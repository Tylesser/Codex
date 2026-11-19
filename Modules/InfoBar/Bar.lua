local addonName, ns = ...

-- Info bars, part 2: the frames (board R3-InfoBars).
--   Screen bar: a slim 24-unit strip along the top (or bottom) edge: the Codex emblem, two slots on the left,
--   one stretching in the middle (centred text), four on the right. Each slot is as wide as its text.
--   Chat panel: a 24-unit strip under the chat window with four equal slots between a hide-chat and a
--   copy-chat button (Chat.lua).
-- Left-click a slot: its window (bags, map, ...); right-click: "Show in this slot". Tooltips are Codex's own
-- (themed, with bars), built only while shown. Updates: each shown data text's events; a 1 s ticker only while
-- a clock, frame rate or location text is shown. Both bars sit on the BACKGROUND strata, so a Blizzard frame
-- that overlaps them (minimap, buffs, micro menu) draws on top. The bar is full width; the Blizzard frames whose
-- edge sits in its strip are moved out of it ("Make room", default on, the user's choice 2026-11-17): shifted by
-- the bar's height plus a gap through the engine's own SetPointBase (Edit Mode's override would taint), out of
-- combat only, and again whenever Edit Mode puts them back (ApplySystemAnchor post-hook, EDIT_MODE_LAYOUTS_UPDATED).
-- Only a frame whose edge is inside the strip is touched, so a frame the player moved elsewhere in Edit Mode is
-- left alone. "Put them back" restores the points remembered before the shift. Nothing is saved through
-- C_EditMode (SaveLayouts crashes the client), so the shift repeats at every login.
-- As an option (off) the bar can instead fit itself beside those frames: it measures them and takes the widest
-- free run, goes to the bottom when the top leaves under 360, and drops the least needed slots first.

local I = ns.infobar
local UI = ns.UI
local T = ns.T

local MEDIA = "Interface\\AddOns\\Codex\\Modules\\InfoBar\\Media\\"
local CODEX_MEDIA = "Interface\\AddOns\\Codex\\Media\\"
local HEIGHT = 24
local CORNER = 28 -- the panel's two corner buttons
local PANEL_PAD = 8 -- a panel slot's inner padding (icon and text start this far from the divider)

I.slots = {} -- [key] = slot button
local frames = {} -- top, panel

-- The bars sit over the game world and show the game's colours (class names, coin colours): the surfaces of the
-- game's interface (ns.InkTheme, the light-theme rule in Theme.lua: light on Dawn, game colours darkened).
local function Theme()
  return ns.InkTheme and ns.InkTheme() or ns.Theme()
end

local function Num(value)
  return I.Num(value)
end

-- Backgrounds ----------------------------------------------------------------------------------------------------

-- The theme's window fill (wood tile included), a little see-through, as on the board's infoBar token.
local function BarFill(frame)
  local panel = Theme().panel
  local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints()
  T.Gradient(fill, "VERTICAL", panel.from, panel.to, 0.94, 0.94)
  if panel.tile then
    local tile = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    tile:SetAllPoints()
    tile:SetTexture(panel.tile, "REPEAT", "REPEAT")
    if tile.SetHorizTile then
      tile:SetHorizTile(true)
      tile:SetVertTile(true)
    end
    tile:SetAlpha(panel.tileAlpha or 1)
    if panel.blend then
      tile:SetBlendMode(panel.blend)
    end
  end
  return fill
end

-- The theme's border lines, one per ring, along the edge that faces the screen (infoLine / infoLineTop).
local function EdgeLines(frame)
  local lines = {}
  for index, ring in ipairs(Theme().rings or {}) do
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetHeight(ring.size or 1)
    UI.SetColor(line, ring.color)
    lines[index] = line
  end
  frame.edgeLines = lines
end

local function PlaceEdgeLines(frame, atBottom)
  local offset = 0
  for _, line in ipairs(frame.edgeLines or {}) do
    line:ClearAllPoints()
    if atBottom then
      line:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -offset)
      line:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -offset)
    else
      line:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, offset)
      line:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, offset)
    end
    offset = offset + (line:GetHeight() or 1)
  end
end

-- Tooltip ----------------------------------------------------------------------------------------------------------

local tip
local PAD = 12

local function TipElement(kind, build)
  local pool = tip.pools[kind]
  tip.used[kind] = (tip.used[kind] or 0) + 1
  local element = pool[tip.used[kind]]
  if not element then
    element = build()
    pool[#pool + 1] = element
  end
  return element
end

local function Place(region, y, height)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, -y)
  region:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -PAD, -y)
  region:SetHeight(height)
end

-- The track of a thin bar in the tooltip: dark on a dark theme, the theme's see-through slot on a light one.
local function Track()
  local theme = Theme()
  if theme.light and theme.slot and theme.slot.fill then
    return theme.slot.fill
  end
  return { 0.04, 0.03, 0.05, 0.85 }
end

-- A theme key or a game colour (class colours, durability) for a text on the tooltip panel: on a light theme
-- (Dawn) a game colour comes back in a shade that reads there (ns.GameColor; theme keys read already).
local function ColorOf(color)
  if type(color) == "string" then
    return Theme()[color] or Theme().text
  end
  if type(color) == "table" and ns.GameColor then
    return ns.GameColor(color, Theme())
  end
  return color or Theme().text
end

local TipMethods = {}

function TipMethods:Title(text, note, noteColor)
  self.title:SetText(text or "")
  self.titleNote:SetText(note or "")
  self.titleNote:SetTextColor(UI.Unpack(ColorOf(noteColor or "muted")))
  self.need = math.max(self.need, (self.title:GetStringWidth() or 0) + 16 + (self.titleNote:GetStringWidth() or 0))
  self.y = PAD - 2 + 16 + 6
end

-- One row: left text, right text (optional), a small colour square before the left text (false = its space only).
function TipMethods:Line(left, right, leftColor, rightColor, swatch)
  local row = TipElement("line", function()
    local frame = CreateFrame("Frame", nil, tip)
    frame.left = UI.Text(frame, "body", 13, "text")
    frame.right = UI.Text(frame, "body", 13, "bright")
    frame.right:SetPoint("RIGHT")
    frame.right:SetJustifyH("RIGHT")
    frame.edge = frame:CreateTexture(nil, "ARTWORK")
    frame.edge:SetSize(10, 10)
    frame.edge:SetPoint("LEFT", 0, 0)
    UI.SetColor(frame.edge, { 0, 0, 0, 1 })
    frame.swatch = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.swatch:SetSize(8, 8)
    frame.swatch:SetPoint("CENTER", frame.edge, "CENTER")
    return frame
  end)
  Place(row, self.y, 19)
  row:Show()
  local indent = swatch ~= nil and 15 or 0
  row.edge:SetShown(type(swatch) == "table")
  row.swatch:SetShown(type(swatch) == "table")
  if type(swatch) == "table" then
    UI.SetColor(row.swatch, swatch)
  end
  row.left:ClearAllPoints()
  row.left:SetPoint("LEFT", indent, 0)
  row.left:SetText(left or "")
  row.left:SetTextColor(UI.Unpack(ColorOf(leftColor)))
  row.right:SetText(right or "")
  row.right:SetTextColor(UI.Unpack(ColorOf(rightColor or "bright")))
  self.need = math.max(self.need, indent + (row.left:GetStringWidth() or 0) + 16 + (row.right:GetStringWidth() or 0))
  self.y = self.y + 19
end

-- A row with a thin bar: label, bar filled to fraction (0-1), right text (durability per slot).
function TipMethods:Bar(label, fraction, color, right)
  local row = TipElement("bar", function()
    local frame = CreateFrame("Frame", nil, tip)
    frame.left = UI.Text(frame, "body", 12, "text")
    frame.left:SetPoint("LEFT")
    frame.left:SetWidth(84)
    frame.left:SetWordWrap(false)
    frame.right = UI.Text(frame, "body", 12, "bright")
    frame.right:SetPoint("RIGHT")
    frame.right:SetWidth(40)
    frame.right:SetJustifyH("RIGHT")
    frame.back = frame:CreateTexture(nil, "ARTWORK")
    frame.back:SetHeight(5)
    frame.back:SetPoint("LEFT", 92, 0)
    frame.back:SetPoint("RIGHT", -48, 0)
    UI.SetColor(frame.back, Track())
    frame.line = T.Outline(frame, 0, { 0, 0, 0 }, 1, "ARTWORK", -1)
    for _, line in ipairs(frame.line) do
      line:ClearAllPoints()
    end
    frame.line[1]:SetPoint("BOTTOMLEFT", frame.back, "TOPLEFT", -1, 0)
    frame.line[1]:SetPoint("BOTTOMRIGHT", frame.back, "TOPRIGHT", 1, 0)
    frame.line[2]:SetPoint("TOPLEFT", frame.back, "BOTTOMLEFT", -1, 0)
    frame.line[2]:SetPoint("TOPRIGHT", frame.back, "BOTTOMRIGHT", 1, 0)
    frame.line[3]:SetPoint("TOPRIGHT", frame.back, "TOPLEFT", 0, 0)
    frame.line[3]:SetPoint("BOTTOMRIGHT", frame.back, "BOTTOMLEFT", 0, 0)
    frame.line[4]:SetPoint("TOPLEFT", frame.back, "TOPRIGHT", 0, 0)
    frame.line[4]:SetPoint("BOTTOMLEFT", frame.back, "BOTTOMRIGHT", 0, 0)
    frame.fill = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.fill:SetPoint("TOPLEFT", frame.back)
    frame.fill:SetPoint("BOTTOMLEFT", frame.back)
    return frame
  end)
  Place(row, self.y, 17)
  row:Show()
  row.left:SetText(label or "")
  row.right:SetText(right or "")
  local rgb = ColorOf(color)
  row.right:SetTextColor(UI.Unpack(rgb))
  UI.SetColor(row.fill, rgb)
  row.fraction = math.max(0, math.min(1, fraction or 0))
  self.bars[#self.bars + 1] = row
  self.need = math.max(self.need, 220)
  self.y = self.y + 17
end

function TipMethods:Rule()
  local line = TipElement("rule", function()
    local texture = tip:CreateTexture(nil, "ARTWORK")
    UI.SetColor(texture, Theme().divider)
    return texture
  end)
  Place(line, self.y + 6, 1)
  line:Show()
  self.y = self.y + 13
end

-- A muted closing line ("Click to open your bags.").
function TipMethods:Note(text)
  local note = TipElement("note", function()
    return UI.Text(tip, "body", 12, "muted")
  end)
  Place(note, self.y + 6, 14)
  note:Show()
  note:SetText(text or "")
  self.need = math.max(self.need, note:GetStringWidth() or 0)
  self.y = self.y + 20
end

-- The experience bar: earned (purple), then rested (blue) and quest XP waiting (gold) after it.
function TipMethods:XPBar(earned, rested, quest)
  local bar = TipElement("xp", function()
    local frame = CreateFrame("Frame", nil, tip)
    local back = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    back:SetAllPoints()
    UI.SetColor(back, Track())
    UI.Rings(frame, { { inset = 0, color = { 0, 0, 0 }, size = 1 } }, "OVERLAY")
    frame.rested = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    UI.SetColor(frame.rested, { 0.35, 0.59, 1, 0.35 })
    frame.quest = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    UI.SetColor(frame.quest, { 1, 0.82, 0, 0.45 })
    frame.earned = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    T.Gradient(frame.earned, "VERTICAL", { 0.31, 0.24, 0.38 }, { 0.49, 0.39, 0.59 })
    return frame
  end)
  Place(bar, self.y, 10)
  bar:Show()
  bar.parts = { earned = earned or 0, rested = rested or 0, quest = quest or 0 }
  self.xpBar = bar
  self.need = math.max(self.need, 238)
  self.y = self.y + 17
end

-- Bars need the final width: fills are sized once the tooltip's width is known.
local function SizeBars(self, width)
  local inner = width - 2 * PAD
  for _, row in ipairs(self.bars) do
    local span = inner - 92 - 48
    row.fill:SetWidth(math.max(0.01, span * row.fraction))
    row.fill:SetShown(row.fraction > 0)
  end
  local bar = self.xpBar
  if bar then
    local parts = bar.parts
    local earned = math.max(0, math.min(1, parts.earned))
    local function Segment(texture, from, size)
      size = math.max(0, math.min(1 - from, size))
      texture:ClearAllPoints()
      texture:SetPoint("TOPLEFT", bar, "TOPLEFT", inner * from, 0)
      texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", inner * from, 0)
      texture:SetWidth(math.max(0.01, inner * size))
      texture:SetShown(size > 0)
    end
    Segment(bar.earned, 0, earned)
    Segment(bar.rested, earned, parts.rested)
    Segment(bar.quest, earned, parts.quest)
  end
end

local function Tip()
  if tip then
    return tip
  end
  tip = UI.Ink(CreateFrame("Frame", "CodexInfoBarTooltip", UIParent))
  tip:SetFrameStrata("TOOLTIP")
  tip:SetClampedToScreen(true)
  tip:Hide()
  UI.Panel(tip, { noCorners = true })
  tip.title = UI.Text(tip, "head", 13, "titleText")
  tip.title:SetPoint("TOPLEFT", PAD, -(PAD - 2))
  tip.titleNote = UI.Text(tip, "body", 12, "muted")
  tip.titleNote:SetPoint("TOPRIGHT", -PAD, -(PAD - 1))
  tip.titleNote:SetJustifyH("RIGHT")
  tip.pools = { line = {}, bar = {}, rule = {}, note = {}, xp = {} }
  for name, method in pairs(TipMethods) do
    tip[name] = method
  end
  I.tip = tip
  return tip
end

-- Builds a tooltip with build(tip) and shows it under (below = true) or above the anchor. owner: the slot it
-- belongs to (refreshed when its data changes), or nil.
function I.OpenTip(anchor, build, below, owner)
  local self = Tip()
  for _, pool in pairs(self.pools) do
    for _, element in ipairs(pool) do
      element:Hide()
    end
  end
  self.used, self.bars, self.xpBar = {}, {}, nil
  self.need, self.y = 0, PAD
  self.title:SetText("")
  self.titleNote:SetText("")
  local ok, err = pcall(build, self)
  if not ok then
    geterrorhandler()(err)
  end
  local width = math.max(220, math.ceil(self.need)) + 2 * PAD
  self:SetSize(width, self.y + PAD - 2)
  SizeBars(self, width)
  self:ClearAllPoints()
  if below then
    self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  else
    self:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
  end
  self.owner = owner
  self:Show()
end

-- The tooltip of a slot's data text (under a top bar, above the others).
function I.ShowTip(slot)
  local text = slot.textDef
  if not (text and text.Tooltip) then
    return
  end
  I.OpenTip(slot, text.Tooltip, slot.info.bar == "top" and I.AtTop(), slot)
end

function I.HideTip()
  if tip then
    tip.owner = nil
    tip:Hide()
  end
end

-- Rebuilds the open tooltip when its data text changed.
local function RefreshTip(textID)
  if tip and tip:IsShown() and tip.owner and tip.owner.textDef and (not textID or tip.owner.textDef.id == textID) then
    I.ShowTip(tip.owner)
  end
end

-- Slots ----------------------------------------------------------------------------------------------------------

local function Compose(label, value, valueColor, note, noteColor)
  local parts = {}
  if label then
    parts[#parts + 1] = I.Hex("muted") .. label .. "|r"
  end
  parts[#parts + 1] = I.Hex(valueColor or "bright") .. value .. "|r"
  if note then
    parts[#parts + 1] = I.Hex(noteColor or "muted") .. note .. "|r"
  end
  return table.concat(parts, " ")
end

-- Icon and text centred together in a panel slot, but never closer than PANEL_PAD to its edges.
local function CenterInPanel(slot)
  local width = Num(slot:GetWidth()) or 0
  local iconWidth = slot.icon:IsShown() and 13 + 5 or 0
  local group = iconWidth + (Num(slot.text:GetStringWidth()) or 0)
  local offset = math.max(PANEL_PAD, math.floor((width - group) / 2))
  slot.icon:ClearAllPoints()
  slot.icon:SetPoint("LEFT", offset, 0)
  slot.text:ClearAllPoints()
  slot.text:SetPoint("LEFT", offset + iconWidth, 0)
  slot.text:SetPoint("RIGHT", -PANEL_PAD, 0)
end

-- Fills one slot from its data text. Returns true when its shown state or width changed (the bar re-lays out).
function I.UpdateSlot(slot)
  local id = I.DB().slots[slot.info.key]
  local text = I.TEXTS[id]
  slot.textDef = text
  local shown = false
  if text then
    local ok, label, value, valueColor, note, noteColor = pcall(text.Value)
    if not ok then
      geterrorhandler()(label)
    elseif value then
      slot.fullText = Compose(label, value, valueColor, note, noteColor)
      -- the panel's fallback when its slots are cramped: the same without the note ("60 fps" for "60 fps 35 ms")
      slot.shortText = note and Compose(label, value, valueColor) or nil
      slot.text:SetText(slot.fullText)
      shown = true
    end
  end
  if not shown then
    slot.fullText, slot.shortText = "", nil
    slot.text:SetText("")
  end
  slot.icon:SetShown(shown and text.icon ~= nil and slot.info.side ~= "center")
  if shown and text.icon then
    slot.icon:SetTexture(text.icon)
  end
  if slot.info.bar == "top" and slot.info.side ~= "center" then
    -- as wide as its text (in steps of 4, so a ticking number doesn't shake its neighbours)
    local width = math.ceil(((Num(slot.text:GetStringWidth()) or 0) + 40) / 4) * 4
    local changed = slot.shownState ~= shown
    if shown and width ~= slot.width then
      slot.width = width
      slot:SetWidth(width)
      changed = true
    end
    slot.shownState = shown
    return changed
  end
  slot.shownState = shown
  return slot.info.bar == "panel"
end

local function OpenSlotMenu(slot)
  I.HideTip()
  local key = slot.info.key
  local current = I.DB().slots[key]
  local items = { { text = "Show in this slot", title = true } }
  for _, id in ipairs(I.MENU_ORDER) do
    local text = I.TEXTS[id]
    items[#items + 1] = { text = text.name, checked = current == id, func = function()
      I.SetSlot(key, id)
    end }
  end
  items[#items + 1] = { text = "Nothing", checked = current == "none", func = function()
    I.SetSlot(key, "none")
  end }
  UI.ShowMenu(slot, items)
  local menu = _G.CodexMenu
  if type(menu) == "table" and menu.ClearAllPoints then
    menu:ClearAllPoints()
    if slot.info.bar == "top" and I.AtTop() then
      menu:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -4)
    else
      menu:SetPoint("BOTTOMLEFT", slot, "TOPLEFT", 0, 4)
    end
  end
end

local function CreateSlot(parent, info)
  local slot = CreateFrame("Button", nil, parent)
  slot.info = info
  slot:SetHeight(HEIGHT)
  slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local select = Theme().select
  local hover = slot:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  T.Gradient(hover, "HORIZONTAL", select.from, select.to, select.from[4] or 0.22, select.to[4] or 0.03)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetVertexColor(UI.Unpack(Theme().accent))
  slot.text = UI.Text(slot, "body", 12, "bright")
  slot.text:SetWordWrap(false)
  local divider = slot:CreateTexture(nil, "BORDER")
  divider:SetWidth(1)
  UI.SetColor(divider, Theme().divider, 0.7)
  if info.bar == "top" then
    divider:SetPoint("TOPLEFT")
    divider:SetPoint("BOTTOMLEFT")
    slot.icon:SetSize(14, 14)
    if info.side == "center" then
      divider:Hide()
      slot.text:SetPoint("LEFT", 10, 0)
      slot.text:SetPoint("RIGHT", -10, 0)
      slot.text:SetJustifyH("CENTER")
    else
      slot.icon:SetPoint("LEFT", 10, 0)
      slot.text:SetPoint("LEFT", slot.icon, "RIGHT", 6, 0)
    end
  else
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")
    slot.icon:SetSize(13, 13)
    slot.icon:SetPoint("LEFT", PANEL_PAD, 0) -- icon + text centred as a group by CenterInPanel
    slot.text:SetPoint("LEFT", PANEL_PAD + 18, 0)
    slot.text:SetPoint("RIGHT", -PANEL_PAD, 0)
  end
  slot:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      OpenSlotMenu(self)
    elseif self.textDef and self.textDef.Click then
      I.HideTip()
      local ok, err = pcall(self.textDef.Click, button)
      if not ok then
        geterrorhandler()(err)
      end
    end
  end)
  slot:SetScript("OnEnter", function(self)
    I.ShowTip(self)
  end)
  slot:SetScript("OnLeave", function()
    I.HideTip()
  end)
  I.slots[info.key] = slot
  return slot
end

-- Screen bar -----------------------------------------------------------------------------------------------------

local function CreateEmblem(bar)
  local button = CreateFrame("Button", nil, bar)
  button:SetSize(20, 20)
  button:SetPoint("LEFT", 6, 0)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local ring = button:CreateTexture(nil, "BACKGROUND")
  ring:SetTexture(CODEX_MEDIA .. "Circle")
  ring:SetAllPoints()
  ring:SetVertexColor(UI.Unpack(Theme().accent))
  local back = button:CreateTexture(nil, "BORDER")
  back:SetTexture(CODEX_MEDIA .. "Circle")
  back:SetPoint("CENTER")
  back:SetSize(18, 18)
  back:SetVertexColor(0.06, 0.05, 0.07, 1)
  local emblem = button:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(CODEX_MEDIA .. "Emblem")
  emblem:SetPoint("CENTER")
  emblem:SetSize(16, 16)
  if button.CreateMaskTexture and emblem.AddMaskTexture then
    local mask = button:CreateMaskTexture()
    mask:SetTexture(CODEX_MEDIA .. "Circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(emblem)
    emblem:AddMaskTexture(mask)
  end
  local glow = button:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture(CODEX_MEDIA .. "Circle")
  glow:SetAllPoints()
  glow:SetVertexColor(1, 1, 1, 0.15)
  button:SetScript("OnClick", function(_, which)
    if which == "RightButton" then
      ns.ShowPage("infobar")
    else
      ns.ToggleWindow()
    end
  end)
  button:SetScript("OnEnter", function(self)
    I.OpenTip(self, function(tooltip)
      tooltip:Title("Codex")
      tooltip:Line("Click to open Codex.", nil, "text")
      tooltip:Line("Right-click for the info bar options.", nil, "text")
    end, I.AtTop())
  end)
  button:SetScript("OnLeave", function()
    I.HideTip()
  end)
  return button
end

local function CreateTop()
  local bar = UI.Ink(CreateFrame("Frame", "CodexInfoBar", UIParent))
  bar:SetHeight(HEIGHT)
  bar:SetFrameStrata("BACKGROUND")
  bar:SetFrameLevel(5)
  BarFill(bar)
  EdgeLines(bar)
  bar.emblem = CreateEmblem(bar)
  bar.slots = {}
  for _, info in ipairs(I.SLOTS) do
    if info.bar == "top" then
      bar.slots[#bar.slots + 1] = CreateSlot(bar, info)
    end
  end
  frames.top = bar
  return bar
end

-- Fitting --------------------------------------------------------------------------------------------------------

local MIN_TOP = 360 -- narrower than this at the top: the bar goes to the bottom edge instead
local GAP = 8 -- between the bar's end and the frame it makes room for
local CENTER_MIN = 150 -- the middle slot's least width when shown
-- Slots dropped first when the bar is too narrow for every shown text (gold, bags, XP, clock and location last).
local DROP_ORDER = { "prof", "rep", "ammo", "durability", "guild", "friends", "fps", "clock", "xp", "bags", "gold", "zone" }

-- Blizzard frames the bar makes room for (read only; Edit Mode puts them where the player likes).
local WATCH = {
  { "MinimapCluster", "the minimap" }, { "BuffFrame", "your buffs" }, { "DebuffFrame", "your debuffs" },
  { "ObjectiveTrackerFrame", "the quest tracker" }, { "MicroMenuContainer", "the menu buttons" },
  { "MicroButtonAndBagsBar", "the menu buttons" }, { "BagsBar", "the bag buttons" },
  { "MainActionBar", "action bar 1" }, { "MainMenuBar", "action bar 1" }, { "MultiBarBottomLeft", "action bar 2" },
  { "MultiBarBottomRight", "action bar 3" }, { "MultiBarRight", "action bar 4" }, { "MultiBarLeft", "action bar 5" },
  { "MultiBar5", "action bar 6" }, { "MultiBar6", "action bar 7" }, { "MultiBar7", "action bar 8" },
  { "StanceBar", "the stance bar" }, { "PetActionBar", "the pet bar" }, { "PossessActionBar", "the possess bar" },
  { "MainStatusTrackingBarContainer", "the experience bar" },
  { "SecondaryStatusTrackingBarContainer", "the reputation bar" },
  { "PlayerFrame", "the player frame" }, { "TargetFrame", "the target frame" },
  { "ChatFrame1", "the chat" }, { "GeneralDockManager", "the chat tabs" }, { "CodexChatDataPanel", "the chat panel" },
}

function I.AtTop()
  local fit = I.fit
  if fit then
    return fit.edge ~= "bottom"
  end
  return I.DB().position ~= "bottom"
end

-- A frame's edges in UIParent's coordinates, or nil when it is hidden or unreadable.
local function Edges(frame)
  if type(frame) ~= "table" or not (frame.IsVisible and frame:IsVisible()) or not frame.GetLeft then
    return nil
  end
  local left, right, top, bottom = Num(frame:GetLeft()), Num(frame:GetRight()), Num(frame:GetTop()), Num(frame:GetBottom())
  if not (left and right and top and bottom) then
    return nil
  end
  local scale = (Num(frame:GetEffectiveScale()) or 1) / (Num(UIParent:GetEffectiveScale()) or 1)
  return left * scale, right * scale, top * scale, bottom * scale
end

-- The watched frames in the bar's strip at that edge: { { left, right, name } }, and the screen width.
local function InStrip(edge)
  local width, height = Num(UIParent:GetWidth()), Num(UIParent:GetHeight())
  if not (width and height and width > 0 and height > 0) then
    return nil
  end
  local stripTop, stripBottom = HEIGHT, 0
  if edge ~= "bottom" then
    stripTop, stripBottom = height, height - HEIGHT
  end
  local list, seen = {}, {}
  for _, watch in ipairs(WATCH) do
    local frame = _G[watch[1]]
    if frame and frame ~= frames.top and not seen[frame] then
      seen[frame] = true
      local left, right, top, bottom = Edges(frame)
      if left and top > stripBottom + 1 and bottom < stripTop - 1 and right > 0 and left < width then
        list[#list + 1] = { left = left, right = right, name = watch[2] }
      end
    end
  end
  return list, width
end

local function Names(list)
  local names, seen = {}, {}
  for _, entry in ipairs(list) do
    local name = entry.name or entry
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  return names
end

-- The widest run of the edge free of those frames: start (from the left), width (nil = the whole width),
-- the frames' names and the side the bar hangs from ("left" / "right").
local function FreeRun(edge)
  local list, width = InStrip(edge)
  if not list or #list == 0 then
    return 0, nil, {}, "left"
  end
  local minLeft, maxRight = width, 0
  for _, entry in ipairs(list) do
    minLeft = math.min(minLeft, entry.left)
    maxRight = math.max(maxRight, entry.right)
  end
  local leftRun, rightRun = minLeft - GAP, width - maxRight - GAP
  if leftRun >= rightRun then
    return 0, math.max(0, math.floor(leftRun)), Names(list), "left"
  end
  return maxRight + GAP, math.max(0, math.floor(rightRun)), Names(list), "right"
end

-- Measures where the bar can go. In combat the last measurement stays (nothing is moved then anyway).
-- { edge, start, width (nil = full), side, names, fallback = true when the top was too narrow, topWidth, topNames }
function I.Fit()
  local db = I.DB()
  local wanted = db.position == "bottom" and "bottom" or "top"
  local fit = { edge = wanted, start = 0, width = nil, names = {}, side = "left", fallback = false }
  if db.fit == false then
    I.fit = fit
    return fit
  end
  if InCombatLockdown and InCombatLockdown() and I.fit then
    return I.fit
  end
  fit.start, fit.width, fit.names, fit.side = FreeRun(wanted)
  if wanted == "top" and fit.width and fit.width < MIN_TOP then
    local start, width, names, side = FreeRun("bottom")
    if not width or width > fit.width then
      fit = { edge = "bottom", start = start, width = width, names = names, side = side, fallback = true,
        topWidth = fit.width, topNames = fit.names }
    end
  end
  I.fit = fit
  return fit
end

-- The bar's width for laying out its slots.
function I.BarWidth()
  local fit = I.fit
  if fit and fit.width then
    return fit.width
  end
  return Num(UIParent:GetWidth()) or 1280
end

-- Names of the frames in the bar's strip (the page's note while "Full width" is on).
function I.Overlaps()
  if not (frames.top and frames.top:IsShown()) then
    return {}
  end
  local list = InStrip(I.AtTop() and "top" or "bottom")
  return list and Names(list) or {}
end

local function PlaceTop()
  local bar = frames.top
  local fit = I.fit or I.Fit()
  local atTop = fit.edge ~= "bottom"
  local point = atTop and "TOP" or "BOTTOM"
  bar:ClearAllPoints()
  if fit.width then
    if fit.side == "right" then
      bar:SetPoint(point .. "RIGHT", UIParent, point .. "RIGHT", 0, 0)
    else
      bar:SetPoint(point .. "LEFT", UIParent, point .. "LEFT", fit.start, 0)
    end
    bar:SetWidth(math.max(1, fit.width))
  else
    bar:SetPoint(point .. "LEFT", UIParent, point .. "LEFT", 0, 0)
    bar:SetPoint(point .. "RIGHT", UIParent, point .. "RIGHT", 0, 0)
  end
  PlaceEdgeLines(bar, atTop)
end

-- Drops the least needed shown slots until the rest fit the bar's width. I.dropped = their names.
local function DropForRoom(bar)
  local available = I.BarWidth() - (6 + 20 + 6) - 4 -- the emblem and the right padding
  local function Needed()
    local total = 0
    for _, slot in ipairs(bar.slots) do
      if slot.shownState and not slot.dropped then
        total = total + (slot.info.side == "center" and CENTER_MIN or (slot.width or 0))
      end
    end
    return total
  end
  for _, slot in ipairs(bar.slots) do
    slot.dropped = nil
  end
  I.dropped = {}
  local index = 1
  while Needed() > available and index <= #DROP_ORDER do
    for _, slot in ipairs(bar.slots) do
      if slot.shownState and not slot.dropped and slot.textDef and slot.textDef.id == DROP_ORDER[index] then
        slot.dropped = true
        I.dropped[#I.dropped + 1] = slot.textDef.name
      end
    end
    index = index + 1
  end
end

-- Chains the shown slots: left ones after the emblem, right ones from the right edge, the middle one between.
local function LayoutTop()
  local bar = frames.top
  if not bar then
    return
  end
  DropForRoom(bar)
  local function On(slot)
    return slot.shownState and not slot.dropped
  end
  local previous, center = bar.emblem, nil
  local rights = {}
  for _, slot in ipairs(bar.slots) do
    slot:ClearAllPoints()
    if slot.info.side == "center" then
      center = slot
    elseif slot.info.side == "right" then
      rights[#rights + 1] = slot
    elseif On(slot) then
      slot:SetPoint("LEFT", previous, "RIGHT", previous == bar.emblem and 6 or 0, 0)
      previous = slot
    end
    slot:SetShown(On(slot) and true or false)
  end
  local right = nil
  for index = #rights, 1, -1 do
    local slot = rights[index]
    if On(slot) then
      if right then
        slot:SetPoint("RIGHT", right, "LEFT", 0, 0)
      else
        slot:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
      end
      right = slot
    end
  end
  if center then
    center:SetPoint("LEFT", previous, "RIGHT", previous == bar.emblem and 6 or 0, 0)
    if right then
      center:SetPoint("RIGHT", right, "LEFT", 0, 0)
    else
      center:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    end
    center:SetShown(On(center) and true or false)
  end
end
I.LayoutTop = LayoutTop

-- Measures again and re-lays out (a moment after the trigger, once for a burst of them). In combat it waits
-- for the fight to end.
local fitPending = false
function I.Refit()
  if not (I.running and frames.top and I.DB().top) then
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    I.fitAfterCombat = true
    return
  end
  I.Fit()
  PlaceTop()
  LayoutTop()
  ns.Fire("INFOBAR_CHANGED")
end

function I.QueueFit()
  if fitPending or not (frames.top and I.DB().top and I.DB().fit) then
    return
  end
  fitPending = true
  C_Timer.After(0.3, function()
    fitPending = false
    I.Refit()
  end)
end

-- Making room ----------------------------------------------------------------------------------------------------

local ROOM_GAP = 4

-- The watched frames whose edge is inside the bar's strip, with their readable points. A frame hanging from
-- another one in the list moves with it and is left out.
local function FramesInStrip(edge)
  local width, height = Num(UIParent:GetWidth()), Num(UIParent:GetHeight())
  if not (width and height) then
    return {}
  end
  local list, inStrip = {}, {}
  for _, watch in ipairs(WATCH) do
    local frame = _G[watch[1]]
    if frame and frame ~= frames.top and frame ~= frames.panel and not inStrip[frame] then
      local _, _, top, bottom = Edges(frame)
      local inside = top and ((edge == "bottom" and bottom < HEIGHT + 1) or (edge ~= "bottom" and top > height - HEIGHT - 1))
      if inside then
        local points, index = {}, 1
        while true do
          local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
          if not point then
            break
          end
          if not (Num(x) and Num(y)) then
            points = nil
            break
          end
          points[index] = { point, relativeTo, relativePoint, x, y }
          index = index + 1
        end
        if points and #points > 0 then
          inStrip[frame] = true
          list[#list + 1] = { frame = frame, name = watch[2], points = points }
        end
      end
    end
  end
  local kept = {}
  for _, entry in ipairs(list) do
    local hangs = false
    for _, point in ipairs(entry.points) do
      local relativeTo = point[2]
      if type(relativeTo) == "string" then
        relativeTo = _G[relativeTo]
      end
      if relativeTo and inStrip[relativeTo] then
        hangs = true
      end
    end
    if not hangs then
      kept[#kept + 1] = entry
    end
  end
  return kept
end

-- Re-anchors a frame with every point's y offset changed by dy (in UIParent units), through the engine's methods.
-- Returns the y offset of its first point afterwards.
local function Shift(frame, points, dy)
  local scale = (Num(frame:GetEffectiveScale()) or 1) / (Num(UIParent:GetEffectiveScale()) or 1)
  local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
  local setPoint = frame.SetPointBase or frame.SetPoint
  clear(frame)
  for _, point in ipairs(points) do
    setPoint(frame, point[1], point[2], point[3], point[4], point[5] + dy / scale)
  end
  return points[1][5] + dy / scale
end

-- Still where the shift put it (not moved since by the player or Edit Mode)?
local function StillShifted(frame, record)
  local _, _, _, _, y = frame:GetPoint(1)
  y = Num(y)
  return y ~= nil and math.abs(y - record.shiftedY) < 0.5
end

I.moved = {} -- [frame] = { name, points = the points before the shift, shiftedY = its first point's y after }

-- Moves the frames in the bar's strip out of it: down from a top bar, up from a bottom one. Returns the names
-- moved now (empty when nothing was in the way) or nil in combat (done after the fight).
function I.MakeRoom()
  if not (I.running and frames.top and frames.top:IsShown() and I.DB().room ~= false) then
    return {}
  end
  if InCombatLockdown and InCombatLockdown() then
    I.roomAfterCombat = true
    return nil
  end
  local editMode = _G.EditModeManagerFrame
  if type(editMode) == "table" and editMode.IsShown and editMode:IsShown() then
    return {} -- Edit Mode is showing the frames where its layout has them; again when it closes
  end
  if I.shifting then
    return {}
  end
  I.shifting = true
  local edge = I.AtTop() and "top" or "bottom"
  local names = {}
  for _, entry in ipairs(FramesInStrip(edge)) do
    local dy = HEIGHT + ROOM_GAP
    if edge == "bottom" and entry.frame == _G.ChatFrame1 and frames.panel and frames.panel:IsShown() then
      dy = dy + HEIGHT + 7 -- the chat panel hangs under the chat
    end
    local ok, shiftedY = pcall(Shift, entry.frame, entry.points, edge == "bottom" and dy or -dy)
    if ok then
      -- the place it had now (Edit Mode's, or the player's) is the one to go back to
      I.moved[entry.frame] = { name = entry.name, points = entry.points, shiftedY = shiftedY }
      names[#names + 1] = entry.name
    else
      geterrorhandler()(shiftedY)
    end
  end
  I.shifting = false
  if #names > 0 then
    ns.Fire("INFOBAR_CHANGED")
  end
  return names
end
ns.API.InfoBarMakeRoom = function()
  return I.MakeRoom()
end

-- Puts every moved frame back on the points it had before (and stops making room until asked again).
function I.PutBack()
  I.DB().room = false
  if InCombatLockdown and InCombatLockdown() then
    I.putBackAfterCombat = true
    return false
  end
  I.shifting = true
  for frame, record in pairs(I.moved) do
    -- a frame the player (or Edit Mode) moved since is where they want it
    if StillShifted(frame, record) then
      local ok, err = pcall(Shift, frame, record.points, 0)
      if not ok then
        geterrorhandler()(err)
      end
    end
  end
  I.shifting = false
  I.moved = {}
  ns.Fire("INFOBAR_CHANGED")
  return true
end

-- Names of the frames moved so far, for the page.
function I.MovedNames()
  local names = {}
  for _, record in pairs(I.moved) do
    names[#names + 1] = record.name
  end
  table.sort(names)
  return names
end

local roomPending = false
function I.QueueRoom()
  if roomPending or I.shifting or not (frames.top and I.DB().top and I.DB().room ~= false) then
    return
  end
  roomPending = true
  C_Timer.After(0.2, function()
    roomPending = false
    I.MakeRoom()
  end)
end

local watchFrame
local hookedAnchors = {}

-- Makes room again whenever Edit Mode puts the frames back (its layout at login, closing it, reverting), and
-- after a fight when it had to wait; re-measures the fitted bar (option) when the frames or the screen change.
local function Watch()
  if not watchFrame then
    watchFrame = CreateFrame("Frame")
    watchFrame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_ENABLED" then
        if I.putBackAfterCombat then
          I.putBackAfterCombat = nil
          I.PutBack()
        end
        if I.roomAfterCombat then
          I.roomAfterCombat = nil
          I.QueueRoom()
        end
        if I.fitAfterCombat then
          I.fitAfterCombat = nil
          I.QueueFit()
        end
        return
      end
      if event == "PLAYER_ENTERING_WORLD" then
        -- Edit Mode lays the frames out a moment after entering: once more a little later
        C_Timer.After(2, I.QueueRoom)
        C_Timer.After(2, I.QueueFit)
      end
      I.QueueRoom()
      I.QueueFit()
    end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
      "DISPLAY_SIZE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
      pcall(watchFrame.RegisterEvent, watchFrame, event)
    end
    I.watchFrame = watchFrame
    -- Edit Mode closing (a method post-hook: its OnHide script is left to others)
    local editMode = _G.EditModeManagerFrame
    -- (rawget: only a frame that really carries the mixin's method, not an inherited stub)
    if type(editMode) == "table" and type(rawget(editMode, "ExitEditMode")) == "function" then
      hooksecurefunc(editMode, "ExitEditMode", function()
        I.QueueRoom()
        I.QueueFit()
      end)
    end
  end
  for _, watch in ipairs(WATCH) do
    local frame = _G[watch[1]]
    if type(frame) == "table" and not hookedAnchors[frame] and type(rawget(frame, "ApplySystemAnchor")) == "function" then
      hookedAnchors[frame] = true
      hooksecurefunc(frame, "ApplySystemAnchor", function()
        if not I.shifting then
          I.QueueRoom()
          I.QueueFit()
        end
      end)
    end
  end
end

-- The fit option's extra triggers: the buff row growing, a watched frame resizing.
local fitWatched = false
local function WatchForFit()
  if fitWatched or not I.DB().fit then
    return
  end
  fitWatched = true
  pcall(watchFrame.RegisterUnitEvent, watchFrame, "UNIT_AURA", "player")
  for _, name in ipairs({ "BuffFrame", "DebuffFrame", "MinimapCluster", "ObjectiveTrackerFrame" }) do
    local frame = _G[name]
    if type(frame) == "table" and frame.HookScript then
      frame:HookScript("OnSizeChanged", I.QueueFit)
    end
  end
end

-- Chat panel -----------------------------------------------------------------------------------------------------

local function ChatFrame()
  return _G.ChatFrame1
end

local function EditBox(chat)
  return (chat and chat.editBox) or _G.ChatFrame1EditBox
end

-- Under the chat window, exactly as wide as its box, PANEL_GAP under it. With Codex's chat look on, the box is the
-- skin's plate (a texture on the chat frame: found once, then the panel hangs from it, so it follows every
-- re-fit, resize and move of the box); without it, the chat frame with the skin's insets (8 left, 6 under, the
-- right edge 4 past the scroll column). An edit box that stays shown under the chat (the "IM" chat style) pushes
-- the panel below it; one that only shows while typing covers it.
local PANEL_GAP = 3
local BOX_LEFT, BOX_BOTTOM, COLUMN_PAD, BUTTON_MIN = 8, 6, 4, 12 -- Skins/Chat.lua's box (FitColumn)

-- The chat skin's box texture on this chat frame, or nil (skin off / not built yet).
local function ChatBox(chat)
  local api = ns.API.ChatBox
  if type(api) == "function" then
    local ok, box = pcall(api, chat)
    if ok and box then
      return box
    end
  end
  if not (ns.SkinPartOn and ns.SkinPartOn("chat")) then
    return nil
  end
  -- the plate's fill: BACKGROUND -8, its bottom-right on the chat frame (Blizzard's own background is emptied)
  for _, region in ipairs({ chat:GetRegions() }) do
    if region ~= _G[(chat:GetName() or "") .. "Background"] and region.GetDrawLayer and region.GetNumPoints
      and region:GetNumPoints() == 2 then
      local layer, sublevel = region:GetDrawLayer()
      local point, relativeTo = region:GetPoint(2)
      if layer == "BACKGROUND" and sublevel == -8 and point == "BOTTOMRIGHT" and relativeTo == chat then
        return region
      end
    end
  end
end
I.ChatBox = ChatBox

-- Without the skin: the box's right edge past the chat frame's right, as Skins/Chat.lua's FitColumn works it out.
local function BoxRight(chat)
  local bar = chat.ScrollBar
  if type(bar) ~= "table" or not bar.GetLeft then
    return BOX_LEFT
  end
  local left, right = Num(bar:GetLeft()), Num(chat:GetRight())
  local barScale = Num(bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
  local frameScale = Num(chat.GetEffectiveScale and chat:GetEffectiveScale()) or 1
  if not (left and right and frameScale > 0) then
    return BOX_LEFT
  end
  local dx = math.max(-40, math.min(40, left * barScale / frameScale - right))
  local width = Num(bar:GetWidth()) or 10
  local size = math.max(BUTTON_MIN, math.floor(width + 0.5))
  return math.max(BOX_LEFT, dx + width / 2 + math.max(width, size) / 2 + COLUMN_PAD)
end

function I.PlacePanel()
  local panel, chat = frames.panel, ChatFrame()
  if not (panel and chat) then
    return
  end
  local box = ChatBox(chat)
  -- how far the edit box (and its 3-unit plate) reaches under the box's bottom, when it stays shown under it
  local drop = 0
  local edit = EditBox(chat)
  if edit and edit.IsShown and edit:IsShown() then
    if not (edit.HasFocus and edit:HasFocus()) then
      I.editStays = true
    end
    local editTop, editBottom, chatBottom = Num(edit:GetTop()), Num(edit:GetBottom()), Num(chat:GetBottom())
    if I.editStays and editTop and editBottom and chatBottom and editTop <= chatBottom + 4 then
      local boxBottom = box and Num(box:GetBottom()) or chatBottom - BOX_BOTTOM
      drop = math.max(0, boxBottom - (editBottom - 3))
    end
  end
  panel:ClearAllPoints()
  if box then
    panel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -(PANEL_GAP + drop))
    panel:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -(PANEL_GAP + drop))
  else
    local y = -(BOX_BOTTOM + PANEL_GAP + drop)
    panel:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", -BOX_LEFT, y)
    panel:SetPoint("TOPRIGHT", chat, "BOTTOMRIGHT", BoxRight(chat), y)
  end
  I.panelBelow = drop > 0 and edit or (box or chat)
end

local function CornerButton(panel, icon, size)
  local button = CreateFrame("Button", nil, panel)
  button:SetSize(CORNER, HEIGHT)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetSize(size, size)
  button.icon:SetPoint("CENTER")
  button.icon:SetTexture(MEDIA .. icon)
  button.icon:SetVertexColor(UI.Unpack(Theme().accent))
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, Theme().accent, 0.12)
  return button
end

local function SimpleTip(button, title, line)
  button:SetScript("OnEnter", function(self)
    I.OpenTip(self, function(tooltip)
      tooltip:Title(title)
      tooltip:Line(line(), nil, "text")
    end, false)
  end)
  button:SetScript("OnLeave", function()
    I.HideTip()
  end)
end

-- A panel slot's natural width for its full (or short) text: icon, gap, text and the padding each side.
local function PanelNatural(slot, short)
  local text = short and slot.shortText or slot.fullText or ""
  if text == "" then
    return 2 * PANEL_PAD + 8 -- an empty slot keeps a little room (right-click picks what it shows)
  end
  slot.text:SetText(text)
  local iconWidth = slot.icon:IsShown() and 13 + 5 or 0
  return math.ceil((iconWidth + (Num(slot.text:GetStringWidth()) or 0) + 2 * PANEL_PAD) / 4) * 4
end

-- The slots share the panel by their texts: each gets what its text needs plus an equal share of the rest. When
-- they don't all fit, the slots with a short form drop their note (widest saving first); only then are texts cut.
local function LayoutPanel()
  local panel = frames.panel
  if not panel then
    return
  end
  local available = math.max(1, (Num(panel:GetWidth()) or 0) - 2 * CORNER)
  local slots, widths, short, total = panel.slots, {}, {}, 0
  for index, slot in ipairs(slots) do
    widths[index] = PanelNatural(slot, false)
    total = total + widths[index]
  end
  while total > available do
    local best, saving = nil, 0
    for index, slot in ipairs(slots) do
      if not short[index] and slot.shortText then
        local gain = widths[index] - PanelNatural(slot, true)
        if gain > saving then
          best, saving = index, gain
        end
      end
    end
    if not best then
      break
    end
    short[best] = true
    widths[best] = widths[best] - saving
    total = total - saving
  end
  local extra = (available - total) / #slots
  local x = CORNER
  for index, slot in ipairs(slots) do
    local width = extra >= 0 and widths[index] + extra or widths[index] * available / total
    slot.text:SetText((short[index] and slot.shortText) or slot.fullText or "")
    slot.short = short[index] or nil
    slot:ClearAllPoints()
    slot:SetPoint("LEFT", panel, "LEFT", x, 0)
    slot:SetWidth(width)
    slot:Show()
    CenterInPanel(slot)
    x = x + width
  end
end
I.LayoutPanel = LayoutPanel

local function CreatePanel()
  local panel = UI.Ink(CreateFrame("Frame", "CodexChatDataPanel", UIParent))
  panel:SetHeight(HEIGHT)
  panel:SetFrameStrata("BACKGROUND")
  panel:SetFrameLevel(5)
  panel:SetClampedToScreen(true)
  local title = Theme().titlebar
  local fill = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
  fill:SetAllPoints()
  UI.Gradient(fill, { title.from[1], title.from[2], title.from[3], 0.94 }, { title.to[1], title.to[2], title.to[3], 0.94 })
  UI.Rings(panel, Theme().hud and Theme().hud.rings or Theme().rings)

  panel.hide = CornerButton(panel, "Left", 12)
  panel.hide:SetPoint("LEFT")
  local hideLine = panel.hide:CreateTexture(nil, "BORDER")
  hideLine:SetWidth(1)
  hideLine:SetPoint("TOPRIGHT", 0, -1)
  hideLine:SetPoint("BOTTOMRIGHT", 0, 1)
  UI.SetColor(hideLine, Theme().divider, 0.7)
  panel.hide:SetScript("OnClick", function()
    I.ToggleChat()
  end)
  SimpleTip(panel.hide, "Chat", function()
    return I.chatHidden and "Click to show the chat again." or "Click to hide the chat."
  end)

  panel.copy = CornerButton(panel, "Copy", 12)
  panel.copy:SetPoint("RIGHT")
  panel.copy:SetScript("OnClick", function()
    I.ShowCopy()
  end)
  SimpleTip(panel.copy, "Copy chat", function()
    return "Click to copy the chat's recent lines."
  end)

  panel.slots = {}
  for _, info in ipairs(I.SLOTS) do
    if info.bar == "panel" then
      panel.slots[#panel.slots + 1] = CreateSlot(panel, info)
    end
  end
  panel:SetScript("OnSizeChanged", LayoutPanel)
  frames.panel = panel

  -- follow the edit box and the chat window (post-hooks only); moving the window moves the anchors with it
  local edit = EditBox(ChatFrame())
  if edit and edit.HookScript then
    for _, script in ipairs({ "OnShow", "OnHide", "OnEditFocusGained", "OnEditFocusLost" }) do
      edit:HookScript(script, I.PlacePanel)
    end
  end
  local chat = ChatFrame()
  if chat and chat.HookScript then
    chat:HookScript("OnSizeChanged", function()
      C_Timer.After(0, I.PlacePanel) -- after the skin has fitted its box
    end)
    chat:HookScript("OnShow", I.PlacePanel)
  end
  return panel
end

-- Events and ticker ----------------------------------------------------------------------------------------------

local eventFrame, ticker

-- The data texts shown right now: { [id] = true }.
local function ShownTexts()
  local shown = {}
  for _, info in ipairs(I.SLOTS) do
    local frame = frames[info.bar]
    if frame and frame:IsShown() then
      local id = I.DB().slots[info.key]
      if I.TEXTS[id] then
        shown[id] = true
      end
    end
  end
  return shown
end

-- Refreshes every slot showing one of these data texts (all when ids is nil).
local function UpdateTexts(ids)
  local relayout, panelChanged = false, false
  for _, info in ipairs(I.SLOTS) do
    local slot = I.slots[info.key]
    local frame = frames[info.bar]
    if slot and frame and frame:IsShown() then
      local id = I.DB().slots[info.key]
      if not ids or ids[id] then
        if I.UpdateSlot(slot) then
          if info.bar == "top" then
            relayout = true
          else
            panelChanged = true
          end
        end
      end
    end
  end
  if relayout then
    LayoutTop()
  end
  if panelChanged then
    I.LayoutPanel()
  end
end
I.UpdateTexts = UpdateTexts

local function Tick()
  local ids = {}
  for id in pairs(ShownTexts()) do
    if I.TEXTS[id].tick then
      ids[id] = true
    end
  end
  UpdateTexts(ids)
  if tip and tip:IsShown() and tip.owner and tip.owner.textDef and ids[tip.owner.textDef.id or ""] then
    RefreshTip()
  end
end

local function OnEvent(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    I.entered = true
    if not I.sessionMoney then
      I.sessionMoney = Num(GetMoney())
    end
    I.PlacePanel()
    UpdateTexts(nil)
    return
  end
  if event == "PLAYER_MONEY" and not I.sessionMoney then
    I.sessionMoney = Num(GetMoney())
  end
  local ids = {}
  for id in pairs(ShownTexts()) do
    local text = I.TEXTS[id]
    for _, name in ipairs(text.events or {}) do
      if name == event then
        ids[id] = true
      end
    end
    if text.unitEvents and text.unitEvents[event] then
      ids[id] = true
    end
  end
  UpdateTexts(ids)
  for id in pairs(ids) do
    RefreshTip(id)
  end
end

-- Listens only to what the shown data texts need; the ticker runs only for clock, frame rate and location.
function I.Listen()
  if not eventFrame then
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
    I.eventFrame = eventFrame
  end
  eventFrame:UnregisterAllEvents()
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  local needTick = false
  for id in pairs(ShownTexts()) do
    local text = I.TEXTS[id]
    for _, name in ipairs(text.events or {}) do
      eventFrame:RegisterEvent(name)
    end
    for name, unit in pairs(text.unitEvents or {}) do
      eventFrame:RegisterUnitEvent(name, unit)
    end
    needTick = needTick or text.tick
  end
  I.ticking = needTick and true or false
  if needTick and not ticker then
    ticker = C_Timer.NewTicker(1, Tick)
  elseif not needTick and ticker then
    ticker:Cancel()
    ticker = nil
  end
end

-- Applying settings ----------------------------------------------------------------------------------------------

-- Shows / hides / places both bars from the settings, refills every slot and re-registers events.
function I.Apply()
  if not I.running then
    return
  end
  local db = I.DB()
  if db.top then
    if not frames.top then
      CreateTop()
      Watch()
    end
    WatchForFit()
    I.Fit()
    PlaceTop()
    frames.top:Show()
  elseif frames.top then
    frames.top:Hide()
  end
  if db.panel and ChatFrame() then
    if not frames.panel then
      CreatePanel()
    end
    I.PlacePanel()
    frames.panel:Show()
    LayoutPanel()
  elseif frames.panel then
    frames.panel:Hide()
  end
  I.HideTip()
  UpdateTexts(nil)
  LayoutTop()
  I.Listen()
  if db.top and db.room ~= false and I.entered then
    I.QueueRoom()
  end
  ns.Fire("INFOBAR_CHANGED")
  ns.Fire("INFOBAR_SHOWN", ns.API.InfoBarShown())
end

-- For Codex_Skins' minimap (it clears the zone line and the clock while the bar shows them): is the screen
-- bar up, and a call when that may have changed.
function ns.API.InfoBarShown()
  return (I.running and frames.top and frames.top:IsShown()) and true or false
end
function ns.API.OnInfoBarShown(callback)
  ns.On("INFOBAR_SHOWN", callback)
end

function I.SetSlot(key, id)
  I.DB().slots[key] = id
  I.Apply()
end

function I.Set(key, value)
  I.DB()[key] = value
  I.Apply()
end

function I.Frames()
  return frames
end

function I.Enable()
  I.DB()
  I.running = true
  I.sessionMoney = Num(GetMoney())
  -- fresh guild and friends numbers (answered by GUILD_ROSTER_UPDATE / FRIENDLIST_UPDATE)
  if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
    I.Ask(C_GuildInfo.GuildRoster)
  end
  if C_FriendList and C_FriendList.ShowFriends then
    I.Ask(C_FriendList.ShowFriends)
  end
  I.Apply()
end
