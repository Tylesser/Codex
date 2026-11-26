local addonName, ns = ...

-- Trade Crier's section on the Chat page: the messages (each with its own time in seconds), the link buttons and the
-- preview of the message being edited, the channel, the checks, the post key. The same choices as the standalone's
-- options page (TradeCrier/Options.lua).

local C = ns.crier
local UI = ns.UI

local view
local INSERT_INDENT = 96 -- the insert buttons start right of "Put in a link:"
local ROW = 30 -- one message row

local function Wrapped(parent, size, color, width)
  local text = UI.Text(parent, "body", size, color)
  text:SetWidth(width)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  return text
end

-- A row's state on its right: when it goes next, or why it doesn't.
local function RowState(message)
  local state = C.MessageState(message)
  if state == "empty" then
    return "", "muted"
  elseif state == "off" then
    return "off", "muted"
  elseif state == "long" then
    return "too long", "bad"
  end
  local wait = C.WaitFor(message)
  if wait > 0 then
    return "in " .. C.Clock(wait), "muted"
  end
  return "ready", "accent"
end

local function Refresh()
  if not view then
    return
  end
  local settings, char = C.Settings(), C.Char()
  local theme = ns.Theme()
  local messages = C.Messages()
  if not messages[view.active] then
    view.active = 1
  end
  local relayout = view.shownRows ~= #messages
  view.shownRows = #messages
  for index, row in ipairs(view.rows) do
    local message = messages[index]
    row:SetShown(message ~= nil)
    if message then
      if not row.box:HasFocus() and row.box:GetText() ~= message.text then
        row.box:SetText(message.text)
      end
      if not row.every:HasFocus() then
        row.every:SetText(tostring(message.every))
      end
      row.on:SetChecked(not message.off)
      row.pick.icon:SetTexture(C.MessageIcon(message))
      row.pick.icon:SetDesaturated(message.off and true or false)
      local text, color = RowState(message)
      row.state:SetText(text)
      row.state:SetTextColor(UI.Unpack(theme[color] or theme.muted))
      row.number:SetTextColor(UI.Unpack(index == view.active and theme.accent or theme.muted))
    end
  end
  view.rowHolder:SetHeight(#messages * ROW)
  view.add:SetShown(#messages < C.MAX_MESSAGES)

  local _, text, unknown = C.MessageState(messages[view.active])
  view.previewLabel:SetText(#messages > 1 and ("Message %d in chat reads"):format(view.active) or "In chat it reads")
  view.preview:SetText(text ~= "" and text or "(nothing yet)")
  view.count:SetText(("%d / %d"):format(#text, C.MAX_LENGTH))
  view.count:SetTextColor(UI.Unpack(#text > C.MAX_LENGTH and theme.bad or theme.muted))
  view.unknown:SetText(#unknown > 0 and (table.concat(unknown, ", ") .. " matched none of your professions.") or "")
  view.status:SetText(C.started and C.StatusText() or "Switch Trade Crier on to see the button.")
  view.channel:SetText(C.ChannelDef(settings.channel).name)
  for _, check in ipairs(view.checks) do
    check:SetChecked((check.char and char or settings)[check.key] and true or false)
  end
  view.key:SetText(view.capturing and "Press a key" or (settings.key or "Not set"))
  -- one insert button per profession that has a link, in rows that fit the page
  local professions = C.Linkable()
  for index, button in ipairs(view.inserts) do
    local profession = professions[index]
    button:SetShown(profession ~= nil)
    if profession then
      button.word = "<" .. profession.name .. ">"
      button:SetText(profession.name)
    end
  end
  view.insertAll:SetShown(#professions > 1)
  view.noProfessions:SetShown(#professions == 0)
  local buttons = {}
  for _, button in ipairs(view.inserts) do
    buttons[#buttons + 1] = button
  end
  buttons[#buttons + 1] = view.insertAll
  C.FlowButtons(view.insertRow, buttons, view.width, INSERT_INDENT, 6, 22)
  -- a row more or less: the section's height changes
  if relayout and view.built and not view.relayingOut and type(ns.RefreshSections) == "function" then
    view.relayingOut = true
    pcall(ns.RefreshSections)
    view.relayingOut = false
  end
end
C.RefreshPage = Refresh

local function Changed()
  Refresh()
  C.Refresh()
end

-- One message row: on/off, the text, its seconds, when it goes next, remove.
local function MessageRow(parent, index, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, ROW)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW)
  row.index = index
  row.number = UI.Text(row, "body", 12, "muted")
  row.number:SetPoint("LEFT", 0, 0)
  row.number:SetWidth(14)
  row.number:SetText(tostring(index))
  row.on = UI.Check(row)
  row.on:SetPoint("LEFT", 16, 0)
  row.on:SetHitRectInsets(0, 0, 0, 0)
  row.on:SetScript("OnClick", function(self)
    local message = C.Messages()[index]
    if message then
      message.off = not self:GetChecked() or nil
      Changed()
    end
  end)
  row.remove = UI.Button(row, 22, 22, "x")
  row.remove:SetPoint("RIGHT", 0, 0)
  row.remove:SetScript("OnClick", function()
    row.box:ClearFocus()
    C.RemoveMessage(index)
    Changed()
  end)
  row.state = UI.Text(row, "body", 11, "muted")
  row.state:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
  row.state:SetWidth(62)
  row.state:SetJustifyH("LEFT")
  local unit = UI.Text(row, "body", 12, "muted")
  unit:SetPoint("RIGHT", row.state, "LEFT", -8, 0)
  unit:SetText("s")
  row.every = UI.EditBox(row, 56, 24)
  row.every:SetPoint("RIGHT", unit, "LEFT", -4, 0)
  row.every:SetNumeric(true)
  row.every:SetMaxLetters(5)
  row.every:SetJustifyH("CENTER")
  row.every:SetScript("OnTextChanged", function(self, userInput)
    local message = C.Messages()[index]
    local seconds = tonumber(self:GetText())
    -- while typing ("3" on the way to "300") only a number that is already allowed is kept
    if userInput and message and seconds and seconds >= C.MIN_EVERY then
      message.every = C.ClampEvery(seconds)
      Refresh()
      C.Refresh()
    end
  end)
  row.every:SetScript("OnEditFocusLost", function(self)
    local message = C.Messages()[index]
    if message then
      message.every = C.ClampEvery(tonumber(self:GetText()) or message.every)
      self:SetText(tostring(message.every))
      Changed()
    end
  end)
  local every = UI.Text(row, "body", 12, "muted")
  every:SetPoint("RIGHT", row.every, "LEFT", -6, 0)
  every:SetText("every")
  row.box = UI.EditBox(row, 100, 24)
  -- its icon (the button shows the icon of the message that goes next): picked, or its profession's
  row.pick = CreateFrame("Button", nil, row)
  row.pick:SetSize(22, 22)
  row.pick:SetPoint("LEFT", row.on, "RIGHT", 4, 0)
  row.pick.icon = row.pick:CreateTexture(nil, "ARTWORK")
  row.pick.icon:SetAllPoints()
  row.pick.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local pickHover = row.pick:CreateTexture(nil, "HIGHLIGHT")
  pickHover:SetAllPoints()
  pickHover:SetColorTexture(1, 1, 1, 0.2)
  row.pick:SetScript("OnClick", function(self)
    C.ShowIconPicker(self, index, Refresh)
  end)
  row.box:SetPoint("LEFT", row.pick, "RIGHT", 8, 0)
  row.box:SetPoint("RIGHT", every, "LEFT", -8, 0)
  row.box:SetMaxLetters(C.MAX_LENGTH)
  row.box:SetScript("OnTextChanged", function(self, userInput)
    local message = C.Messages()[index]
    if userInput and message then
      message.text = self:GetText()
      view.active = index
      Changed()
    end
  end)
  row.box:SetScript("OnEditFocusGained", function()
    if view.active ~= index then
      view.active = index
      Refresh()
    end
  end)
  C.WatchLinks(function()
    return row:IsShown() and row.box or nil
  end)
  return row
end

function C.BuildPage(page)
  view = { active = 1 }
  C.view = view
  local width = ns.PAGE_WIDTH or 620
  view.width = width
  local heading = UI.Heading(page, "Trade Crier", 20)
  heading:SetPoint("TOPLEFT")

  local messageLabel = UI.Text(page, "body", 13, "bright")
  messageLabel:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
  messageLabel:SetText("Your messages")
  local messageHint = Wrapped(page, 11, "muted", width)
  messageHint:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 0, -4)
  messageHint:SetText(("Each message has its own button by your character, with its icon, its own countdown and "
    .. "its own time in seconds (%d at least): it lights up when that message is ready, and a click posts it. The "
    .. "post key posts the one that has waited longest. Click an icon here to pick another; until you do, a message "
    .. "shows the profession it links. Untick a message to keep it without posting it."):format(C.MIN_EVERY))
  view.rowHolder = CreateFrame("Frame", nil, page)
  view.rowHolder:SetPoint("TOPLEFT", messageHint, "BOTTOMLEFT", 0, -6)
  view.rowHolder:SetSize(width, ROW)
  view.rows = {}
  for index = 1, C.MAX_MESSAGES do
    view.rows[index] = MessageRow(view.rowHolder, index, width)
  end
  -- the first box is the one the pages and the tests know as the message box
  view.message = view.rows[1].box
  view.add = UI.Button(page, 140, 22, "Add a message")
  view.add:SetPoint("TOPLEFT", view.rowHolder, "BOTTOMLEFT", 0, -4)
  view.add:SetScript("OnClick", function()
    local index = C.AddMessage()
    if index then
      view.active = index
      Changed()
      view.rows[index].box:SetFocus()
    end
  end)

  local function ActiveBox()
    local row = view.rows[view.active] or view.rows[1]
    return row.box
  end
  view.insertRow = CreateFrame("Frame", nil, page)
  view.insertRow:SetPoint("TOPLEFT", view.add, "BOTTOMLEFT", 0, -12)
  view.insertRow:SetSize(width, 22)
  view.insertLabel = UI.Text(view.insertRow, "body", 12, "muted")
  view.insertLabel:SetPoint("TOPLEFT", 0, -4)
  view.insertLabel:SetText("Put in a link:")
  view.noProfessions = UI.Text(view.insertRow, "body", 12, "muted")
  view.noProfessions:SetPoint("TOPLEFT", INSERT_INDENT, -4)
  view.noProfessions:SetText("(none of your professions has a link yet)")
  view.inserts = {}
  for index = 1, 6 do
    local button = UI.Button(page, 96, 22, "")
    button:SetScript("OnClick", function(self)
      local box = ActiveBox()
      box:SetFocus()
      box:Insert(self.word)
    end)
    view.inserts[index] = button
  end
  view.insertAll = UI.Button(page, 116, 22, "All professions")
  view.insertAll:SetScript("OnClick", function()
    local box = ActiveBox()
    box:SetFocus()
    box:Insert("<professions>")
  end)
  local hint = Wrapped(page, 11, "muted", width)
  hint:SetPoint("TOPLEFT", view.insertRow, "BOTTOMLEFT", 0, -12)
  hint:SetText("<Tailoring> becomes your Tailoring link when it is posted, <professions> all of them. Professions you "
    .. "gather with (and Fishing) have no link. The buttons put the link into the message you last clicked; "
    .. "shift-click an item or a recipe while a box has the cursor to put its link in.")

  view.previewLabel = UI.Text(page, "body", 13, "bright")
  view.previewLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  view.previewLabel:SetText("In chat it reads")
  view.count = UI.Text(page, "body", 11, "muted")
  view.count:SetPoint("LEFT", view.previewLabel, "RIGHT", 10, 0)
  view.preview = Wrapped(page, 12, "text", width)
  view.preview:SetPoint("TOPLEFT", view.previewLabel, "BOTTOMLEFT", 0, -6)
  view.unknown = Wrapped(page, 11, "warn", width)
  view.unknown:SetPoint("TOPLEFT", view.preview, "BOTTOMLEFT", 0, -4)

  view.status = Wrapped(page, 12, "accent", width)
  view.status:SetPoint("TOPLEFT", view.unknown, "BOTTOMLEFT", 0, -12)
  local post = UI.Button(page, 110, 24, "Post now")
  post:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -8)
  post:SetScript("OnClick", function()
    if C.started then
      C.Post()
    else
      C.Say("Switch Trade Crier on first (its switch above).")
    end
    Refresh()
  end)
  local postNote = Wrapped(page, 11, "muted", width - 124)
  postNote:SetPoint("LEFT", post, "RIGHT", 12, 0)
  postNote:SetText("The game sends a Trade chat message only when you click or press a key, so a message's button "
    .. "by your character lights up when it's ready and you post it with one click. Post now sends the one that has "
    .. "waited longest.")

  local channelLabel = UI.Text(page, "body", 13, "text")
  channelLabel:SetPoint("TOPLEFT", post, "BOTTOMLEFT", 0, -22)
  channelLabel:SetText("Channel")
  view.channel = UI.Picker(page, 150, 24)
  view.channel:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
  view.channel:SetScript("OnClick", function(self)
    local items = {}
    for _, def in ipairs(C.CHANNELS) do
      items[#items + 1] = { text = def.name, checked = C.Settings().channel == def.key, func = function()
        C.Settings().channel = def.key
        Changed()
      end }
    end
    UI.ShowMenu(self, items)
  end)

  view.checks = {}
  local anchor = channelLabel
  for index, option in ipairs({
    { "paused", "Pause on this character", true },
    { "sound", "Play a sound when it's time to post" },
    { "remind", "Say in chat when it's time to post" },
    { "onlyCities", "Only show the button in cities" },
    { "locked", "Lock the buttons in place" },
    { "column", "Stack the buttons in a column" },
  }) do
    local check = UI.Check(page, option[2])
    check.key, check.char = option[1], option[3]
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, index == 1 and -14 or -6)
    check:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if self.char then
        C.Char()[self.key] = on
      else
        C.Settings()[self.key] = on
      end
      Changed()
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  local column = 330
  local keyLabel = UI.Text(page, "body", 13, "text")
  keyLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", column, -16)
  keyLabel:SetText("Post key")
  view.key = UI.Button(page, 110, 24, "")
  view.key:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)
  view.key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  view.key:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      view.capturing = false
      self:EnableKeyboard(false)
      C.SetKey(nil)
    else
      view.capturing = not view.capturing
      self:EnableKeyboard(view.capturing)
    end
    Refresh()
  end)
  view.key:SetScript("OnKeyDown", function(self, key)
    if not view.capturing then
      return
    end
    local name = C.KeyName(key)
    if name == nil then
      return
    end
    view.capturing = false
    self:EnableKeyboard(false)
    local before = C.SetKey(name or nil)
    if before then
      C.Say(("%s did \"%s\"; while it posts, that comes back when you clear it here."):format(name, before))
    end
    Refresh()
  end)
  local keyHint = Wrapped(page, 11, "muted", width - column)
  keyHint:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -10)
  keyHint:SetText("Click, then press a key. Escape or right-click clears it.")
  local reset = UI.Button(page, 160, 24, "Put the buttons back")
  reset:SetPoint("TOPLEFT", keyHint, "BOTTOMLEFT", 0, -12)
  reset:SetScript("OnClick", C.ResetPlace)

  C.OnRefresh = function()
    if view.message:IsVisible() then
      Refresh()
    end
  end
  Refresh()
  view.built = true
end
