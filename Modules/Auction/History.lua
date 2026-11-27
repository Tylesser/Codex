local addonName, ns = ...
local L = ns.L

-- Auction house module, part 6 (2026-11-25, the user's request to keep a history of prices): the price history
-- window. One item at a time: a chart of its lowest price per day over the chosen range (a faint bar up to each
-- day's highest low, how many were up underneath), the lowest, highest, average and the change, and every saved
-- day newest first (older than 90 days: one row per week). Opened by clicking an item on the Auction prices page,
-- Shift-clicking a result in the auction house panel, or /codex history <item link or name>.

local A = ns.auction
local UI = ns.UI

local WIDTH, HEIGHT = 560, 600
local PAD = 16
local CHART_H, SUPPLY_H = 150, 30 -- the price chart and the "up for sale" bars under it
local LABEL_W = 74 -- the price labels left of the chart
local PLOT_W = WIDTH - 2 * PAD - LABEL_W - 12
local DAY = 86400
local RANGES = {
  { id = 7, text = L["7 days"] },
  { id = 30, text = L["30 days"] },
  { id = 90, text = L["90 days"] },
  { id = 0, text = L["All"] },
}

local window
A.historyWindow = function()
  return window
end

local function Color(name)
  return ns.Theme()[name]
end

-- "+12%" / "-5%" / "0%" and its colour (dearer = bad, cheaper = good: for a buyer); "" without a value.
function A.TrendText(trend, theme)
  theme = theme or ns.Theme()
  if not trend then
    return "", theme.muted
  end
  local percent = math.floor(trend * 100 + (trend >= 0 and 0.5 or -0.5))
  if percent == 0 then
    return "0%", theme.muted
  end
  return (percent > 0 and "+" or "") .. percent .. "%", percent > 0 and theme.bad or theme.good
end

-- A price label beside the chart, short enough for its column: "1234g", "12g 50s", "50s 3c".
function A.AxisMoney(copper)
  copper = math.floor(copper + 0.5)
  local gold = math.floor(copper / 10000)
  if gold >= 100 then
    return gold .. "g"
  elseif gold > 0 then
    return gold .. "g " .. math.floor(copper / 100) % 100 .. "s"
  end
  return A.PlainMoney(copper)
end

-- "Wed 25 Nov", "Week of 3 Nov"; with the year when it isn't this year's.
local function DayText(point)
  local lastYear = date("%Y", point.time) ~= date("%Y")
  if point.week then
    return L["Week of %s"]:format(date(lastYear and "%d %b %Y" or "%d %b", point.time))
  end
  return date(lastYear and "%a %d %b %Y" or "%a %d %b", point.time)
end
A.HistoryDayText = DayText

-- Pooled pieces of the chart: pool[i] is made once with make() and reused.
local function Take(pool, index, make)
  local piece = pool[index]
  if not piece then
    piece = make()
    pool[index] = piece
  end
  return piece
end

local function HideFrom(pool, first)
  for index = first, #pool do
    pool[index]:Hide()
  end
end

local function ShowPointTooltip(hit)
  local point = hit.point
  if not point then
    return
  end
  local chart = window.chart
  chart.marker:ClearAllPoints()
  chart.marker:SetPoint("BOTTOM", chart.supply, "BOTTOMLEFT", hit.x, 0)
  chart.marker:SetPoint("TOP", chart.plot, "TOPLEFT", hit.x, 0)
  chart.marker:Show()
  GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
  GameTooltip:AddLine(DayText(point), 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Lowest"], ns.Money(point.price), 0.8, 0.8, 0.8, 1, 1, 1)
  if point.high and point.high > point.price then
    GameTooltip:AddDoubleLine(L["Highest low"], ns.Money(point.high), 0.8, 0.8, 0.8, 1, 1, 1)
  end
  if point.count then
    GameTooltip:AddDoubleLine(L["Up for sale"], tostring(point.count), 0.8, 0.8, 0.8, 1, 1, 1)
  end
  GameTooltip:Show()
end

local function HidePointTooltip()
  if window then
    window.chart.marker:Hide()
  end
  GameTooltip_Hide()
end

-- The chart for the chosen entries.
local function DrawChart(points, low, high)
  local chart = window.chart
  local plot, supply = chart.plot, chart.supply
  local theme = ns.Theme()
  local count = #points
  chart.empty:SetShown(count == 0)
  for _, label in ipairs(chart.prices) do
    label:SetShown(count > 0)
  end
  for _, guide in ipairs(chart.guides) do
    guide:SetShown(count > 0)
  end
  chart.firstDate:SetShown(count > 0)
  chart.lastDate:SetShown(count > 0)
  if count == 0 then
    chart.supplyLabel:Hide()
    HideFrom(chart.lines, 1)
    HideFrom(chart.dots, 1)
    HideFrom(chart.spans, 1)
    HideFrom(chart.bars, 1)
    HideFrom(chart.hits, 1)
    return
  end

  -- price scale: a little room above and below; one price only = the middle
  local bottom, top = low, high
  if top <= bottom then
    bottom, top = bottom * 0.9, top * 1.1 + 1
  else
    local room = (top - bottom) * 0.08
    bottom, top = math.max(0, bottom - room), top + room
  end
  local function Y(price)
    return (price - bottom) / (top - bottom) * CHART_H
  end
  for index, label in ipairs(chart.prices) do
    local share = (index - 1) / (#chart.prices - 1) -- bottom, middle, top
    label:SetText(A.AxisMoney(bottom + (top - bottom) * share))
  end

  -- time scale: a week's entry sits in the middle of its week
  local function Middle(point)
    return point.time + (point.week and 3 * DAY or 0)
  end
  local first, last = Middle(points[1]), Middle(points[count])
  local function X(point)
    if last <= first then
      return PLOT_W / 2
    end
    return 4 + (Middle(point) - first) / (last - first) * (PLOT_W - 8)
  end
  chart.firstDate:SetText(DayText(points[1]))
  chart.lastDate:SetText(DayText(points[count]))

  local most = 0
  for _, point in ipairs(points) do
    most = math.max(most, point.count or 0)
  end
  chart.supplyLabel:SetShown(most > 0)
  chart.supplyLabel:SetText(L["Up"] .. "\n" .. most)

  local slot = PLOT_W / math.max(1, count)
  local barWidth = math.max(2, math.min(10, slot - 2))
  local previousX, previousY
  for index, point in ipairs(points) do
    local x, y = X(point), Y(point.price)
    -- the line from the entry before
    if previousX then
      local line = Take(chart.lines, index - 1, function()
        return plot.CreateLine and plot:CreateLine(nil, "ARTWORK", nil, 2) or false
      end)
      if line then
        line:SetStartPoint("BOTTOMLEFT", plot, previousX, previousY)
        line:SetEndPoint("BOTTOMLEFT", plot, x, y)
        line:SetThickness(2)
        UI.SetColor(line, theme.accent, 0.9)
        line:Show()
      end
    end
    previousX, previousY = x, y
    local dot = Take(chart.dots, index, function()
      local texture = plot:CreateTexture(nil, "OVERLAY")
      texture:SetSize(5, 5)
      return texture
    end)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
    UI.SetColor(dot, theme.accent)
    dot:Show()
    -- the day's range: from its lowest to its highest low
    local span = Take(chart.spans, index, function()
      local texture = plot:CreateTexture(nil, "BORDER")
      texture:SetWidth(3)
      return texture
    end)
    if point.high and point.high > point.price then
      span:ClearAllPoints()
      span:SetPoint("BOTTOM", plot, "BOTTOMLEFT", x, y)
      span:SetHeight(math.max(1, Y(point.high) - y))
      UI.SetColor(span, theme.accent, 0.3)
      span:Show()
    else
      span:Hide()
    end
    local bar = Take(chart.bars, index, function()
      return supply:CreateTexture(nil, "ARTWORK")
    end)
    if point.count and point.count > 0 and most > 0 then
      bar:ClearAllPoints()
      bar:SetPoint("BOTTOM", supply, "BOTTOMLEFT", x, 0)
      bar:SetSize(barWidth, math.max(1, point.count / most * SUPPLY_H))
      UI.SetColor(bar, theme.muted, 0.45)
      bar:Show()
    else
      bar:Hide()
    end
    local hit = Take(chart.hits, index, function()
      local frame = CreateFrame("Frame", nil, chart)
      frame:EnableMouse(true)
      frame:SetScript("OnEnter", ShowPointTooltip)
      frame:SetScript("OnLeave", HidePointTooltip)
      return frame
    end)
    hit.point, hit.x = point, x
    hit:ClearAllPoints()
    hit:SetPoint("TOP", plot, "TOPLEFT", x, 0)
    hit:SetPoint("BOTTOM", supply, "BOTTOMLEFT", x, 0)
    hit:SetWidth(math.max(4, math.min(slot, 40)))
    hit:Show()
  end
  for index = count, #chart.lines do
    if chart.lines[index] then
      chart.lines[index]:Hide()
    end
  end
  HideFrom(chart.dots, count + 1)
  HideFrom(chart.spans, count + 1)
  HideFrom(chart.bars, count + 1)
  HideFrom(chart.hits, count + 1)
end

-- Everything for the item and range in the window.
local function Draw()
  if not window or not window.key then
    return
  end
  local key = window.key
  local name, icon, quality = A.ItemInfo(key, true)
  if name == "" then
    name = nil
  end
  window.icon:SetTexture(icon or 134400)
  window.name:SetText(name or L["Item %s"]:format(tostring(key)))
  window.name:SetTextColor(UI.Unpack(A.QualityColor(quality)))
  if not name and not window.nameQueued then
    window.nameQueued = true
    C_Timer.After(1, function()
      window.nameQueued = false
      if window:IsShown() then
        Draw()
      end
    end)
  end
  local rec = A.Record(key)
  if rec and rec.m then
    if rec.n and rec.n > 0 then
      window.now:SetText(L["Now %s, seen %s ago, %s up"]:format(ns.Money(rec.m), ns.Age(rec.t), tostring(rec.n)))
    else
      window.now:SetText(L["Now %s, seen %s ago"]:format(ns.Money(rec.m), ns.Age(rec.t)))
    end
  else
    window.now:SetText(L["No price saved for this item yet."])
  end
  window.realm:SetText(A.RealmKey())

  local history = A.GetHistory(key)
  local range = window.range or 30
  local since = range > 0 and (A.Today() - range + 1) * DAY or nil
  local points = A.HistorySince(history, since)
  window.points = points
  local low, high, average, change = A.HistoryStats(points)
  local stats = window.stats
  stats.low:SetText(low and ns.Money(low) or "-")
  stats.high:SetText(high and ns.Money(high) or "-")
  stats.average:SetText(average and ns.Money(average) or "-")
  local text, color = A.TrendText(change)
  stats.change:SetText(text ~= "" and text or "-")
  stats.change:SetTextColor(UI.Unpack(text ~= "" and color or Color("muted")))
  DrawChart(points, low or 0, high or 0)
  if #points == 0 then
    window.chart.empty:SetText(#history == 0 and L["No price history for this item on this realm yet. Prices are saved when you scan or search the auction house."]
      or L["No prices saved in this range; try a longer one."])
  end
  local rows = {}
  for index = #points, 1, -1 do
    rows[#rows + 1] = points[index]
  end
  window.list:SetItems(rows)
  window.saved:SetText(L["%d saved, kept %d days (Auction house options)"]:format(#history, A.DB().days or 30))
end
A.DrawHistory = Draw

local function Build()
  window = CreateFrame("Frame", "CodexPriceHistory", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetPoint("CENTER", 0, 40)
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  UI.Panel(window, { cornerSize = 12 })
  local title = UI.Heading(window, L["Price history"], 15)
  title:SetPoint("TOPLEFT", PAD, -14)
  local close = UI.CloseButton(window)
  close:SetPoint("TOPRIGHT", -10, -10)
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "CodexPriceHistory")
  end

  window.icon = window:CreateTexture(nil, "ARTWORK")
  window.icon:SetSize(30, 30)
  window.icon:SetPoint("TOPLEFT", PAD, -42)
  window.name = UI.Text(window, "body", 14, "bright")
  window.name:SetPoint("TOPLEFT", window.icon, "TOPRIGHT", 8, -1)
  window.name:SetPoint("RIGHT", -PAD, 0)
  window.name:SetJustifyH("LEFT")
  window.name:SetWordWrap(false)
  window.now = UI.Text(window, "body", 12, "muted")
  window.now:SetPoint("BOTTOMLEFT", window.icon, "BOTTOMRIGHT", 8, 1)
  window.now:SetPoint("RIGHT", -PAD, 0)
  window.now:SetJustifyH("LEFT")
  window.now:SetWordWrap(false)
  -- the item under the mouse: the game's tooltip
  local itemHover = CreateFrame("Frame", nil, window)
  itemHover:SetPoint("TOPLEFT", window.icon)
  itemHover:SetPoint("BOTTOMRIGHT", window.icon)
  itemHover:EnableMouse(true)
  itemHover:SetScript("OnEnter", function(self)
    local link = window.key and A.Hyperlink(window.key)
    if link then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(link)
      GameTooltip:Show()
    end
  end)
  itemHover:SetScript("OnLeave", GameTooltip_Hide)

  window.tabs = UI.Tabs(window, RANGES, function(id)
    window.range = id
    Draw()
  end)
  window.tabs:SetPoint("TOPLEFT", PAD, -82)
  window.tabs:SetPoint("RIGHT", -PAD, 0)
  window.realm = UI.Text(window.tabs, "body", 11, "muted")
  window.realm:SetPoint("RIGHT", 0, 2)

  -- the chart: prices on the left, the plot, how many were up under it, the first and last date
  local chart = UI.Inset(window, CreateFrame("Frame", nil, window))
  window.chart = chart
  chart:SetPoint("TOPLEFT", PAD, -118)
  chart:SetPoint("RIGHT", -PAD, 0)
  chart:SetHeight(10 + CHART_H + 8 + SUPPLY_H + 22)
  chart.plot = CreateFrame("Frame", nil, chart)
  chart.plot:SetPoint("TOPLEFT", LABEL_W, -10)
  chart.plot:SetSize(PLOT_W, CHART_H)
  chart.supply = CreateFrame("Frame", nil, chart)
  chart.supply:SetPoint("TOPLEFT", chart.plot, "BOTTOMLEFT", 0, -8)
  chart.supply:SetSize(PLOT_W, SUPPLY_H)
  chart.prices, chart.guides = {}, {}
  for index = 1, 3 do
    local y = (index - 1) / 2 * CHART_H
    local guide = chart.plot:CreateTexture(nil, "BACKGROUND", nil, 1)
    guide:SetHeight(1)
    guide:SetPoint("BOTTOMLEFT", chart.plot, "BOTTOMLEFT", 0, y)
    guide:SetPoint("BOTTOMRIGHT", chart.plot, "BOTTOMRIGHT", 0, y)
    UI.SetColor(guide, Color("divider"), 0.6)
    chart.guides[index] = guide
    local label = UI.Text(chart, "body", 10, "muted")
    label:SetPoint("RIGHT", chart.plot, "BOTTOMLEFT", -6, y)
    label:SetJustifyH("RIGHT")
    chart.prices[index] = label
  end
  chart.supplyLabel = UI.Text(chart, "body", 10, "muted")
  chart.supplyLabel:SetPoint("RIGHT", chart.supply, "LEFT", -6, 0)
  chart.supplyLabel:SetJustifyH("RIGHT")
  chart.firstDate = UI.Text(chart, "body", 10, "muted")
  chart.firstDate:SetPoint("TOPLEFT", chart.supply, "BOTTOMLEFT", 0, -5)
  chart.lastDate = UI.Text(chart, "body", 10, "muted")
  chart.lastDate:SetPoint("TOPRIGHT", chart.supply, "BOTTOMRIGHT", 0, -5)
  chart.empty = UI.Text(chart, "body", 12, "muted")
  chart.empty:SetPoint("CENTER", chart.plot, "CENTER")
  chart.empty:SetWidth(PLOT_W - 20)
  chart.empty:SetWordWrap(true)
  chart.marker = chart:CreateTexture(nil, "OVERLAY")
  chart.marker:SetWidth(1)
  UI.SetColor(chart.marker, Color("bright"), 0.5)
  chart.marker:Hide()
  chart.lines, chart.dots, chart.spans, chart.bars, chart.hits = {}, {}, {}, {}, {}

  -- lowest, highest, average, change in the range
  local stats = {}
  window.stats = stats
  local cell = (WIDTH - 2 * PAD) / 4
  for index, part in ipairs({ { "low", L["Lowest"] }, { "high", L["Highest"] }, { "average", L["Average"] },
    { "change", L["Change"] } }) do
    local label = UI.Text(window, "body", 11, "muted")
    label:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", (index - 1) * cell, -10)
    label:SetText(part[2])
    local value = UI.Text(window, "body", 13, "bright")
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    value:SetWidth(cell - 8)
    value:SetJustifyH("LEFT")
    stats[part[1]] = value
  end

  -- every saved entry in the range, newest first
  local head = CreateFrame("Frame", nil, window)
  head:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -50)
  head:SetPoint("RIGHT", -PAD, 0)
  head:SetHeight(16)
  local columns = {}
  for _, column in ipairs({ { "day", L["Day"], "LEFT" }, { "low", L["Lowest"], "RIGHT" }, { "high", L["Highest low"], "RIGHT" },
    { "up", L["Up"], "RIGHT" } }) do
    local text = UI.Text(head, "body", 11, "muted")
    text:SetText(column[2])
    text:SetJustifyH(column[3])
    columns[column[1]] = text
  end
  -- the same widths as the rows below (their right edge is 6 in from the list's, plus the list's own 2)
  columns.up:SetPoint("RIGHT", -10, 0)
  columns.up:SetWidth(60)
  columns.high:SetPoint("RIGHT", columns.up, "LEFT", -8, 0)
  columns.high:SetWidth(120)
  columns.low:SetPoint("RIGHT", columns.high, "LEFT", -8, 0)
  columns.low:SetWidth(120)
  columns.day:SetPoint("LEFT", 8, 0)

  window.list = UI.List(window, {
    rowHeight = 20,
    CreateRow = function(row)
      row.up = UI.Text(row, "body", 12, "muted")
      row.up:SetPoint("RIGHT", -2, 0)
      row.up:SetWidth(60)
      row.up:SetJustifyH("RIGHT")
      row.high = UI.Text(row, "body", 12, "text")
      row.high:SetPoint("RIGHT", row.up, "LEFT", -8, 0)
      row.high:SetWidth(120)
      row.high:SetJustifyH("RIGHT")
      row.low = UI.Text(row, "body", 12, "bright")
      row.low:SetPoint("RIGHT", row.high, "LEFT", -8, 0)
      row.low:SetWidth(120)
      row.low:SetJustifyH("RIGHT")
      row.day = UI.Text(row, "body", 12, "text")
      row.day:SetPoint("LEFT", 6, 0)
      row.day:SetPoint("RIGHT", row.low, "LEFT", -8, 0)
      row.day:SetJustifyH("LEFT")
      row.day:SetWordWrap(false)
    end,
    UpdateRow = function(row, point)
      row.day:SetText(DayText(point))
      row.low:SetText(ns.Money(point.price))
      row.high:SetText((point.high and point.high > point.price) and ns.Money(point.high) or "")
      row.up:SetText(point.count and tostring(point.count) or "")
    end,
  })
  window.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
  window.list:SetPoint("BOTTOMRIGHT", -PAD, 34)
  window.saved = UI.Text(window, "body", 11, "muted")
  window.saved:SetPoint("BOTTOMLEFT", PAD, 14)
  window.saved:SetPoint("RIGHT", -PAD, 0)
  window.saved:SetJustifyH("LEFT")

  window.range = 30
  window.tabs:Select(30)
  ns.On("AUCTION_STATE", function()
    if window:IsShown() then
      Draw()
    end
  end)
end

-- Opens the window for an item (ID, link, item string, ItemKey table or database key). false when it isn't one.
function A.ShowHistory(item)
  local key = A.KeyOf(item)
  if not key then
    return false
  end
  if not window then
    Build()
  end
  window.key = key
  window:Show()
  if window.Raise then
    window:Raise()
  end
  Draw()
  return true
end

-- The saved item a typed name means: the same name (any case), else the first name that has it in it (A-Z).
local function FindByName(text)
  text = text:lower()
  local realm = A.Realm(false)
  local partial
  for key, rec in pairs(realm and realm.items or {}) do
    local name = rec.m and A.CachedName(key)
    if name then
      local lower = name:lower()
      if lower == text then
        return key
      end
      if lower:find(text, 1, true) and (not partial or lower < partial[2]) then
        partial = { key, lower }
      end
    end
  end
  return partial and partial[1]
end

-- /codex history <item link, item ID or name>
function A.HistoryCommand(rest)
  rest = (rest or ""):match("^%s*(.-)%s*$")
  if rest == "" then
    ns.Say(L["Type /codex history and an item: Shift-click it into the line, or write its name."])
    return
  end
  local key
  if rest:find("item:", 1, true) or rest:find("battlepet:", 1, true) or tonumber(rest) then
    key = A.KeyOf(rest)
  else
    A.WarmNames(50) -- a few names the game hasn't told us yet
    key = FindByName(rest)
  end
  if not key then
    ns.Say(L["No saved auction price matches \"%s\" on this realm."]:format(rest:gsub("|", "")))
    return
  end
  A.ShowHistory(key)
end
