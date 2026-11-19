local addonName, ns = ...

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
--   hideUnpriced, ownedFree,
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
  ownedFree = false,
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

-- A reagent: a known vendor price wins, the auction price after that.
function P.ReagentUnitPrice(itemID)
  local vendor = P.VendorPrice(itemID)
  if vendor then
    return vendor, "vendor"
  end
  local auction = P.AuctionPrice(itemID)
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
      db.vendor[itemID] = price / math.max(1, stack or 1)
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

local function OwnedOf(reagent)
  local total = 0
  for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
    total = total + P.OwnedCount(itemID)
  end
  return total
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
    reagent.buyPrice, reagent.craftPrice, reagent.craftRecipe = unit, nil, nil
    if crafts then
      local craftID
      for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
        local craftUnit, recipe = CraftUnitCost(crafts, itemID, 1, visiting)
        if craftUnit and (reagent.craftPrice == nil or craftUnit < reagent.craftPrice) then
          reagent.craftPrice, reagent.craftRecipe, craftID = craftUnit, recipe.name, itemID
        end
      end
      if reagent.craftPrice and (unit == nil or reagent.craftPrice < unit) then
        unit, source, chosenID = reagent.craftPrice, "craft", craftID
      end
    end
    reagent.unitPrice, reagent.source, reagent.chosenItemID = unit, source, chosenID

    local toBuy = reagent.count
    reagent.owned = nil
    if ownedFree then
      reagent.owned = OwnedOf(reagent)
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

function P.PlayerKey()
  local name = UnitName("player")
  return (GetRealmName() or "?") .. "-" .. (name or "?")
end

function P.Me()
  local db = P.DB()
  local key = P.PlayerKey()
  local me = db.characters[key]
  if not me then
    me = { recipes = {}, profs = {} }
    db.characters[key] = me
  end
  me.recipes = me.recipes or {}
  me.profs = me.profs or {}
  me.name = UnitName("player")
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
          name = char.name or key:match("%-(.+)$") or key, mine = key == mine, reagents = entry.reagents }
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

-- Adds (delta > 0) or removes crafts of a recipe; the reagents are kept with it.
function P.ChangeQueue(entry, delta)
  local queue = P.Queue()
  local queued = queue[entry.name]
  if not queued then
    if delta <= 0 then
      return
    end
    queued = { count = 0, reagents = {} }
    for _, reagent in ipairs(entry.reagents) do
      local itemID = reagent.chosenItemID or reagent.itemID
      table.insert(queued.reagents, { name = reagent.name or P.ItemName(itemID), itemID = itemID,
        count = reagent.count })
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

-- Reagents for every queued craft, minus what you already own, by name.
function P.ReagentsToBuy()
  local needed, order = {}, {}
  for _, queued in pairs(P.Queue()) do
    for _, reagent in ipairs(queued.reagents) do
      local key = reagent.itemID or reagent.name
      if key then
        if not needed[key] then
          needed[key] = { name = reagent.name, itemID = reagent.itemID, count = 0 }
          table.insert(order, key)
        end
        needed[key].count = needed[key].count + reagent.count * queued.count
      end
    end
  end
  local toBuy = {}
  for _, key in ipairs(order) do
    local reagent = needed[key]
    local missing = reagent.count - P.OwnedCount(reagent.itemID)
    if missing > 0 then
      table.insert(toBuy, { name = reagent.name or P.ItemName(reagent.itemID), itemID = reagent.itemID,
        count = missing })
    end
  end
  table.sort(toBuy, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return toBuy
end

-- Writes the reagents still needed into the Codex shopping list "Professions" (Auction House module), one
-- exact-name term per reagent. Returns the list (nil when there was nothing to write).
function P.CreateShoppingList()
  if P.QueueTotal() == 0 then
    ns.Say("right-click recipes in the profit list to queue them first.")
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
    ns.Say("you already have every reagent for your queued crafts.")
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
  local message = ("shopping list \"%s\" has %d reagent(s) to buy; at the auction house click it in the Codex panel.")
    :format(P.LIST_NAME, #names)
  if not ns.ModuleOn("auction") then
    message = message .. " Switch the Auction House module on to search it."
  end
  if unnamed > 0 then
    message = message .. (" %d reagent(s) were left out because their names haven't loaded yet; try again."):format(unnamed)
  end
  ns.Say(message)
  return list
end
