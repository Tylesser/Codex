local addonName, ns = ...
local L = ns.L

-- The three styles' frames and the pieces they share (board R4-Gossip / R4-Quest; "B and C use the same pieces"):
--   A  CodexDialogueFrame  a themed window (UI.Panel) where the game's would be, drag it by its top; as tall as
--      its content, a thin scroll bar only when the text is long.
--   B  CodexDialogueBar    a subtitle bar at the bottom of the screen (theme token dialogue.sub), the round NPC
--      portrait over its top left corner, the text in parts you click (or Space) through; the choices, objectives
--      and rewards in CodexDialogueSide, a small panel (theme hud look) above its right end.
--   C  CodexDialogueBook   a page at the right of the screen (dialogue.page, ink colours), portrait on its top edge.
-- Content (D.NewContent) is a stack of blocks laid out top to bottom with measured heights, again on the next frame
-- (font strings measure 0 before they are first drawn). Colours come from a palette: the theme's for A and B, the
-- paper's ink for C. Thin lines, see-through empty slots, no boxes inside boxes; no text under 9 px; names in the
-- body font, never in capitals.

local D = ns.dialogue
local UI = ns.UI
local T = ns.T

local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local BOOK_ICON = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local GAME_FONT = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")

-- Quest marks and difficulty colours (the game's), with darker ink versions for light paper (board R4).
D.MARK = { gold = { 1, 0.82, 0 }, blue = { 0.31, 0.70, 1 }, grey = { 0.62, 0.62, 0.62 } }
D.MARK_INK = { gold = { 0.66, 0.46, 0.04 }, blue = { 0.12, 0.44, 0.72 }, grey = { 0.49, 0.45, 0.40 } }
D.DIFF = { red = { 1, 0.19, 0.19 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 0.82, 0 }, green = { 0.25, 0.75, 0.25 },
  grey = { 0.62, 0.62, 0.62 } }
D.DIFF_INK = { red = { 0.69, 0.09, 0.09 }, orange = { 0.70, 0.29, 0.06 }, yellow = { 0.58, 0.40, 0 },
  green = { 0.18, 0.48, 0.11 }, grey = { 0.49, 0.45, 0.40 } }
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }
local QUALITY_TEXT = { [2] = { 0.25, 0.89, 0.25 }, [3] = { 0.24, 0.61, 1 }, [4] = { 0.72, 0.4, 1 } }
local QUALITY_INK = { [0] = { 0.4, 0.38, 0.35 }, [2] = { 0.1, 0.45, 0.05 }, [3] = { 0, 0.3, 0.65 }, [4] = { 0.45, 0.15, 0.65 },
  [5] = { 0.65, 0.3, 0 } }

-- Theme tokens: the theme's dialogue block over the fallback's, key by key.
local merged = setmetatable({}, { __mode = "k" })
function D.Tokens()
  local theme = ns.Theme()
  if merged[theme] then
    return merged[theme]
  end
  local tokens = {}
  local fallback = ns.FALLBACK_THEME and ns.FALLBACK_THEME.dialogue or {}
  for key, value in pairs(fallback) do
    tokens[key] = value
  end
  for key, value in pairs(type(theme.dialogue) == "table" and theme.dialogue or {}) do
    tokens[key] = value
  end
  merged[theme] = tokens
  return tokens
end

-- The colours one style draws with.
function D.Palette(style)
  local theme, tokens = ns.Theme(), D.Tokens()
  if style == "c" then
    local light = not (tokens.page and tokens.page.dark)
    return {
      ink = light, text = tokens.ink, muted = tokens.inkMuted, bright = tokens.ink, head = tokens.inkHead,
      rule = tokens.pageRule, hover = tokens.pageHover, icon = tokens.pageIcon,
      key = { fill = tokens.pageHover, line = tokens.pageRule, text = tokens.inkMuted },
      button = tokens.pageButton, primary = tokens.primary, select = tokens.pageHover, selLine = tokens.inkHead,
      good = light and D.InkTable("inkDiff", D.DIFF_INK).green or theme.good,
      bad = light and D.InkTable("inkDiff", D.DIFF_INK).red or theme.bad,
      chip = { fill = tokens.pageHover, line = tokens.pageRule },
      bar = { back = { 0, 0, 0, 0.15 }, fill = tokens.inkHead },
    }
  end
  local button = theme.button
  return {
    -- a light theme (Dawn) uses the darker ink colours for marks, difficulty and qualities, as on light paper
    ink = theme.light and true or false, text = theme.text, muted = theme.muted, bright = theme.bright, head = theme.accent,
    rule = tokens.rule, hover = tokens.rowHover, icon = theme.accent, key = tokens.key,
    button = { from = button.from, to = button.to, line = button.line, text = button.text },
    primary = tokens.primary, select = theme.select and theme.select.from or tokens.rowHover, selLine = tokens.selLine,
    good = theme.good, bad = theme.bad, chip = { fill = theme.inset.fill, line = theme.inset.line },
    bar = { back = theme.light and { 0, 0, 0, 0.1 } or { 0.04, 0.03, 0.05, 0.85 }, fill = theme.accent },
  }
end

-- The ink colours (marks, difficulty, qualities on light paper): a theme whose paper is darker than the usual cream
-- gives its own (dialogue.inkMark / inkDiff / inkQuality, key by key over these), so they keep reading on it.
function D.InkTable(key, base)
  local own = D.Tokens()[key]
  if type(own) ~= "table" then
    return base
  end
  return setmetatable(own, { __index = base })
end

-- The game's quest icon on a texture of ours: QuestUtil's choice (atlas or file), the plain files when this build
-- lacks the helper or the atlas. data = a quest row (active, complete, repeatable, daily, legendary).
local QUEST_FILES = { offer = "Interface/GossipFrame/AvailableQuestIcon",
  offerRepeat = "Interface/GossipFrame/DailyActiveQuestIcon", active = "Interface/GossipFrame/ActiveQuestIcon",
  activeRepeat = "Interface/GossipFrame/DailyActiveQuestIcon", incomplete = "Interface/GossipFrame/IncompleteQuestIcon" }
function D.QuestIcon(texture, data)
  local frequency = data.daily and 1 or 0
  local asset, isAtlas
  local util = _G.QuestUtil
  if type(util) == "table" then
    local get = data.active and util.GetQuestIconActive or util.GetQuestIconOffer
    if type(get) == "function" then
      local ok, a, b
      if data.active then
        ok, a, b = pcall(get, data.complete and true or false, data.legendary and true or false, frequency,
          data.repeatable and true or false, false, false, false, false)
      else
        ok, a, b = pcall(get, data.legendary and true or false, frequency, data.repeatable and true or false, false,
          false, false, false)
      end
      if ok and type(a) == "string" then
        asset, isAtlas = a, b and true or false
      end
    end
  end
  if isAtlas and not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(asset)) then
    asset = nil -- (an atlas this build doesn't have: the files below)
  end
  if not asset then
    isAtlas = false
    if data.active then
      asset = not data.complete and QUEST_FILES.incomplete or (data.repeatable and QUEST_FILES.activeRepeat or QUEST_FILES.active)
    else
      asset = data.repeatable and QUEST_FILES.offerRepeat or QUEST_FILES.offer
    end
  end
  if isAtlas then
    texture:SetAtlas(asset, false)
  else
    texture:SetTexture(asset)
    texture:SetTexCoord(0, 1, 0, 1)
  end
  texture:SetSize(16, 16)
  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetDesaturated(false)
  return asset, isAtlas
end

function D.MarkColor(palette, which)
  return (palette.ink and D.InkTable("inkMark", D.MARK_INK) or D.MARK)[which] or D.MARK.gold
end

function D.DiffColor(palette, which)
  return (palette.ink and D.InkTable("inkDiff", D.DIFF_INK) or D.DIFF)[which] or D.DIFF.yellow
end

function D.QualityColor(palette, quality)
  quality = type(quality) == "number" and quality or 1
  if palette.ink then
    return D.InkTable("inkQuality", QUALITY_INK)[quality] or palette.text
  end
  return QUALITY_TEXT[quality] or QUALITY[quality] or palette.text
end

function D.QualityRing(quality)
  quality = type(quality) == "number" and quality or 1
  return QUALITY[quality] or QUALITY[1]
end

-- Font sizes from the "Font size" option (board: body 14, the game's own 13).
function D.FontSize(delta)
  return math.max(10, D.DB().fontSize + (delta or 0))
end

local function Color(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function Text(parent, kind, size, color, layer)
  local text = parent:CreateFontString(nil, layer or "OVERLAY")
  UI.Font(text, kind or "body", size, color)
  text:SetJustifyH("LEFT")
  if text.SetJustifyV then
    text:SetJustifyV("TOP")
  end
  return text
end
D.Text = Text

-- Sets a text that may be a secret: readable texts as they are, anything else straight to SetText.
function D.SetText(fontString, text)
  pcall(fontString.SetText, fontString, text)
end

-- Height of a wrapped font string at `width`; an estimate while the game hasn't measured it yet.
local function TextHeight(fontString, width, size, text)
  fontString:SetWidth(width)
  local height = fontString.GetStringHeight and fontString:GetStringHeight()
  if type(height) == "number" and height > 0 then
    return math.ceil(height)
  end
  text = type(text) == "string" and text or ""
  if text == "" then
    return 0
  end
  local perLine = math.max(8, math.floor(width / (size * 0.52)))
  local lines = 0
  for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines = lines + math.max(1, math.ceil(#paragraph / perLine))
  end
  return math.ceil(lines * size * 1.3)
end
D.TextHeight = TextHeight

-- Shared pieces ------------------------------------------------------------------------------------------------

-- Round NPC portrait in the theme's rings (token npcRing, inside out), cut round with Media/Circle.
function D.Portrait(parent, size)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)
  local rings = D.Tokens().npcRing or {}
  local total = 0
  for _, ring in ipairs(rings) do
    total = total + (ring.size or 1)
  end
  local sublevel = -8
  local outer = total
  for index = #rings, 1, -1 do
    local disc = frame:CreateTexture(nil, "BACKGROUND", nil, math.min(7, sublevel))
    disc:SetTexture(CIRCLE)
    disc:SetPoint("CENTER")
    disc:SetSize(size + outer * 2, size + outer * 2)
    local c = rings[index].color
    disc:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    outer = outer - (rings[index].size or 1)
    sublevel = sublevel + 1
  end
  local back = frame:CreateTexture(nil, "BORDER")
  back:SetTexture(CIRCLE)
  back:SetAllPoints()
  back:SetVertexColor(0.05, 0.04, 0.05, 1)
  local face = frame:CreateTexture(nil, "ARTWORK")
  face:SetAllPoints()
  if frame.CreateMaskTexture and face.AddMaskTexture then
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(face)
    face:AddMaskTexture(mask)
  end
  frame.face = face
  frame.ringWidth = total
  function frame:SetUnit(unit)
    if unit and D.Call(_G.UnitExists, unit) == true and type(_G.SetPortraitTexture) == "function" then
      local ok = pcall(SetPortraitTexture, self.face, unit)
      if ok then
        self.face:SetTexCoord(0, 1, 0, 1)
        return
      end
    end
    self.face:SetTexture(BOOK_ICON)
    self.face:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  end
  return frame
end

-- A small cross button (muted, brighter under the mouse).
function D.CloseCross(parent, palette)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(20, 20)
  button.lines = {}
  for _, angle in ipairs({ 45, -45 }) do
    local line = button:CreateTexture(nil, "ARTWORK")
    line:SetSize(13, 2)
    line:SetPoint("CENTER")
    if line.SetRotation then
      line:SetRotation(math.rad(angle))
    end
    button.lines[#button.lines + 1] = line
  end
  function button:SetPalette(p)
    self.palette = p
    for _, line in ipairs(self.lines) do
      Color(line, p.muted)
    end
  end
  button:SetScript("OnEnter", function(self)
    for _, line in ipairs(self.lines) do
      Color(line, self.palette.bright)
    end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetPalette(self.palette)
  end)
  button:SetScript("OnClick", function()
    D.Close()
  end)
  button:SetPalette(palette)
  return button
end

-- Number keycap (board: 16 px, a light fill, thin line, darker bottom edge, 10 px digit).
function D.Keycap(parent)
  local cap = CreateFrame("Frame", nil, parent)
  cap:SetSize(16, 16)
  cap.fill = cap:CreateTexture(nil, "BACKGROUND")
  cap.fill:SetAllPoints()
  cap.ring = T.Outline(cap, 0, { 1, 1, 1 }, 1, "BORDER")
  cap.edge = cap:CreateTexture(nil, "BORDER", nil, 1)
  cap.edge:SetPoint("BOTTOMLEFT", 1, 1)
  cap.edge:SetPoint("BOTTOMRIGHT", -1, 1)
  cap.edge:SetHeight(2)
  cap.edge:SetColorTexture(0, 0, 0, 0.45)
  cap.text = cap:CreateFontString(nil, "OVERLAY")
  cap.text:SetFont(GAME_FONT, 10, "")
  cap.text:SetPoint("CENTER", 0, 1)
  function cap:Set(digit, palette)
    Color(self.fill, palette.key.fill)
    T.ColorLines(self.ring, palette.key.line, palette.key.line[4])
    self.text:SetTextColor(palette.key.text[1], palette.key.text[2], palette.key.text[3], 1)
    self.text:SetText(digit)
  end
  return cap
end

-- The space bar as a tiny key outline (no "[Space]" text), drawn beside the main button's label.
function D.SpaceKey(parent)
  local key = CreateFrame("Frame", nil, parent)
  key:SetSize(18, 12)
  key.lines = T.Outline(key, 0, { 1, 1, 1 }, 1, "OVERLAY")
  key.bar = key:CreateTexture(nil, "OVERLAY")
  key.bar:SetSize(8, 1)
  key.bar:SetPoint("BOTTOM", 0, 3)
  function key:SetColor(color)
    T.ColorLines(self.lines, color, 0.7)
    self.bar:SetColorTexture(color[1], color[2], color[3], 0.7)
  end
  return key
end

-- A button of ours: "primary" (the main one: Accept, Continue, Complete Quest) or "secondary".
function D.Button(parent)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(96, 30)
  button.fill = button:CreateTexture(nil, "BACKGROUND")
  button.fill:SetPoint("TOPLEFT", 1, -1)
  button.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  button.ring = T.Outline(button, 0, { 1, 1, 1 }, 1, "BORDER")
  button.glow = button:CreateTexture(nil, "HIGHLIGHT")
  button.glow:SetAllPoints(button.fill)
  button.glow:SetColorTexture(1, 1, 1, 0.08)
  button.label = Text(button, "body", 14)
  button.label:SetJustifyH("CENTER")
  if button.label.SetJustifyV then
    button.label:SetJustifyV("MIDDLE")
  end
  button.label:SetPoint("CENTER")
  button.label:SetWordWrap(false)
  button.space = D.SpaceKey(button)
  button.space:SetPoint("RIGHT", button.label, "LEFT", -8, 0)
  button.space:Hide()
  function button:Setup(spec, palette)
    local style = spec.primary and palette.primary or palette.button
    T.Gradient(self.fill, "VERTICAL", style.from, style.to, style.from[4] or 1, style.to[4] or 1)
    T.ColorLines(self.ring, style.line, style.line[4])
    UI.Font(self.label, "body", D.FontSize(0), style.text)
    self.label:SetText(spec.text or "")
    self.textColor = style.text
    self.spec = spec
    local enabled = spec.enabled ~= false
    self:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.55)
    if not enabled then
      self.label:SetTextColor(palette.muted[1], palette.muted[2], palette.muted[3], 1)
    end
    local spaceShown = spec.primary and spec.space and enabled
    self.space:SetShown(spaceShown and true or false)
    if spaceShown then
      self.space:SetColor(style.text)
    end
    self.label:ClearAllPoints()
    self.label:SetPoint("CENTER", spaceShown and 13 or 0, 0)
  end
  button:SetScript("OnClick", function(self)
    if self.spec and self.spec.action then
      self.spec.action()
    end
  end)
  return button
end

-- Content: blocks stacked top to bottom ------------------------------------------------------------------------

local Content = {}
Content.__index = Content

function D.NewContent(parent)
  return setmetatable({ parent = parent, pools = {}, used = {}, blocks = {}, width = 300, height = 0 }, Content)
end

function Content:Reset(width, palette, style)
  for kind, list in pairs(self.used) do
    self.pools[kind] = self.pools[kind] or {}
    for _, block in ipairs(list) do
      block:Hide()
      block:ClearAllPoints()
      if block.Release then
        block:Release()
      end
      table.insert(self.pools[kind], block)
    end
  end
  self.used, self.blocks = {}, {}
  self.width, self.palette, self.style = width, palette, style
end

-- A pooled block of `kind`, made by create(content) the first time.
function Content:Get(kind, create, gap)
  self.pools[kind] = self.pools[kind] or {}
  local block = table.remove(self.pools[kind]) or create(self)
  self.used[kind] = self.used[kind] or {}
  table.insert(self.used[kind], block)
  block.gap = gap or 8
  block:SetAlpha(1)
  block:Show()
  self.blocks[#self.blocks + 1] = block
  return block
end

function Content:Layout()
  local y = 0
  for index, block in ipairs(self.blocks) do
    local height = block.Measure and block:Measure(self.width) or block:GetHeight() or 0
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, -y)
    block:SetWidth(self.width)
    block:SetHeight(math.max(1, height))
    y = y + height + (index < #self.blocks and block.gap or 0)
  end
  self.height = y
  return y
end

-- Text (wrapped). opts: size, color (palette key or table), head = true for the heading font, center = true.
local function NewTextBlock(content)
  local block = CreateFrame("Frame", nil, content.parent)
  block.text = Text(block, "body", 14)
  block.text:SetPoint("TOPLEFT")
  function block:Measure(width)
    return TextHeight(self.text, width, self.size or 14, self.raw)
  end
  return block
end

function Content:Text(text, opts)
  opts = opts or {}
  local block = self:Get("text", NewTextBlock, opts.gap)
  local size = opts.size or D.FontSize(0)
  local color = opts.color or "text"
  UI.Font(block.text, opts.head and "head" or "body", size, type(color) == "table" and color or self.palette[color])
  block.text:SetJustifyH(opts.center and "CENTER" or "LEFT")
  block.text:SetWordWrap(true)
  block.size = size
  block.raw = D.Str(text)
  D.SetText(block.text, text)
  return block
end

-- Section label with a thin line after it ("Objectives ———").
local function NewSectionBlock(content)
  local block = CreateFrame("Frame", nil, content.parent)
  block.label = Text(block, "head", 12)
  block.label:SetPoint("LEFT")
  block.line = block:CreateTexture(nil, "ARTWORK")
  block.line:SetHeight(1)
  block.line:SetPoint("LEFT", block.label, "RIGHT", 8, 0)
  block.line:SetPoint("RIGHT")
  function block:Measure()
    return 16
  end
  return block
end

function Content:Section(title)
  local block = self:Get("section", NewSectionBlock, 6)
  UI.Font(block.label, "head", 12, self.palette.head)
  block.label:SetText(title)
  Color(block.line, self.palette.rule)
  return block
end

-- Chips: small boxes in a row that wraps (money, experience, reputation). chips = { { text } }.
local function NewChipsBlock(content)
  local block = CreateFrame("Frame", nil, content.parent)
  block.chips = {}
  function block:Measure(width)
    local x, y, rowHeight = 0, 0, 24
    for _, chip in ipairs(self.chips) do
      if chip:IsShown() then
        local w = chip.label:GetStringWidth()
        if type(w) ~= "number" or w <= 0 then
          w = #(chip.raw or "") * (self.size or 13) * 0.5
        end
        w = math.ceil(w) + 16
        if x > 0 and x + w > width then
          x, y = 0, y + rowHeight + 6
        end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
        chip:SetSize(w, rowHeight)
        x = x + w + 6
      end
    end
    return y + rowHeight
  end
  return block
end

function Content:Chips(list)
  if #list == 0 then
    return nil
  end
  local block = self:Get("chips", NewChipsBlock, 8)
  local size = D.FontSize(-1)
  block.size = size
  for index, spec in ipairs(list) do
    local chip = block.chips[index]
    if not chip then
      chip = CreateFrame("Frame", nil, block)
      chip.fill = chip:CreateTexture(nil, "BACKGROUND")
      chip.fill:SetAllPoints()
      chip.ring = T.Outline(chip, 0, { 1, 1, 1 }, 1, "BORDER")
      chip.label = Text(chip, "body", size)
      chip.label:SetPoint("LEFT", 8, 0)
      if chip.label.SetJustifyV then
        chip.label:SetJustifyV("MIDDLE")
      end
      block.chips[index] = chip
    end
    Color(chip.fill, self.palette.chip.fill)
    T.ColorLines(chip.ring, self.palette.chip.line, self.palette.chip.line[4])
    UI.Font(chip.label, "body", size, spec.color and self.palette[spec.color] or self.palette.bright)
    chip.label:SetText(spec.text)
    chip.raw = spec.raw or spec.text
    chip:Show()
  end
  for index = #list + 1, #block.chips do
    block.chips[index]:Hide()
  end
  return block
end

-- Item slot: icon with a thin ring in the quality colour (empty slots see-through), a count, name and a second line.
-- Used for the offer's rewards, the progress page's items and the reward choices.
function D.ItemIcon(parent, size)
  local slot = CreateFrame("Frame", nil, parent)
  slot:SetSize(size, size)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetPoint("TOPLEFT", 2, -2)
  slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local radius = UI.Radius("slot", ns.Theme())
  if radius then
    -- rounded (Dusk, Dawn): the quality ring and the dark inner line round, the icon cut to match
    slot.ring = UI.RoundLine(slot, slot, radius, { 1, 1, 1 }, { layer = "OVERLAY" })
    slot.inner = UI.RoundLine(slot, slot, radius - 1, { 0, 0, 0 }, { inset = 1, layer = "OVERLAY" })
    slot.mask = UI.RoundMask(slot, slot.icon, radius - 2, { slot.icon })
  else
    slot.ring = T.Outline(slot, 0, { 1, 1, 1 }, 1, "OVERLAY")
    slot.inner = T.Outline(slot, 1, { 0, 0, 0 }, 1, "OVERLAY")
  end
  slot.count = slot:CreateFontString(nil, "OVERLAY", nil, 2)
  slot.count:SetFont(GAME_FONT, 11, "OUTLINE")
  slot.count:SetPoint("BOTTOMRIGHT", -2, 2)
  function slot:Set(texture, quality, count, ringColor)
    self.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    T.ColorLines(self.ring, ringColor or D.QualityRing(quality), 1)
    self.count:SetText(count and count > 1 and tostring(count) or "")
  end
  return slot
end

-- Window frames -------------------------------------------------------------------------------------------------

local frames = {} -- [style] = frame
D.frames = frames

local function Own(frame)
  D.ownFrames[frame] = true
  -- the Quests page's Fonts tab: headings and the rest of the text (FontStyles.lua)
  UI.FontRole(frame, "dialogue.title", "dialogue.text")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetFrameStrata("MEDIUM")
  frame:SetToplevel(true)
  frame:Hide()
  return frame
end

-- Header (portrait, name, zone, cross) and the footer's buttons, shared by A and C.
local function Footer(frame)
  frame.buttons = { D.Button(frame), D.Button(frame) }
  frame.footLine = frame:CreateTexture(nil, "ARTWORK")
  frame.footLine:SetHeight(1)
end

local function NewScroll(frame)
  local scroll, body = UI.ScrollArea(frame)
  frame.scroll, frame.body = scroll, body
  frame.content = D.NewContent(body)
end

local function CreateA()
  local frame = Own(CreateFrame("Frame", "CodexDialogueFrame", UIParent))
  UI.Panel(frame, { strip = false })
  frame:SetMovable(true)
  frame.header = CreateFrame("Frame", nil, frame)
  frame.header:SetPoint("TOPLEFT")
  frame.header:SetPoint("TOPRIGHT")
  frame.header:SetHeight(64)
  frame.header:EnableMouse(true)
  frame.header:RegisterForDrag("LeftButton")
  frame.header:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  frame.header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    if point then
      D.DB().pos = { point, relativePoint, x, y }
    end
  end)
  frame.portrait = D.Portrait(frame.header, 44)
  frame.portrait:SetPoint("LEFT", 14, 0)
  frame.name = Text(frame.header, "body", 17)
  frame.name:SetPoint("TOPLEFT", frame.portrait, "TOPRIGHT", 13, -3)
  frame.name:SetPoint("RIGHT", -34, 0)
  frame.name:SetWordWrap(false)
  frame.zone = Text(frame.header, "body", 12)
  frame.zone:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -2)
  frame.zone:SetPoint("RIGHT", -34, 0)
  frame.zone:SetWordWrap(false)
  frame.close = D.CloseCross(frame, D.Palette("a"))
  frame.close:SetPoint("TOPRIGHT", -8, -8)
  frame.headLine = frame:CreateTexture(nil, "ARTWORK")
  frame.headLine:SetHeight(1)
  frame.headLine:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 14, 0)
  frame.headLine:SetPoint("TOPRIGHT", frame.header, "BOTTOMRIGHT", -14, 0)
  NewScroll(frame)
  Footer(frame)
  return frame
end

local function CreateC()
  local frame = Own(CreateFrame("Frame", "CodexDialogueBook", UIParent))
  local tokens = D.Tokens()
  local page = tokens.page or {}
  if not page.dark then
    UI.Paper(frame) -- dark text on light paper: no drop shadow (it blurred the text)
  end
  frame.paper = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  frame.paper:SetAllPoints()
  T.Gradient(frame.paper, "VERTICAL", page.from, page.to, page.from[4] or 1, page.to[4] or 1)
  -- a soft light at the top of light paper (the board's radial highlight)
  if not page.dark then
    frame.light = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.light:SetPoint("TOPLEFT", 2, -2)
    frame.light:SetPoint("TOPRIGHT", -2, -2)
    frame.light:SetHeight(120)
    T.Gradient(frame.light, "VERTICAL", { 1, 0.98, 0.91 }, { 1, 0.98, 0.91 }, 0, 0.35)
  end
  for index, color in ipairs(page.lines or {}) do
    local lines = T.Outline(frame, index - 1, color, 1, "BORDER")
    T.ColorLines(lines, color, color[4])
  end
  UI.Shadow(frame, frame)
  frame.portrait = D.Portrait(frame, 68)
  frame.portrait:SetPoint("CENTER", frame, "TOP", 0, 0)
  frame.close = D.CloseCross(frame, D.Palette("c"))
  frame.close:SetPoint("TOPRIGHT", -8, -8)
  frame.name = Text(frame, "body", 20)
  frame.name:SetJustifyH("CENTER")
  frame.name:SetPoint("TOPLEFT", 22, -48)
  frame.name:SetPoint("TOPRIGHT", -22, -48)
  frame.name:SetWordWrap(false)
  frame.zone = Text(frame, "body", 13)
  frame.zone:SetJustifyH("CENTER")
  frame.zone:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -2)
  frame.zone:SetPoint("TOPRIGHT", frame.name, "BOTTOMRIGHT", 0, -2)
  frame.zone:SetWordWrap(false)
  -- the ornament: line, a small diamond, line. All three hang on one band under the zone, so both anchors of a line
  -- are at the same height: a line anchored to the diamond on one end and to the window's LEFT edge on the other
  -- took the window's middle for its height and ran through the text (the user's screenshot, 2026-11-24).
  frame.ornament = CreateFrame("Frame", nil, frame)
  frame.ornament:SetPoint("TOPLEFT", frame.zone, "BOTTOMLEFT", 30, -11)
  frame.ornament:SetPoint("TOPRIGHT", frame.zone, "BOTTOMRIGHT", -30, -11)
  frame.ornament:SetHeight(12)
  frame.diamond = frame.ornament:CreateTexture(nil, "ARTWORK")
  frame.diamond:SetSize(6, 6)
  if frame.diamond.SetRotation then
    frame.diamond:SetRotation(math.rad(45))
  end
  frame.diamond:SetPoint("CENTER", frame.ornament, "CENTER", 0, 0)
  frame.ruleLeft = frame.ornament:CreateTexture(nil, "ARTWORK")
  frame.ruleLeft:SetHeight(1)
  frame.ruleLeft:SetPoint("LEFT", frame.ornament, "LEFT", 0, 0)
  frame.ruleLeft:SetPoint("RIGHT", frame.diamond, "LEFT", -8, 0)
  frame.ruleRight = frame.ornament:CreateTexture(nil, "ARTWORK")
  frame.ruleRight:SetHeight(1)
  frame.ruleRight:SetPoint("LEFT", frame.diamond, "RIGHT", 8, 0)
  frame.ruleRight:SetPoint("RIGHT", frame.ornament, "RIGHT", 0, 0)
  NewScroll(frame)
  Footer(frame)
  return frame
end

local function CreateB()
  local bar = Own(CreateFrame("Frame", "CodexDialogueBar", UIParent))
  local tokens = D.Tokens()
  local sub = tokens.sub or {}
  bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
  bar.fill:SetAllPoints()
  T.Gradient(bar.fill, "VERTICAL", sub.from, sub.to, sub.from[4] or 1, sub.to[4] or 1)
  for index, color in ipairs(sub.lines or {}) do
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -(index - 1))
    line:SetPoint("TOPRIGHT", 0, -(index - 1))
    Color(line, color)
  end
  UI.Shadow(bar, bar)
  bar.portrait = D.Portrait(bar, 70)
  bar.portrait:SetPoint("TOPLEFT", 18, 26)
  bar.name = Text(bar, "body", 18)
  bar.name:SetPoint("TOPLEFT", 104, -14)
  bar.name:SetWordWrap(false)
  bar.zone = Text(bar, "body", 12)
  bar.zone:SetPoint("BOTTOMLEFT", bar.name, "BOTTOMRIGHT", 10, 1)
  bar.zone:SetWordWrap(false)
  bar.close = D.CloseCross(bar, D.Palette("b"))
  bar.close:SetPoint("TOPRIGHT", -8, -8)
  bar.text = Text(bar, "body", 15)
  bar.text:SetPoint("TOPLEFT", 18, -52)
  bar.text:SetWordWrap(true)
  bar.dots = {}
  for index = 1, 8 do
    local dot = bar:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(CIRCLE)
    dot:SetSize(7, 7)
    dot:SetPoint("BOTTOMLEFT", 18 + (index - 1) * 12, 20)
    bar.dots[index] = dot
  end
  bar.hint = Text(bar, "body", 12)
  bar.hint:SetPoint("BOTTOMLEFT", 18, 17)
  bar.hint:SetWordWrap(false)
  bar.buttons = { D.Button(bar), D.Button(bar) }
  -- a click on the bar reads on
  bar:SetScript("OnMouseUp", function()
    D.NextPart()
  end)

  local side = Own(CreateFrame("Frame", "CodexDialogueSide", UIParent))
  local hud = ns.Theme().hud
  side.fill = side:CreateTexture(nil, "BACKGROUND", nil, -8)
  side.fill:SetAllPoints()
  Color(side.fill, hud.fill)
  UI.Rings(side, hud.rings)
  UI.Shadow(side, side)
  local scroll, body = UI.ScrollArea(side)
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -6, 8)
  side.scroll, side.body = scroll, body
  side.content = D.NewContent(body)
  bar.side = side
  return bar
end

local CREATE = { a = CreateA, b = CreateB, c = CreateC }

function D.Frame(style)
  if not frames[style] then
    frames[style] = CREATE[style]()
    frames[style]:SetScript("OnUpdate", function(self, elapsed)
      D.OnUpdate(self, elapsed)
    end)
  end
  return frames[style]
end

function D.WindowShown()
  for _, frame in pairs(frames) do
    if frame:IsShown() then
      return true
    end
  end
  return false
end

function D.HideWindows()
  for _, frame in pairs(frames) do
    frame:Hide()
    if frame.side then
      frame.side:Hide()
    end
  end
  D.reveal = nil
end

-- Placing -------------------------------------------------------------------------------------------------------

local function PlaceA(frame)
  frame:ClearAllPoints()
  local pos = D.DB().pos
  if type(pos) == "table" and pos[1] then
    frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
  else
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -104) -- where the game's left panels open
  end
end

-- The tallest a window's body gets before it scrolls.
local function MaxBody(reserved)
  local screen = UIParent:GetHeight()
  screen = type(screen) == "number" and screen > 200 and screen or 768
  return math.max(160, math.floor(screen * 0.78) - reserved)
end

-- Header, body and buttons for styles A and C.
local function Buttons(frame, specs, palette, y)
  local width = frame:GetWidth()
  local shown = {}
  for index, button in ipairs(frame.buttons) do
    local spec = specs[index]
    if spec then
      button:Setup(spec, palette)
      button:Show()
      shown[#shown + 1] = button
    else
      button:Hide()
    end
  end
  for _, button in ipairs(shown) do
    button:ClearAllPoints()
  end
  if #shown == 1 then
    -- one button (Goodbye): right aligned, as wide as it needs
    local w = shown[1].label:GetStringWidth()
    w = type(w) == "number" and w > 0 and w or 60
    shown[1]:SetSize(math.max(96, math.ceil(w) + 28), 26)
    shown[1]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    return 46
  elseif #shown == 2 then
    -- the board: both buttons in one row at the bottom, the main one first
    local w = math.floor((width - 28) / 2)
    shown[1]:SetSize(w, 30)
    shown[1]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    shown[2]:SetSize(w, 30)
    shown[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    return 50
  end
  return 10
end

local function Header(frame, page, palette, style)
  frame.portrait:SetUnit(page.unit)
  UI.Font(frame.name, "body", style == "c" and D.FontSize(6) or D.FontSize(3), palette.bright)
  ns.RestyleFont(frame.name, "dialogue.title") -- the NPC's name is a title too
  UI.Font(frame.zone, "body", D.FontSize(-1), palette.muted)
  D.SetText(frame.name, page.npc)
  D.SetText(frame.zone, page.zone)
  frame.close:SetPalette(palette)
end

-- Draws `page` in the chosen style. Fill functions (Gossip.lua, Quest.lua) put the blocks into the content.
function D.Render(page)
  local style = D.DB().style
  local frame = D.Frame(style)
  for other, f in pairs(frames) do
    if f ~= frame then
      f:Hide()
      if f.side then
        f.side:Hide()
      end
    end
  end
  local palette = D.Palette(style)
  D.palette, D.style = palette, style
  D.rowsShown = {}
  if style == "b" then
    D.RenderBar(frame, page, palette)
  else
    D.RenderWindow(frame, page, palette, style)
  end
  D.StartReveal(page)
  -- font strings measure 0 before they are first drawn: lay out again on the next frame
  C_Timer.After(0, function()
    if D.page == page then
      D.Relayout()
    end
  end)
end

function D.RenderWindow(frame, page, palette, style)
  local width = D.SIZES[D.DB().size] or D.SIZES.m
  frame:SetWidth(width)
  if style == "a" then
    PlaceA(frame)
  else
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 30)
  end
  Header(frame, page, palette, style)
  if style == "a" then
    Color(frame.headLine, palette.rule)
  else
    Color(frame.diamond, palette.icon)
    Color(frame.ruleLeft, palette.rule)
    Color(frame.ruleRight, palette.rule)
  end
  Color(frame.footLine, palette.rule)
  local content = frame.content
  content:Reset(width - 32 - 6, palette, style)
  D.Fill(content, page, true)
  frame.specs = D.ButtonSpecs(page)
  frame:Show()
  D.Relayout()
end

-- Heights of the window (A, C) from its content.
function D.LayoutWindow(frame)
  local style = D.style
  local top = style == "c" and 112 or 64 -- header (C: the portrait's lower half, name, zone, ornament)
  local footer = Buttons(frame, frame.specs or {}, D.palette, 0)
  local content = frame.content
  local height = content:Layout()
  frame.body:SetSize(content.width, math.max(1, height))
  local bodyHeight = math.min(height, MaxBody(top + footer + 24))
  frame.scroll:ClearAllPoints()
  frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(top + 12))
  frame.scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -(top + 12))
  frame.scroll:SetHeight(math.max(1, bodyHeight))
  frame:SetHeight(top + 12 + bodyHeight + 10 + footer)
  frame.footLine:ClearAllPoints()
  frame.footLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", style == "c" and 22 or 1, footer)
  frame.footLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", style == "c" and -22 or -1, footer)
  frame.footLine:SetShown(#(frame.specs or {}) > 0)
  if frame.scroll.Update then
    frame.scroll:Update()
  end
end

-- Style B --------------------------------------------------------------------------------------------------------

-- Splits a long text into parts of a few sentences for the subtitle bar.
function D.SplitText(text, limit)
  limit = limit or 240
  if type(text) ~= "string" or not D.Readable(text) or #text <= limit then
    return { text or "" }
  end
  local parts, current = {}, ""
  local function Push()
    if current ~= "" then
      parts[#parts + 1] = current
      current = ""
    end
  end
  for paragraph in (text .. "\n"):gmatch("([^\n]*)\n") do
    if paragraph:match("%S") then
      for sentence in (paragraph .. " "):gmatch("(.-[%.%!%?]+[\"']?)%s+") do
        if current ~= "" and #current + #sentence + 1 > limit then
          Push()
        end
        current = current == "" and sentence or (current .. " " .. sentence)
      end
      local rest = paragraph:gsub("^.*[%.%!%?][\"']?%s+", "")
      if rest ~= paragraph and rest:match("%S") then
        current = current == "" and rest or (current .. " " .. rest)
      elseif not paragraph:find("[%.%!%?]") then
        current = current == "" and paragraph or (current .. " " .. paragraph)
      end
      Push()
    end
  end
  Push()
  if #parts == 0 then
    parts[1] = text
  end
  return parts
end

function D.RenderBar(bar, page, palette)
  local width = 560
  bar:SetWidth(width)
  bar:ClearAllPoints()
  bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
  Header(bar, page, palette, "b")
  page.parts = page.parts or D.SplitText(page.text)
  page.part = page.part or 1
  UI.Font(bar.text, "body", D.FontSize(1), palette.text)
  UI.Font(bar.hint, "body", D.FontSize(-2), palette.muted)
  bar.specs = D.ButtonSpecs(page)
  local side = bar.side
  local content = side.content
  local sideWidth = D.QUEST_PAGES[page.kind] and 320 or 260
  side:SetWidth(sideWidth)
  content:Reset(sideWidth - 22, palette, "b")
  D.Fill(content, page, false)
  side:ClearAllPoints()
  side:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 34)
  bar:Show()
  side:SetShown(#content.blocks > 0)
  D.Relayout()
end

function D.LayoutBar(bar)
  local page = D.page
  if not page then
    return
  end
  local width = bar:GetWidth()
  local part = page.parts and page.parts[page.part or 1] or page.text
  D.SetText(bar.text, part)
  local textHeight = TextHeight(bar.text, width - 36, D.FontSize(1), D.Str(part))
  local count = page.parts and #page.parts or 1
  for index, dot in ipairs(bar.dots) do
    dot:SetShown(count > 1 and index <= count)
    if index == (page.part or 1) then
      dot:SetVertexColor(D.palette.head[1], D.palette.head[2], D.palette.head[3], 1)
    else
      dot:SetVertexColor(D.palette.muted[1], D.palette.muted[2], D.palette.muted[3], 0.45)
    end
  end
  bar.hint:ClearAllPoints()
  bar.hint:SetPoint("BOTTOMLEFT", 18 + (count > 1 and count * 12 + 6 or 0), 17)
  bar.hint:SetText(count > 1 and (page.part or 1) < count and L["Click the bar to read on"] or "")
  -- buttons: right aligned in the bottom row
  local shown = {}
  for index, button in ipairs(bar.buttons) do
    local spec = bar.specs and bar.specs[index]
    if spec then
      button:Setup(spec, D.palette)
      button:Show()
      shown[#shown + 1] = button
    else
      button:Hide()
    end
  end
  local x = -12
  for index = #shown, 1, -1 do
    local button = shown[index]
    local w = button.label:GetStringWidth()
    w = type(w) == "number" and w > 0 and w or 60
    button:SetSize(math.max(96, math.ceil(w) + (button.space:IsShown() and 52 or 28)), 26)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x, 10)
    x = x - button:GetWidth() - 8
  end
  bar:SetHeight(math.max(130, 52 + textHeight + 52))
  local side = bar.side
  if side:IsShown() then
    local height = side.content:Layout()
    side.body:SetSize(side.content.width, math.max(1, height))
    local bodyHeight = math.min(height, MaxBody(bar:GetHeight() + 200))
    side:SetHeight(bodyHeight + 16)
    if side.scroll.Update then
      side.scroll:Update()
    end
  end
end

-- Next part of the bar's text; true when there was one.
function D.NextPart()
  local page = D.page
  if not (page and D.style == "b" and page.parts and (page.part or 1) < #page.parts) then
    return false
  end
  page.part = (page.part or 1) + 1
  D.Relayout()
  D.StartReveal(page)
  return true
end

function D.Relayout()
  local frame = frames[D.style or ""]
  if not (frame and frame:IsShown()) then
    return
  end
  if D.style == "b" then
    D.LayoutBar(frame)
  else
    D.LayoutWindow(frame)
  end
end

-- The game's own text reveal (CVar instantQuestText "0"): the offer's text is written in at the game's speed
-- (QUEST_DESCRIPTION_GRADIENT_CPS, 70 letters a second), its objectives and rewards and the main button come after.
local REVEAL_CPS, REVEAL_LENGTH = 70, 30

function D.MainText()
  local frame = frames[D.style or ""]
  if not frame then
    return nil
  end
  if D.style == "b" then
    return frame.text
  end
  return D.mainTextBlock and D.mainTextBlock.text
end

function D.StartReveal(page)
  D.reveal = nil
  local keep = page and page.keepReveal
  page.keepReveal = nil
  if not (page and page.kind == "detail" and D.TextWrittenIn()) or (keep and keep.done) then
    D.SetRevealed(true)
    return
  end
  local text = D.MainText()
  if not (text and text.SetAlphaGradient) then
    D.SetRevealed(true)
    return
  end
  local progress = keep and keep.progress or 0
  D.reveal = { text = text, progress = progress }
  pcall(text.SetAlphaGradient, text, progress, REVEAL_LENGTH)
  D.SetRevealed(false)
end

-- Shows (or hides, while the text is written in) what comes after the text, and enables the main button.
function D.SetRevealed(on)
  D.revealed = on
  for _, block in ipairs(D.afterText or {}) do
    block:SetAlpha(on and 1 or 0)
  end
  local frame = frames[D.style or ""]
  if frame and frame.buttons and frame.specs and frame.specs[1] and frame.specs[1].primary then
    local spec = frame.specs[1]
    spec.enabled = on and spec.wanted ~= false
    frame.buttons[1]:Setup(spec, D.palette)
  end
end

function D.FinishReveal()
  if not D.reveal then
    return false
  end
  pcall(D.reveal.text.SetAlphaGradient, D.reveal.text, 1024, REVEAL_LENGTH)
  D.reveal = nil
  D.SetRevealed(true)
  return true
end

function D.OnUpdate(_, elapsed)
  local reveal = D.reveal
  if not reveal then
    return
  end
  reveal.progress = reveal.progress + (elapsed or 0) * REVEAL_CPS
  local ok, going = pcall(reveal.text.SetAlphaGradient, reveal.text, reveal.progress, REVEAL_LENGTH)
  if not ok or not going then
    D.reveal = nil
    D.SetRevealed(true)
  end
end

-- Space on a long text: scroll down first (A and C), then act.
function D.ScrollOn()
  local frame = frames[D.style or ""]
  local scroll = frame and (frame.scroll or (frame.side and frame.side.scroll))
  if not (scroll and frame:IsShown()) then
    return false
  end
  local view = scroll:GetHeight() or 0
  local full = scroll.body and scroll.body:GetHeight() or 0
  local offset = scroll:GetVerticalScroll() or 0
  if type(view) ~= "number" or type(full) ~= "number" or full - view - offset <= 4 then
    return false
  end
  scroll:SetVerticalScroll(math.min(full - view, offset + view * 0.8))
  if scroll.Update then
    scroll:Update()
  end
  return true
end
