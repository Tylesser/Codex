local addonName, ns = ...

-- Commerce module, part 10b: the window beside the auction house (2026-11-28, the user's request: Commerce Authority
-- as a side panel of the auction house). When the auction house opens, the Commerce window opens docked to its
-- right edge, right of the Codex auction panel when that shows (option `auctionDock`), and closes with it; a
-- "Commerce Authority" button on that edge opens it when it is closed. Dragging it, or closing it, gives it back its
-- own place. No tab: tabs on Blizzard's auction house frame are its own. Everything is parented to UIParent and
-- only anchored to the auction house, so nothing of ours becomes a child of Blizzard's frame.
-- (Commerce Authority's Dock.lua twin.)

local C = ns.commerce
local L = ns.L
local UI = ns.UI

local dock = { docked = false, byAH = false }
local button

local function Host()
  if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
    return AuctionHouseFrame
  end
  return nil
end

-- What sits on the auction house's right edge: the Codex auction panel when it shows, else the AH itself.
local function Edge(host)
  local A = ns.auction
  local panel = A and A.Panel and A.Panel()
  if panel and panel:IsShown() then
    return panel
  end
  return host
end

local function UpdateButton()
  if not button then
    return
  end
  local window = C.Window()
  local host = Host()
  if host and C.running and not (window and window:IsShown()) then
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", Edge(host), "TOPRIGHT", 4, -6)
    button:Show()
  else
    button:Hide()
  end
end

local function WatchWindow(window)
  if window.dockWatched then
    return
  end
  window.dockWatched = true
  window:HookScript("OnShow", UpdateButton)
  window:HookScript("OnHide", function()
    if dock.docked then
      dock.docked, dock.byAH = false, false
      C.RestoreWindowPosition()
    end
    UpdateButton()
  end)
  -- moved by the player: their place now, and it stays open when the auction house closes
  window:HookScript("OnDragStop", function()
    dock.docked, dock.byAH = false, false
  end)
end

-- Opens the window docked beside the open auction house. Returns true when it did.
function C.DockWindow()
  local host = Host()
  if not (host and C.running) then
    return false
  end
  local window = C.EnsureWindow()
  WatchWindow(window)
  window:ClearAllPoints()
  window:SetPoint("TOPLEFT", Edge(host), "TOPRIGHT", 4, 0)
  dock.docked, dock.byAH = true, true
  window:Show()
  UpdateButton()
  return true
end

function C.WindowDocked()
  return dock.docked
end

function C.DockButton()
  return button
end

local function CreateButton()
  if button then
    return
  end
  button = UI.Button(UIParent, 170, 24, "Commerce Authority")
  button:SetFrameStrata("HIGH")
  button:Hide()
  button:SetScript("OnClick", function()
    C.DockWindow()
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Commerce Authority")
    GameTooltip:AddLine(L["Opens the window beside the auction house: the crates you have to fill, your writs and the cheapest writs. Click one to search for it here."],
      0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

-- The auction house's frame (and the Codex panel) can appear a moment after the event: one frame later.
local function Show()
  if not (Host() and C.running) then
    return
  end
  CreateButton()
  local window = C.Window()
  if C.DB().auctionDock and not (window and window:IsShown()) then
    C.DockWindow()
  end
  UpdateButton()
end

function C.OnAuctionHouseShow()
  C_Timer.After(0, Show)
end

function C.OnAuctionHouseClosed()
  local window = C.Window()
  if window and dock.docked and dock.byAH then
    window:Hide() -- (OnHide gives it back its own place)
  end
  if button then
    button:Hide()
  end
end
