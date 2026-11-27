local addonName, ns = ...
local L = ns.L

-- Auction house module, part 4: its page in the Codex window. Tabs: Prices (search the price database),
-- Shopping lists (edit lists and terms), Scan, Options.

local A = ns.auction
local UI = ns.UI

local view = {} -- the built page's parts
A.view = view

local function Width(frame, fallback)
  local width = frame:GetWidth()
  return (width and width > 200) and width or fallback
end

local function Color(name)
  return ns.Theme()[name]
end

local function ShowItemTooltip(owner, key)
  local link = A.Hyperlink(key)
  if not link then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(link)
  local history = A.GetHistory(key)
  if #history > 1 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Lowest price per day"], UI.Unpack(Color("accent")))
    for index = #history, math.max(1, #history - 6), -1 do
      local day = history[index]
      GameTooltip:AddDoubleLine(A.HistoryDayText(day), ns.Money(day.price), 0.8, 0.8, 0.8, 1, 1, 1)
    end
  end
  GameTooltip:AddLine(L["Click for its price history."], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end
A.ShowItemTooltip = ShowItemTooltip

-- Prices tab ---------------------------------------------------------------------------------------------

local SORTS = {
  name = function(a, b) return a.sortName < b.sortName end,
  price = function(a, b) return a.rec.m < b.rec.m end,
  age = function(a, b) return a.rec.t > b.rec.t end,
  trend = function(a, b) return (a.trend or 0) < (b.trend or 0) end,
}

-- Price rows matching the search text, sorted. Exposed for tests.
function A.PriceRows(search, sortKey, reverse)
  local realm = A.Realm(false)
  local rows = {}
  search = (search or ""):lower()
  for key, rec in pairs(realm and realm.items or {}) do
    if rec.m then
      -- the cached name only: asking the game for thousands of items here froze it
      local name = A.CachedName(key)
      if search == "" or (name and name:lower():find(search, 1, true)) then
        rows[#rows + 1] = { key = key, rec = rec, name = name, sortName = name and name:lower() or "~",
          trend = sortKey == "trend" and A.Trend(rec) or nil, needTrend = sortKey ~= "trend" }
      end
    end
  end
  local sort = SORTS[sortKey or "name"] or SORTS.name
  table.sort(rows, function(a, b)
    if reverse then
      return sort(b, a)
    end
    return sort(a, b)
  end)
  return rows
end

local function TrendText(trend)
  return A.TrendText(trend, ns.Theme())
end

-- While the Prices tab is open, item names we don't know yet are learnt a few at a time (25 every 0.2s), so
-- search and name sorting fill in without a freeze; the list refreshes when they're all known.
local WARM_BATCH, WARM_EVERY = 25, 0.2
local function WarmNames()
  local prices = view.prices
  if not prices or prices.warming then
    return
  end
  if A.WarmNames(0) == 0 then
    return -- every name known: nothing to do (and no refresh, which would come back here)
  end
  prices.warming = true
  local function Step()
    if not (view.prices and view.prices.list:IsVisible()) then
      prices.warming = false
      return
    end
    if A.WarmNames(WARM_BATCH) > 0 then
      C_Timer.After(WARM_EVERY, Step)
    else
      prices.warming = false
      view.prices.Refresh()
    end
  end
  C_Timer.After(WARM_EVERY, Step)
end

local function RefreshPrices()
  local prices = view.prices
  if not prices then
    return
  end
  WarmNames()
  prices.rows = A.PriceRows(prices.search:GetText(), prices.sortKey, prices.reverse)
  prices.list:SetItems(prices.rows)
  local total = A.ItemCount()
  prices.count:SetText(#prices.rows == total and L["%d items"]:format(total) or L["%d of %d items"]:format(#prices.rows, total))
end

local function BuildPrices(body)
  local prices = {}
  view.prices = prices
  prices.sortKey, prices.reverse = "name", false

  local label = UI.Text(body, "body", 12, "text")
  label:SetPoint("TOPLEFT", 0, -4)
  label:SetText(L["Search"])
  prices.search = UI.EditBox(body, 200, 22)
  prices.search:SetPoint("LEFT", label, "RIGHT", 8, 0)
  prices.search:SetScript("OnTextChanged", function()
    -- rebuild after a short pause in typing, not on every key
    prices.typed = (prices.typed or 0) + 1
    local typed = prices.typed
    C_Timer.After(0.25, function()
      if prices.typed == typed then
        RefreshPrices()
      end
    end)
  end)
  prices.count = UI.Text(body, "body", 11, "muted")
  prices.count:SetPoint("LEFT", prices.search, "RIGHT", 10, 0)

  prices.sortButtons = {}
  local previous
  for _, sort in ipairs({ { "trend", L["Trend"] }, { "age", L["Age"] }, { "price", L["Price"] }, { "name", L["Name"] } }) do
    local button = UI.Button(body, 56, 20, sort[2])
    if previous then
      button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
    else
      button:SetPoint("TOPRIGHT", 0, -5)
    end
    button:SetScript("OnClick", function()
      if prices.sortKey == sort[1] then
        prices.reverse = not prices.reverse
      else
        prices.sortKey, prices.reverse = sort[1], false
      end
      RefreshPrices()
    end)
    prices.sortButtons[sort[1]] = button
    previous = button
  end
  local sortLabel = UI.Text(body, "body", 11, "muted")
  sortLabel:SetPoint("RIGHT", previous, "LEFT", -6, 0)
  sortLabel:SetText(L["Sort"])

  prices.list = UI.List(body, {
    rowHeight = 22,
    CreateRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(18, 18)
      row.icon:SetPoint("LEFT", 4, 0)
      row.trend = UI.Text(row, "body", 12, "muted")
      row.trend:SetPoint("RIGHT", -6, 0)
      row.trend:SetWidth(54)
      row.trend:SetJustifyH("RIGHT")
      row.age = UI.Text(row, "body", 12, "muted")
      row.age:SetPoint("RIGHT", row.trend, "LEFT", -6, 0)
      row.age:SetWidth(44)
      row.age:SetJustifyH("RIGHT")
      row.price = UI.Text(row, "body", 12, "bright")
      row.price:SetPoint("RIGHT", row.age, "LEFT", -6, 0)
      row.price:SetWidth(130)
      row.price:SetJustifyH("RIGHT")
      row.name = UI.Text(row, "body", 12, "text")
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
      row.name:SetPoint("RIGHT", row.price, "LEFT", -8, 0)
      row.name:SetWordWrap(false)
      row:SetScript("OnEnter", function(self)
        if self.item then
          ShowItemTooltip(self, self.item.key)
        end
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)
      row:SetScript("OnClick", function(self)
        if self.item then
          A.ShowHistory(self.item.key)
        end
      end)
    end,
    UpdateRow = function(row, item)
      if item.needTrend then
        item.trend, item.needTrend = A.Trend(item.rec), nil
      end
      if not item.icon then
        local name, icon, quality = A.ItemInfo(item.key, false)
        item.name, item.icon, item.quality = item.name or name, icon, quality
      end
      if not item.name then
        -- not in the game's item cache yet: ask for it and look again shortly
        item.name, item.icon, item.quality = A.ItemInfo(item.key, true)
        if not item.name and not prices.reloadQueued then
          prices.reloadQueued = true
          C_Timer.After(1, function()
            prices.reloadQueued = false
            if view.prices and view.prices.list:IsVisible() then
              view.prices.list:Refresh()
            end
          end)
        end
      end
      row.icon:SetTexture(item.icon or 134400)
      row.name:SetText(item.name or L["Item %s"]:format(tostring(item.key)))
      row.name:SetTextColor(UI.Unpack(A.QualityColor(item.quality)))
      row.price:SetText(ns.Money(item.rec.m))
      row.age:SetText(ns.Age(item.rec.t))
      local text, color = TrendText(item.trend)
      row.trend:SetText(text)
      row.trend:SetTextColor(UI.Unpack(color))
    end,
  })
  prices.list:SetPoint("TOPLEFT", 0, -34)
  prices.list:SetPoint("BOTTOMRIGHT", 0, 0)

  prices.Refresh = RefreshPrices
end

-- Shopping lists tab -------------------------------------------------------------------------------------

local RefreshLists

local function SelectTerm(term)
  local lists = view.lists
  lists.term = term
  lists.text:SetText(term and term.text or "")
  lists.exact:SetChecked(term and term.exact or false)
  lists.maxPrice:SetText(term and A.PlainMoney(term.maxPrice) or "")
  RefreshLists()
end

local function EditorValues()
  local lists = view.lists
  local maxText = lists.maxPrice:GetText() or ""
  local maxPrice = A.ParseMoney(maxText)
  if maxText:match("%S") and not maxPrice then
    return nil, L["Max price: write it like 12g 50s, or a number of gold."]
  end
  return lists.text:GetText(), lists.exact:GetChecked(), maxPrice
end

RefreshLists = function()
  local lists = view.lists
  if not lists then
    return
  end
  local all = A.Lists()
  local found = false
  for _, list in ipairs(all) do
    if list == lists.selected then
      found = true
    end
  end
  if not found then
    lists.selected = all[1]
    lists.term = nil
  end
  lists.listList:SetItems(all)
  local selected = lists.selected
  lists.terms:SetItems(selected and selected.terms or {})
  lists.title:SetText(selected and selected.name or L["No list yet: type a name and press New."])
  for _, button in ipairs({ lists.rename, lists.delete, lists.add }) do
    button:SetEnabled(selected ~= nil)
  end
  lists.save:SetEnabled(lists.term ~= nil)
  lists.remove:SetEnabled(lists.term ~= nil)
end

local function BuildLists(body)
  local lists = {}
  view.lists = lists
  local width = Width(body, 660)
  local leftWidth = 210

  local listsLabel = UI.Text(body, "head", 11, "muted")
  listsLabel:SetPoint("TOPLEFT", 0, -2)
  listsLabel:SetText("LISTS")

  -- Auctionator's saved lists, while it is loaded and has some (A.ImportAuctionator)
  lists.import = UI.Button(body, 130, 18, L["From Auctionator"])
  lists.import:SetPoint("TOPRIGHT", body, "TOPLEFT", leftWidth, 0)
  lists.import:SetShown(#A.AuctionatorLists() > 0)
  lists.import:SetScript("OnClick", function()
    local made, merged, added = A.ImportAuctionator()
    if added == 0 then
      ns.Say(L["Auctionator's lists are already in Codex."])
    else
      ns.Say(L["From Auctionator: new lists %d, lists added to %d, terms %d."]:format(made, merged, added))
    end
  end)
  lists.import:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Import from Auctionator"])
    GameTooltip:AddLine(L["Copies Auctionator's saved shopping lists into Codex (exact names stay exact). Lists you already have here get only the terms they lack. Auctionator's lists stay as they are."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  lists.import:SetScript("OnLeave", GameTooltip_Hide)

  lists.listList = UI.List(body, {
    rowHeight = 22,
    CreateRow = function(row)
      row.text = UI.Text(row, "body", 12, "text")
      row.text:SetPoint("LEFT", 8, 0)
      row.text:SetPoint("RIGHT", -8, 0)
      row.text:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        lists.selected = self.item
        lists.term = nil
        lists.name:SetText(self.item.name)
        SelectTerm(nil)
      end)
    end,
    UpdateRow = function(row, list)
      row.text:SetText(("%s |cff999999(%d)|r"):format(list.name, #list.terms))
      row.selected:SetShown(list == lists.selected)
    end,
  })
  lists.listList:SetPoint("TOPLEFT", 0, -18)
  lists.listList:SetPoint("BOTTOMLEFT", 0, 66)
  lists.listList:SetWidth(leftWidth)

  lists.name = UI.EditBox(body, leftWidth, 22)
  lists.name:SetPoint("BOTTOMLEFT", 0, 34)
  lists.new = UI.Button(body, 66, 24, L["New##list"])
  lists.new:SetPoint("BOTTOMLEFT", 0, 4)
  lists.new:SetScript("OnClick", function()
    lists.selected = A.NewList(lists.name:GetText())
    lists.name:SetText(lists.selected.name)
    SelectTerm(nil)
  end)
  lists.rename = UI.Button(body, 68, 24, L["Rename"])
  lists.rename:SetPoint("LEFT", lists.new, "RIGHT", 6, 0)
  lists.rename:SetScript("OnClick", function()
    A.RenameList(lists.selected, lists.name:GetText())
  end)
  lists.delete = UI.Button(body, 64, 24, L["Delete"])
  lists.delete:SetPoint("LEFT", lists.rename, "RIGHT", 6, 0)
  lists.delete:SetScript("OnClick", function()
    if IsShiftKeyDown() or (lists.selected and #lists.selected.terms == 0) then
      A.DeleteList(lists.selected)
      lists.name:SetText("")
    else
      ns.Say(L["Hold Shift and click Delete to delete a list that still has terms."])
    end
  end)

  -- terms of the selected list
  local left = leftWidth + 20
  lists.title = UI.Text(body, "body", 14, "bright")
  lists.title:SetPoint("TOPLEFT", left, -2)
  lists.title:SetPoint("RIGHT", 0, 0)
  lists.title:SetWordWrap(false)
  lists.terms = UI.List(body, {
    rowHeight = 22,
    CreateRow = function(row)
      row.price = UI.Text(row, "body", 12, "bright")
      row.price:SetPoint("RIGHT", -8, 0)
      row.price:SetJustifyH("RIGHT")
      row.tag = UI.Text(row, "body", 11, "muted")
      row.tag:SetPoint("RIGHT", row.price, "LEFT", -10, 0)
      row.text = UI.Text(row, "body", 12, "text")
      row.text:SetPoint("LEFT", 8, 0)
      row.text:SetPoint("RIGHT", row.tag, "LEFT", -8, 0)
      row.text:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        SelectTerm(self.item)
      end)
    end,
    UpdateRow = function(row, term)
      row.text:SetText(term.text)
      row.tag:SetText(term.exact and L["exact"] or "")
      row.price:SetText(term.maxPrice and L["max %s"]:format(ns.Money(term.maxPrice)) or "")
      row.selected:SetShown(term == lists.term)
    end,
  })
  lists.terms:SetPoint("TOPLEFT", left, -20)
  lists.terms:SetPoint("BOTTOMRIGHT", 0, 66)

  local textLabel = UI.Text(body, "body", 12, "text")
  textLabel:SetPoint("BOTTOMLEFT", left, 38)
  textLabel:SetText(L["Search for"])
  lists.text = UI.EditBox(body, math.max(140, width - left - 330), 22)
  lists.text:SetPoint("LEFT", textLabel, "RIGHT", 8, 0)
  lists.exact = UI.Check(body, L["Exact name"])
  lists.exact:SetPoint("LEFT", lists.text, "RIGHT", 8, 0)
  local maxLabel = UI.Text(body, "body", 12, "text")
  maxLabel:SetPoint("LEFT", lists.exact.label, "RIGHT", 14, 0)
  maxLabel:SetText(L["Max"])
  lists.maxPrice = UI.EditBox(body, 90, 22)
  lists.maxPrice:SetPoint("LEFT", maxLabel, "RIGHT", 6, 0)
  lists.maxPrice:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Highest unit price you'd pay"])
    GameTooltip:AddLine(L["Like 12g 50s, or a number of gold. Results at or below it are marked at the auction house."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  lists.maxPrice:SetScript("OnLeave", GameTooltip_Hide)

  local function Apply(fn)
    local text, exact, maxPrice = EditorValues()
    if not text then
      ns.Say(exact)
      return
    end
    fn(text, exact, maxPrice)
  end
  lists.add = UI.Button(body, 80, 24, L["Add"])
  lists.add:SetPoint("BOTTOMLEFT", left, 4)
  lists.add:SetScript("OnClick", function()
    Apply(function(text, exact, maxPrice)
      local term = A.AddTerm(lists.selected, text, exact, maxPrice)
      if term then
        SelectTerm(nil)
      end
    end)
  end)
  lists.save = UI.Button(body, 80, 24, L["Save"])
  lists.save:SetPoint("LEFT", lists.add, "RIGHT", 6, 0)
  lists.save:SetScript("OnClick", function()
    Apply(function(text, exact, maxPrice)
      A.EditTerm(lists.term, text, exact, maxPrice)
    end)
  end)
  lists.remove = UI.Button(body, 80, 24, L["Remove"])
  lists.remove:SetPoint("LEFT", lists.save, "RIGHT", 6, 0)
  lists.remove:SetScript("OnClick", function()
    A.RemoveTerm(lists.selected, lists.term)
    SelectTerm(nil)
  end)
  local hint = UI.Text(body, "body", 11, "muted")
  hint:SetPoint("LEFT", lists.remove, "RIGHT", 10, 0)
  hint:SetPoint("RIGHT", 0, 0)
  hint:SetText(L["Search a list from the Codex panel beside the auction house."])

  lists.Refresh = RefreshLists
end

-- Scan tab -----------------------------------------------------------------------------------------------

local function RefreshScan()
  local scan = view.scan
  if not scan then
    return
  end
  local realm = A.Realm(false)
  scan.status:SetText(A.ScanText())
  scan.button:SetEnabled(A.IsModern() and A.open and A.scan.state == "idle" and A.NextScanIn() == 0)
  local lines = { L["Prices on %s: %d items."]:format(A.RealmKey(), A.ItemCount()) }
  if realm and realm.scanDone then
    lines[#lines + 1] = L["Last full scan %s ago: %d items."]:format(ns.Age(realm.scanDone), realm.scanned or 0)
  else
    lines[#lines + 1] = L["No full scan yet on this realm."]
  end
  if A.scan.lastResult then
    lines[#lines + 1] = A.scan.lastResult
  end
  local below = A.BelowCount()
  if below > 0 then
    lines[#lines + 1] = L["Items on sale below the vendor price: %d. See \"Below vendor\" in the Codex panel at the auction house."]
      :format(below)
  end
  scan.info:SetText(table.concat(lines, "\n"))
end

local function BuildScan(body)
  local scan = {}
  view.scan = scan
  local intro = UI.Text(body, "body", 12, "text")
  intro:SetPoint("TOPLEFT", 0, -4)
  intro:SetPoint("RIGHT", 0, 0)
  intro:SetText(L["A full scan reads every auction of your realm at once and saves the lowest price of each item."] .. " "
    .. L["The auction house must be open, and the server allows one full scan every 15 minutes."] .. " "
    .. L["Prices also update by themselves whenever you browse or search the auction house."])
  scan.button = UI.Button(body, 140, 28, L["Full scan"])
  scan.button:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -14)
  scan.button:SetScript("OnClick", function()
    A.ScanCommand()
  end)
  scan.status = UI.Text(body, "body", 12, "accent")
  scan.status:SetPoint("LEFT", scan.button, "RIGHT", 12, 0)
  scan.info = UI.Text(body, "body", 12, "text")
  scan.info:SetPoint("TOPLEFT", scan.button, "BOTTOMLEFT", 0, -14)
  scan.info:SetPoint("RIGHT", 0, 0)
  scan.info:SetJustifyV("TOP")
  local note = UI.Text(body, "body", 11, "muted")
  note:SetPoint("TOPLEFT", scan.info, "BOTTOMLEFT", 0, -40)
  note:SetPoint("RIGHT", 0, 0)
  note:SetText(L["You can also type /codex scan at the auction house."])
  scan.Refresh = RefreshScan
end

-- Options tab --------------------------------------------------------------------------------------------

local function RefreshOptions()
  local options = view.options
  if not options then
    return
  end
  local db = A.DB()
  for _, check in ipairs(options.checks) do
    check:SetChecked(db[check.key])
  end
  options.daysText:SetText(A.DaysText(db.days))
end

-- "Keep 30 days of price history"; past 90 days the older ones are kept per week.
function A.DaysText(days)
  if days > A.DAILY then
    return L["Keep %d days of price history (after %d days, one entry per week)"]:format(days, A.DAILY)
  end
  return L["Keep %d days of price history"]:format(days)
end

-- The next or previous length in A.DAY_CHOICES from any saved number of days.
function A.StepDays(days, direction)
  local choices = A.DAY_CHOICES
  if direction > 0 then
    for _, choice in ipairs(choices) do
      if choice > days then
        return choice
      end
    end
    return choices[#choices]
  end
  for index = #choices, 1, -1 do
    if choices[index] < days then
      return choices[index]
    end
  end
  return choices[1]
end

-- One of the options (also from the Tooltips page's "Prices and stats in tooltips").
function A.SetOption(key, on)
  A.DB()[key] = on and true or false
  if key == "panel" then
    A.ShowPanel()
  end
  A.Changed("options")
end

local function BuildOptions(body)
  local options = { checks = {} }
  view.options = options
  local anchor
  for _, option in ipairs({
    { "tooltip", L["Auction price in item tooltips"], L["Hold Shift over a stack to see what the whole stack is worth."] },
    { "tooltipHistory", L["Price history in item tooltips"], L["The past week's average and how today's price compares; hold Shift for the last days."] },
    { "vendor", L["Vendor sell price in item tooltips"], L["The game's sell price shows one item's price; hold Shift for the whole stack. A Vendor line where the game shows none."] },
    { "panel", L["Codex panel beside the auction house"], L["Shopping lists and the scan button at the auction house."] },
  }) do
    local check = UI.Check(body, option[2])
    check.key = option[1]
    if anchor then
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    else
      check:SetPoint("TOPLEFT", 0, -4)
    end
    local note = UI.Text(body, "body", 11, "muted")
    note:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
    note:SetPoint("RIGHT", body, "RIGHT", 0, 0) -- bound to the page: a long note wraps
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(option[3])
    check:SetScript("OnClick", function(self)
      A.SetOption(self.key, self:GetChecked())
    end)
    options.checks[#options.checks + 1] = check
    anchor = check
  end
  options.daysText = UI.Text(body, "body", 12, "text")
  options.daysText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
  local fewer = UI.Button(body, 24, 20, "-")
  fewer:SetPoint("LEFT", options.daysText, "RIGHT", 10, 0)
  local more = UI.Button(body, 24, 20, "+")
  more:SetPoint("LEFT", fewer, "RIGHT", 4, 0)
  local function SetDays(direction)
    local db = A.DB()
    db.days = A.StepDays(db.days or 30, direction)
    RefreshOptions()
    A.Changed("options")
  end
  fewer:SetScript("OnClick", function() SetDays(-1) end)
  more:SetScript("OnClick", function() SetDays(1) end)
  options.fewer, options.more = fewer, more
  options.Refresh = RefreshOptions
end

-- The page --------------------------------------------------------------------------------------------------
-- The module's section on the Trade page holds its options and the full scan; the shopping lists and the price
-- list are sections of their own under it (Areas.lua), each as tall as its lists need.

local PARTS = {
  prices = BuildPrices,
  lists = BuildLists,
  scan = BuildScan,
  options = BuildOptions,
}

-- Refreshes every part that is on screen (and the status line).
local function RefreshCurrent()
  for id, body in pairs(view.bodies or {}) do
    local part = view[id]
    if part and part.Refresh and body:IsVisible() then
      part.Refresh()
    end
  end
  if view.status then
    view.status:SetText(A.StatusText())
  end
end
A.RefreshPage = RefreshCurrent

local listening = false
local function Listen()
  if listening then
    return
  end
  listening = true
  ns.On("PRICES_UPDATED", function()
    -- a full scan or a search changed prices; the Prices list rebuilds only while it is on screen
    RefreshCurrent()
  end)
  ns.On("AUCTION_STATE", function(what)
    if what == "lists" and view.lists then
      RefreshLists()
    end
    RefreshCurrent()
  end)
end

-- One part into its own frame (a section's holder, or a frame of the module's section).
local function BuildPart(id, body)
  view.bodies = view.bodies or {}
  view.bodies[id] = body
  PARTS[id](body)
  Listen()
end

function A.BuildPage(page)
  A.DB()
  view.page = page
  local heading = UI.Heading(page, L["Auction House"], 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)
  view.status:SetJustifyH("LEFT")

  local options = CreateFrame("Frame", nil, page)
  options:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -10)
  options:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  options:SetHeight(140)
  BuildPart("options", options)
  local scanLabel = UI.Section(page, L["Full scan"])
  scanLabel:SetPoint("TOPLEFT", options, "BOTTOMLEFT", 0, -8)
  local scan = CreateFrame("Frame", nil, page)
  scan:SetPoint("TOPLEFT", scanLabel, "BOTTOMLEFT", 0, -6)
  scan:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  scan:SetHeight(200)
  BuildPart("scan", scan)
  RefreshCurrent()
end

function A.ShowPageRefresh()
  RefreshCurrent()
end

local function PartSection(id, partId, title, order, folded, keywords)
  ns.AddSection("trade", {
    id = id,
    title = title,
    order = order,
    folded = folded,
    height = 400,
    keywords = keywords,
    build = function(holder)
      A.DB()
      BuildPart(partId, holder)
      if view[partId] and view[partId].Refresh then
        view[partId].Refresh()
      end
    end,
    show = function()
      if view[partId] and view[partId].Refresh then
        view[partId].Refresh()
      end
    end,
  })
end
PartSection("auction-lists", "lists", L["Shopping lists"], 11, false, { "shopping lists search terms max price" })
PartSection("auction-prices", "prices", L["Auction prices"], 12, true, { "prices price history items" })
