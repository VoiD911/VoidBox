--[[
    VoidBox - Native aura containers (WoW 12.1+, incl. Forever/Camelot)

    Since auras went secret, addon code cannot enumerate them in combat: the
    index walk and GetAuraSlots both raise, GetUnitAuras returns nothing, and
    even targeted per-spell lookups answer nil (healing HoTs report secrecy
    level 2). Reading auras to draw them is a dead end.

    AuraContainer is the sanctioned way round it. The addon declares a filter,
    and the client does the tracking, filtering, sorting and rendering itself;
    the addon only styles the buttons it is handed. No aura data ever reaches
    Lua, so nothing needs to be unlocked - and it keeps working in combat.

    Everything here degrades to nil/false on clients without the intrinsic
    frame type (Retail before 12.1), where UnitFrames.lua keeps its Lua path.
]]

local addonName, VB = ...

-------------------------------------------------
-- Capability probe (cached)
-------------------------------------------------
function VB:HasAuraContainers()
    if VB._hasAuraContainers ~= nil then return VB._hasAuraContainers end

    local ok = false
    if C_AuraContainerUtil then
        local created, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent,
                                     "CustomAuraContainerTemplate")
        ok = created and frame ~= nil and type(frame.AddAuraGroup) == "function"
        if ok then
            -- Probe frame is not reusable as a real container; park it hidden.
            pcall(frame.SetEnabled, frame, false)
            pcall(frame.Hide, frame)
        end
    end

    VB._hasAuraContainers = ok
    VB:Debug("AuraContainer support: " .. tostring(ok))
    return ok
end

-------------------------------------------------
-- Button styling
--
-- Called once per AuraButton the client creates. AuraButton forbids untrusted
-- script execution, so this only attaches regions and hands them over through
-- the Set*/Add* methods - the client drives them from then on.
-------------------------------------------------
local function StyleAuraButton(size, isDebuff, button)
    button:SetSize(size, size)
    button:EnableMouse(false)

    local icon = button:CreateTexture(nil, "BORDER")
    icon:SetAllPoints()
    button.icon = icon
    button:SetIcon(icon)

    -- Cooldown sweep. The client feeds it the duration, so this keeps ticking
    -- in combat where the old SetCooldownDuration path had nothing to read.
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetReverse(true)
    button.cooldown = cooldown
    pcall(button.SetDurationCooldown, button, cooldown)

    -- Stack count, rendered above the cooldown sweep
    local textLayer = CreateFrame("Frame", nil, button)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(cooldown:GetFrameLevel() + 1)

    local count = textLayer:CreateFontString(nil, "OVERLAY")
    count:SetFont(VB.config.font, math.max(7, math.floor(size * 0.5)), "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    count:SetTextColor(1, 0.85, 0)
    button.count = count
    pcall(button.SetApplicationCount, button, count)

    -- Dispel border, coloured by the client from the aura's dispel type.
    -- VoidBox's colour map keeps the "only what I can dispel" behaviour; if the
    -- map shape is rejected we fall back to the client's default colours rather
    -- than losing the border entirely.
    if isDebuff then
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        button.border = border

        local opts = {
            showWhenHarmful = true,
            showWhenHelpful = false,
        }
        if Enum and Enum.CustomAuraButtonDispelTypeTextureStyle then
            opts.style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border
        end

        local withMap = CopyTable and CopyTable(opts) or opts
        withMap.customDispelColorMap = VB.dispelColorMap
        if not pcall(button.AddDispelTypeTexture, button, border, withMap) then
            pcall(button.AddDispelTypeTexture, button, border, opts)
        end
    end
end

-- Shared with Auras.lua (screen auras), which builds its own containers
VB.StyleAuraButton = StyleAuraButton

-------------------------------------------------
-- Container creation
-------------------------------------------------
local function NewContainer(parent, key, filter, maxCount, size, isDebuff)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent,
                                "CustomAuraContainerTemplate")
    if not ok or not container then return nil end

    -- Flow from TOPLEFT and keep the container itself exactly as wide as the
    -- icons it holds; the container is centre-anchored, so the row is centred
    -- as a block. Anchoring the flow at "TOP" instead grows rightwards from the
    -- middle, which only looks centred while a single icon is up.
    pcall(container.SetFlowLayoutAnchorPoint, container, "TOPLEFT")
    if AnchorUtil and AnchorUtil.FlowLayoutAxis then
        pcall(container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Horizontal)
    end
    pcall(container.SetFlowLayoutGrowthDirection, container, 1, -1)
    pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
    pcall(container.SetFlowLayoutMaximumLineSize, container, parent:GetWidth())

    -- The client calls initializeFrame once per AuraButton it creates, possibly
    -- long after this: read the size at that moment, not the one at creation.
    container._iconSize = size
    local added = pcall(container.AddAuraGroup, container, key, filter, {
        maxFrameCount = maxCount,
        initializeFrame = function(button)
            StyleAuraButton(container._iconSize or size, isDebuff, button)
        end,
    })
    if not added then return nil end

    -- maxFrameCount inside the options table is not honoured (a probe group
    -- capped at 4 still reported 10 frames), so cap the group explicitly.
    pcall(container.SetAuraGroupMaxFrameCount, container, key, maxCount)

    container._groupKey = key
    container._isDebuff = isDebuff
    VB:ApplyAuraContainerFilters(container)
    container._isDebuff = isDebuff
    container._iconSize = size
    container._maxCount = maxCount
    return container
end

-- Narrow the HoT row to actual heals.
--
-- "HELPFUL|PLAYER" is everything we cast, buffs included, so the row would fill
-- up with Mark of the Wild and friends. includeSpellIDs restricts it to the
-- heal ranks collected from the spellbook - the client still does the matching,
-- we only hand it the list.
function VB:ApplyAuraContainerFilters(container)
    if not container or container._isDebuff then return end

    local ids = VB.healBuffIDs
    if not ids or not next(ids) then return end

    pcall(container.SetAuraGroupCandidateFilters, container, container._groupKey,
          { includeSpellIDs = ids })
end

-- Re-apply after the spellbook changes (new rank learned, spec swap).
function VB:RefreshAuraContainerFilters()
    for _, group in ipairs({ VB.unitButtons, VB.tankButtons, VB.petButtons, VB.targetButtons }) do
        for _, button in pairs(group or {}) do
            if button.buffContainer then
                VB:ApplyAuraContainerFilters(button.buffContainer)
                pcall(button.buffContainer.UpdateAllAuras, button.buffContainer)
            end
        end
    end
end

-- Shrink-wrap a container to the icons currently in it. The frame count is a
-- plain number even while the auras themselves are secret, so this is safe in
-- combat - and it is what keeps the row centred.
local function FitToContents(container)
    if not container or not container._groupKey then return end

    local ok, count = pcall(container.GetAuraGroupFrameCount, container, container._groupKey)
    if not ok or type(count) ~= "number" then return end

    count = math.max(0, math.min(count, container._maxCount or count))
    local size = container._iconSize or 12
    local width = math.max(1, count * size)

    container:SetWidth(width)
    pcall(container.SetFlowLayoutMaximumLineSize, container, width)
end

-- Probe for /vb auratest: one icon, built exactly like the HoT row (which is
-- known to display in combat on Forever), limited to the given spell ID set.
function VB:CreateAuraTestBox(ids, size)
    local box = NewContainer(UIParent, "vbAuraTest", "HELPFUL|PLAYER", 1, size, false)
    if not box then return nil end
    pcall(box.SetAuraGroupCandidateFilters, box, "vbAuraTest", { includeSpellIDs = ids })
    box:SetSize(size, size)
    box:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    pcall(box.SetEnabled, box, true)
    box:Show()
    pcall(box.SetUnit, box, "player")
    pcall(box.UpdateAllAuras, box)
    return box
end

-- Icons the client is displaying in a container (our buttons carry .icon)
function VB:CountShownAuraButtons(container)
    local shown = 0
    local ok, children = pcall(function() return { container:GetChildren() } end)
    if not ok then return -1 end
    for _, child in ipairs(children) do
        if child.icon then
            local okS, s = pcall(child.IsShown, child)
            if okS and VB:SafeBool(s) then shown = shown + 1 end
        end
    end
    return shown
end

-------------------------------------------------
-- Dispel ring (Forever)
--
-- Forever refuses every aura read in combat, so the frame border cannot be
-- coloured from our own data. Instead a third container, filtered "HARMFUL|RAID"
-- (harmful auras the player can dispel), holds a single invisible 1px button.
-- That button owns four edge textures placed around the unit frame and
-- registered as its dispel type textures: the client shows the button - and
-- with it the ring - only while such a debuff exists, and tints the edges from
-- the debuff's dispel type through our curve. Nothing is read by the addon.
-- Technique as used by Forever Unit Frames (github.com/StephanRosin).
-------------------------------------------------
local RING_SIZE = 4
local RING_COLORS = {
    [1] = { 0.2, 0.6, 1 },   -- Magic
    [2] = { 0.6, 0.2, 1 },   -- Curse
    [3] = { 0.6, 0.4, 0 },   -- Disease
    [4] = { 0, 0.6, 0.1 },   -- Poison
    [9] = { 1, 0.2, 0 },     -- Enrage
}
local ringCurve

-- Fixed curve: the RAID filter already keeps only what the player can dispel,
-- so every type gets its colour and the curve never needs rebuilding.
local function GetRingCurve()
    if ringCurve then return ringCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    ringCurve = C_CurveUtil.CreateColorCurve()
    if Enum and Enum.LuaCurveType then ringCurve:SetType(Enum.LuaCurveType.Step) end
    for _, id in ipairs({ 0, 1, 2, 3, 4, 9 }) do
        local c = RING_COLORS[id]
        ringCurve:AddPoint(id, c and CreateColor(c[1], c[2], c[3], 1) or CreateColor(0, 0, 0, 0))
    end
    return ringCurve
end

local function InitRingButton(frame, auraButton)
    pcall(auraButton.SetMouseClickEnabled, auraButton, false)
    pcall(auraButton.SetMouseMotionEnabled, auraButton, false)
    local options = { customDispelColorCurve = GetRingCurve() }
    if Enum and Enum.CustomAuraButtonDispelTypeTextureStyle then
        options.style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
    end
    for side = 1, 4 do
        local edge = auraButton:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetColorTexture(1, 1, 1, 1)
        if side == 1 then
            edge:SetPoint("TOPLEFT", frame, "TOPLEFT")
            edge:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
            edge:SetHeight(RING_SIZE)
        elseif side == 2 then
            edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
            edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
            edge:SetHeight(RING_SIZE)
        elseif side == 3 then
            edge:SetPoint("TOPLEFT", frame, "TOPLEFT")
            edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
            edge:SetWidth(RING_SIZE)
        else
            edge:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
            edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
            edge:SetWidth(RING_SIZE)
        end
        pcall(auraButton.AddDispelTypeTexture, auraButton, edge, options)
    end
end

function VB:SetupDispelRing(button)
    if button.dispelRing or not GetRingCurve() then return end
    local ok, container = pcall(function()
        local c = CreateFrame("AuraContainer", nil, button, "CustomAuraContainerTemplate")
        pcall(c.SetEditModePreviewEnabled, c, false)
        c:AddAuraGroup("vbDispelRing", "HARMFUL|RAID", {
            maxFrameCount = 1,
            layout = { elementWidth = 1, elementHeight = 1 },
            initializeFrame = function(auraButton) InitRingButton(button, auraButton) end,
        })
        pcall(c.SetAuraGroupMaxFrameCount, c, "vbDispelRing", 1)
        c:SetSize(1, 1)
        c:SetPoint("TOPLEFT", button, "TOPLEFT")
        c:SetFrameLevel(button:GetFrameLevel() + 10)
        return c
    end)
    if ok and container then
        button.dispelRing = container
    else
        VB:Debug("Dispel ring unavailable: " .. tostring(container))
    end
end

-- Build the two rows on a unit button. Returns true when both were created.
function VB:SetupButtonAuraContainers(button, S, maxDebuffs, maxBuffs)
    if not VB:HasAuraContainers() then return false end

    local parent = button.healthBar
    local width = parent:GetWidth()

    local debuffs = NewContainer(parent, "vbDebuffs", "HARMFUL",
                                 maxDebuffs, S.debuffSize, true)
    -- PLAYER narrows to our own casts server-side, so aura.sourceUnit - which
    -- is secret in combat - never has to be read.
    local buffs = NewContainer(parent, "vbBuffs", "HELPFUL|PLAYER",
                               maxBuffs, S.buffSize, false)

    if not debuffs or not buffs then
        if debuffs then debuffs:Hide() end
        if buffs then buffs:Hide() end
        VB._hasAuraContainers = false
        return false
    end

    debuffs:SetSize(width, S.debuffSize)
    buffs:SetSize(width, S.buffSize)

    button.debuffContainer = debuffs
    button.buffContainer = buffs
    VB:AnchorAuraContainers(button, S)
    if VB.isForever then VB:SetupDispelRing(button) end
    return true
end

-- Resize the AuraButtons a container already made. They are styled once, when
-- the client creates them, so without this a new icon size only showed after a
-- /reload. Our buttons are the children that carry .icon (set in StyleAuraButton).
local function ResizeAuraButtons(container, size)
    if not container then return end
    local ok, children = pcall(function() return { container:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
        if child.icon then
            pcall(child.SetSize, child, size, size)
            if child.count then
                pcall(child.count.SetFont, child.count, VB.config.font,
                      math.max(7, math.floor(size * 0.5)), "OUTLINE")
            end
        end
    end
end

-- Position and size both rows; called on creation and on every scale change.
function VB:AnchorAuraContainers(button, S)
    local parent = button.healthBar
    if not parent then return end
    local width = parent:GetWidth()

    if button.debuffContainer then
        button.debuffContainer:ClearAllPoints()
        button.debuffContainer:SetPoint("TOP", parent, "TOP", 0, -(button._row2Top or 14))
        button.debuffContainer:SetHeight(S.debuffSize)
        button.debuffContainer._iconSize = S.debuffSize
        ResizeAuraButtons(button.debuffContainer, S.debuffSize)
        FitToContents(button.debuffContainer)
    end
    if button.buffContainer then
        button.buffContainer:ClearAllPoints()
        button.buffContainer:SetPoint("TOP", parent, "TOP", 0, -(button._row3Top or 36))
        button.buffContainer:SetHeight(S.buffSize)
        button.buffContainer._iconSize = S.buffSize
        ResizeAuraButtons(button.buffContainer, S.buffSize)
        FitToContents(button.buffContainer)
    end
end

-- Point the containers at this button's unit and re-centre the rows. SetUnit
-- triggers a full refresh, so the client does the rest.
function VB:UpdateAuraContainers(button)
    local unit = button.unit
    if not unit then return end

    local ring = button.dispelRing
    if ring then
        ring:SetShown(VB.config.showDispelHighlight ~= false)
        if ring:GetUnit() ~= unit then pcall(ring.SetUnit, ring, unit) end
    end

    for _, container in ipairs({ button.debuffContainer, button.buffContainer }) do
        if container:GetUnit() ~= unit then
            pcall(container.SetUnit, container, unit)
        end
        FitToContents(container)
    end
end

function VB:SetAuraContainersShown(button, showDebuffs, showBuffs)
    if button.debuffContainer then
        button.debuffContainer:SetShown(showDebuffs)
        pcall(button.debuffContainer.SetEnabled, button.debuffContainer, showDebuffs)
    end
    if button.buffContainer then
        button.buffContainer:SetShown(showBuffs)
        pcall(button.buffContainer.SetEnabled, button.buffContainer, showBuffs)
    end
end
