--[[
    VoidBox - Screen Auras

    Icons or drawings placed anywhere on the screen, shown while a chosen buff
    or debuff is up on the player or the target - a small WeakAuras.

    Where the client has AuraContainers (Retail 12.0, Forever) the display is
    client-rendered: a container limited to the spell's IDs holds a single
    button, and that button carries the icon or the drawing. It keeps working
    in combat, where Forever refuses every aura read (Clearcasting verified
    with /vb auratest, 2026-10-02). Elsewhere the addon reads the auras itself.

    Sounds need the addon itself to know the aura is up, so they only play
    when it can read it: always where auras are not secret, out of combat on
    Forever - and Clearcasting in combat, detected from the free Regrowth.
]]

local addonName, VB = ...

VB.screenAuras = VB.screenAuras or {}   -- saved entries, per class (set at login)
local watchers = {}                     -- runtime objects, one per enabled entry

VB.AURA_SOUNDS = {
    { value = "none" },
    { value = "raidwarning", sound = 8959 },
    { value = "readycheck", sound = 8960 },
    { value = "ping", sound = 3175 },
    { value = "invite", sound = 880 },
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

local function ColorOf(entry)
    for _, c in ipairs(VB.AURA_COLORS) do
        if c.value == entry.color then return unpack(c.rgb) end
    end
    return 1, 0.85, 0
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
        display = "icon",       -- icon | frame | disc
        size = 48,
        color = "yellow",
        sound = "none",
        x = 0,
        y = 150,
        enabled = true,
    }
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

-------------------------------------------------
-- Drawing: a square frame or a filled disc covering `anchor`.
-- The textures belong to `owner`, so they show and hide with it.
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
    preview:Hide()
    if entry.display == "icon" then
        local t = preview:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture(VB:GetSpellIcon(entry.spellID))
        t:SetAlpha(0.6)
    else
        for _, region in ipairs(CreateDrawing(preview, preview, entry)) do
            region:SetAlpha(0.6)
        end
    end
    local label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", preview, "TOP", 0, 2)
    label:SetText(VB:GetSpellName(entry.spellID) or "?")
    holder.preview = preview
    return holder
end

-------------------------------------------------
-- Client-rendered display (AuraContainer)
-------------------------------------------------
local function BuildContainer(w)
    local entry, holder = w.entry, w.holder
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    if not ok or not c then return nil end

    pcall(c.SetEditModePreviewEnabled, c, false)
    pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
    pcall(c.SetFlowLayoutPadding, c, 0, 0, 0, 0)

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
        end,
    })
    if not added then return nil end

    pcall(c.SetAuraGroupMaxFrameCount, c, GROUP_KEY, 1)
    pcall(c.SetAuraGroupCandidateFilters, c, GROUP_KEY, { includeSpellIDs = w.ids })
    c:SetAllPoints(holder)
    pcall(c.SetEnabled, c, true)
    c:Show()
    pcall(c.SetUnit, c, entry.unit)
    pcall(c.UpdateAllAuras, c)
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
    return f
end

-------------------------------------------------
-- Detection (for sounds, and the display on clients without containers)
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
    if f.icon then
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

local function PlayAuraSound(key)
    for _, s in ipairs(VB.AURA_SOUNDS) do
        if s.value == key and s.sound then
            pcall(PlaySound, s.sound, "Master")
            return
        end
    end
end

local function UpdateWatcher(w)
    local active, aura = ReadAura(w)
    local cost = CostSaysActive(w)
    if cost == true then
        active = true
    elseif active == nil then
        active = cost
    end

    if w.lua then
        if active == true and aura then
            ShowLuaAura(w.lua, aura)
        elseif active == true then
            w.lua:Show()
        elseif active == false then
            w.lua:Hide()
        end
    end

    -- nil means "cannot tell": keep the last known state
    if active ~= nil then
        if active and w.primed and not w.active and not VB._screenAuraPreview then
            PlayAuraSound(w.entry.sound)
        end
        w.active = active
        w.primed = true
    end
end

local ticker
local function UpdateAll()
    for _, w in ipairs(watchers) do UpdateWatcher(w) end
end

-------------------------------------------------
-- Build / refresh
-------------------------------------------------
function VB:RebuildScreenAuras()
    for _, w in ipairs(watchers) do
        w.holder:Hide()
        if w.container then pcall(w.container.SetEnabled, w.container, false) end
    end
    wipe(watchers)

    for i, entry in ipairs(VB.screenAuras or {}) do
        if entry.spellID and entry.enabled ~= false then
            local w = { entry = entry, index = i }
            w.ids, w.name = ResolveIDs(entry)
            w.holder = CreateHolder(entry)
            if VB:HasAuraContainers() then w.container = BuildContainer(w) end
            if not w.container then w.lua = BuildLuaDisplay(w) end
            watchers[#watchers + 1] = w
        end
    end

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
    end
end

-- While the Auras tab is open every aura shows a preview and can be dragged
function VB:SetScreenAuraPreview(on)
    VB._screenAuraPreview = on and true or false
    for _, w in ipairs(watchers) do
        w.holder.preview:SetShown(VB._screenAuraPreview)
        w.holder:EnableMouse(VB._screenAuraPreview)
    end
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
end)
