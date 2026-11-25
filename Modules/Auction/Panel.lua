local addonName, ns = ...

-- Auction house module, part 5: a themed Codex panel docked to the right of the game's auction house
-- window. It lists the shopping lists (click one to search all its terms), shows the results (click one to
-- open it in the game's own buy view) and has the full scan button. It never buys, bids or posts.

local A = ns.auction
local UI = ns.UI

local WIDTH = 270
local panel

local function RefreshPanel()
  if not panel or not panel:IsShown() then
    return
  end
  panel.scanText:SetText(A.ScanText())
  panel.scan:SetEnabled(A.scan.state == "idle" and A.NextScanIn() == 0)
  panel.lists:SetItems(A.Lists())
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
  local open = UI.Button(panel, 70, 20, "Prices")
  open:SetPoint("TOPRIGHT", -12, -10)
  open:SetScript("OnClick", function()
    ns.ShowPage("auction-prices")
  end)

  panel.scan = UI.Button(panel, 100, 24, "Full scan")
  panel.scan:SetPoint("TOPLEFT", 12, -40)
  panel.scan:SetScript("OnClick", function()
    A.ScanCommand()
  end)
  panel.scanText = UI.Text(panel, "body", 11, "muted")
  panel.scanText:SetPoint("TOPLEFT", panel.scan, "BOTTOMLEFT", 0, -4)
  panel.scanText:SetPoint("RIGHT", -12, 0)

  local listsLabel = UI.Text(panel, "head", 11, "muted")
  listsLabel:SetPoint("TOPLEFT", panel.scan, "BOTTOMLEFT", 0, -26)
  listsLabel:SetText("SHOPPING LISTS")
  panel.lists = UI.List(panel, {
    rowHeight = 20,
    CreateRow = function(row)
      row.text = UI.Text(row, "body", 12, "text")
      row.text:SetPoint("LEFT", 6, 0)
      row.text:SetPoint("RIGHT", -6, 0)
      row.text:SetWordWrap(false)
      row:SetScript("OnClick", function(self)
        local ok, why = A.SearchList(self.item)
        if not ok then
          ns.Say(why)
        end
      end)
    end,
    UpdateRow = function(row, list)
      row.text:SetText(("%s |cff999999(%d)|r"):format(list.name, #list.terms))
      row.selected:SetShown(list == A.shop.list and A.shop.state ~= "idle")
    end,
  })
  panel.lists:SetPoint("TOPLEFT", listsLabel, "BOTTOMLEFT", 0, -4)
  panel.lists:SetPoint("RIGHT", -12, 0)
  panel.lists:SetHeight(124)
  local edit = UI.Button(panel, 90, 20, "Edit lists")
  edit:SetPoint("TOPLEFT", panel.lists, "BOTTOMLEFT", 0, -4)
  edit:SetScript("OnClick", function()
    ns.ShowPage("auction-lists")
  end)

  panel.searchText = UI.Text(panel, "body", 11, "accent")
  panel.searchText:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -12)
  panel.searchText:SetPoint("RIGHT", -64, 0)
  panel.searchText:SetWordWrap(false)
  panel.stop = UI.Button(panel, 48, 20, "Stop")
  panel.stop:SetPoint("TOPRIGHT", panel.lists, "BOTTOMRIGHT", 0, -28)
  panel.stop:SetScript("OnClick", function()
    A.StopSearch()
  end)

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
          local key = A.KeyOf(self.item.result.itemKey)
          if key then
            A.ShowHistory(key)
          end
          return
        end
        if self.item and not A.OpenResult(self.item) then
          ns.Say("The auction house window couldn't open this item; search for it by name.")
        end
      end)
      row:SetScript("OnEnter", function(self)
        local entry = self.item
        if not entry then
          return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local key = A.KeyOf(entry.result.itemKey)
        local link = key and A.Hyperlink(key)
        if link then
          GameTooltip:SetHyperlink(link)
        else
          GameTooltip:AddLine(entry.name)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Search", entry.term.text, 0.8, 0.8, 0.8, 1, 1, 1)
        if entry.term.maxPrice then
          GameTooltip:AddDoubleLine("Your max price", ns.Money(entry.term.maxPrice), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddLine("Click to open it in the auction house, Shift-click for its price history.", 0.6, 0.6,
          0.6, true)
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", GameTooltip_Hide)
    end,
    UpdateRow = function(row, entry)
      row.icon:SetTexture(entry.icon or 134400)
      row.name:SetText(entry.name)
      row.name:SetTextColor(UI.Unpack(A.QualityColor(entry.quality)))
      row.count:SetText(entry.count > 0 and ("x" .. entry.count) or "")
      row.price:SetText(ns.Money(entry.price))
      row.deal:SetShown(entry.deal)
    end,
  })
  panel.results:SetPoint("TOPLEFT", panel.searchText, "BOTTOMLEFT", 0, -8)
  panel.results:SetPoint("BOTTOMRIGHT", -12, 12)

  panel:SetScript("OnShow", RefreshPanel)
  ns.On("AUCTION_STATE", RefreshPanel)
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
