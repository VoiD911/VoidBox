--[[
    VoidBox - Screen Auras

    Icons, bars or drawings placed anywhere on the screen, shown while a chosen
    buff or debuff is up, missing or about to expire on the player or the
    target: a small WeakAuras. An aura is chosen by spell, or by debuff type
    (anything I can dispel, Magic, Curse, Disease, Poison).

    Where the client has AuraContainers (Retail 12.0, Forever) the display is
    client-rendered, so it keeps working in combat where Forever refuses every
    aura read (Clearcasting verified with /vb auratest, 2026-10-02):
      present  : a container limited to the aura holds a single button, and
                 that button carries the icon, the bar or the drawing. The
                 client fills the cooldown, the countdown text, the stack
                 count and the bar itself (SetDurationCooldown/Text/Bar,
                 SetApplicationCount).
      missing  : the client sizes the container itself, 1 px wide while the
                 aura is absent and one element wide while it is present. A
                 clipping frame hung on its right edge is therefore full while
                 the aura is absent and zero wide while it is present, and the
                 display sits inside it. Geometry from a value nobody reads.
      expiring : the button's duration text is the icon itself (an inline
                 texture), coloured through a Step curve over the remaining
                 time: opaque below the threshold, transparent above. The
                 client evaluates the curve.
    Elsewhere the addon reads the auras itself.

    "Spell usable" entries are not auras: they show while a spell can be cast
    (enough energy, rage, mana...). C_Spell.IsSpellUsable stays readable in
    combat on Forever, while the power itself is secret even out of combat
    (/vb usetest, 2026-10-04), so the addon draws those itself.

    Blizzard does not let addons pick a debuff ON THE PLAYER by spell while
    auras are secret (EverAuras' finding): such an aura only shows out of
    combat on Forever. Debuff types are aura properties, not identities, so
    they keep working.

    Sounds: C_UnitAuras.AddAuraSound has the game itself play a sound file when
    an aura is added to or removed from a unit, in combat too. It needs spell
    IDs; debuff types and clients without it fall back to the addon playing
    the sound when it can read the change.

    Techniques as documented by EverAuras (github.com/Hackblarvest/EverAuras,
    GPL-2.0): reimplemented here, no code copied.
]]

local addonName, VB = ...

VB.screenAuras = VB.screenAuras or {}   -- saved entries, per class (set at login)
local watchers = {}                     -- runtime objects, one per enabled entry

-- Sound FILES (FileDataIDs): AddAuraSound takes a file, not a Sound Kit ID.
-- IDs as used by DBM on every client.
VB.AURA_SOUNDS = {
    { value = "none" },
    { value = "bell", file = 566558 },      -- Night Elf bell toll
    { value = "warning", file = 567394 },   -- raid boss emote warning
    { value = "flag", file = 569200 },      -- PvP flag taken
}

VB.AURA_COLORS = {
    { value = "yellow", rgb = { 1, 0.85, 0 } },
    { value = "white",  rgb = { 1, 1, 1 } },
    { value = "red",    rgb = { 1, 0.15, 0.15 } },
    { value = "green",  rgb = { 0.2, 1, 0.2 } },
    { value = "blue",   rgb = { 0.2, 0.6, 1 } },
    { value = "purple", rgb = { 0.7, 0.3, 1 } },
}

-- Debuff types: "any" = whatever the player can dispel (the RAID filter)
VB.AURA_DISPEL_TYPES = { "any", "Magic", "Curse", "Disease", "Poison" }
local TYPE_ICONS = {
    any = "Interface\\Icons\\Spell_Holy_DispelMagic",
    Magic = "Interface\\Icons\\Spell_Holy_DispelMagic",
    Curse = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    Disease = "Interface\\Icons\\Spell_Holy_NullifyDisease",
    Poison = "Interface\\Icons\\Spell_Nature_NullifyPoison",
}

-- Procs that a readable spell cost reveals in combat: aura ID -> spell it makes free
local COST_PROBES = {
    [16870] = 8936,   -- druid Clearcasting -> Regrowth (Forever, /vb auratest 2026-10-02)
}

local GROUP_KEY = "vbScreenAura"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

local function ColorOf(entry)
    for _, c in ipairs(VB.AURA_COLORS) do
        if c.value == entry.color then return unpack(c.rgb) end
    end
    return 1, 0.85, 0
end

local function SoundFileOf(key)
    for _, s in ipairs(VB.AURA_SOUNDS) do
        if s.value == key then return s.file end
    end
    return nil
end

local function IsType(entry) return entry.source == "type" end
local function IsUsableEntry(entry) return entry.source == "usable" end

-- Form condition (druid forms, warrior stances...): entry.form is the spell
-- ID of the form, nil = any form. The stance bar API stays readable in
-- combat; if it ever is not, the aura is left visible rather than hidden.
local function ActiveFormSpell()
    local ok, index = pcall(GetShapeshiftForm)
    if not ok or (issecretvalue and issecretvalue(index)) then return nil, false end
    if not index or index == 0 then return 0, true end
    local okI, _, _, _, spellID = pcall(GetShapeshiftFormInfo, index)
    if not okI or (issecretvalue and issecretvalue(spellID)) then return nil, false end
    return spellID or 0, true
end

local function FormOK(entry)
    if not entry.form then return true end
    local spellID, known = ActiveFormSpell()
    if not known then return true end
    return spellID == entry.form
end

-- A boolean query that may come back secret: unknown counts as "yes", so a
-- condition never hides an aura on a value it could not read
local function SoftBool(fn, ...)
    local ok, v = pcall(fn, ...)
    if not ok or (issecretvalue and issecretvalue(v)) then return true end
    return v and true or false
end

-- entry.needs (recommended auras, Templates.lua): the spell that must be
-- known before the aura means anything, so "Ice Armor missing" stays quiet
-- until Ice Armor is learned. Looked up once per spell, again when the
-- spellbook changes (RefreshScreenAuraIDs).
local knownCache = {}
local function NeedsOK(entry)
    if not entry.needs or not VB.KnowsSpell then return true end
    local known = knownCache[entry.needs]
    if known == nil then
        known = VB:KnowsSpell(entry.needs) and true or false
        knownCache[entry.needs] = known
    end
    return known
end

-- Every condition of an entry. All of them are readable in combat.
local function ConditionsOK(entry)
    if not NeedsOK(entry) then return false end
    if not FormOK(entry) then return false end
    if entry.unit ~= "player" and not UnitExists(entry.unit) then return false end
    if entry.combat == "in" and not InCombatLockdown() then return false end
    if entry.combat == "out" and InCombatLockdown() then return false end
    if entry.group == "group" and not IsInGroup() then return false end
    if entry.group == "raid" and not IsInRaid() then return false end
    if entry.hostileTarget then
        if not UnitExists("target") or not SoftBool(UnitCanAttack, "player", "target") then
            return false
        end
    end
    if entry.inRange and entry.spellID then
        -- The spell's own range to the target; answers in combat on Forever
        if not UnitExists("target") then return false end
        if C_Spell and C_Spell.IsSpellInRange then
            local name = VB:GetSpellName(entry.spellID) or entry.spellID
            local ok, r = pcall(C_Spell.IsSpellInRange, name, "target")
            if ok and r ~= nil and not (issecretvalue and issecretvalue(r)) and not r then
                return false
            end
        end
    end
    return true
end

-- The player's forms, for the config: { { spellID, name }, ... }
function VB:GetPlayerForms()
    local forms = {}
    local okN, n = pcall(GetNumShapeshiftForms)
    for i = 1, (okN and n or 0) do
        local ok, _, _, _, spellID = pcall(GetShapeshiftFormInfo, i)
        if ok and spellID then
            forms[#forms + 1] = { spellID = spellID, name = VB:GetSpellName(spellID) or tostring(spellID) }
        end
    end
    return forms
end

local function FilterOf(entry)
    if IsType(entry) then
        return entry.dispelType == "any" and "HARMFUL|RAID" or "HARMFUL"
    end
    return entry.kind .. (entry.mine and "|PLAYER" or "")
end

-- What the client should match inside the filter
local function CandidateOf(w)
    if IsType(w.entry) then
        if w.entry.dispelType == "any" then return {} end
        return { includeDispelTypes = { [w.entry.dispelType] = true } }
    end
    return { includeSpellIDs = w.ids }
end

function VB:ScreenAuraIcon(entry)
    if IsType(entry) then return TYPE_ICONS[entry.dispelType] or TYPE_ICONS.any end
    return entry.spellID and VB:GetSpellIcon(entry.spellID)
end

function VB:ScreenAuraName(entry)
    if IsType(entry) then return VB.L["AURA_TYPE_" .. (entry.dispelType or "any"):upper()] end
    return entry.spellID and VB:GetSpellName(entry.spellID) or VB.L["DISPLAY_UNKNOWN_SPELL"]
end

-- A bar is wider than tall; everything else is a square of `size`
local function SizeOf(entry)
    if entry.display == "bar" and entry.show ~= "missing" and entry.show ~= "expiring" then
        return entry.size * 4, math.max(14, math.floor(entry.size / 2))
    end
    return entry.size, entry.size
end

function VB:NewScreenAura(spellID)
    return {
        spellID = spellID,
        source = spellID and "spell" or "type",   -- spell | type
        dispelType = "any",
        unit = "player",        -- player | target
        kind = "HELPFUL",       -- HELPFUL | HARMFUL
        mine = true,
        show = "present",       -- present | missing | expiring
        expire = 5,             -- seconds left for "expiring"
        display = "icon",       -- icon | bar | frame | disc
        countdown = false,
        stacks = true,
        glow = false,
        size = 48,
        color = "yellow",
        sound = "none",
        x = 0,
        y = 150,
        enabled = true,
    }
end

-- Entries saved by older versions: fill new fields, map retired sounds, and
-- keep combinations the displays support
local function Normalize(entry)
    entry.source = entry.source or "spell"
    entry.dispelType = entry.dispelType or "any"
    entry.show = entry.show or "present"
    entry.expire = entry.expire or 5
    if entry.countdown == nil then entry.countdown = false end
    if entry.stacks == nil then entry.stacks = true end
    if entry.glow == nil then entry.glow = false end
    entry.combat = entry.combat or "any"
    entry.group = entry.group or "any"
    if entry.sound ~= "none" and not SoundFileOf(entry.sound) then entry.sound = "bell" end
    if IsType(entry) then
        entry.kind = "HARMFUL"
        if entry.show == "expiring" then entry.show = "present" end
    end
    if IsUsableEntry(entry) then
        -- Not an aura: no unit, no timer, nothing for a bar to show
        entry.unit = "player"
        if entry.show == "expiring" then entry.show = "present" end
        if entry.display == "bar" then entry.display = "icon" end
    end
end

-- Every rank sharing the spell's name: ranked spellbooks give each rank its own ID.
-- entry.also: other spells that count as the same aura (one mage armor or
-- another, Arcane Intellect or Arcane Brilliance). Returns the ID set, the
-- spell's own name, and the set of every accepted name.
local function ResolveIDs(entry)
    if IsType(entry) or not entry.spellID then return {}, nil, {} end
    -- Asked by name, which the client answers for the best known rank
    if IsUsableEntry(entry) then return {}, VB:GetSpellName(entry.spellID), {} end
    local ids, names = {}, {}
    local spells = { entry.spellID }
    for _, id in ipairs(entry.also or {}) do spells[#spells + 1] = id end
    for _, spellID in ipairs(spells) do
        ids[spellID] = true
        local n = VB:GetSpellName(spellID)
        if n then names[n] = true end
    end
    if VB.hasRankedSpellbook and next(names) then
        VB:ForEachKnownSpell(function(id, n)
            if names[n or VB:GetSpellName(id) or ""] then ids[id] = true end
        end)
    end
    return ids, VB:GetSpellName(entry.spellID), names
end

-- Frames hung on a container that owns an aura group must refuse untrusted
-- layout scripts; this template is how addons opt in. Absent elsewhere.
local function SafeFrame(parent)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    if ok and f then return f end
    return CreateFrame("Frame", nil, parent)
end

-------------------------------------------------
-- Visuals. Textures belong to `owner` (they show and hide with it) and cover
-- `anchor` (the holder).
-------------------------------------------------
local function CreateDrawing(owner, anchor, entry)
    local r, g, b = ColorOf(entry)
    local regions = {}
    if entry.display == "disc" then
        local t = owner:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(anchor)
        t:SetColorTexture(r, g, b, 0.35)
        if owner.CreateMaskTexture then
            local mask = owner:CreateMaskTexture()
            mask:SetAllPoints(anchor)
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            t:AddMaskTexture(mask)
        end
        regions[1] = t
    else
        local thick = math.max(2, math.floor(entry.size / 25))
        for side = 1, 4 do
            local e = owner:CreateTexture(nil, "OVERLAY")
            e:SetColorTexture(r, g, b, 0.9)
            if side == 1 then
                e:SetPoint("TOPLEFT", anchor, "TOPLEFT")
                e:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
                e:SetHeight(thick)
            elseif side == 2 then
                e:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
                e:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
                e:SetHeight(thick)
            elseif side == 3 then
                e:SetPoint("TOPLEFT", anchor, "TOPLEFT")
                e:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
                e:SetWidth(thick)
            else
                e:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
                e:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
                e:SetWidth(thick)
            end
            regions[#regions + 1] = e
        end
    end
    return regions
end

-- Pulsing glow around the holder. The animation runs on the texture itself,
-- with no Lua script, so it also works inside client-driven buttons.
local GLOW_SCALE = 1.7   -- the border art has a wide empty margin
local function CreateGlow(owner, anchor, entry)
    local r, g, b = ColorOf(entry)
    local w, h = SizeOf(entry)
    local glow = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture(GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(r, g, b, 1)
    glow:SetPoint("CENTER", anchor, "CENTER")
    glow:SetSize(w + h * (GLOW_SCALE - 1), h * GLOW_SCALE)
    pcall(function()
        local ag = glow:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.25)
        fade:SetDuration(0.6)
        ag:Play()
    end)
    return glow
end

-- How far the glow reaches past the holder (room the missing clip must leave)
local function GlowMargin(entry)
    if not entry.glow then return 0 end
    return math.ceil(entry.size * (GLOW_SCALE - 1) / 2)
end

-- A text layer above the cooldown swipe, for countdown and stacks
local function TextLayer(button, above)
    local layer = CreateFrame("Frame", nil, button)
    layer:SetAllPoints(button)
    layer:SetFrameLevel((above or button):GetFrameLevel() + 2)
    return layer
end

local function Font(fs, size)
    fs:SetFont(VB.config.font or STANDARD_TEXT_FONT, math.max(8, math.floor(size)), "OUTLINE")
end

-- Static look of a bar, shared by the live button, the addon display and the preview
local function BuildBarLook(owner, entry)
    local _, h = SizeOf(entry)
    local r, g, b = ColorOf(entry)
    local icon = owner:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", owner, "TOPLEFT")
    icon:SetSize(h, h)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local bar = CreateFrame("StatusBar", nil, owner)
    bar:SetPoint("TOPLEFT", owner, "TOPLEFT", h + 1, 0)
    bar:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT")
    bar:SetStatusBarTexture(BAR_TEXTURE)
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0, 0, 0, 0.6)

    local name = bar:CreateFontString(nil, "OVERLAY")
    Font(name, h * 0.55)
    name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    name:SetPoint("RIGHT", bar, "RIGHT", -40, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(IsType(entry) and VB:ScreenAuraName(entry) or (VB:GetSpellName(entry.spellID) or ""))

    local timer = bar:CreateFontString(nil, "OVERLAY")
    Font(timer, h * 0.55)
    timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

    local count = owner:CreateFontString(nil, "OVERLAY")
    Font(count, h * 0.6)
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    count:SetTextColor(1, 0.85, 0)
    return { icon = icon, bar = bar, timer = timer, count = count, name = name }
end

-- What the preview and the missing clip draw (no live data)
local function CreateVisual(owner, anchor, entry)
    if entry.display == "bar" and entry.show == "present" then
        local look = BuildBarLook(owner, entry)
        look.icon:SetTexture(VB:ScreenAuraIcon(entry))
        if entry.countdown then look.timer:SetText("12") end
    elseif entry.display == "icon" or entry.display == "bar" then
        local t = owner:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(anchor)
        t:SetTexture(VB:ScreenAuraIcon(entry))
    else
        CreateDrawing(owner, anchor, entry)
    end
    if entry.glow then CreateGlow(owner, anchor, entry) end
end

-------------------------------------------------
-- Holder: the movable frame the display sits in, plus the preview used to
-- place it while the Auras tab is open
-------------------------------------------------
-------------------------------------------------
-- Screen groups (2.8.0): auras moved and sized as one block.
-- A group is { name, x, y (its centre, UIParent units), scale }. An entry in
-- one (entry.screenGroup = its key; entry.group is the "in a group / raid"
-- condition) has x / y relative to the group's centre in the group's own
-- units, so the group frame's scale sizes its auras. While the Auras tab is
-- open a handle above the group moves it (drag) and sizes it (wheel).
-- Static on purpose: where the client draws the auras (Forever, Retail) the
-- addon never learns which are up, so nothing could close the gaps.
-------------------------------------------------
VB.screenAuraGroups = VB.screenAuraGroups or {}
local groupFrames = {}  -- key -> frame, kept across rebuilds

local function GroupOf(entry)
    return entry.screenGroup and VB.screenAuraGroups[entry.screenGroup]
end

-- SetPoint offsets are in the frame's own (scaled) units
local function PlaceGroup(f, g)
    local s = g.scale or 1
    f:SetScale(s)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", (g.x or 0) / s, (g.y or 0) / s)
    if f.handle then
        f.handle.text:SetText(("%s  %d%%"):format(g.name or "?", math.floor(s * 100 + 0.5)))
    end
end

local function GroupFrame(key)
    local f = groupFrames[key]
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(1, 1)
        f:SetFrameStrata("MEDIUM")
        f:SetMovable(true)
        local handle = CreateFrame("Button", nil, f, "BackdropTemplate")
        handle:SetHeight(18)
        handle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        handle:SetBackdropColor(0.4, 0.25, 0.8, 0.85)
        handle.text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        handle.text:SetPoint("CENTER")
        handle:RegisterForDrag("LeftButton")
        handle:EnableMouseWheel(true)
        handle:SetScript("OnDragStart", function() f:StartMoving() end)
        handle:SetScript("OnDragStop", function()
            f:StopMovingOrSizing()
            local g = VB.screenAuraGroups[f.key]
            if not g then return end
            local cx, cy = f:GetCenter()
            local ux, uy = UIParent:GetCenter()
            g.x = math.floor(cx * (g.scale or 1) - ux + 0.5)
            g.y = math.floor(cy * (g.scale or 1) - uy + 0.5)
            PlaceGroup(f, g)
        end)
        handle:SetScript("OnMouseWheel", function(_, delta)
            local g = VB.screenAuraGroups[f.key]
            if g then VB:SetScreenGroupScale(f.key, (g.scale or 1) + 0.1 * delta) end
        end)
        handle:Hide()
        f.handle = handle
        groupFrames[key] = f
    end
    f.key = key
    PlaceGroup(f, VB.screenAuraGroups[key])
    f:Show()
    return f
end

-- The handle sits above the group's auras, as wide as they are
local function PlaceHandle(key)
    local f = groupFrames[key]
    if not f then return end
    local l, r, t
    for _, entry in ipairs(VB.screenAuras or {}) do
        if entry.screenGroup == key then
            local w, h = SizeOf(entry)
            local x, y = entry.x or 0, entry.y or 0
            l, r = math.min(l or x - w / 2, x - w / 2), math.max(r or x + w / 2, x + w / 2)
            t = math.max(t or y + h / 2, y + h / 2)
        end
    end
    if not l then return end
    f.handle:ClearAllPoints()
    f.handle:SetPoint("BOTTOM", f, "CENTER", (l + r) / 2, t + 16)
    f.handle:SetWidth(math.max(90, r - l))
end

function VB:SetScreenGroupScale(key, scale)
    local g = VB.screenAuraGroups[key]
    if not g then return end
    g.scale = math.max(0.5, math.min(2, math.floor(scale * 20 + 0.5) / 20))
    if groupFrames[key] then PlaceGroup(groupFrames[key], g) end
end

-- A new group centred at x, y (UIParent units); returns its key
function VB:NewScreenGroup(name, x, y)
    local key = 0
    for k in pairs(VB.screenAuraGroups) do
        if type(k) == "number" and k > key then key = k end
    end
    key = key + 1
    VB.screenAuraGroups[key] = { name = name, x = x or 0, y = y or 150, scale = 1 }
    return key
end

-- Where an entry is on screen (UIParent units), group or not
local function AbsolutePos(entry)
    local g = GroupOf(entry)
    local x, y = entry.x or 0, entry.y or 0
    if g then return g.x + x * (g.scale or 1), g.y + y * (g.scale or 1) end
    return x, y
end

-- Into another group (nil = none), staying where it is on screen
function VB:SetAuraScreenGroup(entry, key)
    local ax, ay = AbsolutePos(entry)
    local g = key and VB.screenAuraGroups[key]
    if g then
        local s = g.scale or 1
        entry.x, entry.y = math.floor((ax - g.x) / s + 0.5), math.floor((ay - g.y) / s + 0.5)
        entry.screenGroup = key
    else
        entry.x, entry.y = math.floor(ax + 0.5), math.floor(ay + 0.5)
        entry.screenGroup = nil
    end
end

-- A copy outside any group, where the original is on screen (sharing one aura)
function VB:UngroupedAuraCopy(entry)
    local copy = VB:CopyTable(entry)
    copy.x, copy.y = AbsolutePos(entry)
    copy.screenGroup = nil
    return copy
end

local function CreateHolder(entry)
    local parent = GroupOf(entry) and GroupFrame(entry.screenGroup) or UIParent
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(SizeOf(entry))
    holder:SetPoint("CENTER", parent, "CENTER", entry.x or 0, entry.y or 0)
    holder:SetFrameStrata("MEDIUM")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:RegisterForDrag("LeftButton")
    holder:EnableMouse(false)
    holder:SetScript("OnDragStart", holder.StartMoving)
    holder:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- (a grouped holder has its group's scale: both centres in the same units)
        local cx, cy = self:GetCenter()
        local px, py = parent:GetCenter()
        entry.x = math.floor(cx - px + 0.5)
        entry.y = math.floor(cy - py + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "CENTER", entry.x, entry.y)
        if entry.screenGroup then PlaceHandle(entry.screenGroup) end
    end)

    local preview = CreateFrame("Frame", nil, holder)
    preview:SetAllPoints()
    preview:SetAlpha(0.6)
    preview:Hide()
    CreateVisual(preview, preview, entry)
    local label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", preview, "TOP", 0, 2)
    label:SetText(VB:ScreenAuraName(entry) or "?")
    holder.preview = preview
    return holder
end

-------------------------------------------------
-- Client-rendered displays (AuraContainer)
-------------------------------------------------
local function NewAuraContainer(w)
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, w.holder, "CustomAuraContainerTemplate")
    if not ok or not c then return nil end
    pcall(c.SetEditModePreviewEnabled, c, false)
    pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
    pcall(c.SetFlowLayoutPadding, c, 0, 0, 0, 0)
    return c
end

local function FinishContainer(c, w)
    pcall(c.SetAuraGroupMaxFrameCount, c, GROUP_KEY, 1)
    pcall(c.SetAuraGroupCandidateFilters, c, GROUP_KEY, CandidateOf(w))
    pcall(c.SetEnabled, c, true)
    c:Show()
    pcall(c.SetUnit, c, w.entry.unit)
    pcall(c.UpdateAllAuras, c)
end

local function RemainingProperty()
    return Enum and Enum.DurationTextBindingProperty
        and Enum.DurationTextBindingProperty.RemainingDuration or 0
end

-- Icon extras on a styled button: countdown text and stack count
local function DecorateIcon(button, entry)
    local layer = TextLayer(button, button.cooldown)
    if entry.countdown then
        local timer = layer:CreateFontString(nil, "OVERLAY")
        Font(timer, entry.size * 0.38)
        timer:SetPoint("CENTER", button, "CENTER", 0, 0)
        pcall(button.SetDurationText, button, timer, nil)
    end
    if button.count then
        if entry.stacks then
            -- Bigger than in the unit frames: it is the point of the aura
            button.count:SetParent(layer)
            Font(button.count, entry.size * 0.6)
        else
            button.count:SetAlpha(0)
        end
    end
end

local function DecorateBar(button, entry)
    local w, h = SizeOf(entry)
    button:SetSize(w, h)
    button:EnableMouse(false)
    local look = BuildBarLook(button, entry)
    pcall(button.SetIcon, button, look.icon)
    local dirs = Enum and Enum.StatusBarTimerDirection
    pcall(button.SetDurationBar, button, look.bar, { direction = dirs and dirs.RemainingTime })
    if entry.countdown then pcall(button.SetDurationText, button, look.timer, nil) end
    if entry.stacks then pcall(button.SetApplicationCount, button, look.count, nil) end
end

-- present: the single button carries the display
local function BuildPresentContainer(w)
    local entry, holder = w.entry, w.holder
    local c = NewAuraContainer(w)
    if not c then return nil end

    local added = pcall(c.AddAuraGroup, c, GROUP_KEY, FilterOf(entry), {
        maxFrameCount = 1,
        initializeFrame = function(button)
            if entry.display == "icon" then
                VB.StyleAuraButton(entry.size, entry.kind == "HARMFUL", button)
                pcall(DecorateIcon, button, entry)
            elseif entry.display == "bar" then
                pcall(DecorateBar, button, entry)
            else
                button:SetSize(1, 1)
                button:EnableMouse(false)
                -- Give the client an icon region to fill, as on a real icon;
                -- it stays invisible, only the drawing shows
                local icon = button:CreateTexture(nil, "BORDER")
                icon:SetSize(1, 1)
                icon:SetPoint("TOPLEFT")
                icon:SetAlpha(0)
                button.icon = icon
                pcall(button.SetIcon, button, icon)
                pcall(CreateDrawing, button, holder, entry)
            end
            if entry.glow then pcall(CreateGlow, button, holder, entry) end
        end,
    })
    if not added then return nil end

    c:SetAllPoints(holder)
    FinishContainer(c, w)
    return c
end

-- missing: the client sizes the container, a clip hung on its right edge
-- holds the display (see the header)
local function BuildMissingContainer(w)
    local entry, holder = w.entry, w.holder
    local c = NewAuraContainer(w)
    if not c then return nil end

    local m = GlowMargin(entry)
    local width = entry.size + 1 + 2 * m
    local added = pcall(c.AddAuraGroup, c, GROUP_KEY, FilterOf(entry), {
        maxFrameCount = 1,
        layout = { elementWidth = width, elementHeight = entry.size },
        initializeFrame = function(button)
            -- Invisible: only its width matters
            button:SetSize(width, entry.size)
            pcall(button.SetMouseClickEnabled, button, false)
            pcall(button.SetMouseMotionEnabled, button, false)
        end,
    })
    if not added then return nil end

    -- Anchored by one corner only, so the client decides its size
    c:SetPoint("TOPLEFT", holder, "TOPLEFT")

    -- Absent: container 1 px wide, the clip starts m px left of the holder.
    -- Present: container `width` wide, the clip starts on its own right edge.
    local clip = SafeFrame(holder)
    clip:SetClipsChildren(true)
    clip:SetPoint("TOPLEFT", c, "TOPRIGHT", -1 - m, m)
    clip:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", m, -m)
    CreateVisual(clip, holder, entry)
    w.clip = clip

    FinishContainer(c, w)
    return c
end

-- Step curve over the remaining time: `on` from 0 up to `limit`, transparent after
local function RemainingCurve(limit, r, g, b)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local curve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Step) end
    curve:AddPoint(0, CreateColor(r, g, b, 1))
    curve:AddPoint(limit, CreateColor(r, g, b, 0))
    return curve
end

-- expiring: the duration text IS the icon, shown by the curve (see the header)
local function BuildExpiringContainer(w)
    local entry = w.entry
    local iconCurve = RemainingCurve(entry.expire, 1, 1, 1)
    if not iconCurve then return nil end
    local c = NewAuraContainer(w)
    if not c then return nil end

    local size = entry.size
    local icon = VB:ScreenAuraIcon(entry)
    local markup = ("|T%s:%d:%d|t"):format(tostring(icon), size, size)
    local added = pcall(c.AddAuraGroup, c, GROUP_KEY, FilterOf(entry), {
        maxFrameCount = 1,
        initializeFrame = function(button)
            button:SetSize(size, size)
            pcall(button.SetMouseClickEnabled, button, false)
            pcall(button.SetMouseMotionEnabled, button, false)
            local pic = button:CreateFontString(nil, "OVERLAY")
            pic:SetFont(STANDARD_TEXT_FONT, 12, "")
            pic:SetPoint("CENTER", button, "CENTER")
            pcall(button.SetDurationText, button, pic, {
                textFormat = { formatString = markup, components = {} },
                textColor = { curve = iconCurve, property = RemainingProperty() },
            })
            if entry.countdown then
                local timer = button:CreateFontString(nil, "OVERLAY", nil, 7)
                Font(timer, size * 0.38)
                timer:SetPoint("CENTER", button, "CENTER")
                -- A second binding on the same button may not be allowed;
                -- then the icon simply shows without numbers
                pcall(button.SetDurationText, button, timer, {
                    textColor = { curve = RemainingCurve(entry.expire, 1, 1, 1), property = RemainingProperty() },
                })
            end
        end,
    })
    if not added then return nil end

    c:SetAllPoints(w.holder)
    FinishContainer(c, w)
    return c
end

-------------------------------------------------
-- Addon-rendered display (clients without AuraContainers)
-------------------------------------------------
local function BuildLuaDisplay(w)
    local entry = w.entry
    local f = CreateFrame("Frame", nil, w.holder)
    f:SetAllPoints()
    f:Hide()
    if entry.display == "bar" and entry.show == "present" then
        f.look = BuildBarLook(f, entry)
        f.look.icon:SetTexture(VB:ScreenAuraIcon(entry))
    elseif entry.display == "icon" or entry.display == "bar" then
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(VB:ScreenAuraIcon(entry))
        f.icon = icon

        local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(not entry.countdown)
        cd:SetReverse(true)
        f.cooldown = cd

        local layer = TextLayer(f, cd)
        local count = layer:CreateFontString(nil, "OVERLAY")
        Font(count, entry.size * 0.45)
        count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        count:SetTextColor(1, 0.85, 0)
        f.count = count
    else
        CreateDrawing(f, f, entry)
    end
    if entry.glow then CreateGlow(f, f, entry) end
    return f
end

-------------------------------------------------
-- Game-played sounds (C_UnitAuras.AddAuraSound)
--
-- Registrations can outlive a /reload. Their IDs are saved: if the counter
-- went on (first new ID above every saved one) the old ones are still ours
-- and are removed; if it started again the game cleared them and the old
-- numbers may now belong to someone else, so they are left alone.
-------------------------------------------------
local staleChecked = false
local function DropStaleSounds(firstNewID)
    if staleChecked then return end
    staleChecked = true
    local old = VoidBoxDB and VoidBoxDB.auraSoundIDs
    if type(old) ~= "table" then return end
    local maxOld = 0
    for _, sid in ipairs(old) do
        if type(sid) == "number" and sid > maxOld then maxOld = sid end
    end
    if firstNewID > maxOld then
        for _, sid in ipairs(old) do pcall(C_UnitAuras.RemoveAuraSound, sid) end
    end
end

local function SaveSoundIDs()
    if not VoidBoxDB then return end
    local all = {}
    for _, w in ipairs(watchers) do
        for _, sid in ipairs(w.soundIDs or {}) do all[#all + 1] = sid end
    end
    VoidBoxDB.auraSoundIDs = all
end

local function RegisterGameSounds(w)
    w.soundIDs = {}
    local entry = w.entry
    local file = SoundFileOf(entry.sound)
    if not file or not next(w.ids) then return false end
    if entry.show == "expiring" then return false end   -- no "about to expire" trigger
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound and Enum and Enum.UnitAuraSoundTrigger) then
        return false
    end
    local trigger = Enum.UnitAuraSoundTrigger[entry.show == "missing" and "Removed" or "Added"]
    if not trigger then return false end

    local info = { unitToken = entry.unit, soundFileID = file,
                   outputChannel = "Master", throttleSeconds = 0.5 }
    for id in pairs(w.ids) do
        info.spellID = id
        local ok, sid = pcall(C_UnitAuras.AddAuraSound, trigger, info)
        if ok and type(sid) == "number" and not (issecretvalue and issecretvalue(sid)) then
            DropStaleSounds(sid)
            w.soundIDs[#w.soundIDs + 1] = sid
        end
    end
    return #w.soundIDs > 0
end

local function RemoveGameSounds(w)
    for _, sid in ipairs(w.soundIDs or {}) do
        pcall(C_UnitAuras.RemoveAuraSound, sid)
    end
    w.soundIDs = nil
end

-------------------------------------------------
-- Detection (addon-played sounds, and the display without containers)
-------------------------------------------------

-- Spell usable: true / false, nil when the answer is hidden
local function ReadUsable(w)
    if not (C_Spell and C_Spell.IsSpellUsable) then return nil end
    local ok, usable = pcall(C_Spell.IsSpellUsable, w.name or w.entry.spellID)
    if not ok or (issecretvalue and issecretvalue(usable)) then return nil end
    return usable and true or false
end

-- true / false when the addon can tell, nil when it cannot (secret auras)
local function ReadAura(w)
    local entry = w.entry
    if IsUsableEntry(entry) then return ReadUsable(w) end
    if not UnitExists(entry.unit) then return false end

    local auras = VB:GetAuras(entry.unit, (FilterOf(entry):gsub("|", " ")))
    local unreadable = false
    for _, a in ipairs(auras) do
        local ok, match = pcall(function()
            if IsType(entry) then
                return entry.dispelType == "any" or a.dispelName == entry.dispelType
            end
            return (a.spellId and w.ids[a.spellId]) or (a.name and w.names and w.names[a.name])
        end)
        if not ok then
            unreadable = true
        elseif match then
            return true, a
        end
    end
    -- Forever returns no aura at all once they turn secret in combat
    if unreadable or (#auras == 0 and C_Secrets and InCombatLockdown()) then return nil end
    return false
end

local function CostSaysActive(w)
    local probe = COST_PROBES[w.entry.spellID]
    if not probe or w.entry.unit ~= "player" or IsType(w.entry) or IsUsableEntry(w.entry) then return nil end
    if not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, probe)
    if not ok or type(costs) ~= "table" or not costs[1] then return nil end
    local cost = costs[1].cost
    if cost == nil or (issecretvalue and issecretvalue(cost)) then return nil end
    return cost == 0
end

-- Seconds left on a readable aura, or nil (permanent / unknown)
local function TimeLeft(aura)
    local ok, left = pcall(function()
        if aura.expirationTime and aura.expirationTime > 0 then
            return aura.expirationTime - GetTime()
        end
    end)
    return ok and left or nil
end

local function ShowLuaAura(f, aura, entry)
    if aura then
        local okI, tex = pcall(function() return aura.icon end)
        local look = f.look
        if okI and tex then
            if look then pcall(look.icon.SetTexture, look.icon, tex)
            elseif f.icon then pcall(f.icon.SetTexture, f.icon, tex) end
        end
        pcall(function()
            local n = aura.applications or 0
            local stackText = (entry.stacks and n > 1) and n or ""
            if look then
                look.count:SetText(stackText)
                local left = TimeLeft(aura)
                if aura.duration and aura.duration > 0 and left then
                    look.bar:SetMinMaxValues(0, aura.duration)
                    look.bar:SetValue(left)
                    look.timer:SetText(entry.countdown and ("%.0f"):format(left) or "")
                else
                    look.bar:SetMinMaxValues(0, 1)
                    look.bar:SetValue(1)
                    look.timer:SetText("")
                end
            elseif f.cooldown then
                if aura.duration and aura.duration > 0 and aura.expirationTime then
                    f.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
                else
                    f.cooldown:Clear()
                end
                f.count:SetText(stackText)
            end
        end)
    end
    f:Show()
end

local function UpdateWatcher(w)
    local entry = w.entry
    local active, aura = ReadAura(w)
    local cost = CostSaysActive(w)
    if cost == true then
        active = true
    elseif active == nil then
        active = cost
    end

    -- shown: what the display should be doing, nil = cannot tell
    local shown
    if active ~= nil then
        if entry.show == "missing" then
            shown = not active and UnitExists(entry.unit)
        elseif entry.show == "expiring" then
            local left = active and aura and TimeLeft(aura)
            shown = (left ~= nil and left <= entry.expire) or false
        else
            shown = active
        end
    end

    -- Out of the chosen form the aura is not wanted at all
    if shown ~= nil and not ConditionsOK(entry) then shown = false end

    if w.lua and shown ~= nil then
        if shown and entry.show ~= "missing" then
            ShowLuaAura(w.lua, aura, entry)
        else
            w.lua:SetShown(shown)
        end
    end

    if shown ~= nil then
        if shown and w.primed and not w.shown and not w.gameSounds and not VB._screenAuraPreview then
            local file = SoundFileOf(entry.sound)
            if file then pcall(PlaySoundFile, file, "Master") end
        end
        w.shown = shown
        w.primed = true
    end
end

-- Hide a whole aura when its unit is missing (no target: the container would
-- call the aura "missing") or the player is not in its form. The holder is a
-- plain frame of ours, so this also works in combat.
local function UpdateHolders()
    for _, w in ipairs(watchers) do
        local wanted = ConditionsOK(w.entry)
        w.holder:SetShown(wanted or VB._screenAuraPreview)
    end
end

local ticker
local function UpdateAll()
    for _, w in ipairs(watchers) do UpdateWatcher(w) end
    UpdateHolders()
end

-------------------------------------------------
-- Build / refresh
-------------------------------------------------
function VB:RebuildScreenAuras()
    wipe(knownCache)
    -- Groups no aura uses any more go; auras naming a group that is gone leave it
    local used = {}
    for _, entry in ipairs(VB.screenAuras or {}) do
        if entry.screenGroup then
            if VB.screenAuraGroups[entry.screenGroup] then used[entry.screenGroup] = true
            else entry.screenGroup = nil end
        end
    end
    for key in pairs(VB.screenAuraGroups) do
        if not used[key] then VB.screenAuraGroups[key] = nil end
    end
    for _, f in pairs(groupFrames) do f:Hide() end

    for _, w in ipairs(watchers) do
        RemoveGameSounds(w)
        w.holder:Hide()
        if w.container then pcall(w.container.SetEnabled, w.container, false) end
    end
    wipe(watchers)

    for i, entry in ipairs(VB.screenAuras or {}) do
        Normalize(entry)
        if (entry.spellID or IsType(entry)) and entry.enabled ~= false then
            local w = { entry = entry, index = i }
            w.ids, w.name, w.names = ResolveIDs(entry)
            w.holder = CreateHolder(entry)
            if VB:HasAuraContainers() and not IsUsableEntry(entry) then
                if entry.show == "missing" then
                    w.container = BuildMissingContainer(w)
                elseif entry.show == "expiring" then
                    w.container = BuildExpiringContainer(w)
                else
                    w.container = BuildPresentContainer(w)
                end
            end
            if not w.container then w.lua = BuildLuaDisplay(w) end
            w.gameSounds = RegisterGameSounds(w)
            watchers[#watchers + 1] = w
        end
    end
    SaveSoundIDs()
    for key in pairs(used) do PlaceHandle(key) end

    VB:SetScreenAuraPreview(VB._screenAuraPreview)

    if #watchers > 0 and not ticker then
        ticker = C_Timer.NewTicker(0.15, UpdateAll)
    elseif #watchers == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- /vb auradebug: each live aura, how it is drawn and what it matches. The IDs
-- are what the client is asked for (every known rank of the spell); "reads"
-- is the addon's own reading (true / false / nil = hidden).
function VB:ScreenAuraDebug()
    VB:Print(("=== Screen auras: %d live, containers=%s ==="):format(#watchers, tostring(VB:HasAuraContainers())))
    for _, w in ipairs(watchers) do
        local ids = {}
        for id in pairs(w.ids or {}) do ids[#ids + 1] = tostring(id) end
        table.sort(ids)
        local okR, active = pcall(ReadAura, w)
        VB:Print(("  %d. %s [%s %s %s%s] %s ids=%s reads=%s"):format(w.index, tostring(w.name or w.entry.spellID),
            tostring(w.entry.show), tostring(w.entry.unit), tostring(w.entry.kind), w.entry.mine and "|PLAYER" or "",
            w.container and "container" or "lua", #ids > 0 and table.concat(ids, ",") or "-",
            okR and tostring(active) or "error"))
    end
    -- What each way of reading the player's buffs returns on this client
    local function Names(list)
        local out = {}
        for i = 1, math.min(#list, 4) do
            local ok, n = pcall(function() return tostring(list[i].name) .. "#" .. tostring(list[i].spellId) end)
            out[#out + 1] = ok and n or "?"
        end
        return #list .. " " .. table.concat(out, ", ")
    end
    VB:Print("  GetUnitAuras exists=" .. tostring(C_UnitAuras and C_UnitAuras.GetUnitAuras ~= nil)
        .. ", GetAuraDataByIndex exists=" .. tostring(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex ~= nil))
    for _, filter in ipairs({ "HELPFUL", "HELPFUL|PLAYER" }) do
        if C_UnitAuras and C_UnitAuras.GetUnitAuras then
            local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", filter, 40)
            VB:Print(("  GetUnitAuras(%s): %s"):format(filter, ok and type(list) == "table" and Names(list) or "error/" .. type(list)))
        end
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local list = {}
            for i = 1, 40 do
                local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, (filter:gsub("|", " ")))
                if not ok or not a then break end
                list[#list + 1] = a
            end
            VB:Print(("  GetAuraDataByIndex(%s): %s"):format(filter, Names(list)))
        end
    end
end

-- New ranks learned: widen the ID sets without rebuilding the frames
function VB:RefreshScreenAuraIDs()
    wipe(knownCache)
    for _, w in ipairs(watchers) do
        if not IsType(w.entry) and not IsUsableEntry(w.entry) then
            w.ids, w.name, w.names = ResolveIDs(w.entry)
            if w.container then
                pcall(w.container.SetAuraGroupCandidateFilters, w.container, GROUP_KEY, CandidateOf(w))
                pcall(w.container.UpdateAllAuras, w.container)
            end
            if w.gameSounds then
                RemoveGameSounds(w)
                w.gameSounds = RegisterGameSounds(w)
            end
        end
    end
    SaveSoundIDs()
end

-- While the Auras tab is open every aura shows a preview and can be dragged.
-- The live display is hidden meanwhile so it does not stack on the preview.
function VB:SetScreenAuraPreview(on)
    VB._screenAuraPreview = on and true or false
    for _, w in ipairs(watchers) do
        w.holder.preview:SetShown(VB._screenAuraPreview)
        w.holder:EnableMouse(VB._screenAuraPreview)
        if w.container then w.container:SetShown(not VB._screenAuraPreview) end
        if w.clip then w.clip:SetShown(not VB._screenAuraPreview) end
        if w.lua and VB._screenAuraPreview then w.lua:Hide() end
    end
    for key, f in pairs(groupFrames) do
        f.handle:SetShown(VB._screenAuraPreview and f:IsShown() and VB.screenAuraGroups[key] ~= nil)
    end
    UpdateHolders()
end

-- The container's unit token stays "target": ask it to re-read on a new target
local events = CreateFrame("Frame")
-- Focus and pet the same way. Events a client lacks are skipped.
local UNIT_EVENTS = { PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus", UNIT_PET = "pet" }
for event in pairs(UNIT_EVENTS) do pcall(events.RegisterEvent, events, event) end
for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                         "GROUP_ROSTER_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, arg1)
    local unit = UNIT_EVENTS[event]
    if unit and not (event == "UNIT_PET" and arg1 ~= "player") then
        for _, w in ipairs(watchers) do
            if w.container and w.entry.unit == unit then
                pcall(w.container.UpdateAllAuras, w.container)
            end
        end
    end
    UpdateHolders()
end)

-- Copy of an aura, placed a little lower so both can be seen
function VB:DuplicateScreenAura(index)
    local src = VB.screenAuras[index]
    if not src then return nil end
    local copy = VB:CopyTable(src)
    copy.y = (copy.y or 0) - (copy.size or 48) - 10
    table.insert(VB.screenAuras, index + 1, copy)
    VB:RebuildScreenAuras()
    return index + 1
end
