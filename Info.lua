local addonName, ns = ...
local L = ns.L

-- The info panel (2026-11-24, the user's request after FlareUI's settings: "shows preview of what is changed"): a
-- column on the right of the Codex window that tells what the thing under the mouse does. Hovering a section's
-- header or any option inside it shows that section's name, what it changes and its preview; an option adds its
-- own name (and its own words, when the option has them: UI.Describe). Nothing hovered keeps the last one; a new
-- page or tab starts with its first section.
--
-- A section's words come from its def: `desc` (text or a function), else its module's desc, its skins part's text
-- or its small switch's desc. Its preview: `def.preview(holder, width)` returning a frame, or for a skins part the
-- part card's "Game default > Codex" picture, laid out one above the other and drawn larger here (the card no longer
-- carries it while the panel shows: SettingsUI.lua, card.pictureInPanel).

local UI = ns.UI

ns.INFO_WIDTH = ns.INFO_WIDTH or 262 -- set by Window.lua, which adds it to the window
local PAD = 14
local INNER = ns.INFO_WIDTH - 2 * PAD
local PICTURE_SIDE = 138 -- SettingsUI.lua's picture sides are drawn this wide (60 high)

local panel
local current = { key = nil, previewKey = nil }

-- An option's own words in the panel: UI.Describe(widget, "text") or UI.Describe(widget, { title =, text = }).
function UI.Describe(widget, info)
  if type(widget) == "table" then
    widget.codexInfo = info
  end
  return widget
end

local function Str(value)
  return type(value) == "string" and value ~= "" and value or nil
end

local function SectionText(def)
  local desc = def.desc
  if type(desc) == "function" then
    local ok, text = pcall(desc)
    desc = ok and text or nil
  end
  if Str(desc) then
    return desc
  end
  local module = def.module and ns.modules and ns.modules[def.module]
  if module and Str(module.desc) then
    return module.desc
  end
  if def.part and ns.UI_PART_TEXT and Str(ns.UI_PART_TEXT[def.part]) then
    return ns.UI_PART_TEXT[def.part]
  end
  return nil
end
ns.InfoSectionText = SectionText

-- The name an option shows next to it: its own (UI.Describe's title, a check's label), the label of the row it sits
-- in (Settings' LabelRow), or a plain button's text. Pickers and steppers show values, never names.
local function WidgetLabel(widget)
  local info = widget.codexInfo
  if type(info) == "table" and Str(info.title) then
    return info.title
  end
  if Str(widget.codexLabel) then
    return widget.codexLabel
  end
  local label = rawget(widget, "label")
  if not widget.codexPicker and type(label) == "table" and label.GetText then
    local text = label:GetText()
    if Str(text) then
      return text
    end
  end
  local parent = widget.GetParent and widget:GetParent()
  if type(parent) == "table" and rawget(parent, "widget") == widget then
    local rowLabel = rawget(parent, "label")
    if type(rowLabel) == "table" and rowLabel.GetText and Str(rowLabel:GetText()) then
      return rowLabel:GetText()
    end
  end
  -- a row frame of ours with one text beside the widget (a label row built by hand)
  if type(parent) == "table" and parent.GetRegions and parent ~= panel then
    local found
    for _, region in ipairs({ parent:GetRegions() }) do
      if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "FontString" then
        if found then
          found = nil
          break
        end
        found = region
      end
    end
    if found and Str(found:GetText()) and #found:GetText() <= 64 then
      return found:GetText()
    end
  end
  if not widget.codexPicker and widget.GetObjectType and widget:GetObjectType() == "Button" and widget.GetText then
    local text = widget:GetText()
    if Str(text) and #text > 1 then -- not "-" / "+" / "x"
      return text
    end
  end
  return nil
end
ns.InfoWidgetLabel = WidgetLabel

local function WidgetText(widget)
  local info = widget.codexInfo
  if type(info) == "table" then
    return Str(info.text)
  end
  return Str(info)
end

-- Layout -----------------------------------------------------------------------------------------------------------

local function Layout()
  local y = 0
  local function Place(region, gap)
    if region:IsShown() then
      region:ClearAllPoints()
      region:SetPoint("TOPLEFT", panel.box, "TOPLEFT", PAD, -(PAD + y + (y > 0 and gap or 0)))
      y = y + (y > 0 and gap or 0) + ns.UITextHeight(region, region.size or 12, INNER)
    end
  end
  Place(panel.kicker, 0)
  Place(panel.title, 2)
  Place(panel.text, 8)
  Place(panel.option, 14)
  Place(panel.optionText, 4)
  local preview = panel.preview
  preview:ClearAllPoints()
  preview:SetPoint("TOPLEFT", panel.box, "TOPLEFT", PAD, -(PAD + y + 16))
  preview:SetWidth(INNER)
end

-- A part card's picture, one side above the other, drawn larger (the sides are drawn 138 x 60).
local function TakePicture(pair)
  local scale = math.min(1.6, INNER / PICTURE_SIDE)
  pair:SetParent(panel.preview)
  pair:ClearAllPoints()
  pair:SetPoint("TOPLEFT", panel.preview, "TOPLEFT", 0, 0)
  pair:SetSize(INNER, 10)
  if pair.arrow then
    pair.arrow:Hide()
  end
  local game, codex = pair.game, pair.codex
  local y = 0
  for _, side in ipairs({ game, codex }) do
    if side then
      side:SetScale(scale)
      side:ClearAllPoints()
      side:SetPoint("TOP", pair, "TOP", 0, -y / scale)
      local label = side.label
      if label then
        label:ClearAllPoints()
        label:SetPoint("TOP", pair, "TOP", 0, -(y + 60 * scale + 4))
        label:SetWidth(INNER)
      end
      y = y + 60 * scale + 4 + 14 + 12
    end
  end
  pair:SetHeight(y)
  pair:Show()
  return pair
end

local function ClearPreview()
  for _, child in ipairs({ panel.preview:GetChildren() }) do
    child:Hide()
  end
  panel.previewFrame = nil
end

local function ShowPreview(key, build)
  if current.previewKey == key and panel.previewFrame and panel.previewFrame:IsShown() then
    return
  end
  ClearPreview()
  current.previewKey = key
  if not build then
    return
  end
  local ok, frame = pcall(build, panel.preview, INNER)
  if not ok then
    geterrorhandler()(frame)
    return
  end
  if type(frame) == "table" and frame.Show then
    frame:Show()
    panel.previewFrame = frame
  end
end

-- The preview of a section: its own builder, else its skins part's picture.
local function SectionPreview(section)
  local def = section.def
  if type(def.preview) == "function" then
    return def.preview
  end
  if def.part then
    return function()
      if type(ns.EnsureSectionBody) == "function" then
        ns.EnsureSectionBody(section)
      end
      local card = ns.partCards and ns.partCards[def.part]
      if card and card.picture then
        return TakePicture(card.picture)
      end
    end
  end
  return nil
end

-- What the panel shows. subject = { key, kicker, title, text, option, optionText, previewKey, preview }.
function ns.ShowInfo(subject)
  if not panel or not subject then
    return
  end
  local sameKey = current.key ~= nil and current.key == subject.key
  current.key = subject.key
  if not sameKey then
    panel.kicker:SetText(subject.kicker or "")
    panel.kicker:SetShown(Str(subject.kicker) ~= nil)
    panel.title:SetText(subject.title or "")
    panel.text:SetText(subject.text or "")
    panel.text:SetShown(Str(subject.text) ~= nil)
    panel.option:SetText(subject.option or "")
    panel.option:SetShown(Str(subject.option) ~= nil)
    panel.optionText:SetText(subject.optionText or "")
    panel.optionText:SetShown(Str(subject.optionText) ~= nil)
    Layout()
  end
  ShowPreview(subject.previewKey or subject.key, subject.preview)
  panel.subject = subject
end

-- The section (and the option in it) under the mouse.
function ns.InfoHover(section, widget)
  if not panel or not section or not section.def then
    return
  end
  local def = section.def
  local area = ns.AREA_BY_ID and ns.AREA_BY_ID[def.area]
  local label = widget and WidgetLabel(widget)
  ns.ShowInfo({
    key = def.id .. (label and (":" .. label) or ""),
    kicker = area and area.name ~= def.title and area.name or nil, -- not "Chat" over "Chat"
    title = def.title,
    text = SectionText(def),
    option = label,
    optionText = widget and WidgetText(widget) or nil,
    previewKey = def.id,
    preview = SectionPreview(section),
  })
end

-- A page (or a tab) shown: its first section, or the page's own words.
function ns.InfoForPage(page, area)
  if not panel then
    return
  end
  if page and page.sections then
    for _, section in ipairs(page.sections) do
      if not page.tab or section.tab == page.tab then
        ns.InfoHover(section)
        return
      end
    end
  end
  area = area or (page and ns.AREA_BY_ID and ns.AREA_BY_ID[page.area or page.id])
  ns.ShowInfo({ key = "page:" .. tostring(area and area.id or (page and page.id)),
    title = area and area.name or "Tylesser Codex",
    text = area and area.desc
      or L["Pick a page on the left. Hover a section or an option and this panel says what it changes."],
  })
end

-- Again from the same subject (a picture was drawn again, a theme card changed).
function ns.RefreshInfo()
  if panel and panel.subject then
    current.key, current.previewKey = nil, nil
    ns.ShowInfo(panel.subject)
  end
end

-- Every option in a section's body tells the panel when the mouse is on it (built once, after the body).
local WATCHED = { Button = true, CheckButton = true, EditBox = true, Slider = true }
function ns.InfoWatch(section, root, depth)
  if not root or not root.GetChildren then
    return
  end
  depth = depth or 0
  if depth > 8 then
    return
  end
  for _, child in ipairs({ root:GetChildren() }) do
    if type(child) == "table" and not child.codexInfoWatched and not child.codexList then
      local kind = child.GetObjectType and child:GetObjectType()
      if WATCHED[kind] or child.codexPicker then
        child.codexInfoWatched = true
        child:HookScript("OnEnter", function(self)
          ns.InfoHover(section, self)
        end)
      end
      ns.InfoWatch(section, child, depth + 1)
    end
  end
end

-- Built by Window.lua on the right of the page area.
function ns.BuildInfoPanel(window)
  if panel then
    return panel
  end
  panel = CreateFrame("Frame", nil, window)
  panel:SetWidth(ns.INFO_WIDTH)
  local box = CreateFrame("Frame", nil, panel)
  box:SetAllPoints()
  UI.Inset(panel, box)
  if box.SetClipsChildren then
    box:SetClipsChildren(true)
  end
  panel.box = box
  local function Line(size, color, kind)
    local text = UI.Text(box, kind or "body", size, color)
    text:SetWidth(INNER - 4) -- a little short of the edge: the game's glyphs run wider than measured
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text.size = size
    return text
  end
  panel.kicker = Line(11, "muted")
  panel.title = Line(16, "titleText", "head")
  panel.text = Line(12, "text")
  panel.text:SetSpacing(2)
  panel.option = Line(13, "accent", "head")
  panel.optionText = Line(12, "text")
  panel.optionText:SetSpacing(2)
  panel.preview = CreateFrame("Frame", nil, box)
  panel.preview:SetSize(INNER, 10)
  panel.preview.codexNoSearch = true
  panel.codexNoSearch = true
  panel.codexMeasureSkip = true
  ns.infoPanel = panel
  return panel
end
