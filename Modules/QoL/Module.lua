local addonName, ns = ...

-- Quality of life: a list of small options, each one a toggle in CodexDB.qol. A toggle is added with
-- Q.AddToggle({ key, name, desc, default, order, Enable, Elsewhere }) from its own file (listed in QoL.xml after
-- this one):
--   Enable()     once at login when the module is on (register events here; check Q.On(key) when they fire,
--                so switching the toggle works at once, without a reload)
--   Elsewhere()  optional: the name of another addon doing the same job right now, or nil. While it returns a
--                name the toggle stays idle and the page says so.
--   Changed(on)  optional: runs when the player switches the toggle while the module is on (a toggle that hooks
--                nothing while off does its hooking here when switched on).
--   options      optional: extra switches shown under the toggle, { { key, name, default, Changed }, ... }, kept in
--                CodexDB.qol beside the toggles (Q.Set works for them too; Changed(on) runs while the module is on).
--                An option may have a kind: "check" (the default, true/false), "choice" (a picker: choices =
--                { { value, text }, ... }, default = a value; Changed(value); button = { name, Click } puts a small
--                button beside the picker; preview(holder) = a frame shown beside it; rowHeight), "stepper" ("- value +":
--                values = { { value, text }, ... }, default = a value), "button" (no setting, a button that runs
--                Click()) or "custom" (Build(parent, last, sub) returns the widget the next line goes under;
--                Refresh(sub, on) when the page refreshes; default may be a table). Disabled() returning a text greys
--                a choice / stepper out and shows that text beside it.

local Q = {}
ns.qol = Q
Q.toggles = {}

function Q.AddToggle(toggle)
  assert(toggle.key and toggle.name, "Codex qol: a toggle needs a key and a name")
  if toggle.default == nil then
    toggle.default = true
  end
  toggle.order = toggle.order or 100
  Q.toggles[#Q.toggles + 1] = toggle
  table.sort(Q.toggles, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)
  return toggle
end

function Q.Toggle(key)
  for _, toggle in ipairs(Q.toggles) do
    if toggle.key == key then
      return toggle
    end
  end
  return nil
end

-- An extra switch of a toggle (toggle.options) and its toggle, or nil.
function Q.Option(key)
  for _, toggle in ipairs(Q.toggles) do
    for _, option in ipairs(toggle.options or {}) do
      if option.key == key then
        return option, toggle
      end
    end
  end
  return nil
end

function Q.DB()
  if not Q.db then
    local defaults = {}
    for _, toggle in ipairs(Q.toggles) do
      defaults[toggle.key] = toggle.default
      for _, option in ipairs(toggle.options or {}) do
        if option.kind == "choice" or option.kind == "stepper" or option.kind == "custom" then
          defaults[option.key] = option.default
        elseif option.kind ~= "button" then
          defaults[option.key] = option.default ~= false
        end
      end
    end
    ns.db.qol = ns.Fill(ns.db.qol or {}, defaults)
    Q.db = ns.db.qol
  end
  return Q.db
end

-- Another addon doing this toggle's job (its name), or nil.
function Q.Elsewhere(key)
  local toggle = Q.Toggle(key)
  if not (toggle and toggle.Elsewhere) then
    return nil
  end
  local ok, name = pcall(toggle.Elsewhere)
  return ok and name or nil
end

-- The toggle is wanted and Codex does the job (module running, toggle on, no other addon doing it).
function Q.On(key)
  return Q.running and Q.DB()[key] and not Q.Elsewhere(key) and true or false
end

function Q.Set(key, on)
  local toggle = Q.Toggle(key) or Q.Option(key)
  local value = on and true or false
  if toggle and (toggle.kind == "choice" or toggle.kind == "stepper" or toggle.kind == "custom") then
    value = on -- a choice keeps its value
  end
  Q.DB()[key] = value
  if Q.running and toggle and toggle.Changed then
    toggle.Changed(value)
  end
  if Q.RefreshPage then
    Q.RefreshPage()
  end
end

function Q.Enable()
  Q.DB()
  Q.running = true
  for _, toggle in ipairs(Q.toggles) do
    if toggle.Enable then
      toggle.Enable()
    end
  end
end

function Q.StatusText()
  if not Q.running then
    return "Off."
  end
  local on, total = 0, #Q.toggles
  for _, toggle in ipairs(Q.toggles) do
    if Q.DB()[toggle.key] then
      on = on + 1
    end
  end
  return ("%d of %d option%s on."):format(on, total, total == 1 and "" or "s")
end

ns.RegisterModule({
  id = "qol",
  name = "Quality of life",
  icon = "Interface\\Icons\\INV_Misc_Gear_01",
  desc = "Small conveniences, each with its own switch: faster loot, quest and gathering info in tooltips, "
    .. "zone levels, unexplored areas, dungeons and town services on the map, glowing proc abilities, new spell ranks, numbers on cooldowns and key binding by hovering on your bars, a skull key for your role, a Whisper button for group leaders, and Learn all at trainers.",
  order = 97,
  area = "general",
  sectionOrder = 90,
  folded = true,
  Enable = function()
    Q.Enable()
  end,
  -- its toggles have sections of their own on their pages (Page.lua); this one holds the switch for all of them
  BuildSection = function(_, holder, width, section)
    return Q.BuildSection(holder, width, section)
  end,
  ShowPage = function()
    if Q.RefreshPage then
      Q.RefreshPage()
    end
  end,
  Status = function()
    return Q.StatusText()
  end,
  commands = {
    -- "/codex procglow": what the proc glow sees (the cooldown manager's icons, their spells, lit or not), to
    -- find out in game why an icon doesn't glow
    procglow = function()
      if Q.procglow and Q.procglow.Report then
        Q.procglow.Report()
      end
    end,
  },
})
