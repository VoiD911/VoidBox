-- Independent click-cast boxes with fixed secure unit tokens and positions.
local addonName, VB = ...

local slots = {
    { unit = "target", key = "targetFrameShowTarget", label = "TARGET_FRAME", suffix = "Target" },
    { unit = "targettarget", key = "targetFrameShowTargetTarget", label = "TARGET_OF_TARGET", suffix = "TargetTarget" },
    { unit = "focus", key = "targetFrameShowFocus", label = "FOCUS_FRAME", suffix = "Focus" },
}

local function IsSelected(slot)
    if slot.unit == "target" then return VB.config[slot.key] ~= false end
    return VB.config[slot.key] == true
end

-- fullAuras rebuilds the aura rows from scratch. Tokens stay constant while
-- the underlying units change, so that is needed when the unit changes - but
-- doing it on every refresh made the icons flicker and slide sideways (the rows
-- are emptied and re-laid out each time).
local function RefreshButton(button, fullAuras)
    if fullAuras then
        for _, container in pairs({ button.debuffContainer, button.buffContainer }) do
            pcall(container.UpdateAllAuras, container)
        end
    end
    VB:UpdateUnitButton(button)
    VB:UpdateThreat(button)
end

function VB:RefreshTargetUnit()
    if not VB.config.showTargetFrame then return end
    for _, slot in ipairs(slots) do
        local button = VB.targetButtons[slot.unit]
        if button and IsSelected(slot) and UnitExists(slot.unit) then
            RefreshButton(button, true)
        end
    end
end

function VB:CreateTargetFrame()
    local frame = CreateFrame("Frame", "VoidBoxTargetFrame", UIParent,
        "SecureHandlerStateTemplate,BackdropTemplate")
    frame:Hide()
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    VB.frames.targetFrame = frame

    local handle = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    handle:SetHeight(14)
    handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT")
    handle:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT")
    handle:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    handle:SetBackdropColor(0.6, 0.4, 1, 0.7)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not VB.config.locked and not InCombatLockdown() then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        if InCombatLockdown() then return end
        frame:StopMovingOrSizing()
        local point, _, relPoint, x, y = frame:GetPoint()
        VB.config.targetFramePosition = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(VB.L["TARGETS_FRAME"])
    frame.handle = handle

    frame:SetScript("OnShow", function() VB:RefreshTargetUnit() end)
end

function VB:UpdateTargetFrame()
    if InCombatLockdown() then
        VB.pendingUpdate = true
        return
    end
    local frame = VB.frames.targetFrame
    if not VB.config.showTargetFrame then
        if frame then
            UnregisterStateDriver(frame, "visibility")
            frame:Hide()
        end
        return
    end
    if not frame then
        VB:CreateTargetFrame()
        frame = VB.frames.targetFrame
    end
    local width, height = VB:GetFrameSize()
    local spacing = VB.config.frameSpacing or 2
    local vertical = VB.config.targetFrameOrientation == "VERTICAL"
    local captionHeight = 14
    local count, conditions = 0, {}
    for _, slot in ipairs(slots) do
        local button = VB.targetButtons[slot.unit]
        if IsSelected(slot) then
            if not button then
                button = VB:CreateUnitButton(slot.unit, slot.suffix)
                button:SetParent(frame)
                local caption = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                caption:SetPoint("BOTTOM", button, "TOP", 0, 2)
                caption:SetText(VB.L[slot.label])
                button.targetCaption = caption
                VB.targetButtons[slot.unit] = button
                button:HookScript("OnShow", function() VB:RefreshTargetUnit() end)
                if slot.unit == "targettarget" then
                    -- Derived unit tokens do not have reliable dedicated unit
                    -- notifications on every supported client. Refresh this
                    -- visible box periodically as well as on target events.
                    button:HookScript("OnUpdate", function(self, elapsed)
                        self.targetRefreshElapsed = (self.targetRefreshElapsed or 0) + elapsed
                        if self.targetRefreshElapsed < 0.2 then return end
                        self.targetRefreshElapsed = 0
                        if not UnitExists("targettarget") then return end
                        -- Rebuild the aura rows only when the unit behind the
                        -- token really changed (UNIT_TARGET also covers it)
                        local okG, guid = pcall(UnitGUID, "targettarget")
                        local changed = false
                        if okG and guid ~= nil and not (issecretvalue and issecretvalue(guid)) then
                            changed = guid ~= self.targetGUID
                            self.targetGUID = guid
                        end
                        RefreshButton(self, changed)
                    end)
                end
            end
            VB:ResizeUnitButton(button)
            button.targetCaption:SetWidth(width)
            button:ClearAllPoints()
            local x = vertical and 0 or count * (width + spacing)
            local y = -captionHeight - (vertical and count * (height + captionHeight + spacing) or 0)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
            RegisterStateDriver(button, "visibility", "[@" .. slot.unit .. ",exists] show; hide")
            conditions[#conditions + 1] = "[@" .. slot.unit .. ",exists]"
            count = count + 1
        elseif button then
            UnregisterStateDriver(button, "visibility")
            button:Hide()
        end
    end
    local slotCount = math.max(1, count)
    frame:SetSize(
        vertical and width or slotCount * (width + spacing) - spacing,
        vertical and slotCount * (height + captionHeight + spacing) - spacing or height + captionHeight)
    local pos = VB.config.targetFramePosition
        or { point = "TOPLEFT", relPoint = "CENTER", x = 270, y = 150 }
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    frame.handle:SetShown(not VB.config.locked)
    -- Secure visibility handles target/focus acquisition and loss in combat.
    -- Empty slots keep their positions so another unit never moves under a click.
    local visibility = count > 0 and (table.concat(conditions) .. " show; hide") or "hide"
    RegisterStateDriver(frame, "visibility", visibility)
    VB:RefreshTargetUnit()
end

local events = CreateFrame("Frame")
VB:SafeRegisterEvent(events, "PLAYER_TARGET_CHANGED")
VB:SafeRegisterEvent(events, "PLAYER_FOCUS_CHANGED")
VB:SafeRegisterEvent(events, "UNIT_TARGET")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_TARGET" and unit ~= "target" then return end
    VB:RefreshTargetUnit()
end)

function VB:DebugTargetFrame()
    VB:Print("=== Target / focus frame ===")
    VB:Print("enabled=" .. tostring(VB.config.showTargetFrame)
        .. " combat=" .. tostring(InCombatLockdown())
        .. " pending=" .. tostring(VB.pendingUpdate))
    local frame = VB.frames.targetFrame
    VB:Print("frame=" .. tostring(frame ~= nil)
        .. " shown=" .. tostring(frame and frame:IsShown())
        .. " visible=" .. tostring(frame and frame:IsVisible()))
    for _, slot in ipairs(slots) do
        local button = VB.targetButtons[slot.unit]
        VB:Print(slot.unit .. ": selected=" .. tostring(IsSelected(slot))
            .. " exists=" .. tostring(UnitExists(slot.unit))
            .. " button=" .. tostring(button ~= nil)
            .. " shown=" .. tostring(button and button:IsShown())
            .. " visible=" .. tostring(button and button:IsVisible()))
    end
end
