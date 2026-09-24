--[[
    VoidBox - Raid frames pour healers avec click-casting
    Compatible WoW 12.0+ (Midnight)
]]

local addonName, VB = ...
_G.VoidBox = VB

-- Namespaces
VB.frames = {}
VB.unitButtons = {}
VB.tankButtons = {}
VB.petButtons = {}
VB.config = {}
VB.clickCastings = {}

-- Variables
VB.playerClass = nil
VB.playerSpecID = nil
VB.groupType = "solo" -- solo, party, raid

-- FRIZQT__.TTF (the client's default font) has no glyphs for non-Latin scripts,
-- so names render as boxes for these locales. Blizzard ships locale-specific
-- fonts that do have the right glyphs; use those as the addon's default instead.
VB.DEFAULT_LATIN_FONT = "Fonts\\FRIZQT__.TTF"
VB.LOCALE_FONTS = {
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
    koKR = "Fonts\\2002.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    zhTW = "Fonts\\bLEI00D.TTF",
}

-- Defaults
VB.defaults = {
    frameWidth = 130,
    frameHeight = 65,
    scaleWidth = 100,
    scaleHeight = 100,
    frameSpacing = 2,
    maxColumns = 5,
    orientation = "HORIZONTAL", -- HORIZONTAL or VERTICAL
    roleOrder = "TDH", -- TDH, THD, HDT, HTD, DTH, DHT
    growthDirection = "DOWN", -- DOWN, UP, RIGHT, LEFT
    showPowerBar = true,
    powerBarHeight = 4,
    texture = "Interface\\TargetingFrame\\UI-StatusBar",
    font = VB.LOCALE_FONTS[GetLocale()] or VB.DEFAULT_LATIN_FONT,
    fontSize = 11,
    showName = true,
    showHealth = true,
    healthFormat = "deficit", -- current, percent, deficit, none
    classColors = true,
    locked = false,
    showTankFrame = false,
    tankFramePosition = nil,
    showPetFrame = false,
    petFramePosition = nil,
    showDebuffs = true,
    showBuffs = true,
    debuffIconSize = 18,
    buffIconSize = 12,
    hideExhaustionDebuffs = true,
    showDispelHighlight = true,
    showTooltipBindings = true,
    keepGroupsTogether = false,
    hideWhenSolo = false,
    autoTargetOnCast = false,
    fallbackWheelBindings = false,  -- opt-in, see ApplyFallbackKeyBindings
    position = { point = "CENTER", x = 0, y = 0 },
    clickCastings = {},
}

-------------------------------------------------
-- Utility Functions
-------------------------------------------------
function VB:Print(msg)
    print("|cFF9966FF[VoidBox]|r " .. tostring(msg))
end

function VB:Debug(msg)
    if VB.config.debug then
        print("|cFFFFFF00[VB Debug]|r " .. tostring(msg))
    end
end

-- Deep copy table
function VB:CopyTable(src)
    if type(src) ~= "table" then return src end
    local dest = {}
    for k, v in pairs(src) do
        dest[k] = VB:CopyTable(v)
    end
    return dest
end

-- Get class color
function VB:GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 0.5, 0.5, 0.5
end

-- Safe number check (secret values: tostring then tonumber gives real numbers)
function VB:SafeNumber(value, default)
    default = default or 0
    if value == nil then return default end
    local n = tonumber(tostring(value))
    if n then return n end
    return default
end

-- Format health text
function VB:FormatHealth(current, max, format)
    if format == "none" then return "" end
    current = VB:SafeNumber(current, 0)
    max = VB:SafeNumber(max, 1)
    if max == 0 then max = 1 end
    
    if format == "current" then
        return VB:AbbreviateNumber(current)
    elseif format == "percent" then
        return math.floor(current / max * 100) .. "%"
    elseif format == "deficit" then
        local deficit = max - current
        if deficit > 0 then
            return "-" .. VB:AbbreviateNumber(deficit)
        end
        return ""
    end
    return ""
end

-------------------------------------------------
-- Event Frame
-------------------------------------------------
local eventFrame = CreateFrame("Frame")
-- SafeRegisterEvent skips events this client does not know: on Forever a plain
-- RegisterEvent on an unknown event raises and aborts the rest of this file.
for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "UNIT_PET",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "LEARNED_SPELL_IN_TAB",
    "PLAYER_REGEN_ENABLED",
}) do
    VB:SafeRegisterEvent(eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            VB:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        VB:OnPlayerLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        VB:OnPlayerEnteringWorld()
    elseif event == "GROUP_ROSTER_UPDATE" then
        VB:OnGroupRosterUpdate()
    elseif event == "UNIT_PET" then
        if VB.config.showPetFrame then VB:UpdatePetFrame() end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "PLAYER_TALENT_UPDATE"
        or event == "LEARNED_SPELL_IN_TAB" then
        -- This event fires with no args or "player" depending on context
        local unit = ...
        if not unit or unit == "player" then
            VB:OnSpecChanged()
            -- Refresh role icons (spec change = role change)
            for _, button in pairs(VB.unitButtons) do
                VB:UpdateRole(button)
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if VB.pendingUpdate then
            VB.pendingUpdate = false
            VB:UpdateAllFrames()
        end
        if VB.pendingClickCastings then
            VB.pendingClickCastings = false
            VB:ApplyClickCastingsToAllFrames()
        end
    end
end)

-- Profile keys (appearance/layout settings that belong in a profile)
VB.profileKeys = {
    "frameWidth", "frameHeight", "frameSpacing", "maxColumns",
    "scaleWidth", "scaleHeight",
    "orientation", "roleOrder", "growthDirection",
    "showPowerBar", "powerBarHeight",
    "texture", "font", "fontSize",
    "showName", "showHealth", "healthFormat",
    "classColors", "locked", "position",
    "showTankFrame", "tankFramePosition",
    "showPetFrame", "petFramePosition",
    "showDebuffs", "showBuffs",
    "debuffIconSize", "buffIconSize",
    "showDispelHighlight",
    "showTooltipBindings",
    "keepGroupsTogether",
    "hideWhenSolo",
    "autoTargetOnCast",
    "fallbackWheelBindings",
}

-------------------------------------------------
-- Initialization
-------------------------------------------------
function VB:OnAddonLoaded()
    if not VoidBoxDB then
        VoidBoxDB = {}
    end
    
    VB.playerClass = select(2, UnitClass("player"))
    
    -- === Profile system migration ===
    -- If no profiles table exists, migrate existing flat config into "Default" profile
    if not VoidBoxDB.profiles then
        VoidBoxDB.profiles = {}
        local defaultProfile = {}
        for _, key in ipairs(VB.profileKeys) do
            if VoidBoxDB[key] ~= nil then
                defaultProfile[key] = VoidBoxDB[key]
                VoidBoxDB[key] = nil  -- clean up root level
            end
        end
        -- Merge defaults for any missing keys
        for _, key in ipairs(VB.profileKeys) do
            if defaultProfile[key] == nil and VB.defaults[key] ~= nil then
                defaultProfile[key] = VB:CopyTable(VB.defaults[key])
            end
        end
        VoidBoxDB.profiles["Default"] = defaultProfile
        VoidBoxDB.activeProfile = "Default"
    end
    
    if not VoidBoxDB.activeProfile or not VoidBoxDB.profiles[VoidBoxDB.activeProfile] then
        VoidBoxDB.activeProfile = "Default"
    end
    if not VoidBoxDB.profiles["Default"] then
        local defaultProfile = {}
        for _, key in ipairs(VB.profileKeys) do
            defaultProfile[key] = VB:CopyTable(VB.defaults[key])
        end
        VoidBoxDB.profiles["Default"] = defaultProfile
    end

    -- Fix pre-existing profiles stuck on the Latin-only default font when the
    -- client locale needs a different font to render its glyphs (e.g. ruRU)
    local localeFont = VB.LOCALE_FONTS[GetLocale()]
    if localeFont then
        for _, profile in pairs(VoidBoxDB.profiles) do
            if profile.font == VB.DEFAULT_LATIN_FONT then
                profile.font = localeFont
            end
        end
    end

    -- v1.18.2: aura icons were silently capped at a third of the frame height
    -- (18px at 100%). The cap is gone and frames grow to fit instead, so bring
    -- every stored size down to what was actually displayed: nothing changes on
    -- screen at update, and the sliders work from there.
    if not VoidBoxDB.auraSizeCapMigrated then
        for _, profile in pairs(VoidBoxDB.profiles) do
            local sh = (profile.scaleHeight or 100) / 100
            local oldCap = math.floor(math.floor(55 * sh) / 3)
            profile.debuffIconSize = math.min(oldCap, math.max(6, profile.debuffIconSize or 21))
            profile.buffIconSize = math.min(oldCap, math.max(6, profile.buffIconSize or 12))
        end
        VoidBoxDB.auraSizeCapMigrated = true
    end

    -- Merge defaults into active profile for any missing keys
    local activeProfile = VoidBoxDB.profiles[VoidBoxDB.activeProfile]
    for _, key in ipairs(VB.profileKeys) do
        if activeProfile[key] == nil and VB.defaults[key] ~= nil then
            activeProfile[key] = VB:CopyTable(VB.defaults[key])
        end
    end
    
    -- VB.config points to the active profile
    VB.config = activeProfile
    
    -- === Click-castings per class (global, not per profile) ===
    if not VoidBoxDB.classBindings then
        VoidBoxDB.classBindings = {}
    end
    
    -- Migrer les anciens bindings globaux vers la classe actuelle
    if VoidBoxDB.clickCastings and #VoidBoxDB.clickCastings > 0 then
        if not VoidBoxDB.classBindings[VB.playerClass] then
            VoidBoxDB.classBindings[VB.playerClass] = VoidBoxDB.clickCastings
        end
        VoidBoxDB.clickCastings = nil
    end
    
    -- Migrer depuis VoidBoxCharDB si ça existe (ancien système per-char)
    if VoidBoxCharDB and VoidBoxCharDB.clickCastings and #VoidBoxCharDB.clickCastings > 0 then
        if not VoidBoxDB.classBindings[VB.playerClass] then
            VoidBoxDB.classBindings[VB.playerClass] = VoidBoxCharDB.clickCastings
        end
    end
    
    -- Charger les bindings de la classe, ou créer les défauts
    if not VoidBoxDB.classBindings[VB.playerClass] then
        VoidBoxDB.classBindings[VB.playerClass] = VB:CopyTable(VB.defaults.clickCastings)
    end
    
    -- Runtime reference to class-specific bindings
    VB.clickCastings = VoidBoxDB.classBindings[VB.playerClass]

    -- === Tracked (custom) buffs per class ===
    -- Spells are class-specific, so this follows click-castings rather than
    -- profiles. Stored as the spell IDs the player dropped in; every rank of
    -- each spell is resolved from the spellbook at runtime.
    if not VoidBoxDB.classCustomBuffs then
        VoidBoxDB.classCustomBuffs = {}
    end
    if not VoidBoxDB.classCustomBuffs[VB.playerClass] then
        VoidBoxDB.classCustomBuffs[VB.playerClass] = {}
    end
    VB.customBuffs = VoidBoxDB.classCustomBuffs[VB.playerClass]
    
    VB:InitMinimapButton()
    
    VB:Print(VB.L["LOADED"] .. " (" .. VB.playerClass .. ") - /vb " .. VB.L["OPTIONS"])
end

function VB:MergeDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = VB:CopyTable(v)
        elseif type(v) == "table" and type(saved[k]) == "table" then
            if k ~= "clickCastings" and k ~= "position" then
                VB:MergeDefaults(saved[k], v)
            end
        end
    end
end

-------------------------------------------------
-- Profile Management
-------------------------------------------------
function VB:GetProfileList()
    local list = {}
    if VoidBoxDB and VoidBoxDB.profiles then
        for name in pairs(VoidBoxDB.profiles) do
            table.insert(list, name)
        end
    end
    table.sort(list)
    return list
end

function VB:GetActiveProfileName()
    return VoidBoxDB and VoidBoxDB.activeProfile or "Default"
end

function VB:SwitchProfile(name)
    if not VoidBoxDB.profiles[name] then return false end
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_CONFIG_COMBAT"])
        return false
    end
    
    VoidBoxDB.activeProfile = name
    VB.config = VoidBoxDB.profiles[name]
    
    -- Merge defaults for any missing keys
    for _, key in ipairs(VB.profileKeys) do
        if VB.config[key] == nil and VB.defaults[key] ~= nil then
            VB.config[key] = VB:CopyTable(VB.defaults[key])
        end
    end
    
    -- Refresh UI
    if VB.frames.main then
        local pos = VB.config.position
        if pos and pos.point then
            VB.frames.main:ClearAllPoints()
            VB.frames.main:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        end
        VB.frames.main:EnableMouse(not VB.config.locked)
        if VB.frames.handle then
            VB.frames.handle:SetShown(not VB.config.locked)
        end
    end
    if VB.frames.tankFrame then
        local tpos = VB.config.tankFramePosition
        if tpos and tpos.point then
            VB.frames.tankFrame:ClearAllPoints()
            VB.frames.tankFrame:SetPoint(tpos.point, UIParent, tpos.relPoint or tpos.point, tpos.x or 0, tpos.y or 0)
        end
    end
    VB:UpdateAllFrames()
    VB:ApplyClickCastingsToAllFrames()
    
    VB:Print(VB.L["PROFILE_SWITCHED"] .. " " .. name)
    return true
end

function VB:CreateProfile(name)
    if not name or name == "" then return false end
    if VoidBoxDB.profiles[name] then return false end
    
    -- New profile from defaults
    local profile = {}
    for _, key in ipairs(VB.profileKeys) do
        profile[key] = VB:CopyTable(VB.defaults[key])
    end
    VoidBoxDB.profiles[name] = profile
    return true
end

function VB:CopyProfile(srcName, destName)
    if not destName or destName == "" then return false end
    if not VoidBoxDB.profiles[srcName] then return false end
    if VoidBoxDB.profiles[destName] then return false end
    
    VoidBoxDB.profiles[destName] = VB:CopyTable(VoidBoxDB.profiles[srcName])
    return true
end

function VB:DeleteProfile(name)
    if name == "Default" then return false end  -- Can't delete Default
    if not VoidBoxDB.profiles[name] then return false end
    
    VoidBoxDB.profiles[name] = nil
    
    -- If we deleted the active profile, switch to Default
    if VoidBoxDB.activeProfile == name then
        VB:SwitchProfile("Default")
    end
    return true
end

function VB:OnPlayerLogin()
    VB.playerSpecID = VB:GetPlayerSpecID()
    VB:BuildForeverHealBuffNames()
    VB:BuildHealBuffIDSet()
    VB:ForeverStartupNotice()
    VB:BuildDispelColorCurve()
    VB:CreateMainFrame()
    VB:InitClickCastings()
end

function VB:OnPlayerEnteringWorld()
    -- Au /reload, PLAYER_ENTERING_WORLD peut fire avant PLAYER_LOGIN
    -- On s'assure que le main frame existe
    if not VB.frames.main then
        VB:CreateMainFrame()
        VB:InitClickCastings()
    end
    if not VB._rangeSpellID then
        VB:FindRangeCheckSpell()
    end
    -- Spell names can still be uncached at PLAYER_LOGIN; rebuild once the world
    -- is up so the HoT name table is not left half-empty for the session.
    VB:BuildForeverHealBuffNames()
    VB:BuildHealBuffIDSet()
    VB:RefreshAuraContainerFilters()
    VB:UpdateGroupType()
    VB:UpdateAllFrames()
end

function VB:OnGroupRosterUpdate()
    VB:UpdateGroupType()
    VB:UpdateAllFrames()
end

function VB:OnSpecChanged()
    VB.playerSpecID = VB:GetPlayerSpecID()
    VB:BuildForeverHealBuffNames()
    VB:BuildHealBuffIDSet()
    VB:RefreshAuraContainerFilters()
    VB:BuildDispelColorCurve()
    VB:ApplyClickCastingsToAllFrames()
    -- Re-detect range check spell (talents may have changed)
    VB:FindRangeCheckSpell()
end

-------------------------------------------------
-- Group Type Detection
-------------------------------------------------
function VB:UpdateGroupType()
    local oldType = VB.groupType
    
    if IsInRaid() then
        VB.groupType = "raid"
    elseif IsInGroup() then
        VB.groupType = "party"
    else
        VB.groupType = "solo"
    end
    
    if oldType ~= VB.groupType then
        VB:Debug("Group type changed: " .. oldType .. " -> " .. VB.groupType)
    end
end

-------------------------------------------------
-- Main Frame
-------------------------------------------------
function VB:CreateMainFrame()
    if VB.frames.main then return end
    
    local main = CreateFrame("Frame", "VoidBoxMain", UIParent)
    main:SetSize(400, 300)
    
    local pos = VB.config.position
    if pos and pos.point then
        main:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    main:SetClampedToScreen(true)
    
    main:SetMovable(true)
    main:EnableMouse(not VB.config.locked)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", function(self)
        if not VB.config.locked then
            self:StartMoving()
        end
    end)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        VB.config.position = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    
    VB.frames.main = main
    
    local container = CreateFrame("Frame", "VoidBoxContainer", VB.frames.main)
    container:SetAllPoints()
    VB.frames.container = container
    
    -- Drag handle (petit carré violet pour déplacer)
    local handle = CreateFrame("Button", nil, main, "BackdropTemplate")
    handle:SetSize(14, 14)
    handle:SetPoint("TOPRIGHT", main, "TOPLEFT", -2, 0)
    handle:SetFrameStrata("HIGH")
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    handle:SetBackdropColor(0.6, 0.4, 1, 0.8)
    handle:SetBackdropBorderColor(0.3, 0.2, 0.5, 1)
    handle:SetMovable(false)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    
    handle:SetScript("OnDragStart", function()
        if not VB.config.locked then
            main:StartMoving()
        end
    end)
    handle:SetScript("OnDragStop", function()
        main:StopMovingOrSizing()
        local point, _, relPoint, x, y = main:GetPoint()
        VB.config.position = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    handle:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            VB:ShowConfig()
        end
    end)
    handle:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.8, 0.5, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cFF9966FFVoidBox|r")
        GameTooltip:AddLine(VB.L["DRAG_TO_MOVE"], 1, 1, 1)
        GameTooltip:AddLine(VB.L["RIGHT_CLICK_CONFIG"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.4, 1, 0.8)
        GameTooltip:Hide()
    end)
    
    handle:SetShown(not VB.config.locked)
    VB.frames.handle = handle
end

-------------------------------------------------
-- Update All Frames
-------------------------------------------------
function VB:UpdateAllFrames()
    if not VB.frames.container then return end
    
    if InCombatLockdown() then
        VB:Debug("UpdateAllFrames delayed - in combat")
        VB.pendingUpdate = true
        return
    end
    
    -- Hide when solo
    if VB.config.hideWhenSolo and VB.groupType == "solo" then
        if VB.frames.main then VB.frames.main:Hide() end
        if VB.frames.handle then VB.frames.handle:Hide() end
        if VB.frames.tankFrame then VB.frames.tankFrame:Hide() end
        if VB.frames.petFrame then VB.frames.petFrame:Hide() end
        return
    else
        if VB.frames.main then VB.frames.main:Show() end
        if VB.frames.handle and not VB.config.locked then VB.frames.handle:Show() end
    end
    
    for _, button in pairs(VB.unitButtons) do
        button:Hide()
    end
    
    local units, isGrouped = VB:GetUnitsToDisplay()
    
    local col, row = 0, 0
    local groupSize = VB.config.maxColumns or 5
    -- Compute scaled frame size
    local sw = (VB.config.scaleWidth or 100) / 100
    local sh = (VB.config.scaleHeight or 100) / 100
    local width, height = VB:GetFrameSize()
    local spacing = VB.config.frameSpacing or 2
    local vertical = VB.config.orientation == "VERTICAL"
    
    local totalUnits = 0
    local maxGroupLen = 0
    local numGroups = 0
    
    if isGrouped then
        -- Layout by raid subgroups
        -- Vertical: each group = a column (left to right), members top to bottom
        -- Horizontal: each group = a row (top to bottom), members left to right
        local sortedGroups = {}
        for sg in pairs(units) do table.insert(sortedGroups, sg) end
        table.sort(sortedGroups)
        
        numGroups = #sortedGroups
        local groupIdx = 0
        
        for _, sg in ipairs(sortedGroups) do
            local grpUnits = units[sg]
            for memberIdx, unit in ipairs(grpUnits) do
                totalUnits = totalUnits + 1
                local button = VB:GetOrCreateUnitButton(unit, totalUnits)
                VB:ResizeUnitButton(button)
                
                local x, y
                if vertical then
                    -- Group = column, members = rows
                    x = groupIdx * (width + spacing)
                    y = -(memberIdx - 1) * (height + spacing)
                else
                    -- Group = row, members = columns
                    x = (memberIdx - 1) * (width + spacing)
                    y = -groupIdx * (height + spacing)
                end
                
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", VB.frames.container, "TOPLEFT", x, y)
                button:Show()
                VB:UpdateUnitButton(button)
            end
            if #grpUnits > maxGroupLen then maxGroupLen = #grpUnits end
            groupIdx = groupIdx + 1
        end
        
        -- Resize main frame
        if vertical then
            VB.frames.main:SetSize(
                numGroups * (width + spacing) - spacing,
                maxGroupLen * (height + spacing) - spacing
            )
        else
            VB.frames.main:SetSize(
                maxGroupLen * (width + spacing) - spacing,
                numGroups * (height + spacing) - spacing
            )
        end
    else
        -- Original flat layout
        for i, unit in ipairs(units) do
            local button = VB:GetOrCreateUnitButton(unit, i)
            VB:ResizeUnitButton(button)
            
            local x, y
            if vertical then
                x = col * (width + spacing)
                y = -row * (height + spacing)
                row = row + 1
                if row >= groupSize then
                    row = 0
                    col = col + 1
                end
            else
                x = col * (width + spacing)
                y = -row * (height + spacing)
                col = col + 1
                if col >= groupSize then
                    col = 0
                    row = row + 1
                end
            end
            
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", VB.frames.container, "TOPLEFT", x, y)
            button:Show()
            VB:UpdateUnitButton(button)
        end
        
        local totalCols, totalRows
        if vertical then
            totalRows = math.min(#units, groupSize)
            totalCols = math.max(1, math.ceil(#units / groupSize))
        else
            totalCols = math.min(#units, groupSize)
            totalRows = math.max(1, math.ceil(#units / groupSize))
        end
        VB.frames.main:SetSize(
            totalCols * (width + spacing) - spacing,
            totalRows * (height + spacing) - spacing
        )
    end
    
    -- Update tank frame if enabled
    VB:UpdateTankFrame()
    -- Update pet frame if enabled
    VB:UpdatePetFrame()
end

local roleOrders = {
    ["TDH"] = { TANK = 1, DAMAGER = 2, HEALER = 3 },
    ["THD"] = { TANK = 1, HEALER = 2, DAMAGER = 3 },
    ["HDT"] = { HEALER = 1, DAMAGER = 2, TANK = 3 },
    ["HTD"] = { HEALER = 1, TANK = 2, DAMAGER = 3 },
    ["DTH"] = { DAMAGER = 1, TANK = 2, HEALER = 3 },
    ["DHT"] = { DAMAGER = 1, HEALER = 2, TANK = 3 },
}

function VB:GetUnitsToDisplay()
    local units = {}
    
    if VB.groupType == "raid" then
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. i)
        end
    elseif VB.groupType == "party" then
        table.insert(units, "player")
        for i = 1, GetNumGroupMembers() - 1 do
            table.insert(units, "party" .. i)
        end
    else
        table.insert(units, "player")
    end
    
    local rolePriority = roleOrders[VB.config.roleOrder or "TDH"] or roleOrders["TDH"]
    
    -- Keep groups together: return grouped units { [subgroup] = { units } }
    if VB.config.keepGroupsTogether and VB.groupType == "raid" then
        local groups = {}
        for _, unit in ipairs(units) do
            local subgroup = 1
            if UnitExists(unit) then
                local raidIndex = UnitInRaid(unit)
                if raidIndex then
                    local _, _, sg = GetRaidRosterInfo(raidIndex + 1)
                    if sg then subgroup = sg end
                end
            end
            if not groups[subgroup] then groups[subgroup] = {} end
            table.insert(groups[subgroup], unit)
        end
        -- Sort within each group by role
        for sg, grpUnits in pairs(groups) do
            table.sort(grpUnits, function(a, b)
                local roleA = UnitGroupRolesAssigned(a) or "NONE"
                local roleB = UnitGroupRolesAssigned(b) or "NONE"
                local prioA = rolePriority[roleA] or 2
                local prioB = rolePriority[roleB] or 2
                if prioA ~= prioB then return prioA < prioB end
                return a < b
            end)
        end
        return groups, true  -- second return = isGrouped
    end
    
    table.sort(units, function(a, b)
        local roleA = UnitGroupRolesAssigned(a) or "NONE"
        local roleB = UnitGroupRolesAssigned(b) or "NONE"
        local prioA = rolePriority[roleA] or 2
        local prioB = rolePriority[roleB] or 2
        if prioA ~= prioB then return prioA < prioB end
        return a < b
    end)
    
    return units, false
end

function VB:GetUnitsFlat()
    local units, isGrouped = VB:GetUnitsToDisplay()
    if not isGrouped then return units end
    local flat = {}
    local sortedGroups = {}
    for sg in pairs(units) do table.insert(sortedGroups, sg) end
    table.sort(sortedGroups)
    for _, sg in ipairs(sortedGroups) do
        for _, u in ipairs(units[sg]) do table.insert(flat, u) end
    end
    return flat
end

-------------------------------------------------
-- Tank Frame (separate panel for tanks only)
-------------------------------------------------
VB.tankButtonCount = 0

function VB:CreateTankFrame()
    if VB.frames.tankFrame then return end
    
    local tf = CreateFrame("Frame", "VoidBoxTankFrame", UIParent, "BackdropTemplate")
    tf:SetSize(80, 55)
    tf:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tf:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    tf:SetBackdropBorderColor(0.4, 0.2, 0.6, 0.8)
    tf:SetClampedToScreen(true)
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    
    local pos = VB.config.tankFramePosition
    if pos and pos.point then
        tf:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    elseif VB.frames.main then
        tf:SetPoint("BOTTOMLEFT", VB.frames.main, "TOPLEFT", 0, 20)
    else
        tf:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    end
    
    tf:SetScript("OnDragStart", function(self)
        if not VB.config.locked then self:StartMoving() end
    end)
    tf:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        VB.config.tankFramePosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    
    -- Label
    local label = tf:CreateFontString(nil, "OVERLAY")
    label:SetFont(VB.config.font, 8, "OUTLINE")
    label:SetPoint("BOTTOM", tf, "TOP", 0, 1)
    label:SetText("|cFF9966FFTANK|r")
    tf.label = label
    
    -- Drag handle (visible when unlocked)
    local handle = CreateFrame("Frame", nil, tf, "BackdropTemplate")
    handle:SetHeight(14)
    handle:SetPoint("TOPLEFT", tf, "TOPLEFT", 0, 14)
    handle:SetPoint("TOPRIGHT", tf, "TOPRIGHT", 0, 14)
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    handle:SetBackdropColor(0.6, 0.4, 1.0, 0.7)
    handle:SetBackdropBorderColor(0.6, 0.4, 1.0, 0.9)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not VB.config.locked then tf:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        tf:StopMovingOrSizing()
        local point, _, relPoint, x, y = tf:GetPoint()
        VB.config.tankFramePosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFF9966FFVoidBox|r Tank")
        GameTooltip:AddLine(VB.L["DRAG_TO_MOVE"], 1, 1, 1)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    local handleText = handle:CreateFontString(nil, "OVERLAY")
    handleText:SetFont(VB.config.font, 8, "OUTLINE")
    handleText:SetPoint("CENTER")
    handleText:SetText("|cFF9966FFTANK|r")
    
    handle:SetShown(not VB.config.locked)
    tf.handle = handle
    
    -- Container for tank buttons
    local container = CreateFrame("Frame", nil, tf)
    container:SetAllPoints()
    tf.container = container
    
    tf:Hide()
    VB.frames.tankFrame = tf
end

function VB:GetOrCreateTankButton(unit, index)
    local key = "tank" .. index
    if VB.tankButtons[key] then
        VB.tankButtons[key].unit = unit
        VB.tankButtons[key]:SetAttribute("unit", unit)
        return VB.tankButtons[key]
    end
    VB.tankButtonCount = VB.tankButtonCount + 1
    local button = VB:CreateUnitButton(unit, 1000 + VB.tankButtonCount)
    -- Re-parent to tank container
    button:SetParent(VB.frames.tankFrame.container)
    VB.tankButtons[key] = button
    return button
end

function VB:UpdateTankFrame()
    if not VB.frames.tankFrame then
        VB:CreateTankFrame()
    end
    
    local tf = VB.frames.tankFrame
    
    -- Hide all tank buttons first
    for _, btn in pairs(VB.tankButtons) do
        btn:Hide()
    end
    
    -- If disabled or solo, hide the frame
    if not VB.config.showTankFrame or VB.groupType == "solo" then
        tf:Hide()
        return
    end
    
    -- Find tank units
    local tanks = {}
    local allUnits = VB:GetUnitsFlat()
    for _, unit in ipairs(allUnits) do
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit) or "NONE"
            if role == "TANK" then
                table.insert(tanks, unit)
            end
        end
    end
    
    if #tanks == 0 then
        tf:Hide()
        return
    end
    
    -- Compute sizes
    local sw = (VB.config.scaleWidth or 100) / 100
    local sh = (VB.config.scaleHeight or 100) / 100
    local width, height = VB:GetFrameSize()
    local spacing = VB.config.frameSpacing or 2
    
    -- Layout tanks vertically
    for i, unit in ipairs(tanks) do
        local button = VB:GetOrCreateTankButton(unit, i)
        VB:ResizeUnitButton(button)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", tf.container, "TOPLEFT", 0, -(i - 1) * (height + spacing))
        button:Show()
        VB:UpdateUnitButton(button)
    end
    
    -- Resize tank frame to fit
    local totalH = #tanks * (height + spacing) - spacing
    tf:SetSize(width, totalH)
    
    -- Lock state
    tf:EnableMouse(not VB.config.locked)
    if tf.handle then tf.handle:SetShown(not VB.config.locked) end

    tf:Show()
end

-------------------------------------------------
-- Pet Frame (separate panel for group/raid pets)
-------------------------------------------------
VB.petButtonCount = 0

-- Map a base unit token to its pet's unit token
local function GetPetUnitToken(unit)
    if unit == "player" then return "pet" end
    local group, index = unit:match("^(party)(%d+)$")
    if group then return "partypet" .. index end
    group, index = unit:match("^(raid)(%d+)$")
    if group then return "raidpet" .. index end
    return nil
end

function VB:CreatePetFrame()
    if VB.frames.petFrame then return end

    local pf = CreateFrame("Frame", "VoidBoxPetFrame", UIParent, "BackdropTemplate")
    pf:SetSize(80, 55)
    pf:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pf:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    pf:SetBackdropBorderColor(0.4, 0.2, 0.6, 0.8)
    pf:SetClampedToScreen(true)
    pf:SetMovable(true)
    pf:EnableMouse(true)
    pf:RegisterForDrag("LeftButton")

    local pos = VB.config.petFramePosition
    if pos and pos.point then
        pf:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    elseif VB.frames.main then
        pf:SetPoint("BOTTOMRIGHT", VB.frames.main, "TOPRIGHT", 0, 20)
    else
        pf:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    pf:SetScript("OnDragStart", function(self)
        if not VB.config.locked then self:StartMoving() end
    end)
    pf:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        VB.config.petFramePosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- Label
    local label = pf:CreateFontString(nil, "OVERLAY")
    label:SetFont(VB.config.font, 8, "OUTLINE")
    label:SetPoint("BOTTOM", pf, "TOP", 0, 1)
    label:SetText("|cFF9966FFPETS|r")
    pf.label = label

    -- Drag handle (visible when unlocked)
    local handle = CreateFrame("Frame", nil, pf, "BackdropTemplate")
    handle:SetHeight(14)
    handle:SetPoint("TOPLEFT", pf, "TOPLEFT", 0, 14)
    handle:SetPoint("TOPRIGHT", pf, "TOPRIGHT", 0, 14)
    handle:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    handle:SetBackdropColor(0.6, 0.4, 1.0, 0.7)
    handle:SetBackdropBorderColor(0.6, 0.4, 1.0, 0.9)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not VB.config.locked then pf:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        pf:StopMovingOrSizing()
        local point, _, relPoint, x, y = pf:GetPoint()
        VB.config.petFramePosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cFF9966FFVoidBox|r Pets")
        GameTooltip:AddLine(VB.L["DRAG_TO_MOVE"], 1, 1, 1)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local handleText = handle:CreateFontString(nil, "OVERLAY")
    handleText:SetFont(VB.config.font, 8, "OUTLINE")
    handleText:SetPoint("CENTER")
    handleText:SetText("|cFF9966FFPETS|r")

    handle:SetShown(not VB.config.locked)
    pf.handle = handle

    -- Container for pet buttons
    local container = CreateFrame("Frame", nil, pf)
    container:SetAllPoints()
    pf.container = container

    pf:Hide()
    VB.frames.petFrame = pf
end

function VB:GetOrCreatePetButton(unit, index)
    local key = "pet" .. index
    if VB.petButtons[key] then
        VB.petButtons[key].unit = unit
        VB.petButtons[key]:SetAttribute("unit", unit)
        return VB.petButtons[key]
    end
    VB.petButtonCount = VB.petButtonCount + 1
    local button = VB:CreateUnitButton(unit, 2000 + VB.petButtonCount)
    -- Re-parent to pet container
    button:SetParent(VB.frames.petFrame.container)
    VB.petButtons[key] = button
    return button
end

function VB:UpdatePetFrame()
    if not VB.frames.petFrame then
        VB:CreatePetFrame()
    end

    local pf = VB.frames.petFrame

    -- Hide all pet buttons first
    for _, btn in pairs(VB.petButtons) do
        btn:Hide()
    end

    -- If disabled or solo, hide the frame
    if not VB.config.showPetFrame or VB.groupType == "solo" then
        pf:Hide()
        return
    end

    -- Find pet units
    local pets = {}
    local allUnits = VB:GetUnitsFlat()
    for _, unit in ipairs(allUnits) do
        local petUnit = GetPetUnitToken(unit)
        if petUnit and UnitExists(petUnit) then
            table.insert(pets, petUnit)
        end
    end

    if #pets == 0 then
        pf:Hide()
        return
    end

    -- Compute sizes
    local sw = (VB.config.scaleWidth or 100) / 100
    local sh = (VB.config.scaleHeight or 100) / 100
    local width, height = VB:GetFrameSize()
    local spacing = VB.config.frameSpacing or 2

    -- Layout pets vertically
    for i, unit in ipairs(pets) do
        local button = VB:GetOrCreatePetButton(unit, i)
        VB:ResizeUnitButton(button)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", pf.container, "TOPLEFT", 0, -(i - 1) * (height + spacing))
        button:Show()
        VB:UpdateUnitButton(button)
    end

    -- Resize pet frame to fit
    local totalH = #pets * (height + spacing) - spacing
    pf:SetSize(width, totalH)

    -- Lock state
    pf:EnableMouse(not VB.config.locked)
    if pf.handle then pf.handle:SetShown(not VB.config.locked) end

    pf:Show()
end

-------------------------------------------------
-- Slash Commands
-------------------------------------------------
SLASH_VOIDBOX1 = "/vb"
SLASH_VOIDBOX2 = "/voidbox"
SlashCmdList["VOIDBOX"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "lock" then
        VB.config.locked = true
        VB.frames.main:EnableMouse(false)
        if VB.frames.handle then VB.frames.handle:Hide() end
        if VB.frames.tankFrame then VB.frames.tankFrame:EnableMouse(false) end
        if VB.frames.tankFrame and VB.frames.tankFrame.handle then VB.frames.tankFrame.handle:Hide() end
        if VB.frames.petFrame then VB.frames.petFrame:EnableMouse(false) end
        if VB.frames.petFrame and VB.frames.petFrame.handle then VB.frames.petFrame.handle:Hide() end
        VB:Print(VB.L["FRAMES_LOCKED"])
    elseif msg == "unlock" then
        VB.config.locked = false
        VB.frames.main:EnableMouse(true)
        if VB.frames.handle then VB.frames.handle:Show() end
        if VB.frames.tankFrame then VB.frames.tankFrame:EnableMouse(true) end
        if VB.frames.tankFrame and VB.frames.tankFrame.handle then VB.frames.tankFrame.handle:Show() end
        if VB.frames.petFrame then VB.frames.petFrame:EnableMouse(true) end
        if VB.frames.petFrame and VB.frames.petFrame.handle then VB.frames.petFrame.handle:Show() end
        VB:Print(VB.L["FRAMES_UNLOCKED"])
    elseif msg == "reset" then
        VB.config.position = { point = "CENTER", x = 0, y = 0 }
        VB.frames.main:ClearAllPoints()
        VB.frames.main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        VB:Print(VB.L["POS_RESET"])
    elseif msg == "config" or msg == "options" then
        VB:ShowConfig()
    elseif msg:find("^profile%s+") then
        local profileName = msg:match("^profile%s+(.+)")
        if profileName then
            profileName = profileName:trim()
            if VoidBoxDB.profiles[profileName] then
                VB:SwitchProfile(profileName)
            else
                VB:Print(VB.L["PROFILES"] .. ": " .. table.concat(VB:GetProfileList(), ", "))
            end
        end
    elseif msg == "profile" or msg == "profiles" then
        VB:Print(VB.L["ACTIVE_PROFILE"] .. ": |cFF9966FF" .. VB:GetActiveProfileName() .. "|r")
        VB:Print(VB.L["PROFILES"] .. ": " .. table.concat(VB:GetProfileList(), ", "))
    elseif msg == "debugauras" or msg:find("^debugauras%s+") then
        -- Probe which aura enumeration actually yields data on this client.
        -- Defaults to a friendly unit VoidBox displays, since in combat the
        -- current target is almost always a hostile mob.
        local unit = msg:match("^debugauras%s+(%S+)")
        if not unit then
            for _, u in ipairs(VB:GetUnitsFlat()) do
                if UnitExists(u) and not UnitIsUnit(u, "player") then unit = u break end
            end
            unit = unit or "player"
        end

        VB:Print("=== Debug Auras (" .. unit .. ": " .. (UnitName(unit) or "?") .. ") ===")
        VB:Print("  player in combat: " .. tostring(InCombatLockdown())
            .. " - unit in combat: " .. tostring(UnitAffectingCombat(unit))
            .. " - ShouldAurasBeSecret: " .. tostring(VB:AurasAreSecret()))

        -- 1) GetUnitAuras per filter
        for _, f in ipairs({ "HELPFUL", "HELPFUL PLAYER", "HELPFUL RAID",
                             "HELPFUL RAID_IN_COMBAT", "HELPFUL RAID_IN_COMBAT PLAYER" }) do
            local rows = VB:GetAuras(unit, f)
            local first = rows[1]
            VB:Print(("  GetUnitAuras[%s] rows=%d readable=%s name=%s"):format(
                f, #rows, tostring(first and VB:AuraFieldsReadable(first)),
                tostring(first and select(2, pcall(function() return first.name end)))))
        end

        -- 2) Raw GetAuraDataByIndex: does the server-side filter make the call
        --    legal under secrecy while a bare HELPFUL raises?
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for _, f in ipairs({ "HELPFUL", "HELPFUL RAID_IN_COMBAT PLAYER" }) do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, f)
                VB:Print(("  ByIndex[%s] ok=%s %s"):format(f, tostring(ok),
                    ok and ("got=" .. tostring(aura ~= nil)) or "(raised)"))
            end
        end

        -- 3) Slot-based enumeration, the other server-side path
        if C_UnitAuras and C_UnitAuras.GetAuraSlots then
            local ok, a, b = pcall(C_UnitAuras.GetAuraSlots, unit, "HELPFUL")
            VB:Print(("  GetAuraSlots ok=%s cont=%s firstSlot=%s"):format(
                tostring(ok), tostring(a), tostring(b)))
        end

        VB:Print("  known HoT names: " .. tostring(next(VB.healBuffNames) ~= nil))

        -- 4) Per-spell access. Aura secrecy is per spell, not global, so a
        --    targeted query may answer where enumeration is refused outright.
        local probeID = 774  -- Rejuvenation rank 1
        local probeName = VB:GetSpellName(probeID)
        if C_Secrets then
            local ok1, secret1 = pcall(C_Secrets.ShouldSpellAuraBeSecret, probeID)
            local ok2, level = pcall(C_Secrets.GetSpellAuraSecrecy, probeID)
            VB:Print(("  ShouldSpellAuraBeSecret(%d)=%s/%s  GetSpellAuraSecrecy=%s/%s"):format(
                probeID, tostring(ok1), tostring(secret1), tostring(ok2), tostring(level)))
        end
        if C_UnitAuras.GetUnitAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, probeID)
            VB:Print(("  GetUnitAuraBySpellID(%d) ok=%s %s"):format(probeID, tostring(ok),
                ok and ("got=" .. tostring(aura ~= nil)) or "(raised)"))
        end
        if C_UnitAuras.GetAuraDataBySpellName and probeName then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, probeName, "HELPFUL")
            VB:Print(("  GetAuraDataBySpellName(%s) ok=%s %s"):format(probeName, tostring(ok),
                ok and ("got=" .. tostring(aura ~= nil)) or "(raised)"))
        end
    elseif msg == "debugmouseover" then
        -- Reported bug: pressing a keyboard binding while hovering a party
        -- member heals the player (or the current target) instead. The
        -- fallback keyboard path (v1.10.1+, needed because secure snippets are
        -- dead on this build - see debugsnippets) casts via a macro:
        --   /cast [@mouseover,exists,nodead][] <spell>
        -- The trailing "[]" is an unconditional fallback: if the client's
        -- "mouseover" unit token never resolves to the hovered VoidBox frame,
        -- the cast silently falls through to the current target (or self,
        -- since HoTs are self-castable). A first pass (2026-09-21) showed
        -- UPDATE_MOUSEOVER_UNIT firing correctly, but only for the player's own
        -- frame (the only one hooked at the time) - inconclusive for other
        -- party members. This version watches three signals together:
        --   1. OnEnter/OnLeave on VoidBox's own frames (hooked once at frame
        --      creation in UnitFrames.lua now, not scanned here, so frames
        --      created after the toggle are covered too)
        --   2. UPDATE_MOUSEOVER_UNIT, the client's own "mouseover" token
        --   3. Ground truth: CombatLogGetCurrentEventInfo does not exist on
        --      this client, so instead of reading the combat log, a short
        --      delay after every player cast re-reads HELPFUL|PLAYER auras on
        --      every displayed unit and reports which one(s) now carry the
        --      spell just cast - i.e. who was actually healed
        VB._debugMouseover = not VB._debugMouseover
        VB:Print("Mouseover debug: " .. (VB._debugMouseover and "ON" or "OFF")
            .. " - hover a party/raid frame, then press a keyboard binding.")

        if VB._debugMouseover then
            if not VB._mouseoverProbeFrame then
                VB._mouseoverProbeFrame = CreateFrame("Frame")
                VB._mouseoverProbeFrame:SetScript("OnEvent", function(_, event, ...)
                    if event == "UPDATE_MOUSEOVER_UNIT" then
                        local exists = UnitExists("mouseover")
                        local name = exists and UnitName("mouseover") or nil
                        VB:Print(("  [event] UPDATE_MOUSEOVER_UNIT -> exists=%s name=%s"):format(
                            tostring(exists), tostring(name)))
                    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                        local unit, _, spellID = ...
                        if unit ~= "player" or not VB._debugMouseover then return end
                        VB:Print("  [cast] player cast spellID=" .. tostring(spellID)
                            .. " - checking who has it in 0.3s...")
                        C_Timer.After(0.3, function()
                            local hits = {}
                            for _, u in ipairs(VB:GetUnitsFlat()) do
                                if UnitExists(u) then
                                    for _, aura in ipairs(VB:GetAuras(u, "HELPFUL PLAYER")) do
                                        local id = aura.spellId and VB:SafeSpellId(aura.spellId)
                                        if id == spellID then
                                            hits[#hits + 1] = (UnitName(u) or u) .. " (" .. u .. ")"
                                        end
                                    end
                                end
                            end
                            VB:Print("  [ground truth] spell is now on: "
                                .. (next(hits) and table.concat(hits, ", ") or "(nobody found - out of range of the scan, or already faded)"))
                        end)
                    end
                end)
            end
            VB:SafeRegisterEvent(VB._mouseoverProbeFrame, "UPDATE_MOUSEOVER_UNIT")
            VB:SafeRegisterEvent(VB._mouseoverProbeFrame, "UNIT_SPELLCAST_SUCCEEDED")
        else
            if VB._mouseoverProbeFrame then VB._mouseoverProbeFrame:UnregisterAllEvents() end
        end
    elseif msg == "debugwheel" then
        -- Scroll on a group member IN COMBAT with this on: the chat shows which
        -- @mouseover conditionals the secure macro engine sees as true, and
        -- whether the gate's action ran. Rebuilds the wheel gates, so out of
        -- combat only.
        if InCombatLockdown() then
            VB:Print(VB.L["CANNOT_BIND_COMBAT"])
            return
        end
        VB._debugWheel = not VB._debugWheel
        VB:Print("Wheel debug: " .. (VB._debugWheel and "ON" or "OFF")
            .. " - needs the wheel option enabled and a spell bound to the wheel.")
        VB:ApplyClickCastingsToAllFrames()
    elseif msg == "debugsnippets" then
        -- Do secure snippets actually run on this client? The Forever fallback
        -- keys off the loadstring_untainted global being absent, which was
        -- measured on build 69893 - never on the current build. This makes the
        -- client execute real snippets instead of checking for a global.
        VB:Print("=== Debug secure snippets ===")
        VB:Print("  loadstring_untainted global: " .. type(loadstring_untainted)
            .. " - in combat: " .. tostring(InCombatLockdown())
            .. " - VB.hasSecureSnippets: " .. tostring(VB.hasSecureSnippets))
        if InCombatLockdown() then
            VB:Print("  Run this out of combat.")
            return
        end

        -- 1) _onattributechanged: the snippet fires when an attribute is set
        local okF, f = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
        if okF and f then
            local okSet, errSet = pcall(f.SetAttribute, f, "_onattributechanged",
                [[ if name == "vbping" then self:SetAttribute("vbpong", value) end ]])
            local okPing, errPing = pcall(f.SetAttribute, f, "vbping", 42)
            VB:Print(("  _onattributechanged: set=%s ping=%s pong=%s %s"):format(
                tostring(okSet), tostring(okPing), tostring(f:GetAttribute("vbpong")),
                (not okSet and tostring(errSet)) or (not okPing and tostring(errPing)) or ""))
        else
            VB:Print("  SecureHandlerAttributeTemplate: " .. tostring(f))
        end

        -- 2) SecureHandlerExecute: run a snippet directly
        local okG, g = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        if okG and g and SecureHandlerExecute then
            local okE, errE = pcall(SecureHandlerExecute, g, [[ self:SetAttribute("vbexec", 7) ]])
            VB:Print(("  SecureHandlerExecute: ok=%s result=%s %s"):format(
                tostring(okE), tostring(g:GetAttribute("vbexec")), okE and "" or tostring(errE)))
        end

        -- Setting _onenter only stores text; compilation happens when a snippet
        -- runs, so only the two executions above say anything.
        VB:Print("  pong=42 and result=7 mean snippets compile and run here.")
    elseif msg == "spelllog" then
        VB:SpellLogToggle()
    elseif msg == "spellranks" or msg:find("^spellranks%s+") then
        VB:SpellLogRanks(msg:match("^spellranks%s+(.+)$"))
    elseif msg == "rezdebug" then
        VB:SpellLogRez()
    elseif msg == "debugcontainer" then
        -- Can this client do AuraContainers? They are the sanctioned way to show
        -- auras without reading them: the client tracks, filters and renders,
        -- the addon only styles. Nothing secret crosses into Lua.
        VB:Print("=== Debug AuraContainer ===")
        VB:Print("  C_AuraContainerUtil: " .. tostring(C_AuraContainerUtil ~= nil))
        if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
            local ok, info = pcall(C_XMLUtil.GetTemplateInfo, "CustomAuraContainerTemplate")
            VB:Print("  CustomAuraContainerTemplate: " .. tostring(ok and info ~= nil))
        end

        local ok, container = pcall(CreateFrame, "AuraContainer", nil, UIParent,
                                    "CustomAuraContainerTemplate")
        VB:Print("  CreateFrame(AuraContainer) ok=" .. tostring(ok)
            .. " got=" .. tostring(ok and container ~= nil))
        if not ok then
            VB:Print("  -> " .. tostring(container))
            return
        end
        if not container then return end

        local methods = {}
        for _, m in ipairs({ "SetUnit", "AddAuraGroup", "AddAuraSlot", "SetEnabled",
                             "UpdateAllAuras", "GetAuraGroupFrameCount",
                             "GetAuraGroupFrame", "SetFlowLayoutAxis",
                             "SetAuraGroupMaxFrameCount", "SetAuraGroupCandidateFilters",
                             "SetFlowLayoutAnchorPoint" }) do
            if type(container[m]) == "function" then methods[#methods + 1] = m end
        end
        VB:Print("  methods: " .. (#methods > 0 and table.concat(methods, ", ") or "(none)"))

        -- Live test against a grouped ally
        local unit
        for _, u in ipairs(VB:GetUnitsFlat()) do
            if UnitExists(u) and not UnitIsUnit(u, "player") then unit = u break end
        end
        unit = unit or "player"

        local okU = pcall(container.SetUnit, container, unit)
        local okG = pcall(container.AddAuraGroup, container, "vbProbe", "HELPFUL|PLAYER",
                          { maxFrameCount = 4 })
        pcall(container.UpdateAllAuras, container)
        local okC, count = pcall(container.GetAuraGroupFrameCount, container, "vbProbe")

        VB:Print(("  unit=%s SetUnit=%s AddAuraGroup=%s"):format(unit, tostring(okU), tostring(okG)))
        VB:Print(("  in combat=%s secret=%s -> HELPFUL||PLAYER frames=%s"):format(
            tostring(InCombatLockdown()), tostring(VB:AurasAreSecret()),
            okC and tostring(count) or "(raised)"))

        -- Tear the probe down: it is parented to UIParent and unpositioned, so
        -- leaving it enabled scatters live aura icons across the screen.
        pcall(container.SetEnabled, container, false)
        pcall(container.SetUnit, container, nil)
        container:Hide()
    elseif msg == "debugrole" then
        VB:Print("=== Debug Role Icons ===")
        local units = VB:GetUnitsFlat()
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local name = UnitName(unit) or "?"
                local role = UnitGroupRolesAssigned(unit) or "NONE"
                local specRole = "N/A"
                if UnitIsUnit(unit, "player") then
                    specRole = VB:GetPlayerSpecRole() or "N/A"
                end
                local btn = VB.unitButtons[unit]
                local iconShown = btn and btn.roleIcon and btn.roleIcon:IsShown() or false
                local iconTex = btn and btn.roleIcon and btn.roleIcon:GetTexture() or "nil"
                local iconAlpha = btn and btn.roleIcon and btn.roleIcon:GetAlpha() or 0
                VB:Print("  " .. name .. " (" .. unit .. "): role=" .. role .. " specRole=" .. specRole .. " shown=" .. tostring(iconShown) .. " tex=" .. tostring(iconTex) .. " alpha=" .. tostring(iconAlpha))
            end
        end
    elseif msg == "debughealth" then
        VB:Print("=== Debug Health Values ===")
        local units = VB:GetUnitsFlat()
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local name = UnitName(unit) or "?"
                VB:Print("--- " .. name .. " (" .. unit .. ") ---")
                
                -- format %d (known to work for display)
                local ok1, s1 = pcall(function()
                    return "h=" .. string.format("%d", UnitHealth(unit)) .. " m=" .. string.format("%d", UnitHealthMax(unit))
                end)
                VB:Print("  format: " .. (ok1 and s1 or "FAIL"))
                
                -- UnitHealthPercent exists?
                VB:Print("  UnitHealthPercent exists: " .. tostring(UnitHealthPercent ~= nil))
                
                -- UnitHealthPercent with different formats
                local ok2, s2 = pcall(function()
                    local pct = UnitHealthPercent(unit)
                    return "type=" .. type(pct) 
                        .. " %%d=" .. string.format("%d", pct)
                        .. " %%.0f=" .. string.format("%.0f", pct)
                        .. " %%.2f=" .. string.format("%.2f", pct)
                        .. " %%.4f=" .. string.format("%.4f", pct)
                        .. " %%f=" .. string.format("%f", pct)
                end)
                VB:Print("  UnitHealthPercent: " .. (ok2 and s2 or "FAIL: " .. tostring(s2)))
                
                -- UnitHealthPercent formatted as integer %
                local ok3, s3 = pcall(function()
                    return string.format("%.0f", UnitHealthPercent(unit)) .. "%"
                end)
                VB:Print("  PCT = " .. (ok3 and s3 or "FAIL: " .. tostring(s3)))
            end
        end
    elseif msg == "minimap" then
        if VB.IsMinimapButtonShown then
            local shown = VB:IsMinimapButtonShown()
            VB:SetMinimapButtonShown(not shown)
            VB:Print(not shown and VB.L["MINIMAP_SHOWN"] or VB.L["MINIMAP_HIDDEN"])
        end
    elseif msg == "debug" then
        VB.config.debug = not VB.config.debug
        VB:Print("Debug: " .. (VB.config.debug and "ON" or "OFF"))
        if VB.config.debug then
            VB:Print("  Group type: " .. tostring(VB.groupType))
            VB:Print("  Units: " .. #VB:GetUnitsFlat())
            local count = 0
            for _ in pairs(VB.unitButtons) do count = count + 1 end
            VB:Print("  Buttons created: " .. count)
            VB:Print("  Click castings: " .. #VB.clickCastings)
            VB:Print("  Main frame: " .. (VB.frames.main and "exists" or "nil"))
            VB:Print("  Container: " .. (VB.frames.container and "exists" or "nil"))
            if VB.frames.main then
                local w, h = VB.frames.main:GetSize()
                VB:Print("  Frame size: " .. math.floor(w) .. "x" .. math.floor(h))
                VB:Print("  Frame shown: " .. tostring(VB.frames.main:IsShown()))
            end
        end
    else
        VB:Print(VB.L["COMMANDS"])
        VB:Print("  /vb config - " .. VB.L["CONFIG_OPEN"])
        VB:Print("  /vb lock - " .. VB.L["LOCK"])
        VB:Print("  /vb unlock - " .. VB.L["UNLOCK"])
        VB:Print("  /vb reset - " .. VB.L["RESET_POS"])
        VB:Print("  /vb minimap - " .. VB.L["MINIMAP_TOGGLE"])
    end
end
