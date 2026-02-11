# VoidBox

Minimalist healer raid frames with click-casting — Cell/VuhDo style.

Compatible with **WoW 12.0 Midnight** (secret values, new APIs).

## Features

- **Compact raid frames** with health and mana bars
- **Click-casting** via SecureUnitButtonTemplate (works in combat)
- **Health percentage** displayed using `UnitHealthPercent` + `C_CurveUtil` (bypasses 12.0 secret values)
- **Per-class bindings** — all your priests share the same bindings
- **Drag & drop** from the spellbook to assign spells
- **Indicators**:
  - Role (tank/heal/dps) — colored square, top-left
  - Active HOTs/shields — green square, bottom-right
  - Dispellable debuffs — icons, bottom-left (max 3)
  - Threat (red/yellow border)
  - Range (reduced opacity when out of range)
  - Dead / Disconnected / Incoming resurrection
  - Ready check
- **Role sorting**: Tank > DPS > Healer
- **Config UI**: frame size, class colors, lock/unlock
- **Theme color**: purple (`#9966FF`)
- **Fully localized**: enUS, frFR, deDE, esES, esMX, ptBR, itIT, ruRU, koKR, zhCN, zhTW

## Commands

| Command | Description |
|---------|-------------|
| `/vb` | Show help |
| `/vb config` | Open configuration |
| `/vb lock` | Lock frames |
| `/vb unlock` | Unlock frames |
| `/vb reset` | Reset position |
| `/vb debug` | Toggle debug mode |
| `/vb debughealth` | Debug health values (secret values) |

## Usage

1. The small purple square to the left of the frames lets you **drag** to reposition
2. **Right-click** the purple square to open **configuration**
3. In config, **Click-Castings** tab: drag a spell from the spellbook onto a slot
4. Bindings are saved **per class** (not per character)

## Installation

1. Download the latest release
2. Extract the `VoidBox/` folder into `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload`

## Secret Values (WoW 12.0)

This addon implements a workaround for the "secret values" system introduced in 12.0 Midnight.
Health values returned by `UnitHealth()` are protected — no arithmetic, comparison, or conversion is possible on them.

The solution uses `UnitHealthPercent()` combined with `C_CurveUtil.CreateCurve()` (scalar curve mapping 0→0, 1→100) to get a displayable health percentage via `string.format()`.

## License

MIT License — see [LICENSE](LICENSE)
