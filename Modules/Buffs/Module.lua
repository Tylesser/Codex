local addonName, codex = ...
local ns = codex.buffs

-- Start-up, events, the 0.2 second tick and the /codex buffs commands, and the module's registration.
-- Buff Tracker set up on its own ADDON_LOADED; here everything happens in Enable, which Codex calls once
-- at PLAYER_LOGIN when the module is on. The first PLAYER_ENTERING_WORLD still comes after it, and reads
-- the buffs (ns.Changed) just as before.

local TICK_SECONDS = 0.2

-- Saved per character in CodexCharDB.buffs, the same shape as Buff Tracker's BuffTrackerDB.
local function SetupDB()
  local db = codex.char.buffs or {}
  codex.char.buffs = db
  for key, value in pairs(ns.defaults) do
    if db[key] == nil then
      db[key] = value
    end
  end
  db.tracked = db.tracked or {}
  ns.db = db
end

-- where and when the row shows (Conditions.lua): only a redraw, no rescan (group updates come often in a raid)
local CONDITION_EVENTS = { ZONE_CHANGED_NEW_AREA = true, PLAYER_UPDATE_RESTING = true, GROUP_ROSTER_UPDATE = true,
  ACTIVE_TALENT_GROUP_CHANGED = true, PLAYER_TALENT_UPDATE = true } -- (talents: also once known after a login)

local function OnEvent(self, event, arg)
  if not ns.db then
    return
  end
  if CONDITION_EVENTS[event] then
    ns.UpdateDisplay()
    ns.RefreshConditions()
    return
  end
  if event == "GET_ITEM_INFO_RECEIVED" then
    if not ns.ItemPending(arg) then -- arg is the item ID here
      return
    end
    ns.ScanBags()
  elseif event == "BAG_UPDATE_DELAYED" then
    ns.ScanBags()
  elseif event == "SPELLS_CHANGED" then
    ns.RefreshKnown() -- before the click overlays are laid out again: they depend on known spells
  end
  if event == "PLAYER_ENTERING_WORLD" and #ns.db.tracked == 0 and not ns.db.welcomed then
    ns.db.welcomed = true
    -- a few seconds later, after the login messages (Codex's own come right after PLAYER_LOGIN)
    local function Welcome()
      print(ns.PREFIX .. "type /codex buffs to choose the buffs to track.")
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(4, Welcome)
    else
      Welcome()
    end
  end
  ns.Changed()
end

local function CreateEventFrame()
  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  eventFrame:RegisterEvent("SPELLS_CHANGED")
  eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
  eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
  eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player") -- weapon enchants, where nothing else fires
  pcall(eventFrame.RegisterEvent, eventFrame, "WEAPON_ENCHANT_CHANGED") -- Retail only
  pcall(eventFrame.RegisterEvent, eventFrame, "MINIMAP_UPDATE_TRACKING") -- Find Minerals etc. switched
  for event in pairs(CONDITION_EVENTS) do
    pcall(eventFrame.RegisterEvent, eventFrame, event) -- (the talent event: not in every game)
  end
  eventFrame:SetScript("OnEvent", OnEvent)

  local sinceTick = 0
  eventFrame:SetScript("OnUpdate", function(_, elapsed)
    sinceTick = sinceTick + elapsed
    if sinceTick >= TICK_SECONDS and ns.db then
      ns.Tick(sinceTick)
      ns.PartyTick(sinceTick)
      sinceTick = 0
    end
  end)
  ns.eventFrame = eventFrame
end

-- What Buff Tracker did on ADDON_LOADED. The frames are made in the same order as Buff Tracker's
-- (combat frame, party events, main events), so each event reaches them in the same order.
local function Enable()
  SetupDB()
  ns.SetupParty()
  ns.SetupDispel()
  ns.CreateDisplay() -- the icon row, and the combat frame for the click overlays
  ns.CreatePartyEvents()
  CreateEventFrame()
end

local function PrintList()
  if #ns.db.tracked == 0 then
    print(ns.PREFIX .. "nothing tracked yet.")
    return
  end
  print(ns.PREFIX .. "tracked buffs:")
  for _, entry in ipairs(ns.db.tracked) do
    local state = ns.StateOf(entry)
    local current = "|cffaaaaaaunknown|r"
    if state and state.active then
      current = "|cff20ff20on|r"
    elseif state and state.known then
      current = "|cffff4040missing|r"
    end
    print("  " .. entry.name .. ": " .. current .. " (show: " .. ns.MODE_LABELS[entry.mode] .. ")")
  end
  if not ns.scanComplete then
    print("  The game is hiding your buffs right now, so these may be out of date.")
  end
end

-- /codex buffs <msg> (Codex's Events.lua opens the Buffs page first).
function ns.Slash(msg)
  if not ns.db then
    codex.Say("the buff tracker isn't running: switch it on in Codex (Buffs > Buff tracker) and reload.")
    return
  end
  msg = strtrim(msg or "")
  local command, rest = msg:match("^(%S+)%s*(.*)$")
  command = command and command:lower() or ""

  if command == "" then
    ns.OpenOptions()
  elseif command == "add" then
    local entry, reason = ns.AddBuff(rest)
    if entry then
      print(ns.PREFIX .. "now tracking " .. entry.name .. ".")
    else
      print(ns.PREFIX .. reason)
    end
  elseif command == "remove" then
    if ns.RemoveBuff(rest) then
      print(ns.PREFIX .. "stopped tracking " .. rest .. ".")
    else
      print(ns.PREFIX .. rest .. " is not tracked.")
    end
  elseif command == "basics" then
    ns.AddPreset()
  elseif command == "item" then
    -- item <buff> = <item name, ID or link>; without "= item" it goes back to none
    local name, item = rest:match("^(.-)%s*=%s*(.-)$")
    name = strtrim(name or rest)
    local entry = ns.FindTracked(name)
    if not entry then
      print(ns.PREFIX .. (name ~= "" and name or "that buff") .. " is not tracked.")
    elseif not item or item == "" then
      ns.SetItem(entry, nil)
      print(ns.PREFIX .. entry.name .. " no longer uses an item.")
    else
      local id = ns.ResolveItem(item)
      if id and ns.IsEquippable(id) then
        print(ns.PREFIX .. "that item is worn, not used: clicking it would equip it.")
      elseif id then
        ns.SetItem(entry, id)
        print(ns.PREFIX .. "clicking " .. entry.name .. " now uses " .. (ns.ItemName(id) or ("item " .. id)) .. ".")
      else
        print(ns.PREFIX .. "no item called " .. item .. " found. Try its item ID, or shift-click it into the line.")
      end
    end
  elseif command == "party" then
    ns.OpenPartyOptions()
  elseif command == "dispel" or command == "dispels" then
    ns.OpenDispelOptions()
  elseif command == "debug" then
    ns.PartyDebug()
    print(ns.PREFIX .. "tracking: " .. ns.TrackingDebug())
  elseif command == "feedback" then
    codex.T.ShowFeedback()
  elseif command == "list" then
    PrintList()
  elseif command == "lock" or command == "unlock" then
    ns.SetLocked(command == "lock")
  elseif command == "reset" then
    ns.ResetPosition()
  else
    print(ns.PREFIX .. "commands:")
    print("  /codex buffs: open the options, /codex buffs party: party buff buttons and blessings")
    print("  /codex buffs dispel: dispel buttons for your party and yourself")
    print("  /codex buffs add <name or spell ID>, /codex buffs remove <name>, /codex buffs list")
    print("  /codex buffs basics: track the basic buffs of your class")
    print("  /codex buffs item <buff> = <item>: the item a click on that icon uses")
    print("  /codex buffs lock, /codex buffs unlock, /codex buffs reset (put the icons back in place)")
    print("  /codex buffs debug: show what the party buttons see")
    print("  /codex buffs feedback: report a bug or suggest an idea")
  end
end

-- A short live line for the Home page.
local function Status()
  if not ns.db then
    return ""
  end
  local tracked, missing = #ns.db.tracked, 0
  if tracked == 0 then
    return "Nothing tracked yet: pick your buffs on the Buffs page."
  end
  for _, entry in ipairs(ns.db.tracked) do
    local state = ns.StateOf(entry)
    if state and state.known and not state.active then
      missing = missing + 1
    end
  end
  return ("%d tracked, %d missing now."):format(tracked, missing)
end

codex.RegisterModule({
  id = "buffs",
  name = "Buffs",
  -- its section in the Codex window (Areas.lua)
  area = "auras", sectionOrder = 10, sectionTitle = "Buff tracker", pageHeight = function() return ns.db and 460 or nil end, -- the off text is short
  icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
  desc = "A row of the buffs you choose, and click-to-buff and dispel buttons by your party frames.",
  standalone = "BuffTracker",
  standaloneName = "Buff Tracker",
  order = 30,
  Enable = function()
    Enable()
  end,
  BuildPage = function(module, page)
    ns.BuildPage(module, page)
  end,
  ShowPage = function(module, page)
    ns.ShowPage(module, page)
  end,
  Status = Status,
  Slash = function(module, rest)
    ns.Slash(rest)
  end,
  commands = {
    -- /codex party and /codex dispel, the two other option tabs (Buff Tracker's /btrack party, /btrack dispel)
    party = function()
      ns.Slash("party")
    end,
    dispel = function()
      ns.Slash("dispel")
    end,
  },
})
