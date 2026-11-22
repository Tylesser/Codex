local addonName, ns = ...
local R = ns.rings

-- The secure side of the rings: works in combat because everything that acts is a secure frame and the logic
-- runs as restricted snippets (Blizzard_RestrictedAddOnEnvironment, forever branch of wow-ui-source).
--
--   controller   SecureHandlerBaseTemplate. Owns the ring keys (SetOverrideBindingClick, out of combat) and the
--                restricted environment every snippet shares (OPEN = the id of the open ring, as a string).
--   CodexRingButton  the one named frame: a SecureActionButtonTemplate every ring key clicks, with the mouse
--                button "ring<id>" (and "close" for Escape). useOnKeyDown = false: its action runs on release.
--                Its OnClick is wrapped (SecureHandlerWrapScript): on key down the snippet moves the ring to the
--                cursor (HANDLE:SetPoint("CENTER", "$cursor")), shows it and binds Escape (HANDLE:SetBindingClick
--                on the ring frame); on key up it reads where the cursor is (HANDLE:GetMousePosition on the ring
--                frame), picks the slice in that direction, copies the slice's attributes onto itself
--                (HANDLE:GetAttribute / SetAttribute) and hides the ring; the button's own secure click then
--                casts / uses it. Releasing in the middle, far outside the ring or after Escape does nothing.
--   ring frames  one SecureHandlerBaseTemplate per ring (2000 x 2000, invisible, no mouse) holding 12
--                SecureActionButtonTemplate slices laid out in a circle out of combat; a slice can also be
--                clicked with the mouse (its wrap hides the ring afterwards). Visuals are plain frames on top
--                (Display.lua), free to change in combat.
-- Secure frames are only made, moved and given attributes out of combat; anything asked for in combat waits for
-- PLAYER_REGEN_ENABLED.
-- Rings inside rings (2026-11-22): a slice with the attribute "subring" (kind "ring") does nothing itself; choosing
-- it (releasing the key over it, or clicking it) hides this ring and opens that one at the cursor, Escape-bound, as
-- OPEN. A ring used inside an enabled ring is built and may open even without a key of its own (`nested`).

local BUTTON = "CodexRingButton"
R.BUTTON = BUTTON
local RING_SIZE = 2000 -- big, so GetMousePosition still reads the cursor far outside the drawn ring

R.frames = {} -- [ringID] = { ring = secure frame, slices = { secure buttons }, display ... (Display.lua) }
R.pending = { layout = {}, bindings = false, build = false }
local controller, trigger

-- Restricted snippets --------------------------------------------------------------------------------------------
-- Only calls the forever restricted environment has: strmatch, floor, math.*, and the frame handle methods
-- GetFrameRef, GetAttribute, SetAttribute, Show, Hide, IsShown, ClearAllPoints, SetPoint("$cursor"),
-- GetMousePosition, GetWidth, GetHeight, GetParent, SetBindingClick, ClearBindings. `owner` = the controller.

local COPY = {}
for _, key in ipairs(R.ATTR_KEYS) do
  COPY[#COPY + 1] = ("self:SetAttribute(%q, slice:GetAttribute(%q))"):format(key, key)
end

R.TRIGGER_SNIPPET = [[
local id = strmatch(button or "", "^ring(%d+)$")
if button == "close" then
  if down and OPEN then
    local open = owner:GetFrameRef("ring" .. OPEN)
    if open then
      open:Hide()
      open:ClearBindings()
    end
    OPEN = nil
  end
  return false
end
if not id then
  return false
end
local ring = owner:GetFrameRef("ring" .. id)
if not ring then
  return false
end
if down then
  if OPEN and OPEN ~= id then
    local other = owner:GetFrameRef("ring" .. OPEN)
    if other then
      other:Hide()
      other:ClearBindings()
    end
  end
  OPEN = nil
  if (ring:GetAttribute("count") or 0) < 1 then
    return false
  end
  ring:ClearAllPoints()
  ring:SetPoint("CENTER", "$cursor")
  ring:Show()
  ring:SetBindingClick(true, "ESCAPE", "]] .. BUTTON .. [[", "close")
  OPEN = id
  return false
end
if OPEN ~= id then
  return false
end
OPEN = nil
local pick
local count = ring:GetAttribute("count") or 0
local x, y = ring:GetMousePosition()
if x and y and count > 0 then
  local dx, dy = (x - 0.5) * ring:GetWidth(), (y - 0.5) * ring:GetHeight()
  local dead = ring:GetAttribute("deadzone") or 20
  local outer = ring:GetAttribute("outer") or 1000
  local distance = dx * dx + dy * dy
  if distance >= dead * dead and distance <= outer * outer then
    local step = 360 / count
    local around = (90 - math.deg(math.atan2(dy, dx))) % 360
    pick = floor(around / step + 0.5) % count + 1
  end
end
ring:Hide()
ring:ClearBindings()
if not pick then
  return false
end
local slice = ring:GetFrameRef("slice" .. pick)
local sub = slice and slice:GetAttribute("subring")
if sub then
  local inner = owner:GetFrameRef("ring" .. sub)
  if inner and (inner:GetAttribute("count") or 0) > 0 then
    inner:ClearAllPoints()
    inner:SetPoint("CENTER", "$cursor")
    inner:Show()
    inner:SetBindingClick(true, "ESCAPE", "]] .. BUTTON .. [[", "close")
    OPEN = sub
  end
  return false
end
if not slice or not slice:GetAttribute("type") then
  return false
end
]] .. table.concat(COPY, "\n") .. "\n"

-- A slice clicked with the mouse: its own secure click acts, then the ring closes. A ring slice instead closes
-- this ring and opens its ring at the cursor (rings inside rings: choose there with a click, or Escape).
R.SLICE_PRE = [[
local sub = self:GetAttribute("subring")
if sub then
  local ring = self:GetParent()
  if ring then
    ring:Hide()
    ring:ClearBindings()
  end
  OPEN = nil
  local inner = owner:GetFrameRef("ring" .. sub)
  if inner and (inner:GetAttribute("count") or 0) > 0 then
    inner:ClearAllPoints()
    inner:SetPoint("CENTER", "$cursor")
    inner:Show()
    inner:SetBindingClick(true, "ESCAPE", "]] .. BUTTON .. [[", "close")
    OPEN = sub
  end
  return false
end
return nil, "used"
]]
R.SLICE_POST = [[
local ring = self:GetParent()
if ring then
  ring:Hide()
  ring:ClearBindings()
end
OPEN = nil
]]

-- Building --------------------------------------------------------------------------------------------------------

local function Combat()
  return InCombatLockdown() and true or false
end

local function BuildBase()
  if controller then
    return true
  end
  if Combat() then
    R.pending.build = true
    return false
  end
  controller = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
  trigger = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
  trigger:SetSize(1, 1)
  trigger:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  trigger:SetAlpha(0)
  trigger:EnableMouse(false)
  trigger:RegisterForClicks("AnyDown", "AnyUp")
  trigger:SetAttribute("useOnKeyDown", false)
  SecureHandlerWrapScript(trigger, "OnClick", controller, R.TRIGGER_SNIPPET)
  R.controller, R.trigger = controller, trigger
  return true
end

local function BuildRing(id)
  if R.frames[id] then
    return R.frames[id]
  end
  if Combat() or not BuildBase() then
    R.pending.build = true
    return nil
  end
  local ring = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
  ring:SetFrameStrata("FULLSCREEN_DIALOG")
  ring:SetSize(RING_SIZE, RING_SIZE)
  ring:SetPoint("CENTER")
  ring:EnableMouse(false)
  ring:Hide()
  SecureHandlerSetFrameRef(controller, "ring" .. id, ring)
  local entry = { id = id, ring = ring, slices = {} }
  for index = 1, R.MAX_SLICES do
    local slice = CreateFrame("Button", nil, ring, "SecureActionButtonTemplate")
    slice:EnableMouse(true)
    slice:RegisterForClicks("AnyUp")
    slice:SetAttribute("useOnKeyDown", false)
    slice:SetFrameLevel(ring:GetFrameLevel() + 20)
    slice:Hide()
    SecureHandlerSetFrameRef(ring, "slice" .. index, slice)
    SecureHandlerWrapScript(slice, "OnClick", controller, R.SLICE_PRE, R.SLICE_POST)
    entry.slices[index] = slice
  end
  R.frames[id] = entry
  if R.CreateDisplay then
    R.CreateDisplay(entry)
  end
  return entry
end
R.BuildRing = BuildRing

-- Lays one ring out: slice positions, sizes and attributes. Out of combat; in combat it waits.
function R.Layout(id)
  local ring = R.Find(id)
  local entry = R.frames[id]
  if not entry then
    return false
  end
  if Combat() then
    R.pending.layout[id] = true
    return false
  end
  R.pending.layout[id] = nil
  local infos = {}
  if ring then
    for _, slice in ipairs(R.Slices(ring)) do
      local info = R.Info(slice)
      if info and #infos < R.MAX_SLICES then
        info.slice = slice
        infos[#infos + 1] = info
      end
    end
  end
  local db = R.DB()
  local count = #infos
  entry.ring:SetAttribute("count", (ring and (ring.enabled ~= false or entry.nested) or entry.preview) and count or 0)
  entry.ring:SetAttribute("deadzone", R.DeadZone())
  entry.ring:SetAttribute("outer", R.OuterLimit())
  for index, button in ipairs(entry.slices) do
    local info = infos[index]
    for _, key in ipairs(R.ATTR_KEYS) do
      button:SetAttribute(key, info and info.attrs[key] or nil)
    end
    if info then
      local x, y = R.SlicePosition(index, count, db.radius)
      button:ClearAllPoints()
      button:SetPoint("CENTER", entry.ring, "CENTER", x, y)
      button:SetSize(db.iconSize, db.iconSize)
      button:Show()
    else
      button:Hide()
    end
  end
  entry.infos = infos
  entry.name = ring and ring.name or ""
  if R.LayoutDisplay then
    R.LayoutDisplay(entry)
  end
  return true
end

-- Override bindings: each enabled ring's key clicks CodexRingButton with "ring<id>". Out of combat only.
function R.ApplyBindings()
  if not controller then
    return false
  end
  if Combat() then
    R.pending.bindings = true
    return false
  end
  R.pending.bindings = false
  ClearOverrideBindings(controller)
  R.bound = {}
  for _, ring in ipairs(R.Rings()) do
    if ring.enabled and ring.key and R.frames[ring.id] then
      SetOverrideBindingClick(controller, true, ring.key, BUTTON, "ring" .. ring.id)
      R.bound[ring.key] = ring.id
    end
  end
  return true
end

-- Everything in step with the saved rings: frames for enabled rings, layouts, bindings. Out of combat.
function R.Sync()
  if Combat() then
    R.pending.build = true
    R.pending.bindings = true
    for _, ring in ipairs(R.Rings()) do
      if R.frames[ring.id] then
        R.pending.layout[ring.id] = true
      end
    end
    return false
  end
  R.pending.build = false
  if not BuildBase() then
    return false
  end
  local alive = {}
  -- rings inside enabled rings are built and may open too, with or without a key of their own
  local nested = {}
  for _, ring in ipairs(R.Rings()) do
    if ring.enabled then
      for _, slice in ipairs(R.Slices(ring)) do
        if slice.kind == "ring" then
          nested[tostring(slice.id)] = true
        end
      end
    end
  end
  for _, ring in ipairs(R.Rings()) do
    alive[ring.id] = true
    if ring.enabled or nested[tostring(ring.id)] then
      BuildRing(ring.id)
    end
    if R.frames[ring.id] then
      R.frames[ring.id].nested = nested[tostring(ring.id)] or nil
    end
    if R.frames[ring.id] then
      R.Layout(ring.id)
    end
  end
  -- deleted rings: their frames stay (frames can't be destroyed) but have nothing and never open
  for id, entry in pairs(R.frames) do
    if not alive[id] then
      entry.ring:SetAttribute("count", 0)
      entry.ring:Hide()
      for _, button in ipairs(entry.slices) do
        button:Hide()
      end
    end
  end
  R.ApplyBindings()
  return true
end

-- After a fight: what was asked for during it.
function R.Flush()
  if Combat() then
    return
  end
  if R.pending.build then
    R.Sync()
    return
  end
  for id in pairs(R.pending.layout) do
    R.Layout(id)
  end
  if R.pending.bindings then
    R.ApplyBindings()
  end
end

-- `auto` rings follow what the character learns and carries (a little later, so a burst of events is one rebuild).
local refreshQueued = false
function R.RefreshAuto()
  if refreshQueued then
    return
  end
  refreshQueued = true
  C_Timer.After(0.5, function()
    refreshQueued = false
    for _, ring in ipairs(R.Rings()) do
      if ring.auto and R.frames[ring.id] then
        R.Layout(ring.id)
      end
    end
    if R.RefreshPage then
      R.RefreshPage()
    end
  end)
end

local AUTO_EVENTS = { "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "NEW_MOUNT_ADDED", "LEARNED_SPELL_IN_TAB" }

function R.Enable()
  R.DB()
  R.events = CreateFrame("Frame")
  R.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      R.Flush()
      if R.RefreshPage then
        R.RefreshPage()
      end
    elseif event == "PLAYER_REGEN_DISABLED" then
      if R.StopCapture then
        R.StopCapture() -- the key button would keep the keyboard during the fight
      end
      if R.RefreshPage then
        R.RefreshPage()
      end
    else
      R.RefreshAuto()
    end
  end)
  R.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  R.events:RegisterEvent("PLAYER_REGEN_DISABLED")
  for _, event in ipairs(AUTO_EVENTS) do
    pcall(R.events.RegisterEvent, R.events, event)
  end
  R.running = true
  R.Sync()
end

-- Open / close a ring at the cursor without its key ("/codex ring <name>", the page's Try button). Out of combat
-- only: then plain Lua may show and move it. Escape closes it, a click on a slice uses it.
function R.ToggleAtCursor(ring)
  if not R.running then
    return false, "The Rings module is off."
  end
  if Combat() then
    return false, "Rings can only be opened this way out of combat."
  end
  if not BuildBase() then
    return false, "Not ready yet."
  end
  local entry = BuildRing(ring.id)
  if not entry then
    return false, "Not ready yet."
  end
  if entry.ring:IsShown() then
    entry.ring:Hide()
    ClearOverrideBindings(entry.ring)
    SecureHandlerExecute(controller, "OPEN = nil")
    return true
  end
  entry.preview = true
  R.Layout(ring.id)
  entry.preview = nil
  if #(entry.infos or {}) == 0 then
    return false, ("%s has no slices yet."):format(ring.name)
  end
  -- the ring may be shown even though it is switched off (the count set for this try)
  entry.ring:SetAttribute("count", #entry.infos)
  for _, other in pairs(R.frames) do
    if other ~= entry and other.ring:IsShown() then
      other.ring:Hide()
      ClearOverrideBindings(other.ring)
    end
  end
  local x, y = GetCursorPosition()
  local scale = entry.ring:GetEffectiveScale()
  entry.ring:ClearAllPoints()
  entry.ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  entry.ring:Show()
  SetOverrideBindingClick(entry.ring, true, "ESCAPE", BUTTON, "close")
  SecureHandlerExecute(controller, ("OPEN = %q"):format(tostring(ring.id)))
  return true
end
