# VoidBox

## v1.16.0 (2026-09-24)

- **Mana bar height slider** (Options tab, 2-12, default 4), next to the "Show
  mana bar" checkbox. Requested on CurseForge. The `powerBarHeight` setting
  had existed but the layout used a hard-coded 4px and never read it.
    - A taller bar grows the frame instead of shrinking the health bar: the
      aura rows are laid out from the top of the health bar, and the HoT row
      would otherwise overflow onto the mana bar. At the default height frames
      are unchanged.
    - Core's grid layouts (group, tank, pet) recomputed the frame size on their
      own; they now share `VB:GetFrameSize()` with the buttons, so taller
      frames do not overlap.
    - Localized in all 11 supported locales.

## v1.15.0 (2026-09-23)

- **Options to hide names and/or health %** (Options tab). Requested on
  CurseForge. The `showName`/`showHealth` settings had existed for a long time
  but were wired to nothing: no checkbox, and rendering never read them.
    - Hiding health % keeps "Dead" and "Offline", which are states, not health
    - With health % hidden, names get its space and are truncated less
    - Applies to group, tank and pet frames at once
    - Localized in all 11 supported locales
- Config window is 60px taller: the Options tab was already full on Forever.

## v1.14.1 (2026-09-23)

- **Fix: pet frames kept old click-cast bindings after they were changed.**
  Pet buttons only received their bindings when created, and
  `ApplyClickCastingsToAllFrames` walked group and tank buttons only. Replacing
  a macro binding with a spell left the pet frame on the old macro until a
  `/reload` - e.g. a targetless `/use Heal` that went to the player through
  auto self-cast. Pet buttons are now updated with the others.
- The debuff/HoT/dispel display toggles now refresh pet frames too.

## v1.14.0 (2026-09-23)

- **Fix: Alt+Left (and any non-default combo) bound to Target did nothing.**
  Blizzard's `SecureUnitButton_OnClick` (Retail 10.0+, Forever) drops a
  `type=target`, `menu` or `togglemenu` click unless its own click-binding
  profile has a matching interaction on that exact button and modifiers. The
  default profile only has plain Left (target) and plain Right (menu), so every
  other Target binding was silently discarded - on mouse and on modified
  keyboard keys alike. Target now goes through `/target [@mouseover,exists]`
  on anything but plain Left; macros are not subject to that check. Menu on
  non-default combos is still dropped (no macro can open the unit menu).
- **Mouse wheel bindings on Forever, opt-in** (Options tab, off by default).
  Without secure snippets the wheel cannot be bound on hover, only globally.
  The global binding goes through a gate macro: a `/stopmacro` line that stops
  unless the unit under the cursor is a living friendly unit, then the action
  itself. When it stops, the swallowed camera zoom is replayed (plain wheel
  only; modified wheels have no default action).
    - Filter is `[@mouseover,help,nodead]`, not `[party]`/`[raid]`: in-game
      probing (`/vb debugwheel`) showed party and raid evaluate false on
      Forever in combat even over a group member, which stopped every wheel
      cast in combat. Trade-off: friendly players and NPCs outside the group,
      and your own 3D model, also take the cast when under the cursor.
    - The action is written into the gate rather than `/click`ing another
      macro button: a macro started from inside a macro does not run, which
      silently dropped a first version's Target. Pinned ranks `/click` a
      `type=spell` proxy, which is not a macro.
    - The zoom is replayed from an addon hook, not from a `/run` line: since
      10.1 any `/run` in a macro triggers Blizzard's "allow custom scripts"
      warning. The gate's last line `/click`s a marker button, so the hook
      knows the action ran from the secure macro engine itself. Re-evaluating
      the conditions from addon code with `SecureCmdOptionParse` disagreed in
      combat, where unit identity is hidden from tainted code, and zoomed on
      top of the cast.
    - Menu has no macro form, so a wheel bound to Menu stays unbound
- The Forever login notice now says wheel bindings are off unless enabled.
  Localized in all 11 supported locales.

## v1.13.0 (2026-09-22)

- **Tracked buffs**: pick any spell to watch in the HoT row, e.g. a druid
  tracking Thorns. Requested on CurseForge.
    - Drop a spell from the spellbook into the new list in the **Auras** tab
      (formerly "Debuffs"; the Sated/Exhaustion option is still there).
    - Shown in the HoT row alongside the built-in heals, and like them only
      when you cast it (server-side PLAYER filter). The row holds 4 icons,
      shared between HoTs and tracked buffs.
    - Stored per class, like click-castings.
    - Every rank counts: the list stores the dropped spell, and on Forever
      each rank the character knows is collected from the spellbook by name.
      Dropping another rank of a spell already listed is ignored.
    - Works on both aura paths: AuraContainer (candidate spell IDs) and the
      legacy Lua path (`IsHealBuff`).
    - Localized in all 11 supported locales.

## v1.12.3 (2026-09-22)

- **`/vb debugmouseover` fixes and a ground-truth check.** A first pass only
  hooked frames that already existed when the command was toggled, so a party
  member's frame created afterwards went unwatched - explaining an
  inconclusive first test (UPDATE_MOUSEOVER_UNIT fired correctly for the
  player's own frame, with no data for anyone else). The hook now attaches
  once at frame creation instead, so it is never missed.
    - `CombatLogGetCurrentEventInfo` does not exist on Forever, so there is no
      combat log to read for "who actually got healed". Instead, shortly after
      every player cast, the tool re-reads HELPFUL|PLAYER auras on every
      displayed unit and reports which one now carries the spell just cast -
      the same mechanism VoidBox's own aura rows already rely on.
    - Fixed a filter-string mismatch (`"HELPFUL|PLAYER"` where `VB:GetAuras`
      expects space-separated `"HELPFUL PLAYER"`) caught before it shipped.

## v1.12.2 (2026-09-22)

- **Diagnostic for a reported bug: keyboard click-casting heals the player
  instead of the hovered party member.** The fallback keyboard path (needed
  because secure snippets are dead on Forever - see debugsnippets) casts via
  `/cast [@mouseover,exists,nodead][] <spell>`. The trailing `[]` is an
  unconditional fallback: if the client's "mouseover" unit token never
  resolves to the hovered VoidBox frame, the cast silently falls through to
  the current target, or self for a self-castable HoT - matching the report
  exactly ("works if I preselect the target").
    - Added `/vb debugmouseover`, which hooks OnEnter/OnLeave on VoidBox's own
      frames (read-only, does not touch secure state) alongside
      UPDATE_MOUSEOVER_UNIT, so whether the client's mouseover token actually
      follows the mouse onto our frames can be checked directly instead of
      guessed at.

## v1.12.1 (2026-09-21)

- **Downranking now covers keyboard bindings on Forever**
    - Secure snippets are confirmed dead on build 69913 by real execution
      (`_onattributechanged` and `SecureHandlerExecute` both fail inside
      RestrictedExecution with `loadstring_untainted` nil), so keyboard bindings
      use the global-override fallback, whose `@mouseover` macro only takes
      spell names and cannot express a rank.
    - A pinned rank on that path is now cast by ID through the proxy's `spell`
      attribute with `unit = "mouseover"`, the same CastSpellByID route mouse
      bindings use. Top-rank bindings keep the macro.
    - Trade-off for pinned ranks only: no fallback to the current target when
      nothing is hovered, and "auto-target on cast" does not apply.
    - Retail, and Forever once snippets work again, keep the hover-scoped proxy
      path unchanged; it already cast pinned ranks by ID.
- Corrected a misleading comment: setting a snippet attribute succeeds even on a
  build where snippets cannot run, so that `pcall` cannot detect a broken
  snippet engine. Detection stays the `loadstring_untainted` check.
- Added `/vb debugsnippets`, which makes the client actually execute two secure
  snippets. Run it after client patches: two passing lines mean the snippet
  path can come back.

## v1.12.0 (2026-09-21)

- **Downranking (Forever/Vanilla)**: drag a lower rank from the spellbook onto a
  click-cast slot and that exact rank is cast
    - Vanilla ranks are separate spells (Rejuvenation rank 1 is 774, rank 2 is
      1058). Bindings used to resolve the dragged spell ID to its bare name,
      which always casts the top rank, so the rank was captured then thrown away.
    - Only a rank lower than the best one known is pinned (`rankLocked`); it is
      cast by numeric ID through the secure template's CastSpellByID path, so no
      localized "(Rank N)" parsing is involved
    - A top-rank binding stays name-based and follows the player up when the
      next rank is learned
    - The config list, the frame tooltip and the drop zone show
      "Rejuvenation (Rank 1)" for pinned ranks and "Rejuvenation (Rank max)" for
      top-rank bindings. The word for "rank" comes from the client's own
      subtext; only "max" is translated.
    - Known limit: keyboard bindings on Forever go through @mouseover macro
      text, which only takes names, so pinned ranks are reliable on mouse
      bindings only
- **Spell inspector** (debug): `/vb spelllog` opens a copyable window logging
  every spell cast and every spell picked up on the cursor (ID, name, rank
  subtext, spellbook entry, link); `/vb spellranks <text>` lists every
  spellbook rank matching a name. Registers no events while closed.
- Localized the Forever login notice, both secure-snippet warnings and the
  "max" rank word in all 11 supported locales

## v1.11.0 (2026-09-20)

- **Aura rows now render through native AuraContainers, and work in combat again**
    - Addon code cannot read auras once they go secret: the index walk and
      `GetAuraSlots` raise, `GetUnitAuras` returns nothing, and per-spell
      lookups answer nil (healing HoTs report secrecy level 2). Drawing auras
      from data we read was a dead end on Forever.
    - `AuraContainer` (12.1+) is the sanctioned way round it: VoidBox declares a
      filter and styles the buttons the client hands it, and never touches the
      aura data. The client does the tracking, filtering, sorting and rendering.
    - Debuffs use `HARMFUL`; HoTs/shields use `HELPFUL|PLAYER`, so our own casts
      are separated server-side instead of reading `aura.sourceUnit`
    - Dispel colouring moves to `AddDispelTypeTexture` with VoidBox's existing
      allow-list as the colour map, and stack counts to `SetApplicationCount`
    - Cooldown sweeps keep ticking in combat, which the old path could not do
    - New `AuraContainers.lua`. Clients without the intrinsic frame type (Retail
      before 12.1) keep the previous Lua path unchanged.
    - The HoT row is narrowed to actual heals with `candidateFilters.includeSpellIDs`,
      fed by a spellbook walk that picks up every rank this character knows
      (a level-60 Rejuvenation is not spell 774). Unfiltered rather than empty
      if the walk finds nothing.
    - Rows are centred by shrink-wrapping each container to its frame count,
      which stays readable in combat even while the auras themselves are secret
    - Known change: the "+N other healers' HoTs" indicator and the frame-level
      dispel border are inactive on the container path; dispel now shows as a
      coloured border on the debuff icon itself.
- Added `/vb debugcontainer` to probe AuraContainer support on any client

## v1.10.3 (2026-09-20)

- **Fix: no HoT icon when the healed unit is in combat**
    - The HoT row picked its path from `InCombatLockdown()`, which is the
      PLAYER's combat state and says nothing about a given unit's auras. A unit
      already in combat has secret auras, so name/ID matching returned false for
      every aura and no icon was drawn, while the server-filtered path that
      would have worked was never taken.
    - Mine-vs-others is now split by the server-side `PLAYER` filter instead of
      comparing `UnitGUID(aura.sourceUnit)`, a field that turns secret in combat
    - `RAID`/`RAID_IN_COMBAT` are tried in turn, since each yields nothing in the
      other combat state
    - Identity filtering is applied only while the fields are readable; under
      secrecy the server filter is taken as-is rather than dropping every icon
- **Known limitation on Forever:** no aura can be read in combat. Enumeration
  raises (`GetAuraDataByIndex`, `GetAuraSlots`), `GetUnitAuras` returns nothing
  and targeted lookups answer nil - healing HoTs report secrecy level 2. Debuff
  icons, HoT icons and dispel highlighting are therefore empty in combat. A
  one-time chat notice now explains this instead of looking like a fault.
- Added `/vb debugauras [unit]`: probes GetUnitAuras per filter, raw
  GetAuraDataByIndex and GetAuraSlots side by side, with readability and
  `IsHealBuff` per aura. Defaults to a grouped ally rather than the target.

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
