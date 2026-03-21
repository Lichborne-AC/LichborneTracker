# LICHBORNE — Gear Tracker

### A World of Warcraft WotLK 3.3.5a Addon for AzerothCore Private Servers


\---

## 

## Purpose

**LICHBORNE** is a standalone gear tracking addon built for AzerothCore WotLK private servers running the 3.3.5a client. It was designed for server owners and raid leaders who manage large rosters of playerbot characters and need to track gear progression, talent specs, raid assignments, and group composition — all in one window. Named after my WoW private server.

\---

## 

## Features

### 

### Class Tabs

Each of the 10 playable classes has its own tab with up to **54 roster slots** across **3 pages**. Each character row tracks:

* **Spec icon** — auto-detected from talent inspection
* **Name** — editable
* **Gear Score** — calculated from item levels via inspect
* **17 gear slots** — Head, Neck, Shoulders, Back, Chest, Wrists, Hands, Waist, Legs, Feet, Ring 1, Ring 2, Trinket 1, Trinket 2, Main Hand, Off Hand, Ranged
* **Tier rating** — color-coded T1 through T17
* **Add to Raid** (+) and **Invite to Group** (>) buttons per row

## Screenshots
Class Tabs
![Class Tab](screenshots/Class%20Tab.png)
Raid Window
![Raid Window](screenshots/Raid%20Window.png)
Character Sheet
![Character Sheet](screenshots/Character%20Sheet.png)

#### 

#### Page Switching

Each class tab has a **Page dropdown** (top-right of the header) letting you switch between Page 1, 2, and 3. Characters fill pages in order — adding a new character always finds the next empty slot across all pages and jumps you to the right page automatically.

#### 

#### Bottom Controls (Class Tabs)

* **+ Add Target** — Inspects your current target and adds them to their class tab
* **+ Add Group** — Inspects all group/raid members and bulk-adds them
* **>> Get Target GS** — Refreshes gear score for your current target
* **>> Get Target Spec** — Reads talent spec for your current target
* **>> Get Group GS** — Refreshes gear score for all group members (sequentially, \~2.5s per player)
* **>> Get Group Spec** — Reads talent spec for all group members (\~3s per player)
* **Maintenance** — Sends `maintenance` to group chat (bots learn spells, repair, enchant)
* **AutoGear** — Sends `autogear` to group chat (bots equip best available gear)
* **Login All Bots** — Logs in all playerbot characters (`.playerbots bot add \*`)
* **Logout All Bots** — Logs out all playerbot characters (`.playerbots bot remove \*`)

#### 

#### Summary Bars

At the bottom of every class tab:

* **Avg bar** — shows average tier rating per class across all tracked characters
* **Count bar** — shows total tracked character count per class



### Raid Tab

Plan and manage your raid roster with up to **40 slots** across two columns. Supports multiple saved rosters for different raids and groups.

Each raid slot shows:

* Class icon, spec icon, name, gear score, tier, **role** (Tank/Healer/DPS), notes, and a delete (x) button

#### 

#### Raid Controls

At the top of the Raid tab:

* **Tier dropdown** — filter your view by tier (T1–T17)
* **Raid dropdown** — select the raid instance (Molten Core, BWL, AQ40, Naxx, etc.)
* **Group dropdown** — switch between Group A and Group B for the selected raid
* **Sort** — sort raid roster by class/spec
* **Clear** — clear the current roster

#### 

#### Invite Raid Button

Appears when a raid roster is selected (T1+). Click to automatically:

1. Log out all current bots by name (removes each one individually for instant disconnect)
2. Leave your current party
3. Wait 2 seconds for bots to clear
4. Invite the first bot and create the group
5. Convert to raid
6. Invite remaining bots with 0.8s gaps
7. Wait 3 seconds then **verify** who joined
8. If anyone was missed: individually removes then re-adds them (1s gap between remove and add)

#### 

#### Invite Group Button

Same as Invite Raid but for 5-man groups — skips the raid conversion step.

\---

### 

### All Tab

A master view showing **all tracked characters** across all classes in a 3-column layout of 20 rows each (60 characters per page).

* **Sort** — sorts all characters by class and spec
* **Page dropdown** — switch between Page 1, 2, and 3 (60 characters each, 180 total capacity)
* Characters sync automatically from your class tabs
* Count bar at the bottom shows totals across **all pages**, not just the current one

\---

## 

## Installation

1. Download `LichborneTracker.zip`
2. Extract the `LichborneTracker` folder
3. Place it in your WoW addons directory:

```
   World of Warcraft/Interface/AddOns/LichborneTracker/
   ```

4. Launch WoW (3.3.5a client) 
5. Type `/lichborne` or click the minimap icon to open the tracker



**Requirements:**

* WoW client: **3.3.5a** (WotLK)
* Server: **AzerothCore** with Playerbot module enabled
* Tested on AzerothCore with the `playerbots` module

\---

## 

## How To Use

### 

### First Time Setup

1. Open the tracker with `/lichborne`
2. Target a character you want to track
3. Click **+ Add Target** — this inspects them and adds them to their class tab automatically
4. Repeat for all your characters, or get them all at once with **+ Add Group** while in a group with them

### 

### Tracking Gear

* Click **>> Get Target GS** while targeting someone to update their gear score
* Click **>> Get Group GS** to update everyone in your current group at once
* Gear slots are manually edited by clicking the boxes in each row and entering which tier the drop came from.  Ex:  Mageblade drops in MC,  enter 1 in the row of which character looted it.  This allows you to track drops from each raid. Their are 17 Tiers.  These tiers are taken from the individual progression mod used in 3.3.5a.

### 

### Building a Raid Roster

1. Switch to the **Raid tab**
2. Select your raid from the Raid dropdown
3. Use the **+** button on any character row (from a class tab, or All tab) to add them to the raid
4. Assign roles using the role button on each raid slot
5. Add notes if needed (tank assignments, loot priority, etc.)
6. Click **Invite Raid** to automatically form the group

### 

### Switching Teams

When switching between different groups (e.g., Group A 40-man to Group B 10-man):

1. Select your new raid and group from the dropdowns
2. Click **Invite Raid** — it will automatically log out the previous group's bots first, then invite the new group

\---

## 

## Data \& Saved Variables

All data is stored in WoW's SavedVariables system under `LichborneTrackerDB`. This persists across sessions. The **Clear All Data** button (top-right, red) will permanently delete all tracked characters, gear data, and raid rosters.

\---

## 

## Known Limitations



* Gear inspection requires the target to be **nearby** (within inspect range, \~28 yards)
* Talent spec reading requires the target to be in your group or nearby
* The addon uses `NotifyInspect()` which is rate-limited by the WoW client — bulk operations like **Get Group GS** space out inspections automatically
* Playerbot commands (`bot add`, `bot remove`) are sent via SAY chat and require you to be the bot owner

\---

## 

## Credits



Built for the **Lichborne** AzerothCore private server.

*If this addon is useful to you, feel free to share it.*

\---

*Compatible with WoW 3.3.5a (build 12340) | AzerothCore | Playerbot Module*
