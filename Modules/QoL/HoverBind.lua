local addonName, ns = ...

-- Bind keys by hovering (2026-11-21): point at an action button, press a key, and that key casts the button.
-- Escape clears the button's keys. A banner at the top of the screen says what to do and has Done / Cancel.
--
-- Forever has its own Quick Keybind mode (Blizzard_QuickKeybind), but opening it from addon code runs
-- ActionButtonUtil.ShowAllActionButtonGrids on the secure action buttons from our call stack (taint). This mode
-- touches nothing of Blizzard's: it reads the hovered button's `commandName` (ActionBar.lua sets it from the bar's
-- commandNamePrefix: ACTIONBUTTON1, MULTIACTIONBAR1BUTTON3, ...; forever branch Blizzard_ActionBar/Shared), lays a
-- frame of ours over it that takes the keys, and binds the way the game's Keybindings page does
-- (Blizzard_Settings_Shared/Blizzard_Keybindings.lua: GetConvertedKeyOrButton, IsKeyPressIgnoredForBinding,
-- CreateKeyChordStringUsingMetaKeyState, SetBinding(key, action, context), SaveBindings(GetCurrentBindingSet())).
-- Done saves, Cancel loads the saved set back (LoadBindings). Out of combat only: a fight ends the mode and saves.

local Q = ns.qol
local UI = ns.UI
local KEY = "hoverBind"
local HB = {}
Q.hoverBind = HB

local banner, cover, watcher
local changed = false

local function InCombat()
  return InCombatLockdown and InCombatLockdown()
end

-- The binding command of a frame under the mouse: an action button's commandName, or nil.
local function CommandOf(frame)
  local depth = 0
  while frame and depth < 3 do
    local ok, forbidden = pcall(function()
      return frame.IsForbidden and frame:IsForbidden()
    end)
    if not ok or forbidden then
      return nil
    end
    local command = rawget(frame, "commandName")
    if type(command) == "string" and command ~= "" then
      return command, frame
    end
    frame = frame.GetParent and frame:GetParent() or nil
    depth = depth + 1
  end
  return nil
end
HB.CommandOf = CommandOf

local function Hovered()
  if not GetMouseFoci then
    return nil
  end
  local ok, foci = pcall(GetMouseFoci)
  if not ok or type(foci) ~= "table" then
    return nil
  end
  for _, frame in ipairs(foci) do
    if frame ~= cover then
      local command, button = CommandOf(frame)
      if command then
        return command, button
      end
    end
  end
  return nil
end

local function Context(command)
  if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
    local ok, context = pcall(C_KeyBindings.GetBindingContextForAction, command)
    if ok then
      return context
    end
  end
  return nil
end

-- Every key bound to a command, as the game writes them ("SHIFT-1").
function HB.Keys(command)
  if not GetBindingKey then
    return {}
  end
  return { GetBindingKey(command, nil, Context(command)) }
end

local function KeyText(key)
  return GetBindingText and GetBindingText(key) or key
end

-- "SHIFT-1" from a pressed key with the modifiers held, or nil for a key the game never binds alone.
function HB.Chord(input)
  local key = GetConvertedKeyOrButton and GetConvertedKeyOrButton(input) or input
  if IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key) then
    return nil
  end
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT"
    or key == "UNKNOWN" or key == "LeftButton" or key == "RightButton" then
    return nil
  end
  if CreateKeyChordStringUsingMetaKeyState then
    return CreateKeyChordStringUsingMetaKeyState(key)
  end
  local chord = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
    .. (IsShiftKeyDown() and "SHIFT-" or "")
  return chord .. key
end

function HB.Bind(command, chord)
  if InCombat() or not (SetBinding and command and chord) then
    return false
  end
  local ok, done = pcall(SetBinding, chord, command, Context(command))
  if ok and done ~= false then
    changed = true
    return true
  end
  return false
end

function HB.Clear(command)
  if InCombat() or not SetBinding then
    return
  end
  for _, key in ipairs(HB.Keys(command)) do
    pcall(SetBinding, key, nil, Context(command))
    changed = true
  end
end

local function ShowTip()
  if not cover or not cover.command then
    return
  end
  GameTooltip:SetOwner(cover, "ANCHOR_RIGHT")
  GameTooltip:AddLine(GetBindingName and GetBindingName(cover.command) or cover.command)
  local keys = HB.Keys(cover.command)
  if #keys == 0 then
    GameTooltip:AddLine("No key yet: press one.", 1, 1, 1)
  else
    local names = {}
    for index, key in ipairs(keys) do
      names[index] = KeyText(key)
    end
    GameTooltip:AddLine(table.concat(names, ", "), 1, 1, 1)
    GameTooltip:AddLine("Press another key to add it, Escape to clear.", 0.7, 0.7, 0.7, true)
  end
  GameTooltip:Show()
end

local function Press(input)
  if not cover or not cover.command then
    return
  end
  if input == "ESCAPE" then
    HB.Clear(cover.command)
  else
    local chord = HB.Chord(input)
    if chord then
      HB.Bind(cover.command, chord)
    end
  end
  ShowTip()
  HB.Refresh()
end

local function MakeCover()
  cover = CreateFrame("Button", "CodexHoverBindCover", UIParent)
  cover:SetFrameStrata("DIALOG")
  cover:EnableKeyboard(true)
  cover:EnableMouseWheel(true)
  cover:RegisterForClicks("AnyUp")
  local theme = ns.Theme()
  local mark = cover:CreateTexture(nil, "OVERLAY")
  mark:SetAllPoints()
  UI.SetColor(mark, theme.accent, 0.35)
  cover:SetScript("OnKeyDown", function(_, key)
    Press(key)
  end)
  cover:SetScript("OnClick", function(_, button)
    if button ~= "LeftButton" and button ~= "RightButton" then
      Press(button)
    end
  end)
  cover:SetScript("OnMouseWheel", function(_, delta)
    Press(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
  end)
  cover:SetScript("OnEnter", ShowTip)
  cover:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    self:Hide()
    self.command = nil
  end)
  cover:Hide()
end

local function MakeBanner()
  banner = CreateFrame("Frame", "CodexHoverBindBanner", UIParent)
  banner:SetSize(460, 74)
  banner:SetPoint("TOP", 0, -90)
  banner:SetFrameStrata("DIALOG")
  UI.Panel(banner, { strip = false })
  local title = UI.Text(banner, "head", 14, "accent")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("Binding keys")
  local help = UI.Text(banner, "body", 12, "text")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  help:SetWidth(270)
  help:SetJustifyH("LEFT")
  help:SetText("Point at an action button and press a key. Escape clears the button's keys.")
  local done = UI.Button(banner, 80, 22, "Done")
  done:SetPoint("RIGHT", -14, 0)
  done:SetScript("OnClick", function()
    HB.Stop(true)
  end)
  local cancel = UI.Button(banner, 80, 22, "Cancel")
  cancel:SetPoint("RIGHT", done, "LEFT", -8, 0)
  cancel:SetScript("OnClick", function()
    HB.Stop(false)
  end)
  banner:Hide()
end

function HB.Refresh()
  -- nothing on the banner changes yet; kept for the page and tests
end

-- The cover over the whole button as you see it: the button's box and its icon's together (the restyled icon can
-- reach past the button's own box; the user's screenshot, 2026-11-22: the highlight covered part of it), in
-- screen pixels so a scaled bar lines up. Falls back to the button's box.
local function Box(region)
  if type(region) ~= "table" or type(region.GetRect) ~= "function" or type(region.GetEffectiveScale) ~= "function" then
    return nil
  end
  local ok, left, bottom, width, height = pcall(region.GetRect, region)
  local okScale, scale = pcall(region.GetEffectiveScale, region)
  if not (ok and okScale) or type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number"
    or type(height) ~= "number" or type(scale) ~= "number" or width <= 0 or height <= 0 then
    return nil
  end
  return left * scale, bottom * scale, (left + width) * scale, (bottom + height) * scale
end

local function CoverButton(button)
  cover:ClearAllPoints()
  local l, b, r, t = Box(button)
  local icon = button.icon or button.Icon
  local il, ib, ir, it = Box(icon)
  local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  if l and il and type(uiScale) == "number" and uiScale > 0 then
    l, b, r, t = math.min(l, il), math.min(b, ib), math.max(r, ir), math.max(t, it)
    cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / uiScale, b / uiScale)
    cover:SetSize((r - l) / uiScale, (t - b) / uiScale)
  else
    cover:SetAllPoints(button)
  end
end
HB.CoverButton = CoverButton

-- One look per frame: a cover over the hovered action button while the mode is on.
local function Watch()
  if not (banner and banner:IsShown()) then
    return
  end
  if cover:IsShown() and cover:IsMouseOver() then
    return
  end
  local command, button = Hovered()
  if command and button then
    cover.command = command
    CoverButton(button)
    cover:Show()
    ShowTip()
  end
end

HB.Watch = Watch -- tests run it by hand

function HB.Start()
  if not Q.On(KEY) then
    ns.Say("Bind keys by hovering is off: switch it on under Action bars > Buttons.")
    return false
  end
  if InCombat() then
    ns.Say("Key binding waits until the fight is over.")
    return false
  end
  if not cover then
    MakeCover()
    MakeBanner()
    watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", Watch)
    watcher:SetScript("OnEvent", function()
      HB.Stop(true)
    end)
  end
  changed = false
  banner:Show()
  watcher:Show()
  watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
  return true
end

-- save = true keeps the new keys (SaveBindings), false loads the saved set back.
function HB.Stop(save)
  if not banner then
    return
  end
  banner:Hide()
  cover:Hide()
  cover.command = nil
  watcher:Hide()
  watcher:UnregisterAllEvents()
  GameTooltip:Hide()
  if changed and GetCurrentBindingSet then
    if save and SaveBindings then
      pcall(SaveBindings, GetCurrentBindingSet())
      ns.Say("Key bindings saved.")
    elseif not save and LoadBindings and not InCombat() then
      pcall(LoadBindings, GetCurrentBindingSet())
      ns.Say("Key bindings put back.")
    end
  end
  changed = false
end

function HB.Active()
  return banner and banner:IsShown() and true or false
end

Q.AddToggle({
  key = KEY,
  name = "Bind keys by hovering",
  desc = "Point at an action button and press a key to bind it, Escape to clear it. Start it with the button "
    .. "below or /codex bind; Done saves the keys, Cancel puts back the ones you had. Not in a fight.",
  default = true,
  order = 29,
  Changed = function(on)
    if not on and HB.Active() then
      HB.Stop(true)
    end
  end,
  options = {
    { key = "hoverBindStart", kind = "button", name = "Start binding", Click = function()
      if HB.Start() and ns.ToggleWindow and CodexWindow and CodexWindow:IsShown() then
        ns.ToggleWindow()
      end
    end },
  },
})

-- /codex bind
local module = ns.modules and ns.modules.qol
if module then
  module.commands = module.commands or {}
  module.commands.bind = function()
    HB.Start()
  end
end
