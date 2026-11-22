local addonName, ns = ...
local S = ns.S

-- Player, target, target-of-target, pet and focus frames. Unlike the other parts this one replaces Blizzard's
-- frames with Codex's own, drawn after Forever's own frame but in the theme: a big round portrait in the theme's
-- rings with a round level badge on its lower corner, and beside it one slim backdrop (HUD fill, one thin ring)
-- that runs in under the ring and carries the name (body font, as the game writes it), a health bar and a thin
-- power bar (target and focus mirrored). Blizzard's PlayerFrame, TargetFrame, FocusFrame
-- and PetFrame are parked on a hidden parent. Party members 1-4 get the same frames, a size smaller, stacked
-- on the left with their auras under each, faded out of range; Blizzard's PartyFrame is parked too, unless
-- the player uses raid-style party frames (then the party is left to those, which Raid.lua restyles). Our frames are secure unit buttons (left
-- click targets, right click opens the unit menu) that the game's unit watch shows and hides, so they work in
-- combat; they are only built and placed out of combat. Edit Mode can't move them: while Edit Mode is open each
-- frame gets a mover box to drag (saved in CodexDB.skins.frames; right-click puts it back where it started).
-- Sizes (2026-11-22, the user's request "resize unit frames in Edit Mode"): the mouse wheel over a mover scales its
-- frame in 5 % steps, 50-200 % (CodexDB.skins.frameScale[unit]; the party stack is one, "party"); Shift + right-click
-- puts it back to 100 %. A frame's offsets are in its own scale, so a saved or default position (UIParent units) is
-- divided by the scale; the party buttons each take the scale and hang from the unscaled stack holder.
-- Health and power can be secret on Forever: those values go straight into the bars and text, no maths on them.
-- Target and focus get their own cast bar and aura icons under the frame. Aura data can be secret, so the icons
-- come from Blizzard's own aura container (CustomAuraContainerTemplate): it tracks UNIT_AURA, reads the auras
-- and drives icon, timer swipe and stack count; we only dress its buttons in the theme's slot look. The cast
-- bar is timed by the client (SetTimerDuration with the cast's duration object), so secret times still run.
-- Three styles (CodexDB.skins.frameStyle, Settings > UI > Unit frames): "compact" (the default) grows the bars out of
-- the portrait: they start under it at its middle (the ring, on a layer above them, covers their end), tall
-- (health and power together about 70 % of the portrait), the name and numbers inside them, nothing behind; "panel" is the round-2 board's look with the
-- backdrop plate (and its shadow and strip) behind the column; "bars" has no portrait at all: a flat health bar
-- with the name on its left and the numbers on its right, a thinner power bar under it, the level and the
-- classification as small text below. The switch re-lays the frames out live (TylesserCodex.RefreshFrameStyle,
-- out of combat).
-- Incoming heals show on the health bars: your own heal brighter, the others' paler, shields after them, each an
-- overlay bar that starts where the health fill ends (no maths on health values: they may be secret).
-- Blizzard's player cast bar (PlayerCastingBarFrame) keeps its place, size and logic but wears Codex's look with
-- the time left (CastBar.Style); its totem timers (TotemFrame, which lives in PlayerFrame) move under our frame.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle" -- smooth 256px circle (TempPortraitAlphaMask looked jagged)
local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local BAR_FONT = "Fonts\\ARIALN.TTF"
local PARTY_STEP, PARTY_STEP_COMPACT, PARTY_STEP_BARS, PARTY_GAP, PARTY_FADE, RANGE_POLL = 88, 70, 64, 8, 0.45, 0.5
-- (party: member to member in the panel / compact / bars style, the gap; alpha out of range; how often)
local STYLES = { compact = true, panel = true, bars = true }
local RING_DEPTH = { round = 5, thin = 2 } -- how far the round rings reach out from the portrait (RoundRings)
local COMPACT_HEALTH, COMPACT_POWER = 0.5, 0.25 -- compact: bar heights as parts of the portrait's size (together,
-- with the one shared line, about 75 % of it)

-- The frame style: "compact" unless the player chose "panel" or "bars".
function ns.FrameStyle()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  local style = skins and skins.frameStyle
  return STYLES[style] and style or "compact"
end

local partyExtra = 0 -- the party frames' extra height (their saved height, Layout)
local function PartyStep()
  local style = ns.FrameStyle()
  return (style == "compact" and PARTY_STEP_COMPACT or style == "bars" and PARTY_STEP_BARS or PARTY_STEP) + partyExtra
end
local DEAD_NAME, DEAD_TEXT = { 0.6, 0.6, 0.6 }, { 0.78, 0.78, 0.78 } -- R2-Frames: a dead / offline member
local REST = { 1, 0.82, 0 } -- the "zZ" while resting
local POLL = 0.2 -- target of target has no events of its own: refreshed this often while shown
local unpack = unpack or table.unpack

-- bar colours from the design: { bottom, top } of the vertical gradient
local HEALTH = { { 0.11, 0.54, 0.11 }, { 0.27, 0.84, 0.27 } }
local POWER = {
  MANA = { { 0.11, 0.26, 0.66 }, { 0.29, 0.53, 1 } },
  RAGE = { { 0.55, 0.07, 0.07 }, { 0.92, 0.22, 0.22 } },
  ENERGY = { { 0.72, 0.58, 0.05 }, { 1, 0.88, 0.25 } },
  FOCUS = { { 0.66, 0.32, 0.1 }, { 1, 0.6, 0.3 } },
  RUNIC_POWER = { { 0, 0.42, 0.6 }, { 0.2, 0.82, 1 } },
}
local BAR_BACK = { 0.067, 0.067, 0.067, 1 }
-- incoming heals: yours, the others', shields
local HEAL_MINE, HEAL_OTHERS, ABSORB = { 0.35, 1, 0.35, 0.7 }, { 0.6, 0.9, 0.55, 0.5 }, { 0.75, 0.9, 1, 0.6 }
local BLACK = { 0, 0, 0, 1 }
local REACTION_HOSTILE, REACTION_NEUTRAL, REACTION_FRIENDLY = { 1, 0.35, 0.35 }, { 1, 0.82, 0 }, { 0.35, 0.85, 0.35 }
local TAPPED = { 0.6, 0.6, 0.6 }
-- a theme may turn the status colours down (status token: Dusk, Dawn); the theme is loaded before this folder
do
  local status = S.Theme().status
  if type(status) == "table" then
    HEALTH = status.health or HEALTH
    POWER.MANA = status.mana or POWER.MANA
    REACTION_HOSTILE = status.hostile or REACTION_HOSTILE
    REACTION_NEUTRAL = status.neutral or REACTION_NEUTRAL
    REACTION_FRIENDLY = status.friendly or REACTION_FRIENDLY
  end
end
local HOSTILE_RING = { 0.69, 0.19, 0.19 } -- the design's target ring
local DISC = { 0.055, 0.047, 0.063, 1 } -- behind the portrait
local CLASSIFICATION = { elite = "Elite", rareelite = "Rare elite", rare = "Rare", worldboss = "Boss" }
local CAST_LOCKED = { 0.55, 0.55, 0.55 } -- a cast that can't be interrupted (others: the theme's accent)
local AURA_MAX, AURA_ROW, AURA_SPACING = 16, 8, 3 -- per group (debuffs, then buffs); icons per row
local PREFIX = "|TInterface\\AddOns\\Codex\\Media\\Stud:12|t |cfff0c24eCodex:|r "
local ELITE_MARK = { elite = "nameplates-icon-elite-gold", rareelite = "nameplates-icon-elite-gold",
  worldboss = "nameplates-icon-elite-gold", rare = "nameplates-icon-elite-silver" }

-- Sizes and places from the round-2 boards (R2-HUD, R2-Frames), in the boards' coordinates: x to the right, y down
-- from the frame's top left. w, h: the clickable frame. portrait = { size, x, y }, ring "round" (roundRing) or
-- "thin" (roundRingThin), drawn outside it. back = { x, y, w, h }: the backdrop (HUD fill and the hud rings,
-- hudLine), pad = { left, right, top }: its content inset. nameSize; gap between the rows; health / power: bar
-- heights, healthText / powerText: their text sizes (no size: no text). badge = { size, x, y }: the round level
-- badge. heading: a small title above (focus). info: the creature type at the end of the name row. cast =
-- { x, y, w, icon, bar height }; auras = { x, y, size, spacing, timer under the icon }; auraMax per group (debuffs,
-- buffs), auraRow icons per row, auraOneLine: buffs follow the debuffs. attach = { unit, x, y }: sits beside that
-- frame until it is moved itself. pos: default { point, relativePoint (UIParent), x, y }. bars = { health, power, nameSize,
-- healthText, powerText }: the same for the bars-only style. compact = { -, -, healthText, powerText }: the compact
-- style's text sizes (its bar heights come from the portrait). compact = { health, power,
-- healthText, powerText }: the bars of the compact style (bigger than the board's: no panel behind them).
local UNITS = {
  { unit = "player", name = "Player", label = "Player", own = true, w = 264, h = 70, portrait = { 66, 0, 0 },
    ring = "round", back = { 32, 6, 232, 58 }, pad = { 38, 9, 5 }, nameSize = 14, gap = 3, health = 15, healthText = 11,
    power = 11, powerText = 10, badge = { 22, -3, 48 }, icons = true, compact = { 0, 0, 12, 10 }, bars = { 20, 8, 12, 11, 8 },
    pos = { "TOPLEFT", "BOTTOM", -302, 264 } },
  { unit = "target", name = "Target", label = "Target", w = 264, h = 70, portrait = { 66, 198, 0 }, ring = "round",
    back = { 0, 6, 232, 58 }, pad = { 9, 38, 5 }, nameSize = 14, gap = 3, health = 15, healthText = 11, power = 11,
    powerText = 10, badge = { 22, 245, 48 }, info = true, combo = true, cast = { 0, 70, 232, 16, 14 },
    auras = { 0, 92, 20, 6, true }, auraRow = 8, watch = true, hostileRing = true, compact = { 0, 0, 12, 10 },
    bars = { 20, 8, 12, 11, 8 },
    pos = { "TOPLEFT", "BOTTOM", 38, 264 } },
  { unit = "targettarget", name = "TargetTarget", label = "Target of target", w = 150, h = 40, portrait = { 36, 0, 2 },
    ring = "thin", back = { 18, 4, 132, 32 }, pad = { 22, 7, 2 }, nameSize = 11, gap = 2, health = 9, watch = true,
    poll = true, hostileRing = true, attach = { "target", 274, 28 }, compact = { 9 }, bars = { 14, nil, 10, 9 },
    pos = { "TOPLEFT", "BOTTOM", 312, 236 } },
  { unit = "pet", name = "Pet", label = "Pet", own = true, w = 150, h = 44, portrait = { 36, 0, 4 }, ring = "thin",
    back = { 18, 4, 132, 36 }, pad = { 22, 7, 2 }, nameSize = 11, gap = 2, health = 9, power = 4, watch = true,
    compact = { 9, 6 }, bars = { 14, 5, 10, 9 }, pos = { "TOPLEFT", "BOTTOM", -470, 250 } },
  { unit = "focus", name = "Focus", label = "Focus", heading = "Focus", w = 214, h = 64, portrait = { 44, 0, 14 },
    ring = "round", back = { 22, 18, 192, 38 }, pad = { 28, 8, 3 }, nameSize = 12, gap = 2, health = 13,
    healthText = 10, cast = { 22, 68, 192, 14, 12 }, auras = { 22, 86, 16, 4 }, auraRow = 9, watch = true,
    hostileRing = true, compact = { 0, 0, 11 }, bars = { 18, 6, 11, 10 }, pos = { "TOPLEFT", "TOPLEFT", 16, -18 } },
}
-- party1-4, stacked PARTY_STEP apart (the stack is moved as one, CodexDB.skins.frames.party)
for index = 1, 4 do
  UNITS[#UNITS + 1] = { unit = "party" .. index, name = "Party" .. index, label = "Party " .. index, party = index,
    w = 240, h = 58, portrait = { 54, 0, 0 }, ring = "round", back = { 28, 4, 212, 50 }, pad = { 32, 8, 4 },
    nameSize = 13, gap = 2, health = 14, healthText = 11, power = 10, powerText = 9, badge = { 20, -3, 38 },
    partyIcons = true, auras = { 60, 60, 16, 4 }, auraMax = { 4, 6 }, auraRow = 10, auraOneLine = true, watch = true,
    compact = { 0, 0, 11, 9 }, bars = { 18, 7, 11, 10, 8 } }
end
local PARTY_POS = { "TOPLEFT", "TOPLEFT", 16, -150 }

-- Blizzard's frames we replace (their target-of-target frames are children and go with them).
local BLIZZARD = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
local BLIZZARD_BARS = { "healthbar", "manabar", "spellbar", "castBar", "totFrame", "petFrame", "powerBarAlt" }

local frames = {} -- [unit] = our frame's state table
local placeables = {} -- what Edit Mode's movers move: the frames, and the party stack as one
local partyHolder -- the party stack (a plain frame the party buttons hang from)
local partyStack -- its entry among the placeables
local partyStyle -- raid-style party frames at build (nil: party frames not ours)
local RaidStyleParty -- (below)
local built = false
local parking -- hidden parent for Blizzard's frames

-- Secret values -------------------------------------------------------------------------------------------

local function CanRead(value)
  return type(canaccessvalue) ~= "function" or canaccessvalue(value) and true or false
end

-- The value when Lua may look at it, else nil.
local function Readable(value)
  if CanRead(value) then
    return value
  end
end

-- Calls an API that may be missing on this client.
local function Call(fn, ...)
  if type(fn) == "function" then
    return fn(...)
  end
end

-- "4,820" when readable, else the game's own abbreviation (which takes secrets), else the value as it is.
local function Number(value)
  if CanRead(value) and type(value) == "number" and type(BreakUpLargeNumbers) == "function" then
    return BreakUpLargeNumbers(value)
  end
  if type(AbbreviateNumbers) == "function" then
    return AbbreviateNumbers(value)
  end
  return value
end

-- Short numbers ("1.9K") when the player asks for them (CodexDB.skins.unitText.short), full ones otherwise.
local function ShortNumbers()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  return skins and type(skins.unitText) == "table" and skins.unitText.short == true or false
end

-- The two numbers of "cur / max". Full: "4,820" when it can be read; a secret one goes to the text as it is (all
-- digits, no separators: the secret-safe way). Short: both as the game abbreviates them (which takes
-- secrets too).
-- The game's thousands separator, tried on secret values too (this client's may take them); its result is never
-- compared (a secret string can't be). ok = false when it can't be had.
local function Separated(value)
  if type(BreakUpLargeNumbers) ~= "function" then
    return false, value
  end
  local ok, text = pcall(BreakUpLargeNumbers, value)
  if ok and (not CanRead(text) or type(text) == "string") then
    return true, text
  end
  return false, value
end

-- Both sides the same way: with separators when both can have them, else both as they are ("2186 / 2186",
-- never "2186 / 2,186").
local function Shown(current, max)
  if ShortNumbers() and type(AbbreviateNumbers) == "function" then
    return AbbreviateNumbers(current), AbbreviateNumbers(max)
  end
  local okCurrent, a = Separated(current)
  local okMax, b = Separated(max)
  if okCurrent and okMax then
    return a, b
  end
  return current, max
end

local function Values(text, current, max)
  text:SetFormattedText("%s / %s", Shown(current, max))
end

-- The player's text choice per bar (Settings, CodexDB.skins.unitText): "value" (cur / max), "percent",
-- "both" (cur · percent) or "none"; unitText.short: abbreviated numbers.
local TEXT_MODES = { value = true, percent = true, both = true, none = true }
local function TextMode(kind)
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  local choice = skins and type(skins.unitText) == "table" and skins.unitText[kind]
  return TEXT_MODES[choice] and choice or "value"
end

-- Writes a bar's text. percentOf() gives the game's (maybe secret) 0-100 number, or nothing when the API is
-- missing; then a readable current / max is worked out here, else the percent falls back to the values.
local function BarValueText(text, mode, current, max, percentOf)
  if mode == "none" then
    text:SetText("")
    return
  end
  if mode == "value" then
    Values(text, current, max)
    return
  end
  local ok, percent = false, nil
  if percentOf then
    ok, percent = pcall(percentOf)
  end
  if not ok then
    local readCurrent, readMax = Readable(current), Readable(max)
    if type(readCurrent) == "number" and type(readMax) == "number" and readMax > 0 then
      ok, percent = true, math.floor(readCurrent / readMax * 100 + 0.5)
    end
  end
  if ok and mode == "percent" and pcall(text.SetFormattedText, text, "%.0f%%", percent) then
    return
  end
  if ok and mode == "both" and pcall(text.SetFormattedText, text, "%s \194\183 %.0f%%", (Shown(current, max)), percent) then
    return
  end
  Values(text, current, max)
end

-- The game's percent functions (secret-safe, 0-100), when this client has them.
local function HealthPercentOf(unit)
  local curve = CurveConstants and CurveConstants.ScaleTo100
  if type(UnitHealthPercent) == "function" and curve then
    return function()
      local percent = UnitHealthPercent(unit, true, curve)
      assert(not CanRead(percent) or percent ~= nil)
      return percent
    end
  end
end

local function PowerPercentOf(unit, powerType)
  local curve = CurveConstants and CurveConstants.ScaleTo100
  if type(UnitPowerPercent) == "function" and curve then
    return function()
      local percent = UnitPowerPercent(unit, powerType, false, curve)
      assert(not CanRead(percent) or percent ~= nil)
      return percent
    end
  end
end

-- Drawing ---------------------------------------------------------------------------------------------------

local function Safe(fn)
  return function(...)
    S.Run("unitframes", fn, ...)
  end
end

local function SetFont(fontString, path, size, flags)
  size = math.floor(size + 0.5)
  if not (path and fontString:SetFont(path, size, flags or "")) then
    fontString:SetFont(GAME_FONT, size, flags or "")
  end
  if flags == nil or flags == "" then
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
  end
end

local function HeadFont(fontString, size)
  local font = S.Theme().font or {}
  SetFont(fontString, font.head or font.body or GAME_FONT, size * (font.head and font.headSize or 1))
end

local function BodyFont(fontString, size, path, flags)
  local font = S.Theme().font or {}
  SetFont(fontString, font.body or path or GAME_FONT, size * (font.body and font.bodySize or 1), flags)
end

local function TextColor(fontString, color)
  fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

-- A name or level on light ground (a light theme's bar track or panel: `kind` "slot", the level disc: "hud"): the
-- colour (class, reaction, difficulty) in a shade that reads 4.5:1 there, hue kept, and no shadow. White numbers
-- with an outline (bar texts, timers) keep TextColor: they read on the bar's fill and track alike.
local function ReadableTextColor(fontString, color, kind)
  local theme = S.Theme()
  if theme.light and type(TylesserCodex.GameColor) == "function" then
    color = TylesserCodex.GameColor(color, theme, TylesserCodex.Ground and TylesserCodex.Ground(theme, kind or "slot"))
    local x, y, r, g, b, a = S.UI.TextShadow(theme)
    fontString:SetShadowOffset(x, y)
    fontString:SetShadowColor(r, g, b, a)
  end
  TextColor(fontString, color)
end

-- A flat bar with a slight vertical gradient, dark back and a black inner line (design: #111, inset #000).
local function Paint(bar, colors)
  local bottom, top = colors[1], colors[2]
  bar:SetStatusBarColor(top[1], top[2], top[3])
  local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if S.IsRegion(texture) and texture.SetGradient and CreateColor then
    -- dark at the bottom (or the left, with "Left to right": CodexDB.skins.barGradient), light at the top (right)
    local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
    local direction = skins and skins.barGradient == "horizontal" and "HORIZONTAL" or "VERTICAL"
    pcall(texture.SetGradient, texture, direction, CreateColor(bottom[1], bottom[2], bottom[3], 1),
      CreateColor(top[1], top[2], top[3], 1))
  end
end

-- square: edges whose corners stay square on a rounded theme ({ bottom = true }: a health bar with the power bar
-- under it). A rounded theme (round.bar: Dusk, Dawn) cuts the fill and the back with a rounded mask and draws no
-- black line round the bar (the boards: a dark see-through track, no border).
local roundBars = setmetatable({}, { __mode = "k" }) -- [our bar] = its mask
S.roundBars = roundBars
local function Bar(parent, height, colors, square)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetHeight(height)
  bar:SetStatusBarTexture(WHITE)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  local back = bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints(bar)
  S.SetColor(back, BAR_BACK)
  -- lines and text on a layer of our own above the fill
  local top = CreateFrame("Frame", nil, bar)
  top:SetAllPoints(bar)
  top:SetFrameLevel(bar:GetFrameLevel() + 2)
  local mask = S.RoundBar(bar, { back }, { height = height, square = square })
  if mask then
    roundBars[bar] = mask
    local fill = S.Theme().slot.fill
    S.SetColor(back, { fill[1], fill[2], fill[3], 0.85 }) -- the boards' track: rgba(18,21,26,0.85)
  else
    S.Outline(top, bar, 0, 1, BLACK, "BORDER")
  end
  if colors then
    Paint(bar, colors)
  end
  return bar, top
end

local function BarText(top, size)
  local text = top:CreateFontString(nil, "OVERLAY")
  BodyFont(text, size, BAR_FONT, "OUTLINE")
  text:SetPoint("CENTER", top, "CENTER", 0, 0)
  TextColor(text, { 1, 1, 1 })
  return text
end

-- A circle: a texture masked round.
local function Round(texture, owner)
  local mask = owner:CreateMaskTexture()
  mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(texture)
  texture:AddMaskTexture(mask)
  return mask
end

-- Positions ---------------------------------------------------------------------------------------------------

local function SavedPositions(create)
  if type(CodexDB) ~= "table" then
    return nil
  end
  if type(CodexDB.skins) ~= "table" then
    if not create then
      return nil
    end
    CodexDB.skins = {}
  end
  if type(CodexDB.skins.frames) ~= "table" then
    if not create then
      return nil
    end
    CodexDB.skins.frames = {}
  end
  return CodexDB.skins.frames
end

local function PositionOf(f)
  local saved = SavedPositions(false)
  local pos = saved and saved[f.unit]
  if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string" and type(pos[3]) == "number"
    and type(pos[4]) == "number" then
    return pos
  end
  return f.spec.pos
end

-- Frame sizes ------------------------------------------------------------------------------------------------
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 2, 0.05

local function SavedScales(create)
  local skins = type(CodexDB) == "table" and CodexDB.skins
  if type(skins) ~= "table" then
    if not create or type(CodexDB) ~= "table" then
      return nil
    end
    CodexDB.skins = {}
    skins = CodexDB.skins
  end
  if type(skins.frameScale) ~= "table" then
    if not create then
      return nil
    end
    skins.frameScale = {}
  end
  return skins.frameScale
end

-- A frame's size (1 = 100 %); party members share the stack's ("party").
local function ScaleOf(unit)
  if type(unit) == "string" and unit:find("^party%d") then
    unit = "party"
  end
  local saved = SavedScales(false)
  local value = saved and tonumber(saved[unit])
  if not value then
    return 1
  end
  return math.max(SCALE_MIN, math.min(SCALE_MAX, value))
end
S.UnitFrameScale = ScaleOf

-- Width and height apart from the size (2026-11-22, the user's "allow user to adjust just width or height", in Edit
-- Mode: Shift + wheel = width, Ctrl + wheel = height): CodexDB.skins.frameShape[unit] = { w = 1.2, h = 0.9 } (party
-- members share "party"). Width = the bars' length (the frame grows away from its portrait), height = the bars'
-- thickness. Laid out by Layout through SizedSpec.
local Shape = { LIMITS = { w = { 0.6, 2 }, h = { 0.6, 2.5 } } } -- (one local: this file is at Lua's 200-local limit)
function Shape.Key(unit)
  if type(unit) == "string" and unit:find("^party%d") then
    return "party"
  end
  return unit
end
function Shape.Of(unit)
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  local saved = skins and type(skins.frameShape) == "table" and skins.frameShape[Shape.Key(unit)]
  local function Read(key)
    local value = type(saved) == "table" and tonumber(saved[key])
    local limits = Shape.LIMITS[key]
    return value and math.max(limits[1], math.min(limits[2], value)) or 1
  end
  return Read("w"), Read("h")
end
S.UnitFrameShape = Shape.Of

-- scale: the frame's own (its offsets are in its scale's units, the saved position in UIParent's)
local function SetPosition(frame, pos, scale)
  scale = scale or 1
  frame:ClearAllPoints()
  frame:SetPoint(pos[1], UIParent, pos[2], pos[3] / scale, pos[4] / scale)
end

-- Puts our frame where it belongs (secure: out of combat only, else after the fight).
local ApplyPosition -- (Building)
local function Place(f)
  S.Defer("unitframes:place:" .. f.unit, function()
    if ApplyPosition and f.spec.attach then
      ApplyPosition(f)
    else
      -- (the party stack's holder isn't scaled: its members are)
      SetPosition(f.button, PositionOf(f), f.unit == "party" and 1 or ScaleOf(f.unit))
    end
  end)
end

-- Gliding bars -----------------------------------------------------------------------------------------------
-- Health and power glide to a new value instead of jumping (eating and drinking tick every 2 s, so a 1.8 s glide
-- fills them as one smooth run); a drop (damage) lands in 0.2 s, a new unit at once. Readable values are eased
-- here (ease-out, one OnUpdate of ours that runs only while a bar glides); a secret value is handed to the
-- client's own easing (SetValue with Enum.StatusBarInterpolation.ExponentialEaseOut, as FlareUI does), else set.
-- CodexDB.skins.smoothBars = false: no gliding. The bar texts always show the real value.

local GLIDE_UP, GLIDE_DOWN = 1.8, 0.2
local gliding = {} -- [bar] = { from, to, start, length }
local glider

local function SmoothBars()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  return not (skins and skins.smoothBars == false)
end

local function Glide()
  local now, any = GetTime(), false
  for bar, run in pairs(gliding) do
    local t = (now - run.start) / run.length
    if t >= 1 then
      gliding[bar] = nil
      bar:SetValue(run.to)
    else
      local eased = 1 - (1 - t) ^ 3
      bar:SetValue(run.from + (run.to - run.from) * eased)
      any = true
    end
  end
  if not any then
    glider:SetScript("OnUpdate", nil)
  end
end

-- glide: the same unit as before (a new unit, or a full refresh, lands at once).
local function SetBar(bar, value, glide)
  if not glide or not SmoothBars() then
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
  local current = bar.GetValue and bar:GetValue()
  if not CanRead(current) or type(current) ~= "number" or type(value) ~= "number" then
    gliding[bar] = nil
    bar:SetValue(value)
    return
  end
  if value == current then
    gliding[bar] = nil
    return
  end
  gliding[bar] = { from = current, to = value, start = GetTime(), length = value > current and GLIDE_UP or GLIDE_DOWN }
  if not glider then
    glider = CreateFrame("Frame")
  end
  glider:SetScript("OnUpdate", function()
    S.Run("unitframes", Glide)
  end)
end

-- Updates -----------------------------------------------------------------------------------------------------

local function Exists(unit)
  local exists = UnitExists(unit)
  return not CanRead(exists) or exists and true or false
end

-- Incoming heals and shields. The overlays share the health bar's range (UnitHealthMax as it is) and get the
-- amounts as they are; Forever's heal calculator (CreateUnitHealPredictionCalculator) gives the total and the
-- shields when it's there, else UnitGetIncomingHeals / UnitGetTotalAbsorbs. "Others" is the total less yours
-- only when both can be read; secret, the total shows as one overlay.
local function UpdateHeals(f)
  local heals = f.heals
  if not heals then
    return
  end
  local unit = f.unit
  local max = UnitHealthMax(unit)
  heals.mine:SetMinMaxValues(0, max)
  heals.others:SetMinMaxValues(0, max)
  heals.absorb:SetMinMaxValues(0, max)
  local mine = Call(UnitGetIncomingHeals, unit, "player")
  local total, absorbs
  local fromCalc, haveShields, calc = false, false, heals.calc
  if calc and type(UnitGetDetailedHealPrediction) == "function"
    and pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
    local okHeals, incoming = pcall(calc.GetIncomingHeals, calc)
    local okShields, shields = pcall(calc.GetDamageAbsorbs, calc)
    if okHeals then
      total, fromCalc = incoming, true
    end
    if okShields then
      absorbs, haveShields = shields, true
    end
  end
  if not fromCalc then
    total = Call(UnitGetIncomingHeals, unit)
  end
  if not haveShields then
    absorbs = Call(UnitGetTotalAbsorbs, unit)
  end
  if CanRead(mine) and CanRead(total) then
    mine = type(mine) == "number" and mine or 0
    total = type(total) == "number" and total or 0
    heals.mine:SetValue(mine)
    heals.others:SetValue(math.max(0, total - mine))
  else
    heals.mine:SetValue(0)
    if not pcall(heals.others.SetValue, heals.others, total) then
      heals.others:SetValue(0)
    end
  end
  if not pcall(heals.absorb.SetValue, heals.absorb, absorbs) then
    heals.absorb:SetValue(0)
  end
end

local function UpdateHealth(f, glide)
  local unit, bar = f.unit, f.health
  local max = UnitHealthMax(unit)
  bar:SetMinMaxValues(0, max)
  SetBar(bar, UnitHealth(unit), glide)
  UpdateHeals(f)
  local text = f.healthText
  if not text then
    return
  end
  local isPlayer = Readable(UnitIsPlayer(unit))
  local gone = true
  if isPlayer == true and Readable(Call(UnitIsConnected, unit)) == false then
    text:SetText(PLAYER_OFFLINE or "Offline")
  elseif Readable(Call(UnitIsGhost, unit)) == true then
    text:SetText(GHOST or "Ghost")
  elseif Readable(Call(UnitIsDead, unit)) == true then
    text:SetText(DEAD or "Dead")
  else
    gone = false
    BarValueText(text, TextMode("health"), UnitHealth(unit), max, HealthPercentOf(unit))
  end
  TextColor(text, gone and DEAD_TEXT or { 1, 1, 1 })
end

-- PowerBarColor's colour for a power type we have no design colour for, as a gradient (kept per token).
local powerCache = {}
local function PowerColors(token)
  if type(token) ~= "string" then
    return POWER.MANA
  end
  if POWER[token] then
    return POWER[token]
  end
  if not powerCache[token] then
    local c = type(PowerBarColor) == "table" and PowerBarColor[token]
    if type(c) == "table" and type(c.r) == "number" then
      powerCache[token] = { { c.r * 0.6, c.g * 0.6, c.b * 0.6 }, { c.r, c.g, c.b } }
    else
      powerCache[token] = POWER.MANA
    end
  end
  return powerCache[token]
end

local function UpdatePower(f, glide)
  if not f.power then
    return
  end
  local unit = f.unit
  local powerType, token = UnitPowerType(unit)
  local max = UnitPowerMax(unit, powerType)
  f.power:SetMinMaxValues(0, max)
  SetBar(f.power, UnitPower(unit, powerType), glide)
  local colors = PowerColors(Readable(token))
  if f.powerColors ~= colors then
    f.powerColors = colors
    Paint(f.power, colors)
  end
  -- no power (max 0, when readable): the bar goes and the backdrop gets shorter; a secret max keeps it
  local none = Readable(max) == 0
  if f.powerHidden ~= none then
    f.powerHidden = none
    f.power:SetAlpha(none and 0 or 1)
    f.back:SetHeight(f.backHeight - (none and f.spec.gap + f.spec.power or 0))
  end
  if f.powerText then
    if none then
      f.powerText:SetText("")
    else
      BarValueText(f.powerText, TextMode("power"), UnitPower(unit, powerType), max, PowerPercentOf(unit, powerType))
    end
  end
end

local function ClassColor(unit)
  local _, class = UnitClass(unit)
  class = Readable(class)
  if type(class) ~= "string" then
    return nil
  end
  local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    or type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class]
  if type(c) == "table" and type(c.r) == "number" then
    return { c.r, c.g, c.b }
  end
end

-- Own frames: the theme's bright (yours in the class colour with the class accent). Players: class colour. NPCs: reaction (grey when tapped by others).
local function Gone(unit)
  return Readable(Call(UnitIsConnected, unit)) == false, Readable(Call(UnitIsDeadOrGhost, unit)) == true
end

local function NameColor(f)
  local theme = S.Theme()
  -- the name sits inside the health bar and that bar is in the class colour: the name in white, or it disappears
  -- into the bar (the user's screenshot, 2026-11-22)
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  if f.nameInBar and skins and skins.healthColor == "class" then
    return theme.bright
  end
  if f.spec.own then
    -- R3-Polish: with the class colour accent your own name is in it too
    return f.unit == "player" and theme.accentSource == "class" and theme.accent or theme.bright
  end
  local unit = f.unit
  if f.spec.party then
    local offline, dead = Gone(unit)
    if offline or dead then
      return DEAD_NAME
    end
  end
  if Readable(UnitIsPlayer(unit)) == true then
    return ClassColor(unit) or theme.text
  end
  if Readable(Call(UnitIsTapDenied, unit)) == true then
    return TAPPED
  end
  local reaction = Readable(UnitReaction(unit, "player"))
  if type(reaction) == "number" then
    if reaction <= 3 then
      return REACTION_HOSTILE
    elseif reaction == 4 then
      return REACTION_NEUTRAL
    end
    return REACTION_FRIENDLY
  end
  return theme.text
end

local function Hostile(f)
  return f.spec.hostileRing and Readable(UnitCanAttack("player", f.unit)) == true or false
end

-- Forever's UnitName gives first name and surname apart: joined when both can be read. With "First names only"
-- (CodexDB.skins.firstNameOnly, the user's request 2026-11-22) a player shows by the first value alone; NPCs have
-- no surname value, so their names ("Marshal McBride") stay whole.
local function FirstNameOnly()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  return skins and skins.firstNameOnly == true or false
end

local function FullName(unit)
  local name, surname = UnitName(unit)
  if FirstNameOnly() then
    return name
  end
  if CanRead(name) and CanRead(surname) and type(name) == "string" and type(surname) == "string" and surname ~= "" then
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    local separator = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
    return name .. (type(separator) == "string" and separator or " ") .. surname
  end
  return name
end

-- The name at its full size, stepped down (to no less than NAME_MIN) until it fits its row; what still doesn't
-- fit, the game cuts. A secret name can't be measured: it stays at the full size.
local NAME_MIN = 11
local function FitName(f, text)
  local name, size, width = f.name, f.nameSize or f.spec.nameSize, f.nameWidth
  BodyFont(name, size)
  if not width or not name.GetStringWidth or not CanRead(text) or type(text) ~= "string" then
    return
  end
  while size > NAME_MIN do
    local ok, used = pcall(name.GetStringWidth, name)
    if not ok or not CanRead(used) or type(used) ~= "number" or used <= width then
      return
    end
    size = size - 1
    BodyFont(name, size)
  end
end

-- Health bars in class colours (CodexDB.skins.healthColor = "class"; nil = the design's green): players in their
-- class colour, NPCs in their reaction's (grey when tapped by others), pets green. A class or reaction that
-- can't be read keeps the green. Very light colours (priest white, rogue yellow) are taken down a little so the
-- white text on the bar stays readable; the gradient is the same shading as the green's.
local function ClassHealth()
  local skins = type(CodexDB) == "table" and type(CodexDB.skins) == "table" and CodexDB.skins
  return skins and skins.healthColor == "class" or false
end

local healthCache = {}
local function HealthGradient(color)
  local r, g, b = color[1], color[2], color[3]
  if r * 0.3 + g * 0.59 + b * 0.11 > 0.75 then
    r, g, b = r * 0.82, g * 0.82, b * 0.82
  end
  local key = string.format("%.3f:%.3f:%.3f", r, g, b)
  if not healthCache[key] then
    -- (the user's "make unit frame colours gradient", 2026-11-22: 45 % at the bottom, the top 12 % towards white)
    healthCache[key] = { { r * 0.45, g * 0.45, b * 0.45 },
      { r + (1 - r) * 0.12, g + (1 - g) * 0.12, b + (1 - b) * 0.12 } }
  end
  return healthCache[key]
end

-- A class or reaction colour for a bar, toned down on a theme with classTone (Dusk, Dawn: ns.ToneClass); the
-- name text keeps the full colour.
local function Tone(color)
  local fn = TylesserCodex.ToneClass
  return type(fn) == "function" and fn(color, S.Theme()) or color
end

local function HealthColors(f)
  if not ClassHealth() or f.unit == "pet" then
    return HEALTH
  end
  local unit = f.unit
  local isPlayer = Readable(UnitIsPlayer(unit))
  if isPlayer == true then
    local color = ClassColor(unit)
    return color and HealthGradient(Tone(color)) or HEALTH
  elseif isPlayer == false then
    if Readable(Call(UnitIsTapDenied, unit)) == true then
      return HealthGradient(Tone(TAPPED))
    end
    local reaction = Readable(UnitReaction(unit, "player"))
    if type(reaction) == "number" then
      return HealthGradient(Tone(reaction <= 3 and REACTION_HOSTILE or reaction == 4 and REACTION_NEUTRAL
        or REACTION_FRIENDLY))
    end
  end
  return HEALTH
end

-- Incoming heals in the health bar's own colour, faded (the user's request, 2026-11-22: not green on a class-coloured
-- bar): yours at 55 %, the others' at 35 %; shields keep their pale blue.
local HEAL_FADE_MINE, HEAL_FADE_OTHERS = 0.55, 0.35
local function PaintHeals(f, colors)
  local heals = f.heals
  local top = colors and colors[2]
  if not (heals and top) then
    return
  end
  heals.mine:SetStatusBarColor(top[1], top[2], top[3], HEAL_FADE_MINE)
  heals.others:SetStatusBarColor(top[1], top[2], top[3], HEAL_FADE_OTHERS)
end

local function UpdateHealthColor(f)
  local colors = HealthColors(f)
  if f.healthColors ~= colors then
    f.healthColors = colors
    Paint(f.health, colors)
    PaintHeals(f, colors)
  end
end

local function UpdateName(f)
  local text = FullName(f.unit)
  f.name:SetText(text)
  FitName(f, text)
  ReadableTextColor(f.name, NameColor(f), "slot")
  UpdateHealthColor(f)
  -- the portrait's rings turn red on an enemy
  local hostile = Hostile(f)
  if f.ringParts and f.hostile ~= hostile then
    f.hostile = hostile
    for _, part in ipairs(f.ringParts) do
      if part.ring then
        S.SetColor(part.texture, hostile and HOSTILE_RING or part.color, 1)
      end
    end
  end
end

local function LevelColor(f, level)
  if f.spec.own or f.spec.party then
    return S.Theme().accent -- the board's badges: accent for you and your party, difficulty for others
  end
  local c = Call(GetCreatureDifficultyColor, level) or Call(GetQuestDifficultyColor, level)
  if type(c) == "table" and type(c.r) == "number" then
    return { c.r, c.g, c.b }
  end
  return S.Theme().accent
end

local function UpdateLevel(f)
  local text = f.level
  if not text then
    return
  end
  local raw = UnitLevel(f.unit)
  local level = Readable(raw)
  if level == nil then
    text:SetText(raw) -- secret: shown as it is
    ReadableTextColor(text, S.Theme().text, "hud")
  elseif type(level) ~= "number" or level <= 0 then
    text:SetText("??")
    ReadableTextColor(text, REACTION_HOSTILE, "hud")
  else
    local class = Readable(UnitClassification(f.unit))
    local elite = class == "elite" or class == "rareelite" or class == "worldboss"
    text:SetFormattedText("%d%s", level, elite and "+" or "")
    ReadableTextColor(text, LevelColor(f, level), "hud")
  end
end

local function UpdatePortrait(f)
  if f.portrait then
    SetPortraitTexture(f.portrait, f.unit)
    if f.spec.party and f.portrait.SetDesaturated then
      -- offline: the portrait in grey; dead or a ghost: grey and darker (R2-Frames)
      local offline, dead = Gone(f.unit)
      f.portrait:SetDesaturated(offline or dead)
      local shade = dead and 0.55 or 1
      f.portrait:SetVertexColor(shade, shade, shade, 1)
    end
  end
end

-- Party: leader, role (Blizzard's own routine keeps a secret role secret; a readable one is the fallback) and
-- the raid target mark (its index can be secret: the texture setter takes it as it is).
local function UpdatePartyIcons(f)
  if not f or not f.raidIcon then
    return
  end
  local unit = f.unit
  f.leader:SetShown(Readable(Call(UnitIsGroupLeader, unit)) == true)
  local done = false
  local util = UnitFrameUtil and UnitFrameUtil.UpdateUnitFrameRoleIcon
  if type(util) == "function" then
    f.roleProxy = f.roleProxy or { optionTable = { displayRoleIcon = true } }
    f.roleProxy.roleIcon, f.roleProxy.unit = f.role, unit
    done = pcall(util, f.roleProxy)
  end
  if not done then
    local role = Readable(Call(UnitGroupRolesAssigned, unit))
    local atlas = (role == "TANK" or role == "HEALER" or role == "DAMAGER") and Call(GetMicroIconForRole, role)
    f.role:SetShown(type(atlas) == "string" and pcall(f.role.SetAtlas, f.role, atlas) or false)
  end
  local index = Call(GetRaidTargetIndex, unit)
  local show
  if not CanRead(index) then
    show = true
  else
    show = type(index) == "number" and index > 0
  end
  if show and type(SetRaidTargetIconTexture) == "function" then
    SetRaidTargetIconTexture(f.raidIcon, index)
  else
    show = false
  end
  f.raidIcon:SetShown(show)
end

-- Party: faded out of range. UnitInRange can be secret: the frame then picks its alpha from it itself (alpha is
-- allowed on secure frames in combat). A range the client couldn't check counts as in range.
local function UpdateRange(f)
  local button = f.button
  if type(UnitInRange) ~= "function" then
    return
  end
  if (Gone(f.unit)) then
    button:SetAlpha(PARTY_FADE) -- offline
    return
  end
  local inRange, checked = UnitInRange(f.unit)
  if Readable(checked) == false then
    button:SetAlpha(1)
  elseif CanRead(inRange) then
    button:SetAlpha(inRange and 1 or PARTY_FADE)
  elseif not (button.SetAlphaFromBoolean and pcall(button.SetAlphaFromBoolean, button, inRange, 1, PARTY_FADE)) then
    button:SetAlpha(1)
  end
end

-- What the unit is casting: channel (true / false), then UnitCastingInfo's / UnitChannelInfo's values in one
-- order (name, text, texture, startMs, endMs, notInterruptible); nil when nothing. The count of values is
-- never secret, so it tells whether there is a cast without looking at them.
local function CastInfo(unit)
  if type(UnitCastingInfo) == "function" and select("#", UnitCastingInfo(unit)) > 0 then
    local name, text, texture, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(unit)
    return false, name, text, texture, startMs, endMs, notInterruptible
  end
  if type(UnitChannelInfo) == "function" and select("#", UnitChannelInfo(unit)) > 0 then
    local name, text, texture, startMs, endMs, _, notInterruptible = UnitChannelInfo(unit)
    return true, name, text, texture, startMs, endMs, notInterruptible
  end
end

-- The target's type under its bars: "Elite · Humanoid" (the parts that are there).
local function UpdateInfo(f)
  if not f.info then
    return
  end
  local unit = f.unit
  local formats, args = {}, {}
  local function Add(format, value)
    -- a secret value is always shown; a readable one only when it says something
    if not CanRead(value) or type(value) == "string" and value ~= "" then
      formats[#formats + 1] = format
      args[#args + 1] = value
    end
  end
  local class = Readable(UnitClassification(unit))
  Add("%s", CLASSIFICATION[class])
  if Readable(UnitIsPlayer(unit)) == true then
    Add("%s", (UnitClass(unit)))
  else
    Add("%s", Call(UnitCreatureType, unit))
  end
  if #formats == 0 then
    f.info:SetText("")
  else
    f.info:SetFormattedText(table.concat(formats, " \194\183 "), unpack(args))
  end
  -- the elite / rare mark on the portrait
  if f.mark then
    local atlas = not f.noPortrait and ELITE_MARK[class]
    if atlas and pcall(f.mark.SetAtlas, f.mark, atlas) then
      f.mark:Show()
    else
      f.mark:Hide()
    end
  end
end

-- Combo points under the target (rogues, and druids in cat form): a 0-5 bar, so a secret count still shows.
local COMBO = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local ENERGY = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local function UpdateCombo()
  local f = frames.target
  if not f or not f.combo then
    return
  end
  local _, class = UnitClass("player")
  class = Readable(class)
  local on = class == "ROGUE" or class == "DRUID" and Readable(UnitPowerType("player")) == ENERGY
  f.combo:SetAlpha(on and 1 or 0)
  if on then
    f.combo:SetMinMaxValues(0, UnitPowerMax("player", COMBO))
    f.combo:SetValue(UnitPower("player", COMBO))
  end
end

local function UpdateIcons()
  local f = frames.player
  if not f or not f.combat then
    return
  end
  local combat = Readable(UnitAffectingCombat("player")) == true
  f.combat:SetShown(combat)
  f.rest:SetShown(not combat and Readable(Call(IsResting)) == true)
  f.leader:SetShown(Readable(Call(UnitIsGroupLeader, "player")) == true)
end

-- The cast bar under target / focus. The client runs the bar from the cast's duration object (secret or not);
-- without that API, readable start and end times drive it from OnUpdate.
local function CastTick(holder)
  local cast = holder.cast
  local now = GetTime() * 1000
  if cast.fallback then
    if now >= cast.endMs then
      holder:SetScript("OnUpdate", nil)
      holder:Hide()
      return
    end
    cast.bar:SetValue(cast.channel and cast.endMs - now or now - cast.startMs)
  end
  if cast.endMs then
    cast.time:SetFormattedText("%.1f", math.max(0, (cast.endMs - now) / 1000))
  end
end

local function UpdateCast(f)
  local cast = f.cast
  if not cast then
    return
  end
  local holder, bar = cast.holder, cast.bar
  local channel, name, text, texture, startMs, endMs, locked = CastInfo(f.unit)
  holder:SetScript("OnUpdate", nil)
  if channel == nil then
    holder:Hide()
    return
  end
  local durationOf = channel and UnitChannelDuration or UnitCastingDuration
  local timer = Enum and Enum.StatusBarTimerDirection
  local timed = false
  if type(durationOf) == "function" and timer and bar.SetTimerDuration then
    local duration = durationOf(f.unit)
    if not CanRead(duration) or duration ~= nil then
      local smooth = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
      timed = pcall(bar.SetTimerDuration, bar, duration, smooth,
        channel and timer.RemainingTime or timer.ElapsedTime)
    end
  end
  startMs, endMs = Readable(startMs), Readable(endMs)
  local known = type(startMs) == "number" and type(endMs) == "number" and endMs > startMs
  if not timed and not known then
    holder:Hide()
    return
  end
  cast.fallback, cast.channel = not timed, channel
  cast.startMs, cast.endMs = known and startMs or nil, known and endMs or nil
  if not timed then
    bar:SetMinMaxValues(0, endMs - startMs)
  end
  cast.time:SetText("")
  -- the time left (when readable) and the fallback fill
  holder:SetScript("OnUpdate", (cast.fallback or cast.endMs) and CastTick or nil)
  -- "text or name" would test a secret: only picked when readable
  local label = text
  if CanRead(text) then
    label = text or name or ""
  end
  cast.text:SetText(label)
  cast.icon:SetTexture(texture)
  local accent = S.Theme().accent
  if CanRead(locked) then
    local color = locked and CAST_LOCKED or accent
    bar:SetStatusBarColor(color[1], color[2], color[3])
  else
    -- secret (enemy casts in combat): the fill picks its colour from the flag itself
    bar:SetStatusBarColor(accent[1], accent[2], accent[3])
    local fill = bar:GetStatusBarTexture()
    if S.IsRegion(fill) and fill.SetVertexColorFromBoolean and CreateColor then
      pcall(fill.SetVertexColorFromBoolean, fill, locked, CreateColor(CAST_LOCKED[1], CAST_LOCKED[2], CAST_LOCKED[3], 1),
        CreateColor(accent[1], accent[2], accent[3], 1))
    end
  end
  holder:Show()
end

local function UpdateCasting(f)
  UpdateInfo(f)
  UpdateCast(f)
end

-- A new unit behind the token: the aura container reads it again.
local function UpdateAuras(f)
  if f and f.auraContainer then
    pcall(f.auraContainer.UpdateAllAuras, f.auraContainer)
  end
end

local function UpdateAll(f)
  if not f or not Exists(f.unit) then
    return
  end
  UpdateName(f)
  UpdateLevel(f)
  UpdateHealth(f)
  UpdatePower(f)
  UpdatePortrait(f)
  UpdateInfo(f)
  UpdateCast(f)
  if f.unit == "target" then
    UpdateCombo()
  elseif f.unit == "player" then
    UpdateIcons()
  elseif f.spec.party then
    UpdatePartyIcons(f)
    UpdateRange(f)
  end
end

local function UpdateParty()
  for index = 1, 4 do
    UpdateAll(frames["party" .. index])
  end
end

local function UpdateAllPartyIcons()
  for index = 1, 4 do
    UpdatePartyIcons(frames["party" .. index])
  end
end

local function UpdateEverything()
  for _, f in pairs(frames) do
    UpdateAll(f)
  end
end

-- Building ----------------------------------------------------------------------------------------------------

local function ShowTooltip(button)
  local f = frames[button:GetAttribute("unit")]
  if not f then
    return
  end
  if type(GameTooltip_SetDefaultAnchor) == "function" then
    GameTooltip_SetDefaultAnchor(GameTooltip, button)
  else
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
  end
  GameTooltip:SetUnit(f.unit)
  GameTooltip:Show()
end

-- A disc: a texture masked round, centred on (point, x, y) of `relative`.
local function Disc(owner, layer, sublevel, size, color, point, relative, x, y)
  local disc = owner:CreateTexture(nil, layer, nil, sublevel)
  disc:SetSize(size, size)
  disc:SetPoint("CENTER", relative, point, x or 0, y or 0)
  S.SetColor(disc, color)
  Round(disc, owner)
  return disc
end

-- The board's round rings, from the outside in: { colour, width, line = true for the theme's line colour }.
-- roundRing: a darker outer edge, a dark gap, the line (2 px), black; the flat theme (one window ring, Slate):
-- black, a brighter line, black. roundRingThin: the line, black. The line is the theme's titleLine
-- (titlebar.line); the outer edge is that line darker (the boards' bronze / brass / grey).
-- Suggested theme tokens: roundRing, roundRingThin.
local function RoundRings(kind)
  local theme = S.Theme()
  local line = theme.titlebar.line
  if kind == "thin" then
    return { { line, 1, line = true }, { BLACK, 1 } }
  end
  if #(theme.rings or {}) <= 1 then
    local bright = { math.min(1, line[1] * 1.6), math.min(1, line[2] * 1.6), math.min(1, line[3] * 1.6) }
    return { { BLACK, 1 }, { bright, 1, line = true }, { BLACK, 1 } }
  end
  local edge = { line[1] * 0.62, line[2] * 0.62, line[3] * 0.62 }
  return { { edge, 1 }, { DISC, 1 }, { line, 2, line = true }, { BLACK, 1 } }
end

local function RingDiscs(owner, layer, sublevel, size, rings, point, relative, x, y, parts)
  local depth = 0
  for _, ring in ipairs(rings) do
    depth = depth + ring[2]
  end
  local edge, first = 0, nil
  for _, ring in ipairs(rings) do
    local disc = Disc(owner, layer, sublevel, size + 2 * (depth - edge), ring[1], point, relative, x, y)
    if parts then
      parts[#parts + 1] = { texture = disc, color = ring[1], ring = ring.line }
    end
    first = first or disc
    edge, sublevel = edge + ring[2], math.min(sublevel + 1, 7)
  end
  return first, depth
end

-- The round portrait at the board's place, in its rings (the rings turn red on an enemy: UpdateName).
local function BuildPortrait(f, spec)
  local button = f.button
  local size, x, y = spec.portrait[1], spec.portrait[2], spec.portrait[3]
  local cx, cy = x + size / 2, -(y + size / 2)
  -- a layer of ours above the bars (the badges go above it): the ring and the portrait cover the bars' end
  local holder = CreateFrame("Frame", nil, button)
  holder:SetAllPoints(button)
  holder:SetFrameLevel(button:GetFrameLevel() + 5)
  f.portraitLayer = holder
  f.ringParts = {}
  f.ring = RingDiscs(holder, "BORDER", -8, size, RoundRings(spec.ring), "TOPLEFT", f.origin, cx, cy, f.ringParts)
  f.disc = Disc(holder, "ARTWORK", 0, size, DISC, "TOPLEFT", f.origin, cx, cy)
  f.portrait = holder:CreateTexture(nil, "ARTWORK", nil, 1)
  f.portrait:SetSize(size, size)
  f.portrait:SetPoint("CENTER", f.disc, "CENTER", 0, 0)
  Round(f.portrait, holder)
end

-- Pieces over the portrait (badge, icons) on a layer of ours above the bars.
local function BuildBadges(f, spec)
  local theme = S.Theme()
  local button = f.button
  local top = CreateFrame("Frame", nil, button)
  top:SetAllPoints(button)
  top:SetFrameLevel(button:GetFrameLevel() + 6)
  local size, px, py = spec.portrait[1], spec.portrait[2], spec.portrait[3]
  if spec.badge then
    -- the level: a disc in the HUD fill with the thin round ring, the number centred on it
    local badge, bx, by = spec.badge[1], spec.badge[2], spec.badge[3]
    local cx, cy = bx + badge / 2, -(by + badge / 2)
    f.badgeParts = {}
    RingDiscs(top, "ARTWORK", -8, badge, RoundRings("thin"), "TOPLEFT", f.origin, cx, cy, f.badgeParts)
    local disc = Disc(top, "ARTWORK", 0, badge, theme.hud.fill, "TOPLEFT", f.origin, cx, cy)
    S.SetColor(disc, theme.hud.fill, 1)
    f.badgeParts[#f.badgeParts + 1] = { texture = disc }
    f.levelDisc, f.badgeSize = disc, badge
    local level = top:CreateFontString(nil, "OVERLAY")
    BodyFont(level, badge >= 22 and 11 or 10, BAR_FONT)
    level:SetPoint("CENTER", disc, "CENTER", 0, 0)
    level:SetSize(badge, badge)
    level:SetJustifyH("CENTER")
    level:SetJustifyV("MIDDLE")
    TextColor(level, theme.accent)
    f.level = level
  end
  if spec.info then
    local mark = top:CreateTexture(nil, "OVERLAY", nil, 2)
    mark:SetSize(math.floor(size * 0.36 + 0.5), math.floor(size * 0.36 + 0.5))
    mark:SetPoint("CENTER", f.origin, "TOPLEFT", px + size / 2, -py + 2)
    mark:Hide()
    f.mark = mark
  end
  if spec.icons then
    -- resting "zZ" over the portrait's upper right, the combat swords there in a fight, the crown upper left
    local rest = top:CreateFontString(nil, "OVERLAY")
    BodyFont(rest, 14)
    rest:SetText("zZ")
    rest:SetPoint("CENTER", f.origin, "TOPLEFT", px + size * 0.86, -py - 2)
    TextColor(rest, REST)
    rest:Hide()
    local combat = top:CreateTexture(nil, "OVERLAY", nil, 2)
    combat:SetSize(20, 20)
    combat:SetPoint("CENTER", f.origin, "TOPLEFT", px + size * 0.86, -py - 4)
    pcall(combat.SetAtlas, combat, "UI-HUD-UnitFrame-Player-CombatIcon")
    combat:Hide()
    local leader = top:CreateTexture(nil, "OVERLAY", nil, 2)
    leader:SetSize(16, 16)
    leader:SetPoint("CENTER", f.origin, "TOPLEFT", px + size * 0.14, -py - 2)
    pcall(leader.SetAtlas, leader, "UI-HUD-UnitFrame-Player-Group-LeaderIcon")
    leader:Hide()
    f.rest, f.combat, f.leader = rest, combat, leader
  end
  if spec.partyIcons then
    -- party (R2-Frames): the leader crown on the portrait's top left, role top right, the raid mark on top
    local leader = top:CreateTexture(nil, "OVERLAY", nil, 2)
    leader:SetSize(16, 16)
    leader:SetPoint("CENTER", f.origin, "TOPLEFT", px + 12, -py)
    pcall(leader.SetAtlas, leader, "UI-HUD-UnitFrame-Player-Group-LeaderIcon")
    leader:Hide()
    local role = top:CreateTexture(nil, "OVERLAY", nil, 2)
    role:SetSize(14, 14)
    role:SetPoint("CENTER", f.origin, "TOPLEFT", px + size - 8, -py - 4)
    role:Hide()
    local mark = top:CreateTexture(nil, "OVERLAY", nil, 3)
    mark:SetSize(16, 16)
    mark:SetPoint("CENTER", f.origin, "TOPLEFT", px + size / 2, -py)
    pcall(mark.SetTexture, mark, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    mark:Hide()
    f.leader, f.role, f.raidIcon = leader, role, mark
  end
end

-- The cast bar (R2-HUD): the spell icon, then a slim bar in plateLine rings (black, the line at .75) with the
-- spell's name on the left and the time left on the right.
local function BuildCast(f, spec)
  local button, cast = f.button, spec.cast
  local x, y, width, icon, height = cast[1], cast[2], cast[3], cast[4], cast[5]
  local holder = CreateFrame("Frame", nil, button)
  holder:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
  holder:SetSize(width, icon)
  local picture = holder:CreateTexture(nil, "ARTWORK")
  picture:SetSize(icon, icon)
  picture:SetPoint("LEFT", holder, "LEFT", 0, 0)
  picture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local pictureLines = S.Outline(holder, picture, -1, 1, BLACK, "BORDER")
  local bar, top = Bar(holder, height)
  bar:SetPoint("LEFT", picture, "RIGHT", 6, 0)
  bar:SetPoint("RIGHT", holder, "RIGHT", -2, 0)
  local line = S.Theme().titlebar.line
  if roundBars[bar] then
    -- rounded: the icon rounded like a slot, one rounded hairline round the bar
    for _, edge in ipairs(pictureLines) do
      edge:Hide()
    end
    S.UI.RoundMask(holder, picture, math.min(S.Radius("slot") or 4, 4), { picture })
    S.UI.RoundLine(holder, bar, roundBars[bar].codexRadius + 1, line, { inset = -1 })
  else
    S.Outline(holder, bar, -1, 1, BLACK, "BORDER")
    S.Outline(holder, bar, -2, 1, { line[1], line[2], line[3], 0.75 }, "BORDER")
  end
  local text = top:CreateFontString(nil, "OVERLAY")
  BodyFont(text, height >= 14 and 11 or 10)
  text:SetPoint("LEFT", top, "LEFT", 6, 0)
  text:SetPoint("RIGHT", top, "RIGHT", -30, 0)
  text:SetJustifyH("LEFT")
  if text.SetWordWrap then
    text:SetWordWrap(false)
  end
  TextColor(text, { 1, 1, 1 })
  local time = top:CreateFontString(nil, "OVERLAY")
  SetFont(time, BAR_FONT, 10)
  time:SetPoint("RIGHT", top, "RIGHT", -6, 0)
  TextColor(time, { 1, 1, 1 })
  holder:Hide()
  f.cast = { holder = holder, bar = bar, icon = picture, text = text, time = time }
  holder.cast = f.cast
end

-- Blizzard's pooled aura buttons we've dressed: [button] = our pieces (nothing written on the buttons).
local dressed = setmetatable({}, { __mode = "k" })

-- An aura button as the board draws them: a round icon in the thin round ring, a round swipe, the stack count,
-- and (target) the time left under it. The button itself fills our icon, swipe, count and time (it reads the
-- aura, secret or not).
local function DressAura(button, size, isDebuff, timer)
  button:SetSize(size, size + (timer and 10 or 0))
  local parts = dressed[button]
  if not parts then
    parts = {}
    local cx, cy = size / 2, -size / 2
    RingDiscs(button, "BACKGROUND", -8, size, RoundRings("thin"), "TOPLEFT", button, cx, cy)
    parts.icon = button:CreateTexture(nil, "ARTWORK")
    parts.icon:SetSize(size, size)
    parts.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Round(parts.icon, button)
    parts.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    parts.cooldown:SetAllPoints(parts.icon)
    parts.cooldown:SetReverse(true)
    parts.cooldown:SetDrawEdge(false)
    parts.cooldown:SetDrawBling(false)
    parts.cooldown:SetHideCountdownNumbers(true)
    pcall(parts.cooldown.SetSwipeTexture, parts.cooldown, CIRCLE)
    pcall(parts.cooldown.SetUseCircularEdge, parts.cooldown, true)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(parts.cooldown:GetFrameLevel() + 5)
    parts.count = overlay:CreateFontString(nil, "OVERLAY", nil, 3)
    SetFont(parts.count, BAR_FONT, math.max(9, size * 0.45), "OUTLINE")
    parts.count:SetPoint("BOTTOMRIGHT", parts.icon, "BOTTOMRIGHT", 1, -1)
    parts.count:SetJustifyH("RIGHT")
    if timer then
      parts.time = overlay:CreateFontString(nil, "OVERLAY", nil, 3)
      SetFont(parts.time, BAR_FONT, 9)
      parts.time:SetPoint("TOP", parts.icon, "BOTTOM", 0, -1)
      TextColor(parts.time, { 1, 1, 1 })
    end
    dressed[button] = parts
  end
  pcall(button.SetIcon, button, parts.icon)
  pcall(button.SetDurationCooldown, button, parts.cooldown)
  pcall(button.SetApplicationCount, button, parts.count, {})
  if parts.time then
    pcall(button.SetDurationText, button, parts.time, {})
  end
end

-- Debuffs then buffs (Blizzard's default order puts your own first). Containers made after login are
-- access-restricted and never show, so they're made as this file loads (at login, even in combat: creating
-- frames isn't protected) on a hidden holder of ours, and moved under the unit frame in Build.
local early = {} -- [unit] = aura container made at load
local auraHolder

local function MakeAuras(spec)
  if not S.AddOnLoaded("Blizzard_AuraContainer") and C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
  end
  if not auraHolder then
    auraHolder = CreateFrame("Frame", nil, UIParent)
    auraHolder:Hide()
  end
  local ok, container = pcall(CreateFrame, "AuraContainer", nil, auraHolder, "CustomAuraContainerTemplate")
  if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
    return
  end
  pcall(container.SetUnit, container, spec.unit)
  local size, spacing, timer, E = spec.auras[3], spec.auras[4], spec.auras[5], Enum or {}
  for index, group in ipairs({ { key = "debuffs", filter = "HARMFUL", debuff = true }, { key = "buffs", filter = "HELPFUL" } }) do
    pcall(container.AddAuraGroup, container, group.key, group.filter, {
      maxFrameCount = spec.auraMax and spec.auraMax[index] or AURA_MAX,
      sortMethod = E.AuraContainerSortMethod and E.AuraContainerSortMethod.Default,
      sortDirection = E.AuraContainerSortDirection and E.AuraContainerSortDirection.Normal,
      initializeFrame = function(button)
        -- (Blizzard locks the buttons while auras are secret: a locked one keeps the plain look)
        pcall(DressAura, button, size, group.debuff, timer)
      end,
      layout = { elementWidth = size, elementHeight = size + (timer and 10 or 0), elementSpacing = spacing,
        lineSpacing = spacing, groupSpacing = spacing, groupLineSpacing = spacing, layoutIndex = index,
        forceNewLine = index > 1 and not spec.auraOneLine },
    })
  end
  local axis, flow = AnchorUtil and AnchorUtil.FlowLayoutAxis, AnchorUtil and AnchorUtil.FlowDirection
  if axis and flow then
    pcall(container.SetFlowLayoutAxis, container, axis.Horizontal)
    pcall(container.SetFlowLayoutGrowthDirection, container, flow.Right, flow.Down)
  end
  pcall(container.SetFlowLayoutAnchorPoint, container, "TOPLEFT")
  local row = spec.auraRow or AURA_ROW
  pcall(container.SetFlowLayoutMaximumLineSize, container, row * size + (row - 1) * spacing)
  pcall(container.SetFlowLayoutPadding, container, 0, 0, 0, 0)
  return container
end

-- Where the auras go (Settings: Target / Focus / Party auras; the user's request, 2026-11-22): below the frame (the
-- board's place), above it (growing up), or beside it on the right or left (growing outward, AURA_SIDE_ROW a row).
local AURA_SIDE_ROW = 4
local function AuraPlace(spec)
  local fn = TylesserCodex.AuraPlace
  local place = type(fn) == "function" and fn(spec.party and "party" or spec.unit) or "below"
  return place
end

-- The container's flow for a place: the anchor corner, the growth directions and the row length.
local function AuraFlow(container, spec, place)
  local axis, flow = AnchorUtil and AnchorUtil.FlowLayoutAxis, AnchorUtil and AnchorUtil.FlowDirection
  local size, spacing = spec.auras[3], spec.auras[4]
  local corner, across, down = "TOPLEFT", "Right", "Down"
  if place == "above" then
    corner, down = "BOTTOMLEFT", "Up"
  elseif place == "left" then
    corner, across = "TOPRIGHT", "Left"
  end
  if axis and flow then
    pcall(container.SetFlowLayoutAxis, container, axis.Horizontal)
    pcall(container.SetFlowLayoutGrowthDirection, container, flow[across], flow[down])
  end
  pcall(container.SetFlowLayoutAnchorPoint, container, corner)
  local row = (place == "left" or place == "right") and AURA_SIDE_ROW or (spec.auraRow or AURA_ROW)
  pcall(container.SetFlowLayoutMaximumLineSize, container, row * size + (row - 1) * spacing)
end

-- At the board's place under the unit frame (Build, out of combat).
local function BuildAuras(f, spec)
  local container = early[f.unit] or MakeAuras(spec)
  if not container then
    return
  end
  container:SetParent(f.button)
  container:SetFrameLevel(f.button:GetFrameLevel() + 4)
  container:ClearAllPoints()
  container:SetPoint("TOPLEFT", f.button, "TOPLEFT", spec.auras[1], -spec.auras[2])
  pcall(container.SetEnabled, container, true)
  container:Show()
  pcall(container.UpdateAllAuras, container)
  f.auraContainer = container
end

-- The heal overlays on a health bar: inside a frame of ours exactly over the bar that cuts off what runs past its
-- end. Yours starts where the health fill ends, the others' where yours ends, shields after those; each is as long
-- as the whole bar, so the same range puts its fill at the right length.
local function BuildHeals(f, health, width)
  local clip = CreateFrame("Frame", nil, health)
  clip:SetAllPoints(health)
  clip:SetFrameLevel(health:GetFrameLevel() + 1)
  clip:SetClipsChildren(true)
  local function Overlay(after, color)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetPoint("TOPLEFT", after, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", after, "BOTTOMRIGHT", 0, 0)
    bar:SetWidth(width)
    return bar
  end
  local heals = { clip = clip }
  heals.mine = Overlay(health:GetStatusBarTexture(), HEAL_MINE)
  heals.others = Overlay(heals.mine:GetStatusBarTexture(), HEAL_OTHERS)
  heals.absorb = Overlay(heals.others:GetStatusBarTexture(), ABSORB)
  if type(CreateUnitHealPredictionCalculator) == "function" then
    local ok, calc = pcall(CreateUnitHealPredictionCalculator)
    if ok and (type(calc) == "table" or type(calc) == "userdata") then
      heals.calc = calc
    end
  end
  f.heals = heals
end

-- Where a frame goes: its saved place, else beside the frame it's attached to (target of target), else its default.
function ApplyPosition(f)
  local saved = SavedPositions(false)
  local attach = f.spec.attach
  local other = attach and frames[attach[1]]
  if not (saved and saved[f.unit]) and other then
    -- beside the other frame, as far off as that frame is big (offsets in this frame's scale)
    local ratio = ScaleOf(other.unit) / ScaleOf(f.unit)
    f.button:ClearAllPoints()
    f.button:SetPoint("TOPLEFT", other.button, "TOPLEFT", attach[2] * ratio, -attach[3] * ratio)
  else
    SetPosition(f.button, PositionOf(f), ScaleOf(f.unit))
  end
end

-- Where the name and bars go in the style in use: x, width, y (the bars' top or the name row's), bar heights,
-- text sizes; inBar: the name sits inside the health bar, textLeft / textRight keep the texts off the portrait;
-- visX / visW: the part of the bars that shows (the cast bar and auras line up with it).
-- Panel: inside the board's backdrop. Compact: from the portrait's middle (under the ring) to the frame's edge,
-- the bars centred on the portrait, nothing behind them. Bars: no portrait, the whole width.
local function Geometry(spec)
  local style = ns.FrameStyle()
  if style == "bars" then
    -- no portrait: the bars run the frame's whole width from its top, a small text row under them
    local b = spec.bars or {}
    local health, power = b[1] or spec.health, spec.power and b[2] or nil
    local block = health + (power and 1 + power or 0) + 2 + 10
    return { x = 0, width = spec.w, y = 0, gap = 1, health = health, power = power, healthText = b[4],
      powerText = b[5], nameSize = b[3] or spec.nameSize, bars = true, compact = true, inBar = true, textLeft = 4,
      textRight = 4, visX = 0, visW = spec.w, bottom = block }
  end
  if style ~= "compact" then
    local x, width = spec.back[1] + spec.pad[1], spec.back[3] - spec.pad[1] - spec.pad[2]
    return { x = x, width = width, y = spec.back[2] + spec.pad[3], gap = spec.gap, health = spec.health,
      power = spec.power, healthText = spec.healthText, powerText = spec.powerText, visX = x, visW = width }
  end
  local size, px, py = spec.portrait[1], spec.portrait[2], spec.portrait[3]
  local depth = RING_DEPTH[spec.ring] or 2
  local c = spec.compact or {}
  local cx = px + size / 2
  local clear = math.floor(size / 2 + depth + 4 + 0.5) -- from the portrait's middle to past its ring
  local x, width, textLeft, textRight, visX, visW
  if cx < spec.w / 2 then
    x = math.floor(cx + 0.5)
    width = spec.w - x - 2
    textLeft, textRight = clear, 4
    visX, visW = x + clear - 4, width - clear + 4
  else
    x = 2
    width = math.floor(cx + 0.5) - 2
    textLeft, textRight = 4, clear
    visX, visW = x, width - clear + 4
  end
  local thick = spec.barScale or 1 -- (frame height, SizedSpec)
  local power = spec.power and math.max(3, math.floor(size * COMPACT_POWER * thick + 0.5)) or nil
  local health = math.floor(size * (power and COMPACT_HEALTH or COMPACT_HEALTH + COMPACT_POWER) * thick + 0.5)
  -- the power bar touches the health bar: it starts 1 px up, so its top line is the health bar's bottom line
  local block = health + (power and power - 1 or 0)
  local y = math.max(0, math.floor(py + size / 2 - block / 2 + 0.5))
  return { x = x, width = width, y = y, gap = -1, health = health, power = power, healthText = c[3], powerText = c[4],
    compact = true, inBar = true, textLeft = textLeft, textRight = textRight, visX = visX, visW = visW,
    bottom = y + block }
end

-- Lays the frame out for the style (built once, laid out again on a style change, out of combat).
-- The portrait's pieces (rings, disc, picture, level badge) shown or not, and the icons round it kept where they
-- were built (bars style: on the health bar's top edge instead).
local ICON_KEYS = { "rest", "combat", "leader", "role", "raidIcon" }

-- The frame's spec at its saved width and height (Shape.Of): a copy over the board's own (1 / 1: the board's).
-- Width: dx more bar; with the portrait on the frame's right the portrait (and its pieces, on f.origin) moves dx
-- out too. Height: the bars' thickness (barScale); the panel's backdrop and the frame grow with it.
local function SizedSpec(f)
  local base = f.spec
  local wide, tall = Shape.Of(f.unit)
  f.originX = 0
  if wide == 1 and tall == 1 then
    return base
  end
  local sized = setmetatable({}, { __index = base })
  local dx = math.floor((wide - 1) * (Geometry(base).width or 0) + 0.5)
  sized.w = base.w + dx
  local p = base.portrait
  local right = p and p[2] + p[1] / 2 >= base.w / 2
  if right then
    sized.portrait = { p[1], p[2] + dx, p[3] }
    f.originX = dx
  end
  sized.back = { base.back[1], base.back[2], base.back[3] + dx, base.back[4] }
  if base.cast then
    sized.cast = { base.cast[1], base.cast[2], base.cast[3] + dx, base.cast[4] }
  end
  sized.barScale = tall
  if tall ~= 1 then
    local function Thick(value)
      return value and math.max(3, math.floor(value * tall + 0.5)) or nil
    end
    sized.health, sized.power = Thick(base.health), Thick(base.power)
    if base.bars then
      local b = base.bars
      sized.bars = { Thick(b[1]), Thick(b[2]), b[3], b[4], b[5] }
    end
    local extra = (sized.health or 0) - (base.health or 0) + (sized.power or 0) - (base.power or 0)
    sized.h = base.h + extra
    sized.back[4] = base.back[4] + extra
  end
  return sized
end
local function PortraitShown(f, shown)
  f.noPortrait = not shown
  f.portraitLayer:SetShown(shown)
  for _, part in ipairs(f.ringParts or {}) do
    part.texture:SetShown(shown)
  end
  for _, part in ipairs(f.badgeParts or {}) do
    part.texture:SetShown(shown)
  end
  f.disc:SetShown(shown)
  f.portrait:SetShown(shown)
  if f.mark and not shown then
    f.mark:Hide()
  end
  if not f.iconPoints then
    f.iconPoints = {}
    for _, key in ipairs(ICON_KEYS) do
      local icon = f[key]
      if icon and icon.GetPoint then
        f.iconPoints[key] = { icon:GetPoint(1) }
      end
    end
  end
  for _, key in ipairs(ICON_KEYS) do
    local icon, point = f[key], f.iconPoints[key]
    if icon and point then
      icon:ClearAllPoints()
      if shown then
        icon:SetPoint(point[1], point[2], point[3], point[4], point[5])
      elseif key == "leader" then
        icon:SetPoint("CENTER", f.health, "TOPLEFT", 8, 1)
      elseif key == "raidIcon" then
        icon:SetPoint("CENTER", f.health, "TOP", 0, 1)
      else
        icon:SetPoint("CENTER", f.health, "TOPRIGHT", -10, 1)
      end
    end
  end
end

-- The level: on its badge, or (bars style) as small text at the start of the row under the bars.
local function PlaceLevel(f, bars, x, y)
  local level = f.level
  if not level then
    return
  end
  level:ClearAllPoints()
  if bars then
    level:SetPoint("TOPLEFT", f.button, "TOPLEFT", x, -y)
    level:SetSize(48, 10)
    level:SetJustifyH("LEFT")
    BodyFont(level, 10, BAR_FONT)
  else
    level:SetPoint("CENTER", f.levelDisc, "CENTER", 0, 0)
    level:SetSize(f.badgeSize, f.badgeSize)
    level:SetJustifyH("CENTER")
    BodyFont(level, f.badgeSize >= 22 and 11 or 10, BAR_FONT)
  end
end

-- A bar text: on the bar's right (in-bar styles, off the portrait) or centred (panel).
local function PlaceBarText(text, top, size, inBar, right)
  if not text then
    return
  end
  if size then
    BodyFont(text, size, BAR_FONT, "OUTLINE")
  end
  text:ClearAllPoints()
  if inBar then
    text:SetPoint("RIGHT", top, "RIGHT", -right, 0)
    text:SetJustifyH("RIGHT")
  else
    text:SetPoint("CENTER", top, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
  end
end

local function Layout(f)
  local button = f.button
  local spec = SizedSpec(f)
  if f.origin then
    f.origin:ClearAllPoints()
    f.origin:SetPoint("TOPLEFT", button, "TOPLEFT", f.originX or 0, 0)
  end
  if f.back and spec.back ~= f.spec.back or f.sizedBack then
    -- the panel's backdrop at the sized width / height (and back to the board's)
    f.back:SetSize(spec.back[3], spec.back[4])
    f.backHeight = spec.back[4]
    f.sizedBack = spec.back ~= f.spec.back or nil
  end
  local g = Geometry(spec)
  local compact, bars, inBar = g.compact or false, g.bars or false, g.inBar or false
  f.nameInBar = inBar
  local x, width, y = g.x, g.width, g.y
  f.columnX, f.nameWidth = g.visX, width
  f.plate:SetShown(not compact)
  PortraitShown(f, not bars)
  -- the clickable frame: the board's size, or (bars) just the bars and their small row
  f.h = bars and g.bottom or (spec ~= f.spec and math.max(spec.h, g.bottom or 0) or spec.h)
  f.w = spec.w
  button:SetSize(spec.w, f.h)
  local nameSize = g.nameSize or spec.nameSize
  f.nameSize = nameSize
  local nameRow = nameSize + 2
  f.name:ClearAllPoints()
  if inBar then
    -- the name on the health bar's left (off the portrait), the numbers on its right
    f.name:SetParent(f.healthTop)
    f.name:SetPoint("LEFT", f.health, "LEFT", g.textLeft, 0)
    f.name:SetPoint("RIGHT", f.health, "RIGHT", -(g.textRight + 70), 0)
    f.name:SetHeight(g.health)
    f.nameWidth = width - g.textLeft - g.textRight - 74
  else
    f.name:SetParent(button)
    f.name:SetHeight(nameRow)
    f.name:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
    f.name:SetPoint("TOPRIGHT", button, "TOPLEFT", x + width, -y)
  end
  BodyFont(f.name, nameSize)
  if f.heading then
    f.heading:ClearAllPoints()
    if inBar then
      f.heading:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", g.textLeft, 1)
    else
      f.heading:SetPoint("TOPLEFT", button, "TOPLEFT", 50, 0)
    end
  end
  if not inBar then
    y = y + nameRow + g.gap
  end
  f.health:ClearAllPoints()
  f.health:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
  f.health:SetPoint("TOPRIGHT", button, "TOPLEFT", x + width, -y)
  f.health:SetHeight(g.health)
  PlaceBarText(f.healthText, f.healthTop, g.healthText, inBar, g.textRight)
  for _, key in ipairs({ "mine", "others", "absorb" }) do
    f.heals[key]:SetWidth(width)
  end
  y = y + g.health + g.gap
  if f.power then
    f.power:ClearAllPoints()
    f.power:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
    f.power:SetPoint("TOPRIGHT", button, "TOPLEFT", x + width, -y)
    f.power:SetHeight(g.power or spec.power)
    PlaceBarText(f.powerText, f.powerTop, g.powerText, inBar, g.textRight)
    y = y + (g.power or spec.power)
  end
  if bars then
    -- the small row: the level on the left, the classification on the right
    PlaceLevel(f, true, x + 2, y + 2)
  else
    PlaceLevel(f, false)
  end
  local vx, vw = g.visX, g.visW
  if f.info then
    f.info:ClearAllPoints()
    if bars then
      f.info:SetPoint("TOPRIGHT", button, "TOPLEFT", x + width - 2, -(y + 2))
      f.info:SetPoint("TOPLEFT", button, "TOPLEFT", x + 48, -(y + 2))
    elseif compact then
      -- small and muted under the power bar, in the part of it that shows
      f.info:SetPoint("TOPRIGHT", button, "TOPLEFT", vx + vw - 2, -(y + 1))
      f.info:SetPoint("TOPLEFT", button, "TOPLEFT", vx, -(y + 1))
      y = y + 1 + 10
    else
      f.info:SetPoint("BOTTOMRIGHT", f.back, "BOTTOMRIGHT", -spec.pad[2], 1)
      f.info:SetPoint("BOTTOMLEFT", f.back, "BOTTOMLEFT", spec.pad[1], 1)
    end
  end
  if f.combo then
    f.combo:ClearAllPoints()
    if compact then
      f.combo:SetPoint("TOPLEFT", button, "TOPLEFT", vx, -(y + 1))
      f.combo:SetPoint("TOPRIGHT", button, "TOPLEFT", vx + vw, -(y + 1))
    else
      f.combo:SetPoint("TOPLEFT", f.back, "BOTTOMLEFT", x - spec.back[1], -1)
      f.combo:SetPoint("TOPRIGHT", f.back, "BOTTOMLEFT", x - spec.back[1] + width, -1)
    end
  end
  if bars then
    y = y + 2 + 10 -- the small row
  end
  -- under the frame: the cast bar, then the auras (compact / bars: under the bars, where they show)
  local under = compact and y + 4 or nil
  if f.cast then
    local holder, cast = f.cast.holder, spec.cast
    holder:ClearAllPoints()
    if compact then
      holder:SetPoint("TOPLEFT", button, "TOPLEFT", vx, -under)
      holder:SetWidth(vw)
      under = under + cast[4] + 4
    else
      holder:SetPoint("TOPLEFT", button, "TOPLEFT", cast[1], -cast[2])
      holder:SetWidth(cast[3])
    end
  end
  if f.auraContainer then
    local place = AuraPlace(spec)
    local container = f.auraContainer
    container:ClearAllPoints()
    AuraFlow(container, spec, place)
    if place == "above" then
      container:SetPoint("BOTTOMLEFT", button, "TOPLEFT", compact and vx or spec.auras[1], 4)
    elseif place == "right" then
      container:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0)
    elseif place == "left" then
      container:SetPoint("TOPRIGHT", button, "TOPLEFT", -4, 0)
    elseif compact then
      container:SetPoint("TOPLEFT", button, "TOPLEFT", vx, -(under - 1))
    else
      container:SetPoint("TOPLEFT", button, "TOPLEFT", spec.auras[1], -spec.auras[2])
    end
    pcall(container.UpdateAllAuras, container)
  end
  if spec.party then
    partyExtra = math.max(0, f.h - f.spec.h)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", partyHolder, "TOPLEFT", 0, -(spec.party - 1) * PartyStep())
  end
end

local function BuildFrame(spec)
  local theme = S.Theme()
  local button = CreateFrame("Button", "Codex" .. spec.name .. "Frame", UIParent, "SecureUnitButtonTemplate")
  local f = { unit = spec.unit, spec = spec, button = button, w = spec.w, h = spec.h }
  -- the portrait's pieces hang on this point, not on the button: a wider frame moves it (with the portrait) when
  -- the portrait sits on the frame's right (Layout, SizedSpec)
  f.origin = CreateFrame("Frame", nil, button)
  f.origin:SetSize(1, 1)
  f.origin:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button:SetScale(ScaleOf(spec.unit))
  button:SetFrameStrata("LOW")
  button:SetFrameLevel(5) -- (the plate goes one under it, the badges above)
  button:SetClampedToScreen(true)
  button:SetSize(spec.w, spec.h)
  button:SetAttribute("unit", spec.unit)
  button:SetAttribute("*type1", "target")
  button:SetAttribute("*type2", "togglemenu")
  button:RegisterForClicks("AnyUp")
  button:SetScript("OnEnter", Safe(ShowTooltip))
  button:SetScript("OnLeave", Safe(function()
    GameTooltip:Hide()
  end))

  -- the panel style's backdrop: HUD fill and the theme's hud rings (the board's hudLine), its shadow and strip, on
  -- a plate frame one level under the button (so the portrait's rings sit on it) that the compact style hides
  local plate = CreateFrame("Frame", nil, button)
  plate:SetAllPoints(button)
  plate:SetFrameLevel(button:GetFrameLevel() - 1)
  f.plate = plate
  local bx, by, bw, bh = spec.back[1], spec.back[2], spec.back[3], spec.back[4]
  local back = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
  back:SetPoint("TOPLEFT", button, "TOPLEFT", bx, -by)
  back:SetSize(bw, bh)
  S.SetColor(back, theme.hud.fill)
  for _, ring in ipairs(theme.hud.rings or {}) do
    S.Outline(plate, back, ring.inset or 0, ring.size or 1, ring.color, "BACKGROUND", -7)
  end
  f.back, f.backHeight = back, bh
  -- Look options (R3-Polish): the soft shadow round the backdrop, and the decorative strip on its top edge
  -- (under the portrait; the end cap on the side away from it, one piece in the middle where the theme has them)
  f.shadow = S.Shadow(plate, back)
  local strip = theme.strip or {}
  f.strip = S.Strip(plate, back, { layer = "BACKGROUND", sublevel = -6,
    caps = spec.portrait[2] > bx and "left" or "right", mids = (strip.mids or 0) > 0 and 1 or 0 })
  BuildPortrait(f, spec)

  if spec.heading then
    local heading = button:CreateFontString(nil, "OVERLAY")
    HeadFont(heading, 11)
    heading:SetText(spec.heading)
    TextColor(heading, theme.muted)
    f.heading = heading
  end

  -- the column's pieces (Layout places them for the style in use)
  local width = bw - spec.pad[1] - spec.pad[2]
  local name = button:CreateFontString(nil, "OVERLAY")
  BodyFont(name, spec.nameSize) -- as the game writes it (a head font may have only capitals)
  name:SetHeight(spec.nameSize + 2)
  name:SetJustifyH("LEFT")
  if name.SetWordWrap then
    name:SetWordWrap(false)
  end
  TextColor(name, theme.bright)
  f.name = name

  -- rounded themes: the health bar's lower corners stay square where the power bar touches it (and the power
  -- bar's upper ones): one rounded shape, as the boards' unit frames
  local health, healthTop = Bar(button, spec.health, HEALTH, spec.power and { bottom = true } or nil)
  f.health, f.healthTop = health, healthTop
  BuildHeals(f, health, width)
  if spec.healthText then
    f.healthText = BarText(healthTop, spec.healthText)
  end
  if spec.power then
    local power, powerTop = Bar(button, spec.power, nil, { top = true })
    f.power, f.powerTop = power, powerTop
    if spec.powerText then
      f.powerText = BarText(powerTop, spec.powerText)
    end
  end

  if spec.info then
    -- the classification and creature type: small and muted right under the bars (the name keeps its whole row;
    -- the badge's "+" already marks an elite). The panel's backdrop grows to hold the line when the board's
    -- height doesn't; it still ends inside the frame.
    local rows = spec.pad[3] + spec.nameSize + 2 + spec.gap + spec.health + spec.gap + (spec.power or 0)
    local needed = rows + 10 + 1
    if needed > bh then
      bh = needed
      back:SetHeight(bh)
      f.backHeight = bh
    end
    local info = button:CreateFontString(nil, "OVERLAY")
    BodyFont(info, 10)
    info:SetHeight(10)
    info:SetJustifyH("RIGHT")
    TextColor(info, theme.muted)
    f.info = info
  end

  if spec.combo then
    -- five segments just under the bars (shown for rogues and cat-form druids)
    local combo = Bar(button, 3)
    local accent = theme.accent
    Paint(combo, { { accent[1] * 0.6, accent[2] * 0.6, accent[3] * 0.6 }, accent })
    for index = 1, 4 do
      local line = combo:CreateTexture(nil, "OVERLAY")
      line:SetSize(1, 3)
      line:SetPoint("TOPLEFT", combo, "TOPLEFT", math.floor(width * index / 5 + 0.5), 0)
      S.SetColor(line, BLACK)
    end
    combo:SetAlpha(0)
    f.combo = combo
  end

  BuildBadges(f, spec)
  if spec.cast then
    BuildCast(f, spec)
  end
  if spec.auras then
    BuildAuras(f, spec)
  end
  Layout(f)

  if spec.poll then
    local elapsed = 0
    button:SetScript("OnUpdate", function(_, delta)
      elapsed = elapsed + (delta or 0)
      if elapsed >= POLL then
        elapsed = 0
        S.Run("unitframes", UpdateAll, f)
      end
    end)
  end

  if spec.party then
    -- in the party stack (Layout); hidden in a raid (the raid frames show the group), as Blizzard's party frames
    if type(RegisterStateDriver) == "function" then
      RegisterStateDriver(button, "visibility", "[group:raid] hide; [@" .. spec.unit .. ",exists] show; hide")
    elseif type(RegisterUnitWatch) == "function" then
      RegisterUnitWatch(button)
    end
    return f
  end
  ApplyPosition(f)
  if spec.watch and type(RegisterUnitWatch) == "function" then
    RegisterUnitWatch(button)
  end
  return f
end

-- Blizzard's frames -------------------------------------------------------------------------------------------

-- Edit Mode frames replace Hide with Lua that spreads taint: the engine's HideBase is used when it's there.
local function HideNow(frame)
  local hide = frame.HideBase or frame.Hide
  hide(frame)
end

-- Silences a Blizzard unit frame and parks it on our hidden parent for good (out of combat: Park runs in Build).
local function Park(name)
  local frame = S.Get(name)
  if not S.Usable(frame) or not S.Once(frame, "parked") then
    return
  end
  pcall(frame.UnregisterAllEvents, frame)
  for _, key in ipairs(BLIZZARD_BARS) do
    local child = S.Child(frame, key)
    if child and type(child.UnregisterAllEvents) == "function" then
      pcall(child.UnregisterAllEvents, child)
    end
  end
  HideNow(frame)
  frame:SetParent(parking)
  S.HookMethod(frame, "Show", function(self)
    if not S.InCombat() then
      HideNow(self)
    end
  end)
end

-- Is `frame` inside one of the given frames (any level up)?
local function Inside(frame, ...)
  local parent = S.Usable(frame) and frame.GetParent and frame:GetParent()
  for _ = 1, 12 do
    if parent == nil then
      return false
    end
    for index = 1, select("#", ...) do
      if parent == select(index, ...) then
        return true
      end
    end
    parent = parent.GetParent and parent:GetParent()
  end
  return false
end

-- Totem timers: Blizzard's TotemFrame lives in PlayerFrame (it re-parents it there whenever it shows), so it is
-- moved onto a holder under our player frame and pulled back after each of Blizzard's SetParent / SetPoint.
local totemHolder
local placingTotems = false
local function PlaceTotems()
  local totems = S.Get("TotemFrame")
  if placingTotems or not totemHolder or not S.Usable(totems) then
    return
  end
  if S.InCombat() and S.Protected(totems) then
    S.Defer("unitframes:totems", PlaceTotems)
    return
  end
  placingTotems = true
  local ok, err = pcall(function()
    if totems:GetParent() ~= totemHolder then
      totems:SetParent(totemHolder)
    end
    totems:ClearAllPoints()
    totems:SetPoint("TOPLEFT", totemHolder, "TOPLEFT", 0, 0)
  end)
  placingTotems = false
  if not ok then
    error(err, 0)
  end
end

local function AdoptTotems()
  local totems = S.Get("TotemFrame")
  local player = frames.player
  if not S.Usable(totems) or not player or not S.Once(totems, "unitframes") then
    return
  end
  totemHolder = CreateFrame("Frame", nil, player.button)
  totemHolder:SetSize(1, 1)
  totemHolder:SetPoint("TOPLEFT", player.button, "BOTTOMLEFT", player.columnX, -4)
  PlaceTotems()
  S.HookMethod(totems, "SetParent", PlaceTotems)
  S.HookMethod(totems, "SetPoint", PlaceTotems)
end

-- Other class bars Blizzard keeps on the player frame: not rebuilt here, so the player is told (once) which went.
local CLASS_BARS = { "RuneFrame", "PaladinPowerBarFrame", "MonkHarmonyBarFrame", "MonkStaggerBar", "WarlockPowerFrame",
  "MageArcaneChargesFrame", "EssencePlayerFrame", "EvokerEbonMightBar", "AlternatePowerBar", "PlayerFrameAlternatePowerBarArea" }
local function ShownClassBars()
  local shown = {}
  local player = S.Get("PlayerFrame")
  for _, name in ipairs(CLASS_BARS) do
    local bar = S.Get(name)
    if player and S.Usable(bar) and bar.IsShown and bar:IsShown() and Inside(bar, player) then
      shown[#shown + 1] = name
    end
  end
  return shown
end

-- Blizzard's player cast bar locked to the player frame ("Lock to Player Frame" in Edit Mode) sits inside
-- PlayerFrame, so it went with it. We don't move Edit Mode systems: the player is told once how to unlock it.
local warned = false
local function WarnCastBar()
  local bar = S.Get("PlayerCastingBarFrame")
  if warned or not S.Usable(bar) then
    return
  end
  if Inside(bar, S.Get("PlayerFrame"), parking) then
    warned = true
    print(PREFIX .. "your cast bar is locked to the player frame, which Codex replaces, so it is hidden. "
      .. "To get it back: Edit Mode, click the Cast Bar, untick \"Lock to Player Frame\".")
  end
end

-- Blizzard's player cast bar in Codex's look (2026-11-22, the user's screenshot of a craft: "apply our design to
-- here also add time"). Forever's PlayerCastingBarFrame (Blizzard_UIPanels_Game Shared/CastingBarFrame.lua, Mainline
-- CastingBarFrame.xml) keeps its logic, place and size (an Edit Mode system in the bottom frame stack, which lays
-- out by height: never resized). Its art and effects are hidden (kept hidden on Show; animations only change alpha);
-- the fill per cast type comes from UpdateBarFillTexture: a post hook paints ours (the accent, CAST_LOCKED when it
-- can't be interrupted, the theme's bad colour when interrupted); the name goes inside the bar (post hook on SetLook,
-- which places it); the time left is ours, from the bar's own value / maxValue (plain numbers for your own casts).
local CastBar = {} -- (one local: this file is at Lua's 200-local limit)
CastBar.ART = { "Border", "TextBorder", "Background", "DropShadow", "BorderShield", "Spark", "Flash", "ChargeFlash",
  "StandardGlow", "CraftGlow", "ChannelShadow", "Flakes01", "Flakes02", "Flakes03", "Shine", "EnergyGlow", "BaseGlow",
  "WispGlow", "Sparkles01", "Sparkles02", "InterruptGlow", "ChargeGlow" }

function CastBar.Fill(bar)
  local theme = S.Theme()
  local kind = bar.barType
  local color = kind == "interrupted" and theme.bad or kind == "uninterruptable" and CAST_LOCKED or theme.accent
  local texture = bar:GetStatusBarTexture()
  if S.IsRegion(texture) and bar.BorderMask and texture.RemoveMaskTexture then
    pcall(texture.RemoveMaskTexture, texture, bar.BorderMask)
  end
  bar:SetStatusBarTexture(WHITE)
  Paint(bar, { { color[1] * 0.6, color[2] * 0.6, color[3] * 0.6 }, color })
end

function CastBar.Text(bar)
  local text = bar.Text
  if not S.IsRegion(text) then
    return
  end
  BodyFont(text, 10, BAR_FONT, "OUTLINE")
  text:ClearAllPoints()
  text:SetWidth(0)
  text:SetPoint("LEFT", bar, "LEFT", 4, 0)
  text:SetPoint("RIGHT", bar, "RIGHT", -34, 0)
  text:SetJustifyH("LEFT")
  if text.SetWordWrap then
    text:SetWordWrap(false)
  end
end

function CastBar.Time(bar)
  local time = bar.codexTime
  if not time then
    return
  end
  local value, max = bar.value, bar.maxValue
  if (bar.casting or bar.channeling) and CanRead(value) and CanRead(max) and type(value) == "number"
    and type(max) == "number" then
    local left = bar.casting and max - value or value
    time:SetFormattedText("%.1f", math.max(0, left))
  else
    time:SetText("")
  end
end

function CastBar.Style()
  local bar = S.Get("PlayerCastingBarFrame")
  if not S.Usable(bar) or not S.Once(bar, "codexcast") then
    return
  end
  for _, key in ipairs(CastBar.ART) do
    local region = bar[key]
    if S.IsRegion(region) then
      region:SetAlpha(0)
      region:Hide()
      hooksecurefunc(region, "Show", function(self)
        self:Hide()
      end)
    end
  end
  local back = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  back:SetAllPoints(bar)
  S.SetColor(back, BAR_BACK)
  local top = CreateFrame("Frame", nil, bar)
  top:SetAllPoints(bar)
  top:SetFrameLevel((bar:GetFrameLevel() or 1) + 5)
  local line = S.Theme().titlebar.line
  S.Outline(top, bar, 0, 1, BLACK, "BORDER")
  S.Outline(top, bar, -1, 1, { line[1], line[2], line[3], 0.75 }, "BORDER")
  if S.IsRegion(bar.Icon) then
    local icon = bar.Icon
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- the line round the icon only while the game shows the icon (Edit Mode's "Show icon"; an empty square
    -- stayed beside the bar with it off: the user's screenshot, 2026-11-22)
    local lines = S.Outline(top, icon, -1, 1, BLACK, "BORDER")
    local function Follow()
      local shown = icon:IsShown() and true or false
      for _, line in ipairs(lines) do
        line:SetShown(shown)
      end
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
      hooksecurefunc(icon, method, Follow)
    end
    Follow()
  end
  if S.IsRegion(bar.Text) and bar.Text.SetParent then
    bar.Text:SetParent(top) -- over our lines
  end
  local time = top:CreateFontString(nil, "OVERLAY")
  SetFont(time, BAR_FONT, 10, "OUTLINE")
  time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  time:SetJustifyH("RIGHT")
  TextColor(time, { 1, 1, 1 })
  bar.codexTime = time
  CastBar.Fill(bar)
  CastBar.Text(bar)
  S.HookMethod(bar, "UpdateBarFillTexture", CastBar.Fill)
  S.HookMethod(bar, "SetLook", CastBar.Text)
  bar:HookScript("OnUpdate", Safe(CastBar.Time))
  S.HookMethod(bar, "UpdateCastTimeText", CastBar.Time)
end

-- Party frames are Codex's unless the part is off or the player uses raid-style party frames (Edit Mode's
-- "Use Raid-Style Party Frames"; the older CVar as a fallback).
function RaidStyleParty()
  local manager = S.Get("EditModeManagerFrame")
  if manager and type(manager.UseRaidStylePartyFrames) == "function" then
    local ok, on = pcall(manager.UseRaidStylePartyFrames, manager)
    if ok and CanRead(on) then
      return on and true or false
    end
  end
  if C_CVar and type(C_CVar.GetCVarBool) == "function" then
    local ok, on = pcall(C_CVar.GetCVarBool, "useCompactPartyFrames")
    if ok and CanRead(on) then
      return on and true or false
    end
  end
  return false
end

local function PartyOn()
  return TylesserCodex and TylesserCodex.SkinPartOn and TylesserCodex.SkinPartOn("partyframes") and true or false
end

-- Edit Mode movers ---------------------------------------------------------------------------------------------

local function SavePosition(f, mover)
  local saved = SavedPositions(true)
  -- the top left corner, so a frame (or the party stack) that changes size keeps its top in place
  local left, top = mover:GetLeft(), mover:GetTop()
  if saved and type(left) == "number" and type(top) == "number" then
    saved[f.unit] = { "TOPLEFT", "BOTTOMLEFT", math.floor(left + 0.5), math.floor(top + 0.5) }
    Place(f)
    return
  end
  local point, _, relativePoint, x, y = mover:GetPoint(1)
  if not saved or type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  saved[f.unit] = { point, type(relativePoint) == "string" and relativePoint or point, math.floor(x + 0.5),
    math.floor(y + 0.5) }
  Place(f)
end

-- The mover over its frame (the party stack: only as tall as the members there are, at least one).
local function FitMover(f)
  local mover = f.mover
  if f.unit == "party" then
    local count = math.max(1, math.min(4, Readable(Call(GetNumSubgroupMembers)) or 0))
    f.h = count * PartyStep() - PARTY_GAP
    if not S.InCombat() then
      f.button:SetSize(f.w, f.h)
    end
  end
  local scale = ScaleOf(f.unit)
  mover:SetSize(f.w * scale, f.h * scale)
  mover:ClearAllPoints()
  mover:SetPoint("TOPLEFT", f.button, "TOPLEFT", 0, 0)
  if f.moverLabel then
    local wide, tall = Shape.Of(f.unit)
    local text = math.abs(scale - 1) < 0.001 and f.spec.label
      or ("%s  %d%%"):format(f.spec.label, math.floor(scale * 100 + 0.5))
    if wide ~= 1 or tall ~= 1 then
      text = ("%s  ·  %d%% x %d%%"):format(text, math.floor(wide * 100 + 0.5), math.floor(tall * 100 + 0.5))
    end
    f.moverLabel:SetText(text)
  end
end

-- A frame (or the party stack) at its saved size, then placed again for it. Out of combat (Edit Mode).
local function ApplyScale(f)
  if S.InCombat() then
    return
  end
  local scale = ScaleOf(f.unit)
  if f.unit == "party" then
    for index = 1, 4 do
      local member = frames["party" .. index]
      if member then
        member.button:SetScale(scale)
      end
    end
  else
    f.button:SetScale(scale)
  end
  Place(f)
  -- a frame attached to this one (target of target beside the target) keeps its distance
  for _, other in pairs(frames) do
    if other.spec.attach and other.spec.attach[1] == f.unit then
      Place(other)
    end
  end
end

-- Sets a frame's size (nil: back to 100 %), in SCALE_STEP steps between SCALE_MIN and SCALE_MAX.
local function SetScale(f, value)
  local saved = SavedScales(true)
  if not saved then
    return
  end
  if value then
    value = math.floor(value / SCALE_STEP + 0.5) * SCALE_STEP
    value = math.max(SCALE_MIN, math.min(SCALE_MAX, value))
    if math.abs(value - 1) < 0.001 then
      value = nil
    end
  end
  saved[f.unit] = value
  ApplyScale(f)
  if f.mover then
    FitMover(f)
  end
end
-- Sets a frame's width or height (key "w" / "h"; nil: back to the board's), in SCALE_STEP steps, and lays it out
-- again (party: every member and the stack). Out of combat (Edit Mode).
local function SetShape(f, key, value)
  if S.InCombat() or type(CodexDB) ~= "table" then
    return
  end
  CodexDB.skins = CodexDB.skins or {}
  CodexDB.skins.frameShape = type(CodexDB.skins.frameShape) == "table" and CodexDB.skins.frameShape or {}
  local unit = Shape.Key(f.unit)
  local saved = CodexDB.skins.frameShape[unit] or {}
  if value then
    local limits = Shape.LIMITS[key]
    value = math.floor(math.max(limits[1], math.min(limits[2], value)) / SCALE_STEP + 0.5) * SCALE_STEP
    value = math.floor(value * 100 + 0.5) / 100 -- (1.2, not 1.2000000000000002)
    if math.abs(value - 1) < 0.001 then
      value = nil
    end
  end
  saved[key] = value
  CodexDB.skins.frameShape[unit] = next(saved) and saved or nil
  if unit == "party" then
    for index = 1, 4 do
      local member = frames["party" .. index]
      if member then
        Layout(member)
      end
    end
    if partyStack and frames.party1 then
      partyStack.w = frames.party1.w
      partyHolder:SetSize(partyStack.w, partyStack.h)
    end
  elseif frames[f.unit] then
    Layout(frames[f.unit])
  end
  ApplyScale(f)
  if f.mover then
    FitMover(f)
  end
end
S.SetUnitFrameShape = function(unit, key, value)
  for _, f in ipairs(placeables) do
    if f.unit == unit then
      SetShape(f, key, value)
    end
  end
end

S.SetUnitFrameScale = function(unit, value)
  for _, f in ipairs(placeables) do
    if f.unit == unit then
      SetScale(f, value)
    end
  end
end

local function ResetPosition(f)
  local saved = SavedPositions(false)
  if saved then
    saved[f.unit] = nil
  end
  Place(f)
  FitMover(f)
end

local function BuildMover(f)
  local theme = S.Theme()
  local mover = CreateFrame("Frame", nil, UIParent)
  mover:SetFrameStrata("DIALOG")
  mover:SetSize(f.w, f.h)
  mover:SetClampedToScreen(true)
  mover:SetMovable(true)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  local fill = mover:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(mover)
  S.SetColor(fill, theme.accent, 0.3)
  S.Outline(mover, mover, 0, 1, theme.accent, "BORDER")
  local label = mover:CreateFontString(nil, "OVERLAY")
  HeadFont(label, 13)
  label:SetPoint("CENTER", mover, "CENTER", 0, 0)
  label:SetText(f.spec.label)
  TextColor(label, theme.bright)
  f.moverLabel = label
  -- the mouse wheel sizes the frame (Shift + right-click: 100 % again)
  mover:EnableMouseWheel(true)
  mover:SetScript("OnMouseWheel", Safe(function(_, delta)
    if S.InCombat() then
      return
    end
    local step = delta > 0 and SCALE_STEP or -SCALE_STEP
    local wide, tall = Shape.Of(f.unit)
    if IsShiftKeyDown and IsShiftKeyDown() then
      SetShape(f, "w", wide + step) -- just the width
    elseif IsControlKeyDown and IsControlKeyDown() then
      SetShape(f, "h", tall + step) -- just the height
    else
      SetScale(f, ScaleOf(f.unit) + step)
    end
  end))
  mover:SetScript("OnEnter", Safe(function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(f.spec.label)
    local wide, tall = Shape.Of(f.unit)
    GameTooltip:AddLine("Drag to move. Mouse wheel: size (" .. math.floor(ScaleOf(f.unit) * 100 + 0.5) .. "%).", 1, 1, 1, true)
    GameTooltip:AddLine(("Shift + wheel: width (%d%%). Ctrl + wheel: height (%d%%)."):format(
      math.floor(wide * 100 + 0.5), math.floor(tall * 100 + 0.5)), 1, 1, 1, true)
    GameTooltip:AddLine("Right-click: back to its place. Shift + right-click: size, width and height back to 100 %.",
      0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end))
  mover:SetScript("OnLeave", Safe(function()
    GameTooltip:Hide()
  end))
  mover:SetScript("OnDragStart", Safe(function(self)
    if not S.InCombat() then
      self:StartMoving()
    end
  end))
  mover:SetScript("OnDragStop", Safe(function(self)
    self:StopMovingOrSizing()
    SavePosition(f, self)
  end))
  mover:SetScript("OnMouseUp", Safe(function(_, button)
    if button == "RightButton" then
      if IsShiftKeyDown and IsShiftKeyDown() then
        SetScale(f, nil)
        SetShape(f, "w", nil)
        SetShape(f, "h", nil)
      else
        ResetPosition(f)
      end
    end
  end))
  mover:Hide()
  f.mover = mover
  return mover
end

local function ShowMovers()
  for _, f in ipairs(placeables) do
    local mover = f.mover or BuildMover(f)
    FitMover(f)
    mover:Show()
  end
  for _, f in pairs(frames) do
    if f.auraContainer then
      pcall(f.auraContainer.SetEditModePreviewEnabled, f.auraContainer, true)
    end
  end
end

local styleNoted = false
local function HideMovers()
  for _, f in ipairs(placeables) do
    if f.mover then
      f.mover:StopMovingOrSizing()
      f.mover:Hide()
    end
  end
  for _, f in pairs(frames) do
    if f.auraContainer then
      pcall(f.auraContainer.SetEditModePreviewEnabled, f.auraContainer, false)
    end
  end
  WarnCastBar()
  -- "Use Raid-Style Party Frames" switched in Edit Mode: which party frames show is decided at load
  if partyStyle ~= nil and RaidStyleParty() ~= partyStyle and not styleNoted then
    styleNoted = true
    print(PREFIX .. "party frame style changed: /reload to switch between Codex's party frames and the raid-style ones.")
  end
end

local function HookEditMode()
  local manager = S.Get("EditModeManagerFrame")
  if not S.Usable(manager) or not S.Once(manager, "unitframes") then
    return
  end
  S.HookScript(manager, "OnShow", ShowMovers)
  S.HookScript(manager, "OnHide", HideMovers)
  if manager:IsShown() then
    ShowMovers()
  end
end

-- Events ------------------------------------------------------------------------------------------------------

local UNIT_EVENTS = {
  UNIT_HEALTH = UpdateHealth, UNIT_MAXHEALTH = UpdateHealth, UNIT_HEAL_PREDICTION = UpdateHeals,
  UNIT_ABSORB_AMOUNT_CHANGED = UpdateHeals, UNIT_CONNECTION = UpdateAll, UNIT_FLAGS = UpdatePortrait,
  UNIT_POWER_UPDATE = UpdatePower, UNIT_MAXPOWER = UpdatePower, UNIT_DISPLAYPOWER = UpdatePower,
  -- (the game sends this one many times a second while power fills, as Personal bars use it; UNIT_POWER_UPDATE came
  -- in steps, so mana and energy jumped on the frames while drinking: the user's report, 2026-11-22)
  UNIT_POWER_FREQUENT = UpdatePower,
  UNIT_NAME_UPDATE = UpdateName, UNIT_FACTION = UpdateName, UNIT_LEVEL = UpdateLevel,
  UNIT_CLASSIFICATION_CHANGED = UpdateAll,
  UNIT_PORTRAIT_UPDATE = UpdatePortrait, UNIT_MODEL_CHANGED = UpdatePortrait,
  UNIT_SPELLCAST_START = UpdateCasting, UNIT_SPELLCAST_STOP = UpdateCasting, UNIT_SPELLCAST_FAILED = UpdateCasting,
  UNIT_SPELLCAST_INTERRUPTED = UpdateCasting, UNIT_SPELLCAST_DELAYED = UpdateCasting,
  UNIT_SPELLCAST_CHANNEL_START = UpdateCasting, UNIT_SPELLCAST_CHANNEL_UPDATE = UpdateCasting,
  UNIT_SPELLCAST_CHANNEL_STOP = UpdateCasting, UNIT_SPELLCAST_INTERRUPTIBLE = UpdateCasting,
  UNIT_SPELLCAST_NOT_INTERRUPTIBLE = UpdateCasting,
}

-- Blizzard's parked TargetFrame no longer plays the target sounds: played here as it did.
local hadTarget = false
local function TargetSound()
  local had = hadTarget
  hadTarget = Readable(UnitExists("target")) and true or false
  if type(PlaySound) ~= "function" or type(SOUNDKIT) ~= "table" then
    return
  end
  if not hadTarget then
    -- (losing a soft target stays silent, as on Blizzard's frame)
    if had and not (type(IsTargetLoose) == "function" and IsTargetLoose()) then
      PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, nil, true)
    end
    return
  end
  local interaction = C_PlayerInteractionManager
  if interaction and interaction.IsReplacingUnit and interaction.IsReplacingUnit() then
    return
  end
  if Readable(Call(UnitIsEnemy, "target", "player")) == true then
    PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
  elseif Readable(Call(UnitIsFriend, "player", "target")) == true then
    PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
  else
    PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
  end
end

local OTHER_EVENTS = {
  PLAYER_ENTERING_WORLD = UpdateEverything,
  PLAYER_TARGET_CHANGED = function()
    TargetSound()
    UpdateAll(frames.target)
    UpdateAuras(frames.target)
    UpdateAll(frames.targettarget)
  end,
  PLAYER_FOCUS_CHANGED = function()
    UpdateAll(frames.focus)
    UpdateAuras(frames.focus)
  end,
  UNIT_TARGET = function(unit)
    if unit == "target" then
      UpdateAll(frames.targettarget)
    end
  end,
  UNIT_PET = function(unit)
    if unit == "player" then
      UpdateAll(frames.pet)
    end
  end,
  PLAYER_REGEN_DISABLED = UpdateIcons, PLAYER_REGEN_ENABLED = UpdateIcons, PLAYER_UPDATE_RESTING = UpdateIcons,
  GROUP_ROSTER_UPDATE = function()
    UpdateIcons()
    UpdateParty()
  end,
  PARTY_LEADER_CHANGED = function()
    UpdateIcons()
    UpdateAllPartyIcons()
  end,
  RAID_TARGET_UPDATE = UpdateAllPartyIcons, PLAYER_ROLES_ASSIGNED = UpdateAllPartyIcons,
}

-- UNIT_* events: one listener per unit, registered for that unit only (no nameplate or raid floods).
local UNIT_ONLY = { UNIT_TARGET = "target", UNIT_PET = "player" } -- other events about one unit

local function OnUnitEvent(listener, event, unit)
  if unit ~= listener.unit then
    return
  end
  local f = frames[unit]
  local fn = UNIT_EVENTS[event]
  if f and fn then
    fn(f, true) -- (an event about the unit shown: its bars glide)
  end
  -- the player's combo points and form live on the target frame
  if unit == "player" and (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") then
    UpdateCombo()
  end
end

local function OnEvent(_, event, unit)
  local fn = OTHER_EVENTS[event]
  if fn then
    fn(unit)
  end
end

-- (pcall: registering an event this client doesn't have is an error)
local function Listen(frame, event, unit)
  if unit and frame.RegisterUnitEvent then
    pcall(frame.RegisterUnitEvent, frame, event, unit)
  else
    pcall(frame.RegisterEvent, frame, event)
  end
end

-- Build ----------------------------------------------------------------------------------------------------

local function Build()
  if built then
    return
  end
  built = true
  parking = CreateFrame("Frame", nil, UIParent)
  parking:Hide()
  local partyOn = PartyOn() and not RaidStyleParty()
  if PartyOn() then
    partyStyle = not partyOn
  end
  if partyOn then
    partyHolder = CreateFrame("Frame", nil, UIParent)
    partyHolder:SetSize(1, 1)
  end
  for _, spec in ipairs(UNITS) do
    if not spec.party then
      frames[spec.unit] = BuildFrame(spec)
      placeables[#placeables + 1] = frames[spec.unit]
    elseif partyOn then
      frames[spec.unit] = BuildFrame(spec)
    end
  end
  if partyOn then
    -- the stack as one piece for Edit Mode, and the range fade on a timer
    local stack = { unit = "party", spec = { label = "Party", pos = PARTY_POS }, button = partyHolder,
      w = frames.party1.w, h = PartyStep() - PARTY_GAP }
    partyHolder:SetSize(stack.w, stack.h)
    SetPosition(partyHolder, PositionOf(stack))
    placeables[#placeables + 1] = stack
    partyStack = stack
    local elapsed = 0
    partyHolder:SetScript("OnUpdate", function(_, delta)
      elapsed = elapsed + (delta or 0)
      if elapsed >= RANGE_POLL then
        elapsed = 0
        for index = 1, 4 do
          local f = frames["party" .. index]
          if f and f.button:IsShown() then
            S.Run("unitframes", UpdateRange, f)
          end
        end
      end
    end)
  end
  local lostBars = ShownClassBars() -- (looked at before the player frame is hidden)
  for _, name in ipairs(BLIZZARD) do
    Park(name)
  end
  if partyOn then
    -- Blizzard's party frames: the members first (silenced), then the whole frame parked
    local blizzardParty = S.Get("PartyFrame")
    for index = 1, 4 do
      local members = { S.Child(blizzardParty, "MemberFrame" .. index) or false, S.Get("PartyMemberFrame" .. index) or false }
      for _, member in ipairs(members) do
        if S.Usable(member) and type(member.UnregisterAllEvents) == "function" then
          pcall(member.UnregisterAllEvents, member)
        end
      end
    end
    Park("PartyFrame")
  end
  AdoptTotems()
  WarnCastBar()
  S.HookGlobal("PlayerFrame_AttachCastBar", WarnCastBar)
  S.Run("unitframes", CastBar.Style)
  if #lostBars > 0 then
    print(PREFIX .. "this class bar sat on the player frame, which Codex replaces, and is hidden with it: "
      .. table.concat(lostBars, ", ") .. ". Turn off \"Player, target, pet and focus frames\" in Codex to get it back.")
  end
  for _, spec in ipairs(UNITS) do
    if not spec.poll and frames[spec.unit] then
      local listener = CreateFrame("Frame")
      listener.unit = spec.unit
      for event in pairs(UNIT_EVENTS) do
        Listen(listener, event, spec.unit)
      end
      listener:SetScript("OnEvent", Safe(OnUnitEvent))
    end
  end
  local events = CreateFrame("Frame")
  for event in pairs(OTHER_EVENTS) do
    Listen(events, event, UNIT_ONLY[event])
  end
  events:SetScript("OnEvent", Safe(OnEvent))
  if S.Get("EditModeManagerFrame") then
    HookEditMode()
  else
    S.OnAddOn("Blizzard_EditMode", HookEditMode)
  end
  UpdateEverything()
end

S.Part("unitframes", function()
  S.Defer("unitframes", Build)
end)

-- Settings changed the text format (CodexDB.skins.unitText): every bar's text again, now.
TylesserCodex.RefreshUnitText = function()
  S.Run("unitframes", function()
    for _, f in pairs(frames) do
      if Exists(f.unit) then
        UpdateHealth(f)
        UpdatePower(f)
      end
    end
  end)
end

-- Settings changed the health bar colour (CodexDB.skins.healthColor): every bar again, now (colours only, so it is
-- safe in combat too).
TylesserCodex.RefreshHealthColor = function()
  S.Run("unitframes", function()
    for _, f in pairs(frames) do
      if Exists(f.unit) then
        UpdateName(f) -- (the name's colour follows the setting too; it paints the health bar)
      else
        f.healthColors = nil
      end
    end
  end)
end

-- "First names only" changed: every shown frame writes its name again.
TylesserCodex.RefreshNames = function()
  S.Run("unitframes", function()
    for _, f in pairs(frames) do
      if Exists(f.unit) and f.name then
        UpdateName(f)
      end
    end
  end)
end

-- Settings changed the frame style (CodexDB.skins.frameStyle): every frame laid out again, out of combat.
-- Every frame's health and power painted again (the gradient direction changed: the colours are cached per frame).
TylesserCodex.RepaintBars = function()
  for _, f in pairs(frames) do
    if f.health and f.healthColors then
      Paint(f.health, f.healthColors)
    end
    if f.power and f.powerColors then
      Paint(f.power, f.powerColors)
    end
  end
end

TylesserCodex.RefreshFrameStyle = function()
  S.Defer("unitframes:style", function()
    for _, f in pairs(frames) do
      Layout(f)
    end
    if partyStack then
      partyStack.h = PartyStep() - PARTY_GAP
      partyHolder:SetSize(partyStack.w, partyStack.h)
      if partyStack.mover and partyStack.mover:IsShown() then
        FitMover(partyStack)
      end
    end
    if totemHolder and frames.player then
      totemHolder:ClearAllPoints()
      totemHolder:SetPoint("TOPLEFT", frames.player.button, "BOTTOMLEFT", frames.player.columnX, -4)
    end
    for _, f in pairs(frames) do
      if Exists(f.unit) then
        UpdateName(f)
      end
    end
  end)
end

-- The aura containers, now (see MakeAuras).
if TylesserCodex and TylesserCodex.SkinPartOn and TylesserCodex.SkinPartOn("unitframes") then
  S.Run("unitframes", function()
    for _, spec in ipairs(UNITS) do
      if spec.auras and (not spec.party or PartyOn()) then
        early[spec.unit] = MakeAuras(spec)
      end
    end
  end)
end
