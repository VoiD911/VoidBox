--[[
    VoidBox - Recommended auras window (2.8.0)

    Lists VB.AURA_TEMPLATES for the player's class: "All specs" and a tab per
    talent tree, check rows, then Add (N). Opens on the detected spec. The
    rules (which items exist here, are learned, already added) and the adding
    live in Templates.lua; this file only shows them.
]]

local addonName, VB = ...

local ROW_HEIGHT = 24
local LIST_WIDTH = 405
local GREY = 0.6

local dialog            -- built on first use
local checked = {}      -- item -> true; kept across tabs while the window is open
local states = {}       -- item -> VB:TemplateItemState, computed when it opens
local rowPool, headerPool = {}, {}

local function Templates() return VB:GetAuraTemplates() end

-- Every item of the class in list order, with its tab (0 = All specs)
local function ForEachItem(fn)
    local t = Templates()
    if not t then return end
    for _, item in ipairs(t.common or {}) do fn(item, 0) end
    for index, spec in ipairs(t.specs or {}) do
        for _, item in ipairs(spec.items or {}) do fn(item, index) end
        for _, group in ipairs(spec.groups or {}) do
            for _, item in ipairs(group.items) do fn(item, index) end
        end
    end
end

local function ModeText(item)
    local key
    if item.source == "usable" then
        key = "TEMPLATE_USABLE"
    else
        key = "TEMPLATE_" .. (item.show or "present"):upper() .. "_" .. (item.unit == "target" and "TARGET" or "SELF")
    end
    return VB.L[key] or ""
end

-- Named after the spell the aura would be made on (the best one known), or
-- for an "any of these" aura by its label (Any blessing...)
local function LabelOf(item)
    local spell = VB:TemplatePrimary(item)
    local name = item.label and VB.L["TEMPLATE_LABEL_" .. item.label]
        or VB:GetSpellName(spell) or tostring(spell)
    return name .. " - " .. ModeText(item)
end

local function ShowTip(row)
    local item, L = row.item, VB.L
    local function Line(text) GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(LabelOf(item), 1, 1, 1)
    if item.form then
        Line(L["TEMPLATE_TIP_FORM"]:format(VB:GetSpellName(VB:TemplateFormSpell(item.form)) or item.form))
    end
    if item.combat == "in" then Line(L["TEMPLATE_TIP_IN_COMBAT"]) end
    if item.combat == "out" then Line(L["TEMPLATE_TIP_OUT_COMBAT"]) end
    if item.hostileTarget then Line(L["TEMPLATE_TIP_HOSTILE"]) end
    if item.glow then Line(L["TEMPLATE_TIP_GLOW"]) end
    if item.sound and item.sound ~= "none" then Line(L["TEMPLATE_TIP_SOUND"]) end
    local spells, primary = VB:TemplateItemSpells(item), VB:TemplatePrimary(item)
    local others = {}
    for _, id in ipairs(spells) do
        if id ~= primary then others[#others + 1] = VB:GetSpellName(id) end
    end
    if #others > 0 then Line(L["TEMPLATE_TIP_ALSO"]:format(table.concat(others, ", "))) end
    if item.requires and item.requires ~= VB:TemplateItemSpell(item) then
        Line(L["TEMPLATE_TIP_REQUIRES"]:format(VB:GetSpellName(item.requires) or tostring(item.requires)))
    end
    if item.note then GameTooltip:AddLine(L["TEMPLATE_NOTE_" .. item.note], 1, 0.82, 0, true) end
    if states[item] == "unlearned" then GameTooltip:AddLine(L["TEMPLATE_UNLEARNED"], 1, 0.5, 0.5) end
    if states[item] == "added" then GameTooltip:AddLine(L["TEMPLATE_ADDED_ALREADY"], 1, 0.5, 0.5) end
    GameTooltip:Show()
end

local function GetRow(i)
    local row = rowPool[i]
    if row then return row end
    row = CreateFrame("Frame", nil, dialog.listChild)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:EnableMouse(true)
    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(22, 22)
    row.check:SetPoint("LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.label:SetJustifyH("LEFT")
    row.check:SetScript("OnClick", function(self)
        checked[row.item] = self:GetChecked() and true or nil
        dialog.UpdateCount()
    end)
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.check:SetScript("OnEnter", function() ShowTip(row) end)
    row.check:SetScript("OnLeave", GameTooltip_Hide)
    rowPool[i] = row
    return row
end

local function ShowTab(tab)
    local L, t = VB.L, Templates()
    for _, button in ipairs(dialog.tabs) do
        if button.tab == tab then button:LockHighlight() else button:UnlockHighlight() end
    end
    for _, row in ipairs(rowPool) do row:Hide() end
    for _, header in ipairs(headerPool) do header:Hide() end

    local child = dialog.listChild
    local y, rows, headers = 0, 0, 0
    local function AddHeader(text)
        headers = headers + 1
        local h = headerPool[headers] or child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerPool[headers] = h
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 4, -y - 4)
        h:SetText(text)
        h:Show()
        y = y + 22
    end
    local function AddItem(item)
        local state = states[item]
        if state == "absent" then return end
        rows = rows + 1
        local row = GetRow(rows)
        row.item = item
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row.icon:SetTexture(VB:GetSpellIcon(VB:TemplatePrimary(item)))
        local text = LabelOf(item)
        if state == "unlearned" then text = text .. "  (" .. L["TEMPLATE_UNLEARNED"] .. ")" end
        if state == "added" then text = text .. "  (" .. L["TEMPLATE_ADDED_ALREADY"] .. ")" end
        row.label:SetText(text)
        local c = state == "ok" and 1 or GREY
        row.label:SetTextColor(c, c, c)
        row.icon:SetDesaturated(state ~= "ok")
        row.check:SetChecked(checked[item] and true or false)
        row.check:SetEnabled(state ~= "added")
        row:Show()
        y = y + ROW_HEIGHT
    end

    if tab == 0 then
        for _, item in ipairs(t.common or {}) do AddItem(item) end
    else
        local spec = t.specs[tab]
        for _, item in ipairs(spec.items or {}) do AddItem(item) end
        for _, group in ipairs(spec.groups or {}) do
            AddHeader(L["TEMPLATE_GROUP_" .. group.key] or group.key)
            for _, item in ipairs(group.items) do AddItem(item) end
        end
    end
    if rows == 0 then AddHeader(L["TEMPLATE_EMPTY"]) end
    child:SetHeight(math.max(y, 1))
end

local function Build()
    local L, t = VB.L, Templates()
    local f = VB:MakeDialog("VoidBoxTemplatesDialog", L["TEMPLATES_TITLE"], 470)
    dialog = f

    -- Tabs: All specs, then the talent trees in the game's order
    local entries = { { tab = 0, text = L["TEMPLATE_SPEC_ALL"] } }
    for i, spec in ipairs(t.specs) do
        entries[#entries + 1] = { tab = i, text = L["TEMPLATE_SPEC_" .. spec.key] or spec.key }
    end
    local width = math.floor((LIST_WIDTH + 20 - (#entries - 1) * 4) / #entries)
    f.tabs = {}
    for i, e in ipairs(entries) do
        local b = VB:MakeButton(f, e.text, width)
        b:SetNormalFontObject("GameFontNormalSmall")
        b:SetHighlightFontObject("GameFontHighlightSmall")
        b:SetPoint("TOPLEFT", 15 + (i - 1) * (width + 4), -40)
        b.tab = e.tab
        b:SetScript("OnClick", function() ShowTab(e.tab) end)
        f.tabs[i] = b
    end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 15, -75)
    scroll:SetSize(LIST_WIDTH, 340)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(LIST_WIDTH, 1)
    scroll:SetScrollChild(child)
    f.listChild = child

    local addBtn = VB:MakeButton(f, "", 140)
    addBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    local cancelBtn = VB:MakeButton(f, CANCEL)
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f.UpdateCount = function()
        local n = 0
        for _ in pairs(checked) do n = n + 1 end
        addBtn:SetText(L["TEMPLATES_ADD"]:format(n))
        addBtn:SetEnabled(n > 0)
    end
    addBtn:SetScript("OnClick", function()
        local list = {}
        ForEachItem(function(item) if checked[item] then list[#list + 1] = item end end)
        f:Hide()
        -- One screen group per batch, named after the class and the detected spec
        local spec = f.spec and t.specs[f.spec]
        local name = (UnitClass("player")) .. " - "
            .. (spec and (L["TEMPLATE_SPEC_" .. spec.key] or spec.key) or L["TEMPLATE_SPEC_ALL"])
        VB:AddTemplateAuras(list, name)
    end)
end

-- Opens on the detected spec (the first one when none), with "All specs" and
-- that spec's items checked, learned or not (they come on once learned):
-- only what is already there stays unchecked
function VB:ShowTemplatesWindow()
    local t = Templates()
    if not t then
        VB:Print(VB.L["TEMPLATES_NONE"])
        return
    end
    if not dialog then Build() end
    wipe(checked)
    wipe(states)
    local spec = VB:GetTalentSpec()
    if spec and not t.specs[spec] then spec = nil end
    dialog.spec = spec
    ForEachItem(function(item, tab)
        local state = VB:TemplateItemState(item)
        states[item] = state
        if (state == "ok" or state == "unlearned") and (tab == 0 or tab == spec) then checked[item] = true end
    end)
    dialog.UpdateCount()
    ShowTab(spec or 1)
    dialog:Show()
end
