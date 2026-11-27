local addonName, ns = ...
local L = ns.L

-- Stat Delta module, part 6: the module's page in the Codex window: the tooltip settings, the upgrade score
-- presets for the player's class and the points per stat (saved per character).

local S = ns.statdelta
local UI = ns.UI

local COLUMNS, COLUMN_WIDTH, ROW_HEIGHT = 3, 215, 24

local view = {}

-- key, label, what to refresh
local OPTIONS = {
  { "enabled", L["Show stat changes (hold Shift)"] },
  { "showScore", L["Show the upgrade score (hold Shift)"], true },
  { "showPrimary", L["Show Strength, Agility, Stamina, Intellect, Spirit"] },
  { "showArrows", L["Show upgrade arrows on items"], true },
}

function S.StatusText()
  local db = S.DB()
  if not (db and db.enabled) then
    return L["Stat changes in tooltips are off."]
  end
  local name = S.PresetName()
  if name then
    return L["Hold Shift over an item to compare it with your gear. Upgrade score: %s."]:format(name)
  end
  return L["Hold Shift over an item to compare it with your gear. Upgrade score off."]
end

local function FormatWeight(value)
  if not value or value == 0 then
    return ""
  end
  if value == math.floor(value) then
    return string.format("%d", value)
  end
  return (string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", ""))
end
S.FormatWeight = FormatWeight

local function StatLabel(key)
  for _, stat in ipairs(S.STATS) do
    if stat.key == key then
      return stat.weightLabel or stat.label -- percent stats: "Crit (1%)"
    end
  end
  return key
end

local function CommitWeight(box)
  local text = strtrim(box:GetText() or ""):gsub(",", ".")
  local value = text == "" and 0 or tonumber(text)
  -- not NaN ("nan") or infinite ("inf", "1e999")
  if value and value == value and math.abs(value) ~= math.huge then
    S.SetWeight(box.statKey, value)
  end
  box:SetText(FormatWeight(S.char.weights[box.statKey]))
end

local function WeightBox(parent, key, index)
  local column = (index - 1) % COLUMNS
  local row = math.floor((index - 1) / COLUMNS)
  local label = UI.Text(parent, "body", 12, "text")
  label:SetPoint("TOPLEFT", column * COLUMN_WIDTH, -row * ROW_HEIGHT - 4)
  label:SetWidth(COLUMN_WIDTH - 66)
  label:SetWordWrap(false)
  label:SetText(StatLabel(key))
  local box = UI.EditBox(parent, 52, 20)
  box:SetPoint("TOPLEFT", column * COLUMN_WIDTH + COLUMN_WIDTH - 62, -row * ROW_HEIGHT)
  box:SetMaxLetters(8)
  box.statKey = key
  box:SetScript("OnEscapePressed", function(self)
    self:SetText(FormatWeight(S.char.weights[self.statKey]))
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", CommitWeight)
  return box
end

local function PresetButtons(page, anchor)
  local entries = { { id = false, label = L["Off"] } }
  for _, preset in ipairs(S.GetPresets()) do
    entries[#entries + 1] = preset
  end
  view.presets = {}
  local previous
  for _, entry in ipairs(entries) do
    local button = UI.Button(page, entry.id and 108 or 60, 22, entry.label)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
      button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    end
    button.presetId = entry.id
    button:SetScript("OnClick", function(self)
      S.SetPreset(self.presetId or nil)
    end)
    if entry.id then
      button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(entry.label)
        GameTooltip:AddLine(L["Fills in rough starting values for this role. Your edited values are replaced."],
          1, 1, 1, true)
        GameTooltip:Show()
      end)
      button:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end
    view.presets[#view.presets + 1] = button
    previous = button
  end
  if #entries == 1 then
    local none = UI.Text(page, "body", 11, "muted")
    none:SetPoint("LEFT", previous, "RIGHT", 10, 0)
    none:SetText(L["No presets for your class: type your own points below."])
  end
  return view.presets[1]
end

function S.RefreshPage()
  if not view.page then
    return
  end
  local db, char = S.DB()
  local theme = ns.Theme()
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key] and true or false)
  end
  view.status:SetText(S.StatusText())
  for _, button in ipairs(view.presets) do
    local selected = button.presetId == char.preset or (button.presetId == false and not char.preset)
    button.textColor = selected and theme.good or nil
    button.label:SetTextColor(UI.Unpack(selected and theme.good or theme.button.text))
  end
  local name = S.PresetName()
  if name then
    local text = L["Score: %s"]
    if S.HasTwoTalentGroups() then
      text = S.ActiveTalentGroup() == 2 and L["Score (your secondary talents): %s"] or L["Score (your primary talents): %s"]
    end
    view.presetStatus:SetText(text:format(name))
  else
    view.presetStatus:SetText(L["The score is off. Pick a preset (or type a number of points) to turn it on."])
  end
  for _, box in ipairs(view.boxes) do
    if not box:HasFocus() then
      box:SetText(FormatWeight(char.weights[box.statKey]))
    end
  end
end

-- One of the options (also from the Tooltips page's "Prices and stats in tooltips").
function S.SetOption(key, on)
  S.DB()[key] = on and true or false
  local score
  for _, option in ipairs(OPTIONS) do
    if option[1] == key then
      score = option[3]
    end
  end
  if score then
    S.ScoreChanged()
  else
    if S.running then
      S.Refresh()
    end
    S.RefreshPage()
  end
end

function S.BuildPage(page)
  S.DB()
  view.page = page
  local heading = UI.Heading(page, "Stat Delta", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  view.checks = {}
  for index, option in ipairs(OPTIONS) do
    local check = UI.Check(page, option[2])
    check.key = option[1]
    local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
    check:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", column * 330, -12 - row * 26)
    check:SetHitRectInsets(0, -(check.label:GetStringWidth() + 4), 0, 0)
    check:SetScript("OnClick", function(self)
      S.SetOption(self.key, self:GetChecked())
    end)
    view.checks[#view.checks + 1] = check
  end

  local score = UI.Text(page, "head", 12, "accent")
  score:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -78)
  score:SetText(L["UPGRADE SCORE"])
  local help = UI.Text(page, "body", 12, "text")
  help:SetPoint("TOPLEFT", score, "BOTTOMLEFT", 0, -6)
  help:SetPoint("RIGHT", 0, 0)
  help:SetWordWrap(true)
  help:SetText(L["Points per stat, saved for this character."] .. " "
    .. L["The score of an item is the sum of its stats times these points; with Shift, the tooltip shows it against your gear, and upgrades get a green arrow in your bags and on quest rewards."]
    .. " " .. L["The presets are rough starting values, not exact numbers: change them as you like."])

  local first = PresetButtons(page, help)
  view.presetStatus = UI.Text(page, "body", 12, "good")
  view.presetStatus:SetPoint("TOPLEFT", first, "BOTTOMLEFT", 0, -8)
  view.presetStatus:SetPoint("RIGHT", 0, 0)

  local note = UI.Text(page, "body", 11, "muted")
  note:SetPoint("TOPLEFT", view.presetStatus, "BOTTOMLEFT", 0, -6)
  note:SetPoint("RIGHT", 0, 0)
  note:SetWordWrap(true)
  note:SetText(L["Attack Power, Ranged Attack Power, Health, Mana and Armor include what Strength, Agility, Stamina and Intellect give you."]
    .. " " .. L["Give points to a stat or to what it turns into, not both."])

  local grid = CreateFrame("Frame", nil, page)
  grid:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -10)
  grid:SetSize(COLUMNS * COLUMN_WIDTH, math.ceil(#S.WEIGHT_STATS / COLUMNS) * ROW_HEIGHT)
  view.boxes = {}
  for index, key in ipairs(S.WEIGHT_STATS) do
    view.boxes[#view.boxes + 1] = WeightBox(grid, key, index)
  end

  S.RefreshPage()
end
