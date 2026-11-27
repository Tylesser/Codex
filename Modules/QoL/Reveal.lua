local addonName, ns = ...
local L = ns.L

-- Reveal unexplored areas on the map: a zone map shows the art of the parts you haven't explored yet too, so the
-- whole zone is drawn instead of dark gaps. With "Tint unexplored areas" (on by default) those parts are drawn a
-- little darker, greyer and cooler, so you can still see where you haven't been; off, they look like the rest.
--
-- How: the game's MapExplorationDataProvider (Blizzard_SharedMapDataProviders) draws only the pieces
-- C_MapExplorationInfo.GetExploredMapTextures(mapID) returns. The full list of pieces per map art is not in the
-- API, so it comes from the game's own DB2 tables (RevealData.lua, ns.MAP_REVEAL by UiMapArtID, made by
-- tools/data/map_reveal.py). Codex adds a data provider of its own to WorldMapFrame (and BattlefieldMapFrame, the
-- zone map, when it loads) with MapCanvas's AddDataProvider: on RefreshAllData / OnMapChanged it draws every piece
-- of the map's art that isn't explored on a frame of its own on the map canvas, one frame level below the game's
-- exploration pin (so the explored pieces stay on top, the map tiles below), cut into 256 px tiles like the game
-- does (last column/row: the rest of the width/height, its texture coordinates cut to the next power of two). The
-- textures are pooled and reused; while the map is hidden nothing runs (the map refreshes its providers when it
-- opens). Nothing of Blizzard's is replaced or hooked; its provider is only read (its pin's frame level).
-- Off = no provider at all (removed again when switched off, its textures hidden). Idle while another addon
-- reveals the map: OpenMap's world map with unexplored areas not hidden, Leatrix Maps' "Reveal map" or Mapster's
-- FogClear (only their saved-variable flags / module state are read).

local Q = ns.qol
local R = {}
Q.reveal = R

local KEY = "revealMap"
local TINT_KEY = "revealTint"
local TILE = 256 -- the data's tile size (WorldMapOverlayTile: 256 px textures)
R.TINT = { 0.66, 0.72, 0.86 } -- vertex colour of an unexplored piece while tinted (a soft, darker blue)
R.DESATURATION = 0.45
R.LOAD_WAIT = 1 -- seconds the pieces may stay hidden waiting for their files before they show anyway

local function Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

local function Pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Pass(pcall(fn, ...))
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

-- Data ----------------------------------------------------------------------------------------------------------------

local parsed = {}
-- The pieces of a map art: { { x, y, w, h, ids = { fileID, ... } }, ... } (row-major tiles), or nil.
function R.Pieces(artID)
  if not artID then
    return nil
  end
  local cached = parsed[artID]
  if cached ~= nil then
    return cached or nil
  end
  local text = ns.MAP_REVEAL and ns.MAP_REVEAL[artID]
  local list = false
  if type(text) == "string" then
    list = {}
    for piece in text:gmatch("[^;]+") do
      local x, y, w, h, files = piece:match("^(%d+),(%d+),(%d+),(%d+),([%d/]+)$")
      if x then
        local ids = {}
        for id in files:gmatch("%d+") do
          ids[#ids + 1] = tonumber(id)
        end
        list[#list + 1] = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), ids = ids }
      end
    end
  end
  parsed[artID] = list
  return list or nil
end

local function PieceKey(x, y, w, h)
  return x .. ":" .. y .. ":" .. w .. ":" .. h
end

-- What the game has drawn already: { [x:y:w:h] = true, [first fileID] = true }.
function R.Explored(mapID)
  local seen = {}
  local list = C_MapExplorationInfo and Ask(C_MapExplorationInfo.GetExploredMapTextures, mapID)
  if type(list) ~= "table" or not Readable(list) then
    return seen
  end
  for _, info in ipairs(list) do
    if type(info) == "table" then
      local x, y = Num(info.offsetX), Num(info.offsetY)
      local w, h = Num(info.textureWidth), Num(info.textureHeight)
      if x and y and w and h then
        seen[PieceKey(x, y, w, h)] = true
      end
      local ids = Readable(info.fileDataIDs) and info.fileDataIDs
      local first = type(ids) == "table" and Num(ids[1])
      if first then
        seen[first] = true
      end
    end
  end
  return seen
end

-- The unexplored pieces of a map: the art's pieces minus the explored ones.
function R.Unexplored(mapID)
  local artID = C_Map and Num(Ask(C_Map.GetMapArtID, mapID))
  local pieces = R.Pieces(artID)
  if not pieces then
    return {}
  end
  local seen = R.Explored(mapID)
  local out = {}
  for _, piece in ipairs(pieces) do
    if not (seen[PieceKey(piece.x, piece.y, piece.w, piece.h)] or seen[piece.ids[1]]) then
      out[#out + 1] = piece
    end
  end
  return out
end

-- One side of a tile: its size in map pixels and the part of its file it uses (the game's maths: full tiles but
-- the last, which is the rest; its file is the next power of two from 16).
function R.TileSide(total, index, count)
  if index < count then
    return TILE, 1
  end
  local size = total % TILE
  if size == 0 then
    size = TILE
  end
  local file = 16
  while file < size do
    file = file * 2
  end
  return size, size / file
end

-- Drawing ---------------------------------------------------------------------------------------------------------------

-- One host per map: { name, addon, frame, provider, textures (pooled), used, events }.
R.hosts = {
  { name = "WorldMapFrame", addon = "Blizzard_WorldMap", textures = {}, used = 0 },
  { name = "BattlefieldMapFrame", addon = "Blizzard_BattlefieldMap", textures = {}, used = 0 },
}

local function Map(host)
  local map = _G[host.name]
  return type(map) == "table" and map or nil
end

-- The game's exploration pin of a map (its provider's one permanent pin), or nil.
local function ExplorationPin(map)
  local providers = Readable(map.dataProviders) and map.dataProviders
  if type(providers) ~= "table" then
    return nil
  end
  for provider in pairs(providers) do
    local pin = type(provider) == "table" and provider.pin
    if type(pin) == "table" and pin.overlayTexturePool then
      return pin
    end
  end
  return nil
end

-- Our frame's level: just under the game's explored pieces (its pin), over the map tiles.
local function FrameLevel(map, canvas)
  local pin = ExplorationPin(map)
  local level = pin and Num(Ask(pin.GetFrameLevel, pin))
  if not level then
    local manager = Ask(map.GetPinFrameLevelsManager, map)
    level = type(manager) == "table" and Num(Ask(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_MAP_EXPLORATION"))
  end
  local base = Num(Ask(canvas.GetFrameLevel, canvas)) or 0
  if not level then
    return base + 1
  end
  return math.max(base + 1, level - 1)
end

local function Canvas(map)
  local canvas = Ask(map.GetCanvas, map)
  if type(canvas) ~= "table" then
    canvas = type(map.ScrollContainer) == "table" and map.ScrollContainer.Child or nil
  end
  return type(canvas) == "table" and canvas or nil
end

local function Frame(host, map)
  if host.frame then
    return host.frame
  end
  local canvas = Canvas(map)
  if not canvas then
    return nil
  end
  local frame = CreateFrame("Frame", nil, canvas)
  frame:SetAllPoints(canvas)
  frame:EnableMouse(false)
  host.frame = frame
  return frame
end

function R.ApplyTint(texture)
  if Q.DB()[TINT_KEY] then
    texture:SetVertexColor(R.TINT[1], R.TINT[2], R.TINT[3], 1)
    if texture.SetDesaturation then
      texture:SetDesaturation(R.DESATURATION)
    end
  else
    texture:SetVertexColor(1, 1, 1, 1)
    if texture.SetDesaturation then
      texture:SetDesaturation(0)
    end
  end
end

local function Acquire(host)
  host.used = host.used + 1
  local texture = host.textures[host.used]
  if not texture then
    texture = host.frame:CreateTexture(nil, "ARTWORK")
    host.textures[host.used] = texture
  end
  return texture
end

-- Hides every texture of ours on this map (they stay in the pool).
function R.Release(host)
  for index = 1, host.used do
    local texture = host.textures[index]
    texture:Hide()
    texture:ClearAllPoints()
  end
  host.used = 0
  if host.frame then
    host.frame:SetScript("OnUpdate", nil)
  end
end

local function GlobalAlpha(map)
  return Num(Ask(map.GetGlobalAlpha, map)) or 1
end

-- Shown once the map's tiles and our files are loaded (no half-drawn flash), like the game's own pieces.
local function WaitForLoad(host, map)
  local frame = host.frame
  frame:SetAlpha(0)
  local waited = 0
  frame:SetScript("OnUpdate", function(self, elapsed)
    waited = waited + (Num(elapsed) or 0)
    local ready = Ask(map.AreDetailLayersLoaded, map) ~= false
    for index = 1, host.used do
      if not ready then
        break
      end
      local texture = host.textures[index]
      ready = not (texture.IsObjectLoaded and texture:IsObjectLoaded() == false)
    end
    if ready or waited >= R.LOAD_WAIT then
      self:SetScript("OnUpdate", nil)
      self:SetAlpha(GlobalAlpha(map))
    end
  end)
end

-- Draws the unexplored pieces of the map shown (none while off, idle, hidden or without data).
function R.Draw(host)
  local map = Map(host)
  R.Release(host)
  if not (map and Q.On(KEY) and map:IsShown()) then
    return
  end
  local mapID = Num(Ask(map.GetMapID, map))
  local pieces = mapID and R.Unexplored(mapID) or {}
  if #pieces == 0 then
    return
  end
  local frame = Frame(host, map)
  if not frame then
    return
  end
  frame:SetFrameLevel(FrameLevel(map, Canvas(map)))
  for _, piece in ipairs(pieces) do
    local wide, tall = math.ceil(piece.w / TILE), math.ceil(piece.h / TILE)
    for row = 1, tall do
      local height, v = R.TileSide(piece.h, row, tall)
      for col = 1, wide do
        local file = piece.ids[(row - 1) * wide + col]
        if file then
          local width, u = R.TileSide(piece.w, col, wide)
          local texture = Acquire(host)
          texture:SetSize(width, height)
          texture:SetTexCoord(0, u, 0, v)
          texture:SetPoint("TOPLEFT", frame, "TOPLEFT", piece.x + TILE * (col - 1), -(piece.y + TILE * (row - 1)))
          texture:SetTexture(file, nil, nil, "TRILINEAR")
          texture:SetDrawLayer("ARTWORK", 0)
          R.ApplyTint(texture)
          texture:Show()
        end
      end
    end
  end
  WaitForLoad(host, map)
end

-- The provider ----------------------------------------------------------------------------------------------------------

local function Safe(host, fn)
  return function()
    local ok, err = pcall(fn, host)
    if not ok and not host.failed then
      host.failed = true -- one report, not one per refresh
      geterrorhandler()(err)
    end
  end
end

local function Events(host)
  if not host.events then
    host.events = CreateFrame("Frame")
    host.events:SetScript("OnEvent", Safe(host, R.Draw))
  end
  return host.events
end

local function NewProvider(host)
  local provider
  if type(CreateFromMixins) == "function" and type(MapCanvasDataProviderMixin) == "table" then
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
  else
    provider = {}
    function provider:OnAdded(map) self.owningMap = map end
    function provider:OnRemoved() self.owningMap = nil end
    function provider:GetMap() return self.owningMap end
  end
  provider.codexReveal = true
  provider.RefreshAllData = Safe(host, R.Draw)
  provider.OnMapChanged = Safe(host, R.Draw)
  provider.RemoveAllData = Safe(host, R.Release)
  provider.OnShow = function()
    Events(host):RegisterEvent("MAP_EXPLORATION_UPDATED")
  end
  provider.OnHide = function()
    if host.events then
      host.events:UnregisterEvent("MAP_EXPLORATION_UPDATED")
    end
  end
  provider.OnGlobalAlphaChanged = function()
    local map = Map(host)
    if map and host.frame and not host.frame:GetScript("OnUpdate") then
      host.frame:SetAlpha(GlobalAlpha(map))
    end
  end
  return provider
end

-- Our provider on one map (now, when the map exists). True when it is on.
function R.Attach(host)
  if host.provider then
    return true
  end
  local map = Map(host)
  if not (map and type(map.AddDataProvider) == "function") then
    return false
  end
  local provider = NewProvider(host)
  if not pcall(map.AddDataProvider, map, provider) then
    return false
  end
  host.provider = provider
  if map:IsShown() then
    provider.OnShow()
    R.Draw(host)
  end
  return true
end

-- Our provider off the map again, its textures hidden.
function R.Detach(host)
  local map = Map(host)
  local provider = host.provider
  host.provider = nil
  if provider and map and type(map.RemoveDataProvider) == "function" then
    pcall(map.RemoveDataProvider, map, provider)
  end
  if provider then
    provider.OnHide()
  end
  R.Release(host)
end

function R.Start()
  R.started = true
  local waiting = false
  for _, host in ipairs(R.hosts) do
    if not R.Attach(host) then
      waiting = true
    end
  end
  if waiting and not R.loader then
    -- a map whose addon loads later (Blizzard_BattlefieldMap is load-on-demand)
    R.loader = CreateFrame("Frame")
    R.loader:SetScript("OnEvent", function(self)
      local all = true
      for _, host in ipairs(R.hosts) do
        if R.started and not R.Attach(host) then
          all = false
        end
      end
      if all then
        self:UnregisterEvent("ADDON_LOADED")
      end
    end)
  end
  if waiting then
    R.loader:RegisterEvent("ADDON_LOADED")
  end
end

function R.Stop()
  R.started = false
  if R.loader then
    R.loader:UnregisterEvent("ADDON_LOADED")
  end
  for _, host in ipairs(R.hosts) do
    R.Detach(host)
  end
end

-- The tint switched: the pieces drawn now get the new colour (nothing redrawn).
function R.Retint()
  for _, host in ipairs(R.hosts) do
    for index = 1, host.used do
      R.ApplyTint(host.textures[index])
    end
  end
end

-- Other addons revealing the map ------------------------------------------------------------------------------------------

local function Field(value, key)
  if type(value) ~= "table" then
    return nil
  end
  return value[key]
end

function R.Elsewhere()
  if ns.IsAddOnLoaded("OpenMap") then
    -- its world map draws the zones itself; unexplored areas "show" (its default) or "dim" = revealed
    local db = Field(_G.OpenMapDB, "worldmap")
    local mode = Field(db, "unexplored")
    local char = Field(_G.OpenMapCharDB, "worldmap")
    if Field(char, "unexploredOwn") and Field(char, "unexplored") then
      mode = Field(char, "unexplored")
    end
    if Field(db, "enabled") ~= false and mode ~= "hide" then
      return "OpenMap"
    end
  end
  if ns.IsAddOnLoaded("Leatrix_Maps") and Field(_G.LeaMapsDB, "RevealMap") == "On" then
    return "Leatrix Maps"
  end
  if ns.IsAddOnLoaded("Mapster") and LibStub then
    local ace = Pass(pcall(LibStub, "AceAddon-3.0", true)) -- LibStub is a callable table
    local mapster = type(ace) == "table" and Ask(ace.GetAddon, ace, "Mapster", true)
    local fog = type(mapster) == "table" and Ask(mapster.GetModule, mapster, "FogClear", true)
    if type(fog) == "table" and Ask(fog.IsEnabled, fog) then
      return "Mapster"
    end
  end
  return nil
end

function R.Enable()
  if Q.DB()[KEY] then
    R.Start()
  end
end

function R.Changed(on)
  if on then
    R.Start()
  else
    R.Stop()
  end
end

Q.AddToggle({
  key = KEY,
  name = L["Reveal unexplored areas on the map"],
  desc = L["Zone maps show the parts you haven't explored yet too, instead of leaving them dark. Also on the small zone map."],
  order = 45,
  Enable = R.Enable,
  Changed = R.Changed,
  Elsewhere = R.Elsewhere,
  options = {
    {
      key = TINT_KEY,
      name = L["Tint unexplored areas"],
      default = true,
      Changed = function()
        R.Retint()
      end,
    },
  },
})
