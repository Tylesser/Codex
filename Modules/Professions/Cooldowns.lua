local addonName, ns = ...
local L = ns.L

-- Professions module, part 2b (2026-11-28, ported from Profit Sort's Cooldowns.lua): crafting cooldowns
-- (transmutes and the like) of all your characters. The profession window tells Codex about a recipe's cooldown
-- while it runs (provider.Cooldowns(), Providers.lua), so a recipe shows up here once you have used it with its
-- profession window open. Kept account-wide in CodexDB.professions.cooldowns["Realm-Name"] with the time it is
-- ready again (time(), so it holds across sessions and characters). Shown on the module page, the profit list's
-- clock button and /codex cooldowns; a chat line tells you when one of this character's cooldowns is ready.
-- Nothing here creates frames or registers events.

local P = ns.professions

local function Plain(text)
  if type(text) ~= "string" or text == "" or (issecretvalue and issecretvalue(text)) then
    return nil
  end
  return text
end

local function Number(value)
  if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then
    return nil
  end
  return value
end

local function Store()
  local db = P.DB()
  db.cooldowns = db.cooldowns or {}
  return db.cooldowns
end

local function Me()
  local key = ns.CharacterKey()
  local store = Store()
  local me = store[key]
  if not me then
    me = { recipes = {} }
    store[key] = me
  end
  me.recipes = me.recipes or {}
  me.name = ns.PlayerName()
  ns.StoreFullName(me)
  me.class = select(2, UnitClass("player"))
  return me, key
end

-- Remembers the cooldowns one profession window shows. list = provider.Cooldowns(): { { name, icon, cooldown
-- (seconds left or nil), charges, maxCharges } } for the recipes the window lists. A recipe on cooldown (or with
-- charges) is stored with the time it is ready; a stored recipe the window lists without one is ready now.
function P.RememberCooldowns(list, prof)
  if type(list) ~= "table" or not P.DB() then
    return 0
  end
  local me = Me()
  local now = time()
  local stored = 0
  for _, item in ipairs(list) do
    local name = Plain(item.name)
    if name then
      local left = Number(item.cooldown)
      local charges, maxCharges = Number(item.charges), Number(item.maxCharges)
      local record = me.recipes[name]
      if (left and left > 0) or (maxCharges and maxCharges > 0) then
        local readyAt = now
        if not (charges and charges > 0) then
          readyAt = now + math.floor(left or 0)
        end
        if readyAt <= now and record and record.readyAt and record.readyAt <= now then
          readyAt = record.readyAt -- still ready (charges left): it stays told
        end
        record = record or {}
        -- a new cooldown (used again): tell again once it is over
        if not record.readyAt or math.abs(record.readyAt - readyAt) > 120 then
          record.told = nil
        end
        record.readyAt, record.prof, record.icon = readyAt, prof or record.prof, item.icon or record.icon
        record.charges, record.maxCharges = charges, maxCharges
        me.recipes[name] = record
        stored = stored + 1
      elseif record and record.readyAt and record.readyAt > now then
        record.readyAt = now -- the window shows no cooldown any more (a day cooldown ends at midnight)
      end
    end
  end
  if stored > 0 then
    P.ScheduleCooldownNote()
  end
  return stored
end

-- From the open window (your own only).
function P.RecordCooldowns(provider)
  provider = provider or P.active
  if not (provider and provider.Cooldowns and provider.IsOwn and provider.IsOwn()) then
    return 0
  end
  local ok, list = pcall(provider.Cooldowns)
  if not ok then
    return 0
  end
  return P.RememberCooldowns(list, provider.GetTitle())
end

-- "3 hr 12 min" in the client's language (the game's SecondsToTime), else "3h 12m".
function P.CooldownTime(seconds)
  seconds = math.max(0, math.floor(seconds))
  if SecondsToTime then
    local ok, text = pcall(SecondsToTime, seconds, true, false, 2)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
  if days > 0 then
    return ("%dd %dh"):format(days, hours)
  elseif hours > 0 then
    return ("%dh %dm"):format(hours, minutes)
  end
  return ("%dm"):format(math.max(1, minutes))
end

-- One character's cooldowns as groups: recipes of one profession ready at the same time (Classic's transmutes
-- share one cooldown) are one group. { { names, readyAt, prof, icon, records }, ... } ready first, then soonest.
local function Groups(char)
  local byTime, groups = {}, {}
  for name, record in pairs(char.recipes or {}) do
    if type(record) == "table" and record.readyAt then
      local key = (record.prof or "") .. ":" .. math.floor(record.readyAt / 60)
      local group = byTime[key]
      if not group then
        group = { names = {}, readyAt = record.readyAt, prof = record.prof, icon = record.icon, records = {} }
        byTime[key] = group
        groups[#groups + 1] = group
      end
      group.names[#group.names + 1] = name
      group.records[#group.records + 1] = record
    end
  end
  for _, group in ipairs(groups) do
    table.sort(group.names)
  end
  table.sort(groups, function(a, b)
    if a.readyAt ~= b.readyAt then
      return a.readyAt < b.readyAt
    end
    return a.names[1] < b.names[1]
  end)
  return groups
end
P.CooldownGroups = Groups

-- "Transmute: Arcanite Bar" or "Transmute: Arcanite Bar (+6)" for a group.
local function GroupName(group)
  if #group.names > 1 then
    return L["%s (+%d)"]:format(group.names[1], #group.names - 1)
  end
  return group.names[1]
end

-- { { key, name, class, mine, groups }, ... }: this character first, then by key; characters without
-- cooldowns are left out.
function P.CooldownCharacters()
  local mine = ns.CharacterKey()
  local list = {}
  for key, char in pairs(Store()) do
    if type(char) == "table" then
      local groups = Groups(char)
      if #groups > 0 then
        list[#list + 1] = { key = key, name = ns.CharacterDisplayName(char, key), class = char.class,
          mine = key == mine, groups = groups }
      end
    end
  end
  table.sort(list, function(a, b)
    if a.mine ~= b.mine then
      return a.mine
    end
    return a.key < b.key
  end)
  return list
end

-- { left, right, ready } per line (a heading line per character has right = nil and its class).
function P.CooldownLines()
  local now = time()
  local lines = {}
  for _, char in ipairs(P.CooldownCharacters()) do
    lines[#lines + 1] = { char.name, nil, nil, class = char.class }
    for _, group in ipairs(char.groups) do
      local ready = group.readyAt <= now
      lines[#lines + 1] = { "  " .. GroupName(group), ready and L["Ready"] or P.CooldownTime(group.readyAt - now), ready }
    end
  end
  return lines
end

local function ClassColor(class)
  local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
  local color = class and colors and colors[class]
  if color then
    return color.r, color.g, color.b
  end
  return 1, 0.82, 0
end

P.COOLDOWN_HINT = L["A recipe with a cooldown (such as a transmute) shows up here after you use it with its profession window open."]

-- Fills a tooltip with the list (the profit list's clock button).
function P.AddCooldownLines(tooltip)
  local lines = P.CooldownLines()
  if #lines == 0 then
    tooltip:AddLine(L["No crafting cooldowns yet."], 1, 1, 1, true)
    tooltip:AddLine(P.COOLDOWN_HINT, 0.6, 0.6, 0.6, true)
    return
  end
  for _, line in ipairs(lines) do
    if line[2] == nil then
      tooltip:AddLine(line[1], ClassColor(line.class))
    elseif line[3] then
      tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 0.25, 1, 0.25)
    else
      tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
    end
  end
end

-- The list as one text (the module page).
function P.CooldownText()
  local lines = P.CooldownLines()
  if #lines == 0 then
    return "|cff999999" .. L["No crafting cooldowns yet."] .. " " .. P.COOLDOWN_HINT .. "|r"
  end
  local out = {}
  for _, line in ipairs(lines) do
    if line[2] == nil then
      out[#out + 1] = line[1]
    else
      out[#out + 1] = line[1] .. ": " .. (line[3] and ("|cff40ff40" .. line[2] .. "|r") or line[2])
    end
  end
  return table.concat(out, "\n")
end

-- How many cooldown groups of this character are ready.
function P.ReadyCooldowns()
  local me = Store()[ns.CharacterKey()]
  local now, count = time(), 0
  for _, group in ipairs(me and Groups(me) or {}) do
    if group.readyAt <= now then
      count = count + 1
    end
  end
  return count
end

-- /codex cooldowns
function P.PrintCooldowns()
  local lines = P.CooldownLines()
  if #lines == 0 then
    ns.Say(L["No crafting cooldowns yet."] .. " " .. P.COOLDOWN_HINT)
    return
  end
  ns.Say(L["Crafting cooldowns:"])
  for _, line in ipairs(lines) do
    if line[2] == nil then
      print(line[1])
    else
      print(line[1] .. ": " .. (line[3] and ("|cff40ff40" .. line[2] .. "|r") or line[2]))
    end
  end
end

-- The chat line: this character's cooldowns that are ready and not told yet. Each is told once per cooldown.
-- Returns how many were told.
function P.CooldownNote()
  local db = P.DB()
  if not (db and db.cooldownNote) then
    return 0
  end
  local me = Store()[ns.CharacterKey()]
  if not me then
    return 0
  end
  local now = time()
  local names = {}
  for _, group in ipairs(Groups(me)) do
    if group.readyAt <= now then
      local new = false
      for _, record in ipairs(group.records) do
        if not record.told then
          new = true
          record.told = true
        end
      end
      if new then
        names[#names + 1] = GroupName(group)
      end
    end
  end
  if #names > 0 then
    ns.Say(L["crafting cooldown ready: %s."]:format(table.concat(names, ", ")))
  end
  return #names
end

-- Tells now what is ready, and again when this character's next cooldown is over (within this session).
local noteToken = 0
function P.ScheduleCooldownNote()
  noteToken = noteToken + 1
  local token = noteToken
  P.CooldownNote()
  local me = Store()[ns.CharacterKey()]
  local now, soonest = time(), nil
  for _, record in pairs(me and me.recipes or {}) do
    if type(record) == "table" and record.readyAt and record.readyAt > now and not record.told then
      soonest = math.min(soonest or math.huge, record.readyAt)
    end
  end
  if soonest and C_Timer and soonest - now < 2 * 86400 then
    C_Timer.After(soonest - now + 2, function()
      if token == noteToken and P.running then
        P.ScheduleCooldownNote()
      end
    end)
  end
end
