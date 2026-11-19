local addonName, ns = ...

-- Quest keys: Space presses the quest window's main button. While the game's quest window (QuestFrame) shows
-- a quest, Space is bound (an override binding of Codex's own) to the first shown, enabled one of: Complete
-- Quest, Continue, Accept. Complete Quest is not bound while the quest offers several rewards and none is
-- picked. In a quest giver's greeting or a gossip window that lists quests, Space picks one (on by default):
-- a quest ready to turn in first, then the first available quest, then the other current quests in the order
-- shown; pressing Space again walks on (Accept, Continue, Complete). No hint is shown (the user's choice).
--
-- Override bindings are protected: they are only set or cleared out of combat. They are cleared when a fight
-- starts (PLAYER_REGEN_DISABLED still allows it), so Space jumps as usual during a fight, and set again
-- after it. They never fire while a chat edit box has the keyboard, so typing a space is unaffected.

local QK = {}
ns.questkeys = QK
local UI = ns.UI

-- pickQuests replaces the old "gossip" switch (off then): nobody chose that value, so it is dropped.
local DEFAULTS = { pickQuests = true }
local ORDER = { "QuestFrameCompleteQuestButton", "QuestFrameCompleteButton", "QuestFrameAcceptButton" }
local PICK_BUTTON = "CodexQuestKeysPickButton"
local KEY = "SPACE"

local owner -- our frame that owns the override binding
local pickButton -- our own named button that picks a quest from a greeting or gossip list
local pick -- the quest it picks: { from = "greeting" / "gossip", active, index / id, title }
QK.bound = nil -- the button name Space clicks now, or nil
QK.state = nil -- "bound", "choose", "combat" or nil, for the page and tests

function QK.DB()
  if not QK.db then
    local db = ns.db.questkeys or {}
    db.gossip = nil
    ns.db.questkeys = ns.Fill(db, DEFAULTS)
    QK.db = ns.db.questkeys
  end
  return QK.db
end

local function Shown(frame)
  return type(frame) == "table" and frame.IsVisible and frame:IsVisible() and true or false
end

local function Usable(button)
  return Shown(button) and (not button.IsEnabled or button:IsEnabled()) and true or false
end

-- Several rewards to choose from and none picked yet.
local function NeedsChoice()
  local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
  if type(choices) ~= "number" or choices <= 1 then
    return false
  end
  local info = _G.QuestInfoFrame
  local picked = type(info) == "table" and info.itemChoice or 0
  return not (type(picked) == "number" and picked > 0)
end

-- From a list of quests in the order shown (current ones first, as the windows list them): a current quest
-- ready to turn in, else the first available one, else the first current one.
local function Choose(quests)
  for _, quest in ipairs(quests) do
    if quest.active and quest.complete then
      return quest
    end
  end
  for _, quest in ipairs(quests) do
    if not quest.active then
      return quest
    end
  end
  return quests[1]
end
QK.Choose = Choose -- Quest windows (Modules/Dialogue/Keys.lua) picks with the same rule

-- A quest giver's greeting (QuestFrame's greeting panel).
local function GreetingQuest()
  if not Shown(_G.QuestFrameGreetingPanel) then
    return nil
  end
  local quests = {}
  for index = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
    local title, complete = GetActiveTitle(index)
    quests[#quests + 1] = { from = "greeting", active = true, index = index, title = title, complete = complete and true }
  end
  for index = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
    quests[#quests + 1] = { from = "greeting", active = false, index = index, title = GetAvailableTitle(index) }
  end
  return Choose(quests)
end

-- A gossip window's quests.
local function GossipQuest()
  if not (Shown(_G.GossipFrame) and C_GossipInfo) then
    return nil
  end
  local quests = {}
  for _, info in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
    if type(info) == "table" and info.questID then
      quests[#quests + 1] = { from = "gossip", active = true, id = info.questID, title = info.title,
        complete = info.isComplete and true }
    end
  end
  for _, info in ipairs(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) do
    if type(info) == "table" and info.questID then
      quests[#quests + 1] = { from = "gossip", active = false, id = info.questID, title = info.title }
    end
  end
  return Choose(quests)
end

-- What Space should press now: a button name, or nil with a reason.
function QK.Target()
  -- Codex's own quest windows are open: their key handler (Modules/Dialogue/Keys.lua) does Space with this
  -- module's settings, so the game's parked windows get no binding
  local dialogue = ns.dialogue
  if dialogue and dialogue.Active and dialogue.Active() then
    return nil, "codex"
  end
  if Shown(_G.QuestFrame) then
    for _, name in ipairs(ORDER) do
      local button = _G[name]
      if Usable(button) then
        if name == "QuestFrameCompleteQuestButton" and NeedsChoice() then
          return nil, "choose"
        end
        return name
      end
    end
  end
  if QK.DB().pickQuests then
    local quest = GreetingQuest() or GossipQuest()
    if quest then
      pick = quest
      return PICK_BUTTON
    end
  end
  return nil
end

local function Clear()
  if owner and QK.bound then
    ClearOverrideBindings(owner)
  end
  QK.bound = nil
end

-- Binds Space to the current target (or clears it). Out of combat only.
function QK.Update()
  if not owner then
    return
  end
  if InCombatLockdown() then
    QK.state = QK.bound and "bound" or "combat"
    return
  end
  local name, reason = QK.Target()
  if name ~= QK.bound then
    Clear()
    if name then
      SetOverrideBindingClick(owner, true, KEY, name, "LeftButton")
      QK.bound = name
    end
  end
  if name then
    QK.state = "bound"
  elseif reason == "choose" then
    QK.state = "choose"
  elseif reason == "codex" then
    QK.state = "codex"
  else
    QK.state = nil
  end
  if QK.RefreshPage then
    QK.RefreshPage()
  end
end

-- After Blizzard has shown its panel for the event (same frame).
local queued = false
local function UpdateSoon()
  if queued then
    return
  end
  queued = true
  C_Timer.After(0, function()
    queued = false
    QK.Update()
  end)
end

local EVENTS = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "QUEST_FINISHED",
  "QUEST_ITEM_UPDATE", "GOSSIP_SHOW", "GOSSIP_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

function QK.Enable()
  QK.DB()
  owner = CreateFrame("Frame", "CodexQuestKeysOwner", UIParent)
  -- Space in a greeting or gossip list: our own button picks the chosen quest (not protected)
  pickButton = CreateFrame("Button", PICK_BUTTON, UIParent)
  pickButton:Hide()
  pickButton:SetScript("OnClick", function()
    local quest = pick
    if not quest then
      return
    end
    if quest.from == "greeting" then
      local select = quest.active and SelectActiveQuest or SelectAvailableQuest
      if select then
        select(quest.index)
      end
    elseif C_GossipInfo then
      local select = quest.active and C_GossipInfo.SelectActiveQuest or C_GossipInfo.SelectAvailableQuest
      if select then
        select(quest.id)
      end
    end
  end)

  owner:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      -- the last moment bindings may change: Space jumps during the fight
      Clear()
      QK.state = "combat"
    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
      QK.Update()
      UpdateSoon()
    else
      UpdateSoon()
    end
  end)
  for _, event in ipairs(EVENTS) do
    owner:RegisterEvent(event)
  end
  -- a reward picked, or the window closed without an event
  if type(_G.QuestInfoItem_OnClick) == "function" then
    hooksecurefunc("QuestInfoItem_OnClick", UpdateSoon)
  end
  for _, name in ipairs({ "QuestFrame", "GossipFrame" }) do
    local frame = _G[name]
    if type(frame) == "table" and frame.HookScript then
      frame:HookScript("OnHide", function()
        QK.Update()
      end)
    end
  end
  QK.running = true
end

function QK.SetPickQuests(on)
  QK.DB().pickQuests = on and true or false
  QK.Update()
end

-- The page --------------------------------------------------------------------------------------------------

local view = {}

function QK.StatusText()
  if not QK.running then
    return "Off: Space jumps as usual."
  end
  if QK.state == "bound" then
    return "Space presses the quest button now."
  elseif QK.state == "choose" then
    return "Pick a reward first, then Space completes the quest."
  elseif QK.state == "codex" then
    return "Space presses the main button of Codex's quest window now."
  end
  return "On: Space picks quests from a quest giver's list and presses Complete Quest, Continue or Accept."
end

function QK.RefreshPage()
  if not view.page then
    return
  end
  view.status:SetText(QK.StatusText())
  view.gossip:SetChecked(QK.DB().pickQuests)
end

function QK.BuildPage(page)
  QK.DB()
  view.page = page
  local heading = UI.Heading(page, "Quest keys", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  local about = UI.Text(page, "body", 12, "text")
  about:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -14)
  about:SetPoint("RIGHT", 0, 0)
  about:SetJustifyH("LEFT")
  about:SetText("While a quest giver's quest window is open, Space presses its main button, in this order: "
    .. "Complete Quest, Continue, Accept. When a quest giver lists quests (greeting or gossip window), Space "
    .. "picks one: a quest ready to turn in first, then the first new quest, then your other quests, in the "
    .. "order shown; press Space again to go on. "
    .. "When a quest offers several rewards, pick one first: Space waits until you do. During a fight Space "
    .. "jumps as usual, and typing in chat is never affected. Codex's own quest windows (the Quest windows "
    .. "module) follow these settings too.")

  view.gossip = UI.Check(page, "Pick quests from greeting and gossip lists with Space")
  view.gossip:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  view.gossip:SetScript("OnClick", function(self)
    QK.SetPickQuests(self:GetChecked())
  end)

  if ns.IsAddOnLoaded and ns.IsAddOnLoaded("DialogueUI") then
    local note = UI.Text(page, "body", 11, "warn")
    note:SetPoint("TOPLEFT", view.gossip, "BOTTOMLEFT", 0, -14)
    note:SetPoint("RIGHT", 0, 0)
    note:SetJustifyH("LEFT")
    note:SetText("DialogueUI is loaded: it shows quests in its own window with its own keys, which may also use "
      .. "Space. Quest keys only works with the game's own quest window and Codex's.")
  end
  QK.RefreshPage()
end

ns.RegisterModule({
  id = "questkeys",
  name = "Quest keys",
  -- its section in the Codex window (Areas.lua)
  area = "quests", sectionOrder = 20, folded = true, pageEstimate = 220,
  icon = "Interface\\Icons\\INV_Misc_Note_01",
  desc = "Space presses Complete Quest, Continue or Accept in the quest window.",
  order = 95,
  Enable = function()
    QK.Enable()
  end,
  BuildPage = function(_, page)
    QK.BuildPage(page)
  end,
  ShowPage = function()
    QK.RefreshPage()
  end,
  Status = function()
    return QK.StatusText()
  end,
})
