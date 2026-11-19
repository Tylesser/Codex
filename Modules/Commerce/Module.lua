local addonName, ns = ...

-- Commerce module, part 12: events, commands, start-up and registration. Tylesser - Commerce Authority ported
-- into Codex: while the standalone addon is loaded Codex leaves this to it (unless the player forces Codex's
-- copy). /codex commerce [npcs | buy | options | debug]; /aca and /commerce too while the standalone addon isn't
-- loaded (it owns them otherwise).

local C = ns.commerce

-- Registered at Enable; pcall because not every client has every event.
local EVENTS = {
  "PLAYER_ENTERING_WORLD", "QUEST_COMPLETE", "QUEST_TURNED_IN", "CURRENCY_DISPLAY_UPDATE",
  "CHAT_MSG_COMBAT_FACTION_CHANGE", "BAG_UPDATE_DELAYED", "UPDATE_FACTION", "QUEST_LOG_UPDATE",
  "SKILL_LINES_CHANGED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED",
}

local function OnEvent(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" then
    -- the currency can still read 0 right at login: take the starting balance a little later
    C_Timer.After(5, C.StartFavorTracking)
  elseif event == "QUEST_COMPLETE" then
    C.OnQuestComplete()
  elseif event == "QUEST_TURNED_IN" then
    C.OnQuestTurnedIn((...))
  elseif event == "CURRENCY_DISPLAY_UPDATE" then
    local currencyID = ...
    if currencyID == nil or currencyID == C.FAVOR_CURRENCY then
      C.OnFavorChanged()
    end
  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local message = ...
    if C.Readable(message) then
      C.OnRepMessage(message)
    end
  else
    if event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
      C.InvalidateCheapest() -- professions, or a legacy talent (Diplomat) changed
      C.RefreshPage()
    end
    C.RequestRefresh()
  end
end

function C.Debug()
  local favor, favorName = C.Favor()
  ns.Say("Commerce debug")
  print(("  Merchant's Favor: %s"):format(favor and (C.Number(favor) .. " (" .. favorName .. ")") or "not found"))
  local faction = C.Faction()
  if faction then
    print(("  Faction: %s (ID %s), %s, %s / %s"):format(faction.name, tostring(faction.id),
      C.StandingName(faction.standingID), C.Number((faction.value or 0) - (faction.min or 0)),
      C.Number((faction.max or 0) - (faction.min or 0))))
  else
    print("  Faction: not in your reputation list yet")
  end
  local names = C.PriceSourceNames()
  print("  Prices: " .. (#names > 0 and table.concat(names, ", ") or "none (Auction House module off)"))
  local professions = {}
  for name, skill in pairs(C.PlayerProfessions()) do
    professions[#professions + 1] = name .. " " .. skill
  end
  table.sort(professions)
  print("  Professions: " .. (#professions > 0 and table.concat(professions, ", ") or "none found"))
  print(("  Writ quests: %d"):format(#C.ActiveWrits()))
  local builtIn, learned = 0, 0
  for writID = C.FOREVER_WRIT_FIRST, C.FOREVER_WRIT_LAST do
    local customer = C.WritCustomer(writID)
    if customer and customer.learned then
      learned = learned + 1
    elseif customer then
      builtIn = builtIn + 1
    end
  end
  print(("  Writ customers known: %d built in, %d seen at your turn-ins"):format(builtIn, learned))
  local summary = C.BagSummary()
  print(("  Bags: %d writs (%d rep), %d sealed writs, %d filled crates (%d Favor), %d crates to fill"):format(
    summary.writs, summary.writRep, summary.sealedWrits, summary.crates, summary.crateFavor, summary.toFill))
  local db = C.DB()
  local crates, writs = 0, 0
  for _ in pairs(db.learned.crates) do
    crates = crates + 1
  end
  for _ in pairs(db.learned.writs) do
    writs = writs + 1
  end
  print(("  Legacy talents: Performance Bonus %s, Diplomat %s"):format(
    C.HasPerformanceBonus() and "yes" or "no", C.HasDiplomat() and "yes" or "no"))
  print(("  Learned: %d crate kinds, %d writs, %d Performance Bonuses seen"):format(crates, writs,
    db.learned.bonuses or 0))
end

-- /codex commerce <rest>, /aca <rest>
function C.Slash(rest)
  local command = (rest or ""):lower():match("^%s*(%S*)")
  if command == "" or command == "show" then
    C.ToggleWindow()
  elseif command == "npcs" or command == "npc" then
    C.ToggleNPCWindow()
  elseif command == "buy" then
    C.CreateBuyList()
  elseif command == "options" or command == "config" then
    ns.ShowPage("commerce")
  elseif command == "debug" then
    C.Debug()
  elseif command == "feedback" then
    ns.T.ShowFeedback()
  else
    ns.Say("Commerce commands:")
    print("  /codex commerce: show or hide the window")
    print("  /codex commerce npcs: every NPC who takes writs, with all its writs and which you have")
    print("  /codex commerce buy: Codex shopping list of the cheapest writs to your next standing")
    print("  /codex commerce options: this module's page in the Codex window")
    print("  /codex commerce debug: what Codex sees (faction, Favor, prices, bags)")
  end
end

-- The standalone addon's /aca and /commerce, while it isn't loaded.
local function SlashAliases()
  if SlashCmdList.COMMERCEAUTHORITY or ns.IsAddOnLoaded("CommerceAuthority") then
    return
  end
  SLASH_CODEXCOMMERCE1 = "/aca"
  SLASH_CODEXCOMMERCE2 = "/commerce"
  SlashCmdList.CODEXCOMMERCE = C.Slash
end

function C.Enable()
  C.DB()
  C.HookItemTooltips()
  C.HookVendor()
  local events = CreateFrame("Frame")
  for _, event in ipairs(EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript("OnEvent", OnEvent)
  C.eventFrame = events
  ns.On("PRICES_UPDATED", function()
    C.InvalidateCheapest()
    C.RequestRefresh()
  end)
  SlashAliases()
  C.running = true
  -- the starting balance, in case Codex was switched on after PLAYER_ENTERING_WORLD
  C_Timer.After(5, C.StartFavorTracking)
end

ns.RegisterModule({
  id = "commerce",
  name = "Commerce Authority",
  -- its section in the Codex window (Areas.lua)
  area = "trade", sectionOrder = 25, folded = true, pageEstimate = 470,
  icon = "Interface\\Icons\\INV_Misc_Note_02",
  desc = "Craftsman's Writs and Waylaid Crates: auction prices, reputation, Merchant's Favor, who takes each writ "
    .. "and the cheapest writs to buy.",
  standalone = "CommerceAuthority",
  standaloneName = "Commerce Authority",
  order = 36,
  Enable = function()
    C.Enable()
  end,
  BuildPage = function(_, page)
    C.BuildPage(page)
  end,
  ShowPage = function()
    C.RefreshPage()
  end,
  Status = function()
    return C.StatusText()
  end,
  Slash = function(_, rest)
    C.Slash(rest)
  end,
  commands = {
    -- /codex writs: the window
    writs = function()
      C.ToggleWindow()
    end,
  },
})
