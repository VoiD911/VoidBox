--[[
    VoidBox - Screen Auras

    Icons or drawings placed anywhere on the screen, shown while a chosen buff
    or debuff is up - or missing - on the player or the target: a small
    WeakAuras.

    Where the client has AuraContainers (Retail 12.0, Forever) the display is
    client-rendered, so it keeps working in combat where Forever refuses every
    aura read (Clearcasting verified with /vb auratest, 2026-10-02):
      present : a container limited to the spell's IDs holds a single button,
                and that button carries the icon or the drawing.
      missing : the client sizes the container itself, 1 px wide while the
                aura is absent and one element wide while it is present. A
                clipping frame hung on its right edge is therefore full while
                the aura is absent and zero wide while it is present, and the
                display sits inside it. Geometry from a value nobody reads.
    Elsewhere the addon reads the auras itself.

    Sounds: C_UnitAuras.AddAuraSound has the game itself play a sound file when
    an aura is added to or removed from a unit, in combat too. Where it is
    missing the addon plays the sound when it can read the change.

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

-- Procs that a readable spell cost reveals in combat: aura ID -> spell it makes free
local COST_PROBES = {
    [16870] = 8936,   -- druid Clearcasting -> Regrowth (Forever, /vb auratest 2026-10-02)
}

local GROUP_KEY = "vbScreenAura"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

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

local function FilterOf(entry)
    return entry.kind .. (entry.mine and "|PLAYER" or "")
end

function VB:NewScreenAura(spellID)
    return {
        spellID = spellID,
        unit = "player",        -- player | target
        kind = "HELPFUL",       -- HELPFUL | HARMFUL
        mine = true,
        show = "present",       -- present | missing
        display = "icon",       -- icon | frame | disc
        glow = false,
        size = 48,
        color = "yellow",
        sound = "none",
        x = 0,
        y = 150,
        enabled = true,
    }
end

-- Entries saved by older versions: fill new fields, map retired sounds
local function Normalize(entry)
    entry.show = entry.show or "present"
    if entry.glow == nil then entry.glow = false end
    if entry.sound ~= "none" and not SoundFileOf(entry.sound) then entry.sound = "bell" end
end

-- Every rank sharing the spell's name: ranked spellbooks give each rank its own ID
local function ResolveIDs(entry)
    local ids = { [entry.spellID] = true }
    local name = VB:GetSpellName(entry.spellID)
    if name and VB.hasRankedSpellbook then
        VB:ForEachKnownSpell(function(id, n)
            if (n or VB:GetSpellName(id)) == name then ids[id] = true end
        end)
    end
    return ids, name
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
    local glow = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture(GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(r, g, b, 1)
    glow:SetPoint("CENTER", anchor, "CENTER")
    glow:SetSize(entry.size * GLOW_SCALE, entry.size * GLOW_SCALE)
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

local function CreateVisual(owner, anchor, entry)
    if entry.display == "icon" then
        local t = owner:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints(anchor)
        t:SetTexture(VB:GetSpellIcon(entry.spellID))
    else
        CreateDrawing(owner, anchor, entry)
    end
    if entry.glow then CreateGlow(owner, anchor, entry) end
end

-------------------------------------------------
-- Holder: the movable square the display sits in, plus the preview used to
-- place it while the Auras tab is open
-------------------------------------------------
local function CreateHolder(entry)
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(entry.size, entry.size)
    holder:SetPoint("CENTER", UIParent, "CENTER", entry.x or 0, entry.y or 0)
    holder:SetFrameStrata("MEDIUM")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:RegisterForDrag("LeftButton")
    holder:EnableMouse(false)
    holder:SetScript("OnDragStart", holder.StartMoving)
    holder:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        entry.x = math.floor(cx - ux + 0.5)
        entry.y = math.floor(cy - uy + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", entry.x, entry.y)
    end)

    local preview = CreateFrame("Frame", nil, holder)
    preview:SetAllPoints()
    preview:SetAlpha(0.6)
    preview:Hide()
    CreateVisual(preview, preview, entry)
    local label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", preview, "TOP", 0, 2)
    label:SetText(VB:GetSpellName(entry.spellID) or "?")
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
    pcall(c.SetAuraGroupCandidateFilters, c, GROUP_KEY, { includeSpellIDs = w.ids })
    pcall(c.SetEnabled, c, true)
    c:Show()
    pcall(c.SetUnit, c, w.entry.unit)
    pcall(c.UpdateAllAuras, c)
end

-- present: the single button carries the display
local function BuildPresentContainer(w)
    local entry, holder = w.entry, w.holder
    local c = NewAuraContainer(w)
    if not c then return nil end

    local isIcon = entry.display == "icon"
    local added = pcall(c.AddAuraGroup, c, GROUP_KEY, FilterOf(entry), {
        maxFrameCount = 1,
        initializeFrame = function(button)
            if isIcon then
                VB.StyleAuraButton(entry.size, entry.kind == "HARMFUL", button)
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

-------------------------------------------------
-- Addon-rendered display (clients without AuraContainers)
-------------------------------------------------
local function BuildLuaDisplay(w)
    local entry = w.entry
    local f = CreateFrame("Frame", nil, w.holder)
    f:SetAllPoints()
    f:Hide()
    if entry.display == "icon" then
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(VB:GetSpellIcon(entry.spellID))
        f.icon = icon

        local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(true)
        cd:SetReverse(true)
        f.cooldown = cd

        local count = f:CreateFontString(nil, "OVERLAY")
        count:SetFont(VB.config.font, math.max(8, math.floor(entry.size * 0.35)), "OUTLINE")
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
    if not file then return false end
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

-- true / false when the addon can tell, nil when it cannot (secret auras)
local function ReadAura(w)
    local entry = w.entry
    if not UnitExists(entry.unit) then return false end

    local auras = VB:GetAuras(entry.unit, (FilterOf(entry):gsub("|", " ")))
    local unreadable = false
    for _, a in ipairs(auras) do
        local ok, match = pcall(function()
            return (a.spellId and w.ids[a.spellId]) or (w.name and a.name == w.name)
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
    if not probe or w.entry.unit ~= "player" then return nil end
    if not (C_Spell and C_Spell.GetSpellPowerCost) then return nil end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, probe)
    if not ok or type(costs) ~= "table" or not costs[1] then return nil end
    local cost = costs[1].cost
    if cost == nil or (issecretvalue and issecretvalue(cost)) then return nil end
    return cost == 0
end

local function ShowLuaAura(f, aura)
    if f.icon and aura then
        local okI, tex = pcall(function() return aura.icon end)
        if okI and tex then pcall(f.icon.SetTexture, f.icon, tex) end
        pcall(function()
            if aura.duration and aura.duration > 0 and aura.expirationTime then
                f.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
            else
                f.cooldown:Clear()
            end
            local n = aura.applications or 0
            f.count:SetText(n > 1 and n or "")
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
        else
            shown = active
        end
    end

    if w.lua and shown ~= nil then
        if shown and entry.show ~= "missing" then
            ShowLuaAura(w.lua, aura)
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

local ticker
local function UpdateAll()
    for _, w in ipairs(watchers) do UpdateWatcher(w) end
end

-- No target, nothing to watch: the container would call the aura "missing"
local function UpdateTargetHolders()
    for _, w in ipairs(watchers) do
        if w.entry.unit == "target" then
            w.holder:SetShown(UnitExists("target") or VB._screenAuraPreview)
        end
    end
end

-------------------------------------------------
-- Build / refresh
-------------------------------------------------
function VB:RebuildScreenAuras()
    for _, w in ipairs(watchers) do
        RemoveGameSounds(w)
        w.holder:Hide()
        if w.container then pcall(w.container.SetEnabled, w.container, false) end
    end
    wipe(watchers)

    for i, entry in ipairs(VB.screenAuras or {}) do
        Normalize(entry)
        if entry.spellID and entry.enabled ~= false then
            local w = { entry = entry, index = i }
            w.ids, w.name = ResolveIDs(entry)
            w.holder = CreateHolder(entry)
            if VB:HasAuraContainers() then
                if entry.show == "missing" then
                    w.container = BuildMissingContainer(w)
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

    VB:SetScreenAuraPreview(VB._screenAuraPreview)

    if #watchers > 0 and not ticker then
        ticker = C_Timer.NewTicker(0.15, UpdateAll)
    elseif #watchers == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- New ranks learned: widen the ID sets without rebuilding the frames
function VB:RefreshScreenAuraIDs()
    for _, w in ipairs(watchers) do
        w.ids, w.name = ResolveIDs(w.entry)
        if w.container then
            pcall(w.container.SetAuraGroupCandidateFilters, w.container, GROUP_KEY,
                  { includeSpellIDs = w.ids })
            pcall(w.container.UpdateAllAuras, w.container)
        end
        if w.gameSounds then
            RemoveGameSounds(w)
            w.gameSounds = RegisterGameSounds(w)
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
    UpdateTargetHolders()
end

-- The container's unit token stays "target": ask it to re-read on a new target
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function()
    for _, w in ipairs(watchers) do
        if w.container and w.entry.unit == "target" then
            pcall(w.container.UpdateAllAuras, w.container)
        end
    end
    UpdateTargetHolders()
end)
