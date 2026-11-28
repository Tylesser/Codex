local addonName, ns = ...
local L = ns.L

-- Auction house module, part 2c: gear on sale that beats what you wear (2026-11-28), by the Stat Delta module's
-- upgrade score (ns.statdelta.BestUpgrade: usable items only, the same comparisons as its tooltip). Taken from the
-- prices Codex saved in the last two days (a full scan, browsing, searching); each random suffix of an item ("of
-- the Bear") counts on its own, as its stats come with the suffix. The Codex panel beside the auction house lists
-- them, the biggest gain first; a click searches the item in the game's auction house. Nothing is bought.

local A = ns.auction

local RECENT = 2 * 86400 -- prices older than this may be gone from the auction house
local BUDGET = 150 -- items looked at for the first time per refresh (each one reads a tooltip)

local asked = {} -- links already given to the score (their answer is cached there)
local refreshQueued = false

-- A gear variant's random suffix ("<itemLevel>:<suffix>", Data.lua's variant keys).
local function VariantSuffix(variant)
  return tonumber(tostring(variant):match(":(%-?%d+)$")) or 0
end

-- The item string of an item with a random suffix (item:id:enchant:gem1:gem2:gem3:gem4:suffix, A.ParseLink).
function A.UpgradeLink(itemID, suffix)
  if suffix and suffix ~= 0 then
    return ("item:%d:0:0:0:0:0:%d"):format(itemID, suffix)
  end
  return "item:" .. itemID
end

-- The saved gear prices of the last two days: { key, link, price, count, seen }.
local function Candidates(now)
  local realm = A.Realm(false)
  local list = {}
  for key, rec in pairs(realm and realm.items or {}) do
    if type(key) == "number" and A.IsEquipment(key) then
      if rec.v and next(rec.v) then
        for variant, data in pairs(rec.v) do
          if type(data) == "table" and data[1] and data[2] and now - data[2] <= RECENT then
            list[#list + 1] = { key = key, link = A.UpgradeLink(key, VariantSuffix(variant)), price = data[1],
              count = data[3] or 0, seen = data[2] }
          end
        end
      elseif rec.m and rec.t and now - rec.t <= RECENT then
        list[#list + 1] = { key = key, link = A.UpgradeLink(key, 0), price = rec.m, count = rec.n or 0, seen = rec.t }
      end
    end
  end
  return list
end

local function GainText(choice)
  if choice.old > 0 then
    return ("+%.1f%%"):format((choice.new - choice.old) / choice.old * 100)
  end
  return ("+%.1f"):format(choice.new - choice.old)
end

local function QueueRefresh()
  if refreshQueued then
    return
  end
  refreshQueued = true
  C_Timer.After(0.3, function()
    refreshQueued = false
    if A.RefreshPanel then
      A.RefreshPanel()
    end
  end)
end

-- The rows for the panel (biggest gain in points first) and its status line.
function A.UpgradeRows()
  local S = ns.statdelta
  if not (S and S.running and S.ActiveWeights and S.ActiveWeights()) then
    return {}, L["Upgrades need Codex's Stat Delta module with an upgrade score."]
  end
  local rows, budget, left = {}, BUDGET, 0
  for _, candidate in ipairs(Candidates(time())) do
    local link = candidate.link
    local choice
    if asked[link] or budget > 0 then
      if not asked[link] then
        budget = budget - 1
      end
      choice = S.BestUpgrade(link)
      if choice == nil then
        left = left + 1 -- the item's data isn't loaded yet: again on the next refresh
      else
        asked[link] = true
      end
    else
      left = left + 1
    end
    if choice then
      -- (the variant's own name, "... of the Bear", once the game has it)
      local name, quality, icon
      local getInfo = A.ItemApi("GetItemInfo")
      if getInfo then
        local info = { getInfo(link) }
        name, quality, icon = info[1], info[3], info[10]
      end
      local baseName, baseIcon, baseQuality = A.ItemInfo(candidate.key, true)
      rows[#rows + 1] = {
        key = candidate.key, link = link, upgrade = choice, seen = candidate.seen,
        name = name or baseName or A.CachedName(candidate.key) or L["Item %s"]:format(candidate.key),
        icon = icon or baseIcon, quality = quality or baseQuality,
        count = candidate.count, price = candidate.price, gainText = GainText(choice),
        gain = choice.new - choice.old, deal = true,
      }
    end
  end
  table.sort(rows, function(a, b)
    if a.gain ~= b.gain then
      return a.gain > b.gain
    end
    if a.price ~= b.price then
      return a.price < b.price
    end
    return a.name < b.name
  end)
  if left > 0 then
    QueueRefresh()
    return rows, L["Checking the gear on sale... (%d left)"]:format(left)
  end
  if #rows == 0 then
    local realm = A.Realm(false)
    return rows, realm and next(realm.items or {}) and L["No upgrades among the prices of the last two days."]
      or L["Run a full scan to find them."]
  end
  return rows, L["%d upgrades on sale (prices of the last two days)."]:format(#rows)
end
