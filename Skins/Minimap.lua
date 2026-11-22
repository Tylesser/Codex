local addonName, ns = ...
local S = ns.S

-- Minimap: the round map gets the board's ring (a solid band in the theme's line colour with a dark edge:
-- gold for Runestone, brass for Hearthwood, silver for Classic, a thin slate line for Slate), drawn as
-- discs of our own just under the map, so the map covers their middle and only the ring shows. Forever's
-- round frame art is emptied (it puts it back on config changes, so that is hooked). The zone button keeps
-- its place and its mouse, but shows a HUD plate sized to "Zone · 52, 41" (13 px, the theme's body font where
-- it has one, accent colour) instead of Forever's header art. The day / night badge gets a small round HUD
-- badge behind it; the other small buttons (tracking, calendar, mail, addon drawer) stay bare. Nothing is
-- moved, except the tracking and calendar buttons while Codex's info bar shows (see "Info bar" below); the
-- minimap isn't protected on Forever, so none of this has to wait for a fight's end once built.
--
-- Shapes (board R3-Polish, CodexDB.skins.minimapShape; nil = the theme's own: round for Runestone and
-- Hearthwood, square with a header for Classic, square for Slate):
-- * "round": all of the above.
-- * "square": a square mask; the ring becomes a thin square border (the line colour next to the map, the dark
--   edge outside it); the zone line sits on the map's top edge, accent with a shadow, no plate.
-- * "header": square, with a title bar of ours along the map's top (the theme's title band and divider line,
--   the zone line on the left); the border goes round both.
-- Forever puts its round mask back after some settings change: the SetMaskTexture post-hook puts the square
-- one on again. Forever's own buttons (tracking, mail, calendar, clock, zoom) keep the places Forever and Edit
-- Mode give them, for every shape. TylesserCodex.ApplyMinimapShape() switches live (also in combat).

local CODEX = "Interface\\AddOns\\Codex\\"
local RING = CODEX .. "Modules\\Buffs\\Media\\Ring" -- white ring, coloured per theme
local CIRCLE_MASK = "Interface\\AddOns\\Codex\\Media\\Circle" -- smooth 256px circle (TempPortraitAlphaMask looked jagged)
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local HYBRID_ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- the indoor map's mask, if it can't be read
local DOT = " \194\183 " -- " · "
local TICK = 0.5 -- seconds between coordinate updates (only while the plate is shown)
local SHAPES = { round = true, square = true, header = true }
local THEME_SHAPE = { runestone = "round", hearthwood = "round", classic = "header", slate = "square", dusk = "round",
  obsidian = "round", onyx = "round" } -- board miniDefault (the same as Settings.lua ns.MINIMAP_THEME_SHAPE)
local HEADER_HEIGHT = 22

-- Forever's round frame art (and its underlay when the map rotates).
local ROUND_ART = { "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapBackdrop.StaticOverlayTexture" }
-- Small buttons that get a round badge: path, extra size round the button.
-- (The tracking, calendar, mail, crafting order and addon drawer buttons stay bare: the player found the
-- backing discs behind them too heavy.)
local BADGES = { { "MinimapCluster.DielFrame", 1 } }

local ringFrame, zoneLabel, labelTicker
local discs = {} -- the round ring's bands
local square -- the square shapes' pieces: { box, lines, header, headerText, overlay, mapText }
local shape -- the shape on screen; nil until the part has run

-- Values Blizzard may hand out as secret: only plain ones are used.
local function Open(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- A disc of `color` round the map, `out` units past its edge, drawn by `frame` (masked round).
local function Disc(frame, out, color, sublevel)
  local disc = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
  disc:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -out, out)
  disc:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", out, -out)
  S.SetColor(disc, color)
  if frame.CreateMaskTexture and disc.AddMaskTexture then
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(disc)
    disc:AddMaskTexture(mask)
  end
  return disc
end

-- The board's ring (R2-HUD `ring`): a solid band in the theme's line colour with a thin dark band outside,
-- built from the theme's frame rings: the brightest ring colour for the band (gold, brass, silver, slate
-- line), the darkest for the edge (black where the theme has only one ring). 4 + 2 units, 2 + 1 for themes
-- with a single thin ring (Slate).
local function Light(c)
  return c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
end

local function RingBands()
  local rings = S.Theme().rings or {}
  local line = S.LineColor(rings)
  local dark
  for _, ring in ipairs(rings) do
    if ring.color ~= line and (not dark or Light(ring.color) < Light(dark)) then
      dark = ring.color
    end
  end
  dark = dark or { 0, 0, 0 }
  local thin = S.RingDepth(rings) < 3
  local band, edge = thin and 2 or 4, thin and 1 or 2
  return { { out = band + edge, color = { dark[1], dark[2], dark[3], 1 } },
    { out = band, color = { line[1], line[2], line[3], 1 } } }
end

local function LevelRing()
  if ringFrame and Minimap.GetFrameLevel then
    local level = Minimap:GetFrameLevel()
    if Open(level) then
      ringFrame:SetFrameLevel(math.max(0, level - 1))
    end
  end
end

local function BuildRing()
  if ringFrame or not S.Usable(Minimap) then
    return
  end
  -- our own frame under the map (same strata, one level down): the map draws over the discs' middle
  ringFrame = CreateFrame("Frame", nil, Minimap)
  ringFrame:SetAllPoints(Minimap)
  ringFrame:EnableMouse(false)
  LevelRing()
  for index, band in ipairs(RingBands()) do
    discs[#discs + 1] = Disc(ringFrame, band.out, band.color, math.min(7, index - 9))
  end
end

-- Forever's round art: the known names, plus any texture on the map, its backdrop or the cluster whose atlas
-- is a minimap frame or compass (Forever's skin names vary between builds; the mask and the day / night
-- badge's own frame are left alone). Emptied, and emptied again whenever Forever sets it back.
local ART_HOLDERS = { "Minimap", "MinimapBackdrop", "MinimapCluster", "MinimapCluster.MinimapContainer" }
local roundArt = setmetatable({}, { __mode = "k" })

local function IsRoundArt(region)
  if not S.IsRegion(region) or region:GetObjectType() ~= "Texture" then
    return false
  end
  local atlas = region.GetAtlas and region:GetAtlas()
  if type(atlas) == "string" and Open(atlas) then
    atlas = atlas:lower()
    return (atlas:find("minimap%-frame") or atlas:find("compass")) and not atlas:find("mask")
      and not atlas:find("cycle") and true or false
  end
  local file = region.GetTexture and region:GetTexture()
  return type(file) == "string" and Open(file) and file:lower():find("compass") ~= nil or false
end

local function FindArt()
  for _, path in ipairs(ROUND_ART) do
    local art = S.Get(path)
    if S.IsRegion(art) then
      roundArt[art] = true
    end
  end
  for _, path in ipairs(ART_HOLDERS) do
    local holder = S.Get(path)
    if S.Usable(holder) and holder.GetRegions then
      for _, region in ipairs({ holder:GetRegions() }) do
        if IsRoundArt(region) then
          roundArt[region] = true
        end
      end
    end
  end
end

local emptying = false
local function HideArt()
  if emptying then
    return
  end
  emptying = true
  for art in pairs(roundArt) do
    S.Empty(art)
  end
  emptying = false
  LevelRing()
end

local function WatchArt()
  FindArt()
  for art in pairs(roundArt) do
    if S.Once(art, "minimapart") then
      S.HookMethod(art, "SetAtlas", HideArt)
    end
  end
  HideArt()
end

-- A small round HUD badge behind a button: a dark disc and a ring in the theme's line colour, `pad` units
-- past its edge. Textures of the button itself, under its own art.
local function Badge(button, pad)
  if not S.Usable(button) or not S.Once(button, "minimapbadge") or not button.CreateTexture then
    return
  end
  local theme = S.Theme()
  local fill = theme.hud.fill
  local disc = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  disc:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
  disc:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
  S.SetColor(disc, { fill[1], fill[2], fill[3], 0.92 })
  if button.CreateMaskTexture and disc.AddMaskTexture then
    local mask = button:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(disc)
    disc:AddMaskTexture(mask)
  end
  local ring = button:CreateTexture(nil, "BACKGROUND", nil, -7)
  ring:SetAllPoints(disc)
  ring:SetTexture(RING)
  local line = S.LineColor(theme.rings)
  ring:SetVertexColor(line[1], line[2], line[3], 1)
end

-- Zone plate ------------------------------------------------------------------------------------------------

local function ZoneName()
  local name = GetMinimapZoneText and GetMinimapZoneText()
  if type(name) == "string" and Open(name) then
    return name
  end
  local text = S.Get("MinimapZoneText")
  name = text and text.GetText and text:GetText()
  return type(name) == "string" and Open(name) and name or ""
end

-- "52, 41", or nil where the game has no position (instances).
local function Coords()
  local map = C_Map
  if map and map.GetBestMapForUnit and map.GetPlayerMapPosition then
    local mapID = map.GetBestMapForUnit("player")
    local position = Open(mapID) and mapID and map.GetPlayerMapPosition(mapID, "player")
    if type(position) == "table" and position.GetXY then
      local x, y = position:GetXY()
      if Open(x) and Open(y) and type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        return ("%d, %d"):format(math.floor(x * 100), math.floor(y * 100))
      end
    end
    return nil
  end
  -- no map API: Forever's own readout, when it shows one
  local text = S.Region(S.Get("MinimapCluster.MinimapContainer.PlayerCoords"), "CoordText")
  local value = text and text.GetText and text:GetText()
  return type(value) == "string" and Open(value) and value ~= "" and value or nil
end

-- The clock sits at the zone plate's right end on Forever: the label stops short of it.
local function Number(value)
  return type(value) == "number" and Open(value) and value or nil
end

-- How far in from `box`'s right end the label must stop for the clock (8 at least). vertical: only when the
-- clock also reaches into the box's height (the header bar sits under Forever's header row).
local function RightInset(box, vertical)
  local clock = S.Get("TimeManagerClockButton")
  if not clock or not clock.IsShown or not clock:IsShown() or not box.GetRight or not clock.GetLeft then
    return 8
  end
  local left, right = Number(box:GetLeft()), Number(box:GetRight())
  local clockLeft, clockRight = Number(clock:GetLeft()), Number(clock:GetRight())
  if vertical then
    local top, bottom = Number(box:GetTop()), Number(box:GetBottom())
    local clockTop, clockBottom = Number(clock:GetTop()), Number(clock:GetBottom())
    if not (top and bottom and clockTop and clockBottom and clockBottom < top and clockTop > bottom) then
      return 8
    end
  end
  if left and right and clockLeft and clockRight and clockLeft < right and clockRight > left then
    return math.max(8, right - clockLeft + 2)
  end
  return 8
end

-- "Zone · 52, 41" into `text`, at most `room` wide: too long, and the zone name alone (it matters more).
local function Compose(text, room)
  local zone = ZoneName()
  local coords = Coords()
  local value = coords and (zone ~= "" and zone .. DOT .. coords or coords) or zone
  text:SetWidth(0) -- unbounded while measuring
  text:SetText(value)
  if coords and zone ~= "" and (Number(text:GetStringWidth()) or 0) > room then
    text:SetText(zone)
  end
  local width = Number(text:GetStringWidth()) or room
  text:SetWidth(math.max(1, math.min(width + 1, room)))
end

local function MapWidth()
  return Number(Minimap:GetWidth()) or 140
end

-- The plate is sized to its text (R2-HUD: 10 units each side), centred in the room the clock leaves.
local PLATE_PAD = 10
local shownInset
local function UpdateLabel()
  if square and shape == "square" then
    Compose(square.mapText, MapWidth() - 16)
    return
  elseif square and shape == "header" then
    Compose(square.headerText, MapWidth() - 6 - RightInset(square.header, true))
    return
  end
  if not zoneLabel then
    return
  end
  local text, button = zoneLabel.text, zoneLabel.button
  local inset = RightInset(button)
  if inset ~= shownInset then
    shownInset = inset
    text:ClearAllPoints()
    text:SetPoint("CENTER", button, "CENTER", -(inset - 8) / 2, 0)
  end
  -- the plate may reach a little past Forever's narrow zone button: up to the map's width
  local width = math.max(Number(button.GetWidth and button:GetWidth()) or 150, Number(Minimap:GetWidth()) or 0)
  Compose(text, width + 24 - 8 - inset - 2 * PLATE_PAD)
end

-- A zone line: Forever's zone font at `size` (the theme's body font where it has one), a black shadow.
local function NewLabel(parent, size, color, justify)
  local zoneText = S.Get("MinimapZoneText")
  local text = parent:CreateFontString(nil, "OVERLAY")
  local path, flags = "Fonts\\FRIZQT__.TTF", ""
  if S.IsRegion(zoneText) and zoneText.GetFont then
    local zonePath, _, zoneFlags = zoneText:GetFont()
    path = type(zonePath) == "string" and zonePath or path
    flags = type(zoneFlags) == "string" and zoneFlags or flags
  end
  text:SetFont(path, size, flags)
  text:SetJustifyH(justify or "CENTER")
  if text.SetWordWrap then
    text:SetWordWrap(false)
  end
  S.TextShadow(text, 1, -1, 0, 0, 0, 1) -- the theme's (none) on a light theme
  S.Font(text, "body", color)
  return text
end

local function BuildZonePlate()
  if zoneLabel then
    return
  end
  local zoneText = S.Get("MinimapZoneText")
  local button = S.Get("MinimapCluster.ZoneTextButton")
  local host = S.Usable(button) and button or nil
  if not host then
    -- no zone button on this client: our own place under the map, as in the design
    if not S.Usable(Minimap) then
      return
    end
    host = CreateFrame("Frame", nil, Minimap)
    host:SetPoint("TOP", Minimap, "BOTTOM", 0, -10)
    host:SetSize(math.max(150, Minimap:GetWidth() or 150), 20)
    host:EnableMouse(false)
  end
  -- Forever's header art off (the button keeps its mouse and tooltip)
  S.KillKeys(button, "StateTexture", "AddTexture")

  local text = NewLabel(host, 13, "accent") -- R2-HUD: 13 px in the theme's body font, accent
  text:SetPoint("CENTER", host, "CENTER", 0, 0)
  -- the HUD plate round the text: textures of the zone button, under its own children
  local plate = S.Plate(host, "hud", { topLeft = text, bottomRight = text, left = PLATE_PAD, right = PLATE_PAD, top = 3, bottom = 3 })
  zoneLabel = { text = text, button = host, plate = plate }
  -- the zone text and Forever's coordinate line now live on our plate
  S.Kill(zoneText)
  S.Kill(S.Get("MinimapCluster.MinimapContainer.PlayerCoords"))

  -- coordinates: a throttled tick on a frame of ours, which only runs while the plate is shown
  labelTicker = CreateFrame("Frame", nil, host)
  labelTicker:EnableMouse(false)
  local elapsed = 0
  labelTicker:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed >= TICK then
      elapsed = 0
      S.Run("minimap", UpdateLabel)
    end
  end)
  for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    labelTicker:RegisterEvent(event)
  end
  labelTicker:SetScript("OnEvent", function()
    S.Run("minimap", UpdateLabel)
  end)
  S.HookMethod(zoneText, "SetText", UpdateLabel)
end

local function SkinClock()
  local ticker = S.Get("TimeManagerClockTicker")
  if S.IsRegion(ticker) and S.Once(ticker, "minimapclock") then
    S.Font(ticker, "head")
  end
end

-- Square shapes ---------------------------------------------------------------------------------------------

-- The pieces both square shapes use, built once (hidden while round): the border (two 1-unit lines outside
-- a box of ours: the theme's line colour next to the map, the ring's dark edge outside), the header bar and
-- the zone line on the map. All on our own frames; the border and the bar lie outside the map, so they can
-- sit under it with the ring.
local function BuildSquare()
  if square or not ringFrame then
    return
  end
  local theme = S.Theme()
  local bands = RingBands()
  local dark, line = bands[1].color, bands[2].color
  square = { lines = {} }

  local header = CreateFrame("Frame", nil, ringFrame)
  header:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 0)
  header:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 0)
  header:SetHeight(HEADER_HEIGHT)
  header:EnableMouse(false)
  local bar = theme.titlebar or {}
  local band = header:CreateTexture(nil, "BACKGROUND", nil, -8)
  band:SetAllPoints(header)
  if bar.from and bar.to then
    S.UI.Gradient(band, bar.from, bar.to)
  else
    S.SetColor(band, theme.hud.fill)
  end
  local rule = header:CreateTexture(nil, "BORDER")
  rule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  rule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  rule:SetHeight(1)
  S.SetColor(rule, theme.divider or line)
  local headerText = NewLabel(header, 12, "titleText", "LEFT")
  headerText:SetPoint("LEFT", header, "LEFT", 6, 0)
  square.header, square.headerText = header, headerText

  local box = CreateFrame("Frame", nil, ringFrame)
  box:EnableMouse(false)
  square.box = box
  for _, band in ipairs({ { 1, line }, { 2, dark } }) do
    for _, piece in ipairs(S.Outline(ringFrame, box, -band[1], 1, band[2], "BORDER", 1)) do
      square.lines[#square.lines + 1] = piece
    end
  end

  -- the zone line on the map's top edge ("square"): a frame of ours over the map, no mouse
  local overlay = CreateFrame("Frame", nil, Minimap)
  overlay:SetAllPoints(Minimap)
  overlay:EnableMouse(false)
  local mapText = NewLabel(overlay, 12, "accent")
  mapText:SetPoint("TOP", Minimap, "TOP", 0, -4)
  square.overlay, square.mapText = overlay, mapText
end

-- The one global Codex sets besides its saved variables: GetMinimapShape, the convention other addons'
-- minimap buttons (LibDBIcon and the like) read to place themselves on a square map. Set only once the map
-- is square; whatever it replaced comes back when the map goes round again.
local function ShapeName()
  return (shape == "square" or shape == "header") and "SQUARE" or "ROUND"
end
local replacedShape
local function ShapeGlobal()
  if shape ~= "round" then
    if _G.GetMinimapShape ~= ShapeName then
      replacedShape = _G.GetMinimapShape
      _G.GetMinimapShape = ShapeName
    end
  elseif _G.GetMinimapShape == ShapeName then
    _G.GetMinimapShape = replacedShape
    replacedShape = nil
  end
end

-- The map's mask. The last one somebody else set (Forever's round one) is kept to put back.
local maskGuard = false
local roundMask
local function SetMask(texture)
  if type(Minimap.SetMaskTexture) ~= "function" then
    return
  end
  maskGuard = true
  pcall(Minimap.SetMaskTexture, Minimap, texture)
  maskGuard = false
end

local function KeepMask(_, texture)
  if maskGuard then
    return
  end
  if texture ~= nil and Open(texture) and texture ~= SQUARE_MASK then
    roundMask = texture
  end
  if shape and shape ~= "round" then
    SetMask(SQUARE_MASK)
  end
end

-- Quest / dig site areas are drawn with a ring at the round map's edge: off on a square map.
local function BlobRings(scalar)
  for _, method in ipairs({ "SetArchBlobRingScalar", "SetQuestBlobRingScalar", "SetTaskBlobRingScalar" }) do
    if type(Minimap[method]) == "function" then
      pcall(Minimap[method], Minimap, scalar)
    end
  end
end

-- The indoor map (Blizzard_HybridMinimap) has its own round mask: square too. Left alone while it was never
-- made square.
local hybridRound
local function HybridShape()
  local hybrid = S.Get("HybridMinimap")
  local mask, canvas = S.Child(hybrid, "CircleMask"), S.Child(hybrid, "MapCanvas")
  if not S.IsRegion(mask) or not mask.SetTexture or not shape then
    return
  end
  local isSquare = shape ~= "round"
  if not isSquare and hybridRound == nil then
    return
  end
  if hybridRound == nil then
    local file = mask.GetTexture and mask:GetTexture()
    hybridRound = file ~= nil and Open(file) and file or HYBRID_ROUND
  end
  mask:SetTexture(isSquare and SQUARE_MASK or hybridRound, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if S.Usable(canvas) and canvas.SetMaskTexture then
    pcall(canvas.SetMaskTexture, canvas, mask)
  end
end

local function PlateShown(plate, on)
  if not plate then
    return
  end
  local pieces = { plate.fill, plate.tile }
  for _, list in ipairs({ plate.lines or {}, plate.corners or {}, plate.round or {} }) do
    for _, piece in ipairs(list) do
      pieces[#pieces + 1] = piece
    end
  end
  for _, piece in pairs(pieces) do
    piece:SetShown(on)
  end
end

-- The player's shape, else the theme's (a theme may name its own with `minimapShape`).
local function WantedShape()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins or nil
  local value = skins and skins.minimapShape
  if type(value) == "string" and SHAPES[value] then
    return value
  end
  local theme = S.Theme()
  if type(theme.minimapShape) == "string" and SHAPES[theme.minimapShape] then
    return theme.minimapShape
  end
  return THEME_SHAPE[theme.id] or "round"
end


-- Info bar ----------------------------------------------------------------------------------------------------
-- While Codex's info bar shows (it has the zone and the time), the map's top is cleared: our zone line (plate,
-- map line or header bar) and Forever's clock go, and the tracking button and the calendar move onto the ring
-- (round: the top-left of the circle, the calendar just clockwise of it; square: in the top-left corner, side by
-- side). With the bar gone everything returns to the places Forever gives them. Forever re-lays its buttons
-- after config changes: the points it sets are kept (to put back later) and ours go on again a moment after.

local TRACKING_ANGLE, CALENDAR_ANGLE = 135, 113 -- degrees on the ring (0 = right, 90 = top)
local infoBar = false
local placing = false
local moved = setmetatable({}, { __mode = "k" }) -- [Blizzard button] = Forever's points, to put back
local watchedPoints = setmetatable({}, { __mode = "k" })
local clockMouse

local function InfoBarShown()
  local shown = TylesserCodex.InfoBarShown
  return type(shown) == "function" and shown() and true or false
end

local function PointsOf(frame)
  local points = {}
  for index = 1, 8 do
    local a, b, c, d, e = frame:GetPoint(index)
    if a == nil then
      break
    end
    for _, value in pairs({ a, b, c, d, e }) do
      if not Open(value) then
        return nil
      end
    end
    points[#points + 1] = { a, b, c, d, e }
  end
  return points
end

local function SetPoints(frame, points)
  placing = true
  frame:ClearAllPoints()
  for _, p in ipairs(points) do
    frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
  placing = false
end

local function OnRing(frame, angle, index)
  if shape ~= "round" then
    if index == 1 then
      return { { "TOPLEFT", Minimap, "TOPLEFT", 2, -2 } }
    end
    return { { "LEFT", S.Get("MinimapCluster.Tracking"), "RIGHT", 2, 0 } }
  end
  local radius = MapWidth() / 2 + 2
  local rad = math.rad(angle)
  return { { "CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius } }
end

local PlaceButtons -- below
local queued = false
local function QueuePlace()
  if queued then
    return
  end
  queued = true
  C_Timer.After(0, function()
    queued = false
    S.Run("minimap", PlaceButtons)
  end)
end

-- Forever's own placements of a moved button: kept as the ones to put back, ours again after.
local function WatchPoints(frame)
  if watchedPoints[frame] then
    return
  end
  watchedPoints[frame] = true
  S.HookMethod(frame, "ClearAllPoints", function()
    if not placing and moved[frame] then
      moved[frame] = {}
      QueuePlace()
    end
  end)
  S.HookMethod(frame, "SetPoint", function(_, a, b, c, d, e)
    if not placing and moved[frame] then
      table.insert(moved[frame], { a, b, c, d, e })
      QueuePlace()
    end
  end)
end

local function MoveButton(frame, angle, index)
  if not S.Usable(frame) or S.Protected(frame) then
    return
  end
  if infoBar then
    if not moved[frame] then
      local points = PointsOf(frame)
      if not points then
        return -- secret or unreadable points: left where it is
      end
      moved[frame] = points
      WatchPoints(frame)
    end
    SetPoints(frame, OnRing(frame, angle, index))
  elseif moved[frame] then
    local points = moved[frame]
    moved[frame] = nil
    if #points > 0 then
      SetPoints(frame, points)
    end
  end
end

PlaceButtons = function()
  MoveButton(S.Get("MinimapCluster.Tracking"), TRACKING_ANGLE, 1)
  MoveButton(S.Get("GameTimeFrame"), CALENDAR_ANGLE, 2)
end

-- Forever's clock: invisible and click-through while the bar shows (it has the time), back after.
local function ClockShown()
  local clock = S.Get("TimeManagerClockButton")
  if not S.Usable(clock) or S.Protected(clock) then
    return
  end
  if infoBar then
    if clockMouse == nil then
      clockMouse = not clock.IsMouseEnabled or clock:IsMouseEnabled() and true or false
    end
    clock:SetAlpha(0)
    if clock.EnableMouse then
      clock:EnableMouse(false)
    end
  elseif clockMouse ~= nil then
    clock:SetAlpha(1)
    if clock.EnableMouse then
      clock:EnableMouse(clockMouse)
    end
    clockMouse = nil
  end
end

local function WatchClock()
  local clock = S.Get("TimeManagerClockButton")
  if S.Usable(clock) and S.Once(clock, "minimapclockbar") then
    S.HookScript(clock, "OnShow", ClockShown)
  end
  ClockShown()
end

-- Which of our zone pieces show, for the shape and the info bar.
local function Layout()
  local isSquare = shape ~= "round"
  local header = shape == "header" and not infoBar
  if square then
    square.box:ClearAllPoints()
    square.box:SetPoint("TOPLEFT", header and square.header or Minimap, "TOPLEFT", 0, 0)
    square.box:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
    for _, piece in ipairs(square.lines) do
      piece:SetShown(isSquare)
    end
    square.header:SetShown(header)
    square.overlay:SetShown(shape == "square" and not infoBar)
  end
  if zoneLabel then
    PlateShown(zoneLabel.plate, not isSquare and not infoBar)
    zoneLabel.text:SetShown(not isSquare and not infoBar)
  end
end

local function InfoBarLayout()
  if not shape then
    return
  end
  infoBar = InfoBarShown()
  Layout()
  ClockShown()
  PlaceButtons()
  shownInset = nil
  UpdateLabel()
end

local function ApplyShape(want)
  local was = shape
  shape = want
  local isSquare = want ~= "round"
  for _, disc in ipairs(discs) do
    disc:SetShown(not isSquare)
  end
  -- round as it came: Forever's mask and rings are only touched once the map has been square
  if isSquare then
    SetMask(SQUARE_MASK)
    BlobRings(0)
  elseif was and was ~= "round" then
    SetMask(roundMask or CIRCLE_MASK)
    BlobRings(1)
  end
  HybridShape()
  ShapeGlobal()
  InfoBarLayout()
end

-- Settings > minimap shape: the new CodexDB.skins.minimapShape on screen now. False while the minimap
-- part isn't running (Settings then asks for a reload).
function TylesserCodex.ApplyMinimapShape()
  if not shape then
    return false
  end
  return S.Run("minimap", ApplyShape, WantedShape())
end
TylesserCodex.MinimapShape = WantedShape -- the shape the part shows (or would show)

S.Part("minimap", function()
  if not S.Usable(Minimap) then
    return
  end
  WatchArt()
  BuildRing()
  BuildZonePlate()
  BuildSquare()
  for _, badge in ipairs(BADGES) do
    Badge(S.Get(badge[1]), badge[2])
  end
  S.Kill(S.Child(S.Get("MinimapCluster.Tracking"), "Background")) -- the tracking button's round backdrop: bare
  -- Forever puts its round art and mask back on config changes (rotate minimap, header position)
  S.HookMethod(S.Get("MinimapCluster"), "UpdateMinimapConfig", WatchArt)
  S.HookMethod(Minimap, "SetMaskTexture", function(...)
    HideArt()
    KeepMask(...)
  end)
  -- the clock comes with Blizzard_TimeManager, the indoor map with Blizzard_HybridMinimap (load-on-demand)
  S.OnAddOn("Blizzard_TimeManager", function()
    SkinClock()
    WatchClock()
  end)
  S.OnAddOn("Blizzard_HybridMinimap", HybridShape)
  -- the info bar shown or hidden (Modules/InfoBar fires it; nothing while that module is off)
  if type(TylesserCodex.OnInfoBarShown) == "function" then
    local part = S.part
    TylesserCodex.OnInfoBarShown(function()
      S.Run(part, InfoBarLayout)
    end)
  end
  ApplyShape(WantedShape())
end)
