local addonName, ns = ...

-- Bags module, part 5: its page in the Codex window. Options, and the list of characters Codex knows with
-- their money (include or leave out of totals and tooltips, delete a character's data).

local B = ns.bags
local UI = ns.UI

local view = {}
B.pageView = view

local OPTIONS = {
  { key = "replace", text = "Open Codex bags instead of the game's", note = "Your bag keys and bag buttons open the Codex window." },
  { key = "categories", text = "Group items into categories", note = "Off: every slot in bag order." },
  { key = "pack", text = "Pack categories side by side", note = "Small categories share a row. Off: one category per row." },
  { key = "combine", text = "Combine identical items", note = "One button with the total; one by one at the bank, trade, mail, vendors and auction house." },
  { key = "tooltip", text = "Item counts in tooltips", note = "How many of an item each of your characters has." },
}

-- The "Bank and guild bank" section.
local BANK_OPTIONS = {
  { key = "bankWindow", text = "Use Codex's bank window", note = "Off: the game's own bank window." },
  { key = "depositButton", text = "Deposit reagents button", note = "On the bank window: crafting reagents from your bags into the bank." },
  { key = "guildBankWindow", text = "Use Codex's guild bank window", note = "Off: the game's own guild bank window." },
}

local function SetOption(key, on)
  if key == "replace" then
    B.SetReplace(on)
  elseif key == "bankWindow" then
    B.SetBankWindow(on)
  elseif key == "guildBankWindow" then
    B.guild.SetWindow(on)
  else
    B.db[key] = on
    B.RequestRefresh()
    B.RequestBankRefresh()
  end
  ns.Fire("BAGS_CHANGED", "options")
end
B.SetOption = SetOption

function B.StatusText()
  local keys = B.CharacterKeys(true)
  local _, total = B.MoneyList()
  return ("%d character%s known; money on them: %s"):format(#keys, #keys == 1 and "" or "s", ns.Money(total))
end

local function RefreshPage()
  if not view.page then
    return
  end
  local db = B.DB()
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key])
  end
  for _, number in ipairs(view.numbers) do
    number.value:SetText(db[number.key] .. (number.unit or ""))
  end
  view.status:SetText(B.StatusText())
  local rows = {}
  for _, entry in ipairs((B.MoneyList())) do
    rows[#rows + 1] = entry.key
  end
  -- characters left out are listed too, after the others
  for _, key in ipairs(B.CharacterKeys(true)) do
    if db.hidden[key] then
      rows[#rows + 1] = key
    end
  end
  view.list:SetItems(rows)
  local _, total = B.MoneyList()
  view.total:SetText("Total: " .. ns.Money(total))
end
B.RefreshPage = RefreshPage

-- Number settings with -/+ (the window lays itself out again; during a fight, after it).
local NUMBERS = {
  { key = "columns", text = "Columns", min = 10, max = 20, step = 1 },
  { key = "itemSize", text = "Item size", min = 28, max = 44, step = 1, unit = " px" },
  { key = "itemSpacing", text = "Space between items", min = 0, max = 12, step = 1, unit = " px" },
  { key = "sectionSpacing", text = "Space between categories", min = 0, max = 30, step = 2, unit = " px" },
  { key = "bankColumns", text = "Bank columns", min = 10, max = 24, step = 1 },
}

function B.SetNumber(key, value)
  for _, number in ipairs(NUMBERS) do
    if number.key == key then
      B.db[key] = math.max(number.min, math.min(number.max, math.floor(value + 0.5)))
      RefreshPage()
      B.RequestRefresh()
      B.RequestBankRefresh()
      return B.db[key]
    end
  end
end

function B.BuildPage(page)
  B.DB()
  view.page = page
  local heading = UI.Heading(page, "Bags", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)
  local open = UI.Button(page, 110, 22, "Open bags")
  open:SetPoint("TOPRIGHT", 0, 0)
  open:SetScript("OnClick", function()
    B.Toggle()
  end)

  view.checks = {}
  -- a column of checks under anchor; returns the last one
  local function Checks(options, anchor, first)
    for index, option in ipairs(options) do
      local check = UI.Check(page, option.text)
      check.key = option.key
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, index == 1 and first or -8)
      local note = UI.Text(page, "body", 11, "muted")
      note:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
      note:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: a long note wraps
      note:SetJustifyH("LEFT")
      note:SetWordWrap(true)
      note:SetText(option.note)
      check:SetScript("OnClick", function(self)
        SetOption(self.key, self:GetChecked() and true or false)
      end)
      view.checks[#view.checks + 1] = check
      anchor = check
    end
    return anchor
  end
  local anchor = Checks(OPTIONS, view.status, -14)

  -- two columns of number settings
  view.numbers = {}
  local lastRow
  for index, number in ipairs(NUMBERS) do
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(310, 22)
    local column = (index - 1) % 2
    if column == 0 then
      row:SetPoint("TOPLEFT", lastRow or anchor, "BOTTOMLEFT", lastRow and 0 or 2, lastRow and -4 or -14)
      lastRow = row
    else
      row:SetPoint("LEFT", lastRow, "RIGHT", 20, 0)
    end
    local text = UI.Text(row, "body", 12, "text")
    text:SetPoint("LEFT")
    text:SetText(number.text)
    local fewer = UI.Button(row, 24, 20, "-")
    fewer:SetPoint("LEFT", 170, 0)
    local value = UI.Text(row, "body", 12, "bright")
    value:SetPoint("LEFT", fewer, "RIGHT", 4, 0)
    value:SetWidth(50)
    value:SetJustifyH("CENTER")
    local more = UI.Button(row, 24, 20, "+")
    more:SetPoint("LEFT", value, "RIGHT", 4, 0)
    fewer:SetScript("OnClick", function() B.SetNumber(number.key, B.db[number.key] - number.step) end)
    more:SetScript("OnClick", function() B.SetNumber(number.key, B.db[number.key] + number.step) end)
    view.numbers[#view.numbers + 1] = { key = number.key, unit = number.unit, value = value, fewer = fewer, more = more }
  end

  local bankLabel = UI.Text(page, "head", 11, "muted")
  bankLabel:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", -2, -18)
  bankLabel:SetText("BANK AND GUILD BANK")
  local lastBank = Checks(BANK_OPTIONS, bankLabel, -8)

  local label = UI.Text(page, "head", 11, "muted")
  label:SetPoint("TOPLEFT", lastBank, "BOTTOMLEFT", 0, -18)
  label:SetText("CHARACTERS")
  view.total = UI.Text(page, "body", 12, "bright")
  view.total:SetPoint("BOTTOMRIGHT", label, "BOTTOMLEFT", 0, 0)
  view.total:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  view.total:SetJustifyH("RIGHT")

  view.list = UI.List(page, {
    rowHeight = 24,
    CreateRow = function(row)
      row.include = UI.Check(row, "")
      row.include:SetPoint("LEFT", 4, 0)
      row.include:SetHitRectInsets(0, 0, 0, 0)
      row.include:SetScript("OnClick", function(self)
        B.SetHidden(row.item, not self:GetChecked())
        RefreshPage()
      end)
      row.include:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Count this character in tooltips and money totals.")
        GameTooltip:Show()
      end)
      row.include:SetScript("OnLeave", GameTooltip_Hide)
      row.delete = UI.Button(row, 60, 18, "Delete")
      row.delete:SetPoint("RIGHT", -4, 0)
      row.delete:SetScript("OnClick", function(self)
        -- two clicks: the first asks
        if self.armed ~= row.item then
          self.armed = row.item
          self:SetText("Sure?")
          return
        end
        self.armed = nil
        B.DeleteCharacter(row.item)
        RefreshPage()
      end)
      row.age = UI.Text(row, "body", 11, "muted")
      row.age:SetPoint("RIGHT", row.delete, "LEFT", -10, 0)
      row.age:SetWidth(70)
      row.age:SetJustifyH("RIGHT")
      row.money = UI.Text(row, "body", 12, "bright")
      row.money:SetPoint("RIGHT", row.age, "LEFT", -10, 0)
      row.money:SetJustifyH("RIGHT")
      row.name = UI.Text(row, "body", 12, "text")
      row.name:SetPoint("LEFT", row.include, "RIGHT", 6, 0)
      row.name:SetPoint("RIGHT", row.money, "LEFT", -8, 0)
      row.name:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        B.CreateWindow()
        if B.Window() and B.View(self.item, false) and not B.Window():IsShown() then
          B.Window():Show()
        end
      end)
    end,
    UpdateRow = function(row, key)
      local char = B.Character(key)
      local mine = key == B.PlayerKey()
      row.include:SetChecked(not B.db.hidden[key])
      row.include:SetEnabled(not mine)
      row.name:SetText(B.ColoredName(key) .. (mine and " |cff999999(you)|r" or ""))
      row.money:SetText(ns.Money(char and char.money or 0))
      row.age:SetText(mine and "now" or (ns.Age(char and char.updated) .. " ago"))
      row.delete:SetShown(not mine)
      row.delete.armed = nil
      row.delete:SetText("Delete")
    end,
  })
  view.list:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
  view.list:SetPoint("BOTTOMRIGHT", 0, 30)
  local note = UI.Text(page, "body", 11, "muted")
  note:SetPoint("BOTTOMLEFT", 0, 6)
  note:SetPoint("RIGHT", 0, 0)
  note:SetText("Click a character to see their bags. Each character is saved when you log in with them; "
    .. "their bank when they visit it.")

  ns.On("BAGS_CHANGED", function()
    if view.page:IsVisible() then
      RefreshPage()
    end
  end)
  RefreshPage()
end
