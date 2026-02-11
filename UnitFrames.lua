--[[
    VoidBox - Unit Frames Module
    Création des frames sécurisés pour le click-casting (compatible 12.0+)
    
    Utilise SecureUnitButtonTemplate pour permettre le cast de sorts en combat
]]

local addonName, VB = ...

-------------------------------------------------
-- Unit Button Pool
-------------------------------------------------
local buttonPool = {}
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
-- Create Unit Button (Secure Frame)
-------------------------------------------------
function VB:CreateUnitButton(unit, index)
    local button = CreateFrame("Button", "VoidBoxButton"..index, VB.frames.container, 
        "SecureUnitButtonTemplate,BackdropTemplate")
    
    button:SetSize(VB.config.frameWidth, VB.config.frameHeight)
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
    
    -- Create health bar
    local healthBar = VB:CreateHealthBar(button)
    healthBar:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    healthBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 
        VB.config.showPowerBar and (VB.config.powerBarHeight + 2) or 1)
    button.healthBar = healthBar
    
    -- Create power bar (optional)
    if VB.config.showPowerBar then
        local powerBar = VB:CreatePowerBar(button)
        powerBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        powerBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        powerBar:SetHeight(VB.config.powerBarHeight)
        button.powerBar = powerBar
    end
    
    -- Name text (ligne du haut, centré)
    local nameText = healthBar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(VB.config.font, VB.config.fontSize, "OUTLINE")
    nameText:SetPoint("TOP", healthBar, "TOP", 0, -2)
    nameText:SetJustifyH("CENTER")
    nameText:SetTextColor(1, 1, 1)
    button.nameText = nameText
    
    -- Health text (ligne du bas, centré - affiche vie)
    local healthText = healthBar:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(VB.config.font, VB.config.fontSize - 2, "OUTLINE")
    healthText:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, 1)
    healthText:SetJustifyH("CENTER")
    healthText:SetTextColor(0.9, 0.9, 0.9)
    button.healthText = healthText
    
    -- Status icon (dead, offline, etc.)
    local statusIcon = healthBar:CreateTexture(nil, "OVERLAY")
    statusIcon:SetSize(16, 16)
    statusIcon:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    statusIcon:Hide()
    button.statusIcon = statusIcon
    
    -- Role indicator (petit carré coloré en haut à gauche)
    local roleIcon = healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    roleIcon:SetSize(6, 6)
    roleIcon:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 2, -2)
    roleIcon:Hide()
    button.roleIcon = roleIcon
    
    -- Debuff indicators
    button.debuffIcons = {}
    for i = 1, 3 do
        local debuff = button:CreateTexture(nil, "OVERLAY")
        debuff:SetSize(14, 14)
        debuff:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2 + (i-1) * 15, 
            VB.config.showPowerBar and (VB.config.powerBarHeight + 3) or 2)
        debuff:Hide()
        button.debuffIcons[i] = debuff
    end
    
    -- My buff/HOT indicator (petit carré en bas à droite)
    local myBuffIcon = healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    myBuffIcon:SetSize(6, 6)
    myBuffIcon:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -2, 2)
    myBuffIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
    myBuffIcon:SetVertexColor(0.2, 1, 0.4, 1) -- vert clair
    myBuffIcon:Hide()
    button.myBuffIcon = myBuffIcon
    
    -- Highlight on mouseover
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)
    button.highlight = highlight
    
    button.inRange = true
    
    VB:RegisterUnitButtonEvents(button)
    VB:ApplyClickCastings(button)
    VB:UpdateUnitButton(button)
    
    return button
end

-------------------------------------------------
-- Unit Button Events
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
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
        if #name > 10 then
            name = name:sub(1, 10) .. "..."
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

function VB:UpdateRole(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local roleIcon = button.roleIcon
    local role = UnitGroupRolesAssigned(unit)
    
    if role == "TANK" then
        -- Petit carré bleu
        roleIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
        roleIcon:SetVertexColor(0.2, 0.6, 1, 1)
        roleIcon:Show()
    elseif role == "HEALER" then
        -- Petit carré vert
        roleIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
        roleIcon:SetVertexColor(0, 1, 0.4, 1)
        roleIcon:Show()
    elseif role == "DAMAGER" then
        -- Petit carré rouge
        roleIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
        roleIcon:SetVertexColor(1, 0.2, 0.2, 1)
        roleIcon:Show()
    else
        roleIcon:Hide()
    end
end

function VB:UpdateRange(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local inRange = true
    if unit == "player" then
        inRange = true
    else
        -- UnitInRange can return secret values in 12.0
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
    
    local ok, _ = pcall(function()
        local status = UnitThreatSituation(unit)
        if status and status >= 2 then
            button:SetBackdropBorderColor(1, 0, 0, 1)
        elseif status and status >= 1 then
            button:SetBackdropBorderColor(1, 1, 0, 1)
        else
            button:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end)
    if not ok then
        button:SetBackdropBorderColor(0, 0, 0, 1)
    end
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
    if UnitHasIncomingResurrection(unit) then
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
-- Aura Updates (using compat wrapper)
-------------------------------------------------
function VB:UpdateAuras(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    -- Debuffs dispellables (en bas à gauche)
    for _, icon in ipairs(button.debuffIcons) do
        icon:Hide()
    end
    
    local debuffs = VB:GetUnitDebuffs(unit, 40)
    local debuffIndex = 1
    
    for _, debuff in ipairs(debuffs) do
        if debuff.dispelType or debuff.isStealable then
            local icon = button.debuffIcons[debuffIndex]
            if icon then
                icon:SetTexture(debuff.icon)
                icon:Show()
                debuffIndex = debuffIndex + 1
                if debuffIndex > 3 then break end
            end
        end
    end
    
    -- My HOTs/shields indicator — petit carré vert en bas à droite
    -- Vérifie si le joueur a au moins un HOT ou bouclier de heal actif
    -- (de n'importe quel healer, pas juste le joueur)
    if button.myBuffIcon then
        local hasHealBuff = VB:UnitHasHealBuff(unit)
        if hasHealBuff then
            button.myBuffIcon:Show()
        else
            button.myBuffIcon:Hide()
        end
    end
end
