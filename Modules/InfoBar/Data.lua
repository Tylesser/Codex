local addonName, ns = ...

-- Info bars, part 1: settings and the data texts (board R3-InfoBars). No frames here.
--
-- A data text is { id, name, icon, events = { ... }, unitEvents = { EVENT = "player" }, tick = true when it
-- changes by itself (clock, frame rate, coordinates: the bars' 1 s ticker runs only while one is shown),
-- Value() -> label, value, valueColor, note, noteColor (nil = nothing to show), Tooltip(tip), Click(button) }.
-- Colors are theme keys ("bright", "good", ...) or { r, g, b }. Every game value is read through Num/Str, so a
-- secret value is never compared or used in maths.

local I = {}
ns.infobar = I

local DEFAULTS = {
  top = true,           -- the screen bar
  panel = true,         -- the data panel under the chat window
  position = "top",     -- the screen bar at the "top" or "bottom" of the screen
  room = true,          -- the game's frames at the bar's edge are moved out of its way (session only, never saved by Edit Mode)
  fit = false,          -- option: the bar fits itself beside those frames instead of running full width
  clock24 = true,
  slots = {
    t1 = "gold", t2 = "bags", t3 = "zone", t4 = "xp", t5 = "rep", t6 = "prof", t7 = "clock",
    p1 = "fps", p2 = "guild", p3 = "friends", p4 = "durability",
  },
}

-- The slots of both bars, in order. side: where a screen bar slot sits (the middle one stretches).
I.SLOTS = {
  { key = "t1", bar = "top", side = "left", name = "Left 1" },
  { key = "t2", bar = "top", side = "left", name = "Left 2" },
  { key = "t3", bar = "top", side = "center", name = "Middle" },
  { key = "t4", bar = "top", side = "right", name = "Right 1" },
  { key = "t5", bar = "top", side = "right", name = "Right 2" },
  { key = "t6", bar = "top", side = "right", name = "Right 3" },
  { key = "t7", bar = "top", side = "right", name = "Right 4" },
  { key = "p1", bar = "panel", name = "Slot 1" },
  { key = "p2", bar = "panel", name = "Slot 2" },
  { key = "p3", bar = "panel", name = "Slot 3" },
  { key = "p4", bar = "panel", name = "Slot 4" },
}

function I.DB()
  if not I.db then
    ns.db.infobar = ns.Fill(ns.db.infobar or {}, DEFAULTS)
    I.db = ns.db.infobar
  end
  return I.db
end

-- Helpers ----------------------------------------------------------------------------------------------------

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end
I.Readable = Readable

local function Num(value)
  return type(value) == "number" and Readable(value) and value or nil
end
I.Num = Num

local function Str(value)
  return type(value) == "string" and Readable(value) and value ~= "" and value or nil
end
I.Str = Str

-- A call that may be missing or fail on this client: its results, or nothing.
local function Pass(ok, ...)
  if not ok then
    return nil
  end
  return ...
end
local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Pass(pcall(fn, ...))
end
I.Ask = Ask

local function Group(n)
  n = math.floor(n + 0.5)
  if BreakUpLargeNumbers then
    return BreakUpLargeNumbers(n)
  end
  return tostring(n)
end
I.Group = Group

local function Percent(value)
  return ("%.1f%%"):format(value)
end

-- "|cffrrggbb" for a theme key or a color.
function I.Hex(color)
  local theme = ns.InkTheme and ns.InkTheme() or ns.Theme()
  if type(color) == "string" then
    color = theme[color] or theme.text
  end
  color = color or theme.text
  local r = color[1] or color.r or 1
  local g = color[2] or color.g or 1
  local b = color[3] or color.b or 1
  return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
-- 46g 41s 29c with the game's coin icons; gold only when there is some (full numbers, grouped).
function I.Coins(copper)
  copper = math.floor(math.abs(copper or 0) + 0.5)
  local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if gold > 0 then
    parts[#parts + 1] = Group(gold) .. COIN:format("Gold")
  end
  if gold > 0 or silver > 0 then
    parts[#parts + 1] = silver .. COIN:format("Silver")
  end
  parts[#parts + 1] = rest .. COIN:format("Copper")
  -- the theme's money colour on the numbers (Dusk, Dawn); the coin icons stay the game's
  local hex = ns.MoneyHex and ns.MoneyHex()
  if hex then
    return "|cff" .. hex .. table.concat(parts, " ") .. "|r"
  end
  return table.concat(parts, " ")
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown()
end

-- Game windows opened from a click: never in combat (some refuse addon code there).
local function Open(fn, ...)
  if InCombat() or type(fn) ~= "function" then
    return
  end
  pcall(fn, ...)
end
I.Open = Open

local function ClassColor(class)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and { color.r, color.g, color.b } or nil
end

local function PctColor(pct)
  return pct < 50 and "bad" or (pct < 80 and "warn" or "good")
end
I.PctColor = PctColor

I.TEXTS = {}
I.ORDER = {}
local function Add(text)
  I.TEXTS[text.id] = text
  I.ORDER[#I.ORDER + 1] = text.id
  text.icon = text.icon and ("Interface\\AddOns\\Codex\\Modules\\InfoBar\\Media\\" .. text.icon)
end

-- Friends ----------------------------------------------------------------------------------------------------

local function WowFriends()
  local list = {}
  local count = C_FriendList and Num(Ask(C_FriendList.GetNumFriends)) or 0
  for index = 1, count do
    local info = Ask(C_FriendList.GetFriendInfoByIndex, index)
    if type(info) == "table" and info.connected then
      list[#list + 1] = info
    end
  end
  return list
end

local function BnetOnline()
  local _, online = Ask(BNGetNumFriends)
  return Num(online) or 0
end

Add({
  id = "friends", name = "Friends", icon = "People",
  events = { "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE",
    "BN_CONNECTED", "BN_DISCONNECTED" },
  Value = function()
    local online = (C_FriendList and Num(Ask(C_FriendList.GetNumOnlineFriends)) or 0) + BnetOnline()
    return nil, tostring(online), "bright", "friends"
  end,
  Tooltip = function(tip)
    local wow = WowFriends()
    local bnet = BnetOnline()
    tip:Title("Friends", (#wow + bnet) .. " online")
    for index, info in ipairs(wow) do
      if index > 20 then
        tip:Line(("and %d more"):format(#wow - 20), nil, "muted")
        break
      end
      local level = Num(info.level)
      local area = Str(info.area)
      tip:Line(Str(info.name) or "?", (level and ("Level " .. level) or "") .. (area and (" · " .. area) or ""),
        ClassColor(Str(info.className) and I.ClassToken(info.className)) or "text", "muted")
    end
    if bnet > 0 then
      tip:Line("Battle.net friends online", tostring(bnet), "muted", "bright")
    end
    if #wow == 0 and bnet == 0 then
      tip:Line("No friends online.", nil, "muted")
    end
    tip:Note("Click to open your friends list.")
  end,
  Click = function()
    Open(ToggleFriendsFrame, 1)
  end,
})

-- Localized class name -> class token (friends list and guild roster give the name).
function I.ClassToken(name)
  for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
    if localized == name then
      return token
    end
  end
  for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
    if localized == name then
      return token
    end
  end
  return name and name:upper()
end

-- Guild ------------------------------------------------------------------------------------------------------

Add({
  id = "guild", name = "Guild", icon = "Shield",
  events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
  Value = function()
    if not Ask(IsInGuild) then
      return nil, "No guild", "muted"
    end
    local _, online = Ask(GetNumGuildMembers)
    return nil, tostring(Num(online) or 0), "bright", "guild"
  end,
  Tooltip = function(tip)
    -- fresh numbers for next time, at most every 15 s (the answer, GUILD_ROSTER_UPDATE, rebuilds this tooltip)
    local now = Num(Ask(GetTime)) or 0
    if C_GuildInfo and C_GuildInfo.GuildRoster and (not I.rosterAsked or now - I.rosterAsked > 15) then
      I.rosterAsked = now
      Ask(C_GuildInfo.GuildRoster)
    end
    if not Ask(IsInGuild) then
      tip:Title("Guild")
      tip:Line("You are not in a guild.", nil, "muted")
      return
    end
    local guildName = Str(Ask(GetGuildInfo, "player"))
    local total, online = Ask(GetNumGuildMembers)
    total, online = Num(total) or 0, Num(online) or 0
    -- a name never goes in the heading font (Cinzel and IM Fell have capitals only)
    tip:Title("Guild", ("%d of %d online"):format(online, total))
    if guildName then
      tip:Line(guildName, nil, "accent")
    end
    local shown = 0
    for index = 1, total do
      local name, _, _, level, _, zone, _, _, isOnline, _, class = Ask(GetGuildRosterInfo, index)
      if isOnline and Str(name) then
        shown = shown + 1
        if shown > 20 then
          tip:Line(("and %d more"):format(online - 20), nil, "muted")
          break
        end
        name = Ambiguate and Ambiguate(name, "guild") or name
        level = Num(level)
        tip:Line(name, (level and ("Level " .. level) or "") .. (Str(zone) and (" · " .. zone) or ""),
          ClassColor(class) or "text", "muted")
      end
    end
    tip:Note("Click to open the guild window.")
  end,
  Click = function()
    Open(ToggleGuildFrame)
  end,
})

-- Gold -------------------------------------------------------------------------------------------------------

local function MyMoney()
  return Num(Ask(GetMoney))
end

Add({
  id = "gold", name = "Gold", icon = "Coins",
  events = { "PLAYER_MONEY" },
  Value = function()
    local money = MyMoney()
    if not money then
      return nil
    end
    return nil, I.Coins(money), "bright"
  end,
  Tooltip = function(tip)
    -- every character from the Bags module's records (read only), this one with its live gold
    local bags = ns.db and ns.db.bags
    local characters = bags and type(bags.characters) == "table" and bags.characters or {}
    local hidden = bags and type(bags.hidden) == "table" and bags.hidden or {}
    local realm = ns.RealmName()
    local mine = ns.CharacterKey()
    local list, total = {}, 0
    for key, char in pairs(characters) do
      if type(char) == "table" and ns.NormalizeCharacterKey(key) ~= mine and not hidden[key] and Num(char.money) then
        list[#list + 1] = { name = ns.CharacterDisplayName(char, key), class = char.class, money = char.money,
          realm = (type(char.realm) == "string" and char.realm ~= "" and char.realm ~= realm) and char.realm or nil }
      end
    end
    local money = MyMoney() or 0
    list[#list + 1] = { name = ns.PlayerFullName(), class = select(2, UnitClass("player")), money = money }
    table.sort(list, function(a, b)
      if a.money ~= b.money then
        return a.money > b.money
      end
      return a.name < b.name
    end)
    tip:Title("Gold", realm .. " · " .. #list .. (#list == 1 and " character" or " characters"))
    for _, entry in ipairs(list) do
      total = total + entry.money
      tip:Line(entry.name .. (entry.realm and (" (" .. entry.realm .. ")") or ""), I.Coins(entry.money),
        ClassColor(entry.class) or "text", "bright")
    end
    tip:Rule()
    tip:Line("Total", I.Coins(total), "muted", "bright")
    local session = I.sessionMoney and money - I.sessionMoney or 0
    tip:Line("This session", (session < 0 and "-" or (session > 0 and "+" or "")) .. I.Coins(session), "muted",
      session < 0 and "bad" or (session > 0 and "good" or "muted"))
    -- Loot text's session (Modules/LootText): what was looted since login, its worth per hour and the best drop
    local loot = ns.loottext
    if loot and loot.running and type(loot.Session) == "function" then
      local s = loot.Session()
      tip:Line("Looted", I.Coins(s.money), "muted", "bright")
      tip:Line("Items' worth", I.Coins(s.value), "muted", "bright")
      tip:Line("Per hour", I.Coins(s.perHour), "muted", "good")
      if s.best and s.best.link then
        tip:Line("Best drop", s.best.link, "muted", "bright")
      end
    end
    tip:Note("Click to open your bags.")
  end,
  Click = function()
    if ToggleAllBags then
      ToggleAllBags()
    end
  end,
})

-- Durability -------------------------------------------------------------------------------------------------

local DURABILITY_SLOTS = {
  { 1, "HEADSLOT", "Head" }, { 3, "SHOULDERSLOT", "Shoulders" }, { 5, "CHESTSLOT", "Chest" },
  { 9, "WRISTSLOT", "Wrists" }, { 10, "HANDSSLOT", "Hands" }, { 6, "WAISTSLOT", "Waist" }, { 7, "LEGSSLOT", "Legs" },
  { 8, "FEETSLOT", "Feet" }, { 16, "MAINHANDSLOT", "Main hand" }, { 17, "SECONDARYHANDSLOT", "Off hand" },
  { 18, "RANGEDSLOT", "Ranged" },
}

-- { { slot, name, pct } }, the overall percent (all current / all maximum) and the lowest slot's percent.
function I.Durability()
  local rows, current, maximum, lowest = {}, 0, 0, nil
  for _, info in ipairs(DURABILITY_SLOTS) do
    local cur, max = Ask(GetInventoryItemDurability, info[1])
    cur, max = Num(cur), Num(max)
    if cur and max and max > 0 then
      local pct = math.floor(cur / max * 100 + 0.5)
      rows[#rows + 1] = { slot = info[1], name = Str(_G[info[2]]) or info[3], pct = pct }
      current, maximum = current + cur, maximum + max
      lowest = math.min(lowest or 100, pct)
    end
  end
  if maximum == 0 then
    return rows, nil, nil
  end
  return rows, math.floor(current / maximum * 100 + 0.5), lowest
end

-- Repair cost when the game gives it cheaply: the merchant's own number, else each slot's tooltip data.
local scanner
local function SlotRepairCost(slot)
  if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
    local data = Ask(C_TooltipInfo.GetInventoryItem, "player", slot)
    if type(data) == "table" and Num(data.repairCost) then
      return data.repairCost
    end
  end
  if not scanner then
    scanner = CreateFrame("GameTooltip", "CodexInfoBarScanTooltip", nil, "GameTooltipTemplate")
  end
  if not (scanner and scanner.SetOwner and scanner.SetInventoryItem) then
    return nil
  end
  scanner:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
  local _, _, cost = Ask(scanner.SetInventoryItem, scanner, "player", slot)
  scanner:Hide()
  return Num(cost)
end

function I.RepairCost(rows)
  if MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() and CanMerchantRepair and CanMerchantRepair() then
    local cost = Num(Ask(GetRepairAllCost))
    if cost then
      return cost
    end
  end
  local total, known = 0, false
  for _, row in ipairs(rows) do
    if row.pct < 100 then
      local cost = SlotRepairCost(row.slot)
      if cost then
        total, known = total + cost, true
      end
    end
  end
  return known and total or nil
end

Add({
  id = "durability", name = "Durability", icon = "Armor",
  events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
  Value = function()
    local _, overall, lowest = I.Durability()
    if not overall then
      return nil, "-", "muted"
    end
    -- a broken item shows red whatever the rest is
    return nil, overall .. "%", lowest == 0 and "bad" or PctColor(overall)
  end,
  Tooltip = function(tip)
    local rows, overall = I.Durability()
    tip:Title("Durability", overall and (overall .. "%") or nil, "bright")
    if #rows == 0 then
      tip:Line("Nothing equipped wears down.", nil, "muted")
      return
    end
    for _, row in ipairs(rows) do
      tip:Bar(row.name, row.pct / 100, PctColor(row.pct), row.pct .. "%")
    end
    local cost = I.RepairCost(rows)
    if cost and cost > 0 then
      tip:Rule()
      tip:Line("Repair cost", I.Coins(cost), "muted", "bright")
    end
    tip:Note("Click to open your character.")
  end,
  Click = function()
    Open(ToggleCharacter, "PaperDollFrame")
  end,
})

-- Free bag slots ---------------------------------------------------------------------------------------------

local function BagRange()
  return 0, (NUM_BAG_SLOTS or 4)
end

local function ReagentBag()
  return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
end

-- free and total slots of the general bags (profession bags, quivers and the reagent bag aside), and per bag
function I.BagSlots()
  local free, total, bags = 0, 0, {}
  local first, last = BagRange()
  local function Read(bag)
    local size = Num(Ask(C_Container.GetContainerNumSlots, bag)) or 0
    if size == 0 then
      return
    end
    local open, bagType = Ask(C_Container.GetContainerNumFreeSlots, bag)
    open, bagType = Num(open) or 0, Num(bagType) or 0
    local name = bag == 0 and (Str(BACKPACK_TOOLTIP) or "Backpack") or Str(Ask(C_Container.GetBagName, bag)) or ("Bag " .. bag)
    bags[#bags + 1] = { name = name, free = open, size = size, special = bagType ~= 0 or bag == ReagentBag() }
    if bagType == 0 and bag ~= ReagentBag() then
      free, total = free + open, total + size
    end
  end
  for bag = first, last do
    Read(bag)
  end
  if ReagentBag() and ReagentBag() > last then
    Read(ReagentBag())
  end
  return free, total, bags
end

Add({
  id = "bags", name = "Free bag slots", icon = "Bag",
  events = { "BAG_UPDATE_DELAYED" },
  Value = function()
    local free = I.BagSlots()
    return nil, tostring(free), free == 0 and "bad" or (free < 5 and "warn" or "bright"), "free"
  end,
  Tooltip = function(tip)
    local free, total, bags = I.BagSlots()
    tip:Title("Bags", ("%d of %d free"):format(free, total))
    for _, bag in ipairs(bags) do
      tip:Line(bag.name, ("%d / %d free"):format(bag.free, bag.size), bag.special and "muted" or "text", "bright")
    end
    tip:Note("Click to open your bags.")
  end,
  Click = function()
    if ToggleAllBags then
      ToggleAllBags()
    end
  end,
})

-- Ammo -------------------------------------------------------------------------------------------------------

-- The ammo slot's ID, or nil on a client without one.
local function AmmoSlot()
  if INVSLOT_AMMO then
    return INVSLOT_AMMO
  end
  local slot = Ask(GetInventorySlotInfo, "AMMOSLOT")
  return Num(slot)
end

Add({
  id = "ammo", name = "Ammo", icon = "Arrow",
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  unitEvents = { UNIT_INVENTORY_CHANGED = "player" },
  Value = function()
    local slot = AmmoSlot()
    if not slot then
      return nil -- no ammo on this client: the slot stays empty
    end
    local id = Num(Ask(GetInventoryItemID, "player", slot))
    if not id then
      return nil, "0", "muted", "ammo"
    end
    local count = Num(Ask(GetInventoryItemCount, "player", slot)) or 0
    return nil, Group(count), count < 100 and (count == 0 and "bad" or "warn") or "bright", "ammo"
  end,
  Tooltip = function(tip)
    local slot = AmmoSlot()
    local id = slot and Num(Ask(GetInventoryItemID, "player", slot))
    tip:Title("Ammo")
    if not id then
      tip:Line("No ammo in the ammo slot.", nil, "muted")
      return
    end
    local name = C_Item and Str(Ask(C_Item.GetItemNameByID, id)) or "Ammo"
    tip:Line(name, Group(Num(Ask(GetInventoryItemCount, "player", slot)) or 0), "text", "bright")
  end,
})

-- Frame rate and latency -------------------------------------------------------------------------------------

local function Latency()
  local _, _, home, world = Ask(GetNetStats)
  return Num(home) or 0, Num(world) or 0
end

Add({
  id = "fps", name = "Frame rate and latency", icon = "Signal", tick = true,
  Value = function()
    local fps = math.floor((Num(Ask(GetFramerate)) or 0) + 0.5)
    local home, world = Latency()
    local ms = math.max(home, world)
    return nil, fps .. " fps", ms < 150 and "good" or (ms < 300 and "warn" or "bad"), ms .. " ms"
  end,
  Tooltip = function(tip)
    local home, world = Latency()
    tip:Title("Performance")
    tip:Line("Frame rate", math.floor((Num(Ask(GetFramerate)) or 0) + 0.5) .. " fps", "muted", "bright")
    tip:Line("Latency (home)", home .. " ms", "muted", home < 150 and "good" or (home < 300 and "warn" or "bad"))
    tip:Line("Latency (world)", world .. " ms", "muted", world < 150 and "good" or (world < 300 and "warn" or "bad"))
  end,
})

-- Clock ------------------------------------------------------------------------------------------------------

function I.FormatTime(hour, minute)
  if I.DB().clock24 then
    return ("%02d:%02d"):format(hour, minute)
  end
  local suffix = hour < 12 and "AM" or "PM"
  hour = hour % 12
  return ("%d:%02d %s"):format(hour == 0 and 12 or hour, minute, suffix)
end

local function LocalTime()
  local now = date("*t")
  return I.FormatTime(now.hour, now.min)
end

local function RealmTime()
  local hour, minute = Ask(GetGameTime)
  hour, minute = Num(hour), Num(minute)
  return hour and minute and I.FormatTime(hour, minute) or nil
end

Add({
  id = "clock", name = "Clock", icon = "Clock", tick = true,
  Value = function()
    return nil, LocalTime(), "bright"
  end,
  Tooltip = function(tip)
    tip:Title("Clock", date("%d %B %Y"))
    tip:Line("Local time", LocalTime(), "muted", "bright")
    local realm = RealmTime()
    if realm then
      tip:Line("Realm time", realm, "muted", "bright")
    end
    tip:Note("Click to open the calendar.")
  end,
  Click = function()
    Open(ToggleCalendar)
  end,
})

-- Experience -------------------------------------------------------------------------------------------------

local function MaxLevel()
  return Num(Ask(GetMaxLevelForPlayerExpansion)) or Num(Ask(GetMaxPlayerLevel)) or Num(MAX_PLAYER_LEVEL) or 60
end

-- level, xp, max, rested (nil while no XP is gained: max level or XP switched off)
function I.Experience()
  local level = Num(Ask(UnitLevel, "player")) or 1
  if level >= MaxLevel() or Ask(IsXPUserDisabled) then
    return level
  end
  local xp, max = Num(Ask(UnitXP, "player")), Num(Ask(UnitXPMax, "player"))
  if not (xp and max) or max <= 0 then
    return level
  end
  return level, xp, max, Num(Ask(GetXPExhaustion)) or 0
end

-- XP from the completed quests in the quest log (if the game says how much), and how many.
function I.QuestXP()
  local log = C_QuestLog
  if not (log and log.GetNumQuestLogEntries and log.GetInfo and log.IsComplete and GetQuestLogRewardXP) then
    return nil
  end
  local total, count = 0, 0
  for index = 1, Num(Ask(log.GetNumQuestLogEntries)) or 0 do
    local info = Ask(log.GetInfo, index)
    local id = type(info) == "table" and not info.isHeader and Num(info.questID)
    if id and Ask(log.IsComplete, id) then
      local xp = Num(Ask(GetQuestLogRewardXP, id))
      if xp and xp > 0 then
        total, count = total + xp, count + 1
      end
    end
  end
  return total, count
end

Add({
  id = "xp", name = "Experience", icon = "Star",
  events = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" },
  Value = function()
    local level, xp, max, rested = I.Experience()
    if not xp then
      return "Level", tostring(level), "bright"
    end
    local note = rested > 0 and ("+%d%%"):format(math.floor(rested / max * 100 + 0.5)) or nil
    return "XP", Percent(xp / max * 100), "bright", note, { 0.5, 0.7, 1 }
  end,
  Tooltip = function(tip)
    local level, xp, max, rested = I.Experience()
    if not xp then
      tip:Title("Experience", "Level " .. level)
      tip:Line(level >= MaxLevel() and "You are at the highest level." or "Experience gain is switched off.", nil, "muted")
      return
    end
    local questXP, quests = I.QuestXP()
    tip:Title("Experience", ("Level %d to %d"):format(level, level + 1))
    tip:XPBar(xp / max, rested / max, (questXP or 0) / max)
    tip:Line("Earned", Group(xp) .. " / " .. Group(max), "muted", "bright", { 0.49, 0.39, 0.59 })
    tip:Line("To level", Group(max - xp), "muted", "bright", false)
    if rested > 0 then
      tip:Line("Rested", ("%s (%d%%)"):format(Group(rested), math.floor(rested / max * 100 + 0.5)), "muted",
        { 0.5, 0.7, 1 }, { 0.35, 0.59, 1 })
    end
    if questXP and quests > 0 then
      tip:Line(("Completed quests (%d)"):format(quests), Group(questXP), "muted", { 1, 0.82, 0 }, { 1, 0.82, 0 })
    end
  end,
})

-- Experience per hour (2026-11-21) -----------------------------------------------------------------------------
-- What this session earned: each look adds the XP gained since the last one (across a level up: the rest of the
-- old level plus the new XP). Per hour from the session's start (at least a minute, so the first kill doesn't
-- read as a million an hour), time to level = what is left / that rate.

I.xpSession = nil

function I.XPRate()
  local level, xp, max = I.Experience()
  local now = Num(Ask(GetTime)) or 0
  local s = I.xpSession
  if not xp then
    return { level = level, maxed = true }
  end
  if not s then
    s = { start = now, gained = 0, level = level, xp = xp, max = max }
    I.xpSession = s
  elseif level == s.level and xp >= s.xp then
    s.gained = s.gained + (xp - s.xp)
  elseif level > s.level then
    s.gained = s.gained + math.max(0, s.max - s.xp) + xp
  end
  s.level, s.xp, s.max = level, xp, max
  local hours = math.max(now - s.start, 60) / 3600
  local rate = s.gained / hours
  local left = max - xp
  return { level = level, gained = s.gained, rate = rate, left = left, seconds = now - s.start,
    toLevel = rate > 0 and left / rate * 3600 or nil }
end

-- "1 h 20 m", "12 m", "under a minute"
function I.Duration(seconds)
  seconds = math.floor((seconds or 0) + 0.5)
  if seconds < 60 then
    return "under a minute"
  end
  local hours, minutes = math.floor(seconds / 3600), math.floor(seconds / 60) % 60
  if hours > 0 then
    return minutes > 0 and ("%d h %d m"):format(hours, minutes) or ("%d h"):format(hours)
  end
  return ("%d m"):format(minutes)
end

Add({
  id = "xprate", name = "Experience per hour", icon = "Star",
  events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP" },
  Value = function()
    local r = I.XPRate()
    if r.maxed then
      return "XP/h", "max level", "muted"
    end
    if r.gained <= 0 then
      return "XP/h", "--", "muted"
    end
    return "XP/h", Group(r.rate), "bright", r.toLevel and ("level in " .. I.Duration(r.toLevel)) or nil, "muted"
  end,
  Tooltip = function(tip)
    local r = I.XPRate()
    tip:Title("Experience per hour", "Level " .. r.level)
    if r.maxed then
      tip:Line(r.level >= MaxLevel() and "You are at the highest level." or "Experience gain is switched off.", nil,
        "muted")
      return
    end
    tip:Line("This session", Group(r.gained) .. " in " .. I.Duration(r.seconds), "muted", "bright")
    tip:Line("Per hour", r.gained > 0 and Group(r.rate) or "--", "muted", "bright")
    tip:Line("To level", Group(r.left), "muted", "bright")
    tip:Line("Next level in", r.toLevel and I.Duration(r.toLevel) or "--", "muted", "good")
    tip:Note("Counted from your login (or since the bar first showed it).")
  end,
})

-- Gear set (2026-11-21) ---------------------------------------------------------------------------------------
-- Forever's character window has the game's equipment manager (Camelot PaperDollFrame.EquipmentManagerPane,
-- C_EquipmentSet in the forever API docs). This shows the set you wear; a click lists your sets to put one on
-- (out of combat: the game refuses gear changes in a fight).

function I.GearSets()
  local list = {}
  if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then
    return list
  end
  local ids = Ask(C_EquipmentSet.GetEquipmentSetIDs)
  for _, id in ipairs(type(ids) == "table" and ids or {}) do
    local name, icon, setID, isEquipped, numItems, numEquipped, _, numLost = Ask(C_EquipmentSet.GetEquipmentSetInfo, id)
    if Str(name) then
      list[#list + 1] = { id = Num(setID) or id, name = name, icon = icon, equipped = isEquipped and true or false,
        items = Num(numItems) or 0, worn = Num(numEquipped) or 0, lost = Num(numLost) or 0 }
    end
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
  return list
end

function I.WearSet(id)
  if InCombat() or not (C_EquipmentSet and C_EquipmentSet.UseEquipmentSet) then
    return false
  end
  return Ask(C_EquipmentSet.UseEquipmentSet, id) and true or false
end

Add({
  id = "gearset", name = "Gear set", icon = "Armor",
  events = { "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_FINISHED" },
  Value = function()
    local sets = I.GearSets()
    if #sets == 0 then
      return "Set", "none", "muted"
    end
    for _, set in ipairs(sets) do
      if set.equipped then
        return "Set", set.name, "bright"
      end
    end
    return "Set", "mixed", "muted"
  end,
  Tooltip = function(tip)
    local sets = I.GearSets()
    tip:Title("Gear sets")
    if #sets == 0 then
      tip:Line("No sets yet: make one in the character window's equipment manager.", nil, "muted")
      return
    end
    for _, set in ipairs(sets) do
      local state = set.equipped and "worn" or (set.lost > 0 and (set.lost .. " missing") or
        (set.worn .. " / " .. set.items))
      tip:Line(set.name, state, set.equipped and "good" or "text", set.lost > 0 and "bad" or "muted")
    end
    tip:Note(InCombat() and "Not in a fight." or "Click to put on a set.")
  end,
  Click = function()
    if InCombat() then
      return
    end
    local items = { { text = "Put on a set", title = true } }
    for _, set in ipairs(I.GearSets()) do
      items[#items + 1] = { text = set.name, checked = set.equipped, func = function()
        I.WearSet(set.id)
      end }
    end
    if #items == 1 then
      items[#items + 1] = { text = "No sets yet", disabled = true }
    end
    local anchor = GetMouseFoci and Ask(GetMouseFoci)
    anchor = type(anchor) == "table" and anchor[1] or UIParent
    ns.UI.ShowMenu(anchor, items)
  end,
})

-- Reputation -------------------------------------------------------------------------------------------------

-- name, reaction (1-8), value within the standing, the standing's size, factionID
function I.Watched()
  if C_Reputation and C_Reputation.GetWatchedFactionData then
    local data = Ask(C_Reputation.GetWatchedFactionData)
    if type(data) == "table" and Str(data.name) then
      local low, high, value = Num(data.currentReactionThreshold), Num(data.nextReactionThreshold), Num(data.currentStanding)
      if low and high and value then
        return data.name, Num(data.reaction), value - low, high - low, Num(data.factionID)
      end
    end
  end
  local name, reaction, low, high, value, id = Ask(GetWatchedFactionInfo)
  low, high, value = Num(low), Num(high), Num(value)
  if Str(name) and low and high and value then
    return name, Num(reaction), value - low, high - low, Num(id)
  end
end

local function Standing(reaction)
  return reaction and Str(_G["FACTION_STANDING_LABEL" .. reaction]) or "?"
end

local function ReactionColor(reaction)
  local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
  if color then
    return { color.r, color.g, color.b }
  end
  return reaction and reaction >= 5 and "good" or (reaction == 4 and "warn" or "bad")
end

Add({
  id = "rep", name = "Reputation", icon = "Flag",
  events = { "UPDATE_FACTION" },
  Value = function()
    local name, reaction, value, size = I.Watched()
    if not name then
      return nil, "No reputation watched", "muted"
    end
    local note = size > 0 and (Group(value) .. " / " .. Group(size)) or nil
    return name, Standing(reaction), ReactionColor(reaction), note
  end,
  Tooltip = function(tip)
    local name, reaction, value, size = I.Watched()
    tip:Title("Reputation")
    if not name then
      tip:Line("No faction is watched. Pick one in your reputation list.", nil, "muted")
    else
      tip:Line(name, Standing(reaction), "bright", ReactionColor(reaction))
      if size > 0 then
        tip:Bar("Progress", value / size, ReactionColor(reaction), math.floor(value / size * 100) .. "%")
        tip:Line("Points", Group(value) .. " / " .. Group(size), "muted", "bright")
      end
    end
    tip:Note("Click to open your reputation.")
  end,
  Click = function()
    Open(ToggleCharacter, "ReputationFrame")
  end,
})

-- Professions ------------------------------------------------------------------------------------------------

-- { { name, rank, max } }: primary professions first, then the secondary ones.
function I.Professions()
  local list = {}
  if GetProfessions and GetProfessionInfo then
    local indices = { Ask(GetProfessions) }
    for slot = 1, 5 do
      local index = Num(indices[slot])
      if index then
        local name, _, rank, max = Ask(GetProfessionInfo, index)
        if Str(name) and Num(rank) then
          list[#list + 1] = { name = name, rank = rank, max = Num(max) }
        end
      end
    end
    if #list > 0 then
      return list
    end
  end
  -- skill lines: the entries under the professions and secondary skills headers
  local primary = Str(TRADE_SKILLS) or "Professions"
  local secondary = Str(SECONDARY_SKILLS) or "Secondary Skills"
  local header
  for index = 1, Num(Ask(GetNumSkillLines)) or 0 do
    local name, isHeader, _, rank, _, _, max = Ask(GetSkillLineInfo, index)
    if isHeader then
      header = Str(name)
    elseif Str(name) and Num(rank) and (header == primary or header == secondary) then
      list[#list + 1] = { name = name, rank = rank, max = Num(max) }
    end
  end
  return list
end

Add({
  id = "prof", name = "Professions", icon = "Hammer",
  events = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" },
  Value = function()
    local list = I.Professions()
    if #list == 0 then
      return nil, "No professions", "muted"
    end
    -- the second one's name muted like the first's, its rank in the same bright colour as the first rank
    local second = list[2] and (list[2].name .. " " .. I.Hex("bright") .. list[2].rank .. "|r") or nil
    return list[1].name, tostring(list[1].rank), "bright", second
  end,
  Tooltip = function(tip)
    local list = I.Professions()
    tip:Title("Professions")
    if #list == 0 then
      tip:Line("You have no professions yet.", nil, "muted")
    end
    for _, prof in ipairs(list) do
      tip:Line(prof.name, prof.max and (prof.rank .. " / " .. prof.max) or tostring(prof.rank), "text", "bright")
    end
  end,
})

-- Location ---------------------------------------------------------------------------------------------------

-- x, y in percent, or nil (instances and some zones have no position)
function I.Coordinates()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
    return nil
  end
  local map = Num(Ask(C_Map.GetBestMapForUnit, "player"))
  if not map then
    return nil
  end
  local position = Ask(C_Map.GetPlayerMapPosition, map, "player")
  if type(position) ~= "table" and type(position) ~= "userdata" then
    return nil
  end
  local x, y = Ask(position.GetXY, position)
  x, y = Num(x), Num(y)
  if not x or not y or (x == 0 and y == 0) then
    return nil
  end
  return x * 100, y * 100
end

local ZONE_COLORS = { sanctuary = { 0.41, 0.8, 0.94 }, friendly = { 0.1, 1, 0.1 }, hostile = { 1, 0.1, 0.1 },
  contested = { 1, 0.7, 0 }, combat = { 1, 0.1, 0.1 }, arena = { 1, 0.1, 0.1 } }

local function ZoneColor()
  local kind = Str(Ask(GetZonePVPInfo))
  return kind and ZONE_COLORS[kind] or "accent"
end

Add({
  id = "zone", name = "Location", icon = "Pin", tick = true,
  events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
  Value = function()
    local zone = Str(Ask(GetRealZoneText)) or Str(Ask(GetZoneText)) or "?"
    local sub = Str(Ask(GetSubZoneText))
    local x, y = I.Coordinates()
    local note = {}
    if sub and sub ~= zone then
      note[#note + 1] = sub
    end
    if x then
      note[#note + 1] = ("%.1f, %.1f"):format(x, y)
    end
    return nil, zone, ZoneColor(), #note > 0 and ("· " .. table.concat(note, " · ")) or nil
  end,
  Tooltip = function(tip)
    local zone = Str(Ask(GetRealZoneText)) or Str(Ask(GetZoneText)) or "?"
    local sub = Str(Ask(GetSubZoneText))
    local _, _, faction = Ask(GetZonePVPInfo)
    tip:Title("Location")
    tip:Line(zone, Str(faction), ZoneColor(), "muted")
    if sub and sub ~= zone then
      tip:Line(sub, nil, "text")
    end
    local x, y = I.Coordinates()
    tip:Line("Coordinates", x and ("%.1f, %.1f"):format(x, y) or "none here", "muted", "bright")
    tip:Note("Click to open the map.")
  end,
  Click = function()
    Open(ToggleWorldMap)
  end,
})

-- Nothing: the slot stays empty (the panel keeps the space, the screen bar closes the gap).
I.NOTHING = { id = "none", name = "Nothing" }

function I.Text(id)
  return I.TEXTS[id]
end

-- Board order for the slot menu.
I.MENU_ORDER = { "friends", "guild", "gold", "durability", "bags", "ammo", "fps", "clock", "xp", "rep", "prof", "zone" }
