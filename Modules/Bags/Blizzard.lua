local addonName, ns = ...

-- Bags module, part 4: the game's bag windows. With "Open Codex bags instead of the game's" on, the game
-- still opens and closes its own bag windows exactly as before (bag keys, bag buttons, the keyring, vendors,
-- the mailbox): nothing of Blizzard's is replaced or called for layout. Each of its windows that holds a
-- carried bag is parked off the screen and made invisible while it is open (FlareUI parks Forever's reagent
-- bag window the same way, Bags.lua ParkReagentWindow), and the Codex window follows whether any of them is
-- open. Closing the Codex window closes them. Bank bag windows are left alone.

local B = ns.bags

local unpack = unpack or table.unpack
local parked = {} -- [frame] = its clamped-to-screen setting before parking
local syncing = false

local function GameFrames()
  local list = {}
  if ContainerFrameCombinedBags then
    list[#list + 1] = ContainerFrameCombinedBags
  end
  for index = 1, NUM_CONTAINER_FRAMES or 13 do
    local frame = _G["ContainerFrame" .. index]
    if type(frame) == "table" and frame.GetID then
      list[#list + 1] = frame
    end
  end
  return list
end

-- Does this game window show one of the carried bags (the combined backpack always does)?
local function HoldsCarried(frame)
  if frame == ContainerFrameCombinedBags then
    return true
  end
  local id = frame:GetID()
  return B.Readable(id) and B.IsCarried(id)
end

local panels = {} -- [frame] = its points before parking, for the game's UI panels (bank, guild bank)

local function Park(frame)
  if parked[frame] == nil then
    parked[frame] = frame:IsClampedToScreen() and true or false
  end
  frame:SetClampedToScreen(false)
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -4000, 0)
  frame:SetAlpha(0)
end

-- Back to normal: the game places it again the next time it opens.
local function Unpark(frame)
  if parked[frame] ~= nil then
    frame:SetClampedToScreen(parked[frame])
    frame:SetAlpha(1)
    parked[frame] = nil
  end
end

function B.IsParked(frame)
  return parked[frame] ~= nil
end

-- The game's bank and guild bank windows are UI panels: they stay open (shown, so the game's bank logic
-- keeps working, and closing them ends the visit) but are parked like the bag windows. Their points are
-- kept, so unparking puts them back where the game had them, and they are parked again whenever the game
-- lays out its panels.
function B.ParkPanel(frame)
  if type(frame) ~= "table" or not frame.ClearAllPoints then
    return
  end
  if not panels[frame] then
    local points = {}
    for index = 1, 5 do
      local point = { frame:GetPoint(index) }
      if #point == 0 then
        break
      end
      points[#points + 1] = point
    end
    panels[frame] = points
  end
  Park(frame)
end

function B.UnparkPanel(frame)
  local points = type(frame) == "table" and panels[frame]
  if not points then
    return
  end
  panels[frame] = nil
  Unpark(frame)
  frame:ClearAllPoints()
  for _, point in ipairs(points) do
    frame:SetPoint(unpack(point))
  end
  if type(UpdateUIPanelPositions) == "function" then
    pcall(UpdateUIPanelPositions, frame)
  end
end

local function ReparkPanels()
  for frame in pairs(panels) do
    if frame:IsShown() and parked[frame] ~= nil then
      Park(frame)
    end
  end
end

-- Once, from Enable.
function B.InstallPanelHooks()
  if B.panelHooks then
    return
  end
  B.panelHooks = true
  if type(UpdateUIPanelPositions) == "function" then
    hooksecurefunc("UpdateUIPanelPositions", ReparkPanels)
  end
end

function B.GameBagsOpen()
  for _, frame in ipairs(GameFrames()) do
    if frame:IsShown() and HoldsCarried(frame) then
      return true
    end
  end
  return false
end

-- Every shown game window: parked when it holds a carried bag, else (a bank bag) left visible.
local function ParkAll()
  if not B.db.replace then
    return
  end
  for _, frame in ipairs(GameFrames()) do
    if frame:IsShown() and HoldsCarried(frame) then
      Park(frame)
    elseif parked[frame] ~= nil then
      Unpark(frame)
    end
  end
end
B.ParkAll = ParkAll

-- The Codex window is open exactly while one of the game's bag windows is.
function B.SyncWithGame()
  if not B.db.replace then
    return
  end
  local window = B.Window() or B.CreateWindow()
  if not window then
    return -- not made yet (a fight at login): the game's bags show meanwhile
  end
  local open = B.GameBagsOpen()
  if open ~= window:IsShown() then
    syncing = true
    window:SetShown(open)
    syncing = false
  end
end

-- Closing the Codex window (its x, Escape) closes the game's bag windows, so the bag key keeps toggling.
function B.CloseGameBags()
  for _, frame in ipairs(GameFrames()) do
    if frame:IsShown() and HoldsCarried(frame) then
      if frame == ContainerFrameCombinedBags then
        if CloseBackpack then
          pcall(CloseBackpack)
        end
      elseif CloseBag then
        pcall(CloseBag, frame:GetID())
      end
      if frame:IsShown() then
        frame:Hide()
      end
    end
  end
end

function B.OnWindowHidden()
  if syncing or not B.db.replace then
    return
  end
  syncing = true
  B.CloseGameBags()
  syncing = false
end

local function OnGameShow(frame)
  if B.db.replace and HoldsCarried(frame) then
    Park(frame)
  elseif parked[frame] ~= nil then
    Unpark(frame)
  end
  B.SyncWithGame()
end

local function OnGameHide()
  B.SyncWithGame()
end

-- Once, from Enable. Every hook checks the option, so switching it needs no reload.
function B.InstallGameHooks()
  if B.gameHooks then
    return
  end
  B.gameHooks = true
  for _, frame in ipairs(GameFrames()) do
    frame:HookScript("OnShow", OnGameShow)
    frame:HookScript("OnHide", OnGameHide)
  end
  -- the game places its bag windows after opening them: park ours again right after
  if type(UpdateContainerFrameAnchors) == "function" then
    hooksecurefunc("UpdateContainerFrameAnchors", ParkAll)
  end
  for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBackpack",
    "CloseBackpack", "ToggleBag", "ToggleBackpack_Combined" }) do
    if type(_G[name]) == "function" then
      hooksecurefunc(name, function()
        B.SyncWithGame()
      end)
    end
  end
end

-- The option was switched: off gives the game's windows back (closed, so the game places them on the next
-- open); on parks the ones open now.
function B.SetReplace(on)
  B.db.replace = on and true or false
  if on then
    ParkAll()
    B.SyncWithGame()
  else
    local open = B.GameBagsOpen()
    for frame in pairs(parked) do
      Unpark(frame)
    end
    if open then
      B.CloseGameBags()
    end
    local window = B.Window()
    if window then
      window:Hide()
    end
  end
end
