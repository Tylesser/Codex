-- Slate: flat and minimal. Dark grey, one thin border, a light blue accent, the game's narrow font.

local MEDIA = "Interface\\AddOns\\Codex_Slate\\Media\\"
local LINE, BLUE = { 0.18, 0.2, 0.24 }, { 0.36, 0.78, 1 }

TylesserCodex.RegisterTheme({
  id = "slate", name = "Slate",
  swatch = BLUE,
  font = { head = "Fonts\\ARIALN.TTF", headSize = 1.15, body = "Fonts\\ARIALN.TTF", bodySize = 1.1 },
  text = { 0.9, 0.91, 0.93 }, muted = { 0.64, 0.67, 0.71 }, accent = BLUE, bright = { 1, 1, 1 },
  titleText = { 0.9, 0.91, 0.93 }, good = { 0.35, 0.9, 0.5 }, bad = { 1, 0.42, 0.42 }, warn = { 1, 0.78, 0.35 },
  panel = { from = { 0.08, 0.09, 0.11 }, to = { 0.08, 0.09, 0.11 }, alpha = 0.95 },
  rings = { { inset = 0, color = LINE, size = 1 } },
  corner = { texture = MEDIA .. "Dot", size = 10, color = { 0.36, 0.78, 1, 0.8 } },
  titlebar = { from = { 0.1, 0.12, 0.14 }, to = { 0.1, 0.12, 0.14 }, line = LINE, upper = false, height = 28 },
  inset = { fill = { 0.06, 0.07, 0.09, 1 }, line = { 0.15, 0.16, 0.2, 1 } },
  side = { 0.07, 0.08, 0.09, 1 }, divider = LINE,
  button = { from = { 0.14, 0.15, 0.19 }, to = { 0.14, 0.15, 0.19 }, line = { 0.23, 0.25, 0.3 }, text = { 0.9, 0.91, 0.93 },
    hover = { 0.36, 0.78, 1, 0.12 } },
  select = { from = { 0.36, 0.78, 1, 0.16 }, to = { 0.36, 0.78, 1, 0.04 } },
  slot = { fill = { 0, 0, 0, 1 }, rings = {
    { inset = 0, color = LINE, size = 1 } } }, -- thinner borders (the user found them too thick, 2026-11-17)
  hud = { fill = { 0.06, 0.07, 0.09, 0.8 }, rings = { { inset = 0, color = LINE, size = 1 } } },
  -- Look options (board R3-Polish): a 2 px accent line; a subtle shadow
  strip = { from = BLUE, to = BLUE, height = 2 },
  shadow = { alpha = 0.35, size = 5 },
  -- text shadow, section labels, ink surfaces (Dusk/Dawn round 2026-11-19): a dark theme keeps a dark shadow,
  -- capitals in section labels, and is its own ink (the game's coloured text reads on every surface)
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.9 } },
  sectionCaps = true,
  inkPanel = {},
  -- Quest windows (board R4): portrait rings, main button, keycaps, subtitle bar (style B), book page (style C:
  -- dark paper in this theme)
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0 } }, { size = 1, color = { 0.23, 0.25, 0.3 } } },
    rule = LINE,
    primary = { from = BLUE, to = BLUE, line = BLUE, text = { 0.043, 0.086, 0.125 } },
    key = { fill = { 1, 1, 1, 0.05 }, line = { 0.23, 0.25, 0.3 }, text = { 0.9, 0.91, 0.93 } },
    rowHover = { 0.36, 0.78, 1, 0.1 }, selLine = BLUE,
    sub = { from = { 0.063, 0.07, 0.086, 0.9 }, to = { 0.063, 0.07, 0.086, 0.9 }, lines = { LINE } },
    page = { from = { 0.09, 0.10, 0.125 }, to = { 0.114, 0.125, 0.153 }, lines = { LINE }, dark = true },
    ink = { 0.9, 0.91, 0.93 }, inkMuted = { 0.64, 0.67, 0.71 }, inkHead = { 1, 1, 1 },
    pageRule = LINE, pageIcon = BLUE, pageHover = { 0.36, 0.78, 1, 0.1 },
    pageButton = { from = { 0.14, 0.15, 0.19 }, to = { 0.14, 0.15, 0.19 }, line = { 0.23, 0.25, 0.3 }, text = { 0.9, 0.91, 0.93 } },
  },
})
