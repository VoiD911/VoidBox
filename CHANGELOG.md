# VoidBox

## v1.10.2 (2026-09-20)

- **Fix: HoT/shield icons appeared only in combat on Forever**
    - The out-of-combat row filtered auras against the Retail spell ID table.
      In Vanilla every rank has its own ID and only rank 1 matches Retail, so a
      level-60 Rejuvenation or Renew was skipped; the in-combat row has no ID
      filter (it uses the server-side RAID_IN_COMBAT filter), hence icons that
      showed in combat and vanished out of it.
    - ID and name matching are now one shared `VB:IsHealBuff()` used by both the
      aura row and `UnitHasHealBuff`, instead of only the latter
    - The HoT name table is rebuilt at PLAYER_ENTERING_WORLD too, in case spell
      data was still uncached at login

## v1.10.1 (2026-09-20)

- **Fix: "Auras cannot be accessed when secret while tainted by 'VoidBox'"**
    - Once the aura system goes secret, `C_UnitAuras.GetAuraDataByIndex` raises
      instead of returning nil, which killed `UpdateAuras` on every `UNIT_AURA`
    - All aura reads now go through a single `VB:GetAuras()` helper built on
      `C_UnitAuras.GetUnitAuras` (always callable; only the fields turn secret),
      with a pcall-guarded index walk as fallback for older clients
    - Added `VB:AurasAreSecret()` (`C_Secrets.ShouldAurasBeSecret`) and
      `VB:HasAuraAPI()`
    - HARMFUL auras are read once per refresh instead of twice

## v1.10.0 (2026-09-20)

- **World of Warcraft: Forever support** (project "Camelot", 1.60.x, interface 16001)
    - TOC now declares `## Interface: 16001, 120000` so one package loads on both
      Forever and Retail/Midnight
    - New `Forever.lua` compatibility module, inert on Retail
    - `GetSpecialization` / `GetSpecializationInfo` are gone on Forever; spec
      lookups now go through `C_SpecializationInfo` with a nil-safe shim
    - Every `RegisterEvent` is filtered through `C_EventUtils.IsEventValid`
      (an unknown event aborts the whole file on Forever)
    - Dispel highlighting: Vanilla has no specs, so dispel schools are read from
      the spellbook (Dispel Magic, Cleanse, Purify, Remove Curse, Abolish Poison, ...)
    - Range check uses Vanilla rank-1 spell IDs per class, filtered through
      `C_Spell.DoesSpellExist`
    - HoT/shield detection matches by localized spell name so every Vanilla rank
      of Rejuvenation / Regrowth / Renew / Power Word: Shield is recognised
    - Click-casting: when `loadstring_untainted` is missing, secure snippets
      cannot compile. Keyboard bindings fall back to global override bindings on
      `@mouseover` proxy buttons; mouse click-casting is unaffected, scroll-wheel
      bindings are disabled on that path

## [v1.7.3](https://github.com/VoiD911/VoidBox/tree/v1.7.3) (2026-03-24)
[Full Changelog](https://github.com/VoiD911/VoidBox/commits/v1.7.3) [Previous Releases](https://github.com/VoiD911/VoidBox/releases)

- v1.7.3 - Class/spec-specific dispel highlight filtering  
    - Dispel border now only highlights debuffs YOUR class/spec can dispel  
    - Dynamic ColorCurve rebuilt on login and spec change  
    - Priest: Magic + Disease (all specs)  
    - Druid: Curse + Poison (all), +Magic (Resto)  
    - Paladin: Disease + Poison (all), +Magic (Holy)  
    - Shaman: Curse (all), +Magic (Resto)  
    - Monk: Disease + Poison (all), +Magic (Mistweaver)  
    - Evoker: Poison (all), +Magic (Preservation)  
    - Mage: Curse only  
    - Non-dispel classes: no border shown  
    - Debuff icons still show ALL debuffs (bleeds, etc.)  
    - No new config option needed - works automatically  
