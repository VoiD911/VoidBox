# Changelog

## v1.3.1 (2026-02-17)

- Fix: stack count badge not displaying on debuff/HOT icons (secret string from string.format broke tonumber — now extracts digits via string.byte)

## v1.3.0 (2026-02-17)

- New: percentage-based scaling system replacing fixed pixel width/height sliders
  - Base frame 80×55px at 100%, scales from 50% to 150% (step 10%)
  - Independent width and height scale sliders
  - Live resizing — no /reload needed, frames update in real-time
- New: debuff icons row (HARMFUL auras, max 4) with stack count badges
  - Dark background badge overlapping bottom-right of icon
  - Gold text, turns red at 5+ stacks
  - Dynamically centered row (only visible icons count)
- New: HOT/shield icons row (player-cast only, max 4) with stack badges
  - Filters to known heal spell IDs (all healer classes supported)
  - "+N" indicator bottom-right showing other healers' active HOTs/shields
  - In-combat mode uses RAID_IN_COMBAT PLAYER filter
- New: tooltip repositioned to bottom-right of screen (non-intrusive near raid frames)
- Change: compact layout — Row1 (10px name+%), Row2 (21px debuffs), Row3 (12px HOTs), Row4 (4px power bar)
- Change: all internal sizes (fonts, icons, badges, power bar) scale proportionally with height %

## v1.2.2 (2026-02-16)

- New: real role icons (shield/cross/sword) instead of colored squares, centered on health bar
- New: role icon updates automatically on spec change (no reload needed)
- New: role icon visible even when solo (uses current spec)
- Fix: name text now truncates dynamically based on frame width (no more overflow)
- Change: default frame height raised to 45, minimum height set to 45
- Change: role icon size increased to 12x12

## v1.2.1 (2026-02-16)

- Fix: mousewheel bindings were blocking normal click-casting (overlay frame removed, now uses WrapScript on button OnEnter/OnLeave)

## v1.2.0 (2026-02-15)

- New: mousewheel scroll up/down binding support
- New: macro drag & drop from the macro UI to binding slots
- New: profile system — create, copy, delete, switch layout/appearance profiles
- New: `/vb profile` and `/vb profile <name>` slash commands
- Fix: comprehensive secret value audit (SafeBool helper, PowerBarColor, UnitHasIncomingResurrection)

## v1.1.3 (2026-02-15)

- Fix: secret value spellId crash ("table index is secret") when checking heal buffs in 12.0+
- Fix: isStealable secret boolean crash — now converted at storage time via SafeBool helper
- Fix: PowerBarColor[powerType] table lookup protected against secret powerType
- Fix: UnitHasIncomingResurrection protected against secret boolean return
- Added VB:SafeBool() helper for safe boolean evaluation of secret values

## v1.1.1 (2026-02-14)

- Fix: complete localization for all languages (ptBR, itIT, ruRU, koKR, zhCN, zhTW)
- Fix: Interface version back to 120000 (12.0.0)

## v1.1.0 (2026-02-14)

- Fix: per-class bindings were leaking between classes (druid bindings showing on paladin/monk)
- New: orientation option (Horizontal / Vertical) in Appearance tab
- New: role order selector (6 presets: TDH, THD, HDT, HTD, DTH, DHT)
- New: frames per row slider (1-10, default 5) — VuhDo-style grouping
- Layout: 5 frames per row/column by default, wraps to next row/column
- Updated README for international audience

## v1.0.0 (2026-02-10)

- Initial release
- Compact raid frames with click-casting (SecureUnitButtonTemplate)
- Health percentage via UnitHealthPercent + C_CurveUtil (compatible with 12.0 secret values)
- Per-class bindings (shared across all characters of the same class)
- Drag & drop from spellbook
- Indicators: role, HOTs/shields, dispellable debuffs, threat, range
- Role sorting (Tank > DPS > Healer)
- Config UI (frame size, class colors, lock/unlock)
- Full localization: enUS, frFR, deDE, esES, esMX, ptBR, itIT, ruRU, koKR, zhCN, zhTW
- Compatible with WoW 12.0 Midnight
