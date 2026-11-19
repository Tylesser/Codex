local addonName, ns = ...

-- Move windows module, part 1: dragging the game's windows. Every window Blizzard registers as a panel
-- (UIPanelWindows) plus the bags and a list of others gets an invisible drag strip of Codex's own over
-- the top of the window (the title bar), short of the close button. Dragging the strip moves the
-- window; right-clicking it puts the window back. Windows that come with load-on-demand addons are picked
-- up when those load.
--
-- Taint: nothing is written onto Blizzard's frames and none of their scripts are replaced (OnShow /
-- OnHide are post-hooked); all state lives in tables here. Positions go back after Blizzard places a
-- window (its OnShow, the panel manager's UpdateUIPanelPositions, the bags' UpdateContainerFrameAnchors).
-- Protected windows are only touched out of combat; Edit Mode systems are never touched.
-- (FlareUI's "Move any frame", MIT, Modules/Tweaks.lua, was read for the pitfalls: excluded windows, the
-- maximised map, re-applying after the panel manager.)

local MW = {}
ns.movewindows = MW

local unpack = unpack or table.unpack

local STRIP_HEIGHT = 24
local RIGHT_ROOM = 60 -- the close button (and a maximise / minimise button beside it) stay clickable
local PORTRAIT_ROOM = 54 -- a bag's portrait button (its menu) stays clickable
local LEVEL_ABOVE = 20 -- above the window's own title art and the frames lying over it

-- Windows that are not panels, or come with addons, by name (Forever).
local EXTRA = { "ContainerFrameCombinedBags", "CharacterFrame", "PlayerSpellsFrame", "ProfessionsFrame",
  "ProfessionsBookFrame", "FriendsFrame", "MerchantFrame", "BankFrame", "GuildBankFrame", "MailFrame", "OpenMailFrame",
  "GossipFrame", "QuestFrame", "TradeFrame", "ClassTrainerFrame", "AuctionHouseFrame", "InspectFrame", "MacroFrame",
  "CommunitiesFrame", "CollectionsJournal", "EncounterJournal", "AchievementFrame", "TabardFrame", "PetitionFrame",
  "GuildRegistrarFrame", "TaxiFrame", "StableFrame", "PetStableFrame", "LFGParentFrame", "PVEFrame",
  "GroupLootHistoryFrame", "DressUpFrame", "ItemTextFrame", "TimeManagerFrame", "ModelPreviewFrame", "AddonList",
  "CooldownViewerSettings", "ChannelFrame" }
MW.EXTRA = EXTRA

-- Left where Blizzard puts them: the world map (it maximises and places itself), Edit Mode's window and
-- the loot window (Edit Mode systems), the game menu and settings (they hold protected buttons), the
-- group finder's pages (they belong inside their window).
local EXCLUDED = { WorldMapFrame = true, EditModeManagerFrame = true, LootFrame = true, GameMenuFrame = true,
  SettingsPanel = true, HelpFrame = true, ChatConfigFrame = true, LFGBrowseFrame = true, LFGListingFrame = true,
  LFGWhoListFrame = true }
MW.EXCLUDED = EXCLUDED

local DEFAULTS = { remember = false, positions = {} }

local windows = {} -- [name] = window, set up
local states = setmetatable({}, { __mode = "k" }) -- [window] = { name, handle, original, clamped, dragging, ... }
local positions = {} -- [name] = { x, y }: TOPLEFT of the window from UIParent's BOTTOMLEFT, this session
local pendingSetup = {} -- [name] = true: protected windows that turned up during a fight
local pendingApply = {} -- [window] = true: protected windows to put back when the fight ends
local warned = false -- one combat note per fight
local applyQueued = false

MW.windows = windows
MW.positions = positions

function MW.DB()
  if not MW.db then
    ns.db.movewindows = ns.Fill(ns.db.movewindows or {}, DEFAULTS)
    MW.db = ns.db.movewindows
  end
  return MW.db
end

local function Locked(window)
  return InCombatLockdown() and window:IsProtected() and true or false
end

local function Usable(window)
  return type(window) == "table" and type(window.GetObjectType) == "function"
    and type(window.StartMoving) == "function" and not (window.IsForbidden and window:IsForbidden())
end

-- An Edit Mode system (each carries its system id): Edit Mode moves it, addon code must not.
local function IsEditModeSystem(window)
  if window.system ~= nil then
    return true
  end
  local manager = EditModeManagerFrame
  local list = type(manager) == "table" and manager.registeredSystemFrames
  if type(list) == "table" then
    for _, frame in ipairs(list) do
      if frame == window then
        return true
      end
    end
  end
  return false
end

local function FullScreenPanel(name)
  local info = type(UIPanelWindows) == "table" and UIPanelWindows[name]
  return type(info) == "table" and info.area == "full"
end

local function Maximised(window)
  return type(window.IsMaximized) == "function" and window:IsMaximized() == true
end

-- Codex's bags park the game's bag windows off screen while they stand in for them: leave those alone.
local function Parked(window)
  local bags = ns.bags
  return bags and type(bags.IsParked) == "function" and bags.IsParked(window) or false
end

local function Copy(pos)
  return { x = pos.x, y = pos.y }
end

-- Keeps the whole window on the screen (in the window's own scale).
local function Clamp(window, x, y)
  local scale = window:GetEffectiveScale() or 1
  local parentScale = UIParent:GetEffectiveScale() or 1
  local ratio = scale > 0 and parentScale / scale or 1
  local screenW, screenH = (UIParent:GetWidth() or 0) * ratio, (UIParent:GetHeight() or 0) * ratio
  local w, h = window:GetWidth() or 0, window:GetHeight() or 0
  if screenW > 0 then
    x = math.max(0, math.min(x, screenW - w))
  end
  if screenH > 0 then
    y = math.min(screenH, math.max(y, math.min(h, screenH)))
  end
  return x, y
end

-- Blizzard's anchors before Codex first moved the window, so a reset can put them back.
local function KeepOriginal(window, state)
  if state.original then
    return
  end
  local points = {}
  for index = 1, (window.GetNumPoints and window:GetNumPoints() or 1) do
    local point = { window:GetPoint(index) }
    if point[1] then
      points[#points + 1] = point
    end
  end
  state.original = points
end

-- Puts a window where the player left it (if they moved it this session, or saved it).
local function Apply(window)
  local state = states[window]
  local pos = state and positions[state.name]
  if not pos or state.dragging or not window:IsShown() or Parked(window) or Maximised(window) then
    return
  end
  if Locked(window) then
    pendingApply[window] = true
    return
  end
  local x, y = Clamp(window, pos.x, pos.y)
  local left, top = window:GetLeft(), window:GetTop()
  if left and top and math.abs(left - x) < 0.5 and math.abs(top - y) < 0.5 then
    return
  end
  KeepOriginal(window, state)
  window:ClearAllPoints()
  window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end
MW.Apply = Apply

local function ApplyAll()
  for _, window in pairs(windows) do
    Apply(window)
  end
end

-- Now, and once more on the next frame for anything that places a window after the hooks ran.
local function ApplyAllSoon()
  ApplyAll()
  if applyQueued then
    return
  end
  applyQueued = true
  C_Timer.After(0, function()
    applyQueued = false
    ApplyAll()
  end)
end
MW.ApplyAllSoon = ApplyAllSoon

local function Save(name, pos)
  positions[name] = pos
  local db = MW.DB()
  if db.remember then
    db.positions[name] = pos and Copy(pos) or nil
  end
  ns.Fire("MOVEWINDOWS_CHANGED")
end

-- Dragging --------------------------------------------------------------------------------------------------

local function StartDrag(window)
  local state = states[window]
  if not state or state.dragging or Maximised(window) or Parked(window) then
    return
  end
  if Locked(window) then
    if not warned then
      warned = true
      ns.Say("This window can't be moved during a fight.")
    end
    return
  end
  KeepOriginal(window, state)
  state.startLeft, state.startTop = window:GetLeft(), window:GetTop()
  state.clamped = window:IsClampedToScreen() and true or false
  if not window:IsMovable() then
    window:SetMovable(true)
  end
  window:SetClampedToScreen(true)
  state.dragging = true
  window:StartMoving()
end
MW.StartDrag = StartDrag

local function StopDrag(window)
  local state = states[window]
  if not state or not state.dragging then
    return
  end
  state.dragging = false
  if Locked(window) then
    return -- hidden by a fight starting mid-drag: the client has let go already
  end
  window:StopMovingOrSizing()
  -- Codex remembers the place itself: the client must not save it per character (layout-local.txt),
  -- and the panel manager keeps placing the window as before.
  window:SetUserPlaced(false)
  window:SetClampedToScreen(state.clamped)
  local left, top = window:GetLeft(), window:GetTop()
  if not (left and top) then
    return
  end
  local moved = not (state.startLeft and state.startTop)
    or math.abs(left - state.startLeft) >= 1 or math.abs(top - state.startTop) >= 1
  if not moved then
    return -- a click, not a drag: Blizzard keeps placing it
  end
  left, top = math.floor(left + 0.5), math.floor(top + 0.5)
  window:ClearAllPoints()
  window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  Save(state.name, { x = left, y = top })
end
MW.StopDrag = StopDrag

-- Back to Blizzard's place: the anchors it had before the first move. Next time the window opens
-- Blizzard places it as usual.
local function Restore(window)
  local state = states[window]
  if not state or not state.original or #state.original == 0 or not window:IsShown() or Locked(window) or Parked(window) then
    return
  end
  window:ClearAllPoints()
  for _, point in ipairs(state.original) do
    window:SetPoint(unpack(point))
  end
end

function MW.Reset(name)
  Save(name, nil)
  local window = windows[name]
  if window then
    Restore(window)
  end
end

function MW.ResetAll()
  for name in pairs(positions) do
    positions[name] = nil
  end
  local db = MW.DB()
  for name in pairs(db.positions) do
    db.positions[name] = nil
  end
  for _, window in pairs(windows) do
    Restore(window)
  end
  ns.Fire("MOVEWINDOWS_CHANGED")
end

function MW.SetRemember(on)
  local db = MW.DB()
  db.remember = on and true or false
  for name in pairs(db.positions) do
    db.positions[name] = nil
  end
  if db.remember then
    for name, pos in pairs(positions) do
      db.positions[name] = Copy(pos)
    end
  end
  ns.Fire("MOVEWINDOWS_CHANGED")
end

function MW.MovedCount()
  local count = 0
  for _ in pairs(positions) do
    count = count + 1
  end
  return count
end

function MW.WindowCount()
  local count = 0
  for _ in pairs(windows) do
    count = count + 1
  end
  return count
end

-- Setting windows up --------------------------------------------------------------------------------------

local function MakeHandle(window)
  local handle = CreateFrame("Frame", nil, window)
  local left = type(window.PortraitButton) == "table" and PORTRAIT_ROOM or 0
  handle:SetPoint("TOPLEFT", window, "TOPLEFT", left, 0)
  handle:SetPoint("TOPRIGHT", window, "TOPRIGHT", -RIGHT_ROOM, 0)
  handle:SetHeight(STRIP_HEIGHT)
  handle:SetFrameLevel((window:GetFrameLevel() or 1) + LEVEL_ABOVE)
  handle:EnableMouse(true)
  handle:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      StartDrag(window)
    end
  end)
  handle:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      StopDrag(window)
    elseif button == "RightButton" then
      local state = states[window]
      if state and positions[state.name] then
        MW.Reset(state.name)
      end
    end
  end)
  -- the window closed mid-drag (walked away from a vendor): the drag ends where it was let go
  handle:SetScript("OnHide", function()
    StopDrag(window)
  end)
  handle:SetScript("OnEnter", function(self)
    local state = states[window]
    if state and positions[state.name] then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Drag to move. Right-click: back to its usual place.")
      GameTooltip:Show()
    end
  end)
  handle:SetScript("OnLeave", GameTooltip_Hide)
  return handle
end

local function Setup(name)
  if windows[name] or EXCLUDED[name] or FullScreenPanel(name) then
    return
  end
  local window = _G[name]
  if not Usable(window) or IsEditModeSystem(window) then
    return
  end
  if InCombatLockdown() and window:IsProtected() then
    pendingSetup[name] = true
    return
  end
  pendingSetup[name] = nil
  windows[name] = window
  states[window] = { name = name }
  states[window].handle = MakeHandle(window)
  -- Blizzard has placed the window by its OnShow: the moved position goes back before it draws
  window:HookScript("OnShow", function(self)
    Apply(self)
    C_Timer.After(0, function()
      Apply(self)
    end)
  end)
  Apply(window)
end
MW.Setup = Setup

local function Scan()
  if type(UIPanelWindows) == "table" then
    for name in pairs(UIPanelWindows) do
      if type(name) == "string" then
        Setup(name)
      end
    end
  end
  for _, name in ipairs(EXTRA) do
    Setup(name)
  end
  for index = 1, (type(NUM_CONTAINER_FRAMES) == "number" and NUM_CONTAINER_FRAMES or 13) do
    Setup("ContainerFrame" .. index)
  end
end
MW.Scan = Scan

local function OnEvent(_, event)
  if event == "ADDON_LOADED" then
    -- a load-on-demand addon registers its panels while it loads: looked for once it is done
    C_Timer.After(0, Scan)
  elseif event == "PLAYER_REGEN_ENABLED" then
    warned = false
    for name in pairs(pendingSetup) do
      Setup(name)
    end
    for window in pairs(pendingApply) do
      pendingApply[window] = nil
      Apply(window)
    end
  end
end

function MW.Enable()
  local db = MW.DB()
  if db.remember then
    for name, pos in pairs(db.positions) do
      if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        positions[name] = Copy(pos)
      end
    end
  end
  Scan()
  if type(UpdateUIPanelPositions) == "function" then
    hooksecurefunc("UpdateUIPanelPositions", ApplyAllSoon)
  end
  if type(UpdateContainerFrameAnchors) == "function" then
    hooksecurefunc("UpdateContainerFrameAnchors", function()
      Scan()
      ApplyAllSoon()
    end)
  end
  local events = CreateFrame("Frame")
  events:RegisterEvent("ADDON_LOADED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:SetScript("OnEvent", OnEvent)
  MW.eventFrame = events
  MW.running = true
end
