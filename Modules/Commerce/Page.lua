local addonName, ns = ...

-- Commerce module, part 11: the module's page in the Codex window: options, where you stand, the window
-- buttons and how it works. Ported from Tylesser - Commerce Authority's options page.

local C = ns.commerce
local L = ns.L
local UI = ns.UI

local view = {}

local OPTIONS = {
  { "writTooltips", L["Writ tooltips"], L["The reputation a writ gives, what it asks for, its price and the cost per 100 reputation."] },
  { "crateTooltips", L["Crate tooltips"], L["The Merchant's Favor and silver a crate gives, and the cheapest way to fill it."] },
  { "vendorMarks", L["Marks at the Commerce Authority vendors"],
    L["\"%s\" or how much Favor you still need, and how many crates that is."]:format(L["Can buy"]) },
}

-- "How it works": the factions by the names the game gives them (the client's language), so built with the page.
local function HowText()
  return table.concat({
    L["Craftsman's Writs and Waylaid Crates for the %s (Alliance, Three Corners in Redridge) and %s (Horde, west of the Crossroads)."]
      :format(C.FactionNameOf("Alliance"), C.FactionNameOf("Horde")),
    L["Writ tooltips show the reputation, what the writ asks for, its auction price and the cost per 100 reputation, and who takes it. Crate tooltips show the Merchant's Favor and the cheapest way to fill them."],
    L["Prices come from Codex's own auction scans (Auction House module), craft costs from the Professions module. The window ranks the cheapest reputation by writ, NPC or zone; Buy list writes the Codex shopping list \"%s\", ready to search in the Codex auction panel."]
      :format(C.SHOPPING_LIST),
    L["Codex learns what your turn-ins really give, and who took each writ, so the guides' numbers are replaced as you play."],
  }, "\n\n")
end

function C.StatusText()
  if not C.DB() then
    return ""
  end
  local faction = C.Faction()
  local text = C.Tone(C.FactionText(faction))
  local favor = C.Favor()
  if favor then
    text = text .. ". " .. L["%s Merchant's Favor."]:format(C.Number(favor))
  end
  return text
end

local function LearnedText()
  local db = C.DB()
  local crates, writs, customers = 0, 0, 0
  for _ in pairs(db.learned.crates or {}) do
    crates = crates + 1
  end
  for _ in pairs(db.learned.writs or {}) do
    writs = writs + 1
  end
  for _ in pairs(db.learned.customers or {}) do
    customers = customers + 1
  end
  local names = C.PriceSourceNames()
  local talents = {}
  for _, talent in ipairs({ { C.TalentName(C.PERFORMANCE_BONUS_SPELL, "Performance Bonus"), C.HasPerformanceBonus() },
    { C.TalentName(C.DIPLOMAT_SPELL, "Diplomat"), C.HasDiplomat() } }) do
    talents[#talents + 1] = talent[1] .. " " .. (talent[2] and L["(yours: counted in)"] or L["(not taken)"])
  end
  return L["Legacy talents: %s."]:format(table.concat(talents, ", ")) .. "\n"
    .. L["Learned from your turn-ins: %d crate kinds, %d writs, %d writ NPCs."]:format(crates, writs, customers) .. "\n"
    .. L["Prices: %s."]:format(#names > 0 and table.concat(names, ", ")
      or L["the Auction House module is off, so writs have no prices"])
end

function C.RefreshPage()
  if not view.page then
    return
  end
  local db = C.DB()
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key])
  end
  view.status:SetText(C.StatusText())
  view.learned:SetText(LearnedText())
end

function C.SetOption(key, on)
  C.DB()[key] = on and true or false
  if key == "vendorMarks" and C.running then
    C.UpdateVendorMarks()
  end
  C.RefreshWindow()
  C.RefreshPage()
end

-- Clears the learned amounts; who takes each writ is a fact seen in the game, not an estimate: kept.
function C.ForgetLearned()
  local db = C.DB()
  local customers = db.learned.customers or {}
  db.learned = { crates = {}, writs = {}, customers = customers }
  C.InvalidateCheapest()
  ns.Say(L["learned turn-in amounts cleared; the guides' numbers are used again."])
  C.RefreshWindow()
  C.RefreshPage()
end

local function Tip(button, title, text)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

function C.BuildPage(page)
  C.DB()
  view.page = page
  local heading = UI.Heading(page, "Commerce Authority", 20)
  heading:SetPoint("TOPLEFT")
  view.status = UI.Text(page, "body", 12, "muted")
  view.status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  view.status:SetPoint("RIGHT", 0, 0)

  local open = UI.Button(page, 150, 24, L["Open the window"])
  open:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -12)
  open:SetScript("OnClick", C.ToggleWindow)
  Tip(open, "Commerce Authority", L["Reputation, Merchant's Favor, your writs by who takes them, the next standings and the cheapest reputation (%s)."]
    :format("/codex commerce"))
  local npcs = UI.Button(page, 110, 24, L["Writ NPCs"])
  npcs:SetPoint("LEFT", open, "RIGHT", 8, 0)
  npcs:SetScript("OnClick", C.ToggleNPCWindow)
  Tip(npcs, L["Writ NPCs"], L["Every NPC who takes writs, with all its writs and which of them you have (%s)."]:format(
    "/codex commerce npcs"))
  local buy = UI.Button(page, 100, 24, L["Buy list"])
  buy:SetPoint("LEFT", npcs, "RIGHT", 8, 0)
  buy:SetScript("OnClick", C.CreateBuyList)
  Tip(buy, L["Buy list"], L["The cheapest writs to your next standing, and the items they ask for, in the Codex shopping list \"%s\" (%s)."]
    :format(C.SHOPPING_LIST, "/codex commerce buy"))

  view.checks = {}
  local anchor
  for _, option in ipairs(OPTIONS) do
    local check = UI.Check(page, option[2])
    check.key = option[1]
    if anchor then
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -14)
    end
    local note = UI.Text(page, "body", 11, "muted")
    note:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
    note:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: a long note wraps
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(option[3])
    check:SetScript("OnClick", function(self)
      C.SetOption(self.key, self:GetChecked())
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  view.learned = UI.Text(page, "body", 12, "text")
  view.learned:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  view.learned:SetPoint("RIGHT", -170, 0)
  view.learned:SetJustifyH("LEFT")
  view.learned:SetWordWrap(true)
  local forget = UI.Button(page, 160, 24, L["Forget what was learned"])
  forget:SetPoint("TOPLEFT", view.learned, "TOPRIGHT", 10, 2)
  forget:SetScript("OnClick", C.ForgetLearned)
  Tip(forget, L["Forget what was learned"], L["Codex remembers the Merchant's Favor and reputation each crate and writ gave you. Clear them to go back to the guides' numbers. Who takes each writ is kept."])

  local how = UI.Text(page, "head", 12, "accent")
  how:SetPoint("TOPLEFT", view.learned, "BOTTOMLEFT", 0, -22)
  how:SetText(L["How it works"])
  local text = UI.Text(page, "body", 12, "text")
  text:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  text:SetText(HowText())

  C.RefreshPage()
end
