local addonName, ns = ...

-- Classic gathering nodes and the skill they need (English names; other languages are left out, their nodes
-- simply get no requirement). Shared: QoL's "Gathering skill in tooltips" reads the levels, the Highlight module
-- its herb names, QoL's "Zone levels on the world map" the zone tables at the end. Node levels as in Classic
-- Era (cross-checked with DoMeWhen-Classic's Gatherables table).
--   ns.GATHER_SKILL[name] = { skill = "mining" | "herbalism", level = n }
--   ns.GATHER_SKILL_LINES[skill] = skill line ID (for the player's rank and the localised profession name)

ns.GATHER_SKILL_LINES = { mining = 186, herbalism = 182, fishing = 356 }
ns.GATHER_SKILL_NAMES = { mining = "Mining", herbalism = "Herbalism", fishing = "Fishing" } -- English fallbacks

local NODES = {
  mining = {
    ["Copper Vein"] = 1,
    ["Tin Vein"] = 65,
    ["Incendicite Mineral Vein"] = 65,
    ["Silver Vein"] = 75,
    ["Ooze Covered Silver Vein"] = 75,
    ["Lesser Bloodstone Deposit"] = 75,
    ["Iron Deposit"] = 125,
    ["Indurium Mineral Vein"] = 150,
    ["Gold Vein"] = 155,
    ["Ooze Covered Gold Vein"] = 155,
    ["Mithril Deposit"] = 175,
    ["Ooze Covered Mithril Deposit"] = 175,
    ["Truesilver Deposit"] = 230,
    ["Ooze Covered Truesilver Deposit"] = 230,
    ["Dark Iron Deposit"] = 230,
    ["Small Thorium Vein"] = 245,
    ["Ooze Covered Thorium Vein"] = 245,
    ["Rich Thorium Vein"] = 275,
    ["Ooze Covered Rich Thorium Vein"] = 275,
    ["Hakkari Thorium Vein"] = 275,
    ["Small Obsidian Chunk"] = 305,
    ["Large Obsidian Chunk"] = 305,
  },
  herbalism = {
    ["Peacebloom"] = 1,
    ["Silverleaf"] = 1,
    ["Bloodthistle"] = 1,
    ["Earthroot"] = 15,
    ["Mageroyal"] = 50,
    ["Briarthorn"] = 70,
    ["Stranglekelp"] = 85,
    ["Bruiseweed"] = 100,
    ["Wild Steelbloom"] = 115,
    ["Grave Moss"] = 120,
    ["Kingsblood"] = 125,
    ["Liferoot"] = 150,
    ["Fadeleaf"] = 160,
    ["Goldthorn"] = 170,
    ["Khadgar's Whisker"] = 185,
    ["Wintersbite"] = 195,
    ["Firebloom"] = 205,
    ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220,
    ["Sungrass"] = 230,
    ["Blindweed"] = 235,
    ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250,
    ["Golden Sansam"] = 260,
    ["Dreamfoil"] = 270,
    ["Mountain Silversage"] = 280,
    ["Plaguebloom"] = 285,
    ["Icecap"] = 290,
    ["Black Lotus"] = 300,
  },
}

ns.GATHER_SKILL = {}
for skill, nodes in pairs(NODES) do
  for name, level in pairs(nodes) do
    ns.GATHER_SKILL[name] = { skill = skill, level = level }
  end
end

-- Zones ------------------------------------------------------------------------------------------------------------
-- Zones by uiMapID (Forever uses the Classic Era IDs, plus its own for the new zones):
--   ns.ZONE_LEVELS[uiMapID] = { name (English, for a lookup by name), min, max (level range; nil for cities and
--   Moonglade), fish = the zone's minimum Fishing skill (nil: no fishing water, or not known yet) }
-- Levels are Forever's own, as its Looking for Group tool shows them (generated; Deadwind Pass isn't listed there
-- and keeps its Classic range). Fishing minimums are the Classic ones.
ns.ZONE_LEVELS = {
  -- Eastern Kingdoms
  [1416] = { name = "Alterac Mountains", min = 28, max = 44, fish = 130 },
  [1417] = { name = "Arathi Highlands", min = 28, max = 44, fish = 130 },
  [1418] = { name = "Badlands", min = 33, max = 50 },
  [1419] = { name = "Blasted Lands", min = 43, max = 60 },
  [1428] = { name = "Burning Steppes", min = 48, max = 60, fish = 330 },
  [1430] = { name = "Deadwind Pass", min = 55, max = 60, fish = 330 },
  [1426] = { name = "Dun Morogh", min = 1, max = 14, fish = 1 },
  [1431] = { name = "Duskwood", min = 18, max = 34, fish = 55 },
  [1423] = { name = "Eastern Plaguelands", min = 53, max = 63, fish = 330 },
  [1429] = { name = "Elwynn Forest", min = 1, max = 14, fish = 1 },
  [1424] = { name = "Hillsbrad Foothills", min = 18, max = 34, fish = 55 },
  [1432] = { name = "Loch Modan", min = 8, max = 24, fish = 1 },
  [1433] = { name = "Redridge Mountains", min = 13, max = 30, fish = 55 },
  [1427] = { name = "Searing Gorge", min = 43, max = 60 },
  [1421] = { name = "Silverpine Forest", min = 8, max = 24, fish = 1 },
  [1434] = { name = "Stranglethorn Vale", min = 28, max = 50, fish = 130 },
  [1435] = { name = "Swamp of Sorrows", min = 33, max = 50, fish = 130 },
  [1425] = { name = "The Hinterlands", min = 38, max = 54, fish = 205 },
  [1420] = { name = "Tirisfal Glades", min = 1, max = 14, fish = 1 },
  [1436] = { name = "Westfall", min = 8, max = 24, fish = 1 },
  [1422] = { name = "Western Plaguelands", min = 48, max = 60, fish = 205 },
  [1437] = { name = "Wetlands", min = 18, max = 34, fish = 55 },
  [1453] = { name = "Stormwind City", city = true, fish = 1 },
  [1455] = { name = "Ironforge", city = true, fish = 1 },
  [1458] = { name = "Undercity", city = true, fish = 1 },
  -- Kalimdor
  [1440] = { name = "Ashenvale", min = 18, max = 34, fish = 55 },
  [1447] = { name = "Azshara", min = 43, max = 60, fish = 205 },
  [1439] = { name = "Darkshore", min = 8, max = 24, fish = 1 },
  [1443] = { name = "Desolace", min = 28, max = 44, fish = 130 },
  [1411] = { name = "Durotar", min = 1, max = 14, fish = 1 },
  [1445] = { name = "Dustwallow Marsh", min = 33, max = 50, fish = 130 },
  [1448] = { name = "Felwood", min = 46, max = 60, fish = 205 },
  [1444] = { name = "Feralas", min = 38, max = 54, fish = 205 },
  [1450] = { name = "Moonglade", fish = 205 },
  [1412] = { name = "Mulgore", min = 1, max = 14, fish = 1 },
  [1451] = { name = "Silithus", min = 53, max = 60, fish = 330 },
  [1442] = { name = "Stonetalon Mountains", min = 13, max = 32, fish = 55 },
  [1446] = { name = "Tanaris", min = 38, max = 54, fish = 205 },
  [1438] = { name = "Teldrassil", min = 1, max = 14, fish = 1 },
  [1413] = { name = "The Barrens", min = 8, max = 30, fish = 1 },
  [1441] = { name = "Thousand Needles", min = 23, max = 40, fish = 130 },
  [1449] = { name = "Un'Goro Crater", min = 45, max = 60, fish = 205 },
  [1452] = { name = "Winterspring", min = 53, max = 63, fish = 330 },
  [1454] = { name = "Orgrimmar", city = true, fish = 1 },
  [1456] = { name = "Thunder Bluff", city = true, fish = 1 },
  [1457] = { name = "Darnassus", city = true, fish = 1 },
  -- Forever's new zones
  [2548] = { name = "Riverglades", min = 33, max = 54 },
  [2521] = { name = "Zephras Isle", min = 1, max = 14 },
  [2665] = { name = "Zephras Isle", min = 1, max = 14 },
  [2482] = { name = "Mount Hyjal", min = 55, max = 60 },
}

-- The herb and ore nodes that spawn in each zone (uiMapID), from the game's spawn data
-- (strays below 3 spawns or 10% of the zone's most common node are left out). Zones
-- without nodes in that data (Deadwind Pass, Moonglade, the cities) have no entry: no gathering range shown.
ns.GATHER_ZONES = {
  [1411] = { "Copper Vein", "Earthroot", "Mageroyal", "Peacebloom", "Silverleaf" },
  [1412] = { "Copper Vein", "Earthroot", "Peacebloom", "Silverleaf" },
  [1413] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Kingsblood", "Mageroyal", "Peacebloom", "Silver Vein", "Silverleaf", "Stranglekelp", "Tin Vein", "Wild Steelbloom" },
  [1416] = { "Bruiseweed", "Fadeleaf", "Gold Vein", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Kingsblood", "Liferoot", "Mithril Deposit", "Silver Vein", "Truesilver Deposit", "Wild Steelbloom", "Wintersbite" },
  [1417] = { "Bruiseweed", "Fadeleaf", "Gold Vein", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Kingsblood", "Liferoot", "Mithril Deposit", "Silver Vein", "Tin Vein", "Truesilver Deposit", "Wild Steelbloom" },
  [1418] = { "Fadeleaf", "Firebloom", "Gold Vein", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Kingsblood", "Mithril Deposit", "Purple Lotus", "Silver Vein", "Truesilver Deposit", "Wild Steelbloom" },
  [1419] = { "Firebloom", "Gold Vein", "Gromsblood", "Mithril Deposit", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1420] = { "Copper Vein", "Earthroot", "Peacebloom", "Silverleaf" },
  [1421] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Mageroyal", "Peacebloom", "Silver Vein", "Silverleaf", "Stranglekelp", "Tin Vein" },
  [1422] = { "Arthas' Tears", "Dreamfoil", "Gold Vein", "Mithril Deposit", "Mountain Silversage", "Plaguebloom", "Rich Thorium Vein", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1423] = { "Arthas' Tears", "Black Lotus", "Dreamfoil", "Gold Vein", "Golden Sansam", "Mithril Deposit", "Mountain Silversage", "Plaguebloom", "Rich Thorium Vein", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1424] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Gold Vein", "Iron Deposit", "Kingsblood", "Liferoot", "Mageroyal", "Mithril Deposit", "Silver Vein", "Stranglekelp", "Tin Vein", "Truesilver Deposit", "Wild Steelbloom" },
  [1425] = { "Fadeleaf", "Ghost Mushroom", "Gold Vein", "Golden Sansam", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Liferoot", "Mithril Deposit", "Purple Lotus", "Silver Vein", "Small Thorium Vein", "Stranglekelp", "Sungrass", "Truesilver Deposit" },
  [1426] = { "Copper Vein", "Earthroot", "Peacebloom", "Silverleaf" },
  [1427] = { "Dark Iron Deposit", "Firebloom", "Gold Vein", "Iron Deposit", "Mithril Deposit", "Silver Vein", "Small Thorium Vein", "Truesilver Deposit" },
  [1428] = { "Black Lotus", "Dark Iron Deposit", "Dreamfoil", "Gold Vein", "Golden Sansam", "Mithril Deposit", "Mountain Silversage", "Rich Thorium Vein", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1429] = { "Copper Vein", "Earthroot", "Peacebloom", "Silverleaf" },
  [1431] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Gold Vein", "Grave Moss", "Iron Deposit", "Kingsblood", "Mageroyal", "Silver Vein", "Tin Vein", "Wild Steelbloom" },
  [1432] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Mageroyal", "Peacebloom", "Silver Vein", "Silverleaf", "Tin Vein" },
  [1433] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Mageroyal", "Silver Vein", "Tin Vein" },
  [1434] = { "Fadeleaf", "Gold Vein", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Kingsblood", "Liferoot", "Mithril Deposit", "Purple Lotus", "Silver Vein", "Stranglekelp", "Tin Vein", "Wild Steelbloom" },
  [1435] = { "Blindweed", "Fadeleaf", "Gold Vein", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Liferoot", "Mithril Deposit", "Silver Vein" },
  [1436] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Mageroyal", "Peacebloom", "Silver Vein", "Silverleaf", "Stranglekelp", "Tin Vein" },
  [1437] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Gold Vein", "Grave Moss", "Incendicite Mineral Vein", "Iron Deposit", "Kingsblood", "Liferoot", "Mageroyal", "Silver Vein", "Stranglekelp", "Tin Vein", "Wild Steelbloom" },
  [1438] = { "Earthroot", "Mageroyal", "Peacebloom", "Silverleaf" },
  [1439] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Earthroot", "Mageroyal", "Peacebloom", "Silverleaf", "Stranglekelp", "Tin Vein" },
  [1440] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Iron Deposit", "Kingsblood", "Liferoot", "Mageroyal", "Purple Lotus", "Silver Vein", "Stranglekelp", "Tin Vein", "Wild Steelbloom" },
  [1441] = { "Bruiseweed", "Copper Vein", "Gold Vein", "Iron Deposit", "Kingsblood", "Tin Vein", "Wild Steelbloom" },
  [1442] = { "Briarthorn", "Bruiseweed", "Copper Vein", "Gold Vein", "Iron Deposit", "Kingsblood", "Mithril Deposit", "Tin Vein", "Wild Steelbloom" },
  [1443] = { "Bruiseweed", "Ghost Mushroom", "Grave Moss", "Gromsblood", "Iron Deposit", "Kingsblood", "Liferoot", "Mithril Deposit", "Stranglekelp", "Tin Vein", "Truesilver Deposit", "Wild Steelbloom" },
  [1444] = { "Golden Sansam", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Liferoot", "Mithril Deposit", "Ooze Covered Gold Vein", "Ooze Covered Mithril Deposit", "Ooze Covered Truesilver Deposit", "Purple Lotus", "Small Thorium Vein", "Stranglekelp", "Sungrass", "Truesilver Deposit" },
  [1445] = { "Fadeleaf", "Goldthorn", "Iron Deposit", "Khadgar's Whisker", "Kingsblood", "Liferoot", "Mithril Deposit", "Stranglekelp" },
  [1446] = { "Firebloom", "Gold Vein", "Mithril Deposit", "Purple Lotus", "Small Thorium Vein", "Stranglekelp", "Truesilver Deposit" },
  [1447] = { "Dreamfoil", "Golden Sansam", "Mithril Deposit", "Mountain Silversage", "Purple Lotus", "Rich Thorium Vein", "Stranglekelp", "Sungrass", "Truesilver Deposit" },
  [1448] = { "Arthas' Tears", "Dreamfoil", "Golden Sansam", "Gromsblood", "Mithril Deposit", "Plaguebloom", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1449] = { "Blindweed", "Dreamfoil", "Gold Vein", "Golden Sansam", "Mithril Deposit", "Mountain Silversage", "Ooze Covered Thorium Vein", "Ooze Covered Truesilver Deposit", "Rich Thorium Vein", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1451] = { "Black Lotus", "Dreamfoil", "Gold Vein", "Golden Sansam", "Mithril Deposit", "Mountain Silversage", "Ooze Covered Rich Thorium Vein", "Ooze Covered Truesilver Deposit", "Small Thorium Vein", "Sungrass", "Truesilver Deposit" },
  [1452] = { "Black Lotus", "Gold Vein", "Icecap", "Mithril Deposit", "Mountain Silversage", "Rich Thorium Vein", "Small Thorium Vein", "Truesilver Deposit" },
}
