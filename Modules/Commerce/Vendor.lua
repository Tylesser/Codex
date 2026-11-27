local addonName, ns = ...

-- Commerce module, part 7: marks and tooltip lines at the vendors that take Merchant's Favor.
-- Ported from Tylesser - Commerce Authority (same author, MIT); see Modules/Commerce/Settings.lua.

local C = ns.commerce
local L = ns.L

-- At the Commerce Authority vendors: every item that costs Merchant's Favor gets a small mark, green "Can
-- buy" or red "Need 340", and its tooltip says how many crates the rest is. Works with Tylesser - Vendor
-- Search's filtering: the merchant index comes from the item button's ID, which both addons keep.

local labels = {}

local function DB()
  return C.db or C.DEFAULTS
end

-- The Merchant's Favor an item costs, or nil.
function C.MerchantFavorCost(index)
  if not (index and GetMerchantItemCostInfo and GetMerchantItemCostItem) then
    return nil
  end
  local _, favorName = C.Favor()
  local costs = GetMerchantItemCostInfo(index) or 0
  for cost = 1, costs do
    local _, value, link, name = GetMerchantItemCostItem(index, cost)
    if (type(link) == "string" and link:find("currency:" .. C.FAVOR_CURRENCY, 1, true))
      or (favorName and name == favorName) then
      return value
    end
  end
end

local function Label(slot)
  local label = labels[slot]
  if not label then
    local button = _G["MerchantItem" .. slot]
    if not button then
      return nil
    end
    label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
    labels[slot] = label
  end
  return label
end

local function ItemIndex(slot)
  local itemButton = _G["MerchantItem" .. slot .. "ItemButton"]
  local button = _G["MerchantItem" .. slot]
  itemButton = itemButton or (button and button.ItemButton)
  return itemButton and itemButton.GetID and itemButton:GetID()
end

function C.UpdateVendorMarks()
  local favor = C.Favor()
  local onBuyTab = not MerchantFrame or MerchantFrame.selectedTab == nil or MerchantFrame.selectedTab == 1
  for slot = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
    local button = _G["MerchantItem" .. slot]
    local label = button and Label(slot)
    if label then
      local cost = DB().vendorMarks and favor and onBuyTab and button:IsShown() and C.MerchantFavorCost(ItemIndex(slot))
      if cost and cost > 0 then
        if favor >= cost then
          label:SetText("|cff40ff40" .. L["Can buy"] .. "|r")
        else
          label:SetText("|cffff5050" .. L["Need %s"]:format(C.Number(cost - favor)) .. "|r")
        end
        label:Show()
      else
        label:Hide()
      end
    end
  end
end

-- The mark shown on a merchant row, or nil (for tests and /aca debug).
function C.VendorLabelText(slot)
  local label = labels[slot]
  if label and label:IsShown() then
    return label:GetText()
  end
end

-- "about 34 Journeyman crates" for the Favor still needed.
local function CratesFor(needed)
  local journeyman = C.CRATE_LEVELS.Journeyman.favor
  local expert = C.CRATE_LEVELS.Expert.favor
  return L["about %d Journeyman or %d Expert crates (raw goods)"]:format(math.ceil(needed / journeyman),
    math.ceil(needed / expert))
end

local function MerchantTooltip(tooltip, index)
  if not DB().vendorMarks then
    return
  end
  local cost = C.MerchantFavorCost(index)
  local favor = C.Favor()
  if not (cost and favor and cost > 0) then
    return
  end
  if favor >= cost then
    tooltip:AddLine("Commerce Authority: " .. L["you have %s Merchant's Favor, %s left after this"]:format(
      C.Number(favor), C.Number(favor - cost)), 0.25, 1, 0.25)
  else
    tooltip:AddLine("Commerce Authority: " .. L["%s more Merchant's Favor needed, %s"]:format(
      C.Number(cost - favor), CratesFor(cost - favor)), 1, 0.82, 0, true)
  end
  tooltip:Show()
end

function C.HookVendor()
  if MerchantFrame_UpdateMerchantInfo then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
      C.UpdateVendorMarks()
      -- again next frame, after other addons (Vendor Search) have laid the page out
      if C_Timer and C_Timer.After then
        C_Timer.After(0, C.UpdateVendorMarks)
      end
    end)
  end
  if GameTooltip and GameTooltip.SetMerchantItem then
    hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
      pcall(MerchantTooltip, tooltip, index)
    end)
  end
end
