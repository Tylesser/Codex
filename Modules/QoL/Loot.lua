local addonName, ns = ...
local L = ns.L

-- Faster loot: when auto-loot applies (the "Auto Loot" option, turned around while the auto-loot key is held),
-- every slot is taken at LOOT_READY, before the loot window has drawn, so it barely flashes.
--
-- Left for the game's own loot window (so the player can choose):
-- - slots that are locked (a roll in progress, someone else's master loot) or empty;
-- - with master loot, items at or above the loot threshold (the master looter hands them out);
-- - in a group, bind-on-pickup items of uncommon or better (the game asks to confirm those). If the game asks
--   anyway (LOOT_BIND_CONFIRM), the run stops until the window closes and the game's dialog does the rest;
-- - items once the bags have no free slot (coins and currencies are still taken).
-- LOOT_READY can fire twice for one corpse: a second run within DELAY seconds is ignored (reset at LOOT_CLOSED).
-- FasterLoot, or Leatrix Plus with "Faster auto loot" on, does the same: then this stays idle.

local Q = ns.qol
local FL = {}
Q.loot = FL

local DELAY = 0.3
local ITEM_SLOT = 1 -- Enum.LootSlotType.Item
local UNCOMMON = 2
local BIND_ON_PICKUP = 1

FL.last = nil -- GetTime() of the last run
FL.cleared = {} -- [slot] = true once LOOT_SLOT_CLEARED fired, until the window closes
FL.confirm = false -- the game asked to confirm a bind-on-pickup item
FL.result = nil -- { taken, left, reason } of the last run, for the page and tests

function FL.Elsewhere()
  if ns.IsAddOnLoaded("FasterLoot") then
    return "FasterLoot"
  end
  if ns.IsAddOnLoaded("Leatrix_Plus") then
    local db = _G.LeaPlusDB
    if type(db) == "table" and db.FasterLooting == "On" then
      return "Leatrix Plus"
    end
  end
  return nil
end

function FL.AutoLoot()
  local default = GetCVarBool and GetCVarBool("autoLootDefault") and true or false
  local key = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") and true or false
  return default ~= key
end

-- Free slots in the bags that take any item (not profession bags, not the reagent bag).
function FL.FreeSlots()
  if not (C_Container and C_Container.GetContainerNumFreeSlots) then
    return math.huge
  end
  local free = 0
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local count, family = C_Container.GetContainerNumFreeSlots(bag)
    if (family or 0) == 0 then
      free = free + (count or 0)
    end
  end
  return free
end

local function SlotType(slot)
  if not GetLootSlotType then
    return ITEM_SLOT
  end
  local enum = Enum and Enum.LootSlotType
  local kind = GetLootSlotType(slot)
  if kind == nil then
    return ITEM_SLOT -- unknown: treat it as an item (needs a bag slot)
  end
  return (enum and enum.Item and kind == enum.Item) and ITEM_SLOT or kind
end

local function MasterLoot()
  local method
  if C_PartyInfo and C_PartyInfo.GetLootMethod then
    method = C_PartyInfo.GetLootMethod()
  elseif GetLootMethod then
    method = GetLootMethod()
  end
  local master = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter
  return method == "master" or (master ~= nil and method == master)
end

local function InGroup()
  return IsInGroup and IsInGroup() or false
end

-- In a group the game asks before a bind-on-pickup item of uncommon or better is looted.
local function NeedsConfirm(slot, quality)
  if not InGroup() or (quality or 0) < UNCOMMON then
    return false
  end
  local link = GetLootSlotLink and GetLootSlotLink(slot)
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not (link and info) then
    return false
  end
  return select(14, info(link)) == BIND_ON_PICKUP
end

-- What to do with a slot: "take", "item" (take, needs a bag slot) or nil (leave it).
local function Plan(slot, masterLoot, threshold)
  if FL.cleared[slot] then
    return nil
  end
  local texture, _, _, _, quality, locked = GetLootSlotInfo(slot)
  if not texture or locked then
    return nil
  end
  if SlotType(slot) ~= ITEM_SLOT then
    return "take"
  end
  if masterLoot and (quality or 0) >= threshold then
    return nil
  end
  if NeedsConfirm(slot, quality) then
    return nil
  end
  return "item"
end

function FL.Run()
  local count = GetNumLootItems and GetNumLootItems() or 0
  local result = { taken = 0, left = 0 }
  FL.result = result
  if count == 0 then
    return result
  end
  local masterLoot = MasterLoot()
  local threshold = (masterLoot and GetLootThreshold and GetLootThreshold()) or UNCOMMON
  local free = FL.FreeSlots()
  for slot = count, 1, -1 do
    if FL.confirm then
      result.reason = "confirm"
      break
    end
    local plan = Plan(slot, masterLoot, threshold)
    if plan == "item" and free <= 0 then
      result.reason = "bags"
      plan = nil
    end
    if plan then
      if plan == "item" then
        free = free - 1
      end
      LootSlot(slot)
      result.taken = result.taken + 1
    else
      result.left = result.left + 1
    end
  end
  return result
end

local function OnReady()
  if not Q.On("fasterLoot") or FL.confirm or not FL.AutoLoot() then
    return
  end
  local now = GetTime()
  if FL.last and now - FL.last < DELAY then
    return -- the second LOOT_READY of the same corpse
  end
  FL.last = now
  FL.Run()
end

local function Reset()
  FL.last = nil
  FL.cleared = {}
  FL.confirm = false
end

function FL.Enable()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event, slot)
    if event == "LOOT_READY" then
      OnReady()
    elseif event == "LOOT_SLOT_CLEARED" then
      if slot then
        FL.cleared[slot] = true
      end
    elseif event == "LOOT_BIND_CONFIRM" then
      FL.confirm = true
    elseif event == "LOOT_CLOSED" then
      Reset()
    end
  end)
  for _, event in ipairs({ "LOOT_READY", "LOOT_SLOT_CLEARED", "LOOT_BIND_CONFIRM", "LOOT_CLOSED" }) do
    events:RegisterEvent(event)
  end
  FL.frame = events
end

Q.AddToggle({
  key = "fasterLoot",
  name = L["Faster loot"],
  desc = L["With auto-loot, takes everything at once so the loot window barely flashes. Items that need a roll, a confirmation or a free bag slot stay in the window for you."],
  order = 10,
  Enable = FL.Enable,
  Elsewhere = FL.Elsewhere,
})
