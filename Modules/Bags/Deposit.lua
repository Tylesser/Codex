local addonName, ns = ...
local L = ns.L

-- Bags module, part 8: "Deposit reagents" on the bank window. When the game offers it for the character bank
-- (C_Bank.DoesBankTypeSupportAutoDeposit(Enum.BankType.Character); the game's own button there is "Deposit
-- All Reagents"), the game's C_Bank.AutoDepositItemsIntoBank does the work. Otherwise Codex moves them itself
-- like the Vendor module sells: C_Container.UseContainerItem(bag, slot, nil, bankType) while the bank is
-- open, 6 every 0.2 s, each slot read again just before it is used, stopping when the bank closes or a fight
-- starts. A reagent: the item says it is a crafting reagent, or it is a trade good (class 7), or it sits in
-- the reagent bag. Never: quest items, weapons and armour, ammo, keys (the keyring), locked items.
-- The result goes to chat and the bank window's footer ("Deposited 23 reagents").

local B = ns.bags
local D = {}
B.deposit = D

local BATCH, STEP, CONFIRM = 6, 0.2, 0.8
local WEAPON, ARMOR, PROJECTILE, TRADEGOODS, QUEST, KEY = 2, 4, 6, 7, 12, 13

D.run = nil

function D.BankOpen()
  if not B.bankOpen then
    return false
  end
  local game = B.GameBank()
  return not game or game:IsShown() and true or false
end

local function QuestItem(bag, slot)
  local get = C_Container.GetContainerItemQuestInfo
  local quest = get and get(bag, slot)
  return type(quest) == "table" and (quest.isQuestItem or quest.questID) and true or false
end

-- classID and isCraftingReagent of an item (nil when the game hasn't loaded it yet).
local function ItemFacts(itemID)
  local classID, crafting
  local get = C_Item and C_Item.GetItemInfo
  if get then
    local info = { get(itemID) }
    classID, crafting = info[12], info[17]
  end
  if classID == nil and C_Item and C_Item.GetItemInfoInstant then
    classID = select(6, C_Item.GetItemInfoInstant(itemID))
  end
  return classID, crafting
end

-- A bag slot as a deposit entry, or nil when it holds nothing to deposit.
function D.Check(bag, slot)
  if bag == B.KeyringID() then
    return nil
  end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if type(info) ~= "table" or not info.itemID or info.isLocked then
    return nil
  end
  if QuestItem(bag, slot) then
    return nil
  end
  local classID, crafting = ItemFacts(info.itemID)
  if classID == WEAPON or classID == ARMOR or classID == PROJECTILE or classID == QUEST or classID == KEY then
    return nil
  end
  if not (crafting == true or classID == TRADEGOODS or bag == B.ReagentID()) then
    return nil
  end
  return { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1 }
end

-- Every reagent in the carried bags, and how many items that is.
function D.Candidates()
  local list, items = {}, 0
  for _, bag in ipairs(B.CarriedBags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local entry = D.Check(bag, slot)
      if entry then
        list[#list + 1] = entry
        items = items + entry.count
      end
    end
  end
  return list, items
end

-- Items in the carried bags (the keyring left out), to count what the game's own deposit moved.
local function BagItems()
  local items = 0
  for _, bag in ipairs(B.CarriedBags()) do
    if bag ~= B.KeyringID() then
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" and info.itemID then
          items = items + (info.stackCount or 1)
        end
      end
    end
  end
  return items
end

local function Report(moved, left, reason)
  local text
  if moved > 0 then
    text = moved == 1 and L["Deposited 1 reagent"] or L["Deposited %d reagents"]:format(moved)
    if reason == "closed" and left > 0 then
      text = text .. L[" (%d left: the bank closed)"]:format(left)
    elseif reason == "combat" and left > 0 then
      text = text .. L[" (%d left: stopped for combat)"]:format(left)
    elseif left > 0 then
      text = text .. L[" (%d didn't fit)"]:format(left)
    end
  elseif left > 0 then
    text = L["No room in the bank for your reagents"]
  else
    text = L["No reagents in your bags"]
  end
  D.last = text
  ns.Say(text:sub(1, 1):lower() .. text:sub(2) .. ".")
  if B.BankNote then
    B.BankNote(text)
  end
end

-- The game's own deposit, when it offers one for the character bank.
local function GameDeposit()
  local bankType = B.BankType()
  if bankType == nil or not (C_Bank and C_Bank.AutoDepositItemsIntoBank and C_Bank.DoesBankTypeSupportAutoDeposit) then
    return false
  end
  local ok, supported = pcall(C_Bank.DoesBankTypeSupportAutoDeposit, bankType)
  if not ok or not supported then
    return false
  end
  local before = BagItems()
  C_Bank.AutoDepositItemsIntoBank(bankType)
  D.game = true
  C_Timer.After(CONFIRM, function()
    D.game = nil
    Report(math.max(0, before - BagItems()), 0)
  end)
  return true
end

-- Our own deposit -------------------------------------------------------------------------------------------

local Step, Confirm

-- The item is still in its slot (same item, not on its way to the bank).
local function StillThere(entry)
  local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
  return type(info) == "table" and info.itemID == entry.itemID and not info.isLocked
end

local function Finish(reason)
  local run = D.run
  if not run then
    return
  end
  D.run = nil
  Report(run.moved, run.left, reason)
end

Step = function()
  local run = D.run
  if not run then
    return
  end
  if not D.BankOpen() then
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
    local now = StillThere(entry) and D.Check(entry.bag, entry.slot)
    if now then
      entry.count = now.count
      C_Container.UseContainerItem(entry.bag, entry.slot, nil, B.BankType())
      run.done[#run.done + 1] = entry
      used = used + 1
    end
  end
  if run.pos <= #run.queue then
    C_Timer.After(STEP, Step)
  else
    C_Timer.After(CONFIRM, function()
      if D.run == run then
        Confirm()
      end
    end)
  end
end

-- After the last batch (or when stopped): count what left the bags.
Confirm = function(stopped)
  local run = D.run
  if not run then
    return
  end
  local left = 0
  for _, entry in ipairs(run.done) do
    if StillThere(entry) then
      left = left + entry.count
    else
      run.moved = run.moved + entry.count
    end
  end
  for index = run.pos, #run.queue do
    left = left + run.queue[index].count
  end
  run.done = {}
  run.left = left
  Finish(stopped)
end

-- Stops a deposit in progress ("closed" / "combat").
function D.Stop(reason)
  if D.run then
    Confirm(reason)
  end
end

-- Deposits the reagents now. manual = from the button (says why when there is nothing to do).
function D.Run(manual)
  if D.run or D.game then
    return false
  end
  if not D.BankOpen() then
    if manual then
      ns.Say(L["open the bank first."])
    end
    return false
  end
  if InCombatLockdown() then
    if manual then
      ns.Say(L["can't deposit during a fight."])
    end
    return false
  end
  if GameDeposit() then
    return true
  end
  local queue = D.Candidates()
  if #queue == 0 then
    if manual then
      Report(0, 0)
    end
    return false
  end
  D.run = { queue = queue, pos = 1, done = {}, moved = 0, left = 0, manual = manual }
  Step()
  return true
end
