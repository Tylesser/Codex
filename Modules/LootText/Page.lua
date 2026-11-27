local addonName, ns = ...
local L = ns.L

-- Loot text, part 3: the section (Bags and items > Loot text) and the module's registration.
-- Left: which lines show. Right: look (float / list), sizes, quality, value and glow, sounds, the game's toasts,
-- place. Below: the watch list (Shift-click an item into the box, or type its name or ID) and the session.

local LT = ns.loottext
local UI = ns.UI
local view = { checks = {}, steppers = {}, pickers = {}, rows = {} }
LT.pageView = view -- (for the test)

local ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local COLUMN_GAP, ROW, LINE, LABEL = 30, 26, 30, 110

local KINDS = {
  { key = "items", name = L["Items you loot"] },
  { key = "junk", name = L["Grey items as one Junk line"], indent = true },
  { key = "crafted", name = L["Items you make"], indent = true },
  { key = "money", name = L["Money"] },
  { key = "otherMoney", name = L["Also from sales, mail and trades"], indent = true },
  { key = "reputation", name = L["Reputation"] },
  { key = "xp", name = L["Experience"] },
  { key = "honor", name = L["Honor"] },
  { key = "currency", name = L["Currencies"] },
  { key = "skill", name = L["Skill-ups"] },
  { key = "legacy", name = L["Legacy points"] },
}
LT.PAGE_KINDS = KINDS

LT.STYLES = { { key = "float", name = L["Floating up"] }, { key = "down", name = L["Floating down"] },
  { key = "list", name = L["List by the chat"] } }
LT.QUALITIES = { { key = 0, name = L["All (grey too)"] }, { key = 1, name = L["White and better"] },
  { key = 2, name = L["Green and better"] }, { key = 3, name = L["Blue and better"] }, { key = 4, name = L["Purple and better"] } }
LT.GLOW_VALUES = { { key = 0, name = L["Never"] }, { key = 2000, name = L["20 silver"] }, { key = 5000, name = L["50 silver"] },
  { key = 10000, name = L["1 gold"] }, { key = 50000, name = L["5 gold"] }, { key = 100000, name = L["10 gold"] },
  { key = 500000, name = L["50 gold"] } }
LT.SIZES = { size = { 10, 28, 1 }, duration = { 2, 10, 1 }, maxLines = { 3, 15, 1 } }

local function NameOf(list, key)
  for _, item in ipairs(list) do
    if item.key == key then
      return item.name
    end
  end
  return list[1].name
end

local function SoundName(key)
  for _, sound in ipairs(LT.SOUNDS) do
    if sound[1] == key then
      return sound[2]
    end
  end
  return L["None"]
end

function LT.StatusText()
  local state = ns.ModuleState("loottext")
  if state ~= "on" then
    return L["Off: switch it on at the top of this section (then reload)."]
  end
  if not LT.running then
    return L["On after a reload."]
  end
  local style = LT.DB().style
  return style == "list" and L["Lines stack beside the chat."] or style == "down"
    and L["Lines float down from the middle of the screen."] or L["Lines float up from the middle of the screen."]
end

local function Wrap(text)
  text:SetJustifyH("LEFT")
  text:SetPoint("RIGHT", 0, 0)
  return text
end

local function WatchName(key)
  if type(key) == "number" then
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(key)
    return (ns.Plain(name) and name) or L["Item %s"]:format(key)
  end
  return tostring(key)
end

local function RefreshWatch()
  local keys = {}
  for key in pairs(LT.DB().watch) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    return WatchName(a):lower() < WatchName(b):lower()
  end)
  for index, key in ipairs(keys) do
    local row = view.rows[index]
    if not row then
      row = CreateFrame("Frame", nil, view.page)
      row:SetSize(view.columnWidth, 22)
      row:SetPoint("TOPLEFT", view.watchBox, "BOTTOMLEFT", 0, -8 - (index - 1) * 24)
      row.name = UI.Text(row, "body", 13, "text")
      row.name:SetPoint("LEFT")
      row.name:SetPoint("RIGHT", -80, 0)
      row.name:SetJustifyH("LEFT")
      row.name:SetWordWrap(false)
      row.remove = UI.Button(row, 72, 20, L["Remove"])
      row.remove:SetPoint("RIGHT")
      row.codexList = true
      view.rows[index] = row
    end
    row.name:SetText(WatchName(key))
    row.remove:SetScript("OnClick", function()
      LT.RemoveWatch(key)
      RefreshWatch()
    end)
    row:Show()
  end
  for index = #keys + 1, #view.rows do
    view.rows[index]:Hide()
  end
  view.watchEmpty:SetShown(#keys == 0)
end

function LT.RefreshPage()
  if not view.page then
    return
  end
  local db = LT.DB()
  view.status:SetText(LT.StatusText())
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key] and true or false)
    local parent = check.parentKey
    local on = not parent or db[parent]
    check:SetEnabled(on and true or false)
    if check.label then
      check.label:SetAlpha(on and 1 or 0.5)
    end
  end
  for _, stepper in ipairs(view.steppers) do
    local value, range = db[stepper.key], LT.SIZES[stepper.key]
    local on = stepper.key ~= "maxLines" or db.style == "list"
    stepper.value:SetText(stepper.key == "duration" and L["%s s"]:format(value) or tostring(value))
    stepper.less:SetEnabled(on and value > range[1])
    stepper.more:SetEnabled(on and value < range[2])
    stepper.value:SetAlpha(on and 1 or 0.5)
    stepper.label:SetAlpha(on and 1 or 0.5)
  end
  view.pickers.style:SetText(NameOf(LT.STYLES, db.style))
  view.pickers.minQuality:SetText(NameOf(LT.QUALITIES, db.minQuality))
  view.pickers.glowValue:SetText(NameOf(LT.GLOW_VALUES, db.glowValue))
  view.pickers.glowSound:SetText(SoundName(db.glowSound))
  view.pickers.watchSound:SetText(SoundName(db.watchSound))
  local s = LT.Session()
  view.session:SetText(L["This session (%d min): looted %s, items worth %s, %s an hour."]:format(s.minutes,
    LT.Coins(s.money), LT.Coins(s.value), LT.Coins(s.perHour))
    .. (s.best and ("  " .. L["Best: %s"]:format(s.best.link or "?")) or ""))
  RefreshWatch()
end

function LT.BuildPage(page)
  LT.DB()
  view.page = page
  local width = ns.PAGE_WIDTH or 640
  local columnWidth = math.floor((width - COLUMN_GAP) / 2)
  view.columnWidth = columnWidth

  local icon = page:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("TOPLEFT")
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local heading = UI.Heading(page, L["Loot text"], 22)
  heading:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -1)
  view.status = Wrap(UI.Text(page, "body", 13, "muted"))
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  local about = Wrap(UI.Text(page, "body", 13, "text"))
  about:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
  about:SetSpacing(2)
  about:SetText(L["Floating text for what you get: items with how many you now have and what they are worth, money, reputation, experience, honor, currencies, skill-ups and Legacy points. The same thing again adds to its line."])

  -- left: what shows
  local kinds = UI.Section(page, L["What shows"])
  kinds:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  for index, kind in ipairs(KINDS) do
    local check = UI.Check(page, kind.name)
    check.key = kind.key
    check.parentKey = kind.indent and (kind.key == "otherMoney" and "money" or "items") or nil
    check:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", (kind.indent and 22 or 0) - 2, -6 - (index - 1) * ROW)
    check:SetScript("OnClick", function(self)
      LT.Set(kind.key, self:GetChecked() and true or false)
    end)
    view.checks[#view.checks + 1] = check
  end
  local extras = {
    { key = "showValue", name = L["Show what items are worth"] },
    { key = "allCharacters", name = L["Counts include your other characters"] },
    { key = "glowEpic", name = L["Purple and better always glow"] },
    { key = "hideToasts", name = L["Hide the game's loot toasts"] },
  }
  local extrasTop = -6 - #KINDS * ROW - 10
  for index, extra in ipairs(extras) do
    local check = UI.Check(page, extra.name)
    check.key = extra.key
    check:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", -2, extrasTop - (index - 1) * ROW)
    check:SetScript("OnClick", function(self)
      LT.Set(extra.key, self:GetChecked() and true or false)
    end)
    view.checks[#view.checks + 1] = check
  end

  -- right: look and place
  local look = UI.Section(page, L["Look and alerts"])
  look:SetPoint("TOPLEFT", about, "BOTTOMLEFT", columnWidth + COLUMN_GAP, -16)
  local function Label(line, text)
    local label = UI.Text(page, "body", 13, "text")
    label:SetPoint("TOPLEFT", look, "BOTTOMLEFT", 0, -12 - line * LINE)
    label:SetText(text)
    return label
  end
  local function Picker(line, text, key, items)
    local label = Label(line, text)
    local picker = UI.Picker(page, math.min(180, columnWidth - LABEL), 24)
    picker:SetPoint("LEFT", label, "LEFT", LABEL, 0)
    picker:SetScript("OnClick", function(self)
      local list = {}
      for _, item in ipairs(items()) do
        list[#list + 1] = { text = item.name, checked = LT.DB()[key] == item.key, func = function()
          LT.Set(key, item.key)
          if key == "glowSound" or key == "watchSound" then
            LT.PlaySound(item.key)
          end
        end }
      end
      UI.ShowMenu(self, list)
    end)
    view.pickers[key] = picker
    return picker
  end
  local function Stepper(line, text, key)
    local label = Label(line, text)
    local stepper = UI.Stepper(page, 48)
    stepper:SetPoint("LEFT", label, "LEFT", LABEL, 0)
    stepper.key, stepper.label = key, label
    local range = LT.SIZES[key]
    stepper.less:SetScript("OnClick", function()
      LT.Set(key, math.max(range[1], LT.DB()[key] - range[3]))
    end)
    stepper.more:SetScript("OnClick", function()
      LT.Set(key, math.min(range[2], LT.DB()[key] + range[3]))
    end)
    view.steppers[#view.steppers + 1] = stepper
  end
  local function Sounds()
    local list = {}
    for _, sound in ipairs(LT.SOUNDS) do
      list[#list + 1] = { key = sound[1], name = sound[2] }
    end
    return list
  end
  Picker(0, L["Look"], "style", function() return LT.STYLES end)
  Stepper(1, L["Text size"], "size")
  Stepper(2, L["Shown for"], "duration")
  Stepper(3, L["Lines (list)"], "maxLines")
  Picker(4, L["Items from"], "minQuality", function() return LT.QUALITIES end)
  Picker(5, L["Glow from"], "glowValue", function() return LT.GLOW_VALUES end)
  Picker(6, L["Glow sound"], "glowSound", Sounds)
  Picker(7, L["Watch sound"], "watchSound", Sounds)

  local sample = UI.Button(page, 130, 24, L["Show sample"])
  sample:SetPoint("TOPLEFT", look, "BOTTOMLEFT", 0, -12 - 8 * LINE - 4)
  sample:SetScript("OnClick", function()
    LT.Test()
  end)
  local reset = UI.Button(page, 130, 24, L["Reset position"])
  reset:SetPoint("LEFT", sample, "RIGHT", 8, 0)
  reset:SetScript("OnClick", function()
    LT.ResetPosition()
  end)
  local moveNote = UI.Text(page, "body", 12, "muted")
  moveNote:SetPoint("TOPLEFT", sample, "BOTTOMLEFT", 0, -6)
  moveNote:SetWidth(columnWidth)
  moveNote:SetJustifyH("LEFT")
  moveNote:SetText(L["To move the text open Edit Mode and drag its box; right-click the box puts it back. Each look keeps its own place. Values are Codex's auction prices, else what a merchant pays."])

  -- below: the watch list and the session
  local watch = UI.Section(page, L["Watch list"])
  watch:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", 2, extrasTop - #extras * ROW - 18)
  local watchNote = UI.Text(page, "body", 12, "muted")
  watchNote:SetPoint("TOPLEFT", watch, "BOTTOMLEFT", 0, -6)
  watchNote:SetWidth(columnWidth)
  watchNote:SetJustifyH("LEFT")
  watchNote:SetText(L["Items you farm: a banner and the watch sound when one drops. Shift-click an item into the box, or type its name."])
  view.watchBox = UI.EditBox(page, columnWidth - 70, 24)
  view.watchBox:SetPoint("TOPLEFT", watchNote, "BOTTOMLEFT", 0, -8)
  local add = UI.Button(page, 62, 24, L["Add"])
  add:SetPoint("LEFT", view.watchBox, "RIGHT", 8, 0)
  local function AddFromBox()
    if LT.AddWatch(view.watchBox:GetText()) then
      view.watchBox:SetText("")
      view.watchBox:ClearFocus()
      RefreshWatch()
    end
  end
  add:SetScript("OnClick", AddFromBox)
  view.watchBox:SetScript("OnEnterPressed", AddFromBox)
  view.watchEmpty = UI.Text(page, "body", 12, "muted")
  view.watchEmpty:SetPoint("TOPLEFT", view.watchBox, "BOTTOMLEFT", 0, -8)
  view.watchEmpty:SetText(L["Nothing watched yet."])
  -- Shift-click puts the link into the box while it has the cursor
  local function OnInsertLink(link)
    if view.watchBox:HasFocus() and type(link) == "string" and link:find("item:", 1, true) then
      view.watchBox:SetText(link)
    end
  end
  if type(_G.ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
  end
  if type(_G.ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
  end

  local session = UI.Section(page, L["This session"])
  session:SetPoint("TOPLEFT", watch, "TOPLEFT", columnWidth + COLUMN_GAP, 0)
  view.session = UI.Text(page, "body", 13, "text")
  view.session:SetPoint("TOPLEFT", session, "BOTTOMLEFT", 0, -8)
  view.session:SetWidth(columnWidth)
  view.session:SetJustifyH("LEFT")
  view.session:SetSpacing(2)
  local resetSession = UI.Button(page, 130, 24, L["Start again"])
  resetSession:SetPoint("TOPLEFT", view.session, "BOTTOMLEFT", 0, -8)
  resetSession:SetScript("OnClick", function()
    LT.ResetSession()
    LT.RefreshPage()
  end)
  local sessionNote = UI.Text(page, "body", 12, "muted")
  sessionNote:SetPoint("TOPLEFT", resetSession, "BOTTOMLEFT", 0, -6)
  sessionNote:SetWidth(columnWidth)
  sessionNote:SetJustifyH("LEFT")
  sessionNote:SetText(L["Also in the info bar's gold tooltip. Money from sales, mail and trades doesn't count."])

  ns.On("LOOTTEXT_CHANGED", function()
    if view.page:IsVisible() then
      LT.RefreshPage()
    end
  end)
  LT.RefreshPage()
end

-- /codex loottext [test]
local function Command(_, rest)
  rest = strtrim(rest or ""):lower()
  if rest == "test" then
    if LT.running then
      LT.Test()
    end
    return
  end
  ns.ShowPage("loottext")
end

ns.RegisterModule({
  id = "loottext",
  name = L["Loot text"],
  -- its section in the Codex window (Areas.lua)
  area = "items", sectionOrder = 35, folded = true, pageEstimate = 760,
  icon = ICON,
  desc = L["Floating text for loot, money, reputation, experience, honor, currencies, skill-ups and Legacy points."],
  default = false, -- off until the player switches it on (the user's choice, 2026-11-21)
  order = 97,
  Enable = function()
    LT.Enable()
  end,
  BuildPage = function(_, page)
    LT.BuildPage(page)
  end,
  ShowPage = function()
    LT.RefreshPage()
  end,
  Status = function()
    return LT.StatusText()
  end,
  commands = {
    loottext = Command,
  },
})
