# LICHBORNE — Gear Tracker
**A World of Warcraft WotLK 3.3.5a Addon for AzerothCore Private Servers**

**Version 1.70**

---

## Screenshots

![Character Sheet](screenshots/Character_Sheet.png)
![Class Tracker](screenshots/Class_Tracker.png)
![Raid Planner](screenshots/Raid_Planner.png)

---

## Recent Changes

- **Gear Score average bar in Class tabs** — Each class tab now displays an average GearScore bar alongside the existing average iLvl bar.
- **Item quality colors on gear slots** — Gear slot icons in the class tab are now color-coded to match WoW item quality (grey, white, green, blue, purple, orange).
- **Buttons disabled during scans** — Get Gear Score, Get Group Spec, and Invite Raid buttons are now disabled while a scan or invite sequence is running to prevent conflicts.
- **Visual updates and fixes** — General polish and layout corrections across tabs.
- **Separate `iLvl` and `GS` columns** — The old GS field is now labeled `iLvl`, and a new `GS` column tracks actual GearScore.
- **Actual GearScore calculation** — Inspect now calculates WotLK-style GearScore from equipped gear instead of reusing average item level.
- **Shared score syncing** — `iLvl` and `GS` stay in sync across Class, All, and Raid tabs, including copy/paste and drag reorder paths.
- **Addon code split into modules** — Shared bootstrap, data tables, layout constants, needs helpers, and raid row refresh logic now live in separate Lua files loaded by the TOC.
- **All tab action fixes** — Delete, add-to-group, and add-to-raid actions now operate on the visible character.
- **Deletion cleanup** — Removing a character also clears matching needs and raid roster references.
- **Invite flow fixes** — Invite buttons now reflect whether you are inviting a raid, inviting a group, or have an active invite run.
- **Raid size normalization** — Raid rosters now initialize and clamp correctly for the selected size.
- **Needs system** — Up to 2 needed gear slots per character, editable across Class, All, and Raid tabs.

---

## Features

### Class Tabs

Each of the 10 playable classes has its own tab with up to 54 roster slots across 3 pages. Each character row tracks:

- Row number — muted grey, turns gold on hover
- Spec icon — auto-detected from talent inspection
- Name — editable, colored by class
- iLvl — average equipped item level calculated via inspect
- Gear Score — actual WotLK-style GearScore calculated from inspected gear, colored by item quality
- **Needs** — up to 2 gear slots marked as needed, shown as slot icons
- 17 gear slots — Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring 1, Ring 2, Trinket 1, Trinket 2, Main Hand, Off Hand, Ranged
- Add to Raid (+) and Invite to Group (>) buttons per row
- Hover any gear slot to see the full item tooltip

### Sort & Page

Every tab has a Sort dropdown (top-left) and Page dropdown (top-right). Sort options: By Name, By Class/Spec, By Gear Score. Gear Score sorting uses the true `GS` column. After dragging to reorder, sort mode clears so your order sticks.

### Bottom Controls (Class Tabs)

- **+ Add Target** — Inspects your current target and adds them
- **+ Add Group** — Bulk-adds all group/raid members
- **+ Add Target/Group GS** — Refreshes both `iLvl` and `GS` from inspect (does not affect spec); button disabled during active scan
- **+ Add Target/Group Spec** — Reads talent spec (does not affect GS); button disabled during active scan
- **Stop** — Cancels a running GS or Spec scan
- **Maintenance** — Sends maintenance to group chat
- **AutoGear** — Sends autogear to group chat
- **Login/Logout All Bots** — `.playerbots bot add/remove *`
- **Disband Group / Raid** — Kicks all members then leaves. Requires confirmation
- **Invite Raid / Stop Invite** — Visible on all tabs; disabled while invite sequence is running

### Summary Bars

- **Avg bar** — average tracked item level per class, class name in class color, value in gold
- **GS bar** — average GearScore per class
- **Count bar** — total characters per class

---

## Needs System

Per-character gear slot wishlist, accessible from all tabs.

- 15 selectable slots: Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring, Trinket, Main Hand, Off Hand, Ranged
- Max 2 needs per character
- Click a Needs cell to open the picker popup
- Left-click a slot icon to mark as needed, right-click to remove
- Once at max (2), remaining slots are dimmed
- Right-click the Needs cell itself to clear all needs for that character
- Changes sync instantly across Class, All, and Raid tabs
- Stored in `LichborneTrackerDB.needs` per character name

---

## Raid Tab

Up to 40 slots across two columns. Each slot shows class icon, spec icon, name, `iLvl`, `GS`, needs, role, notes, and delete button.

### Raid Controls

- **Sort** — By Name, Class/Spec, or Gear Score using the real `GS` value
- **Tier / Raid / Group dropdowns** — Tier color matches raid name color
- **Copy** — Copies current roster to session clipboard
- **Paste** — Prompts confirmation, pastes into destination, disappears after one use
- **Clear** — Clears roster with confirmation

### Copy / Paste

1. Navigate to source roster → click **Copy**
2. Navigate to destination → click **Paste**
3. Confirm: *"Copy T1 Molten Core (A) roster to T3 Karazhan (B)?"*
4. Status bar shows "Roster copied!"

Clipboard is session-only. Paste respects destination raid size — a 10-man paste from a 40-man only fills 10 slots.

### Invite Raid

Automatically logs out old bots, leaves party, converts to raid, and invites all roster members via `.playerbots bot add`. The Invite Raid button is disabled while the sequence is running.

---

## Character Sheet (All Tab)

Master view of all tracked characters across all classes — 3 columns of 20 rows (60 per page, 180 total).

- Groups A, B, C for organizing characters
- Sort by Name, Class/Spec, or Gear Score using the real `GS` value
- Needs column editable per row
- Add to Raid and Invite to Group buttons per row
- Delete characters directly
- Count bar shows totals across all pages

---

## Tier Key

Color-coded T1–T17 reference bar at the top of the frame. Hover any swatch to see the full tier name and associated raids.

---

## Installation

1. Download the zip and extract it
2. Drag the `LichborneTracker` folder into:

   ```text
   World of Warcraft/Interface/AddOns/
   ```

3. Launch WoW and type `/lichborne` or click the minimap icon

**Requirements:** WoW 3.3.5a (WotLK) | AzerothCore | Playerbot module

---

## How To Use

### First Time Setup

1. Open the tracker with `/lichborne`
2. Target a character → click **+ Add Target**
3. Or get everyone at once: group up and click **+ Add Group**

### Tracking Gear

- **+ Add Target/Group GS** — updates both `iLvl` and `GS` without touching spec
- Hover any gear slot to see the full item tooltip
- Gear slot colors reflect WoW item quality

### Building a Raid Roster

1. Switch to **Raid** tab → select tier and raid
2. Use **+** on any character row to add them
3. Assign roles and notes
4. Click **Invite Raid**

### Marking Needs

1. Click any **Needs** cell on the Class, All, or Raid tab
2. Select up to 2 slot icons from the picker
3. Right-click a slot to remove it, or right-click the cell to clear all

### Copying a Roster

1. Navigate to source roster → **Copy**
2. Switch to destination → **Paste** → confirm

### Disbanding

**Disband Group / Raid** kicks every member via `.playerbots bot remove`, waits, then calls `LeaveParty()`. Requires confirmation.

---

## Data & Saved Variables

Stored under `LichborneTrackerDB` and `LichborneMinimapIconDB` per WoW account.

| Key | Contents |
| --- | --- |
| `rows` | All tracked characters, item levels, and GearScore data |
| `allGroups` | All tab group assignments (A/B/C) |
| `raidRosters` | Raid rosters keyed by raid name + group |
| `needs` | Gear needs per character |
| `raidName` | Currently selected raid |
| `raidTier` | Currently selected tier |
| `raidGroup` | Currently selected group (A/B/C) |

**Clear All Data** permanently deletes all tracked characters, gear, rosters, and needs data.

To share data between accounts, copy:

```text
WoW/WTF/Account/ACCOUNTNAME/SavedVariables/LichborneTracker.lua
```

---

## Code Organization

The addon loads through `LichborneTracker.toc`. Shared logic is split across dedicated modules.

| File | Responsibility |
| --- | --- |
| `LichborneTracker/Core.lua` | Saved-variable bootstrap, legacy migration, raid roster access |
| `LichborneTracker/Layout.lua` | Shared layout constants and column sizing |
| `LichborneTracker/Data.lua` | Static lookup tables for specs, classes, tiers, roles, and raid labels |
| `LichborneTracker/GearScore.lua` | WotLK-style GearScore calculation helpers |
| `LichborneTracker/Needs.lua` | Needs data helpers and limits |
| `LichborneTracker/Helpers.lua` | Shared row, tab, and tracker helper functions |
| `LichborneTracker/NeedsUI.lua` | Needs picker and needs-cell UI behavior |
| `LichborneTracker/RaidRows.lua` | Raid roster sorting and refresh behavior |
| `LichborneTracker/LichborneTracker.lua` | Remaining frame construction, event wiring, and top-level addon flow |

---

## Known Limitations

- Inspect requires target within ~28 yards
- GearScore depends on the inspect data returned by the server for the target's equipped items
- `NotifyInspect()` is rate-limited — bulk scans space out automatically
- Playerbot commands sent via SAY chat — requires bot ownership
- Roster clipboard is session-only (lost on `/reload`)

---

## Slash Commands

| Command | Action |
| --- | --- |
| `/lichborne` | Toggle the tracker window |
| `/lbt` | Toggle the tracker window (short alias) |

---

## Credits

Built for the Lichborne AzerothCore private server.

Special thanks to: **Dohtt**, **Scarecr0w12** — TheCGN.net, **Dreathean**, **Revision**, and **crow** for feature suggestions and support.

**Questions & Support:** [lichborne.wow@proton.me](mailto:lichborne.wow@proton.me)

---

## Compatibility

WoW 3.3.5a (build 12340) | AzerothCore | Playerbot Module
