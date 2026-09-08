-- Avid Angler
-- Scoring pillar: turns recorded catches into current-zone progress signals.

local ADDON_NAME, AvidAngler = ...

local Scoring = {}
AvidAngler.Modules.Scoring = Scoring

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L

local MAX_ROWS = 12
local ROW_HEIGHT = Theme.layout.rowHeight + 2
local showAllZones = false
local hideTrophy = false
local moduleEnabled = true
local dataPending = 0
local retryPending = false
local scoreCache = {}
local pendingCatchRefresh = false
local knownFishEntriesCache
local knownFishLookupCache
local pendingZoneRefresh = false

local function ClearScoreCache()
    scoreCache = {}
end

local function ClearKnownFishCache()
    knownFishEntriesCache = nil
    knownFishLookupCache = nil
end

local SCORE_SPELL_ID = 1303630
local SCORE_ACHIEVEMENT_ID = 63510
local SCORE_ACHIEVEMENT_TARGET = 2500
local FISHING_JOURNAL_FISH = {
    { spellID = 1225282, itemID = 238371, category = 1 },
    { spellID = 1295409, itemID = 274592, category = 1 },
    { spellID = 1225275, itemID = 238382, category = 1 },
    { spellID = 1225270, itemID = 238366, category = 1 },
    { spellID = 1225269, itemID = 238367, category = 1 },
    { spellID = 1225245, itemID = 238365, category = 1 },
    { spellID = 1295404, itemID = 274587, category = 1 },
    { spellID = 1295405, itemID = 274588, category = 1 },
    { spellID = 1225266, itemID = 238369, category = 2 },
    { spellID = 1225276, itemID = 238375, category = 2 },
    { spellID = 1225267, itemID = 238381, category = 2 },
    { spellID = 1295410, itemID = 274594, category = 2 },
    { spellID = 1225277, itemID = 238372, category = 2 },
    { spellID = 1225272, itemID = 238370, category = 2 },
    { spellID = 1225271, itemID = 238378, category = 2 },
    { spellID = 1295407, itemID = 274590, category = 2 },
    { spellID = 1225278, itemID = 238384, category = 2 },
    { spellID = 1225281, itemID = 238374, category = 2 },
    { spellID = 1295411, itemID = 274593, category = 3 },
    { spellID = 1225274, itemID = 238377, category = 3 },
    { spellID = 1295408, itemID = 274591, category = 3 },
    { spellID = 1225283, itemID = 238383, category = 3 },
    { spellID = 1225284, itemID = 238376, category = 3 },
    { spellID = 1225268, itemID = 238380, category = 3 },
    { spellID = 1225273, itemID = 238373, category = 3 },
    { spellID = 1225280, itemID = 238368, category = 3 },
    { spellID = 1295406, itemID = 274589, category = 3 },
    { spellID = 1225279, itemID = 238379, category = 3 },
    { spellID = 1305973, itemID = 279093, category = 4 },
    { spellID = 1305975, itemID = 279094, category = 4 },
    { spellID = 1305979, itemID = 279106, category = 4 },
    { spellID = 1305976, itemID = 279100, category = 4 },
    { spellID = 1305972, itemID = 279091, category = 4 },
    { spellID = 1305978, itemID = 279105, category = 4 },
}
local RANK_LEVEL = { Guppy = 1, Minnow = 2, Pike = 3, Shark = 4, Trophy = 5 }
local RANK_ORDER = { "Guppy", "Minnow", "Pike", "Shark", "Trophy" }
local RANK_CUTOFFS = {
    Minnow = 75,
    Pike = 80,
    Shark = 95,
    Trophy = 100,
}
local FISH_LURES = {
    [1225269] = true,
    [1225273] = true,
    [1225274] = true,
    [1225278] = true,
    [1225284] = true,
    [1295406] = true,
    [1295408] = true,
}
local PARSE_LOCALES = {
    enUS = {
        scoreLabel = { "Anglin' Score", "Anglin\226\128\153 Score", "Fishing Score" },
        rankLabel = "Catch Rank",
        areasHeader = "Areas you can find",
        poolsHeader = "Fishing Pools",
        ratesHeader = "Rates",
        descriptionHeader = "Description",
        rankWords = { Guppy = "Guppy", Minnow = "Minnow", Pike = "Pike", Shark = "Shark", Trophy = "Trophy" },
        openWaterWord = "open water",
        poolWord = "pool",
    },
    deDE = {
        scoreLabel = "Angelwertung",
        rankLabel = "Fangrang",
        areasHeader = "Verbreitungsgebiete",
        poolsHeader = "Fischschwärme",
        ratesHeader = "Raten",
        descriptionHeader = "Beschreibung",
        rankWords = { ["Guppy"] = "Guppy" },
        openWaterWord = "offenen gewässern",
        poolWord = "teich",
    },
    esES = {
        scoreLabel = { "Puntaje de pesca", "puntaje de pesca", "Puntuación de pesca", "Puntuacion de pesca", "Puntuaci", "puntuaci" },
        rankLabel = { "Rango de la pesca", "Rango de pesca", "Rango de la captura", "Rango de captura", "rango de" },
        areasHeader = { "Áreas donde puedes encontrar", "Areas donde puedes encontrar", "Zonas en las que puedes encontrar" },
        poolsHeader = { "Estanques de pesca", "Zonas de pesca", "Zona de pesca" },
        ratesHeader = { "Tasa de captura", "Frecuencia" },
        descriptionHeader = "Descripción",
        pointsWord = "puntos",
        rankWords = { ["Lebistes"] = "Guppy", ["Lebiste"] = "Guppy", ["Lebiestes"] = "Guppy" },
        openWaterWord = "mar abierto",
        poolWord = "estanque",
    },
    esMX = {
        scoreLabel = { "Puntaje de pesca", "puntaje de pesca", "Puntuación de pesca", "Puntuacion de pesca", "Puntuaci", "puntuaci" },
        rankLabel = { "Rango de la pesca", "Rango de pesca", "Rango de la captura", "Rango de captura", "rango de" },
        areasHeader = { "Áreas donde puedes encontrar", "Areas donde puedes encontrar", "Zonas en las que puedes encontrar" },
        poolsHeader = { "Estanques de pesca", "Zonas de pesca", "Zona de pesca" },
        ratesHeader = { "Tasa de captura", "Frecuencia" },
        descriptionHeader = "Descripción",
        pointsWord = "puntos",
        rankWords = { ["Lebistes"] = "Guppy", ["Lebiste"] = "Guppy", ["Lebiestes"] = "Guppy" },
        openWaterWord = "aguas abiertas",
        poolWord = "estanque",
    },
    frFR = {
        scoreLabel = "Score de pêche",
        rankLabel = { "Rang de la prise", "Rang de capture" },
        areasHeader = "Poisson présent dans les régions",
        poolsHeader = "Bancs de poissons",
        ratesHeader = "Fréquence",
        descriptionHeader = "Description",
        rankWords = { ["guppy"] = "Guppy", ["Guppy"] = "Guppy", ["trophée"] = "Trophy", ["Trophée"] = "Trophy" },
        openWaterWord = "étendues d’eau",
        poolWord = "bancs de poissons",
    },
    itIT = {
        scoreLabel = "Punteggio di Pesca",
        rankLabel = "Grado di Cattura",
        areasHeader = "Aree in cui si può trovare",
        poolsHeader = "Pozze di Pesca",
        ratesHeader = { "Probabilità", "Frequenza", "Rates" },
        descriptionHeader = "Descrizione",
        rankWords = { ["Bavosa"] = "Guppy" },
        openWaterWord = "mare aperto",
        poolWord = "pozze",
    },
    koKR = {
        scoreLabel = "강태공 점수",
        rankLabel = "어획 등급",
        areasHeader = "이 생선을 잡을 수 있는 지역",
        poolsHeader = "낚시 웅덩이",
        ratesHeader = "확률",
        descriptionHeader = "설명",
        rankWords = { ["치어"] = "Guppy" },
        openWaterWord = "개방된 수역",
        poolWord = "웅덩이",
    },
    ptBR = {
        scoreLabel = "Pontuação de pescaria",
        rankLabel = "Grau da captura",
        areasHeader = "Áreas de ocorrência",
        poolsHeader = "Pesqueiros",
        ratesHeader = "Frequência",
        descriptionHeader = "Descrição",
        rankWords = { ["Lebiste"] = "Guppy" },
        openWaterWord = "águas abertas",
        poolWord = "pesqueiro",
    },
    ruRU = {
        scoreLabel = "Счет рыбалки",
        rankLabel = { "Уровень улова", "Категория улова" },
        areasHeader = "Зоны обитания",
        poolsHeader = "Косяки рыб",
        ratesHeader = "Распространенность",
        descriptionHeader = "Описание",
        rankWords = { ["гуппи"] = "Guppy", ["Гуппи"] = "Guppy" },
        openWaterWord = "открытом море",
        poolWord = "прудах",
    },
    zhCN = {
        scoreLabel = "钓鱼得分",
        rankLabel = "捕获等级",
        areasHeader = { "可发现此鱼的水域", "可以找到这种鱼的地方" },
        poolsHeader = { "垂钓池", "钓鱼场所" },
        ratesHeader = { "几率", "稀有度" },
        descriptionHeader = "描述",
        rankWords = { ["孔雀鱼"] = "Guppy" },
        openWaterWord = "开阔水域",
        poolWord = "鱼群",
    },
    zhTW = {
        scoreLabel = "釣魚分數",
        rankLabel = "漁獲等級",
        areasHeader = "可以找到這種魚的地區",
        poolsHeader = "釣魚池",
        ratesHeader = "機率",
        descriptionHeader = "說明",
        rankWords = { ["孔雀魚"] = "Guppy" },
        openWaterWord = "開放水域",
        poolWord = "魚群",
    },
}
PARSE_LOCALES.enGB = PARSE_LOCALES.enUS
local PARSE = PARSE_LOCALES[GetLocale and GetLocale() or "enUS"] or PARSE_LOCALES.enUS
local CATEGORY_HEX = { "ffffff", "1eff00", "0070dd", "a335ee" }
local RANK_HEX = { Guppy = "9d9d9d", Minnow = "1eff00", Pike = "0070dd", Shark = "a335ee", Trophy = "ff8000" }
local MAP_COILED_ISLE = 2512
local MAP_VAULTS = 2509
local FISHING_CASTS = { [7620] = true, [131474] = true, [131476] = true }
local WATCH_HIDE_DELAY = 25
local WATCH_CLOSE_RESET_DELAY = 30
local fishingActive = false
local watchClosed = false
local watchKeepOpen = false
local watchHiddenForCombat = false
local watchMouseOver = false
local watchHideToken = 0
local watchCloseResetToken = 0
local ScheduleWatchCloseReset
local itemInfoCache = {}

local AREA_CORRECTIONS = {
    ["Atal'Utek"] = { "vaults", "isle" },
    ["Vaults of Ula'tek"] = { "isle" },
}
local MIDNIGHT_ZONE_POOLS = {
    ["Bubbling Bloom"] = true,
    ["Bubbling Beryl"] = true,
    ["Carcass Cargo"] = true,
    ["Lost Treasures"] = true,
    ["Lashing Waves"] = true,
    ["Blossoming Torrent"] = true,
    ["Lost Bounty"] = true,
    ["Oceanic Vortex"] = true,
    ["Obscured School"] = true,
    ["Surface Ripple"] = true,
    ["Hunter Surge"] = true,
    ["Willow Sea"] = true,
    ["Viscous Venom"] = true,
    ["Vile Venom"] = true,
    ["Vile Oddities"] = true,
}

local function GetScoringDB()
    if not AvidAngler.DB then
        return nil
    end
    AvidAngler.DB.scoring = AvidAngler.DB.scoring or {}
    AvidAngler.DB.scoring.lastRanks = AvidAngler.DB.scoring.lastRanks or {}
    AvidAngler.DB.settings = AvidAngler.DB.settings or {}
    AvidAngler.DB.settings.scoring = AvidAngler.DB.settings.scoring or {}
    return AvidAngler.DB.scoring, AvidAngler.DB.settings.scoring
end

local function PersistSettings()
    local _, settings = GetScoringDB()
    if settings then
        settings.showAllZones = showAllZones
        settings.hideTrophy = hideTrophy
        settings.keepScoreWatchOpen = watchKeepOpen
    end
end

local scoreFrame = CreateFrame("Frame", "AvidAnglerScoreFrame", UIParent, "BackdropTemplate")
scoreFrame:SetSize(420, Theme.layout.headerHeight + 82 + MAX_ROWS * ROW_HEIGHT + Theme.layout.padding)
scoreFrame:SetPoint("CENTER", UIParent, "CENTER", 70, -40)
scoreFrame:SetFrameStrata("DIALOG")
scoreFrame:SetBackdrop((Theme:Backdrop("backdrop", "border")))
scoreFrame:SetBackdropColor(unpack(Theme.color.backdrop))
scoreFrame:SetBackdropBorderColor(unpack(Theme.color.border))
scoreFrame:SetMovable(true)
scoreFrame:SetClampedToScreen(true)
scoreFrame:Hide()

local titleBar = CreateFrame("Frame", nil, scoreFrame)
titleBar:SetPoint("TOPLEFT")
titleBar:SetPoint("TOPRIGHT")
titleBar:SetHeight(Theme.layout.headerHeight)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() scoreFrame:StartMoving() end)
titleBar:SetScript("OnDragStop", function() scoreFrame:StopMovingOrSizing() end)

local title = titleBar:CreateFontString(nil, "ARTWORK")
title:SetFontObject(Theme.font.title)
title:SetPoint("LEFT", Theme.layout.padding, 0)
title:SetText(L["SCORING_TITLE"])

local closeButton = Theme:CreateCloseButton(titleBar)
closeButton:SetPoint("RIGHT", -Theme.layout.gutter, 0)
closeButton:SetScript("OnClick", function() scoreFrame:Hide() end)
tinsert(UISpecialFrames, "AvidAnglerScoreFrame")

local zoneButton = Theme:CreateButton(scoreFrame, L["SCORING_SHOW_ZONE"])
zoneButton:SetPoint("TOPLEFT", Theme.layout.padding, -(Theme.layout.headerHeight + 8))
zoneButton:SetWidth(110)

local allButton = Theme:CreateButton(scoreFrame, L["SCORING_SHOW_ALL"])
allButton:SetPoint("LEFT", zoneButton, "RIGHT", Theme.layout.gutter, 0)
allButton:SetWidth(96)

local hideTrophyButton = Theme:CreateButton(scoreFrame, L["SCORING_HIDE_TROPHY"])
hideTrophyButton:SetPoint("LEFT", allButton, "RIGHT", Theme.layout.gutter, 0)
hideTrophyButton:SetWidth(118)

local summaryText = scoreFrame:CreateFontString(nil, "ARTWORK")
summaryText:SetFontObject(Theme.font.heading)
summaryText:SetPoint("TOPLEFT", zoneButton, "BOTTOMLEFT", 0, -12)
summaryText:SetPoint("RIGHT", -Theme.layout.padding, 0)
summaryText:SetJustifyH("LEFT")

local emptyText = scoreFrame:CreateFontString(nil, "ARTWORK")
emptyText:SetFontObject(Theme.font.muted)
emptyText:SetPoint("CENTER", 0, -8)
emptyText:SetText(L["SCORING_EMPTY"])
emptyText:Hide()

local rows = {}
for i = 1, MAX_ROWS do
    local row = Theme:CreatePanel(scoreFrame, "panel", "border")
    row:SetHeight(ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", Theme.layout.padding, -(Theme.layout.headerHeight + 82 + (i - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", -Theme.layout.padding, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
    icon:SetPoint("LEFT", 4, 0)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.body)
    nameText:SetPoint("LEFT", icon, "RIGHT", Theme.layout.gutter, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -160, 0)
    nameText:SetJustifyH("LEFT")

    local rankText = row:CreateFontString(nil, "ARTWORK")
    rankText:SetFontObject(Theme.font.small)
    rankText:SetPoint("LEFT", nameText, "RIGHT", Theme.layout.gutter, 0)
    rankText:SetWidth(78)
    rankText:SetJustifyH("LEFT")

    local scoreText = row:CreateFontString(nil, "ARTWORK")
    scoreText:SetFontObject(Theme.font.muted)
    scoreText:SetPoint("RIGHT", -6, 0)
    scoreText:SetWidth(64)
    scoreText:SetJustifyH("RIGHT")

    row.icon = icon
    row.nameText = nameText
    row.rankText = rankText
    row.scoreText = scoreText
    row:Hide()
    rows[i] = row
end

local watchFrame = CreateFrame("Frame", "AvidAnglerScoreWatchFrame", UIParent, "BackdropTemplate")
watchFrame:SetSize(330, 280)
watchFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 230)
watchFrame:SetFrameStrata("MEDIUM")
watchFrame:SetBackdrop((Theme:Backdrop("backdrop", "border")))
watchFrame:SetBackdropColor(unpack(Theme.color.backdrop))
watchFrame:SetBackdropBorderColor(unpack(Theme.color.border))
watchFrame:SetMovable(true)
watchFrame:SetClampedToScreen(true)
watchFrame:EnableMouse(true)
watchFrame:RegisterForDrag("LeftButton")
watchFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
watchFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
watchFrame:SetScript("OnEnter", function() watchMouseOver = true end)
watchFrame:SetScript("OnLeave", function() watchMouseOver = false end)
watchFrame:Hide()

local watchTitle = watchFrame:CreateFontString(nil, "ARTWORK")
watchTitle:SetFontObject(Theme.font.heading)
watchTitle:SetPoint("TOPLEFT", 10, -8)
watchTitle:SetWidth(270)
watchTitle:SetJustifyH("LEFT")

local watchCloseButton = Theme:CreateCloseButton(watchFrame)
watchCloseButton:SetPoint("TOPRIGHT", -4, -4)
watchCloseButton:SetScript("OnClick", function()
    watchClosed = true
    watchHideToken = watchHideToken + 1
    watchFrame:Hide()
    if ScheduleWatchCloseReset then
        ScheduleWatchCloseReset()
    end
end)

local watchSummary = watchFrame:CreateFontString(nil, "ARTWORK")
watchSummary:SetFontObject(Theme.font.small)
watchSummary:SetPoint("TOPLEFT", watchTitle, "BOTTOMLEFT", 0, -3)
watchSummary:SetPoint("RIGHT", -10, 0)
watchSummary:SetJustifyH("LEFT")

local watchRows = {}
for i = 1, 6 do
    local row = CreateFrame("Frame", nil, watchFrame)
    row:SetHeight(16)
    row:SetPoint("TOPLEFT", watchSummary, "BOTTOMLEFT", 0, -7 - ((i - 1) * 17))
    row:SetPoint("RIGHT", -10, 0)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.small)
    nameText:SetPoint("LEFT")
    nameText:SetWidth(190)
    nameText:SetJustifyH("LEFT")

    local scoreText = row:CreateFontString(nil, "ARTWORK")
    scoreText:SetFontObject(Theme.font.small)
    scoreText:SetPoint("LEFT", nameText, "RIGHT", Theme.layout.gutter, 0)
    scoreText:SetWidth(48)
    scoreText:SetJustifyH("RIGHT")

    local rankText = row:CreateFontString(nil, "ARTWORK")
    rankText:SetFontObject(Theme.font.small)
    rankText:SetPoint("RIGHT")
    rankText:SetWidth(58)
    rankText:SetJustifyH("RIGHT")

    row.nameText = nameText
    row.scoreText = scoreText
    row.rankText = rankText
    row:Hide()
    watchRows[i] = row
end

local watchOpportunityTitle = watchFrame:CreateFontString(nil, "ARTWORK")
watchOpportunityTitle:SetFontObject(Theme.font.heading)
watchOpportunityTitle:SetPoint("TOPLEFT", watchRows[#watchRows], "BOTTOMLEFT", 0, -8)

local watchOpportunityRows = {}
for i = 1, 5 do
    local row = CreateFrame("Frame", nil, watchFrame)
    row:SetHeight(14)
    row:SetPoint("TOPLEFT", watchOpportunityTitle, "BOTTOMLEFT", 0, -4 - ((i - 1) * 15))
    row:SetPoint("RIGHT", -10, 0)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.small)
    nameText:SetPoint("LEFT")
    nameText:SetPoint("RIGHT", row, "RIGHT", -184, 0)
    nameText:SetJustifyH("LEFT")

    local scoreText = row:CreateFontString(nil, "ARTWORK")
    scoreText:SetFontObject(Theme.font.small)
    scoreText:SetPoint("RIGHT", row, "RIGHT", -108, 0)
    scoreText:SetWidth(68)
    scoreText:SetJustifyH("RIGHT")

    local percentText = row:CreateFontString(nil, "ARTWORK")
    percentText:SetFontObject(Theme.font.small)
    percentText:SetPoint("RIGHT", row, "RIGHT", -66, 0)
    percentText:SetWidth(36)
    percentText:SetJustifyH("RIGHT")

    local leftText = row:CreateFontString(nil, "ARTWORK")
    leftText:SetFontObject(Theme.font.muted)
    leftText:SetPoint("RIGHT")
    leftText:SetWidth(60)
    leftText:SetJustifyH("RIGHT")

    row.nameText = nameText
    row.scoreText = scoreText
    row.percentText = percentText
    row.leftText = leftText
    row:Hide()
    watchOpportunityRows[i] = row
end

local watchLegend = watchFrame:CreateFontString(nil, "ARTWORK")
watchLegend:SetFontObject(Theme.font.muted)
watchLegend:SetPoint("BOTTOMLEFT", 10, 8)
watchLegend:SetPoint("RIGHT", -10, 0)
watchLegend:SetJustifyH("LEFT")
watchLegend:SetText(L["SCORING_LEGEND"])

local toastFrame = Theme:CreatePanel(UIParent, "panelRaised", "accent")
toastFrame:SetSize(420, 86)
toastFrame:SetFrameStrata("DIALOG")
toastFrame:Hide()

local toastAccent = toastFrame:CreateTexture(nil, "ARTWORK")
toastAccent:SetColorTexture(unpack(Theme.color.accent))
toastAccent:SetPoint("TOPLEFT", 1, -1)
toastAccent:SetPoint("BOTTOMLEFT", 1, 1)
toastAccent:SetWidth(4)

local toastGlow = toastFrame:CreateTexture(nil, "BACKGROUND")
toastGlow:SetColorTexture(1, 1, 1, 0.07)
toastGlow:SetPoint("TOPLEFT", 5, -1)
toastGlow:SetPoint("TOPRIGHT", -1, -1)
toastGlow:SetHeight(22)

local toastIconBorder = Theme:CreatePanel(toastFrame, "backdrop", "accent")
toastIconBorder:SetSize(48, 48)
toastIconBorder:SetPoint("LEFT", 16, 0)

local toastIcon = toastIconBorder:CreateTexture(nil, "ARTWORK")
toastIcon:SetPoint("TOPLEFT", 2, -2)
toastIcon:SetPoint("BOTTOMRIGHT", -2, 2)
toastIcon:SetTexture("Interface\\Icons\\Trade_Fishing")

local toastTitle = toastFrame:CreateFontString(nil, "ARTWORK")
toastTitle:SetFontObject(Theme.font.heading)
toastTitle:SetPoint("TOPLEFT", toastIconBorder, "TOPRIGHT", 12, -2)
toastTitle:SetPoint("RIGHT", -14, 0)
toastTitle:SetJustifyH("LEFT")

local toastRank = toastFrame:CreateFontString(nil, "ARTWORK")
toastRank:SetFontObject(Theme.font.body)
toastRank:SetPoint("TOPLEFT", toastTitle, "BOTTOMLEFT", 0, -5)
toastRank:SetPoint("RIGHT", -14, 0)
toastRank:SetJustifyH("LEFT")

local toastText = toastFrame:CreateFontString(nil, "ARTWORK")
toastText:SetFontObject(Theme.font.small)
toastText:SetPoint("TOPLEFT", toastRank, "BOTTOMLEFT", 0, -5)
toastText:SetPoint("RIGHT", -14, 0)
toastText:SetJustifyH("LEFT")

local toastToken = 0

local function ReadItemInfo(itemID)
    if not itemID or not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return nil
    end

    local ok, name, link, quality, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, itemID)
    if not ok or (not name and not icon) then
        return nil
    end

    local info = itemInfoCache[itemID] or {}
    info.name = name or info.name
    info.link = link or info.link
    info.quality = quality or info.quality
    info.icon = icon or info.icon
    info.ready = info.name ~= nil or info.icon ~= nil
    itemInfoCache[itemID] = info
    return info
end

local function GetItemInfoCached(itemID, callback)
    if not itemID then
        return nil
    end

    local cached = itemInfoCache[itemID]
    if cached and cached.ready then
        if callback then
            callback(cached)
        end
        return cached
    end

    local info = ReadItemInfo(itemID)
    if info and info.ready then
        if callback then
            callback(info)
        end
        return info
    end

    if callback and Item and type(Item.CreateFromItemID) == "function" then
        cached = cached or {}
        cached.callbacks = cached.callbacks or {}
        cached.callbacks[#cached.callbacks + 1] = callback
        itemInfoCache[itemID] = cached
        if not cached.loading then
            cached.loading = true
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                local loaded = ReadItemInfo(itemID) or cached
                loaded.ready = loaded.ready or loaded.name ~= nil or loaded.icon ~= nil
                loaded.loading = false
                local callbacks = loaded.callbacks or {}
                loaded.callbacks = nil
                itemInfoCache[itemID] = loaded
                for i = 1, #callbacks do
                    callbacks[i](loaded)
                end
            end)
        end
    end

    return itemInfoCache[itemID]
end

local function GetEntryDisplayName(entry)
    if not entry then
        return ""
    end

    local itemInfo = GetItemInfoCached(entry.itemID)
    return (itemInfo and itemInfo.name) or entry.name or ("item:" .. tostring(entry.itemID or entry.spellID or "?"))
end

local function GetEntryIcon(entry)
    if not entry then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local itemInfo = GetItemInfoCached(entry.itemID)
    return (itemInfo and itemInfo.icon) or entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetCurrentZoneMapID()
    return C_Map.GetBestMapForUnit("player")
end

local function StripCodes(text)
    text = (text or ""):gsub("|n", "\n")
    text = text:gsub("|H(.-)|h(.-)|h", "%2")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|cn.-:", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    return text
end

local function ParseNumber(text)
    if not text then
        return nil
    end
    local value = tostring(text):match("(%d+[%d%.,]*)")
    if not value then
        return nil
    end
    return tonumber((value:gsub(",", "."):gsub("[%.]+$", "")))
end

local function FindLabel(text, labels)
    if type(labels) == "table" then
        for _, label in ipairs(labels) do
            local startIndex, endIndex = text:find(label, 1, true)
            if startIndex then
                return startIndex, endIndex
            end
            startIndex, endIndex = text:lower():find(tostring(label):lower(), 1, true)
            if startIndex then
                return startIndex, endIndex
            end
        end
        return nil
    end
    if not labels then
        return nil
    end
    local startIndex, endIndex = text:find(labels, 1, true)
    if startIndex then
        return startIndex, endIndex
    end
    return text:lower():find(tostring(labels):lower(), 1, true)
end

local function MatchAfter(text, endIndex, pattern)
    if not endIndex then
        return nil
    end
    return text:sub(endIndex + 1):match(pattern)
end

local function FindNumberAfterLabel(text, labels)
    local _, firstLabelEnd = FindLabel(text, labels)
    local foundLabel = firstLabelEnd ~= nil
    local value = ParseNumber(MatchAfter(text, firstLabelEnd, "^%D*([%d%.,]+)"))
    if value then
        return value, true
    end

    for rawLine in tostring(text or ""):gmatch("[^\n\r]+") do
        local _, labelEnd = FindLabel(rawLine, labels)
        if labelEnd then
            value = ParseNumber(MatchAfter(rawLine, labelEnd, "^[^%d\r\n]*([%d%.,]+)"))
            if value then
                return value, true
            end
        end
    end
    return nil, foundLabel
end

local function FindLineAfterLabel(text, labels)
    for rawLine in tostring(text or ""):gmatch("[^\n\r]+") do
        local _, labelEnd = FindLabel(rawLine, labels)
        local line = MatchAfter(rawLine, labelEnd, "^%s*([^\n\r]+)")
        if line and line ~= "" then
            return line
        end
    end
    return nil
end

local function StartsWithAny(text, prefixes)
    if type(prefixes) == "table" then
        for _, prefix in ipairs(prefixes) do
            if prefix and text:sub(1, #prefix) == prefix then
                return true
            end
        end
        return false
    end
    return prefixes and text:sub(1, #prefixes) == prefixes or false
end

local function RankFromScore(score)
    local best = "Guppy"
    for _, rankName in ipairs(RANK_ORDER) do
        local cutoff = RANK_CUTOFFS[rankName]
        if not cutoff or score >= cutoff then
            best = rankName
        end
    end
    return best
end

local function GetRankDisplayName(rankName)
    return L["SCORING_RANK_" .. tostring(rankName or "UNKNOWN"):upper()] or rankName or L["SCORING_RANK_UNKNOWN"]
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function NormalizeZoneName(name)
    return Trim(name):lower()
end

local function MapName(mapID, fallback)
    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return (mapInfo and mapInfo.name) or fallback
end

local function AddArea(info, area)
    local correction = AREA_CORRECTIONS[area]
    if correction then
        for _, target in ipairs(correction) do
            if target == "vaults" then
                AddArea(info, MapName(MAP_VAULTS, "Vaults of Atal'Utek"))
            elseif target == "isle" then
                AddArea(info, MapName(MAP_COILED_ISLE, "The Coiled Isle"))
            end
        end
        return
    end
    local key = NormalizeZoneName(area)
    if info.areaKeys and info.areaKeys[key] then
        return
    end
    info.areaKeys = info.areaKeys or {}
    info.areaKeys[key] = true
    info.areas[#info.areas + 1] = area
end

local function BulletValue(line)
    local value = line:match("^%s*%-+%s*(.-)%s*$")
    if not value and line:sub(1, 3) == "\226\128\147" then
        value = line:sub(4):match("^%s*(.-)%s*$")
    end
    if not value or value == "" then
        return nil
    end
    return (value:gsub("[%.;,]+$", ""))
end

local function ParseFish(definition)
    if not C_Spell or type(C_Spell.GetSpellDescription) ~= "function" then
        return nil, true
    end

    local description = AvidAngler:SafeCall(C_Spell.GetSpellDescription, nil, definition.spellID)
    if not description or description == "" then
        return nil, true
    end
    description = StripCodes(description)

    local spellInfo = AvidAngler:SafeCall(C_Spell.GetSpellInfo, nil, definition.spellID)
    local info = {
        spellID = definition.spellID,
        itemID = definition.itemID,
        category = definition.category,
        excludeFromScore = definition.excludeFromScore and true or false,
        name = (spellInfo and spellInfo.name) or ("spell:" .. definition.spellID),
        icon = spellInfo and spellInfo.iconID,
        score = 0,
        scoreable = false,
        areas = {},
        areaKeys = {},
        pools = {},
        rates = {},
        lure = FISH_LURES[definition.spellID] and true or false,
    }

    local score, scoreable = FindNumberAfterLabel(description, PARSE.scoreLabel)
    info.scoreable = scoreable
    info.score = score or 0

    local rankLine = FindLineAfterLabel(description, PARSE.rankLabel)
    if rankLine then
        for localizedRank, rankName in pairs(PARSE.rankWords or {}) do
            if rankLine:find(localizedRank, 1, true) then
                info.rankName = rankName
                break
            end
        end
    end
    if not info.rankName and info.scoreable and info.score > 0 then
        info.rankName = RankFromScore(info.score)
    end
    info.rankLevel = RANK_LEVEL[info.rankName] or 0

    local mode
    for rawLine in description:gmatch("[^\n\r]+") do
        local line = Trim(rawLine)
        if StartsWithAny(line, PARSE.areasHeader) then
            mode = "areas"
        elseif StartsWithAny(line, PARSE.poolsHeader) then
            mode = "pools"
        elseif StartsWithAny(line, PARSE.ratesHeader) then
            mode = "rates"
        elseif StartsWithAny(line, PARSE.descriptionHeader) then
            mode = nil
        else
            local value = BulletValue(line)
            if value and mode == "areas" then
                AddArea(info, value)
            elseif value and mode == "pools" then
                info.pools[#info.pools + 1] = value
            elseif value and mode == "rates" then
                info.rates[#info.rates + 1] = value
            end
        end
    end

    local rateText = table.concat(info.rates, " "):lower()
    local mentionsOpenWater = PARSE.openWaterWord and rateText:find(PARSE.openWaterWord, 1, true)
    local mentionsPool = PARSE.poolWord and rateText:find(PARSE.poolWord, 1, true)
    if mentionsOpenWater and mentionsPool then
        info.sourceKey = "either"
        info.sourceTag = L["SCORING_SOURCE_EITHER"]
    elseif mentionsOpenWater then
        info.sourceKey = "open-water"
        info.sourceTag = L["SCORING_SOURCE_OPEN"]
    elseif mentionsPool then
        info.sourceKey = "pool"
        info.sourceTag = L["SCORING_SOURCE_POOL"]
    end
    return info, false
end

local function GetCurrentZoneNames()
    local names = {}
    local zone = GetZoneText()
    if zone and zone ~= "" then
        names[NormalizeZoneName(zone)] = true
    end
    local subzone = GetSubZoneText()
    if subzone and subzone ~= "" then
        names[NormalizeZoneName(subzone)] = true
    end
    local mapID = GetCurrentZoneMapID()
    local hops = 0
    while mapID and hops < 6 do
        local mapInfo = C_Map.GetMapInfo(mapID)
        if not mapInfo then
            break
        end
        if mapInfo.name then
            names[NormalizeZoneName(mapInfo.name)] = true
        end
        mapID = (mapInfo.parentMapID and mapInfo.parentMapID > 0) and mapInfo.parentMapID or nil
        hops = hops + 1
    end
    return names
end

local function FishMatchesCurrentZone(info, currentZones)
    for _, area in ipairs(info.areas or {}) do
        if currentZones[NormalizeZoneName(area)] then
            return true
        end
    end
    return false
end

local function BuildCatchCounts()
    local catches = AvidAngler.DataLayer:GetCatches()
    local counts = {
        byItemID = {},
        byName = {},
    }
    for i = 1, #catches do
        local record = catches[i]
        if record.itemID then
            local entry = counts.byItemID[record.itemID] or { quantity = 0, catches = 0 }
            entry.quantity = entry.quantity + (record.quantity or 1)
            entry.catches = entry.catches + 1
            counts.byItemID[record.itemID] = entry
        end
        if record.itemName then
            local key = NormalizeZoneName(record.itemName)
            if key then
                local entry = counts.byName[key] or { quantity = 0, catches = 0 }
                entry.quantity = entry.quantity + (record.quantity or 1)
                entry.catches = entry.catches + 1
                counts.byName[key] = entry
            end
        end
    end
    return counts
end

local function RequestScoreData()
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    if not C_Spell or type(C_Spell.RequestLoadSpellData) ~= "function" then
        return
    end
    for _, definition in ipairs(FISHING_JOURNAL_FISH) do
        pcall(C_Spell.RequestLoadSpellData, definition.spellID)
    end
    pcall(C_Spell.RequestLoadSpellData, SCORE_SPELL_ID)
end

local function QueueScoreRefresh(delay)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end
    if retryPending then
        return
    end
    retryPending = true
    C_Timer.After(delay or 1, function()
        retryPending = false
        ClearScoreCache()
        RequestScoreData()
        Scoring:Refresh()
        if watchFrame:IsShown() then
            Scoring:RefreshFishingWindow()
        end
    end)
end

local function GetWarbandScore()
    local ok, _, _, _, quantity = pcall(GetAchievementCriteriaInfo, SCORE_ACHIEVEMENT_ID, 1)
    local criteriaScore = ok and AvidAngler:SafeValue(quantity, nil) or nil
    if C_Spell and type(C_Spell.GetSpellDescription) == "function" then
        local description = AvidAngler:SafeCall(C_Spell.GetSpellDescription, nil, SCORE_SPELL_ID)
        local precise
        if description then
            description = StripCodes(description)
            precise = PARSE.pointsWord and description:match("([%d%.,]+)%s*" .. PARSE.pointsWord)
            precise = precise or description:match("([%d%.,]+)%s*points")
        end
        if precise then
            return precise:gsub(",", "."), criteriaScore
        end
    end
    return criteriaScore and tostring(criteriaScore) or "?", criteriaScore
end

local function BuildScores(showAllOverride)
    local includeAllZones = showAllOverride
    if includeAllZones == nil then
        includeAllZones = showAllZones
    end
    local currentZones = GetCurrentZoneNames()
    local catchCounts = BuildCatchCounts()
    local rowsOut = {}
    local zoneAgg = {}
    local totalScore = 0
    local totalMax = 0
    local trophies = 0
    local scoreableTypes = 0
    dataPending = 0

    for _, definition in ipairs(FISHING_JOURNAL_FISH) do
        local info, pending = ParseFish(definition)
        if pending then
            dataPending = dataPending + 1
        elseif info then
            local inZone = FishMatchesCurrentZone(info, currentZones)
            if info.scoreable and not info.excludeFromScore then
                for _, area in ipairs(info.areas or {}) do
                    local key = NormalizeZoneName(area)
                    local zone = zoneAgg[key] or { name = area, score = 0, max = 0, types = 0 }
                    zone.score = zone.score + info.score
                    zone.max = zone.max + 100
                    zone.types = zone.types + 1
                    zoneAgg[key] = zone
                end
            end

            if info.scoreable and not info.excludeFromScore and (includeAllZones or inZone) then
                local caught = catchCounts.byItemID[info.itemID] or catchCounts.byName[NormalizeZoneName(info.name)]
                info.quantity = caught and caught.quantity or 0
                info.catches = caught and caught.catches or 0
                info.points = info.score
                info.categoryHex = CATEGORY_HEX[info.category] or "ffffff"
                info.rankName = info.rankName or L["SCORING_RANK_UNKNOWN"]
                info.rankLevel = info.rankLevel or 0
                totalScore = totalScore + info.score
                totalMax = totalMax + 100
                scoreableTypes = scoreableTypes + 1
                if info.rankLevel >= RANK_LEVEL.Trophy then
                    trophies = trophies + 1
                end
                if not hideTrophy or info.rankLevel < RANK_LEVEL.Trophy then
                    rowsOut[#rowsOut + 1] = info
                end
            end
        end
    end

    table.sort(rowsOut, function(a, b)
        if a.score ~= b.score then
            return a.score < b.score
        end
        return GetEntryDisplayName(a) < GetEntryDisplayName(b)
    end)

    local opportunities = {}
    for _, zone in pairs(zoneAgg) do
        zone.left = zone.max - zone.score
        zone.percent = zone.max > 0 and (zone.score / zone.max * 100) or 0
        opportunities[#opportunities + 1] = zone
    end
    table.sort(opportunities, function(a, b)
        if a.left ~= b.left then
            return a.left > b.left
        end
        return a.name < b.name
    end)

    local warbandScore = GetWarbandScore()
    return rowsOut, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies
end

local function GetScoreCacheKey(showAllOverride)
    local catches = AvidAngler.DataLayer and AvidAngler.DataLayer.GetCatches and AvidAngler.DataLayer:GetCatches() or {}
    local lastCatch = catches[#catches]
    local includeAllZones = showAllOverride
    if includeAllZones == nil then
        includeAllZones = showAllZones
    end

    return table.concat({
        includeAllZones and 1 or 0,
        hideTrophy and 1 or 0,
        GetZoneText() or "",
        GetSubZoneText() or "",
        GetCurrentZoneMapID() or 0,
        #catches,
        lastCatch and (lastCatch.timestamp or 0) or 0,
        lastCatch and (lastCatch.itemID or 0) or 0,
        lastCatch and (lastCatch.quantity or 1) or 0,
    }, ":")
end

local function BuildScoresCached(showAllOverride)
    local key = GetScoreCacheKey(showAllOverride)
    local cached = scoreCache[key]
    if cached then
        dataPending = cached.pending or 0
        return cached.rows, cached.scoreableTypes, cached.totalScore, cached.opportunities, cached.warbandScore, cached.totalMax, cached.trophies
    end

    local rowsOut, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies = BuildScores(showAllOverride)
    scoreCache[key] = {
        rows = rowsOut,
        scoreableTypes = scoreableTypes,
        totalScore = totalScore,
        opportunities = opportunities,
        warbandScore = warbandScore,
        totalMax = totalMax,
        trophies = trophies,
        pending = dataPending,
    }
    return rowsOut, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies
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

local function RefreshRow(row, entry)
    row.itemID = entry.itemID
    row.icon:SetTexture(GetEntryIcon(entry))
    row.nameText:SetText(Scoring:FormatFishLabel(entry))
    row.rankText:SetText(entry.rankName)
    row.scoreText:SetText(("%.1f"):format(entry.score or 0))
    GetItemInfoCached(entry.itemID, function()
        if row.itemID == entry.itemID then
            row.icon:SetTexture(GetEntryIcon(entry))
            row.nameText:SetText(Scoring:FormatFishLabel(entry))
        end
    end)
end

function Scoring:FormatFishLabel(entry)
    if not entry then
        return ""
    end
    local suffix = entry.sourceTag and (" " .. entry.sourceTag) or ""
    if entry.lure then
        suffix = suffix .. " " .. L["SCORING_SOURCE_LURE"]
    end
    return ("|cff%s%s|r%s"):format(entry.categoryHex or CATEGORY_HEX[entry.category] or "ffffff", GetEntryDisplayName(entry), suffix)
end

function Scoring:FormatRankLabel(entry)
    if not entry then
        return ""
    end
    local rankName = entry.rankName or L["SCORING_RANK_UNKNOWN"]
    return ("|cff%s%s|r"):format(RANK_HEX[rankName] or "9d9d9d", GetRankDisplayName(rankName))
end

local function RefreshWatchFrame()
    if not moduleEnabled then
        watchFrame:Hide()
        return
    end

    local scoreRows, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies = BuildScoresCached(false)
    if dataPending > 0 and #scoreRows == 0 then
        watchFrame.scoreRowsShown = 0
        watchTitle:SetText(L["SCORING_WATCH_TITLE"]:format(GetZoneText() or "?"))
        watchSummary:SetText(L["SCORING_LOADING"]:format(dataPending))
        for i = 1, #watchRows do
            watchRows[i]:Hide()
        end
        for i = 1, #watchOpportunityRows do
            watchOpportunityRows[i]:Hide()
        end
        watchOpportunityTitle:SetText("")
        return
    end

    watchFrame.scoreRowsShown = #scoreRows
    watchTitle:SetText(L["SCORING_WATCH_TITLE"]:format(GetZoneText() or "?"))
    watchSummary:SetText(L["SCORING_SUMMARY"]:format(totalScore, totalMax, trophies, scoreableTypes, warbandScore or "?"))
    for i = 1, #watchRows do
        local row = watchRows[i]
        local entry = scoreRows[i]
        if entry then
            row.itemID = entry.itemID
            row.nameText:SetText(Scoring:FormatFishLabel(entry))
            row.scoreText:SetText(("%.1f"):format(entry.score or 0))
            row.rankText:SetText(Scoring:FormatRankLabel(entry))
            GetItemInfoCached(entry.itemID, function()
                if row.itemID == entry.itemID then
                    row.nameText:SetText(Scoring:FormatFishLabel(entry))
                end
            end)
            row:Show()
        else
            row.itemID = nil
            row:Hide()
        end
    end

    if opportunities and #opportunities > 0 then
        watchOpportunityTitle:SetText(L["SCORING_OPPORTUNITIES_TITLE"])
    else
        watchOpportunityTitle:SetText("")
    end
    for i = 1, #watchOpportunityRows do
        local row = watchOpportunityRows[i]
        local opportunity = opportunities and opportunities[i]
        if opportunity then
            row.nameText:SetText(opportunity.name)
            row.scoreText:SetText(("%.0f / %d"):format(opportunity.score, opportunity.max))
            row.percentText:SetText(("%.0f%%"):format(opportunity.percent))
            row.leftText:SetText(L["SCORING_OPPORTUNITY_LEFT"]:format(opportunity.left))
            row:Show()
        else
            row:Hide()
        end
    end
end

function Scoring:RefreshFishingWindow()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    RefreshWatchFrame()
    if fishingActive and not watchClosed and watchFrame.scoreRowsShown and watchFrame.scoreRowsShown > 0 then
        watchFrame:Show()
    end
end

ScheduleWatchCloseReset = function()
    watchCloseResetToken = watchCloseResetToken + 1
    local token = watchCloseResetToken
    C_Timer.After(WATCH_CLOSE_RESET_DELAY, function()
        if token == watchCloseResetToken and not fishingActive then
            watchClosed = false
        end
    end)
end

local function ScheduleWatchHide(delay)
    watchHideToken = watchHideToken + 1
    local token = watchHideToken
    C_Timer.After(delay or WATCH_HIDE_DELAY, function()
        if token ~= watchHideToken or fishingActive then
            return
        end
        if watchMouseOver or (watchFrame.IsMouseOver and watchFrame:IsMouseOver()) then
            ScheduleWatchHide(1)
            return
        end
        watchFrame:Hide()
        watchClosed = false
    end)
end

local function HideWatchImmediately()
    watchHiddenForCombat = watchFrame:IsShown()
    fishingActive = false
    watchClosed = false
    watchHideToken = watchHideToken + 1
    watchCloseResetToken = watchCloseResetToken + 1
    watchFrame:Hide()
end

local function ShowWatchForFishing()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    fishingActive = true
    watchHideToken = watchHideToken + 1
    watchCloseResetToken = watchCloseResetToken + 1
    if not watchFrame:IsShown() or not watchFrame.scoreRowsShown or watchFrame.scoreRowsShown <= 0 then
        RequestScoreData()
        Scoring:RefreshFishingWindow()
    else
        watchFrame:Show()
    end
end

local function HideWatchAfterFishing()
    fishingActive = false
    ScheduleWatchCloseReset()
    if watchKeepOpen then
        return
    end
    ScheduleWatchHide(WATCH_HIDE_DELAY)
end

local function ReopenWatchAfterCombat()
    if not watchHiddenForCombat then
        return
    end
    watchHiddenForCombat = false
    RequestScoreData()
    RefreshWatchFrame()
    if not watchClosed and watchFrame.scoreRowsShown and watchFrame.scoreRowsShown > 0 then
        watchFrame:Show()
        if not watchKeepOpen then
            ScheduleWatchHide(WATCH_HIDE_DELAY)
        end
    end
end

local function RefreshAfterZoneChange()
    pendingZoneRefresh = false
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        return
    end

    ClearScoreCache()
    RequestScoreData()
    if watchFrame:IsShown() then
        RefreshWatchFrame()
    end
    if scoreFrame:IsShown() then
        Scoring:Refresh()
    end
end

local function QueueZoneRefresh()
    if pendingZoneRefresh then
        return
    end

    pendingZoneRefresh = true
    C_Timer.After(0.35, RefreshAfterZoneChange)
end

local function ShowScoreTooltip(row, entry)
    if not entry then
        return
    end

    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local itemInfo = entry.itemID and GetItemInfoCached(entry.itemID)
    if itemInfo and itemInfo.name and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("item:" .. tostring(entry.itemID))
    else
        GameTooltip:SetText(GetEntryDisplayName(entry))
    end
    GameTooltip:AddLine(L["SCORING_TOOLTIP_RANK"]:format(GetRankDisplayName(entry.rankName)), 1, 1, 1)
    GameTooltip:AddLine(L["SCORING_TOOLTIP_SCORE"]:format(entry.score or 0), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["SCORING_TOOLTIP_SEEN"]:format(entry.quantity or 0, entry.catches or 0), 0.8, 0.8, 0.8)
    if entry.lure then
        GameTooltip:AddLine(L["SCORING_TOOLTIP_LURE"], 0.64, 0.21, 0.93, true)
    end
    if entry.areas and #entry.areas > 0 then
        GameTooltip:AddLine(L["SCORING_TOOLTIP_AREAS"]:format(table.concat(entry.areas, ", ")), 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
end

function Scoring:DecorateRowTooltip(row, entry)
    row.scoreEntry = entry
    row:EnableMouse(entry ~= nil)
    row:SetScript("OnEnter", function(self)
        ShowScoreTooltip(self, self.scoreEntry)
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function PositionToast()
    toastFrame:ClearAllPoints()
    if AlertFrame then
        toastFrame:SetPoint("TOP", AlertFrame, "BOTTOM", 0, -10)
    else
        toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -170)
    end
end

local function SetToastRankColor(rankName)
    local hex = RANK_HEX[rankName] or RANK_HEX.Guppy
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    toastRank:SetTextColor(r, g, b)
    toastAccent:SetColorTexture(r, g, b, 1)
    toastIconBorder:SetBackdropBorderColor(r, g, b, 0.85)
end

local function GetItemToastInfo(itemID, fallbackIcon)
    local icon = fallbackIcon or "Interface\\Icons\\Trade_Fishing"
    local nameColor = "|cffffffff"
    if itemID and C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, _, link, quality, _, _, _, _, _, _, itemIcon = pcall(C_Item.GetItemInfo, itemID)
        if ok then
            icon = itemIcon or icon
            if link then
                local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
                nameColor = color or nameColor
            elseif quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                local r, g, b = color:GetRGB()
                nameColor = ("|cff%02x%02x%02x"):format(math.floor((r * 255) + 0.5), math.floor((g * 255) + 0.5), math.floor((b * 255) + 0.5))
            end
        end
    end
    return icon, nameColor
end

local function ShowRankToast(itemText, rankName, quantity, icon, itemID)
    toastToken = toastToken + 1
    local token = toastToken
    PositionToast()
    SetToastRankColor(rankName)
    local toastIconTexture, itemColor = GetItemToastInfo(itemID, icon)
    local rankDisplayName = GetRankDisplayName(rankName)
    toastTitle:SetText(L["SCORING_TOAST_TITLE"])
    toastRank:SetText(L["SCORING_TOAST_RANK_LINE"]:format(itemColor .. itemText .. "|r", ("|cff%s%s|r"):format(RANK_HEX[rankName] or RANK_HEX.Guppy, rankDisplayName)))
    toastText:SetText(L["SCORING_IMPROVED"]:format(itemText, rankDisplayName, quantity))
    toastIcon:SetTexture(toastIconTexture)
    toastFrame:SetAlpha(1)
    toastFrame:Show()
    if itemID and Item and type(Item.CreateFromItemID) == "function" then
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            if token == toastToken then
                local itemIcon, itemColor = GetItemToastInfo(itemID, icon)
                toastIcon:SetTexture(itemIcon)
                toastRank:SetText(L["SCORING_TOAST_RANK_LINE"]:format(itemColor .. itemText .. "|r", ("|cff%s%s|r"):format(RANK_HEX[rankName] or RANK_HEX.Guppy, rankDisplayName)))
            end
        end)
    end
    if UIFrameFadeIn then
        UIFrameFadeIn(toastFrame, 0.15, 0, 1)
    end
    C_Timer.After(4.25, function()
        if token == toastToken then
            UIFrameFadeOut(toastFrame, 0.45, toastFrame:GetAlpha(), 0)
            C_Timer.After(0.5, function()
                if token == toastToken then
                    toastFrame:Hide()
                    toastFrame:SetAlpha(1)
                end
            end)
        end
    end)
    return token
end

function Scoring:GetSummary()
    local scoreRows, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies = BuildScoresCached()
    return {
        types = #scoreRows,
        scoreableTypes = scoreableTypes,
        fish = scoreableTypes,
        points = totalScore,
        maxPoints = totalMax,
        trophies = trophies,
        warbandScore = warbandScore,
        opportunities = opportunities,
        pending = dataPending,
        rows = scoreRows,
    }
end

function Scoring:GetAchievementSummary()
    local name = L["SCORING_ACHIEVEMENT_TITLE"]
    local description = L["SCORING_ACHIEVEMENT_DESC"]
    local icon
    if C_AchievementInfo and C_AchievementInfo.GetAchievementInfo then
        local info = C_AchievementInfo.GetAchievementInfo(SCORE_ACHIEVEMENT_ID)
        if info then
            name = info.name or name
            description = info.description or description
            icon = info.icon
        end
    elseif GetAchievementInfo then
        local _, achievementName, _, _, _, _, _, achievementDescription, _, achievementIcon = GetAchievementInfo(SCORE_ACHIEVEMENT_ID)
        name = achievementName or name
        description = achievementDescription or description
        icon = achievementIcon
    end
    return {
        id = SCORE_ACHIEVEMENT_ID,
        name = name,
        description = description,
        target = SCORE_ACHIEVEMENT_TARGET,
        icon = icon,
    }
end

function Scoring:GetKnownCatchSource(itemID, itemName)
    local normalizedName = itemName and NormalizeZoneName(itemName)
    for _, entry in ipairs(self:GetKnownFishEntries()) do
        if (itemID and entry.itemID == itemID) or (normalizedName and NormalizeZoneName(entry.name) == normalizedName) then
            if entry.sourceKey == "pool" or entry.sourceKey == "open-water" or entry.sourceKey == "either" then
                return entry.sourceKey, entry.sourceKey == "pool" and entry.pools and entry.pools[1] or nil
            end
            return nil
        end
    end
end

function Scoring:GetKnownFishEntries()
    if knownFishEntriesCache then
        return knownFishEntriesCache
    end

    local entries = {}
    for _, definition in ipairs(FISHING_JOURNAL_FISH) do
        local info = ParseFish(definition)
        if info then
            entries[#entries + 1] = info
        end
    end
    knownFishEntriesCache = entries
    return entries
end

function Scoring:GetKnownFishLookup()
    if knownFishLookupCache then
        return knownFishLookupCache
    end

    local lookup = { byID = {}, byName = {} }
    for _, entry in ipairs(self:GetKnownFishEntries()) do
        if entry.itemID then
            lookup.byID[entry.itemID] = true
        end
        local normalizedName = NormalizeZoneName(entry.name)
        if normalizedName then
            lookup.byName[normalizedName] = true
        end
    end
    knownFishLookupCache = lookup
    return lookup
end

function Scoring:IsKnownFish(itemID, itemName)
    local normalizedName = itemName and NormalizeZoneName(itemName)
    local lookup = self:GetKnownFishLookup()
    return (itemID and lookup.byID[itemID]) or (normalizedName and lookup.byName[normalizedName]) or false
end

function Scoring:GetKnownPoolTooltip(text)
    local normalizedText = text and NormalizeZoneName(text)
    if not normalizedText then
        return false
    end

    local poolCatalog = AvidAngler.Data and AvidAngler.Data.PoolCatalog
    if poolCatalog and poolCatalog:IsPool(nil, text) then
        local entry = poolCatalog:Get(nil, text)
        return true, entry and entry.name or text
    end

    for poolName in pairs(MIDNIGHT_ZONE_POOLS) do
        if NormalizeZoneName(poolName) == normalizedText then
            return true, poolName
        end
    end

    local rows = BuildScoresCached(true)
    for _, entry in ipairs(rows) do
        for _, poolName in ipairs(entry.pools or {}) do
            if NormalizeZoneName(poolName) == normalizedText then
                return true, poolName
            end
        end
    end
    return false
end

function Scoring:SetShowAllZones(enabled, skipRefresh)
    showAllZones = enabled and true or false
    ClearScoreCache()
    PersistSettings()
    if not skipRefresh then
        self:Refresh()
    end
end

function Scoring:IsShowingAllZones()
    return showAllZones
end

function Scoring:SetHideTrophy(enabled, skipRefresh)
    hideTrophy = enabled and true or false
    ClearScoreCache()
    PersistSettings()
    if not skipRefresh then
        self:Refresh()
    end
end

function Scoring:IsHidingTrophy()
    return hideTrophy
end

function Scoring:SetKeepScoreWatchOpen(enabled)
    watchKeepOpen = enabled and true or false
    PersistSettings()
    if not watchKeepOpen and watchFrame:IsShown() and not fishingActive then
        ScheduleWatchHide(0)
    end
end

function Scoring:IsKeepingScoreWatchOpen()
    return watchKeepOpen
end

function Scoring:ShowScoreWatch()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) or (InCombatLockdown and InCombatLockdown()) then
        return false
    end

    watchClosed = false
    watchHiddenForCombat = false
    watchHideToken = watchHideToken + 1
    watchCloseResetToken = watchCloseResetToken + 1
    RequestScoreData()
    RefreshWatchFrame()
    watchFrame:Show()
    if not watchKeepOpen and not fishingActive then
        ScheduleWatchHide(WATCH_HIDE_DELAY)
    end
    return true
end

function Scoring:Refresh()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        scoreFrame:Hide()
        watchFrame:Hide()
        return
    end

    local scoreRows, scoreableTypes, totalScore, opportunities, warbandScore, totalMax, trophies = BuildScoresCached()
    local totalTypes = #scoreRows

    SetModeButtonVisual(zoneButton, not showAllZones)
    SetModeButtonVisual(allButton, showAllZones)
    SetModeButtonVisual(hideTrophyButton, hideTrophy)
    emptyText:SetShown(totalTypes == 0)
    if dataPending > 0 and totalTypes == 0 then
        summaryText:SetText(L["SCORING_LOADING"]:format(dataPending))
        QueueScoreRefresh(1.5)
    else
        local opportunity = opportunities and opportunities[1]
        if opportunity then
            summaryText:SetText(L["SCORING_SUMMARY_OPPORTUNITY"]:format(totalScore, totalMax, trophies, scoreableTypes, warbandScore or "?"))
        else
            summaryText:SetText(L["SCORING_SUMMARY"]:format(totalScore, totalMax, trophies, scoreableTypes, warbandScore or "?"))
        end
    end

    for i = 1, MAX_ROWS do
        local entry = scoreRows[i]
        if entry then
            RefreshRow(rows[i], entry)
            self:DecorateRowTooltip(rows[i], entry)
            rows[i]:Show()
        else
            self:DecorateRowTooltip(rows[i], nil)
            rows[i]:Hide()
        end
    end

    if dataPending > 0 then
        QueueScoreRefresh(2)
    end
end

function Scoring:Toggle()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        AvidAngler:Print(L["MODULE_DISABLED_OPEN"]:format(L["MAIN_TAB_SCORING"]))
        return
    end

    if scoreFrame:IsShown() then
        scoreFrame:Hide()
    else
        self:Refresh()
        scoreFrame:Show()
    end
end

function Scoring:Show()
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        AvidAngler:Print(L["MODULE_DISABLED_OPEN"]:format(L["MAIN_TAB_SCORING"]))
        return
    end

    self:Refresh()
    scoreFrame:Show()
end

function Scoring:Enable()
    moduleEnabled = true
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        scoreFrame:Hide()
        watchFrame:Hide()
        toastFrame:Hide()
    end
end

function Scoring:Disable()
    moduleEnabled = false
    scoreFrame:Hide()
    toastFrame:Hide()
end

zoneButton:SetScript("OnClick", function() Scoring:SetShowAllZones(false) end)
allButton:SetScript("OnClick", function() Scoring:SetShowAllZones(true) end)
hideTrophyButton:SetScript("OnClick", function() Scoring:SetHideTrophy(not hideTrophy) end)

local function RefreshAfterCatch()
    pendingCatchRefresh = false
    if not moduleEnabled or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        return
    end

    RequestScoreData()
    ClearScoreCache()
    local summary = Scoring:GetSummary()
    local improvedRow
    local scoringDB = GetScoringDB()
    local lastRanks = scoringDB and scoringDB.lastRanks or {}
    for i = 1, #summary.rows do
        local row = summary.rows[i]
        local previous = lastRanks[row.itemID]
        if previous == nil then
            lastRanks[row.itemID] = row.rankLevel or 0
        elseif row.rankLevel and row.rankLevel > previous and row.quantity and row.quantity > 0 then
            improvedRow = row
            lastRanks[row.itemID] = row.rankLevel
            break
        end
    end

    if improvedRow then
        local improvedName = GetEntryDisplayName(improvedRow)
        AvidAngler:Print(L["SCORING_IMPROVED"]:format(improvedName, GetRankDisplayName(improvedRow.rankName), improvedRow.quantity))
        ShowRankToast(improvedName, improvedRow.rankName, improvedRow.quantity, GetEntryIcon(improvedRow), improvedRow.itemID)
    end

    if scoreFrame:IsShown() then
        Scoring:Refresh()
    end
    if watchFrame:IsShown() then
        Scoring:RefreshFishingWindow()
    end
end

local function QueueCatchRefresh()
    if pendingCatchRefresh then
        return
    end

    pendingCatchRefresh = true
    C_Timer.After(0.75, RefreshAfterCatch)
end

EventRegistry:RegisterCallback(AvidAngler.CATCH_RECORDED_EVENT, function()
    QueueCatchRefresh()
end)

EventRegistry:RegisterCallback(AvidAngler.CONTENT_SAFETY_CHANGED_EVENT, function()
    local disabled = AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()
    if disabled then
        fishingActive = false
        watchHiddenForCombat = true
        scoreFrame:Hide()
        watchFrame:Hide()
        toastFrame:Hide()
    elseif moduleEnabled then
        watchHiddenForCombat = false
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("CRITERIA_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_TEXT_UPDATE")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_CHANNEL_START", "player")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_INTERRUPTED", "player")
pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_FAILED", "player")
eventFrame:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
        return
    end
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() and event ~= "ADDON_LOADED" and event ~= "PLAYER_REGEN_DISABLED" then
        scoreFrame:Hide()
        watchFrame:Hide()
        toastFrame:Hide()
        return
    end
    if event == "ADDON_LOADED" then
        local _, settings = GetScoringDB()
        showAllZones = settings and settings.showAllZones and true or false
        hideTrophy = settings and settings.hideTrophy and true or false
        watchKeepOpen = settings and settings.keepScoreWatchOpen and true or false
        ClearScoreCache()
        RequestScoreData()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "CRITERIA_UPDATE" or event == "SPELL_TEXT_UPDATE" then
        if event == "SPELL_TEXT_UPDATE" then
            ClearKnownFishCache()
        end
        ClearScoreCache()
        RequestScoreData()
        QueueScoreRefresh(1)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        QueueZoneRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        HideWatchImmediately()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ReopenWatchAfterCombat()
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local spellID = select(2, ...)
        if FISHING_CASTS[spellID] then
            ShowWatchForFishing()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local spellID = select(2, ...)
        if FISHING_CASTS[spellID] then
            HideWatchAfterFishing()
        end
    else
        ClearScoreCache()
        QueueScoreRefresh(0.3)
    end
end)

SLASH_AVIDANGLERSCORE1 = "/aascore"
SlashCmdList["AVIDANGLERSCORE"] = function(msg)
    if AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled() then
        return
    end

    local command = (msg or ""):match("^%s*(.-)%s*$"):lower()
    local showAll = showAllZones
    if command == "all" then
        showAll = true
    elseif command == "zone" then
        showAll = false
    end
    if AvidAngler.UI.MainWindow then
        AvidAngler.UI.MainWindow:ShowScoring(showAll)
    else
        Scoring:SetShowAllZones(showAll)
        Scoring:Show()
    end
end
