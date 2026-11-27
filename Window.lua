local addonName, ns = ...
local L = ns.L

-- The Codex window: title bar, a sidebar (a search box, Home, one page per part of the game, General, Look and
-- Profiles) and the selected page. Every page but Home is one scrolling page of foldable sections (Areas.lua).

local UI = ns.UI
local BASE_WIDTH, HEIGHT, SIDE = 920, 610, 200
-- the info panel (Info.lua) on the right: the window grows by its width and the gap, the pages keep theirs
local INFO_GAP = 14
ns.INFO_WIDTH = 262 -- the info panel (Info.lua)
local WIDTH = BASE_WIDTH + ns.INFO_WIDTH + INFO_GAP
-- The page area's size (pages are built before the window has been laid out, so they read these). AREA_WIDTH is
-- the whole page (Home, an area page); PAGE_WIDTH is what a module's own page gets inside its section (Areas.lua:
-- the page less the scroll thumb's room and the section's indent), the width module builders lay themselves out in.
ns.AREA_WIDTH = BASE_WIDTH - 10 - SIDE - 38
ns.PAGE_WIDTH = ns.AREA_WIDTH - 14 - 18
ns.PAGE_HEIGHT = HEIGHT - 80

-- The sidebar lists the areas (Areas.lua, ns.AREAS): Home, the parts of the game, then General, Look and
-- Profiles under a line. A search box on top finds any option (Search.lua).

local window
local pages = {}
local navButtons = {}

ns.builtinPages = ns.builtinPages or {} -- [id] = { name, icon, Build(page), Show(page) }: Home and the area pages

local function SavePosition(self)
  local point, _, relativePoint, x, y = self:GetPoint()
  ns.db.window = { point, relativePoint, x, y }
end

local function PageInfo(id)
  return ns.builtinPages[id]
end

local function CreatePage(id)
  local info = PageInfo(id)
  local page = CreateFrame("Frame", nil, window.content)
  page:SetAllPoints()
  page.id = id
  pages[id] = page
  local build = info.Build or info.BuildPage
  if build then
    local ok, err = pcall(build, info, page)
    if not ok then
      geterrorhandler()(err)
      local text = UI.Text(page, "body", 13, "bad")
      text:SetPoint("TOPLEFT", 4, -4)
      text:SetText(L["This page failed to load: %s"]:format(tostring(err)))
    end
  end
  return page
end

-- The page of an area, built (hidden unless it is the one shown). The search builds every page this way.
function ns.EnsurePage(id)
  if not window then
    ns.CreateWindow()
  end
  if not PageInfo(id) then
    return nil
  end
  local page = pages[id]
  if not page then
    page = CreatePage(id)
    if window.current ~= id then
      page:Hide()
    end
  end
  return page
end

-- Shows a page. `id` is an area ("bars", "look", ...), a module or section id (its area opens at that section,
-- unfolded, scrolled to and marked; `widget` = a widget inside it to scroll to instead), or an old name
-- ("settings"). Anything unknown goes Home. window.current is the area, window.section the section.
function ns.ShowPage(id, widget)
  if not window then
    ns.CreateWindow()
  end
  local area, sectionId = ns.ResolvePage(id)
  if not area or not PageInfo(area) then
    area, sectionId = "home", nil
  end
  for pageID, page in pairs(pages) do
    page:SetShown(pageID == area)
  end
  local page = pages[area] or CreatePage(area)
  page:Show()
  for buttonID, button in pairs(navButtons) do
    button:SetSelected(buttonID == area)
  end
  window.current = area
  window.section = sectionId
  window:Show()
  local info = PageInfo(area)
  local show = info.Show or info.ShowPage
  if show then
    local ok, err = pcall(show, info, page)
    if not ok then
      geterrorhandler()(err)
    end
  end
  if type(ns.InfoForPage) == "function" then
    local section = sectionId and ns.SectionFrame and ns.SectionFrame(sectionId)
    if section and type(ns.InfoHover) == "function" then
      ns.InfoHover(section)
    else
      ns.InfoForPage(page.sections and page or nil, ns.AREA_BY_ID and ns.AREA_BY_ID[area])
    end
  end
  if sectionId then
    ns.FocusSection(sectionId, widget)
  end
  if type(ns.ClearSearchFocus) == "function" then
    ns.ClearSearchFocus()
  end
end

-- Opens Settings' old tabs: "modules" (Home), "look", "interface" (General), "profiles".
function ns.ShowSettings(tab)
  ns.ShowPage(tab and (ns.PAGE_ALIASES[tab] or tab) or "general")
end

function ns.RefreshNav()
  if not window then
    return
  end
  window.banner:SetShown(ns.pendingReload)
  window.PlaceContent(ns.pendingReload)
  ns.UpdateReloadOverlay()
end

local function CreateBanner()
  -- a strip under the page (the page area shrinks while it shows), never over the page's text
  local banner = CreateFrame("Frame", nil, window)
  banner:SetPoint("BOTTOMLEFT", window.side, "BOTTOMRIGHT", 18, 14)
  banner:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, -44)
  banner:SetHeight(34)
  banner:SetFrameLevel(window.content:GetFrameLevel() + 20)
  UI.Inset(window, banner)
  local warn = ns.Theme().warn
  local radius = UI.Radius("box")
  if radius then
    UI.RoundFill(banner, banner, radius, { warn[1], warn[2], warn[3], 0.12 }, { layer = "ARTWORK" })
  else
    local fill = banner:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    UI.SetColor(fill, warn, 0.12)
  end
  local text = UI.Text(banner, "body", 12, "bright")
  text:SetPoint("LEFT", 12, 0)
  text:SetText(L["Your changes take effect after a reload."])
  local reload = UI.Button(banner, 110, 24, L["Reload now"])
  reload:SetPoint("RIGHT", -6, 0)
  -- only reached in combat or when the secure button could not be made: the overlay takes the click
  reload:SetScript("OnClick", function()
    ns.Say(InCombatLockdown() and L["type /reload after the fight to apply your changes."]
      or L["type /reload to apply your changes."])
  end)
  banner.reload = reload
  banner:Hide()
  banner:HookScript("OnShow", ns.UpdateReloadOverlay)
  banner:HookScript("OnHide", ns.UpdateReloadOverlay)
  window.banner = banner
end

-- ReloadUI is protected on Forever. A secure macro button ("/reload") is laid over the banner's Reload
-- button out of combat. It is parented to UIParent, not to the window: a secure child would make the
-- Codex window protected, so it could not be closed in combat. When a fight starts it is hidden and
-- unanchored (still allowed in PLAYER_REGEN_DISABLED) and the plain button below says to type /reload.
local overlay
local function Overlay()
  if overlay or InCombatLockdown() then
    return overlay
  end
  overlay = CreateFrame("Button", "CodexReloadButton", UIParent, "SecureActionButtonTemplate")
  overlay:SetAttribute("type", "macro")
  overlay:SetAttribute("macrotext", "/stopmacro [combat]\n/reload")
  overlay:RegisterForClicks("AnyUp", "AnyDown")
  local glow = overlay:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints()
  UI.SetColor(glow, ns.Theme().button.hover or { 1, 1, 1, 0.12 })
  overlay:Hide()
  overlay:RegisterEvent("PLAYER_REGEN_DISABLED")
  overlay:RegisterEvent("PLAYER_REGEN_ENABLED")
  overlay:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
      self:Hide()
      self:ClearAllPoints()
    else
      ns.UpdateReloadOverlay()
    end
  end)
  return overlay
end

function ns.UpdateReloadOverlay()
  if InCombatLockdown() then
    return
  end
  local button = Overlay()
  if not button then
    return
  end
  local banner = window and window.banner
  if banner and window:IsShown() and banner:IsShown() then
    button:ClearAllPoints()
    button:SetAllPoints(banner.reload)
    -- one strata above the window: the window is toplevel, so with the same strata a click raises it over the
    -- secure button and the plain button below takes the click
    button:SetFrameStrata("DIALOG")
    button:Show()
  else
    button:Hide()
    button:ClearAllPoints()
  end
end

function ns.CreateWindow()
  if window then
    return window
  end
  window = CreateFrame("Frame", "CodexWindow", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetFrameStrata("HIGH")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)
  window:SetScale(ns.db.scale or 1)
  local saved = ns.db.window
  if saved then
    window:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
  else
    window:SetPoint("CENTER")
  end
  table.insert(UISpecialFrames, "CodexWindow")
  UI.Panel(window)

  -- title bar
  local theme = ns.Theme()
  local bar = CreateFrame("Frame", nil, window)
  local barHeight = theme.titlebar.height or 30
  bar:SetPoint("TOPLEFT", 5, -5)
  bar:SetPoint("TOPRIGHT", -5, -5)
  bar:SetHeight(barHeight)
  local barFill = bar:CreateTexture(nil, "BACKGROUND")
  barFill:SetAllPoints()
  UI.Gradient(barFill, theme.titlebar.from, theme.titlebar.to)
  local barLine = bar:CreateTexture(nil, "BORDER")
  barLine:SetPoint("BOTTOMLEFT")
  barLine:SetPoint("BOTTOMRIGHT")
  barLine:SetHeight(2)
  UI.SetColor(barLine, theme.titlebar.line)
  local emblem = bar:CreateTexture(nil, "ARTWORK")
  emblem:SetTexture(ns.T.EMBLEM)
  emblem:SetSize(barHeight - 4, barHeight - 4)
  emblem:SetPoint("LEFT", 6, 0)
  local title = UI.Text(bar, "head", 16, "titleText")
  title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  title:SetText(theme.titlebar.upper and "TYLESSER CODEX" or "Tylesser Codex")
  local version = UI.Text(bar, "body", 11, "muted")
  version:SetPoint("LEFT", title, "RIGHT", 8, 0)
  version:SetText(ns.VERSION)
  local close = UI.CloseButton(window)
  close:SetParent(bar)
  close:SetPoint("RIGHT", -4, 0)

  -- sidebar
  local side = CreateFrame("Frame", nil, window)
  side:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
  side:SetPoint("BOTTOMLEFT", 5, 5)
  side:SetWidth(SIDE)
  local sideFill = side:CreateTexture(nil, "BACKGROUND", nil, -6)
  sideFill:SetAllPoints()
  UI.SetColor(sideFill, theme.side)
  local sideLine = UI.Divider(side, true)
  sideLine:SetPoint("TOPRIGHT")
  sideLine:SetPoint("BOTTOMRIGHT")

  -- the search box on top, the pages under it (they scroll when the window is too short for them); while a search
  -- runs its results take the list's place
  local searchHeight = 0
  if type(ns.BuildSearch) == "function" then
    searchHeight = ns.BuildSearch(window, side, SIDE) or 0
  end
  local navScroll, nav = UI.ScrollArea(side)
  navScroll:SetPoint("TOPLEFT", 0, -searchHeight)
  navScroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -2, 8)
  nav:SetWidth(SIDE - 2)
  window.navScroll, window.nav = navScroll, nav
  local y = -4
  local function AddNav(id, icon, text, height)
    local button = UI.NavButton(nav, SIDE - 16, height, icon, text)
    button:SetPoint("TOPLEFT", 8, y)
    button:SetScript("OnClick", function()
      ns.ShowPage(id)
    end)
    if button.icon.SetTexCoord and id ~= "home" then
      button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's own border
    end
    navButtons[id] = button
    y = y - height - 1
    return button
  end
  local lined = false
  for _, area in ipairs(ns.AREAS) do
    if area.lower and not lined then
      -- General, Look and Profiles under a line
      lined = true
      local line = UI.Divider(nav)
      line:SetPoint("TOPLEFT", 16, y - 7)
      line:SetPoint("TOPRIGHT", -12, y - 7)
      y = y - 15
    end
    AddNav(area.id, area.icon, area.name, area.id == "home" and 32 or 28)
  end
  nav:SetHeight(-y + 8)
  navScroll:Update()
  window.navButtons = navButtons

  -- page area, and the info panel on its right (Info.lua)
  local content = CreateFrame("Frame", nil, window)
  window.content = content
  window.side = side
  local info = type(ns.BuildInfoPanel) == "function" and ns.BuildInfoPanel(window) or nil
  window.info = info
  local infoRoom = info and (ns.INFO_WIDTH + INFO_GAP) or 0
  if info then
    info:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -9, -14)
    info:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -14, 18)
  end
  function window.PlaceContent(bannerShown)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", side, "TOPRIGHT", 18, -14)
    content:SetPoint("BOTTOMRIGHT", -20 - infoRoom, bannerShown and 58 or 18)
  end
  window.PlaceContent(false)

  CreateBanner()
  window:Hide()
  ns.On("RELOAD_STATE", ns.RefreshNav)
  window:SetScript("OnShow", ns.RefreshNav)
  window:SetScript("OnHide", ns.UpdateReloadOverlay)
  ns.window = window
  return window
end

function ns.ToggleWindow(page)
  if window and window:IsShown() and (not page or window.current == page) then
    window:Hide()
  else
    ns.ShowPage(page or (window and window.current) or "home")
  end
end
