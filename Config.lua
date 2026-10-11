--[[
    VoidBox - Configuration UI
    Interface de configuration avec "Press to Bind" universal capture
    Compatible 12.0+ : pas de UIDropDownMenu, pas de OptionsSliderTemplate
]]

local addonName, VB = ...

local configFrame = nil
local bindingSlots = {}

-------------------------------------------------
-- UI Helpers (dropdown, slider) — must be defined
-- before any function that uses them
-------------------------------------------------
local function CreateSimpleDropdown(parent, width, items, defaultText, onSelect)
    local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
    dropdown:SetSize(width, 25)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(0.15, 0.15, 0.15, 1)
    dropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 8, 0)
    text:SetText(defaultText or "")
    dropdown.text = text
    local arrow = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")
    dropdown.selectedValue = items[1] and items[1].value or nil
    dropdown.isOpen = false
    local menu = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.12, 0.12, 0.12, 0.98)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, #items * 22 + 4)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:Hide()
    dropdown.menu = menu
    for i, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, menu, "BackdropTemplate")
        btn:SetSize(width - 4, 20)
        btn:SetPoint("TOPLEFT", 2, -(i-1) * 22 - 2)
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("LEFT", 6, 0)
        btnText:SetText(item.text)
        btn:SetScript("OnClick", function()
            dropdown.selectedValue = item.value
            text:SetText(item.text)
            menu:Hide()
            dropdown.isOpen = false
            if onSelect then onSelect(item.value) end
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
        btn:SetScript("OnLeave", function(self) self:SetBackdrop(nil) end)
    end
    dropdown:SetScript("OnClick", function()
        dropdown.isOpen = not dropdown.isOpen
        menu:SetShown(dropdown.isOpen)
    end)
    dropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    dropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.15, 1) end)
    return dropdown
end

local function CreateSimpleSlider(parent, label, minVal, maxVal, step, currentVal, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(220, 40)
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label .. ": " .. currentVal)
    container.label = labelText
    local template = nil
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("MinimalSliderTemplate") then
        template = "MinimalSliderTemplate"
    end
    local slider = CreateFrame("Slider", nil, container, template)
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetSize(200, 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValue(currentVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if not slider:GetThumbTexture() then
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end
    if not template then
        local bg = slider:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    end
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        labelText:SetText(label .. ": " .. value)
        if onChange then onChange(value) end
    end)
    container.slider = slider
    return container
end

-------------------------------------------------
-- Show Configuration
-------------------------------------------------
function VB:ShowConfig()
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_CONFIG_COMBAT"])
        return
    end
    
    if configFrame and configFrame:IsShown() then
        configFrame:Hide()
        return
    end
    
    if not configFrame then
        VB:CreateConfigFrame()
    end
    
    VB:RefreshBindingsList()
    configFrame:Show()
end

-------------------------------------------------
-- Create Configuration Frame
-------------------------------------------------
function VB:CreateConfigFrame()
    configFrame = CreateFrame("Frame", "VoidBoxConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(500, 760)
    configFrame:SetPoint("CENTER")
    configFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    configFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    configFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetClampedToScreen(true)
    configFrame:Hide()
    
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFF9966FFVoidBox|r - " .. VB.L["CONFIG_TITLE"])
    
    local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    VB:CreateConfigTabs()
    
    local content = CreateFrame("Frame", nil, configFrame)
    content:SetPoint("TOPLEFT", 10, -70)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    configFrame.content = content
    
    VB:CreateBindingsTab()
    VB:CreateAppearanceTab()
    VB:CreateDebuffsTab()
    VB:CreateScreenAurasTab()
    VB:CreateProfilesTab()
    VB:ShowConfigTab("bindings")
    -- Aura placement previews only live while the Auras tab is on screen
    configFrame:HookScript("OnHide", function() VB:SetScreenAuraPreview(false) end)
    
    if VB.tocVersion > 0 and VB.tocVersion < 100000 then
        -- Classic clients call CloseSpecialWindows when the spellbook opens,
        -- which would close the config while picking spells. Handle Escape
        -- ourselves and let every other key through.
        configFrame:EnableKeyboard(true)
        configFrame:SetPropagateKeyboardInput(true)
        configFrame:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
        configFrame:SetScript("OnShow", function(self) self:SetPropagateKeyboardInput(true) end)
    else
        tinsert(UISpecialFrames, "VoidBoxConfig")
    end
end

-------------------------------------------------
-- Config Tabs
-------------------------------------------------
local tabs = {}

function VB:CreateConfigTabs()
    local tabData = {
        { id = "bindings", text = VB.L["TAB_BINDINGS"] },
        { id = "appearance", text = VB.L["TAB_APPEARANCE"] },
        { id = "debuffs", text = VB.L["TAB_BUFFS"] },
        { id = "auras", text = VB.L["TAB_AURAS"] },
        { id = "profiles", text = VB.L["TAB_PROFILES"] },
    }

    local tabWidth = math.floor((480 - (#tabData - 1) * 5) / #tabData)
    local lastTab = nil
    for i, data in ipairs(tabData) do
        local tab = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
        tab:SetSize(tabWidth, 25)
        tab:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
        tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(data.text)
        tab.text = text
        tab.id = data.id
        
        tab:SetScript("OnClick", function() VB:ShowConfigTab(data.id) end)
        tab:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.3, 1) end)
        tab:SetScript("OnLeave", function(self)
            if self.selected then
                self:SetBackdropColor(0.3, 0.3, 0.5, 1)
            else
                self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            end
        end)
        
        if lastTab then
            tab:SetPoint("LEFT", lastTab, "RIGHT", 5, 0)
        else
            tab:SetPoint("TOPLEFT", 10, -40)
        end
        tabs[data.id] = tab
        lastTab = tab
    end
end

function VB:ShowConfigTab(tabId)
    for id, tab in pairs(tabs) do
        tab.selected = (id == tabId)
        tab:SetBackdropColor(id == tabId and 0.3 or 0.2, id == tabId and 0.3 or 0.2, id == tabId and 0.5 or 0.2, 1)
    end
    if configFrame.bindingsContent then configFrame.bindingsContent:SetShown(tabId == "bindings") end
    if configFrame.appearanceContent then configFrame.appearanceContent:SetShown(tabId == "appearance") end
    if configFrame.debuffsContent then configFrame.debuffsContent:SetShown(tabId == "debuffs") end
    if configFrame.aurasContent then
        configFrame.aurasContent:SetShown(tabId == "auras")
        VB:SetScreenAuraPreview(tabId == "auras")
        if tabId == "auras" then VB:RefreshScreenAurasTab() end
    end
    if configFrame.profilesContent then
        configFrame.profilesContent:SetShown(tabId == "profiles")
        if tabId == "profiles" then VB:RefreshProfilesTab() end
    end
end

-------------------------------------------------
-- Bindings Tab
-------------------------------------------------
function VB:CreateBindingsTab()
    local content = CreateFrame("Frame", nil, configFrame.content)
    content:SetAllPoints()
    configFrame.bindingsContent = content
    
    local instructions = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", 5, -5)
    instructions:SetWidth(460)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("|cFFFFFF00" .. VB.L["INSTRUCTIONS_V2"] .. "|r")
    
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 5, -30)
    header:SetText(VB.L["HEADER_COMBO"] .. "              " .. VB.L["HEADER_ACTION"])
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(440, 400)
    scrollFrame:SetScrollChild(scrollChild)
    content.scrollChild = scrollChild
    
    local addBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
    addBtn:SetSize(150, 25)
    addBtn:SetPoint("BOTTOMLEFT", 5, 10)
    addBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addBtn:SetBackdropColor(0.2, 0.2, 0.4, 1)
    addBtn:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    local addText = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addText:SetPoint("CENTER")
    addText:SetText(VB.L["ADD_BINDING"])
    addBtn:SetScript("OnClick", function() VB:ShowAddBindingDialog() end)
    addBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.5, 1) end)
    addBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.4, 1) end)
end

-------------------------------------------------
-- Refresh Bindings List
-------------------------------------------------
function VB:RefreshBindingsList()
    if not configFrame or not configFrame.bindingsContent then return end
    local scrollChild = configFrame.bindingsContent.scrollChild
    
    for _, slot in ipairs(bindingSlots) do slot:Hide() end
    
    local yOffset = 0
    for i, binding in ipairs(VB.clickCastings) do
        local slot = VB:GetOrCreateBindingSlot(i)
        slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        slot.keyText:SetText(VB:GetBindingDisplayText(binding))
        slot.actionText:SetText(VB:GetActionDisplayText(binding))
        local icon = binding.action == "spell" and type(binding.value) == "number"
            and VB:GetSpellIcon(binding.value) or nil
        slot.actionText:ClearAllPoints()
        -- Room on the right for the hostile spell button
        if icon then
            slot.actionIcon:SetTexture(icon)
            slot.actionIcon:Show()
            slot.actionText:SetPoint("LEFT", 194, 0)
            slot.actionText:SetWidth(150)
        else
            slot.actionIcon:Hide()
            slot.actionText:SetPoint("LEFT", 170, 0)
            slot.actionText:SetWidth(174)
        end
        VB:RefreshHostileButton(slot, binding)
        slot.bindingIndex = i
        slot:Show()
        yOffset = yOffset + 30
    end
    
    scrollChild:SetHeight(math.max(400, yOffset + 50))
end

function VB:GetOrCreateBindingSlot(index)
    if bindingSlots[index] then return bindingSlots[index] end
    
    local scrollChild = configFrame.bindingsContent.scrollChild
    local slot = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    slot:SetSize(440, 28)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slot:SetBackdropColor(0.15, 0.15, 0.15, 1)
    slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    local keyText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyText:SetPoint("LEFT", 10, 0)
    keyText:SetWidth(150)
    keyText:SetJustifyH("LEFT")
    slot.keyText = keyText
    
    -- Spell icon in front of the action name (spells only)
    local actionIcon = slot:CreateTexture(nil, "ARTWORK")
    actionIcon:SetSize(20, 20)
    actionIcon:SetPoint("LEFT", 170, 0)
    actionIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    actionIcon:Hide()
    slot.actionIcon = actionIcon

    local actionText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionText:SetPoint("LEFT", 170, 0)
    actionText:SetWidth(200)
    actionText:SetJustifyH("LEFT")
    slot.actionText = actionText
    
    -- Hostile spell (VuhDo style): what the same click casts on an enemy
    local hostileBtn = CreateFrame("Button", nil, slot, "BackdropTemplate")
    hostileBtn:SetSize(22, 22)
    hostileBtn:SetPoint("RIGHT", -30, 0)
    hostileBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    hostileBtn:SetBackdropColor(0.2, 0.05, 0.05, 1)
    hostileBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    hostileBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hostileIcon = hostileBtn:CreateTexture(nil, "ARTWORK")
    hostileIcon:SetPoint("TOPLEFT", 1, -1)
    hostileIcon:SetPoint("BOTTOMRIGHT", -1, 1)
    hostileIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hostileBtn.icon = hostileIcon
    local hostilePlus = hostileBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hostilePlus:SetPoint("CENTER")
    hostilePlus:SetText("|cFFFF5555+|r")
    hostileBtn.plus = hostilePlus
    slot.hostileBtn = hostileBtn

    local function SetHostileFromCursor()
        local binding = slot.bindingIndex and VB.clickCastings[slot.bindingIndex]
        if not binding or not VB:CanHaveHostileAction(binding) then return end
        if InCombatLockdown() then VB:Print(VB.L["CANNOT_BIND_COMBAT"]) return end
        local spellID = VB:GetCursorSpell()
        if spellID then
            binding.hostileAction = "spell"
            binding.hostileValue = spellID
            binding.hostileRankLocked = VB:IsDownrank(spellID) or nil
            binding.hostileName = nil
        else
            local macroName, _, macroBody = VB:GetCursorMacro()
            if not (macroName and macroBody) then return end
            binding.hostileAction = "macro"
            binding.hostileValue = macroBody
            binding.hostileName = macroName
            binding.hostileRankLocked = nil
        end
        ClearCursor()
        VB:ApplyClickCastingsToAllFrames()
        VB:RefreshBindingsList()
    end
    hostileBtn:SetScript("OnReceiveDrag", SetHostileFromCursor)
    hostileBtn:SetScript("OnClick", function(self, mouseButton)
        local binding = slot.bindingIndex and VB.clickCastings[slot.bindingIndex]
        if not binding then return end
        if mouseButton == "RightButton" then
            if InCombatLockdown() then VB:Print(VB.L["CANNOT_BIND_COMBAT"]) return end
            binding.hostileAction, binding.hostileValue = nil, nil
            binding.hostileRankLocked, binding.hostileName = nil, nil
            VB:ApplyClickCastingsToAllFrames()
            VB:RefreshBindingsList()
        else
            SetHostileFromCursor()
        end
    end)
    hostileBtn:SetScript("OnEnter", function(self)
        local binding = slot.bindingIndex and VB.clickCastings[slot.bindingIndex]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(VB.L["HOSTILE_TITLE"], 1, 0.35, 0.35)
        local hostile = binding and VB:GetHostileDisplayText(binding)
        if hostile then GameTooltip:AddLine(hostile) end
        GameTooltip:AddLine(VB.L["HOSTILE_HELP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    hostileBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local deleteBtn = CreateFrame("Button", nil, slot)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", -5, 0)
    deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:GetHighlightTexture():SetVertexColor(1, 0, 0)
    deleteBtn:SetScript("OnClick", function()
        if slot.bindingIndex then
            VB:RemoveBindingAt(slot.bindingIndex)
            VB:RefreshBindingsList()
        end
    end)
    
    -- Drag spell/macro onto existing slot to replace action
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnReceiveDrag", function(self)
        if not self.bindingIndex then return end
        local binding = VB.clickCastings[self.bindingIndex]
        if not binding then return end
        
        local spellID, spellName = VB:GetCursorSpell()
        if spellID then
            binding.action = "spell"
            binding.value = spellID
            -- Dragging a lower rank than the best known one means "cast this rank"
            binding.rankLocked = VB:IsDownrank(spellID) or nil
            binding.name = VB:GetBindingSpellLabel(spellID, binding.rankLocked) or spellName
            VB:ApplyClickCastingsToAllFrames()
            VB:RefreshBindingsList()
            ClearCursor()
            return
        end
        
        local macroName, macroIcon, macroBody = VB:GetCursorMacro()
        if macroName and macroBody then
            binding.action = "macro"
            binding.value = macroBody
            binding.name = macroName
            VB:ApplyClickCastingsToAllFrames()
            VB:RefreshBindingsList()
            ClearCursor()
        end
    end)
    
    slot:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    slot:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.15, 1) end)
    
    bindingSlots[index] = slot
    return slot
end

-- Hostile button of a bindings list row
function VB:RefreshHostileButton(slot, binding)
    local btn = slot.hostileBtn
    if not btn then return end
    if not VB:CanHaveHostileAction(binding) then
        btn:Hide()
        return
    end
    local icon
    if binding.hostileAction == "spell" and type(binding.hostileValue) == "number" then
        icon = VB:GetSpellIcon(binding.hostileValue)
    elseif binding.hostileAction == "macro" then
        icon = 134400   -- question mark: a macro's icon is not stored
    end
    btn.icon:SetTexture(icon)
    btn.icon:SetShown(icon ~= nil)
    btn.plus:SetShown(icon == nil)
    btn:Show()
end

-------------------------------------------------
-- Add Binding Dialog ("Press to Bind")
-------------------------------------------------
local addDialog = nil

function VB:ShowAddBindingDialog()
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return
    end
    if not addDialog then VB:CreateAddBindingDialog() end
    VB:ResetAddDialog()
    addDialog:Show()
end

-- Mouse button display names
local mouseDisplayNames = {
    LeftButton   = "Left Click",
    RightButton  = "Right Click",
    MiddleButton = "Middle Click",
    Button4      = "Button 4",
    Button5      = "Button 5",
}

-- Mouse button → internal name for binding storage
local mouseInternalNames = {
    LeftButton   = "Left",
    RightButton  = "Right",
    MiddleButton = "Middle",
    Button4      = "Button4",
    Button5      = "Button5",
}

-- Key display overrides
local keyDisplayNames = {
    NUMPAD0 = "Numpad 0", NUMPAD1 = "Numpad 1", NUMPAD2 = "Numpad 2",
    NUMPAD3 = "Numpad 3", NUMPAD4 = "Numpad 4", NUMPAD5 = "Numpad 5",
    NUMPAD6 = "Numpad 6", NUMPAD7 = "Numpad 7", NUMPAD8 = "Numpad 8",
    NUMPAD9 = "Numpad 9", NUMPADDECIMAL = "Numpad .",
    NUMPADPLUS = "Numpad +", NUMPADMINUS = "Numpad -",
    NUMPADMULTIPLY = "Numpad *", NUMPADDIVIDE = "Numpad /",
    SPACE = "Space", TAB = "Tab", BACKSPACE = "Backspace",
    DELETE = "Delete", INSERT = "Insert", HOME = "Home", END = "End",
    PAGEUP = "Page Up", PAGEDOWN = "Page Down",
}

function VB:CreateAddBindingDialog()
    addDialog = CreateFrame("Frame", "VoidBoxAddBinding", UIParent, "BackdropTemplate")
    addDialog:SetSize(320, 385)
    addDialog:SetPoint("CENTER")
    addDialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    addDialog:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
    addDialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    addDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    addDialog:SetMovable(true)
    addDialog:EnableMouse(true)
    addDialog:RegisterForDrag("LeftButton")
    addDialog:SetScript("OnDragStart", addDialog.StartMoving)
    addDialog:SetScript("OnDragStop", addDialog.StopMovingOrSizing)
    addDialog:Hide()
    
    local title = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(VB.L["NEW_BINDING"])
    
    local closeBtn = CreateFrame("Button", nil, addDialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- === Step 1: Capture zone ===
    local captureLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    captureLabel:SetPoint("TOPLEFT", 15, -40)
    captureLabel:SetText(VB.L["STEP1_COMBO"])
    
    local captureBtn = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    captureBtn:SetSize(280, 45)
    captureBtn:SetPoint("TOP", 0, -60)
    captureBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    captureBtn:SetBackdropColor(0.15, 0.15, 0.25, 1)
    captureBtn:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    captureBtn:RegisterForClicks("AnyUp")
    captureBtn:EnableMouseWheel(true)
    addDialog.captureBtn = captureBtn
    
    local captureText = captureBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    captureText:SetPoint("CENTER")
    captureText:SetText("|cFF888888" .. VB.L["PRESS_ANY_COMBO"] .. "|r")
    addDialog.captureText = captureText
    
    -- Capture state
    addDialog.captured = nil  -- { combo, mouse, mods, display, isKey }
    
    -- Mouse click capture
    captureBtn:SetScript("OnClick", function(self, btn)
        local mouseName = mouseInternalNames[btn]
        if not mouseName then return end
        local displayName = mouseDisplayNames[btn] or btn
        local mods = VB:BuildModString(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown())
        local display = VB:BuildDisplayString(mods, displayName)
        
        addDialog.captured = { mouse = mouseName, mods = mods, display = display }
        captureText:SetText("|cFF9966FF" .. display .. "|r")
        captureBtn:SetBackdropBorderColor(0.6, 0.4, 1, 1)
    end)
    
    -- Scroll capture
    captureBtn:SetScript("OnMouseWheel", function(self, delta)
        local scrollName = delta > 0 and "ScrollUp" or "ScrollDown"
        local displayName = delta > 0 and "Scroll Up" or "Scroll Down"
        local mods = VB:BuildModString(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown())
        local display = VB:BuildDisplayString(mods, displayName)
        
        addDialog.captured = { mouse = scrollName, mods = mods, display = display }
        captureText:SetText("|cFF9966FF" .. display .. "|r")
        captureBtn:SetBackdropBorderColor(0.6, 0.4, 1, 1)
    end)
    
    -- Keyboard capture
    captureBtn:SetScript("OnKeyDown", function(self, key)
        if VB:IsIgnoredKey(key) then return end
        local displayName = keyDisplayNames[key] or key
        local mods = VB:BuildModString(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown())
        local combo = VB:BuildWoWBindingString(mods, key)
        local display = VB:BuildDisplayString(mods, displayName)
        
        addDialog.captured = { combo = combo, mods = mods, display = display, isKey = true }
        captureText:SetText("|cFF9966FF" .. display .. "|r")
        captureBtn:SetBackdropBorderColor(0.6, 0.4, 1, 1)
    end)
    captureBtn:SetPropagateKeyboardInput(false)
    
    -- Focus management: enable keyboard capture on enter
    captureBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.35, 1)
    end)
    captureBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.25, 1)
    end)

    -- === Step 2: Action type ===
    local actionLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionLabel:SetPoint("TOPLEFT", 15, -115)
    actionLabel:SetText(VB.L["STEP2_ACTION"])
    
    local actionDropdown = CreateSimpleDropdown(addDialog, 200, {
        { text = VB.L["ACTION_SPELL"], value = "spell" },
        { text = VB.L["ACTION_MACRO"], value = "macro" },
        { text = VB.L["ACTION_TARGET"], value = "target" },
        { text = VB.L["ACTION_FOCUS"], value = "focus" },
        { text = VB.L["ACTION_MENU"], value = "togglemenu" },
        { text = VB.L["ACTION_ASSIST"], value = "assist" },
        { text = VB.L["ACTION_FOLLOW"], value = "follow" },
        { text = VB.L["ACTION_REZ"], value = "rez" },
    }, VB.L["ACTION_SPELL"])
    actionDropdown:SetPoint("TOPLEFT", 15, -133)
    addDialog.actionDropdown = actionDropdown
    
    -- === Step 3: Drop zone for spell/macro ===
    local dropZone = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    dropZone:SetSize(280, 50)
    dropZone:SetPoint("TOP", 0, -175)
    dropZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropZone:SetBackdropColor(0.2, 0.2, 0.3, 1)
    dropZone:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    
    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropText:SetPoint("CENTER")
    dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_MACRO"] .. "|r")
    addDialog.dropText = dropText
    addDialog.dropZone = dropZone
    addDialog.selectedSpell = nil
    addDialog.selectedMacro = nil
    
    dropZone:SetScript("OnReceiveDrag", function()
        local spellID, spellName, spellIcon = VB:GetCursorSpell()
        if spellID and spellName then
            addDialog.selectedSpell = spellID
            addDialog.selectedMacro = nil
            addDialog.actionDropdown.selectedValue = "spell"
            addDialog.actionDropdown.text:SetText(VB.L["ACTION_SPELL"])
            local iconStr = spellIcon and ("|T" .. spellIcon .. ":20|t ") or ""
            -- Say up front when this drop will pin a lower rank
            local label = VB:GetBindingSpellLabel(spellID, VB:IsDownrank(spellID)) or spellName
            dropText:SetText(iconStr .. label)
            ClearCursor()
            return
        end
        
        local macroName, macroIcon, macroBody = VB:GetCursorMacro()
        if macroName and macroBody then
            addDialog.selectedSpell = nil
            addDialog.selectedMacro = { name = macroName, body = macroBody }
            addDialog.actionDropdown.selectedValue = "macro"
            addDialog.actionDropdown.text:SetText(VB.L["ACTION_MACRO"])
            local iconStr = macroIcon and ("|T" .. macroIcon .. ":20|t ") or ""
            dropText:SetText(iconStr .. macroName)
            ClearCursor()
        end
    end)
    
    dropZone:SetScript("OnClick", function()
        addDialog.selectedSpell = nil
        addDialog.selectedMacro = nil
        dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_MACRO"] .. "|r")
    end)

    -- === Step 4: hostile spell (optional) ===
    local hostileZone = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    hostileZone:SetSize(280, 50)
    hostileZone:SetPoint("TOP", 0, -240)
    hostileZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    hostileZone:SetBackdropColor(0.25, 0.1, 0.1, 1)
    hostileZone:SetBackdropBorderColor(0.7, 0.3, 0.3, 1)
    local hostileText = hostileZone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hostileText:SetPoint("CENTER")
    hostileText:SetWidth(270)
    hostileText:SetText("|cFFFF8888" .. VB.L["HOSTILE_DROP"] .. "|r")
    addDialog.hostileText = hostileText
    addDialog.hostile = nil

    hostileZone:SetScript("OnReceiveDrag", function()
        local spellID, spellName, spellIcon = VB:GetCursorSpell()
        if spellID and spellName then
            addDialog.hostile = { action = "spell", value = spellID }
            local iconStr = spellIcon and ("|T" .. spellIcon .. ":20|t ") or ""
            local label = VB:GetBindingSpellLabel(spellID, VB:IsDownrank(spellID)) or spellName
            hostileText:SetText(iconStr .. "|cFFFF5555" .. label .. "|r")
            ClearCursor()
            return
        end
        local macroName, macroIcon, macroBody = VB:GetCursorMacro()
        if macroName and macroBody then
            addDialog.hostile = { action = "macro", value = macroBody, name = macroName }
            local iconStr = macroIcon and ("|T" .. macroIcon .. ":20|t ") or ""
            hostileText:SetText(iconStr .. "|cFFFF5555" .. macroName .. "|r")
            ClearCursor()
        end
    end)
    hostileZone:SetScript("OnClick", function()
        addDialog.hostile = nil
        hostileText:SetText("|cFFFF8888" .. VB.L["HOSTILE_DROP"] .. "|r")
    end)
    
    -- === Confirm button ===
    local confirmBtn = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    confirmBtn:SetSize(120, 28)
    confirmBtn:SetPoint("BOTTOM", 0, 12)
    confirmBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    confirmBtn:SetBackdropColor(0.2, 0.2, 0.5, 1)
    confirmBtn:SetBackdropBorderColor(0.4, 0.4, 0.7, 1)
    local confirmText = confirmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirmText:SetPoint("CENTER")
    confirmText:SetText(VB.L["CONFIRM"])
    confirmBtn:SetScript("OnClick", function() VB:ConfirmAddBinding() end)
    confirmBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.6, 1) end)
    confirmBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.5, 1) end)
    
    tinsert(UISpecialFrames, "VoidBoxAddBinding")
end

function VB:ResetAddDialog()
    if not addDialog then return end
    addDialog.captured = nil
    addDialog.selectedSpell = nil
    addDialog.selectedMacro = nil
    addDialog.captureText:SetText("|cFF888888" .. VB.L["PRESS_ANY_COMBO"] .. "|r")
    addDialog.captureBtn:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    addDialog.dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_MACRO"] .. "|r")
    addDialog.actionDropdown.selectedValue = "spell"
    addDialog.actionDropdown.text:SetText(VB.L["ACTION_SPELL"])
    addDialog.hostile = nil
    addDialog.hostileText:SetText("|cFFFF8888" .. VB.L["HOSTILE_DROP"] .. "|r")
end

function VB:ConfirmAddBinding()
    if not addDialog.captured then
        VB:Print(VB.L["PRESS_COMBO_FIRST"])
        return
    end
    
    local actionType = addDialog.actionDropdown.selectedValue or "spell"
    
    if actionType == "spell" and not addDialog.selectedSpell then
        VB:Print(VB.L["DRAG_SPELL_FIRST"])
        return
    end
    if actionType == "macro" and not addDialog.selectedMacro then
        VB:Print(VB.L["DRAG_MACRO_FIRST"])
        return
    end
    
    local cap = addDialog.captured
    local binding = {
        combo   = cap.combo or nil,
        mouse   = cap.mouse or nil,
        mods    = cap.mods or "",
        action  = actionType,
        display = cap.display,
    }
    
    if actionType == "spell" then
        binding.value = addDialog.selectedSpell
        binding.rankLocked = VB:IsDownrank(addDialog.selectedSpell) or nil
        binding.name = VB:GetBindingSpellLabel(addDialog.selectedSpell, binding.rankLocked)
    elseif actionType == "macro" then
        binding.value = addDialog.selectedMacro.body
        binding.name = addDialog.selectedMacro.name
    end

    local hostile = addDialog.hostile
    if hostile then
        binding.hostileAction = hostile.action
        binding.hostileValue = hostile.value
        binding.hostileName = hostile.name
        if hostile.action == "spell" then
            binding.hostileRankLocked = VB:IsDownrank(hostile.value) or nil
        end
    end

    if VB:AddBinding(binding) then
        VB:RefreshBindingsList()
        addDialog:Hide()
    end
end

-------------------------------------------------
-- Appearance Tab
-------------------------------------------------
function VB:CreateAppearanceTab()
    local panel = CreateFrame("Frame", nil, configFrame.content)
    panel:SetAllPoints()
    panel:Hide()
    configFrame.appearanceContent = panel
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -25, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(455, 1000)
    scroll:SetScrollChild(content)
    
    local yOffset = -10
    
    local hideWhenSoloCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideWhenSoloCB:SetPoint("TOPLEFT", 10, yOffset)
    hideWhenSoloCB.text:SetText(VB.L["HIDE_WHEN_SOLO"])
    hideWhenSoloCB:SetChecked(VB.config.hideWhenSolo or false)
    hideWhenSoloCB:SetScript("OnClick", function(self)
        VB.config.hideWhenSolo = self:GetChecked()
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    yOffset = yOffset - 30

    local hideBlizzardCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    hideBlizzardCB:SetPoint("TOPLEFT", 10, yOffset)
    hideBlizzardCB.text:SetText(VB.L["HIDE_BLIZZARD_FRAMES"])
    hideBlizzardCB:SetChecked(VB.config.hideBlizzardFrames or false)
    hideBlizzardCB:SetScript("OnClick", function(self)
        VB.config.hideBlizzardFrames = self:GetChecked() and true or false
        if VB.config.hideBlizzardFrames then
            VB:ApplyHideBlizzardFrames()
        else
            VB:Print(VB.L["HIDE_BLIZZARD_RELOAD"])
        end
    end)
    yOffset = yOffset - 30
    
    local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 10, yOffset)
    sizeLabel:SetText(VB.L["FRAME_SIZE"])
    yOffset = yOffset - 20
    
    local scaleWSlider = CreateSimpleSlider(content, VB.L["SCALE_WIDTH"], 50, 250, 5, VB.config.scaleWidth or 100, function(value)
        VB.config.scaleWidth = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    scaleWSlider:SetPoint("TOPLEFT", 10, yOffset)
    
    local scaleHSlider = CreateSimpleSlider(content, VB.L["SCALE_HEIGHT"], 50, 250, 5, VB.config.scaleHeight or 100, function(value)
        VB.config.scaleHeight = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    scaleHSlider:SetPoint("TOPLEFT", 240, yOffset)
    yOffset = yOffset - 55
    
    local groupSlider = CreateSimpleSlider(content, VB.L["GROUP_SIZE"], 1, 10, 1, VB.config.maxColumns or 5, function(value)
        VB.config.maxColumns = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    groupSlider:SetPoint("TOPLEFT", 10, yOffset)
    yOffset = yOffset - 55
    
    local keepGroupsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    keepGroupsCB:SetPoint("TOPLEFT", 10, yOffset)
    keepGroupsCB.text:SetText(VB.L["KEEP_GROUPS_TOGETHER"])
    keepGroupsCB:SetChecked(VB.config.keepGroupsTogether or false)
    keepGroupsCB:SetScript("OnClick", function(self)
        VB.config.keepGroupsTogether = self:GetChecked()
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    yOffset = yOffset - 30
    
    local orientLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    orientLabel:SetPoint("TOPLEFT", 10, yOffset)
    orientLabel:SetText(VB.L["ORIENTATION"])
    
    local orientDropdown = CreateSimpleDropdown(content, 180, {
        { text = VB.L["ORIENTATION_H"], value = "HORIZONTAL" },
        { text = VB.L["ORIENTATION_V"], value = "VERTICAL" },
    }, VB.config.orientation == "VERTICAL" and VB.L["ORIENTATION_V"] or VB.L["ORIENTATION_H"])
    orientDropdown:SetPoint("TOPLEFT", 10, yOffset - 18)
    
    local origOrientItems = orientDropdown.menu
    for i = 1, select("#", origOrientItems:GetChildren()) do
        local btn = select(i, origOrientItems:GetChildren())
        local origOnClick = btn:GetScript("OnClick")
        btn:SetScript("OnClick", function(self)
            if origOnClick then origOnClick(self) end
            VB.config.orientation = orientDropdown.selectedValue
            if not InCombatLockdown() then VB:UpdateAllFrames() end
        end)
    end
    
    local roleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleLabel:SetPoint("TOPLEFT", 240, yOffset)
    roleLabel:SetText(VB.L["ROLE_ORDER"])
    
    local roleOrderItems = {
        { text = "Tank > DPS > Healer", value = "TDH" },
        { text = "Tank > Healer > DPS", value = "THD" },
        { text = "Healer > DPS > Tank", value = "HDT" },
        { text = "Healer > Tank > DPS", value = "HTD" },
        { text = "DPS > Tank > Healer", value = "DTH" },
        { text = "DPS > Healer > Tank", value = "DHT" },
    }
    local currentRoleText = "Tank > DPS > Healer"
    for _, item in ipairs(roleOrderItems) do
        if item.value == (VB.config.roleOrder or "TDH") then
            currentRoleText = item.text
            break
        end
    end
    
    local roleDropdown = CreateSimpleDropdown(content, 220, roleOrderItems, currentRoleText)
    roleDropdown:SetPoint("TOPLEFT", 240, yOffset - 18)
    local roleMenu = roleDropdown.menu
    for i = 1, select("#", roleMenu:GetChildren()) do
        local btn = select(i, roleMenu:GetChildren())
        local origOnClick = btn:GetScript("OnClick")
        btn:SetScript("OnClick", function(self)
            if origOnClick then origOnClick(self) end
            VB.config.roleOrder = roleDropdown.selectedValue
            if not InCombatLockdown() then VB:UpdateAllFrames() end
        end)
    end
    yOffset = yOffset - 50
    
    local tankFrameCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    tankFrameCB:SetPoint("TOPLEFT", 10, yOffset)
    tankFrameCB.text:SetText(VB.L["SHOW_TANK_FRAME"])
    tankFrameCB:SetChecked(VB.config.showTankFrame or false)
    tankFrameCB:SetScript("OnClick", function(self)
        VB.config.showTankFrame = self:GetChecked()
        if not InCombatLockdown() then VB:UpdateTankFrame() end
        if self:GetChecked() then
            if VB.groupType == "solo" then
                VB:Print(VB.L["TANK_FRAME_ENABLED_SOLO"])
            else
                VB:Print(VB.L["TANK_FRAME_ENABLED"])
            end
        else
            VB:Print(VB.L["TANK_FRAME_DISABLED"])
        end
    end)
    yOffset = yOffset - 30

    local petFrameCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    petFrameCB:SetPoint("TOPLEFT", 10, yOffset)
    petFrameCB.text:SetText(VB.L["SHOW_PET_FRAME"])
    petFrameCB:SetChecked(VB.config.showPetFrame or false)
    petFrameCB:SetScript("OnClick", function(self)
        VB.config.showPetFrame = self:GetChecked()
        if not InCombatLockdown() then VB:UpdatePetFrame() end
    end)
    yOffset = yOffset - 30

    local targetOptions = {}
    local function RefreshTargetOptions()
        for _, cb in ipairs(targetOptions) do
            cb:SetEnabled(VB.config.showTargetFrame == true)
            cb:SetAlpha(VB.config.showTargetFrame and 1 or 0.5)
            if cb.menu and not VB.config.showTargetFrame then
                cb.menu:Hide()
                cb.isOpen = false
            end
        end
    end
    local targetFrameCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    targetFrameCB:SetPoint("TOPLEFT", 10, yOffset)
    targetFrameCB.text:SetText(VB.L["SHOW_TARGET_FRAME"])
    targetFrameCB:SetChecked(VB.config.showTargetFrame or false)
    targetFrameCB:SetScript("OnClick", function(self)
        VB.config.showTargetFrame = self:GetChecked()
        RefreshTargetOptions()
        VB:UpdateTargetFrame()
    end)
    yOffset = yOffset - 30

    for _, option in ipairs({
        { key = "targetFrameShowTarget", label = "TARGET_FRAME", x = 30, width = 85 },
        { key = "targetFrameShowTargetTarget", label = "TARGET_OF_TARGET", x = 145, width = 160 },
        { key = "targetFrameShowFocus", label = "FOCUS_FRAME", x = 335, width = 85 },
    }) do
        local key = option.key
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", option.x, yOffset)
        cb.text:SetText(VB.L[option.label])
        cb.text:SetWidth(option.width)
        cb.text:SetJustifyH("LEFT")
        cb:SetChecked(VB.config[key] == true)
        targetOptions[#targetOptions + 1] = cb
        cb:SetScript("OnClick", function(self)
            VB.config[key] = self:GetChecked()
            VB:UpdateTargetFrame()
        end)
    end
    yOffset = yOffset - 30
    local targetOrientLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetOrientLabel:SetPoint("TOPLEFT", 30, yOffset - 6)
    targetOrientLabel:SetText(VB.L["ORIENTATION"])
    local targetOrientation = CreateSimpleDropdown(content, 170, {
        { text = VB.L["ORIENTATION_H"], value = "HORIZONTAL" },
        { text = VB.L["ORIENTATION_V"], value = "VERTICAL" },
    }, VB.config.targetFrameOrientation == "VERTICAL" and VB.L["ORIENTATION_V"] or VB.L["ORIENTATION_H"])
    targetOrientation:SetPoint("TOPLEFT", 160, yOffset)
    targetOrientation.selectedValue = VB.config.targetFrameOrientation or "HORIZONTAL"
    for _, item in ipairs({ targetOrientation.menu:GetChildren() }) do
        item:HookScript("OnClick", function()
            VB.config.targetFrameOrientation = targetOrientation.selectedValue
            VB:UpdateTargetFrame()
        end)
    end
    targetOptions[#targetOptions + 1] = targetOrientation
    yOffset = yOffset - 35
    RefreshTargetOptions()
    local targetHelp = CreateFrame("Button", nil, content)
    targetHelp:SetSize(22, 22)
    targetHelp:SetPoint("LEFT", targetOrientation, "RIGHT", 8, 0)
    local helpText = targetHelp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpText:SetPoint("CENTER")
    helpText:SetText("?")
    targetHelp:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(VB.L["TARGETS_FRAME"])
        GameTooltip:AddLine(VB.L["TARGET_FRAME_HELP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    targetHelp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local classColorsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    classColorsCB:SetPoint("TOPLEFT", 10, yOffset)
    classColorsCB.text:SetText(VB.L["CLASS_COLORS"])
    classColorsCB:SetChecked(VB.config.classColors)
    classColorsCB:SetScript("OnClick", function(self)
        VB.config.classColors = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do VB:UpdateHealthBar(button) end
        for _, button in pairs(VB.targetButtons) do VB:UpdateHealthBar(button) end
    end)
    yOffset = yOffset - 30

    -- Name / HP% text, side by side to spare a row in a full tab
    local showNameCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showNameCB:SetPoint("TOPLEFT", 10, yOffset)
    showNameCB.text:SetText(VB.L["SHOW_NAME"])
    showNameCB:SetChecked(VB.config.showName ~= false)
    showNameCB:SetScript("OnClick", function(self)
        VB.config.showName = self:GetChecked()
        VB:RefreshFrameTexts()
    end)

    local showHealthCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showHealthCB:SetPoint("TOPLEFT", 250, yOffset)
    showHealthCB.text:SetText(VB.L["SHOW_HEALTH"])
    showHealthCB:SetChecked(VB.config.showHealth ~= false)
    showHealthCB:SetScript("OnClick", function(self)
        VB.config.showHealth = self:GetChecked()
        VB:RefreshFrameTexts()
    end)
    yOffset = yOffset - 30
    
    local powerBarCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    powerBarCB:SetPoint("TOPLEFT", 10, yOffset)
    powerBarCB.text:SetText(VB.L["SHOW_POWER_BAR"])
    powerBarCB:SetChecked(VB.config.showPowerBar)
    powerBarCB:SetScript("OnClick", function(self)
        VB.config.showPowerBar = self:GetChecked()
        VB:Print(VB.L["RELOAD_REQUIRED"])
    end)
    -- Same checkbox + slider row pattern as the debuff icon size
    local powerHeightSlider = CreateSimpleSlider(content, VB.L["POWER_BAR_HEIGHT"], 2, 12, 1,
        VB.config.powerBarHeight or 4, function(value)
        VB.config.powerBarHeight = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    powerHeightSlider:SetPoint("TOPLEFT", 200, yOffset + 5)
    yOffset = yOffset - 45
    
    local minimapCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    minimapCB:SetPoint("TOPLEFT", 10, yOffset)
    minimapCB.text:SetText(VB.L["SHOW_MINIMAP_BUTTON"])
    minimapCB:SetChecked(VB:IsMinimapButtonShown())
    minimapCB:SetScript("OnClick", function(self)
        VB:SetMinimapButtonShown(self:GetChecked())
    end)
    yOffset = yOffset - 30
    
    local showDebuffsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showDebuffsCB:SetPoint("TOPLEFT", 10, yOffset)
    showDebuffsCB.text:SetText(VB.L["SHOW_DEBUFFS"])
    showDebuffsCB:SetChecked(VB.config.showDebuffs ~= false)
    showDebuffsCB:SetScript("OnClick", function(self)
        VB.config.showDebuffs = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.tankButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.petButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.targetButtons) do VB:UpdateAuras(button) end
    end)
    
    local debuffSizeSlider = CreateSimpleSlider(content, VB.L["DEBUFF_ICON_SIZE"], 6, 30, 1, VB.config.debuffIconSize or 18, function(value)
        VB.config.debuffIconSize = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    debuffSizeSlider:SetPoint("TOPLEFT", 200, yOffset + 5)
    yOffset = yOffset - 45
    
    local showBuffsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    showBuffsCB:SetPoint("TOPLEFT", 10, yOffset)
    showBuffsCB.text:SetText(VB.L["SHOW_BUFFS"])
    showBuffsCB:SetChecked(VB.config.showBuffs ~= false)
    showBuffsCB:SetScript("OnClick", function(self)
        VB.config.showBuffs = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.tankButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.petButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.targetButtons) do VB:UpdateAuras(button) end
    end)
    
    local buffSizeSlider = CreateSimpleSlider(content, VB.L["BUFF_ICON_SIZE"], 6, 30, 1, VB.config.buffIconSize or 12, function(value)
        VB.config.buffIconSize = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    buffSizeSlider:SetPoint("TOPLEFT", 200, yOffset + 5)
    yOffset = yOffset - 30
    
    local dispelCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    dispelCB:SetPoint("TOPLEFT", 10, yOffset)
    dispelCB.text:SetText(VB.L["SHOW_DISPEL_HIGHLIGHT"])
    dispelCB:SetChecked(VB.config.showDispelHighlight ~= false)
    dispelCB:SetScript("OnClick", function(self)
        VB.config.showDispelHighlight = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.tankButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.petButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.targetButtons) do VB:UpdateAuras(button) end
    end)

    local eatDrinkCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    eatDrinkCB:SetPoint("TOPLEFT", 250, yOffset)
    eatDrinkCB.text:SetText(VB.L["SHOW_EAT_DRINK"])
    eatDrinkCB:SetChecked(VB.config.showEatDrink ~= false)
    eatDrinkCB:SetScript("OnClick", function(self)
        VB.config.showEatDrink = self:GetChecked()
        for _, group in ipairs({ VB.unitButtons, VB.tankButtons, VB.petButtons, VB.targetButtons }) do
            for _, button in pairs(group) do VB:UpdateStatus(button) end
        end
    end)
    yOffset = yOffset - 30

    local tooltipBindingsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    tooltipBindingsCB:SetPoint("TOPLEFT", 10, yOffset)
    tooltipBindingsCB.text:SetText(VB.L["SHOW_TOOLTIP_BINDINGS"])
    tooltipBindingsCB:SetChecked(VB.config.showTooltipBindings ~= false)
    tooltipBindingsCB:SetScript("OnClick", function(self)
        VB.config.showTooltipBindings = self:GetChecked()
    end)
    yOffset = yOffset - 30

    local autoTargetCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    autoTargetCB:SetPoint("TOPLEFT", 10, yOffset)
    autoTargetCB.text:SetText(VB.L["AUTO_TARGET_ON_CAST"])
    autoTargetCB:SetChecked(VB.config.autoTargetOnCast or false)
    autoTargetCB:SetScript("OnClick", function(self)
        VB.config.autoTargetOnCast = self:GetChecked()
    end)
    yOffset = yOffset - 30

    local clickRezCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    clickRezCB:SetPoint("TOPLEFT", 10, yOffset)
    clickRezCB.text:SetText(VB.L["CLICK_TO_REZ"])
    clickRezCB:SetChecked(VB.config.clickToRez or false)
    clickRezCB:SetScript("OnClick", function(self)
        VB.config.clickToRez = self:GetChecked()
        VB:ApplyClickCastingsToAllFrames()
    end)
    yOffset = yOffset - 30

    local smoothCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    smoothCB:SetPoint("TOPLEFT", 10, yOffset)
    smoothCB.text:SetText(VB.L["SMOOTH_GROUP_UPDATES"])
    smoothCB:SetChecked(VB.config.smoothGroupUpdates ~= false)
    smoothCB:SetScript("OnClick", function(self)
        VB.config.smoothGroupUpdates = self:GetChecked()
    end)
    yOffset = yOffset - 30

    -- Only meaningful where secure snippets are dead (Forever): elsewhere the
    -- wheel is bound on hover and needs no opt-in.
    if not VB.hasSecureSnippets then
        local wheelCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        wheelCB:SetPoint("TOPLEFT", 10, yOffset)
        wheelCB.text:SetText(VB.L["WHEEL_FALLBACK"])
        wheelCB:SetChecked(VB.config.fallbackWheelBindings or false)
        wheelCB:SetScript("OnClick", function(self)
            if InCombatLockdown() then
                self:SetChecked(not self:GetChecked())
                VB:Print(VB.L["CANNOT_BIND_COMBAT"])
                return
            end
            VB.config.fallbackWheelBindings = self:GetChecked()
            VB:ApplyClickCastingsToAllFrames()
        end)
        yOffset = yOffset - 30
    end
    yOffset = yOffset - 10
    
    local lockBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
    lockBtn:SetSize(150, 25)
    lockBtn:SetPoint("TOPLEFT", 10, yOffset)
    lockBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local lockText = lockBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockText:SetPoint("CENTER")
    lockBtn.text = lockText
    
    local function UpdateLockButton()
        if VB.config.locked then
            lockBtn:SetBackdropColor(0.5, 0.2, 0.2, 1)
            lockBtn.text:SetText(VB.L["BTN_UNLOCK"])
        else
            lockBtn:SetBackdropColor(0.2, 0.2, 0.5, 1)
            lockBtn.text:SetText(VB.L["BTN_LOCK"])
        end
    end
    UpdateLockButton()
    
    lockBtn:SetScript("OnClick", function()
        VB.config.locked = not VB.config.locked
        if VB.frames.main then VB.frames.main:EnableMouse(not VB.config.locked) end
        if VB.frames.handle then VB.frames.handle:SetShown(not VB.config.locked) end
        VB:UpdateTargetFrame()
        UpdateLockButton()
    end)
    content:SetHeight(-yOffset + 45)
end

-------------------------------------------------
-- Debuffs Tab
-------------------------------------------------
function VB:CreateDebuffsTab()
    local content = CreateFrame("Frame", nil, configFrame.content)
    content:SetAllPoints()
    content:Hide()
    configFrame.debuffsContent = content

    local exhaustionCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    exhaustionCB:SetPoint("TOPLEFT", 5, -5)
    exhaustionCB.text:SetText(VB.L["HIDE_EXHAUSTION_DEBUFFS"])
    exhaustionCB:SetChecked(VB.config.hideExhaustionDebuffs ~= false)
    exhaustionCB:SetScript("OnClick", function(self)
        VB.config.hideExhaustionDebuffs = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.tankButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.petButtons) do VB:UpdateAuras(button) end
        for _, button in pairs(VB.targetButtons) do VB:UpdateAuras(button) end
    end)

    -- === Tracked buffs ===
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 5, -45)
    header:SetText(VB.L["CUSTOM_BUFFS_HEADER"])

    local help = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 5, -65)
    help:SetWidth(460)
    help:SetJustifyH("LEFT")
    help:SetText(VB.L["CUSTOM_BUFFS_HELP"])

    local dropZone = CreateFrame("Button", nil, content, "BackdropTemplate")
    dropZone:SetSize(460, 40)
    dropZone:SetPoint("TOPLEFT", 5, -100)
    dropZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropZone:SetBackdropColor(0.2, 0.2, 0.3, 1)
    dropZone:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dropText:SetPoint("CENTER")
    dropText:SetText("|cFFAAAAFF" .. VB.L["CUSTOM_BUFFS_DROP"] .. "|r")

    -- Drop, or click while holding a spell on the cursor
    local function acceptCursorSpell()
        local spellID = VB:GetCursorSpell()
        if spellID then
            VB:AddCustomBuff(spellID)
            ClearCursor()
        end
    end
    dropZone:SetScript("OnReceiveDrag", acceptCursorSpell)
    dropZone:SetScript("OnClick", acceptCursorSpell)

    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -150)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(440, 300)
    scrollFrame:SetScrollChild(scrollChild)
    content.buffScrollChild = scrollChild

    VB:RefreshCustomBuffsList()
end

-------------------------------------------------
-- Tracked buffs list
-------------------------------------------------
local customBuffSlots = {}

local function GetOrCreateCustomBuffSlot(index)
    if customBuffSlots[index] then return customBuffSlots[index] end

    local slot = CreateFrame("Frame", nil, configFrame.debuffsContent.buffScrollChild, "BackdropTemplate")
    slot:SetSize(440, 28)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slot:SetBackdropColor(0.15, 0.15, 0.15, 1)
    slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 6, 0)
    slot.icon = icon

    local nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 32, 0)
    nameText:SetWidth(360)
    nameText:SetJustifyH("LEFT")
    slot.nameText = nameText

    local deleteBtn = CreateFrame("Button", nil, slot)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", -5, 0)
    deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:GetHighlightTexture():SetVertexColor(1, 0, 0)
    deleteBtn:SetScript("OnClick", function()
        if slot.buffIndex then VB:RemoveCustomBuffAt(slot.buffIndex) end
    end)

    customBuffSlots[index] = slot
    return slot
end

function VB:RefreshCustomBuffsList()
    if not configFrame or not configFrame.debuffsContent
       or not configFrame.debuffsContent.buffScrollChild then return end
    local scrollChild = configFrame.debuffsContent.buffScrollChild

    for _, slot in ipairs(customBuffSlots) do slot:Hide() end

    local yOffset = 0
    for i, spellID in ipairs(VB.customBuffs or {}) do
        local slot = GetOrCreateCustomBuffSlot(i)
        slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        -- Name without rank: every rank of the spell is tracked
        slot.nameText:SetText("|cFF00FF00" .. (VB:GetSpellName(spellID)
            or VB.L["DISPLAY_UNKNOWN_SPELL"]) .. "|r")
        slot.icon:SetTexture(VB:GetSpellIcon(spellID))
        slot.buffIndex = i
        slot:Show()
        yOffset = yOffset + 30
    end
    scrollChild:SetHeight(math.max(300, yOffset + 20))
end

-------------------------------------------------
-- Auras Tab (icons / drawings on screen, see Auras.lua)
-------------------------------------------------
local auraSlots = {}
local selectedAura = nil   -- index in VB.screenAuras

local function SetDropdownValue(dropdown, items, value)
    for _, item in ipairs(items) do
        if item.value == value then
            dropdown.selectedValue = value
            dropdown.text:SetText(item.text)
            return
        end
    end
end

local function TextOf(items, value)
    for _, item in ipairs(items) do
        if item.value == value then return item.text end
    end
    return ""
end

local auraUnitItems, auraKindItems, auraDisplayItems, auraColorItems, auraSoundItems, auraShowItems
local auraSourceItems, auraTypeItems

local function BuildAuraItems()
    local L = VB.L
    auraShowItems = {
        { value = "present", text = L["AURA_SHOW_PRESENT"] },
        { value = "missing", text = L["AURA_SHOW_MISSING"] },
        { value = "expiring", text = L["AURA_SHOW_EXPIRING"] },
    }
    auraSourceItems = {
        { value = "spell", text = L["AURA_SOURCE_SPELL"] },
        { value = "type", text = L["AURA_SOURCE_TYPE"] },
        { value = "usable", text = L["AURA_SOURCE_USABLE"] },
    }
    auraTypeItems = {}
    for _, t in ipairs(VB.AURA_DISPEL_TYPES) do
        auraTypeItems[#auraTypeItems + 1] = { value = t, text = L["AURA_TYPE_" .. t:upper()] }
    end
    auraUnitItems = {
        { value = "player", text = L["AURA_UNIT_PLAYER"] },
        { value = "target", text = L["AURA_UNIT_TARGET"] },
    }
    auraKindItems = {
        { value = "HELPFUL", text = L["AURA_KIND_HELPFUL"] },
        { value = "HARMFUL", text = L["AURA_KIND_HARMFUL"] },
    }
    auraDisplayItems = {
        { value = "icon", text = L["AURA_DISPLAY_ICON"] },
        { value = "bar", text = L["AURA_DISPLAY_BAR"] },
        { value = "frame", text = L["AURA_DISPLAY_FRAME"] },
        { value = "disc", text = L["AURA_DISPLAY_DISC"] },
    }
    auraColorItems = {}
    for _, c in ipairs(VB.AURA_COLORS) do
        auraColorItems[#auraColorItems + 1] = { value = c.value, text = L["AURA_COLOR_" .. c.value:upper()] }
    end
    auraSoundItems = {}
    for _, snd in ipairs(VB.AURA_SOUNDS) do
        auraSoundItems[#auraSoundItems + 1] = { value = snd.value, text = L["AURA_SOUND_" .. snd.value:upper()] }
    end
end

local function AuraSummary(entry)
    local text = TextOf(auraUnitItems, entry.unit) .. " - " .. TextOf(auraKindItems, entry.kind)
        .. " - " .. TextOf(auraDisplayItems, entry.display)
    if entry.show ~= "present" then text = text .. " - " .. TextOf(auraShowItems, entry.show) end
    return text
end

local function LabelAbove(parent, frame, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 2)
    label:SetText(text)
    return label
end

function VB:CreateScreenAurasTab()
    local L = VB.L
    BuildAuraItems()

    local content = CreateFrame("Frame", nil, configFrame.content)
    content:SetAllPoints()
    content:Hide()
    configFrame.aurasContent = content

    local help = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 5, -5)
    help:SetWidth(460)
    help:SetJustifyH("LEFT")
    help:SetText(L["SCREEN_AURAS_HELP"])

    -- === Add by name, ID or drag ===
    local function AddSpell(spellID)
        if not spellID or not VB:GetSpellName(spellID) then
            VB:Print(L["SCREEN_AURA_UNKNOWN"])
            return
        end
        table.insert(VB.screenAuras, VB:NewScreenAura(spellID))
        selectedAura = #VB.screenAuras
        VB:RebuildScreenAuras()
        VB:RefreshScreenAurasTab()
    end

    -- Procs are states, not spells the player casts: the client cannot find
    -- them by name, so a few common ones are listed by ID (wowhead, Forever,
    -- 2026-10-02) and matched against their localized name.
    -- Same name across classes (Clearcasting), so the player's class goes first.
    local KNOWN_PROCS = {
        DRUID = { 16870 },            -- Clearcasting
        MAGE = { 12536 },             -- Clearcasting
        SHAMAN = { 16246 },           -- Clearcasting
        ROGUE = { 457342, 467735 },   -- Clearcasting
    }
    local function KnownProcIDs()
        local list = {}
        for _, id in ipairs(KNOWN_PROCS[VB.playerClass] or {}) do list[#list + 1] = id end
        for class, ids in pairs(KNOWN_PROCS) do
            if class ~= VB.playerClass then
                for _, id in ipairs(ids) do list[#list + 1] = id end
            end
        end
        return list
    end

    local function ResolveInput(text)
        local id = tonumber(text)
        if id then return id end
        local wanted = text:lower()
        local function same(name)
            return type(name) == "string" and name:lower() == wanted
        end

        -- 1. Spells the client knows (spellbook, cache)
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, text)
            if ok and type(info) == "table" and info.spellID then return info.spellID end
        end
        -- 2. Spellbook, ignoring case
        local found
        VB:ForEachKnownSpell(function(spellID, name)
            if not found and same(name or VB:GetSpellName(spellID)) then found = spellID end
        end)
        if found then return found end
        -- 3. Auras up right now on me or my target (readable out of combat)
        for _, unit in ipairs({ "player", "target" }) do
            for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
                for _, a in ipairs(VB:GetAuras(unit, filter)) do
                    local ok, match = pcall(function() return same(a.name) and a.spellId end)
                    if ok and match then return match end
                end
            end
        end
        -- 4. Known procs
        for _, spellID in ipairs(KnownProcIDs()) do
            if same(VB:GetSpellName(spellID)) then return spellID end
        end
        return nil
    end

    local input = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    input:SetSize(130, 22)
    input:SetPoint("TOPLEFT", 12, -62)
    input:SetAutoFocus(false)

    local addBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    addBtn:SetSize(70, 22)
    addBtn:SetPoint("LEFT", input, "RIGHT", 8, 0)
    addBtn:SetText(L["SCREEN_AURA_ADD"])

    local function SubmitInput()
        local text = strtrim(input:GetText() or "")
        input:SetText("")
        input:ClearFocus()
        if text ~= "" then AddSpell(ResolveInput(text)) end
    end
    addBtn:SetScript("OnClick", SubmitInput)
    input:SetScript("OnEnterPressed", SubmitInput)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local dropZone = CreateFrame("Button", nil, content, "BackdropTemplate")
    dropZone:SetSize(120, 22)
    dropZone:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    dropZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropZone:SetBackdropColor(0.2, 0.2, 0.3, 1)
    dropZone:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropText:SetPoint("CENTER")
    dropText:SetText("|cFFAAAAFF" .. L["CUSTOM_BUFFS_DROP"] .. "|r")
    local function AcceptCursorSpell()
        local spellID = VB:GetCursorSpell()
        if spellID then
            ClearCursor()
            AddSpell(spellID)
        end
    end
    dropZone:SetScript("OnReceiveDrag", AcceptCursorSpell)
    dropZone:SetScript("OnClick", AcceptCursorSpell)

    -- An aura by debuff type rather than by spell
    local typeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    typeBtn:SetSize(110, 22)
    typeBtn:SetPoint("LEFT", dropZone, "RIGHT", 8, 0)
    typeBtn:SetText(L["AURA_ADD_TYPE"])
    typeBtn:SetScript("OnClick", function()
        table.insert(VB.screenAuras, VB:NewScreenAura(nil))
        selectedAura = #VB.screenAuras
        VB:RebuildScreenAuras()
        VB:RefreshScreenAurasTab()
    end)

    -- === List ===
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -95)
    scrollFrame:SetSize(440, 180)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(440, 180)
    scrollFrame:SetScrollChild(scrollChild)
    content.auraScrollChild = scrollChild

    -- === Editor for the selected aura ===
    local editor = CreateFrame("Frame", nil, content)
    editor:SetPoint("TOPLEFT", 5, -290)
    editor:SetSize(470, 330)
    editor:Hide()
    content.editor = editor

    local header = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, 0)
    editor.header = header

    -- Apply a change to the selected entry. Rebuilds are debounced so a
    -- slider drag does not create a new set of frames on every step.
    local rebuildToken = 0
    local function Change(key, value)
        local entry = selectedAura and VB.screenAuras[selectedAura]
        if not entry or editor.loading then return end
        entry[key] = value
        rebuildToken = rebuildToken + 1
        local token = rebuildToken
        C_Timer.After(0.3, function()
            if token ~= rebuildToken then return end
            VB:RebuildScreenAuras()
            VB:RefreshScreenAurasTab()
        end)
    end

    local unitDD = CreateSimpleDropdown(editor, 140, auraUnitItems, "", function(v) Change("unit", v) end)
    unitDD:SetPoint("TOPLEFT", 0, -40)
    LabelAbove(editor, unitDD, L["AURA_UNIT"])
    editor.unitDD = unitDD

    local kindDD = CreateSimpleDropdown(editor, 140, auraKindItems, "", function(v) Change("kind", v) end)
    kindDD:SetPoint("TOPLEFT", 155, -40)
    LabelAbove(editor, kindDD, L["AURA_KIND"])
    editor.kindDD = kindDD

    local mineCB = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    mineCB:SetPoint("TOPLEFT", 310, -38)
    mineCB.text:SetText(L["AURA_MINE"])
    mineCB:SetScript("OnClick", function(self) Change("mine", self:GetChecked() and true or false) end)
    editor.mineCB = mineCB

    local displayDD = CreateSimpleDropdown(editor, 140, auraDisplayItems, "", function(v) Change("display", v) end)
    displayDD:SetPoint("TOPLEFT", 0, -95)
    LabelAbove(editor, displayDD, L["AURA_DISPLAY"])
    editor.displayDD = displayDD

    local colorDD = CreateSimpleDropdown(editor, 140, auraColorItems, "", function(v) Change("color", v) end)
    colorDD:SetPoint("TOPLEFT", 155, -95)
    LabelAbove(editor, colorDD, L["AURA_COLOR"])
    editor.colorDD = colorDD

    local soundDD = CreateSimpleDropdown(editor, 150, auraSoundItems, "", function(v)
        -- Play it once so the player hears what was picked
        for _, snd in ipairs(VB.AURA_SOUNDS) do
            if snd.value == v and snd.file then pcall(PlaySoundFile, snd.file, "Master") end
        end
        Change("sound", v)
    end)
    soundDD:SetPoint("TOPLEFT", 310, -95)
    LabelAbove(editor, soundDD, L["AURA_SOUND"])
    editor.soundDD = soundDD

    local showDD = CreateSimpleDropdown(editor, 140, auraShowItems, "", function(v) Change("show", v) end)
    showDD:SetPoint("TOPLEFT", 0, -150)
    LabelAbove(editor, showDD, L["AURA_SHOW"])
    editor.showDD = showDD

    local glowCB = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    glowCB:SetPoint("TOPLEFT", 155, -148)
    glowCB.text:SetText(L["AURA_GLOW"])
    glowCB:SetScript("OnClick", function(self) Change("glow", self:GetChecked() and true or false) end)
    editor.glowCB = glowCB

    local enabledCB = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    enabledCB:SetPoint("TOPLEFT", 310, -148)
    enabledCB.text:SetText(L["AURA_ENABLED"])
    enabledCB:SetScript("OnClick", function(self) Change("enabled", self:GetChecked() and true or false) end)
    editor.enabledCB = enabledCB

    local sourceDD = CreateSimpleDropdown(editor, 140, auraSourceItems, "", function(v) Change("source", v) end)
    sourceDD:SetPoint("TOPLEFT", 0, -205)
    LabelAbove(editor, sourceDD, L["AURA_SOURCE"])
    editor.sourceDD = sourceDD

    local typeDD = CreateSimpleDropdown(editor, 140, auraTypeItems, "", function(v) Change("dispelType", v) end)
    typeDD:SetPoint("TOPLEFT", 155, -205)
    editor.typeLabel = LabelAbove(editor, typeDD, L["AURA_DISPEL_TYPE"])
    editor.typeDD = typeDD

    -- Form condition, same place as the debuff type (a type never needs it).
    -- Only for classes with forms or stances.
    local formItems = { { value = 0, text = L["AURA_FORM_ANY"] } }
    for _, form in ipairs(VB:GetPlayerForms()) do
        formItems[#formItems + 1] = { value = form.spellID, text = form.name }
    end
    editor.formItems = formItems
    if #formItems > 1 then
        local formDD = CreateSimpleDropdown(editor, 140, formItems, "", function(v)
            Change("form", v ~= 0 and v or nil)
        end)
        formDD:SetPoint("TOPLEFT", 155, -205)
        editor.formLabel = LabelAbove(editor, formDD, L["AURA_FORM"])
        editor.formDD = formDD
    end

    local countdownCB = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    countdownCB:SetPoint("TOPLEFT", 310, -203)
    countdownCB.text:SetText(L["AURA_COUNTDOWN"])
    countdownCB:SetScript("OnClick", function(self) Change("countdown", self:GetChecked() and true or false) end)
    editor.countdownCB = countdownCB

    local sizeSlider = CreateSimpleSlider(editor, L["AURA_SIZE"], 16, 400, 4, 48, function(v) Change("size", v) end)
    sizeSlider:SetPoint("TOPLEFT", 0, -240)
    editor.sizeSlider = sizeSlider

    local expireSlider = CreateSimpleSlider(editor, L["AURA_EXPIRE"], 1, 60, 1, 5, function(v) Change("expire", v) end)
    expireSlider:SetPoint("TOPLEFT", 250, -240)
    editor.expireSlider = expireSlider

    local stacksCB = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate")
    stacksCB:SetPoint("TOPLEFT", 0, -283)
    stacksCB.text:SetText(L["AURA_STACKS"])
    stacksCB:SetScript("OnClick", function(self) Change("stacks", self:GetChecked() and true or false) end)
    editor.stacksCB = stacksCB

    local note = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 0, -315)
    note:SetWidth(460)
    note:SetJustifyH("LEFT")
    note:SetText(L["AURA_SOUND_NOTE"])

    VB:RefreshScreenAurasTab()
end

local function GetOrCreateAuraSlot(index)
    if auraSlots[index] then return auraSlots[index] end

    local slot = CreateFrame("Button", nil, configFrame.aurasContent.auraScrollChild, "BackdropTemplate")
    slot:SetSize(440, 28)
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 6, 0)
    slot.icon = icon

    local nameText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", 32, 0)
    nameText:SetWidth(380)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    slot.nameText = nameText

    slot:SetScript("OnClick", function(self)
        selectedAura = self.auraIndex
        VB:RefreshScreenAurasTab()
    end)

    local deleteBtn = CreateFrame("Button", nil, slot)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", -5, 0)
    deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:GetHighlightTexture():SetVertexColor(1, 0, 0)
    deleteBtn:SetScript("OnClick", function()
        if not slot.auraIndex then return end
        table.remove(VB.screenAuras, slot.auraIndex)
        selectedAura = nil
        VB:RebuildScreenAuras()
        VB:RefreshScreenAurasTab()
    end)

    auraSlots[index] = slot
    return slot
end

function VB:RefreshScreenAurasTab()
    if not configFrame or not configFrame.aurasContent then return end
    local content = configFrame.aurasContent
    local scrollChild = content.auraScrollChild

    for _, slot in ipairs(auraSlots) do slot:Hide() end
    if selectedAura and not VB.screenAuras[selectedAura] then selectedAura = nil end

    local yOffset = 0
    for i, entry in ipairs(VB.screenAuras or {}) do
        local slot = GetOrCreateAuraSlot(i)
        slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        slot.auraIndex = i
        slot.icon:SetTexture(VB:ScreenAuraIcon(entry))
        local name = VB:ScreenAuraName(entry)
        local color = entry.enabled == false and "|cFF888888" or "|cFF00FF00"
        slot.nameText:SetText(color .. name .. "|r  |cFFAAAAAA" .. AuraSummary(entry) .. "|r")
        if i == selectedAura then
            slot:SetBackdropColor(0.25, 0.25, 0.4, 1)
            slot:SetBackdropBorderColor(0.6, 0.6, 1, 1)
        else
            slot:SetBackdropColor(0.15, 0.15, 0.15, 1)
            slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        slot:Show()
        yOffset = yOffset + 30
    end
    scrollChild:SetHeight(math.max(180, yOffset + 10))

    local editor = content.editor
    local entry = selectedAura and VB.screenAuras[selectedAura]
    if not entry then
        editor:Hide()
        return
    end
    editor.loading = true
    editor.header:SetText(VB.L["SCREEN_AURA_SETTINGS"]:format(VB:ScreenAuraName(entry) or "?"))
    SetDropdownValue(editor.unitDD, auraUnitItems, entry.unit)
    SetDropdownValue(editor.kindDD, auraKindItems, entry.kind)
    SetDropdownValue(editor.displayDD, auraDisplayItems, entry.display)
    SetDropdownValue(editor.colorDD, auraColorItems, entry.color)
    SetDropdownValue(editor.soundDD, auraSoundItems, entry.sound)
    SetDropdownValue(editor.showDD, auraShowItems, entry.show or "present")
    editor.glowCB:SetChecked(entry.glow)
    editor.mineCB:SetChecked(entry.mine)
    editor.enabledCB:SetChecked(entry.enabled ~= false)
    editor.sizeSlider.slider:SetValue(entry.size or 48)
    editor.expireSlider.slider:SetValue(entry.expire or 5)
    editor.expireSlider:SetShown(entry.show == "expiring")
    editor.countdownCB:SetChecked(entry.countdown)
    editor.stacksCB:SetChecked(entry.stacks ~= false)
    -- Spell or debuff type. A spell-less entry (added as a type) stays a type.
    local isType = entry.source == "type"
    local isUsable = entry.source == "usable"
    SetDropdownValue(editor.sourceDD, auraSourceItems, entry.source or "spell")
    editor.sourceDD:SetEnabled(entry.spellID ~= nil)
    SetDropdownValue(editor.typeDD, auraTypeItems, entry.dispelType or "any")
    editor.typeDD:SetShown(isType)
    editor.typeLabel:SetShown(isType)
    if editor.formDD then
        SetDropdownValue(editor.formDD, editor.formItems, entry.form or 0)
        editor.formDD:SetShown(not isType)
        editor.formLabel:SetShown(not isType)
    end
    -- A type is always a debuff, and has no spell to watch for "own only"
    editor.kindDD:SetEnabled(not isType and not isUsable)
    editor.mineCB:SetEnabled(not isType and not isUsable)
    -- "Spell usable" is about the player only
    editor.unitDD:SetEnabled(not isUsable)
    editor.loading = false
    editor:Show()
end

-------------------------------------------------
-- Profiles Tab
-------------------------------------------------
function VB:CreateProfilesTab()
    local content = CreateFrame("Frame", nil, configFrame.content)
    content:SetAllPoints()
    content:Hide()
    configFrame.profilesContent = content
    
    local yOffset = -10
    
    local activeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", 10, yOffset)
    activeLabel:SetText(VB.L["ACTIVE_PROFILE"] .. ":")
    content.activeLabel = activeLabel
    
    local activeName = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeName:SetPoint("LEFT", activeLabel, "RIGHT", 8, 0)
    activeName:SetText(VB:ColoredProfileName(VB:GetActiveProfileName()))
    content.activeName = activeName
    yOffset = yOffset - 35
    
    local listLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 10, yOffset)
    listLabel:SetText(VB.L["PROFILES"] .. ":")
    yOffset = yOffset - 20
    
    local listFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 10, yOffset)
    listFrame:SetSize(300, 200)
    listFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(0.12, 0.12, 0.12, 1)
    listFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    content.listFrame = listFrame
    content.profileButtons = {}
    yOffset = yOffset - 210
    
    local btnWidth = 90
    local btnSpacing = 5
    local btnY = yOffset - 5
    
    local function MakeProfileBtn(text, xOff, onClick)
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(btnWidth, 25)
        btn:SetPoint("TOPLEFT", 10 + xOff, btnY)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.2, 0.2, 0.4, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.6, 1)
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("CENTER")
        t:SetText(text)
        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.5, 1) end)
        btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.4, 1) end)
        return btn
    end
    
    MakeProfileBtn(VB.L["PROFILE_NEW"], 0, function() VB:ShowProfileNameDialog("new") end)
    MakeProfileBtn(VB.L["PROFILE_COPY"], btnWidth + btnSpacing, function() VB:ShowProfileNameDialog("copy") end)
    
    local deleteBtn = MakeProfileBtn(VB.L["PROFILE_DELETE"], (btnWidth + btnSpacing) * 2, function()
        if content.selectedProfile and content.selectedProfile ~= "Default" then
            VB:DeleteProfile(content.selectedProfile)
            content.selectedProfile = nil
            VB:RefreshProfilesTab()
        else
            VB:Print(VB.L["PROFILE_CANNOT_DELETE_DEFAULT"])
        end
    end)
    deleteBtn:SetBackdropColor(0.4, 0.15, 0.15, 1)
    deleteBtn:SetBackdropBorderColor(0.6, 0.3, 0.3, 1)
    deleteBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.5, 0.2, 0.2, 1) end)
    deleteBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.4, 0.15, 0.15, 1) end)

    -- Reset the selected (or active) profile to the defaults, after a confirmation
    StaticPopupDialogs["VOIDBOX_RESET_PROFILE"] = {
        text = VB.L["PROFILE_RESET_CONFIRM"],
        button1 = YES,
        button2 = NO,
        OnAccept = function(_, name)
            if VB:ResetProfile(name) then
                VB:Print(VB.L["PROFILE_RESET_DONE"]:format(name))
                VB:RefreshProfilesTab()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    MakeProfileBtn(VB.L["PROFILE_RESET"], (btnWidth + btnSpacing) * 3, function()
        local name = content.selectedProfile or VB:GetActiveProfileName()
        local dialog = StaticPopup_Show("VOIDBOX_RESET_PROFILE", name)
        if dialog then dialog.data = name end
    end)

    -- Share the configuration as text (Share.lua)
    btnY = btnY - 35
    MakeProfileBtn(VB.L["PROFILE_RENAME"], 0, function()
        local name = content.selectedProfile or VB:GetActiveProfileName()
        if name == "Default" then
            VB:Print(VB.L["PROFILE_CANNOT_RENAME_DEFAULT"])
            return
        end
        VB:ShowProfileNameDialog("rename", name)
    end)
    MakeProfileBtn(VB.L["SHARE_EXPORT"], btnWidth + btnSpacing, function() VB:ShowExportDialog() end)
    MakeProfileBtn(VB.L["SHARE_IMPORT"], (btnWidth + btnSpacing) * 2, function() VB:ShowImportDialog() end)

    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 10, btnY - 35)
    note:SetWidth(440)
    note:SetJustifyH("LEFT")
    note:SetText(VB.L["PROFILE_PER_CHARACTER_NOTE"])

    content.selectedProfile = nil
end

function VB:RefreshProfilesTab()
    if not configFrame or not configFrame.profilesContent then return end
    local content = configFrame.profilesContent
    content.activeName:SetText(VB:ColoredProfileName(VB:GetActiveProfileName()))
    
    for _, btn in ipairs(content.profileButtons) do btn:Hide() end
    
    local profiles = VB:GetProfileList()
    local activeName = VB:GetActiveProfileName()
    
    for i, name in ipairs(profiles) do
        local btn = content.profileButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content.listFrame, "BackdropTemplate")
            btn:SetSize(296, 24)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t:SetPoint("LEFT", 8, 0)
            btn.text = t
            local activeTag = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            activeTag:SetPoint("RIGHT", -8, 0)
            btn.activeTag = activeTag
            content.profileButtons[i] = btn
        end
        
        btn:SetPoint("TOPLEFT", 2, -(i-1) * 26 - 2)
        btn.profileName = name
        btn.text:SetText(VB:ColoredProfileName(name))
        
        local isActive = (name == activeName)
        local isSelected = (name == content.selectedProfile)
        btn.activeTag:SetText(isActive and ("|cFF00FF00" .. VB.L["PROFILE_ACTIVE"] .. "|r") or "")
        
        if isSelected then btn:SetBackdropColor(0.3, 0.3, 0.5, 1)
        elseif isActive then btn:SetBackdropColor(0.2, 0.2, 0.3, 1)
        else btn:SetBackdropColor(0.15, 0.15, 0.15, 1) end
        
        btn:SetScript("OnClick", function(self)
            content.selectedProfile = self.profileName
            VB:RefreshProfilesTab()
        end)
        btn:SetScript("OnDoubleClick", function(self)
            VB:SwitchProfile(self.profileName)
            VB:RefreshProfilesTab()
        end)
        btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.25, 0.25, 0.35, 1) end)
        btn:SetScript("OnLeave", function(self)
            local sel = (self.profileName == content.selectedProfile)
            local act = (self.profileName == VB:GetActiveProfileName())
            if sel then self:SetBackdropColor(0.3, 0.3, 0.5, 1)
            elseif act then self:SetBackdropColor(0.2, 0.2, 0.3, 1)
            else self:SetBackdropColor(0.15, 0.15, 0.15, 1) end
        end)
        btn:Show()
    end
end

-------------------------------------------------
-- Profile Name Input Dialog
-------------------------------------------------
local profileDialog = nil

function VB:ShowProfileNameDialog(mode, renaming)
    if not profileDialog then
        profileDialog = CreateFrame("Frame", "VoidBoxProfileDialog", UIParent, "BackdropTemplate")
        profileDialog:SetSize(280, 120)
        profileDialog:SetPoint("CENTER")
        profileDialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        profileDialog:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
        profileDialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        profileDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        profileDialog:SetMovable(true)
        profileDialog:EnableMouse(true)
        profileDialog:RegisterForDrag("LeftButton")
        profileDialog:SetScript("OnDragStart", profileDialog.StartMoving)
        profileDialog:SetScript("OnDragStop", profileDialog.StopMovingOrSizing)
        profileDialog:Hide()
        
        local title = profileDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        profileDialog.title = title
        
        local closeBtn = CreateFrame("Button", nil, profileDialog, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -5, -5)
        
        local editBox = CreateFrame("EditBox", nil, profileDialog, "BackdropTemplate")
        editBox:SetSize(240, 25)
        editBox:SetPoint("CENTER", 0, 0)
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(0.15, 0.15, 0.15, 1)
        editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        editBox:SetFontObject(GameFontNormal)
        editBox:SetAutoFocus(true)
        editBox:SetMaxLetters(30)
        editBox:SetTextInsets(6, 6, 0, 0)
        profileDialog.editBox = editBox
        
        local okBtn = CreateFrame("Button", nil, profileDialog, "BackdropTemplate")
        okBtn:SetSize(80, 25)
        okBtn:SetPoint("BOTTOM", 0, 10)
        okBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        okBtn:SetBackdropColor(0.2, 0.2, 0.5, 1)
        okBtn:SetBackdropBorderColor(0.4, 0.4, 0.7, 1)
        local okText = okBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        okText:SetPoint("CENTER")
        okText:SetText(VB.L["CONFIRM"])
        profileDialog.okBtn = okBtn
        
        editBox:SetScript("OnEnterPressed", function() okBtn:Click() end)
        editBox:SetScript("OnEscapePressed", function() profileDialog:Hide() end)
        
        tinsert(UISpecialFrames, "VoidBoxProfileDialog")
    end
    
    profileDialog.mode = mode
    -- New and copied profiles are named after the character by default
    profileDialog.renaming = renaming
    profileDialog.editBox:SetText(mode == "rename" and renaming or VB:SuggestProfileName())
    profileDialog.editBox:HighlightText()
    profileDialog.title:SetText(mode == "new" and VB.L["PROFILE_NEW"]
        or mode == "rename" and VB.L["PROFILE_RENAME"] or VB.L["PROFILE_COPY"])
    
    profileDialog.okBtn:SetScript("OnClick", function()
        local name = profileDialog.editBox:GetText():trim()
        if name == "" then return end
        if VoidBoxDB.profiles[name] then
            VB:Print(VB.L["PROFILE_EXISTS"])
            return
        end
        if profileDialog.mode == "new" then
            VB:CreateProfile(name)
        elseif profileDialog.mode == "rename" then
            VB:RenameProfile(profileDialog.renaming, name)
            if configFrame.profilesContent.selectedProfile == profileDialog.renaming then
                configFrame.profilesContent.selectedProfile = name
            end
        elseif profileDialog.mode == "copy" then
            local src = configFrame.profilesContent.selectedProfile or VB:GetActiveProfileName()
            VB:CopyProfile(src, name)
        end
        profileDialog:Hide()
        VB:RefreshProfilesTab()
    end)
    
    profileDialog:Show()
    profileDialog.editBox:SetFocus()
end
