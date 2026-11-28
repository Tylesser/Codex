local addonName, ns = ...
local L = ns.L

-- Professions module, part 3: what Codex adds to the profession window.
--  * the block: reagent cost, AH value and profit of the selected recipe, inside the recipe page under the
--    reagents (hover it for the price of each reagent; click it to show or hide the profit list);
--  * the profit list: every recipe sorted by profit, cost, value, margin or cost per skill point, docked to
--    the right of the window (ported from Profit Sort). Right-click recipes to queue them for the shopping list.
-- Both are Codex frames parented to the game's window, so they close with it. Nothing is written to the
-- game's frames; the selection is followed with hooksecurefunc (Providers.lua).

local P = ns.professions
local UI = ns.UI

local block, panel
local hooked = {}
P.all, P.byKey, P.shown = {}, {}, {}

-- Refresh ---------------------------------------------------------------------------------------------------

local refreshPending = false
function P.RequestRefresh()
  if refreshPending or not P.active then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    if P.active then
      P.Refresh()
    end
  end)
end

-- How often the recipe's item is up for sale: on how many of the last P.LISTED_DAYS days Codex saw it at the
-- auction house, of the days Codex scanned at all (Auction History.lua A.DaysListed). nil without the module.
P.LISTED_DAYS = 14
function P.ListedDays(entry)
  local A = ns.auction
  if not (A and A.DaysListed and entry and entry.itemID) then
    return nil
  end
  local ok, listed, scanned = pcall(A.DaysListed, entry.itemID, P.LISTED_DAYS)
  if not ok then
    return nil
  end
  return listed, scanned
end

-- "Up for sale on 9 of the 12 days Codex scanned (last 14 days)" for a tooltip; nil before any scan.
function P.ListedText(entry)
  local listed, scanned = P.ListedDays(entry)
  if not scanned or scanned == 0 then
    return nil
  end
  return L["Up for sale on %d of the %d days Codex scanned (last %d days)"]:format(listed, scanned, P.LISTED_DAYS)
end

-- "Often listed": seen on at least half the scanned days. With fewer than 3 scanned days there is nothing to go
-- by, so every recipe stays.
function P.ListedOften(entry)
  local listed, scanned = P.ListedDays(entry)
  if not scanned or scanned < 3 then
    return true
  end
  return listed * 2 >= scanned
end

-- Rescans the open window: remembers its recipes, prices every recipe, then redraws the block and list.
function P.Refresh()
  local provider = P.active
  if not provider then
    return
  end
  local db = P.db
  local all, complete = provider.Scan()
  local title = provider.GetTitle()
  if provider.IsOwn() then
    P.RememberRecipes(all, title, complete)
    P.RecordCooldowns(provider)
  end
  local crafts = db.craftReagents and P.BuildCraftIndex(all) or nil
  local byKey, shown, priced = {}, {}, 0
  local minHidden, minTotal = 0, 0 -- recipes Min profit hides, of all the other filters keep
  for _, entry in ipairs(all) do
    P.Evaluate(entry, db.ownedFree, crafts)
    byKey[entry.key] = entry
    if entry.unitAH then
      priced = priced + 1
    end
    local keep = entry.visible ~= false
    if db.craftableOnly and entry.numAvailable <= 0 then
      keep = false
    end
    if db.hideUnpriced and entry.value == nil then
      keep = false
    end
    if keep and db.listedOften and not P.ListedOften(entry) then
      keep = false
    end
    if keep then
      minTotal = minTotal + 1
      local profit = entry.profit
      if db.minProfitOn and not (profit and profit > 0 and profit >= db.minProfit) then
        keep = false
        minHidden = minHidden + 1
      end
    end
    if keep then
      shown[#shown + 1] = entry
    end
  end
  P.minHidden, P.minTotal = minHidden, minTotal
  P.SortEntries(shown, db.sortKey, db.ascending)
  P.all, P.byKey, P.shown, P.priced, P.title = all, byKey, shown, priced, title
  P.UpdatePanel()
  P.UpdateBlock()
end

-- The block ------------------------------------------------------------------------------------------------

-- Round-2 design (R2-Professions board): the "Codex profit" box has 10px padding, a heading row (title left,
-- "after 5% AH cut" right), three label/value rows, and at the auction house a row of two equal buttons
-- (magnifier + Search / Reagents) 8px apart under them.
local BOX_PAD, ROW_STEP, BUTTON_H = 10, 16, 22

-- Box look. Design tokens: fill = slotBg (the theme's bright colour at 7%), laid over the inset fill so the
-- text stays readable on the recipe page's art; line = the theme's inset line.
local function SlotBox(frame)
  local theme = UI.ThemeOf(frame)
  local under = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
  under:SetAllPoints()
  UI.SetColor(under, theme.inset.fill)
  local tint = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  tint:SetAllPoints()
  UI.SetColor(tint, theme.bright, 0.07)
  local lines = ns.T.Outline(frame, 0, theme.inset.line, 1, "BORDER")
  ns.T.ColorLines(lines, theme.inset.line, theme.inset.line[4])
end

local function Line(parent, y)
  local left = UI.Text(parent, "body", 12, "muted")
  left:SetPoint("TOPLEFT", BOX_PAD, y)
  local right = UI.Text(parent, "body", 12, "bright")
  right:SetPoint("TOPRIGHT", -BOX_PAD, y)
  right:SetJustifyH("RIGHT")
  return left, right
end

local function ReagentLine(reagent)
  local itemID = reagent.chosenItemID or reagent.itemID
  local name = reagent.name or P.ItemName(itemID) or ("item:" .. tostring(itemID))
  local right
  if reagent.source == "craft" then
    right = "|cff909090" .. L["crafted"] .. "|r " .. ns.Money(reagent.unitPrice * reagent.count)
  elseif reagent.unitPrice then
    right = ns.Money(reagent.unitPrice * reagent.count)
    if reagent.source == "vendor" then
      right = "|cff909090" .. L["vendor"] .. "|r " .. right
    end
  else
    right = "|cffff5050" .. L["no price"] .. "|r"
  end
  return ("%dx %s"):format(reagent.count, name), right
end
P.ReagentLine = ReagentLine

local function BlockOnEnter(self)
  local entry = self.entry
  if not entry then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(entry.name, 1, 0.82, 0)
  for _, reagent in ipairs(entry.reagents) do
    local left, right = ReagentLine(reagent)
    GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
    if reagent.source == "craft" then
      GameTooltip:AddDoubleLine("   |cff909090" .. L["made with %s"]:format(reagent.craftRecipe or "?") .. "|r",
        "|cff909090" .. L["buy:"] .. "|r " .. P.Money(reagent.buyPrice and reagent.buyPrice * reagent.count), 1, 1, 1, 1, 1, 1)
    end
  end
  GameTooltip:AddLine(" ")
  if entry.unitAH then
    GameTooltip:AddDoubleLine(L["Auction price each"], ns.Money(entry.unitAH) .. " |cff999999(" .. ns.Age(entry.seen) .. ")|r",
      1, 1, 1, 1, 1, 1)
  else
    GameTooltip:AddLine(L["No auction price for the item yet: scan at the auction house."], 1, 0.5, 0.25, true)
  end
  local listed = P.ListedText(entry)
  if listed then
    GameTooltip:AddLine(listed, 0.6, 0.6, 0.6, true)
  end
  if entry.fullCostMissing then
    GameTooltip:AddLine(L["Some reagents have no price, so the cost is too low"], 1, 0.5, 0, true)
  end
  GameTooltip:AddLine(P.db.panel and L["Click to hide the profit list."] or L["Click to show the profit list."], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Auction house searches ----------------------------------------------------------------------------------
-- While the auction house is open the block gets two buttons: Search (the recipe's item) and Reagents (every
-- reagent of the recipe, whether you have it or not: the user's request, 2026-11-24). They run the Auction House module's
-- shopping search on a temporary list (not saved), so the results show in the Codex auction panel, where a
-- click opens the game's own buy view. Codex never buys.

function P.AuctionOpen()
  local A = ns.auction
  return (A and A.running and A.open and A.IsModern and A.IsModern()) and true or false
end

-- Searches the auction house for each name (exact; quantities[name] = how many to buy, put in the game's buy view
-- when that result is opened). Returns true when the search started.
function P.SearchAuction(listName, names, quantities)
  local A = ns.auction
  if InCombatLockdown() then
    ns.Say(L["auction searches wait until the fight is over."])
    return false
  end
  if not (A and A.SearchList) or #names == 0 then
    return false
  end
  local list = { name = listName, terms = {} }
  for _, name in ipairs(names) do
    list.terms[#list.terms + 1] = { text = name, exact = true, quantity = quantities and quantities[name] or nil }
  end
  local ok, why = A.SearchList(list)
  if not ok then
    ns.Say(why or L["the search could not start."])
    return false
  end
  if A.ShowPanel then
    A.ShowPanel()
  end
  return true
end

function P.SearchItem(entry)
  local name = P.ItemName(entry.itemID) or entry.name
  return P.SearchAuction(L["Recipe: %s"]:format(entry.name), { name })
end

-- How many crafts the recipe window's count box asks for (forever Blizzard_ProfessionsCrafting.xml:
-- CraftingPage.CreateMultipleInputBox, a NumericInputSpinner), at least one.
function P.CraftCount()
  local page = type(ProfessionsFrame) == "table" and ProfessionsFrame.CraftingPage
  local box = type(page) == "table" and page.CreateMultipleInputBox
  local ok, value = false, nil
  if type(box) == "table" and type(box.GetValue) == "function" then
    ok, value = pcall(box.GetValue, box)
  end
  value = ok and tonumber(value) or nil
  return value and value >= 1 and math.floor(value) or 1
end

-- Every reagent of one craft (the ones you have too, so you can compare prices), how many names haven't loaded,
-- and how many of each to buy (2026-11-24, the user's "set the quantity to what the recipe requires"): what the
-- crafts in the count box need minus what you have, or all of it when you have enough.
function P.ReagentNames(entry)
  local all, unnamed, quantities = {}, 0, {}
  local crafts = P.CraftCount()
  for _, reagent in ipairs(entry.reagents) do
    local itemID = reagent.chosenItemID or reagent.itemID
    if reagent.source == "craft" then
      itemID = reagent.itemID -- you would buy the reagent itself, not what it is crafted from
    end
    local name = reagent.name or P.ItemName(itemID)
    if name then
      all[#all + 1] = name
      local need = (tonumber(reagent.count) or 1) * crafts
      local missing = need - (P.OwnedCount(itemID) or 0)
      quantities[name] = (quantities[name] or 0) + (missing > 0 and missing or need)
    else
      unnamed = unnamed + 1
    end
  end
  return all, unnamed, quantities
end

function P.SearchReagents(entry)
  local names, unnamed, quantities = P.ReagentNames(entry)
  if unnamed > 0 then
    ns.Say(L["%d reagent name(s) haven't loaded yet; try again in a moment."]:format(unnamed))
  end
  return P.SearchAuction(L["Reagents: %s"]:format(entry.name), names, quantities)
end

local SEARCH_ICON = "Interface\\Common\\UI-Searchbox-Icon"

-- A board button: magnifier + label, centred together.
local function SearchButton(text, tip, onClick)
  local width = math.floor((block:GetWidth() - 2 * BOX_PAD - 8) / 2)
  local button = UI.Button(block, width, BUTTON_H, text)
  UI.Font(button.label, "body", 12, UI.ThemeOf(block).button.text)
  button.label:ClearAllPoints()
  button.label:SetPoint("CENTER", 8, 0)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture(SEARCH_ICON)
  button.icon:SetSize(12, 12)
  button.icon:SetPoint("RIGHT", button.label, "LEFT", -5, 0)
  button.icon:SetVertexColor(UI.Unpack(UI.ThemeOf(block).button.text))
  button:SetScript("OnClick", function()
    if block.entry then
      onClick(block.entry)
    end
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button.codexProfRow = true
  button:Hide()
  return button
end

local BLOCK_W = 236
local BLOCK_H = BOX_PAD + 14 + 3 * ROW_STEP + BOX_PAD - 2 -- heading + three rows
local BLOCK_H_SEARCH = BLOCK_H + BUTTON_H + 6             -- plus the search buttons at the auction house

local function CreateBlock(parent)
  -- inside the game's profession window (it carries the game's own text and art): ink surfaces (Dawn)
  block = UI.Ink(CreateFrame("Button", nil, parent))
  block:SetSize(BLOCK_W, BLOCK_H)
  SlotBox(block)
  block.title = UI.Text(block, "head", 11, "accent")
  block.title:SetPoint("TOPLEFT", BOX_PAD, -BOX_PAD + 1)
  block.title:SetText(L["CODEX PROFIT"])
  block.cut = UI.Text(block, "body", 11, "muted")
  block.cut:SetPoint("TOPRIGHT", -BOX_PAD, -BOX_PAD + 1)
  block.cut:SetJustifyH("RIGHT")
  local top = -BOX_PAD - 16
  block.costLabel, block.cost = Line(block, top)
  block.valueLabel, block.value = Line(block, top - ROW_STEP)
  block.profitLabel, block.profit = Line(block, top - 2 * ROW_STEP)
  block.costLabel:SetText(L["Reagent cost"])
  block.profitLabel:SetText(L["Profit"])
  block.note = UI.Text(block, "body", 12, "warn")
  block.note:SetPoint("TOPLEFT", block.valueLabel, "TOPLEFT", 0, 0)
  block.note:SetPoint("RIGHT", -BOX_PAD, 0)
  block.note:SetWordWrap(true)
  block:SetScript("OnEnter", BlockOnEnter)
  block:SetScript("OnLeave", GameTooltip_Hide)
  block:SetScript("OnClick", function()
    P.db.panel = not P.db.panel
    P.UpdatePanel()
    if GameTooltip:GetOwner() == block then
      BlockOnEnter(block)
    end
  end)
  block.codexProfRow = true
  block.searchButton = SearchButton(L["Search"], L["Search the auction house for this recipe's item. Results show in the Codex auction panel."], P.SearchItem)
  block.searchButton:SetPoint("BOTTOMLEFT", BOX_PAD, BOX_PAD - 2)
  block.reagentsButton = SearchButton(L["Reagents"], L["Search the auction house for every reagent of this recipe, also the ones you have. Results show in the Codex auction panel; opening one puts in the amount the recipe needs."], P.SearchReagents)
  block.reagentsButton:SetPoint("BOTTOMRIGHT", -BOX_PAD, BOX_PAD - 2)
  return block
end

-- Shows the selected recipe's figures (full reagent cost, without Owned free).
function P.UpdateBlock()
  local provider = P.active
  if not block then
    return
  end
  local entry = provider and P.byKey[provider.GetSelectedKey()]
  if not (provider and P.db.block and entry) then
    block.entry = nil
    block:Hide()
    return
  end
  block.entry = entry
  block.cut:SetText(L["after %g%% AH cut"]:format(P.db.ahCut))
  -- at the auction house the box grows a row of search buttons
  local auction = P.AuctionOpen()
  block:SetHeight(auction and BLOCK_H_SEARCH or BLOCK_H)
  block.reagentsButton:SetShown(auction)
  block.searchButton:SetShown(auction)
  block.searchButton:SetEnabled(entry.itemID ~= nil)
  local cost = entry.fullCost
  local costText = (cost > 0 or not entry.fullCostMissing) and ns.Money(cost) or "|cff808080--|r"
  block.cost:SetText(costText .. (entry.fullCostMissing and "|cffff8000*|r" or ""))
  if entry.unitAH then
    local made = entry.numMade ~= 1 and (" x%g"):format(entry.numMade) or ""
    block.valueLabel:SetText(L["AH value"] .. made)
    block.value:SetText(ns.Money(entry.value))
    local profit = entry.value - cost
    local margin = cost > 0 and profit / cost or nil
    block.profit:SetText(P.Money(profit, true) .. (margin and ("  " .. P.Margin(margin)) or ""))
    block.note:Hide()
    for _, region in ipairs({ block.valueLabel, block.value, block.profitLabel, block.profit }) do
      region:Show()
    end
  else
    for _, region in ipairs({ block.valueLabel, block.value, block.profitLabel, block.profit }) do
      region:Hide()
    end
    block.note:SetText(L["No price yet - scan at the auction house."])
    block.note:Show()
  end
  block:Show()
end

-- The profit list --------------------------------------------------------------------------------------------

-- Round-2 design: panel 564 wide (7px frame padding), a 40px title bar with a line under it, the table in one
-- inset box (8px below the title bar, 4px in) with a 24px header row whose sorted column is in the accent
-- colour, 20px rows, the filter row, and a 40px footer with "x / y priced" and the Shopping list button.
local COLUMNS = {
  { key = "name", label = L["Recipe"], width = 190, justify = "LEFT" },
  { key = "cost", label = L["Cost"], width = 66, justify = "RIGHT" },
  { key = "value", label = L["AH value"], width = 66, justify = "RIGHT" },
  { key = "profit", label = L["Profit"], width = 64, justify = "RIGHT" },
  { key = "margin", label = L["Margin"], width = 50, justify = "RIGHT" },
  { key = "skillCost", label = L["Per skill"], width = 56, justify = "RIGHT" },
}
local GAP, ICON, LEFTPAD = 6, 24, 4 -- ICON: the 16px row icon plus an 8px gap before the name
-- FILTER_H: two rows over the footer, the three filter checks and under them Min profit
local WIDTH, PAD, TITLE_H, HEADER_H, ROW_H, FOOTER_H, FILTER_H = 564, 7, 40, 24, 20, 40, 60
local FILTER_ROW = 26

local function SetSort(key)
  local db = P.db
  if db.sortKey == key then
    db.ascending = not db.ascending
  else
    db.sortKey = key
    db.ascending = key == "name" or key == "skillCost" -- names and cost per point read best A / cheapest first
  end
  P.Refresh()
end

local function RowOnClick(self, button)
  local entry = self.item
  if not entry then
    return
  end
  if button == "RightButton" then
    P.ChangeQueue(entry, IsShiftKeyDown() and -1 or 1)
    P.UpdatePanel()
    return
  end
  if IsModifiedClick and IsModifiedClick("CHATLINK") and entry.link then
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if insert and insert(entry.link) then
      return
    end
  end
  P.selectedKey = entry.key
  if P.active then
    P.active.Select(entry)
  end
  P.UpdatePanel()
end

local function RowOnEnter(self)
  local entry = self.item
  if not entry then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(entry.name, 1, 0.82, 0)
  for _, reagent in ipairs(entry.reagents) do
    local left, right = ReagentLine(reagent)
    if reagent.owned and reagent.owned > 0 then
      left = left .. " |cff40ff40" .. L["(have %d)"]:format(reagent.owned) .. "|r"
    end
    GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
    if reagent.ownedAlts then
      GameTooltip:AddLine("   |cff909090" .. L["on your other characters: %s"]:format(P.AltText(reagent.ownedAlts)) .. "|r",
        1, 1, 1, true)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine(entry.ownedFree and L["Cost to buy what you lack"] or L["Reagent cost"], P.Money(entry.cost),
    1, 1, 1, 1, 1, 1)
  if entry.unitAH then
    local made = entry.numMade ~= 1 and (" x%g"):format(entry.numMade) or ""
    GameTooltip:AddDoubleLine(L["AH value%s (after %g%% cut)"]:format(made, P.db.ahCut), ns.Money(entry.value),
      1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Profit"], P.Money(entry.profit, true), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(L["Price seen %s ago"]:format(ns.Age(entry.seen)), 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine(L["No auction price for the item yet"], 1, 0.5, 0.25)
  end
  local listed = P.ListedText(entry)
  if listed then
    GameTooltip:AddLine(listed, 0.6, 0.6, 0.6, true)
  end
  if entry.missingReagents then
    GameTooltip:AddLine(L["Some reagents have no price, so the cost is too low"], 1, 0.5, 0)
  end
  if entry.skillChance then
    if entry.skillCost then
      GameTooltip:AddDoubleLine(L["Skill-up chance ~%d%%%s"]:format(entry.skillChance * 100, ""),
        P.Money(entry.skillCost) .. " " .. L["per point"], 1, 1, 1, 1, 1, 1)
    else
      GameTooltip:AddLine(L["Gray recipe: no more skill points"], 0.6, 0.6, 0.6)
    end
  end
  local queued = P.QueuedCount(entry)
  if queued > 0 then
    GameTooltip:AddLine((L["Queued: %d for the shopping list"]):format(queued), 0.4, 0.73, 1)
  end
  GameTooltip:AddLine(L["Click to select, Shift-click to link"], 0.5, 0.5, 0.5)
  GameTooltip:AddLine(L["Right-click to queue, Shift-right-click to unqueue"], 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function CreateRow(row)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.codexProfRow = true -- Tooltip.lua leaves these alone
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", LEFTPAD, 0)
  row.cells = {}
  local x = LEFTPAD
  for index, column in ipairs(COLUMNS) do
    local cell = UI.Text(row, "body", 12, "text")
    cell:SetJustifyH(column.justify)
    cell:SetWordWrap(false)
    if index == 1 then
      cell:SetPoint("LEFT", x + ICON, 0)
      cell:SetWidth(column.width - ICON)
    else
      cell:SetPoint("LEFT", x, 0)
      cell:SetWidth(column.width)
    end
    row.cells[column.key] = cell
    x = x + column.width + GAP
  end
  row:SetScript("OnClick", RowOnClick)
  row:SetScript("OnEnter", RowOnEnter)
  row:SetScript("OnLeave", GameTooltip_Hide)
end

local function UpdateRow(row, entry)
  row.icon:SetTexture(entry.icon)
  local name = entry.name
  if entry.numAvailable > 0 then
    name = name .. " |cff80ff80[" .. entry.numAvailable .. "]|r"
  end
  local queued = P.QueuedCount(entry)
  if queued > 0 then
    name = name .. " |cff66bbffQ" .. queued .. "|r"
  end
  row.cells.name:SetText(name)
  -- the recipe's difficulty colour (the game's), kept readable on a light theme (Dawn); else the theme's bright
  local theme = ns.UI.ThemeOf(row)
  local color = entry.color and { entry.color.r, entry.color.g, entry.color.b } or theme.bright
  if theme.light then
    color = ns.ReadableColor(color, ns.Ground(theme))
  end
  row.cells.name:SetTextColor(color[1], color[2], color[3])
  local warning = entry.missingReagents and "|cffff8000*|r" or ""
  -- compact money here ("1g 17s", "94s 72c"); the row tooltip has the full amounts
  row.cells.cost:SetText(P.ShortMoney(entry.cost) .. warning)
  row.cells.value:SetText(P.ShortMoney(entry.value))
  row.cells.profit:SetText(P.ShortMoney(entry.profit))
  row.cells.margin:SetText(P.Margin(entry.margin))
  row.cells.skillCost:SetText(entry.skillCost and (P.ShortMoney(entry.skillCost) .. warning) or P.ShortMoney(nil))
  row.selected:SetShown(entry.key == (P.selectedKey or (P.active and P.active.GetSelectedKey())))
end

local function Check(parent, label, key, tip)
  local check = UI.Check(parent, label)
  check:SetHitRectInsets(0, -(check.label:GetStringWidth() + 4), 0, 0)
  check.key = key
  check:SetScript("OnClick", function(self)
    P.db[key] = self:GetChecked() and true or false
    P.Refresh()
  end)
  check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", GameTooltip_Hide)
  return check
end

local MIN_TIP = L["Hide recipes that earn less than this per craft (after the auction house cut), every recipe that loses money, and recipes without an auction price."]
  .. " " .. L["At 0 only losses and break-even recipes are hidden."]

-- The Min profit box: Enter or clicking elsewhere applies the amount (and turns the filter on), Escape undoes.
local function ApplyMinProfit(box)
  local db = P.db
  local amount = P.ParseMoney(box:GetText())
  if box.edited and amount and (amount ~= db.minProfit or not db.minProfitOn) then
    db.minProfit, db.minProfitOn = amount, true
    P.Refresh()
  end
  box.edited = false
  box:SetText(P.PlainMoney(db.minProfit))
end

local function CreatePanel(parent)
  local theme = ns.Theme()
  panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(WIDTH)
  panel:EnableMouse(true)
  UI.Panel(panel, { cornerSize = 14 })

  panel.title = UI.Heading(panel, L["Profit"], 16)
  panel.title:SetPoint("LEFT", panel, "TOPLEFT", PAD + 12, -PAD - TITLE_H / 2)
  local close = UI.CloseButton(panel)
  close:SetSize(24, 24)
  close:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD - 6, -PAD - TITLE_H / 2)
  close:SetScript("OnClick", function()
    P.db.panel = false
    P.UpdatePanel()
  end)
  -- crafting cooldowns of all your characters (Cooldowns.lua): hover for the list, click to print it
  local clock = CreateFrame("Button", nil, panel)
  clock:SetSize(20, 20)
  clock:SetPoint("RIGHT", close, "LEFT", -8, 0)
  clock.icon = clock:CreateTexture(nil, "ARTWORK")
  clock.icon:SetAllPoints()
  clock.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
  clock.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  clock:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  clock.count = UI.Text(clock, "body", 11, "good")
  clock.count:SetPoint("BOTTOMRIGHT", 3, -3)
  clock:SetScript("OnClick", P.PrintCooldowns)
  clock:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(L["Crafting cooldowns"], 1, 0.82, 0)
    P.AddCooldownLines(GameTooltip)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click to print the list in chat (also /codex cooldowns)."], 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
  end)
  clock:SetScript("OnLeave", GameTooltip_Hide)
  clock.codexProfRow = true
  panel.clock = clock
  local titleLine = UI.Divider(panel)
  titleLine:SetPoint("TOPLEFT", PAD, -PAD - TITLE_H)
  titleLine:SetPoint("TOPRIGHT", -PAD, -PAD - TITLE_H)
  UI.SetColor(titleLine, theme.inset.line) -- design token: line

  -- the table: one box with the header row on top and the list under it
  local box = CreateFrame("Frame", nil, panel)
  box:SetPoint("TOPLEFT", PAD + 4, -PAD - TITLE_H - 8)
  box:SetPoint("BOTTOMRIGHT", -PAD - 4, PAD + FOOTER_H + FILTER_H)
  local headerFill = box:CreateTexture(nil, "BACKGROUND", nil, -6)
  headerFill:SetPoint("TOPLEFT")
  headerFill:SetPoint("TOPRIGHT")
  headerFill:SetHeight(HEADER_H)
  UI.SetColor(headerFill, theme.inset.fill)
  local boxLines = ns.T.Outline(box, 0, theme.inset.line, 1, "BORDER")
  ns.T.ColorLines(boxLines, theme.inset.line, theme.inset.line[4])
  panel.box = box

  panel.headers = {}
  local x = 2 + LEFTPAD -- the list's rows start 2px in
  for _, column in ipairs(COLUMNS) do
    local header = CreateFrame("Button", nil, box)
    header:SetSize(column.width, HEADER_H)
    header:SetPoint("TOPLEFT", column.key == "name" and (x - LEFTPAD) or x, 0)
    header.key, header.justify = column.key, column.justify
    header.label = UI.Text(header, "body", 11, "muted")
    header.label:SetJustifyH(column.justify)
    header.label:SetPoint("TOPLEFT", column.key == "name" and (ICON + LEFTPAD) or 0, 0)
    header.label:SetPoint("BOTTOMRIGHT", column.justify == "RIGHT" and -11 or 0, 0)
    header.label:SetText(column.label)
    header.arrow = header:CreateTexture(nil, "OVERLAY")
    header.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    header.arrow:SetSize(9, 8)
    if column.justify == "LEFT" then
      header.arrow:SetPoint("LEFT", header, "LEFT", ICON + LEFTPAD + header.label:GetStringWidth() + 3, 0)
    else
      header.arrow:SetPoint("RIGHT")
    end
    header:SetScript("OnClick", function(self)
      SetSort(self.key)
    end)
    panel.headers[#panel.headers + 1] = header
    x = x + column.width + GAP
  end

  panel.list = UI.List(box, { rowHeight = ROW_H, CreateRow = CreateRow, UpdateRow = UpdateRow })
  panel.list:SetPoint("TOPLEFT", 0, -HEADER_H)
  panel.list:SetPoint("BOTTOMRIGHT", 0, 0)

  panel.craftable = Check(panel, L["Craftable now"], "craftableOnly", L["Only show recipes you have the reagents for right now."])
  panel.craftable:SetPoint("BOTTOMLEFT", PAD + 6, PAD + FOOTER_H + 6 + FILTER_ROW)
  panel.priced = Check(panel, L["Has AH price"], "hideUnpriced", L["Hide recipes whose item has no Codex auction price."])
  panel.priced:SetPoint("LEFT", panel.craftable.label, "RIGHT", 22, 0)
  local ownedTip = L["Count reagents already in your bags and bank as free, so Cost and Profit show what crafting from your own stock earns."]
  panel.owned = Check(panel, L["Owned free"], "ownedFree", ownedTip)
  panel.owned:SetPoint("LEFT", panel.priced.label, "RIGHT", 22, 0)
  panel.owned:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(ownedTip, 1, 1, 1, 1, true)
    if P.db.ownedAlts then
      local source = P.AltSource()
      if source == "bags" then
        GameTooltip:AddLine(L["Also counts your other characters' bags and bank (from Codex's bag records)."], 0.6, 0.6, 0.6, true)
      elseif source == "syndicator" then
        GameTooltip:AddLine(L["Also counts your other characters' bags, bank and mail (from Syndicator)."], 0.6, 0.6, 0.6, true)
      else
        GameTooltip:AddLine(L["Your other characters are counted with the Bags module on, or with Syndicator."], 1, 0.5, 0.25, true)
      end
    end
    GameTooltip:Show()
  end)

  panel.minProfit = Check(panel, L["Min profit"], "minProfitOn", MIN_TIP)
  panel.minProfit:SetPoint("BOTTOMLEFT", PAD + 6, PAD + FOOTER_H + 6)
  panel.minProfit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(MIN_TIP, 1, 1, 1, 1, true)
    if P.db.minProfitOn then
      GameTooltip:AddLine((L["Hides %d of %d recipes."]):format(P.minHidden or 0, P.minTotal or 0), 0.25, 1, 0.25, true)
    end
    GameTooltip:Show()
  end)
  local box = UI.EditBox(panel, 76, 20)
  box:SetMaxLetters(16)
  box:SetPoint("LEFT", panel.minProfit.label, "RIGHT", 10, 0)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self.edited = true
    end
  end)
  box:SetScript("OnEnterPressed", function(self)
    ApplyMinProfit(self)
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", ApplyMinProfit)
  box:SetScript("OnEscapePressed", function(self)
    self.edited = false
    self:ClearFocus()
  end)
  box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(L["Min profit per craft"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Type an amount like 50s, 1g or 1g 50s (a plain number is silver), then press Enter."],
      1, 1, 1, true)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", GameTooltip_Hide)
  panel.minBox = box

  panel.often = Check(panel, L["Often listed"], "listedOften",
    L["Only recipes whose item Codex saw up for sale on at least half the days it scanned in the last 14 (every recipe stays until Codex has scanned on 3 days). Codex sees listings, not sales."])
  panel.often:SetPoint("LEFT", box, "RIGHT", 22, 0)

  panel.shopping = UI.Button(panel, 150, 26, L["Shopping list"])
  panel.shopping:SetPoint("BOTTOMRIGHT", -PAD - 4, PAD + 7)
  panel.shopping:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  panel.shopping:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      P.ClearQueue()
    else
      P.CreateShoppingList()
    end
    P.UpdatePanel()
  end)
  panel.shopping:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Codex shopping list"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Right-click recipes to queue crafts, then click here."], 1, 1, 1, true)
    GameTooltip:AddLine(L["Writes the reagents you still need (minus your bags and bank) to the Codex shopping list \"%s\". At the auction house, click it in the Codex panel to search."]:format(P.LIST_NAME), 1, 1, 1, true)
    local toBuy, toCraft = P.ReagentsToBuy()
    if #toBuy > 0 then
      GameTooltip:AddLine(" ")
      for _, reagent in ipairs(toBuy) do
        GameTooltip:AddDoubleLine(reagent.name or ("item:" .. tostring(reagent.itemID)), reagent.count, 1, 1, 1, 1, 1, 1)
      end
    end
    if #toCraft > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L["Craft first (their reagents are in the list):"], 1, 0.82, 0)
      for _, reagent in ipairs(toCraft) do
        GameTooltip:AddDoubleLine(reagent.name or ("item:" .. tostring(reagent.itemID)),
          ("%dx %s"):format(reagent.count, reagent.recipe or "?"), 1, 1, 1, 0.6, 0.6, 0.6)
      end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Right-click to clear the queue"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  panel.shopping:SetScript("OnLeave", GameTooltip_Hide)

  panel.status = UI.Text(panel, "body", 12, "muted")
  panel.status:SetPoint("LEFT", panel, "BOTTOMLEFT", PAD + 8, PAD + FOOTER_H / 2)
  panel.status:SetPoint("RIGHT", panel.shopping, "LEFT", -8, 0)
  return panel
end

function P.UpdatePanel()
  if not panel then
    return
  end
  local db = P.db
  if not (P.active and db.panel) then
    panel:Hide()
    return
  end
  panel:Show()
  panel.title:SetText(L["Profit · %s"]:format(P.title or L["Profession"])) -- "Profit · Blacksmithing"
  panel.craftable:SetChecked(db.craftableOnly)
  panel.priced:SetChecked(db.hideUnpriced)
  panel.owned:SetChecked(db.ownedFree)
  panel.minProfit:SetChecked(db.minProfitOn)
  panel.often:SetChecked(db.listedOften)
  local ready = P.ReadyCooldowns()
  panel.clock.count:SetText(ready > 0 and ready or "")
  if not panel.minBox:HasFocus() then
    panel.minBox:SetText(P.PlainMoney(db.minProfit))
  end
  for _, header in ipairs(panel.headers) do
    local sorted = header.key == db.sortKey
    header.label:SetTextColor(UI.Unpack(ns.Theme()[sorted and "accent" or "muted"]))
    if header.justify == "RIGHT" then
      -- flush with the numbers under it; the sorted column makes room for its arrow
      header.label:SetPoint("BOTTOMRIGHT", sorted and -11 or 0, 0)
    end
    if sorted then
      header.arrow:SetTexCoord(0, 0.5625, db.ascending and 1 or 0, db.ascending and 0 or 1)
      header.arrow:SetVertexColor(UI.Unpack(ns.Theme().accent))
      header.arrow:Show()
    else
      header.arrow:Hide()
    end
  end
  panel.list:SetItems(P.shown)
  if #P.all > 0 and (P.priced or 0) == 0 then
    panel.status:SetText("|cffff8000" .. L["No price yet - scan at the auction house."] .. "|r")
  else
    panel.status:SetText(L["%d / %d priced"]:format(P.priced or 0, #P.all))
  end
  local total = P.QueueTotal()
  panel.shopping:SetText(total > 0 and (L["Shopping list (%d)"]):format(total) or L["Shopping list"])
end

-- Docking --------------------------------------------------------------------------------------------------
-- Forever's profession window has round profession tabs sticking out of its right edge. The list docks to
-- the right of whatever the window shows there (its children and grandchildren that reach past its right
-- edge); with no room on the right it docks on the left of the window instead.

local function Number(fn, frame)
  local ok, value = pcall(fn, frame)
  if ok and type(value) == "number" and P.Readable(value) then
    return value
  end
end

-- How far the window's own parts (side tabs) reach past its right edge, in the window's coordinates.
function P.RightOverhang(frame)
  local right = frame.GetRight and Number(frame.GetRight, frame)
  if not right then
    return 0
  end
  local reach = right
  local function Walk(parent, depth)
    if not parent.GetChildren then
      return
    end
    for _, child in ipairs({ parent:GetChildren() }) do
      if child ~= panel and child.IsShown and child:IsShown() then
        local childRight = Number(child.GetRight, child)
        local childLeft = Number(child.GetLeft, child)
        -- a part that starts inside or just at the edge (not a separate window docked further away)
        if childRight and childLeft and childRight > reach and childLeft < right + 40 then
          local scale = (Number(child.GetEffectiveScale, child) or 1) / (Number(frame.GetEffectiveScale, frame) or 1)
          reach = math.max(reach, childRight * scale)
        end
        if depth < 2 then
          Walk(child, depth + 1)
        end
      end
    end
  end
  Walk(frame, 1)
  -- Forever's side tabs by name (as other Forever addons find them): the overview tab, one tab per
  -- profession, and the side bar some of them sit on
  if frame == ProfessionsFrame then
    local tabs = { frame.ProfessionsOverviewTab }
    for _, tab in ipairs(type(frame.rightProfessionTabs) == "table" and frame.rightProfessionTabs or {}) do
      tabs[#tabs + 1] = tab
    end
    local sideBar = ProfessionsFrameTabSideBar
    if type(sideBar) == "table" and sideBar.GetChildren then
      tabs[#tabs + 1] = sideBar
      Walk(sideBar, 2)
    end
    for _, tab in ipairs(tabs) do
      if type(tab) == "table" and tab.IsShown and tab:IsShown() then
        local tabRight = Number(tab.GetRight, tab)
        if tabRight then
          local scale = (Number(tab.GetEffectiveScale, tab) or 1) / (Number(frame.GetEffectiveScale, frame) or 1)
          reach = math.max(reach, tabRight * scale)
        end
      end
    end
  end
  return math.max(0, math.ceil(reach - right))
end

function P.PlacePanel(provider)
  if not panel then
    return
  end
  local frame = provider.GetFrame()
  local x = provider.dockX + P.RightOverhang(frame)
  local bottom = provider.dockY == 0 and 0 or 72
  local right = Number(frame.GetRight, frame)
  local left = Number(frame.GetLeft, frame)
  local screen = UIParent and Number(UIParent.GetRight, UIParent)
  local scale = (Number(frame.GetEffectiveScale, frame) or 1) / ((UIParent and Number(UIParent.GetEffectiveScale, UIParent)) or 1)
  panel:ClearAllPoints()
  if right and left and screen and (right + x + panel:GetWidth()) * scale > screen and left * scale > panel:GetWidth() * scale then
    -- no room on the right: dock on the left of the window
    panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -2, provider.dockY)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -2, bottom)
    P.panelSide = "left"
  else
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", x, provider.dockY)
    panel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", x, bottom)
    P.panelSide = "right"
  end
  panel:SetClampedToScreen(true)
end

-- Attaching to a window ---------------------------------------------------------------------------------------

local function Attach(provider)
  local frame = provider.GetFrame()
  if not hooked[provider] then
    -- false while the window's parts aren't there yet: tried again next time
    hooked[provider] = provider.Hook(function()
      if P.active == provider then
        P.selectedKey = nil
        P.UpdateBlock()
        if panel and panel:IsShown() then
          panel.list:Refresh()
        end
      end
    end)
  end
  if not hooked[frame] then
    hooked[frame] = true
    frame:HookScript("OnHide", function()
      P.Deactivate(provider)
    end)
  end

  local blockParent = provider.BlockParent()
  if blockParent then
    if not block then
      CreateBlock(blockParent)
    end
    block:SetParent(blockParent)
    block:ClearAllPoints()
    provider.PlaceBlock(block, blockParent)
    pcall(function()
      block:SetFrameLevel((blockParent:GetFrameLevel() or 1) + 20)
    end)
  end

  if not panel then
    CreatePanel(frame)
  end
  panel:SetParent(frame)
  P.PlacePanel(provider)
  -- the window may add its side tabs a moment after it shows
  C_Timer.After(0.5, function()
    if P.active == provider then
      P.PlacePanel(provider)
    end
  end)
end

function P.Activate(provider)
  if not provider or not provider.IsAvailable() or not provider.GetFrame() then
    return false
  end
  P.active = provider
  P.selectedKey = nil
  Attach(provider)
  P.Refresh()
  return true
end

function P.Deactivate(provider)
  if P.active ~= provider then
    return
  end
  P.active = nil
  P.all, P.byKey, P.shown = {}, {}, {}
  if block then
    block:Hide()
  end
  if panel then
    panel:Hide()
  end
  -- another profession window (Enchanting next to Tailoring in the old clients) may still be open
  for _, other in pairs(P.Providers) do
    if other ~= provider and other.IsAvailable() then
      local frame = other.GetFrame()
      if frame and frame:IsShown() then
        P.Activate(other)
        return
      end
    end
  end
end

local function DetectTradeSkill()
  local providers = P.Providers
  if ProfessionsFrame and ProfessionsFrame:IsShown() and providers.Professions.IsAvailable() then
    return providers.Professions
  end
  if TradeSkillFrame and TradeSkillFrame:IsShown() and providers.TradeSkill.IsAvailable() then
    return providers.TradeSkill
  end
end

-- The game shows its window from its own TRADE_SKILL_SHOW handler, which may run after ours.
function P.ActivateTradeSkill(retries)
  local provider = DetectTradeSkill()
  if provider then
    P.Activate(provider)
  elseif retries > 0 then
    C_Timer.After(0.2, function()
      P.ActivateTradeSkill(retries - 1)
    end)
  end
end

function P.ActivateCraft(retries)
  if CraftFrame and CraftFrame:IsShown() then
    P.Activate(P.Providers.Craft)
  elseif retries > 0 then
    C_Timer.After(0.2, function()
      P.ActivateCraft(retries - 1)
    end)
  end
end

function P.Block()
  return block
end

function P.Panel()
  return panel
end
