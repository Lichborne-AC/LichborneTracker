-- ============================================================
--  LichborneTracker.lua  |  WotLK 3.3.5a  |  AzerothCore
-- ============================================================

if not LichborneTrackerDB then LichborneTrackerDB = {} end
if not LichborneTrackerDB.rows then LichborneTrackerDB.rows = {} end
if not LichborneTrackerDB.notes then LichborneTrackerDB.notes = "" end
if not LichborneTrackerDB.raid then LichborneTrackerDB.raid = "" end
if not LichborneTrackerDB.raidRows then LichborneTrackerDB.raidRows = {} end  -- legacy compat
if not LichborneTrackerDB.raidRosters then LichborneTrackerDB.raidRosters = {} end
if not LichborneTrackerDB.raidTier then LichborneTrackerDB.raidTier = 0 end
if not LichborneTrackerDB.needs then LichborneTrackerDB.needs = {} end  -- keyed by charname:lower()
if not LichborneTrackerDB.raidName then LichborneTrackerDB.raidName = "Molten Core" end
if not LichborneTrackerDB.raidSize then LichborneTrackerDB.raidSize = 40 end
if not LichborneTrackerDB.raidGroup then LichborneTrackerDB.raidGroup = "A" end
if not LichborneTrackerDB.allGroups then
    LichborneTrackerDB.allGroups = {}
    for _, g in ipairs({"A","B","C"}) do
        LichborneTrackerDB.allGroups[g] = {}
        for i = 1, 60 do LichborneTrackerDB.allGroups[g][i] = {name="",cls="",spec="",gs=0,realGs=0} end
    end
end
if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
local MAX_RAID_SLOTS = 40
-- Legacy migration
if LichborneTrackerDB.allRows then
    if not LichborneTrackerDB.allGroups then LichborneTrackerDB.allGroups = {A={},B={},C={}} end
    for i,v in ipairs(LichborneTrackerDB.allRows) do
        if v.realGs == nil then v.realGs = 0 end
        LichborneTrackerDB.allGroups["A"][i] = v
    end
    LichborneTrackerDB.allRows = nil
end


-- Returns the roster table for the currently selected raid, creating if needed
local function GetCurrentRoster()
    -- Guard: ensure DB and raidRosters exist (may not yet if SavedVars not loaded)
    if not LichborneTrackerDB then LichborneTrackerDB = {} end
    if not LichborneTrackerDB.raidRosters then LichborneTrackerDB.raidRosters = {} end
    if not LichborneTrackerDB.raidName then LichborneTrackerDB.raidName = "N/A (5-Man)" end
    if not LichborneTrackerDB.raidSize then LichborneTrackerDB.raidSize = 5 end
    if not LichborneTrackerDB.raidGroup then LichborneTrackerDB.raidGroup = "A" end
    if not LichborneTrackerDB.allGroups then
        LichborneTrackerDB.allGroups = {}
        for _, g in ipairs({"A","B","C"}) do
            LichborneTrackerDB.allGroups[g] = {}
            for i = 1, 60 do
                LichborneTrackerDB.allGroups[g][i] = {name="",cls="",spec="",gs=0,realGs=0}
            end
        end
    end
    if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
    local name = LichborneTrackerDB.raidName
    local size = LichborneTrackerDB.raidSize
    if type(size) ~= "number" then size = tonumber(size) or 5 end
    if size < 1 then size = 1 end
    if size > MAX_RAID_SLOTS then size = MAX_RAID_SLOTS end
    LichborneTrackerDB.raidSize = size
    local group = LichborneTrackerDB.raidGroup
    local key = name .. "_" .. group   -- e.g. "Karazhan_A"
    if not LichborneTrackerDB.raidRosters[key] then
        LichborneTrackerDB.raidRosters[key] = {}
        for i = 1, MAX_RAID_SLOTS do
            LichborneTrackerDB.raidRosters[key][i] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
        end
    end
    local roster = LichborneTrackerDB.raidRosters[key]
    for i = 1, MAX_RAID_SLOTS do
        if not roster[i] then roster[i] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""} end
    end
    return roster, size
end

local function IsInActiveRaid(charName)
    if not LichborneTrackerDB or not LichborneTrackerDB.raidRosters then return false end
    local raidName  = LichborneTrackerDB.raidName  or ""
    local raidGroup = LichborneTrackerDB.raidGroup or "A"
    local key = raidName .. "_" .. raidGroup
    local roster = LichborneTrackerDB.raidRosters[key]
    if not roster then return false end
    for i = 1, MAX_RAID_SLOTS do
        if roster[i] and roster[i].name and roster[i].name ~= "" and
           roster[i].name:lower() == charName:lower() then
            return true
        end
    end
    return false
end

local ROW_HEIGHT  = 24
local GEAR_SLOTS  = 17
local MAX_ROWS    = 18  -- visible rows per class tab
local SLOT_ABBR   = {"Head","Neck","Shldr","Back","Chest","Wrist","Hands","Waist","Legs","Feet","Ring1","Ring2","Trnk1","Trnk2","MH","OH","Rngd"}

local GS_SCALE = 1.8618
local GS_ITEM_TYPES = {
    ["INVTYPE_RELIC"] = { slotMod = 0.3164 },
    ["INVTYPE_TRINKET"] = { slotMod = 0.5625 },
    ["INVTYPE_2HWEAPON"] = { slotMod = 2.0000 },
    ["INVTYPE_WEAPONMAINHAND"] = { slotMod = 1.0000 },
    ["INVTYPE_WEAPONOFFHAND"] = { slotMod = 1.0000 },
    ["INVTYPE_RANGED"] = { slotMod = 0.3164 },
    ["INVTYPE_THROWN"] = { slotMod = 0.3164 },
    ["INVTYPE_RANGEDRIGHT"] = { slotMod = 0.3164 },
    ["INVTYPE_SHIELD"] = { slotMod = 1.0000 },
    ["INVTYPE_WEAPON"] = { slotMod = 1.0000 },
    ["INVTYPE_HOLDABLE"] = { slotMod = 1.0000 },
    ["INVTYPE_HEAD"] = { slotMod = 1.0000 },
    ["INVTYPE_NECK"] = { slotMod = 0.5625 },
    ["INVTYPE_SHOULDER"] = { slotMod = 0.7500 },
    ["INVTYPE_CHEST"] = { slotMod = 1.0000 },
    ["INVTYPE_ROBE"] = { slotMod = 1.0000 },
    ["INVTYPE_WAIST"] = { slotMod = 0.7500 },
    ["INVTYPE_LEGS"] = { slotMod = 1.0000 },
    ["INVTYPE_FEET"] = { slotMod = 0.7500 },
    ["INVTYPE_WRIST"] = { slotMod = 0.5625 },
    ["INVTYPE_HAND"] = { slotMod = 0.7500 },
    ["INVTYPE_FINGER"] = { slotMod = 0.5625 },
    ["INVTYPE_CLOAK"] = { slotMod = 0.5625 },
    ["INVTYPE_BODY"] = { slotMod = 0.0000 },
}

local GS_FORMULA = {
    A = {
        [4] = { A = 91.4500, B = 0.6500 },
        [3] = { A = 81.3750, B = 0.8125 },
        [2] = { A = 73.0000, B = 1.0000 },
    },
    B = {
        [4] = { A = 26.0000, B = 1.2000 },
        [3] = { A = 0.7500, B = 1.8000 },
        [2] = { A = 8.0000, B = 2.0000 },
        [1] = { A = 0.0000, B = 2.2500 },
    },
}

local function CalculateGearScoreForItemLink(itemLink)
    if not itemLink then return 0, 0, nil end

    local _, _, itemRarity, itemLevel, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    local itemType = itemEquipLoc and GS_ITEM_TYPES[itemEquipLoc]
    if not itemType or not itemRarity or not itemLevel then return 0, itemLevel or 0, itemEquipLoc end

    local qualityScale = 1
    if itemRarity == 5 then
        qualityScale = 1.3
        itemRarity = 4
    elseif itemRarity == 1 or itemRarity == 0 then
        qualityScale = 0.005
        itemRarity = 2
    end

    if itemRarity == 7 then
        itemRarity = 3
        itemLevel = 187.05
    end

    if itemRarity < 2 or itemRarity > 4 then return 0, itemLevel, itemEquipLoc end

    local formulaSet = itemLevel > 120 and GS_FORMULA.A or GS_FORMULA.B
    local formula = formulaSet[itemRarity]
    if not formula then return 0, itemLevel, itemEquipLoc end

    local score = ((itemLevel - formula.A) / formula.B) * itemType.slotMod * GS_SCALE * qualityScale
    if score < 0 then score = 0 end

    return math.floor(score), itemLevel, itemEquipLoc
end

local function CalculateUnitGearScore(unitToken)
    if not unitToken or not UnitExists(unitToken) then return 0 end

    local _, classToken = UnitClass(unitToken)
    local titanGripScale = 1
    local mainHandLink = GetInventoryItemLink(unitToken, 16)
    local offHandLink = GetInventoryItemLink(unitToken, 17)

    if mainHandLink and offHandLink then
        local _, _, _, _, _, _, _, _, mainEquipLoc = GetItemInfo(mainHandLink)
        local _, _, _, _, _, _, _, _, offEquipLoc = GetItemInfo(offHandLink)
        if mainEquipLoc == "INVTYPE_2HWEAPON" or offEquipLoc == "INVTYPE_2HWEAPON" then
            titanGripScale = 0.5
        end
    end

    local totalScore = 0

    if offHandLink then
        local offHandScore = select(1, CalculateGearScoreForItemLink(offHandLink))
        if classToken == "HUNTER" then offHandScore = offHandScore * 0.3164 end
        totalScore = totalScore + (offHandScore * titanGripScale)
    end

    for slot = 1, 18 do
        if slot ~= 4 and slot ~= 17 then
            local itemLink = GetInventoryItemLink(unitToken, slot)
            if itemLink then
                local itemScore = select(1, CalculateGearScoreForItemLink(itemLink))
                if classToken == "HUNTER" then
                    if slot == 16 then
                        itemScore = itemScore * 0.3164
                    elseif slot == 18 then
                        itemScore = itemScore * 5.3224
                    end
                end
                if slot == 16 then itemScore = itemScore * titanGripScale end
                totalScore = totalScore + itemScore
            end
        end
    end

    if totalScore <= 0 then return 0 end
    return math.floor(totalScore)
end

-- ── Needs system ───────────────────────────────────────────────
local NEEDS_SLOTS = {
    { key="head",    icon="Interface\\Icons\\INV_Helmet_03",              label="Head"      },
    { key="neck",    icon="Interface\\Icons\\INV_Jewelry_Necklace_07",    label="Neck"      },
    { key="shoulder",icon="Interface\\Icons\\INV_Shoulder_22",            label="Shoulders" },
    { key="back",    icon="Interface\\Icons\\INV_Misc_Cape_07",           label="Back"      },
    { key="chest",   icon="Interface\\Icons\\INV_Chest_Cloth_04",         label="Chest"     },
    { key="wrist",   icon="Interface\\Icons\\INV_Bracer_07",              label="Wrists"    },
    { key="hands",   icon="Interface\\Icons\\INV_Gauntlets_04",           label="Hands"     },
    { key="waist",   icon="Interface\\Icons\\INV_Belt_13",                label="Waist"     },
    { key="legs",    icon="Interface\\Icons\\INV_Pants_06",               label="Legs"      },
    { key="feet",    icon="Interface\\Icons\\INV_Boots_05",               label="Feet"      },
    { key="ring",    icon="Interface\\Icons\\INV_Jewelry_Ring_02",        label="Ring"      },
    { key="trinket", icon="Interface\\Icons\\INV_Misc_Rune_06",                label="Trinket"    },
    { key="mh",      icon="Interface\\Icons\\INV_Sword_27",               label="Main Hand" },
    { key="oh",      icon="Interface\\Icons\\INV_Shield_06",              label="Off Hand"  },
    { key="ranged",  icon="Interface\\Icons\\INV_Weapon_Bow_07",          label="Ranged"    },
}
local NEEDS_ICON_SIZE = 18  -- size of each mini icon in the needs cell

local function GetNeeds(charName)
    if not charName or charName == "" then return {} end
    local k = charName:lower()
    if not LichborneTrackerDB.needs then LichborneTrackerDB.needs = {} end
    if not LichborneTrackerDB.needs[k] then LichborneTrackerDB.needs[k] = {} end
    return LichborneTrackerDB.needs[k]
end

local MAX_NEEDS = 2  -- max stored + displayed needs per character

local function SetNeed(charName, slotKey, val)
    if not charName or charName == "" then return end
    if not LichborneTrackerDB.needs then LichborneTrackerDB.needs = {} end
    local k = charName:lower()
    if not LichborneTrackerDB.needs[k] then LichborneTrackerDB.needs[k] = {} end
    if val then
        -- count current needs
        local count = 0
        for _ in pairs(LichborneTrackerDB.needs[k]) do count = count + 1 end
        if count < MAX_NEEDS then
            LichborneTrackerDB.needs[k][slotKey] = true
        end
    else
        LichborneTrackerDB.needs[k][slotKey] = nil
    end
end

local function HasNeeds(charName)
    if not charName or charName == "" then return false end
    if not LichborneTrackerDB.needs then return false end
    local n = LichborneTrackerDB.needs[charName:lower()]
    if not n then return false end
    for _ in pairs(n) do return true end
    return false
end

-- Shared singleton needs picker popup
local needsPicker = nil
local needsPickerOwner = nil  -- charName currently open

local COL_NAME_W  = 140
local COL_GS_W    = 42
local COL_GEAR_W  = 44
local COL_NEEDS_W = 42  -- needs cell: fits exactly 2 icons (2 + 18 + 2 + 18 + 2)
local NAME_OFF    = 4
local GS_OFF      = NAME_OFF + COL_NAME_W + 6
local REALGS_OFF  = GS_OFF + COL_GS_W + 2
local NEEDS_OFF   = REALGS_OFF + COL_GS_W + 2    -- needs cell right after GS
local GEAR_OFF    = NEEDS_OFF + COL_NEEDS_W + 2  -- gear slots shifted right

local COL_DRAG_W  = 18  -- drag handle width
local COL_SPEC_W  = 24  -- icon column width
local DRAG_OFF    = 0   -- drag handle at far left
local SPEC_OFF    = COL_DRAG_W + 2  -- spec icon after drag handle
-- shift name right to make room for drag + spec
NAME_OFF = NAME_OFF + COL_DRAG_W + 2 + COL_SPEC_W + 2

-- Spec → icon mapping (WotLK interface icons)
local SPEC_ICONS = {
    -- Death Knight
    ["Blood"]       = "Interface\\Icons\\Spell_DeathKnight_BloodPresence",
    ["Frost DK"]    = "Interface\\Icons\\Spell_DeathKnight_FrostPresence",
    ["Unholy"]      = "Interface\\Icons\\Spell_DeathKnight_UnholyPresence",
    -- Druid
    ["Balance"]     = "Interface\\Icons\\Spell_Nature_StarFall",
    ["Feral"]       = "Interface\\Icons\\Ability_Druid_CatForm",
    ["Restoration"] = "Interface\\Icons\\Spell_Nature_HealingTouch",
    -- Hunter
    ["Beast Mastery"] = "Interface\\Icons\\Ability_Hunter_BeastTaming",
    ["Marksmanship"]  = "Interface\\Icons\\Ability_Marksmanship",
    ["Survival"]      = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
    -- Mage
    ["Arcane"]      = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    ["Fire"]        = "Interface\\Icons\\Spell_Fire_FireBolt02",
    ["Frost"]       = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    -- Paladin
    ["Holy Pala"]   = "Interface\\Icons\\Spell_Holy_HolyBolt",
    ["Protection"]  = "Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar",
    ["Retribution"] = "Interface\\Icons\\Spell_Holy_AuraofLight",
    -- Priest
    ["Discipline"]  = "Interface\\Icons\\Spell_Holy_WordFortitude",
    ["Holy Priest"] = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
    ["Shadow"]      = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    -- Rogue
    ["Assassination"] = "Interface\\Icons\\Ability_Rogue_Eviscerate",
    ["Combat"]        = "Interface\\Icons\\Ability_BackStab",
    ["Subtlety"]      = "Interface\\Icons\\Ability_Stealth",
    -- Shaman
    ["Elemental"]   = "Interface\\Icons\\Spell_Nature_Lightning",
    ["Enhancement"] = "Interface\\Icons\\Spell_Nature_LightningShield",
    ["Restoration Shaman"] = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    -- Warlock
    ["Affliction"]  = "Interface\\Icons\\Spell_Shadow_DeathCoil",
    ["Demonology"]  = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
    ["Destruction"] = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    -- Warrior
    ["Arms"]        = "Interface\\Icons\\Ability_Warrior_Sunder",
    ["Fury"]        = "Interface\\Icons\\Ability_Warrior_InnerRage",
    ["Protection Warrior"] = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
}

-- Tab index → spec names in talent tree order (tab1, tab2, tab3)
local CLASS_SPECS = {
    ["Death Knight"] = {"Blood", "Frost DK", "Unholy"},
    ["Druid"]        = {"Balance", "Feral", "Restoration"},
    ["Hunter"]       = {"Beast Mastery", "Marksmanship", "Survival"},
    ["Mage"]         = {"Arcane", "Fire", "Frost"},
    ["Paladin"]      = {"Holy Pala", "Protection", "Retribution"},
    ["Priest"]       = {"Discipline", "Holy Priest", "Shadow"},
    ["Rogue"]        = {"Assassination", "Combat", "Subtlety"},
    ["Shaman"]       = {"Elemental", "Enhancement", "Restoration Shaman"},
    ["Warlock"]      = {"Affliction", "Demonology", "Destruction"},
    ["Warrior"]      = {"Arms", "Fury", "Protection Warrior"},
}

local CLASS_COLORS = {
    ["Death Knight"]={r=0.77,g=0.12,b=0.23}, ["Druid"]={r=1.00,g=0.49,b=0.04},
    ["Hunter"]={r=0.67,g=0.83,b=0.45},       ["Mage"]={r=0.25,g=0.78,b=0.92},
    ["Paladin"]={r=0.96,g=0.55,b=0.73},      ["Priest"]={r=1.00,g=1.00,b=1.00},
    ["Rogue"]={r=1.00,g=0.96,b=0.41},        ["Shaman"]={r=0.00,g=0.44,b=0.87},
    ["Warlock"]={r=0.53,g=0.53,b=0.93},      ["Warrior"]={r=0.78,g=0.61,b=0.23},
}
local CLASS_TABS = {"Death Knight","Druid","Hunter","Mage","Paladin","Priest","Rogue","Shaman","Warlock","Warrior","Raid","Overview"}
local TAB_LABELS = {["Death Knight"]="DK",["Druid"]="Druid",["Hunter"]="Hunter",["Mage"]="Mage",["Paladin"]="Paladin",["Priest"]="Priest",["Rogue"]="Rogue",["Shaman"]="Shaman",["Warlock"]="Warlock",["Warrior"]="Warrior",["Raid"]="Raid",["Overview"]="Overview"}

local TIER_COLORS = {
    [18]={r=0.20,g=0.60,b=0.80},  -- T0: 5-man silver-blue (key 18, not 0)
    [1]={r=0.70,g=0.36,b=0.00}, [2]={r=0.55,g=0.00,b=0.00},
    [3]={r=0.18,g=0.49,b=0.20}, [4]={r=0.08,g=0.40,b=0.75},
    [5]={r=0.42,g=0.10,b=0.54}, [6]={r=0.00,g=0.51,b=0.56},
    [7]={r=0.52,g=0.42,b=0.00}, [8]={r=0.68,g=0.08,b=0.34},
    [9]={r=0.33,g=0.43,b=0.48}, [10]={r=0.90,g=0.29,b=0.00},
    [11]={r=0.00,g=0.41,b=0.36},[12]={r=0.16,g=0.21,b=0.58},
    [13]={r=0.34,g=0.55,b=0.18},[14]={r=0.29,g=0.08,b=0.55},
    [15]={r=0.00,g=0.38,b=0.39},[16]={r=0.53,g=0.06,b=0.31},
    [17]={r=0.11,g=0.37,b=0.13},
}
local TIER_KEY_COLORS = {
    -- Classic (T1-T6): Stop Scan red (matches StopInspectBtn 0.90,0.20,0.20 * 0.35)
    [1]={r=0.315,g=0.07,b=0.07}, [2]={r=0.315,g=0.07,b=0.07},
    [3]={r=0.315,g=0.07,b=0.07}, [4]={r=0.315,g=0.07,b=0.07},
    [5]={r=0.315,g=0.07,b=0.07}, [6]={r=0.315,g=0.07,b=0.07},
    -- TBC (T7-T12): Log In All Bots green (matches LoginBtn 0.1,0.6,0.2 * 0.3)
    [7]={r=0.03,g=0.18,b=0.06},  [8]={r=0.03,g=0.18,b=0.06},
    [9]={r=0.03,g=0.18,b=0.06},  [10]={r=0.03,g=0.18,b=0.06},
    [11]={r=0.03,g=0.18,b=0.06}, [12]={r=0.03,g=0.18,b=0.06},
    -- WotLK (T13-T17): +Add Group blue (matches AddGroupBtn 0.10,0.40,0.70 * 0.35)
    [13]={r=0.035,g=0.14,b=0.245},[14]={r=0.035,g=0.14,b=0.245},
    [15]={r=0.035,g=0.14,b=0.245},[16]={r=0.035,g=0.14,b=0.245},
    [17]={r=0.035,g=0.14,b=0.245},
}
local TIER_LABELS = {
    [0]="T0 — 5-Man Dungeons",  -- display key stays 0
    [1]="T1 — Molten Core & Onyxia",   [2]="T2 — Blackwing Lair",
    [3]="T3 — Pre-AQ / Zul'Gurub",     [4]="T4 — AQ War",
    [5]="T5 — Anh'Qiraj",              [6]="T6 — Naxxramas (Kel'Thuzad)",
    [7]="T7 — Pre-TBC",                [8]="T8 — Karazhan / Gruul / Mag",
    [9]="T9 — SSC & Tempest Keep",     [10]="T10 — Hyjal & Black Temple",
    [11]="T11 — Zul'Aman",             [12]="T12 — Sunwell Plateau",
    [13]="T13 — Naxx / EoE / OS",      [14]="T14 — Ulduar",
    [15]="T15 — Trial of the Crusader",[16]="T16 — Icecrown Citadel",
    [17]="T17 — Ruby Sanctum",
}



local TIER_TOOLTIP_RAIDS = {
    [1]  = {"Molten Core", "Onyxia's Lair"},
    [2]  = {"Blackwing Lair"},
    [3]  = {"Zul'Gurub"},
    [4]  = {"Ruins of Ahn'Qiraj", "Ahn'Qiraj (AQ40)"},
    [5]  = {"Ahn'Qiraj (AQ40)"},
    [6]  = {"Naxxramas (Level 60)"},
    [7]  = {"Dark Portal Event"},
    [8]  = {"Karazhan", "Gruul's Lair", "Magtheridon's Lair"},
    [9]  = {"Serpentshrine Cavern", "Tempest Keep"},
    [10] = {"Mount Hyjal", "Black Temple"},
    [11] = {"Zul'Aman"},
    [12] = {"Sunwell Plateau"},
    [13] = {"Naxxramas", "Eye of Eternity", "Obsidian Sanctum"},
    [14] = {"Ulduar"},
    [15] = {"Trial of the Crusader"},
    [16] = {"Icecrown Citadel"},
    [17] = {"Ruby Sanctum"},
}

local ROLE_DEFS = {
    {key="TNK", label="Tank",   color={r=0.20,g=0.60,b=1.00}, icon="Interface\\Icons\\Ability_Warrior_DefensiveStance"},
    {key="HLR", label="Healer", color={r=0.20,g=1.00,b=0.40}, icon="Interface\\Icons\\Spell_ChargePositive"},
    {key="DPS", label="DPS",    color={r=1.00,g=0.40,b=0.20}, icon="Interface\\Icons\\Ability_DualWield"},
}
local ROLE_BY_KEY = {}
for _, rd in ipairs(ROLE_DEFS) do ROLE_BY_KEY[rd.key] = rd end

-- Module-level class token -> class name map (used by Add Target, Add Group, etc.)
local CLASS_TOKEN_MAP = {
    DEATHKNIGHT="Death Knight", DRUID="Druid", HUNTER="Hunter",
    MAGE="Mage", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
    SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"
}

-- Raid abbreviations for tooltips
local RAID_ABBR = {
    ["Molten Core"]="MC", ["Onyxia's Lair"]="Ony", ["Blackwing Lair"]="BWL",
    ["Zul'Gurub"]="ZG", ["Ruins of Ahn'Qiraj"]="AQ20", ["Ahn'Qiraj (AQ40)"]="AQ40",
    ["Ahn'Qiraj (AQ20)"]="AQ20", ["Naxxramas (Classic)"]="Naxx60",
    ["Karazhan"]="Kara", ["Gruul's Lair"]="Gruul", ["Magtheridon's Lair"]="Mag",
    ["Serpentshrine Cavern"]="SSC", ["Tempest Keep"]="TK",
    ["Mount Hyjal"]="Hyjal", ["Black Temple"]="BT", ["Zul'Aman"]="ZA",
    ["Sunwell Plateau"]="SW",
    ["Naxxramas 10"]="Naxx10", ["Naxxramas 25"]="Naxx25",
    ["Eye of Eternity 10"]="EoE10", ["Eye of Eternity 25"]="EoE25",
    ["Obsidian Sanctum 10"]="OS10", ["Obsidian Sanctum 25"]="OS25",
    ["Ulduar 10"]="Uld10", ["Ulduar 25"]="Uld25",
    ["Trial of the Crusader 10"]="ToC10", ["Trial of the Crusader 25"]="ToC25",
    ["Trial of the Grand Crusader 10"]="ToGC10", ["Trial of the Grand Crusader 25"]="ToGC25",
    ["Icecrown Citadel 10"]="ICC10", ["Icecrown Citadel 25"]="ICC25",
    ["ICC 10 Heroic"]="ICC10H", ["ICC 25 Heroic"]="ICC25H",
    ["Ruby Sanctum 10"]="RS10", ["Ruby Sanctum 25"]="RS25",
    ["N/A (5-Man)"]="5-Man",
}

-- Class icon mapping for raid tab
local CLASS_ICONS = {
    ["Death Knight"] = "Interface\\Icons\\Spell_DeathKnight_ClassIcon",
    ["Druid"]        = "Interface\\Icons\\Ability_Druid_Maul",
    ["Hunter"]       = "Interface\\Icons\\INV_Weapon_Bow_07",
    ["Mage"]         = "Interface\\Icons\\INV_Staff_13",
    ["Paladin"]      = "Interface\\Icons\\Spell_Holy_HolyBolt",
    ["Priest"]       = "Interface\\Icons\\INV_Staff_30",
    ["Rogue"]        = "Interface\\Icons\\Ability_Stealth",
    ["Shaman"]       = "Interface\\Icons\\Spell_Nature_BloodLust",
    ["Warlock"]      = "Interface\\Icons\\Spell_Nature_FaerieFire",
    ["Warrior"]      = "Interface\\Icons\\Ability_Warrior_BattleShout",
}

local activeTab = "Overview"
local classScroll = {}   -- classScroll[cls] = scroll offset (0-based row index)
local tabButtons = {}
local rowFrames = {}      -- rowFrames[i] = row frame for slot i
local raidRowFrames = {}  -- raid tab row frames (40 slots)
local raidDragPoll = CreateFrame("Frame")  -- module-level so it persists
local raidMouseHeld = false
local overviewRowFrames = {}   -- overview tab row frames (60 slots)
-- Raid drag state (module-level so RefreshRaidRows can reset)
local raidDragSource = nil
local raidDragOver   = nil
local LichborneAllCountLabels = nil
local LichborneRosterIlvlLabel = nil
local LichborneRosterGsLabel = nil
local LichborneRaidCountLabels = nil  -- populated in BuildRaidFrame, read in RefreshRaidRows
local inspectWait = 0   -- shared timer for CalcGS and button callbacks
LichborneDebugMode = false  -- toggled by DBG button on output box
local function DBG(msg) if LichborneDebugMode then LichborneOutput("|cffaaaaaa[DBG]|r "..msg) end end
local LichborneInspectGUID = nil  -- GUID captured after InspectUnit (GS); verified on INSPECT_READY
local LichborneSpecGUID    = nil  -- GUID captured after InspectUnit (Spec); verified on INSPECT_READY
local LichborneGroupScanActive = false  -- true while a group GS or Spec scan is running (limits retries to 1)
local LBFilter = {
    groupActive = false,  -- true while group filter is active (hides non-group members)
    showLevel   = false,  -- true: show level instead of row number in Overview/Class tabs
    hideRaid    = false,  -- true: hide characters NOT in the raid tab roster (show only raid members)
    showTierKey = true,   -- true: tier key bar visible; false: hidden (restored from DB at ADDON_LOADED)
}
local overviewFrameBuilt = false
local LichborneOverviewFrame = nil
local RefreshOverviewRows = nil  -- will be set after definition
local RefreshRaidRows       -- forward declaration
local UpdateSummary         -- forward declaration
local SetScanActive         -- forward declaration (module-scope for CalcGS/CalcSpec access)
local raidFrameBuilt = false
local setupDone = false
local dragSourceRow = nil   -- row frame being dragged
local dragOverTarget = nil  -- row frame mouse is currently over
local dragOverlay = nil     -- visual drag indicator

-- Buttons to lock during any invite or scan operation (excludes StopInspectBtn during scans, and excludes invite buttons locked separately)
local LOCKABLE_BUTTONS = {
    "LichborneAddTargetBtn",
    "LichborneAddGroupBtn",
    "LichborneUpdateGSBtn",
    "LichborneUpdateTargetSpecBtn",
    "LichborneUpdateGroupGSBtn",
    "LichborneUpdateGroupSpecBtn",
    "LichborneDisbandBtn",
    "LichborneLoginBtn",
    "LichborneLogoutBtn",
    "LichborneMaintBtn",
    "LichborneOrphanedBotsBtn",
}

local function SetButtonsLocked(locked)
    for _, name in ipairs(LOCKABLE_BUTTONS) do
        local btn = _G[name]
        if btn then
            if locked then btn:Disable(); btn:SetAlpha(0.35)
            else btn:Enable(); btn:SetAlpha(1.0) end
        end
    end
end

-- During an invite, also lock the Stop (scan) button since no scan is running
local function SetInviteActive(active)
    SetButtonsLocked(active)
    local stopBtn = _G["LichborneStopInspectBtn"]
    if stopBtn then
        if active then stopBtn:Disable(); stopBtn:SetAlpha(0.35)
        else stopBtn:Enable(); stopBtn:SetAlpha(1.0) end
    end
end

-- ── DB helpers ────────────────────────────────────────────────
-- Migrate old 'gear' field to 'ilvl'
local function MigrateGearField()
    if not LichborneTrackerDB or not LichborneTrackerDB.rows then return end
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.gear and not row.ilvl then
            row.ilvl = row.gear
            row.gear = nil
        end
        if not row.ilvl then
            local g = {}
            for i = 1, 17 do g[i] = 0 end
            row.ilvl = g
        end
        if not row.ilvlLink then
            local lnk = {}
            for i = 1, 17 do lnk[i] = "" end
            row.ilvlLink = lnk
        end
        if row.realGs == nil then row.realGs = 0 end
    end
end
local function DefaultRow(cls)
    local g = {}
    for i = 1, GEAR_SLOTS do g[i] = 0 end
    local lnk = {}
    for i = 1, GEAR_SLOTS do lnk[i] = "" end
    return {cls = cls or "", name = "", ilvl = g, ilvlLink = lnk, gs = 0, realGs = 0, spec = "", level = 0}
end

local function FindTrackedRowIndexByName(charName)
    if not charName or charName == "" then return nil end
    local needle = charName:lower()
    for i, row in ipairs(LichborneTrackerDB.rows or {}) do
        if row.name and row.name ~= "" and row.name:lower() == needle then
            return i, row
        end
    end
    return nil
end

local function RemoveCharacterReferences(charName)
    if not charName or charName == "" then return false end

    local removed = false
    local rowIndex, rowData = FindTrackedRowIndexByName(charName)
    if rowIndex and rowData then
        local cls = rowData.cls
        table.remove(LichborneTrackerDB.rows, rowIndex)
        removed = true
        -- Clamp scroll offset so we don't show empty space after deletion
        if cls and cls ~= "" and cls ~= "Raid" and cls ~= "Overview" then
            local remaining = 0
            for _, r in ipairs(LichborneTrackerDB.rows) do
                if r.cls == cls then remaining = remaining + 1 end
            end
            local maxOffset = math.max(0, remaining - MAX_ROWS)
            if (classScroll[cls] or 0) > maxOffset then
                classScroll[cls] = maxOffset
            end
        end
    end

    if LichborneTrackerDB.needs then
        LichborneTrackerDB.needs[charName:lower()] = nil
    end

    if LichborneTrackerDB.raidRosters then
        for _, roster in pairs(LichborneTrackerDB.raidRosters) do
            if type(roster) == "table" then
                for i, slot in ipairs(roster) do
                    if slot and slot.name and slot.name ~= "" and slot.name:lower() == charName:lower() then
                        roster[i] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
                    end
                end
            end
        end
    end

    return removed
end

local function EnsureClass(cls)
    if cls == "Raid" or cls == "Overview" then return end
    -- Ensure we have at least MAX_ROWS blank rows for this class
    local count = 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then count = count + 1 end
    end
    while count < MAX_ROWS do
        table.insert(LichborneTrackerDB.rows, DefaultRow(cls))
        count = count + 1
    end
end

local function GetAllClassRows(cls)
    -- Returns ALL row indices for a class regardless of page (for add/search ops)
    local out = {}
    if cls == "Raid" or cls == "Overview" then return out end
    for i, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then out[#out+1] = i end
    end
    return out
end

local classSortKey  = {}    -- classSortKey[cls]  nil|"spec"|"name"|"ilvl"|"gs"|"gear_N"
local classSortAsc  = {}    -- classSortAsc[cls]  bool; true=A-Z/low-high
local classSortHdrs = {}    -- key -> {lbl=str, fs=FontString} for indicator update

local function UpdateClassSortHeaders()
    local cls = activeTab
    local curKey = classSortKey[cls]
    local curAsc = classSortAsc[cls]
    for key, entry in pairs(classSortHdrs) do
        if curKey == key then
            local arrow = curAsc and " ^" or " v"
            entry.fs:SetText("|cffd4af37"..entry.lbl..arrow.."|r")
        else
            entry.fs:SetText("|cffd4af37"..entry.lbl.."|r")
        end
    end
end

local function GetGroupMemberNameSet()
    local set = {}
    local pname = UnitName("player")
    if pname then set[pname] = true end
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local n = UnitName("raid"..i)
            if n then set[n] = true end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local n = UnitName("party"..i)
            if n then set[n] = true end
        end
    end
    return set
end


local function GetClassRows(cls)
    local out = {}
    if cls == "Raid" or cls == "Overview" then return out end
    local offset = classScroll[cls] or 0
    local count = 0
    -- Collect all matching indices for this class
    local allIdx = {}
    for i, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then
            allIdx[#allIdx+1] = i
        end
    end
    -- Apply group filter: keep empty rows, hide named non-group members
    if LBFilter.groupActive then
        local gnames = GetGroupMemberNameSet()
        local filtered = {}
        for _, ai in ipairs(allIdx) do
            local n = LichborneTrackerDB.rows[ai].name or ""
            if n == "" or gnames[n] then filtered[#filtered+1] = ai end
        end
        allIdx = filtered
    end
    -- Apply hide-raid filter: exclude characters already in the raid tab roster
    if LBFilter.hideRaid then
        local raidFiltered = {}
        for _, ai in ipairs(allIdx) do
            local nm = LichborneTrackerDB.rows[ai].name or ""
            if nm ~= "" and IsInActiveRaid(nm) then raidFiltered[#raidFiltered+1] = ai end
        end
        allIdx = raidFiltered
    end
    -- Apply header-click sort if active; always compact filled before empty
    local curKey = classSortKey[cls]
    local curAsc = classSortAsc[cls]
    if curKey then
        table.sort(allIdx, function(a, b)
            local ra, rb = LichborneTrackerDB.rows[a], LichborneTrackerDB.rows[b]
            local na, nb = ra.name or "", rb.name or ""
            -- Empty rows always sink to the bottom
            if (na == "") ~= (nb == "") then return na ~= "" end
            if curKey == "spec" then
                local sa, sb2 = ra.spec or "", rb.spec or ""
                if sa ~= sb2 then
                    if curAsc then return sa < sb2 else return sa > sb2 end
                end
                return na < nb
            elseif curKey == "name" then
                if na ~= nb then
                    if curAsc then return na < nb else return na > nb end
                end
                return false
            elseif curKey == "ilvl" then
                local ga, gb2 = ra.gs or 0, rb.gs or 0
                if ga ~= gb2 then
                    if curAsc then return ga < gb2 else return ga > gb2 end
                end
                return na < nb
            elseif curKey == "gs" then
                local ga, gb2 = ra.realGs or 0, rb.realGs or 0
                if ga ~= gb2 then
                    if curAsc then return ga < gb2 else return ga > gb2 end
                end
                return na < nb
            else  -- "gear_N"
                local g = tonumber(curKey:sub(6)) or 1
                local ga = (ra.ilvl and ra.ilvl[g]) or 0
                local gb2 = (rb.ilvl and rb.ilvl[g]) or 0
                if ga ~= gb2 then
                    if curAsc then return ga < gb2 else return ga > gb2 end
                end
                return na < nb
            end
        end)
    else
        -- No sort key: compact filled rows to top, empty rows to bottom
        local filled, empty = {}, {}
        for _, i in ipairs(allIdx) do
            if LichborneTrackerDB.rows[i].name ~= "" then
                filled[#filled+1] = i
            else
                empty[#empty+1] = i
            end
        end
        allIdx = {}
        for _, i in ipairs(filled) do allIdx[#allIdx+1] = i end
        for _, i in ipairs(empty)  do allIdx[#allIdx+1] = i end
    end
    -- Clamp scroll offset and apply slice (stop at last filled row)
    local total = #allIdx
    local filledCount = 0
    for _, ai in ipairs(allIdx) do
        if LichborneTrackerDB.rows[ai].name ~= "" then filledCount = filledCount + 1 end
    end
    local maxOffset = math.max(0, filledCount - MAX_ROWS)
    offset = math.min(math.max(0, offset), maxOffset)
    classScroll[cls] = offset
    for i = offset + 1, math.min(offset + MAX_ROWS, total) do
        out[#out+1] = allIdx[i]
    end
    return out
end

-- ── Item quality colors (matches WoW item rarity) ─────────────
local QUALITY_COLORS = {
    [0] = {r=0.62, g=0.62, b=0.62},  -- Poor (grey)
    [1] = {r=1.00, g=1.00, b=1.00},  -- Common (white)
    [2] = {r=0.12, g=0.85, b=0.12},  -- Uncommon (green)
    [3] = {r=0.00, g=0.44, b=0.87},  -- Rare (blue)
    [4] = {r=0.64, g=0.21, b=0.93},  -- Epic (purple)
    [5] = {r=1.00, g=0.50, b=0.00},  -- Legendary (orange)
    [6] = {r=0.90, g=0.80, b=0.50},  -- Artifact (pale gold)
}

local function GetItemQualityColor(link)
    if not link or link == "" then return nil end
    local _, _, rarity = GetItemInfo(link)
    if rarity then return QUALITY_COLORS[rarity] end
    return nil
end

-- ── Tier color ────────────────────────────────────────────────
local function ApplyTierColor(gb, val, qualityColor)
    local n = tonumber(val) or 0
    local c = TIER_COLORS[n]
    if c then
        gb:SetBackdropColor(c.r, c.g, c.b, 1)
        gb:SetBackdropBorderColor(math.min(c.r*1.5,1), math.min(c.g*1.5,1), math.min(c.b*1.5,1), 1)
    else
        gb:SetBackdropColor(0.05, 0.07, 0.14, 1)
        gb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
    end
    -- Text color: use item quality color if available, otherwise white
    if qualityColor then
        gb:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
    elseif c and (0.299*c.r + 0.587*c.g + 0.114*c.b) > 0.45 then
        gb:SetTextColor(0.05, 0.05, 0.05)
    else
        gb:SetTextColor(1, 1, 1)
    end
end

-- ── Tab highlight ─────────────────────────────────────────────
local allSortMenus = {}
local function CloseAllSortMenus()
    for _, m in ipairs(allSortMenus) do m:Hide() end
end

local activeInviteFrame = nil

local function UpdateInviteButtons()
    -- Both invite buttons always show in their normal state
    if LichborneInviteRaidBtn then
        LichborneInviteRaidBtn:Show()
        LichborneInviteRaidBtn:SetBackdropColor(0.30, 0.15, 0.01, 1)
        if LichborneInviteRaidBtn.lbl then
            LichborneInviteRaidBtn.lbl:SetText("|cffd4af37Invite Raid|r")
        end
    end
    if _G["LichborneInviteGroupBtn"] then
        local grpBtn = _G["LichborneInviteGroupBtn"]
        grpBtn:Show()
        grpBtn:SetBackdropColor(0.035, 0.14, 0.245, 1)
        if grpBtn.lbl then grpBtn.lbl:SetText("|cffd4af37Invite Group|r") end
    end
    -- Stop Invite overlay: covers both invite buttons when an invite is active
    if _G["LichborneStopInviteBtn"] then
        if activeInviteFrame then
            _G["LichborneStopInviteBtn"]:Show()
        else
            _G["LichborneStopInviteBtn"]:Hide()
        end
    end
end

local function UpdateTabs()
    if LichborneSpecMenu then LichborneSpecMenu:Hide() end
    CloseAllSortMenus()
    if _G["LichborneOverviewGroupMenu"] then _G["LichborneOverviewGroupMenu"]:Hide() end
    -- Close raid tab dropdowns when switching away
    if _G["LichborneRaidTierMenu"] then _G["LichborneRaidTierMenu"]:Hide() end
    if _G["LichborneRaidRaidMenu"] then _G["LichborneRaidRaidMenu"]:Hide() end
    if _G["LichborneRaidGroupMenu"] then _G["LichborneRaidGroupMenu"]:Hide() end
    for cls, btn in pairs(tabButtons) do
        local c = CLASS_COLORS[cls]
        if cls == activeTab then
            btn:SetAlpha(1.0)
            if c then
                btn.bg:SetTexture(c.r*0.45, c.g*0.45, c.b*0.45, 1)
                btn.bottomLine:SetTexture(c.r, c.g, c.b, 1)
            elseif cls == "Raid" then
                btn.bg:SetTexture(0.42, 0.22, 0.00, 1)
                btn.bottomLine:SetTexture(0.70, 0.36, 0.00, 1)
            elseif cls == "Overview" then
                btn.bg:SetTexture(0.20, 0.45, 0.20, 1)
                btn.bottomLine:SetTexture(0.40, 0.90, 0.40, 1)
            end
        else
            btn:SetAlpha(0.5)
            btn.bg:SetTexture(0.05, 0.07, 0.12, 1)
            btn.bottomLine:SetTexture(0, 0, 0, 0)
        end
    end
    -- Show/hide raid frame vs normal rows+headers
    if LichborneRaidFrame then
        local isRaid = activeTab == "Raid"
        local isAll = activeTab == "Overview"
        if isAll then
            if LichborneOverviewFrame then LichborneOverviewFrame:Show() end
            if LichborneRaidFrame then LichborneRaidFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Hide() end
            if LichborneAvgBar then LichborneAvgBar:Hide() end
            if LichborneCountBar then LichborneCountBar:Hide() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Hide() end
            for _, rf in ipairs(rowFrames) do rf:Hide() end
            UpdateInviteButtons()
        elseif isRaid then
            LichborneRaidFrame:Show()
            if LichborneOverviewFrame then LichborneOverviewFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Hide() end
            if LichborneAvgBar then LichborneAvgBar:Hide() end
            if LichborneCountBar then LichborneCountBar:Hide() end
            for _, rf in ipairs(rowFrames) do rf:Hide() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Show() end
            UpdateInviteButtons()
        elseif not isAll then
            LichborneRaidFrame:Hide()
            if LichborneOverviewFrame then LichborneOverviewFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Show() end
            if LichborneAvgBar then LichborneAvgBar:Show() end
            if LichborneCountBar then LichborneCountBar:Show() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Hide() end
            UpdateInviteButtons()
        end
    end
end

-- ── Row hover highlight helper ─────────────────────────────────
-- Hooks OnEnter/OnLeave on a child frame to show/hide the parent row highlight
local function HookRowHighlight(child, row, hovTex)
    local orig_enter = child:GetScript("OnEnter")
    local orig_leave = child:GetScript("OnLeave")
    child:SetScript("OnEnter", function()
        hovTex:SetTexture(0.78, 0.61, 0.23, 0.12)
        if orig_enter then orig_enter() end
    end)
    child:SetScript("OnLeave", function()
        -- Only hide if mouse isn't still on the row
        local f = GetMouseFocus()
        if f ~= row then
            hovTex:SetTexture(0, 0, 0, 0)
        end
        if orig_leave then orig_leave() end
    end)
end


local needsCellFrames = {}

local MAX_NEEDS_DISPLAY = MAX_NEEDS

local function RefreshNeedsCell(cf, charName)
    if not cf or not cf.icons then return end
    local needs = GetNeeds(charName)
    local active = {}
    for _, slot in ipairs(NEEDS_SLOTS) do
        if needs[slot.key] then active[#active+1] = slot end
    end
    local show = math.min(#active, MAX_NEEDS_DISPLAY)
    for idx = 1, show do
        local ic = cf.icons[idx]
        if ic then ic:SetTexture(active[idx].icon); ic:SetAlpha(1); ic:Show() end
    end
    for j = show+1, MAX_NEEDS_DISPLAY do
        if cf.icons[j] then cf.icons[j]:Hide() end
    end
end

local function RefreshAllNeedsCells()
    for _, entry in ipairs(needsCellFrames) do
        if entry.frame and entry.getCharName then
            RefreshNeedsCell(entry.frame, entry.getCharName())
        end
    end
end

local function ClosePicker()
    if needsPicker then needsPicker:Hide() end
    needsPickerOwner = nil
end

local function BuildPickerIfNeeded()
    if needsPicker then return end
    local COLS, BSIZE, PAD = 5, 26, 4
    local ROWS = math.ceil(#NEEDS_SLOTS / COLS)
    local W = COLS*(BSIZE+PAD)+PAD
    local H = ROWS*(BSIZE+PAD)+PAD+20
    local pf = CreateFrame("Frame","LichborneNeedsPicker",UIParent)
    pf:SetFrameStrata("TOOLTIP"); pf:SetFrameLevel(200)
    pf:SetSize(W,H)
    pf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    pf:SetBackdropColor(0.04,0.06,0.12,0.98); pf:SetBackdropBorderColor(0.78,0.61,0.23,1)
    local ttl = pf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    ttl:SetPoint("TOPLEFT",pf,"TOPLEFT",6,-5); pf.title=ttl
    pf.slotBtns = {}
    for si, slot in ipairs(NEEDS_SLOTS) do
        local col = (si-1)%COLS
        local row = math.floor((si-1)/COLS)
        local btn = CreateFrame("Button",nil,pf)
        btn:SetSize(BSIZE,BSIZE)
        btn:SetPoint("TOPLEFT",pf,"TOPLEFT",PAD+col*(BSIZE+PAD),-20-PAD-row*(BSIZE+PAD))
        btn:SetFrameLevel(pf:GetFrameLevel()+1)
        local bg=btn:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(btn); bg:SetTexture(0.08,0.10,0.18,1)
        local tex=btn:CreateTexture(nil,"ARTWORK")
        tex:SetPoint("CENTER",btn,"CENTER",0,0); tex:SetSize(BSIZE-4,BSIZE-4); tex:SetTexture(slot.icon)
        btn.tex=tex
        local hi=btn:CreateTexture(nil,"OVERLAY")
        hi:SetAllPoints(btn); hi:SetTexture(0.3,0.8,0.3,0.35); hi:Hide(); btn.hi=hi
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
        btn:SetBackdropColor(0.08,0.10,0.18,1); btn:SetBackdropBorderColor(0.25,0.35,0.55,0.8)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        btn.slotKey=slot.key; btn.slotLabel=slot.label
        btn:SetScript("OnEnter",function()
            -- Update picker title to show slot name instead of using GameTooltip
            if pf.title then
                local owned = needsPickerOwner and GetNeeds(needsPickerOwner)[slot.key]
                local hint = owned and "|cffff6666  (right-click to remove)|r" or "|cff66ff66  click to mark|r"
                pf.title:SetText("|cffC69B3A"..slot.label.."|r"..hint)
            end
        end)
        btn:SetScript("OnLeave",function()
            -- Restore title to character name
            if pf.title and needsPickerOwner then
                pf.title:SetText("|cffC69B3ANeeds: |r|cffffff00"..needsPickerOwner.."|r")
            end
        end)
        btn:SetScript("OnClick",function(_, mouseButton)
            if not needsPickerOwner or needsPickerOwner=="" then return end
            local k=slot.key
            local cur=GetNeeds(needsPickerOwner)[k]
            if mouseButton=="RightButton" then SetNeed(needsPickerOwner,k,false)
            else SetNeed(needsPickerOwner,k,not cur) end
            local needs2=GetNeeds(needsPickerOwner)
            local count2=0; for _ in pairs(needs2) do count2=count2+1 end
            for _,sb in ipairs(pf.slotBtns) do
                if needs2[sb.slotKey] then
                    sb.hi:Show(); sb:SetBackdropBorderColor(0.3,0.8,0.3,0.9); sb.tex:SetAlpha(1)
                elseif count2 >= MAX_NEEDS then
                    sb.hi:Hide(); sb:SetBackdropBorderColor(0.15,0.15,0.15,0.5); sb.tex:SetAlpha(0.35)
                else
                    sb.hi:Hide(); sb:SetBackdropBorderColor(0.25,0.35,0.55,0.8); sb.tex:SetAlpha(1)
                end
            end
            RefreshAllNeedsCells()
        end)
        btn:RegisterForClicks("LeftButtonUp","RightButtonUp")
        pf.slotBtns[si]=btn
    end
    -- Close when mouse leaves the picker (with a small grace period)
    pf.closeTimer = 0
    pf:SetScript("OnUpdate",function(_, elapsed)
        if not pf:IsShown() then return end
        if not MouseIsOver(pf) then
            pf.closeTimer = (pf.closeTimer or 0) + elapsed
            if pf.closeTimer > 0.3 then
                ClosePicker()
            end
        else
            pf.closeTimer = 0
        end
    end)
    -- ESC closes picker but not the main frame
    pf:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then ClosePicker() end
    end)
    pf:EnableKeyboard(true)
    needsPicker=pf
end

local function OpenNeedsPicker(anchorFrame, charName)
    if not charName or charName=="" then return end
    BuildPickerIfNeeded()
    needsPickerOwner=charName
    needsPicker.title:SetText("|cffC69B3ANeeds: |r|cffffff00"..charName.."|r")
    local needs3=GetNeeds(charName)
    local count3=0; for _ in pairs(needs3) do count3=count3+1 end
    for _,sb in ipairs(needsPicker.slotBtns) do
        if needs3[sb.slotKey] then
            sb.hi:Show(); sb:SetBackdropBorderColor(0.3,0.8,0.3,0.9); sb.tex:SetAlpha(1)
        elseif count3 >= MAX_NEEDS then
            sb.hi:Hide(); sb:SetBackdropBorderColor(0.15,0.15,0.15,0.5); sb.tex:SetAlpha(0.35)
        else
            sb.hi:Hide(); sb:SetBackdropBorderColor(0.25,0.35,0.55,0.8); sb.tex:SetAlpha(1)
        end
    end
    needsPicker:ClearAllPoints()
    needsPicker:SetPoint("TOPLEFT",anchorFrame,"BOTTOMLEFT",0,-2)
    needsPicker.closeTimer = 0
    needsPicker:Show(); needsPicker:Raise()
end

local function MakeNeedsCell(parent, xOff, rowH, getCharName, hovTex, overrideW)
    local cellW = overrideW or 80
    local cf = CreateFrame("Button",nil,parent)
    cf:SetPoint("LEFT",parent,"LEFT",xOff,0)
    cf:SetSize(cellW,rowH-2)
    cf:SetFrameLevel(parent:GetFrameLevel()+4)
    cf:RegisterForClicks("LeftButtonUp","RightButtonUp")
    cf:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
    cf:SetBackdropColor(0.04,0.06,0.12,0.9); cf:SetBackdropBorderColor(0.15,0.22,0.38,0.6)
    -- No SetHighlightTexture - border changes on hover instead
    cf.icons={}
    for si=1,MAX_NEEDS_DISPLAY do
        local ic=cf:CreateTexture(nil,"ARTWORK")
        ic:SetSize(NEEDS_ICON_SIZE,NEEDS_ICON_SIZE)
        ic:SetPoint("LEFT",cf,"LEFT",2+(si-1)*(NEEDS_ICON_SIZE+2),0)
        ic:Hide(); cf.icons[si]=ic
    end
    cf:SetScript("OnClick",function(_, mouseButton)
        local cname=getCharName()
        if not cname or cname=="" then return end
        if mouseButton=="RightButton" then
            if LichborneTrackerDB.needs then LichborneTrackerDB.needs[cname:lower()]={} end
            RefreshAllNeedsCells(); ClosePicker(); return
        end
        if needsPicker and needsPicker:IsShown() and needsPickerOwner==cname then
            ClosePicker()
        else
            ClosePicker(); OpenNeedsPicker(cf,cname)
        end
    end)
    cf:SetScript("OnEnter",function()
        if hovTex then hovTex:SetTexture(0.78,0.61,0.23,0.12) end
        cf:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
        local cname=getCharName()
        if cname and cname~="" then
            GameTooltip:SetOwner(cf,"ANCHOR_RIGHT")
            GameTooltip:AddLine("|cffC69B3ANeeds:|r "..cname,1,1,1)
            local needs4=GetNeeds(cname)
            local any=false
            for _,slot in ipairs(NEEDS_SLOTS) do
                if needs4[slot.key] then GameTooltip:AddLine("  "..slot.label,1,0.6,0.2); any=true end
            end
            if not any then GameTooltip:AddLine("  Nothing marked",0.5,0.5,0.5) end
            GameTooltip:AddLine("|cff888888Click to edit  (max 2)  Right-click clears all|r",0.6,0.6,0.6)
            GameTooltip:Show()
        end
    end)
    cf:SetScript("OnLeave",function()
        if hovTex then hovTex:SetTexture(0,0,0,0) end
        cf:SetBackdropBorderColor(0.15,0.22,0.38,0.6)
        GameTooltip:Hide()
    end)
    needsCellFrames[#needsCellFrames+1]={frame=cf,getCharName=getCharName}
    return cf
end




-- ── Raid tab: RefreshRaidRows ──────────────────────────────────
local raidSortKey     = nil    -- nil|"spec"|"name"|"ilvl"|"gs"|"role"
local raidSortAsc     = true   -- direction; for role: true=TNK first, false=HLR first
local raidSortPending = false  -- true only while a header-click sort is waiting to fire once
local raidSortHdrs    = {}     -- key -> {lbl=str, fs=FontString}
local allSortKey   = nil   -- nil|"spec"|"name"|"ilvl"|"gs"|"inraid"
local allSortAsc   = true  -- true=A-Z/low-high/inraid-first
local allSortHdrs  = {}    -- key -> {lbl=str, fsList={FontString,...}}

local function UpdateRaidSortHeaders()
    for key, entry in pairs(raidSortHdrs) do
        if raidSortKey == key then
            local arrow
            if key == "role" then
                arrow = raidSortAsc and " (T)" or " (H)"
            elseif key == "spec" then
                arrow = raidSortAsc and " ^" or " v"
            else
                arrow = raidSortAsc and " ^" or " v"
            end
            entry.fs:SetText("|cffd4af37"..entry.lbl..arrow.."|r")
        else
            entry.fs:SetText("|cffd4af37"..entry.lbl.."|r")
        end
    end
end

local ROLE_ORDER_TNK = {TNK=1, HLR=2, DPS=3}
local ROLE_ORDER_HLR = {HLR=1, TNK=2, DPS=3}

local function SortRaidRows()
    local roster, raidSize = GetCurrentRoster()
    local filled, empty = {}, {}
    for i = 1, MAX_RAID_SLOTS do
        local r = roster[i]
        if r and r.name and r.name ~= "" then
            filled[#filled+1] = r
        else
            empty[#empty+1] = {name="", cls="", spec="", gs=0, realGs=0}
        end
    end
    if not raidSortKey then
        -- No sort active: just compact (filled first, empty last) and return
        local idx = 1
        for _, r in ipairs(filled) do roster[idx] = r; idx = idx + 1 end
        for _, r in ipairs(empty)  do roster[idx] = r; idx = idx + 1 end
        return
    end
    if raidSortPending then
        raidSortPending = false
        if raidSortKey == "spec" then
            -- Class A-Z or Z-A; spec within class always A-Z; then name
            table.sort(filled, function(a, b)
                local ca, cb = a.cls or "", b.cls or ""
                if ca ~= cb then
                    if raidSortAsc then return ca < cb else return ca > cb end
                end
                local sa, sb2 = a.spec or "", b.spec or ""
                if sa ~= sb2 then return sa < sb2 end
                return (a.name or "") < (b.name or "")
            end)
        elseif raidSortKey == "name" then
            table.sort(filled, function(a, b)
                local na, nb = a.name or "", b.name or ""
                if na ~= nb then
                    if raidSortAsc then return na < nb else return na > nb end
                end
                return false
            end)
        elseif raidSortKey == "ilvl" then
            table.sort(filled, function(a, b)
                local ga, gb2 = a.gs or 0, b.gs or 0
                if ga ~= gb2 then
                    if raidSortAsc then return ga < gb2 else return ga > gb2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif raidSortKey == "gs" then
            table.sort(filled, function(a, b)
                local ga, gb2 = a.realGs or 0, b.realGs or 0
                if ga ~= gb2 then
                    if raidSortAsc then return ga < gb2 else return ga > gb2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif raidSortKey == "role" then
            local order = raidSortAsc and ROLE_ORDER_TNK or ROLE_ORDER_HLR
            table.sort(filled, function(a, b)
                local ra = order[a.role or ""] or 4
                local rb2 = order[b.role or ""] or 4
                if ra ~= rb2 then return ra < rb2 end
                return (a.name or "") < (b.name or "")
            end)
        end
    end
    local idx = 1
    for _, r in ipairs(filled) do roster[idx] = r; idx = idx + 1 end
    for _, r in ipairs(empty)  do roster[idx] = r; idx = idx + 1 end
end


function RefreshRaidRows()
    if not raidRowFrames or #raidRowFrames == 0 then return end
    -- Cancel any in-progress drag when refreshing
    raidDragSource = nil

    -- Remove anyone from the current roster who no longer exists in class tabs
    local classTabNames = {}
    if LichborneTrackerDB.rows then
        for _, classRow in ipairs(LichborneTrackerDB.rows) do
            if classRow.name and classRow.name ~= "" then
                classTabNames[classRow.name:lower()] = true
            end
        end
    end
    local roster, _ = GetCurrentRoster()
    for i = 1, 40 do
        if roster[i] and roster[i].name and roster[i].name ~= "" then
            if not classTabNames[roster[i].name:lower()] then
                roster[i] = {name="", cls="", spec="", gs=0}
            end
        end
    end

    SortRaidRows()
    local rows, raidSize = GetCurrentRoster()
    for i = 1, MAX_RAID_SLOTS do
        local rf = raidRowFrames[i]
        if not rf then break end
        -- Hide rows beyond current raid size
        if i > raidSize then
            rf:Hide()
        else
            rf:Show()
        end
        local data = rows[i] or {name="", cls="", spec="", gs=0, role="", notes=""}

        -- Class icon
        local cIcon = CLASS_ICONS[data.cls]
        if rf.classIcon then
            if cIcon then rf.classIcon:SetTexture(cIcon); rf.classIcon:SetAlpha(1)
            else rf.classIcon:SetTexture(0,0,0,0) end
        end

        -- Sync spec from class tab rows (refresh keeps it current)
        if data.name and data.name ~= "" then
            for _, classRow in ipairs(LichborneTrackerDB.rows) do
                if classRow.name and classRow.name:lower() == data.name:lower() then
                    if classRow.spec and classRow.spec ~= "" then
                        data.spec = classRow.spec
                    end
                    data.realGs = classRow.realGs or 0
                    break
                end
            end
        end

        -- Spec icon
        local sIcon = data.spec and data.spec ~= "" and SPEC_ICONS[data.spec]
        if rf.specIcon then
            if sIcon then
                rf.specIcon:SetTexture(sIcon); rf.specIcon:SetAlpha(1)
            elseif data.name and data.name ~= "" then
                rf.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); rf.specIcon:SetAlpha(0.2)
            else
                rf.specIcon:SetTexture(0,0,0,0)
            end
        end

        -- Needs cell refresh
        if rf.needsCell then
            RefreshNeedsCell(rf.needsCell, data.name or "")
        end

        -- Role button
        if rf.roleBtn and rf.roleLbl then
            if not data.role then data.role = "" end
            local rd = ROLE_BY_KEY[data.role]
            if rd then
                rf.roleLbl:SetText("")
                rf.roleBtn:SetBackdropBorderColor(rd.color.r, rd.color.g, rd.color.b, 0.9)
                if rf.roleIcon then rf.roleIcon:SetTexture(rd.icon); rf.roleIcon:SetAlpha(1.0) end
            else
                rf.roleLbl:SetText("")
                rf.roleBtn:SetBackdropBorderColor(0.20,0.30,0.50,0.3)
                if rf.roleIcon then rf.roleIcon:SetTexture(0,0,0,0) end
            end
            local idx = i
            rf.roleBtn:SetScript("OnEnter", function()
                local roster2, _ = GetCurrentRoster()
                local d2 = roster2[idx]
                GameTooltip:SetOwner(rf.roleBtn, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Assign Role  (click to cycle)",1,1,1)
                for _, rdef in ipairs(ROLE_DEFS) do
                    local cur = (d2 and d2.role == rdef.key) and " ◄" or ""
                    GameTooltip:AddLine("|T"..rdef.icon..":14:14|t  "..rdef.key.."  "..rdef.label..cur, rdef.color.r, rdef.color.g, rdef.color.b)
                end
                GameTooltip:AddLine("--  None (clear)", 0.5,0.6,0.7)
                GameTooltip:Show()
            end)
            rf.roleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            rf.roleBtn:SetScript("OnClick", function()
                local roster2, _ = GetCurrentRoster()
                local d2 = roster2[idx]
                if not d2 or not d2.name or d2.name == "" then return end
                local cur = d2.role or ""
                -- Cycle: ""->TNK->HLR->DPS->""
                if cur == "" or cur == nil then
                    d2.role = "TNK"
                elseif cur == "TNK" then
                    d2.role = "HLR"
                elseif cur == "HLR" then
                    d2.role = "DPS"
                else
                    d2.role = ""
                end
                RefreshRaidRows()
            end)
        end

        -- Notes
        if rf.notesBox then
            rf.notesBox:SetScript("OnTextChanged", nil)
            rf.notesBox:SetText(data.notes or "")
            local idx = i
            rf.notesBox:SetScript("OnTextChanged", function()
                local r2, _ = GetCurrentRoster()
                if r2[idx] then r2[idx].notes = rf.notesBox:GetText() end
            end)
        end

        -- Name
        if rf.nameBox then
            rf.nameBox:SetScript("OnTextChanged", nil)
            rf.nameBox:SetText(data.name or "")
            local c = CLASS_COLORS[data.cls]
            if c then rf.nameBox:SetTextColor(c.r, c.g, c.b)
            else rf.nameBox:SetTextColor(0.9, 0.95, 1.0) end
            local idx = i
            rf.nameBox:SetScript("OnTextChanged", function()
local r2, _ = GetCurrentRoster(); r2[idx].name = rf.nameBox:GetText()
            end)
        end

        -- iLvl (read-only)
        if rf.gsBox then
            rf.gsBox:SetScript("OnTextChanged", nil)
            rf.gsBox:SetText(data.gs and data.gs > 0 and tostring(data.gs) or "")
            rf.gsBox.readOnly = rf.gsBox:GetText()
            rf.gsBox:SetScript("OnTextChanged", function()
                if rf.gsBox:GetText() ~= (rf.gsBox.readOnly or "") then
                    rf.gsBox:SetText(rf.gsBox.readOnly or "")
                end
            end)
        end

        -- GS (read-only)
        if rf.realGsBox then
            rf.realGsBox:SetScript("OnTextChanged", nil)
            rf.realGsBox:SetText(data.realGs and data.realGs > 0 and tostring(data.realGs) or "")
            rf.realGsBox.readOnly = rf.realGsBox:GetText()
            rf.realGsBox:SetScript("OnTextChanged", function()
                if rf.realGsBox:GetText() ~= (rf.realGsBox.readOnly or "") then
                    rf.realGsBox:SetText(rf.realGsBox.readOnly or "")
                end
            end)
        end




        -- Spec icon hover - reads live from rows[i] at hover time
        if rf.specBtn then
            local rowIdx = i
            rf.specBtn:SetScript("OnEnter", function()
                local roster4, _ = GetCurrentRoster()
                local d4 = roster4[rowIdx]
                local spec = d4 and d4.spec or ""
                local cls = d4 and d4.cls or ""
                local c = cls ~= "" and CLASS_COLORS[cls]
                GameTooltip:SetOwner(rf.specBtn, "ANCHOR_RIGHT")
                if spec ~= "" then GameTooltip:AddLine(spec, 1, 1, 1) end
                if cls ~= "" then
                    if c then GameTooltip:AddLine(cls, c.r, c.g, c.b)
                    else GameTooltip:AddLine(cls, 0.8, 0.8, 0.9) end
                end
                if spec == "" and cls == "" then GameTooltip:AddLine("Empty", 0.4, 0.4, 0.4) end
                GameTooltip:Show()
            end)
            rf.specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        -- Delete button
        if rf.delBtn then
            local idx = i
            rf.delBtn:SetScript("OnClick", function()
local r5, _ = GetCurrentRoster(); r5[idx] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
                RefreshRaidRows()
            end)
        end
    end

    -- Update raid class count bar
    if LichborneRaidCountLabels then
        local raidCounts = {}
        for _, cls in ipairs(CLASS_TABS) do if cls ~= "Raid" then raidCounts[cls] = 0 end end
        local rosterC, sizeC = GetCurrentRoster()
        for i2 = 1, sizeC do
            local r2 = rosterC[i2]
            if r2 and r2.name and r2.name ~= "" and raidCounts[r2.cls] then
                raidCounts[r2.cls] = raidCounts[r2.cls] + 1
            end
        end
        for cls, lbl in pairs(LichborneRaidCountLabels) do
            local c = CLASS_COLORS[cls]
            if c then
                local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
                local n = raidCounts[cls] or 0
                lbl:SetText(hex..(TAB_LABELS[cls])..": |cffd4af37"..n.."|r")
                -- Color background if has members
                local sw = lbl:GetParent()
                if sw and sw.bg then
                    if n > 0 then sw.bg:SetTexture(c.r*0.25, c.g*0.25, c.b*0.30, 1)
                    else sw.bg:SetTexture(0.08, 0.10, 0.18, 1) end
                end
            end
        end
    end
end



-- ── Build row frames (once) ───────────────────────────────────
local function BuildRows(parent, yStart)
    if #rowFrames > 0 then return end  -- already built

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "LichborneRow"..i, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yStart - (i-1)*ROW_HEIGHT)
        row:SetSize(1086, ROW_HEIGHT)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetTexture(0.05, 0.07, 0.13, 1)
        row.bg = bg

        -- Hover
        local hov = row:CreateTexture(nil, "OVERLAY")
        hov:SetAllPoints(row)
        hov:SetTexture(0, 0, 0, 0)
        row.hov = hov

        -- Drop highlight
        local dropHi = row:CreateTexture(nil, "OVERLAY")
        dropHi:SetAllPoints(row)
        dropHi:SetTexture(0, 0, 0, 0)
        row.dropHi = dropHi

        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
            if not dragSourceRow then
                row.hov:SetTexture(0.78, 0.61, 0.23, 0.12)
            end
        end)
        row:SetScript("OnLeave", function()
            row.hov:SetTexture(0, 0, 0, 0)
        end)

        -- Drag handle
        local dragBtn = CreateFrame("Button", nil, row)
        dragBtn:SetPoint("LEFT", row, "LEFT", DRAG_OFF, 0)
        dragBtn:SetSize(COL_DRAG_W, ROW_HEIGHT)
        dragBtn:SetFrameLevel(row:GetFrameLevel() + 5)
        local dragTex = dragBtn:CreateTexture(nil, "ARTWORK")
        dragTex:SetAllPoints(dragBtn)
        dragTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        dragTex:SetVertexColor(0.3, 0.4, 0.6, 0)  -- invisible by default
        row.dragTex = dragTex
        local dragLbl = dragBtn:CreateFontString(nil, "OVERLAY")
        dragLbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        dragLbl:SetAllPoints(dragBtn)
        dragLbl:SetJustifyH("CENTER"); dragLbl:SetJustifyV("MIDDLE")
        dragLbl:SetTextColor(0.4, 0.4, 0.5, 1.0)
        dragLbl:SetText(tostring(i))
        row.dragLbl = dragLbl
        dragBtn:SetScript("OnEnter", function()
            if not dragSourceRow then
                row.dragLbl:SetTextColor(0.78, 0.61, 0.23, 1.0)
                GameTooltip:SetOwner(dragBtn, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Drag to reorder", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        dragBtn:SetScript("OnLeave", function()
            if not dragSourceRow then
                row.dragLbl:SetTextColor(0.4, 0.4, 0.5, 1.0)
            end
            GameTooltip:Hide()
        end)
        dragBtn:SetScript("OnMouseDown", function(_, mouseButton)
            if mouseButton == "LeftButton" and row.dbIndex then
                local data = LichborneTrackerDB.rows[row.dbIndex]
                if data and data.name and data.name ~= "" then
                    dragSourceRow = row
                    row.dragLbl:SetTextColor(0.78, 0.61, 0.23, 1.0)
                    row.hov:SetTexture(0.9, 0.7, 0.1, 0.12)
                end
            end
        end)

        -- Spec icon (click to set spec manually)
        local specBtn = CreateFrame("Button", "LichborneRow"..i.."SpecBtn", row)
        specBtn:SetPoint("LEFT", row, "LEFT", SPEC_OFF, 0)
        specBtn:SetSize(COL_SPEC_W - 2, ROW_HEIGHT - 2)
        specBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local specIcon = specBtn:CreateTexture(nil, "ARTWORK")
        specIcon:SetAllPoints(specBtn)
        specIcon:SetTexture(0, 0, 0, 0)
        specBtn.icon = specIcon
        row.specIcon = specIcon
        row.specBtn = specBtn
        specBtn:SetScript("OnEnter", function()
            if row.dbIndex and LichborneTrackerDB.rows[row.dbIndex] then
                local spec = LichborneTrackerDB.rows[row.dbIndex].spec or ""
                GameTooltip:SetOwner(specBtn, "ANCHOR_RIGHT")
                GameTooltip:AddLine(spec ~= "" and spec or "No spec set", 1, 1, 1)
                GameTooltip:AddLine("Click to set spec manually", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)
        specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        specBtn:SetScript("OnClick", function()
            if not row.dbIndex then return end
            local rowData = LichborneTrackerDB.rows[row.dbIndex]
            if not rowData then return end
            -- Don't allow setting spec on empty rows
            if not rowData.name or rowData.name == "" then return end
            -- Only show specs for the row's own class, not the active tab
            local cls = rowData.cls or ""
            local specNames = CLASS_SPECS[cls]
            if not specNames then return end
            -- Build a simple dropdown menu
            if LichborneSpecMenu and LichborneSpecMenu:IsShown() then
                LichborneSpecMenu:Hide()
                return
            end
            if not LichborneSpecMenu then
                LichborneSpecMenu = CreateFrame("Frame", "LichborneSpecMenu", UIParent)
                LichborneSpecMenu:SetFrameStrata("TOOLTIP")
                LichborneSpecMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
                LichborneSpecMenu:SetBackdropColor(0.05, 0.07, 0.14, 0.98)
                LichborneSpecMenu:SetBackdropBorderColor(0.78, 0.61, 0.23, 1)
                LichborneSpecMenu.btns = {}
                for s = 1, 3 do
                    local mb = CreateFrame("Button", nil, LichborneSpecMenu)
                    mb:SetSize(160, 22)
                    mb:SetPoint("TOPLEFT", LichborneSpecMenu, "TOPLEFT", 4, -4 - (s-1)*23)
                    local mbIcon = mb:CreateTexture(nil, "ARTWORK")
                    mbIcon:SetSize(18, 18)
                    mbIcon:SetPoint("LEFT", mb, "LEFT", 2, 0)
                    mb.icon = mbIcon
                    local mbLabel = mb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    mbLabel:SetPoint("LEFT", mb, "LEFT", 24, 0)
                    mbLabel:SetTextColor(1, 1, 1)
                    mb.label = mbLabel
                    mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                    LichborneSpecMenu.btns[s] = mb
                end
                LichborneSpecMenu:SetSize(168, 4 + 3*23)
                LichborneSpecMenu:Hide()
            end
            -- Populate menu for this class
            for s = 1, 3 do
                local mb = LichborneSpecMenu.btns[s]
                local sName = specNames[s] or ""
                local sIcon = SPEC_ICONS[sName]
                mb.icon:SetTexture(sIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                mb.label:SetText(sName)
                mb:SetScript("OnClick", function()
                    rowData.spec = sName
                    local icon = SPEC_ICONS[sName]
                    if icon then
                        row.specIcon:SetTexture(icon)
                        row.specIcon:SetAlpha(1.0)
                    end
                    LichborneSpecMenu:Hide()
                    if LichborneAddStatus then
                        LichborneAddStatus:SetText("Set Specialization: |cffffff00"..sName.."|r for "..(rowData.name or "?"))
                    end
                end)
            end
            LichborneSpecMenu:ClearAllPoints()
            LichborneSpecMenu:SetPoint("TOPLEFT", specBtn, "TOPRIGHT", 2, 0)
            LichborneSpecMenu:Show()
        end)

        -- Name box
        local nb = CreateFrame("EditBox", "LichborneRow"..i.."Name", row)
        nb:SetPoint("LEFT", row, "LEFT", NAME_OFF, 0)
        nb:SetSize(COL_NAME_W - 44, ROW_HEIGHT - 4)
        nb:SetAutoFocus(false); nb:SetMaxLetters(32)
        nb:SetFont("Fonts\\FRIZQT__.TTF", 11)
        nb:SetTextColor(0.90, 0.95, 1.0)
        nb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        nb:SetBackdropColor(0.05, 0.07, 0.14, 0.8)
        nb:SetBackdropBorderColor(0.15, 0.22, 0.38, 0.7)
        nb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nb:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
        nb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.nameBox = nb
        nb:SetScript("OnEnter", function() row.hov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        nb:SetScript("OnLeave", function()
            if GetMouseFocus() ~= row then row.hov:SetTexture(0, 0, 0, 0) end
        end)

        -- iLvl box
        local gsb = CreateFrame("EditBox", "LichborneRow"..i.."GS", row)
        gsb:SetPoint("LEFT", row, "LEFT", GS_OFF, 0)
        gsb:SetSize(COL_GS_W - 2, ROW_HEIGHT - 4)
        gsb:SetAutoFocus(false); gsb:SetMaxLetters(5)
        gsb:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        gsb:SetTextColor(0.831, 0.686, 0.216); gsb:SetJustifyH("CENTER")
        gsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gsb:SetBackdropColor(0.05, 0.07, 0.14, 1)
        gsb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
        gsb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        gsb:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
        gsb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.gsBox = gsb
        gsb:SetScript("OnEnter", function() row.hov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        gsb:SetScript("OnLeave", function()
            if GetMouseFocus() ~= row then row.hov:SetTexture(0, 0, 0, 0) end
        end)

        -- GS box
        local realGsb = CreateFrame("EditBox", "LichborneRow"..i.."RealGS", row)
        realGsb:SetPoint("LEFT", row, "LEFT", REALGS_OFF, 0)
        realGsb:SetSize(COL_GS_W - 2, ROW_HEIGHT - 4)
        realGsb:SetAutoFocus(false); realGsb:SetMaxLetters(5)
        realGsb:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        realGsb:SetTextColor(0.831, 0.686, 0.216); realGsb:SetJustifyH("CENTER")
        realGsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        realGsb:SetBackdropColor(0.05, 0.07, 0.14, 1)
        realGsb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
        realGsb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        realGsb:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
        realGsb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.realGsBox = realGsb
        realGsb:SetScript("OnEnter", function() row.hov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        realGsb:SetScript("OnLeave", function()
            if GetMouseFocus() ~= row then row.hov:SetTexture(0, 0, 0, 0) end
        end)

        -- Gear boxes (ilvl)
        row.gearBoxes = {}
        for g = 1, GEAR_SLOTS do
            local gx = GEAR_OFF + (g-1)*COL_GEAR_W
            local gb = CreateFrame("EditBox", "LichborneRow"..i.."Gear"..g, row)
            gb:SetPoint("LEFT", row, "LEFT", gx, 0)
            gb:SetSize(COL_GEAR_W - 2, ROW_HEIGHT - 2)
            gb:SetAutoFocus(false); gb:SetMaxLetters(3); gb:SetNumeric(true)
            gb:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            gb:SetTextColor(1,1,1); gb:SetJustifyH("CENTER")
            gb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
            gb:SetBackdropColor(0.05, 0.07, 0.14, 1)
            gb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
            gb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            gb:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
            gb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            gb:SetScript("OnMouseUp", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    gb:SetText("")
                    gb:SetTextColor(1, 1, 1)
                    if row.dbIndex then
                        LichborneTrackerDB.rows[row.dbIndex].ilvl[g] = 0
                        if LichborneTrackerDB.rows[row.dbIndex].ilvlLink then
                            LichborneTrackerDB.rows[row.dbIndex].ilvlLink[g] = ""
                        end
                    end
                end
            end)
            row.gearBoxes[g] = gb
            -- Hover glow overlay frame
            local glow = CreateFrame("Frame", nil, row)
            glow:SetAllPoints(gb)
            glow:SetFrameLevel(gb:GetFrameLevel() + 1)
            glow:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
            glow:SetBackdropColor(0,0,0,0)
            glow:SetBackdropBorderColor(0,0,0,0)
            glow:EnableMouse(false)
            gb:SetScript("OnEnter", function()
                row.hov:SetTexture(0.78, 0.61, 0.23, 0.12)
                glow:SetBackdropBorderColor(0.3, 0.7, 1.0, 1.0)
                glow:SetBackdropColor(0.05, 0.15, 0.35, 0.4)
            end)
            gb:SetScript("OnLeave", function()
                local f = GetMouseFocus()
                if f ~= row then row.hov:SetTexture(0, 0, 0, 0) end
                glow:SetBackdropBorderColor(0, 0, 0, 0)
                glow:SetBackdropColor(0, 0, 0, 0)
            end)
        end

        -- Add to Raid button (green +)
        local addRaidX = GEAR_OFF + GEAR_SLOTS * COL_GEAR_W + 3
        local arb = CreateFrame("Button", "LichborneRow"..i.."AddRaid", row)
        arb:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        arb:SetSize(16, ROW_HEIGHT - 2)
        arb:SetNormalFontObject("GameFontNormalSmall")
        arb:SetText("|cff44ff44+|r")
        arb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        arb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(arb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44ff44+ Add to Raid|r", 1, 1, 1)
            GameTooltip:AddLine("Adds to the Raid planner tab.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to remove.", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        arb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        arb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.addRaidBtn = arb

        -- Add to Group button (cyan >) - invite to current party
        local agX = addRaidX + 20
        local agb = CreateFrame("Button", "LichborneRow"..i.."AddGroup", row)
        agb:SetPoint("RIGHT", row, "RIGHT", -20, 0)
        agb:SetSize(16, ROW_HEIGHT - 2)
        agb:SetNormalFontObject("GameFontNormalSmall")
        agb:SetText("|cff44eeff>|r")
        agb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        agb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(agb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44eeff> Invite to Group|r", 1, 1, 1)
            GameTooltip:AddLine("Left-click to invite to group.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click to remove from bots.", 0.7, 0.4, 0.4)
            GameTooltip:Show()
        end)
        agb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.addGroupBtn = agb

        -- Delete button (shifted right)
        local delX = agX + 20
        local db = CreateFrame("Button", "LichborneRow"..i.."Del", row)
        db:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        db:SetSize(18, ROW_HEIGHT - 2)
        db:SetNormalFontObject("GameFontNormalSmall")
        db:SetText("|cffaa2222x|r")
        db:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        db:SetScript("OnEnter", function()
            GameTooltip:SetOwner(db, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Remove Character", 1, 0.3, 0.3)
            GameTooltip:AddLine("Removes from tracker.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        db:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.delBtn = db

        -- Needs cell in class tab (beside GS, before gear slots)
        local classRow = row
        row.needsCell = MakeNeedsCell(row, NEEDS_OFF, ROW_HEIGHT, function()
            if classRow.dbIndex and LichborneTrackerDB.rows[classRow.dbIndex] then
                return LichborneTrackerDB.rows[classRow.dbIndex].name or ""
            end
            return ""
        end, row.hov, COL_NEEDS_W)

        -- Hook all child elements to propagate row highlight
        local hov = row.hov
        HookRowHighlight(dragBtn, row, hov)
        HookRowHighlight(specBtn, row, hov)
        HookRowHighlight(arb, row, hov)
        HookRowHighlight(agb, row, hov)
        HookRowHighlight(db, row, hov)

        -- Divider
        local line = row:CreateTexture(nil, "OVERLAY")
        line:SetHeight(1); line:SetWidth(1010)
        line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        line:SetTexture(0.12, 0.20, 0.35, 0.4)

        rowFrames[i] = row
    end
end

-- ── Populate rows with current class data ────────────────────
local function RefreshRows()
    if activeTab == "Raid" then
        if LichborneRaidFrame then RefreshRaidRows() end
        return
    end
    if activeTab == "Overview" then
        if LichborneOverviewFrame then RefreshOverviewRows() end
        return
    end
    EnsureClass(activeTab)
    local indices = GetClassRows(activeTab)
    local offset = classScroll[activeTab] or 0
    local c = CLASS_COLORS[activeTab]


    for i = 1, MAX_ROWS do
        local row = rowFrames[i]
        if not row then break end
        local di = indices[i]

        if di then
            local data = LichborneTrackerDB.rows[di]
            row.dbIndex = di
            if row.dragLbl then
                if LBFilter.showLevel and data and (data.level or 0) > 0 then
                    row.dragLbl:SetText(tostring(data.level))
                    row.dragLbl:SetTextColor(0.83, 0.69, 0.22, 1.0)
                else
                    row.dragLbl:SetText(tostring(offset + i))
                    row.dragLbl:SetTextColor(0.4, 0.4, 0.5, 1.0)
                end
            end
            row:Show()

            -- No background tint - clean dark rows
            row.bg:SetTexture(0.05, 0.07, 0.13, 1)
            -- Name box colored text to match class
            if c then
                row.nameBox:SetTextColor(c.r, c.g, c.b)
            else
                row.nameBox:SetTextColor(0.90, 0.95, 1.0)
            end
            row.nameBox:SetBackdropColor(0.05, 0.07, 0.14, 0.8)
            row.nameBox:SetBackdropBorderColor(0.15, 0.22, 0.38, 0.7)

            -- Spec icon
            if row.specIcon then
                local spec = data.spec or ""
                local icon = spec ~= "" and SPEC_ICONS[spec] or nil
                if icon then
                    row.specIcon:SetTexture(icon)
                    row.specIcon:SetAlpha(1.0)
                else
                    row.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    row.specIcon:SetAlpha(data.name and data.name ~= "" and 0.25 or 0)
                end
            end

            -- Name
            row.nameBox:SetText(data.name or "")
            row.nameBox:SetScript("OnTextChanged", function()
                LichborneTrackerDB.rows[di].name = row.nameBox:GetText()
            end)

            -- iLvl (read-only)
            local gsval = data.gs or 0
            row.gsBox:SetScript("OnTextChanged", nil)
            row.gsBox:SetText(gsval > 0 and tostring(gsval) or "")
            row.gsBox.readOnly = row.gsBox:GetText()
            row.gsBox:SetScript("OnTextChanged", function()
                if row.gsBox:GetText() ~= (row.gsBox.readOnly or "") then
                    row.gsBox:SetText(row.gsBox.readOnly or "")
                end
            end)

            -- GS (read-only)
            local realGsVal = data.realGs or 0
            row.realGsBox:SetScript("OnTextChanged", nil)
            row.realGsBox:SetText(realGsVal > 0 and tostring(realGsVal) or "")
            row.realGsBox.readOnly = row.realGsBox:GetText()
            row.realGsBox:SetScript("OnTextChanged", function()
                if row.realGsBox:GetText() ~= (row.realGsBox.readOnly or "") then
                    row.realGsBox:SetText(row.realGsBox.readOnly or "")
                end
            end)

            -- Gear (ilvl)
            for g = 1, GEAR_SLOTS do
                local gb = row.gearBoxes[g]
                local val = data.ilvl[g] or 0
                local link = data.ilvlLink and data.ilvlLink[g]
                -- Show 0 when item exists but has iLvl=0 (PvP trinket, relic, etc.)
                -- Show blank only when the slot is truly empty (no link)
                gb:SetText((val > 0 or (link and link ~= "")) and tostring(val) or "")
                -- Apply item quality color; also request cache for uncached links so
                -- GET_ITEM_INFO_RECEIVED fires and re-colors once the server responds.
                local qc = GetItemQualityColor(link)
                if qc then
                    gb:SetTextColor(qc.r, qc.g, qc.b)
                else
                    if link and link ~= "" then GetItemInfo(link) end  -- queue cache request
                    gb:SetTextColor(1, 1, 1)
                end
                gb:SetScript("OnTextChanged", function()
                    local n = tonumber(gb:GetText()) or 0
                    if n > 999 then n=999; gb:SetText("999") end
                    if n < 0   then n=0;   gb:SetText("") end
                    LichborneTrackerDB.rows[di].ilvl[g] = n
                end)
                gb:SetScript("OnEnter", function()
                    row.hov:SetTexture(0.78, 0.61, 0.23, 0.12)
                    local rowData = LichborneTrackerDB.rows[di]
                    local link = rowData and rowData.ilvlLink and rowData.ilvlLink[g]
                    if link and link ~= "" then
                        -- Request cache if not already loaded (triggers GET_ITEM_INFO_RECEIVED)
                        GetItemInfo(link)
                        local anchor = (i <= 11) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
                        GameTooltip:SetOwner(gb, anchor)
                        local ok = pcall(function() GameTooltip:SetHyperlink(link) end)
                        if ok then
                            GameTooltip:Show()
                        else
                            GameTooltip:Hide()
                        end
                    end
                end)
                gb:SetScript("OnLeave", function()
                    if GetMouseFocus() ~= row then row.hov:SetTexture(0, 0, 0, 0) end
                    GameTooltip:Hide()
                end)
            end

            -- Add to Raid
            if row.addRaidBtn then
                -- Color + orange (T1) when in raid, green when not
                if IsInActiveRaid(data.name) then
                    row.addRaidBtn:SetText("|cffb25b00+|r")
                else
                    row.addRaidBtn:SetText("|cff44ff44+|r")
                end
                row.addRaidBtn:SetScript("OnClick", function(self, btn)
                    local srcData = LichborneTrackerDB.rows[di]
                    if not srcData or not srcData.name or srcData.name == "" then return end
                    local c = CLASS_COLORS[srcData.cls]
                    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
                    if btn == "RightButton" then
                        -- Remove from raid
                        local roster, _ = GetCurrentRoster()
                        for ri = 1, MAX_RAID_SLOTS do
                            if roster[ri] and roster[ri].name and roster[ri].name:lower() == srcData.name:lower() then
                                local slot = ri
                                roster[ri] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
                                row.addRaidBtn:SetText("|cff44ff44+|r")
                                if LichborneAddStatus then
                                    LichborneAddStatus:SetText(hex..srcData.name.."|r removed from raid slot "..slot..".")
                                end
                                if LichborneRaidFrame then RefreshRaidRows() end
                                RefreshRows()
                                return
                            end
                        end
                        return
                    end
                    -- Left click: add to raid
                    local roster, maxSlots = GetCurrentRoster()
                    -- Check for duplicate
                    for ri = 1, maxSlots do
                        local rr = roster[ri]
                        if rr.name and rr.name:lower() == srcData.name:lower() then
                            local c2 = CLASS_COLORS[srcData.cls]
                            local hex2 = c2 and string.format("|cff%02x%02x%02x", math.floor(c2.r*255), math.floor(c2.g*255), math.floor(c2.b*255)) or "|cffffffff"
                            if LichborneAddStatus then
                                LichborneAddStatus:SetText(hex2..srcData.name.."|r is already in the Raid.")
                            end
                            LichborneOutput("|cffC69B3ALichborne:|r "..hex2..srcData.name.."|r is already in the Raid.", 1, 0.5, 0.5)
                            return
                        end
                    end
                    -- Find first empty raid slot within size limit
                    local slot = nil
                    for ri = 1, maxSlots do
                        local rr = roster[ri]
                        if not rr.name or rr.name == "" then
                            slot = ri; break
                        end
                    end
                    if not slot then
                        local raidLabel = LichborneTrackerDB.raidName or "Raid"
                        LichborneOutput("|cffC69B3ALichborne:|r "..raidLabel.." is full ("..maxSlots.."/"..maxSlots..").", 1, 0.5, 0.5)
                        return
                    end
                    roster[slot] = {
                        name   = srcData.name,
                        cls    = srcData.cls,
                        spec   = srcData.spec or "",
                        gs     = srcData.gs or 0,
                        realGs = srcData.realGs or 0,
                        role   = "",
                        notes  = "",
                    }
                    LichborneOutput("|cffC69B3ALichborne:|r Added "..hex..srcData.name.."|r to Raid slot "..slot..".", 1, 0.85, 0)
                    if LichborneAddStatus then
                        LichborneAddStatus:SetText(hex..srcData.name.."|r added to raid slot "..slot..".")
                    end
                    -- Color + orange after successful add
                    row.addRaidBtn:SetText("|cffb25b00+|r")
                    if LichborneRaidFrame then RefreshRaidRows() end
                end)
            end

            -- Invite to Group
            if row.addGroupBtn then
                row.addGroupBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row.addGroupBtn:SetScript("OnClick", function(self, btn)
                    local srcData = LichborneTrackerDB.rows[di]
                    if not srcData or not srcData.name or srcData.name == "" then return end
                    local c = CLASS_COLORS[srcData.cls]
                    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
                    if btn == "RightButton" then
                        UninviteUnit(srcData.name)
                        SendChatMessage(".playerbots bot remove "..srcData.name, "SAY")
                        LichborneOutput("|cffC69B3ALichborne:|r Removed "..hex..srcData.name.."|r from bots.", 1, 0.85, 0)
                        return
                    end
                    SendChatMessage(".playerbots bot add "..srcData.name, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Inviting "..hex..srcData.name.."|r to group...", 1, 0.85, 0)
                    if LichborneAddStatus then
                        LichborneAddStatus:SetText("Invited "..hex..srcData.name.."|r to group.")
                    end
                end)
            end

            -- Delete
            row.delBtn:SetScript("OnClick", function()
                local srcData = LichborneTrackerDB.rows[di]
                if not srcData or not srcData.name or srcData.name == "" then return end
                RemoveCharacterReferences(srcData.name)
                RefreshRows()
                if overviewRowFrames and #overviewRowFrames > 0 then RefreshOverviewRows() end
                if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            end)

            -- Needs cell
            if row.needsCell then
                RefreshNeedsCell(row.needsCell, data.name or "")
            end
        else
            -- Show as blank row (slot filtered out or beyond DB entries)
            if row.needsCell then RefreshNeedsCell(row.needsCell, "") end
            row.dbIndex = nil
            if row.dragLbl then
                row.dragLbl:SetText(tostring(offset + i))
                row.dragLbl:SetTextColor(0.4, 0.4, 0.5, 1.0)
            end
            row.bg:SetTexture(0.05, 0.07, 0.13, 1)
            row.nameBox:SetText("")
            row.nameBox:SetScript("OnTextChanged", nil)
            if row.specIcon then row.specIcon:SetAlpha(0) end
            row.gsBox:SetScript("OnTextChanged", nil)
            row.gsBox:SetText("")
            row.realGsBox:SetScript("OnTextChanged", nil)
            row.realGsBox:SetText("")
            for g = 1, GEAR_SLOTS do
                local gb = row.gearBoxes[g]
                gb:SetScript("OnTextChanged", nil)
                gb:SetScript("OnEnter", nil)
                gb:SetScript("OnLeave", nil)
                gb:SetText("")
                gb:SetTextColor(1, 1, 1)
            end
            if row.addRaidBtn then
                row.addRaidBtn:SetText("|cff44ff44+|r")
                row.addRaidBtn:SetScript("OnClick", nil)
            end
            row.delBtn:SetScript("OnClick", nil)
            row.hov:SetTexture(0, 0, 0, 0)
            row:Show()
        end
    end
    UpdateSummary()
end

-- ── One-time UI setup ─────────────────────────────────────────

local SORT_GOLD  = "|cffd4af37"   -- gold used for sort button label
local SORT_OPTS  = {
    { label = "By Name",       mode = "name"     },
    { label = "By Class/Spec", mode = "classspec"},
    { label = "By Gear Score", mode = "gs"       },
}

-- Builds a Sort dropdown button+menu parented to `parent`.
-- onSelect(mode) called when user picks an option.
-- Returns the button so caller can position it.
local function MakeSortDropdown(parent, fl, onSelect)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(90, 16); btn:SetFrameLevel(fl+2)
    btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    btn:SetBackdropColor(0.10,0.08,0.02,1); btn:SetBackdropBorderColor(0.70,0.55,0.10,0.9)
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
    lbl:SetText(SORT_GOLD.."Sort  v|r")

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("TOOLTIP"); menu:SetSize(150, #SORT_OPTS*22+8)
    menu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    menu:SetBackdropColor(0.08,0.06,0.01,0.98); menu:SetBackdropBorderColor(0.70,0.55,0.10,1)
    menu:Hide()

    for i, opt in ipairs(SORT_OPTS) do
        local mb = CreateFrame("Button", nil, menu); mb:SetSize(146, 20)
        mb:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2-(i-1)*22)
        mb:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        mb:SetBackdropColor(0.08,0.06,0.01,1); mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local ml = mb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); ml:SetAllPoints(mb); ml:SetJustifyH("CENTER")
        ml:SetText(SORT_GOLD..opt.label.."|r")
        local cap = opt
        mb:SetScript("OnClick", function()
            menu:Hide()
            lbl:SetText(SORT_GOLD..cap.label.."  v|r")
            onSelect(cap.mode)
        end)
    end

    allSortMenus[#allSortMenus+1] = menu  -- track for tab-switch hiding

    btn:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide()
        else
            CloseAllSortMenus()
                    menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            menu:Show()
        end
    end)

    btn._menu = menu  -- store ref so callers can hide on tab switch
    return btn
end


local function GetClassAvgIlvl(cls)
    if cls == "Raid" then return 0 end
    local total, namedRows = 0, 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls and row.name and row.name ~= "" then
            namedRows = namedRows + 1
            total = total + (row.gs or 0)  -- row.gs stores the iLvl column value
        end
    end
    if namedRows == 0 then return 0 end
    return math.floor(total / namedRows + 0.5)
end

local function GetClassAvgGS(cls)
    if cls == "Raid" then return 0 end
    local total, namedRows = 0, 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls and row.name and row.name ~= "" then
            namedRows = namedRows + 1
            total = total + (row.realGs or 0)  -- row.realGs stores actual GS (1000s)
        end
    end
    if namedRows == 0 then return 0 end
    return math.floor(total / namedRows + 0.5)
end

local function GetRosterAvgIlvl()
    local total, namedRows = 0, 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.name and row.name ~= "" then
            namedRows = namedRows + 1
            total = total + (row.gs or 0)  -- row.gs stores the iLvl column value
        end
    end
    if namedRows == 0 then return 0 end
    return math.floor(total / namedRows + 0.5)
end

local function GetRosterAvgGS()
    local total, namedRows = 0, 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.name and row.name ~= "" then
            namedRows = namedRows + 1
            total = total + (row.realGs or 0)  -- row.realGs stores actual GS (1000s)
        end
    end
    if namedRows == 0 then return 0 end
    return math.floor(total / namedRows + 0.5)
end



-- ── Needs picker & cell builder ───────────────────────────────
-- ── Raid tab: BuildRaidFrame ───────────────────────────────────
local function BuildRaidFrame(parent, fl)
    if raidFrameBuilt then return end
    raidFrameBuilt = true

    -- Main container hidden behind header bar area
    LichborneRaidFrame = CreateFrame("Frame", "LichborneRaidFrame", parent)
    LichborneRaidFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -66)
    LichborneRaidFrame:SetSize(1070, 510)
    LichborneRaidFrame:SetFrameLevel(fl + 10)
    LichborneRaidFrame:Hide()
    -- Full frame background so no gaps show between columns
    local raidFrameBg = LichborneRaidFrame:CreateTexture(nil, "BACKGROUND")
    raidFrameBg:SetAllPoints(LichborneRaidFrame)
    raidFrameBg:SetTexture(0.05, 0.07, 0.13, 1)


    -- Tier bar across top with dropdown
    -- Raid definitions: tier -> list of {name, size}
    local RAID_DEFS = {
        [0]  = {{"N/A (5-Man)",5}},
        [1]  = {{"Molten Core",40},{"Onyxia's Lair",40}},
        [2]  = {{"Blackwing Lair",40}},
        [3]  = {{"Zul'Gurub",20},{"Ruins of Ahn'Qiraj",20}},
        [4]  = {{"Ahn'Qiraj (AQ40)",40}},
        [5]  = {{"Ahn'Qiraj (AQ20)",20}},
        [6]  = {{"Naxxramas (Classic)",40}},
        [7]  = {{"Karazhan",10},{"Gruul's Lair",25},{"Magtheridon's Lair",25}},
        [8]  = {{"Karazhan",10},{"Gruul's Lair",25},{"Magtheridon's Lair",25}},
        [9]  = {{"Serpentshrine Cavern",25},{"Tempest Keep",25}},
        [10] = {{"Mount Hyjal",25},{"Black Temple",25}},
        [11] = {{"Zul'Aman",10}},
        [12] = {{"Sunwell Plateau",25}},
        [13] = {{"Naxxramas 10",10},{"Naxxramas 25",25},{"Eye of Eternity 10",10},{"Eye of Eternity 25",25},{"Obsidian Sanctum 10",10},{"Obsidian Sanctum 25",25}},
        [14] = {{"Ulduar 10",10},{"Ulduar 25",25}},
        [15] = {{"Trial of the Crusader 10",10},{"Trial of the Crusader 25",25},{"Trial of the Grand Crusader 10",10},{"Trial of the Grand Crusader 25",25}},
        [16] = {{"Icecrown Citadel 10",10},{"Icecrown Citadel 25",25},{"ICC 10 Heroic",10},{"ICC 25 Heroic",25}},
        [17] = {{"Ruby Sanctum 10",10},{"Ruby Sanctum 25",25}},
    }

    -- Init raid selection state
    if not LichborneTrackerDB.raidName then LichborneTrackerDB.raidName = "N/A (5-Man)" end
    if not LichborneTrackerDB.raidSize then LichborneTrackerDB.raidSize = 5 end

    local tierBar = CreateFrame("Frame", nil, LichborneRaidFrame)
    tierBar:SetPoint("TOPLEFT", LichborneRaidFrame, "TOPLEFT", 0, 0)
    tierBar:SetSize(1080, 24)
    tierBar:SetFrameLevel(fl + 11)
    local tierBarBg = tierBar:CreateTexture(nil, "BACKGROUND")
    tierBarBg:SetAllPoints(tierBar)

    local function UpdateTierBar()
        local t = LichborneTrackerDB.raidTier or 0
        local colorKey = (t == 0) and 18 or t
        local c = TIER_COLORS[colorKey]
        if c then tierBarBg:SetTexture(c.r*0.6, c.g*0.6, c.b*0.6, 1) end
    end
    UpdateTierBar()

    -- Helper to make a dropdown button
    local function MakeDD(name, w, parent)
        local btn = CreateFrame("Button", name, parent or tierBar)
        btn:SetSize(w, 20)
        btn:SetFrameLevel(fl + 12)
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
        btn:SetBackdropColor(0.05,0.07,0.14,1)
        btn:SetBackdropBorderColor(0.78,0.61,0.23,0.8)
        local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER")
        btn.lbl = lbl
        return btn
    end

    -- ── Tier label + dropdown ──────────────────────────────────
    local tierLbl = tierBar:CreateFontString(nil,"OVERLAY","GameFontNormal")
    tierLbl:SetPoint("LEFT",tierBar,"LEFT",100,0)
    tierLbl:SetText("|cffC69B3ATier:|r")

    local tierDD = MakeDD("LichborneRaidTierDrop", 200)
    tierDD:SetPoint("LEFT",tierLbl,"RIGHT",6,0)

    local raidDD = MakeDD("LichborneRaidRaidDrop", 220)
    local raidDDMenu  -- forward ref

    local function UpdateRaidDD(hex)
        local t = LichborneTrackerDB.raidTier or 1
        local defs = RAID_DEFS[t] or {}
        -- Find current raid in this tier, fallback to first
        local found = false
        for _, rd in ipairs(defs) do
            if rd[1] == LichborneTrackerDB.raidName then found = true; break end
        end
        if not found and #defs > 0 then
            LichborneTrackerDB.raidName = defs[1][1]
            LichborneTrackerDB.raidSize = defs[1][2]
        end
        local raidName = LichborneTrackerDB.raidName or "---"
        local raidSize = LichborneTrackerDB.raidSize or 40
        local h = hex or "|cffd4af37"
        raidDD.lbl:SetText(h..raidName.."|r  |cffaaaaaa("..raidSize..")|r  v")
    end

    local function UpdateTierDD()
        local t = LichborneTrackerDB.raidTier or 1
        local colorKey = (t == 0) and 18 or t
        local c = TIER_COLORS[colorKey]
        local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        local label = (TIER_LABELS[t] or ""):match("^T%d+ %— (.+)") or ""
        tierDD.lbl:SetText(hex.."T"..t.."  "..label.."  v|r")
        UpdateTierBar()
        UpdateRaidDD(hex)
    end
    UpdateTierDD()

    -- Raid label
    local raidLbl = tierBar:CreateFontString(nil,"OVERLAY","GameFontNormal")
    raidLbl:SetPoint("LEFT",tierDD,"RIGHT",14,0)
    raidLbl:SetText("|cffC69B3ARaid:|r")
    raidDD:SetPoint("LEFT",raidLbl,"RIGHT",6,0)

    -- Tier dropdown menu
    local tierDDMenu = CreateFrame("Frame","LichborneRaidTierMenu",UIParent)
    tierDDMenu:SetFrameStrata("TOOLTIP")
    tierDDMenu:SetSize(260, 18*22+8)
    tierDDMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    tierDDMenu:SetBackdropColor(0.04,0.06,0.12,0.98)
    tierDDMenu:SetBackdropBorderColor(0.78,0.61,0.23,1)
    tierDDMenu:Hide()
    for t=0,17 do
        local mb = CreateFrame("Button",nil,tierDDMenu)
        mb:SetSize(256,20); mb:SetPoint("TOPLEFT",tierDDMenu,"TOPLEFT",2,-2-(t)*22)
        local mbbg=mb:CreateTexture(nil,"BACKGROUND"); mbbg:SetAllPoints(mb)
        local colorKey2 = (t == 0) and 18 or t
        local c=TIER_COLORS[colorKey2]; if not c then c={r=0.1,g=0.1,b=0.1} end
        mbbg:SetTexture(c.r*0.35,c.g*0.35,c.b*0.35,1)
        mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local mblbl=mb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
        local hex=string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255))
        mblbl:SetText(hex..(TIER_LABELS[t] or ("T"..t)).."|r")
        mb:SetScript("OnClick",function()
            LichborneTrackerDB.raidTier = t
            UpdateTierDD()
            tierDDMenu:Hide()
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            UpdateInviteButtons()
        end)
    end
    tierDD:SetScript("OnClick",function()
        if raidDDMenu then raidDDMenu:Hide() end
        if tierDDMenu:IsShown() then tierDDMenu:Hide()
        else tierDDMenu:ClearAllPoints(); tierDDMenu:SetPoint("TOPLEFT",tierDD,"BOTTOMLEFT",0,-2); tierDDMenu:Show() end
    end)

    local groupDDMenu

    -- Raid dropdown menu (built dynamically per tier)
    raidDDMenu = CreateFrame("Frame","LichborneRaidRaidMenu",UIParent)
    raidDDMenu:SetFrameStrata("TOOLTIP")
    raidDDMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    raidDDMenu:SetBackdropColor(0.04,0.06,0.12,0.98)
    raidDDMenu:SetBackdropBorderColor(0.78,0.61,0.23,1)
    raidDDMenu:Hide()
    raidDDMenu.btns = {}

    local function PopulateRaidMenu()
        -- Hide old buttons
        for _,b in ipairs(raidDDMenu.btns) do b:Hide() end
        raidDDMenu.btns = {}
        local t = LichborneTrackerDB.raidTier or 1
        local defs = RAID_DEFS[t] or {}
        for idx, rd in ipairs(defs) do
            local mb = CreateFrame("Button",nil,raidDDMenu)
            mb:SetSize(256,20); mb:SetPoint("TOPLEFT",raidDDMenu,"TOPLEFT",2,-2-(idx-1)*22)
            local mbbg=mb:CreateTexture(nil,"BACKGROUND"); mbbg:SetAllPoints(mb)
            local ck=TIER_COLORS[(t==0) and 18 or t] or TIER_COLORS[1]; local c=ck; mbbg:SetTexture(c.r*0.25,c.g*0.25,c.b*0.25,1)
            mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
            local mblbl=mb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
            mblbl:SetText("|cffffffff"..rd[1].."|r  |cffaaaaaa("..rd[2].." players)|r")
            local capturedName = rd[1]
            local capturedSize = rd[2]
            mb:SetScript("OnClick",function()
                LichborneTrackerDB.raidName = capturedName
                LichborneTrackerDB.raidSize = capturedSize
                LichborneTrackerDB.raidGroup = "A"  -- always start on group A for a new raid
                -- Update group dropdown label to show A
                local gdd = _G["LichborneRaidGroupDrop"]
                if gdd and gdd.lbl then gdd.lbl:SetText("|cffd4af37 A|r  v") end
                UpdateRaidDD()
                raidDDMenu:Hide()
                if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            end)
            raidDDMenu.btns[idx] = mb
        end
        raidDDMenu:SetSize(260, #defs*22+8)
    end

    raidDD:SetScript("OnClick",function()
        tierDDMenu:Hide()
        if groupDDMenu then groupDDMenu:Hide() end
        PopulateRaidMenu()
        if raidDDMenu:IsShown() then raidDDMenu:Hide()
        else raidDDMenu:ClearAllPoints(); raidDDMenu:SetPoint("TOPLEFT",raidDD,"BOTTOMLEFT",0,-2); raidDDMenu:Show() end
    end)
    UpdateRaidDD()

    -- ── Group dropdown (A / B / C) ─────────────────────────
    local groupLbl = tierBar:CreateFontString(nil,"OVERLAY","GameFontNormal")
    groupLbl:SetPoint("LEFT",raidDD,"RIGHT",14,0)
    groupLbl:SetText("|cffC69B3AGroup:|r")

    local groupDD = MakeDD("LichborneRaidGroupDrop", 70)
    groupDD:SetPoint("LEFT",groupLbl,"RIGHT",6,0)
    groupDD:SetFrameLevel(fl + 12)

    local function UpdateGroupDD()
        local g = LichborneTrackerDB.raidGroup or "A"
        groupDD.lbl:SetText("|cffd4af37"..g.."|r  v")
    end
    UpdateGroupDD()

    groupDDMenu = CreateFrame("Frame","LichborneRaidGroupMenu",UIParent)
    groupDDMenu:SetFrameStrata("TOOLTIP")
    groupDDMenu:SetSize(74, 3*22+8)
    groupDDMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    groupDDMenu:SetBackdropColor(0.04,0.06,0.12,0.98)
    groupDDMenu:SetBackdropBorderColor(0.78,0.61,0.23,1)
    groupDDMenu:Hide()
    for gi, gname in ipairs({"A","B","C"}) do
        local mb = CreateFrame("Button",nil,groupDDMenu)
        mb:SetSize(70,20); mb:SetPoint("TOPLEFT",groupDDMenu,"TOPLEFT",2,-2-(gi-1)*22)
        mb:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        mb:SetBackdropColor(0.06,0.09,0.20,1)
        mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local mblbl=mb:CreateFontString(nil,"OVERLAY","GameFontNormal"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
        mblbl:SetText("|cffffffff"..gname.."|r")
        local capturedG = gname
        mb:SetScript("OnClick",function()
            LichborneTrackerDB.raidGroup = capturedG
            UpdateGroupDD()
            groupDDMenu:Hide()
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        end)
    end
    groupDD:SetScript("OnClick",function()
        tierDDMenu:Hide(); raidDDMenu:Hide()
        if groupDDMenu:IsShown() then groupDDMenu:Hide()
        else groupDDMenu:ClearAllPoints(); groupDDMenu:SetPoint("TOPLEFT",groupDD,"BOTTOMLEFT",0,-2); groupDDMenu:Show() end
    end)

    -- ── Copy / Paste roster buttons ────────────────────────────
    local rosterClipboard = nil       -- session-only clipboard
    local clipboardLabel  = nil       -- human-readable source label e.g. "T1 Molten Core (A)"

    local copyBtn = CreateFrame("Button", nil, tierBar)
    copyBtn:SetSize(55, 20); copyBtn:SetFrameLevel(fl + 12)
    copyBtn:SetPoint("RIGHT", tierBar, "RIGHT", -70, 0)
    copyBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    copyBtn:SetBackdropColor(0.10,0.08,0.02,1); copyBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    copyBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local copyLbl = copyBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    copyLbl:SetAllPoints(copyBtn); copyLbl:SetJustifyH("CENTER"); copyLbl:SetJustifyV("MIDDLE")
    copyLbl:SetText("|cffd4af37Copy|r")
    copyBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(copyBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Copy Roster",1,1,1)
        GameTooltip:AddLine("Copies the current roster to clipboard.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    copyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pasteBtn = CreateFrame("Button", nil, tierBar)
    pasteBtn:SetSize(55, 20); pasteBtn:SetFrameLevel(fl + 12)
    pasteBtn:SetPoint("RIGHT", copyBtn, "LEFT", -4, 0)
    pasteBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    pasteBtn:SetBackdropColor(0.10,0.08,0.02,1); pasteBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    pasteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local pasteLbl = pasteBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    pasteLbl:SetAllPoints(pasteBtn); pasteLbl:SetJustifyH("CENTER"); pasteLbl:SetJustifyV("MIDDLE")
    pasteLbl:SetText("|cffd4af37Paste|r")
    pasteBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(pasteBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Paste Roster",1,1,1)
        if clipboardLabel then
            GameTooltip:AddLine("Clipboard: "..clipboardLabel,0.8,0.8,0.8)
        end
        GameTooltip:Show()
    end)
    pasteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pasteBtn:Hide()

    -- Paste confirmation popup
    local pasteConfirm = CreateFrame("Frame", nil, UIParent)
    pasteConfirm:SetSize(380, 80)
    pasteConfirm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    pasteConfirm:SetFrameStrata("FULLSCREEN_DIALOG")
    pasteConfirm:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    pasteConfirm:SetBackdropColor(0.04,0.06,0.13,0.98)
    pasteConfirm:SetBackdropBorderColor(0.78,0.61,0.23,1)
    pasteConfirm:Hide()

    local pasteConfirmText = pasteConfirm:CreateFontString(nil,"OVERLAY","GameFontNormal")
    pasteConfirmText:SetPoint("TOP",pasteConfirm,"TOP",0,-14)
    pasteConfirmText:SetWidth(360)
    pasteConfirmText:SetJustifyH("CENTER")

    local pasteYes = CreateFrame("Button",nil,pasteConfirm)
    pasteYes:SetSize(120,22); pasteYes:SetPoint("BOTTOMLEFT",pasteConfirm,"BOTTOMLEFT",16,10)
    pasteYes:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    pasteYes:SetBackdropColor(0.10,0.08,0.02,1); pasteYes:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    pasteYes:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local pasteYesLbl = pasteYes:CreateFontString(nil,"OVERLAY","GameFontNormal")
    pasteYesLbl:SetAllPoints(pasteYes); pasteYesLbl:SetJustifyH("CENTER")
    pasteYesLbl:SetText("|cffd4af37Yes, Paste|r")

    local pasteNo = CreateFrame("Button",nil,pasteConfirm)
    pasteNo:SetSize(120,22); pasteNo:SetPoint("BOTTOMRIGHT",pasteConfirm,"BOTTOMRIGHT",-16,10)
    pasteNo:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    pasteNo:SetBackdropColor(0.10,0.08,0.02,1); pasteNo:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    pasteNo:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local pasteNoLbl = pasteNo:CreateFontString(nil,"OVERLAY","GameFontNormal")
    pasteNoLbl:SetAllPoints(pasteNo); pasteNoLbl:SetJustifyH("CENTER")
    pasteNoLbl:SetText("|cffd4af37Cancel|r")
    pasteNo:SetScript("OnClick", function() pasteConfirm:Hide() end)

    copyBtn:SetScript("OnClick", function()
        local roster, size = GetCurrentRoster()
        local t    = LichborneTrackerDB.raidTier  or 0
        local name = LichborneTrackerDB.raidName  or "?"
        local grp  = LichborneTrackerDB.raidGroup or "A"
        -- Deep copy the roster
        rosterClipboard = {}
        for i = 1, MAX_RAID_SLOTS do
            local r = roster[i] or {}
            rosterClipboard[i] = {
                name  = r.name  or "",
                cls   = r.cls   or "",
                spec  = r.spec  or "",
                gs    = r.gs    or 0,
                realGs = r.realGs or 0,
                role  = r.role  or "",
                notes = r.notes or "",
            }
        end
        clipboardLabel = "T"..t.." "..name.." ("..grp..")"
        pasteBtn:Show()
        if LichborneAddStatus then
            LichborneAddStatus:SetText("|cffd4af37Roster copied to clipboard: "..clipboardLabel.."|r")
        end
    end)

    pasteYes:SetScript("OnClick", function()
        pasteConfirm:Hide()
        if not rosterClipboard then return end
        local roster, size = GetCurrentRoster()
        -- Only paste up to destination size, clear any slots beyond it
        for i = 1, MAX_RAID_SLOTS do
            if i <= size then
                local src = rosterClipboard[i] or {}
                roster[i] = {
                    name  = src.name  or "",
                    cls   = src.cls   or "",
                    spec  = src.spec  or "",
                    gs    = src.gs    or 0,
                    realGs = src.realGs or 0,
                    role  = src.role  or "",
                    notes = src.notes or "",
                }
            else
                roster[i] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
            end
        end
        -- Clear clipboard and hide paste button
        rosterClipboard = nil
        clipboardLabel  = nil
        pasteBtn:Hide()
        RefreshRaidRows()
        if LichborneAddStatus then
            LichborneAddStatus:SetText("|cffd4af37Roster copied!|r")
        end
    end)

    pasteBtn:SetScript("OnClick", function()
        if not rosterClipboard then pasteBtn:Hide(); return end
        local t    = LichborneTrackerDB.raidTier  or 0
        local name = LichborneTrackerDB.raidName  or "?"
        local grp  = LichborneTrackerDB.raidGroup or "A"
        local destLabel = "T"..t.." "..name.." ("..grp..")"
        pasteConfirmText:SetText("|cffd4af37Copy "..clipboardLabel.." roster to "..destLabel.."?|r")
        pasteConfirm:SetPoint("CENTER",UIParent,"CENTER",0,0)
        pasteConfirm:Show()
    end)

    -- Clear All button
    local clearBtn = CreateFrame("Button", nil, tierBar)
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("RIGHT", tierBar, "RIGHT", -4, 0)
    clearBtn:SetFrameLevel(fl + 12)
    clearBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    clearBtn:SetBackdropColor(0.25,0.04,0.04,1)
    clearBtn:SetBackdropBorderColor(0.8,0.1,0.1,0.9)
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local clearLbl = clearBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    clearLbl:SetAllPoints(clearBtn); clearLbl:SetJustifyH("CENTER"); clearLbl:SetJustifyV("MIDDLE")
    clearLbl:SetText("|cffd4af37Clear|r")
    clearBtn:SetScript("OnEnter",function()
        GameTooltip:SetOwner(clearBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Clear All Raid Slots",1,1,1)
        GameTooltip:AddLine("Removes all characters from the raid.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)

    -- Confirm popup for Clear All
    local confirmFrame = CreateFrame("Frame","LichborneRaidClearConfirm",UIParent)
    confirmFrame:SetSize(300,90)
    confirmFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    confirmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    confirmFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=3,right=3,top=3,bottom=3}})
    confirmFrame:SetBackdropColor(0.04,0.06,0.13,0.98)
    confirmFrame:SetBackdropBorderColor(0.78,0.61,0.23,1)
    confirmFrame:Hide()
    local confText = confirmFrame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    confText:SetPoint("TOP",confirmFrame,"TOP",0,-12)
    confText:SetText("|cffC69B3AClear all raid slots?|r")
    local confSub = confirmFrame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    confSub:SetPoint("TOP",confText,"BOTTOM",0,-4)
    confSub:SetText("|cffaaaaaa This cannot be undone.|r")
    local yesBtn = CreateFrame("Button",nil,confirmFrame)
    yesBtn:SetSize(100,24); yesBtn:SetPoint("BOTTOMLEFT",confirmFrame,"BOTTOMLEFT",16,10)
    yesBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    yesBtn:SetBackdropColor(0.25,0.04,0.04,1); yesBtn:SetBackdropBorderColor(0.8,0.1,0.1,0.9)
    yesBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local yesLbl=yesBtn:CreateFontString(nil,"OVERLAY","GameFontNormal"); yesLbl:SetAllPoints(yesBtn); yesLbl:SetJustifyH("CENTER"); yesLbl:SetText("|cffff4444Yes, Clear|r")
    yesBtn:SetScript("OnClick",function()
        local rosterC, sizeC = GetCurrentRoster()
        for i=1,sizeC do rosterC[i]={name="",cls="",spec="",gs=0,realGs=0,role="",notes=""} end
        RefreshRaidRows()
        confirmFrame:Hide()
    end)
    local noBtn = CreateFrame("Button",nil,confirmFrame)
    noBtn:SetSize(100,24); noBtn:SetPoint("BOTTOMRIGHT",confirmFrame,"BOTTOMRIGHT",-16,10)
    noBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    noBtn:SetBackdropColor(0.04,0.15,0.04,1); noBtn:SetBackdropBorderColor(0.1,0.7,0.1,0.9)
    noBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local noLbl=noBtn:CreateFontString(nil,"OVERLAY","GameFontNormal"); noLbl:SetAllPoints(noBtn); noLbl:SetJustifyH("CENTER"); noLbl:SetText("|cff44ff44Cancel|r")
    noBtn:SetScript("OnClick",function() confirmFrame:Hide() end)

    clearBtn:SetScript("OnClick",function()
        confirmFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
        confirmFrame:Show()
    end)

    -- Column headers row
    local hdrRow = CreateFrame("Frame",nil,LichborneRaidFrame)
    hdrRow:SetPoint("TOPLEFT",LichborneRaidFrame,"TOPLEFT",0,-26)
    hdrRow:SetSize(535,18)
    hdrRow:SetFrameLevel(fl+11)
    local hdrBg = hdrRow:CreateTexture(nil,"BACKGROUND"); hdrBg:SetAllPoints(hdrRow); hdrBg:SetTexture(0.08,0.20,0.42,1)

    local function RH(lbl,x,w)
        local fs=hdrRow:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("LEFT",hdrRow,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cffd4af37"..lbl.."|r")
    end
    local function RSH(lbl,x,w,key,isNumeric,tipExtra)
        local btn = CreateFrame("Button",nil,hdrRow)
        btn:SetPoint("TOPLEFT",hdrRow,"TOPLEFT",x,0)
        btn:SetSize(w,18); btn:SetFrameLevel(hdrRow:GetFrameLevel()+2)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local fs=btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetAllPoints(btn); fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
        fs:SetText("|cffd4af37"..lbl.."|r")
        raidSortHdrs[key] = {lbl=lbl, fs=fs}
        btn:SetScript("OnEnter",function()
            GameTooltip:SetOwner(btn,"ANCHOR_BOTTOM")
            GameTooltip:AddLine("Click to sort",1,1,1)
            if tipExtra then GameTooltip:AddLine(tipExtra,0.8,0.8,0.8) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave",function() GameTooltip:Hide() end)
        btn:SetScript("OnClick",function()
            if raidSortKey == key then
                raidSortAsc = not raidSortAsc
            else
                raidSortKey = key
                raidSortAsc = not isNumeric
            end
            raidSortPending = true
            UpdateRaidSortHeaders()
            RefreshRaidRows()
        end)
    end

    -- Layout constants for raid rows (both columns identical, 530px wide)
    local RD=0; local RC=20; local RS=42; local RN=66; local RG=178; local RRealGS=232; local RT=286; local RRole=334; local RNotes=362; local RInvX=0; local RDelX=0  -- InvX/DelX unused, buttons use RIGHT anchor
    -- Spec header icon only (no class icon header)
    local specHdrTex = hdrRow:CreateTexture(nil, "OVERLAY")
    specHdrTex:SetPoint("LEFT", hdrRow, "LEFT", RS, 0)
    specHdrTex:SetSize(18, 16)
    specHdrTex:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    RSH("Spec", RS-4, 26, "spec", false, "Click 1: Death Knight first (A-Z classes)\nClick 2: Warrior first (Z-A classes)\nSpec within class always A-Z")
    RSH("Name", RN+2, 108, "name", false, nil)
    RSH("iLvL", RG+2, 50, "ilvl", true, nil)
    RSH("GS",   RRealGS+2, 50, "gs", true, nil)
    RH("Need", RT+2, 46)
    RSH("Role", RRole, 26, "role", false, nil)
    RH("Notes", RNotes+2, 120)

    -- Build 40 raid rows (2 columns of 20)
    local ROW_H = 22
    local COL2_X = 530

    for i=1,40 do
        local col = i <= 20 and 0 or COL2_X
        local rowIdx = i <= 20 and (i-1) or (i-21)
        local yOff = -46 - rowIdx * ROW_H

        local rf = CreateFrame("Frame","LichborneRaidRow"..i,LichborneRaidFrame)
        rf:SetPoint("TOPLEFT",LichborneRaidFrame,"TOPLEFT",col,yOff)
        rf:SetSize(530,ROW_H)
        rf:SetFrameLevel(fl+11)

        local rbg = rf:CreateTexture(nil,"BACKGROUND"); rbg:SetAllPoints(rf)
        rbg:SetTexture(i%2==0 and 0.05 or 0.07, i%2==0 and 0.07 or 0.09, i%2==0 and 0.13 or 0.16, 1)

        -- Row number label (behind drag handle)
        local rnum = rf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        rnum:SetPoint("LEFT",rf,"LEFT",RD+2,0); rnum:SetWidth(16); rnum:SetJustifyH("CENTER")
        rnum:SetTextColor(0.4,0.4,0.5); rnum:SetText(tostring(i))

        -- Hover/drop highlight textures (same as class tab)
        rf:EnableMouse(true)
        local raidHov = rf:CreateTexture(nil,"OVERLAY"); raidHov:SetAllPoints(rf); raidHov:SetTexture(0,0,0,0); rf.raidHov = raidHov
        local raidDropHi = rf:CreateTexture(nil,"OVERLAY"); raidDropHi:SetAllPoints(rf); raidDropHi:SetTexture(0,0,0,0); rf.raidDropHi = raidDropHi
        rf:SetScript("OnEnter", function()
            if not raidDragSource then
                raidHov:SetTexture(0.78, 0.61, 0.23, 0.12)
            end
        end)
        rf:SetScript("OnLeave", function()
            if not raidDragSource then
                raidHov:SetTexture(0, 0, 0, 0)
            end
        end)

        -- Drag handle button (same style as class tab, shows row number)
        local dragBtn = CreateFrame("Button",nil,rf)
        dragBtn:SetPoint("LEFT",rf,"LEFT",RD,0); dragBtn:SetSize(18,ROW_H)
        dragBtn:SetFrameLevel(rf:GetFrameLevel()+5)
        local dragTex2 = dragBtn:CreateTexture(nil,"ARTWORK"); dragTex2:SetAllPoints(dragBtn)
        dragTex2:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        dragTex2:SetVertexColor(0.2,0.3,0.5,0)  -- invisible by default
        dragBtn:SetScript("OnEnter",function()
            if not raidDragSource then
                dragTex2:SetVertexColor(0.9,0.7,0.1,1.0)
                GameTooltip:SetOwner(dragBtn,"ANCHOR_RIGHT")
                GameTooltip:AddLine("Drag to reorder",1,1,1)
                GameTooltip:Show()
            end
        end)
        dragBtn:SetScript("OnLeave",function()
            if not raidDragSource then dragTex2:SetVertexColor(0.2,0.3,0.5,0) end
            GameTooltip:Hide()
        end)
        dragBtn:SetScript("OnMouseDown",function(_, mouseButton)
            if mouseButton == "LeftButton" then
                local roster2, _ = GetCurrentRoster()
                local d2 = roster2[i]
                if d2 and d2.name and d2.name ~= "" then
                    raidDragSource = i
                    raidMouseHeld = true
                    dragTex2:SetVertexColor(0.9,0.7,0.1,1.0)
                    raidHov:SetTexture(0.9,0.7,0.1,0.12)
                end
            end
        end)
        dragBtn:SetScript("OnMouseUp",function()
            raidMouseHeld = false
        end)
        rf.raidDragBtn = dragBtn; rf.raidDragTex = dragTex2; rf.raidRowIdx = i

        -- Class icon (plain Frame, same as All tab)
        local clsBtn = CreateFrame("Frame",nil,rf)
        clsBtn:SetPoint("LEFT",rf,"LEFT",RC,0); clsBtn:SetSize(18,18)
        local clsTex = clsBtn:CreateTexture(nil,"ARTWORK"); clsTex:SetAllPoints(clsBtn); clsTex:SetTexture(0,0,0,0)
        rf.classIcon = clsTex
        -- Class is set automatically when adding from class tabs

        -- Spec icon (Button so it receives mouse events for future use)
        local specBtn = CreateFrame("Button",nil,rf)
        specBtn:SetPoint("LEFT",rf,"LEFT",RS,0); specBtn:SetSize(18,18)
        specBtn:SetFrameLevel(rf:GetFrameLevel()+2)
        specBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local specTex=specBtn:CreateTexture(nil,"ARTWORK"); specTex:SetAllPoints(specBtn); specTex:SetTexture(0,0,0,0)
        rf.specIcon=specTex; rf.specBtn=specBtn

        -- Name editbox
        local nb=CreateFrame("EditBox",nil,rf)
        nb:SetPoint("LEFT",rf,"LEFT",RN,0); nb:SetSize(106,ROW_H-2)
        nb:SetAutoFocus(false); nb:SetMaxLetters(24)
        nb:SetFont("Fonts\\FRIZQT__.TTF",10)
        nb:SetTextColor(0.9,0.95,1.0)
        nb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        nb:SetBackdropColor(0.05,0.07,0.14,0.6)
        nb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        nb:SetScript("OnEnterPressed",function() nb:ClearFocus() end)
        nb:SetScript("OnTabPressed",function() nb:ClearFocus() end)
        nb:SetScript("OnEscapePressed",function() nb:ClearFocus() end)
        rf.nameBox=nb

        -- iLvl editbox
        local gsb=CreateFrame("EditBox",nil,rf)
        gsb:SetPoint("LEFT",rf,"LEFT",RG,0); gsb:SetSize(50,ROW_H-2)
        gsb:SetAutoFocus(false); gsb:SetMaxLetters(5)
        gsb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        gsb:SetTextColor(0.831, 0.686, 0.216); gsb:SetJustifyH("CENTER")
        gsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gsb:SetBackdropColor(0.05,0.07,0.14,0.6)
        gsb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        gsb:SetScript("OnEnterPressed",function() gsb:ClearFocus() end)
        gsb:SetScript("OnTabPressed",function() gsb:ClearFocus() end)
        gsb:SetScript("OnEscapePressed",function() gsb:ClearFocus() end)
        rf.gsBox=gsb
        gsb:SetScript("OnEnter", function() rf.raidHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        gsb:SetScript("OnLeave", function() if GetMouseFocus()~=rf then rf.raidHov:SetTexture(0,0,0,0) end end)

        -- GS editbox
        local realGsb=CreateFrame("EditBox",nil,rf)
        realGsb:SetPoint("LEFT",rf,"LEFT",RRealGS,0); realGsb:SetSize(50,ROW_H-2)
        realGsb:SetAutoFocus(false); realGsb:SetMaxLetters(5)
        realGsb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        realGsb:SetTextColor(0.831, 0.686, 0.216); realGsb:SetJustifyH("CENTER")
        realGsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        realGsb:SetBackdropColor(0.05,0.07,0.14,0.6)
        realGsb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        realGsb:SetScript("OnEnterPressed",function() realGsb:ClearFocus() end)
        realGsb:SetScript("OnTabPressed",function() realGsb:ClearFocus() end)
        realGsb:SetScript("OnEscapePressed",function() realGsb:ClearFocus() end)
        rf.realGsBox=realGsb
        realGsb:SetScript("OnEnter", function() rf.raidHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        realGsb:SetScript("OnLeave", function() if GetMouseFocus()~=rf then rf.raidHov:SetTexture(0,0,0,0) end end)

        -- Needs cell (replaces Tier)
        local raidRowIdx = i
        rf.needsCell = MakeNeedsCell(rf, RT, ROW_H, function()
            local roster5, _ = GetCurrentRoster()
            local d5 = roster5[raidRowIdx]
            return d5 and d5.name or ""
        end, rf.raidHov, 46)

        -- Role button (icon-only 22px, after Needs)
        local roleBtn = CreateFrame("Button",nil,rf)
        roleBtn:SetPoint("LEFT",rf,"LEFT",RRole,0); roleBtn:SetSize(26,ROW_H-2)
        roleBtn:SetFrameLevel(rf:GetFrameLevel()+6)
        roleBtn:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        roleBtn:SetBackdropColor(0.05,0.07,0.14,0.8); roleBtn:SetBackdropBorderColor(0.20,0.30,0.50,0.4)
        roleBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local roleIcon=roleBtn:CreateTexture(nil,"ARTWORK")
        roleIcon:SetPoint("CENTER",roleBtn,"CENTER",0,0); roleIcon:SetSize(16,16)
        roleIcon:SetTexture(0,0,0,0)
        local roleLbl=roleBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        roleLbl:SetAllPoints(roleBtn); roleLbl:SetJustifyH("CENTER"); roleLbl:SetJustifyV("MIDDLE")
        roleLbl:SetText(""); rf.roleBtn=roleBtn; rf.roleLbl=roleLbl; rf.roleIcon=roleIcon
        HookRowHighlight(roleBtn, rf, rf.raidHov)

        -- Notes editbox
        local notesBox=CreateFrame("EditBox",nil,rf)
        notesBox:SetPoint("LEFT",rf,"LEFT",RNotes,0); notesBox:SetSize(120,ROW_H-2)
        notesBox:SetAutoFocus(false); notesBox:SetMaxLetters(24)
        notesBox:SetFont("Fonts\\FRIZQT__.TTF",9); notesBox:SetTextColor(0.85,0.85,0.70)
        notesBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        notesBox:SetBackdropColor(0.05,0.07,0.10,0.6); notesBox:SetBackdropBorderColor(0.25,0.25,0.15,0.5)
        notesBox:SetScript("OnEnterPressed",function() notesBox:ClearFocus() end)
        notesBox:SetScript("OnTabPressed",function() notesBox:ClearFocus() end)
        notesBox:SetScript("OnEscapePressed",function() notesBox:ClearFocus() end)
        rf.notesBox=notesBox
        notesBox:SetScript("OnEnter", function() rf.raidHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        notesBox:SetScript("OnLeave", function() if GetMouseFocus()~=rf then rf.raidHov:SetTexture(0,0,0,0) end end)

        -- Class btn reference for color updates
        rf.classBtn=clsBtn; rf.classBtnTex=clsTex

        -- Clear/delete button (far right)
        local db=CreateFrame("Button",nil,rf)
        db:SetPoint("RIGHT",rf,"RIGHT",-2,0)
        db:SetSize(16,ROW_H-2)
        db:SetNormalFontObject("GameFontNormalSmall"); db:SetText("|cffaa2222x|r")
        db:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        db:SetScript("OnEnter", function()
            GameTooltip:SetOwner(db, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Remove from Raid", 1, 0.3, 0.3)
            GameTooltip:AddLine("Clears this slot in the raid roster.", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Character remains in the tracker.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        db:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rf.delBtn=db

        -- Invite to group > button
        local invb = CreateFrame("Button", nil, rf)
        invb:SetPoint("RIGHT",rf,"RIGHT",-20,0)
        invb:SetSize(16, ROW_H-2)
        invb:SetNormalFontObject("GameFontNormalSmall"); invb:SetText("|cff44eeff>|r")
        invb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        invb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(invb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44eeff> Invite to Group|r", 1,1,1)
            GameTooltip:AddLine("Left-click to invite to group.", 0.7,0.7,0.7)
            GameTooltip:AddLine("Right-click to remove.", 0.7,0.4,0.4)
            GameTooltip:Show()
        end)
        invb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        invb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        invb:SetScript("OnClick", function(self, btn)
            local roster, _ = GetCurrentRoster()
            local d = roster[i]
            if d and d.name and d.name ~= "" then
                if btn == "RightButton" then
                    UninviteUnit(d.name)
                    SendChatMessage(".playerbots bot remove "..d.name, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Removed "..d.name.." from bots.", 1, 0.85, 0)
                    return
                end
                SendChatMessage(".playerbots bot add "..d.name, "SAY")
                if LichborneAddStatus then
                    LichborneAddStatus:SetText("|cffd4af37Invited "..d.name.." to group.|r")
                end
            end
        end)
        rf.invBtn = invb

        -- Hook child elements to propagate row highlight
        local rHov = rf.raidHov
        HookRowHighlight(dragBtn, rf, rHov)
        HookRowHighlight(db, rf, rHov)
        HookRowHighlight(invb, rf, rHov)
        if rf.specBtn then HookRowHighlight(rf.specBtn, rf, rHov) end
        if rf.roleBtn then HookRowHighlight(rf.roleBtn, rf, rHov) end

        -- Divider
        local ln=rf:CreateTexture(nil,"OVERLAY"); ln:SetHeight(1); ln:SetWidth(530)
        ln:SetPoint("BOTTOMLEFT",rf,"BOTTOMLEFT",0,0); ln:SetTexture(0.10,0.16,0.28,0.4)

        raidRowFrames[i]=rf
    end

    -- ── Raid drag-to-reorder (same logic as class tabs) ────────
    -- raidMouseHeld: set true on OnMouseDown, false on OnMouseUp
    -- This avoids IsMouseButtonDown which is unreliable in 3.3.5a
    LichborneTrackerFrame:HookScript("OnMouseUp", function()
        if raidDragSource then
            raidMouseHeld = false
        end
    end)

    raidDragPoll:SetScript("OnUpdate", function()
        if not raidDragSource then return end
        if not raidMouseHeld then
            -- Mouse released - find target and swap
            local cx, cy = GetCursorPosition()
            local sc = UIParent:GetEffectiveScale()
            cx, cy = cx/sc, cy/sc
            local targetIdx = nil
            for j, rf2 in ipairs(raidRowFrames) do
                if rf2:IsShown() and j ~= raidDragSource then
                    local roster2, _ = GetCurrentRoster()
                    local d2 = roster2[j]
                    if d2 and d2.name and d2.name ~= "" then
                        local l,r,b,t = rf2:GetLeft(),rf2:GetRight(),rf2:GetBottom(),rf2:GetTop()
                        if l and cx>=l and cx<=r and cy>=b and cy<=t then
                            targetIdx = j; break
                        end
                    end
                end
            end
            if targetIdx then
                local roster3, _ = GetCurrentRoster()
                local a, b2 = raidDragSource, targetIdx
                if a ~= b2 then
                    local item = {name=roster3[a].name,cls=roster3[a].cls,spec=roster3[a].spec,gs=roster3[a].gs,realGs=roster3[a].realGs,role=roster3[a].role,notes=roster3[a].notes}
                    -- Shift rows between a and b2
                    if a < b2 then
                        for k = a, b2 - 1 do roster3[k] = roster3[k+1] end
                    else
                        for k = a, b2 + 1, -1 do roster3[k] = roster3[k-1] end
                    end
                    roster3[b2] = item
                    raidSortKey = nil  -- clear sort so drag order sticks
                    RefreshRaidRows()
                end
            end
            for _, rf2 in ipairs(raidRowFrames) do
                if rf2.raidHov then rf2.raidHov:SetTexture(0,0,0,0) end
                if rf2.raidDropHi then rf2.raidDropHi:SetTexture(0,0,0,0) end
                if rf2.raidDragTex then rf2.raidDragTex:SetVertexColor(0.2,0.3,0.5,0) end
            end
            raidDragSource = nil
            return
        end
        -- Dragging - highlight target
        local cx, cy = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        cx, cy = cx/sc, cy/sc
        for j, rf2 in ipairs(raidRowFrames) do
            if rf2:IsShown() and j ~= raidDragSource then
                local l,r,b,t = rf2:GetLeft(),rf2:GetRight(),rf2:GetBottom(),rf2:GetTop()
                if l then
                    if cx>=l and cx<=r and cy>=b and cy<=t then
                        rf2.raidDropHi:SetTexture(0.9,0.7,0.1,0.20)
                    else
                        rf2.raidDropHi:SetTexture(0,0,0,0)
                    end
                end
            end
        end
    end)

    -- Second column header
    local hdrRow2 = CreateFrame("Frame",nil,LichborneRaidFrame)
    hdrRow2:SetPoint("TOPLEFT",LichborneRaidFrame,"TOPLEFT",COL2_X,-26)
    hdrRow2:SetSize(535,18); hdrRow2:SetFrameLevel(fl+11)
    local hdrBg2=hdrRow2:CreateTexture(nil,"BACKGROUND"); hdrBg2:SetAllPoints(hdrRow2); hdrBg2:SetTexture(0.08,0.20,0.42,1)
    local RH2 = function(lbl,x,w)
        local fs=hdrRow2:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("LEFT",hdrRow2,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cffd4af37"..lbl.."|r")
    end
    local specHdrTex2 = hdrRow2:CreateTexture(nil, "OVERLAY")
    specHdrTex2:SetPoint("LEFT", hdrRow2, "LEFT", RS, 0)
    specHdrTex2:SetSize(18, 16)
    specHdrTex2:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    RH2("Name",RN+2,108); RH2("iLvL",RG+2,50); RH2("GS",RRealGS+2,50); RH2("Need",RT+2,46); RH2("Role",RRole,26); RH2("Notes",RNotes+2,120)

        -- ── Raid class count bar ──────────────────────────────────
    local raidCountBar = CreateFrame("Frame","LichborneRaidCountBar",LichborneRaidFrame)
    _G["LichborneRaidCountBar"] = raidCountBar
    raidCountBar:SetPoint("TOPLEFT", LichborneRaidFrame, "TOPLEFT", 0, -488)
    raidCountBar:SetSize(1080, 24)
    raidCountBar:SetFrameLevel(fl + 11)
    local rcbBg = raidCountBar:CreateTexture(nil,"BACKGROUND")
    rcbBg:SetAllPoints(raidCountBar); rcbBg:SetTexture(0.05, 0.07, 0.13, 1)
    local rcTitle = raidCountBar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    rcTitle:SetPoint("LEFT", raidCountBar, "LEFT", 4, 0)
    rcTitle:SetText("|cffC69B3ACount:|r"); rcTitle:SetWidth(44)
    LichborneRaidCountLabels = {}
    local rcW = (1080 - 50) / 10
    local rcIdx = 0
    for ci, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" or cls == "Overview" then break end
        rcIdx = rcIdx + 1
        local c = CLASS_COLORS[cls]
        local rcSw = CreateFrame("Button", nil, raidCountBar)
        rcSw:SetSize(rcW - 2, 20)
        rcSw:SetPoint("LEFT", raidCountBar, "LEFT", 48 + (rcIdx-1)*rcW, 0)
        rcSw:SetFrameLevel(raidCountBar:GetFrameLevel() + 1)
        local rcBg2 = rcSw:CreateTexture(nil,"BACKGROUND"); rcBg2:SetAllPoints(rcSw)
        rcBg2:SetTexture(0.08, 0.10, 0.18, 1); rcSw.bg = rcBg2
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local rcLbl = rcSw:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        rcLbl:SetAllPoints(rcSw); rcLbl:SetJustifyH("CENTER"); rcLbl:SetJustifyV("MIDDLE")
        rcLbl:SetText(hex..(TAB_LABELS[cls])..": "..hex.."0|r")
        rcSw.lbl = rcLbl; rcSw.cls = cls
        LichborneRaidCountLabels[cls] = rcLbl
        rcSw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(rcSw,"ANCHOR_TOP")
            GameTooltip:AddLine(cls, c.r, c.g, c.b)
            GameTooltip:Show()
        end)
        rcSw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- ── Invite Raid button (anchored below raid frame) ────────
    -- Invite button lives on main frame beside Add Target/Update GS buttons

    local inviteBtn = CreateFrame("Button","LichborneInviteRaidBtn",LichborneRaidFrame:GetParent())
    inviteBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 495, 8)
    inviteBtn:SetSize(155, 62)
    inviteBtn:SetFrameLevel(fl + 12)
    inviteBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    inviteBtn:SetBackdropColor(0.30,0.15,0.01,1)
    inviteBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    inviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local inviteLbl = inviteBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    inviteLbl:SetAllPoints(inviteBtn); inviteLbl:SetJustifyH("CENTER"); inviteLbl:SetJustifyV("MIDDLE")
    inviteLbl:SetText("|cffd4af37Invite Raid|r")
    inviteBtn.lbl = inviteLbl
    inviteBtn:SetScript("OnEnter",function()
        local roster, size = GetCurrentRoster()
        local count = 0
        for i=1,size do if roster[i] and roster[i].name and roster[i].name ~= "" then count=count+1 end end
        GameTooltip:SetOwner(inviteBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("Invite Raid",1,1,1)
        GameTooltip:AddLine(count.." players in this roster",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    inviteBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)

    inviteBtn:SetScript("OnClick",function()
        local roster, size = GetCurrentRoster()
        -- Collect non-empty names
        local names = {}
        local nameClasses = {}
        for i=1,size do
            local r = roster[i]
            if r and r.name and r.name ~= "" then
                names[#names+1] = r.name
                nameClasses[r.name] = r.cls
            end
        end
        if #names == 0 then
            LichborneOutput("|cffC69B3ALichborne:|r No players in this roster.",1,0.5,0.5)
            return
        end
        local function GetClassHex(name)
            local cls = nameClasses[name]
            local c = cls and CLASS_COLORS[cls]
            if c then return string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) end
            return "|cffffff88"
        end

        SetInviteActive(true)
        LichborneOutput("|cffC69B3ALichborne:|r Starting raid invite for "..#names.." players...",1,0.85,0)
        if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Logging out all bots...") end

        -- Step 0: Remove all bots with wildcard
        SendChatMessage(".playerbots bot remove *", "SAY")

        local inviteIndex = 1
        local waitTime = 0
        local phase = "logout_wait"
        local reinviteSubPhase = "remove"

        local inviteFrame = CreateFrame("Frame")
        activeInviteFrame = inviteFrame
        UpdateInviteButtons()
        inviteFrame:SetScript("OnUpdate",function(_, elapsed)
            waitTime = waitTime + elapsed

            if phase == "logout_wait" then
                if waitTime < 1.5 then return end
                waitTime = 0
                -- Leave party after bots are removed
                LeaveParty()
                phase = "leave_wait"
                LichborneOutput("|cffC69B3ALichborne:|r Bots removed, leaving party...",1,0.85,0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Leaving party, then inviting...") end

            elseif phase == "leave_wait" then
                if waitTime < 1.0 then return end
                waitTime = 0
                phase = "first"
                LichborneOutput("|cffC69B3ALichborne:|r Bots cleared, starting invites...",1,0.85,0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Inviting "..#names.." players...") end

            elseif phase == "first" then
                if waitTime < 0.5 then return end
                local firstName = names[1]
                SendChatMessage(".playerbots bot add "..firstName, "SAY")
                LichborneOutput("|cffC69B3ALichborne:|r Inviting "..GetClassHex(firstName)..firstName.."|r...",1,0.85,0)
                inviteIndex = 2
                waitTime = 0
                phase = "convert"

            elseif phase == "convert" then
                if waitTime < 2.0 then return end
                ConvertToRaid()
                LichborneOutput("|cffC69B3ALichborne:|r Converting to raid...",1,0.85,0)
                waitTime = 0
                phase = "rest"

            elseif phase == "rest" then
                if waitTime < 0.8 then return end
                waitTime = 0
                if inviteIndex > #names then
                    -- Initial pass done — wait 3s then verify who's missing
                    phase = "verify_wait"
                    waitTime = 0
                    LichborneOutput("|cffC69B3ALichborne:|r Initial invites sent, verifying...",1,0.85,0)
                    return
                end
                local pname = names[inviteIndex]
                SendChatMessage(".playerbots bot add "..pname, "SAY")
                LichborneOutput("|cffC69B3ALichborne:|r Inviting "..GetClassHex(pname)..pname.."|r...",1,0.85,0)
                inviteIndex = inviteIndex + 1

            elseif phase == "verify_wait" then
                if waitTime < 3.0 then return end
                -- Build set of who is currently in the raid
                local inRaid = {}
                for i = 1, GetNumRaidMembers() do
                    local rname = UnitName("raid"..i)
                    if rname then inRaid[rname:lower()] = true end
                end
                local selfName = UnitName("player")
                if selfName then inRaid[selfName:lower()] = true end
                -- Find missing
                local missing = {}
                for _, pname in ipairs(names) do
                    if not inRaid[pname:lower()] then
                        missing[#missing+1] = pname
                    end
                end
                if #missing == 0 then
                    LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44All "..#names.." players confirmed in raid!|r",1,0.85,0)
                    if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44All "..#names.." players confirmed in raid.|r") end
                    inviteFrame:SetScript("OnUpdate",nil)
                    activeInviteFrame = nil
                    SetInviteActive(false)
                    UpdateInviteButtons()
                    return
                end
                LichborneOutput("|cffC69B3ALichborne:|r |cffff9900"..#missing.." missed — re-inviting...|r",1,0.85,0)
                names = missing
                inviteIndex = 1
                phase = "reinvite"
                waitTime = 0

            elseif phase == "reinvite" then
                -- remove then wait 1s then add, per missed character
                if reinviteSubPhase == "remove" then
                    if inviteIndex > #names then
                        LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44Re-invite pass complete.|r",1,0.85,0)
                        if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44Invite complete (re-invite pass done).|r") end
                        inviteFrame:SetScript("OnUpdate",nil)
                        activeInviteFrame = nil
                        SetInviteActive(false)
                        UpdateInviteButtons()
                        return
                    end
                    local pname = names[inviteIndex]
                    SendChatMessage(".playerbots bot remove "..pname, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Removing "..GetClassHex(pname)..pname.."|r before re-invite...",1,0.85,0)
                    waitTime = 0
                    reinviteSubPhase = "add"

                elseif reinviteSubPhase == "add" then
                    if waitTime < 1.0 then return end
                    local pname = names[inviteIndex]
                    SendChatMessage(".playerbots bot add "..pname, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Re-inviting "..GetClassHex(pname)..pname.."|r...",1,0.85,0)
                    inviteIndex = inviteIndex + 1
                    waitTime = 0
                    reinviteSubPhase = "remove"
                end
            end
        end)
    end)

    -- ── Invite Group button (for T0 5-mans, no raid conversion) ──
    local inviteGroupBtn = CreateFrame("Button","LichborneInviteGroupBtn",LichborneRaidFrame:GetParent())
    inviteGroupBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 495, 76)
    inviteGroupBtn:SetSize(155, 62)
    inviteGroupBtn:SetFrameLevel(fl + 12)
    inviteGroupBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    inviteGroupBtn:SetBackdropColor(0.035,0.14,0.245,1)
    inviteGroupBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    inviteGroupBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local inviteGroupLbl = inviteGroupBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    inviteGroupLbl:SetAllPoints(inviteGroupBtn); inviteGroupLbl:SetJustifyH("CENTER"); inviteGroupLbl:SetJustifyV("MIDDLE")
    inviteGroupLbl:SetText("|cffd4af37Invite Group|r")
    inviteGroupBtn.lbl = inviteGroupLbl
    inviteGroupBtn:SetScript("OnEnter",function()
        -- Always count from T0 5-Man roster
        local t0group = (LichborneTrackerDB and LichborneTrackerDB.raidGroup) or "A"
        local t0key = "N/A (5-Man)_" .. t0group
        local t0roster = (LichborneTrackerDB and LichborneTrackerDB.raidRosters and LichborneTrackerDB.raidRosters[t0key]) or {}
        local count = 0
        for i=1,5 do if t0roster[i] and t0roster[i].name and t0roster[i].name ~= "" then count=count+1 end end
        GameTooltip:SetOwner(inviteGroupBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("Invite Group (5-Man)",1,1,1)
        GameTooltip:AddLine(count.." players in T0 5-Man roster",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    inviteGroupBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    inviteGroupBtn:SetScript("OnClick",function()
        -- Always invite from T0 5-Man roster
        local t0group = (LichborneTrackerDB and LichborneTrackerDB.raidGroup) or "A"
        local t0key = "N/A (5-Man)_" .. t0group
        if not LichborneTrackerDB.raidRosters then LichborneTrackerDB.raidRosters = {} end
        if not LichborneTrackerDB.raidRosters[t0key] then
            LichborneTrackerDB.raidRosters[t0key] = {}
            for i = 1, MAX_RAID_SLOTS do
                LichborneTrackerDB.raidRosters[t0key][i] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
            end
        end
        local t0roster = LichborneTrackerDB.raidRosters[t0key]
        local names = {}
        local nameClasses = {}
        for i=1,5 do
            local r = t0roster[i]
            if r and r.name and r.name ~= "" then
                names[#names+1] = r.name
                nameClasses[r.name] = r.cls
            end
        end
        if #names == 0 then
            LichborneOutput("|cffC69B3ALichborne:|r No players in T0 5-Man roster.",1,0.5,0.5)
            return
        end
        local function GetClassHex(name)
            local cls = nameClasses[name]
            local c = cls and CLASS_COLORS[cls]
            if c then return string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) end
            return "|cffffff88"
        end
        SetInviteActive(true)
        LichborneOutput("|cffC69B3ALichborne:|r Starting group invite for "..#names.." players...",1,0.85,0)
        if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Logging out all bots...") end
        -- Remove all bots with wildcard first
        SendChatMessage(".playerbots bot remove *", "SAY")
        local invIdx = 1
        local waited = 0
        local grpPhase = "logout_wait"
        local grpReinviteSubPhase = "remove"
        local grpFrame = CreateFrame("Frame")
        activeInviteFrame = grpFrame
        UpdateInviteButtons()
        grpFrame:SetScript("OnUpdate",function(_, elapsed)
            waited = waited + elapsed
            if grpPhase == "logout_wait" then
                if waited < 1.5 then return end
                waited = 0
                LeaveParty()
                grpPhase = "leave_wait"
                LichborneOutput("|cffC69B3ALichborne:|r Bots removed, leaving party...",1,0.85,0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Leaving party, then inviting...") end
            elseif grpPhase == "leave_wait" then
                if waited < 1.0 then return end
                waited = 0
                grpPhase = "invite"
                LichborneOutput("|cffC69B3ALichborne:|r Starting group invites...",1,0.85,0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Inviting "..#names.." players...") end
            elseif grpPhase == "invite" then
                if waited < 0.8 then return end
                waited = 0
                if invIdx > #names then
                    -- Verify pass
                    grpPhase = "verify_wait"
                    waited = 0
                    LichborneOutput("|cffC69B3ALichborne:|r Initial invites sent, verifying...",1,0.85,0)
                    return
                end
                local pname = names[invIdx]
                SendChatMessage(".playerbots bot add "..pname, "SAY")
                LichborneOutput("|cffC69B3ALichborne:|r Inviting "..GetClassHex(pname)..pname.."|r...",1,0.85,0)
                invIdx = invIdx + 1
            elseif grpPhase == "verify_wait" then
                if waited < 3.0 then return end
                -- Build set of who is currently in the party
                local inParty = {}
                for pi = 1, GetNumPartyMembers() do
                    local pn = UnitName("party"..pi)
                    if pn then inParty[pn:lower()] = true end
                end
                local selfName = UnitName("player")
                if selfName then inParty[selfName:lower()] = true end
                local missing = {}
                for _, pname in ipairs(names) do
                    if not inParty[pname:lower()] then
                        missing[#missing+1] = pname
                    end
                end
                if #missing == 0 then
                    LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44All "..#names.." players confirmed in group!|r",1,0.85,0)
                    if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44All "..#names.." players confirmed in group.|r") end
                    grpFrame:SetScript("OnUpdate",nil)
                    activeInviteFrame = nil
                    SetInviteActive(false)
                    UpdateInviteButtons()
                    return
                end
                LichborneOutput("|cffC69B3ALichborne:|r |cffff9900"..#missing.." missed — re-inviting...|r",1,0.85,0)
                names = missing
                invIdx = 1
                grpPhase = "reinvite"
                waited = 0
            elseif grpPhase == "reinvite" then
                if grpReinviteSubPhase == "remove" then
                    if invIdx > #names then
                        LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44Re-invite pass complete.|r",1,0.85,0)
                        if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44Invite complete (re-invite pass done).|r") end
                        grpFrame:SetScript("OnUpdate",nil)
                        activeInviteFrame = nil
                        SetInviteActive(false)
                        UpdateInviteButtons()
                        return
                    end
                    local pname = names[invIdx]
                    SendChatMessage(".playerbots bot remove "..pname, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Removing "..GetClassHex(pname)..pname.."|r before re-invite...",1,0.85,0)
                    waited = 0
                    grpReinviteSubPhase = "add"
                elseif grpReinviteSubPhase == "add" then
                    if waited < 1.0 then return end
                    local pname = names[invIdx]
                    SendChatMessage(".playerbots bot add "..pname, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Re-inviting "..GetClassHex(pname)..pname.."|r...",1,0.85,0)
                    invIdx = invIdx + 1
                    waited = 0
                    grpReinviteSubPhase = "remove"
                end
            end
        end)
    end)
    _G["LichborneInviteGroupBtn"] = inviteGroupBtn

    -- â”€â”€ Stop Invite overlay (full right column, covers both invite buttons) â”€â”€
    local stopInviteBtn = CreateFrame("Button","LichborneStopInviteBtn",LichborneRaidFrame:GetParent())
    stopInviteBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 495, 8)
    stopInviteBtn:SetSize(155, 130)
    stopInviteBtn:SetFrameLevel(fl + 13)
    stopInviteBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    stopInviteBtn:SetBackdropColor(0.25, 0.05, 0.05, 1)
    stopInviteBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    stopInviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local stopInviteLbl = stopInviteBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    stopInviteLbl:SetAllPoints(stopInviteBtn); stopInviteLbl:SetJustifyH("CENTER"); stopInviteLbl:SetJustifyV("MIDDLE")
    stopInviteLbl:SetText("|cffd4af37Stop Invite|r")
    stopInviteBtn:SetScript("OnEnter",function()
        GameTooltip:SetOwner(stopInviteBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("Stop Invite",1,1,1)
        GameTooltip:AddLine("Cancels the running invite script.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    stopInviteBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    stopInviteBtn:SetScript("OnClick",function()
        if activeInviteFrame then
            activeInviteFrame:SetScript("OnUpdate", nil)
            activeInviteFrame = nil
            SetInviteActive(false)
            UpdateInviteButtons()
            LichborneOutput("|cffC69B3ALichborne:|r |cffff4444Invite stopped.|r", 1, 0.85, 0)
            if LichborneAddStatus then LichborneAddStatus:SetText("|cffff4444Invite stopped.") end
        end
    end)
    stopInviteBtn:Hide()
    _G["LichborneStopInviteBtn"] = stopInviteBtn

    UpdateInviteButtons()

end


-- Helper: get current All group rows
local function GetCurrentOverviewRows()
    if not LichborneTrackerDB.allGroups then
        LichborneTrackerDB.allGroups = {}
    end
    if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
    local g = LichborneTrackerDB.allGroup
    if not LichborneTrackerDB.allGroups[g] then
        LichborneTrackerDB.allGroups[g] = {}
        for i=1,60 do LichborneTrackerDB.allGroups[g][i]={name="",cls="",spec="",gs=0,realGs=0} end
    end
    local rows = LichborneTrackerDB.allGroups[g]
    for i=1,60 do if not rows[i] then rows[i]={name="",cls="",spec="",gs=0,realGs=0} end end
    return rows
end

-- ── Overview tab: mirrors Raid tab with 3 columns of 20 = 60 slots ──────────
RefreshOverviewRows = function()
    if not LichborneOverviewFrame then return end
    local rows = GetCurrentOverviewRows()

    -- Update Overview tab group label
    local g = LichborneTrackerDB.allGroup or "A"
    if LichborneAllPageLbl then
        local pageNum = ({A="1",B="2",C="3"})[g] or g
        LichborneAllPageLbl:SetText("|cffd4af37Page "..pageNum.." v|r")
    end

    -- Overflow sync: rebuild all three groups from class tabs sequentially
    -- A=slots 1-60, B=slots 61-120, C=slots 121-180
    -- Collect ALL tracked characters in order
    local allTracked = {}
    for _, classRow in ipairs(LichborneTrackerDB.rows or {}) do
        if classRow.name and classRow.name ~= "" then
            allTracked[#allTracked+1] = classRow
        end
    end
    -- Apply group filter: show only party/raid members in Overview tab
    if LBFilter.groupActive then
        local gnames = GetGroupMemberNameSet()
        local filtered = {}
        for _, r in ipairs(allTracked) do
            if gnames[r.name] then filtered[#filtered+1] = r end
        end
        allTracked = filtered
    end
    -- Apply hide-raid filter: exclude characters already in the raid tab roster
    if LBFilter.hideRaid then
        local raidFiltered = {}
        for _, r in ipairs(allTracked) do
            if IsInActiveRaid(r.name or "") then raidFiltered[#raidFiltered+1] = r end
        end
        allTracked = raidFiltered
    end
    -- Apply sort globally across ALL characters before splitting into pages
    if allSortKey then
        local function nameEmpty(r) return not r.name or r.name == "" end
        if allSortKey == "spec" then
            table.sort(allTracked, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ac, bc = a.cls or "", b.cls or ""
                if ac ~= bc then
                    if allSortAsc then return ac < bc else return ac > bc end
                end
                local as2, bs2 = a.spec or "", b.spec or ""
                if as2 ~= bs2 then return as2 < bs2 end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "name" then
            table.sort(allTracked, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local an, bn = a.name or "", b.name or ""
                if an ~= bn then
                    if allSortAsc then return an < bn else return an > bn end
                end
                return false
            end)
        elseif allSortKey == "ilvl" then
            table.sort(allTracked, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ag, bg2 = a.gs or 0, b.gs or 0
                if ag ~= bg2 then
                    if allSortAsc then return ag < bg2 else return ag > bg2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "gs" then
            table.sort(allTracked, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ag, bg2 = a.realGs or 0, b.realGs or 0
                if ag ~= bg2 then
                    if allSortAsc then return ag < bg2 else return ag > bg2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "inraid" then
            table.sort(allTracked, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ai = IsInActiveRaid(a.name or "") and 1 or 0
                local bi = IsInActiveRaid(b.name or "") and 1 or 0
                if ai ~= bi then
                    if allSortAsc then return ai > bi else return ai < bi end
                end
                local ac, bc = a.cls or "", b.cls or ""
                if ac ~= bc then return ac < bc end
                local as2, bs2 = a.spec or "", b.spec or ""
                if as2 ~= bs2 then return as2 < bs2 end
                return (a.name or "") < (b.name or "")
            end)
        end
    end
    -- Fill groups in order
    local groups = {"A","B","C"}
    for gi, g in ipairs(groups) do
        if not LichborneTrackerDB.allGroups[g] then
            LichborneTrackerDB.allGroups[g] = {}
        end
        local gRows = LichborneTrackerDB.allGroups[g]
        for i=1,60 do if not gRows[i] then gRows[i]={name="",cls="",spec="",gs=0,realGs=0} end end
        local startIdx = (gi-1)*60 + 1
        local endIdx   = gi*60
        -- Clear first
        for i=1,60 do gRows[i]={name="",cls="",spec="",gs=0,realGs=0} end
        -- Fill with tracked chars for this range
        for i=startIdx,endIdx do
            local slot = i - startIdx + 1
            if allTracked[i] then
                local cr = allTracked[i]
                gRows[slot] = {name=cr.name, cls=cr.cls or "", spec=cr.spec or "", gs=cr.gs or 0, realGs=cr.realGs or 0}
            end
        end
    end
    -- Re-get rows for current group display
    rows = GetCurrentOverviewRows()

    -- Apply sort if active (sort a copy so DB order is unchanged)
    if allSortKey then
        local function nameEmpty(r) return not r.name or r.name == "" end
        local sorted = {}
        for i = 1, 60 do sorted[i] = rows[i] end
        if allSortKey == "spec" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ac, bc = a.cls or "", b.cls or ""
                if ac ~= bc then
                    if allSortAsc then return ac < bc else return ac > bc end
                end
                local as2, bs2 = a.spec or "", b.spec or ""
                if as2 ~= bs2 then return as2 < bs2 end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "name" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local an, bn = a.name or "", b.name or ""
                if an ~= bn then
                    if allSortAsc then return an < bn else return an > bn end
                end
                return false
            end)
        elseif allSortKey == "ilvl" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ag, bg2 = a.gs or 0, b.gs or 0
                if ag ~= bg2 then
                    if allSortAsc then return ag < bg2 else return ag > bg2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "gs" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ag, bg2 = a.realGs or 0, b.realGs or 0
                if ag ~= bg2 then
                    if allSortAsc then return ag < bg2 else return ag > bg2 end
                end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortKey == "inraid" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ai = IsInActiveRaid(a.name or "") and 1 or 0
                local bi = IsInActiveRaid(b.name or "") and 1 or 0
                if ai ~= bi then
                    if allSortAsc then return ai > bi else return ai < bi end
                end
                -- within same raid-status group: class A-Z, then spec A-Z, then name
                local ac, bc = a.cls or "", b.cls or ""
                if ac ~= bc then return ac < bc end
                local as2, bs2 = a.spec or "", b.spec or ""
                if as2 ~= bs2 then return as2 < bs2 end
                return (a.name or "") < (b.name or "")
            end)
        end
        rows = sorted
    end

    for i = 1, 60 do
        local rf = overviewRowFrames[i]
        if not rf then break end
        local data = rows[i]
        local dataRef = data
        local hasData = data.name and data.name ~= ""

        -- Sync spec from class tabs
        if hasData then
            for _, r in ipairs(LichborneTrackerDB.rows) do
                if r.name and r.name:lower() == data.name:lower() then
                    if r.spec and r.spec ~= "" then data.spec = r.spec end
                    if r.cls and r.cls ~= "" then data.cls = r.cls end
                    if r.gs and r.gs > 0 then data.gs = r.gs end
                    data.realGs = r.realGs or 0
                    data.level = r.level or 0
                    break
                end
            end
        end

        -- Needs cell refresh
        if rf.needsCell then
            RefreshNeedsCell(rf.needsCell, data.name or "")
        end

        -- Class icon
        if rf.classIcon then
            local cIcon = CLASS_ICONS[data.cls or ""]
            if cIcon and hasData then rf.classIcon:SetTexture(cIcon); rf.classIcon:SetAlpha(1)
            else rf.classIcon:SetTexture(0,0,0,0) end
        end
        -- Spec icon
        if rf.specIcon then
            local sIcon = data.spec and data.spec ~= "" and SPEC_ICONS[data.spec]
            if sIcon and hasData then rf.specIcon:SetTexture(sIcon); rf.specIcon:SetAlpha(1)
            elseif hasData then rf.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); rf.specIcon:SetAlpha(0.2)
            else rf.specIcon:SetTexture(0,0,0,0) end
        end
        -- Name (read-only - populated from class tabs)
        if rf.nameBox then
            local name = data.name or ""
            rf.nameBox.readOnly = name  -- store for OnChar guard
            rf.nameBox:SetScript("OnTextChanged", nil)
            rf.nameBox:SetText(name)
            local c = data.cls and CLASS_COLORS[data.cls]
            if c then rf.nameBox:SetTextColor(c.r, c.g, c.b)
            else rf.nameBox:SetTextColor(0.7,0.8,0.9) end
            -- Prevent editing - restore on any change
            rf.nameBox:SetScript("OnTextChanged", function()
                if rf.nameBox:GetText() ~= (rf.nameBox.readOnly or "") then
                    rf.nameBox:SetText(rf.nameBox.readOnly or "")
                end
            end)
        end
        -- iLvl (read-only on Overview tab)
        if rf.gsBox then
            rf.gsBox:SetScript("OnTextChanged", nil)
            rf.gsBox:SetText(data.gs and data.gs > 0 and tostring(data.gs) or "")
            rf.gsBox.readOnly = rf.gsBox:GetText()
            rf.gsBox:SetScript("OnTextChanged", function()
                if rf.gsBox:GetText() ~= (rf.gsBox.readOnly or "") then
                    rf.gsBox:SetText(rf.gsBox.readOnly or "")
                end
            end)
        end
        -- GS (read-only on Overview tab)
        if rf.realGsBox then
            rf.realGsBox:SetScript("OnTextChanged", nil)
            rf.realGsBox:SetText(data.realGs and data.realGs > 0 and tostring(data.realGs) or "")
            rf.realGsBox.readOnly = rf.realGsBox:GetText()
            rf.realGsBox:SetScript("OnTextChanged", function()
                if rf.realGsBox:GetText() ~= (rf.realGsBox.readOnly or "") then
                    rf.realGsBox:SetText(rf.realGsBox.readOnly or "")
                end
            end)
        end
        -- Row number
        if rf.numLbl then
            if LBFilter.showLevel and hasData and (data.level or 0) > 0 then
                rf.numLbl:SetText(tostring(data.level))
                rf.numLbl:SetTextColor(0.83, 0.69, 0.22)
            else
                rf.numLbl:SetText(tostring(i))
                rf.numLbl:SetTextColor(0.4, 0.5, 0.6)
            end
        end
        -- No delete on Overview tab

        -- Spec button popup (same menu as raid/class tabs)
        if rf.specIcon then
            local specFrame = rf.specIcon and rf.specIcon:GetParent()
            if specFrame then
                specFrame:SetScript("OnEnter", function()
                    local d4 = dataRef
                    local spec = d4 and d4.spec or ""
                    local cls = d4 and d4.cls or ""
                    local c = cls ~= "" and CLASS_COLORS[cls]
                    GameTooltip:SetOwner(specFrame, "ANCHOR_RIGHT")
                    if spec ~= "" then
                        GameTooltip:AddLine(spec, 1, 1, 1)
                    end
                    if cls ~= "" then
                        if c then GameTooltip:AddLine(cls, c.r, c.g, c.b)
                        else GameTooltip:AddLine(cls, 0.8, 0.8, 0.9) end
                    end
                    if spec == "" and cls == "" then
                        GameTooltip:AddLine("Empty", 0.4, 0.4, 0.4)
                    end
                    GameTooltip:Show()
                end)
                specFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
        -- Add to Group btn
        if rf.addGroupBtn then
            rf.addGroupBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            rf.addGroupBtn:SetScript("OnClick", function(self, btn)
                local d = dataRef
                if not d or not d.name or d.name == "" then return end
                local c = d.cls and CLASS_COLORS[d.cls]
                local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
                if btn == "RightButton" then
                    UninviteUnit(d.name)
                    SendChatMessage(".playerbots bot remove "..d.name, "SAY")
                    LichborneOutput("|cffC69B3ALichborne:|r Removed "..hex..d.name.."|r from bots.", 1, 0.85, 0)
                    return
                end
                SendChatMessage(".playerbots bot add "..d.name, "SAY")
                if LichborneAddStatus then LichborneAddStatus:SetText("Invited "..hex..d.name.."|r to group.") end
            end)
        end
        -- Add to Raid btn
        if rf.addRaidBtn then
            -- Color + orange (T1) when in raid, green when not
            if IsInActiveRaid(data.name) then
                rf.addRaidBtn:SetText("|cffb25b00+|r")
            else
                rf.addRaidBtn:SetText("|cff44ff44+|r")
            end
            rf.addRaidBtn:SetScript("OnClick", function(self, btn)
                local d = dataRef
                if not d or not d.name or d.name == "" then return end
                local c = d.cls and CLASS_COLORS[d.cls]
                local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
                if btn == "RightButton" then
                    -- Remove from raid
                    local roster, _ = GetCurrentRoster()
                    for ri = 1, MAX_RAID_SLOTS do
                        if roster[ri] and roster[ri].name and roster[ri].name:lower() == d.name:lower() then
                            local slot = ri
                            roster[ri] = {name="", cls="", spec="", gs=0, realGs=0, role="", notes=""}
                            rf.addRaidBtn:SetText("|cff44ff44+|r")
                            if LichborneAddStatus then
                                LichborneAddStatus:SetText(hex..d.name.."|r removed from raid slot "..slot..".")
                            end
                            if LichborneRaidFrame then RefreshRaidRows() end
                            RefreshOverviewRows()
                            return
                        end
                    end
                    return
                end
                -- Left click: add to raid
                local roster, raidSize = GetCurrentRoster()
                for ri = 1, raidSize do
                    if roster[ri] and roster[ri].name and roster[ri].name:lower() == d.name:lower() then
                        if LichborneAddStatus then LichborneAddStatus:SetText(hex..d.name.."|r is already in the Raid.") end; return
                    end
                end
                for ri = 1, raidSize do
                    if not roster[ri] or roster[ri].name == "" then
                        roster[ri] = {name=d.name, cls=d.cls or "",spec=d.spec or "",gs=d.gs or 0, realGs=d.realGs or 0, role="", notes=""}
                        if LichborneAddStatus then LichborneAddStatus:SetText(hex..d.name.."|r added to raid slot "..ri..".") end
                        -- Color + orange after successful add
                        rf.addRaidBtn:SetText("|cffb25b00+|r")
                        if LichborneRaidFrame then RefreshRaidRows() end
                        return
                    end
                end
                if LichborneAddStatus then LichborneAddStatus:SetText("Raid is full!") end
            end)
        end
        -- Wire delete button
        if rf.allDelBtnFrame then
            rf.allDelBtnFrame:SetScript("OnClick", function()
                local d = dataRef
                if not d or not d.name or d.name == "" then return end
                local charName = d.name
                RemoveCharacterReferences(charName)
                if LichborneAddStatus then
                    LichborneAddStatus:SetText("|cffff6666"..charName.."|r removed from tracker.")
                end
                RefreshRows()
                RefreshOverviewRows()
                if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            end)
        end
    end

    -- Count bar
    if LichborneAllCountLabels then
        local allCounts = {}
        for _, cls in ipairs(CLASS_TABS) do if cls ~= "Raid" and cls ~= "Overview" then allCounts[cls] = 0 end end
        -- Count from ALL tracked rows, not just the current page
        for _, r in ipairs(LichborneTrackerDB.rows or {}) do
            if r and r.name and r.name ~= "" and r.cls and allCounts[r.cls] ~= nil then
                allCounts[r.cls] = allCounts[r.cls] + 1
            end
        end
        for cls, lbl in pairs(LichborneAllCountLabels) do
            local c = CLASS_COLORS[cls]
            if c then
                local n = allCounts[cls] or 0
                local hex = string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255))
                lbl:SetText(hex..(TAB_LABELS[cls])..": |cffd4af37"..n.."|r")
                local sw = lbl:GetParent()
                if sw and sw.bg then
                    if n > 0 then sw.bg:SetTexture(c.r*0.25,c.g*0.25,c.b*0.30,1)
                    else sw.bg:SetTexture(0.08,0.10,0.18,1) end
                end
            end
        end
    end
end  -- RefreshOverviewRows

-- Overview frame uses same layout as Raid: 3 columns of 20, same row height
local ALL_PER_COL = 20
local ALL_NCOLS   = 3
local ALL_COL_W   = 362   -- fits the tracker frame; internal columns are tightened to fit iLvl + GS

local function BuildOverviewFrame(parent, fl)
    if overviewFrameBuilt then return end
    overviewFrameBuilt = true

    LichborneOverviewFrame = CreateFrame("Frame","LichborneOverviewFrame",parent)
    LichborneOverviewFrame:SetPoint("TOPLEFT",parent,"TOPLEFT",15,-66)
    LichborneOverviewFrame:SetSize(ALL_NCOLS*ALL_COL_W, 512)  -- 24hdr+20+18hdr+20+440rows+10+24count
    LichborneOverviewFrame:SetFrameLevel(fl+10)
    LichborneOverviewFrame:Hide()

    -- Green header bar
    local allHdr = CreateFrame("Frame",nil,LichborneOverviewFrame)
    allHdr:SetPoint("TOPLEFT",LichborneOverviewFrame,"TOPLEFT",0,0)
    allHdr:SetSize(ALL_NCOLS*ALL_COL_W,24); allHdr:SetFrameLevel(fl+11)
    local allHdrBg = allHdr:CreateTexture(nil,"BACKGROUND"); allHdrBg:SetAllPoints(allHdr); allHdrBg:SetTexture(0.05,0.20,0.05,1)
    local allTitle = allHdr:CreateFontString(nil,"OVERLAY","GameFontNormal")
    allTitle:SetPoint("TOPLEFT",allHdr,"TOPLEFT",0,0); allTitle:SetPoint("TOPRIGHT",allHdr,"TOPRIGHT",0,0)
    allTitle:SetHeight(24); allTitle:SetJustifyH("CENTER"); allTitle:SetJustifyV("MIDDLE")
    allTitle:SetText("|cffd4af37Character Sheet|r")

    -- Sort / Clear buttons
    local function MakeHdrBtn(lbl, br, bg2, bb, xOff, w)
        local btn = CreateFrame("Button",nil,allHdr); btn:SetSize(w or 55,20)
        btn:SetPoint("RIGHT",allHdr,"RIGHT",xOff,0); btn:SetFrameLevel(fl+12)
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
        btn:SetBackdropColor(br*0.4,bg2*0.4,bb*0.4,1); btn:SetBackdropBorderColor(br,bg2,bb,0.9)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local l=btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); l:SetAllPoints(btn); l:SetJustifyH("CENTER"); l:SetJustifyV("MIDDLE"); l:SetText(lbl)
        return btn
    end
    -- Page label (far right, dropdown trigger)
    -- Page button - same style as Sort
    local overviewPageBtn = CreateFrame("Button", "LichborneOverviewPageBtn", allHdr)
    overviewPageBtn:SetSize(55, 20)
    overviewPageBtn:SetPoint("RIGHT", allHdr, "RIGHT", -4, 0)
    overviewPageBtn:SetFrameLevel(fl+12)
    overviewPageBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    overviewPageBtn:SetBackdropColor(0.10, 0.08, 0.02, 1)
    overviewPageBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    overviewPageBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local allPageLbl = overviewPageBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    allPageLbl:SetAllPoints(overviewPageBtn); allPageLbl:SetJustifyH("CENTER"); allPageLbl:SetJustifyV("MIDDLE")
    allPageLbl:SetText("|cffd4af37Page 1 v|r")
    LichborneAllPageLbl  = allPageLbl
    LichborneAllPagePrev = nil
    LichborneAllPageNext = nil
    local allPrevBtn = {}
    local allNextBtn = {}

    -- Single group dropdown on the right (replaces both left Group: and page < > buttons)
    local function UpdateOverviewGroupDD()
        local g = LichborneTrackerDB.allGroup or "A"
        if LichborneAllPageLbl then
            local pageNum = ({A="1",B="2",C="3"})[g] or g
            LichborneAllPageLbl:SetText("|cffd4af37Page "..pageNum.." v|r")
        end
        if LichborneAllPagePrev then LichborneAllPagePrev:SetAlpha(g ~= "A" and 1.0 or 0.35) end
        if LichborneAllPageNext then LichborneAllPageNext:SetAlpha(g ~= "C" and 1.0 or 0.35) end
    end
    UpdateOverviewGroupDD()

    -- Dropdown menu triggered by clicking the Group label
    local overviewGroupMenu = CreateFrame("Frame","LichborneOverviewGroupMenu",UIParent)
    overviewGroupMenu:SetFrameStrata("TOOLTIP"); overviewGroupMenu:SetSize(90,3*22+8)
    overviewGroupMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    overviewGroupMenu:SetBackdropColor(0.05,0.08,0.20,0.98); overviewGroupMenu:SetBackdropBorderColor(0.30,0.50,0.80,1)
    overviewGroupMenu:Hide()
    for gi, gname in ipairs({"A","B","C"}) do
        local mb=CreateFrame("Button",nil,overviewGroupMenu); mb:SetSize(86,20)
        mb:SetPoint("TOPLEFT",overviewGroupMenu,"TOPLEFT",2,-2-(gi-1)*22)
        mb:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        mb:SetBackdropColor(0.05,0.08,0.20,1); mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local mblbl=mb:CreateFontString(nil,"OVERLAY","GameFontNormal"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
        mblbl:SetText("|cffd4af37Page "..gi.."|r")
        local cap=gname
        mb:SetScript("OnClick",function()
            LichborneTrackerDB.allGroup=cap; UpdateOverviewGroupDD(); overviewGroupMenu:Hide(); RefreshOverviewRows()
        end)
    end
    -- Wire the page button to open the dropdown menu
    overviewPageBtn:SetScript("OnClick", function()
        if overviewGroupMenu:IsShown() then overviewGroupMenu:Hide()
        else overviewGroupMenu:ClearAllPoints(); overviewGroupMenu:SetPoint("TOPRIGHT",overviewPageBtn,"BOTTOMRIGHT",0,-2); overviewGroupMenu:Show() end
    end)

    -- Column headers (3 cols; left col has sortable buttons, right cols plain labels)
    local RH_ALL = 22
    allSortHdrs = {}
    local function UpdateAllSortHeaders()
        for key, entry in pairs(allSortHdrs) do
            if key == "inraid" then
                for _, fs in ipairs(entry.fsList) do
                    fs:SetText("|cffd4af37+|r")
                end
            end
        end
    end
    for col = 0, ALL_NCOLS-1 do
        local hdr = CreateFrame("Frame",nil,LichborneOverviewFrame)
        hdr:SetPoint("TOPLEFT",LichborneOverviewFrame,"TOPLEFT",col*ALL_COL_W,-26)
        hdr:SetSize(ALL_COL_W,18); hdr:SetFrameLevel(fl+11)
        local hbg=hdr:CreateTexture(nil,"BACKGROUND"); hbg:SetAllPoints(hdr); hbg:SetTexture(0.08,0.20,0.42,1)
        local function H(txt,x,w) local fs=hdr:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); fs:SetPoint("LEFT",hdr,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER"); fs:SetText("|cffd4af37"..txt.."|r") end
        if col == 0 then
            local function ASH(lbl, x, w, key)
                if not allSortHdrs[key] then allSortHdrs[key] = {lbl=lbl, fsList={}} end
                local entry = allSortHdrs[key]
                local btn = CreateFrame("Button",nil,hdr)
                btn:SetPoint("TOPLEFT",hdr,"TOPLEFT",x,0)
                btn:SetSize(w,18); btn:SetFrameLevel(hdr:GetFrameLevel()+1)
                btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
                local fs = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                fs:SetPoint("CENTER",btn,"CENTER",0,0); fs:SetSize(w+6,18); fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
                fs:SetText("|cffd4af37"..lbl.."|r")
                entry.fsList[#entry.fsList+1] = fs
                btn:SetScript("OnEnter",function()
                    GameTooltip:SetOwner(btn,"ANCHOR_RIGHT")
                    GameTooltip:AddLine("Click to sort",1,1,1)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave",function() GameTooltip:Hide() end)
                btn:SetScript("OnClick",function()
                    if allSortKey == key then
                        allSortAsc = not allSortAsc
                    else
                        allSortKey = key
                        allSortAsc = true
                    end
                    UpdateAllSortHeaders()
                    RefreshOverviewRows()
                end)
            end
            ASH("Spec",14,48,"spec")
            ASH("Name",60,126,"name")
            ASH("iLvL",187,38,"ilvl")
            ASH("GS",225,38,"gs")
            H("Need",266,38)
            ASH("+",308,18,"inraid")
        else
            H("Spec",16,44); H("Name",62,124); H("iLvL",190,36); H("GS",228,36); H("Need",266,38)
        end
    end

    -- 60 rows across 3 columns
    for i = 1, 60 do
        local col = math.floor((i-1)/ALL_PER_COL)
        local rowInCol = (i-1) % ALL_PER_COL
        local rf = CreateFrame("Frame",nil,LichborneOverviewFrame)
        rf:SetPoint("TOPLEFT",LichborneOverviewFrame,"TOPLEFT",col*ALL_COL_W,-(46+rowInCol*RH_ALL))
        rf:SetSize(ALL_COL_W, RH_ALL); rf:SetFrameLevel(fl+11)
        local rbg=rf:CreateTexture(nil,"BACKGROUND"); rbg:SetAllPoints(rf)
        rbg:SetTexture(rowInCol%2==0 and 0.06 or 0.04, rowInCol%2==0 and 0.08 or 0.06, rowInCol%2==0 and 0.16 or 0.12, 1)
        local allHov=rf:CreateTexture(nil,"OVERLAY"); allHov:SetAllPoints(rf); allHov:SetTexture(0,0,0,0)
        rf:EnableMouse(true)
        rf:SetScript("OnEnter", function() allHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        rf:SetScript("OnLeave", function() allHov:SetTexture(0, 0, 0, 0) end)

        -- Row number
        local nl=rf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); nl:SetPoint("LEFT",rf,"LEFT",2,0); nl:SetWidth(18); nl:SetJustifyH("CENTER"); nl:SetTextColor(0.4,0.5,0.6); rf.numLbl=nl

        -- Class icon
        local cF=CreateFrame("Frame",nil,rf); cF:SetPoint("LEFT",rf,"LEFT",20,0); cF:SetSize(18,18)
        local cT=cF:CreateTexture(nil,"ARTWORK"); cT:SetAllPoints(cF); rf.classIcon=cT

        -- Spec icon
        local sF=CreateFrame("Button",nil,rf); sF:SetPoint("LEFT",rf,"LEFT",40,0); sF:SetSize(18,18)
        sF:SetFrameLevel(rf:GetFrameLevel()+4)
        sF:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local sT=sF:CreateTexture(nil,"ARTWORK"); sT:SetAllPoints(sF); rf.specIcon=sT

        -- Name editbox
        local nb=CreateFrame("EditBox",nil,rf); nb:SetPoint("LEFT",rf,"LEFT",60,0); nb:SetSize(126,RH_ALL-2)
        nb:SetAutoFocus(false); nb:SetMaxLetters(32); nb:SetFont("Fonts\\FRIZQT__.TTF",10); nb:SetTextColor(0.9,0.95,1.0)
        nb:SetScript("OnChar",function() nb:SetText(nb.readOnly or "") end)  -- read-only
        nb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        nb:SetBackdropColor(0.05,0.07,0.14,0.6); nb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        nb:SetScript("OnEnterPressed",function() nb:ClearFocus() end); nb:SetScript("OnTabPressed",function() nb:ClearFocus() end)
        rf.nameBox=nb

        -- iLvl editbox
        local gb=CreateFrame("EditBox",nil,rf); gb:SetPoint("LEFT",rf,"LEFT",188,0); gb:SetSize(36,RH_ALL-2)
        gb:SetAutoFocus(false); gb:SetMaxLetters(5); gb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE"); gb:SetTextColor(0.831, 0.686, 0.216); gb:SetJustifyH("CENTER")
        gb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gb:SetBackdropColor(0.05,0.07,0.14,0.6); gb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        gb:SetScript("OnEnterPressed",function() gb:ClearFocus() end); gb:SetScript("OnTabPressed",function() gb:ClearFocus() end)
        rf.gsBox=gb
        gb:SetScript("OnEnter", function() allHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        gb:SetScript("OnLeave", function() if GetMouseFocus()~=rf then allHov:SetTexture(0,0,0,0) end end)

        -- GS editbox
        local rgb=CreateFrame("EditBox",nil,rf); rgb:SetPoint("LEFT",rf,"LEFT",226,0); rgb:SetSize(36,RH_ALL-2)
        rgb:SetAutoFocus(false); rgb:SetMaxLetters(5); rgb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE"); rgb:SetTextColor(0.831, 0.686, 0.216); rgb:SetJustifyH("CENTER")
        rgb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        rgb:SetBackdropColor(0.05,0.07,0.14,0.6); rgb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        rgb:SetScript("OnEnterPressed",function() rgb:ClearFocus() end); rgb:SetScript("OnTabPressed",function() rgb:ClearFocus() end)
        rf.realGsBox=rgb
        rgb:SetScript("OnEnter", function() allHov:SetTexture(0.78, 0.61, 0.23, 0.12) end)
        rgb:SetScript("OnLeave", function() if GetMouseFocus()~=rf then allHov:SetTexture(0,0,0,0) end end)

        -- Needs cell (replaces Tier)
        local allRowIdx = i
        rf.needsCell = MakeNeedsCell(rf, 264, RH_ALL, function()
            local r6 = overviewRowFrames[allRowIdx]
            if r6 and r6.nameBox then return r6.nameBox.readOnly or "" end
            return ""
        end, allHov, 46)

        -- Add to Group btn >
        -- Add to Raid btn + (first)
        local ar=CreateFrame("Button",nil,rf); ar:SetPoint("LEFT",rf,"LEFT",312,0); ar:SetSize(16,RH_ALL-2)
        ar:SetNormalFontObject("GameFontNormalSmall"); ar:SetText("|cff44ff44+|r")
        ar:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        ar:SetScript("OnEnter",function()
            local raidName = LichborneTrackerDB.raidName or "?"
            local raidAbbr = RAID_ABBR and RAID_ABBR[raidName] or raidName
            local tier = LichborneTrackerDB.raidTier or 0
            local tierStr = tier > 0 and ("T"..tier) or "T0"
            local grp = LichborneTrackerDB.raidGroup or "A"
            GameTooltip:SetOwner(ar,"ANCHOR_RIGHT")
            GameTooltip:AddLine("+ Add to Raid", 0.3, 1.0, 0.3)
            GameTooltip:AddLine(tierStr.."  "..raidAbbr.."  Group "..grp, 1, 0.85, 0)
            GameTooltip:AddLine("Right-click to remove.", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        ar:SetScript("OnLeave",function() GameTooltip:Hide() end)
        ar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        rf.addRaidBtn=ar

        -- Invite to group btn > (second)
        local ag=CreateFrame("Button",nil,rf); ag:SetPoint("LEFT",rf,"LEFT",330,0); ag:SetSize(16,RH_ALL-2)
        ag:SetNormalFontObject("GameFontNormalSmall"); ag:SetText("|cff44eeff>|r")
        ag:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        ag:SetScript("OnEnter",function()
            GameTooltip:SetOwner(ag,"ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44eeff> Invite to Group|r",1,1,1)
            GameTooltip:AddLine("Left-click to invite to group.",0.7,0.7,0.7)
            GameTooltip:AddLine("Right-click to remove.",0.7,0.4,0.4)
            GameTooltip:Show()
        end)
        ag:SetScript("OnLeave",function() GameTooltip:Hide() end)
        rf.addGroupBtn=ag

        -- Delete btn x (third)
        local dx=CreateFrame("Button",nil,rf); dx:SetPoint("LEFT",rf,"LEFT",348,0); dx:SetSize(16,RH_ALL-2)
        dx:SetNormalFontObject("GameFontNormalSmall"); dx:SetText("|cffaa2222x|r")
        dx:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        dx:SetScript("OnEnter",function()
            GameTooltip:SetOwner(dx,"ANCHOR_RIGHT")
            GameTooltip:AddLine("Delete Character",1,0.3,0.3)
            GameTooltip:AddLine("Removes from tracker.",0.8,0.8,0.8)
            GameTooltip:Show()
        end)
        dx:SetScript("OnLeave",function() GameTooltip:Hide() end)
        rf.allDelBtn=dx

        -- Hook child elements to propagate row highlight
        HookRowHighlight(ag, rf, allHov)
        HookRowHighlight(ar, rf, allHov)
        HookRowHighlight(dx, rf, allHov)
        if rf.specBtn then HookRowHighlight(rf.specBtn, rf, allHov) end

        -- Wire delete button in RefreshOverviewRows (needs dbIndex set first)
        rf.allDelBtnFrame = dx

        -- Divider
        local ln=rf:CreateTexture(nil,"OVERLAY"); ln:SetHeight(1); ln:SetWidth(ALL_COL_W)
        ln:SetPoint("BOTTOMLEFT",rf,"BOTTOMLEFT",0,0); ln:SetTexture(0.10,0.16,0.28,0.4)

        overviewRowFrames[i]=rf
    end

    -- Count bar at bottom
    local cbY = -(46 + ALL_PER_COL*RH_ALL + 2)  -- below last row
    local allCB = CreateFrame("Frame","LichborneOverviewCountBar",LichborneOverviewFrame)
    allCB:SetPoint("TOPLEFT",LichborneOverviewFrame,"TOPLEFT",0,cbY)
    allCB:SetSize(ALL_NCOLS*ALL_COL_W,24); allCB:SetFrameLevel(fl+11)
    local acbBg=allCB:CreateTexture(nil,"BACKGROUND"); acbBg:SetAllPoints(allCB); acbBg:SetTexture(0.05,0.07,0.13,1)
    local acT=allCB:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); acT:SetPoint("LEFT",allCB,"LEFT",4,0); acT:SetText("|cffC69B3ACount:|r"); acT:SetWidth(44)
    LichborneAllCountLabels={}
    local acW=(ALL_NCOLS*ALL_COL_W-50)/10
    for ci,cls in ipairs(CLASS_TABS) do
        if cls=="Raid" or cls=="All" then break end
        local c=CLASS_COLORS[cls]
        local sw=CreateFrame("Button",nil,allCB); sw:SetSize(acW-2,20); sw:SetPoint("LEFT",allCB,"LEFT",48+(ci-1)*acW,0)
        sw:SetFrameLevel(allCB:GetFrameLevel()+1)
        local sbg=sw:CreateTexture(nil,"BACKGROUND"); sbg:SetAllPoints(sw); sbg:SetTexture(0.08,0.10,0.18,1); sw.bg=sbg
        local hex=string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255))
        local sl=sw:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); sl:SetAllPoints(sw); sl:SetJustifyH("CENTER"); sl:SetJustifyV("MIDDLE")
        sl:SetText(hex..(TAB_LABELS[cls])..": "..hex.."0|r"); sw.lbl=sl; LichborneAllCountLabels[cls]=sl
    end
end


-- ── Lichborne Output helper ───────────────────────────────────
-- Writes a message to the in-frame output box instead of chat.
-- Falls back gracefully if the frame hasn't been built yet.
LichborneOutput = function(msg, r, g, b)
    local sf = _G["LichborneOutputMsgFrame"]
    if sf then
        sf:AddMessage(msg, r or 1, g or 0.85, b or 0)
    end
end

-- ── Export / Import serialization (module level — must be before OnFirstShow) ──
local function LB_SerializeValue(v)
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local parts = {}
        local maxN = 0
        for k, _ in pairs(v) do
            if type(k) == "number" and k == math.floor(k) and k >= 1 then
                if k > maxN then maxN = k end
            end
        end
        local isArr = maxN > 0
        if isArr then
            for i = 1, maxN do
                if v[i] == nil then isArr = false; break end
            end
        end
        if isArr then
            for i = 1, maxN do
                parts[#parts+1] = LB_SerializeValue(v[i])
            end
        else
            for k, val in pairs(v) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                elseif type(k) == "number" then
                    key = "[" .. tostring(k) .. "]"
                else
                    key = '["' .. tostring(k):gsub('"','\\"') .. '"]'
                end
                parts[#parts+1] = key .. "=" .. LB_SerializeValue(val)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

local EXPORT_PREFIX    = "LICHBORNE_V3:"
local EXPORT_PREFIX_V2 = "LICHBORNE_V2:"
local EXPORT_PREFIX_V1 = "LICHBORNE_V1:"

local function LB_ExportDB()
    local db = LichborneTrackerDB
    -- Build stripped row copies: only identity/social fields.
    -- Gear slot data (ilvl array, ilvlLink, gs, realGs) is excluded intentionally —
    -- a fresh gear scan on Account B will populate those fields correctly.
    local strippedRows = {}
    for i, row in ipairs(db.rows or {}) do
        strippedRows[i] = {
            cls    = row.cls    or "",
            name   = row.name   or "",
            spec   = row.spec   or "",
            role   = row.role   or "",
            gs     = row.gs     or 0,
            realGs = row.realGs or 0,
        }
    end
    local payload = {
        rows        = strippedRows,
        needs       = db.needs,
        raidRosters = db.raidRosters,
        allGroups   = db.allGroups,
        allGroup    = db.allGroup,
        notes       = db.notes,
    }
    return EXPORT_PREFIX .. LB_SerializeValue(payload)
end

local function LB_ImportDB(str)
    if not str or str == "" then return nil, "Nothing to import — paste text first." end
    str = str:match("^%s*(.-)%s*$")
    local data
    if str:find(EXPORT_PREFIX, 1, true) then
        data = str:sub(#EXPORT_PREFIX + 1)
    elseif str:find(EXPORT_PREFIX_V2, 1, true) then
        -- V2: had ZZPIPEZZ escaping; restore pipes after loading
        data = str:sub(#EXPORT_PREFIX_V2 + 1)
    elseif str:find(EXPORT_PREFIX_V1, 1, true) then
        data = str:sub(#EXPORT_PREFIX_V1 + 1)
    else
        return nil, "Not a valid Lichborne export string."
    end
    local fn, err = loadstring("return " .. data)
    if not fn then return nil, "Parse error: " .. (err or "unknown") end
    local ok, result = pcall(fn)
    if not ok then return nil, "Load error: " .. tostring(result) end
    if type(result) ~= "table" then return nil, "Invalid data format." end
    -- V2 legacy: restore pipe placeholders in any ilvlLink strings
    if str:find(EXPORT_PREFIX_V2, 1, true) and result.rows then
        for _, row in pairs(result.rows) do
            if row.ilvlLink then
                for i, lnk in ipairs(row.ilvlLink) do
                    if type(lnk) == "string" and lnk ~= "" then
                        row.ilvlLink[i] = lnk:gsub("ZZPIPEZZ", "|")
                    end
                end
            end
        end
    end
    return result, nil
end

local function OnFirstShow()
    if setupDone then return end
    setupDone = true
    local f = LichborneTrackerFrame
    local fl = f:GetFrameLevel()

    -- Tabs (centered in frame)
    local tabFrame = CreateFrame("Frame", "LichborneTabBar", f)
    tabFrame:SetPoint("TOP", f, "TOP", 0, -36)
    tabFrame:SetSize(1090, 28)
    tabFrame:SetFrameLevel(fl + 8)
    local tabW = 1090 / 12
    for i, cls in ipairs(CLASS_TABS) do
        local btn = CreateFrame("Button", "LichborneTab"..i, tabFrame)
        btn:SetSize(tabW - 1, 26)
        btn:SetPoint("LEFT", tabFrame, "LEFT", (i-1)*tabW, 0)
        btn:SetFrameLevel(fl + 9)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn); bg:SetTexture(0.05, 0.07, 0.12, 1)
        btn.bg = bg
        local bl = btn:CreateTexture(nil, "OVERLAY")
        bl:SetHeight(3); bl:SetWidth(tabW-1)
        bl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
        bl:SetTexture(0, 0, 0, 0)
        btn.bottomLine = bl
        local cc = CLASS_COLORS[cls]
        local hex
        if cls == "Raid" or cls == "Overview" then
            hex = cls == "Overview" and "|cffd4af37" or "|cffC69B3A"
        else
            hex = cc and string.format("|cff%02x%02x%02x",math.floor(cc.r*255),math.floor(cc.g*255),math.floor(cc.b*255)) or "|cffdddddd"
        end
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(hex..(TAB_LABELS[cls] or cls).."|r")
        btn:SetScript("OnClick", function()
            activeTab = cls
            UpdateTabs()
            RefreshRows()
        end)
        btn:SetScript("OnEnter", function()
            btn:SetAlpha(1.0)
            GameTooltip:SetOwner(btn,"ANCHOR_BOTTOM")
            GameTooltip:SetText(cls,1,1,1); GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            if cls ~= activeTab then btn:SetAlpha(0.5) end
            GameTooltip:Hide()
        end)
        tabButtons[cls] = btn
    end
    UpdateTabs()

    -- Column headers
    local hf = CreateFrame("Frame", "LichborneHeaderBar", f)
    hf:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -66)
    hf:SetSize(1086, 20)
    hf:SetFrameLevel(fl + 10)
    local hbg = hf:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints(hf); hbg:SetTexture(0.08, 0.20, 0.42, 1)

    -- Gold border wrapping header through count bar
    local contentBorder = CreateFrame("Frame", nil, f)
    contentBorder:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -64)
    contentBorder:SetSize(1090, 518)
    contentBorder:SetFrameLevel(fl + 9)
    contentBorder:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    contentBorder:SetBackdropColor(0, 0, 0, 0)
    contentBorder:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local function H(lbl, x, w)
        local fs = hf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", hf, "LEFT", x, 0)
        fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cffd4af37"..lbl.."|r")
    end
    local function SH(lbl, x, w, key, isNumeric)
        local btn = CreateFrame("Button", nil, hf)
        btn:SetPoint("TOPLEFT", hf, "TOPLEFT", x, 0)
        btn:SetSize(w, 20); btn:SetFrameLevel(hf:GetFrameLevel() + 2)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints(btn); fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
        fs:SetText("|cffd4af37"..lbl.."|r")
        classSortHdrs[key] = {lbl = lbl, fs = fs}
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Click to sort", 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function()
            local cls = activeTab
            if classSortKey[cls] == key then
                classSortAsc[cls] = not classSortAsc[cls]
            else
                classSortKey[cls] = key
                classSortAsc[cls] = not isNumeric
            end
            UpdateClassSortHeaders()
            RefreshRows()
        end)
    end
    local specHdr = hf:CreateTexture(nil, "OVERLAY")
    specHdr:SetPoint("LEFT", hf, "LEFT", SPEC_OFF + 1, 0)
    specHdr:SetSize(COL_SPEC_W - 2, 18)
    specHdr:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    SH("Spec", SPEC_OFF - 4, COL_SPEC_W + 12, "spec", false)
    SH("Name", NAME_OFF - 4, COL_NAME_W - 40, "name", false)
    SH("iLvL", GS_OFF+2,    COL_GS_W-4,       "ilvl", true)
    SH("GS",   REALGS_OFF+2, COL_GS_W-4,      "gs",   true)
    H("Need", NEEDS_OFF+2, COL_NEEDS_W-4)
    for g, a in ipairs(SLOT_ABBR) do SH(a, GEAR_OFF+(g-1)*COL_GEAR_W, COL_GEAR_W, "gear_"..g, true) end

    -- Build row frames parented directly to main frame, below headers
    BuildRows(f, -90)

    -- Mouse wheel scrolling for class tabs
    local function ClassTabScrollWheel(delta)
        if activeTab == "Raid" or activeTab == "Overview" then return end
        local cls = activeTab
        local offset = classScroll[cls] or 0
        local count = 0
        for _, r in ipairs(LichborneTrackerDB.rows) do
            if r.cls == cls and r.name and r.name ~= "" then count = count + 1 end
        end
        local maxOffset = math.max(0, count - MAX_ROWS)
        classScroll[cls] = math.max(0, math.min(offset - delta, maxOffset))
        RefreshRows()
    end
    for _, rowFr in ipairs(rowFrames) do
        rowFr:EnableMouseWheel(true)
        rowFr:SetScript("OnMouseWheel", function(_, delta) ClassTabScrollWheel(delta) end)
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) ClassTabScrollWheel(delta) end)


    -- Avg iLvl bar
    local avgFrame = CreateFrame("Frame", "LichborneAvgBar", f)
    LichborneAvgBar = avgFrame
    avgFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -530)
    avgFrame:SetSize(1086, 24)
    avgFrame:SetFrameLevel(fl + 10)
    local avgbg = avgFrame:CreateTexture(nil, "BACKGROUND")
    avgbg:SetAllPoints(avgFrame); avgbg:SetTexture(0.05, 0.07, 0.13, 1)
    local avgTitle = avgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgTitle:SetPoint("LEFT", avgFrame, "LEFT", 4, 0)
    avgTitle:SetText("|cffC69B3AAvg iLvL:|r"); avgTitle:SetWidth(52)
    LichborneAvgSwatches = {}
    -- Roster block is 130px wide, 4px gap, label is 56px: swatches fill 1086-56-4-130 = 896px for 10 classes
    local rosterBlockW = 130
    local swTotalW = 1086 - 56 - 4 - rosterBlockW
    local swW = swTotalW / 10
    local avgIdx = 0
    for i, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" then break end
        avgIdx = avgIdx + 1
        local c = CLASS_COLORS[cls]
        local sw = CreateFrame("Button", "LichborneAvgSwatch"..avgIdx, avgFrame)
        sw:SetSize(swW - 2, 20)
        sw:SetPoint("LEFT", avgFrame, "LEFT", 56 + (avgIdx-1)*swW, 0)
        sw:SetFrameLevel(avgFrame:GetFrameLevel() + 1)
        local swbg = sw:CreateTexture(nil, "BACKGROUND")
        swbg:SetAllPoints(sw); swbg:SetTexture(0.08, 0.10, 0.18, 1); sw.bg = swbg
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local lbl = sw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(sw); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(hex..(TAB_LABELS[cls])..": |cff555555--|r"); sw.lbl = lbl; sw.cls = cls
        sw:EnableMouse(true)
        sw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(sw, "ANCHOR_TOP")
            local avg = GetClassAvgIlvl(cls)
            GameTooltip:AddLine(TAB_LABELS[cls], c.r, c.g, c.b)
            GameTooltip:AddLine("Average item level of all tracked "..TAB_LABELS[cls].."s.", 1,1,1)
            if avg > 0 then
                GameTooltip:AddLine("Current: |cffd4af37"..avg.."|r", 1,1,1)
            else
                GameTooltip:AddLine("No gear data yet.", 0.6,0.6,0.6)
            end
            GameTooltip:AddLine("Click to switch to this tab.", 0.5,0.5,0.5)
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sw:SetScript("OnClick", function()
            activeTab = cls
            UpdateTabs()
            RefreshRows()
        end)
        LichborneAvgSwatches[i] = sw
    end

    -- Roster iLvl block — right-anchored, gold border, fills remaining space
    local rosterIlvlBlock = CreateFrame("Frame", "LichborneRosterIlvlBlock", avgFrame)
    rosterIlvlBlock:SetPoint("RIGHT", avgFrame, "RIGHT", 0, 0)
    rosterIlvlBlock:SetSize(rosterBlockW, 24)
    rosterIlvlBlock:SetFrameLevel(avgFrame:GetFrameLevel() + 1)
    rosterIlvlBlock:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    rosterIlvlBlock:SetBackdropColor(0.05, 0.07, 0.13, 1)
    rosterIlvlBlock:SetBackdropBorderColor(0.78, 0.61, 0.23, 1.0)
    local rosterIlvlLbl = rosterIlvlBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rosterIlvlLbl:SetAllPoints(rosterIlvlBlock)
    rosterIlvlLbl:SetJustifyH("CENTER"); rosterIlvlLbl:SetJustifyV("MIDDLE")
    rosterIlvlLbl:SetText("|cffC69B3ARoster iLvL:|r |cff555555--|r")
    LichborneRosterIlvlLabel = rosterIlvlLbl
    rosterIlvlBlock:EnableMouse(true)
    rosterIlvlBlock:SetScript("OnEnter", function()
        GameTooltip:SetOwner(rosterIlvlBlock, "ANCHOR_TOP")
        GameTooltip:AddLine("Roster Avg iLvL", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Average item level across your", 1,1,1)
        GameTooltip:AddLine("entire tracked roster.", 1,1,1)
        GameTooltip:Show()
    end)
    rosterIlvlBlock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Filters label ──────────────────────────────────────────
    local filtersLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filtersLbl:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 497, 152)
    filtersLbl:SetJustifyH("LEFT")
    filtersLbl:SetText("|cffC69B3AFilters:|r")

    -- ── Add Target button ──────────────────────────────────────
    local addBtn = CreateFrame("Button", "LichborneAddTargetBtn", f)
    addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 110)
    addBtn:SetSize(155, 28)
    addBtn:SetFrameLevel(fl + 12)
    addBtn:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    addBtn:SetBackdropColor(0.10*0.35, 0.40*0.35, 0.70*0.35, 1)
    addBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local addBtnLabel = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addBtnLabel:SetAllPoints(addBtn)
    addBtnLabel:SetJustifyH("CENTER"); addBtnLabel:SetJustifyV("MIDDLE")
    addBtnLabel:SetText("|cffd4af37+ Add Target|r")
    addBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local addStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addStatus:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 661, 152)  -- above output box, close to border
    addStatus:SetWidth(254)
    addStatus:SetJustifyH("LEFT")
    addStatus:SetText("")
    LichborneAddStatus = addStatus

    addBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(addBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("+ Add Target", 1, 1, 1)
        GameTooltip:AddLine("Adds target to tracker.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addBtn:SetScript("OnClick", function()
        if not UnitExists("target") or not UnitIsPlayer("target") then
            LichborneAddStatus:SetText("|cffff4444No player targeted.|r")
            return
        end

        local targetName = UnitName("target")
        local _, targetClass = UnitClass("target")
        local cls = targetClass and CLASS_TOKEN_MAP[targetClass]
        if not cls then
            LichborneAddStatus:SetText("|cffff4444Unknown class: "..(targetClass or "nil").."|r")
            return
        end

        EnsureClass(cls)
        local indices = GetAllClassRows(cls)
        for _, di in ipairs(indices) do
            local row = LichborneTrackerDB.rows[di]
            if row.name and row.name:lower() == targetName:lower() then
                local c = CLASS_COLORS[cls]
                local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
                LichborneAddStatus:SetText(hex..targetName.."|r already in tracker.")
                return
            end
        end

        local targetDi = nil
        for _, di in ipairs(indices) do
            local row = LichborneTrackerDB.rows[di]
            if not row.name or row.name == "" then
                targetDi = di
                break
            end
        end
        if not targetDi then
            table.insert(LichborneTrackerDB.rows, DefaultRow(cls))
            targetDi = #LichborneTrackerDB.rows
        end

        LichborneTrackerDB.rows[targetDi].name = targetName
        LichborneTrackerDB.rows[targetDi].level = UnitLevel("target")

        local c = CLASS_COLORS[cls]
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        LichborneAddStatus:SetText(hex..targetName.."|r added to Overview tab.")
        LichborneOutput("|cffC69B3ALichborne:|r Added "..hex..targetName.."|r ("..cls..")", 1, 0.85, 0)

        if overviewRowFrames and #overviewRowFrames > 0 then RefreshOverviewRows() end
    end)

    -- ── Add Group button ───────────────────────────────────────
    local SetScanActive, AddGroupMembers

    local addGroupBtn = CreateFrame("Button", "LichborneAddGroupBtn", f)
    addGroupBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 175, 110)
    addGroupBtn:SetSize(155, 28)
    addGroupBtn:SetFrameLevel(fl + 12)
    addGroupBtn:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    addGroupBtn:SetBackdropColor(0.10*0.35, 0.40*0.35, 0.70*0.35, 1)
    addGroupBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local addGroupLbl = addGroupBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addGroupLbl:SetAllPoints(addGroupBtn); addGroupLbl:SetJustifyH("CENTER"); addGroupLbl:SetJustifyV("MIDDLE")
    addGroupLbl:SetText("|cffd4af37+ Add Group|r")
    addGroupBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    addGroupBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(addGroupBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("+ Add Group", 1, 1, 1)
        GameTooltip:AddLine("Adds group to tracker.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    addGroupBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addGroupBtn:SetScript("OnClick", function()
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cffff4444Not in a group, or no other members found.|r")
            end
            return
        end
        SetScanActive(true)
        AddGroupMembers(function(added, skipped)
            SetScanActive(false)
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cff44ff44Added "..added.." new, skipped "..skipped.." duplicates.|r")
            end
            LichborneOutput("|cffC69B3ALichborne:|r Group scan complete. Added: "..added..", Skipped: "..skipped, 1, 0.85, 0)
        end)
    end)

    -- ── Shared helper: silently add all group members to tracker ──
    AddGroupMembers = function(onDone)
        local playerName = UnitName("player")
        local members = {}
        local _, selfClsKey = UnitClass("player")
        members[#members+1] = {name=playerName, clsKey=selfClsKey, level=UnitLevel("player")}
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local unit = "raid"..i
                if UnitExists(unit) and UnitName(unit) ~= playerName then
                    local name2 = UnitName(unit)
                    local _, clsKey = UnitClass(unit)
                    members[#members+1] = {name=name2, clsKey=clsKey, level=UnitLevel(unit)}
                end
            end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do
                local unit = "party"..i
                if UnitExists(unit) then
                    local name2 = UnitName(unit)
                    local _, clsKey = UnitClass(unit)
                    members[#members+1] = {name=name2, clsKey=clsKey, level=UnitLevel(unit)}
                end
            end
        end
        local toProcess = {}
        for _, m in ipairs(members) do
            local cls = m.clsKey and CLASS_TOKEN_MAP[m.clsKey]
            if cls then toProcess[#toProcess+1] = {name=m.name, cls=cls, level=m.level or 0} end
        end
        if #toProcess == 0 then
            if onDone then onDone(0, 0) end
            return
        end
        local addIdx, addWait, addedCount, skippedCount = 1, 0, 0, 0
        local agFrame = CreateFrame("Frame")
        activeInspectFrame = agFrame
        agFrame:SetScript("OnUpdate", function(_, elapsed)
            addWait = addWait + elapsed
            if addWait < 0.15 then return end
            addWait = 0
            if addIdx > #toProcess then
                agFrame:SetScript("OnUpdate", nil)
                if activeInspectFrame == agFrame then activeInspectFrame = nil end
                RefreshRows()
                if onDone then onDone(addedCount, skippedCount) end
                return
            end
            local m = toProcess[addIdx]; addIdx = addIdx + 1
            EnsureClass(m.cls)
            local indices = GetAllClassRows(m.cls)
            for _, di in ipairs(indices) do
                local row = LichborneTrackerDB.rows[di]
                if row.name and row.name:lower() == m.name:lower() then
                    skippedCount = skippedCount + 1; return
                end
            end
            local slot = nil
            for _, di in ipairs(indices) do
                local row = LichborneTrackerDB.rows[di]
                if not row.name or row.name == "" then slot = di; break end
            end
            if not slot then
                table.insert(LichborneTrackerDB.rows, DefaultRow(m.cls))
                slot = #LichborneTrackerDB.rows
            end
            LichborneTrackerDB.rows[slot].name = m.name
            LichborneTrackerDB.rows[slot].level = m.level or 0
            addedCount = addedCount + 1
        end)
    end

    -- ── Helper: make a tracker button ──────────────────────────
    local function MakeTrackerBtn(name, x, y, w, h, br, bg2, bb, label)
        local btn = CreateFrame("Button", name, f)
        btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
        btn:SetSize(w, h); btn:SetFrameLevel(fl+12)
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        btn:SetBackdropColor(br*0.35,bg2*0.35,bb*0.35,1); btn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local lbl=btn:CreateFontString(nil,"OVERLAY","GameFontNormal"); lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(label)
        return btn
    end

    -- ── Update Target GS (row y=78, left) ────────────────────
    local gsBtn = MakeTrackerBtn("LichborneUpdateGSBtn", 15, 76, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Target Gear|r")
    gsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(gsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("+ Add Target Gear",1,1,1)
        GameTooltip:AddLine("Adds target's gear.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    gsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gsBtn:SetScript("OnClick", function()
        if not UnitExists("target") or not UnitIsPlayer("target") then LichborneAddStatus:SetText("|cffff4444No player targeted.|r"); return end
        local targetName = UnitName("target")
        local _, targetClassGS = UnitClass("target")
        local clsGS = targetClassGS and CLASS_TOKEN_MAP[targetClassGS]
        -- Add to tracker if not already there
        local foundDi = nil
        for i, row in ipairs(LichborneTrackerDB.rows) do
            if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
        end
        if not foundDi then
            if not clsGS then LichborneAddStatus:SetText("|cffff4444Unknown class for "..targetName.."|r"); return end
            EnsureClass(clsGS)
            local idxs = GetAllClassRows(clsGS)
            for _, di in ipairs(idxs) do
                local row = LichborneTrackerDB.rows[di]
                if not row.name or row.name == "" then foundDi = di; break end
            end
            if not foundDi then
                table.insert(LichborneTrackerDB.rows, DefaultRow(clsGS))
                foundDi = #LichborneTrackerDB.rows
            end
            LichborneTrackerDB.rows[foundDi].name = targetName
            LichborneTrackerDB.rows[foundDi].level = UnitLevel("target")
            if overviewRowFrames and #overviewRowFrames > 0 then RefreshOverviewRows() end
            local cA = CLASS_COLORS[clsGS]; local hA = cA and string.format("|cff%02x%02x%02x",math.floor(cA.r*255),math.floor(cA.g*255),math.floor(cA.b*255)) or "|cffffffff"
            LichborneOutput("|cffC69B3ALichborne:|r Added "..hA..targetName.."|r to tracker.", 1, 0.85, 0)
        end
        local rowData = LichborneTrackerDB.rows[foundDi]
        local c = CLASS_COLORS[rowData.cls or ""]; local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        LichborneAddStatus:SetText("Updating Gear for "..hex..targetName.."|r...")
        LichborneOutput("|cffC69B3ALichborne:|r Updating Gear for "..hex..targetName.."|r...", 1, 0.85, 0)
        local gsDi = foundDi
        -- Lock all buttons (including Stop and invite) during single-target scan
        SetScanActive(true)
        local stopBtn = _G["LichborneStopInspectBtn"]
        if stopBtn then stopBtn:Disable(); stopBtn:SetAlpha(0.35) end
        -- Self-contained OnUpdate loop: owns the entire lock-to-unlock lifecycle
        local gsPhase = "delay"
        local gsElapsed = 0
        local GS_TIMEOUT = 15  -- hard safety timeout in seconds
        local gsTotalTime = 0
        local gsFrame = CreateFrame("Frame")
        gsFrame:SetScript("OnUpdate", function(_, delta)
            gsElapsed = gsElapsed + delta
            gsTotalTime = gsTotalTime + delta
            -- Hard timeout: always unlock no matter what
            if gsTotalTime >= GS_TIMEOUT then
                gsFrame:SetScript("OnUpdate", nil)
                LichborneInspectTarget = nil
                ClearInspectPlayer()
                SetScanActive(false)
                if stopBtn then stopBtn:Enable(); stopBtn:SetAlpha(1.0) end
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff4444GS scan timed out.|r") end
                LichborneOutput("|cffC69B3ALichborne:|r |cffff4444Target GS scan timed out.|r", 1, 0.85, 0)
                return
            end
            if gsPhase == "delay" then
                if gsElapsed < 0.5 then return end
                gsElapsed = 0
                LichborneInspectTarget = gsDi; LichborneInspectUnit = "target"
                DBG("InspectUnit(target) -> GS scan for |cffffff88"..((LichborneTrackerDB.rows[gsDi] and LichborneTrackerDB.rows[gsDi].name) or "?").."|r UnitExists=|cffffff88"..tostring(UnitExists("target")).."|r InRange=|cffffff88"..tostring(CheckInteractDistance("target",1)).."|r")
                InspectUnit("target"); LichborneInspectGUID = UnitGUID("target"); if not LichborneInspectGUID then DBG("|cffff4444[NIL]|r UnitGUID(target)=nil â€” GUID capture skipped") end; inspectWait = 0
                gsPhase = "wait"
            elseif gsPhase == "wait" then
                -- CalcGS sets LichborneInspectTarget = nil when done
                if LichborneInspectTarget == nil then
                    gsFrame:SetScript("OnUpdate", nil)
                    SetScanActive(false)
                    if stopBtn then stopBtn:Enable(); stopBtn:SetAlpha(1.0) end
                    return
                end
            end
        end)
    end)

    -- ── Update Target Spec (row y=78, right) ──────────────────
    local tsBtn = MakeTrackerBtn("LichborneUpdateTargetSpecBtn", 15, 42, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Target Spec|r")
    tsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(tsBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("+ Add Target Spec",1,1,1)
        GameTooltip:AddLine("Adds targets spec.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    tsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tsBtn:SetScript("OnClick", function()
        if not UnitExists("target") or not UnitIsPlayer("target") then LichborneAddStatus:SetText("|cffff4444No player targeted.|r"); return end
        local targetName = UnitName("target")
        local _, targetClassSP = UnitClass("target")
        local clsSP = targetClassSP and CLASS_TOKEN_MAP[targetClassSP]
        -- Add to tracker if not already there
        local foundDi = nil
        for i, row in ipairs(LichborneTrackerDB.rows) do
            if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
        end
        if not foundDi then
            if not clsSP then LichborneAddStatus:SetText("|cffff4444Unknown class for "..targetName.."|r"); return end
            EnsureClass(clsSP)
            local idxs = GetAllClassRows(clsSP)
            for _, di in ipairs(idxs) do
                local row = LichborneTrackerDB.rows[di]
                if not row.name or row.name == "" then foundDi = di; break end
            end
            if not foundDi then
                table.insert(LichborneTrackerDB.rows, DefaultRow(clsSP))
                foundDi = #LichborneTrackerDB.rows
            end
            LichborneTrackerDB.rows[foundDi].name = targetName
            LichborneTrackerDB.rows[foundDi].level = UnitLevel("target")
            if overviewRowFrames and #overviewRowFrames > 0 then RefreshOverviewRows() end
            local cA = CLASS_COLORS[clsSP]; local hA = cA and string.format("|cff%02x%02x%02x",math.floor(cA.r*255),math.floor(cA.g*255),math.floor(cA.b*255)) or "|cffffffff"
            LichborneOutput("|cffC69B3ALichborne:|r Added "..hA..targetName.."|r to tracker.", 1, 0.85, 0)
        end
        local rowData = LichborneTrackerDB.rows[foundDi]
        local c = CLASS_COLORS[rowData.cls or ""]; local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        LichborneAddStatus:SetText("Adding Specialization for "..hex..targetName.."|r...")
        LichborneOutput("|cffC69B3ALichborne:|r Adding Specialization for "..hex..targetName.."|r...", 1, 0.85, 0)
        local spDi = foundDi
        -- Lock all buttons (including Stop and invite) during single-target scan
        SetScanActive(true)
        local stopBtn = _G["LichborneStopInspectBtn"]
        if stopBtn then stopBtn:Disable(); stopBtn:SetAlpha(0.35) end
        -- Self-contained OnUpdate loop: owns the entire lock-to-unlock lifecycle
        local spPhase = "delay"
        local spElapsed = 0
        local SP_TIMEOUT = 15  -- hard safety timeout in seconds
        local spTotalTime = 0
        local spFrame = CreateFrame("Frame")
        spFrame:SetScript("OnUpdate", function(_, delta)
            spElapsed = spElapsed + delta
            spTotalTime = spTotalTime + delta
            -- Hard timeout: always unlock no matter what
            if spTotalTime >= SP_TIMEOUT then
                spFrame:SetScript("OnUpdate", nil)
                LichborneSpecTarget = nil
                ClearInspectPlayer()
                SetScanActive(false)
                if stopBtn then stopBtn:Enable(); stopBtn:SetAlpha(1.0) end
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff4444Specialization scan timed out.|r") end
                LichborneOutput("|cffC69B3ALichborne:|r |cffff4444Target Specialization scan timed out.|r", 1, 0.85, 0)
                return
            end
            if spPhase == "delay" then
                if spElapsed < 0.5 then return end
                spElapsed = 0
                LichborneSpecTarget = spDi; LichborneInspectUnit = "target"
                LichborneTrackerDB.rows[spDi].spec = ""
                DBG("InspectUnit(target) -> Spec scan for |cffffff88"..((LichborneTrackerDB.rows[spDi] and LichborneTrackerDB.rows[spDi].name) or "?").."|r UnitExists=|cffffff88"..tostring(UnitExists("target")).."|r InRange=|cffffff88"..tostring(CheckInteractDistance("target",1)).."|r")
                InspectUnit("target"); LichborneSpecGUID = UnitGUID("target"); if not LichborneSpecGUID then DBG("|cffff4444[NIL]|r UnitGUID(target)=nil â€” GUID capture skipped") end; specWait = 0
                spPhase = "wait"
            elseif spPhase == "wait" then
                -- CalcSpec sets LichborneSpecTarget = nil when done
                if LichborneSpecTarget == nil then
                    spFrame:SetScript("OnUpdate", nil)
                    SetScanActive(false)
                    if stopBtn then stopBtn:Enable(); stopBtn:SetAlpha(1.0) end
                    return
                end
            end
        end)
    end)

    -- ── Update Group GS (row y=44, left) ──────────────────────
    local activeInspectFrame = nil  -- shared by GS and Spec scans; Stop button kills it

    -- Disable/enable all buttons except Stop during a scan
    SetScanActive = function(active)
        SetButtonsLocked(active)
        -- Also lock invite buttons and stop overlay during scans
        local inviteRaid = _G["LichborneInviteRaidBtn"]
        if inviteRaid then
            if active then inviteRaid:Disable(); inviteRaid:SetAlpha(0.35)
            else inviteRaid:Enable(); inviteRaid:SetAlpha(1.0) end
        end
        local inviteGroup = _G["LichborneInviteGroupBtn"]
        if inviteGroup then
            if active then inviteGroup:Disable(); inviteGroup:SetAlpha(0.35)
            else inviteGroup:Enable(); inviteGroup:SetAlpha(1.0) end
        end
        local stopInv = _G["LichborneStopInviteBtn"]
        if stopInv then
            if active then stopInv:Disable(); stopInv:SetAlpha(0.35)
            else stopInv:Enable(); stopInv:SetAlpha(1.0) end
        end
    end
    local uggsBtn = MakeTrackerBtn("LichborneUpdateGroupGSBtn", 175, 76, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Group Gear|r")
    uggsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(uggsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("+ Add Group Gear",1,1,1)
        GameTooltip:AddLine("Adds members gear.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    uggsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uggsBtn:SetScript("OnClick", function()
        local playerName = UnitName("player")
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            LichborneAddStatus:SetText("|cffff4444Not in a group.|r"); return
        end
        SetScanActive(true)
        LichborneGroupScanActive = true
        LichborneAddStatus:SetText("Adding group members first...")
        AddGroupMembers(function(added, skipped)
            -- Now build unit list and run GS scan
            if not LichborneGroupScanActive then SetScanActive(false); return end
            local units = {}
            units[#units+1] = "player"
            if GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do local unit="raid"..i; if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit)~=playerName then units[#units+1]=unit end end
            elseif GetNumPartyMembers() > 0 then
                for i = 1, GetNumPartyMembers() do local unit="party"..i; if UnitExists(unit) then units[#units+1]=unit end end
            end
            if #units == 0 then SetScanActive(false); LichborneAddStatus:SetText("|cffff4444No group members found.|r"); return end
            local totalTime = math.ceil(#units*2.5)
            LichborneAddStatus:SetText("|cffff9900Added "..added.." new. Inspecting "..#units.." players (~"..totalTime.."s)...|r")
            LichborneOutput("|cffC69B3ALichborne:|r Group synced (+"..added..").\nStarting GS scan for "..#units.." players.", 1, 0.85, 0)
            local scanGsStartTime = GetTime()  -- DBG: group scan timing
            local idx,elapsed,inspecting = 1,0,false
            local gFrame = CreateFrame("Frame")
            activeInspectFrame = gFrame
            gFrame:SetScript("OnUpdate", function(_, delta)
                elapsed = elapsed + delta
                if inspecting then
                    if LichborneInspectTarget ~= nil and elapsed < 25 then return end
                    if LichborneInspectTarget ~= nil then
                        DBG("|cffff9900GS 25s cap|r — forcing advance to next player")
                    else
                        DBG("|cff44ff44GS wait done|r — CalcGS signaled complete; advancing")
                    end
                    inspecting=false; elapsed=0
                end
                if idx > #units then
                    gFrame:SetScript("OnUpdate",nil)
                    LichborneGroupScanActive = false
                    SetScanActive(false)
                    LichborneAddStatus:SetText("|cff44ff44Group GS update complete!|r")
                    LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44Group GS update complete.|r", 1, 0.85, 0)
                    DBG("|cff44ff44Group GS scan done|r - "..#units.." units, elapsed |cffffff88"..string.format("%.1f", GetTime()-scanGsStartTime).."s|r")
                    RefreshRows(); return
                end
                local unit = units[idx]; if not UnitExists(unit) then idx=idx+1; return end
                local targetName = UnitName(unit)
                if not targetName then DBG("|cffff4444[NIL]|r UnitName("..unit..") returned nil - skipping"); idx=idx+1; return end
                local foundDi = nil
                for i, row in ipairs(LichborneTrackerDB.rows) do if row.name and row.name:lower()==targetName:lower() then foundDi=i; break end end
                if not foundDi then LichborneOutput("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)",1,0.6,0.3); idx=idx+1; return end
                LichborneAddStatus:SetText("Updating Gear for |cffffff88"..tostring(targetName).."|r... ("..(idx).."/"..#units..")")
                LichborneInspectTarget = foundDi; LichborneInspectUnit = unit
                DBG("InspectUnit("..unit..") -> group GS for |cffffff88"..tostring(targetName).."|r ("..idx.."/"..#units..") UnitExists=|cffffff88"..tostring(UnitExists(unit)).."|r InRange=|cffffff88"..tostring(CheckInteractDistance(unit,1)).."|r")
                InspectUnit(unit); LichborneInspectGUID = UnitGUID(unit); if not LichborneInspectGUID then DBG("|cffff4444[NIL]|r UnitGUID("..unit..")=nil â€” GUID capture skipped") end; inspectWait=0; idx=idx+1; inspecting=true; elapsed=0
            end)
        end)
    end)

    -- ── Update Group Spec (row y=44, right) ───────────────────
    local ugsBtn = MakeTrackerBtn("LichborneUpdateGroupSpecBtn", 175, 42, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Group Spec|r")
    ugsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(ugsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("+ Add Group Spec",1,1,1)
        GameTooltip:AddLine("Adds members spec.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    ugsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ugsBtn:SetScript("OnClick", function()
        local playerName = UnitName("player")
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            LichborneAddStatus:SetText("|cffff4444Not in a group.|r"); return
        end
        SetScanActive(true)
        LichborneGroupScanActive = true
        LichborneAddStatus:SetText("Adding group members first...")
        AddGroupMembers(function(added, skipped)
            -- Now build unit list and run Spec scan
            if not LichborneGroupScanActive then SetScanActive(false); return end
            local units = {}
            units[#units+1] = "player"
            if GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do local unit="raid"..i; if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit)~=playerName then units[#units+1]=unit end end
            elseif GetNumPartyMembers() > 0 then
                for i = 1, GetNumPartyMembers() do local unit="party"..i; if UnitExists(unit) then units[#units+1]=unit end end
            end
            if #units == 0 then SetScanActive(false); LichborneAddStatus:SetText("|cffff4444No group members found.|r"); return end
            local totalTime = math.ceil(#units*3)
            LichborneAddStatus:SetText("|cffff9900Added "..added.." new. Reading Specialization for "..#units.." players (~"..totalTime.."s)...|r")
            LichborneOutput("|cffC69B3ALichborne:|r Group synced (+"..added..").\nStarting Specialization scan for "..#units.." players.", 1, 0.85, 0)
            local scanSpecStartTime = GetTime()  -- DBG: group scan timing
            local idx,elapsed,inspecting = 1,0,false
            local sFrame = CreateFrame("Frame")
            activeInspectFrame = sFrame
            sFrame:SetScript("OnUpdate", function(_, delta)
                elapsed = elapsed + delta
                if inspecting then
                    if LichborneSpecTarget ~= nil and elapsed < 25 then return end
                    if LichborneSpecTarget ~= nil then
                        DBG("|cffff9900Spec 25s cap|r — forcing advance to next player")
                    else
                        DBG("|cff44ff44Spec wait done|r — CalcSpec signaled complete; advancing")
                    end
                    inspecting=false; elapsed=0
                end
                if idx > #units then
                    sFrame:SetScript("OnUpdate",nil)
                    LichborneGroupScanActive = false
                    SetScanActive(false)
                    LichborneAddStatus:SetText("|cff44ff44Group Specialization update complete!|r")
                    LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44Group Specialization update complete.|r", 1, 0.85, 0)
                    DBG("|cff44ff44Group Spec scan done|r - "..#units.." units, elapsed |cffffff88"..string.format("%.1f", GetTime()-scanSpecStartTime).."s|r")
                    RefreshRows(); if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end; return
                end
                local unit = units[idx]; if not UnitExists(unit) then idx=idx+1; return end
                local targetName = UnitName(unit)
                if not targetName then DBG("|cffff4444[NIL]|r UnitName("..unit..") returned nil - skipping"); idx=idx+1; return end
                local foundDi = nil
                for i, row in ipairs(LichborneTrackerDB.rows) do if row.name and row.name:lower()==targetName:lower() then foundDi=i; break end end
                if not foundDi then LichborneOutput("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)",1,0.6,0.3); idx=idx+1; return end
                LichborneAddStatus:SetText("Reading Specialization |cffffff88"..tostring(targetName).."|r... ("..(idx).."/"..#units..")")
                LichborneSpecTarget = foundDi; LichborneInspectUnit = unit
                if LichborneTrackerDB.rows[foundDi] then LichborneTrackerDB.rows[foundDi].spec="" end
                DBG("InspectUnit("..unit..") -> group Spec for |cffffff88"..tostring(targetName).."|r ("..idx.."/"..#units..") UnitExists=|cffffff88"..tostring(UnitExists(unit)).."|r InRange=|cffffff88"..tostring(CheckInteractDistance(unit,1)).."|r")
                InspectUnit(unit); LichborneSpecGUID = UnitGUID(unit); if not LichborneSpecGUID then DBG("|cffff4444[NIL]|r UnitGUID("..unit..")=nil â€” GUID capture skipped") end; specWait=0; idx=idx+1; inspecting=true; elapsed=0
            end)
        end)
    end)

    -- ── Stop Inspect button (below Get Group Spec) ────────────
    local stopInspectBtn = MakeTrackerBtn("LichborneStopInspectBtn", 15, 8, 155, 28, 0.90, 0.20, 0.20, "|cffd4af37Stop Scan|r")
    stopInspectBtn:SetBackdropColor(0.90*0.30, 0.20*0.30, 0.20*0.30, 1)
    stopInspectBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(stopInspectBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Stop Scan", 1, 1, 1)
        GameTooltip:AddLine("Cancels the running Gear or Spec scan.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    stopInspectBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stopInspectBtn:SetScript("OnClick", function()
        if activeInspectFrame then
            activeInspectFrame:SetScript("OnUpdate", nil)
            activeInspectFrame = nil
        end
        LichborneInspectTarget = nil
        LichborneSpecTarget = nil
        LichborneGroupScanActive = false
        SetScanActive(false)
        LichborneAddStatus:SetText("|cffff4444Scan stopped.|r")
        LichborneOutput("|cffC69B3ALichborne:|r |cffff4444Scan stopped.|r", 1, 0.85, 0)
    end)

    -- Row y=10: Add Target / Add Group (existing buttons stay here)
    -- Avg GS bar (repurposed from Count bar)
    local clsFrame = CreateFrame("Frame", "LichborneClassBar", f)
    LichborneCountBar = clsFrame
    clsFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -556)
    clsFrame:SetSize(1086, 24)
    clsFrame:SetFrameLevel(fl + 10)
    local clsbg = clsFrame:CreateTexture(nil, "BACKGROUND")
    clsbg:SetAllPoints(clsFrame); clsbg:SetTexture(0.05, 0.07, 0.13, 1)
    local clsTitle = clsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clsTitle:SetPoint("LEFT", clsFrame, "LEFT", 4, 0)
    clsTitle:SetText("|cffC69B3AAvg GS:|r"); clsTitle:SetWidth(52)
    LichborneCountLabels = {}
    local cRosterBlockW = 130
    local cswTotalW = 1086 - 56 - 4 - cRosterBlockW
    local cswW = cswTotalW / 10
    local cswIdx = 0
    for i, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" or cls == "Overview" then break end
        cswIdx = cswIdx + 1
        local c = CLASS_COLORS[cls]
        local csw = CreateFrame("Button", "LichborneClassSwatch"..cswIdx, clsFrame)
        csw:SetSize(cswW - 2, 20)
        csw:SetPoint("LEFT", clsFrame, "LEFT", 56 + (cswIdx-1)*cswW, 0)
        csw:SetFrameLevel(clsFrame:GetFrameLevel() + 1)
        local cswbg = csw:CreateTexture(nil, "BACKGROUND")
        cswbg:SetAllPoints(csw); cswbg:SetTexture(0.08, 0.10, 0.18, 1); csw.bg = cswbg
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local lbl = csw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(csw); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(hex..(TAB_LABELS[cls])..": |cff555555--|r"); csw.lbl = lbl; csw.cls = cls
        LichborneCountLabels[cls] = lbl
        csw:EnableMouse(true)
        csw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(csw, "ANCHOR_TOP")
            local gs = GetClassAvgGS(cls)
            GameTooltip:AddLine(TAB_LABELS[cls], c.r, c.g, c.b)
            GameTooltip:AddLine("Average gear score of all tracked "..TAB_LABELS[cls].."s.", 1,1,1)
            if gs > 0 then
                GameTooltip:AddLine("Current: |cffd4af37"..gs.."|r", 1,1,1)
            else
                GameTooltip:AddLine("No gear data yet.", 0.6,0.6,0.6)
            end
            GameTooltip:AddLine("Click to switch to this tab.", 0.5,0.5,0.5)
            GameTooltip:Show()
        end)
        csw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        csw:SetScript("OnClick", function()
            activeTab = cls
            UpdateTabs()
            RefreshRows()
        end)
    end

    -- Roster GS block — right-anchored, gold border, fills remaining space
    local rosterGsBlock = CreateFrame("Frame", "LichborneRosterGsBlock", clsFrame)
    rosterGsBlock:SetPoint("RIGHT", clsFrame, "RIGHT", 0, 0)
    rosterGsBlock:SetSize(cRosterBlockW, 24)
    rosterGsBlock:SetFrameLevel(clsFrame:GetFrameLevel() + 1)
    rosterGsBlock:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    rosterGsBlock:SetBackdropColor(0.05, 0.07, 0.13, 1)
    rosterGsBlock:SetBackdropBorderColor(0.78, 0.61, 0.23, 1.0)
    local rosterGsLbl = rosterGsBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rosterGsLbl:SetAllPoints(rosterGsBlock)
    rosterGsLbl:SetJustifyH("CENTER"); rosterGsLbl:SetJustifyV("MIDDLE")
    rosterGsLbl:SetText("|cffC69B3ARoster GS:|r |cff555555--|r")
    LichborneRosterGsLabel = rosterGsLbl
    rosterGsBlock:EnableMouse(true)
    rosterGsBlock:SetScript("OnEnter", function()
        GameTooltip:SetOwner(rosterGsBlock, "ANCHOR_TOP")
        GameTooltip:AddLine("Roster Avg GS", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Average gear score across your", 1,1,1)
        GameTooltip:AddLine("entire tracked roster.", 1,1,1)
        GameTooltip:Show()
    end)
    rosterGsBlock:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Build raid frame
    BuildRaidFrame(f, fl)
    BuildOverviewFrame(f, fl)


    -- ── Playerbot section ─────────────────────────────────────
    -- Border frame styled like the title bar
    -- ── Bot buttons (left column, no border) ─────────────────
    local function MakeSimpleBtn(name, label, r, g, b, x, y, w, tooltip)
        local btn = CreateFrame("Button", name, f)
        btn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
        btn:SetSize(w or 185, 28)
        btn:SetFrameLevel(fl + 12)
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        btn:SetBackdropColor(r*0.3, g*0.3, b*0.3, 1)
        btn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetAllPoints(btn); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(label)
        if tooltip then
            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(btn, "ANCHOR_TOP")
                for _, line in ipairs(tooltip) do
                    GameTooltip:AddLine(line[1], line[2] or 1, line[3] or 1, line[4] or 1)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return btn
    end

    local maintBtn = MakeSimpleBtn("LichborneMaintBtn", "|cffd4af37+ Full Group Scan|r",
        0.2, 0.5, 0.9, 175, 8,
        155, {
            {"Full Group Scan",1,1,1},
            {"Long scan is used for first time setup",0.8,0.8,0.8},
            {"or reconfiguration of raid. Performs",0.8,0.8,0.8},
            {"gear and spec scan. Allow 6s per",0.8,0.8,0.8},
            {"character.",0.8,0.8,0.8},
        })
    maintBtn:SetScript("OnClick", function()
        local playerName = UnitName("player")
        if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
            LichborneAddStatus:SetText("|cffff4444Not in a group.|r"); return
        end
        SetScanActive(true)
        LichborneGroupScanActive = true
        LichborneAddStatus:SetText("Adding group members...")
        AddGroupMembers(function(added, skipped)
            -- Abort if Stop Scan was pressed during the add phase
            if not LichborneGroupScanActive then return end
            -- Build shared unit list used by both GS and Spec phases
            local units = {}
            units[#units+1] = "player"
            if GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do
                    local unit = "raid"..i
                    if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) ~= playerName then
                        units[#units+1] = unit
                    end
                end
            elseif GetNumPartyMembers() > 0 then
                for i = 1, GetNumPartyMembers() do
                    local unit = "party"..i
                    if UnitExists(unit) then units[#units+1] = unit end
                end
            end
            if #units == 0 then
                SetScanActive(false)
                LichborneAddStatus:SetText("|cffff4444No group members found.|r")
                return
            end
            -- ── Phase 2: GS scan ──────────────────────────────────────────
            local totalTime = math.ceil(#units * 6)
            LichborneAddStatus:SetText("|cffff9900Added "..added.." new. Full scan: "..#units.." players (~"..totalTime.."s)...|r")
            LichborneOutput("|cffC69B3ALichborne:|r Full Group Scan started (+"..added..").\nGS phase: "..#units.." players.", 1, 0.85, 0)
            local scanStartTime = GetTime()
            local idx, elapsed, inspecting = 1, 0, false
            local gFrame = CreateFrame("Frame")
            activeInspectFrame = gFrame
            gFrame:SetScript("OnUpdate", function(_, delta)
                elapsed = elapsed + delta
                if inspecting then
                    if LichborneInspectTarget ~= nil and elapsed < 25 then return end
                    if LichborneInspectTarget ~= nil then
                        DBG("|cffff9900FullScan GS 25s cap|r — forcing advance to next player")
                    else
                        DBG("|cff44ff44FullScan GS wait done|r — advancing")
                    end
                    inspecting = false; elapsed = 0
                end
                if idx > #units then
                    gFrame:SetScript("OnUpdate", nil)
                    DBG("|cff44ff44FullScan GS phase done|r — elapsed |cffffff88"..string.format("%.1f", GetTime()-scanStartTime).."s|r")
                    -- ── Phase 3: Spec scan ────────────────────────────────
                    LichborneAddStatus:SetText("|cffff9900GS done. Starting Specialization scan ("..#units.." players)...|r")
                    LichborneOutput("|cffC69B3ALichborne:|r GS phase complete. Starting Specialization phase.", 1, 0.85, 0)
                    local sIdx, sElapsed, sInspecting = 1, 0, false
                    local sFrame = CreateFrame("Frame")
                    activeInspectFrame = sFrame
                    sFrame:SetScript("OnUpdate", function(_, sdelta)
                        sElapsed = sElapsed + sdelta
                        if sInspecting then
                            if LichborneSpecTarget ~= nil and sElapsed < 25 then return end
                            if LichborneSpecTarget ~= nil then
                                DBG("|cffff9900FullScan Spec 25s cap|r — forcing advance")
                            else
                                DBG("|cff44ff44FullScan Spec wait done|r — advancing")
                            end
                            sInspecting = false; sElapsed = 0
                        end
                        if sIdx > #units then
                            sFrame:SetScript("OnUpdate", nil)
                            LichborneGroupScanActive = false
                            SetScanActive(false)
                            LichborneAddStatus:SetText("|cff44ff44Full Group Scan complete!|r")
                            LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44Full Group Scan complete.|r", 1, 0.85, 0)
                            DBG("|cff44ff44FullScan complete|r — total elapsed |cffffff88"..string.format("%.1f", GetTime()-scanStartTime).."s|r")
                            RefreshRows(); if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
                            return
                        end
                        local unit = units[sIdx]; if not UnitExists(unit) then sIdx = sIdx + 1; return end
                        local targetName = UnitName(unit)
                        if not targetName then DBG("|cffff4444[NIL]|r UnitName("..unit..") nil - skipping"); sIdx = sIdx + 1; return end
                        local foundDi = nil
                        for i, row in ipairs(LichborneTrackerDB.rows) do
                            if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
                        end
                        if not foundDi then
                            LichborneOutput("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)", 1, 0.6, 0.3)
                            sIdx = sIdx + 1; return
                        end
                        LichborneAddStatus:SetText("Specialization scan |cffffff88"..tostring(targetName).."|r... ("..sIdx.."/"..#units..")")
                        LichborneSpecTarget = foundDi; LichborneInspectUnit = unit
                        if LichborneTrackerDB.rows[foundDi] then LichborneTrackerDB.rows[foundDi].spec = "" end
                        DBG("InspectUnit("..unit..") -> FullScan Spec for |cffffff88"..tostring(targetName).."|r ("..sIdx.."/"..#units..")")
                        InspectUnit(unit); LichborneSpecGUID = UnitGUID(unit); if not LichborneSpecGUID then DBG("|cffff4444[NIL]|r UnitGUID("..unit..")=nil — GUID capture skipped") end; specWait = 0; sIdx = sIdx + 1; sInspecting = true; sElapsed = 0
                    end)
                    return
                end
                local unit = units[idx]; if not UnitExists(unit) then idx = idx + 1; return end
                local targetName = UnitName(unit)
                if not targetName then DBG("|cffff4444[NIL]|r UnitName("..unit..") nil - skipping"); idx = idx + 1; return end
                local foundDi = nil
                for i, row in ipairs(LichborneTrackerDB.rows) do
                    if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
                end
                if not foundDi then
                    LichborneOutput("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)", 1, 0.6, 0.3)
                    idx = idx + 1; return
                end
                LichborneAddStatus:SetText("Updating Gear for |cffffff88"..tostring(targetName).."|r... ("..idx.."/"..#units..")")
                LichborneInspectTarget = foundDi; LichborneInspectUnit = unit
                DBG("InspectUnit("..unit..") -> FullScan GS for |cffffff88"..tostring(targetName).."|r ("..idx.."/"..#units..")")
                InspectUnit(unit); LichborneInspectGUID = UnitGUID(unit); if not LichborneInspectGUID then DBG("|cffff4444[NIL]|r UnitGUID("..unit..")=nil — GUID capture skipped") end; inspectWait = 0; idx = idx + 1; inspecting = true; elapsed = 0
            end)
        end)
    end)

    local loginBtn = MakeSimpleBtn("LichborneLoginBtn", "|cffd4af37Log in All Bots|r",
        0.1, 0.6, 0.2, 335, 76,
        155, {{"Log in All Bots",1,1,1},{".playerbots bot add *",0.8,0.8,0.8}})
    loginBtn:SetScript("OnClick", function() SendChatMessage(".playerbots bot add *", "PARTY") end)

    local logoutBtn = MakeSimpleBtn("LichborneLogoutBtn", "|cffd4af37Log Out All Bots|r",
        0.90, 0.20, 0.20, 335, 42,
        155, {{"Log Out All Bots",1,1,1},{".playerbots bot remove *",0.8,0.8,0.8}})
    logoutBtn:SetScript("OnClick", function() SendChatMessage(".playerbots bot remove *", "PARTY") end)

    -- ── Remove Orphaned Bots button ────────────────────────────
    -- Sends .playerbots bot remove <name> for every character in the Overview tab roster
    -- Used when bots are still logged in but player has left the group
    local orphanedBotsBtn = CreateFrame("Button", "LichborneOrphanedBotsBtn", f)
    orphanedBotsBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 335, 110)
    orphanedBotsBtn:SetSize(155, 28)
    orphanedBotsBtn:SetFrameLevel(fl + 12)
    orphanedBotsBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    orphanedBotsBtn:SetBackdropColor(0.90*0.30, 0.20*0.30, 0.20*0.30, 1)
    orphanedBotsBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    orphanedBotsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local orphanedBotsLbl = orphanedBotsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    orphanedBotsLbl:SetAllPoints(orphanedBotsBtn); orphanedBotsLbl:SetJustifyH("CENTER"); orphanedBotsLbl:SetJustifyV("MIDDLE")
    orphanedBotsLbl:SetText("|cffd4af37Clean Up Bots|r")
    orphanedBotsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(orphanedBotsBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Clean Up Bots", 1, 1, 1)
        GameTooltip:AddLine("Logs out all bots in your Overview tab", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("that are not currently in your", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("group or raid.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    orphanedBotsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    orphanedBotsBtn:SetScript("OnClick", function()
        -- Get current group/raid members
        local groupMembers = {}
        local playerName = UnitName("player")
        if playerName then groupMembers[playerName:lower()] = true end
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local unit = "raid"..i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    if name then groupMembers[name:lower()] = true end
                end
            end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do
                local unit = "party"..i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    if name then groupMembers[name:lower()] = true end
                end
            end
        end
        -- Collect names from Overview tab that are NOT in the current group
        local botNames = {}
        local seen = {}
        if LichborneTrackerDB.allGroups then
            for _, g in ipairs({"A","B","C"}) do
                local grp = LichborneTrackerDB.allGroups[g]
                if grp then
                    for i = 1, 60 do
                        local r = grp[i]
                        if r and r.name and r.name ~= "" and not seen[r.name:lower()] then
                            seen[r.name:lower()] = true
                            if not groupMembers[r.name:lower()] then
                                botNames[#botNames+1] = r.name
                            end
                        end
                    end
                end
            end
        end
        if #botNames == 0 then
            LichborneOutput("|cffC69B3ALichborne:|r No orphaned bots found.", 1, 0.5, 0.5)
            if LichborneAddStatus then LichborneAddStatus:SetText("|cffff4444No orphaned bots found.|r") end
            return
        end
        LichborneOutput("|cffC69B3ALichborne:|r Logging out "..#botNames.." orphaned bots...", 1, 0.85, 0)
        if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Logging out "..#botNames.." orphaned bots...") end
        SetScanActive(true)
        local stopBtn = _G["LichborneStopInspectBtn"]
        if stopBtn then stopBtn:Disable(); stopBtn:SetAlpha(0.35) end
        local orphanIdx = 1
        local orphanWait = 0
        local orphanFrame = CreateFrame("Frame")
        orphanFrame:SetScript("OnUpdate", function(_, elapsed)
            orphanWait = orphanWait + elapsed
            if orphanWait < 0.2 then return end
            orphanWait = 0
            if orphanIdx > #botNames then
                orphanFrame:SetScript("OnUpdate", nil)
                SetScanActive(false)
                local stopBtn2 = _G["LichborneStopInspectBtn"]
                if stopBtn2 then stopBtn2:Enable(); stopBtn2:SetAlpha(1.0) end
                LichborneOutput("|cffC69B3ALichborne:|r |cff44ff44All "..#botNames.." orphaned bots logged out.|r", 1, 0.85, 0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44Orphaned bots logged out ("..#botNames..").|r") end
                return
            end
            local bname = botNames[orphanIdx]
            SendChatMessage(".playerbots bot remove "..bname, "SAY")
            orphanIdx = orphanIdx + 1
        end)
    end)
    local disbandBtn = CreateFrame("Button", "LichborneDisbandBtn", f)
    disbandBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 335, 8)
    disbandBtn:SetSize(155, 28)
    disbandBtn:SetFrameLevel(fl + 12)
    disbandBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    disbandBtn:SetBackdropColor(0.90*0.30, 0.20*0.30, 0.20*0.30, 1)
    disbandBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    disbandBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local disbandLbl = disbandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disbandLbl:SetAllPoints(disbandBtn); disbandLbl:SetJustifyH("CENTER"); disbandLbl:SetJustifyV("MIDDLE")
    disbandLbl:SetText("|cffd4af37Disband Group|r")
    disbandBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(disbandBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Disband Group", 1, 1, 1)
        GameTooltip:AddLine("Removes all bots and leaves the group.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    disbandBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Confirmation dialog
    local disbConfirm = CreateFrame("Frame", nil, UIParent)
    disbConfirm:SetSize(260, 80)
    disbConfirm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    disbConfirm:SetFrameStrata("FULLSCREEN_DIALOG")
    disbConfirm:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
    disbConfirm:SetBackdropColor(0.04, 0.06, 0.13, 0.98)
    disbConfirm:SetBackdropBorderColor(0.90, 0.20, 0.20, 1)
    disbConfirm:Hide()

    local disbText = disbConfirm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disbText:SetPoint("TOP", disbConfirm, "TOP", 0, -12)
    disbText:SetText("|cffd4af37Disband Group?|r")
    local disbSub = disbConfirm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    disbSub:SetPoint("TOP", disbText, "BOTTOM", 0, -4)
    disbSub:SetText("|cffaaaaaaRemoves all bots and leaves the group.|r")

    local disbYes = CreateFrame("Button", nil, disbConfirm)
    disbYes:SetSize(100, 22); disbYes:SetPoint("BOTTOMLEFT", disbConfirm, "BOTTOMLEFT", 12, 10)
    disbYes:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    disbYes:SetBackdropColor(0.32, 0.07, 0.07, 1); disbYes:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    disbYes:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local disbYesLbl = disbYes:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disbYesLbl:SetAllPoints(disbYes); disbYesLbl:SetJustifyH("CENTER")
    disbYesLbl:SetText("|cffd4af37Yes, Disband|r")

    local disbNo = CreateFrame("Button", nil, disbConfirm)
    disbNo:SetSize(100, 22); disbNo:SetPoint("BOTTOMRIGHT", disbConfirm, "BOTTOMRIGHT", -12, 10)
    disbNo:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    disbNo:SetBackdropColor(0.08, 0.10, 0.18, 1); disbNo:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    disbNo:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local disbNoLbl = disbNo:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disbNoLbl:SetAllPoints(disbNo); disbNoLbl:SetJustifyH("CENTER")
    disbNoLbl:SetText("|cffd4af37Cancel|r")

    disbNo:SetScript("OnClick", function() disbConfirm:Hide() end)

    disbYes:SetScript("OnClick", function()
        disbConfirm:Hide()
        SetButtonsLocked(true)
        -- Also lock Stop and Invite Raid/Group during disband
        local function lockExtra(locked)
            for _, n in ipairs({"LichborneStopInspectBtn","LichborneInviteRaidBtn","LichborneInviteGroupBtn","LichborneStopInviteBtn"}) do
                local b = _G[n]
                if b then
                    if locked then b:Disable(); b:SetAlpha(0.35)
                    else b:Enable(); b:SetAlpha(1.0) end
                end
            end
        end
        lockExtra(true)
        LichborneOutput("|cffC69B3ALichborne:|r |cffd4af37Disbanding group...|r", 1, 0.85, 0)
        SendChatMessage(".playerbots bot remove *", "SAY")
        local waited = 0
        local disbFrame = CreateFrame("Frame")
        disbFrame:SetScript("OnUpdate", function(_, elapsed)
            waited = waited + elapsed
            if waited < 1.0 then return end
            LeaveParty()
            SetButtonsLocked(false)
            lockExtra(false)
            LichborneOutput("|cffC69B3ALichborne:|r |cffd4af37Group disbanded.|r", 1, 0.85, 0)
            disbFrame:SetScript("OnUpdate", nil)
        end)
    end)

    disbandBtn:SetScript("OnClick", function()
        disbConfirm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        disbConfirm:Show()
    end)

    -- ── Scrollable Output Box ────────────────────────────────────
    local outputBox = CreateFrame("Frame", "LichborneOutputBox", f)
    outputBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 655, 8)
    outputBox:SetSize(260, 130)
    outputBox:SetFrameLevel(fl + 20)
    outputBox:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    outputBox:SetBackdropColor(0.04, 0.06, 0.14, 1.0)
    outputBox:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    outputBox:EnableMouse(true)
    outputBox:SetScript("OnEnter", function()
        GameTooltip:SetOwner(outputBox, "ANCHOR_TOP")
        GameTooltip:AddLine("Output Log", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Scroll up/down with the mouse wheel.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    outputBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local outputTitle = outputBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    outputTitle:SetPoint("TOPLEFT", outputBox, "TOPLEFT", 6, -4)
    outputTitle:SetText("|cffC69B3AOutput|r")

    -- Debug toggle button
    local dbgBtn = CreateFrame("Button", "LichborneDbgBtn", outputBox)
    dbgBtn:SetPoint("TOPRIGHT", outputBox, "TOPRIGHT", -4, -3)
    dbgBtn:SetSize(34, 13)
    dbgBtn:SetFrameLevel(outputBox:GetFrameLevel() + 2)
    dbgBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    dbgBtn:SetBackdropColor(0.10, 0.10, 0.10, 1)
    dbgBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    dbgBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local dbgLbl = dbgBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dbgLbl:SetAllPoints(dbgBtn); dbgLbl:SetJustifyH("CENTER"); dbgLbl:SetJustifyV("MIDDLE")
    dbgLbl:SetText("|cff888888DBG|r")
    dbgBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(dbgBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Debug Mode", 0.78, 0.61, 0.23)
        if LichborneDebugMode then
            GameTooltip:AddLine("Currently: |cff44ff44ON|r", 1, 1, 1)
        else
            GameTooltip:AddLine("Currently: |cffff4444OFF|r", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    dbgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dbgBtn:SetScript("OnClick", function()
        LichborneDebugMode = not LichborneDebugMode
        if LichborneDebugMode then
            dbgLbl:SetText("|cff44ff44DBG|r")
            dbgBtn:SetBackdropColor(0.05, 0.20, 0.05, 1)
            dbgBtn:SetBackdropBorderColor(0.3, 0.9, 0.3, 0.9)
            LichborneOutput("|cff44ff44[DBG] Debug mode ON — inspect logging active.|r")
        else
            dbgLbl:SetText("|cff888888DBG|r")
            dbgBtn:SetBackdropColor(0.10, 0.10, 0.10, 1)
            dbgBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
            LichborneOutput("|cffaaaaaa[DBG] Debug mode OFF.|r")
        end
    end)

    -- Expand/Collapse output box button (/\ expands up, V collapses)
    local outputExpanded = false
    local OUTPUT_H_COLLAPSED = 130
    local OUTPUT_H_EXPANDED  = 650   -- 130 + 40 lines * ~13px
    local expBtn = CreateFrame("Button", "LichborneOutputExpBtn", outputBox)
    expBtn:SetPoint("RIGHT", dbgBtn, "LEFT", -2, 0)
    expBtn:SetSize(16, 13)
    expBtn:SetFrameLevel(outputBox:GetFrameLevel() + 2)
    expBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    expBtn:SetBackdropColor(0.10, 0.10, 0.10, 1)
    expBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    expBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local expLbl = expBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expLbl:SetAllPoints(expBtn); expLbl:SetJustifyH("CENTER"); expLbl:SetJustifyV("MIDDLE")
    expLbl:SetText("|cffaaaaaa/\\|r")
    expBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(expBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Output Box Size", 0.78, 0.61, 0.23)
        if outputExpanded then
            GameTooltip:AddLine("Click to collapse the output box.", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Click to expand the output box upward.", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    expBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    expBtn:SetScript("OnClick", function()
        outputExpanded = not outputExpanded
        if outputExpanded then
            outputBox:SetHeight(OUTPUT_H_EXPANDED)
            expLbl:SetText("|cffaaaaaa V|r")
        else
            outputBox:SetHeight(OUTPUT_H_COLLAPSED)
            expLbl:SetText("|cffaaaaaa/\\|r")
        end
    end)

    local outputScroll = CreateFrame("ScrollingMessageFrame", "LichborneOutputMsgFrame", outputBox)
    outputScroll:SetPoint("TOPLEFT", outputBox, "TOPLEFT", 4, -16)
    outputScroll:SetPoint("BOTTOMRIGHT", outputBox, "BOTTOMRIGHT", -4, 4)
    outputScroll:SetFontObject("GameFontNormalSmall")
    outputScroll:SetJustifyH("LEFT")
    outputScroll:SetMaxLines(500)
    outputScroll:SetInsertMode("BOTTOM")
    outputScroll:SetFading(false)
    outputScroll:EnableMouseWheel(true)
    outputScroll:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)

    -- ── Version / Info box (right of Output box) ─────────────
    local infoBox = CreateFrame("Frame", nil, f)
    infoBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 920, 8)
    infoBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 8)
    infoBox:SetHeight(130)
    infoBox:SetFrameLevel(fl + 11)
    infoBox:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    infoBox:SetBackdropColor(0, 0, 0, 0)
    infoBox:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local infoText = infoBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("CENTER", infoBox, "CENTER", 0, 0)
    infoText:SetWidth(160)
    infoText:SetJustifyH("CENTER"); infoText:SetJustifyV("MIDDLE")
    infoText:SetText(
        "|cffd4af37LICHBORNE  —  v2.1|r\n" ..
        "|cffaaaaaaGear Tracker & Raid Planner|r\n" ..
        "|cffaaaaaaWotLK 3.3.5a  ·  AzerothCore + PlayerBots|r\n" ..
        "\n" ..
        "|cffaaaaaaFeedback & Bug Reports:|r\n" ..
        "|cffd4af37lichborne.wow@proton.me|r\n" ..
        "|cff7289DAjared2219|r |cffaaaaaa(Discord)|r"
    )

    -- ── Export Data button (above info box, right-aligned) ─────
    local exportBtn = CreateFrame("Button", "LichborneExportBtn", f)
    exportBtn:SetPoint("BOTTOMRIGHT", infoBox, "TOPRIGHT", -2, 4)
    exportBtn:SetSize(24, 24)
    exportBtn:SetFrameLevel(fl + 12)
    exportBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    exportBtn:SetBackdropColor(0, 0, 0, 1)
    exportBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    exportBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local exportLbl = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    exportLbl:SetAllPoints(exportBtn); exportLbl:SetJustifyH("CENTER"); exportLbl:SetJustifyV("MIDDLE")
    exportLbl:SetText("|cffd4af37>>|r")
    exportBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(exportBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Export Tracker Data", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Saves all tracker data to a text string.", 1, 1, 1)
        GameTooltip:AddLine("Warning: Opening this window may", 1, 0.2, 0.2)
        GameTooltip:AddLine("take several minutes.", 1, 0.2, 0.2)
        GameTooltip:AddLine("Only exports Character data:", 1, 0.55, 0.0)
        GameTooltip:AddLine("a new gear scan is needed.", 1, 0.55, 0.0)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("On Account A:", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("1. Click >> to open the export window.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("2. Click 'Select All' to highlight the text.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("3. Press Ctrl+C to copy.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("On Account B:", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("4. Log in and open Lichborne.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("5. Click << to open the import window.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("6. Click Select, press Ctrl+V to paste.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("7. Click Import to apply the data.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Import button (left of Export button) ──────────────────
    local importBtn = CreateFrame("Button", "LichborneImportBtn", f)
    importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -2, 0)
    importBtn:SetSize(24, 24)
    importBtn:SetFrameLevel(fl + 12)
    importBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    importBtn:SetBackdropColor(0, 0, 0, 1)
    importBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    importBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local importLbl = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importLbl:SetAllPoints(importBtn); importLbl:SetJustifyH("CENTER"); importLbl:SetJustifyV("MIDDLE")
    importLbl:SetText("|cffd4af37<<|r")
    importBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(importBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Import Tracker Data", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Loads tracker data from a copied export string.", 1, 1, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("On Account A:", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("1. Click >> to open the export window.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("2. Click 'Select All' to highlight the text.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("3. Press Ctrl+C to copy.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("On Account B:", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("4. Log in and open Lichborne.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("5. Click << to open this import window.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("6. Click Select, press Ctrl+V to paste.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("7. Click Import to apply the data.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Export popup ────────────────────────────────────────────
    local exportPopup = CreateFrame("Frame", "LichborneExportPopup", UIParent)
    exportPopup:SetSize(520, 320)
    exportPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    exportPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    exportPopup:SetFrameLevel(200)
    exportPopup:SetMovable(true); exportPopup:EnableMouse(true)
    exportPopup:SetScript("OnMouseDown", function(self, btn) if btn=="LeftButton" then self:StartMoving() end end)
    exportPopup:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    exportPopup:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeSize=0,insets={left=0,right=0,top=0,bottom=0}})
    exportPopup:SetBackdropColor(0,0,0,1)
    exportPopup:Hide()

    local expTitle = exportPopup:CreateFontString(nil,"OVERLAY","GameFontNormal")
    expTitle:SetPoint("TOP",exportPopup,"TOP",0,-12)
    expTitle:SetText("|cffC69B3AExport Tracker Data|r")

    -- Dark inset behind the EditBox (no border — direct fill)
    local expBoxBg = CreateFrame("Frame", nil, exportPopup)
    expBoxBg:SetPoint("TOPLEFT",  exportPopup, "TOPLEFT",   0, -28)
    expBoxBg:SetPoint("BOTTOMRIGHT", exportPopup, "BOTTOMRIGHT", -8, 44)
    expBoxBg:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeSize=0,insets={left=0,right=0,top=0,bottom=0}})
    expBoxBg:SetBackdropColor(0.02,0.02,0.06,1)
    expBoxBg:SetFrameLevel(exportPopup:GetFrameLevel() + 1)

    local expScroll = CreateFrame("ScrollFrame", nil, exportPopup)
    expScroll:SetPoint("TOPLEFT",     expBoxBg, "TOPLEFT",     2, -2)
    expScroll:SetPoint("BOTTOMRIGHT", expBoxBg, "BOTTOMRIGHT", -2,  2)
    expScroll:SetFrameLevel(exportPopup:GetFrameLevel() + 1)

    local expEditBox = CreateFrame("EditBox","LichborneExpEditBox",expScroll)
    expEditBox:SetMultiLine(true)
    expEditBox:SetMaxLetters(0)
    expEditBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    expEditBox:SetTextColor(1, 1, 1, 1)
    expEditBox:SetAutoFocus(false)
    expEditBox:EnableMouse(true)
    expEditBox:SetWidth(492)
    expEditBox:SetFrameLevel(exportPopup:GetFrameLevel() + 2)
    expEditBox:SetScript("OnEscapePressed", function() exportPopup:Hide() end)
    expScroll:SetScrollChild(expEditBox)

    local expSelectBtn = CreateFrame("Button",nil,exportPopup,"UIPanelButtonTemplate")
    expSelectBtn:SetSize(110,24); expSelectBtn:SetPoint("BOTTOMLEFT",exportPopup,"BOTTOMLEFT",8,10)
    expSelectBtn:SetText("Select All")
    expSelectBtn:SetFrameLevel(exportPopup:GetFrameLevel() + 3)
    expSelectBtn:SetScript("OnClick", function()
        expEditBox:SetFocus()
        expEditBox:HighlightText()
    end)

    local expHint = exportPopup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    expHint:SetPoint("LEFT",expSelectBtn,"RIGHT",10,0)
    expHint:SetText("|cffd4af37Push Select All then Ctrl+C to copy|r")

    local expCloseBtn = CreateFrame("Button",nil,exportPopup,"UIPanelButtonTemplate")
    expCloseBtn:SetSize(100,24); expCloseBtn:SetPoint("BOTTOMRIGHT",exportPopup,"BOTTOMRIGHT",-8,10)
    expCloseBtn:SetText("Close")
    expCloseBtn:SetFrameLevel(exportPopup:GetFrameLevel() + 3)
    expCloseBtn:SetScript("OnClick", function() exportPopup:Hide() end)

    exportBtn:SetScript("OnClick", function()
        if exportPopup:IsShown() then exportPopup:Hide(); return end
        if _G["LichborneImportPopup"] then _G["LichborneImportPopup"]:Hide() end
        if _G["LichborneOptionsPanel"] then _G["LichborneOptionsPanel"]:Hide() end
        local blob = LB_ExportDB()
        expEditBox:SetText(blob)
        expEditBox:SetFocus()
        expEditBox:HighlightText()
        exportPopup:Show()
        LichborneOutput("|cffC69B3ALichborne:|r |cffd4af37Export ready — click Select All, then press Ctrl+C.|r")
    end)

    -- ── Import popup ────────────────────────────────────────────
    local importPopup = CreateFrame("Frame","LichborneImportPopup",UIParent)
    importPopup:SetSize(520,320)
    importPopup:SetPoint("CENTER",UIParent,"CENTER",0,40)
    importPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    importPopup:SetFrameLevel(200)
    importPopup:SetMovable(true); importPopup:EnableMouse(true)
    importPopup:SetScript("OnMouseDown", function(self,btn) if btn=="LeftButton" then self:StartMoving() end end)
    importPopup:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    importPopup:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeSize=0,insets={left=0,right=0,top=0,bottom=0}})
    importPopup:SetBackdropColor(0,0,0,1)
    importPopup:Hide()

    local impTitle = importPopup:CreateFontString(nil,"OVERLAY","GameFontNormal")
    impTitle:SetPoint("TOP",importPopup,"TOP",0,-12)
    impTitle:SetText("|cffC69B3AImport Tracker Data|r")

    local impWarn = importPopup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    impWarn:SetPoint("TOP",impTitle,"BOTTOM",0,-4)
    impWarn:SetWidth(480); impWarn:SetJustifyH("CENTER")
    impWarn:SetText("|cffff3333WARNING: Paste may take several minutes — do not close WoW!|r")

    local impBoxBg = CreateFrame("Frame",nil,importPopup)
    impBoxBg:SetPoint("TOPLEFT",  importPopup, "TOPLEFT",   0, -46)
    impBoxBg:SetPoint("BOTTOMRIGHT", importPopup, "BOTTOMRIGHT", 0, 62)
    impBoxBg:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeSize=0,insets={left=0,right=0,top=0,bottom=0}})
    impBoxBg:SetBackdropColor(0,0,0,1)
    impBoxBg:SetFrameLevel(importPopup:GetFrameLevel() + 1)

    local impScroll = CreateFrame("ScrollFrame", nil, importPopup)
    impScroll:SetPoint("TOPLEFT",     impBoxBg, "TOPLEFT",     2, -2)
    impScroll:SetPoint("BOTTOMRIGHT", impBoxBg, "BOTTOMRIGHT", -2,  2)
    impScroll:SetFrameLevel(importPopup:GetFrameLevel() + 1)

    local impEditBox = CreateFrame("EditBox","LichborneImpEditBox",impScroll)
    impEditBox:SetMultiLine(true)
    impEditBox:SetMaxLetters(0)
    impEditBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    impEditBox:SetTextColor(1, 1, 1, 1)
    impEditBox:SetAutoFocus(false)
    impEditBox:EnableMouse(true)
    impEditBox:SetWidth(492)
    impEditBox:SetFrameLevel(importPopup:GetFrameLevel() + 2)
    impEditBox:SetScript("OnEscapePressed", function() importPopup:Hide() end)
    impScroll:SetScrollChild(impEditBox)

    -- Status / confirm label (reused for both error and "are you sure?" text)
    local impStatus = importPopup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    impStatus:SetPoint("BOTTOM",importPopup,"BOTTOM",0,30)
    impStatus:SetWidth(500); impStatus:SetJustifyH("CENTER")
    impStatus:SetText("")

    -- Normal bottom buttons
    local impPasteBtn = CreateFrame("Button",nil,importPopup,"UIPanelButtonTemplate")
    impPasteBtn:SetSize(100,24); impPasteBtn:SetPoint("BOTTOMLEFT",importPopup,"BOTTOMLEFT",8,10)
    impPasteBtn:SetText("Select")
    impPasteBtn:SetFrameLevel(importPopup:GetFrameLevel() + 3)
    impPasteBtn:SetScript("OnClick", function() impEditBox:SetFocus() end)

    local impHint = importPopup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    impHint:SetPoint("CENTER",importPopup,"BOTTOM",0,22)
    impHint:SetWidth(500); impHint:SetJustifyH("CENTER")
    impHint:SetText("|cffd4af37Click Select, press Ctrl+V to paste, then click Import.|r")

    -- X close button — top right corner
    local impCancelBtn = CreateFrame("Button",nil,importPopup)
    impCancelBtn:SetSize(22,22)
    impCancelBtn:SetPoint("TOPRIGHT",importPopup,"TOPRIGHT",-6,-6)
    impCancelBtn:SetFrameLevel(importPopup:GetFrameLevel() + 3)
    impCancelBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    impCancelBtn:SetBackdropColor(0.25,0.04,0.04,1)
    impCancelBtn:SetBackdropBorderColor(0.8,0.1,0.1,1)
    impCancelBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local impCancelLbl = impCancelBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    impCancelLbl:SetAllPoints(impCancelBtn); impCancelLbl:SetJustifyH("CENTER")
    impCancelLbl:SetText("|cffff4444X|r")

    -- Import button — bottom right
    local impDoBtn = CreateFrame("Button",nil,importPopup,"UIPanelButtonTemplate")
    impDoBtn:SetSize(100,24); impDoBtn:SetPoint("BOTTOMRIGHT",importPopup,"BOTTOMRIGHT",-8,10)
    impDoBtn:SetText("Import")
    impDoBtn:SetFrameLevel(importPopup:GetFrameLevel() + 3)

    -- Inline confirm buttons — centered pair (150+10+110=270px, start at (520-270)/2=125)
    local impYesBtn = CreateFrame("Button",nil,importPopup,"UIPanelButtonTemplate")
    impYesBtn:SetSize(150,24); impYesBtn:SetPoint("BOTTOMLEFT",importPopup,"BOTTOMLEFT",125,10)
    impYesBtn:SetText("Yes, Replace Data")
    impYesBtn:SetFrameLevel(importPopup:GetFrameLevel() + 3)
    impYesBtn:Hide()

    local impNoBtn = CreateFrame("Button",nil,importPopup,"UIPanelButtonTemplate")
    impNoBtn:SetSize(110,24); impNoBtn:SetPoint("LEFT",impYesBtn,"RIGHT",10,0)
    impNoBtn:SetText("No, Go Back")
    impNoBtn:SetFrameLevel(importPopup:GetFrameLevel() + 3)
    impNoBtn:Hide()

    local function impShowNormal()
        impPasteBtn:Show(); impDoBtn:Show()
        impYesBtn:Hide(); impNoBtn:Hide()
        impHint:Show()
        impStatus:SetText("")
    end

    local function impShowConfirm()
        impPasteBtn:Hide(); impDoBtn:Hide()
        impYesBtn:Show(); impNoBtn:Show()
        impHint:Hide()
        impStatus:SetPoint("BOTTOM",importPopup,"BOTTOM",0,42)
        impStatus:SetText("|cffC69B3AReplace ALL tracker data? This cannot be undone.|r")
    end

    local pendingImport = nil

    impNoBtn:SetScript("OnClick", function()
        pendingImport = nil
        impShowNormal()
    end)

    impYesBtn:SetScript("OnClick", function()
        if not pendingImport then impShowNormal(); return end
        local db = LichborneTrackerDB
        if pendingImport.rows        then db.rows        = pendingImport.rows        end
        if pendingImport.needs       then db.needs       = pendingImport.needs       end
        if pendingImport.raidRosters then db.raidRosters = pendingImport.raidRosters end
        if pendingImport.allGroups   then db.allGroups   = pendingImport.allGroups   end
        if pendingImport.allGroup    then db.allGroup    = pendingImport.allGroup    end
        if pendingImport.notes       then db.notes       = pendingImport.notes       end
        -- raidName/raidSize/raidGroup/raidTier are intentionally NOT imported;
        -- they are per-account settings and should not be overwritten by Account A's config.
        -- Initialize gear fields on imported rows (ilvl array, ilvlLink, gs, realGs)
        -- since V3 exports strip gear data — MigrateGearField fills in the defaults.
        MigrateGearField()
        pendingImport = nil
        importPopup:Hide()
        impShowNormal()
        if RefreshRows then RefreshRows() end
        if LichborneRaidFrame then RefreshRaidRows() end
        if LichborneOverviewFrame  then RefreshOverviewRows()  end
        UpdateSummary()
        LichborneOutput("|cffC69B3ALichborne:|r |cffd4af37Import complete — tracker data loaded.|r")
    end)

    impDoBtn:SetScript("OnClick", function()
        local raw = impEditBox:GetText()
        local result, err = LB_ImportDB(raw)
        if not result then
            impStatus:SetText("|cffff4444Error: " .. (err or "unknown") .. "|r")
            return
        end
        pendingImport = result
        impShowConfirm()
    end)

    impCancelBtn:SetScript("OnClick", function() importPopup:Hide() end)

    importPopup:SetScript("OnHide", function() pendingImport = nil; impShowNormal() end)

    importBtn:SetScript("OnClick", function()
        if importPopup:IsShown() then importPopup:Hide(); return end
        if _G["LichborneExportPopup"] then _G["LichborneExportPopup"]:Hide() end
        if _G["LichborneOptionsPanel"] then _G["LichborneOptionsPanel"]:Hide() end
        impEditBox:SetText("")
        impShowNormal()
        impEditBox:SetFocus()
        importPopup:Show()
    end)

    -- ── Help button (left of Import button) ────────────────────
    local helpBtn = CreateFrame("Button", "LichborneHelpBtn", f)
    helpBtn:SetPoint("RIGHT", importBtn, "LEFT", -2, 0)
    helpBtn:SetSize(24, 24)
    helpBtn:SetFrameLevel(fl + 12)
    -- no backdrop
    helpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local helpIcon = helpBtn:CreateTexture(nil, "OVERLAY")
    helpIcon:SetPoint("CENTER", helpBtn, "CENTER", 0, 0)
    helpIcon:SetSize(22, 22)
    helpIcon:SetTexture("Interface\\Icons\\Inv_misc_book_08")
    helpBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(helpBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("SETTING UP YOUR TRACKER", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("For First Time Use", 0.4, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("1. Add your PlayerBots to the group.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("2. Click |cff4488FF+Full Group Scan|r to |cffC69B3Aadd bots,|r gear score", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   |cffC69B3A(GS)|r, |cffC69B3AiLvL|r, |cffC69B3Agear,|r and |cffC69B3Aspecialization|r to the tracker.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   Allow 4-5 minutes for a complete scan.", 1, 0.55, 0.0)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("TIP: Use |cffC69B3A.playerbot bot addaccount <account>|r to", 0.4, 0.8, 1)
        GameTooltip:AddLine("     quickly add bots for first time set up.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3A+Add Target|r buttons are used for |cffC69B3ASingle|r scans.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3A+Add Group|r buttons are used for |cffC69B3AGroup|r scans.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3AClean Up Bots|r removes bots currently not", 0.4, 0.8, 1)
        GameTooltip:AddLine("     in your group. (.playerbot bot remove)", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3ADisband Group|r removes PlayerBots before", 0.4, 0.8, 1)
        GameTooltip:AddLine("     disbanding the group.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3AStop Scan|r stops the current scan.", 0.4, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cffC69B3ANote:|r All |cffC69B3AScans|r add characters to the tracker before", 0.4, 0.8, 1)
        GameTooltip:AddLine("     executing, to prevent corruption.", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Raid Tab help button ──────────────────────────────────────
    local raidHelpBtn = CreateFrame("Button", "LichborneRaidHelpBtn", f)
    raidHelpBtn:SetPoint("RIGHT", helpBtn, "LEFT", -2, 0)
    raidHelpBtn:SetSize(24, 24)
    raidHelpBtn:SetFrameLevel(fl + 12)
    raidHelpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local raidHelpIcon = raidHelpBtn:CreateTexture(nil, "OVERLAY")
    raidHelpIcon:SetPoint("CENTER", raidHelpBtn, "CENTER", 0, 0)
    raidHelpIcon:SetSize(22, 22)
    raidHelpIcon:SetTexture("Interface\\Icons\\Inv_misc_book_06")
    raidHelpBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(raidHelpBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("RAID TAB", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Allows you to plan raid configurations,", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("invite groups, and select roles for your", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("PlayerBot team.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("For Groups:", 0.27, 0.53, 1)
        GameTooltip:AddLine("1. Select the |cff4488ffTO 5-Man Dungeons|r tab.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("2. Add characters via the Class or Overview tabs.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("3. Click |cff4488ffINVITE GROUP|r at the bottom of", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   the tracker to log in your PlayerBots.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("For Raids:", 1, 0.4, 0)
        GameTooltip:AddLine("1. Pick a Tier and Raid from the dropdowns", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   in the raid table header.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("2. Add characters via the Class or Overview tabs.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("3. Click |cffFF6600INVITE RAID|r at the bottom of", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   the tracker to log in your PlayerBots.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("TIP: |cffC69B3AInvite Group|r always invites your 5-Man team,", 0.4, 0.8, 1)
        GameTooltip:AddLine("     regardless of which raid tab is active.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: |cffC69B3AInvite Raid|r always invites from the", 0.4, 0.8, 1)
        GameTooltip:AddLine("     currently selected raid.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: You can have multiple raid configurations", 0.4, 0.8, 1)
        GameTooltip:AddLine("     for each raid.  Use the dropdown menu located", 0.4, 0.8, 1)
        GameTooltip:AddLine("     in the header (|cffC69B3AA, B, C|r).", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use |cffC69B3ACopy|r to duplicate your selected config", 0.4, 0.8, 1)
        GameTooltip:AddLine("     into another raid category (see header).", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use |cffC69B3AClear|r (next to Copy) to reset your", 0.4, 0.8, 1)
        GameTooltip:AddLine("     current selected raid.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Raid configurations are saved after reloads.", 0.4, 0.8, 1)
        GameTooltip:AddLine("     You must manually clear them.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Assign |cffC69B3ARoles|r (Tank, Healer, DPS)", 0.4, 0.8, 1)
        GameTooltip:AddLine("     by clicking the Roles Column.  Write", 0.4, 0.8, 1)
        GameTooltip:AddLine("     notes to help keep organized.", 0.4, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cffC69B3ANote:|r All Raids have a unique table that work", 0.4, 0.8, 1)
        GameTooltip:AddLine("     |cffC69B3Aindependently|r of each other.", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    raidHelpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- ── Class Tab help button ─────────────────────────────────────
    local classHelpBtn = CreateFrame("Button", "LichborneClassHelpBtn", f)
    classHelpBtn:SetPoint("RIGHT", raidHelpBtn, "LEFT", -2, 0)
    classHelpBtn:SetSize(24, 24)
    classHelpBtn:SetFrameLevel(fl + 12)
    classHelpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local classHelpIcon = classHelpBtn:CreateTexture(nil, "OVERLAY")
    classHelpIcon:SetPoint("CENTER", classHelpBtn, "CENTER", 0, 0)
    classHelpIcon:SetSize(22, 22)
    classHelpIcon:SetTexture("Interface\\Icons\\Inv_misc_book_01")
    classHelpBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(classHelpBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("CLASS TABS", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Each class has its own dedicated tab.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("1. Scan to add gear score (|cffC69B3AGS|r), |cffC69B3AiLvL|r and gear.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("2. Hover on a gear slot to view the equipped item.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("3. The |cffC69B3AiLvL|r and |cffC69B3AGS|r is calculated after a scan", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   (not manual edits)", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("4. After a gear upgrade, it is suggested to use", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   |cff4488FF+Add Target Gear|r to update the row.  OR", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   |cff4488FF+Add Group Gear|r at the end of the raid.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   Gear only updates after a scan, not on equip.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("TIP: Click any column header to |cffC69B3ASort|r.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use the |cffC69B3ANeed|r cell to flag which gear slot", 0.4, 0.8, 1)
        GameTooltip:AddLine("     a character needs to upgrade.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: You can change the spec by clicking the icon.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Click |cff00cc00[+]|r on a PlayerBot row to add to the", 0.4, 0.8, 1)
        GameTooltip:AddLine("     |cffC69B3ARaid Tab|r.  Right-click |cffFF6600[+]|r to remove.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Click |cff00cc00[>]|r to invite PlayerBot to your", 0.4, 0.8, 1)
        GameTooltip:AddLine("     |cffC69B3AGroup|r.  Right-click |cff00cc00[>]|r to remove.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use |cff66CCFFDelete Character|r |cffff3333[x]|r to remove", 0.4, 0.8, 1)
        GameTooltip:AddLine("     PlayerBots from your tracker.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: You can drag row numbers to reorder", 0.4, 0.8, 1)
        GameTooltip:AddLine("     characters within the list.", 0.4, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cffC69B3ANote:|r Some |cff00cc00<Random Enchantment>|r gear cannot", 0.4, 0.8, 1)
        GameTooltip:AddLine("     be displayed correctly, due to client limitations.", 0.4, 0.8, 1)
        GameTooltip:AddLine("|cffC69B3ANote:|r Some items may display with a 0 Gear Score.", 0.4, 0.8, 1)
        GameTooltip:AddLine("     Such as PvP gear.", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    classHelpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Overview Tab help button ──────────────────────────────────
    local overviewHelpBtn = CreateFrame("Button", "LichborneOverviewHelpBtn", f)
    overviewHelpBtn:SetPoint("RIGHT", raidHelpBtn, "LEFT", -2, 0)
    overviewHelpBtn:SetSize(24, 24)
    overviewHelpBtn:SetFrameLevel(fl + 12)
    overviewHelpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local overviewHelpIcon = overviewHelpBtn:CreateTexture(nil, "OVERLAY")
    overviewHelpIcon:SetPoint("CENTER", overviewHelpBtn, "CENTER", 0, 0)
    overviewHelpIcon:SetSize(22, 22)
    overviewHelpIcon:SetTexture("Interface\\Icons\\Inv_misc_book_05")
    overviewHelpBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(overviewHelpBtn, "ANCHOR_LEFT")
        GameTooltip:AddLine("OVERVIEW TAB", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Provides an overview of all current PlayerBots", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("you have in your tracker.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("1. Click |cff00cc00[+]|r on a PlayerBot row to add to the", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   selected raid. (in |cffC69B3ARaid Tab|r)", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   Right-click |cffFF6600[+]|r to remove from raid.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("2. Click |cff00cc00[>]|r to invite a PlayerBot to your |cffC69B3AGroup|r.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   Right-click to remove from your |cffC69B3AGroup|r.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("3. If you have more than 60 characters, use the", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("   |cffC69B3APage|r dropdown in the header to view overflow.", 0.9, 0.9, 0.9)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("TIP: Click any column header to |cffC69B3ASort|r.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use the |cffC69B3ANeed|r cell to mark which slot a", 0.4, 0.8, 1)
        GameTooltip:AddLine("     PlayerBot needs an upgrade.", 0.4, 0.8, 1)
        GameTooltip:AddLine("TIP: Use Delete Character |cffff3333[x]|r to remove", 0.4, 0.8, 1)
        GameTooltip:AddLine("     PlayerBots from your tracker.", 0.4, 0.8, 1)
        GameTooltip:Show()
    end)
    overviewHelpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Options panel (DBM-style, Update tab)
    local optionsPanel = CreateFrame("Frame", "LichborneOptionsPanel", UIParent)
    optionsPanel:SetSize(500, 420)
    optionsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    optionsPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    optionsPanel:SetFrameLevel(200)
    optionsPanel:SetMovable(true)
    optionsPanel:EnableMouse(true)
    optionsPanel:SetScript("OnMouseDown", function(self, btn) if btn == "LeftButton" then self:StartMoving() end end)
    optionsPanel:SetScript("OnMouseUp",   function(self) self:StopMovingOrSizing() end)
    optionsPanel:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=5, right=5, top=5, bottom=5}
    })
    optionsPanel:SetBackdropColor(0.06, 0.07, 0.14, 0.98)
    optionsPanel:SetBackdropBorderColor(0.50, 0.50, 0.50, 1)
    optionsPanel:Hide()

    -- Title bar
    local optsTitleBg = optionsPanel:CreateTexture(nil, "ARTWORK")
    optsTitleBg:SetPoint("TOPLEFT",  optionsPanel, "TOPLEFT",  6, -6)
    optsTitleBg:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -6, -6)
    optsTitleBg:SetHeight(30)
    optsTitleBg:SetTexture(0.07, 0.09, 0.20, 1)

    local optsTitleText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    optsTitleText:SetPoint("CENTER", optsTitleBg, "CENTER", 0, 0)
    optsTitleText:SetText("|cffC69B3ALichborne Gear Tracker|r")

    local optsXBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelCloseButton")
    optsXBtn:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", 4, 4)
    optsXBtn:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)
    optsXBtn:SetScript("OnClick", function() optionsPanel:Hide() end)

    local optsTitleDiv = optionsPanel:CreateTexture(nil, "OVERLAY")
    optsTitleDiv:SetPoint("TOPLEFT",  optionsPanel, "TOPLEFT",  6, -36)
    optsTitleDiv:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -6, -36)
    optsTitleDiv:SetHeight(1)
    optsTitleDiv:SetTexture(0.78, 0.61, 0.23, 0.9)

    -- Update tab button
    local optsTabGeneral = CreateFrame("Button", nil, optionsPanel)
    optsTabGeneral:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 8, -40)
    optsTabGeneral:SetSize(100, 24)
    optsTabGeneral:SetFrameLevel(optionsPanel:GetFrameLevel() + 2)
    optsTabGeneral:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2, right=2, top=2, bottom=2}
    })
    optsTabGeneral:SetBackdropColor(0.12, 0.16, 0.30, 1)
    optsTabGeneral:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    optsTabGeneral:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local optsTabLbl = optsTabGeneral:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optsTabLbl:SetAllPoints(optsTabGeneral)
    optsTabLbl:SetJustifyH("CENTER")
    optsTabLbl:SetText("|cffFFFFFFUpdate|r")

    -- Content area (the bordered box like DBM)
    local optsContentBox = CreateFrame("Frame", nil, optionsPanel)
    optsContentBox:SetPoint("TOPLEFT",     optionsPanel, "TOPLEFT",    6, -66)
    optsContentBox:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -6, 48)
    optsContentBox:SetFrameLevel(optionsPanel:GetFrameLevel() + 1)
    optsContentBox:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=3, right=3, top=3, bottom=3}
    })
    optsContentBox:SetBackdropColor(0.03, 0.04, 0.09, 1)
    optsContentBox:SetBackdropBorderColor(0.60, 0.60, 0.60, 0.8)
    -- ── Update tab content ────────────────────────────────────────────

    -- Get latest version via Git clone
    local updLabel1 = optsContentBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    updLabel1:SetPoint("TOPLEFT", optsContentBox, "TOPLEFT", 10, -14)
    updLabel1:SetText("|cffd4af37Get the latest version -- clone the repository with Git:|r")

    local updBg1 = CreateFrame("Frame", nil, optsContentBox)
    updBg1:SetPoint("TOPLEFT",  optsContentBox, "TOPLEFT",  8, -34)
    updBg1:SetPoint("TOPRIGHT", optsContentBox, "TOPRIGHT", -8, -34)
    updBg1:SetHeight(22)
    updBg1:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    updBg1:SetBackdropColor(0.02, 0.02, 0.06, 1)
    updBg1:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.8)
    updBg1:SetFrameLevel(optionsPanel:GetFrameLevel() + 2)

    local updEdit1 = CreateFrame("EditBox", "LichborneUpdateCloneBox", updBg1)
    updEdit1:SetPoint("TOPLEFT",     updBg1, "TOPLEFT",      4, -2)
    updEdit1:SetPoint("BOTTOMRIGHT", updBg1, "BOTTOMRIGHT", -4,  2)
    updEdit1:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    updEdit1:SetTextColor(1, 1, 1, 1)
    updEdit1:SetAutoFocus(false)
    updEdit1:EnableMouse(true)
    updEdit1:SetText("git clone https://github.com/Lichborne-AC/LichborneTracker")
    updEdit1:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)

    local updSelectBtn1 = CreateFrame("Button", nil, optsContentBox, "UIPanelButtonTemplate")
    updSelectBtn1:SetSize(90, 22)
    updSelectBtn1:SetPoint("TOPLEFT", optsContentBox, "TOPLEFT", 8, -62)
    updSelectBtn1:SetText("Select All")
    updSelectBtn1:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)
    updSelectBtn1:SetScript("OnClick", function()
        updEdit1:SetFocus()
        updEdit1:HighlightText()
    end)

    local updHint1 = optsContentBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    updHint1:SetPoint("LEFT", updSelectBtn1, "RIGHT", 10, 0)
    updHint1:SetText("|cffd4af37Push Select All then Ctrl+C to copy|r")

    -- Browse / download from GitHub
    local updLabel2 = optsContentBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    updLabel2:SetPoint("TOPLEFT", optsContentBox, "TOPLEFT", 10, -96)
    updLabel2:SetText("|cffd4af37Browse or download from the GitHub repository:|r")

    local updBg2 = CreateFrame("Frame", nil, optsContentBox)
    updBg2:SetPoint("TOPLEFT",  optsContentBox, "TOPLEFT",  8, -116)
    updBg2:SetPoint("TOPRIGHT", optsContentBox, "TOPRIGHT", -8, -116)
    updBg2:SetHeight(22)
    updBg2:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    updBg2:SetBackdropColor(0.02, 0.02, 0.06, 1)
    updBg2:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.8)
    updBg2:SetFrameLevel(optionsPanel:GetFrameLevel() + 2)

    local updEdit2 = CreateFrame("EditBox", "LichborneUpdateRepoBox", updBg2)
    updEdit2:SetPoint("TOPLEFT",     updBg2, "TOPLEFT",      4, -2)
    updEdit2:SetPoint("BOTTOMRIGHT", updBg2, "BOTTOMRIGHT", -4,  2)
    updEdit2:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    updEdit2:SetTextColor(1, 1, 1, 1)
    updEdit2:SetAutoFocus(false)
    updEdit2:EnableMouse(true)
    updEdit2:SetText("https://github.com/Lichborne-AC/LichborneTracker")
    updEdit2:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)

    local updSelectBtn2 = CreateFrame("Button", nil, optsContentBox, "UIPanelButtonTemplate")
    updSelectBtn2:SetSize(90, 22)
    updSelectBtn2:SetPoint("TOPLEFT", optsContentBox, "TOPLEFT", 8, -144)
    updSelectBtn2:SetText("Select All")
    updSelectBtn2:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)
    updSelectBtn2:SetScript("OnClick", function()
        updEdit2:SetFocus()
        updEdit2:HighlightText()
    end)

    local updHint2 = optsContentBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    updHint2:SetPoint("LEFT", updSelectBtn2, "RIGHT", 10, 0)
    updHint2:SetText("|cffd4af37Push Select All then Ctrl+C to copy|r")
    -- Bottom divider
    local optsBottomDiv = optionsPanel:CreateTexture(nil, "OVERLAY")
    optsBottomDiv:SetPoint("BOTTOMLEFT",  optionsPanel, "BOTTOMLEFT",  6, 46)
    optsBottomDiv:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -6, 46)
    optsBottomDiv:SetHeight(1)
    optsBottomDiv:SetTexture(0.78, 0.61, 0.23, 0.5)

    -- Close button
    local optsCloseBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    optsCloseBtn:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -8, 12)
    optsCloseBtn:SetSize(80, 24)
    optsCloseBtn:SetText("Close")
    optsCloseBtn:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)
    optsCloseBtn:SetScript("OnClick", function() optionsPanel:Hide() end)

    -- Apply button
    local optsApplyBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    optsApplyBtn:SetPoint("RIGHT", optsCloseBtn, "LEFT", -6, 0)
    optsApplyBtn:SetSize(80, 24)
    optsApplyBtn:SetText("Apply")
    optsApplyBtn:SetFrameLevel(optionsPanel:GetFrameLevel() + 3)
    optsApplyBtn:SetScript("OnClick", function()
        -- placeholder: will apply settings when populated
    end)

    -- Settings button (rightmost of the button row)
    local settingsBtn = CreateFrame("Button", "LichborneSettingsBtn", f)
    settingsBtn:SetPoint("BOTTOMRIGHT", infoBox, "TOPRIGHT", 0, 7)
    settingsBtn:SetSize(24, 24)
    settingsBtn:SetFrameLevel(fl + 12)
    -- no backdrop
    settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local settingsIcon = settingsBtn:CreateTexture(nil, "OVERLAY")
    settingsIcon:SetPoint("CENTER", settingsBtn, "CENTER", 0, 0)
    settingsIcon:SetSize(22, 22)
    settingsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
    settingsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(settingsBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Options", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Open the Lichborne options panel.", 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    settingsBtn:SetScript("OnClick", function()
        if optionsPanel:IsShown() then
            optionsPanel:Hide()
        else
            if _G["LichborneExportPopup"] then _G["LichborneExportPopup"]:Hide() end
            if _G["LichborneImportPopup"] then _G["LichborneImportPopup"]:Hide() end
            optionsPanel:Show()
        end
    end)

    -- Group filter button: pvp icon swaps red/green with filter state
    local groupFilterBtn = CreateFrame("Button", "LichborneGroupFilterBtn", f)
    groupFilterBtn:SetSize(24, 24)
    groupFilterBtn:SetFrameLevel(fl + 12)
    groupFilterBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
    groupFilterBtn:SetBackdropColor(0.05, 0.08, 0.18, 1)
    groupFilterBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local gfIcon = groupFilterBtn:CreateTexture(nil, "OVERLAY")
    gfIcon:SetPoint("CENTER", groupFilterBtn, "CENTER", 0, 0)
    gfIcon:SetSize(24, 24)
    gfIcon:SetTexture("Interface\\Icons\\Achievement_pvp_h_02")  -- red = off
    local function UpdateGroupFilterBtn()
        if LBFilter.groupActive then
            gfIcon:SetTexture("Interface\\Icons\\Achievement_pvp_g_02")
        else
            gfIcon:SetTexture("Interface\\Icons\\Achievement_pvp_h_02")
        end
    end
    groupFilterBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(groupFilterBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Party Filter", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Hides characters not in your party or raid.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    groupFilterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    groupFilterBtn:SetScript("OnClick", function()
        LBFilter.groupActive = not LBFilter.groupActive
        UpdateGroupFilterBtn()
        RefreshRows()
        if LichborneOverviewFrame then RefreshOverviewRows() end
    end)
    UpdateGroupFilterBtn()

    -- ── Show Only Raid Members filter button ─────────────────────────
    local hideRaidBtn = CreateFrame("Button", "LichborneHideRaidBtn", f)
    hideRaidBtn:SetSize(24, 24)
    hideRaidBtn:SetFrameLevel(fl + 12)
    hideRaidBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
    hideRaidBtn:SetBackdropColor(0.05, 0.08, 0.18, 1)
    hideRaidBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local hrIcon = hideRaidBtn:CreateTexture(nil, "OVERLAY")
    hrIcon:SetPoint("CENTER", hideRaidBtn, "CENTER", 0, 0)
    hrIcon:SetSize(24, 24)
    hrIcon:SetTexture("Interface\\Icons\\Achievement_pvp_h_12")  -- red = off (raid members visible)
    hideRaidBtn:SetPoint("LEFT", groupFilterBtn, "RIGHT", 2, 0)
    local function UpdateHideRaidBtn()
        if LBFilter.hideRaid then
            hrIcon:SetTexture("Interface\\Icons\\Achievement_pvp_g_12")
            hideRaidBtn:SetBackdropColor(0.05, 0.35, 0.10, 1)
        else
            hrIcon:SetTexture("Interface\\Icons\\Achievement_pvp_h_12")
            hideRaidBtn:SetBackdropColor(0.05, 0.08, 0.18, 1)
        end
    end
    hideRaidBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(hideRaidBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Raid Tab Filter", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Shows only characters in your currently selected raid.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    hideRaidBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hideRaidBtn:SetScript("OnClick", function()
        LBFilter.hideRaid = not LBFilter.hideRaid
        UpdateHideRaidBtn()
        RefreshRows()
        if LichborneOverviewFrame then RefreshOverviewRows() end
    end)
    UpdateHideRaidBtn()

    -- ── Filter button 2 ────────────────────────────────────────
    local filterBtn2 = CreateFrame("Button", "LichborneFilterBtn2", f)
    filterBtn2:SetSize(24, 24)
    filterBtn2:SetFrameLevel(fl + 12)
    filterBtn2:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",tile=true,tileSize=16,insets={left=0,right=0,top=0,bottom=0}})
    filterBtn2:SetBackdropColor(0.05, 0.08, 0.18, 1)
    filterBtn2:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local fb2Icon = filterBtn2:CreateTexture(nil, "OVERLAY")
    fb2Icon:SetPoint("CENTER", filterBtn2, "CENTER", 0, 0)
    fb2Icon:SetSize(24, 24)
    fb2Icon:SetTexture("Interface\\Icons\\Achievement_pvp_h_06")  -- off by default
    filterBtn2:SetPoint("LEFT", hideRaidBtn, "RIGHT", 2, 0)

    local function UpdateLevelBtn()
        if LBFilter.showLevel then
            fb2Icon:SetTexture("Interface\\Icons\\Achievement_pvp_g_06")
        else
            fb2Icon:SetTexture("Interface\\Icons\\Achievement_pvp_h_06")
        end
    end
    filterBtn2:SetScript("OnEnter", function()
        GameTooltip:SetOwner(filterBtn2, "ANCHOR_TOP")
        GameTooltip:AddLine("Show Level", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Replaces row numbers with character level", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    filterBtn2:SetScript("OnLeave", function() GameTooltip:Hide() end)
    filterBtn2:SetScript("OnClick", function()
        LBFilter.showLevel = not LBFilter.showLevel
        LichborneTrackerDB.showLevel = LBFilter.showLevel
        UpdateLevelBtn()
        RefreshRows()
        if LichborneOverviewFrame then RefreshOverviewRows() end
    end)
    UpdateLevelBtn()

    -- ── Tier Key visibility toggle button ────────────────────────────
    local tierKeyFrames = {}
    local tkLabel  -- forward declared; assigned in tier key section below

    local tierKeyToggleBtn = CreateFrame("Button", "LichborneTierKeyToggleBtn", f)
    tierKeyToggleBtn:SetSize(24, 24)
    tierKeyToggleBtn:SetFrameLevel(fl + 12)
    tierKeyToggleBtn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets   = {left=2,right=2,top=2,bottom=2},
    })
    tierKeyToggleBtn:SetBackdropColor(0.05, 0.08, 0.18, 1)
    tierKeyToggleBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 1)
    tierKeyToggleBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    tierKeyToggleBtn:SetPoint("LEFT", filterBtn2, "RIGHT", 2, 0)
    local tkvIcon = tierKeyToggleBtn:CreateTexture(nil, "OVERLAY")
    tkvIcon:SetPoint("CENTER", tierKeyToggleBtn, "CENTER", 0, 0)
    tkvIcon:SetSize(24, 24)
    local function UpdateTierKeyToggleBtn()
        if LBFilter.showTierKey then
            tkvIcon:SetTexture("Interface\\Icons\\Achievement_pvp_h_11")
            if tkLabel then tkLabel:Show() end
            for _, frm in ipairs(tierKeyFrames) do frm:Show() end
        else
            tkvIcon:SetTexture("Interface\\Icons\\Achievement_pvp_g_11")
            if tkLabel then tkLabel:Hide() end
            for _, frm in ipairs(tierKeyFrames) do frm:Hide() end
        end
    end
    tierKeyToggleBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(tierKeyToggleBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Tier Key", 0.78, 0.61, 0.23)
        GameTooltip:AddLine("Show or hide the tier key bar.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    tierKeyToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tierKeyToggleBtn:SetScript("OnClick", function()
        LBFilter.showTierKey = not LBFilter.showTierKey
        LichborneTrackerDB.showTierKey = LBFilter.showTierKey
        UpdateTierKeyToggleBtn()
    end)
    UpdateTierKeyToggleBtn()

    -- Tier Key filter swatches (bottom bar)
    tkLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tkLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 152)
    tkLabel:SetText("|cffC69B3ATiers:|r")

    local prevTier = nil
    for t = 1, 17 do
        local tc = TIER_KEY_COLORS[t]
        local tsf = CreateFrame("Frame", nil, f)
        tsf:SetSize(24, 24)
        tsf:SetFrameLevel(fl + 12)
        tsf:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=8,
            insets   = {left=2,right=2,top=2,bottom=2},
        })
        tsf:SetBackdropColor(tc.r, tc.g, tc.b, 1)
        tsf:SetBackdropBorderColor(0.78, 0.61, 0.23, 1)
        if t == 1 then
            tsf:SetPoint("LEFT", tkLabel, "RIGHT", 2, 0)
        else
            tsf:SetPoint("LEFT", prevTier, "RIGHT", 2, 0)
        end
        table.insert(tierKeyFrames, tsf)
        local glow = tsf:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints(tsf)
        glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.55)
        glow:Hide()
        local tlbl = tsf:CreateFontString(nil, "OVERLAY")
        tlbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        tlbl:SetAllPoints(tsf)
        tlbl:SetJustifyH("CENTER"); tlbl:SetJustifyV("MIDDLE")
        tlbl:SetTextColor(1, 1, 1)
        tlbl:SetText("T"..t)
        tsf:EnableMouse(true)
        tsf:SetScript("OnEnter", function()
            glow:Show()
            GameTooltip:SetOwner(tsf, "ANCHOR_TOP")
            local hex2 = t <= 6 and "ff6666" or t <= 12 and "55cc55" or "5599ff"
            local expName = t <= 6 and "Level 60" or t <= 12 and "Level 70" or "Level 80"
            GameTooltip:AddLine("|cff"..hex2.."Tier "..t.." ("..expName..")|r")
            local raids = TIER_TOOLTIP_RAIDS[t]
            if raids then
                for _, rname in ipairs(raids) do
                    GameTooltip:AddLine(rname, 1, 1, 1)
                end
            end
            GameTooltip:Show()
        end)
        tsf:SetScript("OnLeave", function() glow:Hide(); GameTooltip:Hide() end)
        prevTier = tsf
    end
    UpdateTierKeyToggleBtn()

    -- groupFilterBtn moves to left side, positioned after Filters: label
    groupFilterBtn:ClearAllPoints()
    groupFilterBtn:SetPoint("LEFT", filtersLbl, "RIGHT", 2, 0)
    -- Right-side chain: ? raidHelp classHelp overviewHelp << >> gear  (left to right)
    -- settingsBtn is anchored at BOTTOMRIGHT of infoBox (rightmost).
    exportBtn:ClearAllPoints()
    exportBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -2, 0)
    importBtn:ClearAllPoints()
    importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -2, 0)
    overviewHelpBtn:ClearAllPoints()
    overviewHelpBtn:SetPoint("RIGHT", importBtn, "LEFT", -2, 0)
    raidHelpBtn:ClearAllPoints()
    raidHelpBtn:SetPoint("RIGHT", overviewHelpBtn, "LEFT", -2, 0)
    classHelpBtn:ClearAllPoints()
    classHelpBtn:SetPoint("RIGHT", raidHelpBtn, "LEFT", -2, 0)
    helpBtn:ClearAllPoints()
    helpBtn:SetPoint("RIGHT", classHelpBtn, "LEFT", -2, 0)

end

UpdateSummary = function()
    if not LichborneAvgSwatches then return end
    for _, sw in ipairs(LichborneAvgSwatches) do
        local cls = sw.cls
        if cls == "Raid" then break end
        local avg = GetClassAvgIlvl(cls)
        local c = CLASS_COLORS[cls]
        if not c then break end
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        sw.bg:SetTexture(0.08, 0.10, 0.18, 1)
        if avg > 0 then
            sw.lbl:SetText(hex..(TAB_LABELS[cls])..": |cffd4af37"..avg.."|r")
        else
            sw.lbl:SetText(hex..(TAB_LABELS[cls])..": |cff555555--|r")
        end
    end
    -- Update Avg GS bar
    if LichborneCountLabels then
        local classIndex = {["Death Knight"]=1,["Druid"]=2,["Hunter"]=3,["Mage"]=4,["Paladin"]=5,["Priest"]=6,["Rogue"]=7,["Shaman"]=8,["Warlock"]=9,["Warrior"]=10}
        for cls, lbl in pairs(LichborneCountLabels) do
            local c = CLASS_COLORS[cls]
            if not c then break end
            local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
            local gs = GetClassAvgGS(cls)
            if gs > 0 then
                lbl:SetText(hex..(TAB_LABELS[cls])..": |cffd4af37"..gs.."|r")
            else
                lbl:SetText(hex..(TAB_LABELS[cls])..": |cff555555--|r")
            end
            local sw = _G["LichborneClassSwatch"..classIndex[cls]]
            if sw and sw.bg then
                sw.bg:SetTexture(0.08, 0.10, 0.18, 1)
            end
        end
    end
    -- Update Roster iLvl and Roster GS blocks
    if LichborneRosterIlvlLabel then
        local rIlvl = GetRosterAvgIlvl()
        if rIlvl > 0 then
            LichborneRosterIlvlLabel:SetText("|cffC69B3ARoster iLvL:|r |cffff8000"..rIlvl.."|r")
        else
            LichborneRosterIlvlLabel:SetText("|cffC69B3ARoster iLvL:|r |cff555555--|r")
        end
    end
    if LichborneRosterGsLabel then
        local rGs = GetRosterAvgGS()
        if rGs > 0 then
            LichborneRosterGsLabel:SetText("|cffC69B3ARoster GS:|r |cffff8000"..rGs.."|r")
        else
            LichborneRosterGsLabel:SetText("|cffC69B3ARoster GS:|r |cff555555--|r")
        end
    end
end

-- ── Open ──────────────────────────────────────────────────────
local frameBgBuilt = false
local function BuildFrameBG()
    if frameBgBuilt then return end
    frameBgBuilt = true
    local f = LichborneTrackerFrame
    f:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
        insets={left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(0.04, 0.06, 0.13, 1.0)
    f:SetBackdropBorderColor(0.78, 0.61, 0.23, 1.0)
    local titleBg = f:CreateTexture(nil, "ARTWORK")
    titleBg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    titleBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    titleBg:SetHeight(30)
    titleBg:SetTexture(0.06, 0.09, 0.20, 1)
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -33)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -33)
    divider:SetHeight(2)
    divider:SetTexture(0.78, 0.61, 0.23, 1)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -12)
    title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -280, -12)
    title:SetJustifyH("LEFT")
    title:SetText("|cffC69B3ALICHBORNE|r  —  Gear Tracker  |cffaaaaaa v2.1|r")
    local closeBtn = CreateFrame("Button", "LichborneCloseBtn", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Close all dropdown menus when the frame hides (ESC key or close button)
    f:SetScript("OnHide", function()
        if _G["LichborneRaidTierMenu"]  then _G["LichborneRaidTierMenu"]:Hide()  end
        if _G["LichborneRaidRaidMenu"]  then _G["LichborneRaidRaidMenu"]:Hide()  end
        if _G["LichborneRaidGroupMenu"] then _G["LichborneRaidGroupMenu"]:Hide() end
        if _G["LichborneOverviewGroupMenu"]  then _G["LichborneOverviewGroupMenu"]:Hide()  end
        if LichborneSpecMenu            then LichborneSpecMenu:Hide()            end
        CloseAllSortMenus()
    end)

    -- ── Danger zone buttons (far right of title bar) ──────────
    local function MakeDangerConfirm(title2, lines, onConfirm)
        local cf = CreateFrame("Frame", nil, UIParent)
        cf:SetFrameStrata("FULLSCREEN_DIALOG")
        cf:SetSize(340, 130)
        cf:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        cf:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=4,right=4,top=4,bottom=4}})
        cf:SetBackdropColor(0.08,0.04,0.04,0.98)
        cf:SetBackdropBorderColor(0.90,0.20,0.20,1)
        cf:Hide()

        local hdr = cf:CreateFontString(nil,"OVERLAY","GameFontNormal")
        hdr:SetPoint("TOP",cf,"TOP",0,-12)
        hdr:SetText("|cffff4444"..title2.."|r")

        local sub = cf:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        sub:SetPoint("TOP",hdr,"BOTTOM",0,-4); sub:SetWidth(310)
        sub:SetText("|cffaaaaaa"..lines.."|r")

        local yBtn = CreateFrame("Button",nil,cf)
        yBtn:SetSize(140,26); yBtn:SetPoint("BOTTOMLEFT",cf,"BOTTOMLEFT",12,10)
        yBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        yBtn:SetBackdropColor(0.35,0.04,0.04,1); yBtn:SetBackdropBorderColor(1,0.2,0.2,0.9)
        yBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local yLbl=yBtn:CreateFontString(nil,"OVERLAY","GameFontNormal"); yLbl:SetAllPoints(yBtn); yLbl:SetJustifyH("CENTER")
        yLbl:SetText("|cffff5555Yes, wipe it all|r")
        yBtn:SetScript("OnClick",function() onConfirm(); cf:Hide() end)

        local nBtn = CreateFrame("Button",nil,cf)
        nBtn:SetSize(140,26); nBtn:SetPoint("BOTTOMRIGHT",cf,"BOTTOMRIGHT",-12,10)
        nBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        nBtn:SetBackdropColor(0.04,0.15,0.04,1); nBtn:SetBackdropBorderColor(0.2,0.8,0.2,0.9)
        nBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local nLbl=nBtn:CreateFontString(nil,"OVERLAY","GameFontNormal"); nLbl:SetAllPoints(nBtn); nLbl:SetJustifyH("CENTER")
        nLbl:SetText("|cff44ff44Keep my data|r")
        nBtn:SetScript("OnClick",function() cf:Hide() end)
        return cf
    end

    -- Confirm: Clear ALL data (characters + all raids)
    local confirmAll = MakeDangerConfirm(
        "⚠  Wipe Entire Database?",
        "This permanently deletes ALL tracked characters,\ngear data, raid rosters, and the Overview list.",
        function()
            LichborneTrackerDB.rows = {}
            LichborneTrackerDB.raidRosters = {}
            LichborneTrackerDB.needs = {}
            LichborneTrackerDB.allGroups = {A={}, B={}, C={}}
            for _, g in ipairs({"A", "B", "C"}) do
                for i=1,60 do
                    LichborneTrackerDB.allGroups[g][i] = {name="",cls="",spec="",gs=0,realGs=0}
                end
            end
            LichborneTrackerDB.raidName = "Molten Core"
            LichborneTrackerDB.raidSize = 40
            LichborneTrackerDB.raidTier = 1
            LichborneTrackerDB.raidGroup = "A"
            LichborneOutput("|cffC69B3ALichborne:|r |cffff4444All data wiped.|r", 1, 0.5, 0.5)
            RefreshRows()
            if LichborneOverviewFrame then RefreshOverviewRows() end
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        end
    )

    -- Confirm: Clear all raid rosters only
    local confirmRaids = MakeDangerConfirm(
        "⚠  Wipe All Raid Rosters?",
        "This clears every raid roster (all tiers, raids,\nand groups A/B/C). Characters remain in class tabs.",
        function()
            LichborneTrackerDB.raidRosters = {}
            LichborneOutput("|cffC69B3ALichborne:|r |cffff9900All raid rosters cleared.|r", 1, 0.7, 0)
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        end
    )

    -- Clear Raids button (now on LEFT)
    local clrRaidsBtn = CreateFrame("Button", nil, f)
    clrRaidsBtn:SetSize(100, 20)
    clrRaidsBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -166, -8)
    clrRaidsBtn:SetFrameLevel(f:GetFrameLevel()+10)
    clrRaidsBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    clrRaidsBtn:SetBackdropColor(0.30,0.04,0.04,1); clrRaidsBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    clrRaidsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local clrRaidsLbl=clrRaidsBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); clrRaidsLbl:SetAllPoints(clrRaidsBtn); clrRaidsLbl:SetJustifyH("CENTER")
    clrRaidsLbl:SetText("|cffd4af37Clear Raids|r")
    clrRaidsBtn:SetScript("OnEnter",function()
        GameTooltip:SetOwner(clrRaidsBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Clear All Raid Rosters",1,0.5,0.5)
        GameTooltip:AddLine("Wipes every raid group across all tiers.",0.8,0.8,0.8)
        GameTooltip:AddLine("Character data is NOT affected.",0.6,0.8,0.6)
        GameTooltip:Show()
    end)
    clrRaidsBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    clrRaidsBtn:SetScript("OnClick",function() confirmRaids:Show() end)

    -- Clear All button
    local clrAllBtn = CreateFrame("Button", nil, f)
    clrAllBtn:SetSize(100, 20)
    clrAllBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -62, -8)
    clrAllBtn:SetFrameLevel(f:GetFrameLevel()+10)
    clrAllBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    clrAllBtn:SetBackdropColor(0.30,0.04,0.04,1); clrAllBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    clrAllBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local clrAllLbl=clrAllBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); clrAllLbl:SetAllPoints(clrAllBtn); clrAllLbl:SetJustifyH("CENTER")
    clrAllLbl:SetText("|cffd4af37Clear All Data|r")
    clrAllBtn:SetScript("OnEnter",function()
        GameTooltip:SetOwner(clrAllBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Wipe Entire Database",1,0.3,0.3)
        GameTooltip:AddLine("Permanently deletes ALL characters,",0.8,0.8,0.8)
        GameTooltip:AddLine("gear data, raid rosters, and the Overview list.",0.8,0.8,0.8)
        GameTooltip:AddLine("|cffff4444This cannot be undone.|r",1,0.4,0.4)
        GameTooltip:Show()
    end)
    clrAllBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    clrAllBtn:SetScript("OnClick",function() confirmAll:Show() end)
    DBG("|cff44ff44OnFirstShow complete|r rowFrames=|cffffff88"..#rowFrames.."|r raidRowFrames=|cffffff88"..#raidRowFrames.."|r overviewRowFrames=|cffffff88"..(overviewRowFrames and #overviewRowFrames or 0).."|r")
end

function LichborneTracker_Open()
    if not activeTab then activeTab = "Overview" end
    BuildFrameBG()
    OnFirstShow()
    LichborneTrackerFrame:Show()
    UpdateTabs()
    RefreshRows()
end

-- ── Minimap button (standalone – zero library dependency) ──────────────────
-- Built entirely with standard WoW frame API.  Position is saved in
-- LichborneMinimapIconDB.minimapPos (degrees, 0-360) and restored at login.
local minimapBtn = CreateFrame("Button", "LichborneMinimapButton", Minimap)
minimapBtn:SetWidth(31); minimapBtn:SetHeight(31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForClicks("anyUp")
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

do
    local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53); overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetWidth(20); bg:SetHeight(20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -5)
    minimapBtn.icon = icon
end

local function LichborneUpdateMinimapPos()
    local angle = math.rad(
        (LichborneMinimapIconDB and LichborneMinimapIconDB.minimapPos) or 225
    )
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * 80, math.sin(angle) * 80)
end

minimapBtn:SetScript("OnClick", function(self, btn)
    if LichborneTrackerFrame and LichborneTrackerFrame:IsShown() then
        LichborneTrackerFrame:Hide()
    else
        LichborneTracker_Open()
    end
end)

minimapBtn:SetScript("OnDragStart", function(self)
    self.icon:SetTexCoord(0, 1, 0, 1)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        if LichborneMinimapIconDB then
            LichborneMinimapIconDB.minimapPos =
                math.deg(math.atan2(py - my, px - mx)) % 360
        end
        LichborneUpdateMinimapPos()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
    self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffC69B3ALichborne Gear Tracker|r")
    GameTooltip:AddLine("Click to open / close", 1, 1, 1)
    GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

minimapBtn:Hide()  -- hidden until PLAYER_LOGIN positions it

-- ── Initialization ────────────────────────────────────────────
-- ESC key support: insert into UISpecialFrames at Lua load time so WoW hides the
-- frame when ESC is pressed (same pattern used by DBM).
table.insert(_G["UISpecialFrames"], "LichborneTrackerFrame")

do
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "LichborneTracker" then
            -- DB migration and roster repair run at ADDON_LOADED so SavedVars
            -- are available as early as possible.
            MigrateGearField()
            -- Restore filter toggle states from DB (SavedVars are live at ADDON_LOADED)
            if LichborneTrackerDB.showTierKey == nil then LichborneTrackerDB.showTierKey = true end
            LBFilter.showTierKey = LichborneTrackerDB.showTierKey
            if LichborneTrackerDB.showLevel == nil then LichborneTrackerDB.showLevel = false end
            LBFilter.showLevel = LichborneTrackerDB.showLevel
            -- Repair all raid rosters: fill any nil/missing slots
            if LichborneTrackerDB and LichborneTrackerDB.raidRosters then
                for key, roster in pairs(LichborneTrackerDB.raidRosters) do
                    if type(roster) == "table" then
                        for i = 1, MAX_RAID_SLOTS do
                            if not roster[i] or type(roster[i]) ~= "table" then
                                roster[i] = {name="",cls="",spec="",gs=0,realGs=0,role="",notes=""}
                            else
                                if roster[i].role == nil then roster[i].role = "" end
                                if roster[i].notes == nil then roster[i].notes = "" end
                                if roster[i].name == nil then roster[i].name = "" end
                                if roster[i].cls == nil then roster[i].cls = "" end
                                if roster[i].spec == nil then roster[i].spec = "" end
                                if roster[i].gs == nil then roster[i].gs = 0 end
                                if roster[i].realGs == nil then roster[i].realGs = 0 end
                            end
                        end
                    end
                end
            end
        elseif event == "PLAYER_LOGIN" then
            -- Position and show the minimap button now that SavedVars are loaded.
            self:UnregisterEvent("PLAYER_LOGIN")
            if type(LichborneMinimapIconDB) ~= "table" then
                LichborneMinimapIconDB = {}
            end
            if not LichborneMinimapIconDB.minimapPos then
                LichborneMinimapIconDB.minimapPos = 225
            end
            LichborneUpdateMinimapPos()
            if not LichborneMinimapIconDB.hide then
                minimapBtn:Show()
            end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- An item just entered the client cache; re-color any visible gear boxes
            -- whose link now resolves. This fixes imported data where GetItemInfo
            -- returned nil at display time because the item wasn't cached yet.
            for _, row in ipairs(rowFrames) do
                if row:IsShown() and row.dbIndex and row.gearBoxes then
                    local data = LichborneTrackerDB.rows[row.dbIndex]
                    if data and data.ilvlLink then
                        for g = 1, GEAR_SLOTS do
                            local gb = row.gearBoxes[g]
                            if gb then
                                local link = data.ilvlLink[g]
                                local qc = GetItemQualityColor(link)
                                if qc then
                                    gb:SetTextColor(qc.r, qc.g, qc.b)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    initFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

-- ── Spec / Talent handler ─────────────────────────────────────
LichborneSpecTarget = nil
local specRetries = 0
local MAX_SPEC_RETRIES = 6
local lastCalcSpecDi = nil  -- tracks last di so retry counter resets on new player

local function CalcSpec()
    local di = LichborneSpecTarget
    if not di then return end
    -- Reset retry counter when starting a new player (handles 25s cap forced advance)
    if di ~= lastCalcSpecDi then
        specRetries = 0
        lastCalcSpecDi = di
    end
    local rowData = LichborneTrackerDB.rows[di]
    if not rowData then LichborneSpecTarget = nil; specRetries = 0; return end

    local cls = rowData.cls or ""
    local specNames = CLASS_SPECS[cls]
    DBG("CalcSpec start: |cffffff88"..(rowData.name or "?").."|r cls=|cffffff88"..cls.."|r unit=|cffffff88"..(LichborneInspectUnit or "?").."|r UnitExists=|cffffff88"..tostring(UnitExists(LichborneInspectUnit or "target")).."|r")
    local specStartTime = GetTime()  -- DBG: timing
    if not specNames then
        LichborneOutput("|cffC69B3ALichborne:|r Unknown class: "..cls, 1, 0.5, 0.5)
        LichborneSpecTarget = nil; specRetries = 0
        return
    end

    -- WotLK 3.3.5a: pass inspect=true to read target's talents
    local inspectSelf = (LichborneInspectUnit and UnitIsUnit(LichborneInspectUnit, "player"))
    local inspFlag = inspectSelf and false or true
    local activeGroup = (GetActiveTalentGroup and GetActiveTalentGroup(inspFlag)) or 1
    local treePts = {0, 0, 0}
    for tab = 1, 3 do
        local numTalents = GetNumTalents(tab, inspFlag)
        if numTalents and numTalents > 0 then
            for t = 1, numTalents do
                local name, _, _, _, currRank = GetTalentInfo(tab, t, inspFlag, false, activeGroup)
                if currRank and currRank > 0 then
                    treePts[tab] = treePts[tab] + currRank
                end
            end
        end
    end

    -- Try the direct tab points API
    local tabPts = {0, 0, 0}
    local gotTabData = false
    for tab = 1, 3 do
        local tabName, _, pts = GetTalentTabInfo(tab, inspFlag, false, activeGroup)
        if pts == nil then DBG("|cffff4444[NIL]|r GetTalentTabInfo(tab="..tab..") pts=nil (tabName=|cffffff88"..(tabName or "nil").."|r)") end
        if pts and pts > 0 then
            tabPts[tab] = pts
            gotTabData = true
        end
    end
    -- Prefer tabPts if available, else fall back to treePts
    local pts = gotTabData and tabPts or treePts

    DBG("Talent pts (tree/tab): T1=|cffffff88"..pts[1].."|r T2=|cffffff88"..pts[2].."|r T3=|cffffff88"..pts[3].."|r (gotTabData=|cffffff88"..tostring(gotTabData).."|r)")
    local treeNames = specNames and {specNames[1] or "?", specNames[2] or "?", specNames[3] or "?"} or {"?","?","?"}
    DBG("Trees: T1=|cffffff88"..treeNames[1].."|r("..pts[1].."pts) T2=|cffffff88"..treeNames[2].."|r("..pts[2].."pts) T3=|cffffff88"..treeNames[3].."|r("..pts[3].."pts)")

    local best, bestPoints = 1, 0
    for tab = 1, 3 do
        if pts[tab] > bestPoints then
            bestPoints = pts[tab]
            best = tab
        end
    end

    if bestPoints == 0 then
        specRetries = specRetries + 1
        local maxSpecRetries = LichborneGroupScanActive and 1 or 0
        DBG("|cffff4444Spec talent data = 0/0/0 for |r|cffffff88"..(rowData.name or "?").."|r — retry "..specRetries.."/"..maxSpecRetries)
        if specRetries >= maxSpecRetries then
            DBG("|cffff4444FAILED spec for |r|cffffff88"..(rowData.name or "?").."|r — all trees 0 after "..maxSpecRetries.." retries")
            LichborneOutput("|cffff4444"..(rowData.name or "?")..":|r |cffff4444FAILED — could not read talent data.|r", 1, 0.5, 0.5)
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cffff4444Talent data unavailable. Try standing closer.|r")
            end
            LichborneSpecTarget = nil; specRetries = 0
        end
        return
    end

    specRetries = 0
    local specName = specNames[best] or ""
    local prevSpec = rowData.spec or ""
    rowData.spec = specName
    DBG("DB write spec |cffffff88"..(rowData.name or "?").."|r: "..(prevSpec~=specName and "|cffff9900"..prevSpec.."|r->|cff44ff44"..specName.."|r" or "|cffaaaaaa"..specName.."|r (unchanged)"))

    local c = CLASS_COLORS[cls]
    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
    if LichborneAddStatus then
        LichborneAddStatus:SetText(hex..(rowData.name or "?").."|r — Specialization: |cffffff00"..specName.."|r ("..bestPoints.." pts)")
    end
    LichborneOutput(hex..(rowData.name or "?").."|r: |cffffff00"..specName.."|r ("..bestPoints.." pts)", 1, 0.85, 0)
    DBG("|cff44ff44SUCCESS|r spec |cffffff88"..(rowData.name or "?").."|r = |cffffff00"..specName.."|r tree"..best.." ("..bestPoints.." pts)")
    DBG("CalcSpec elapsed: |cffffff88"..string.format("%.3f", GetTime()-specStartTime).."s|r")

    ClearInspectPlayer()
    LichborneSpecTarget = nil
    RefreshRows()
end

local specWait = 0
local specFrame = CreateFrame("Frame")
specFrame:SetScript("OnUpdate", function(_, elapsed)
    if not LichborneSpecTarget then return end
    specWait = specWait + elapsed
    if specWait >= 3.0 then
        specWait = 0
        CalcSpec()
    end
end)
specFrame:RegisterEvent("INSPECT_READY")
specFrame:SetScript("OnEvent", function(_, event, guid)
    if not LichborneSpecTarget then return end
    local guidInfo = guid and ("|cffffff88"..guid.."|r") or "|cff888888(no GUID)|r"
    if guid and LichborneSpecGUID and guid ~= LichborneSpecGUID then
        DBG("|cffff4444GUID MISMATCH (Spec)|r got "..guidInfo.." expected |cffffff88"..LichborneSpecGUID.."|r for |cffffff88"..(LichborneTrackerDB.rows[LichborneSpecTarget] and LichborneTrackerDB.rows[LichborneSpecTarget].name or "?").."|r")
    else
        DBG("INSPECT_READY (Spec) for |cffffff88"..(LichborneTrackerDB.rows[LichborneSpecTarget] and LichborneTrackerDB.rows[LichborneSpecTarget].name or "?").."|r GUID="..guidInfo)
    end
    specWait = 0
    CalcSpec()
end)

-- ── Inspect handler ───────────────────────────────────────────
LichborneInspectTarget = nil
LichborneInspectRow = nil
LichborneInspectUnit = "target"  -- unit token for current inspect
local LichborneInspectRetries = 0  -- retry counter for empty gear data
local INSPECT_MAX_RETRIES = 6      -- max retries before giving up (uses < check)
local LichborneCacheRetries = 0    -- retry counter for uncached item data
local CACHE_MAX_RETRIES = 6        -- max cache retries before accepting partial data (uses < check)
-- inspectWait declared at module top (shared with button callbacks in OnFirstShow)
local lastCalcGsDi = nil  -- tracks last di so retry counters reset on new player

local function CalcGS()
    local di = LichborneInspectTarget
    if not di then return end
    -- Reset retry counters when starting a new player (handles 25s cap forced advance)
    if di ~= lastCalcGsDi then
        LichborneInspectRetries = 0
        LichborneCacheRetries = 0
        lastCalcGsDi = di
    end
    local inspUnit = LichborneInspectUnit or "target"
    local rowName = (LichborneTrackerDB.rows[di] and LichborneTrackerDB.rows[di].name) or "?"
    if not LichborneTrackerDB.rows[di] then
        DBG("|cffff4444[NIL]|r LichborneTrackerDB.rows["..tostring(di).."] is nil mid-scan - aborting CalcGS")
        LichborneInspectTarget = nil; return
    end
    local slots = {1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17,18}
    local total, count = 0, 0

    DBG("CalcGS start: |cffffff88"..rowName.."|r unit=|cffffff88"..inspUnit.."|r UnitExists=|cffffff88"..tostring(UnitExists(inspUnit)).."|r")
    local gsStartTime = GetTime()  -- DBG: timing

    if not LichborneTrackerDB.rows[di].ilvl then
        local g = {}
        for i = 1, 17 do g[i] = 0 end
        LichborneTrackerDB.rows[di].ilvl = g
    end
    if not LichborneTrackerDB.rows[di].ilvlLink then
        local lnk = {}
        for i = 1, 17 do lnk[i] = "" end
        LichborneTrackerDB.rows[di].ilvlLink = lnk
    end

    local anyPending = false
    local linkCount, cachedCount, uncachedCount, emptyCount, zeroIlvlCount = 0, 0, 0, 0, 0
    local slotDiag = {}  -- per-slot diagnostic strings; logged only on failure

    -- Check if MH is a 2H weapon so we can blank OH instead of duplicating it
    local mhLink = GetInventoryItemLink(inspUnit, 16)
    local mhIs2H = false
    if mhLink then
        local _, _, _, _, _, _, _, _, mhEquipLoc = GetItemInfo(mhLink)
        if mhEquipLoc == "INVTYPE_2HWEAPON" then
            mhIs2H = true
        end
    end

    for g, slot in ipairs(slots) do
        -- slot 17 = OH; if MH is 2H, WoW mirrors the same link into slot 17 — blank it out
        if slot == 17 and mhIs2H then
            LichborneTrackerDB.rows[di].ilvl[g] = 0
            LichborneTrackerDB.rows[di].ilvlLink[g] = ""
            slotDiag[g] = string.format("%-5s", SLOT_ABBR[g]).."(s17)=|cff888888[2H-OH]|r"
        else
            local link = GetInventoryItemLink(inspUnit, slot)
            if link then
                linkCount = linkCount + 1
                local itemName, _, itemQuality, itemIlvl = GetItemInfo(link)
                if itemIlvl and itemIlvl > 0 then
                    cachedCount = cachedCount + 1
                    total = total + itemIlvl
                    count = count + 1
                    LichborneTrackerDB.rows[di].ilvl[g] = itemIlvl
                    LichborneTrackerDB.rows[di].ilvlLink[g] = link
                    slotDiag[g] = string.format("%-5s", SLOT_ABBR[g]).."(s"..slot..")=|cff44ff44"..itemIlvl.."|r"
                else
                    LichborneTrackerDB.rows[di].ilvl[g] = 0
                    LichborneTrackerDB.rows[di].ilvlLink[g] = link
                    if itemName then
                        -- Link cached but iLvl=0 (PvP trinket, quest item, relic, etc.)
                        -- itemName returned means the item IS cached — iLvl is just 0.
                        -- Do NOT set anyPending; retrying will never change a 0-iLvl item.
                        zeroIlvlCount = zeroIlvlCount + 1
                        slotDiag[g] = string.format("%-5s", SLOT_ABBR[g]).."(s"..slot..")=|cffffff00iLvl0|r("..itemName..(itemQuality and " q"..itemQuality or "")..")"
                    else
                        -- GetItemInfo returned nil - item not in client cache yet; request it
                        GetItemInfo(link)  -- trigger cache load
                        anyPending = true
                        uncachedCount = uncachedCount + 1
                        slotDiag[g] = string.format("%-5s", SLOT_ABBR[g]).."(s"..slot..")=|cffff9900uncached|r"
                    end
                end
            else
                emptyCount = emptyCount + 1
                LichborneTrackerDB.rows[di].ilvl[g] = 0
                LichborneTrackerDB.rows[di].ilvlLink[g] = ""
                slotDiag[g] = string.format("%-5s", SLOT_ABBR[g]).."(s"..slot..")=|cff555555NIL|r"
            end
        end
    end

    DBG("Slots: |cff44ff44"..linkCount.." links|r (cached="..cachedCount.." uncached="..uncachedCount.." iLvl0="..zeroIlvlCount..") nil-link=|cffff4444"..emptyCount.."|r")
    if anyPending then
        LichborneCacheRetries = LichborneCacheRetries + 1
        DBG("|cffffff88"..rowName.."|r: "..uncachedCount.." items uncached - cache retry "..LichborneCacheRetries.."/"..CACHE_MAX_RETRIES)
        if LichborneCacheRetries < CACHE_MAX_RETRIES then
            inspectWait = 0  -- reset so OnUpdate waits another full interval before next attempt
            return
        end
        -- Exhausted cache retries — proceed with whatever data we have
        DBG("|cffff4444Cache retries exhausted for |r|cffffff88"..rowName.."|r — proceeding with "..cachedCount.." cached slots")
        if LichborneAddStatus then
            LichborneAddStatus:SetText("|cffff4444Some items not cached — using available data.|r")
        end
        LichborneCacheRetries = 0
    end

    for _, row in ipairs(rowFrames) do
        if row.dbIndex == di and row.gearBoxes then
            for g = 1, 17 do
                local v = LichborneTrackerDB.rows[di].ilvl[g] or 0
                if row.gearBoxes[g] then
                    local link2 = LichborneTrackerDB.rows[di].ilvlLink and LichborneTrackerDB.rows[di].ilvlLink[g]
                    -- Show 0 when item exists but has iLvl=0 (PvP trinket, relic, etc.)
                    row.gearBoxes[g]:SetText((v > 0 or (link2 and link2 ~= "")) and tostring(v) or "")
                    -- Apply item quality color
                    local qc2 = GetItemQualityColor(link2)
                    if qc2 then
                        row.gearBoxes[g]:SetTextColor(qc2.r, qc2.g, qc2.b)
                    else
                        row.gearBoxes[g]:SetTextColor(1, 1, 1)
                    end
                end
            end
            break
        end
    end

    if count > 0 then
        local rowData = LichborneTrackerDB.rows[di]
        local ilvl = math.floor(total / count)
        local realGs = CalculateUnitGearScore(inspUnit)

        local prevGS     = rowData.gs or 0
        local prevRealGS = rowData.realGs or 0
        rowData.gs = ilvl
        rowData.realGs = realGs
        DBG("DB write |cffffff88"..rowName.."|r: iLvl "..(prevGS~=ilvl and "|cffff9900"..prevGS.."|r->".."|cff44ff44"..ilvl.."|r" or "|cffaaaaaa"..ilvl.."|r").." GS "..(prevRealGS~=realGs and "|cffff9900"..prevRealGS.."|r->".."|cff44ff44"..realGs.."|r" or "|cffaaaaaa"..realGs.."|r"))

        for _, row in ipairs(rowFrames) do
            if row.dbIndex == di then
                if row.gsBox then row.gsBox:SetText(tostring(ilvl)) end
                if row.realGsBox then row.realGsBox:SetText(realGs > 0 and tostring(realGs) or "") end
                break
            end
        end

        local updatedName = rowData.name
        if updatedName and updatedName ~= "" and LichborneTrackerDB.raidRosters then
            for _, roster in pairs(LichborneTrackerDB.raidRosters) do
                for _, slot in ipairs(roster) do
                    if slot.name and slot.name:lower() == updatedName:lower() then
                        slot.gs = ilvl
                        slot.realGs = realGs
                    end
                end
            end
        end

        local name = rowData.name or "?"
        local cls = rowData.cls or "?"
        local c = CLASS_COLORS[cls]
        local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or "|cffffffff"
        if LichborneAddStatus then
            LichborneAddStatus:SetText(hex..name.."|r ("..cls..") - iLvl |cffffff00"..ilvl.."|r, GS |cffffff00"..realGs.."|r added!")
        end
        LichborneOutput(hex..name.."|r: iLvl |cffffff00"..ilvl.."|r  GS |cffffff00"..realGs.."|r ("..count.." slots)", 1, 0.85, 0)
        DBG("|cff44ff44SUCCESS|r |cffffff88"..rowName.."|r iLvl="..ilvl.." GS="..realGs.." slots="..count)

        local targetName = UnitName("target")
        if targetName and targetName == UnitName("player") then
            local specNames = CLASS_SPECS[rowData.cls or ""]
            if specNames then
                local bestTab, bestPoints = 1, 0
                for tab = 1, 3 do
                    local _, _, pts = GetTalentTabInfo(tab)
                    if pts and pts > bestPoints then
                        bestPoints = pts
                        bestTab = tab
                    end
                end
                if bestPoints > 0 then
                    rowData.spec = specNames[bestTab] or rowData.spec
                    LichborneOutput(hex..name.."|r: |cffffff00"..specNames[bestTab].."|r ("..bestPoints.." pts)", 1, 0.85, 0)
                end
            end
        end

        RefreshRows()
        if overviewRowFrames and #overviewRowFrames > 0 then RefreshOverviewRows() end
        if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        LichborneInspectRetries = 0  -- reset retry counter on success
    else
        -- No slots came back — inspect data not ready yet.
        LichborneInspectRetries = LichborneInspectRetries + 1
        local unit = LichborneInspectUnit or "target"
        local unitExists = UnitExists(unit)
        local maxGsRetries = LichborneGroupScanActive and 1 or 0
        DBG("|cffff4444No slot data for |r|cffffff88"..rowName.."|r — retry "..LichborneInspectRetries.."/"..maxGsRetries.." UnitExists=|cffffff88"..tostring(unitExists).."|r links="..linkCount)
        if LichborneInspectRetries < maxGsRetries then
            if unitExists then
                InspectUnit(unit)
                DBG("Re-fired InspectUnit("..unit..") for |cffffff88"..rowName.."|r")
            else
                DBG("|cffff4444UnitExists("..unit..") = false — cannot re-fire InspectUnit|r")
            end
            inspectWait = 0  -- reset timer for next attempt
            return  -- do NOT clear LichborneInspectTarget — keep retrying
        end
        -- Exhausted retries
        DBG("|cffff4444FAILED |r|cffffff88"..rowName.."|r — exhausted "..INSPECT_MAX_RETRIES.." retries, 0 slots. UnitExists="..tostring(unitExists).." links="..linkCount)
        DBG("|cffff4444FAIL breakdown:|r cached="..cachedCount.." uncached="..uncachedCount.." iLvl0="..zeroIlvlCount.." nil-link=|cffff4444"..emptyCount.."|r total-links="..linkCount)
        if LichborneDebugMode then
            for g2 = 1, #slots do
                if slotDiag[g2] then DBG("  "..slotDiag[g2]) end
            end
        end
        if LichborneAddStatus then
            LichborneAddStatus:SetText("|cffff4444No gear data returned. Target may be out of range.|r")
        end
        LichborneOutput("|cffff4444"..rowName..":|r |cffff4444FAILED — no gear data returned.|r", 1, 0.5, 0)
    end

    DBG("CalcGS elapsed: |cffffff88"..string.format("%.3f", GetTime()-gsStartTime).."s|r")
    LichborneInspectRetries = 0  -- reset for next inspect
    LichborneCacheRetries = 0     -- reset cache retry counter
    ClearInspectPlayer()
    LichborneInspectTarget = nil
    LichborneInspectRow = nil
end

local inspectFrame = CreateFrame("Frame")
-- inspectWait declared above CalcGS so the reset inside CalcGS targets the same local
inspectFrame:SetScript("OnUpdate", function(_, elapsed)
    if not LichborneInspectTarget then return end
    inspectWait = inspectWait + elapsed
    if inspectWait >= 3.0 then
        inspectWait = 0
        local di = LichborneInspectTarget
        DBG("Timer fallback → CalcGS for |cffffff88"..(LichborneTrackerDB.rows[di] and LichborneTrackerDB.rows[di].name or "?").."|r (no INSPECT_READY in 3.0s)")
        CalcGS()
    end
end)

-- Also try INSPECT_READY in case server supports it
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(_, event, guid)
    if not LichborneInspectTarget then return end
    local di = LichborneInspectTarget
    local guidInfo = guid and ("|cffffff88"..guid.."|r") or "|cff888888(no GUID)|r"
    if guid and LichborneInspectGUID and guid ~= LichborneInspectGUID then
        DBG("|cffff4444GUID MISMATCH (GS)|r got "..guidInfo.." expected |cffffff88"..LichborneInspectGUID.."|r for |cffffff88"..(LichborneTrackerDB.rows[di] and LichborneTrackerDB.rows[di].name or "?").."|r")
    else
        DBG("INSPECT_READY (GS) for |cffffff88"..(LichborneTrackerDB.rows[di] and LichborneTrackerDB.rows[di].name or "?").."|r GUID="..guidInfo)
    end
    inspectWait = 0
    LichborneInspectRetries = 0  -- fresh INSPECT_READY means fresh data incoming
    CalcGS()
end)


-- ── Drag-to-reorder poller ────────────────────────────────────
-- Polls every frame while dragging; detects mouse release and
-- finds which row the cursor is over using GetCursorPosition.
local dragPollFrame = CreateFrame("Frame")
dragPollFrame:SetScript("OnUpdate", function()
    if not dragSourceRow then return end

    -- Detect mouse button released
    if not IsMouseButtonDown("LeftButton") then
        -- Find which rowFrame the cursor is currently over
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx = cx / scale
        cy = cy / scale

        local targetRow = nil
        for _, rf in ipairs(rowFrames) do
            if rf:IsShown() and rf ~= dragSourceRow and rf.dbIndex then
                local data = LichborneTrackerDB.rows[rf.dbIndex]
                if data and data.name and data.name ~= "" then
                    local left   = rf:GetLeft()
                    local right  = rf:GetRight()
                    local bottom = rf:GetBottom()
                    local top    = rf:GetTop()
                    if left and right and bottom and top then
                        if cx >= left and cx <= right and cy >= bottom and cy <= top then
                            targetRow = rf
                            break
                        end
                    end
                end
            end
        end

        -- Perform insert if we found a valid target
        if targetRow then
            local a = dragSourceRow.dbIndex
            local b = targetRow.dbIndex
            if a and b and a ~= b then
                local rows = LichborneTrackerDB.rows
                local item = rows[a]
                table.remove(rows, a)
                local insertAt = b > a and b - 1 or b
                table.insert(rows, insertAt, item)
                classSortKey[activeTab] = nil   -- clear sort so drag order sticks
                RefreshRows()
            end
        end

        -- Reset all visual state
        for _, rf in ipairs(rowFrames) do
            rf.hov:SetTexture(0, 0, 0, 0)
            rf.dropHi:SetTexture(0, 0, 0, 0)
            if rf.dragLbl and rf.dbIndex then
                local data = LichborneTrackerDB.rows[rf.dbIndex]
                local cls = data and data.cls
                local cc = cls and CLASS_COLORS[cls]
                rf.dragLbl:SetTextColor(0.4, 0.4, 0.5, 1.0)
            end
        end
        dragSourceRow = nil
        return
    end

    -- Still dragging — highlight whichever row cursor is over
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale

    for _, rf in ipairs(rowFrames) do
        if rf:IsShown() and rf ~= dragSourceRow then
            local left   = rf:GetLeft()
            local right  = rf:GetRight()
            local bottom = rf:GetBottom()
            local top    = rf:GetTop()
            if left and right and bottom and top then
                if cx >= left and cx <= right and cy >= bottom and cy <= top then
                    rf.dropHi:SetTexture(0.9, 0.7, 0.1, 0.20)
                else
                    rf.dropHi:SetTexture(0, 0, 0, 0)
                end
            end
        end
    end
end)
SLASH_LICHBORNE1 = "/lichborne"
SLASH_LICHBORNE2 = "/lbt"
SlashCmdList["LICHBORNE"] = function(msg)
    if LichborneTrackerFrame and LichborneTrackerFrame:IsShown() then
        LichborneTrackerFrame:Hide()
    else
        LichborneTracker_Open()
    end
end

