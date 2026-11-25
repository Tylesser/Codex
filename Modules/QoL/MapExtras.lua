local addonName, ns = ...

-- Map extras: dungeon and raid entrances on zone and continent maps (an icon at each entrance; hover for the name,
-- the level range coloured for your level, dungeon or raid and its size, the zone on a bigger map or another zone's
-- map), and the town's services on zone maps (innkeepers, flight masters, banks, auction houses, mailboxes; on
-- request trainers, vendors, repair, stable masters and others). Only your own faction's services: NPCs hostile to
-- you are left out. What shows is picked under the toggle on the Quality of life page or with the small funnel
-- button on the world map's top bar.
--
-- How: our own data provider on WorldMapFrame (MapCanvas AddDataProvider, removed again when switched off; never on
-- the flight map or the small zone map). Its pins are frames of ours on the map canvas: a holder at the position and
-- the pin on it, scaled against the canvas zoom so it stays the same size on screen, spread round their middle when
-- they would overlap. On zone maps the pins sit at the game's dungeon entrance pin level (above the map art and the
-- explored areas, under flight points, area POIs and every quest pin); on continent maps just under Codex's own
-- quest pins (Skins/QuestPins.lua, canvas + 60). A pin takes no clicks (SetMouseClickEnabled(false)): clicks, drags
-- and the wheel go to the map and the pins under it; only the hover tooltip is ours. No frames are made in a fight.
-- Data: MapExtrasData.lua (generated data).
--
-- A group stays idle where something else shows it already: dungeons where the game's own dungeon entrance pins
-- would show (CVar showDungeonEntrancesOnMap and C_EncounterJournal.GetDungeonEntrancesForMap; Forever has no
-- encounter journal data for Classic instances today, so it returns none), flight masters where the game draws its
-- flight points on that map (C_TaxiMap.ShouldMapShowTaxiNodes with nodes), and every group another map addon shows:
-- Leatrix Maps (its "Show points of interest" with dungeons / flight points / spirit healers) and OpenMap (its world
-- map's dungeons, flight masters and townsfolk kinds). Only their saved-variable flags are read.

local Q = ns.qol
local M = {}
Q.mapExtras = M

local KEY = "mapExtras"
local SHOW_KEY = "mapExtrasShow"
local CLASS_KEY = "mapExtrasClasses"
local PROF_KEY = "mapExtrasProfs"
local NOTE_KEY = "mapExtrasNote"

local ART = "Interface\\AddOns\\Codex\\Modules\\QoL\\Media\\MapIcons"
local COLS, ROWS = 8, 4
local ICON = { dungeon = 0, raid = 1, inn = 2, fly = 3, bank = 4, ah = 5, mail = 6, ct = 7, pt = 8, repair = 9,
  goods = 10, stable = 11, bm = 12, spirit = 13, guild = 14, wm = 15, ride = 16, barber = 17, tmog = 18, disc = 19,
  ring = 20, filter = 21, food = 22, reagent = 23, poison = 23 }
M.ICON = ICON

M.SIZE = { dungeon = 22, service = 17 } -- on screen
M.SPREAD = 0.8 -- pins closer than this many pin widths (on screen) are spread apart
M.CONTINENT_LEVELS = 58 -- on a continent: our frame this far above the canvas (Codex's quest pins: 60)

-- The groups, in the menu's order. default = shown when nothing is saved yet.
M.GROUPS = {
  { key = "dungeons", name = "Dungeons and raids", default = true },
  { key = "inns", name = "Innkeepers", default = true, kinds = { inn = true } },
  { key = "flight", name = "Flight masters", default = true, kinds = { fly = true } },
  { key = "banks", name = "Banks", default = true, kinds = { bank = true } },
  { key = "auction", name = "Auction houses", default = true, kinds = { ah = true } },
  { key = "mail", name = "Mailboxes", default = true, kinds = { mail = true } },
  { key = "classTrainers", name = "Class trainers", default = false, kinds = { ct = true } },
  { key = "profTrainers", name = "Profession trainers", default = false, kinds = { pt = true } },
  { key = "vendors", name = "Vendors", default = false, kinds = { goods = true, food = true, reagent = true, poison = true } },
  { key = "repair", name = "Repair", default = false, kinds = { repair = true } },
  { key = "stable", name = "Stable masters", default = false, kinds = { stable = true } },
  { key = "others", name = "Others", default = false,
    kinds = { bm = true, spirit = true, guild = true, wm = true, ride = true, barber = true, tmog = true } },
}
local GROUP_OF = {}
for _, group in ipairs(M.GROUPS) do
  for kind in pairs(group.kinds or {}) do
    GROUP_OF[kind] = group.key
  end
end
M.GROUP_OF = GROUP_OF

-- What a service is called (tooltip title) and the colour token of its glyph.
M.KINDS = {
  inn = { "Innkeeper", "warn" }, fly = { "Flight master", "good" }, bank = { "Bank", "money" },
  ah = { "Auction house", "money" }, mail = { "Mailbox", "bright" }, ct = { "Class trainer", "class" },
  pt = { "Profession trainer", "accent" }, repair = { "Repair", "text" }, goods = { "General goods", "text" },
  food = { "Food and drink", "text" }, reagent = { "Reagents", "text" }, poison = { "Poisons", "text" },
  stable = { "Stable master", "text" }, bm = { "Battlemaster", "bad" }, spirit = { "Spirit healer", "bright" },
  guild = { "Guild master", "text" }, wm = { "Weapon master", "text" }, ride = { "Riding trainer", "text" },
  barber = { "Barber", "text" }, tmog = { "Transmogrifier", "text" },
}
M.PROFESSIONS = {
  alchemy = { "Alchemy", 171 }, blacksmithing = { "Blacksmithing", 164 }, enchanting = { "Enchanting", 333 },
  engineering = { "Engineering", 202 }, herbalism = { "Herbalism", 182 }, leatherworking = { "Leatherworking", 165 },
  mining = { "Mining", 186 }, skinning = { "Skinning", 393 }, tailoring = { "Tailoring", 197 },
  cooking = { "Cooking", 185 }, firstaid = { "First Aid", 129 }, fishing = { "Fishing", 356 },
}
local CLASS_NAMES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }

-- Safe reads -------------------------------------------------------------------------------------------------------

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

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Field(value, key)
  if type(value) ~= "table" then
    return nil
  end
  return value[key]
end

local function InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

local function Theme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

-- Settings -----------------------------------------------------------------------------------------------------------

function M.Shown(group)
  local show = Q.DB()[SHOW_KEY]
  return type(show) == "table" and show[group] and true or false
end

function M.SetGroup(group, on)
  local db = Q.DB()
  if type(db[SHOW_KEY]) ~= "table" then
    db[SHOW_KEY] = {}
  end
  db[SHOW_KEY][group] = on and true or false
  M.Refresh()
  if Q.RefreshPage then
    Q.RefreshPage()
  end
end

-- The player ---------------------------------------------------------------------------------------------------------

local function Faction()
  local faction = Str(Ask(UnitFactionGroup, "player"))
  return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
end

local function PlayerClass()
  return Str(select(2, Ask(UnitClass, "player")))
end

-- The professions the player has: { alchemy = true, ... } (skill lines, else the English skill names).
function M.PlayerProfessions()
  local have = {}
  local byLine, byName = {}, {}
  for key, info in pairs(M.PROFESSIONS) do
    byLine[info[2]] = key
    byName[info[1]:lower()] = key
  end
  if GetProfessions and GetProfessionInfo then
    local list = { Ask(GetProfessions) }
    for slot = 1, 5 do
      local index = Num(list[slot])
      if index then
        local name, _, _, _, _, _, line = Ask(GetProfessionInfo, index)
        local key = byLine[Num(line) or -1] or (Str(name) and byName[name:lower()])
        if key then
          have[key] = true
        end
      end
    end
  end
  if next(have) == nil and GetNumSkillLines and GetSkillLineInfo then
    for index = 1, Num(Ask(GetNumSkillLines)) or 0 do
      local name, isHeader = Ask(GetSkillLineInfo, index)
      local key = not isHeader and Str(name) and byName[name:lower()]
      if key then
        have[key] = true
      end
    end
  end
  return have
end

-- Who else shows a group ---------------------------------------------------------------------------------------------

local OPENMAP_TOWNSFOLK = { inns = "innkeeper", banks = "banker", auction = "auctioneer", mail = "mailbox",
  stable = "stable", classTrainers = "classTrainer", profTrainers = "profTrainer", repair = "repair",
  vendors = "vendor", spirit = "spirit" }

-- The map addon showing a group (or the kind "spirit") everywhere, or nil.
function M.Addon(group)
  if ns.IsAddOnLoaded("Leatrix_Maps") then
    local db = _G.LeaMapsDB
    if Field(db, "ShowPointsOfInterest") == "On" then
      local flag = ({ dungeons = "ShowDungeonIcons", flight = "ShowFlightPoints", spirit = "ShowSpiritHealers" })[group]
      if flag and Field(db, flag) == "On" then
        return "Leatrix Maps"
      end
    end
  end
  if ns.IsAddOnLoaded("OpenMap") then
    local db = Field(_G.OpenMapDB, "worldmap")
    if type(db) == "table" and db.enabled ~= false then
      if group == "dungeons" and db.icons ~= false then
        return "OpenMap"
      end
      if group == "flight" and db.flight ~= false then
        return "OpenMap"
      end
      local kind = OPENMAP_TOWNSFOLK[group]
      if kind and Field(db.townsfolk, kind) == true then
        return "OpenMap"
      end
    end
  end
  return nil
end

-- The game shows this group on this map itself (dungeon entrances, flight points).
function M.GameShows(group, mapID)
  if group == "dungeons" then
    local on = GetCVarBool and Ask(GetCVarBool, "showDungeonEntrancesOnMap")
    if on and C_EncounterJournal then
      local list = Ask(C_EncounterJournal.GetDungeonEntrancesForMap, mapID)
      return type(list) == "table" and Readable(list) and #list > 0
    end
  elseif group == "flight" and C_TaxiMap then
    if Ask(C_TaxiMap.ShouldMapShowTaxiNodes, mapID) == true then
      local list = Ask(C_TaxiMap.GetTaxiNodesForMap, mapID)
      return type(list) == "table" and Readable(list) and #list > 0
    end
  end
  return false
end

-- Whether Codex draws this group (or kind) on this map now.
function M.Wanted(group, mapID)
  if not M.Shown(group) then
    return false
  end
  return not M.Addon(group) and not M.GameShows(group, mapID)
end

-- The page's line about other addons.
function M.NoteText()
  local by = {}
  local order = {}
  for _, group in ipairs(M.GROUPS) do
    local who = M.Addon(group.key)
    if who then
      if not by[who] then
        by[who] = {}
        order[#order + 1] = who
      end
      table.insert(by[who], group.name:lower())
    end
  end
  local who = M.Addon("spirit")
  if who then
    if not by[who] then
      by[who] = {}
      order[#order + 1] = who
    end
    table.insert(by[who], "spirit healers")
  end
  local parts = {}
  for _, name in ipairs(order) do
    parts[#parts + 1] = ("%s shows %s, so Codex leaves those to it."):format(name, table.concat(by[name], ", "))
  end
  return table.concat(parts, " ")
end

-- Data ----------------------------------------------------------------------------------------------------------------

local parsed = {}
-- The services of a zone map: { { kind, detail, x, y, faction, ids = { npcID, ... } }, ... } (x, y in 0-1).
function M.Spots(mapID)
  local cached = parsed[mapID]
  if cached then
    return cached
  end
  local list = {}
  local text = ns.MAP_SERVICES and ns.MAP_SERVICES[mapID]
  if type(text) == "string" then
    for spot in text:gmatch("[^;]+") do
      local kind, x, y, faction, ids = spot:match("^([%w:]+),([%d.]+),([%d.]+),(%a),([%d/]*)$")
      if kind then
        local base, detail = kind:match("^(%w+):(%w+)$")
        local entry = { kind = base or kind, detail = detail, x = tonumber(x) / 100, y = tonumber(y) / 100,
          faction = faction, ids = {} }
        for id in ids:gmatch("%d+") do
          entry.ids[#entry.ids + 1] = tonumber(id)
        end
        list[#list + 1] = entry
      end
    end
  end
  parsed[mapID] = list
  return list
end

-- Forget the parsed spots (the data changed: tests).
function M.ClearCache()
  parsed = {}
end

-- Map info --------------------------------------------------------------------------------------------------------------

local function MapType(mapID)
  local info = C_Map and Ask(C_Map.GetMapInfo, mapID)
  return Num(Field(info, "mapType"))
end

local function ZoneType()
  return Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
end

local function ContinentType()
  return Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
end

function M.ZoneName(mapID)
  local info = C_Map and Ask(C_Map.GetMapInfo, mapID)
  local name = Str(Field(info, "name"))
  if name then
    return name
  end
  local zone = ns.ZONE_LEVELS and ns.ZONE_LEVELS[mapID]
  return zone and zone.name or ""
end

-- The dungeon pins for a map: { { u, v, list = { { inst, zone }, ... } } } (u, v in 0-1 of the shown map).
function M.InstancePoints(mapID)
  local kind = MapType(mapID)
  local points = {}
  local function Add(inst, zone, u, v)
    for _, point in ipairs(points) do
      for _, item in ipairs(point.list) do
        if item.inst == inst and math.abs(point.u - u) < 0.01 and math.abs(point.v - v) < 0.01 then
          return -- the same entrance seen from two zones (Blackrock Mountain)
        end
      end
    end
    for _, point in ipairs(points) do
      if math.abs(point.u - u) < 0.006 and math.abs(point.v - v) < 0.006 then
        table.insert(point.list, { inst = inst, zone = zone })
        return
      end
    end
    points[#points + 1] = { u = u, v = v, list = { { inst = inst, zone = zone } } }
  end
  if kind == ZoneType() then
    for _, inst in ipairs(ns.MAP_INSTANCES or {}) do
      for _, at in ipairs(inst.at) do
        if at[1] == mapID then
          Add(inst, inst.home ~= mapID and inst.home or nil, at[2] / 100, at[3] / 100)
        end
      end
    end
  elseif kind == ContinentType() and C_Map and C_Map.GetMapChildrenInfo and C_Map.GetMapRectOnMap then
    local rects = {}
    for _, child in ipairs(Ask(C_Map.GetMapChildrenInfo, mapID, ZoneType(), true) or {}) do
      local childID = Num(Field(child, "mapID"))
      if childID then
        local left, right, top, bottom = Ask(C_Map.GetMapRectOnMap, childID, mapID)
        left, right, top, bottom = Num(left), Num(right), Num(top), Num(bottom)
        if left and right and top and bottom then
          rects[childID] = { left, right, top, bottom }
        end
      end
    end
    for _, inst in ipairs(ns.MAP_INSTANCES or {}) do
      for _, at in ipairs(inst.at) do
        local r = rects[at[1]]
        if r then
          Add(inst, at[1], r[1] + at[2] / 100 * (r[2] - r[1]), r[3] + at[3] / 100 * (r[4] - r[3]))
        end
      end
    end
  end
  return points
end

-- The service pins for a zone map (only the player's faction and the groups wanted there).
function M.ServicePoints(mapID)
  if MapType(mapID) ~= ZoneType() then
    return {}
  end
  local faction = Faction()
  local class = PlayerClass()
  local allClasses = Q.DB()[CLASS_KEY] == "all"
  local allProfs = Q.DB()[PROF_KEY] ~= "mine"
  local mine = not allProfs and M.PlayerProfessions() or nil
  local wanted = {}
  local points = {}
  for _, spot in ipairs(M.Spots(mapID)) do
    local group = GROUP_OF[spot.kind]
    if group and (spot.faction == "B" or spot.faction == faction) then
      if wanted[group] == nil then
        wanted[group] = M.Wanted(group, mapID)
      end
      local ok = wanted[group]
      if ok and spot.kind == "spirit" and M.Addon("spirit") then
        ok = false
      end
      if ok and spot.kind == "ct" and not allClasses then
        ok = spot.detail == class
      end
      if ok and spot.kind == "pt" and mine then
        ok = mine[spot.detail] or false
      end
      if ok then
        points[#points + 1] = { u = spot.x, v = spot.y, spot = spot }
      end
    end
  end
  return M.MergeNear(points)
end

-- The data has several mailbox objects at nearly the same place (one per faction, old and new spawns): six pins
-- round the one mailbox of Ironforge's Commons (the user's screenshot, 2026-11-20). Points of a merged kind closer
-- than its radius (map fractions) to any point of a group become one pin in the group's middle.
local MERGE_RADIUS = { mail = 0.035 }

function M.MergeNear(points)
  local out, groups = {}, {}
  for _, point in ipairs(points) do
    local kind = point.spot.kind
    local radius = MERGE_RADIUS[kind]
    local joined
    if radius then
      for _, group in ipairs(groups) do
        if group.kind == kind then
          for _, member in ipairs(group.members) do
            local du, dv = member.u - point.u, member.v - point.v
            if du * du + dv * dv <= radius * radius then
              joined = group
              break
            end
          end
        end
        if joined then
          break
        end
      end
    end
    if joined then
      local members = joined.members
      members[#members + 1] = point
      local su, sv = 0, 0
      for _, member in ipairs(members) do
        su, sv = su + member.u, sv + member.v
      end
      joined.pin.u, joined.pin.v = su / #members, sv / #members
    else
      local pin = { u = point.u, v = point.v, spot = point.spot }
      out[#out + 1] = pin
      if radius then
        groups[#groups + 1] = { kind = kind, members = { point }, pin = pin }
      end
    end
  end
  return out
end

-- Texts -----------------------------------------------------------------------------------------------------------------

local function Hex(c)
  return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5))
end

function M.LevelText(low, high)
  local text = low == high and tostring(low) or (low .. "-" .. high)
  local Z = Q.zones
  if Z and Z.LevelColor then
    local level = Num(Ask(UnitLevel, "player")) or 1
    local ok, color = pcall(Z.LevelColor, level, low, high)
    if ok and type(color) == "table" then
      return Hex(color) .. text .. "|r"
    end
  end
  return text
end

local function KindText(inst, players)
  return ("%s, %d players"):format(inst.kind == "raid" and "Raid" or "Dungeon", players)
end

function M.ServiceTitle(spot)
  local info = M.KINDS[spot.kind]
  local title = info and info[1] or spot.kind
  if spot.kind == "ct" and spot.detail then
    local name = CLASS_NAMES[spot.detail] or spot.detail
    local localized = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[spot.detail]
    title = title .. ": " .. (Str(localized) or name)
  elseif spot.kind == "pt" and spot.detail then
    local prof = M.PROFESSIONS[spot.detail]
    title = title .. ": " .. (prof and prof[1] or spot.detail)
  end
  return title
end

-- Tooltip lines for a pin: { { left, right, color } } (right may be nil). The first line is the title.
function M.TooltipLines(pin)
  local theme = Theme()
  local lines = {}
  local function Add(left, right, color)
    lines[#lines + 1] = { left, right, color or theme.text }
  end
  if pin.list then
    for index, item in ipairs(pin.list) do
      local inst = item.inst
      if index > 1 then
        Add(" ")
      end
      Add(inst.name, nil, theme.bright)
      local wings = inst.wings
      if #wings == 1 then
        Add(KindText(inst, wings[1][4]), M.LevelText(wings[1][2], wings[1][3]), theme.muted)
      else
        local players = wings[1][4]
        local same = true
        for _, wing in ipairs(wings) do
          same = same and wing[4] == players
        end
        Add(same and KindText(inst, players) or (inst.kind == "raid" and "Raid" or "Dungeon"), nil, theme.muted)
        for _, wing in ipairs(wings) do
          local label = wing[1] or inst.name
          if not same then
            label = ("%s (%d)"):format(label, wing[4])
          end
          Add("  " .. label, M.LevelText(wing[2], wing[3]))
        end
      end
      if item.zone then
        Add(M.ZoneName(item.zone), nil, theme.muted)
      end
      if inst.note then
        Add(inst.note, nil, theme.muted)
      end
    end
  elseif pin.spot then
    local spot = pin.spot
    Add(M.ServiceTitle(spot), nil, theme.bright)
    for _, id in ipairs(spot.ids) do
      local npc = ns.MAP_NPC_NAMES and ns.MAP_NPC_NAMES[id]
      if npc then
        Add(npc[1], npc[2], theme.text)
      end
    end
  end
  return lines
end

local function Enter(pin)
  local tip = _G.GameTooltip
  if not (tip and pin.data) then
    return
  end
  tip:SetOwner(pin, "ANCHOR_RIGHT")
  for index, line in ipairs(M.TooltipLines(pin.data)) do
    local c = line[3]
    if index == 1 then
      tip:SetText(line[1], c[1], c[2], c[3])
    elseif line[2] then
      local m = Theme().muted
      tip:AddDoubleLine(line[1], line[2], c[1], c[2], c[3], m[1], m[2], m[3])
    else
      tip:AddLine(line[1], c[1], c[2], c[3], true)
    end
  end
  tip:Show()
end

local function Leave()
  local tip = _G.GameTooltip
  if tip and tip.Hide then
    tip:Hide()
  end
end

-- Pins -------------------------------------------------------------------------------------------------------------------

M.host = { name = "WorldMapFrame", pins = {}, used = 0, points = {} }

local function Map()
  local map = _G[M.host.name]
  return type(map) == "table" and map or nil
end

local function Canvas(map)
  local canvas = Ask(map.GetCanvas, map)
  if type(canvas) ~= "table" then
    canvas = type(map.ScrollContainer) == "table" and map.ScrollContainer.Child or nil
  end
  return type(canvas) == "table" and canvas or nil
end

local function SetCell(texture, index)
  local col, row = index % COLS, math.floor(index / COLS)
  texture:SetTexture(ART)
  texture:SetTexCoord(col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS)
end
M.SetCell = SetCell

local function Color(token, theme)
  local c = theme[token]
  if type(c) ~= "table" then
    c = token == "money" and (theme.warn or theme.accent) or theme.text
  end
  return c
end

local function ClassColor(token)
  local c = C_ClassColor and Ask(C_ClassColor.GetClassColor, token)
  if type(c) == "table" and Num(c.r) then
    return { c.r, c.g, c.b }
  end
  c = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[token]
  if type(c) == "table" and Num(c.r) then
    return { c.r, c.g, c.b }
  end
  return nil
end

local function Overlay(map)
  local host = M.host
  if host.overlay then
    return host.overlay
  end
  local canvas = Canvas(map)
  if not canvas or InCombat() then
    return nil
  end
  local overlay = CreateFrame("Frame", nil, canvas)
  overlay:SetAllPoints(canvas)
  overlay:EnableMouse(false)
  host.overlay = overlay
  return overlay
end

-- Our frame's level for the map shown: zone maps at the game's dungeon entrance level, continents under Codex's
-- quest pins.
function M.FrameLevel(map, continent)
  local canvas = Canvas(map)
  local base = canvas and Num(Ask(canvas.GetFrameLevel, canvas)) or 0
  if continent then
    return base + M.CONTINENT_LEVELS
  end
  local manager = Ask(map.GetPinFrameLevelsManager, map)
  local level = type(manager) == "table"
    and Num(Ask(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE"))
  return level or (base + 2010)
end

local function NewPin(overlay)
  local holder = CreateFrame("Frame", nil, overlay)
  holder:SetSize(1, 1)
  local pin = CreateFrame("Frame", nil, holder)
  pin:SetPoint("CENTER", holder, "CENTER")
  local disc = pin:CreateTexture(nil, "BACKGROUND")
  disc:SetAllPoints(pin)
  SetCell(disc, ICON.disc)
  local ring = pin:CreateTexture(nil, "BORDER")
  ring:SetAllPoints(pin)
  SetCell(ring, ICON.ring)
  local icon = pin:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", pin, "TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -2, 2)
  local hover = pin:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(pin)
  SetCell(hover, ICON.disc)
  hover:SetVertexColor(1, 1, 1, 0.18)
  -- hover only: clicks, drags and the wheel go through to the map and the pins under it
  pin:EnableMouse(true)
  if pin.SetMouseClickEnabled then
    pin:SetMouseClickEnabled(false)
  end
  if pin.SetMouseMotionEnabled then
    pin:SetMouseMotionEnabled(true)
  end
  pin:SetScript("OnEnter", Enter)
  pin:SetScript("OnLeave", Leave)
  local entry = { holder = holder, pin = pin, disc = disc, ring = ring, icon = icon }
  M.host.pins[#M.host.pins + 1] = entry
  return entry
end

local function Paint(entry, point)
  local theme = Theme()
  local fill = theme.hud and theme.hud.fill or theme.panel and theme.panel.from or { 0.08, 0.08, 0.1 }
  entry.disc:SetVertexColor(fill[1], fill[2], fill[3], 0.92)
  local index, color, size, ringColor
  if point.list then
    local raid = true
    for _, item in ipairs(point.list) do
      raid = raid and item.inst.kind == "raid"
    end
    index = raid and ICON.raid or ICON.dungeon
    color = raid and Color("bad", theme) or Color("accent", theme)
    ringColor = color
    size = M.SIZE.dungeon
  else
    local spot = point.spot
    local info = M.KINDS[spot.kind] or { "", "text" }
    index = ICON[spot.kind] or ICON.disc
    color = info[2] == "class" and ClassColor(spot.detail) or Color(info[2] == "class" and "text" or info[2], theme)
    ringColor = theme.divider or theme.muted
    size = M.SIZE.service
  end
  SetCell(entry.icon, index)
  entry.icon:SetVertexColor(color[1], color[2], color[3], 1)
  entry.ring:SetVertexColor(ringColor[1], ringColor[2], ringColor[3], 0.9)
  entry.pin:SetSize(size, size)
  entry.size = size
  entry.pin.data = point
  entry.kindIndex = index
end

local function CanvasScale(map)
  local scale = Num(Ask(map.GetCanvasScale, map))
  return scale and scale > 0 and scale or 1
end

-- Canvas positions: pins that would overlap on screen at this zoom are put round their group's middle.
function M.Layout(points, width, height, scale)
  local groups = {}
  for _, point in ipairs(points) do
    local x, y = point.u * width, point.v * height
    local near = (point.size or M.SIZE.service) * M.SPREAD / scale
    local home
    for _, group in ipairs(groups) do
      if math.abs(group.x - x) < near and math.abs(group.y - y) < near then
        home = group
        break
      end
    end
    if home then
      home[#home + 1] = point
      home.x, home.y = home.x + (x - home.x) / #home, home.y + (y - home.y) / #home
    else
      groups[#groups + 1] = { point, x = x, y = y, size = point.size or M.SIZE.service }
    end
  end
  for _, group in ipairs(groups) do
    local n = #group
    if n == 1 then
      group[1].x, group[1].y = group.x, group.y
    else
      local size = group.size
      local radius = math.max(size * 0.55, size * 0.55 / math.sin(math.pi / n)) / scale
      for index, point in ipairs(group) do
        local angle = math.pi / 2 + (index - 1) * 2 * math.pi / n
        point.x, point.y = group.x + radius * math.cos(angle), group.y - radius * math.sin(angle)
      end
    end
  end
end

function M.HideAll()
  local host = M.host
  for _, entry in ipairs(host.pins) do
    entry.holder:Hide()
    entry.pin.data = nil
  end
  host.used = 0
  host.points = {}
end

function M.Rescale()
  local host = M.host
  local map = Map()
  if not (map and host.overlay) then
    return
  end
  local scale = CanvasScale(map)
  local canvas = Canvas(map)
  local width = canvas and Num(Ask(canvas.GetWidth, canvas)) or 0
  local height = canvas and Num(Ask(canvas.GetHeight, canvas)) or 0
  M.Layout(host.points, width, height, scale)
  for index = 1, host.used do
    local entry, point = host.pins[index], host.points[index]
    entry.pin:SetScale(1 / scale)
    entry.holder:ClearAllPoints()
    entry.holder:SetPoint("CENTER", host.overlay, "TOPLEFT", point.x or 0, -(point.y or 0))
  end
end

-- Draws the pins for the map shown (none while off, hidden or on a map without any).
function M.Draw()
  local host = M.host
  local map = Map()
  M.HideAll()
  if not (map and Q.On(KEY) and map:IsShown()) then
    return
  end
  local mapID = Num(Ask(map.GetMapID, map))
  if not mapID then
    return
  end
  local continent = MapType(mapID) == ContinentType()
  local points = {}
  if M.Wanted("dungeons", mapID) then
    for _, point in ipairs(M.InstancePoints(mapID)) do
      point.size = M.SIZE.dungeon
      points[#points + 1] = point
    end
  end
  if not continent then
    for _, point in ipairs(M.ServicePoints(mapID)) do
      point.size = M.SIZE.service
      table.insert(points, 1, point) -- under the dungeon pins
    end
  end
  if #points == 0 then
    return
  end
  local overlay = Overlay(map)
  if not overlay then
    host.waiting = true -- in a fight before the frame exists: after it
    return
  end
  overlay:SetFrameLevel(M.FrameLevel(map, continent))
  local level = overlay:GetFrameLevel()
  local shown = {}
  for index, point in ipairs(points) do
    local entry = host.pins[index]
    if not entry then
      if InCombat() then
        host.waiting = true -- no new frames in a fight; the rest after it
        break
      end
      entry = NewPin(overlay)
    end
    Paint(entry, point)
    entry.holder:SetFrameLevel(level + 1)
    entry.pin:SetFrameLevel(level + 1)
    entry.holder:Show()
    shown[index] = point
    host.used = index
  end
  host.points = shown
  M.Rescale()
end

local function Safe(fn)
  return function()
    local ok, err = pcall(fn)
    if not ok and not M.failed then
      M.failed = true -- one report, not one per refresh
      geterrorhandler()(err)
    end
  end
end

function M.Refresh()
  if M.host.provider then
    Safe(M.Draw)()
  end
  if M.button then
    M.UpdateButton()
  end
end

local function NewProvider()
  local provider
  if type(CreateFromMixins) == "function" and type(MapCanvasDataProviderMixin) == "table" then
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
  else
    provider = {}
    function provider:OnAdded(map) self.owningMap = map end
    function provider:OnRemoved() self.owningMap = nil end
    function provider:GetMap() return self.owningMap end
  end
  provider.codexMapExtras = true
  provider.RefreshAllData = Safe(M.Draw)
  provider.OnMapChanged = function()
    Safe(M.Draw)()
    M.PlaceSoon()
  end
  provider.RemoveAllData = Safe(M.HideAll)
  provider.OnCanvasScaleChanged = Safe(M.Rescale)
  provider.OnCanvasSizeChanged = Safe(M.Rescale)
  provider.OnShow = function()
    if M.events then
      M.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    M.PlaceSoon()
  end
  provider.OnHide = function()
    if M.events then
      M.events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    M.HideAll()
  end
  return provider
end

-- The filter button on the map's top bar ------------------------------------------------------------------------------

function M.MenuItems()
  local items = { { text = "Map extras", title = true } }
  for _, group in ipairs(M.GROUPS) do
    local who = M.Addon(group.key)
    items[#items + 1] = {
      text = who and ("%s (%s)"):format(group.name, who) or group.name,
      checked = M.Shown(group.key),
      disabled = who and true or nil,
      func = function()
        M.SetGroup(group.key, not M.Shown(group.key))
      end,
    }
  end
  items[#items + 1] = { text = "Trainers", title = true }
  items[#items + 1] = {
    text = "Every class",
    checked = Q.DB()[CLASS_KEY] == "all",
    func = function()
      Q.Set(CLASS_KEY, Q.DB()[CLASS_KEY] == "all" and "mine" or "all")
    end,
  }
  items[#items + 1] = {
    text = "Every profession",
    checked = Q.DB()[PROF_KEY] ~= "mine",
    func = function()
      Q.Set(PROF_KEY, Q.DB()[PROF_KEY] == "mine" and "all" or "mine")
    end,
  }
  return items
end

-- Inside the breadcrumb bar, at its right end, as tall as the crumbs (the bar less BAR_INSET at the top and the
-- bottom, the skin's crumb boxes too). Forever leaves 10 px between the bar and its tracking button
-- (LEFT, NavBar, RIGHT, 10, -2), so beside that button the funnel hung over the bar's edge and 2 px low
-- (2026-11-25). Anchored to the bar, it is on the bar's middle without reading a rect; the size needs the
-- bar's height, read once the map is shown (24 until then).
local BAR_INSET = 3
function M.PlaceButton(map)
  local button = M.button
  local bar = type(map) == "table" and map.NavBar
  if not button or type(bar) ~= "table" or InCombat() then
    return -- no bar: it keeps its place beside the tracking button
  end
  local top, bottom = Num(Ask(bar.GetTop, bar)), Num(Ask(bar.GetBottom, bar))
  local size = top and bottom and math.floor(top - bottom - 2 * BAR_INSET + 0.5) or 24
  size = math.max(18, math.min(32, size))
  if button.placedOn == bar and button.placedSize == size then
    return
  end
  button.placedOn, button.placedSize = bar, size
  button:ClearAllPoints()
  button:SetPoint("RIGHT", bar, "RIGHT", -BAR_INSET, 0)
  button:SetSize(size, size)
  -- above the crumbs (the bar's children) when a long path reaches this far
  local barLevel = Num(Ask(bar.GetFrameLevel, bar))
  if barLevel and barLevel + 5 > (Num(Ask(button.GetFrameLevel, button)) or 0) then
    button:SetFrameLevel(barLevel + 5)
  end
end

-- Now and on the next frame (the map's frames have their rects once it is shown and laid out). The button
-- is first made at login with the map hidden, so it is placed again each time the map opens.
function M.PlaceSoon()
  if not M.button then
    return
  end
  M.PlaceButton(Map())
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      M.PlaceButton(Map())
    end)
  end
end

function M.UpdateButton()
  local button = M.button
  if button then
    button:SetShown(Q.On(KEY) and M.host.provider ~= nil)
    M.PlaceButton(Map())
  end
end

function M.MakeButton(map)
  if M.button or InCombat() then
    return M.button
  end
  local theme = Theme()
  local button = CreateFrame("Button", nil, map)
  button:SetSize(24, 24)
  button:SetFrameStrata("HIGH")
  local anchor = map.WorldMapTrackingOptionsButton
  if type(anchor) == "table" then
    button:SetPoint("RIGHT", anchor, "LEFT", -2, 0) -- M.PlaceButton moves it into the breadcrumb bar
    button:SetFrameLevel((Num(Ask(anchor.GetFrameLevel, anchor)) or 1) + 1)
  else
    local container = Ask(map.GetCanvasContainer, map) or map
    button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -40, -4)
  end
  local fill = theme.hud and theme.hud.fill or theme.panel and theme.panel.from or { 0.08, 0.08, 0.1 }
  local disc = button:CreateTexture(nil, "BACKGROUND")
  disc:SetAllPoints()
  SetCell(disc, ICON.disc)
  disc:SetVertexColor(fill[1], fill[2], fill[3], 0.92)
  local ring = button:CreateTexture(nil, "BORDER")
  ring:SetAllPoints()
  SetCell(ring, ICON.ring)
  local line = theme.accent
  ring:SetVertexColor(line[1], line[2], line[3], 0.9)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 5, -6)
  icon:SetPoint("BOTTOMRIGHT", -5, 4)
  SetCell(icon, ICON.filter)
  icon:SetVertexColor(theme.text[1], theme.text[2], theme.text[3], 1)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  SetCell(hover, ICON.disc)
  hover:SetVertexColor(1, 1, 1, 0.15)
  button.icon = icon
  button:SetScript("OnClick", function(self)
    ns.UI.ShowMenu(self, M.MenuItems())
  end)
  button:SetScript("OnEnter", function(self)
    local tip = _G.GameTooltip
    if tip then
      local t = Theme()
      tip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
      tip:SetText("Map extras", t.bright[1], t.bright[2], t.bright[3])
      tip:AddLine("Pick what the map shows: dungeons, innkeepers, flight masters, banks...", t.text[1], t.text[2],
        t.text[3], true)
      tip:Show()
    end
  end)
  button:SetScript("OnLeave", Leave)
  M.button = button
  return button
end

-- Start / stop ----------------------------------------------------------------------------------------------------------

function M.Attach()
  local host = M.host
  if host.provider then
    return true
  end
  local map = Map()
  if not (map and type(map.AddDataProvider) == "function") then
    return false
  end
  if not M.events then
    M.events = CreateFrame("Frame")
    M.events:SetScript("OnEvent", function()
      if M.host.waiting then
        M.host.waiting = nil
        M.Refresh()
      end
    end)
  end
  local provider = NewProvider()
  if not pcall(map.AddDataProvider, map, provider) then
    return false
  end
  host.provider = provider
  M.MakeButton(map)
  M.UpdateButton()
  if map:IsShown() then
    provider.OnShow()
    Safe(M.Draw)()
  end
  return true
end

function M.Detach()
  local host = M.host
  local map = Map()
  local provider = host.provider
  host.provider = nil
  if provider and map and type(map.RemoveDataProvider) == "function" then
    pcall(map.RemoveDataProvider, map, provider)
  end
  if provider then
    provider.OnHide()
  end
  M.HideAll()
  M.UpdateButton()
end

function M.Start()
  M.started = true
  if M.Attach() then
    return
  end
  if not M.loader then
    M.loader = CreateFrame("Frame")
    M.loader:SetScript("OnEvent", function(self)
      if M.started and M.Attach() then
        self:UnregisterEvent("ADDON_LOADED")
      end
    end)
  end
  M.loader:RegisterEvent("ADDON_LOADED")
end

function M.Stop()
  M.started = false
  if M.loader then
    M.loader:UnregisterEvent("ADDON_LOADED")
  end
  M.Detach()
end

function M.Enable()
  if Q.DB()[KEY] then
    M.Start()
  end
end

function M.Changed(on)
  if on then
    M.Start()
  else
    M.Stop()
  end
end

-- The page: the groups as a grid of checks, the trainer pickers, the note about other addons --------------------------

local COLUMN = 220

local function BuildGrid(body, last, sub)
  local UI = ns.UI
  local rows = math.ceil(#M.GROUPS / 3)
  local holder = CreateFrame("Frame", nil, body)
  holder:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  holder:SetPoint("RIGHT", 0, 0)
  holder:SetHeight(rows * 24)
  sub.holder = holder
  sub.checks = {}
  for index, group in ipairs(M.GROUPS) do
    local check = UI.Check(holder, group.name)
    local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
    check:SetPoint("TOPLEFT", holder, "TOPLEFT", col * COLUMN, -row * 24)
    check:SetHitRectInsets(0, -(COLUMN - 30), 0, 0)
    check:SetScript("OnClick", function(self)
      M.SetGroup(group.key, self:GetChecked())
    end)
    check.group = group.key
    sub.checks[#sub.checks + 1] = check
  end
  return holder
end

local function RefreshGrid(sub, on)
  for _, check in ipairs(sub.checks or {}) do
    check:SetChecked(M.Shown(check.group))
    check:SetEnabled(on)
    check:SetAlpha(on and 1 or 0.5)
  end
end

local function BuildNote(body, last, sub)
  local text = ns.UI.Text(body, "body", 11, "muted")
  text:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", 0, 0)
  text:SetJustifyH("LEFT")
  sub.note = text
  return text
end

local function RefreshNote(sub)
  if sub.note then
    sub.note:SetText(M.NoteText())
  end
end

local function Defaults()
  local out = {}
  for _, group in ipairs(M.GROUPS) do
    out[group.key] = group.default
  end
  return out
end

Q.AddToggle({
  key = KEY,
  name = "Dungeons and town services on the map",
  desc = "Dungeon and raid entrances on zone and continent maps (hover one for its level range and size), and "
    .. "the services of your faction on zone maps. The funnel button at the top of the world map picks what shows.",
  order = 47,
  Enable = M.Enable,
  Changed = M.Changed,
  options = {
    { key = SHOW_KEY, kind = "custom", default = Defaults(), Build = BuildGrid, Refresh = RefreshGrid },
    {
      key = CLASS_KEY,
      kind = "choice",
      name = "Class trainers",
      default = "mine",
      choices = { { "mine", "Your class" }, { "all", "Every class" } },
      Changed = function()
        M.Refresh()
      end,
      Disabled = function()
        return not M.Shown("classTrainers") and "Class trainers are not shown." or nil
      end,
    },
    {
      key = PROF_KEY,
      kind = "choice",
      name = "Profession trainers",
      default = "all",
      choices = { { "all", "Every profession" }, { "mine", "Your professions" } },
      Changed = function()
        M.Refresh()
      end,
      Disabled = function()
        return not M.Shown("profTrainers") and "Profession trainers are not shown." or nil
      end,
    },
    { key = NOTE_KEY, kind = "custom", Build = BuildNote, Refresh = RefreshNote },
  },
})
