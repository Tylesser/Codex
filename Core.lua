local addonName, ns = ...

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
    return "never"
  end
  local seconds = math.max(0, time() - stamp)
  if seconds < 3600 then
    return math.max(1, math.floor(seconds / 60)) .. "m"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h"
  end
  return math.floor(seconds / 86400) .. "d"
end
