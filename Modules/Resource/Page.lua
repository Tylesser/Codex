local addonName, ns = ...

-- Personal bars, part 3: the module's page (which bars; width, when they show, text, layout) and its registration.

local R = ns.resource
local UI = ns.UI
local view = { checks = {}, steppers = {} }
R.pageView = view -- (for the test)

local ICON = "Interface\\Icons\\Spell_Nature_Rejuvenation"
local COLUMN_GAP, ROW = 30, 26

-- Left column: which bars. indent: belongs to the row above.
local BARS = {
  { key = "health", name = "Health" },
  { key = "power", name = "Power (mana, rage or energy)" },
  { key = "fsr", name = "Five-second rule spark", indent = true },
  { key = "ticks", name = "Mana and energy ticks", indent = true },
  { key = "druidMana", name = "Druid: mana while in a form" },
  { key = "combo", name = "Combo points (rogue, druid in cat form)" },
  { key = "seal", name = "Paladin: seal time left" },
  { key = "swing", name = "Swing timer (main and off hand)" },
  { key = "ranged", name = "Ranged swing timer" },
  { key = "standStill", name = "Stand-still zone (its last half second)", indent = true },
}
R.PAGE_BARS = BARS

R.SHOW_MODES = { { key = "always", name = "Always" }, { key = "combat", name = "Only in combat" } }

local function NameOf(list, key)
  for _, item in ipairs(list) do
    if item.key == key then
      return item.name
    end
  end
  return list[1].name
end

function R.StatusText()
  local state = ns.ModuleState("resource")
  if state ~= "on" then
    return "Off: switch it on at the top of this section (then reload)."
  end
  if not R.running then
    return "On after a reload."
  end
  local where = R.Beside() and "beside" or "under"
  return R.DB().show == "combat" and ("Shown " .. where .. " your character in combat.")
    or ("Shown " .. where .. " your character.")
end

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

-- The size steppers (R.SIZES): key, label; side = only for the bars beside the character.
local STEPPERS = {
  { key = "width", name = "Width" },
  { key = "sideGap", name = "Side gap", side = true },
  { key = "sideHeight", name = "Side height", side = true },
  { key = "sideWidth", name = "Side width", side = true },
}

function R.RefreshPage()
  if not view.page then
    return
  end
  local db = R.DB()
  view.status:SetText(R.StatusText())
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key] and true or false)
  end
  local beside = R.Beside()
  for _, stepper in ipairs(view.steppers) do
    local value, range = R.Size(stepper.key), R.SIZES[stepper.key]
    local on = not stepper.side or beside
    stepper.value:SetText(tostring(value))
    stepper.less:SetEnabled(on and value > range[1])
    stepper.more:SetEnabled(on and value < range[2])
    stepper.value:SetAlpha(on and 1 or 0.5)
    stepper.label:SetAlpha(on and 1 or 0.5)
  end
  view.show:SetText(NameOf(R.SHOW_MODES, db.show))
  view.text:SetText(NameOf(R.TEXT_MODES, R.TextMode()))
  view.layout:SetText(NameOf(R.LAYOUTS, beside and "beside" or "under"))
  view.fade:SetEnabled(db.show ~= "combat")
  view.fade.label:SetAlpha(db.show ~= "combat" and 1 or 0.5)
end

function R.BuildPage(page)
  R.DB()
  view.page = page
  local width = ns.PAGE_WIDTH or 672
  local columnWidth = math.floor((width - COLUMN_GAP) / 2)

  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT")
  icon:SetTexture(ICON)
  if icon.SetTexCoord then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local heading = UI.Heading(page, "Personal bars", 22)
  heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
  view.status = Wrap(UI.Text(page, "body", 13, "muted"))
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)

  local about = Wrap(UI.Text(page, "body", 13, "text"))
  about:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
  about:SetSpacing(2)
  about:SetText("Slim health and power bars under or beside your character, with the timers that matter in a fight. "
    .. "A spark crosses the mana bar for five seconds after you spend mana (no spirit regeneration then); a "
    .. "fainter one shows when the next mana or energy tick comes. Seal and swing rows show only while they run.")

  -- left: which bars
  local bars = UI.Section(page, "Bars")
  bars:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  for index, bar in ipairs(BARS) do
    local check = UI.Check(page, bar.name)
    check.key = bar.key
    check:SetPoint("TOPLEFT", bars, "BOTTOMLEFT", (bar.indent and 22 or 0) - 2, -6 - (index - 1) * ROW)
    check:SetScript("OnClick", function(self)
      R.Set(bar.key, self:GetChecked() and true or false)
    end)
    view.checks[#view.checks + 1] = check
  end

  -- right: sizes, when they show, text, layout, place (one line every LINE pixels)
  local look = UI.Section(page, "Look and place")
  look:SetPoint("TOPLEFT", about, "BOTTOMLEFT", columnWidth + COLUMN_GAP, -16)
  local LABEL, LINE = 92, 30
  local function Label(line, text)
    local label = UI.Text(page, "body", 13, "text")
    label:SetPoint("TOPLEFT", look, "BOTTOMLEFT", 0, -12 - line * LINE)
    label:SetText(text)
    return label
  end
  local function Stepper(line, spec)
    local label = Label(line, spec.name)
    local stepper = UI.Stepper(page, 48)
    stepper:SetPoint("LEFT", label, "LEFT", LABEL, 0)
    stepper.key, stepper.side, stepper.label = spec.key, spec.side, label
    local step = R.SIZES[spec.key][3]
    stepper.less:SetScript("OnClick", function()
      R.Set(spec.key, R.Size(spec.key) - step)
    end)
    stepper.more:SetScript("OnClick", function()
      R.Set(spec.key, R.Size(spec.key) + step)
    end)
    view.steppers[#view.steppers + 1] = stepper
    return stepper
  end
  -- a picker of list's items for db[key]
  local function Picker(line, text, list, key, current)
    local label = Label(line, text)
    local picker = UI.Picker(page, math.min(180, columnWidth - LABEL), 24)
    picker:SetPoint("LEFT", label, "LEFT", LABEL, 0)
    picker:SetScript("OnClick", function(self)
      local items = {}
      for _, item in ipairs(list) do
        items[#items + 1] = { text = item.name, checked = current() == item.key, func = function()
          R.Set(key, item.key)
        end }
      end
      UI.ShowMenu(self, items)
    end)
    return picker
  end

  Stepper(0, STEPPERS[1])
  view.show = Picker(1, "Show", R.SHOW_MODES, "show", function() return R.DB().show end)
  view.fade = UI.Check(page, "Fade out of combat")
  view.fade.key = "fade"
  view.fade:SetPoint("TOPLEFT", look, "BOTTOMLEFT", -2, -12 - 2 * LINE + 4)
  view.fade:SetScript("OnClick", function(self)
    R.Set("fade", self:GetChecked() and true or false)
  end)
  view.checks[#view.checks + 1] = view.fade
  view.text = Picker(3, "Text", R.TEXT_MODES, "text", R.TextMode)
  view.layout = Picker(4, "Layout", R.LAYOUTS, "layout", function() return R.Beside() and "beside" or "under" end)
  for index = 2, #STEPPERS do
    Stepper(3 + index, STEPPERS[index])
  end
  local sideNote = UI.Text(page, "body", 12, "muted")
  sideNote:SetPoint("TOPLEFT", look, "BOTTOMLEFT", 0, -12 - (#STEPPERS + 4) * LINE + 6)
  sideNote:SetWidth(columnWidth)
  sideNote:SetJustifyH("LEFT")
  sideNote:SetText("Beside: health on the left, power on the right, the text at their tops; combo points and "
    .. "timers stay under your character, as wide as Width. Short numbers (1.9K) follow Unit frames > Player, target, pet and focus.")

  local reset = UI.Button(page, 150, 24, "Reset position")
  reset:SetPoint("TOPLEFT", sideNote, "BOTTOMLEFT", 0, -10)
  reset:SetScript("OnClick", function()
    R.ResetPosition()
  end)
  local moveNote = UI.Text(page, "body", 12, "muted")
  moveNote:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -6)
  moveNote:SetWidth(columnWidth)
  moveNote:SetJustifyH("LEFT")
  moveNote:SetText("To move the bars open Edit Mode and drag the box over them; right-click the box puts them back. "
    .. "Each layout keeps its own place.")

  ns.On("RESOURCE_CHANGED", function()
    if view.page:IsVisible() then
      R.RefreshPage()
    end
  end)
  R.RefreshPage()
end

ns.RegisterModule({
  id = "resource",
  name = "Personal bars",
  -- its section in the Codex window (Areas.lua)
  area = "units", sectionOrder = 50, folded = true, pageEstimate = 430,
  icon = ICON,
  desc = "Health and power under your character, with the five-second rule, seal and swing timers.",
  default = false,
  order = 96,
  Enable = function()
    R.Enable()
  end,
  BuildPage = function(_, page)
    R.BuildPage(page)
  end,
  ShowPage = function()
    R.RefreshPage()
  end,
  Status = function()
    return R.StatusText()
  end,
})
