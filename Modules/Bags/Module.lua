local addonName, ns = ...
local L = ns.L

-- Bags module, part 6: events, start-up and registration. Codex's own bag window with categories, every
-- character's bags, bank and money, and item counts in tooltips. Baganator is the standalone: while it is
-- loaded Codex leaves the bags to it (unless the player forces Codex's copy).

local B = ns.bags

local SCAN_DELAY = 1

-- Saving a character's bags waits a moment after the last change, and never runs during a fight (the
-- window itself still updates in combat); a pending scan runs when the fight ends.
B.queued = {}
local scanTimer = false

local function RunScans()
  scanTimer = false
  if InCombatLockdown() then
    return -- PLAYER_REGEN_ENABLED runs them
  end
  local queued = B.queued
  B.queued = {}
  if queued.bags then
    B.ScanBags()
  end
  if queued.bank and B.bankOpen then
    B.ScanBank()
  end
  if queued.equipped then
    B.ScanEquipped()
  end
end
B.RunScans = RunScans

local function QueueScan(what)
  B.queued[what] = true
  if scanTimer or InCombatLockdown() then
    return
  end
  scanTimer = true
  C_Timer.After(SCAN_DELAY, RunScans)
end
B.QueueScan = QueueScan

-- Windows where single stacks matter: while one is open, identical items are shown one by one.
local INTERACTIONS = {
  BANKFRAME_OPENED = { "bank", true }, BANKFRAME_CLOSED = { "bank", false },
  TRADE_SHOW = { "trade", true }, TRADE_CLOSED = { "trade", false },
  MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
  MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
  AUCTION_HOUSE_SHOW = { "auction", true }, AUCTION_HOUSE_CLOSED = { "auction", false },
  GUILDBANKFRAME_OPENED = { "guildbank", true }, GUILDBANKFRAME_CLOSED = { "guildbank", false },
}
B.INTERACTIONS = INTERACTIONS

local GUILD_EVENTS = {}
for _, event in ipairs(B.guild.EVENTS) do
  GUILD_EVENTS[event] = true
end

local function OnEvent(_, event, arg)
  local interaction = INTERACTIONS[event]
  if interaction then
    B.SetInteracting(interaction[1], interaction[2])
  end
  if GUILD_EVENTS[event] then
    B.guild.OnEvent(event)
  end
  if event == "BAG_UPDATE_DELAYED" then
    QueueScan("bags")
    if B.bankOpen then
      QueueScan("bank")
      B.RequestBankRefresh()
    end
    B.EnsureButtons()
    B.RequestRefresh()
  elseif event == "PLAYER_MONEY" then
    B.ScanMoney()
    B.RequestRefresh()
  elseif event == "ITEM_LOCK_CHANGED" or event == "BAG_UPDATE_COOLDOWN" then
    B.RefillShown()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    QueueScan("equipped")
  elseif event == "BANKFRAME_OPENED" then
    B.bankOpen = true
    QueueScan("bank")
    B.OpenBank()
  elseif event == "BANKFRAME_CLOSED" then
    if B.queued.bank and B.bankOpen and not InCombatLockdown() then
      B.queued.bank = nil
      B.ScanBank() -- the last change before closing
    end
    B.CloseBank()
    B.bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
    if B.bankOpen then
      QueueScan("bank")
      B.RequestBankRefresh()
    end
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    if arg and B.pending[arg] then
      B.pending[arg] = nil
      B.RequestRefresh()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    B.deposit.Stop("combat")
    -- the last moment buttons can still be placed: catch up on a waiting layout, also while the window is closed
    B.PrepareForCombat()
    if B.bank.pending and B.BankWindow() and B.BankWindow():IsShown() then
      B.RefreshBank()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if not B.Window() then
      B.CreateWindow()
      B.SyncWithGame()
    end
    B.EnsureButtons()
    if next(B.queued) then
      RunScans()
    end
    if B.layoutPending then
      B.RequestRefresh()
    end
    if B.bank.pending then
      B.RequestBankRefresh()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    B.ScanMoney()
    QueueScan("bags")
    QueueScan("equipped")
  end
end

function B.Enable()
  B.DB()
  B.Me()
  B.InstallTooltip()
  B.CreateWindow() -- nil during a fight (a reload in combat): made at PLAYER_REGEN_ENABLED
  B.InstallGameHooks()
  B.InstallPanelHooks()
  B.InstallBankHooks()
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
  end
  pcall(events.RegisterEvent, events, "PLAYERBANKBAGSLOTS_CHANGED") -- not on every client
  pcall(events.RegisterEvent, events, "BANK_TABS_CHANGED")
  for _, event in ipairs(B.guild.EVENTS) do
    if not events:IsEventRegistered(event) then
      pcall(events.RegisterEvent, events, event) -- the guild bank may not exist on Forever
    end
  end
  for event in pairs(INTERACTIONS) do
    if not events:IsEventRegistered(event) then
      pcall(events.RegisterEvent, events, event) -- the guild bank may not exist on Forever
    end
  end
  events:SetScript("OnEvent", OnEvent)
  B.eventFrame = events
  B.running = true
end

ns.RegisterModule({
  id = "bags",
  name = L["Bags"],
  -- its section in the Codex window (Areas.lua)
  area = "items", sectionOrder = 10, pageHeight = 450,
  icon = "Interface\\Icons\\INV_Misc_Bag_08",
  desc = L["One bag window with categories and search, a bank and guild bank window in the same look, every character's bags, bank and money, and item counts in tooltips."],
  standalone = "Baganator",
  standaloneName = "Baganator",
  order = 40,
  Enable = function()
    B.Enable()
  end,
  BuildPage = function(_, page)
    B.BuildPage(page)
  end,
  ShowPage = function()
    B.RefreshPage()
  end,
  Status = function()
    return B.StatusText()
  end,
  -- /codex bags open
  Slash = function(_, rest)
    rest = rest:lower()
    if rest == "open" or rest == "show" then
      B.Toggle()
    else
      ns.ShowPage("bags")
    end
  end,
})
