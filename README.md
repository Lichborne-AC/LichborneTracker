# LICHBORNE — Gear Tracker

**A World of Warcraft WotLK 3.3.5a Addon for AzerothCore Private Servers that tracks gear score, iLvL, gear slots, specs, and raid composition for your entire playerbot roster.**

**Version 2.1**

\---

## Screenshots

![Class Tracker](Screenshots/ClassTab.png)
![Raid Planner](Screenshots/RaidTab.png)
![Character Sheet](Screenshots/CharacterSheet.png)

\---

## Recent Changes (v2.2)
* **Fixed Titans grip bug (Duel 2h weapons not displaying correctly)


## Recent Changes (v2.1)

* **Dual-spec bots now report correct active spec** — Fixed a bug where bots with their secondary spec active always returned their primary spec. `CalcSpec` now calls `GetActiveTalentGroup` to determine which talent group is active and passes it to `GetTalentTabInfo` and `GetTalentInfo`, so the correct spec is read regardless of which group is active.
* **Stop Scan now cancels Add Group Gear and Add Group Spec immediately** — Fixed a bug where pressing Stop during the member-adding phase of Add Group Gear or Add Group Spec had no effect. The scan would continue through all phases regardless. Root cause: `AddGroupMembers` wrote to a different variable than the one Stop Scan was reading due to a Lua scope mismatch. Both buttons now set the cancellation flag before the scan begins and check it when the add phase completes.

(See CHANGELOG.md for full version history)

\---

## Recent Changes (v2.0)

* **Class Tab help button** — A new `?` help icon has been added to the header bar for the Class tab. Hover it to see an explanation of class tab filtering, spec icon click-to-assign, gear slot hover inspection, and the count bar.
* **"All" tab renamed to "Overview"** — The All tab is now called Overview throughout the addon: tab label, frame names, and all internal references updated.
* **Stop Scan now works during Add Group phase** — Fixed a bug where pressing Stop during the member-adding phase of Add Group or Full Group Scan had no effect. The scan would continue adding characters and proceed through all phases regardless.
* **Full Group Scan** — The Full Scan button has been renamed to Full Group Scan. It runs all three scan phases automatically in sequence: add members → scan gear → scan specialization. No manual button clicks required between phases. Allow \~6 seconds per member.
* **Options panel** — A gear (⚙) button opens a new Options panel. 
* **Help buttons for Raid and Overview tabs** — Two new help icons added to the header bar. Hover the Raid Tab icon for instructions on tier/raid selection, adding characters, and using Invite Raid or Invite Group. Hover the Overview Tab icon for instructions on adding/removing from raid, inviting to group, filtering, and sorting.
* **Raid filter button** — A new filter button in the Filters row lets you show only characters in your currently selected raid. When active, all other characters are hidden across Class and Overview tabs. Useful for confirming who has or hasn't been added to a roster.

(See CHANGELOG.md for full version history)

\---

## Features

### Class Tabs

Each of the 10 playable classes has its own tab with unlimited roster slots. Each character row tracks:

* Spec icon — auto-detected from talent inspection. Can be manually changed by clicking the icon.
* Name — editable, colored by class
* iLvL — average equipped item level calculated via inspect
* Gear Score — actual WotLK-style GearScore calculated from inspected gear, colored by item quality
* **Need Box** — up to 2 gear slots marked as needed, shown as slot icons
* 17 gear slots — Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring 1, Ring 2, Trinket 1, Trinket 2, Main Hand, Off Hand, Ranged
* Add to Raid (+) and Invite to Group (>) buttons per row
* Hover any gear slot to see the full item tooltip

### Bottom Controls

* **+ Add Target** — Inspects your current target and adds them
* **+ Add Group** — Bulk-adds all group/raid members
* **+ Add Target/Group Gear** — Refreshes both iLvL and GS from inspect (does not affect spec); disabled during active scan
* **+ Add Target/Group Spec** — Reads talent spec (does not affect GS); disabled during active scan
* **Full Group Scan** — Runs all three phases automatically: add members → scan gear → scan specialization
* **Stop** — Cancels a running scan at any point, including during the member-adding phase
* **Maintenance** — Sends maintenance to group chat
* **AutoGear** — Sends autogear to group chat
* **Log in / Log Out All Bots** — `.playerbots bot add/remove \*`
* **Log Out Orphaned Bots** — Logs out any roster bots not currently in your active raid group
* **Disband Group / Raid** — Kicks all members then leaves. Requires confirmation
* **Invite Raid / Stop Invite** — Visible on all tabs; disabled while invite sequence is running
* **Import / Export** — Transfer roster data between accounts

### Output Box

* Scrollable log at the bottom of the tracker window
* All status messages route here instead of chat
* Mouse-wheel scrollable, 500-line history
* Expand (∧) / collapse (∨) toggle for more visible lines
* **DBG button** — toggles detailed inspect debug logging (green = active)

### Summary Bars

* **Avg bar** — average tracked item level per class (values in gold)
* **GS bar** — average GearScore per class (values in gold)
* **Count bar** — total characters per class

### Help Buttons

Three help icons in the header bar (hover for tooltips):

* **? (Setup)** — How to set up your tracker
* **Raid Tab** — How to use the Raid tab: picking a tier/raid, adding characters, inviting via INVITE RAID or INVITE GROUP
* **Overview Tab** — How to use the Overview tab: adding/removing from raid, inviting to group, filtering, and sorting
* **Class Tab** — How to use class tabs: filtering, spec icon assignment, gear slot inspection, count bar

\---

## Need Box

Per-character gear slot wishlist, accessible from all tabs.

* 15 selectable slots: Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring, Trinket, Main Hand, Off Hand, Ranged
* Max 2 needs per character
* Click a Need Box cell to open the popup
* Left-click a slot icon to mark as needed, right-click to remove
* At max (2), remaining slots are dimmed
* Right-click the Need Box cell itself to clear all needs for that character
* Changes sync instantly across Class, Overview, and Raid tabs
* Stored in `LichborneTrackerDB.needs` per character name

\---

## Raid Tab

Up to 40 slots across two columns. Each slot shows class icon, spec icon, name, iLvL, GS, needs, role, notes, and delete button.

### Raid Controls

* **Column header sorting** — Click Spec, Name, iLvL, GS, or Role to sort
* **Tier / Raid / Group dropdowns** — Tier color matches the Individual Progression module
* **Copy** — Copies current roster to session clipboard
* **Paste** — Prompts confirmation, pastes into destination, disappears after one use
* **Clear** — Clears roster with confirmation

### Raid Filter

The filter button on Class and Overview tabs, when active, shows *only* characters currently in your selected raid — hiding everyone else. Useful for confirming who has been added to a roster.

### Invite Raid / Invite Group

* **INVITE RAID** — Automatically logs out old bots, leaves party, converts to raid, and invites all roster members via `.playerbots bot add`. Always invites from the currently selected raid's table.
* **INVITE GROUP** — Invites the 5-Man team from the TO 5-Man Dungeons tab. Operates independently of whichever tab is active.

Use the Group dropdown (A/B/C) to manage multiple raid parties.

> \*\*Note:\*\* Raid configurations are saved after reloads and must be manually cleared.

\---

## Overview Tab (formerly "All Tab")

Master view of all tracked characters across all classes — 3 columns of 20 rows (60 per page, 180 total).

* Groups A, B, C for organizing characters
* Sort by Spec, Name, iLvL, GS, or raid membership (+ header)
* Need Box column editable per row
* Add to Raid (left-click +) and Remove from Raid (right-click +) per row
* Invite to Group (left-click >) and Kick from Group (right-click >) per row
* Delete characters directly
* Count bar shows totals across all pages

\---

## Options Panel

Open via the ⚙ button above the output box.

\---

## Installation

### Option 1 — Git Clone (recommended, stays updated)

Navigate to your AddOns folder and run:

```
git clone https://github.com/Lichborne-AC/LichborneTracker
```

To update later just run `git pull` inside the LichborneTracker folder.

### Option 2 — Manual Install

1. Download the latest zip from the Releases page
2. Extract and drag the LichborneTracker folder into:

   World of Warcraft/Interface/AddOns/

3. Launch WoW and type `/lichborne` or click the minimap book icon

   **Requirements:** WoW 3.3.5a (WotLK) | AzerothCore | Playerbot module

   \---

   ## How To Use

   ### First Time Setup

1. Open the tracker with `/lichborne` or click the minimap book icon
2. Target a character and click **+ Add Target**
3. Or get everyone at once: group up and click **+ Add Group**
4. For a full scan in one click, use **Full Group Scan** — adds all members, then scans gear and spec automatically

   ### Tracking Gear

* **+ Add Target/Group Gear** — updates both iLvL and GS without touching spec
* Hover any gear slot to see the full item tooltip
* Gear slot colors reflect WoW item quality

  ### Building a Raid Roster

1. Switch to the Raid tab and select a tier and raid from the header dropdowns
2. Use + on any character row (Class or Overview tab) to add them to the active raid
3. Right-click + to remove a character from the raid roster
4. Assign roles and notes on the Raid tab
5. Click **Invite Raid** to log in all roster members

   ### Managing a 5-Man Group

1. Switch to the **TO 5-Man Dungeons** tab on the Raid tab
2. Add up to 5 characters via the Class or Overview tabs
3. Click **Invite Group** to log them in

   ### Filtering by Raid

   Activate the raid filter button (Class or Overview tab) to show only characters in your currently selected raid. Turn it off to see everyone.

   ### Marking Needs

1. Click any Need Box cell on the Class, Overview, or Raid tab
2. Select up to 2 slot icons from the picker
3. Right-click a slot to remove it, or right-click the cell to clear all

   ### Copying a Roster

1. Navigate to the source roster and click **Copy**
2. Switch to destination and click **Paste** then confirm

   ### Importing / Exporting Characters

   Use the Import/Export button to generate a text string of your current roster. Copy it and import it on another account to transfer your tracked characters and gear data.

   ### Disbanding

   Disband Group / Raid kicks every member via `.playerbots bot remove`, waits, then calls `LeaveParty()`. Requires confirmation.

   \---

   ## Data \& Saved Variables

   Stored under `LichborneTrackerDB` and `LichborneMinimapIconDB` per WoW account.

|Key|Contents|
|-|-|
|rows|All tracked characters, item levels, and GearScore data|
|allGroups|Overview tab group assignments (A/B/C)|
|raidRosters|Raid rosters keyed by raid name + group|
|needs|Gear needs per character|
|raidName|Currently selected raid|
|raidTier|Currently selected tier|
|raidGroup|Currently selected group (A/B/C)|
|language|Selected language preference|

**Clear All Data** permanently deletes all tracked characters, gear, rosters, and needs data.

\---

## Known Limitations

* Inspect requires target within \~28 yards
* GearScore depends on the inspect data returned by the server for the target's equipped items
* `NotifyInspect()` is rate-limited — bulk scans space out automatically
* Playerbot commands sent via SAY chat — requires bot ownership
* Roster clipboard is session-only (lost on `/reload`)

\---

## Slash Commands

|Command|Action|
|-|-|
|/lichborne|Toggle the tracker window|
|/lbt|Toggle the tracker window (short alias)|

\---

## Credits

Built for the Lichborne AzerothCore private server.

Special thanks to: **Dohtt**, **Scarecr0w12** — TheCGN.net, **Dreathean**, **Revision**, **crow**, and **ScoobyPwnsOnU** for feature suggestions, testing, and support.

**Questions \& Support:** lichborne.wow@proton.me | Discord: jared2219

\---

## Compatibility

WoW 3.3.5a (build 12340) | AzerothCore | Playerbot Module

