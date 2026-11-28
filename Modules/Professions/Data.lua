local addonName, ns = ...
local L = ns.L

-- Professions module, part 1: prices, the profit of a recipe, make or buy, the recipes each character
-- knows, vendor prices and the craft queue. Ported from Tylesser - Auctionator Profit Sort (same author,
-- MIT), but every price comes from Codex itself: auction prices from the Auction House module's database
-- (ns.auction.GetPrice), vendor prices from what Codex saw at merchants. No Auctionator or TSM.
-- Nothing here creates frames or registers events.
--
-- CodexDB.professions = {
--   characters = { ["Realm-Name"] = { name, class, profs = { [profession] = time() },
--     recipes = { [product itemID] = { { name, numMade, prof, reagents = { { itemID, count, alternatives } } } } } } },
--   vendor = { [itemID] = unit price a merchant sells it for (copper) },
--   queue = { [recipe name] = { count, reagents = { { name, itemID, count } } } },
--   block, panel, tooltip, tooltipValue, craftReagents, ahCut (percent), sortKey, ascending, craftableOnly,
--   hideUnpriced, minProfitOn, minProfit (copper), ownedFree, ownedAlts, listedOften, cooldownNote,
--   cooldowns = { ["Realm-Name"] = { name, class, recipes = { [recipe name] = { readyAt, prof, icon, charges,
--     maxCharges, told } } } },  -- crafting cooldowns (Cooldowns.lua)
-- }

local P = {}
ns.professions = P

P.DEFAULTS = {
  block = true,         -- cost / value / profit block in the profession window
  panel = true,         -- profit list docked beside the profession window
  tooltip = true,       -- "Craft cost" and "Craft profit" in item tooltips
  tooltipValue = true,  -- "AH value" in tooltips while the Auction House module shows no price line
  craftReagents = true, -- make or buy: craft a reagent when that is cheaper than buying it
  ahCut = 5,            -- auction house cut, percent
  sortKey = "profit",
  ascending = false,
  craftableOnly = false,
  hideUnpriced = false,
  minProfitOn = false,  -- hide recipes that earn less than minProfit per craft (and every loss)
  minProfit = 0,        -- copper
  ownedFree = false,
  ownedAlts = false,    -- Owned free also counts your other characters' reagents (Codex Bags, else Syndicator)
  listedOften = false,  -- profit list: only items Codex saw up for sale on at least half the scanned days
  cooldownNote = true,  -- a chat line when a crafting cooldown of this character is ready
  cooldowns = {},
  characters = {},
  vendor = {},
  queue = {},
}

P.LIST_NAME = "Professions" -- the Codex shopping list the craft queue writes
P.MAX_CRAFT_DEPTH = 3

function P.DB()
  if not ns.db then
    return nil
  end
  if not P.db or ns.db.professions ~= P.db then
    ns.db.professions = ns.Fill(ns.db.professions or {}, P.DEFAULTS)
    P.db = ns.db.professions
  end
  return P.db
end

-- Not nil and not a secret value.
local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end
P.Readable = Readable

-- Items ---------------------------------------------------------------------------------------------------

function P.ItemIDFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

function P.ItemLinkOrNil(link)
  if type(link) == "string" and link:find("|Hitem:", 1, true) then
    return link
  end
  return nil
end

function P.ItemName(itemID)
  if not itemID then
    return nil
  end
  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name then
      return name
    end
  end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  return getInfo and (getInfo(itemID)) or nil
end

function P.OwnedCount(itemID)
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not itemID or not count then
    return 0
  end
  return count(itemID, true) or 0
end

-- Your other characters' reagents (2026-11-28): on this realm and faction (the ones you can mail), from the Bags
-- module's records (bags and bank) while it runs, else from Syndicator's public API (bags, bank and mail). The
-- current character is left out (P.OwnedCount counts it). Cached a few seconds: a refresh asks for every reagent.
local altCache, altCacheTime = {}, -math.huge

local function SyndicatorAlts(itemID)
  local api = Syndicator and Syndicator.API
  if not (api and api.GetInventoryInfoByItemID) then
    return nil
  end
  if api.IsReady then
    local ok, ready = pcall(api.IsReady)
    if not (ok and ready) then
      return nil
    end
  end
  local ok, info = pcall(api.GetInventoryInfoByItemID, itemID, true, true)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local currentOk, current = pcall(api.GetCurrentCharacter or function() return nil end)
  current = currentOk and current or nil
  local list = {}
  for _, char in ipairs(info.characters or {}) do
    local name = char.character
    if type(name) == "string" then
      local realm = char.realmNormalized
      local full = (realm and realm ~= "") and (name .. "-" .. realm) or name
      local count = (char.bags or 0) + (char.bank or 0) + (char.mail or 0)
      if full ~= current and count > 0 then
        list[#list + 1] = { name = name, count = count }
      end
    end
  end
  return list
end

local function BagsOn()
  local B = ns.bags
  return B and B.CharacterKeys and B.CountsOf and B.Character and ns.ModuleOn and ns.ModuleOn("bags") and true or false
end

local function BagsAlts(itemID)
  if not BagsOn() then
    return nil
  end
  local B = ns.bags
  local mine, realm = ns.CharacterKey(), ns.RealmName()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local list = {}
  for _, key in ipairs(B.CharacterKeys(false)) do
    local char = key ~= mine and B.Character(key)
    if char and (char.realm or key:match("^(.-)%-")) == realm and (not char.faction or char.faction == faction) then
      local counts = B.CountsOf(key)[itemID]
      local count = counts and ((counts.bags or 0) + (counts.bank or 0)) or 0
      if count > 0 then
        list[#list + 1] = { name = ns.CharacterDisplayName(char, key), count = count }
      end
    end
  end
  return list
end

-- How many of an item your other characters have, and { { name, count }, ... } most first.
function P.AltOwned(itemID)
  if not itemID then
    return 0, {}
  end
  local now = GetTime and GetTime() or 0
  if now - altCacheTime > 5 then
    altCache, altCacheTime = {}, now
  end
  local cached = altCache[itemID]
  if not cached then
    local list = BagsAlts(itemID) or SyndicatorAlts(itemID) or {}
    local total = 0
    for _, char in ipairs(list) do
      total = total + char.count
    end
    table.sort(list, function(a, b)
      if a.count ~= b.count then
        return a.count > b.count
      end
      return a.name < b.name
    end)
    cached = { total = total, list = list }
    altCache[itemID] = cached
  end
  return cached.total, cached.list
end

-- Where your other characters' counts come from: "bags" (the Bags module), "syndicator" or nil (nowhere).
function P.AltSource()
  if BagsOn() then
    return "bags"
  end
  local api = Syndicator and Syndicator.API
  return (api and api.GetInventoryInfoByItemID) and "syndicator" or nil
end

-- "Ann 5, Bob 2" (at most four, then "...").
function P.AltText(list)
  local parts = {}
  for index, char in ipairs(list or {}) do
    if index > 4 then
      parts[#parts + 1] = "..."
      break
    end
    parts[#parts + 1] = char.name .. " " .. char.count
  end
  return table.concat(parts, ", ")
end

-- Prices --------------------------------------------------------------------------------------------------

-- Share of a sale you keep after the auction house cut (0.95 for 5%).
function P.Keep()
  local cut = P.db and P.db.ahCut or 5
  return 1 - math.max(0, math.min(50, cut)) / 100
end

-- Lowest unit buyout Codex saw on this realm and when; nil without a price.
function P.AuctionPrice(item)
  local A = ns.auction
  if item == nil or not (A and A.GetPrice) then
    return nil
  end
  local ok, price, seen = pcall(A.GetPrice, item)
  if ok and price then
    return price, seen
  end
  return nil
end

-- Product price: the full link first (gear variants), the bare item ID after that.
local function ProductPrice(link, itemID)
  local price, seen
  if link then
    price, seen = P.AuctionPrice(link)
  end
  if not price and itemID then
    price, seen = P.AuctionPrice(itemID)
  end
  return price, seen
end
P.ProductPrice = ProductPrice

function P.VendorPrice(itemID)
  local vendor = P.db and P.db.vendor
  return vendor and itemID and vendor[itemID] or nil
end

-- A reagent: the cheaper of a known vendor price and the auction price. Some vendors sell reagents far above
-- the auction house (the Black Market), so a vendor price alone must not win.
function P.ReagentUnitPrice(itemID)
  local vendor = P.VendorPrice(itemID)
  local auction = P.AuctionPrice(itemID)
  if vendor and (not auction or vendor <= auction) then
    return vendor, "vendor"
  end
  if auction then
    return auction, "auction"
  end
  return nil, "missing"
end

-- What the open merchant sells, per unit (items for gold only).
function P.RecordMerchant()
  local db = P.db
  local count = GetMerchantNumItems and GetMerchantNumItems() or 0
  if not db or not Readable(count) then
    return 0
  end
  local recorded = 0
  for index = 1, count do
    local price, stack, extended
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
      local info = C_MerchantFrame.GetItemInfo(index)
      if info then
        price, stack, extended = info.price, info.stackCount, info.hasExtendedCost
      end
    elseif GetMerchantItemInfo then
      local _
      _, _, price, stack, _, _, _, extended = GetMerchantItemInfo(index)
    end
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    local itemID = Readable(link) and P.ItemIDFromLink(link)
    if itemID and Readable(price) and Readable(stack) and type(price) == "number" and price > 0 and not extended then
      local unit = price / math.max(1, stack or 1)
      -- Keep the lowest price seen: the same item can cost far more at another merchant.
      if not db.vendor[itemID] or unit < db.vendor[itemID] then
        db.vendor[itemID] = unit
      end
      recorded = recorded + 1
    end
  end
  return recorded
end

-- Make or buy -----------------------------------------------------------------------------------------------
-- A reagent that another known recipe makes can be crafted instead of bought: its craft cost is that recipe's
-- cost / amount made, its own reagents again bought or crafted, whichever is cheaper (up to MAX_CRAFT_DEPTH,
-- with a cycle guard). An index is { byItem = { [itemID] = { recipe, ... } }, buyPrices = {} }; recipes need
-- name, numMade and reagents = { { itemID, count, alternatives } }. Index recipes are only read.

function P.BuildCraftIndex(entries)
  local index = { byItem = {}, buyPrices = {} }
  for _, entry in ipairs(entries) do
    if entry.itemID and entry.numMade and entry.numMade > 0 and entry.reagents and #entry.reagents > 0 then
      local list = index.byItem[entry.itemID]
      if not list then
        list = {}
        index.byItem[entry.itemID] = list
      end
      table.insert(list, entry)
    end
  end
  return index
end

local function BuyPrice(index, itemID)
  local cached = index.buyPrices[itemID]
  if cached == nil then
    cached = P.ReagentUnitPrice(itemID) or false
    index.buyPrices[itemID] = cached
  end
  return cached or nil
end

local CraftUnitCost

local function SlotUnitCost(index, reagent, depth, visiting)
  local best
  for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
    local unit = BuyPrice(index, itemID)
    local craft = CraftUnitCost(index, itemID, depth, visiting)
    if craft and (unit == nil or craft < unit) then
      unit = craft
    end
    if unit and (best == nil or unit < best) then
      best = unit
    end
  end
  return best
end

function CraftUnitCost(index, itemID, depth, visiting)
  if not itemID or depth > P.MAX_CRAFT_DEPTH or visiting[itemID] then
    return nil
  end
  local recipes = index.byItem[itemID]
  if not recipes then
    return nil
  end
  visiting[itemID] = true
  local best, bestRecipe
  for _, recipe in ipairs(recipes) do
    local cost = 0
    for _, reagent in ipairs(recipe.reagents) do
      local unit = SlotUnitCost(index, reagent, depth + 1, visiting)
      if not unit then
        cost = nil
        break
      end
      cost = cost + unit * reagent.count
    end
    if cost and (recipe.numMade or 0) > 0 then
      local unitCost = cost / recipe.numMade
      if best == nil or unitCost < best then
        best, bestRecipe = unitCost, recipe
      end
    end
  end
  visiting[itemID] = nil
  return best, bestRecipe
end

function P.CraftUnitCost(index, itemID)
  return CraftUnitCost(index, itemID, 1, {})
end

-- Estimated chance of a skill point by recipe colour (orange 100%, yellow ~75%, green ~25%).
P.SKILL_CHANCE = { optimal = 1, medium = 0.75, easy = 0.25, trivial = 0 }

-- With alts, also your other characters' (the second value lists them).
local function OwnedOf(reagent, alts)
  local total, where = 0, nil
  for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
    total = total + P.OwnedCount(itemID)
    if alts then
      local count, list = P.AltOwned(itemID)
      if count > 0 then
        total = total + count
        where = where or {}
        for _, char in ipairs(list) do
          where[#where + 1] = char
        end
      end
    end
  end
  return total, where
end

-- Fills in cost / value / profit / margin of a recipe entry (see Providers.lua for its shape). The reagent
-- tables get unitPrice, source ("vendor", "auction", "craft"), chosenItemID, buyPrice, craftPrice, owned,
-- toBuy. With ownedFree, reagents in your bags and bank cost nothing. entry.fullCost is the cost without
-- Owned free; entry.missingReagents / fullCostMissing: a reagent had no price.
function P.Evaluate(entry, ownedFree, crafts)
  local cost, fullCost, missing, fullMissing = 0, 0, false, false
  local visiting
  if crafts then
    visiting = {}
    if entry.itemID then
      visiting[entry.itemID] = true
    end
  end
  for _, reagent in ipairs(entry.reagents) do
    local unit, source = P.ReagentUnitPrice(reagent.itemID)
    local chosenID = reagent.itemID
    if reagent.alternatives then -- reagents in several qualities: the cheapest one
      for _, altID in ipairs(reagent.alternatives) do
        local altUnit, altSource = P.ReagentUnitPrice(altID)
        if altUnit and (unit == nil or altUnit < unit) then
          unit, source, chosenID = altUnit, altSource, altID
        end
      end
    end
    reagent.buyPrice, reagent.craftPrice, reagent.craftRecipe, reagent.craftEntry = unit, nil, nil, nil
    if crafts then
      local craftID
      for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
        local craftUnit, recipe = CraftUnitCost(crafts, itemID, 1, visiting)
        if craftUnit and (reagent.craftPrice == nil or craftUnit < reagent.craftPrice) then
          -- craftEntry: the recipe that makes it, for the shopping list (expanded in P.ReagentsToBuy)
          reagent.craftPrice, reagent.craftRecipe, reagent.craftEntry, craftID = craftUnit, recipe.name, recipe, itemID
        end
      end
      if reagent.craftPrice and (unit == nil or reagent.craftPrice < unit) then
        unit, source, chosenID = reagent.craftPrice, "craft", craftID
      end
    end
    reagent.unitPrice, reagent.source, reagent.chosenItemID = unit, source, chosenID

    local toBuy = reagent.count
    reagent.owned, reagent.ownedAlts = nil, nil
    if ownedFree then
      reagent.owned, reagent.ownedAlts = OwnedOf(reagent, P.db and P.db.ownedAlts)
      toBuy = math.max(0, reagent.count - reagent.owned)
    end
    reagent.toBuy = toBuy
    if unit then
      fullCost = fullCost + unit * reagent.count
    elseif reagent.count > 0 then
      fullMissing = true
    end
    if toBuy > 0 then
      if unit then
        cost = cost + unit * toBuy
      else
        missing = true
      end
    end
  end

  entry.cost, entry.fullCost = cost, fullCost
  entry.missingReagents, entry.fullCostMissing = missing, fullMissing
  entry.ownedFree = ownedFree and true or false
  local chance = entry.difficulty and P.SKILL_CHANCE[entry.difficulty]
  entry.skillChance = chance
  if chance and chance > 0 then
    entry.skillCost = cost / (chance * (entry.skillUps or 1))
  else
    entry.skillCost = nil
  end

  local unitAH, seen = ProductPrice(entry.link, entry.itemID)
  entry.unitAH, entry.seen = unitAH, seen
  if unitAH then
    entry.value = math.floor(unitAH * (entry.numMade or 1) * P.Keep())
    entry.profit = entry.value - cost
    entry.margin = cost > 0 and entry.profit / cost or nil
  else
    entry.value, entry.profit, entry.margin = nil, nil, nil
  end
end

-- Entries without a value for the sort key always go to the bottom.
function P.SortEntries(entries, key, ascending)
  table.sort(entries, function(a, b)
    local va, vb = a[key], b[key]
    if va == nil or vb == nil or va == vb then
      if va ~= nil and vb == nil then
        return true
      elseif va == nil and vb ~= nil then
        return false
      end
      return (a.name or "") < (b.name or "")
    end
    if ascending then
      return va < vb
    end
    return va > vb
  end)
end

-- Money with a sign: "-1g 20s" in red for a loss; "--" for nil.
-- "1g 50s", "75s", "2.5g", "30c" -> copper. A number without g, s or c is silver. nil when the text isn't money.
function P.ParseMoney(text)
  text = tostring(text or ""):lower():gsub(",", ".")
  if not text:find("%d") then
    return text:match("^%s*$") and 0 or nil
  end
  local total, bare = 0, 0
  local rest = text:gsub("(%d*%.?%d+)%s*([gsc]?)", function(number, unit)
    local factor = unit == "g" and 10000 or unit == "c" and 1 or 100
    if unit == "" then
      bare = bare + 1
    end
    total = total + tonumber(number) * factor
    return ""
  end)
  if bare > 1 or rest:find("%S") then
    return nil
  end
  return math.floor(total + 0.5)
end

-- Exact money text for an input box: "1g 5s 20c", "75s", "0".
function P.PlainMoney(copper)
  copper = math.max(0, math.floor(copper or 0))
  local parts = {}
  local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if copper % 100 > 0 then
    parts[#parts + 1] = (copper % 100) .. "c"
  end
  return #parts > 0 and table.concat(parts, " ") or "0"
end

function P.Money(amount, plus)
  if amount == nil then
    return "|cff808080--|r"
  end
  if amount < 0 then
    return "|cffff5050-|r" .. ns.Money(-amount)
  end
  return (plus and "|cff40ff40+|r" or "") .. ns.Money(amount)
end

-- Compact money for the profit list's narrow columns: "1g 17s" with gold, "94s 72c" below 1g, "72c".
function P.ShortMoney(amount)
  if amount == nil then
    return "|cff808080--|r"
  end
  local sign = amount < 0 and "|cffff5050-|r" or ""
  amount = math.floor(math.abs(amount) + 0.5)
  local gold, silver, copper = math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100
  local hex = ns.MoneyHex and ns.MoneyHex() -- the theme's money colour (Dusk, Dawn), else the game's coin colours
  local G, S, C = "|cff" .. (hex or "ffd100") .. "%sg|r", "|cff" .. (hex or "c7c7cf") .. "%ds|r",
    "|cff" .. (hex or "eda55f") .. "%dc|r"
  local text
  if gold > 0 then
    text = G:format(BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or gold)
    if silver > 0 then
      text = text .. " " .. S:format(silver)
    end
  elseif silver > 0 then
    text = S:format(silver)
    if copper > 0 then
      text = text .. " " .. C:format(copper)
    end
  else
    text = C:format(copper)
  end
  return sign .. text
end

function P.Margin(margin)
  if margin == nil then
    return "|cff808080--|r"
  end
  local pct = math.floor(margin * 100 + 0.5)
  return (pct >= 0 and "|cff40ff40%d%%|r" or "|cffff5050%d%%|r"):format(pct)
end

-- Recipe knowledge ----------------------------------------------------------------------------------------
-- Kept per character (account-wide, so tooltips can say an alt can make an item) and only read from the
-- profession window of your own character, never a linked or guild one.

-- "Realm-Name" without a surname (ns.CharacterKey)
function P.PlayerKey()
  return ns.CharacterKey()
end

function P.Me()
  local db = P.DB()
  local key = P.PlayerKey()
  -- older records of this character under another spelling of its name (with the surname) join this one
  if not P.merged then
    P.merged = true
    ns.MergeCharacterRecords(db.characters, key)
  end
  local me = db.characters[key]
  if not me then
    me = { recipes = {}, profs = {} }
    db.characters[key] = me
  end
  me.recipes = me.recipes or {}
  me.profs = me.profs or {}
  me.name = ns.PlayerName()
  ns.StoreFullName(me)
  me.class = select(2, UnitClass("player"))
  return me, key
end

-- Stores the recipes of one scan. complete = the scan holds every recipe of the profession (the modern
-- window), so recipes of that profession that are gone are dropped; otherwise records are only added or
-- replaced (a classic window lists only what its filters and collapsed headers show).
function P.RememberRecipes(entries, prof, complete)
  if not prof or #entries == 0 then
    return 0
  end
  local me = P.Me()
  local recipes = me.recipes
  local function Drop(itemID, test)
    local list = recipes[itemID]
    if not list then
      return
    end
    for i = #list, 1, -1 do
      if test(list[i]) then
        table.remove(list, i)
      end
    end
    if #list == 0 then
      recipes[itemID] = nil
    end
  end
  if complete then
    for itemID in pairs(recipes) do
      Drop(itemID, function(record)
        return record.prof == prof
      end)
    end
  end
  local stored = 0
  for _, entry in ipairs(entries) do
    local reagents, whole = {}, entry.itemID ~= nil and #entry.reagents > 0
    for _, reagent in ipairs(entry.reagents) do
      if not reagent.itemID then
        whole = false -- a reagent the game hasn't loaded yet: a cost without it would be too low
        break
      end
      reagents[#reagents + 1] = { itemID = reagent.itemID, count = reagent.count, alternatives = reagent.alternatives }
    end
    if whole then
      Drop(entry.itemID, function(record)
        return record.prof == prof and record.name == entry.name
      end)
      recipes[entry.itemID] = recipes[entry.itemID] or {}
      table.insert(recipes[entry.itemID], { name = entry.name, numMade = entry.numMade or 1, prof = prof,
        reagents = reagents })
      stored = stored + 1
    end
  end
  me.profs[prof] = time()
  return stored
end

-- Character keys with recipes: this character first, then by name.
function P.CharacterKeys()
  local db = P.DB()
  local mine = P.PlayerKey()
  local keys = {}
  for key, char in pairs(db.characters) do
    if key ~= mine and next(char.recipes or {}) then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  if db.characters[mine] then
    table.insert(keys, 1, mine)
  end
  return keys
end

function P.RecipeCount(char)
  local count = 0
  for _, list in pairs(char and char.recipes or {}) do
    count = count + #list
  end
  return count
end

-- Fully priced recipes first, then the cheapest per item made.
local function Better(a, b)
  if not b then
    return true
  end
  local aFull, bFull = a.cost ~= nil and not a.missing, b.cost ~= nil and not b.missing
  if aFull ~= bFull then
    return aFull
  end
  if a.cost and b.cost then
    return a.cost / a.numMade < b.cost / b.numMade
  end
  return a.cost ~= nil and b.cost == nil
end

-- Craft cost of an item from the recipes one character knows: { cost, missing, numMade, recipe, key, name,
-- mine }. cost is per craft (nil when no reagent has a price); missing = some reagent has no price.
-- This character's recipes are used when it knows the item, otherwise the first other character that does.
function P.CraftInfo(itemID)
  local db = P.DB()
  if not db or not itemID then
    return nil
  end
  local mine = P.PlayerKey()
  for _, key in ipairs(P.CharacterKeys()) do
    local char = db.characters[key]
    local list = char.recipes[itemID]
    if list and #list > 0 then
      local crafts = db.craftReagents and { byItem = char.recipes, buyPrices = {} } or nil
      local best
      for _, record in ipairs(list) do
        -- a copy: Evaluate writes into the reagent tables, and these are saved
        local entry = { itemID = itemID, name = record.name, numMade = record.numMade or 1, reagents = {} }
        for _, reagent in ipairs(record.reagents) do
          entry.reagents[#entry.reagents + 1] = { itemID = reagent.itemID, count = reagent.count,
            alternatives = reagent.alternatives }
        end
        P.Evaluate(entry, false, crafts)
        local priced = entry.fullCost > 0 or not entry.fullCostMissing
        local candidate = { cost = priced and entry.fullCost or nil, missing = entry.fullCostMissing,
          numMade = entry.numMade, recipe = record.name, prof = record.prof, key = key,
          name = ns.CharacterDisplayName(char, key), mine = key == mine, reagents = entry.reagents }
        if Better(candidate, best) then
          best = candidate
        end
      end
      return best
    end
  end
  return nil
end

-- Craft queue and the Codex shopping list ------------------------------------------------------------------

function P.Queue()
  return P.DB().queue
end

function P.QueuedCount(entry)
  local queued = P.Queue()[entry.name]
  return queued and queued.count or 0
end

function P.QueueTotal()
  local total = 0
  for _, queued in pairs(P.Queue()) do
    total = total + queued.count
  end
  return total
end

-- One reagent of a queued craft, as saved: { name, itemID, count }, and for a reagent that make or buy chose to
-- craft also { recipe, made = average amount one craft makes, reagents = { ...the same, one level down } }. A
-- plain copy: the scan's tables must not go into the saved variables.
local function Plan(reagent, depth, visiting)
  local itemID = reagent.chosenItemID or reagent.itemID
  local node = { name = reagent.name or P.ItemName(itemID), itemID = itemID, count = reagent.count }
  local recipe = reagent.craftEntry
  if reagent.source == "craft" and recipe and recipe.reagents and (recipe.numMade or 0) > 0
    and depth <= P.MAX_CRAFT_DEPTH and itemID and not visiting[itemID] then
    visiting[itemID] = true
    node.recipe, node.made, node.reagents = recipe.name, recipe.numMade, {}
    for _, sub in ipairs(recipe.reagents) do
      node.reagents[#node.reagents + 1] = Plan(sub, depth + 1, visiting)
    end
    visiting[itemID] = nil
  end
  return node
end
P.PlanReagent = Plan

-- Adds (delta > 0) or removes crafts of a recipe; the reagents are kept with it.
function P.ChangeQueue(entry, delta)
  local queue = P.Queue()
  local queued = queue[entry.name]
  if not queued then
    if delta <= 0 then
      return
    end
    queued = { count = 0, reagents = {} }
    local visiting = {}
    if entry.itemID then
      visiting[entry.itemID] = true
    end
    for _, reagent in ipairs(entry.reagents) do
      table.insert(queued.reagents, Plan(reagent, 1, visiting))
    end
    queue[entry.name] = queued
  end
  queued.count = queued.count + delta
  if queued.count <= 0 then
    queue[entry.name] = nil
  end
end

function P.ClearQueue()
  P.DB().queue = {}
end

-- Reagents to buy for every queued craft. What you own (bags and bank) is used first; a reagent that make or
-- buy crafts is replaced by what crafting the rest of it takes, one level down at a time (crafts rounded up).
-- Returns the reagents to buy by name and { { name, itemID, count = how many to craft, recipe } } to craft.
function P.ReagentsToBuy()
  local stock = {}
  local buy, buyOrder, craft, craftOrder = {}, {}, {}, {}
  local function Take(itemID, amount)
    if not itemID then
      return 0
    end
    if stock[itemID] == nil then
      stock[itemID] = P.OwnedCount(itemID)
    end
    local used = math.min(stock[itemID], amount)
    stock[itemID] = stock[itemID] - used
    return used
  end
  local function Need(node, amount)
    local rest = amount - Take(node.itemID, amount)
    local key = node.itemID or node.name
    if rest <= 0 or not key then
      return
    end
    if node.reagents and (node.made or 0) > 0 then
      local crafts = math.ceil(rest / node.made - 1e-9)
      if not craft[key] then
        craft[key] = { name = node.name, itemID = node.itemID, recipe = node.recipe, count = 0 }
        craftOrder[#craftOrder + 1] = key
      end
      craft[key].count = craft[key].count + crafts
      for _, sub in ipairs(node.reagents) do
        Need(sub, (sub.count or 0) * crafts)
      end
      return
    end
    if not buy[key] then
      buy[key] = { name = node.name, itemID = node.itemID, count = 0 }
      buyOrder[#buyOrder + 1] = key
    end
    buy[key].count = buy[key].count + rest
  end
  -- the same order every time (pairs has none), so what you own goes to the same crafts
  local names = {}
  for name in pairs(P.Queue()) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local queued = P.Queue()[name]
    for _, reagent in ipairs(queued.reagents) do
      Need(reagent, (reagent.count or 0) * queued.count)
    end
  end
  local function List(byKey, order)
    local list = {}
    for _, key in ipairs(order) do
      local item = byKey[key]
      item.name = item.name or P.ItemName(item.itemID)
      list[#list + 1] = item
    end
    table.sort(list, function(a, b)
      return (a.name or "") < (b.name or "")
    end)
    return list
  end
  return List(buy, buyOrder), List(craft, craftOrder)
end

-- Writes the reagents still needed into the Codex shopping list "Professions" (Auction House module), one
-- exact-name term per reagent. Returns the list (nil when there was nothing to write).
function P.CreateShoppingList()
  if P.QueueTotal() == 0 then
    ns.Say(L["right-click recipes in the profit list to queue them first."])
    return nil
  end
  local names, unnamed = {}, 0
  for _, reagent in ipairs(P.ReagentsToBuy()) do
    if reagent.name then
      names[#names + 1] = reagent.name
    else
      unnamed = unnamed + 1
    end
  end
  if #names == 0 and unnamed == 0 then
    ns.Say(L["you already have every reagent for your queued crafts."])
    return nil
  end
  local A = ns.auction
  if not (A and A.DB and A.DB()) then
    return nil
  end
  local list
  for _, existing in ipairs(A.Lists()) do
    if existing.name == P.LIST_NAME then
      list = existing
      break
    end
  end
  list = list or A.NewList(P.LIST_NAME)
  for index = #list.terms, 1, -1 do -- replaced, not added to
    list.terms[index] = nil
  end
  for _, name in ipairs(names) do
    A.AddTerm(list, name, true, nil)
  end
  A.Changed("lists")
  local message = L["shopping list \"%s\" has %d reagent(s) to buy; at the auction house click it in the Codex panel."]
    :format(P.LIST_NAME, #names)
  if not ns.ModuleOn("auction") then
    message = message .. " " .. L["Switch the Auction House module on to search it."]
  end
  if unnamed > 0 then
    message = message .. " " .. L["%d reagent(s) were left out because their names haven't loaded yet; try again."]:format(unnamed)
  end
  ns.Say(message)
  return list
end
