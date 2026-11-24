-- Bronze: the calm theme (2026-11-24, the user's request after comparing Codex with FlareUI: "it looks more elegant
-- and easier on the eye"). The rules it follows, so later changes keep it calm:
--   * close to the game's own materials: warm dark brown and bronze, the colours of the game's frames and parchment;
--   * one thin bronze line per box, square corners, no studs, double rings, bevels or caps on the strip;
--   * see-through panels (the world shows through the HUD);
--   * the game's own font (Friz Quadrata) at its size, never in capitals; order comes from colour and spacing:
--     gold for titles and what is selected, cream for text, a warm grey for everything secondary;
--   * colour is rare, so the gold accent and the status colours stand out where they are used.
-- No media of its own: the game's font, Codex's shared textures.

local FRIZ = "Fonts\\FRIZQT__.TTF"
local WINDOW = { 0.098, 0.082, 0.067 } -- #191511 windows
local RAISED = { 0.157, 0.129, 0.098 } -- #282119 buttons
local CARD = { 0.071, 0.059, 0.047 } -- #12100C boxes inside a window
local DEEP = { 0.051, 0.043, 0.035 } -- #0D0B09 behind bars, chat, frames
local TEXT, MUTED = { 0.910, 0.875, 0.800 }, { 0.659, 0.612, 0.533 } -- #E8DFCC cream, #A89C88 warm grey
local SOFT = { 0.780, 0.737, 0.659 }
local BRIGHT = { 0.961, 0.933, 0.863 }
local GOLD = { 0.886, 0.714, 0.333 } -- #E2B655 titles, selected, focus
local BRONZE = { 0.416, 0.329, 0.204 } -- #6A5434 the one line
local RULE = { 0.290, 0.235, 0.161 } -- #4A3C29 dividers, a step quieter
local SLOT_LINE = { 0.337, 0.271, 0.176 } -- #56452D round an icon

TylesserCodex.RegisterTheme({
  id = "bronze", name = "Bronze",
  swatch = GOLD,
  font = { head = FRIZ, headSize = 1, damage = nil },
  text = TEXT, muted = MUTED, accent = GOLD, bright = BRIGHT,
  titleText = GOLD, good = { 0.471, 0.800, 0.443 }, bad = { 0.949, 0.537, 0.486 }, warn = { 0.922, 0.769, 0.388 },
  panel = { from = WINDOW, to = WINDOW, alpha = 0.92 },
  rings = { { inset = 0, color = BRONZE, size = 1 } },
  money = { 0.906, 0.792, 0.525 },
  titlebar = { from = { CARD[1], CARD[2], CARD[3], 0.9 }, to = { CARD[1], CARD[2], CARD[3], 0.9 }, line = RULE,
    upper = false, height = 30 },
  inset = { fill = { CARD[1], CARD[2], CARD[3], 0.7 }, line = RULE },
  side = { 0, 0, 0, 0.18 }, divider = RULE,
  button = { from = RAISED, to = RAISED, line = BRONZE, text = GOLD, hover = { 0.886, 0.714, 0.333, 0.08 } },
  select = { from = { 0.886, 0.714, 0.333, 0.12 }, to = { 0.886, 0.714, 0.333, 0.04 }, mark = GOLD, text = GOLD },
  slot = { fill = DEEP, rings = { { inset = 0, color = SLOT_LINE, size = 1 } } },
  hud = { fill = { DEEP[1], DEEP[2], DEEP[3], 0.72 }, rings = { { inset = 0, color = RULE, size = 1 } } },
  strip = { from = BRONZE, to = BRONZE, height = 1 },
  shadow = { alpha = 0.45, size = 6 },
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.75 } },
  sectionCaps = false,
  inkPanel = {}, -- every surface is dark already
  -- class and reaction colours on bars a little calmer
  classTone = { mix = 0.18, toward = DEEP, desaturate = 0.1 },
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0, 0.7 } }, { size = 1, color = BRONZE } },
    rule = RULE,
    primary = { from = { 0.255, 0.200, 0.122 }, to = { 0.255, 0.200, 0.122 }, line = GOLD, text = BRIGHT },
    key = { fill = { 1, 0.925, 0.784, 0.05 }, line = BRONZE, text = TEXT },
    rowHover = { 0.886, 0.714, 0.333, 0.08 }, selLine = GOLD,
    sub = { from = { DEEP[1], DEEP[2], DEEP[3], 0.9 }, to = { DEEP[1], DEEP[2], DEEP[3], 0.8 }, lines = { BRONZE } },
    -- the book page: a dull, greyed parchment (#A89B82 to #B0A389), far below Runestone's bright cream (the user,
    -- 2026-11-24: "this color is too shiny", then "more duller, and change the text colours to it"). Every text on
    -- it, the quest level, "Ready", marks and item qualities included, is darkened to read 4.5:1 there.
    page = { from = { 0.66, 0.61, 0.51 }, to = { 0.69, 0.64, 0.54 }, lines = { BRONZE } },
    ink = { 0.12, 0.09, 0.06 }, inkMuted = { 0.21, 0.17, 0.12 }, inkHead = { 0.25, 0.14, 0.03 },
    pageRule = { 0.25, 0.18, 0.08, 0.45 }, pageIcon = { 0.29, 0.21, 0.11 }, pageHover = { 0.25, 0.18, 0.08, 0.1 },
    pageButton = { from = { 0.25, 0.18, 0.08, 0.1 }, to = { 0.25, 0.18, 0.08, 0.1 }, line = { 0.25, 0.18, 0.08, 0.6 },
      text = { 0.25, 0.14, 0.03 } },
    inkDiff = { red = { 0.42, 0.05, 0.04 }, orange = { 0.36, 0.13, 0.02 }, yellow = { 0.28, 0.185, 0 },
      green = { 0.06, 0.24, 0.04 }, grey = { 0.22, 0.20, 0.17 } },
    inkMark = { gold = { 0.28, 0.18, 0 }, blue = { 0.03, 0.20, 0.37 }, grey = { 0.22, 0.20, 0.17 } },
    inkQuality = { [0] = { 0.22, 0.20, 0.17 }, [2] = { 0.04, 0.23, 0.02 }, [3] = { 0, 0.18, 0.42 },
      [4] = { 0.28, 0.08, 0.42 }, [5] = { 0.36, 0.14, 0 } },
  },
})
