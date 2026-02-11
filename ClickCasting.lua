--[[
    VoidBox - Click Casting Module
    Gestion des bindings spell/clic (compatible 12.0+)
    
    IMPORTANT: Les attributs des SecureButtons ne peuvent PAS être modifiés en combat!
    Toute la configuration doit se faire hors combat.
]]

local addonName, VB = ...

local mouseKeyIDs = {
    ["Left"] = 1,
    ["Right"] = 2,
    ["Middle"] = 3,
    ["Button4"] = 4,
    ["Button5"] = 5,
}

local modifiers = {
    [""] = "",
    ["shift"] = "shift-",
    ["ctrl"] = "ctrl-",
    ["alt"] = "alt-",
    ["shift-ctrl"] = "ctrl-shift-",
    ["shift-alt"] = "alt-shift-",
    ["ctrl-alt"] = "alt-ctrl-",
    ["shift-ctrl-alt"] = "alt-ctrl-shift-",
}

-------------------------------------------------
-- Initialize Click Castings
-------------------------------------------------
function VB:InitClickCastings()
    if not VB.config.clickCastings then
        VB.config.clickCastings = VB:CopyTable(VB.defaults.clickCastings)
    end
    VB.clickCastings = VB.config.clickCastings
end

function VB:GetAttributeKey(modifier, mouseButton)
    local prefix = modifiers[modifier] or ""
    local buttonID = mouseKeyIDs[mouseButton]
    if buttonID then
        return prefix .. "type" .. buttonID
    end
    return nil
end

-------------------------------------------------
-- Apply Click Castings to a Button
-------------------------------------------------
function VB:ApplyClickCastings(button)
    if InCombatLockdown() then
        VB:Debug("Cannot apply click castings in combat!")
        return false
    end
    if not button then return false end
    
    VB:ClearClickCastings(button)
    
    for _, binding in ipairs(VB.clickCastings) do
        local attrKey = binding[1]
        local actionType = binding[2]
        local actionValue = binding[3]
        if attrKey and actionType then
            VB:SetButtonAttribute(button, attrKey, actionType, actionValue)
        end
    end
    return true
end

function VB:SetButtonAttribute(button, attrKey, actionType, actionValue)
    if InCombatLockdown() then return end
    
    if actionType == "spell" then
        local spellName = actionValue
        if type(actionValue) == "number" then
            spellName = VB:GetSpellName(actionValue)
        end
        if spellName then
            -- Use native "spell" attribute - SecureUnitButtonTemplate
            -- casts on the button's unit automatically
            button:SetAttribute(attrKey, "spell")
            local spellKey = attrKey:gsub("type", "spell")
            button:SetAttribute(spellKey, spellName)
        end
    elseif actionType == "macro" then
        button:SetAttribute(attrKey, "macro")
        local macroKey = attrKey:gsub("type", "macrotext")
        button:SetAttribute(macroKey, actionValue)
    elseif actionType == "target" then
        button:SetAttribute(attrKey, "target")
    elseif actionType == "focus" then
        button:SetAttribute(attrKey, "focus")
    elseif actionType == "togglemenu" then
        button:SetAttribute(attrKey, "togglemenu")
    elseif actionType == "assist" then
        button:SetAttribute(attrKey, "assist")
    end
end

function VB:ClearClickCastings(button)
    if InCombatLockdown() then return end
    if not button then return end
    
    for _, mod in pairs(modifiers) do
        for _, id in pairs(mouseKeyIDs) do
            local attrKey = mod .. "type" .. id
            button:SetAttribute(attrKey, nil)
            button:SetAttribute(attrKey:gsub("type", "spell"), nil)
            button:SetAttribute(attrKey:gsub("type", "macro"), nil)
            button:SetAttribute(attrKey:gsub("type", "macrotext"), nil)
        end
    end
end

function VB:ApplyClickCastingsToAllFrames()
    if InCombatLockdown() then
        VB:Print("Impossible de modifier les bindings en combat!")
        return
    end
    for _, button in pairs(VB.unitButtons) do
        VB:ApplyClickCastings(button)
    end
    VB:Debug("Click castings applied to all frames")
end

function VB:AddClickCasting(modifier, mouseButton, actionType, actionValue)
    if InCombatLockdown() then
        VB:Print("Impossible de modifier les bindings en combat!")
        return false
    end
    
    local attrKey = VB:GetAttributeKey(modifier, mouseButton)
    if not attrKey then
        VB:Print("Combinaison de touches invalide")
        return false
    end
    
    for i, binding in ipairs(VB.clickCastings) do
        if binding[1] == attrKey then
            VB.clickCastings[i] = { attrKey, actionType, actionValue }
            VB:ApplyClickCastingsToAllFrames()
            return true
        end
    end
    
    table.insert(VB.clickCastings, { attrKey, actionType, actionValue })
    VB:ApplyClickCastingsToAllFrames()
    return true
end

function VB:RemoveClickCasting(attrKey)
    if InCombatLockdown() then
        VB:Print("Impossible de modifier les bindings en combat!")
        return false
    end
    
    for i, binding in ipairs(VB.clickCastings) do
        if binding[1] == attrKey then
            table.remove(VB.clickCastings, i)
            VB:ApplyClickCastingsToAllFrames()
            return true
        end
    end
    return false
end

function VB:GetBindingDisplayText(attrKey)
    local modifier = ""
    local buttonNum = attrKey:match("type(%d+)")
    
    if attrKey:find("shift") then modifier = modifier .. "Shift+" end
    if attrKey:find("ctrl") then modifier = modifier .. "Ctrl+" end
    if attrKey:find("alt") then modifier = modifier .. "Alt+" end
    
    local buttonName = "?"
    for name, id in pairs(mouseKeyIDs) do
        if tostring(id) == buttonNum then
            buttonName = name
            break
        end
    end
    return modifier .. buttonName
end

function VB:GetActionDisplayText(actionType, actionValue)
    if actionType == "spell" then
        local spellName = actionValue
        if type(actionValue) == "number" then
            spellName = VB:GetSpellName(actionValue) or "Sort inconnu"
        end
        return "|cFF00FF00" .. (spellName or "Sort") .. "|r"
    elseif actionType == "macro" then
        local preview = actionValue or ""
        if #preview > 20 then preview = preview:sub(1, 20) .. "..." end
        return "|cFFFFFF00Macro:|r " .. preview
    elseif actionType == "target" then
        return "|cFFFFFFFFCibler|r"
    elseif actionType == "focus" then
        return "|cFFFF8800Focus|r"
    elseif actionType == "togglemenu" then
        return "|cFF888888Menu|r"
    elseif actionType == "assist" then
        return "|cFFFF00FFAssister|r"
    end
    return actionType or "?"
end

function VB:HandleSpellDrop(modifier, mouseButton)
    if InCombatLockdown() then
        VB:Print("Impossible de modifier les bindings en combat!")
        ClearCursor()
        return false
    end
    
    local spellID, spellName = VB:GetCursorSpell()
    if spellID and spellName then
        VB:AddClickCasting(modifier, mouseButton, "spell", spellID)
        VB:Print("Binding ajouté: " .. VB:GetBindingDisplayText(VB:GetAttributeKey(modifier, mouseButton)) .. " -> " .. spellName)
        ClearCursor()
        return true
    end
    
    ClearCursor()
    return false
end
