--[[
    VoidBox - Unit Frames Module
    Création des frames sécurisés pour le click-casting (compatible 12.0+)
    
    Layout at 100% scale (base 80x55):
      Row 1 (11px): [RoleIcon] Name (left) + Health % (right)
      Row 2 (20px): Debuff icons (HARMFUL, max 5) + stacks
      Row 3 (12px): HOT/shield icons from PLAYER only (max 5) + other healer indicator
      Row 4 (4px):  Power bar (mana, rage, etc.)
      Padding: remaining pixels distributed as gaps
    
    Scaling: scaleW% and scaleH% multiply the base dimensions.
    All internal sizes (fonts, icons, power bar) scale with scaleH.
]]

local addonName, VB = ...

-- Base dimensions at 100%
local BASE_WIDTH = 80
local BASE_HEIGHT = 55

-- Base layout sizes at 100% (total = 11+2+20+1+12+1+4+2+2 = 55)
local BASE_ROW1_FONT = 10
local BASE_DEBUFF_SIZE = 21
local BASE_BUFF_SIZE = 12
local BASE_POWERBAR_H = 4

local MAX_DEBUFF_ICONS = 4
local MAX_BUFF_ICONS = 4
local AURA_ICON_SPACING = 1

-- Compute scaled dimensions from config
local function GetScaledSizes()
    local sw = (VB.config.scaleWidth or 100) / 100
    local sh = (VB.config.scaleHeight or 100) / 100
    return {
        frameW     = math.floor(BASE_WIDTH * sw),
        frameH     = math.floor(BASE_HEIGHT * sh),
        row1Font   = math.max(7, math.floor(BASE_ROW1_FONT * sh)),
        debuffSize = math.max(8, math.floor(BASE_DEBUFF_SIZE * sh)),
        buffSize   = math.max(6, math.floor(BASE_BUFF_SIZE * sh)),
        powerBarH  = math.max(2, math.floor(BASE_POWERBAR_H * sh)),
    }
end

-------------------------------------------------
-- Unit Button Pool
-------------------------------------------------
local buttonCount = 0

function VB:GetOrCreateUnitButton(unit, index)
    local key = unit
    if VB.unitButtons[key] then
        VB.unitButtons[key].unit = unit
        VB.unitButtons[key]:SetAttribute("unit", unit)
        return VB.unitButtons[key]
    end
    buttonCount = buttonCount + 1
    local button = VB:CreateUnitButton(unit, buttonCount)
    VB.unitButtons[key] = button
    return button
end

-------------------------------------------------
-- Create aura icon frames
-------------------------------------------------
local function CreateAuraIcons(parent, count, iconSize)
    local icons = {}
    for i = 1, count do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(iconSize, iconSize)
        f._iconSize = iconSize
        local tex = f:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetAllPoints()
        f.icon = tex

        -- Stack badge: dark bg overlapping bottom-right
        local badgeSize = math.max(9, math.floor(iconSize * 0.55))
        local badge = CreateFrame("Frame", nil, f, "BackdropTemplate")
        badge:SetSize(badgeSize, badgeSize)
        badge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        badge:SetBackdropColor(0, 0, 0, 0.85)
        badge:SetBackdropBorderColor(0, 0, 0, 1)
        badge:SetFrameLevel(f:GetFrameLevel() + 2)
        badge:Hide()
        f.badge = badge

        local stkFont = math.max(7, math.floor(iconSize * 0.45))
        local stk = badge:CreateFontString(nil, "OVERLAY")
        stk:SetFont(VB.config.font, stkFont, "OUTLINE")
        stk:SetPoint("CENTER", badge, "CENTER", 0, 0)
        stk:SetTextColor(1, 0.85, 0)
        f.stacks = stk

        f:Hide()
        icons[i] = f
    end
    return icons
end

-------------------------------------------------
-- Create Unit Button
-------------------------------------------------
function VB:CreateUnitButton(unit, index)
    local S = GetScaledSizes()

    local button = CreateFrame("Button", "VoidBoxButton"..index, VB.frames.container,
        "SecureUnitButtonTemplate,BackdropTemplate")
    button:SetSize(S.frameW, S.frameH)
    button.unit = unit
    button:SetAttribute("unit", unit)
    button:SetAttribute("toggleForVehicle", true)
    button:RegisterForClicks("AnyUp")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    button:SetBackdropBorderColor(0, 0, 0, 1)

    local powerBarH = VB.config.showPowerBar and (S.powerBarH + 2) or 1
    local row1H = S.row1Font + 2

    -- Health bar (fills button minus power bar)
    local healthBar = VB:CreateHealthBar(button)
    healthBar:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    healthBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, powerBarH)
    button.healthBar = healthBar

    -- Power bar
    if VB.config.showPowerBar then
        local powerBar = VB:CreatePowerBar(button)
        powerBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        powerBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        powerBar:SetHeight(S.powerBarH)
        button.powerBar = powerBar
    end

    -- === Row 1: Role icon + Name (left) + Health % (right) ===
    local roleIcon = healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    roleIcon:SetSize(S.row1Font, S.row1Font)
    roleIcon:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 2, -1)
    roleIcon:Hide()
    button.roleIcon = roleIcon

    local healthText = healthBar:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(VB.config.font, S.row1Font, "OUTLINE")
    healthText:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -2, -1)
    healthText:SetHeight(row1H)
    healthText:SetJustifyH("RIGHT")
    healthText:SetJustifyV("TOP")
    healthText:SetTextColor(0.9, 0.9, 0.9)
    healthText:SetWordWrap(false)
    button.healthText = healthText

    local nameText = healthBar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(VB.config.font, S.row1Font, "OUTLINE")
    nameText:SetPoint("TOPLEFT", roleIcon, "TOPRIGHT", 1, 0)
    nameText:SetPoint("RIGHT", healthText, "LEFT", -2, 0)
    nameText:SetHeight(row1H)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("TOP")
    nameText:SetTextColor(1, 1, 1)
    nameText:SetWordWrap(false)
    button.nameText = nameText

    -- Status icon (dead, offline)
    local statusIcon = healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    statusIcon:SetSize(16, 16)
    statusIcon:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    statusIcon:Hide()
    button.statusIcon = statusIcon

    -- === Row 2: Debuff icons, positioned dynamically in UpdateAuras ===
    local row2Top = row1H + 2
    button._row2Top = row2Top
    button.debuffIcons = CreateAuraIcons(healthBar, MAX_DEBUFF_ICONS, S.debuffSize)

    -- === Row 3: HOT/buff icons, positioned dynamically in UpdateAuras ===
    local row3Top = row2Top + S.debuffSize + 1
    button._row3Top = row3Top
    button.buffIcons = CreateAuraIcons(healthBar, MAX_BUFF_ICONS, S.buffSize)

    -- "Others healing" indicator: small + icon bottom-right of healthBar
    local othersIndicator = healthBar:CreateFontString(nil, "OVERLAY")
    othersIndicator:SetFont(VB.config.font, math.max(7, S.buffSize - 2), "OUTLINE")
    othersIndicator:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -1, 1)
    othersIndicator:SetTextColor(0.5, 1, 0.5, 0.8)
    othersIndicator:SetText("")
    button.othersIndicator = othersIndicator

    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    button.inRange = true
    VB:RegisterUnitButtonEvents(button)
    VB:ApplyClickCastings(button)
    VB:UpdateUnitButton(button)
    return button
end

-------------------------------------------------
-- Resize an existing button to match current scale
-- Called from UpdateAllFrames when scale changes
-------------------------------------------------
function VB:ResizeUnitButton(button)
    local S = GetScaledSizes()
    local powerBarH = VB.config.showPowerBar and (S.powerBarH + 2) or 1
    local row1H = S.row1Font + 2

    -- Resize button
    button:SetSize(S.frameW, S.frameH)

    -- Resize health bar anchors (already anchored to button edges, just update bottom)
    button.healthBar:ClearAllPoints()
    button.healthBar:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.healthBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, powerBarH)

    -- Power bar
    if button.powerBar then
        button.powerBar:ClearAllPoints()
        button.powerBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        button.powerBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.powerBar:SetHeight(S.powerBarH)
    end

    -- Row 1: role icon
    button.roleIcon:SetSize(S.row1Font, S.row1Font)

    -- Row 1: fonts
    button.healthText:SetFont(VB.config.font, S.row1Font, "OUTLINE")
    button.healthText:SetHeight(row1H)
    button.nameText:SetFont(VB.config.font, S.row1Font, "OUTLINE")
    button.nameText:SetHeight(row1H)

    -- Row 2: debuff icons (positions set dynamically in UpdateAuras)
    local row2Top = row1H + 2
    button._row2Top = row2Top
    for i, f in ipairs(button.debuffIcons) do
        f:SetSize(S.debuffSize, S.debuffSize)
        f._iconSize = S.debuffSize
        if f.badge then
            local badgeSize = math.max(9, math.floor(S.debuffSize * 0.55))
            f.badge:SetSize(badgeSize, badgeSize)
            local stkFont = math.max(7, math.floor(S.debuffSize * 0.45))
            f.stacks:SetFont(VB.config.font, stkFont, "OUTLINE")
        end
    end

    -- Row 3: buff/HOT icons (positions set dynamically in UpdateAuras)
    local row3Top = row2Top + S.debuffSize + 1
    button._row3Top = row3Top
    for i, f in ipairs(button.buffIcons) do
        f:SetSize(S.buffSize, S.buffSize)
        f._iconSize = S.buffSize
        if f.badge then
            local badgeSize = math.max(9, math.floor(S.buffSize * 0.55))
            f.badge:SetSize(badgeSize, badgeSize)
            local stkFont = math.max(7, math.floor(S.buffSize * 0.45))
            f.stacks:SetFont(VB.config.font, stkFont, "OUTLINE")
        end
    end

    -- Others indicator
    if button.othersIndicator then
        button.othersIndicator:SetFont(VB.config.font, math.max(7, S.buffSize - 2), "OUTLINE")
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
function VB:RegisterUnitButtonEvents(button)
    button:RegisterEvent("UNIT_HEALTH")
    button:RegisterEvent("UNIT_MAXHEALTH")
    button:RegisterEvent("UNIT_POWER_UPDATE")
    button:RegisterEvent("UNIT_MAXPOWER")
    button:RegisterEvent("UNIT_AURA")
    button:RegisterEvent("UNIT_NAME_UPDATE")
    button:RegisterEvent("UNIT_CONNECTION")
    button:RegisterEvent("PLAYER_FLAGS_CHANGED")
    button:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    button:RegisterEvent("READY_CHECK")
    button:RegisterEvent("READY_CHECK_CONFIRM")
    button:RegisterEvent("READY_CHECK_FINISHED")
    button:RegisterEvent("INCOMING_RESURRECT_CHANGED")
    button.rangeCheckTimer = 0

    button:SetScript("OnEvent", function(self, event, ...)
        local unit = ...
        if unit and unit ~= self.unit then return end
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            VB:UpdateHealthBar(self)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            VB:UpdatePowerBar(self)
        elseif event == "UNIT_AURA" then
            VB:UpdateAuras(self)
        elseif event == "UNIT_NAME_UPDATE" then
            VB:UpdateName(self)
        elseif event == "UNIT_CONNECTION" then
            VB:UpdateStatus(self)
        elseif event == "PLAYER_FLAGS_CHANGED" then
            VB:UpdateStatus(self)
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
            VB:UpdateThreat(self)
        elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then
            VB:UpdateReadyCheck(self)
        elseif event == "INCOMING_RESURRECT_CHANGED" then
            VB:UpdateResurrect(self)
        end
    end)

    button:SetScript("OnUpdate", function(self, elapsed)
        self.rangeCheckTimer = self.rangeCheckTimer + elapsed
        if self.rangeCheckTimer >= 0.2 then
            self.rangeCheckTimer = 0
            VB:UpdateRange(self)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 20)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
end

-------------------------------------------------
-- Update Functions
-------------------------------------------------
function VB:UpdateUnitButton(button)
    if not button or not button.unit then return end
    VB:UpdateName(button)
    VB:UpdateHealthBar(button)
    VB:UpdatePowerBar(button)
    VB:UpdateStatus(button)
    VB:UpdateRole(button)
    VB:UpdateAuras(button)
    VB:UpdateRange(button)
end

function VB:UpdateName(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then
        button.nameText:SetText("")
        return
    end
    local name = UnitName(unit)
    if name then
        local S = GetScaledSizes()
        local iconWidth = button.roleIcon:IsShown() and (S.row1Font + 3) or 0
        local pctWidth = S.row1Font * 3  -- reserve space for "100%"
        local availWidth = S.frameW - 6 - iconWidth - pctWidth
        local charWidth = math.max(4, math.floor(S.row1Font * 0.65))
        local maxChars = math.floor(availWidth / charWidth)
        if maxChars < 3 then maxChars = 3 end
        if #name > maxChars then
            name = name:sub(1, maxChars) .. ".."
        end
        button.nameText:SetText(name)
    end
end

function VB:UpdateStatus(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local statusIcon = button.statusIcon
    local healthBar = button.healthBar
    if UnitIsDeadOrGhost(unit) then
        statusIcon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        statusIcon:Show()
        healthBar:SetStatusBarColor(0.3, 0.3, 0.3)
    elseif not UnitIsConnected(unit) then
        statusIcon:SetTexture("Interface\\CharacterFrame\\Disconnect-Icon")
        statusIcon:Show()
        healthBar:SetStatusBarColor(0.3, 0.3, 0.3)
    else
        statusIcon:Hide()
    end
end

local roleAtlasNames = {
    TANK    = "roleicon-tank",
    HEALER  = "roleicon-healer",
    DAMAGER = "roleicon-dps",
}

function VB:UpdateRole(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local roleIcon = button.roleIcon
    local role = UnitGroupRolesAssigned(unit)
    if (not role or role == "NONE") and UnitIsUnit(unit, "player") then
        if GetSpecialization and GetSpecializationRole then
            local spec = GetSpecialization()
            if spec then role = GetSpecializationRole(spec) end
        end
    end
    local atlas = roleAtlasNames[role]
    if atlas then
        roleIcon:SetTexture(nil)
        roleIcon:SetTexCoord(0, 1, 0, 1)
        local ok = pcall(function() roleIcon:SetAtlas(atlas, false) end)
        if not ok or not roleIcon:GetTexture() then
            roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            if role == "TANK" then
                roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
            elseif role == "HEALER" then
                roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
            elseif role == "DAMAGER" then
                roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
            end
        end
        roleIcon:Show()
    else
        roleIcon:Hide()
    end
    VB:UpdateName(button)
end

function VB:UpdateRange(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local inRange = true
    if unit ~= "player" then
        local ok, result = pcall(function()
            local r = UnitInRange(unit)
            if r then return true else return false end
        end)
        if ok then inRange = result else inRange = true end
    end
    if inRange ~= button.inRange then
        button.inRange = inRange
        button:SetAlpha(inRange and 1 or 0.4)
    end
end

function VB:UpdateThreat(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local ok = pcall(function()
        local status = UnitThreatSituation(unit)
        if status and status >= 2 then
            button:SetBackdropBorderColor(1, 0, 0, 1)
        elseif status and status >= 1 then
            button:SetBackdropBorderColor(1, 1, 0, 1)
        else
            button:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end)
    if not ok then button:SetBackdropBorderColor(0, 0, 0, 1) end
end

function VB:UpdateReadyCheck(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local statusIcon = button.statusIcon
    local status = GetReadyCheckStatus(unit)
    if status == "ready" then
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        statusIcon:Show()
    elseif status == "notready" then
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        statusIcon:Show()
    elseif status == "waiting" then
        statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
        statusIcon:Show()
    else
        if not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
            statusIcon:Hide()
        end
    end
end

function VB:UpdateResurrect(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    local statusIcon = button.statusIcon
    if VB:SafeBool(UnitHasIncomingResurrection(unit)) then
        statusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
        statusIcon:Show()
    elseif UnitIsDeadOrGhost(unit) then
        statusIcon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        statusIcon:Show()
    elseif UnitIsConnected(unit) then
        statusIcon:Hide()
    end
end

-------------------------------------------------
-- Aura Updates (12.0+ compatible)
-- Row 2: HARMFUL debuffs (icon + stacks, max 4)
-- Row 3: Player-cast HOTs/shields only (max 4)
--        + "others healing" indicator bottom-right
-------------------------------------------------

-- Center N visible icons on a row
local function CenterAuraRow(icons, visibleCount, iconSize, parent, yOffset)
    -- Hide all first
    for _, f in ipairs(icons) do f:ClearAllPoints(); f:Hide(); if f.badge then f.badge:Hide() end end
    if visibleCount <= 0 then return end
    local totalW = visibleCount * iconSize + (visibleCount - 1) * AURA_ICON_SPACING
    for i = 1, visibleCount do
        local f = icons[i]
        local offset = (i - 1) * (iconSize + AURA_ICON_SPACING) - (totalW - iconSize) / 2
        f:ClearAllPoints()
        f:SetPoint("TOP", parent, "TOP", offset, -yOffset)
    end
end

local function SetAuraFrame(frame, aura)
    pcall(function() frame.icon:SetTexture(aura.icon) end)

    local showBadge = false

    -- aura.applications is a secret value in 12.0+
    -- tonumber(string.format("%d", secret)) returns nil (secret string)
    -- Strategy: format to secret string, SetText displays it fine,
    -- then try to extract a real number to decide color/visibility
    local formatted = nil
    local ok1 = pcall(function()
        formatted = string.format("%d", aura.applications or 0)
    end)

    if ok1 and formatted then
        -- Try to get a real number for comparison
        -- In 12.0+: tonumber(secretString) = nil, so we use string.byte extraction
        local realNum = tonumber(formatted)  -- works outside secret context
        if not realNum then
            -- Secret string: extract digits via string.byte
            local ok2, extracted = pcall(function()
                local n = 0
                for pos = 1, 10 do
                    local b = string.byte(formatted, pos)
                    if not b then break end
                    if b >= 48 and b <= 57 then
                        n = n * 10 + (b - 48)
                    end
                end
                return n
            end)
            if ok2 then realNum = extracted end
        end

        if realNum and realNum > 1 then
            frame.stacks:SetText(formatted)
            if realNum >= 5 then
                frame.stacks:SetTextColor(1, 0.2, 0.2)
            else
                frame.stacks:SetTextColor(1, 0.85, 0)
            end
            showBadge = true
        elseif not realNum then
            -- Could not extract number at all — show badge as safety
            frame.stacks:SetText(formatted)
            frame.stacks:SetTextColor(1, 0.85, 0)
            showBadge = true
        end
    end

    if frame.badge then
        frame.badge:SetShown(showBadge)
    end
    frame:Show()
end

function VB:UpdateAuras(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end

    for _, f in ipairs(button.debuffIcons) do f:Hide(); if f.badge then f.badge:Hide() end end
    for _, f in ipairs(button.buffIcons) do f:Hide(); if f.badge then f.badge:Hide() end end
    if button.othersIndicator then button.othersIndicator:SetText("") end

    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end

    local S = GetScaledSizes()

    -- === DEBUFFS ===
    local debuffIdx = 0
    for i = 1, 40 do
        if debuffIdx >= MAX_DEBUFF_ICONS then break end
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not aura then break end
        debuffIdx = debuffIdx + 1
        SetAuraFrame(button.debuffIcons[debuffIdx], aura)
    end
    -- Center only the visible debuff icons
    CenterAuraRow(button.debuffIcons, debuffIdx, S.debuffSize, button.healthBar, button._row2Top or 14)
    -- Re-show the ones that have data
    for i = 1, debuffIdx do button.debuffIcons[i]:Show() end

    -- === HOTs / Shields (player-cast only) ===
    local buffIdx = 0
    local othersCount = 0
    local inCombat = InCombatLockdown()
    local playerGUID = UnitGUID("player")

    if not inCombat then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then break end
            local ok, id = pcall(function()
                return tonumber(string.format("%d", aura.spellId))
            end)
            if ok and id and VB.healBuffSpellIDs[id] then
                local isPlayer = false
                pcall(function()
                    if aura.sourceUnit and UnitGUID(aura.sourceUnit) == playerGUID then
                        isPlayer = true
                    end
                end)
                if isPlayer then
                    if buffIdx < MAX_BUFF_ICONS then
                        buffIdx = buffIdx + 1
                        SetAuraFrame(button.buffIcons[buffIdx], aura)
                    end
                else
                    othersCount = othersCount + 1
                end
            end
        end
    else
        for i = 1, 40 do
            if buffIdx >= MAX_BUFF_ICONS then break end
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL RAID_IN_COMBAT PLAYER")
            if not aura then break end
            buffIdx = buffIdx + 1
            SetAuraFrame(button.buffIcons[buffIdx], aura)
        end
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL RAID_IN_COMBAT")
            if not aura then break end
            othersCount = othersCount + 1
        end
        othersCount = math.max(0, othersCount - buffIdx)
    end
    -- Center only the visible buff icons
    CenterAuraRow(button.buffIcons, buffIdx, S.buffSize, button.healthBar, button._row3Top or 36)
    for i = 1, buffIdx do button.buffIcons[i]:Show() end

    if button.othersIndicator and othersCount > 0 then
        button.othersIndicator:SetText("+" .. othersCount)
    end
end
