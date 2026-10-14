-- Avid Angler
-- Expansion guide and collection screens.

local _, AvidAngler = ...

local Theme = AvidAngler.UI.Theme
local L = AvidAngler.L
local itemInfoCache = {}

local ExpansionGuide = {}
AvidAngler.UI.ExpansionGuide = ExpansionGuide

local CARD_COLUMNS = 3
local CARD_WIDTH = 286
local CARD_HEIGHT = 92
local CARD_PAGE_SIZE = 12
local COLLECTIBLE_PAGE_SIZE = 15

local GRAND_LINE_ITEM_IDS = {
    final = 262796,
    shreddedBloom = 262792,
    strandedBloom = 262793,
    weakBloom = 262794,
    bloom = 262795,
    shreddedGlimmer = 262797,
    strandedGlimmer = 262798,
    weakGlimmer = 262799,
    glimmer = 262800,
}

local GRAND_LINE_ITEM_NAMES = {
    [262796] = "Midnight Angler's Grand Line",
    [262792] = "Shredded Bloomline",
    [262793] = "Stranded Bloomline",
    [262794] = "Weak Bloomline",
    [262795] = "Angler's Bloomline",
    [262797] = "Shredded Glimmerline",
    [262798] = "Stranded Glimmerline",
    [262799] = "Weak Glimmerline",
    [262800] = "Angler's Glimmerline",
}

local GRAND_LINE_ITEM_QUALITIES = {
    [262796] = 5,
    [262792] = 1,
    [262793] = 2,
    [262794] = 3,
    [262795] = 4,
    [262797] = 1,
    [262798] = 2,
    [262799] = 3,
    [262800] = 4,
}

local INFO_ONLY_ITEM_IDS = {
    [255157] = true,
    [243343] = true,
    [262649] = true,
}

local MIDNIGHT_EXCLUDED_LURE_ITEM_IDS = {
    [250096] = true, -- Worm Bait
    [271181] = true, -- Finnow Chum
    [271182] = true, -- Plecofin Bait
    [277848] = true, -- Untouched Crab Lure
    [280446] = true, -- Unnerving Bait
}

local EXPANSION_EXCLUDED_LURE_ITEM_IDS = {
    warWithin = {
        [216664] = true, -- Threadling Lure
        [225640] = true, -- Abyssal Lure
        [239074] = true, -- Void Lure
    },
}

local EXPANSION_LURE_TOY_ITEM_IDS = {
    warWithin = {
        [225641] = true, -- Illusive Kobyss Lure
        [228413] = true, -- Lampyridae Lure
    },
}

local EXPANSION_LURE_PET_ITEM_IDS = {
    shadowlands = {
        [185919] = true, -- Flawless Amethyst Baubleworm
        [186535] = true, -- Topaz Baubleworm
        [186536] = true, -- Turquoise Baubleworm
        [186537] = true, -- Ruby Baubleworm
    },
}

local EXPANSION_ACCESSORY_ITEM_IDS = {
    battleForAzeroth = {
        [160711] = true, -- Aromatic Fish Oil
        [162515] = true, -- Midnight Salmon
        [162516] = true, -- Rasboralus
        [162517] = true, -- U'taka
        [167698] = true, -- Secret Fish Goggles
        [168016] = true, -- Hyper-Compressed Ocean
    },
    legion = {
        [138448] = true, -- Emblem of Margoss
        [138777] = true, -- Drowned Mana
        [141975] = true, -- Mark of Aquaos
    },
    warlords = {
        [118391] = true, -- Worm Supreme
    },
    pandaria = {
        [84660] = true, -- Pandaren Fishing Pole
        [84661] = true, -- Dragon Fishing Pole
        [85500] = true, -- Anglers Fishing Raft
        [85973] = true, -- Ancient Pandaren Fishing Charm
        [86596] = true, -- Nat's Fishing Chair
        [88535] = true, -- Sharpened Tuskarr Spear
        [88563] = true, -- Nat's Fishing Journal
        [88710] = true, -- Nat's Hat
    },
    shadowlands = {
        [180136] = true, -- The Brokers Angle'r
        [187662] = true, -- Strange Goop
        [187915] = true, -- Pungent Blobfish
        [187916] = true, -- Coilclutch Vine
        [187922] = true, -- Flipper Fish
        [187923] = true, -- Aurelid Lure
    },
    dragonflight = {
        [194510] = true, -- Iskaaran Harpoon
        [198070] = true, -- Tattered Seavine
        [198225] = true, -- Draconium Fisherfriend
        [198226] = true, -- Khaz'gorite Fisherfriend
        [198475] = true, -- Broken Banding
        [199694] = true, -- Flying Fish Bone Charm
        [199695] = true, -- Iskaaran Fishing Net
        [199696] = true, -- Iskaaran Ice Axe
        [199697] = true, -- Polished Basalt Bracelet
        [199698] = true, -- Irontree Harpoon Handle
        [199555] = true, -- Versatile Storm Lure
        [199844] = true, -- Serevite Harpoon Head
        [199846] = true, -- Seavine Harpoon Rope
        [199848] = true, -- Draconium Net Weights
        [199850] = true, -- Imbu Knot
        [199924] = true, -- Strong Sea Kelp
        [199925] = true, -- Stone With Hole
        [200081] = true, -- Strong Seavine
        [205229] = true, -- Magma Serpent Lure
        [205262] = true, -- Magmaclaw Lure
        [205276] = true, -- Deepflayer Lure
        [204230] = true, -- Dense Seaforged Javelin
    },
}

local FALLBACK_COLLECTIBLES = {
    { name = "Lost Frostwolf's Stand", itemID = 260908, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Winter's Hunger", itemID = 260907, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Blade of Spacial Descent", itemID = 260905, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Soul Collector", itemID = 260904, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Sunwell Splitter", itemID = 260903, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Sunset Scepter", itemID = 260902, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Stave of Burrowing Contortion", itemID = 260901, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Thunder Fist", itemID = 260900, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Lost Cerulean Edge", itemID = 260898, kind = L["MIDNIGHT_KIND_TRANSMOG"], trackType = "appearance", detail = L["MIDNIGHT_COLLECTIBLE_LOST_WEAPON"] },
    { name = "Nether-Warped Egg", itemID = 268730, kind = L["MIDNIGHT_KIND_EGG"], trackType = "item", detail = L["MIDNIGHT_COLLECTIBLE_NETHER_EGG"] },
    { name = "Nether-Swept Drake", itemID = 260916, kind = L["MIDNIGHT_KIND_MOUNT"], trackType = "mount", detail = L["MIDNIGHT_COLLECTIBLE_NETHER_DRAKE"] },
}

local function IsAccessoryInfoRow(row)
    if not row then
        return false
    end
    local itemID = tonumber(row.itemID)
    if itemID and INFO_ONLY_ITEM_IDS[itemID] then
        return true
    end
    local expansionAccessories = EXPANSION_ACCESSORY_ITEM_IDS[row.expansionKey or row.expansion]
    if itemID and expansionAccessories and expansionAccessories[itemID] then
        return true
    end

    local kind = tostring(row.kind or ""):lower()
    return kind:find("fishing accessory", 1, true)
        or kind:find("fishing enhancement", 1, true)
        or kind:find("fishing equipment", 1, true)
        or kind:find("fishing skill item", 1, true)
        or kind:find("fishing utility item", 1, true)
        or kind:find("pole skill lure", 1, true)
        or kind:find("profession / quest item", 1, true)
        or kind:find("ability unlock", 1, true)
        or kind:find("fishing unlock", 1, true)
        or kind:find("fishing line", 1, true)
        or kind:find("permanent fishing line", 1, true)
end

local function IsExcludedLureRow(row, expansionKey)
    local itemID = row and tonumber(row.itemID)
    if not itemID then
        return false
    end

    if expansionKey == "midnight" and MIDNIGHT_EXCLUDED_LURE_ITEM_IDS[itemID] then
        return true
    end

    local kind = tostring(row.kind or ""):lower()
    if kind:find("pole skill lure", 1, true) then
        return true
    end

    local excluded = EXPANSION_EXCLUDED_LURE_ITEM_IDS[expansionKey]
    if excluded and excluded[itemID] then
        return true
    end

    local collectibleToys = EXPANSION_LURE_TOY_ITEM_IDS[expansionKey]
    if collectibleToys and collectibleToys[itemID] then
        return true
    end

    local collectiblePets = EXPANSION_LURE_PET_ITEM_IDS[expansionKey]
    if collectiblePets and collectiblePets[itemID] then
        return true
    end

    local accessoryItems = EXPANSION_ACCESSORY_ITEM_IDS[expansionKey]
    return accessoryItems and accessoryItems[itemID] or false
end

local function BuildToyCollectibleRow(row)
    if not row then
        return nil
    end

    return {
        name = row.name,
        itemID = row.itemID,
        kind = L["MIDNIGHT_KIND_TOY"] or "Toy",
        trackType = "toy",
        acquisition = row.acquisition,
        source = row.source,
        fishingSource = row.fishingSource,
        areas = row.areas,
        conditions = row.conditions,
        location = row.location,
        detail = row.detail or row.source,
        notes = row.notes,
        url = row.url,
        confidence = row.confidence,
        itemTooltip = true,
    }
end

local function BuildPetCollectibleRow(row)
    if not row then
        return nil
    end

    return {
        name = row.name,
        itemID = row.itemID,
        kind = L["MIDNIGHT_KIND_PET"] or "Pet",
        trackType = "pet",
        acquisition = row.acquisition,
        source = row.source,
        fishingSource = row.fishingSource or row.detail,
        areas = row.areas,
        conditions = row.conditions,
        location = row.location,
        detail = row.detail or row.source,
        notes = row.notes,
        url = row.url,
        confidence = row.confidence,
        itemTooltip = true,
    }
end

local SCREENS = {
    achievements = {},
    fish = {
        title = L["MIDNIGHT_FISH_TITLE"],
        description = L["MIDNIGHT_FISH_DESC"],
        rows = {},
    },
    grandline = {
        title = L["MIDNIGHT_GRAND_LINE_TITLE"],
        description = L["MIDNIGHT_GRAND_LINE_DESC"],
        rows = {
            { name = "Midnight Angler's Grand Line", itemID = 262796, kind = L["MIDNIGHT_KIND_FISHING_LINE"], detail = L["MIDNIGHT_GRAND_LINE_FINAL"], craftStep = L["MIDNIGHT_GRAND_LINE_STEP_FINAL"], target = L["MIDNIGHT_GRAND_LINE_EFFECT"], source = L["MIDNIGHT_GRAND_LINE_SOURCE_COMBINE"], notes = L["MIDNIGHT_GRAND_LINE_SKILL_NOTE"], itemTooltip = true },
            { name = "Shredded Bloomline", itemID = 262792, kind = L["MIDNIGHT_KIND_BLOOMLINE"], detail = L["MIDNIGHT_GRAND_LINE_BLOOM_1"], craftStep = L["MIDNIGHT_GRAND_LINE_BLOOM_1"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_BLOOM"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Stranded Bloomline", itemID = 262793, kind = L["MIDNIGHT_KIND_BLOOMLINE"], detail = L["MIDNIGHT_GRAND_LINE_BLOOM_2"], craftStep = L["MIDNIGHT_GRAND_LINE_BLOOM_2"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_BLOOM"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Weak Bloomline", itemID = 262794, kind = L["MIDNIGHT_KIND_BLOOMLINE"], detail = L["MIDNIGHT_GRAND_LINE_BLOOM_3"], craftStep = L["MIDNIGHT_GRAND_LINE_BLOOM_3"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_BLOOM"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Angler's Bloomline", itemID = 262795, kind = L["MIDNIGHT_KIND_BLOOMLINE"], detail = L["MIDNIGHT_GRAND_LINE_BLOOM_DONE"], craftStep = L["MIDNIGHT_GRAND_LINE_BLOOM_DONE"], target = L["MIDNIGHT_GRAND_LINE_STEP_FINAL"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Shredded Glimmerline", itemID = 262797, kind = L["MIDNIGHT_KIND_GLIMMERLINE"], detail = L["MIDNIGHT_GRAND_LINE_GLIMMER_1"], craftStep = L["MIDNIGHT_GRAND_LINE_GLIMMER_1"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_GLIMMER"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Stranded Glimmerline", itemID = 262798, kind = L["MIDNIGHT_KIND_GLIMMERLINE"], detail = L["MIDNIGHT_GRAND_LINE_GLIMMER_2"], craftStep = L["MIDNIGHT_GRAND_LINE_GLIMMER_2"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_GLIMMER"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Weak Glimmerline", itemID = 262799, kind = L["MIDNIGHT_KIND_GLIMMERLINE"], detail = L["MIDNIGHT_GRAND_LINE_GLIMMER_3"], craftStep = L["MIDNIGHT_GRAND_LINE_GLIMMER_3"], target = L["MIDNIGHT_GRAND_LINE_CHAIN_GLIMMER"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
            { name = "Angler's Glimmerline", itemID = 262800, kind = L["MIDNIGHT_KIND_GLIMMERLINE"], detail = L["MIDNIGHT_GRAND_LINE_GLIMMER_DONE"], craftStep = L["MIDNIGHT_GRAND_LINE_GLIMMER_DONE"], target = L["MIDNIGHT_GRAND_LINE_STEP_FINAL"], source = L["MIDNIGHT_GRAND_LINE_SOURCE"], notes = L["MIDNIGHT_GRAND_LINE_AH_NOTE"], itemTooltip = true },
        },
    },
    pools = {
        title = L["MIDNIGHT_POOLS_TITLE"],
        description = L["MIDNIGHT_POOLS_DESC"],
        rows = {
            { name = "Careless Cargo", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_CARGO"] },
            { name = "Lost Treasures", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_TREASURES"] },
            { name = "Viscous Void", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_VISCOUS_VOID"] },
            { name = "Oceanic Vortex", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_OCEANIC_VORTEX"] },
            { name = "Abyssal Swirl", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_ABYSSAL_SWIRL"] },
            { name = "Cursed Oddity", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_CURSED_ODDITY"] },
            { name = "Hunter Surge", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_HUNTER_SURGE"] },
            { name = "Torrential Gorgerswarm", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_GORGERSWARM"] },
            { name = "Surface Ripple", kind = L["MIDNIGHT_KIND_POOL"], detail = L["MIDNIGHT_POOL_SURFACE_RIPPLE"] },
        },
    },
    lures = {
        title = L["MIDNIGHT_LURES_TITLE"],
        description = L["MIDNIGHT_LURES_DESC"],
        rows = {
            { name = "Majestic Eversong Lure", itemID = 238652, kind = L["MIDNIGHT_KIND_ZONE_LURE"], detail = L["MIDNIGHT_LURE_EVERSONG"], target = L["MIDNIGHT_LURE_TARGET_EVERSONG"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Majestic Zul'Aman Lure", itemID = 238653, kind = L["MIDNIGHT_KIND_ZONE_LURE"], detail = L["MIDNIGHT_LURE_ZULAMAN"], target = L["MIDNIGHT_LURE_TARGET_ZULAMAN"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Majestic Harandar Lure", itemID = 238654, kind = L["MIDNIGHT_KIND_ZONE_LURE"], detail = L["MIDNIGHT_LURE_HARANDAR"], target = L["MIDNIGHT_LURE_TARGET_HARANDAR"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Majestic Voidstorm Lure", itemID = 238655, kind = L["MIDNIGHT_KIND_ZONE_LURE"], detail = L["MIDNIGHT_LURE_VOIDSTORM"], target = L["MIDNIGHT_LURE_TARGET_VOIDSTORM"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Grand Beast Lure", itemID = 238656, kind = L["MIDNIGHT_KIND_CREATURE_LURE"], detail = L["MIDNIGHT_LURE_BEAST"], target = L["MIDNIGHT_LURE_TARGET_BEAST"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Lucky Loa Lure", itemID = 241145, kind = L["MIDNIGHT_KIND_FISH_LURE"], detail = L["MIDNIGHT_LURE_LUCKY_LOA"], target = L["MIDNIGHT_LURE_TARGET_LUCKY_LOA"], source = L["MIDNIGHT_LURE_SOURCE_LUCKY_LOA"] },
            { name = "Blood Hunter Lure", itemID = 241147, kind = L["MIDNIGHT_KIND_FISH_LURE"], detail = L["MIDNIGHT_LURE_BLOOD_HUNTER"], target = L["MIDNIGHT_LURE_TARGET_BLOOD_HUNTER"], source = L["MIDNIGHT_LURE_SOURCE_BLOOD_HUNTER"] },
            { name = "Ominous Octopus Lure", itemID = 241149, kind = L["MIDNIGHT_KIND_FISH_LURE"], detail = L["MIDNIGHT_LURE_OCTOPUS"], target = L["MIDNIGHT_LURE_TARGET_OCTOPUS"], source = L["MIDNIGHT_LURE_SOURCE_OCTOPUS"] },
            { name = "Ula'tek Snakehead Lure", itemID = 277821, kind = L["MIDNIGHT_KIND_FISH_LURE"], detail = L["MIDNIGHT_LURE_ULATEK"], target = L["MIDNIGHT_LURE_TARGET_ULATEK"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Coiled Stargorger Lure", itemID = 241151, kind = L["MIDNIGHT_KIND_FISH_LURE"], detail = L["MIDNIGHT_LURE_COILED_STARGORGER"], target = L["MIDNIGHT_LURE_TARGET_COILED_STARGORGER"], source = L["MIDNIGHT_LURE_SOURCE_GENERAL"] },
            { name = "Eerie Lure", itemID = 281022, kind = L["MIDNIGHT_KIND_SPECIAL_LURE"], detail = L["MIDNIGHT_LURE_EERIE"], target = L["MIDNIGHT_LURE_TARGET_EERIE"], source = L["MIDNIGHT_LURE_SOURCE_EERIE"] },
        },
    },
    accessories = {
        title = L["MIDNIGHT_ACCESSORIES_TITLE"],
        description = L["MIDNIGHT_ACCESSORIES_DESC"],
        rows = {},
    },
    collectibles = {
        title = L["MIDNIGHT_COLLECTIBLES_TITLE"],
        description = L["MIDNIGHT_COLLECTIBLES_DESC"],
        rows = FALLBACK_COLLECTIBLES,
    },
}

local function GetExpansionName(expansionKey)
    local catalog = AvidAngler.Data and AvidAngler.Data.TrainerCatalog
    return (catalog and catalog.GetExpansionName and catalog:GetExpansionName(expansionKey)) or expansionKey or L["CATCH_FILTER_EXPANSION_MIDNIGHT"]
end

local function GetScreenRows(screenKey, expansionKey)
    expansionKey = expansionKey or "midnight"
    if screenKey == "fish" then
        if expansionKey == "midnight" then
            local midnightCatalog = AvidAngler.Data and AvidAngler.Data.MidnightGuideCatalog
            local midnightRows = midnightCatalog and midnightCatalog.GetFish and midnightCatalog:GetFish()
            if midnightRows then
                return midnightRows
            end
        end
        local catalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
        local rows = catalog and catalog.GetRows and catalog:GetRows(expansionKey, "fish")
        return rows or {}
    end
    if screenKey == "pools" then
        if expansionKey == "midnight" then
            local midnightCatalog = AvidAngler.Data and AvidAngler.Data.MidnightGuideCatalog
            local midnightRows = midnightCatalog and midnightCatalog.GetPools and midnightCatalog:GetPools()
            if midnightRows then
                return midnightRows
            end
        end
        local catalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
        local rows = catalog and catalog.GetRows and catalog:GetRows(expansionKey, "pools")
        if rows then
            return rows
        end
    end
    if screenKey == "lures" then
        local catalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
        local rows = catalog and catalog.GetRows and catalog:GetRows(expansionKey, "lures")
        if rows then
            return rows
        end
    end
    if screenKey == "accessories" then
        local catalog = AvidAngler.Data and AvidAngler.Data.CollectibleCatalog
        local rows = catalog and catalog:GetExpansion(expansionKey)
        local accessoryRows = {}
        local seen = {}
        if rows then
            for _, row in ipairs(rows) do
                if IsAccessoryInfoRow(row) then
                    if row.itemID then
                        seen[tonumber(row.itemID) or row.itemID] = true
                    end
                    accessoryRows[#accessoryRows + 1] = row
                end
            end
        end
        local guideCatalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
        local lureRows = guideCatalog and guideCatalog.GetRows and guideCatalog:GetRows(expansionKey, "lures")
        if lureRows then
            for _, row in ipairs(lureRows) do
                local itemID = row.itemID and (tonumber(row.itemID) or row.itemID)
                if IsAccessoryInfoRow(row) and (not itemID or not seen[itemID]) then
                    if itemID then
                        seen[itemID] = true
                    end
                    accessoryRows[#accessoryRows + 1] = row
                end
            end
        end
        return accessoryRows
    end
    if screenKey == "collectibles" then
        local catalog = AvidAngler.Data and AvidAngler.Data.CollectibleCatalog
        local rows = catalog and catalog:GetExpansion(expansionKey)
        local collectibleRows = {}
        local seen = {}
        if rows then
            for _, row in ipairs(rows) do
                local itemID = row.itemID and (tonumber(row.itemID) or row.itemID)
                if itemID then
                    seen[itemID] = true
                end
                collectibleRows[#collectibleRows + 1] = row
            end
        end

        local collectibleToys = EXPANSION_LURE_TOY_ITEM_IDS[expansionKey]
        if collectibleToys then
            local guideCatalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
            local lureRows = guideCatalog and guideCatalog.GetRows and guideCatalog:GetRows(expansionKey, "lures")
            if lureRows then
                for _, row in ipairs(lureRows) do
                    local itemID = row.itemID and (tonumber(row.itemID) or row.itemID)
                    if itemID and collectibleToys[itemID] and not seen[itemID] then
                        local toyRow = BuildToyCollectibleRow(row)
                        if toyRow then
                            seen[itemID] = true
                            collectibleRows[#collectibleRows + 1] = toyRow
                        end
                    end
                end
            end
        end

        local collectiblePets = EXPANSION_LURE_PET_ITEM_IDS[expansionKey]
        if collectiblePets then
            local guideCatalog = AvidAngler.Data and AvidAngler.Data.ExpansionGuideCatalog
            local lureRows = guideCatalog and guideCatalog.GetRows and guideCatalog:GetRows(expansionKey, "lures")
            if lureRows then
                for _, row in ipairs(lureRows) do
                    local itemID = row.itemID and (tonumber(row.itemID) or row.itemID)
                    if itemID and collectiblePets[itemID] and not seen[itemID] then
                        local petRow = BuildPetCollectibleRow(row)
                        if petRow then
                            seen[itemID] = true
                            collectibleRows[#collectibleRows + 1] = petRow
                        end
                    end
                end
            end
        end

        if #collectibleRows > 0 then
            return collectibleRows
        end
    end
    local screen = SCREENS[screenKey]
    return screen and screen.rows or {}
end

local function NewLabel(parent, text, font, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK")
    label:SetFontObject(font or Theme.font.body)
    if point then
        label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    end
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    return label
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

    if not itemID or not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return info
    end
    local ok, name, _, quality, _, _, _, _, _, _, icon = pcall(C_Item.GetItemInfo, itemID)
    if ok and (name or icon) then
        info.name = name
        info.quality = quality
        info.icon = icon
        if name and icon then
            info.ready = true
        end
    end
    return info
end

local function GetItemInfo(itemID, callback)
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

local function ApplyItemColor(label, itemInfo)
    SetItemNameColor(label, itemInfo and itemInfo.quality)
end

local function ShowItemTooltip(owner, itemID)
    if not owner or not itemID or type(GameTooltip.SetHyperlink) ~= "function" then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. itemID)
    GameTooltip:Show()
end

local function GetOwnedItemCount(itemID)
    if not itemID or not C_Item or type(C_Item.GetItemCount) ~= "function" then
        return 0
    end
    return AvidAngler:SafeCall(C_Item.GetItemCount, 0, itemID, true, false, true, true) or 0
end

local function HasOwnedItem(itemID)
    return GetOwnedItemCount(itemID) > 0
end

local function GetMidnightSettings()
    AvidAnglerDB = AvidAnglerDB or {}
    AvidAnglerDB.settings = AvidAnglerDB.settings or {}
    AvidAnglerDB.settings.midnight = AvidAnglerDB.settings.midnight or {}
    AvidAngler.DB = AvidAnglerDB
    return AvidAnglerDB.settings.midnight
end

local function GetGuideSettings(expansionKey)
    AvidAnglerDB = AvidAnglerDB or {}
    AvidAnglerDB.settings = AvidAnglerDB.settings or {}
    AvidAnglerDB.settings.expansionGuide = AvidAnglerDB.settings.expansionGuide or {}

    local key = expansionKey or "midnight"
    local settings = AvidAnglerDB.settings.expansionGuide[key]
    if not settings then
        settings = {}
        AvidAnglerDB.settings.expansionGuide[key] = settings
    end

    if key == "midnight" and settings.hideCollected == nil then
        local legacy = GetMidnightSettings()
        if legacy.hideCollected ~= nil then
            settings.hideCollected = legacy.hideCollected and true or false
        end
    end

    AvidAngler.DB = AvidAnglerDB
    return settings
end

local function NormalizeText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("^recipe:%s*", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function GetCollectibleCacheKey(row, trackType)
    if not row then
        return nil
    end
    local id = row.itemID or row.sourceItemID or row.recipeItemID
    if id then
        return (trackType or row.trackType or "item") .. ":" .. tostring(id)
    end
    if row.name then
        return (trackType or row.trackType or "item") .. ":name:" .. NormalizeText(row.name)
    end
    return nil
end

local function GetCollectibleCacheBucket(trackType)
    AvidAnglerDB = AvidAnglerDB or {}
    AvidAnglerDB.collectibleCache = AvidAnglerDB.collectibleCache or {}
    AvidAnglerDB.collectibleCache.account = AvidAnglerDB.collectibleCache.account or {}
    AvidAnglerDB.collectibleCache.characters = AvidAnglerDB.collectibleCache.characters or {}
    AvidAngler.DB = AvidAnglerDB

    if trackType == "recipe" then
        local characterKey = AvidAngler.GetCurrentCharacterKey and AvidAngler:GetCurrentCharacterKey()
        if not characterKey then
            return nil
        end
        local characters = AvidAnglerDB.collectibleCache.characters
        characters[characterKey] = characters[characterKey] or {}
        return characters[characterKey]
    end

    return AvidAnglerDB.collectibleCache.account
end

local function ReadCachedCollectible(row, trackType)
    local bucket = GetCollectibleCacheBucket(trackType)
    local key = GetCollectibleCacheKey(row, trackType)
    local entry = bucket and key and bucket[key]
    if type(entry) == "table" and entry.collected then
        if trackType == "appearance" and not entry.appearanceLearned then return nil end
        return true
    end
    return nil
end

local function CacheCollected(row, trackType, status)
    local bucket = GetCollectibleCacheBucket(trackType)
    local key = GetCollectibleCacheKey(row, trackType)
    if not bucket or not key then
        return
    end
    bucket[key] = {
        collected = true,
        appearanceLearned = trackType == "appearance" or nil,
        status = status,
        name = row and row.name or nil,
        trackType = trackType,
        updatedAt = time(),
    }
end

local function ResolveCollectedStatus(row, trackType, liveValue, positiveStatus, negativeStatus)
    if liveValue == true then
        CacheCollected(row, trackType, positiveStatus)
        return positiveStatus, true
    end
    if ReadCachedCollectible(row, trackType) then
        return positiveStatus, true
    end
    if liveValue == false then
        return negativeStatus, false
    end
    return nil, nil
end

local function ResolvePositiveOnlyStatus(row, trackType, liveValue, positiveStatus)
    if liveValue == true then
        CacheCollected(row, trackType, positiveStatus)
        return positiveStatus, true
    end
    if ReadCachedCollectible(row, trackType) then
        return positiveStatus, true
    end
    return nil, nil
end

local function IsMountCollected(itemID)
    if not itemID or not C_MountJournal or type(C_MountJournal.GetMountFromItem) ~= "function" then
        return nil
    end
    local mountID = AvidAngler:SafeCall(C_MountJournal.GetMountFromItem, nil, itemID)
    if not mountID or type(C_MountJournal.GetMountInfoByID) ~= "function" then
        return nil
    end
    local ok, _, _, _, _, _, _, _, _, _, _, isCollected = pcall(C_MountJournal.GetMountInfoByID, mountID)
    if not ok then
        return nil
    end
    return isCollected and true or false
end

local function IsPetCollected(itemID)
    if not C_PetJournal then
        return nil
    end

    if itemID and type(C_PetJournal.GetPetInfoByItemID) == "function" and type(C_PetJournal.GetNumCollectedInfo) == "function" then
        local ok, first, _, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
        if not ok then
            first = nil
            speciesID = nil
        end
        speciesID = tonumber(speciesID) or tonumber(first)
        if speciesID then
            local owned = AvidAngler:SafeCall(C_PetJournal.GetNumCollectedInfo, 0, speciesID)
            if owned ~= nil then
                return (tonumber(owned) or 0) > 0
            end
        end
    end

    return nil
end

local function IsPetNameCollected(petName)
    if not petName or not C_PetJournal or type(C_PetJournal.GetNumPets) ~= "function" or type(C_PetJournal.GetPetInfoByIndex) ~= "function" then
        return nil
    end

    if type(C_PetJournal.FindPetIDByName) == "function" then
        local petID = AvidAngler:SafeCall(C_PetJournal.FindPetIDByName, nil, petName)
        if petID then
            return true
        end
    end

    local count = AvidAngler:SafeCall(C_PetJournal.GetNumPets, 0, false) or 0
    if count <= 0 then
        count = AvidAngler:SafeCall(C_PetJournal.GetNumPets, 0) or 0
    end

    local wanted = NormalizeText(petName)
    local matched = false
    for index = 1, count do
        local ok, petID, speciesID, isOwned, customName, level, favorite, isRevoked, name = pcall(C_PetJournal.GetPetInfoByIndex, index)
        if ok then
            local candidate = name or customName
            if candidate and NormalizeText(candidate) == wanted then
                matched = true
                if isOwned or petID then
                    return true
                end
            end
        end
    end

    if matched then
        return false
    end
    return nil
end

local function IsToyCollected(itemID)
    if not itemID or not C_ToyBox or type(C_ToyBox.PlayerHasToy) ~= "function" then
        return nil
    end
    local collected = AvidAngler:SafeCall(C_ToyBox.PlayerHasToy, nil, itemID)
    if collected == nil then
        return nil
    end
    return collected and true or false
end

local function IsHousingDecor(row)
    local kind = row and row.kind and tostring(row.kind):lower() or ""
    return kind:find("housing", 1, true) or kind:find("decor", 1, true)
end

local DECOR_IDS_BY_ITEM = {
    [277923] = 25299,
    [277931] = 26197,
    [277927] = 25336,
}

local function EntryMatchesCollectible(row, key, value)
    if not row then
        return false, false
    end

    local itemID = tonumber(row.itemID)
    local name = row.name and NormalizeText(row.name) or nil
    if itemID and (key == itemID or value == itemID) then
        return true, true
    end

    if type(value) ~= "table" then
        return false, false
    end

    local ids = {
        value.itemID,
        value.itemId,
        value.itemIDRaw,
        value.sourceItemID,
        value.sourceItemId,
        value.id,
        value.decorID,
        value.decorationID,
        value.housingItemID,
    }
    for _, candidate in ipairs(ids) do
        if itemID and tonumber(candidate) == itemID then
            return true, true
        end
    end

    local names = {
        value.name,
        value.itemName,
        value.decorName,
        value.decorationName,
        value.displayName,
    }
    for _, candidate in ipairs(names) do
        if candidate and name then
            return NormalizeText(candidate) == name, true
        end
    end

    return false, false
end

local function ScanHousingCollection(row, collection)
    if type(collection) ~= "table" then
        return false, false
    end

    local inspected = false
    for key, value in pairs(collection) do
        local matched, inspectable = EntryMatchesCollectible(row, key, value)
        inspected = inspected or inspectable
        if matched then
            return true, true
        end
    end
    return false, inspected
end

local function ReadHousingInfo(row, functionName)
    local housing = C_HousingDecor or C_Housing
    if not housing or type(housing[functionName]) ~= "function" then
        return nil
    end

    return AvidAngler:SafeCall(housing[functionName], nil, row.itemID)
end

local function ScanPlacedHousingDecor(row)
    if not row or not row.name or not C_HousingDecor or type(C_HousingDecor.GetAllPlacedDecor) ~= "function" or type(C_HousingDecor.GetDecorName) ~= "function" then
        return nil
    end

    local placed = AvidAngler:SafeCall(C_HousingDecor.GetAllPlacedDecor, nil)
    if type(placed) ~= "table" then
        return nil
    end

    local wanted = NormalizeText(row.name)
    for key, value in pairs(placed) do
        local candidates = { key, value }
        if type(value) == "table" then
            candidates[#candidates + 1] = value.guid
            candidates[#candidates + 1] = value.decorGUID
            candidates[#candidates + 1] = value.decorGuid
        end
        for _, decorGUID in ipairs(candidates) do
            local name = AvidAngler:SafeCall(C_HousingDecor.GetDecorName, nil, decorGUID)
            if name and NormalizeText(name) == wanted then
                return true
            end
        end
    end
    return nil
end

local function IsHousingDecorCollected(row)
    local housing = C_HousingDecor or C_Housing
    if not row or not row.itemID then
        return nil
    end

    local decorID = row.decorID or DECOR_IDS_BY_ITEM[tonumber(row.itemID)]
    if decorID and C_HousingCatalog and type(C_HousingCatalog.GetCatalogEntryInfoByRecordID) == "function" then
        local entryType = Enum and Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Decor or 1
        local info = AvidAngler:SafeCall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, nil, entryType, decorID, true)
        if type(info) == "table" then
            if info.firstAcquisitionBonus == 0 then
                return true, true
            end
            if (tonumber(info.quantity) or 0) > 0 or (tonumber(info.remainingRedeemable) or 0) > 0 or (tonumber(info.numPlaced) or 0) > 0 then
                return true, true
            end
            return false, true
        end
    end

    if not housing then
        return nil
    end

    local placed = ScanPlacedHousingDecor(row)
    if placed then
        return true, true
    end

    local booleanFunctions = {
        "IsDecorCollected",
        "IsDecorUnlocked",
        "IsDecorationCollected",
        "IsDecorationUnlocked",
        "PlayerHasDecor",
        "PlayerHasDecoration",
        "HasDecor",
        "HasDecoration",
    }
    for _, functionName in ipairs(booleanFunctions) do
        if type(housing[functionName]) == "function" then
            local collected = AvidAngler:SafeCall(housing[functionName], nil, row.itemID)
            if collected ~= nil then
                return collected and true or false, collected == true
            end
        end
    end

    local directFunctions = {
        "GetDecorInfoByItemID",
        "GetDecorationInfoByItemID",
        "GetItemInfo",
        "GetHousingItemInfo",
        "GetDecorInfoForItem",
        "GetDecorInfoByItem",
        "GetDecorationInfoForItem",
    }
    for _, functionName in ipairs(directFunctions) do
        local info = ReadHousingInfo(row, functionName)
        if type(info) == "table" then
            local owned = info.isOwned
            if owned == nil then
                owned = info.owned
            end
            if owned == nil then
                owned = info.unlocked
            end
            if owned ~= nil then
                return owned and true or false, owned == true
            end
        end
    end

    local collectionFunctions = {
        "GetOwnedItems",
        "GetOwnedDecorations",
        "GetAllOwnedDecorations",
        "GetDecorations",
        "GetOwnedDecor",
        "GetCollectedDecor",
        "GetUnlockedDecor",
        "GetDecorCollection",
    }
    local inspected = false
    for _, functionName in ipairs(collectionFunctions) do
        if type(housing[functionName]) == "function" then
            local collection = AvidAngler:SafeCall(housing[functionName], nil)
            local matched, inspectable = ScanHousingCollection(row, collection)
            inspected = inspected or inspectable
            if matched then
                return true, true
            end
        end
    end

    if inspected then
        return false, false
    end
    return nil
end

local function GetRecipeName(row)
    if row.recipeName then
        return row.recipeName
    end
    if row.source and row.source:find("^Recipe:") then
        return row.source:gsub("^Recipe:%s*", "")
    end
    if row.name and row.name:find("^Recipe:") then
        return row.name:gsub("^Recipe:%s*", "")
    end
    return nil
end

local function IsRecipeKnown(row)
    local recipeName = GetRecipeName(row)
    if not recipeName or not C_TradeSkillUI then
        return nil
    end
    if type(C_TradeSkillUI.GetAllRecipeIDs) ~= "function" or type(C_TradeSkillUI.GetRecipeInfo) ~= "function" then
        return nil
    end

    local recipeIDs = AvidAngler:SafeCall(C_TradeSkillUI.GetAllRecipeIDs, nil)
    if type(recipeIDs) ~= "table" or not next(recipeIDs) then
        return nil
    end

    local wanted = NormalizeText(recipeName)
    for _, recipeID in ipairs(recipeIDs) do
        local info = AvidAngler:SafeCall(C_TradeSkillUI.GetRecipeInfo, nil, recipeID)
        local name = info and (info.name or info.recipeName)
        if name and NormalizeText(name) == wanted then
            if info.learned == false then
                return false
            end
            return true
        end
    end
    return false
end

local function IsAppearanceCollected(itemID)
    if not itemID or not C_TransmogCollection
        or (AvidAngler.IsRuntimeDisabled and AvidAngler:IsRuntimeDisabled()) then
        return nil
    end
    local api = C_TransmogCollection
    if AvidAngler:SafeCall(api.PlayerHasTransmog, nil, itemID) == true
        or AvidAngler:SafeCall(api.PlayerHasTransmogByItemInfo, nil, itemID) == true then
        return true
    end
    if type(api.GetItemInfo) ~= "function" then return nil end
    local ok, appearanceID, sourceID = pcall(api.GetItemInfo, itemID)
    if not ok then return nil end
    appearanceID = AvidAngler:SafeNumber(appearanceID, nil)
    sourceID = AvidAngler:SafeNumber(sourceID, nil)
    if sourceID and AvidAngler:SafeCall(api.PlayerHasTransmogItemModifiedAppearance, nil, sourceID) == true then
        return true
    end
    if not appearanceID or appearanceID <= 0 then return nil end
    -- All sources avoids wardrobe display filters and includes identical looks
    -- learned through another item. Missing data is not proof of a missing look.
    local sources = AvidAngler:SafeCall(api.GetAllAppearanceSources, nil, appearanceID)
    if type(sources) == "table" and next(sources) then
        local complete = true
        for _, id in pairs(sources) do
            id = AvidAngler:SafeNumber(id, nil)
            local collected = id and AvidAngler:SafeCall(api.PlayerHasTransmogItemModifiedAppearance, nil, id)
            if collected == true then return true end
            if collected ~= false then complete = false end
        end
        if complete then return false end
    end
    local visibleSources = AvidAngler:SafeCall(api.GetAppearanceSources, nil, appearanceID)
    if type(visibleSources) == "table" then
        for _, source in pairs(visibleSources) do
            if not AvidAngler:IsSecretValue(source) and type(source) == "table"
                and not AvidAngler:IsSecretValue(source.isCollected) and source.isCollected == true then
                return true
            end
        end
    end
    return nil
end

local function GetStatus(row)
    local trackType = row.trackType
    if not trackType and row.kind then
        local kind = tostring(row.kind):lower()
        if kind:find("transmog", 1, true) or kind:find("cosmetic", 1, true) then
            trackType = "appearance"
        elseif kind:find("mount", 1, true) then
            trackType = "mount"
        elseif kind:find("pet", 1, true) or kind:find("companion", 1, true) then
            trackType = "pet"
        elseif kind:find("toy", 1, true) then
            trackType = "toy"
        end
    end

    if IsHousingDecor(row) then
        local collected, reliable = IsHousingDecorCollected(row)
        if collected == true then
            CacheCollected(row, "housing", L["MIDNIGHT_STATUS_OWNED"])
            return L["MIDNIGHT_STATUS_OWNED"], true
        end
        local cachedStatus = ReadCachedCollectible(row, "housing")
        if cachedStatus then
            return cachedStatus, true
        end
        if reliable and collected == false then
            return L["MIDNIGHT_STATUS_MISSING"], false
        end
        if HasOwnedItem(row.itemID) then
            CacheCollected(row, "housing", L["MIDNIGHT_STATUS_OWNED"])
            return L["MIDNIGHT_STATUS_OWNED"], true
        end
        return L["MIDNIGHT_STATUS_UNKNOWN"], nil
    end

    if trackType == "recipe" then
        local known = IsRecipeKnown(row)
        local status, positive = ResolveCollectedStatus(row, trackType, known, L["MIDNIGHT_STATUS_KNOWN"], L["MIDNIGHT_STATUS_MISSING"])
        if status then
            return status, positive
        end

        local recipeItemID = tonumber(row.sourceItemID) or row.recipeItemID
        if HasOwnedItem(recipeItemID or row.itemID) then
            return L["MIDNIGHT_STATUS_IN_BAGS"], true
        end
        return L["MIDNIGHT_STATUS_UNKNOWN"], nil
    elseif trackType == "appearance" then
        local collected = IsAppearanceCollected(row.itemID)
        local status, positive = ResolveCollectedStatus(row, trackType, collected, L["MIDNIGHT_STATUS_COLLECTED"], L["MIDNIGHT_STATUS_MISSING"])
        if status then
            return status, positive
        end
        return L["MIDNIGHT_STATUS_UNKNOWN"], nil
    elseif trackType == "mount" then
        local collected = IsMountCollected(row.itemID)
        local status, positive = ResolveCollectedStatus(row, trackType, collected, L["MIDNIGHT_STATUS_COLLECTED"], L["MIDNIGHT_STATUS_MISSING"])
        if status then
            return status, positive
        end
    elseif trackType == "pet" then
        local collected = IsPetCollected(row.itemID)
        if collected == nil then
            collected = IsPetNameCollected(row.name)
        end
        local status, positive = ResolveCollectedStatus(row, trackType, collected, L["MIDNIGHT_STATUS_COLLECTED"], L["MIDNIGHT_STATUS_MISSING"])
        if status then
            return status, positive
        end
    elseif trackType == "toy" then
        local collected = IsToyCollected(row.itemID)
        local status, positive = ResolveCollectedStatus(row, trackType, collected, L["MIDNIGHT_STATUS_COLLECTED"], L["MIDNIGHT_STATUS_MISSING"])
        if status then
            return status, positive
        end
    end

    if HasOwnedItem(row.itemID) then
        CacheCollected(row, trackType or "item", L["MIDNIGHT_STATUS_OWNED"])
        return L["MIDNIGHT_STATUS_OWNED"], true
    end
    if row.itemID then
        return trackType and L["MIDNIGHT_STATUS_MISSING"] or L["MIDNIGHT_STATUS_NOT_SEEN"], false
    end
    return L["MIDNIGHT_STATUS_INFO"], nil
end

local function ShouldShowCollectibleRow(row)
    if not row then
        return false
    end
    if IsAccessoryInfoRow(row) then
        return false
    end
    return row.acquisition ~= "CraftedFromFishedRecipe"
end

local function ShouldShowGuideRow(screenKey, row, expansionKey)
    if not row then
        return false
    end
    if screenKey == "lures" then
        if IsAccessoryInfoRow(row) then
            return false
        end

        if IsExcludedLureRow(row, expansionKey) then
            return false
        end

        local kind = NormalizeText(row.kind)
        return not kind:find("creature lure", 1, true)
            and not kind:find("creature bait", 1, true)
    end
    if screenKey ~= "pools" then
        return true
    end

    local name = NormalizeText(row.name)
    local fishingSource = NormalizeText(row.fishingSource)
    return name ~= "open water"
        and name ~= "all pools"
        and name ~= "no specific pool confirmed"
        and fishingSource ~= "openwater"
        and fishingSource ~= "allpools"
        and fishingSource ~= "openwaterorspecial"
end

local LocalizeCatalogDisplayText

local function GetDisplayKind(screenKey, row)
    local kind = row and row.kind or ""
    if screenKey == "accessories" then
        local normalizedKind = NormalizeText(kind)
        if normalizedKind:find("profession / quest item", 1, true) then
            return L["MIDNIGHT_KIND_PROFESSION_QUEST_ITEM"] or "Profession / quest item"
        end
        if normalizedKind:find("fishing", 1, true) or normalizedKind:find("permanent fishing line", 1, true) then
            return L["MIDNIGHT_KIND_FISHING_EQUIPMENT"] or "Fishing Equipment"
        end
    end
    return LocalizeCatalogDisplayText(kind)
end

local CATALOG_DISPLAY_KEYS = {
    ["anti-lure recipe fished from treasure pools"] = "EXPANSION_GUIDE_ANTI_LURE_RECIPE_TREASURE_POOLS",
    ["ability unlock / find fish"] = "EXPANSION_GUIDE_ABILITY_UNLOCK_FIND_FISH",
    ["book / fishing unlock"] = "MIDNIGHT_KIND_BOOK_FISHING_UNLOCK",
    ["baby crocolisk pet buckets from the outland fishing daily reward bag."] = "EXPANSION_GUIDE_OUTLAND_CROCOLISK_PET_BUCKETS",
    ["can drop from fishing containers; teaches find fish / angler's guide path may replace this in newer content"] = "EXPANSION_GUIDE_FIND_FISH_CONTAINER_CONDITIONS",
    ["captain tokka reputation, coiled filament, unique fish, midnight fishing fragments"] = "EXPANSION_GUIDE_CAPTAIN_TOKKA_REPUTATION",
    ["cataclysm fishing lure"] = "EXPANSION_GUIDE_CATACLYSM_FISHING_LURE",
    ["coiled filament / voidlight marl / cursed fishing"] = "EXPANSION_GUIDE_COILED_FILAMENT_VOIDLIGHT_CURSED",
    ["container"] = "MIDNIGHT_KIND_CONTAINER",
    ["currency item"] = "MIDNIGHT_KIND_CURRENCY_ITEM",
    ["cursedfishingpool"] = "EXPANSION_GUIDE_CURSED_FISHING_POOL",
    ["cursed fishing / open sea fishing / midnight zones"] = "EXPANSION_GUIDE_CURSED_OPEN_SEA_MIDNIGHT",
    ["dragonflight fish lure"] = "EXPANSION_GUIDE_DRAGONFLIGHT_FISH_LURE",
    ["fish"] = "MIDNIGHT_KIND_FISH",
    ["fish/farm nether-warped egg, then wait for hatch"] = "EXPANSION_GUIDE_FISH_FARM_NETHER_EGG",
    ["fish-specific lure"] = "MIDNIGHT_KIND_FISH_SPECIFIC_LURE",
    ["fishing daily lure"] = "EXPANSION_GUIDE_FISHING_DAILY_LURE",
    ["fishing daily quest reward bag"] = "EXPANSION_GUIDE_FISHING_DAILY_REWARD_BAG",
    ["fishing and/or patient treasure chests; boe appearances"] = "EXPANSION_GUIDE_FISHING_PATIENT_BOE",
    ["fishing accessory"] = "MIDNIGHT_KIND_FISHING_EQUIPMENT",
    ["fishing equipment"] = "MIDNIGHT_KIND_FISHING_EQUIPMENT",
    ["fishing gear"] = "EXPANSION_GUIDE_FISHING_GEAR",
    ["fishing gear material"] = "EXPANSION_GUIDE_FISHING_GEAR_MATERIAL",
    ["fishing harpoon upgrade"] = "EXPANSION_GUIDE_FISHING_HARPOON_UPGRADE",
    ["fishing in midnight"] = "EXPANSION_GUIDE_FISHING_IN_MIDNIGHT",
    ["fishing lure"] = "MIDNIGHT_KIND_FISH_LURE",
    ["fishing lure reference"] = "EXPANSION_GUIDE_FISHING_LURE_REFERENCE",
    ["fishing net upgrade"] = "EXPANSION_GUIDE_FISHING_NET_UPGRADE",
    ["fishing pools"] = "EXPANSION_GUIDE_FISHING_POOLS",
    ["fishing pools and trunks"] = "EXPANSION_GUIDE_FISHING_POOLS_TRUNKS",
    ["fishing pole skill utility item; shown as accessory reference rather than a fish-targeting lure."] = "EXPANSION_GUIDE_POLE_SKILL_UTILITY_NOTE",
    ["fishing skill item"] = "EXPANSION_GUIDE_FISHING_SKILL_ITEM",
    ["fishing spot unlock"] = "EXPANSION_GUIDE_FISHING_SPOT_UNLOCK",
    ["fishing trunks / crates"] = "EXPANSION_GUIDE_FISHING_TRUNKS_CRATES",
    ["fishing utility item"] = "EXPANSION_GUIDE_FISHING_UTILITY_ITEM",
    ["reusable fishing item"] = "COLLECTIBLE_REUSABLE_FISHING_ITEM",
    ["hallowfall fishing derby / careless dasher treasure"] = "EXPANSION_GUIDE_HALLOWFALL_DERBY_TREASURE",
    ["housing decor"] = "MIDNIGHT_KIND_HOUSING_DECOR",
    ["included because it unlocks fish school tracking and is commonly needed by fishing addons."] = "EXPANSION_GUIDE_FIND_FISH_CATALOG_NOTE",
    ["increases midnight fishing skill by 10; save for higher skill levels."] = "EXPANSION_GUIDE_INCREASES_MIDNIGHT_FISHING_SKILL",
    ["lure recipe fished from treasure pools"] = "EXPANSION_GUIDE_LURE_RECIPE_TREASURE_POOLS",
    ["midnight fishing / patient treasure"] = "EXPANSION_GUIDE_MIDNIGHT_FISHING_PATIENT_TREASURE",
    ["midnight fish lure"] = "EXPANSION_GUIDE_MIDNIGHT_FISH_LURE",
    ["midnight fish lure; itemeffect spell currently named torrential gorgerswarm"] = "EXPANSION_GUIDE_MIDNIGHT_FISH_LURE_ITEMEFFECT_GORGERSWARM",
    ["midnight fishing-related reward; some line fragments are fishable in midnight zones, while mount/cosmetics require captain tokka progression and fishing currency."] = "EXPANSION_GUIDE_MIDNIGHT_TOKKA_REWARD_NOTE",
    ["midnight lure"] = "EXPANSION_GUIDE_MIDNIGHT_LURE",
    ["midnight lure; no direct effect found in itemeffect"] = "EXPANSION_GUIDE_MIDNIGHT_LURE_NO_ITEMEFFECT",
    ["midnight zones"] = "EXPANSION_GUIDE_MIDNIGHT_ZONES",
    ["mount"] = "MIDNIGHT_KIND_MOUNT",
    ["mount starter item"] = "MIDNIGHT_KIND_MOUNT_STARTER_ITEM",
    ["no fish mapping yet"] = "EXPANSION_GUIDE_NO_FISH_MAPPING",
    ["one-hand mace; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_ONE_HAND_MACE_NOTE",
    ["one-hand mace/fist appearance; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_ONE_HAND_MACE_FIST_NOTE",
    ["one-hand sword; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_ONE_HAND_SWORD_NOTE",
    ["open water"] = "EXPANSION_GUIDE_OPEN_WATER",
    ["open water / special"] = "EXPANSION_GUIDE_OPEN_WATER_SPECIAL",
    ["openwater"] = "EXPANSION_GUIDE_OPEN_WATER",
    ["openwaterorspecial"] = "EXPANSION_GUIDE_OPEN_WATER_SPECIAL",
    ["open-water row included so addon logic can distinguish pool targeting from non-pool catches.; cursed fishing species; mapped to the midnight cursed pool currently in the pool object csv."] = "EXPANSION_GUIDE_OPEN_WATER_CURSED_POOL_NOTE",
    ["outland and later eligible fishing containers"] = "EXPANSION_GUIDE_OUTLAND_FISHING_CONTAINERS",
    ["outland fishing daily"] = "EXPANSION_GUIDE_OUTLAND_FISHING_DAILY",
    ["patient treasure / open water"] = "EXPANSION_GUIDE_PATIENT_TREASURE_OPEN_WATER",
    ["patient treasure chests or open-water fishing"] = "EXPANSION_GUIDE_PATIENT_TREASURE_OPEN_WATER_FISHING",
    ["pool"] = "MIDNIGHT_KIND_POOL",
    ["pole skill lure"] = "EXPANSION_GUIDE_POLE_SKILL_LURE",
    ["pole skill lure / fishing accessory"] = "EXPANSION_GUIDE_POLE_SKILL_LURE_ACCESSORY",
    ["pole skill utility item"] = "EXPANSION_GUIDE_POLE_SKILL_UTILITY_ITEM",
    ["profession / quest item"] = "MIDNIGHT_KIND_PROFESSION_QUEST_ITEM",
    ["profession tool / fishing pole"] = "EXPANSION_GUIDE_PROFESSION_TOOL_POLE",
    ["primarily careless cargo and lost treasures; also patient treasure chests"] = "EXPANSION_GUIDE_PRIMARILY_TREASURE_POOLS",
    ["random patient treasure chest while fishing"] = "EXPANSION_GUIDE_RANDOM_PATIENT_TREASURE",
    ["recipe"] = "MIDNIGHT_KIND_RECIPE",
    ["static treasure related to fishing"] = "EXPANSION_GUIDE_STATIC_FISHING_TREASURE",
    ["staff; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_STAFF_NOTE",
    ["staff/polearm appearance; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_STAFF_POLEARM_NOTE",
    ["transmog / cosmetic"] = "MIDNIGHT_KIND_TRANSMOG_COSMETIC",
    ["transmog / lost weapon appearance"] = "MIDNIGHT_KIND_LOST_WEAPON_APPEARANCE",
    ["transmog ensemble"] = "MIDNIGHT_KIND_TRANSMOG_ENSEMBLE",
    ["two-hand axe; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_TWO_HAND_AXE_NOTE",
    ["two-hand sword; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_TWO_HAND_SWORD_NOTE",
    ["two-hand weapon; boe fishing-exclusive lost appearance listed by wowhead."] = "EXPANSION_GUIDE_LOST_TWO_HAND_WEAPON_NOTE",
    ["treasure fishing pools"] = "EXPANSION_GUIDE_TREASURE_POOLS",
    ["treasure fishing pools and patient treasure chests"] = "EXPANSION_GUIDE_TREASURE_POOLS_PATIENT_CHESTS",
    ["treasure pool"] = "EXPANSION_GUIDE_TREASURE_POOL",
    ["tww fish lure"] = "EXPANSION_GUIDE_TWW_FISH_LURE",
    ["wait 7 days after nether-warped egg"] = "EXPANSION_GUIDE_WAIT_7_DAYS_NETHER_EGG",
}

function LocalizeCatalogDisplayText(text)
    if not text or text == "" then
        return text or ""
    end

    local normalized = NormalizeText(text)
    local key = CATALOG_DISPLAY_KEYS[normalized]
    if key and L[key] then
        return L[key]
    end

    if tostring(text):find(";", 1, true) then
        local changed = false
        local localizedValues = {}
        for value in tostring(text):gmatch("[^;]+") do
            local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
            local tokenKey = CATALOG_DISPLAY_KEYS[NormalizeText(trimmed)]
            if tokenKey and L[tokenKey] then
                localizedValues[#localizedValues + 1] = L[tokenKey]
                changed = true
            else
                localizedValues[#localizedValues + 1] = trimmed
            end
        end
        if changed then
            return table.concat(localizedValues, "; ")
        end
    end

    local best = tostring(text):match("^%s*Best:%s*(.+)$")
    if best then
        return ("%s %s"):format(L["EXPANSION_GUIDE_BEST_PREFIX"] or "Best:", LocalizeCatalogDisplayText(best))
    end

    local fishCount = tostring(text):match("^%s*Fish:%s*(%d+)%s+fish%s*$")
    if fishCount then
        return (L["EXPANSION_GUIDE_FISH_COUNT_DETAIL"] or "Fish: %d fish"):format(tonumber(fishCount) or 0)
    end

    local fishList = tostring(text):match("^%s*Fish:%s*(.+)$")
    if fishList then
        return ("%s %s"):format(L["EXPANSION_GUIDE_FISH_PREFIX"] or "Fish:", fishList)
    end

    return text
end

local function CountDelimitedValues(text)
    local count = 0
    for value in tostring(text or ""):gmatch("[^;]+") do
        if value:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
            count = count + 1
        end
    end
    return count
end

local function GetCardDetail(screenKey, row)
    if not row then
        return ""
    end
    if screenKey == "pools" and row.target then
        local count = CountDelimitedValues(row.target)
        if count > 4 then
            return (L["EXPANSION_GUIDE_FISH_COUNT_DETAIL"] or "Fish: %d fish"):format(count)
        end
    end
    return LocalizeCatalogDisplayText(row.detail or row.fishingSource or row.areas or row.source or "")
end

local function BuildDisplayRows(self, screenKey)
    local displayRows = {}
    for _, row in ipairs(GetScreenRows(screenKey, self.expansionKey)) do
        if ShouldShowGuideRow(screenKey, row, self.expansionKey) and (screenKey ~= "collectibles" or ShouldShowCollectibleRow(row)) then
            local status, positive = "", nil
            if screenKey ~= "fish" and screenKey ~= "grandline" and screenKey ~= "pools" and screenKey ~= "lures" and screenKey ~= "accessories" then
                status, positive = GetStatus(row)
            end
            if screenKey ~= "collectibles" or not self.hideCollected or positive ~= true then
                displayRows[#displayRows + 1] = {
                    row = row,
                    status = status,
                    positive = positive,
                }
            end
        end
    end
    return displayRows
end

local function HasVisibleRows(self, screenKey)
    return #BuildDisplayRows(self, screenKey) > 0
end

function ExpansionGuide:HasVisibleRows(screenKey, expansionKey)
    local previousExpansionKey = self.expansionKey
    if expansionKey then
        self.expansionKey = expansionKey
    end
    local visible = HasVisibleRows(self, screenKey)
    self.expansionKey = previousExpansionKey
    return visible
end

local function SetButtonSelected(button, selected)
    if button and button.SetSelected then
        button:SetSelected(selected and true or false)
    end
end

local function LayoutNav(self)
    local previous
    local isMidnight = self.expansionKey == "midnight"
    local nav = isMidnight
        and { "overview", "score", "fish", "pools", "lures", "accessories", "collectibles", "grandline" }
        or { "overview", "fish", "pools" }

    if not isMidnight and HasVisibleRows(self, "lures") then
        nav[#nav + 1] = "lures"
    end
    if not isMidnight then
        nav[#nav + 1] = "accessories"
        nav[#nav + 1] = "collectibles"
    end
    nav[#nav + 1] = "achievements"

    for key, button in pairs(self.buttons or {}) do
        button:SetShown(false)
    end

    for index, key in ipairs(nav) do
        local button = self.buttons[key]
        if button then
            button:ClearAllPoints()
            if index == 1 then
                button:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", 0, -16)
            else
                button:SetPoint("LEFT", previous, "RIGHT", Theme.layout.gutter, 0)
            end
            button:SetShown(true)
            previous = button
        end
    end
end

local function AddTooltipLine(label, value)
    if not value or value == "" then
        return
    end
    GameTooltip:AddLine(label, unpack(Theme.color.accent))
    GameTooltip:AddLine(value, 0.8, 0.8, 0.8, true)
end

local function ShowCardTooltip(card)
    local row = card and card.row
    if not row then
        return
    end
    local isGeneratedGuideRow = row.sourceLabel == "MIDNIGHT_TOOLTIP_SOURCE_TYPE" or row.sourceLabel == "MIDNIGHT_TOOLTIP_MAPPING"

    local itemInfo = GetItemInfo(row.itemID)
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    if row.itemTooltip and row.itemID and type(GameTooltip.SetHyperlink) == "function" then
        GameTooltip:SetHyperlink("item:" .. row.itemID)
    else
        local titleColor = Theme.color.textPrimary
        local qualityColor = itemInfo and itemInfo.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemInfo.quality]
        if qualityColor then
            if qualityColor.GetRGB then
                GameTooltip:AddLine((itemInfo and itemInfo.name) or row.name or "", qualityColor:GetRGB())
            else
                GameTooltip:AddLine((itemInfo and itemInfo.name) or row.name or "", qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1)
            end
        else
            GameTooltip:AddLine((itemInfo and itemInfo.name) or row.name or "", unpack(titleColor))
        end
    end
    if row.kind then
        GameTooltip:AddLine(LocalizeCatalogDisplayText(row.kind), unpack(Theme.color.textSecondary))
    end
    if row.craftStep or row.target or row.source or row.detail then
        GameTooltip:AddLine(" ")
    end
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_CRAFT_STEP"], row.craftStep)
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_TARGET"], row.target)
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_SOURCE"], LocalizeCatalogDisplayText(row.fishingSource or row.source))
    if row.fishingSource and row.source and not isGeneratedGuideRow then
        AddTooltipLine((row.sourceLabel and L[row.sourceLabel]) or L["MIDNIGHT_TOOLTIP_SOURCE_ITEM"], LocalizeCatalogDisplayText(row.source))
    end
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_AREAS"], LocalizeCatalogDisplayText(row.areas))
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_CONDITIONS"], LocalizeCatalogDisplayText(row.conditions))
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_LOCATION"], LocalizeCatalogDisplayText(row.location))
    AddTooltipLine(L["MIDNIGHT_TOOLTIP_NOTES"], LocalizeCatalogDisplayText(row.detail))
    if not isGeneratedGuideRow then
        AddTooltipLine(L["MIDNIGHT_TOOLTIP_CATALOG_NOTES"], LocalizeCatalogDisplayText(row.notes))
    end
    GameTooltip:Show()
end

local function SetButtonEnabled(button, enabled)
    if not button then
        return
    end
    if enabled then
        button:Enable()
        button:SetAlpha(1)
        if button.text then
            button.text:SetTextColor(unpack(Theme.color.textPrimary))
        end
    else
        button:Disable()
        button:SetAlpha(0.55)
        if button.text then
            button.text:SetTextColor(unpack(Theme.color.textDisabled))
        end
    end
end

local function GetPageSize(screenKey)
    if screenKey == "collectibles" or screenKey == "accessories" or screenKey == "grandline" then
        return COLLECTIBLE_PAGE_SIZE
    end
    if screenKey == "fish" or screenKey == "pools" then
        return COLLECTIBLE_PAGE_SIZE
    end
    return CARD_PAGE_SIZE
end

local function GetCurrentPage(self, screenKey, rowCount)
    self.pages = self.pages or {}
    local pageSize = GetPageSize(screenKey)
    local maxPage = math.max(1, math.ceil((rowCount or 0) / pageSize))
    local page = tonumber(self.pages[screenKey]) or 1
    if page < 1 then
        page = 1
    elseif page > maxPage then
        page = maxPage
    end
    self.pages[screenKey] = page
    return page, maxPage
end

local function SetPage(self, direction)
    local rows = BuildDisplayRows(self, self.activeScreen)
    local page, maxPage = GetCurrentPage(self, self.activeScreen, #rows)
    page = page + direction
    if page < 1 then
        page = 1
    elseif page > maxPage then
        page = maxPage
    end
    self.pages[self.activeScreen] = page
    self:Refresh()
end

local function CreateGrandLineItem(parent, itemID)
    local item = CreateFrame("Button", nil, parent)
    item:SetHeight(22)

    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetSize(16, 16)
    item.icon:SetPoint("LEFT", 0, 0)
    item.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    item.text = item:CreateFontString(nil, "ARTWORK")
    item.text:SetFontObject(Theme.font.body)
    item.text:SetPoint("LEFT", item.icon, "RIGHT", 3, 0)
    item.text:SetJustifyH("LEFT")

    item.itemID = itemID
    item:SetScript("OnEnter", function(self)
        ShowItemTooltip(self, self.itemID)
    end)
    item:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return item
end

local function SetGrandLineItem(item, itemID)
    local itemInfo = GetItemInfo(itemID, function(loadedInfo)
        if item.itemID ~= itemID then
            return
        end
        local loadedName = loadedInfo.name or GRAND_LINE_ITEM_NAMES[itemID] or ("item:" .. tostring(itemID))
        item.icon:SetTexture(loadedInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        item.text:SetText(loadedName)
        ApplyItemColor(item.text, loadedInfo or { quality = GRAND_LINE_ITEM_QUALITIES[itemID] })
        item:SetWidth(22 + (item.text:GetStringWidth() or 120))
    end)
    local name = (itemInfo and itemInfo.name) or GRAND_LINE_ITEM_NAMES[itemID] or ("item:" .. tostring(itemID))
    item.itemID = itemID
    item.icon:SetTexture((itemInfo and itemInfo.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
    item.text:SetText(name)
    ApplyItemColor(item.text, itemInfo or { quality = GRAND_LINE_ITEM_QUALITIES[itemID] })
    item:SetWidth(22 + (item.text:GetStringWidth() or 120))
end

local function CreateGrandLineStep(parent)
    local step = CreateFrame("Frame", nil, parent)
    step:SetSize(820, 22)

    step.leftQty = NewLabel(step, "", Theme.font.body, "LEFT", step, "LEFT", 0, 0)
    step.leftQty:SetWidth(42)

    step.leftItem = CreateGrandLineItem(step)
    step.leftItem:SetPoint("LEFT", step.leftQty, "RIGHT", 0, 0)

    step.arrow = NewLabel(step, L["MIDNIGHT_GRAND_LINE_ARROW"], Theme.font.body, "LEFT", step.leftItem, "RIGHT", 6, 0)
    step.arrow:SetWidth(22)

    step.rightQty = NewLabel(step, "", Theme.font.body, "LEFT", step.arrow, "RIGHT", 0, 0)
    step.rightQty:SetWidth(26)

    step.rightItem = CreateGrandLineItem(step)
    step.rightItem:SetPoint("LEFT", step.rightQty, "RIGHT", 0, 0)

    return step
end

local function SetGrandLineStep(step, leftQty, leftItemID, rightQty, rightItemID)
    step.leftQty:SetText(leftQty)
    SetGrandLineItem(step.leftItem, leftItemID)
    step.arrow:ClearAllPoints()
    step.arrow:SetPoint("LEFT", step.leftItem, "RIGHT", 6, 0)
    step.rightQty:ClearAllPoints()
    step.rightQty:SetPoint("LEFT", step.arrow, "RIGHT", 0, 0)
    step.rightQty:SetText(rightQty)
    step.rightItem:ClearAllPoints()
    step.rightItem:SetPoint("LEFT", step.rightQty, "RIGHT", 0, 0)
    SetGrandLineItem(step.rightItem, rightItemID)
end

local function CreateFinalGrandLineStep(parent)
    local step = CreateFrame("Frame", nil, parent)
    step:SetSize(940, 24)

    step.firstQty = NewLabel(step, "1x", Theme.font.body, "LEFT", step, "LEFT", 0, 0)
    step.firstQty:SetWidth(24)
    step.firstItem = CreateGrandLineItem(step)
    step.firstItem:SetPoint("LEFT", step.firstQty, "RIGHT", 0, 0)
    step.plus = NewLabel(step, "+", Theme.font.body, "LEFT", step.firstItem, "RIGHT", 7, 0)
    step.plus:SetWidth(14)
    step.secondQty = NewLabel(step, "1x", Theme.font.body, "LEFT", step.plus, "RIGHT", 0, 0)
    step.secondQty:SetWidth(24)
    step.secondItem = CreateGrandLineItem(step)
    step.secondItem:SetPoint("LEFT", step.secondQty, "RIGHT", 0, 0)
    step.arrow = NewLabel(step, L["MIDNIGHT_GRAND_LINE_ARROW"], Theme.font.body, "LEFT", step.secondItem, "RIGHT", 7, 0)
    step.arrow:SetWidth(22)
    step.finalQty = NewLabel(step, "1x", Theme.font.body, "LEFT", step.arrow, "RIGHT", 0, 0)
    step.finalQty:SetWidth(24)
    step.finalItem = CreateGrandLineItem(step)
    step.finalItem:SetPoint("LEFT", step.finalQty, "RIGHT", 0, 0)

    return step
end

local function SetFinalGrandLineStep(step)
    SetGrandLineItem(step.firstItem, GRAND_LINE_ITEM_IDS.bloom)
    step.plus:ClearAllPoints()
    step.plus:SetPoint("LEFT", step.firstItem, "RIGHT", 7, 0)
    step.secondQty:ClearAllPoints()
    step.secondQty:SetPoint("LEFT", step.plus, "RIGHT", 0, 0)
    step.secondItem:ClearAllPoints()
    step.secondItem:SetPoint("LEFT", step.secondQty, "RIGHT", 0, 0)
    SetGrandLineItem(step.secondItem, GRAND_LINE_ITEM_IDS.glimmer)
    step.arrow:ClearAllPoints()
    step.arrow:SetPoint("LEFT", step.secondItem, "RIGHT", 7, 0)
    step.finalQty:ClearAllPoints()
    step.finalQty:SetPoint("LEFT", step.arrow, "RIGHT", 0, 0)
    step.finalItem:ClearAllPoints()
    step.finalItem:SetPoint("LEFT", step.finalQty, "RIGHT", 0, 0)
    SetGrandLineItem(step.finalItem, GRAND_LINE_ITEM_IDS.final)
end

local function CreateGrandLineShoppingLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(400, 22)

    line.qty = NewLabel(line, "", Theme.font.body, "LEFT", line, "LEFT", 0, 0)
    line.qty:SetWidth(60)
    line.item = CreateGrandLineItem(line)
    line.item:SetPoint("LEFT", line.qty, "RIGHT", 0, 0)

    return line
end

local function SetGrandLineShoppingLine(line, qty, itemID)
    line.qty:SetText(qty)
    SetGrandLineItem(line.item, itemID)
end

local function CreateGrandLineView(self, panel)
    local boxOffsetX = 28
    local contentWidth = 940
    local columnGap = 44
    local columnWidth = 440

    local view = CreateFrame("Frame", nil, panel)
    view:SetPoint("TOPLEFT", self.buttons.overview, "BOTTOMLEFT", 0, -28)
    view:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    view:SetHeight(560)
    view:Hide()

    view.title = NewLabel(view, L["MIDNIGHT_GRAND_LINE_TITLE"], Theme.font.title, "TOPLEFT", view, "TOPLEFT", boxOffsetX, 0)
    view.title:SetJustifyH("CENTER")
    view.title:SetPoint("RIGHT", view, "LEFT", boxOffsetX + contentWidth, 0)

    view.intro = NewLabel(view, L["MIDNIGHT_GRAND_LINE_INTRO"], Theme.font.body, "TOPLEFT", view.title, "BOTTOMLEFT", 0, -28)
    view.intro:SetPoint("RIGHT", view.title, "RIGHT", 0, 0)

    view.howTitle = NewLabel(view, L["MIDNIGHT_GRAND_LINE_HOW_TITLE"], Theme.font.title, "TOPLEFT", view.intro, "BOTTOMLEFT", 0, -40)
    view.howText = NewLabel(view, L["MIDNIGHT_GRAND_LINE_HOW_BODY"], Theme.font.body, "TOPLEFT", view.howTitle, "BOTTOMLEFT", 0, -16)
    view.howText:SetPoint("RIGHT", view.title, "RIGHT", 0, 0)

    view.bloomColumn = Theme:CreatePanel(view, "panel", "border")
    view.bloomColumn:SetPoint("TOPLEFT", view.howText, "BOTTOMLEFT", boxOffsetX, -30)
    view.bloomColumn:SetSize(columnWidth, 132)

    view.glimmerColumn = Theme:CreatePanel(view, "panel", "border")
    view.glimmerColumn:SetPoint("LEFT", view.bloomColumn, "RIGHT", columnGap, 0)
    view.glimmerColumn:SetSize(columnWidth, 132)

    view.bloomTitle = NewLabel(view.bloomColumn, L["MIDNIGHT_GRAND_LINE_BLOOM_TITLE"], Theme.font.heading, "TOPLEFT", view.bloomColumn, "TOPLEFT", 12, -12)
    view.bloomSteps = {}
    for i = 1, 3 do
        local step = CreateGrandLineStep(view.bloomColumn)
        step:SetPoint("TOPLEFT", view.bloomTitle, "BOTTOMLEFT", 0, -12 - ((i - 1) * 24))
        view.bloomSteps[i] = step
    end

    view.glimmerTitle = NewLabel(view.glimmerColumn, L["MIDNIGHT_GRAND_LINE_GLIMMER_TITLE"], Theme.font.heading, "TOPLEFT", view.glimmerColumn, "TOPLEFT", 12, -12)
    view.glimmerSteps = {}
    for i = 1, 3 do
        local step = CreateGrandLineStep(view.glimmerColumn)
        step:SetPoint("TOPLEFT", view.glimmerTitle, "BOTTOMLEFT", 0, -12 - ((i - 1) * 24))
        view.glimmerSteps[i] = step
    end

    view.finalPanel = Theme:CreatePanel(view, "panel", "border")
    view.finalPanel:SetPoint("TOPLEFT", view.bloomColumn, "BOTTOMLEFT", 0, -36)
    view.finalPanel:SetSize(contentWidth, 74)
    view.finalTitle = NewLabel(view.finalPanel, L["MIDNIGHT_GRAND_LINE_FINAL_TITLE"], Theme.font.heading, "TOPLEFT", view.finalPanel, "TOPLEFT", 12, -12)
    view.finalStep = CreateFinalGrandLineStep(view.finalPanel)
    view.finalStep:SetPoint("TOPLEFT", view.finalTitle, "BOTTOMLEFT", 0, -12)

    view.shoppingPanel = Theme:CreatePanel(view, "panel", "border")
    view.shoppingPanel:SetPoint("TOPLEFT", view.finalPanel, "BOTTOMLEFT", 0, -20)
    view.shoppingPanel:SetSize(contentWidth, 116)
    view.shoppingTitle = NewLabel(view.shoppingPanel, L["MIDNIGHT_GRAND_LINE_SHOPPING_TITLE"], Theme.font.heading, "TOPLEFT", view.shoppingPanel, "TOPLEFT", 12, -12)
    view.shoppingHint = NewLabel(view.shoppingPanel, L["MIDNIGHT_GRAND_LINE_SHOPPING_DESC"], Theme.font.muted, "TOPLEFT", view.shoppingTitle, "BOTTOMLEFT", 0, -8)
    view.shoppingLines = {}
    for i = 1, 4 do
        local line = CreateGrandLineShoppingLine(view.shoppingPanel)
        if i == 1 then
            line:SetPoint("TOPLEFT", view.shoppingHint, "BOTTOMLEFT", 0, -12)
        elseif i == 3 then
            line:SetPoint("TOPLEFT", view.shoppingLines[1], "TOPRIGHT", 46, 0)
        else
            line:SetPoint("TOPLEFT", view.shoppingLines[i - 1], "BOTTOMLEFT", 0, -4)
        end
        view.shoppingLines[i] = line
    end

    self.grandLineView = view
end

local function RefreshGrandLineView(self)
    local view = self.grandLineView
    if not view then
        return
    end

    SetGrandLineStep(view.bloomSteps[1], "100x", GRAND_LINE_ITEM_IDS.shreddedBloom, "1x", GRAND_LINE_ITEM_IDS.strandedBloom)
    SetGrandLineStep(view.bloomSteps[2], "20x", GRAND_LINE_ITEM_IDS.strandedBloom, "1x", GRAND_LINE_ITEM_IDS.weakBloom)
    SetGrandLineStep(view.bloomSteps[3], "5x", GRAND_LINE_ITEM_IDS.weakBloom, "1x", GRAND_LINE_ITEM_IDS.bloom)
    SetGrandLineStep(view.glimmerSteps[1], "100x", GRAND_LINE_ITEM_IDS.shreddedGlimmer, "1x", GRAND_LINE_ITEM_IDS.strandedGlimmer)
    SetGrandLineStep(view.glimmerSteps[2], "20x", GRAND_LINE_ITEM_IDS.strandedGlimmer, "1x", GRAND_LINE_ITEM_IDS.weakGlimmer)
    SetGrandLineStep(view.glimmerSteps[3], "20x", GRAND_LINE_ITEM_IDS.weakGlimmer, "1x", GRAND_LINE_ITEM_IDS.glimmer)
    SetFinalGrandLineStep(view.finalStep)
    SetGrandLineShoppingLine(view.shoppingLines[1], "1x", GRAND_LINE_ITEM_IDS.bloom)
    SetGrandLineShoppingLine(view.shoppingLines[2], "1x", GRAND_LINE_ITEM_IDS.glimmer)
    SetGrandLineShoppingLine(view.shoppingLines[3], "10000x", GRAND_LINE_ITEM_IDS.shreddedBloom)
    SetGrandLineShoppingLine(view.shoppingLines[4], "40000x", GRAND_LINE_ITEM_IDS.shreddedGlimmer)
end

function ExpansionGuide:Create(parent, callbacks)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    self.panel = panel
    self.callbacks = callbacks or {}
    self.expansionKey = "midnight"
    self.expansionName = L["CATCH_FILTER_EXPANSION_MIDNIGHT"]
    self.activeScreen = "pools"
    self.buttons = {}
    self.cards = {}
    self.pages = {}
    self.hideCollected = GetGuideSettings("midnight").hideCollected and true or false

    self.summary = NewLabel(panel, "", Theme.font.title, "TOPLEFT", panel, "TOPLEFT", 0, -2)

    local nav = {
        { key = "overview", label = L["CATCH_HISTORY_VIEW_OVERVIEW"], width = 116 },
        { key = "score", label = L["CATCH_HISTORY_VIEW_SCORE"], width = 78 },
        { key = "fish", label = L["MIDNIGHT_TAB_FISH"], width = 78 },
        { key = "pools", label = L["MIDNIGHT_TAB_POOLS"], width = 78 },
        { key = "lures", label = L["MIDNIGHT_TAB_LURES"], width = 78 },
        { key = "accessories", label = L["MIDNIGHT_TAB_ACCESSORIES"], width = 116 },
        { key = "collectibles", label = L["MIDNIGHT_TAB_COLLECTIBLES"], width = 116 },
        { key = "grandline", label = L["MIDNIGHT_TAB_GRAND_LINE"], width = 106 },
        { key = "achievements", label = L["ACH_BUTTON"], width = 124 },
    }
    for index, item in ipairs(nav) do
        local button = Theme:CreateButton(panel, item.label)
        if index == 1 then
            button:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", 0, -16)
        else
            button:SetPoint("LEFT", self.buttons[nav[index - 1].key], "RIGHT", Theme.layout.gutter, 0)
        end
        button:SetWidth(item.width)
        button:SetScript("OnClick", function()
            local callback = self.callbacks[item.key]
            if callback then
                callback(item.key, self.expansionKey)
            elseif SCREENS[item.key] then
                self:ShowScreen(item.key)
            end
        end)
        self.buttons[item.key] = button
    end

    self.title = NewLabel(panel, "", Theme.font.title, "TOPLEFT", self.buttons.overview, "BOTTOMLEFT", 0, -22)
    self.description = NewLabel(panel, "", Theme.font.body, "TOPLEFT", self.title, "BOTTOMLEFT", 0, -8)
    self.description:SetPoint("RIGHT", -4, 0)

    for i = 1, COLLECTIBLE_PAGE_SIZE do
        local card = Theme:CreatePanel(panel, "panel", "border")
        local column = (i - 1) % CARD_COLUMNS
        local row = math.floor((i - 1) / CARD_COLUMNS)
        card:SetSize(CARD_WIDTH, CARD_HEIGHT)
        card:SetPoint("TOPLEFT", self.description, "BOTTOMLEFT", column * (CARD_WIDTH + Theme.layout.gutter), -22 - (row * (CARD_HEIGHT + Theme.layout.gutter)))

        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(24, 24)
        card.icon:SetPoint("TOPLEFT", 10, -10)
        card.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        card.nameText = NewLabel(card, "", Theme.font.heading, "TOPLEFT", card.icon, "TOPRIGHT", Theme.layout.gutter, 0)
        card.nameText:SetWidth(CARD_WIDTH - 54)
        card.kindText = NewLabel(card, "", Theme.font.muted, "TOPLEFT", card.nameText, "BOTTOMLEFT", 0, -4)
        card.kindText:SetWidth(CARD_WIDTH - 54)
        card.detailText = NewLabel(card, "", Theme.font.small, "BOTTOMLEFT", card, "BOTTOMLEFT", 10, 10)
        card.detailText:SetWidth(CARD_WIDTH - 20)
        card.statusText = NewLabel(card, "", Theme.font.small, "TOPRIGHT", card, "TOPRIGHT", -10, -10)
        card.statusText:SetJustifyH("RIGHT")
        card.statusText:SetWidth(92)
        card:SetScript("OnEnter", ShowCardTooltip)
        card:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        card:Hide()
        self.cards[i] = card
    end

    self.prevButton = Theme:CreateButton(panel, L["CATCH_HISTORY_PREV"])
    self.prevButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    self.prevButton:SetWidth(78)
    self.prevButton:SetScript("OnClick", function()
        SetPage(self, -1)
    end)

    self.nextButton = Theme:CreateButton(panel, L["CATCH_HISTORY_NEXT"])
    self.nextButton:SetPoint("LEFT", self.prevButton, "RIGHT", Theme.layout.gutter, 0)
    self.nextButton:SetWidth(78)
    self.nextButton:SetScript("OnClick", function()
        SetPage(self, 1)
    end)

    self.pageText = NewLabel(panel, "", Theme.font.muted, "LEFT", self.nextButton, "RIGHT", Theme.layout.gutter, 0)

    self.collectedButton = Theme:CreateButton(panel, L["MIDNIGHT_TOGGLE_HIDE_COLLECTED"])
    self.collectedButton:SetPoint("LEFT", self.pageText, "RIGHT", Theme.layout.gutter, 0)
    self.collectedButton:SetWidth(130)
    self.collectedButton:SetScript("OnClick", function()
        self.hideCollected = not self.hideCollected
        local settings = GetGuideSettings(self.expansionKey)
        settings.hideCollected = self.hideCollected and true or false
        if self.expansionKey == "midnight" then
            GetMidnightSettings().hideCollected = settings.hideCollected
        end
        self.pages.collectibles = 1
        self:Refresh()
    end)
    self.collectedButton:Hide()

    CreateGrandLineView(self, panel)
    self.achievementView = AvidAngler.UI.Achievements:Create(panel, self.buttons.overview)

    return panel
end

function ExpansionGuide:ShowScreen(screenKey, expansionKey, summaryText)
    self.expansionKey = expansionKey or self.expansionKey or "midnight"
    self.expansionName = summaryText or GetExpansionName(self.expansionKey)
    self.activeScreen = SCREENS[screenKey] and screenKey or "pools"
    if self.panel then
        self.panel:Show()
    end
    self:Refresh()
end

function ExpansionGuide:Refresh(screenKey, summaryText, expansionKey)
    if expansionKey then
        self.expansionKey = expansionKey
    else
        self.expansionKey = self.expansionKey or "midnight"
    end
    self.expansionName = summaryText or GetExpansionName(self.expansionKey)
    self.hideCollected = GetGuideSettings(self.expansionKey).hideCollected and true or false
    if screenKey then
        if self.expansionKey ~= "midnight" and (screenKey == "score" or screenKey == "grandline") then
            self.activeScreen = "fish"
        else
            self.activeScreen = SCREENS[screenKey] and screenKey or self.activeScreen
        end
    end
    if self.expansionKey ~= "midnight" and self.activeScreen == "lures" and not HasVisibleRows(self, "lures") then
        self.activeScreen = "fish"
    end
    local screen = SCREENS[self.activeScreen] or SCREENS.pools
    local isAchievements = self.activeScreen == "achievements"
    self.achievementView:SetShown(isAchievements)
    if isAchievements then
        self.summary:SetText(self.expansionName)
        LayoutNav(self)
        for key, button in pairs(self.buttons) do SetButtonSelected(button, key == "achievements") end
        for _, card in ipairs(self.cards) do card:Hide() end
        self.title:Hide()
        self.description:Hide()
        self.grandLineView:Hide()
        self.prevButton:Hide()
        self.nextButton:Hide()
        self.pageText:Hide()
        self.collectedButton:Hide()
        AvidAngler.UI.Achievements:SetExpansion(self.expansionKey, self.expansionName)
        return
    end
    local expansionName = self.expansionName
    self.summary:SetText(expansionName)
    if self.expansionKey == "midnight" then
        self.title:SetText(screen.title or "")
        self.description:SetText(screen.description or "")
    elseif self.activeScreen == "fish" then
        self.title:SetText(L["EXPANSION_GUIDE_FISH_TITLE"]:format(expansionName))
        self.description:SetText(L["EXPANSION_GUIDE_FISH_DESC"]:format(expansionName))
    elseif self.activeScreen == "pools" then
        self.title:SetText(L["EXPANSION_GUIDE_POOLS_TITLE"]:format(expansionName))
        self.description:SetText(L["EXPANSION_GUIDE_POOLS_DESC"]:format(expansionName))
    elseif self.activeScreen == "lures" then
        self.title:SetText(L["EXPANSION_GUIDE_LURES_TITLE"]:format(expansionName))
        self.description:SetText(L["EXPANSION_GUIDE_LURES_DESC"]:format(expansionName))
    elseif self.activeScreen == "accessories" then
        self.title:SetText(L["EXPANSION_GUIDE_ACCESSORIES_TITLE"]:format(expansionName))
        self.description:SetText(L["EXPANSION_GUIDE_ACCESSORIES_DESC"]:format(expansionName))
    elseif self.activeScreen == "collectibles" then
        self.title:SetText(L["EXPANSION_GUIDE_COLLECTIBLES_TITLE"]:format(expansionName))
        self.description:SetText(L["EXPANSION_GUIDE_COLLECTIBLES_DESC"]:format(expansionName))
    else
        self.title:SetText(screen.title or "")
        self.description:SetText(screen.description or "")
    end
    local isGrandLineScreen = self.activeScreen == "grandline"
    LayoutNav(self)
    self.title:SetShown(not isGrandLineScreen)
    self.description:SetShown(not isGrandLineScreen)
    if self.grandLineView then
        self.grandLineView:SetShown(isGrandLineScreen)
        if isGrandLineScreen then
            RefreshGrandLineView(self)
        end
    end
    local rows = BuildDisplayRows(self, self.activeScreen)
    local page, maxPage = GetCurrentPage(self, self.activeScreen, #rows)
    local pageSize = GetPageSize(self.activeScreen)
    local startIndex = ((page - 1) * pageSize) + 1

    for key, button in pairs(self.buttons) do
        SetButtonSelected(button, key == self.activeScreen)
    end
    if self.collectedButton then
        local visible = self.activeScreen == "collectibles"
        self.collectedButton:SetShown(visible)
        if visible then
            self.collectedButton.text:SetText(self.hideCollected and L["MIDNIGHT_TOGGLE_SHOW_COLLECTED"] or L["MIDNIGHT_TOGGLE_HIDE_COLLECTED"])
            SetButtonSelected(self.collectedButton, self.hideCollected)
        end
    end

    for i = 1, #self.cards do
        local card = self.cards[i]
        local entry = not isGrandLineScreen and i <= pageSize and rows[startIndex + i - 1] or nil
        local row = entry and entry.row
        if row then
            local itemID = row.itemID
            local itemInfo = GetItemInfo(itemID, function(loadedInfo)
                if card.itemID ~= itemID then
                    return
                end
                card.icon:SetTexture(loadedInfo.icon or row.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                card.nameText:SetText(loadedInfo.name or row.name or "")
                SetItemNameColor(card.nameText, loadedInfo.quality)
            end)
            local status = entry.status
            local positive = entry.positive
            card.row = row
            card.itemID = itemID
            card.icon:SetTexture((itemInfo and itemInfo.icon) or row.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            card.nameText:SetText((itemInfo and itemInfo.name) or row.name or "")
            SetItemNameColor(card.nameText, itemInfo and itemInfo.quality)
            card.kindText:SetText(GetDisplayKind(self.activeScreen, row))
            card.detailText:SetText(GetCardDetail(self.activeScreen, row))
            card.statusText:SetText(status or "")
            if positive == true then
                card.statusText:SetTextColor(unpack(Theme.color.success))
            elseif positive == false then
                card.statusText:SetTextColor(unpack(Theme.color.textSecondary))
            else
                card.statusText:SetTextColor(unpack(Theme.color.accent))
            end
            card:Show()
        else
            card.row = nil
            card.itemID = nil
            card:Hide()
        end
    end

    if self.pageText then
        self.pageText:Show()
        local lastIndex = math.min(#rows, startIndex + pageSize - 1)
        self.pageText:SetText(isGrandLineScreen and "" or L["MIDNIGHT_PAGE_STATUS"]:format(#rows > 0 and startIndex or 0, lastIndex, #rows))
    end
    if self.prevButton then
        self.prevButton:SetShown(not isGrandLineScreen)
        SetButtonEnabled(self.prevButton, page > 1)
    end
    if self.nextButton then
        self.nextButton:SetShown(not isGrandLineScreen)
        SetButtonEnabled(self.nextButton, page < maxPage)
    end
end
