local addonName, ns = ...
local L = ns.L

-- Professions module, part 4: item tooltips. For an item one of your characters can craft:
--   Craft cost     1g 20s            (the reagents at today's prices; "(Name)" when only another character knows it)
--   Craft profit   +1g 90s           (auction price x amount made, after the AH cut, minus the craft cost)
-- and "AH value" for any item with a Codex price, but only while the Auction House module shows no "Auction"
-- line of its own, so a price never shows twice. Skipped for forbidden and comparison tooltips, secret
-- values and the profit list's own rows.

local P = ns.professions

-- The Auction House module already writes the item's price into the tooltip.
local function AuctionLineShown()
  local A = ns.auction
  return A and A.running and A.db and A.db.tooltip and true or false
end
P.AuctionLineShown = AuctionLineShown

-- { { left, right }, ... } for one item, for tests and the tooltip.
function P.TooltipLines(itemID, link)
  local db = P.db
  local lines = {}
  if not db or not itemID then
    return lines
  end
  local unit, seen = P.ProductPrice(link, itemID)
  if db.tooltip then
    local craft = P.CraftInfo(itemID)
    if craft then
      local label = L["Craft cost"]
      if not craft.mine then
        label = label .. " |cff999999(" .. craft.name .. ")|r"
      end
      local right
      if craft.cost then
        right = ns.Money(craft.cost) .. (craft.missing and "|cffff8000*|r" or "")
        if craft.numMade ~= 1 then
          right = right .. " |cff999999" .. L["(makes %g)"]:format(craft.numMade) .. "|r"
        end
      else
        right = "|cff999999" .. L["no price yet - scan at the AH"] .. "|r"
      end
      lines[#lines + 1] = { label, right }
      if unit and craft.cost and not craft.missing then
        local profit = math.floor(unit * craft.numMade * P.Keep()) - craft.cost
        lines[#lines + 1] = { L["Craft profit"], P.Money(math.floor(profit + 0.5), true) }
      end
    end
  end
  if db.tooltipValue and unit and not AuctionLineShown() then
    lines[#lines + 1] = { L["AH value"], ns.Money(unit) .. " |cff999999(" .. ns.Age(seen) .. ")|r" }
  end
  return lines
end

local function ItemOf(tooltip, data)
  local itemID, link
  if data and P.Readable(data.id) and type(data.id) == "number" then
    itemID = data.id
  end
  if tooltip.GetItem then
    local _, itemLink = tooltip:GetItem()
    if P.Readable(itemLink) then
      link = P.ItemLinkOrNil(itemLink)
    end
  end
  return itemID or P.ItemIDFromLink(link), link
end

local function IsOwnRow(tooltip)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  return type(owner) == "table" and owner.codexProfRow == true
end

function P.AddTooltipLines(tooltip, data)
  local db = P.db
  if not db or not (db.tooltip or db.tooltipValue) then
    return
  end
  if tooltip.IsForbidden and tooltip:IsForbidden() then
    return
  end
  local name = tooltip.GetName and tooltip:GetName()
  if name ~= nil and (not P.Readable(name) or name:find("Shopping")) then
    return -- the comparison tooltips beside the main one
  end
  if IsOwnRow(tooltip) then
    return
  end
  local itemID, link = ItemOf(tooltip, data)
  if not itemID then
    return
  end
  local lines = P.TooltipLines(itemID, link)
  if #lines == 0 then
    return
  end
  -- under the shared "Codex" heading when the tooltip skin offers one (labels muted then), else accent labels
  local label = ns.InkTheme().accent -- the game's tooltip: ink
  local section = ns.API.TooltipSection
  if section and section(tooltip, "Codex") then
    label = ns.InkTheme().muted
  end
  for _, line in ipairs(lines) do
    tooltip:AddDoubleLine(line[1], line[2], label[1], label[2], label[3], 1, 1, 1)
  end
end

local function Safe(tooltip, data)
  local ok, err = pcall(P.AddTooltipLines, tooltip, data)
  if not ok then
    geterrorhandler()(err)
  end
end

-- Once, from Enable. The options only decide whether lines are added.
function P.InstallTooltip()
  if P.tooltipInstalled or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
    and Enum.TooltipDataType) then
    return
  end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe)
  P.tooltipInstalled = true
end
