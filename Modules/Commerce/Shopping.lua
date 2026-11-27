local addonName, ns = ...

-- Commerce module, part 8: the buy list and auction searches. The buy list is the Codex shopping list
-- "Commerce Authority" (Auction House module; searched from the Codex auction panel): the cheapest writs for
-- the reputation you still need to your next standing, or every writ one NPC or one zone takes, and the items
-- they ask for (the ones cheaper to buy than to craft). At most MAX_WRITS writs to the next standing.
-- Ported from Tylesser - Commerce Authority, whose list was Auctionator's.

local C = ns.commerce
local L = ns.L

C.SHOPPING_LIST = "Commerce Authority"
local MAX_WRITS = 20
local DEFAULT_GOAL = 3000 -- no reputation yet: enough for Friendly

local function Auction()
  local A = ns.auction
  if A and A.DB and A.DB() and A.Lists and A.NewList and A.AddTerm then
    return A
  end
end

-- The writs to buy: { picks = { entry... }, rep, cost, goal }.
function C.PlanPurchases()
  local faction = C.Faction()
  local goal = DEFAULT_GOAL
  local standings = C.NextStandings(faction)
  if faction then
    goal = standings[1] and standings[1].needed or 0
  end
  goal = math.max(goal - C.BagSummary().writRep, 0)
  local plan = { picks = {}, rep = 0, cost = 0, goal = goal }
  for _, entry in ipairs(C.CheapestWrits()) do
    if plan.rep >= goal or #plan.picks >= MAX_WRITS then
      break
    end
    plan.picks[#plan.picks + 1] = entry
    plan.rep = plan.rep + entry.rep
    plan.cost = plan.cost + entry.total
  end
  return plan
end

-- What to buy for a writ's items (2026-11-22, the user's request: search the materials of what you craft): the item
-- itself when buying is cheaper, its materials when crafting is (C.CraftReagents), else nothing. Calls
-- add(name, quantity) for each; `count` = how many of the item the writs ask for. (Commerce Authority's twin.)
function C.ItemsFor(writID, writ, count, add)
  local _, how = C.WantedItemCost(writID)
  local itemID = C.WantedItem(writ)
  if how == "craft" and itemID then
    local reagents, made = C.CraftReagents(itemID)
    if reagents then
      local crafts = math.ceil(count / math.max(made or 1, 1))
      for _, reagent in ipairs(reagents) do
        add(C.ItemName(reagent.itemID), reagent.count * crafts)
      end
      return
    end
  end
  if itemID or writ[3] then
    add((itemID and C.ItemName(itemID)) or writ[3], count)
  end
end

-- The names to search for writs (cheapest-list entries): each writ, then the items they ask for (the materials,
-- for items cheaper to craft; one name each).
function C.BuyNames(picks)
  local names, seen = {}, {}
  local function Add(name)
    if name and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  local items = {}
  for _, entry in ipairs(picks) do
    local writ = C.WRITS[entry.writID]
    Add(C.ItemName(entry.writID) or ("Craftsman's Writ: " .. writ[3]))
    C.ItemsFor(entry.writID, writ, C.WritCount(entry.writID, writ), function(name)
      if name then
        items[#items + 1] = name
      end
    end)
  end
  for _, name in ipairs(items) do
    Add(name)
  end
  return names
end

-- Writes the names into the Codex list (replaced, not added to). Returns the list.
local function MakeList(picks)
  local A = Auction()
  if not A then
    ns.Say(L["the buy list needs Codex's Auction House module; switch it on in the Codex window."])
    return nil
  end
  local list
  for _, existing in ipairs(A.Lists()) do
    if existing.name == C.SHOPPING_LIST then
      list = existing
      break
    end
  end
  list = list or A.NewList(C.SHOPPING_LIST)
  for index = #list.terms, 1, -1 do
    list.terms[index] = nil
  end
  for _, name in ipairs(C.BuyNames(picks)) do
    local term = A.AddTerm(list, name, true, nil)
    if term then
      term.noRecipes = true -- the item a writ asks for, never its recipe
    end
  end
  A.Changed("lists")
  return list
end

-- The buy list for one kind of crate (an entry of C.CratesToFill): the cheapest priced fill item, in the Codex list
-- (replaced), with how many it takes in chat (enough for all of them, less what your bags hold).
function C.CreateCrateBuyList(crate)
  local A = Auction()
  local option = crate and crate.options[1]
  if not A then
    ns.Say(L["the buy list needs Codex's Auction House module; switch it on in the Codex window."])
    return false
  end
  if not option then
    ns.Say(L["no known fill for %s."]:format(crate and crate.info.name or L["that crate"]))
    return false
  end
  local need = C.CrateNeed(crate, option) or 0
  if need == 0 then
    ns.Say(L["your bags already hold enough %s to fill %s."]:format(option.name, crate.info.name))
    return false
  end
  local list
  for _, existing in ipairs(A.Lists()) do
    if existing.name == C.SHOPPING_LIST then
      list = existing
      break
    end
  end
  list = list or A.NewList(C.SHOPPING_LIST)
  for index = #list.terms, 1, -1 do
    list.terms[index] = nil
  end
  local term = A.AddTerm(list, option.name, true, nil)
  if term then
    term.noRecipes = true
    term.quantity = need -- (the game's buy view opens with this amount: Auction/Scan.lua A.OpenResult)
  end
  A.Changed("lists")
  ns.Say(L["shopping list \"%s\": %s, %d to fill %d %s."]:format(C.SHOPPING_LIST, option.name, need, crate.count,
    crate.info.name))
  return true
end

-- How many of one fill item (an entry of crate.options) all the crates of that kind still need, less what your
-- bags hold; nil when the bags hold enough.
function C.CrateNeed(crate, option)
  local need = (option.count or 0) * (crate.count or 1) - (option.owned or 0)
  return need > 0 and need or nil
end

-- Searches the open auction house for everything that fills a crate (an entry of C.CratesToFill), cheapest first:
-- Codex's auction panel, else the game's search box with the cheapest. Returns true when a search started.
function C.SearchCrate(crate)
  if not (crate and C.AuctionHouseOpen()) then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    ns.Say(L["auction searches wait until the fight is over."])
    return false
  end
  local terms, quantities = {}, {}
  for _, option in ipairs(crate.options) do
    terms[#terms + 1] = option.name
    quantities[#terms] = C.CrateNeed(crate, option)
  end
  if #terms == 0 then
    ns.Say(L["no known fill for %s."]:format(crate.info.name))
    return false
  end
  local A = ns.auction
  if A and A.running and A.open and A.SearchList then
    local list = { name = C.SHOPPING_LIST, terms = {} }
    for index, name in ipairs(terms) do
      -- (opening a result fills the game's buy box with what the crates still need: Auction/Scan.lua A.OpenResult)
      list.terms[#list.terms + 1] = { text = name, exact = true, noRecipes = true, quantity = quantities[index] }
    end
    local ok, started = pcall(A.SearchList, list)
    if ok and started then
      if A.ShowPanel then
        pcall(A.ShowPanel)
      end
      if #terms == 1 then
        ns.Say(L["searching the auction house: what fills %s (1 item)."]:format(crate.info.name))
      else
        ns.Say(L["searching the auction house: what fills %s (%d items)."]:format(crate.info.name, #terms))
      end
      return true
    end
  end
  local ok, started = pcall(C.BlizzardSearch, terms[1])
  if ok and started then
    if #terms > 1 then
      ns.Say(L["searching for %s; switch Codex's Auction House module on to search all %d fills in turn."]:format(
        terms[1], #terms))
    end
    return true
  end
  return false
end

local function Where()
  return " " .. L["At the auction house, click it in the Codex panel to search it."]
end

-- A crate from the By crate ranking (an entry of C.CheapestCrates, 2026-11-28): searches the open auction house for
-- the crate and every item that fills it (one crate's worth each, cheapest first; opening a result fills the game's
-- buy box with that amount: Auction/Scan.lua A.OpenResult), in the Codex auction panel, else the game's search box
-- with the crate. Returns true when a search started. (Commerce Authority's twin.)
function C.SearchRankedCrate(entry)
  if not (entry and C.AuctionHouseOpen()) then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    ns.Say(L["auction searches wait until the fight is over."])
    return false
  end
  local terms = { { text = entry.name, exact = true, noRecipes = true, quantity = 1 } }
  if not entry.info.filled then
    for _, option in ipairs(C.CrateFillOptions(entry.info)) do
      terms[#terms + 1] = { text = option.name, exact = true, noRecipes = true, quantity = option.count }
    end
  end
  local A = ns.auction
  if A and A.running and A.open and A.SearchList then
    local ok, started = pcall(A.SearchList, { name = C.SHOPPING_LIST, terms = terms })
    if ok and started then
      if A.ShowPanel then
        pcall(A.ShowPanel)
      end
      ns.Say(L["searching the auction house: %s and what fills it."]:format(entry.name))
      return true
    end
  end
  local ok, started = pcall(C.BlizzardSearch, entry.name)
  if ok and started then
    if #terms > 1 then
      ns.Say(L["searching for %s; switch Codex's Auction House module on to search for what fills it too."]:format(
        entry.name))
    end
    return true
  end
  return false
end

-- The buy list for a crate from the By crate ranking: the crate and its cheapest fill (the Codex shopping list,
-- replaced). Returns true when it was made.
function C.CreateRankedCrateBuyList(entry)
  local A = Auction()
  if not A then
    ns.Say(L["the buy list needs Codex's Auction House module; switch it on in the Codex window."])
    return false
  end
  if not entry then
    return false
  end
  local list
  for _, existing in ipairs(A.Lists()) do
    if existing.name == C.SHOPPING_LIST then
      list = existing
      break
    end
  end
  list = list or A.NewList(C.SHOPPING_LIST)
  for index = #list.terms, 1, -1 do
    list.terms[index] = nil
  end
  local term = A.AddTerm(list, entry.name, true, nil)
  if term then
    term.noRecipes, term.quantity = true, 1
  end
  if entry.fill then
    term = A.AddTerm(list, entry.fill.name, true, nil)
    if term then
      term.noRecipes, term.quantity = true, entry.fill.count
    end
  end
  A.Changed("lists")
  if entry.fill then
    ns.Say(L["shopping list \"%s\": %s and %d %s to fill it, about %s."]:format(C.SHOPPING_LIST, entry.name,
      entry.fill.count, entry.fill.name, C.Money(entry.total)) .. Where())
  else
    ns.Say(L["shopping list \"%s\": %s, about %s."]:format(C.SHOPPING_LIST, entry.name, C.Money(entry.total))
      .. Where())
  end
  return true
end

-- The cheapest writs to your next standing.
function C.CreateBuyList()
  local plan = C.PlanPurchases()
  if plan.goal <= 0 then
    ns.Say(L["the writs in your bags already reach your next standing."])
    return false
  end
  if #plan.picks == 0 then
    ns.Say(L["no priced writs yet. Scan the auction house, or search for \"%s\"."]:format("Craftsman's Writ"))
    return false
  end
  if not MakeList(plan.picks) then
    return false
  end
  ns.Say(L["shopping list \"%s\": %d writs for about %s reputation (%s needed), about %s in all."]:format(
    C.SHOPPING_LIST, #plan.picks, C.Number(plan.rep), C.Number(plan.goal), C.Money(plan.cost)) .. Where())
  return true
end

-- Every priced writ one NPC takes (a group from C.CheapestCustomers), to deliver in one trip.
function C.CreateCustomerBuyList(group)
  if not (group and #group.writs > 0) or not MakeList(group.writs) then
    return false
  end
  ns.Say(L["shopping list \"%s\": %d writs for %s, about %s reputation, about %s in all."]:format(
    C.SHOPPING_LIST, #group.writs, C.CustomerText(group.customer), C.Number(group.rep), C.Money(group.total))
    .. Where())
  return true
end

-- Every priced writ taken in one zone (a zone from C.CheapestZones): one list, one trip around the zone.
function C.CreateZoneBuyList(zone)
  if not (zone and #zone.writs > 0) or not MakeList(zone.writs) then
    return false
  end
  ns.Say(L["shopping list \"%s\": %d writs for %d NPCs in %s, about %s reputation, about %s in all."]:format(
    C.SHOPPING_LIST, #zone.writs, #zone.npcs, zone.name, C.Number(zone.rep), C.Money(zone.total)) .. Where())
  return true
end

-- Auction house search ----------------------------------------------------------------------------------

function C.AuctionHouseOpen()
  local A = ns.auction
  if A and A.running and A.open then
    return true
  end
  return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) and true or false
end

-- The game's own search box takes one name.
local function BlizzardSearch(term)
  local bar = AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar
  if bar and bar.SearchBox and bar.StartSearch then
    bar.SearchBox:SetText(term)
    bar:StartSearch()
    return true
  end
  return false
end
C.BlizzardSearch = BlizzardSearch -- (the crate search above calls it)

-- Searches the open auction house for writs you don't hold yet, and the items asked for by those and by your
-- writs that aren't ready. `held` from C.HeldWrits. With Codex's Auction House module every name in turn (results
-- in the Codex auction panel), else the game's search box with the first. Returns true when a search started.
function C.SearchWrits(writIDs, held)
  if not C.AuctionHouseOpen() then
    return false
  end
  if InCombatLockdown and InCombatLockdown() then
    ns.Say(L["auction searches wait until the fight is over."])
    return false
  end
  held = held or {}
  local terms, seen = {}, {}
  local function Add(name)
    if name and not seen[name] then
      seen[name] = true
      terms[#terms + 1] = name
    end
  end
  local writCount = 0
  for _, writID in ipairs(writIDs) do
    local writ = C.WRITS[writID]
    local mine = held[writID]
    if writ and not mine then
      Add(C.ItemName(writID) or ("Craftsman's Writ: " .. writ[3]))
      writCount = writCount + 1
    end
    if writ and not (mine and mine.ready) then
      C.ItemsFor(writID, writ, C.WritCount(writID, writ), Add)
    end
  end
  if #terms == 0 then
    ns.Say(L["you already hold all of these writs, and they're ready."])
    return false
  end
  local A = ns.auction
  if A and A.running and A.open and A.SearchList then
    local list = { name = C.SHOPPING_LIST, terms = {} }
    for _, name in ipairs(terms) do
      list.terms[#list.terms + 1] = { text = name, exact = true, noRecipes = true }
    end
    local ok, started, why = pcall(A.SearchList, list)
    if ok and started then
      if A.ShowPanel then
        pcall(A.ShowPanel)
      end
      if writCount == 1 then
        ns.Say(L["searching the auction house: 1 writ and the items they ask for (the materials for those you craft)."])
      else
        ns.Say(L["searching the auction house: %d writs and the items they ask for (the materials for those you craft)."]
          :format(writCount))
      end
      return true
    end
    if ok and why then
      ns.Say(why)
    end
  end
  local ok, started = pcall(BlizzardSearch, terms[1])
  if ok and started then
    if #terms > 1 then
      ns.Say(L["searching for %s; switch Codex's Auction House module on to search all %d names in turn."]:format(
        terms[1], #terms))
    end
    return true
  end
  return false
end
