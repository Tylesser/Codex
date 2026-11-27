local addonName, ns = ...

-- Commerce module, part 10: the Writ NPCs window (/codex commerce npcs, or "All NPCs" in the main window):
-- every NPC who takes Craftsman's Writs, grouped by zone, with all the writs it takes and which of them you hold,
-- so you can collect the writs of a zone's NPCs and deliver them in one trip. Then the writs whose NPC isn't
-- known yet. A search box filters by NPC, zone or writ; a row under it by writ level and your professions. Zones
-- (and the "not known yet" group) fold with the arrow on their line, or a click on it away from the auction house. Ported from Tylesser - Commerce Authority, drawn with
-- Codex's widgets.

local C = ns.commerce
local L = ns.L
local UI = ns.UI

local WIDTH = 440
local HEIGHT = 540
local PAD = 16
local INNER = WIDTH - PAD * 2
local ROW_HEIGHT = 17
local TOP = 130 -- where the list starts, below the search box, the filter row and the summary
local LEVELS = { false, "Journeyman", "Expert", "Artisan" } -- the level button's steps (false: every level)
local ROWS = math.floor((HEIGHT - TOP - 34) / ROW_HEIGHT)
local frame
local lines = {}
local held = {} -- the writs you hold (C.HeldWrits), as of the last rebuild
local offset = 0

-- Folded zones (by map ID, and "unknown" for the writs with no known NPC), kept between sessions.
local function Folded(key)
  local db = C.DB()
  return db ~= nil and db.npcFolded ~= nil and db.npcFolded[key] == true
end

local function ToggleFold(key)
  local db = C.DB()
  db.npcFolded = db.npcFolded or {}
  db.npcFolded[key] = not Folded(key) or nil
  C.RefreshNPCWindow()
end

local function FoldKey(line)
  if line.kind == "continent" then
    return "c" .. line.continent.id
  elseif line.kind == "zone" then
    return line.zone.mapID
  elseif line.kind == "unknown" then
    return "unknown"
  end
end

local function Writs(count)
  return count == 1 and L["1 writ"] or L["%d writs"]:format(count)
end

local function WritLabel(writID)
  local writ = C.WRITS[writID]
  local tier = C.WritTier(writID)
  local rep = C.WritReputation(writID)
  return ("%s |cff999999(%s, %s)|r"):format(writ and writ[3] or L["item %d"]:format(writID), C.TierName(tier and tier.name),
    rep and C.Number(rep) or "?")
end

-- "1 of 5 yours · 6g 20s" or "5 writs · 6g 20s": how many are yours, and what buying the rest costs ("+" when
-- some of them have no auction price yet).
local function CountAndCost(mine, count, cost, unpriced)
  local text = mine > 0 and ("|cff40ff40" .. L["%d of %d yours"]:format(mine, count) .. "|r") or Writs(count)
  if cost > 0 then
    text = text .. (" |cff999999· %s%s|r"):format(C.ShortMoney(cost), unpriced > 0 and "+" or "")
  end
  return text
end

local function WritState(writID, mineByID)
  local mine = mineByID[writID]
  if mine then
    if mine.ready then
      return "|cff40ff40" .. L["yours, ready"] .. "|r"
    end
    return mine.questID and ("|cffffd100" .. L["yours, needs the item"] .. "|r")
      or ("|cffffffff" .. L["yours, not opened"] .. "|r")
  end
  if C.WritDoneToday(writID) then
    return "|cff999999" .. L["done today"] .. "|r"
  end
  local total = C.WritCost(writID)
  return total and C.Money(total) or ("|cff999999" .. L["no AH price"] .. "|r")
end

-- "Buying the others: 6g on the auction house, plus 2 with no price yet."
local function BuyingOthers(cost, unpriced)
  if unpriced > 0 then
    return L["Buying the others: %s on the auction house, plus %d with no price yet."]:format(C.Money(cost), unpriced)
  end
  return L["Buying the others: %s on the auction house."]:format(C.Money(cost))
end

-- Rows ----------------------------------------------------------------------------------------------------

local function OnEnter(row)
  local line = row.line
  if not line then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if line.kind == "writ" then
    if GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(line.writID)
    else
      GameTooltip:SetHyperlink("item:" .. line.writID)
    end
    GameTooltip:AddLine(L["Click at the auction house to search for it. Shift-click to link it."], 0.6, 0.6, 0.6)
  elseif line.kind == "continent" then
    local continent = line.continent
    GameTooltip:AddLine(continent.name)
    GameTooltip:AddLine(L["%d zones, %d NPCs, %d writs; you hold %d."]:format(#continent.zones, continent.npcs,
      continent.writs, continent.held), 1, 1, 1)
    GameTooltip:AddLine(L["Click to fold its zones."], 0.6, 0.6, 0.6, true)
  elseif line.kind == "zone" then
    local zone = line.zone
    GameTooltip:AddLine(zone.name)
    GameTooltip:AddLine(L["%d NPCs take %d writs here; you hold %d."]:format(#zone.npcs, zone.writs, zone.held),
      1, 1, 1)
    if zone.cost > 0 then
      GameTooltip:AddLine(BuyingOthers(zone.cost, zone.unpriced), 0.25, 1, 0.25, true)
    end
    GameTooltip:AddLine(L["Click at the auction house: search for the writs here you don't have, and their items. Way: waypoints to the NPCs here (all of them with TomTom, else the first)."], 0.6, 0.6, 0.6, true)
  elseif line.kind == "npc" then
    local customer = line.group.customer
    GameTooltip:AddLine(customer.name)
    GameTooltip:AddLine(("%s %.1f, %.1f%s"):format(line.group.zone, customer.x, customer.y,
      customer.learned and (" " .. L["(seen at your turn-in)"]) or customer.collected and (" " .. L["(players' data)"])
      or ""), 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L["Takes %d writs; you hold %d."]:format(#line.group.writs, line.group.held), 1, 1, 1)
    if line.group.cost > 0 then
      GameTooltip:AddLine(BuyingOthers(line.group.cost, line.group.unpriced), 0.25, 1, 0.25, true)
    end
    GameTooltip:AddLine(L["Click at the auction house: search for its writs you don't have, and their items. Way: waypoint to %s."]:format(customer.name), 0.6, 0.6, 0.6, true)
  else
    GameTooltip:AddLine(L["Who takes these isn't known yet"])
    GameTooltip:AddLine(L["Use the writ and the game marks the spot on your map. Codex remembers the NPC once you turn one in."], 1, 1, 1, true)
  end
  GameTooltip:Show()
end

local function Row()
  local row = CreateFrame("Button", nil, frame)
  row:SetSize(INNER, ROW_HEIGHT)
  C.RowHighlight(row)
  row.way = UI.Button(row, 40, 16, L["Way"])
  row.way:SetPoint("RIGHT", 0, 0)
  row.start = UI.Button(row, 44, 15, L["Start"])
  row.start:SetPoint("RIGHT", 0, 0)
  row.start:SetScript("OnClick", function()
    local line = row.line
    if line and line.kind == "writ" then
      local ok, why = C.StartWrit(line.writID)
      if not ok and why then
        ns.Say(why)
      end
    end
  end)
  row.start:Hide()
  row.way:SetScript("OnClick", function()
    local line = row.line
    if line and line.kind == "zone" then
      C.SetZoneWaypoints(line.zone)
    elseif line and line.group then
      C.SetCustomerWaypoint(line.group.customer)
    end
  end)
  row.fold = CreateFrame("Button", nil, row)
  row.fold:SetSize(14, ROW_HEIGHT)
  row.fold:SetPoint("LEFT", 0, 0)
  row.fold.arrow = UI.FoldArrow(row.fold, ns.Theme().accent)
  row.fold.arrow:SetPoint("CENTER")
  row.fold:SetScript("OnClick", function()
    local key = row.line and FoldKey(row.line)
    if key then
      ToggleFold(key)
    end
  end)
  row.name = C.WindowText(row)
  row.name:SetWordWrap(false)
  row.state = C.WindowText(row)
  row.state:SetJustifyH("RIGHT")
  row:SetScript("OnEnter", OnEnter)
  row:SetScript("OnLeave", C.HideTooltip)
  row:SetScript("OnClick", function(self)
    local line = self.line
    if not line then
      return
    end
    if line.kind == "writ" and IsShiftKeyDown and IsShiftKeyDown() then
      local link = C.ItemLink(line.writID)
      if link and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
      end
      return
    end
    if line.kind == "continent" or not C.AuctionHouseOpen() then
      local key = FoldKey(line)
      if key then
        ToggleFold(key) -- away from the auction house a zone line folds
      end
      return
    end
    local writIDs = {}
    if line.kind == "writ" then
      writIDs[1] = line.writID
    elseif line.kind == "npc" then
      writIDs = line.group.writs
    elseif line.kind == "zone" then
      for _, group in ipairs(line.zone.npcs) do
        for _, writID in ipairs(group.writs) do
          writIDs[#writIDs + 1] = writID
        end
      end
    end
    C.SearchWrits(writIDs, held)
  end)
  return row
end

local function ShowFold(row, key)
  if not key then
    row.fold:Hide()
    return
  end
  row.fold.arrow:SetOpen(not Folded(key))
  row.fold:Show()
end

local function ShowLine(row, line, mineByID)
  row.line = line
  row.name:ClearAllPoints()
  row.state:ClearAllPoints()
  ShowFold(row, FoldKey(line))
  row.start:Hide()
  row.fold:ClearAllPoints()
  row.fold:SetPoint("LEFT", line.kind == "zone" and 12 or 0, 0)
  if line.kind == "continent" then
    local continent = line.continent
    row.way:Hide()
    row.name:SetPoint("LEFT", 18, 0)
    row.name:SetPoint("RIGHT", -150, 0)
    C.SetToned(row.name, ("|cffffd100%s|r |cff999999%s|r"):format(continent.name,
      #continent.zones == 1 and L["1 zone"] or L["%d zones"]:format(#continent.zones)))
    row.state:SetPoint("RIGHT", -2, 0)
    C.SetToned(row.state, CountAndCost(continent.held, continent.writs, continent.cost, continent.unpriced))
  elseif line.kind == "zone" then
    local zone = line.zone
    row.way:Show()
    row.name:SetPoint("LEFT", 30, 0)
    row.name:SetPoint("RIGHT", -206, 0)
    C.SetToned(row.name, ("|cffff9933%s|r |cff999999%s|r"):format(zone.name,
      #zone.npcs == 1 and L["1 NPC"] or L["%d NPCs"]:format(#zone.npcs)))
    row.state:SetPoint("RIGHT", -46, 0)
    C.SetToned(row.state, CountAndCost(zone.held, zone.writs, zone.cost, zone.unpriced))
  elseif line.kind == "npc" then
    local group = line.group
    row.way:Show()
    row.name:SetPoint("LEFT", 24, 0)
    row.name:SetPoint("RIGHT", -206, 0)
    C.SetToned(row.name, ("|cffffd100%s|r |cff999999%.1f, %.1f|r"):format(group.customer.name, group.customer.x,
      group.customer.y))
    row.state:SetPoint("RIGHT", -46, 0)
    C.SetToned(row.state, CountAndCost(group.held, #group.writs, group.cost, group.unpriced))
  elseif line.kind == "writ" then
    row.way:Hide()
    local mine = mineByID[line.writID]
    local startable = mine and mine.ready and not mine.questID and not (InCombatLockdown and InCombatLockdown())
    row.start:SetShown(startable and true or false)
    row.name:SetPoint("LEFT", line.group and 36 or 12, 0)
    row.name:SetPoint("RIGHT", -150, 0)
    C.SetToned(row.name, WritLabel(line.writID))
    row.state:SetPoint("RIGHT", startable and -50 or -2, 0)
    C.SetToned(row.state, WritState(line.writID, mineByID))
  else
    row.way:Hide()
    row.name:SetPoint("LEFT", 18, 0)
    row.name:SetPoint("RIGHT", -2, 0)
    C.SetToned(row.name, ("|cffffd100%s|r |cff999999(%s)|r"):format(L["NPC not known yet"], L["%d writs"]:format(line.count)))
    row.state:SetPoint("RIGHT", -2, 0)
    row.state:SetText("")
  end
  row:Show()
end

-- Window --------------------------------------------------------------------------------------------------

local function Scroll(delta)
  local maxOffset = math.max(#lines - ROWS, 0)
  offset = math.min(math.max(offset - delta * (IsShiftKeyDown and IsShiftKeyDown() and 10 or 3), 0), maxOffset)
  C.RefreshNPCWindow(true)
end

local function Create()
  frame = C.NewWindow("CodexCommerceNPCWindow", L["Writ NPCs"], WIDTH, HEIGHT, "npcPosition",
    { "CENTER", "CENTER", 420, 40 })
  frame:SetScript("OnShow", function()
    C.RefreshNPCWindow()
  end)
  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(_, delta)
    Scroll(delta)
  end)

  local search = UI.EditBox(frame, INNER, 22)
  search:SetPoint("TOPLEFT", PAD, -48)
  search.hint = UI.Text(search, "body", 11, "muted")
  search.hint:SetPoint("LEFT", 6, 0)
  search.hint:SetText(L["Search an NPC, zone or writ"])
  search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    offset = 0
    C.RefreshNPCWindow()
  end)
  search:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  frame.search = search

  local level = UI.Button(frame, 96, 20, L["All levels"])
  level:SetPoint("TOPLEFT", PAD, -78)
  level:SetScript("OnClick", function()
    local db = C.DB()
    local current = 1
    for index, name in ipairs(LEVELS) do
      if (name or nil) == db.npcTier then
        current = index
      end
    end
    db.npcTier = LEVELS[current % #LEVELS + 1] or nil
    offset = 0
    C.RefreshNPCWindow()
  end)
  level:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Writ level"])
    GameTooltip:AddLine(L["Click to show every level, or only Journeyman, Expert or Artisan writs."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  level:SetScript("OnLeave", C.HideTooltip)
  frame.level = level
  local mine = UI.Check(frame, L["My professions"])
  mine:SetPoint("LEFT", level, "RIGHT", 10, 0)
  UI.Font(mine.label, "body", 11, "text")
  mine:SetScript("OnClick", function(self)
    C.DB().npcMine = self:GetChecked() and true or false
    offset = 0
    C.RefreshNPCWindow()
  end)
  C.FitCheck(mine)
  frame.mine = mine
  local notDone = UI.Check(frame, L["Not done today"])
  notDone:SetPoint("LEFT", mine.label or mine.Text or mine, "RIGHT", 8, 0)
  notDone:SetScript("OnClick", function(self)
    C.DB().npcNotDone = self:GetChecked() and true or false
    offset = 0
    C.RefreshNPCWindow()
  end)
  notDone:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Not done today"])
    GameTooltip:AddLine(L["Every writ can be turned in once a day: show only the ones you haven't turned in since the daily reset."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  notDone:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  UI.Font(notDone.label, "body", 11, "text")
  C.FitCheck(notDone)
  frame.notDone = notDone
  local foldAll = UI.Button(frame, 80, 20, L["Fold all"])
  foldAll:SetPoint("TOPRIGHT", -PAD, -78)
  foldAll:SetScript("OnClick", function()
    local db = C.DB()
    local anyOpen = false
    for _, line in ipairs(lines) do
      local key = FoldKey(line)
      if key and not Folded(key) then
        anyOpen = true
      end
    end
    db.npcFolded = {}
    if anyOpen then
      for _, line in ipairs(lines) do
        local key = FoldKey(line)
        if key then
          db.npcFolded[key] = true
        end
      end
    end
    offset = 0
    C.RefreshNPCWindow()
  end)
  frame.foldAll = foldAll

  frame.summary = C.WindowText(frame, 11)
  frame.summary:SetPoint("TOPLEFT", PAD, -106)
  frame.summary:SetPoint("RIGHT", -PAD, 0)
  frame.summary:SetWordWrap(false)

  frame.rows = {}
  for index = 1, ROWS do
    local row = Row()
    row:SetPoint("TOPLEFT", PAD, -TOP - (index - 1) * ROW_HEIGHT)
    frame.rows[index] = row
  end

  frame.footer = C.WindowText(frame, 10, "muted")
  frame.footer:SetPoint("BOTTOMLEFT", PAD, 14)
  frame.footer:SetPoint("RIGHT", -PAD, 0)
  frame.footer:SetWordWrap(false)
end

-- Rebuilds the list (unless `keep`, when only scrolling) and shows the rows from the scroll offset.
function C.RefreshNPCWindow(keep)
  if not (frame and frame:IsShown()) then
    return
  end
  if not keep then
    local db = C.DB()
    local text = frame.search:GetText() or ""
    local directory = C.CustomerDirectory(nil, text:lower():match("^%s*(.-)%s*$"),
      { tier = db.npcTier, mine = db.npcMine, notDone = db.npcNotDone })
    frame.level:SetText(db.npcTier and C.TierName(db.npcTier) or L["All levels"])
    frame.mine:SetChecked(db.npcMine and true or false)
    frame.notDone:SetChecked(db.npcNotDone and true or false)
    held = directory.held
    lines = {}
    local writs, mine = 0, 0
    local anyOpen = false
    -- zones under their continents (in the order of their first zone)
    local continents, byID = {}, {}
    for _, zone in ipairs(directory.zones) do
      local id, name = C.ContinentOf(zone.mapID)
      local continent = byID[id]
      if not continent then
        continent = { id = id, name = name, zones = {}, npcs = 0, writs = 0, held = 0, cost = 0, unpriced = 0 }
        byID[id] = continent
        continents[#continents + 1] = continent
      end
      continent.zones[#continent.zones + 1] = zone
      continent.npcs = continent.npcs + #zone.npcs
      continent.writs = continent.writs + zone.writs
      continent.held = continent.held + zone.held
      continent.cost = continent.cost + (zone.cost or 0)
      continent.unpriced = continent.unpriced + (zone.unpriced or 0)
    end
    for _, continent in ipairs(continents) do
      lines[#lines + 1] = { kind = "continent", continent = continent }
      local closed = Folded("c" .. continent.id)
      anyOpen = anyOpen or not closed
      for _, zone in ipairs(continent.zones) do
        local folded = closed or Folded(zone.mapID)
        if not closed then
          lines[#lines + 1] = { kind = "zone", zone = zone }
          anyOpen = anyOpen or not folded
        end
        for _, group in ipairs(zone.npcs) do
          if not folded then
            lines[#lines + 1] = { kind = "npc", group = group }
            for _, writID in ipairs(group.writs) do
              lines[#lines + 1] = { kind = "writ", writID = writID, group = group }
            end
          end
          writs = writs + #group.writs
          mine = mine + group.held
        end
      end
    end
    if #directory.unknown > 0 then
      lines[#lines + 1] = { kind = "unknown", count = #directory.unknown }
      local folded = Folded("unknown")
      anyOpen = anyOpen or not folded
      for _, writID in ipairs(directory.unknown) do
        if not folded then
          lines[#lines + 1] = { kind = "writ", writID = writID }
        end
        if held[writID] then
          mine = mine + 1
        end
      end
    end
    frame.foldAll:SetText(anyOpen and L["Fold all"] or L["Unfold all"])
    frame.summary:SetText(L["%d NPCs in %d zones take %d writs; %d with no known NPC. You hold %d."]:format(
      #directory.npcs, #directory.zones, writs, #directory.unknown, mine))
    offset = math.min(offset, math.max(#lines - ROWS, 0))
  end
  for index, row in ipairs(frame.rows) do
    local line = lines[offset + index]
    if line then
      ShowLine(row, line, held)
    else
      row.line = nil
      row:Hide()
    end
  end
  if #lines == 0 then
    frame.footer:SetText(L["Nothing matches."])
  elseif #lines > ROWS then
    frame.footer:SetText(L["Lines %d-%d of %d. Scroll with the mouse wheel."]:format(offset + 1,
      math.min(offset + ROWS, #lines), #lines))
  else
    frame.footer:SetText("")
  end
end

function C.ToggleNPCWindow()
  if not C.running then
    ns.Say(L["the Commerce module is off; switch it on in the Codex window."])
    return
  end
  if not frame then
    Create()
  end
  frame:SetShown(not frame:IsShown())
end

function C.NPCWindowShown()
  return frame ~= nil and frame:IsShown()
end

function C.NPCWindow()
  return frame
end

function C.ScrollNPCWindow(delta)
  Scroll(delta)
end
