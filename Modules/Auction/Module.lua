local addonName, ns = ...
local L = ns.L

-- Auction house module: registration and start-up. Codex's own auction engine (no Auctionator, TSM or
-- Auctioneer needed): full scans, a price history per realm, prices in tooltips and shopping lists.

local A = ns.auction

-- One live line for Home and the page.
function A.StatusText()
  if not A.IsModern() then
    return L["The old auction house of this game version isn't supported yet; only tooltips with saved prices work."]
  end
  local count = A.ItemCount()
  local realm = A.Realm(false)
  if A.scan.state ~= "idle" then
    return A.ScanText()
  end
  if count == 0 then
    return L["No prices yet: open the auction house and run a full scan."]
  end
  if realm and realm.scanDone then
    return L["%d prices on this realm, last full scan %s ago."]:format(count, ns.Age(realm.scanDone))
  end
  return L["%d prices on this realm."]:format(count)
end

function A.Enable()
  A.DB()
  A.RepairPerItem()
  -- old history goes a little after login, not during it (it walks every saved item)
  C_Timer.After(10, A.TrimAll)
  A.InstallTooltip()
  if A.IsModern() then
    A.StartEvents()
  end
  A.running = true
end

ns.RegisterModule({
  id = "auction",
  name = L["Auction House"],
  -- its section in the Codex window (Areas.lua)
  area = "trade", sectionOrder = 10, sectionTitle = L["Auction house"], pageHeight = 400,
  icon = "Interface\\Icons\\INV_Misc_Coin_01",
  desc = L["Scan the auction house, keep a price history, see prices in tooltips and shop from your own lists."],
  order = 20,
  Enable = function()
    A.Enable()
  end,
  BuildPage = function(_, page)
    A.BuildPage(page)
  end,
  ShowPage = function()
    A.ShowPageRefresh()
  end,
  Status = function()
    return A.StatusText()
  end,
  -- /codex auction scan, /codex auction history <item>
  Slash = function(_, rest)
    if rest:lower() == "scan" then
      A.ScanCommand()
    elseif rest:lower():match("^history") then
      A.HistoryCommand(rest:sub(8))
    end
  end,
  commands = {
    -- /codex scan
    scan = function()
      A.ScanCommand()
    end,
    -- /codex history <item link, ID or name>: the price history window
    history = function(_, rest)
      A.HistoryCommand(rest)
    end,
  },
})
