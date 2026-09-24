--[[
    VoidBox - Spell inspector (debug tool)

    Shows what the client itself knows about a spell - ID, name, rank subtext,
    link, base/override IDs, spellbook entry - in a window whose text can be
    selected and copied (the chat frame cannot).

      /vb spelllog           toggle the window and live capture:
                               * every spell the player casts
                               * every spell picked up on the cursor, i.e.
                                 exactly what drag & drop hands to VoidBox
      /vb spellranks <text>  list every spellbook entry whose name contains
                             <text>, one line per rank

    Dormant until opened: no events are registered while the window is closed.
]]

local addonName, VB = ...

local MAX_LINES = 400
local lines = {}
local window, editBox, scrollFrame
local captureFrame

-------------------------------------------------
-- Safe readers
-------------------------------------------------
local function isSecret(v)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, v)
    return ok and VB:SafeBool(secret)
end

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

local function show(v)
    if v == nil then return "nil" end
    if isSecret(v) then return "<secret>" end
    return tostring(v)
end

-------------------------------------------------
-- Describe one spell ID the way the client sees it
-------------------------------------------------
local function DescribeSpell(spellID)
    if isSecret(spellID) then
        return "id=<secret> (cast out of combat to read it)"
    end

    local name     = try(C_Spell and C_Spell.GetSpellName, spellID)
    local subtext  = try(C_Spell and C_Spell.GetSpellSubtext, spellID)
    local link     = try(C_Spell and C_Spell.GetSpellLink, spellID)
    local base     = try(C_Spell and C_Spell.GetBaseSpell, spellID)
    local override = try(C_Spell and C_Spell.GetOverrideSpell, spellID)
    local known    = try(C_SpellBook and C_SpellBook.IsSpellKnown, spellID)

    local parts = {
        ("id=%s"):format(show(spellID)),
        ("name=%q"):format(show(name)),
        ("subtext=%q"):format(show(subtext)),
        ("base=%s"):format(show(base)),
        ("override=%s"):format(show(override)),
        ("known=%s"):format(show(known)),
    }

    -- Where it sits in the spellbook, and what the book calls it. subName is
    -- where Classic-style clients put "Rank N".
    local slot, bank = try(C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell, spellID)
    if slot then
        local item = try(C_SpellBook.GetSpellBookItemInfo, slot, bank)
        parts[#parts + 1] = ("book=%s/%s"):format(show(slot), show(bank))
        if type(item) == "table" then
            parts[#parts + 1] = ("bookName=%q bookSubName=%q bookSpellID=%s"):format(
                show(item.name), show(item.subName), show(item.spellID))
        end
    end

    if link then
        -- The link text is what the client prints for this exact spell/rank.
        -- "||" so the pipes survive as literal characters in the edit box.
        parts[#parts + 1] = "link=" .. show(link):gsub("|", "||")
    end

    return table.concat(parts, "  ")
end

-------------------------------------------------
-- Window
-------------------------------------------------
local function Refresh()
    if not editBox then return end
    editBox:SetText(table.concat(lines, "\n"))
    -- Scroll to the newest line once the edit box has re-measured itself
    C_Timer.After(0, function()
        if scrollFrame then
            scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
        end
    end)
end

local function Append(text)
    lines[#lines + 1] = date("%H:%M:%S") .. "  " .. text
    while #lines > MAX_LINES do table.remove(lines, 1) end
    Refresh()
end

local function MakeButton(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function CreateWindow()
    window = CreateFrame("Frame", "VoidBoxSpellLog", UIParent, "BackdropTemplate")
    window:SetSize(640, 360)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    window:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    window:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    window:SetBackdropBorderColor(0.6, 0.4, 1, 1)
    tinsert(UISpecialFrames, "VoidBoxSpellLog")  -- close on Escape

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("VoidBox - Spell log  (cast a spell, or pick one up from the spellbook)")

    local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scrollFrame = ok and sf or CreateFrame("ScrollFrame", nil, window)
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

    editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(590)
    editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
    -- Read-only in practice: any typing is reverted to the log contents
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then Refresh() end
    end)
    scrollFrame:SetScrollChild(editBox)

    local selectAll = MakeButton(window, "Select all", 100, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    selectAll:SetPoint("BOTTOMLEFT", 10, 10)

    local clear = MakeButton(window, "Clear", 80, function()
        wipe(lines)
        Refresh()
    end)
    clear:SetPoint("LEFT", selectAll, "RIGHT", 6, 0)

    local close = MakeButton(window, "Close", 80, function() window:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -10, 10)

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", clear, "RIGHT", 10, 0)
    hint:SetText("Select all, then Ctrl+C to copy")

    -- Capture only while the window is open
    window:SetScript("OnShow", function() VB:SpellLogSetCapture(true) end)
    window:SetScript("OnHide", function() VB:SpellLogSetCapture(false) end)
    window:Hide()
end

-------------------------------------------------
-- Live capture
-------------------------------------------------
local function OnCaptureEvent(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            Append("CAST    " .. DescribeSpell(spellID))
        end
    elseif event == "CURSOR_CHANGED" then
        local kind, a, b, c = GetCursorInfo()
        if kind == "spell" then
            -- The raw tuple is what VoidBox's drag & drop receives
            Append(("CURSOR  raw=(%s, %s, %s)  "):format(show(a), show(b), show(c))
                .. DescribeSpell(c or a))
        end
    end
end

function VB:SpellLogSetCapture(enabled)
    if not captureFrame then
        captureFrame = CreateFrame("Frame")
        captureFrame:SetScript("OnEvent", OnCaptureEvent)
    end
    if enabled then
        VB:SafeRegisterEvent(captureFrame, "UNIT_SPELLCAST_SUCCEEDED")
        VB:SafeRegisterEvent(captureFrame, "CURSOR_CHANGED")
    else
        captureFrame:UnregisterAllEvents()
    end
end

-------------------------------------------------
-- Commands
-------------------------------------------------
function VB:SpellLogToggle()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
    if window:IsShown() and #lines == 0 then
        Append("Ready. Client: " .. show(VB.tocVersion) .. (VB.isForever and " (Forever)" or ""))
    end
end

-- List every spellbook entry whose name contains `query`, one line per rank.
function VB:SpellLogRanks(query)
    if not window then CreateWindow() end
    window:Show()

    query = (query or ""):lower()
    if query == "" then
        Append("Usage: /vb spellranks <part of a spell name>")
        return
    end

    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local numLines = try(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) or 0
    local found = 0

    Append(("RANKS   searching the spellbook for %q ..."):format(query))
    for line = 1, numLines do
        local lineInfo = try(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if type(lineInfo) == "table" and lineInfo.numSpellBookItems then
            local offset = lineInfo.itemIndexOffset or 0
            for i = 1, lineInfo.numSpellBookItems do
                local item = try(C_SpellBook.GetSpellBookItemInfo, offset + i, bank)
                if type(item) == "table" and item.name
                   and not isSecret(item.name) and item.name:lower():find(query, 1, true) then
                    found = found + 1
                    Append(("RANKS   slot=%d  subName=%q  "):format(offset + i, show(item.subName))
                        .. DescribeSpell(item.spellID))
                end
            end
        end
    end
    Append(("RANKS   %d match(es). If only one rank shows, the spellbook hides lower ranks."):format(found))
end

-- Why does the "rez" action do (or not do) what it does? Dumps what the client says about
-- every candidate spell, what VoidBox concluded, the macro it built, and the whole spellbook
-- so the real resurrection spell can be identified.
function VB:SpellLogRez()
    if not window then CreateWindow() end
    window:Show()

    local class = VB.playerClass or select(2, UnitClass("player"))
    local data = VB.isForever and VB.FOREVER_REZ_SPELLS or VB.REZ_SPELLS
    Append(("REZ     class=%s level=%s forever=%s locale=%s tocVersion=%s"):format(
        show(class), show(UnitLevel("player")), show(VB.isForever), show(GetLocale()), show(VB.tocVersion)))

    local list = data and data[class]
    if not list then
        Append("REZ     no candidate table for this class on this client")
    else
        for _, slotName in ipairs({ "normal", "combat" }) do
            for _, id in ipairs(list[slotName] or {}) do
                Append(("REZ     candidate %s  isKnownByID=%s  highestRank=%s"):format(
                    slotName, show(VB:IsSpellKnownByID(id)),
                    show(VB.GetHighestKnownRank and VB:GetHighestKnownRank(id))))
                Append("REZ       " .. DescribeSpell(id))
            end
        end
    end

    local spells = VB:GetRezSpells()
    Append(("REZ     resolved: normal=%q combat=%q"):format(show(spells.normal), show(spells.combat)))
    Append(("REZ     macro: %s"):format(show(VB:BuildRezMacro())))

    -- Every rez binding currently configured, and what is actually set on a frame
    local n = 0
    for _, b in ipairs(VB.clickCastings or {}) do
        if b.action == "rez" then
            n = n + 1
            Append(("REZ     binding: mouse=%s combo=%s mods=%q display=%q"):format(
                show(b.mouse), show(b.combo), show(b.mods), show(b.display)))
        end
    end
    Append(("REZ     %d rez binding(s) configured"):format(n))

    -- The whole spellbook: name / rank text / id
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local numLines = try(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) or 0
    Append("BOOK    --- full spellbook ---")
    for line = 1, numLines do
        local lineInfo = try(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if type(lineInfo) == "table" and lineInfo.numSpellBookItems then
            Append(("BOOK    [%s]"):format(show(lineInfo.name)))
            local offset = lineInfo.itemIndexOffset or 0
            for i = 1, lineInfo.numSpellBookItems do
                local item = try(C_SpellBook.GetSpellBookItemInfo, offset + i, bank)
                if type(item) == "table" and item.name and not isSecret(item.name) then
                    Append(("BOOK    %s  subName=%q  id=%s"):format(
                        show(item.name), show(item.subName), show(item.spellID)))
                end
            end
        end
    end
    Append("REZ     done - Select all, Ctrl+C, and paste it back.")
end
