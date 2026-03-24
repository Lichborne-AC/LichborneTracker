# Changelog

All notable changes to Lichborne are documented in this file.

## Unreleased

### Added

- Added a separate `GS` column for actual GearScore alongside the existing `iLvl` column.
- Added automatic WotLK-style GearScore calculation from inspected equipment, including slot weighting, rarity scaling, and weapon handling.

### Changed

- Renamed the former `GS` display to `iLvl` everywhere it represents average equipped item level.
- Updated Class, Raid, and All tabs to show both `iLvl` and `GS` values.
- Updated sorting so Gear Score sorts now use the true `GS` value instead of average item level.
- Preserved real GearScore values across All tab groups, raid rosters, copy/paste, drag-reorder, and reset paths.

### Fixed

- Fixed inspect slot mapping so equipped item levels are read from the correct gear slots.
- Fixed All tab actions so add, delete, and sync operations act on the displayed character.
- Fixed tracker deletion cleanup so removing a character also clears roster and needs references.
- Fixed raid dropdown closure scoping.
- Fixed raid size normalization and roster initialization for all raid views.
- Fixed invite button visibility so Invite Raid, Invite Group, and Stop Invite match the active state.
- Fixed raid row drag/drop so reordering no longer drops stored GearScore values.
- Fixed inspect refresh so empty slots clear stale item-level values instead of leaving old data behind.
