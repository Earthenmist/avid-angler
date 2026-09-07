local _, AvidAngler = ...

AvidAngler.Data = AvidAngler.Data or {}

local TrainerCatalog = {
    expansionNames = {
        midnight = "Midnight",
        warWithin = "The War Within",
        dragonflight = "Dragonflight",
        shadowlands = "Shadowlands",
        battleForAzeroth = "Battle for Azeroth",
        legion = "Legion",
        warlords = "Warlords",
        pandaria = "Pandaria",
        cataclysm = "Cataclysm",
        northrend = "Wrath of the Lich King",
        outland = "Burning Crusade",
        classic = "Classic",
    },

    skillLineNames = {
        midnight = { "Midnight Fishing" },
        warWithin = { "Khaz Algar Fishing" },
        dragonflight = { "Dragon Isles Fishing" },
        shadowlands = { "Shadowlands Fishing" },
        battleForAzeroth = { "Kul Tiran Fishing", "Zandalari Fishing" },
        legion = { "Legion Fishing" },
        warlords = { "Draenor Fishing" },
        pandaria = { "Pandaria Fishing" },
        cataclysm = { "Cataclysm Fishing" },
        northrend = { "Northrend Fishing" },
        outland = { "Outland Fishing" },
        classic = { "Fishing", "Classic Fishing" },
    },

    professionIDs = {
        midnight = { 2911 },
        warWithin = { 2876 },
        dragonflight = { 2826 },
        shadowlands = { 2754 },
        battleForAzeroth = { 2585 },
        legion = { 2586 },
        warlords = { 2587 },
        pandaria = { 2588 },
        cataclysm = { 2589 },
        northrend = { 2590 },
        outland = { 2591 },
        classic = { 2592 },
    },

    trainers = {
        midnight = {
            { name = "Melandra", npcID = 247800, faction = "Both", zone = "Eversong Woods", location = nil, mapID = 2395, x = 48.6, y = 76.0, waypoint = "/way #2395 48.6 76.0 Melandra", note = "Midnight trainer" },
            { name = "Drathen", npcID = 253468, faction = "Both", zone = "Silvermoon City", location = "Large pond / trainer area", mapID = 2393, x = 44.7, y = 60.2, waypoint = "/way #2393 44.7 60.2 Drathen", note = "Midnight trainer" },
            { name = "Rinnoa", npcID = 254707, faction = "Both", zone = "Voidstorm", location = nil, mapID = 2405, x = 51.0, y = 68.6, waypoint = "/way #2405 51.0 68.6 Rinnoa", note = "Midnight trainer" },
            { name = "Hav'kalo", npcID = 253039, faction = "Both", zone = "Zul'Aman", location = nil, mapID = 2437, x = 38.2, y = 21.4, waypoint = "/way #2437 38.2 21.4 Hav'kalo", note = "Midnight trainer" },
            { name = "Old Koko", npcID = 255185, faction = "Both", zone = "Zul'Aman", location = nil, mapID = 2437, x = 48.6, y = 25.8, waypoint = "/way #2437 48.6 25.8 Old Koko", note = "Midnight trainer" },
            { name = "Zel'kara the Spear", npcID = 255092, faction = "Both", zone = "Zul'Aman", location = nil, mapID = 2437, x = 46.2, y = 70.4, waypoint = "/way #2437 46.2 70.4 Zel'kara the Spear", note = "Midnight trainer" },
        },
        warWithin = {
            { name = "Maraclozh", npcID = 218175, faction = "Both", zone = "City of Threads", location = "Umbral Bazaar", mapID = 2213, x = nil, y = nil, waypoint = nil, note = "TWW trainer; waypoint not confirmed" },
            { name = "Drokar", npcID = 219106, faction = "Both", zone = "Dornogal", location = "Keepers Terrace", mapID = 2339, x = 50.4, y = 26.8, waypoint = "/way #2339 50.4 26.8 Drokar", note = "TWW trainer" },
        },
        dragonflight = {
            { name = "Angler Taimu", npcID = 194955, faction = "Both", zone = "Ohn'ahran Plains", location = "Roaring Dragonsprings near Ohn'iri Springs", mapID = 2023, x = 41.2, y = 56.0, waypoint = "/way #2023 41.2 56.0 Angler Taimu", note = "Dragonflight trainer" },
            { name = "Daring Fisher", npcID = 197645, faction = "Both", zone = "Ohn'ahran Plains", location = "Roaring Dragonsprings", mapID = 2023, x = nil, y = nil, waypoint = nil, note = "Dragonflight trainer; mobile/various locations noted by guide" },
            { name = "Threshrak", npcID = 194282, faction = "Both", zone = "Ohn'ahran Plains", location = "Emerald Gardens near Teerakai", mapID = 2023, x = 34.1, y = 59.4, waypoint = "/way #2023 34.1 59.4 Threshrak", note = "Dragonflight trainer" },
            { name = "Nunvuq", npcID = 186554, faction = "Both", zone = "The Azure Span", location = "Iskaara", mapID = 2024, x = 13.9, y = 49.2, waypoint = "/way #2024 13.9 49.2 Nunvuq", note = "Dragonflight trainer" },
            { name = "Danielle Anglers", npcID = 191150, faction = "Both", zone = "The Waking Shores", location = "Wild Coast, Alliance arrival area", mapID = 2022, x = 81.3, y = 32.3, waypoint = "/way #2022 81.3 32.3 Danielle Anglers", note = "Dragonflight trainer" },
            { name = "Khuri", npcID = 194584, faction = "Both", zone = "The Waking Shores", location = "River Mouth Fishing Hole near Ruby Life Pools", mapID = 2022, x = 63.3, y = 75.8, waypoint = "/way #2022 63.3 75.8 Khuri", note = "Dragonflight trainer" },
            { name = "Mora Cloudwalker", npcID = 190524, faction = "Both", zone = "The Waking Shores", location = "Wild Coast, Horde arrival area", mapID = 2022, x = 81.0, y = 29.0, waypoint = "/way #2022 81.0 29.0 Mora Cloudwalker", note = "Dragonflight trainer" },
            { name = "Toklo", npcID = 185359, faction = "Both", zone = "Valdrakken", location = "Market area", mapID = 2112, x = nil, y = nil, waypoint = nil, note = "Dragonflight trainer; waypoint not confirmed" },
        },
        shadowlands = {
            { name = "Retriever Au'prin", npcID = 156671, faction = "Both", zone = "Oribos", location = "Hall of Shapes", mapID = 1670, x = 46.6, y = 25.8, waypoint = "/way #1670 46.6 25.8 Retriever Au'prin", note = "Shadowlands trainer" },
        },
        battleForAzeroth = {
            { name = "Alan Goyle", npcID = 136102, faction = "Alliance", zone = "Boralus", location = "Tradewinds Market / Boralus Harbor", mapID = 1161, x = 74.2, y = 5.7, waypoint = "/way #1161 74.2 5.7 Alan Goyle", note = "Alliance BFA trainer" },
            { name = "Silent Tali", npcID = 122705, faction = "Horde", zone = "Dazar'alor", location = "Northern Dazar'alor / The Sliver", mapID = 1165, x = 50.6, y = 23.2, waypoint = "/way #1165 50.6 23.2 Silent Tali", note = "Horde BFA trainer" },
        },
        legion = {
            { name = "Marcia Chase", npcID = 95844, faction = "Both", zone = "Dalaran", location = "Broken Isles Dalaran, near fountain", mapID = 627, x = nil, y = nil, waypoint = nil, note = "Legion guide says to talk to Marcia Chase in Broken Isles Dalaran" },
        },
        warlords = {
            { name = "Draenor Fishing", npcID = nil, faction = "Both", zone = "Draenor", location = nil, mapID = 572, x = nil, y = nil, waypoint = nil, note = "No fixed trainer row: Draenor fishing is learned via Fishing Guide to Draenor" },
        },
        pandaria = {
            { name = "Nat Pagle", npcID = 63721, faction = "Both", zone = "Krasarang Wilds", location = "Anglers Wharf", mapID = 418, x = 68.4, y = 43.4, waypoint = "/way #418 68.4 43.4 Nat Pagle", note = "Pandaria trainer / Anglers hub" },
            { name = "Ben of the Booming Voice", npcID = 70398, faction = "Both", zone = "Valley of the Four Winds", location = "Halfhill", mapID = 376, x = 58.8, y = 47.0, waypoint = "/way #376 58.8 47.0 Ben of the Booming Voice", note = "Pandaria trainer" },
        },
        cataclysm = {
            { name = "Whilsey Bottomtooth", npcID = 50570, faction = "Alliance", zone = "Gilneas", location = "Stormglen Village", mapID = 217, x = 63.6, y = 95.0, waypoint = "/way 63.6 95.0", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Steven Stagnaro", npcID = 56068, faction = "Both", zone = "Darkmoon Isle", location = nil, mapID = nil, x = 52.6, y = 88.6, waypoint = "/way 52.6 88.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "KTC Train-a-Tron Deluxe", npcID = 45286, faction = "Horde", zone = "Lost Isles", location = "Town-In-A-Box", mapID = nil, x = 45.6, y = 65.6, waypoint = "/way 45.6 65.6", note = "Parsed from Wowhead MoP Classic trainer table" },
        },
        northrend = {
            { name = "Old Man Robert", npcID = 26993, faction = "Alliance", zone = "Borean Tundra", location = "Valiance Keep", mapID = 114, x = 57.8, y = 71.6, waypoint = "/way 57.8 71.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Byron Welwick", npcID = 26909, faction = "Alliance", zone = "Howling Fjord", location = "Valgarde", mapID = 117, x = 59.4, y = 63.0, waypoint = "/way 59.4 63.0", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Marcia Chase", npcID = 28742, faction = "Both", zone = "Dalaran", location = "The Eventide", mapID = 125, x = 52.6, y = 64.8, waypoint = "/way 52.6 64.8", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Fishy Ser'ji", npcID = 32474, faction = "Horde", zone = "Borean Tundra", location = "Warsong Hold", mapID = 114, x = 41.8, y = 54.6, waypoint = "/way 41.8 54.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Angelina Soren", npcID = 26957, faction = "Horde", zone = "Howling Fjord", location = "Vengeance Landing", mapID = 117, x = 78.7, y = 26.1, waypoint = "/way 78.7 26.1", note = "Parsed from Wowhead MoP Classic trainer table" },
        },
        outland = {
            { name = "Diktynna", npcID = 17101, faction = "Alliance", zone = "Azuremyst Isle", location = "Azura Watch", mapID = 97, x = 57.8, y = 71.6, waypoint = "/way 57.8 71.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Erett", npcID = 16774, faction = "Alliance", zone = "The Exodar", location = "The Crystal Hall", mapID = 103, x = 31.6, y = 14.8, waypoint = "/way 31.6 14.8", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Old Man Barlo", npcID = 25580, faction = "Both", zone = "Terokkar Forest", location = "Cenarion Thicket", mapID = 108, x = 38.6, y = 12.8, waypoint = "/way 38.6 12.8", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Juno Dufrain", npcID = 18911, faction = "Both", zone = "Zangarmarsh", location = "Cenarion Refuge", mapID = 102, x = 78.0, y = 66.0, waypoint = "/way 78.0 66.0", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Drathen", npcID = 16780, faction = "Horde", zone = "Silvermoon City", location = "Walk of Elders", mapID = 110, x = 76.6, y = 68.2, waypoint = "/way 76.6 68.2", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Zurjaya", npcID = 18018, faction = "Horde", zone = "Zangarmarsh", location = "Zabra'jin", mapID = 102, x = 32.2, y = 49.6, waypoint = "/way 32.2 49.6", note = "Parsed from Wowhead MoP Classic trainer table" },
        },
        classic = {
            { name = "Astaia", npcID = 4156, faction = "Alliance", zone = "Darnassus", location = "Temple Gardens", mapID = 89, x = 47.6, y = 56.6, waypoint = "/way 47.6, 56.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Paxton Ganter", npcID = 1700, faction = "Alliance", zone = "Dun Morogh", location = "Brewnall Village", mapID = 29, x = 35.6, y = 40.4, waypoint = "/way 35.6, 40.4", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "\"Dirty\" Michael Crowe", npcID = 23896, faction = "Alliance", zone = "Dustwallow Marsh", location = "Theramore", mapID = 70, x = 69.2, y = 51.8, waypoint = "/way 69.2 51.8", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Lee Brown", npcID = 1651, faction = "Alliance", zone = "Elwynn Forest", location = "Goldshire", mapID = 37, x = 47.6, y = 62.2, waypoint = "/way 47.6, 62.2", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Brannock", npcID = 7946, faction = "Alliance", zone = "Feralas", location = "Feathermoon Stronghold", mapID = 69, x = 32.2, y = 41.6, waypoint = "/way 32.2, 41.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Donald Rabonne", npcID = 2367, faction = "Alliance", zone = "Hillsbrad Foothills", location = "Southshore", mapID = 25, x = 50.6, y = 61, waypoint = "/way 50.6, 61", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Grimnur Stonebrand", npcID = 5161, faction = "Alliance", zone = "Ironforge", location = "Forlorn Cavern", mapID = 87, x = 48.4, y = 6.4, waypoint = "/way 48.4, 6.4", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Warg Deepwater", npcID = 1683, faction = "Alliance", zone = "Loch Modan", location = "Thelsamar", mapID = 48, x = 40.6, y = 39.6, waypoint = "/way 40.6, 39.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Matthew Hooper", npcID = 1680, faction = "Alliance", zone = "Redridge Mountains", location = "Lakeshire", mapID = 49, x = 26.8, y = 50.4, waypoint = "/way 26.8, 50.4", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Arnold Leland", npcID = 5493, faction = "Alliance", zone = "Stormwind City", location = "Canal by Trade District", mapID = 84, x = 45.8, y = 58.2, waypoint = "/way 45.8, 58.2", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Androl Oakhand", npcID = 3607, faction = "Alliance", zone = "Teldrassil", location = "Rut'theran Village", mapID = 57, x = 56, y = 93.6, waypoint = "/way 56, 93.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Harold Riggs", npcID = 3179, faction = "Alliance", zone = "Wetlands", location = "Menethil Harbor", mapID = 56, x = 8.2, y = 58.6, waypoint = "/way 8.2, 58.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Myizz Luckycatch", npcID = 2834, faction = "Both", zone = "Cape of Stranglethorn", location = "Booty Bay", mapID = 210, x = 27.6, y = 77, waypoint = "/way 27.6, 77", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Kil'Hiwana", npcID = 12961, faction = "Horde", zone = "Ashenvale", location = "Zoram'gar", mapID = 63, x = 10.8, y = 33.6, waypoint = "/way 10.8, 33.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "KTC Train-a-Tron Deluxe", npcID = 49885, faction = "Horde", zone = "Azshara", location = "Bilgewater Harbor", mapID = 76, x = 57.0, y = 50.6, waypoint = "/way 57.0 50.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Lui'Mala", npcID = 12032, faction = "Horde", zone = "Desolace", location = "Shadowprey Village", mapID = 66, x = 22.6, y = 72.6, waypoint = "/way 22.6, 72.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Lau'Tiki", npcID = 5941, faction = "Horde", zone = "Durotar", location = "SW of Sen'jin Village", mapID = 1, x = 53.2, y = 81.6, waypoint = "/way 53.2, 81.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Uthan Stillwater", npcID = 5938, faction = "Horde", zone = "Mulgore", location = "Bloodhoof Village", mapID = 7, x = 44.6, y = 60.6, waypoint = "/way 44.6, 60.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Lumak", npcID = 3332, faction = "Horde", zone = "Orgrimmar", location = "Valley of Honor", mapID = 85, x = 69.8, y = 29.6, waypoint = "/way 69.8, 29.6", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Old Umbehto", npcID = 44975, faction = "Horde", zone = "Orgrimmar", location = "Valley of the Spirits", mapID = 85, x = 35.0, y = 67.4, waypoint = "/way 35.0 67.4", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Katoom the Angler", npcID = 14740, faction = "Horde", zone = "The Hinterlands", location = "Revantusk Village", mapID = 26, x = 80.2, y = 81.4, waypoint = "/way 80.2, 81.4", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Kah Mistrunner", npcID = 3028, faction = "Horde", zone = "Thunder Bluff", location = "Upper Tier", mapID = 88, x = 56, y = 46.8, waypoint = "/way 56, 46.8", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Clyde Kellen", npcID = 5690, faction = "Horde", zone = "Tirisfal Glades Brightwater Lake", location = nil, mapID = nil, x = 67.2, y = 51, waypoint = "/way 67.2, 51", note = "Parsed from Wowhead MoP Classic trainer table" },
            { name = "Armand Cromwell", npcID = 4573, faction = "Horde", zone = "Undercity", location = "Magic Quarter", mapID = 90, x = 80.8, y = 31.2, waypoint = "/way 80.8, 31.2", note = "Parsed from Wowhead MoP Classic trainer table" },
        },
    },
}

function TrainerCatalog:GetExpansionName(expansionKey)
    return self.expansionNames and self.expansionNames[expansionKey]
end

function TrainerCatalog:GetSkillLineNames(expansionKey)
    return self.skillLineNames and self.skillLineNames[expansionKey] or {}
end

function TrainerCatalog:GetProfessionIDs(expansionKey)
    return self.professionIDs and self.professionIDs[expansionKey] or {}
end

function TrainerCatalog:GetTrainers(expansionKey, faction)
    local rows = self.trainers and self.trainers[expansionKey] or {}
    local result = {}
    for _, row in ipairs(rows) do
        if row.faction == "Both" or row.faction == faction then
            result[#result + 1] = row
        end
    end
    return result
end

AvidAngler.Data.TrainerCatalog = TrainerCatalog
