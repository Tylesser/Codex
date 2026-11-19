-- Hearthwood: dark wood panels, brass borders and rivets, IM Fell English SC headings.

local MEDIA = "Interface\\AddOns\\Codex_Hearthwood\\Media\\"
local BRASS, BRASS_DARK, CHAR = { 0.71, 0.51, 0.25 }, { 0.54, 0.35, 0.17 }, { 0.11, 0.06, 0.02 }

TylesserCodex.RegisterTheme({
  id = "hearthwood", name = "Hearthwood",
  swatch = { 0.83, 0.64, 0.29 },
  font = { head = MEDIA .. "IMFellEnglishSC.ttf", headSize = 1.1, damage = MEDIA .. "IMFellEnglishSC.ttf" },
  text = { 0.95, 0.89, 0.8 }, muted = { 0.8, 0.7, 0.54 }, accent = { 0.94, 0.73, 0.33 }, bright = { 1, 0.95, 0.86 },
  titleText = { 0.96, 0.83, 0.54 }, good = { 0.35, 0.95, 0.35 }, bad = { 1, 0.4, 0.35 }, warn = { 1, 0.8, 0.3 },
  panel = { from = { 0.17, 0.1, 0.05 }, to = { 0.3, 0.19, 0.11 }, alpha = 0.97, tile = MEDIA .. "Wood", tileAlpha = 0.9 },
  rings = { -- thinner borders (the user found them too thick, 2026-11-17)
    { inset = 0, color = CHAR, size = 1 },
    { inset = 1, color = BRASS_DARK, size = 1 },
    { inset = 2, color = CHAR, size = 1 },
  },
  corner = { texture = MEDIA .. "Rivet", size = 16 },
  titlebar = { from = { 0.26, 0.16, 0.06 }, to = { 0.43, 0.27, 0.14 }, line = BRASS, upper = false, height = 30 },
  inset = { fill = { 0.11, 0.06, 0.02, 0.5 }, line = { 0.71, 0.51, 0.25, 0.5 } },
  side = { 0.08, 0.04, 0.02, 0.3 }, divider = { 0.71, 0.51, 0.25, 0.55 },
  button = { from = { 0.29, 0.18, 0.09 }, to = { 0.48, 0.32, 0.19 }, line = BRASS, text = { 0.96, 0.83, 0.54 },
    hover = { 0.94, 0.73, 0.33, 0.16 } },
  select = { from = { 0.94, 0.73, 0.33, 0.26 }, to = { 0.94, 0.73, 0.33, 0.04 } },
  slot = { fill = { 0.05, 0.03, 0.01, 1 }, rings = {
    { inset = 0, color = BRASS, size = 1 }, { inset = 1, color = CHAR, size = 1 } } },
  hud = { fill = { 0.17, 0.1, 0.05, 0.86 }, rings = {
    { inset = 0, color = CHAR, size = 1 }, { inset = 1, color = BRASS_DARK, size = 1 } } },
  -- Look options (board R3-Polish): brass rail with rivets; soft shadow
  strip = { from = { 0.37, 0.24, 0.09 }, to = { 0.94, 0.78, 0.47 }, height = 3, caps = true, mids = 3, capSize = 8 },
  shadow = { alpha = 0.5, size = 6 },
  -- text shadow, section labels, ink surfaces (Dusk/Dawn round 2026-11-19): a dark theme keeps a dark shadow,
  -- capitals in section labels, and is its own ink (the game's coloured text reads on every surface)
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.9 } },
  sectionCaps = true,
  inkPanel = {},
  -- Quest windows (board R4): portrait rings, main button, keycaps, subtitle bar (style B), book page (style C)
  dialogue = {
    npcRing = { { size = 1, color = CHAR }, { size = 1, color = BRASS }, { size = 2, color = { 0.11, 0.06, 0.024, 0.9 } },
      { size = 1, color = BRASS }, { size = 1, color = { 0, 0, 0, 0.5 } } },
    rule = { 0.71, 0.51, 0.25, 0.45 },
    primary = { from = { 0.38, 0.25, 0.11 }, to = { 0.66, 0.45, 0.235 }, line = { 0.94, 0.73, 0.33 }, text = { 1, 0.95, 0.86 } },
    key = { fill = { 1, 0.9, 0.745, 0.08 }, line = { 0.71, 0.51, 0.25, 0.65 }, text = { 0.95, 0.89, 0.8 } },
    rowHover = { 0.94, 0.73, 0.33, 0.18 }, selLine = { 0.94, 0.73, 0.33 },
    sub = { from = { 0.11, 0.06, 0.024, 0.95 }, to = { 0.17, 0.10, 0.05, 0.84 }, lines = { CHAR, BRASS_DARK, CHAR } },
    page = { from = { 0.82, 0.70, 0.50 }, to = { 0.92, 0.835, 0.67 }, lines = { { 0.37, 0.235, 0.09 }, { 1, 0.94, 0.82, 0.55 } } },
    ink = { 0.2, 0.125, 0.055 }, inkMuted = { 0.43, 0.31, 0.19 }, inkHead = { 0.415, 0.227, 0.063 },
    pageRule = { 0.43, 0.25, 0.078, 0.4 }, pageIcon = { 0.48, 0.29, 0.11 }, pageHover = { 0.43, 0.25, 0.078, 0.12 },
    pageButton = { from = { 0.29, 0.184, 0.086 }, to = { 0.48, 0.32, 0.19 }, line = BRASS, text = { 0.96, 0.83, 0.54 } },
  },
})
