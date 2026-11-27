-- Classic: close to the game's own colours. Near-black panels, silver borders, red buttons with gold
-- text, and the game's own fonts (Friz Quadrata), so it needs no media of its own.

local SILVER, SILVER_DARK, GOLD = { 0.66, 0.66, 0.69 }, { 0.23, 0.23, 0.25 }, { 1, 0.82, 0 }

TylesserCodex.RegisterTheme({
  id = "classic", name = "Classic",
  swatch = { 0.65, 0.11, 0.11 },
  font = { head = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"), headSize = 1.05 },
  text = { 1, 1, 1 }, muted = { 0.71, 0.71, 0.71 }, accent = GOLD, bright = { 1, 1, 1 },
  titleText = GOLD, good = { 0.1, 1, 0.1 }, bad = { 1, 0.13, 0.13 }, warn = GOLD,
  panel = { from = { 0.04, 0.04, 0.05 }, to = { 0.11, 0.11, 0.13 }, alpha = 0.95 },
  rings = { -- thinner borders (the user found them too thick, 2026-11-17)
    { inset = 0, color = SILVER, size = 1 },
    { inset = 1, color = SILVER_DARK, size = 1 },
  },
  titlebar = { from = { 0.09, 0.09, 0.11 }, to = { 0.2, 0.2, 0.23 }, line = SILVER, upper = false, height = 28 },
  inset = { fill = { 0, 0, 0, 0.45 }, line = { 0.66, 0.66, 0.69, 0.35 } },
  side = { 0, 0, 0, 0.3 }, divider = { 0.66, 0.66, 0.69, 0.4 },
  button = { from = { 0.37, 0.04, 0.04 }, to = { 0.65, 0.11, 0.11 }, line = { 0.16, 0, 0 }, text = GOLD,
    hover = { 1, 0.6, 0.4, 0.15 } },
  select = { from = { 1, 0.82, 0, 0.2 }, to = { 1, 0.82, 0, 0.03 } },
  slot = { fill = { 0, 0, 0, 1 }, rings = {
    { inset = 0, color = { 0.55, 0.55, 0.58 }, size = 1 }, { inset = 1, color = { 0, 0, 0 }, size = 1 } } },
  hud = { fill = { 0, 0, 0, 0.6 }, rings = {
    { inset = 0, color = { 0.55, 0.55, 0.58 }, size = 1 }, { inset = 1, color = { 0, 0, 0, 0.6 }, size = 1 } } },
  -- Look options (board R3-Polish): the game's bronze trim; soft shadow
  strip = { from = { 0.35, 0.24, 0.09 }, to = { 0.88, 0.72, 0.47 }, height = 2 },
  shadow = { alpha = 0.7, size = 6 },
  -- text shadow, section labels, ink surfaces (Dusk/Dawn round 2026-11-19): a dark theme keeps a dark shadow,
  -- capitals in section labels, and is its own ink (the game's coloured text reads on every surface)
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.9 } },
  sectionCaps = true,
  inkPanel = {},
  -- Quest windows (board R4): portrait rings, main button, keycaps, subtitle bar (style B), book page (style C)
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0 } }, { size = 1, color = SILVER }, { size = 2, color = { 0, 0, 0, 0.85 } },
      { size = 1, color = SILVER }, { size = 1, color = { 0, 0, 0, 0.55 } } },
    rule = { 0.66, 0.66, 0.69, 0.32 },
    primary = { from = { 0.43, 0.047, 0.047 }, to = { 0.77, 0.125, 0.125 }, line = GOLD, text = GOLD },
    key = { fill = { 1, 1, 1, 0.07 }, line = { 0.66, 0.66, 0.69, 0.6 }, text = { 1, 1, 1 } },
    rowHover = { 1, 0.82, 0, 0.14 }, selLine = GOLD,
    sub = { from = { 0, 0, 0, 0.92 }, to = { 0.04, 0.04, 0.047, 0.78 }, lines = { SILVER, SILVER_DARK } },
    page = { from = { 0.85, 0.75, 0.58 }, to = { 0.93, 0.86, 0.71 }, lines = { { 0.42, 0.35, 0.235 }, { 1, 0.956, 0.84, 0.55 } } },
    ink = { 0.165, 0.10, 0.03 }, inkMuted = { 0.37, 0.29, 0.18 }, inkHead = { 0.24, 0.12, 0 },
    pageRule = { 0.31, 0.20, 0.063, 0.35 }, pageIcon = { 0.42, 0.29, 0.10 }, pageHover = { 0.31, 0.20, 0.063, 0.1 },
    pageButton = { from = { 0.37, 0.04, 0.04 }, to = { 0.65, 0.11, 0.11 }, line = { 0.165, 0, 0 }, text = GOLD },
  },
})
