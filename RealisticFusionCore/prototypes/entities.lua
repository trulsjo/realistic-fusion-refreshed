require("util") -- table.deepcopy

local ENTITY = "__RealisticFusionCore__/graphics/krastorio-2/entities/"

-- Core's machines are built from vanilla ones rather than modelled from scratch.
--
-- ponytail: the icons are now Krastorio 2's (LGPLv3, graphics/krastorio-2/ with its licence and
-- NOTICE), but the in-world sprites are still the vanilla machine's. So a player sees the right
-- thing in hand, in map view and in alerts, and a chemical plant on the ground. Finishing that
-- is not a repoint like the icons were -- K2's buildings are different sizes and shapes from the
-- vanilla ones these are copied from, so it needs real sprite definitions. Tracked on #45.
--
-- The base entity is chosen for its fluid box count, which is the part that actually matters:
--   chemical-plant  2 in / 2 out  -> electrolysis, concentration, lithium extraction
--   oil-refinery    2 in / 3 out  -> Girdler sulfide (2 in, 3 out)
-- The enrichment step returns its catalyst, so it genuinely needs the third output.
--
-- Every stat that affects balance is set explicitly rather than inherited. A deep copy taken in
-- data.lua picks up whatever another mod has already done to the source prototype, and mods
-- sorting before this one alphabetically -- Krastorio 2 among them, which ADR 0007 names as a
-- coexistence target -- would silently rewrite all four machines. The in-world sprites stay
-- inherited on purpose; those are what is left of the placeholder.
local function from_vanilla(source_name, name, categories, opts)
  local e = table.deepcopy(data.raw["assembling-machine"][source_name])
  e.name = name
  e.minable = { mining_time = 0.2, result = name }
  e.crafting_categories = categories
  e.crafting_speed = opts.crafting_speed
  e.energy_usage = opts.energy_usage
  e.module_slots = 3
  e.allowed_effects = { "consumption", "speed", "productivity", "pollution", "quality" }
  e.icons = { { icon = ENTITY .. opts.icon .. ".png", icon_size = 64 } }
  e.icon = nil
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

data:extend({
  from_vanilla("chemical-plant", "rf-electrolyser", { "rf-electrolysis" }, {
    crafting_speed = 1, energy_usage = "200kW", icon = "electrolyser",
  }),
  from_vanilla("oil-refinery", "rf-deuterium-extractor", { "rf-enrichment" }, {
    crafting_speed = 1, energy_usage = "400kW", icon = "deuterium-extractor",
  }),
  from_vanilla("chemical-plant", "rf-brine-concentrator", { "rf-concentration" }, {
    crafting_speed = 1, energy_usage = "200kW", icon = "brine-concentrator",
  }),
  from_vanilla("chemical-plant", "rf-lithium-extractor", { "rf-lithium-processing" }, {
    crafting_speed = 1, energy_usage = "300kW", icon = "lithium-extractor",
  }),
})
