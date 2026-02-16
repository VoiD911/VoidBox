# Changelog

## v1.2.0 (2026-02-15)

- New: mousewheel scroll up/down binding support (via SecureHandlerEnterLeaveTemplate)
- New: macro drag & drop from the macro UI to binding slots
- New: profile system — create, copy, delete, switch layout/appearance profiles
- New: `/vb profile` and `/vb profile <name>` slash commands
- Fix: comprehensive secret value audit (SafeBool helper, PowerBarColor, UnitHasIncomingResurrection)

## v1.1.3 (2026-02-12)

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
