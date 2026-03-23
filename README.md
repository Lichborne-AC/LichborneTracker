# LICHBORNE — Gear Tracker

### A World of Warcraft WotLK 3.3.5a Addon for AzerothCore Private Servers

**Version 1.51**

\---

## What's New in v1.51

* **Drag after sort fixed** — sorting no longer blocks drag reordering; dragging clears the sort mode so your manual order sticks
* Dragging characters on tables now take the position and move everyone down (before it would swap positions)
* **Clear Raids / Clear All Data** swapped positions
* Fixed overflow of data when copying large raids into smaller raids
* Various bug fixes and UI polish

\---
## Screenshots

**Character Sheet (All Tab)**
![Character Sheet](screenshots/Character_Sheet.png)

**Class Tracker**
![Class Tracker](screenshots/Class_Tracker.png)

**Raid Planner**
![Raid Planner](screenshots/Raid_Planner.png)

## Features

### Class Tabs

Each of the 10 playable classes has its own tab with up to **54 roster slots** across **3 pages**. Each character row tracks:

* **Row number** — muted grey, turns gold on hover
* **Spec icon** — auto-detected from talent inspection
* **Name** — editable, colored by class
* **Gear Score** — calculated from item levels via inspect
* **17 gear slots** — Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring 1, Ring 2, Trinket 1, Trinket 2, Main Hand, Off Hand, Ranged
* **Tier rating** — color-coded T1 through T17
* **Add to Raid** (+) and **Invite to Group** (>) buttons per row

#### Sort \& Page

Every tab has a **Sort** dropdown (top-left) and **Page** dropdown (top-right) on the header bar. Sort options: By Name, By Class/Spec, By Gear Score. After dragging to reorder, sort mode clears so your order sticks.

#### Bottom Controls (Class Tabs)

* **+ Add Target** — Inspects your current target and adds them
* **+ Add Group** — Bulk-adds all group/raid members
* **+ Add Target/Group GS** — Refreshes gear score (does not affect spec)
* **+ Add Target/Group Spec** — Reads talent spec (does not affect GS)
* **Stop** — Cancels a running GS or Spec scan
* **Maintenance** — Sends `maintenance` to group chat
* **AutoGear** — Sends `autogear` to group chat
* **Login/Logout All Bots** — `.playerbots bot add/remove \\\*`
* **Disband Group / Raid** — Kicks all members then leaves. Requires confirmation.
* **Invite Raid / Stop Invite** — Visible on all tabs

#### Summary Bars

* **Avg bar** — average tier per class, dark background, class name in class color, tier value in gold (T3, T10...)
* **Count bar** — total characters per class, class name in class color, number in class color

\---

### Raid Tab

Up to **40 slots** across two columns. Each slot shows class icon, spec icon, name, GS, tier, role, notes, delete button.

#### Raid Controls

* **Sort** — By Name, Class/Spec, or Gear Score
* **Tier / Raid / Group dropdowns** — Tier color matches raid name color
* **Copy** — Copies current roster to session clipboard
* **Paste** — Prompts confirmation, pastes into destination, disappears after one use
* **Clear** — Clears roster with confirmation

#### Copy / Paste

1. Navigate to source roster → click **Copy**
2. Navigate to destination → click **Paste**
3. Confirm: *"Copy T1 Molten Core (A) roster to T3 Karazhan (B)?"*
4. Status bar shows **"Roster copied!"**

Clipboard is session-only. Paste respects destination raid size — a 10-man paste from a 40-man only fills 10 slots.

#### Invite Raid

Automatically logs out old bots, leaves party, converts to raid, invites all members with verification and retry.

\---

### Character Sheet Tab

Master view of all tracked characters across all classes — 3 columns of 20 rows (60 per page, 180 total).

* Sort by Name, Class/Spec, or Gear Score
* Count bar shows totals across all pages

\---

## Installation

1. Download the zip and extract it
2. Drag the **`LichborneTracker`** folder into:

```
World of Warcraft/Interface/AddOns/
```

3. Launch WoW and type `/lichborne` or click the minimap icon

**Requirements:** WoW 3.3.5a (WotLK) | AzerothCore | Playerbot module

\---

## How To Use

### First Time Setup

1. Open the tracker with `/lichborne`
2. Target a character → click **+ Add Target**
3. Or get everyone at once: group up and click **+ Add Group**

### Tracking Gear

* **+ Add Target/Group GS** — updates gear score without touching spec
* Gear slot boxes — enter the tier number of each drop manually (e.g. MC drop = 1)

### Building a Raid Roster

1. Switch to **Raid tab** → select tier and raid
2. Use **+** on any character row to add them
3. Assign roles and notes
4. Click **Invite Raid**

### Copying a Roster

1. Navigate to source roster → **Copy**
2. Switch to destination → **Paste** → confirm

### Disbanding

**Disband Group / Raid** (bottom-left) kicks every member via `.playerbots bot remove` + `UninviteUnit`, waits 1 second, then calls `LeaveParty()`.

\---

## Data \& Saved Variables

Stored under `LichborneTrackerDB` and `LichborneMinimapIconDB` per WoW account. **Clear All Data** permanently deletes all tracked characters, gear, and rosters.

Data is saved per account — to share between accounts, copy:

```
WoW/WTF/Account/ACCOUNTNAME/SavedVariables/LichborneTracker.lua
```

\---

## Known Limitations

* Inspect requires target within \~28 yards
* `NotifyInspect()` is rate-limited — bulk scans space out automatically
* Playerbot commands sent via SAY chat — requires bot ownership
* Roster clipboard is session-only (lost on `/reload`)

\---

## Credits

Built for the **Lichborne** AzerothCore private server.
Special thanks to **Dohtt** for feature suggestions.

Questions \& Support: **lichborne.wow@proton.me**

*Compatible with WoW 3.3.5a (build 12340) | AzerothCore | Playerbot Module*

