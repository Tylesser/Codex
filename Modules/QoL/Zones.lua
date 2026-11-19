local addonName, ns = ...

-- Zone levels on the world map. Hovering a zone on a continent map shows, under the game's big zone name, its
-- level range ("50-58", coloured from your level the way the game colours quests: red far above you, grey far
-- below) and, when you have the profession, a line with the zone's Fishing minimum and its Mining / Herbalism
-- range ("Fishing 330 · Mining 155-275 · Herbalism 230-300"; red when your skill is below the zone's minimum).
-- Viewing a zone map shows the same lines for that zone at the top of the map (under the hovered area name).
--
-- How: Forever's AreaLabelDataProvider (Blizzard_SharedMapDataProviders) keeps one label frame (Name, Description)
-- on the map's canvas; it would add C_Map.GetMapLevels ranges itself, but Forever has none. Codex adds a frame of
-- its own as a child of that label, with its own two strings and its own OnUpdate that only reads (the label's
-- texts and current label info, the map's cursor position, C_Map.GetMapInfoAtPosition). No Blizzard method is
-- replaced or hooked, so the map is never tainted. Data: ns.ZONE_LEVELS / ns.GATHER_ZONES (Gathering.lua), the
-- ranks from the gathering toggle (Gather.lua, G.Rank). Secret texts are treated as empty. Nothing is made while
-- the toggle is off; switched on later, it is made then. Leatrix Maps with "Show zone levels" on does this job.

local Q = ns.qol
local Z = {}
Q.zones = Z

local KEY = "zoneLevels"
local DOT = " · "
local RED = { 1, 0.1, 0.1 }
local NORMAL = { 1, 0.82, 0 }

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

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Hex(r, g, b)
  return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Paint(text, color)
  return Hex(color[1], color[2], color[3]) .. text .. "|r"
end

-- Data -------------------------------------------------------------------------------------------------------------

local byName
-- The zone's data by uiMapID, else by its English name (a map the table doesn't know by ID).
function Z.Zone(mapID, name)
  local zone = Num(mapID) and ns.ZONE_LEVELS[mapID]
  if zone then
    return zone, mapID
  end
  name = Str(name)
  if name then
    if not byName then
      byName = {}
      for id, data in pairs(ns.ZONE_LEVELS) do
        byName[data.name] = id
      end
    end
    local id = byName[name]
    if id then
      return ns.ZONE_LEVELS[id], id
    end
  end
  return nil
end

-- Lowest and highest node requirement of a profession in a zone, or nil (no nodes known there).
function Z.GatherRange(mapID, skill)
  local low, high
  for _, name in ipairs(ns.GATHER_ZONES[mapID] or {}) do
    local node = ns.GATHER_SKILL[name]
    if node and node.skill == skill then
      low = math.min(low or node.level, node.level)
      high = math.max(high or node.level, node.level)
    end
  end
  return low, high
end

-- Colours ----------------------------------------------------------------------------------------------------------

local function ColorOf(value)
  if type(value) == "table" and Num(value.r) and Num(value.g) and Num(value.b) then
    return { value.r, value.g, value.b }
  end
  return nil
end

-- The game's quest colour for a level (red / orange / yellow / green / grey from your level).
local function QuestColor(level)
  local color = GetQuestDifficultyColor and ColorOf(Ask(GetQuestDifficultyColor, level))
  if color then
    return color
  end
  local mine = Num(Ask(UnitLevel, "player")) or 1
  local gap = level - mine
  if gap >= 5 then
    return { 1, 0.1, 0.1 }
  elseif gap >= 3 then
    return { 1, 0.5, 0.25 }
  elseif gap >= -2 then
    return { 1, 0.82, 0 }
  elseif gap >= -8 then
    return { 0.25, 0.75, 0.25 }
  end
  return { 0.5, 0.5, 0.5 }
end

-- The range's colour, as the game's own area label does it: below the zone = its minimum's quest colour, above
-- it = its maximum's (minus 2, so a zone you've outlevelled isn't yellow), inside it = "difficult" (yellow).
function Z.LevelColor(level, low, high)
  if level < low then
    return QuestColor(low)
  elseif level > high then
    return QuestColor(high - 2)
  end
  local colors = _G.QuestDifficultyColors
  return ColorOf(type(colors) == "table" and colors.difficult) or { 1, 0.82, 0 }
end

-- Texts ------------------------------------------------------------------------------------------------------------

local function Range(low, high)
  return low == high and tostring(low) or (low .. "-" .. high)
end

-- "50-58" in the colour for your level, or nil (a city).
function Z.LevelText(zone)
  if not (zone.min and zone.max) then
    return nil
  end
  local level = Num(Ask(UnitLevel, "player")) or 1
  return Paint(Range(zone.min, zone.max), Z.LevelColor(level, zone.min, zone.max))
end

-- "Fishing 330 · Mining 155-275 · Herbalism 230-300": only the professions you have; nil when none applies.
function Z.ProfessionText(zone, mapID)
  local G = Q.gather
  local parts = {}
  local fishing = G.Rank("fishing")
  if fishing and zone.fish then
    parts[#parts + 1] = Paint(G.SkillName("fishing") .. " " .. zone.fish, fishing < zone.fish and RED or NORMAL)
  end
  for _, skill in ipairs({ "mining", "herbalism" }) do
    local rank = G.Rank(skill)
    local low, high = Z.GatherRange(mapID, skill)
    if rank and low then
      parts[#parts + 1] = Paint(G.SkillName(skill) .. " " .. Range(low, high), rank < low and RED or NORMAL)
    end
  end
  return #parts > 0 and table.concat(parts, DOT) or nil
end

-- The map -----------------------------------------------------------------------------------------------------------

-- The area label frame of a map (the one the AreaLabelDataProvider made), or nil.
function Z.FindLabel(map)
  local providers = type(map) == "table" and map.dataProviders
  if type(providers) ~= "table" then
    return nil
  end
  for provider in pairs(providers) do
    local label = type(provider) == "table" and provider.Label
    if type(label) == "table" and label.Name and label.Description and label.labelInfoByType then
      return label
    end
  end
  return nil
end

-- What the label shows now: "area" (a hovered zone/area name), "other" (a higher-priority label such as a POI)
-- or nil (nothing).
local function LabelState(label)
  local top = type(label.GetHighestPriorityLabelInfo) == "function" and Ask(label.GetHighestPriorityLabelInfo, label)
  if type(top) ~= "table" then
    return nil
  end
  local types = _G.MAP_AREA_LABEL_TYPE
  local infos = label.labelInfoByType
  local area = type(types) == "table" and type(infos) == "table" and infos[types.AREA_NAME]
  return top == area and "area" or "other"
end

-- The zone to show and how: mapID, "hover" (a zone under the cursor on a bigger map) or "view" (the map shown).
function Z.Target(map, label)
  local mapID = Num(Ask(map.GetMapID, map))
  if not mapID then
    return nil
  end
  if Ask(map.IsCanvasMouseFocus, map) and LabelState(label) == "area" then
    local x, y = Ask(map.GetNormalizedCursorPosition, map)
    local info = C_Map and Num(x) and Num(y) and Ask(C_Map.GetMapInfoAtPosition, mapID, x, y)
    local hovered = type(info) == "table" and Num(info.mapID)
    if hovered and hovered ~= mapID then
      local _, id = Z.Zone(hovered, info.name)
      if id then
        return id, "hover"
      end
    end
  end
  local _, id = Z.Zone(mapID)
  if id then
    return id, "view"
  end
  return nil
end

local function Text(fs)
  return fs and fs.GetText and Str(fs:GetText()) or nil
end

local function Place(view, label, mode)
  local anchor
  if mode ~= "top" and Text(label.Description) then
    anchor = "description"
  elseif mode ~= "top" and Text(label.Name) then
    anchor = "name"
  else
    anchor = "top"
  end
  if view.anchor == anchor then
    return
  end
  view.anchor = anchor
  view.level:ClearAllPoints()
  if anchor == "description" then
    view.level:SetPoint("TOP", label.Description, "BOTTOM", 0, -6)
  elseif anchor == "name" then
    view.level:SetPoint("TOP", label.Name, "BOTTOM", 0, -8)
  else
    view.level:SetPoint("TOP", label, "TOP", 0, -20)
  end
end

local function Clear(view)
  view.level:SetText("")
  view.prof:SetText("")
  view.shown = nil
end

-- One update of our lines (our own frame's OnUpdate, while the map is open).
function Z.Update(view)
  local label = view.label
  if not Q.On(KEY) then
    if view.shown then
      Clear(view)
    end
    return
  end
  local provider = label.dataProvider
  local map = type(provider) == "table" and Ask(provider.GetMap, provider) or _G.WorldMapFrame
  local mapID, mode
  if type(map) == "table" then
    mapID, mode = Z.Target(map, label)
  end
  local zone = mapID and ns.ZONE_LEVELS[mapID]
  if not zone then
    if view.shown then
      Clear(view)
    end
    return
  end
  local level = Z.LevelText(zone)
  local onTop = mode == "view" and LabelState(label) == nil
  if onTop then
    -- nothing hovered on a zone map: the zone's own name leads the line
    local info = C_Map and Ask(C_Map.GetMapInfo, mapID)
    local name = type(info) == "table" and Str(info.name) or zone.name
    level = level and (name .. "  " .. level) or name
  end
  Place(view, label, onTop and "top" or nil)
  view.level:SetText(level or "")
  view.prof:SetText(Z.ProfessionText(zone, mapID) or "")
  view.shown = mapID
end

local function Font(fs, names)
  for _, name in ipairs(names) do
    local font = _G[name]
    if type(font) == "table" and fs.SetFontObject then
      fs:SetFontObject(font)
      return
    end
  end
end

-- Our frame on the map's area label.
function Z.Attach(map)
  if Z.view then
    return true
  end
  local label = Z.FindLabel(map)
  if not label then
    return false
  end
  local frame = CreateFrame("Frame", nil, label)
  frame:SetAllPoints(label)
  local view = { frame = frame, label = label }
  view.level = frame:CreateFontString(nil, "OVERLAY")
  Font(view.level, { "SubZoneTextFont", "GameFontNormalLarge" })
  view.prof = frame:CreateFontString(nil, "OVERLAY")
  Font(view.prof, { "SystemFont_Shadow_Large_Outline", "GameFontNormalLarge" })
  view.prof:SetPoint("TOP", view.level, "BOTTOM", 0, -6)
  Place(view, label)
  frame:SetScript("OnUpdate", function()
    local ok, err = pcall(Z.Update, view)
    if not ok then
      frame:SetScript("OnUpdate", nil) -- one error, not one per frame
      geterrorhandler()(err)
    end
  end)
  Z.view = view
  return true
end

Z.hooked = false
function Z.Hook()
  if Z.hooked then
    return
  end
  Z.hooked = true
  if Z.Attach(_G.WorldMapFrame) then
    return
  end
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(self, _, name)
    if name == "Blizzard_WorldMap" or _G.WorldMapFrame then
      if Z.Attach(_G.WorldMapFrame) then
        self:UnregisterEvent("ADDON_LOADED")
      end
    end
  end)
  events:RegisterEvent("ADDON_LOADED")
  Z.events = events
end

function Z.Elsewhere()
  if ns.IsAddOnLoaded("Leatrix_Maps") then
    local db = _G.LeaMapsDB
    if type(db) == "table" and db.ShowZoneLevels == "On" then
      return "Leatrix Maps"
    end
  end
  return nil
end

function Z.Enable()
  if Q.DB()[KEY] then
    Z.Hook()
  end
end

function Z.Changed(on)
  if on then
    Z.Hook()
  end
end

Q.AddToggle({
  key = KEY,
  name = "Zone levels on the world map",
  desc = "Hovering a zone on the map shows its level range (\"50-58\", coloured from your level) and, if you "
    .. "have them, the Fishing skill it needs and its Mining and Herbalism ranges. A zone map shows its own.",
  order = 40,
  Enable = Z.Enable,
  Changed = Z.Changed,
  Elsewhere = Z.Elsewhere,
})
