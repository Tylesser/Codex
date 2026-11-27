local addonName, ns = ...
local L = ns.L

-- The "Fonts" sections (FontStyles.lua has the elements): one per group, on that group's page. Each element is a
-- row with its name, Reset and a fold button; open, it shows Font and Size, Outline and Shadow (the user's FlareUI
-- screenshot, 2026-11-24). The info panel shows sample lines of the group drawn with the chosen styles.

local UI = ns.UI
local ROW = 30
local FIELD = 26

local open = {} -- [element key] = true while its row is open (this session)

local SAMPLES = {
  ["tracker.header"] = "Quests  9/40",
  ["tracker.quest"] = "[10] The Missing Scholar",
  ["tracker.objective"] = "- 0/1 Find Fillion Flamebreeze",
  ["dialogue.title"] = "Spear of the Skylord",
  ["dialogue.text"] = "Have you found Zarrat? Her cunning is considerable.",
  ["units.name"] = "Lunaria Aeria",
  ["units.bars"] = "224 / 224 · 100%",
  ["plates.name"] = "Shriekling Talon",
  ["plates.health"] = "1,204 · 87%",
  ["personal.text"] = "546 · 100%",
  ["chat.text"] = "[1. General] [Arthas]: anyone for Deadmines?",
  ["chat.tabs"] = "General   Combat Log",
  ["infobar.text"] = "12g 40s   ·   Dalaran   ·   19:26",
}

local function Elements(group)
  local list = {}
  for _, element in ipairs(ns.FONT_ELEMENTS) do
    if element.group == group then
      list[#list + 1] = element
    end
  end
  table.sort(list, function(a, b) return a.order < b.order end)
  return list
end
ns.FontElementsOf = Elements

local function SizeChoices(element)
  local list = { { key = "own", name = L["Own (%d)"]:format(math.floor(element.base + 0.5)) } }
  for size = ns.FONT_SIZE_MIN, ns.FONT_SIZE_MAX do
    list[#list + 1] = { key = size, name = tostring(size) }
  end
  return list
end

local function FontChoices()
  local list = { { key = "own", name = L["Element's own"] } }
  for _, info in ipairs(ns.FONTS) do
    if info.key ~= "theme" then
      list[#list + 1] = { key = info.key, name = info.name }
    end
  end
  return list
end

local function Choices(list)
  local out = { { key = "own", name = L["Own"] } }
  for _, entry in ipairs(list) do
    out[#out + 1] = { key = entry.key, name = entry.name }
  end
  return out
end

-- One field: its name and a picker.
local function Field(parent, label, width, field, element)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, FIELD)
  frame.label = UI.Text(frame, "body", 12, "text")
  frame.label:SetPoint("LEFT", 0, 0)
  frame.label:SetWidth(70)
  frame.label:SetJustifyH("LEFT")
  frame.label:SetWordWrap(false)
  frame.label:SetText(label)
  local pick = UI.Picker(frame, width - 76, 24)
  pick:SetPoint("LEFT", 76, 0)
  pick.codexLabel = ("%s: %s"):format(element.label, label)
  pick.refresh = function(self)
    self:SetText(ns.FontStyleValueName(element.key, field))
  end
  pick:SetScript("OnClick", function(self)
    local choices
    if field == "font" then
      choices = FontChoices()
    elseif field == "size" then
      choices = SizeChoices(element)
    elseif field == "outline" then
      choices = Choices(ns.FONT_OUTLINES)
    else
      choices = Choices(ns.FONT_SHADOWS)
    end
    local style = ns.FontStyle(element.key) or {}
    ns.PickerMenu(self, choices, style[field] or "own", function(key)
      ns.SetFontStyle(element.key, field, key ~= "own" and key or nil)
    end)
  end)
  pick:refresh()
  frame.pick = pick
  return frame
end

-- One element: the header line, and its four fields while open.
local function ElementRow(body, element, width)
  local row = CreateFrame("Frame", nil, body)
  row:SetWidth(width)
  row.element = element
  local head = CreateFrame("Button", nil, row)
  head:SetPoint("TOPLEFT")
  head:SetPoint("TOPRIGHT")
  head:SetHeight(ROW)
  row.head = head
  local hover = head:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, ns.Theme().accent, 0.05)
  row.label = UI.Text(head, "head", 13, "accent")
  row.label:SetPoint("LEFT", 2, 0)
  row.label:SetText(element.label)
  row.fold = UI.Text(head, "body", 14, "muted")
  row.fold:SetPoint("RIGHT", -6, 0)
  row.reset = CreateFrame("Button", nil, head)
  row.reset:SetSize(44, 20)
  row.reset:SetPoint("RIGHT", row.fold, "LEFT", -12, 0)
  row.reset.label = UI.Text(row.reset, "body", 11, "muted")
  row.reset.label:SetPoint("RIGHT")
  row.reset.label:SetText(L["Reset"])
  row.reset.codexLabel = ("%s: %s"):format(element.label, L["Reset"])
  row.reset:SetScript("OnClick", function()
    ns.ResetFontStyle(element.key)
  end)
  head:SetScript("OnClick", function()
    open[element.key] = not open[element.key] or nil
    if body.Relayout then
      body.Relayout()
    end
    if type(ns.RefreshSections) == "function" then
      ns.RefreshSections() -- the page lays the sections out again for the new height
    end
  end)
  head.codexLabel = element.label
  local half = math.floor((width - 24) / 2)
  row.fields = {
    Field(row, L["Font"], half, "font", element),
    Field(row, L["Size"], half, "size", element),
    Field(row, L["Outline"], half, "outline", element),
    Field(row, L["Shadow"], half, "shadow", element),
  }
  for index, field in ipairs(row.fields) do
    local column = (index - 1) % 2
    local line = math.floor((index - 1) / 2)
    field:SetPoint("TOPLEFT", row, "TOPLEFT", 2 + column * (half + 20), -(ROW + 4 + line * (FIELD + 8)))
  end
  function row.Refresh()
    local isOpen = open[element.key] and true or false
    row.fold:SetText(isOpen and "-" or "+")
    local styled = ns.FontStyle(element.key) ~= nil
    row.reset:SetShown(styled)
    for _, field in ipairs(row.fields) do
      field:SetShown(isOpen)
      field.pick:refresh()
    end
    local height = isOpen and (ROW + 4 + 2 * (FIELD + 8) + 4) or ROW
    row:SetHeight(height)
    return height
  end
  return row
end

local function BuildGroup(group)
  return function(body, width, section)
    local rows = {}
    for _, element in ipairs(Elements(group.id)) do
      rows[#rows + 1] = ElementRow(body, element, width)
    end
    local note = UI.Text(body, "body", 11, "muted")
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["Anything left on \"Own\" stays as Codex draws it: the theme's font at the element's size."])
    note.size = 11
    body.fontRows = rows
    function body.Relayout()
      local y = 0
      note:ClearAllPoints()
      note:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
      y = ns.UITextHeight(note, 11, width) + 8
      for _, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + row.Refresh()
        if not row.line then
          row.line = UI.Divider(row)
          row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
          row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        end
      end
      body.height = y
      return y
    end
    body.Relayout()
    ns.fontSections = ns.fontSections or {}
    ns.fontSections[group.id] = body
    return {
      Height = function()
        return body.height or body.Relayout()
      end,
      Refresh = function()
        body.Relayout()
      end,
    }
  end
end

-- The info panel's preview: a sample line per element, drawn the way the game will draw it with the styles.
local function Preview(group)
  return function(holder, width)
    local frame = CreateFrame("Frame", nil, holder)
    frame:SetWidth(width)
    frame:SetPoint("TOPLEFT")
    local y = 0
    for _, element in ipairs(Elements(group.id)) do
      local label = UI.Text(frame, "body", 10, "muted")
      label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
      label:SetText(element.label)
      y = y + 14
      local sample = UI.Text(frame, "body", element.base, "text")
      sample:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
      sample:SetWidth(width)
      sample:SetJustifyH("LEFT")
      sample:SetWordWrap(true)
      sample:SetText(SAMPLES[element.key] or element.label)
      ns.RestyleFont(sample, element.key)
      local _, size = sample:GetFont()
      y = y + math.max(14, ns.UITextHeight(sample, type(size) == "number" and size or element.base, width)) + 10
    end
    frame:SetHeight(y)
    return frame
  end
end

for _, group in ipairs(ns.FONT_GROUPS) do
  ns.AddSection(group.area, {
    id = "fonts-" .. group.id,
    title = group.title,
    order = group.order,
    desc = L["Font, size, outline and shadow for each kind of text on this page. Hover a field to see its name here; the samples below follow your choices."],
    keywords = { "font size outline shadow text", L["font size outline shadow text"] },
    build = BuildGroup(group),
    preview = Preview(group),
  })
end

-- a change: the rows and the panel's samples follow at once
ns.OnFontStyle(function()
  for _, body in pairs(ns.fontSections or {}) do
    if body.Relayout then
      body.Relayout()
    end
  end
  if type(ns.RefreshInfo) == "function" then
    ns.RefreshInfo()
  end
end)
