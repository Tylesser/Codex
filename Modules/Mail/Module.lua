local addonName, ns = ...
local L = ns.L

-- Mail: three helpers at the mailbox (the game's own MailFrame, Blizzard_MailFrame in the forever branch).
--
-- Open all: Codex's Open all and Gold only buttons take the place of the game's Open All Mail button
-- (InboxFrame.OpenAllMail, hidden while ours are there). One step every 0.15 s (the game's own
-- OPEN_ALL_MAIL_MIN_DELAY), waiting while C_Mail.IsCommandPending(): each step finds the first shown mail with
-- something to take (TakeInboxMoney, then TakeInboxItem per attachment). Cash on Delivery and Game Master mails
-- are skipped (the game's Open All skips them too: they have to be opened by hand). With full bags the items are
-- left and the gold is still taken (the game's Open All stops at full bags). An item the server refuses
-- (MAIL_FAILED with its item ID: a unique item you have) is skipped. When the inbox holds more mail than it
-- shows (GetInboxNumItems' second value) and there is room, CheckInbox brings the rest once C_Mail.CanCheckInbox
-- allows. The run stops when nothing is left, on Stop, or when the mailbox closes (MAIL_CLOSED); one chat line
-- tells the gold (GetMoney before and after) and the number of items taken.
--
-- Recent names: the names you send mail to (hooksecurefunc("SendMail"), kept on MAIL_SEND_SUCCESS), per realm and
-- faction, newest first (20 kept), and your own characters there (recorded at login), in a menu from a small
-- button at the right end of the To box (SendMailNameEditBox; its text inset makes room).
--
-- Alt-click attach: Alt-click a bag item while the Send Mail tab shows (hooksecurefunc on HandleModifiedItemClick,
-- which the game's bag buttons call with the item's location for every modified click; Alt does nothing there by
-- default) and every stack of it in your bags goes into the letter, one stack every 0.1 s, never into a slot
-- that holds something and never soulbound ones, until the letter's 12 slots are full.
--
-- When Postal is loaded it does all three, so Codex leaves them to it. Nothing here is protected: it all works
-- in combat too, and hiding the game's Open All Mail button (not a secure frame) taints nothing.

local M = {}
ns.mail = M

local DEFAULTS = { openAll = true, recent = true, altAttach = true, recents = {}, characters = {} }
local STEP = 0.15 -- the game's OPEN_ALL_MAIL_MIN_DELAY
local ATTACH_STEP = 0.1
local MAX_RECENT = 20
local MENU_RECENT = 10
local MAX_STEPS = 2000 -- a safety net: no run takes more steps than this
local MAX_TRIES = 3 -- the same money or attachment asked for this often without effect is skipped
local MAX_WAITS = 5 -- times we wait for the server to send more mail without anything new
local CHECK_EXTRA = 0.5 -- seconds after CanCheckInbox's wait

M.run = nil -- the Open all run in progress
M.attach = nil -- the Alt-click attach in progress

function M.DB()
  if not M.db then
    ns.db.mail = ns.Fill(ns.db.mail or {}, DEFAULTS)
    M.db = ns.db.mail
  end
  return M.db
end

function M.PostalLoaded()
  return ns.IsAddOnLoaded("Postal") and true or false
end

-- A part runs: switched on and not left to Postal.
function M.Wanted(part)
  return M.running and M.DB()[part] and not M.PostalLoaded() or false
end

local function Shown(frame)
  return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

local function MailOpen()
  return M.mailOpen and Shown(_G.MailFrame)
end

local function SendTabOpen()
  return MailOpen() and Shown(_G.SendMailFrame)
end

local function After(seconds, fn)
  C_Timer.After(seconds, fn)
end

local function MaxReceive()
  return tonumber(_G.ATTACHMENTS_MAX_RECEIVE) or 16
end

local function MaxSend()
  return tonumber(_G.ATTACHMENTS_MAX_SEND) or 12
end

local function FreeBagSlots()
  local free = C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots
  if free then
    return tonumber(free()) or 0
  end
  return 1
end

local function CommandPending()
  return C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending() and true or false
end

-- Realm and faction: the key of the recent names and of your characters.
function M.Key()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  if type(faction) ~= "string" or faction == "" then
    faction = "?"
  end
  return ns.RealmName() .. "|" .. faction
end

-- Open all -----------------------------------------------------------------------------------------------------

local function Header(index)
  local _, _, sender, subject, money, cod, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(index)
  return sender, subject, tonumber(money) or 0, tonumber(cod) or 0, tonumber(itemCount) or 0, isGM and true or false
end

-- What one mail's money or attachment is called in the run's tries table: indexes move when a mail is emptied.
local function TryKey(index, kind, slot, itemID)
  local sender, subject = Header(index)
  return table.concat({ tostring(sender), tostring(subject), kind, tostring(slot or 0), tostring(itemID or 0) }, "\1")
end

-- The next thing to take: { index, kind = "money" / "item", slot }, or nil. Notes what it had to leave.
function M.NextTarget(run)
  local count = GetInboxNumItems() or 0
  local bagsFull = FreeBagSlots() <= 0
  run.codLeft, run.itemsLeft = 0, false
  for index = 1, count do
    local _, _, money, cod, itemCount, isGM = Header(index)
    if cod > 0 then
      run.codLeft = run.codLeft + 1
    elseif not isGM then
      if money > 0 then
        local key = TryKey(index, "money")
        if (run.tries[key] or 0) < MAX_TRIES then
          return { index = index, kind = "money", key = key }
        end
      end
      if run.mode == "all" and itemCount > 0 then
        for slot = 1, MaxReceive() do
          if HasInboxItem(index, slot) then
            local _, itemID = GetInboxItem(index, slot)
            local key = TryKey(index, "item", slot, itemID)
            if not (itemID and run.failed[itemID]) and (run.tries[key] or 0) < MAX_TRIES then
              if bagsFull then
                run.itemsLeft = true
              else
                return { index = index, kind = "item", slot = slot, key = key }
              end
            end
          end
        end
      end
    end
  end
  return nil
end

local function Finish(reason)
  local run = M.run
  if not run then
    return
  end
  M.run = nil
  local taken = math.max(0, (GetMoney() or 0) - run.startMoney)
  local lines = {}
  if taken > 0 and run.items > 0 then
    lines[#lines + 1] = L["Open all: took %s and %d items."]:format(ns.Money(taken), run.items)
  elseif taken > 0 then
    lines[#lines + 1] = L["Open all: took %s."]:format(ns.Money(taken))
  elseif run.items > 0 then
    lines[#lines + 1] = L["Open all: took %d items."]:format(run.items)
  else
    lines[#lines + 1] = L["Open all: nothing to take."]
  end
  if reason == "closed" then
    lines[#lines + 1] = L["Stopped: the mailbox closed."]
  elseif reason == "stopped" then
    lines[#lines + 1] = L["Stopped."]
  end
  if run.itemsLeft then
    lines[#lines + 1] = L["Your bags are full: the rest of the items wait in the mail."]
  end
  if run.codLeft > 0 then
    lines[#lines + 1] = L["Mails with Cash on Delivery are left for you to open: %d."]:format(run.codLeft)
  end
  ns.Say(table.concat(lines, " "))
  if M.RefreshButtons then
    M.RefreshButtons()
  end
end
M.Finish = Finish

local Step

local function Schedule(run, seconds)
  After(seconds, function()
    if M.run == run then
      Step()
    end
  end)
end

-- Asks the server for the mail the inbox doesn't show yet. True when we wait for it.
local function WaitForMore(run)
  local shown, total = GetInboxNumItems()
  shown, total = tonumber(shown) or 0, tonumber(total) or 0
  local frame = _G.InboxFrame
  local room = tonumber(frame and frame.maxShownMails) or 50
  if total <= shown or shown >= room or run.waits >= MAX_WAITS then
    return false
  end
  run.waits = run.waits + 1
  local can, seconds = true, 0
  if C_Mail and C_Mail.CanCheckInbox then
    can, seconds = C_Mail.CanCheckInbox()
  end
  if can then
    run.waiting = true
    CheckInbox()
    -- MAIL_INBOX_UPDATE goes on; this is in case it never comes
    Schedule(run, 5)
  else
    Schedule(run, (tonumber(seconds) or 1) + CHECK_EXTRA)
  end
  return true
end

function Step()
  local run = M.run
  if not run then
    return
  end
  run.waiting = false
  if not MailOpen() then
    return Finish("closed")
  end
  if CommandPending() then
    return Schedule(run, STEP)
  end
  run.steps = run.steps + 1
  if run.steps > MAX_STEPS then
    return Finish("done")
  end
  local target = M.NextTarget(run)
  if not target then
    if WaitForMore(run) then
      return
    end
    return Finish("done")
  end
  run.tries[target.key] = (run.tries[target.key] or 0) + 1
  if target.kind == "money" then
    TakeInboxMoney(target.index)
  else
    TakeInboxItem(target.index, target.slot)
    run.items = run.items + 1
  end
  run.waits = 0
  Schedule(run, STEP)
end

-- mode: "all" (gold and items) or "gold".
function M.StartOpenAll(mode)
  if M.run or not MailOpen() then
    return false
  end
  M.run = { mode = mode == "gold" and "gold" or "all", startMoney = GetMoney() or 0, items = 0, steps = 0,
    waits = 0, tries = {}, failed = {}, codLeft = 0, itemsLeft = false }
  if M.RefreshButtons then
    M.RefreshButtons()
  end
  Step()
  return true
end

function M.StopOpenAll()
  if M.run then
    Finish("stopped")
  end
end

-- Recent names and your characters -------------------------------------------------------------------------------

local function Trim(text)
  if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
    return nil
  end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text ~= "" and text or nil
end

function M.AddRecent(name)
  name = Trim(name)
  if not name then
    return
  end
  local db = M.DB()
  local key = M.Key()
  local list = db.recents[key] or {}
  for index = #list, 1, -1 do
    if type(list[index]) ~= "string" or list[index]:lower() == name:lower() then
      table.remove(list, index)
    end
  end
  table.insert(list, 1, name)
  while #list > MAX_RECENT do
    table.remove(list)
  end
  db.recents[key] = list
end

function M.Recents()
  return M.DB().recents[M.Key()] or {}
end

function M.ClearRecents()
  M.DB().recents[M.Key()] = nil
end

function M.RememberMe()
  local name = ns.PlayerName()
  if name == "?" then
    return
  end
  local db = M.DB()
  local key = M.Key()
  local list = db.characters[key] or {}
  local _, class = UnitClass("player")
  list[name] = type(class) == "string" and class or true
  db.characters[key] = list
end

-- Your other characters on this realm and faction, sorted by name: { name, class }.
function M.Characters()
  local me = ns.PlayerName()
  local out = {}
  for name, class in pairs(M.DB().characters[M.Key()] or {}) do
    if name ~= me then
      out[#out + 1] = { name = name, class = type(class) == "string" and class or nil }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

local function ClassName(name, class)
  local colors = _G.RAID_CLASS_COLORS
  local color = class and colors and colors[class]
  if color and type(color.colorStr) == "string" then
    return "|c" .. color.colorStr .. name .. "|r"
  end
  return name
end

function M.PickName(name)
  local box = _G.SendMailNameEditBox
  if box and box.SetText then
    box:SetText(name)
    local subject = _G.SendMailSubjectEditBox
    if subject and subject.SetFocus then
      subject:SetFocus()
    end
  end
end

function M.MenuItems()
  local items = {}
  local recents = M.Recents()
  if #recents > 0 then
    items[#items + 1] = { text = L["Recent"], title = true }
    for index = 1, math.min(#recents, MENU_RECENT) do
      local name = recents[index]
      items[#items + 1] = { text = name, func = function()
        M.PickName(name)
      end }
    end
  end
  local characters = M.Characters()
  if #characters > 0 then
    items[#items + 1] = { text = L["Your characters"], title = true }
    for _, character in ipairs(characters) do
      items[#items + 1] = { text = ClassName(character.name, character.class), func = function()
        M.PickName(character.name)
      end }
    end
  end
  if #items == 0 then
    items[#items + 1] = { text = L["No names yet: the names you send mail to show here."], disabled = true }
  elseif #recents > 0 then
    items[#items + 1] = { text = L["Forget the recent names"], func = function()
      M.ClearRecents()
    end }
  end
  return items
end

-- Alt-click attach -----------------------------------------------------------------------------------------------

local function ItemIDOf(link)
  if type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

local function LastBag()
  return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

-- A stack of itemID in your bags that can go into a letter: bag, slot.
local function NextStack(itemID)
  for bag = 0, LastBag() do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if type(info) == "table" and info.itemID == itemID and not info.isLocked and not info.isBound then
        return bag, slot
      end
    end
  end
  return nil
end

local function FreeAttachment(used)
  for index = 1, MaxSend() do
    if not used[index] and not HasSendMailItem(index) then
      return index
    end
  end
  return nil
end

local function FinishAttach(full)
  local run = M.attach
  if not run then
    return
  end
  M.attach = nil
  if run.count == 0 then
    return
  end
  local text = run.count == 1 and L["Attached 1 stack of %s."]:format(run.link)
    or L["Attached %d stacks of %s."]:format(run.count, run.link)
  if full and NextStack(run.itemID) then
    text = text .. " " .. L["The letter is full; the rest stays in your bags."]
  end
  ns.Say(text)
end

local function AttachStep()
  local run = M.attach
  if not run then
    return
  end
  if not SendTabOpen() or (CursorHasItem and CursorHasItem()) then
    return FinishAttach(false)
  end
  local index = FreeAttachment(run.used)
  if not index then
    return FinishAttach(true)
  end
  local bag, slot = NextStack(run.itemID)
  if not bag then
    return FinishAttach(false)
  end
  run.used[index] = true
  C_Container.PickupContainerItem(bag, slot)
  ClickSendMailItemButton(index)
  if CursorHasItem and CursorHasItem() then
    -- the slot was taken after all (an item came back on the cursor): put it back and stop
    ClearCursor()
    return FinishAttach(false)
  end
  run.count = run.count + 1
  After(ATTACH_STEP, function()
    if M.attach == run then
      AttachStep()
    end
  end)
end

-- Every stack of the item in your bags into the letter. link: the item's link (for the chat line).
function M.AttachAll(itemID, link)
  if M.attach or not itemID or not SendTabOpen() or (CursorHasItem and CursorHasItem()) then
    return false
  end
  M.attach = { itemID = itemID, link = link or L["item %s"]:format(itemID), count = 0, used = {} }
  AttachStep()
  return true
end

local function FromBags(itemLocation)
  return type(itemLocation) == "table" and type(itemLocation.IsBagAndSlot) == "function"
    and itemLocation:IsBagAndSlot() and true or false
end

local function OnModifiedItemClick(link, itemLocation)
  if not M.Wanted("altAttach") or not (IsAltKeyDown and IsAltKeyDown()) then
    return
  end
  if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then
    return
  end
  if not FromBags(itemLocation) or not SendTabOpen() then
    return
  end
  local itemID = ItemIDOf(link)
  if itemID then
    M.AttachAll(itemID, link)
  end
end
M.OnModifiedItemClick = OnModifiedItemClick

-- The buttons ----------------------------------------------------------------------------------------------------

local ui = {}
M.ui = ui

local function Tip(button, title, text)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    local body = type(text) == "function" and text() or text
    if body then
      GameTooltip:AddLine(body, 1, 1, 1, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip_Hide()
  end)
end

local function GameOpenAll()
  local inbox = _G.InboxFrame
  return (inbox and inbox.OpenAllMail) or _G.OpenAllMail
end

function M.RefreshButtons()
  local openAll = M.Wanted("openAll")
  if ui.all then
    ui.all:SetShown(openAll)
    ui.gold:SetShown(openAll)
    ui.all:SetText(M.run and L["Stop"] or L["Open all"])
    ui.gold:SetEnabled(not M.run)
  end
  local game = GameOpenAll()
  if game and game.SetShown and ui.hidGame ~= nil then
    if openAll then
      game:Hide()
    elseif ui.hidGame then
      game:Show()
    end
  end
  ui.hidGame = openAll
  if ui.names then
    ui.names:SetShown(M.Wanted("recent"))
  end
end

local function BuildInboxButtons()
  local inbox = _G.InboxFrame
  if ui.all or type(inbox) ~= "table" then
    return
  end
  local UI = ns.UI
  ui.all = UI.Button(inbox, 92, 24, L["Open all"])
  ui.all:SetPoint("BOTTOMRIGHT", inbox, "BOTTOM", -2, 14)
  ui.all:SetScript("OnClick", function()
    if M.run then
      M.StopOpenAll()
    else
      M.StartOpenAll("all")
    end
  end)
  Tip(ui.all, L["Open all (Codex)"], function()
    if M.run then
      return L["Stops taking mail."]
    end
    return L["Takes the gold and items from every mail, one after the other. Mails with Cash on Delivery and mails from a Game Master are left for you to open. With full bags the gold is still taken."]
  end)
  ui.gold = UI.Button(inbox, 92, 24, L["Gold only"])
  ui.gold:SetPoint("BOTTOMLEFT", inbox, "BOTTOM", 2, 14)
  ui.gold:SetScript("OnClick", function()
    M.StartOpenAll("gold")
  end)
  Tip(ui.gold, L["Gold only (Codex)"], L["Takes the gold from every mail and leaves the items in the mail."])
  ui.hidGame = false
  local game = GameOpenAll()
  if game and game.HookScript then
    -- the game shows it again when gamepad mode ends
    game:HookScript("OnShow", function(self)
      if M.Wanted("openAll") then
        self:Hide()
      end
    end)
  end
end

local function BuildNamesButton()
  local box = _G.SendMailNameEditBox
  if ui.names or type(box) ~= "table" then
    return
  end
  local button = CreateFrame("Button", "CodexMailNamesButton", box)
  button:SetSize(18, 18)
  button:SetPoint("RIGHT", box, "RIGHT", -2, 0)
  button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
  button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  button:SetScript("OnClick", function(self)
    ns.UI.ShowMenu(self, M.MenuItems())
  end)
  Tip(button, L["Recent names (Codex)"], L["The names you sent mail to on this realm, and your other characters here. Click one to put it in the To box."])
  if box.GetTextInsets and box.SetTextInsets then
    local left, right, top, bottom = box:GetTextInsets()
    box:SetTextInsets(left or 0, (right or 0) + 18, top or 0, bottom or 0)
  end
  ui.names = button
end

function M.BuildButtons()
  BuildInboxButtons()
  BuildNamesButton()
  M.RefreshButtons()
end

-- Events ---------------------------------------------------------------------------------------------------------

function M.Enable()
  M.DB()
  M.running = true
  M.RememberMe()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event, ...)
    if event == "MAIL_SHOW" then
      M.mailOpen = true
      M.BuildButtons()
    elseif event == "MAIL_CLOSED" then
      M.mailOpen = false
      if M.run then
        Finish("closed")
      end
      M.attach = nil
    elseif event == "MAIL_INBOX_UPDATE" then
      local run = M.run
      if run and run.waiting then
        run.waiting = false
        Schedule(run, STEP)
      end
    elseif event == "MAIL_FAILED" then
      local itemID = ...
      if M.run and type(itemID) == "number" then
        M.run.failed[itemID] = true
      end
    elseif event == "MAIL_SEND_SUCCESS" then
      if M.pendingTo and M.Wanted("recent") then
        M.AddRecent(M.pendingTo)
      end
      M.pendingTo = nil
    elseif event == "PLAYER_ENTERING_WORLD" then
      M.RememberMe() -- the realm name can be empty at login on Forever (Core.lua RealmName)
    end
  end)
  for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_FAILED", "MAIL_SEND_SUCCESS",
    "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(event)
  end
  if type(_G.SendMail) == "function" then
    hooksecurefunc("SendMail", function(recipient)
      M.pendingTo = Trim(recipient)
    end)
  end
  if type(_G.HandleModifiedItemClick) == "function" then
    hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick)
  end
end

function M.StatusText()
  if not M.running then
    return L["Off."]
  end
  if M.PostalLoaded() then
    return L["Postal is loaded: Codex leaves the mailbox to it."]
  end
  local db = M.DB()
  if not (db.openAll or db.recent or db.altAttach) then
    return L["Every part is switched off below."]
  end
  return L["On at the mailbox."]
end

ns.RegisterModule({
  id = "mail",
  name = L["Mail"],
  -- its section in the Codex window (Areas.lua): a tab of its own on the Trade page
  area = "trade", sectionOrder = 60, pageEstimate = 330,
  icon = "Interface\\Icons\\INV_Letter_15",
  desc = L["At the mailbox: open all your mail at once (or only the gold), pick a recent name or one of your characters for the To box, and Alt-click a bag item to attach every stack of it."],
  default = false,
  order = 97,
  Enable = function()
    M.Enable()
  end,
  BuildPage = function(_, page)
    M.BuildPage(page)
  end,
  ShowPage = function()
    if M.RefreshPage then
      M.RefreshPage()
    end
  end,
  Status = function()
    return M.StatusText()
  end,
})
