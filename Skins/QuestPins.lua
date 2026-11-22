local addonName, ns = ...
local S = ns.S

-- Quest pins on the continent and world maps, and on the flight map (FlightMapFrame, Blizzard_FlightMap: the
-- same kind of map canvas, a continent). The classic TaxiFrame has no map coordinates we could convert
-- reliably, so it gets none. Blizzard's quest pins show only on a zone's own map; zoomed
-- out there are none. Here, while the map shown is a continent or the world (C_Map.GetMapInfo(mapID).mapType
-- <= Enum.UIMapType.Continent), every quest of your log on any zone of that map (C_QuestLog.GetQuestsOnMap on
-- each zone child, C_Map.GetMapChildrenInfo) gets a small pin of ours, its zone position translated into the
-- shown map through C_Map.GetMapRectOnMap. Zone maps keep Blizzard's own pins and get none of ours.
--
-- The pins are frames of ours on the map canvas (WorldMapFrame.ScrollContainer.Child): a holder at the
-- position (unscaled, so the anchor offsets are in canvas units) and the pin itself scaled against the
-- canvas zoom so it stays PIN px on screen. A pin is the game's own quest marker art, so it reads as a
-- quest at a glance (the user found plain discs ugly, 2026-11-18): a yellow "?" for a quest ready to turn in,
-- the in-progress quest marker otherwise (atlases checked with C_Texture.GetAtlasInfo, the gossip window's
-- quest icons when the client has none of them), on a soft shadow. Tracked quests get the thin double-line
-- ring (Buff Tracker's) in the accent, the selected / super-tracked quest the ring plus a glow, and they sit
-- on top. Pins closer than one pin's width on screen are spread round their middle (re-done on zoom), so
-- neighbours never merge into one blob. Tooltip: the quest's title and objectives; a click opens the quest
-- in the log (never in combat: opening the log is refused then). The map's own data-provider API
-- (MapCanvasDataProviderMixin, WorldMapFrame:AddDataProvider; the pattern OpenMap and others use) gives the
-- map-changed / shown / hidden / zoom callbacks; without it the map's OnMapChanged and scripts are hooked.
-- Nothing of Blizzard's is written to; secret values are guarded; a quest without a readable position is
-- skipped; one pin per quest (its first position). Pins are built out of combat only.
--
-- Quests of one zone are one pin (the user's request, 2026-11-20: a zone's quests made a ring of markers): a zone with
-- two or more of your quests gets a cluster pin at their middle with the count on it, the turn-in marker when any
-- of them is ready, the ring / glow when one is tracked / selected; its tooltip lists the zone's quests and a click
-- opens that zone's map (where Blizzard's own pins show each). A zone with one quest keeps that quest's pin.
--
-- On the flight map the pins must never get in the way of choosing a flight: they sit just above the canvas
-- (below the flight-point pins), take no clicks (SetMouseClickEnabled(false): hover only, for the tooltip,
-- with a hit rect inset), and are a little smaller (FLIGHT_PIN).

local PIN, SHADOW, HALO = 20, 30, 30 -- on screen: the marker, its soft shadow, the tracked ring
local FLIGHT_PIN, FLIGHT_HIT = 16, 3 -- the flight map's marker size and its hit rect inset
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local RING = "Interface\\AddOns\\Codex\\Modules\\Buffs\\Media\\Ring"
-- the game's quest markers, first one the client has; then a plain texture of the gossip window
local ART = {
  turnin = { atlases = { "QuestTurnin", "UI-QuestPoi-QuestBangTurnIn", "QuestActiveIcon" },
    texture = "Interface\\GossipFrame\\ActiveQuestIcon" },
  progress = { atlases = { "Quest-In-Progress-Icon-yellow", "QuestIncomplete" },
    texture = "Interface\\GossipFrame\\IncompleteQuestIcon" },
}
local SPREAD = 0.85 -- pins closer than this many pin widths (on screen) are spread apart
local LEVELS = 60 -- our frames this far above the world map's canvas child
local FLIGHT_LEVELS = 1 -- on the flight map: just above the canvas, under the flight points
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_REMOVED", "QUEST_ACCEPTED", "QUEST_TURNED_IN" }

local function Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue then
    return not issecretvalue(value)
  end
  if canaccessvalue then
    return canaccessvalue(value) and true or false
  end
  return true
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

-- One host per map: { name, addon, flight, pins (pooled), used, quests, overlay, provider }.
local HOSTS = {
  world = { name = "WorldMapFrame", addon = "Blizzard_WorldMap", pins = {}, used = 0 },
  flight = { name = "FlightMapFrame", addon = "Blizzard_FlightMap", flight = true, pins = {}, used = 0 },
}

local function Map(host)
  return S.Get(host.name)
end

local function Canvas(host)
  return S.Get(host.name .. ".ScrollContainer.Child")
end

local function PinSize(host)
  return host.flight and FLIGHT_PIN or PIN
end

-- The map shown, when it is a continent or the world; nil on a zone (or when unreadable).
local function WideMapID(host)
  local map = Map(host)
  if not S.Usable(map) or type(map.GetMapID) ~= "function" or not C_Map or not C_Map.GetMapInfo then
    return nil
  end
  local ok, mapID = pcall(map.GetMapID, map)
  mapID = ok and Num(mapID)
  if not mapID then
    return nil
  end
  local info = C_Map.GetMapInfo(mapID)
  local kind = type(info) == "table" and Num(info.mapType)
  local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
  if kind and kind <= continent then
    return mapID
  end
end

-- The zone a spot of the wide map `mapID` (u, v: its coords) lies in: the game's own C_Map.GetMapInfoAtPosition,
-- walked up from a cave or dungeon map to its zone; nil over the sea or between zones. A zone's GetQuestsOnMap also
-- lists quests whose spot is in a neighbouring zone (Ashenvale lists a Felwood quest), so the zone that listed a quest
-- isn't where it is: the user's report, 2026-11-22, a cluster of two zones' quests sitting between them.
local function ZoneAt(mapID, u, v)
  if not C_Map.GetMapInfoAtPosition then
    return nil
  end
  local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
  local ok, info = pcall(C_Map.GetMapInfoAtPosition, mapID, u, v)
  for _ = 1, 4 do
    if not (ok and type(info) == "table") then
      return nil
    end
    local id, kind = Num(info.mapID), Num(info.mapType)
    if not (id and kind) or id == mapID or kind < zoneType then
      return nil
    end
    if kind == zoneType then
      return id, Readable(info.name) and type(info.name) == "string" and info.name or nil
    end
    local parent = Num(info.parentMapID)
    if not parent then
      return nil
    end
    ok, info = pcall(C_Map.GetMapInfo, parent)
  end
  return nil
end
S.QuestZoneAt = ZoneAt

-- Every quest of the log on the zones of `mapID`: { questID, u, v, complete } in the shown map's coords.
local function Quests(mapID)
  local list, seen = {}, {}
  local zone = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
  if not (C_Map.GetMapChildrenInfo and C_Map.GetMapRectOnMap and C_QuestLog and C_QuestLog.GetQuestsOnMap) then
    return list
  end
  for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, zone, true) or {}) do
    local childID = type(child) == "table" and Num(child.mapID)
    local zoneName = type(child) == "table" and Readable(child.name) and type(child.name) == "string" and child.name
      or nil
    local ok, left, right, top, bottom = false, nil, nil, nil, nil
    if childID then
      ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, childID, mapID)
    end
    left, right, top, bottom = Num(left), Num(right), Num(top), Num(bottom)
    if ok and left and right and top and bottom then
      local quests = C_QuestLog.GetQuestsOnMap(childID)
      for _, quest in ipairs(type(quests) == "table" and quests or {}) do
        local questID = type(quest) == "table" and Num(quest.questID)
        local x, y = quest and Num(quest.x), quest and Num(quest.y)
        local indicator = quest and Readable(quest.isMapIndicatorQuest) and quest.isMapIndicatorQuest
        if questID and x and y and not indicator and not seen[questID] then
          seen[questID] = true
          local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
          if not Readable(complete) then
            complete = false
          end
          local u, v = left + x * (right - left), top + y * (bottom - top)
          local atZone, atName = ZoneAt(mapID, u, v)
          list[#list + 1] = { questID = questID, u = u, v = v, complete = complete and true or false,
            zone = atZone or childID, zoneName = atZone and (atName or zoneName) or zoneName }
        end
      end
    end
  end
  return list
end

-- One entry per zone with two or more quests (the cluster), the others as they are.
local function Clusters(quests)
  local byZone, order = {}, {}
  for _, quest in ipairs(quests) do
    local key = quest.zone or ("q" .. quest.questID)
    local group = byZone[key]
    if not group then
      group = {}
      byZone[key] = group
      order[#order + 1] = key
    end
    group[#group + 1] = quest
  end
  local out = {}
  for _, key in ipairs(order) do
    local group = byZone[key]
    if #group == 1 or not group[1].zone then
      for _, quest in ipairs(group) do
        out[#out + 1] = quest
      end
    else
      local cluster = { cluster = true, quests = group, zone = group[1].zone, zoneName = group[1].zoneName,
        u = 0, v = 0, questID = nil, complete = false, ready = 0 }
      for _, quest in ipairs(group) do
        cluster.u, cluster.v = cluster.u + quest.u / #group, cluster.v + quest.v / #group
        if quest.complete then
          cluster.complete, cluster.ready = true, cluster.ready + 1
        end
        cluster.tracked = cluster.tracked or quest.tracked
        cluster.focus = cluster.focus or quest.focus
      end
      out[#out + 1] = cluster
    end
  end
  return out
end

local function Title(questID)
  local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
  return Readable(title) and type(title) == "string" and title or "Quest"
end

-- A cluster's tooltip: the zone, its quests (the ready ones marked), what a click does.
local function EnterCluster(pin)
  local cluster = pin.cluster
  local theme = S.Theme()
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:SetText(cluster.zoneName or "Quests", S.UI.Unpack(theme.bright))
  GameTooltip:AddLine(("%d quests%s"):format(#cluster.quests, cluster.ready > 0 and (", %d ready"):format(cluster.ready)
    or ""), S.UI.Unpack(theme.muted))
  for _, quest in ipairs(cluster.quests) do
    local c = quest.complete and theme.good or theme.text
    GameTooltip:AddLine(Title(quest.questID) .. (quest.complete and " (ready)" or ""), c[1], c[2], c[3])
  end
  if not pin.flight then
    GameTooltip:AddLine("Click to open the zone's map.", S.UI.Unpack(theme.muted))
  end
  GameTooltip:Show()
end

-- Tooltip: the quest's title and objectives.
local function Enter(pin)
  if pin.cluster and GameTooltip and C_QuestLog then
    return EnterCluster(pin)
  end
  local questID = pin.questID
  if not questID or not GameTooltip or not C_QuestLog then
    return
  end
  local theme = S.Theme()
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
  GameTooltip:SetText(Readable(title) and type(title) == "string" and title or "Quest", S.UI.Unpack(theme.bright))
  if pin.complete then
    GameTooltip:AddLine("Ready for turn-in", S.UI.Unpack(theme.good))
  else
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
    for _, objective in ipairs(type(objectives) == "table" and objectives or {}) do
      local text = type(objective) == "table" and objective.text
      if Readable(text) and type(text) == "string" and text ~= "" then
        local done = Readable(objective.finished) and objective.finished
        local c = done and theme.good or theme.text
        GameTooltip:AddLine(text, c[1], c[2], c[3])
      end
    end
  end
  GameTooltip:Show()
end

local function Leave()
  if GameTooltip and GameTooltip.Hide then
    GameTooltip:Hide()
  end
end

-- Opens the quest in the log (refused in combat: nothing then). Never on the flight map (no clicks there).
local function Click(pin)
  if pin.cluster and not pin.flight then
    -- the zone's own map: Blizzard's pins there show each quest
    local map = WorldMapFrame
    if map and type(map.SetMapID) == "function" and pin.cluster.zone then
      pcall(map.SetMapID, map, pin.cluster.zone)
    end
    return
  end
  local questID = pin.questID
  if not questID or S.InCombat() or pin.flight then
    return
  end
  if type(QuestMapFrame_OpenToQuestDetails) == "function" then
    pcall(QuestMapFrame_OpenToQuestDetails, questID)
    return
  end
  if C_QuestLog and C_QuestLog.SetSelectedQuest then
    pcall(C_QuestLog.SetSelectedQuest, questID)
  end
  if type(QuestMapFrame_ShowQuestDetails) == "function" then
    pcall(QuestMapFrame_ShowQuestDetails, questID)
  end
end

local function Overlay(host)
  if host.overlay then
    return host.overlay
  end
  local canvas = Canvas(host)
  if not S.Usable(canvas) or S.InCombat() then
    return nil
  end
  local overlay = CreateFrame("Frame", nil, canvas)
  overlay:SetAllPoints(canvas)
  local ok, level = pcall(canvas.GetFrameLevel, canvas)
  overlay:SetFrameLevel((ok and Num(level) or 0) + (host.flight and FLIGHT_LEVELS or LEVELS))
  overlay:EnableMouse(false)
  host.overlay = overlay
  return overlay
end

-- The art for a kind: { atlas = name } or { texture = path }, looked up once.
local artCache = {}
local function ArtOf(kind)
  if artCache[kind] then
    return artCache[kind]
  end
  local def = ART[kind]
  local found = { texture = def.texture }
  if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
    for _, name in ipairs(def.atlases) do
      local ok, info = pcall(C_Texture.GetAtlasInfo, name)
      if ok and type(info) == "table" then
        found = { atlas = name }
        break
      end
    end
  end
  artCache[kind] = found
  return found
end

local function SetArt(entry, kind)
  if entry.kind == kind then
    return
  end
  entry.kind = kind
  local art = ArtOf(kind)
  if art.atlas and entry.icon.SetAtlas then
    entry.icon:SetAtlas(art.atlas)
  else
    entry.icon:SetTexture(art.texture)
  end
  entry.art = art.atlas or art.texture
end

local function NewPin(host, overlay)
  local theme = S.Theme()
  local size = PinSize(host)
  local grow = size / PIN
  local holder = CreateFrame("Frame", nil, overlay)
  holder:SetSize(1, 1)
  holder:SetFrameLevel(overlay:GetFrameLevel() + 1)
  local pin = CreateFrame("Button", nil, holder)
  pin:SetSize(size, size)
  pin:SetPoint("CENTER", holder, "CENTER")
  pin:SetFrameLevel(holder:GetFrameLevel() + 1)
  -- soft shadow: lifts the marker off the bright map art
  local shadow = pin:CreateTexture(nil, "BACKGROUND", nil, -8)
  shadow:SetTexture(CIRCLE)
  shadow:SetSize(SHADOW * grow, SHADOW * grow)
  shadow:SetPoint("CENTER", 0, -1)
  shadow:SetVertexColor(0, 0, 0, 0.45)
  -- the selected quest's glow and the tracked ring (thin double line, the accent)
  local glow = pin:CreateTexture(nil, "BACKGROUND", nil, -7)
  glow:SetTexture(CIRCLE)
  glow:SetSize(HALO * grow, HALO * grow)
  glow:SetPoint("CENTER")
  glow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.35)
  glow:Hide()
  local ring = pin:CreateTexture(nil, "BORDER")
  ring:SetTexture(RING)
  ring:SetSize((HALO - 4) * grow, (HALO - 4) * grow)
  ring:SetPoint("CENTER")
  ring:SetVertexColor(S.UI.Unpack(theme.accent))
  ring:Hide()
  local icon = pin:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(pin)
  local hover = pin:CreateTexture(nil, "HIGHLIGHT")
  hover:SetTexture(CIRCLE)
  hover:SetSize(size + 4, size + 4)
  hover:SetPoint("CENTER")
  hover:SetVertexColor(1, 1, 1, 0.18)
  pin:SetScript("OnEnter", Enter)
  pin:SetScript("OnLeave", Leave)
  if host.flight then
    -- hover only: clicks go through to the flight points and the map
    pin.flight = true
    if pin.SetMouseClickEnabled then
      pin:SetMouseClickEnabled(false)
    end
    if pin.SetHitRectInsets then
      pin:SetHitRectInsets(FLIGHT_HIT, FLIGHT_HIT, FLIGHT_HIT, FLIGHT_HIT)
    end
  else
    pin:SetScript("OnClick", Click)
  end
  -- a cluster's quest count, on its lower right
  local count = pin:CreateFontString(nil, "OVERLAY")
  S.UI.Font(count, "body", math.max(10, math.floor(11 * grow + 0.5)), "bright")
  count:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 3, -2)
  if count.SetShadowOffset then
    count:SetShadowOffset(1, -1)
    count:SetShadowColor(0, 0, 0, 1)
  end
  count:Hide()
  local entry = { holder = holder, pin = pin, icon = icon, ring = ring, glow = glow, shadow = shadow, count = count }
  host.pins[#host.pins + 1] = entry
  return entry
end

local function CanvasScale(host)
  local map = Map(host)
  if S.Usable(map) and type(map.GetCanvasScale) == "function" then
    local ok, scale = pcall(map.GetCanvasScale, map)
    scale = ok and Num(scale)
    if scale and scale > 0 then
      return scale
    end
  end
  return 1
end

-- Tracked (watched) and selected / super-tracked quests: read once per refresh, secrets ignored.
local function Watched(questID)
  local log = C_QuestLog
  if log and type(log.GetQuestWatchType) == "function" then
    local ok, kind = pcall(log.GetQuestWatchType, questID)
    return ok and Readable(kind) and kind ~= nil
  end
  if log and type(log.IsQuestWatched) == "function" then
    local ok, on = pcall(log.IsQuestWatched, questID)
    return ok and Readable(on) and on and true or false
  end
  return false
end

local function Focused()
  local id
  if C_SuperTrack and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
    local ok, value = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    id = ok and Num(value)
  end
  if (not id or id == 0) and C_QuestLog and type(C_QuestLog.GetSelectedQuest) == "function" then
    local ok, value = pcall(C_QuestLog.GetSelectedQuest)
    id = ok and Num(value)
  end
  return id
end

-- Canvas positions for the shown quests: pins whose markers would overlap on screen at this zoom are put
-- round their group's middle, evenly spaced, so each stays clickable.
local function Layout(host, quests, scale)
  local PIN = PinSize(host)
  local canvas = Canvas(host)
  local width, height = canvas and Num(canvas:GetWidth()) or 0, canvas and Num(canvas:GetHeight()) or 0
  local near = PIN * SPREAD / scale -- canvas units
  local groups = {}
  for _, quest in ipairs(quests) do
    local x, y = quest.u * width, quest.v * height
    quest.x, quest.y = x, y
    local home
    for _, group in ipairs(groups) do
      if math.abs(group.x - x) < near and math.abs(group.y - y) < near then
        home = group
        break
      end
    end
    if home then
      home[#home + 1] = quest
      local n = #home
      home.x, home.y = home.x + (x - home.x) / n, home.y + (y - home.y) / n
    else
      groups[#groups + 1] = { quest, x = x, y = y }
    end
  end
  for _, group in ipairs(groups) do
    local n = #group
    if n == 1 then
      group[1].x, group[1].y = group.x, group.y
    else
      -- on a circle whose chord between neighbours is one pin wide (at least half a pin from the middle)
      local radius = math.max(PIN * 0.55, PIN * 0.55 / math.sin(math.pi / n)) / scale
      for index, quest in ipairs(group) do
        local angle = math.pi / 2 + (index - 1) * 2 * math.pi / n
        quest.x, quest.y = group.x + radius * math.cos(angle), group.y - radius * math.sin(angle)
      end
    end
  end
end

local function Place(entry, overlay, quest)
  entry.holder:ClearAllPoints()
  entry.holder:SetPoint("CENTER", overlay, "TOPLEFT", quest.x or 0, -(quest.y or 0))
end

-- Pins the same size on screen whatever the zoom, and spread for this zoom.
local function Rescale(host)
  local scale = CanvasScale(host)
  if host.quests and host.overlay then
    Layout(host, host.quests, scale)
  end
  for index = 1, host.used do
    local entry = host.pins[index]
    entry.pin:SetScale(1 / scale)
    local quest = host.quests and host.quests[index]
    if quest and host.overlay then
      Place(entry, host.overlay, quest)
    end
  end
end

local function HideAll(host)
  for _, entry in ipairs(host.pins) do
    entry.holder:Hide()
  end
  host.used = 0
end

-- The pins for the map shown now (none on a zone map, or while the map is hidden).
local function Refresh(host)
  local map = Map(host)
  if not S.Usable(map) or not map:IsShown() then
    HideAll(host)
    return
  end
  local mapID = WideMapID(host)
  if not mapID then
    HideAll(host)
    return
  end
  local overlay = Overlay(host)
  if not overlay then
    return -- in combat before the overlay exists: nothing yet
  end
  local quests = Quests(mapID)
  local focus = Focused()
  for _, quest in ipairs(quests) do
    quest.focus = quest.questID == focus
    quest.tracked = quest.focus or Watched(quest.questID)
  end
  quests = Clusters(quests)
  -- tracked quests last, so their pins sit on top of their neighbours
  table.sort(quests, function(a, b)
    local ra, rb = (a.focus and 2 or a.tracked and 1 or 0), (b.focus and 2 or b.tracked and 1 or 0)
    if ra ~= rb then
      return ra < rb
    end
    return (a.questID or a.zone or 0) < (b.questID or b.zone or 0)
  end)
  HideAll(host)
  local shown = {}
  for index, quest in ipairs(quests) do
    local entry = host.pins[index]
    if not entry then
      if S.InCombat() then
        break -- no new frames in a fight; the rest after it
      end
      entry = NewPin(host, overlay)
    end
    entry.pin.questID, entry.pin.complete = quest.questID, quest.complete
    entry.pin.cluster = quest.cluster and quest or nil
    entry.count:SetText(quest.cluster and tostring(#quest.quests) or "")
    entry.count:SetShown(quest.cluster and true or false)
    SetArt(entry, quest.complete and "turnin" or "progress")
    entry.ring:SetShown(quest.tracked)
    entry.glow:SetShown(quest.focus)
    entry.pin:SetFrameLevel(entry.holder:GetFrameLevel() + 1 + index)
    entry.holder:Show()
    shown[index] = quest
    host.used = index
  end
  host.quests = shown
  Rescale(host)
end

local function Setup(host)
  local map = Map(host)
  if not S.Usable(map) or not S.Once(map, "questpins") then
    return
  end
  local part = S.part
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function()
    S.Run(part, Refresh, host)
  end)
  local function Watch(on)
    for _, event in ipairs(EVENTS) do
      pcall(on and events.RegisterEvent or events.UnregisterEvent, events, event)
    end
  end
  local provider
  if type(CreateFromMixins) == "function" and type(MapCanvasDataProviderMixin) == "table" then
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
  else
    provider = {}
  end
  provider.RefreshAllData = function()
    S.Run(part, Refresh, host)
  end
  provider.OnMapChanged = function()
    S.Run(part, Refresh, host)
  end
  provider.OnShow = function()
    Watch(true)
    S.Run(part, Refresh, host)
  end
  provider.OnHide = function()
    Watch(false)
    S.Run(part, HideAll, host)
  end
  provider.OnCanvasScaleChanged = function()
    S.Run(part, Rescale, host)
  end
  provider.OnCanvasSizeChanged = function()
    S.Run(part, Rescale, host)
  end
  if type(map.AddDataProvider) == "function" and pcall(map.AddDataProvider, map, provider) then
    host.provider = provider
  else
    S.HookMethod(map, "OnMapChanged", function()
      Refresh(host)
    end)
    S.HookScript(map, "OnShow", provider.OnShow)
    S.HookScript(map, "OnHide", provider.OnHide)
  end
  local overlay = Overlay(host)
  if overlay then
    overlay:SetScript("OnSizeChanged", function()
      S.Run(part, Rescale, host)
    end)
  end
  if map:IsShown() then
    provider.OnShow()
  end
end

S.Part("questpins", function()
  -- each map when its addon loads (now when it already has)
  for _, key in ipairs({ "world", "flight" }) do
    local host = HOSTS[key]
    S.OnAddOn(host.addon, function()
      Setup(host)
    end)
  end
end)

-- for tests
ns.questPins = HOSTS.world
ns.questPinsFlight = HOSTS.flight
