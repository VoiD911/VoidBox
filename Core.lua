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
    maxColumns = 8,
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

-------------------------------------------------
-- Initialization
-------------------------------------------------
function VB:OnAddonLoaded()
    if not VoidBoxDB then
        VoidBoxDB = VB:CopyTable(VB.defaults)
    else
        VB:MergeDefaults(VoidBoxDB, VB.defaults)
    end
    
    VB.playerClass = select(2, UnitClass("player"))
    
    -- Click-castings par classe
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
    
    VB.config = VoidBoxDB
    VB.config.clickCastings = VoidBoxDB.classBindings[VB.playerClass]
    
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
    local maxCols = VB.config.maxColumns or 8
    local width = VB.config.frameWidth or 80
    local height = VB.config.frameHeight or 40
    local spacing = VB.config.frameSpacing or 2
    
    for i, unit in ipairs(units) do
        local button = VB:GetOrCreateUnitButton(unit, i)
        button:SetSize(width, height)
        
        local x = col * (width + spacing)
        local y = -row * (height + spacing)
        
        if VB.config.growthDirection == "UP" then
            y = row * (height + spacing)
        elseif VB.config.growthDirection == "RIGHT" then
            x = row * (width + spacing)
            y = -col * (height + spacing)
        elseif VB.config.growthDirection == "LEFT" then
            x = -row * (width + spacing)
            y = -col * (height + spacing)
        end
        
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", VB.frames.container, "TOPLEFT", x, y)
        button:Show()
        VB:UpdateUnitButton(button)
        
        col = col + 1
        if col >= maxCols then
            col = 0
            row = row + 1
        end
    end
    
    local totalCols = math.max(1, math.min(#units, maxCols))
    local totalRows = math.max(1, math.ceil(#units / maxCols))
    VB.frames.main:SetSize(
        totalCols * (width + spacing) - spacing,
        totalRows * (height + spacing) - spacing
    )
end

local rolePriority = { TANK = 1, DAMAGER = 2, HEALER = 3, NONE = 2 }

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
    
    -- Trier par rôle: Tank > DPS > Healer
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
