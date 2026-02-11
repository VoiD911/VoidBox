--[[
    VoidBox - Health Bar Module
    Gestion des barres de vie avec heal prediction (compatible 12.0+)
]]

local addonName, VB = ...

-------------------------------------------------
-- Health Bar Creation
-------------------------------------------------
function VB:CreateHealthBar(parent)
    local healthBar = CreateFrame("StatusBar", nil, parent)
    healthBar:SetStatusBarTexture(VB.config.texture)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)
    
    local bg = healthBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    healthBar.bg = bg
    
    local healPrediction = CreateFrame("StatusBar", nil, healthBar)
    healPrediction:SetStatusBarTexture(VB.config.texture)
    healPrediction:SetStatusBarColor(0, 0.8, 0, 0.5)
    healPrediction:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    healPrediction:SetPoint("BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healPrediction:SetMinMaxValues(0, 1)
    healPrediction:SetValue(0)
    healPrediction:Hide()
    healthBar.healPrediction = healPrediction
    
    local absorbBar = CreateFrame("StatusBar", nil, healthBar)
    absorbBar:SetStatusBarTexture(VB.config.texture)
    absorbBar:SetStatusBarColor(0.8, 0.8, 0, 0.6)
    absorbBar:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    absorbBar:SetPoint("BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:Hide()
    healthBar.absorbBar = absorbBar
    
    local healAbsorb = healthBar:CreateTexture(nil, "OVERLAY")
    healAbsorb:SetColorTexture(0.8, 0, 0, 0.5)
    healAbsorb:SetPoint("TOPRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    healAbsorb:SetPoint("BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healAbsorb:SetWidth(0)
    healAbsorb:Hide()
    healthBar.healAbsorb = healAbsorb
    
    return healthBar
end

-------------------------------------------------
-- Health Update (12.0+ compatible)
-- Cell/VuhDo do health/healthMax directly.
-- We wrap in pcall just in case secret values cause issues.
-------------------------------------------------
function VB:UpdateHealthBar(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local healthBar = button.healthBar
    if not healthBar then return end
    
    local healthRaw = UnitHealth(unit)
    local maxHealthRaw = UnitHealthMax(unit)
    
    -- StatusBars accept secret values natively
    healthBar:SetMinMaxValues(0, maxHealthRaw)
    healthBar:SetValue(healthRaw)
    
    -- Class colors
    if VB.config.classColors then
        local _, class = UnitClass(unit)
        if class then
            local r, g, b = VB:GetClassColor(class)
            healthBar:SetStatusBarColor(r, g, b)
        end
    else
        local ok = pcall(function()
            local pct = healthRaw / maxHealthRaw
            if pct > 0.5 then
                healthBar:SetStatusBarColor(0, 1, 0)
            elseif pct > 0.25 then
                healthBar:SetStatusBarColor(1, 1, 0)
            else
                healthBar:SetStatusBarColor(1, 0, 0)
            end
        end)
        if not ok then
            healthBar:SetStatusBarColor(0, 1, 0)
        end
    end
    
    VB:UpdateHealPrediction(button)
    
    -- Health text - percentage display
    -- WoW 12.0: UnitHealthPercent() returns a secret float percentage
    -- string.format can display secret values, so we format it directly
    if button.healthText then
        local pctText = ""
        
        if UnitIsDeadOrGhost(unit) then
            pctText = VB.L["DEAD"]
        elseif not UnitIsConnected(unit) then
            pctText = VB.L["OFFLINE"]
        else
            local ok, r = pcall(function()
                if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve then
                    -- Create a scalar curve that maps 0-1 to 0-100
                    if not VB._pctCurve then
                        local curve = C_CurveUtil.CreateCurve()
                        curve:SetType(Enum.LuaCurveType.Linear)
                        curve:AddPoint(0, 0)     -- 0% health -> 0
                        curve:AddPoint(1, 100)   -- 100% health -> 100
                        VB._pctCurve = curve
                    end
                    -- UnitHealthPercent with curve returns the curve-evaluated result
                    -- which is a secret number ~54 for 54% health
                    local scaled = UnitHealthPercent(unit, true, VB._pctCurve)
                    return string.format("%.0f", scaled) .. "%"
                elseif UnitHealthPercent then
                    -- Fallback without curve: show raw 0-1 value
                    return string.format("%.2f", UnitHealthPercent(unit))
                end
                return nil
            end)
            if ok and r then
                pctText = r
            end
        end
        
        button.healthText:SetText(pctText)
    end
end

-------------------------------------------------
-- Heal Prediction (12.0+ compatible)
-------------------------------------------------
function VB:UpdateHealPrediction(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local healthBar = button.healthBar
    if not healthBar then return end
    
    local ok = pcall(function()
        local health = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        if maxHealth == 0 then maxHealth = 1 end
        
        local healPredictionBar = healthBar.healPrediction
        local absorbBar = healthBar.absorbBar
        local healAbsorb = healthBar.healAbsorb
        
        local incomingHeal = 0
        local absorb = 0
        local healAbsorbAmount = 0
        
        if UnitGetIncomingHeals then
            local v = UnitGetIncomingHeals(unit)
            if v and v > 0 then incomingHeal = v end
        end
        if UnitGetTotalAbsorbs then
            local v = UnitGetTotalAbsorbs(unit)
            if v and v > 0 then absorb = v end
        end
        if UnitGetTotalHealAbsorbs then
            local v = UnitGetTotalHealAbsorbs(unit)
            if v and v > 0 then healAbsorbAmount = v end
        end
        
        if incomingHeal > 0 then
            local missingHealth = maxHealth - health
            local healToShow = math.min(incomingHeal, missingHealth)
            healPredictionBar:SetMinMaxValues(0, maxHealth)
            healPredictionBar:SetValue(healToShow)
            healPredictionBar:SetWidth(healthBar:GetWidth() * (healToShow / maxHealth))
            healPredictionBar:Show()
        else
            healPredictionBar:Hide()
        end
        
        if absorb > 0 then
            local currentHealthWidth = healthBar:GetWidth() * (health / maxHealth)
            local absorbWidth = healthBar:GetWidth() * (absorb / maxHealth)
            absorbBar:SetMinMaxValues(0, maxHealth)
            absorbBar:SetValue(absorb)
            absorbBar:SetWidth(math.min(absorbWidth, healthBar:GetWidth() - currentHealthWidth))
            absorbBar:Show()
        else
            absorbBar:Hide()
        end
        
        if healAbsorbAmount > 0 then
            local absorbWidth = healthBar:GetWidth() * (healAbsorbAmount / maxHealth)
            healAbsorb:SetWidth(math.min(absorbWidth, healthBar:GetWidth() * (health / maxHealth)))
            healAbsorb:Show()
        else
            healAbsorb:Hide()
        end
    end)
    
    if not ok then
        healthBar.healPrediction:Hide()
        healthBar.absorbBar:Hide()
        healthBar.healAbsorb:Hide()
    end
end

-------------------------------------------------
-- Power Bar
-------------------------------------------------
function VB:CreatePowerBar(parent)
    local powerBar = CreateFrame("StatusBar", nil, parent)
    powerBar:SetStatusBarTexture(VB.config.texture)
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
    
    local bg = powerBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    powerBar.bg = bg
    
    return powerBar
end

function VB:UpdatePowerBar(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local powerBar = button.powerBar
    if not powerBar then return end
    
    local powerType = UnitPowerType(unit)
    local powerRaw = UnitPower(unit)
    local maxPowerRaw = UnitPowerMax(unit)
    
    powerBar:SetMinMaxValues(0, maxPowerRaw)
    powerBar:SetValue(powerRaw)
    
    local powerColor = PowerBarColor[powerType]
    if powerColor then
        powerBar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
    else
        powerBar:SetStatusBarColor(0.5, 0.5, 0.5)
    end
end
