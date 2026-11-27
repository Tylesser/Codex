local addonName, ns = ...
local L = ns.L

-- Action bar visibility, part 1: fading the action bars (and the micro menu, bags bar and experience bar)
-- by alpha only, per bar: Always, Mouse-over only, In combat only, Out of combat only, In combat or
-- mouse-over, or Never (alpha 0, still clickable).
--
-- Taint and combat: SetAlpha is the only thing done to Blizzard's bars (allowed on protected frames in a
-- fight); they are never shown, hidden, moved or given a field, and Edit Mode layouts are never touched.
-- Blizzard may set a bar's alpha itself: a post-hook on SetAlpha puts ours back. Script hooks on Blizzard's
-- windows (spell book, Quick Keybind) are only added out of combat.
-- Nothing at all is set up while every bar is on Always: no events, hooks, frames or OnUpdate. Once a bar
-- fades, one frame of ours polls the mouse (throttled) only while a bar uses a mouse-over mode, and steps
-- alphas only while something fades.
-- (FlareUI's Visibility, MIT, Modules/Visibility.lua, was read for the Forever facts: each gryphon is its
-- own Edit Mode system and ignores the main bar's alpha, so each cap gets the alpha too; bars show while
-- something is dragged, the spell book is open, Edit Mode or Quick Keybind is on; a spell flyout over a
-- bar's button counts as the mouse over the bar.)

local BF = {}
ns.barfade = BF

local FADE_TIME = 0.2 -- seconds for a full fade
local POLL = 0.05 -- seconds between mouse checks
local LINGER = 0.5 -- a bar stays this long after the mouse left it
local MARGIN = 4 -- pixels around a bar that still count as over it
local MAX_FADED = 0.5

BF.FADE_TIME, BF.POLL, BF.LINGER = FADE_TIME, POLL, LINGER

BF.MODES = {
  { id = "always", name = L["Always"] },
  { id = "mouseover", name = L["Mouse-over only"] },
  { id = "combat", name = L["In combat only"] },
  { id = "nocombat", name = L["Out of combat only"] },
  { id = "combatmouse", name = L["In combat or mouse-over"] },
  { id = "never", name = L["Never (invisible, still clickable)"] },
}
local MODE_NAME = {}
for _, mode in ipairs(BF.MODES) do
  MODE_NAME[mode.id] = mode.name
end
local MOUSE_MODES = { mouseover = true, combatmouse = true }

-- key: the saved name; frames: the frames that get the alpha; buttons: an action bar (shows while
-- something is dragged, the grid is up or the spell book is open); vehicle: shows in a vehicle, possess
-- or override; caps: the gryphons follow it.
BF.BARS = {
  { key = "MainActionBar", name = L["Main bar"], frames = { "MainActionBar" }, buttons = { "ActionButton", 12 },
    caps = true, vehicle = true },
  { key = "MultiBarBottomLeft", name = L["Bar 2"], frames = { "MultiBarBottomLeft" }, buttons = { "MultiBarBottomLeftButton", 12 } },
  { key = "MultiBarBottomRight", name = L["Bar 3"], frames = { "MultiBarBottomRight" }, buttons = { "MultiBarBottomRightButton", 12 } },
  { key = "MultiBarRight", name = L["Bar 4"], frames = { "MultiBarRight" }, buttons = { "MultiBarRightButton", 12 } },
  { key = "MultiBarLeft", name = L["Bar 5"], frames = { "MultiBarLeft" }, buttons = { "MultiBarLeftButton", 12 } },
  { key = "MultiBar5", name = L["Bar 6"], frames = { "MultiBar5" }, buttons = { "MultiBar5Button", 12 } },
  { key = "MultiBar6", name = L["Bar 7"], frames = { "MultiBar6" }, buttons = { "MultiBar6Button", 12 } },
  { key = "MultiBar7", name = L["Bar 8"], frames = { "MultiBar7" }, buttons = { "MultiBar7Button", 12 } },
  { key = "PetActionBar", name = L["Pet bar"], frames = { "PetActionBar" }, buttons = { "PetActionButton", 10 }, vehicle = true },
  { key = "StanceBar", name = L["Stance bar"], frames = { "StanceBar" }, buttons = { "StanceButton", 10 } },
  -- the container, not the menu: in a vehicle Blizzard moves the menu onto the vehicle bar
  { key = "MicroMenu", name = L["Micro menu"], frames = { "MicroMenuContainer" }, fallback = "MicroMenu" },
  { key = "BagsBar", name = L["Bags bar"], frames = { "BagsBar" } },
  { key = "StatusTracking", name = L["Experience bar"], frames = { "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer" } },
}
local BAR_BY_KEY = {}
for _, bar in ipairs(BF.BARS) do
  BAR_BY_KEY[bar.key] = bar
end

local DEFAULTS = { bars = {}, faded = 0 }

local state = {
  active = false, -- events and the driver are set up (once a bar fades)
  combat = false,
  dragging = false,
  grid = false,
  editMode = false,
  keybind = false,
  preview = false, -- "Show all now"
  clock = 0, -- seconds, from the driver's own OnUpdate
  pollTimer = 0,
  dirty = false,
  hooksPending = false,
}
BF.state = state

local current = {} -- [key] = the alpha we last set (nil: the bar is left to Blizzard)
local target = {} -- [key] = the alpha the bar is heading for
local lastOver = {} -- [key] = clock when the mouse was last over the bar
local framesOf = {} -- [key] = { frame, ... } resolved
local alphaHooked = setmetatable({}, { __mode = "k" }) -- [frame] = key, SetAlpha post-hooked
local scriptHooked = setmetatable({}, { __mode = "k" }) -- [frame] = true, OnShow/OnHide hooked
local blingOff = setmetatable({}, { __mode = "k" }) -- [cooldown] = true: its finish flash turned off by us
local setting = false -- our own SetAlpha is running
local driver

BF.current, BF.target = current, target

function BF.DB()
  if not BF.db then
    ns.db.barfade = ns.Fill(ns.db.barfade or {}, DEFAULTS)
    BF.db = ns.db.barfade
  end
  return BF.db
end

function BF.Mode(key)
  local mode = BF.DB().bars[key]
  return MODE_NAME[mode] and mode or "always"
end

function BF.ModeName(id)
  return MODE_NAME[id] or MODE_NAME.always
end

function BF.Faded()
  local value = tonumber(BF.DB().faded) or 0
  return math.max(0, math.min(MAX_FADED, value))
end

-- bars not on Always
function BF.FadingCount()
  local count = 0
  for _, bar in ipairs(BF.BARS) do
    if BF.Mode(bar.key) ~= "always" then
      count = count + 1
    end
  end
  return count
end

-- Frames ----------------------------------------------------------------------------------------------------

local function Usable(frame)
  return type(frame) == "table" and type(frame.SetAlpha) == "function" and type(frame.GetAlpha) == "function"
    and not (type(frame.IsForbidden) == "function" and frame:IsForbidden())
end

local function Field(object, key)
  local value = type(object) == "table" and object[key] or nil
  return type(value) == "table" and value or nil
end

-- The gryphons, unless the restyle already made them invisible (Skins/ActionBars.lua).
local function Caps()
  if ns.SkinPartOn and ns.db.skins and ns.SkinPartOn("actionbars") then
    return nil
  end
  local caps = Field(_G.MainActionBar, "EndCaps")
  local left, right = Field(caps, "LeftEndCap"), Field(caps, "RightEndCap")
  return Usable(left) and left or nil, Usable(right) and right or nil
end

local function Frames(bar)
  local list = framesOf[bar.key]
  if list and #list > 0 then
    return list
  end
  list = {}
  for _, name in ipairs(bar.frames) do
    if Usable(_G[name]) then
      list[#list + 1] = _G[name]
    end
  end
  if #list == 0 and bar.fallback and Usable(_G[bar.fallback]) then
    list[1] = _G[bar.fallback]
  end
  if bar.caps and #list > 0 then
    local left, right = Caps()
    list[#list + 1] = left
    list[#list + 1] = right
  end
  framesOf[bar.key] = list
  return list
end
BF.Frames = Frames

-- Alpha ------------------------------------------------------------------------------------------------------

-- The cooldown "finished" flash draws at full strength whatever the bar's alpha: off while a bar is faded
-- below half, the button's own setting back after.
local function SetBling(bar, alpha)
  local set = bar.buttons
  if not set then
    return
  end
  local faded = alpha < 0.5
  for index = 1, set[2] do
    local cooldown = Field(_G[set[1] .. index], "cooldown")
    if cooldown and type(cooldown.SetDrawBling) == "function" then
      if faded and not blingOff[cooldown] and type(cooldown.GetDrawBling) == "function" and cooldown:GetDrawBling() then
        blingOff[cooldown] = true
        cooldown:SetDrawBling(false)
      elseif not faded and blingOff[cooldown] then
        blingOff[cooldown] = nil
        cooldown:SetDrawBling(true)
      end
    end
  end
end

local function Apply(bar, alpha)
  current[bar.key] = alpha
  setting = true
  for _, frame in ipairs(Frames(bar)) do
    pcall(frame.SetAlpha, frame, alpha)
  end
  setting = false
  SetBling(bar, alpha)
end

-- Blizzard set the alpha itself (Edit Mode, its own updates): ours goes back on.
local function AfterSetAlpha(frame)
  if setting then
    return
  end
  local key = alphaHooked[frame]
  local alpha = key and current[key]
  if alpha == nil then
    return
  end
  local now = frame:GetAlpha()
  if type(now) == "number" and math.abs(now - alpha) > 0.001 then
    setting = true
    pcall(frame.SetAlpha, frame, alpha)
    setting = false
  end
end

-- The experience bar containers fade themselves in and out with animation groups (setToFinalAlpha), which change
-- the alpha without a SetAlpha call (Blizzard_StatusTrackingBar, StatusTrackingBar.xml on Forever): after a reload or
-- alt-tab the bar faded in to full and stayed there until the mouse passed over it. When one of those animations
-- ends, or the frame shows again, ours goes back on.
local ANIMATIONS = { "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }

local function Reapply(frame)
  local key = alphaHooked[frame]
  local alpha = key and current[key]
  if alpha == nil then
    return
  end
  setting = true
  pcall(frame.SetAlpha, frame, alpha)
  setting = false
end

local function HookAlpha(bar)
  for _, frame in ipairs(Frames(bar)) do
    if not alphaHooked[frame] then
      alphaHooked[frame] = bar.key
      hooksecurefunc(frame, "SetAlpha", AfterSetAlpha)
      for _, name in ipairs(ANIMATIONS) do
        local group = Field(frame, name)
        if group and type(group.HookScript) == "function" then
          pcall(group.HookScript, group, "OnFinished", function()
            Reapply(frame)
          end)
        end
      end
      if bar.key == "StatusTracking" and type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", function()
          Reapply(frame)
        end)
      end
    end
  end
end

-- Conditions -------------------------------------------------------------------------------------------------

local function Visible(frame)
  return type(frame.IsVisible) == "function" and frame:IsVisible() and true or false
end

local function Has(name)
  local api = _G.C_ActionBar
  local fn = (type(api) == "table" and type(api[name]) == "function" and api[name]) or _G[name]
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn)
  return ok and result and true or false
end

-- a vehicle, possessed creature, override or temporary shapeshift bar: its actions are on the main bar
-- (or the pet bar), so those show
local function InVehicle()
  if type(UnitHasVehicleUI) == "function" and UnitHasVehicleUI("player") then
    return true
  end
  return Has("HasVehicleActionBar") or Has("HasOverrideActionBar") or Has("HasTempShapeshiftActionBar")
    or Has("IsPossessBarVisible")
end

local function SpellBookOpen()
  local book = Field(_G.PlayerSpellsFrame, "SpellBookFrame")
  if book and Visible(book) then
    return true
  end
  local classic = _G.SpellBookFrame
  return type(classic) == "table" and Visible(classic) or false
end

local function EditModeOpen()
  local manager = _G.EditModeManagerFrame
  return state.editMode or (type(manager) == "table" and type(manager.IsShown) == "function" and manager:IsShown())
    and true or false
end

local function KeybindOpen()
  local frame = _G.QuickKeybindFrame
  return state.keybind or (type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown())
    and true or false
end

-- a spell flyout opened from one of this bar's buttons, with the mouse on it (it hangs outside the bar)
local function FlyoutOver(frame)
  local flyout = _G.SpellFlyout
  if type(flyout) ~= "table" or not Visible(flyout) or not flyout:IsMouseOver() then
    return false
  end
  local parent = flyout:GetParent()
  for _ = 1, 6 do
    if parent == nil then
      return false
    end
    if parent == frame then
      return true
    end
    parent = type(parent.GetParent) == "function" and parent:GetParent() or nil
  end
  return false
end

local function MouseOver(bar)
  for _, frame in ipairs(Frames(bar)) do
    if Visible(frame) and (frame:IsMouseOver(MARGIN, -MARGIN, -MARGIN, MARGIN) or (bar.buttons and FlyoutOver(frame))) then
      return true
    end
  end
  return false
end

-- The alpha a bar wants now. `shared` holds what is read once per pass.
local function Wanted(bar, mode, shared)
  if mode == "always" or state.preview or shared.editMode then
    return 1
  end
  if mode == "never" then
    return 0
  end
  if bar.vehicle and shared.vehicle then
    return 1
  end
  if bar.buttons and (state.dragging or state.grid or shared.spellBook or shared.keybind) then
    return 1
  end
  local combat = state.combat
  if (mode == "combat" or mode == "combatmouse") and combat then
    return 1
  end
  if mode == "nocombat" and not combat then
    return 1
  end
  if MOUSE_MODES[mode] then
    if MouseOver(bar) then
      lastOver[bar.key] = state.clock
      return 1
    end
    if lastOver[bar.key] and state.clock - lastOver[bar.key] < LINGER then
      return 1
    end
  end
  return BF.Faded()
end

-- Every bar's target, read again (`shared` is reused: this runs 20 times a second while polling).
BF.shared = {}
local function Evaluate()
  state.dirty = false
  local shared = BF.shared
  shared.editMode, shared.vehicle, shared.spellBook, shared.keybind = EditModeOpen(), InVehicle(), SpellBookOpen(),
    KeybindOpen()
  local polling = false
  for _, bar in ipairs(BF.BARS) do
    local mode = BF.Mode(bar.key)
    if mode == "always" and current[bar.key] == nil then
      target[bar.key] = nil
    else
      if #Frames(bar) > 0 then
        HookAlpha(bar)
        if current[bar.key] == nil then
          local first = Frames(bar)[1]
          local alpha = first:GetAlpha()
          current[bar.key] = type(alpha) == "number" and alpha or 1
        end
        target[bar.key] = Wanted(bar, mode, shared)
      end
      if MOUSE_MODES[mode] then
        polling = true
      end
    end
  end
  state.polling = polling
end

-- One step of every fade; true while any bar is still on its way.
local function Step(elapsed)
  local moving = false
  for _, bar in ipairs(BF.BARS) do
    local key = bar.key
    local goal, now = target[key], current[key]
    if goal ~= nil and now ~= nil then
      if math.abs(now - goal) > 0.001 then
        local change = elapsed / FADE_TIME
        local alpha = now < goal and math.min(goal, now + change) or math.max(goal, now - change)
        Apply(bar, alpha)
        if math.abs(alpha - goal) > 0.001 then
          moving = true
        end
      end
      if math.abs(current[key] - goal) <= 0.001 and BF.Mode(key) == "always" then
        -- back on Always and at full: left to Blizzard again
        current[key], target[key] = nil, nil
        SetBling(bar, 1)
      end
    end
  end
  return moving
end

local function OnUpdate(self, elapsed)
  state.clock = state.clock + elapsed
  state.pollTimer = state.pollTimer + elapsed
  if state.dirty or (state.polling and state.pollTimer >= POLL) then
    state.pollTimer = 0
    Evaluate()
  end
  local moving = Step(elapsed)
  state.fading = moving
  -- lingering after the mouse left is part of polling
  if not moving and not state.polling and not state.dirty then
    self:SetScript("OnUpdate", nil)
    state.running = false
  end
end
BF.OnUpdate = OnUpdate

-- Something changed: read every bar again and run the driver until the fades are done.
function BF.Wake()
  if not state.active then
    return
  end
  state.dirty = true
  Evaluate()
  -- an instant first step (no time passed): only starts the fades
  if not state.running then
    state.running = true
    driver:SetScript("OnUpdate", OnUpdate)
  end
end

-- Hooks and events --------------------------------------------------------------------------------------------

-- OnShow / OnHide of Blizzard's windows: only out of combat (some are protected).
local function HookWindow(frame)
  if type(frame) ~= "table" or scriptHooked[frame] or type(frame.HookScript) ~= "function" then
    return
  end
  scriptHooked[frame] = true
  frame:HookScript("OnShow", BF.Wake)
  frame:HookScript("OnHide", BF.Wake)
end

local function HookWindows()
  if InCombatLockdown() then
    state.hooksPending = true
    return
  end
  state.hooksPending = false
  HookWindow(Field(_G.PlayerSpellsFrame, "SpellBookFrame"))
  HookWindow(_G.PlayerSpellsFrame)
  HookWindow(_G.SpellBookFrame)
  HookWindow(_G.QuickKeybindFrame)
  HookWindow(_G.EditModeManagerFrame)
end

local function ApplyCaps()
  local alpha = current.MainActionBar
  if alpha == nil then
    return
  end
  local left, right = Caps()
  setting = true
  if left then
    pcall(left.SetAlpha, left, alpha)
  end
  if right then
    pcall(right.SetAlpha, right, alpha)
  end
  setting = false
end

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "CURSOR_CHANGED",
  "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "ADDON_LOADED", "EDIT_MODE_LAYOUTS_UPDATED", "UNIT_ENTERED_VEHICLE",
  "UNIT_EXITED_VEHICLE", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_POSSESS_BAR",
  "UPDATE_BONUS_ACTIONBAR", "PET_BAR_UPDATE" }

local function OnEvent(_, event, arg)
  if event == "PLAYER_REGEN_DISABLED" then
    -- InCombatLockdown is still false during this event
    state.combat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    state.combat = false
    if state.hooksPending then
      HookWindows()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    state.combat = InCombatLockdown() and true or false
  elseif event == "CURSOR_CHANGED" then
    state.dragging = type(GetCursorInfo) == "function" and GetCursorInfo() ~= nil or false
  elseif event == "ACTIONBAR_SHOWGRID" then
    state.grid = true
  elseif event == "ACTIONBAR_HIDEGRID" then
    state.grid = false
    state.dragging = type(GetCursorInfo) == "function" and GetCursorInfo() ~= nil or false
  elseif event == "ADDON_LOADED" then
    if arg == "Blizzard_PlayerSpells" or arg == "Blizzard_QuickKeybind" or arg == "Blizzard_EditMode" then
      HookWindows()
    end
    return
  end
  BF.Wake()
end

local function EditModeCallback(on)
  return function()
    state.editMode = on
    BF.Wake()
  end
end

-- Once a bar fades: the driver, events and hooks (never undone; with every bar back on Always they cost
-- nothing but an event now and then).
function BF.Activate()
  if state.active then
    return
  end
  state.active = true
  state.combat = (InCombatLockdown() or (type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player")))
    and true or false
  state.dragging = type(GetCursorInfo) == "function" and GetCursorInfo() ~= nil or false
  driver = CreateFrame("Frame")
  BF.driver = driver
  for _, event in ipairs(EVENTS) do
    pcall(driver.RegisterEvent, driver, event)
  end
  driver:SetScript("OnEvent", OnEvent)
  local registry = _G.EventRegistry
  if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
    pcall(registry.RegisterCallback, registry, "EditMode.Enter", EditModeCallback(true), BF)
    pcall(registry.RegisterCallback, registry, "EditMode.Exit", EditModeCallback(false), BF)
    pcall(registry.RegisterCallback, registry, "QuickKeybindFrame.QuickKeybindModeEnabled",
      function() state.keybind = true BF.Wake() end, driver)
    pcall(registry.RegisterCallback, registry, "QuickKeybindFrame.QuickKeybindModeDisabled",
      function() state.keybind = false BF.Wake() end, driver)
  end
  local main = _G.MainActionBar
  if type(main) == "table" and type(main.UpdateEndCaps) == "function" then
    hooksecurefunc(main, "UpdateEndCaps", ApplyCaps)
  end
  HookWindows()
  BF.Wake()
end

-- Settings -----------------------------------------------------------------------------------------------------

function BF.SetMode(key, mode)
  if not BAR_BY_KEY[key] or not MODE_NAME[mode] then
    return
  end
  BF.DB().bars[key] = mode ~= "always" and mode or nil
  if mode ~= "always" then
    BF.Activate()
  end
  BF.Wake()
  ns.Fire("BARFADE_CHANGED")
end

function BF.SetFaded(value)
  value = math.floor((tonumber(value) or 0) * 20 + 0.5) / 20 -- steps of 5%
  BF.DB().faded = math.max(0, math.min(MAX_FADED, value))
  BF.Wake()
  ns.Fire("BARFADE_CHANGED")
end

function BF.SetPreview(on)
  state.preview = on and true or false
  if on then
    BF.Activate()
  end
  BF.Wake()
  ns.Fire("BARFADE_CHANGED")
end

function BF.Enable()
  BF.DB()
  BF.running = true
  if BF.FadingCount() > 0 then
    BF.Activate()
  end
end
