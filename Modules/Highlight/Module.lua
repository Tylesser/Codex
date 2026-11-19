local addonName, ns = ...

-- Highlights (off by default): marks the things worth walking to. Settings in CodexDB.highlight, each part
-- with its own switch (all on when the module is turned on):
--   nodes        herbs and ore get a pulsing ring and their name (herb green, ore orange)
--   chests       treasure chests (gold)          fish   fishing pools (blue)
--   questPlates  quest objects get a yellow ring and "!", quest mobs a "!" over their nameplate
--   questBags    quest items in the bags (Codex's window and Blizzard's) glow; quest starters get a "!"
--   ownOnly      herbs only with Herbalism, ore only with Mining
-- Objects have no nameplate of their own: the game shows one for the object you would interact with (the
-- "soft target", the nearest within range). The marks sit on that plate, so while an object part is on these
-- CVars are set, and the player's own values are kept in CodexDB.highlight.saved and put back when the parts
-- (or the module) are switched off. NodeSight does the same job: while it is loaded Codex leaves it to it.

local H = {}
ns.highlight = H

local DEFAULTS = {
  nodes = true,
  chests = true,
  fish = true,
  questPlates = true,
  questBags = true,
  ownOnly = false,
  names = true,
  size = 1,
  range = 15,
}

H.SIZES = { { value = 0.8, text = "Small" }, { value = 1, text = "Normal" }, { value = 1.3, text = "Large" } }
H.RANGES = { 10, 15, 20, 25, 30 }

-- Values that can be secret on Forever are only used when readable.
function H.Readable(value)
  if canaccessvalue then
    return canaccessvalue(value) and true or false
  end
  if issecretvalue then
    return not issecretvalue(value)
  end
  return true
end

-- fn(...) caught; its first result only when it is readable.
function H.Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if ok and H.Readable(value) then
    return value
  end
  return nil
end

function H.DB()
  if not H.db then
    ns.db.highlight = ns.Fill(ns.db.highlight or {}, DEFAULTS)
    H.db = ns.db.highlight
  end
  return H.db
end

-- An object part is on: the soft-target plates are needed.
function H.NeedsObjects()
  local db = H.DB()
  return db.nodes or db.chests or db.fish or db.questPlates or false
end

-- CVars -------------------------------------------------------------------------------------------------

local function GetCVarValue(name)
  local get = (C_CVar and C_CVar.GetCVar) or GetCVar
  local value = H.Ask(get, name)
  return type(value) == "string" and value or nil
end

local function SetCVarValue(name, value)
  local set = (C_CVar and C_CVar.SetCVar) or SetCVar
  if type(set) == "function" then
    pcall(set, name, value)
  end
end

-- What the module wants: interact soft targeting always on, all round you, within the chosen range, with
-- the object's nameplate and the game's own interact icon.
function H.CVarValues()
  return {
    SoftTargetInteract = "3",
    SoftTargetInteractArc = "2",
    SoftTargetInteractRange = tostring(H.DB().range or DEFAULTS.range),
    SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1",
  }
end

function H.WantCVars()
  return H.running and ns.ModuleOn("highlight") and H.NeedsObjects() and true or false
end

local regen
local function Later()
  if not regen then
    regen = CreateFrame("Frame")
    regen:SetScript("OnEvent", function(self)
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      H.ApplyCVars()
    end)
  end
  regen:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Sets our values (keeping the player's first) or puts the player's back. Never in combat: then after it.
function H.ApplyCVars()
  local db = ns.db and ns.db.highlight
  if type(db) ~= "table" then
    return
  end
  local want = H.WantCVars()
  if not want and not db.saved then
    return
  end
  if InCombatLockdown() then
    Later()
    return
  end
  if want then
    local values = H.CVarValues()
    if not db.saved then
      local saved = {}
      for name in pairs(values) do
        saved[name] = GetCVarValue(name) or false -- false: the client has no such CVar
      end
      db.saved = saved
    end
    for name, value in pairs(values) do
      if db.saved[name] ~= false and GetCVarValue(name) ~= value then
        SetCVarValue(name, value)
      end
    end
  else
    for name, value in pairs(db.saved) do
      if type(value) == "string" then
        SetCVarValue(name, value)
      end
    end
    db.saved = nil
  end
end

-- The module switched off (or on again) in Settings: the CVars follow at once, before the reload. Codex's own
-- event bus only (no game events while the module is off).
ns.On("RELOAD_STATE", function()
  local db = ns.db and ns.db.highlight
  if type(db) == "table" and (H.running or db.saved) then
    H.ApplyCVars()
  end
end)

-- Switches ------------------------------------------------------------------------------------------------

function H.Set(key, value)
  H.DB()[key] = value
  if key == "ownOnly" then
    H.knows = nil
  end
  H.ApplyCVars()
  if H.RefreshPlates then
    H.RefreshPlates()
  end
  if H.RefreshBags then
    H.RefreshBags()
  end
  if H.RefreshPage then
    H.RefreshPage()
  end
end

local PARTS = { "nodes", "chests", "fish", "questPlates", "questBags" }

function H.StatusText()
  if not H.running then
    return "Off."
  end
  local on = 0
  for _, key in ipairs(PARTS) do
    if H.DB()[key] then
      on = on + 1
    end
  end
  return ("%d of %d highlights on."):format(on, #PARTS)
end

function H.Enable()
  H.DB()
  H.running = true
  H.EnablePlates()
  H.EnableBags()
  H.ApplyCVars()
end

ns.RegisterModule({
  id = "highlight",
  name = "Highlights",
  -- its section in the Codex window (Areas.lua)
  area = "map", sectionOrder = 60, sectionTitle = "Highlights", folded = true, pageEstimate = 400,
  icon = "Interface\\Icons\\INV_Misc_Herb_07",
  desc = "Rings on herbs, ore, chests and quest objects near you, \"!\" on quest mobs, glowing quest items in your bags.",
  standalone = "NodeSight",
  standaloneName = "NodeSight",
  default = false,
  order = 98,
  Enable = function()
    H.Enable()
  end,
  BuildPage = function(_, page)
    H.BuildPage(page)
  end,
  ShowPage = function()
    if H.RefreshPage then
      H.RefreshPage()
    end
  end,
  Status = function()
    return H.StatusText()
  end,
})
