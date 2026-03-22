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
    
    -- Absorb bar: overlay on full health bar, fills from RIGHT (Cell/VuhDo style)
    -- Cannot anchor to health fill due to secret value arithmetic limitations
    local absorbBar = CreateFrame("StatusBar", nil, healthBar)
    absorbBar:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    absorbBar:SetStatusBarColor(1, 1, 1, 0.7)
    absorbBar:SetAllPoints(healthBar)
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetReverseFill(true)
    absorbBar:SetFrameLevel(healthBar:GetFrameLevel() + 2)
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
-- Uses StatusBar:SetMinMaxValues/SetValue which accept secret values natively.
-- Avoids all arithmetic (division, comparison) on health/absorb values.
-------------------------------------------------
function VB:UpdateHealPrediction(button)
    local unit = button.unit
    if not unit or not UnitExists(unit) then return end
    
    local healthBar = button.healthBar
    if not healthBar then return end
    
    local healPredictionBar = healthBar.healPrediction
    local absorbBar = healthBar.absorbBar
    local healAbsorbTex = healthBar.healAbsorb
    
    -- Get raw values (may be secret in combat)
    local maxHealth = UnitHealthMax(unit)
    
    -- === Incoming heals (green overlay) ===
    local showHeal = false
    pcall(function()
        if UnitGetIncomingHeals then
            local incomingHeal = UnitGetIncomingHeals(unit) or 0
            -- SetValue accepts secrets; StatusBar clips to min/max automatically
            healPredictionBar:SetMinMaxValues(0, maxHealth)
            healPredictionBar:SetValue(incomingHeal)
            -- Anchor after health bar fill (already set in CreateHealthBar)
            showHeal = true
        end
    end)
    if showHeal then
        healPredictionBar:Show()
    else
        healPredictionBar:Hide()
    end
    
    -- === Shield absorbs (white overlay, e.g. PW:Shield) ===
    local showAbsorb = false
    pcall(function()
        if UnitGetTotalAbsorbs then
            local absorb = UnitGetTotalAbsorbs(unit)
            if absorb == nil then absorb = 0 end
            absorbBar:SetMinMaxValues(0, maxHealth)
            absorbBar:SetValue(absorb)
            showAbsorb = true
        end
    end)
    if showAbsorb then
        absorbBar:Show()
    else
        absorbBar:Hide()
    end
    
    -- === Heal absorbs (red overlay eating into health, e.g. Necrotic) ===
    local showHealAbsorb = false
    pcall(function()
        if UnitGetTotalHealAbsorbs then
            local healAbsorbAmount = UnitGetTotalHealAbsorbs(unit) or 0
            -- healAbsorb is a Texture, not a StatusBar — we need width
            -- Use a helper StatusBar instead for secret-safe sizing
            if not healthBar.healAbsorbBar then
                -- Create a StatusBar replacement for the texture approach
                local hab = CreateFrame("StatusBar", nil, healthBar)
                hab:SetStatusBarTexture(VB.config.texture)
                hab:SetStatusBarColor(0.8, 0, 0, 0.5)
                hab:SetPoint("TOPRIGHT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
                hab:SetPoint("BOTTOMRIGHT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
                hab:SetMinMaxValues(0, 1)
                hab:SetValue(0)
                hab:SetReverseFill(true)
                hab:Hide()
                healthBar.healAbsorbBar = hab
                -- Hide old texture approach
                healAbsorbTex:Hide()
            end
            healthBar.healAbsorbBar:SetMinMaxValues(0, maxHealth)
            healthBar.healAbsorbBar:SetValue(healAbsorbAmount)
            showHealAbsorb = true
        end
    end)
    if showHealAbsorb and healthBar.healAbsorbBar then
        healthBar.healAbsorbBar:Show()
    elseif healthBar.healAbsorbBar then
        healthBar.healAbsorbBar:Hide()
    end
    healAbsorbTex:Hide()  -- always hide old texture approach
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
    
    local powerRaw = UnitPower(unit)
    local maxPowerRaw = UnitPowerMax(unit)
    
    powerBar:SetMinMaxValues(0, maxPowerRaw)
    powerBar:SetValue(powerRaw)
    
    -- UnitPowerType may return a secret value in 12.0+
    -- Using it as table key (PowerBarColor[powerType]) would crash
    local ok, r, g, b = pcall(function()
        local powerType = UnitPowerType(unit)
        local powerColor = PowerBarColor[powerType]
        if powerColor then
            return powerColor.r, powerColor.g, powerColor.b
        end
        return 0.5, 0.5, 0.5
    end)
    if ok then
        powerBar:SetStatusBarColor(r, g, b)
    else
        powerBar:SetStatusBarColor(0.5, 0.5, 0.5)
    end
end
