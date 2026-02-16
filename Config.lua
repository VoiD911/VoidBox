--[[
    VoidBox - Configuration UI
    Interface de configuration avec drag & drop depuis le grimoire
    Compatible 12.0+ : pas de UIDropDownMenu, pas de OptionsSliderTemplate
]]

local addonName, VB = ...

local configFrame = nil
local bindingSlots = {}

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
    configFrame:SetSize(500, 600)
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
    
    -- Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cFF9966FFVoidBox|r - " .. VB.L["CONFIG_TITLE"])
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Tab buttons
    VB:CreateConfigTabs()
    
    -- Content area
    local content = CreateFrame("Frame", nil, configFrame)
    content:SetPoint("TOPLEFT", 10, -70)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    configFrame.content = content
    
    -- Create tab contents
    VB:CreateBindingsTab()
    VB:CreateAppearanceTab()
    VB:CreateProfilesTab()
    
    -- Show bindings tab by default
    VB:ShowConfigTab("bindings")
    
    tinsert(UISpecialFrames, "VoidBoxConfig")
end

-------------------------------------------------
-- Config Tabs
-------------------------------------------------
local tabs = {}

function VB:CreateConfigTabs()
    local tabData = {
        { id = "bindings", text = VB.L["TAB_BINDINGS"] },
        { id = "appearance", text = VB.L["TAB_APPEARANCE"] },
        { id = "profiles", text = VB.L["TAB_PROFILES"] },
    }
    
    local lastTab = nil
    for i, data in ipairs(tabData) do
        local tab = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
        tab:SetSize(120, 25)
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
        tab:SetScript("OnClick", function()
            VB:ShowConfigTab(data.id)
        end)
        
        tab:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
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
        if id == tabId then
            tab.selected = true
            tab:SetBackdropColor(0.3, 0.3, 0.5, 1)
        else
            tab.selected = false
            tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
        end
    end
    
    if configFrame.bindingsContent then
        configFrame.bindingsContent:SetShown(tabId == "bindings")
    end
    if configFrame.appearanceContent then
        configFrame.appearanceContent:SetShown(tabId == "appearance")
    end
    if configFrame.profilesContent then
        configFrame.profilesContent:SetShown(tabId == "profiles")
        if tabId == "profiles" then
            VB:RefreshProfilesTab()
        end
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
    instructions:SetText("|cFFFFFF00Instructions:|r " .. VB.L["INSTRUCTIONS"])
    
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 5, -30)
    header:SetText(VB.L["HEADER_COMBO"] .. "          " .. VB.L["HEADER_ACTION"])
    
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
    
    for _, slot in ipairs(bindingSlots) do
        slot:Hide()
    end
    
    local yOffset = 0
    for i, binding in ipairs(VB.clickCastings) do
        local slot = VB:GetOrCreateBindingSlot(i)
        slot:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        
        slot.keyText:SetText(VB:GetBindingDisplayText(binding[1]))
        slot.actionText:SetText(VB:GetActionDisplayText(binding[2], binding[3], binding[4]))
        slot.bindingIndex = i
        
        slot:Show()
        yOffset = yOffset + 30
    end
    
    scrollChild:SetHeight(math.max(400, yOffset + 50))
end

function VB:GetOrCreateBindingSlot(index)
    if bindingSlots[index] then
        return bindingSlots[index]
    end
    
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
    keyText:SetWidth(120)
    keyText:SetJustifyH("LEFT")
    slot.keyText = keyText
    
    local actionText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionText:SetPoint("LEFT", 140, 0)
    actionText:SetWidth(220)
    actionText:SetJustifyH("LEFT")
    slot.actionText = actionText
    
    local deleteBtn = CreateFrame("Button", nil, slot)
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", -5, 0)
    deleteBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    deleteBtn:GetHighlightTexture():SetVertexColor(1, 0, 0)
    deleteBtn:SetScript("OnClick", function()
        if slot.bindingIndex then
            local binding = VB.clickCastings[slot.bindingIndex]
            if binding then
                VB:RemoveClickCasting(binding[1])
                VB:RefreshBindingsList()
            end
        end
    end)
    
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnReceiveDrag", function(self)
        if not self.bindingIndex then return end
        local binding = VB.clickCastings[self.bindingIndex]
        if not binding then return end
        
        -- Try spell first
        local spellID, spellName = VB:GetCursorSpell()
        if spellID then
            binding[2] = "spell"
            binding[3] = spellID
            VB:ApplyClickCastingsToAllFrames()
            VB:RefreshBindingsList()
            ClearCursor()
            return
        end
        
        -- Try macro
        local macroName, macroIcon, macroBody = VB:GetCursorMacro()
        if macroName and macroBody then
            binding[2] = "macro"
            binding[3] = macroBody
            binding[4] = macroName  -- store name for display
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

-------------------------------------------------
-- Add Binding Dialog
-------------------------------------------------
local addDialog = nil

function VB:ShowAddBindingDialog()
    if InCombatLockdown() then
        VB:Print(VB.L["CANNOT_BIND_COMBAT"])
        return
    end
    if not addDialog then VB:CreateAddBindingDialog() end
    addDialog:Show()
end

-- Simple custom dropdown (no UIDropDownMenu taint issues)
local function CreateSimpleDropdown(parent, width, items, defaultText)
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
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdrop(nil)
        end)
    end
    
    dropdown:SetScript("OnClick", function()
        dropdown.isOpen = not dropdown.isOpen
        menu:SetShown(dropdown.isOpen)
    end)
    dropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    dropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.15, 1) end)
    
    return dropdown
end

-- Simple custom slider (compatible 12.0+)
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

function VB:CreateAddBindingDialog()
    addDialog = CreateFrame("Frame", "VoidBoxAddBinding", UIParent, "BackdropTemplate")
    addDialog:SetSize(300, 300)
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
    
    local modLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modLabel:SetPoint("TOPLEFT", 15, -40)
    modLabel:SetText(VB.L["MODIFIERS"])
    
    local shiftCB = CreateFrame("CheckButton", nil, addDialog, "UICheckButtonTemplate")
    shiftCB:SetPoint("TOPLEFT", 15, -60)
    shiftCB.text:SetText("Shift")
    addDialog.shiftCB = shiftCB
    
    local ctrlCB = CreateFrame("CheckButton", nil, addDialog, "UICheckButtonTemplate")
    ctrlCB:SetPoint("LEFT", shiftCB, "RIGHT", 50, 0)
    ctrlCB.text:SetText("Ctrl")
    addDialog.ctrlCB = ctrlCB
    
    local altCB = CreateFrame("CheckButton", nil, addDialog, "UICheckButtonTemplate")
    altCB:SetPoint("LEFT", ctrlCB, "RIGHT", 50, 0)
    altCB.text:SetText("Alt")
    addDialog.altCB = altCB
    
    local mouseLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mouseLabel:SetPoint("TOPLEFT", 15, -95)
    mouseLabel:SetText(VB.L["MOUSE_BUTTON"])
    
    local mouseDropdown = CreateSimpleDropdown(addDialog, 180, {
        { text = VB.L["BTN_LEFT"], value = "Left" },
        { text = VB.L["BTN_RIGHT"], value = "Right" },
        { text = VB.L["BTN_MIDDLE"], value = "Middle" },
        { text = VB.L["BTN_4"], value = "Button4" },
        { text = VB.L["BTN_5"], value = "Button5" },
        { text = VB.L["BTN_SCROLLUP"], value = "ScrollUp" },
        { text = VB.L["BTN_SCROLLDOWN"], value = "ScrollDown" },
    }, VB.L["BTN_LEFT"])
    mouseDropdown:SetPoint("TOPLEFT", 15, -112)
    addDialog.mouseDropdown = mouseDropdown
    
    -- Action type selector
    local actionLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionLabel:SetPoint("TOPLEFT", 15, -145)
    actionLabel:SetText(VB.L["ACTION_TYPE"])
    
    local actionDropdown = CreateSimpleDropdown(addDialog, 180, {
        { text = VB.L["ACTION_SPELL"], value = "spell" },
        { text = VB.L["ACTION_MACRO"], value = "macro" },
        { text = VB.L["ACTION_TARGET"], value = "target" },
        { text = VB.L["ACTION_FOCUS"], value = "focus" },
        { text = VB.L["ACTION_MENU"], value = "togglemenu" },
        { text = VB.L["ACTION_ASSIST"], value = "assist" },
    }, VB.L["ACTION_SPELL"])
    actionDropdown:SetPoint("TOPLEFT", 15, -162)
    addDialog.actionDropdown = actionDropdown
    
    -- Drop zone for spells (only visible when action = spell)
    local dropZone = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    dropZone:SetSize(260, 50)
    dropZone:SetPoint("TOP", 0, -200)
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
        -- Try spell first
        local spellID, spellName, spellIcon = VB:GetCursorSpell()
        if spellID and spellName then
            addDialog.selectedSpell = spellID
            addDialog.selectedMacro = nil
            addDialog.actionDropdown.selectedValue = "spell"
            addDialog.actionDropdown.text:SetText(VB.L["ACTION_SPELL"])
            local iconStr = spellIcon and ("|T" .. spellIcon .. ":20|t ") or ""
            dropText:SetText(iconStr .. spellName)
            ClearCursor()
            return
        end
        
        -- Try macro
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
    
    local confirmBtn = CreateFrame("Button", nil, addDialog, "BackdropTemplate")
    confirmBtn:SetSize(100, 25)
    confirmBtn:SetPoint("BOTTOM", 0, 10)
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

function VB:ConfirmAddBinding()
    local actionType = addDialog.actionDropdown.selectedValue or "spell"
    
    if actionType == "spell" and not addDialog.selectedSpell then
        VB:Print(VB.L["DRAG_SPELL_FIRST"])
        return
    end
    
    if actionType == "macro" and not addDialog.selectedMacro then
        VB:Print(VB.L["DRAG_MACRO_FIRST"])
        return
    end
    
    local parts = {}
    if addDialog.shiftCB:GetChecked() then table.insert(parts, "shift") end
    if addDialog.ctrlCB:GetChecked() then table.insert(parts, "ctrl") end
    if addDialog.altCB:GetChecked() then table.insert(parts, "alt") end
    local modifier = table.concat(parts, "-")
    
    local mouseButton = addDialog.mouseDropdown.selectedValue or "Left"
    
    local actionValue = nil
    local macroName = nil
    if actionType == "spell" then
        actionValue = addDialog.selectedSpell
    elseif actionType == "macro" then
        actionValue = addDialog.selectedMacro.body
        macroName = addDialog.selectedMacro.name
    end
    
    if VB:AddClickCasting(modifier, mouseButton, actionType, actionValue, macroName) then
        VB:RefreshBindingsList()
        addDialog:Hide()
        
        addDialog.shiftCB:SetChecked(false)
        addDialog.ctrlCB:SetChecked(false)
        addDialog.altCB:SetChecked(false)
        addDialog.selectedSpell = nil
        addDialog.selectedMacro = nil
        addDialog.dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_MACRO"] .. "|r")
        addDialog.actionDropdown.selectedValue = "spell"
        addDialog.actionDropdown.text:SetText(VB.L["ACTION_SPELL"])
    end
end

-------------------------------------------------
-- Appearance Tab (using custom sliders)
-------------------------------------------------
function VB:CreateAppearanceTab()
    local content = CreateFrame("Frame", nil, configFrame.content)
    content:SetAllPoints()
    content:Hide()
    configFrame.appearanceContent = content
    
    local yOffset = -10
    
    local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 10, yOffset)
    sizeLabel:SetText(VB.L["FRAME_SIZE"])
    yOffset = yOffset - 20
    
    local widthSlider = CreateSimpleSlider(content, VB.L["WIDTH"], 40, 150, 5, VB.config.frameWidth, function(value)
        VB.config.frameWidth = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    widthSlider:SetPoint("TOPLEFT", 10, yOffset)
    yOffset = yOffset - 50
    
    local heightSlider = CreateSimpleSlider(content, VB.L["HEIGHT"], 45, 80, 5, VB.config.frameHeight, function(value)
        VB.config.frameHeight = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    heightSlider:SetPoint("TOPLEFT", 10, yOffset)
    yOffset = yOffset - 55
    
    -- Group size slider
    local groupSlider = CreateSimpleSlider(content, VB.L["GROUP_SIZE"], 1, 10, 1, VB.config.maxColumns or 5, function(value)
        VB.config.maxColumns = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    groupSlider:SetPoint("TOPLEFT", 10, yOffset)
    yOffset = yOffset - 55
    
    -- Orientation dropdown (Horizontal / Vertical)
    local orientLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    orientLabel:SetPoint("TOPLEFT", 10, yOffset)
    orientLabel:SetText(VB.L["ORIENTATION"])
    
    local orientDropdown = CreateSimpleDropdown(content, 180, {
        { text = VB.L["ORIENTATION_H"], value = "HORIZONTAL" },
        { text = VB.L["ORIENTATION_V"], value = "VERTICAL" },
    }, VB.config.orientation == "VERTICAL" and VB.L["ORIENTATION_V"] or VB.L["ORIENTATION_H"])
    orientDropdown:SetPoint("TOPLEFT", 10, yOffset - 18)
    
    -- Store original OnClick to chain
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
    yOffset = yOffset - 50
    
    -- Role order dropdown
    local roleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleLabel:SetPoint("TOPLEFT", 10, yOffset)
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
    roleDropdown:SetPoint("TOPLEFT", 10, yOffset - 18)
    
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
    
    local classColorsCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    classColorsCB:SetPoint("TOPLEFT", 10, yOffset)
    classColorsCB.text:SetText(VB.L["CLASS_COLORS"])
    classColorsCB:SetChecked(VB.config.classColors)
    classColorsCB:SetScript("OnClick", function(self)
        VB.config.classColors = self:GetChecked()
        for _, button in pairs(VB.unitButtons) do
            VB:UpdateHealthBar(button)
        end
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
    yOffset = yOffset - 40
    
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
        if VB.frames.main then
            VB.frames.main:EnableMouse(not VB.config.locked)
        end
        if VB.frames.handle then
            VB.frames.handle:SetShown(not VB.config.locked)
        end
        UpdateLockButton()
    end)
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
    
    -- Active profile label
    local activeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeLabel:SetPoint("TOPLEFT", 10, yOffset)
    activeLabel:SetText(VB.L["ACTIVE_PROFILE"] .. ":")
    content.activeLabel = activeLabel
    
    local activeName = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeName:SetPoint("LEFT", activeLabel, "RIGHT", 8, 0)
    activeName:SetText("|cFF9966FF" .. VB:GetActiveProfileName() .. "|r")
    content.activeName = activeName
    yOffset = yOffset - 35
    
    -- Profile list
    local listLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 10, yOffset)
    listLabel:SetText(VB.L["PROFILES"] .. ":")
    yOffset = yOffset - 20
    
    -- Scroll frame for profile list
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
    
    -- Buttons row
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
    
    -- New button
    MakeProfileBtn(VB.L["PROFILE_NEW"], 0, function()
        VB:ShowProfileNameDialog("new")
    end)
    
    -- Copy button
    MakeProfileBtn(VB.L["PROFILE_COPY"], btnWidth + btnSpacing, function()
        VB:ShowProfileNameDialog("copy")
    end)
    
    -- Delete button
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
    
    content.selectedProfile = nil
end

function VB:RefreshProfilesTab()
    if not configFrame or not configFrame.profilesContent then return end
    local content = configFrame.profilesContent
    
    -- Update active name
    content.activeName:SetText("|cFF9966FF" .. VB:GetActiveProfileName() .. "|r")
    
    -- Clear old buttons
    for _, btn in ipairs(content.profileButtons) do
        btn:Hide()
    end
    
    local profiles = VB:GetProfileList()
    local activeName = VB:GetActiveProfileName()
    
    for i, name in ipairs(profiles) do
        local btn = content.profileButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, content.listFrame, "BackdropTemplate")
            btn:SetSize(296, 24)
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
            })
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
        btn.text:SetText(name)
        
        local isActive = (name == activeName)
        local isSelected = (name == content.selectedProfile)
        
        if isActive then
            btn.activeTag:SetText("|cFF00FF00" .. VB.L["PROFILE_ACTIVE"] .. "|r")
        else
            btn.activeTag:SetText("")
        end
        
        if isSelected then
            btn:SetBackdropColor(0.3, 0.3, 0.5, 1)
        elseif isActive then
            btn:SetBackdropColor(0.2, 0.2, 0.3, 1)
        else
            btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        end
        
        btn:SetScript("OnClick", function(self)
            content.selectedProfile = self.profileName
            VB:RefreshProfilesTab()
        end)
        btn:SetScript("OnDoubleClick", function(self)
            VB:SwitchProfile(self.profileName)
            VB:RefreshProfilesTab()
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.35, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            local sel = (self.profileName == content.selectedProfile)
            local act = (self.profileName == VB:GetActiveProfileName())
            if sel then
                self:SetBackdropColor(0.3, 0.3, 0.5, 1)
            elseif act then
                self:SetBackdropColor(0.2, 0.2, 0.3, 1)
            else
                self:SetBackdropColor(0.15, 0.15, 0.15, 1)
            end
        end)
        
        btn:Show()
    end
end

-------------------------------------------------
-- Profile Name Input Dialog
-------------------------------------------------
local profileDialog = nil

function VB:ShowProfileNameDialog(mode)
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
    profileDialog.editBox:SetText("")
    
    if mode == "new" then
        profileDialog.title:SetText(VB.L["PROFILE_NEW"])
    elseif mode == "copy" then
        profileDialog.title:SetText(VB.L["PROFILE_COPY"])
    end
    
    profileDialog.okBtn:SetScript("OnClick", function()
        local name = profileDialog.editBox:GetText():trim()
        if name == "" then return end
        
        if VoidBoxDB.profiles[name] then
            VB:Print(VB.L["PROFILE_EXISTS"])
            return
        end
        
        if profileDialog.mode == "new" then
            VB:CreateProfile(name)
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
