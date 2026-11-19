local addonName, ns = ...

-- Keys in Codex's NPC windows, all in one place: 1-9 pick the rows (option "numbers", keycaps beside them), Space
-- presses the main button (Quest keys module: on when that module is on, with its "pick quests" setting for lists),
-- Tab moves to the next reward (Shift+Tab back; option "tabRewards"), Escape on a quest page reached from the NPC's
-- list goes back to it (option "escapeBack"). While the game's own windows are used (module or windows option off),
-- the Quest keys module's override binding does Space as before.
--
-- How: a frame of ours with EnableKeyboard while one of our windows shows; every key it doesn't use goes on to the
-- game (SetPropagateKeyboardInput(true)), the ones it uses stop there. Both calls are only made out of combat (they
-- are restricted in a fight): a fight starts -> propagation on and the keyboard off (PLAYER_REGEN_DISABLED still
-- allows it), so in combat every key does what the game says. Nothing a key does here is protected (selecting
-- gossip options and quests, AcceptQuest, CompleteQuest, GetQuestReward). A focused chat box gets keys first, so
-- typing is never touched.

local D = ns.dialogue
local K = {}
D.Keys = K

local frame
K.enabled = false

local function Modified()
  return (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
    or (IsAltKeyDown and IsAltKeyDown()) or false
end

function K.SpaceOn()
  return ns.ModuleOn and ns.ModuleOn("questkeys") or false
end

-- Space: finish the written-in text, read on (style B), scroll a long quest text, then the main button. In a list
-- it picks a quest the way Quest keys does (a quest ready to hand in first, then a new one, then the others).
function K.Confirm()
  local page = D.page
  if not page then
    return false
  end
  if D.FinishReveal() then
    return true
  end
  if D.NextPart() then
    return true
  end
  local kind = page.kind
  if D.QUEST_PAGES[kind] and D.ScrollOn() then
    return true
  end
  if kind == "detail" then
    return D.Accept()
  elseif kind == "progress" then
    return D.Continue()
  elseif kind == "reward" then
    return D.Complete()
  end
  local QK = ns.questkeys
  if not (QK and QK.DB and QK.DB().pickQuests and QK.Choose) then
    return false
  end
  local quests = {}
  for _, row in ipairs(D.rowsShown or {}) do
    if row.kind == "quest" then
      quests[#quests + 1] = row
    end
  end
  local choice = #quests > 0 and QK.Choose(quests)
  if choice then
    D.SelectRow(choice)
    return true
  end
  return false
end

-- True when the key was used (it then stops here).
function K.Handle(key)
  local page = D.page
  if not (page and type(key) == "string") then
    return false
  end
  -- a popup of the game's is asking (PvP quest, costly hand-in, gossip confirm): its own keys answer it
  for index = 1, 4 do
    local popup = _G["StaticPopup" .. index]
    if type(popup) == "table" and popup.IsShown and popup:IsShown() then
      return false
    end
  end
  local db = D.DB()
  if key == "ESCAPE" then
    return db.escapeBack and D.Back() or false
  end
  local digit = key:match("^NUMPAD(%d)$") or key:match("^(%d)$")
  if digit then
    local n = tonumber(digit)
    if n and n >= 1 and db.numbers and not Modified() then
      local row = D.RowAt(n)
      if row then
        D.SelectRow(row)
        return true
      end
    end
    return false
  end
  if key == "TAB" then
    return db.tabRewards and D.NextReward(IsShiftKeyDown and IsShiftKeyDown()) or false
  end
  if key == "SPACE" and K.SpaceOn() and not Modified() then
    return K.Confirm()
  end
  return false
end

local function OnKeyDown(self, key)
  if InCombatLockdown() then
    return -- propagation is on (set as the fight started): the game gets every key
  end
  local used = K.Handle(key)
  self:SetPropagateKeyboardInput(not used)
end

function K.Create()
  frame = CreateFrame("Frame", "CodexDialogueKeys", UIParent)
  frame:SetSize(1, 1)
  frame:SetPoint("TOPLEFT")
  frame:SetScript("OnKeyDown", OnKeyDown)
  K.frame = frame
end

-- Keyboard on while one of our windows shows; changed only out of combat.
function K.Update()
  if not frame or InCombatLockdown() then
    return
  end
  local on = D.Active() and true or false
  if on ~= K.enabled then
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(on)
    K.enabled = on
  end
end

-- PLAYER_REGEN_DISABLED: the last moment these may change. Every key goes to the game during the fight.
function K.CombatStarts()
  if not frame then
    return
  end
  frame:SetPropagateKeyboardInput(true)
  frame:EnableKeyboard(false)
  K.enabled = false
end
