# Changelog

All notable changes to LichborneTracker are documented in this file.

---

## v1.76 - 2026-03-29

### Fixed

- Converted `activeTab`, four UI state variables (`LichborneAllCountLabels`, `LichborneRosterIlvlLabel`, `LichborneRosterGsLabel`, `LichborneRaidCountLabels`), and three functions (`RefreshRaidRows`, `RefreshAllRows`, `UpdateSummary`) from accidental globals to proper `local` declarations, eliminating addon conflict risk.
- Converted `RH2` helper inside `BuildRaidFrame` to `local` — it was a bare global with a short generic name.
- Fixed Tier 0 dropdown color rendering — `TIER_COLORS[0]` was `nil`; now correctly maps T0 to key `18` (silver-blue).
- Fixed GS scan timer never resetting — `inspectWait` was declared after the functions that reference it, causing the reset writes to target a different variable. Moved to module top so all closures share the same variable.
- Replaced three identical inline `classMap` tables with a single module-level `CLASS_TOKEN_MAP` constant.

---

## v1.75 - 2026-03-28

### Fixed

- Fixed minimap icon not appearing on machines where bundled libs failed to load silently.
- Added native fallback minimap button (based on DBM implementation) that activates automatically when LibDBIcon is unavailable.
- Replaced bundled libs with DBM-compatible versions for wider client support.
- Moved lib registration into `ADDON_LOADED` for correct initialization order.
- Changed minimap icon to book texture (`INV_Misc_Book_11`).

---

## v1.74 - 2026-03-27

### Fixed

- Fixed minimap icon not appearing on fresh installs without other broker addons.
- Replaced bundled libs with compatible versions for wider client compatibility.
- Moved lib registration into `ADDON_LOADED` for reliability.
- Changed minimap icon to book texture (`INV_Misc_Book_11`).

---

## v1.72 - 2026-03-26

### Fixed

- Fixed nil value crash (`attempt to index local 'c'`) when opening the raid selector dropdown with an unmapped tier value — now falls back to T1 color safely.
- Fixed dropdown menus (tier, raid, group, page, spec, sort) orphaning on screen when the addon is closed via ESC key — all menus now close via an `OnHide` hook on the main frame.

---

## v1.71 - 2026-03-26

### Added

- Added a separate `GS` column for actual GearScore alongside the existing `iLvl` column.
- Added automatic WotLK-style GearScore calculation from inspected equipment, including slot weighting, rarity scaling, and weapon handling.

### Changed

- Renamed the former `GS` display to `iLvl` everywhere it represents average equipped item level.
- Updated Class, Raid, and All tabs to show both `iLvl` and `GS` values.
- Updated sorting so Gear Score sorts now use the true `GS` value instead of average item level.
- Preserved real GearScore values across All tab groups, raid rosters, copy/paste, drag-reorder, and reset paths.
- Split shared addon code out of `LichborneTracker.lua` into dedicated modules for core state, layout constants, static data, GearScore helpers, needs handling, shared UI helpers, and raid row refresh logic.

### Fixed

- Fixed Add Group scan actions on 3.3.5a so UI handlers bind the local scan-state helper instead of calling a missing global `SetScanActive` when addon hook stacks are present.
- Fixed inspect slot mapping so equipped item levels are read from the correct gear slots.
- Fixed All tab actions so add, delete, and sync operations act on the displayed character.
- Fixed tracker deletion cleanup so removing a character also clears roster and needs references.
- Fixed raid dropdown closure scoping.
- Fixed raid size normalization and roster initialization for all raid views.
- Fixed invite button visibility so Invite Raid, Invite Group, and Stop Invite match the active state.
- Fixed raid row drag/drop so reordering no longer drops stored GearScore values.
- Fixed inspect refresh so empty slots clear stale item-level values instead of leaving old data behind.
- Fixed addon startup compatibility by loading `CallbackHandler-1.0` before `LibDataBroker-1.1`.
- Fixed multiple UI script handlers to use explicit event arguments instead of fragile implicit globals such as `this` and `arg1`.
