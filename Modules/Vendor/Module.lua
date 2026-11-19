local addonName, ns = ...

-- Vendor: sells junk and repairs at merchants.
--
-- Sell junk: at MERCHANT_SHOW every grey item with a sell price (plus the player's "Also sell" items, minus the
-- "Never sell" ones) is sold with C_Container.UseContainerItem, 6 items every 0.2 s so the server doesn't refuse
-- ("That object is busy"). Each slot is read again just before it is used, so an item that moved (sorting) is
-- never sold by mistake. A moment after the last batch the slots are checked: items still there were refused
-- by the server and get one more pass. The run stops when the merchant window closes or a fight starts.
-- UseContainerItem sells from an event handler on Forever (no hardware event needed); the "Sell junk" button
-- in the strip under the merchant window runs the same code by hand.
--
-- Repair: RepairAllItems(), optionally guild funds first (RepairAllItems(true)); a moment later whatever the
-- guild didn't pay is paid from your own gold. Not enough gold: we wait for the junk sale, then say so.
--
-- Hold Shift while opening the merchant to skip both. When Leatrix Plus does the same job
-- (LeaPlusDB.AutoSellJunk / AutoRepairGear == "On"), Codex leaves that part to it.

local V = {}
ns.vendor = V

local DEFAULTS = { sellJunk = true, repair = true, guildFunds = false, alsoSell = {}, neverSell = {} }
local BATCH, STEP, CONFIRM = 6, 0.2, 0.8
local POOR = 0

V.merchantOpen = false
V.run = nil -- the sale in progress

function V.DB()
  if not V.db then
    ns.db.vendor = ns.Fill(ns.db.vendor or {}, DEFAULTS)
    V.db = ns.db.vendor
  end
  return V.db
end

local function Say(text)
  ns.Say(text)
end

-- Leatrix Plus doing the same job: "sell" or "repair".
local LEATRIX_KEYS = { sell = "AutoSellJunk", repair = "AutoRepairGear" }
function V.LeatrixDoes(what)
  if not ns.IsAddOnLoaded("Leatrix_Plus") then
    return false
  end
  local db = _G.LeaPlusDB
  return type(db) == "table" and db[LEATRIX_KEYS[what]] == "On" or false
end

function V.SellWanted()
  return V.DB().sellJunk and not V.LeatrixDoes("sell")
end

function V.RepairWanted()
  return V.DB().repair and not V.LeatrixDoes("repair")
end

-- Items ------------------------------------------------------------------------------------------------------

local function Shown(name)
  local frame = _G[name]
  return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

function V.MerchantOpen()
  if not V.merchantOpen then
    return false
  end
  local frame = _G.MerchantFrame
  if type(frame) == "table" and frame.IsShown and not frame:IsShown() then
    return false
  end
  -- with mail, bank or trade open UseContainerItem would move the item there instead
  return not (Shown("MailFrame") or Shown("BankFrame") or Shown("TradeFrame"))
end

local function LastBag()
  return (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

function V.SellPrice(itemID)
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not info then
    return nil
  end
  return (select(11, info(itemID)))
end

-- An item ID from a link, "item:123" or a plain number.
function V.ItemID(text)
  if type(text) == "number" then
    return text
  end
  if type(text) ~= "string" then
    return nil
  end
  local id = text:match("item:(%d+)") or text:match("^%s*(%d+)%s*$")
  return id and tonumber(id)
end

function V.ItemName(itemID, stored)
  local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))
  if not name then
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    name = info and info(itemID)
  end
  if not name and type(stored) == "string" then
    name = stored
  end
  return name or ("item " .. itemID)
end

local function Refundable(bag, slot)
  local get = C_Container.GetContainerItemPurchaseInfo
  if not get then
    return false
  end
  local ok, info = pcall(get, bag, slot, false)
  return ok and type(info) == "table" and (info.refundSeconds or 0) > 0 or false
end

local function QuestItem(bag, slot)
  local get = C_Container.GetContainerItemQuestInfo
  local quest = get and get(bag, slot)
  return type(quest) == "table" and (quest.isQuestItem or quest.questID) and true or false
end

-- The slot as a sale entry, or nil when it holds nothing we sell.
function V.Check(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if type(info) ~= "table" or not info.itemID or info.isLocked or info.hasNoValue then
    return nil
  end
  local db = V.DB()
  local id = info.itemID
  if db.neverSell[id] then
    return nil
  end
  if info.quality ~= POOR and not db.alsoSell[id] then
    return nil
  end
  local price = V.SellPrice(id)
  if not price or price <= 0 then
    if not price and C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(id) -- picked up by the second pass
    end
    return nil
  end
  if Refundable(bag, slot) or QuestItem(bag, slot) then
    return nil
  end
  local count = info.stackCount or 1
  return { bag = bag, slot = slot, itemID = id, count = count, value = price * count, link = info.hyperlink }
end

function V.Candidates()
  local list, value = {}, 0
  if not (C_Container and C_Container.GetContainerNumSlots) then
    return list, value
  end
  for bag = 0, LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local entry = V.Check(bag, slot)
      if entry then
        list[#list + 1] = entry
        value = value + entry.value
      end
    end
  end
  return list, value
end

-- The item is still in its slot (same item, not on its way to the merchant).
local function StillThere(entry, unlockedOnly)
  local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
  if type(info) ~= "table" or info.itemID ~= entry.itemID then
    return false
  end
  if unlockedOnly then
    return not info.isLocked
  end
  return true
end

-- Last visit -------------------------------------------------------------------------------------------------

local function Last()
  local db = V.DB()
  if not db.last or db.last.visit ~= V.visit then
    db.last = { visit = V.visit, time = time(), merchant = UnitName and UnitName("npc") or nil }
  end
  return db.last
end

local function Changed()
  if V.RefreshButtons then
    V.RefreshButtons()
  end
  if V.RefreshPage then
    V.RefreshPage()
  end
end

-- Selling ----------------------------------------------------------------------------------------------------

local Step, Confirm

local function Finish(reason)
  local run = V.run
  if not run then
    return
  end
  V.run = nil
  local last = Last()
  last.sold = (last.sold or 0) + run.sold
  last.soldValue = (last.soldValue or 0) + run.value
  last.left = run.left
  last.stopped = reason
  if run.sold > 0 then
    local text = ("sold %d junk item%s for %s"):format(run.sold, run.sold == 1 and "" or "s", ns.Money(run.value))
    if reason == "closed" and run.left > 0 then
      text = text .. (" (%d left: the vendor window closed)"):format(run.left)
    elseif reason == "combat" and run.left > 0 then
      text = text .. (" (%d left: stopped for combat)"):format(run.left)
    elseif run.left > 0 then
      text = text .. (" (%d the merchant didn't take)"):format(run.left)
    end
    Say(text)
  elseif run.manual then
    Say("the merchant didn't take any junk.")
  end
  if V.repairWaiting then
    V.repairWaiting = false
    if V.MerchantOpen() then
      V.Repair(false, true)
    end
  end
  Changed()
end

-- Counts which used items left the bags; refused ones are left in run.done for another pass.
local function Count(run)
  local left = {}
  for _, entry in ipairs(run.done) do
    if StillThere(entry, true) then
      left[#left + 1] = entry
    else
      run.sold = run.sold + 1
      run.value = run.value + entry.value
    end
  end
  run.done = {}
  return left
end

Step = function()
  local run = V.run
  if not run then
    return
  end
  if not V.MerchantOpen() then
    return Confirm("closed")
  end
  if InCombatLockdown() then
    return Confirm("combat")
  end
  local used = 0
  while run.pos <= #run.queue and used < BATCH do
    local entry = run.queue[run.pos]
    run.pos = run.pos + 1
    -- read again: the bags may have changed since the list was made
    if StillThere(entry, true) and V.Check(entry.bag, entry.slot) then
      C_Container.UseContainerItem(entry.bag, entry.slot)
      run.done[#run.done + 1] = entry
      used = used + 1
    end
  end
  if run.pos <= #run.queue then
    C_Timer.After(STEP, Step)
  else
    C_Timer.After(CONFIRM, function()
      if V.run == run then
        Confirm()
      end
    end)
  end
end

-- After the last batch (or when stopped): count, and give refused items one more pass.
Confirm = function(stopped)
  local run = V.run
  if not run then
    return
  end
  local left = Count(run)
  local notReached = math.max(0, #run.queue - run.pos + 1)
  if stopped then
    run.left = #left + notReached
    return Finish(stopped)
  end
  local tab = _G.MerchantFrame and _G.MerchantFrame.selectedTab
  if run.pass == 1 and V.MerchantOpen() and tab ~= 2 then
    -- a second pass: refused items and items whose price had not loaded yet (never on the Buyback tab,
    -- an item bought back just now would be sold again)
    local queue = V.Candidates()
    if #queue > 0 then
      run.pass, run.queue, run.pos = 2, queue, 1
      return Step()
    end
  end
  run.left = #left
  Finish()
end

-- Sells the junk now. manual = from the button (says why when there is nothing to do).
function V.SellJunk(manual)
  if V.run then
    return false
  end
  if not V.MerchantOpen() then
    if manual then
      Say("open a merchant first.")
    end
    return false
  end
  if InCombatLockdown() then
    if manual then
      Say("can't sell during a fight.")
    end
    return false
  end
  local queue = V.Candidates()
  if #queue == 0 then
    if manual then
      Say("no junk to sell.")
    end
    return false
  end
  V.run = { queue = queue, pos = 1, pass = 1, done = {}, sold = 0, value = 0, left = 0, manual = manual }
  Step()
  return true
end

-- Repairing --------------------------------------------------------------------------------------------------

local function RepairCost()
  if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost) then
    return nil
  end
  local cost, canRepair = GetRepairAllCost()
  if not cost or cost <= 0 or canRepair == false then
    return 0
  end
  return cost
end
V.RepairCost = RepairCost

local function GuildCanPay()
  if not (V.DB().guildFunds and IsInGuild and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()) then
    return false
  end
  local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
  return limit ~= 0 -- nil or -1: no limit we know of
end

local function Record(cost, guild)
  local last = Last()
  last.repair = (last.repair or 0) + cost
  last.guild = guild or last.guild
  last.noGold = nil
  Changed()
end

-- Pays the repair from your own gold. guildPaid: what the guild covered first (for the chat line).
local function OwnRepair(cost, guildPaid, afterSale)
  if GetMoney() < cost then
    if V.run and not afterSale then
      V.repairWaiting = true -- the junk gold may cover it
      return false
    end
    Say(("not enough gold to repair (%s)."):format(ns.Money(cost)))
    Last().noGold = cost
    Changed()
    return false
  end
  RepairAllItems()
  if guildPaid and guildPaid > 0 then
    Say(("repaired for %s (guild %s, you %s)"):format(ns.Money(guildPaid + cost), ns.Money(guildPaid), ns.Money(cost)))
    Record(guildPaid + cost, "part")
  else
    Say(("repaired for %s"):format(ns.Money(cost)))
    Record(cost)
  end
  return true
end

-- Repairs everything now. manual = from the button. afterSale = the retry once the junk is sold.
function V.Repair(manual, afterSale)
  local cost = RepairCost()
  if not cost then
    if manual then
      Say("this merchant can't repair.")
    end
    return false
  end
  if cost <= 0 then
    if manual then
      Say("nothing to repair.")
    end
    return false
  end
  if InCombatLockdown() then
    if manual then
      Say("can't repair during a fight.")
    end
    return false
  end
  if GuildCanPay() then
    RepairAllItems(true)
    -- the new cost arrives a moment later: whatever is left is ours to pay
    C_Timer.After(1, function()
      local left = RepairCost() or 0
      if left <= 0 then
        Say(("repaired for %s (guild)"):format(ns.Money(cost)))
        Record(cost, "all")
      elseif V.MerchantOpen() then
        OwnRepair(left, cost - left, afterSale)
      end
    end)
    return true
  end
  return OwnRepair(cost, nil, afterSale)
end

-- The merchant window's strip ---------------------------------------------------------------------------------
-- Board R2-Bags (vendor window): two equal columns, info text ("6 junk items  1s 12c" / "Repair all  1g 3s
-- 40c") over equal-width "Sell junk" and "Repair" buttons (32 high, 14px bold). Blizzard's own repair, junk and
-- money buttons fill the bottom of the window, so the strip hangs directly under the window, below the
-- Merchant / Buyback tabs, and covers nothing of Blizzard's.

local buttons
local STRIP_HEIGHT, PAD, GAP = 74, 12, 12

local function ButtonTip(button, title, line)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(line(), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

function V.RefreshButtons()
  if not buttons or not V.merchantOpen then
    return
  end
  local junk, value = V.Candidates()
  buttons.sell:SetEnabled(#junk > 0 and not V.run)
  if #junk > 0 then
    buttons.junkText:SetText(("%d junk item%s"):format(#junk, #junk == 1 and "" or "s"))
    buttons.junkMoney:SetText(ns.Money(value))
  else
    buttons.junkText:SetText("No junk")
    buttons.junkMoney:SetText("")
  end
  local cost = RepairCost()
  buttons.repair:SetEnabled((cost or 0) > 0)
  if cost == nil then
    buttons.repairText:SetText("Can't repair here")
    buttons.repairMoney:SetText("")
  elseif cost > 0 then
    buttons.repairText:SetText("Repair all")
    buttons.repairMoney:SetText(ns.Money(cost))
  else
    buttons.repairText:SetText("Nothing to repair")
    buttons.repairMoney:SetText("")
  end
end

-- One column: info line (label left, money right) over a full-width button.
local function Column(strip, text, left)
  local UI = ns.UI
  local button = UI.Button(strip, 100, 32, text)
  UI.Font(button.label, "body", 14) -- board: 700 14px (button colour stays with the button's own state)
  if left then
    button:SetPoint("BOTTOMLEFT", PAD, 10)
    button:SetPoint("RIGHT", strip, "CENTER", -GAP / 2, 0)
  else
    button:SetPoint("BOTTOMRIGHT", -PAD, 10)
    button:SetPoint("LEFT", strip, "CENTER", GAP / 2, 0)
  end
  local label = UI.Text(strip, "body", 13, "muted")
  label:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 6)
  local money = UI.Text(strip, "body", 13, "muted")
  money:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 6)
  money:SetJustifyH("RIGHT")
  return button, label, money
end

local function MakeButtons()
  local frame = _G.MerchantFrame
  if type(frame) ~= "table" or buttons then
    return
  end
  local UI = ns.UI
  buttons = {}
  -- on the game's merchant window (an ink surface in Dawn, restyled or not): ink too
  local strip = UI.Ink(CreateFrame("Frame", "CodexVendorStrip", frame))
  strip:SetHeight(STRIP_HEIGHT)
  -- under the tabs (MerchantFrameTab1/2 hang about 32 px below the window)
  local below = _G.MerchantFrameTab1 and -34 or -2
  strip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, below)
  strip:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, below)
  UI.Panel(strip, { cornerSize = 12 })
  strip:EnableMouse(true)
  buttons.strip = strip

  buttons.sell, buttons.junkText, buttons.junkMoney = Column(strip, "Sell junk", true)
  buttons.sell:SetScript("OnClick", function()
    V.SellJunk(true)
    V.RefreshButtons()
  end)
  ButtonTip(buttons.sell, "Sell junk (Codex)", function()
    local junk, value = V.Candidates()
    if #junk == 0 then
      return "No junk in your bags."
    end
    return ("Sells %d item%s for %s: grey items and your Also sell list, never your Never sell list.")
      :format(#junk, #junk == 1 and "" or "s", ns.Money(value))
  end)
  buttons.repair, buttons.repairText, buttons.repairMoney = Column(strip, "Repair", false)
  buttons.repair:SetScript("OnClick", function()
    V.Repair(true)
  end)
  ButtonTip(buttons.repair, "Repair all (Codex)", function()
    local cost = RepairCost()
    if cost == nil then
      return "This merchant can't repair."
    elseif cost <= 0 then
      return "Nothing to repair."
    end
    return "Costs " .. ns.Money(cost) .. (V.DB().guildFunds and " (guild funds first)." or ".")
  end)
  V.buttons = buttons
end

-- Events -----------------------------------------------------------------------------------------------------

local visits = 0

local function OnShow()
  V.merchantOpen = true
  visits = visits + 1
  V.visit = time() .. ":" .. visits -- one "last visit" record per merchant window
  V.repairWaiting = false
  MakeButtons()
  -- Shift is read now (held while opening); the work waits a moment: at MERCHANT_SHOW the game hasn't shown
  -- MerchantFrame yet, so V.MerchantOpen() said no and nothing was sold (in game, 2026-11-17)
  local skip = (IsShiftKeyDown and IsShiftKeyDown()) and true or false
  local visit = V.visit
  local tries = 0
  local function Run()
    if V.visit ~= visit or not V.merchantOpen then
      return
    end
    if not V.MerchantOpen() then
      tries = tries + 1
      if tries < 10 then
        C_Timer.After(0.1, Run) -- the window is still opening
      end
      return
    end
    if not skip and not InCombatLockdown() then
      if V.SellWanted() then
        V.SellJunk(false)
      end
      if V.RepairWanted() then
        V.Repair(false)
      end
    end
    V.RefreshButtons()
  end
  C_Timer.After(0.1, Run)
  V.RefreshButtons()
end

local refreshQueued = false
local function RefreshSoon()
  if refreshQueued or not V.merchantOpen then
    return
  end
  refreshQueued = true
  C_Timer.After(0.2, function()
    refreshQueued = false
    V.RefreshButtons()
  end)
end

function V.Enable()
  V.DB()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
      OnShow()
    elseif event == "MERCHANT_CLOSED" then
      V.merchantOpen = false
      if V.run then
        Confirm("closed")
      end
      V.repairWaiting = false
    elseif event == "PLAYER_REGEN_DISABLED" then
      if V.run then
        Confirm("combat")
      end
    else
      RefreshSoon()
    end
  end)
  for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_DELAYED",
    "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY" }) do
    events:RegisterEvent(event)
  end
  V.running = true
end

-- Lists ------------------------------------------------------------------------------------------------------

-- Adds an item to "alsoSell" or "neverSell" (and takes it off the other list).
function V.AddToList(which, text)
  local id = V.ItemID(text)
  if not id then
    return nil
  end
  local db = V.DB()
  local other = which == "alsoSell" and "neverSell" or "alsoSell"
  db[other][id] = nil
  db[which][id] = (type(text) == "string" and text:match("|h%[(.-)%]|h")) or true
  Changed()
  return id
end

function V.RemoveFromList(which, id)
  V.DB()[which][id] = nil
  Changed()
end

function V.ListItems(which)
  local items = {}
  for id, stored in pairs(V.DB()[which]) do
    items[#items + 1] = { id = id, name = V.ItemName(id, stored) }
  end
  table.sort(items, function(a, b)
    return a.name < b.name
  end)
  return items
end

function V.StatusText()
  if not V.running then
    return "Off."
  end
  local parts = {}
  local db = V.DB()
  if V.LeatrixDoes("sell") then
    parts[#parts + 1] = "Leatrix Plus sells junk"
  elseif db.sellJunk then
    parts[#parts + 1] = "Sells junk"
  end
  if V.LeatrixDoes("repair") then
    parts[#parts + 1] = "Leatrix Plus repairs"
  elseif db.repair then
    parts[#parts + 1] = db.guildFunds and "repairs (guild funds first)" or "repairs"
  end
  if #parts == 0 then
    return "Buttons on the merchant window only."
  end
  local text = table.concat(parts, ", ") .. " at merchants."
  return text:sub(1, 1):upper() .. text:sub(2)
end

ns.RegisterModule({
  id = "vendor",
  name = "Vendor",
  -- its section in the Codex window (Areas.lua)
  area = "trade", sectionOrder = 30, folded = true, pageHeight = 450,
  icon = "Interface\\Icons\\INV_Misc_Bag_10",
  desc = "Sells junk and repairs your gear when you talk to a merchant.",
  order = 96,
  Enable = function()
    V.Enable()
  end,
  BuildPage = function(_, page)
    V.BuildPage(page)
  end,
  ShowPage = function()
    if V.RefreshPage then
      V.RefreshPage()
    end
  end,
  Status = function()
    return V.StatusText()
  end,
})
