--[[
    VoidBox - World of Warcraft: Forever compatibility layer
    (project "Camelot", 1.60.x, interface 16001)

    Forever runs the Retail/Midnight UI codebase on a level-60 Vanilla ruleset.
    That means the C_* namespaces are there, but:
      * there are no specializations (GetSpecialization & friends are gone,
        only C_SpecializationInfo survives and returns nil)
      * spell content is Vanilla: Retail spell IDs simply do not exist
      * secure snippet support must be checked by executing a snippet
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

-- Any client whose spells still have their own per-rank ID (Vanilla, TBC/BCC
-- Anniversary, Forever...) needs auras matched by localized NAME instead of
-- ID: only rank 1 of a spell tends to share the Retail ID the rest of the
-- addon is keyed on (see VB.healBuffSpellIDs). C_UnitAuras.GetUnitAuras is
-- the Dragonflight+ unified aura reader; its absence is what actually causes
-- the multi-rank problem, on any client - not being "Forever" specifically.
-- (Forever itself already satisfies this, since a client that new would
-- otherwise have GetUnitAuras; kept explicit so isForever changing shape
-- later can't silently drop this.)
-- Burning Crusade Classic Anniversary has GetUnitAuras yet still ranks its
-- spells (Renew rank 10 is not spell 139), so any pre-Legion interface number
-- counts as ranked too.
VB.hasRankedSpellbook = VB.isForever
    or (VB.tocVersion > 0 and VB.tocVersion < 100000)
    or not (C_UnitAuras and C_UnitAuras.GetUnitAuras)

-- Forever can execute secure snippets even when loadstring_untainted is not
-- exposed to addons. Storing snippet text alone also proves nothing: execute
-- an attribute handler and verify its result before selecting hover bindings.
local function ProbeSecureSnippets()
    local probe
    local ok, supported = pcall(function()
        probe = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
        probe:SetAttribute("_onattributechanged",
            [[ if name == "vbping" then self:SetAttribute("vbpong", value) end ]])
        probe:SetAttribute("vbping", 42)
        return probe:GetAttribute("vbpong") == 42
    end)
    if probe then
        pcall(probe.SetAttribute, probe, "_onattributechanged", nil)
        pcall(probe.Hide, probe)
    end
    return ok and supported == true
end

VB.hasSecureSnippets = ProbeSecureSnippets()

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

-- Resurrection spells per class for the "rez" click-cast action. Rank 1 IDs:
-- every rank shares one localized name, so casting by that name fires the
-- highest known rank. First known ID of each list wins.
-- normal = usable out of combat, combat = battle res. No Vanilla paladin
-- battle res exists.
-- The druid out-of-combat "Revive" is a Forever-only spell with its own ID:
-- 437138 (read from a level 14 druid's spellbook with /vb rezdebug, shown as
-- "Ressusciter" Rang 1 on frFR). The Retail ID 50769 does not exist here.
-- Rebirth (20484, level 20) is the battle res and covers both when Revive is
-- not known.
-- No warlock: Vanilla Soulstone is cast on a LIVING player (self-res later),
-- not on a corpse. Add it only if Forever is confirmed to change that.
VB.FOREVER_REZ_SPELLS = {
    PRIEST  = { normal = { 2006 } },                       -- Resurrection
    PALADIN = { normal = { 7328 } },                       -- Redemption
    SHAMAN  = { normal = { 2008 } },                       -- Ancestral Spirit
    DRUID   = { normal = { 437138 }, combat = { 20484 } }, -- Revive (Forever), Rebirth
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
    974,   -- Earth Shield
    33763, -- Lifebloom (BCC only; ignored where the ID does not exist)
    33076, -- Prayer of Mending (BCC only)
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
    return VB:IsSpellKnownByID(id)
end

-- Build VB.healBuffNames from the base IDs above. Despite the name this also
-- runs on any other ranked-spellbook client (see VB.hasRankedSpellbook): the
-- base IDs are old rank-1 IDs that stayed stable from Vanilla through TBC.
function VB:BuildForeverHealBuffNames()
    if not VB.hasRankedSpellbook then return end
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
    for _, group in ipairs({ VB.unitButtons, VB.tankButtons, VB.petButtons, VB.targetButtons }) do
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

    if VB.hasRankedSpellbook and (next(VB.healBuffNames) or next(VB.customBuffNames)) then
        local found = 0
        ForEachKnownSpell(function(spellID, name)
            name = name or VB:GetSpellName(spellID)
            if name and (VB.healBuffNames[name] or VB.customBuffNames[name]) then
                ids[spellID] = true
                found = found + 1
            end
        end)
        -- Zero matching ranks is valid: a character may not know any of the
        -- built-in healing/protection buffs yet. Keep the base and custom IDs
        -- collected above; disabling the filter would display every own buff.
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
-- Returns a { [typeID] = true } set, or nil on Retail.
function VB:GetForeverDispelTypes()
    -- Forever and Burning Crusade Classic: no specs, dispels come from the spellbook
    if not (VB.isForever or (VB.tocVersion > 0 and VB.tocVersion < 100000)) then return nil end

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

-- /vb dispeldebug: what the addon believes about dispels on this client
function VB:DispelDebug()
    VB:Print("=== Dispel debug ===")
    VB:Print(("  toc=%s forever=%s class=%s"):format(tostring(VB.tocVersion),
        tostring(VB.isForever), tostring(VB.playerClass)))
    VB:Print("  GetAuraDispelTypeColor: "
        .. tostring(C_UnitAuras ~= nil and C_UnitAuras.GetAuraDispelTypeColor ~= nil)
        .. "  CreateColorCurve: " .. tostring(C_CurveUtil ~= nil))

    local names = { [1] = "Magic", [2] = "Curse", [3] = "Disease", [4] = "Poison" }
    local ids = {}
    for id in pairs(VB.FOREVER_DISPEL_SPELLS) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if spellKnown(id) then
            VB:Print(("  known: %s (%d) -> %s"):format(VB:GetSpellName(id) or "?", id,
                names[VB.FOREVER_DISPEL_SPELLS[id]] or "?"))
        end
    end

    local can = VB:GetForeverDispelTypes()
    if can then
        local list = {}
        for t = 1, 4 do if can[t] then list[#list + 1] = names[t] end end
        VB:Print("  can dispel: " .. (#list > 0 and table.concat(list, ", ") or "nothing"))
    else
        VB:Print("  can dispel: (Retail table, not spellbook)")
    end

    if VB.DispelCurveDebug and UnitExists("player") then VB:DispelCurveDebug("player") end

    local units = { "player", "target", "party1", "party2", "party3", "party4" }
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            for _, d in ipairs(VB:GetUnitDebuffs(unit, 40)) do
                local ok, line = pcall(function()
                    return ("  %s: %s type=%s id=%s"):format(unit, tostring(d.name),
                        tostring(d.dispelType), tostring(d.spellID))
                end)
                VB:Print(ok and line or ("  " .. unit .. ": (secret aura)"))
            end
        end
    end
end

-- /vb healdebug: watch incoming-heal data for 20 seconds. Cast a heal (or have
-- someone heal you) while it runs. Prints only when a value changes.
function VB:HealDebug()
    if VB._healDebugTicker then VB._healDebugTicker:Cancel() end
    VB:Print("=== Heal debug (20s) - cast a heal now ===")
    VB:Print(("  toc=%s forever=%s"):format(tostring(VB.tocVersion), tostring(VB.isForever)))
    VB:Print("  UnitGetIncomingHeals: " .. tostring(UnitGetIncomingHeals ~= nil)
        .. "  UnitGetTotalAbsorbs: " .. tostring(UnitGetTotalAbsorbs ~= nil)
        .. "  HealComm lib: " .. tostring(LibStub ~= nil and LibStub("LibHealComm-4.0", true) ~= nil))

    -- Anything secret is reported as a word: formatting or comparing it would error
    local function safe(v)
        if issecretvalue and issecretvalue(v) then return "secret" end
        if type(v) == "number" then return ("%.0f"):format(v) end
        return tostring(v)
    end

    local last = {}
    local units = { "player", "target", "party1", "party2", "party3", "party4" }
    local ticks = 0
    VB._healDebugTicker = C_Timer.NewTicker(0.25, function(t)
        ticks = ticks + 1
        for _, unit in ipairs(units) do
            if UnitExists(unit) and UnitGetIncomingHeals then
                local ok, val = pcall(UnitGetIncomingHeals, unit)
                local secret = ok and issecretvalue and issecretvalue(val) or false
                local text
                if not ok then text = "error"
                elseif secret then text = "secret"
                else text = tostring(val) end
                local btn = VB.unitButtons and VB.unitButtons[unit]
                local bar = btn and btn.healthBar and btn.healthBar.healPrediction
                text = text .. " bar=" .. tostring(bar and bar:IsShown() or false)
                if bar then
                    local okv, v = pcall(bar.GetValue, bar)
                    text = text .. " w=" .. safe(bar:GetWidth())
                        .. " h=" .. safe(bar:GetHeight())
                        .. " visible=" .. safe(bar:IsVisible())
                        .. " value=" .. (okv and safe(v) or "err")
                end
                if last[unit] ~= text then
                    last[unit] = text
                    VB:Print(("  %s: incoming=%s"):format(unit, text))
                end
            end
        end
        if ticks >= 80 then
            t:Cancel()
            VB._healDebugTicker = nil
            VB:Print("=== Heal debug done ===")
        end
    end)
end
