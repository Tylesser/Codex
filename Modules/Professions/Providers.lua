local addonName, ns = ...

-- Professions module, part 2: one provider per kind of profession window (ported from Profit Sort).
-- WoW Forever uses the modern ProfessionsFrame (recipe schematic with "Reagents:", Track Recipe, Create All);
-- the classic TradeSkillFrame and CraftFrame are kept in case a profession still opens one of them.
-- Scan() returns entries and whether the list is complete (every learned recipe, not just what the filters show):
--   { key, name, icon, link, itemID, numMade, numAvailable, color, difficulty, skillUps, visible,
--     reagents = { { name, link, itemID, count, alternatives } } }
-- visible = false: the window's own search or filter hides it (left out of the profit list, still remembered).

local P = ns.professions
P.Providers = {}

local function IsHeader(skillType)
  return skillType == "header" or skillType == "subheader"
end

local function TypeColor(skillType)
  local colors = TradeSkillTypeColor
  return colors and colors[skillType]
end

-- Scroll a classic FauxScrollFrame list so that `index` is visible.
local function ScrollClassicList(scrollFrame, index, total, displayed, rowHeight)
  if not (scrollFrame and FauxScrollFrame_SetOffset and FauxScrollFrame_GetOffset and displayed and rowHeight) then
    return
  end
  local offset = FauxScrollFrame_GetOffset(scrollFrame)
  if index > offset and index <= offset + displayed then
    return
  end
  offset = math.max(0, math.min(index - 1, total - displayed))
  FauxScrollFrame_SetOffset(scrollFrame, offset)
  local frameName = scrollFrame:GetName()
  local bar = scrollFrame.ScrollBar or (frameName and _G[frameName .. "ScrollBar"])
  if bar then
    bar:SetValue(offset * rowHeight)
  end
end

--------------------------------------------------------------------------------------------------------------
-- Classic trade skill window (TradeSkillFrame / GetTradeSkillInfo)
--------------------------------------------------------------------------------------------------------------
P.Providers.TradeSkill = {
  id = "TradeSkill",
  dockX = -34,
  dockY = -12,

  IsAvailable = function()
    return GetNumTradeSkills ~= nil
  end,

  GetFrame = function()
    return TradeSkillFrame
  end,

  GetTitle = function()
    return GetTradeSkillLine and (GetTradeSkillLine())
  end,

  IsOwn = function()
    return not (IsTradeSkillLinked and IsTradeSkillLinked())
  end,

  -- { { name, icon, cooldown = seconds left or nil } } for the recipes the window lists (Cooldowns.lua)
  Cooldowns = function()
    local list = {}
    if not (GetTradeSkillCooldown and GetNumTradeSkills) then
      return list
    end
    for index = 1, GetNumTradeSkills() do
      local name, skillType = GetTradeSkillInfo(index)
      if name and not IsHeader(skillType) then
        local ok, left = pcall(GetTradeSkillCooldown, index)
        list[#list + 1] = { name = name, icon = GetTradeSkillIcon(index), cooldown = ok and left or nil }
      end
    end
    return list
  end,

  Scan = function()
    local entries = {}
    for index = 1, GetNumTradeSkills() do
      local name, skillType, numAvailable = GetTradeSkillInfo(index)
      if name and not IsHeader(skillType) then
        local link = P.ItemLinkOrNil(GetTradeSkillItemLink(index))
        local minMade, maxMade = GetTradeSkillNumMade(index)
        minMade = minMade or 1
        maxMade = maxMade or minMade
        local entry = {
          key = index, name = name, icon = GetTradeSkillIcon(index), link = link, itemID = P.ItemIDFromLink(link),
          numMade = (minMade + maxMade) / 2, numAvailable = numAvailable or 0, color = TypeColor(skillType),
          difficulty = skillType, visible = true, reagents = {},
        }
        for r = 1, GetTradeSkillNumReagents(index) do
          local reagentName, _, count = GetTradeSkillReagentInfo(index, r)
          local reagentLink = GetTradeSkillReagentItemLink(index, r)
          table.insert(entry.reagents, { name = reagentName, link = reagentLink,
            itemID = P.ItemIDFromLink(reagentLink), count = count or 1 })
        end
        table.insert(entries, entry)
      end
    end
    return entries, false
  end,

  GetSelectedKey = function()
    return GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or nil
  end,

  -- calls onSelect after the window selects a recipe; true when hooked
  Hook = function(onSelect)
    if TradeSkillFrame_SetSelection then
      hooksecurefunc("TradeSkillFrame_SetSelection", onSelect)
      return true
    end
    return false
  end,

  -- where the profit block sits: below the window's recipe details
  BlockParent = function()
    return TradeSkillFrame
  end,
  PlaceBlock = function(block, frame)
    block:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 16, 74)
  end,

  Select = function(entry)
    if TradeSkillFrame_SetSelection then
      TradeSkillFrame_SetSelection(entry.key)
    end
    ScrollClassicList(TradeSkillListScrollFrame, entry.key, GetNumTradeSkills(), TRADE_SKILLS_DISPLAYED,
      TRADE_SKILL_HEIGHT)
    if TradeSkillFrame_Update then
      TradeSkillFrame_Update()
    end
  end,
}

--------------------------------------------------------------------------------------------------------------
-- Classic craft window (CraftFrame / GetCraftInfo): Enchanting in the old clients. No item for enchants.
--------------------------------------------------------------------------------------------------------------
P.Providers.Craft = {
  id = "Craft",
  dockX = -34,
  dockY = -12,

  IsAvailable = function()
    return GetNumCrafts ~= nil
  end,

  GetFrame = function()
    return CraftFrame
  end,

  GetTitle = function()
    if GetCraftDisplaySkillLine then
      local name = GetCraftDisplaySkillLine()
      if name then
        return name
      end
    end
    return GetCraftName and GetCraftName()
  end,

  IsOwn = function()
    return true
  end,

  Cooldowns = function()
    return {} -- the classic craft window (Enchanting) has no recipe cooldowns
  end,

  Scan = function()
    local entries = {}
    for index = 1, GetNumCrafts() do
      local name, _, craftType, numAvailable = GetCraftInfo(index)
      local numReagents = GetCraftNumReagents(index) or 0
      if name and not IsHeader(craftType) and numReagents > 0 then
        local link = P.ItemLinkOrNil(GetCraftItemLink and GetCraftItemLink(index))
        local entry = {
          key = index, name = name, icon = GetCraftIcon(index), link = link, itemID = P.ItemIDFromLink(link),
          numMade = 1, numAvailable = numAvailable or 0, color = TypeColor(craftType), difficulty = craftType,
          visible = true, reagents = {},
        }
        for r = 1, numReagents do
          local reagentName, _, count = GetCraftReagentInfo(index, r)
          local reagentLink = GetCraftReagentItemLink(index, r)
          table.insert(entry.reagents, { name = reagentName, link = reagentLink,
            itemID = P.ItemIDFromLink(reagentLink), count = count or 1 })
        end
        table.insert(entries, entry)
      end
    end
    return entries, false
  end,

  GetSelectedKey = function()
    return GetCraftSelectionIndex and GetCraftSelectionIndex() or nil
  end,

  Hook = function(onSelect)
    if CraftFrame_SetSelection then
      hooksecurefunc("CraftFrame_SetSelection", onSelect)
      return true
    end
    return false
  end,

  BlockParent = function()
    return CraftFrame
  end,
  PlaceBlock = function(block, frame)
    block:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 16, 74)
  end,

  Select = function(entry)
    if CraftFrame_SetSelection then
      CraftFrame_SetSelection(entry.key)
    end
    ScrollClassicList(CraftListScrollFrame, entry.key, GetNumCrafts(), CRAFTS_DISPLAYED, CRAFT_SKILL_HEIGHT)
    if CraftFrame_Update then
      CraftFrame_Update()
    end
  end,
}

--------------------------------------------------------------------------------------------------------------
-- Modern professions window (ProfessionsFrame / C_TradeSkillUI): the one WoW Forever opens.
--------------------------------------------------------------------------------------------------------------
local modernNames, modernColors
local function ModernDifficulty(relativeDifficulty)
  local difficulty = Enum and Enum.TradeskillRelativeDifficulty
  if not difficulty or relativeDifficulty == nil then
    return nil
  end
  modernNames = modernNames or {
    [difficulty.Optimal] = "optimal", [difficulty.Medium] = "medium",
    [difficulty.Easy] = "easy", [difficulty.Trivial] = "trivial",
  }
  return modernNames[relativeDifficulty]
end

local function ModernColor(relativeDifficulty)
  local difficulty = Enum and Enum.TradeskillRelativeDifficulty
  if not difficulty or relativeDifficulty == nil then
    return nil
  end
  modernColors = modernColors or {
    [difficulty.Optimal] = { r = 1.00, g = 0.50, b = 0.25 }, [difficulty.Medium] = { r = 1.00, g = 1.00, b = 0.00 },
    [difficulty.Easy] = { r = 0.25, g = 0.75, b = 0.25 }, [difficulty.Trivial] = { r = 0.50, g = 0.50, b = 0.50 },
  }
  return modernColors[relativeDifficulty]
end

local function IsBasicReagentSlot(slot)
  local types = Enum and Enum.CraftingReagentType
  if types and types.Basic and slot.reagentType ~= nil then
    return slot.reagentType == types.Basic
  end
  return slot.required ~= false
end

local function SchematicForm()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  return page and page.SchematicForm
end
P.SchematicForm = SchematicForm

P.Providers.Professions = {
  id = "Professions",
  dockX = 2,
  dockY = 0,

  IsAvailable = function()
    return C_TradeSkillUI ~= nil and C_TradeSkillUI.GetAllRecipeIDs ~= nil and C_TradeSkillUI.GetRecipeSchematic ~= nil
  end,

  GetFrame = function()
    return ProfessionsFrame
  end,

  GetTitle = function()
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return info and info.professionName
  end,

  -- your own profession, not one opened from a chat link, a guild list or an NPC
  IsOwn = function()
    for _, name in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsTradeSkillGuildMember" }) do
      local fn = C_TradeSkillUI[name]
      if fn and fn() then
        return false
      end
    end
    return true
  end,

  -- C_TradeSkillUI.GetRecipeCooldown(recipeID): seconds left (nil when ready), isDayCooldown, charges, maxCharges,
  -- as forever Blizzard_ProfessionsRecipeSchematicForm reads it. Every learned recipe, not only the filtered ones.
  Cooldowns = function()
    local list = {}
    if not (C_TradeSkillUI.GetRecipeCooldown and C_TradeSkillUI.GetAllRecipeIDs) then
      return list
    end
    if C_TradeSkillUI.IsTradeSkillReady and not C_TradeSkillUI.IsTradeSkillReady() then
      return list
    end
    for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
      if info and info.learned and info.name then
        local ok, left, _, charges, maxCharges = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
        if ok then
          list[#list + 1] = { name = info.name, icon = info.icon, cooldown = left, charges = charges,
            maxCharges = maxCharges }
        end
      end
    end
    return list
  end,

  Scan = function()
    local entries = {}
    if C_TradeSkillUI.IsTradeSkillReady and not C_TradeSkillUI.IsTradeSkillReady() then
      return entries, false
    end
    local shown
    local filtered = C_TradeSkillUI.GetFilteredRecipeIDs and C_TradeSkillUI.GetFilteredRecipeIDs()
    if filtered then
      shown = {}
      for _, recipeID in ipairs(filtered) do
        shown[recipeID] = true
      end
    end
    for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
      local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
      if info and info.learned and not info.isDummyRecipe and not info.isGatheringRecipe and not info.isRecraft
        and not info.isSalvageRecipe then
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        if schematic then
          local output = C_TradeSkillUI.GetRecipeOutputItemData and C_TradeSkillUI.GetRecipeOutputItemData(recipeID)
          local link = output and P.ItemLinkOrNil(output.hyperlink)
          local minMade = schematic.quantityMin or 1
          local maxMade = schematic.quantityMax or minMade
          local entry = {
            key = recipeID, name = info.name or schematic.name or "?", icon = info.icon, link = link,
            itemID = (output and output.itemID) or schematic.outputItemID, numMade = (minMade + maxMade) / 2,
            numAvailable = info.numAvailable or 0, color = ModernColor(info.relativeDifficulty),
            difficulty = ModernDifficulty(info.relativeDifficulty),
            skillUps = (info.numSkillUps and info.numSkillUps > 1) and info.numSkillUps or 1,
            visible = not shown or shown[recipeID] == true, reagents = {},
          }
          for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
            if IsBasicReagentSlot(slot) and slot.reagents then
              local itemIDs = {}
              for _, reagent in ipairs(slot.reagents) do
                if reagent.itemID then
                  table.insert(itemIDs, reagent.itemID)
                end
              end
              if #itemIDs > 0 then
                table.insert(entry.reagents, { itemID = itemIDs[1], count = slot.quantityRequired or 1,
                  alternatives = #itemIDs > 1 and itemIDs or nil })
              end
            end
          end
          table.insert(entries, entry)
        end
      end
    end
    return entries, #entries > 0
  end,

  GetSelectedKey = function()
    local form = SchematicForm()
    if form and form.GetRecipeInfo then
      local ok, info = pcall(form.GetRecipeInfo, form)
      if ok and type(info) == "table" then
        return info.recipeID
      end
    end
    return P.lastSchematicRecipe
  end,

  -- the schematic form shows a recipe through Init(recipeInfo)
  Hook = function(onSelect)
    local form = SchematicForm()
    if form and form.Init then
      hooksecurefunc(form, "Init", function(_, recipeInfo)
        if type(recipeInfo) == "table" then
          P.lastSchematicRecipe = recipeInfo.recipeID
        end
        onSelect()
      end)
      return true
    end
    return false
  end,

  -- the block sits in the schematic, under the reagent list (the empty part of the recipe page)
  BlockParent = function()
    return SchematicForm()
  end,
  PlaceBlock = function(block, form)
    local reagents = form.Reagents
    if reagents and reagents.GetObjectType then
      block:SetPoint("TOPLEFT", reagents, "BOTTOMLEFT", 0, -14)
    else
      block:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 20, 40)
    end
  end,

  Select = function(entry)
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    local info = C_TradeSkillUI.GetRecipeInfo(entry.key)
    if list and list.SelectRecipe and info then
      list:SelectRecipe(info, true)
    elseif C_TradeSkillUI.OpenRecipe then
      C_TradeSkillUI.OpenRecipe(entry.key)
    end
  end,
}
