local addonName, ns = ...

-- Codex_Skins: restyles the game's own interface in the active Codex theme. Shared helpers here; one file
-- per part (TylesserCodex.SKIN_PARTS id), run by Run.lua.
--
-- Restyle only, with one exception: UnitFrames.lua draws Codex's own player/target/ToT/pet/focus frames and
-- parks Blizzard's (out of combat). Otherwise Blizzard frames are never moved, resized, reparented, shown or hidden, no attribute is set
-- and no Blizzard function is replaced (hooksecurefunc / HookScript re-apply the look after Blizzard
-- updates). What we draw is textures of our own, on the Blizzard frame or on frames of our own parented to
-- it, and Blizzard art is only made invisible (SetAlpha(0) on a texture or an art-only frame). Nothing is
-- built while in combat: that waits for PLAYER_REGEN_ENABLED. State is kept in our own tables, never as
-- fields on Blizzard frames.

local Codex = TylesserCodex
local UI = Codex.UI
local S = {}
ns.S = S
S.UI = UI
S.parts = {} -- [id] = function, registered by the part files

local PREFIX = "|TInterface\\AddOns\\Codex\\Media\\Stud:12|t |cfff0c24eCodex:|r "

-- The game's interface surfaces (the light-theme rule in Theme.lua): the theme itself (Dawn: light, with the game's
-- text colours darkened), or Dawn's dark ink surfaces with "Game interface on dark panels". For a dark theme this is
-- simply the theme.
function S.Theme()
  if type(Codex.InkTheme) == "function" then
    return Codex.InkTheme()
  end
  return Codex.Theme()
end

function S.Part(id, fn)
  S.parts[id] = fn
end

-- Lookups --------------------------------------------------------------------------------------------------
-- Every frame may be missing or named differently on this client, so all reads go through these and only
-- ever return tables (frames and regions).

-- `object.key1.key2...`, or nil when a step is missing.
function S.Child(object, ...)
  for index = 1, select("#", ...) do
    if type(object) ~= "table" then
      return nil
    end
    object = object[(select(index, ...))]
  end
  if type(object) == "table" then
    return object
  end
end

-- "Global.key.key" -> the object, or nil.
function S.Get(path)
  if type(path) ~= "string" then
    return type(path) == "table" and path or nil
  end
  local object
  for key in path:gmatch("[^%.]+") do
    if object == nil then
      object = _G[key]
    else
      object = S.Child(object, key)
    end
    if type(object) ~= "table" then
      return nil
    end
  end
  return object
end

-- The first of several paths that exists.
function S.First(...)
  for index = 1, select("#", ...) do
    local object = S.Get((select(index, ...)))
    if object then
      return object
    end
  end
end

-- A frame or region we may touch: a real widget, not forbidden.
function S.Usable(object)
  if type(object) ~= "table" or type(object.GetObjectType) ~= "function" then
    return false
  end
  if type(object.IsForbidden) == "function" and object:IsForbidden() then
    return false
  end
  return true
end

local REGION_TYPES = { Texture = true, FontString = true, Line = true, MaskTexture = true }
function S.IsRegion(object)
  return S.Usable(object) and REGION_TYPES[object:GetObjectType()] or false
end

-- A texture or font string under `key` of an object.
function S.Region(object, key)
  local region = S.Child(object, key)
  if S.IsRegion(region) then
    return region
  end
end

function S.Protected(frame)
  return S.Usable(frame) and type(frame.IsProtected) == "function" and frame:IsProtected() and true or false
end

function S.Name(frame)
  local name = S.Usable(frame) and frame.GetName and frame:GetName()
  return type(name) == "string" and name or nil
end

-- Our marks on Blizzard frames (weak keys, nothing written to the frames themselves).
local marks = setmetatable({}, { __mode = "k" })
function S.Done(object, tag)
  return marks[object] ~= nil and marks[object][tag] == true
end
function S.Once(object, tag)
  if type(object) ~= "table" or S.Done(object, tag) then
    return false
  end
  marks[object] = marks[object] or {}
  marks[object][tag] = true
  return true
end

-- Errors ---------------------------------------------------------------------------------------------------
-- Each part runs in its own pcall; the first error per part is kept (TylesserCodex.skinErrors for /dump)
-- and one short line names the parts that failed.

S.errors = {}
Codex.skinErrors = S.errors
local reported = {}
S.ready = false -- true after the first run: later failures are reported straight away

function S.PartName(id)
  for _, part in ipairs(Codex.SKIN_PARTS or {}) do
    if part.id == id then
      return part.name
    end
  end
  return id
end

function S.Report()
  local names = {}
  for id in pairs(S.errors) do
    if not reported[id] then
      reported[id] = true
      names[#names + 1] = S.PartName(id)
    end
  end
  if #names > 0 then
    table.sort(names)
    print(PREFIX .. "could not restyle " .. table.concat(names, ", ")
      .. " on this client; the rest is restyled. (/dump TylesserCodex.skinErrors)")
  end
end

function S.Fail(part, err)
  part = part or "skins"
  if not S.errors[part] then
    S.errors[part] = tostring(err)
  end
  if S.ready then
    S.Report()
  end
end

-- Runs fn(...) for a part, catching errors. S.part is the part id while it runs, so hooks and deferred work
-- set up inside report against the same part.
function S.Run(part, fn, ...)
  local previous = S.part
  S.part = part
  local ok, err = pcall(fn, ...)
  S.part = previous
  if not ok then
    S.Fail(part, err)
  end
  return ok
end

-- Combat ---------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
ns.eventFrame = events
local queue, queued = {}, {}

function S.InCombat()
  return InCombatLockdown and InCombatLockdown() and true or false
end

-- Runs fn now, or after the fight when in combat (once per key while waiting).
function S.Defer(key, fn)
  local part = S.part
  if not S.InCombat() then
    return S.Run(part, fn)
  end
  if key ~= nil then
    if queued[key] then
      return
    end
    queued[key] = true
  end
  queue[#queue + 1] = { part = part, fn = fn }
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function RunQueue()
  local list = queue
  queue, queued = {}, {}
  events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for _, job in ipairs(list) do
    S.Run(job.part, job.fn)
  end
end

-- Hooks ----------------------------------------------------------------------------------------------------
-- All post-hooks: Blizzard's code runs untouched first. Errors are caught so a hook can never break the
-- Blizzard function it follows.

function S.HookGlobal(name, fn)
  if type(_G[name]) ~= "function" then
    return false
  end
  local part = S.part
  hooksecurefunc(name, function(...)
    S.Run(part, fn, ...)
  end)
  return true
end

function S.HookMethod(object, method, fn)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return false
  end
  local part = S.part
  hooksecurefunc(object, method, function(...)
    S.Run(part, fn, ...)
  end)
  return true
end

function S.HookScript(frame, script, fn)
  if not S.Usable(frame) or type(frame.HookScript) ~= "function" then
    return false
  end
  local part = S.part
  return (pcall(frame.HookScript, frame, script, function(...)
    S.Run(part, fn, ...)
  end))
end

-- Blizzard's load-on-demand addons -------------------------------------------------------------------------

local waiting = {} -- [addon] = { { part, fn }, ... }
local anyAddOn = {} -- { { part, fn }, ... } on every ADDON_LOADED

function S.AddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded(name) and true or false
  end
  return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
end

-- fn() once `addon` is loaded (now if it already is), out of combat.
function S.OnAddOn(addon, fn)
  if S.AddOnLoaded(addon) then
    return S.Defer(nil, fn)
  end
  waiting[addon] = waiting[addon] or {}
  table.insert(waiting[addon], { part = S.part, fn = fn })
  events:RegisterEvent("ADDON_LOADED")
end

-- fn(addon) after every addon that loads (for windows that come with load-on-demand addons).
function S.OnAnyAddOn(fn)
  table.insert(anyAddOn, { part = S.part, fn = fn })
  events:RegisterEvent("ADDON_LOADED")
end

local function WithPart(part, fn, ...)
  local previous = S.part
  S.part = part
  fn(...)
  S.part = previous
end

events:SetScript("OnEvent", function(self, event, addon)
  if event == "PLAYER_REGEN_ENABLED" then
    RunQueue()
  elseif event == "ADDON_LOADED" then
    local list = waiting[addon]
    waiting[addon] = nil
    for _, job in ipairs(list or {}) do
      WithPart(job.part, S.Defer, nil, job.fn)
    end
    for _, job in ipairs(anyAddOn) do
      WithPart(job.part, S.Defer, "any:" .. job.part, function()
        job.fn(addon)
      end)
    end
  end
end)

-- Art ------------------------------------------------------------------------------------------------------

-- Makes a piece of Blizzard art invisible: a texture, or an art-only frame (NineSlice, border). A protected
-- frame is never touched.
function S.Kill(object)
  if not S.Usable(object) then
    return
  end
  if not S.IsRegion(object) and S.Protected(object) then
    return
  end
  if type(object.SetAlpha) == "function" then
    object:SetAlpha(0)
  end
end

function S.KillKeys(object, ...)
  for index = 1, select("#", ...) do
    S.Kill(S.Child(object, (select(index, ...))))
  end
end

-- `name .. suffix` globals, for the older named art.
function S.KillNamed(name, ...)
  if not name then
    return
  end
  for index = 1, select("#", ...) do
    S.Kill(_G[name .. select(index, ...)])
  end
end

-- Empties a texture for good (chat backgrounds, which Blizzard fades in and out with SetAlpha).
function S.Empty(texture)
  if S.IsRegion(texture) and texture.SetTexture then
    texture:SetTexture(nil)
    texture:SetAlpha(0)
  end
end

-- Recolours Blizzard art: greyed, then tinted.
function S.Tint(texture, color, alpha)
  if not S.IsRegion(texture) or not texture.SetVertexColor then
    return
  end
  if texture.SetDesaturated then
    texture:SetDesaturated(true)
  end
  texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- The brightest ring colour: the "line" of a look, used to tint Blizzard borders.
function S.LineColor(rings)
  local best, bestLight
  for _, ring in ipairs(rings or {}) do
    local c = ring.color
    local light = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
    if not best or light > bestLight then
      best, bestLight = c, light
    end
  end
  return best or S.Theme().accent
end

local function SetColor(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end
S.SetColor = SetColor

-- A rectangle of lines `inset` in from the edges of `box` (any frame or region), drawn as textures of
-- `frame`.
function S.Outline(frame, box, inset, size, color, layer, sublevel)
  inset, size = inset or 0, size or 1
  local lines = {}
  for index = 1, 4 do
    lines[index] = frame:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
    SetColor(lines[index], color)
  end
  local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
  top:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
  top:SetPoint("TOPRIGHT", box, "TOPRIGHT", -inset, -inset)
  top:SetHeight(size)
  bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", inset, inset)
  bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
  bottom:SetHeight(size)
  left:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
  left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", inset, inset)
  left:SetWidth(size)
  right:SetPoint("TOPRIGHT", box, "TOPRIGHT", -inset, -inset)
  right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
  right:SetWidth(size)
  return lines
end

-- How far a title band starts in from a window's edge: under the rings, or (rounded corners) far enough in
-- that its square corners stay inside the rounded ones.
function S.BandInset(theme)
  theme = theme or S.Theme()
  local radius = UI.Radius and UI.Radius("window", theme)
  if radius then
    return math.ceil(radius * 0.3)
  end
  return S.RingDepth(theme.rings)
end

-- How far the rings reach in from the edge.
function S.RingDepth(rings)
  local depth = 0
  for _, ring in ipairs(rings or {}) do
    depth = math.max(depth, (ring.inset or 0) + (ring.size or 1))
  end
  return depth
end

-- The theme's corner pieces (studs, rivets) on the corners of `box`, drawn by `frame`.
function S.Corners(frame, box, size)
  local corner = S.Theme().corner
  if not corner or not corner.texture then
    return
  end
  size = size or corner.size or 16
  local pieces = {}
  for _, point in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
    local piece = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    piece:SetTexture(corner.texture)
    piece:SetSize(size, size)
    piece:SetPoint("CENTER", box, point[1], point[2], point[3])
    if corner.color then
      piece:SetVertexColor(UI.Unpack(corner.color))
    end
    pieces[#pieces + 1] = piece
  end
  return pieces
end

-- The theme's looks: fill (or gradient) and rings.
function S.Look(kind)
  local theme = S.Theme()
  if kind == "panel" then
    local panel = theme.panel
    return { from = panel.from, to = panel.to, alpha = panel.alpha or 0.97, tile = panel.tile, tileAlpha = panel.tileAlpha,
      blend = panel.blend, rings = theme.rings, corners = true, round = theme.round ~= nil }
  elseif kind == "slot" then
    return { fill = theme.slot.fill, rings = theme.slot.rings }
  elseif kind == "inset" then
    return { fill = theme.inset.fill, rings = { { inset = 0, color = theme.inset.line, size = 1 } } }
  elseif kind == "soft" then
    local fill = theme.hud.fill
    return { fill = fill, alpha = (fill[4] or 1) * 0.65, rings = {} }
  end
  return { fill = theme.hud.fill, rings = theme.hud.rings }
end

-- Draws a look behind `frame` as textures of the frame itself (under all its child frames).
-- opts: pad (grow outward, default 0) or left/top/right/bottom; topLeft/bottomRight (anchor objects
-- instead of the frame); ringsOn (a frame of ours to draw the rings and corners on, so they sit above the
-- frame's children); corners (true = theme corners when the look has them); cornerSize; sublevel; shadow (true /
-- false: the Look options' soft shadow round the fill; default: on for the "panel" look, i.e. windows, tooltips
-- and menus).
-- Returns { fill, tile, lines, corners, shadow }.
function S.Plate(frame, look, opts)
  opts = opts or {}
  local shadow = opts.shadow
  if shadow == nil then
    shadow = look == "panel"
  end
  if type(look) == "string" then
    look = S.Look(look)
  end
  local pad = opts.pad or 0
  local fill = frame:CreateTexture(nil, "BACKGROUND", nil, opts.sublevel or -8)
  fill:SetPoint("TOPLEFT", opts.topLeft or frame, "TOPLEFT", -(opts.left or pad), opts.top or pad)
  fill:SetPoint("BOTTOMRIGHT", opts.bottomRight or frame, "BOTTOMRIGHT", opts.right or pad, -(opts.bottom or pad))
  if look.from then
    UI.Gradient(fill, { look.from[1], look.from[2], look.from[3], look.alpha or look.from[4] or 1 },
      { look.to[1], look.to[2], look.to[3], look.alpha or look.to[4] or 1 })
  else
    SetColor(fill, look.fill, look.alpha)
  end
  local plate = { fill = fill, lines = {} }
  -- rounded corners (the theme's round.window) on window panels: the fill stays as the anchor every part moves,
  -- see-through; nine pieces anchored on it draw the rounded box and one rounded hairline (plate.round, plate.lines)
  local radius = look.round and UI.Radius and UI.Radius("window", S.Theme())
  if radius then
    local color = look.from or look.fill
    fill:SetColorTexture(color[1], color[2], color[3], 0)
    plate.round = UI.RoundFill(frame, fill, radius, { color[1], color[2], color[3], look.alpha or color[4] or 1 },
      { sublevel = opts.sublevel or -8 })
    local ring = look.rings and look.rings[1]
    if ring then
      for _, piece in ipairs(UI.RoundLine(opts.ringsOn or frame, fill, radius, ring.color,
        { layer = opts.ringLayer or "BORDER", sublevel = opts.ringSublevel, size = ring.size })) do
        plate.lines[#plate.lines + 1] = piece
      end
    end
    if shadow then
      plate.shadow = S.Shadow(frame, fill)
    end
    return plate
  end
  if look.tile then
    local tile = frame:CreateTexture(nil, "BACKGROUND", nil, (opts.sublevel or -8) + 1)
    tile:SetAllPoints(fill)
    tile:SetTexture(look.tile, "REPEAT", "REPEAT")
    if tile.SetHorizTile then
      tile:SetHorizTile(true)
      tile:SetVertTile(true)
    end
    tile:SetAlpha(look.tileAlpha or 1)
    if look.blend then
      tile:SetBlendMode(look.blend)
    end
    plate.tile = tile
  end
  local host = opts.ringsOn or frame
  for _, ring in ipairs(look.rings or {}) do
    local lines = S.Outline(host, fill, ring.inset, ring.size, ring.color, opts.ringLayer or "BORDER", opts.ringSublevel)
    for _, line in ipairs(lines) do
      plate.lines[#plate.lines + 1] = line
    end
  end
  if look.corners and opts.corners then
    plate.corners = S.Corners(host, fill, opts.cornerSize)
  end
  if shadow then
    plate.shadow = S.Shadow(frame, fill)
  end
  return plate
end

-- Look options (Widgets.lua keeps the list, so Settings can switch them live) -----------------------------

-- The soft outer shadow round `box`, as textures of `frame` (only while "Soft shadows" is on).
function S.Shadow(frame, box, opts)
  if not S.Usable(frame) or type(UI.Shadow) ~= "function" then
    return
  end
  opts = opts or {}
  opts.ink = true -- the game's interface: the ink surfaces' shadow
  return UI.Shadow(frame, box or frame, opts)
end

-- The theme's decorative strip on the top edge of `box`, as textures of `frame` (only while "Decorative
-- strips" is on). opts as UI.Strip: caps, mids, left / right / top, minHeight.
function S.Strip(frame, box, opts)
  if not S.Usable(frame) or type(UI.Strip) ~= "function" then
    return
  end
  opts = opts or {}
  opts.ink = true
  return UI.Strip(frame, box or frame, opts)
end

-- Every texture of a plate (fill, tile, rings, corner pieces, rounded pieces), for showing / hiding / fading.
function S.PlatePieces(plate)
  local pieces = {}
  if not plate then
    return pieces
  end
  pieces[#pieces + 1] = plate.fill
  pieces[#pieces + 1] = plate.tile
  for _, list in ipairs({ plate.lines or {}, plate.corners or {}, plate.round or {} }) do
    for _, piece in ipairs(list) do
      pieces[#pieces + 1] = piece
    end
  end
  return pieces
end

-- A frame of ours over `frame` (same size, no mouse) for rings and corners that must sit above the
-- frame's own children.
function S.Overlay(frame, levels)
  local overlay = CreateFrame("Frame", nil, frame)
  overlay:SetAllPoints(frame)
  overlay:SetFrameLevel(frame:GetFrameLevel() + (levels or 8))
  overlay:EnableMouse(false)
  return overlay
end

-- Fonts ----------------------------------------------------------------------------------------------------

local baseSize = setmetatable({}, { __mode = "k" })

local function ThemeFont(kind)
  local font = S.Theme().font or {}
  if kind == "head" then
    return font.head, font.headSize or 1
  end
  return font.body, font.bodySize or 1
end

-- Theme font (kind "head" or "body") at the string's own size; only when the theme has that font, so
-- themes that use the game's fonts leave the face alone. color: a colour or a theme key ("accent").
-- keepSize: no theme size scaling (chat, whose size is the player's setting).
function S.Font(fontString, kind, color, keepSize)
  if not S.Usable(fontString) then
    return
  end
  local path, scale = ThemeFont(kind)
  if keepSize then
    scale = 1
  end
  if path and fontString.SetFont and fontString.GetFont then
    local _, size, flags = fontString:GetFont()
    if not baseSize[fontString] then
      baseSize[fontString] = type(size) == "number" and size > 0 and size or 12
    end
    fontString:SetFont(path, math.floor(baseSize[fontString] * scale + 0.5), type(flags) == "string" and flags or "")
  end
  if color and fontString.SetTextColor then
    local c = type(color) == "string" and S.Theme()[color] or color
    if c and type(color) == "table" and type(Codex.GameColor) == "function" then
      c = Codex.GameColor(c, S.Theme()) -- a game colour (whisper pink, zone colours): readable on light ground
    end
    if c then
      fontString:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
  end
end

-- Game texts on light ground (the light-theme rule, Theme.lua) ----------------------------------------------
-- A font string (or edit box) whose colours Blizzard sets, kept readable on a light theme (UI.GameText: colour and
-- colour codes darkened now and after each of Blizzard's later setters, the theme's text shadow). kind: the
-- ground it sits on, "hud" (chat, tracker), "slot" (bar tracks, slots) or nil (windows, tooltips). Does nothing on
-- a dark theme.
function S.GameText(fontString, kind, opts)
  if not S.Usable(fontString) or type(UI.GameText) ~= "function" then
    return false
  end
  opts = opts or {}
  opts.theme = S.Theme()
  opts.kind = opts.kind or kind
  return UI.GameText(fontString, opts)
end

-- A Blizzard bar whose class colour Blizzard sets (raid cells, the damage meter): on a theme with classTone (Dusk,
-- Dawn) a texture of ours over its fill, in the tone's dark colour at the tone's mix, so the colour shows a third of
-- the way to the dark track (ns.ToneClass for our own bars; an overlay can mix but not desaturate). Nothing of
-- Blizzard's is set: the overlay follows the fill texture's width. Returns the texture, or nil (no token).
function S.ToneOverlay(bar, layer, sublevel, fill)
  local tone = S.Theme().classTone
  if type(tone) ~= "table" or not S.Usable(bar) or not bar.CreateTexture then
    return nil
  end
  fill = fill or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
  if not S.IsRegion(fill) then
    return nil
  end
  local to = tone.toward or { 0, 0, 0 }
  local overlay = bar:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 0)
  overlay:SetAllPoints(fill)
  overlay:SetColorTexture(to[1], to[2], to[3], tone.mix or 0.33)
  return overlay
end

-- A text's drop shadow: the given one (default 1, -1 black) on dark ground, the theme's own (none) on light ground.
function S.TextShadow(fontString, x, y, r, g, b, a)
  if not S.IsRegion(fontString) or not fontString.SetShadowOffset then
    return
  end
  if S.Theme().light then
    x, y, r, g, b, a = UI.TextShadow(S.Theme())
  end
  fontString:SetShadowOffset(x or 1, y or -1)
  fontString:SetShadowColor(r or 0, g or 0, b or 0, a or 1)
end

-- Light themes: the game's shared window fonts (GameFontNormal yellow, GameFontHighlight white, the disabled
-- greys, red / green ...; Blizzard_Fonts_Shared, forever branch) in readable shades of their colours and with the
-- theme's text shadow, so every game window drawn on the light panel reads without touching its strings. Strings
-- that set their own colour are looked after where they are skinned. Outline fonts (text over icons and the world)
-- are left as they are. Nothing happens on a dark theme. Returns how many font objects were recoloured.
S.GAME_FONTS = { "GameFontNormal", "GameFontNormalSmall", "GameFontNormalSmall2", "GameFontNormalMed2",
  "GameFontNormalMed3", "GameFontNormalLarge", "GameFontNormalLarge2", "GameFontNormalHuge", "GameFontNormalHuge2",
  "GameFontNormalHuge3", "GameFontNormalHuge4", "GameFontNormalTiny", "GameFontNormalTiny2", "GameFontNormal_NoShadow",
  "GameFontNormalLeft", "GameFontNormalLeftBottom", "GameFontNormalSmallLeft", "GameFontNormalLargeLeft",
  "GameFontNormalLargeLeftTop", "GameFontNormalLeftGreen", "GameFontNormalLeftGrey", "GameFontNormalLeftLightBlue",
  "GameFontNormalLeftLightGreen", "GameFontNormalLeftLightGrey", "GameFontNormalLeftOrange", "GameFontNormalLeftRed",
  "GameFontNormalLeftYellow", "GameFontNormalSmallBattleNetBlueLeft", "GameFontNormalShadowHuge2",
  "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightSmall2", "GameFontHighlightExtraSmall",
  "GameFontHighlightExtraSmallLeft", "GameFontHighlightExtraSmallLeftTop", "GameFontHighlightMedium",
  "GameFontHighlightMed2", "GameFontHighlightLarge", "GameFontHighlightLarge2", "GameFontHighlightHuge",
  "GameFontHighlightHuge2", "GameFontHighlightLeft", "GameFontHighlightRight", "GameFontHighlightCenter",
  "GameFontHighlightSmallLeft", "GameFontHighlightSmallLeftTop", "GameFontHighlightSmallRight",
  "GameFontHighlight_NoShadow", "GameFontWhite", "GameFontWhiteSmall", "GameFontWhiteTiny", "GameFontWhiteTiny2",
  "GameFontWhiteLarge", "GameFontDisable", "GameFontDisableSmall", "GameFontDisableSmall2", "GameFontDisableLarge",
  "GameFontDisableHuge", "GameFontDisableMed2", "GameFontDisableMed3", "GameFontDisableTiny", "GameFontDisableTiny2",
  "GameFontDisableLeft", "GameFontDisableSmallLeft", "GameFontDarkGraySmall", "GameFontGreen", "GameFontGreenSmall",
  "GameFontGreenLarge", "GameFontRed", "GameFontRedSmall", "GameFontRedLarge" }

function S.GameFonts()
  local theme = S.Theme()
  if not theme.light or type(Codex.GameColor) ~= "function" then
    return 0
  end
  local done = 0
  for _, name in ipairs(S.GAME_FONTS) do
    local object = S.Get(name)
    if object and type(object.GetTextColor) == "function" and type(object.SetTextColor) == "function"
      and S.Once(object, "gamefont") then
      local ok = pcall(function()
        local r, g, b, a = object:GetTextColor()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
          local c = Codex.GameColor({ r, g, b }, theme)
          object:SetTextColor(c[1], c[2], c[3], type(a) == "number" and a or 1)
        end
        if object.SetShadowColor then
          local x, y, sr, sg, sb, sa = UI.TextShadow(theme)
          object:SetShadowOffset(x, y)
          object:SetShadowColor(sr, sg, sb, sa)
        end
      end)
      if ok then
        done = done + 1
      end
    end
  end
  return done
end

-- The same for a shared font object (GameTooltipHeaderText, ...): every string using it follows.
-- A font style of Codex's Fonts tabs (Codex FontStyles.lua) laid over a text's font; nothing without Codex's API.
function S.RestyleFont(fontString, key)
  if S.IsRegion(fontString) and type(TylesserCodex) == "table" and type(TylesserCodex.RestyleFont) == "function" then
    return TylesserCodex.RestyleFont(fontString, key)
  end
  return false
end

function S.FontObject(object, kind)
  object = S.Get(object)
  if not object or not object.SetFont or not object.GetFont then
    return
  end
  local path, scale = ThemeFont(kind)
  if not path then
    return
  end
  local _, size, flags = object:GetFont()
  if not baseSize[object] then
    baseSize[object] = type(size) == "number" and size > 0 and size or 12
  end
  object:SetFont(path, math.floor(baseSize[object] * scale + 0.5), type(flags) == "string" and flags or "")
end

-- Pieces ---------------------------------------------------------------------------------------------------

local function IconOf(button)
  local name = S.Name(button)
  return S.Region(button, "icon") or S.Region(button, "Icon") or S.Region(button, "IconTexture")
    or (name and (S.Get(name .. "Icon") or S.Get(name .. "IconTexture")))
end
S.IconOf = IconOf

local function NormalOf(button)
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if S.IsRegion(normal) then
    return normal
  end
  return S.Region(button, "NormalTexture") or (S.Name(button) and S.Get(S.Name(button) .. "NormalTexture"))
end

-- Re-hides a slot's Blizzard frame art (Blizzard sets it again when the button's art updates).
function S.SlotArt(button)
  S.Kill(NormalOf(button))
  S.KillKeys(button, "SlotArt", "SlotBackground")
  S.KillNamed(S.Name(button), "FloatingBG")
end

-- Rounded slots and bars (themes with round.slot / round.bar / round.plate: Dusk, Dawn; the others stay square).
function S.Radius(kind)
  return UI.Radius and UI.Radius(kind, S.Theme()) or nil
end

-- The textures of a slot button that cover the icon: the icon itself and the hover / pushed / checked art (all
-- get the rounded mask, so no square corner shows on hover or click). Read through the button's own getters.
function S.IconTextures(button, icon)
  local list = { icon }
  for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
    if type(button[getter]) == "function" then
      local ok, texture = pcall(button[getter], button)
      if ok and S.IsRegion(texture) then
        list[#list + 1] = texture
      end
    end
  end
  for _, key in ipairs({ "Flash", "IconQuestTexture", "NewActionTexture", "SpellHighlightTexture" }) do
    list[#list + 1] = S.Region(button, key)
  end
  return list
end

-- Rounds a slot's icon (round.slot): our nine-sliced rounded mask on the icon and the art over it, and the
-- cooldown swipe drawn in the same shape. Blizzard's own IconMask is taken off the icon first by the caller. Returns
-- the mask, or nil (square theme, or masks missing on this client).
local ROUND_SWIPE = "Interface\\AddOns\\Codex\\Media\\RoundMask6"
function S.RoundIcon(button, icon, radius)
  radius = radius or S.Radius("slot")
  if not radius or not S.Usable(button) or not S.IsRegion(icon) then
    return nil
  end
  local mask = UI.RoundMask(button, icon, radius, S.IconTextures(button, icon))
  local name = S.Name(button)
  local cooldown = S.Child(button, "cooldown") or (name and S.Get(name .. "Cooldown"))
  if mask and S.Usable(cooldown) and type(cooldown.SetSwipeTexture) == "function" then
    pcall(cooldown.SetSwipeTexture, cooldown, ROUND_SWIPE)
  end
  return mask
end

-- The theme slot look on a button (action, bag, item slot): a dark fill behind, the slot rings over the
-- icon's edge, the icon's edges cropped. Textures only: the button itself is never moved, sized or hidden,
-- so this is safe on secure buttons (out of combat, like everything we build). A rounded theme (round.slot)
-- draws the fill and ring rounded and cuts the icon with a rounded mask.
function S.Slot(button)
  if not S.Usable(button) or not S.Once(button, "slot") then
    return false
  end
  local icon = IconOf(button)
  if icon then
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- "Mask": ItemButton's own (common-iconmask on the icon, ItemButtonMixin:OnLoad); with our rounded mask on top
    -- the bag icons drew as specks on black (2026-11-19)
    for _, key in ipairs({ "IconMask", "CircleMask", "Mask" }) do
      local mask = S.Child(button, key)
      if mask and icon.RemoveMaskTexture then
        pcall(icon.RemoveMaskTexture, icon, mask)
      end
    end
  end
  S.SlotArt(button)
  local look = S.Look("slot")
  local radius = S.Radius("slot")
  if radius then
    UI.RoundFill(button, button, radius, look.fill, { sublevel = -8 })
    local ring = look.rings[1]
    if ring then
      UI.RoundLine(button, button, radius, ring.color, { layer = "OVERLAY", sublevel = 1 })
    end
    S.RoundIcon(button, icon, radius)
    return true
  end
  local fill = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints(button)
  SetColor(fill, look.fill)
  for _, ring in ipairs(look.rings) do
    S.Outline(button, button, ring.inset, ring.size, ring.color, "OVERLAY", 1)
  end
  return true
end

-- A rounded status bar (round.bar, or `kind` "plate" for nameplates): the rounded mask on its fill texture and on
-- the given background textures. opts.square = { top, bottom, left, right }: edges whose corners stay square (two
-- bars touching). Only with a sliced mask (a stretched one would round a long bar far too much). Returns the mask.
function S.RoundBar(bar, textures, opts)
  opts = opts or {}
  local radius = S.Radius(opts.kind or "bar")
  if not radius or not S.Usable(bar) then
    return nil
  end
  local height = type(opts.height) == "number" and opts.height or nil
  if type(height) ~= "number" then
    local ok, h = pcall(bar.GetHeight, bar)
    height = ok and type(h) == "number" and (not canaccessvalue or canaccessvalue(h)) and h or nil
  end
  if height and height > 0 then
    radius = math.min(radius, math.floor(height / 2))
  end
  if radius < 2 then
    return nil
  end
  local list = { }
  local ok, fill = pcall(bar.GetStatusBarTexture, bar)
  if ok and S.IsRegion(fill) then
    list[#list + 1] = fill
  end
  for _, texture in pairs(textures or {}) do
    list[#list + 1] = texture
  end
  return UI.RoundMask(opts.owner or bar, opts.box or bar, radius, list, { square = opts.square, sliced = true })
end

-- A status bar: dark slot fill behind and slot rings round it, outside its edge. The bar's own texture
-- and colours (health green, ...) stay Blizzard's.
function S.StatusBar(bar, pad)
  if not S.Usable(bar) or not S.Once(bar, "bar") then
    return false
  end
  pad = pad or 1
  local look = S.Look("slot")
  local depth = S.RingDepth(look.rings)
  S.Plate(bar, { fill = look.fill, alpha = 0.7, rings = look.rings }, { pad = pad + depth, ringLayer = "OVERLAY" })
  return true
end

-- A UIPanelButtonTemplate button (Left / Middle / Right art): the theme's button instead.
function S.IsPanelButton(button)
  return S.Usable(button) and button:GetObjectType() == "Button" and S.Region(button, "Left") ~= nil
    and S.Region(button, "Middle") ~= nil and S.Region(button, "Right") ~= nil
end

local function ButtonText(button)
  local text = button.GetFontString and button:GetFontString()
  if not S.IsRegion(text) then
    return
  end
  local theme = S.Theme()
  local enabled = not button.IsEnabled or button:IsEnabled()
  local c = enabled and theme.button.text or theme.muted
  text:SetTextColor(c[1], c[2], c[3], enabled and 1 or 0.6)
end

function S.Button(button)
  if not S.IsPanelButton(button) or not S.Once(button, "button") then
    return false
  end
  S.KillKeys(button, "Left", "Middle", "Right")
  local theme = S.Theme()
  local style = theme.button
  local radius = UI.Radius and UI.Radius("button", theme)
  if radius then
    -- rounded (Dusk, Dawn): flat fill and one rounded hairline, 1 px in from the button's edge like the square look
    local holder = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    holder:SetPoint("TOPLEFT", 1, -1)
    holder:SetPoint("BOTTOMRIGHT", -1, 1)
    holder:SetColorTexture(0, 0, 0, 0)
    UI.RoundFill(button, holder, radius, style.from)
    UI.RoundLine(button, holder, radius, style.line)
  else
    S.Plate(button, { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } },
      { left = -1, right = -1, top = -1, bottom = -1 })
  end
  ButtonText(button)
  S.HookScript(button, "OnEnable", ButtonText)
  S.HookScript(button, "OnDisable", ButtonText)
  return true
end

-- Calls fn(child) for the child frames of `frame`, `depth` levels down.
function S.Walk(frame, depth, fn)
  if not S.Usable(frame) or not frame.GetChildren or depth <= 0 then
    return
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if S.Usable(child) then
      fn(child)
      S.Walk(child, depth - 1, fn)
    end
  end
end

-- Windows --------------------------------------------------------------------------------------------------

local WINDOW_ART = { "NineSlice", "Bg", "TitleBg", "TopTileStreaks", "PortraitContainer", "portrait", "PortraitFrame",
  "PortraitOverlay", "BorderBox" }

local function IsNineSlice(object)
  return S.Usable(object) and S.Child(object, "TopLeftCorner") ~= nil
end

function S.TitleOf(frame, chrome)
  local name = S.Name(frame)
  return S.Region(S.Child(chrome, "TitleContainer"), "TitleText") or S.Region(chrome, "TitleText")
    or S.Region(S.Child(frame, "TitleContainer"), "TitleText") or S.Region(frame, "TitleText")
    or (name and S.Get(name .. "TitleText"))
end

-- An inset box (ButtonFrameTemplate's Inset): Blizzard's art off, the theme's inset look on.
function S.Inset(inset)
  if not S.Usable(inset) or not S.Child(inset, "NineSlice") or not S.Once(inset, "inset") then
    return
  end
  S.KillKeys(inset, "NineSlice", "Bg")
  S.Plate(inset, "inset")
end

-- A game window (PortraitFrameTemplate / ButtonFrameTemplate and the like): Blizzard's border, background,
-- title band and portrait made invisible, the theme panel, rings, corners and title bar drawn instead.
-- Windows with old-style art (no NineSlice border) are left alone: their art can't be swapped cleanly.
-- opts: chrome (the frame holding the border art, e.g. WorldMapFrame.BorderFrame), level (overlay levels
-- above the window), strip = false (no decorative strip: NPC windows). Returns true when skinned.
function S.Window(frame, opts)
  opts = opts or {}
  if not S.Usable(frame) or S.Done(frame, "window") then
    return false
  end
  local chrome = opts.chrome or frame
  local border = S.Child(chrome, "Border")
  if not border or not IsNineSlice(border) then
    border = nil
  end
  if not S.Child(chrome, "NineSlice") and not border then
    return false
  end
  S.Once(frame, "window")
  local theme = S.Theme()
  local name = S.Name(frame)
  for _, holder in ipairs({ frame, chrome }) do
    for _, key in ipairs(WINDOW_ART) do
      S.Kill(S.Child(holder, key))
    end
  end
  S.Kill(border)
  S.KillNamed(name, "Bg", "TitleBg", "Portrait", "PortraitFrame", "TopTileStreaks")

  local depth = S.BandInset(theme)
  local overlay = S.Overlay(frame, opts.level)
  local plate = S.Plate(frame, "panel", { ringsOn = overlay, corners = true })
  if opts.strip ~= false then
    -- on the overlay, above the window's content; the corner pieces already sit at its ends
    plate.strip = S.Strip(overlay, plate.fill, { caps = not plate.corners and "both" or false })
  end

  local title = S.TitleOf(frame, chrome)
  if title then
    local bar = theme.titlebar
    local band = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    band:SetPoint("TOPLEFT", frame, "TOPLEFT", depth, -depth)
    band:SetPoint("RIGHT", frame, "RIGHT", -depth, 0)
    local container = S.Child(chrome, "TitleContainer") or S.Child(frame, "TitleContainer")
    if container then
      band:SetPoint("BOTTOM", container, "BOTTOM", 0, -2)
    else
      band:SetHeight(22)
    end
    UI.Gradient(band, bar.from, bar.to)
    local line = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
    line:SetHeight(1)
    SetColor(line, bar.line)
    plate.band = band
    S.Font(title, "head", "titleText")
  end
  for _, key in ipairs({ "Inset", "LeftInset", "RightInset" }) do
    S.Inset(S.Child(frame, key))
  end
  return true, plate
end

-- Panel buttons inside a window (looked over every time it opens: windows build their content late).
function S.WindowButtons(frame)
  S.Walk(frame, 5, function(child)
    if S.IsPanelButton(child) then
      S.Button(child)
    end
  end)
end
