local addonName, ns = ...
local L = ns.L

-- Vendor search module, part 3: settings, events, the module's page, commands and registration. Tylesser - Vendor
-- Search ported into Codex: a search box on the vendor window that filters its own item grid by name, type or
-- slot, "Unknown" (recipes, mounts, pets) / "Usable" / "Can afford" filters, a fade mode, bag counts and "Known"
-- marks on the items, and a Buy window (Alt-click a stackable item: several stacks at once, Buy.lua). While the
-- standalone addon is loaded Codex leaves this to it (unless the player forces Codex's copy).
--
-- CodexDB.vendorsearch = { fade, bagCount, boxOffset (the box's place on the vendor window, kept out of profiles) }

local V = ns.vendorsearch
local UI = ns.UI

V.DEFAULTS = {
  boxOffset = nil,
  fade = false,
  bagCount = true,
}

-- The standalone addon's settings, copied once (the player forced Codex's copy with Vendor Search around).
function V.DB()
  if not ns.db then
    return nil
  end
  if not ns.db.vendorsearch then
    local target = {}
    if type(VendorSearchDB) == "table" then
      target.fade = VendorSearchDB.fade
      target.bagCount = VendorSearchDB.bagCount
      if type(VendorSearchDB.boxOffset) == "table" then
        target.boxOffset = { VendorSearchDB.boxOffset[1], VendorSearchDB.boxOffset[2] }
      end
    end
    ns.db.vendorsearch = target
  end
  if V.db ~= ns.db.vendorsearch then
    V.db = ns.Fill(ns.db.vendorsearch, V.DEFAULTS)
  end
  return V.db
end

-- Events --------------------------------------------------------------------------------------------------

local function MerchantOpen()
  return MerchantFrame and MerchantFrame:IsShown()
end

-- Item types/slots can arrive a moment after the vendor opens; the bag counts and "Known" marks need the item
-- data too.
local refreshPending = false
local function RequestRefresh()
  if refreshPending or not MerchantOpen() then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    V.Filter:Apply()
  end)
end

-- Buying or using an item (e.g. learning a recipe) changes the bag counts and what is known.
local function InventoryChanged()
  if not MerchantOpen() then
    return
  end
  V.ClearKnownCache()
  RequestRefresh()
end

-- Gold or currency changed: the "Can afford" filter shows other items.
local function MoneyChanged()
  if MerchantOpen() and V.Filter.affordOnly then
    RequestRefresh()
  end
end

local HANDLERS = {
  MERCHANT_SHOW = function()
    V.ClearKnownCache()
  end,
  MERCHANT_CLOSED = function()
    V.Filter:Clear()
  end,
  GET_ITEM_INFO_RECEIVED = RequestRefresh,
  BAG_UPDATE_DELAYED = InventoryChanged,
  NEW_RECIPE_LEARNED = InventoryChanged,
  LEARNED_SPELL_IN_TAB = InventoryChanged,
  NEW_MOUNT_ADDED = InventoryChanged,
  NEW_PET_ADDED = InventoryChanged,
  COMPANION_LEARNED = InventoryChanged,
  PLAYER_MONEY = MoneyChanged,
  CURRENCY_DISPLAY_UPDATE = MoneyChanged,
}

function V.Enable()
  V.DB()
  V.Filter:Create()
  local events = CreateFrame("Frame")
  for event in pairs(HANDLERS) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript("OnEvent", function(_, event, ...)
    HANDLERS[event](...)
  end)
  V.eventFrame = events
  -- the standalone addon's /vsearch and /vendorsearch, while it isn't loaded
  if not SlashCmdList.VENDORSEARCH and not ns.IsAddOnLoaded("VendorSearch") then
    SLASH_CODEXVENDORSEARCH1 = "/vsearch"
    SLASH_CODEXVENDORSEARCH2 = "/vendorsearch"
    SlashCmdList.CODEXVENDORSEARCH = V.Slash
  end
  V.running = true
end

-- The page --------------------------------------------------------------------------------------------------

local view = {}

local OPTIONS = {
  { "fade", L["Fade instead of hide"], L["Keep the vendor's own pages and fade the items that don't match; Enter turns to the first page with a match."] },
  { "bagCount", L["How many you have"], L["A backpack mark with the count from your bags and bank on each item."] },
}

local HOW = L["Talk to a vendor: a search box sits at the top of the vendor window. Type part of an item's name, type or slot (\"vial\", \"recipe cooking\", \"head\"); every word must match. The vendor's own window shows the matches, so buying, tooltips and item previews work as usual. Under the box, \"Unknown\" shows only recipes you haven't learned and mounts and pets you don't have, \"Usable\" only what your character can use and \"Can afford\" only what you can pay for now; they reset when the vendor closes. Learned recipes, and mounts and pets you have, get a green \"Known\" mark."]
  .. "\n\n" .. L["Alt-click a stackable item to buy several stacks at once: type how many, and Buy splits it into one purchase per stack, as many as your gold, the vendor's stock and your bags allow."]
  .. "\n\n" .. L["Alt-drag the box to move it."]

function V.StatusText()
  return L["A search box on the vendor window."]
end

function V.RefreshPage()
  if not view.page then
    return
  end
  local db = V.DB()
  for _, check in ipairs(view.checks) do
    check:SetChecked(db[check.key])
  end
end

function V.SetOption(key, on)
  V.DB()[key] = on and true or false
  if V.running and MerchantOpen() then
    V.Filter:Refresh(true)
  end
  V.RefreshPage()
end

function V.BuildPage(page)
  V.DB()
  view.page = page
  local heading = UI.Heading(page, L["Vendor search"], 20)
  heading:SetPoint("TOPLEFT")
  local status = UI.Text(page, "body", 12, "muted")
  status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
  status:SetPoint("RIGHT", 0, 0)
  status:SetText(V.StatusText())

  view.checks = {}
  local anchor
  for _, option in ipairs(OPTIONS) do
    local check = UI.Check(page, option[2])
    check.key = option[1]
    if anchor then
      check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      check:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)
    end
    local note = UI.Text(page, "body", 11, "muted")
    note:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
    note:SetPoint("RIGHT", page, "RIGHT", 0, 0) -- bound to the page: a long note wraps
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(option[3])
    check:SetScript("OnClick", function(self)
      V.SetOption(self.key, self:GetChecked())
    end)
    view.checks[#view.checks + 1] = check
    anchor = check
  end

  local reset = UI.Button(page, 190, 24, L["Put the search box back"])
  reset:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
  reset:SetScript("OnClick", function()
    V.ResetBox()
  end)

  local how = UI.Text(page, "head", 12, "accent")
  how:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 0, -18)
  how:SetText(L["How it works"])
  local text = UI.Text(page, "body", 12, "text")
  text:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  text:SetText(HOW)

  V.RefreshPage()
end

-- Commands ----------------------------------------------------------------------------------------------

function V.ResetBox()
  V.DB().boxOffset = nil
  if V.running then
    V.Filter:ResetPosition()
  end
  ns.Say(L["search box moved back to its default place."])
end

-- /codex vendorsearch [reset | help]; anything else (or nothing) puts the cursor in the box at a vendor
function V.Slash(rest)
  local command = strtrim(rest or ""):lower()
  if command == "reset" then
    V.ResetBox()
  elseif command == "help" then
    ns.Say(L["Vendor search commands:"])
    print("  /codex vendorsearch: " .. L["put the cursor in the search box"])
    print("  /codex vendorsearch reset: " .. L["move the search box back to its default place"])
    print("  /codex vendorsearch options: " .. L["this module's page in the Codex window"])
  elseif command == "options" then
    ns.ShowPage("vendorsearch")
  elseif not V.running then
    ns.Say(L["the Vendor search module is off; switch it on in the Codex window."])
  elseif not MerchantOpen() then
    ns.Say(L["talk to a vendor to search their items. Type %s for commands."]:format("/codex vendorsearch help"))
  else
    V.Filter:Focus()
  end
end

ns.RegisterModule({
  id = "vendorsearch",
  name = L["Vendor search"],
  -- its section in the Codex window (Areas.lua)
  area = "trade", sectionOrder = 32, folded = true, pageEstimate = 260,
  icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
  desc = L["A search box on the vendor window: filter its items by name, type or slot, unknown recipes or usable items, with bag counts and \"Known\" marks."],
  standalone = "VendorSearch",
  standaloneName = "Vendor Search",
  order = 97,
  Enable = function()
    V.Enable()
  end,
  BuildPage = function(_, page)
    V.BuildPage(page)
  end,
  ShowPage = function()
    V.RefreshPage()
  end,
  Status = function()
    return V.StatusText()
  end,
  Slash = function(_, rest)
    V.Slash(rest)
  end,
})
