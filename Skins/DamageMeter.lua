local addonName, ns = ...
local S = ns.S

-- Damage meter: Blizzard's own meter (Blizzard_DamageMeter, the retail one Forever ships) in the theme, as the
-- round-2 HUD board draws it. Every session window (the first, the extra ones opened from its gear menu, and
-- any made later) gets the theme's HUD box and rings (no corner studs) instead of Blizzard's dark background,
-- and a divider line under its header. The title ("DPS", the meter type dropdown) is in the heading font and
-- accent colour, the session time muted; the small header buttons (segment "C", gear, minimize, the dropdown's
-- arrow) get the theme's small button: gradient, line, hover, icon and text in the button text colour. A
-- minimized window shrinks its box to the header. Rows keep Blizzard's class colour, height and spacing; the bar
-- becomes a flat fill shaded lighter at the top over a dark track, names in a clean font with a shadow (the
-- theme's body font where the theme has one), values in the game's Arial. The breakdown window gets the box too.
--
-- The segment button shows a glyph (swords = current fight, sigma = overall) instead of Blizzard's letter, and
-- the minimize button is taken off the header (alpha 0, no mouse; the gear moves into its place) except while
-- the window is minimized. Apart from that nothing is moved, sized, shown or hidden, and no Blizzard layout,
-- refresh or session function is ever called: the segment changes only from Blizzard's own list (a call of
-- ours would taint the window's sessionType, which its secure refresh reads with secret values).
-- Forever pitfalls (from FlareUI, MIT, Modules/DamageMeter.lua):
-- * Never hook the rows' Init / UpdateValue or the window's SetSessionDuration / SetMinimized: secure code
--   with secret values that styling taints (:67-69). Rows are styled from the setters Blizzard calls on
--   every row it sets up (SetTextScale, :801-814; SetStyle), on the row mixin and on rows made earlier.
-- * Never call window:SetMinimized() (taints isMinimized, :212) or meter:UpdateShownState() (taints the
--   session timer, :2565-2566); both are only read here.
-- * The header art can go to alpha 0: the header buttons are not inside it (:495-496).
-- * Blizzard sets the background again in UpdateBackground: hidden again after it (:306-314).
-- Row values can be secret: they are never read; Blizzard's own texts and bars carry them.

local FLAT = "Interface\\Buttons\\WHITE8x8"
local VALUE_FONT = "Fonts\\ARIALN.TTF"
local MAX_WINDOWS = 10 -- Blizzard opens up to 3; other addons scan up to 10
local HEADER_HEIGHT = 24 -- strip height when the window has no Header to follow
local ROW_HOOKS = { "SetTextScale", "SetStyle" }

local windows = setmetatable({}, { __mode = "k" }) -- [session window] = { plate, band, depth, art = { ... } }
local rows = setmetatable({}, { __mode = "k" }) -- [row] = { bar, art = { Blizzard bar art }, flat = texture id }
local minimizers = setmetatable({}, { __mode = "k" }) -- [minimize button] = { window, plus }

local function Readable(value)
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

-- A window part through Blizzard's plain getter, else its key (the getter / key pairs FlareUI reads,
-- DamageMeter.lua:184-205).
local function Part(object, getter, key)
  if not S.Usable(object) then
    return nil
  end
  local fn = object[getter]
  if type(fn) == "function" then
    local ok, value = pcall(fn, object)
    if ok and S.Usable(value) then
      return value
    end
  end
  local value = S.Child(object, key)
  return S.Usable(value) and value or nil
end

local function Color(fontString, c)
  if S.IsRegion(fontString) and fontString.SetTextColor and c then
    fontString:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  end
end

local function Shadow(fontString)
  if fontString.SetShadowOffset then
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 0.9)
  end
end

local function ButtonLook()
  local style = S.Theme().button
  return { from = style.from, to = style.to, rings = { { inset = 0, color = style.line, size = 1 } } }
end

-- Makes every texture of a Blizzard button invisible but the ones in `keep`; returns them to hide again
-- later (Blizzard may bring its art back when a button updates).
local function KillArt(frame, keep)
  local killed = {}
  if not S.Usable(frame) or not frame.GetRegions then
    return killed
  end
  local seen = {}
  local function Kill(region)
    if S.IsRegion(region) and region:GetObjectType() == "Texture" and not keep[region] and not seen[region] then
      seen[region] = true
      S.Kill(region)
      killed[#killed + 1] = region
    end
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    Kill(region)
  end
  for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    if type(frame[getter]) == "function" then
      Kill(frame[getter](frame))
    end
  end
  return killed
end

local function Rekill(list)
  for _, region in ipairs(list or {}) do
    region:SetAlpha(0)
  end
end

-- Rows -----------------------------------------------------------------------------------------------------

-- The theme's body face at the size Blizzard (its text scale) gives the string; the game's face is kept when
-- the theme has no body font. Only the face changes: Blizzard's sizes stay the player's.
local function RowFont(fontString)
  if not S.IsRegion(fontString) then
    return
  end
  local font = S.Theme().font
  if font.body and fontString.GetFont and fontString.SetFont then
    local path, size = fontString:GetFont()
    -- Blizzard set its own face again (a new text scale): ours at Blizzard's new size
    if path ~= font.body and Readable(size) and type(size) == "number" and size > 0 then
      fontString:SetFont(font.body, math.floor(size * (font.bodySize or 1) + 0.5), "")
    end
  end
  Shadow(fontString)
end

-- The value in the game's Arial (the design's numbers), at Blizzard's size.
local function ValueFont(fontString)
  if not S.IsRegion(fontString) then
    return
  end
  if fontString.GetFont and fontString.SetFont then
    local path, size, flags = fontString:GetFont()
    if path ~= VALUE_FONT and Readable(size) and type(size) == "number" and size > 0 then
      fontString:SetFont(VALUE_FONT, size, type(flags) == "string" and flags or "")
    end
  end
  Shadow(fontString)
end

-- Blizzard's bar fill swapped for a flat one (Blizzard's class colour stays on it), Blizzard's own bar shadow
-- art hidden. Cheap when nothing changed: it runs each time Blizzard sets a row up.
local function FlatBar(look)
  local bar = look.bar
  local fill = bar:GetStatusBarTexture()
  local current = S.IsRegion(fill) and fill.GetTexture and fill:GetTexture()
  if look.flat ~= nil and Readable(current) and current == look.flat then
    return
  end
  bar:SetStatusBarTexture(FLAT)
  fill = bar:GetStatusBarTexture()
  current = S.IsRegion(fill) and fill.GetTexture and fill:GetTexture()
  look.flat = Readable(current) and current or FLAT
  Rekill(look.art)
end

local function StyleRow(row)
  if not S.Usable(row) then
    return
  end
  local look = rows[row]
  if not look then
    local bar = Part(row, "GetStatusBar", "StatusBar")
    if not bar or type(bar.GetStatusBarTexture) ~= "function" or type(bar.SetStatusBarTexture) ~= "function" then
      return
    end
    local fill = bar:GetStatusBarTexture()
    look = { bar = bar, art = KillArt(bar, { [fill or false] = true }) }
    rows[row] = look
    -- the track (design token barBg: the HUD fill darkened to 45%, at 85%; no line round it)
    local hud = S.Theme().hud.fill
    local back = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetAllPoints(bar)
    back:SetColorTexture(hud[1] * 0.45, hud[2] * 0.45, hud[3] * 0.45, 0.85)
    -- the class colour lighter at the top, darker at the bottom (the design's fill gradient): a shade over
    -- Blizzard's fill, following its width
    if S.IsRegion(fill) then
      local shade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
      shade:SetAllPoints(fill)
      S.UI.Gradient(shade, { 0, 0, 0, 0.4 }, { 0, 0, 0, 0 })
      look.shade = shade
      -- Dusk / Dawn: the class colour toned down from outside (Blizzard's own SetStatusBarColor keeps
      -- self.statusBarColor, a Lua field its refresh compares: never called from here)
      look.tone = S.ToneOverlay(bar, "ARTWORK", 6, fill)
    end
  end
  FlatBar(look)
  RowFont(Part(row, "GetName", "Name") or S.Region(look.bar, "Name"))
  ValueFont(Part(row, "GetValue", "Value") or S.Region(look.bar, "Value"))
end

-- A row made before the mixin was hooked carries Blizzard's unhooked setters: hooked on the row itself.
local function HookRow(row)
  local mixin = S.Get("DamageMeterEntryMixin")
  for _, method in ipairs(ROW_HOOKS) do
    local fn = S.Usable(row) and row[method]
    if type(fn) == "function" and not (mixin and fn == mixin[method]) and S.Once(row, "dm:" .. method) then
      S.HookMethod(row, method, StyleRow)
    end
  end
end

local function ForEachRow(scrollBox, fn)
  if not S.Usable(scrollBox) then
    return
  end
  if type(scrollBox.ForEachFrame) == "function" then
    scrollBox:ForEachFrame(fn)
  elseif type(scrollBox.EnumerateFrames) == "function" then
    for _, frame in scrollBox:EnumerateFrames() do
      fn(frame)
    end
  end
end

local function ScanRows(scrollBox)
  ForEachRow(scrollBox, function(row)
    HookRow(row)
    StyleRow(row)
  end)
end

-- The list's rows, and again after each list update (pooled rows made before the hooks come back there).
-- In a fight the look over the hooks is enough; the scan waits for the fight's end.
local function WatchList(scrollBox)
  if not S.Usable(scrollBox) then
    return
  end
  ScanRows(scrollBox)
  if S.Once(scrollBox, "dmlist") then
    S.HookMethod(scrollBox, "Update", function()
      S.Defer(scrollBox, function()
        ScanRows(scrollBox)
      end)
    end)
  end
end

-- Header ---------------------------------------------------------------------------------------------------
-- All four small buttons (the title's arrow, "C", gear, minimize) get the same square of ours, drawn on the
-- button itself (so it shows and hides with Blizzard's button). Blizzard's buttons differ in size and anchor,
-- so one size (the strip's height less 8) and one vertical centre (the strip's) are used for all: each square
-- sits on its button's horizontal centre (the arrow's 6px left of the title), moved up or down to the strip's
-- middle, measured again on every show and size change. Only Blizzard
-- art we know is a box or background goes invisible: each button's Background, its state textures where we
-- draw our own glyph, the arrow (our chevron replaces it) and the gear icon only once a gear of the game's
-- art has really loaded; otherwise Blizzard's own icon stays, tinted. Buttons are looked over again on every
-- window show (one made late is styled then) and their hidden art hidden again when they show.

local GEAR_ATLASES = { "QuestLog-icon-setting", "GM-icon-settings" }
local GEAR_FILES = { "Interface\\WorldMap\\GEAR_64GREY", "Interface\\Buttons\\UI-OptionsButton" }
local STATE_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local TITLE_GAP = 6 -- between the arrow's square and the title

-- The square's size: the header strip less a few pixels above and below.
local function BoxSize(window, depth)
  local header = Part(window, "GetHeader", "Header")
  local height = header and header.GetHeight and header:GetHeight()
  if Readable(height) and type(height) == "number" and height > 0 then
    return math.max(12, math.min(20, math.floor(height - depth - 8 + 0.5)))
  end
  return 14
end

-- Hides the named Blizzard textures of a button (`regions`, and with `states` its state textures); returns
-- them, and hides them again whenever the button shows.
local function HideKnown(button, regions, states)
  local art, seen = {}, {}
  local function Hide(region)
    if S.IsRegion(region) and region:GetObjectType() == "Texture" and not seen[region] then
      seen[region] = true
      S.Kill(region)
      art[#art + 1] = region
    end
  end
  Hide(S.Child(button, "Background"))
  for _, region in ipairs(regions or {}) do
    Hide(region)
  end
  if states then
    for _, getter in ipairs(STATE_TEXTURES) do
      if type(button[getter]) == "function" then
        Hide(button[getter](button))
      end
    end
  end
  if #art > 0 then
    S.HookScript(button, "OnShow", function()
      Rekill(art)
    end)
  end
  return art
end

local function Number(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Scale(object)
  if type(object.GetEffectiveScale) == "function" then
    local ok, scale = pcall(object.GetEffectiveScale, object)
    if ok and Number(scale) and scale > 0 then
      return scale
    end
  end
  local parent = object.GetParent and object:GetParent()
  if parent and parent ~= object then
    return Scale(parent)
  end
  return 1
end

local function MiddleY(object)
  local ok, _, y = pcall(object.GetCenter, object)
  return ok and Number(y) or nil
end

-- Every square of a window: one size from the strip, each moved to the strip's vertical middle. Only our own
-- textures move; unreadable measures keep the last place.
local function Align(window)
  local look = windows[window]
  if not look or not look.squares or not look.band then
    return
  end
  local band = look.band
  local height = Number(band:GetHeight())
  if height and height > 0 then
    look.size = math.max(12, math.min(20, math.floor(height - 8 + 0.5)))
  end
  local size = look.size
  local bandY = MiddleY(band)
  local bandScale = Scale(window)
  for _, square in ipairs(look.squares) do
    local refY = MiddleY(square.ref)
    if bandY and refY then
      square.dy = (bandY * bandScale - refY * Scale(square.ref)) / Scale(square.button)
    end
    square.anchor:SetSize(size, size)
    square.anchor:ClearAllPoints()
    square.anchor:SetPoint("CENTER", square.ref, square.point, square.x and square.x(size) or 0, square.dy or 0)
  end
end

local function AlignSoon(window)
  Align(window)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      S.Run("damagemeter", Align, window)
    end)
  end
end

-- Our square on a button, placed by Align on `ref`'s `point` (+ x(size)): gradient, line and hover inside it.
local function SmallBox(window, button, ref, point, x)
  local look = windows[window]
  local style = S.Theme().button
  local anchor = button:CreateTexture(nil, "BACKGROUND", nil, -8) -- no art: only the square's place
  anchor:SetSize(look.size, look.size)
  anchor:SetPoint("CENTER", ref, point, x and x(look.size) or 0, 0)
  look.squares = look.squares or {}
  table.insert(look.squares, { anchor = anchor, button = button, ref = ref, point = point, x = x })
  S.Plate(button, ButtonLook(), { topLeft = anchor, bottomRight = anchor, sublevel = -6 })
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
  hover:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)
  S.SetColor(hover, style.hover or { 1, 1, 1, 0.1 })
  S.HookScript(button, "OnShow", function()
    AlignSoon(window)
  end)
  return anchor
end

-- A flat bar of the button text colour.
local function Bar(button, anchor, width, height, x, y)
  local bar = button:CreateTexture(nil, "ARTWORK", nil, 7)
  bar:SetSize(width, height)
  bar:SetPoint("CENTER", anchor, "CENTER", x or 0, y or 0)
  S.SetColor(bar, S.Theme().button.text)
  return bar
end

-- A small down-pointing triangle, drawn as rows of shrinking width.
local function Chevron(button, anchor, size)
  local rows = math.max(3, math.floor(size / 4))
  for index = 0, rows - 1 do
    Bar(button, anchor, (rows - index) * 2, 1, 0, math.floor(rows / 2) - index)
  end
end

-- A gear of the game's own art on `texture`, only an atlas the client has or a file that loaded; else false.
local function GearArt(texture)
  local info = C_Texture and C_Texture.GetAtlasInfo
  if type(info) == "function" then
    for _, atlas in ipairs(GEAR_ATLASES) do
      local ok, known = pcall(info, atlas)
      if ok and known then
        texture:SetAtlas(atlas)
        local current = texture.GetAtlas and texture:GetAtlas()
        if type(current) == "string" and current:lower() == atlas:lower() then
          return true
        end
      end
    end
  end
  -- a file only when SetTexture says it loaded (it returns false for a missing file)
  for _, file in ipairs(GEAR_FILES) do
    local ok, loaded = pcall(texture.SetTexture, texture, file)
    if ok and loaded == true then
      return true
    end
  end
  texture:SetTexture(nil)
  return false
end

local function IsMinimized(window)
  if type(window.IsMinimized) == "function" then
    local ok, value = pcall(window.IsMinimized, window)
    if ok and Readable(value) then
      return value == true
    end
  end
  local container = Part(window, "GetMinimizeContainer", "MinimizeContainer")
  if container then
    return not container:IsShown()
  end
  return false
end

-- The segment glyph follows the window's segment (read only; Blizzard sets the short name on every change).
local GLYPHS = { Current = "MeterCurrent", Overall = "MeterOverall" }
local function SessionGlyph(window)
  local look = windows[window]
  local glyph = look and look.glyph
  if not glyph then
    return
  end
  local file
  local kinds = Enum and Enum.DamageMeterSessionType
  if type(kinds) == "table" and type(window.GetSessionType) == "function" then
    local ok, kind = pcall(window.GetSessionType, window)
    if ok and Readable(kind) and kind ~= nil then
      for key, name in pairs(GLYPHS) do
        if kind == kinds[key] then
          file = name
        end
      end
    end
  end
  if file then
    glyph:SetTexture("Interface\\AddOns\\Codex\\Media\\" .. file)
    glyph:Show()
  else
    glyph:Hide()
  end
  if S.IsRegion(look.label) then
    look.label:SetAlpha(file and 0 or 1)
  end
end

-- The minimize button is taken off the header (the user's choice): invisible and not clickable, the gear moves
-- into its place. While a window is minimized it comes back, so the window can still be opened again.
local function MinimizeShown(window, shown)
  local look = windows[window]
  local button = look and look.minimize
  if not button then
    return
  end
  button:SetAlpha(shown and 1 or 0)
  if button.EnableMouse then
    button:EnableMouse(shown)
  end
  local settings = Part(window, "GetSettingsDropdown", "SettingsDropdown")
  if settings and settings.ClearAllPoints and look.gearShifted ~= not shown then
    look.gearShifted = not shown
    settings:ClearAllPoints()
    if shown then
      settings:SetPoint("RIGHT", button, "LEFT", -2, -2) -- Blizzard's own anchor
    else
      settings:SetPoint("RIGHT", button, "RIGHT", 0, -2)
    end
    AlignSoon(window)
  end
end

-- Minimized: the box shrinks to the header strip; the minimize button shows "+" instead of "-".
local function FollowMinimized(window)
  local look = windows[window]
  if not look then
    return
  end
  local small = IsMinimized(window)
  local fill = look.plate.fill
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", window, "TOPLEFT")
  if small then
    fill:SetPoint("BOTTOMRIGHT", look.band, "BOTTOMRIGHT", look.depth, -(look.depth + 1))
  else
    fill:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT")
  end
  local button = look.minimize
  if button and minimizers[button] then
    minimizers[button].plus:SetShown(small)
  end
  MinimizeShown(window, small)
end

local function MinimizeButton(window, button)
  if not S.Usable(button) or not S.Once(button, "dmminimize") then
    return
  end
  local look = windows[window]
  look.minimize = button
  -- its art is the red button with the dash: our square and dash replace it
  look.art[#look.art + 1] = HideKnown(button, { S.Region(button, "Icon") }, true)
  local anchor = SmallBox(window, button, button, "CENTER")
  local arm = math.max(6, math.floor(windows[window].size / 2))
  Bar(button, anchor, arm, 2)
  local plus = Bar(button, anchor, 2, arm)
  plus:Hide()
  minimizers[button] = { window = window, plus = plus }
  S.HookScript(button, "OnClick", function()
    FollowMinimized(window)
  end)
  local container = Part(window, "GetMinimizeContainer", "MinimizeContainer")
  if container then
    S.HookScript(container, "OnShow", function()
      FollowMinimized(window)
    end)
    S.HookScript(container, "OnHide", function()
      FollowMinimized(window)
    end)
  end
  FollowMinimized(window)
end

-- Runs on every window show: each button is styled once, when it is first there.
local function StyleHeader(window, look)
  local theme = S.Theme()
  local style = theme.button
  look.size = look.size or BoxSize(window, look.depth)
  local size = look.size

  -- the title: the meter type dropdown ("DPS"); its arrow becomes a square just left of the title
  local dropdown = Part(window, "GetDamageMeterTypeDropdown", "DamageMeterTypeDropdown")
  if dropdown and S.Once(dropdown, "dmtitle") then
    local arrow = S.Region(dropdown, "Arrow")
    local title = S.Region(dropdown, "TypeName")
    if arrow or title then
      look.art[#look.art + 1] = HideKnown(dropdown, { arrow })
      local anchor
      if title then
        anchor = SmallBox(window, dropdown, title, "LEFT", function(boxSize)
          return -(TITLE_GAP + boxSize / 2)
        end)
      else
        anchor = SmallBox(window, dropdown, arrow, "CENTER")
      end
      Chevron(dropdown, anchor, size)
    end
    if title then
      S.Font(title, "head", "accent")
      S.HookMethod(title, "SetText", function()
        Color(title, theme.accent)
      end)
    end
  end

  -- the segment button: a glyph on our square (swords = current fight, sigma = overall); a past fight keeps
  -- Blizzard's number. A click still opens Blizzard's own list: the segment can only change from there.
  local session = Part(window, "GetSessionDropdown", "SessionDropdown")
  if session and S.Once(session, "dmbutton") then
    local label = S.Region(session, "SessionName")
    look.art[#look.art + 1] = HideKnown(session, {}, label ~= nil)
    local anchor = SmallBox(window, session, session, "CENTER")
    local glyph = session:CreateTexture(nil, "ARTWORK", nil, 7)
    glyph:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2, -2)
    glyph:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -2, 2)
    S.Tint(glyph, style.text)
    glyph:Hide()
    look.glyph, look.label = glyph, label
    if label then
      S.Font(label, "head", style.text)
      S.HookMethod(label, "SetText", function()
        SessionGlyph(window)
      end)
    end
    SessionGlyph(window)
  end

  -- the settings button: a gear of the game's art on our square, else Blizzard's own icon, tinted
  local settings = Part(window, "GetSettingsDropdown", "SettingsDropdown")
  if settings and S.Once(settings, "dmbutton") then
    local anchor = SmallBox(window, settings, settings, "CENTER")
    local gear = settings:CreateTexture(nil, "ARTWORK", nil, 7)
    gear:SetPoint("TOPLEFT", anchor, "TOPLEFT", 2, -2)
    gear:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -2, 2)
    local icon = S.Region(settings, "Icon") or S.Region(settings, "icon")
    if GearArt(gear) then
      S.Tint(gear, style.text)
      look.art[#look.art + 1] = HideKnown(settings, { icon }, true)
    else
      gear:Hide()
      look.art[#look.art + 1] = HideKnown(settings, {})
      if icon then
        S.Tint(icon, style.text)
      end
    end
  end

  MinimizeButton(window, Part(window, "GetMinimizeButton", "MinimizeButton"))
  AlignSoon(window)

  local timer = Part(window, "GetSessionTimerFontString", "SessionTimer")
  if S.IsRegion(timer) and S.Once(timer, "dmtimer") then
    S.Font(timer, "body", "muted")
  end
end

-- Windows --------------------------------------------------------------------------------------------------

local function HudLook()
  local hud = S.Theme().hud
  return { fill = hud.fill, rings = hud.rings }
end

-- The theme's HUD box on a window (session window or breakdown), rings and corners on a frame of ours above
-- its list. Blizzard's background goes invisible, also after Blizzard sets it again.
local function Box(window)
  local background = Part(window, "GetBackground", "Background")
  S.Kill(background)
  if type(window.UpdateBackground) == "function" then
    S.HookMethod(window, "UpdateBackground", function(self)
      S.Kill(Part(self, "GetBackground", "Background"))
    end)
  end
  local overlay = S.Overlay(window, 6)
  return S.Plate(window, HudLook(), { ringsOn = overlay })
end

local function StyleBreakdown(window)
  local source = Part(window, "GetSourceWindow", "SourceWindow")
  if not source then
    return
  end
  if S.Once(source, "dmbreakdown") then
    Box(source)
  end
  WatchList(Part(source, "GetScrollBox", "ScrollBox"))
end

-- Rows of the window, its own pinned row and its breakdown window (made late: looked for on every show).
local function StyleContent(window)
  local look = windows[window]
  if look then
    StyleHeader(window, look)
  end
  WatchList(Part(window, "GetScrollBox", "ScrollBox"))
  local own = Part(window, "GetLocalPlayerEntry", "LocalPlayerEntry")
  if own then
    HookRow(own)
    StyleRow(own)
  end
  StyleBreakdown(window)
end

local function StyleWindow(window)
  if not S.Usable(window) then
    return
  end
  if windows[window] then
    StyleContent(window)
    return
  end
  local theme = S.Theme()
  local depth = S.RingDepth(theme.hud.rings)
  local look = { depth = depth, art = {} }
  windows[window] = look

  -- the header's own art (a frame: only its textures, in case a button lives inside it)
  local header = Part(window, "GetHeader", "Header")
  if header then
    if S.IsRegion(header) then
      S.Kill(header)
    else
      look.art[#look.art + 1] = KillArt(header, {})
    end
  end
  look.plate = Box(window)

  -- the header strip: no fill of its own (the board's header sits on the HUD box), a divider line under it;
  -- the strip texture stays as the measure the squares are aligned to
  local band = window:CreateTexture(nil, "BACKGROUND", nil, -5)
  band:SetPoint("TOPLEFT", window, "TOPLEFT", depth, -depth)
  band:SetPoint("RIGHT", window, "RIGHT", -depth, 0)
  if header then
    band:SetPoint("BOTTOM", header, "BOTTOM")
  else
    band:SetHeight(HEADER_HEIGHT)
  end
  local line = window:CreateTexture(nil, "BACKGROUND", nil, -4)
  line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
  line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
  line:SetHeight(1)
  S.SetColor(line, theme.divider)
  look.band = band

  FollowMinimized(window)
  StyleContent(window)

  S.HookScript(window, "OnSizeChanged", function()
    AlignSoon(window)
  end)
  S.HookScript(window, "OnShow", function()
    for _, list in ipairs(look.art) do
      Rekill(list)
    end
    FollowMinimized(window)
    AlignSoon(window)
    S.Defer(window, function()
      StyleContent(window)
    end)
  end)
end

-- Every session window: Blizzard's named ones and any handed to SetupSessionWindow.
local known = setmetatable({}, { __mode = "k" })

local function StyleAll()
  for index = 1, MAX_WINDOWS do
    local window = S.Get("DamageMeterSessionWindow" .. index)
    if window then
      known[window] = true
    end
  end
  for window in pairs(known) do
    StyleWindow(window)
  end
end

local function Setup()
  -- rows: the mixin's setters (rows made from now on), see the header for why these
  local mixin = S.Get("DamageMeterEntryMixin")
  if mixin and S.Once(mixin, "dmrows") then
    for _, method in ipairs(ROW_HOOKS) do
      S.HookMethod(mixin, method, StyleRow)
    end
  end
  -- windows opened later (the gear menu's "Show New Window") and windows Blizzard sets up again
  local meter = S.Get("DamageMeter")
  if meter and S.Once(meter, "dmmeter") then
    S.HookMethod(meter, "SetupSessionWindow", function(_, _, data)
      local window = S.Child(data, "sessionWindow")
      if S.Usable(window) then
        known[window] = true
      end
      S.Defer("dmwindows", StyleAll)
    end)
    S.HookMethod(meter, "ShowNewSecondarySessionWindow", function()
      S.Defer("dmwindows", StyleAll)
    end)
  end
  StyleAll()
end

S.Part("damagemeter", function()
  S.OnAddOn("Blizzard_DamageMeter", Setup)
end)
