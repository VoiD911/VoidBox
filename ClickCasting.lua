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
        rankLocked = true,              -- optional: cast this exact rank (downrank)
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

    -- Fallback bindings are global, not per-frame: install them once here so
    -- they exist even before any unit button has been built.
    if not VB.hasSecureSnippets then
        VB:ApplyFallbackKeyBindings()
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
-- Keyboard Proxy Buttons
-- Each keyboard binding gets a dedicated invisible SecureActionButton.
-- On hover (OnEnter), the secure snippet updates the proxy's "unit"
-- attribute to match the hovered unit frame, then binds the key
-- to click the proxy. On leave, bindings are cleared.
-- This approach works because SetBindingClick with a real named
-- button + "LeftButton" is fully supported by the WoW secure system.
-------------------------------------------------
VB._kbProxies = {}
VB._kbProxyCount = 0

function VB:GetOrCreateKBProxy(index, binding)
    if VB._kbProxies[index] then return VB._kbProxies[index] end
    
    VB._kbProxyCount = VB._kbProxyCount + 1
    local name = "VoidBoxKBProxy" .. VB._kbProxyCount
    -- SecureUnitButtonTemplate so the "unit" attribute is used for spell targeting
    -- Must NOT be Hide()'d — hidden buttons can't receive binding clicks
    -- Instead, placed off-screen with 0 alpha and no mouse interaction
    local proxy = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
    proxy:SetAlpha(0)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    
    VB._kbProxies[index] = proxy
    return proxy
end

-- What a spell binding casts, in the two forms the secure templates take.
--   attrValue - for a "spell" attribute. A pinned rank is passed as its numeric
--               ID, which the template casts with CastSpellByID: exact, and no
--               localized "(Rank N)" parsing involved.
--   macroName - for macro text. Macros only take names, so a pinned rank falls
--               back to the Classic "Name(Rank N)" form.
-- Unpinned bindings resolve to the bare name, which always casts the top rank.
function VB:ResolveSpellForCast(value, rankLocked)
    if type(value) ~= "number" then return value, value end

    local name = VB:GetSpellName(value)
    if not name then return nil, nil end

    if rankLocked then
        local _, subtext = VB:GetSpellRank(value)
        return value, subtext and (name .. "(" .. subtext .. ")") or name
    end
    return name, name
end

-- mouseoverMode: no secure snippet is available to push the hovered unit into
-- the proxy's "unit" attribute, so the proxy has to resolve @mouseover itself.
function VB:ConfigureKBProxy(proxy, binding, mouseoverMode)
    if InCombatLockdown() then return end

    -- Ensure vehicle toggle like main unit buttons
    proxy:SetAttribute("toggleForVehicle", true)

    local action = binding.action
    if action == "spell" then
        local attrValue, spellName = VB:ResolveSpellForCast(binding.value, binding.rankLocked)
        if spellName then
            if mouseoverMode and binding.rankLocked and type(attrValue) == "number" then
                -- Macro text only takes names, and Forever does not parse the
                -- "(Rank N)" form, so a pinned rank cannot go through /cast.
                -- Cast it by ID through the spell attribute instead - the same
                -- CastSpellByID path mouse bindings use - aimed at the unit under
                -- the cursor. Trade-offs vs the macro: no fallback to the current
                -- target when nothing is hovered, and no auto-target.
                proxy:SetAttribute("type", "spell")
                proxy:SetAttribute("spell", attrValue)
                proxy:SetAttribute("unit", "mouseover")
                proxy:SetAttribute("macrotext", nil)
            elseif mouseoverMode then
                proxy:SetAttribute("type", "macro")
                if VB.config.autoTargetOnCast then
                    proxy:SetAttribute("macrotext",
                        "/target [@mouseover,exists]\n/cast [@mouseover,exists,nodead][] " .. spellName)
                else
                    proxy:SetAttribute("macrotext",
                        "/cast [@mouseover,exists,nodead][] " .. spellName)
                end
            elseif VB.config.autoTargetOnCast then
                proxy:SetAttribute("type", "macro")
                proxy:SetAttribute("macrotext", "/target [@mouseover,exists]\n/cast " .. spellName)
            else
                proxy:SetAttribute("type", "spell")
                proxy:SetAttribute("spell", attrValue)
            end
        end
    elseif action == "macro" then
        proxy:SetAttribute("type", "macro")
        proxy:SetAttribute("macrotext", binding.value)
    elseif action == "target" then
        -- Always a macro: proxies are SecureUnitButtons too, and a key bound with
        -- a modifier (Alt+F1...) reaches SecureUnitButton_OnClick with that
        -- modifier held, where type=target is dropped unless Blizzard's own
        -- click-binding profile has a matching interaction.
        proxy:SetAttribute("type", "macro")
        proxy:SetAttribute("macrotext", "/target [@mouseover,exists]")
    elseif action == "focus" then
        if mouseoverMode then
            proxy:SetAttribute("type", "macro")
            proxy:SetAttribute("macrotext", "/focus [@mouseover,exists]")
        else
            proxy:SetAttribute("type", "focus")
        end
    elseif action == "togglemenu" then
        -- togglemenu needs a resolved unit attribute, which the fallback path
        -- cannot provide; the binding is simply skipped there.
        if not mouseoverMode then
            proxy:SetAttribute("type", "togglemenu")
        end
    elseif action == "assist" then
        if mouseoverMode then
            proxy:SetAttribute("type", "macro")
            proxy:SetAttribute("macrotext", "/assist [@mouseover,exists]")
        else
            proxy:SetAttribute("type", "assist")
        end
    end
end

-------------------------------------------------
-- Mouse wheel helpers (fallback path)
-------------------------------------------------
-- True when the unit under the cursor is NOT a living friendly unit.
-- Not [party]/[raid]: /vb debugwheel showed both evaluate false on Forever
-- IN COMBAT even over a group member (exists/help stay true), which stopped
-- every wheel cast in combat. [help] is the narrowest filter that holds there;
-- it also matches friendly players and NPCs outside the group, and the
-- player's own 3D model.
local WHEEL_BLOCKED = "[@mouseover,noexists][@mouseover,dead][@mouseover,nohelp]"

-- Did the gate get past its /stopmacro? The gate's last line /clicks this
-- marker, so it only fires when the action ran. The decision is the secure
-- macro engine's own: re-evaluating the conditions from addon code with
-- SecureCmdOptionParse disagreed in combat (unit identity is hidden from
-- tainted code there), and zoomed on top of a successful cast.
local wheelActionRan = false
local WHEEL_MARKER = "VoidBoxWheelMarker"

local function EnsureWheelMarker()
    if _G[WHEEL_MARKER] then return end
    -- Plain, non-secure button: shown (off-screen, invisible) because hidden
    -- buttons may not take clicks
    local marker = CreateFrame("Button", WHEEL_MARKER, UIParent)
    marker:SetSize(1, 1)
    marker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
    marker:SetAlpha(0)
    marker:EnableMouse(false)
    marker:RegisterForClicks("AnyUp", "AnyDown")
    marker:SetScript("OnClick", function() wheelActionRan = true end)
end

-- /vb debugwheel: which @mouseover conditionals does the SECURE macro engine
-- consider true? Evaluating them from addon code is exactly what misreports in
-- combat, so each one gets a marker button the gate /clicks when it holds.
local WHEEL_PROBES = { "exists", "help", "dead", "party", "raid" }
local wheelProbeHits = {}

local function EnsureWheelProbes()
    for _, cond in ipairs(WHEEL_PROBES) do
        local name = "VoidBoxWheelProbe_" .. cond
        if not _G[name] then
            local b = CreateFrame("Button", name, UIParent)
            b:SetSize(1, 1)
            b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)
            b:SetAlpha(0)
            b:EnableMouse(false)
            b:RegisterForClicks("AnyUp", "AnyDown")
            b:SetScript("OnClick", function() wheelProbeHits[cond] = true end)
        end
    end
end

local function WheelProbeLines()
    local lines = {}
    for _, cond in ipairs(WHEEL_PROBES) do
        lines[#lines + 1] = "/click [@mouseover," .. cond .. "] VoidBoxWheelProbe_" .. cond
    end
    return table.concat(lines, "\n") .. "\n"
end

-- Runs after a wheel gate's secure handler. If the action did not run, the
-- wheel did nothing, so give the camera its zoom back.
local function ReplayWheelZoom(self)
    if VB._debugWheel then
        local parts = {}
        for _, cond in ipairs(WHEEL_PROBES) do
            parts[#parts + 1] = cond .. "=" .. tostring(wheelProbeHits[cond] == true)
        end
        VB:Print(("  [wheel] combat=%s %s -> action ran=%s"):format(
            tostring(InCombatLockdown()), table.concat(parts, " "), tostring(wheelActionRan)))
        wipe(wheelProbeHits)
    end
    if not self._vbZoomDir then return end
    local ran = wheelActionRan
    wheelActionRan = false
    if ran then return end
    -- Proxies take both press and release; zoom once
    local now = GetTime()
    if self._vbLastZoom == now then return end
    self._vbLastZoom = now
    if self._vbZoomDir > 0 then CameraZoomIn(1) else CameraZoomOut(1) end
end

-- Macro lines performing a binding's action on @mouseover, for a wheel gate.
-- newProxy() allocates a proxy when one is needed (pinned ranks only).
function VB:BuildWheelActionText(binding, newProxy)
    local action = binding.action
    if action == "spell" then
        local attrValue, spellName = VB:ResolveSpellForCast(binding.value, binding.rankLocked)
        if not spellName then return nil end
        local prefix = VB.config.autoTargetOnCast and "/target [@mouseover]\n" or ""
        if binding.rankLocked and type(attrValue) == "number" then
            -- A pinned rank needs the ID, which macro text cannot carry; a
            -- type=spell button is not a macro, so /clicking it is fine.
            local proxy = newProxy()
            proxy:SetAttribute("type", "spell")
            proxy:SetAttribute("spell", attrValue)
            proxy:SetAttribute("unit", "mouseover")
            proxy:SetAttribute("macrotext", nil)
            return prefix .. "/click " .. proxy:GetName()
        end
        return prefix .. "/cast [@mouseover] " .. spellName
    elseif action == "target" then
        return "/target [@mouseover]"
    elseif action == "focus" then
        return "/focus [@mouseover]"
    elseif action == "assist" then
        return "/assist [@mouseover]"
    elseif action == "macro" then
        return binding.value
    end
    return nil
end

-------------------------------------------------
-- Fallback keyboard bindings (no secure snippets)
--
-- Forever builds without loadstring_untainted cannot compile _onenter/_onleave,
-- so hover-scoped bindings are impossible. Instead we install global override
-- bindings onto @mouseover proxy buttons - the classic mouseover-macro approach.
-- Trade-offs: bindings are global rather than frame-scoped, and scroll-wheel
-- click-casting is off by default (overriding MOUSEWHEEL globally would eat
-- camera zoom); the opt-in wheel path below gates it and re-emits the zoom.
-------------------------------------------------
function VB:ApplyFallbackKeyBindings()
    if InCombatLockdown() then
        VB.pendingClickCastings = true
        return false
    end

    if not VB._bindingOwner then
        VB._bindingOwner = CreateFrame("Frame", "VoidBoxBindingOwner", UIParent)
    end
    ClearOverrideBindings(VB._bindingOwner)

    for _, proxy in pairs(VB._kbProxies) do
        proxy._vbZoomDir = nil
    end

    local index = 0
    for _, binding in ipairs(VB.clickCastings) do
        if binding.combo then
            index = index + 1
            local proxy = VB:GetOrCreateKBProxy(index, binding)
            VB:ConfigureKBProxy(proxy, binding, true)
            SetOverrideBindingClick(VB._bindingOwner, true, binding.combo,
                                    proxy:GetName(), "LeftButton")
        end
    end

    -- Mouse wheel, opt-in (VB.config.fallbackWheelBindings).
    --
    -- On Retail the wheel is bound on hover by the _onenter snippet. Without
    -- snippets it can only be a global binding, which would steal the wheel
    -- everywhere - so each wheel binding is a gate macro:
    --   /stopmacro <unit under the cursor is not a living friendly unit>
    --   <the action itself>
    -- (see WHEEL_BLOCKED for why this is [help] and not [party]/[raid])
    --
    -- The action is written into the gate itself rather than /clicking another
    -- macro button: a macro started from inside a macro does not run, so a
    -- nested /target or /cast was silently dropped. Pinned ranks still /click a
    -- proxy, but that proxy is type=spell, not a macro.
    --
    -- When the gate stops, the camera zoom it swallowed is replayed from a Lua
    -- hook; the gate's final /click on a marker button tells the hook the
    -- action ran. Not a /run line: since 10.1 any /run in a macro pops
    -- Blizzard's "allow custom scripts" warning.
    local wheels = 0
    if VB.config.fallbackWheelBindings then
        for _, binding in ipairs(VB.clickCastings) do
            if not binding.combo
               and (binding.mouse == "ScrollUp" or binding.mouse == "ScrollDown") then
                local actionText = VB:BuildWheelActionText(binding, function()
                    index = index + 1
                    return VB:GetOrCreateKBProxy(index, binding)
                end)
                -- togglemenu has no macro form: leave that wheel unbound
                if actionText then
                    local up = binding.mouse == "ScrollUp"
                    local mods = binding.mods or ""

                    index = index + 1
                    local gate = VB:GetOrCreateKBProxy(index, binding)
                    gate:SetAttribute("type", "macro")
                    -- The marker comes last: the action has already gone out
                    -- before anything else runs.
                    EnsureWheelMarker()
                    local probes = ""
                    if VB._debugWheel then
                        EnsureWheelProbes()
                        probes = WheelProbeLines()
                    end
                    gate:SetAttribute("macrotext", probes
                        .. "/stopmacro " .. WHEEL_BLOCKED .. "\n" .. actionText
                        .. "\n/click " .. WHEEL_MARKER)
                    -- Modified wheels have no default action to replay
                    gate._vbZoomDir = (mods == "") and (up and 1 or -1) or nil
                    if not gate._vbZoomHooked then
                        gate._vbZoomHooked = true
                        gate:HookScript("OnClick", ReplayWheelZoom)
                    end

                    local wheelKey = VB:BuildWoWBindingString(mods, up and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
                    SetOverrideBindingClick(VB._bindingOwner, true, wheelKey, gate:GetName(), "LeftButton")
                    wheels = wheels + 1
                end
            end
        end
    end

    VB:Debug("Fallback bindings applied: " .. index .. " proxies, " .. wheels .. " wheel")
    return true
end

-------------------------------------------------
-- Setup Secure Keyboard Bindings
-- Uses _onenter/_onleave attributes on the button
-- (which inherits SecureHandlerEnterLeaveTemplate).
-- On enter: SetBindingClick for scroll + keyboard proxies.
-- On leave: ClearBindings.
-------------------------------------------------
function VB:SetupSecureBindings(button)
    local btnName = button:GetName()
    if not btnName then return end

    -- Without loadstring_untainted the client cannot compile snippets at all,
    -- so setting _onenter would be a silent no-op. Take the fallback path.
    if not VB.hasSecureSnippets then
        button:EnableMouseWheel(false)
        return VB:ApplyFallbackKeyBindings()
    end
    
    -- Collect keyboard bindings + scroll bindings
    local kbBindings = {}
    local hasScroll = false
    local kbIndex = 0
    
    for _, binding in ipairs(VB.clickCastings) do
        if binding.combo then
            kbIndex = kbIndex + 1
            
            -- Create/configure a proxy button for this keyboard binding
            local proxy = VB:GetOrCreateKBProxy(kbIndex, binding)
            VB:ConfigureKBProxy(proxy, binding)
            
            kbBindings[kbIndex] = { combo = binding.combo, proxyName = proxy:GetName() }
        end
        if binding.mouse == "ScrollUp" or binding.mouse == "ScrollDown" then
            hasScroll = true
        end
    end
    
    -- Enable mousewheel if needed
    button:EnableMouseWheel(hasScroll)
    
    -- SetFrameRef for each proxy so the _onenter snippet can access them
    for i, kb in ipairs(kbBindings) do
        SecureHandlerSetFrameRef(button, "vbProxy" .. i, VB._kbProxies[i])
    end
    
    -- Build the _onenter snippet string dynamically
    -- This runs in the restricted environment when mouse enters the button
    -- "self" in _onenter = the button itself (it's the handler owner)
    local enterParts = {}
    table.insert(enterParts, 'self:ClearBindings()')
    
    -- Scroll wheel: always bind bare scroll up/down
    table.insert(enterParts, string.format(
        'self:SetBindingClick(true, "MOUSEWHEELUP", "%s", "Button6")', btnName))
    table.insert(enterParts, string.format(
        'self:SetBindingClick(true, "MOUSEWHEELDOWN", "%s", "Button7")', btnName))
    
    -- Also bind modifier+scroll combos via dedicated proxy buttons
    -- SetBindingClick doesn't transmit modifier state, so we need proxies
    -- with the action pre-configured (same pattern as keyboard bindings)
    for _, binding in ipairs(VB.clickCastings) do
        if (binding.mouse == "ScrollUp" or binding.mouse == "ScrollDown") and (binding.mods or "") ~= "" then
            kbIndex = kbIndex + 1
            local proxy = VB:GetOrCreateKBProxy(kbIndex, binding)
            VB:ConfigureKBProxy(proxy, binding)
            
            local parts = {}
            local mods = binding.mods
            if mods:find("alt") then table.insert(parts, "ALT") end
            if mods:find("ctrl") then table.insert(parts, "CTRL") end
            if mods:find("shift") then table.insert(parts, "SHIFT") end
            local modPrefix = table.concat(parts, "-") .. "-"
            local wowKey = binding.mouse == "ScrollUp" and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
            
            SecureHandlerSetFrameRef(button, "vbProxy" .. kbIndex, proxy)
            kbBindings[kbIndex] = { combo = modPrefix .. wowKey, proxyName = proxy:GetName() }
        end
    end
    
    -- Keyboard bindings
    local unit_line = 'local unit = self:GetAttribute("unit")'
    if kbIndex > 0 then
        table.insert(enterParts, unit_line)
    end
    for i, kb in ipairs(kbBindings) do
        -- Update proxy unit, then bind key to proxy
        table.insert(enterParts, string.format(
            'local p%d = self:GetFrameRef("vbProxy%d")', i, i))
        table.insert(enterParts, string.format(
            'if p%d then p%d:SetAttribute("unit", unit) end', i, i))
        table.insert(enterParts, string.format(
            'self:SetBindingClick(true, "%s", "%s", "LeftButton")',
            kb.combo, kb.proxyName))
    end
    
    local enterSnippet = table.concat(enterParts, "\n")
    local leaveSnippet = 'self:ClearBindings()'
    
    -- Set the _onenter/_onleave attributes
    -- SecureHandlerEnterLeaveTemplate executes these in the restricted env
    -- Setting a snippet attribute only stores text: measured on Forever 69913,
    -- SetAttribute("_onattributechanged", ...) succeeds even though snippets
    -- cannot run there, and the failure only surfaces when the snippet
    -- executes. So this pcall guards against SetAttribute itself raising, not
    -- against a broken snippet engine - that case is what the
    -- VB.hasSecureSnippets check (loadstring_untainted present) is for, and
    -- /vb debugsnippets is how to verify it against a real execution.
    local compiled = pcall(button.SetAttribute, button, "_onenter", enterSnippet)
    if compiled then
        pcall(button.SetAttribute, button, "_onleave", leaveSnippet)
    else
        VB.hasSecureSnippets = false
        button:EnableMouseWheel(false)
        VB:Print("|cffffcc00" .. VB.L["SNIPPETS_FAILED"] .. "|r")
        VB:ApplyFallbackKeyBindings()
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
                VB:SetButtonAttribute(button, attrKey, binding.action, binding.value, binding.rankLocked)
            end
        end
    end
    
    -- Setup secure keyboard + scroll bindings
    VB:SetupSecureBindings(button)
    
    return true
end

-- Legacy-compatible SetButtonAttribute (for mouse bindings)
function VB:SetButtonAttribute(button, attrKey, actionType, actionValue, rankLocked)
    if InCombatLockdown() then return end

    if actionType == "spell" then
        local attrValue, spellName = VB:ResolveSpellForCast(actionValue, rankLocked)
        if spellName then
            if VB.config.autoTargetOnCast then
                -- Wrap as macro: target + cast
                button:SetAttribute(attrKey, "macro")
                local macroKey = attrKey:gsub("type", "macrotext")
                button:SetAttribute(macroKey, "/target [@mouseover,exists]\n/cast " .. spellName)
            else
                button:SetAttribute(attrKey, "spell")
                local spellKey = attrKey:gsub("type", "spell")
                button:SetAttribute(spellKey, attrValue)
            end
        end
    elseif actionType == "macro" then
        button:SetAttribute(attrKey, "macro")
        local macroKey = attrKey:gsub("type", "macrotext")
        button:SetAttribute(macroKey, actionValue)
    elseif actionType == "target" then
        -- Blizzard's SecureUnitButton_OnClick (Retail 10.0+, Forever) throws away
        -- a type=target click unless its OWN click-binding profile has a
        -- "target" interaction on that exact button+modifiers. The default
        -- profile only has one on plain Left, so Alt+Left, Middle, etc. did
        -- nothing. Macros are not subject to that check, and hovering one of
        -- our frames reliably sets @mouseover (verified with /vb debugmouseover).
        if attrKey == "type1" then
            button:SetAttribute(attrKey, "target")
        else
            button:SetAttribute(attrKey, "macro")
            local macroKey = attrKey:gsub("type", "macrotext")
            button:SetAttribute(macroKey, "/target [@mouseover,exists]")
        end
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
    
    -- Clear keyboard proxy attributes
    local oldCount = button:GetAttribute("_vbKBCount") or 0
    for i = 1, math.max(oldCount, 20) do
        button:SetAttribute("_vbKB" .. i, nil)
        button:SetAttribute("_vbKBProxy" .. i, nil)
    end
    button:SetAttribute("_vbKBCount", 0)
    
    -- Drop fallback global bindings (no-op when snippets are available)
    if VB._bindingOwner then
        ClearOverrideBindings(VB._bindingOwner)
    end

    -- Clear proxy button configurations
    for i, proxy in pairs(VB._kbProxies) do
        proxy:SetAttribute("type", nil)
        proxy:SetAttribute("spell", nil)
        proxy:SetAttribute("macrotext", nil)
        proxy:SetAttribute("unit", nil)
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
    for _, button in pairs(VB.tankButtons) do
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
            -- Pinned ranks show their rank; top-rank bindings stay bare because
            -- they follow the player up to the next rank.
            spellName = VB:GetBindingSpellLabel(value, binding.rankLocked)
                or VB.L["DISPLAY_UNKNOWN_SPELL"]
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

