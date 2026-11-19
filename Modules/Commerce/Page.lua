local addonName, ns = ...

-- Commerce module, part 11: the module's page in the Codex window: options, where you stand, the window
-- buttons and how it works. Ported from Tylesser - Commerce Authority's options page.

local C = ns.commerce
local UI = ns.UI

local view = {}

local OPTIONS = {
  { "writTooltips", "Writ tooltips", "The reputation a writ gives, what it asks for, its price and the cost per 100 reputation." },
  { "crateTooltips", "Crate tooltips", "The Merchant's Favor and silver a crate gives, and the cheapest way to fill it." },
  { "vendorMarks", "Marks at the Commerce Authority vendors", "\"Can buy\" or how much Favor you still need, and how many crates that is." },
}

local HOW = "Craftsman's Writs and Waylaid Crates for the Azeroth Commerce Authority (Alliance, Three Corners in "
  .. "Redridge) and Durotar Supply and Logistics (Horde, west of the Crossroads).\n\n"
  .. "Writ tooltips show the reputation, what the writ asks for, its auction price and the cost per 100 "
  .. "reputation, and who takes it. Crate tooltips show the Merchant's Favor and the cheapest way to fill them.\n\n"
  .. "Prices come from Codex's own auction scans (Auction House module), craft costs from the Professions "
  .. "module. The window ranks the cheapest reputation by writ, NPC or zone; Buy list writes the Codex shopping "
  .. "list \"" .. C.SHOPPING_LIST .. "\", ready to search in the Codex auction panel.\n\n"
  .. "Codex learns what your turn-ins really give, and who took each writ, so the guides' numbers are replaced "
  .. "as you play."

function C.StatusText()
  if not C.DB() then
    return ""
  end
  local faction = C.Faction()
  local text = C.Tone(C.FactionText(faction))
  local favor = C.Favor()
  if favor then
    text = text .. (". %s Merchant's Favor."):format(C.Number(favor))
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
  for _, talent in ipairs({ { "Performance Bonus", C.HasPerformanceBonus() }, { "Diplomat", C.HasDiplomat() } }) do
    talents[#talents + 1] = talent[1] .. (talent[2] and " (yours: counted in)" or " (not taken)")
  end
  return ("Legacy talents: %s.\nLearned from your turn-ins: %d crate kinds, %d writs, %d writ NPCs.\nPrices: %s.")
    :format(table.concat(talents, ", "), crates, writs, customers, #names > 0 and table.concat(names, ", ")
      or "the Auction House module is off, so writs have no prices")
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
  ns.Say("learned turn-in amounts cleared; the guides' numbers are used again.")
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

  local open = UI.Button(page, 150, 24, "Open the window")
  open:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -12)
  open:SetScript("OnClick", C.ToggleWindow)
  Tip(open, "Commerce Authority", "Reputation, Merchant's Favor, your writs by who takes them, the next standings "
    .. "and the cheapest reputation (/codex commerce).")
  local npcs = UI.Button(page, 110, 24, "Writ NPCs")
  npcs:SetPoint("LEFT", open, "RIGHT", 8, 0)
  npcs:SetScript("OnClick", C.ToggleNPCWindow)
  Tip(npcs, "Writ NPCs", "Every NPC who takes writs, with all its writs and which of them you have "
    .. "(/codex commerce npcs).")
  local buy = UI.Button(page, 100, 24, "Buy list")
  buy:SetPoint("LEFT", npcs, "RIGHT", 8, 0)
  buy:SetScript("OnClick", C.CreateBuyList)
  Tip(buy, "Buy list", "The cheapest writs to your next standing, and the items they ask for, in the Codex "
    .. "shopping list \"" .. C.SHOPPING_LIST .. "\" (/codex commerce buy).")

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
  local forget = UI.Button(page, 160, 24, "Forget what was learned")
  forget:SetPoint("TOPLEFT", view.learned, "TOPRIGHT", 10, 2)
  forget:SetScript("OnClick", C.ForgetLearned)
  Tip(forget, "Forget what was learned", "Codex remembers the Merchant's Favor and reputation each crate and writ "
    .. "gave you. Clear them to go back to the guides' numbers. Who takes each writ is kept.")

  local how = UI.Text(page, "head", 12, "accent")
  how:SetPoint("TOPLEFT", view.learned, "BOTTOMLEFT", 0, -22)
  how:SetText("How it works")
  local text = UI.Text(page, "body", 12, "text")
  text:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  text:SetText(HOW)

  C.RefreshPage()
end
