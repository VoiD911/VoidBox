# VoidBox

Healer unit frames with click-casting, and WeakAuras-style screen auras, in one addon. Works in combat on WoW Forever.

One download for **Retail (Midnight)**, **WoW Forever**, **Burning Crusade Classic Anniversary** and **Classic Era / Hardcore**.

## Unit frames and click-casting (VuhDo / Cell / Healbot style)

- Solo, party and raid frames, plus optional tank, pet, target and focus frames.
- Click-casting: drag a spell or macro from your spellbook onto a binding. Mouse buttons, wheel and keyboard, with any modifier.
- **Friendly and hostile spells on the same binding**: Rejuvenation on a friend, Moonfire on an enemy, the game picks at click time.
- **Downranking** on Classic clients: drop a lower rank to cast that rank.
- Health and mana bars, incoming heals, absorbs, HoTs and shields, debuffs.
- Dispellable debuffs: coloured ring around the frame (green poison, brown disease...), in combat on Forever too.
- Out of range fading, threat border, role icons, dead / offline / incoming resurrection / ready check, eating and drinking.
- Option to hide Blizzard's party and raid frames.

## Screen auras (WeakAuras style)

- An icon, a bar, a frame or a disc anywhere on screen while a buff or debuff is **up, missing or running out**, or while a spell is **usable**.
- On you, your target, your focus or your pet. By spell, or by debuff type (Magic, Curse, Disease, Poison, "anything I can dispel").
- Countdown, stacks, glow, sound (played by the game, so it works in combat on Forever).
- Conditions: in or out of combat, in a group or raid, hostile target, spell in range, druid form or warrior stance.
- **Recommended auras**: a starter set for your class and spec in one click (all classes, Classic and Retail).
- Aura groups that move and resize as one block. Duplicate an aura, or share one as text.

## Profiles and sharing

- A profile per character, renamable, with a reset.
- Export / import everything (profile, bindings, tracked buffs, screen auras) as one line of text.

## Getting started

1. The small purple square next to the frames: drag it to move them, right-click it for the settings.
2. **Bindings** tab: drag a spell from your spellbook onto the drop zone (or pick it up and click the zone).
3. **Auras** tab: "Recommended auras" for a ready-made set.

## Commands

| Command | What it does |
|---|---|
| `/vb config` | Open the settings |
| `/vb lock` / `/vb unlock` | Lock or unlock the frames |
| `/vb reset` | Reset the frames' position |
| `/vb profile <name>` | Switch profile |
| `/vb spec` | Talent points read and spec detected |
| `/vb templatecheck` | Recommended auras' spells missing from your game version |
| `/vb cursor` | Typed while holding a spell: what VoidBox reads from the cursor |

## Notes for WoW Forever

Blizzard hides auras, health and range from addons in combat on Forever. VoidBox lets the game draw them (aura rows, dispel ring, screen auras, range fading), so they keep working in combat. One limit: a debuff **on yourself** cannot be picked by spell in combat; use a debuff type instead.

## Bugs and requests

Comments here, or [GitHub issues](https://github.com/VoiD911/VoidBox/issues). Please give your game version, class, and the Lua error if there is one (BugSack helps).

Translations: French nearly complete, the other languages partly (English for the rest). Help welcome.

MIT License
