# VoidBox 2.8.0: recommended auras per class and spec

Date: 2026-10-24. Status: design approved in conversation; awaiting spec review.

## Goal

The Auras tab gets a "Recommended auras" button. It opens a window listing a
starter set of screen auras for the player's class, grouped by spec, so a
newcomer gets useful auras without building each one by hand (the main thing
WeakAuras users miss).

2.8.0 covers the **druid** and the **mage**, on the Classic-ruleset clients:
WoW Forever, Classic Era / Hardcore and TBC Anniversary.

Out of scope for 2.8.0: other classes, Retail (different spells and specs),
auras matching "one of several spells" (Mark of the Wild or Gift of the Wild),
cooldown / power / combo point tracking (the "probes" planned for 2.9.0).

## Units

### `Templates.lua` (new: data and logic, no UI)

Loaded after `Auras.lua` in `VoidBox.toc`. Holds `VB.AURA_TEMPLATES`, keyed by
class token, plus the functions below (spec detection, availability, adding):

```lua
VB.AURA_TEMPLATES.DRUID = {
    common = { <item>, ... },                       -- "All specs" tab
    specs = {                                        -- index = talent tree
        { key = "BALANCE",     items = { ... } },
        { key = "FERAL",       groups = { { key = "CAT", items = { ... } },
                                          { key = "BEAR", items = { ... } } } },
        { key = "RESTORATION", items = { ... } },
    },
}
```

A spec has either `items` or `groups` (sub-headings). `key` values are locale
keys (`TEMPLATE_SPEC_<KEY>`, `TEMPLATE_GROUP_<KEY>`).

An **item** holds only what differs from `VB:NewScreenAura`'s defaults:

| field | meaning |
|---|---|
| `spell` | spell ID (rank 1) the aura watches, or the usable spell |
| `requires` | spell that must be known for the aura to make sense (a talent granting a proc); defaults to `spell` |
| `source` | `"spell"` (default) or `"usable"` |
| `show` | `"present"` (default), `"missing"`, `"expiring"` |
| `unit`, `kind`, `mine` | as in a screen aura entry |
| `combat`, `group`, `hostileTarget`, `inRange` | conditions, as in an entry |
| `form` | symbolic: `"cat"`, `"bear"`; resolved when the aura is added |
| `display`, `countdown`, `stacks`, `glow`, `sound`, `color` | look |

Forms resolve to spell IDs at add time: `cat` = 768; `bear` = 9634 (Dire Bear
Form) if known, else 5487 (Bear Form). An item whose form cannot be resolved is
added without a form condition.

### `VB:GetTalentSpec()` (new, in `Templates.lua`)

Returns the index of the talent tree with the most points spent, or `nil`
when no points are spent or the client does not answer. Reads
`GetNumTalentTabs` / `GetTalentTabInfo` under `pcall`. Two return layouts
exist: the current one starts with a numeric tab ID
(`id, name, description, icon, pointsSpent, ...`), the old one with the name
(`name, icon, pointsSpent, ...`). Points spent = 5th return when the 1st is a
number, else the 3rd. Anything that is not a non-negative number counts as 0.
A tie between trees returns the lowest index.
On WoW Forever specialization APIs are gone (`Forever.lua`); whether talent
trees answer is unknown and checked with `/vb spec`.

`/vb spec` (new slash subcommand) prints each tree's name and points and the
detected spec.

### Availability of an item

Computed when the window opens:

1. `VB:GetSpellName(item.spell)` is nil: the spell does not exist on this
   client (Molten Armor before TBC). The item is **not listed**.
2. The required spell is not known: listed, greyed, marked "not learned
   yet", checked like an available item (rule 4): the aura comes on once the
   spell is learned. (Changed after the first in-game test, 2026-10-24: a
   low-level character's spec tab was all unchecked.) Known = `VB:IsSpellKnownByID`,
   else (ranked spellbooks) any known spell with the same name
   (`VB:ForEachKnownSpell`).
3. An entry already in `VB.screenAuras` has the same `spellID`, `source`,
   `show` and `unit`: listed, greyed, unchecked, marked "already added".
4. Otherwise (and for rule 2): checked if the item is in "All specs" or in
   the detected spec's tab; unchecked elsewhere.

### Adding

For each checked item, across all tabs, in list order:
`VB:NewScreenAura(item.spell)`, then the item's fields copied over, `form`
resolved, then the same cleaning the importer applies (`CleanAura` in
`Share.lua`, exposed as `VB:CleanScreenAura`). Entries are appended to
`VB.screenAuras`, laid out in one row centred on x = 0 at the default height
(y = 150), `size + 8` apart. Then `VB:RebuildScreenAuras()`, the Auras tab
refreshes with the first new aura selected, and the chat says "N auras added".

### The window (`TemplatesWindow.lua`, new)

Loaded after `Templates.lua` and `Share.lua`. `Templates.lua` keeps the data,
`VB:GetTalentSpec`, the availability rules and the adding; the window only
displays them and calls `VB:AddTemplateAuras(items)`. `Config.lua` only gains
the button that opens it (`VB:ShowTemplatesWindow()`).

- Button "Recommended auras" in the Auras tab, next to Add. Disabled with a
  tooltip ("No recommended auras for this class yet") when
  `VB.AURA_TEMPLATES[VB.playerClass]` is nil.
- Window in the Share dialogs' style: `MakeDialog` and `MakeButton` move from
  `Share.lua` to shared helpers (`VB:MakeDialog`, `VB:MakeButton`).
- Tabs: All specs, then one per spec, opening on the detected spec (first
  spec when none).
- Each tab: a scrolling list of check rows, sub-headings where a spec has
  groups. Row = spell icon, then a label built from the localized spell name
  and the mode ("Rake - missing on target"); greyed rows carry their reason. A
  tooltip lists the settings (form, in combat, sound...).
- Checks persist across tabs. Footer: "Add (N)" with the count over all tabs,
  and Cancel.

### Locales

Spell names come from the client. New strings (button, window title, tab and
group names, mode phrases, "not learned yet", "already added", "N auras
added", `/vb spec` output) in `Locales.lua`: English default and French, like
the rest of the Auras tab (other locales fall back to English).

## Content

IDs are rank 1, Classic ruleset. "TBC" = exists only from TBC on (hidden
elsewhere). Unless stated: unit = player, kind = HELPFUL, mine = true.

### Druid (trees: 1 Balance, 2 Feral Combat, 3 Restoration)

All specs:
- Clearcasting 16870, present, glow + sound; requires Omen of Clarity 16864.
- Mark of the Wild 1126, missing, out of combat, any caster.
- Thorns 467, missing, out of combat, any caster.

Feral Combat, Cat:
- Shred 5221, usable, form cat.
- Rake 1822, missing on target, HARMFUL mine, in combat, hostile target, form cat.
- Rip 1079, present on target, HARMFUL mine, bar with countdown, form cat.
- Tiger's Fury 5217, present, countdown, form cat.

Feral Combat, Bear:
- Demoralizing Roar 99, missing on target, HARMFUL mine, in combat, hostile target, form bear.
- Faerie Fire (Feral) 16857, missing on target, HARMFUL, in combat, hostile target, form bear.

Balance:
- Moonfire 8921, missing on target, HARMFUL mine, in combat, hostile target.
- Insect Swarm 5570, missing on target, HARMFUL mine, in combat, hostile target.
- Faerie Fire 770, missing on target, HARMFUL, in combat, hostile target.

Restoration:
- Nature's Swiftness 17116, present, glow.
- Innervate 29166, present, countdown, any caster.

### Mage (trees: 1 Arcane, 2 Fire, 3 Frost)

All specs:
- Arcane Intellect 1459, missing, out of combat, any caster.
- Clearcasting 12536, present, glow + sound; requires Arcane Concentration 11213.

Arcane:
- Mage Armor 6117, missing, out of combat.
- Arcane Power 12042, present, countdown.
- Presence of Mind 12043, present, glow.
- Arcane Blast 36032 (TBC), present, HARMFUL on the player, any caster, stacks; requires Arcane Blast 30451.

Fire:
- Molten Armor 30482 (TBC), missing, out of combat.
- Combustion 11129, present, stacks.
- Fire Vulnerability 22959, present on target, HARMFUL, any caster (mine = false), bar with countdown and stacks; requires Improved Scorch 11095.

Frost:
- Ice Armor 7302, missing, out of combat.
- Icy Veins 12472 (TBC), present, countdown.
- Ice Barrier 11426, missing, in combat.
- Winter's Chill 12579, present on target, HARMFUL, any caster, stacks; requires Winter's Chill talent 11180.

Known limits, stated in the tooltips where they apply:
- Arcane Intellect / Mark of the Wild show as missing under the group
  version (Arcane Brilliance, Gift of the Wild).
- On WoW Forever a debuff on the player picked by spell only shows out of
  combat (Blizzard restriction): Arcane Blast does not exist there anyway.

## Error handling

- Every client query (talents, spell names, known spells, forms) is guarded;
  a failure degrades to "not detected" / "not listed" / "no form", never to an
  error in the window.
- Adding goes through the importer's cleaning, so a wrong template field can
  not produce an entry the aura code rejects.

## Testing

Manual, in game (no test harness in this repo):

1. TBC Anniversary, mage: `/vb spec`; the window opens on the right spec;
   TBC-only items listed; unlearned talents greyed; add a set; each aura shows
   in its situation (Arcane Blast stacks, Fire Vulnerability on a target...).
2. Classic Era, druid Wondersog: TBC-only items absent; forms resolved (Bear vs
   Dire Bear); the Feral cat auras only in Cat Form.
3. WoW Forever when playable: `/vb spec` result; auras in combat.
4. Regressions: a class without templates (button disabled); "already added"
   after adding twice; export / import of a template-made aura; Retail loads
   with the button disabled.

## Packaging

`docs/` is added to `.pkgmeta`'s ignore list so the spec does not ship.

## Changes after the first in-game test (2026-10-24, TBC mage)

- Buffs someone else can give you (Arcane Intellect, Mark of the Wild,
  Thorns, Innervate) match any caster: with "mine" the aura showed as missing
  under another mage's Arcane Intellect.
- Every template-made aura carries `needs` (its `requires` or its spell): it
  stays hidden until that spell is known (`NeedsOK` in `Auras.lua`, cached,
  cleared when the spellbook changes). Kept by the importer's cleaning. Auras
  made by hand have no `needs`.
- Unlearned items are checked by default like the others (see Availability).
- "One spell among several" (moved into scope after the test: a level-20
  mage's armor is Frost Armor, learned at level 1, which no item covered).
  An entry may carry `also`, a list of other spell IDs that count as the same
  aura; `Auras.lua` `ResolveIDs` accepts every rank of every one of them, by
  ID and by name. Items list theirs best first; the aura is made on the first
  one known (`VB:TemplatePrimary`). The mage's three spec armors became one
  "All specs" item (Molten, Mage, Ice, Frost Armor); Arcane Intellect also
  accepts Arcane Brilliance, Mark of the Wild Gift of the Wild (their
  GROUP_BUFF notes are gone).

## Screen groups (added 2026-10-24 after the test, approved in conversation)

- `VoidBoxDB.classAuraGroups[class]` = `VB.screenAuraGroups`: key ->
  `{ name, x, y, scale }`, x / y = the group's centre in UIParent units,
  scale 0.5-2.
- `entry.screenGroup` = a group key (`entry.group` is the existing "in a
  group / raid" condition). A grouped entry's x / y are relative to the
  group's centre in the group's units; its holder is a child of the group
  frame, so the frame's scale sizes it.
- While the Auras tab is open, a handle above each group (name and %) moves
  it by dragging and scales it with the wheel (steps of 5-10%). Dragging an
  aura moves it inside its group.
- Editor: a "Group: <name>" button next to Duplicate / Share opens a menu:
  none, every group, New group... (name prompt; the group starts where the
  aura is). Changing group keeps the aura where it is on screen. No size
  slider (the editor has no room left): the wheel on the handle does it.
- Groups no aura uses are dropped on rebuild; an aura naming a missing group
  leaves it.
- Recommended auras added together become a new group named "<class> -
  <detected spec>" at (0, 150).
- Export of all auras carries `auraGroups`; sharing one aura exports it
  ungrouped at its absolute position. Import replaces the groups with the
  text's (all auras) or leaves them (one aura).
- Static layout: on clients where the game draws the auras (Forever,
  Retail) the addon cannot know which are shown, so no gap closing.

## All nine Classic classes (2026-10-24)

- Lists for warrior, paladin, hunter, rogue, priest, shaman and warlock were
  approved in conversation and added to `Templates.lua`.
- Every ID was checked against wago.tools' SpellName tables for Classic Era
  1.15.9.70003, TBC Anniversary 2.5.6.70006 and WoW Forever 1.60.1.70532.
  Findings handled in the data: Icy Veins 12472 is Cold Snap on Era and
  Forever (`tbc = true`); Sweeping Strikes and Death Wish swap IDs between
  Era/Forever and TBC (`spell = { era = ..., tbc = ... }`); Forever renames
  some spells (Bane of Agony, Salvation, Shadow Weaving) under the same IDs.
- "Any of these" items carry a `label` (Any armor, Any blessing, Any aura,
  Any seal, Any aspect, Any shield) used by the window.
- Warrior stances are forms (battle 2457, defensive 71, berserker 2458).
- `VB:GetAuraTemplates()` returns nil on Retail (toc >= 100000): its spells
  and specs differ; Retail lists are the next step.

## Retail (2026-10-24, lists approved in conversation)

- `VB.AURA_TEMPLATES_RETAIL[class]`, same shape; specs in GetSpecialization's
  order; `VB:GetTalentSpec()` returns `VB:GetPlayerSpecIndex()` on Retail.
- Retail auras often have an ID of their own (Moonfire's debuff 164812, not
  8921): `requires` names the castable spell. Procs no single spell grants
  carry `always = true`: never shown as not learned, no `needs`.
- Left out: debuffs on the player picked by spell (Stagger), which Midnight
  hides in combat. Hunter's Aspect of the Cheetah shows while active.
- IDs checked against 12.1.5.70575; to confirm in game: Unstable Affliction
  30108, Festering Wound 194311 (their 11.x IDs are gone).
