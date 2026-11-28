local addonName, ns = ...
local L = ns.L

-- Auction house module, part 5: a themed Codex panel docked to the right of the game's auction house
-- window. It lists the shopping lists (click one to search all its terms), shows the results (click one to
-- open it in the game's own buy view) and has the full scan button. "Below vendor" shows the items on sale for
-- less than a vendor pays (Below.lua) in the same result list, with a Buy button under it (Buy.lua: one click buys
-- the top item while it is under the vendor price). "Upgrades" (Upgrades.lua) lists the gear on sale that beats what
-- you wear by the Stat Delta module's score. It never bids or posts.

local A = ns.auction
local UI = ns.UI

local WIDTH = 270
local panel

-- The result list ends above the Buy button in vendor mode.
local function PlaceResults(vendor)
  if panel.resultsVendor == vendor then
    return
  end
  panel.resultsVendor = vendor
  panel.results:ClearAllPoints()
  panel.results:SetPoint("TOPLEFT", panel.searchText, "BOTTOMLEFT", 0, -8)
  panel.results:SetPoint("BOTTOMRIGHT", -12, vendor and 62 or 12)
end

local function RefreshPanel()
  if not panel or not panel:IsShown() then
    return
  end
  panel.scanText:SetText(A.ScanText())
  panel.scan:SetEnabled(A.scan.state == "idle" and A.NextScanIn() == 0)
  panel.lists:SetItems(A.Lists())
  local vendor = panel.mode == "vendor"
  PlaceResults(vendor)
  panel.buy:SetShown(vendor)
  panel.buyText:SetShown(vendor)
  panel.stacks:SetShown(vendor)
  if vendor then
    A.PrepareBuy() -- (searches the top item so the next click can buy it)
    panel.searchText:SetText(A.BelowText())
    panel.stop:Hide()
    panel.sort:SetText(A.BelowSort() == "each" and L["Each"] or L["Total"])
    panel.sort:Show()
    panel.results:SetItems(A.BelowRows())
    local state = A.buy.state
    panel.buyText:SetText(A.BuyText())
    panel.buy:SetEnabled(state == "ready")
    panel.buy:SetText((state == "quote" or state == "buying") and L["Buying..."] or L["Buy"])
    panel.stacks:SetText(A.BuyStacksOnly() and L["Stacks only"] or L["All items"])
    return
  end
  panel.sort:Hide()
  if panel.mode == "upgrades" then
    panel.stop:Hide()
    local rows, text = A.UpgradeRows()
    panel.searchText:SetText(text)
    panel.results:SetItems(rows)
    return
  end
  panel.searchText:SetText(A.SearchText())
  local busy = A.shop.state == "searching" or A.shop.state == "throttled"
  panel.stop:SetShown(busy)
  panel.results:SetItems(A.shop.results)
end
A.RefreshPanel = RefreshPanel

local function CreatePanel()
  local host = AuctionHouseFrame
  panel = CreateFrame("Frame", "CodexAuctionPanel", host)
  panel:SetWidth(WIDTH)
  panel:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0)
  panel:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", 4, 0)
  panel:EnableMouse(true)
  UI.Panel(panel, { cornerSize = 14 })

  local title = UI.Heading(panel, "Codex", 16)
  title:SetPoint("TOPLEFT", 14, -12)
  local emblem = panel:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ns.T.EMBLEM)
  emblem:SetSize(18, 18)
  emblem:SetPoint("LEFT", title, "RIGHT", 6, 0)
  local open = UI.Button(panel, 70, 20, L["Prices"])
  open:SetPoint("TOPRIGHT", -12, -10)
  open:SetScript("OnClick", function()
    ns.ShowPage("auction-prices")
  end)
  -- gear on sale that beats what you wear (Upgrades.lua)
  panel.upgrades = UI.Button(panel, 80, 20, L["Upgrades"])
  panel.upgrades:SetPoint("RIGHT", open, "LEFT", -6, 0)
  panel.upgrades:SetScript("OnClick", function()
    panel.mode = "upgrades"
    RefreshPanel()
  end)
  panel.upgrades:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Upgrades on sale"])
    GameTooltip:AddLine(L["Gear on sale that beats what you wear by the upgrade score of Codex's Stat Delta (items you can use): the prices Codex saved in the last two days (a full scan, browsing, searching). Biggest gain first."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel.upgrades:SetScript("OnLeave", GameTooltip_Hide)

  panel.scan = UI.Button(panel, 100, 24, L["Full scan"])
  panel.scan:SetPoint("TOPLEFT", 12, -40)
  panel.scan:SetScript("OnClick", function()
    A.ScanCommand()
  end)
  panel.vendor = UI.Button(panel, 120, 24, L["Below vendor"])
  panel.vendor:SetPoint("LEFT", panel.scan, "RIGHT", 8, 0)
  panel.vendor:SetScript("OnClick", function()
    panel.mode = "vendor"
    RefreshPanel()
  end)
  panel.vendor:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Below vendor price"])
    GameTooltip:AddLine(L["Items on sale for less than a vendor pays for them: the last full scan and every price Codex saved since (browsing, searching). Most profit first: in total, or per item with the button beside the list."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel.vendor:SetScript("OnLeave", GameTooltip_Hide)
  panel.scanText = UI.Text(panel, "body", 11, "muted")
  panel.scanText:SetPoint("TOPLEFT", panel.scan, "BOTTOMLEFT", 0, -4)
  panel.scanText:SetPoint("RIGHT", -12, 0)

  local listsLabel = UI.Text(panel, "head", 11, "muted")
  listsLabel:SetPoint("TOPLEFT", panel.scan, "BOTTOMLEFT", 0, -26)
  listsLabel:SetText(L["SHOPPING LISTS"])
  panel.lists = UI.List(panel, {
    rowHeight = 20,
    CreateRow = function(row)
      row.text = UI.Text(row, "body", 12, "text")
      row.text:SetPoint("LEFT", 6, 0)
      row.text:SetPoint("RIGHT", -6, 0)
      row.text:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        panel.mode = "shop"
        local ok, why = A.SearchList(self.item)
        if not ok then
          ns.Say(why)
        end
      end)
    end,
    UpdateRow = function(row, list)
      row.text:SetText(("%s |cff999999(%d)|r"):format(list.name, #list.terms))
      row.selected:SetShown(panel.mode ~= "vendor" and panel.mode ~= "upgrades" and list == A.shop.list
        and A.shop.state ~= "idle")
    end,
  })
  panel.lists:SetPoint("TOPLEFT", listsLabel, "BOTTOMLEFT", 0, -4)
  panel.lists:SetPoint("RIGHT", -12, 0)
  panel.lists:SetHeight(124)
  local edit = UI.Button(panel, 90, 20, L["Edit lists"])
  edit:SetPoint("TOPLEFT", panel.lists, "BOTTOMLEFT", 0, -4)
  edit:SetScript("OnClick", function()
    ns.ShowPage("auction-lists")
  end)

  panel.searchText = UI.Text(panel, "body", 11, "accent")
  panel.searchText:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -12)
  panel.searchText:SetPoint("RIGHT", -64, 0)
  panel.searchText:SetWordWrap(false)
  panel.stop = UI.Button(panel, 48, 20, L["Stop"])
  panel.stop:SetPoint("TOPRIGHT", panel.lists, "BOTTOMRIGHT", 0, -28)
  panel.stop:SetScript("OnClick", function()
    A.StopSearch()
  end)
  -- (vendor mode, in the Stop button's place: what "Below vendor" is sorted by)
  panel.sort = UI.Button(panel, 48, 20, L["Total"])
  panel.sort:SetPoint("TOPRIGHT", panel.lists, "BOTTOMRIGHT", 0, -28)
  panel.sort:Hide()
  panel.sort:SetScript("OnClick", function()
    A.DB().belowSort = A.BelowSort() == "each" and "total" or "each"
    RefreshPanel()
  end)
  panel.sort:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Sort by profit"])
    GameTooltip:AddLine(A.BelowSort() == "each"
      and L["Each: what one item makes (vendor price minus the lowest price). Click for the total."]
      or L["Total: what buying every cheap one and selling it to a vendor makes. Click for the profit on one item."],
      0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel.sort:SetScript("OnLeave", GameTooltip_Hide)

  panel.results = UI.List(panel, {
    rowHeight = 22,
    CreateRow = function(row)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.icon:SetSize(16, 16)
      row.icon:SetPoint("LEFT", 4, 0)
      row.price = UI.Text(row, "body", 11, "bright")
      row.price:SetPoint("RIGHT", -4, 0)
      row.price:SetJustifyH("RIGHT")
      row.count = UI.Text(row, "body", 11, "muted")
      row.count:SetPoint("RIGHT", row.price, "LEFT", -6, 0)
      row.name = UI.Text(row, "body", 11, "text")
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
      row.name:SetPoint("RIGHT", row.count, "LEFT", -4, 0)
      row.name:SetWordWrap(false)
      row.deal = row:CreateTexture(nil, "BACKGROUND", nil, -4)
      row.deal:SetAllPoints()
      UI.SetColor(row.deal, ns.Theme().good, 0.12)
      row:SetScript("OnClick", function(self)
        if self.item and IsShiftKeyDown() then
          local key = self.item.key or (self.item.result and A.KeyOf(self.item.result.itemKey))
          if key then
            A.ShowHistory(key)
          end
          return
        end
        if self.item and not A.OpenResult(self.item) then
          ns.Say(L["The auction house window couldn't open this item; search for it by name."])
        end
      end)
      row:SetScript("OnEnter", function(self)
        local entry = self.item
        if not entry then
          return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local key = entry.key or (entry.result and A.KeyOf(entry.result.itemKey))
        local link = entry.link or (key and A.Hyperlink(key))
        if link then
          GameTooltip:SetHyperlink(link)
        else
          GameTooltip:AddLine(entry.name)
        end
        GameTooltip:AddLine(" ")
        local below = entry.below
        if below then
          GameTooltip:AddDoubleLine(L["Lowest price"], ns.Money(below.l), 0.8, 0.8, 0.8, 1, 1, 1)
          GameTooltip:AddDoubleLine(L["Vendor pays"], ns.Money(below.s), 0.8, 0.8, 0.8, 1, 1, 1)
          GameTooltip:AddDoubleLine(L["Profit for one"], ns.Money(math.max(0, below.s - below.l)), 0.8, 0.8, 0.8, 1, 1, 1)
          if below.u then
            GameTooltip:AddDoubleLine(L["Below the vendor price"], below.u, 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine(L["Profit for all of them"], ns.Money(below.p), 0.8, 0.8, 0.8, 1, 1, 1)
          end
          if below.seen then
            GameTooltip:AddDoubleLine(L["Price seen"], L["%s ago"]:format(ns.Age(below.seen)), 0.8, 0.8, 0.8, 1, 1, 1)
          end
        elseif entry.upgrade then
          local S = ns.statdelta
          local text, r, g, b = S.ScoreText(entry.upgrade.new, entry.upgrade.old)
          GameTooltip:AddLine(text, r, g, b)
          if #entry.upgrade.links > 0 then
            GameTooltip:AddLine(L["Instead of %s"]:format(table.concat(entry.upgrade.links, " + ")), 0.8, 0.8, 0.8, true)
          end
          GameTooltip:AddDoubleLine(L["Lowest price"], ns.Money(entry.price), 0.8, 0.8, 0.8, 1, 1, 1)
          GameTooltip:AddDoubleLine(L["Price seen"], L["%s ago"]:format(ns.Age(entry.seen)), 0.8, 0.8, 0.8, 1, 1, 1)
        else
          GameTooltip:AddDoubleLine(L["Search"], entry.term.text, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if entry.term and entry.term.maxPrice then
          GameTooltip:AddDoubleLine(L["Your max price"], ns.Money(entry.term.maxPrice), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddLine(L["Click to open it in the auction house, Shift-click for its price history."], 0.6, 0.6,
          0.6, true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)
    end,
    UpdateRow = function(row, entry)
      row.icon:SetTexture(entry.icon or 134400)
      row.name:SetText(entry.name)
      row.name:SetTextColor(UI.Unpack(A.QualityColor(entry.quality)))
      -- (upgrade rows: the gain instead of how many are up)
      row.count:SetText(entry.gainText or (entry.count > 0 and ("x" .. entry.count) or ""))
      -- (below-vendor rows show what they make, the order of that list; shopping rows their price)
      row.price:SetText(entry.profit and ("+" .. ns.Money(entry.profit)) or ns.Money(entry.price))
      row.deal:SetShown(entry.deal)
    end,
  })
  PlaceResults(false)

  -- (vendor mode) one click buys the top item while it is under the vendor price (Buy.lua)
  panel.buy = UI.Button(panel, 100, 24, L["Buy"])
  panel.buy:SetPoint("BOTTOMLEFT", 12, 12)
  panel.buy:SetPoint("BOTTOMRIGHT", -108, 12)
  panel.buy:Hide()
  -- what Buy buys: every item, or only stackable goods (the auction house's commodities)
  panel.stacks = UI.Button(panel, 90, 24, L["All items"])
  panel.stacks:SetPoint("BOTTOMRIGHT", -12, 12)
  panel.stacks:Hide()
  panel.stacks:SetScript("OnClick", function()
    A.SetBuyStacksOnly(not A.BuyStacksOnly())
  end)
  panel.stacks:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["What Buy buys"])
    GameTooltip:AddLine(A.BuyStacksOnly()
      and L["Stacks only: only stackable goods (cloth, herbs, ore...). Click to buy every kind of item."]
      or L["All items: every item on the list except gear. Click to buy only stackable goods."],
      0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel.stacks:SetScript("OnLeave", GameTooltip_Hide)
  panel.buy:SetScript("OnClick", function()
    local ok, why = A.BuyNext()
    if not ok and why then
      ns.Say(why)
    end
  end)
  panel.buy:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Buy below the vendor price"])
    GameTooltip:AddLine(L["Each click buys the top item of the list (gear excepted): stackable goods every one still under the vendor price, other items the cheapest one. The price is checked again just before paying; if it is no longer under what a vendor pays, nothing is bought. The game needs a click for every purchase, so it never buys on its own."], 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel.buy:SetScript("OnLeave", GameTooltip_Hide)
  panel.buyText = UI.Text(panel, "body", 11, "muted")
  panel.buyText:SetPoint("BOTTOMLEFT", panel.buy, "TOPLEFT", 2, 6)
  panel.buyText:SetPoint("RIGHT", -12, 0)
  panel.buyText:SetWordWrap(false)
  panel.buyText:Hide()

  panel:SetScript("OnShow", RefreshPanel)
  ns.On("AUCTION_STATE", RefreshPanel)
  ns.On("PRICES_UPDATED", function()
    if panel.mode == "vendor" or panel.mode == "upgrades" then
      RefreshPanel() -- (saved prices feed the below-vendor list too)
    end
  end)
  return panel
end

-- Shows the panel when the auction house is open and the option is on (creates it the first time).
function A.ShowPanel()
  local db = A.DB()
  if not db.panel or not A.open then
    if panel then
      panel:Hide()
    end
    return
  end
  if not AuctionHouseFrame then
    -- the game's auction house addon may finish loading a moment after the event
    C_Timer.After(0, function()
      if AuctionHouseFrame and A.open then
        A.ShowPanel()
      end
    end)
    return
  end
  if not panel then
    CreatePanel()
  end
  panel:Show()
  RefreshPanel()
end

function A.Panel()
  return panel
end
