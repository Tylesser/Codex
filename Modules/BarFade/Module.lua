local addonName, ns = ...
local L = ns.L

-- Action bar visibility, part 2: its page in the Codex window (one row per bar with its mode, the faded
-- opacity, "Show all now") and registration.

local BF = ns.barfade
local UI = ns.UI

local view = { rows = {} }

local ROW_HEIGHT = 30
local ACTION_BARS = 8 -- the first 8 of BF.BARS (main bar, bars 2-8) go left, the rest right ("Other bars")
local LABEL_WIDTH = 112
local MENU_WIDTH = 210
local COLUMN_GAP = 30

function BF.StatusText()
  if not BF.running then
    return L["Off: the action bars stay as the game shows them."]
  end
  local count = BF.FadingCount()
  if count == 0 then
    return L["Every bar is always shown. Pick when a bar shows below."]
  end
  return (count == 1 and L["%d bar fades when not needed"] or L["%d bars fade when not needed"]):format(count)
end

local function RefreshPage()
  if not view.page then
    return
  end
  view.status:SetText(BF.StatusText())
  local theme = ns.Theme()
  for _, row in ipairs(view.rows) do
    local mode = BF.Mode(row.key)
    row.menu:SetText(BF.ModeName(mode))
    -- "Always" in the plain text colour, a fading mode brighter
    row.menu.label:SetTextColor(UI.Unpack(mode == "always" and theme.text or theme.bright))
  end
  view.faded:SetText(("%d%%"):format(math.floor(BF.Faded() * 100 + 0.5)))
  view.minus:SetEnabled(BF.Faded() > 0)
  view.plus:SetEnabled(BF.Faded() < 0.5)
  view.preview:SetChecked(BF.state.preview)
end
BF.RefreshPage = RefreshPage

local function OpenMenu(button, key)
  local items = { { text = BF.BarName(key), title = true } }
  for _, mode in ipairs(BF.MODES) do
    items[#items + 1] = {
      text = mode.name,
      checked = BF.Mode(key) == mode.id,
      func = function()
        BF.SetMode(key, mode.id)
      end,
    }
  end
  UI.ShowMenu(button, items)
  -- under the button rather than to its left
  local menu = _G.CodexMenu
  if type(menu) == "table" and menu.ClearAllPoints then
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
  end
end

function BF.BarName(key)
  for _, bar in ipairs(BF.BARS) do
    if bar.key == key then
      return bar.name
    end
  end
  return key
end

function BF.BuildPage(page)
  BF.DB()
  view.page = page
  local width = ns.PAGE_WIDTH or 672
  local columnWidth = math.floor((width - COLUMN_GAP) / 2)

  -- header: the module's icon, its name and the live status line
  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT")
  icon:SetTexture(ns.modules.barfade and ns.modules.barfade.icon or "Interface\\Icons\\Spell_Nature_Invisibilty")
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local heading = UI.Heading(page, L["Action bar visibility"], 22)
  heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
  view.status = UI.Text(page, "body", 13, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  local about = UI.Text(page, "body", 13, "text")
  about:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
  about:SetPoint("RIGHT", 0, 0)
  about:SetJustifyH("LEFT")
  about:SetSpacing(2)
  about:SetText(L["Choose when each bar shows. Faded bars come back while you drag a spell or item, while the spell book or Edit Mode is open, and the main bar in a vehicle. Mouse-over bars stay a moment after the mouse leaves. \"Never\" makes a bar invisible but its buttons still work (keys and clicks)."])

  -- two columns: "Action bars" and "Other bars", one row per bar (its name, then a picker with its mode)
  local sections = {}
  for column, title in ipairs({ L["Action bars"], L["Other bars"] }) do
    local label = UI.Section(page, title)
    label:SetPoint("TOPLEFT", about, "BOTTOMLEFT", (column - 1) * (columnWidth + COLUMN_GAP), -16)
    sections[column] = label
  end
  for index, bar in ipairs(BF.BARS) do
    local column = index <= ACTION_BARS and 1 or 2
    local line = column == 1 and index - 1 or index - ACTION_BARS - 1
    local menu = UI.Picker(page, math.min(MENU_WIDTH, columnWidth - LABEL_WIDTH), 24)
    menu:SetPoint("TOPLEFT", sections[column], "BOTTOMLEFT", LABEL_WIDTH, -8 - line * ROW_HEIGHT)
    menu:SetScript("OnClick", function(self)
      OpenMenu(self, bar.key)
    end)
    local label = UI.Text(page, "body", 13, "text")
    label:SetPoint("RIGHT", menu, "LEFT", -8, 0)
    label:SetWidth(LABEL_WIDTH - 8)
    label:SetJustifyH("LEFT")
    label:SetText(bar.name)
    view.rows[#view.rows + 1] = { key = bar.key, label = label, menu = menu }
  end

  -- "Fading", under the other bars: the faded opacity and "Show all now"
  local others = #BF.BARS - ACTION_BARS
  local fading = UI.Section(page, L["Fading"])
  fading:SetPoint("TOPLEFT", sections[2], "BOTTOMLEFT", 0, -8 - others * ROW_HEIGHT - 14)
  local stepper = UI.Stepper(page, 48)
  stepper:SetPoint("TOPLEFT", fading, "BOTTOMLEFT", LABEL_WIDTH, -8)
  view.minus, view.faded, view.plus = stepper.less, stepper.value, stepper.more
  local fadedLabel = UI.Text(page, "body", 13, "text")
  fadedLabel:SetPoint("RIGHT", stepper, "LEFT", -8, 0)
  fadedLabel:SetWidth(LABEL_WIDTH - 8)
  fadedLabel:SetJustifyH("LEFT")
  fadedLabel:SetText(L["Faded opacity"])
  view.minus:SetScript("OnClick", function()
    BF.SetFaded(BF.Faded() - 0.05)
  end)
  view.plus:SetScript("OnClick", function()
    BF.SetFaded(BF.Faded() + 0.05)
  end)
  local fadedNote = UI.Text(page, "body", 12, "muted")
  fadedNote:SetPoint("TOPLEFT", stepper, "BOTTOMLEFT", 0, -4)
  fadedNote:SetWidth(columnWidth - LABEL_WIDTH)
  fadedNote:SetJustifyH("LEFT")
  fadedNote:SetText(L["How much of a faded bar still shows (0% = invisible)."])

  view.preview = UI.Check(page, L["Show all now"])
  view.preview:SetPoint("TOPLEFT", fading, "BOTTOMLEFT", -2, -64)
  view.preview:SetScript("OnClick", function(self)
    BF.SetPreview(self:GetChecked())
  end)
  local previewNote = UI.Text(page, "body", 12, "muted")
  previewNote:SetPoint("TOPLEFT", view.preview.label, "BOTTOMLEFT", 0, -2)
  previewNote:SetWidth(columnWidth - 30)
  previewNote:SetJustifyH("LEFT")
  previewNote:SetText(L["Every bar at full until you untick this or reload."])

  -- at the bottom, under a line: how this works with Edit Mode
  local editNote = UI.Text(page, "body", 12, "muted")
  editNote:SetPoint("TOP", previewNote, "BOTTOM", 0, -28) -- under the taller right column
  editNote:SetPoint("LEFT", page, "LEFT", 0, 0)
  editNote:SetPoint("RIGHT", 0, 0)
  editNote:SetJustifyH("LEFT")
  editNote:SetText(L["Edit Mode has its own \"Bar Visible\" setting for each bar. A bar Edit Mode hides stays hidden; the mode chosen here works on top of it."])
  local line = UI.Divider(page)
  line:SetPoint("BOTTOMLEFT", editNote, "TOPLEFT", 0, 8)
  line:SetPoint("RIGHT", 0, 0)

  ns.On("BARFADE_CHANGED", function()
    if view.page:IsVisible() then
      RefreshPage()
    end
  end)
  RefreshPage()
end

ns.RegisterModule({
  id = "barfade",
  name = L["Action bar visibility"],
  -- its section in the Codex window (Areas.lua)
  area = "bars", sectionOrder = 20, sectionTitle = L["Visibility"], pageEstimate = 470,
  icon = "Interface\\Icons\\Spell_Nature_Invisibilty",
  desc = L["Choose when each action bar shows: on mouse-over, only in combat, out of combat or never."],
  order = 95,
  Enable = function()
    BF.Enable()
  end,
  BuildPage = function(_, page)
    BF.BuildPage(page)
  end,
  ShowPage = function()
    RefreshPage()
  end,
  Status = function()
    return BF.StatusText()
  end,
  -- /codex barfade show: every bar at full (again: back to their modes)
  Slash = function(_, rest)
    if rest:lower() == "show" and BF.running then
      BF.SetPreview(not BF.state.preview)
      ns.Say(BF.state.preview and L["Every action bar is shown. /codex barfade show again to fade them."]
        or L["The action bars fade as set again."])
    else
      ns.ShowPage("barfade")
    end
  end,
})
