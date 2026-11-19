local addonName, ns = ...

-- Bags module, part 9: the guild bank window. At the guild vault (GUILDBANKFRAME_OPENED) the game's
-- GuildBankFrame (Blizzard_GuildBankUI, loaded on demand) stays open but is parked like the bank window,
-- and the Codex window shows the guild's tabs down the left (icon, name, withdrawals left; tabs you can't
-- view are greyed) and the current tab's 98 slots in the bag window's item look, in the game's order (14
-- columns of 7). Slots are plain buttons of ours (the guild bank functions aren't protected): left-click /
-- drag = PickupGuildBankItem, right-click = AutoStoreGuildBankItem (into your bags), Shift-click links,
-- split with the split-stack modifier, money on the cursor is deposited. Search lights the current tab's
-- matches. Money: the guild's, your withdraw limit, Deposit / Withdraw through the game's own popups
-- (GUILDBANK_DEPOSIT / GUILDBANK_WITHDRAW). "Log" shows the game's window (its log tabs). Changing tab calls
-- QueryGuildBankTab, as the game does. Closing the Codex window ends the visit (CloseGuildBankFrame).

local B = ns.bags
local UI = ns.UI
local T = ns.T

local G = { open = false, search = "" }
B.guild = G

local SLOTS = 98          -- MAX_GUILDBANK_SLOTS_PER_TAB
local PER_COLUMN = 7       -- the game's guild bank fills 14 columns of 7, top to bottom
local COLUMNS = 14
local MAX_TABS = 8         -- MAX_GUILDBANK_TABS
local TAB = 32             -- tab button size
local INFO = 22            -- the tab's name and rights over the slots

local frame
local tabs, slots = {}, {}
local syncing = false

local function Call(name, ...)
  local fn = _G[name]
  if type(fn) == "function" then
    return fn(...)
  end
end

-- Has this client a guild bank (the functions the window needs)?
function G.Available()
  for _, name in ipairs({ "GetNumGuildBankTabs", "GetGuildBankTabInfo", "GetGuildBankItemInfo",
    "GetCurrentGuildBankTab", "SetCurrentGuildBankTab", "QueryGuildBankTab" }) do
    if type(_G[name]) ~= "function" then
      return false
    end
  end
  return true
end

local function GameGuildBank()
  local game = _G.GuildBankFrame
  return type(game) == "table" and game.IsShown and game or nil
end

local function CurrentTab()
  return Call("GetCurrentGuildBankTab") or 1
end

-- { name, icon, viewable, canDeposit, withdrawals, remaining } of a tab.
function G.TabInfo(tab)
  local name, icon, viewable, canDeposit, withdrawals, remaining = Call("GetGuildBankTabInfo", tab)
  return { name = name, icon = icon, viewable = viewable and true or false, canDeposit = canDeposit and true or false,
    withdrawals = withdrawals or 0, remaining = remaining or 0 }
end

-- "Full access, 5 stacks left today", "Deposit only", ... (the game's own rules).
function G.RightsText(info)
  if not info.viewable then
    return "You can't view this tab"
  end
  local access
  if not info.canDeposit and info.withdrawals == 0 then
    access = "View only"
  elseif not info.canDeposit then
    access = "Withdraw only"
  elseif info.withdrawals == 0 then
    access = "Deposit only"
  else
    access = "Full access"
  end
  if info.withdrawals ~= 0 then
    local left
    if info.remaining > 0 then
      left = ("%d stack%s left today"):format(info.remaining, info.remaining == 1 and "" or "s")
    elseif info.remaining == 0 then
      left = "no withdrawals left today"
    else
      left = "unlimited withdrawals"
    end
    access = access .. ", " .. left
  end
  return access
end

-- Slots -------------------------------------------------------------------------------------------------------

local function SlotClick(self, button)
  local tab, slot = CurrentTab(), self:GetID()
  local link = Call("GetGuildBankItemLink", tab, slot)
  if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then
    return
  end
  if IsModifiedClick and IsModifiedClick("SPLITSTACK") then
    local cursor = CursorHasItem and CursorHasItem()
    if not cursor then
      local _, count, locked = Call("GetGuildBankItemInfo", tab, slot)
      if not locked and count and count > 1 and StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then
        StackSplitFrame:OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
      end
    end
    return
  end
  local kind, money = Call("GetCursorInfo")
  if kind == "money" then
    Call("DepositGuildBankMoney", money)
    Call("ClearCursor")
  elseif kind == "guildbankmoney" then
    Call("DropCursorMoney")
    Call("ClearCursor")
  elseif button == "RightButton" then
    Call("AutoStoreGuildBankItem", tab, slot)
    GameTooltip_Hide()
  else
    Call("PickupGuildBankItem", tab, slot)
  end
end

local function Slot(index)
  local button = slots[index]
  if button then
    return button
  end
  local size = B.Sizes()
  button = CreateFrame("Button", nil, frame.grid)
  button:SetID(index)
  button:SetSize(size, size)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  B.SlotLook(button, button.icon)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnClick", SlotClick)
  button:SetScript("OnDragStart", function(self)
    Call("PickupGuildBankItem", CurrentTab(), self:GetID())
  end)
  button:SetScript("OnReceiveDrag", function(self)
    Call("PickupGuildBankItem", CurrentTab(), self:GetID())
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetGuildBankItem then
      GameTooltip:SetGuildBankItem(CurrentTab(), self:GetID())
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button.SplitStack = function(self, split)
    Call("SplitGuildBankItem", CurrentTab(), self:GetID(), split)
  end
  slots[index] = button
  return button
end
G.slots = slots

local function ApplySearch()
  local search = G.search
  for _, button in ipairs(slots) do
    local match = search == "" or (button.link and B.Matches({ link = button.link }, search)) or false
    button:SetAlpha((search == "" or match) and 1 or 0.25)
  end
end

-- Tabs ---------------------------------------------------------------------------------------------------------

local function TabButton(index)
  local button = tabs[index]
  if button then
    return button
  end
  button = B.IconButton(frame, "Interface\\Icons\\INV_Misc_QuestionMark", function(self)
    G.SelectTab(self.tab)
  end, function(self)
    local info = G.TabInfo(self.tab)
    return { info.name or ("Tab " .. self.tab), G.RightsText(info) }
  end)
  button:SetSize(TAB, TAB)
  button.icon:SetSize(TAB - 8, TAB - 8)
  button.keepColors = true
  button.tab = index
  button.selected = T.Outline(button, 0, ns.Theme().accent, 2, "OVERLAY")
  tabs[index] = button
  return button
end
G.tabs = tabs

-- The first tab the player may view, or nil.
local function FirstViewable(count)
  for tab = 1, count do
    if G.TabInfo(tab).viewable then
      return tab
    end
  end
end

function G.SelectTab(tab)
  if not G.TabInfo(tab).viewable then
    return false
  end
  if CurrentTab() ~= tab then
    Call("SetCurrentGuildBankTab", tab)
  end
  Call("QueryGuildBankTab", tab)
  G.Refresh()
  return true
end

-- Refresh --------------------------------------------------------------------------------------------------

local function UpdateMoney()
  local guild = Call("GetGuildBankMoney") or 0
  local limit = Call("GetGuildBankWithdrawMoney")
  local canWithdraw = Call("CanWithdrawGuildBankMoney") and true or false
  local text = "Guild " .. ns.Money(guild)
  if canWithdraw and limit and limit >= 0 then
    text = text .. "   |cff999999You may take|r " .. ns.Money(math.min(limit, guild))
  elseif canWithdraw then
    text = text .. "   |cff999999No limit|r"
  end
  frame.money.text:SetText(text)
  frame.withdraw:SetEnabled(canWithdraw and (not limit or limit ~= 0))
end
G.UpdateMoney = UpdateMoney

function G.Refresh()
  if not frame or not frame:IsShown() then
    return
  end
  local count = math.min(MAX_TABS, Call("GetNumGuildBankTabs") or 0)
  local current = CurrentTab()
  if count > 0 and (current > count or not G.TabInfo(current).viewable) then
    local first = FirstViewable(count)
    if first and first ~= current then
      Call("SetCurrentGuildBankTab", first)
      Call("QueryGuildBankTab", first)
      current = first
    end
  end
  for index = 1, math.max(count, #tabs) do
    local button = TabButton(index)
    if index <= count then
      local info = G.TabInfo(index)
      button.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      B.SetIconState(button, index == current, info.viewable)
      button:SetEnabled(info.viewable)
      for _, line in ipairs(button.selected) do
        line:SetShown(index == current)
      end
      button:Show()
    else
      button:Hide()
    end
  end
  local info = count > 0 and G.TabInfo(current) or nil
  if not info then
    frame.info:SetText("The guild has no bank tabs yet.")
  elseif not info.viewable then
    frame.info:SetText("No tab you can view.")
  else
    frame.info:SetText(("|cffffffff%s|r   %s"):format(info.name or ("Tab " .. current), G.RightsText(info)))
  end
  local show = info and info.viewable
  local filled = 0
  for index = 1, SLOTS do
    local button = Slot(index)
    if show then
      local texture, itemCount, locked, _, quality = Call("GetGuildBankItemInfo", current, index)
      button.link = texture and Call("GetGuildBankItemLink", current, index) or nil
      button.icon:SetTexture(texture)
      button.icon:SetDesaturated(locked and true or false)
      B.SetEmpty(button, not texture)
      B.SetCount(button, texture and itemCount or nil)
      B.SetQuality(button, texture and quality or nil)
      if texture then
        filled = filled + 1
      end
      button:Show()
    else
      button.link = nil
      button:Hide()
    end
  end
  frame.free:SetText(show and ("Free %d / %d"):format(SLOTS - filled, SLOTS) or "")
  UpdateMoney()
  ApplySearch()
end

-- Window ---------------------------------------------------------------------------------------------------

local function EndVisit()
  for _, name in ipairs({ "GUILDBANK_WITHDRAW", "GUILDBANK_DEPOSIT" }) do
    if StaticPopup_Hide then
      pcall(StaticPopup_Hide, name)
    end
  end
  local game = GameGuildBank()
  if game and game:IsShown() and type(HideUIPanel) == "function" then
    pcall(HideUIPanel, game) -- its OnHide calls CloseGuildBankFrame
  end
  if G.open then
    Call("CloseGuildBankFrame")
  end
end

local function ShowPopup(name)
  if StaticPopupDialogs and StaticPopupDialogs[name] and StaticPopup_Show then
    for _, other in ipairs({ "GUILDBANK_WITHDRAW", "GUILDBANK_DEPOSIT" }) do
      if other ~= name and StaticPopup_Hide then
        StaticPopup_Hide(other)
      end
    end
    StaticPopup_Show(name)
    return true
  end
  return false
end
G.ShowPopup = ShowPopup

-- The game's guild bank window shown normally (its log tabs), or parked again.
function G.ToggleLog()
  local game = GameGuildBank()
  if not game or not game:IsShown() then
    return false
  end
  if B.IsParked(game) then
    B.UnparkPanel(game)
    local logTab = game.Tabs and game.Tabs[2]
    if type(logTab) == "table" and logTab.Click then
      pcall(logTab.Click, logTab)
    end
  else
    local bankTab = game.Tabs and game.Tabs[1]
    if type(bankTab) == "table" and bankTab.Click then
      pcall(bankTab.Click, bankTab)
    end
    B.ParkPanel(game)
  end
  return true
end

function G.CreateWindow()
  if frame then
    return frame
  end
  B.DB()
  B.ReadSizes()
  local size, spacing, _, cell, _, pad, title = B.Sizes()
  frame = B.NewWindow("CodexGuildBankFrame", "guildBankPoint", { "TOPLEFT", "TOPLEFT", 40, -120 })
  B.TitleBar(frame)
  local top = -(5 + title + 11)
  frame.log = B.TextButton(frame, 60, "Log", function()
    G.ToggleLog()
  end, function()
    return { "Guild bank log", "Shows the game's guild bank window with its logs. Click again to hide it." }
  end)
  frame.log:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, top)
  frame.search = B.SearchBox(frame, frame.log, function(text)
    G.search = text
    ApplySearch()
  end)
  -- tabs down the left, the slots beside them
  local left = pad + TAB + 10
  frame.info = UI.Text(frame, "body", 12, "muted")
  frame.info:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -frame.top)
  frame.info:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
  frame.info:SetWordWrap(false)
  frame.grid = CreateFrame("Frame", nil, frame)
  frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -(frame.top + INFO))
  frame.grid:SetSize(COLUMNS * cell - spacing, PER_COLUMN * cell - spacing)
  for index = 1, SLOTS do
    local button = Slot(index)
    local col, row = math.floor((index - 1) / PER_COLUMN), (index - 1) % PER_COLUMN
    button:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", col * cell, -row * cell)
  end
  for index = 1, MAX_TABS do
    local button = TabButton(index)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(frame.top + (index - 1) * (TAB + 6)))
    button:Hide()
  end
  B.Footer(frame)
  frame.money:SetScript("OnEnter", nil)
  frame.deposit = B.TextButton(frame.band, 70, "Deposit", function()
    ShowPopup("GUILDBANK_DEPOSIT")
  end)
  frame.deposit:SetHeight(22)
  frame.deposit:SetPoint("RIGHT", frame.band, "CENTER", 30, 0)
  frame.withdraw = B.TextButton(frame.band, 70, "Withdraw", function()
    ShowPopup("GUILDBANK_WITHDRAW")
  end)
  frame.withdraw:SetHeight(22)
  frame.withdraw:SetPoint("LEFT", frame.deposit, "RIGHT", 6, 0)
  frame.money:ClearAllPoints()
  frame.money:SetPoint("RIGHT", frame.band, "RIGHT", -12, 0)
  frame.money:SetPoint("LEFT", frame.withdraw, "RIGHT", 10, 0)
  local width = left + COLUMNS * cell - spacing + pad
  frame:SetSize(math.max(width, 560), frame.top + INFO + PER_COLUMN * cell - spacing + select(9, B.Sizes()))
  frame.title:SetText(ns.Theme().titlebar.upper and "GUILD BANK" or "Guild bank")
  frame:SetScript("OnShow", function()
    G.Refresh()
  end)
  frame:SetScript("OnHide", function()
    frame.search:ClearFocus()
    if not syncing then
      syncing = true
      EndVisit()
      syncing = false
    end
  end)
  G.frame = frame
  return frame
end

function G.Window()
  return frame
end

-- Opening and closing ----------------------------------------------------------------------------------------

local function HookGame()
  local game = GameGuildBank()
  if not game or G.hooked then
    return game
  end
  G.hooked = true
  -- the game's window only shows at the vault (sometimes before GUILDBANKFRAME_OPENED): park it right away
  game:HookScript("OnShow", function()
    if B.db.guildBankWindow then
      G.Open()
    end
  end)
  game:HookScript("OnHide", function()
    if not syncing then
      G.Close()
    end
  end)
  return game
end

-- The guild vault is open (GUILDBANKFRAME_OPENED; the game's window loads and shows around it).
function G.Open()
  G.open = true
  if not B.db.guildBankWindow or not G.Available() then
    return false
  end
  local game = HookGame()
  if game and game:IsShown() then
    B.ParkPanel(game)
  end
  G.CreateWindow()
  -- shown once the game's window is parked (or when this client has none)
  if not game or (game:IsShown() and B.IsParked(game)) then
    if not frame:IsShown() then
      Call("QueryGuildBankTab", CurrentTab())
      syncing = true
      frame:Show()
      syncing = false
    else
      G.Refresh()
    end
  end
  return true
end

-- The visit ended.
function G.Close()
  G.open = false
  if frame and frame:IsShown() then
    syncing = true
    frame:Hide()
    syncing = false
  end
  B.UnparkPanel(GameGuildBank())
end

function G.SetWindow(on)
  B.db.guildBankWindow = on and true or false
  if not G.open then
    return
  end
  if on then
    G.Open()
  else
    if frame and frame:IsShown() then
      syncing = true
      frame:Hide()
      syncing = false
    end
    B.UnparkPanel(GameGuildBank())
  end
end

function G.OnEvent(event)
  if event == "GUILDBANKFRAME_OPENED" then
    G.open = true
    -- the game loads and shows its window around this event: take over once it is there
    G.Open()
    C_Timer.After(0, function()
      if G.open then
        G.Open()
      end
    end)
  elseif event == "GUILDBANKFRAME_CLOSED" then
    G.Close()
  elseif not frame or not frame:IsShown() then
    return
  elseif event == "GUILDBANK_UPDATE_MONEY" or event == "GUILDBANK_UPDATE_WITHDRAWMONEY" then
    UpdateMoney()
  else -- GUILDBANKBAGSLOTS_CHANGED, GUILDBANK_ITEM_LOCK_CHANGED, GUILDBANK_UPDATE_TABS
    G.Refresh()
  end
end

G.EVENTS = { "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_ITEM_LOCK_CHANGED",
  "GUILDBANK_UPDATE_TABS", "GUILDBANK_UPDATE_MONEY", "GUILDBANK_UPDATE_WITHDRAWMONEY" }
