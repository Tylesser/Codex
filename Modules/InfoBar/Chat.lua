local addonName, ns = ...

-- Info bars, part 3: the chat panel's two corner buttons.
--   Hide chat: the chat windows, their tabs and side buttons fade out (alpha only: nothing is hidden, moved or
--   replaced) and come back with the same button. While you type the chat shows (the edit box is part of it).
--   Blizzard keeps setting tab alphas while it fades them: a post-hook on SetAlpha keeps them at 0 while hidden
--   and remembers Blizzard's value for later.
--   Copy chat: a Codex window with the selected chat window's recent lines as plain text (links, textures and
--   colour codes stripped, secret lines left out) in a box you can select and copy from.

local I = ns.infobar
local UI = ns.UI

local SIDE_BUTTONS = { "GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
  "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "TextToSpeechButton" }
local COPY_LINES = 300

-- Hide chat ------------------------------------------------------------------------------------------------------

local saved = {} -- [frame] = the alpha Blizzard gave it last (put back on show)
local hooked = {}
local quiet = false -- our own SetAlpha calls

local function ChatFrames()
  local list, seen = {}, {}
  local function Add(frame)
    if type(frame) == "table" and frame.SetAlpha and not seen[frame] then
      seen[frame] = true
      list[#list + 1] = frame
    end
  end
  for _, name in ipairs(type(CHAT_FRAMES) == "table" and CHAT_FRAMES or {}) do
    Add(_G[name])
  end
  for index = 1, (NUM_CHAT_WINDOWS or 10) do
    Add(_G["ChatFrame" .. index])
  end
  return list
end

-- Chat windows, their tabs and the side buttons.
local function Targets()
  local list = {}
  for _, frame in ipairs(ChatFrames()) do
    list[#list + 1] = frame
    local name = frame.GetName and frame:GetName()
    local tab = name and _G[name .. "Tab"]
    if type(tab) == "table" and tab.SetAlpha then
      list[#list + 1] = tab
    end
  end
  for _, name in ipairs(SIDE_BUTTONS) do
    local frame = _G[name]
    if type(frame) == "table" and frame.SetAlpha then
      list[#list + 1] = frame
    end
  end
  return list
end

local function Faded()
  return I.chatHidden and not I.chatPeek
end

local function SetAlpha(frame, alpha)
  quiet = true
  pcall(frame.SetAlpha, frame, alpha)
  quiet = false
end

local function Fade(frame)
  if not hooked[frame] then
    hooked[frame] = true
    hooksecurefunc(frame, "SetAlpha", function(self, alpha)
      if quiet or not Faded() then
        return
      end
      saved[self] = alpha
      SetAlpha(self, 0)
    end)
  end
  if saved[frame] == nil then
    saved[frame] = I.Num(frame:GetAlpha()) or 1
  end
  SetAlpha(frame, 0)
end

local function Unfade(frame)
  if saved[frame] ~= nil then
    SetAlpha(frame, saved[frame])
    saved[frame] = nil
  end
end

local function ApplyChat()
  if Faded() then
    for _, frame in ipairs(Targets()) do
      Fade(frame)
    end
  else
    for frame in pairs(saved) do
      Unfade(frame)
    end
  end
  local panel = I.Frames().panel
  if panel and panel.hide then
    panel.hide.icon:SetTexture("Interface\\AddOns\\Codex\\Modules\\InfoBar\\Media\\" .. (I.chatHidden and "Right" or "Left"))
  end
end
I.ApplyChat = ApplyChat

-- While typing the chat shows; it fades again when the edit box lets go.
local editHooked = {}
local function HookEditBoxes()
  for _, frame in ipairs(ChatFrames()) do
    local box = frame.editBox or (frame.GetName and _G[(frame:GetName() or "") .. "EditBox"])
    if type(box) == "table" and box.HookScript and not editHooked[box] then
      editHooked[box] = true
      box:HookScript("OnEditFocusGained", function()
        if I.chatHidden then
          I.chatPeek = true
          ApplyChat()
        end
      end)
      box:HookScript("OnEditFocusLost", function()
        if I.chatPeek then
          I.chatPeek = false
          ApplyChat()
        end
      end)
    end
  end
end

local tempHooked = false
function I.ToggleChat()
  I.chatHidden = not I.chatHidden
  I.chatPeek = false
  HookEditBoxes()
  if not tempHooked and type(_G.FCF_OpenTemporaryWindow) == "function" then
    tempHooked = true
    -- a whisper window opening while the chat is hidden fades with the rest
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      if Faded() then
        HookEditBoxes()
        ApplyChat()
      end
    end)
  end
  ApplyChat()
end

-- Copy chat ------------------------------------------------------------------------------------------------------

-- A chat line as plain text: textures and atlases dropped, links reduced to their text, colours removed.
function I.PlainText(text)
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
  text = text:gsub("|K.-|k", "?")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
  text = text:gsub("|n", " ")
  return text
end

local function SelectedChat()
  local frame = _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
  return type(frame) == "table" and frame or nil
end

-- The last `limit` readable lines of a chat window, oldest first.
function I.ChatLines(frame, limit)
  local lines = {}
  if not (frame and frame.GetNumMessages and frame.GetMessageInfo) then
    return lines
  end
  local count = I.Num(I.Ask(frame.GetNumMessages, frame)) or 0
  for index = math.max(1, count - (limit or COPY_LINES) + 1), count do
    local text = I.Ask(frame.GetMessageInfo, frame, index)
    if type(text) == "string" and I.Readable(text) then
      local ok, plain = pcall(I.PlainText, text)
      if ok and plain ~= "" then
        lines[#lines + 1] = plain
      end
    end
  end
  return lines
end

local copy

local function ChatName(frame)
  local id = frame.GetID and I.Num(frame:GetID())
  local name = id and I.Str(I.Ask(GetChatWindowInfo, id))
  return name or "Chat"
end

local function CreateCopy()
  copy = UI.Ink(CreateFrame("Frame", "CodexChatCopy", UIParent)) -- next to the chat: the HUD's surfaces
  copy:SetSize(600, 400)
  copy:SetPoint("CENTER")
  copy:SetFrameStrata("DIALOG")
  copy:SetClampedToScreen(true)
  copy:EnableMouse(true)
  copy:SetMovable(true)
  copy:RegisterForDrag("LeftButton")
  copy:SetScript("OnDragStart", copy.StartMoving)
  copy:SetScript("OnDragStop", copy.StopMovingOrSizing)
  UI.Panel(copy)
  local heading = UI.Heading(copy, "Copy chat", 16)
  heading:SetPoint("TOPLEFT", 18, -16)
  copy.sub = UI.Text(copy, "body", 12, "muted")
  copy.sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  copy.sub:SetPoint("RIGHT", -50, 0)
  local close = UI.CloseButton(copy)
  close:SetPoint("TOPRIGHT", -12, -12)

  local area = UI.Inset(copy)
  area:SetPoint("TOPLEFT", 16, -60)
  area:SetPoint("BOTTOMRIGHT", -16, 16)
  -- the edit box is the scroll child itself: one frame further down it drew no text on Forever (UI.ScrollArea)
  local scroll, box = UI.ScrollArea(area, "EditBox")
  scroll:SetPoint("TOPLEFT", 8, -6)
  scroll:SetPoint("BOTTOMRIGHT", -6, 6)
  copy.scroll, copy.body = scroll, box
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetMaxLetters(0)
  UI.Font(box, "body", 13, "text")
  box:SetScript("OnEscapePressed", function()
    copy:Hide()
  end)
  -- read only: typing puts the text back
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(copy.text or "")
    end
  end)
  -- (a multi-line edit box grows with its text; the scroll area's own OnSizeChanged updates its thumb)
  copy.box = box
  table.insert(UISpecialFrames, "CodexChatCopy")
end

function I.ShowCopy()
  local frame = SelectedChat()
  if not copy then
    CreateCopy()
  end
  local lines = frame and I.ChatLines(frame, COPY_LINES) or {}
  copy.text = table.concat(lines, "\n")
  copy.sub:SetText(("%s, the last %d line%s. Select what you want and copy it with Ctrl+C.")
    :format(frame and ChatName(frame) or "Chat", #lines, #lines == 1 and "" or "s"))
  copy:Show()
  -- the scroll area's width is 0 until the game has laid the window out (the first open showed an empty box:
  -- a negative width, 2026-11-20): then the width the window's size gives (600 - insets)
  local measured = I.Num(copy.scroll:GetWidth())
  local width = (measured and measured > 100 and measured or 546) - 10
  copy.box:SetWidth(width)
  copy.box:SetText(copy.text)
  copy.box:SetFocus()
  copy.box:HighlightText()
  -- to the newest lines once the box has its height
  C_Timer.After(0, function()
    local laidOut = I.Num(copy.scroll:GetWidth())
    if laidOut and laidOut > 100 then
      copy.box:SetWidth(laidOut - 10)
    end
    pcall(copy.scroll.UpdateScrollChildRect, copy.scroll)
    copy.scroll:SetVerticalScroll(math.max(0, (I.Num(copy.box:GetHeight()) or 0) - (I.Num(copy.scroll:GetHeight()) or 0)))
    copy.scroll:Update()
  end)
end
