# VoidBox

Minimalist healer raid frames with click-casting — Cell/VuhDo style.

Compatible with **WoW 12.0 Midnight** (secret values, new APIs).

## Usage

1. The small purple square to the left of the frames lets you **drag** to reposition
2. **Right-click** the purple square to open **configuration**
3. In config, **Click-Castings** tab: drag a spell from the spellbook onto a slot
4. Bindings are saved **per class** (not per character)

   
## Features

- **Compact raid frames** with health and mana bars
- **Click-casting** via SecureUnitButtonTemplate (works in combat)
- **Health percentage** 
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
| `/vb config` | Open configuration |
| `/vb lock` | Lock frames |
| `/vb unlock` | Unlock frames |
| `/vb reset` | Reset position |


## License

MIT License
