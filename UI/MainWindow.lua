-- Avid Angler
-- Main addon window and tab navigation.

local _, AvidAngler = ...

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L
local ExpansionGuideScreen = AvidAngler.UI.ExpansionGuide
local SettingsScreen = AvidAngler.UI.SettingsScreen

local MainWindow = {}
AvidAngler.UI.MainWindow = MainWindow

local PRIMARY_NAV = {
    { key = "tracking", labelKey = "MAIN_TAB_DASHBOARD" },
    { key = "midnight", labelKey = "CATCH_FILTER_EXPANSION_MIDNIGHT", expansion = "midnight", panel = "tracking" },
    { key = "warWithin", labelKey = "CATCH_FILTER_EXPANSION_WAR_WITHIN", expansion = "warWithin", panel = "tracking" },
    { key = "dragonflight", labelKey = "CATCH_FILTER_EXPANSION_DRAGONFLIGHT", expansion = "dragonflight", panel = "tracking" },
    { key = "shadowlands", labelKey = "CATCH_FILTER_EXPANSION_SHADOWLANDS", expansion = "shadowlands", panel = "tracking" },
    { key = "battleForAzeroth", labelKey = "CATCH_FILTER_EXPANSION_BATTLE_FOR_AZEROTH", expansion = "battleForAzeroth", panel = "tracking" },
    { key = "legion", labelKey = "CATCH_FILTER_EXPANSION_LEGION", expansion = "legion", panel = "tracking" },
    { key = "warlords", labelKey = "CATCH_FILTER_EXPANSION_WARLORDS", expansion = "warlords", panel = "tracking" },
    { key = "pandaria", labelKey = "CATCH_FILTER_EXPANSION_PANDARIA", expansion = "pandaria", panel = "tracking" },
    { key = "cataclysm", labelKey = "CATCH_FILTER_EXPANSION_CATACLYSM", expansion = "cataclysm", panel = "tracking" },
    { key = "northrend", labelKey = "CATCH_FILTER_EXPANSION_NORTHREND", expansion = "northrend", panel = "tracking" },
    { key = "outland", labelKey = "CATCH_FILTER_EXPANSION_OUTLAND", expansion = "outland", panel = "tracking" },
    { key = "classic", labelKey = "CATCH_FILTER_EXPANSION_CLASSIC", expansion = "classic", panel = "tracking" },
}

local EXPANSION_NAV_KEYS = {}
for _, tab in ipairs(PRIMARY_NAV) do
    if tab.expansion then
        EXPANSION_NAV_KEYS[tab.key] = true
    end
end

local function GetExpansionDisplayName(expansionKey)
    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    return (catalog and catalog.GetExpansionName and catalog:GetExpansionName(expansionKey)) or expansionKey or ""
end

local UTILITY_NAV = {
    { key = "settings", labelKey = "MAIN_TAB_SETTINGS" },
}

local TRACKING_VIEW_HISTORY = "history"
local TRACKING_VIEW_FISH = "fish"
local TRACKING_VIEW_ZONES = "zones"
local TRACKING_SCOPE_WARBAND = "warband"
local TRACKING_SCOPE_CHARACTER = "character"
local TRACKING_EXPANSION_ALL = "all"
local ExpansionSkill = { fishingSkillLineID = 356, cachedStates = {} }

local frame = CreateFrame("Frame", "AvidAnglerMainFrame", UIParent, "BackdropTemplate")
frame:SetSize(1228, 760)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetBackdrop((Theme:Backdrop("backdrop", "border")))
frame:SetBackdropColor(unpack(Theme.color.backdrop))
frame:SetBackdropBorderColor(unpack(Theme.color.border))
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
if frame.SetMouseClickEnabled then
    frame:SetMouseClickEnabled(true)
end
if frame.SetMouseMotionEnabled then
    frame:SetMouseMotionEnabled(true)
end
frame:Hide()
tinsert(UISpecialFrames, "AvidAnglerMainFrame")

function MainWindow:GetUIScale()
    local value = AvidAngler.DB and AvidAngler.DB.ui and tonumber(AvidAngler.DB.ui.scale) or 1
    if not value or value ~= value then value = 1 end
    return math.max(0.6, math.min(1.3, value))
end

function MainWindow:SetUIScale(value)
    value = tonumber(value)
    if not AvidAngler.DB or not value or value ~= value then return end
    AvidAngler.DB.ui = AvidAngler.DB.ui or {}
    AvidAngler.DB.ui.scale = math.max(0.6, math.min(1.3, value))
    frame:SetScale(self:GetUIScale())
end

frame:HookScript("OnShow", function()
    frame:SetScale(MainWindow:GetUIScale())
end)

local titleBar = CreateFrame("Frame", nil, frame)
titleBar:SetPoint("TOPLEFT")
titleBar:SetPoint("TOPRIGHT")
titleBar:SetHeight(Theme.layout.headerHeight)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

local title = titleBar:CreateFontString(nil, "ARTWORK")
title:SetFontObject(Theme.font.title)
title:SetPoint("LEFT", Theme.layout.padding, 0)
title:SetText(L["CONTROL_PANEL_TITLE"])

local closeButton = Theme:CreateCloseButton(titleBar)
closeButton:SetPoint("RIGHT", -Theme.layout.gutter, 0)
closeButton:SetScript("OnClick", function() frame:Hide() end)

local sidebar = Theme:CreatePanel(frame, "panel", "border")
sidebar:SetPoint("TOPLEFT", Theme.layout.padding, -Theme.layout.headerHeight)
sidebar:SetPoint("BOTTOMLEFT", Theme.layout.padding, Theme.layout.padding)
sidebar:SetWidth(Theme.layout.sidebarWidth)

local sidebarLogo = sidebar:CreateTexture(nil, "ARTWORK")
sidebarLogo:SetSize(96, 96)
sidebarLogo:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 58)
sidebarLogo:SetTexture("Interface\\AddOns\\AvidAngler\\Media\\AvidAngler-logo-soft.png")

local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", Theme.layout.gutter, 0)
content:SetPoint("BOTTOMRIGHT", -Theme.layout.padding, Theme.layout.padding)
content:EnableMouse(true)
if content.SetMouseClickEnabled then
    content:SetMouseClickEnabled(true)
end
if content.SetMouseMotionEnabled then
    content:SetMouseMotionEnabled(true)
end

local navButtons = {}
local panels = {}
local activeTab
local activeNavKey
local selectedExpansionKey
local activeExpansionGuideScreen = "pools"
local refreshElapsed = 0
local zoneNameCache = {}
local itemInfoCache = {}
local QueueRefreshTask
local SetFontStringText
local GetItemInfoCached
local SIDEBAR_ROW_STEP = Theme.layout.rowHeight + 8
local SIDEBAR_GROUP_GAP = 14

local function NewPanel(key)
    local panel = CreateFrame("Frame", nil, content)
    panel:SetAllPoints()
    panel:Hide()
    panels[key] = panel
    return panel
end

local function GetNavLabel(tab)
    return (tab and tab.labelKey and L[tab.labelKey]) or (tab and tab.label) or ""
end

local function NewLabel(parent, text, font, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK")
    label:SetFontObject(font or Theme.font.body)
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function GetZoneName()
    local mapID = C_Map.GetBestMapForUnit("player")
    local catalog = AvidAngler.Data and AvidAngler.Data.MapCatalog
    local displayMapID = catalog and catalog.GetDisplayAreaMapID and catalog:GetDisplayAreaMapID(mapID) or mapID
    if zoneNameCache[displayMapID] then
        return zoneNameCache[displayMapID]
    end
    local info = displayMapID and C_Map.GetMapInfo(displayMapID)
    local name = (info and info.name) or L["CATCH_HISTORY_ZONE_UNKNOWN"]
    zoneNameCache[displayMapID] = name
    return name
end

local function GetRecordZoneName(record)
    local catalog = AvidAngler.Data and AvidAngler.Data.MapCatalog
    local zoneMapID = record and record.zoneMapID
    local displayMapID = catalog and catalog.GetDisplayAreaMapID and catalog:GetDisplayAreaMapID(zoneMapID) or zoneMapID
    if zoneNameCache[displayMapID] then
        return zoneNameCache[displayMapID]
    end
    local info = displayMapID and C_Map.GetMapInfo(displayMapID)
    local name = (info and info.name) or L["CATCH_HISTORY_ZONE_UNKNOWN"]
    zoneNameCache[displayMapID] = name
    return name
end

local function FormatElapsed(timestamp)
    local elapsed = time() - (timestamp or time())
    if elapsed < 60 then
        return elapsed .. "s"
    elseif elapsed < 3600 then
        return math.floor(elapsed / 60) .. "m"
    end
    return math.floor(elapsed / 3600) .. "h"
end

local function FormatRecordClock(timestamp)
    return timestamp and date("%H:%M", timestamp) or L["CATCH_HISTORY_TIME_UNKNOWN"]
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

local function GetCatchTypeLabel(catchType)
    if catchType == "fish" then
        return L["CATCH_HISTORY_TYPE_FISH"]
    elseif catchType == "junk" then
        return L["CATCH_HISTORY_TYPE_JUNK"]
    elseif catchType == "treasure" then
        return L["CATCH_HISTORY_TYPE_TREASURE"]
    end
    return L["CATCH_HISTORY_TYPE_LOOT"]
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

local function SetButtonSelected(button, selected)
    if button.SetSelected then
        button:SetSelected(selected)
        return
    end
    if selected then
        button:SetBackdropBorderColor(unpack(Theme.color.accent))
        button.text:SetFontObject(Theme.font.heading)
    else
        button:SetBackdropBorderColor(unpack(Theme.color.accentDim))
        button.text:SetFontObject(Theme.font.body)
    end
end

local function IsModuleEnabled(key)
    return AvidAngler.IsModuleEnabled and AvidAngler:IsModuleEnabled(key)
end

local function IsRuntimeDisabled()
    return AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()
end

function ExpansionSkill:NormalizeSkillName(name)
    if AvidAngler.IsSecretValue and AvidAngler:IsSecretValue(name) then
        return nil
    end
    if type(name) ~= "string" then
        return nil
    end
    return name:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function ExpansionSkill:SkillNameMatches(candidate, skillNames)
    local normalized = self:NormalizeSkillName(candidate)
    if not normalized then
        return false
    end
    for _, skillName in ipairs(skillNames or {}) do
        if normalized == self:NormalizeSkillName(skillName) then
            return true
        end
    end
    return false
end

function ExpansionSkill:SkillInfoMatches(info, skillNames)
    if type(info) ~= "table" then
        return false
    end
    return self:SkillNameMatches(info.skillLineName, skillNames)
        or self:SkillNameMatches(info.professionName, skillNames)
        or self:SkillNameMatches(info.parentProfessionName, skillNames)
        or self:SkillNameMatches(info.expansionName, skillNames)
        or self:SkillNameMatches(info.name, skillNames)
end

function ExpansionSkill:ProfessionIDMatches(info, professionIDs)
    local professionID = type(info) == "table" and AvidAngler:SafeNumber(info.professionID, nil)
    if not professionID then
        return false
    end
    for _, expectedID in ipairs(professionIDs or {}) do
        if professionID == expectedID then
            return true
        end
    end
    return false
end

function ExpansionSkill:IsSkillInfoLearned(info)
    if AvidAngler:IsSecretValue(info) or type(info) ~= "table" then
        return nil
    end
    for _, key in ipairs({ "learned", "isLearned", "unlocked", "isUnlocked" }) do
        local value = info[key]
        if not AvidAngler:IsSecretValue(value) and type(value) == "boolean" then
            return value
        end
    end
    for _, key in ipairs({ "skillLevel", "currentLevel", "rank", "numSkillUps" }) do
        local level = AvidAngler:SafeNumber(info[key], nil)
        if level and level > 0 then return true end
    end
    -- Zero ranks can be placeholders while profession data is loading.
    return nil
end

function ExpansionSkill:MatchesKnownSkillInfo(info, skillNames, professionIDs)
    return self:IsSkillInfoLearned(info)
        and (self:ProfessionIDMatches(info, professionIDs) or self:SkillInfoMatches(info, skillNames))
end

function ExpansionSkill:StatesEqual(left, right)
    for expansionKey in pairs(EXPANSION_NAV_KEYS) do
        if (left and left[expansionKey]) ~= (right and right[expansionKey]) then
            return false
        end
    end
    return true
end

function ExpansionSkill:CacheChildSkillStates(children, catalog)
    local previous = self.cachedStates
    self:LoadSavedStates()
    local states = {}
    for expansionKey in pairs(EXPANSION_NAV_KEYS) do
        states[expansionKey] = self.cachedStates[expansionKey]
        if previous[expansionKey] == true then states[expansionKey] = true end
    end
    for _, child in ipairs(children or {}) do
        local learned = self:IsSkillInfoLearned(child)
        if learned ~= nil then
            for expansionKey in pairs(EXPANSION_NAV_KEYS) do
                local professionIDs = catalog:GetProfessionIDs(expansionKey)
                if self:ProfessionIDMatches(child, professionIDs) and states[expansionKey] ~= true then
                    states[expansionKey] = learned
                end
            end
        end
    end
    local changed = not self:StatesEqual(previous, states)
    self.cachedStates = states
    if changed and AvidAngler.DataLayer and AvidAngler.DataLayer.SaveCharacterFishingSkillSnapshot then
        AvidAngler.DataLayer:SaveCharacterFishingSkillSnapshot(states)
    end
    return states, changed
end

function ExpansionSkill:LoadSavedStates()
    if not AvidAngler.DataLayer or not AvidAngler.DataLayer.GetCharacterFishingSkillSnapshot then
        return nil
    end

    local snapshot = AvidAngler.DataLayer:GetCharacterFishingSkillSnapshot()
    if type(snapshot) ~= "table" or type(snapshot.expansions) ~= "table" then
        return nil
    end

    local states = {}
    for _, tab in ipairs(PRIMARY_NAV) do
        if tab.expansion and snapshot.expansions[tab.key] == true then
            -- Older snapshots inferred false from missing journal rows.
            states[tab.key] = true
        end
    end
    if next(states) then
        self.cachedStates = states
        return states
    end
end

function ExpansionSkill:RefreshFromJournal()
    if IsRuntimeDisabled() or InCombatLockdown() then return nil end
    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    local tradeSkill = C_TradeSkillUI
    if not catalog or not tradeSkill then return nil end

    local children = {}
    -- Direct ID queries do not depend on the currently open profession journal.
    for expansionKey in pairs(EXPANSION_NAV_KEYS) do
        for _, skillLineID in ipairs(catalog:GetProfessionIDs(expansionKey)) do
            local info = AvidAngler:SafeCall(tradeSkill.GetProfessionInfoBySkillLineID, nil, skillLineID)
            if type(info) == "table" and self:ProfessionIDMatches(info, { skillLineID }) then
                children[#children + 1] = info
            end
        end
    end
    -- This API has no skill-line argument and may describe another profession.
    -- Matching fishing rows can still fill gaps in the direct queries.
    local journal = AvidAngler:SafeCall(tradeSkill.GetChildProfessionInfos, nil)
    if type(journal) == "table" then
        for _, info in ipairs(journal) do children[#children + 1] = info end
    end
    return self:CacheChildSkillStates(children, catalog)
end

function ExpansionSkill:MarkExpansionLearned(expansionKey, source)
    if type(expansionKey) ~= "string" then
        return false
    end

    self:LoadSavedStates()
    if type(self.cachedStates) ~= "table" then
        self.cachedStates = {}
    end
    self.cachedStates[expansionKey] = true
    if AvidAngler.DataLayer and AvidAngler.DataLayer.UpdateCharacterFishingSkillState then
        AvidAngler.DataLayer:UpdateCharacterFishingSkillState(expansionKey, true, source)
    elseif AvidAngler.DataLayer and AvidAngler.DataLayer.SaveCharacterFishingSkillSnapshot then
        AvidAngler.DataLayer:SaveCharacterFishingSkillSnapshot(self.cachedStates)
    end
    return true
end

function ExpansionSkill:UpdateFromSystemMessage(message)
    if IsRuntimeDisabled() then
        return nil
    end
    if AvidAngler.SafeValue then
        message = AvidAngler:SafeValue(message, nil)
    end

    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    local normalizedMessage = self:NormalizeSkillName(message)
    if not catalog or not normalizedMessage then
        return nil
    end

    for expansionKey in pairs(EXPANSION_NAV_KEYS) do
        local skillNames = catalog.GetSkillLineNames and catalog:GetSkillLineNames(expansionKey) or {}
        for _, skillName in ipairs(skillNames) do
            local normalizedSkill = self:NormalizeSkillName(skillName)
            if normalizedSkill and normalizedSkill ~= "fishing" and normalizedMessage:find(normalizedSkill, 1, true) then
                self:MarkExpansionLearned(expansionKey, "systemMessage")
                return expansionKey
            end
        end
    end
end

function ExpansionSkill:CharacterHasFishingSkill(expansionKey)
    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    local skillNames = catalog and catalog.GetSkillLineNames and catalog:GetSkillLineNames(expansionKey) or nil
    local professionIDs = catalog and catalog.GetProfessionIDs and catalog:GetProfessionIDs(expansionKey) or nil
    if (not skillNames or #skillNames == 0) and (not professionIDs or #professionIDs == 0) then
        return nil
    end

    local liveStates = self:RefreshFromJournal()
    if liveStates then
        return liveStates[expansionKey]
    end

    if self.cachedStates[expansionKey] ~= nil then
        return self.cachedStates[expansionKey]
    end

    local savedStates = self:LoadSavedStates()
    if savedStates and savedStates[expansionKey] ~= nil then
        return savedStates[expansionKey]
    end

    return nil
end

function ExpansionSkill:GetPlayerFaction()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Alliance" or faction == "Horde" then
        return faction
    end
    return "Both"
end

local dashboardPanel = NewPanel("dashboard")
local statusPanel = Theme:CreatePanel(dashboardPanel, "panel", "border")
statusPanel:SetPoint("TOPLEFT")
statusPanel:SetPoint("TOPRIGHT")
statusPanel:SetHeight(92)

local statusTitle = NewLabel(statusPanel, L["MAIN_STATUS_READY"], Theme.font.title, "TOPLEFT", statusPanel, "TOPLEFT", 12, -10)
local zoneTitle = NewLabel(statusPanel, L["MAIN_CURRENT_ZONE"], Theme.font.small, "TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -8)
local zoneValue = NewLabel(statusPanel, "", Theme.font.body, "LEFT", zoneTitle, "RIGHT", Theme.layout.gutter, 0)
local totalValue = NewLabel(statusPanel, "", Theme.font.heading, "TOPLEFT", zoneTitle, "BOTTOMLEFT", 0, -8)

local sessionPanel = Theme:CreatePanel(dashboardPanel, "panel", "border")
sessionPanel:SetPoint("TOPLEFT", statusPanel, "BOTTOMLEFT", 0, -Theme.layout.gutter)
sessionPanel:SetPoint("TOPRIGHT", statusPanel, "BOTTOMRIGHT", 0, -Theme.layout.gutter)
sessionPanel:SetHeight(74)

local sessionTitle = NewLabel(sessionPanel, L["MAIN_CURRENT_SESSION"], Theme.font.heading, "TOPLEFT", sessionPanel, "TOPLEFT", 12, -10)
local sessionValue = NewLabel(sessionPanel, "", Theme.font.body, "TOPLEFT", sessionTitle, "BOTTOMLEFT", 0, -8)
local sessionResetButton = Theme:CreateButton(sessionPanel, L["CATCH_HISTORY_RESET_SESSION"])
sessionResetButton:SetPoint("RIGHT", -12, 0)
sessionResetButton:SetWidth(120)

local recentTitle = NewLabel(dashboardPanel, L["MAIN_RECENT_CATCHES"], Theme.font.heading, "TOPLEFT", sessionPanel, "BOTTOMLEFT", 0, -Theme.layout.padding)
local recentRows = {}
for i = 1, 5 do
    local row = dashboardPanel:CreateFontString(nil, "ARTWORK")
    row:SetFontObject(Theme.font.body)
    row:SetPoint("TOPLEFT", recentTitle, "BOTTOMLEFT", 0, -6 - ((i - 1) * 20))
    row:SetPoint("RIGHT", -8, 0)
    row:SetJustifyH("LEFT")
    row:SetText("")
    recentRows[i] = row
end

local trackingPanel = NewPanel("tracking")
local trackingMode = "all"
local trackingView = TRACKING_VIEW_HISTORY
local trackingScope = TRACKING_SCOPE_WARBAND
local trackingExpansion = TRACKING_EXPANSION_ALL
local trackingExpansionDefaulted = false
local trackingDrilldownZoneID = nil
local trackingHideJunk = false
local trackingHideTreasures = false
local trackingOffset = 0
local trackingSettingsLoaded = false
local trackingRefreshStats
local trackingRefreshPage
local trackingRefreshRowIndex = 1
local trackingSummary = NewLabel(trackingPanel, "", Theme.font.title, "TOPLEFT", trackingPanel, "TOPLEFT", 0, -2)
local fishingStatusHeader = CreateFrame("Frame", nil, content)
fishingStatusHeader:SetPoint("TOPLEFT")
fishingStatusHeader:SetPoint("TOPRIGHT")
fishingStatusHeader:SetHeight(24)
fishingStatusHeader:SetFrameLevel(content:GetFrameLevel() + 20)
local fishingSkillText = NewLabel(fishingStatusHeader, "", Theme.font.title, "LEFT", trackingSummary, "RIGHT", 24, 0)
local venomText = NewLabel(fishingStatusHeader, "", Theme.font.title, "LEFT", fishingSkillText, "RIGHT", 32, 0)

local trackingAllButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_FILTER_ALL"])
trackingAllButton:SetPoint("TOPLEFT", trackingSummary, "BOTTOMLEFT", 0, -16)
trackingAllButton:SetWidth(76)
local trackingSessionButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_FILTER_SESSION"])
trackingSessionButton:SetPoint("LEFT", trackingAllButton, "RIGHT", Theme.layout.gutter, 0)
trackingSessionButton:SetWidth(92)
local trackingZoneButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_FILTER_ZONE"])
trackingZoneButton:SetPoint("LEFT", trackingSessionButton, "RIGHT", Theme.layout.gutter, 0)
trackingZoneButton:SetWidth(76)
local trackingScopeButton = Theme:CreateButton(trackingPanel, L["CATCH_SCOPE_WARBAND"])
trackingScopeButton:SetPoint("LEFT", trackingZoneButton, "RIGHT", Theme.layout.gutter, 0)
trackingScopeButton:SetWidth(118)
local trackingExpansionButton = Theme:CreateButton(trackingPanel, "")
trackingExpansionButton:SetPoint("LEFT", trackingScopeButton, "RIGHT", Theme.layout.gutter, 0)
trackingExpansionButton:SetWidth(190)
local trackingExpansionDropdown = Theme:CreatePanel(trackingPanel, "panelRaised", "accent")
trackingExpansionDropdown:SetPoint("TOPLEFT", trackingExpansionButton, "BOTTOMLEFT", 0, -2)
trackingExpansionDropdown:SetWidth(190)
trackingExpansionDropdown:SetFrameLevel(trackingExpansionButton:GetFrameLevel() + 10)
trackingExpansionDropdown:Hide()
local trackingExpansionRows = {}
local trackingResetButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_RESET_SESSION"])
trackingResetButton:SetPoint("TOPRIGHT", trackingPanel, "TOPRIGHT", -4, -34)
trackingResetButton:SetWidth(124)

local trackingHistoryButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_VIEW_HISTORY"])
trackingHistoryButton:SetPoint("TOPLEFT", trackingAllButton, "BOTTOMLEFT", 0, -10)
trackingHistoryButton:SetWidth(92)
local trackingFishButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_VIEW_FISH"])
trackingFishButton:SetPoint("LEFT", trackingHistoryButton, "RIGHT", Theme.layout.gutter, 0)
trackingFishButton:SetWidth(78)
local trackingZonesButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_VIEW_ZONES"])
trackingZonesButton:SetPoint("LEFT", trackingFishButton, "RIGHT", Theme.layout.gutter, 0)
trackingZonesButton:SetWidth(78)
local trackingScoreButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_VIEW_SCORE"])
trackingScoreButton:SetPoint("LEFT", trackingZonesButton, "RIGHT", Theme.layout.gutter, 0)
trackingScoreButton:SetWidth(78)
trackingScoreButton:Hide()
local trackingMidnightFishButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_FISH"])
trackingMidnightFishButton:SetWidth(78)
trackingMidnightFishButton:Hide()
trackingMidnightFishButton.grandLineButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_GRAND_LINE"])
trackingMidnightFishButton.grandLineButton:SetWidth(106)
trackingMidnightFishButton.grandLineButton:Hide()
local trackingPoolsButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_POOLS"])
trackingPoolsButton:SetWidth(78)
trackingPoolsButton:Hide()
local trackingLuresButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_LURES"])
trackingLuresButton:SetWidth(78)
trackingLuresButton:Hide()
local trackingAccessoriesButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_ACCESSORIES"])
trackingAccessoriesButton:SetWidth(116)
trackingAccessoriesButton:Hide()
local trackingCollectiblesButton = Theme:CreateButton(trackingPanel, L["MIDNIGHT_TAB_COLLECTIBLES"])
trackingCollectiblesButton:SetWidth(116)
trackingCollectiblesButton:Hide()
trackingCollectiblesButton.achievementsButton = Theme:CreateButton(trackingPanel, L["ACH_BUTTON"])
trackingCollectiblesButton.achievementsButton:SetWidth(124)
trackingCollectiblesButton.achievementsButton:Hide()
local trackingHideJunkButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_HIDE_JUNK"])
trackingHideJunkButton:SetPoint("LEFT", trackingZonesButton, "RIGHT", Theme.layout.gutter, 0)
trackingHideJunkButton:SetWidth(100)
local trackingHideTreasuresButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_HIDE_TREASURES"])
trackingHideTreasuresButton:SetPoint("LEFT", trackingHideJunkButton, "RIGHT", Theme.layout.gutter, 0)
trackingHideTreasuresButton:SetWidth(118)

local trackingCards = {}
local function CreateTrackingCard(index, label)
    local card = Theme:CreatePanel(trackingPanel, "panel", "border")
    card:SetSize(192, 70)
    if index == 1 then
        card:SetPoint("TOPLEFT", trackingHistoryButton, "BOTTOMLEFT", 0, -14)
    else
        card:SetPoint("LEFT", trackingCards[index - 1], "RIGHT", Theme.layout.gutter, 0)
    end

    local labelText = card:CreateFontString(nil, "ARTWORK")
    labelText:SetFontObject(Theme.font.small)
    labelText:SetPoint("TOPLEFT", 10, -8)
    labelText:SetPoint("RIGHT", -10, 0)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    local valueText = card:CreateFontString(nil, "ARTWORK")
    valueText:SetFontObject(Theme.font.title)
    valueText:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -5)
    valueText:SetPoint("RIGHT", -10, 0)
    valueText:SetJustifyH("LEFT")

    local detailText = card:CreateFontString(nil, "ARTWORK")
    detailText:SetFontObject(Theme.font.muted)
    detailText:SetPoint("TOPLEFT", valueText, "BOTTOMLEFT", 0, -4)
    detailText:SetPoint("RIGHT", -10, 0)
    detailText:SetJustifyH("LEFT")

    card.labelText = labelText
    card.valueText = valueText
    card.detailText = detailText
    trackingCards[index] = card
    return card
end
CreateTrackingCard(1, L["CATCH_CARD_FISH"])
CreateTrackingCard(2, L["CATCH_CARD_CASTS"])
CreateTrackingCard(3, L["CATCH_CARD_JUNK"])
CreateTrackingCard(4, L["CATCH_CARD_TREASURE"])
CreateTrackingCard(5, L["CATCH_CARD_RATE"])

local trackingPageText = NewLabel(trackingPanel, "", Theme.font.muted, "TOPLEFT", trackingCards[1], "BOTTOMLEFT", 0, -12)
trackingPageText:SetPoint("RIGHT", -4, 0)

local trackingTopFishText = NewLabel(trackingPanel, "", Theme.font.small, "TOPLEFT", trackingPageText, "BOTTOMLEFT", 0, -10)
trackingTopFishText:SetPoint("RIGHT", -4, 0)
local trackingTopZoneText = NewLabel(trackingPanel, "", Theme.font.small, "TOPLEFT", trackingTopFishText, "BOTTOMLEFT", 0, -4)
trackingTopZoneText:SetPoint("RIGHT", -4, 0)
local trackingSourceText = NewLabel(trackingPanel, "", Theme.font.small, "TOPLEFT", trackingTopZoneText, "BOTTOMLEFT", 0, -4)
trackingSourceText:SetPoint("RIGHT", -4, 0)

local TRACKING_CARD_PAGE_SIZE = 25
local trackingRows = {}
for i = 1, TRACKING_CARD_PAGE_SIZE do
    local row = Theme:CreatePanel(trackingPanel, "panel", "border")
    row:SetHeight(24)
    row:SetPoint("TOPLEFT", trackingSourceText, "BOTTOMLEFT", 0, -10 - ((i - 1) * 27))
    row:SetPoint("RIGHT", -4, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.body)
    nameText:SetPoint("LEFT", icon, "RIGHT", Theme.layout.gutter, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -278, 0)
    nameText:SetJustifyH("LEFT")

    local zoneText = row:CreateFontString(nil, "ARTWORK")
    zoneText:SetFontObject(Theme.font.small)
    zoneText:SetPoint("LEFT", nameText, "RIGHT", Theme.layout.gutter, 0)
    zoneText:SetWidth(176)
    zoneText:SetJustifyH("LEFT")

    local detailText = row:CreateFontString(nil, "ARTWORK")
    detailText:SetFontObject(Theme.font.muted)
    detailText:SetPoint("RIGHT", -6, 0)
    detailText:SetWidth(84)
    detailText:SetJustifyH("RIGHT")

    row.icon = icon
    row.nameText = nameText
    row.zoneText = zoneText
    row.detailText = detailText
    row:Hide()
    trackingRows[i] = row
end

local function LayoutTrackingRow(row, index, cardMode)
    row:ClearAllPoints()
    row.icon:ClearAllPoints()
    row.nameText:ClearAllPoints()
    row.zoneText:ClearAllPoints()
    row.detailText:ClearAllPoints()

    if cardMode then
        local cardWidth = 192
        local cardHeight = 70
        local columns = 5
        local column = (index - 1) % columns
        local gridRow = math.floor((index - 1) / columns)
        row:SetSize(cardWidth, cardHeight)
        row:SetPoint("TOPLEFT", trackingSourceText, "BOTTOMLEFT", column * (cardWidth + Theme.layout.gutter), -12 - (gridRow * (cardHeight + Theme.layout.gutter)))

        row.icon:SetSize(22, 22)
        row.icon:SetPoint("TOPLEFT", 10, -10)

        row.nameText:SetFontObject(Theme.font.heading)
        row.nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", Theme.layout.gutter, 0)
        row.nameText:SetWidth(cardWidth - 50)
        row.nameText:SetJustifyH("LEFT")

        row.zoneText:SetFontObject(Theme.font.body)
        row.zoneText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -36)
        row.zoneText:SetWidth(cardWidth - 20)
        row.zoneText:SetJustifyH("LEFT")

        row.detailText:SetFontObject(Theme.font.muted)
        row.detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
        row.detailText:SetWidth(cardWidth - 20)
        row.detailText:SetJustifyH("LEFT")
    else
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", trackingSourceText, "BOTTOMLEFT", 0, -10 - ((index - 1) * 27))
        row:SetPoint("RIGHT", -4, 0)

        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)

        row.nameText:SetFontObject(Theme.font.body)
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", Theme.layout.gutter, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -278, 0)
        row.nameText:SetJustifyH("LEFT")

        row.zoneText:SetFontObject(Theme.font.small)
        row.zoneText:SetPoint("LEFT", row.nameText, "RIGHT", Theme.layout.gutter, 0)
        row.zoneText:SetWidth(176)
        row.zoneText:SetJustifyH("LEFT")

        row.detailText:SetFontObject(Theme.font.muted)
        row.detailText:SetPoint("RIGHT", -6, 0)
        row.detailText:SetWidth(84)
        row.detailText:SetJustifyH("RIGHT")
    end
end

local trackingPrevButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_PREV"])
trackingPrevButton:SetPoint("BOTTOMLEFT", 0, 0)
trackingPrevButton:SetWidth(76)
local trackingNextButton = Theme:CreateButton(trackingPanel, L["CATCH_HISTORY_NEXT"])
trackingNextButton:SetPoint("LEFT", trackingPrevButton, "RIGHT", Theme.layout.gutter, 0)
trackingNextButton:SetWidth(76)

local skillPrompt = { panel = NewPanel("skillPrompt"), rows = {} }
skillPrompt.card = Theme:CreatePanel(skillPrompt.panel, "panel", "border")
skillPrompt.card:SetPoint("TOPLEFT", 0, -18)
skillPrompt.card:SetWidth(620)
skillPrompt.card:SetHeight(140)

skillPrompt.title = NewLabel(skillPrompt.card, "", Theme.font.title, "TOPLEFT", skillPrompt.card, "TOPLEFT", 16, -16)
skillPrompt.title:SetPoint("RIGHT", -16, 0)
skillPrompt.body = NewLabel(skillPrompt.card, "", Theme.font.body, "TOPLEFT", skillPrompt.title, "BOTTOMLEFT", 0, -10)
skillPrompt.body:SetPoint("RIGHT", -16, 0)
skillPrompt.hint = NewLabel(skillPrompt.card, "", Theme.font.muted, "TOPLEFT", skillPrompt.body, "BOTTOMLEFT", 0, -8)
skillPrompt.hint:SetPoint("RIGHT", -16, 0)
skillPrompt.achievementsButton = Theme:CreateButton(skillPrompt.panel, L["ACH_BUTTON"])
skillPrompt.achievementsButton:SetPoint("TOPLEFT", skillPrompt.card, "TOPRIGHT", 16, 0)
skillPrompt.achievementsButton:SetWidth(124)
skillPrompt.achievementsButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "achievements")
end)

skillPrompt.trainerTitle = NewLabel(skillPrompt.panel, L["EXPANSION_SKILL_TRAINERS"], Theme.font.heading, "TOPLEFT", skillPrompt.card, "BOTTOMLEFT", 0, -22)
skillPrompt.noTrainersText = NewLabel(skillPrompt.panel, "", Theme.font.muted, "TOPLEFT", skillPrompt.trainerTitle, "BOTTOMLEFT", 0, -10)

for i = 1, 10 do
    local row = Theme:CreatePanel(skillPrompt.panel, "panel", "border")
    row:SetHeight(42)
    row:SetPoint("TOPLEFT", skillPrompt.trainerTitle, "BOTTOMLEFT", 0, -10 - ((i - 1) * 48))
    row:SetPoint("RIGHT", -4, 0)

    row.nameText = NewLabel(row, "", Theme.font.heading, "TOPLEFT", row, "TOPLEFT", 12, -6)
    row.detailText = NewLabel(row, "", Theme.font.muted, "TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -4)
    row.detailText:SetPoint("RIGHT", -142, 0)

    row.waypointButton = Theme:CreateButton(row, L["EXPANSION_SKILL_WAYPOINT"])
    row.waypointButton:SetPoint("RIGHT", -12, 0)
    row.waypointButton:SetWidth(118)
    row.waypointButton:SetScript("OnClick", function()
        if row.trainer then
            MainWindow:SetTrainerWaypoint(row.trainer)
        end
    end)

    skillPrompt.rows[i] = row
end

local scoringPanel = NewPanel("scoring")
local scoreState = { offset = 0 }
local scoreUI = {
    rows = {},
    opportunityRows = {},
    cardWidth = 192,
    cardHeight = 70,
    cardColumns = 5,
}
scoreUI.summary = NewLabel(scoringPanel, "", Theme.font.title, "TOPLEFT", scoringPanel, "TOPLEFT", 0, -2)
scoreUI.overviewButton = Theme:CreateButton(scoringPanel, L["CATCH_HISTORY_VIEW_OVERVIEW"])
scoreUI.overviewButton:SetPoint("TOPLEFT", scoreUI.summary, "BOTTOMLEFT", 0, -16)
scoreUI.overviewButton:SetWidth(116)
scoreUI.scoreButton = Theme:CreateButton(scoringPanel, L["CATCH_HISTORY_VIEW_SCORE"])
scoreUI.scoreButton:SetPoint("LEFT", scoreUI.overviewButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.scoreButton:SetWidth(78)
scoreUI.fishButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_FISH"])
scoreUI.fishButton:SetPoint("LEFT", scoreUI.scoreButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.fishButton:SetWidth(78)
scoreUI.poolsButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_POOLS"])
scoreUI.poolsButton:SetPoint("LEFT", scoreUI.fishButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.poolsButton:SetWidth(78)
scoreUI.luresButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_LURES"])
scoreUI.luresButton:SetPoint("LEFT", scoreUI.poolsButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.luresButton:SetWidth(78)
scoreUI.accessoriesButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_ACCESSORIES"])
scoreUI.accessoriesButton:SetPoint("LEFT", scoreUI.luresButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.accessoriesButton:SetWidth(116)
scoreUI.collectiblesButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_COLLECTIBLES"])
scoreUI.collectiblesButton:SetPoint("LEFT", scoreUI.accessoriesButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.collectiblesButton:SetWidth(116)
scoreUI.grandLineButton = Theme:CreateButton(scoringPanel, L["MIDNIGHT_TAB_GRAND_LINE"])
scoreUI.grandLineButton:SetPoint("LEFT", scoreUI.collectiblesButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.grandLineButton:SetWidth(106)
scoreUI.achievementsButton = Theme:CreateButton(scoringPanel, L["ACH_BUTTON"])
scoreUI.achievementsButton:SetPoint("LEFT", scoreUI.grandLineButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.achievementsButton:SetWidth(124)

scoreUI.zoneButton = Theme:CreateButton(scoringPanel, L["SCORING_SHOW_ZONE"])
scoreUI.zoneButton:SetPoint("TOPLEFT", scoreUI.overviewButton, "BOTTOMLEFT", 0, -16)
scoreUI.zoneButton:SetWidth(116)
scoreUI.allButton = Theme:CreateButton(scoringPanel, L["SCORING_SHOW_ALL"])
scoreUI.allButton:SetPoint("LEFT", scoreUI.zoneButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.allButton:SetWidth(100)
scoreUI.hideTrophyButton = Theme:CreateButton(scoringPanel, L["SCORING_HIDE_TROPHY"])
scoreUI.hideTrophyButton:SetPoint("LEFT", scoreUI.allButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.hideTrophyButton:SetWidth(128)
scoreUI.pageText = NewLabel(scoringPanel, "", Theme.font.muted, "LEFT", scoreUI.hideTrophyButton, "RIGHT", 18, 0)
scoreUI.pageText:SetWidth(116)
scoreUI.prevButton = Theme:CreateButton(scoringPanel, L["CATCH_HISTORY_PREV"])
scoreUI.prevButton:SetPoint("LEFT", scoreUI.pageText, "RIGHT", Theme.layout.gutter, 0)
scoreUI.prevButton:SetWidth(76)
scoreUI.nextButton = Theme:CreateButton(scoringPanel, L["CATCH_HISTORY_NEXT"])
scoreUI.nextButton:SetPoint("LEFT", scoreUI.prevButton, "RIGHT", Theme.layout.gutter, 0)
scoreUI.nextButton:SetWidth(76)

for i = 1, 25 do
    local row = Theme:CreatePanel(scoringPanel, "panel", "border")
    local column = (i - 1) % scoreUI.cardColumns
    local gridRow = math.floor((i - 1) / scoreUI.cardColumns)
    row:SetSize(scoreUI.cardWidth, scoreUI.cardHeight)
    row:SetPoint("TOPLEFT", scoreUI.zoneButton, "BOTTOMLEFT", column * (scoreUI.cardWidth + Theme.layout.gutter), -14 - (gridRow * (scoreUI.cardHeight + Theme.layout.gutter)))

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 10, -10)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.heading)
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", Theme.layout.gutter, 0)
    nameText:SetWidth(scoreUI.cardWidth - 50)
    nameText:SetJustifyH("LEFT")

    local rankText = row:CreateFontString(nil, "ARTWORK")
    rankText:SetFontObject(Theme.font.body)
    rankText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -36)
    rankText:SetWidth(scoreUI.cardWidth - 20)
    rankText:SetJustifyH("LEFT")

    local scoreText = row:CreateFontString(nil, "ARTWORK")
    scoreText:SetFontObject(Theme.font.muted)
    scoreText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
    scoreText:SetWidth(scoreUI.cardWidth - 20)
    scoreText:SetJustifyH("LEFT")

    row.icon = icon
    row.nameText = nameText
    row.rankText = rankText
    row.scoreText = scoreText
    row:Hide()
    scoreUI.rows[i] = row
end

scoreUI.watchPanel = Theme:CreatePanel(scoringPanel, "panel", "border")
scoreUI.watchPanel:SetPoint("BOTTOMLEFT", 0, 0)
scoreUI.watchPanel:SetWidth(452)
scoreUI.watchPanel:SetHeight(48)

scoreUI.watchSettingsTitle = NewLabel(scoreUI.watchPanel, L["SCORING_WATCH_SETTINGS_TITLE"], Theme.font.heading, "LEFT", scoreUI.watchPanel, "LEFT", 12, 0)
scoreUI.watchKeepOpenCheck = Theme:CreateCheckbox(scoreUI.watchPanel, L["SCORING_WATCH_KEEP_OPEN"])
scoreUI.watchKeepOpenCheck:SetPoint("LEFT", scoreUI.watchSettingsTitle, "RIGHT", 28, 0)
scoreUI.watchShowButton = Theme:CreateButton(scoreUI.watchPanel, L["SCORING_WATCH_SHOW"])
scoreUI.watchShowButton:SetPoint("LEFT", scoreUI.watchKeepOpenCheck.text, "RIGHT", 28, 0)
scoreUI.watchShowButton:SetWidth(104)

scoreUI.achievementPanel = Theme:CreatePanel(scoringPanel, "panel", "border")
scoreUI.achievementPanel:SetPoint("BOTTOMLEFT", scoreUI.watchPanel, "BOTTOMRIGHT", Theme.layout.gutter, 0)
scoreUI.achievementPanel:SetPoint("BOTTOMRIGHT", -4, 0)
scoreUI.achievementPanel:SetHeight(104)

scoreUI.achievementIcon = scoreUI.achievementPanel:CreateTexture(nil, "ARTWORK")
scoreUI.achievementIcon:SetSize(40, 40)
scoreUI.achievementIcon:SetPoint("TOPLEFT", 12, -12)
scoreUI.achievementIcon:SetTexture("Interface\\Icons\\Achievement_Quests_Completed_08")

scoreUI.achievementTitle = scoreUI.achievementPanel:CreateFontString(nil, "ARTWORK")
scoreUI.achievementTitle:SetFontObject(Theme.font.heading)
scoreUI.achievementTitle:SetPoint("TOPLEFT", scoreUI.achievementIcon, "TOPRIGHT", Theme.layout.gutter, 1)
scoreUI.achievementTitle:SetPoint("RIGHT", -110, 0)
scoreUI.achievementTitle:SetJustifyH("LEFT")

scoreUI.achievementDescription = scoreUI.achievementPanel:CreateFontString(nil, "ARTWORK")
scoreUI.achievementDescription:SetFontObject(Theme.font.small)
scoreUI.achievementDescription:SetPoint("TOPLEFT", scoreUI.achievementTitle, "BOTTOMLEFT", 0, -5)
scoreUI.achievementDescription:SetPoint("RIGHT", -12, 0)
scoreUI.achievementDescription:SetJustifyH("LEFT")
scoreUI.achievementDescription:SetHeight(32)

scoreUI.achievementBar = Theme:CreatePanel(scoreUI.achievementPanel, "backdrop", "border")
scoreUI.achievementBar:SetPoint("BOTTOMLEFT", scoreUI.achievementIcon, "BOTTOMRIGHT", Theme.layout.gutter, -27)
scoreUI.achievementBar:SetPoint("BOTTOMRIGHT", -12, -27)
scoreUI.achievementBar:SetHeight(16)

scoreUI.achievementFill = scoreUI.achievementBar:CreateTexture(nil, "ARTWORK")
scoreUI.achievementFill:SetColorTexture(unpack(Theme.color.accent))
scoreUI.achievementFill:SetPoint("TOPLEFT", 1, -1)
scoreUI.achievementFill:SetPoint("BOTTOMLEFT", 1, 1)
scoreUI.achievementFill:SetWidth(1)

scoreUI.achievementProgress = scoreUI.achievementBar:CreateFontString(nil, "OVERLAY")
scoreUI.achievementProgress:SetFontObject(Theme.font.small)
scoreUI.achievementProgress:SetPoint("TOPRIGHT", scoreUI.achievementPanel, "TOPRIGHT", -12, -8)
scoreUI.achievementProgress:SetJustifyH("RIGHT")

scoreUI.opportunityTitle = NewLabel(scoringPanel, L["SCORING_OPPORTUNITIES_TITLE"], Theme.font.heading, "BOTTOMLEFT", scoreUI.watchPanel, "TOPLEFT", 0, 104)
for i = 1, 5 do
    local row = CreateFrame("Frame", nil, scoringPanel)
    row:SetHeight(16)
    row:SetPoint("TOPLEFT", scoreUI.opportunityTitle, "BOTTOMLEFT", 0, -6 - ((i - 1) * 18))
    row:SetWidth(452)

    local nameText = row:CreateFontString(nil, "ARTWORK")
    nameText:SetFontObject(Theme.font.small)
    nameText:SetPoint("LEFT")
    nameText:SetPoint("RIGHT", row, "RIGHT", -210, 0)
    nameText:SetJustifyH("LEFT")

    local scoreText = row:CreateFontString(nil, "ARTWORK")
    scoreText:SetFontObject(Theme.font.small)
    scoreText:SetPoint("RIGHT", row, "RIGHT", -118, 0)
    scoreText:SetWidth(84)
    scoreText:SetJustifyH("RIGHT")

    local percentText = row:CreateFontString(nil, "ARTWORK")
    percentText:SetFontObject(Theme.font.small)
    percentText:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    percentText:SetWidth(52)
    percentText:SetJustifyH("RIGHT")

    local leftText = row:CreateFontString(nil, "ARTWORK")
    leftText:SetFontObject(Theme.font.muted)
    leftText:SetPoint("RIGHT")
    leftText:SetWidth(78)
    leftText:SetJustifyH("RIGHT")

    row.nameText = nameText
    row.scoreText = scoreText
    row.percentText = percentText
    row.leftText = leftText
    row:Hide()
    scoreUI.opportunityRows[i] = row
end

local expansionGuidePanel
if ExpansionGuideScreen and ExpansionGuideScreen.Create then
    expansionGuidePanel = ExpansionGuideScreen:Create(content, {
        overview = function(_, expansionKey)
            MainWindow:SelectExpansionOverview(expansionKey or "midnight")
        end,
        score = function()
            MainWindow:SelectMidnightScore()
        end,
        fish = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "fish")
        end,
        grandline = function()
            MainWindow:SelectExpansionInfo("midnight", "grandline")
        end,
        pools = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "pools")
        end,
        lures = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "lures")
        end,
        accessories = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "accessories")
        end,
        collectibles = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "collectibles")
        end,
        achievements = function(_, expansionKey)
            MainWindow:SelectExpansionInfo(expansionKey or "midnight", "achievements")
        end,
    })
    panels.expansionGuide = expansionGuidePanel
end

if SettingsScreen and SettingsScreen.Initialize then
    local settingsPanels = SettingsScreen:Initialize(content, MainWindow)
    panels.casting = settingsPanels.casting
    panels.settings = settingsPanels.settings
end

local function SetTopFishText(label, itemID, count)
    if not itemID then
        label.topFishKey = nil
        local text = L["CATCH_HISTORY_TOP_FISH"]:format("-", count or 0)
        if label:GetText() ~= text then
            label:SetText(text)
        end
        return
    end

    label.topFishKey = itemID
    label.topFishCount = count or 0
    local info = GetItemInfoCached(itemID, function(itemInfo)
        if label.topFishKey == itemID then
            SetFontStringText(label, L["CATCH_HISTORY_TOP_FISH"]:format(itemInfo.name or ("item:" .. itemID), label.topFishCount or 0))
        end
    end)
    local text = L["CATCH_HISTORY_TOP_FISH"]:format((info and info.name) or ("item:" .. itemID), count or 0)
    if label:GetText() ~= text then
        label:SetText(text)
    end
end

local function SetTrackingCard(card, value, detail)
    value = value or "-"
    detail = detail or ""
    if card.valueText:GetText() ~= value then
        card.valueText:SetText(value)
    end
    if card.detailText:GetText() ~= detail then
        card.detailText:SetText(detail)
    end
end

local function SetItemNameColor(label, quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.GetRGB then
        label:SetTextColor(color:GetRGB())
    elseif color and color.r and color.g and color.b then
        label:SetTextColor(color.r, color.g, color.b)
    else
        label:SetTextColor(unpack(Theme.color.textPrimary))
    end
end

SetFontStringText = function(label, text)
    text = text or ""
    if label:GetText() ~= text then
        label:SetText(text)
    end
end

local function SetTexture(texture, value)
    value = value or "Interface\\Icons\\INV_Misc_QuestionMark"
    if texture.currentTexture ~= value then
        texture:SetTexture(value)
        texture.currentTexture = value
    end
end

local function ReadItemInfo(itemID)
    local info = itemInfoCache[itemID]
    if not info then
        info = {}
        itemInfoCache[itemID] = info
    end
    if info.ready then
        return info
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, name, _, quality, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, itemID)
        if ok and name then
            info.name = name
            info.quality = quality
            info.icon = icon
            info.ready = true
            return info
        end
    end
    return info
end

GetItemInfoCached = function(itemID, callback)
    if not itemID then
        return nil
    end

    local info = ReadItemInfo(itemID)
    if info.ready then
        return info
    end

    if callback then
        info.callbacks = info.callbacks or {}
        info.callbacks[#info.callbacks + 1] = callback
    end

    if info.pending or not Item or type(Item.CreateFromItemID) ~= "function" then
        return info
    end

    info.pending = true
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        info.name = item:GetItemName() or info.name
        info.icon = item:GetItemIcon() or info.icon
        if C_Item and type(C_Item.GetItemInfo) == "function" then
            local ok, _, _, quality = pcall(C_Item.GetItemInfo, itemID)
            if ok then
                info.quality = quality
            end
        end
        info.ready = true
        info.pending = false
        local callbacks = info.callbacks or {}
        info.callbacks = nil
        for i = 1, #callbacks do
            callbacks[i](info)
        end
    end)
    return info
end

local function RefreshTrackingCards(stats)
    stats = stats or {}
    local totalFish = stats.fish or 0
    local totalQuantity = stats.totalQuantity or totalFish
    SetTrackingCard(trackingCards[1], L["CATCH_CARD_FISH_VALUE"]:format(totalFish), L["CATCH_CARD_FISH_DETAIL"]:format(stats.types or 0, stats.zones or 0))
    SetTrackingCard(trackingCards[2], L["CATCH_CARD_CASTS_VALUE"]:format(stats.casts or 0), L["CATCH_CARD_CASTS_DETAIL"]:format(stats.castsPerHour or 0))
    SetTrackingCard(trackingCards[3], L["CATCH_CARD_JUNK_VALUE"]:format(stats.junk or 0), L["CATCH_CARD_JUNK_DETAIL"]:format(totalQuantity > 0 and ((stats.junk or 0) / totalQuantity * 100) or 0))
    SetTrackingCard(trackingCards[4], L["CATCH_CARD_TREASURE_VALUE"]:format(stats.treasure or 0), L["CATCH_CARD_TREASURE_DETAIL"]:format(totalQuantity > 0 and ((stats.treasure or 0) / totalQuantity * 100) or 0))
    SetTrackingCard(trackingCards[5], L["CATCH_CARD_RATE_VALUE"]:format(stats.catchRate or 0), L["CATCH_CARD_RATE_DETAIL"]:format(stats.fishPerHour or 0))
end

local function RefreshTrackingCardStatsOnly()
    local tracking = AvidAngler.Modules.Tracking
    if activeTab ~= "tracking" or not tracking or not IsModuleEnabled("tracking") or not tracking.GetStats then
        return
    end

    trackingRefreshStats = tracking:GetStats(trackingMode, trackingScope, trackingExpansion, trackingDrilldownZoneID)
    RefreshTrackingCards(trackingRefreshStats)
end

local function GetTrackingSettings()
    if not AvidAngler.DB or not AvidAngler.DB.settings then
        return nil
    end
    AvidAngler.DB.settings.mainWindow = AvidAngler.DB.settings.mainWindow or {}
    AvidAngler.DB.settings.mainWindow.tracking = AvidAngler.DB.settings.mainWindow.tracking or {}
    return AvidAngler.DB.settings.mainWindow.tracking
end

local function IsTrackingMode(value)
    return value == "all" or value == "session" or value == "zone"
end

local function IsTrackingView(value)
    return value == TRACKING_VIEW_HISTORY or value == TRACKING_VIEW_FISH or value == TRACKING_VIEW_ZONES
end

local function IsTrackingScope(value)
    return value == TRACKING_SCOPE_WARBAND or value == TRACKING_SCOPE_CHARACTER
end

local function LoadTrackingSettings()
    if trackingSettingsLoaded then
        return
    end
    local settings = GetTrackingSettings()
    if not settings then
        return
    end

    trackingSettingsLoaded = true
    if IsTrackingMode(settings.mode) then
        trackingMode = settings.mode
    end
    if IsTrackingView(settings.view) then
        trackingView = settings.view
    end
    if IsTrackingScope(settings.scope) then
        trackingScope = settings.scope
    end
    if type(settings.expansion) == "string" and settings.expansion ~= "" then
        trackingExpansion = settings.expansion
        trackingExpansionDefaulted = true
    end
    trackingHideJunk = settings.hideJunk and true or false
    trackingHideTreasures = settings.hideTreasures and true or false
    trackingDrilldownZoneID = nil
    trackingOffset = 0
end

local function PersistTrackingSettings()
    local settings = GetTrackingSettings()
    if not settings then
        return
    end
    settings.mode = trackingMode
    settings.view = trackingView
    settings.scope = trackingScope
    settings.expansion = trackingExpansion
    settings.hideJunk = trackingHideJunk and true or false
    settings.hideTreasures = trackingHideTreasures and true or false
end

local function RefreshTrackingExpansionFilter(tracking)
    local options = tracking.GetAvailableExpansions and tracking:GetAvailableExpansions(trackingScope) or {}
    local currentFound = trackingExpansion == TRACKING_EXPANSION_ALL
    for _, option in ipairs(options) do
        if option.key == trackingExpansion then
            currentFound = true
            break
        end
    end
    if not currentFound then
        if activeNavKey ~= trackingExpansion then
            trackingExpansion = TRACKING_EXPANSION_ALL
            PersistTrackingSettings()
        end
    end
    local label = tracking.GetExpansionLabel and tracking:GetExpansionLabel(trackingExpansion) or L["CATCH_FILTER_EXPANSION_ALL"]
    trackingExpansionButton.text:SetText(L["CATCH_FILTER_EXPANSION"]:format(label) .. " v")
end

local function DefaultTrackingExpansionToCurrent()
    if trackingExpansionDefaulted then
        return
    end
    trackingExpansionDefaulted = true
    local tracking = AvidAngler.Modules.Tracking
    local currentExpansion = tracking and tracking.GetCurrentExpansionKey and tracking:GetCurrentExpansionKey()
    if not currentExpansion or currentExpansion == "other" then
        return
    end
    trackingExpansion = currentExpansion
    PersistTrackingSettings()
end

local function ResetDashboardExpansionDefault()
    LoadTrackingSettings()
    trackingExpansionDefaulted = true
    trackingExpansion = TRACKING_EXPANSION_ALL
    trackingDrilldownZoneID = nil
    trackingOffset = 0
    PersistTrackingSettings()
end

local function HideTrackingExpansionDropdown()
    trackingExpansionDropdown:Hide()
end
frame:HookScript("OnHide", HideTrackingExpansionDropdown)

local function RefreshTrackingExpansionDropdown()
    local tracking = AvidAngler.Modules.Tracking
    local options = tracking and tracking.GetAvailableExpansions and tracking:GetAvailableExpansions(trackingScope) or {}
    if #options == 0 then
        return
    end

    local rowHeight = 24
    trackingExpansionDropdown:SetHeight((#options * rowHeight) + 8)

    for i = 1, #options do
        local option = options[i]
        local row = trackingExpansionRows[i]
        if not row then
            row = CreateFrame("Button", nil, trackingExpansionDropdown, "BackdropTemplate")
            row:SetHeight(rowHeight)
            row:SetPoint("LEFT", 4, 0)
            row:SetPoint("RIGHT", -4, 0)
            row:SetBackdrop((Theme:Backdrop("panelRaised", "border")))
            row:SetBackdropColor(0, 0, 0, 0)
            row:SetBackdropBorderColor(0, 0, 0, 0)

            local text = row:CreateFontString(nil, "ARTWORK")
            text:SetFontObject(Theme.font.body)
            text:SetPoint("LEFT", 8, 0)
            text:SetPoint("RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            row.text = text

            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(unpack(Theme.color.panel))
                self:SetBackdropBorderColor(unpack(Theme.color.accentDim))
            end)
            row:SetScript("OnLeave", function(self)
                if self.expansionKey == trackingExpansion then
                    self:SetBackdropColor(unpack(Theme.color.panel))
                    self:SetBackdropBorderColor(unpack(Theme.color.accent))
                else
                    self:SetBackdropColor(0, 0, 0, 0)
                    self:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end)
            row:SetScript("OnClick", function(self)
                trackingExpansion = self.expansionKey or TRACKING_EXPANSION_ALL
                trackingDrilldownZoneID = nil
                trackingOffset = 0
                PersistTrackingSettings()
                HideTrackingExpansionDropdown()
                MainWindow:Refresh()
            end)
            trackingExpansionRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -4 - ((i - 1) * rowHeight))
        row:SetPoint("RIGHT", -4, 0)
        row.expansionKey = option.key
        row.text:SetText(tracking:GetExpansionLabel(option.key))
        if option.key == trackingExpansion then
            row:SetBackdropColor(unpack(Theme.color.panel))
            row:SetBackdropBorderColor(unpack(Theme.color.accent))
            row.text:SetFontObject(Theme.font.heading)
        else
            row:SetBackdropColor(0, 0, 0, 0)
            row:SetBackdropBorderColor(0, 0, 0, 0)
            row.text:SetFontObject(Theme.font.body)
        end
        row:Show()
    end

    for i = #options + 1, #trackingExpansionRows do
        trackingExpansionRows[i]:Hide()
    end
end

local function ToggleTrackingExpansionDropdown()
    if trackingExpansionDropdown:IsShown() then
        HideTrackingExpansionDropdown()
        return
    end
    RefreshTrackingExpansionDropdown()
    trackingExpansionDropdown:Show()
end

local function SetAnalyticsTooltip(row, entry)
    row.tooltipEntry = entry
    if row.tooltipScriptsSet then
        return
    end

    row.tooltipScriptsSet = true
    row:SetScript("OnEnter", function(self)
        local currentEntry = self.tooltipEntry
        if not currentEntry then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if currentEntry.kind == "zone" then
            GameTooltip:SetText(GetRecordZoneName({ zoneMapID = currentEntry.zoneMapID }))
            GameTooltip:AddLine(L["CATCH_ANALYTICS_TOOLTIP_TYPES"]:format(currentEntry.typeCount or 0), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(L["CATCH_ANALYTICS_TOOLTIP_TOP_FISH"]:format(currentEntry.topFishName or (currentEntry.topFishID and ("item:" .. currentEntry.topFishID) or "-"), currentEntry.topFishCount or 0), 0.8, 0.8, 0.8)
        else
            GameTooltip:SetText(self.nameText:GetText() or L["CATCH_HISTORY_TITLE"])
            GameTooltip:AddLine(L["CATCH_ANALYTICS_FISH_META"]:format(currentEntry.zoneCount or 0), 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(L["CATCH_ANALYTICS_TOOLTIP_CATCHES"]:format(currentEntry.catches or 0), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["CATCH_HISTORY_SOURCE_MIX"]:format(currentEntry.sourceBreakdown or L["CATCH_HISTORY_SOURCE_UNKNOWN"]), 0.8, 0.8, 0.8)
        if currentEntry.kind == "zone" then
            GameTooltip:AddLine(L["CATCH_ANALYTICS_TOOLTIP_DRILLDOWN"], unpack(Theme.color.accent))
        end
        if currentEntry.recent and #currentEntry.recent > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["CATCH_HISTORY_RECENT_TOOLTIP"], unpack(Theme.color.textPrimary))
            for i = 1, math.min(#currentEntry.recent, 6) do
                local recent = currentEntry.recent[i]
                local quantityLabel = (recent.quantity and recent.quantity > 1) and ("x" .. recent.quantity) or "x1"
                if recent.catchSource == "pool" or recent.catchSource == "open-water" or recent.catchSource == "either" then
                    GameTooltip:AddLine(L["CATCH_HISTORY_RECENT_LINE_SOURCE"]:format(quantityLabel, FormatElapsed(recent.timestamp), GetRecordZoneName(recent), GetSourceLabel(recent.catchSource)), 0.8, 0.8, 0.8)
                else
                    GameTooltip:AddLine(L["CATCH_HISTORY_RECENT_LINE"]:format(quantityLabel, FormatElapsed(recent.timestamp), GetRecordZoneName(recent)), 0.8, 0.8, 0.8)
                end
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button)
        local currentEntry = self.tooltipEntry
        if button == "LeftButton" and currentEntry and currentEntry.kind == "zone" then
            trackingDrilldownZoneID = currentEntry.zoneMapID
            trackingView = TRACKING_VIEW_HISTORY
            trackingOffset = 0
            PersistTrackingSettings()
            HideTrackingExpansionDropdown()
            MainWindow:Refresh()
        end
    end)
end

local function RefreshAnalyticsRow(row, entry, view)
    local renderKey = table.concat({
        view or "",
        entry.kind or "",
        entry.itemID or entry.zoneMapID or "",
        entry.quantity or 0,
        entry.percent or 0,
        entry.catches or 0,
        entry.typeCount or 0,
        entry.zoneCount or 0,
        entry.catchType or "",
        entry.lastTime or "",
    }, "|")
    row.tooltipEntry = entry
    if row.renderKey == renderKey then
        row:EnableMouse(true)
        SetAnalyticsTooltip(row, entry)
        row:Show()
        return
    end

    row.renderKey = renderKey
    row.record = nil
    row.recordIndex = nil
    row.analyticsKey = entry.kind == "fish" and entry.itemID or entry.zoneMapID
    SetTexture(row.icon, view == TRACKING_VIEW_ZONES and "Interface\\Icons\\INV_Misc_Map02" or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.nameText:SetTextColor(unpack(Theme.color.textPrimary))

    if view == TRACKING_VIEW_ZONES then
        SetFontStringText(row.nameText, GetRecordZoneName({ zoneMapID = entry.zoneMapID }))
        SetFontStringText(row.zoneText, L["CATCH_ANALYTICS_ZONE_DETAIL"]:format(entry.quantity or 0, entry.percent or 0))
        SetFontStringText(row.detailText, L["CATCH_ANALYTICS_ZONE_META"]:format(entry.typeCount or 0))
        if entry.topFishID then
            local itemID = entry.topFishID
            local key = row.analyticsKey
            local info = GetItemInfoCached(itemID, function(itemInfo)
                if row.analyticsKey == key then
                    entry.topFishName = itemInfo.name or ("item:" .. itemID)
                end
            end)
            entry.topFishName = (info and info.name) or entry.topFishName
        end
    else
        local itemID = entry.itemID
        SetFontStringText(row.nameText, itemID and ("item:" .. itemID) or "?")
        if view == TRACKING_VIEW_HISTORY then
            SetFontStringText(row.zoneText, L["CATCH_HISTORY_GROUP_DETAIL_TYPED"]:format(entry.quantity or 0, GetCatchTypeLabel(entry.catchType), entry.catches or 0))
            SetFontStringText(row.detailText, L["CATCH_HISTORY_GROUP_LATEST"]:format(entry.lastTime or L["CATCH_HISTORY_TIME_UNKNOWN"]))
        else
            SetFontStringText(row.zoneText, L["CATCH_ANALYTICS_FISH_DETAIL"]:format(entry.quantity or 0, entry.percent or 0))
            SetFontStringText(row.detailText, L["CATCH_ANALYTICS_FISH_META"]:format(entry.zoneCount or 0))
        end
        if itemID then
            local key = row.analyticsKey
            local info = GetItemInfoCached(itemID, function(itemInfo)
                if row.analyticsKey ~= key then
                    return
                end
                SetTexture(row.icon, itemInfo.icon)
                SetFontStringText(row.nameText, itemInfo.name or ("item:" .. itemID))
                SetItemNameColor(row.nameText, itemInfo.quality)
            end)
            if info then
                SetTexture(row.icon, info.icon)
                SetFontStringText(row.nameText, info.name or ("item:" .. itemID))
                SetItemNameColor(row.nameText, info.quality)
            end
        end
    end

    row:EnableMouse(true)
    SetAnalyticsTooltip(row, entry)
    row:Show()
end

local function ClearTrackingRows()
    for i = 1, #trackingRows do
        local row = trackingRows[i]
        row.record = nil
        row.analyticsKey = nil
        row.renderKey = nil
        row.tooltipEntry = nil
        row:EnableMouse(false)
        row:Hide()
    end
end

local function RefreshEmbeddedTracking(step)
    local tracking = AvidAngler.Modules.Tracking
    if activeTab ~= "tracking" then
        return
    end

    if not tracking or not IsModuleEnabled("tracking") then
        trackingCollectiblesButton.achievementsButton:SetShown(selectedExpansionKey ~= nil)
        trackingCollectiblesButton.achievementsButton:ClearAllPoints()
        trackingCollectiblesButton.achievementsButton:SetPoint("TOPRIGHT", trackingCollectiblesButton:GetParent(), "TOPRIGHT", 0, -2)
        trackingSummary:SetText(L["MODULE_DISABLED_VIEW"]:format(L["MAIN_TAB_DASHBOARD"]))
        trackingPageText:SetText("")
        trackingTopFishText:SetText("")
        trackingTopZoneText:SetText("")
        trackingSourceText:SetText("")
        RefreshTrackingCards(nil)
        trackingPrevButton:SetEnabled(false)
        trackingNextButton:SetEnabled(false)
        ClearTrackingRows()
        trackingRefreshStats = nil
        trackingRefreshPage = nil
        return
    end

    if step == "rows" then
        local page = trackingRefreshPage
        if not page then
            return
        end

        local firstRow = trackingRefreshRowIndex or 1
        local lastRow = math.min(firstRow + 9, #trackingRows)
        for i = firstRow, lastRow do
            local row = trackingRows[i]
            local entry = page.entries[i]
            LayoutTrackingRow(row, i, true)
            if entry then
                RefreshAnalyticsRow(row, entry, trackingView)
            else
                row.record = nil
                row.analyticsKey = nil
                row.renderKey = nil
                row.tooltipEntry = nil
                row:EnableMouse(false)
                row:Hide()
            end
        end
        trackingRefreshRowIndex = lastRow + 1
        if trackingRefreshRowIndex <= #trackingRows then
            QueueRefreshTask("trackingRows")
        end
        return
    end

    if step == "page" then
        local stats = trackingRefreshStats
        local page
        if trackingView == TRACKING_VIEW_HISTORY then
            page = tracking.GetGroupedHistoryPage and tracking:GetGroupedHistoryPage(trackingMode, trackingOffset, #trackingRows, trackingScope, trackingExpansion, trackingDrilldownZoneID, trackingHideJunk, trackingHideTreasures) or tracking:GetHistoryPage(trackingMode, trackingOffset, #trackingRows, trackingScope, trackingExpansion, trackingDrilldownZoneID, trackingHideJunk, trackingHideTreasures)
            if trackingDrilldownZoneID then
                trackingSummary:SetText(L["CATCH_HISTORY_ZONE_DRILLDOWN_SUMMARY"]:format(GetRecordZoneName({ zoneMapID = trackingDrilldownZoneID }), page.totalCatches or page.total, page.totalQuantity))
            else
                trackingSummary:SetText(L["CATCH_HISTORY_SUMMARY"]:format(page.totalCatches or page.total, page.totalQuantity))
            end
        else
            page = tracking:GetAnalyticsPage(trackingMode, trackingView, trackingOffset, #trackingRows, trackingScope, trackingExpansion, trackingDrilldownZoneID, trackingHideJunk, trackingHideTreasures)
            if trackingView == TRACKING_VIEW_ZONES then
                trackingSummary:SetText(L["CATCH_ANALYTICS_SUMMARY_ZONES"]:format(page.total, page.totalQuantity))
            else
                trackingSummary:SetText(L["CATCH_ANALYTICS_SUMMARY_FISH"]:format(page.total, page.totalQuantity))
            end
        end
        trackingOffset = page.offset
        trackingRefreshPage = page

        if page.total == 0 then
            trackingPageText:SetText(trackingView == TRACKING_VIEW_HISTORY and L["CATCH_HISTORY_EMPTY"] or L["CATCH_ANALYTICS_EMPTY"])
            SetTopFishText(trackingTopFishText, nil, 0)
            trackingTopZoneText:SetText(L["CATCH_HISTORY_TOP_ZONE"]:format("-", 0))
            trackingSourceText:SetText(L["CATCH_HISTORY_SOURCE_MIX"]:format(L["CATCH_HISTORY_SOURCE_UNKNOWN"]))
        else
            trackingPageText:SetText(L["CATCH_HISTORY_PAGE"]:format(page.offset + 1, page.offset + #page.entries, page.total))
            if stats then
                SetTopFishText(trackingTopFishText, stats.topFishID, stats.topFishCount or 0)
                trackingTopZoneText:SetText(L["CATCH_HISTORY_TOP_ZONE"]:format(stats.topZoneID and GetRecordZoneName({ zoneMapID = stats.topZoneID }) or "-", stats.topZoneCount or 0))
                trackingSourceText:SetText(L["CATCH_HISTORY_SOURCE_MIX"]:format(stats.sourceBreakdown or FormatSourceBreakdown(stats.sourceCounts)))
            end
        end

        trackingPrevButton:SetEnabled(page.offset > 0)
        trackingNextButton:SetEnabled(page.offset + page.pageSize < page.total)
        trackingRefreshRowIndex = 1
        QueueRefreshTask("trackingRows")
        return
    end

    if step == "stats" then
        trackingRefreshStats = tracking.GetStats and tracking:GetStats(trackingMode, trackingScope, trackingExpansion, trackingDrilldownZoneID)
        RefreshTrackingCards(trackingRefreshStats)
        QueueRefreshTask("trackingPage")
        return
    end

    if step == "options" then
        RefreshTrackingExpansionFilter(tracking)
        QueueRefreshTask("trackingStats")
        return
    end

    LoadTrackingSettings()
    DefaultTrackingExpansionToCurrent()
    trackingRefreshStats = nil
    trackingRefreshPage = nil
    trackingRefreshRowIndex = 1

    local isExpansionOverview = activeTab == "tracking" and selectedExpansionKey and activeNavKey == selectedExpansionKey
    local isMidnightOverview = isExpansionOverview and selectedExpansionKey == "midnight"
    local guideScreen = AvidAngler.UI and AvidAngler.UI.ExpansionGuide
    local showExpansionLures = isExpansionOverview and isMidnightOverview
    if isExpansionOverview and not isMidnightOverview and guideScreen and guideScreen.HasVisibleRows then
        showExpansionLures = guideScreen:HasVisibleRows("lures", selectedExpansionKey)
    end
    if isExpansionOverview then
        trackingView = TRACKING_VIEW_HISTORY
        trackingMode = "all"
        trackingExpansion = selectedExpansionKey
        trackingDrilldownZoneID = nil
        trackingOffset = 0
    end

    trackingAllButton:SetShown(not isExpansionOverview)
    trackingSessionButton:SetShown(not isExpansionOverview)
    trackingZoneButton:SetShown(not isExpansionOverview)
    trackingScopeButton:SetShown(not isExpansionOverview)
    trackingExpansionButton:SetShown(not isExpansionOverview)
    trackingResetButton:SetShown(not isExpansionOverview)
    trackingFishButton:SetShown(not isExpansionOverview)
    trackingZonesButton:SetShown(not isExpansionOverview)
    trackingScoreButton:SetShown(isMidnightOverview)
    trackingMidnightFishButton:SetShown(isExpansionOverview)
    trackingMidnightFishButton.grandLineButton:SetShown(isMidnightOverview)
    trackingPoolsButton:SetShown(isExpansionOverview)
    trackingLuresButton:SetShown(showExpansionLures)
    trackingAccessoriesButton:SetShown(isExpansionOverview)
    trackingCollectiblesButton:SetShown(isExpansionOverview)
    trackingCollectiblesButton.achievementsButton:SetShown(isExpansionOverview)
    trackingCollectiblesButton.achievementsButton:ClearAllPoints()
    trackingCollectiblesButton.achievementsButton:SetPoint("LEFT", isMidnightOverview and trackingMidnightFishButton.grandLineButton or trackingCollectiblesButton, "RIGHT", Theme.layout.gutter, 0)
    trackingHideJunkButton:SetShown(not isExpansionOverview)
    trackingHideTreasuresButton:SetShown(not isExpansionOverview)
    if isExpansionOverview then
        HideTrackingExpansionDropdown()
    end

    trackingHistoryButton:ClearAllPoints()
    if isExpansionOverview then
        trackingHistoryButton:SetPoint("TOPLEFT", trackingSummary, "BOTTOMLEFT", 0, -16)
        trackingHistoryButton.text:SetText(L["CATCH_HISTORY_VIEW_OVERVIEW"])
    else
        trackingHistoryButton:SetPoint("TOPLEFT", trackingAllButton, "BOTTOMLEFT", 0, -10)
        trackingHistoryButton.text:SetText(L["CATCH_HISTORY_VIEW_HISTORY"])
    end

    SetButtonSelected(trackingAllButton, trackingMode == "all")
    SetButtonSelected(trackingSessionButton, trackingMode == "session")
    SetButtonSelected(trackingZoneButton, trackingMode == "zone")
    trackingScopeButton.text:SetText(trackingScope == TRACKING_SCOPE_CHARACTER and L["CATCH_SCOPE_CHARACTER"] or L["CATCH_SCOPE_WARBAND"])
    trackingExpansionButton.text:SetText(L["CATCH_FILTER_EXPANSION"]:format(tracking.GetExpansionLabel and tracking:GetExpansionLabel(trackingExpansion) or L["CATCH_FILTER_EXPANSION_ALL"]) .. " v")
    SetButtonSelected(trackingScopeButton, true)
    SetButtonSelected(trackingExpansionButton, true)
    SetButtonSelected(trackingHistoryButton, trackingView == TRACKING_VIEW_HISTORY or isExpansionOverview)
    SetButtonSelected(trackingFishButton, trackingView == TRACKING_VIEW_FISH)
    SetButtonSelected(trackingZonesButton, trackingView == TRACKING_VIEW_ZONES)
    trackingScoreButton:ClearAllPoints()
    trackingScoreButton:SetPoint("LEFT", isExpansionOverview and trackingHistoryButton or trackingZonesButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingScoreButton, false)
    trackingMidnightFishButton:ClearAllPoints()
    trackingMidnightFishButton:SetPoint("LEFT", isMidnightOverview and trackingScoreButton or trackingHistoryButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingMidnightFishButton, false)
    trackingPoolsButton:ClearAllPoints()
    trackingPoolsButton:SetPoint("LEFT", trackingMidnightFishButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingPoolsButton, false)
    trackingLuresButton:ClearAllPoints()
    trackingLuresButton:SetPoint("LEFT", trackingPoolsButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingLuresButton, false)
    trackingAccessoriesButton:ClearAllPoints()
    trackingAccessoriesButton:SetPoint("LEFT", showExpansionLures and trackingLuresButton or trackingPoolsButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingAccessoriesButton, false)
    trackingCollectiblesButton:ClearAllPoints()
    trackingCollectiblesButton:SetPoint("LEFT", trackingAccessoriesButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingCollectiblesButton, false)
    trackingMidnightFishButton.grandLineButton:ClearAllPoints()
    trackingMidnightFishButton.grandLineButton:SetPoint("LEFT", trackingCollectiblesButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingMidnightFishButton.grandLineButton, false)
    trackingHideJunkButton:ClearAllPoints()
    trackingHideJunkButton:SetPoint("LEFT", trackingZonesButton, "RIGHT", Theme.layout.gutter, 0)
    SetButtonSelected(trackingHideJunkButton, trackingHideJunk)
    SetButtonSelected(trackingHideTreasuresButton, trackingHideTreasures)
    trackingPageText:SetText("")
    trackingPrevButton:SetEnabled(false)
    trackingNextButton:SetEnabled(false)
    ClearTrackingRows()
    QueueRefreshTask("trackingOptions")
end

local function ClampPageOffset(offset, total, pageSize)
    if total <= pageSize then
        return 0
    end
    local lastOffset = math.floor((total - 1) / pageSize) * pageSize
    return math.max(0, math.min(offset or 0, lastOffset))
end

local function RefreshScoreAchievement(scoring, summary)
    local achievement = scoring.GetAchievementSummary and scoring:GetAchievementSummary() or nil
    local target = achievement and achievement.target or 2500
    local score = tonumber(summary and summary.warbandScore) or tonumber(summary and summary.points) or 0
    local percent = target > 0 and math.min(score / target, 1) or 0
    local barWidth = scoreUI.achievementBar:GetWidth() or 0
    if barWidth < 2 then
        barWidth = 360
    else
        barWidth = barWidth - 2
    end

    scoreUI.achievementTitle:SetText((achievement and achievement.name) or L["SCORING_ACHIEVEMENT_TITLE"])
    scoreUI.achievementDescription:SetText((achievement and achievement.description) or L["SCORING_ACHIEVEMENT_DESC"])
    scoreUI.achievementProgress:SetText(L["SCORING_ACHIEVEMENT_PROGRESS"]:format(score, target))
    scoreUI.achievementFill:SetWidth(math.max(barWidth * percent, 1))
    if achievement and achievement.icon then
        scoreUI.achievementIcon:SetTexture(achievement.icon)
    end
    scoreUI.achievementPanel:Show()
end

local function RefreshEmbeddedScoring()
    local scoring = AvidAngler.Modules.Scoring
    SetButtonSelected(scoreUI.overviewButton, false)
    SetButtonSelected(scoreUI.scoreButton, true)
    SetButtonSelected(scoreUI.fishButton, false)
    SetButtonSelected(scoreUI.grandLineButton, false)
    SetButtonSelected(scoreUI.poolsButton, false)
    SetButtonSelected(scoreUI.luresButton, false)
    SetButtonSelected(scoreUI.accessoriesButton, false)
    SetButtonSelected(scoreUI.collectiblesButton, false)
    if not scoring or not IsModuleEnabled("scoring") then
        scoreUI.summary:SetText(L["MODULE_DISABLED_VIEW"]:format(L["MAIN_TAB_SCORING"]))
        SetButtonSelected(scoreUI.zoneButton, false)
        SetButtonSelected(scoreUI.allButton, false)
        SetButtonSelected(scoreUI.hideTrophyButton, false)
        scoreUI.pageText:SetText("")
        scoreUI.prevButton:SetEnabled(false)
        scoreUI.nextButton:SetEnabled(false)
        for i = 1, #scoreUI.rows do
            scoreUI.rows[i]:Hide()
        end
        scoreUI.opportunityTitle:SetText("")
        for i = 1, #scoreUI.opportunityRows do
            scoreUI.opportunityRows[i]:Hide()
        end
        scoreUI.watchKeepOpenCheck:SetChecked(false)
        scoreUI.watchKeepOpenCheck:SetEnabled(false)
        scoreUI.watchShowButton:SetEnabled(false)
        scoreUI.watchPanel:Hide()
        scoreUI.achievementPanel:Hide()
        return
    end

    if scoreState.showAll == nil and scoring.IsShowingAllZones then
        scoreState.showAll = scoring:IsShowingAllZones()
    elseif scoring.IsShowingAllZones and scoring:IsShowingAllZones() ~= scoreState.showAll then
        scoring:SetShowAllZones(scoreState.showAll, true)
    end
    local summary = scoring:GetSummary()
    local totalRows = summary.rows and #summary.rows or 0
    local pageSize = #scoreUI.rows
    scoreState.offset = ClampPageOffset(scoreState.offset, totalRows, pageSize)
    if summary.pending and summary.pending > 0 and summary.types == 0 then
        scoreUI.summary:SetText(L["SCORING_LOADING"]:format(summary.pending))
    else
        local opportunity = summary.opportunities and summary.opportunities[1]
        if opportunity then
            scoreUI.summary:SetText(L["SCORING_SUMMARY_OPPORTUNITY"]:format(summary.points, summary.maxPoints or 0, summary.trophies or 0, summary.scoreableTypes or summary.types, summary.warbandScore or "?"))
        else
            scoreUI.summary:SetText(L["SCORING_SUMMARY"]:format(summary.points, summary.maxPoints or 0, summary.trophies or 0, summary.scoreableTypes or summary.types, summary.warbandScore or "?"))
        end
    end
    SetButtonSelected(scoreUI.zoneButton, not scoreState.showAll)
    SetButtonSelected(scoreUI.allButton, scoreState.showAll)
    SetButtonSelected(scoreUI.hideTrophyButton, scoring:IsHidingTrophy())
    scoreUI.watchKeepOpenCheck:SetEnabled(true)
    scoreUI.watchKeepOpenCheck:SetChecked(scoring.IsKeepingScoreWatchOpen and scoring:IsKeepingScoreWatchOpen())
    scoreUI.watchShowButton:SetEnabled(scoring.ShowScoreWatch ~= nil)
    scoreUI.watchPanel:Show()
    RefreshScoreAchievement(scoring, summary)
    if totalRows > 0 then
        scoreUI.pageText:SetText(L["CATCH_HISTORY_PAGE"]:format(scoreState.offset + 1, scoreState.offset + math.min(pageSize, totalRows - scoreState.offset), totalRows))
    else
        scoreUI.pageText:SetText("")
    end
    scoreUI.prevButton:SetEnabled(scoreState.offset > 0)
    scoreUI.nextButton:SetEnabled(scoreState.offset + pageSize < totalRows)

    for i = 1, #scoreUI.rows do
        local row = scoreUI.rows[i]
        local entry = summary.rows and summary.rows[scoreState.offset + i]
        if entry then
            row.itemID = entry.itemID
            row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.nameText:SetText(scoring.FormatFishLabel and scoring:FormatFishLabel(entry) or (entry.name or ("spell:" .. entry.itemID)))
            row.rankText:SetText(scoring.FormatRankLabel and scoring:FormatRankLabel(entry) or (entry.rankName or ""))
            row.scoreText:SetText(L["SCORING_CARD_SCORE"]:format(entry.score or 0))
            if scoring.DecorateRowTooltip then
                scoring:DecorateRowTooltip(row, entry)
            end
            row:Show()
        else
            if scoring.DecorateRowTooltip then
                scoring:DecorateRowTooltip(row, nil)
            end
            row:Hide()
        end
    end

    if summary.opportunities and #summary.opportunities > 0 then
        scoreUI.opportunityTitle:SetText(L["SCORING_OPPORTUNITIES_TITLE"])
    else
        scoreUI.opportunityTitle:SetText("")
    end
    for i = 1, #scoreUI.opportunityRows do
        local row = scoreUI.opportunityRows[i]
        local opportunity = summary.opportunities and summary.opportunities[i]
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

local refreshTasks = {}
local refreshTaskSet = {}
local pendingCatchDataRefresh = false
local pendingCastDataRefresh = false

QueueRefreshTask = function(task)
    if refreshTaskSet[task] then
        return
    end
    refreshTaskSet[task] = true
    refreshTasks[#refreshTasks + 1] = task
end

local function QueueFishingDataRefresh(kind)
    local isCatch = kind == "catch"
    if isCatch then
        if pendingCatchDataRefresh then
            return
        end
        pendingCatchDataRefresh = true
    else
        if pendingCastDataRefresh then
            return
        end
        pendingCastDataRefresh = true
    end

    C_Timer.After(isCatch and 0.9 or 2.5, function()
        if isCatch then
            pendingCatchDataRefresh = false
        else
            pendingCastDataRefresh = false
        end

        if IsRuntimeDisabled() or not frame:IsShown() then
            return
        end

        if activeTab == "tracking" then
            QueueRefreshTask(isCatch and "trackingStats" or "trackingCardStats")
        elseif isCatch and activeTab == "scoring" then
            QueueRefreshTask("scoring")
        end
    end)
end

local function RefreshLegacyDashboardSummary()
    local tracking = AvidAngler.Modules.Tracking
    zoneValue:SetText(GetZoneName())

    if tracking and IsModuleEnabled("tracking") then
        local summary = tracking:GetSummary()
        totalValue:SetText(L["MAIN_TOTALS"]:format(summary.allCatches, summary.allFish, summary.allTypes))
        sessionValue:SetText(L["MAIN_SESSION_TOTALS"]:format(summary.sessionCatches, summary.sessionFish, summary.sessionTypes, summary.sessionElapsed))

        for i = 1, #recentRows do
            local record = summary.recent[i]
            if record and record.itemID then
                local row = recentRows[i]
                local itemID = record.itemID
                row:SetText("item:" .. itemID)
                local item = Item:CreateFromItemID(itemID)
                item:ContinueOnItemLoad(function()
                    row:SetText(item:GetItemName() or ("item:" .. itemID))
                end)
            else
                recentRows[i]:SetText("")
            end
        end
    elseif tracking then
        totalValue:SetText(L["MODULE_DISABLED_VIEW"]:format(L["MAIN_TAB_TRACKING"]))
        sessionValue:SetText("")
        for i = 1, #recentRows do
            recentRows[i]:SetText("")
        end
    end
end

function MainWindow:SetTrainerWaypoint(trainer)
    if type(trainer) ~= "table" or not trainer.mapID or not trainer.x or not trainer.y then
        if AvidAngler.Print then
            AvidAngler:Print(L["EXPANSION_SKILL_WAYPOINT_UNAVAILABLE"]:format(trainer and trainer.name or L["CATCH_HISTORY_SOURCE_UNKNOWN"]))
        end
        return
    end

    local title = trainer.name or L["EXPANSION_SKILL_TRAINERS"]
    local x = trainer.x / 100
    local y = trainer.y / 100

    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok = pcall(TomTom.AddWaypoint, TomTom, trainer.mapID, x, y, { title = title, persistent = false, minimap = true, world = true })
        if not ok then
            ok = pcall(TomTom.AddWaypoint, trainer.mapID, x, y, { title = title, persistent = false, minimap = true, world = true })
        end
        if ok then
            if AvidAngler.Print then
                AvidAngler:Print(L["EXPANSION_SKILL_WAYPOINT_SET"]:format(title))
            end
            return
        end
    end

    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local point = UiMapPoint.CreateFromCoordinates(trainer.mapID, x, y)
        if point then
            C_Map.SetUserWaypoint(point)
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
            end
            if AvidAngler.Print then
                AvidAngler:Print(L["EXPANSION_SKILL_WAYPOINT_SET"]:format(title))
            end
            return
        end
    end

    if AvidAngler.Print then
        AvidAngler:Print(L["EXPANSION_SKILL_WAYPOINT_UNAVAILABLE"]:format(title))
    end
end

function MainWindow:RefreshFishingStatus()
    local status = AvidAngler.Modules.FishingStatus
    if not status then return end
    local anchor = activeTab == "tracking" and trackingSummary
        or activeTab == "scoring" and scoreUI.summary
        or activeTab == "expansionGuide" and ExpansionGuideScreen and ExpansionGuideScreen.summary
    if not IsModuleEnabled("tracking") or not anchor then
        fishingSkillText:Hide()
        venomText:Hide()
        return
    end
    fishingSkillText:ClearAllPoints()
    fishingSkillText:SetPoint("LEFT", anchor, "RIGHT", 24, 0)
    local expansionKey = selectedExpansionKey or (trackingExpansion ~= "all" and trackingExpansion or nil)
    fishingSkillText:SetShown(expansionKey ~= nil)
    if expansionKey then
        local skill, saved = status:GetSkill(expansionKey)
        local value = "â€”"
        if skill then
            value = string.format("%d / %d", skill.rank, skill.maximum)
            if skill.bonus and skill.bonus > 0 then value = value .. string.format(" (+%d)", skill.bonus) end
            if saved then value = L["FISHING_STATUS_SAVED"]:format(value) end
        end
        fishingSkillText:SetText(L["FISHING_STATUS_SKILL"]:format(value))
    end
    venomText:ClearAllPoints()
    if expansionKey then
        venomText:SetPoint("LEFT", fishingSkillText, "RIGHT", 32, 0)
    else
        venomText:SetPoint("LEFT", trackingSummary, "RIGHT", 24, 0)
    end
    local venom, equipped = status:GetVenom(selectedExpansionKey)
    venomText:SetShown(equipped == true)
    if equipped then venomText:SetText(L["FISHING_STATUS_VENOM"]:format(venom ~= nil and tostring(venom) or "â€”")) end
end

function MainWindow:RefreshSelectedFishingSkill()
    if IsRuntimeDisabled() or InCombatLockdown() or not selectedExpansionKey then return end
    ExpansionSkill.selectedState = ExpansionSkill:CharacterHasFishingSkill(selectedExpansionKey)
    if activeTab == "skillPrompt" then
        if ExpansionSkill.selectedState == true then
            self:SelectTab(selectedExpansionKey)
        else
            self:RefreshExpansionSkillPrompt()
        end
    end
end

function MainWindow:RefreshExpansionSkillPrompt()
    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    local expansionKey = selectedExpansionKey
    local expansionName = catalog and catalog.GetExpansionName and catalog:GetExpansionName(expansionKey) or expansionKey or ""
    local skillNames = catalog and catalog.GetSkillLineNames and catalog:GetSkillLineNames(expansionKey) or {}
    local skillName = skillNames[1] or (expansionName .. " " .. L["EXPANSION_SKILL_FISHING"])
    local trainers = catalog and catalog.GetTrainers and catalog:GetTrainers(expansionKey, ExpansionSkill:GetPlayerFaction()) or {}

    if ExpansionSkill.selectedState == false then
        skillPrompt.title:SetText(L["EXPANSION_SKILL_NOT_LEARNED_TITLE"]:format(skillName))
        skillPrompt.body:SetText(L["EXPANSION_SKILL_NOT_LEARNED_BODY"]:format(skillName))
        skillPrompt.hint:SetText(L["EXPANSION_SKILL_LEARN_PROMPT"]:format(expansionName))
    else
        skillPrompt.title:SetText(L["EXPANSION_SKILL_UNKNOWN_TITLE"]:format(skillName))
        skillPrompt.body:SetText(L["EXPANSION_SKILL_UNKNOWN_BODY"])
        skillPrompt.hint:SetText(L["EXPANSION_SKILL_UNKNOWN_PROMPT"]:format(skillName))
    end
    skillPrompt.noTrainersText:SetText(#trainers == 0 and L["EXPANSION_SKILL_NO_TRAINERS"] or "")

    for i = 1, #skillPrompt.rows do
        local row = skillPrompt.rows[i]
        local trainer = trainers[i]
        if trainer then
            local location = trainer.location and trainer.location ~= "" and (trainer.zone .. " - " .. trainer.location) or trainer.zone
            local canWaypoint = trainer.mapID and trainer.x and trainer.y
            row.trainer = trainer
            row.nameText:SetText(trainer.name or L["EXPANSION_SKILL_TRAINERS"])
            row.detailText:SetText(location or "")
            row.waypointButton.text:SetText(canWaypoint and L["EXPANSION_SKILL_WAYPOINT"] or L["EXPANSION_SKILL_WAYPOINT_NONE"])
            row.waypointButton:SetEnabled(canWaypoint)
            row.waypointButton:SetAlpha(canWaypoint and 1 or 0.55)
            row:Show()
        else
            row.trainer = nil
            row:Hide()
        end
    end
end

local function RefreshVisibleTab()
    if activeTab == "tracking" then
        RefreshEmbeddedTracking()
    elseif activeTab == "scoring" then
        RefreshEmbeddedScoring()
    elseif activeTab == "expansionGuide" then
        if ExpansionGuideScreen and ExpansionGuideScreen.Refresh then
            ExpansionGuideScreen:Refresh(activeExpansionGuideScreen, GetExpansionDisplayName(selectedExpansionKey or "midnight"), selectedExpansionKey or "midnight")
        end
    elseif activeTab == "skillPrompt" then
        MainWindow:RefreshExpansionSkillPrompt()
    elseif activeTab == "casting" then
        if SettingsScreen then
            SettingsScreen:RefreshCasting()
        end
    elseif activeTab == "settings" then
        if SettingsScreen then
            SettingsScreen:RefreshModules()
        end
    end
end

local function ProcessRefreshQueue()
    if #refreshTasks == 0 then
        return
    end
    local tasksThisFrame = math.min(#refreshTasks, 3)
    for _ = 1, tasksThisFrame do
        local task = table.remove(refreshTasks, 1)
        if not task then
            return
        end
        refreshTaskSet[task] = nil

        if task == "visible" then
            RefreshVisibleTab()
        elseif task == "casting" then
            if SettingsScreen then
                SettingsScreen:RefreshCasting()
            end
        elseif task == "tracking" then
            RefreshEmbeddedTracking()
        elseif task == "trackingOptions" then
            RefreshEmbeddedTracking("options")
        elseif task == "trackingStats" then
            RefreshEmbeddedTracking("stats")
        elseif task == "trackingCardStats" then
            RefreshTrackingCardStatsOnly()
        elseif task == "trackingPage" then
            RefreshEmbeddedTracking("page")
        elseif task == "trackingRows" then
            RefreshEmbeddedTracking("rows")
        elseif task == "scoring" then
            RefreshEmbeddedScoring()
        elseif task == "expansionGuide" then
            if ExpansionGuideScreen and ExpansionGuideScreen.Refresh then
                ExpansionGuideScreen:Refresh(activeExpansionGuideScreen, GetExpansionDisplayName(selectedExpansionKey or "midnight"), selectedExpansionKey or "midnight")
            end
        elseif task == "skillPrompt" then
            MainWindow:RefreshExpansionSkillPrompt()
        elseif task == "settings" then
            if SettingsScreen then
                SettingsScreen:RefreshModules()
            end
        elseif task == "summary" then
            RefreshLegacyDashboardSummary()
        end

        if task == "visible" or task == "trackingStats" or task == "trackingPage" then
            return
        end
    end
end

function MainWindow:RefreshStaticLocaleText()
    title:SetText(L["CONTROL_PANEL_TITLE"])
    for i = 1, #PRIMARY_NAV do
        local tab = PRIMARY_NAV[i]
        local button = navButtons[tab.key]
        if button then
            button.text:SetText(GetNavLabel(tab))
        end
    end
    for i = 1, #UTILITY_NAV do
        local tab = UTILITY_NAV[i]
        local button = navButtons[tab.key]
        if button then
            button.text:SetText(GetNavLabel(tab))
        end
    end
end

function MainWindow:Refresh(task)
    if task then
        QueueRefreshTask(task)
        return
    end
    self:RefreshStaticLocaleText()
    self:RefreshFishingStatus()
    QueueRefreshTask("visible")
    if SettingsScreen then
        if activeTab == SettingsScreen:GetActivePanelKey() then
            SettingsScreen:Refresh()
        else
            SettingsScreen:RefreshModules()
        end
    end
end

function MainWindow:SelectTab(key)
    HideTrackingExpansionDropdown()
    if key == "settings" then
        activeNavKey = "settings"
        selectedExpansionKey = nil
        ExpansionSkill.selectedState = nil
        activeTab = SettingsScreen and SettingsScreen:GetActivePanelKey() or "casting"
    elseif key == "midnight" then
        activeNavKey = "midnight"
        selectedExpansionKey = "midnight"
        ExpansionSkill.selectedState = ExpansionSkill:CharacterHasFishingSkill("midnight")
        if ExpansionSkill.selectedState == true then
            activeTab = "tracking"
            LoadTrackingSettings()
            trackingMode = "all"
            trackingExpansion = "midnight"
            trackingView = TRACKING_VIEW_HISTORY
            trackingDrilldownZoneID = nil
            trackingOffset = 0
            PersistTrackingSettings()
        else
            activeTab = "skillPrompt"
        end
    elseif key ~= "tracking" then
        activeNavKey = key
        selectedExpansionKey = key
        ExpansionSkill.selectedState = EXPANSION_NAV_KEYS[key] and ExpansionSkill:CharacterHasFishingSkill(key) or nil
        if EXPANSION_NAV_KEYS[key] and ExpansionSkill.selectedState ~= true then
            activeTab = "skillPrompt"
        else
            activeTab = "tracking"
            LoadTrackingSettings()
            trackingMode = "all"
            trackingExpansion = key
            trackingView = TRACKING_VIEW_HISTORY
            trackingDrilldownZoneID = nil
            trackingOffset = 0
            PersistTrackingSettings()
        end
    else
        activeNavKey = "tracking"
        selectedExpansionKey = nil
        ExpansionSkill.selectedState = nil
        activeTab = "tracking"
        ResetDashboardExpansionDefault()
    end
    for tabKey, panel in pairs(panels) do
        panel:SetShown(tabKey == activeTab)
    end
    for tabKey, button in pairs(navButtons) do
        button:SetSelected(tabKey == activeNavKey)
    end
    self:Refresh()
end

function MainWindow:SelectExpansionOverview(expansionKey)
    HideTrackingExpansionDropdown()
    expansionKey = expansionKey or "midnight"
    activeNavKey = expansionKey
    selectedExpansionKey = expansionKey
    ExpansionSkill.selectedState = true
    activeTab = "tracking"
    LoadTrackingSettings()
    trackingMode = "all"
    trackingExpansion = expansionKey
    trackingView = TRACKING_VIEW_HISTORY
    trackingDrilldownZoneID = nil
    trackingOffset = 0
    PersistTrackingSettings()
    for tabKey, panel in pairs(panels) do
        panel:SetShown(tabKey == activeTab)
    end
    for tabKey, button in pairs(navButtons) do
        button:SetSelected(tabKey == activeNavKey)
    end
    self:Refresh()
end

function MainWindow:SelectSettingsSection(section)
    if SettingsScreen then
        SettingsScreen:SetSection(section)
        return
    end
    self:SelectTab("settings")
end

function MainWindow:SelectMidnightScore()
    HideTrackingExpansionDropdown()
    activeNavKey = "midnight"
    selectedExpansionKey = "midnight"
    ExpansionSkill.selectedState = true
    activeTab = "scoring"
    for tabKey, panel in pairs(panels) do
        panel:SetShown(tabKey == activeTab)
    end
    for tabKey, button in pairs(navButtons) do
        button:SetSelected(tabKey == activeNavKey)
    end
    self:Refresh()
end

function MainWindow:SelectExpansionInfo(expansionKey, screenKey)
    HideTrackingExpansionDropdown()
    activeExpansionGuideScreen = screenKey or "pools"
    expansionKey = expansionKey or "midnight"
    if expansionKey ~= "midnight" and (activeExpansionGuideScreen == "score" or activeExpansionGuideScreen == "grandline") then
        activeExpansionGuideScreen = "fish"
    end
    activeNavKey = expansionKey
    selectedExpansionKey = expansionKey
    ExpansionSkill.selectedState = true
    activeTab = "expansionGuide"
    for tabKey, panel in pairs(panels) do
        panel:SetShown(tabKey == activeTab)
    end
    for tabKey, button in pairs(navButtons) do
        button:SetSelected(tabKey == activeNavKey)
    end
    self:Refresh()
end

function MainWindow:Show()
    if IsRuntimeDisabled() then
        return
    end

    if not activeTab then
        self:SelectTab("tracking")
    else
        self:Refresh()
    end
    frame:Show()
end

function MainWindow:IsShown()
    return frame:IsShown()
end

function MainWindow:Hide()
    frame:Hide()
end

function MainWindow:Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function MainWindow:ShowTracking(mode)
    trackingMode = mode or "all"
    trackingOffset = 0
    self:SelectTab("tracking")
    frame:Show()
end

function MainWindow:ShowScoring(showAll)
    scoreState.showAll = showAll and true or false
    scoreState.offset = 0
    self:SelectTab("midnight")
    frame:Show()
end

local sidebarPrimaryDivider = sidebar:CreateTexture(nil, "ARTWORK")
sidebarPrimaryDivider:SetColorTexture(unpack(Theme.color.accent))
sidebarPrimaryDivider:SetPoint("TOPLEFT", 10, -(Theme.layout.rowHeight + 13))
sidebarPrimaryDivider:SetPoint("RIGHT", -10, 0)
sidebarPrimaryDivider:SetHeight(2)

for i = 1, #PRIMARY_NAV do
    local tab = PRIMARY_NAV[i]
    local button = Theme:CreateNavButton(sidebar, GetNavLabel(tab))
    local yOffset = (i - 1) * SIDEBAR_ROW_STEP
    if i > 1 then
        yOffset = yOffset + SIDEBAR_GROUP_GAP
    end
    button:SetPoint("TOPLEFT", 0, -yOffset)
    button:SetPoint("RIGHT", 0, 0)
    button:SetScript("OnClick", function() MainWindow:SelectTab(tab.key) end)
    navButtons[tab.key] = button
end

for i = 1, #UTILITY_NAV do
    local tab = UTILITY_NAV[i]
    local button = Theme:CreateNavButton(sidebar, GetNavLabel(tab))
    button:SetPoint("BOTTOMLEFT", 0, ((i - 1) * (Theme.layout.rowHeight + 8)))
    button:SetPoint("RIGHT", 0, 0)
    button:SetScript("OnClick", function() MainWindow:SelectTab(tab.key) end)
    navButtons[tab.key] = button
end

sessionResetButton:SetScript("OnClick", function()
    if AvidAngler.Modules.Tracking then
        AvidAngler.Modules.Tracking:ResetSession()
        MainWindow:Refresh()
    end
end)
trackingAllButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingMode = "all"
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingSessionButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingMode = "session"
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingZoneButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingMode = "zone"
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingScopeButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingScope = trackingScope == TRACKING_SCOPE_WARBAND and TRACKING_SCOPE_CHARACTER or TRACKING_SCOPE_WARBAND
    trackingExpansion = TRACKING_EXPANSION_ALL
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingExpansionButton:SetScript("OnClick", function()
    ToggleTrackingExpansionDropdown()
end)
trackingHistoryButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingView = TRACKING_VIEW_HISTORY
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingFishButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingView = TRACKING_VIEW_FISH
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingZonesButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingDrilldownZoneID = nil
    trackingView = TRACKING_VIEW_ZONES
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingScoreButton:SetScript("OnClick", function()
    MainWindow:SelectMidnightScore()
end)
trackingMidnightFishButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "fish")
end)
trackingMidnightFishButton.grandLineButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "grandline")
end)
trackingPoolsButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "pools")
end)
trackingLuresButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "lures")
end)
trackingAccessoriesButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "accessories")
end)
trackingCollectiblesButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "collectibles")
end)
trackingCollectiblesButton.achievementsButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo(selectedExpansionKey or "midnight", "achievements")
end)
scoreUI.achievementsButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "achievements")
end)
scoreUI.overviewButton:SetScript("OnClick", function()
    MainWindow:SelectTab("midnight")
end)
scoreUI.scoreButton:SetScript("OnClick", function()
    MainWindow:SelectMidnightScore()
end)
scoreUI.fishButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "fish")
end)
scoreUI.grandLineButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "grandline")
end)
scoreUI.poolsButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "pools")
end)
scoreUI.luresButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "lures")
end)
scoreUI.accessoriesButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "accessories")
end)
scoreUI.collectiblesButton:SetScript("OnClick", function()
    MainWindow:SelectExpansionInfo("midnight", "collectibles")
end)
trackingHideJunkButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingHideJunk = not trackingHideJunk
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingHideTreasuresButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingHideTreasures = not trackingHideTreasures
    trackingOffset = 0
    PersistTrackingSettings()
    MainWindow:Refresh()
end)
trackingResetButton:SetScript("OnClick", function()
    if AvidAngler.Modules.Tracking then
        AvidAngler.Modules.Tracking:ResetSession()
        trackingMode = "session"
        trackingOffset = 0
        PersistTrackingSettings()
        MainWindow:Refresh()
    end
end)
trackingPrevButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingOffset = math.max(trackingOffset - #trackingRows, 0)
    MainWindow:Refresh()
end)
trackingNextButton:SetScript("OnClick", function()
    HideTrackingExpansionDropdown()
    trackingOffset = trackingOffset + #trackingRows
    MainWindow:Refresh()
end)
scoreUI.zoneButton:SetScript("OnClick", function()
    scoreState.showAll = false
    scoreState.offset = 0
    MainWindow:Refresh()
end)
scoreUI.allButton:SetScript("OnClick", function()
    scoreState.showAll = true
    scoreState.offset = 0
    MainWindow:Refresh()
end)
scoreUI.hideTrophyButton:SetScript("OnClick", function()
    if AvidAngler.Modules.Scoring then
        AvidAngler.Modules.Scoring:SetHideTrophy(not AvidAngler.Modules.Scoring:IsHidingTrophy(), true)
    end
    scoreState.offset = 0
    MainWindow:Refresh()
end)
scoreUI.prevButton:SetScript("OnClick", function()
    scoreState.offset = math.max(scoreState.offset - #scoreUI.rows, 0)
    MainWindow:Refresh()
end)
scoreUI.nextButton:SetScript("OnClick", function()
    scoreState.offset = scoreState.offset + #scoreUI.rows
    MainWindow:Refresh()
end)
scoreUI.watchKeepOpenCheck:SetScript("OnClick", function(self)
    local scoring = AvidAngler.Modules.Scoring
    self:SetChecked(not self:GetChecked())
    if scoring and scoring.SetKeepScoreWatchOpen then
        scoring:SetKeepScoreWatchOpen(self:GetChecked())
    end
    MainWindow:Refresh()
end)
scoreUI.watchShowButton:SetScript("OnClick", function()
    local scoring = AvidAngler.Modules.Scoring
    if scoring and scoring.ShowScoreWatch then
        scoring:ShowScoreWatch()
    end
    MainWindow:Refresh()
end)
EventRegistry:RegisterCallback(AvidAngler.CATCH_RECORDED_EVENT, function()
    if IsRuntimeDisabled() then
        return
    end
    if frame:IsShown() then
        QueueFishingDataRefresh("catch")
    end
end)

EventRegistry:RegisterCallback(AvidAngler.CAST_RECORDED_EVENT, function()
    if IsRuntimeDisabled() then
        return
    end
    if frame:IsShown() then
        QueueFishingDataRefresh("cast")
    end
end)

EventRegistry:RegisterCallback(AvidAngler.MODULE_SETTING_CHANGED_EVENT, function()
    if IsRuntimeDisabled() then
        if frame:IsShown() then
            frame:Hide()
        end
        return
    end
    if frame:IsShown() then
        MainWindow:Refresh()
    end
end)

EventRegistry:RegisterCallback(AvidAngler.CONTENT_SAFETY_CHANGED_EVENT, function()
    if IsRuntimeDisabled() and frame:IsShown() then
        frame:Hide()
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
for _, event in ipairs({ "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED" }) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if IsRuntimeDisabled() then
        return
    end

    if event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_COLLECTION_SOURCE_ADDED"
        or event == "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED" then
        if frame:IsShown() and activeTab == "expansionGuide" then QueueRefreshTask("visible") end
        return
    end

    local shouldRefresh = event ~= "SKILL_LINES_CHANGED" and event ~= "TRADE_SKILL_LIST_UPDATE" and event ~= "CHAT_MSG_SYSTEM"
    if event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" then
        local _, changed = ExpansionSkill:RefreshFromJournal()
        shouldRefresh = changed
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        local learnedExpansion = ExpansionSkill:UpdateFromSystemMessage(message)
        shouldRefresh = learnedExpansion ~= nil
        if learnedExpansion and selectedExpansionKey == learnedExpansion and activeTab == "skillPrompt" then
            ExpansionSkill.selectedState = true
            activeTab = "tracking"
            LoadTrackingSettings()
            trackingMode = "all"
            trackingExpansion = learnedExpansion
            trackingDrilldownZoneID = nil
            trackingOffset = 0
            PersistTrackingSettings()
        end
    end
    if frame:IsShown() then
        MainWindow:RefreshSelectedFishingSkill()
    end
    if shouldRefresh and frame:IsShown() then
        MainWindow:Refresh()
    end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    ProcessRefreshQueue()

    refreshElapsed = refreshElapsed + elapsed
    if refreshElapsed < 1 then
        return
    end
    refreshElapsed = 0
    if frame:IsShown() then MainWindow:RefreshFishingStatus() end
    if frame:IsShown() and activeTab == "skillPrompt" then
        MainWindow:RefreshSelectedFishingSkill()
    end
    if frame:IsShown() and activeTab == "casting" then
        local casting = AvidAngler.Modules.Casting
        if casting and casting.RefreshResolvedAction then
            casting:RefreshResolvedAction()
            MainWindow:Refresh("casting")
        end
    end
end)

SLASH_AVIDANGLER1 = "/avidangler"
SLASH_AVIDANGLER2 = "/aa"
SlashCmdList["AVIDANGLER"] = function()
    MainWindow:Toggle()
end
