-- Avid Angler
-- Catch tracking & stats pillar: what's been caught, when, and where.
--
-- This window reads from Core's shared catch-record stream. Tracking never
-- reads loot itself; it consumes AvidAngler.DataLayer and the
-- CATCH_RECORDED broadcast.

local ADDON_NAME, AvidAngler = ...

local Tracking = {}
AvidAngler.Modules.Tracking = Tracking

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L

local MODE_ALL = "all"
local MODE_SESSION = "session"
local MODE_ZONE = "zone"
local SCOPE_WARBAND = "warband"
local SCOPE_CHARACTER = "character"
local EXPANSION_ALL = "all"
local MAX_VISIBLE_ROWS = 10
local ROW_HEIGHT = Theme.layout.rowHeight + 2

local historyMode = MODE_ALL
local pageOffset = 0
local sessionStartIndex = 1
local sessionStartCastIndex = 1
local sessionStartTime = nil
local moduleEnabled = true
local zoneNameCache = {}
local statsCache = {}
local analyticsCache = {}
local expansionsCache = {}
local itemQualityCache = {}
local equippableCache = {}
local catchTypeCache = setmetatable({}, { __mode = "k" })

local EXPANSIONS = {
    { key = EXPANSION_ALL, labelKey = "CATCH_FILTER_EXPANSION_ALL" },
    { key = "midnight", labelKey = "CATCH_FILTER_EXPANSION_MIDNIGHT" },
    { key = "warWithin", labelKey = "CATCH_FILTER_EXPANSION_WAR_WITHIN" },
    { key = "dragonflight", labelKey = "CATCH_FILTER_EXPANSION_DRAGONFLIGHT" },
    { key = "shadowlands", labelKey = "CATCH_FILTER_EXPANSION_SHADOWLANDS" },
    { key = "battleForAzeroth", labelKey = "CATCH_FILTER_EXPANSION_BATTLE_FOR_AZEROTH" },
    { key = "legion", labelKey = "CATCH_FILTER_EXPANSION_LEGION" },
    { key = "warlords", labelKey = "CATCH_FILTER_EXPANSION_WARLORDS" },
    { key = "pandaria", labelKey = "CATCH_FILTER_EXPANSION_PANDARIA" },
    { key = "cataclysm", labelKey = "CATCH_FILTER_EXPANSION_CATACLYSM" },
    { key = "northrend", labelKey = "CATCH_FILTER_EXPANSION_NORTHREND" },
    { key = "outland", labelKey = "CATCH_FILTER_EXPANSION_OUTLAND" },
    { key = "classic", labelKey = "CATCH_FILTER_EXPANSION_CLASSIC" },
    { key = "other", labelKey = "CATCH_FILTER_EXPANSION_OTHER" },
}

local EXPANSION_BY_KEY = {}
for _, expansion in ipairs(EXPANSIONS) do
    EXPANSION_BY_KEY[expansion.key] = expansion
end

local OPEN_WATER_ONLY_ZONE_MAP_IDS = {
    [2351] = true, -- Razorwind Shores
    [2352] = true, -- Founder's Point
}

local function NormalizeItemName(name)
    if not name or name == "" then
        return nil
    end
    return tostring(name):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local ZONE_EXPANSIONS = {
    ["Slayer's Rise"] = "midnight",
    ["Founder's Point"] = "warWithin",
    ["Razorwind Shores"] = "warWithin",
    ["Eversong Woods"] = "midnight",
    ["Harandar"] = "midnight",
    ["Zul'Aman"] = "midnight",
    ["Voidstorm"] = "midnight",
    ["The Coiled Isle"] = "midnight",
    ["Vaults of Ata'Tuek"] = "midnight",
    ["Isle of Dorn"] = "warWithin",
    ["The Ringing Deeps"] = "warWithin",
    ["Hallowfall"] = "warWithin",
    ["Azj-Kahet"] = "warWithin",
    ["The Waking Shores"] = "dragonflight",
    ["Ohn'ahran Plains"] = "dragonflight",
    ["The Azure Span"] = "dragonflight",
    ["Thaldraszus"] = "dragonflight",
    ["Valdrakken"] = "dragonflight",
    ["Oribos"] = "shadowlands",
    ["Bastion"] = "shadowlands",
    ["Maldraxxus"] = "shadowlands",
    ["Ardenweald"] = "shadowlands",
    ["Revendreth"] = "shadowlands",
    ["Zuldazar"] = "battleForAzeroth",
    ["Nazmir"] = "battleForAzeroth",
    ["Vol'dun"] = "battleForAzeroth",
    ["Tiragarde Sound"] = "battleForAzeroth",
    ["Drustvar"] = "battleForAzeroth",
    ["Stormsong Valley"] = "battleForAzeroth",
    ["Broken Shore"] = "legion",
    ["Azsuna"] = "legion",
    ["Highmountain"] = "legion",
    ["Stormheim"] = "legion",
    ["Suramar"] = "legion",
    ["Val'sharah"] = "legion",
    ["Frostfire Ridge"] = "warlords",
    ["Gorgrond"] = "warlords",
    ["Shadowmoon Valley"] = "warlords",
    ["Spires of Arak"] = "warlords",
    ["Talador"] = "warlords",
    ["Dread Wastes"] = "pandaria",
    ["Krasarang Wilds"] = "pandaria",
    ["Kun-Lai Summit"] = "pandaria",
    ["The Jade Forest"] = "pandaria",
    ["Townlong Steppes"] = "pandaria",
    ["Vale of Eternal Blossoms"] = "pandaria",
    ["Valley of the Four Winds"] = "pandaria",
    ["Deepholm"] = "cataclysm",
    ["Mount Hyjal"] = "cataclysm",
    ["Twilight Highlands"] = "cataclysm",
    ["Uldum"] = "cataclysm",
    ["Vashj'ir"] = "cataclysm",
    ["Borean Tundra"] = "northrend",
    ["Dragonblight"] = "northrend",
    ["Grizzly Hills"] = "northrend",
    ["Howling Fjord"] = "northrend",
    ["Icecrown"] = "northrend",
    ["Sholazar Basin"] = "northrend",
    ["Zangarmarsh"] = "outland",
    ["Terokkar Forest"] = "outland",
    ["Hellfire Peninsula"] = "outland",
    ["Nagrand"] = "outland",
    ["Alterac Mountains"] = "classic",
    ["Arathi Highlands"] = "classic",
    ["Ashenvale"] = "classic",
    ["Azshara"] = "classic",
    ["Azuremyst Isle"] = "classic",
    ["Badlands"] = "classic",
    ["Blasted Lands"] = "classic",
    ["Bloodmyst Isle"] = "classic",
    ["Burning Steppes"] = "classic",
    ["Darkshore"] = "classic",
    ["Darnassus"] = "classic",
    ["Deadwind Pass"] = "classic",
    ["Desolace"] = "classic",
    ["Dun Morogh"] = "classic",
    ["Durotar"] = "classic",
    ["Duskwood"] = "classic",
    ["Dustwallow Marsh"] = "classic",
    ["Eastern Plaguelands"] = "classic",
    ["Elwynn Forest"] = "classic",
    ["Felwood"] = "classic",
    ["Feralas"] = "classic",
    ["Ghostlands"] = "classic",
    ["Gilneas"] = "classic",
    ["Hillsbrad Foothills"] = "classic",
    ["Ironforge"] = "classic",
    ["Loch Modan"] = "classic",
    ["Moonglade"] = "classic",
    ["Mulgore"] = "classic",
    ["Northern Barrens"] = "classic",
    ["Northern Stranglethorn"] = "classic",
    ["Orgrimmar"] = "classic",
    ["Redridge Mountains"] = "classic",
    ["Ruins of Gilneas"] = "classic",
    ["Searing Gorge"] = "classic",
    ["Silithus"] = "classic",
    ["Silvermoon City"] = "classic",
    ["Silverpine Forest"] = "classic",
    ["Southern Barrens"] = "classic",
    ["Stonetalon Mountains"] = "classic",
    ["Stormwind City"] = "classic",
    ["Stranglethorn Vale"] = "classic",
    ["Sunken Temple"] = "classic",
    ["Swamp of Sorrows"] = "classic",
    ["Tanaris"] = "classic",
    ["Teldrassil"] = "classic",
    ["The Cape of Stranglethorn"] = "classic",
    ["The Hinterlands"] = "classic",
    ["Thunder Bluff"] = "classic",
    ["Tirisfal Glades"] = "classic",
    ["Undercity"] = "classic",
    ["Un'Goro Crater"] = "classic",
    ["Western Plaguelands"] = "classic",
    ["Westfall"] = "classic",
    ["Wetlands"] = "classic",
    ["Winterspring"] = "classic",
}

local MAP_EXPANSIONS = {
    [2393] = "midnight",
    [2395] = "midnight",
    [2405] = "midnight",
    [2437] = "midnight",
    [2509] = "midnight",
    [2512] = "midnight",
    [2213] = "warWithin",
    [2214] = "warWithin",
    [2215] = "warWithin",
    [2248] = "warWithin",
    [2255] = "warWithin",
    [2339] = "warWithin",
    [2351] = "warWithin",
    [2352] = "warWithin",
    [2401] = "warWithin",
    [2402] = "warWithin",
    [2022] = "dragonflight",
    [2023] = "dragonflight",
    [2024] = "dragonflight",
    [2025] = "dragonflight",
    [2112] = "dragonflight",
    [1525] = "shadowlands",
    [1533] = "shadowlands",
    [1536] = "shadowlands",
    [1565] = "shadowlands",
    [1670] = "shadowlands",
    [862] = "battleForAzeroth",
    [863] = "battleForAzeroth",
    [864] = "battleForAzeroth",
    [895] = "battleForAzeroth",
    [896] = "battleForAzeroth",
    [942] = "battleForAzeroth",
    [1161] = "battleForAzeroth",
    [1165] = "battleForAzeroth",
    [627] = "legion",
    [630] = "legion",
    [634] = "legion",
    [641] = "legion",
    [646] = "legion",
    [650] = "legion",
    [680] = "legion",
    [525] = "warlords",
    [535] = "warlords",
    [539] = "warlords",
    [542] = "warlords",
    [543] = "warlords",
    [572] = "warlords",
    [371] = "pandaria",
    [376] = "pandaria",
    [379] = "pandaria",
    [388] = "pandaria",
    [390] = "pandaria",
    [418] = "pandaria",
    [422] = "pandaria",
    [198] = "cataclysm",
    [203] = "cataclysm",
    [207] = "cataclysm",
    [241] = "cataclysm",
    [249] = "cataclysm",
    [114] = "northrend",
    [115] = "northrend",
    [116] = "northrend",
    [117] = "northrend",
    [118] = "northrend",
    [119] = "northrend",
    [102] = "outland",
    [100] = "outland",
    [107] = "outland",
    [108] = "outland",
    [1] = "classic",
    [7] = "classic",
    [10] = "classic",
    [14] = "classic",
    [15] = "classic",
    [18] = "classic",
    [21] = "classic",
    [22] = "classic",
    [23] = "classic",
    [25] = "classic",
    [26] = "classic",
    [27] = "classic",
    [32] = "classic",
    [36] = "classic",
    [37] = "classic",
    [42] = "classic",
    [47] = "classic",
    [48] = "classic",
    [49] = "classic",
    [50] = "classic",
    [51] = "classic",
    [52] = "classic",
    [56] = "classic",
    [57] = "classic",
    [62] = "classic",
    [63] = "classic",
    [64] = "classic",
    [66] = "classic",
    [69] = "classic",
    [70] = "classic",
    [71] = "classic",
    [76] = "classic",
    [77] = "classic",
    [78] = "classic",
    [81] = "classic",
    [83] = "classic",
    [84] = "classic",
    [85] = "classic",
    [87] = "classic",
    [88] = "classic",
    [89] = "classic",
    [90] = "classic",
    [97] = "classic",
    [103] = "classic",
    [110] = "classic",
    [174] = "classic",
    [179] = "classic",
    [194] = "classic",
    [199] = "classic",
    [210] = "classic",
    [217] = "classic",
    [224] = "classic",
}

local historyFrame = CreateFrame("Frame", "AvidAnglerHistoryFrame", UIParent, "BackdropTemplate")
historyFrame:SetSize(500, Theme.layout.headerHeight + 160 + MAX_VISIBLE_ROWS * ROW_HEIGHT + Theme.layout.padding)
historyFrame:SetPoint("CENTER")
historyFrame:SetFrameStrata("DIALOG")
historyFrame:SetBackdrop((Theme:Backdrop("backdrop", "border")))
historyFrame:SetBackdropColor(unpack(Theme.color.backdrop))
historyFrame:SetBackdropBorderColor(unpack(Theme.color.border))
historyFrame:SetMovable(true)
historyFrame:SetClampedToScreen(true)
historyFrame:Hide()

local titleBar = CreateFrame("Frame", nil, historyFrame)
titleBar:SetPoint("TOPLEFT")
titleBar:SetPoint("TOPRIGHT")
titleBar:SetHeight(Theme.layout.headerHeight)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() historyFrame:StartMoving() end)
titleBar:SetScript("OnDragStop", function() historyFrame:StopMovingOrSizing() end)

local title = titleBar:CreateFontString(nil, "ARTWORK")
title:SetFontObject(Theme.font.title)
title:SetPoint("LEFT", Theme.layout.padding, 0)
title:SetText(L["CATCH_HISTORY_TITLE"])

local closeButton = Theme:CreateCloseButton(titleBar)
closeButton:SetPoint("RIGHT", -Theme.layout.gutter, 0)
closeButton:SetScript("OnClick", function() historyFrame:Hide() end)
tinsert(UISpecialFrames, "AvidAnglerHistoryFrame")

local allButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_FILTER_ALL"])
allButton:SetPoint("TOPLEFT", Theme.layout.padding, -(Theme.layout.headerHeight + 8))
allButton:SetWidth(76)

local sessionButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_FILTER_SESSION"])
sessionButton:SetPoint("LEFT", allButton, "RIGHT", Theme.layout.gutter, 0)
sessionButton:SetWidth(86)

local zoneButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_FILTER_ZONE"])
zoneButton:SetPoint("LEFT", sessionButton, "RIGHT", Theme.layout.gutter, 0)
zoneButton:SetWidth(76)

local resetSessionButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_RESET_SESSION"])
resetSessionButton:SetPoint("RIGHT", -Theme.layout.padding, -(Theme.layout.headerHeight + 8))
resetSessionButton:SetWidth(118)

local summaryText = historyFrame:CreateFontString(nil, "ARTWORK")
summaryText:SetFontObject(Theme.font.heading)
summaryText:SetPoint("TOPLEFT", allButton, "BOTTOMLEFT", 0, -12)
summaryText:SetPoint("RIGHT", -Theme.layout.padding, 0)
summaryText:SetJustifyH("LEFT")

local pageText = historyFrame:CreateFontString(nil, "ARTWORK")
pageText:SetFontObject(Theme.font.muted)
pageText:SetPoint("TOPLEFT", summaryText, "BOTTOMLEFT", 0, -4)
pageText:SetPoint("RIGHT", -Theme.layout.padding, 0)
pageText:SetJustifyH("LEFT")

local insightTopFish = historyFrame:CreateFontString(nil, "ARTWORK")
insightTopFish:SetFontObject(Theme.font.small)
insightTopFish:SetPoint("TOPLEFT", pageText, "BOTTOMLEFT", 0, -10)
insightTopFish:SetPoint("RIGHT", -Theme.layout.padding, 0)
insightTopFish:SetJustifyH("LEFT")

local insightTopZone = historyFrame:CreateFontString(nil, "ARTWORK")
insightTopZone:SetFontObject(Theme.font.small)
insightTopZone:SetPoint("TOPLEFT", insightTopFish, "BOTTOMLEFT", 0, -4)
insightTopZone:SetPoint("RIGHT", -Theme.layout.padding, 0)
insightTopZone:SetJustifyH("LEFT")

local insightSource = historyFrame:CreateFontString(nil, "ARTWORK")
insightSource:SetFontObject(Theme.font.small)
insightSource:SetPoint("TOPLEFT", insightTopZone, "BOTTOMLEFT", 0, -4)
insightSource:SetPoint("RIGHT", -Theme.layout.padding, 0)
insightSource:SetJustifyH("LEFT")

local insightWindow = historyFrame:CreateFontString(nil, "ARTWORK")
insightWindow:SetFontObject(Theme.font.muted)
insightWindow:SetPoint("TOPLEFT", insightSource, "BOTTOMLEFT", 0, -4)
insightWindow:SetPoint("RIGHT", -Theme.layout.padding, 0)
insightWindow:SetJustifyH("LEFT")

local emptyText = historyFrame:CreateFontString(nil, "ARTWORK")
emptyText:SetFontObject(Theme.font.muted)
emptyText:SetPoint("CENTER", 0, -12)
emptyText:SetText(L["CATCH_HISTORY_EMPTY"])
emptyText:Hide()

local rows = {}
for i = 1, MAX_VISIBLE_ROWS do
    local row = Theme:CreatePanel(historyFrame, "panel", "border")
    row:SetHeight(ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", Theme.layout.padding, -(Theme.layout.headerHeight + 160 + (i - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", -Theme.layout.padding, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
    icon:SetPoint("LEFT", 4, 0)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.body)
    nameText:SetPoint("LEFT", icon, "RIGHT", Theme.layout.gutter, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -144, 0)
    nameText:SetJustifyH("LEFT")

    local zoneText = row:CreateFontString(nil, "ARTWORK")
    zoneText:SetFontObject(Theme.font.small)
    zoneText:SetPoint("LEFT", nameText, "RIGHT", Theme.layout.gutter, 0)
    zoneText:SetWidth(82)
    zoneText:SetJustifyH("LEFT")

    local detailText = row:CreateFontString(nil, "ARTWORK")
    detailText:SetFontObject(Theme.font.muted)
    detailText:SetPoint("RIGHT", -6, 0)
    detailText:SetWidth(48)
    detailText:SetJustifyH("RIGHT")

    row.icon = icon
    row.nameText = nameText
    row.zoneText = zoneText
    row.detailText = detailText
    row:Hide()
    rows[i] = row
end

local prevButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_PREV"])
prevButton:SetPoint("BOTTOMLEFT", Theme.layout.padding, Theme.layout.gutter)
prevButton:SetWidth(76)

local nextButton = Theme:CreateButton(historyFrame, L["CATCH_HISTORY_NEXT"])
nextButton:SetPoint("LEFT", prevButton, "RIGHT", Theme.layout.gutter, 0)
nextButton:SetWidth(76)

local function FormatElapsed(timestamp)
    local elapsed = time() - (timestamp or time())
    if elapsed < 60 then
        return elapsed .. "s"
    elseif elapsed < 3600 then
        return math.floor(elapsed / 60) .. "m"
    end
    return math.floor(elapsed / 3600) .. "h"
end

local function FormatDuration(seconds)
    seconds = math.max(seconds or 0, 0)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m " .. (seconds % 60) .. "s"
    end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return hours .. "h " .. minutes .. "m"
end

local function FormatClock(timestamp)
    return timestamp and date("%H:%M", timestamp) or L["CATCH_HISTORY_TIME_UNKNOWN"]
end

local function GetCurrentZoneMapID()
    return C_Map.GetBestMapForUnit("player")
end

local function GetDisplayZoneMapID(zoneMapID)
    local catalog = AvidAngler.Data and AvidAngler.Data.MapCatalog
    if catalog and catalog.GetDisplayAreaMapID then
        return catalog:GetDisplayAreaMapID(zoneMapID)
    end
    return zoneMapID
end

local function GetRecordDisplayZoneMapID(record)
    return record and GetDisplayZoneMapID(record.zoneMapID)
end

local function GetZoneName(zoneMapID)
    if not zoneMapID then
        return L["CATCH_HISTORY_ZONE_UNKNOWN"]
    end
    local displayZoneMapID = GetDisplayZoneMapID(zoneMapID)
    if zoneNameCache[displayZoneMapID] then
        return zoneNameCache[displayZoneMapID]
    end
    local info = displayZoneMapID and C_Map.GetMapInfo(displayZoneMapID)
    local name = (info and info.name) or L["CATCH_HISTORY_ZONE_UNKNOWN"]
    zoneNameCache[displayZoneMapID] = name
    return name
end

local function CountKeys(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

local function ClearComputedCaches()
    statsCache = {}
    analyticsCache = {}
    expansionsCache = {}
end

local function GetDataSignature()
    local catches = AvidAngler.DataLayer:GetCatches()
    local casts = AvidAngler.DataLayer.GetFishingCasts and AvidAngler.DataLayer:GetFishingCasts() or {}
    local lastCatch = catches[#catches]
    local lastCast = casts[#casts]
    local currentZone = GetDisplayZoneMapID(GetCurrentZoneMapID()) or 0
    return table.concat({
        #catches,
        lastCatch and (lastCatch.timestamp or 0) or 0,
        lastCatch and (lastCatch.itemID or 0) or 0,
        #casts,
        lastCast and (lastCast.timestamp or 0) or 0,
        sessionStartIndex,
        sessionStartCastIndex,
        currentZone,
    }, ":")
end

local function BuildCacheKey(...)
    local values = { GetDataSignature(), ... }
    for i = 1, #values do
        values[i] = tostring(values[i] or "")
    end
    return table.concat(values, "|")
end

local function GetCurrentCharacterKey()
    local characterName = UnitName("player")
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    if characterName and realmName then
        return realmName .. "-" .. characterName
    end
end

local function RecordMatchesScope(record, scope)
    if scope ~= SCOPE_CHARACTER then
        return true
    end
    local currentKey = GetCurrentCharacterKey()
    return not record.characterKey or record.characterKey == currentKey
end

local function GetExpansionLabel(key)
    local expansion = EXPANSION_BY_KEY[key or EXPANSION_ALL] or EXPANSION_BY_KEY[EXPANSION_ALL]
    return L[expansion.labelKey] or expansion.key
end

local GetKnownFishExpansion

local function GetMapExpansion(zoneMapID)
    local displayMapID = GetDisplayZoneMapID(zoneMapID)
    if displayMapID and MAP_EXPANSIONS[displayMapID] then
        return MAP_EXPANSIONS[displayMapID]
    end
    return zoneMapID and MAP_EXPANSIONS[zoneMapID] or nil
end

local function GetRecordExpansionKey(record)
    if not record or not record.zoneMapID then
        return (record and GetKnownFishExpansion(record.itemID, record.itemName)) or "other"
    end
    local fishExpansion = GetKnownFishExpansion(record.itemID, record.itemName)
    if fishExpansion then
        return fishExpansion
    end
    local mapExpansion = GetMapExpansion(record.zoneMapID)
    if mapExpansion then
        return mapExpansion
    end
    local name = GetZoneName(record.zoneMapID)
    return ZONE_EXPANSIONS[name] or "other"
end

local function GetCurrentExpansionKey()
    return GetRecordExpansionKey({ zoneMapID = GetCurrentZoneMapID() })
end

local function RecordMatchesExpansion(record, expansionKey)
    if not expansionKey or expansionKey == EXPANSION_ALL then
        return true
    end
    return GetRecordExpansionKey(record) == expansionKey
end

local function IsEquippableItem(itemID)
    if not itemID or not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return false
    end
    if equippableCache[itemID] ~= nil then
        return equippableCache[itemID]
    end

    local ok
    local itemEquipLoc
    local itemClassID
    ok, _, _, _, _, _, _, _, _, itemEquipLoc, _, _, itemClassID = pcall(C_Item.GetItemInfo, itemID)
    if not ok then
        equippableCache[itemID] = false
        return false
    end
    if itemEquipLoc and itemEquipLoc ~= "" then
        equippableCache[itemID] = true
        return true
    end

    local itemClass = Enum and Enum.ItemClass
    local weaponClass = itemClass and itemClass.Weapon
    local armorClass = itemClass and itemClass.Armor
    local result = type(itemClassID) == "number" and ((type(weaponClass) == "number" and itemClassID == weaponClass) or (type(armorClass) == "number" and itemClassID == armorClass)) or false
    equippableCache[itemID] = result
    return result
end

local function BuildKnownFishLookup()
    local scoring = AvidAngler.Modules and AvidAngler.Modules.Scoring
    if scoring and scoring.GetKnownFishLookup then
        return scoring:GetKnownFishLookup()
    end

    local entries = scoring and scoring.GetKnownFishEntries and scoring:GetKnownFishEntries() or {}
    local lookup = { byID = {}, byName = {} }
    for _, entry in ipairs(entries) do
        if entry.itemID then
            lookup.byID[entry.itemID] = true
        end
        local normalizedName = NormalizeItemName(entry.name)
        if normalizedName then
            lookup.byName[normalizedName] = true
        end
    end
    return lookup
end

local function IsKnownFish(itemID, itemName, knownFish)
    if AvidAngler.DataLayer and AvidAngler.DataLayer.IsKnownFish and AvidAngler.DataLayer:IsKnownFish(itemID, itemName) then
        return true
    end

    if knownFish then
        local normalizedName = NormalizeItemName(itemName)
        return (itemID and knownFish.byID[itemID]) or (normalizedName and knownFish.byName[normalizedName]) or false
    end

    local scoring = AvidAngler.Modules and AvidAngler.Modules.Scoring
    return scoring and scoring.IsKnownFish and scoring:IsKnownFish(itemID, itemName) or false
end

GetKnownFishExpansion = function(itemID, itemName)
    return AvidAngler.DataLayer and AvidAngler.DataLayer.GetKnownFishExpansion and AvidAngler.DataLayer:GetKnownFishExpansion(itemID, itemName) or nil
end

local function GetRecordItemQuality(record)
    if record.itemQuality ~= nil then
        return record.itemQuality
    end
    if record.itemID and itemQualityCache[record.itemID] ~= nil then
        return itemQualityCache[record.itemID]
    end
    if record.itemID and C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, _, _, itemQuality = pcall(C_Item.GetItemInfo, record.itemID)
        if ok then
            itemQualityCache[record.itemID] = itemQuality
            return itemQuality
        end
    end
    return nil
end

local function GetRecordCatchType(record, knownFish)
    local cached = catchTypeCache[record]
    if cached then
        return cached
    end

    local catchType
    if IsKnownFish(record.itemID, record.itemName, knownFish) then
        catchType = "fish"
        catchTypeCache[record] = catchType
        return catchType
    end

    local itemQuality = GetRecordItemQuality(record)
    if record.catchType == "junk" or itemQuality == 0 or (Enum and Enum.ItemQuality and itemQuality == Enum.ItemQuality.Poor) then
        catchType = "junk"
        catchTypeCache[record] = catchType
        return catchType
    end

    local name = record.itemName and record.itemName:lower()
    if name and (name:find("cosmetic", 1, true) or name == "farstrider's solemn bow") then
        catchType = "treasure"
        catchTypeCache[record] = catchType
        return catchType
    end
    if IsEquippableItem(record.itemID) then
        catchType = "treasure"
        catchTypeCache[record] = catchType
        return catchType
    end

    if record.catchType == "treasure" then
        catchType = record.catchType
        catchTypeCache[record] = catchType
        return catchType
    end
    if itemQuality == 1 or (Enum and Enum.ItemQuality and itemQuality == Enum.ItemQuality.Common) then
        catchType = "junk"
        catchTypeCache[record] = catchType
        return catchType
    elseif type(itemQuality) == "number" and itemQuality >= 2 then
        catchType = "treasure"
        catchTypeCache[record] = catchType
        return catchType
    end
    catchType = "unknown"
    catchTypeCache[record] = catchType
    return catchType
end

local function GetSourceLabel(source)
    if source == "pool" then
        return L["CATCH_HISTORY_SOURCE_POOL"]
    elseif source == "open-water" then
        return L["CATCH_HISTORY_SOURCE_OPEN"]
    elseif source == "either" then
        return L["CATCH_HISTORY_SOURCE_EITHER"]
    end
    return L["CATCH_HISTORY_SOURCE_UNKNOWN"]
end

local function GetRecordCatchSource(record)
    if record and OPEN_WATER_ONLY_ZONE_MAP_IDS[record.zoneMapID] then
        return "open-water"
    end
    return record and record.catchSource or "unknown"
end

local function FormatSourceBreakdown(sourceCounts)
    local parts = {}
    local ordered = { "pool", "open-water", "either" }
    for _, source in ipairs(ordered) do
        local count = sourceCounts and sourceCounts[source] or 0
        if count > 0 then
            parts[#parts + 1] = L["CATCH_HISTORY_SOURCE_PART"]:format(GetSourceLabel(source), count)
        end
    end
    return #parts > 0 and table.concat(parts, " / ") or L["CATCH_HISTORY_SOURCE_NOT_DETECTED"]
end

local function RecordMatchesMode(record, index, mode, zoneMapID)
    if zoneMapID and GetRecordDisplayZoneMapID(record) ~= GetDisplayZoneMapID(zoneMapID) then
        return false
    end
    local activeMode = mode or historyMode
    if activeMode == MODE_SESSION then
        return index >= sessionStartIndex
    elseif activeMode == MODE_ZONE then
        return GetRecordDisplayZoneMapID(record) == GetDisplayZoneMapID(GetCurrentZoneMapID())
    end
    return true
end

local function CastMatchesMode(record, index, mode, zoneMapID)
    if zoneMapID and GetRecordDisplayZoneMapID(record) ~= GetDisplayZoneMapID(zoneMapID) then
        return false
    end
    local activeMode = mode or historyMode
    if activeMode == MODE_SESSION then
        return index >= sessionStartCastIndex
    elseif activeMode == MODE_ZONE then
        return GetRecordDisplayZoneMapID(record) == GetDisplayZoneMapID(GetCurrentZoneMapID())
    end
    return true
end

local function BuildFilteredCatches(mode, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)
    local catches = AvidAngler.DataLayer:GetCatches()
    local filtered = {}
    local totalQuantity = 0
    local knownFish = BuildKnownFishLookup()

    for index = #catches, 1, -1 do
        local record = catches[index]
        local catchType = GetRecordCatchType(record, knownFish)
        if (not hideJunk or catchType ~= "junk") and (not hideTreasures or catchType ~= "treasure") and RecordMatchesMode(record, index, mode, zoneMapID) and RecordMatchesScope(record, scope) and RecordMatchesExpansion(record, expansionKey) then
            filtered[#filtered + 1] = {
                index = index,
                record = record,
                catchType = catchType,
            }
            totalQuantity = totalQuantity + (record.quantity or 1)
        end
    end

    return filtered, totalQuantity
end

local function BuildFilteredCasts(mode, scope, expansionKey, zoneMapID)
    local casts = AvidAngler.DataLayer.GetFishingCasts and AvidAngler.DataLayer:GetFishingCasts() or {}
    local filtered = {}
    for index = #casts, 1, -1 do
        local record = casts[index]
        if CastMatchesMode(record, index, mode, zoneMapID) and RecordMatchesScope(record, scope) and RecordMatchesExpansion(record, expansionKey) then
            filtered[#filtered + 1] = {
                index = index,
                record = record,
            }
        end
    end
    return filtered
end

local function BuildStats(mode, scope, expansionKey, zoneMapID)
    local filtered, totalQuantity = BuildFilteredCatches(mode, scope, expansionKey, zoneMapID)
    local castEntries = BuildFilteredCasts(mode, scope, expansionKey, zoneMapID)

    local fish = {}
    local zones = {}
    local sourceCounts = {}
    local firstTimestamp
    local lastTimestamp
    local firstCastTimestamp
    local fishQuantity = 0
    local junk = 0
    local treasure = 0
    for i = 1, #filtered do
        local record = filtered[i].record
        local quantity = record.quantity or 1
        local catchType = filtered[i].catchType or GetRecordCatchType(record)
        if catchType == "fish" and record.itemID then
            fish[record.itemID] = (fish[record.itemID] or 0) + quantity
            fishQuantity = fishQuantity + quantity
            local displayZoneMapID = GetRecordDisplayZoneMapID(record)
            if displayZoneMapID then
                zones[displayZoneMapID] = (zones[displayZoneMapID] or 0) + quantity
            end
        end
        if catchType == "junk" then
            junk = junk + quantity
        elseif catchType == "treasure" then
            treasure = treasure + quantity
        end
        local source = GetRecordCatchSource(record)
        sourceCounts[source] = (sourceCounts[source] or 0) + quantity
        if record.timestamp then
            firstTimestamp = firstTimestamp and math.min(firstTimestamp, record.timestamp) or record.timestamp
            lastTimestamp = lastTimestamp and math.max(lastTimestamp, record.timestamp) or record.timestamp
        end
    end
    for i = 1, #castEntries do
        local timestamp = castEntries[i].record.timestamp
        if timestamp then
            firstCastTimestamp = firstCastTimestamp and math.min(firstCastTimestamp, timestamp) or timestamp
            firstTimestamp = firstTimestamp and math.min(firstTimestamp, timestamp) or timestamp
            lastTimestamp = lastTimestamp and math.max(lastTimestamp, timestamp) or timestamp
        end
    end
    local catchEventTimes = {}
    local trackedCatchEvents = 0
    if firstCastTimestamp then
        for i = 1, #filtered do
            local timestamp = filtered[i].record.timestamp
            if timestamp and timestamp >= firstCastTimestamp and not catchEventTimes[timestamp] then
                catchEventTimes[timestamp] = true
                trackedCatchEvents = trackedCatchEvents + 1
            end
        end
    end

    local topFishID, topFishCount
    for itemID, quantity in pairs(fish) do
        if not topFishCount or quantity > topFishCount then
            topFishID = itemID
            topFishCount = quantity
        end
    end

    local topZoneID, topZoneCount
    for zoneMapID, quantity in pairs(zones) do
        if not topZoneCount or quantity > topZoneCount then
            topZoneID = zoneMapID
            topZoneCount = quantity
        end
    end

    local duration = (firstTimestamp and lastTimestamp) and math.max(lastTimestamp - firstTimestamp, 1) or 0
    local fishPerHour = duration > 0 and (fishQuantity / duration * 3600) or 0
    local castsPerHour = duration > 0 and (#castEntries / duration * 3600) or 0

    return {
        catches = #filtered,
        totalQuantity = totalQuantity,
        fish = fishQuantity,
        casts = #castEntries,
        junk = junk,
        treasure = treasure,
        types = CountKeys(fish),
        zones = CountKeys(zones),
        topFishID = topFishID,
        topFishCount = topFishCount or 0,
        topZoneID = topZoneID,
        topZoneCount = topZoneCount or 0,
        sourceCounts = sourceCounts,
        sourceBreakdown = FormatSourceBreakdown(sourceCounts),
        firstTimestamp = firstTimestamp,
        lastTimestamp = lastTimestamp,
        firstTime = FormatClock(firstTimestamp),
        lastTime = FormatClock(lastTimestamp),
        fishPerHour = fishPerHour,
        castsPerHour = castsPerHour,
        catchRate = #castEntries > 0 and math.min(trackedCatchEvents / #castEntries * 100, 100) or 0,
    }
end

local function StampWindow(entry, timestamp)
    if not timestamp then
        return
    end
    entry.firstTimestamp = entry.firstTimestamp and math.min(entry.firstTimestamp, timestamp) or timestamp
    entry.lastTimestamp = entry.lastTimestamp and math.max(entry.lastTimestamp, timestamp) or timestamp
    entry.firstTime = FormatClock(entry.firstTimestamp)
    entry.lastTime = FormatClock(entry.lastTimestamp)
end

local function BuildAnalytics(mode, scope, expansionKey, zoneMapID, hideJunk, hideTreasures, includeAllLoot)
    local filtered, totalQuantity = BuildFilteredCatches(mode, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)

    local fishByID = {}
    local zoneByID = {}
    local fishQuantity = 0
    for _, entry in ipairs(filtered) do
        local record = entry.record
        local quantity = record.quantity or 1
        local source = GetRecordCatchSource(record)
        local catchType = entry.catchType or GetRecordCatchType(record)
        local includeInItemCards = includeAllLoot or catchType == "fish"

        if includeInItemCards and record.itemID then
            local fish = fishByID[record.itemID]
            if not fish then
                fish = {
                    kind = "fish",
                    itemID = record.itemID,
                    catchType = catchType,
                    quantity = 0,
                    catches = 0,
                    zones = {},
                    sourceCounts = {},
                    recent = {},
                }
                fishByID[record.itemID] = fish
            end
            fish.quantity = fish.quantity + quantity
            fish.catches = fish.catches + 1
            local displayZoneMapID = GetRecordDisplayZoneMapID(record)
            if displayZoneMapID then
                fish.zones[displayZoneMapID] = true
            end
            fish.sourceCounts[source] = (fish.sourceCounts[source] or 0) + quantity
            if #fish.recent < 8 then
                fish.recent[#fish.recent + 1] = {
                    quantity = quantity,
                    timestamp = record.timestamp,
                    zoneMapID = record.zoneMapID,
                    catchSource = source,
                }
            end
            StampWindow(fish, record.timestamp)
        end

        if catchType == "fish" then
            fishQuantity = fishQuantity + quantity
        end

        local displayZoneMapID = GetRecordDisplayZoneMapID(record)
        if displayZoneMapID and (includeAllLoot or catchType == "fish") then
            local zone = zoneByID[displayZoneMapID]
            if not zone then
                zone = {
                    kind = "zone",
                    zoneMapID = displayZoneMapID,
                    quantity = 0,
                    catches = 0,
                    fish = {},
                    sourceCounts = {},
                }
                zoneByID[displayZoneMapID] = zone
            end
            zone.quantity = zone.quantity + quantity
            zone.catches = zone.catches + 1
            if record.itemID then
                zone.fish[record.itemID] = (zone.fish[record.itemID] or 0) + quantity
            end
            zone.sourceCounts[source] = (zone.sourceCounts[source] or 0) + quantity
            StampWindow(zone, record.timestamp)
        end
    end

    local fishRows = {}
    for _, fish in pairs(fishByID) do
        fish.zoneCount = CountKeys(fish.zones)
        local denominator = includeAllLoot and totalQuantity or fishQuantity
        fish.percent = denominator > 0 and (fish.quantity / denominator * 100) or 0
        fish.sourceBreakdown = FormatSourceBreakdown(fish.sourceCounts)
        fishRows[#fishRows + 1] = fish
    end
    table.sort(fishRows, function(a, b)
        if a.quantity ~= b.quantity then
            return a.quantity > b.quantity
        end
        return (a.itemID or 0) < (b.itemID or 0)
    end)

    local zoneRows = {}
    for _, zone in pairs(zoneByID) do
        zone.typeCount = CountKeys(zone.fish)
        local denominator = includeAllLoot and totalQuantity or fishQuantity
        zone.percent = denominator > 0 and (zone.quantity / denominator * 100) or 0
        zone.sourceBreakdown = FormatSourceBreakdown(zone.sourceCounts)
        for itemID, quantity in pairs(zone.fish) do
            if not zone.topFishCount or quantity > zone.topFishCount then
                zone.topFishID = itemID
                zone.topFishCount = quantity
            end
        end
        zoneRows[#zoneRows + 1] = zone
    end
    table.sort(zoneRows, function(a, b)
        if a.quantity ~= b.quantity then
            return a.quantity > b.quantity
        end
        return GetZoneName(a.zoneMapID) < GetZoneName(b.zoneMapID)
    end)

    return {
        fish = fishRows,
        zones = zoneRows,
        totalQuantity = includeAllLoot and totalQuantity or fishQuantity,
        totalCatches = #filtered,
    }
end

local function SetTopFishLine(label, stats)
    if not stats or not stats.topFishID then
        label:SetText(L["CATCH_HISTORY_TOP_FISH"]:format("-", 0))
        return
    end

    local itemID = stats.topFishID
    label:SetText(L["CATCH_HISTORY_TOP_FISH"]:format("item:" .. itemID, stats.topFishCount or 0))
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local currentStats = BuildStats(historyMode)
        if currentStats.topFishID == itemID then
            label:SetText(L["CATCH_HISTORY_TOP_FISH"]:format(item:GetItemName() or ("item:" .. itemID), currentStats.topFishCount or 0))
        end
    end)
end

local function RefreshInsightLabels(stats)
    SetTopFishLine(insightTopFish, stats)
    insightTopZone:SetText(L["CATCH_HISTORY_TOP_ZONE"]:format(stats and stats.topZoneID and GetZoneName(stats.topZoneID) or "-", stats and stats.topZoneCount or 0))
    insightSource:SetText(L["CATCH_HISTORY_SOURCE_MIX"]:format(stats and stats.sourceBreakdown or L["CATCH_HISTORY_SOURCE_UNKNOWN"]))
    insightWindow:SetText(L["CATCH_HISTORY_WINDOW"]:format(stats and stats.firstTime or L["CATCH_HISTORY_TIME_UNKNOWN"], stats and stats.lastTime or L["CATCH_HISTORY_TIME_UNKNOWN"]))
end

local function SetModeButtonVisual(button, selected)
    if selected then
        button:SetBackdropBorderColor(unpack(Theme.color.accent))
        button.text:SetFontObject(Theme.font.heading)
    else
        button:SetBackdropBorderColor(unpack(Theme.color.accentDim))
        button.text:SetFontObject(Theme.font.body)
    end
end

local function RefreshModeButtons()
    SetModeButtonVisual(allButton, historyMode == MODE_ALL)
    SetModeButtonVisual(sessionButton, historyMode == MODE_SESSION)
    SetModeButtonVisual(zoneButton, historyMode == MODE_ZONE)
end

local function RefreshRow(row, entry)
    local record = entry.record
    row.recordIndex = entry.index
    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetText(record.itemID and ("item:" .. record.itemID) or "?")
    row.zoneText:SetText(GetZoneName(record.zoneMapID))

    if record.itemID then
        local item = Item:CreateFromItemID(record.itemID)
        item:ContinueOnItemLoad(function()
            if row.recordIndex ~= entry.index then
                return
            end
            row.icon:SetTexture(item:GetItemIcon())
            row.nameText:SetText(item:GetItemName())
        end)
    end

    local quantityLabel = (record.quantity and record.quantity > 1) and ("x" .. record.quantity .. "  ") or ""
    row.detailText:SetText(quantityLabel .. FormatElapsed(record.timestamp))
    row.record = record
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local currentRecord = self.record
        if not currentRecord then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.nameText:GetText() or L["CATCH_HISTORY_TITLE"])
        GameTooltip:AddLine(L["CATCH_HISTORY_TOOLTIP_ZONE"]:format(GetZoneName(currentRecord.zoneMapID)), 0.8, 0.8, 0.8)
        if currentRecord.coordX and currentRecord.coordY then
            GameTooltip:AddLine(L["CATCH_HISTORY_TOOLTIP_COORDS"]:format(currentRecord.coordX * 100, currentRecord.coordY * 100), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(L["CATCH_HISTORY_TOOLTIP_SOURCE"]:format(GetSourceLabel(currentRecord.catchSource)), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:Show()
end

function Tracking:SetMode(mode)
    historyMode = mode or MODE_ALL
    pageOffset = 0
    self:Refresh()
end

function Tracking:ResetSession()
    if self.SessionValue then self.SessionValue:Reset() end
    sessionStartIndex = #AvidAngler.DataLayer:GetCatches() + 1
    sessionStartCastIndex = AvidAngler.DataLayer.GetFishingCasts and (#AvidAngler.DataLayer:GetFishingCasts() + 1) or 1
    sessionStartTime = time()
    pageOffset = 0
    ClearComputedCaches()
    AvidAngler:Print(L["CATCH_HISTORY_SESSION_RESET"])
    self:Refresh()
end

function Tracking:ShowSession()
    historyMode = MODE_SESSION
    pageOffset = 0
    self:Refresh()
    historyFrame:Show()
end

function Tracking:ShowMode(mode)
    historyMode = mode or MODE_ALL
    pageOffset = 0
    self:Refresh()
    historyFrame:Show()
end

function Tracking:GetSummary()
    local catches = AvidAngler.DataLayer:GetCatches()
    local currentZone = GetDisplayZoneMapID(GetCurrentZoneMapID())
    local summary = {
        allCatches = #catches,
        allFish = 0,
        allTypes = 0,
        sessionCatches = 0,
        sessionFish = 0,
        sessionTypes = 0,
        zoneCatches = 0,
        zoneFish = 0,
        zoneTypes = 0,
        sessionElapsed = FormatDuration(time() - (sessionStartTime or time())),
        recent = {},
    }
    local allTypes = {}
    local sessionTypes = {}
    local zoneTypes = {}

    for index = #catches, 1, -1 do
        local record = catches[index]
        local quantity = record.quantity or 1

        summary.allFish = summary.allFish + quantity
        if record.itemID then
            allTypes[record.itemID] = true
        end

        if index >= sessionStartIndex then
            summary.sessionCatches = summary.sessionCatches + 1
            summary.sessionFish = summary.sessionFish + quantity
            if record.itemID then
                sessionTypes[record.itemID] = true
            end
        end

        if GetRecordDisplayZoneMapID(record) == currentZone then
            summary.zoneCatches = summary.zoneCatches + 1
            summary.zoneFish = summary.zoneFish + quantity
            if record.itemID then
                zoneTypes[record.itemID] = true
            end
        end

        if #summary.recent < 5 then
            summary.recent[#summary.recent + 1] = record
        end
    end

    for _ in pairs(allTypes) do summary.allTypes = summary.allTypes + 1 end
    for _ in pairs(sessionTypes) do summary.sessionTypes = summary.sessionTypes + 1 end
    for _ in pairs(zoneTypes) do summary.zoneTypes = summary.zoneTypes + 1 end

    return summary
end

function Tracking:GetStats(mode, scope, expansionKey, zoneMapID)
    local key = BuildCacheKey("stats", mode or MODE_ALL, scope or "", expansionKey or "", zoneMapID or "")
    if not statsCache[key] then
        statsCache[key] = BuildStats(mode, scope, expansionKey, zoneMapID)
    end
    return statsCache[key]
end

function Tracking:GetHistoryPage(mode, offset, limit, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)
    local filtered, totalQuantity = BuildFilteredCatches(mode or MODE_ALL, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)
    local pageSize = limit or MAX_VISIBLE_ROWS
    local currentOffset = math.min(offset or 0, math.max(#filtered - pageSize, 0))
    local page = {}

    for i = 1, pageSize do
        local entry = filtered[currentOffset + i]
        if entry then
            page[#page + 1] = entry
        end
    end

    return {
        entries = page,
        total = #filtered,
        totalQuantity = totalQuantity,
        offset = currentOffset,
        pageSize = pageSize,
    }
end

function Tracking:GetGroupedHistoryPage(mode, offset, limit, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)
    local key = BuildCacheKey("grouped", mode or MODE_ALL, scope or "", expansionKey or "", zoneMapID or "", hideJunk and 1 or 0, hideTreasures and 1 or 0)
    if not analyticsCache[key] then
        analyticsCache[key] = BuildAnalytics(mode, scope, expansionKey, zoneMapID, hideJunk, hideTreasures, true)
    end
    local analytics = analyticsCache[key]
    local rows = analytics.fish
    local pageSize = limit or MAX_VISIBLE_ROWS
    local currentOffset = math.min(offset or 0, math.max(#rows - pageSize, 0))
    local page = {}

    for i = 1, pageSize do
        local entry = rows[currentOffset + i]
        if entry then
            page[#page + 1] = entry
        end
    end

    return {
        entries = page,
        total = #rows,
        totalQuantity = analytics.totalQuantity,
        totalCatches = analytics.totalCatches,
        offset = currentOffset,
        pageSize = pageSize,
    }
end

function Tracking:GetAnalyticsPage(mode, view, offset, limit, scope, expansionKey, zoneMapID, hideJunk, hideTreasures)
    local key = BuildCacheKey("analytics", mode or MODE_ALL, view or "", scope or "", expansionKey or "", zoneMapID or "", hideJunk and 1 or 0, hideTreasures and 1 or 0)
    if not analyticsCache[key] then
        analyticsCache[key] = BuildAnalytics(mode, scope, expansionKey, zoneMapID, hideJunk, hideTreasures, false)
    end
    local analytics = analyticsCache[key]
    local rows = view == "zones" and analytics.zones or analytics.fish
    local pageSize = limit or MAX_VISIBLE_ROWS
    local currentOffset = math.min(offset or 0, math.max(#rows - pageSize, 0))
    local page = {}

    for i = 1, pageSize do
        local entry = rows[currentOffset + i]
        if entry then
            page[#page + 1] = entry
        end
    end

    return {
        entries = page,
        total = #rows,
        totalQuantity = analytics.totalQuantity,
        totalCatches = analytics.totalCatches,
        offset = currentOffset,
        pageSize = pageSize,
    }
end

function Tracking:GetExpansionLabel(expansionKey)
    return GetExpansionLabel(expansionKey)
end

function Tracking:GetCurrentExpansionKey()
    return GetCurrentExpansionKey()
end

function Tracking:GetAvailableExpansions(scope)
    local key = BuildCacheKey("expansions", scope or "")
    if expansionsCache[key] then
        return expansionsCache[key]
    end
    local seen = {}
    local available = { [EXPANSION_ALL] = true }
    local function addExpansion(key, includeOther)
        if key and (includeOther or key ~= "other") and EXPANSION_BY_KEY[key] then
            available[key] = true
        end
    end
    local function addFromRecord(record)
        if RecordMatchesScope(record, scope) then
            addExpansion(GetRecordExpansionKey(record), true)
        end
    end
    addExpansion(GetCurrentExpansionKey(), false)
    for _, record in ipairs(AvidAngler.DataLayer:GetCatches()) do
        addFromRecord(record)
    end
    local casts = AvidAngler.DataLayer.GetFishingCasts and AvidAngler.DataLayer:GetFishingCasts() or {}
    for _, record in ipairs(casts) do
        addFromRecord(record)
    end

    local options = {}
    for _, expansion in ipairs(EXPANSIONS) do
        if available[expansion.key] and not seen[expansion.key] then
            seen[expansion.key] = true
            options[#options + 1] = expansion
        end
    end
    expansionsCache[key] = options
    return options
end

function Tracking:Refresh()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        historyFrame:Hide()
        return
    end

    local filtered, totalQuantity = BuildFilteredCatches()
    local total = #filtered
    local maxOffset = math.max(total - MAX_VISIBLE_ROWS, 0)
    pageOffset = math.min(pageOffset, maxOffset)

    RefreshModeButtons()
    emptyText:SetShown(total == 0)
    summaryText:SetText(L["CATCH_HISTORY_SUMMARY"]:format(total, totalQuantity))
    local stats = BuildStats(historyMode)

    if total == 0 then
        pageText:SetText("")
        RefreshInsightLabels(nil)
    else
        local first = pageOffset + 1
        local last = math.min(pageOffset + MAX_VISIBLE_ROWS, total)
        pageText:SetText(L["CATCH_HISTORY_PAGE_STATS"]:format(first, last, total, stats.types, stats.zones, stats.fishPerHour))
        RefreshInsightLabels(stats)
    end

    prevButton:SetEnabled(pageOffset > 0)
    nextButton:SetEnabled(pageOffset + MAX_VISIBLE_ROWS < total)

    for i = 1, MAX_VISIBLE_ROWS do
        local entry = filtered[pageOffset + i]
        if entry then
            RefreshRow(rows[i], entry)
        else
            rows[i]:Hide()
        end
    end
end

function Tracking:Toggle()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        AvidAngler:Print(L["MODULE_DISABLED_OPEN"]:format(L["MAIN_TAB_TRACKING"]))
        return
    end

    if historyFrame:IsShown() then
        historyFrame:Hide()
    else
        self:Refresh()
        historyFrame:Show()
    end
end

allButton:SetScript("OnClick", function() Tracking:SetMode(MODE_ALL) end)
sessionButton:SetScript("OnClick", function() Tracking:SetMode(MODE_SESSION) end)
zoneButton:SetScript("OnClick", function() Tracking:SetMode(MODE_ZONE) end)
resetSessionButton:SetScript("OnClick", function() Tracking:ResetSession() end)
prevButton:SetScript("OnClick", function()
    pageOffset = math.max(pageOffset - MAX_VISIBLE_ROWS, 0)
    Tracking:Refresh()
end)
nextButton:SetScript("OnClick", function()
    pageOffset = pageOffset + MAX_VISIBLE_ROWS
    Tracking:Refresh()
end)

EventRegistry:RegisterCallback(AvidAngler.CATCH_RECORDED_EVENT, function()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    local catches = AvidAngler.DataLayer:GetCatches()
    if Tracking.SessionValue then Tracking.SessionValue:RecordCatch(catches[#catches]) end
    ClearComputedCaches()
    if moduleEnabled and historyFrame:IsShown() then
        Tracking:Refresh()
    end
end)

EventRegistry:RegisterCallback(AvidAngler.CAST_RECORDED_EVENT, function()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    ClearComputedCaches()
    if moduleEnabled and historyFrame:IsShown() then
        Tracking:Refresh()
    end
end)

EventRegistry:RegisterCallback(AvidAngler.CONTENT_SAFETY_CHANGED_EVENT, function()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        historyFrame:Hide()
        ClearComputedCaches()
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() and event ~= "ADDON_LOADED" then
        historyFrame:Hide()
        return
    end

    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        if Tracking.SessionValue then Tracking.SessionValue:Reset() end
        sessionStartIndex = #AvidAngler.DataLayer:GetCatches() + 1
        sessionStartCastIndex = AvidAngler.DataLayer.GetFishingCasts and (#AvidAngler.DataLayer:GetFishingCasts() + 1) or 1
        sessionStartTime = time()
        ClearComputedCaches()
    elseif event == "PLAYER_ENTERING_WORLD" and sessionStartTime == nil then
        sessionStartIndex = #AvidAngler.DataLayer:GetCatches() + 1
        sessionStartCastIndex = AvidAngler.DataLayer.GetFishingCasts and (#AvidAngler.DataLayer:GetFishingCasts() + 1) or 1
        sessionStartTime = time()
        ClearComputedCaches()
    end
end)

SLASH_AVIDANGLERHISTORY1 = "/aahistory"
SlashCmdList["AVIDANGLERHISTORY"] = function(msg)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end

    local command = (msg or ""):match("^%s*(.-)%s*$"):lower()
    local mode = MODE_ALL
    if command == "session" then
        mode = MODE_SESSION
    elseif command == "zone" then
        mode = MODE_ZONE
    end
    if AvidAngler.UI.MainWindow then
        AvidAngler.UI.MainWindow:ShowTracking(mode)
    else
        Tracking:ShowMode(mode)
    end
end

SLASH_AVIDANGLERSESSION1 = "/aasession"
SlashCmdList["AVIDANGLERSESSION"] = function(msg)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end

    local command = (msg or ""):match("^%s*(.-)%s*$"):lower()
    if command == "reset" then
        Tracking:ResetSession()
        if AvidAngler.UI.MainWindow then
            AvidAngler.UI.MainWindow:ShowTracking(MODE_SESSION)
        end
    else
        AvidAngler:Print(L["CATCH_HISTORY_SESSION_USAGE"])
    end
end

function Tracking:Enable()
    moduleEnabled = true
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        historyFrame:Hide()
    end
end

function Tracking:Disable()
    moduleEnabled = false
    historyFrame:Hide()
end
