local addonName, ns = ...

-- Reputation on the offer and reward pages ("+75 Booty Bay"). Forever's quest window gives addons no Classic
-- faction reputation (only C_QuestOffer.GetQuestOfferMajorFactionReputationRewards, for retail factions), so the
-- amounts come from D.QUEST_REP (RepData.lua, generated data). Faction names come from the game (C_Reputation.GetFactionDataByID, the older
-- GetFactionInfoByID), the table's own name when the game gives none. A quest that isn't in the table shows nothing.

local D = ns.dialogue

local function GameFactionName(factionID)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local data = D.Call(C_Reputation.GetFactionDataByID, factionID)
    local name = type(data) == "table" and D.Str(data.name)
    if name and name ~= "" then
      return name
    end
  end
  if type(_G.GetFactionInfoByID) == "function" then
    local name = D.Str(D.Call(_G.GetFactionInfoByID, factionID))
    if name and name ~= "" then
      return name
    end
  end
  return nil
end

-- { { factionID, name, amount }, ... } for a quest, or nil.
function D.Reputation(questID)
  questID = D.Num(questID)
  local list = questID and D.QUEST_REP and D.QUEST_REP[questID]
  if type(list) ~= "table" then
    return nil
  end
  local out = {}
  for index = 1, #list - 1, 2 do
    local factionID, amount = list[index], list[index + 1]
    local name = GameFactionName(factionID) or (D.FACTION_NAMES and D.FACTION_NAMES[factionID])
    if name and type(amount) == "number" and amount ~= 0 then
      out[#out + 1] = { factionID = factionID, name = name, amount = amount }
    end
  end
  return #out > 0 and out or nil
end

-- "+75" / "-500" for a chip.
function D.RepAmountText(amount)
  if amount > 0 then
    return "+" .. tostring(amount)
  end
  return "-" .. tostring(-amount)
end
