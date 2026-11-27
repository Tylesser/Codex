local addonName, ns = ...
local L = ns.L

-- Bags module, part 7: the bank window. At the banker (BANKFRAME_OPENED, or the game's BankFrame showing)
-- the game's bank window stays open but is parked off screen with alpha 0 (Blizzard.lua B.ParkPanel): it
-- has to stay shown, since the game's own bag-button right-click asks BankFrame:GetActiveBankType() to move
-- items into the bank, and hiding it ends the visit. The Codex bank window shows the bank's containers in
-- the bag window's look: live ContainerFrameItemButtonTemplate buttons under holders whose ID is the bank
-- container (Forever: CharacterBankTab_1..9 = 6..14, from C_Bank.FetchPurchasedBankTabIDs), so clicking,
-- right-clicking (back to the bags), dragging and splitting are the game's own. Categories packed side by
-- side like the bags (or one section per bank tab in bag order), search, sort (C_Container.SortBank), free
-- slots and money. Buying bank tabs and putting bags in them stays in the game's window: the "game's bank"
-- button shows it. Buttons are made, placed and shown only out of combat; a bank opened during a fight
-- with buttons still to make is shown in the game's window instead. Closing the Codex window ends the visit.

local B = ns.bags
local UI = ns.UI

local bank = { search = "", headings = { list = {} } }
B.bank = bank
local frame

local function BankType()
  return Enum and Enum.BankType and Enum.BankType.Character
end
B.BankType = BankType

local function GameBank()
  local game = _G.BankFrame
  return type(game) == "table" and game.IsShown and game or nil
end
B.GameBank = GameBank

-- The open bank's containers with slots, in order.
function B.LiveBankBags()
  local list = {}
  local bankType = BankType()
  if C_Bank and C_Bank.FetchPurchasedBankTabIDs and bankType ~= nil then
    local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
    if ok and type(ids) == "table" then
      for _, id in ipairs(ids) do
        if type(id) == "number" and (C_Container.GetContainerNumSlots(id) or 0) > 0 then
          list[#list + 1] = id
        end
      end
      if #list > 0 then
        table.sort(list)
        return list
      end
    end
  end
  for _, id in ipairs(B.BankBags()) do
    if (C_Container.GetContainerNumSlots(id) or 0) > 0 then
      list[#list + 1] = id
    end
  end
  return list
end

-- [container] = the name the player gave the bank tab, when there is one.
local function TabNames()
  local names = {}
  local bankType = BankType()
  if C_Bank and C_Bank.FetchPurchasedBankTabData and bankType ~= nil then
    local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
    if ok and type(data) == "table" then
      for _, tab in ipairs(data) do
        if type(tab) == "table" and tab.ID and B.Readable(tab.name) and tab.name ~= "" then
          names[tab.ID] = tab.name
        end
      end
    end
  end
  return names
end

-- Bag order: one section per bank container, every slot.
local function BagOrderSections(bags, slots)
  local names = TabNames()
  local sections, byBag = {}, {}
  for index, bagID in ipairs(bags) do
    local name = names[bagID] or (index == 1 and L["Bank"] or L["Bank bag %d"]:format(index - 1))
    local section = { id = "bank" .. bagID, name = name, entries = {}, wide = true }
    byBag[bagID] = section
    sections[#sections + 1] = section
  end
  for _, entry in ipairs(slots) do
    local section = byBag[entry.bagID]
    if section then
      section.entries[#section.entries + 1] = entry
    end
  end
  return sections
end

local function Columns()
  return math.max(10, math.min(24, B.db.bankColumns or 14))
end

-- Footer and header ---------------------------------------------------------------------------------------

local function UpdateFooter(free, size)
  if size then
    frame.free:SetText(L["Free %d / %d"]:format(free, size))
  else
    frame.free:SetText(L["Free %d"]:format(free))
  end
  local _, total = B.MoneyList()
  frame.money.text:SetText(ns.Money(GetMoney() or 0) .. "   |cff999999" .. L["Total"] .. "|r " .. ns.Money(total))
end

-- A short line in the footer (the deposit's result), gone after a while.
function B.BankNote(text)
  if not frame then
    return
  end
  frame.note:SetText(text or "")
  local stamp = (bank.noteStamp or 0) + 1
  bank.noteStamp = stamp
  C_Timer.After(12, function()
    if bank.noteStamp == stamp and frame then
      frame.note:SetText("")
    end
  end)
end

local function UpdateHeader()
  local theme = ns.Theme()
  frame.title:SetText(theme.titlebar.upper and L["Bank"]:upper() or L["Bank"])
  local game = GameBank()
  B.SetIconState(frame.game, game ~= nil and game:IsShown() and not B.IsParked(game), game ~= nil)
  B.SetIconState(frame.sort, false, true)
  local deposit = B.db.depositButton
  frame.deposit:SetShown(deposit)
  frame.search:SetPoint("RIGHT", deposit and frame.deposit or frame.sort, "LEFT", -6, 0)
end

-- Layout -----------------------------------------------------------------------------------------------------

function B.RefreshBank()
  if not frame or not frame:IsShown() then
    bank.pending = true
    return
  end
  bank.queued = false
  UpdateHeader()
  local bags = B.LiveBankBags()
  if InCombatLockdown() then
    -- refill what is shown; the layout waits for the end of the fight
    local free = B.RefillSet(bank.set, bags)
    bank.pending = true
    B.DimSet(bank.set, bank.search)
    UpdateFooter(free)
    return
  end
  B.ReadSizes()
  local _, _, gap, cell, heading = B.Sizes()
  B.EnsureButtons(bank.set, bags)
  local entries, slots, free = B.LiveEntries(bags)
  local sections
  if B.db.categories then
    sections = B.CategorySections(entries, free)
  else
    sections = BagOrderSections(bags, slots)
  end
  B.SetMinCols(sections)
  local columns = Columns()
  local packed = B.Pack(sections, columns, cell, heading, gap, B.db.pack)
  B.PlaceLive(bank.set, packed, bank.headings, frame.content)
  bank.pending = false
  bank.lastPacked = packed
  B.ResizeWindow(frame, columns, packed.height)
  B.DimSet(bank.set, bank.search)
  UpdateFooter(free.normal.count + free.reagent.count, #slots)
end

-- Coalesces bursts of bank and bag events into one refresh while the window is open.
function B.RequestBankRefresh()
  if not frame or not frame:IsShown() then
    bank.pending = true
    return
  end
  if bank.queued then
    return
  end
  bank.queued = true
  C_Timer.After(0.05, function()
    if bank.queued then
      B.RefreshBank()
    end
  end)
end

-- Item lock / cooldown changes.
function B.RefillBank()
  if frame and frame:IsShown() then
    B.RefillButtons(bank.set)
  end
end

function B.BankWindow()
  return frame
end

-- Sorting ----------------------------------------------------------------------------------------------------

-- The game's bank sort (Forever: C_Container.SortBank(Enum.BankType.Character); older clients
-- C_Container.SortBankBags()).
function B.SortBank()
  if InCombatLockdown() then
    ns.Say(L["the bank can be sorted after the fight."])
    return false
  end
  local bankType = BankType()
  if C_Container.SortBank and bankType ~= nil then
    C_Container.SortBank(bankType)
    return true
  elseif C_Container.SortBankBags then
    C_Container.SortBankBags()
    return true
  end
  ns.Say(L["this game client can't sort the bank."])
  return false
end

-- The game's bank window, shown normally (buy bank tabs, put bags in them) or parked again.
function B.ToggleGameBank()
  local game = GameBank()
  if not game or not game:IsShown() then
    return false
  end
  if B.IsParked(game) then
    B.UnparkPanel(game)
  else
    B.ParkPanel(game)
  end
  if frame then
    UpdateHeader()
  end
  return true
end

-- Opening and closing ----------------------------------------------------------------------------------------

-- Ends the visit (our window was closed): the game's window closes, which tells the game.
local function EndVisit()
  local game = GameBank()
  if game and game:IsShown() and type(HideUIPanel) == "function" then
    pcall(HideUIPanel, game) -- its OnHide calls C_Bank.CloseBankFrame
  end
  if B.bankOpen then
    if C_Bank and C_Bank.CloseBankFrame then
      pcall(C_Bank.CloseBankFrame)
    elseif type(CloseBankFrame) == "function" then
      pcall(CloseBankFrame)
    end
  end
end

-- Built on first use. Item buttons come later, with the first layout (out of combat).
function B.CreateBankWindow()
  if frame then
    return frame
  end
  B.DB()
  frame = B.NewWindow("CodexBankFrame", "bankPoint", { "TOPLEFT", "TOPLEFT", 40, -120 })
  B.TitleBar(frame)
  local top = -(5 + select(7, B.Sizes()) + 11)
  local pad = select(6, B.Sizes())
  frame.game = B.IconButton(frame, "Interface\\Icons\\INV_Misc_Bag_10_Blue", function()
    B.ToggleGameBank()
  end, function()
    local game = GameBank()
    local shown = game and not B.IsParked(game)
    return { L["The game's bank window"], (shown and L["Click to hide it again."] or L["Click to show it: buy bank tabs and put bags in them there."]) }
  end)
  frame.game.keepColors = true
  frame.game:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, top)
  frame.sort = B.IconButton(frame, "Interface\\Icons\\INV_Pet_Broom", function()
    B.SortBank()
  end, function()
    return { L["Sort the bank"], L["The game's own bank sort."] }
  end)
  frame.sort:SetPoint("RIGHT", frame.game, "LEFT", -6, 0)
  frame.deposit = B.TextButton(frame, 130, L["Deposit reagents"], function()
    B.deposit.Run(true)
  end, function()
    return { L["Deposit reagents"], L["Puts the crafting reagents from your bags into the bank. Never quest items, gear, ammo or keys."] }
  end)
  frame.deposit:SetPoint("RIGHT", frame.sort, "LEFT", -6, 0)
  frame.search = B.SearchBox(frame, frame.deposit, function(text)
    bank.search = text
    B.DimSet(bank.set, text)
  end)
  frame.content = CreateFrame("Frame", nil, frame)
  frame.content:SetPoint("TOPLEFT", pad, -frame.top)
  frame.content:SetPoint("BOTTOMRIGHT", -pad, select(9, B.Sizes()))
  bank.set = B.NewLiveSet(frame.content, "CodexBankLive")
  B.Footer(frame)
  frame.note = UI.Text(frame.band, "body", 13, "accent")
  frame.note:SetPoint("LEFT", frame.free, "RIGHT", 14, 0)
  frame:SetScript("OnShow", function()
    B.RefreshBank()
  end)
  frame:SetScript("OnHide", function()
    frame.search:ClearFocus()
    if not bank.syncing then
      bank.syncing = true
      EndVisit()
      bank.syncing = false
    end
  end)
  B.bankFrame = frame
  return frame
end

-- The bank is open: the Codex window instead of the game's, when wanted and possible.
function B.OpenBank()
  if not B.bankOpen or not B.db.bankWindow or bank.syncing then
    return false
  end
  local bags = B.LiveBankBags()
  if InCombatLockdown() and not (frame and bank.set and B.HasButtons(bank.set, bags)) then
    -- the buttons can't be made during a fight: the game's bank window this time
    if not bank.toldCombat then
      bank.toldCombat = true
      ns.Say(L["the Codex bank window opens out of combat; the game's bank this time."])
    end
    return false
  end
  B.CreateBankWindow()
  local game = GameBank()
  if game and game:IsShown() and not (InCombatLockdown() and game.IsProtected and game:IsProtected()) then
    B.ParkPanel(game)
  end
  if not frame:IsShown() then
    bank.syncing = true
    frame:Show()
    bank.syncing = false
  else
    B.RefreshBank()
  end
  return true
end

-- The visit ended (BANKFRAME_CLOSED, or the game's window closed).
function B.CloseBank()
  bank.toldCombat = nil
  if B.deposit and B.deposit.run then
    B.deposit.Stop("closed")
  end
  if frame and frame:IsShown() then
    bank.syncing = true
    frame:Hide()
    bank.syncing = false
  end
  B.UnparkPanel(GameBank())
end

-- The option was switched while at the bank: hand over to the game's window or take over from it.
function B.SetBankWindow(on)
  B.db.bankWindow = on and true or false
  if not B.bankOpen then
    return
  end
  if on then
    B.OpenBank()
  else
    if frame and frame:IsShown() then
      bank.syncing = true
      frame:Hide()
      bank.syncing = false
    end
    B.UnparkPanel(GameBank())
  end
end

-- Once, from Enable: the game's bank window showing means the banker is open (its OnShow can come before
-- BANKFRAME_OPENED); parking it right away keeps it from flashing.
function B.InstallBankHooks()
  local game = GameBank()
  if not game or B.bankHooks then
    return
  end
  B.bankHooks = true
  game:HookScript("OnShow", function()
    if B.db.bankWindow then
      B.bankOpen = true
      B.OpenBank()
    end
  end)
  game:HookScript("OnHide", function()
    if not bank.syncing then
      B.CloseBank()
    end
  end)
end
