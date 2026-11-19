local addonName, ns = ...

-- Professions module, part 6: events, start-up and registration. Profit Sort ported into Codex, with Codex's
-- own auction prices instead of Auctionator's. While the standalone Profit Sort addon is loaded Codex leaves
-- this to it (unless the player forces Codex's copy).

local P = ns.professions

local REFRESH_EVENTS = {
  TRADE_SKILL_LIST_UPDATE = true, TRADE_SKILL_UPDATE = true, TRADE_SKILL_FILTER_UPDATE = true,
  TRADE_SKILL_DATA_SOURCE_CHANGED = true, CRAFT_UPDATE = true, BAG_UPDATE_DELAYED = true,
  GET_ITEM_INFO_RECEIVED = true,
}

local function OnEvent(_, event)
  if REFRESH_EVENTS[event] then
    P.RequestRefresh()
  elseif event == "TRADE_SKILL_SHOW" then
    C_Timer.After(0, function()
      P.ActivateTradeSkill(3)
    end)
  elseif event == "TRADE_SKILL_CLOSE" then
    P.Deactivate(P.Providers.TradeSkill)
    P.Deactivate(P.Providers.Professions)
  elseif event == "CRAFT_SHOW" then
    C_Timer.After(0, function()
      P.ActivateCraft(3)
    end)
  elseif event == "CRAFT_CLOSE" then
    P.Deactivate(P.Providers.Craft)
  elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
    -- after the Auction House module has noted the open state
    C_Timer.After(0, P.UpdateBlock)
  elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
    if P.RecordMerchant() > 0 then
      P.RequestRefresh()
    end
  end
end

function P.Enable()
  P.DB()
  P.Me()
  P.InstallTooltip()
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "CRAFT_SHOW", "CRAFT_CLOSE", "MERCHANT_SHOW",
    "MERCHANT_UPDATE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE", "TRADE_SKILL_FILTER_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "CRAFT_UPDATE", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(events.RegisterEvent, events, event) -- some events don't exist on every client
  end
  events:SetScript("OnEvent", OnEvent)
  P.eventFrame = events
  ns.On("PRICES_UPDATED", P.RequestRefresh)
  P.running = true
end

ns.RegisterModule({
  id = "professions",
  name = "Professions",
  -- its section in the Codex window (Areas.lua)
  area = "trade", sectionOrder = 20, folded = true, pageEstimate = 330,
  icon = "Interface\\Icons\\Trade_BlackSmithing",
  desc = "Reagent cost, auction value and profit in the profession window, a profit list, and craft cost in item tooltips.",
  standalone = "ProfitSort",
  standaloneName = "Profit Sort",
  order = 35,
  Enable = function()
    P.Enable()
  end,
  BuildPage = function(_, page)
    P.BuildPage(page)
  end,
  ShowPage = function()
    P.RefreshPage()
  end,
  Status = function()
    return P.StatusText()
  end,
})
