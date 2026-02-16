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
    ["ScrollUp"] = 6,
    ["ScrollDown"] = 7,
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
    -- VB.clickCastings is set in Core.lua OnAddonLoaded
    -- pointing to VoidBoxDB.classBindings[playerClass]
    if not VB.clickCastings or #VB.clickCastings == 0 then
        VB.clickCastings = VB:CopyTable(VB.defaults.clickCastings)
        if VoidBoxDB and VoidBoxDB.classBindings and VB.playerClass then
            VoidBoxDB.classBindings[VB.playerClass] = VB.clickCastings
        end
    end
end

-------------------------------------------------
-- Mousewheel Secure Handler
-- Converts OnMouseWheel delta into virtual Click("Button6"/"Button7")
-- so they flow through the SecureActionButton attribute system.
-- Button6 = ScrollUp, Button7 = ScrollDown (convention used by Clique/VuhDo)
-------------------------------------------------
function VB:SetupMouseWheel(button)
    if button._vbMouseWheelSetup then return end
    button._vbMouseWheelSetup = true
    
    button:EnableMouseWheel(true)
    
    -- Secure snippet: convert mousewheel delta to a virtual button click
    -- self:Click("Button6") / self:Click("Button7") triggers the attribute
    -- system with type6/spell6 or type7/spell7 respectively
    SecureHandlerWrapScript(button, "OnMouseWheel", button, [[
        if ... > 0 then
            self:Click("Button6")
        else
            self:Click("Button7")
        end
    ]])
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
    VB:SetupMouseWheel(button)
    
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
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return
    end
    for _, button in pairs(VB.unitButtons) do
        VB:ApplyClickCastings(button)
    end
    VB:Debug("Click castings applied to all frames")
end

function VB:AddClickCasting(modifier, mouseButton, actionType, actionValue)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return false
    end
    
    local attrKey = VB:GetAttributeKey(modifier, mouseButton)
    if not attrKey then
        VB:Print(VB.L["INVALID_COMBO"])
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
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
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
    local displayNames = {
        ["1"] = "Left", ["2"] = "Right", ["3"] = "Middle",
        ["4"] = "Button 4", ["5"] = "Button 5",
        ["6"] = "Scroll Up", ["7"] = "Scroll Down",
    }
    buttonName = displayNames[buttonNum] or "?"
    return modifier .. buttonName
end

function VB:GetActionDisplayText(actionType, actionValue)
    if actionType == "spell" then
        local spellName = actionValue
        if type(actionValue) == "number" then
            spellName = VB:GetSpellName(actionValue) or VB.L["DISPLAY_UNKNOWN_SPELL"]
        end
        return "|cFF00FF00" .. (spellName or "Spell") .. "|r"
    elseif actionType == "macro" then
        local preview = actionValue or ""
        if #preview > 20 then preview = preview:sub(1, 20) .. "..." end
        return "|cFFFFFF00Macro:|r " .. preview
    elseif actionType == "target" then
        return "|cFFFFFFFF" .. VB.L["DISPLAY_TARGET"] .. "|r"
    elseif actionType == "focus" then
        return "|cFFFF8800" .. VB.L["DISPLAY_FOCUS"] .. "|r"
    elseif actionType == "togglemenu" then
        return "|cFF888888" .. VB.L["DISPLAY_MENU"] .. "|r"
    elseif actionType == "assist" then
        return "|cFFFF00FF" .. VB.L["DISPLAY_ASSIST"] .. "|r"
    end
    return actionType or "?"
end

function VB:HandleSpellDrop(modifier, mouseButton)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        ClearCursor()
        return false
    end
    
    local spellID, spellName = VB:GetCursorSpell()
    if spellID and spellName then
        VB:AddClickCasting(modifier, mouseButton, "spell", spellID)
        VB:Print(VB.L["BINDING_ADDED"] .. " " .. VB:GetBindingDisplayText(VB:GetAttributeKey(modifier, mouseButton)) .. " -> " .. spellName)
        ClearCursor()
        return true
    end
    
    ClearCursor()
    return false
end
