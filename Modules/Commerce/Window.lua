local addonName, ns = ...

-- Commerce module, part 9: the Commerce Authority window (/codex commerce, /aca), in two tabs (2026-11-28, the
-- user's request: writs and crates are not the same thing, give crates their own section). Writs: reputation,
-- the writs in your bags, the ones you hold grouped by who takes them (with waypoints), how far each standing is
-- and the cheapest reputation on the auction house (with the Codex buy list). Crates: Merchant's Favor, the
-- crates in your bags, the ones you have to fill and every crate on the auction house by crate price + cheapest
-- fill. Under both: this session's turn-ins. Ported from Tylesser - Commerce Authority's window, drawn with
-- Codex's widgets in the active theme.

local C = ns.commerce
local L = ns.L
local UI = ns.UI

local WIDTH = 400
local HEIGHT = 580
local PAD = 16
local INNER = WIDTH - PAD * 2
local TITLE_H = 34
local CHEAP_ROWS = 8
local DELIVERY_ROWS = 4
local FILL_ROWS = 5 -- the Crates tab: crates to fill
local RANK_ROWS = 12 -- the Crates tab: the crate ranking (scrolls)
-- the cheapest list's rankings, switched by one button
local MODE_LABELS = { writ = L["By writ"], npc = L["By NPC"], zone = L["By zone"] }
local NEXT_MODE = { writ = "npc", npc = "zone", zone = "writ" }
local MODE_HELP = {
  writ = L["Writs sorted by what each costs per 100 reputation (the writ and the item it asks for)."],
  npc = L["The NPCs who take writs, by what buying all their priced writs costs per 100 reputation: one shopping list, one trip."],
  zone = L["Zones, by what buying all the priced writs their NPCs take costs per 100 reputation: one shopping list, one trip around the zone."],
}
local crateOffset = 0 -- the crate ranking scrolls (with the mouse wheel)
local window

-- "1 writ" / "5 writs" and the like.
local function Writs(count)
  return count == 1 and L["1 writ"] or L["%d writs"]:format(count)
end

-- The standalone addon's colour codes in the theme's own colours (a light theme needs darker ones).
local TONES = { ["|cff999999"] = "muted", ["|cff666666"] = "muted", ["|cff40ff40"] = "good", ["|cffffd100"] = "warn",
  ["|cffff9933"] = "accent", ["|cffffffff"] = "bright" }
function C.Tone(text)
  if type(text) ~= "string" or not ns.Hex then
    return text
  end
  local theme = ns.Theme()
  return (text:gsub("|cff%x%x%x%x%x%x", function(code)
    local key = TONES[code:lower()]
    local color = key and theme[key]
    return color and ("|cff" .. ns.Hex(color)) or code
  end))
end

local function Text(parent, size, color)
  local text = UI.Text(parent, "body", size or 11, color or "text")
  text:SetJustifyH("LEFT")
  return text
end
C.WindowText = Text

local function SetText(fontString, text)
  fontString:SetText(C.Tone(text))
end
C.SetToned = SetText

-- A movable Codex window: panel, title, close button, the line under the title; its place in C.db[key].
function C.NewWindow(name, title, width, height, key, default)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetSize(width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    C.DB()[key] = { point, relativePoint, x, y }
  end)
  UI.Panel(frame, { cornerSize = 14 })
  frame.title = UI.Text(frame, "head", 15, "accent")
  frame.title:SetPoint("LEFT", frame, "TOPLEFT", PAD, -TITLE_H / 2 - 2)
  frame.title:SetText(title)
  local close = UI.CloseButton(frame)
  close:SetPoint("RIGHT", frame, "TOPRIGHT", -10, -TITLE_H / 2 - 2)
  local line = UI.Divider(frame)
  line:SetPoint("TOPLEFT", PAD - 4, -TITLE_H - 2)
  line:SetPoint("TOPRIGHT", -PAD + 4, -TITLE_H - 2)
  table.insert(UISpecialFrames, name) -- Esc closes it, like other windows
  frame:ClearAllPoints()
  local position = C.DB()[key]
  if type(position) == "table" and position[1] then
    frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
  else
    frame:SetPoint(default[1], UIParent, default[2], default[3], default[4])
  end
  frame:Hide()
  return frame
end

-- A check box clickable over its own label only: the shared check boxes reach 200+ px to the right, and in a row
-- of controls they covered the next one (hovering "Not done today" lit "My professions", 2026-11-19).
function C.FitCheck(check)
  local label = check.label or check.Text
  local width = label and label.GetStringWidth and label:GetStringWidth()
  if type(width) ~= "number" or width <= 0 then
    -- not measured yet (before the first show): about 6 px a letter at these sizes
    local text = label and label.GetText and label:GetText()
    width = type(text) == "string" and #text * 6 or 90
  end
  check:SetHitRectInsets(0, -(math.ceil(width) + 6), 0, 0)
end

-- A row's hover in the theme's accent.
function C.RowHighlight(row)
  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  UI.SetColor(highlight, ns.Theme().accent, 0.1)
  return highlight
end

local function HideTooltip()
  GameTooltip:Hide()
end
C.HideTooltip = HideTooltip

local function ItemTooltip(owner, itemID, hint)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then
    GameTooltip:SetItemByID(itemID)
  else
    GameTooltip:SetHyperlink("item:" .. itemID)
  end
  if hint then
    GameTooltip:AddLine(hint, 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end
C.ItemTooltip = ItemTooltip

-- A section heading: the name in the accent, a thin line after it to the right edge (or to `right` px short).
local function Heading(y, text, right, parent)
  parent = parent or window
  local heading = UI.Text(parent, "head", 13, "accent")
  heading:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
  heading:SetText(text)
  local line = UI.Divider(parent)
  line:SetPoint("LEFT", heading, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", window, "RIGHT", -PAD - (right or 0), 0)
  return heading
end

local function LinkItem(itemID)
  local link = C.ItemLink(itemID)
  if link and ChatEdit_InsertLink then
    ChatEdit_InsertLink(link)
  end
end

-- Cheapest list rows ---------------------------------------------------------------------------------

local function CustomerTooltip(row)
  local group = row.group
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local customer = group.customer
  GameTooltip:AddLine(customer.name)
  GameTooltip:AddLine(("%s %.1f, %.1f"):format(C.MapName(customer.mapID), customer.x, customer.y), 0.6, 0.6, 0.6)
  for _, entry in ipairs(group.writs) do
    local writ = C.WRITS[entry.writID]
    local tier = C.WritTier(entry.writID)
    GameTooltip:AddDoubleLine(("%s |cff999999(%s, %d)|r"):format(writ[3], C.TierName(tier.name), entry.rep),
      C.Money(entry.total), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine(L["All %d: %s for %s reputation, %s per 100"]:format(#group.writs, C.Money(group.total),
    C.Number(group.rep), C.Money(group.per100)), 0.25, 1, 0.25)
  if group.have > 0 then
    local text = group.have == 1 and L["You also hold 1 writ for %s: deliver it on the same trip."]:format(customer.name)
      or L["You also hold %d writs for %s: deliver them on the same trip."]:format(group.have, customer.name)
    GameTooltip:AddLine(text, 1, 0.82, 0, true)
  end
  local missing = #C.CustomerWrits(customer) - #group.writs - group.have
  if missing > 0 then
    local text = missing == 1 and L["1 more writ for %s with no auction price yet."]:format(customer.name)
      or L["%d more writs for %s with no auction price yet."]:format(missing, customer.name)
    GameTooltip:AddLine(text, 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddLine(L["Click: search the auction house for these writs and their items (the materials, for items cheaper to craft) when it's open, else make the Codex buy list. Way: waypoint to %s."]:format(customer.name), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function ZoneTooltip(row)
  local zone = row.zone
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(zone.name)
  for _, group in ipairs(zone.npcs) do
    local customer = group.customer
    GameTooltip:AddLine(("%s |cff999999%.1f, %.1f|r"):format(customer.name, customer.x, customer.y), 1, 0.82, 0)
    for _, entry in ipairs(group.writs) do
      local writ = C.WRITS[entry.writID]
      local tier = C.WritTier(entry.writID)
      GameTooltip:AddDoubleLine(("  %s |cff999999(%s, %d)|r"):format(writ[3], C.TierName(tier.name), entry.rep),
        C.Money(entry.total), 1, 1, 1, 1, 1, 1)
    end
  end
  GameTooltip:AddLine(L["All %d writs: %s for %s reputation, %s per 100"]:format(#zone.writs, C.Money(zone.total),
    C.Number(zone.rep), C.Money(zone.per100)), 0.25, 1, 0.25)
  if zone.have > 0 then
    local text = zone.have == 1 and L["You also hold 1 writ for NPCs here: deliver it on the same trip."]
      or L["You also hold %d writs for NPCs here: deliver them on the same trip."]:format(zone.have)
    GameTooltip:AddLine(text, 1, 0.82, 0, true)
  end
  GameTooltip:AddLine(L["Click: search the auction house for these writs and their items (the materials, for items cheaper to craft) when it's open, else make the Codex buy list. Way: waypoints to the NPCs (all of them with TomTom, else the first)."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- A crate of the By crate ranking (row.ranked, from C.CheapestCrates): what it costs and what it gives.
local function RankedCrateTooltip(row)
  local entry = row.ranked
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(entry.name)
  GameTooltip:AddLine(L["About %s Merchant's Favor"]:format(C.Number(entry.favor)), 1, 1, 1)
  GameTooltip:AddDoubleLine(L["The crate"], C.Money(entry.price), 1, 1, 1, 1, 1, 1)
  if entry.fill then
    GameTooltip:AddDoubleLine(L["Fill: %d %s"]:format(entry.fill.count, entry.fill.name), C.Money(entry.fillCost),
      1, 1, 1, 1, 1, 1)
  else
    GameTooltip:AddLine(L["Already filled: turn it in as it is."], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddDoubleLine(L["Total"], C.Money(entry.total), 1, 0.82, 0, 1, 0.82, 0)
  GameTooltip:AddDoubleLine(L["Per Merchant's Favor"], C.Money(entry.perFavor), 0.25, 1, 0.25, 0.25, 1, 0.25)
  GameTooltip:AddLine(L["Click at the auction house to search for the crate and what fills it, else put both on the buy list. Shift-click to link it."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function CheapRow(index, parent)
  local row = CreateFrame("Button", nil, parent or window)
  row:SetSize(INNER, 17)
  C.RowHighlight(row)
  row.way = UI.Button(row, 40, 16, L["Way"])
  row.way:SetPoint("RIGHT", 0, 0)
  row.way:SetScript("OnClick", function()
    if row.zone then
      C.SetZoneWaypoints(row.zone)
    elseif row.group then
      C.SetCustomerWaypoint(row.group.customer)
    end
  end)
  row.way:Hide()
  row.name = Text(row)
  row.name:SetPoint("LEFT", 2, 0)
  row.name:SetPoint("RIGHT", -110, 0)
  row.name:SetWordWrap(false)
  row.cost = Text(row)
  row.cost:SetPoint("RIGHT", -2, 0)
  row.cost:SetJustifyH("RIGHT")
  row:SetScript("OnEnter", function(self)
    if self.ranked then
      RankedCrateTooltip(self)
    elseif self.zone then
      ZoneTooltip(self)
    elseif self.group then
      CustomerTooltip(self)
    elseif self.writID then
      ItemTooltip(self, self.writID, L["Click at the auction house to search for it and its item (or the item's materials, when crafting it is cheaper). Shift-click to link it."])
    end
  end)
  row:SetScript("OnLeave", HideTooltip)
  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function(self, delta)
    if self.rankList then -- (the crate ranking scrolls; the writ lists show their top rows)
      crateOffset = math.max(crateOffset - delta, 0)
      C.RefreshWindow()
    end
  end)
  row:SetScript("OnClick", function(self)
    local linkID = self.writID or (self.ranked and self.ranked.itemID)
    if linkID and IsShiftKeyDown and IsShiftKeyDown() then
      LinkItem(linkID)
      return
    end
    if self.ranked then
      if C.AuctionHouseOpen() then
        C.SearchRankedCrate(self.ranked)
      else
        C.CreateRankedCrateBuyList(self.ranked)
      end
      return
    end
    local entries = (self.zone and self.zone.writs) or (self.group and self.group.writs)
    if C.AuctionHouseOpen() then
      local writIDs = {}
      for _, entry in ipairs(entries or {}) do
        writIDs[#writIDs + 1] = entry.writID
      end
      if self.writID then
        writIDs[1] = self.writID
      end
      C.SearchWrits(writIDs, C.HeldWrits())
    elseif self.zone then
      C.CreateZoneBuyList(self.zone)
    elseif self.group then
      C.CreateCustomerBuyList(self.group)
    end
  end)
  row.index = index
  return row
end

-- Lays a cheapest row out for a writ (cost at the right edge) or an NPC (cost left of the Way button).
local function CheapLayout(row, byNPC)
  row.way:SetShown(byNPC)
  row.cost:ClearAllPoints()
  row.cost:SetPoint("RIGHT", byNPC and -46 or -2, 0)
  row.name:SetPoint("RIGHT", byNPC and -200 or -110, 0)
end

-- Delivery rows: one per customer, with the writs you hold for them ------------------------------------

local function WritName(writID)
  local writ = C.Writ(writID)
  return writ and writ[3] or L["item %d"]:format(writID)
end
C.WritName = WritName

local function Way(row)
  local group = row.group
  if not group then
    return
  end
  if group.customer then
    C.SetCustomerWaypoint(group.customer)
  elseif group.writs[1].questID then
    C.SetWritWaypoint(group.writs[1].questID, WritName(group.writs[1].writID))
  end
end

-- A crate to fill (row.crate, from C.CratesToFill): its Favor and every way to fill it, cheapest first.
local function CrateTooltip(row)
  local crate = row.crate
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(crate.info.name)
  GameTooltip:AddLine(L["%d in your bags: about %s Merchant's Favor each"]:format(crate.count,
    C.Number(crate.favor)), 1, 1, 1, true)
  for _, option in ipairs(crate.options) do
    local have = option.owned > 0 and (" |cff999999" .. L["(you have %d)"]:format(option.owned) .. "|r") or ""
    GameTooltip:AddDoubleLine(C.Tone(L["Fill: %d %s"]:format(option.count, option.name) .. have),
      option.cost and C.Money(option.cost) or C.Tone("|cff999999" .. L["no price"] .. "|r"), 1, 1, 1, 1, 1, 1)
  end
  if #crate.options == 0 then
    GameTooltip:AddLine(L["What fills it isn't known."], 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddLine(L["Click: search the auction house for what fills it when it's open, else put the cheapest fill on the Codex buy list."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function DeliveryTooltip(row)
  if row.crate then
    CrateTooltip(row)
    return
  end
  local group = row.group
  if not group then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local customer = group.customer
  if customer then
    GameTooltip:AddLine(customer.name)
    GameTooltip:AddLine(("%s %.1f, %.1f%s"):format(C.MapName(customer.mapID), customer.x, customer.y,
      customer.learned and (" " .. L["(seen at your turn-in)"]) or customer.collected and (" " .. L["(players' data)"])
      or ""), 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine(WritName(group.writs[1].writID))
    GameTooltip:AddLine(L["Who takes this writ isn't known yet. Use it, and the game marks the spot on your map; Codex remembers the NPC once you turn it in."], 1, 1, 1, true)
  end
  local mine = {}
  for _, entry in ipairs(group.writs) do
    mine[entry.writID] = true
    local state
    if entry.ready then
      state = "|cff40ff40" .. L["ready"] .. "|r"
    elseif entry.questID then
      state = "|cffffd100" .. L["needs the item"] .. "|r"
    else
      state = "|cff999999" .. L["not opened, needs the item"] .. "|r"
    end
    GameTooltip:AddDoubleLine(WritName(entry.writID), state, 1, 1, 1, 1, 1, 1)
  end
  if customer then
    local others = {}
    for _, writID in ipairs(C.CustomerWrits(customer)) do
      if not mine[writID] then
        others[#others + 1] = WritName(writID)
      end
    end
    if #others > 0 then
      GameTooltip:AddLine(L["Also takes: %s"]:format(table.concat(others, ", ")), 0.6, 0.6, 0.6, true)
    end
  end
  GameTooltip:Show()
end

local function DeliveryRow(parent)
  local row = CreateFrame("Button", nil, parent or window)
  row:SetSize(INNER, 19)
  C.RowHighlight(row)
  row:SetScript("OnEnter", DeliveryTooltip)
  row:SetScript("OnLeave", HideTooltip)
  row.way = UI.Button(row, 44, 17, L["Way"])
  row.way:SetPoint("RIGHT", 0, 0)
  row.way:SetScript("OnClick", function()
    Way(row)
  end)
  row.way:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Waypoint"])
    GameTooltip:AddLine(L["Puts a waypoint on who takes these writs (TomTom when installed)."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  row.way:SetScript("OnLeave", HideTooltip)
  row.start = UI.Button(row, 48, 17, L["Start"])
  row.start:SetPoint("RIGHT", row.way, "LEFT", -4, 0)
  row.start:SetScript("OnClick", function()
    local writID = row.group and C.StartableWrit(row.group)
    if writID then
      local ok, why = C.StartWrit(writID)
      if not ok and why then
        ns.Say(why)
      end
    end
  end)
  row.start:SetScript("OnEnter", function(self)
    local writID = row.group and C.StartableWrit(row.group)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Start"])
    GameTooltip:AddLine(L["Opens the quest of %s: your bags hold what it asks for. Each click starts one writ."]:format(
      writID and WritName(writID) or L["the writ"]), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  row.start:SetScript("OnLeave", HideTooltip)
  row.start:Hide()
  row.name = Text(row)
  row.name:SetPoint("LEFT", 2, 0)
  row.name:SetPoint("RIGHT", row.way, "LEFT", -6, 0)
  row.name:SetWordWrap(false)
  -- a crate to fill: search for what fills it (or the buy list away from the auction house)
  row:SetScript("OnClick", function(self)
    if not self.crate then
      return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
      local link = C.ItemLink(self.crate.itemID)
      if link and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
      end
    elseif C.AuctionHouseOpen() then
      C.SearchCrate(self.crate)
    else
      C.CreateCrateBuyList(self.crate)
    end
  end)
  return row
end

local function TipButton(button, title, text)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(type(text) == "function" and text() or text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", HideTooltip)
end

local function BuyTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Buy list"])
  if C.CheapestMode() == "zone" then
    local zone = C.CheapestZones(1)[1]
    GameTooltip:AddLine(L["Makes the Codex shopping list \"%s\" with every priced writ taken in the cheapest zone, and the items they ask for. Click a zone's row for that zone's."]:format(C.SHOPPING_LIST), 1, 1, 1, true)
    if zone then
      GameTooltip:AddLine(L["%s: %d writs for %d NPCs, %s reputation, about %s"]:format(zone.name, #zone.writs,
        #zone.npcs, C.Number(zone.rep), C.Money(zone.total)), 0.25, 1, 0.25)
    end
  elseif C.CheapestMode() == "npc" then
    local group = C.CheapestCustomers(1)[1]
    GameTooltip:AddLine(L["Makes the Codex shopping list \"%s\" with every priced writ the cheapest NPC takes, and the items they ask for. Click an NPC's row for that NPC's."]:format(C.SHOPPING_LIST), 1, 1, 1, true)
    if group then
      GameTooltip:AddLine(L["%s: %d writs, %s reputation, about %s"]:format(group.customer.name, #group.writs,
        C.Number(group.rep), C.Money(group.total)), 0.25, 1, 0.25)
    end
  else
    local plan = C.PlanPurchases()
    GameTooltip:AddLine(L["Makes the Codex shopping list \"%s\" with the cheapest writs for the reputation you still need to your next standing, and the items they ask for."]:format(C.SHOPPING_LIST), 1, 1, 1, true)
    if #plan.picks > 0 then
      GameTooltip:AddLine(L["%d writs, about %s reputation, about %s"]:format(#plan.picks, C.Number(plan.rep),
        C.Money(plan.cost)), 0.25, 1, 0.25)
    end
  end
  GameTooltip:AddLine(L["At the auction house, click the list in the Codex panel to search it."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

-- The Crates tab's Buy list: the cheapest crate and what fills it.
local function RankBuyTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Buy list"])
  local entry = C.CheapestCrates(1)[1]
  GameTooltip:AddLine(L["Makes the Codex shopping list \"%s\" with the cheapest crate and what fills it. Click a crate's row for that crate."]:format(C.SHOPPING_LIST), 1, 1, 1, true)
  if entry then
    GameTooltip:AddLine(L["%s: about %s for %s Favor"]:format(entry.name, C.Money(entry.total),
      C.Number(entry.favor)), 0.25, 1, 0.25)
  end
  GameTooltip:AddLine(L["At the auction house, click the list in the Codex panel to search it."], 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Create()
  local theme = ns.Theme()
  window = C.NewWindow("CodexCommerceWindow", "Commerce Authority", WIDTH, HEIGHT, "position",
    { "CENTER", "CENTER", 0, 40 })
  window:SetScript("OnShow", function()
    C.RefreshWindow()
  end)

  -- the two tabs and their panes (each pane covers the window; its parts keep window coordinates)
  window.panes, window.tabs = {}, {}
  for index, key in ipairs({ "writs", "crates" }) do
    local pane = CreateFrame("Frame", nil, window)
    pane:SetAllPoints(window)
    pane:Hide()
    window.panes[key] = pane
    local tab = UI.Button(window, 96, 22, key == "writs" and L["Writs"] or L["Crates"])
    tab:SetPoint("TOPLEFT", PAD + (index - 1) * 100, -40)
    tab.mark = tab:CreateTexture(nil, "OVERLAY")
    tab.mark:SetPoint("BOTTOMLEFT", 3, 1)
    tab.mark:SetPoint("BOTTOMRIGHT", -3, 1)
    tab.mark:SetHeight(2)
    UI.SetColor(tab.mark, theme.accent)
    tab.key = key
    tab:SetScript("OnClick", function()
      C.SelectWindowTab(key)
    end)
    window.tabs[key] = tab
  end
  local writs, crates = window.panes.writs, window.panes.crates

  -- Writs ------------------------------------------------------------------------------------------------
  window.faction = UI.Text(writs, "body", 12, "bright")
  window.faction:SetPoint("TOPLEFT", PAD, -72)
  window.faction:SetPoint("RIGHT", -PAD, 0)
  window.faction:SetWordWrap(false)

  local bar = CreateFrame("Frame", nil, writs)
  bar:SetPoint("TOPLEFT", PAD, -92)
  bar:SetSize(INNER, 13)
  local barBack = bar:CreateTexture(nil, "BACKGROUND")
  barBack:SetAllPoints()
  UI.SetColor(barBack, theme.inset.fill)
  bar.fill = bar:CreateTexture(nil, "ARTWORK")
  bar.fill:SetPoint("TOPLEFT")
  bar.fill:SetPoint("BOTTOMLEFT")
  UI.SetColor(bar.fill, theme.good, 0.75)
  bar.bags = bar:CreateTexture(nil, "ARTWORK", nil, -1)
  bar.bags:SetPoint("TOPLEFT", bar.fill, "TOPRIGHT")
  bar.bags:SetPoint("BOTTOMLEFT", bar.fill, "BOTTOMRIGHT")
  UI.SetColor(bar.bags, theme.good, 0.3)
  ns.T.Outline(bar, 0, theme.inset.line, 1, "BORDER")
  bar.text = UI.Text(bar, "body", 10, "bright")
  bar.text:SetPoint("CENTER")
  window.bar = bar

  Heading(-114, L["In your bags"], nil, writs)
  window.bags = Text(writs)
  window.bags:SetPoint("TOPLEFT", PAD, -134)
  window.bags:SetPoint("RIGHT", -PAD, 0)
  window.bags:SetSpacing(2)

  Heading(-180, L["Deliveries"], 86, writs)
  local allNPCs = UI.Button(writs, 76, 20, L["All NPCs"])
  allNPCs:SetPoint("RIGHT", window, "TOPRIGHT", -PAD, -187) -- on the heading's middle
  allNPCs:SetScript("OnClick", function()
    C.ToggleNPCWindow()
  end)
  TipButton(allNPCs, L["Writ NPCs"], L["Every NPC who takes writs, with all its writs and which of them you have (%s)."]:format(
    "/codex commerce npcs"))
  window.deliveries = {}
  for index = 1, DELIVERY_ROWS do
    local row = DeliveryRow(writs)
    row:SetPoint("TOPLEFT", PAD, -200 - (index - 1) * 19)
    window.deliveries[index] = row
  end
  window.noDeliveries = Text(writs, 11, "muted")
  window.noDeliveries:SetPoint("TOPLEFT", PAD + 2, -202)
  window.noDeliveries:SetPoint("RIGHT", -PAD, 0)

  Heading(-284, L["Next standings"], nil, writs)
  window.goals = Text(writs)
  window.goals:SetPoint("TOPLEFT", PAD, -304)
  window.goals:SetPoint("RIGHT", -PAD, 0)
  window.goals:SetSpacing(2)

  window.cheapHeading = Heading(-360, L["Cheapest reputation"], nil, writs)
  local mine = UI.Check(writs, L["Only my professions"])
  mine:SetPoint("TOPLEFT", PAD - 2, -378)
  UI.Font(mine.label, "body", 11, "text")
  mine:SetScript("OnShow", function(self)
    self:SetChecked(C.DB().onlyMyProfessions)
  end)
  mine:SetScript("OnClick", function(self)
    C.DB().onlyMyProfessions = self:GetChecked() and true or false
    C.InvalidateCheapest()
    C.RefreshWindow()
    C.RefreshPage()
  end)
  mine:SetChecked(C.DB().onlyMyProfessions)
  C.FitCheck(mine)
  window.mine = mine
  local mode = UI.Button(writs, 84, 20, MODE_LABELS[C.CheapestMode()])
  mode:SetPoint("TOPLEFT", PAD + 160, -378)
  mode:SetScript("OnClick", function(self)
    C.SetCheapestMode(NEXT_MODE[C.CheapestMode()])
    self:SetText(MODE_LABELS[C.CheapestMode()])
    C.RefreshWindow()
    if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
      self:GetScript("OnEnter")(self) -- the tooltip follows the new ranking
    end
  end)
  mode:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(MODE_LABELS[C.CheapestMode()])
    GameTooltip:AddLine(MODE_HELP[C.CheapestMode()], 1, 1, 1, true)
    GameTooltip:AddLine(L["Click to switch: by writ, by NPC, by zone."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  mode:SetScript("OnLeave", HideTooltip)
  window.mode = mode
  local buy = UI.Button(writs, 96, 20, L["Buy list"])
  buy:SetPoint("TOPRIGHT", -PAD, -378)
  buy:SetScript("OnClick", function()
    if C.CheapestMode() == "zone" then
      C.CreateZoneBuyList(C.CheapestZones(1)[1])
    elseif C.CheapestMode() == "npc" then
      C.CreateCustomerBuyList(C.CheapestCustomers(1)[1])
    else
      C.CreateBuyList()
    end
  end)
  buy:SetScript("OnEnter", BuyTooltip)
  buy:SetScript("OnLeave", HideTooltip)
  window.buy = buy

  window.rows = {}
  for index = 1, CHEAP_ROWS do
    local row = CheapRow(index, writs)
    row:SetPoint("TOPLEFT", PAD, -404 - (index - 1) * 17)
    window.rows[index] = row
  end
  window.empty = Text(writs, 11, "muted")
  window.empty:SetPoint("TOPLEFT", PAD + 2, -406)
  window.empty:SetPoint("RIGHT", -PAD, 0)
  window.empty:SetWordWrap(true)

  -- Crates -----------------------------------------------------------------------------------------------
  window.favor = Text(crates, 12)
  window.favor:SetPoint("TOPLEFT", PAD, -72)
  window.favor:SetPoint("RIGHT", -PAD, 0)
  window.favor:SetWordWrap(false)

  Heading(-96, L["In your bags"], nil, crates)
  window.crateBags = Text(crates)
  window.crateBags:SetPoint("TOPLEFT", PAD, -116)
  window.crateBags:SetPoint("RIGHT", -PAD, 0)
  window.crateBags:SetSpacing(2)

  Heading(-154, L["Crates to fill"], nil, crates)
  window.fills = {}
  for index = 1, FILL_ROWS do
    local row = DeliveryRow(crates)
    row:SetPoint("TOPLEFT", PAD, -174 - (index - 1) * 19)
    window.fills[index] = row
  end
  window.noFills = Text(crates, 11, "muted")
  window.noFills:SetPoint("TOPLEFT", PAD + 2, -176)
  window.noFills:SetPoint("RIGHT", -PAD, 0)
  window.noFills:SetWordWrap(true)

  Heading(-276, L["Cheapest Merchant's Favor"], nil, crates)
  window.rankHint = Text(crates, 10, "muted")
  window.rankHint:SetPoint("TOPLEFT", PAD + 2, -298)
  window.rankHint:SetPoint("RIGHT", -PAD - 104, 0)
  window.rankHint:SetWordWrap(false)
  window.rankHint:SetText(L["Crate price + its cheapest fill, cheapest first"])
  local rankBuy = UI.Button(crates, 96, 20, L["Buy list"])
  rankBuy:SetPoint("TOPRIGHT", -PAD, -293)
  rankBuy:SetScript("OnClick", function()
    C.CreateRankedCrateBuyList(C.CheapestCrates(1)[1])
  end)
  rankBuy:SetScript("OnEnter", RankBuyTooltip)
  rankBuy:SetScript("OnLeave", HideTooltip)
  window.rankBuy = rankBuy
  window.rankRows = {}
  for index = 1, RANK_ROWS do
    local row = CheapRow(index, crates)
    row.rankList = true
    row:SetPoint("TOPLEFT", PAD, -320 - (index - 1) * 17)
    window.rankRows[index] = row
  end
  window.rankEmpty = Text(crates, 11, "muted")
  window.rankEmpty:SetPoint("TOPLEFT", PAD + 2, -322)
  window.rankEmpty:SetPoint("RIGHT", -PAD, 0)
  window.rankEmpty:SetWordWrap(true)

  window.session = Text(window, 10, "muted")
  window.session:SetPoint("BOTTOMLEFT", PAD, 14)
  window.session:SetPoint("RIGHT", -PAD, 0)
  window.session:SetWordWrap(false)
  C.SelectWindowTab(C.DB().windowTab, true)
end

-- Shows a tab of the window ("writs" or "crates"; anything else = writs), saved for next time.
function C.SelectWindowTab(key, quiet)
  key = key == "crates" and "crates" or "writs"
  local db = C.DB()
  if db then
    db.windowTab = key
  end
  if not window then
    return
  end
  for name, pane in pairs(window.panes) do
    pane:SetShown(name == key)
    window.tabs[name].mark:SetShown(name == key)
  end
  window.tab = key
  if not quiet then
    C.RefreshWindow()
  end
end

local function Bags(summary)
  local lines = {}
  if summary.writs > 0 then
    lines[#lines + 1] = L["%d writs: %s reputation"]:format(summary.writs, C.Number(summary.writRep))
  end
  if summary.sealedWrits > 0 then
    lines[#lines + 1] = L["%d sealed writs: %s reputation once done"]:format(summary.sealedWrits,
      C.Number(summary.sealedRep))
  end
  if #lines == 0 then
    return L["No writs in your bags."]
  end
  return table.concat(lines, "\n")
end
C.BagsText = Bags

-- The Crates tab's "In your bags": filled crates and crates to fill.
local function CrateBags(summary)
  local lines = {}
  if summary.crates > 0 then
    lines[#lines + 1] = L["%d filled crates: about %s Favor + %s"]:format(summary.crates,
      C.Number(C.ExpectedFavor(summary.crateFavor)), C.Money(summary.crateFavor * C.COPPER_PER_FAVOR))
  end
  if summary.toFill > 0 then
    lines[#lines + 1] = L["%d crates to fill: about %s Favor"]:format(summary.toFill,
      C.Number(C.ExpectedFavor(summary.fillFavor)))
  end
  if #lines == 0 then
    return L["No crates in your bags."]
  end
  return table.concat(lines, "\n")
end
C.CrateBagsText = CrateBags

local function Goals(faction, bagRep)
  local upcoming = C.NextStandings(faction)
  if #upcoming == 0 then
    return faction and L["Exalted. Nothing left to earn here but Merchant's Favor."] or
      L["Turn in your first crate at the trade hub to start."]
  end
  local lines = {}
  local fewest = C.TierRep(C.WRIT_TIERS[3])
  local most = C.TierRep(C.WRIT_TIERS[1])
  for index = 1, math.min(#upcoming, 3) do
    local goal = upcoming[index]
    local needed = math.max(goal.needed - bagRep, 0)
    local text = L["%s: %s more"]:format(C.StandingName(goal.standingID), C.Number(goal.needed))
    if bagRep > 0 then
      text = text .. " " .. L["(%s after your bags)"]:format(C.Number(needed))
    end
    if needed > 0 then
      text = text .. ", " .. L["%d-%d writs"]:format(math.ceil(needed / fewest), math.ceil(needed / most))
    end
    lines[#lines + 1] = text
  end
  return table.concat(lines, "\n")
end
C.GoalsText = Goals

-- "Kzixx, Duskwood: 2 writs, 1 ready" or "Radiant Circlet (Artisan): who takes it isn't known yet"
local function DeliveryText(group)
  local ready = group.ready > 0 and (" |cff40ff40" .. L["%d ready"]:format(group.ready) .. "|r") or ""
  if group.customer then
    local what = #group.writs == 1 and WritName(group.writs[1].writID) or Writs(#group.writs)
    return ("%s |cff999999%s|r: %s%s"):format(group.customer.name, C.MapName(group.customer.mapID), what,
      ready ~= "" and "," .. ready or "")
  end
  return ("%s |cff999999%s|r%s"):format(WritName(group.writs[1].writID), L["(not known who takes it)"], ready)
end

-- "Crate: Journeyman Ore x2: fill 20 Iron Ore, 20s" (or "ready to fill" when your bags hold enough)
local function CrateText(crate)
  local short = crate.info.name:match("^Waylaid Crate: (.+)$")
  local name = short and L["Crate: %s"]:format(short) or crate.info.name
  local times = crate.count > 1 and (" x%d"):format(crate.count) or ""
  if crate.ready then
    return ("%s%s |cff40ff40%s|r"):format(name, times, L["ready to fill"])
  end
  local option = crate.options[1]
  if not option then
    return ("%s%s |cff999999%s|r"):format(name, times, L["(fill not known)"])
  end
  return ("%s%s|cff999999: %s%s|r"):format(name, times, L["fill %d %s"]:format(option.count, option.name),
    option.cost and (", " .. C.ShortMoney(option.cost)) or "")
end

local function Deliveries(counts)
  local groups = C.Deliveries(counts)
  for index, row in ipairs(window.deliveries) do
    local group = groups[index]
    row.group, row.crate = group, nil
    if group then
      local text = DeliveryText(group)
      if index == DELIVERY_ROWS and #groups > DELIVERY_ROWS then
        text = text .. " |cff999999" .. L["+%d more"]:format(#groups - DELIVERY_ROWS) .. "|r"
      end
      SetText(row.name, text)
      row.way:SetShown(group.customer ~= nil or group.writs[1].questID ~= nil)
      local startable = C.StartableWrit(group) ~= nil and not (InCombatLockdown and InCombatLockdown())
      row.start:SetShown(startable)
      row.name:SetPoint("RIGHT", startable and row.start or row.way, "LEFT", -6, 0)
      row:Show()
    else
      row:Hide()
    end
  end
  if #groups == 0 then
    window.noDeliveries:SetText(L["No writs. The writs you hold show here, grouped by who takes them."])
  else
    window.noDeliveries:SetText("")
  end
end

-- The Crates tab: the Waylaid Crates in your bags that still need filling, the cheapest fill on each row.
local function Fills(counts)
  local crates = C.CratesToFill(counts)
  for index, row in ipairs(window.fills) do
    local crate = crates[index]
    row.group, row.crate = nil, crate
    row.way:Hide()
    row.start:Hide()
    if crate then
      local text = CrateText(crate)
      if index == FILL_ROWS and #crates > FILL_ROWS then
        text = text .. " |cff999999" .. L["+%d more"]:format(#crates - FILL_ROWS) .. "|r"
      end
      SetText(row.name, text)
      row.name:SetPoint("RIGHT", row, "RIGHT", -2, 0)
      row:Show()
    else
      row:Hide()
    end
  end
  if #crates == 0 then
    window.noFills:SetText(L["No crates to fill. The Waylaid Crates in your bags show here, with the cheapest way to fill each."])
  else
    window.noFills:SetText("")
  end
end

-- "Spek Riverglades: 4 writs" with "1g 90s / 100", for the By NPC ranking. Returns how many are shown.
local function CheapestByNPC(counts)
  local groups = C.CheapestCustomers(CHEAP_ROWS, counts)
  for index, row in ipairs(window.rows) do
    local group = groups[index]
    row.writID, row.zone = nil, nil
    CheapLayout(row, true)
    if group then
      row.group = group
      local what = #group.writs == 1 and C.WRITS[group.writs[1].writID][3] or Writs(#group.writs)
      SetText(row.name, ("%s |cff999999%s|r: %s"):format(group.customer.name, C.MapName(group.customer.mapID),
        what))
      SetText(row.cost, ("%s |cff999999· %s / 100|r"):format(C.ShortMoney(group.total),
        C.ShortMoney(group.per100)))
      row:Show()
    else
      row.group = nil
      row:Hide()
    end
  end
  return #groups
end

-- "Tanaris: 3 NPCs, 5 writs" with "1g 20s / 100", for the By zone ranking. Returns how many are shown.
local function CheapestByZone(counts)
  local zones = C.CheapestZones(CHEAP_ROWS, counts)
  for index, row in ipairs(window.rows) do
    local zone = zones[index]
    row.writID, row.group = nil, nil
    CheapLayout(row, true)
    if zone then
      row.zone = zone
      local npcs = #zone.npcs == 1 and L["1 NPC"] or L["%d NPCs"]:format(#zone.npcs)
      SetText(row.name, ("%s|cff999999:|r %s, %s"):format(zone.name, npcs, Writs(#zone.writs)))
      SetText(row.cost, ("%s |cff999999· %s / 100|r"):format(C.ShortMoney(zone.total), C.ShortMoney(zone.per100)))
      row:Show()
    else
      row.zone = nil
      row:Hide()
    end
  end
  return #zones
end

-- Why the cheapest list is empty (`mode`: the ranking shown).
function C.EmptyCheapestText(mode)
  if #C.PriceSourceNames() == 0 then
    return L["Switch on Codex's Auction House module and scan the auction house to see writ prices."]
  elseif mode == "crate" then -- (the Crates tab's ranking)
    return L["No priced crates yet. Scan the auction house, or search for \"%s\"."]:format("Waylaid Crate")
  elseif C.DB().onlyMyProfessions and next(C.PlayerProfessions()) == nil then
    return L["No crafting profession found on this character."]
  end
  return L["No priced writs yet. Scan the auction house, or search for \"%s\"."]:format("Craftsman's Writ")
end

-- "Waylaid Crate: Journeyman Ore (10)" with "45s · 4s 50c / Favor", the Crates tab's ranking: crate price plus the
-- cheapest fill, scrolled by crateOffset (mouse wheel).
local function CrateRanking()
  local crates = C.CheapestCrates()
  crateOffset = math.min(crateOffset, math.max(#crates - RANK_ROWS, 0))
  for index, row in ipairs(window.rankRows) do
    local entry = crates[crateOffset + index]
    CheapLayout(row, false)
    row.name:SetPoint("RIGHT", -150, 0)
    row.ranked = entry
    if entry then
      SetText(row.name, ("%s |cff999999(%s)|r"):format(entry.name, C.Number(entry.favor)))
      SetText(row.cost, ("%s |cff999999· %s|r"):format(C.ShortMoney(entry.total),
        L["%s / Favor"]:format(C.ShortMoney(entry.perFavor))))
      row:Show()
    else
      row:Hide()
    end
  end
  window.rankEmpty:SetText(#crates > 0 and "" or C.EmptyCheapestText("crate"))
  window.rankHint:SetText(#crates > RANK_ROWS
    and L["Crate price + its cheapest fill, cheapest first (%d-%d of %d, scroll for more)"]:format(crateOffset + 1,
      math.min(crateOffset + RANK_ROWS, #crates), #crates)
    or L["Crate price + its cheapest fill, cheapest first"])
end

local function Cheapest(counts)
  local shown
  local mode = C.CheapestMode()
  if mode == "zone" then
    shown = CheapestByZone(counts)
  elseif mode == "npc" then
    shown = CheapestByNPC(counts)
  end
  local cheapest = shown and {} or C.CheapestWrits(CHEAP_ROWS)
  for index, row in ipairs(window.rows) do
    local entry = cheapest[index]
    if shown then
      -- laid out by CheapestByNPC / CheapestByZone
    elseif entry then
      local writ = C.WRITS[entry.writID]
      local tier = C.WritTier(entry.writID)
      CheapLayout(row, false)
      row.group, row.zone = nil, nil
      row.writID = entry.writID
      SetText(row.name, ("%s |cff999999(%s, %d)|r"):format(writ[3], C.TierName(tier.name), entry.rep))
      SetText(row.cost, ("%s |cff999999/ 100|r"):format(C.Money(entry.per100)))
      row:Show()
    else
      row.writID, row.group, row.zone = nil, nil, nil
      row:Hide()
    end
  end
  window.empty:SetText((shown or #cheapest) > 0 and "" or C.EmptyCheapestText(mode))
end

-- "Azeroth Commerce Authority: Friendly" and the bar's numbers; also for the module's status line.
function C.FactionText(faction)
  if faction then
    return ("%s: |cffffffff%s|r"):format(faction.name, C.StandingName(faction.standingID))
  end
  return C.MyFactionName() .. ": |cff999999" .. L["no reputation yet"] .. "|r"
end

function C.RefreshWindow()
  if not (window and window:IsShown()) then
    return
  end
  local faction = C.Faction()
  local counts = C.BagCounts()
  local summary = C.BagSummary(counts)
  local bagRep = summary.writRep
  local bar = window.bar
  SetText(window.faction, C.FactionText(faction))
  if faction then
    local span = math.max((faction.max or 1) - (faction.min or 0), 1)
    local done = math.min(math.max((faction.value or 0) - (faction.min or 0), 0), span)
    local width = bar:GetWidth()
    bar.fill:SetWidth(math.max(done / span * width, 0.01))
    bar.bags:SetWidth(math.max(math.min(bagRep, span - done) / span * width, 0.01))
    bar.text:SetText(("%s / %s"):format(C.Number(done), C.Number(span)))
  else
    bar.fill:SetWidth(0.01)
    bar.bags:SetWidth(0.01)
    bar.text:SetText(L["Trade hub: %s"]:format(C.HubText()))
  end

  local favor = C.Favor()
  if favor then
    local text = L["Merchant's Favor: %s"]:format("|cffffffff" .. C.Number(favor) .. "|r")
    local coming = C.ExpectedFavor(summary.crateFavor)
    if coming > 0 then
      text = text .. "  |cff999999" .. L["(about %s after your crates)"]:format(C.Number(favor + coming)) .. "|r"
    end
    SetText(window.favor, text)
  else
    window.favor:SetText(L["Merchant's Favor: not found"])
  end
  window.bags:SetText(Bags(summary))
  Deliveries(counts)
  window.goals:SetText(Goals(faction, bagRep))
  window.mine:SetChecked(C.DB().onlyMyProfessions)
  window.mode:SetText(MODE_LABELS[C.CheapestMode()])
  Cheapest(counts)
  window.crateBags:SetText(CrateBags(summary))
  Fills(counts)
  CrateRanking()

  local session = C.session
  window.session:SetText(L["This session: +%s Favor, +%s reputation, %d crates, %d writs"]:format(
    C.Number(session.favor), C.Number(session.rep), session.crates, session.writs)
    .. (session.bonuses > 0 and (", " .. L["%d bonus"]:format(session.bonuses)) or ""))
end

local function RefreshAll()
  C.RefreshWindow()
  if C.RefreshNPCWindow then
    C.RefreshNPCWindow()
  end
end

-- Refreshes the windows (this one and Writ NPCs) at most twice a second, while one is shown.
local refreshPending = false
function C.RequestRefresh()
  if not ((window and window:IsShown()) or (C.NPCWindowShown and C.NPCWindowShown())) then
    return
  end
  if refreshPending then
    return
  end
  refreshPending = true
  C_Timer.After(0.5, function()
    refreshPending = false
    RefreshAll()
  end)
end

function C.ToggleWindow()
  if not C.running then
    ns.Say(L["the Commerce module is off; switch it on in the Codex window."])
    return
  end
  if not window then
    Create()
  end
  window:SetShown(not window:IsShown())
end

function C.Window()
  return window
end

-- The window, made the first time it is needed (Dock.lua opens it beside the auction house).
function C.EnsureWindow()
  if not window then
    Create()
  end
  return window
end

-- Back to the player's own place (after it was docked beside the auction house).
function C.RestoreWindowPosition()
  if not window then
    return
  end
  window:ClearAllPoints()
  local position = C.DB().position
  if type(position) == "table" and position[1] then
    window:SetPoint(position[1], UIParent, position[2], position[3], position[4])
  else
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end
