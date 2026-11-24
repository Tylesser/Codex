local addonName, ns = ...

-- Quest windows (boards R4-Gossip, R4-Quest, R4-Options): Codex draws the windows you get when you talk to an
-- NPC (gossip, a quest giver's greeting, a quest's offer, progress and reward pages) in one of three styles:
--   "a" Codex window: a themed window where the game's would be, as tall as its content (the default),
--   "b" subtitle bar: a bar at the bottom of the screen with the NPC in view and the choices beside it,
--   "c" book page: a page at the side of the screen.
-- All three are frames of ours. The game's own QuestFrame / GossipFrame still open and stay *shown* (so the
-- talk with the NPC stays open and every Blizzard behaviour keeps working: Escape, walking away, the
-- confirmation popups), but they are parked off the screen with alpha 0 (Blizzard.lua, as the Bags module parks
-- the bag windows). Closing ours closes theirs (CloseQuest / C_GossipInfo.CloseGossip); theirs closing closes ours.
-- Nothing here is protected: selecting gossip options and quests, AcceptQuest, CompleteQuest and GetQuestReward
-- can be called from any code, so our buttons are plain buttons. Keys (Keys.lua) never act in combat.
--
-- Files: Module.lua (settings, events, what is shown), RepData.lua (generated quest reputation table),
-- Reputation.lua, Blizzard.lua (parking, fading the game's interface), Data.lua (reads the game's quest and gossip
-- APIs into plain tables), Window.lua (the three styles' frames and shared pieces), Gossip.lua (lists), Quest.lua
-- (quest pages), Keys.lua, Auto.lua (auto accept / hand-in / the only service), Page.lua (settings).

local D = {}
ns.dialogue = D

D.DEFAULTS = {
  windows = true,       -- Codex draws the NPC windows (off: the game's own windows, Quest keys still works)
  style = "a",          -- "a" Codex window, "b" subtitle bar, "c" book page
  levels = true,        -- "[48]" before quest names, in the difficulty colour
  fontSize = 14,        -- body text size (the game's own is 13)
  size = "m",           -- window size for styles A and C: "s", "m", "l"
  numbers = true,       -- 1-9 pick the rows (keycaps beside them)
  escapeBack = true,    -- Escape on a quest page reached from the NPC's list goes back to the list
  tabRewards = true,    -- Tab moves to the next reward to choose
  statArrows = true,    -- Stat Delta's arrows and stat changes on reward items (when Stat Delta is on)
  fade = true,          -- styles B and C: fade the game's interface while talking (alpha only, never in a fight)
  service = false,      -- an NPC whose only option is a service (vendor, banker, trainer, flight master) opens it
  autoAccept = false,   -- accept quests by themselves
  autoTurnIn = false,   -- hand quests in by themselves
  pos = nil,            -- style A: where the player dragged the window, { point, relativePoint, x, y }
}

D.STYLES = {
  { key = "a", name = "A · Codex window", desc = "The game's window in the theme, sized to its content." },
  { key = "b", name = "B · Subtitle bar", desc = "A bar at the bottom of the screen; the NPC stays in view." },
  { key = "c", name = "C · Book page", desc = "A page at the side of the screen, like a storybook." },
}

D.SIZES = { s = 336, m = 388, l = 440 }

function D.DB()
  if not D.db then
    ns.db.dialogue = ns.Fill(type(ns.db.dialogue) == "table" and ns.db.dialogue or {}, D.DEFAULTS)
    D.db = ns.db.dialogue
    if not D.SIZES[D.db.size] then
      D.db.size = "m"
    end
    if D.db.style ~= "a" and D.db.style ~= "b" and D.db.style ~= "c" then
      D.db.style = "a"
    end
    D.db.fontSize = math.max(11, math.min(20, tonumber(D.db.fontSize) or 14))
  end
  return D.db
end

-- Values the game may hand out as secrets (Forever): never compared, measured or joined unless readable.
function D.Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

-- A readable string (secrets and non-strings give nil).
function D.Str(value)
  if type(value) == "string" and D.Readable(value) then
    return value
  end
  return nil
end

-- A text to show: a string as the game gave it, which may be a secret (then it only ever goes to SetText).
function D.Raw(value)
  if type(value) == "string" then
    return value
  end
  return nil
end

-- Is there something to show? A secret counts as text (it can't be looked at).
function D.HasText(value)
  if type(value) ~= "string" then
    return false
  end
  if not D.Readable(value) then
    return true
  end
  return value ~= ""
end

function D.Num(value)
  if type(value) == "number" and D.Readable(value) then
    return value
  end
  return nil
end

-- Calls a game function safely: nil when it's missing or fails.
local unpack = unpack or table.unpack
local function Pack(ok, ...)
  return ok, select("#", ...), { ... }
end
function D.Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, count, values = Pack(pcall(fn, ...))
  if not ok then
    return nil
  end
  return unpack(values, 1, count)
end

-- Does Codex draw the NPC windows now?
function D.Owns()
  return D.running and D.DB().windows and true or false
end

-- Is one of our windows on the screen?
function D.Active()
  return D.Owns() and D.page ~= nil and D.WindowShown and D.WindowShown() or false
end

-- What is shown ---------------------------------------------------------------------------------------------
-- D.page: the page model on the screen (Data.lua builds it), or nil. D.fromList: the quest page was reached from
-- the NPC's list (gossip or greeting), so Escape can go back to it.

local QUEST_PAGES = { detail = true, progress = true, reward = true }
D.QUEST_PAGES = QUEST_PAGES

function D.Show(kind)
  if not D.Owns() then
    return
  end
  local page = D.Read(kind)
  if not page then
    D.GiveBack()
    return
  end
  if kind == "gossip" or kind == "greeting" then
    D.fromList = false
  elseif D.picked then
    D.fromList = true -- the player picked this quest from our list
  elseif not QUEST_PAGES[D.lastKind or ""] then
    D.fromList = false -- the NPC went straight to the quest
  end -- else: the next page of the same quest (offer, progress, reward) keeps it
  D.picked = nil
  D.lastKind = kind
  page.fromList = QUEST_PAGES[kind] and D.fromList or false
  D.page = page
  D.ParkGame()
  D.restoreToken = nil
  local ok, err = pcall(D.Render, page)
  if not ok then
    -- never leave the player with an invisible window: the game's own comes back
    D.GiveBack()
    geterrorhandler()(err)
    return
  end
  if D.FadeWanted() then
    D.FadeGameUI()
  else
    D.RestoreGameUI()
  end
  if D.Keys then
    D.Keys.Update()
  end
  ns.Fire("DIALOGUE_SHOWN", kind)
end

-- Something went wrong drawing ours: hide it and give the game's windows back for this talk.
function D.GiveBack()
  D.page = nil
  if D.HideWindows then
    D.HideWindows()
  end
  D.UnparkGame()
  D.RestoreGameUI(true)
  if D.Keys then
    D.Keys.Update()
  end
end

-- The same page again with fresh data (items arrived, the quest log changed).
function D.Refresh()
  if D.page and D.Active() then
    local old = D.page
    local page = D.Read(old.kind)
    if page then
      page.fromList = old.fromList
      page.choice = old.choice
      page.part = old.part
      -- the text being written in carries on where it was (item data often arrives half way)
      page.keepReveal = { done = D.revealed, progress = D.reveal and D.reveal.progress }
      D.page = page
      local ok, err = pcall(D.Render, page)
      if not ok then
        D.GiveBack()
        geterrorhandler()(err)
      end
    end
  end
end

-- Our window goes away (the game closed the talk, or a page of the other kind follows).
function D.Hide()
  D.page = nil
  if D.HideWindows then
    D.HideWindows()
  end
  D.RestoreSoon()
  if D.Keys then
    D.Keys.Update()
  end
  ns.Fire("DIALOGUE_HIDDEN")
end

-- Closing ours ends the talk: the game closes its own window, and its event hides ours.
function D.Close()
  local page = D.page
  D.Hide()
  if page and (page.kind == "gossip") then
    if C_GossipInfo and C_GossipInfo.CloseGossip then
      pcall(C_GossipInfo.CloseGossip)
    end
  elseif page then
    if CloseQuest then
      pcall(CloseQuest)
    end
  end
  -- a quest page opened from a gossip list: the gossip is still open on the server side
  if _G.GossipFrame and _G.GossipFrame.IsShown and _G.GossipFrame:IsShown() and C_GossipInfo and C_GossipInfo.CloseGossip then
    pcall(C_GossipInfo.CloseGossip)
  end
  D.fromList = false
  D.lastKind = nil
end

-- After the game's window for the talk has closed: ours too, unless another one of the talk is open.
local function AfterClose(kind)
  if not D.page then
    return
  end
  if kind == "gossip" and D.page.kind ~= "gossip" then
    return
  end
  if kind == "quest" and D.page.kind == "gossip" then
    return
  end
  D.Hide()
end

-- Events ------------------------------------------------------------------------------------------------------

local events
local EVENTS = { "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "QUEST_FINISHED", "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

-- The game's window that belongs to each page (shown while that page of the talk is open).
local GAME_PANELS = { gossip = "GossipFrame", greeting = "QuestFrameGreetingPanel", detail = "QuestFrameDetailPanel",
  progress = "QuestFrameProgressPanel", reward = "QuestFrameRewardPanel" }

local function GameShows(kind)
  local frame = _G[GAME_PANELS[kind] or ""]
  if type(frame) == "table" and frame.IsShown then
    return frame:IsShown() and true or false
  end
  return D.GameWindowOpen()
end

-- An option acted by itself (Auto.lua). If the game is still on that page a second later (the action did nothing),
-- our window shows after all, so the parked game window is never left on its own.
local function Acted(kind, done)
  if not done then
    return false
  end
  C_Timer.After(1, function()
    if not D.page and D.Owns() and GameShows(kind) then
      D.Show(kind)
    end
  end)
  return true
end

local function OnEvent(_, event, ...)
  if event == "PLAYER_REGEN_DISABLED" then
    if D.Keys then
      D.Keys.CombatStarts()
    end
    D.RestoreGameUI(true)
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    if D.Keys then
      D.Keys.Update()
    end
    if D.page then
      D.FadeGameUI()
    end
    return
  end
  if not D.DB().windows and not (D.Auto and D.Auto.Wanted()) then
    return
  end
  if event == "GOSSIP_SHOW" then
    if D.Auto and Acted("gossip", D.Auto.OnGossip()) then
      return
    end
    if D.Owns() and not D.GameSkipsGossip() then
      D.Show("gossip")
    end
  elseif event == "GOSSIP_CLOSED" then
    AfterClose("gossip")
  elseif event == "QUEST_GREETING" then
    if D.Auto and Acted("greeting", D.Auto.OnGreeting()) then
      return
    end
    D.Show("greeting")
  elseif event == "QUEST_DETAIL" then
    local startItem = ...
    if D.GameSkipsDetail(startItem) then
      return
    end
    if D.Auto and Acted("detail", D.Auto.OnDetail()) then
      return
    end
    D.Show("detail")
  elseif event == "QUEST_PROGRESS" then
    if D.Auto and Acted("progress", D.Auto.OnProgress()) then
      return
    end
    D.Show("progress")
  elseif event == "QUEST_COMPLETE" then
    if D.Auto and Acted("reward", D.Auto.OnComplete()) then
      return
    end
    D.Show("reward")
  elseif event == "QUEST_FINISHED" then
    AfterClose("quest")
    if not D.picked then
      D.lastKind = nil
    end
  elseif event == "QUEST_ITEM_UPDATE" then
    if D.page and QUEST_PAGES[D.page.kind] then
      D.Refresh()
    end
  elseif event == "QUEST_LOG_UPDATE" then
    if D.page and (D.page.kind == "gossip" or D.page.kind == "greeting") then
      D.Refresh()
    end
  end
end

-- The game picks a gossip's only option itself (selectOptionWhenOnlyOption): no window then, as in the game.
function D.GameSkipsGossip()
  if not C_GossipInfo then
    return false
  end
  local available = D.Num(D.Call(C_GossipInfo.GetNumAvailableQuests)) or 0
  local active = D.Num(D.Call(C_GossipInfo.GetNumActiveQuests)) or 0
  local options = D.Call(C_GossipInfo.GetOptions)
  if available > 0 or active > 0 or type(options) ~= "table" or #options ~= 1 then
    return false
  end
  if D.Call(C_GossipInfo.ForceGossip) == true then
    return false
  end
  return type(options[1]) == "table" and options[1].selectOptionWhenOnlyOption == true
end

-- QUEST_DETAIL the game does not show (QuestFrame_OnEvent): a quest from an item goes to the tracker's pop-up, an
-- area-trigger auto quest too, an adventure-map quest to its own frame.
function D.GameSkipsDetail(startItem)
  if type(startItem) == "number" and D.Readable(startItem) and startItem ~= 0 then
    return true
  end
  if D.Call(_G.QuestIsFromAdventureMap) == true then
    return true
  end
  if D.Call(_G.QuestGetAutoAccept) == true and D.Call(_G.QuestIsFromAreaTrigger) == true then
    return true
  end
  return false
end

function D.Enable()
  D.DB()
  events = CreateFrame("Frame", "CodexDialogueEvents", UIParent)
  events:SetScript("OnEvent", OnEvent)
  for _, event in ipairs(EVENTS) do
    events:RegisterEvent(event)
  end
  D.events = events
  -- a font style of the quest windows changed (Quests > Fonts): the open page drawn again
  ns.OnFontStyle(function(key)
    if type(key) == "string" and key:find("^dialogue%.") then
      D.Refresh()
    end
  end)
  D.InstallGameHooks()
  if D.Keys then
    D.Keys.Create()
  end
  D.running = true
end

-- Settings ----------------------------------------------------------------------------------------------------

function D.Set(key, value)
  local db = D.DB()
  db[key] = value
  if key == "style" or key == "size" or key == "fontSize" or key == "levels" or key == "numbers" or key == "statArrows" then
    if D.page then
      D.HideWindows()
      D.Render(D.page)
    end
  elseif key == "fade" then
    if value and D.page then
      D.FadeGameUI()
    else
      D.RestoreGameUI()
    end
  elseif key == "windows" then
    if not value and D.page then
      D.page = nil
      D.HideWindows()
      D.UnparkGame()
    end
  end
  if D.Keys then
    D.Keys.Update()
  end
  if ns.questkeys and ns.questkeys.Update then
    ns.questkeys.Update()
  end
  if D.RefreshPage then
    D.RefreshPage()
  end
end

-- "Write the text in as the game does" is the game's own Instant Quest Text setting (CVar instantQuestText).
function D.TextWrittenIn()
  local value = D.Call(_G.C_CVar and C_CVar.GetCVar or _G.GetCVar, "instantQuestText")
  return value == "0"
end

function D.SetTextWrittenIn(on)
  local set = _G.C_CVar and C_CVar.SetCVar or _G.SetCVar
  if type(set) == "function" then
    pcall(set, "instantQuestText", on and "0" or "1")
  end
  if D.RefreshPage then
    D.RefreshPage()
  end
end

function D.StatusText()
  local state = ns.ModuleState("dialogue")
  if state == "standalone" then
    return "DialogueUI is loaded, so Codex leaves the NPC windows to it."
  elseif state == "off" or not D.running then
    return "Off: the game's own quest and gossip windows."
  end
  if not D.DB().windows then
    return "Codex leaves the windows to the game; the quest options below still work."
  end
  for _, style in ipairs(D.STYLES) do
    if style.key == D.DB().style then
      return "On: " .. style.name:gsub("^%a · ", "") .. "."
    end
  end
  return "On."
end

ns.RegisterModule({
  id = "dialogue",
  name = "Quest windows",
  -- its section in the Codex window (Areas.lua)
  area = "quests", sectionOrder = 10, pageEstimate = 600,
  standalone = "DialogueUI",
  icon = "Interface\\Icons\\INV_Misc_Book_09",
  desc = "Quest and gossip windows in the Codex look, in three styles, with number keys and reputation rewards.",
  order = 94,
  Enable = function()
    D.Enable()
  end,
  BuildPage = function(_, page)
    D.BuildPage(page)
  end,
  ShowPage = function()
    if D.RefreshPage then
      D.RefreshPage()
    end
  end,
  Status = function()
    return D.StatusText()
  end,
})
