local addonName, ns = ...

-- Commerce module, part 9: the Commerce Authority window (/codex commerce, /aca): reputation and Merchant's
-- Favor, what your bags are worth, the writs you hold grouped by who takes them (with waypoints), how far each
-- standing is, the cheapest reputation on the auction house (with the Codex buy list) and this session's
-- turn-ins. Ported from Tylesser - Commerce Authority's window, drawn with Codex's widgets in the active theme.

local C = ns.commerce
local UI = ns.UI

local WIDTH = 400
local HEIGHT = 580
local PAD = 16
local INNER = WIDTH - PAD * 2
local TITLE_H = 34
local CHEAP_ROWS = 8
local DELIVERY_ROWS = 4
-- the cheapest list's rankings, switched by one button
local MODE_LABELS = { writ = "By writ", npc = "By NPC", zone = "By zone" }
local NEXT_MODE = { writ = "npc", npc = "zone", zone = "writ" }
local MODE_HELP = {
  writ = "Writs sorted by what each costs per 100 reputation (the writ and the item it asks for).",
  npc = "The NPCs who take writs, by what buying all their priced writs costs per 100 reputation: one shopping "
    .. "list, one trip.",
  zone = "Zones, by what buying all the priced writs their NPCs take costs per 100 reputation: one shopping list, "
    .. "one trip around the zone.",
}
local window

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
local function Heading(y, text, right)
  local heading = UI.Text(window, "head", 13, "accent")
  heading:SetPoint("TOPLEFT", PAD, y)
  heading:SetText(text)
  local line = UI.Divider(window)
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
    GameTooltip:AddDoubleLine(("%s |cff999999(%s, %d)|r"):format(writ[3], tier.name, entry.rep),
      C.Money(entry.total), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine(("All %d: %s for %s reputation, %s per 100"):format(#group.writs, C.Money(group.total),
    C.Number(group.rep), C.Money(group.per100)), 0.25, 1, 0.25)
  if group.have > 0 then
    GameTooltip:AddLine(("You also hold %d writ%s for %s: deliver %s on the same trip."):format(group.have,
      group.have == 1 and "" or "s", customer.name, group.have == 1 and "it" or "them"), 1, 0.82, 0, true)
  end
  local missing = #C.CustomerWrits(customer) - #group.writs - group.have
  if missing > 0 then
    GameTooltip:AddLine(("%d more writ%s for %s with no auction price yet."):format(missing,
      missing == 1 and "" or "s", customer.name), 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddLine("Click: search the auction house for these writs when it's open, else make the Codex "
    .. "buy list. Way: waypoint to " .. customer.name .. ".", 0.6, 0.6, 0.6, true)
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
      GameTooltip:AddDoubleLine(("  %s |cff999999(%s, %d)|r"):format(writ[3], tier.name, entry.rep),
        C.Money(entry.total), 1, 1, 1, 1, 1, 1)
    end
  end
  GameTooltip:AddLine(("All %d writs: %s for %s reputation, %s per 100"):format(#zone.writs, C.Money(zone.total),
    C.Number(zone.rep), C.Money(zone.per100)), 0.25, 1, 0.25)
  if zone.have > 0 then
    GameTooltip:AddLine(("You also hold %d writ%s for NPCs here: deliver %s on the same trip."):format(zone.have,
      zone.have == 1 and "" or "s", zone.have == 1 and "it" or "them"), 1, 0.82, 0, true)
  end
  GameTooltip:AddLine("Click: search the auction house for these writs when it's open, else make the Codex "
    .. "buy list. Way: waypoints to the NPCs (all of them with TomTom, else the first).", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function CheapRow(index)
  local row = CreateFrame("Button", nil, window)
  row:SetSize(INNER, 17)
  C.RowHighlight(row)
  row.way = UI.Button(row, 40, 16, "Way")
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
    if self.zone then
      ZoneTooltip(self)
    elseif self.group then
      CustomerTooltip(self)
    elseif self.writID then
      ItemTooltip(self, self.writID, "Click at the auction house to search for it. Shift-click to link it.")
    end
  end)
  row:SetScript("OnLeave", HideTooltip)
  row:SetScript("OnClick", function(self)
    if self.writID and IsShiftKeyDown and IsShiftKeyDown() then
      LinkItem(self.writID)
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
  return writ and writ[3] or ("item " .. writID)
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

local function DeliveryTooltip(row)
  local group = row.group
  if not group then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local customer = group.customer
  if customer then
    GameTooltip:AddLine(customer.name)
    GameTooltip:AddLine(("%s %.1f, %.1f%s"):format(C.MapName(customer.mapID), customer.x, customer.y,
      customer.learned and " (seen at your turn-in)" or ""), 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine(WritName(group.writs[1].writID))
    GameTooltip:AddLine("Who takes this writ isn't known yet. Use it, and the game marks the spot on your map; "
      .. "Codex remembers the NPC once you turn it in.", 1, 1, 1, true)
  end
  local mine = {}
  for _, entry in ipairs(group.writs) do
    mine[entry.writID] = true
    local state
    if entry.ready then
      state = "|cff40ff40ready|r"
    elseif entry.questID then
      state = "|cffffd100needs the item|r"
    else
      state = "|cff999999not opened, needs the item|r"
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
      GameTooltip:AddLine("Also takes: " .. table.concat(others, ", "), 0.6, 0.6, 0.6, true)
    end
  end
  GameTooltip:Show()
end

local function DeliveryRow()
  local row = CreateFrame("Button", nil, window)
  row:SetSize(INNER, 19)
  C.RowHighlight(row)
  row:SetScript("OnEnter", DeliveryTooltip)
  row:SetScript("OnLeave", HideTooltip)
  row.way = UI.Button(row, 44, 17, "Way")
  row.way:SetPoint("RIGHT", 0, 0)
  row.way:SetScript("OnClick", function()
    Way(row)
  end)
  row.way:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Waypoint")
    GameTooltip:AddLine("Puts a waypoint on who takes these writs (TomTom when installed).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  row.way:SetScript("OnLeave", HideTooltip)
  row.name = Text(row)
  row.name:SetPoint("LEFT", 2, 0)
  row.name:SetPoint("RIGHT", row.way, "LEFT", -6, 0)
  row.name:SetWordWrap(false)
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
  GameTooltip:AddLine("Buy list")
  local list = "Makes the Codex shopping list \"" .. C.SHOPPING_LIST .. "\" with "
  if C.CheapestMode() == "zone" then
    local zone = C.CheapestZones(1)[1]
    GameTooltip:AddLine(list .. "every priced writ taken in the cheapest zone, and the items they ask for. Click a "
      .. "zone's row for that zone's.", 1, 1, 1, true)
    if zone then
      GameTooltip:AddLine(("%s: %d writs for %d NPCs, %s reputation, about %s"):format(zone.name, #zone.writs,
        #zone.npcs, C.Number(zone.rep), C.Money(zone.total)), 0.25, 1, 0.25)
    end
  elseif C.CheapestMode() == "npc" then
    local group = C.CheapestCustomers(1)[1]
    GameTooltip:AddLine(list .. "every priced writ the cheapest NPC takes, and the items they ask for. Click an "
      .. "NPC's row for that NPC's.", 1, 1, 1, true)
    if group then
      GameTooltip:AddLine(("%s: %d writs, %s reputation, about %s"):format(group.customer.name, #group.writs,
        C.Number(group.rep), C.Money(group.total)), 0.25, 1, 0.25)
    end
  else
    local plan = C.PlanPurchases()
    GameTooltip:AddLine(list .. "the cheapest writs for the reputation you still need to your next standing, and "
      .. "the items they ask for.", 1, 1, 1, true)
    if #plan.picks > 0 then
      GameTooltip:AddLine(("%d writs, about %s reputation, about %s"):format(#plan.picks, C.Number(plan.rep),
        C.Money(plan.cost)), 0.25, 1, 0.25)
    end
  end
  GameTooltip:AddLine("At the auction house, click the list in the Codex panel to search it.", 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Create()
  local theme = ns.Theme()
  window = C.NewWindow("CodexCommerceWindow", "Commerce Authority", WIDTH, HEIGHT, "position",
    { "CENTER", "CENTER", 0, 40 })
  window:SetScript("OnShow", function()
    C.RefreshWindow()
  end)

  window.faction = UI.Text(window, "body", 12, "bright")
  window.faction:SetPoint("TOPLEFT", PAD, -46)
  window.faction:SetPoint("RIGHT", -PAD, 0)
  window.faction:SetWordWrap(false)

  local bar = CreateFrame("Frame", nil, window)
  bar:SetPoint("TOPLEFT", PAD, -66)
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

  window.favor = Text(window, 12)
  window.favor:SetPoint("TOPLEFT", PAD, -88)
  window.favor:SetPoint("RIGHT", -PAD, 0)
  window.favor:SetWordWrap(false)

  Heading(-110, "In your bags")
  window.bags = Text(window)
  window.bags:SetPoint("TOPLEFT", PAD, -130)
  window.bags:SetPoint("RIGHT", -PAD, 0)
  window.bags:SetSpacing(2)

  Heading(-192, "Deliveries", 86)
  local allNPCs = UI.Button(window, 76, 20, "All NPCs")
  allNPCs:SetPoint("RIGHT", window, "TOPRIGHT", -PAD, -199) -- on the heading's middle
  allNPCs:SetScript("OnClick", function()
    C.ToggleNPCWindow()
  end)
  TipButton(allNPCs, "Writ NPCs", "Every NPC who takes writs, with all its writs and which of them you have "
    .. "(/codex commerce npcs).")
  window.deliveries = {}
  for index = 1, DELIVERY_ROWS do
    local row = DeliveryRow()
    row:SetPoint("TOPLEFT", PAD, -212 - (index - 1) * 19)
    window.deliveries[index] = row
  end
  window.noDeliveries = Text(window, 11, "muted")
  window.noDeliveries:SetPoint("TOPLEFT", PAD + 2, -214)
  window.noDeliveries:SetPoint("RIGHT", -PAD, 0)

  Heading(-294, "Next standings")
  window.goals = Text(window)
  window.goals:SetPoint("TOPLEFT", PAD, -314)
  window.goals:SetPoint("RIGHT", -PAD, 0)
  window.goals:SetSpacing(2)

  Heading(-368, "Cheapest reputation")
  local mine = UI.Check(window, "Only my professions")
  mine:SetPoint("TOPLEFT", PAD - 2, -386)
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
  local mode = UI.Button(window, 84, 20, MODE_LABELS[C.CheapestMode()])
  mode:SetPoint("TOPLEFT", PAD + 160, -386)
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
    GameTooltip:AddLine("Click to switch: by writ, by NPC, by zone.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  mode:SetScript("OnLeave", HideTooltip)
  window.mode = mode
  local buy = UI.Button(window, 96, 20, "Buy list")
  buy:SetPoint("TOPRIGHT", -PAD, -386)
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
    local row = CheapRow(index)
    row:SetPoint("TOPLEFT", PAD, -412 - (index - 1) * 17)
    window.rows[index] = row
  end
  window.empty = Text(window, 11, "muted")
  window.empty:SetPoint("TOPLEFT", PAD + 2, -414)
  window.empty:SetPoint("RIGHT", -PAD, 0)
  window.empty:SetWordWrap(true)

  window.session = Text(window, 10, "muted")
  window.session:SetPoint("BOTTOMLEFT", PAD, 14)
  window.session:SetPoint("RIGHT", -PAD, 0)
  window.session:SetWordWrap(false)
end

local function Bags(summary)
  local lines = {}
  if summary.writs > 0 then
    lines[#lines + 1] = ("%d writs: %s reputation"):format(summary.writs, C.Number(summary.writRep))
  end
  if summary.sealedWrits > 0 then
    lines[#lines + 1] = ("%d sealed writs: %s reputation once done"):format(summary.sealedWrits,
      C.Number(summary.sealedRep))
  end
  if summary.crates > 0 then
    lines[#lines + 1] = ("%d filled crates: about %s Favor + %s"):format(summary.crates,
      C.Number(C.ExpectedFavor(summary.crateFavor)), C.Money(summary.crateFavor * C.COPPER_PER_FAVOR))
  end
  if summary.toFill > 0 then
    lines[#lines + 1] = ("%d crates to fill: about %s Favor"):format(summary.toFill,
      C.Number(C.ExpectedFavor(summary.fillFavor)))
  end
  if #lines == 0 then
    return "No writs or crates in your bags."
  end
  return table.concat(lines, "\n")
end
C.BagsText = Bags

local function Goals(faction, bagRep)
  local upcoming = C.NextStandings(faction)
  if #upcoming == 0 then
    return faction and "Exalted. Nothing left to earn here but Merchant's Favor." or
      "Turn in your first crate at the trade hub to start."
  end
  local lines = {}
  local fewest = C.TierRep(C.WRIT_TIERS[3])
  local most = C.TierRep(C.WRIT_TIERS[1])
  for index = 1, math.min(#upcoming, 3) do
    local goal = upcoming[index]
    local needed = math.max(goal.needed - bagRep, 0)
    local text = ("%s: %s more"):format(C.StandingName(goal.standingID), C.Number(goal.needed))
    if bagRep > 0 then
      text = text .. (" (%s after your bags)"):format(C.Number(needed))
    end
    if needed > 0 then
      text = text .. (", %d-%d writs"):format(math.ceil(needed / fewest), math.ceil(needed / most))
    end
    lines[#lines + 1] = text
  end
  return table.concat(lines, "\n")
end
C.GoalsText = Goals

-- "Kzixx, Duskwood: 2 writs, 1 ready" or "Radiant Circlet (Artisan): who takes it isn't known yet"
local function DeliveryText(group)
  local ready = group.ready > 0 and (" |cff40ff40%d ready|r"):format(group.ready) or ""
  if group.customer then
    local what = #group.writs == 1 and WritName(group.writs[1].writID) or (#group.writs .. " writs")
    return ("%s |cff999999%s|r: %s%s"):format(group.customer.name, C.MapName(group.customer.mapID), what,
      ready ~= "" and "," .. ready or "")
  end
  return ("%s |cff999999(not known who takes it)|r%s"):format(WritName(group.writs[1].writID), ready)
end

local function Deliveries(counts)
  local groups = C.Deliveries(counts)
  for index, row in ipairs(window.deliveries) do
    local group = groups[index]
    if group then
      row.group = group
      local text = DeliveryText(group)
      if index == DELIVERY_ROWS and #groups > DELIVERY_ROWS then
        text = text .. (" |cff999999+%d more|r"):format(#groups - DELIVERY_ROWS)
      end
      SetText(row.name, text)
      row.way:SetShown(group.customer ~= nil or group.writs[1].questID ~= nil)
      row:Show()
    else
      row.group = nil
      row:Hide()
    end
  end
  if #groups == 0 then
    window.noDeliveries:SetText("No writs. The writs you hold show here, grouped by who takes them.")
  else
    window.noDeliveries:SetText("")
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
      local what = #group.writs == 1 and C.WRITS[group.writs[1].writID][3] or (#group.writs .. " writs")
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
      SetText(row.name, ("%s|cff999999:|r %d NPC%s, %d writ%s"):format(zone.name, #zone.npcs,
        #zone.npcs == 1 and "" or "s", #zone.writs, #zone.writs == 1 and "" or "s"))
      SetText(row.cost, ("%s |cff999999· %s / 100|r"):format(C.ShortMoney(zone.total), C.ShortMoney(zone.per100)))
      row:Show()
    else
      row.zone = nil
      row:Hide()
    end
  end
  return #zones
end

-- Why the cheapest list is empty.
function C.EmptyCheapestText()
  if #C.PriceSourceNames() == 0 then
    return "Switch on Codex's Auction House module and scan the auction house to see writ prices."
  elseif C.DB().onlyMyProfessions and next(C.PlayerProfessions()) == nil then
    return "No crafting profession found on this character."
  end
  return "No priced writs yet. Scan the auction house, or search for \"Craftsman's Writ\"."
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
      SetText(row.name, ("%s |cff999999(%s, %d)|r"):format(writ[3], tier.name, entry.rep))
      SetText(row.cost, ("%s |cff999999/ 100|r"):format(C.Money(entry.per100)))
      row:Show()
    else
      row.writID, row.group, row.zone = nil, nil, nil
      row:Hide()
    end
  end
  window.empty:SetText((shown or #cheapest) > 0 and "" or C.EmptyCheapestText())
end

-- "Azeroth Commerce Authority: Friendly" and the bar's numbers; also for the module's status line.
function C.FactionText(faction)
  if faction then
    return ("%s: |cffffffff%s|r"):format(faction.name, C.StandingName(faction.standingID))
  end
  return C.MyFactionName() .. ": |cff999999no reputation yet|r"
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
    bar.text:SetText("Trade hub: " .. (C.HUBS[C.Side()] or C.HUBS.Alliance))
  end

  local favor = C.Favor()
  if favor then
    local text = "Merchant's Favor: |cffffffff" .. C.Number(favor) .. "|r"
    local coming = C.ExpectedFavor(summary.crateFavor)
    if coming > 0 then
      text = text .. ("  |cff999999(about %s after your crates)|r"):format(C.Number(favor + coming))
    end
    SetText(window.favor, text)
  else
    window.favor:SetText("Merchant's Favor: not found")
  end
  window.bags:SetText(Bags(summary))
  Deliveries(counts)
  window.goals:SetText(Goals(faction, bagRep))
  window.mine:SetChecked(C.DB().onlyMyProfessions)
  window.mode:SetText(MODE_LABELS[C.CheapestMode()])
  Cheapest(counts)

  local session = C.session
  window.session:SetText(("This session: +%s Favor, +%s reputation, %d crates, %d writs%s"):format(
    C.Number(session.favor), C.Number(session.rep), session.crates, session.writs,
    session.bonuses > 0 and (", " .. session.bonuses .. " bonus") or ""))
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
    ns.Say("the Commerce module is off; switch it on in the Codex window.")
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
