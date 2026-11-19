-- Dusk: the calm look from the "Codex: a calmer look" boards (2026-11-19). Blue-grey windows a little see-through,
-- one hairline at most, rounded corners (10 px windows, 6 px buttons), a soft teal accent only for focus, the
-- selected tab, the tracked quest and proc glows (everything else stays grey), status colours turned down,
-- softened item qualities, and Inter (SIL OFL 1.1, shipped in Media with its licence) for headings (semibold, normal
-- case) and text. No studs, double rings or bevels.
--
-- The boards draw their lines as white at 6-14% over the window. Several parts of the restyle draw lines at full
-- opacity (rings, nameplate and minimap edges), so the lines here are those mixes, opaque: the same look on the dark
-- ground, and never a bright white line where a part ignores the alpha.

local MEDIA = "Interface\\AddOns\\Codex_Dusk\\Media\\"
local WINDOW = { 0.086, 0.098, 0.118 } -- #16191E
local RAISED = { 0.125, 0.145, 0.173 } -- #20252C buttons, slots
local CARD = { 0.106, 0.122, 0.145 } -- #1B1F25 boxes inside a window
local DEEP = { 0.071, 0.082, 0.102 } -- #12151A behind bars, chat, frames
local TEXT, SOFT, MUTED = { 0.843, 0.859, 0.878 }, { 0.655, 0.682, 0.718 }, { 0.545, 0.576, 0.616 } -- D7DBE0 A7AEB7 8B939D
local BRIGHT = { 0.941, 0.949, 0.957 } -- #F0F2F4
local TEAL = { 0.498, 0.722, 0.690 } -- #7FB8B0
local HAIR = { 0.15, 0.161, 0.18 } -- white 7% over the window: the one hairline
local RULE = { 0.141, 0.152, 0.171 } -- white 6%: dividers
local LINE = { 0.214, 0.224, 0.241 } -- white 14%: portrait, aura, minimap and nameplate rings
local BUTTON_LINE = { 0.195, 0.213, 0.239 } -- white 8% over a raised button
local SLOT_LINE = { 0.201, 0.211, 0.228 } -- white 14% round an icon

TylesserCodex.RegisterTheme({
  id = "dusk", name = "Dusk",
  swatch = TEAL,
  font = { head = MEDIA .. "Inter-SemiBold.ttf", headSize = 1, body = MEDIA .. "Inter-Regular.ttf", bodySize = 1,
    damage = MEDIA .. "Inter-SemiBold.ttf" },
  text = TEXT, muted = MUTED, accent = TEAL, bright = BRIGHT,
  titleText = TEXT, good = { 0.498, 0.769, 0.549 }, bad = { 0.878, 0.541, 0.502 }, warn = { 0.839, 0.698, 0.431 },
  panel = { from = WINDOW, to = WINDOW, alpha = 0.94 },
  rings = { { inset = 0, color = HAIR, size = 1 } },
  -- corners: windows 10, buttons and slots 6, boxes 8, status bars 6, nameplate bars 3 (the boards)
  round = { window = 10, button = 6, box = 8, slot = 6, bar = 6, plate = 3 },
  money = { 0.851, 0.769, 0.561 }, -- #D9C48F: money only
  titlebar = { from = { CARD[1], CARD[2], CARD[3], 0.94 }, to = { CARD[1], CARD[2], CARD[3], 0.94 }, line = LINE,
    upper = false, height = 30 },
  inset = { fill = { CARD[1], CARD[2], CARD[3], 0.92 }, line = RULE },
  side = { 1, 1, 1, 0.02 }, divider = RULE,
  button = { from = RAISED, to = RAISED, line = BUTTON_LINE, text = TEXT, hover = { 1, 1, 1, 0.05 } },
  select = { from = { 1, 1, 1, 0.05 }, to = { 1, 1, 1, 0.05 }, mark = TEAL, text = TEXT },
  slot = { fill = DEEP, rings = { { inset = 0, color = SLOT_LINE, size = 1 } } },
  hud = { fill = { DEEP[1], DEEP[2], DEEP[3], 0.85 }, rings = { { inset = 0, color = HAIR, size = 1 } } },
  -- Look options: a flat 2 px teal line; a soft, wide shadow (the boards' 0 16px 40px at 35%)
  strip = { from = TEAL, to = TEAL, height = 2 },
  shadow = { alpha = 0.35, size = 8 },
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.55 } },
  sectionCaps = false,
  inkPanel = {}, -- every surface is dark already
  quality = { [0] = { 0.6, 0.62, 0.65 }, [1] = TEXT, [2] = { 0.498, 0.827, 0.416 }, [3] = { 0.435, 0.643, 0.878 },
    [4] = { 0.659, 0.639, 0.878 }, [5] = { 0.878, 0.627, 0.376 }, [6] = { 0.851, 0.769, 0.561 },
    [7] = { 0.498, 0.776, 0.878 }, [8] = { 0.498, 0.776, 0.878 } },
  -- class and reaction colours on bars a third of the way to the dark track and a little greyer (the user's
  -- "too bright", 2026-11-19): the paladin pink, the mage blue stay recognisable but calm
  classTone = { mix = 0.33, toward = DEEP, desaturate = 0.2 },
  status = { health = { { 0.25, 0.45, 0.29 }, { 0.31, 0.561, 0.365 } },
    mana = { { 0.24, 0.385, 0.57 }, { 0.302, 0.482, 0.71 } },
    hostile = { 0.651, 0.353, 0.322 }, neutral = { 0.561, 0.541, 0.31 }, friendly = { 0.31, 0.561, 0.365 },
    tapped = { 0.45, 0.47, 0.5 } },
  -- Quest windows (board R4) in the calm look: a teal main button, quiet keycaps, a dark page for style C
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0, 0.6 } }, { size = 1, color = LINE } },
    rule = HAIR,
    primary = { from = TEAL, to = TEAL, line = TEAL, text = { 0.067, 0.075, 0.09 } },
    key = { fill = { 1, 1, 1, 0.06 }, line = { 0.196, 0.206, 0.224 }, text = TEXT },
    rowHover = { 1, 1, 1, 0.05 }, selLine = TEAL,
    sub = { from = { DEEP[1], DEEP[2], DEEP[3], 0.9 }, to = { DEEP[1], DEEP[2], DEEP[3], 0.9 }, lines = { HAIR } },
    page = { from = CARD, to = RAISED, lines = { HAIR }, dark = true },
    ink = TEXT, inkMuted = SOFT, inkHead = BRIGHT,
    pageRule = HAIR, pageIcon = TEAL, pageHover = { 1, 1, 1, 0.05 },
    pageButton = { from = RAISED, to = RAISED, line = BUTTON_LINE, text = TEXT },
  },
})
