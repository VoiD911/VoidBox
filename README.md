# VoidBox

Minimalist solo/party/raid unit frames with click-casting — Cell/Healbot-Click/Grid/VuhDo style.

Compatible with **WoW 12.0 Midnight** (secret values, new APIs).

## Usage

1. The small purple square to the left of the frames lets you **drag** to reposition
2. **Right-click** the purple square to open **configuration**
3. In config, **Click-Castings** tab: drag a spell from the spellbook onto a slot
4. Bindings are saved **per class** (not per character)

## Features

- Compact raid frames with health and mana bars
- Click-casting with drag & drop from spellbook or macro UI
- Universal "Press to Bind" system: keyboard, mouse, scroll wheel, MMO mouse
  - Capture any combo: Ctrl+F1, Shift+Numpad5, Alt+Right Click, etc.
  - Keyboard bindings activate on hover (SecureHandlerWrapScript)
  - Full modifier support (Shift, Ctrl, Alt) with any input
- Health percentage display (secret-value safe)
- Per-class bindings — all your priests share the same bindings
- Mousewheel scroll bindings (with modifier support)
- Profile system (layout/appearance profiles)
- Percentage-based scaling system (50%-150%, live preview, no reload)
  - Base frame: 80×55px at 100% scale
  - Independent width/height scale sliders (step 10%)
- Aura indicators:
  - Debuffs (HARMFUL): up to 4 icons with stack count badges, centered row
  - HOTs/shields (player-cast only): up to 4 icons with stack badges, centered row
  - "+N" indicator for other healers' HOTs/shields on the target
  - Stack badges: dark background, gold text, red at 5+ stacks
- Role icons (tank/heal/dps) — real atlas icons
- Threat border (red/yellow)
- Range check (reduced opacity when out of range)
- Dead / Disconnected / Incoming resurrection / Ready check icons
- Role sorting: Tank > DPS > Healer (6 presets)
- Tooltip anchored to bottom-right of screen (non-intrusive)
- Config UI: scaling, class colors, orientation, role order, lock/unlock
- Theme color: purple (#9966FF)
- Fully localized: enUS, frFR, deDE, esES, esMX, ptBR, itIT, ruRU, koKR, zhCN, zhTW

## Commands

| Command | Description |
|---------|-------------|
| `/vb config` | Open configuration |
| `/vb lock` | Lock frames |
| `/vb unlock` | Unlock frames |
| `/vb reset` | Reset position |
| `/vb profile` | List profiles |
| `/vb profile <name>` | Switch profile |

## License

MIT License
