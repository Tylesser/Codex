local addonName, ns = ...

-- Settings: the skins parts and their option values, theme previews, look options, and the sections of the Look,
-- General (Codex window), Tooltips (prices and stats) and Profiles pages (Areas.lua builds the pages).

local UI = ns.UI

-- Parts of the game's UI that Codex_Skins can restyle. The skins folder handles each id.
ns.SKIN_PARTS = {
  { id = "actionbars", name = "Action bars" },
  { id = "barpanels", name = "Panel behind the action bars", default = false },
  { id = "unitframes", name = "Player, target, pet and focus frames" },
  { id = "partyframes", name = "Party frames" },
  { id = "raidframes", name = "Raid frames" },
  { id = "nameplates", name = "Nameplates" },
  { id = "auras", name = "Buffs and debuffs" },
  { id = "cooldowns", name = "Cooldown manager" },
  { id = "roundicons", name = "Round icons (buffs, debuffs, cooldown manager)", default = false },
  { id = "minimap", name = "Minimap" },
  { id = "chat", name = "Chat" },
  { id = "tracker", name = "Quest tracker" },
  { id = "damagemeter", name = "Damage meter" },
  { id = "questlog", name = "Quest log and world map" },
  { id = "tooltips", name = "Tooltips" },
  { id = "menus", name = "Dropdown and right-click menus" },
  { id = "lootroll", name = "Loot roll window", default = true },
  { id = "questpins", name = "All your quests on continent, world and flight maps", default = true },
  { id = "windows", name = "Game windows (character, bags, spellbook, ...)" },
  -- set at Codex's ADDON_LOADED (Theme.lua, ns.ApplyFloatingTextFont): the skins folder loads too late for it
  { id = "floatingtext", name = "Floating combat text and damage numbers", default = true },
}

-- UI addons that change the same frames as Codex's interface parts.
local OVERLAPPING = { "FlareUI", "ElvUI", "ClassicUI" }
ns.OVERLAP_NOTE = "%s is also changing the game's interface (it replaces or restyles the same frames). "
  .. "Switch it off in the AddOns list to see Codex's look, or switch Codex's off here."
function ns.UIOverlap()
  for _, name in ipairs(OVERLAPPING) do
    if ns.IsAddOnLoaded(name) then
      return name
    end
  end
end

local function PartDefault(id)
  for _, part in ipairs(ns.SKIN_PARTS) do
    if part.id == id then
      return part.default ~= false
    end
  end
  return true
end

-- A part's own setting, or its default when the player hasn't set it.
function ns.SkinPartWanted(id)
  local value = ns.db.skins.parts[id]
  if value == nil then
    return PartDefault(id)
  end
  return value and true or false
end

-- How the bars of Codex's unit frames show their numbers (CodexDB.skins.unitText[bar]).
ns.UNIT_TEXT_FORMATS = {
  { key = "value", name = "Amount (1.9K / 2.1K)" },
  { key = "percent", name = "Percent (73%)" },
  { key = "both", name = "Amount and percent" },
  { key = "none", name = "No text" },
}

-- Each bar's format when the player hasn't picked one (bars not listed: "value").
ns.UNIT_TEXT_DEFAULTS = { health = "value", power = "value", nameplate = "both" }

function ns.UnitTextFormat(bar)
  local saved = ns.db and ns.db.skins and ns.db.skins.unitText
  local value = saved and saved[bar]
  for _, format in ipairs(ns.UNIT_TEXT_FORMATS) do
    if format.key == value then
      return value
    end
  end
  return ns.UNIT_TEXT_DEFAULTS[bar] or "value"
end

-- Short numbers on unit frames and nameplates (1.9K instead of 1,920); CodexDB.skins.unitText.short, off by default.
function ns.UnitTextShort()
  local saved = ns.db and ns.db.skins and ns.db.skins.unitText
  return saved and saved.short == true or false
end
ns.API.UnitTextShort = ns.UnitTextShort

-- How Codex's unit frames are drawn (CodexDB.skins.frameStyle): compact (bars on the portrait ring, nothing
-- behind them; the default), panel (a backdrop plate behind the bars) or bars (no portrait, the name in the bar).
ns.FRAME_STYLES = {
  { key = "compact", name = "Compact", desc = "Bars on the portrait" },
  { key = "panel", name = "Panel", desc = "Backdrop behind the bars" },
  { key = "bars", name = "Bars only", desc = "No portrait, the name in the bar" },
}

function ns.FrameStyle()
  local skins = ns.db and ns.db.skins
  local style = skins and skins.frameStyle
  for _, known in ipairs(ns.FRAME_STYLES) do
    if known.key == style then
      return style
    end
  end
  return "compact"
end
ns.API.FrameStyle = ns.FrameStyle

-- The way unit frame bars shade (CodexDB.skins.barGradient: nil = top to bottom, "horizontal" = left to right;
-- 2026-11-22, after the user's "make unit frame colours gradient").
ns.BAR_GRADIENTS = { { key = "vertical", name = "Top to bottom" }, { key = "horizontal", name = "Left to right" } }
function ns.BarGradient()
  local skins = ns.db and ns.db.skins
  return skins and skins.barGradient == "horizontal" and "horizontal" or "vertical"
end

-- Where a unit frame's auras go (CodexDB.skins.auraPos[unit]: "target", "focus", "party"; nil = below; 2026-11-22).
ns.AURA_PLACES = {
  { key = "below", name = "Below the frame" },
  { key = "above", name = "Above the frame" },
  { key = "right", name = "Right of the frame" },
  { key = "left", name = "Left of the frame" },
}
local AURA_PLACE_KEYS = { below = true, above = true, right = true, left = true }
function ns.AuraPlace(unit)
  local skins = ns.db and ns.db.skins
  local place = skins and type(skins.auraPos) == "table" and skins.auraPos[unit]
  return AURA_PLACE_KEYS[place] and place or "below"
end
ns.API.AuraPlace = ns.AuraPlace

-- Players on the unit frames by first name only, no surname (CodexDB.skins.firstNameOnly; 2026-11-22).
function ns.FirstNameOnly()
  local skins = ns.db and ns.db.skins
  return skins and skins.firstNameOnly == true or false
end
ns.API.FirstNameOnly = ns.FirstNameOnly

-- Health bars in class colours (CodexDB.skins.healthColor = "class"); nil = green.
function ns.ClassHealth()
  local skins = ns.db and ns.db.skins
  return skins and skins.healthColor == "class" or false
end
ns.API.ClassHealth = ns.ClassHealth

function ns.FrameStyleName(key)
  for _, style in ipairs(ns.FRAME_STYLES) do
    if style.key == key then
      return style.name
    end
  end
  return key
end

-- Health and power bars fill gradually (CodexDB.skins.smoothBars: nil or true = on, false = off).
function ns.SmoothBars()
  local skins = ns.db and ns.db.skins
  return not (skins and skins.smoothBars == false)
end
ns.API.SmoothBars = ns.SmoothBars

function ns.UnitTextName(key)
  for _, format in ipairs(ns.UNIT_TEXT_FORMATS) do
    if format.key == key then
      return format.name
    end
  end
  return key
end

-- Gap Codex leaves round each icon it draws (buffs, cooldown manager), in pixels.
function ns.IconSpacing()
  local value = ns.db and ns.db.skins and ns.db.skins.iconSpacing
  return type(value) == "number" and value or 3
end

-- The guided setup for the action bars (Edit Mode does the moving).
ns.BAR_GUIDE = table.concat({
  "Open Edit Mode (Esc > Edit Mode), click a bar and drag it. Positions that suit the panels:",
  "1. Main bar: bottom centre, 12 buttons in 1 row.",
  "2. Bar 2: right above the main bar, same width, with a small gap so the panels don't touch.",
  "3. Bar 3: above bar 2, or as a column at the right edge of the screen.",
  "4. Pet and stance bars: above bar 2's left end. The experience bar: under the main bar.",
  "Then click Check spacing to see whether any panels still overlap.",
}, "\n")

-- One line about the bar panels' spacing (Settings > Check spacing).
function ns.BarSpacingText()
  local check = ns.API.BarSpacing
  if not (ns.db.skins.enabled and ns.SkinPartOn("barpanels")) or type(check) ~= "function" then
    return "Switch on \"Panel behind the action bars\" (and reload) first."
  end
  if InCombatLockdown() then
    return "Try again after the fight."
  end
  local ok, found = pcall(check)
  if not ok or not found then
    return "The bars couldn't be measured right now."
  end
  if #found == 0 then
    return "All clear: no panels overlap."
  end
  local lines = {}
  for _, pair in ipairs(found) do
    -- the smaller move clears it
    local how = pair.y <= pair.x and ("%d up or down"):format(pair.y) or ("%d left or right"):format(pair.x)
    lines[#lines + 1] = ("%s and %s overlap: move one %s."):format(pair.a, pair.b, how)
  end
  return table.concat(lines, "\n")
end

function ns.SkinPartOn(id)
  return ns.db.skins.enabled and ns.SkinPartWanted(id)
end
ns.API.SkinPartOn = ns.SkinPartOn
ns.API.SKIN_PARTS = ns.SKIN_PARTS

-- Theme preview cards (Settings > Look). Only the chosen theme is loaded, so the colours of the others are
-- copied here from Themes/*/Theme.lua (keep them in step when a theme changes).
local CODEX_MEDIA = "Interface\\AddOns\\Codex\\Media\\"
local PREVIEW = {
  runestone = { head = CODEX_MEDIA .. "Cinzel-Bold.ttf", upper = true,
    text = { 0.91, 0.87, 0.78 }, muted = { 0.72, 0.65, 0.49 },
    panel = { { 0.09, 0.07, 0.11 }, { 0.15, 0.13, 0.18 } }, rings = { { 0.78, 0.54, 0.12 }, { 0.29, 0.18, 0.02 } },
    title = { { 0.14, 0.08, 0.04 }, { 0.29, 0.16, 0.06 } }, titleLine = { 0.78, 0.54, 0.12 }, titleText = { 0.94, 0.76, 0.31 },
    accent = { 0.94, 0.76, 0.31 }, bright = { 1, 0.96, 0.84 }, good = { 0.25, 1, 0.25 },
    side = { 0, 0, 0, 0.25 }, divider = { 0.78, 0.54, 0.12, 0.5 },
    inset = { { 0.04, 0.03, 0.05, 0.55 }, { 0.78, 0.54, 0.12, 0.45 } },
    button = { { 0.11, 0.10, 0.14 }, { 0.24, 0.22, 0.27 }, { 0.54, 0.35, 0.05 }, { 0.94, 0.76, 0.31 } },
    corner = { texture = CODEX_MEDIA .. "Stud", size = 9 } },
  hearthwood = { head = "Interface\\AddOns\\Codex_Hearthwood\\Media\\IMFellEnglishSC.ttf",
    text = { 0.95, 0.89, 0.8 }, muted = { 0.8, 0.7, 0.54 },
    panel = { { 0.17, 0.1, 0.05 }, { 0.3, 0.19, 0.11 } }, rings = { { 0.11, 0.06, 0.02 }, { 0.54, 0.35, 0.17 } },
    title = { { 0.26, 0.16, 0.06 }, { 0.43, 0.27, 0.14 } }, titleLine = { 0.71, 0.51, 0.25 }, titleText = { 0.96, 0.83, 0.54 },
    accent = { 0.94, 0.73, 0.33 }, bright = { 1, 0.95, 0.86 }, good = { 0.35, 0.95, 0.35 },
    side = { 0.08, 0.04, 0.02, 0.3 }, divider = { 0.71, 0.51, 0.25, 0.55 },
    inset = { { 0.11, 0.06, 0.02, 0.5 }, { 0.71, 0.51, 0.25, 0.5 } },
    button = { { 0.29, 0.18, 0.09 }, { 0.48, 0.32, 0.19 }, { 0.71, 0.51, 0.25 }, { 0.96, 0.83, 0.54 } },
    corner = { texture = CODEX_MEDIA .. "Circle", size = 6, color = { 0.83, 0.64, 0.29 } } },
  classic = { head = "Fonts\\FRIZQT__.TTF",
    text = { 1, 1, 1 }, muted = { 0.71, 0.71, 0.71 },
    panel = { { 0.04, 0.04, 0.05 }, { 0.11, 0.11, 0.13 } }, rings = { { 0.42, 0.42, 0.45 }, { 0.66, 0.66, 0.69 } },
    title = { { 0.09, 0.09, 0.11 }, { 0.2, 0.2, 0.23 } }, titleLine = { 0.66, 0.66, 0.69 }, titleText = { 1, 0.82, 0 },
    accent = { 1, 0.82, 0 }, bright = { 1, 1, 1 }, good = { 0.1, 1, 0.1 },
    side = { 0, 0, 0, 0.3 }, divider = { 0.66, 0.66, 0.69, 0.4 },
    inset = { { 0, 0, 0, 0.45 }, { 0.66, 0.66, 0.69, 0.35 } },
    button = { { 0.37, 0.04, 0.04 }, { 0.65, 0.11, 0.11 }, { 0.16, 0, 0 }, { 1, 0.82, 0 } } },
  slate = { head = "Fonts\\ARIALN.TTF", body = "Fonts\\ARIALN.TTF",
    text = { 0.9, 0.91, 0.93 }, muted = { 0.64, 0.67, 0.71 },
    panel = { { 0.08, 0.09, 0.11 }, { 0.08, 0.09, 0.11 } }, rings = { { 0.18, 0.2, 0.24 } },
    title = { { 0.1, 0.12, 0.14 }, { 0.1, 0.12, 0.14 } }, titleLine = { 0.18, 0.2, 0.24 }, titleText = { 0.9, 0.91, 0.93 },
    accent = { 0.36, 0.78, 1 }, bright = { 1, 1, 1 }, good = { 0.35, 0.9, 0.5 },
    side = { 0.07, 0.08, 0.09, 1 }, divider = { 0.18, 0.2, 0.24, 1 },
    inset = { { 0.06, 0.07, 0.09, 1 }, { 0.15, 0.16, 0.2, 1 } },
    button = { { 0.14, 0.15, 0.19 }, { 0.14, 0.15, 0.19 }, { 0.23, 0.25, 0.3 }, { 0.9, 0.91, 0.93 } },
    corner = { texture = CODEX_MEDIA .. "Circle", size = 5, color = { 0.36, 0.78, 1, 0.8 } } },
}
-- Dusk and Dawn: rounded (round = the card's corner radius). Dawn's game interface is light like its windows
-- (Theme.lua, the light-theme rule: `light` = Setup's scene darkens the game's text colours); only with the Look
-- option "Game interface on dark panels" does Setup's live scene of unit frame, tooltip, bar and chat use `ink`.
local DUSK_MEDIA = "Interface\\AddOns\\Codex_Dusk\\Media\\"
PREVIEW.dusk = { head = DUSK_MEDIA .. "Inter-SemiBold.ttf", body = DUSK_MEDIA .. "Inter-Regular.ttf", round = 5,
  text = { 0.843, 0.859, 0.878 }, muted = { 0.545, 0.576, 0.616 },
  panel = { { 0.086, 0.098, 0.118 }, { 0.086, 0.098, 0.118 } }, rings = { { 0.15, 0.161, 0.18 } },
  title = { { 0.106, 0.122, 0.145 }, { 0.106, 0.122, 0.145 } }, titleLine = { 0.214, 0.224, 0.241 },
  titleText = { 0.843, 0.859, 0.878 },
  accent = { 0.498, 0.722, 0.690 }, bright = { 0.941, 0.949, 0.957 }, good = { 0.498, 0.769, 0.549 },
  side = { 1, 1, 1, 0.02 }, divider = { 0.141, 0.152, 0.171 },
  inset = { { 0.106, 0.122, 0.145, 0.92 }, { 0.141, 0.152, 0.171 } },
  button = { { 0.125, 0.145, 0.173 }, { 0.125, 0.145, 0.173 }, { 0.195, 0.213, 0.239 }, { 0.843, 0.859, 0.878 } } }
-- Obsidian and Onyx (2026-11-22): Dusk's look in near-black
PREVIEW.obsidian = { head = DUSK_MEDIA .. "Inter-SemiBold.ttf", body = DUSK_MEDIA .. "Inter-Regular.ttf", round = 5,
  text = { 0.839, 0.831, 0.812 }, muted = { 0.518, 0.506, 0.482 },
  panel = { { 0.047, 0.047, 0.051 }, { 0.047, 0.047, 0.051 } }, rings = { { 0.114, 0.114, 0.117 } },
  title = { { 0.067, 0.067, 0.075 }, { 0.067, 0.067, 0.075 } }, titleLine = { 0.180, 0.180, 0.184 },
  titleText = { 0.839, 0.831, 0.812 },
  accent = { 0.784, 0.635, 0.353 }, bright = { 0.949, 0.937, 0.910 }, good = { 0.498, 0.769, 0.549 },
  inset = { { 0.067, 0.067, 0.075, 0.94 }, { 0.104, 0.104, 0.108 } },
  side = { 1, 1, 1, 0.02 }, divider = { 0.104, 0.104, 0.108 },
  button = { { 0.090, 0.090, 0.102 }, { 0.090, 0.090, 0.102 }, { 0.163, 0.163, 0.174 }, { 0.839, 0.831, 0.812 } } }
PREVIEW.onyx = { head = DUSK_MEDIA .. "Inter-SemiBold.ttf", body = DUSK_MEDIA .. "Inter-Regular.ttf", round = 5,
  text = { 0.827, 0.843, 0.863 }, muted = { 0.486, 0.518, 0.553 },
  panel = { { 0.039, 0.043, 0.047 }, { 0.039, 0.043, 0.047 } }, rings = { { 0.106, 0.110, 0.114 } },
  title = { { 0.059, 0.067, 0.075 }, { 0.059, 0.067, 0.075 } }, titleLine = { 0.174, 0.177, 0.180 },
  titleText = { 0.827, 0.843, 0.863 },
  accent = { 0.435, 0.698, 0.659 }, bright = { 0.941, 0.949, 0.957 }, good = { 0.498, 0.769, 0.549 },
  inset = { { 0.059, 0.067, 0.075, 0.94 }, { 0.097, 0.101, 0.104 } },
  side = { 1, 1, 1, 0.02 }, divider = { 0.097, 0.101, 0.104 },
  button = { { 0.078, 0.086, 0.098 }, { 0.078, 0.086, 0.098 }, { 0.152, 0.159, 0.170 }, { 0.827, 0.843, 0.863 } } }
-- Frame style cards: a small drawn player frame in the theme for each style (Codex's own textures, not pictures)
local function StyleDisc(frame, size, color, x, y, layer, sublevel)
  local disc = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
  disc:SetSize(size, size)
  disc:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
  UI.SetColor(disc, color)
  local mask = frame:CreateMaskTexture()
  mask:SetTexture(CODEX_MEDIA .. "Circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(disc)
  disc:AddMaskTexture(mask)
  return disc
end

local function StyleBar(frame, x, y, width, height, color, fill)
  local back = frame:CreateTexture(nil, "ARTWORK", nil, 1)
  back:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
  back:SetSize(width, height)
  UI.SetColor(back, { 0.07, 0.07, 0.07, 0.9 })
  local bar = frame:CreateTexture(nil, "ARTWORK", nil, 2)
  bar:SetPoint("TOPLEFT", back, "TOPLEFT", 0, 0)
  bar:SetSize(math.max(1, math.floor(width * fill + 0.5)), height)
  UI.SetColor(bar, color)
  back.fill = bar
  local lines = ns.T.Outline(frame, 0, { 0, 0, 0, 1 }, 1, "ARTWORK", 3)
  ns.T.ColorLines(lines, { 0, 0, 0, 1 }, 1)
  for _, line in ipairs(lines) do
    line:ClearAllPoints()
  end
  lines[3]:Hide()
  lines[4]:Hide()
  lines[1]:SetPoint("TOPLEFT", back, "TOPLEFT", 0, 0)
  lines[1]:SetPoint("TOPRIGHT", back, "TOPRIGHT", 0, 0)
  lines[2]:SetPoint("BOTTOMLEFT", back, "BOTTOMLEFT", 0, 0)
  lines[2]:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", 0, 0)
  return back
end

local PREVIEW_GREEN, PREVIEW_BLUE = { 0.27, 0.84, 0.27 }, { 0.29, 0.53, 1 }

-- The previews' health colour: green, or your own class colour when health bars are class-coloured.
local previewHealth = setmetatable({}, { __mode = "k" }) -- the preview health fills, recoloured on a change
local function PreviewHealthColor()
  if not ns.ClassHealth() then
    return PREVIEW_GREEN
  end
  local ok, _, class = pcall(UnitClass, "player")
  local readable = ok and (not canaccessvalue or canaccessvalue(class)) and type(class) == "string"
  local color = readable and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if type(color) == "table" and type(color.r) == "number" then
    -- toned down on Dusk / Dawn (classTone), as the frames draw it
    return ns.ToneClass and ns.ToneClass({ color.r, color.g, color.b }, ns.InkTheme()) or { color.r, color.g, color.b }
  end
  return PREVIEW_GREEN
end

local function PreviewHealth(back)
  previewHealth[back.fill] = true
  UI.SetColor(back.fill, PreviewHealthColor())
  return back
end

function ns.RecolourPreviews()
  local color = PreviewHealthColor()
  for fill in pairs(previewHealth) do
    UI.SetColor(fill, color)
  end
end

-- Draws one style's preview inside `frame` (w x h).
local function DrawStylePreview(frame, style, w, h)
  local theme = ns.InkTheme() -- a picture of a unit frame: the game's interface, so the ink surfaces
  local line = theme.titlebar and theme.titlebar.line or theme.accent
  local font = theme.font or {}
  local function Label(text, size, color, justify)
    local label = frame:CreateFontString(nil, "OVERLAY")
    if not label:SetFont(font.body or "Fonts\\FRIZQT__.TTF", size, "") then
      label:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    end
    local x, y, r, g, b, a = UI.TextShadow(theme)
    label:SetShadowOffset(x, y)
    label:SetShadowColor(r, g, b, a)
    label:SetTextColor(UI.Unpack(color))
    label:SetJustifyH(justify or "LEFT")
    label:SetText(text)
    return label
  end
  if style == "bars" then
    local x, width = 8, w - 16
    local top = math.floor(h / 2 - 14)
    local health = PreviewHealth(StyleBar(frame, x, top, width, 14, PREVIEW_GREEN, 0.75))
    StyleBar(frame, x, top + 15, width, 5, PREVIEW_BLUE, 0.6)
    local name = Label("Tylesser", 9, theme.bright)
    name:SetPoint("LEFT", health, "LEFT", 3, 0)
    local value = Label("75%", 9, { 1, 1, 1 }, "RIGHT")
    value:SetPoint("RIGHT", health, "RIGHT", -3, 0)
    local level = Label("60", 9, theme.accent)
    level:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 1, -8)
    return
  end
  if style == "compact" then
    -- the bars grow out of the portrait: they start under it at its middle, the ring drawn over their end; the
    -- name and numbers inside them, the level badge on the ring's lower left
    local size, cx, cy = 34, 6 + 19, h / 2
    local health = PreviewHealth(StyleBar(frame, cx, cy - 13, w - cx - 6, 17, PREVIEW_GREEN, 0.75))
    StyleBar(frame, cx, cy + 3, w - cx - 6, 9, PREVIEW_BLUE, 0.6) -- the power bar, touching the health bar
    StyleDisc(frame, size + 4, line, cx, cy, "OVERLAY", 0)
    StyleDisc(frame, size + 2, { 0, 0, 0, 1 }, cx, cy, "OVERLAY", 1)
    StyleDisc(frame, size, { 0.42, 0.33, 0.27, 1 }, cx, cy, "OVERLAY", 2)
    local name = Label("Tylesser", 9, theme.bright)
    name:SetPoint("LEFT", health, "LEFT", size / 2 + 4, 0)
    local value = Label("75%", 9, { 1, 1, 1 }, "RIGHT")
    value:SetPoint("RIGHT", health, "RIGHT", -3, 0)
    -- no mana number: at 9 px it wouldn't fit its bar, so the bar alone shows it (no picture text under 9 px)
    StyleDisc(frame, 18, line, cx - 12, cy + 12, "OVERLAY", 3)
    StyleDisc(frame, 16, theme.hud and theme.hud.fill or { 0, 0, 0, 1 }, cx - 12, cy + 12, "OVERLAY", 4)
    local level = Label("60", 9, theme.accent, "CENTER")
    level:SetPoint("CENTER", frame, "TOPLEFT", cx - 12, -(cy + 12))
    return
  end
  -- a portrait in the theme's ring, the bars beside it, the level badge on its lower left
  local size, cx, cy = 34, 6 + 19, h / 2
  StyleDisc(frame, size + 4, line, cx, cy, "ARTWORK", 3)
  StyleDisc(frame, size + 2, { 0, 0, 0, 1 }, cx, cy, "ARTWORK", 4)
  StyleDisc(frame, size, { 0.42, 0.33, 0.27, 1 }, cx, cy, "ARTWORK", 5)
  local x = cx + size / 2 + (style == "panel" and 4 or 0)
  local width = w - x - 6
  if style == "panel" then
    local plate = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    plate:SetPoint("TOPLEFT", frame, "TOPLEFT", cx, -(cy - (size + 4) / 2))
    plate:SetSize(w - cx - 4, size + 4) -- as tall as the ring, on the same middle line
    UI.SetColor(plate, theme.hud and theme.hud.fill or { 0, 0, 0, 0.6 })
    local lines = ns.T.Outline(frame, 0, line, 1, "ARTWORK", 1)
    ns.T.ColorLines(lines, line, line[4])
    for _, edge in ipairs(lines) do
      edge:ClearAllPoints()
    end
    lines[1]:SetPoint("TOPLEFT", plate, "TOPLEFT", 0, 0)
    lines[1]:SetPoint("TOPRIGHT", plate, "TOPRIGHT", 0, 0)
    lines[2]:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", 0, 0)
    lines[2]:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, 0)
    lines[3]:SetPoint("TOPRIGHT", plate, "TOPRIGHT", 0, 0)
    lines[3]:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, 0)
    lines[4]:Hide()
    width = w - x - 10
  end
  local name = Label("Tylesser", 9, theme.bright)
  name:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(cy - 13))
  local health = PreviewHealth(StyleBar(frame, x, cy - 2, width, 11, PREVIEW_GREEN, 0.75))
  local value = Label("75%", 9, { 1, 1, 1 }, "CENTER")
  value:SetPoint("CENTER", health, "CENTER", 0, 0)
  StyleBar(frame, x, cy + 10, width, 4, PREVIEW_BLUE, 0.6)
  StyleDisc(frame, 18, line, cx - 12, cy + 12, "OVERLAY", 1)
  StyleDisc(frame, 16, theme.hud and theme.hud.fill or { 0, 0, 0, 1 }, cx - 12, cy + 12, "OVERLAY", 2)
  local level = Label("60", 9, theme.accent, "CENTER")
  level:SetPoint("CENTER", frame, "TOPLEFT", cx - 12, -(cy + 12))
end

-- One card per style: the preview, the style's name under it, the chosen one marked (accent line and a check).
local function StyleCards(parent, width, onPick)
  local cards, gap = {}, 8
  local w = math.floor((width - gap * (#ns.FRAME_STYLES - 1)) / #ns.FRAME_STYLES)
  local previewHeight = 58
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, previewHeight + 20)
  for index, style in ipairs(ns.FRAME_STYLES) do
    local card = CreateFrame("Button", nil, holder)
    card:SetSize(w, previewHeight + 20)
    card:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (w + gap), 0)
    local preview = UI.Ink(CreateFrame("Frame", nil, card)) -- a unit frame picture: drawn on ink (Dawn)
    preview.codexPicture = true -- sample texts (the search skips them)
    preview:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    preview:SetSize(w, previewHeight)
    UI.Inset(card, preview)
    DrawStylePreview(preview, style.key, w, previewHeight)
    local name = UI.Text(card, "body", 12, "text")
    name:SetPoint("TOP", preview, "BOTTOM", 0, -4)
    name:SetWidth(w)
    name:SetJustifyH("CENTER")
    name:SetWordWrap(false)
    name:SetText(style.name)
    card.label = name
    -- the mark: an accent line under the preview and a check in its corner
    local mark = card:CreateTexture(nil, "OVERLAY", nil, 6)
    mark:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 0, 0)
    mark:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 0, 0)
    mark:SetHeight(2)
    UI.SetColor(mark, ns.Theme().accent)
    local check = card:CreateTexture(nil, "OVERLAY", nil, 7)
    check:SetSize(16, 16)
    check:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -2, -2)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetVertexColor(UI.Unpack(ns.Theme().accent))
    card.mark, card.check, card.key = mark, check, style.key
    card:SetScript("OnClick", function()
      onPick(style.key)
    end)
    card:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(style.name, 1, 1, 1)
      GameTooltip:AddLine(style.desc, 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    cards[#cards + 1] = card
  end
  holder.cards = cards
  holder.refresh = function()
    local current = ns.FrameStyle()
    for _, card in ipairs(cards) do
      local on = card.key == current
      card.mark:SetShown(on)
      card.check:SetShown(on)
      card.label:SetTextColor(UI.Unpack(on and ns.Theme().accent or ns.Theme().text))
    end
  end
  holder.refresh()
  return holder
end
ns.StyleCards = StyleCards
ns.DrawStylePreview = DrawStylePreview

local GAME_FONT = "Fonts\\FRIZQT__.TTF"
local function PreviewText(parent, path, size, color)
  local text = parent:CreateFontString(nil, "OVERLAY")
  if not text:SetFont(path or GAME_FONT, size, "") then
    text:SetFont(GAME_FONT, size, "") -- the theme's folder isn't installed
  end
  text:SetTextColor(UI.Unpack(color))
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  return text
end

local function Fill(frame, color, layer, sublevel)
  local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
  UI.SetColor(texture, color)
  return texture
end

local function Box(frame, fillColor, lineColor)
  Fill(frame, fillColor):SetAllPoints()
  local lines = ns.T.Outline(frame, 0, lineColor, 1, "BORDER")
  ns.T.ColorLines(lines, lineColor, lineColor[4])
end

local function Icon(parent, texture, size)
  local icon = parent:CreateTexture(nil, "ARTWORK")
  icon:SetSize(size, size)
  icon:SetTexture(texture)
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  return icon
end

-- A small picture of the Codex window in another theme: title bar, sidebar, a heading, a card, a button.
local function BuildPreview(parent, id, width, height)
  local p = PREVIEW[id]
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(width, height)
  if p.round then
    -- the rounded themes: a flat fill and one hairline with rounded corners, as their windows
    UI.RoundFill(box, box, p.round, p.panel[1])
    UI.RoundLine(box, box, p.round, p.rings[1])
  else
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    UI.Gradient(fill, p.panel[1], p.panel[2])
    for index, color in ipairs(p.rings) do
      local lines = ns.T.Outline(box, (index - 1) * 2, color, 1, "BORDER")
      ns.T.ColorLines(lines, color)
    end
  end
  local inset = p.round and 3 or #p.rings * 2
  local title = CreateFrame("Frame", nil, box)
  title:SetPoint("TOPLEFT", inset, -inset)
  title:SetPoint("TOPRIGHT", -inset, -inset)
  title:SetHeight(16)
  local titleFill = title:CreateTexture(nil, "BACKGROUND")
  titleFill:SetAllPoints()
  UI.Gradient(titleFill, p.title[1], p.title[2])
  local titleLine = title:CreateTexture(nil, "BORDER")
  titleLine:SetPoint("BOTTOMLEFT")
  titleLine:SetPoint("BOTTOMRIGHT")
  titleLine:SetHeight(1)
  UI.SetColor(titleLine, p.titleLine)
  local emblem = title:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ns.T.EMBLEM)
  emblem:SetSize(11, 11)
  emblem:SetPoint("LEFT", 3, 0)
  local name = PreviewText(title, p.head, 9, p.titleText)
  name:SetPoint("LEFT", emblem, "RIGHT", 3, 0)
  name:SetText(p.upper and "TYLESSER CODEX" or "Tylesser Codex")

  local side = CreateFrame("Frame", nil, box)
  side:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -1)
  side:SetPoint("BOTTOMLEFT", inset, inset)
  side:SetWidth(24)
  Fill(side, p.side):SetAllPoints()
  local sideLine = Fill(side, p.divider, "BORDER")
  sideLine:SetPoint("TOPRIGHT")
  sideLine:SetPoint("BOTTOMRIGHT")
  sideLine:SetWidth(1)
  local y = -5
  for _, id in ipairs({ "auction", "buffs", "barfade" }) do
    local module = ns.modules[id]
    if module and module.icon then
      local icon = Icon(side, module.icon, 9)
      icon:SetPoint("TOP", 0, y)
      y = y - 13
    end
  end

  local home = PreviewText(box, p.head, 10, p.accent)
  home:SetPoint("TOPLEFT", side, "TOPRIGHT", 7, -6)
  home:SetText(p.upper and "HOME" or "Home")
  local card = CreateFrame("Frame", nil, box)
  card:SetPoint("TOPLEFT", side, "TOPRIGHT", 7, -21)
  card:SetPoint("RIGHT", -inset - 5, 0)
  card:SetHeight(18)
  Box(card, p.inset[1], p.inset[2])
  local cardIcon = Icon(card, ns.modules.buffs and ns.modules.buffs.icon or ns.T.EMBLEM, 9)
  cardIcon:SetPoint("LEFT", 4, 0)
  local cardName = PreviewText(card, p.body, 9, p.bright)
  cardName:SetPoint("LEFT", cardIcon, "RIGHT", 4, 0)
  cardName:SetText("Buffs")
  local cardState = PreviewText(card, p.body, 9, p.good)
  cardState:SetPoint("RIGHT", -4, 0)
  cardState:SetText("On")

  local button = CreateFrame("Frame", nil, box)
  button:SetSize(58, 15)
  button:SetPoint("BOTTOMRIGHT", -inset - 5, inset + 4)
  local buttonFill = button:CreateTexture(nil, "BACKGROUND")
  buttonFill:SetAllPoints()
  UI.Gradient(buttonFill, p.button[1], p.button[2])
  local buttonLines = ns.T.Outline(button, 0, p.button[3], 1, "BORDER")
  ns.T.ColorLines(buttonLines, p.button[3])
  local buttonText = PreviewText(button, p.body, 9, p.button[4])
  buttonText:SetPoint("CENTER")
  buttonText:SetText("Feedback")

  -- only textured corner pieces (Runestone's studs): a tinted dot is too small to read on a card this size
  if p.corner and not p.corner.color then
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      local piece = box:CreateTexture(nil, "OVERLAY", nil, 7)
      piece:SetTexture(p.corner.texture)
      piece:SetSize(p.corner.size, p.corner.size)
      piece:SetPoint("CENTER", box, point, 0, 0)
      if p.corner.color then
        piece:SetVertexColor(UI.Unpack(p.corner.color))
      end
    end
  end
  return box
end
-- Setup.lua shows the same cards and builds its live preview from these colours.
ns.ThemePreview = BuildPreview
ns.THEME_PREVIEW = PREVIEW

-- Opens a menu of choices under a picker. choices = { { key, name } }, current = key, pick(key).
local function PickerMenu(picker, choices, current, pick)
  local items = {}
  for _, choice in ipairs(choices) do
    items[#items + 1] = { text = choice.name, checked = choice.key == current, func = function()
      pick(choice.key)
    end }
  end
  UI.ShowMenu(picker, items)
  local menu = _G.CodexMenu
  if type(menu) == "table" and menu.ClearAllPoints then
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -2)
  end
end

ns.PickerMenu = PickerMenu

local function NeedsReload()
  ns.pendingReload = true
  ns.Fire("RELOAD_STATE")
end
ns.NeedsReload = NeedsReload

-- A row of two or three choices in one field, the chosen one lit (board R3-Setup: accent, profile scope).
-- options = { { key, name } }; get() returns the chosen key; set(key). width = nil sizes each to its text.
-- switch:Refresh() redraws it (switch.refresh is the same, for the Settings refresh list).
function ns.Segmented(parent, options, get, set, width)
  local theme = ns.Theme()
  local bar = CreateFrame("Frame", nil, parent)
  UI.Inset(parent, bar)
  bar.buttons = {}
  local x = 2
  for _, option in ipairs(options) do
    local button = CreateFrame("Button", nil, bar)
    button:SetHeight(24)
    button.key = option.key
    button.label = UI.Text(button, "body", 12, "muted")
    button.label:SetPoint("CENTER")
    button.label:SetText(option.name)
    local w = width and math.floor((width - 4) / #options) or math.max(64, button.label:GetStringWidth() + 26)
    button:SetWidth(w)
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -2)
    x = x + w
    button.fill = UI.Selection(button)
    button.ring = ns.T.Outline(button, 0, theme.accent, 1, "BORDER")
    ns.T.ColorLines(button.ring, theme.accent, 0.8)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    UI.SetColor(hover, theme.accent, 0.08)
    button:SetScript("OnClick", function(self)
      set(self.key)
      bar:Refresh()
    end)
    bar.buttons[#bar.buttons + 1] = button
  end
  bar:SetSize(x + 2, 28)
  function bar:Refresh()
    local current = get()
    local colors = ns.Theme()
    for _, button in ipairs(self.buttons) do
      local on = button.key == current
      button.fill:SetShown(on)
      for _, line in ipairs(button.ring) do
        line:SetShown(on)
      end
      button.label:SetTextColor(UI.Unpack(on and colors.accent or colors.muted))
    end
  end
  bar.refresh = bar.Refresh
  bar:Refresh()
  return bar
end

-- Look options (CodexDB.look, board R3-Polish). The look code (Theme.lua) reads them through ns.LookOption.
local LOOK_DEFAULTS = { accent = "theme", shadows = true, strips = false, inkHud = false }
function ns.LookValue(key)
  if type(ns.LookOption) == "function" then
    local ok, value = pcall(ns.LookOption, key)
    if ok and value ~= nil then
      return value
    end
  end
  local look = ns.db and ns.db.look
  local value = type(look) == "table" and look[key]
  if value == nil then
    return LOOK_DEFAULTS[key]
  end
  return value
end

function ns.SetLookValue(key, value)
  if type(ns.db.look) ~= "table" then
    ns.db.look = {}
  end
  if ns.db.look[key] == value then
    return
  end
  ns.db.look[key] = value
  local apply = ns.ApplyLook or ns.API.ApplyLook
  if type(apply) == "function" then
    local ok, err = pcall(apply)
    if not ok then
      geterrorhandler()(err)
      NeedsReload()
    end
  else
    NeedsReload()
  end
end

ns.ACCENT_CHOICES = { { key = "theme", name = "Theme" }, { key = "class", name = "Class colour" } }

-- The quest tracker's background panel (CodexDB.skins.trackerPanel: nil or true = shown, false = hidden).
function ns.TrackerPanelOn()
  return not (ns.db and ns.db.skins and ns.db.skins.trackerPanel == false)
end
ns.API.TrackerPanelOn = ns.TrackerPanelOn

-- Minimap shape (CodexDB.skins.minimapShape; nil = the theme's own). The skins folder draws it.
ns.MINIMAP_SHAPES = {
  { key = "round", name = "Round" },
  { key = "square", name = "Square" },
  { key = "header", name = "Square with header" },
}
-- each theme's own shape (board miniDefault; Skins/Minimap.lua uses the same)
ns.MINIMAP_THEME_SHAPE = { runestone = "round", classic = "header", hearthwood = "round", slate = "square",
  dusk = "round", obsidian = "round", onyx = "round" }

function ns.MinimapShapeName(key)
  for _, shape in ipairs(ns.MINIMAP_SHAPES) do
    if shape.key == key then
      return shape.name
    end
  end
  local theme = ns.db and ns.db.theme or "runestone"
  local own = ns.MINIMAP_THEME_SHAPE[theme] or "round"
  -- the skins folder knows the shape in effect (only while the theme in use is the one picked)
  local current = ns.API.MinimapShape
  if type(current) == "function" and ns.Theme().id == theme then
    local ok, shape = pcall(current)
    if ok and type(shape) == "string" then
      own = shape
    end
  end
  for _, shape in ipairs(ns.MINIMAP_SHAPES) do
    if shape.key == own then
      return ("Theme default (%s)"):format(shape.name:lower())
    end
  end
  return "Theme default"
end

function ns.SetMinimapShape(key)
  if key == "theme" then
    key = nil
  end
  if ns.db.skins.minimapShape == key then
    return
  end
  ns.db.skins.minimapShape = key
  local apply = ns.API.ApplyMinimapShape
  if type(apply) == "function" then
    local ok, result = pcall(apply)
    if not ok then
      geterrorhandler()(result)
      NeedsReload()
    elseif result == false and ns.db.skins.enabled then
      NeedsReload() -- the minimap part isn't running yet
    end
  elseif ns.db.skins.enabled then
    NeedsReload()
  end
end

-- Layout helpers shared by the sections (SettingsUI.lua uses them too) ---------------------------------------------

-- A text's height: the measured one once the game has drawn it, else an estimate from its length (font strings
-- measure 0 before their first show; the pages are laid out again after it).
local function TextHeight(text, size, width)
  local measured = text.GetStringHeight and text:GetStringHeight()
  if type(measured) == "number" and measured > 1 then
    return measured
  end
  local content = text.GetText and text:GetText() or ""
  local lines = 0
  for line in (tostring(content) .. "\n"):gmatch("(.-)\n") do
    lines = lines + math.max(1, math.ceil(#line * size * 0.5 / math.max(1, width)))
  end
  return math.max(1, lines) * (size + 4)
end
ns.UITextHeight = TextHeight

-- A wrapping text bound to a column `width` wide.
local function Wrapping(parent, size, color, width, text)
  local label = UI.Text(parent, "body", size, color)
  label:SetWidth(width)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(true)
  label:SetText(text or "")
  label.size, label.columnWidth = size, width
  return label
end
ns.UIWrapping = Wrapping

-- A check whose label wraps under itself: the label starts at the box's top, so a second line goes down,
-- never up into the row above.
local function WrapCheck(parent, text, width, size, color)
  local check = UI.Check(parent, text)
  size = size or 12
  UI.Font(check.label, "body", size, color or "text")
  check.label:ClearAllPoints()
  check.label:SetPoint("TOPLEFT", check, "TOPRIGHT", 4, -3)
  check.label:SetWidth(width - 26)
  check.label:SetJustifyH("LEFT")
  check.label:SetWordWrap(true)
  check.label.size, check.label.columnWidth = size, width - 26
  check:SetHitRectInsets(0, -(width - 30), 0, 0)
  function check.Height()
    return math.max(20, TextHeight(check.label, size, width - 26) + 6)
  end
  return check
end
ns.UIWrapCheck = WrapCheck

-- Rows laid out top to bottom whenever the section is measured: stack.Add(region, height(), x, gap);
-- stack.Layout() places them and returns the height used.
local function Stack(parent)
  local stack = { rows = {} }
  function stack.Add(region, height, x, gap)
    stack.rows[#stack.rows + 1] = { region = region, height = height, x = x or 0, gap = gap or 6 }
    return region
  end
  function stack.AddText(text, gap)
    return stack.Add(text, function()
      return TextHeight(text, text.size or 12, text.columnWidth or 200)
    end, 0, gap)
  end
  function stack.AddCheck(check, gap)
    return stack.Add(check, check.Height, -2, gap)
  end
  function stack.Layout()
    local y = 0
    for index, row in ipairs(stack.rows) do
      local shown = not row.region.IsShown or row.region:IsShown()
      if shown then
        row.region:ClearAllPoints()
        row.region:SetPoint("TOPLEFT", parent, "TOPLEFT", row.x, -y)
        y = y + row.height() + (index < #stack.rows and row.gap or 0)
      end
    end
    return y
  end
  return stack
end
ns.UIStack = Stack

-- A label and a widget in one row: the label in a column `labelWidth` wide (wrapping), the widget after it.
local function LabelRow(parent, stack, labelText, width, widget, labelWidth, gap)
  labelWidth = labelWidth or 104
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, 24)
  local label = Wrapping(row, 12, "text", labelWidth, labelText)
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -5)
  widget:SetParent(row)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", row, "TOPLEFT", labelWidth + 6, 0)
  row.label, row.widget = label, widget
  stack.Add(row, function()
    return math.max(widget:GetHeight() or 24, TextHeight(label, 12, labelWidth) + 5)
  end, 0, gap)
  return row
end
ns.UILabelRow = LabelRow

-- Starts the first-run setup again (Setup.lua).
local function RunSetup()
  if type(ns.ShowSetup) == "function" then
    ns.ShowSetup(1)
  end
end

-- Look: the theme cards -------------------------------------------------------------------------------------------

ns.lookSections = {} -- the Look page's bodies (themes, fonts, accent, effects), for the tests

local function BuildThemes(body, width, section)
  local gap = 10
  local perRow = width >= 520 and 3 or 2
  local rows = math.ceil(#ns.THEMES / perRow)
  local cardWidth = math.floor((width - gap * (perRow - 1)) / perRow)
  local cardHeight = 150
  local cardsHeight = rows * cardHeight + (rows - 1) * gap
  local cards = {}
  for index, info in ipairs(ns.THEMES) do
    local card = CreateFrame("Button", nil, body)
    card:SetSize(cardWidth, cardHeight)
    local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
    card:SetPoint("TOPLEFT", body, "TOPLEFT", column * (cardWidth + gap), -row * (cardHeight + gap))
    UI.Inset(body, card)
    local hover = card:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    UI.SetColor(hover, ns.Theme().accent, 0.07)
    card.ring = ns.T.Outline(card, 0, ns.Theme().accent, 2, "OVERLAY")
    ns.T.ColorLines(card.ring, ns.Theme().accent)
    local preview = BuildPreview(card, info.id, cardWidth - 16, 84)
    preview:SetPoint("TOP", 0, -8)
    preview.codexPicture = true
    card.name = UI.Text(card, "body", 14, "bright")
    card.name:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
    card.name:SetPoint("RIGHT", card, "RIGHT", -78, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.name:SetText(info.name)
    card.tag = UI.Text(card, "body", 11, "accent")
    card.tag:SetPoint("RIGHT", card, "RIGHT", -8, 0)
    card.tag:SetPoint("BOTTOM", card.name, "BOTTOM", 0, 0)
    card.tag:SetJustifyH("RIGHT")
    local desc = UI.Text(card, "body", 12, "muted")
    desc:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    desc:SetWidth(cardWidth - 16)
    desc:SetJustifyH("LEFT")
    desc:SetText(info.desc)
    card:SetScript("OnClick", function()
      ns.SetTheme(info.id)
      ns.RefreshSections()
    end)
    cards[info.id] = card
  end
  body.themeButtons = cards
  local themeNote = Wrapping(body, 12, "muted", width, "Only the theme you pick is loaded. It shows after a reload.")
  themeNote:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(cardsHeight + 8))
  section.Register({ refresh = function()
    local active = ns.Theme().id
    for id, card in pairs(cards) do
      local picked = ns.db.theme == id
      for _, line in ipairs(card.ring) do
        line:SetShown(picked)
      end
      card.tag:SetText(picked and (active == id and "In use" or "After reload") or "")
    end
    if ns.themeMissing then
      themeNote:SetText(("The %s theme folder (%s) is missing or switched off in the AddOns list, so a plain look is used.")
        :format(ns.themeMissing.name, ns.themeMissing.folder))
    end
  end })
  ns.lookSections.themes = body
  return { Height = function()
    return cardsHeight + 8 + TextHeight(themeNote, 12, width)
  end }
end

local function BuildFonts(body, width, section)
  local stack = Stack(body)
  local pickWidth = math.min(260, width - 110)
  body.fontPickers = {}
  for _, slot in ipairs({ { key = "head", label = "Headings" }, { key = "body", label = "Text" } }) do
    local pick = UI.Picker(body, pickWidth, 24)
    LabelRow(body, stack, slot.label, width, pick, 92, 6)
    local function Show()
      pick:SetText(ns.FontInfo(ns.db.fonts[slot.key]).name)
    end
    pick:SetScript("OnClick", function(self)
      PickerMenu(self, ns.FONTS, ns.db.fonts[slot.key] or "theme", function(key)
        if ns.db.fonts[slot.key] ~= key then
          ns.db.fonts[slot.key] = key
          NeedsReload()
        end
        Show()
      end)
    end)
    pick.refresh = Show
    section.Register(pick)
    body.fontPickers[slot.key] = pick
    Show()
  end
  stack.AddText(Wrapping(body, 12, "muted", width,
    "Used by the Codex window and the restyled game interface. Shows after a reload."), 0)
  ns.lookSections.fonts = body
  return { Height = stack.Layout }
end

local function BuildAccent(body, width, section)
  local stack = Stack(body)
  local accent = ns.Segmented(body, ns.ACCENT_CHOICES, function()
    return ns.LookValue("accent")
  end, function(key)
    ns.SetLookValue("accent", key)
  end)
  stack.Add(accent, function()
    return 28
  end, 0, 6)
  section.Register(accent)
  body.accentSwitch = accent
  stack.AddText(Wrapping(body, 12, "muted", width,
    "Class colour paints the portrait ring, frame lines, level and the chosen tab in your class's colour."), 0)
  ns.lookSections.accent = body
  return { Height = stack.Layout }
end

local function BuildEffects(body, width, section)
  local stack = Stack(body)
  body.lookChecks = {}
  local effects = {
    { key = "shadows", name = "Soft shadows", note = "A soft dark edge round panels, so they stand out on a bright world." },
    { key = "strips", name = "Decorative strips", note = "A thin line in the theme's style along the top of windows and frames." },
  }
  -- only a theme with dark panels for the game's interface (Dawn) offers them; off = the game's interface is as
  -- light as the Codex window, with its texts darkened (Theme.lua, the light-theme rule)
  if type(ns.HasInkPanel) == "function" and ns.HasInkPanel() then
    effects[#effects + 1] = { key = "inkHud", name = "Game interface on dark panels",
      note = "Chat, tooltips, bars, frames and the game's windows on dark see-through panels instead of light ones. Shows after a reload." }
  end
  for index, effect in ipairs(effects) do
    local check = WrapCheck(body, effect.name, width)
    check.refresh = function(self)
      self:SetChecked(ns.LookValue(effect.key) and true or false)
    end
    check:SetScript("OnClick", function(self)
      ns.SetLookValue(effect.key, self:GetChecked() and true or false)
    end)
    stack.AddCheck(check, 1)
    local note = Wrapping(body, 12, "muted", width - 24, effect.note)
    stack.Add(note, function()
      return TextHeight(note, 12, width - 24)
    end, 24, index < #effects and 12 or 0)
    section.Register(check)
    body.lookChecks[effect.key] = check
    check:refresh()
  end
  ns.lookSections.effects = body
  return { Height = stack.Layout }
end

ns.AddSection("look", { id = "theme", title = "Theme", order = 10, build = BuildThemes,
  keywords = { "runestone hearthwood classic slate dusk dawn" } })
ns.AddSection("look", { id = "fonts", title = "Fonts", order = 20, build = BuildFonts })
ns.AddSection("look", { id = "accent", title = "Accent colour", order = 30, build = BuildAccent,
  keywords = { "class colour" } })
ns.AddSection("look", { id = "effects", title = "Effects", order = 40, build = BuildEffects,
  keywords = { "shadows strips dark panels" } })

-- General: the Codex window itself ---------------------------------------------------------------------------------

local function BuildCodexWindow(body, width, section)
  local stack = Stack(body)
  local minimap = WrapCheck(body, "Minimap button (right-click it for a quick menu)", width)
  minimap.refresh = function(self)
    self:SetChecked(not ns.db.minimap.hide)
  end
  minimap:SetScript("OnClick", function(self)
    ns.db.minimap.hide = not self:GetChecked()
    ns.UpdateMinimapButton()
  end)
  stack.AddCheck(minimap, 10)
  section.Register(minimap)
  body.minimapCheck = minimap

  local size = UI.Stepper(body, 52)
  LabelRow(body, stack, "Window size", width, size, 104, 4)
  local function SetScale(scale)
    ns.db.scale = math.max(0.7, math.min(1.4, scale))
    if ns.window then
      ns.window:SetScale(ns.db.scale)
    end
    size.value:SetText(("%d%%"):format(math.floor(ns.db.scale * 100 + 0.5)))
    size.less:SetEnabled(ns.db.scale > 0.7 + 0.001)
    size.more:SetEnabled(ns.db.scale < 1.4 - 0.001)
  end
  size.less:SetScript("OnClick", function() SetScale(ns.db.scale - 0.05) end)
  size.more:SetScript("OnClick", function() SetScale(ns.db.scale + 0.05) end)
  size.value:SetText(("%d%%"):format(math.floor((ns.db.scale or 1) * 100 + 0.5)))
  body.sizeStepper = size
  stack.AddText(Wrapping(body, 12, "muted", width, "From 70% to 140%. Drag the title bar to move the window."), 0)

  local news = WrapCheck(body, "Show what's new after an update (once for each version)", width)
  news.refresh = function(self)
    self:SetChecked(ns.db.whatsNew ~= false)
  end
  news:SetScript("OnClick", function(self)
    ns.db.whatsNew = self:GetChecked() and true or false
  end)
  stack.AddCheck(news, 10)
  section.Register(news)
  body.whatsNewCheck = news
  local newsButton = UI.Button(body, 150, 24, "What's new")
  newsButton:SetScript("OnClick", function()
    ns.ShowWhatsNew()
  end)
  stack.Add(newsButton, function() return 24 end, 0, 6)
  return { Height = stack.Layout }
end

-- General: the game's interface scale (2026-11-22, the user's request) ---------------------------------------------
-- CodexDB.uiScale: nil = the game's own setting, untouched. 0.5-1.15 in 0.05 steps, or "pixel perfect" (768 / the
-- screen's physical height). From 0.64 up it is the game's own setting (CVars useUiScale / uiScale, the game scales
-- UIParent itself); below that the CVar sits at 0.64 and UIParent gets the scale, again after the game resets it
-- (UI_SCALE_CHANGED, DISPLAY_SIZE_CHANGED). Out of combat only: a change in a fight waits for its end.
local UI_SCALE_MIN, UI_SCALE_MAX, UI_SCALE_GAME_MIN = 0.5, 1.15, 0.64
local scaleFrame, applyingScale

function ns.PixelPerfectScale()
  local _, height = GetPhysicalScreenSize and GetPhysicalScreenSize()
  if type(height) ~= "number" or height <= 0 then
    return nil
  end
  return math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, 768 / height))
end

function ns.UIScale()
  local value = ns.db and tonumber(ns.db.uiScale)
  return value and math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, value)) or nil
end

local function SetGameCVar(name, value)
  if C_CVar and C_CVar.SetCVar then
    pcall(C_CVar.SetCVar, name, tostring(value))
  elseif SetCVar then
    pcall(SetCVar, name, tostring(value))
  end
end

function ns.ApplyUIScale()
  local value = ns.UIScale()
  if not value or applyingScale then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    scaleFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  applyingScale = true
  SetGameCVar("useUiScale", 1)
  if value >= UI_SCALE_GAME_MIN then
    SetGameCVar("uiScale", value)
  else
    SetGameCVar("uiScale", UI_SCALE_GAME_MIN)
  end
  if math.abs((UIParent:GetScale() or 1) - value) > 0.001 then
    pcall(UIParent.SetScale, UIParent, value)
  end
  applyingScale = false
end

function ns.SetUIScale(value)
  if value == nil then
    ns.db.uiScale = nil -- the game's own setting from now on (what is set stays until it is changed there)
    return
  end
  value = math.floor(value / 0.05 + 0.5) * 0.05
  ns.db.uiScale = math.max(UI_SCALE_MIN, math.min(UI_SCALE_MAX, value))
  ns.ApplyUIScale()
end

scaleFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
  pcall(scaleFrame.RegisterEvent, scaleFrame, event)
end
scaleFrame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  if ns.db then
    ns.ApplyUIScale()
  end
end)

local function BuildUIScale(body, width, section)
  local stack = Stack(body)
  local stepper = UI.Stepper(body, 52)
  LabelRow(body, stack, "Interface scale", width, stepper, 104, 4)
  local note = Wrapping(body, 12, "muted", width, "")
  local function Refresh()
    local value = ns.UIScale()
    local shown = value or (UIParent and UIParent:GetScale()) or 1
    stepper.value:SetText(("%d%%"):format(math.floor(shown * 100 + 0.5)))
    stepper.less:SetEnabled(shown > UI_SCALE_MIN + 0.001)
    stepper.more:SetEnabled(shown < UI_SCALE_MAX - 0.001)
    note:SetText(value and ("Codex keeps the game's interface at %d%%. From 50%% to 115%%; changes in a fight wait "
      .. "until it ends."):format(math.floor(value * 100 + 0.5))
      or "The game's own setting (Options > Graphics). Change it here to let Codex keep it, also below the game's 64%.")
  end
  stepper.less:SetScript("OnClick", function()
    ns.SetUIScale((ns.UIScale() or UIParent:GetScale() or 1) - 0.05)
    Refresh()
  end)
  stepper.more:SetScript("OnClick", function()
    ns.SetUIScale((ns.UIScale() or UIParent:GetScale() or 1) + 0.05)
    Refresh()
  end)
  local pixel = UI.Button(body, 130, 24, "Pixel perfect")
  local game = UI.Button(body, 130, 24, "Game's own")
  game:SetPoint("LEFT", pixel, "RIGHT", 8, 0)
  stack.Add(pixel, function() return 24 end, 0, 8)
  pixel:SetScript("OnClick", function()
    local value = ns.PixelPerfectScale()
    if value then
      ns.db.uiScale = value
      ns.ApplyUIScale()
      Refresh()
    end
  end)
  game:SetScript("OnClick", function()
    ns.SetUIScale(nil)
    Refresh()
  end)
  stack.AddText(note, 6)
  body.uiScaleStepper, body.uiScaleRefresh = stepper, Refresh
  Refresh()
  return { Height = stack.Layout, Refresh = Refresh }
end

ns.AddSection("general", { id = "uiscale", title = "Interface scale", order = 85, build = BuildUIScale,
  keywords = { "ui scale size pixel perfect" } })

ns.AddSection("general", { id = "codexwindow", title = "Codex window", order = 80, build = BuildCodexWindow,
  keywords = { "minimap button scale size" } })

-- Tooltips: what the other features add to item tooltips (the same settings as on their own sections) ---------------

local TOOLTIP_OPTIONS = {
  { module = "auction", title = "Auction house", options = {
    { key = "tooltip", name = "Auction price of the item (hold Shift for the whole stack)" },
    { key = "vendor", name = "Vendor sell price (one item; hold Shift for the whole stack)" } } },
  { module = "professions", title = "Professions", options = {
    { key = "tooltip", name = "Craft cost and profit, for items your characters can make" },
    { key = "tooltipValue", name = "Auction value, while the auction house's own price line is off" } } },
  { module = "statdelta", title = "Stat Delta", options = {
    { key = "enabled", name = "Stat changes against your gear (hold Shift)" },
    { key = "showScore", name = "Upgrade score (hold Shift)" } } },
}

-- The module's namespace: its DB() and SetOption(key, on) (each module's own page uses the same setter).
local function ModuleOptions(id)
  return ({ auction = ns.auction, professions = ns.professions, statdelta = ns.statdelta })[id]
end

local function BuildTooltipExtras(body, width, section)
  local stack = Stack(body)
  stack.AddText(Wrapping(body, 12, "muted", width, "The lines other features add to item tooltips. They are the "
    .. "same switches as in those features' own sections."), 10)
  body.extraChecks = {}
  for groupIndex, group in ipairs(TOOLTIP_OPTIONS) do
    local module = ns.modules[group.module]
    if module then
      local head = CreateFrame("Frame", nil, body)
      head:SetSize(width, 22)
      local title = UI.Text(head, "body", 13, "bright")
      title:SetPoint("LEFT", 0, 0)
      title:SetText(group.title)
      local open = UI.Button(head, 110, 20, "All its options")
      open:SetPoint("RIGHT", 0, 0)
      open:SetScript("OnClick", function()
        ns.ShowPage(group.module)
      end)
      local state = UI.Text(head, "body", 11, "muted")
      state:SetPoint("LEFT", title, "RIGHT", 10, 0)
      state:SetPoint("RIGHT", open, "LEFT", -10, 0)
      state:SetJustifyH("LEFT")
      state:SetWordWrap(false)
      stack.Add(head, function()
        return 22
      end, 0, 4)
      section.Register({ refresh = function()
        state:SetText(ns.ModuleState(group.module) == "on" and "" or "(this feature is off)")
      end })
      for index, option in ipairs(group.options) do
        local check = WrapCheck(body, option.name, width - 12)
        check.module, check.key = group.module, option.key
        check.refresh = function(self)
          local api = ModuleOptions(group.module)
          local db = api and api.DB and api.DB()
          self:SetChecked(db and db[option.key] and true or false)
        end
        check:SetScript("OnClick", function(self)
          local api = ModuleOptions(group.module)
          if api and api.SetOption then
            api.SetOption(option.key, self:GetChecked() and true or false)
          end
          ns.RefreshSections()
        end)
        stack.Add(check, check.Height, 10, index < #group.options and 2 or (groupIndex < #TOOLTIP_OPTIONS and 12 or 0))
        section.Register(check)
        body.extraChecks[group.module .. "." .. option.key] = check
        check:refresh()
      end
    end
  end
  return { Height = stack.Layout }
end

ns.AddSection("tooltips", { id = "tooltipextras", title = "Prices and stats in tooltips", order = 40,
  build = BuildTooltipExtras, keywords = { "auction price vendor sell craft cost profit stat delta score" } })

-- Profiles ---------------------------------------------------------------------------------------------------------

local function BuildProfilesSection(body, width, section)
  if type(ns.BuildProfiles) ~= "function" then
    return
  end
  ns.BuildProfiles(body, width, function(refresh)
    section.Register(refresh)
  end)
  local height = body:GetHeight()
  return { Height = function()
    return height
  end }
end

local function BuildSetupSection(body, width)
  local stack = Stack(body)
  stack.AddText(Wrapping(body, 12, "muted", width, "The short setup from your first login: theme, the parts of "
    .. "the game Codex restyles, and the features you use. It changes nothing until you finish it."), 8)
  local setup = UI.Button(body, 150, 24, "Run setup again")
  setup:SetScript("OnClick", RunSetup)
  stack.Add(setup, function()
    return 24
  end, 0, 0)
  body.setupButton = setup
  ns.setupButton = setup
  return { Height = stack.Layout }
end

ns.AddSection("profiles", { id = "profiles", title = "Profiles", order = 10, build = BuildProfilesSection,
  aliases = { "profile" }, keywords = { "export import share copy" } })
ns.AddSection("profiles", { id = "setup", title = "First-run setup", order = 20, build = BuildSetupSection,
  keywords = { "setup wizard run again" } })
