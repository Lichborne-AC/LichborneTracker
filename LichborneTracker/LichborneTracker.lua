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
if not LichborneTrackerDB.raidName then LichborneTrackerDB.raidName = "Molten Core" end
if not LichborneTrackerDB.raidSize then LichborneTrackerDB.raidSize = 40 end
if not LichborneTrackerDB.raidGroup then LichborneTrackerDB.raidGroup = "A" end
if not LichborneTrackerDB.allGroups then
    LichborneTrackerDB.allGroups = {}
    for _, g in ipairs({"A","B","C"}) do
        LichborneTrackerDB.allGroups[g] = {}
        for i = 1, 60 do LichborneTrackerDB.allGroups[g][i] = {name="",cls="",spec="",gs=0} end
    end
end
if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
-- Legacy migration
if LichborneTrackerDB.allRows then
    if not LichborneTrackerDB.allGroups then LichborneTrackerDB.allGroups = {A={},B={},C={}} end
    for i,v in ipairs(LichborneTrackerDB.allRows) do
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
        for i = 1, 60 do LichborneTrackerDB.allGroups[g][i] = {name="",cls="",spec="",gs=0} end
    end
end
if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
-- Legacy migration
if LichborneTrackerDB.allRows then
    if not LichborneTrackerDB.allGroups then LichborneTrackerDB.allGroups = {A={},B={},C={}} end
    for i,v in ipairs(LichborneTrackerDB.allRows) do
        LichborneTrackerDB.allGroups["A"][i] = v
    end
    LichborneTrackerDB.allRows = nil
end
    local name = LichborneTrackerDB.raidName
    local size = LichborneTrackerDB.raidSize
    local group = LichborneTrackerDB.raidGroup
    local key = name .. "_" .. group   -- e.g. "Karazhan_A"
    if not LichborneTrackerDB.raidRosters[key] then
        LichborneTrackerDB.raidRosters[key] = {}
        for i = 1, 40 do
            LichborneTrackerDB.raidRosters[key][i] = {name="", cls="", spec="", gs=0, role="", notes=""}
        end
    end
    local roster = LichborneTrackerDB.raidRosters[key]
    for i = 1, 40 do
        if not roster[i] then roster[i] = {name="", cls="", spec="", gs=0, role="", notes=""} end
    end
    return roster, size
end

local ROW_HEIGHT  = 24
local GEAR_SLOTS  = 17
local MAX_ROWS    = 18  -- visible rows per class tab
local ROWS_PER_PAGE = 18
local MAX_PAGES   = 3
local SLOT_ABBR   = {"Head","Neck","Shldr","Back","Chest","Wrsts","Hands","Waist","Legs","Feet","Ring1","Ring2","Trnk1","Trnk2","MH","OH","Rngd"}

local COL_NAME_W  = 140
local COL_GS_W    = 42
local COL_GEAR_W  = 42
local NAME_OFF    = 4
local GS_OFF      = NAME_OFF + COL_NAME_W + 2
local GEAR_OFF    = GS_OFF + COL_GS_W + 4
local COL_TIER_W  = 42
local TIER_OFF    = GEAR_OFF + GEAR_SLOTS * COL_GEAR_W + 4

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
local CLASS_TABS = {"Death Knight","Druid","Hunter","Mage","Paladin","Priest","Rogue","Shaman","Warlock","Warrior","Raid","All"}
local TAB_LABELS = {["Death Knight"]="DK",["Druid"]="Druid",["Hunter"]="Hunter",["Mage"]="Mage",["Paladin"]="Paladin",["Priest"]="Priest",["Rogue"]="Rogue",["Shaman"]="Shaman",["Warlock"]="Warlock",["Warrior"]="Warrior",["Raid"]="Raid",["All"]="All"}

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



local ROLE_DEFS = {
    {key="TNK", label="Tank",   color={r=0.20,g=0.60,b=1.00}, icon="Interface\\Icons\\Ability_Warrior_DefensiveStance"},
    {key="HLR", label="Healer", color={r=0.20,g=1.00,b=0.40}, icon="Interface\\Icons\\Spell_ChargePositive"},
    {key="DPS", label="DPS",    color={r=1.00,g=0.40,b=0.20}, icon="Interface\\Icons\\Ability_DualWield"},
}
local ROLE_BY_KEY = {}
for _, rd in ipairs(ROLE_DEFS) do ROLE_BY_KEY[rd.key] = rd end

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

activeTab = "All"
local classPage = {}   -- classPage[cls] = current page (1-3)
local allPage = 1      -- current page for All tab
local tabButtons = {}
local rowFrames = {}      -- rowFrames[i] = row frame for slot i
local raidRowFrames = {}  -- raid tab row frames (40 slots)
local raidDragPoll = CreateFrame("Frame")  -- module-level so it persists
local raidMouseHeld = false
local allRowFrames = {}   -- all tab row frames (60 slots)
-- Raid drag state (module-level so RefreshRaidRows can reset)
local raidDragSource = nil
local raidDragOver   = nil
LichborneAllCountLabels = nil
local allFrameBuilt = false
local LichborneAllFrame = nil
RefreshAllRows = nil  -- will be set after definition
local raidFrameBuilt = false
local setupDone = false
local dragSourceRow = nil   -- row frame being dragged
local dragOverTarget = nil  -- row frame mouse is currently over
local dragOverlay = nil     -- visual drag indicator

-- ── DB helpers ────────────────────────────────────────────────
local function DefaultRow(cls)
    local g = {}
    for i = 1, GEAR_SLOTS do g[i] = 0 end
    return {cls = cls or "", name = "", gear = g, gs = 0, spec = ""}
end

local function EnsureClass(cls)
    if cls == "Raid" or cls == "All" then return end
    -- Ensure we have MAX_ROWS * MAX_PAGES rows for this class (3 pages)
    local count = 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then count = count + 1 end
    end
    while count < MAX_ROWS * MAX_PAGES do
        table.insert(LichborneTrackerDB.rows, DefaultRow(cls))
        count = count + 1
    end
end

local function GetAllClassRows(cls)
    -- Returns ALL row indices for a class regardless of page (for add/search ops)
    local out = {}
    if cls == "Raid" or cls == "All" then return out end
    for i, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then out[#out+1] = i end
    end
    return out
end

local classSortMode = nil  -- nil, "classspec", "gs", "tier"

local function GetClassRows(cls)
    local out = {}
    if cls == "Raid" or cls == "All" then return out end
    local page = classPage[cls] or 1
    local startIdx = (page - 1) * ROWS_PER_PAGE + 1
    local endIdx   = page * ROWS_PER_PAGE
    local count = 0
    -- Collect all matching indices for this class
    local allIdx = {}
    for i, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls then
            allIdx[#allIdx+1] = i
        end
    end
    -- Apply sort if active
    if classSortMode == "name" then
        table.sort(allIdx, function(a, b)
            local ra, rb = LichborneTrackerDB.rows[a], LichborneTrackerDB.rows[b]
            local na, nb = ra.name or "", rb.name or ""
            if (na == "") ~= (nb == "") then return na ~= "" end
            return na < nb
        end)
    elseif classSortMode == "classspec" then
        table.sort(allIdx, function(a, b)
            local ra, rb = LichborneTrackerDB.rows[a], LichborneTrackerDB.rows[b]
            local na, nb = ra.name or "", rb.name or ""
            -- Empty rows always go to the bottom
            if (na == "") ~= (nb == "") then return na ~= "" end
            local sa, sb = ra.spec or "", rb.spec or ""
            if sa ~= sb then return sa < sb end
            return na < nb
        end)
    elseif classSortMode == "gs" then
        table.sort(allIdx, function(a, b)
            local ra, rb = LichborneTrackerDB.rows[a], LichborneTrackerDB.rows[b]
            local na, nb = ra.name or "", rb.name or ""
            if (na == "") ~= (nb == "") then return na ~= "" end
            local ga, gb2 = ra.gs or 0, rb.gs or 0
            if ga ~= gb2 then return ga > gb2 end
            return na < nb
        end)
    end
    -- Page slice
    for _, i in ipairs(allIdx) do
        count = count + 1
        if count >= startIdx and count <= endIdx then
            out[#out+1] = i
        end
    end
    return out
end

-- ── Tier color ────────────────────────────────────────────────
local function ApplyTierColor(gb, val)
    local n = tonumber(val) or 0
    local c = TIER_COLORS[n]
    if c then
        gb:SetBackdropColor(c.r, c.g, c.b, 1)
        gb:SetBackdropBorderColor(math.min(c.r*1.5,1), math.min(c.g*1.5,1), math.min(c.b*1.5,1), 1)
        if (0.299*c.r + 0.587*c.g + 0.114*c.b) > 0.45 then
            gb:SetTextColor(0.05, 0.05, 0.05)
        else
            gb:SetTextColor(1, 1, 1)
        end
    else
        gb:SetBackdropColor(0.05, 0.07, 0.14, 1)
        gb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
        gb:SetTextColor(1, 1, 1)
    end
end

-- ── Tab highlight ─────────────────────────────────────────────
local allSortMenus = {}
local function CloseAllSortMenus()
    for _, m in ipairs(allSortMenus) do m:Hide() end
end

local function UpdateTabs()
    if LichborneSpecMenu then LichborneSpecMenu:Hide() end
    if _G["LichbornePageDDMenu"] then _G["LichbornePageDDMenu"]:Hide() end
    CloseAllSortMenus()
    if _G["LichborneAllGroupMenu"] then _G["LichborneAllGroupMenu"]:Hide() end
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
                btn.bg:SetTexture(0.55, 0.40, 0.05, 1)
                btn.bottomLine:SetTexture(0.78, 0.61, 0.23, 1)
            elseif cls == "All" then
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
        local isAll = activeTab == "All"
        if isAll then
            if LichborneAllFrame then LichborneAllFrame:Show() end
            if LichborneRaidFrame then LichborneRaidFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Hide() end
            if LichborneAvgBar then LichborneAvgBar:Hide() end
            if LichborneCountBar then LichborneCountBar:Hide() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Hide() end
            for _, rf in ipairs(rowFrames) do rf:Hide() end
            -- Show invite buttons on All tab too
            local t = LichborneTrackerDB.raidTier or 0
            if LichborneInviteRaidBtn then
                if t == 0 then LichborneInviteRaidBtn:Hide() else LichborneInviteRaidBtn:Show() end
            end
            if _G["LichborneInviteGroupBtn"] then
                if t == 0 then _G["LichborneInviteGroupBtn"]:Show() else _G["LichborneInviteGroupBtn"]:Hide() end
            end
            if _G["LichborneStopInviteBtn"] then _G["LichborneStopInviteBtn"]:Show() end
        elseif isRaid then
            LichborneRaidFrame:Show()
            if LichborneAllFrame then LichborneAllFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Hide() end
            if LichborneAvgBar then LichborneAvgBar:Hide() end
            if LichborneCountBar then LichborneCountBar:Hide() end
            for _, rf in ipairs(rowFrames) do rf:Hide() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Show() end
            -- Show Invite Raid or Invite Group depending on T0
            local t = LichborneTrackerDB.raidTier or 0
            if LichborneInviteRaidBtn then
                if t == 0 then LichborneInviteRaidBtn:Hide() else LichborneInviteRaidBtn:Show() end
            end
            if _G["LichborneInviteGroupBtn"] then
                if t == 0 then _G["LichborneInviteGroupBtn"]:Show() else _G["LichborneInviteGroupBtn"]:Hide() end
            end
            if _G["LichborneStopInviteBtn"] then
                if t == 0 then _G["LichborneStopInviteBtn"]:Show() else _G["LichborneStopInviteBtn"]:Show() end
            end
        elseif not isAll then
            LichborneRaidFrame:Hide()
            if LichborneAllFrame then LichborneAllFrame:Hide() end
            if LichborneHeaderBar then LichborneHeaderBar:Show() end
            if LichborneAvgBar then LichborneAvgBar:Show() end
            if LichborneCountBar then LichborneCountBar:Show() end
            if _G["LichborneRaidCountBar"] then _G["LichborneRaidCountBar"]:Hide() end
            -- Show invite buttons on class tabs too
            local t = LichborneTrackerDB.raidTier or 0
            if LichborneInviteRaidBtn then
                if t == 0 then LichborneInviteRaidBtn:Hide() else LichborneInviteRaidBtn:Show() end
            end
            if _G["LichborneInviteGroupBtn"] then
                if t == 0 then _G["LichborneInviteGroupBtn"]:Show() else _G["LichborneInviteGroupBtn"]:Hide() end
            end
            if _G["LichborneStopInviteBtn"] then _G["LichborneStopInviteBtn"]:Show() end
        end
    end
end

-- ── Build row frames (once) ───────────────────────────────────
local function BuildRows(parent, yStart)
    if #rowFrames > 0 then return end  -- already built

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "LichborneRow"..i, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yStart - (i-1)*ROW_HEIGHT)
        row:SetSize(1010, ROW_HEIGHT)

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
                row.hov:SetTexture(0.3, 0.5, 0.9, 0.06)
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
        dragTex:SetVertexColor(0.3, 0.4, 0.6, 0.8)
        row.dragTex = dragTex
        local dragLbl = dragBtn:CreateFontString(nil, "OVERLAY")
        dragLbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        dragLbl:SetAllPoints(dragBtn)
        dragLbl:SetJustifyH("CENTER"); dragLbl:SetJustifyV("MIDDLE")
        dragLbl:SetTextColor(0.8, 0.9, 1.0, 1.0)
        dragLbl:SetText(":")
        dragBtn:SetScript("OnEnter", function()
            if not dragSourceRow then
                dragTex:SetVertexColor(0.9, 0.7, 0.1, 1.0)
                GameTooltip:SetOwner(dragBtn, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Drag to reorder", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        dragBtn:SetScript("OnLeave", function()
            if not dragSourceRow then
                dragTex:SetVertexColor(0.3, 0.4, 0.6, 0.8)
            end
            GameTooltip:Hide()
        end)
        dragBtn:SetScript("OnMouseDown", function()
            if arg1 == "LeftButton" and row.dbIndex then
                local data = LichborneTrackerDB.rows[row.dbIndex]
                if data and data.name and data.name ~= "" then
                    dragSourceRow = row
                    dragTex:SetVertexColor(0.9, 0.7, 0.1, 1.0)
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
                        LichborneAddStatus:SetText("Set spec: |cffffff00"..sName.."|r for "..(rowData.name or "?"))
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
        nb:SetSize(COL_NAME_W - 4, ROW_HEIGHT - 4)
        nb:SetAutoFocus(false); nb:SetMaxLetters(32)
        nb:SetFont("Fonts\\FRIZQT__.TTF", 11)
        nb:SetTextColor(0.90, 0.95, 1.0)
        nb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        nb:SetBackdropColor(0.05, 0.07, 0.14, 0.8)
        nb:SetBackdropBorderColor(0.15, 0.22, 0.38, 0.7)
        nb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
        nb:SetScript("OnTabPressed", function() this:ClearFocus() end)
        nb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        row.nameBox = nb

        -- GS box
        local gsb = CreateFrame("EditBox", "LichborneRow"..i.."GS", row)
        gsb:SetPoint("LEFT", row, "LEFT", GS_OFF, 0)
        gsb:SetSize(COL_GS_W - 2, ROW_HEIGHT - 4)
        gsb:SetAutoFocus(false); gsb:SetMaxLetters(5)
        gsb:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        gsb:SetTextColor(1, 0.85, 0.0); gsb:SetJustifyH("CENTER")
        gsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gsb:SetBackdropColor(0.05, 0.07, 0.14, 1)
        gsb:SetBackdropBorderColor(0.30, 0.25, 0.05, 0.8)
        gsb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
        gsb:SetScript("OnTabPressed", function() this:ClearFocus() end)
        gsb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
        row.gsBox = gsb

        -- Gear boxes
        row.gearBoxes = {}
        for g = 1, GEAR_SLOTS do
            local gx = GEAR_OFF + (g-1)*COL_GEAR_W
            local gb = CreateFrame("EditBox", "LichborneRow"..i.."Gear"..g, row)
            gb:SetPoint("LEFT", row, "LEFT", gx, 0)
            gb:SetSize(COL_GEAR_W - 2, ROW_HEIGHT - 2)
            gb:SetAutoFocus(false); gb:SetMaxLetters(2); gb:SetNumeric(true)
            gb:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            gb:SetTextColor(1,1,1); gb:SetJustifyH("CENTER")
            gb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
            gb:SetBackdropColor(0.05, 0.07, 0.14, 1)
            gb:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
            gb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
            gb:SetScript("OnTabPressed", function() this:ClearFocus() end)
            gb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
            gb:SetScript("OnMouseUp", function()
                if arg1 == "RightButton" then
                    gb:SetText("")
                    if row.dbIndex then
                        LichborneTrackerDB.rows[row.dbIndex].gear[g] = 0
                        ApplyTierColor(gb, 0)
                    end
                end
            end)
            row.gearBoxes[g] = gb
        end

        -- Tier average box (read-only label)
        local tierBox = CreateFrame("Frame", "LichborneRow"..i.."Tier", row)
        tierBox:SetPoint("LEFT", row, "LEFT", TIER_OFF, 0)
        tierBox:SetSize(COL_TIER_W - 2, ROW_HEIGHT - 2)
        tierBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        tierBox:SetBackdropColor(0.05, 0.07, 0.14, 1)
        tierBox:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
        local tierLabel = tierBox:CreateFontString(nil, "OVERLAY")
        tierLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        tierLabel:SetAllPoints(tierBox)
        tierLabel:SetJustifyH("CENTER"); tierLabel:SetJustifyV("MIDDLE")
        tierLabel:SetTextColor(1, 1, 1)
        tierLabel:SetText("")
        row.tierBox = tierBox
        row.tierLabel = tierLabel

        -- Add to Raid button (green +)
        local addRaidX = TIER_OFF + COL_TIER_W + 3
        local arb = CreateFrame("Button", "LichborneRow"..i.."AddRaid", row)
        arb:SetPoint("LEFT", row, "LEFT", addRaidX, 0)
        arb:SetSize(18, ROW_HEIGHT - 2)
        arb:SetNormalFontObject("GameFontNormalSmall")
        arb:SetText("|cff44ff44+|r")
        arb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        arb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(arb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44ff44+ Add to Raid|r", 1, 1, 1)
            GameTooltip:AddLine("Adds to the Raid planner tab.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        arb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.addRaidBtn = arb

        -- Add to Group button (cyan >) - invite to current party
        local agX = addRaidX + 20
        local agb = CreateFrame("Button", "LichborneRow"..i.."AddGroup", row)
        agb:SetPoint("LEFT", row, "LEFT", agX, 0)
        agb:SetSize(18, ROW_HEIGHT - 2)
        agb:SetNormalFontObject("GameFontNormalSmall")
        agb:SetText("|cff44eeff>|r")
        agb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        agb:SetScript("OnEnter", function()
            GameTooltip:SetOwner(agb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff44eeff> Invite to Group|r", 1, 1, 1)
            GameTooltip:AddLine("Sends a party invite to this player.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        agb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.addGroupBtn = agb

        -- Delete button (shifted right)
        local delX = agX + 20
        local db = CreateFrame("Button", "LichborneRow"..i.."Del", row)
        db:SetPoint("LEFT", row, "LEFT", delX, 0)
        db:SetSize(18, ROW_HEIGHT - 2)
        db:SetNormalFontObject("GameFontNormalSmall")
        db:SetText("|cffaa2222x|r")
        db:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        db:SetScript("OnEnter", function()
            GameTooltip:SetOwner(db, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Remove Character", 1, 0.3, 0.3)
            GameTooltip:AddLine("Permanently removes this character", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("from the tracker database.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        db:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.delBtn = db

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
    if activeTab == "All" then
        if LichborneAllFrame then RefreshAllRows() end
        return
    end
    EnsureClass(activeTab)
    local indices = GetClassRows(activeTab)
    local c = CLASS_COLORS[activeTab]

    -- Reset to page 1 if tab changed
    if not classPage[activeTab] then classPage[activeTab] = 1 end
    -- Update page dropdown label
    local page = classPage[activeTab] or 1
    if LichbornePageLbl then LichbornePageLbl:SetText("|cffaaccffPage "..page.."  v|r") end
    if LichbornePagePrev then LichbornePagePrev:SetAlpha(page > 1 and 1.0 or 0.35) end
    if LichbornePageNext then LichbornePageNext:SetAlpha(page < MAX_PAGES and 1.0 or 0.35) end


    for i = 1, MAX_ROWS do
        local row = rowFrames[i]
        if not row then break end
        local di = indices[i]

        if di then
            local data = LichborneTrackerDB.rows[di]
            row.dbIndex = di
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

            -- GS
            local gsval = data.gs or 0
            row.gsBox:SetScript("OnTextChanged", nil)
            row.gsBox:SetText(gsval > 0 and tostring(gsval) or "")
            row.gsBox:SetScript("OnTextChanged", function()
                local raw = row.gsBox:GetText()
                local clean = raw:gsub("%D", "")
                if clean ~= raw then
                    row.gsBox:SetText(clean)
                    return
                end
                LichborneTrackerDB.rows[di].gs = tonumber(clean) or 0
            end)

            -- Gear
            for g = 1, GEAR_SLOTS do
                local gb = row.gearBoxes[g]
                local val = data.gear[g] or 0
                gb:SetText(val > 0 and tostring(val) or "")
                ApplyTierColor(gb, val)
                gb:SetScript("OnTextChanged", function()
                    local n = tonumber(gb:GetText()) or 0
                    if n > 17 then n=17; gb:SetText("17") end
                    if n < 0  then n=0;  gb:SetText("") end
                    LichborneTrackerDB.rows[di].gear[g] = n
                    ApplyTierColor(gb, n)
                    -- Recalc row tier average live
                    if row.tierLabel then
                        local t2, filled2 = 0, 0
                        for gg = 1, GEAR_SLOTS do
                            local vv = LichborneTrackerDB.rows[di].gear[gg] or 0
                            if vv > 0 then t2 = t2 + vv; filled2 = filled2 + 1 end
                        end
                        if filled2 > 0 then
                            local avg2 = math.floor(t2 / GEAR_SLOTS + 0.5)
                            local tc = TIER_COLORS[avg2]
                            row.tierLabel:SetText("T"..avg2)
                            if tc then
                                local lum = 0.299*tc.r + 0.587*tc.g + 0.114*tc.b
                                row.tierLabel:SetTextColor(lum > 0.45 and 0.05 or 1, lum > 0.45 and 0.05 or 1, lum > 0.45 and 0.05 or 1)
                                row.tierBox:SetBackdropColor(tc.r*0.7, tc.g*0.7, tc.b*0.7, 1)
                                row.tierBox:SetBackdropBorderColor(tc.r, tc.g, tc.b, 1)
                            end
                        else
                            row.tierLabel:SetText("")
                            row.tierBox:SetBackdropColor(0.05, 0.07, 0.14, 1)
                            row.tierBox:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
                        end
                    end
                end)
            end

            -- Tier average (blanks count as 0 — divide by GEAR_SLOTS always)
            if row.tierLabel then
                local total, filled = 0, 0
                for g = 1, GEAR_SLOTS do
                    local v = data.gear[g] or 0
                    if v > 0 then total = total + v; filled = filled + 1 end
                end
                if filled > 0 then
                    local avg = math.floor(total / GEAR_SLOTS + 0.5)
                    local c = TIER_COLORS[avg]
                    row.tierLabel:SetText("T"..avg)
                    if c then
                        local lum = 0.299*c.r + 0.587*c.g + 0.114*c.b
                        if lum > 0.45 then
                            row.tierLabel:SetTextColor(0.05, 0.05, 0.05)
                        else
                            row.tierLabel:SetTextColor(1, 1, 1)
                        end
                        row.tierBox:SetBackdropColor(c.r*0.7, c.g*0.7, c.b*0.7, 1)
                        row.tierBox:SetBackdropBorderColor(c.r, c.g, c.b, 1)
                    end
                else
                    row.tierLabel:SetText("")
                    row.tierBox:SetBackdropColor(0.05, 0.07, 0.14, 1)
                    row.tierBox:SetBackdropBorderColor(0.12, 0.18, 0.30, 0.8)
                end
            end

            -- Add to Raid
            if row.addRaidBtn then
                row.addRaidBtn:SetScript("OnClick", function()
                    local srcData = LichborneTrackerDB.rows[di]
                    if not srcData or not srcData.name or srcData.name == "" then return end
                    -- Get current raid roster
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
                            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r "..hex2..srcData.name.."|r is already in the Raid.", 1, 0.5, 0.5)
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
                        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r "..raidLabel.." is full ("..maxSlots.."/"..maxSlots..").", 1, 0.5, 0.5)
                        return
                    end
                    roster[slot] = {
                        name = srcData.name,
                        cls  = srcData.cls,
                        spec = srcData.spec or "",
                        gs   = srcData.gs or 0,
                    }
                    local c = CLASS_COLORS[srcData.cls]
                    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Added "..hex..srcData.name.."|r to Raid slot "..slot..".", 1, 0.85, 0)
                    if LichborneAddStatus then
                        LichborneAddStatus:SetText(hex..srcData.name.."|r added to raid slot "..slot..".")
                    end
                    -- Refresh raid rows if visible
                    if activeTab == "Raid" and raidRowFrames and #raidRowFrames > 0 then
                        RefreshRaidRows()
                    end
                end)
            end

            -- Invite to Group
            if row.addGroupBtn then
                row.addGroupBtn:SetScript("OnClick", function()
                    local srcData = LichborneTrackerDB.rows[di]
                    if not srcData or not srcData.name or srcData.name == "" then return end
                    SendChatMessage(".playerbots bot add "..srcData.name, "SAY")
                    local c = CLASS_COLORS[srcData.cls]
                    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Inviting "..hex..srcData.name.."|r to group...", 1, 0.85, 0)
                    if LichborneAddStatus then
                        LichborneAddStatus:SetText("Invited "..hex..srcData.name.."|r to group.")
                    end
                end)
            end

            -- Delete
            row.delBtn:SetScript("OnClick", function()
                table.remove(LichborneTrackerDB.rows, di)
                RefreshRows()
                if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            end)
        else
            row:Hide()
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
            if _G["LichbornePageDDMenu"] then _G["LichbornePageDDMenu"]:Hide() end
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            menu:Show()
        end
    end)

    btn._menu = menu  -- store ref so callers can hide on tab switch
    return btn
end


local function GetClassAvgTier(cls)
    if cls == "Raid" then return 0 end
    local total, namedRows = 0, 0
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.cls == cls and row.name and row.name ~= "" then
            namedRows = namedRows + 1
            for g = 1, GEAR_SLOTS do
                total = total + (row.gear[g] or 0)
            end
        end
    end
    if namedRows == 0 then return 0 end
    return math.floor(total / (namedRows * GEAR_SLOTS) + 0.5)
end


-- ── Raid tab: RefreshRaidRows ──────────────────────────────────
local raidSortMode = nil  -- nil, "name", "classspec", "gs", "tier"
local allSortMode  = nil  -- nil, "name", "classspec", "gs"

local function SortRaidRows()
    if not raidSortMode then return end
    local roster, raidSize = GetCurrentRoster()
    local filled, empty = {}, {}
    for i = 1, 40 do
        local r = roster[i]
        if r and r.name and r.name ~= "" then
            filled[#filled+1] = r
        else
            empty[#empty+1] = {name="", cls="", spec="", gs=0}
        end
    end
    if raidSortMode == "name" then
        table.sort(filled, function(a, b) return (a.name or "") < (b.name or "") end)
    elseif raidSortMode == "classspec" then
        table.sort(filled, function(a, b)
            if (a.cls or "") ~= (b.cls or "") then return (a.cls or "") < (b.cls or "") end
            if (a.spec or "") ~= (b.spec or "") then return (a.spec or "") < (b.spec or "") end
            return (a.name or "") < (b.name or "")
        end)
    elseif raidSortMode == "gs" then
        table.sort(filled, function(a, b)
            local ga, gb2 = a.gs or 0, b.gs or 0
            if ga ~= gb2 then return ga > gb2 end
            return (a.name or "") < (b.name or "")
        end)
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
    for i = 1, 40 do
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

        -- Tier: look up from class tab gear data
        if rf.tierLbl then
            local avgT = 0
            if data.name and data.name ~= "" then
                for _, row in ipairs(LichborneTrackerDB.rows) do
                    if row.name and row.name:lower() == data.name:lower() then
                        local tot = 0
                        for g = 1, GEAR_SLOTS do tot = tot + (row.gear and row.gear[g] or 0) end
                        avgT = math.floor(tot / GEAR_SLOTS + 0.5)
                        break
                    end
                end
            end
            if avgT > 0 then
                rf.tierLbl:SetText("T"..avgT)
                rf.tierLbl:SetTextColor(1, 0.85, 0.0)  -- gold like GS
            else
                rf.tierLbl:SetText("")
                rf.tierLbl:SetTextColor(1, 0.85, 0.0)
            end
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

        -- GS
        if rf.gsBox then
            rf.gsBox:SetScript("OnTextChanged", nil)
            rf.gsBox:SetText(data.gs and data.gs > 0 and tostring(data.gs) or "")
            local idx = i
            rf.gsBox:SetScript("OnTextChanged", function()
                local raw = rf.gsBox:GetText()
                local clean = raw:gsub("%D","")
                if clean ~= raw then rf.gsBox:SetText(clean); return end
local r3, _ = GetCurrentRoster(); r3[idx].gs = tonumber(clean) or 0
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
local r5, _ = GetCurrentRoster(); r5[idx] = {name="", cls="", spec="", gs=0}
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
                lbl:SetText(hex..(TAB_LABELS[cls])..": "..n.."|r")
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

-- ── Raid tab: BuildRaidFrame ───────────────────────────────────
local function BuildRaidFrame(parent, fl)
    if raidFrameBuilt then return end
    raidFrameBuilt = true

    -- Main container hidden behind header bar area
    LichborneRaidFrame = CreateFrame("Frame", "LichborneRaidFrame", parent)
    LichborneRaidFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -94)
    LichborneRaidFrame:SetSize(1020, 510)
    LichborneRaidFrame:SetFrameLevel(fl + 10)
    LichborneRaidFrame:Hide()

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
    tierBar:SetSize(1020, 24)
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
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
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

    local function UpdateRaidDD()
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
        raidDD.lbl:SetText("|cffffffff"..raidName.."|r  |cffaaaaaa("..raidSize..")|r  v")
    end

    local function UpdateTierDD()
        local t = LichborneTrackerDB.raidTier or 1
        local c = TIER_COLORS[t]
        local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        tierDD.lbl:SetText(hex.."T"..t.."  "..(TIER_LABELS[t] or ""):match("^T%d+ %— (.+)") or "".."|r  v")
        UpdateTierBar()
        UpdateRaidDD()
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
        mblbl:SetText(hex..(TIER_LABELS[t] or "T"..t).."|r")
        mb:SetScript("OnClick",function()
            LichborneTrackerDB.raidTier = t
            UpdateTierDD()
            tierDDMenu:Hide()
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
            -- Swap invite buttons based on tier
            if LichborneInviteRaidBtn then
                if t == 0 then LichborneInviteRaidBtn:Hide() else LichborneInviteRaidBtn:Show() end
            end
            if _G["LichborneInviteGroupBtn"] then
                if t == 0 then _G["LichborneInviteGroupBtn"]:Show() else _G["LichborneInviteGroupBtn"]:Hide() end
            end
            if _G["LichborneStopInviteBtn"] then _G["LichborneStopInviteBtn"]:Show() end
        end)
    end
    tierDD:SetScript("OnClick",function()
        if raidDDMenu then raidDDMenu:Hide() end
        if tierDDMenu:IsShown() then tierDDMenu:Hide()
        else tierDDMenu:ClearAllPoints(); tierDDMenu:SetPoint("TOPLEFT",tierDD,"BOTTOMLEFT",0,-2); tierDDMenu:Show() end
    end)

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
            local c=TIER_COLORS[t]; mbbg:SetTexture(c.r*0.25,c.g*0.25,c.b*0.25,1)
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
                if gdd and gdd.lbl then gdd.lbl:SetText("|cffffffff A|r  v") end
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
        groupDD.lbl:SetText("|cffffffff"..g.."|r  v")
    end
    UpdateGroupDD()

    local groupDDMenu = CreateFrame("Frame","LichborneRaidGroupMenu",UIParent)
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

    -- Sort dropdown
    local raidSortBtn = MakeSortDropdown(tierBar, fl + 12, function(mode)
        raidSortMode = mode
        RefreshRaidRows()
    end)
    raidSortBtn:SetPoint("LEFT", tierBar, "LEFT", 4, 0)

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
        for i = 1, 40 do
            local r = roster[i] or {}
            rosterClipboard[i] = {
                name  = r.name  or "",
                cls   = r.cls   or "",
                spec  = r.spec  or "",
                gs    = r.gs    or 0,
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
        for i = 1, 40 do
            local src = rosterClipboard[i] or {}
            roster[i] = {
                name  = src.name  or "",
                cls   = src.cls   or "",
                spec  = src.spec  or "",
                gs    = src.gs    or 0,
                role  = src.role  or "",
                notes = src.notes or "",
            }
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
    clearLbl:SetText("|cffff6666Clear|r")
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
        for i=1,sizeC do rosterC[i]={name="",cls="",spec="",gs=0,role="",notes=""} end
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
    hdrRow:SetSize(1020,18)
    hdrRow:SetFrameLevel(fl+11)
    local hdrBg = hdrRow:CreateTexture(nil,"BACKGROUND"); hdrBg:SetAllPoints(hdrRow); hdrBg:SetTexture(0.08,0.20,0.42,1)

    local function RH(lbl,x,w)
        local fs=hdrRow:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("LEFT",hdrRow,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cff90b8e8"..lbl.."|r")
    end

    -- Layout constants for raid rows
    local RD=0; local RC=20; local RS=42; local RN=66; local RG=190; local RT=246; local RRole=284; local RNotes=308; local RDelX=480
    -- Spec header icon only (no class icon header)
    local specHdrTex = hdrRow:CreateTexture(nil, "OVERLAY")
    specHdrTex:SetPoint("LEFT", hdrRow, "LEFT", RS, 0)
    specHdrTex:SetSize(18, 16)
    specHdrTex:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    RH("Name",RN+2,122); RH("GS",RG+2,52); RH("Tier",RT+2,36); RH("Role",RRole-2,28); RH("Notes",RNotes+2,168)

    -- Build 40 raid rows (2 columns of 20)
    local ROW_H = 22
    local COL2_X = 520

    for i=1,40 do
        local col = i <= 20 and 0 or COL2_X
        local rowIdx = i <= 20 and (i-1) or (i-21)
        local yOff = -46 - rowIdx * ROW_H

        local rf = CreateFrame("Frame","LichborneRaidRow"..i,LichborneRaidFrame)
        rf:SetPoint("TOPLEFT",LichborneRaidFrame,"TOPLEFT",col,yOff)
        rf:SetSize(500,ROW_H)
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
        dragBtn:SetScript("OnMouseDown",function()
            if arg1 == "LeftButton" then
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
        nb:SetPoint("LEFT",rf,"LEFT",RN,0); nb:SetSize(122,ROW_H-2)
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

        -- GS editbox
        local gsb=CreateFrame("EditBox",nil,rf)
        gsb:SetPoint("LEFT",rf,"LEFT",RG,0); gsb:SetSize(52,ROW_H-2)  -- GS at 190
        gsb:SetAutoFocus(false); gsb:SetMaxLetters(5)
        gsb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
        gsb:SetTextColor(1,0.85,0); gsb:SetJustifyH("CENTER")
        gsb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gsb:SetBackdropColor(0.05,0.07,0.14,0.6)
        gsb:SetBackdropBorderColor(0.30,0.25,0.05,0.5)
        gsb:SetScript("OnEnterPressed",function() gsb:ClearFocus() end)
        gsb:SetScript("OnTabPressed",function() gsb:ClearFocus() end)
        gsb:SetScript("OnEscapePressed",function() gsb:ClearFocus() end)
        rf.gsBox=gsb

        -- Tier box (styled like GS box)
        local tierBox2 = CreateFrame("Frame",nil,rf)
        tierBox2:SetPoint("LEFT",rf,"LEFT",RT,0); tierBox2:SetSize(36,ROW_H-2)
        tierBox2:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        tierBox2:SetBackdropColor(0.05,0.07,0.14,1); tierBox2:SetBackdropBorderColor(0.30,0.25,0.05,0.5)
        local tierLbl = tierBox2:CreateFontString(nil,"OVERLAY")
        tierLbl:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
        tierLbl:SetAllPoints(tierBox2); tierLbl:SetJustifyH("CENTER"); tierLbl:SetJustifyV("MIDDLE")
        tierLbl:SetTextColor(1,0.85,0); tierLbl:SetText("")
        rf.tierLbl = tierLbl

        -- Role button (icon-only 22px, between Tier and Notes)
        local roleBtn = CreateFrame("Button",nil,rf)
        roleBtn:SetPoint("LEFT",rf,"LEFT",RRole,0); roleBtn:SetSize(22,ROW_H-2)
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

        -- Notes editbox
        local notesBox=CreateFrame("EditBox",nil,rf)
        notesBox:SetPoint("LEFT",rf,"LEFT",RNotes,0); notesBox:SetSize(168,ROW_H-2)
        notesBox:SetAutoFocus(false); notesBox:SetMaxLetters(24)
        notesBox:SetFont("Fonts\\FRIZQT__.TTF",9); notesBox:SetTextColor(0.85,0.85,0.70)
        notesBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        notesBox:SetBackdropColor(0.05,0.07,0.10,0.6); notesBox:SetBackdropBorderColor(0.25,0.25,0.15,0.5)
        notesBox:SetScript("OnEnterPressed",function() notesBox:ClearFocus() end)
        notesBox:SetScript("OnTabPressed",function() notesBox:ClearFocus() end)
        notesBox:SetScript("OnEscapePressed",function() notesBox:ClearFocus() end)
        rf.notesBox=notesBox

        -- Class btn reference for color updates
        rf.classBtn=clsBtn; rf.classBtnTex=clsTex

        -- Clear/delete button (far right)
        local db=CreateFrame("Button",nil,rf)
        db:SetPoint("LEFT",rf,"LEFT",RDelX,0); db:SetSize(16,ROW_H-2)
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

        -- Divider
        local ln=rf:CreateTexture(nil,"OVERLAY"); ln:SetHeight(1); ln:SetWidth(500)
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
                local ra = roster3[a] or {name="",cls="",spec="",gs=0,role="",notes=""}
                local rb = roster3[b2] or {name="",cls="",spec="",gs=0,role="",notes=""}
                local tmp = {name=ra.name,cls=ra.cls,spec=ra.spec,gs=ra.gs,role=ra.role,notes=ra.notes}
                roster3[a] = {name=rb.name,cls=rb.cls,spec=rb.spec,gs=rb.gs,role=rb.role,notes=rb.notes}
                roster3[b2] = tmp
                RefreshRaidRows()
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
    hdrRow2:SetSize(500,18); hdrRow2:SetFrameLevel(fl+11)
    local hdrBg2=hdrRow2:CreateTexture(nil,"BACKGROUND"); hdrBg2:SetAllPoints(hdrRow2); hdrBg2:SetTexture(0.08,0.20,0.42,1)
    RH2 = function(lbl,x,w)
        local fs=hdrRow2:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("LEFT",hdrRow2,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cff90b8e8"..lbl.."|r")
    end
    local specHdrTex2 = hdrRow2:CreateTexture(nil, "OVERLAY")
    specHdrTex2:SetPoint("LEFT", hdrRow2, "LEFT", RS, 0)
    specHdrTex2:SetSize(18, 16)
    specHdrTex2:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    RH2("Name",RN+2,122); RH2("GS",RG+2,52); RH2("Tier",RT+2,36); RH2("",RRole,20); RH2("Notes",RNotes+2,168)

    -- ── Raid class count bar ──────────────────────────────────
    local raidCountBar = CreateFrame("Frame","LichborneRaidCountBar",LichborneRaidFrame)
    _G["LichborneRaidCountBar"] = raidCountBar
    raidCountBar:SetPoint("TOPLEFT", LichborneRaidFrame, "TOPLEFT", 0, -486)
    raidCountBar:SetSize(1020, 24)
    raidCountBar:SetFrameLevel(fl + 11)
    local rcbBg = raidCountBar:CreateTexture(nil,"BACKGROUND")
    rcbBg:SetAllPoints(raidCountBar); rcbBg:SetTexture(0.05, 0.07, 0.13, 1)
    -- Gold top border on count bar
    local rcbBorder = raidCountBar:CreateTexture(nil,"OVERLAY")
    rcbBorder:SetHeight(1); rcbBorder:SetAllPoints(false)
    rcbBorder:SetPoint("TOPLEFT",raidCountBar,"TOPLEFT",0,0)
    rcbBorder:SetPoint("TOPRIGHT",raidCountBar,"TOPRIGHT",0,0)
    rcbBorder:SetHeight(1); rcbBorder:SetTexture(0.08,0.20,0.42,1)
    local rcTitle = raidCountBar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    rcTitle:SetPoint("LEFT", raidCountBar, "LEFT", 4, 0)
    rcTitle:SetText("|cffC69B3ACount:|r"); rcTitle:SetWidth(44)
    LichborneRaidCountLabels = {}
    local rcW = (1020 - 50) / 10
    for ci, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" then break end
        local c = CLASS_COLORS[cls]
        local rcSw = CreateFrame("Button", nil, raidCountBar)
        rcSw:SetSize(rcW - 2, 20)
        rcSw:SetPoint("LEFT", raidCountBar, "LEFT", 48 + (ci-1)*rcW, 0)
        rcSw:SetFrameLevel(raidCountBar:GetFrameLevel() + 1)
        local rcBg2 = rcSw:CreateTexture(nil,"BACKGROUND"); rcBg2:SetAllPoints(rcSw)
        rcBg2:SetTexture(0.08, 0.10, 0.18, 1); rcSw.bg = rcBg2
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local rcLbl = rcSw:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        rcLbl:SetAllPoints(rcSw); rcLbl:SetJustifyH("CENTER"); rcLbl:SetJustifyV("MIDDLE")
        rcLbl:SetText(hex..(TAB_LABELS[cls])..": 0|r")
        rcSw.lbl = rcLbl; rcSw.cls = cls
        LichborneRaidCountLabels[cls] = rcLbl
        -- Click to filter/highlight that class (future feature hook)
        rcSw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(rcSw,"ANCHOR_TOP")
            GameTooltip:AddLine(cls, c.r, c.g, c.b)
            GameTooltip:Show()
        end)
        rcSw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- ── Invite Raid button (anchored below raid frame) ────────
    -- Invite button lives on main frame beside Add Target/Update GS buttons
    local activeInviteFrame = nil  -- holds the running invite OnUpdate frame so Stop can kill it

    -- ── Stop button ───────────────────────────────────────────
    local stopBtn = CreateFrame("Button", "LichborneStopInviteBtn", LichborneRaidFrame:GetParent())
    stopBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 710, 10)
    stopBtn:SetSize(180, 130)
    stopBtn:SetFrameLevel(fl + 12)
    stopBtn:Hide()
    stopBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    stopBtn:SetBackdropColor(0.25,0.05,0.05,1)
    stopBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    stopBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local stopLbl = stopBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    stopLbl:SetAllPoints(stopBtn); stopLbl:SetJustifyH("CENTER"); stopLbl:SetJustifyV("MIDDLE")
    stopLbl:SetText("|cffd4af37Stop Invite|r")
    stopBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(stopBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Stop Invite", 1, 1, 1)
        GameTooltip:AddLine("Cancels the running invite script.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    stopBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stopBtn:SetScript("OnClick", function()
        if activeInviteFrame then
            activeInviteFrame:SetScript("OnUpdate", nil)
            activeInviteFrame = nil
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffff4444Invite stopped.|r", 1, 0.85, 0)
        if LichborneAddStatus then LichborneAddStatus:SetText("|cffff4444Invite stopped.") end
    end)
    _G["LichborneStopInviteBtn"] = stopBtn

    local inviteBtn = CreateFrame("Button","LichborneInviteRaidBtn",LichborneRaidFrame:GetParent())
    inviteBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 525, 10)
    inviteBtn:SetSize(180, 130)
    inviteBtn:SetFrameLevel(fl + 12)
    inviteBtn:Hide()  -- hidden until Raid tab is active
    inviteBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    inviteBtn:SetBackdropColor(0.05,0.20,0.05,1)
    inviteBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    inviteBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local inviteLbl = inviteBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    inviteLbl:SetAllPoints(inviteBtn); inviteLbl:SetJustifyH("CENTER"); inviteLbl:SetJustifyV("MIDDLE")
    inviteLbl:SetText("|cffd4af37Invite Raid|r")
    inviteBtn:SetScript("OnEnter",function()
        local roster, size = GetCurrentRoster()
        local count = 0
        for i=1,size do if roster[i] and roster[i].name and roster[i].name ~= "" then count=count+1 end end
        GameTooltip:SetOwner(inviteBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("Invite Raid",1,1,1)
        GameTooltip:AddLine(count.." players in this roster",0.8,0.8,0.8)
        GameTooltip:AddLine("1. Log out all current bots",0.6,0.6,0.6)
        GameTooltip:AddLine("2. Leave current party",0.6,0.6,0.6)
        GameTooltip:AddLine("3. Invite first player",0.6,0.6,0.6)
        GameTooltip:AddLine("4. Convert to raid",0.6,0.6,0.6)
        GameTooltip:AddLine("5. Invite remaining players",0.6,0.6,0.6)
        GameTooltip:Show()
    end)
    inviteBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)

    inviteBtn:SetScript("OnClick",function()
        local roster, size = GetCurrentRoster()
        -- Collect non-empty names
        local names = {}
        for i=1,size do
            local r = roster[i]
            if r and r.name and r.name ~= "" then
                names[#names+1] = r.name
            end
        end
        if #names == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r No players in this roster.",1,0.5,0.5)
            return
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Starting raid invite for "..#names.." players...",1,0.85,0)
        if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Removing current bots by name...") end

        -- Step 0: Leave party immediately
        LeaveParty()

        -- Collect all known bot names across ALL rosters to remove individually
        local botsToRemove = {}
        local seen = {}
        local allRosters = LichborneTrackerDB.raidRosters or {}
        for _, roster in pairs(allRosters) do
            for i = 1, 40 do
                local r = roster[i]
                if r and r.name and r.name ~= "" and not seen[r.name:lower()] then
                    seen[r.name:lower()] = true
                    botsToRemove[#botsToRemove+1] = r.name
                end
            end
        end
        -- Fallback: if no rosters found, just remove the current invite list
        if #botsToRemove == 0 then
            for _, n in ipairs(names) do botsToRemove[#botsToRemove+1] = n end
        end

        local inviteIndex = 1
        local waitTime = 0
        local phase = "logout_remove"
        local logoutIndex = 1
        local reinviteSubPhase = "remove"

        local inviteFrame = CreateFrame("Frame")
        activeInviteFrame = inviteFrame
        inviteFrame:SetScript("OnUpdate",function()
            waitTime = waitTime + arg1

            if phase == "logout_remove" then
                if waitTime < 0.1 then return end
                waitTime = 0
                if logoutIndex > #botsToRemove then
                    phase = "logout_wait"
                    waitTime = 0
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r All bots removed, waiting...",1,0.85,0)
                    if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Waiting for bots to clear...") end
                    return
                end
                local bname = botsToRemove[logoutIndex]
                SendChatMessage(".playerbots bot remove "..bname, "SAY")
                logoutIndex = logoutIndex + 1

            elseif phase == "logout_wait" then
                if waitTime < 2.0 then return end
                waitTime = 0
                phase = "first"
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Bots cleared, starting invites...",1,0.85,0)
                if LichborneAddStatus then LichborneAddStatus:SetText("|cffff9900Inviting "..#names.." players...") end

            elseif phase == "first" then
                if waitTime < 0.5 then return end
                local firstName = names[1]
                SendChatMessage(".playerbots bot add "..firstName, "SAY")
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Inviting "..firstName.."...",1,0.85,0)
                inviteIndex = 2
                waitTime = 0
                phase = "convert"

            elseif phase == "convert" then
                if waitTime < 2.0 then return end
                ConvertToRaid()
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Converting to raid...",1,0.85,0)
                waitTime = 0
                phase = "rest"

            elseif phase == "rest" then
                if waitTime < 0.8 then return end
                waitTime = 0
                if inviteIndex > #names then
                    -- Initial pass done — wait 3s then verify who's missing
                    phase = "verify_wait"
                    waitTime = 0
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Initial invites sent, verifying...",1,0.85,0)
                    return
                end
                local pname = names[inviteIndex]
                SendChatMessage(".playerbots bot add "..pname, "SAY")
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Inviting "..pname.."...",1,0.85,0)
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
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cff44ff44All "..#names.." players confirmed in raid!|r",1,0.85,0)
                    if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44All "..#names.." players confirmed in raid.|r") end
                    inviteFrame:SetScript("OnUpdate",nil)
                    return
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffff9900"..#missing.." missed — re-inviting...|r",1,0.85,0)
                names = missing
                inviteIndex = 1
                phase = "reinvite"
                waitTime = 0

            elseif phase == "reinvite" then
                -- remove then wait 1s then add, per missed character
                if reinviteSubPhase == "remove" then
                    if inviteIndex > #names then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cff44ff44Re-invite pass complete.|r",1,0.85,0)
                        if LichborneAddStatus then LichborneAddStatus:SetText("|cff44ff44Invite complete (re-invite pass done).|r") end
                        inviteFrame:SetScript("OnUpdate",nil)
                        return
                    end
                    local pname = names[inviteIndex]
                    SendChatMessage(".playerbots bot remove "..pname, "SAY")
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Removing "..pname.." before re-invite...",1,0.85,0)
                    waitTime = 0
                    reinviteSubPhase = "add"

                elseif reinviteSubPhase == "add" then
                    if waitTime < 1.0 then return end
                    local pname = names[inviteIndex]
                    SendChatMessage(".playerbots bot add "..pname, "SAY")
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Re-inviting "..pname.."...",1,0.85,0)
                    inviteIndex = inviteIndex + 1
                    waitTime = 0
                    reinviteSubPhase = "remove"
                end
            end
        end)
    end)

    -- ── Invite Group button (for T0 5-mans, no raid conversion) ──
    local inviteGroupBtn = CreateFrame("Button","LichborneInviteGroupBtn",LichborneRaidFrame:GetParent())
    inviteGroupBtn:SetPoint("BOTTOMLEFT", LichborneRaidFrame:GetParent(), "BOTTOMLEFT", 525, 10)
    inviteGroupBtn:SetSize(180, 130)
    inviteGroupBtn:SetFrameLevel(fl + 12)
    inviteGroupBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    inviteGroupBtn:SetBackdropColor(0.05,0.25,0.30,1)
    inviteGroupBtn:SetBackdropBorderColor(0.78,0.61,0.23,0.9)
    inviteGroupBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    inviteGroupBtn:Hide()
    local inviteGroupLbl = inviteGroupBtn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    inviteGroupLbl:SetAllPoints(inviteGroupBtn); inviteGroupLbl:SetJustifyH("CENTER"); inviteGroupLbl:SetJustifyV("MIDDLE")
    inviteGroupLbl:SetText("|cffd4af37Invite Group|r")
    inviteGroupBtn:SetScript("OnEnter",function()
        local roster, size = GetCurrentRoster()
        local count = 0
        for i=1,size do if roster[i] and roster[i].name and roster[i].name ~= "" then count=count+1 end end
        GameTooltip:SetOwner(inviteGroupBtn,"ANCHOR_TOP")
        GameTooltip:AddLine("Invite Group (5-Man)",1,1,1)
        GameTooltip:AddLine(count.." players in this roster",0.8,0.8,0.8)
        GameTooltip:AddLine("Leaves party, then invites all",0.6,0.6,0.6)
        GameTooltip:AddLine("players as a normal party.",0.6,0.6,0.6)
        GameTooltip:Show()
    end)
    inviteGroupBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    inviteGroupBtn:SetScript("OnClick",function()
        local roster, size = GetCurrentRoster()
        local names = {}
        for i=1,size do
            local r = roster[i]
            if r and r.name and r.name ~= "" then names[#names+1] = r.name end
        end
        if #names == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r No players in this roster.",1,0.5,0.5)
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Starting group invite for "..#names.." players...",1,0.85,0)
        LeaveParty()
        local invIdx = 1
        local waited = 0
        local grpFrame = CreateFrame("Frame")
        activeInviteFrame = grpFrame
        grpFrame:SetScript("OnUpdate",function()
            waited = waited + arg1
            if waited < 0.8 then return end
            waited = 0
            if invIdx > #names then
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cff44ff44Group invite complete! ("..#names.." players)|r",1,0.85,0)
                grpFrame:SetScript("OnUpdate",nil)
                return
            end
            local pname = names[invIdx]
            SendChatMessage(".playerbots bot add "..pname, "SAY")
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Inviting "..pname.."...",1,0.85,0)
            invIdx = invIdx + 1
        end)
    end)
    _G["LichborneInviteGroupBtn"] = inviteGroupBtn

end


-- Helper: get current All group rows
local function GetCurrentAllRows()
    if not LichborneTrackerDB.allGroups then
        LichborneTrackerDB.allGroups = {}
    end
    if not LichborneTrackerDB.allGroup then LichborneTrackerDB.allGroup = "A" end
    local g = LichborneTrackerDB.allGroup
    if not LichborneTrackerDB.allGroups[g] then
        LichborneTrackerDB.allGroups[g] = {}
        for i=1,60 do LichborneTrackerDB.allGroups[g][i]={name="",cls="",spec="",gs=0} end
    end
    local rows = LichborneTrackerDB.allGroups[g]
    for i=1,60 do if not rows[i] then rows[i]={name="",cls="",spec="",gs=0} end end
    return rows
end

-- ── All tab: mirrors Raid tab with 3 columns of 20 = 60 slots ──────────
RefreshAllRows = function()
    if not LichborneAllFrame then return end
    local rows = GetCurrentAllRows()

    -- Update All tab group label
    local g = LichborneTrackerDB.allGroup or "A"
    if LichborneAllPageLbl then
        local pageNum = ({A="1",B="2",C="3"})[g] or g
        LichborneAllPageLbl:SetText("|cffaaccffPage "..pageNum.."  v|r")
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
    -- Fill groups in order
    local groups = {"A","B","C"}
    for gi, g in ipairs(groups) do
        if not LichborneTrackerDB.allGroups[g] then
            LichborneTrackerDB.allGroups[g] = {}
        end
        local gRows = LichborneTrackerDB.allGroups[g]
        for i=1,60 do if not gRows[i] then gRows[i]={name="",cls="",spec="",gs=0} end end
        local startIdx = (gi-1)*60 + 1
        local endIdx   = gi*60
        -- Clear first
        for i=1,60 do gRows[i]={name="",cls="",spec="",gs=0} end
        -- Fill with tracked chars for this range
        for i=startIdx,endIdx do
            local slot = i - startIdx + 1
            if allTracked[i] then
                local cr = allTracked[i]
                gRows[slot] = {name=cr.name, cls=cr.cls or "", spec=cr.spec or "", gs=cr.gs or 0}
            end
        end
    end
    -- Re-get rows for current group display
    rows = GetCurrentAllRows()

    -- Apply sort if active (sort a copy so DB order is unchanged)
    if allSortMode then
        local function nameEmpty(r) return not r.name or r.name == "" end
        local sorted = {}
        for i = 1, 60 do sorted[i] = rows[i] end
        if allSortMode == "name" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortMode == "classspec" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                if (a.cls or "") ~= (b.cls or "") then return (a.cls or "") < (b.cls or "") end
                if (a.spec or "") ~= (b.spec or "") then return (a.spec or "") < (b.spec or "") end
                return (a.name or "") < (b.name or "")
            end)
        elseif allSortMode == "gs" then
            table.sort(sorted, function(a, b)
                if nameEmpty(a) ~= nameEmpty(b) then return not nameEmpty(a) end
                local ga, gb2 = a.gs or 0, b.gs or 0
                if ga ~= gb2 then return ga > gb2 end
                return (a.name or "") < (b.name or "")
            end)
        end
        rows = sorted
    end

    for i = 1, 60 do
        local rf = allRowFrames[i]
        if not rf then break end
        local data = rows[i]
        local hasData = data.name and data.name ~= ""

        -- Sync spec from class tabs
        if hasData then
            for _, r in ipairs(LichborneTrackerDB.rows) do
                if r.name and r.name:lower() == data.name:lower() then
                    if r.spec and r.spec ~= "" then data.spec = r.spec end
                    if r.cls and r.cls ~= "" then data.cls = r.cls end
                    if r.gs and r.gs > 0 then data.gs = r.gs end
                    break
                end
            end
        end

        -- Tier lookup from class tab gear
        if rf.tierLbl then
            local avgT = 0
            if hasData then
                for _, row in ipairs(LichborneTrackerDB.rows) do
                    if row.name and row.name:lower() == data.name:lower() then
                        local tot = 0
                        for g = 1, GEAR_SLOTS do tot = tot + (row.gear and row.gear[g] or 0) end
                        avgT = math.floor(tot / GEAR_SLOTS + 0.5)
                        break
                    end
                end
            end
            rf.tierLbl:SetText(avgT > 0 and ("T"..avgT) or "")
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
        -- GS
        if rf.gsBox then
            rf.gsBox:SetScript("OnTextChanged", nil)
            rf.gsBox:SetText(data.gs and data.gs > 0 and tostring(data.gs) or "")
            local idx = i
            rf.gsBox:SetScript("OnTextChanged", function()
                local raw = rf.gsBox:GetText()
                local clean = raw:gsub("%D","")
                if clean ~= raw then rf.gsBox:SetText(clean); return end
                local r3=GetCurrentAllRows(); r3[idx].gs = tonumber(clean) or 0
            end)
        end
        -- Row number
        if rf.numLbl then rf.numLbl:SetText(tostring(i)) end
        -- No delete on All tab

        -- Spec button popup (same menu as raid/class tabs)
        if rf.specIcon then
            local specFrame = rf.specIcon and rf.specIcon:GetParent()
            if specFrame then
                specFrame:SetScript("OnEnter", function()
                    local allR2 = GetCurrentAllRows()
                    local d4 = allR2[i]
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
            local idx = i
            rf.addGroupBtn:SetScript("OnClick", function()
                local d = GetCurrentAllRows()[idx]
                if not d or not d.name or d.name == "" then return end
                SendChatMessage(".playerbots bot add "..d.name, "SAY")
                local c = d.cls and CLASS_COLORS[d.cls]
                local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
                if LichborneAddStatus then LichborneAddStatus:SetText("Invited "..hex..d.name.."|r to group.") end
            end)
        end
        -- Add to Raid btn
        if rf.addRaidBtn then
            local idx = i
            rf.addRaidBtn:SetScript("OnClick", function()
                local d = GetCurrentAllRows()[idx]
                if not d or not d.name or d.name == "" then return end
                local roster, raidSize = GetCurrentRoster()
                for ri = 1, raidSize do
                    if roster[ri] and roster[ri].name and roster[ri].name:lower() == d.name:lower() then
                        if LichborneAddStatus then LichborneAddStatus:SetText(d.name.." already in Raid.") end; return
                    end
                end
                for ri = 1, raidSize do
                    if not roster[ri] or roster[ri].name == "" then
                        roster[ri] = {name=d.name, cls=d.cls or "",spec=d.spec or "",gs=d.gs or 0}
                        local c = d.cls and CLASS_COLORS[d.cls]
                        local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
                        if LichborneAddStatus then LichborneAddStatus:SetText(hex..d.name.."|r added to raid slot "..ri..".") end; return
                    end
                end
                if LichborneAddStatus then LichborneAddStatus:SetText("Raid is full!") end
            end)
        end
    end

    -- Count bar
    if LichborneAllCountLabels then
        local allCounts = {}
        for _, cls in ipairs(CLASS_TABS) do if cls ~= "Raid" and cls ~= "All" then allCounts[cls] = 0 end end
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
                lbl:SetText(hex..(TAB_LABELS[cls])..": "..n.."|r")
                local sw = lbl:GetParent()
                if sw and sw.bg then
                    if n > 0 then sw.bg:SetTexture(c.r*0.25,c.g*0.25,c.b*0.30,1)
                    else sw.bg:SetTexture(0.08,0.10,0.18,1) end
                end
            end
        end
    end
end  -- RefreshAllRows

-- All frame uses same layout as Raid: 3 columns of 20, same row height
local ALL_PER_COL = 20
local ALL_NCOLS   = 3
local ALL_COL_W   = 338   -- 3 * 338 = 1014, fits in 1020 frame

local function BuildAllFrame(parent, fl)
    if allFrameBuilt then return end
    allFrameBuilt = true

    LichborneAllFrame = CreateFrame("Frame","LichborneAllFrame",parent)
    LichborneAllFrame:SetPoint("TOPLEFT",parent,"TOPLEFT",15,-94)
    LichborneAllFrame:SetSize(ALL_NCOLS*ALL_COL_W, 512)  -- 24hdr+20+18hdr+20+440rows+10+24count
    LichborneAllFrame:SetFrameLevel(fl+10)
    LichborneAllFrame:Hide()

    -- Green header bar
    local allHdr = CreateFrame("Frame",nil,LichborneAllFrame)
    allHdr:SetPoint("TOPLEFT",LichborneAllFrame,"TOPLEFT",0,0)
    allHdr:SetSize(ALL_NCOLS*ALL_COL_W,24); allHdr:SetFrameLevel(fl+11)
    local allHdrBg = allHdr:CreateTexture(nil,"BACKGROUND"); allHdrBg:SetAllPoints(allHdr); allHdrBg:SetTexture(0.05,0.20,0.05,1)
    local allTitle = allHdr:CreateFontString(nil,"OVERLAY","GameFontNormal")
    allTitle:SetPoint("TOPLEFT",allHdr,"TOPLEFT",0,0); allTitle:SetPoint("TOPRIGHT",allHdr,"TOPRIGHT",0,0)
    allTitle:SetHeight(24); allTitle:SetJustifyH("CENTER"); allTitle:SetJustifyV("MIDDLE")
    allTitle:SetText("|cff44cc44All|r")

    -- Sort / Clear buttons
    local function MakeHdrBtn(lbl, br, bg2, bb, xOff, w)
        local btn = CreateFrame("Button",nil,allHdr); btn:SetSize(w or 55,20)
        btn:SetPoint("RIGHT",allHdr,"RIGHT",xOff,0); btn:SetFrameLevel(fl+12)
        btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        btn:SetBackdropColor(br*0.4,bg2*0.4,bb*0.4,1); btn:SetBackdropBorderColor(br,bg2,bb,0.9)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local l=btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); l:SetAllPoints(btn); l:SetJustifyH("CENTER"); l:SetJustifyV("MIDDLE"); l:SetText(lbl)
        return btn
    end
    local allSortBtn = MakeSortDropdown(allHdr, fl + 12, function(mode)
        allSortMode = mode
        RefreshAllRows()
    end)
    allSortBtn:SetPoint("LEFT", allHdr, "LEFT", 4, 0)

    -- Page label (far right, dropdown trigger)
    -- Page button - same style as Sort
    local allPageBtn = CreateFrame("Button", "LichborneAllPageBtn", allHdr)
    allPageBtn:SetSize(55, 20)
    allPageBtn:SetPoint("RIGHT", allHdr, "RIGHT", -4, 0)
    allPageBtn:SetFrameLevel(fl+12)
    allPageBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    allPageBtn:SetBackdropColor(0.3*0.4, 0.4*0.4, 0.6*0.4, 1)
    allPageBtn:SetBackdropBorderColor(0.3, 0.4, 0.6, 0.9)
    allPageBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local allPageLbl = allPageBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    allPageLbl:SetAllPoints(allPageBtn); allPageLbl:SetJustifyH("CENTER"); allPageLbl:SetJustifyV("MIDDLE")
    allPageLbl:SetText("|cffaaccffPage 1  v|r")
    LichborneAllPageLbl  = allPageLbl
    LichborneAllPagePrev = nil
    LichborneAllPageNext = nil
    local allPrevBtn = {}
    local allNextBtn = {}

    -- Single group dropdown on the right (replaces both left Group: and page < > buttons)
    local function UpdateAllGroupDD()
        local g = LichborneTrackerDB.allGroup or "A"
        if LichborneAllPageLbl then
            local pageNum = ({A="1",B="2",C="3"})[g] or g
            LichborneAllPageLbl:SetText("|cffaaccffPage "..pageNum.."  v|r")
        end
        if LichborneAllPagePrev then LichborneAllPagePrev:SetAlpha(g ~= "A" and 1.0 or 0.35) end
        if LichborneAllPageNext then LichborneAllPageNext:SetAlpha(g ~= "C" and 1.0 or 0.35) end
    end
    UpdateAllGroupDD()

    -- Dropdown menu triggered by clicking the Group label
    local allGroupMenu = CreateFrame("Frame","LichborneAllGroupMenu",UIParent)
    allGroupMenu:SetFrameStrata("TOOLTIP"); allGroupMenu:SetSize(90,3*22+8)
    allGroupMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    allGroupMenu:SetBackdropColor(0.05,0.08,0.20,0.98); allGroupMenu:SetBackdropBorderColor(0.30,0.50,0.80,1)
    allGroupMenu:Hide()
    for gi, gname in ipairs({"A","B","C"}) do
        local mb=CreateFrame("Button",nil,allGroupMenu); mb:SetSize(86,20)
        mb:SetPoint("TOPLEFT",allGroupMenu,"TOPLEFT",2,-2-(gi-1)*22)
        mb:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        mb:SetBackdropColor(0.05,0.08,0.20,1); mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local mblbl=mb:CreateFontString(nil,"OVERLAY","GameFontNormal"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
        mblbl:SetText("|cffaaccffPage "..gi.."|r")
        local cap=gname
        mb:SetScript("OnClick",function()
            LichborneTrackerDB.allGroup=cap; UpdateAllGroupDD(); allGroupMenu:Hide(); RefreshAllRows()
        end)
    end
    -- Wire the page button to open the dropdown menu
    allPageBtn:SetScript("OnClick", function()
        if allGroupMenu:IsShown() then allGroupMenu:Hide()
        else allGroupMenu:ClearAllPoints(); allGroupMenu:SetPoint("TOPRIGHT",allPageBtn,"BOTTOMRIGHT",0,-2); allGroupMenu:Show() end
    end)

    -- Column headers (3 cols, same as raid)
    local RH_ALL = 22
    for col = 0, ALL_NCOLS-1 do
        local hdr = CreateFrame("Frame",nil,LichborneAllFrame)
        hdr:SetPoint("TOPLEFT",LichborneAllFrame,"TOPLEFT",col*ALL_COL_W,-26)
        hdr:SetSize(ALL_COL_W,18); hdr:SetFrameLevel(fl+11)
        local hbg=hdr:CreateTexture(nil,"BACKGROUND"); hbg:SetAllPoints(hdr); hbg:SetTexture(0.08,0.20,0.42,1)
        local function H(txt,x,w) local fs=hdr:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); fs:SetPoint("LEFT",hdr,"LEFT",x,0); fs:SetWidth(w); fs:SetJustifyH("CENTER"); fs:SetText(txt) end
        H("#",2,18); H("",20,18); H("",40,18); H("Name",62,148); H("GS",214,52); H("Tier",264,34)
    end

    -- 60 rows across 3 columns
    for i = 1, 60 do
        local col = math.floor((i-1)/ALL_PER_COL)
        local rowInCol = (i-1) % ALL_PER_COL
        local rf = CreateFrame("Frame",nil,LichborneAllFrame)
        rf:SetPoint("TOPLEFT",LichborneAllFrame,"TOPLEFT",col*ALL_COL_W,-(46+rowInCol*RH_ALL))
        rf:SetSize(ALL_COL_W, RH_ALL); rf:SetFrameLevel(fl+11)
        local rbg=rf:CreateTexture(nil,"BACKGROUND"); rbg:SetAllPoints(rf)
        rbg:SetTexture(rowInCol%2==0 and 0.06 or 0.04, rowInCol%2==0 and 0.08 or 0.06, rowInCol%2==0 and 0.16 or 0.12, 1)

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
        local nb=CreateFrame("EditBox",nil,rf); nb:SetPoint("LEFT",rf,"LEFT",60,0); nb:SetSize(150,RH_ALL-2)
        nb:SetAutoFocus(false); nb:SetMaxLetters(32); nb:SetFont("Fonts\\FRIZQT__.TTF",10); nb:SetTextColor(0.9,0.95,1.0)
        nb:SetScript("OnChar",function() nb:SetText(nb.readOnly or "") end)  -- read-only
        nb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        nb:SetBackdropColor(0.05,0.07,0.14,0.6); nb:SetBackdropBorderColor(0.12,0.18,0.30,0.5)
        nb:SetScript("OnEnterPressed",function() nb:ClearFocus() end); nb:SetScript("OnTabPressed",function() nb:ClearFocus() end)
        rf.nameBox=nb

        -- GS editbox
        local gb=CreateFrame("EditBox",nil,rf); gb:SetPoint("LEFT",rf,"LEFT",212,0); gb:SetSize(50,RH_ALL-2)
        gb:SetAutoFocus(false); gb:SetMaxLetters(5); gb:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE"); gb:SetTextColor(1,0.85,0); gb:SetJustifyH("CENTER")
        gb:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        gb:SetBackdropColor(0.05,0.07,0.14,0.6); gb:SetBackdropBorderColor(0.30,0.25,0.05,0.5)
        gb:SetScript("OnEnterPressed",function() gb:ClearFocus() end); gb:SetScript("OnTabPressed",function() gb:ClearFocus() end)
        rf.gsBox=gb

        -- Tier box (styled like GS)
        local tierBox3=CreateFrame("Frame",nil,rf); tierBox3:SetPoint("LEFT",rf,"LEFT",264,0); tierBox3:SetSize(34,RH_ALL-2)
        tierBox3:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        tierBox3:SetBackdropColor(0.05,0.07,0.14,1); tierBox3:SetBackdropBorderColor(0.30,0.25,0.05,0.5)
        local tierLbl=tierBox3:CreateFontString(nil,"OVERLAY"); tierLbl:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
        tierLbl:SetAllPoints(tierBox3); tierLbl:SetJustifyH("CENTER"); tierLbl:SetJustifyV("MIDDLE")
        tierLbl:SetTextColor(1,0.85,0); rf.tierLbl=tierLbl

        -- Add to Group btn >
        local ag=CreateFrame("Button",nil,rf); ag:SetPoint("LEFT",rf,"LEFT",300,0); ag:SetSize(16,RH_ALL-2)
        ag:SetNormalFontObject("GameFontNormalSmall"); ag:SetText("|cff44eeff>|r")
        ag:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        ag:SetScript("OnEnter",function() GameTooltip:SetOwner(ag,"ANCHOR_RIGHT"); GameTooltip:AddLine("|cff44eeff> Invite to Group|r",1,1,1); GameTooltip:Show() end)
        ag:SetScript("OnLeave",function() GameTooltip:Hide() end)
        rf.addGroupBtn=ag

        -- Add to Raid btn +
        local ar=CreateFrame("Button",nil,rf); ar:SetPoint("LEFT",rf,"LEFT",318,0); ar:SetSize(16,RH_ALL-2)
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
            GameTooltip:Show()
        end)
        ar:SetScript("OnLeave",function() GameTooltip:Hide() end)
        rf.addRaidBtn=ar

        -- No delete button on All tab (manage from class tabs)

        -- Divider
        local ln=rf:CreateTexture(nil,"OVERLAY"); ln:SetHeight(1); ln:SetWidth(ALL_COL_W)
        ln:SetPoint("BOTTOMLEFT",rf,"BOTTOMLEFT",0,0); ln:SetTexture(0.10,0.16,0.28,0.4)

        allRowFrames[i]=rf
    end

    -- Count bar at bottom
    local cbY = -(46 + ALL_PER_COL*RH_ALL + 2)  -- below last row
    local allCB = CreateFrame("Frame","LichborneAllCountBar",LichborneAllFrame)
    allCB:SetPoint("TOPLEFT",LichborneAllFrame,"TOPLEFT",0,cbY)
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
        sl:SetText(hex..(TAB_LABELS[cls])..": 0|r"); sw.lbl=sl; LichborneAllCountLabels[cls]=sl
    end
end


local function OnFirstShow()
    if setupDone then return end
    setupDone = true
    local f = LichborneTrackerFrame
    local fl = f:GetFrameLevel()

    -- Tabs
    local tabFrame = CreateFrame("Frame", "LichborneTabBar", f)
    tabFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -64)
    tabFrame:SetSize(1010, 28)
    tabFrame:SetFrameLevel(fl + 8)
    local tabW = 1010 / 12
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
        if cls == "Raid" or cls == "All" then
            hex = cls == "All" and "|cff44cc44" or "|cffC69B3A"
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
    hf:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -94)
    hf:SetSize(1020, 20)
    hf:SetFrameLevel(fl + 10)
    local hbg = hf:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints(hf); hbg:SetTexture(0.08, 0.20, 0.42, 1)

    -- Gold border wrapping header through count bar
    local contentBorder = CreateFrame("Frame", nil, f)
    contentBorder:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -92)
    contentBorder:SetSize(1024, 518)
    contentBorder:SetFrameLevel(fl + 9)
    contentBorder:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    contentBorder:SetBackdropColor(0, 0, 0, 0)
    contentBorder:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local function H(lbl, x, w)
        local fs = hf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", hf, "LEFT", x, 0)
        fs:SetWidth(w); fs:SetJustifyH("CENTER")
        fs:SetText("|cff90b8e8"..lbl.."|r")
    end
    local specHdr = hf:CreateTexture(nil, "OVERLAY")
    specHdr:SetPoint("LEFT", hf, "LEFT", SPEC_OFF + 1, 0)
    specHdr:SetSize(COL_SPEC_W - 2, 18)
    specHdr:SetTexture("Interface\\Icons\\Ability_Rogue_Deadliness")
    H("Name", NAME_OFF+2, COL_NAME_W-4)
    H("GS",   GS_OFF+2,   COL_GS_W-4)
    for g, a in ipairs(SLOT_ABBR) do H(a, GEAR_OFF+(g-1)*COL_GEAR_W, COL_GEAR_W) end
    H("Tier", TIER_OFF, COL_TIER_W)

    -- Sort dropdown button (far left, before drag handle)
    local classSortBtn = MakeSortDropdown(hf, hf:GetFrameLevel(), function(mode)
        classSortMode = mode
        RefreshRows()
    end)
    classSortBtn:SetPoint("LEFT", hf, "LEFT", 4, 0)

    -- Page controls (after Tier column)
    local pageX = TIER_OFF + COL_TIER_W + 8

    -- Page dropdown button (like Group: in All tab)
    local pageDDBtn = CreateFrame("Button", "LichbornePageDD", hf)
    pageDDBtn:SetPoint("RIGHT", hf, "RIGHT", -4, 0)
    pageDDBtn:SetSize(72, 16); pageDDBtn:SetFrameLevel(hf:GetFrameLevel()+2)
    pageDDBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=6,insets={left=1,right=1,top=1,bottom=1}})
    pageDDBtn:SetBackdropColor(0.08,0.14,0.30,1); pageDDBtn:SetBackdropBorderColor(0.30,0.50,0.80,0.9)
    pageDDBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local pageDDLbl = pageDDBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    pageDDLbl:SetAllPoints(pageDDBtn); pageDDLbl:SetJustifyH("CENTER"); pageDDLbl:SetJustifyV("MIDDLE")
    pageDDLbl:SetText("|cffaaccffPage 1  v|r")

    -- Dropdown menu
    local pageDDMenu = CreateFrame("Frame","LichbornePageDDMenu",UIParent)
    pageDDMenu:SetFrameStrata("TOOLTIP"); pageDDMenu:SetSize(74, MAX_PAGES*22+8)
    pageDDMenu:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    pageDDMenu:SetBackdropColor(0.05,0.08,0.20,0.98); pageDDMenu:SetBackdropBorderColor(0.30,0.50,0.80,1)
    pageDDMenu:Hide()
    for p = 1, MAX_PAGES do
        local mb = CreateFrame("Button",nil,pageDDMenu); mb:SetSize(70,20)
        mb:SetPoint("TOPLEFT",pageDDMenu,"TOPLEFT",2,-2-(p-1)*22)
        mb:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=1,right=1,top=1,bottom=1}})
        mb:SetBackdropColor(0.05,0.08,0.20,1); mb:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
        local mblbl = mb:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); mblbl:SetAllPoints(mb); mblbl:SetJustifyH("CENTER")
        mblbl:SetText("|cffaaccffPage "..p.."|r")
        local cap = p
        mb:SetScript("OnClick", function()
            classPage[activeTab] = cap
            pageDDMenu:Hide()
            RefreshRows()
        end)
    end
    pageDDBtn:SetScript("OnClick", function()
        if pageDDMenu:IsShown() then pageDDMenu:Hide()
        else
            pageDDMenu:ClearAllPoints()
            pageDDMenu:SetPoint("TOPLEFT", pageDDBtn, "BOTTOMLEFT", 0, -2)
            pageDDMenu:Show()
        end
    end)

    -- Store ref so RefreshRows can update the label
    LichbornePageLbl = pageDDLbl
    LichbornePageDD  = pageDDBtn

    -- Build row frames parented directly to main frame, below headers
    BuildRows(f, -118)

    -- Tier key
    local kf = CreateFrame("Frame", "LichborneTierKeyFrame", f)
    kf:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -36)
    kf:SetSize(1020, 30)
    kf:SetFrameLevel(fl + 10)
    local kbg = kf:CreateTexture(nil, "BACKGROUND")
    kbg:SetAllPoints(kf); kbg:SetTexture(0.04, 0.06, 0.12, 1)
    local tl = kf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tl:SetPoint("LEFT", kf, "LEFT", 4, 0); tl:SetText("|cffC69B3ATier Key:|r")
    local swW, sx = 51, 70
    for t = 1, 17 do
        local col  = t - 1
        local yOff = -3
        local c = TIER_COLORS[t]
        local sf = CreateFrame("Frame", nil, kf)
        sf:SetSize(swW-2, 22)
        sf:SetPoint("TOPLEFT", kf, "TOPLEFT", sx+col*swW, yOff)
        sf:SetFrameLevel(kf:GetFrameLevel()+1)
        local sbg = sf:CreateTexture(nil, "BACKGROUND")
        sbg:SetAllPoints(sf); sbg:SetTexture(c.r, c.g, c.b, 1)
        local lum = 0.299*c.r+0.587*c.g+0.114*c.b
        local tr,tg,tb = 1,1,1; if lum>0.45 then tr,tg,tb=0.05,0.05,0.05 end
        local lbl = sf:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        lbl:SetAllPoints(sf); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetTextColor(tr,tg,tb); lbl:SetText("T"..t)
        sf:EnableMouse(true)
        sf:SetScript("OnEnter", function()
            GameTooltip:SetOwner(sf, "ANCHOR_TOP")
            local tc = TIER_COLORS[t]
            local hex = string.format("%02x%02x%02x",math.floor(tc.r*255),math.floor(tc.g*255),math.floor(tc.b*255))
            GameTooltip:AddLine("|cff"..hex.."Tier "..t.."|r")
            GameTooltip:AddLine(TIER_LABELS[t],1,1,1); GameTooltip:Show()
        end)
        sf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Avg tier bar
    local avgFrame = CreateFrame("Frame", "LichborneAvgBar", f)
    LichborneAvgBar = avgFrame
    avgFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -558)
    avgFrame:SetSize(1010, 24)
    avgFrame:SetFrameLevel(fl + 10)
    local avgbg = avgFrame:CreateTexture(nil, "BACKGROUND")
    avgbg:SetAllPoints(avgFrame); avgbg:SetTexture(0.05, 0.07, 0.13, 1)
    local avgTitle = avgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgTitle:SetPoint("LEFT", avgFrame, "LEFT", 4, 0)
    avgTitle:SetText("|cffC69B3AAvg:|r"); avgTitle:SetWidth(36)
    LichborneAvgSwatches = {}
    local swW = (950 - 44) / 10
    local avgIdx = 0
    for i, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" then break end
        avgIdx = avgIdx + 1
        local c = CLASS_COLORS[cls]
        local sw = CreateFrame("Button", "LichborneAvgSwatch"..avgIdx, avgFrame)
        sw:SetSize(swW - 2, 20)
        sw:SetPoint("LEFT", avgFrame, "LEFT", 42 + (avgIdx-1)*swW, 0)
        sw:SetFrameLevel(avgFrame:GetFrameLevel() + 1)
        local swbg = sw:CreateTexture(nil, "BACKGROUND")
        swbg:SetAllPoints(sw); swbg:SetTexture(0.08, 0.10, 0.18, 1); sw.bg = swbg
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local lbl = sw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(sw); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(hex..(TAB_LABELS[cls])..": --|r"); sw.lbl = lbl; sw.cls = cls
        sw:EnableMouse(true)
        sw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(sw, "ANCHOR_TOP")
            local avg = GetClassAvgTier(cls)
            GameTooltip:AddLine(cls, c.r, c.g, c.b)
            if avg > 0 then
                local tc = TIER_COLORS[avg]
                local thex = string.format("%02x%02x%02x", math.floor(tc.r*255), math.floor(tc.g*255), math.floor(tc.b*255))
                GameTooltip:AddLine("Avg Tier: |cff"..thex.."T"..avg.."|r  ("..TIER_LABELS[avg]..")", 1,1,1)
            else
                GameTooltip:AddLine("No gear data yet", 0.6,0.6,0.6)
            end
            GameTooltip:AddLine("Click to switch to this tab", 0.5, 0.5, 0.5)
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

    -- ── Add Target button ──────────────────────────────────────
    local addBtn = CreateFrame("Button", "LichborneAddTargetBtn", f)
    addBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 112)
    addBtn:SetSize(155, 28)
    addBtn:SetFrameLevel(fl + 12)
    addBtn:SetBackdrop({
        bgFile="Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=8,
        insets={left=2,right=2,top=2,bottom=2}
    })
    addBtn:SetBackdropColor(0.05, 0.25, 0.30, 1)
    addBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local addBtnLabel = addBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addBtnLabel:SetAllPoints(addBtn)
    addBtnLabel:SetJustifyH("CENTER"); addBtnLabel:SetJustifyV("MIDDLE")
    addBtnLabel:SetText("|cffd4af37+ Add Target|r")
    addBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    local addStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -618)  -- just above Add Target row
    addStatus:SetWidth(880)
    addStatus:SetJustifyH("LEFT")
    addStatus:SetText("")
    LichborneAddStatus = addStatus

    addBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(addBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Add Target to Tracker", 1, 1, 1)
        GameTooltip:AddLine("Target a player, then click to", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("auto-detect class, name & GS", 0.8, 0.8, 0.8)
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
        local classMap = {
            DEATHKNIGHT="Death Knight", DRUID="Druid", HUNTER="Hunter",
            MAGE="Mage", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
            SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"
        }
        local cls = targetClass and classMap[targetClass]
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
                LichborneAddStatus:SetText(hex..targetName.."|r already in "..cls.." tab.")
                return
            end
        end

        local targetDi = nil
        local slotNum = 0
        for _, di in ipairs(indices) do
            slotNum = slotNum + 1
            local row = LichborneTrackerDB.rows[di]
            if not row.name or row.name == "" then
                targetDi = di
                break
            end
        end
        if not targetDi then
            LichborneAddStatus:SetText("|cffff4444"..cls.." tab is full ("..MAX_ROWS*MAX_PAGES.."/"..MAX_ROWS*MAX_PAGES..").|r")
            return
        end
        -- Auto-jump to the page containing the new slot
        classPage[cls] = math.ceil(slotNum / ROWS_PER_PAGE)

        LichborneTrackerDB.rows[targetDi].name = targetName

        local c = CLASS_COLORS[cls]
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        LichborneAddStatus:SetText("Inspecting "..hex..targetName.."|r ("..cls..")...")

        activeTab = cls
        UpdateTabs()
        RefreshRows()

        LichborneInspectTarget = targetDi
        LichborneSpecTarget = targetDi
        LichborneInspectUnit = "target"
        NotifyInspect("target")
        inspectWait = 0

        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Adding "..hex..targetName.."|r ("..cls..")...", 1, 0.85, 0)
    end)

    -- ── Add Group button ───────────────────────────────────────
    local addGroupBtn = CreateFrame("Button", "LichborneAddGroupBtn", f)
    addGroupBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 175, 112)
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
        GameTooltip:AddLine("Add Group to Tracker", 1, 1, 1)
        GameTooltip:AddLine("Scans all players in your party/raid", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("and adds them to their class tabs.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Skips duplicates automatically.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    addGroupBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addGroupBtn:SetScript("OnClick", function()
        -- Build list of group members INCLUDING self
        local members = {}
        local playerName = UnitName("player")
        -- Always add self first
        local _, selfClsKey = UnitClass("player")
        members[#members+1] = {name=playerName, clsKey=selfClsKey}
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local unit = "raid"..i
                if UnitExists(unit) and UnitName(unit) ~= playerName then
                    local name = UnitName(unit)
                    local _, clsKey = UnitClass(unit)
                    members[#members+1] = {name=name, clsKey=clsKey}
                end
            end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do
                local unit = "party"..i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    local _, clsKey = UnitClass(unit)
                    members[#members+1] = {name=name, clsKey=clsKey}
                end
            end
        end

        if #members == 0 then
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cffff4444Not in a group, or no other members found.|r")
            end
            return
        end

        local classMap = {
            DEATHKNIGHT="Death Knight", DRUID="Druid", HUNTER="Hunter",
            MAGE="Mage", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
            SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"
        }

        local added, skipped = 0, 0
        local toProcess = {}
        for _, m in ipairs(members) do
            local cls = m.clsKey and classMap[m.clsKey]
            if cls then
                toProcess[#toProcess+1] = {name=m.name, cls=cls}
            end
        end

        if #toProcess == 0 then
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cffff9900Could not determine class for group members.|r")
            end
            return
        end

        -- Process with delay to avoid UI freeze on large groups
        local idx = 1
        local waitTime = 0
        local addGroupFrame = CreateFrame("Frame")
        addGroupFrame:SetScript("OnUpdate", function()
            waitTime = waitTime + arg1
            if waitTime < 0.15 then return end  -- small gap between each
            waitTime = 0

            if idx > #toProcess then
                addGroupFrame:SetScript("OnUpdate", nil)
                if LichborneAddStatus then
                    LichborneAddStatus:SetText("|cff44ff44Added "..added.." new, skipped "..skipped.." duplicates.|r")
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Group scan complete. Added: "..added..", Skipped: "..skipped, 1, 0.85, 0)
                RefreshRows()
                return
            end

            local m = toProcess[idx]
            idx = idx + 1
            local cls = m.cls
            local name = m.name

            EnsureClass(cls)
            local indices = GetAllClassRows(cls)

            -- Check for duplicate
            for _, di in ipairs(indices) do
                local row = LichborneTrackerDB.rows[di]
                if row.name and row.name:lower() == name:lower() then
                    skipped = skipped + 1
                    return
                end
            end

            -- Find empty slot
            local slot = nil
            for _, di in ipairs(indices) do
                local row = LichborneTrackerDB.rows[di]
                if not row.name or row.name == "" then
                    slot = di; break
                end
            end

            if not slot then
                skipped = skipped + 1  -- tab full
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r "..cls.." tab full, skipped "..name, 1, 0.5, 0.5)
                return
            end

            LichborneTrackerDB.rows[slot].name = name
            added = added + 1

            local c = CLASS_COLORS[cls]
            local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Added "..hex..name.."|r ("..cls..")", 1, 0.85, 0)
        end)
    end)

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
    local gsBtn = MakeTrackerBtn("LichborneUpdateGSBtn", 15, 78, 155, 28, 0.20, 0.80, 0.90, "|cffd4af37+ Add Target GS|r")
    gsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(gsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("Get Target GS",1,1,1)
        GameTooltip:AddLine("Target a tracked player to refresh their gear score.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    gsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gsBtn:SetScript("OnClick", function()
        if not UnitExists("target") or not UnitIsPlayer("target") then LichborneAddStatus:SetText("|cffff4444No player targeted.|r"); return end
        local targetName = UnitName("target")
        local foundDi = nil
        for i, row in ipairs(LichborneTrackerDB.rows) do
            if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
        end
        if not foundDi then LichborneAddStatus:SetText("|cffff9900"..targetName.." not found. Use + Add Target first.|r"); return end
        local rowData = LichborneTrackerDB.rows[foundDi]
        local c = CLASS_COLORS[rowData.cls or ""]; local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        LichborneAddStatus:SetText("Updating GS for "..hex..targetName.."|r...")
        LichborneInspectTarget = foundDi; LichborneInspectUnit = "target"
        NotifyInspect("target"); inspectWait = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Updating GS for "..hex..targetName.."|r...", 1, 0.85, 0)
    end)

    -- ── Update Target Spec (row y=78, right) ──────────────────
    local tsBtn = MakeTrackerBtn("LichborneUpdateTargetSpecBtn", 15, 44, 155, 28, 0.20, 0.80, 0.90, "|cffd4af37+ Add Target Spec|r")
    tsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(tsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("Get Target Spec",1,1,1)
        GameTooltip:AddLine("Target a tracked player to read their talent spec.",0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    tsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tsBtn:SetScript("OnClick", function()
        if not UnitExists("target") or not UnitIsPlayer("target") then LichborneAddStatus:SetText("|cffff4444No player targeted.|r"); return end
        local targetName = UnitName("target")
        local foundDi = nil
        for i, row in ipairs(LichborneTrackerDB.rows) do
            if row.name and row.name:lower() == targetName:lower() then foundDi = i; break end
        end
        if not foundDi then LichborneAddStatus:SetText("|cffff9900"..targetName.." not found. Use + Add Target first.|r"); return end
        local rowData = LichborneTrackerDB.rows[foundDi]
        local c = CLASS_COLORS[rowData.cls or ""]; local hex = c and string.format("|cff%02x%02x%02x",math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255)) or "|cffffffff"
        LichborneAddStatus:SetText("Reading spec for "..hex..targetName.."|r...")
        LichborneSpecTarget = foundDi; LichborneInspectUnit = "target"
        LichborneTrackerDB.rows[foundDi].spec = ""
        NotifyInspect("target"); specWait = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Reading spec for "..hex..targetName.."|r...", 1, 0.85, 0)
    end)

    -- ── Update Group GS (row y=44, left) ──────────────────────
    local activeInspectFrame = nil  -- shared by GS and Spec scans; Stop button kills it
    local uggsBtn = MakeTrackerBtn("LichborneUpdateGroupGSBtn", 175, 78, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Group GS|r")
    uggsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(uggsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("Get Group GS",1,1,1)
        GameTooltip:AddLine("Inspects every tracked group member for gear score.",0.8,0.8,0.8)
        GameTooltip:AddLine("Allow ~2.5s per player.",0.6,0.6,0.6)
        GameTooltip:Show()
    end)
    uggsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    uggsBtn:SetScript("OnClick", function()
        local playerName = UnitName("player"); local units = {}
        units[#units+1] = "player"
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do local unit="raid"..i; if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit)~=playerName then units[#units+1]=unit end end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do local unit="party"..i; if UnitExists(unit) then units[#units+1]=unit end end
        end
        if #units == 0 then LichborneAddStatus:SetText("|cffff4444Not in a group.|r"); return end
        local totalTime = math.ceil(#units*2.5)
        LichborneAddStatus:SetText("|cffff9900Inspecting "..#units.." players (~"..totalTime.."s)...|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Starting group GS update for "..#units.." players...", 1, 0.85, 0)
        local idx,elapsed,inspecting = 1,0,false
        local gFrame = CreateFrame("Frame")
        activeInspectFrame = gFrame
        gFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if inspecting then if elapsed < 2.5 then return end; inspecting=false; elapsed=0 end
            if idx > #units then
                gFrame:SetScript("OnUpdate",nil)
                LichborneAddStatus:SetText("|cff44ff44Group GS update complete!|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cff44ff44Group GS update complete.|r", 1, 0.85, 0)
                RefreshRows(); return
            end
            local unit = units[idx]; if not UnitExists(unit) then idx=idx+1; return end
            local targetName = UnitName(unit); local foundDi = nil
            for i, row in ipairs(LichborneTrackerDB.rows) do if row.name and row.name:lower()==targetName:lower() then foundDi=i; break end end
            if not foundDi then DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)",1,0.6,0.3); idx=idx+1; return end
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Updating GS for "..tostring(targetName).."...", 1, 0.85, 0)
            LichborneAddStatus:SetText("Updating GS |cffffff88"..tostring(targetName).."|r... ("..(idx).."/"..#units..")")
            LichborneInspectTarget = foundDi; LichborneInspectUnit = unit
            NotifyInspect(unit); inspectWait=0; idx=idx+1; inspecting=true; elapsed=0
        end)
    end)

    -- ── Update Group Spec (row y=44, right) ───────────────────
    local ugsBtn = MakeTrackerBtn("LichborneUpdateGroupSpecBtn", 175, 44, 155, 28, 0.10, 0.40, 0.70, "|cffd4af37+ Add Group Spec|r")
    ugsBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(ugsBtn,"ANCHOR_TOP"); GameTooltip:AddLine("Get Group Spec",1,1,1)
        GameTooltip:AddLine("Reads talent spec for every tracked group member.",0.8,0.8,0.8)
        GameTooltip:AddLine("Allow ~3s per player.",0.6,0.6,0.6)
        GameTooltip:Show()
    end)
    ugsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ugsBtn:SetScript("OnClick", function()
        local playerName = UnitName("player"); local units = {}
        units[#units+1] = "player"
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do local unit="raid"..i; if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit)~=playerName then units[#units+1]=unit end end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do local unit="party"..i; if UnitExists(unit) then units[#units+1]=unit end end
        end
        if #units == 0 then LichborneAddStatus:SetText("|cffff4444Not in a group.|r"); return end
        local totalTime = math.ceil(#units*3)
        LichborneAddStatus:SetText("|cffff9900Reading spec for "..#units.." players (~"..totalTime.."s)...|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Starting group spec update for "..#units.." players...", 1, 0.85, 0)
        local idx,elapsed,inspecting = 1,0,false
        local sFrame = CreateFrame("Frame")
        activeInspectFrame = sFrame
        sFrame:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if inspecting then if elapsed < 3.0 then return end; inspecting=false; elapsed=0 end
            if idx > #units then
                sFrame:SetScript("OnUpdate",nil)
                LichborneAddStatus:SetText("|cff44ff44Group spec update complete!|r")
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cff44ff44Group spec update complete.|r", 1, 0.85, 0)
                RefreshRows(); if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end; return
            end
            local unit = units[idx]; if not UnitExists(unit) then idx=idx+1; return end
            local targetName = UnitName(unit); local foundDi = nil
            for i, row in ipairs(LichborneTrackerDB.rows) do if row.name and row.name:lower()==targetName:lower() then foundDi=i; break end end
            if not foundDi then DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Skipping "..tostring(targetName).." (not tracked)",1,0.6,0.3); idx=idx+1; return end
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Reading spec for "..tostring(targetName).."...", 1, 0.85, 0)
            LichborneAddStatus:SetText("Reading spec |cffffff88"..tostring(targetName).."|r... ("..(idx).."/"..#units..")")
            LichborneSpecTarget = foundDi; LichborneInspectUnit = unit
            if LichborneTrackerDB.rows[foundDi] then LichborneTrackerDB.rows[foundDi].spec="" end
            NotifyInspect(unit); specWait=0; idx=idx+1; inspecting=true; elapsed=0
        end)
    end)

    -- ── Stop Inspect button (below Get Group Spec) ────────────
    local stopInspectBtn = MakeTrackerBtn("LichborneStopInspectBtn", 175, 10, 155, 28, 0.90, 0.20, 0.20, "|cffd4af37Stop|r")
    stopInspectBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(stopInspectBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Stop", 1, 1, 1)
        GameTooltip:AddLine("Cancels the running GS or Spec scan.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    stopInspectBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stopInspectBtn:SetScript("OnClick", function()
        if activeInspectFrame then
            activeInspectFrame:SetScript("OnUpdate", nil)
            activeInspectFrame = nil
        end
        LichborneAddStatus:SetText("|cffff4444Scan stopped.|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffff4444Scan stopped.|r", 1, 0.85, 0)
    end)

    -- Row y=10: Add Target / Add Group (existing buttons stay here)
    -- Classes bar (exact copy of avg bar structure)
    local clsFrame = CreateFrame("Frame", "LichborneClassBar", f)
    LichborneCountBar = clsFrame
    clsFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -584)
    clsFrame:SetSize(1010, 24)
    clsFrame:SetFrameLevel(fl + 10)
    local clsbg = clsFrame:CreateTexture(nil, "BACKGROUND")
    clsbg:SetAllPoints(clsFrame); clsbg:SetTexture(0.05, 0.07, 0.13, 1)
    local clsTitle = clsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clsTitle:SetPoint("LEFT", clsFrame, "LEFT", 4, 0)
    clsTitle:SetText("|cffC69B3ACount:|r"); clsTitle:SetWidth(36)
    LichborneCountLabels = {}
    local cswW = (950 - 44) / 10
    local cswIdx = 0
    for i, cls in ipairs(CLASS_TABS) do
        if cls == "Raid" or cls == "All" then break end
        cswIdx = cswIdx + 1
        local c = CLASS_COLORS[cls]
        local csw = CreateFrame("Button", "LichborneClassSwatch"..cswIdx, clsFrame)
        csw:SetSize(cswW - 2, 20)
        csw:SetPoint("LEFT", clsFrame, "LEFT", 42 + (cswIdx-1)*cswW, 0)
        csw:SetFrameLevel(clsFrame:GetFrameLevel() + 1)
        local cswbg = csw:CreateTexture(nil, "BACKGROUND")
        cswbg:SetAllPoints(csw); cswbg:SetTexture(0.08, 0.10, 0.18, 1); csw.bg = cswbg
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local lbl = csw:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(csw); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")
        lbl:SetText(hex..(TAB_LABELS[cls])..": 0|r"); csw.lbl = lbl; csw.cls = cls
        LichborneCountLabels[cls] = lbl
        csw:EnableMouse(true)
        csw:SetScript("OnEnter", function()
            GameTooltip:SetOwner(csw, "ANCHOR_TOP")
            local n = 0
            for _, row in ipairs(LichborneTrackerDB.rows) do
                if row.cls == cls and row.name and row.name ~= "" then n = n + 1 end
            end
            GameTooltip:AddLine(cls, c.r, c.g, c.b)
            GameTooltip:AddLine(n.." character"..(n~=1 and "s" or "").." tracked", 1,1,1)
            GameTooltip:AddLine("Click to switch to this tab", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        csw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        csw:SetScript("OnClick", function()
            activeTab = cls
            UpdateTabs()
            RefreshRows()
        end)
    end

    -- Build raid frame
    BuildRaidFrame(f, fl)
    BuildAllFrame(f, fl)

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

    local maintBtn = MakeSimpleBtn("LichborneMaintBtn", "|cffd4af37Maintenance|r",
        0.2, 0.5, 0.9, 335, 112,
        nil, {{"Maintenance",1,1,1},{"Says 'maintenance' in group chat.",0.8,0.8,0.8},{"Bots learn spells, repair, enchant.",0.6,0.6,0.6}})
    maintBtn:SetScript("OnClick", function() SendChatMessage("maintenance", "PARTY") end)

    local autogearBtn = MakeSimpleBtn("LichborneAutogearBtn", "|cffd4af37AutoGear|r",
        0.2, 0.5, 0.9, 335, 78,
        nil, {{"AutoGear",1,1,1},{"Says 'autogear' in group chat.",0.8,0.8,0.8},{"Bots equip best available gear.",0.6,0.6,0.6}})
    autogearBtn:SetScript("OnClick", function() SendChatMessage("autogear", "PARTY") end)

    local loginBtn = MakeSimpleBtn("LichborneLoginBtn", "|cffd4af37Login All Bots|r",
        0.1, 0.6, 0.2, 335, 44,
        nil, {{"Login All Bots",1,1,1},{".playerbots bot add *",0.8,0.8,0.8}})
    loginBtn:SetScript("OnClick", function() SendChatMessage(".playerbots bot add *", "PARTY") end)

    local logoutBtn = MakeSimpleBtn("LichborneLogoutBtn", "|cffd4af37Logout All Bots|r",
        0.90, 0.20, 0.20, 335, 10,
        nil, {{"Logout All Bots",1,1,1},{".playerbots bot remove *",0.8,0.8,0.8}})
    logoutBtn:SetScript("OnClick", function() SendChatMessage(".playerbots bot remove *", "PARTY") end)

    -- ── Disband Group/Raid button ──────────────────────────────
    local disbandBtn = CreateFrame("Button", "LichborneDisbandBtn", f)
    disbandBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 10)
    disbandBtn:SetSize(155, 28)
    disbandBtn:SetFrameLevel(fl + 12)
    disbandBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    disbandBtn:SetBackdropColor(0.90*0.35, 0.20*0.35, 0.20*0.35, 1)
    disbandBtn:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    disbandBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local disbandLbl = disbandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disbandLbl:SetAllPoints(disbandBtn); disbandLbl:SetJustifyH("CENTER"); disbandLbl:SetJustifyV("MIDDLE")
    disbandLbl:SetText("|cffd4af37Disband Group / Raid|r")
    disbandBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(disbandBtn, "ANCHOR_TOP")
        GameTooltip:AddLine("Disband Group / Raid", 1, 1, 1)
        GameTooltip:AddLine("Kicks all members and disbands.", 0.8, 0.8, 0.8)
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
    disbText:SetText("|cffd4af37Disband Group / Raid?|r")
    local disbSub = disbConfirm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    disbSub:SetPoint("TOP", disbText, "BOTTOM", 0, -4)
    disbSub:SetText("|cffaaaaaaKicks all members and leaves the group.|r")

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
        local playerName = UnitName("player")
        local members = {}
        if GetNumRaidMembers() > 0 then
            for i = 1, GetNumRaidMembers() do
                local unit = "raid"..i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    if name and name ~= playerName then members[#members+1] = name end
                end
            end
        elseif GetNumPartyMembers() > 0 then
            for i = 1, GetNumPartyMembers() do
                local unit = "party"..i
                if UnitExists(unit) then
                    local name = UnitName(unit)
                    if name and name ~= playerName then members[#members+1] = name end
                end
            end
        end
        if #members == 0 then
            LeaveParty()
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffd4af37Group disbanded.|r", 1, 0.85, 0)
            return
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffd4af37Disbanding - kicking " .. #members .. " members...|r", 1, 0.85, 0)
        local idx = 1
        local waited = 0
        local phase = "kick"
        local disbFrame = CreateFrame("Frame")
        disbFrame:SetScript("OnUpdate", function()
            waited = waited + arg1
            if phase == "kick" then
                if waited < 0.2 then return end
                waited = 0
                if idx > #members then phase = "leave"; waited = 0; return end
                local name = members[idx]
                SendChatMessage(".playerbots bot remove " .. name, "SAY")
                UninviteUnit(name)
                idx = idx + 1
            elseif phase == "leave" then
                if waited < 1.0 then return end
                LeaveParty()
                DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffd4af37All members kicked. Group disbanded.|r", 1, 0.85, 0)
                disbFrame:SetScript("OnUpdate", nil)
            end
        end)
    end)

    disbandBtn:SetScript("OnClick", function()
        disbConfirm:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        disbConfirm:Show()
    end)

    -- ── Version / Info box (right of Stop Invite) ─────────────
    local infoBox = CreateFrame("Frame", nil, f)
    infoBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 895, 10)
    infoBox:SetSize(155, 130)
    infoBox:SetFrameLevel(fl + 11)
    infoBox:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    infoBox:SetBackdropColor(0, 0, 0, 0)
    infoBox:SetBackdropBorderColor(0.78, 0.61, 0.23, 0.9)
    local infoText = infoBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("CENTER", infoBox, "CENTER", 0, 0)
    infoText:SetWidth(140)
    infoText:SetJustifyH("CENTER"); infoText:SetJustifyV("MIDDLE")
    infoText:SetText(
        "|cffd4af37LICHBORNE|r\n" ..
        "|cffd4af37Gear Tracker|r\n" ..
        "|cffd4af37v1.50|r\n" ..
        "\n" ..
        "|cffaaaaaaQuestions & Support:|r\n" ..
        "|cffd4af37lichborne.wow|r\n" ..
        "|cffd4af37@proton.me|r"
    )

end

UpdateSummary = function()
    if not LichborneAvgSwatches then return end
    for _, sw in ipairs(LichborneAvgSwatches) do
        local cls = sw.cls
        if cls == "Raid" then break end
        local avg = GetClassAvgTier(cls)
        local c = CLASS_COLORS[cls]
        if not c then break end
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        if avg > 0 then
            local tc = TIER_COLORS[avg]
            sw.bg:SetTexture(tc.r*0.4, tc.g*0.4, tc.b*0.4, 1)
            local thex = string.format("%02x%02x%02x", math.floor(tc.r*255), math.floor(tc.g*255), math.floor(tc.b*255))
            sw.lbl:SetText(hex..(TAB_LABELS[cls])..": |cff"..thex.."T"..avg.."|r")
        else
            sw.bg:SetTexture(0.08, 0.10, 0.18, 1)
            sw.lbl:SetText(hex..(TAB_LABELS[cls])..": |cff444444--|r")
        end
    end
    if not LichborneCountLabels then return end
    local counts = {}
    for _, cls in ipairs(CLASS_TABS) do if cls ~= "Raid" then counts[cls] = 0 end end
    for _, row in ipairs(LichborneTrackerDB.rows) do
        if row.name and row.name ~= "" and counts[row.cls] then
            counts[row.cls] = counts[row.cls] + 1
        end
    end
    local classIndex = {["Death Knight"]=1,["Druid"]=2,["Hunter"]=3,["Mage"]=4,["Paladin"]=5,["Priest"]=6,["Rogue"]=7,["Shaman"]=8,["Warlock"]=9,["Warrior"]=10}
    for cls, lbl in pairs(LichborneCountLabels) do
        local c = CLASS_COLORS[cls]
        if not c then break end
        local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        local n = counts[cls]
        lbl:SetText(hex..(TAB_LABELS[cls])..": "..n.."|r")
        local sw = _G["LichborneCountSwatch"..classIndex[cls]]
        if sw and sw.bg then
            if n > 0 then sw.bg:SetTexture(c.r*0.25, c.g*0.25, c.b*0.30, 1)
            else sw.bg:SetTexture(0.08, 0.10, 0.18, 1) end
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
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    title:SetText("|cffC69B3ALICHBORNE|r  —  Gear Tracker")
    local closeBtn = CreateFrame("Button", "LichborneCloseBtn", f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

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
        "This permanently deletes ALL tracked characters,\ngear data, raid rosters, and the All list.",
        function()
            LichborneTrackerDB.rows = {}
            LichborneTrackerDB.raidRosters = {}
            LichborneTrackerDB.allRows = {}
            for i=1,60 do LichborneTrackerDB.allRows[i]={name="",cls="",spec="",gs=0} end
            LichborneTrackerDB.raidName = "Molten Core"
            LichborneTrackerDB.raidSize = 40
            LichborneTrackerDB.raidTier = 1
            LichborneTrackerDB.raidGroup = "A"
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffff4444All data wiped.|r", 1, 0.5, 0.5)
            RefreshRows()
            if LichborneAllFrame then RefreshAllRows() end
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        end
    )

    -- Confirm: Clear all raid rosters only
    local confirmRaids = MakeDangerConfirm(
        "⚠  Wipe All Raid Rosters?",
        "This clears every raid roster (all tiers, raids,\nand groups A/B/C). Characters remain in class tabs.",
        function()
            LichborneTrackerDB.raidRosters = {}
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r |cffff9900All raid rosters cleared.|r", 1, 0.7, 0)
            if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
        end
    )

    -- Clear Raids button
    local clrRaidsBtn = CreateFrame("Button", nil, f)
    clrRaidsBtn:SetSize(100, 20)
    clrRaidsBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -5)
    clrRaidsBtn:SetFrameLevel(f:GetFrameLevel()+10)
    clrRaidsBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    clrRaidsBtn:SetBackdropColor(0.25,0.05,0.05,1); clrRaidsBtn:SetBackdropBorderColor(0.70,0.15,0.15,0.8)
    clrRaidsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local clrRaidsLbl=clrRaidsBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); clrRaidsLbl:SetAllPoints(clrRaidsBtn); clrRaidsLbl:SetJustifyH("CENTER")
    clrRaidsLbl:SetText("|cffff8888Clear Raids|r")
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
    clrAllBtn:SetPoint("RIGHT", clrRaidsBtn, "LEFT", -4, 0)
    clrAllBtn:SetFrameLevel(f:GetFrameLevel()+10)
    clrAllBtn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
    clrAllBtn:SetBackdropColor(0.35,0.04,0.04,1); clrAllBtn:SetBackdropBorderColor(0.90,0.10,0.10,0.9)
    clrAllBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    local clrAllLbl=clrAllBtn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); clrAllLbl:SetAllPoints(clrAllBtn); clrAllLbl:SetJustifyH("CENTER")
    clrAllLbl:SetText("|cffff4444Clear All Data|r")
    clrAllBtn:SetScript("OnEnter",function()
        GameTooltip:SetOwner(clrAllBtn,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Wipe Entire Database",1,0.3,0.3)
        GameTooltip:AddLine("Permanently deletes ALL characters,",0.8,0.8,0.8)
        GameTooltip:AddLine("gear data, raid rosters, and the All list.",0.8,0.8,0.8)
        GameTooltip:AddLine("|cffff4444This cannot be undone.|r",1,0.4,0.4)
        GameTooltip:Show()
    end)
    clrAllBtn:SetScript("OnLeave",function() GameTooltip:Hide() end)
    clrAllBtn:SetScript("OnClick",function() confirmAll:Show() end)
end

function LichborneTracker_Open()
    if not activeTab then activeTab = "All" end
    BuildFrameBG()
    OnFirstShow()
    LichborneTrackerFrame:Show()
    UpdateTabs()
    RefreshRows()
end

-- ── Minimap button ────────────────────────────────────────────
local LichborneMinimapIcon = LibStub("LibDBIcon-1.0", true)
local miniLDB = LibStub("LibDataBroker-1.1"):NewDataObject("LichborneTracker", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    OnClick = function(self, btn)
        if LichborneTrackerFrame:IsShown() then
            LichborneTrackerFrame:Hide()
        else
            LichborneTracker_Open()
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cffC69B3ALichborne Gear Tracker|r")
        tooltip:AddLine("Click to open / close", 1,1,1)
        tooltip:AddLine("Drag to reposition", 0.7,0.7,0.7)
    end,
})

-- ── Initialization ────────────────────────────────────────────
-- ESC key support: insert into UISpecialFrames at Lua load time so WoW hides the
-- frame when ESC is pressed (same pattern used by DBM).
table.insert(_G["UISpecialFrames"], "LichborneTrackerFrame")

do
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function()
        if arg1 == "LichborneTracker" then
            -- Register minimap icon with its own SavedVariable (so position persists correctly)
            if type(LichborneMinimapIconDB) ~= "table" then
                LichborneMinimapIconDB = {}
            end
            if LichborneMinimapIcon then
                LichborneMinimapIcon:Register("LichborneTracker", miniLDB, LichborneMinimapIconDB)
                LichborneMinimapIcon:Refresh("LichborneTracker", LichborneMinimapIconDB)
            end
            -- Repair all raid rosters: fill any nil/missing slots
            if LichborneTrackerDB and LichborneTrackerDB.raidRosters then
                for key, roster in pairs(LichborneTrackerDB.raidRosters) do
                    if type(roster) == "table" then
                        for i = 1, 40 do
                            if not roster[i] or type(roster[i]) ~= "table" then
                                roster[i] = {name="",cls="",spec="",gs=0,role="",notes=""}
                            else
                                if roster[i].role == nil then roster[i].role = "" end
                                if roster[i].notes == nil then roster[i].notes = "" end
                                if roster[i].name == nil then roster[i].name = "" end
                                if roster[i].cls == nil then roster[i].cls = "" end
                                if roster[i].spec == nil then roster[i].spec = "" end
                                if roster[i].gs == nil then roster[i].gs = 0 end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ── Spec / Talent handler ─────────────────────────────────────
LichborneSpecTarget = nil
local specRetries = 0
local MAX_SPEC_RETRIES = 3

local function CalcSpec()
    local di = LichborneSpecTarget
    if not di then return end
    local rowData = LichborneTrackerDB.rows[di]
    if not rowData then LichborneSpecTarget = nil; specRetries = 0; return end

    local cls = rowData.cls or ""
    local specNames = CLASS_SPECS[cls]
    if not specNames then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Unknown class: "..cls, 1, 0.5, 0.5)
        LichborneSpecTarget = nil; specRetries = 0
        return
    end

    -- WotLK 3.3.5a: pass inspect=true to read target's talents
    local inspectSelf = (LichborneInspectUnit and UnitIsUnit(LichborneInspectUnit, "player"))
    local treePts = {0, 0, 0}
    for tab = 1, 3 do
        local numTalents = GetNumTalents(tab, inspectSelf and false or true)
        if numTalents and numTalents > 0 then
            for t = 1, numTalents do
                local name, _, _, _, currRank = GetTalentInfo(tab, t, inspectSelf and false or true)
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
        local _, _, pts = GetTalentTabInfo(tab, inspectSelf and false or true)
        if pts and pts > 0 then
            tabPts[tab] = pts
            gotTabData = true
        end
    end
    -- Prefer tabPts if available, else fall back to treePts
    local pts = gotTabData and tabPts or treePts

    local best, bestPoints = 1, 0
    for tab = 1, 3 do
        if pts[tab] > bestPoints then
            bestPoints = pts[tab]
            best = tab
        end
    end

    if bestPoints == 0 then
        specRetries = specRetries + 1
        if specRetries >= MAX_SPEC_RETRIES then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Could not read talent data for "..tostring(rowData.name)..". Target may need to be in range.", 1, 0.5, 0.5)
            if LichborneAddStatus then
                LichborneAddStatus:SetText("|cffff9900Talent data unavailable. Try standing closer.|r")
            end
            LichborneSpecTarget = nil; specRetries = 0
        end
        -- else: silent retry, no spam
        return
    end

    specRetries = 0
    local specName = specNames[best] or ""
    rowData.spec = specName

    local c = CLASS_COLORS[cls]
    local hex = c and string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255)) or "|cffffffff"
    if LichborneAddStatus then
        LichborneAddStatus:SetText(hex..(rowData.name or "?").."|r — Spec: |cffffff00"..specName.."|r ("..bestPoints.." pts)")
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Spec: |cffffff00"..specName.."|r ("..bestPoints.." pts)", 1, 0.85, 0)

    ClearInspectPlayer()
    LichborneSpecTarget = nil
    RefreshRows()
end

local specWait = 0
local specFrame = CreateFrame("Frame")
specFrame:SetScript("OnUpdate", function()
    if not LichborneSpecTarget then return end
    specWait = specWait + arg1
    if specWait >= 2.0 then
        specWait = 0
        CalcSpec()
    end
end)
specFrame:RegisterEvent("INSPECT_READY")
specFrame:SetScript("OnEvent", function()
    if not LichborneSpecTarget then return end
    specWait = 0
    CalcSpec()
end)

-- ── Inspect handler ───────────────────────────────────────────
LichborneInspectTarget = nil
LichborneInspectRow = nil
LichborneInspectUnit = "target"  -- unit token for current inspect

local function CalcGS()
    local di = LichborneInspectTarget
    if not di then return end
    local inspUnit = LichborneInspectUnit or "target"
    local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
    local total, count = 0, 0
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink(inspUnit, slot)
        if link then
            local _, _, _, ilvl = GetItemInfo(link)
            if ilvl and ilvl > 0 then
                total = total + ilvl
                count = count + 1
            end
        end
    end
    if count > 0 then
        local gs = math.floor(total / count)
        LichborneTrackerDB.rows[di].gs = gs
        local rowData = LichborneTrackerDB.rows[di]
        -- Find the row frame by dbIndex and update gsBox
        for _, row in ipairs(rowFrames) do
            if row.dbIndex == di and row.gsBox then
                row.gsBox:SetText(tostring(gs))
                break
            end
        end
        -- Update Add Target status label
        if LichborneAddStatus then
            local name = rowData.name or "?"
            local cls  = rowData.cls  or "?"
            local c = CLASS_COLORS[cls]
            if c then
                local hex = string.format("|cff%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
                LichborneAddStatus:SetText(hex..name.."|r ("..cls..") — GS |cffffff00"..gs.."|r added!")
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r GS: |cffffff00"..gs.."|r ("..count.." slots)", 1, 0.85, 0)

        -- Auto-read spec if target is the local player (inspect data = self)
        local targetName = UnitName("target")
        if targetName and targetName == UnitName("player") then
            local rowData2 = LichborneTrackerDB.rows[di]
            local cls2 = rowData2 and rowData2.cls or ""
            local specNames2 = CLASS_SPECS[cls2]
            if specNames2 then
                local best2, bestPts2 = 1, 0
                for tab = 1, 3 do
                    local _, _, pts = GetTalentTabInfo(tab)
                    if pts and pts > bestPts2 then bestPts2 = pts; best2 = tab end
                end
                if bestPts2 > 0 then
                    rowData2.spec = specNames2[best2]
                    DEFAULT_CHAT_FRAME:AddMessage("|cffC69B3ALichborne:|r Spec: |cffffff00"..specNames2[best2].."|r ("..bestPts2.." pts)", 1, 0.85, 0)
                end
            end
        end

        RefreshRows()
        if raidRowFrames and #raidRowFrames > 0 then RefreshRaidRows() end
    else
        if LichborneAddStatus then
            LichborneAddStatus:SetText("|cffff9900No gear data returned. Target may need to be closer.|r")
        end
    end
    ClearInspectPlayer()
    LichborneInspectTarget = nil
    LichborneInspectRow = nil
end

local inspectFrame = CreateFrame("Frame")
inspectWait = 0
inspectFrame:SetScript("OnUpdate", function()
    if not LichborneInspectTarget then return end
    inspectWait = inspectWait + arg1
    if inspectWait >= 1.5 then
        inspectWait = 0
        CalcGS()
    end
end)

-- Also try INSPECT_READY in case server supports it
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function()
    if not LichborneInspectTarget then return end
    inspectWait = 0
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

        -- Perform swap if we found a valid target
        if targetRow then
            local a = dragSourceRow.dbIndex
            local b = targetRow.dbIndex
            if a and b then
                local tmp = LichborneTrackerDB.rows[a]
                LichborneTrackerDB.rows[a] = LichborneTrackerDB.rows[b]
                LichborneTrackerDB.rows[b] = tmp
                RefreshRows()
            end
        end

        -- Reset all visual state
        for _, rf in ipairs(rowFrames) do
            rf.hov:SetTexture(0, 0, 0, 0)
            rf.dropHi:SetTexture(0, 0, 0, 0)
            if rf.dragTex then rf.dragTex:SetVertexColor(0.3, 0.4, 0.6, 0.8) end
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
    if LichborneTrackerFrame:IsShown() then
        LichborneTrackerFrame:Hide()
    else
        LichborneTracker_Open()
    end
end

