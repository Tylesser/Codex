local addonName, ns = ...
local L = ns.L
local UI = ns.UI

-- What's new (2026-11-22, the user's request: "whats new page automatically opened when addon updated in game,
-- show only one time for each version"). The changes come from WhatsNewData.lua (generated from CHANGELOG.md).
-- At login, a few seconds after the loading screen and never in a fight, the window opens once for each new version:
-- CodexDB.whatsNewSeen holds the last version shown. Not on a first install (the first-run setup opens then; the
-- version is only noted), not in a development copy (version "@project-version@" / "dev"), not with the option
-- "Show what's new after an update" off (CodexDB.whatsNew == false). It lists every version newer than the one seen
-- (an update that skips versions shows them all), up to this one. `/codex whatsnew` and a button in General open it.

local WIDTH, HEIGHT = 540, 470
local window, watcher

-- "v1.2.0" -> "1.2.0"; nil for a development copy.
function ns.ReleaseVersion(version)
  version = tostring(version or ns.VERSION or "")
  if version == "" or version == "dev" or version:find("@", 1, true) then
    return nil
  end
  return (version:gsub("^v", ""))
end

-- Numeric parts of a version ("1.2.0-beta3" -> { 1, 2, 0, 3 } with a beta below its release).
local function Parts(version)
  local main, rest = tostring(version):match("^v?([%d%.]+)(.*)$")
  local parts = {}
  for number in (main or ""):gmatch("%d+") do
    parts[#parts + 1] = tonumber(number)
  end
  while #parts < 3 do
    parts[#parts + 1] = 0
  end
  local beta = rest and rest:match("(%d+)")
  parts[4] = (rest and rest ~= "") and (tonumber(beta) or 0) or math.huge
  return parts
end

-- -1, 0 or 1.
function ns.CompareVersions(a, b)
  local pa, pb = Parts(a), Parts(b)
  for i = 1, 4 do
    if pa[i] ~= pb[i] then
      return pa[i] < pb[i] and -1 or 1
    end
  end
  return 0
end

-- The sections to show: newer than `seen` (nil = only this version's), up to `current`. `current` nil = the newest.
function ns.WhatsNewFor(current, seen)
  local list = {}
  for _, section in ipairs(ns.WHATS_NEW or {}) do
    local version = section.version
    if version:lower() == "unreleased" then
      if not current then
        list[#list + 1] = section -- a development copy: its own changes first
      end
    elseif not current then
      if #list == 0 or (#list == 1 and list[1].version:lower() == "unreleased") then
        list[#list + 1] = section
      end
    elseif ns.CompareVersions(version, current) <= 0
      and (seen and ns.CompareVersions(version, seen) > 0 or (not seen and ns.CompareVersions(version, current) == 0)) then
      list[#list + 1] = section
    end
  end
  return list
end

local function Rich(text)
  local hex = ns.Hex(ns.Theme().accent or { 1, 0.82, 0 })
  return (text:gsub("%*%*(.-)%*%*", "|cff" .. hex .. "%1|r"):gsub("`(.-)`", "%1"))
end

local function Fill(sections, current)
  local body = window.body
  for _, region in ipairs(window.lines or {}) do
    region:Hide()
  end
  window.lines = {}
  local width = WIDTH - 56
  local y = 0
  for index, section in ipairs(sections) do
    local heading = UI.Text(body, "head", 15, "bright")
    heading:SetPoint("TOPLEFT", 0, -y)
    heading:SetWidth(width)
    heading:SetText(section.version:lower() == "unreleased" and L["Not released yet"] or section.version)
    window.lines[#window.lines + 1] = heading
    y = y + 24
    for _, item in ipairs(section.items) do
      local dot = UI.Text(body, "body", 13, "accent")
      dot:SetPoint("TOPLEFT", 2, -y)
      dot:SetText("•")
      local line = UI.Text(body, "body", 13, "text")
      line:SetPoint("TOPLEFT", 16, -y)
      line:SetWidth(width - 16)
      line:SetWordWrap(true)
      line:SetText(Rich(item))
      window.lines[#window.lines + 1] = dot
      window.lines[#window.lines + 1] = line
      local height = line:GetStringHeight() or 0
      if height < 14 then
        height = math.ceil(#item / 70) * 17 -- not drawn yet: a guess, measured again on show
      end
      y = y + height + 6
    end
    if index < #sections then
      y = y + 10
    end
  end
  body:SetSize(width, math.max(1, y))
  window.title:SetText(current and L["What's new in Codex %s"]:format(current) or L["What's new in Codex"])
end

local function Layout()
  if not (window and window:IsShown() and window.sections) then
    return
  end
  Fill(window.sections, window.current)
end

local function Build()
  window = CreateFrame("Frame", "CodexWhatsNew", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetPoint("CENTER", 0, 40)
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  UI.Panel(window, { cornerSize = 12 })
  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "CodexWhatsNew")
  end
  window.title = UI.Heading(window, L["What's new in Codex"], 17)
  window.title:SetPoint("TOPLEFT", 20, -16)
  window.title:SetPoint("RIGHT", -44, 0)
  local close = UI.CloseButton(window)
  close:SetPoint("TOPRIGHT", -10, -10)
  local scroll, body = UI.ScrollArea(window)
  scroll:SetPoint("TOPLEFT", 20, -50)
  scroll:SetPoint("BOTTOMRIGHT", -16, 54)
  window.scroll, window.body = scroll, body

  local again = UI.Check(window, L["Show this after each update"])
  again:SetPoint("BOTTOMLEFT", 16, 16)
  again.label:SetText(L["Show this after each update"])
  again:SetScript("OnShow", function(self)
    self:SetChecked(ns.db.whatsNew ~= false)
  end)
  again:SetScript("OnClick", function(self)
    ns.db.whatsNew = self:GetChecked() and true or false
  end)
  window.again = again
  local ok = UI.Button(window, 110, 26, L["Close"])
  ok:SetPoint("BOTTOMRIGHT", -16, 14)
  ok:SetScript("OnClick", function()
    window:Hide()
  end)
  local open = UI.Button(window, 120, 26, L["Open Codex"])
  open:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  open:SetScript("OnClick", function()
    window:Hide()
    if ns.ShowPage then
      ns.ShowPage("home")
    end
  end)
  window:SetScript("OnShow", function()
    again:SetChecked(ns.db.whatsNew ~= false)
    if C_Timer and C_Timer.After then
      C_Timer.After(0, Layout) -- texts measure 0 before their first draw
    end
  end)
  window:Hide()
end

-- Opens the window. sections nil = this version's (or the newest in a development copy).
function ns.ShowWhatsNew(sections, current)
  current = current or ns.ReleaseVersion()
  sections = sections or ns.WhatsNewFor(current, nil)
  if #sections == 0 then
    sections = ns.WhatsNewFor(nil, nil)
  end
  if #sections == 0 then
    ns.Say(L["no notes for this version."])
    return
  end
  if not window then
    Build()
  end
  window.sections, window.current = sections, current
  Fill(sections, current)
  window.scroll:SetVerticalScroll(0)
  window:Show()
end

-- What the login check decides: "show" (with the sections), "note" (record the version only) or nil (nothing).
function ns.WhatsNewDecision()
  local current = ns.ReleaseVersion()
  if not current then
    return nil
  end
  local seen = ns.db.whatsNewSeen
  if seen and ns.CompareVersions(seen, current) >= 0 then
    return nil
  end
  if not ns.db.setupDone or ns.db.whatsNew == false then
    return "note"
  end
  local sections = ns.WhatsNewFor(current, seen)
  if #sections == 0 then
    return "note"
  end
  return "show", sections, current
end

local function Check()
  if InCombatLockdown and InCombatLockdown() then
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local decision, sections, current = ns.WhatsNewDecision()
  if decision then
    ns.db.whatsNewSeen = ns.ReleaseVersion() -- once per version, also when it is closed at once
  end
  if decision == "show" and not (CodexSetup and CodexSetup.IsShown and CodexSetup:IsShown()) then
    ns.ShowWhatsNew(sections, current)
  end
end

-- At login (Events.lua): a few seconds after the loading screen ends.
function ns.MaybeShowWhatsNew()
  if watcher then
    return
  end
  watcher = CreateFrame("Frame")
  watcher:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
      C_Timer.After(4, Check)
    else
      Check()
    end
  end)
  watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
end
