local addonName, ns = ...

-- Commerce module, part 2: saved settings, prices and money text. Tylesser - Commerce Authority ported into
-- Codex (WoW Forever's Azeroth Commerce Authority / Durotar Supply and Logistics): the same writ, crate,
-- reputation and Merchant's Favor features, with Codex's own auction prices (Auction House module) instead of
-- Auctionator / TSM / Auctioneer, craft costs from Codex's Professions module instead of Profit Sort, and
-- Codex's shopping lists and auction panel for the buy list and searches. While the standalone addon is loaded
-- Codex leaves this to it (unless the player forces Codex's copy). Nothing here creates frames.
--
-- CodexDB.commerce (account-wide, like the standalone addon's CommerceAuthorityDB): the options below, the
-- windows' places, and what turn-ins taught (learned, factionIDs: data, kept out of profiles).

local C = ns.commerce

C.TITLE = "Commerce Authority"

C.DEFAULTS = {
  writTooltips = true,       -- writ tooltips: what it needs, prices, reputation
  crateTooltips = true,      -- crate tooltips: Merchant's Favor, silver, what fills it
  vendorMarks = true,        -- at the Commerce Authority vendors: what you can afford
  onlyMyProfessions = false, -- the window's cheapest list: only writs your professions make
  cheapestBy = nil,          -- the window's cheapest list: "writ", "npc" or "zone" (nil: writ; C.CheapestMode)
  position = nil,            -- the window's place
  npcPosition = nil,         -- the Writ NPCs window's place
  npcTier = nil,             -- the Writ NPCs window: only this writ level ("Journeyman", "Expert", "Artisan")
  npcMine = false,           -- the Writ NPCs window: only writs your professions make
  npcNotDone = false,        -- the Writ NPCs window: only writs not turned in today
  npcFolded = {},            -- the Writ NPCs window: folded zones ([uiMapID] = true, unknown = true)
  learned = {
    crates = {},             -- [level .. " raw"/" made"] = { n, total, min, max, last, values }: Favor per turn-in
    writs = {},              -- [writ quest ID] = { n, total, min, max, last, values }: reputation per turn-in
    customers = {},          -- [writ item ID] = { NPC name, uiMapID, x, y }: who took the writ, where
  },
  factionIDs = {},           -- [Alliance/Horde] = the faction's ID, once found in the reputation list
}

-- The standalone addon's saved data, copied once (the first time Codex's copy runs while it is around: the
-- player forced Codex's copy). What turn-ins taught is worth keeping; positions are not.
local IMPORT = { "writTooltips", "crateTooltips", "vendorMarks", "onlyMyProfessions", "npcTier", "npcMine", "npcNotDone", "npcFolded", "cheapestBy", "learned", "factionIDs" }

local function Copy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, inner in pairs(value) do
    copy[key] = Copy(inner)
  end
  return copy
end

function C.DB()
  if not ns.db then
    return nil
  end
  if not ns.db.commerce then
    local target = {}
    local source = CommerceAuthorityDB
    if type(source) == "table" then
      for _, key in ipairs(IMPORT) do
        if source[key] ~= nil then
          target[key] = Copy(source[key])
        end
      end
      if target.cheapestBy == nil and source.cheapestByNPC then
        target.cheapestBy = "npc"
      end
    end
    ns.db.commerce = target
  end
  if C.db ~= ns.db.commerce then
    C.db = ns.Fill(ns.db.commerce, C.DEFAULTS)
  end
  return C.db
end

-- Legacy talents ----------------------------------------------------------------------------------------------
-- Forever's legacy talents are trait tree talents (TraitDefinition rows for these spells, wago.tools DB2, build
-- 1.60.1.70959): Performance Bonus (spell 1225456, "a 15% chance to receive 100% increased Merchant's Favor" from
-- a crate) and Diplomat (1225485, "+10% reputation gains"). Detected like any spell you know, instead of the two
-- check boxes the standalone addon asked you to tick (the user's request, 2026-11-19).

C.PERFORMANCE_BONUS_SPELL = 1225456
C.DIPLOMAT_SPELL = 1225485

local function Yes(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn, ...)
  return ok and C.Readable(result) and result == true
end

-- Whether you have a legacy talent: the spell is yours (IsPlayerSpell / IsSpellKnown / C_SpellBook), or its
-- passive aura is on you.
function C.HasLegacyTalent(spellID)
  if Yes(IsPlayerSpell, spellID) or Yes(IsSpellKnown, spellID) then
    return true
  end
  if C_SpellBook and Yes(C_SpellBook.IsSpellKnown, spellID) then
    return true
  end
  local auras = C_UnitAuras
  if auras and type(auras.GetPlayerAuraBySpellID) == "function" then
    local ok, aura = pcall(auras.GetPlayerAuraBySpellID, spellID)
    if ok and aura ~= nil and C.Readable(aura) then
      return true
    end
  end
  return false
end

function C.HasPerformanceBonus()
  return C.HasLegacyTalent(C.PERFORMANCE_BONUS_SPELL)
end

function C.HasDiplomat()
  return C.HasLegacyTalent(C.DIPLOMAT_SPELL)
end

-- Prices -----------------------------------------------------------------------------------------------------

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end
C.Readable = Readable

function C.ItemLink(itemID)
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo and itemID then
    local ok, _, link = pcall(getInfo, itemID)
    if ok and Readable(link) and type(link) == "string" then
      return link
    end
  end
end

local function AuctionPrice(item)
  local A = ns.auction
  if item == nil or not (A and A.GetPrice) then
    return nil
  end
  local ok, price, seen = pcall(A.GetPrice, item)
  if ok and type(price) == "number" and price > 0 then
    return price, seen
  end
end

-- Codex's auction price for an item: by link first (gear is kept per item level), then by item ID.
-- Returns copper and when it was seen.
function C.AuctionPrice(itemID)
  if not itemID then
    return nil
  end
  local link = C.ItemLink(itemID)
  local price, seen
  if link then
    price, seen = AuctionPrice(link)
  end
  if not price then
    price, seen = AuctionPrice(itemID)
  end
  return price, seen
end

-- The standalone addon listed one price per installed price addon; Codex has one source, its own scans.
-- { { name, price, seen } } or {}.
function C.Prices(itemID)
  local price, seen = C.AuctionPrice(itemID)
  if price then
    return { { name = "Codex", price = price, seen = seen } }
  end
  return {}
end

function C.Price(itemID)
  local price = C.AuctionPrice(itemID)
  return price, price and "Codex" or nil
end

-- Where prices come from, for the page, the window and /codex commerce debug: {} while the Auction House module
-- is off.
function C.PriceSourceNames()
  if ns.ModuleOn and ns.ModuleOn("auction") then
    return { "Codex auction scans" }
  end
  return {}
end

-- Your crafting cost of one item, when Codex's Professions module knows a recipe that makes it (any of your
-- characters) and every reagent has a price.
function C.CraftCost(itemID)
  local P = ns.professions
  if not (itemID and P and P.CraftInfo and ns.ModuleOn and ns.ModuleOn("professions")) then
    return nil
  end
  local ok, craft = pcall(P.CraftInfo, itemID)
  if ok and type(craft) == "table" and craft.cost and not craft.missing then
    return craft.cost / (craft.numMade or 1), craft
  end
end

-- The materials of one craft of an item (Codex's Professions: the cheapest choice of each, { itemID, count }) and how
-- many one craft makes, or nil (the twin of Commerce Authority's ns.CraftReagents, which reads Profit Sort).
function C.CraftReagents(itemID)
  local _, craft = C.CraftCost(itemID)
  if type(craft) ~= "table" or type(craft.reagents) ~= "table" or #craft.reagents == 0 then
    return nil
  end
  local reagents = {}
  for _, reagent in ipairs(craft.reagents) do
    local id = reagent.chosenItemID or reagent.itemID
    if id and reagent.count and reagent.count > 0 then
      reagents[#reagents + 1] = { itemID = id, count = reagent.count }
    end
  end
  if #reagents > 0 then
    return reagents, craft.numMade or 1
  end
end

-- Money and numbers ------------------------------------------------------------------------------------------

-- Codex's coin text, or "--" for nil.
function C.Money(amount)
  if not amount then
    return "--"
  end
  return ns.Money(amount)
end

-- Without copper from 1 gold up (for short columns): "4g 10s".
function C.ShortMoney(amount)
  if amount and amount >= 10000 then
    return C.Money(math.floor(amount / 100 + 0.5) * 100)
  end
  return C.Money(amount)
end

-- "1,234"
function C.Number(value)
  local text = tostring(math.floor((value or 0) + 0.5))
  local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (formatted:gsub("^,", ""))
end
