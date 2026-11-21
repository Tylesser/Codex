local addonName, ns = ...

-- Auction house module, part 1: the price database, item keys, shopping lists and small helpers.
-- Nothing here creates frames or registers events; Scan.lua, Tooltip.lua, Page.lua and Panel.lua do that
-- from Enable (Module.lua).
--
-- CodexDB.auction = {
--   realms = { ["<realm>-<faction>"] = {
--     items = { [itemID or "p<speciesID>"] = {
--       m = lowest unit buyout (copper), t = when seen (time()), n = how many were up,
--       h = { [day] = lowest unit buyout that day },  -- day = floor(time() / 86400), last `days` days only
--       v = { ["<itemLevel>:<suffix>"] = { price, time, count } },  -- gear variants only
--     } },
--     lastScan = time() of the last full scan request, scanned = items in it, scanDone = when it finished,
--   } },
--   lists = { { name = "...", terms = { { text = "...", exact = true/nil, maxPrice = copper/nil } } } },
--   tooltip = true, vendor = true, panel = true, days = 30,
-- }

local A = {}
ns.auction = A

A.DEFAULTS = {
  realms = {},
  lists = {},
  tooltip = true, -- "Auction" line in item tooltips
  vendor = true, -- "Vendor" line when the game doesn't show a sell price
  panel = true, -- Codex panel beside the auction house
  days = 30, -- days of price history to keep
}

local DAY = 86400
local FRESH = 6 * 3600 -- variants seen this recently count for the item's own (lowest) price
A.PET_CAGE = 82800

-- C_Item first (Retail and Forever), the old globals otherwise. Looked up per call.
local function Api(name)
  return (C_Item and C_Item[name]) or _G[name]
end
A.ItemApi = Api

-- The module's saved table, filled with defaults (created on first use after login).
function A.DB()
  if not ns.db then
    return nil
  end
  if not A.db or ns.db.auction ~= A.db then
    ns.db.auction = ns.Fill(ns.db.auction or {}, A.DEFAULTS)
    A.db = ns.db.auction
  end
  return A.db
end

-- Changes for the UI: "lists", "scan", "shop", "options".
function A.Changed(what)
  ns.Fire("AUCTION_STATE", what)
end

-- Realms --------------------------------------------------------------------------------------------------

-- Realm name plus faction: classic auction houses are per faction.
function A.RealmKey()
  local realm = ns.RealmName() -- (never "": Forever's GetRealmName gave "" for a session)
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  return realm .. "-" .. (faction or "Neutral")
end

-- This realm's record; create = true makes it (and the saved table) when missing.
function A.Realm(create)
  local db = create and A.DB() or (ns.db and ns.db.auction)
  if not db or not db.realms then
    return nil
  end
  local key = A.RealmKey()
  local realm = db.realms[key]
  if not realm and create then
    realm = { items = {} }
    db.realms[key] = realm
  end
  return realm
end

function A.ItemCount()
  local realm = A.Realm(false)
  local count = 0
  for _ in pairs(realm and realm.items or {}) do
    count = count + 1
  end
  return count
end

-- Item keys ----------------------------------------------------------------------------------------------
-- Most items are keyed by their item ID. Battle pets by species ("p<id>"). Weapons and armour also keep a
-- price per variant: item level (when it differs from the item's base level) and random suffix.

local function IsEquipment(itemID)
  local getInstant = Api("GetItemInfoInstant")
  if not getInstant then
    return false
  end
  local _, _, _, _, _, classID = getInstant(itemID)
  return classID == 2 or classID == 4 -- Enum.ItemClass.Weapon, Enum.ItemClass.Armor
end
A.IsEquipment = IsEquipment

local function BaseLevel(itemID)
  local getInfo = Api("GetItemInfo")
  return getInfo and select(4, getInfo(itemID))
end

local function VariantKey(itemID, level, suffix)
  level = tonumber(level) or 0
  suffix = tonumber(suffix) or 0
  if level == BaseLevel(itemID) then
    level = 0
  end
  if level == 0 and suffix == 0 then
    return nil
  end
  return math.floor(level) .. ":" .. math.floor(suffix)
end

-- itemID, random suffix ID, battle pet species from an item link or item string.
function A.ParseLink(link)
  local species = link:match("battlepet:(%d+)")
  if species then
    return nil, nil, tonumber(species)
  end
  local itemString = link:match("item:([%-%d:]+)")
  if not itemString then
    return nil
  end
  local fields = {}
  for field in (itemString .. ":"):gmatch("([^:]*):") do
    fields[#fields + 1] = field
  end
  return tonumber(fields[1]), tonumber(fields[7]) or 0
end

-- Database key (and gear variant key or nil) of an item ID, item link, item string or ItemKey table.
function A.KeyOf(item)
  local kind = type(item)
  if kind == "number" then
    return item, nil
  elseif kind == "table" then
    if item.battlePetSpeciesID and item.battlePetSpeciesID > 0 then
      return "p" .. item.battlePetSpeciesID, nil
    end
    local itemID = item.itemID
    if not itemID then
      return nil
    end
    if IsEquipment(itemID) then
      return itemID, VariantKey(itemID, item.itemLevel, item.itemSuffix)
    end
    return itemID, nil
  elseif kind == "string" then
    local plain = tonumber(item)
    if plain then
      return plain, nil
    end
    local itemID, suffix, species = A.ParseLink(item)
    if species then
      return "p" .. species, nil
    end
    if not itemID then
      return nil
    end
    if IsEquipment(itemID) then
      local getLevel = Api("GetDetailedItemLevelInfo")
      local level = getLevel and item:find("|H") and getLevel(item)
      return itemID, VariantKey(itemID, level, suffix)
    end
    return itemID, nil
  end
end

-- Recording prices ----------------------------------------------------------------------------------------

local function Today(when)
  return math.floor((when or time()) / DAY)
end
A.Today = Today

local function Trim(rec, today, days)
  if rec.h then
    for day in pairs(rec.h) do
      if day <= today - days then
        rec.h[day] = nil
      end
    end
  end
  if rec.v then
    for key, variant in pairs(rec.v) do
      if Today(variant[2]) <= today - days then
        rec.v[key] = nil
      end
    end
    if next(rec.v) == nil then
      rec.v = nil
    end
  end
end

local function Record(items, key)
  local rec = items[key]
  if not rec then
    rec = {}
    items[key] = rec
  end
  return rec
end

local function SetBase(rec, price, count, when, days)
  price = math.floor(price + 0.5)
  rec.m, rec.t, rec.n = price, when, math.floor(count or 0)
  local today = Today(when)
  rec.h = rec.h or {}
  if not rec.h[today] or price < rec.h[today] then
    rec.h[today] = price
  end
  Trim(rec, today, days)
end

-- One observation from a search: the lowest unit price of an item (or one gear variant) and how many are up.
function A.Observe(key, variant, price, count, when)
  if not key or not price or price <= 0 then
    return
  end
  when = when or time()
  local realm = A.Realm(true)
  local days = A.db.days or 30
  local rec = Record(realm.items, key)
  if variant then
    rec.v = rec.v or {}
    rec.v[variant] = { math.floor(price + 0.5), when, math.floor(count or 0) }
    -- the item's own price is the lowest variant seen lately
    local low, total = price, count or 0
    for other, data in pairs(rec.v) do
      if other ~= variant and when - data[2] < FRESH then
        low = math.min(low, data[1])
        total = total + data[3]
      end
    end
    price, count = low, total
  end
  SetBase(rec, price, count, when, days)
end

-- A finished full scan: entries[key] = { m = lowest unit price, n = count, v = { [variant] = { price, count } } }.
function A.Commit(entries, when)
  when = when or time()
  local realm = A.Realm(true)
  local days = A.db.days or 30
  local total = 0
  for key, entry in pairs(entries) do
    local rec = Record(realm.items, key)
    if entry.v then
      rec.v = rec.v or {}
      for variant, data in pairs(entry.v) do
        rec.v[variant] = { math.floor(data[1] + 0.5), when, data[2] }
      end
    end
    SetBase(rec, entry.m, entry.n, when, days)
    total = total + 1
  end
  return total
end

-- Drops history older than the kept days on every realm (once per session).
function A.TrimAll()
  local db = A.DB()
  local today = Today()
  for _, realm in pairs(db.realms) do
    for _, rec in pairs(realm.items or {}) do
      Trim(rec, today, db.days or 30)
    end
  end
end

-- Reading prices -----------------------------------------------------------------------------------------

-- Lowest unit buyout, when it was seen, how many were up. nil when the item has no price on this realm.
function A.GetPrice(item)
  if item == nil then
    return nil
  end
  local realm = A.Realm(false)
  if not realm then
    return nil
  end
  local key, variant = A.KeyOf(item)
  local rec = key and realm.items[key]
  if not rec then
    return nil
  end
  if variant and rec.v and rec.v[variant] then
    local data = rec.v[variant]
    return data[1], data[2], data[3]
  end
  return rec.m, rec.t, rec.n
end

-- Daily lowest prices, oldest first: { { time = <start of day>, price = copper }, ... }.
function A.GetHistory(item)
  local realm = A.Realm(false)
  local key = realm and item ~= nil and A.KeyOf(item)
  local rec = key and realm.items[key]
  local history = {}
  for day, price in pairs(rec and rec.h or {}) do
    history[#history + 1] = { time = day * DAY, price = price }
  end
  table.sort(history, function(a, b)
    return a.time < b.time
  end)
  return history
end

-- Current price against the average daily low of the past week (today left out): 0.12 = 12% dearer.
function A.Trend(rec)
  if not rec or not rec.m or not rec.h then
    return nil
  end
  local today = Today()
  local sum, days = 0, 0
  for day, price in pairs(rec.h) do
    if day < today and day >= today - 7 then
      sum, days = sum + price, days + 1
    end
  end
  if days == 0 or sum == 0 then
    return nil
  end
  return rec.m / (sum / days) - 1
end

-- Items --------------------------------------------------------------------------------------------------

-- name, icon, quality of a database key (nil name while the game hasn't loaded the item yet; request = true
-- asks the game to load it).
-- Item names we have seen (account-wide: names don't change per realm), so long lists can sort and search
-- without asking the game for thousands of items at once (GetItemInfo on an uncached item asks the server).
function A.Names()
  local db = ns.db and ns.db.auction
  if not db then
    return {}
  end
  db.names = db.names or {}
  return db.names
end

function A.RememberName(key, name)
  if key and type(name) == "string" and name ~= "" then
    A.Names()[key] = name
  end
end

-- The cached name only (never asks the game).
function A.CachedName(key)
  return A.Names()[key]
end

-- Learns the names of up to `limit` priced items we have no name for yet (each may ask the server, so this is
-- done a few at a time). Returns how many are still unknown.
function A.WarmNames(limit)
  local realm = A.Realm(false)
  local names = A.Names()
  local left = 0
  for key, rec in pairs(realm and realm.items or {}) do
    if rec.m and not names[key] then
      if limit > 0 then
        limit = limit - 1
        A.ItemInfo(key, true)
      end
      if not names[key] then
        left = left + 1
      end
    end
  end
  return left
end

function A.ItemInfo(key, request)
  if type(key) == "string" then
    local species = tonumber(key:match("^p(%d+)"))
    if species and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
      local name, icon = C_PetJournal.GetPetInfoBySpeciesID(species)
      return name, icon, 1
    end
    return nil
  end
  local getInfo = Api("GetItemInfo")
  if not getInfo then
    return nil
  end
  local name, _, quality, _, _, _, _, _, _, icon = getInfo(key)
  if name then
    A.RememberName(key, name)
  else
    if request and C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(key)
    end
    if C_Item and C_Item.GetItemIconByID then
      icon = C_Item.GetItemIconByID(key)
    end
  end
  return name, icon, quality
end

-- Hyperlink for GameTooltip:SetHyperlink.
function A.Hyperlink(key)
  if type(key) == "string" then
    local species = key:match("^p(%d+)")
    return species and ("battlepet:" .. species) or nil
  end
  return "item:" .. key
end

-- An item name's colour in Codex's own lists: the theme's quality colours (readable on a light theme).
function A.QualityColor(quality)
  return ns.QualityColor(quality) or ns.Theme().bright
end

-- Money and time text ------------------------------------------------------------------------------------

-- "12g 50s" without colours, for edit boxes.
function A.PlainMoney(copper)
  if not copper then
    return ""
  end
  copper = math.floor(copper + 0.5)
  local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = gold .. "g"
  end
  if silver > 0 then
    parts[#parts + 1] = silver .. "s"
  end
  if rest > 0 or #parts == 0 then
    parts[#parts + 1] = rest .. "c"
  end
  return table.concat(parts, " ")
end

-- "12g 50s 3c", "12g", "1.5" (a plain number is gold) -> copper; nil when empty or not money.
function A.ParseMoney(text)
  text = (text or ""):lower():match("^%s*(.-)%s*$")
  if text == "" then
    return nil
  end
  local plain = tonumber(text)
  if plain then
    return plain >= 0 and math.floor(plain * 10000 + 0.5) or nil
  end
  local total, found = 0, false
  for amount, unit in text:gmatch("(%d+%.?%d*)%s*([gsc])") do
    found = true
    total = total + tonumber(amount) * (unit == "g" and 10000 or unit == "s" and 100 or 1)
  end
  return found and math.floor(total + 0.5) or nil
end

-- "14m", "40s" for a number of seconds.
function A.Duration(seconds)
  seconds = math.max(0, math.floor(seconds + 0.5))
  if seconds >= 60 then
    return math.ceil(seconds / 60) .. "m"
  end
  return seconds .. "s"
end

-- Shopping lists -----------------------------------------------------------------------------------------

local function Clean(text)
  return ((text or ""):gsub("|", ""):match("^%s*(.-)%s*$"))
end

function A.Lists()
  return A.DB().lists
end

function A.NewList(name)
  name = Clean(name)
  local list = { name = name ~= "" and name or "New list", terms = {} }
  table.insert(A.Lists(), list)
  A.Changed("lists")
  return list
end

function A.RenameList(list, name)
  name = Clean(name)
  if list and name ~= "" then
    list.name = name
    A.Changed("lists")
    return true
  end
  return false
end

local function IndexOf(array, value)
  for index, item in ipairs(array) do
    if item == value then
      return index
    end
  end
end

function A.DeleteList(list)
  local index = IndexOf(A.Lists(), list)
  if index then
    table.remove(A.Lists(), index)
    A.Changed("lists")
    return true
  end
  return false
end

-- text: what to search for; exact: only items with exactly that name; maxPrice: copper or nil.
function A.AddTerm(list, text, exact, maxPrice)
  text = Clean(text)
  if not list or text == "" then
    return nil
  end
  local term = { text = text, exact = exact and true or nil, maxPrice = maxPrice }
  table.insert(list.terms, term)
  A.Changed("lists")
  return term
end

function A.EditTerm(term, text, exact, maxPrice)
  text = Clean(text)
  if not term or text == "" then
    return false
  end
  term.text, term.exact, term.maxPrice = text, exact and true or nil, maxPrice
  A.Changed("lists")
  return true
end

function A.RemoveTerm(list, term)
  local index = list and IndexOf(list.terms, term)
  if index then
    table.remove(list.terms, index)
    A.Changed("lists")
    return true
  end
  return false
end

-- Import from Auctionator (2026-11-21): its saved shopping lists (the global AUCTIONATOR_SHOPPING_LISTS while
-- Auctionator is loaded: { { name, items = { search strings }, isTemporary }, ... }; only that data is read). A
-- search string's first field (up to ";") is the term, in double quotes for an exact name. Temporary lists are
-- left out; a list whose name Codex already has gets only the terms it lacks.

-- term text, exact from one of Auctionator's search strings, or nil
function A.ParseAuctionatorTerm(search)
  if type(search) ~= "string" then
    return nil
  end
  local first = search:match("^([^;]*)") or ""
  first = first:match("^%s*(.-)%s*$")
  local quoted = first:match('^"(.*)"$')
  local text = Clean(quoted or first)
  if text == "" then
    return nil
  end
  return text, quoted ~= nil
end

-- Auctionator's lists worth importing (not temporary, at least one term), or an empty table.
function A.AuctionatorLists()
  local out = {}
  local saved = rawget(_G, "AUCTIONATOR_SHOPPING_LISTS")
  if type(saved) ~= "table" then
    return out
  end
  for _, list in ipairs(saved) do
    if type(list) == "table" and not list.isTemporary and type(list.name) == "string" and type(list.items) == "table"
      and #list.items > 0 then
      out[#out + 1] = list
    end
  end
  return out
end

-- Copies them in. Returns lists made, lists added to, terms added.
function A.ImportAuctionator()
  local made, merged, added = 0, 0, 0
  for _, source in ipairs(A.AuctionatorLists()) do
    local name = Clean(source.name)
    local target
    for _, list in ipairs(A.Lists()) do
      if list.name == name then
        target = list
      end
    end
    local before = target and #target.terms or 0
    if not target then
      target = { name = name ~= "" and name or "Auctionator", terms = {} }
      table.insert(A.Lists(), target)
      made = made + 1
    end
    local have = {}
    for _, term in ipairs(target.terms) do
      have[term.text:lower() .. (term.exact and "|exact" or "")] = true
    end
    for _, search in ipairs(source.items) do
      local text, exact = A.ParseAuctionatorTerm(search)
      local key = text and (text:lower() .. (exact and "|exact" or ""))
      if key and not have[key] then
        have[key] = true
        table.insert(target.terms, { text = text, exact = exact or nil })
        added = added + 1
      end
    end
    if before > 0 and #target.terms > before then
      merged = merged + 1
    end
  end
  if made + added > 0 then
    A.Changed("lists")
  end
  return made, merged, added
end

-- Public API (TylesserCodex.GetAuctionPrice(itemLinkOrID) -> copper, time seen, count).
ns.API.GetAuctionPrice = function(item)
  return A.GetPrice(item)
end
ns.API.GetAuctionHistory = function(item)
  return A.GetHistory(item)
end
