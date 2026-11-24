local addonName, ns = ...

-- The Quest windows page (board R4-Options, the "Quest and gossip windows" card): the switch, three style cards with
-- a small picture each (the theme's own colours), then two columns: Text (levels, written-in text = the game's
-- Instant Quest Text, font size, window size, Stat Delta on rewards) and While talking (keys, the only service,
-- fading, auto accept and hand-in). Changes work at once.

local D = ns.dialogue
local UI = ns.UI
local T = ns.T
local view = { checks = {} }

local TEXT_OPTIONS = {
  { key = "levels", name = "Show quest levels", desc = "[48] before each quest name, in its difficulty colour." },
  { key = "reveal", name = "Write the text in as the game does",
    desc = "Off shows the whole text at once (the game's Instant Quest Text)." },
}
local TEXT_OPTIONS_AFTER = {
  { key = "statArrows", name = "Stat Delta on rewards",
    desc = "Stat changes and the upgrade arrow on reward items, while the Stat Delta module is on." },
}
local TALK_OPTIONS = {
  { key = "numbers", name = "Number keys pick choices",
    desc = "1 to 9 pick the rows in order, shown as small keys beside them. Space still accepts (Quest keys)." },
  { key = "escapeBack", name = "Escape goes back to the list",
    desc = "On a quest you opened from an NPC's list, Escape takes you back to the list instead of closing." },
  { key = "tabRewards", name = "Tab picks the next reward", desc = "When a quest lets you choose a reward." },
  { key = "service", name = "Open the only service at once",
    desc = "A banker, vendor, trainer or flight master with nothing else to say opens at once." },
  { key = "fade", name = "Fade the game's interface",
    desc = "Styles B and C: bars, frames and chat fade out and come back when you walk away; never in a fight." },
  { key = "autoAccept", name = "Accept quests by themselves",
    desc = "Not repeatable or grey (low level) quests, and not quests that ask first." },
  { key = "autoTurnIn", name = "Hand in quests by themselves",
    desc = "Not repeatables, quests that take gold or marks, or when a reward must be chosen." },
}

local function Wrap(text, width)
  text:SetJustifyH("LEFT")
  text:SetWidth(width)
  return text
end

local function Color(texture, color, alpha)
  texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function Box(parent, x, y, w, h, color, layer)
  local texture = parent:CreateTexture(nil, layer or "ARTWORK")
  texture:SetPoint("TOPLEFT", x, -y)
  texture:SetSize(w, h)
  Color(texture, color)
  return texture
end

-- The little scene of each style: a painted evening meadow and an NPC with a quest mark (Media/PreviewScene.tga,
-- PreviewNpc.tga, branding/source/dialogue-art.py), and over it the style's window in the theme's own colours with a
-- round portrait, the name, text lines, choice rows with their number keys and the main button. They replaced flat
-- boxes (the user's screenshot of these cards, 2026-11-21).
local MEDIA = "Interface\\AddOns\\Codex\\Modules\\Dialogue\\Media\\"
local CIRCLE = "Interface\\AddOns\\Codex\\Media\\Circle"
local PORTRAIT = { 0.55, 0.40, 0.27 }

local function Disc(parent, x, y, size, color, layer)
  local texture = parent:CreateTexture(nil, layer or "OVERLAY")
  texture:SetTexture(CIRCLE)
  texture:SetPoint("TOPLEFT", x, -y)
  texture:SetSize(size, size)
  texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  return texture
end

-- A round portrait with a ring in `ring`.
local function Portrait(parent, x, y, size, ring)
  Disc(parent, x - 1, y - 1, size + 2, ring, "OVERLAY")
  local face = Disc(parent, x, y, size, PORTRAIT, "OVERLAY")
  face:SetDrawLayer("OVERLAY", 2)
end

-- A choice row: a small key, a quest mark and a line of text.
local function Choice(parent, x, y, width, key, mark, text)
  Box(parent, x, y, 6, 6, key.line, "OVERLAY")
  Box(parent, x + 1, y + 1, 4, 4, { key.fill[1], key.fill[2], key.fill[3], math.max(0.6, key.fill[4] or 1) }, "OVERLAY")
  Box(parent, x + 9, y, 2, 6, mark, "OVERLAY")
  Box(parent, x + 14, y + 2, width - 14, 2, text, "OVERLAY")
end

local function Lines(parent, x, y, widths, color, gap)
  for index, width in ipairs(widths) do
    Box(parent, x, y + (index - 1) * (gap or 5), width, 2, color, "OVERLAY")
  end
end

local function DrawPreview(frame, key, w, h)
  local theme, tokens = ns.Theme(), D.Tokens()
  -- the scene, cropped round the horizon to the picture's shape
  local scene = frame:CreateTexture(nil, "BACKGROUND")
  scene:SetAllPoints()
  scene:SetTexture(MEDIA .. "PreviewScene")
  local aspect = w / h
  if aspect >= 2 then
    local part = 2 / aspect
    local top = math.max(0, 0.6 - part * 0.6)
    scene:SetTexCoord(0, 1, top, top + part)
  else
    local part = aspect / 2
    scene:SetTexCoord(0.5 - part / 2, 0.5 + part / 2, 0, 1)
  end
  local npcHeight = h - 12
  local npcX = key == "a" and w - 52 or (key == "b" and math.floor(w * 0.34) or 26)
  local npc = frame:CreateTexture(nil, "ARTWORK")
  npc:SetTexture(MEDIA .. "PreviewNpc")
  npc:SetPoint("TOPLEFT", npcX, -4)
  npc:SetSize(math.floor(npcHeight / 2), npcHeight)

  local text, bright, accent = theme.text, theme.bright, theme.accent
  local soft = { text[1], text[2], text[3], 0.55 }
  local keyLook = tokens.key or { fill = { 1, 1, 1, 0.07 }, line = theme.muted }
  if key == "a" then
    local pw = math.min(112, math.floor(w * 0.56))
    local panel = Box(frame, 8, 8, pw, h - 16, theme.panel.to)
    T.Gradient(panel, "VERTICAL", theme.panel.from, theme.panel.to, 0.97, 0.97)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", 8, -8)
    holder:SetSize(pw, h - 16)
    UI.Rings(holder, theme.rings)
    Portrait(frame, 15, 14, 14, accent)
    Box(frame, 34, 16, math.floor(pw * 0.42), 4, bright, "OVERLAY")
    Box(frame, 34, 23, math.floor(pw * 0.26), 2, theme.muted, "OVERLAY")
    Lines(frame, 15, 35, { pw - 16, pw - 26, pw - 36 }, soft)
    Choice(frame, 15, 53, pw - 30, keyLook, D.MARK.gold, { text[1], text[2], text[3], 0.85 })
    Choice(frame, 15, 62, pw - 40, keyLook, D.MARK.blue, { text[1], text[2], text[3], 0.85 })
    local button = Box(frame, 8 + pw - 34, h - 20, 26, 7, theme.button.to, "OVERLAY")
    T.Gradient(button, "VERTICAL", theme.button.from, theme.button.to, 1, 1)
    Box(frame, 8 + pw - 34, h - 14, 26, 1, accent, "OVERLAY")
  elseif key == "b" then
    local sub = tokens.sub
    local x0, bw = math.floor(w * 0.10), math.floor(w * 0.80)
    local bar = Box(frame, x0, h - 28, bw, 24, sub.to)
    T.Gradient(bar, "VERTICAL", sub.from, sub.to, sub.from[4] or 1, sub.to[4] or 1)
    Box(frame, x0, h - 28, bw, 1, sub.lines and sub.lines[1] or accent, "OVERLAY")
    Portrait(frame, x0 - 4, h - 38, 20, accent)
    Box(frame, x0 + 22, h - 23, math.floor(bw * 0.22), 3, accent, "OVERLAY")
    Lines(frame, x0 + 22, h - 16, { math.floor(bw * 0.66), math.floor(bw * 0.5) }, soft)
    -- the choices beside the NPC
    local cw, cx = 64, math.max(x0, w - 78)
    Box(frame, cx, 12, cw, 26, theme.hud.fill)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", cx, -12)
    holder:SetSize(cw, 26)
    UI.Rings(holder, theme.hud.rings)
    Choice(frame, cx + 5, 17, cw - 12, keyLook, D.MARK.gold, { text[1], text[2], text[3], 0.85 })
    Choice(frame, cx + 5, 27, cw - 20, keyLook, D.MARK.grey, { text[1], text[2], text[3], 0.85 })
  else
    local page, ink = tokens.page, tokens.ink
    local pw = math.min(84, math.floor(w * 0.44))
    local px = w - pw - 10
    local paper = Box(frame, px, 12, pw, h - 12, page.to)
    T.Gradient(paper, "VERTICAL", page.from, page.to, 1, 1)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", px, -12)
    holder:SetSize(pw, h - 12)
    local line = page.lines and page.lines[1] or tokens.inkHead
    T.ColorLines(T.Outline(holder, 0, line, 1, "OVERLAY"), line, line[4])
    Portrait(frame, px + math.floor(pw / 2) - 8, 4, 16, line)
    local inkColor = { ink[1], ink[2], ink[3], 0.85 }
    Box(frame, px + 10, 26, math.floor(pw * 0.55), 3, inkColor, "OVERLAY")
    Lines(frame, px + 8, 35, { pw - 16, pw - 20, pw - 28 }, { ink[1], ink[2], ink[3], 0.45 })
    Choice(frame, px + 8, 56, pw - 22, keyLook, D.InkTable("inkMark", D.MARK_INK).gold, inkColor)
    Choice(frame, px + 8, 66, pw - 28, keyLook, D.InkTable("inkMark", D.MARK_INK).blue, inkColor)
  end
end

-- Three style cards side by side (one under the other on a narrow page). Fit(width) places them and returns the
-- height; the little pictures are drawn again when the card width changes.
local function StyleCards(parent)
  local gap = 14
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(300, 160)
  holder.cards = {}
  local theme, tokens = ns.Theme(), D.Tokens()
  for index, style in ipairs(D.STYLES) do
    local card = CreateFrame("Button", nil, holder)
    card.back = card:CreateTexture(nil, "BACKGROUND")
    card.back:SetAllPoints()
    card.lines = T.Outline(card, 0, tokens.rule, 1, "BORDER")
    card.dot = card:CreateTexture(nil, "ARTWORK")
    card.dot:SetTexture("Interface\\AddOns\\Codex\\Media\\Circle")
    card.dot:SetSize(14, 14)
    card.name = UI.Text(card, "body", 14, "bright")
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(true)
    card.name.lineHeight = 18
    card.name:SetText(style.name)
    card.desc = UI.Text(card, "body", 12, "muted")
    card.desc:SetJustifyH("LEFT")
    card.desc:SetWordWrap(true)
    card.desc.lineHeight = 16
    card.desc:SetText(style.desc)
    card.key = style.key
    card:SetScript("OnClick", function(self)
      D.Set("style", self.key)
    end)
    holder.cards[index] = card
  end
  function holder:Fit(width)
    local stacked = width < 420
    local w = stacked and width or math.floor((width - gap * 2) / 3)
    local heights = {}
    for index, card in ipairs(self.cards) do
      if card.previewWidth ~= w then
        if card.preview then
          card.preview:Hide()
        end
        card.preview = CreateFrame("Frame", nil, card)
        card.preview:SetPoint("TOPLEFT", 7, -7)
        card.preview:SetSize(w - 14, 92)
        DrawPreview(card.preview, card.key, w - 14, 92)
        card.previewWidth = w
      end
      card.dot:ClearAllPoints()
      card.dot:SetPoint("TOPLEFT", 7, -(7 + 92 + 10))
      card.name:ClearAllPoints()
      card.name:SetPoint("TOPLEFT", 29, -(7 + 92 + 8))
      card.name:SetWidth(w - 36)
      local nameHeight = D.PageTextHeight(card.name)
      card.desc:ClearAllPoints()
      card.desc:SetPoint("TOPLEFT", 29, -(7 + 92 + 8 + nameHeight + 3))
      card.desc:SetWidth(w - 36)
      heights[index] = 7 + 92 + 8 + nameHeight + 3 + D.PageTextHeight(card.desc) + 10
    end
    local tallest = 0
    for _, h in ipairs(heights) do
      tallest = math.max(tallest, h)
    end
    local y = 0
    for index, card in ipairs(self.cards) do
      card:ClearAllPoints()
      if stacked then
        card:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        card:SetSize(w, heights[index])
        y = y + heights[index] + 8
      else
        card:SetPoint("TOPLEFT", self, "TOPLEFT", (index - 1) * (w + gap), 0)
        card:SetSize(w, tallest)
      end
    end
    local height = stacked and (y - 8) or tallest
    self:SetSize(width, height)
    self.cardWidth = w
    return height
  end
  function holder:Refresh()
    local current = D.DB().style
    for _, card in ipairs(self.cards) do
      local on = card.key == current
      if on then
        Color(card.back, theme.select.from)
        T.ColorLines(card.lines, tokens.selLine, 1)
        card.dot:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        card.name:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
      else
        card.back:SetColorTexture(0, 0, 0, 0)
        T.ColorLines(card.lines, tokens.rule, tokens.rule[4])
        card.dot:SetVertexColor(theme.muted[1], theme.muted[2], theme.muted[3], 0.5)
        card.name:SetTextColor(theme.bright[1], theme.bright[2], theme.bright[3], 1)
      end
    end
  end
  return holder
end

-- Layout ---------------------------------------------------------------------------------------------------------
-- Everything sits in a scroll area and is stacked by measured heights (as on the Info bars page): every text is bound
-- to its own column's width and wraps in it; a text measures 0 until it is first drawn, so the page lays itself out
-- again when shown and on the next frame. Two columns 30 px apart, one under the other when the page is narrow.
-- Notes go on their own line under their control, never beside it.

local NARROW = 620
local COLUMN_GAP = 30
local PAD = 14 -- inside the card
local INDENT = 28 -- the card's content under the big switch
local CHECK_TEXT = 26 -- a check's label and note start this far right of the box

local function Num(value)
  return type(value) == "number" and D.Readable(value) and value or nil
end

-- A font string's height at its width; before it is drawn (or in tests) worked out from its text's length.
function D.PageTextHeight(text)
  if not text:IsShown() then
    return 0
  end
  local raw = text:GetText()
  if type(raw) ~= "string" or (D.Readable(raw) and raw == "") then
    return 0
  end
  local height = Num(text:GetStringHeight())
  if height and height > 0 then
    return math.ceil(height)
  end
  local width = Num(text:GetWidth()) or 0
  local lines = width > 0 and math.max(1, math.ceil((Num(text:GetStringWidth()) or 0) / width)) or 1
  return lines * (text.lineHeight or 16)
end

local function Item(kind, region, gap, indent, height)
  return { kind = kind, region = region, gap = gap or 8, indent = indent or 0, height = height }
end

local function Text(parent, size, color)
  local text = UI.Text(parent, "body", size, color)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  text.lineHeight = size + 4
  return text
end

-- Places `items` on `parent` from (x, y) in a column `width` wide; `top` = the parent's y on the body (for the
-- record of what sits where, view.placed). Returns the y under the last one.
local function Stack(items, parent, x, y, width, top)
  local last
  for _, item in ipairs(items) do
    local region = item.region
    local shown = not region.IsShown or region:IsShown()
    local w = width - item.indent
    local height = 0
    if shown then
      if item.kind == "text" then
        region:SetWidth(w)
        height = D.PageTextHeight(region)
      elseif item.kind == "check" then
        -- the label wraps beside the box: it gets the rest of the column
        local label = region.label
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", region, "TOPLEFT", CHECK_TEXT, -3)
        label:SetWidth(w - CHECK_TEXT)
        label:SetWordWrap(true)
        region:SetHitRectInsets(0, -(w - 20), 0, 0)
        height = math.max(20, D.PageTextHeight(label) + 3)
      elseif region.Fit then
        height = region:Fit(w) or item.height or 24
      else
        height = item.height or 24
      end
    end
    if shown and height > 0 then
      region:ClearAllPoints()
      region:SetPoint("TOPLEFT", parent, "TOPLEFT", x + item.indent, -y)
      view.placed[#view.placed + 1] = { region = region, kind = item.kind, x = x + item.indent, y = top + y,
        width = w, height = height }
      y = y + height + item.gap
      last = item
    end
  end
  return last and (y - last.gap) or y
end

function D.LayoutPage()
  local body = view.body
  if not body then
    return
  end
  local width = math.floor((Num(view.scroll:GetWidth()) or 0) - 12)
  if width < 200 then
    width = (ns.PAGE_WIDTH or 672) - 12
  end
  body:SetWidth(width)
  view.placed = {}
  local narrow = width < NARROW
  view.narrow = narrow

  local y = Stack(view.header, body, 0, 0, width, 0)
  local cardY = y + 10
  local inner = width - PAD * 2
  local cy = Stack(view.top, view.card, PAD, PAD, inner, cardY)
  local columns = inner - INDENT
  local column = narrow and columns or math.floor((columns - COLUMN_GAP) / 2)
  view.columnWidth = column
  local x = PAD + INDENT
  local leftEnd = Stack(view.left, view.card, x, cy + 16, column, cardY)
  local rightEnd
  if narrow then
    rightEnd = Stack(view.right, view.card, x, leftEnd + 16, column, cardY)
  else
    rightEnd = Stack(view.right, view.card, x + column + COLUMN_GAP, cy + 16, column, cardY)
  end
  local cardHeight = math.max(leftEnd, rightEnd) + PAD
  view.card:ClearAllPoints()
  view.card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -cardY)
  view.card:SetSize(width, cardHeight)
  view.cardY, view.cardHeight = cardY, cardHeight
  body:SetHeight(cardY + cardHeight + 16)
  if view.scroll.Update then
    view.scroll:Update()
  end
end

-- Page widgets -----------------------------------------------------------------------------------------------------

-- A check with its plain note under it (two items of a column).
local function Option(parent, option, items)
  local check = UI.Check(parent, option.name)
  check.label:SetTextColor(UI.Unpack(ns.Theme().bright))
  check.label:SetJustifyH("LEFT")
  check.label.lineHeight = 16
  check.key = option.key
  check:SetScript("OnClick", function(self)
    if self.key == "reveal" then
      D.SetTextWrittenIn(self:GetChecked())
    else
      D.Set(self.key, self:GetChecked() and true or false)
    end
  end)
  view.checks[#view.checks + 1] = check
  local desc = Text(parent, 12, "muted")
  desc:SetText(option.desc)
  items[#items + 1] = Item("check", check, 1)
  items[#items + 1] = Item("text", desc, 10, CHECK_TEXT)
end

local LABEL_WIDTH = 100

-- "Font size  - 14 +" on one line; its note goes on its own line under it.
local function FontRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.label = UI.Text(row, "body", 14, "bright")
  row.label:SetPoint("LEFT")
  row.label:SetWordWrap(false)
  row.label:SetText("Font size")
  row.stepper = UI.Stepper(row, 34)
  row.stepper:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
  row.stepper.less:SetScript("OnClick", function()
    D.Set("fontSize", math.max(11, D.DB().fontSize - 1))
  end)
  row.stepper.more:SetScript("OnClick", function()
    D.Set("fontSize", math.min(20, D.DB().fontSize + 1))
  end)
  function row:Fit(width)
    self:SetSize(width, 24)
    self.label:SetWidth(LABEL_WIDTH - 6)
    return 24
  end
  return row
end

local SIZE_NAMES = { s = "Small", m = "Medium", l = "Large" }

-- "Window size  [Medium]": a picker (its menu lists the three) that fits the column; its note under it.
local function SizeRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row.label = UI.Text(row, "body", 14, "bright")
  row.label:SetPoint("LEFT")
  row.label:SetWordWrap(false)
  row.label:SetText("Window size")
  row.picker = UI.Picker(row, 140, 24)
  row.picker:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
  row.picker:SetScript("OnClick", function(self)
    local items = {}
    for _, key in ipairs({ "s", "m", "l" }) do
      items[#items + 1] = { text = SIZE_NAMES[key], checked = D.DB().size == key, func = function()
        D.Set("size", key)
      end }
    end
    UI.ShowMenu(self, items)
  end)
  function row:Fit(width)
    self:SetSize(width, 24)
    self.label:SetWidth(LABEL_WIDTH - 6)
    self.picker:SetWidth(math.max(80, math.min(160, width - LABEL_WIDTH)))
    return 24
  end
  function row:Refresh()
    self.picker:SetText(SIZE_NAMES[D.DB().size] or SIZE_NAMES.m)
  end
  return row
end

function D.RefreshPage()
  if not view.page then
    return
  end
  local db = D.DB()
  view.status:SetText(D.StatusText())
  view.windows:SetChecked(db.windows)
  for _, check in ipairs(view.checks) do
    if check.key == "reveal" then
      check:SetChecked(D.TextWrittenIn())
    else
      check:SetChecked(db[check.key] and true or false)
    end
  end
  view.styles:Refresh()
  view.styles:SetAlpha(db.windows and 1 or 0.45)
  view.fontRow.stepper.value:SetText(tostring(db.fontSize))
  view.sizeRow:Refresh()
  local note = ""
  if ns.IsAddOnLoaded and ns.IsAddOnLoaded("DialogueUI") then
    note = ns.ModuleState("dialogue") == "standalone"
      and "DialogueUI is loaded, so Codex leaves the NPC windows to it (the switch at the top of this section can use Codex's instead)."
      or "DialogueUI is loaded too: both want to draw the NPC windows. Turn one of them off."
  elseif not D.running then
    note = "Quest windows are off: switch them on at the top of this section (then reload)."
  end
  view.note:SetText(note)
  view.note:SetShown(note ~= "")
  D.LayoutPage()
end

function D.BuildPage(page)
  D.DB()
  view.page = page
  view.checks = {}
  local scroll, body = UI.ScrollArea(page)
  scroll:SetPoint("TOPLEFT")
  scroll:SetPoint("BOTTOMRIGHT")
  body:SetWidth((ns.PAGE_WIDTH or 672) - 12)
  view.scroll, view.body = scroll, body
  D.pageView = view

  -- header: name, live status, a note when DialogueUI is there or the module is off
  local heading = UI.Heading(body, "Quest windows", 20)
  heading:SetWordWrap(false)
  heading.lineHeight = 24
  view.status = Text(body, 12, "muted")
  view.note = Text(body, 12, "warn")
  view.header = { Item("text", heading, 4), Item("text", view.status, 6), Item("text", view.note, 6) }

  -- the card (its texts on the card's own frame, above its fill)
  local card = UI.Inset(body)
  view.card = card
  view.windows = UI.Check(card, "Quest and gossip windows")
  UI.Font(view.windows.label, "body", 16, "bright")
  view.windows.label.lineHeight = 20
  view.windows:SetScript("OnClick", function(self)
    D.Set("windows", self:GetChecked() and true or false)
  end)
  local about = Text(card, 12, "muted")
  about:SetText("Codex draws the windows you get when you talk to an NPC: greeting, quests, rewards. Off keeps the "
    .. "game's own windows (the quest options below still work).")
  view.styles = StyleCards(card)
  view.top = { Item("check", view.windows, 1), Item("text", about, 12, INDENT), Item("row", view.styles, 0, INDENT) }

  -- left column: Text
  local left = {}
  local leftHead = UI.Text(card, "head", 12, "accent")
  leftHead:SetWordWrap(false)
  leftHead:SetText("Text")
  left[#left + 1] = Item("text", leftHead, 8)
  for _, option in ipairs(TEXT_OPTIONS) do
    Option(card, option, left)
  end
  view.fontRow = FontRow(card)
  left[#left + 1] = Item("row", view.fontRow, 3)
  local fontNote = Text(card, 12, "muted")
  fontNote:SetText("The game's own is 13.")
  left[#left + 1] = Item("text", fontNote, 12)
  view.sizeRow = SizeRow(card)
  left[#left + 1] = Item("row", view.sizeRow, 3)
  local sizeNote = Text(card, 12, "muted")
  sizeNote:SetText("Styles A and C; the subtitle bar keeps its own width.")
  left[#left + 1] = Item("text", sizeNote, 12)
  for _, option in ipairs(TEXT_OPTIONS_AFTER) do
    Option(card, option, left)
  end
  view.left = left

  -- right column: While talking
  local right = {}
  local rightHead = UI.Text(card, "head", 12, "accent")
  rightHead:SetWordWrap(false)
  rightHead:SetText("While talking")
  right[#right + 1] = Item("text", rightHead, 8)
  for _, option in ipairs(TALK_OPTIONS) do
    Option(card, option, right)
  end
  local shift = Text(card, 12, "text")
  shift:SetText("Hold Shift while you talk to an NPC to talk normally: nothing is accepted, handed in or opened by itself.")
  right[#right + 1] = Item("text", shift, 0)
  view.right = right

  page:HookScript("OnShow", function()
    D.LayoutPage()
    C_Timer.After(0, D.LayoutPage)
  end)
  D.RefreshPage()
  C_Timer.After(0, D.LayoutPage)
end
