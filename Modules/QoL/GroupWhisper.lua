local addonName, ns = ...

-- Whisper group leaders (2026-11-27, the user's wish): a "Whisper" button on every group in the game's Looking For
-- Group window that sends the leader the message written on the Chat page, in one click.
--
-- Forever's window is Blizzard_GroupFinder_VanillaStyle (load on demand; [Family] = Mainline for camelot). Each row
-- is a LFGBrowseSearchEntryTemplate button; the global LFGBrowseSearchEntry_Update(self) draws it from
-- self.resultID (forever Blizzard_LFGVanilla_Browse.lua), so a hook there adds and updates the button. The leader's
-- name is C_LFGList.GetSearchResultInfo(resultID).leaderName, as Blizzard's own "Send Message" button uses it.
-- That function is SecretInChatMessagingLockdown and SendChatMessage HasRestrictions (a click is needed; forever
-- LFGListInfoDocumentation / ChatInfoDocumentation): the message is only sent from the button's click, and never
-- with a secret name. Solo players, delisted groups and your own listing get no button.

local Q = ns.qol
local UI = ns.UI

local KEY = "lfgWhisper"
local TEXT_KEY = "lfgWhisperText"
local AGAIN = 120 -- seconds before the same leader can be whispered again

local buttons = setmetatable({}, { __mode = "k" }) -- (Blizzard's row -> our button; nothing written on their frames)
local sent = {} -- leader name -> GetTime() of the whisper

local function Secret(value)
  return issecretvalue and issecretvalue(value) or false
end

local function Message()
  local text = Q.DB()[TEXT_KEY]
  if type(text) ~= "string" then
    return nil
  end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text ~= "" and text or nil
end

-- The leader of a row's group, or nil (solo player, delisted, your own, unknown or secret).
local function Leader(resultID)
  if not (resultID and C_LFGList and C_LFGList.GetSearchResultInfo) then
    return nil
  end
  local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
  if not ok or type(info) ~= "table" then
    return nil
  end
  local name = info.leaderName
  if name == nil or Secret(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  if info.isDelisted or info.hasSelf or (info.numMembers or 0) < 2 then
    return nil
  end
  return name
end

local function RecentlySent(name)
  local when = sent[name]
  return when and GetTime() - when < AGAIN
end

local function UpdateButton(button)
  local leader = Leader(button.resultID)
  if not Q.On(KEY) or not leader then
    button:Hide()
    return
  end
  button.leader = leader
  local done = RecentlySent(leader)
  button:SetText(done and "Sent" or "Whisper")
  button:SetEnabled(not done)
  button:Show()
end

-- Sends the message to the row's leader (from the click only).
function Q.WhisperLeader(button)
  local text = Message()
  if not text then
    ns.Say("Write your message first: Chat page, \"Whisper group leaders\".")
    ns.ShowPage("qol-" .. KEY)
    return false
  end
  local leader = Leader(button.resultID)
  if not leader then
    ns.Say("This group's leader can't be whispered right now.")
    return false
  end
  if RecentlySent(leader) then
    return false -- (a second click before the button greyed out)
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send then
    return false
  end
  send(text, "WHISPER", nil, leader)
  sent[leader] = GetTime()
  UpdateButton(button)
  if C_Timer and C_Timer.After then
    C_Timer.After(AGAIN + 1, function()
      if button.resultID then
        UpdateButton(button)
      end
    end)
  end
  return true
end

local function Decorate(entry)
  if type(entry) ~= "table" then
    return
  end
  local button = buttons[entry]
  if not button then
    if not Q.On(KEY) then
      return
    end
    button = UI.Button(entry, 62, 16, "Whisper")
    button:SetPoint("BOTTOMRIGHT", -8, 3)
    button:SetFrameLevel(entry:GetFrameLevel() + 5)
    button:SetScript("OnClick", function(self)
      Q.WhisperLeader(self)
    end)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Whisper the leader")
      GameTooltip:AddLine(Message() and ("Sends " .. (self.leader or "the leader") .. ": " .. Message())
        or "Write your message on the Chat page first (Whisper group leaders).", 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    buttons[entry] = button
  end
  button.resultID = entry.resultID
  UpdateButton(button)
end
Q.DecorateGroupEntry = Decorate

local hooked = false
local function Hook()
  if hooked or type(LFGBrowseSearchEntry_Update) ~= "function" then
    return
  end
  hooked = true
  hooksecurefunc("LFGBrowseSearchEntry_Update", Decorate)
end

local function RefreshAll()
  for entry in pairs(buttons) do
    Decorate(entry)
  end
end

local function Enable()
  Hook()
  if not hooked then
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(self, _, name)
      if name == "Blizzard_GroupFinder_VanillaStyle" then
        Hook()
        if hooked then
          self:UnregisterEvent("ADDON_LOADED")
        end
      end
    end)
  end
end

-- The message box on the Chat page.
local function BuildMessage(body, last, sub)
  local holder = CreateFrame("Frame", nil, body)
  holder:SetHeight(24)
  holder:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)
  holder:SetPoint("RIGHT", 0, 0)
  sub.holder = holder
  sub.label = UI.Text(holder, "body", 12, "text")
  sub.label:SetPoint("LEFT", 0, 0)
  sub.label:SetText("Message")
  local box = UI.EditBox(holder, 300, 22)
  box:SetPoint("LEFT", 80, 0)
  box:SetPoint("RIGHT", 0, 0)
  box:SetMaxLetters(255)
  box:SetScript("OnTextChanged", function(self, typed)
    if typed then
      Q.DB()[TEXT_KEY] = self:GetText()
      RefreshAll()
    end
  end)
  sub.box = box
  sub.status = UI.Text(body, "body", 11, "muted")
  sub.status:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -6)
  sub.status:SetPoint("RIGHT", 0, 0)
  sub.status:SetJustifyH("LEFT")
  return sub.status
end

local function RefreshMessage(sub, on)
  if not sub.box:HasFocus() then
    sub.box:SetText(Q.DB()[TEXT_KEY] or "")
  end
  sub.box:SetEnabled(on)
  sub.box:SetAlpha(on and 1 or 0.5)
  if not on then
    sub.status:SetText("")
  elseif Message() then
    sub.status:SetText("Each group in the Looking For Group window has a Whisper button that sends this to its leader.")
  else
    sub.status:SetText("Write the message the Whisper button sends, e.g. \"Hi, 60 mage LF Scholo, can I join?\"")
  end
end

Q.AddToggle({
  key = KEY,
  name = "Whisper group leaders",
  desc = "A Whisper button on every group in the Looking For Group window: one click sends the group's leader "
    .. "your message. The same leader can be whispered again after two minutes.",
  default = true,
  order = 75,
  Enable = Enable,
  Changed = function(on)
    if on then
      Hook()
    end
    RefreshAll()
  end,
  options = {
    { key = TEXT_KEY, kind = "custom", default = "", Build = BuildMessage, Refresh = RefreshMessage },
  },
})
