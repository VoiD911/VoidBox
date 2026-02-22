--[[
    VoidBox - Click Casting Module (v2 - Universal Bindings)
    Supports mouse clicks, scroll wheel, AND keyboard keys on hover.
    Compatible 12.0+ (SecureHandlerWrapScript for keyboard bindings)
    
    NEW BINDING FORMAT (v2):
    {
        combo    = "CTRL-F1",           -- WoW key string (for keyboard) or nil (for mouse)
        mouse    = "Left",              -- mouse button name or nil (for keyboard)
        mods     = "ctrl-shift",        -- modifier string (sorted: alt-ctrl-shift)
        action   = "spell",             -- spell/macro/target/focus/togglemenu/assist
        value    = 12345,               -- spellID, macro body, or nil
        display  = "Ctrl + F1",         -- human-readable combo text
        name     = "Renew",             -- display name for the action
    }
    
    LEGACY FORMAT (v1 - auto-migrated):
    { "shift-type1", "spell", 12345, "Renew" }
    
    IMPORTANT: SecureButton attributes cannot be modified in combat!
]]

local addonName, VB = ...

-------------------------------------------------
-- Mouse button ID mapping (for SecureUnitButton attributes)
-------------------------------------------------
local mouseKeyIDs = {
    ["Left"]       = 1,
    ["Right"]      = 2,
    ["Middle"]     = 3,
    ["Button4"]    = 4,
    ["Button5"]    = 5,
    ["ScrollUp"]   = 6,
    ["ScrollDown"] = 7,
}

-- Modifier prefix for attribute keys (sorted canonical form)
local modPrefixes = {
    [""]               = "",
    ["alt"]            = "alt-",
    ["ctrl"]           = "ctrl-",
    ["shift"]          = "shift-",
    ["alt-ctrl"]       = "alt-ctrl-",
    ["alt-shift"]      = "alt-shift-",
    ["ctrl-shift"]     = "ctrl-shift-",
    ["alt-ctrl-shift"] = "alt-ctrl-shift-",
}

-- Ignored keys (modifiers themselves, escape, etc.)
local ignoredKeys = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, ESCAPE = true, UNKNOWN = true,
    PRINTSCREEN = true,
}

-------------------------------------------------
-- Canonical modifier string from booleans
-------------------------------------------------
function VB:BuildModString(shift, ctrl, alt)
    local parts = {}
    if alt then table.insert(parts, "alt") end
    if ctrl then table.insert(parts, "ctrl") end
    if shift then table.insert(parts, "shift") end
    return table.concat(parts, "-")
end

-- WoW binding string: "CTRL-SHIFT-F1"
function VB:BuildWoWBindingString(mods, key)
    local parts = {}
    if mods:find("alt") then table.insert(parts, "ALT") end
    if mods:find("ctrl") then table.insert(parts, "CTRL") end
    if mods:find("shift") then table.insert(parts, "SHIFT") end
    table.insert(parts, key:upper())
    return table.concat(parts, "-")
end

-- Human-readable display: "Ctrl + Shift + F1"
function VB:BuildDisplayString(mods, inputName)
    local parts = {}
    if mods:find("alt") then table.insert(parts, "Alt") end
    if mods:find("ctrl") then table.insert(parts, "Ctrl") end
    if mods:find("shift") then table.insert(parts, "Shift") end
    table.insert(parts, inputName)
    return table.concat(parts, " + ")
end

-------------------------------------------------
-- Legacy Migration (v1 → v2)
-------------------------------------------------
function VB:MigrateBindings()
    if not VB.clickCastings or #VB.clickCastings == 0 then return end
    
    -- Check if already v2 format (first entry has .action field)
    local first = VB.clickCastings[1]
    if type(first) == "table" and first.action then return end  -- already v2
    
    local migrated = {}
    for _, old in ipairs(VB.clickCastings) do
        if type(old) == "table" and type(old[1]) == "string" then
            local attrKey = old[1]   -- e.g. "shift-ctrl-type1"
            local action  = old[2]   -- e.g. "spell"
            local value   = old[3]   -- e.g. 12345
            local dname   = old[4]   -- e.g. "Renew"
            
            -- Parse modifier and button from attrKey
            local mods = ""
            local parts = {}
            if attrKey:find("alt") then table.insert(parts, "alt") end
            if attrKey:find("ctrl") then table.insert(parts, "ctrl") end
            if attrKey:find("shift") then table.insert(parts, "shift") end
            mods = table.concat(parts, "-")
            
            local btnNum = attrKey:match("type(%d+)")
            local mouseNames = {
                ["1"] = "Left", ["2"] = "Right", ["3"] = "Middle",
                ["4"] = "Button4", ["5"] = "Button5",
                ["6"] = "ScrollUp", ["7"] = "ScrollDown",
            }
            local mouseName = mouseNames[btnNum]
            
            if mouseName then
                local displayInput = ({
                    Left = "Left Click", Right = "Right Click", Middle = "Middle Click",
                    Button4 = "Button 4", Button5 = "Button 5",
                    ScrollUp = "Scroll Up", ScrollDown = "Scroll Down",
                })[mouseName] or mouseName
                
                table.insert(migrated, {
                    mouse   = mouseName,
                    mods    = mods,
                    action  = action,
                    value   = value,
                    display = VB:BuildDisplayString(mods, displayInput),
                    name    = dname,
                })
            end
        end
    end
    
    -- Replace in-place
    for i = 1, #VB.clickCastings do VB.clickCastings[i] = nil end
    for i, b in ipairs(migrated) do VB.clickCastings[i] = b end
    
    VB:Debug("Migrated " .. #migrated .. " bindings to v2 format")
end

-------------------------------------------------
-- Initialize Click Castings
-------------------------------------------------
function VB:InitClickCastings()
    if not VB.clickCastings or #VB.clickCastings == 0 then
        -- Default bindings in v2 format
        VB.clickCastings = {
            { mouse = "Left",  mods = "", action = "target",     display = "Left Click" },
            { mouse = "Right", mods = "", action = "togglemenu", display = "Right Click" },
        }
        if VoidBoxDB and VoidBoxDB.classBindings and VB.playerClass then
            VoidBoxDB.classBindings[VB.playerClass] = VB.clickCastings
        end
    else
        VB:MigrateBindings()
    end
end

-------------------------------------------------
-- Get attribute key for a mouse binding
-------------------------------------------------
local function GetMouseAttrKey(binding)
    local prefix = modPrefixes[binding.mods or ""] or ""
    local id = mouseKeyIDs[binding.mouse]
    if id then return prefix .. "type" .. id end
    return nil
end

-------------------------------------------------
-- Setup Secure Keyboard Bindings
-- Uses SecureHandlerWrapScript on OnEnter/OnLeave
-- to SetBindingClick for keyboard combos and scroll wheel.
-- The snippet reads attributes _vbKB1, _vbKB2... for the
-- WoW binding strings, and _vbKBBtn1... for the virtual button.
-------------------------------------------------
function VB:SetupSecureBindings(button)
    local btnName = button:GetName()
    if not btnName then return end
    
    -- Collect keyboard bindings + scroll bindings
    local kbBindings = {}
    local hasScroll = false
    local kbIndex = 0
    
    for _, binding in ipairs(VB.clickCastings) do
        if binding.combo then
            -- Keyboard binding
            kbIndex = kbIndex + 1
            local virtualBtn = "VBKey" .. kbIndex
            kbBindings[kbIndex] = { combo = binding.combo, virtualBtn = virtualBtn }
            
            -- Set the action attributes for this virtual button
            VB:SetButtonActionAttr(button, virtualBtn, binding)
        end
        if binding.mouse == "ScrollUp" or binding.mouse == "ScrollDown" then
            hasScroll = true
        end
    end
    
    -- Store binding info as attributes for the secure snippet
    button:SetAttribute("_vbKBCount", kbIndex)
    for i, kb in ipairs(kbBindings) do
        button:SetAttribute("_vbKB" .. i, kb.combo)
        button:SetAttribute("_vbKBBtn" .. i, kb.virtualBtn)
    end
    
    -- Enable mousewheel if needed
    button:EnableMouseWheel(hasScroll)
    
    -- Only wrap once
    if button._vbSecureWrapped then return end
    button._vbSecureWrapped = true
    
    -- Build the secure snippet for OnEnter
    SecureHandlerWrapScript(button, "OnEnter", button, [[
        local btn = self:GetName()
        if not btn then return end
        
        -- Scroll wheel bindings
        self:SetBindingClick(true, "MOUSEWHEELUP", btn, "Button6")
        self:SetBindingClick(true, "MOUSEWHEELDOWN", btn, "Button7")
        
        -- Keyboard bindings
        local count = self:GetAttribute("_vbKBCount") or 0
        for i = 1, count do
            local combo = self:GetAttribute("_vbKB" .. i)
            local vBtn = self:GetAttribute("_vbKBBtn" .. i)
            if combo and vBtn then
                self:SetBindingClick(true, combo, btn, vBtn)
            end
        end
    ]])
    
    SecureHandlerWrapScript(button, "OnLeave", button, [[
        self:ClearBindings()
    ]])
end

-------------------------------------------------
-- Set action attributes for a virtual button name
-------------------------------------------------
function VB:SetButtonActionAttr(button, virtualBtn, binding)
    if InCombatLockdown() then return end
    
    local typeKey = "type-" .. virtualBtn
    local action = binding.action
    
    if action == "spell" then
        local spellName = binding.value
        if type(binding.value) == "number" then
            spellName = VB:GetSpellName(binding.value)
        end
        if spellName then
            button:SetAttribute(typeKey, "spell")
            button:SetAttribute("spell-" .. virtualBtn, spellName)
        end
    elseif action == "macro" then
        button:SetAttribute(typeKey, "macro")
        button:SetAttribute("macrotext-" .. virtualBtn, binding.value)
    elseif action == "target" then
        button:SetAttribute(typeKey, "target")
    elseif action == "focus" then
        button:SetAttribute(typeKey, "focus")
    elseif action == "togglemenu" then
        button:SetAttribute(typeKey, "togglemenu")
    elseif action == "assist" then
        button:SetAttribute(typeKey, "assist")
    end
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
    
    -- Apply mouse bindings as standard SecureUnitButton attributes
    for _, binding in ipairs(VB.clickCastings) do
        if binding.mouse and not binding.combo then
            local attrKey = GetMouseAttrKey(binding)
            if attrKey then
                VB:SetButtonAttribute(button, attrKey, binding.action, binding.value)
            end
        end
    end
    
    -- Setup secure keyboard + scroll bindings
    VB:SetupSecureBindings(button)
    
    return true
end

-- Legacy-compatible SetButtonAttribute (for mouse bindings)
function VB:SetButtonAttribute(button, attrKey, actionType, actionValue)
    if InCombatLockdown() then return end
    
    if actionType == "spell" then
        local spellName = actionValue
        if type(actionValue) == "number" then
            spellName = VB:GetSpellName(actionValue)
        end
        if spellName then
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
    
    -- Clear mouse attributes
    for _, mod in pairs(modPrefixes) do
        for _, id in pairs(mouseKeyIDs) do
            local attrKey = mod .. "type" .. id
            button:SetAttribute(attrKey, nil)
            button:SetAttribute(attrKey:gsub("type", "spell"), nil)
            button:SetAttribute(attrKey:gsub("type", "macro"), nil)
            button:SetAttribute(attrKey:gsub("type", "macrotext"), nil)
        end
    end
    
    -- Clear keyboard virtual button attributes
    local oldCount = button:GetAttribute("_vbKBCount") or 0
    for i = 1, math.max(oldCount, 20) do
        local vBtn = "VBKey" .. i
        button:SetAttribute("type-" .. vBtn, nil)
        button:SetAttribute("spell-" .. vBtn, nil)
        button:SetAttribute("macrotext-" .. vBtn, nil)
        button:SetAttribute("_vbKB" .. i, nil)
        button:SetAttribute("_vbKBBtn" .. i, nil)
    end
    button:SetAttribute("_vbKBCount", 0)
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

-------------------------------------------------
-- Add / Remove Bindings (v2 format)
-------------------------------------------------
function VB:AddBinding(binding)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return false
    end
    
    -- Check for duplicate combo
    local key = binding.combo or (binding.mods or "") .. ":" .. (binding.mouse or "")
    for i, existing in ipairs(VB.clickCastings) do
        local eKey = existing.combo or (existing.mods or "") .. ":" .. (existing.mouse or "")
        if eKey == key then
            -- Replace existing
            VB.clickCastings[i] = binding
            VB:ApplyClickCastingsToAllFrames()
            return true
        end
    end
    
    table.insert(VB.clickCastings, binding)
    VB:ApplyClickCastingsToAllFrames()
    return true
end

function VB:RemoveBindingAt(index)
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return false
    end
    if index >= 1 and index <= #VB.clickCastings then
        table.remove(VB.clickCastings, index)
        VB:ApplyClickCastingsToAllFrames()
        return true
    end
    return false
end

-- Legacy compat: RemoveClickCasting by attrKey (used by old delete buttons)
function VB:RemoveClickCasting(attrKeyOrIndex)
    if type(attrKeyOrIndex) == "number" then
        return VB:RemoveBindingAt(attrKeyOrIndex)
    end
    -- Should not happen in v2, but just in case
    return false
end

-------------------------------------------------
-- Display Helpers
-------------------------------------------------
function VB:GetBindingDisplayText(binding)
    if type(binding) == "table" and binding.display then
        return binding.display
    end
    return "?"
end

function VB:GetActionDisplayText(binding)
    if type(binding) ~= "table" then return "?" end
    local action = binding.action
    local value = binding.value
    local dname = binding.name
    
    if action == "spell" then
        local spellName = value
        if type(value) == "number" then
            spellName = VB:GetSpellName(value) or VB.L["DISPLAY_UNKNOWN_SPELL"]
        end
        return "|cFF00FF00" .. (spellName or "Spell") .. "|r"
    elseif action == "macro" then
        local name = dname or ""
        if name ~= "" then
            return "|cFFFFFF00Macro:|r " .. name
        end
        local preview = value or ""
        if type(preview) == "string" and #preview > 20 then preview = preview:sub(1, 20) .. "..." end
        return "|cFFFFFF00Macro:|r " .. tostring(preview)
    elseif action == "target" then
        return "|cFFFFFFFF" .. VB.L["DISPLAY_TARGET"] .. "|r"
    elseif action == "focus" then
        return "|cFFFF8800" .. VB.L["DISPLAY_FOCUS"] .. "|r"
    elseif action == "togglemenu" then
        return "|cFF888888" .. VB.L["DISPLAY_MENU"] .. "|r"
    elseif action == "assist" then
        return "|cFFFF00FF" .. VB.L["DISPLAY_ASSIST"] .. "|r"
    end
    return action or "?"
end

-------------------------------------------------
-- Ignored Keys Check
-------------------------------------------------
function VB:IsIgnoredKey(key)
    return ignoredKeys[key] or false
end

