-- Runestone: dark stone, double gold borders, hex studs and Cinzel headings (the shared Tylesser look).
-- Uses the stud and font that ship in Codex's own Media folder.

local CODEX = "Interface\\AddOns\\Codex\\Media\\"
local GOLD, GOLD_DEEP, BRONZE, EDGE = { 0.94, 0.76, 0.31 }, { 0.78, 0.54, 0.12 }, { 0.54, 0.35, 0.05 }, { 0.29, 0.18, 0.02 }

TylesserCodex.RegisterTheme({
  id = "runestone", name = "Runestone",
  swatch = GOLD,
  font = { head = CODEX .. "Cinzel-Bold.ttf", headSize = 0.95, damage = CODEX .. "Cinzel-Bold.ttf" },
  text = { 0.91, 0.87, 0.78 }, muted = { 0.72, 0.65, 0.49 }, accent = GOLD, bright = { 1, 0.96, 0.84 },
  titleText = GOLD, good = { 0.25, 1, 0.25 }, bad = { 1, 0.35, 0.35 }, warn = { 1, 0.82, 0 },
  panel = { from = { 0.09, 0.07, 0.11 }, to = { 0.15, 0.13, 0.18 }, alpha = 0.97 },
  rings = { -- thinner borders (the user found them too thick, 2026-11-17)
    { inset = 0, color = GOLD_DEEP, size = 1 },
    { inset = 1, color = EDGE, size = 1 },
  },
  corner = { texture = CODEX .. "Stud", size = 18 },
  titlebar = { from = { 0.14, 0.08, 0.04 }, to = { 0.29, 0.16, 0.06 }, line = GOLD_DEEP, upper = true, height = 30 },
  inset = { fill = { 0.04, 0.03, 0.05, 0.55 }, line = { 0.78, 0.54, 0.12, 0.45 } },
  side = { 0, 0, 0, 0.25 }, divider = { 0.78, 0.54, 0.12, 0.5 },
  button = { from = { 0.11, 0.10, 0.14 }, to = { 0.24, 0.22, 0.27 }, line = BRONZE, text = GOLD,
    hover = { 0.94, 0.76, 0.31, 0.14 } },
  select = { from = { 0.94, 0.76, 0.31, 0.22 }, to = { 0.94, 0.76, 0.31, 0.03 } },
  slot = { fill = { 0, 0, 0, 1 }, rings = {
    { inset = 0, color = GOLD_DEEP, size = 1 }, { inset = 1, color = { 0, 0, 0 }, size = 1 } } },
  hud = { fill = { 0.09, 0.07, 0.11, 0.86 }, rings = {
    { inset = 0, color = GOLD_DEEP, size = 1 }, { inset = 1, color = { 0, 0, 0, 0.5 }, size = 1 } } },
  -- Look options (board R3-Polish): gold line with a stud at each end; soft shadow
  strip = { from = { 0.42, 0.26, 0.04 }, to = { 0.96, 0.82, 0.42 }, height = 2, caps = true, mids = 0, capSize = 8 },
  shadow = { alpha = 0.55, size = 6 },
  -- text shadow, section labels, ink surfaces (Dusk/Dawn round 2026-11-19): a dark theme keeps a dark shadow,
  -- capitals in section labels, and is its own ink (the game's coloured text reads on every surface)
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.9 } },
  sectionCaps = true,
  inkPanel = {},
  -- Quest windows (board R4): portrait rings, main button, keycaps, subtitle bar (style B), book page (style C)
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0 } }, { size = 1, color = GOLD_DEEP },
      { size = 2, color = { 0.05, 0.035, 0.063, 0.9 } }, { size = 1, color = GOLD_DEEP }, { size = 1, color = { 0, 0, 0, 0.55 } } },
    rule = { 0.78, 0.54, 0.12, 0.42 },
    primary = { from = { 0.29, 0.16, 0.06 }, to = { 0.48, 0.29, 0.08 }, line = GOLD, text = { 1, 0.96, 0.84 } },
    key = { fill = { 1, 0.925, 0.784, 0.07 }, line = { 0.78, 0.54, 0.12, 0.6 }, text = { 0.91, 0.87, 0.78 } },
    rowHover = { 0.94, 0.76, 0.31, 0.16 }, selLine = GOLD,
    sub = { from = { 0.05, 0.035, 0.063, 0.95 }, to = { 0.09, 0.07, 0.11, 0.84 }, lines = { GOLD_DEEP, { 0, 0, 0, 0.5 } } },
    page = { from = { 0.82, 0.73, 0.55 }, to = { 0.90, 0.84, 0.70 }, lines = { BRONZE, { 1, 0.956, 0.84, 0.6 } } },
    ink = { 0.18, 0.125, 0.063 }, inkMuted = { 0.42, 0.33, 0.20 }, inkHead = { 0.48, 0.29, 0.05 },
    pageRule = { 0.48, 0.29, 0.05, 0.38 }, pageIcon = BRONZE, pageHover = { 0.48, 0.29, 0.05, 0.12 },
    pageButton = { from = { 0.48, 0.29, 0.05, 0.08 }, to = { 0.48, 0.29, 0.05, 0.08 }, line = { 0.48, 0.29, 0.05, 0.55 },
      text = { 0.48, 0.29, 0.05 } },
  },
})
