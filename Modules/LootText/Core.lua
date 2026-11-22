local addonName, ns = ...

-- Loot text (2026-11-21, the user's request: "floating text when you get gold, loot items etc."; they picked every
-- kind of line, both looks, and value + glow, a watch list, hiding the game's loot toasts and a session summary).
-- What other addons offer was looked at (BattleText Forever, ScrollingLoot, Lootline, Loot Pro, MSBT); nothing of
-- theirs is used.
--
-- Part 1: what happened. Every source is the game's own event, checked against Forever's API docs (forever branch,
-- Blizzard_APIDocumentationGenerated):
--   items       CHAT_MSG_LOOT, your own lines only (LOOT_ITEM_SELF / _PUSHED_SELF / _CREATED_SELF and their
--               _MULTIPLE forms, turned into patterns from the client's own strings)
--   money       PLAYER_MONEY: the rise of GetMoney(); while a merchant, the mailbox, the auction house, a trade or
--               the guild bank is open only with "money from sales and mail"
--   reputation  CHAT_MSG_COMBAT_FACTION_CHANGE (FACTION_STANDING_INCREASED / DECREASED and the bonus forms)
--   XP          PLAYER_XP_UPDATE: the rise of UnitXP (across a level too), with how many more of the same reach the
--               next level
--   honor       CHAT_MSG_COMBAT_HONOR_GAIN (the last number in the line)
--   currencies  CURRENCY_DISPLAY_UPDATE (currencyType, quantity, quantityChange: no text to read)
--   skill-ups   CHAT_MSG_SKILL (SKILL_RANK_UP); this one is SecretInChatMessagingLockdown: a secret text is skipped
--   Legacy      MAJOR_FACTION_RENOWN_LEVEL_CHANGED for Forever's Legacy reward track (LegacyConsts
--               LEGACY_REWARD_TRACK_FACTION_ID 2802: its renown level is your account's Legacy points; 2026-11-22)
-- None of the others is marked secret, but every value read is checked (ns.Plain) before it is compared.
-- The game's loot toasts follow the CVar enableLootToasts (AlertFrameSystems.lua: LootAlertSystem ignores alerts
-- while it is 0); "hide the game's loot toasts" sets it, keeping the player's own value to put back.

local LT = {}
ns.loottext = LT

LT.DEFAULTS = {
  style = "float", -- "float" (rises from the middle), "down" (falls from it) or "list" (stacks by the chat)
  size = 15, duration = 4, maxLines = 8,
  items = true, junk = true, crafted = false, money = true, otherMoney = false,
  reputation = true, xp = true, honor = true, currency = true, skill = true, legacy = true,
  minQuality = 0, showValue = true, allCharacters = true,
  glowValue = 10000, glowEpic = true, glowSound = "coin",
  watch = {}, watchSound = "toast",
  hideToasts = true,
}

function LT.DB()
  if not LT.db then
    ns.db.loottext = ns.Fill(ns.db.loottext or {}, LT.DEFAULTS)
    LT.db = ns.db.loottext
    if type(LT.db.watch) ~= "table" then
      LT.db.watch = {}
    end
  end
  return LT.db
end

local function Plain(value)
  return value ~= nil and ns.Plain(value) and value or nil
end

local function Num(value)
  value = Plain(value)
  return type(value) == "number" and value or tonumber(type(value) == "string" and value or nil)
end

local function Str(value)
  value = Plain(value)
  return type(value) == "string" and value or nil
end

-- Patterns from the client's own strings ------------------------------------------------------------------------

-- A format string ("You receive loot: %sx%d.") as an anchored Lua pattern: %s -> (.-), %d -> number, %.1f -> number.
function LT.Pattern(format)
  if type(format) ~= "string" or format == "" then
    return nil
  end
  local out, index = { "^" }, 1
  while index <= #format do
    local spec = format:match("^%%%d*%$?[%-%d%.]*[sdfi%%]", index)
    if spec then
      local kind = spec:sub(-1)
      if kind == "s" then
        out[#out + 1] = "(.-)"
      elseif kind == "d" or kind == "i" then
        out[#out + 1] = "(%-?%d+)"
      elseif kind == "f" then
        out[#out + 1] = "(%-?[%d%.]+)"
      else
        out[#out + 1] = "%%"
      end
      index = index + #spec
    else
      local char = format:sub(index, index)
      if char:find("[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        char = "%" .. char
      end
      out[#out + 1] = char
      index = index + 1
    end
  end
  out[#out + 1] = "$"
  return table.concat(out)
end

-- { pattern, kind, multiple } in the order they are tried (the "x%d" forms first). English fallbacks only when the
-- client lacks a string.
local ITEM_STRINGS = {
  { "LOOT_ITEM_SELF_MULTIPLE", "You receive loot: %sx%d.", "loot", true },
  { "LOOT_ITEM_SELF", "You receive loot: %s.", "loot" },
  { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "You receive item: %sx%d.", "pushed", true },
  { "LOOT_ITEM_PUSHED_SELF", "You receive item: %s.", "pushed" },
  { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "You create: %sx%d.", "created", true },
  { "LOOT_ITEM_CREATED_SELF", "You create: %s.", "created" },
}
local REP_STRINGS = {
  { "FACTION_STANDING_INCREASED_DOUBLE_BONUS", 1 },
  { "FACTION_STANDING_INCREASED_ACH_BONUS", 1 },
  { "FACTION_STANDING_INCREASED_BONUS", 1 },
  { "FACTION_STANDING_INCREASED", 1, "Your %s reputation has increased by %d." },
  { "FACTION_STANDING_DECREASED", -1, "Your %s reputation has decreased by %d." },
}
local SKILL_STRINGS = { { "SKILL_RANK_UP", "Your skill in %s has increased to %d." } }

local patterns
local function Patterns()
  if patterns then
    return patterns
  end
  patterns = { items = {}, rep = {}, skill = {} }
  for _, spec in ipairs(ITEM_STRINGS) do
    local pattern = LT.Pattern(Str(_G[spec[1]]) or spec[2])
    if pattern then
      patterns.items[#patterns.items + 1] = { pattern = pattern, kind = spec[3], multiple = spec[4] }
    end
  end
  for _, spec in ipairs(REP_STRINGS) do
    local pattern = LT.Pattern(Str(_G[spec[1]]) or spec[3])
    if pattern then
      patterns.rep[#patterns.rep + 1] = { pattern = pattern, sign = spec[2] }
    end
  end
  for _, spec in ipairs(SKILL_STRINGS) do
    local pattern = LT.Pattern(Str(_G[spec[1]]) or spec[2])
    if pattern then
      patterns.skill[#patterns.skill + 1] = pattern
    end
  end
  return patterns
end

-- "You receive loot: [Linen Cloth]x3." -> link, 3, "loot"; someone else's line -> nil.
function LT.ParseLoot(text)
  text = Str(text)
  if not text then
    return nil
  end
  for _, spec in ipairs(Patterns().items) do
    local link, count = text:match(spec.pattern)
    if link and link:find("|H", 1, true) then
      return link, spec.multiple and tonumber(count) or 1, spec.kind
    end
  end
  return nil
end

-- "Your Stormwind reputation has increased by 250." -> "Stormwind", 250 (negative for a loss).
function LT.ParseReputation(text)
  text = Str(text)
  if not text then
    return nil
  end
  for _, spec in ipairs(Patterns().rep) do
    local faction, amount = text:match(spec.pattern)
    if faction and tonumber(amount) then
      return faction, tonumber(amount) * spec.sign
    end
  end
  return nil
end

function LT.ParseSkill(text)
  text = Str(text)
  if not text then
    return nil
  end
  for _, pattern in ipairs(Patterns().skill) do
    local skill, rank = text:match(pattern)
    if skill and tonumber(rank) then
      return skill, tonumber(rank)
    end
  end
  return nil
end

-- Items -----------------------------------------------------------------------------------------------------------

function LT.ItemID(link)
  local id = type(link) == "string" and link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

function LT.ItemInfo(link)
  local id = LT.ItemID(link)
  local name = type(link) == "string" and link:match("|h%[(.-)%]|h")
  local quality, icon, sellPrice
  if C_Item and C_Item.GetItemInfo then
    local info = { pcall(C_Item.GetItemInfo, link) }
    if info[1] then
      name = Str(info[2]) or name
      quality, sellPrice = Num(info[4]), Num(info[12])
    end
  end
  if quality == nil and id and C_Item and C_Item.GetItemQualityByID then
    quality = Num(select(2, pcall(C_Item.GetItemQualityByID, id)))
  end
  if id and C_Item and C_Item.GetItemIconByID then
    icon = Plain(select(2, pcall(C_Item.GetItemIconByID, id)))
  end
  return { id = id, name = name or "?", quality = quality, icon = icon, sellPrice = sellPrice }
end

-- One item's worth: Codex's auction price, else what a merchant pays.
function LT.UnitValue(link, info)
  local auction = ns.auction
  if auction and type(auction.GetPrice) == "function" then
    local ok, price = pcall(auction.GetPrice, link)
    if ok and type(price) == "number" and price > 0 then
      return price, "auction"
    end
  end
  if info and info.sellPrice and info.sellPrice > 0 then
    return info.sellPrice, "vendor"
  end
  return nil
end

-- How many you have now (bags and bank), and with your other characters when the Bags module knows them.
function LT.Totals(id)
  local own = 0
  if id and C_Item and C_Item.GetItemCount then
    own = Num(select(2, pcall(C_Item.GetItemCount, id, true))) or 0
  end
  local others = 0
  local bags = ns.bags
  if LT.DB().allCharacters and id and bags and type(bags.ItemCounts) == "function" then
    local ok, list = pcall(bags.ItemCounts, id)
    local mine = ns.CharacterKey and ns.CharacterKey()
    if ok and type(list) == "table" then
      for _, entry in ipairs(list) do
        if ns.NormalizeCharacterKey(entry.key) ~= mine then
          others = others + (entry.total or 0)
        end
      end
    end
  end
  return own, others
end

-- Watch list: item IDs and lower-case names.
function LT.Watched(info)
  local watch = LT.DB().watch
  return (info.id and watch[info.id]) or (info.name and watch[info.name:lower()]) or false
end

function LT.AddWatch(text)
  text = type(text) == "string" and strtrim(text) or ""
  if text == "" then
    return nil
  end
  local id = LT.ItemID(text) or tonumber(text)
  local key = id or (text:match("%[(.-)%]") or text):lower()
  LT.DB().watch[key] = true
  return key
end

function LT.RemoveWatch(key)
  LT.DB().watch[key] = nil
end

-- The session (since login): what was looted, for the info bar's gold tooltip.
LT.session = { start = nil, money = 0, value = 0, items = 0, best = nil }

function LT.ResetSession()
  LT.session = { start = GetTime(), money = 0, value = 0, items = 0, best = nil }
end

function LT.Session()
  local s = LT.session
  local hours = math.max((GetTime() - (s.start or GetTime())) / 3600, 1 / 60)
  return { money = s.money, value = s.value, items = s.items, best = s.best,
    perHour = math.floor((s.money + s.value) / hours + 0.5), minutes = math.floor(hours * 60 + 0.5) }
end

-- An item line: the display decides how it looks (Display.lua); here what it is.
function LT.OnItem(link, count, kind)
  local db = LT.DB()
  if not db.items or (kind == "created" and not db.crafted) then
    return
  end
  local info = LT.ItemInfo(link)
  local quality = info.quality or 1
  local unit = LT.UnitValue(link, info)
  local value = unit and unit * count or nil
  local watched = LT.Watched(info)
  if kind ~= "created" then
    LT.session.items = LT.session.items + count
    if value then
      LT.session.value = LT.session.value + value
      if not LT.session.best or value > LT.session.best.value then
        LT.session.best = { link = link, value = value, count = count }
      end
    end
  end
  if quality < db.minQuality and not watched then
    return
  end
  if quality == 0 and db.junk and not watched then
    LT.Show({ key = "junk", kind = "junk", amount = count, value = value or 0 })
    return
  end
  local glow = watched or (db.glowEpic and quality >= 4)
    or (db.glowValue and db.glowValue > 0 and value and value >= db.glowValue) or false
  LT.Show({ key = "item:" .. (info.id or info.name), kind = "item", link = link, info = info, amount = count,
    value = db.showValue and value or nil, unit = unit, glow = glow and true or false, watched = watched })
end

-- Money ------------------------------------------------------------------------------------------------------------

local OTHER_MONEY_FRAMES = { "MerchantFrame", "MailFrame", "SendMailFrame", "AuctionHouseFrame", "TradeFrame",
  "GuildBankFrame", "CodexGuildBankFrame" }

function LT.OtherMoneyWindow()
  for _, name in ipairs(OTHER_MONEY_FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" and frame.IsShown and frame:IsShown() then
      return true
    end
  end
  return false
end

function LT.OnMoney()
  local money = Num(GetMoney and GetMoney())
  if not money then
    return
  end
  local last = LT.lastMoney
  LT.lastMoney = money
  if not last or money <= last then
    return
  end
  local gain = money - last
  if LT.OtherMoneyWindow() then
    if LT.DB().money and LT.DB().otherMoney then
      LT.Show({ key = "money", kind = "money", amount = gain })
    end
    return
  end
  LT.session.money = LT.session.money + gain
  if LT.DB().money then
    LT.Show({ key = "money", kind = "money", amount = gain })
  end
end

-- XP ---------------------------------------------------------------------------------------------------------------

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  return ok and value or nil
end

function LT.OnXP()
  local xp, max, level = Num(Ask(UnitXP, "player")), Num(Ask(UnitXPMax, "player")), Num(Ask(UnitLevel, "player"))
  if not (xp and max and level) then
    return
  end
  local last = LT.lastXP
  LT.lastXP = { xp = xp, max = max, level = level }
  if not last then
    return
  end
  local gain
  if level == last.level then
    gain = xp - last.xp
  elseif level > last.level then
    gain = (last.max - last.xp) + xp -- across a level (more than one at once is too rare to count)
  end
  if not gain or gain <= 0 or not LT.DB().xp then
    return
  end
  local left = max - xp
  LT.Show({ key = "xp", kind = "xp", amount = gain, left = left > 0 and math.ceil(left / gain) or nil })
end

-- Events -----------------------------------------------------------------------------------------------------------

local EVENTS = { "CHAT_MSG_LOOT", "PLAYER_MONEY", "CHAT_MSG_COMBAT_FACTION_CHANGE", "PLAYER_XP_UPDATE",
  "PLAYER_LEVEL_UP", "CHAT_MSG_COMBAT_HONOR_GAIN", "CURRENCY_DISPLAY_UPDATE", "CHAT_MSG_SKILL",
  "PLAYER_ENTERING_WORLD", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }
LT.LEGACY_FACTION = Constants and Constants.LegacyConsts and Constants.LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID
  or 2802

function LT.OnEvent(event, ...)
  local db = LT.DB()
  if event == "CHAT_MSG_LOOT" then
    local link, count, kind = LT.ParseLoot(...)
    if link then
      LT.OnItem(link, count, kind)
    end
  elseif event == "PLAYER_MONEY" then
    LT.OnMoney()
  elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
    LT.OnXP()
  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local faction, amount = LT.ParseReputation(...)
    if faction and db.reputation and amount ~= 0 then
      LT.Show({ key = "rep:" .. faction, kind = "reputation", name = faction, amount = amount })
    end
  elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
    local text = Str(...)
    local amount = text and tonumber(text:match("(%d+)%D*$"))
    if amount and amount > 0 and db.honor then
      LT.Show({ key = "honor", kind = "honor", amount = amount })
    end
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    local id, _, change = ...
    id, change = Num(id), Num(change)
    if id and change and change > 0 and db.currency then
      local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and select(2, pcall(C_CurrencyInfo.GetCurrencyInfo, id))
      local name = type(info) == "table" and Str(info.name) or nil
      if name and name ~= (Str(_G.HONOR) or "Honor") then -- honor has its own line
        LT.Show({ key = "currency:" .. id, kind = "currency", name = name, icon = Plain(info.iconFileID),
          amount = change })
      end
    end
  elseif event == "CHAT_MSG_SKILL" then
    local skill, rank = LT.ParseSkill(...)
    if skill and db.skill then
      LT.Show({ key = "skill:" .. skill, kind = "skill", name = skill, rank = rank, replace = true })
    end
  elseif event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
    local faction, new, old = ...
    faction, new, old = Num(faction), Num(new), Num(old)
    if faction == LT.LEGACY_FACTION and new and old and new > old and db.legacy then
      LT.Show({ key = "legacy", kind = "legacy", amount = new - old, total = new })
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    LT.lastMoney = Num(GetMoney and GetMoney())
    LT.lastXP = nil
    LT.OnXP()
  end
end

-- The game's loot toasts -------------------------------------------------------------------------------------------

local TOAST_CVAR = "enableLootToasts"

local function GetCVarValue(name)
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  local ok, value = pcall(get, name)
  return ok and Str(value) or nil
end

local function SetCVarValue(name, value)
  local set = (C_CVar and C_CVar.SetCVar) or SetCVar
  pcall(set, name, value)
end

-- Hidden while the module runs with the option on; the player's own value back otherwise.
function LT.ApplyToasts()
  local db = ns.db and ns.db.loottext
  if type(db) ~= "table" then
    return
  end
  local want = LT.running and db.hideToasts and ns.ModuleState("loottext") == "on"
  if want then
    if db.savedToasts == nil then
      db.savedToasts = GetCVarValue(TOAST_CVAR) or false -- false: the client has no such CVar
    end
    if db.savedToasts ~= false and GetCVarValue(TOAST_CVAR) ~= "0" then
      SetCVarValue(TOAST_CVAR, "0")
    end
  elseif db.savedToasts ~= nil then
    if type(db.savedToasts) == "string" then
      SetCVarValue(TOAST_CVAR, db.savedToasts)
    end
    db.savedToasts = nil
  end
end

-- Switched off in the Codex window: the toasts come back at once (Codex's own event bus).
ns.On("RELOAD_STATE", function()
  local db = ns.db and ns.db.loottext
  if type(db) == "table" and db.savedToasts ~= nil and ns.ModuleState("loottext") ~= "on" then
    LT.running = false
    LT.ApplyToasts()
  end
end)

function LT.Set(key, value)
  LT.DB()[key] = value
  if key == "hideToasts" then
    LT.ApplyToasts()
  end
  if key == "style" or key == "size" or key == "maxLines" then
    if LT.Relayout then
      LT.Relayout()
    end
  end
  ns.Fire("LOOTTEXT_CHANGED")
end

function LT.Enable()
  LT.DB()
  LT.running = true
  LT.ResetSession()
  LT.lastMoney = Num(GetMoney and GetMoney())
  LT.OnXP()
  local frame = CreateFrame("Frame")
  LT.events = frame
  for _, event in ipairs(EVENTS) do
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function(_, event, ...)
    local ok, err = pcall(LT.OnEvent, event, ...)
    if not ok then
      geterrorhandler()(err)
    end
  end)
  LT.ApplyToasts()
  if LT.BuildDisplay then
    LT.BuildDisplay()
  end
end
