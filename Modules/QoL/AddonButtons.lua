local addonName, ns = ...
local L = ns.L

-- Addon buttons on the minimap in a list (the user's request, 2026-11-19): the buttons addons put round the
-- minimap (LibDBIcon's, named addon buttons such as Codex's own) are hidden, and a click on the day/night moon
-- (Forever's MinimapCluster.DielFrame, a plain frame with no click of its own: Blizzard_Minimap/Camelot/Diel.lua)
-- opens a list of them: icon and name; a click on a row does what a click on the button did (LibDataBroker's
-- OnClick for LibDBIcon buttons, anchored to the row; the button's own OnClick otherwise), hovering shows its
-- tooltip. Blizzard's own minimap buttons stay. Switched off, the buttons come back.
--
-- Hidden buttons stay hidden: a post hook on each button's Show hides it again while the toggle is on (LibDBIcon
-- shows its buttons again on refresh). Only buttons that were shown (or that their addon tried to show) are listed.

local Q = ns.qol
local UI = ns.UI
local AB = {}
Q.addonButtons = AB

local KEY = "addonButtons"
local ROW = 24
local WIDTH = 220

-- Blizzard's own buttons that a name test below would also catch
local BLIZZARD = { ExpansionLandingPageMinimapButton = true, GameTimeFrame = true, MiniMapTracking = true,
  MiniMapTrackingButton = true, QueueStatusButton = true, MiniMapMailFrame = true, TimeManagerClockButton = true,
  AddonCompartmentFrame = true, MinimapZoomIn = true, MinimapZoomOut = true, MiniMapWorldMapButton = true,
  MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true, GarrisonLandingPageMinimapButton = true }

local hidden = setmetatable({}, { __mode = "k" }) -- [button] = true while we hide it
local hooked = setmetatable({}, { __mode = "k" })
local known = {} -- the buttons found, in the order found
local list

local function On()
  return Q.On and Q.On(KEY)
end

local function Name(frame)
  local ok, name = pcall(frame.GetName, frame)
  return ok and type(name) == "string" and name or nil
end

local function LibDBIcon()
  return LibStub and LibStub("LibDBIcon-1.0", true)
end

-- An addon button? (Blizzard's are left alone.)
local function IsAddonButton(frame, name)
  if not name or BLIZZARD[name] then
    return false
  end
  if name:find("^LibDBIcon10_") then
    return true
  end
  local lower = name:lower()
  return lower:find("minimapbutton", 1, true) ~= nil or lower:find("minimap_button", 1, true) ~= nil
    or lower:find("minimapicon", 1, true) ~= nil
end

local function Keep(button)
  if hooked[button] then
    return
  end
  hooked[button] = true
  known[#known + 1] = button
  hooksecurefunc(button, "Show", function(self)
    if On() and AB.active then
      hidden[self] = true
      self:Hide()
    end
  end)
end

local function Hide(button)
  Keep(button)
  if button:IsShown() then
    hidden[button] = true
    button:Hide()
  end
end

-- Finds the addon buttons now (addons make theirs at load or login; looked again whenever the list opens).
function AB.Collect()
  local lib = LibDBIcon()
  if lib and type(lib.objects) == "table" then
    for _, button in pairs(lib.objects) do
      if type(button) == "table" and button.Hide then
        Hide(button)
      end
    end
  end
  for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
    if parent and parent.GetChildren then
      for _, child in ipairs({ parent:GetChildren() }) do
        if IsAddonButton(child, Name(child)) then
          Hide(child)
        end
      end
    end
  end
end

-- The buttons the list shows: the ones that were shown, or that their addon tried to show.
function AB.Buttons()
  local out = {}
  for _, button in ipairs(known) do
    if hidden[button] then
      out[#out + 1] = button
    end
  end
  return out
end

-- Name, icon (texture and coords) of a button.
local function Describe(button)
  local data = button.dataObject
  local name, icon, coords
  if type(data) == "table" then
    name = data.label or data.text or button.name
    icon = data.icon
    coords = data.iconCoords
  end
  local frameName = Name(button)
  if not name then
    name = button.name or (frameName and frameName:gsub("^LibDBIcon10_", ""):gsub("MinimapButton$", ""))
      or L["Addon"]
  end
  if not icon then
    local region = button.icon or button.Icon
    if not (type(region) == "table" and region.GetTexture) and button.GetNormalTexture then
      region = button:GetNormalTexture()
    end
    if type(region) == "table" and region.GetTexture then
      icon = region:GetTexture()
    end
  end
  if not icon and button.GetRegions then
    -- the first texture that isn't the usual minimap button frame (border, background, highlight)
    for _, region in ipairs({ button:GetRegions() }) do
      local ok, texture = false, nil
      if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then
        ok, texture = pcall(region.GetTexture, region)
      end
      local text = ok and texture ~= nil and tostring(texture):lower() or nil
      if text and not (text:find("border", 1, true) or text:find("background", 1, true)
        or text:find("highlight", 1, true)) then
        icon = texture
        break
      end
    end
  end
  return tostring(name), icon, coords
end

local function Tooltip(row)
  local button = row.button
  local data = button and button.dataObject
  if type(data) == "table" and type(data.OnTooltipShow) == "function" then
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    pcall(data.OnTooltipShow, GameTooltip)
    GameTooltip:Show()
  elseif type(data) == "table" and type(data.OnEnter) == "function" then
    pcall(data.OnEnter, row)
    row.ldbEntered = true
  else
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    GameTooltip:AddLine(row.name:GetText() or "")
    GameTooltip:Show()
  end
end

local function Leave(row)
  local data = row.button and row.button.dataObject
  if row.ldbEntered and type(data) == "table" and type(data.OnLeave) == "function" then
    pcall(data.OnLeave, row)
  end
  row.ldbEntered = nil
  GameTooltip:Hide()
end

-- What a click on the button did.
function AB.Click(button, row, mouse)
  local data = button.dataObject
  if type(data) == "table" and type(data.OnClick) == "function" then
    return pcall(data.OnClick, row or button, mouse or "LeftButton")
  end
  local script = button.GetScript and button:GetScript("OnClick")
  if script then
    return pcall(script, button, mouse or "LeftButton", false)
  end
  return false
end

local function Row(index)
  local row = CreateFrame("Button", nil, list)
  row:SetSize(WIDTH - 16, ROW)
  row:SetPoint("TOPLEFT", 8, -8 - (index - 1) * ROW)
  row:RegisterForClicks("AnyUp")
  local hover = row:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  UI.SetColor(hover, ns.Theme().accent, 0.12)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 4, 0)
  row.name = UI.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  row.name:SetPoint("RIGHT", -4, 0)
  row.name:SetWordWrap(false)
  row:SetScript("OnEnter", Tooltip)
  row:SetScript("OnLeave", Leave)
  row:SetScript("OnClick", function(self, mouse)
    Leave(self)
    AB.Click(self.button, self, mouse)
    if mouse == "LeftButton" then
      list:Hide()
    end
  end)
  return row
end

local function Moon()
  local moon = type(MinimapCluster) == "table" and MinimapCluster.DielFrame
  return type(moon) == "table" and moon.EnableMouse and moon or nil
end

local function CreateList()
  list = CreateFrame("Frame", "CodexAddonButtonList", UIParent)
  list:SetFrameStrata("DIALOG")
  list:SetClampedToScreen(true)
  list:EnableMouse(true)
  list:SetWidth(WIDTH)
  UI.Panel(list, { cornerSize = 12 })
  list.empty = UI.Text(list, "body", 12, "muted")
  list.empty:SetPoint("TOPLEFT", 14, -14)
  list.empty:SetPoint("RIGHT", -14, 0)
  list.empty:SetText(L["No addon buttons on the minimap."])
  list.rows = {}
  table.insert(UISpecialFrames, "CodexAddonButtonList") -- Esc closes it
  list:Hide()
  return list
end

function AB.Refresh()
  if not list then
    return
  end
  local buttons = AB.Buttons()
  table.sort(buttons, function(a, b)
    return (Describe(a)):lower() < (Describe(b)):lower()
  end)
  for index, button in ipairs(buttons) do
    local row = list.rows[index] or Row(index)
    list.rows[index] = row
    local name, icon, coords = Describe(button)
    row.button = button
    row.name:SetText(name)
    row.icon:SetTexture(icon)
    if type(coords) == "table" and #coords >= 4 then
      row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
      row.icon:SetTexCoord(0, 1, 0, 1)
    end
    row:Show()
  end
  for index = #buttons + 1, #list.rows do
    list.rows[index]:Hide()
  end
  list.empty:SetShown(#buttons == 0)
  list:SetHeight(math.max(1, #buttons) * ROW + 16 + (#buttons == 0 and 12 or 0))
end

function AB.Toggle()
  if not On() then
    return
  end
  if not list then
    CreateList()
  end
  if list:IsShown() then
    list:Hide()
    return
  end
  AB.Collect()
  AB.Refresh()
  list:ClearAllPoints()
  local moon = Moon()
  if moon then
    list:SetPoint("TOPRIGHT", moon, "BOTTOMLEFT", 8, 8)
  else
    list:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 0, 0)
  end
  list:Show()
end

-- The moon opens the list: mouse on, a click and a tooltip of ours (it had neither).
local function MoonScripts(on)
  local moon = Moon()
  if not moon then
    return
  end
  if not AB.moonHooked then
    AB.moonHooked = true
    moon:HookScript("OnMouseUp", function(_, mouse)
      if On() and AB.active and mouse == "LeftButton" then
        AB.Toggle()
      end
    end)
    moon:HookScript("OnEnter", function(self)
      if not (On() and AB.active) then
        return
      end
      AB.Collect()
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine(L["Addon buttons"])
      GameTooltip:AddLine((L["%d on the minimap. Click to list them."]):format(#AB.Buttons()), 1, 1, 1)
      GameTooltip:Show()
    end)
    moon:HookScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  moon:EnableMouse(on and true or false)
end

function AB.Start()
  if not Moon() then
    return -- no moon to open the list from: the buttons stay where they are
  end
  AB.active = true
  MoonScripts(true)
  AB.Collect()
  -- addons that make their button a little later (after login)
  C_Timer.After(2, function()
    if On() and AB.active then
      AB.Collect()
    end
  end)
  C_Timer.After(10, function()
    if On() and AB.active then
      AB.Collect()
    end
  end)
  local lib = LibDBIcon()
  if lib and lib.RegisterCallback and not AB.callback then
    AB.callback = true
    pcall(lib.RegisterCallback, AB, "LibDBIcon_IconCreated", function()
      if On() and AB.active then
        AB.Collect()
      end
    end)
  end
end

function AB.Stop()
  AB.active = false
  MoonScripts(false)
  if list then
    list:Hide()
  end
  for _, button in ipairs(known) do
    if hidden[button] then
      hidden[button] = nil
      button:Show()
    end
  end
end

Q.AddToggle({
  key = KEY,
  name = L["Addon buttons in a list"],
  desc = L["Hides the buttons addons put round the minimap; click the moon (day and night) at the minimap's edge to list them, and click one in the list to use it."],
  order = 15,
  Enable = function()
    if On() then
      AB.Start()
    end
  end,
  Changed = function(on)
    if on then
      AB.Start()
    else
      AB.Stop()
    end
  end,
})
