local addonName, ns = ...
local L = ns.L

-- Auction house module, part 2c: the Buy button of "Below vendor" (2026-11-27, the user's wish). One click buys
-- the top item of the list, and only what is still under the vendor price right now:
--   stackable goods (commodities): every unit under the vendor price, in one purchase;
--   other items: the cheapest auction (one item).
-- The game requires a click or key press for every purchase (forever AuctionHouseDocumentation: PlaceBid and
-- StartCommoditiesPurchase have HasRestrictions), so nothing is ever bought without the player's click; the
-- button only buys, it never posts or bids. Gear (one row per item level) isn't bought here.
-- "Stacks only" (the button beside it, A.db.buyStacks) leaves everything but stackable goods (commodities).
--
-- Before the click, the top item is searched (C_AuctionHouse.SendSearchQuery, as Blizzard's buy views do) so the
-- click can buy at once. A commodity purchase asks the server for a quote first (COMMODITY_PRICE_UPDATED with the
-- real total): when someone bought the cheap ones in between and the total is no longer under what a vendor pays
-- (or more than the player has), it is cancelled and nothing is bought. ConfirmCommoditiesPurchase has no
-- restrictions in the forever docs; Blizzard's own buy dialog calls it after the quote too.

local A = ns.auction

local SEARCH_TIMEOUT = 10
local PURCHASE_TIMEOUT = 10

-- state: "idle" | "checking" (the top item's search is out) | "ready" (offer known) | "quote" (waiting for the
-- commodity quote) | "buying" (waiting for the purchase to complete)
A.buy = { state = "idle", gen = 0, skip = {}, bought = 0, spent = 0, profit = 0 }

local function After(seconds, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, fn)
  end
end

local function Money()
  return GetMoney and GetMoney() or 0
end

local function Changed()
  A.Changed("buy")
end

local function Reset(state)
  local buy = A.buy
  buy.gen = buy.gen + 1
  buy.state = state or "idle"
  buy.key, buy.kind, buy.offer, buy.itemKey = nil, nil, nil, nil
end

-- "Stacks only" (the button beside Buy, A.db.buyStacks): only stackable goods, the auction house's commodities.
function A.BuyStacksOnly()
  return A.db and A.db.buyStacks == true or false
end

function A.SetBuyStacksOnly(on)
  A.DB().buyStacks = on and true or false
  if A.buy.state ~= "quote" and A.buy.state ~= "buying" then
    Reset()
    A.PrepareBuy()
  end
  Changed()
end

-- true / false, or nil while unknown (then the search tells: commodities answer with COMMODITY_SEARCH_RESULTS_UPDATED).
-- The item key's isCommodity (forever AuctionHouseDocumentation ItemKeyInfo), else the item's stack size.
local function IsStackable(row)
  local api = C_AuctionHouse
  local ok, info = pcall(api.GetItemKeyInfo or function() end, row.result.itemKey)
  if ok and info and type(info.isCommodity) == "boolean" then
    return info.isCommodity
  end
  local getInfo = A.ItemApi("GetItemInfo")
  if getInfo then
    local okStack, stack = pcall(function()
      return select(8, getInfo(row.key))
    end)
    if okStack and type(stack) == "number" then
      return stack > 1
    end
  end
  return nil
end

-- The item the button buys next: the first row of the list that can be bought here (not gear, not skipped, a
-- stackable one with "Stacks only").
local function Target()
  local stacksOnly = A.BuyStacksOnly()
  for _, row in ipairs(A.BelowRows()) do
    if row.result and not A.buy.skip[row.key] and not (stacksOnly and IsStackable(row) == false) then
      return row
    end
  end
end
A.BuyTarget = Target

-- What a click buys, from the item's search results. Commodities: every unit under the vendor price (the
-- player's own units left out), as many as the player can pay for. Items: the cheapest auction under it.
local function CommodityOffer(itemID, sell)
  local api = C_AuctionHouse
  local money = Money()
  local quantity, total = 0, 0
  for index = 1, api.GetNumCommoditySearchResults(itemID) or 0 do
    local info = api.GetCommoditySearchResultInfo(itemID, index)
    if not info or not info.unitPrice or info.unitPrice >= sell then
      break -- (cheapest first)
    end
    local available = (info.quantity or 0) - (info.numOwnerItems or 0)
    local afford = info.unitPrice > 0 and math.floor((money - total) / info.unitPrice) or 0
    local take = math.max(0, math.min(available, afford))
    quantity = quantity + take
    total = total + take * info.unitPrice
    if take < available then
      break -- (out of gold)
    end
  end
  if quantity > 0 then
    return { quantity = quantity, total = total, sell = sell }
  end
end

local function ItemOffer(itemKey, sell)
  local api = C_AuctionHouse
  local money = Money()
  local best
  for index = 1, api.GetNumItemSearchResults(itemKey) or 0 do
    local info = api.GetItemSearchResultInfo(itemKey, index)
    local price = info and info.buyoutAmount -- (one item's price: Scan.lua's FromItemSearch)
    if price and price > 0 and price < sell and price <= money and info.auctionID and not info.containsOwnerItem
      and (not best or price < best.total) then
      best = { quantity = 1, total = price, sell = sell, auctionID = info.auctionID }
    end
  end
  return best
end

local function ItemName(key)
  local name = A.ItemInfo(key, true)
  return name or A.CachedName(key) or L["Item %s"]:format(key)
end

-- Searches the top item so the next click can buy it. Called whenever the list or the panel changes.
function A.PrepareBuy()
  local buy = A.buy
  if not A.open or not A.IsModern() or buy.state == "quote" or buy.state == "buying" then
    return
  end
  local target = Target()
  if not target then
    if buy.state ~= "idle" then
      Reset()
      Changed()
    end
    return
  end
  if (buy.state == "checking" or buy.state == "ready") and buy.key == target.key then
    return -- (already searched or being searched)
  end
  local api = C_AuctionHouse
  if not api.SendSearchQuery then
    return
  end
  Reset("checking")
  buy.key = target.key
  buy.itemKey = target.result.itemKey
  if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
    -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY sends it
    buy.waiting = true
    Changed()
    return
  end
  buy.waiting = false
  local sorts = {}
  local order = Enum and Enum.AuctionHouseSortOrder
  if order and order.Buyout then
    sorts[1] = { sortOrder = order.Buyout, reverseSort = false }
  end
  if order and order.Bid then
    sorts[#sorts + 1] = { sortOrder = order.Bid, reverseSort = false }
  end
  pcall(api.SendSearchQuery, buy.itemKey, sorts, false)
  local gen, key = buy.gen, buy.key
  After(SEARCH_TIMEOUT, function()
    if buy.gen == gen and buy.state == "checking" then
      buy.skip[key] = true -- (no answer: the next item)
      Reset()
      A.PrepareBuy()
      Changed()
    end
  end)
  Changed()
end

-- Search results for the item being prepared (both kinds come here from Scan.lua's events).
local function OnResults(kind, itemID, itemKey)
  local buy = A.buy
  if not buy.key or buy.key ~= itemID or (buy.state ~= "checking" and buy.state ~= "ready") then
    return
  end
  local sell = A.SellPrice(itemID)
  if kind ~= "commodity" and A.BuyStacksOnly() then
    sell = nil -- (not a commodity after all: skipped with "Stacks only")
  end
  -- (an explicit if: "commodity and CommodityOffer() or ItemOffer()" ran ItemOffer with no item key when a
  -- commodity had nothing cheap left, a Lua error in game 2026-11-27)
  local offer
  if sell and sell > 0 then
    if kind == "commodity" then
      offer = CommodityOffer(itemID, sell)
    elseif itemKey then
      offer = ItemOffer(itemKey, sell)
    end
  end
  if not offer then
    -- nothing under the vendor price left (or nothing the player can pay for): the next item
    buy.skip[itemID] = true
    Reset()
    A.PrepareBuy()
    Changed()
    return
  end
  buy.state = "ready"
  buy.kind = kind
  buy.itemKey = itemKey or buy.itemKey
  buy.offer = offer
  Changed()
end

function A.BuyCommodityResults(itemID)
  OnResults("commodity", itemID)
end

function A.BuyItemResults(itemKey)
  if itemKey and itemKey.itemID then
    OnResults("item", itemKey.itemID, itemKey)
  end
end

local function Done(ok, why)
  local buy = A.buy
  local key, offer = buy.key, buy.offer
  if ok and key and offer then
    buy.bought = buy.bought + offer.quantity
    buy.spent = buy.spent + offer.total
    buy.profit = buy.profit + (offer.sell * offer.quantity - offer.total)
    ns.Say(L["Bought %d %s for %s (a vendor pays %s)."]:format(offer.quantity, ItemName(key), ns.Money(offer.total),
      ns.Money(offer.sell * offer.quantity)))
  elseif why then
    ns.Say(why)
  end
  Reset()
  -- the top item searched again: more may be under the vendor price, or less after a failure (the search also
  -- updates the list; an item with nothing cheap left is skipped by OnResults)
  A.PrepareBuy()
  Changed()
end

local function Timeout(gen)
  After(PURCHASE_TIMEOUT, function()
    local buy = A.buy
    if buy.gen == gen and (buy.state == "quote" or buy.state == "buying") then
      if buy.state == "quote" and C_AuctionHouse.CancelCommoditiesPurchase then
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
      end
      Done(false, L["The auction house didn't answer; nothing more was bought."])
    end
  end)
end

-- The button's click (a hardware event: the game allows the purchase only from one). Returns true when a
-- purchase started, or false and why not.
function A.BuyNext()
  local buy = A.buy
  if not A.open then
    return false, L["Open the auction house first."]
  end
  if buy.state == "quote" or buy.state == "buying" then
    return false, L["Still buying the last one."]
  end
  if buy.state ~= "ready" or not buy.offer then
    A.PrepareBuy()
    return false, Target() and L["Checking the price; click again in a moment."] or L["Nothing to buy below the vendor price."]
  end
  local api = C_AuctionHouse
  local offer = buy.offer
  if offer.total > Money() then
    Reset()
    A.PrepareBuy()
    Changed()
    return false, L["Not enough gold for it."]
  end
  if buy.kind == "commodity" then
    if not api.StartCommoditiesPurchase then
      return false, L["This game version can't buy from here."]
    end
    buy.state = "quote"
    -- (Blizzard's buy view passes the price per item as well: AuctionHouseFrameMixin:StartCommoditiesPurchase)
    api.StartCommoditiesPurchase(buy.key, offer.quantity, math.ceil(offer.total / offer.quantity))
  else
    if not api.PlaceBid then
      return false, L["This game version can't buy from here."]
    end
    buy.state = "buying"
    api.PlaceBid(offer.auctionID, offer.total)
  end
  Timeout(buy.gen)
  Changed()
  return true
end

-- Purchase events -----------------------------------------------------------------------------------------------

local handlers = {}

-- The server's quote: buy only while the whole purchase is still under what a vendor pays and affordable.
function handlers.COMMODITY_PRICE_UPDATED(_, total)
  local buy = A.buy
  if buy.state ~= "quote" or not buy.offer then
    return
  end
  local offer = buy.offer
  local api = C_AuctionHouse
  if type(total) ~= "number" or total >= offer.sell * offer.quantity or total > Money() then
    pcall(api.CancelCommoditiesPurchase)
    Done(false, L["%s got dearer before the purchase; nothing was bought."]:format(ItemName(buy.key)))
    return
  end
  offer.total = total
  buy.state = "buying"
  api.ConfirmCommoditiesPurchase(buy.key, offer.quantity)
  Changed()
end

function handlers.COMMODITY_PRICE_UNAVAILABLE()
  if A.buy.state == "quote" then
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    Done(false, L["That price isn't available any more; nothing was bought."])
  end
end

function handlers.COMMODITY_PURCHASE_SUCCEEDED()
  if A.buy.state == "buying" and A.buy.kind == "commodity" then
    Done(true)
  end
end

function handlers.COMMODITY_PURCHASE_FAILED()
  local state = A.buy.state
  if (state == "buying" or state == "quote") and A.buy.kind == "commodity" then
    Done(false, L["The purchase failed; nothing was bought."])
  end
end

function handlers.AUCTION_HOUSE_PURCHASE_COMPLETED(auctionID)
  local buy = A.buy
  if buy.state == "buying" and buy.kind == "item" and buy.offer and buy.offer.auctionID == auctionID then
    Done(true)
  end
end

function handlers.AUCTION_HOUSE_SHOW_ERROR()
  local buy = A.buy
  if buy.state == "buying" and buy.kind == "item" then
    Done(false, L["The auction house refused the purchase (someone may have bought it first)."])
  end
end

function handlers.AUCTION_HOUSE_THROTTLED_SYSTEM_READY()
  local buy = A.buy
  if buy.state == "checking" and buy.waiting then
    Reset()
    A.PrepareBuy()
  end
end

function handlers.AUCTION_HOUSE_CLOSED()
  local buy = A.buy
  Reset()
  buy.skip = {}
end

-- Called from Scan.lua's A.StartEvents (modern clients only).
function A.StartBuyEvents()
  local frame = CreateFrame("Frame")
  for event in pairs(handlers) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function(_, event, ...)
    handlers[event](...)
  end)
  A.buyFrame = frame
end

-- One line for the panel: what the next click buys.
function A.BuyText()
  local buy = A.buy
  local state = buy.state
  if state == "ready" and buy.offer then
    local offer = buy.offer
    return L["Next: %s x%d for %s, +%s"]:format(ItemName(buy.key), offer.quantity, ns.Money(offer.total),
      ns.Money(offer.sell * offer.quantity - offer.total))
  elseif state == "checking" then
    return L["Checking %s..."]:format(ItemName(buy.key))
  elseif state == "quote" or state == "buying" then
    return L["Buying %s..."]:format(ItemName(buy.key))
  end
  if buy.bought > 0 then
    return L["Bought %d for %s, +%s."]:format(buy.bought, ns.Money(buy.spent), ns.Money(buy.profit))
  end
  return A.BuyStacksOnly() and L["No stackable goods to buy below the vendor price."]
    or L["Nothing to buy below the vendor price."]
end
