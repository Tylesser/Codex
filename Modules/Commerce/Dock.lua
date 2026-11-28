local addonName, ns = ...

-- Commerce module, part 10b: the window beside the auction house (2026-11-28, the user's request: Commerce Authority
-- as a side panel of the auction house). When the auction house opens, the Commerce window opens docked to its
-- right edge, right of the Codex auction panel when that shows, and closes with it. It opens from the
-- "Commerce Authority" tab in the auction house's tab row (below), or by itself when the auction house opens with
-- the option `auctionDock` (off by default since 1.19.2: the user wanted it only on request). Dragging it, or
-- closing it, gives it back its own place. The window and the edge button are parented to UIParent and only
-- anchored to the auction house; the tab's holder is a child of the auction house, outside its Tabs list.
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


-- The tab (2026-11-28, the user's request: the window only when they want it, from a tab of the auction house).
-- It sits in the auction house's tab row, after Blizzard's tabs and after the ones Auctionator adds
-- (LibAHTab-1-0), and opens or closes the window beside the auction house; what the auction house shows stays as
-- it is. Like LibAHTab's tabs it lives in a holder frame of ours: Blizzard's tab template adds every tab to its
-- parent's Tabs list (PanelTabButtonTemplate, parentArray="Tabs"), and the auction house's own list must stay
-- Blizzard's. The active look is set by hand: PanelTemplates_SelectTab disables a tab, and a second click closes
-- the window. Modern auction house only (forever Blizzard_AuctionHouseUI, AuctionHouseFrameTabTemplate); the old
-- one, or a client without the template, gets the button on the auction house's edge instead.
local TAB_TEMPLATE = "AuctionHouseFrameTabTemplate"
local TAB_PADDING, TAB_MIN_WIDTH = 20, 70 -- Blizzard_AuctionHouseTab.lua's
local holder, tab

-- LibAHTab's gap between tabs: 3 on Retail and Forever, -14 on the Classic clients with this auction house.
local function TabGap()
  if WOW_PROJECT_ID and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE and WOW_PROJECT_ID ~= WOW_PROJECT_CAMELOT then
    return -14
  end
  return 3
end

-- The rightmost tab of the row: the last one Auctionator's LibAHTab added, else Blizzard's last.
local function LastTab(host)
  local tabs = host.Tabs
  local last = type(tabs) == "table" and tabs[#tabs] or nil
  local lib = type(LibStub) == "table" and LibStub("LibAHTab-1-0", true)
  local state = type(lib) == "table" and lib.internalState
  local extra = type(state) == "table" and state.Tabs
  if type(extra) == "table" and extra[#extra] then
    last = extra[#extra]
  end
  return last
end

local function TabActive(active)
  if not tab then
    return
  end
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    local normal, lit = tab[key], tab[key .. "Active"]
    if normal and lit then
      normal:SetShown(not active)
      lit:SetShown(active)
    end
  end
  if tab.Text then
    tab.Text:ClearAllPoints()
    tab.Text:SetPoint("CENTER", tab, "CENTER", 0, active and -3 or 2)
  end
  if GameFontHighlightSmall and GameFontNormalSmall then
    tab:SetNormalFontObject(active and GameFontHighlightSmall or GameFontNormalSmall)
  end
end

local function CreateTab(host)
  if tab or holder then
    return tab
  end
  if host ~= AuctionHouseFrame then
    return nil
  end
  holder = CreateFrame("Frame", nil, host)
  holder:SetSize(10, 10)
  holder.tabPadding, holder.minTabWidth = TAB_PADDING, TAB_MIN_WIDTH -- what the template's OnShow resizes with
  local ok, made = pcall(CreateFrame, "Button", nil, holder, TAB_TEMPLATE)
  if not ok or type(made) ~= "table" or not made.Text then
    holder:Hide()
    return nil
  end
  tab = made
  tab:SetText("Commerce Authority")
  if PanelTemplates_TabResize then
    pcall(PanelTemplates_TabResize, tab, TAB_PADDING, nil, TAB_MIN_WIDTH)
  end
  local inset = (math.abs(TabGap()) - 3) / 2
  tab:SetHitRectInsets(inset, inset, 0, 0)
  TabActive(false)
  tab:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
      PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end
    C.ToggleDock()
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Commerce Authority")
    GameTooltip:AddLine(L["Opens the window beside the auction house: the crates you have to fill, your writs and the cheapest writs. Click one to search for it here."],
      0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", GameTooltip_Hide)
  return tab
end

-- After the row's last tab, each time the auction house opens (Auctionator makes its tabs when it first opens).
local function PlaceTab(host)
  local last = tab and LastTab(host)
  if not last then
    if holder then
      holder:Hide()
    end
    return false
  end
  holder:ClearAllPoints()
  holder:SetPoint("TOPLEFT", last, "TOPRIGHT", 0, 0)
  tab:ClearAllPoints()
  tab:SetPoint("TOPLEFT", holder, "TOPLEFT", TabGap(), 0)
  holder:Show()
  tab:Show()
  return true
end

-- The tab's look, and the edge button (only where there is no tab) while the window is closed.
local function UpdateButton()
  local window = C.Window()
  local open = window and window:IsShown() and true or false
  TabActive(open and dock.docked)
  if not button then
    return
  end
  local host = Host()
  if host and C.running and not open and not (holder and holder:IsVisible()) then
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
    UpdateButton()
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

-- The tab's click: closes the window when it is open beside the auction house, else opens it there.
function C.ToggleDock()
  local window = C.Window()
  if window and window:IsShown() and dock.docked then
    window:Hide()
    return false
  end
  return C.DockWindow()
end

function C.DockTab()
  return tab
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
    if holder then
      holder:Hide()
    end
    return
  end
  if not PlaceTab(Host()) and not (CreateTab(Host()) and PlaceTab(Host())) then
    CreateButton()
  end
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
