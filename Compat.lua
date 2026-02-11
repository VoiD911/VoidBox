--[[
    VoidBox - Compatibility Layer for WoW 12.0+ (Midnight)
    
    Wraps deprecated APIs with their modern replacements.
    This file MUST be loaded first.
]]

local addonName, VB = ...

-------------------------------------------------
-- Spell Info Wrapper
-- GetSpellInfo() deprecated since 11.0, removed in 12.0
-- Replaced by C_Spell.GetSpellInfo() which returns a table
-------------------------------------------------
function VB:GetSpellInfo(spellID)
    if not spellID then return nil, nil, nil end
    
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
        end
        return nil
    end
    
    -- Fallback for older clients (should not happen in 12.0)
    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    
    return nil
end

-- Get just the spell name (most common use case)
function VB:GetSpellName(spellID)
    if not spellID then return nil end
    
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    
    local name = VB:GetSpellInfo(spellID)
    return name
end

-- Get just the spell icon
function VB:GetSpellIcon(spellID)
    if not spellID then return nil end
    
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    
    local _, icon = VB:GetSpellInfo(spellID)
    return icon
end

-------------------------------------------------
-- Cursor Info Wrapper
-- GetCursorInfo for spells returns: "spell", spellIndex, bookType, spellID
-- The real spellID is the 4th return value (id3)
-------------------------------------------------
function VB:GetCursorSpell()
    local cursorType, id1, id2, id3 = GetCursorInfo()
    
    if cursorType == "spell" then
        -- id1 = spellIndex in spellbook, id3 = actual spellID
        local spellID = id3 or id1
        local spellName = VB:GetSpellName(spellID)
        local spellIcon = VB:GetSpellIcon(spellID)
        return spellID, spellName, spellIcon
    end
    
    return nil
end

-------------------------------------------------
-- Aura Wrapper
-- UnitDebuff/UnitBuff deprecated since 11.0
-- Use C_UnitAuras in 12.0+
-------------------------------------------------
function VB:GetUnitDebuffs(unit, maxCount)
    local debuffs = {}
    maxCount = maxCount or 40
    
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, maxCount do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
            if not aura then break end
            table.insert(debuffs, {
                name = aura.name,
                icon = aura.icon,
                count = aura.applications or 0,
                dispelType = aura.dispelName,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
                spellID = aura.spellId,
                isStealable = aura.isStealable,
            })
        end
    elseif UnitDebuff then
        for i = 1, maxCount do
            local name, icon, count, dispelType, duration, expirationTime, _, _, _, spellID = UnitDebuff(unit, i)
            if not name then break end
            table.insert(debuffs, {
                name = name,
                icon = icon,
                count = count or 0,
                dispelType = dispelType,
                duration = duration,
                expirationTime = expirationTime,
                spellID = spellID,
            })
        end
    end
    
    return debuffs
end

-------------------------------------------------
-- Get unit buffs cast by player (for HOT/buff tracking)
-------------------------------------------------
function VB:GetUnitBuffsByPlayer(unit, maxCount)
    local buffs = {}
    maxCount = maxCount or 40
    local playerGUID = UnitGUID("player")
    
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, maxCount do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then break end
            if aura.sourceUnit and UnitGUID(aura.sourceUnit) == playerGUID then
                table.insert(buffs, {
                    name = aura.name,
                    icon = aura.icon,
                    count = aura.applications or 0,
                    duration = aura.duration,
                    expirationTime = aura.expirationTime,
                    spellID = aura.spellId,
                })
            end
        end
    elseif UnitBuff then
        for i = 1, maxCount do
            local name, icon, count, _, duration, expirationTime, source, _, _, spellID = UnitBuff(unit, i)
            if not name then break end
            if source == "player" then
                table.insert(buffs, {
                    name = name,
                    icon = icon,
                    count = count or 0,
                    duration = duration,
                    expirationTime = expirationTime,
                    spellID = spellID,
                })
            end
        end
    end
    
    return buffs
end

-------------------------------------------------
-- Secret Value → Real Number (WoW 12.0+)
-- string.format("%d", secretValue) produces a displayable string
-- but tonumber() and string.match() fail on it (secret string).
-- string.byte() returns real ASCII codes we can use to rebuild
-- a real Lua number digit by digit.
-------------------------------------------------
function VB:SecretStringToNumber(secretStr)
    if not secretStr then return nil end
    
    -- Try normal tonumber first (works outside of secret context)
    local direct = tonumber(secretStr)
    if direct then return direct end
    
    -- Extract digits via string.byte
    local result = 0
    local negative = false
    local len = #secretStr
    
    if len == 0 then return nil end
    
    for i = 1, len do
        local byte = string.byte(secretStr, i)
        if byte == 45 then -- '-' minus sign
            negative = true
        elseif byte >= 48 and byte <= 57 then -- '0'-'9'
            result = result * 10 + (byte - 48)
        end
        -- skip any other characters
    end
    
    if negative then result = -result end
    return result
end

-------------------------------------------------
-- AbbreviateNumbers Wrapper
-- In 12.0+, AbbreviateNumbers may return secret values
-------------------------------------------------
function VB:AbbreviateNumber(value)
    if type(value) ~= "number" then return tostring(value) end
    
    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    end
    
    return tostring(math.floor(value))
end

-------------------------------------------------
-- Heal Buff Detection (HOTs + Shields)
-- Spell IDs de tous les HOTs et boucliers de heal connus
-- Toutes classes confondues, toutes sources
-------------------------------------------------
local healBuffSpellIDs = {
    -- Druide (Restoration / all specs)
    [774]    = true,  -- Rejuvenation / Récupération
    [155777] = true,  -- Rejuvenation (Germination)
    [8936]   = true,  -- Regrowth / Rétablissement (HOT part)
    [33763]  = true,  -- Lifebloom / Fleur de vie
    [188550] = true,  -- Lifebloom (talent)
    [48438]  = true,  -- Wild Growth / Croissance sauvage
    [102342] = true,  -- Ironbark / Ecorcefer (damage reduction)
    [102351] = true,  -- Cenarion Ward / Gardien cénarien
    [200389] = true,  -- Cultivation
    [207386] = true,  -- Spring Blossoms
    [391891] = true,  -- Adaptive Swarm (heal)
    [382550] = true,  -- Grove Guardians HOT
    
    -- Prêtre (Holy / Discipline)
    [139]    = true,  -- Renew / Rénovation
    [17]     = true,  -- Power Word: Shield / Mot de pouvoir : Bouclier
    [41635]  = true,  -- Prayer of Mending / Prière de guérison
    [194384] = true,  -- Atonement / Expiation
    [77489]  = true,  -- Echo of Light (Mastery Holy)
    [47788]  = true,  -- Guardian Spirit / Esprit gardien
    [33206]  = true,  -- Pain Suppression / Suppression de la douleur
    [81782]  = true,  -- Power Word: Barrier
    [372847] = true,  -- Crystalline Reflection shield
    [271466] = true,  -- Luminous Barrier (Disc talent)
    [152118] = true,  -- Clarity of Will (absorb)
    [47753]  = true,  -- Divine Aegis (Disc mastery absorb)
    
    -- Paladin (Holy)
    [53563]  = true,  -- Beacon of Light / Illumination
    [156910] = true,  -- Beacon of Faith
    [200025] = true,  -- Beacon of Virtue
    [223306] = true,  -- Bestow Faith / Don de foi
    [287280] = true,  -- Glimmer of Light
    [1022]   = true,  -- Blessing of Protection
    [6940]   = true,  -- Blessing of Sacrifice
    [388013] = true,  -- Barrier of Faith
    
    -- Chaman (Restoration)
    [61295]  = true,  -- Riptide / Remous
    [382024] = true,  -- Earthliving Weapon HOT
    [974]    = true,  -- Earth Shield / Bouclier de terre
    [383648] = true,  -- Earth Shield (talent)
    [201633] = true,  -- Earthen Wall Totem absorb
    [207400] = true,  -- Ancestral Vigor
    [382311] = true,  -- Tidecaller's Guard
    [114893] = true,  -- Stone Bulwark Totem absorb
    [383018] = true,  -- Stoneskin Totem absorb
    
    -- Moine (Mistweaver)
    [119611] = true,  -- Renewing Mist / Brume de renouveau
    [124682] = true,  -- Enveloping Mist / Brume enveloppante
    [116849] = true,  -- Life Cocoon / Cocon de vie (absorb)
    [191840] = true,  -- Essence Font HOT
    [325209] = true,  -- Enveloping Breath
    [343655] = true,  -- Chi Harmony
    
    -- Evoker (Preservation)
    [355941] = true,  -- Dream Breath HOT
    [376788] = true,  -- Dream Breath echo
    [363502] = true,  -- Dream Flight HOT
    [373267] = true,  -- Lifebind
    [364343] = true,  -- Echo (Preservation)
    [366155] = true,  -- Reversion
    [367364] = true,  -- Reversion (echo)
    [378001] = true,  -- Dream Projection
}

function VB:UnitHasHealBuff(unit)
    if not unit or not UnitExists(unit) then return false end
    
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then break end
            if aura.spellId and healBuffSpellIDs[aura.spellId] then
                return true
            end
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
            if not name then break end
            if spellID and healBuffSpellIDs[spellID] then
                return true
            end
        end
    end
    
    return false
end
