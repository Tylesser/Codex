local addonName, ns = ...

-- Quality of life in the Codex window: each toggle is a section of its own on the page it belongs to (Q.SECTIONS:
-- proc glow and spell ranks on Action bars, faster loot on Bags and items, ...), its switch in the section's header.
-- The body: a line saying what it does, its extra options (toggle.options; greyed out while the toggle is off:
-- switches, pickers with an optional button beside them, steppers, buttons, custom rows) and a note when another
-- addon is doing that job (the toggle then stays idle). The module itself has a section in General with the switch
-- for all of them and where each one lives.

local Q = ns.qol
local UI = ns.UI
local view = { rows = {} } -- rows of every built toggle section
Q.view = view

local LABEL_WIDTH = 120

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

function Q.NoteText(key)
  local other = Q.Elsewhere(key)
  if not other then
    return ""
  end
  local toggle = Q.Toggle(key)
  return ("%s is doing this, so Codex's %s stays idle. Turn it off there (or disable %s) to use Codex's.")
    :format(other, toggle.name:lower(), other)
end

-- The text a choice option shows for its current value (entries { title = "..." } are menu headings).
function Q.ChoiceText(option, value)
  for _, choice in ipairs(option.choices or option.values or {}) do
    if not choice.title and choice[1] == value then
      return choice[2]
    end
  end
  return tostring(value or "")
end

-- A menu of choices under a picker; pick(value) runs on a click. Shared with toggles that build their own rows.
function Q.OpenChoice(picker, choices, current, pick)
  local items = {}
  for _, choice in ipairs(choices or {}) do
    if choice.title then
      items[#items + 1] = { text = choice.title, title = true }
    else
      local value = choice[1]
      items[#items + 1] = {
        text = choice[2],
        checked = value == current,
        func = function()
          pick(value)
        end,
      }
    end
  end
  UI.ShowMenu(picker, items)
end

-- The next / previous value of a stepper option.
function Q.StepValue(option, value, step)
  local values = option.values or {}
  local index = 1
  for i, entry in ipairs(values) do
    if entry[1] == value then
      index = i
    end
  end
  index = math.max(1, math.min(#values, index + step))
  return values[index] and values[index][1]
end

-- Why an option doesn't apply right now (its Disabled()), or nil.
local function Reason(option)
  if type(option.Disabled) ~= "function" then
    return nil
  end
  local ok, text = pcall(option.Disabled)
  return ok and text or nil
end

local GREYED = { "check", "picker", "button", "extra", "extra2", "less", "more" }

local function Grey(sub, on)
  local reason = on and Reason(sub.option) or nil
  local enabled = on and not reason and true or false
  for _, key in ipairs(GREYED) do
    local widget = sub[key]
    if widget then
      widget:SetEnabled(enabled)
      widget:SetAlpha(enabled and 1 or 0.5)
    end
  end
  for _, key in ipairs({ "label", "value" }) do
    if sub[key] then
      sub[key]:SetAlpha(enabled and 1 or 0.5)
    end
  end
  if sub.hint then
    sub.hint:SetText(reason or "")
  end
  if sub.option.kind == "custom" and sub.option.Refresh then
    sub.option.Refresh(sub, on and true or false)
  end
end

-- A row's height from where its last line ends (font strings measure only once drawn), else an estimate.
local function RowHeight(row)
  local top = row.holder.GetTop and row.holder:GetTop()
  local bottom = row.note.GetBottom and row.note:GetBottom()
  if type(top) == "number" and type(bottom) == "number" and top > bottom then
    return math.ceil(top - bottom + 4)
  end
  local TextHeight = ns.UITextHeight
  local height = TextHeight(row.desc, 11, row.width)
  for _, sub in ipairs(row.subs) do
    local h = 22
    if sub.holder then
      h = sub.holder:GetHeight() or 24
    elseif sub.note then
      h = TextHeight(sub.note, 11, row.width)
    end
    height = height + 6 + h
  end
  local note = row.note:GetText()
  if note and note ~= "" then
    height = height + 4 + TextHeight(row.note, 11, row.width)
  end
  return math.ceil(height + 4)
end
Q.RowHeight = RowHeight

local function RefreshRow(row)
  local db = Q.DB()
  if row.check then
    row.check:SetChecked(db[row.toggle.key] and ns.ModuleState("qol") ~= "off")
  end
  row.note:SetText(Q.NoteText(row.toggle.key))
  for _, sub in ipairs(row.subs) do
    if sub.check then
      sub.check:SetChecked(db[sub.option.key])
    elseif sub.picker then
      sub.picker:SetText(Q.ChoiceText(sub.option, db[sub.option.key]))
    elseif sub.value then
      sub.value:SetText(Q.ChoiceText(sub.option, db[sub.option.key]))
    end
    Grey(sub, db[row.toggle.key])
  end
end

-- Reads every built toggle again (after any change) and lays the pages out again (a per-ability list opening
-- makes its section taller).
function Q.RefreshPage()
  for _, row in ipairs(view.rows) do
    RefreshRow(row)
  end
  if not Q.refreshing and type(ns.RefreshSections) == "function" then
    Q.refreshing = true
    pcall(ns.RefreshSections)
    Q.refreshing = false
  end
end

-- The built row of a toggle (its section's body), or nil.
function Q.RowOf(key)
  for _, row in ipairs(view.rows) do
    if row.toggle.key == key then
      return row
    end
  end
  return nil
end

local function Holder(body, last, height)
  local holder = CreateFrame("Frame", nil, body)
  holder:SetHeight(height or 24)
  holder:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  holder:SetPoint("RIGHT", 0, 0)
  return holder
end

local function Label(sub, holder, text)
  sub.label = UI.Text(holder, "body", 12, "text")
  sub.label:SetPoint("LEFT", 0, 0)
  sub.label:SetWidth(LABEL_WIDTH - 8)
  sub.label:SetJustifyH("LEFT")
  sub.label:SetText(text)
end

-- The grey text beside a choice / stepper saying why it doesn't apply (Disabled()).
local function Hint(sub, holder, after)
  sub.hint = UI.Text(holder, "body", 11, "muted")
  sub.hint:SetPoint("LEFT", after, "RIGHT", 10, 0)
  sub.hint:SetPoint("RIGHT", 0, 0)
  sub.hint:SetJustifyH("LEFT")
end

-- One extra option under a toggle, below `last`. Returns its entry and the widget the next one goes under.
local function BuildOption(body, option, last)
  local sub = { option = option }
  if option.kind == "custom" then
    local bottom = option.Build(body, last, sub)
    return sub, bottom or last
  end
  if option.kind == "choice" then
    local holder = Holder(body, last, option.rowHeight)
    sub.holder = holder
    Label(sub, holder, option.name)
    sub.picker = UI.Picker(holder, 200, 22)
    sub.picker:SetPoint("LEFT", LABEL_WIDTH, 0)
    sub.picker:SetScript("OnClick", function(self)
      Q.OpenChoice(self, option.choices, Q.DB()[option.key], function(value)
        Q.Set(option.key, value)
      end)
    end)
    local after = sub.picker
    if option.button then
      sub.extra = UI.Button(holder, 80, 22, option.button.name)
      sub.extra:SetPoint("LEFT", sub.picker, "RIGHT", 8, 0)
      sub.extra:SetScript("OnClick", function()
        option.button.Click()
      end)
      after = sub.extra
    end
    if option.button2 then -- (a second one, e.g. the art colour's Reset)
      sub.extra2 = UI.Button(holder, 80, 22, option.button2.name)
      sub.extra2:SetPoint("LEFT", after, "RIGHT", 8, 0)
      sub.extra2:SetScript("OnClick", function()
        option.button2.Click()
      end)
      after = sub.extra2
    end
    if option.preview then
      local ok, frame = pcall(option.preview, holder)
      if ok and frame then
        frame:SetPoint("LEFT", after, "RIGHT", 16, 0)
        sub.preview = frame
        after = frame
      end
    end
    Hint(sub, holder, after)
    return sub, holder
  end
  if option.kind == "stepper" then
    local holder = Holder(body, last)
    sub.holder = holder
    Label(sub, holder, option.name)
    local stepper = UI.Stepper(holder, 64)
    stepper:SetPoint("LEFT", LABEL_WIDTH, 0)
    sub.stepper, sub.less, sub.more, sub.value = stepper, stepper.less, stepper.more, stepper.value
    sub.less:SetScript("OnClick", function()
      Q.Set(option.key, Q.StepValue(option, Q.DB()[option.key], -1))
    end)
    sub.more:SetScript("OnClick", function()
      Q.Set(option.key, Q.StepValue(option, Q.DB()[option.key], 1))
    end)
    Hint(sub, holder, stepper)
    return sub, holder
  end
  if option.kind == "button" then
    local holder = Holder(body, last)
    sub.holder = holder
    sub.button = UI.Button(holder, math.max(110, #option.name * 7 + 24), 22, option.name)
    sub.button:SetPoint("LEFT", 0, 0)
    sub.button:SetScript("OnClick", function()
      option.Click()
    end)
    return sub, holder
  end
  sub.check = UI.Check(body, option.name)
  sub.check:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  sub.check:SetScript("OnClick", function(self)
    Q.Set(option.key, self:GetChecked())
  end)
  return sub, sub.check
end

-- One toggle's body in its section: what it does, its options (greyed while it is off) and the note when another
-- addon does the job. The switch is the section header's (`switch`).
function Q.BuildToggle(holder, toggle, width, switch)
  Q.DB()
  local row = { toggle = toggle, subs = {}, check = switch, holder = holder, width = width }
  row.desc = Wrap(UI.Text(holder, "body", 11, "muted"))
  row.desc:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  row.desc:SetText(toggle.desc or "")
  local last = row.desc
  for _, option in ipairs(toggle.options or {}) do
    local sub
    sub, last = BuildOption(holder, option, last)
    row.subs[#row.subs + 1] = sub
  end
  row.note = Wrap(UI.Text(holder, "body", 11, "warn"))
  row.note:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
  view.rows[#view.rows + 1] = row
  RefreshRow(row)
  return row
end

-- Where each toggle's section goes (Areas.lua): page, place, the header's name, folded at first.
Q.SECTIONS = {
  procGlow = { area = "bars", order = 30, title = "Proc glow" },
  spellRanks = { area = "bars", order = 40, title = "Spell ranks", folded = true },
  futureSpells = { area = "bars", order = 45, title = "Future spells", folded = true },
  hoverBind = { area = "bars", order = 50, title = "Bind keys by hovering" },
  cooldownNumbers = { area = "bars", order = 55, title = "Numbers on cooldowns" },
  greyOut = { area = "bars", order = 56, title = "Grey out what you can't use" },
  hideEmpty = { area = "bars", order = 57, title = "Hide empty slots" },
  trainerAll = { area = "trade", order = 40, title = "Learn all at trainers" },
  fasterLoot = { area = "items", order = 30, title = "Faster loot" },
  questTooltips = { area = "tooltips", order = 20, title = "Quest info in tooltips" },
  gatherTooltips = { area = "tooltips", order = 30, title = "Gathering skill in tooltips" },
  trackerSort = { area = "quests", order = 35, title = "Quest tracker order" },
  addonButtons = { area = "map", order = 15, title = "Addon buttons on the minimap", folded = true },
  revealMap = { area = "map", order = 20, title = "Reveal unexplored areas", folded = true },
  zoneLevels = { area = "map", order = 30, title = "Zone levels on the world map", folded = true },
  mapExtras = { area = "map", order = 40, title = "Dungeons and town services on the map", folded = true },
  skullMark = { area = "units", order = 70, title = "Skull mark" },
}

local function ModuleOff()
  return ns.ModuleState("qol") == "off"
end

local function SwitchModuleOn()
  ns.SetModuleWanted("qol", true)
end

for _, toggle in ipairs(Q.toggles) do
  local place = Q.SECTIONS[toggle.key] or { area = "general", order = 95 }
  local key = toggle.key
  ns.AddSection(place.area, {
    id = "qol-" .. key,
    title = place.title or toggle.name,
    order = place.order,
    folded = place.folded,
    aliases = { key },
    keywords = { toggle.name, toggle.desc },
    desc = toggle.desc,
    switch = {
      get = function()
        return Q.DB()[key] and not ModuleOff()
      end,
      set = function(on)
        if on and ModuleOff() then
          SwitchModuleOn() -- the small switches as a whole were off: on again (after a reload)
        end
        Q.Set(key, on)
      end,
    },
    tag = function()
      return Q.Elsewhere(key) and "other addon" or ""
    end,
    notice = function()
      if ModuleOff() then
        return "Every small switch is off (General > Quality of life), so this one waits.", "Switch them on",
          SwitchModuleOn
      end
      local module = ns.modules.qol
      if module and not module.running and ns.ModuleState("qol") == "on" then
        return "Switched on: it starts after a reload."
      end
      return nil
    end,
    build = function(holder, width, section)
      local row = Q.BuildToggle(holder, toggle, width, section.switch)
      section.qolRow = row
      return { Height = function()
        return RowHeight(row)
      end }
    end,
    refresh = function(section)
      if section.qolRow then
        RefreshRow(section.qolRow)
      end
    end,
  })
end

-- The module's own section (General): the switch for all of them, and where each one lives.
function Q.BuildSection(holder, width, section)
  local stack = ns.UIStack(holder)
  stack.AddText(ns.UIWrapping(holder, 12, "muted", width, "Small conveniences, each with its own switch on the page "
    .. "it belongs to. This switch turns all of them off at once."), 10)
  for _, toggle in ipairs(Q.toggles) do
    local place = Q.SECTIONS[toggle.key] or {}
    local row = CreateFrame("Frame", nil, holder)
    row:SetSize(width, 22)
    local open = UI.Button(row, 60, 20, "Open")
    open:SetPoint("RIGHT", 0, 0)
    open:SetScript("OnClick", function()
      ns.ShowPage("qol-" .. toggle.key)
    end)
    local name = UI.Text(row, "body", 12, "text")
    name:SetPoint("LEFT", 0, 0)
    name:SetPoint("RIGHT", open, "LEFT", -150, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetText(toggle.name)
    local where = UI.Text(row, "body", 11, "muted")
    where:SetPoint("LEFT", name, "RIGHT", 8, 0)
    where:SetPoint("RIGHT", open, "LEFT", -8, 0)
    where:SetJustifyH("RIGHT")
    where:SetWordWrap(false)
    local area = ns.AREA_BY_ID[place.area or "general"]
    where:SetText(area and area.name or "")
    stack.Add(row, function()
      return 22
    end, 0, 2)
  end
  return { Height = stack.Layout }
end
