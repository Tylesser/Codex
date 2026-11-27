local addonName, ns = ...
local L = ns.L

-- Info bars, part 4: the module page (show each bar, the screen bar's edge, what each slot shows, the clock)
-- and registration.

local I = ns.infobar
local UI = ns.UI

local view = { rows = {} }
I.pageView = view

local LABEL_WIDTH = 92
local COLUMN_GAP = 30

local POSITIONS = { { id = "top", name = L["Top of the screen"] }, { id = "bottom", name = L["Bottom of the screen"] } }

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetSpacing(2)
  return text
end

function I.StatusText()
  if not I.running then
    return L["Off: no info bars."]
  end
  local db = I.DB()
  local parts = {}
  if db.top then
    local atTop = db.position ~= "bottom"
    if I.AtTop then
      atTop = I.AtTop()
    end
    parts[#parts + 1] = atTop and L["Screen bar at the top"] or L["Screen bar at the bottom"]
    if I.fit and I.fit.width then
      parts[#parts + 1] = L["%d px wide"]:format(I.fit.width)
    end
  end
  if db.panel then
    parts[#parts + 1] = L["data panel under the chat"]
  end
  if #parts == 0 then
    return L["Both bars are hidden. Show them below."]
  end
  local text = table.concat(parts, ", ")
  return text:sub(1, 1):upper() .. text:sub(2) .. "."
end

local function TextName(id)
  local text = I.TEXTS[id]
  return text and text.name or L["Nothing"]
end

local function Join(list)
  if #list == 0 then
    return L["nothing"]
  end
  if #list == 1 then
    return list[1]
  end
  return L["%s and %s"]:format(table.concat(list, ", ", 1, #list - 1), list[#list])
end

-- The page's note: what was moved out of the bar's way (or what it runs under), and with the fit option the
-- bar's width, the fallback to the bottom edge and the texts that got no room. "" when there is nothing to say.
function I.OverlapText()
  local db = I.DB()
  if not (I.running and db.top) then
    return ""
  end
  local parts = {}
  local fit = I.fit
  local moved = I.MovedNames and I.MovedNames() or {}
  if #moved > 0 then
    parts[#parts + 1] = L["Moved out of the bar's way: %s. \"Put them back\" restores their places."]:format(Join(moved))
  end
  if db.fit then
    if fit and fit.fallback then
      parts[#parts + 1] = L["The top edge leaves only %d px beside %s, so the bar is at the bottom."]
        :format(fit.topWidth or 0, Join(fit.topNames or {}))
    end
    if fit and fit.width and #fit.names > 0 then
      parts[#parts + 1] = L["Fitted to %d px, making room for %s."]:format(fit.width, Join(fit.names))
    end
    if I.dropped and #I.dropped > 0 then
      parts[#parts + 1] = L["No room for %s: move those frames a little in Edit Mode, or show fewer texts."]
        :format(Join(I.dropped))
    end
  else
    local names = I.Overlaps and I.Overlaps() or {}
    if #names > 0 then
      parts[#parts + 1] = L["The bar runs under %s (they draw on top of it). \"Make room\" moves them out of its way."]
        :format(Join(names))
    end
  end
  return table.concat(parts, " ")
end

local function RefreshPage()
  if not view.page then
    return
  end
  local db = I.DB()
  view.status:SetText(I.StatusText())
  view.top:SetChecked(db.top)
  view.panel:SetChecked(db.panel)
  view.clock:SetChecked(db.clock24)
  view.position:SetText(db.position == "bottom" and POSITIONS[2].name or POSITIONS[1].name)
  view.full:SetChecked(db.fit and true or false)
  view.makeRoom:SetEnabled(db.top)
  view.putBack:SetEnabled(next(I.moved or {}) ~= nil)
  local note = I.running and db.top and I.OverlapText() or ""
  view.overlap:SetText(note)
  view.overlap:SetShown(note ~= "")
  for _, row in ipairs(view.rows) do
    row.picker:SetText(TextName(db.slots[row.key]))
    local on = row.bar == "top" and db.top or (row.bar == "panel" and db.panel)
    row.picker:SetAlpha(on and 1 or 0.5)
    row.label:SetAlpha(on and 1 or 0.5)
  end
  if I.LayoutPage then
    I.LayoutPage() -- the note under the buttons may have changed height
  end
end
I.RefreshPage = RefreshPage

local function OpenPicker(button, title, choices, current, onPick)
  local items = { { text = title, title = true } }
  for _, choice in ipairs(choices) do
    items[#items + 1] = { text = choice.name, checked = current == choice.id, func = function()
      onPick(choice.id)
    end }
  end
  UI.ShowMenu(button, items)
  local menu = _G.CodexMenu
  if type(menu) == "table" and menu.ClearAllPoints then
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
  end
end

local function TextChoices()
  local list = {}
  for _, id in ipairs(I.MENU_ORDER) do
    list[#list + 1] = { id = id, name = I.TEXTS[id].name }
  end
  list[#list + 1] = { id = "none", name = L["Nothing"] }
  return list
end

-- When the module is off the settings are still saved; they show after it is switched on.
local function Change(key, value)
  if I.running then
    I.Set(key, value)
  else
    I.DB()[key] = value
  end
  RefreshPage()
end

-- Layout ---------------------------------------------------------------------------------------------------------
-- Everything sits in a scroll area and is stacked by measured heights: texts are bound to their column's width
-- and wrap in it; a text measures 0 until it is first drawn, so the page lays itself out again when shown (and
-- on the next frame, when the real heights are known). Two columns, one under the other when the page is narrow.

local PAD_BOTTOM = 16
local NARROW = 560 -- below this the right column goes under the left one

-- A font string's height at its width; before it is drawn (or in tests) worked out from its text's length.
local function TextHeight(text)
  if not text:IsShown() or (text:GetText() or "") == "" then
    return 0
  end
  local height = I.Num(text:GetStringHeight())
  if height and height > 0 then
    return height
  end
  local width = I.Num(text:GetWidth()) or 0
  local lines = width > 0 and math.max(1, math.ceil((I.Num(text:GetStringWidth()) or 0) / width)) or 1
  return lines * (text.lineHeight or 16)
end

-- A row of the page: label + picker, a check box, buttons, a text, a section title.
local function Item(kind, region, height, gap, indent)
  return { kind = kind, region = region, height = height, gap = gap or 8, indent = indent or 0 }
end

local function Layout()
  local body = view.body
  if not body then
    return
  end
  local width = math.floor((I.Num(view.scroll:GetWidth()) or 0) - 12)
  if width < 200 then
    width = (ns.PAGE_WIDTH or 672) - 12
  end
  body:SetWidth(width)
  local narrow = width < NARROW
  local columnWidth = narrow and width or math.floor((width - COLUMN_GAP) / 2)
  view.columnWidth = columnWidth
  view.placed = {}

  local function Stack(items, x, y, colWidth)
    for _, item in ipairs(items) do
      local region = item.region
      local shown = not region.IsShown or region:IsShown()
      if item.kind == "text" then
        region:SetWidth(colWidth - item.indent)
      elseif item.kind == "row" then
        region:SetWidth(colWidth)
        if region.Fit then
          region:Fit(colWidth)
        end
      end
      local height = item.kind == "text" and TextHeight(region) or item.height
      if shown and height > 0 then
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", body, "TOPLEFT", x + item.indent, -y)
        view.placed[#view.placed + 1] = { region = region, x = x + item.indent, y = y, height = height,
          width = colWidth - item.indent }
        y = y + height + item.gap
      end
    end
    return y
  end

  -- header (full width), then the columns
  local y = Stack(view.header, 0, 0, width)
  local top = y + 8
  local leftEnd = Stack(view.left, 0, top, columnWidth)
  if narrow then
    Stack(view.right, 0, leftEnd + 8, columnWidth)
  else
    Stack(view.right, columnWidth + COLUMN_GAP, top, columnWidth)
  end
  local lowest = 0
  for _, entry in ipairs(view.placed) do
    lowest = math.max(lowest, entry.y + entry.height)
  end
  body:SetHeight(lowest + PAD_BOTTOM)
  view.scroll:Update()
end
I.LayoutPage = Layout

-- Page widgets -------------------------------------------------------------------------------------------------

local function Text(parent, size, color)
  local text = Wrap(UI.Text(parent, "body", size, color))
  text.lineHeight = size + 4
  return text
end

-- Label + picker on one line; the picker fills the column after the label.
local function PickerRow(parent, labelText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(24)
  row.label = UI.Text(row, "body", 13, "text")
  row.label:SetPoint("LEFT")
  row.label:SetWidth(LABEL_WIDTH - 8)
  row.label:SetWordWrap(false)
  row.label:SetText(labelText)
  row.picker = UI.Picker(row, 200, 24)
  row.picker:SetPoint("LEFT", LABEL_WIDTH, 0)
  function row:Fit(width)
    self.picker:SetWidth(math.max(80, width - LABEL_WIDTH))
  end
  return row
end

local function SlotRows(parent, bar, items)
  for _, info in ipairs(I.SLOTS) do
    if info.bar == bar then
      local row = PickerRow(parent, info.name)
      row.picker:SetScript("OnClick", function(self)
        OpenPicker(self, L["Show in this slot"], TextChoices(), I.DB().slots[info.key], function(id)
          if I.running then
            I.SetSlot(info.key, id)
          else
            I.DB().slots[info.key] = id
          end
          RefreshPage()
        end)
      end)
      view.rows[#view.rows + 1] = { key = info.key, bar = bar, picker = row.picker, label = row.label }
      items[#items + 1] = Item("row", row, 24, 4)
    end
  end
  items[#items].gap = 14
end

function I.BuildPage(page)
  I.DB()
  view.page = page
  local scroll, body = UI.ScrollArea(page)
  scroll:SetPoint("TOPLEFT")
  scroll:SetPoint("BOTTOMRIGHT")
  view.scroll, view.body = scroll, body
  body:SetWidth((ns.PAGE_WIDTH or 672) - 12)

  -- header: the module's icon, its name and the live status line, then what the module does
  local head = CreateFrame("Frame", nil, body)
  head:SetHeight(36)
  local icon = head:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT")
  icon:SetTexture(ns.modules.infobar.icon)
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local heading = UI.Heading(head, L["Info bars"], 22)
  heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
  view.status = UI.Text(head, "body", 13, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)
  view.status:SetWordWrap(false)
  local about = Text(body, 13, "text")
  about:SetText(L["A slim bar along the screen edge and a data panel under the chat window, with your gold, bags, location, experience and more. Point at a slot for details, click it to open its window, right-click it to choose what it shows."])
  view.header = { Item("row", head, 36, 12), Item("text", about, 0, 8) }

  -- left column: the screen bar
  local left = {}
  left[#left + 1] = Item("title", UI.Section(body, L["Screen bar"]), 14, 6)
  view.top = UI.Check(body, L["Show the screen bar"])
  view.top:SetScript("OnClick", function(self)
    Change("top", self:GetChecked() and true or false)
  end)
  left[#left + 1] = Item("check", view.top, 20, 8, -2)
  local positionRow = PickerRow(body, L["Position"])
  view.position = positionRow.picker
  view.position:SetScript("OnClick", function(self)
    OpenPicker(self, L["Screen bar"], POSITIONS, I.DB().position, function(id)
      Change("position", id)
    end)
  end)
  left[#left + 1] = Item("row", positionRow, 24, 12)

  -- the frames at the bar's edge: moved out of its way (default), or the bar fits beside them (option)
  local buttons = CreateFrame("Frame", nil, body)
  buttons:SetHeight(24)
  view.makeRoom = UI.Button(buttons, 110, 24, L["Make room"])
  view.makeRoom:SetPoint("LEFT")
  view.makeRoom:SetScript("OnClick", function()
    I.DB().room = true
    local names = I.MakeRoom()
    if names == nil then
      ns.Say(L["the frames move out of the bar's way after the fight."])
    elseif #names == 0 then
      ns.Say(L["nothing sits in the bar's way."])
    end
    RefreshPage()
  end)
  view.putBack = UI.Button(buttons, 110, 24, L["Put them back"])
  view.putBack:SetPoint("LEFT", view.makeRoom, "RIGHT", 8, 0)
  view.putBack:SetScript("OnClick", function()
    I.PutBack()
    RefreshPage()
  end)
  left[#left + 1] = Item("row", buttons, 24, 6)
  -- what was moved (or what the bar runs under): right under the buttons, hidden when there is nothing to say
  view.overlap = Text(body, 12, "warn")
  left[#left + 1] = Item("text", view.overlap, 0, 6)
  local roomNote = Text(body, 12, "muted")
  roomNote:SetText(L["Moves the minimap, buffs and bars at the bar's edge out of its way, and again after Edit Mode. Frames you place elsewhere are left alone. For this session only: Codex never writes Edit Mode layouts, so it happens again at every login."])
  left[#left + 1] = Item("text", roomNote, 0, 10)
  view.full = UI.Check(body, L["Fit the bar beside those frames instead"])
  view.full:SetScript("OnClick", function(self)
    Change("fit", self:GetChecked() and true or false)
  end)
  left[#left + 1] = Item("check", view.full, 20, 14, -2)
  local slotsLeft = Text(body, 12, "muted")
  slotsLeft:SetText(L["What each slot shows"])
  left[#left + 1] = Item("text", slotsLeft, 0, 6)
  SlotRows(body, "top", left)
  view.left = left

  -- right column: the chat panel and the clock
  local right = {}
  right[#right + 1] = Item("title", UI.Section(body, L["Chat panel"]), 14, 6)
  view.panel = UI.Check(body, L["Show the data panel under the chat"])
  view.panel:SetScript("OnClick", function(self)
    Change("panel", self:GetChecked() and true or false)
  end)
  right[#right + 1] = Item("check", view.panel, 20, 8, -2)
  local panelNote = Text(body, 12, "muted")
  panelNote:SetText(L["Its corner buttons hide the chat (click again to show it) and copy the chat's recent lines."])
  right[#right + 1] = Item("text", panelNote, 0, 12)
  local slotsRight = Text(body, 12, "muted")
  slotsRight:SetText(L["What each slot shows"])
  right[#right + 1] = Item("text", slotsRight, 0, 6)
  SlotRows(body, "panel", right)
  right[#right + 1] = Item("title", UI.Section(body, L["Clock"]), 14, 6)
  view.clock = UI.Check(body, L["24-hour clock"])
  view.clock:SetScript("OnClick", function(self)
    Change("clock24", self:GetChecked() and true or false)
  end)
  right[#right + 1] = Item("check", view.clock, 20, 8, -2)
  view.right = right

  scroll:HookScript("OnSizeChanged", Layout)
  page:HookScript("OnShow", function()
    Layout()
    C_Timer.After(0, Layout) -- the texts' real heights, once drawn
  end)
  ns.On("INFOBAR_CHANGED", function()
    if view.page:IsVisible() then
      RefreshPage()
    end
  end)
  RefreshPage()
end

ns.RegisterModule({
  id = "infobar",
  name = L["Info bars"],
  -- its section in the Codex window (Areas.lua)
  area = "info", sectionOrder = 10, pageEstimate = 600,
  icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
  desc = L["A slim bar along the screen edge and a panel under the chat: gold, bags, location, experience, reputation, clock, frame rate, friends, guild and durability."],
  order = 99,
  Enable = function()
    I.Enable()
  end,
  BuildPage = function(_, page)
    I.BuildPage(page)
  end,
  ShowPage = function()
    RefreshPage()
    C_Timer.After(0, function()
      if I.LayoutPage then
        I.LayoutPage()
      end
    end)
  end,
  Status = function()
    return I.StatusText()
  end,
  commands = {
    -- /codex copychat
    copychat = function()
      I.ShowCopy()
    end,
  },
})
