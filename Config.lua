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
    configFrame:SetSize(500, 550)
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
        slot.actionText:SetText(VB:GetActionDisplayText(binding[2], binding[3]))
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
        local spellID, spellName = VB:GetCursorSpell()
        if spellID and self.bindingIndex then
            local binding = VB.clickCastings[self.bindingIndex]
            if binding then
                binding[2] = "spell"
                binding[3] = spellID
                VB:ApplyClickCastingsToAllFrames()
                VB:RefreshBindingsList()
                ClearCursor()
            end
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
    }, VB.L["BTN_LEFT"])
    mouseDropdown:SetPoint("TOPLEFT", 15, -112)
    addDialog.mouseDropdown = mouseDropdown
    
    -- Action type selector
    local actionLabel = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionLabel:SetPoint("TOPLEFT", 15, -145)
    actionLabel:SetText(VB.L["ACTION_TYPE"])
    
    local actionDropdown = CreateSimpleDropdown(addDialog, 180, {
        { text = VB.L["ACTION_SPELL"], value = "spell" },
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
    dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_HERE"] .. "|r")
    addDialog.dropText = dropText
    addDialog.dropZone = dropZone
    addDialog.selectedSpell = nil
    
    dropZone:SetScript("OnReceiveDrag", function()
        local spellID, spellName, spellIcon = VB:GetCursorSpell()
        if spellID and spellName then
            addDialog.selectedSpell = spellID
            addDialog.actionDropdown.selectedValue = "spell"
            addDialog.actionDropdown.text:SetText(VB.L["ACTION_SPELL"])
            local iconStr = spellIcon and ("|T" .. spellIcon .. ":20|t ") or ""
            dropText:SetText(iconStr .. spellName)
            ClearCursor()
        end
    end)
    
    dropZone:SetScript("OnClick", function()
        addDialog.selectedSpell = nil
        dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_HERE"] .. "|r")
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
    
    local parts = {}
    if addDialog.shiftCB:GetChecked() then table.insert(parts, "shift") end
    if addDialog.ctrlCB:GetChecked() then table.insert(parts, "ctrl") end
    if addDialog.altCB:GetChecked() then table.insert(parts, "alt") end
    local modifier = table.concat(parts, "-")
    
    local mouseButton = addDialog.mouseDropdown.selectedValue or "Left"
    
    local actionValue = nil
    if actionType == "spell" then
        actionValue = addDialog.selectedSpell
    end
    
    if VB:AddClickCasting(modifier, mouseButton, actionType, actionValue) then
        VB:RefreshBindingsList()
        addDialog:Hide()
        
        addDialog.shiftCB:SetChecked(false)
        addDialog.ctrlCB:SetChecked(false)
        addDialog.altCB:SetChecked(false)
        addDialog.selectedSpell = nil
        addDialog.dropText:SetText("|cFFAAAAFF" .. VB.L["DROP_SPELL_HERE"] .. "|r")
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
    
    local heightSlider = CreateSimpleSlider(content, VB.L["HEIGHT"], 20, 80, 5, VB.config.frameHeight, function(value)
        VB.config.frameHeight = value
        if not InCombatLockdown() then VB:UpdateAllFrames() end
    end)
    heightSlider:SetPoint("TOPLEFT", 10, yOffset)
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
