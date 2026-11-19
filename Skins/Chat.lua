local addonName, ns = ...
local S = ns.S

-- Chat: every chat window (new, whisper and temporary windows too) gets the design's HUD box instead of
-- Blizzard's background, border and button-bar art. The box follows the window's own opacity setting and
-- Blizzard's fade in on mouse-over / out after (it copies the alpha Blizzard gives its own, now empty,
-- background): fully drawn at the default opacity and above, fainter below, gone at 0 until moused over.
-- Tabs sit above as in the design: the selected one in the title bar gradient with accent text (always fully
-- drawn, so it stays readable), the others on the HUD fill with muted text; Blizzard's unread glow is turned
-- into an accent glow; whisper tabs keep the whisper colour. The edit box is a 26-unit HUD bar of its own under
-- the window, its channel header in Blizzard's colours ("Say:" white, as on the board). Chat text takes the theme's body font only where the theme has one, at
-- the player's own size. The side buttons get the theme's button line. Everything is a post-hook: no FCF
-- function is ever called and AddMessage / Hide are never replaced.

local BACKGROUND = { "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
  "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }
local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft",
  "HighlightMiddle", "HighlightRight", "SelectedLeft", "SelectedMiddle", "SelectedRight" }
local EDIT_ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
-- (The friends button, QuickJoinToastButton, keeps its own look: its icon and online count read badly in a box.)
local SIDE_BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "TextToSpeechButton",
  "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }

local tabs = {} -- [tab] = { fill, selected = gradient texture, isSelected }
local windows = {} -- [chat frame] = { plate, edit = edit box plate, editBox, alpha }
local editOwner = {} -- [edit box] = chat frame

local function ChatFrames()
  local list, seen = {}, {}
  local function Add(frame)
    if frame and not seen[frame] then
      seen[frame] = true
      list[#list + 1] = frame
    end
  end
  for _, name in ipairs(type(CHAT_FRAMES) == "table" and CHAT_FRAMES or {}) do
    Add(S.Get(name))
  end
  for index = 1, (NUM_CHAT_WINDOWS or 10) do
    Add(S.Get("ChatFrame" .. index))
  end
  return list
end

local function Number(value)
  return type(value) == "number" and (not canaccessvalue or canaccessvalue(value)) and value or nil
end

-- Opacity --------------------------------------------------------------------------------------------------

-- lines: alpha of the rings; fill: alpha of the box (nil = the same)
local function PlateAlpha(plate, alpha, fill)
  if not plate then
    return
  end
  plate.fill:SetAlpha(fill or alpha)
  if plate.tile then
    plate.tile:SetAlpha(fill or alpha)
  end
  for _, piece in ipairs(plate.round or {}) do
    piece:SetAlpha(fill or alpha)
  end
  for _, line in ipairs(plate.lines) do
    line:SetAlpha(alpha)
  end
end

local function EditAlpha(window)
  local box = window.editBox
  local focused = box and box.HasFocus and box:HasFocus()
  PlateAlpha(window.edit, focused and 1 or window.alpha, not focused and window.fill or nil)
end

-- Blizzard's background alpha (the window's opacity, faded in and out) -> our box. The box is as dark as
-- Blizzard's own background would be (a window at the default 25% stays a light shade, not a solid box);
-- the rings are full from DEFAULT_CHATFRAME_ALPHA (0.25) up and fade out below it.
local function FollowAlpha(frame, alpha)
  local window = windows[frame]
  alpha = Number(alpha)
  if not window or not alpha then
    return
  end
  local full = Number(DEFAULT_CHATFRAME_ALPHA) or 0.25
  window.alpha = math.max(0, math.min(1, full > 0 and alpha / full or alpha))
  local hudAlpha = S.Theme().hud.fill[4] or 1
  window.fill = math.max(0, math.min(1, hudAlpha > 0 and alpha / hudAlpha or alpha))
  PlateAlpha(window.plate, window.alpha, window.fill)
  EditAlpha(window)
end

-- Tabs -----------------------------------------------------------------------------------------------------

local function TabText(tab)
  local text = tab.GetFontString and tab:GetFontString()
  return S.IsRegion(text) and text or S.Region(tab, "Text") or (S.Name(tab) and S.Get(S.Name(tab) .. "Text"))
end

local function FrameOfTab(tab)
  local name = S.Name(tab)
  return name and S.Get((name:gsub("Tab$", "")))
end

-- Is this tab's window the one shown? Read from Blizzard's state, never set.
local function IsSelected(tab)
  local frame = FrameOfTab(tab)
  if not frame then
    return false
  end
  local dock = type(GENERAL_CHAT_DOCK) == "table" and GENERAL_CHAT_DOCK or nil
  if dock then
    if frame.isDocked then
      return dock.selected == frame
    end
    return true -- an undocked window's own tab
  end
  return type(SELECTED_CHAT_FRAME) == "table" and SELECTED_CHAT_FRAME == frame
end

-- R2-HUD: a whisper window's tab name is in the whisper colour (pink), whatever its state.
local WHISPERS = { WHISPER = true, BN_WHISPER = true }
local function WhisperColor(tab)
  local frame = FrameOfTab(tab)
  local chatType = frame and frame.chatType
  if type(chatType) ~= "string" or not WHISPERS[chatType] then
    return nil
  end
  local info = type(ChatTypeInfo) == "table" and ChatTypeInfo[chatType]
  if type(info) == "table" and Number(info.r) and Number(info.g) and Number(info.b) then
    return { info.r, info.g, info.b }
  end
  return { 1, 0.5, 1 }
end

local tabAlphaGuard = false
local function TabColors(tab, selected)
  local look = tabs[tab]
  if not look then
    return
  end
  if selected == nil then
    selected = IsSelected(tab)
  end
  look.isSelected = selected and true or false
  look.selected:SetShown(look.isSelected)
  local text = TabText(tab)
  if text then
    S.Font(text, "body", WhisperColor(tab) or (look.isSelected and "accent" or "muted"))
  end
  if look.isSelected and tab.GetAlpha and (Number(tab:GetAlpha()) or 1) < 1 then
    tabAlphaGuard = true
    tab:SetAlpha(1)
    tabAlphaGuard = false
  end
end

local function AllTabColors()
  for tab in pairs(tabs) do
    TabColors(tab)
  end
end

local function TintGlow(tab)
  local glow = S.Region(tab, "glow") or (S.Name(tab) and S.Get(S.Name(tab) .. "Glow"))
  if glow then
    S.Tint(glow, S.Theme().accent)
  end
end

local function SkinTab(tab)
  if not S.Usable(tab) or not S.Once(tab, "chattab") then
    return
  end
  local name = S.Name(tab)
  for _, key in ipairs(TAB_ART) do
    S.Kill(S.Child(tab, key))
    S.KillNamed(name, key)
  end
  local theme = S.Theme()
  -- the tab hugs its name (Blizzard's tab button is much taller and wider than the text); without a name to
  -- measure, the lower part of the button, where Blizzard's art was
  local text = TabText(tab)
  local opts
  if text then
    opts = { topLeft = text, bottomRight = text, left = 9, right = 9, top = 4, bottom = 4 }
  else
    local left = S.Region(tab, "Left") or (name and S.Get(name .. "Left"))
    local right = S.Region(tab, "Right") or (name and S.Get(name .. "Right"))
    opts = { left = -2, right = -2, top = -4, bottom = 0 }
    if left and right then
      opts.topLeft, opts.bottomRight = left, right
    end
  end
  local plate = S.Plate(tab, { fill = theme.hud.fill, rings = { { inset = 0, color = theme.button.line, size = 1 } } }, opts)
  -- R2-HUD: the tab's line has no bottom edge (it opens onto the chat box)
  if plate.lines[2] then
    plate.lines[2]:Hide()
  end
  local selected = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
  selected:SetAllPoints(plate.fill)
  S.UI.Gradient(selected, theme.titlebar.from, theme.titlebar.to)
  selected:Hide()
  tabs[tab] = { fill = plate.fill, selected = selected, isSelected = false }
  TintGlow(tab)
  TabColors(tab)
  -- Blizzard fades tabs out when the mouse leaves; the selected tab stays readable
  S.HookMethod(tab, "SetAlpha", function(self, alpha)
    local look = tabs[self]
    if not tabAlphaGuard and look and look.isSelected and (Number(alpha) or 1) < 1 then
      tabAlphaGuard = true
      self:SetAlpha(1)
      tabAlphaGuard = false
    end
  end)
end

-- Edit box -------------------------------------------------------------------------------------------------

local function HeaderColor(box)
  local header = S.Region(box, "header") or (S.Name(box) and S.Get(S.Name(box) .. "Header"))
  if not header then
    return
  end
  -- R2-HUD: "Say:" in white, 13 px: Blizzard's own channel colours stay, only the face follows the theme
  S.Font(header, "body", nil, true)
end

local function SkinEditBox(box, frame)
  if not S.Usable(box) or not S.Once(box, "chatedit") then
    return
  end
  local name = S.Name(box)
  for _, key in ipairs(EDIT_ART) do
    S.Kill(S.Child(box, key))
    S.KillNamed(name, key)
  end
  local window = windows[frame]
  if window then
    window.editBox = box
    -- R2-HUD: a 26-unit bar (Blizzard's edit box is 32 tall)
    window.edit = S.Plate(box, "hud", { left = -3, right = -3, top = -3, bottom = -3 })
    editOwner[box] = frame
    EditAlpha(window)
  end
  S.Font(box, "body", nil, true)
  local suffix = S.Region(box, "headerSuffix")
  if suffix then
    S.Font(suffix, "body", nil, true)
  end
  HeaderColor(box)
  S.HookMethod(box, "UpdateHeader", HeaderColor)
  -- light theme: the channel colours Blizzard gives the "Say:" header and the typed text, readable on the light
  -- bar (colour only on the edit box itself: its text is never written)
  S.GameText(S.Region(box, "header") or (name and S.Get(name .. "Header")), "hud")
  S.GameText(suffix, "hud")
  S.GameText(box, "hud", { codes = false })
  local function Focus()
    local owner = windows[editOwner[box]]
    if owner then
      EditAlpha(owner)
    end
  end
  S.HookScript(box, "OnEditFocusGained", Focus)
  S.HookScript(box, "OnEditFocusLost", Focus)
end

-- Side buttons ---------------------------------------------------------------------------------------------
-- One look for every button beside and in the chat (live Blizzard_ChatFrameBase / Blizzard_VoiceToggleButton):
-- a SIDE_SIZE square of ours (the theme button's gradient and 1-unit line) centred on the button, the theme's
-- hover over it, Blizzard's box art invisible (alpha only) and the icon kept, centred. The voice / speech
-- buttons (ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton / MuteButton, TextToSpeechButton:
-- VoiceToggleButtonTemplate, 27 x 26, box atlas "chatframe-button-up" with a separate .Icon) keep their
-- icon. ChatFrameMenuButton (32 x 32) has the yellow speech bubble drawn into its box
-- (Interface\ChatFrame\UI-ChatIcon-Chat-Up), so its art goes and our own copy of the bubble, cut out of the
-- box, sits in the square. The scroll-to-bottom and tab overflow buttons draw only their arrow: the square
-- fills them (FitColumn sizes the scroll button). The buttons are never moved: they are centred on the
-- button frame already, so the squares line up.
local SIDE_SIZE = 22
local MENU_ART = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"
local MENU_CROP = { 0.2, 0.8, 0.18, 0.78 } -- the bubble without the box round it
local BOX_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local ART_ONLY = { GetHighlightTexture = true } -- arrow buttons: their states are the icon, only the glow goes

local sideButtons = {} -- [button] = { keep = { [getter] = true } }

-- Blizzard's box art invisible again (the voice buttons put their atlases back when their state changes).
local function HideBoxArt(button)
  local look = sideButtons[button]
  if not look then
    return
  end
  local icon = S.Region(button, "Icon") or S.Region(button, "icon")
  for _, getter in ipairs(BOX_GETTERS) do
    local texture = not look.keep[getter] and button[getter] and button[getter](button)
    if S.IsRegion(texture) and texture ~= icon then
      S.Kill(texture)
    end
  end
  S.Kill(S.Region(button, "Background")) -- the speech button's black square
end

local function SkinSideButton(button, fill)
  if not S.Usable(button) or not S.Once(button, "chatbutton") then
    return
  end
  local style = S.Theme().button
  local keep = {}
  if fill then
    for _, getter in ipairs(BOX_GETTERS) do
      keep[getter] = not ART_ONLY[getter]
    end
  end
  sideButtons[button] = { keep = keep }
  -- the square: our own frame-less textures on the button, under its icon
  local square = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  if fill then
    square:SetAllPoints(button)
  else
    square:SetSize(SIDE_SIZE, SIDE_SIZE)
    square:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
  S.UI.Gradient(square, style.from, style.to)
  S.Outline(button, square, 0, 1, style.line, "BORDER", 1)
  local hover = button:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(square)
  S.SetColor(hover, style.hover or { 1, 1, 1, 0.1 })
  -- the menu button's bubble is part of its box art: our own copy, the box left out
  if not fill and not (S.Region(button, "Icon") or S.Region(button, "icon")) then
    local bubble = button:CreateTexture(nil, "ARTWORK")
    bubble:SetTexture(MENU_ART)
    bubble:SetTexCoord(MENU_CROP[1], MENU_CROP[2], MENU_CROP[3], MENU_CROP[4])
    bubble:SetSize(SIDE_SIZE - 6, SIDE_SIZE - 6)
    bubble:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
  HideBoxArt(button)
  for _, method in ipairs({ "SetNormalAtlas", "SetPushedAtlas", "SetHighlightAtlas", "SetNormalTexture",
    "SetPushedTexture", "SetHighlightTexture", "UpdateVisualState" }) do
    S.HookMethod(button, method, HideBoxArt)
  end
  S.HookScript(button, "OnShow", HideBoxArt)
end

-- Scroll column ------------------------------------------------------------------------------------------
-- The scroll bar (arrows and track) and the scroll-to-bottom button form one column inside the box's right
-- edge: the bar keeps Blizzard's distance from the text (measured once), the button is centred under it with
-- the column's width (a square, at least BUTTON_MIN), and the box reaches COLUMN_PAD past the column on the
-- right, top and bottom alike. Chat isn't secure, so the bar and button are re-anchored to the chat window
-- itself (never to each other, so no anchor loop), again after each of Blizzard's own layout passes.
local COLUMN_PAD, BUTTON_MIN, BUTTON_GAP = 4, 12, 2
local BOX_LEFT, BOX_BOTTOM = 8, 6 -- the box's room round the text (R2-HUD)

local function FitColumn(frame)
  local window = windows[frame]
  local bar = S.Child(frame, "ScrollBar")
  if not window or not window.plate or not S.Usable(bar) then
    return
  end
  if window.dx == nil then
    local left, right = Number(bar.GetLeft and bar:GetLeft()), Number(frame.GetRight and frame:GetRight())
    local barScale = Number(bar.GetEffectiveScale and bar:GetEffectiveScale()) or 1
    local frameScale = Number(frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    if not left or not right or frameScale <= 0 then
      return -- not laid out yet: tried again on the next pass
    end
    window.dx = math.max(-40, math.min(40, left * barScale / frameScale - right))
  end
  local width = Number(bar.GetWidth and bar:GetWidth()) or 10
  local size = math.max(BUTTON_MIN, math.floor(width + 0.5))
  local centre = window.dx + width / 2
  local bottom = BOX_BOTTOM - COLUMN_PAD -- the button's bottom, units under the window's bottom
  local button = S.Child(frame, "ScrollToBottomButton")
  if S.Usable(button) then
    button:ClearAllPoints()
    button:SetPoint("BOTTOM", frame, "BOTTOMRIGHT", centre, -bottom)
    button:SetSize(size, size)
  end
  -- the bar's top, units under the window's top (never above it: the combat log's filter bar is there)
  local top = math.max(0, window.top - COLUMN_PAD)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", window.dx, -top)
  bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", window.dx,
    S.Usable(button) and (size - bottom + BUTTON_GAP) or -bottom)
  local fill = window.plate.fill
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", window.topLeft, "TOPLEFT", -BOX_LEFT, window.top)
  fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
    math.max(BOX_LEFT, centre + math.max(width, size) / 2 + COLUMN_PAD), -BOX_BOTTOM)
end

local function FitAllColumns()
  for frame in pairs(windows) do
    FitColumn(frame)
  end
end

-- Chat font ------------------------------------------------------------------------------------------------

-- The theme's body face at whatever size Blizzard (the player's setting) gives the window.
local settingFont = false
local function KeepFont(frame)
  local path = S.Theme().font.body
  if settingFont or not path or not frame.GetFont then
    return
  end
  local current, size, flags = frame:GetFont()
  size = Number(size)
  if current ~= path and size and size > 0 then
    settingFont = true
    frame:SetFont(path, size, type(flags) == "string" and flags or "")
    settingFont = false
  end
end

-- Readable lines on a light box (Dawn) ---------------------------------------------------------------------
-- Forever's chat window is a ScrollingMessageFrame (Blizzard_SharedXML/ScrollingMessageFrame.lua, forever
-- branch): AddMessage only stores the message; RefreshDisplay later writes each shown message into one of the
-- pooled font strings in frame.visibleLines (SetText, then SetTextColor with the chat type's r, g, b) and ends by
-- calling the callbacks added with AddOnDisplayRefreshedCallback. That method is on ScrollingMessageFrameSecureMixin,
-- which Blizzard keeps for addons: a "secure elevation barrier" whose callbacks run through secureexecuterange,
-- each on its own, so our code never runs inside Blizzard's message handling. Codex uses it to go over the shown
-- lines after every refresh: the line colour through ns.GameColor and the colour codes in the text (class-coloured
-- names, item / quest links |cnIQn:, channel colours) through ns.Readable, both against the chat box drawn over the
-- world. Only the display is changed: the history (and so a later theme, copy chat, other addons) keeps the game's
-- colours, and the next refresh sets each line afresh before we look at it again. A secret line (Forever makes some
-- chat secret: the font string then has a secret aspect) is never read further: GetText / GetTextColor values are
-- checked with issecretvalue / canaccessvalue first and a secret one is left exactly as the game set it. Not used:
-- replacing AddMessage (it would run our code inside Blizzard's handler, tainting it for the secret values it
-- handles next), rewriting historyBuffer entries (Blizzard's table, read by its secure refresh) and
-- AdjustMessageColors (colour only, and it rewrites the whole history).
local readableFrames = {} -- [chat frame] = true once its callback is added

local function ReadableLines(frame)
  local theme = S.Theme()
  if not theme.light then
    return
  end
  -- the chat box: the HUD fill over the world (drawn fully at the default opacity and up)
  local ground = TylesserCodex.Ground and TylesserCodex.Ground(theme, "hud") or nil
  for _, line in ipairs(S.Child(frame, "visibleLines") or {}) do
    if S.IsRegion(line) and line.IsShown and line:IsShown() == true then
      S.UI.ReadableNow(line, theme, ground, true)
    end
  end
end
S.ReadableChatLines = ReadableLines

local function WatchLines(frame)
  if readableFrames[frame] or not S.Theme().light or type(frame.AddOnDisplayRefreshedCallback) ~= "function" then
    return
  end
  readableFrames[frame] = true
  local part = S.part
  frame:AddOnDisplayRefreshedCallback(function(messageFrame)
    S.Run(part, ReadableLines, messageFrame)
  end)
  ReadableLines(frame)
end

-- Windows --------------------------------------------------------------------------------------------------

local function SkinChat(frame)
  if not S.Usable(frame) or not S.Once(frame, "chat") then
    return
  end
  local name = S.Name(frame)
  local background = S.Region(frame, "Background") or (name and S.Get(name .. "Background"))
  for _, key in ipairs(BACKGROUND) do
    local art = S.Child(frame, key) or (name and S.Get(name .. key))
    if art == background then
      -- emptied but its alpha left alone: Blizzard's fading of it is what our box follows
      if S.IsRegion(art) and art.SetTexture then
        art:SetTexture(nil)
      end
    else
      S.Empty(art)
    end
  end
  S.Empty(S.Child(frame, "ScrollBar", "Background"))
  -- the button bar beside the window (its buttons stay)
  local buttonFrame = S.Child(frame, "buttonFrame") or (name and S.Get(name .. "ButtonFrame"))
  local buttonName = S.Name(buttonFrame) or (name and name .. "ButtonFrame")
  for _, key in ipairs(BACKGROUND) do
    S.Empty(S.Child(buttonFrame, key))
    if buttonName then
      S.Empty(S.Get(buttonName .. key))
    end
  end

  -- the combat log has its filter bar on top: the box covers it too
  local top = name == "ChatFrame2" and S.Get("CombatLogQuickButtonFrame_Custom") or nil
  local window = { alpha = 1 }
  windows[frame] = window
  -- R2-HUD: the box holds the text with 6 / 9 units of room (the top stays tight under the tabs)
  window.topLeft, window.top = top or frame, top and 0 or 4
  window.plate = S.Plate(frame, "hud", { left = BOX_LEFT, right = 8, bottom = BOX_BOTTOM, top = window.top,
    topLeft = window.topLeft })
  if S.IsRegion(background) then
    FollowAlpha(frame, background:GetAlpha())
    S.HookMethod(background, "SetAlpha", function(_, alpha)
      FollowAlpha(frame, alpha)
    end)
  end

  if S.Theme().font.body then
    KeepFont(frame)
    S.HookMethod(frame, "SetFont", KeepFont)
  end
  SkinTab(S.Child(frame, "tab") or (name and S.Get(name .. "Tab")))
  SkinEditBox(S.Child(frame, "editBox") or (name and S.Get(name .. "EditBox")), frame)
  WatchLines(frame)
  local scrollButton = S.Child(frame, "ScrollToBottomButton")
  SkinSideButton(scrollButton, true)
  -- the scroll column: now if the window is laid out, else when it shows or Blizzard lays it out again
  FitColumn(frame)
  S.HookScript(frame, "OnShow", function()
    FitColumn(frame)
  end)
  S.HookScript(frame, "OnSizeChanged", function()
    FitColumn(frame)
  end)
  S.HookScript(scrollButton, "OnShow", function()
    FitColumn(frame)
  end)
end

local function SkinAll()
  for _, frame in ipairs(ChatFrames()) do
    SkinChat(frame)
  end
  SkinSideButton(S.Child(S.Get("GeneralDockManager"), "overflowButton") or S.Get("GeneralDockManagerOverflowButton"), true)
  for _, path in ipairs(SIDE_BUTTONS) do
    SkinSideButton(S.Get(path))
  end
end

-- The box texture a chat window got from this skin (the info bar's chat panel lines up with it), or nil.
TylesserCodex.ChatBox = function(frame)
  local window = windows[frame]
  return window and window.plate and window.plate.fill or nil
end

S.Part("chat", function()
  SkinAll()
  -- tab colours follow Blizzard's own selected / unselected colouring
  S.HookGlobal("FCFTab_UpdateColors", function(tab, selected)
    TabColors(tab, selected and true or false)
  end)
  for _, name in ipairs({ "FCF_SelectDockFrame", "FCFDock_SelectWindow", "FCF_DockFrame", "FCF_UnDockFrame",
    "FCFDock_UpdateTabs", "FCFTab_UpdateAlpha" }) do
    S.HookGlobal(name, AllTabColors)
  end
  S.HookGlobal("FCF_StartAlertFlash", function(frame)
    local tab = S.Child(frame, "tab") or (S.Name(frame) and S.Get(S.Name(frame) .. "Tab"))
    if tab then
      TintGlow(tab)
    end
  end)
  -- the scroll column after Blizzard places the bar and the button again (button side, scroll bar anchors)
  for _, name in ipairs({ "FCF_UpdateScrollbarAnchors", "FCF_UpdateButtonSide", "FCF_SetButtonSide" }) do
    S.HookGlobal(name, function(frame)
      if windows[frame] then
        FitColumn(frame)
      else
        FitAllColumns()
      end
    end)
  end
  C_Timer.After(0, function()
    S.Run("chat", FitAllColumns)
  end)
  -- the "Say:" header after Blizzard sets the channel (global on older builds, a method on newer ones)
  S.HookGlobal("ChatEdit_UpdateHeader", HeaderColor)
  -- new windows (whispers, new tabs): chat isn't secure, so they are styled straight away
  for _, name in ipairs({ "FCF_OpenTemporaryWindow", "FCF_OpenNewWindow" }) do
    S.HookGlobal(name, function()
      SkinAll()
      AllTabColors()
    end)
  end
end)
