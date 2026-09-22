--[[
    VoidBox - World of Warcraft: Forever compatibility layer
    (project "Camelot", 1.60.x, interface 16001)

    Forever runs the Retail/Midnight UI codebase on a level-60 Vanilla ruleset.
    That means the C_* namespaces are there, but:
      * there are no specializations (GetSpecialization & friends are gone,
        only C_SpecializationInfo survives and returns nil)
      * spell content is Vanilla: Retail spell IDs simply do not exist
      * secure snippets only compile when loadstring_untainted is present
      * registering an event the client does not know aborts the whole file

    Loaded right after Compat.lua. On Retail everything here stays inert.
]]

local addonName, VB = ...

-------------------------------------------------
-- Client detection
-------------------------------------------------
local _, _, _, tocVersion = GetBuildInfo()
VB.tocVersion = tonumber(tocVersion) or 0

-- Forever = modern API surface (C_Secrets exists) on a sub-2.0 interface number.
-- Classic Era has the low interface number but none of the Midnight namespaces.
VB.isForever = (VB.tocVersion > 0 and VB.tocVersion < 20000
                and C_Secrets ~= nil and C_Secrets.HasSecretRestrictions ~= nil) or false

-- Secure snippets (_onenter/_onleave/_onstate-*) need loadstring_untainted.
-- It is missing on early Forever builds, which silently kills every snippet.
VB.hasSecureSnippets = (type(loadstring_untainted) == "function")

-------------------------------------------------
-- Safe event registration
-- Registering an unknown event raises and aborts the enclosing file.
-------------------------------------------------
function VB:SafeRegisterEvent(frame, event)
    if not frame or not event then return false end
    if C_EventUtils and C_EventUtils.IsEventValid then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if ok and not valid then
            VB:Debug("Event not supported on this client: " .. event)
            return false
        end
    end
    return (pcall(frame.RegisterEvent, frame, event))
end

-------------------------------------------------
-- Specialization shims
-- GetSpecialization / GetSpecializationInfo are gone; the C_SpecializationInfo
-- namespace is still there but returns nil on a spec-less client.
-------------------------------------------------
local function callFirst(a, b, ...)
    local fn = a or b
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

function VB:GetPlayerSpecIndex()
    return callFirst(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization,
                     _G.GetSpecialization)
end

function VB:GetPlayerSpecID()
    local index = VB:GetPlayerSpecIndex()
    if not index then return nil end
    return callFirst(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo,
                     _G.GetSpecializationInfo, index)
end

function VB:GetPlayerSpecRole()
    local index = VB:GetPlayerSpecIndex()
    if not index then return nil end
    return callFirst(_G.GetSpecializationRole, nil, index)
end

-------------------------------------------------
-- Vanilla spell content
-- Only applied when VB.isForever; Retail keeps its own tables.
-------------------------------------------------

-- Rank-1 IDs. Any ID that does not exist on this client is filtered out at
-- runtime, so a wrong guess degrades silently instead of breaking anything.
VB.FOREVER_RANGE_SPELLS = {
    DRUID   = { 5185, 774, 8936 },       -- Healing Touch, Rejuvenation, Regrowth (40yd)
    PRIEST  = { 2061, 139, 17, 2050 },   -- Flash Heal, Renew, PW:Shield, Lesser Heal (40yd)
    PALADIN = { 19750, 635, 633, 1152 }, -- Flash of Light, Holy Light, Lay on Hands, Purify (40yd)
    SHAMAN  = { 331, 8004, 526 },        -- Healing Wave, Lesser Healing Wave, Cure Poison (40yd)
    MAGE    = { 475, 1459, 130 },        -- Remove Lesser Curse, Arcane Intellect, Slow Fall
    WARLOCK = { 20707, 5697 },           -- Soulstone Resurrection, Unending Breath
    WARRIOR = {},
    ROGUE   = {},
    HUNTER  = {},
}

-- spellID -> dispel type ID (1=Magic, 2=Curse, 3=Disease, 4=Poison)
-- Vanilla has no specs, so dispel capability is read from the spellbook.
VB.FOREVER_DISPEL_SPELLS = {
    -- Priest
    [527]  = 1,  -- Dispel Magic
    [528]  = 3,  -- Cure Disease
    [552]  = 3,  -- Abolish Disease
    -- Paladin
    [1152] = 3,  -- Purify (Disease, + Poison below)
    [4987] = 1,  -- Cleanse (Magic, + Disease/Poison below)
    -- Druid
    [2782] = 2,  -- Remove Curse
    [8946] = 4,  -- Cure Poison
    [2893] = 4,  -- Abolish Poison
    -- Shaman
    [526]  = 4,  -- Cure Poison
    [2870] = 3,  -- Cure Disease
    -- Mage
    [475]  = 2,  -- Remove Lesser Curse
}

-- Spells that clear more than one school
VB.FOREVER_DISPEL_EXTRA = {
    [1152] = { 4 },     -- Purify also clears Poison
    [4987] = { 3, 4 },  -- Cleanse also clears Disease and Poison
}

-- Base spell IDs of Vanilla HoTs / absorbs. Matched by NAME at runtime so every
-- rank is covered without listing dozens of IDs.
VB.FOREVER_HEAL_BUFF_BASE_IDS = {
    774,   -- Rejuvenation
    8936,  -- Regrowth
    139,   -- Renew
    17,    -- Power Word: Shield
    1022,  -- Blessing of Protection
    6940,  -- Blessing of Sacrifice
}

-- Filled at login: localized spell name -> true
VB.healBuffNames = {}

local function spellExists(id)
    if C_Spell and C_Spell.DoesSpellExist then
        local ok, exists = pcall(C_Spell.DoesSpellExist, id)
        if ok then return VB:SafeBool(exists) end
    end
    return VB:GetSpellName(id) ~= nil
end

local function spellKnown(id)
    local fn = (C_SpellBook and C_SpellBook.IsSpellKnown) or _G.IsSpellKnown
    if type(fn) ~= "function" then return false end
    local ok, known = pcall(fn, id)
    if ok then return VB:SafeBool(known) end
    return false
end

-- Build VB.healBuffNames from the base IDs above.
function VB:BuildForeverHealBuffNames()
    if not VB.isForever then return end
    wipe(VB.healBuffNames)
    for _, id in ipairs(VB.FOREVER_HEAL_BUFF_BASE_IDS) do
        local name = VB:GetSpellName(id)
        if name then VB.healBuffNames[name] = true end
    end
end

-- Every spell ID the aura row should accept.
--
-- Vanilla gives each rank its own ID, so a level-60 Rejuvenation is not 774.
-- Walking the spellbook and matching localized names picks up exactly the ranks
-- this character knows - which is also exactly what they can have out on a
-- target. Safe to read: the spellbook is not secret.
VB.healBuffIDs = {}

local function ForEachKnownSpell(callback)
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then return end
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0

    local ok, numLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or not numLines then return end

    for line = 1, numLines do
        local okLine, lineInfo = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if okLine and lineInfo and lineInfo.numSpellBookItems then
            local offset = lineInfo.itemIndexOffset or 0
            for i = 1, lineInfo.numSpellBookItems do
                local okItem, item = pcall(C_SpellBook.GetSpellBookItemInfo, offset + i, bank)
                if okItem and item and item.spellID then
                    callback(item.spellID, item.name)
                end
            end
        end
    end
end

-------------------------------------------------
-- Tracked (custom) buffs
--
-- Spells the player chose to watch in the HoT row on top of the built-in heal
-- list - e.g. a druid tracking Thorns. Same row, same PLAYER filter: only the
-- player's own casts show. Matched by name so every rank counts, like HoTs.
-------------------------------------------------
VB.customBuffNames = {}
VB.customBuffIDSet = {}

function VB:BuildCustomBuffSets()
    wipe(VB.customBuffNames)
    wipe(VB.customBuffIDSet)
    for _, id in ipairs(VB.customBuffs or {}) do
        VB.customBuffIDSet[id] = true
        local name = VB:GetSpellName(id)
        if name then VB.customBuffNames[name] = true end
    end
end

-- Returns true when added, false when the spell (any rank) is already tracked.
function VB:AddCustomBuff(spellID)
    if type(spellID) ~= "number" or not VB.customBuffs then return false end
    local name = VB:GetSpellName(spellID)
    for _, id in ipairs(VB.customBuffs) do
        if id == spellID or (name and VB:GetSpellName(id) == name) then return false end
    end
    table.insert(VB.customBuffs, spellID)
    VB:RefreshCustomBuffs()
    return true
end

function VB:RemoveCustomBuffAt(index)
    if not VB.customBuffs or not VB.customBuffs[index] then return end
    table.remove(VB.customBuffs, index)
    VB:RefreshCustomBuffs()
end

-- Rebuild the accepted-ID set and push it to every frame's HoT row.
function VB:RefreshCustomBuffs()
    VB:BuildHealBuffIDSet()
    VB:RefreshAuraContainerFilters()
    for _, group in ipairs({ VB.unitButtons, VB.tankButtons, VB.petButtons }) do
        for _, button in pairs(group or {}) do VB:UpdateAuras(button) end
    end
    if VB.RefreshCustomBuffsList then VB:RefreshCustomBuffsList() end
end

function VB:BuildHealBuffIDSet()
    VB:BuildCustomBuffSets()

    local ids = {}
    for id in pairs(VB.healBuffSpellIDs) do ids[id] = true end
    -- The dropped IDs themselves: all a rank-less (Retail) client needs
    for id in pairs(VB.customBuffIDSet) do ids[id] = true end

    if VB.isForever and (next(VB.healBuffNames) or next(VB.customBuffNames)) then
        local found = 0
        ForEachKnownSpell(function(spellID, name)
            name = name or VB:GetSpellName(spellID)
            if name and (VB.healBuffNames[name] or VB.customBuffNames[name]) then
                ids[spellID] = true
                found = found + 1
            end
        end)
        -- If the spellbook gave us nothing, applying this set as a filter would
        -- blank the row entirely. Better unfiltered than empty.
        if found == 0 then
            VB.healBuffIDs = nil
            VB:Debug("Heal buff ID set: spellbook walk found nothing, filter disabled")
            return
        end
        VB:Debug("Heal buff ID set: " .. found .. " ranks from spellbook")
    end

    VB.healBuffIDs = ids
end

-------------------------------------------------
-- Spell ranks (downranking)
--
-- Vanilla ranks are separate spells: Rejuvenation rank 1 is 774, rank 2 is
-- 1058, each its own base and override. Casting by name always picks the top
-- rank; casting by ID picks exactly that rank.
-------------------------------------------------

-- Rank number, read from the client's own localized subtext ("Rang 2",
-- "Rank 2", ...). Digits are the same in every locale.
function VB:GetSpellRank(spellID)
    if type(spellID) ~= "number" or not C_Spell or not C_Spell.GetSpellSubtext then return nil end
    local ok, subtext = pcall(C_Spell.GetSpellSubtext, spellID)
    if not ok or type(subtext) ~= "string" then return nil end
    return tonumber(subtext:match("(%d+)")), subtext
end

-- Highest rank of this spell's name that the character knows.
function VB:GetHighestKnownRank(spellID)
    local name = VB:GetSpellName(spellID)
    if not name then return nil end

    local highest
    ForEachKnownSpell(function(otherID, otherName)
        if (otherName or VB:GetSpellName(otherID)) == name then
            local rank = VB:GetSpellRank(otherID)
            if rank and (not highest or rank > highest) then highest = rank end
        end
    end)
    return highest
end

-- True when this is a deliberately lower rank than the best one known. Only
-- those get pinned: a top-rank binding stays name-based so it follows the
-- player up when the next rank is learned.
function VB:IsDownrank(spellID)
    local rank = VB:GetSpellRank(spellID)
    if not rank then return false end
    local highest = VB:GetHighestKnownRank(spellID)
    return highest ~= nil and rank < highest
end

-- Display name for a binding.
--   pinned rank   -> "Récupération (Rang 1)"
--   unpinned rank -> "Récupération (Rang max)": it casts by name, so it always
--                    fires the top rank and follows the player up. Showing the
--                    rank it happened to be dragged at would go stale.
--   no ranks      -> "Récupération" (Retail, or spells without ranks)
-- The localized "max" is spliced into the client's own subtext in place of the
-- number, so the word for "rank" (Rang/Rank/Rango/Ранг...) comes from the game
-- itself and only "max" needs translating.
function VB:GetBindingSpellLabel(spellID, rankLocked)
    local name = VB:GetSpellName(spellID)
    if not name then return nil end

    local rank, subtext = VB:GetSpellRank(spellID)
    if not rank then return name end

    if rankLocked then
        return name .. " (" .. subtext .. ")"
    end
    local maxWord = (VB.L and VB.L["RANK_MAX_WORD"]) or "max"
    local maxLabel = subtext:gsub("%d+", maxWord, 1)
    return name .. " (" .. maxLabel .. ")"
end

-- Dispel types the player can actually remove, read from the spellbook.
-- Returns a { [typeID] = true } set, or nil when this is not Forever.
function VB:GetForeverDispelTypes()
    if not VB.isForever then return nil end

    local canDispel = {}
    for id, dispelType in pairs(VB.FOREVER_DISPEL_SPELLS) do
        if spellKnown(id) then
            canDispel[dispelType] = true
            local extra = VB.FOREVER_DISPEL_EXTRA[id]
            if extra then
                for _, t in ipairs(extra) do canDispel[t] = true end
            end
        end
    end
    return canDispel
end

-- Range-check candidates for the current client.
function VB:GetRangeSpellCandidates(class, retailTable)
    if VB.isForever then
        local list = VB.FOREVER_RANGE_SPELLS[class]
        if not list then return {} end
        local filtered = {}
        for _, id in ipairs(list) do
            if spellExists(id) then table.insert(filtered, id) end
        end
        return filtered
    end
    return (retailTable and retailTable[class]) or {}
end

-------------------------------------------------
-- Startup notice
-------------------------------------------------
function VB:ForeverStartupNotice()
    if not VB.isForever or VB._foreverNoticeShown then return end
    VB._foreverNoticeShown = true

    VB:Print(VB.L["FOREVER_DETECTED"]:format(VB.tocVersion))
    if not VB.hasSecureSnippets then
        VB:Print("|cffffcc00" .. VB.L["SNIPPETS_UNAVAILABLE"] .. "|r")
    end
end
