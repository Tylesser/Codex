local addonName, ns = ...

-- The game's own NPC windows and the rest of its interface while Codex draws the talk.
--
-- Parking: QuestFrame and GossipFrame keep opening and closing exactly as the game wants (they must stay shown:
-- the talk with the NPC lives as long as they do, Escape and walking away close them, their OnHide calls
-- CloseQuest / C_GossipInfo.CloseGossip). While they show they are moved off the screen and made invisible
-- (alpha 0), the way the Bags module parks the bag and bank windows. Their points are kept and put back when they
-- hide, and they are parked again after the game lays out its panels (UpdateUIPanelPositions). Nothing is hidden,
-- nothing of theirs is called; all of it works in combat too (they are not protected frames).
--
-- Fading (styles B and C, option "fade"): every shown child of UIParent except ours, tooltips and popups goes to
-- alpha 0 with a short fade of our own (never UIFrameFade, never Hide), and back to its own alpha when the talk ends
-- or a fight starts. Nothing fades in combat.

local D = ns.dialogue

local GAME_FRAMES = { "QuestFrame", "GossipFrame" }
local parked = {} -- [frame] = { points = {...}, clamped = bool }
local unpack = unpack or table.unpack

local function Park(frame)
  if type(frame) ~= "table" or not frame.ClearAllPoints then
    return
  end
  if not parked[frame] then
    local points = {}
    for index = 1, 5 do
      local point = { frame:GetPoint(index) }
      if #point == 0 then
        break
      end
      points[#points + 1] = point
    end
    parked[frame] = { points = points, clamped = frame.IsClampedToScreen and frame:IsClampedToScreen() and true or false }
  end
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(false)
  end
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -4000, 0)
  frame:SetAlpha(0)
end

local function Unpark(frame)
  local saved = parked[frame]
  if not saved then
    return
  end
  parked[frame] = nil
  frame:SetAlpha(1)
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(saved.clamped)
  end
  frame:ClearAllPoints()
  for _, point in ipairs(saved.points) do
    frame:SetPoint(unpack(point))
  end
end

function D.IsParked(frame)
  return parked[frame] ~= nil
end

-- Parks the game's NPC windows that are open now (from D.Show, and from their OnShow).
function D.ParkGame()
  if not D.Owns() then
    return
  end
  for _, name in ipairs(GAME_FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" and frame.IsShown and frame:IsShown() then
      Park(frame)
    end
  end
end

function D.UnparkGame()
  for frame in pairs(parked) do
    Unpark(frame)
  end
end

local function Repark()
  for frame in pairs(parked) do
    if frame:IsShown() then
      Park(frame)
    end
  end
end

-- Once, from Enable.
function D.InstallGameHooks()
  for _, name in ipairs(GAME_FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" and frame.HookScript then
      frame:HookScript("OnShow", function(self)
        if D.Owns() then
          Park(self)
        end
      end)
      frame:HookScript("OnHide", function(self)
        Unpark(self)
        -- the talk ended without an event we caught (a panel pushed it away): ours goes too
        C_Timer.After(0, function()
          if D.page and not D.GameWindowOpen() then
            D.Hide()
          end
        end)
      end)
    end
  end
  if type(_G.UpdateUIPanelPositions) == "function" then
    hooksecurefunc("UpdateUIPanelPositions", Repark)
  end
end

-- Is one of the game's NPC windows open (the talk still on)?
function D.GameWindowOpen()
  for _, name in ipairs(GAME_FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" and frame.IsShown and frame:IsShown() then
      return true
    end
  end
  return false
end

-- Fading the game's interface ---------------------------------------------------------------------------------

local faded = {} -- [frame] = its alpha before
local fader
local KEEP = { GameTooltip = true, ItemRefTooltip = true, ShoppingTooltip1 = true, ShoppingTooltip2 = true,
  EmbeddedItemTooltip = true, QuestFrame = true, GossipFrame = true, CodexMenu = true, UIErrorsFrame = true }
local KEEP_STRATA = { DIALOG = true, FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true }

D.ownFrames = {} -- [frame] = true: our windows (never faded)

local function Keep(frame)
  if D.ownFrames[frame] then
    return true
  end
  local name = frame.GetName and frame:GetName()
  if type(name) == "string" and (KEEP[name] or name:find("^StaticPopup") or name:find("^CodexDialogue")) then
    return true
  end
  local strata = frame.GetFrameStrata and frame:GetFrameStrata()
  if type(strata) == "string" and D.Readable(strata) and KEEP_STRATA[strata] then
    return true
  end
  return false
end

-- A shown, plain (not forbidden) UIParent child we may fade.
local function FadeCandidate(frame)
  if type(frame.IsForbidden) ~= "function" or type(frame.IsShown) ~= "function" or type(frame.SetAlpha) ~= "function" then
    return false
  end
  local ok, forbidden = pcall(frame.IsForbidden, frame)
  if not ok or forbidden then
    return false
  end
  local okShown, shown = pcall(frame.IsShown, frame)
  if not okShown or not shown then
    return false
  end
  local okKeep, keep = pcall(Keep, frame)
  return okKeep and not keep
end

function D.FadeWanted()
  local db = D.DB()
  return D.Owns() and db.fade and (db.style == "b" or db.style == "c") and not InCombatLockdown()
end

-- Alpha steps of our own over 0.2 s, each from where the frame is now: [frame] = { from, to }. `restoring` keeps a
-- frame's own alpha until it is back, so fading it again half way still saves the right one.
local steps, stepTime = {}, 0
local restoring = {}

local function Current(frame)
  local alpha = frame.GetAlpha and frame:GetAlpha()
  return type(alpha) == "number" and D.Readable(alpha) and alpha or 1
end

local function Step(_, elapsed)
  stepTime = stepTime + (elapsed or 0)
  local t = math.min(1, stepTime / 0.2)
  for frame, step in pairs(steps) do
    frame:SetAlpha(step[1] + (step[2] - step[1]) * t)
  end
  if t >= 1 then
    for frame in pairs(steps) do
      if not faded[frame] then
        restoring[frame] = nil
      end
    end
    steps = {}
    fader:SetScript("OnUpdate", nil)
  end
end

local function Animate(frame, to)
  if not fader then
    fader = CreateFrame("Frame", "CodexDialogueFader", UIParent)
  end
  for other, step in pairs(steps) do
    -- the ones still on their way carry on from where they are
    if other ~= frame then
      local t = math.min(1, stepTime / 0.2)
      step[1] = step[1] + (step[2] - step[1]) * t
    end
  end
  steps[frame] = { Current(frame), to }
  stepTime = 0
  fader:SetScript("OnUpdate", Step)
end

function D.FadeGameUI()
  if not D.FadeWanted() then
    return
  end
  for _, frame in ipairs({ UIParent:GetChildren() }) do
    -- forbidden frames first: even IsShown on one errors from addon code (the user's error, 2026-11-21: a forbidden
    -- UIParent child broke the fade at the first quest window in style B / C); each check in pcall
    if type(frame) == "table" and not faded[frame] and FadeCandidate(frame) then
      faded[frame] = restoring[frame] or Current(frame)
      restoring[frame] = faded[frame]
      Animate(frame, 0)
    end
  end
  D.uiFaded = next(faded) ~= nil
end

-- instant: at once, no animation (a fight starts).
function D.RestoreGameUI(instant)
  D.restoreToken = nil
  for frame, alpha in pairs(faded) do
    steps[frame] = nil
    if instant or InCombatLockdown() then
      frame:SetAlpha(alpha)
      restoring[frame] = nil
    else
      restoring[frame] = alpha
      Animate(frame, alpha)
    end
  end
  faded = {}
  D.uiFaded = false
end

-- After our window hides: the interface comes back a moment later, unless the next page of the talk shows by then
-- (gossip -> quest, offer -> list), so it doesn't flash.
function D.RestoreSoon()
  if not next(faded) then
    return
  end
  local token = {}
  D.restoreToken = token
  C_Timer.After(0.3, function()
    if D.restoreToken == token and not D.page then
      D.RestoreGameUI()
    end
  end)
end

function D.FadedFrames()
  return faded
end
