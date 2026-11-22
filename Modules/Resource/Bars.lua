local addonName, ns = ...

-- Personal bars, part 2: the frames (board R3-Polish, "personal bars under the player"). One plain holder
-- under the character, rows stacked from the top: health (8 px), power (6 px, mana with the five-second rule
-- spark, regeneration / energy tick), a druid's mana in a form (4 px), combo points (one pip each), then the
-- timer rows (a round icon, a 5 px bar and the time): the seal, main hand, off hand and ranged swings. A row
-- shows only while it applies (a swing row while a swing runs, and a moment after for the next one). Bars as
-- Codex's unit frames draw them: a slight vertical gradient, dark back, black line; secret health and power go
-- straight into the bars and texts. Nothing here is secure, so the bars may change and move in combat; the
-- holder takes no clicks. While Edit Mode is open a mover box lies over it (drag it; right-click puts it back),
-- saved in CodexDB.resource.pos; the seal and swing rows show samples then. Built only by Enable.
--
-- Text (CodexDB.resource.text): none, amount, percentage or both ("4,820 · 75%"), centred on the health, power
-- and druid mana bars (taller then). The amount follows Settings' short numbers; the percent is the game's own
-- (UnitHealthPercent / UnitPowerPercent, secret-safe), else worked out from readable values; secret values go
-- straight into SetFormattedText, and whatever fails shows the amount alone (never an error).
--
-- Layout "beside" (CodexDB.resource.layout): health upright on the left of the character, power on the right
-- (a druid's mana just outside it), filling bottom to top, sideGap apart, sideHeight tall, sideWidth wide; the
-- sparks then climb the bar. Texts sit outside the ends (health and power above the top, druid mana under its
-- bottom), so the amount fits. Combo points and the timer rows stay flat, under the upright bars, Width wide.
-- Each layout keeps its own place (pos / posBeside; the beside one saved by its top centre).
--
-- Layout "arc" (2026-11-22, the user's request): the "beside" places and sizes, the bars drawn as arcs: health "("
-- on the left, power ")" on the right (a druid's mana just outside it). The status bar fills its arc texture
-- (Media/Arc*.tga, from branding/source/arc_textures.py) bottom to top; the dark track is the same band a little
-- wider (ArcBack), no straight outline or rounded mask. A bar's frame is ARC_SCALE x sideWidth wide, so the band is
-- sideWidth thick and bulges outward; sparks sit on the band's centre line (ArcX), texts above the arcs' ends.
--
-- Show "When not full" (CodexDB.resource.show = "notfull", 2026-11-22, the user's request): the health, power and
-- druid mana bars each show only while they aren't at rest: health and druid mana below their max, power below its
-- max, or above 0 for the powers that drain when you rest (rage, runic power). Forever's UnitHealth is always secret
-- (SecretReturns) and power often is, so nothing is compared: the row's alpha comes from a step curve evaluated by
-- the game, UnitHealthPercent / UnitPowerPercent(..., curve) (forever UnitDocumentation; Blizzard's CurveConstants),
-- and goes straight into SetAlpha (it takes secrets: AllowedWhenTainted). The rows keep their places; Edit Mode
-- shows them all. Without the curve API, readable values decide (R.AtRest), and an unreadable one shows the bar.
--
-- Health in class colours (2026-11-22): with Unit frames' "Health bars in class colours" (ns.ClassHealth) the health
-- bar takes your class colour, shaded as the unit frames' (R.RefreshHealthColor when the setting changes).

local R = ns.resource
local T = ns.T
local CanRead, Readable = R.CanRead, R.Readable

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\Codex\\Modules\\Resource\\Media\\"
local ARC = { left = MEDIA .. "Arc", right = MEDIA .. "ArcRight" }
local ARC_BACK = { left = MEDIA .. "ArcBack", right = MEDIA .. "ArcRightBack" }
-- the textures' geometry (arc_textures.py): 64 x 256, a 16 px band whose centre line is a circle of radius
-- ARC_RADIUS around (ARC_CX, 128); its ends at x = ARC_END
local ARC_W, ARC_H, ARC_BAND, ARC_END, ARC_RADIUS, ARC_CX = 64, 256, 16, 55, 201.09, 210.09
local ARC_SCALE = math.floor(ARC_W / ARC_BAND) -- 4 (whole pixels)
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local BAR_FONT = "Fonts\\ARIALN.TTF"
local GAP, TIMER_GAP, ICON, PIP_GAP = 4, 3, 14, 3 -- between rows, more before the first timer row, icon size
local HEIGHTS = { health = 8, power = 6, druid = 4, combo = 5, timer = 5 }
local NUMBER_HEIGHTS = { health = 14, power = 10, druid = 10 } -- with text on them (the boards' unit frame bars)
local TEXT_SIZES = { health = 11, power = 9, druid = 9 }
local SIDE_TEXT_SIZES = { health = 12, power = 11, druid = 10 } -- outside the upright bars, outlined
local PAIR_GAP, TEXT_LINE = 3, 13 -- upright: power to druid mana; the druid text's line under its bar

-- colours from the design: { bottom, top } of the vertical gradient (as Codex's unit frames)
local HEALTH = { { 0.11, 0.54, 0.11 }, { 0.27, 0.84, 0.27 } }
local POWER = {
  MANA = { { 0.11, 0.26, 0.66 }, { 0.29, 0.53, 1 } },
  RAGE = { { 0.55, 0.07, 0.07 }, { 0.92, 0.22, 0.22 } },
  ENERGY = { { 0.72, 0.58, 0.05 }, { 1, 0.88, 0.25 } },
  FOCUS = { { 0.66, 0.32, 0.1 }, { 1, 0.6, 0.3 } },
}
local BAR_BACK = { 0.067, 0.067, 0.067, 0.85 }
local EMPTY_PIP = { 0.067, 0.067, 0.067, 0.35 } -- see-through empty slots
local BLACK = { 0, 0, 0, 1 }
local SWING_FILL = { 1, 1, 1 }
local OUT_OF_RANGE = { 0.55, 0.55, 0.55 }
local ZONE = { 1, 0.35, 0.25, 0.5 } -- the ranged swing's stand-still part
local TICK_ALPHA = 0.55 -- the regeneration tick spark, fainter than the five-second rule's
local SWING_SLOTS = { main = 16, off = 17, ranged = 18 }
local SWING_ICONS = { main = "Interface\\Icons\\INV_Sword_04", off = "Interface\\Icons\\INV_Sword_04",
  ranged = "Interface\\Icons\\INV_Weapon_Bow_07" }
local SEAL_ICON = "Interface\\Icons\\Spell_Holy_RighteousnessAura"
local COMBO_MAX = 5
local ORDER = { "health", "power", "druid", "combo", "seal", "main", "off", "ranged" }
local GLIDE_UP, GLIDE_DOWN = 1.8, 0.2

local unpack = unpack or table.unpack
local holder, mover
local rows = {}
local layoutKey -- what the last layout showed, so it only runs again on a change
local awake = false
local gliding = {} -- [bar] = { from, to, start, length }
local st = R.state

-- Drawing -------------------------------------------------------------------------------------------------------

-- (an upright bar's gradient runs across it, left to right, so it doesn't change as the bar fills)
local function Paint(bar, colors)
  bar.paint = colors
  local bottom, top = colors[1], colors[2]
  bar:SetStatusBarColor(top[1], top[2], top[3])
  local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if type(texture) == "table" and texture.SetGradient and CreateColor then
    pcall(texture.SetGradient, texture, bar.vertical and "HORIZONTAL" or "VERTICAL",
      CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
  end
end

-- Flat (fills left to right) or upright (bottom to top).
local function Orient(bar, vertical)
  vertical = vertical and true or false
  if bar.vertical == vertical then
    return
  end
  bar.vertical = vertical
  bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
  if bar.paint then
    Paint(bar, bar.paint)
  end
end

-- The theme's fill for small timer bars: its accent, a little darker at the bottom.
local function AccentColors()
  local accent = ns.InkTheme().accent
  return { { accent[1] * 0.7, accent[2] * 0.7, accent[3] * 0.7 }, { accent[1], accent[2], accent[3] } }
end

local function Bar(parent, colors, back)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture(WHITE)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  local fill = bar:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(bar)
  fill:SetColorTexture(unpack(back or BAR_BACK))
  bar.back, bar.backColor = fill, back or BAR_BACK
  -- the black line and the texts on a layer above the fill
  local top = CreateFrame("Frame", nil, bar)
  top:SetAllPoints(bar)
  top:SetFrameLevel((bar:GetFrameLevel() or 1) + 2)
  -- a rounded theme (round.bar: Dusk, Dawn): fill and track cut by a rounded mask, no black line. Sized later
  -- (and turned upright), so the corner is capped at 2 px: the thinnest rows (druid mana) are 4 px.
  local radius = ns.UI.Radius("bar", ns.InkTheme())
  local mask = radius and ns.UI.RoundMask(bar, bar, math.min(radius, 2),
    { bar:GetStatusBarTexture(), fill }, { sliced = true })
  if mask then
    bar.mask = mask
  else
    bar.outline = T.Outline(top, 0, BLACK, 1, "BORDER")
  end
  if colors then
    Paint(bar, colors)
  end
  bar.top = top
  return bar
end

-- A bar as an arc (side "left" = "(", "right" = ")") or back to a straight bar (nil).
local function SetArc(bar, side)
  if bar.arc == side then
    return
  end
  bar.arc = side
  local fill, back = bar:GetStatusBarTexture(), bar.back
  if bar.mask and fill then
    pcall(fill.RemoveMaskTexture, fill, bar.mask)
    pcall(back.RemoveMaskTexture, back, bar.mask)
  end
  if side then
    bar:SetStatusBarTexture(ARC[side])
    back:SetTexture(ARC_BACK[side])
    back:SetVertexColor(unpack(bar.backColor))
  else
    bar:SetStatusBarTexture(WHITE)
    back:SetColorTexture(unpack(bar.backColor))
    back:SetVertexColor(1, 1, 1, 1)
    fill = bar:GetStatusBarTexture()
    if bar.mask and fill then
      pcall(fill.AddMaskTexture, fill, bar.mask)
      pcall(back.AddMaskTexture, back, bar.mask)
    end
  end
  for _, line in ipairs(bar.outline or {}) do
    line:SetShown(not side)
  end
  if bar.paint then
    Paint(bar, bar.paint)
  end
end

-- Where an arc's band is at `phase` (0 = bottom, 1 = top): x from the frame's centre, as a share of its width.
local function ArcX(phase, side)
  local dy = (phase - 0.5) * ARC_H
  local x = ARC_CX - math.sqrt(math.max(0, ARC_RADIUS * ARC_RADIUS - dy * dy))
  local share = x / ARC_W - 0.5
  return side == "right" and -share or share
end
R.ArcX = ArcX

local function SetFont(text, size, flags)
  if not text:SetFont(BAR_FONT, size, flags or "") then
    text:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "")
  end
end

local function Text(parent, size, justify)
  local text = parent:CreateFontString(nil, "OVERLAY")
  SetFont(text, size)
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  text:SetTextColor(1, 1, 1, 1)
  text:SetJustifyH(justify or "CENTER")
  text:SetWordWrap(false)
  return text
end

-- A spark on a bar: a 2 px white line with a soft glow behind it (the board's spark).
local function Spark(bar, alpha)
  local spark = CreateFrame("Frame", nil, bar)
  spark:SetFrameLevel((bar:GetFrameLevel() or 1) + 4)
  spark:SetSize(10, 12)
  local glow = spark:CreateTexture(nil, "ARTWORK")
  glow:SetTexture(SPARK)
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(spark)
  glow:SetAlpha(alpha or 1)
  local core = spark:CreateTexture(nil, "OVERLAY")
  core:SetColorTexture(1, 1, 1, alpha or 1)
  spark.glow, spark.core = glow, core
  spark:Hide()
  return spark
end

-- Across a flat bar (a 2 px upright line) or an upright one (a 2 px flat line, the glow turned with it);
-- thickness: the bar's height (flat) or width (upright).
local function OrientSpark(spark, vertical, thickness)
  local core = spark.core
  core:ClearAllPoints()
  if vertical then
    spark:SetSize(thickness + 6, 10)
    core:SetHeight(2)
    core:SetPoint("LEFT", spark, "LEFT", 0, 0)
    core:SetPoint("RIGHT", spark, "RIGHT", 0, 0)
  else
    spark:SetSize(10, thickness + 6)
    core:SetWidth(2)
    core:SetPoint("TOP", spark, "TOP", 0, 0)
    core:SetPoint("BOTTOM", spark, "BOTTOM", 0, 0)
  end
  if spark.glow.SetRotation then
    pcall(spark.glow.SetRotation, spark.glow, vertical and math.pi / 2 or 0)
  end
end

-- How long the bar is along its fill (its width, or its height when upright).
local function BarLength(bar)
  local length
  if bar.vertical then
    length = bar:GetHeight()
  else
    length = bar:GetWidth()
  end
  if type(length) ~= "number" or length <= 0 then
    length = bar.vertical and R.Size("sideHeight") or R.Width()
  end
  return length
end

local function PlaceSpark(spark, bar, phase)
  if not phase then
    spark:Hide()
    return false
  end
  spark:ClearAllPoints()
  if bar.vertical then
    local x = 0
    if bar.arc then
      local width = bar:GetWidth()
      x = ArcX(phase, bar.arc) * (type(width) == "number" and width > 0 and width or R.Size("sideWidth") * ARC_SCALE)
    end
    spark:SetPoint("CENTER", bar, "BOTTOM", x, BarLength(bar) * phase)
  else
    spark:SetPoint("CENTER", bar, "LEFT", BarLength(bar) * phase, 0)
  end
  spark:Show()
  return true
end

-- A round icon in the theme's thin ring (the line, then black), as the board's seal icon.
local function RoundIcon(parent, size)
  local ink = ns.InkTheme()
  local line = ink.titlebar and ink.titlebar.line or ink.accent
  local icon
  for index, ring in ipairs({ { line, size + 4 }, { BLACK, size + 2 }, { nil, size } }) do
    local texture = parent:CreateTexture(nil, "ARTWORK", nil, index)
    texture:SetSize(ring[2], ring[2])
    texture:SetPoint("CENTER", parent, "LEFT", size / 2 + 2, 0)
    if ring[1] then
      texture:SetColorTexture(ring[1][1], ring[1][2], ring[1][3], 1)
    else
      icon = texture
      if texture.SetTexCoord then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
    end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
  end
  return icon
end

-- Rows ----------------------------------------------------------------------------------------------------------

local function BarRow(key, colors, withText, sparks)
  local row = { key = key }
  row.frame = CreateFrame("Frame", nil, holder)
  row.bar = Bar(row.frame, colors)
  row.bar:SetAllPoints(row.frame)
  if withText then
    row.text = Text(row.bar.top, TEXT_SIZES[key])
    row.text:SetPoint("CENTER", row.bar.top, "CENTER", 0, 0)
  end
  if sparks then
    row.tick = Spark(row.bar, TICK_ALPHA)
    row.fsr = Spark(row.bar)
  end
  row.frame:Hide()
  return row
end

-- A bar row flat (text centred on it), upright or an arc (text outside an end, outlined: it sits on the world;
-- over an arc's end, which is at the inner side: `width` is the arc's frame width).
local function StyleBarRow(row, beside, height, arc, width)
  local style = not beside and "flat" or (arc or "upright") .. ":" .. tostring(width or 0)
  if row.styled ~= style then
    row.styled = style
    Orient(row.bar, beside)
    SetArc(row.bar, beside and arc or nil)
    if row.text then
      row.text:ClearAllPoints()
      -- an arc's end: (ARC_W - ARC_END) / ARC_W of its width in from its inner side
      local inset = arc and (ARC_W - ARC_END) / ARC_W * (width or 0) or 0
      local from = arc == "left" and "RIGHT" or arc == "right" and "LEFT" or ""
      local dx = arc == "left" and -inset or inset
      if not beside then
        SetFont(row.text, TEXT_SIZES[row.key])
        row.text:SetPoint("CENTER", row.bar.top, "CENTER", 0, 0)
      elseif row.key == "druid" then
        SetFont(row.text, SIDE_TEXT_SIZES[row.key], "OUTLINE")
        row.text:SetPoint("TOP", row.bar, "BOTTOM" .. from, arc and dx or 0, -3)
      else
        SetFont(row.text, SIDE_TEXT_SIZES[row.key], "OUTLINE")
        row.text:SetPoint("BOTTOM", row.bar, "TOP" .. from, arc and dx or 0, 3)
      end
    end
  end
  if row.fsr then
    OrientSpark(row.fsr, beside, height)
    OrientSpark(row.tick, beside, height)
  end
end

-- The seal and swing rows: round icon, thin bar, time.
local function TimerRow(key, colors)
  local row = { key = key, timer = true }
  local frame = CreateFrame("Frame", nil, holder)
  row.frame = frame
  row.icon = RoundIcon(frame, ICON)
  row.time = Text(frame, 10, "RIGHT")
  row.time:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
  row.time:SetWidth(26)
  row.bar = Bar(frame, colors, nil)
  row.bar:SetHeight(HEIGHTS.timer)
  row.bar:SetPoint("LEFT", frame, "LEFT", ICON + 4 + 5, 0)
  row.bar:SetPoint("RIGHT", row.time, "LEFT", -4, 0)
  frame:Hide()
  return row
end

local function SwingColor(row, color)
  if row.color == color then
    return
  end
  row.color = color
  row.bar:SetStatusBarColor(1, 1, 1)
  local texture = row.bar.GetStatusBarTexture and row.bar:GetStatusBarTexture()
  if type(texture) == "table" then
    -- the board's swing fill: brighter towards the swing
    T.Gradient(texture, "HORIZONTAL", color, color, 0.5, 1)
  end
end

local function Pip(row, index)
  local pip = Bar(row.frame, AccentColors(), EMPTY_PIP)
  -- each pip is a bar from index - 1 to index: a count (even a secret one) fills the pips up to it
  pip:SetMinMaxValues(index - 1, index)
  row.pips[index] = pip
  return pip
end

local function LayoutPips()
  local row = rows.combo
  local count = row.count or COMBO_MAX
  local width = (R.Width() - (count - 1) * PIP_GAP) / count
  for index = 1, count do
    local pip = row.pips[index] or Pip(row, index)
    pip:ClearAllPoints()
    pip:SetPoint("TOPLEFT", row.frame, "TOPLEFT", (index - 1) * (width + PIP_GAP), 0)
    pip:SetSize(width, HEIGHTS.combo)
    pip:Show()
  end
  for index = count + 1, #row.pips do
    row.pips[index]:Hide()
  end
end

-- Values --------------------------------------------------------------------------------------------------------

-- Health and power glide to a new value (as Codex's unit frames, Settings' "smooth bars"); a secret value goes to
-- the client's own easing.
local function SetBar(bar, value, glide)
  if not glide or not (ns.SmoothBars and ns.SmoothBars()) then
    gliding[bar] = nil
    bar:SetValue(value)
    return
  end
  if not CanRead(value) then
    gliding[bar] = nil
    local ease = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
    if ease == nil or not pcall(bar.SetValue, bar, value, ease) then
      bar:SetValue(value)
    end
    return
  end
  local current = bar:GetValue()
  if not CanRead(current) or type(current) ~= "number" or type(value) ~= "number" then
    gliding[bar] = nil
    bar:SetValue(value)
    return
  end
  local run = gliding[bar]
  if run and run.to == value then
    return
  end
  if value == current then
    gliding[bar] = nil
    return
  end
  gliding[bar] = { from = current, to = value, start = GetTime(), length = value > current and GLIDE_UP or GLIDE_DOWN }
  R.Wake()
end

local function Glide(now)
  local any = false
  for bar, run in pairs(gliding) do
    local t = (now - run.start) / run.length
    if t >= 1 then
      gliding[bar] = nil
      bar:SetValue(run.to)
    else
      bar:SetValue(run.from + (run.to - run.from) * (1 - (1 - t) ^ 3))
      any = true
    end
  end
  return any
end

-- The amount for "%s", as the nameplates write it: the game's short form when the player picked short numbers
-- (Settings, unit frame text), else "4,820"; a secret value as the game's helper gives it back, or as it is.
-- Never compared or joined here: a secret string goes straight to SetFormattedText.
local function Amount(value)
  if ns.UnitTextShort and ns.UnitTextShort() and type(AbbreviateNumbers) == "function" then
    local ok, out = pcall(AbbreviateNumbers, value)
    if ok and (not CanRead(out) or type(out) == "string") then
      return out
    end
  end
  if type(BreakUpLargeNumbers) == "function" then
    local ok, out = pcall(BreakUpLargeNumbers, value)
    if ok and (not CanRead(out) or type(out) == "string") then
      return out
    end
  end
  return value
end

-- The 0-100 percent: the game's (maybe secret) one, else from readable values. ok false: none to show.
local function Percent(kind, current, max, powerType)
  local curve = CurveConstants and CurveConstants.ScaleTo100
  if curve then
    local ok, percent
    if kind == "health" then
      if type(UnitHealthPercent) == "function" then
        ok, percent = pcall(UnitHealthPercent, "player", true, curve)
      end
    elseif type(UnitPowerPercent) == "function" then
      ok, percent = pcall(UnitPowerPercent, "player", powerType, false, curve)
    end
    if ok and (not CanRead(percent) or type(percent) == "number") then
      return true, percent
    end
  end
  local readCurrent, readMax = Readable(current), Readable(max)
  if type(readCurrent) == "number" and type(readMax) == "number" and readMax > 0 then
    return true, math.floor(readCurrent / readMax * 100 + 0.5)
  end
  return false
end

-- The bar's text in the page's format: none, amount, percentage or both ("4,820 · 75%"). A percent that can't
-- be shown leaves the amount; an amount that can't be written leaves the text empty.
local function WriteText(text, kind, current, max, powerType)
  local mode = R.TextMode()
  if mode == "none" then
    text:SetText("")
    return
  end
  if mode ~= "value" then
    local ok, percent = Percent(kind, current, max, powerType)
    if ok and mode == "percent" and pcall(text.SetFormattedText, text, "%.0f%%", percent) then
      return
    end
    if ok and mode == "both" and pcall(text.SetFormattedText, text, "%s \194\183 %.0f%%", Amount(current), percent) then
      return
    end
  end
  if not pcall(text.SetFormattedText, text, "%s", Amount(current)) then
    text:SetText("")
  end
end

-- Whatever goes wrong with one value, the bar keeps going.
local function SafeText(text, kind, current, max, powerType)
  if not pcall(WriteText, text, kind, current, max, powerType) then
    pcall(text.SetText, text, "")
  end
end

local function HasText()
  return R.TextMode() ~= "none"
end

-- Powers that drain to 0 when you rest (rage, runic power): "at rest" is empty, not full.
local DRAINS = { [R.RAGE] = true, [(Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6] = true }

-- Whether a bar is at rest (full; empty for rage): the "When not full" mode hides it then.
local function AtRest(key)
  local current, max, powerType
  if key == "health" then
    current, max = Readable(UnitHealth("player")), Readable(UnitHealthMax("player"))
  elseif key == "power" then
    powerType = Readable(UnitPowerType("player"))
    if powerType == nil then
      return false
    end
    current, max = Readable(UnitPower("player", powerType)), Readable(UnitPowerMax("player", powerType))
  elseif key == "druid" then
    current, max = Readable(UnitPower("player", R.MANA)), Readable(UnitPowerMax("player", R.MANA))
  end
  if type(current) ~= "number" or type(max) ~= "number" then
    return false
  end
  if powerType and DRAINS[powerType] then
    return current <= 0
  end
  return current >= max
end
R.AtRest = AtRest

-- Step curves of a percentage (0-1): 1 = shown. HIDE_FULL: shown below 100 %; HIDE_EMPTY: shown above 0.
local curves
local function Curves()
  if curves == nil then
    curves = false
    local create = C_CurveUtil and C_CurveUtil.CreateCurve
    local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
    if type(create) == "function" and step then
      local ok, full, empty = pcall(function()
        local a, b = create(), create()
        a:SetType(step)
        a:AddPoint(0, 1)
        a:AddPoint(1, 0)
        b:SetType(step)
        b:AddPoint(0, 0)
        b:AddPoint(0.001, 1)
        return a, b
      end)
      if ok and full and empty then
        curves = { full = full, empty = empty }
      end
    end
  end
  return curves or nil
end

-- The row's alpha for "When not full" (may be a secret number: only ever handed to SetAlpha).
local function RestAlpha(key)
  local c = Curves()
  if c then
    local ok, alpha
    if key == "health" and UnitHealthPercent then
      ok, alpha = pcall(UnitHealthPercent, "player", true, c.full)
    elseif key == "power" and UnitPowerPercent then
      local powerType = UnitPowerType("player")
      local drains = Readable(powerType) ~= nil and DRAINS[powerType]
      ok, alpha = pcall(UnitPowerPercent, "player", powerType, false, drains and c.empty or c.full)
    elseif key == "druid" and UnitPowerPercent then
      ok, alpha = pcall(UnitPowerPercent, "player", R.MANA, false, c.full)
    end
    if ok and alpha ~= nil then
      return alpha
    end
  end
  return AtRest(key) and 0 or 1
end
R.RestAlpha = RestAlpha
function R.ResetCurves() -- (tests: the curve API came or went)
  curves = nil
end

local function CheckRest(key)
  local row = rows[key]
  if not (row and row.frame) then
    return
  end
  if R.DB().show ~= "notfull" or st.editing then
    row.frame:SetAlpha(1)
  elseif not pcall(row.frame.SetAlpha, row.frame, RestAlpha(key)) then
    row.frame:SetAlpha(1)
  end
end

-- All three again (the setting, Edit Mode).
function R.ApplyRest()
  for _, key in ipairs({ "health", "power", "druid" }) do
    CheckRest(key)
  end
end

-- The health bar's colours: green, or your class colour with "Health bars in class colours" (as the unit frames
-- shade it: a very light colour taken down a little, the bottom at 60 %, toned on a classTone theme).
local healthShades = {}
local function HealthColors()
  if not (ns.ClassHealth and ns.ClassHealth()) then
    return HEALTH
  end
  local _, class = UnitClass("player")
  class = Readable(class)
  local c = type(class) == "string" and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    or type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class])
  if type(c) ~= "table" or type(c.r) ~= "number" then
    return HEALTH
  end
  local color = { c.r, c.g, c.b }
  local tone = TylesserCodex and TylesserCodex.ToneClass
  if type(tone) == "function" then
    local ok, toned = pcall(tone, color, ns.InkTheme())
    color = ok and type(toned) == "table" and toned or color
  end
  local r, g, b = color[1], color[2], color[3]
  if r * 0.3 + g * 0.59 + b * 0.11 > 0.75 then
    r, g, b = r * 0.82, g * 0.82, b * 0.82
  end
  local key = string.format("%.3f:%.3f:%.3f", r, g, b)
  healthShades[key] = healthShades[key] or { { r * 0.6, g * 0.6, b * 0.6 }, { r, g, b } }
  return healthShades[key]
end
R.HealthColors = HealthColors

local function UpdateHealth(glide)
  local row = rows.health
  local colors = HealthColors()
  if row.colors ~= colors then
    row.colors = colors
    Paint(row.bar, colors)
  end
  local max = UnitHealthMax("player")
  row.bar:SetMinMaxValues(0, max)
  local value = UnitHealth("player")
  SetBar(row.bar, value, glide)
  SafeText(row.text, "health", value, max)
  CheckRest("health")
end

local function PowerColors(token)
  return POWER[Readable(token)] or POWER.MANA
end

local function UpdatePower(glide)
  local row = rows.power
  local powerType, token = UnitPowerType("player")
  local max = UnitPowerMax("player", powerType)
  row.bar:SetMinMaxValues(0, max)
  local value = UnitPower("player", powerType)
  SetBar(row.bar, value, glide)
  local colors = PowerColors(token)
  if row.colors ~= colors then
    row.colors = colors
    Paint(row.bar, colors)
  end
  SafeText(row.text, "power", value, max, powerType)
  CheckRest("power")
end

-- What a cast will spend (2026-11-22, the user's request): while a spell with a cost in the bar's power is being cast,
-- a dark band over the end of the fill, as long as the cost (cost / max of the bar), so its left (bottom) edge is
-- where the power will be. The band hangs on the fill texture's moving edge, which the client places from the bar's
-- value: no current power is read, so it works while UnitPower is secret. The cost comes from
-- C_Spell.GetSpellPowerCost (not secret on Forever); an unreadable max, a cost in another power type or an arc
-- layout shows nothing. Clipped to the bar (a cost above what is left would reach past its start).
local function CostBand(row)
  local clip = CreateFrame("Frame", nil, row.bar)
  clip:SetAllPoints(row.bar)
  clip:SetFrameLevel((row.bar:GetFrameLevel() or 1) + 1)
  if clip.SetClipsChildren then
    clip:SetClipsChildren(true)
  end
  local band = clip:CreateTexture(nil, "ARTWORK")
  band:SetColorTexture(0, 0, 0, 0.5)
  local edge = clip:CreateTexture(nil, "ARTWORK", nil, 1)
  edge:SetColorTexture(1, 1, 1, 0.85)
  band:Hide()
  edge:Hide()
  row.cost, row.costEdge = band, edge
end

-- The cost of `spellID` in the player's current power type, or nil.
function R.CastCost(spellID)
  spellID = Readable(spellID)
  if not (spellID and C_Spell and C_Spell.GetSpellPowerCost) then
    return nil
  end
  local powerType = Readable((UnitPowerType("player")))
  local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
  if not (ok and type(costs) == "table" and powerType) then
    return nil
  end
  for _, info in ipairs(costs) do
    local kind, cost = Readable(info.type), Readable(info.cost)
    local needsAura = Readable(info.requiredAuraID)
    local applies = not needsAura or needsAura == 0 or Readable(info.hasRequiredAura) == true
    if kind == powerType and type(cost) == "number" and cost > 0 and applies then
      return cost, powerType
    end
  end
  return nil
end

function R.HideCost()
  local row = rows.power
  if row and row.cost then
    row.cost:Hide()
    row.costEdge:Hide()
  end
end

function R.ShowCost(spellID)
  R.HideCost()
  local row = rows.power
  if not (row and row.cost and R.DB().castCost ~= false and R.Wanted("power") and not row.bar.arc) then
    return
  end
  local cost, powerType = R.CastCost(spellID)
  local max = cost and Readable(UnitPowerMax("player", powerType))
  if not (type(max) == "number" and max > 0) then
    return
  end
  local length = BarLength(row.bar) * math.min(1, cost / max)
  local fill = row.bar:GetStatusBarTexture()
  local band, edge = row.cost, row.costEdge
  band:ClearAllPoints()
  edge:ClearAllPoints()
  if row.bar.vertical then
    band:SetPoint("TOPLEFT", fill, "TOPLEFT")
    band:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    band:SetHeight(length)
    edge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT")
    edge:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT")
    edge:SetHeight(1)
  else
    band:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    band:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    band:SetWidth(length)
    edge:SetPoint("TOPLEFT", band, "TOPLEFT")
    edge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT")
    edge:SetWidth(1)
  end
  band:Show()
  edge:Show()
end

local function UpdateDruid(glide)
  local row = rows.druid
  local max = UnitPowerMax("player", R.MANA)
  row.bar:SetMinMaxValues(0, max)
  local value = UnitPower("player", R.MANA)
  SetBar(row.bar, value, glide)
  SafeText(row.text, "druid", value, max, R.MANA)
  CheckRest("druid")
end

local function UpdateCombo()
  local row = rows.combo
  local max = Readable(UnitPowerMax("player", R.COMBO))
  local count = type(max) == "number" and max > 0 and max <= 10 and max or COMBO_MAX
  if count ~= row.count then
    row.count = count
    LayoutPips()
  end
  local points = UnitPower("player", R.COMBO)
  if Readable(points) == 0 and type(GetComboPoints) == "function" then
    local onTarget = Readable(GetComboPoints("player", "target"))
    if type(onTarget) == "number" and onTarget > 0 then
      points = onTarget
    end
  end
  for index = 1, count do
    row.pips[index]:SetValue(points)
  end
end

-- The seal row's icon and, for a secret aura, the client's own timing of the bar.
local function UpdateSeal()
  local row, seal = rows.seal, st.seal
  row.timed = false
  if not seal then
    if st.editing then
      row.icon:SetTexture(SEAL_ICON)
      row.bar:SetValue(0.47)
      row.time:SetText("14s")
    end
    return
  end
  row.icon:SetTexture(seal.icon or SEAL_ICON)
  row.bar:SetMinMaxValues(0, 1)
  local timer = Enum and Enum.StatusBarTimerDirection
  local durationOf = C_UnitAuras and C_UnitAuras.GetAuraDuration
  if seal.timer and seal.instance ~= nil and timer and type(durationOf) == "function" and row.bar.SetTimerDuration then
    local ok, duration = pcall(durationOf, "player", seal.instance)
    if ok and (not CanRead(duration) or duration ~= nil) then
      local smooth = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
      row.timed = pcall(row.bar.SetTimerDuration, row.bar, duration, smooth, timer.RemainingTime)
    end
  end
  row.shownTime = nil
end

local function UpdateSwingIcons()
  for key, slot in pairs(SWING_SLOTS) do
    local texture = type(GetInventoryItemTexture) == "function" and GetInventoryItemTexture("player", slot)
    rows[key].icon:SetTexture(texture or SWING_ICONS[key])
  end
end

-- Layout --------------------------------------------------------------------------------------------------------

local function PowerMaxZero()
  return Readable(UnitPowerMax("player", UnitPowerType("player"))) == 0
end

function R.Wanted(key)
  local db, class, editing = R.DB(), R.Class(), st.editing
  if key == "health" then
    return db.health and true or false
  elseif key == "power" then
    return db.power and not PowerMaxZero() or false
  elseif key == "druid" then
    if not db.druidMana or class ~= "DRUID" then
      return false
    end
    local powerType = R.PowerType()
    if powerType == nil or powerType == R.MANA then
      return false
    end
    local max = Readable(UnitPowerMax("player", R.MANA))
    return max == nil or max > 0
  elseif key == "combo" then
    return db.combo and (class == "ROGUE" or class == "DRUID" and R.PowerType() == R.ENERGY) or false
  elseif key == "seal" then
    return db.seal and class == "PALADIN" and (editing or st.seal ~= nil) or false
  elseif key == "main" then
    return db.swing and (editing or st.swings.main ~= nil) or false
  elseif key == "off" then
    return db.swing and st.swings.off ~= nil or false
  elseif key == "ranged" then
    return db.ranged and st.swings.ranged ~= nil or false
  end
  return false
end

local function RowHeight(row)
  if row.timer then
    return ICON
  end
  if HasText() and NUMBER_HEIGHTS[row.key] then
    return NUMBER_HEIGHTS[row.key]
  end
  return HEIGHTS[row.key]
end

local BAR_KEYS = { health = true, power = true, druid = true }

-- One flat row at y (from the holder's top), Width wide and centred: every row "under", the rest "beside".
local function PlaceFlat(row, y, beside)
  local height = RowHeight(row)
  row.frame:ClearAllPoints()
  if beside then
    row.frame:SetPoint("TOP", holder, "TOP", 0, -y)
    row.frame:SetSize(R.Width(), height)
  else
    row.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    row.frame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -y)
    row.frame:SetHeight(height)
  end
  if BAR_KEYS[row.key] then
    StyleBarRow(row, false, height)
  end
  if row.bar and row.bar.mask then
    -- the rounded theme's corner for this row's height (4 px on the 8-14 px bars, 2 on the thin ones)
    ns.UI.SetMaskRadius(row.bar.mask, math.min(ns.UI.Radius("bar", ns.InkTheme()) or 2, 4, math.floor(height / 2)))
  end
  return height
end

-- "Beside": health upright left of the gap, power right of it, a druid's mana just outside the power bar; the
-- holder is as wide as the widest part, centred on the character. Returns where the flat rows start.
local function PlaceUpright(wanted)
  local gap, tall, thick = R.Size("sideGap"), R.Size("sideHeight"), R.Size("sideWidth")
  local druidThick = math.max(4, math.floor(thick * 0.6 + 0.5))
  local arc = R.Arc()
  -- an arc's frame: ARC_SCALE times its band, so the band is `thick` and bulges outward
  local scale = arc and ARC_SCALE or 1
  -- how far the right side reaches from the gap: the power bar, and a druid's mana just outside its band
  local druidAt = wanted.power and thick + PAIR_GAP or 0
  local right = math.max(wanted.power and thick * scale or 0, wanted.druid and druidAt + druidThick * scale or 0)
  local left = wanted.health and thick * scale or 0
  holder:SetWidth(math.max(R.Width(), gap + 2 * math.max(left, right)))
  local half = math.floor(gap / 2) -- (whole pixels)
  -- { point, x, band thickness, arc side }
  local spots = {
    health = { "TOPRIGHT", -half, thick, "left" },
    power = { "TOPLEFT", half, thick, "right" },
    druid = { "TOPLEFT", half + (wanted.power and thick + PAIR_GAP or 0), druidThick, "right" },
  }
  local any = false
  for key, spot in pairs(spots) do
    local row = rows[key]
    local width = spot[3] * scale
    StyleBarRow(row, true, spot[3], arc and spot[4] or nil, width)
    if wanted[key] then
      any = true
      row.frame:ClearAllPoints()
      row.frame:SetPoint(spot[1], holder, "TOP", spot[2], 0)
      row.frame:SetSize(width, tall)
    end
  end
  if not any then
    return 0
  end
  return tall + GAP + (wanted.druid and HasText() and TEXT_LINE or 0)
end

local function Layout(force)
  local wanted, parts = {}, {}
  for _, key in ipairs(ORDER) do
    wanted[key] = R.Wanted(key)
    parts[#parts + 1] = wanted[key] and key or "-"
  end
  local beside = R.Beside()
  parts[#parts + 1] = R.Width()
  parts[#parts + 1] = R.TextMode()
  if beside then
    parts[#parts + 1] = (R.Arc() and "arc " or "beside ") .. R.Size("sideGap") .. " " .. R.Size("sideHeight") .. " "
      .. R.Size("sideWidth")
  end
  local layout = table.concat(parts, ",")
  if layout == layoutKey and not force then
    return
  end
  layoutKey = layout
  local y, timers = 0, false
  if beside then
    y = PlaceUpright(wanted)
  else
    holder:SetWidth(R.Width())
  end
  for _, key in ipairs(ORDER) do
    local row = rows[key]
    local upright = beside and BAR_KEYS[key]
    if wanted[key] then
      if not upright then
        if row.timer and not timers and y > 0 then
          y = y + TIMER_GAP
        end
        timers = timers or row.timer
        y = y + PlaceFlat(row, y, beside) + GAP
      end
      if row.text then
        row.text:SetShown(HasText())
      end
      row.frame:Show()
    else
      row.frame:Hide()
    end
  end
  holder:SetHeight(math.max(1, y - GAP))
  LayoutPips()
end
R.Layout = Layout

-- Unit frames' "Health bars in class colours" changed (SettingsUI).
function R.RefreshHealthColor()
  if holder and rows.health then
    UpdateHealth()
  end
end

-- Shown and faded as the page says (Edit Mode: always shown, full).
local function ApplyVisibility()
  local db = R.DB()
  local show = st.editing or db.show ~= "combat" or st.combat
  holder:SetShown(show and true or false)
  local faded = not st.editing and not st.combat and db.show ~= "combat" and db.fade
  holder:SetAlpha(faded and R.FADED or 1)
  R.ApplyRest() -- "When not full": each bar's own alpha
end
R.ApplyVisibility = ApplyVisibility

-- Animation (one OnUpdate, only while something moves) ----------------------------------------------------------

-- The row that shows mana: the power bar, or a druid's mana bar in a form.
local function ManaRow()
  local powerType = R.PowerType()
  if powerType == R.MANA then
    return rows.power
  end
  if rows.druid.frame:IsShown() then
    return rows.druid
  end
end

local function Sparks(now)
  local db, busy = R.DB(), false
  R.FsrPhase(now) -- (ends the five seconds even with no mana bar shown)
  local manaRow = ManaRow()
  for _, row in ipairs({ rows.power, rows.druid }) do
    local fsr, tick
    if row == manaRow then
      fsr = db.fsr and R.FsrPhase(now)
      tick = db.ticks and R.TickPhase(R.MANA, now)
    elseif row == rows.power and R.PowerType() == R.ENERGY then
      tick = db.ticks and R.TickPhase(R.ENERGY, now)
    end
    busy = PlaceSpark(row.fsr, row.bar, fsr or nil) or busy
    busy = PlaceSpark(row.tick, row.bar, tick or nil) or busy
  end
  return busy or st.fsrStart ~= nil
end

local function Timers(now)
  local busy, relayout = false, false
  -- seal
  local row = rows.seal
  if st.seal and not st.editing then
    local fraction, left = R.SealLeft(now)
    if fraction then
      busy = true
      if not row.timed then
        row.bar:SetValue(fraction)
      end
      local seconds = math.ceil(left)
      if seconds ~= row.shownTime then
        row.shownTime = seconds
        row.time:SetFormattedText("%ds", seconds)
      end
    elseif row.shownTime ~= false then
      row.shownTime = false
      row.time:SetText("")
    end
    relayout = relayout or st.seal == nil
  end
  -- swings
  for _, key in ipairs(R.SWING_KEYS) do
    row = rows[key]
    if st.swings[key] then
      local fraction, left, held = R.SwingPhase(key, now)
      if fraction then
        busy = true
        row.bar:SetValue(fraction)
        local tenth = math.floor(left * 10)
        if tenth ~= row.shownTime then
          row.shownTime = tenth
          row.time:SetFormattedText("%.1f", math.max(0, left))
        end
        SwingColor(row, st.out[key] and OUT_OF_RANGE or SWING_FILL)
        if row.zone then
          local duration = R.SwingDuration(key)
          local on = R.DB().standStill and duration and duration > 0
          if on then
            row.zone:SetWidth(math.max(1, BarLength(row.bar) * math.min(R.STAND_STILL / duration, 1)))
          end
          row.zone:SetShown(on and true or false)
        end
      elseif held then
        busy = true
        row.bar:SetValue(0)
        row.shownTime = nil
        row.time:SetText("")
        if row.zone then
          row.zone:Hide()
        end
      else
        relayout = true
      end
    end
  end
  if relayout then
    Layout()
  end
  return busy
end

local function OnUpdate()
  local now = GetTime()
  local busy = Glide(now)
  busy = Sparks(now) or busy
  busy = Timers(now) or busy
  if not busy then
    holder:SetScript("OnUpdate", nil)
    awake = false
  end
end

local function SafeUpdate()
  local ok, err = pcall(OnUpdate)
  if not ok then
    holder:SetScript("OnUpdate", nil)
    awake = false
    geterrorhandler()(err)
  end
end

function R.Wake()
  if holder and not awake then
    awake = true
    holder:SetScript("OnUpdate", SafeUpdate)
  end
end

-- Position and Edit Mode ----------------------------------------------------------------------------------------

-- Each layout has its own place: pos (under) and posBeside.
local function PosKey()
  return R.Beside() and "posBeside" or "pos"
end

local function SavedPosition()
  local pos = R.DB()[PosKey()]
  if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string" and type(pos[3]) == "number"
    and type(pos[4]) == "number" then
    return pos
  end
  return R.Beside() and R.DEFAULT_POS_BESIDE or R.DEFAULT_POS
end

local function Place()
  local pos = SavedPosition()
  holder:ClearAllPoints()
  holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

-- The holder's top left corner, so rows coming and going keep its top in place; beside, its top centre, so a
-- new gap keeps the bars round the character.
local function SavePosition()
  local key = PosKey()
  local left, top, width = holder:GetLeft(), holder:GetTop(), holder:GetWidth()
  if type(left) == "number" and type(top) == "number" then
    if key == "posBeside" and type(width) == "number" then
      R.DB()[key] = { "TOP", "BOTTOMLEFT", math.floor(left + width / 2 + 0.5), math.floor(top + 0.5) }
    else
      R.DB()[key] = { "TOPLEFT", "BOTTOMLEFT", math.floor(left + 0.5), math.floor(top + 0.5) }
    end
  else
    local point, _, relativePoint, x, y = holder:GetPoint(1)
    if type(point) == "string" and type(x) == "number" and type(y) == "number" then
      R.DB()[key] = { point, type(relativePoint) == "string" and relativePoint or point, math.floor(x + 0.5),
        math.floor(y + 0.5) }
    end
  end
  Place()
end

-- Back to the default place (of the layout in use).
function R.ResetPosition()
  R.DB()[PosKey()] = nil
  if holder then
    Place()
  end
end

local function BuildMover()
  local theme = ns.InkTheme()
  mover = CreateFrame("Frame", nil, holder)
  mover:SetFrameStrata("DIALOG")
  mover:SetPoint("TOPLEFT", holder, "TOPLEFT", -3, 3)
  mover:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 3, -3)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  local fill = mover:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(mover)
  fill:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.3)
  T.Outline(mover, 0, theme.accent, 1, "BORDER")
  local label = mover:CreateFontString(nil, "OVERLAY")
  ns.UI.Font(label, "body", 12, "bright")
  label:SetPoint("BOTTOM", mover, "TOP", 0, 3)
  label:SetText("Personal bars")
  mover:SetScript("OnDragStart", function()
    holder:StartMoving()
  end)
  mover:SetScript("OnDragStop", function()
    holder:StopMovingOrSizing()
    SavePosition()
  end)
  mover:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then
      holder:StopMovingOrSizing()
      R.ResetPosition()
    end
  end)
  mover:Hide()
end

local UpdateAll -- (below)

local function ShowMover()
  st.editing = true
  if not mover then
    BuildMover()
  end
  UpdateAll()
  -- the samples (seal, main swing)
  rows.main.bar:SetValue(0.53)
  rows.main.time:SetText("1.9")
  SwingColor(rows.main, SWING_FILL)
  mover:Show()
end

local function HideMover()
  st.editing = false
  if mover then
    mover:Hide()
  end
  holder:StopMovingOrSizing()
  rows.seal.time:SetText("")
  rows.main.time:SetText("")
  rows.main.bar:SetValue(0)
  UpdateAll()
end

local editHooked = false
local function HookEditMode()
  local manager = _G.EditModeManagerFrame
  if editHooked or type(manager) ~= "table" or not manager.HookScript then
    return
  end
  editHooked = true
  manager:HookScript("OnShow", ShowMover)
  manager:HookScript("OnHide", HideMover)
  if manager:IsShown() then
    ShowMover()
  end
end

-- Updates and events --------------------------------------------------------------------------------------------

function UpdateAll()
  R.SeedPower()
  UpdateHealth(false)
  UpdatePower(false)
  UpdateDruid(false)
  UpdateCombo()
  UpdateSeal()
  UpdateSwingIcons()
  Layout()
  ApplyVisibility()
  R.Wake()
end

-- After a change on the page.
function R.Refresh()
  if not holder then
    return
  end
  Place() -- (the layout may have changed, and each has its own place)
  Layout(true)
  UpdateAll()
end

local function PowerEvent(token, glide)
  token = Readable(token)
  if token == nil or token == "MANA" then
    R.PowerChanged(R.MANA)
  end
  if token == nil or token == "ENERGY" then
    R.PowerChanged(R.ENERGY)
  end
  UpdatePower(glide)
  if token == nil or token == "MANA" then
    UpdateDruid(glide)
  end
  if token == nil or token == "COMBO_POINTS" then
    UpdateCombo()
  end
  Layout()
  R.Wake()
end

local HANDLERS = {
  UNIT_HEALTH = function() UpdateHealth(true) end,
  UNIT_MAXHEALTH = function() UpdateHealth(false) end,
  UNIT_POWER_UPDATE = function(token) PowerEvent(token, true) end,
  UNIT_POWER_FREQUENT = function(token) PowerEvent(token, true) end,
  UNIT_MAXPOWER = function(token) PowerEvent(token, false) end,
  UNIT_DISPLAYPOWER = function() UpdateAll() end,
  UPDATE_SHAPESHIFT_FORM = function() UpdateAll() end,
  UNIT_SPELLCAST_START = function(_, spellID) R.ShowCost(spellID) end,
  UNIT_SPELLCAST_STOP = function() R.HideCost() end,
  UNIT_SPELLCAST_FAILED = function() R.HideCost() end,
  UNIT_SPELLCAST_INTERRUPTED = function() R.HideCost() end,
  UNIT_SPELLCAST_SUCCEEDED = function(_, spellID)
    R.HideCost()
    R.SpellSucceeded(spellID)
    UpdateSeal()
    Layout()
    R.Wake()
  end,
  UNIT_AURA = function()
    if R.DB().seal and R.Class() == "PALADIN" then
      R.ScanSeal()
      UpdateSeal()
      Layout()
      R.Wake()
    end
  end,
  PLAYER_SWING = function(duration, swingType)
    local key = R.StartSwing(swingType, duration)
    if key then
      rows[key].shownTime = nil
      Layout()
      R.Wake()
    end
  end,
  PLAYER_SWING_RANGE_UPDATE = function(swingType, inRange, checked)
    R.SwingRange(swingType, inRange, checked)
  end,
  UNIT_ATTACK_SPEED = function() R.RescaleSwings() end,
  PLAYER_DEAD = function() R.EndSwings() end,
  PLAYER_EQUIPMENT_CHANGED = function() UpdateSwingIcons() end,
  PLAYER_TARGET_CHANGED = function() UpdateCombo() end,
  COMBO_TARGET_CHANGED = function() UpdateCombo() end,
  PLAYER_REGEN_DISABLED = function()
    st.combat = true
    ApplyVisibility()
  end,
  PLAYER_REGEN_ENABLED = function()
    st.combat = false
    ApplyVisibility()
  end,
  PLAYER_ENTERING_WORLD = function()
    st.combat = InCombatLockdown() and true or false
    R.ScanSeal()
    UpdateAll()
  end,
  ADDON_LOADED = function(name)
    if name == "Blizzard_EditMode" then
      HookEditMode()
    end
  end,
}
local UNIT_EVENTS = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true,
  UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_AURA = true,
  UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
  UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_ATTACK_SPEED = true }

local function OnEvent(_, event, ...)
  local handler = HANDLERS[event]
  if not handler then
    return
  end
  if UNIT_EVENTS[event] then
    handler(select(2, ...))
  else
    handler(...)
  end
end

local function Build()
  holder = ns.UI.Ink(CreateFrame("Frame", nil, UIParent)) -- over the game world: the ink surfaces
  holder:SetSize(R.Width(), 10)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  R.holder = holder
  -- a theme may turn the status colours down (status token: Dusk, Dawn)
  local status = ns.InkTheme().status
  if type(status) == "table" then
    HEALTH = status.health or HEALTH
    POWER.MANA = status.mana or POWER.MANA
  end
  rows.health = BarRow("health", HEALTH, true)
  rows.power = BarRow("power", POWER.MANA, true, true)
  CostBand(rows.power)
  rows.druid = BarRow("druid", POWER.MANA, true, true)
  rows.combo = { key = "combo", frame = CreateFrame("Frame", nil, holder), pips = {} }
  rows.combo.frame:Hide()
  rows.seal = TimerRow("seal", AccentColors())
  for _, key in ipairs(R.SWING_KEYS) do
    rows[key] = TimerRow(key)
    SwingColor(rows[key], SWING_FILL)
  end
  -- the ranged swing's last half second: stand still for Auto Shot and wands
  local zone = rows.ranged.bar.top:CreateTexture(nil, "ARTWORK")
  zone:SetColorTexture(ZONE[1], ZONE[2], ZONE[3], ZONE[4])
  zone:SetPoint("TOPRIGHT", rows.ranged.bar, "TOPRIGHT", 0, 0)
  zone:SetPoint("BOTTOMRIGHT", rows.ranged.bar, "BOTTOMRIGHT", 0, 0)
  zone:SetWidth(1)
  zone:Hide()
  rows.ranged.zone = zone
  R.rows = rows
  holder:SetScript("OnShow", function()
    R.Wake()
  end)
end

function R.Enable()
  if holder then
    return
  end
  R.DB()
  Build()
  holder:SetScript("OnEvent", OnEvent)
  for event in pairs(HANDLERS) do
    if UNIT_EVENTS[event] then
      pcall(holder.RegisterUnitEvent, holder, event, "player")
    else
      -- (PLAYER_SWING and friends may not exist on every build: an unknown event errors)
      pcall(holder.RegisterEvent, holder, event)
    end
  end
  st.combat = InCombatLockdown() and true or false
  R.running = true
  Place()
  HookEditMode()
  R.ScanSeal()
  UpdateAll()
end
