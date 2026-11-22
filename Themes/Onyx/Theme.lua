-- Onyx: cool black windows with Dusk's soft teal (Dusk, darker). Asked for by players who found Dusk not dark enough (2026-11-22; the user's preview
-- artifact "Codex Midnight Preview", variants A Obsidian and B Onyx). Built on Dusk's structure: one hairline at
-- most, rounded corners (10 px windows, 6 px buttons), the accent only for focus, the selected tab, the tracked
-- quest and proc glows, status colours turned down, Inter (shipped in Codex_Dusk/Media with its licence) for
-- headings and text. Lines are white at 6-14 % over the window, mixed and made opaque as Dusk's are.

local MEDIA = "Interface\\AddOns\\Codex_Dusk\\Media\\"
local WINDOW = { 0.039, 0.043, 0.047 } -- #0A0B0C
local RAISED = { 0.078, 0.086, 0.098 } -- #141619 buttons, slots
local CARD = { 0.059, 0.067, 0.075 } -- #0F1113 boxes inside a window
local DEEP = { 0.024, 0.027, 0.027 } -- #060707 behind bars, chat, frames
local TEXT, SOFT, MUTED = { 0.827, 0.843, 0.863 }, { 0.639, 0.667, 0.702 }, { 0.486, 0.518, 0.553 }
local BRIGHT = { 0.941, 0.949, 0.957 }
local ACCENT = { 0.435, 0.698, 0.659 } -- #6FB2A8
local HAIR = { 0.106, 0.110, 0.114 } -- white 7% over the window: the one hairline
local RULE = { 0.097, 0.101, 0.104 } -- white 6%: dividers
local LINE = { 0.174, 0.177, 0.180 } -- white 14%: portrait, aura, minimap and nameplate rings
local BUTTON_LINE = { 0.152, 0.159, 0.170 } -- white 8% over a raised button
local SLOT_LINE = { 0.174, 0.177, 0.180 } -- white 14% round an icon

TylesserCodex.RegisterTheme({
  id = "onyx", name = "Onyx",
  swatch = ACCENT,
  font = { head = MEDIA .. "Inter-SemiBold.ttf", headSize = 1, body = MEDIA .. "Inter-Regular.ttf", bodySize = 1,
    damage = MEDIA .. "Inter-SemiBold.ttf" },
  text = TEXT, muted = MUTED, accent = ACCENT, bright = BRIGHT,
  titleText = TEXT, good = { 0.498, 0.769, 0.549 }, bad = { 0.878, 0.541, 0.502 }, warn = { 0.839, 0.698, 0.431 },
  panel = { from = WINDOW, to = WINDOW, alpha = 0.96 },
  rings = { { inset = 0, color = HAIR, size = 1 } },
  round = { window = 10, button = 6, box = 8, slot = 6, bar = 6, plate = 3 },
  money = { 0.851, 0.769, 0.561 },
  titlebar = { from = { CARD[1], CARD[2], CARD[3], 0.96 }, to = { CARD[1], CARD[2], CARD[3], 0.96 }, line = LINE,
    upper = false, height = 30 },
  inset = { fill = { CARD[1], CARD[2], CARD[3], 0.94 }, line = RULE },
  side = { 1, 1, 1, 0.02 }, divider = RULE,
  button = { from = RAISED, to = RAISED, line = BUTTON_LINE, text = TEXT, hover = { 1, 1, 1, 0.05 } },
  select = { from = { 1, 1, 1, 0.05 }, to = { 1, 1, 1, 0.05 }, mark = ACCENT, text = TEXT },
  slot = { fill = DEEP, rings = { { inset = 0, color = SLOT_LINE, size = 1 } } },
  hud = { fill = { DEEP[1], DEEP[2], DEEP[3], 0.88 }, rings = { { inset = 0, color = HAIR, size = 1 } } },
  strip = { from = ACCENT, to = ACCENT, height = 2 },
  shadow = { alpha = 0.45, size = 8 },
  textShadow = { x = 1, y = -1, color = { 0, 0, 0, 0.6 } },
  sectionCaps = false,
  inkPanel = {}, -- every surface is dark already
  quality = { [0] = { 0.6, 0.62, 0.65 }, [1] = TEXT, [2] = { 0.498, 0.827, 0.416 }, [3] = { 0.435, 0.643, 0.878 },
    [4] = { 0.659, 0.639, 0.878 }, [5] = { 0.878, 0.627, 0.376 }, [6] = { 0.851, 0.769, 0.561 },
    [7] = { 0.498, 0.776, 0.878 }, [8] = { 0.498, 0.776, 0.878 } },
  -- class and reaction colours on bars a little toward the dark track, as on Dusk
  classTone = { mix = 0.25, toward = DEEP, desaturate = 0.15 },
  status = { health = { { 0.200, 0.361, 0.239 }, { 0.310, 0.561, 0.365 } },
    mana = { { 0.180, 0.294, 0.447 }, { 0.302, 0.482, 0.710 } },
    hostile = { 0.651, 0.353, 0.322 }, neutral = { 0.561, 0.541, 0.310 }, friendly = { 0.310, 0.561, 0.365 },
    tapped = { 0.45, 0.47, 0.5 } },
  dialogue = {
    npcRing = { { size = 1, color = { 0, 0, 0, 0.7 } }, { size = 1, color = LINE } },
    rule = HAIR,
    primary = { from = ACCENT, to = ACCENT, line = ACCENT, text = { 0.039, 0.043, 0.047 } },
    key = { fill = { 1, 1, 1, 0.06 }, line = LINE, text = TEXT },
    rowHover = { 1, 1, 1, 0.05 }, selLine = ACCENT,
    sub = { from = { DEEP[1], DEEP[2], DEEP[3], 0.92 }, to = { DEEP[1], DEEP[2], DEEP[3], 0.92 }, lines = { HAIR } },
    page = { from = CARD, to = RAISED, lines = { HAIR }, dark = true },
    ink = TEXT, inkMuted = SOFT, inkHead = BRIGHT,
    pageRule = HAIR, pageIcon = ACCENT, pageHover = { 1, 1, 1, 0.05 },
    pageButton = { from = RAISED, to = RAISED, line = BUTTON_LINE, text = TEXT },
  },
})
