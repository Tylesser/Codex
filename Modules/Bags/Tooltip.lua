local addonName, ns = ...
local L = ns.L

-- Bags module, part 2: "Codex: N on your characters" in item tooltips, with a line per character
-- (bags / bank / equipped). Skipped when the item can't be read (forbidden tooltip or secret data).

local B = ns.bags

local MAX_CHARACTERS = 6

local function Where(entry)
  local parts = {}
  if entry.bags > 0 then
    parts[#parts + 1] = L["bags %d"]:format(entry.bags)
  end
  if entry.bank > 0 then
    parts[#parts + 1] = L["bank %d"]:format(entry.bank)
  end
  if entry.equipped > 0 then
    parts[#parts + 1] = L["worn %d"]:format(entry.equipped)
  end
  return table.concat(parts, ", ")
end

local function ItemIDOf(tooltip, data)
  if data and B.Readable(data.id) and type(data.id) == "number" then
    return data.id
  end
  if tooltip.GetItem then
    local _, link = tooltip:GetItem()
    if B.Readable(link) then
      return B.ItemID(link)
    end
  end
end

-- The lines for one item ({ left, right } pairs), for tests and the tooltip.
function B.TooltipLines(itemID)
  local list, total = B.ItemCounts(itemID)
  if total == 0 then
    return {}
  end
  local lines = { { L["Codex: %d on your characters"]:format(total), nil } }
  for index, entry in ipairs(list) do
    if index > MAX_CHARACTERS then
      lines[#lines + 1] = { "  " .. L["and %d more"]:format(#list - MAX_CHARACTERS), nil }
      break
    end
    lines[#lines + 1] = { "  " .. B.ColoredName(entry.key), entry.total .. " |cff999999(" .. Where(entry) .. ")|r" }
  end
  return lines
end

function B.AddTooltipLines(tooltip, data)
  local db = B.db
  if not db or not db.tooltip then
    return
  end
  if tooltip.IsForbidden and tooltip:IsForbidden() then
    return
  end
  local name = tooltip.GetName and tooltip:GetName()
  if name ~= nil and (not B.Readable(name) or name:find("^ShoppingTooltip")) then
    return -- the comparison tooltips beside the main one
  end
  local itemID = ItemIDOf(tooltip, data)
  if not itemID then
    return
  end
  local lines = B.TooltipLines(itemID)
  if #lines == 0 then
    return
  end
  local theme = ns.InkTheme() -- the game's tooltip: ink
  local accent = theme.accent
  -- under the tooltip skin's "Codex" heading (board R2-Tooltips) the first line reads "On your characters  N"
  local sectioned = ns.API.TooltipSection and ns.API.TooltipSection(tooltip, "Codex")
  for index, line in ipairs(lines) do
    if sectioned and index == 1 then
      local total = line[1]:match("(%d+)") or ""
      tooltip:AddDoubleLine(L["On your characters"], total, theme.muted[1], theme.muted[2], theme.muted[3],
        theme.bright[1], theme.bright[2], theme.bright[3])
    elseif line[2] then
      tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
    elseif index == 1 then
      tooltip:AddLine(line[1], accent[1], accent[2], accent[3])
    else
      tooltip:AddLine(line[1], 0.6, 0.6, 0.6)
    end
  end
end

local function Safe(tooltip, data)
  local ok, err = pcall(B.AddTooltipLines, tooltip, data)
  if not ok then
    geterrorhandler()(err)
  end
end

-- Once, from Enable. The option only decides whether lines are added.
function B.InstallTooltip()
  if B.tooltipInstalled or not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
    return
  end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Safe)
  B.tooltipInstalled = true
end
