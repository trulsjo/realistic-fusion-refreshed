require("util") -- table.deepcopy

-- Core's machines are built from vanilla ones rather than modelled from scratch.
--
-- ponytail: this ships no graphics, no sounds and no remnants of our own, so the art decision
-- ADR 0010 left open stays open, and the entities are fully working rather than invisible.
-- The base entity is chosen for its fluid box count, which is the part that actually matters:
--   chemical-plant  2 in / 2 out  -> electrolysis, concentration, lithium extraction
--   oil-refinery    2 in / 3 out  -> Girdler sulfide (2 in, 3 out)
-- The enrichment step returns its catalyst, so it genuinely needs the third output.
--
-- Every stat that affects balance is set explicitly rather than inherited. A deep copy taken in
-- data.lua picks up whatever another mod has already done to the source prototype, and mods
-- sorting before this one alphabetically -- Krastorio 2 among them, which ADR 0007 names as a
-- coexistence target -- would silently rewrite all four machines. Graphics stay inherited on
-- purpose; those are the placeholder.
local function from_vanilla(source_name, name, categories, opts)
  local e = table.deepcopy(data.raw["assembling-machine"][source_name])
  e.name = name
  e.minable = { mining_time = 0.2, result = name }
  e.crafting_categories = categories
  e.crafting_speed = opts.crafting_speed
  e.energy_usage = opts.energy_usage
  e.module_slots = 3
  e.allowed_effects = { "consumption", "speed", "productivity", "pollution", "quality" }
  -- Tinted so the machines are distinguishable in map view, alt-mode and alerts. The in-world
  -- sprites are still identical copies of the vanilla machine; that is a placeholder limitation,
  -- not an oversight, and it goes away when real art arrives.
  e.icons = { { icon = opts.icon, icon_size = 64, tint = opts.tint } }
  e.icon = nil
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

local CHEMICAL_PLANT = "__base__/graphics/icons/chemical-plant.png"
local OIL_REFINERY   = "__base__/graphics/icons/oil-refinery.png"

data:extend({
  from_vanilla("chemical-plant", "rf-electrolyser", { "rf-electrolysis" }, {
    crafting_speed = 1, energy_usage = "200kW",
    icon = CHEMICAL_PLANT, tint = { r = 0.70, g = 0.85, b = 1.00 },
  }),
  from_vanilla("oil-refinery", "rf-deuterium-extractor", { "rf-enrichment" }, {
    crafting_speed = 1, energy_usage = "400kW",
    icon = OIL_REFINERY, tint = { r = 0.55, g = 0.75, b = 1.00 },
  }),
  from_vanilla("chemical-plant", "rf-brine-concentrator", { "rf-concentration" }, {
    crafting_speed = 1, energy_usage = "200kW",
    icon = CHEMICAL_PLANT, tint = { r = 0.75, g = 0.85, b = 0.65 },
  }),
  from_vanilla("chemical-plant", "rf-lithium-extractor", { "rf-lithium-processing" }, {
    crafting_speed = 1, energy_usage = "300kW",
    icon = CHEMICAL_PLANT, tint = { r = 0.90, g = 0.80, b = 0.92 },
  }),
})
