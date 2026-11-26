local addonName, ns = ...

-- Auction house module, part 2b: items on sale for less than a vendor pays for them (2026-11-26). A full scan
-- notes every auction whose price per item is under the item's vendor sell price; browsing and searching keep
-- the list current (an item bought up or sold out leaves it), and every saved price under the vendor price
-- joins it without a scan (A.AllBelow). The Codex panel beside the auction house shows
-- it; clicking an item opens it in the game's buy view. Nothing is bought or sold for the player.
--
-- CodexDB.auction.realms[realm].below = {
--   t = when the full scan behind it finished,
--   items = { [itemID] = { l = lowest price per item, s = vendor sell price per item,
--                          u = items under the vendor price (nil: not counted, seen while browsing),
--                          p = what selling all of them to a vendor makes over their price } },
-- }

local A = ns.auction

-- The vendor's price for one (C_Item.GetItemInfo's 11th value; nil while the item's data isn't loaded).
function A.SellPrice(item)
  local getInfo = A.ItemApi("GetItemInfo")
  if not getInfo or not item then
    return nil
  end
  local ok, sell = pcall(function()
    return select(11, getInfo(item))
  end)
  return ok and type(sell) == "number" and sell or nil
end

local function Add(items, key, unit, count, sell)
  if not sell or sell <= 0 or unit >= sell then
    return
  end
  local entry = items[key]
  if not entry then
    entry = { l = unit, s = sell, u = 0, p = 0 }
    items[key] = entry
  end
  entry.l = math.min(entry.l, unit)
  entry.u = (entry.u or 0) + count
  entry.p = (entry.p or 0) + (sell - unit) * count
end

-- One auction of a full scan (Scan.lua's ReadAuction). Items whose data hasn't loaded yet wait for the end.
function A.NoteBelow(scan, key, itemID, unit, count, link)
  if type(key) ~= "number" or not scan.below then
    return
  end
  local sell = A.SellPrice(link or itemID)
  if sell then
    Add(scan.below, key, unit, count, sell)
    return
  end
  local wait = scan.sellWait[key]
  if not wait then
    wait = {}
    scan.sellWait[key] = wait
    if C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(itemID)
    end
  end
  wait[#wait + 1] = unit
  wait[#wait + 1] = count
end

local function Settle(items, waiting)
  local left
  for key, wait in pairs(waiting) do
    local sell = A.SellPrice(key)
    if sell then
      for index = 1, #wait, 2 do
        Add(items, key, wait[index], wait[index + 1], sell)
      end
    else
      left = left or {}
      left[key] = wait
    end
  end
  return left
end

local function Count(items)
  local count = 0
  for _ in pairs(items or {}) do
    count = count + 1
  end
  return count
end

-- At the end of a full scan: the new list replaces the old one. Items whose sell price was still loading get
-- another look every few seconds (five at most). Returns how many items are below the vendor price.
function A.SaveBelow(scan, when)
  local realm = A.Realm(true)
  if not scan.below then
    return Count(realm.below and realm.below.items)
  end
  local saved = { t = when, items = scan.below }
  realm.below = saved
  local left = Settle(saved.items, scan.sellWait or {})
  local tries = 0
  local function Again()
    tries = tries + 1
    if left and tries <= 5 and C_Timer and C_Timer.After then
      C_Timer.After(3, function()
        if realm.below == saved then
          left = Settle(saved.items, left)
          A.Changed("below")
          Again()
        end
      end)
    end
  end
  Again()
  A.Changed("below")
  return Count(saved.items)
end

local function Items(create)
  local realm = A.Realm(create)
  if not realm then
    return nil
  end
  if not realm.below and create then
    realm.below = { items = {} }
  end
  return realm.below and realm.below.items
end

-- Every auction of one item, from a search (commodity or item buy view): { { price per item, count }, ... }.
-- The list then holds exactly what is under the vendor price now; nothing left takes the item off.
function A.SearchBelow(key, auctions)
  if type(key) ~= "number" then
    return
  end
  local sell = A.SellPrice(key)
  if not sell or sell <= 0 then
    return
  end
  local items = Items(false)
  local cheap = items and items[key] ~= nil -- (on the list: the search may take it off)
  for _, auction in ipairs(auctions) do
    cheap = cheap or auction[1] < sell
  end
  if not cheap then
    return
  end
  items = Items(true)
  items[key] = nil
  for _, auction in ipairs(auctions) do
    Add(items, key, auction[1], auction[2], sell)
  end
  A.Changed("below")
end

-- A browse result (the game's search or a shopping list): only its lowest price is known. Cheaper than the
-- vendor: the item joins the list (not counted) or its lowest price updates; not cheaper: it leaves the list.
function A.BrowseBelow(key, variant, price)
  if type(key) ~= "number" or not price then
    return
  end
  local sell = A.SellPrice(key)
  if not sell or sell <= 0 then
    return
  end
  local items = Items(false)
  local entry = items and items[key]
  if price < sell then
    if not entry then
      Items(true)[key] = { l = price, s = sell, p = sell - price }
      A.Changed("below")
    elseif price ~= entry.l then
      entry.l = math.min(entry.l, price)
      if not entry.u then
        entry.p = sell - entry.l
      end
      A.Changed("below")
    end
  elseif entry and not variant and not A.IsEquipment(key) then
    -- (gear lists one row per item level: another row may still be cheap)
    items[key] = nil
    A.Changed("below")
  end
end

-- An item key the game's buy view takes (C_AuctionHouse.MakeItemKey, forever AuctionHouseDocumentation).
local function ItemKey(itemID)
  local api = C_AuctionHouse
  if api and api.MakeItemKey then
    local ok, key = pcall(api.MakeItemKey, itemID)
    if ok and key then
      return key
    end
  end
  return { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
end

-- The list for the panel, most profit first. A.db.belowSort "total": the amount made by buying every cheap one
-- and selling it to a vendor; "each": what one item makes (vendor price - lowest price). The row shows the
-- amount it is sorted by. Each row works with A.OpenResult like a shopping list result; gear opens through the
-- game's search box (its rows are per item level, which the list doesn't keep).
function A.BelowSort()
  return A.db and A.db.belowSort == "each" and "each" or "total"
end

-- Items not on the full scan's list whose saved price (the latest seen: scan, browse or search; Data.lua's
-- realm.items) is under the vendor price join it, with their profit for one (how many are up isn't known).
-- So the list works without a recent full scan. Sell prices are kept for the session; items whose data
-- isn't loaded are asked for once and the list is redrawn a moment later.
local sellCache, asked, redraw = {}, {}, false

local function SavedSell(key)
  local sell = sellCache[key]
  if sell == nil then
    sell = A.SellPrice(key)
    if sell then
      sellCache[key] = sell
    elseif not asked[key] then
      asked[key] = true
      if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(key)
        if not redraw and C_Timer and C_Timer.After then
          redraw = true
          C_Timer.After(2, function()
            redraw = false
            A.Changed("below")
          end)
        end
      end
    end
  end
  return sell
end

-- Every item under the vendor price: { [key] = { l, s, u, p, seen } } (seen: when a saved price was seen).
function A.AllBelow()
  local realm = A.Realm(false)
  local all = {}
  if not realm then
    return all
  end
  local listed = realm.below and realm.below.items or {}
  for key, entry in pairs(listed) do
    all[key] = entry
  end
  for key, rec in pairs(realm.items or {}) do
    if type(key) == "number" and not listed[key] and type(rec.m) == "number" and rec.m > 0 then
      local sell = SavedSell(key)
      if sell and sell > 0 and rec.m < sell then
        all[key] = { l = rec.m, s = sell, p = sell - rec.m, seen = rec.t }
      end
    end
  end
  return all
end

function A.BelowRows()
  local each = A.BelowSort() == "each"
  local rows = {}
  for key, entry in pairs(A.AllBelow()) do
    local name, icon, quality = A.ItemInfo(key, true)
    name = name or A.CachedName(key)
    local total = entry.p or 0
    local one = math.max(0, (entry.s or 0) - (entry.l or 0))
    rows[#rows + 1] = {
      key = key, below = entry, name = name or ("Item " .. key), icon = icon, quality = quality,
      count = entry.u or 0, price = entry.l, profit = each and one or total, other = each and total or one,
      deal = true,
      result = not A.IsEquipment(key) and { itemKey = ItemKey(key), minPrice = math.floor(entry.l) } or nil,
    }
  end
  table.sort(rows, function(a, b)
    if a.profit ~= b.profit then
      return a.profit > b.profit
    end
    if a.other ~= b.other then
      return a.other > b.other
    end
    return a.name < b.name
  end)
  return rows
end

-- One line for the panel.
function A.BelowText()
  local count, profit = 0, 0
  for _, entry in pairs(A.AllBelow()) do
    count = count + 1
    profit = profit + (entry.p or 0)
  end
  if count == 0 then
    local realm = A.Realm(false)
    return realm and next(realm.items or {}) and "Nothing below the vendor price." or "Run a full scan to find them."
  end
  return ("%d below vendor: +%s"):format(count, ns.Money(profit))
end

function A.BelowCount()
  return Count(A.AllBelow())
end
