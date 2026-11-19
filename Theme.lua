local addonName, ns = ...

-- Themes. Each look lives in its own load-on-demand folder (Codex_Runestone, Codex_Hearthwood,
-- Codex_Classic, Codex_Slate, Codex_Dusk) that is loaded only when the player picks it. The folder
-- calls TylesserCodex.RegisterTheme(def) while it loads. Changing the theme takes effect after a reload.
--
-- A theme definition (colors are { r, g, b } or { r, g, b, a }, 0-1):
-- {
--   id = "runestone", name = "Runestone", order = 1, desc = "...",
--   swatch = { r, g, b },                       -- the dot in the theme picker
--   font = { head = <path>, headSize = 1.0,     -- heading font; nil = the game's
--            body = <path> or nil, bodySize = 1.0,
--            damage = <path> or nil },          -- damage numbers and floating combat text (skins part
--                                                -- "floatingtext"); nil = the game's own font
--   text, muted, accent, bright, titleText, good, bad, warn = colors,
--   panel = { from = c, to = c, alpha = 0.97, tile = <texture> or nil, tileAlpha = 1, tileSize = 128 },
--   rings = { { inset = 0, color = c, size = 1 }, ... },  -- border lines drawn inside the frame edge
--   corner = { texture = <path>, size = 18, color = c or nil } or nil,  -- studs / rivets
--   round = { window = 10, button = 6, box = 8, slot = 6, bar = 6, plate = 3 } or nil, -- rounded corners in px
--                                                -- (Media/Round + RoundLine, nine pieces, UI.RoundFill /
--                                                -- UI.RoundLine): windows and tooltips, buttons, boxes inside a
--                                                -- window; slot / bar / plate: icons of action, bag and item slots,
--                                                -- status bars, nameplate bars, cut by a nine-sliced rounded mask
--                                                -- (Media/RoundMask<r>, UI.RoundMask). A rounded fill is flat
--                                                -- (panel.from) and only the first ring is drawn. nil = square
--   money = c or nil,                           -- Codex's money texts (ns.Money, the info bar's coins) in one
--                                                -- colour; nil = the game's gold / silver / copper colours
--   titlebar = { from = c, to = c, line = c, upper = true, height = 30 },
--   inset = { fill = c, line = c },             -- boxes inside a window
--   side = c, divider = c,                      -- sidebar fill and its edge line
--   button = { from = c, to = c, line = c, text = c, hover = c },
--   select = { from = c, to = c, mark = c or nil, text = c or nil }, -- selected row / tab; mark = a 2px line on
--                                                -- the row's left edge; text = the selected label (nil = accent)
--   slot = { rings = {...}, fill = c },         -- action / bag slots (game UI skins)
--   hud = { fill = c, rings = {...} },          -- unit frames, chat, tracker backgrounds (game UI skins)
--   strip = { from = c, to = c, height = 2, caps = true, mids = 3, capSize = 8 },  -- Look options: the thin
--                                                -- decorative line on top of windows (from = bottom, to = top);
--                                                -- caps / mids: the theme's corner piece at the ends / spread along
--   shadow = { alpha = 0.6, size = 6 },          -- Look options: the soft outer shadow
--   textShadow = { x = 1, y = -1, color = c },  -- the drop shadow of Codex's texts (a light theme: none)
--   sectionCaps = true,                         -- small section labels (UI.Section) in capitals
--   light = true or nil,                        -- light surfaces (Dawn): see the rule below
--   inkPanel = { <any keys above> },            -- dark surfaces for the game's interface, used only with the Look
--                                                -- option "Game interface on dark panels" (inkHud). A dark theme
--                                                -- leaves it empty (its own surfaces are dark already); Dawn gives
--                                                -- dark-translucent ones. ns.InkTheme() = the theme, or with the
--                                                -- option on, the theme with these keys swapped in.
--   quality = { [0] = c, ..., [8] = c } or nil, -- item quality colours (nil = the game's), ns.QualityColor
--   classTone = { mix = 0.33, toward = c, desaturate = 0.2 } or nil, -- class / reaction colours on bars toned down
--                                                -- (ns.ToneClass: unit frames, nameplates, raid cells, damage
--                                                -- meter); nil = full strength (the older themes)
--   status = { health = { bottom, top }, mana = { bottom, top }, hostile = c, neutral = c, friendly = c,
--     tapped = c } or nil,
--                                                -- bar colours of Codex's unit frames, nameplates and personal
--                                                -- bars (nil = the design's game-like greens and blues)
--   dialogue = {                                -- Quest windows module (board R4); a missing key comes from the fallback
--     npcRing = { { size = 1, color = c }, ... }, -- NPC portrait rings, inside out (round, drawn with Media/Circle)
--     rule = c,                                 -- thin lines between the parts of a window
--     primary = { from, to, line, text },       -- the main button (Accept, Continue, Complete Quest); from = bottom
--     key = { fill, line, text },               -- number keycaps beside the choices
--     rowHover = c, selLine = c,                -- the row under the mouse; the line round the picked reward
--     sub = { from, to, lines = { c, ... } },   -- style B subtitle bar; lines along its top edge, top first
--     page = { from, to, lines = { c, ... }, dark = bool }, -- style C paper; border lines outside in; dark paper
--     ink, inkMuted, inkHead = c,               -- text on the paper
--     pageRule, pageIcon, pageHover = c,        -- lines, the ornament and row hover on the paper
--     pageButton = { from, to, line, text },    -- buttons on the paper
--   },
-- }
--
-- The light-theme rule (Dawn, 2026-11-19; rewritten the same day after the user's "dawn is not updating game UI"):
-- a light theme is light everywhere: the Codex window and Codex's own windows, and the game's interface Codex
-- restyles (Codex_Skins: tooltips, chat, menus, nameplates, unit / party / raid frames, bars, minimap, tracker, quest
-- log, damage meter, loot rolls, the game's windows) and Codex's HUD (personal bars, buff icons and buttons, rings,
-- the info bar and its tooltip). They all read ns.InkTheme(), which is the theme itself. Texts the game colours for
-- dark panels (white, yellow headings, quality and class colours, chat colours) are darkened until they read 4.5:1
-- on the surface they sit on, blended over ns.WORLD, the hue kept: ns.GameColor for a colour (quality colours become
-- the theme's quality token, white the text colour, greys the muted one), ns.Readable for |cff / |cn colour codes
-- in a text, UI.GameText / S.GameText for a font string whose colours the game sets (post-hooks on its setters),
-- S.GameFonts for the game's shared window fonts, chat lines after each refresh (Skins/Chat.lua). Secret values
-- are never read: they stay as the game set them. No text shadow on light ground (textShadow). Texts drawn over the
-- world, not on a panel (nameplate names, floating combat text, timers and counts on icons) and white numbers with
-- an outline on bars keep their light colour.
-- The Look option "Game interface on dark panels" (CodexDB.look.inkHud, off by default, offered only by a theme
-- with an inkPanel, i.e. Dawn; reload) brings the old dark HUD back: ns.InkTheme() is then the theme with its
-- inkPanel keys swapped in, and nothing on those surfaces is darkened (the ink theme is not light). A frame of ours
-- marked with UI.Ink(frame) builds its children's widgets in ns.InkTheme(). Colour codes in Codex's own texts on
-- light panels go through ns.Readable (UI.Text / UI.Font).

ns.THEMES = {
  { id = "runestone", name = "Runestone", folder = "Codex_Runestone", desc = "Dark stone, gold borders and studs." },
  { id = "hearthwood", name = "Hearthwood", folder = "Codex_Hearthwood", desc = "Warm wood with brass rivets." },
  { id = "classic", name = "Classic", folder = "Codex_Classic", desc = "Close to the game's own colours." },
  { id = "slate", name = "Slate", folder = "Codex_Slate", desc = "Flat, quiet and minimal." },
  { id = "dusk", name = "Dusk", folder = "Codex_Dusk", desc = "Calm blue-grey, a soft teal, rounded corners." },
}

local registered = {}

-- Used when the chosen theme's folder is missing or disabled: plain and readable.
local FALLBACK = {
  id = "fallback", name = "Plain",
  font = {},
  text = { 0.92, 0.92, 0.92 }, muted = { 0.65, 0.65, 0.65 }, accent = { 1, 0.82, 0 }, bright = { 1, 1, 1 },
  titleText = { 1, 0.82, 0 }, good = { 0.25, 1, 0.25 }, bad = { 1, 0.3, 0.3 }, warn = { 1, 0.82, 0 },
  panel = { from = { 0.06, 0.06, 0.07 }, to = { 0.11, 0.11, 0.12 }, alpha = 0.96 },
  rings = { { inset = 0, color = { 0.35, 0.35, 0.38 }, size = 1 } },
  titlebar = { from = { 0.12, 0.12, 0.14 }, to = { 0.18, 0.18, 0.2 }, line = { 0.35, 0.35, 0.38 }, height = 28 },
  inset = { fill = { 0, 0, 0, 0.35 }, line = { 0.3, 0.3, 0.33, 1 } },
  side = { 0, 0, 0, 0.25 }, divider = { 0.3, 0.3, 0.33, 1 },
  button = { from = { 0.14, 0.14, 0.16 }, to = { 0.22, 0.22, 0.25 }, line = { 0.4, 0.4, 0.44 }, text = { 1, 0.82, 0 },
    hover = { 1, 1, 1, 0.1 } },
  select = { from = { 1, 0.82, 0, 0.2 }, to = { 1, 0.82, 0, 0.03 } },
  slot = { rings = { { inset = 0, color = { 0.4, 0.4, 0.44 }, size = 1 } }, fill = { 0, 0, 0, 1 } },
  hud = { fill = { 0, 0, 0, 0.6 }, rings = { { inset = 0, color = { 0.35, 0.35, 0.38 }, size = 1 } } },
  strip = { from = { 1, 0.82, 0 }, to = { 1, 0.82, 0 }, height = 2 },
  shadow = { alpha = 0.6, size = 6 },
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.9 } },
  sectionCaps = true,
  inkPanel = {},
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0 } }, { size = 1, color = { 0.35, 0.35, 0.38 } } },
    rule = { 0.35, 0.35, 0.38, 0.5 },
    primary = { from = { 0.3, 0.22, 0 }, to = { 0.5, 0.38, 0 }, line = { 1, 0.82, 0 }, text = { 1, 1, 1 } },
    key = { fill = { 1, 1, 1, 0.07 }, line = { 0.5, 0.5, 0.55, 0.6 }, text = { 1, 1, 1 } },
    rowHover = { 1, 0.82, 0, 0.14 }, selLine = { 1, 0.82, 0 },
    sub = { from = { 0, 0, 0, 0.92 }, to = { 0.05, 0.05, 0.06, 0.8 }, lines = { { 0.35, 0.35, 0.38 } } },
    page = { from = { 0.85, 0.75, 0.58 }, to = { 0.93, 0.86, 0.71 }, lines = { { 0.42, 0.35, 0.235 } } },
    ink = { 0.165, 0.10, 0.03 }, inkMuted = { 0.37, 0.29, 0.18 }, inkHead = { 0.24, 0.12, 0 },
    pageRule = { 0.31, 0.20, 0.063, 0.35 }, pageIcon = { 0.42, 0.29, 0.10 }, pageHover = { 0.31, 0.20, 0.063, 0.1 },
    pageButton = { from = { 0.14, 0.14, 0.16 }, to = { 0.22, 0.22, 0.25 }, line = { 0.4, 0.4, 0.44 }, text = { 1, 0.82, 0 } },
  },
}
ns.FALLBACK_THEME = FALLBACK

function ns.API.RegisterTheme(def)
  assert(type(def) == "table" and def.id, "Codex: a theme needs an id")
  registered[def.id] = def
end

function ns.ThemeInfo(id)
  for _, info in ipairs(ns.THEMES) do
    if info.id == id then
      return info
    end
  end
end

-- Loads the chosen theme's folder (once, at ADDON_LOADED) and makes it the active theme.
-- Fonts the player can pick for headings and text (Settings > Fonts). "theme" keeps the theme's own choice.
-- Cinzel and IM Fell English SC have capitals only (small caps): fine for headings, hard to read as text.
ns.FONTS = {
  { key = "theme", name = "Theme's own" },
  { key = "friz", name = "Friz Quadrata (the game's)", path = "Fonts\\FRIZQT__.TTF" },
  { key = "arialn", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
  { key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
  { key = "skurri", name = "Skurri", path = "Fonts\\SKURRI.TTF" },
  { key = "cinzel", name = "Cinzel (capitals)", path = "Interface\\AddOns\\Codex\\Media\\Cinzel-Bold.ttf" },
  { key = "imfell", name = "IM Fell English SC (capitals)",
    path = "Interface\\AddOns\\Codex_Hearthwood\\Media\\IMFellEnglishSC.ttf" },
  { key = "inter", name = "Inter", path = "Interface\\AddOns\\Codex_Dusk\\Media\\Inter-Regular.ttf" },
  { key = "intersemi", name = "Inter Semibold", path = "Interface\\AddOns\\Codex_Dusk\\Media\\Inter-SemiBold.ttf" },
}

function ns.FontInfo(key)
  for _, info in ipairs(ns.FONTS) do
    if info.key == key then
      return info
    end
  end
  return ns.FONTS[1]
end

-- The player's font choices over the theme's (a copy of the font table: the theme's own stays as it was).
local function ApplyFontChoices(theme)
  local choice = ns.db and ns.db.fonts or {}
  local font = {}
  for key, value in pairs(theme.font or {}) do
    font[key] = value
  end
  local head, body = ns.FontInfo(choice.head), ns.FontInfo(choice.body)
  if head.path then
    font.head, font.headSize = head.path, 1
  end
  if body.path then
    font.body, font.bodySize = body.path, 1
  end
  theme.font = font
end

-- Look options (board R3-Polish): CodexDB.look = { accent = "theme" | "class", shadows = bool, strips = bool }.
-- Shadows and strips switch live (Widgets.lua, ns.ApplyLook); the accent is read when things are built, so a
-- change of accent shows after a reload.
-- inkHud: "Game interface on dark panels" (only offered by a theme with an inkPanel, Dawn; reload). On by default
-- since 2026-11-20: the light see-through HUD panels turned into a grey haze over the dark game world (the user's
-- screenshot), so Dawn is light Codex windows over the game's interface on dark panels unless the player turns it off.
ns.LOOK_DEFAULTS = { accent = "theme", shadows = true, strips = false, inkHud = true }

function ns.LookOption(key)
  local look = ns.db and ns.db.look
  local value
  if type(look) == "table" then
    value = look[key]
  end
  if value == nil then
    return ns.LOOK_DEFAULTS[key]
  end
  return value
end
ns.API.LookOption = ns.LookOption

-- The player's class colour as { r, g, b }, or nil while the game doesn't know it yet.
local function ClassColor()
  local _, class = UnitClass("player")
  if type(class) ~= "string" then
    return nil
  end
  local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
  if not color and type(RAID_CLASS_COLORS) == "table" then
    color = RAID_CLASS_COLORS[class]
  end
  if type(color) == "table" and type(color.r) == "number" then
    return { color.r, color.g, color.b }
  end
end
ns.PlayerClassColor = ClassColor

local pendingClass = false

local function Copy(source)
  local copy = {}
  for key, value in pairs(source or {}) do
    copy[key] = value
  end
  return copy
end

-- `rgb` with the alpha of `color` (an accent-coloured line keeps how see-through it was).
local function Recolor(color, rgb)
  return { rgb[1], rgb[2], rgb[3], type(color) == "table" and color[4] or nil }
end

-- The brightest of a list of rings: the "line" (the others are dark edges and gaps).
local function LineIndex(rings)
  local best, bestLight
  for index, ring in ipairs(rings or {}) do
    local c = ring.color
    local light = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
    if not best or light > bestLight then
      best, bestLight = index, light
    end
  end
  return best
end

-- Class accent: a copy of the theme whose accent tokens are the player's class colour. Replaced: accent,
-- titlebar.line (the line of title bars, portrait rings, aura and radio rings, nameplate lines), the line of
-- hud.rings (unit frame / chat / tracker frame line), select.from / select.to (selected rows and tabs, alphas
-- kept), button.hover, corner.color (Slate's dot; textured studs and rivets keep their own colours) and strip
-- (light top, class colour, dark bottom; a flat strip stays flat). Panels' own rings, button lines, text and
-- titleText keep the theme's colours. The theme table itself is never changed.
function ns.AccentTheme(theme)
  pendingClass = false
  if ns.LookOption("accent") ~= "class" then
    return theme
  end
  local cls = ClassColor()
  if not cls then
    pendingClass = true
    return theme
  end
  local copy = Copy(theme)
  copy.accentSource = "class"
  copy.accent = Recolor(theme.accent, cls)
  if theme.titlebar then
    copy.titlebar = Copy(theme.titlebar)
    copy.titlebar.line = Recolor(theme.titlebar.line, cls)
  end
  if theme.hud and theme.hud.rings then
    copy.hud = Copy(theme.hud)
    local rings, line = {}, LineIndex(theme.hud.rings)
    for index, ring in ipairs(theme.hud.rings) do
      rings[index] = index == line and { inset = ring.inset, size = ring.size, color = Recolor(ring.color, cls) } or ring
    end
    copy.hud.rings = rings
  end
  if theme.select then
    copy.select = { from = Recolor(theme.select.from, cls), to = Recolor(theme.select.to, cls) }
  end
  if theme.button and theme.button.hover then
    copy.button = Copy(theme.button)
    copy.button.hover = Recolor(theme.button.hover, cls)
  end
  if theme.corner and theme.corner.color then
    copy.corner = Copy(theme.corner)
    copy.corner.color = Recolor(theme.corner.color, cls)
  end
  if theme.strip then
    local strip = Copy(theme.strip)
    local flat = theme.strip.from and theme.strip.to and theme.strip.from[1] == theme.strip.to[1]
      and theme.strip.from[2] == theme.strip.to[2] and theme.strip.from[3] == theme.strip.to[3]
    if flat then
      strip.from, strip.to = Recolor(nil, cls), Recolor(nil, cls)
    else
      strip.from = { cls[1] * 0.5, cls[2] * 0.5, cls[3] * 0.5 }
      strip.to = { cls[1] + (1 - cls[1]) * 0.55, cls[2] + (1 - cls[2]) * 0.55, cls[3] + (1 - cls[3]) * 0.55 }
    end
    copy.strip = strip
  end
  return copy
end

function ns.LoadTheme()
  local info = ns.ThemeInfo(ns.db.theme) or ns.THEMES[1]
  if not registered[info.id] then
    ns.LoadAddOn(info.folder)
  end
  local theme = registered[info.id]
  if not theme then
    ns.themeMissing = info
    theme = FALLBACK
  end
  -- fill anything a theme left out from the fallback, so widgets never meet a nil
  for key, value in pairs(FALLBACK) do
    if theme[key] == nil then
      theme[key] = value
    end
  end
  theme.font = theme.font or {}
  ApplyFontChoices(theme)
  ns.baseTheme = theme
  ns.theme = ns.AccentTheme(theme)
  ns.inkTheme = nil
  ns.lookApplied = { accent = ns.LookOption("accent"), inkHud = ns.LookOption("inkHud") == true }
  ns.ApplyFloatingTextFont()
  return ns.theme
end

-- Floating text (skins part "floatingtext"): damage numbers over enemies and Blizzard's floating combat text
-- ("XP: 276", heals, reputation) in the theme's font.damage. Decided at Codex's ADDON_LOADED from the saved
-- settings, because the game reads DAMAGE_TEXT_FONT when the world loads (before Codex_Skins, which loads at
-- PLAYER_LOGIN): a change shows after a reload. DAMAGE_TEXT_FONT is a global the game asks addons to set: the one
-- global Codex writes besides its SavedVariables and TylesserCodex. Nothing is touched while the restyle or the
-- part is off, or when the theme has no damage font (Classic, Slate: the game's own).
local COMBAT_TEXT_FONTS = { "CombatTextFont", "CombatTextFontOutline" }

function ns.DamageFont()
  local font = ns.Theme().font
  return type(font) == "table" and type(font.damage) == "string" and font.damage or nil
end

function ns.FloatingTextWanted()
  local skins = ns.db and ns.db.skins
  return type(skins) == "table" and skins.enabled == true and type(ns.SkinPartWanted) == "function"
    and ns.SkinPartWanted("floatingtext") and ns.DamageFont() ~= nil or false
end

-- The combat text font objects in `path`, each keeping its own size and flags.
local function FontCombatText(path)
  for _, name in ipairs(COMBAT_TEXT_FONTS) do
    local object = _G[name]
    if type(object) == "table" and type(object.GetFont) == "function" and type(object.SetFont) == "function" then
      pcall(function()
        local _, size, flags = object:GetFont()
        if type(size) ~= "number" or size <= 0 then
          size = 25
        end
        object:SetFont(path, size, type(flags) == "string" and flags or "")
      end)
    end
  end
end

local combatTextWatch
function ns.ApplyFloatingTextFont()
  if not ns.FloatingTextWanted() then
    return false
  end
  local path = ns.DamageFont()
  DAMAGE_TEXT_FONT = path
  FontCombatText(path)
  -- Blizzard_CombatText is load-on-demand: its strings are made when it loads, so the fonts go on again then
  if not combatTextWatch then
    combatTextWatch = CreateFrame("Frame")
    combatTextWatch:RegisterEvent("ADDON_LOADED")
    combatTextWatch:SetScript("OnEvent", function(self, _, name)
      if name == "Blizzard_CombatText" then
        self:UnregisterEvent("ADDON_LOADED")
        FontCombatText(path)
      end
    end)
  end
  return true
end

function ns.Theme()
  if pendingClass and ClassColor() then
    -- class accent wanted but the class wasn't known yet when the theme loaded: try again
    pendingClass = false
    if ns.baseTheme then
      ns.theme = ns.AccentTheme(ns.baseTheme)
      ns.inkTheme = nil
    end
  end
  return ns.theme or FALLBACK
end
ns.API.Theme = ns.Theme

-- Does the theme have ink surfaces to offer (Dawn)? Only then Settings shows the "Game interface on dark panels"
-- option.
function ns.HasInkPanel(theme)
  theme = theme or ns.baseTheme
  local swap = type(theme) == "table" and theme.inkPanel
  return type(swap) == "table" and next(swap) ~= nil or false
end

-- The surfaces of the game's interface (the light-theme rule at the top). By default they are the theme itself, so
-- on Dawn the game's interface is as light as the Codex window and its texts are darkened (ns.GameColor,
-- ns.Readable, UI.GameText). With the Look option "Game interface on dark panels" (CodexDB.look.inkHud, read
-- when the theme loads: a change shows after a reload) a theme with an inkPanel gets the old dark HUD: the theme
-- with its inkPanel keys swapped in. Every dark theme has an empty inkPanel, so for them this is always the very
-- same table as ns.Theme(). The class accent applies to the ink copy too.
function ns.InkTheme()
  local theme = ns.Theme()
  local base = ns.baseTheme
  local swap = base and base.inkPanel
  if type(swap) ~= "table" or next(swap) == nil then
    return theme
  end
  if not (ns.lookApplied and ns.lookApplied.inkHud) then
    return theme
  end
  if not ns.inkTheme or ns.inkTheme.inkOf ~= theme then
    local merged = Copy(base)
    for key, value in pairs(swap) do
      merged[key] = value
    end
    merged.inkPanel, merged.light, merged.isInk = {}, nil, true
    local class = pendingClass
    merged = ns.AccentTheme(merged)
    pendingClass = class or pendingClass
    merged.inkOf = theme
    ns.inkTheme = merged
  end
  return ns.inkTheme
end
ns.API.InkTheme = ns.InkTheme

-- Contrast (WCAG 2) -----------------------------------------------------------------------------------------------

local function Channel(value)
  value = math.max(0, math.min(1, value or 0))
  if value <= 0.03928 then
    return value / 12.92
  end
  return ((value + 0.055) / 1.055) ^ 2.4
end

-- Relative luminance of { r, g, b }.
function ns.Luminance(color)
  return 0.2126 * Channel(color[1]) + 0.7152 * Channel(color[2]) + 0.0722 * Channel(color[3])
end

-- Contrast ratio of two colours (1 to 21); alpha is ignored (the colours as drawn on an opaque ground).
function ns.Contrast(a, b)
  local la, lb = ns.Luminance(a), ns.Luminance(b)
  if la < lb then
    la, lb = lb, la
  end
  return (la + 0.05) / (lb + 0.05)
end

-- The world behind see-through panels, assumed mid-grey for contrast checks (the user's rule for Dawn, 2026-11-19).
ns.WORLD = { 0.431, 0.451, 0.471 } -- #6E7378

-- `color` drawn at its alpha (or `alpha`) over `under` (default ns.WORLD): the colour the eye sees.
function ns.Blend(color, alpha, under)
  under = under or ns.WORLD
  local a = alpha or color[4] or 1
  return { color[1] * a + under[1] * (1 - a), color[2] * a + under[2] * (1 - a), color[3] * a + under[3] * (1 - a) }
end

-- The ground texts sit on in a theme: its window fill at its alpha over the assumed world. kind "hud" = the HUD
-- boxes (chat, tracker, unit frame panels: hud.fill), "slot" = slots and bar tracks (slot.fill); default the window.
function ns.Ground(theme, kind)
  theme = theme or ns.Theme()
  if kind == "hud" or kind == "slot" then
    local look = theme[kind]
    local fill = type(look) == "table" and look.fill
    if type(fill) == "table" and type(fill[1]) == "number" then
      return ns.Blend(fill, fill[4] or 1)
    end
  end
  local panel = theme.panel or FALLBACK.panel
  return ns.Blend(panel.from or panel.to or { 0, 0, 0 }, panel.alpha or 1)
end
ns.API.Ground = ns.Ground

-- `color`, or a darker (on light ground) / lighter (on dark ground) shade of it that reads 4.5:1 on `ground`.
-- The hue is kept, so a quality green stays green.
function ns.ReadableColor(color, ground, ratio)
  ratio = ratio or 4.5
  ground = ground or ns.Ground()
  if type(color) ~= "table" or ns.Contrast(color, ground) >= ratio then
    return color
  end
  local darken = ns.Luminance(ground) > 0.4
  local r, g, b = color[1], color[2], color[3]
  for _ = 1, 40 do
    if darken then
      r, g, b = r * 0.92, g * 0.92, b * 0.92
    else
      r, g, b = r + (1 - r) * 0.1, g + (1 - g) * 0.1, b + (1 - b) * 0.1
    end
    if ns.Contrast({ r, g, b }, ground) >= ratio then
      break
    end
  end
  return { r, g, b, color[4] }
end

function ns.Hex(color)
  return ("%02x%02x%02x"):format(math.floor(math.max(0, math.min(1, color[1])) * 255 + 0.5),
    math.floor(math.max(0, math.min(1, color[2])) * 255 + 0.5), math.floor(math.max(0, math.min(1, color[3])) * 255 + 0.5))
end

-- An item quality's colour in a theme: the theme's own (quality token), else the game's; on a light theme made
-- readable on its ground. Returns { r, g, b } or nil for an unknown quality.
function ns.QualityColor(quality, theme)
  theme = theme or ns.Theme()
  if type(quality) ~= "number" then
    return nil
  end
  local color = type(theme.quality) == "table" and theme.quality[quality] or nil
  if not color then
    local game = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[quality]
    if type(game) == "table" and type(game.r) == "number" then
      color = { game.r, game.g, game.b }
    end
  end
  if color and theme.light then
    color = ns.ReadableColor(color, ns.Ground(theme))
  end
  return color
end

-- Class and reaction colours on bars, toned down (theme token classTone = { mix, toward, desaturate }: Dusk, Dawn;
-- the user's "nameplate colors are too bright", 2026-11-19): the colour moved `desaturate` of the way to its own
-- grey, then mixed `mix` toward `toward` (the theme's dark bar track). The hue stays, so classes are still told
-- apart. `color` is { r, g, b } or { r =, g =, b = }; returns { r, g, b }, or the colour as { r, g, b } unchanged
-- when the theme has no token (the four older themes) or a value can't be read.
function ns.ToneClass(color, theme)
  theme = theme or ns.InkTheme()
  if type(color) ~= "table" then
    return color
  end
  local r, g, b = color[1] or color.r, color[2] or color.g, color[3] or color.b
  if not (ns.Plain(r) and ns.Plain(g) and ns.Plain(b)) or type(r) ~= "number" or type(g) ~= "number"
    or type(b) ~= "number" then
    return color
  end
  local tone = type(theme) == "table" and theme.classTone
  if type(tone) ~= "table" then
    return { r, g, b }
  end
  local grey = r * 0.3 + g * 0.59 + b * 0.11
  local d = tone.desaturate or 0
  r, g, b = r + (grey - r) * d, g + (grey - g) * d, b + (grey - b) * d
  local m, to = tone.mix or 0, tone.toward or { 0, 0, 0 }
  return { r + (to[1] - r) * m, g + (to[2] - g) * m, b + (to[3] - b) * m }
end
ns.API.ToneClass = ns.ToneClass

-- The money colour as "rrggbb" (the ink surfaces' money token: money texts are drawn on tooltips and the info bar
-- as well as on windows; ns.Readable swaps it for the light theme's own money colour on light panels), or nil when
-- the theme keeps the game's coin colours.
function ns.MoneyHex()
  local theme = ns.InkTheme and ns.InkTheme() or ns.Theme()
  local color = theme and theme.money
  return type(color) == "table" and ns.Hex(color) or nil
end

-- Secret values (Forever): a value Codex may not compare, measure, concat or do maths with. Everything that reads
-- a colour or a text back from the game checks this first and leaves a secret one exactly as it is.
function ns.Plain(value)
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

-- Game colours on light ground (the light-theme rule): the game colours its texts for dark panels (white, yellow
-- headings, quality and class colours). On a light theme `color` ({ r, g, b[, a] }) comes back as a shade that reads
-- 4.5:1 on `ground` (default the theme's window ground, ns.Ground), the hue kept: a colour that already reads stays;
-- an item quality colour (ITEM_QUALITY_COLORS) becomes the theme's own (quality token); white and light greys
-- become the theme's text colour, mid greys (disabled, poor items, finished objectives) its muted colour; anything
-- else is darkened (ns.ReadableColor). On a dark theme, or for a value that isn't a plain colour, `color` itself.
local gameColorCache = setmetatable({}, { __mode = "k" }) -- [theme] = { [colour .. ground] = colour }

local function QualityOf(r, g, b)
  if type(ITEM_QUALITY_COLORS) ~= "table" then
    return nil
  end
  for quality = 0, 8 do
    local c = ITEM_QUALITY_COLORS[quality]
    if type(c) == "table" and type(c.r) == "number" and math.abs(c.r - r) < 0.006 and math.abs(c.g - g) < 0.006
      and math.abs(c.b - b) < 0.006 then
      return quality
    end
  end
end

local function GroundKey(ground)
  return ("%.3f,%.3f,%.3f"):format(ground[1], ground[2], ground[3])
end

function ns.GameColor(color, theme, ground)
  theme = theme or ns.InkTheme()
  if type(color) ~= "table" or type(theme) ~= "table" or not theme.light then
    return color
  end
  local r, g, b = color[1], color[2], color[3]
  if not (ns.Plain(r) and ns.Plain(g) and ns.Plain(b)) or type(r) ~= "number" or type(g) ~= "number"
    or type(b) ~= "number" then
    return color
  end
  ground = ground or ns.Ground(theme)
  local cache = gameColorCache[theme]
  if not cache then
    cache = {}
    gameColorCache[theme] = cache
  end
  local key = ("%.3f,%.3f,%.3f|"):format(r, g, b) .. GroundKey(ground)
  local out = cache[key]
  if not out then
    local rgb = { r, g, b }
    if ns.Contrast(rgb, ground) >= 4.5 then
      out = rgb
    else
      local quality = QualityOf(r, g, b)
      if quality and quality ~= 1 then
        out = ns.QualityColor(quality, theme)
      elseif math.max(r, g, b) - math.min(r, g, b) < 0.06 then
        out = ns.Luminance(rgb) >= 0.4 and theme.text or theme.muted
      end
      out = ns.ReadableColor(out or rgb, ground)
    end
    out = { out[1], out[2], out[3] }
    cache[key] = out
  end
  return { out[1], out[2], out[3], color[4] }
end
ns.API.GameColor = ns.GameColor

-- Colour codes in a text, made readable on a light theme's ground (`ground`, default the window's): |cAARRGGBB
-- codes through ns.GameColor, |cnIQ<n>: (item quality names in links) turned into the theme's quality colour,
-- other named codes (|cnGREEN_FONT_COLOR:) into a readable shade of that global colour. On a dark theme, for a
-- secret or non-string value, the text comes back as it was (never compared or measured).
local readableCache = setmetatable({}, { __mode = "k" }) -- [theme] = { [ground key] = { [rrggbb] = rrggbb } }
function ns.Readable(text, theme, ground)
  theme = theme or ns.Theme()
  if not theme.light or type(text) ~= "string" then
    return text
  end
  if not ns.Plain(text) then
    return text
  end
  if not text:find("|c", 1, true) then
    return text
  end
  ground = ground or ns.Ground(theme)
  local byGround = readableCache[theme]
  if not byGround then
    byGround = {}
    readableCache[theme] = byGround
  end
  local groundKey = GroundKey(ground)
  local cache = byGround[groundKey]
  if not cache then
    cache = {}
    byGround[groundKey] = cache
  end
  local inkMoney = ns.MoneyHex()
  if inkMoney and type(theme.money) == "table" and not cache[inkMoney] then
    -- the money colour of the ink surfaces -> this theme's own
    cache[inkMoney] = ns.Hex(ns.ReadableColor(theme.money, ground))
  end
  text = text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
    local key = (r .. g .. b):lower()
    if not cache[key] then
      local color = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 }
      cache[key] = ns.Hex(ns.GameColor(color, theme, ground))
    end
    return "|c" .. a .. cache[key]
  end)
  text = text:gsub("|cn([%a_][%w_]*):", function(name)
    local quality = name:match("^IQ(%d+)$")
    if quality then
      local color = ns.QualityColor(tonumber(quality), theme)
      return color and ("|cff" .. ns.Hex(ns.ReadableColor(color, ground))) or nil
    end
    local object = _G[name]
    if type(object) == "table" and type(object.GetRGB) == "function" then
      local ok, r, g, b = pcall(object.GetRGB, object)
      if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return "|cff" .. ns.Hex(ns.GameColor({ r, g, b }, theme, ground))
      end
    end
    return nil
  end)
  return text
end
ns.API.Readable = ns.Readable

-- Picking a theme saves it; it shows after a reload.
function ns.SetTheme(id)
  if ns.db.theme ~= id then
    ns.db.theme = id
    ns.pendingReload = true
    ns.Fire("RELOAD_STATE")
  end
end
