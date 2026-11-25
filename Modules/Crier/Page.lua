local addonName, ns = ...

-- Trade Crier's section on the Chat page: the message with its link buttons and preview, the timing, the channel,
-- the checks, the post key. The same choices as the standalone's options page (TradeCrier/Options.lua).

local C = ns.crier
local UI = ns.UI

local view
local INSERT_INDENT = 96 -- the insert buttons start right of "Put in a link:"

local function Refresh()
  if not view then
    return
  end
  local settings, char = C.Settings(), C.Char()
  local theme = ns.Theme()
  if not view.message:HasFocus() and view.message:GetText() ~= char.message then
    view.message:SetText(char.message)
  end
  local text, unknown = C.Expand(char.message)
  view.preview:SetText(text ~= "" and text or "(nothing yet)")
  view.count:SetText(("%d / %d"):format(#text, C.MAX_LENGTH))
  view.count:SetTextColor(UI.Unpack(#text > C.MAX_LENGTH and theme.bad or theme.muted))
  view.unknown:SetText(#unknown > 0 and (table.concat(unknown, ", ") .. " matched none of your professions.") or "")
  view.status:SetText(C.started and C.StatusText() or "Switch Trade Crier on to see the button.")
  view.interval.value:SetText(settings.interval .. " min")
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
end
C.RefreshPage = Refresh

local function Wrapped(parent, size, color, width)
  local text = UI.Text(parent, "body", size, color)
  text:SetWidth(width)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  return text
end

function C.BuildPage(page)
  view = {}
  C.view = view
  local width = ns.PAGE_WIDTH or 620
  view.width = width
  local heading = UI.Heading(page, "Trade Crier", 20)
  heading:SetPoint("TOPLEFT")

  local messageLabel = UI.Text(page, "body", 13, "bright")
  messageLabel:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
  messageLabel:SetText("Your message")
  local box = UI.EditBox(page, width, 24)
  box:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 0, -6)
  box:SetMaxLetters(C.MAX_LENGTH)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      C.Char().message = self:GetText()
      Refresh()
      C.Refresh()
    end
  end)
  view.message = box
  C.WatchLinks(function()
    return view and view.message
  end)

  view.insertRow = CreateFrame("Frame", nil, page)
  view.insertRow:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
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
      box:SetFocus()
      box:Insert(self.word)
    end)
    view.inserts[index] = button
  end
  view.insertAll = UI.Button(page, 116, 22, "All professions")
  view.insertAll:SetScript("OnClick", function()
    box:SetFocus()
    box:Insert("<professions>")
  end)
  local hint = Wrapped(page, 11, "muted", width)
  hint:SetPoint("TOPLEFT", view.insertRow, "BOTTOMLEFT", 0, -12)
  hint:SetText("<Tailoring> becomes your Tailoring link when it is posted, <professions> all of them. Professions you "
    .. "gather with (and Fishing) have no link. Shift-click an item or a recipe while the box has the cursor to put its "
    .. "link in.")

  local previewLabel = UI.Text(page, "body", 13, "bright")
  previewLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  previewLabel:SetText("In chat it reads")
  view.count = UI.Text(page, "body", 11, "muted")
  view.count:SetPoint("LEFT", previewLabel, "RIGHT", 10, 0)
  view.preview = Wrapped(page, 12, "text", width)
  view.preview:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -6)
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
  postNote:SetText("The game sends a Trade chat message only when you click or press a key, so the button by your "
    .. "character lights up when it's time and you post with one click.")

  local every = UI.Text(page, "body", 13, "text")
  every:SetPoint("TOPLEFT", post, "BOTTOMLEFT", 0, -22)
  every:SetText("Post every")
  view.interval = UI.Stepper(page, 60)
  view.interval:SetPoint("LEFT", every, "RIGHT", 10, 0)
  local function Step(direction)
    local settings = C.Settings()
    local at = 1
    for index, minutes in ipairs(C.INTERVALS) do
      if minutes <= settings.interval then
        at = index
      end
    end
    settings.interval = C.INTERVALS[math.max(1, math.min(#C.INTERVALS, at + direction))]
    Refresh()
    C.Refresh()
  end
  view.interval.less:SetScript("OnClick", function() Step(-1) end)
  view.interval.more:SetScript("OnClick", function() Step(1) end)
  local channelLabel = UI.Text(page, "body", 13, "text")
  channelLabel:SetPoint("LEFT", view.interval, "RIGHT", 30, 0)
  channelLabel:SetText("Channel")
  view.channel = UI.Picker(page, 150, 24)
  view.channel:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
  view.channel:SetScript("OnClick", function(self)
    local items = {}
    for _, def in ipairs(C.CHANNELS) do
      items[#items + 1] = { text = def.name, checked = C.Settings().channel == def.key, func = function()
        C.Settings().channel = def.key
        Refresh()
        C.Refresh()
      end }
    end
    UI.ShowMenu(self, items)
  end)

  view.checks = {}
  local anchor = every
  for index, option in ipairs({
    { "paused", "Pause on this character", true },
    { "sound", "Play a sound when it's time to post" },
    { "remind", "Say in chat when it's time to post" },
    { "onlyCities", "Only show the button in cities" },
    { "locked", "Lock the button in place" },
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
      Refresh()
      C.Refresh()
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  local column = 330
  local keyLabel = UI.Text(page, "body", 13, "text")
  keyLabel:SetPoint("TOPLEFT", every, "BOTTOMLEFT", column, -16)
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
  local reset = UI.Button(page, 160, 24, "Put the button back")
  reset:SetPoint("TOPLEFT", keyHint, "BOTTOMLEFT", 0, -12)
  reset:SetScript("OnClick", C.ResetPlace)

  C.OnRefresh = function()
    if view.message:IsVisible() then
      Refresh()
    end
  end
  Refresh()
end
