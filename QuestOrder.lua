local addonName, ns = ...

-- The order of your tracked quests by zone (shared by QoL's "Quest tracker order" and the Quest tracker module):
-- the quests of the zone you're in first, then the other zones' quests by zone (the zone with the nearest quest
-- first, then the quest log's order of zones); inside each, nearest first, then the quest log's order.
--
-- A quest is in your zone when its quest log header is the zone's name (the log groups quests under zone headers),
-- or the game puts it on your map (QuestInfo.isOnMap / C_QuestLog.IsOnMap). Distance: C_QuestLog.GetDistanceSqToQuest
-- where the game knows the quest's spot on your continent (many Classic quests have none: those keep their log
-- order). Every value is read through Readable (no secret is compared).

local QO = {}
ns.QuestOrder = QO

local FAR = math.huge
QO.FAR = FAR

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
QO.Readable = Readable

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local result = { pcall(fn, ...) }
  if not result[1] then
    return nil
  end
  return (unpack or table.unpack)(result, 2)
end
QO.Ask = Ask

-- C_QuestLog's functions, looked up when used (nil when missing)
local function API(name)
  return type(C_QuestLog) == "table" and C_QuestLog[name] or nil
end
QO.API = API

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end
QO.Num = Num

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end
QO.Str = Str

local function Lower(text)
  text = Str(text)
  return text and text:lower() or nil
end

-- The watched quests in the game's watch order.
function QO.Watched()
  local list = {}
  local count = Num(Ask(API("GetNumQuestWatches"))) or 0
  for index = 1, count do
    local id = Num(Ask(API("GetQuestIDForQuestWatchIndex"), index))
    if id then
      list[#list + 1] = id
    end
  end
  return list
end

-- The names of the zone you're in (lower case): the game's zone text and the map you're on with its parents up to
-- the zone.
function QO.ZoneNames()
  local names = {}
  local function Add(name)
    name = Lower(name)
    if name then
      names[name] = true
    end
  end
  Add(Ask(GetRealZoneText))
  Add(Ask(GetZoneText))
  local mapID = C_Map and Num(Ask(C_Map.GetBestMapForUnit, "player"))
  local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
  for _ = 1, 5 do
    local info = mapID and C_Map.GetMapInfo and Ask(C_Map.GetMapInfo, mapID)
    if type(info) ~= "table" then
      break
    end
    Add(info.name)
    if Num(info.mapType) and info.mapType <= zoneType then
      break
    end
    mapID = Num(info.parentMapID)
  end
  return names
end

-- Each quest in the log: { order (log index), logIndex, header (the zone header's text), title, level, onMap }.
function QO.LogInfo()
  local byID = {}
  local count = Num(Ask(API("GetNumQuestLogEntries"))) or 0
  local header
  for index = 1, count do
    local info = Ask(API("GetInfo"), index)
    if type(info) == "table" then
      if info.isHeader == true then
        header = Str(info.title)
      else
        local id = Num(info.questID)
        if id then
          byID[id] = { order = index, logIndex = index, header = header, title = Str(info.title),
            level = Num(info.level), onMap = info.isOnMap == true }
        end
      end
    end
  end
  return byID
end

function QO.Distance(id)
  local distanceSq, onContinent = Ask(API("GetDistanceSqToQuest"), id)
  distanceSq = Num(distanceSq)
  if distanceSq and Readable(onContinent) and onContinent == true then
    return distanceSq
  end
  return nil
end

-- The watched quests sorted, as entries { id, position, order, distance, here, zone (lower case), header (as the
-- log writes it), info (the LogInfo entry) }, and the list of quest IDs in that order.
function QO.Sorted(watched)
  watched = watched or QO.Watched()
  local log = QO.LogInfo()
  local here = QO.ZoneNames()
  local entries, zones = {}, {}
  for position, id in ipairs(watched) do
    local info = log[id] or {}
    local onMap = info.onMap
    if not onMap and API("IsOnMap") then
      onMap = Ask(API("IsOnMap"), id) == true
    end
    local zone = info.header and info.header:lower() or nil
    local entry = {
      id = id,
      position = position,
      order = info.order or (1000 + position),
      distance = QO.Distance(id),
      here = (zone and here[zone]) or onMap or false,
      zone = zone or "",
      header = info.header,
      info = info,
    }
    entries[#entries + 1] = entry
    if not entry.here then
      local group = zones[entry.zone]
      if not group then
        group = { nearest = FAR, first = entry.order }
        zones[entry.zone] = group
      end
      group.nearest = math.min(group.nearest, entry.distance or FAR)
      group.first = math.min(group.first, entry.order)
    end
  end
  table.sort(entries, function(a, b)
    if a.here ~= b.here then
      return a.here
    end
    if not a.here and a.zone ~= b.zone then
      local ga, gb = zones[a.zone], zones[b.zone]
      if ga.nearest ~= gb.nearest then
        return ga.nearest < gb.nearest
      end
      return ga.first < gb.first
    end
    local da, db = a.distance or FAR, b.distance or FAR
    if da ~= db then
      return da < db
    end
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.position < b.position
  end)
  local list = {}
  for index, entry in ipairs(entries) do
    list[index] = entry.id
  end
  return list, entries
end
