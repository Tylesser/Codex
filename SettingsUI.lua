local addonName, ns = ...

-- The game's own interface: one section per interface part (ns.SKIN_PARTS) on the page of the part of the game it
-- belongs to (ns.PART_SECTIONS; the action bars' look on Action bars, the chat on Chat, ...), and the
-- switch for the whole restyle in General. A part's section: its switch in the header, what changes in plain
-- words, the part's own options and a small "before > after" picture beside them. Storage is unchanged: CodexDB.skins.enabled, CodexDB.skins.parts[id]
-- (ns.SkinPartWanted), the unit text formats, frame style, icon spacing and minimap shape.
--
-- The pictures: on the left ("Game default") the element drawn with the game's own atlases and files, each atlas
-- checked with C_Texture.GetAtlasInfo (files with GetFileIDFromPath where the client has it); what the client
-- lacks is drawn as a plain grey stand-in, never as copied art. On the right ("Codex") the same element drawn
-- with the current theme's tokens and Codex's own textures. The pictures are textures only: nothing secure.

local UI = ns.UI
local T = ns.T

local GAME_FONT, NUMBER_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local GREY = { 0.32, 0.32, 0.34, 1 }
local MIN_TEXT = 9 -- no picture text smaller: the game's fonts blur under 9 px
ns.UI_MIN_TEXT = MIN_TEXT
local GOLD = { 1, 0.82, 0 }
local ICONS = { "Interface\\Icons\\Spell_Holy_HolyBolt", "Interface\\Icons\\Spell_Holy_FlashHeal",
  "Interface\\Icons\\Spell_Holy_SealOfMight", "Interface\\Icons\\Spell_Holy_DevotionAura",
  "Interface\\Icons\\Spell_Shadow_ShadowWordPain" }
local CLASS = { { 0.96, 0.55, 0.73 }, { 0.25, 0.78, 0.92 }, { 0.78, 0.61, 0.43 }, { 0, 0.44, 0.87 } }

-- Parts shown as an option inside another part's card instead of a card of their own.
ns.UI_OPTION_PARTS = { barpanels = "actionbars", roundicons = "auras" }

-- What each part changes, in plain words (from the skin files' own notes).
ns.UI_PART_TEXT = {
  actionbars = "Every action button gets the theme's slot: a dark square with thin theme lines, the icon trimmed "
    .. "and clean white numbers. The gryphons and the bar art go.",
  unitframes = "Codex draws its own player, target, target of target, pet and focus frames: a round portrait in "
    .. "the theme's ring with a level badge and slim health and power bars.",
  partyframes = "Party members get the same frames a size smaller, stacked on the left with their buffs under "
    .. "each, faded while out of range.",
  raidframes = "Raid frames (and raid-style party frames) get flat class-coloured bars on a dark slot with a thin "
    .. "theme line. The game still handles colours, auras and range.",
  nameplates = "Health bars become flat with a soft shade and a thin theme line, the target gets an accent ring, "
    .. "the level a small dark disc, and the name sits centred above.",
  auras = "Your buffs get a thin theme ring and white timers; debuffs keep their dispel-colour border. The game "
    .. "still places and sorts them.",
  cooldowns = "The cooldown manager's icons get the theme's slot and white countdowns; its tracked bars become "
    .. "flat fills on a dark strip.",
  minimap = "The map gets the theme's ring and the zone name a small plate. Pick a square shape below if you "
    .. "prefer one.",
  chat = "The chat box gets the theme's panel, the tabs the accent colour and the edit box a slim bar under the "
    .. "window. Chat text and its colours stay as they are.",
  tracker = "The quest tracker sits on a soft panel under an accent heading. Quest titles keep their difficulty "
    .. "colours; objectives turn light grey.",
  damagemeter = "The game's damage meter gets the theme's box, an accent title and flat class-coloured bars.",
  questlog = "The world map and quest log lose the parchment: the theme's panel and title bar and light, readable "
    .. "quest text. Quest levels in front of titles stay.",
  tooltips = "Tooltips get the theme's panel and thin border. Item quality still shows in the name's colour.",
  menus = "Dropdown and right-click menus get the theme's panel, the hover in the theme's select colour and "
    .. "ticks in the accent.",
  lootroll = "Need, greed and pass rolls get the theme's panel and buttons, the item's quality on a thin ring round "
    .. "its icon and the time left as a slim bar.",
  questpins = "On continent, world and flight maps every quest in your log gets a pin. The game shows quest "
    .. "pins only on a zone's own map. On the flight map the pins only show their tooltip: clicks go to the "
    .. "flight points.",
  windows = "The character window, spellbook, bags, mail, merchants and the other game windows get the theme's "
    .. "panel, title bar, buttons and tabs.",
  floatingtext = "Damage numbers over enemies and the game's floating combat text use the theme's font. Takes "
    .. "effect after a reload.",
}

-- Drawing helpers ------------------------------------------------------------------------------------------------

local function Theme()
  return ns.Theme()
end

-- The "Codex" side of each picture shows a part of the game's interface, drawn as the game shows it: ns.InkTheme()
-- (the light-theme rule in Theme.lua: Dawn's light surfaces with darkened game colours, or its dark ink surfaces
-- with "Game interface on dark panels" on; the theme itself for a dark one).
local function GameTheme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

-- A game colour on the Codex side (quest titles, objectives, levels): on a light theme the readable shade the
-- game's interface shows it in (ns.GameColor, the light-theme rule); else the colour itself.
local function GameColored(color, kind)
  local theme = GameTheme()
  if type(color) == "table" and theme.light and ns.GameColor then
    return ns.GameColor(color, theme, ns.Ground(theme, kind))
  end
  return color
end

local function Tex(parent, layer, sublevel)
  return parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
end

local function At(region, parent, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
  region:SetSize(w, h)
  return region
end

local function Solid(parent, color, layer, sublevel)
  local texture = Tex(parent, layer, sublevel)
  texture:SetColorTexture(UI.Unpack(color))
  return texture
end

-- A frame one level above its parent (what the game does anyway; set here so the order is never left to chance).
local function Child(parent, template)
  local frame = CreateFrame("Frame", nil, parent, template)
  frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 1)
  return frame
end

-- Texts and marks go on a frame of their own well above everything in their box (child boxes and bars are drawn
-- over their parent's own regions, so a text on the parent would disappear under them). Made once per frame.
local function Ink(parent)
  if not parent.codexInk then
    local ink = CreateFrame("Frame", nil, parent)
    ink:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    ink:SetSize(parent:GetWidth() or 1, parent:GetHeight() or 1)
    ink:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    ink.isInk = true
    parent.codexInk = ink
  end
  return parent.codexInk
end

local function Text(parent, font, size, color, text, justify)
  size = math.max(MIN_TEXT, size)
  local label = Ink(parent):CreateFontString(nil, "OVERLAY")
  if not label:SetFont(font or GAME_FONT, size, "") then
    label:SetFont(GAME_FONT, size, "")
  end
  label:SetShadowOffset(1, -1)
  label:SetShadowColor(0, 0, 0, 1)
  label:SetTextColor(UI.Unpack(color or { 1, 1, 1 }))
  label:SetJustifyH(justify or "LEFT")
  label:SetWordWrap(false)
  label:SetText(text or "")
  return label
end

-- The theme's body font (Codex side).
local function CodexText(parent, size, color, text, justify)
  local label = UI.Text(Ink(parent), "body", math.max(MIN_TEXT, size), color)
  label:SetJustifyH(justify or "LEFT")
  label:SetWordWrap(false)
  label:SetText(text or "")
  return label
end

-- The theme's heading font (Codex side), above its box like every text.
local function HeadText(parent, size, color, text)
  local label = UI.Text(Ink(parent), "head", math.max(MIN_TEXT + 1, size), color) -- head fonts scale a little down
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetText(text or "")
  return label
end

local function Lines(frame, inset, color, layer, sublevel)
  local lines = T.Outline(frame, inset or 0, color, 1, layer or "BORDER", sublevel)
  T.ColorLines(lines, color, color[4])
  return lines
end

local function Disc(parent, size, color, layer, sublevel)
  local disc = Tex(parent, layer, sublevel)
  disc:SetTexture(CIRCLE)
  disc:SetSize(size, size)
  disc:SetVertexColor(UI.Unpack(color))
  return disc
end

-- The game's own art ---------------------------------------------------------------------------------------------

-- [atlas or file] = true when the client has it, false when a stand-in was drawn (for the tests and the report).
ns.UI_PREVIEW_ART = ns.UI_PREVIEW_ART or {}

local function AtlasOK(name)
  if not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then
    return false
  end
  local ok, info = pcall(C_Texture.GetAtlasInfo, name)
  return ok and info ~= nil
end

local function FileOK(path)
  if type(GetFileIDFromPath) ~= "function" then
    return true -- the client can't tell: the game's own path is trusted
  end
  local ok, id = pcall(GetFileIDFromPath, path)
  return ok and id ~= nil
end

-- A texture with the game's atlas (kind "atlas") or file (kind "file"), or the grey stand-in.
local function GameArt(side, kind, name, layer, sublevel)
  local texture = Tex(side, layer, sublevel)
  local found = kind == "atlas" and AtlasOK(name) or (kind == "file" and FileOK(name))
  ns.UI_PREVIEW_ART[name] = found and true or false
  if found and kind == "atlas" and texture.SetAtlas then
    texture:SetAtlas(name)
  elseif found and kind == "file" then
    texture:SetTexture(name)
  else
    texture:SetColorTexture(UI.Unpack(GREY))
    side.standIns = (side.standIns or 0) + 1
  end
  return texture
end

local function GameIcon(side, index, x, y, size, holder)
  local icon = At(GameArt(holder or side, "file", ICONS[index]), side, x, y, size, size)
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  return icon
end

local function GameBar(side, x, y, w, h, color, fill)
  At(Solid(side, { 0, 0, 0, 0.55 }, "BACKGROUND"), side, x, y, w, h)
  local bar = At(GameArt(side, "file", STATUSBAR, "ARTWORK"), side, x, y, math.max(1, math.floor(w * fill)), h)
  bar:SetVertexColor(UI.Unpack(color))
  return bar
end

-- Codex's own drawing (the current theme) ------------------------------------------------------------------------

local function SlotRings()
  local slot = GameTheme().slot
  return slot and slot.rings or GameTheme().rings
end

local function LineColor()
  local theme = GameTheme()
  return theme.titlebar and theme.titlebar.line or theme.accent
end

-- One icon in the theme's slot look; round = cut to a circle in a thin ring.
local function CodexSlot(side, x, y, size, iconIndex, round, ringColor)
  local holder = Child(side)
  At(holder, side, x, y, size, size)
  if round then
    local ring = Disc(holder, size + 2, ringColor or LineColor(), "ARTWORK", 1)
    ring:SetPoint("CENTER")
    local edge = Disc(holder, size, { 0, 0, 0, 1 }, "ARTWORK", 2)
    edge:SetPoint("CENTER")
    local icon = Tex(holder, "ARTWORK", 3)
    icon:SetSize(size - 2, size - 2)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICONS[iconIndex])
    local mask = holder.CreateMaskTexture and holder:CreateMaskTexture()
    if mask then
      mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(icon)
      if icon.AddMaskTexture then
        icon:AddMaskTexture(mask)
      end
    end
    return holder
  end
  local slot = GameTheme().slot or {}
  Solid(holder, slot.fill or { 0, 0, 0, 1 }, "BACKGROUND"):SetAllPoints()
  local icon = Tex(holder, "ARTWORK")
  icon:SetPoint("TOPLEFT", 1, -1)
  icon:SetPoint("BOTTOMRIGHT", -1, 1)
  icon:SetTexture(ICONS[iconIndex])
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  UI.Rings(holder, SlotRings(), "OVERLAY")
  if ringColor then
    Lines(holder, -1, ringColor, "OVERLAY", 2) -- a debuff keeps its dispel colour
  end
  return holder
end

-- An empty slot: see-through, a faint line.
local function CodexEmptySlot(side, x, y, size)
  local holder = Child(side)
  At(holder, side, x, y, size, size)
  Solid(holder, { 1, 1, 1, 0.06 }, "BACKGROUND"):SetAllPoints()
  local line = LineColor()
  Lines(holder, 0, { line[1], line[2], line[3], 0.4 })
  return holder
end

local function CodexBar(side, x, y, w, h, color, fill, edged)
  local holder = Child(side)
  At(holder, side, x, y, w, h)
  Solid(holder, { 0.05, 0.05, 0.05, 0.9 }, "BACKGROUND"):SetAllPoints()
  local bar = Tex(holder, "ARTWORK")
  bar:SetPoint("TOPLEFT")
  bar:SetSize(math.max(1, math.floor(w * fill)), h)
  UI.Gradient(bar, { color[1] * 0.6, color[2] * 0.6, color[3] * 0.6 }, color)
  Lines(holder, 0, { 0, 0, 0, 1 }, "OVERLAY")
  if edged then
    local line = LineColor()
    local outer = T.Outline(holder, -1, line, 1, "OVERLAY")
    T.ColorLines(outer, line, line[4])
  end
  return holder
end

-- The theme's HUD box (unit frames, chat, tracker) or its window panel.
local function CodexBox(side, x, y, w, h, kind, alpha)
  local theme = GameTheme()
  local box = Child(side)
  At(box, side, x, y, w, h)
  local fill = Tex(box, "BACKGROUND")
  fill:SetAllPoints()
  if kind == "panel" then
    local panel = theme.panel
    T.Gradient(fill, "VERTICAL", panel.from, panel.to, alpha or 0.97, alpha or 0.97)
    UI.Rings(box, theme.rings)
    box.fillColor = panel.to
  else
    local hud = theme.hud or {}
    local color = hud.fill or { 0, 0, 0, 0.6 }
    fill:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 0.6)
    box.fillColor = color
    if kind ~= "soft" then
      UI.Rings(box, hud.rings or theme.rings)
    end
  end
  return box
end

local function CodexDivider(parent, x, y, w)
  local line = Solid(Ink(parent), GameTheme().divider, "ARTWORK")
  At(line, parent, x, y, w, 1)
  return line
end

-- The pictures, one pair per part. Each draws into `side` (w x h). --------------------------------------------

local PICTURES = {}

PICTURES.actionbars = {
  game = function(side)
    for index = 1, 3 do
      local x = 8 + (index - 1) * 32
      GameIcon(side, index, x, 15, 28)
      At(GameArt(side, "atlas", "UI-HUD-ActionBar-IconFrame", "OVERLAY"), side, x - 1, 14, 30, 30)
      local key = Text(side, NUMBER_FONT, 9, { 0.75, 0.75, 0.75 }, tostring(index), "RIGHT")
      key:SetPoint("TOPRIGHT", side, "TOPLEFT", x + 27, -16)
    end
  end,
  codex = function(side)
    for index = 1, 4 do
      local x = 8 + (index - 1) * 32
      if index < 4 then
        CodexSlot(side, x, 15, 28, index)
        local key = Text(side, NUMBER_FONT, 9, { 1, 1, 1 }, tostring(index), "RIGHT")
        key:SetPoint("TOPRIGHT", side, "TOPLEFT", x + 26, -17)
      else
        CodexEmptySlot(side, x, 15, 28)
      end
    end
  end,
}

PICTURES.unitframes = {
  game = function(side)
    At(GameArt(side, "atlas", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health", "ARTWORK", 1), side, 50, 22, 76, 11)
    At(GameArt(side, "atlas", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana", "ARTWORK", 1), side, 50, 34, 76, 7)
    local face = At(Disc(side, 34, GREY, "ARTWORK", 0), side, 10, 13, 34, 34)
    face:SetVertexColor(UI.Unpack(GREY))
    At(GameArt(side, "atlas", "UI-HUD-UnitFrame-Player-PortraitOn", "OVERLAY"), side, 2, 6, 132, 48)
    local name = Text(side, GAME_FONT, 9, GOLD, "Tylesser")
    name:SetPoint("TOPLEFT", side, "TOPLEFT", 54, -10)
  end,
  codex = function(side, w, h)
    if type(ns.DrawStylePreview) == "function" then
      ns.DrawStylePreview(side, ns.FrameStyle and ns.FrameStyle() or "compact", w, h)
    end
  end,
}

PICTURES.partyframes = {
  game = function(side)
    for row = 1, 2 do
      local y = 4 + (row - 1) * 27
      At(GameArt(side, "atlas", "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health", "ARTWORK", 1), side, 38, y + 9, 58, 7)
      At(Disc(side, 20, GREY, "ARTWORK", 0), side, 10, y + 2, 20, 20)
      At(GameArt(side, "atlas", "UI-HUD-UnitFrame-Party-PortraitOn", "OVERLAY"), side, 6, y, 100, 25)
    end
  end,
  codex = function(side)
    local names = { "Lucius", "Durgan" }
    for row = 1, 2 do
      local y = 4 + (row - 1) * 27
      if GameTheme().light then
        CodexBox(side, 34, y - 1, 90, 26, "hud") -- the row's light panel: the dark name reads on it
      end
      At(Disc(side, 24, LineColor(), "ARTWORK", 1), side, 8, y, 24, 24)
      At(Disc(side, 22, { 0, 0, 0, 1 }, "ARTWORK", 2), side, 9, y + 1, 22, 22)
      At(Disc(side, 20, { 0.42, 0.33, 0.27, 1 }, "ARTWORK", 3), side, 10, y + 2, 20, 20)
      local name = CodexText(side, 9, GameTheme().bright, names[row])
      name:SetPoint("TOPLEFT", side, "TOPLEFT", 38, -y)
      CodexBar(side, 38, y + 13, 80, 7, { 0.27, 0.84, 0.27 }, row == 1 and 0.9 or 0.55)
      CodexBar(side, 38, y + 21, 80, 3, { 0.29, 0.53, 1 }, 0.7)
    end
  end,
}

PICTURES.raidframes = {
  game = function(side)
    for index = 1, 4 do
      local x, y = 6 + ((index - 1) % 2) * 64, 6 + math.floor((index - 1) / 2) * 25
      At(GameArt(side, "file", "Interface\\RaidFrame\\Raid-Bar-Hp-Bg", "BACKGROUND"), side, x, y, 60, 22)
      local fill = At(GameArt(side, "file", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill", "ARTWORK"), side, x, y,
        math.floor(60 * (1 - index * 0.12)), 22)
      fill:SetVertexColor(UI.Unpack(CLASS[index]))
      local name = Text(side, GAME_FONT, 9, { 1, 1, 1 }, ({ "Valerius", "Tess", "Durgan", "Lucius" })[index])
      name:SetPoint("TOPLEFT", side, "TOPLEFT", x + 3, -y - 3)
    end
  end,
  codex = function(side)
    for index = 1, 4 do
      local x, y = 7 + ((index - 1) % 2) * 64, 7 + math.floor((index - 1) / 2) * 25
      CodexBar(side, x, y, 59, 21, ns.ToneClass(CLASS[index], GameTheme()), 1 - index * 0.12, true)
      local name = CodexText(side, 9, { 1, 1, 1 }, ({ "Valerius", "Tess", "Durgan", "Lucius" })[index])
      name:SetPoint("TOPLEFT", side, "TOPLEFT", x + 3, -y - 3)
    end
  end,
}

PICTURES.nameplates = {
  game = function(side)
    local name = Text(side, GAME_FONT, 9, { 1, 1, 1 }, "Soothsayer", "CENTER")
    name:SetPoint("TOP", side, "TOP", 0, -14)
    GameBar(side, 18, 26, 100, 9, { 0.85, 0.1, 0.1 }, 0.74)
    local frame = Child(side)
    At(frame, side, 18, 26, 100, 9)
    Lines(frame, 0, { 0, 0, 0, 1 }, "OVERLAY")
  end,
  codex = function(side)
    -- the name floats over the world: white on a light theme (its "bright" is dark)
    local name = CodexText(side, 9, GameTheme().light and { 1, 1, 1 } or GameTheme().bright, "Soothsayer", "CENTER")
    name:SetPoint("TOP", side, "TOP", 8, -14)
    CodexBar(side, 28, 26, 96, 12, { 0.85, 0.1, 0.1 }, 0.74, true)
    local value = Text(side, NUMBER_FONT, 9, { 1, 1, 1 }, "74%", "RIGHT")
    value:SetPoint("TOPRIGHT", side, "TOPLEFT", 121, -27)
    At(Disc(side, 20, LineColor(), "ARTWORK", 4), side, 4, 22, 20, 20)
    local light = GameTheme().light -- the disc is the theme's slot colour: light on a light theme
    At(Disc(side, 18, light and GameTheme().slot.fill or { 0.05, 0.05, 0.06, 1 }, "ARTWORK", 5), side, 5, 23, 18, 18)
    local level = Text(side, NUMBER_FONT, 9, GameColored({ 1, 0.82, 0 }, "slot"), "46", "CENTER")
    if light then
      level:SetShadowColor(0, 0, 0, 0)
    end
    level:SetPoint("CENTER", side, "TOPLEFT", 14, -32)
  end,
}

local function AuraRow(side, codex, round)
  for index = 1, 4 do
    local x = 8 + (index - 1) * 31
    local debuff = index == 4
    if codex then
      CodexSlot(side, x, 10, 24, debuff and 5 or index, round, debuff and { 0.8, 0, 0, 1 } or nil)
      local time = Text(side, NUMBER_FONT, 9, debuff and { 1, 0.55, 0.55 } or { 1, 1, 1 }, debuff and "9 s" or "12 m", "CENTER")
      time:SetPoint("TOP", side, "TOPLEFT", x + 12, -37)
    else
      GameIcon(side, debuff and 5 or index, x, 10, 24)
      if debuff then
        local border = At(GameArt(side, "file", "Interface\\Buttons\\UI-Debuff-Overlays", "OVERLAY"), side, x - 1, 9, 26, 26)
        if border.SetTexCoord then
          border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        end
        border:SetVertexColor(0.8, 0, 0)
      end
      local time = Text(side, GAME_FONT, 9, GOLD, debuff and "9 s" or "12 m", "CENTER")
      time:SetPoint("TOP", side, "TOPLEFT", x + 12, -37)
    end
  end
end

-- the round icons option switches the Codex side between its two drawings
local function TwoShapes(side, draw)
  local square, round = Child(side), Child(side)
  square:SetAllPoints()
  round:SetAllPoints()
  draw(square, false)
  draw(round, true)
  side.square, side.round = square, round
  side.refresh = function()
    local on = ns.SkinPartWanted("roundicons")
    square:SetShown(not on)
    round:SetShown(on)
  end
  side.refresh()
end

PICTURES.auras = {
  game = function(side)
    AuraRow(side, false)
  end,
  codex = function(side)
    TwoShapes(side, function(frame, round)
      AuraRow(frame, true, round)
    end)
  end,
}

local function CooldownRow(side, codex, round)
  for index = 1, 3 do
    local x = 10 + (index - 1) * 40
    if codex then
      CodexSlot(side, x, 12, 32, index, round)
    else
      GameIcon(side, index, x, 12, 32)
      At(GameArt(side, "atlas", "UI-HUD-CoolDownManager-IconOverlay", "OVERLAY"), side, x - 4, 8, 40, 40)
    end
    if index == 2 then
      local swipe = Solid(codex and Ink(side) or side, { 0, 0, 0, 0.55 }, "OVERLAY", 2)
      At(swipe, side, x + 1, 25, 30, 18)
      local count = Text(side, codex and NUMBER_FONT or GAME_FONT, 13, codex and { 1, 1, 1 } or GOLD, "8", "CENTER")
      count:SetPoint("CENTER", side, "TOPLEFT", x + 16, -28)
    end
  end
end

PICTURES.cooldowns = {
  game = function(side)
    CooldownRow(side, false)
  end,
  codex = function(side)
    TwoShapes(side, function(frame, round)
      CooldownRow(frame, true, round)
    end)
  end,
}

local MAP_COLOR = { 0.24, 0.42, 0.36, 1 }

local function MapDisc(side, size, x, y)
  local map = At(Disc(side, size, MAP_COLOR, "ARTWORK", 3), side, x, y, size, size)
  return map
end

PICTURES.minimap = {
  game = function(side, w)
    local size = 40
    local x = math.floor((w - size) / 2)
    MapDisc(side, size, x, 16)
    At(GameArt(side, "atlas", "ui-hud-minimap-frame", "OVERLAY"), side, x - 6, 10, size + 12, size + 12)
    local zone = Text(side, GAME_FONT, 9, GOLD, "Durotar", "CENTER")
    zone:SetPoint("TOP", side, "TOP", 0, -1)
  end,
  codex = function(side, w)
    local size = 40
    local x = math.floor((w - size) / 2)
    local shapes = {}
    for _, key in ipairs({ "round", "square", "header" }) do
      local frame = Child(side)
      frame:SetAllPoints()
      frame:SetSize(side:GetWidth(), side:GetHeight())
      shapes[key] = frame
      local theme = GameTheme()
      if key == "round" then
        At(Disc(frame, size + 6, LineColor(), "ARTWORK", 1), frame, x - 3, 13, size + 6, size + 6)
        At(Disc(frame, size + 2, { 0, 0, 0, 1 }, "ARTWORK", 2), frame, x - 1, 15, size + 2, size + 2)
        MapDisc(frame, size, x, 16)
      else
        local top = 16
        local map = Child(frame)
        At(map, frame, x, top, size, size - (key == "header" and 4 or 0))
        Solid(map, MAP_COLOR, "ARTWORK"):SetAllPoints()
        Lines(map, 0, { 0, 0, 0, 1 }, "OVERLAY")
        local line = LineColor()
        local outer = T.Outline(map, -1, line, 1, "OVERLAY")
        T.ColorLines(outer, line, line[4])
        if key == "header" then
          local plate = CodexBox(frame, x - 1, 2, size + 2, 13, "hud")
          local zone = CodexText(plate, 9, theme.accent, "Durotar", "CENTER")
          zone:SetPoint("CENTER", plate, "CENTER")
        end
      end
      if key ~= "header" then -- the zone name on a small plate above the map
        local plate = CodexBox(frame, x - 8, 1, size + 16, 12, "hud")
        local zone = CodexText(plate, 9, theme.accent, "Durotar", "CENTER")
        zone:SetPoint("CENTER", plate, "CENTER")
      end
    end
    side.shapes = shapes
    side.refresh = function()
      local shape = ns.db.skins.minimapShape or ns.MINIMAP_THEME_SHAPE[ns.db.theme or "runestone"] or "round"
      for key, frame in pairs(shapes) do
        frame:SetShown(key == shape)
      end
    end
    side.refresh()
  end,
}

local LOOT, MONEY = { 0.24, 0.77, 0.24 }, { 1, 1, 0 }

PICTURES.chat = {
  game = function(side)
    At(GameArt(side, "file", "Interface\\ChatFrame\\ChatFrameTab-BGMid", "ARTWORK"), side, 4, 4, 48, 14)
    local tab = Text(side, GAME_FONT, 9, GOLD, "General", "CENTER")
    tab:SetPoint("CENTER", side, "TOPLEFT", 28, -12)
    At(Solid(side, { 0, 0, 0, 0.25 }, "BACKGROUND"), side, 4, 18, 129, 38)
    local loot = Text(side, GAME_FONT, 9, LOOT, "Loot: [Mithril Ore]")
    loot:SetPoint("TOPLEFT", side, "TOPLEFT", 7, -23)
    local money = Text(side, GAME_FONT, 9, MONEY, "You get 1s 91c.")
    money:SetPoint("TOPLEFT", side, "TOPLEFT", 7, -36)
  end,
  codex = function(side)
    local theme = GameTheme()
    local tab = Child(side)
    At(tab, side, 4, 3, 46, 14)
    local fill = Tex(tab, "BACKGROUND")
    fill:SetAllPoints()
    UI.Gradient(fill, theme.titlebar.from, theme.titlebar.to)
    local underline = Solid(tab, theme.accent, "ARTWORK")
    underline:SetPoint("BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT")
    underline:SetHeight(1)
    local label = CodexText(tab, 9, theme.accent, "General", "CENTER")
    label:SetPoint("CENTER", tab, "CENTER")
    local box = CodexBox(side, 4, 17, 129, 27, "hud")
    -- chat lines in the game's colours: darkened on a light theme's box, as the chat skin does
    local loot = Text(box, GAME_FONT, 9, GameColored(LOOT, "hud"), "Loot: [Mithril Ore]")
    loot:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
    local money = Text(box, GAME_FONT, 9, GameColored(MONEY, "hud"), "You get 1s 91c.")
    money:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -14)
    local edit = CodexBox(side, 4, 45, 129, 13, "hud")
    local say = Text(edit, GAME_FONT, 9, GameColored({ 1, 1, 1 }, "hud"), "Say:")
    say:SetPoint("LEFT", edit, "LEFT", 4, 0)
  end,
}

PICTURES.tracker = {
  game = function(side)
    At(GameArt(side, "atlas", "Objective-Header", "ARTWORK"), side, 2, 2, 133, 16)
    local header = Text(side, GAME_FONT, 9, GOLD, "Quests")
    header:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -5)
    local title = Text(side, GAME_FONT, 9, GOLD, "Vile Familiars")
    title:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -21)
    local goal = Text(side, GAME_FONT, 9, { 1, 1, 1 }, "- Slain: 4/12")
    goal:SetPoint("TOPLEFT", side, "TOPLEFT", 12, -33)
    local title2 = Text(side, GAME_FONT, 9, { 0.25, 0.75, 0.25 }, "Cutting Teeth")
    title2:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -45)
  end,
  codex = function(side)
    CodexBox(side, 2, 2, 133, 56, "soft", 0.5)
    local header = HeadText(side, 9, "accent", "All objectives")
    header:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -6)
    CodexDivider(side, 8, 18, 121)
    local title = CodexText(side, 9, GameColored(GOLD, "hud"), "Vile Familiars")
    title:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -21)
    local goal = CodexText(side, 9, GameColored({ 0.8, 0.8, 0.8 }, "hud"), "Slain: 4/12")
    goal:SetPoint("TOPLEFT", side, "TOPLEFT", 12, -33)
    local title2 = CodexText(side, 9, GameColored({ 0.25, 0.75, 0.25 }, "hud"), "Cutting Teeth")
    title2:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -45)
  end,
}

local METER = { { "Valerius", 1, "1,204" }, { "Tess", 0.76, "915" }, { "Durgan", 0.52, "626" } }
local METER_ROW, METER_TOP = 13, 19

PICTURES.damagemeter = {
  game = function(side)
    At(Solid(side, { 0.06, 0.06, 0.07, 0.85 }, "BACKGROUND"), side, 4, 4, 129, 52)
    local title = Text(side, GAME_FONT, 9, GOLD, "Damage Done")
    title:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -6)
    for index, row in ipairs(METER) do
      local y = METER_TOP + (index - 1) * METER_ROW
      GameBar(side, 8, y, 121, 12, CLASS[index], row[2])
      local name = Text(side, GAME_FONT, 9, { 1, 1, 1 }, row[1])
      name:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -y - 1)
      local value = Text(side, GAME_FONT, 9, { 1, 1, 1 }, row[3], "RIGHT")
      value:SetPoint("TOPRIGHT", side, "TOPLEFT", 127, -y - 1)
    end
  end,
  codex = function(side)
    local box = CodexBox(side, 4, 4, 129, 52, "hud")
    local title = HeadText(side, 10, "accent", "DPS")
    title:SetPoint("TOPLEFT", side, "TOPLEFT", 9, -6)
    CodexDivider(side, 8, 17, 121)
    for index, row in ipairs(METER) do
      local y = METER_TOP + 1 + (index - 1) * METER_ROW
      -- inside the box, so above its fill; the class colour toned on Dusk / Dawn as the skins draw it
      CodexBar(box, 4, y - 4, 121, 12, ns.ToneClass(CLASS[index], GameTheme()), row[2])
      local name = CodexText(side, 9, { 1, 1, 1 }, row[1])
      name:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -y - 1)
      local value = Text(side, NUMBER_FONT, 9, { 1, 1, 1 }, row[3], "RIGHT")
      value:SetPoint("TOPRIGHT", side, "TOPLEFT", 127, -y - 1)
    end
  end,
}

local function QuestMark(side, x, y, size, kind)
  local atlas = kind == "turnin" and "QuestTurnin" or "Quest-In-Progress-Icon-yellow"
  local mark = At(GameArt(Ink(side), "atlas", atlas, "OVERLAY"), side, x, y, size, size)
  return mark
end

PICTURES.questlog = {
  game = function(side)
    At(GameArt(side, "atlas", "QuestLog-main-background", "BACKGROUND"), side, 2, 2, 133, 56)
    local zone = Text(side, GAME_FONT, 9, GOLD, "Durotar")
    zone:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -7)
    for index, title in ipairs({ "[12] Vile Familiars", "[10] Cutting Teeth" }) do
      local y = 20 + (index - 1) * 14
      QuestMark(side, 8, y, 10)
      local line = Text(side, GAME_FONT, 9, GOLD, title)
      line:SetPoint("TOPLEFT", side, "TOPLEFT", 21, -y - 1)
    end
  end,
  codex = function(side)
    CodexBox(side, 2, 2, 133, 56, "panel")
    local zone = HeadText(side, 10, "bright", "Durotar")
    zone:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -7)
    CodexDivider(side, 8, 18, 121)
    for index, title in ipairs({ "[12] Vile Familiars", "[10] Cutting Teeth" }) do
      local y = 22 + (index - 1) * 14
      QuestMark(side, 8, y, 10)
      local line = CodexText(side, 9, GameColored(index == 1 and GOLD or { 0.25, 0.75, 0.25 }), title)
      line:SetPoint("TOPLEFT", side, "TOPLEFT", 21, -y - 1)
    end
  end,
}

PICTURES.tooltips = {
  game = function(side)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local tip = Child(side, template)
    At(tip, side, 8, 6, 121, 46)
    if tip.SetBackdrop then
      tip:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, tile = true, tileSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      if tip.SetBackdropColor then
        tip:SetBackdropColor(0.09, 0.09, 0.19, 0.95)
      end
    end
    ns.UI_PREVIEW_ART["Interface\\Tooltips\\UI-Tooltip-Border"] = FileOK("Interface\\Tooltips\\UI-Tooltip-Border")
    local name = Text(tip, GAME_FONT, 9, { 1, 1, 1 }, "Mithril Ore")
    name:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -8)
    local kind = Text(tip, GAME_FONT, 9, { 1, 1, 1 }, "Trade Goods")
    kind:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -20)
    local sell = Text(tip, GAME_FONT, 9, { 1, 1, 1 }, "Sell price: 25c")
    sell:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -32)
  end,
  codex = function(side)
    local theme = GameTheme()
    local tip = CodexBox(side, 8, 6, 121, 46, "panel")
    local name = HeadText(tip, 10, "bright", "Mithril Ore")
    name:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -7)
    local kind = CodexText(tip, 9, theme.text, "Trade Goods")
    kind:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -19)
    CodexDivider(tip, 8, 30, 105)
    local line = CodexText(tip, 9, theme.text, ("|cff%02x%02x%02xCodex:|r 34 owned"):format(
      math.floor(theme.accent[1] * 255), math.floor(theme.accent[2] * 255), math.floor(theme.accent[3] * 255)))
    line:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -34)
  end,
}

local MENU = { "Set focus", "Invite", "Whisper" }

PICTURES.menus = {
  game = function(side)
    At(GameArt(side, "atlas", "common-dropdown-bg", "BACKGROUND"), side, 18, 2, 101, 56)
    for index, entry in ipairs(MENU) do
      local line = Text(side, GAME_FONT, 9, { 1, 1, 1 }, entry)
      line:SetPoint("TOPLEFT", side, "TOPLEFT", 30, -10 - (index - 1) * 13)
    end
  end,
  codex = function(side)
    local theme = GameTheme()
    local menu = CodexBox(side, 18, 2, 101, 56, "panel")
    for index, entry in ipairs(MENU) do
      local y = 8 + (index - 1) * 13
      if index == 2 then
        local band = Tex(menu, "ARTWORK")
        At(band, menu, 4, y - 1, 93, 13)
        T.Gradient(band, "HORIZONTAL", theme.select.from, theme.select.to, theme.select.from[4] or 0.25,
          theme.select.to[4] or 0.03)
      end
      local line = CodexText(menu, 9, index == 2 and theme.bright or theme.text, entry)
      line:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -y)
    end
  end,
}

local ROLL_GLYPHS = { "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
  "Interface\\Buttons\\UI-GroupLoot-Pass-Up" }
local RARE = { 0, 0.44, 0.87 }

PICTURES.lootroll = {
  game = function(side)
    At(GameArt(side, "atlas", "LootToast-MoreAwesome", "BACKGROUND"), side, 2, 8, 133, 44)
    GameIcon(side, 4, 8, 14, 22)
    local name = Text(side, GAME_FONT, 9, RARE, "Big Bad Pauldrons")
    name:SetPoint("TOPLEFT", side, "TOPLEFT", 34, -15)
    for index, glyph in ipairs(ROLL_GLYPHS) do
      At(GameArt(side, "file", glyph, "OVERLAY"), side, 34 + (index - 1) * 18, 26, 16, 16)
    end
    GameBar(side, 8, 44, 121, 4, { 1, 0.82, 0 }, 0.62)
  end,
  codex = function(side)
    local theme = GameTheme()
    local box = CodexBox(side, 2, 8, 133, 44, "panel")
    local ring = Child(box)
    At(ring, side, 7, 13, 24, 24)
    Lines(ring, 0, RARE, "OVERLAY", 2)
    Lines(ring, 1, { 0, 0, 0, 1 }, "OVERLAY", 2)
    GameIcon(side, 4, 9, 15, 20, ring)
    local name = CodexText(side, 9, RARE, "Big Bad Pauldrons")
    name:SetPoint("TOPLEFT", side, "TOPLEFT", 36, -15)
    for index, glyph in ipairs(ROLL_GLYPHS) do
      local plate = Child(box)
      At(plate, side, 36 + (index - 1) * 19, 26, 16, 14)
      local fill = Tex(plate, "BACKGROUND")
      fill:SetAllPoints()
      UI.Gradient(fill, theme.button.from, theme.button.to)
      Lines(plate, 0, theme.button.line)
      local art = GameArt(plate, "file", glyph, "ARTWORK")
      art:SetSize(12, 12)
      art:SetPoint("CENTER")
      if art.SetDesaturated then
        art:SetDesaturated(true)
      end
      art:SetVertexColor(UI.Unpack(theme.button.text))
    end
    CodexBar(box, 6, 36, 121, 3, theme.accent, 0.62)
  end,
}

local function MapTile(side)
  At(Solid(side, { 0.24, 0.31, 0.23, 1 }, "BACKGROUND"), side, 2, 2, 133, 56) -- a plain stand-in for the map
  local name = Text(side, GAME_FONT, 9, { 1, 0.95, 0.8 }, "Kalimdor")
  name:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 6, 5)
end

PICTURES.questpins = {
  game = function(side)
    MapTile(side) -- zoomed out the game shows no quest pins at all
  end,
  codex = function(side)
    MapTile(side)
    for _, pin in ipairs({ { 46, 14 }, { 74, 22 }, { 60, 34, "turnin" }, { 92, 12 } }) do
      QuestMark(side, pin[1], pin[2], 12, pin[3])
    end
  end,
}

PICTURES.windows = {
  game = function(side)
    At(GameArt(side, "file", "Interface\\FrameGeneral\\UI-Background-Rock", "BACKGROUND"), side, 8, 8, 121, 48)
    At(GameArt(side, "atlas", "UI-Frame-Metal-CornerTopLeft", "OVERLAY"), side, 4, 4, 22, 22)
    At(GameArt(side, "atlas", "UI-Frame-Metal-CornerTopRight", "OVERLAY"), side, 111, 4, 22, 22)
    At(GameArt(side, "atlas", "_UI-Frame-Metal-EdgeTop", "OVERLAY"), side, 26, 4, 85, 10)
    local title = Text(side, GAME_FONT, 9, GOLD, "Character", "CENTER")
    title:SetPoint("TOP", side, "TOP", 0, -8)
  end,
  codex = function(side)
    local theme = GameTheme()
    local window = CodexBox(side, 4, 4, 129, 52, "panel")
    local bar = Tex(window, "ARTWORK")
    At(bar, window, 2, 2, 125, 15)
    UI.Gradient(bar, theme.titlebar.from, theme.titlebar.to)
    local line = Solid(window, theme.titlebar.line, "ARTWORK", 1)
    At(line, window, 2, 17, 125, 1)
    local title = HeadText(window, 10, "titleText", theme.titlebar.upper and "CHARACTER" or "Character")
    title:SetPoint("TOPLEFT", window, "TOPLEFT", 7, -4)
    local close = Child(window)
    At(close, window, 112, 3, 13, 13)
    local fill = Tex(close, "BACKGROUND")
    fill:SetAllPoints()
    UI.Gradient(fill, theme.button.from, theme.button.to)
    Lines(close, 0, theme.button.line)
    local x = Text(close, NUMBER_FONT, 9, theme.button.text, "x", "CENTER")
    x:SetPoint("CENTER", close, "CENTER", 0, 1)
  end,
}
-- Damage numbers over a mob and a line of floating combat text: the game's font, then the theme's damage font
-- (themes without one, Classic and Slate, keep the game's).
local function FloatingText(side, font)
  local numbers = { { "575", 22, 30, 8, { 1, 1, 1 } }, { "340", 16, 74, 4, { 1, 0.95, 0.4 } },
    { "83", 14, 104, 18, { 1, 1, 1 } } }
  for _, n in ipairs(numbers) do
    local label = Text(side, font, n[2], n[5], n[1])
    label:SetPoint("TOPLEFT", side, "TOPLEFT", n[3], -n[4])
  end
  local xp = Text(side, font, 10, { 0.6, 0.4, 1 }, "XP: 276")
  xp:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 8, 6)
end

PICTURES.floatingtext = {
  game = function(side)
    FloatingText(side, GAME_FONT)
  end,
  codex = function(side)
    FloatingText(side, ns.DamageFont and ns.DamageFont() or GAME_FONT)
  end,
}
ns.UI_PICTURES = PICTURES

-- A small right-pointing arrow between the two pictures, drawn (no glyph): a 7 px line and a solid head of
-- five 1 px columns, 9 to 1 px tall, all centred on the same middle line. `cx` is the gap's centre.
local function Arrow(parent, cx, cy, color)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(12, 9)
  holder:SetPoint("CENTER", parent, "TOPLEFT", cx, -cy)
  holder.pieces = {}
  local shaft = Solid(holder, color, "ARTWORK")
  shaft:SetSize(7, 1)
  shaft:SetPoint("LEFT", holder, "LEFT", 0, 0)
  holder.pieces[1] = shaft
  for column = 0, 4 do
    local bar = Solid(holder, color, "ARTWORK")
    bar:SetSize(1, 9 - column * 2)
    bar:SetPoint("LEFT", holder, "LEFT", 7 + column, 0)
    holder.pieces[#holder.pieces + 1] = bar
  end
  return holder
end

-- Every text in a picture gets a width that ends inside its box. No wrapping in a picture: a text that would run
-- past its box is cut short ("...") instead.
local function Walk(frame, visit)
  for _, region in ipairs({ frame:GetRegions() }) do
    visit(region)
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    Walk(child, visit)
  end
end
ns.UIWalk = Walk

local function IsText(region)
  return type(region) == "table" and region.GetObjectType and region:GetObjectType() == "FontString"
end

local function BoundPictureTexts(side, sideWidth)
  Walk(side, function(region)
    if not IsText(region) then
      return
    end
    local point, relative, relativePoint, x = region:GetPoint(1)
    local room = sideWidth - 4
    if type(point) == "string" and type(relativePoint) == "string" and type(relative) == "table" and relative.GetWidth then
      -- the room from the anchor to the edge of what the text is anchored to: rightwards for a left-anchored
      -- text, leftwards for a right-anchored one, both ways for a centred one
      local width = relative:GetWidth() or sideWidth
      local at = (relativePoint:find("LEFT$") and 0 or (relativePoint:find("RIGHT$") and width or width / 2)) + (x or 0)
      if point:find("LEFT$") then
        room = math.min(room, width - at - 2)
      elseif point:find("RIGHT$") then
        room = math.min(room, at - 2)
      else
        room = math.min(room, 2 * math.min(at, width - at) - 4)
      end
    end
    region:SetWidth(math.max(8, math.floor(room)))
    region:SetWordWrap(false)
  end)
end

-- The "Game default > Codex" pair for one part.
local function Picture(card, id, width)
  local pair = CreateFrame("Frame", nil, card)
  local sideWidth = math.floor((width - 26) / 2)
  local height = 60
  pair:SetSize(width, height + 16)
  local sides = {}
  for index, key in ipairs({ "game", "codex" }) do
    local side = Child(pair)
    if key == "codex" then
      UI.Ink(side) -- Codex's own widgets in the picture (texts) use the ink surfaces too
    end
    side:SetSize(sideWidth, height)
    side:SetPoint("TOPLEFT", pair, "TOPLEFT", index == 1 and 0 or (sideWidth + 26), 0)
    -- the game side on a neutral dark ground, the Codex side on a dusk one (both see-through panels show)
    side.fillColor = index == 1 and { 0.12, 0.12, 0.13, 1 } or { 0.13, 0.1, 0.08, 1 }
    Solid(side, side.fillColor, "BACKGROUND", -8):SetAllPoints()
    Lines(side, 0, Theme().divider)
    local draw = PICTURES[id] and PICTURES[id][key]
    if draw then
      local ok, err = pcall(draw, side, sideWidth, height)
      if not ok then
        geterrorhandler()(err)
      end
    end
    BoundPictureTexts(side, sideWidth)
    local label = UI.Text(pair, "body", 11, "muted")
    label:SetPoint("TOP", side, "BOTTOM", 0, -3)
    label:SetWidth(sideWidth)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(index == 1 and "Game default" or "Codex")
    side.label = label
    sides[key] = side
  end
  pair.arrow = Arrow(pair, sideWidth + 13, math.floor(height / 2), Theme().muted)
  pair.game, pair.codex = sides.game, sides.codex
  pair.sideWidth = sideWidth
  pair.codexPicture = true -- sample texts, not options (the search skips them)
  return pair
end

-- Text layout (Settings.lua's helpers) ---------------------------------------------------------------------------

local TextHeight = ns.UITextHeight
local Wrapping = ns.UIWrapping
local WrapCheck = ns.UIWrapCheck
local Stack = ns.UIStack

local function AddCheck(stack, check, gap)
  return stack.Add(check, check.Height, -2, gap)
end

local function AddText(stack, text, gap)
  return stack.Add(text, function()
    return TextHeight(text, text.size or 12, text.columnWidth or 200)
  end, 0, gap)
end

-- Options inside the cards ------------------------------------------------------------------------------------

local function RedrawTexts(nameplates, frames)
  for _, name in ipairs({ frames and "RefreshUnitText" or "", nameplates and "RefreshNameplateText" or "" }) do
    local redraw = ns.API[name]
    if type(redraw) == "function" then
      pcall(redraw)
    end
  end
end

local TEXT_CHOICES = {}
for _, format in ipairs(ns.UNIT_TEXT_FORMATS) do
  TEXT_CHOICES[#TEXT_CHOICES + 1] = { key = format.key, name = format.name }
end

local LABEL_WIDTH = 104

-- A label and a picker in one row of its own. Returns the picker (picker.row is the row).
local function PickerRow(parent, stack, labelText, width, get, choices, set, current)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, 24)
  local label = Wrapping(row, 12, "text", LABEL_WIDTH, labelText)
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -5)
  local pick = UI.Picker(row, width - LABEL_WIDTH - 6, 24)
  pick:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_WIDTH + 6, 0)
  pick.label:SetWidth(width - LABEL_WIDTH - 26)
  pick.refresh = function(self)
    self:SetText(get())
  end
  pick:SetScript("OnClick", function(self)
    ns.PickerMenu(self, choices(), current and current(), function(key)
      set(key)
      self:refresh()
    end)
  end)
  pick:refresh()
  pick.row = row
  stack.Add(row, function()
    return math.max(24, TextHeight(label, 12, LABEL_WIDTH) + 5)
  end)
  return pick
end

local function UnitTextRow(parent, stack, labelText, bar, width)
  return PickerRow(parent, stack, labelText, width, function()
    return ns.UnitTextName(ns.UnitTextFormat(bar))
  end, function()
    return TEXT_CHOICES
  end, function(key)
    ns.db.skins.unitText = ns.db.skins.unitText or {}
    ns.db.skins.unitText[bar] = key
    RedrawTexts(bar == "nameplate", bar ~= "nameplate")
  end, function()
    return ns.UnitTextFormat(bar)
  end)
end

local function OptionCheck(parent, stack, labelText, width, get, set, gap)
  local check = WrapCheck(parent, labelText, width)
  check.refresh = function(self)
    self:SetChecked(get() and true or false)
  end
  check:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
  end)
  check:refresh()
  AddCheck(stack, check, gap)
  return check
end

-- the round icons option (the "roundicons" part), shown in two cards
local function RoundIconsCheck(parent, stack, width)
  local check = OptionCheck(parent, stack, "Round icons (buffs, debuffs and the cooldown manager)", width, function()
    return ns.SkinPartWanted("roundicons")
  end, function(on)
    ns.db.skins.parts.roundicons = on
    ns.NeedsReload()
  end)
  check.part = "roundicons"
  return check
end

local OPTIONS = {}

OPTIONS.actionbars = function(card, parent, width, stack)
  local options = card.options
  options.panels = OptionCheck(parent, stack, "A panel behind each bar, fitted to its buttons", width, function()
    return ns.SkinPartWanted("barpanels")
  end, function(on)
    ns.db.skins.parts.barpanels = on
    ns.NeedsReload()
  end, 8)
  options.panels.part = "barpanels"
  local guide = Wrapping(parent, 12, "text", width, ns.BAR_GUIDE)
  guide:SetSpacing(2)
  options.guide = guide
  AddText(stack, guide, 8)
  local check = UI.Button(parent, 130, 24, "Check spacing")
  stack.Add(check, function()
    return 24
  end)
  local result = Wrapping(parent, 12, "good", width, "")
  stack.Add(result, function()
    return (result:GetText() or "") == "" and 0 or TextHeight(result, 12, width)
  end)
  check:SetScript("OnClick", function()
    local text = ns.BarSpacingText()
    result:SetText(text)
    local theme = Theme()
    result:SetTextColor(UI.Unpack(text:find("^All clear") and theme.good or theme.text))
    if card.Relayout then
      card.Relayout()
    end
  end)
  options.spacingButton, options.spacingResult = check, result
end

OPTIONS.unitframes = function(card, parent, width, stack)
  local options = card.options
  AddText(stack, Wrapping(parent, 12, "text", width, "Frame style"), 4)
  local cards
  cards = ns.StyleCards(parent, width, function(key)
    ns.db.skins.frameStyle = key
    cards.refresh()
    local refresh = ns.API.RefreshFrameStyle
    if type(refresh) == "function" then
      pcall(refresh)
    end
    if card.RedrawCodex then
      card.RedrawCodex()
    end
  end)
  ns.styleCards = cards
  options.styles = cards
  stack.Add(cards, function()
    return cards:GetHeight() or 78
  end, 0, 10)
  options.health = UnitTextRow(parent, stack, "Health text", "health", width)
  options.power = UnitTextRow(parent, stack, "Power text", "power", width)
  options.classHealth = OptionCheck(parent, stack, "Health bars in class colours (players; NPCs by reaction)", width,
    ns.ClassHealth, function(on)
      ns.db.skins.healthColor = on and "class" or nil
      local refresh = ns.API.RefreshHealthColor
      if type(refresh) == "function" then
        pcall(refresh)
      end
      if ns.resource and type(ns.resource.RefreshHealthColor) == "function" then
        pcall(ns.resource.RefreshHealthColor) -- Personal bars' health
      end
      if type(ns.RecolourPreviews) == "function" then
        ns.RecolourPreviews()
      end
      if card.RedrawCodex then
        card.RedrawCodex()
      end
    end, 4)
  options.short = OptionCheck(parent, stack, "Short numbers (1.9K instead of 1,920)", width, ns.UnitTextShort, function(on)
    ns.db.skins.unitText = ns.db.skins.unitText or {}
    ns.db.skins.unitText.short = on
    RedrawTexts(true, true)
  end, 4)
  options.smooth = OptionCheck(parent, stack, "Smooth health and power bars (fill gradually, e.g. while eating)", width,
    ns.SmoothBars, function(on)
      ns.db.skins.smoothBars = on
    end)
  -- where each frame's auras go (Settings.lua ns.AURA_PLACES)
  options.auraPlaces = {}
  for _, unit in ipairs({ { "target", "Target auras" }, { "focus", "Focus auras" }, { "party", "Party auras" } }) do
    options.auraPlaces[#options.auraPlaces + 1] = PickerRow(parent, stack, unit[2], width, function()
      local place = ns.AuraPlace(unit[1])
      for _, choice in ipairs(ns.AURA_PLACES) do
        if choice.key == place then
          return choice.name
        end
      end
      return place
    end, function()
      return ns.AURA_PLACES
    end, function(key)
      ns.db.skins.auraPos = ns.db.skins.auraPos or {}
      ns.db.skins.auraPos[unit[1]] = key ~= "below" and key or nil
      local refresh = ns.API.RefreshFrameStyle
      if type(refresh) == "function" then
        pcall(refresh)
      end
    end, function()
      return ns.AuraPlace(unit[1])
    end)
  end
  options.firstName = OptionCheck(parent, stack, "Players by first name only (no surname)", width, ns.FirstNameOnly,
    function(on)
      ns.db.skins.firstNameOnly = on and true or nil
      local refresh = ns.API.RefreshNames
      if type(refresh) == "function" then
        pcall(refresh)
      end
    end, 4)
end

OPTIONS.nameplates = function(card, parent, width, stack)
  card.options.health = UnitTextRow(parent, stack, "Health text", "nameplate", width)
  card.options.glow = OptionCheck(parent, stack, "Glow round the target's nameplate", width, function()
    return not (ns.db.skins and ns.db.skins.nameplateGlow == false)
  end, function(on)
    ns.db.skins.nameplateGlow = (not on) and false or nil
    local refresh = ns.API.RefreshPlateGlow
    if type(refresh) == "function" then
      pcall(refresh)
    end
  end, 4)
end

OPTIONS.auras = function(card, parent, width, stack)
  local options = card.options
  options.round = RoundIconsCheck(parent, stack, width)
  -- icon spacing: label and stepper in one row, the note under them
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, 22)
  local label = Wrapping(row, 12, "text", LABEL_WIDTH, "Icon spacing")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
  local spacing = UI.Stepper(row, 48)
  spacing:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_WIDTH + 6, 0)
  stack.Add(row, function()
    return math.max(22, TextHeight(label, 12, LABEL_WIDTH) + 4)
  end, 0, 4)
  local note = Wrapping(parent, 11, "muted", width, "The gap round each round icon, here and in the cooldown manager.")
  AddText(stack, note)
  local function Show()
    spacing.value:SetText(("%d px"):format(ns.IconSpacing()))
    spacing.less:SetEnabled(ns.IconSpacing() > 0)
    spacing.more:SetEnabled(ns.IconSpacing() < 10)
  end
  local function Step(delta)
    ns.db.skins.iconSpacing = math.max(0, math.min(10, ns.IconSpacing() + delta))
    Show()
    local apply = ns.API.SetIconSpacing
    if type(apply) == "function" then
      pcall(apply, ns.db.skins.iconSpacing) -- the skins folder applies it at once
    else
      ns.NeedsReload()
    end
  end
  spacing.less:SetScript("OnClick", function() Step(-1) end)
  spacing.more:SetScript("OnClick", function() Step(1) end)
  spacing.refresh = Show
  Show()
  options.spacing = spacing
  options.spacingNote = note
end

OPTIONS.cooldowns = function(card, parent, width, stack)
  card.options.round = RoundIconsCheck(parent, stack, width)
end

-- The quest tracker's background (CodexDB.skins.trackerPanel, nil = on); the skins folder shows or hides it at once.
OPTIONS.tracker = function(card, parent, width, stack)
  card.options.panel = OptionCheck(parent, stack, "A background behind the quest tracker", width, function()
    return ns.TrackerPanelOn()
  end, function(on)
    ns.db.skins.trackerPanel = (not on) and false or nil
    local apply = ns.API.SetTrackerPanel
    if type(apply) == "function" then
      pcall(apply)
    elseif ns.db.skins.enabled then
      ns.NeedsReload()
    end
  end)
end

OPTIONS.minimap = function(card, parent, width, stack)
  local choices = { { key = "theme", name = "Theme default" } }
  for _, choice in ipairs(ns.MINIMAP_SHAPES) do
    choices[#choices + 1] = choice
  end
  card.options.shape = PickerRow(parent, stack, "Shape", width, function()
    return ns.MinimapShapeName(ns.db.skins.minimapShape)
  end, function()
    return choices
  end, function(key)
    ns.SetMinimapShape(key)
    if card.picture and card.picture.codex.refresh then
      card.picture.codex.refresh()
    end
  end, function()
    return ns.db.skins.minimapShape or "theme"
  end)
end

-- The part sections ---------------------------------------------------------------------------------------------

local function PartName(id)
  for _, part in ipairs(ns.SKIN_PARTS) do
    if part.id == id then
      return part.name
    end
  end
  return id
end

-- Where each part's section goes (Areas.lua): page, place on it, the header's name, folded at first.
-- Parts shown as an option inside another part's section (ns.UI_OPTION_PARTS) have none of their own.
ns.PART_SECTIONS = {
  actionbars = { area = "bars", order = 10, title = "Look" },
  cooldowns = { area = "bars", order = 60, title = "Cooldown manager", folded = true },
  unitframes = { area = "units", order = 10, title = "Player, target, pet and focus" },
  partyframes = { area = "units", order = 20, title = "Party frames", folded = true },
  raidframes = { area = "units", order = 30, title = "Raid frames", folded = true },
  nameplates = { area = "units", order = 40, title = "Nameplates", folded = true },
  auras = { area = "auras", order = 20, title = "Buffs and debuffs look" },
  lootroll = { area = "items", order = 40, title = "Loot roll window", folded = true },
  tracker = { area = "quests", order = 30, title = "Quest tracker", folded = true },
  questlog = { area = "quests", order = 40, title = "Quest log and world map", folded = true },
  minimap = { area = "map", order = 10, title = "Minimap" },
  questpins = { area = "map", order = 50, title = "Quest pins on bigger maps", folded = true },
  chat = { area = "chat", order = 10, title = "Chat" },
  damagemeter = { area = "chat", order = 20, title = "Damage meter", folded = true },
  tooltips = { area = "tooltips", order = 10, title = "Tooltip look" },
  windows = { area = "general", order = 20, title = "Game windows" },
  menus = { area = "general", order = 30, title = "Menus" },
  floatingtext = { area = "general", order = 40, title = "Floating combat text" },
}

-- A part's section id ("part-chat"): area and part ids would clash ("chat", "tooltips").
function ns.PartSectionId(id)
  return "part-" .. (ns.UI_OPTION_PARTS[id] or id)
end

local PICTURE_WIDTH = 303 -- the pictures are drawn for this width (two 138 px sides and the arrow between)
local PICTURE_GAP = 18
local TWO_COLUMNS = 560 -- narrower: the picture goes on top of the text
ns.partCards = {} -- [part id] = the part's body (also for the tests)

-- One part's body: what it changes in plain words, the part's own options and, beside them (on top when narrow),
-- the "Game default > Codex" picture. Its switch is the section header's. card.Measure() lays it out and returns
-- its height; card.refresh() reads the settings again.
function ns.BuildPartCard(parent, part, width, section)
  local card = CreateFrame("Frame", nil, parent)
  card:SetWidth(width)
  card.id = part.id
  local columns = width >= TWO_COLUMNS and 2 or 1
  local pictureWidth = math.min(PICTURE_WIDTH, width)
  local inner = columns == 2 and (width - pictureWidth - PICTURE_GAP) or width
  card.inner, card.columns = inner, columns
  card.options = {}
  card.check = section and section.switch
  card.picture = Picture(card, part.id, pictureWidth)
  function card.RedrawCodex()
    -- the unit frame picture follows the frame style: draw it again
    local old = card.picture
    card.picture = Picture(card, part.id, pictureWidth)
    old:Hide()
    if card.Relayout then
      card.Relayout()
    end
  end

  local desc = Wrapping(card, 12, "muted", inner, ns.UI_PART_TEXT[part.id] or "")
  desc:SetSpacing(2)
  card.desc = desc

  local holder, stack
  if OPTIONS[part.id] then
    holder = CreateFrame("Frame", nil, card)
    holder:SetSize(inner, 10)
    stack = Stack(holder)
    OPTIONS[part.id](card, holder, inner, stack)
    card.optionsFrame = holder
  end

  function card.Measure()
    local y = 0
    local pictureHeight = card.picture:GetHeight() or 76
    card.picture:ClearAllPoints()
    if columns == 2 then
      card.picture:SetPoint("TOPLEFT", card, "TOPLEFT", inner + PICTURE_GAP, 0)
    else
      card.picture:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
      y = pictureHeight + 10
    end
    desc:ClearAllPoints()
    desc:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
    y = y + TextHeight(desc, 12, inner)
    if holder and #stack.rows > 0 then
      y = y + 12
      holder:ClearAllPoints()
      holder:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
      local h = stack.Layout()
      holder:SetHeight(math.max(1, h))
      y = y + h
    end
    local height = math.ceil(columns == 2 and math.max(y, pictureHeight) or y)
    card:SetHeight(height)
    return height
  end

  function card.refresh()
    local on = ns.db.skins.enabled and true or false
    for _, option in pairs(card.options) do
      if type(option) == "table" and option.refresh then
        option:refresh()
      end
      if type(option) == "table" and option.SetEnabled and option.GetObjectType
        and (option:GetObjectType() == "CheckButton" or option:GetObjectType() == "Button") then
        option:SetEnabled(on)
      end
    end
    local codex = card.picture and card.picture.codex
    if codex and codex.refresh then
      codex.refresh()
    end
  end
  card.refresh()
  ns.partCards[part.id] = card
  return card
end

local function RestyleOff()
  return not ns.db.skins.enabled
end

local function SwitchRestyleOn()
  ns.db.skins.enabled = true
  ns.NeedsReload()
end

for _, part in ipairs(ns.SKIN_PARTS) do
  local place = ns.PART_SECTIONS[part.id]
  if place and not ns.UI_OPTION_PARTS[part.id] then
    local aliases, keywords = {}, { part.name, ns.UI_PART_TEXT[part.id] }
    for option, host in pairs(ns.UI_OPTION_PARTS) do
      if host == part.id then
        aliases[#aliases + 1] = option
        keywords[#keywords + 1] = PartName(option) -- "Panel behind the action bars" finds the bars' look
      end
    end
    ns.AddSection(place.area, {
      id = ns.PartSectionId(part.id),
      part = part.id,
      title = place.title,
      order = place.order,
      folded = place.folded,
      aliases = aliases,
      keywords = keywords,
      switch = {
        get = function()
          return ns.SkinPartWanted(part.id)
        end,
        set = function(on)
          ns.db.skins.parts[part.id] = on and true or false
          ns.NeedsReload()
        end,
        enabled = function()
          return ns.db.skins.enabled and true or false
        end,
      },
      tag = function()
        return RestyleOff() and "restyle off" or ""
      end,
      notice = function()
        if RestyleOff() then
          return "The game's interface isn't restyled, so this part waits. The switch for all of it is in General.",
            "Restyle it", SwitchRestyleOn
        end
        return nil
      end,
      build = function(holder, width, section)
        local card = ns.BuildPartCard(holder, part, width, section)
        card:SetPoint("TOPLEFT")
        card.Relayout = function()
          local def = ns.sectionById[ns.PartSectionId(part.id)]
          local page = def and ns.areaPages[def.area]
          if page then
            page.Layout()
          end
        end
        section.Register(card)
        return { Height = card.Measure }
      end,
    })
  end
end

-- General: the switch for the whole restyle --------------------------------------------------------------------

local function BuildRestyle(body, width, section)
  local stack = Stack(body)
  local intro = Wrapping(body, 12, "muted", width, "Codex redraws the game's own bars, frames, chat, minimap and "
    .. "windows in your theme; Edit Mode still decides where everything sits. Each part has its own switch on its "
    .. "page: action bars, unit frames, buffs, map and quests, chat, tooltips, and game windows and menus below. "
    .. "Changes take effect after a reload.")
  AddText(stack, intro, 6)
  local overlapName = ns.UIOverlap()
  local overlap = Wrapping(body, 12, "warn", width, overlapName and ns.OVERLAP_NOTE:format(overlapName) or "")
  overlap:SetShown(overlapName ~= nil)
  if overlapName then
    AddText(stack, overlap, 6)
  end
  body.introTexts = { intro, overlap }
  body.skinsCheck = section.switch
  ns.restyleBody = body
  return { Height = stack.Layout }
end

ns.AddSection("general", {
  id = "restyle",
  title = "Restyle the game's interface",
  order = 10,
  aliases = { "skins" },
  keywords = { "skins theme game interface" },
  switch = {
    get = function()
      return ns.db.skins.enabled and true or false
    end,
    set = function(on)
      ns.db.skins.enabled = on and true or false
      ns.NeedsReload()
    end,
  },
  build = BuildRestyle,
})

ns.UIPartName = PartName
