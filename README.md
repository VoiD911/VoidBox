# VoidBox

Minimalist solo/party/raid unit frames with click-casting — Cell/Healbot-Click/Grid/VuhDo style.

Compatible with **WoW 12.0 Midnight** and **WoW: Forever** (Classic+, interface 16001).

### Notes for WoW: Forever

Forever runs the Midnight UI codebase on a level-60 Vanilla ruleset, so VoidBox
adapts itself at login:

- Dispel highlighting is derived from the spells in your spellbook (Vanilla has
  no specializations)
- Range checking and HoT/shield tracking use Vanilla spells and cover every rank
- **Click-casting:** mouse bindings work normally. On builds where
  `loadstring_untainted` is missing, the client cannot compile secure snippets,
  so keyboard bindings switch to global override bindings on `@mouseover` proxy
  buttons. VoidBox prints a notice at login when that happens. Scroll-wheel
  click-casting is unavailable on that path.
- **Known beta client bug:** early Forever builds write `SavedVariables` on exit
  but never read them back, so settings can reset between sessions. That is a
  client issue, not an addon one.

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
- Minimap button (LibDBIcon): left-click toggle frames, right-click config
- Separate tank frame (optional): dedicated movable panel for tanks only
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
| `/vb minimap` | Toggle minimap button |
| `/vb profile` | List profiles |
| `/vb profile <name>` | Switch profile |

## License

MIT License
