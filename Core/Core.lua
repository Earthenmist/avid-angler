-- Avid Angler
-- Core namespace bootstrap and shared catch-record data layer.
--
-- Avid Angler is organized as three internally decoupled pillars — casting
-- and gear automation, catch tracking, and achievement scoring — that share
-- one read/write data layer for what was caught, where, and when. Core owns
-- the single shared loot listener that produces catch records; no pillar
-- module parses loot directly.

local ADDON_NAME, AvidAngler = ...

-- Public module registry. Each pillar registers its own small table here
-- (e.g. AvidAngler.Modules.Casting) rather than reaching into another
-- pillar's file-local state.
AvidAngler.Modules = {}

-- Shared, Core-owned catch-record store. Tracking and Scoring read from
-- this; neither owns it. Casting may read the recent-catch broadcast for
-- its own throw-back/timer logic, but never writes catch records directly.
AvidAngler.DataLayer = {}

-- Small session-context table Casting publishes into (active lure, active
-- buffs, current cast target) so the Core loot listener can enrich a catch
-- record without Core reaching into Casting's internals.
AvidAngler.Session = {}

-- The event name broadcast through EventRegistry each time a catch record
-- is written. Casting, Tracking, and Scoring all subscribe independently;
-- none of them read loot directly.
AvidAngler.CATCH_RECORDED_EVENT = "AvidAngler.CatchRecorded"
AvidAngler.CAST_RECORDED_EVENT = "AvidAngler.CastRecorded"
AvidAngler.MODULE_SETTING_CHANGED_EVENT = "AvidAngler.ModuleSettingChanged"
AvidAngler.FISHING_SKILL_CACHE_UPDATED_EVENT = "AvidAngler.FishingSkillCacheUpdated"
AvidAngler.CONTENT_SAFETY_CHANGED_EVENT = "AvidAngler.ContentSafetyChanged"

-- Prefixes a chat message with the addon name in the shared accent color,
-- for the same consistent identification any module's feedback should use
-- rather than each printing its own ad hoc prefix.
local PRINT_PREFIX = "|cff3ed9c0Avid Angler|r: "
local MODULE_DEFAULTS = {
    casting = true,
    tracking = true,
    scoring = true,
}
local MODULE_TABLES = {
    casting = "Casting",
    tracking = "Tracking",
    scoring = "Scoring",
}

function AvidAngler:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PRINT_PREFIX .. tostring(message))
end

local eventFrame = CreateFrame("Frame")
AvidAngler.EventFrame = eventFrame
local lootWindowRecorded = false
local HOUSING_ZONE_MAP_IDS = {
    [2401] = true, -- Alliance Housing District
    [2402] = true, -- Horde Housing District
}
local HOUSING_INSTANCE_TYPES = {
    interior = true,
    neighborhood = true,
}
local OPEN_WATER_ONLY_ZONE_MAP_IDS = {
    [2351] = true, -- Razorwind Shores
    [2352] = true, -- Founder's Point
}
local PROTECTED_INSTANCE_TYPES = {
    arena = true,
    party = true,
    pvp = true,
    raid = true,
    scenario = true,
}

local function IsInaccessibleSecret(value)
    if not issecretvalue or not issecretvalue(value) then
        return false
    end
    if not canaccessvalue then
        return true
    end

    local ok, accessible = pcall(canaccessvalue, value)
    return not (ok and accessible)
end

local function SafeBestMapForPlayer()
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return nil
    end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or IsInaccessibleSecret(mapID) then
        return nil
    end
    return tonumber(mapID)
end

function AvidAngler:IsHousingZone(mapID)
    return mapID and HOUSING_ZONE_MAP_IDS[tonumber(mapID)] and true or false
end

function AvidAngler:IsHousingInstanceType(instanceType)
    return instanceType and HOUSING_INSTANCE_TYPES[instanceType] and true or false
end

function AvidAngler:RefreshContentSafety()
    local previous = self.runtimeDisabled
    local disabled = false
    local reason
    local instanceType

    if type(IsInInstance) == "function" then
        local ok, inInstance, currentInstanceType = pcall(IsInInstance)
        if ok and not IsInaccessibleSecret(inInstance) and not IsInaccessibleSecret(currentInstanceType) then
            instanceType = currentInstanceType
            if inInstance and (PROTECTED_INSTANCE_TYPES[currentInstanceType] or (currentInstanceType and currentInstanceType ~= "none")) then
                disabled = not (self:IsHousingInstanceType(currentInstanceType) or self:IsHousingZone(SafeBestMapForPlayer()))
                reason = disabled and currentInstanceType or nil
            end
        else
            disabled = true
            reason = "secret"
        end
    end

    self.runtimeDisabled = disabled
    self.runtimeDisabledReason = reason
    if previous ~= nil and previous ~= disabled then
        EventRegistry:TriggerEvent(self.CONTENT_SAFETY_CHANGED_EVENT, disabled, reason, instanceType)
    end
    return disabled, reason, instanceType
end

function AvidAngler:IsRuntimeDisabled()
    if self.runtimeDisabled == nil then
        self:RefreshContentSafety()
    end
    return self.runtimeDisabled and true or false, self.runtimeDisabledReason
end

local function EnsurePersistentTables()
    AvidAnglerDB = AvidAnglerDB or {}
    AvidAnglerDB.catches = AvidAnglerDB.catches or {}
    AvidAnglerDB.casts = AvidAnglerDB.casts or {}
    AvidAnglerDB.skillCache = AvidAnglerDB.skillCache or {}
    AvidAnglerDB.skillCache.characters = AvidAnglerDB.skillCache.characters or {}
    AvidAnglerDB.collectibleCache = AvidAnglerDB.collectibleCache or {}
    AvidAnglerDB.collectibleCache.account = AvidAnglerDB.collectibleCache.account or {}
    AvidAnglerDB.collectibleCache.characters = AvidAnglerDB.collectibleCache.characters or {}
    AvidAnglerDB.settings = AvidAnglerDB.settings or {}
    AvidAnglerDB.settings.modules = AvidAnglerDB.settings.modules or {}
    AvidAnglerDB.settings.midnight = AvidAnglerDB.settings.midnight or {}
    AvidAnglerDB.settings.setupWizard = AvidAnglerDB.settings.setupWizard or {}
    AvidAngler.DB = AvidAnglerDB
    return AvidAnglerDB
end

local function OnAddonLoaded(name)
    if name ~= ADDON_NAME then
        return
    end

    local db = EnsurePersistentTables()
    for key, enabled in pairs(MODULE_DEFAULTS) do
        if db.settings.modules[key] == nil then
            db.settings.modules[key] = enabled
        end
    end
    if AvidAngler.RefreshLocale then
        AvidAngler:RefreshLocale()
    end
    AvidAngler:RefreshContentSafety()
    AvidAngler:ApplyModuleSettings()
end

function AvidAngler:IsModuleEnabled(key)
    local modules = self.DB and self.DB.settings and self.DB.settings.modules
    if modules and modules[key] ~= nil then
        return modules[key] and true or false
    end
    return MODULE_DEFAULTS[key] ~= false
end

function AvidAngler:SetModuleEnabled(key, enabled)
    if not MODULE_DEFAULTS[key] then
        return
    end

    AvidAnglerDB = AvidAnglerDB or {}
    AvidAnglerDB.settings = AvidAnglerDB.settings or {}
    AvidAnglerDB.settings.modules = AvidAnglerDB.settings.modules or {}
    AvidAnglerDB.settings.modules[key] = enabled and true or false
    self.DB = AvidAnglerDB

    local moduleName = MODULE_TABLES[key]
    local module = moduleName and self.Modules and self.Modules[moduleName]
    local shouldRun = enabled and not self:IsRuntimeDisabled()
    if module then
        if shouldRun and module.Enable then
            module:Enable()
        elseif (not shouldRun) and module.Disable then
            module:Disable()
        end
    end
    EventRegistry:TriggerEvent(self.MODULE_SETTING_CHANGED_EVENT, key, enabled and true or false)
end

function AvidAngler:ApplyModuleSettings()
    for key in pairs(MODULE_DEFAULTS) do
        self:SetModuleEnabled(key, self:IsModuleEnabled(key))
    end
end

function AvidAngler:ApplyContentSafety()
    self:RefreshContentSafety()
    self:ApplyModuleSettings()
end

function AvidAngler:IsSetupWizardComplete()
    local settings = self.DB and self.DB.settings and self.DB.settings.setupWizard
    return settings and settings.completed and true or false
end

function AvidAngler:SetSetupWizardComplete(completed)
    local db = EnsurePersistentTables()
    db.settings.setupWizard.completed = completed and true or false
    db.settings.setupWizard.completedAt = completed and time() or nil
end

-- Writes one catch record to the persisted store and notifies subscribers.
-- The only writer of AvidAngler.DB.catches; every pillar reads through
-- this table rather than appending to it directly.
function AvidAngler.DataLayer:RecordCatch(record)
    if not AvidAngler.DB or type(record) ~= "table" or AvidAngler:IsRuntimeDisabled() then
        return
    end
    table.insert(AvidAngler.DB.catches, record)
    EventRegistry:TriggerEvent(AvidAngler.CATCH_RECORDED_EVENT, record)
end

function AvidAngler.DataLayer:GetCatches()
    return AvidAngler.DB and AvidAngler.DB.catches or {}
end

function AvidAngler.DataLayer:RecordFishingCast(record)
    if not AvidAngler.DB or type(record) ~= "table" or AvidAngler:IsRuntimeDisabled() then
        return
    end
    table.insert(AvidAngler.DB.casts, record)
    EventRegistry:TriggerEvent(AvidAngler.CAST_RECORDED_EVENT, record)
end

function AvidAngler.DataLayer:GetFishingCasts()
    return AvidAngler.DB and AvidAngler.DB.casts or {}
end

local function GetCurrentCharacterFields()
    local characterName = UnitName("player")
    local realmName = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    local characterKey
    if characterName and realmName then
        characterKey = realmName .. "-" .. characterName
    end
    return characterName, realmName, characterKey
end

function AvidAngler:GetCurrentCharacterKey()
    local _, _, characterKey = GetCurrentCharacterFields()
    return characterKey
end

function AvidAngler.DataLayer:SaveCharacterFishingSkillSnapshot(states)
    if type(states) ~= "table" then
        return
    end
    local db = EnsurePersistentTables()

    local characterKey = AvidAngler.GetCurrentCharacterKey and AvidAngler:GetCurrentCharacterKey()
    if not characterKey then
        return
    end

    local snapshot = {
        updatedAt = time(),
        source = "fishingJournal",
        expansions = {},
    }
    for expansionKey, learned in pairs(states) do
        snapshot.expansions[expansionKey] = learned and true or false
    end
    db.skillCache.characters[characterKey] = snapshot
    EventRegistry:TriggerEvent(AvidAngler.FISHING_SKILL_CACHE_UPDATED_EVENT, snapshot)
end

function AvidAngler.DataLayer:GetCharacterFishingSkillSnapshot()
    local characterKey = AvidAngler.GetCurrentCharacterKey and AvidAngler:GetCurrentCharacterKey()
    local db = AvidAngler.DB or AvidAnglerDB
    local characters = db and db.skillCache and db.skillCache.characters
    return characterKey and characters and characters[characterKey] or nil
end

function AvidAngler.DataLayer:UpdateCharacterFishingSkillState(expansionKey, learned, source)
    if type(expansionKey) ~= "string" then
        return nil
    end

    local db = EnsurePersistentTables()

    local characterKey = AvidAngler.GetCurrentCharacterKey and AvidAngler:GetCurrentCharacterKey()
    if not characterKey then
        return nil
    end

    local snapshot = db.skillCache.characters[characterKey]
    if type(snapshot) ~= "table" then
        snapshot = { expansions = {} }
        db.skillCache.characters[characterKey] = snapshot
    end
    snapshot.expansions = snapshot.expansions or {}
    snapshot.expansions[expansionKey] = learned and true or false
    snapshot.updatedAt = time()
    snapshot.source = source or "skillUpdate"
    EventRegistry:TriggerEvent(AvidAngler.FISHING_SKILL_CACHE_UPDATED_EVENT, snapshot, expansionKey)
    return snapshot
end

local TREASURE_NAME_PATTERNS = {
    "chest",
    "crate",
    "cask",
    "barrel",
    "trunk",
    "lockbox",
    "treasure",
    "clamshell",
    "oyster",
    "cosmetic",
}

local KNOWN_TREASURE_NAMES = {
    ["farstrider's solemn bow"] = true,
}

function AvidAngler.DataLayer:GetKnownFishExpansion(itemID, itemName)
    local catalog = AvidAngler.Data and AvidAngler.Data.FishCatalog
    local catalogExpansion = catalog and catalog:GetExpansion(itemID, itemName)
    if catalogExpansion then
        return catalogExpansion
    end

    local scoring = AvidAngler.Modules and AvidAngler.Modules.Scoring
    if scoring and scoring.IsKnownFish and scoring:IsKnownFish(itemID, itemName) then
        return "midnight"
    end
end

function AvidAngler.DataLayer:IsKnownFish(itemID, itemName)
    return self:GetKnownFishExpansion(itemID, itemName) ~= nil
end

local function IsKnownFish(itemID, itemName)
    return AvidAngler.DataLayer:IsKnownFish(itemID, itemName)
end

local function IsEquipmentClass(classID)
    local itemClass = Enum and Enum.ItemClass
    local weaponClass = itemClass and itemClass.Weapon
    local armorClass = itemClass and itemClass.Armor
    return type(classID) == "number" and ((type(weaponClass) == "number" and classID == weaponClass) or (type(armorClass) == "number" and classID == armorClass)) or false
end

local function ClassifyCatch(item, link, itemID)
    local quality = item and item.quality
    local name = item and (item.itemName or item.item)
    if (not name or name == "") and link then
        name = C_Item.GetItemInfo(link)
    end
    if IsKnownFish(itemID, name) then
        return "fish"
    end

    name = name and name:lower()
    if name then
        for _, pattern in ipairs(TREASURE_NAME_PATTERNS) do
            if name:find(pattern, 1, true) then
                return "treasure"
            end
        end
        if KNOWN_TREASURE_NAMES[name] then
            return "treasure"
        end
    end

    if quality == 0 or (Enum and Enum.ItemQuality and quality == Enum.ItemQuality.Poor) then
        return "junk"
    elseif quality == 1 or (Enum and Enum.ItemQuality and quality == Enum.ItemQuality.Common) then
        return "junk"
    elseif type(quality) == "number" and quality >= 2 then
        return "treasure"
    end

    if link and C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok
        local itemEquipLoc
        local itemClassID
        ok, _, _, _, _, _, _, _, _, itemEquipLoc, _, _, itemClassID = pcall(C_Item.GetItemInfo, link)
        if ok then
            if itemEquipLoc and itemEquipLoc ~= "" then
                return "treasure"
            end
            if IsEquipmentClass(itemClassID) then
                return "treasure"
            end
        end
    end

    return "unknown"
end

function AvidAngler.DataLayer:BuildFishingCastRecord()
    if AvidAngler:IsRuntimeDisabled() then
        return nil
    end

    local zoneMapID = SafeBestMapForPlayer()
    local characterName, realmName, characterKey = GetCurrentCharacterFields()
    return {
        timestamp = time(),
        zoneMapID = zoneMapID,
        characterName = characterName,
        realmName = realmName,
        characterKey = characterKey,
    }
end

-- Builds one normalized catch record from a resolved fishing loot slot.
-- Optional context fields are filled from Core session state when available
-- and otherwise remain explicitly unknown.
local function BuildCatchRecord(index, item, zoneMapID, coordX, coordY)
    local link = GetLootSlotLink(index)
    local itemID = link and select(1, C_Item.GetItemInfoInstant(link))
    local itemName = item.itemName or item.item
    local catchSource = AvidAngler.Session.catchSource
    local poolName = AvidAngler.Session.poolName
    if OPEN_WATER_ONLY_ZONE_MAP_IDS[zoneMapID] then
        catchSource = "open-water"
        poolName = nil
    elseif (not catchSource or catchSource == "unknown") and AvidAngler.Modules.Scoring and AvidAngler.Modules.Scoring.GetKnownCatchSource then
        local knownSource, knownPoolName = AvidAngler.Modules.Scoring:GetKnownCatchSource(itemID, itemName)
        if knownSource == "pool" or knownSource == "open-water" or knownSource == "either" then
            catchSource = knownSource
            poolName = poolName or knownPoolName
        end
    end
    if (not catchSource or catchSource == "unknown") and AvidAngler.Session.defaultCatchSource then
        catchSource = AvidAngler.Session.defaultCatchSource
    end
    local characterName, realmName, characterKey = GetCurrentCharacterFields()

    return {
        itemID      = itemID,
        itemName    = itemName,
        itemQuality = item.quality,
        quantity    = item.quantity,
        timestamp   = time(),
        zoneMapID   = zoneMapID,
        coordX      = coordX,
        coordY      = coordY,
        catchSource = catchSource or "unknown",
        catchType   = ClassifyCatch(item, link, itemID),
        lureActive  = AvidAngler.Session.activeLure,
        poolName    = poolName,
        characterName = characterName,
        realmName   = realmName,
        characterKey = characterKey,
    }
end

-- Fires on every loot window becoming ready. Gated on IsFishingLoot() so
-- only fishing catches are recorded; this never loots on the player's
-- behalf — auto-loot is a Casting-owned preference, not Core's job.
local function OnLootReady()
    if lootWindowRecorded or AvidAngler:IsRuntimeDisabled() or InCombatLockdown() or not IsFishingLoot() then
        return
    end
    lootWindowRecorded = true

    local zoneMapID = SafeBestMapForPlayer()
    local position
    if zoneMapID and C_Map and type(C_Map.GetPlayerMapPosition) == "function" then
        position = AvidAngler.SafeCall and AvidAngler:SafeCall(C_Map.GetPlayerMapPosition, nil, zoneMapID, "player") or nil
    end
    local coordX, coordY
    if position then
        coordX, coordY = position:GetXY()
    end

    for index, item in ipairs(GetLootInfo()) do
        AvidAngler.DataLayer:RecordCatch(BuildCatchRecord(index, item, zoneMapID, coordX, coordY))
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        AvidAngler:ApplyContentSafety()
    elseif event == "LOOT_READY" then
        OnLootReady()
    elseif event == "LOOT_CLOSED" then
        lootWindowRecorded = false
    end
end)
