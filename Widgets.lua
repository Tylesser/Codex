local addonName, ns = ...

-- Themed widgets. Everything Codex draws goes through these, so a theme only has to describe colours,
-- borders, fonts and corner pieces. The active theme is read when a widget is built (themes switch after
-- a reload). Exposed to the load-on-demand folders as TylesserCodex.UI.

local T = ns.T
local UI = {}
ns.UI = UI
ns.API.UI = UI

-- The theme a widget is built in: the ink surfaces (ns.InkTheme, the light-theme rule in Theme.lua) when the frame
-- or one of its parents was marked with UI.Ink, else the theme. Dark themes are their own ink, so for them this is
-- always ns.Theme().
local function OnInk(frame)
  for _ = 1, 40 do
    if type(frame) ~= "table" then
      return false
    end
    if frame.codexOnInk == true then
      return true
    end
    frame = type(frame.GetParent) == "function" and frame:GetParent() or nil
  end
  return false
end

local function Theme(frame)
  local theme = ns.Theme()
  if frame ~= nil and type(ns.InkTheme) == "function" then
    local ink = ns.InkTheme()
    if ink ~= theme and OnInk(frame) then
      return ink
    end
  end
  return theme
end
UI.ThemeOf = Theme

-- Marks a frame of ours as an ink surface: widgets built on it or its children use ns.InkTheme().
function UI.Ink(frame)
  if type(frame) == "table" then
    frame.codexOnInk = true
  end
  return frame
end

local GAME_FONT = "Fonts\\FRIZQT__.TTF"

function UI.Unpack(color, alpha)
  return color[1], color[2], color[3], alpha or color[4] or 1
end

function UI.SetColor(texture, color, alpha)
  texture:SetColorTexture(UI.Unpack(color, alpha))
end

-- Vertical gradient: `from` at the bottom, `to` at the top.
function UI.Gradient(texture, from, to)
  T.Gradient(texture, "VERTICAL", from, to, from[4] or 1, to[4] or 1)
end

function UI.Rings(frame, rings, layer, sublevel)
  local all = {}
  for _, ring in ipairs(rings or {}) do
    local lines = T.Outline(frame, ring.inset or 0, ring.color, ring.size or 1, layer or "BORDER", sublevel)
    T.ColorLines(lines, ring.color, ring.color[4])
    table.insert(all, lines)
  end
  return all
end

-- Rounded corners (themes with a `round` token: Dusk, Dawn) ------------------------------------------------------
-- WoW textures have no corner radius: a rounded box is nine pieces, four quarters of Media/Round (a smooth disc)
-- at the corners and plain rectangles between them; its hairline is four quarters of Media/RoundLine and four
-- 1 px lines. Both textures are white and tinted (branding/source/round-art.py).

local ROUND = "Interface\\AddOns\\Codex\\Media\\Round"
local ROUND_LINE = "Interface\\AddOns\\Codex\\Media\\RoundLine"
UI.ROUND, UI.ROUND_LINE = ROUND, ROUND_LINE
local QUARTERS = { -- point, texcoords, x / y sign of the inset
  { "TOPLEFT", 0, 0.5, 0, 0.5, 1, -1 }, { "TOPRIGHT", 0.5, 1, 0, 0.5, -1, -1 },
  { "BOTTOMLEFT", 0, 0.5, 0.5, 1, 1, 1 }, { "BOTTOMRIGHT", 0.5, 1, 0.5, 1, -1, 1 },
}

-- The theme's corner radius for a kind of box ("window", "button", "box"), or nil for square corners.
function UI.Radius(kind, theme)
  local round = (theme or Theme()).round
  local radius = type(round) == "table" and round[kind or "window"]
  return type(radius) == "number" and radius > 0 and radius or nil
end

-- A corner quarter keeps its texture: SetColorTexture on it (T.ColorLines, S.SetColor, line:SetColorTexture in
-- older code that recolours lines) tints it instead, so rounded pieces can stand in for square line lists.
local function TintQuarter(self, r, g, b, a)
  self:SetVertexColor(r, g, b, a or 1)
end

local function Quarter(piece, path, coords)
  piece.codexQuarter, piece.codexCoords = path, coords
  piece:SetTexture(path)
  piece:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  piece.SetColorTexture = TintQuarter
end

local function Paint(pieces, color, alpha)
  local r, g, b, a = UI.Unpack(color, alpha)
  for _, piece in ipairs(pieces) do
    piece:SetColorTexture(r, g, b, a)
  end
end

-- Rounded masks (icons and status bars): nine-sliced MaskTextures (Forever's TextureBase has
-- SetTextureSliceMargins / SetTextureSliceMode, MaskTexture shares it), so the corner keeps its radius at any size.
local MASK_RADII = { 2, 3, 4, 6 } -- Media/RoundMask<r>.tga
UI.MASK_PATH = "Interface\\AddOns\\Codex\\Media\\RoundMask"

-- A rounded mask over `box`, made on `owner` (a frame), added to `textures`. opts: square = { top, bottom, left,
-- right } (those edges keep square corners: the mask reaches past them), sliced = true (nine-sliced, for flat
-- fills only: bars, a scroll thumb; nil when the client can't slice it, a stretched mask would round a long bar's
-- ends far too much). Without it the mask is plain (icons and pictures: slicing squeezed them). Returns the mask, or nil.
function UI.RoundMask(owner, box, radius, textures, opts)
  opts = opts or {}
  if type(owner) ~= "table" or type(owner.CreateMaskTexture) ~= "function" or type(radius) ~= "number" then
    return nil
  end
  local size
  for _, r in ipairs(MASK_RADII) do
    if r <= radius then
      size = r
    end
  end
  if not size then
    return nil
  end
  local ok, mask = pcall(owner.CreateMaskTexture, owner)
  if not ok or type(mask) ~= "table" then
    return nil
  end
  mask:SetTexture(UI.MASK_PATH .. size, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  -- Only flat fills (bars, the scroll thumb) take a nine-sliced mask: on a picture (item / spell icons) the game
  -- squeezed the icon itself into a few pixels (in game 2026-11-19: bag and action icons drawn as specks on black).
  -- Icons are near-square, so the plain 32 px mask stretched over them keeps about the same corner.
  local sliced = opts.sliced and type(mask.SetTextureSliceMargins) == "function"
    and pcall(mask.SetTextureSliceMargins, mask, size, size, size, size) or false
  if sliced and type(mask.SetTextureSliceMode) == "function" then
    pcall(mask.SetTextureSliceMode, mask, 0) -- Enum.UITextureSliceMode.Stretched
  end
  if opts.sliced and not sliced then
    if mask.Hide then
      mask:Hide()
    end
    return nil
  end
  local square, e = opts.square or {}, size + 2
  mask:SetPoint("TOPLEFT", box, "TOPLEFT", square.left and -e or 0, square.top and e or 0)
  mask:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", square.right and e or 0, square.bottom and -e or 0)
  mask.codexRadius, mask.codexSliced = size, sliced
  UI.AddMask(mask, textures)
  return mask
end

-- A new corner for a rounded mask (a bar whose height was set later): the largest of our radii up to `radius`.
function UI.SetMaskRadius(mask, radius)
  if type(mask) ~= "table" or type(radius) ~= "number" then
    return
  end
  local size
  for _, r in ipairs(MASK_RADII) do
    if r <= radius then
      size = r
    end
  end
  if not size or size == mask.codexRadius then
    return
  end
  mask:SetTexture(UI.MASK_PATH .. size, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if mask.codexSliced and type(mask.SetTextureSliceMargins) == "function" then
    pcall(mask.SetTextureSliceMargins, mask, size, size, size, size)
  end
  mask.codexRadius = size
end

-- Adds a mask to more textures (nil entries skipped; never errors).
function UI.AddMask(mask, textures)
  if not mask then
    return
  end
  for _, texture in pairs(textures or {}) do
    if type(texture) == "table" and type(texture.AddMaskTexture) == "function" then
      pcall(texture.AddMaskTexture, texture, mask)
    end
  end
end

-- A flat rounded fill over `box` (a frame or region), drawn as textures of `frame`. opts: layer, sublevel, inset,
-- top = true (only the top corners round: a title band). Returns the pieces; pieces.middle spans the full width.
function UI.RoundFill(frame, box, radius, color, opts)
  opts = opts or {}
  local inset, layer, sublevel = opts.inset or 0, opts.layer or "BACKGROUND", opts.sublevel
  local pieces = {}
  local function Piece()
    local piece = frame:CreateTexture(nil, layer, nil, sublevel)
    pieces[#pieces + 1] = piece
    return piece
  end
  for index, q in ipairs(QUARTERS) do
    local piece = Piece()
    if opts.top and index > 2 then
      piece.codexSquare = true
    else
      Quarter(piece, ROUND, { q[2], q[3], q[4], q[5] })
    end
    piece:SetSize(radius, radius)
    piece:SetPoint(q[1], box, q[1], q[6] * inset, q[7] * inset)
  end
  local top = Piece()
  top:SetPoint("TOPLEFT", box, "TOPLEFT", inset + radius, -inset)
  top:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -inset - radius, -inset - radius)
  local bottom = Piece()
  bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", inset + radius, inset + radius)
  bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset - radius, inset)
  local middle = Piece()
  middle:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset - radius)
  middle:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset + radius)
  pieces.middle, pieces.round = middle, true
  Paint(pieces, color)
  return pieces
end

-- A rounded hairline along the edge of `box`. opts as UI.RoundFill (layer default "BORDER"; top: square bottom).
function UI.RoundLine(frame, box, radius, color, opts)
  opts = opts or {}
  local inset, layer, sublevel = opts.inset or 0, opts.layer or "BORDER", opts.sublevel
  local size = opts.size or 1
  local pieces = {}
  local function Piece()
    local piece = frame:CreateTexture(nil, layer, nil, sublevel)
    pieces[#pieces + 1] = piece
    return piece
  end
  local corner = {}
  for index, q in ipairs(QUARTERS) do
    local piece = Piece()
    if opts.top and index > 2 then
      piece:SetSize(size, size)
      piece.codexSquare = true
    else
      Quarter(piece, ROUND_LINE, { q[2], q[3], q[4], q[5] })
      piece:SetSize(radius, radius)
    end
    piece:SetPoint(q[1], box, q[1], q[6] * inset, q[7] * inset)
    corner[index] = opts.top and index > 2 and size or radius
  end
  local top = Piece()
  top:SetPoint("TOPLEFT", box, "TOPLEFT", inset + radius, -inset)
  top:SetPoint("TOPRIGHT", box, "TOPRIGHT", -inset - radius, -inset)
  top:SetHeight(size)
  local bottom = Piece()
  bottom:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", inset + corner[3], inset)
  bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset - corner[4], inset)
  bottom:SetHeight(size)
  local left = Piece()
  left:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset - radius)
  left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", inset, inset + corner[3])
  left:SetWidth(size)
  local right = Piece()
  right:SetPoint("TOPRIGHT", box, "TOPRIGHT", -inset, -inset - radius)
  right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset + corner[4])
  right:SetWidth(size)
  pieces.round = true
  Paint(pieces, color)
  return pieces
end

-- Recolours the pieces of a UI.RoundFill / UI.RoundLine.
function UI.SetRoundColor(pieces, color, alpha)
  Paint(pieces, color, alpha)
end

function UI.ShowRound(pieces, on)
  for _, piece in ipairs(pieces) do
    piece:SetShown(on)
  end
end

-- Corner pieces (studs, rivets) from the theme, if it has them.
function UI.Corners(frame, size, inset)
  local corner = Theme(frame).corner
  if not corner or not corner.texture then
    return
  end
  size = size or corner.size or 16
  inset = inset or 1
  local pieces = {}
  for _, point in ipairs({ { "TOPLEFT", inset, -inset }, { "TOPRIGHT", -inset, -inset },
    { "BOTTOMLEFT", inset, inset }, { "BOTTOMRIGHT", -inset, inset } }) do
    local piece = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    piece:SetTexture(corner.texture)
    piece:SetSize(size, size)
    piece:SetPoint("CENTER", frame, point[1], point[2], point[3])
    if corner.color then
      piece:SetVertexColor(UI.Unpack(corner.color))
    end
    table.insert(pieces, piece)
  end
  return pieces
end

-- Look options: soft shadows and decorative strips ----------------------------------------------------------
-- Both are registered here, so ns.ApplyLook can switch them on and off live. Nothing is drawn while an
-- option is off: the pieces are made the first time they are wanted, then only shown / hidden.

local SHADOW = "Interface\\AddOns\\Codex\\Media\\Shadow" -- 64px soft falloff, cut into a nine-slice (centre unused)
local looks = {} -- every shadow / strip: { kind, frame, box, opts, pieces }
UI.looks = looks

-- The eight shadow pieces round `box`, outside it: { point, relative point, texcoords, edge = "h" / "v" }.
local SHADOW_PIECES = {
  { "BOTTOMRIGHT", "TOPLEFT", 0, 0.5, 0, 0.5 },
  { "BOTTOMLEFT", "TOPRIGHT", 0.5, 1, 0, 0.5 },
  { "TOPRIGHT", "BOTTOMLEFT", 0, 0.5, 0.5, 1 },
  { "TOPLEFT", "BOTTOMRIGHT", 0.5, 1, 0.5, 1 },
  { "BOTTOMLEFT", "TOPLEFT", 0.49, 0.51, 0, 0.5, "BOTTOMRIGHT", "TOPRIGHT", edge = "h" }, -- top
  { "TOPLEFT", "BOTTOMLEFT", 0.49, 0.51, 0.5, 1, "TOPRIGHT", "BOTTOMRIGHT", edge = "h" }, -- bottom
  { "TOPRIGHT", "TOPLEFT", 0, 0.5, 0.49, 0.51, "BOTTOMRIGHT", "BOTTOMLEFT", edge = "v" }, -- left
  { "TOPLEFT", "TOPRIGHT", 0.5, 1, 0.49, 0.51, "BOTTOMLEFT", "BOTTOMRIGHT", edge = "v" }, -- right
}

-- The theme a shadow / strip was registered in (read when it is built: the class accent may come late).
local function EntryTheme(entry)
  return entry.ink and ns.InkTheme and ns.InkTheme() or ns.Theme()
end

local function BuildShadow(entry)
  local style = EntryTheme(entry).shadow or {}
  local opts = entry.opts
  local size = opts.size or style.size or 6
  local alpha = (opts.alpha or style.alpha or 0.6) * (opts.strength or 1)
  local inset = opts.inset or 0
  -- `inset` pulls every piece in towards the middle of the box (under its border)
  local function Inward(point)
    local x = point:find("LEFT") and inset or point:find("RIGHT") and -inset or 0
    local y = point:find("TOP") and -inset or point:find("BOTTOM") and inset or 0
    return x, y
  end
  local pieces = {}
  for _, p in ipairs(SHADOW_PIECES) do
    local piece = entry.frame:CreateTexture(nil, opts.layer or "BACKGROUND", nil, opts.sublevel or -8)
    piece:SetTexture(SHADOW)
    piece:SetTexCoord(p[3], p[4], p[5], p[6])
    piece:SetVertexColor(0, 0, 0, alpha)
    local x, y = Inward(p[2])
    piece:SetPoint(p[1], entry.box, p[2], x, y)
    if p.edge then
      x, y = Inward(p[8])
      piece:SetPoint(p[7], entry.box, p[8], x, y)
      if p.edge == "h" then
        piece:SetHeight(size)
      else
        piece:SetWidth(size)
      end
    else
      piece:SetSize(size, size)
    end
    pieces[#pieces + 1] = piece
  end
  return pieces
end

-- A theme corner piece (stud, rivet) centred on (point, x) of the strip line.
local function StripPiece(entry, line, size, relative, point)
  local corner = EntryTheme(entry).corner
  local piece = entry.frame:CreateTexture(nil, entry.opts.layer or "OVERLAY", nil, 7)
  piece:SetTexture(corner.texture)
  piece:SetSize(size, size)
  piece:SetPoint("CENTER", relative or line, point or "CENTER", 0, 0)
  if corner.color then
    piece:SetVertexColor(UI.Unpack(corner.color))
  end
  return piece
end

local function BuildStrip(entry)
  local theme = EntryTheme(entry)
  local strip = theme.strip or {}
  local opts = entry.opts
  local line = entry.frame:CreateTexture(nil, opts.layer or "OVERLAY", nil, opts.sublevel or 6)
  line:SetPoint("TOPLEFT", entry.box, "TOPLEFT", opts.left or 0, opts.top or 0)
  line:SetPoint("TOPRIGHT", entry.box, "TOPRIGHT", -(opts.right or 0), opts.top or 0)
  line:SetHeight(strip.height or 2)
  local from, to = strip.from or theme.accent, strip.to or strip.from or theme.accent
  T.Gradient(line, "VERTICAL", from, to, from[4] or 1, to[4] or 1)
  local pieces = { line }
  local corner = theme.corner
  if corner and corner.texture then
    local size = opts.capSize or strip.capSize or 8
    -- caps: "both", "left", "right" or false (false where the frame has corner pieces of its own already)
    local caps = opts.caps
    if caps == nil then
      caps = "both"
    end
    if strip.caps and caps then
      if caps == "both" or caps == "left" then
        pieces[#pieces + 1] = StripPiece(entry, line, size, line, "LEFT")
      end
      if caps == "both" or caps == "right" then
        pieces[#pieces + 1] = StripPiece(entry, line, size, line, "RIGHT")
      end
    end
    local mids = opts.mids or strip.mids or 0
    if mids >= 1 then
      pieces[#pieces + 1] = StripPiece(entry, line, 6)
    end
    if mids >= 3 then
      -- at a quarter and three quarters: the centres of two see-through halves of the line
      for _, side in ipairs({ { "TOPLEFT", "BOTTOM" }, { "TOP", "BOTTOMRIGHT" } }) do
        local half = entry.frame:CreateTexture(nil, opts.layer or "OVERLAY")
        half:SetPoint("TOPLEFT", line, side[1], 0, 0)
        half:SetPoint("BOTTOMRIGHT", line, side[2], 0, 0)
        half:SetColorTexture(0, 0, 0, 0)
        pieces[#pieces + 1] = half
        pieces[#pieces + 1] = StripPiece(entry, line, 6, half, "CENTER")
      end
    end
  end
  return pieces
end

local function Wanted(entry)
  if entry.opts.off then
    return false
  end
  if not ns.LookOption(entry.kind == "shadow" and "shadows" or "strips") then
    return false
  end
  local minHeight = entry.opts.minHeight
  if minHeight then
    local height = entry.box.GetHeight and entry.box:GetHeight()
    if type(height) ~= "number" or height < minHeight then
      return false
    end
  end
  return true
end

-- Shows or hides one shadow / strip (building it the first time it's wanted).
function UI.RefreshLook(entry)
  local on = Wanted(entry)
  if on and not entry.pieces then
    entry.pieces = entry.kind == "shadow" and BuildShadow(entry) or BuildStrip(entry)
  end
  for _, piece in ipairs(entry.pieces or {}) do
    piece:SetShown(on)
  end
  return on
end

local function Register(kind, frame, box, opts)
  local entry = { kind = kind, frame = frame, box = box or frame, opts = opts or {} }
  -- on an ink surface (opts.ink, or a frame marked with UI.Ink): the ink theme's shadow and strip
  if entry.opts.ink ~= nil then
    entry.ink = entry.opts.ink and true or false
  else
    entry.ink = OnInk(frame)
  end
  looks[#looks + 1] = entry
  if entry.opts.minHeight and entry.box == frame and frame.HookScript then
    frame:HookScript("OnSizeChanged", function()
      UI.RefreshLook(entry)
    end)
  end
  UI.RefreshLook(entry)
  return entry
end

-- A soft outer shadow round `box` (a frame or region; default `frame`), drawn as textures of `frame` (the theme's
-- shadow token: alpha, size). Only while "Soft shadows" is on. opts: size, alpha, strength (alpha factor), inset
-- (pulled in under the border), layer, sublevel, minHeight, ink (true: the ink theme's shadow; default: whether
-- `frame` is on an ink surface).
function UI.Shadow(frame, box, opts)
  return Register("shadow", frame, box, opts)
end

-- The theme's decorative strip along the top edge of `box`, drawn as textures of `frame` (put it on a frame above
-- the content). Only while "Decorative strips" is on. opts: caps ("both" / "left" / "right" / false), mids (0, 1
-- or 3 pieces along it), capSize, left / right / top (offsets), layer, sublevel, minHeight (only on a box at least
-- this tall: big windows, not small bars).
function UI.Strip(frame, box, opts)
  return Register("strip", frame, box, opts)
end

-- Look options changed (Settings): shadows and strips follow at once; a new accent needs a reload.
function ns.ApplyLook()
  for _, entry in ipairs(looks) do
    UI.RefreshLook(entry)
  end
  local applied = ns.lookApplied and ns.lookApplied.accent
  local inkChanged = ns.lookApplied and ns.HasInkPanel and ns.HasInkPanel()
    and (ns.LookOption("inkHud") == true) ~= (ns.lookApplied.inkHud == true)
  if applied and ns.LookOption("accent") ~= applied or inkChanged then
    ns.pendingReload = true
    ns.Fire("RELOAD_STATE")
  end
  ns.Fire("LOOK_CHANGED")
end
ns.API.ApplyLook = ns.ApplyLook

-- Saves a look option and applies it.
function ns.SetLookOption(key, value)
  if not ns.db then
    return
  end
  ns.db.look = type(ns.db.look) == "table" and ns.db.look or {}
  ns.db.look[key] = value
  ns.ApplyLook()
end
ns.API.SetLookOption = ns.SetLookOption

-- Window background, borders and corners. opts: noCorners, cornerSize, alpha; shadow = false (no soft shadow),
-- strip = true / false (the decorative strip; default: only on windows at least 120 tall).
function UI.Panel(frame, opts)
  opts = opts or {}
  local theme = Theme(frame)
  local panel = theme.panel
  local alpha = opts.alpha or panel.alpha or 0.97
  local radius = UI.Radius(opts.radius or "window", theme)
  if radius then
    -- flat rounded panel with one hairline (Dusk, Dawn): no tile, no corner pieces
    local pieces = UI.RoundFill(frame, frame, radius, { panel.from[1], panel.from[2], panel.from[3], alpha },
      { sublevel = -8 })
    local ring = theme.rings and theme.rings[1]
    if ring then
      frame.codexLine = UI.RoundLine(frame, frame, radius, ring.color, { size = ring.size })
    end
    frame.codexShadow = UI.Shadow(frame, frame, { off = opts.shadow == false })
    if opts.strip ~= false then
      frame.codexStrip = UI.Strip(frame, frame, { caps = "both", left = radius, right = radius,
        minHeight = opts.strip ~= true and 120 or nil })
    end
    frame.codexFill, frame.codexRound = pieces.middle, pieces
    return pieces.middle
  end
  local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  T.Gradient(fill, "VERTICAL", panel.from, panel.to, alpha, alpha)
  if panel.tile then
    local tile = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    tile:SetAllPoints(fill)
    tile:SetTexture(panel.tile, "REPEAT", "REPEAT")
    if tile.SetHorizTile then
      tile:SetHorizTile(true)
      tile:SetVertTile(true)
    end
    tile:SetAlpha(panel.tileAlpha or 1)
    if panel.blend then
      tile:SetBlendMode(panel.blend)
    end
    frame.codexTile = tile
  end
  UI.Rings(frame, theme.rings)
  local corners
  if not opts.noCorners then
    corners = UI.Corners(frame, opts.cornerSize)
  end
  -- Look options: the soft shadow outside it, the strip along its top (no end caps where corner pieces sit)
  frame.codexShadow = UI.Shadow(frame, frame, { off = opts.shadow == false })
  if opts.strip ~= false then
    frame.codexStrip = UI.Strip(frame, frame, { caps = not corners and "both" or false,
      minHeight = opts.strip ~= true and 120 or nil })
  end
  frame.codexFill = fill
  return fill
end

-- Font helpers: kind "head" (theme heading font) or "body" (theme body font or the game's).
-- Texts on a light theme's own panels keep their colour codes readable (ns.Readable on every SetText /
-- SetFormattedText of the string; secret values pass untouched). Only font strings, never edit boxes.
local function KeepReadable(fontString, theme)
  if type(ns.Readable) ~= "function" or type(fontString.GetObjectType) ~= "function"
    or fontString:GetObjectType() ~= "FontString" then
    return
  end
  local had = fontString.codexReadable
  fontString.codexReadable = theme.light and theme or false
  if had ~= nil or not theme.light then
    return
  end
  local setText, setFormatted = fontString.SetText, fontString.SetFormattedText
  fontString.SetText = function(self, text, ...)
    local readable = self.codexReadable
    return setText(self, readable and ns.Readable(text, readable) or text, ...)
  end
  if type(setFormatted) == "function" then
    fontString.SetFormattedText = function(self, format, ...)
      local readable = self.codexReadable
      return setFormatted(self, readable and ns.Readable(format, readable) or format, ...)
    end
  end
end
UI.KeepReadable = KeepReadable

-- The text shadow of a theme (textShadow token): x, y, r, g, b, a.
function UI.TextShadow(theme)
  local shadow = (theme or Theme()).textShadow or {}
  local color = shadow.color or { 0, 0, 0, 0.9 }
  return shadow.x or 1, shadow.y or -1, color[1], color[2], color[3], color[4] or 1
end

-- Game texts on light ground (the light-theme rule, Theme.lua) ------------------------------------------------
-- UI.GameText(fontString, opts) keeps a font string whose colours someone else sets (the game's tooltip lines,
-- tracker objectives, chat's edit box, or a text of ours that shows game colours) readable on a light theme: its
-- colour through ns.GameColor and the colour codes in its text through ns.Readable, now and after every later
-- SetTextColor / SetVertexColor / SetText / SetFormattedText / SetFontObject (post-hooks: hooksecurefunc, so the
-- caller's code runs untouched first and stays secure). The theme's text shadow goes on it (none on light ground).
-- A secret colour or text is never read further: it stays as the game set it. Does nothing on a dark theme, on a
-- forbidden region, or on a region built by Blizzard's menu compositor (a function __index: even looking a method
-- up on those reports an error, Skins/Menus.lua). opts: theme (default ns.InkTheme()), ground (a colour, default
-- ns.Ground(theme, opts.kind)), kind ("hud" / "slot"), codes = false (colour only: edit boxes), shadow = false (keep
-- the shadow). Returns true when the text is looked after.
local gameTexts = setmetatable({}, { __mode = "k" }) -- [font string] = { theme, ground, codes, busy }
UI.gameTexts = gameTexts

local function Plain(value)
  return value ~= nil and (ns.Plain == nil or ns.Plain(value))
end

local function Composed(region)
  local ok, meta = pcall(getmetatable, region)
  return ok and type(meta) == "table" and type(rawget(meta, "__index")) == "function" or false
end

-- One pass over a text: its colour and (codes) the colour codes in it, each only when plain (never secret).
local function PaintReadable(fontString, theme, ground, codes)
  return pcall(function()
    local r, g, b, a = fontString:GetTextColor()
    if Plain(r) and Plain(g) and Plain(b) and type(r) == "number" and type(g) == "number" and type(b) == "number" then
      local c = ns.GameColor({ r, g, b }, theme, ground)
      if c[1] ~= r or c[2] ~= g or c[3] ~= b then
        fontString:SetTextColor(c[1], c[2], c[3], Plain(a) and type(a) == "number" and a or 1)
      end
    end
    if codes and fontString.GetText then
      local text = fontString:GetText()
      if type(text) == "string" and Plain(text) then
        local readable = ns.Readable(text, theme, ground)
        if readable ~= text then
          fontString:SetText(readable)
        end
      end
    end
  end)
end

-- The same pass once, without hooks (pooled lines that their owner sets again anyway, e.g. chat lines). Light
-- themes only.
function UI.ReadableNow(fontString, theme, ground, codes)
  theme = theme or (ns.InkTheme and ns.InkTheme()) or ns.Theme()
  if type(theme) ~= "table" or not theme.light or type(fontString) ~= "table" or Composed(fontString) then
    return false
  end
  return (PaintReadable(fontString, theme, ground or ns.Ground(theme), codes ~= false))
end

local function RepaintGameText(fontString)
  local state = gameTexts[fontString]
  if not state or state.busy then
    return
  end
  state.busy = true
  PaintReadable(fontString, state.theme, state.ground, state.codes)
  state.busy = false
end
UI.RepaintGameText = RepaintGameText

local GAME_TEXT_HOOKS = { "SetTextColor", "SetVertexColor", "SetText", "SetFormattedText", "SetFontObject" }

function UI.GameText(fontString, opts)
  opts = opts or {}
  local theme = opts.theme or (ns.InkTheme and ns.InkTheme()) or ns.Theme()
  if type(theme) ~= "table" or not theme.light or type(fontString) ~= "table" or Composed(fontString) then
    return false
  end
  local okType, kind = pcall(function()
    return fontString:GetObjectType()
  end)
  if not okType or (kind ~= "FontString" and kind ~= "EditBox") then
    return false
  end
  if type(fontString.IsForbidden) == "function" then
    local ok, forbidden = pcall(fontString.IsForbidden, fontString)
    if not ok or forbidden then
      return false
    end
  end
  local state = gameTexts[fontString]
  local ground = opts.ground or ns.Ground(theme, opts.kind)
  if not state then
    state = { theme = theme, ground = ground, codes = opts.codes ~= false and kind == "FontString" }
    gameTexts[fontString] = state
    -- an edit box: colour only (its text is the player's; Codex never writes text into a game edit box)
    for _, method in ipairs(kind == "EditBox" and { "SetTextColor", "SetFontObject" } or GAME_TEXT_HOOKS) do
      if type(fontString[method]) == "function" then
        pcall(hooksecurefunc, fontString, method, function(self)
          RepaintGameText(self)
        end)
      end
    end
  else
    state.theme, state.ground = theme, ground
  end
  if opts.shadow ~= false and fontString.SetShadowColor then
    local x, y, r, g, b, a = UI.TextShadow(theme)
    pcall(fontString.SetShadowOffset, fontString, x, y)
    pcall(fontString.SetShadowColor, fontString, r, g, b, a)
  end
  RepaintGameText(fontString)
  return true
end

function UI.Font(fontString, kind, size, color)
  local theme = Theme(fontString)
  local font = theme.font
  local path, scale
  if kind == "head" then
    path, scale = font.head, font.headSize or 1
  else
    path, scale = font.body, font.bodySize or 1
  end
  local ok = fontString:SetFont(path or GAME_FONT, math.floor((size or 12) * scale + 0.5), font.flags or "")
  if not ok then
    fontString:SetFont(GAME_FONT, size or 12, "")
  end
  local x, y, r, g, b, a = UI.TextShadow(theme)
  fontString:SetShadowOffset(x, y)
  fontString:SetShadowColor(r, g, b, a)
  if color then
    fontString:SetTextColor(UI.Unpack(type(color) == "string" and theme[color] or color))
  end
  KeepReadable(fontString, theme)
  return fontString
end

function UI.Text(parent, kind, size, color, layer)
  local text = parent:CreateFontString(nil, layer or "OVERLAY")
  UI.Font(text, kind or "body", size or 12, color or "text")
  text:SetJustifyH("LEFT")
  return text
end

function UI.Heading(parent, text, size)
  local heading = UI.Text(parent, "head", size or 18, "accent")
  heading:SetText(text)
  if ns.embedding then
    -- a module page built into a section (Areas.lua): the section's header already names it, so the page's own
    -- title is hidden and takes no room (what was anchored under it moves up)
    heading:SetHeight(1)
    heading:Hide()
    heading.codexEmbedded = true
  end
  return heading
end

-- A box inside a window.
function UI.Inset(parent, frame)
  frame = frame or CreateFrame("Frame", nil, parent)
  local theme = Theme(frame)
  local inset = theme.inset
  local radius = UI.Radius("box", theme)
  if radius then
    frame.codexRound = UI.RoundFill(frame, frame, radius, inset.fill, { sublevel = -6 })
    frame.codexLine = UI.RoundLine(frame, frame, radius, inset.line)
    return frame
  end
  local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  fill:SetAllPoints()
  UI.SetColor(fill, inset.fill)
  local lines = T.Outline(frame, 0, inset.line, 1, "BORDER")
  T.ColorLines(lines, inset.line, inset.line[4])
  return frame
end

function UI.Divider(parent, vertical)
  local line = parent:CreateTexture(nil, "BORDER")
  UI.SetColor(line, Theme(parent).divider)
  if vertical then
    line:SetWidth(1)
  else
    line:SetHeight(1)
  end
  return line
end

-- Buttons ------------------------------------------------------------------------------------------------

local function ButtonState(button)
  local theme = button.codexTheme or Theme(button)
  local color = button:IsEnabled() and (button.textColor or theme.button.text) or theme.muted
  button.label:SetTextColor(UI.Unpack(color, button:IsEnabled() and 1 or 0.6))
end

function UI.Button(parent, width, height, text)
  local theme = Theme(parent)
  local style = theme.button
  local button = CreateFrame("Button", nil, parent)
  button.codexTheme = theme
  button:SetSize(width or 100, height or 24)
  local radius = UI.Radius("button", theme)
  if radius then
    radius = math.min(radius, math.floor((height or 24) / 2))
    button.codexRound = UI.RoundFill(button, button, radius, style.from)
    button.codexLine = UI.RoundLine(button, button, radius, style.line)
    button.codexHover = UI.RoundFill(button, button, radius, style.hover or { 1, 1, 1, 0.12 }, { layer = "HIGHLIGHT" })
  else
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    UI.Gradient(fill, style.from, style.to)
    UI.Rings(button, { { inset = 0, color = style.line, size = 1 } })
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(fill)
    UI.SetColor(glow, style.hover or { 1, 1, 1, 0.12 })
  end
  button.label = UI.Text(button, "body", 12, style.text)
  button.label:SetPoint("LEFT", 4, 0)
  button.label:SetPoint("RIGHT", -4, 0)
  button.label:SetJustifyH("CENTER")
  button.label:SetWordWrap(false)
  button:SetFontString(button.label)
  button:SetPushedTextOffset(1, -1)
  button:HookScript("OnEnable", ButtonState)
  button:HookScript("OnDisable", ButtonState)
  if text then
    button:SetText(text)
  end
  ButtonState(button)
  return button
end

function UI.CloseButton(parent)
  local button = UI.Button(parent, 22, 22, "x")
  button:SetScript("OnClick", function()
    parent:Hide()
  end)
  return button
end

-- Check box. The label is check.label; width of the click area follows the label.
function UI.Check(parent, label)
  local theme = Theme(parent)
  local check = CreateFrame("CheckButton", nil, parent)
  check:SetSize(20, 20)
  local box = check:CreateTexture(nil, "BACKGROUND")
  box:SetPoint("TOPLEFT", 2, -2)
  box:SetPoint("BOTTOMRIGHT", -2, 2)
  UI.SetColor(box, theme.inset.fill, 0.9)
  local lines = T.Outline(check, 2, theme.button.line, 1, "BORDER")
  T.ColorLines(lines, theme.button.line)
  local glow = check:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(box)
  UI.SetColor(glow, theme.accent, 0.2)
  check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local tick = check:GetCheckedTexture()
  if tick then
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", 1, 0)
    tick:SetSize(22, 22)
    if theme.round and tick.SetDesaturated then
      tick:SetDesaturated(true) -- the game's yellow tick, greyed, so the tint is the accent (teal, not olive)
    end
    tick:SetVertexColor(UI.Unpack(theme.accent))
  end
  check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  check.label = UI.Text(check, "body", 12, "text")
  check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  check.Text = check.label
  check:SetHitRectInsets(0, -220, 0, 0)
  if label then
    check.label:SetText(label)
  end
  return check
end

function UI.EditBox(parent, width, height)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(width or 160, height or 22)
  box:SetAutoFocus(false)
  box:SetTextInsets(6, 6, 0, 0)
  UI.Inset(parent, box)
  UI.Font(box, "body", 12, "bright")
  box:SetScript("OnEscapePressed", box.ClearFocus)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  return box
end

-- Selected-state background for list rows, nav buttons and tabs.
function UI.Selection(frame)
  local select = Theme(frame).select
  local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
  texture:SetAllPoints()
  T.Gradient(texture, "HORIZONTAL", select.from, select.to, select.from[4] or 0.25, select.to[4] or 0.03)
  texture:Hide()
  if select.mark then
    -- the theme's mark: a 2px accent line on the left edge, shown and hidden with the selection
    local mark = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
    mark:SetPoint("TOPLEFT")
    mark:SetPoint("BOTTOMLEFT")
    mark:SetWidth(2)
    UI.SetColor(mark, select.mark)
    mark:Hide()
    texture.codexMark = mark
    local show, hide = texture.Show, texture.Hide
    texture.Show = function(self)
      show(self)
      mark:Show()
    end
    texture.Hide = function(self)
      hide(self)
      mark:Hide()
    end
    texture.SetShown = function(self, on)
      if on then
        self:Show()
      else
        self:Hide()
      end
    end
  end
  return texture
end

-- The colour of a selected label (select.text, else the accent).
function UI.SelectedText(theme)
  theme = theme or Theme()
  return theme.select and theme.select.text or theme.accent
end

-- Sidebar entry: icon + label, with a selected state.
function UI.NavButton(parent, width, height, icon, text)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  button.selected = UI.Selection(button)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, Theme(button).accent, 0.08)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetSize(height - 10, height - 10)
  button.icon:SetPoint("LEFT", 8, 0)
  if icon then
    button.icon:SetTexture(icon)
  end
  button.label = UI.Text(button, "body", 14, "text")
  button.label:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
  button.label:SetPoint("RIGHT", -34, 0)
  button.label:SetText(text)
  button.tag = UI.Text(button, "body", 10, "muted")
  button.tag:SetPoint("RIGHT", -8, 0)
  function button:SetSelected(on)
    self.selected:SetShown(on)
    local theme = Theme(self)
    self.label:SetTextColor(UI.Unpack(on and UI.SelectedText(theme) or (self.dim and theme.muted or theme.text)))
  end
  function button:SetDim(dim)
    self.dim = dim
    self.icon:SetDesaturated(dim)
    self.icon:SetAlpha(dim and 0.6 or 1)
    self:SetSelected(self.selected:IsShown())
  end
  return button
end

-- Row of tabs. tabs = { { id, text }, ... }; onSelect(id).
function UI.Tabs(parent, tabs, onSelect)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(26)
  local line = UI.Divider(bar)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  bar.buttons = {}
  local previous
  for _, tab in ipairs(tabs) do
    local button = CreateFrame("Button", nil, bar)
    button:SetHeight(26)
    button.id = tab.id
    button.label = UI.Text(button, "body", 13, "muted")
    button.label:SetPoint("CENTER")
    button.label:SetText(tab.text)
    button:SetWidth(button.label:GetStringWidth() + 26)
    button.underline = button:CreateTexture(nil, "ARTWORK")
    button.underline:SetPoint("BOTTOMLEFT")
    button.underline:SetPoint("BOTTOMRIGHT")
    button.underline:SetHeight(2)
    UI.SetColor(button.underline, Theme(bar).accent)
    button:SetPoint("LEFT", previous or bar, previous and "RIGHT" or "LEFT", previous and 2 or 0, 0)
    button:SetScript("OnClick", function(self)
      bar:Select(self.id)
    end)
    bar.buttons[tab.id] = button
    previous = button
  end
  function bar:Select(id)
    for tabID, button in pairs(self.buttons) do
      local on = tabID == id
      button.underline:SetShown(on)
      local theme = Theme(self)
      button.label:SetTextColor(UI.Unpack(on and UI.SelectedText(theme) or theme.muted))
    end
    self.current = id
    if onSelect then
      onSelect(id)
    end
  end
  return bar
end

-- Section label inside a page: heading font, small, in capitals, accent colour (the bag window's labels).
function UI.Section(parent, text, size)
  local label = UI.Text(parent, "head", size or 11, "accent")
  label:SetText(Theme(parent).sectionCaps == false and (text or "") or (text or ""):upper())
  return label
end

-- A picker: an inset field showing the chosen value, left aligned, no arrow after it. The caller opens a
-- menu (UI.ShowMenu) from OnClick. picker.label is the value text; SetText works as on a button.
function UI.Picker(parent, width, height)
  local theme = Theme(parent)
  local picker = CreateFrame("Button", nil, parent)
  picker:SetSize(width or 200, height or 24)
  local radius = UI.Radius("button", theme)
  if radius then
    radius = math.min(radius, math.floor((height or 24) / 2))
    picker.codexRound = UI.RoundFill(picker, picker, radius, theme.button.from)
    picker.codexLine = UI.RoundLine(picker, picker, radius, theme.button.line)
    UI.RoundFill(picker, picker, radius, { theme.accent[1], theme.accent[2], theme.accent[3], 0.08 }, { layer = "HIGHLIGHT" })
  else
    local fill = picker:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    UI.SetColor(fill, theme.inset.fill, math.max(0.6, theme.inset.fill[4] or 1)) -- design token "field"
    local lines = T.Outline(picker, 0, theme.button.line, 1, "BORDER") -- design token "fieldLine"
    T.ColorLines(lines, theme.button.line, 0.8)
    local glow = picker:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    UI.SetColor(glow, theme.accent, 0.1)
  end
  picker.label = UI.Text(picker, "body", 13, "bright")
  picker.label:SetPoint("LEFT", 10, 0)
  picker.label:SetPoint("RIGHT", -10, 0)
  picker.label:SetJustifyH("LEFT")
  picker.label:SetWordWrap(false)
  picker:SetFontString(picker.label)
  picker.codexPicker = true -- its text is a value, not an option name (the search skips it)
  return picker
end

-- "-  value  +": two small buttons round a value. stepper.less, stepper.more (buttons), stepper.value (text).
function UI.Stepper(parent, valueWidth)
  valueWidth = valueWidth or 48
  local stepper = CreateFrame("Frame", nil, parent)
  stepper:SetSize(24 + 4 + valueWidth + 4 + 24, 22)
  stepper.less = UI.Button(stepper, 24, 22, "-")
  stepper.less:SetPoint("LEFT")
  stepper.value = UI.Text(stepper, "body", 13, "bright")
  stepper.value:SetPoint("LEFT", stepper.less, "RIGHT", 4, 0)
  stepper.value:SetWidth(valueWidth)
  stepper.value:SetJustifyH("CENTER")
  stepper.more = UI.Button(stepper, 24, 22, "+")
  stepper.more:SetPoint("LEFT", stepper.value, "RIGHT", 4, 0)
  stepper.codexPicker = true -- its text is a value (the search skips it)
  return stepper
end

-- Hands a mouse wheel turn to the scroll area round `frame` (a frame that has nothing to scroll itself: a module
-- page laid into a section is as tall as its content, so the page around it scrolls instead).
function UI.ForwardWheel(frame, delta)
  local outer = frame.GetParent and frame:GetParent()
  for _ = 1, 30 do
    if type(outer) ~= "table" then
      return false
    end
    if outer.codexScrollArea then
      local wheel = outer:GetScript("OnMouseWheel")
      if wheel then
        wheel(outer, delta)
      end
      return true
    end
    outer = outer.GetParent and outer:GetParent() or nil
  end
  return false
end

-- A scrolling area: scroll (the ScrollFrame) and body (its child, size it to the content). A thin thumb on the
-- right shows where you are when the body is taller than the area. Call scroll:Update() after resizing body.
-- `kind` "EditBox": the scroll child is an edit box itself. On Forever an edit box nested one frame below the scroll
-- child draws no text at all (the user's empty Copy chat, 2026-11-21: text, font, colour, size and visibility were
-- all right; moved onto the window, or made the scroll child, it showed), so a scrolling edit box is the child.
function UI.ScrollArea(parent, kind)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local body = CreateFrame(kind == "EditBox" and "EditBox" or "Frame", nil, scroll)
  if kind == "EditBox" then
    body:SetWidth(100) -- no height: a multi-line edit box grows with its text
  else
    body:SetSize(100, 100)
  end
  scroll:SetScrollChild(body)
  local theme = Theme(parent)
  local track = scroll:CreateTexture(nil, "OVERLAY")
  track:SetPoint("TOPRIGHT")
  track:SetPoint("BOTTOMRIGHT")
  local thumb = scroll:CreateTexture(nil, "OVERLAY", nil, 1)
  if UI.Radius("button", theme) then
    -- the rounded themes: a 1 px hairline track and a 4 px pill thumb in the quiet text colour
    track:ClearAllPoints()
    track:SetPoint("TOPRIGHT", -2, 0) -- under the middle of the thumb
    track:SetPoint("BOTTOMRIGHT", -2, 0)
    track:SetWidth(1)
    UI.SetColor(track, theme.divider)
    thumb:SetWidth(4)
    UI.SetColor(thumb, theme.muted, 0.55)
    scroll.codexThumbMask = UI.RoundMask(scroll, thumb, 2, { thumb }, { sliced = true }) -- a flat fill
  else
    track:SetWidth(3)
    UI.SetColor(track, theme.inset.fill, 0.5)
    thumb:SetWidth(3)
    UI.SetColor(thumb, theme.accent, 0.6)
  end
  scroll.codexTrack, scroll.codexThumb = track, thumb
  function scroll:Update()
    local height = self:GetHeight() or 0
    local full = body:GetHeight() or 0
    local range = math.max(0, full - height)
    local offset = math.max(0, math.min(range, self:GetVerticalScroll() or 0))
    self:SetVerticalScroll(offset)
    local show = range > 1 and height > 0
    track:SetShown(show)
    thumb:SetShown(show)
    if show then
      local size = math.max(20, height * height / full)
      thumb:SetHeight(size)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(height - size) * offset / range)
    end
  end
  scroll.codexScrollArea = true
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = math.max(0, (body:GetHeight() or 0) - (self:GetHeight() or 0))
    if range <= 1 then
      UI.ForwardWheel(self, delta)
      return
    end
    self:SetVerticalScroll((self:GetVerticalScroll() or 0) - delta * 40)
    self:Update()
  end)
  scroll:SetScript("OnSizeChanged", function(self)
    self:Update()
  end)
  body:SetScript("OnSizeChanged", function()
    scroll:Update()
  end)
  scroll.body = body
  return scroll, body
end

-- Scrolling list with a fixed number of pooled rows.
-- opts: rowHeight, CreateRow(row) once per row, UpdateRow(row, item, index) on every refresh.
function UI.List(parent, opts)
  local list = CreateFrame("Frame", nil, parent)
  list.rowHeight = opts.rowHeight or 22
  list.items = {}
  list.offset = 0
  list.rows = {}
  list.codexList = true -- rows of data, not options (the search skips them)
  UI.Inset(parent, list)

  local thumb = list:CreateTexture(nil, "OVERLAY")
  thumb:SetWidth(3)
  UI.SetColor(thumb, Theme(parent).accent, 0.6)

  local function VisibleRows()
    return math.max(1, math.floor((list:GetHeight() - 4) / list.rowHeight))
  end

  function list:Refresh()
    local visible = VisibleRows()
    local maxOffset = math.max(0, #self.items - visible)
    self.offset = math.max(0, math.min(self.offset, maxOffset))
    for index = 1, visible do
      local row = self.rows[index]
      if not row then
        row = CreateFrame("Button", nil, self)
        row:SetHeight(self.rowHeight)
        row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * self.rowHeight)
        row:SetPoint("RIGHT", -6, 0)
        row.selected = UI.Selection(row)
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        UI.SetColor(hover, Theme(self).accent, 0.07)
        if opts.CreateRow then
          opts.CreateRow(row)
        end
        self.rows[index] = row
      end
      local item = self.items[index + self.offset]
      row.item = item
      row.index = index + self.offset
      if item then
        row:Show()
        if opts.UpdateRow then
          opts.UpdateRow(row, item, index + self.offset)
        end
      else
        row:Hide()
      end
    end
    for index = visible + 1, #self.rows do
      self.rows[index]:Hide()
    end
    if #self.items > visible then
      local height = self:GetHeight() - 4
      local size = math.max(16, height * visible / #self.items)
      thumb:SetHeight(size)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOPRIGHT", -1, -2 - (height - size) * (self.offset / maxOffset))
      thumb:Show()
    else
      thumb:Hide()
    end
  end

  function list:SetItems(items)
    self.items = items or {}
    self:Refresh()
  end

  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta)
    self.offset = self.offset - delta * (IsShiftKeyDown() and 10 or 3)
    self:Refresh()
  end)
  list:SetScript("OnSizeChanged", function(self)
    self:Refresh()
  end)
  return list
end

-- Popup menu (minimap right-click and similar). items = { { text, checked, disabled, title, func }, ... }
local menu
function UI.ShowMenu(anchor, items)
  if not menu then
    menu = CreateFrame("Frame", "CodexMenu", UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    UI.Panel(menu, { cornerSize = 12, strip = false })
    menu.rows = {}
    menu:EnableMouse(true)
    table.insert(UISpecialFrames, "CodexMenu")
    -- Close on a click anywhere else. The click still reaches what is under the mouse; a click on the button that
    -- opened the menu is left to that button (it opens the menu again or does its own thing).
    local function Over(frame)
      return frame and frame.IsMouseOver and frame:IsMouseOver()
    end
    menu:SetScript("OnEvent", function(self)
      if not Over(self) and not Over(self.anchor) then
        self:Hide()
      end
    end)
    menu:SetScript("OnShow", function(self)
      pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN")
    end)
    menu:SetScript("OnHide", function(self)
      pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN")
      self.anchor = nil
    end)
  end
  menu.anchor = anchor
  -- The opener's tooltip would sit on top of the menu's first rows.
  local tip = _G.GameTooltip
  if tip and tip.GetOwner and tip:GetOwner() == anchor then
    tip:Hide()
  end
  local width = 180
  for index, item in ipairs(items) do
    local row = menu.rows[index]
    if not row then
      row = CreateFrame("Button", nil, menu)
      row:SetHeight(22)
      row.check = UI.Text(row, "body", 13, "accent")
      row.check:SetPoint("LEFT", 8, 0)
      row.text = UI.Text(row, "body", 12, "text")
      row.text:SetPoint("LEFT", 26, 0)
      local hover = row:CreateTexture(nil, "HIGHLIGHT")
      hover:SetAllPoints()
      UI.SetColor(hover, Theme().accent, 0.1)
      menu.rows[index] = row
    end
    row:SetPoint("TOPLEFT", 6, -8 - (index - 1) * 22)
    row:SetPoint("RIGHT", -6, 0)
    row.check:SetText(item.checked and "+" or "")
    row.text:SetText(item.text)
    row.text:SetTextColor(UI.Unpack(item.title and Theme().accent or (item.disabled and Theme().muted or Theme().text)))
    row:SetEnabled(not item.title and not item.disabled)
    row:SetScript("OnClick", function()
      menu:Hide()
      if item.func then
        item.func()
      end
    end)
    row:Show()
    width = math.max(width, row.text:GetStringWidth() + 46)
  end
  for index = #items + 1, #menu.rows do
    menu.rows[index]:Hide()
  end
  menu:SetSize(width, #items * 22 + 16)
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
  menu:Show()
end

function UI.HideMenu()
  if menu then
    menu:Hide()
  end
end

-- An on/off switch (the switch at the top of a section, Areas.lua): a small track with a knob, the knob on the
-- right and the track in the theme's accent while on. A CheckButton, so SetChecked / GetChecked / SetEnabled and
-- a click work as on UI.Check; it redraws itself on each of them. Rounded in the rounded themes, square elsewhere.
function UI.Switch(parent)
  local theme = Theme(parent)
  local switch = CreateFrame("CheckButton", nil, parent)
  switch:SetSize(34, 18)
  switch.codexSwitch = true
  local radius = UI.Radius("button", theme) and 9 or nil
  local track, line
  if radius then
    track = UI.RoundFill(switch, switch, radius, theme.inset.fill)
    line = UI.RoundLine(switch, switch, radius, theme.button.line)
  else
    local fill = switch:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    track = { fill }
    line = T.Outline(switch, 0, theme.button.line, 1, "BORDER")
  end
  local knob = CreateFrame("Frame", nil, switch)
  knob:SetSize(12, 12)
  local knobFill
  if radius then
    knobFill = UI.RoundFill(knob, knob, 6, theme.muted, { layer = "ARTWORK" })
  else
    local fill = knob:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    knobFill = { fill }
  end
  local hover = switch:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, theme.accent, 0.12)
  switch.knob, switch.track, switch.line, switch.knobFill = knob, track, line, knobFill

  function switch:Paint()
    local colors = Theme(self)
    local on = self:GetChecked() and true or false
    local enabled = self:IsEnabled() ~= false
    knob:ClearAllPoints()
    knob:SetPoint(on and "RIGHT" or "LEFT", self, on and "RIGHT" or "LEFT", on and -3 or 3, 0)
    Paint(track, on and colors.accent or colors.inset.fill, on and 0.35 or nil)
    if line.round then
      Paint(line, on and colors.accent or colors.button.line)
    else
      T.ColorLines(line, on and colors.accent or colors.button.line)
    end
    Paint(knobFill, on and colors.accent or colors.muted)
    self:SetAlpha(enabled and 1 or 0.45)
  end
  local setChecked, setEnabled = switch.SetChecked, switch.SetEnabled
  function switch:SetChecked(value)
    setChecked(self, value)
    self:Paint()
  end
  function switch:SetEnabled(value)
    setEnabled(self, value)
    self:Paint()
  end
  switch:SetScript("PostClick", function(self)
    self:Paint()
  end)
  switch:Paint()
  return switch
end

-- A fold arrow, drawn (never a letter): a small solid triangle of 1 px textures pointing right (folded) or down
-- (open). arrow:SetOpen(on); arrow:SetColor(color).
-- A fold arrow: Media/FoldArrow.tga (branding/source/arrow-art.py, a smooth triangle drawn at 8x and scaled down)
-- pointing right when folded, turned a quarter to point down when open. The first one was drawn from 1 px texture
-- columns, whose slanted edges stepped at the screen's pixels (the user's "arrows are low quality", 2026-11-21).
-- The frame stays 9x9 for layouts; the texture is 18x18 round its middle (the triangle is about 8x10 of it).
local FOLD_ARROW = "Interface\\AddOns\\Codex\\Media\\FoldArrow"

function UI.FoldArrow(parent, color)
  local arrow = CreateFrame("Frame", nil, parent)
  arrow:SetSize(9, 9)
  arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
  arrow.icon:SetTexture(FOLD_ARROW)
  arrow.icon:SetSize(18, 18)
  arrow.icon:SetPoint("CENTER")
  function arrow:SetColor(value)
    self.icon:SetVertexColor(UI.Unpack(value))
  end
  function arrow:SetOpen(open)
    self.open = open and true or false
    -- a quarter turn clockwise for "open" (pointing down)
    if self.icon.SetRotation then
      self.icon:SetRotation(self.open and -math.pi / 2 or 0)
    end
  end
  arrow:SetColor(color or Theme(parent).muted)
  arrow:SetOpen(false)
  return arrow
end
