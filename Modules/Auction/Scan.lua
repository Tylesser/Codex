local addonName, ns = ...

-- Auction house module, part 2: full scans (C_AuctionHouse.ReplicateItems), prices from whatever the player
-- browses or searches, and shopping list searches. Modern auction house only (Forever, Retail); the legacy
-- one of Classic Era / TBC / Wrath (QueryAuctionItems) isn't supported yet, so nothing here runs there.

local A = ns.auction

local SCAN_LIMIT = 15 * 60 -- the server allows one full scan per 15 minutes (account-wide)
local SCAN_TIMEOUT = 180 -- give up when the server sends nothing for this long
local BATCH = 500 -- auctions read per frame
local RETRY_ROUNDS = 8 -- rounds of waiting for item data, one second apart
local SEARCH_TIMEOUT = 15 -- seconds to wait for one shopping term's results

A.open = false
A.scan = { state = "idle", gen = 0, done = 0, total = 0 }
A.shop = { state = "idle", gen = 0, index = 0, results = {}, terms = {} }

-- True on clients with the modern auction house API.
function A.IsModern()
  local api = C_AuctionHouse
  if not (api and api.ReplicateItems and api.GetReplicateItemInfo and api.SendBrowseQuery and api.GetBrowseResults) then
    return false
  end
  if WOW_PROJECT_ID and (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) then
    return true
  end
  return QueryAuctionItems == nil
end

local function After(seconds, fn)
  C_Timer.After(seconds, fn)
end

-- Full scan -----------------------------------------------------------------------------------------------

-- Seconds until the server allows the next full scan (0 = now).
function A.NextScanIn()
  local realm = A.Realm(false)
  local last = realm and realm.lastScan
  if not last then
    return 0
  end
  return math.max(0, last + SCAN_LIMIT - time())
end

local function FinishScan(reason)
  local scan = A.scan
  local realm = A.Realm(true)
  scan.gen = scan.gen + 1 -- stops any batch still queued
  if reason == "done" then
    local when = time()
    local count = A.Commit(scan.entries or {}, when)
    realm.scanned, realm.scanDone = count, when
    scan.lastResult = ("Scan done: %d items, %d auctions%s."):format(count, scan.total,
      scan.skipped > 0 and (", " .. scan.skipped .. " skipped (no item data)") or "")
    ns.Say(scan.lastResult)
  elseif reason == "closed" then
    scan.lastResult = "Scan stopped: the auction house was closed."
    ns.Say(scan.lastResult)
  elseif reason == "timeout" then
    scan.lastResult = "Scan stopped: the server sent no data. Try again after the 15-minute wait."
    ns.Say(scan.lastResult)
  end
  scan.state = "idle"
  scan.entries, scan.pending = nil, nil
  A.Changed("scan")
  if reason == "done" then
    ns.Fire("PRICES_UPDATED")
  end
end
A.FinishScan = FinishScan

local function Add(entries, key, variant, unit, count)
  local entry = entries[key]
  if not entry then
    entry = { m = unit, n = 0 }
    entries[key] = entry
  elseif unit < entry.m then
    entry.m = unit
  end
  entry.n = entry.n + count
  if variant then
    entry.v = entry.v or {}
    local data = entry.v[variant]
    if not data then
      entry.v[variant] = { unit, count }
    else
      data[1] = math.min(data[1], unit)
      data[2] = data[2] + count
    end
  end
end

-- Reads one auction into the scan. Returns false when it has to wait for item data.
local function ReadAuction(scan, index)
  local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID, hasAllInfo =
    C_AuctionHouse.GetReplicateItemInfo(index)
  if not itemID then
    return false
  end
  if not buyout or buyout <= 0 or not count or count <= 0 then
    return true -- bid-only auction: no buyout price to learn from
  end
  -- count, buyout and item ID come at once; gear and pets also need their link (item level, suffix, species)
  local key, variant = itemID, nil
  if itemID == A.PET_CAGE or A.IsEquipment(itemID) then
    if not hasAllInfo then
      if not scan.requested[itemID] then
        scan.requested[itemID] = true
        if C_Item and C_Item.RequestLoadItemDataByID then
          C_Item.RequestLoadItemDataByID(itemID)
        end
      end
      return false
    end
    local link = C_AuctionHouse.GetReplicateItemLink and C_AuctionHouse.GetReplicateItemLink(index)
    if link then
      key, variant = A.KeyOf(link)
      key = key or itemID
    end
  end
  Add(scan.entries, key, variant, buyout / count, count)
  if type(name) == "string" and not A.CachedName(key) then
    A.RememberName(key, name)
  end
  return true
end

local ProcessBatch

local function RetryPending(gen)
  local scan = A.scan
  if scan.gen ~= gen then
    return
  end
  local still = {}
  for _, index in ipairs(scan.pending) do
    if not ReadAuction(scan, index) then
      still[#still + 1] = index
    end
  end
  scan.pending = still
  scan.rounds = scan.rounds + 1
  if #still == 0 or scan.rounds >= RETRY_ROUNDS then
    scan.skipped = #still
    FinishScan("done")
  else
    A.Changed("scan")
    After(1, function()
      RetryPending(gen)
    end)
  end
end

ProcessBatch = function(gen)
  local scan = A.scan
  if scan.gen ~= gen then
    return
  end
  local last = math.min(scan.index + BATCH, scan.total) - 1
  for index = scan.index, last do
    if not ReadAuction(scan, index) then
      scan.pending[#scan.pending + 1] = index
    end
  end
  scan.index = last + 1
  scan.done = scan.index
  if scan.index < scan.total then
    A.Changed("scan")
    After(0, function()
      ProcessBatch(gen)
    end)
  elseif #scan.pending > 0 then
    scan.state = "loading"
    A.Changed("scan")
    After(1, function()
      RetryPending(gen)
    end)
  else
    scan.skipped = 0
    FinishScan("done")
  end
end

-- REPLICATE_ITEM_LIST_UPDATE: the data of our scan arrived. The event fires again for every item the
-- server sends later, so only the first one after our request starts the work.
local function OnReplicate()
  local scan = A.scan
  if scan.state ~= "waiting" then
    return
  end
  scan.state = "reading"
  scan.total = C_AuctionHouse.GetNumReplicateItems() or 0
  scan.index, scan.done, scan.rounds, scan.skipped = 0, 0, 0, 0
  scan.entries, scan.pending, scan.requested = {}, {}, {}
  A.Changed("scan")
  local gen = scan.gen
  After(0, function()
    ProcessBatch(gen)
  end)
end

-- Asks the server for every auction. Returns true, or false and why not.
function A.StartScan()
  if not A.IsModern() then
    return false, "The old auction house of this game version isn't supported yet."
  end
  if not A.open then
    return false, "Open the auction house first."
  end
  if A.scan.state ~= "idle" then
    return false, "A scan is already running."
  end
  local wait = A.NextScanIn()
  if wait > 0 then
    return false, ("The server allows one full scan every 15 minutes. The next one is possible in %s."):format(A.Duration(wait))
  end
  local scan = A.scan
  scan.gen = scan.gen + 1
  scan.state = "waiting"
  scan.done, scan.total = 0, 0
  scan.lastResult = nil
  A.Realm(true).lastScan = time()
  C_AuctionHouse.ReplicateItems()
  local gen = scan.gen
  After(SCAN_TIMEOUT, function()
    if scan.gen == gen and scan.state == "waiting" then
      FinishScan("timeout")
    end
  end)
  A.Changed("scan")
  return true
end

-- /codex scan and the Scan buttons.
function A.ScanCommand()
  local ok, why = A.StartScan()
  if ok then
    ns.Say("Full scan started. This takes a moment; you can keep using the auction house.")
  else
    ns.Say(why)
  end
end

-- One line about the scan for the page, the panel and Home.
function A.ScanText()
  local scan = A.scan
  if scan.state == "waiting" then
    return "Waiting for the server..."
  elseif scan.state == "reading" then
    local percent = scan.total > 0 and math.floor(scan.done / scan.total * 100) or 0
    return ("Reading auctions: %d%% (%d of %d)"):format(percent, scan.done, scan.total)
  elseif scan.state == "loading" then
    return ("Loading item data for %d auctions..."):format(#(scan.pending or {}))
  end
  if not A.IsModern() then
    return "The old auction house of this game version isn't supported yet."
  end
  local wait = A.NextScanIn()
  if wait > 0 then
    return ("Next full scan possible in %s."):format(A.Duration(wait))
  end
  return A.open and "Ready to scan." or "Open the auction house to scan."
end

-- Prices from browsing and searching -----------------------------------------------------------------------

local function FromBrowse(results)
  local seen = 0
  local now = time()
  for _, result in ipairs(results or {}) do
    if result.itemKey and result.minPrice and result.minPrice > 0 then
      local key, variant = A.KeyOf(result.itemKey)
      if key then
        A.Observe(key, variant, result.minPrice, result.totalQuantity, now)
        seen = seen + 1
      end
    end
  end
  if seen > 0 then
    ns.Fire("PRICES_UPDATED")
  end
end
A.FromBrowse = FromBrowse

local function FromCommodity(itemID)
  local api = C_AuctionHouse
  local num = itemID and api.GetNumCommoditySearchResults and api.GetNumCommoditySearchResults(itemID) or 0
  local low, total = nil, 0
  for index = 1, num do
    local info = api.GetCommoditySearchResultInfo(itemID, index)
    if info and info.unitPrice and info.unitPrice > 0 then
      low = math.min(low or info.unitPrice, info.unitPrice)
      total = total + (info.quantity or 0)
    end
  end
  if api.GetCommoditySearchResultsQuantity then
    total = math.max(total, api.GetCommoditySearchResultsQuantity(itemID) or 0)
  end
  if low then
    A.Observe(itemID, nil, low, total)
    ns.Fire("PRICES_UPDATED")
  end
end
A.FromCommodity = FromCommodity

local function FromItemSearch(itemKey)
  local api = C_AuctionHouse
  local num = itemKey and api.GetNumItemSearchResults and api.GetNumItemSearchResults(itemKey) or 0
  local low, total = nil, 0
  for index = 1, num do
    local info = api.GetItemSearchResultInfo(itemKey, index)
    local quantity = info and info.quantity or 0
    if info and info.buyoutAmount and info.buyoutAmount > 0 and quantity > 0 then
      local unit = info.buyoutAmount / quantity
      low = math.min(low or unit, unit)
      total = total + quantity
    end
  end
  if low then
    local key, variant = A.KeyOf(itemKey)
    A.Observe(key, variant, low, total)
    ns.Fire("PRICES_UPDATED")
  end
end
A.FromItemSearch = FromItemSearch

-- Shopping list searches -------------------------------------------------------------------------------------

local QUALITY_FILTERS = { "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality",
  "LegendaryQuality", "ArtifactQuality" }

-- A browse query like the game's own search box sends: every quality, cheapest first.
function A.BuildQuery(text)
  local filters, sorts = {}, {}
  local filterEnum = Enum and Enum.AuctionHouseFilter or {}
  for _, name in ipairs(QUALITY_FILTERS) do
    if filterEnum[name] then
      filters[#filters + 1] = filterEnum[name]
    end
  end
  local sortEnum = Enum and Enum.AuctionHouseSortOrder or {}
  if sortEnum.Price then
    sorts[#sorts + 1] = { sortOrder = sortEnum.Price, reverseSort = false }
  end
  if sortEnum.Name then
    sorts[#sorts + 1] = { sortOrder = sortEnum.Name, reverseSort = false }
  end
  return { searchString = text, sorts = sorts, filters = filters, itemClassFilters = {} }
end

local function ResultName(itemKey)
  local info = C_AuctionHouse.GetItemKeyInfo and C_AuctionHouse.GetItemKeyInfo(itemKey)
  if info and info.itemName then
    return info.itemName, info.iconFileID, info.quality
  end
  local key = A.KeyOf(itemKey)
  return A.ItemInfo(key, true)
end

-- A recipe (pattern, plans, formula, schematic...), from the item's class (known without the item's data).
local RECIPE_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Recipe) or 9
local function IsRecipe(itemKey)
  local itemID = itemKey and itemKey.itemID
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not (itemID and instant) then
    return false
  end
  local ok, _, _, _, _, _, classID = pcall(instant, itemID)
  return ok and classID == RECIPE_CLASS
end
A.IsRecipeKey = IsRecipe

-- term.noRecipes (the writ searches and buy lists of the Commerce module: the item a writ asks for, never its
-- recipe) skips every recipe; an exact term skips a recipe whose name hasn't loaded yet (it can't be compared).
local function Collect(term, results)
  local shop = A.shop
  local wanted = term.text:lower()
  for _, result in ipairs(results or {}) do
    if result.itemKey then
      local name, icon, quality = ResultName(result.itemKey)
      local skipRecipe = (term.noRecipes or (term.exact and not name)) and IsRecipe(result.itemKey)
      if not skipRecipe and not (term.exact and name and name:lower() ~= wanted) then
        shop.results[#shop.results + 1] = {
          result = result, name = name or ("Item " .. tostring(result.itemKey.itemID)), icon = icon,
          quality = quality, count = result.totalQuantity or 0, price = result.minPrice, term = term,
          deal = term.maxPrice and result.minPrice and result.minPrice <= term.maxPrice or false,
        }
      end
    end
  end
end

local SendTerm

local function NextTerm()
  local shop = A.shop
  shop.index = shop.index + 1
  shop.term = shop.terms[shop.index]
  if not shop.term then
    shop.state = "done"
    A.Changed("shop")
    return
  end
  SendTerm()
end

SendTerm = function()
  local shop = A.shop
  local api = C_AuctionHouse
  if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
    -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY resumes; a slow poll covers a missed event
    shop.state = "throttled"
    A.Changed("shop")
    local gen, index = shop.gen, shop.index
    After(2, function()
      if shop.gen == gen and shop.index == index and shop.state == "throttled" then
        SendTerm()
      end
    end)
    return
  end
  shop.state = "searching"
  A.Changed("shop")
  api.SendBrowseQuery(A.BuildQuery(shop.term.text))
  local gen, index = shop.gen, shop.index
  After(SEARCH_TIMEOUT, function()
    if shop.gen == gen and shop.index == index and shop.state == "searching" then
      NextTerm() -- no answer: skip this term
    end
  end)
end

-- Searches every term of a list in turn. Returns true, or false and why not.
function A.SearchList(list)
  if not A.IsModern() then
    return false, "The old auction house of this game version isn't supported yet."
  end
  if not A.open then
    return false, "Open the auction house first."
  end
  if not list or #list.terms == 0 then
    return false, "This list has no search terms yet."
  end
  local shop = A.shop
  shop.gen = shop.gen + 1
  shop.list = list
  shop.terms = {}
  for index, term in ipairs(list.terms) do
    shop.terms[index] = term
  end
  shop.index = 0
  shop.results = {}
  NextTerm()
  return true
end

function A.StopSearch()
  local shop = A.shop
  if shop.state ~= "idle" and shop.state ~= "done" then
    shop.gen = shop.gen + 1
    shop.state = "stopped"
    A.Changed("shop")
  end
end

function A.SearchText()
  local shop = A.shop
  if shop.state == "searching" or shop.state == "throttled" then
    return ("Searching %d of %d: %s"):format(shop.index, #shop.terms, shop.term.text)
  elseif shop.state == "done" then
    local deals = 0
    for _, entry in ipairs(shop.results) do
      if entry.deal then
        deals = deals + 1
      end
    end
    return ("%s: %d results%s."):format(shop.list.name, #shop.results,
      deals > 0 and (", " .. deals .. " under your max price") or "")
  elseif shop.state == "stopped" then
    return "Search stopped."
  end
  return "Click a list to search it."
end

-- Opens a result in the game's own buy view (the player buys there; Codex never buys, bids or posts).
function A.OpenResult(entry)
  local frame = AuctionHouseFrame
  if not frame or not entry then
    return false
  end
  if frame.SelectBrowseResult then
    -- Blizzard's buy views search for their item when they are shown (the item list's refresh on show): with
    -- one already open, a second result only changed the name and the old item's prices stayed (the user's
    -- screenshot, 2026-11-19). Back to the browse view first, as Blizzard's own list click comes from there.
    local modes = AuctionHouseFrameDisplayMode
    local current = frame.GetDisplayMode and frame:GetDisplayMode()
    if modes and current and modes.Buy and (current == modes.ItemBuy or current == modes.CommoditiesBuy)
      and frame.SetDisplayMode then
      pcall(frame.SetDisplayMode, frame, modes.Buy)
    end
    local ok = pcall(frame.SelectBrowseResult, frame, entry.result)
    if ok then
      local quantity = entry.term and tonumber(entry.term.quantity)
      local itemID = entry.result and entry.result.itemKey and entry.result.itemKey.itemID
      if quantity and quantity > 0 and itemID then
        A.wantQuantity = { itemID = itemID, quantity = math.floor(quantity), untilTime = GetTime() + 15 }
        A.SetBuyQuantity()
      end
      return true
    end
  end
  local bar = frame.SearchBar
  if bar and bar.SetSearchText and bar.StartSearch and entry.name then
    bar:SetSearchText(entry.name)
    bar:StartSearch()
    return true
  end
  return false
end

-- The amount to buy in the game's commodity buy view (a reagent search's result: what the recipe needs; 2026-11-24).
-- Done the way typing in its box does it (forever Blizzard_AuctionHouseCommoditiesBuyFrame.lua: the QuantityInput's
-- changed callback sets the box and triggers CommoditiesQuantitySelectionChanged, which BuyDisplay and the list
-- listen to); again a frame after the item's search results come (before them the price can't be totalled, and
-- the game caps the amount at what is on sale). Nothing is bought: the player still presses Buy.
function A.SetBuyQuantity()
  local want = A.wantQuantity
  local frame = AuctionHouseFrame
  local buy = frame and frame.CommoditiesBuyFrame
  local display = buy and buy.BuyDisplay
  if not want or GetTime() > want.untilTime or not display or not display.QuantityInput then
    return false
  end
  local ok, shownID = pcall(display.GetItemID, display)
  if not ok or shownID ~= want.itemID or not (display.IsShown and display:IsShown()) then
    return false
  end
  local input = display.QuantityInput
  pcall(input.SetQuantity, input, want.quantity)
  local event = AuctionHouseFrameMixin and AuctionHouseFrameMixin.Event
    and AuctionHouseFrameMixin.Event.CommoditiesQuantitySelectionChanged
  if event and frame.TriggerEvent then
    pcall(frame.TriggerEvent, frame, event, want.quantity)
  elseif display.SetQuantitySelected then
    pcall(display.SetQuantitySelected, display, want.quantity)
  end
  return true
end

-- Events ----------------------------------------------------------------------------------------------------

local EVENTS = {
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE",
  "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
  "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
}

local handlers = {}

function handlers.AUCTION_HOUSE_SHOW()
  A.open = true
  A.Changed("scan")
  A.ShowPanel()
end

function handlers.AUCTION_HOUSE_CLOSED()
  A.open = false
  local scan = A.scan
  if scan.state ~= "idle" then
    FinishScan("closed")
  end
  A.StopSearch()
  A.Changed("scan")
end

handlers.REPLICATE_ITEM_LIST_UPDATE = OnReplicate

function handlers.AUCTION_HOUSE_BROWSE_RESULTS_UPDATED()
  local results = C_AuctionHouse.GetBrowseResults()
  FromBrowse(results)
  local shop = A.shop
  if shop.state == "searching" then
    Collect(shop.term, results)
    NextTerm()
  end
end

function handlers.AUCTION_HOUSE_BROWSE_RESULTS_ADDED(added)
  FromBrowse(added)
end

function handlers.COMMODITY_SEARCH_RESULTS_UPDATED(itemID)
  FromCommodity(itemID)
  local want = A.wantQuantity
  if want and want.itemID == itemID and C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if A.wantQuantity == want and A.SetBuyQuantity() then
        A.wantQuantity = nil -- once: after a purchase the game's own reset to 1 stays
      end
    end) -- (after the buy view has its results: it totals the price then)
  end
end

function handlers.ITEM_SEARCH_RESULTS_UPDATED(itemKey)
  FromItemSearch(itemKey)
end

function handlers.AUCTION_HOUSE_THROTTLED_SYSTEM_READY()
  if A.shop.state == "throttled" then
    SendTerm()
  end
end

-- Called from Enable on modern clients only.
function A.StartEvents()
  local frame = CreateFrame("Frame")
  for _, event in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then
      handler(...)
    end
  end)
  A.eventFrame = frame
  -- opened before login finished (a /reload at the auction house)
  if AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() then
    handlers.AUCTION_HOUSE_SHOW()
  end
end
