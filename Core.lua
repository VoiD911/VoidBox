--[[
    VoidBox - Raid frames pour healers avec click-casting
    Compatible WoW 12.0+ (Midnight)
]]

local addonName, VB = ...
_G.VoidBox = VB

-- Namespaces
VB.frames = {}
VB.unitButtons = {}
VB.config = {}
VB.clickCastings = {}

-- Variables
VB.playerClass = nil
VB.playerSpecID = nil
VB.groupType = "solo" -- solo, party, raid

-- Defaults
VB.defaults = {
    frameWidth = 80,
    frameHeight = 40,
    frameSpacing = 2,
    maxColumns = 5,
    orientation = "HORIZONTAL", -- HORIZONTAL or VERTICAL
    roleOrder = "TDH", -- TDH, THD, HDT, HTD, DTH, DHT
    growthDirection = "DOWN", -- DOWN, UP, RIGHT, LEFT
    showPowerBar = true,
    powerBarHeight = 4,
    texture = "Interface\\TargetingFrame\\UI-StatusBar",
    font = "Fonts\\FRIZQT__.TTF",
    fontSize = 11,
    showName = true,
    showHealth = true,
    healthFormat = "deficit", -- current, percent, deficit, none
    classColors = true,
    locked = false,
    position = { point = "CENTER", x = 0, y = 0 },
    clickCastings = {
        { "type1", "target", nil },           -- Left click = target
        { "type2", "togglemenu", nil },       -- Right click = menu
    },
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
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

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
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            VB:OnSpecChanged()
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
    "orientation", "roleOrder", "growthDirection",
    "showPowerBar", "powerBarHeight",
    "texture", "font", "fontSize",
    "showName", "showHealth", "healthFormat",
    "classColors", "locked", "position",
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
    if GetSpecialization then
        VB.playerSpecID = GetSpecializationInfo(GetSpecialization())
    end
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
    VB:UpdateGroupType()
    VB:UpdateAllFrames()
end

function VB:OnGroupRosterUpdate()
    VB:UpdateGroupType()
    VB:UpdateAllFrames()
end

function VB:OnSpecChanged()
    if GetSpecialization then
        VB.playerSpecID = GetSpecializationInfo(GetSpecialization())
    end
    VB:ApplyClickCastingsToAllFrames()
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
    
    for _, button in pairs(VB.unitButtons) do
        button:Hide()
    end
    
    local units = VB:GetUnitsToDisplay()
    
    local col, row = 0, 0
    local groupSize = VB.config.maxColumns or 5
    local width = VB.config.frameWidth or 80
    local height = VB.config.frameHeight or 40
    local spacing = VB.config.frameSpacing or 2
    local vertical = VB.config.orientation == "VERTICAL"
    
    for i, unit in ipairs(units) do
        local button = VB:GetOrCreateUnitButton(unit, i)
        button:SetSize(width, height)
        
        local x, y
        if vertical then
            -- Vertical: stack rows down, new column every groupSize
            x = col * (width + spacing)
            y = -row * (height + spacing)
            row = row + 1
            if row >= groupSize then
                row = 0
                col = col + 1
            end
        else
            -- Horizontal: stack columns right, new row every groupSize
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
    
    table.sort(units, function(a, b)
        local roleA = UnitGroupRolesAssigned(a) or "NONE"
        local roleB = UnitGroupRolesAssigned(b) or "NONE"
        local prioA = rolePriority[roleA] or 2
        local prioB = rolePriority[roleB] or 2
        if prioA ~= prioB then return prioA < prioB end
        return a < b
    end)
    
    return units
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
        VB:Print(VB.L["FRAMES_LOCKED"])
    elseif msg == "unlock" then
        VB.config.locked = false
        VB.frames.main:EnableMouse(true)
        if VB.frames.handle then VB.frames.handle:Show() end
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
    elseif msg == "debughealth" then
        VB:Print("=== Debug Health Values ===")
        local units = VB:GetUnitsToDisplay()
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
    elseif msg == "debug" then
        VB.config.debug = not VB.config.debug
        VB:Print("Debug: " .. (VB.config.debug and "ON" or "OFF"))
        if VB.config.debug then
            VB:Print("  Group type: " .. tostring(VB.groupType))
            VB:Print("  Units: " .. #VB:GetUnitsToDisplay())
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
    end
end
