local addonName, ns = ...

-- Learn all at trainers (2026-11-21): a "Learn all" button on the class trainer window that learns every spell
-- you can learn now and afford, cheapest first. Forever's trainer is Blizzard_TrainerUI (Mainline + Camelot
-- overrides, forever branch): GetNumTrainerServices, GetTrainerServiceInfo(i) -> name, type ("available" /
-- "unavailable" / "used"), icon, level, subtext, category; GetTrainerServiceCost(i) -> money, isProfession;
-- BuyTrainerService(i) is what its Train button calls. Professions are never learned here (the game asks to
-- confirm a profession, and you pick those yourself).
--
-- Everything is bought inside the one click: the list is chosen first (cheapest first, within your money), then
-- bought from the highest index down, so an index never shifts under the next purchase. Spells whose lower rank you
-- learn now turn "available" with the next TRAINER_UPDATE: the button counts them again and a second click learns
-- them. The button is a frame of ours on ClassTrainerFrame (a plain UI panel); nothing of Blizzard's is changed.

local Q = ns.qol
local UI = ns.UI
local KEY = "trainerAll"
local TA = {}
Q.trainer = TA

local button, events

local function Num(value)
  return type(value) == "number" and (not canaccessvalue or canaccessvalue(value)) and value or nil
end

-- The services to learn now: { index, cost, name } cheapest first, within `money`, and their total.
function TA.Plan(money)
  local list = {}
  local count = GetNumTrainerServices and Num(GetNumTrainerServices()) or 0
  local step = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex() or nil
  for index = 1, count do
    if index ~= step then
      local name, kind = GetTrainerServiceInfo(index)
      if kind == "available" then
        local cost, isProfession = GetTrainerServiceCost(index)
        cost = Num(cost) or 0
        if not isProfession then
          list[#list + 1] = { index = index, cost = cost, name = name }
        end
      end
    end
  end
  table.sort(list, function(a, b)
    if a.cost ~= b.cost then
      return a.cost < b.cost
    end
    return a.index < b.index
  end)
  local chosen, total = {}, 0
  for _, entry in ipairs(list) do
    if total + entry.cost <= money then
      chosen[#chosen + 1] = entry
      total = total + entry.cost
    end
  end
  return chosen, total, #list
end

function TA.Money()
  return GetMoney and Num(GetMoney()) or 0
end

function TA.LearnAll()
  if not Q.On(KEY) then
    return 0, 0
  end
  local chosen, total = TA.Plan(TA.Money())
  table.sort(chosen, function(a, b)
    return a.index > b.index
  end)
  for _, entry in ipairs(chosen) do
    pcall(BuyTrainerService, entry.index)
  end
  if #chosen > 0 then
    ns.Say(("Learned %d %s for %s."):format(#chosen, #chosen == 1 and "spell" or "spells", ns.Money(total)))
  end
  return #chosen, total
end

function TA.Update()
  if not button then
    return
  end
  local on = Q.On(KEY) and ClassTrainerFrame and ClassTrainerFrame:IsShown()
  if not on then
    button:Hide()
    return
  end
  local chosen, total, available = TA.Plan(TA.Money())
  button:Show()
  button:SetText(#chosen > 0 and ("Learn all (%d)"):format(#chosen) or "Learn all")
  button:SetEnabled(#chosen > 0)
  button.total, button.count, button.available = total, #chosen, available
end

local function ShowTip(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Learn all")
  if (self.count or 0) > 0 then
    GameTooltip:AddLine(("%d %s for %s, cheapest first."):format(self.count, self.count == 1 and "spell" or "spells",
      ns.Money(self.total or 0)), 1, 1, 1, true)
  else
    GameTooltip:AddLine("Nothing you can learn and afford right now.", 1, 1, 1, true)
  end
  if (self.available or 0) > (self.count or 0) then
    GameTooltip:AddLine(("%d more when you have the gold."):format(self.available - self.count), 0.7, 0.7, 0.7, true)
  end
  GameTooltip:AddLine("Professions are left to you.", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end

local function MakeButton()
  if button or not ClassTrainerFrame then
    return
  end
  button = UI.Button(ClassTrainerFrame, 110, 22, "Learn all")
  local train = ClassTrainerTrainButton
  if train then
    button:SetPoint("RIGHT", train, "LEFT", -4, 0)
  else
    button:SetPoint("BOTTOMRIGHT", ClassTrainerFrame, "BOTTOMRIGHT", -100, 4)
  end
  button:SetFrameLevel((train and train:GetFrameLevel() or ClassTrainerFrame:GetFrameLevel()) + 2)
  button:SetScript("OnClick", function(self)
    TA.LearnAll()
    ShowTip(self)
  end)
  button:SetScript("OnEnter", ShowTip)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:Hide()
end

local function OnEvent(_, event, name)
  if event == "ADDON_LOADED" and name ~= "Blizzard_TrainerUI" then
    return
  end
  if not Q.On(KEY) then
    if button then
      button:Hide()
    end
    return
  end
  MakeButton()
  TA.Update()
end

local function Start()
  if not events then
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
  end
  for _, event in ipairs({ "ADDON_LOADED", "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_MONEY", "TRAINER_CLOSED" }) do
    pcall(events.RegisterEvent, events, event)
  end
  if ClassTrainerFrame then
    MakeButton()
    TA.Update()
  end
end

Q.AddToggle({
  key = KEY,
  name = "Learn all at trainers",
  desc = "A Learn all button on the class trainer's window: learns every spell you can learn now and afford, "
    .. "cheapest first. Professions are left to you. Click again for spells whose lower rank you just learned.",
  default = true,
  order = 60,
  Enable = function()
    if Q.On(KEY) then
      Start()
    end
  end,
  Changed = function(on)
    if on then
      Start()
    elseif button then
      button:Hide()
    end
  end,
})
