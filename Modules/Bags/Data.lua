local addonName, ns = ...

-- Bags module, part 1: what every character carries. Each character's bags, bank (from the last bank
-- visit), equipped gear and money are saved account-wide in CodexDB.bags.characters["Realm-Name"], so the
-- bag window can show another character's items and tooltips can count an item on all characters.
-- Also the categories (grouping) and the section packing the window uses. No frames here.

local B = {}
ns.bags = B

local DEFAULTS = {
  replace = true,     -- open the Codex bag window instead of the game's bags
  categories = true,  -- grouped sections; false = bag order
  combine = true,     -- identical items as one button with the total (in categories)
  pack = true,        -- categories side by side while they fit; false = one category per row
  tooltip = true,     -- "Codex: N on your characters" in item tooltips
  bankWindow = true,  -- Codex's bank window at the banker (false = the game's bank window)
  guildBankWindow = true, -- Codex's guild bank window at the guild vault (false = the game's)
  depositButton = true,   -- "Deposit reagents" on the bank window
  columns = 10,
  bankColumns = 14,   -- the bank window's width in items, 10-24
  itemSize = 40,       -- px, 28-44 (round-2 board: 40)
  itemSpacing = 6,     -- px between items, 0-12 (board: 6)
  sectionSpacing = 10, -- px between rows of categories, 0-30 (board: 10)
  hidden = {},        -- [key] = true: left out of tooltips, money totals and the character menu
  characters = {},
}

function B.DB()
  if not B.db then
    local saved = ns.db.bags
    -- the round-2 design's sizes replace the first version's defaults once (37 / 4 / 12)
    if saved and not saved.layout2 then
      if saved.itemSize == 37 then saved.itemSize = nil end
      if saved.itemSpacing == 4 then saved.itemSpacing = nil end
      if saved.sectionSpacing == 12 then saved.sectionSpacing = nil end
    end
    ns.db.bags = ns.Fill(saved or {}, DEFAULTS)
    ns.db.bags.layout2 = true
    B.db = ns.db.bags
  end
  return B.db
end

-- Readable: not nil and not a secret value.
local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end
B.Readable = Readable

-- Bag IDs -------------------------------------------------------------------------------------------------
-- Forever's Enum.BagIndex: Backpack 0, Bag_1..4, ReagentBag 5, Keyring -1, CharacterBankTab_1..9 6..14.

local function BagIndex()
  return (Enum and Enum.BagIndex) or {}
end

function B.KeyringID()
  return BagIndex().Keyring
end

function B.ReagentID()
  return BagIndex().ReagentBag
end

-- Bags 0-4, the reagent bag and the keyring (when the game has them), in display order.
function B.CarriedBags()
  local index = BagIndex()
  local first = index.Backpack or 0
  local list = {}
  for bag = first, first + (NUM_BAG_SLOTS or 4) do
    list[#list + 1] = bag
  end
  if index.ReagentBag then
    list[#list + 1] = index.ReagentBag
  end
  if index.Keyring then
    list[#list + 1] = index.Keyring
  end
  return list
end

function B.IsCarried(bagID)
  for _, bag in ipairs(B.CarriedBags()) do
    if bag == bagID then
      return true
    end
  end
  return false
end

-- The bank's containers: the bank itself and its bag slots or tabs, whatever this client names. Read only
-- while the bank is open; a container with no slots is skipped then.
function B.BankBags()
  local list, seen = {}, {}
  for _, bag in ipairs(B.CarriedBags()) do
    seen[bag] = true
  end
  local function Add(bag)
    if type(bag) == "number" and not seen[bag] then
      seen[bag] = true
      list[#list + 1] = bag
    end
  end
  local index = BagIndex()
  Add(index.Bank)
  Add(BANK_CONTAINER)
  local named = false
  for name, bag in pairs(index) do
    if type(name) == "string" and (name:find("^BankBag") or name:find("^CharacterBankTab")) then
      Add(bag)
      named = true
    end
  end
  if not named and NUM_BANKBAGSLOTS then
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + NUM_BANKBAGSLOTS - 1 do
      Add(bag)
    end
  end
  table.sort(list)
  return list
end

-- Characters ----------------------------------------------------------------------------------------------

-- "Realm-Name" without a surname (ns.CharacterKey: Forever's UnitName gave the surname in some sessions).
function B.PlayerKey()
  return ns.CharacterKey()
end

-- This character's record, made on first use.
function B.Me()
  local db = B.DB()
  local key = B.PlayerKey()
  -- older records of this character under another spelling of its name (with the surname) join this one
  if not B.merged then
    B.merged = true
    if ns.MergeCharacterRecords(db.characters, key, { db.hidden }) > 0 then
      ns.Fire("BAGS_CHANGED", "characters")
    end
  end
  local me = db.characters[key]
  if not me then
    me = { bags = {} }
    db.characters[key] = me
  end
  me.name = ns.PlayerName()
  ns.StoreFullName(me) -- shown in lists (the key keeps the first word)
  me.realm = ns.RealmName()
  me.guid = UnitGUID and UnitGUID("player") or me.guid
  me.class = select(2, UnitClass("player"))
  me.faction = UnitFactionGroup("player")
  return me, key
end

function B.Character(key)
  return B.DB().characters[key]
end

-- Keys of the characters shown in menus and totals (all when includeHidden), this character first, then by
-- realm and name.
function B.CharacterKeys(includeHidden)
  local db = B.DB()
  local mine = B.PlayerKey()
  local keys = {}
  for key in pairs(db.characters) do
    if includeHidden or not db.hidden[key] or key == mine then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys, function(a, b)
    if (a == mine) ~= (b == mine) then
      return a == mine
    end
    return a < b
  end)
  return keys
end

function B.DeleteCharacter(key)
  if key == B.PlayerKey() then
    return false
  end
  local db = B.DB()
  db.characters[key] = nil
  db.hidden[key] = nil
  B.counts[key] = nil
  ns.Fire("BAGS_CHANGED", "characters")
  return true
end

function B.SetHidden(key, hidden)
  B.DB().hidden[key] = hidden and true or nil
  ns.Fire("BAGS_CHANGED", "characters")
end

-- "Name" in its class colour (and " (Realm)" when it is another realm).
function B.ColoredName(key, withRealm)
  local char = B.Character(key)
  if not char then
    return key
  end
  -- this character: the name the game gives now (with the surname once it has it)
  local name = key == B.PlayerKey() and ns.PlayerFullName() or ns.CharacterDisplayName(char, key)
  local color = RAID_CLASS_COLORS and char.class and RAID_CLASS_COLORS[char.class]
  if color then
    name = ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
      math.floor(color.b * 255 + 0.5), name)
  end
  if withRealm ~= false and type(char.realm) == "string" and char.realm ~= "" and char.realm ~= ns.RealmName() then
    name = name .. " |cff999999(" .. char.realm .. ")|r"
  end
  return name
end

-- Money -----------------------------------------------------------------------------------------------------

function B.ScanMoney()
  local money = GetMoney()
  if Readable(money) then
    B.Me().money = money
    B.Me().updated = time()
  end
end

-- { { key, money }, ... } richest first, and the total, of the shown characters.
function B.MoneyList()
  local list, total = {}, 0
  for _, key in ipairs(B.CharacterKeys(false)) do
    local money = B.Character(key).money or 0
    list[#list + 1] = { key = key, money = money }
    total = total + money
  end
  table.sort(list, function(a, b)
    if a.money ~= b.money then
      return a.money > b.money
    end
    return a.key < b.key
  end)
  return list, total
end

-- Scanning --------------------------------------------------------------------------------------------------

-- One slot as saved: { hyperlink, count, quality }.
local function ReadSlot(bagID, slot)
  local info = C_Container.GetContainerItemInfo(bagID, slot)
  if not info or not Readable(info.hyperlink) then
    return nil
  end
  local count = Readable(info.stackCount) and info.stackCount or 1
  local quality = Readable(info.quality) and info.quality or nil
  return { info.hyperlink, count, quality }
end

-- A container as saved: { size = N, [slot] = { link, count, quality } }, or nil when it has no slots.
function B.ReadBag(bagID)
  local size = C_Container.GetContainerNumSlots(bagID) or 0
  if not Readable(size) or size <= 0 then
    return nil
  end
  local bag = { size = size }
  for slot = 1, size do
    bag[slot] = ReadSlot(bagID, slot)
  end
  return bag
end

B.counts = {} -- [key] = { [itemID] = { bags, bank, equipped } }, built when a tooltip first asks

function B.ScanBags()
  local me, key = B.Me()
  local bags = {}
  for _, bagID in ipairs(B.CarriedBags()) do
    bags[bagID] = B.ReadBag(bagID)
  end
  me.bags = bags
  me.updated = time()
  B.counts[key] = nil
  ns.Fire("BAGS_CHANGED", "bags")
end

function B.ScanBank()
  local me, key = B.Me()
  local bank = {}
  for _, bagID in ipairs(B.BankBags()) do
    bank[bagID] = B.ReadBag(bagID)
  end
  me.bank = bank
  me.bankUpdated = time()
  B.counts[key] = nil
  ns.Fire("BAGS_CHANGED", "bank")
end

function B.ScanEquipped()
  local me, key = B.Me()
  local equipped = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if Readable(link) then
      equipped[slot] = link
    end
  end
  me.equipped = equipped
  B.counts[key] = nil
end

-- Counts ----------------------------------------------------------------------------------------------------

function B.ItemID(link)
  if type(link) == "number" then
    return link
  end
  return link and tonumber(link:match("item:(%d+)"))
end

local function CountInto(counts, containers, field)
  for _, bag in pairs(containers or {}) do
    for slot = 1, bag.size or 0 do
      local item = bag[slot]
      local id = item and B.ItemID(item[1])
      if id then
        counts[id] = counts[id] or { bags = 0, bank = 0, equipped = 0 }
        counts[id][field] = counts[id][field] + (item[2] or 1)
      end
    end
  end
end

-- [itemID] = { bags = n, bank = n, equipped = n } for one character.
function B.CountsOf(key)
  local counts = B.counts[key]
  if counts then
    return counts
  end
  counts = {}
  local char = B.Character(key)
  if char then
    CountInto(counts, char.bags, "bags")
    CountInto(counts, char.bank, "bank")
    for _, link in pairs(char.equipped or {}) do
      local id = B.ItemID(link)
      if id then
        counts[id] = counts[id] or { bags = 0, bank = 0, equipped = 0 }
        counts[id].equipped = counts[id].equipped + 1
      end
    end
  end
  B.counts[key] = counts
  return counts
end

-- { { key, bags, bank, equipped, total }, ... } most first, and the total, over the shown characters.
function B.ItemCounts(itemID)
  local list, total = {}, 0
  for _, key in ipairs(B.CharacterKeys(false)) do
    local c = B.CountsOf(key)[itemID]
    if c then
      local sum = c.bags + c.bank + c.equipped
      if sum > 0 then
        list[#list + 1] = { key = key, bags = c.bags, bank = c.bank, equipped = c.equipped, total = sum }
        total = total + sum
      end
    end
  end
  table.sort(list, function(a, b)
    if a.total ~= b.total then
      return a.total > b.total
    end
    return a.key < b.key
  end)
  return list, total
end

-- Categories ------------------------------------------------------------------------------------------------

B.CATEGORIES = {
  { id = "new", name = "New items" },
  { id = "equipment", name = "Equipment" },
  { id = "consumable", name = "Consumables" },
  { id = "trade", name = "Trade goods" },
  { id = "recipe", name = "Recipes" },
  { id = "quest", name = "Quest items" },
  { id = "key", name = "Keys" },
  { id = "misc", name = "Miscellaneous" },
  { id = "junk", name = "Junk" },
}

-- Item class IDs (Enum.ItemClass) to a category.
local BY_CLASS = {
  [0] = "consumable", -- consumable
  [1] = "equipment",  -- container (bags)
  [2] = "equipment",  -- weapon
  [3] = "trade",      -- gem
  [4] = "equipment",  -- armour
  [5] = "trade",      -- reagent
  [6] = "consumable", -- projectile (ammo)
  [7] = "trade",      -- trade goods
  [8] = "consumable", -- item enhancement
  [9] = "recipe",
  [11] = "equipment", -- quiver
  [12] = "quest",
  [13] = "key",
  [19] = "trade",     -- profession
}

-- Name from a hyperlink ("[Linen Cloth]"), else from the item cache (nil until it is loaded).
function B.ItemName(link)
  local name = type(link) == "string" and link:match("|h%[(.-)%]|h")
  if name and name ~= "" then
    return name
  end
  local get = C_Item and C_Item.GetItemInfo
  name = get and get(link)
  if not name then
    local id = B.ItemID(link)
    if id then
      B.pending[id] = true
      if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
      end
    end
  end
  return name
end
B.pending = {} -- item IDs whose names are on their way (GET_ITEM_INFO_RECEIVED)

-- entry: { link, quality, isNew, isQuest, bagID }
function B.Category(entry)
  if entry.isNew then
    return "new"
  end
  if entry.bagID ~= nil and entry.bagID == B.KeyringID() then
    return "key"
  end
  if entry.isQuest then
    return "quest"
  end
  if entry.quality == 0 then
    return "junk"
  end
  local classID = select(6, C_Item.GetItemInfoInstant(entry.link))
  return BY_CLASS[classID] or "misc"
end

local function SortEntries(a, b)
  local qa, qb = a.quality or 1, b.quality or 1
  if qa ~= qb then
    return qa > qb
  end
  local na, nb = a.sortName or "~", b.sortName or "~"
  if na ~= nb then
    return na < nb
  end
  local ia, ib = B.ItemID(a.link) or 0, B.ItemID(b.link) or 0
  if ia ~= ib then
    return ia < ib
  end
  return (a.order or 0) < (b.order or 0)
end

-- Item entries into category sections, in B.CATEGORIES order: { { id, name, entries = {...} }, ... }.
-- Each entry gets .category and .sortName; empty categories are left out.
function B.Group(entries)
  local byID = {}
  for index, entry in ipairs(entries) do
    entry.category = entry.category or B.Category(entry)
    local name = B.ItemName(entry.link)
    entry.sortName = name and name:lower()
    entry.order = entry.order or index
    byID[entry.category] = byID[entry.category] or {}
    table.insert(byID[entry.category], entry)
  end
  local sections = {}
  for _, category in ipairs(B.CATEGORIES) do
    local list = byID[category.id]
    if list then
      table.sort(list, SortEntries)
      sections[#sections + 1] = { id = category.id, name = category.name, entries = list }
    end
  end
  return sections
end

-- Entries of a saved container set (another character's bags or a bank), in bag order.
function B.SavedEntries(containers)
  local entries, free, size = {}, 0, 0
  local ids = {}
  for bagID in pairs(containers or {}) do
    ids[#ids + 1] = bagID
  end
  table.sort(ids, function(a, b)
    -- the keyring (negative) last
    if (a < 0) ~= (b < 0) then
      return b < 0
    end
    return a < b
  end)
  for _, bagID in ipairs(ids) do
    local bag = containers[bagID]
    for slot = 1, bag.size or 0 do
      local item = bag[slot]
      if item then
        entries[#entries + 1] = { link = item[1], count = item[2], quality = item[3], bagID = bagID, slot = slot,
          order = #entries + 1 }
      elseif bagID ~= B.KeyringID() then
        free = free + 1
      end
      if bagID ~= B.KeyringID() then
        size = size + 1
      end
    end
  end
  return entries, free, size
end

-- Combining -------------------------------------------------------------------------------------------------
-- Identical items show as one button with the total. Gear is identical only when the whole link is (item
-- level, suffix, enchant); anything else by item ID.

-- Open windows where single stacks matter (bank, trade, mail, merchant, guild bank, auction house).
B.interacting = {}

function B.SetInteracting(what, open)
  local before = B.ShouldCombine()
  B.interacting[what] = open and true or nil
  if before ~= B.ShouldCombine() then
    ns.Fire("BAGS_CHANGED", "combine")
    if B.RequestRefresh then
      B.RequestRefresh()
    end
  end
end

-- Combined now: the option is on, the view is grouped and no window wants single stacks.
function B.ShouldCombine()
  local db = B.db
  return db ~= nil and db.combine and db.categories and next(B.interacting) == nil or false
end

function B.CombineKey(link)
  if type(link) ~= "string" then
    return nil
  end
  local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
  if type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
    return link:match("|H(item:[^|]+)|h") or link
  end
  local id = B.ItemID(link)
  return id and ("id:" .. id) or link
end

-- One entry per identical item, the first in bag order standing for the rest: .total (all slots), .stacks,
-- .combineKey; new / quest when any of its stacks is. Other entries pass through untouched.
function B.Combine(entries)
  local out, byKey = {}, {}
  for _, entry in ipairs(entries) do
    local key = B.CombineKey(entry.link)
    local first = key and byKey[key]
    if first then
      first.total = first.total + (entry.count or 1)
      first.stacks = first.stacks + 1
      first.isNew = first.isNew or entry.isNew
      first.isQuest = first.isQuest or entry.isQuest
    else
      local combined = {}
      for field, value in pairs(entry) do
        combined[field] = value
      end
      combined.total, combined.stacks, combined.combineKey = entry.count or 1, 1, key
      out[#out + 1] = combined
      if key then
        byKey[key] = combined
      end
    end
  end
  return out
end

-- Totals per combine key over entries ({ [key] = { total, stacks } }), for refreshing counts in combat.
function B.CombineTotals(entries)
  local totals = {}
  for _, entry in ipairs(entries) do
    local key = B.CombineKey(entry.link)
    if key then
      local t = totals[key] or { total = 0, stacks = 0 }
      t.total, t.stacks = t.total + (entry.count or 1), t.stacks + 1
      totals[key] = t
    end
  end
  return totals
end

-- Does an entry match the search text (lower case)? Empty text matches everything.
function B.Matches(entry, search)
  if not search or search == "" then
    return true
  end
  local name = B.ItemName(entry.link)
  return name ~= nil and name:lower():find(search, 1, true) ~= nil
end

-- Packing ---------------------------------------------------------------------------------------------------
-- Sections are laid out as blocks on shelves (rows of blocks) over a grid of `columns` cells, `cell` px
-- each: a block is a heading over a grid of cells. Packed (`pack` true, the default), a block is as wide
-- as its items need (its count, or ceil(count / rows) cells when it needs several rows, never less than
-- its heading's `minCols`), blocks follow each other on the shelf in section order while they fit, and a
-- block that doesn't fit in the room left is made narrower and taller when that doesn't make the shelf
-- taller, else it starts the next shelf; a block wider than a shelf spans full rows. Not packed: one
-- block per shelf. Blocks side by side are one cell spacing apart, so every cell of the window lines up.
-- A section with `wide` (the bag-order grid) is never narrower than its count allows.
-- Returns { blocks = { { section, x, y, cols, rows, height } }, width, height } in pixels; each block's
-- cells go left to right, top to bottom from (x, y + heading); a shelf is `gap` px under the one before.

function B.Pack(sections, columns, cell, heading, gap, pack)
  pack = pack ~= false
  local blocks = {}
  local used, y, shelfRows, shelfHeight = 0, 0, 0, 0 -- cells taken on the shelf, its top, its rows and height
  for _, section in ipairs(sections) do
    local count = math.max(1, #section.entries)
    local minCols = math.max(1, math.min(columns, section.minCols or 1))
    -- the block's shape within `limit` cells; nil when it needs more than `maxRows` rows or its heading
    -- doesn't fit
    local function Fit(limit, maxRows)
      if limit < minCols then
        return nil
      end
      local cols = math.min(limit, count)
      local rows = math.ceil(count / cols)
      if pack and not section.wide then
        cols = math.ceil(count / rows) -- as narrow as those rows allow (11 items: 6 x 2, not 10 + 1)
      end
      if maxRows and rows > maxRows then
        return nil
      end
      return math.max(cols, minCols), rows
    end
    local cols, rows
    if used > 0 then
      if pack then
        local c, r = Fit(columns)
        if c <= columns - used then
          cols, rows = c, r
        else
          cols, rows = Fit(columns - used, shelfRows)
        end
      end
      if not cols then
        used, y, shelfRows, shelfHeight = 0, y + shelfHeight + gap, 0, 0
      end
    end
    if not cols then
      cols, rows = Fit(columns)
    end
    local height = (section.name and heading or 0) + rows * cell
    blocks[#blocks + 1] = { section = section, x = used * cell, y = y, cols = cols, rows = rows, height = height }
    used = used + cols
    shelfRows = math.max(shelfRows, rows)
    shelfHeight = math.max(shelfHeight, height)
  end
  return { blocks = blocks, width = columns * cell, height = y + shelfHeight }
end
