local addonName, ns = ...
local L = ns.L

-- Codex core: saved data, the module registry and small shared helpers. Every feature is a module that
-- registers itself here; a module that is switched off (or left to its standalone addon) never runs its
-- Enable, so it adds no hooks, events or frames.

ns.TITLE = "Tylesser - Codex"
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(addonName, "Version") or "dev"
if ns.VERSION:find("@") then
  ns.VERSION = "dev"
end
ns.PREFIX = ns.T.Prefix("Codex")

-- The one global Codex exposes: the API its load-on-demand folders (themes, game UI skins) talk to.
local API = {}
TylesserCodex = API
ns.API = API
-- The translations (Tylesser.lua's ns.L) for the load-on-demand folders, which have their own namespace: Codex_Skins
-- and the themes read TylesserCodex.L (2026-11-27).
API.L = ns.L

local DEFAULTS = {
  theme = "runestone",
  modules = {}, -- [id] = false when switched off; nil means the module's default
  minimap = { angle = 225, hide = false },
  skins = { enabled = false, parts = {} }, -- game UI restyling (Codex_Skins); parts[id] = false to skip one
  scale = 1,
  fonts = { head = "theme", body = "theme" }, -- font choices (ns.FONTS keys); "theme" = the theme's own
}

local CHAR_DEFAULTS = {}

local function Fill(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = {}
        Fill(target[key], value)
      else
        target[key] = value
      end
    elseif type(value) == "table" and type(target[key]) == "table" then
      Fill(target[key], value)
    end
  end
  return target
end
ns.Fill = Fill

function ns.SetupDB()
  CodexDB = Fill(CodexDB or {}, DEFAULTS)
  CodexCharDB = Fill(CodexCharDB or {}, CHAR_DEFAULTS)
  ns.db = CodexDB
  ns.char = CodexCharDB
  -- the Dawn theme was removed (the user's request, 2026-11-20): its players get Dusk, its dark counterpart
  if CodexDB.theme == "dawn" then
    CodexDB.theme = "dusk"
  end
end

function ns.Say(text)
  print(ns.PREFIX .. text)
end

-- Characters ---------------------------------------------------------------------------------------------------
-- Forever has surnames: UnitName("player") gave "Tylesser" in one session and "Tylesser Valerius" in another, so
-- the same character got two records (the user's money tooltip, 2026-11-21). A character is its realm and its own
-- name: the first word of the name, never the surname.

-- The player's own name, without a surname.
function ns.PlayerName()
  local ok, name = pcall(UnitName, "player")
  if not ok or type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then
    return "?"
  end
  return name:match("^[^%s]+") or name
end

-- The realm's name. Forever's GetRealmName() returned "" for a whole session (2026-11-21: the character got a second
-- record "-Tylesser" and the old one showed its realm as another realm's), so an empty answer falls back to the last
-- realm seen (`CodexDB.lastRealm`, else the realm of the newest character record), never to "".
local function Plain(text)
  if type(text) ~= "string" or text == "" or text == "?" or (issecretvalue and issecretvalue(text)) then
    return nil
  end
  return text
end

function ns.RealmName()
  local ok, realm = pcall(GetRealmName)
  realm = ok and Plain(realm) or nil
  local db = ns.db
  if realm then
    if db then
      db.lastRealm = realm
    end
    return realm
  end
  if db and Plain(db.lastRealm) then
    return db.lastRealm
  end
  -- the newest record that knows its realm
  local best, when
  local characters = db and type(db.bags) == "table" and type(db.bags.characters) == "table" and db.bags.characters or {}
  for _, record in pairs(characters) do
    if type(record) == "table" and Plain(record.realm) and (tonumber(record.updated) or 0) > (when or -1) then
      best, when = record.realm, tonumber(record.updated) or 0
    end
  end
  if best and db then
    db.lastRealm = best -- kept for the session: the merge below may empty the records' own realm fields
  end
  return best or "?"
end

-- The player's full name for display: Forever's UnitName returns the name and the surname as two values
-- ("Tylesser", "Valerius"; print shows them with a space, which first looked like one value: the user's checks,
-- 2026-11-21), joined with the game's separator as Codex's unit frames do (Skins/UnitFrames.lua FullName).
-- Keys use ns.PlayerName (the first value).
function ns.PlayerFullName()
  local ok, name, surname = pcall(UnitName, "player")
  local function Text(value)
    return type(value) == "string" and value ~= "" and not (issecretvalue and issecretvalue(value)) and value or nil
  end
  name, surname = ok and Text(name) or nil, ok and Text(surname) or nil
  if not name then
    return ns.PlayerName()
  end
  if surname then
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local separator = consts and type(consts.CHARACTERNAME_SURNAME_SEPARATOR) == "string"
      and consts.CHARACTERNAME_SURNAME_SEPARATOR or " "
    return name .. separator .. surname
  end
  return name
end

-- Stores the full name on a character record: a name with the surname is kept once seen (the game may give the
-- name without it early in a session; the user's tooltip showed "Tylesser" right after a reload, 2026-11-21).
function ns.StoreFullName(record)
  if type(record) ~= "table" then
    return
  end
  local full = ns.PlayerFullName()
  if full:find(" ", 1, true) or type(record.fullName) ~= "string" or record.fullName == "" then
    record.fullName = full
  end
end

-- A stored character's name to show: its full name when known, else its name, else the key's name part.
function ns.CharacterDisplayName(record, key)
  if type(record) == "table" then
    if type(record.fullName) == "string" and record.fullName ~= "" then
      return record.fullName
    end
    if type(record.name) == "string" and record.name ~= "" then
      return record.name
    end
  end
  return type(key) == "string" and (key:match("%-(.+)$") or key) or "?"
end

-- "Realm-Name" for any key or name: a surname after the first space is dropped, and an empty or unknown realm
-- ("-Name", "?-Name") is this realm.
function ns.NormalizeCharacterKey(key)
  if type(key) ~= "string" then
    return key
  end
  local realm, name = key:match("^(.*)%-(.-)$")
  if not realm then
    return key
  end
  if realm == "" or realm == "?" then
    realm = ns.RealmName()
  end
  return realm .. "-" .. (name:match("^[^%s]+") or name)
end

-- This character's key.
function ns.CharacterKey()
  return ns.RealmName() .. "-" .. ns.PlayerName()
end

-- One record per character in a table keyed "Realm-Name": every other key with the same realm and first name is
-- merged into `key` (the newer record by `updated` is kept whole; fields it lacks come from the older one) and
-- removed. `also` = more tables keyed the same way (hidden flags) whose entries move with it. Returns how many
-- records were merged in.
function ns.MergeCharacterRecords(records, key, also)
  if type(records) ~= "table" then
    return 0
  end
  local merged = 0
  -- (the keys first: a table may not get new keys while pairs walks it)
  local others = {}
  for other, record in pairs(records) do
    if other ~= key and type(record) == "table" and ns.NormalizeCharacterKey(other) == key then
      others[#others + 1] = other
    end
  end
  for _, other in ipairs(others) do
    local record = records[other]
    do
      local mine = records[key]
      if type(mine) ~= "table" then
        records[key] = record
      else
        local newer, older = mine, record
        if (tonumber(record.updated) or 0) > (tonumber(mine.updated) or 0) then
          newer, older = record, mine
        end
        for field, value in pairs(older) do
          -- (an empty string counts as missing: the newer record may have been made with an empty realm)
          if newer[field] == nil or (newer[field] == "" and value ~= "") then
            newer[field] = value
          end
        end
        records[key] = newer
      end
      records[other] = nil
      for _, map in ipairs(also or {}) do
        if type(map) == "table" and map[other] ~= nil then
          if map[key] == nil then
            map[key] = map[other]
          end
          map[other] = nil
        end
      end
      merged = merged + 1
    end
  end
  return merged
end

function ns.IsAddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded(name)
  end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

-- Loads a load-on-demand folder that ships with Codex. Returns true when it is loaded.
function ns.LoadAddOn(name)
  if ns.IsAddOnLoaded(name) then
    return true
  end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  if not load then
    return false
  end
  local ok, loaded, reason = pcall(load, name)
  if not ok or not loaded then
    ns.loadErrors = ns.loadErrors or {}
    ns.loadErrors[name] = (not ok and tostring(loaded)) or reason or "not loaded"
    return false
  end
  return true
end

-- Modules -----------------------------------------------------------------------------------------------
-- ns.RegisterModule({
--   id = "buffs", name = "Buffs", icon = <texture>, desc = "One line for Home and Settings.",
--   standalone = "BuffTracker",   -- optional: while that addon is loaded, Codex leaves the feature to it
--   default = true,               -- on for new players (default true)
--   order = 10,                   -- sidebar order
--   Enable = function() end,      -- once, at login, when the module is on
--   BuildPage = function(page) end, -- once, the first time its page is shown (page is a frame)
--   ShowPage = function(page) end,  -- optional: every time its page is shown
--   Status = function() return "text" end, -- optional: a short live line on Home
-- })

ns.modules = {}
ns.moduleList = {}

function ns.RegisterModule(module)
  assert(module.id and not ns.modules[module.id], "Codex: module needs a unique id")
  module.order = module.order or 100
  if module.default == nil then
    module.default = true
  end
  ns.modules[module.id] = module
  table.insert(ns.moduleList, module)
  table.sort(ns.moduleList, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)
  return module
end

-- "on", "off" or "standalone" (the module's own addon is loaded, so Codex leaves the feature to it).
function ns.ModuleState(id)
  local module = ns.modules[id]
  if not module then
    return "off"
  end
  local wanted = ns.db and ns.db.modules[id]
  if wanted == nil then
    wanted = module.default
  end
  if not wanted then
    return "off"
  end
  if module.standalone and ns.IsAddOnLoaded(module.standalone) and not (ns.db and ns.db.modules[id .. ":force"]) then
    return "standalone"
  end
  return "on"
end

function ns.ModuleOn(id)
  return ns.ModuleState(id) == "on"
end

-- Switching takes effect after a reload: a running module can't take its hooks back.
ns.pendingReload = false

function ns.SetModuleWanted(id, on)
  ns.db.modules[id] = on and true or false
  local module = ns.modules[id]
  if module and on ~= (module.running or false) then
    ns.pendingReload = true
  end
  ns.Fire("RELOAD_STATE")
end

-- Use Codex's copy of a feature even though its standalone addon is installed.
function ns.ForceModule(id)
  ns.db.modules[id] = true
  ns.db.modules[id .. ":force"] = true
  ns.pendingReload = true
  ns.Fire("RELOAD_STATE")
end

function ns.EnableModules()
  for _, module in ipairs(ns.moduleList) do
    if ns.ModuleOn(module.id) and module.Enable then
      local ok, err = pcall(module.Enable, module)
      if ok then
        module.running = true
      else
        module.error = err
        geterrorhandler()(err)
      end
    elseif ns.ModuleOn(module.id) then
      module.running = true
    end
  end
end

-- Tiny event bus between Codex files ("RELOAD_STATE", "PRICES_UPDATED", ...).
local listeners = {}
function ns.On(event, callback)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], callback)
end
function ns.Fire(event, ...)
  for _, callback in ipairs(listeners[event] or {}) do
    local ok, err = pcall(callback, ...)
    if not ok then
      geterrorhandler()(err)
    end
  end
end

-- "12g 34s 5c" with the game's coin colours; nil gives "".
function ns.Money(copper)
  if not copper then
    return ""
  end
  copper = math.floor(copper + 0.5)
  local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  -- a theme with a money colour (Dusk, Dawn) writes the whole amount in it; else the game's coin colours
  local hex = type(ns.MoneyHex) == "function" and ns.MoneyHex() or nil
  if gold > 0 then
    parts[#parts + 1] = ("|cff%s%sg|r"):format(hex or "ffd100", BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or gold)
  end
  if silver > 0 then
    parts[#parts + 1] = ("|cff%s%ds|r"):format(hex or "c7c7cf", silver)
  end
  if rest > 0 or #parts == 0 then
    parts[#parts + 1] = ("|cff%s%dc|r"):format(hex or "eda55f", rest)
  end
  return table.concat(parts, " ")
end

-- "3m", "2h", "5d" since a time() stamp.
function ns.Age(stamp)
  if not stamp then
    return L["never"]
  end
  local seconds = math.max(0, time() - stamp)
  if seconds < 3600 then
    return L["%dm"]:format(math.max(1, math.floor(seconds / 60)))
  elseif seconds < 86400 then
    return L["%dh"]:format(math.floor(seconds / 3600))
  end
  return L["%dd"]:format(math.floor(seconds / 86400))
end
