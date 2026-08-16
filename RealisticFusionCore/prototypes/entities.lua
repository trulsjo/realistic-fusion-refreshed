require("util") -- table.deepcopy

local ENTITY = "__RealisticFusionCore__/graphics/krastorio-2/entities/"

-- Core's machines are built from vanilla ones rather than modelled from scratch.
--
-- ponytail: the deuterium extractor now carries its Krastorio 2 building as well as its icon,
-- because it happened to fit -- five tiles square either way. The three chemical-plant machines
-- still show a chemical plant on the ground. That is not laziness and not a repoint away:
-- Krastorio 2 has exactly one 3x3 building, the fuel refinery, and rf-heater already has it, so
-- telling these three apart means giving each a footprint its art was drawn for -- 5x5 for the
-- electrolyser, 7x7 for the other two -- the way ADR 0013 did for the reactor. That is three
-- decisions about factory layout, not a graphics change. Tracked on #45.
--
-- The base entity is chosen for its fluid box count, which is the part that actually matters:
--   chemical-plant  2 in / 2 out  -> electrolysis, concentration, lithium extraction
--   oil-refinery    2 in / 3 out  -> Girdler sulfide (2 in, 3 out)
-- The enrichment step returns its catalyst, so it genuinely needs the third output.
--
-- Every stat that affects balance is set explicitly rather than inherited. A deep copy taken in
-- data.lua picks up whatever another mod has already done to the source prototype, and mods
-- sorting before this one alphabetically -- Krastorio 2 among them, which ADR 0007 names as a
-- coexistence target -- would silently rewrite all four machines.
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
  -- LGPLv3 and named per machine, because only some of them have one yet; see the note above.
  if opts.pictures then
    e.graphics_set = require("graphics.krastorio-2.buildings." .. opts.pictures)
  end
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
    pictures = "deuterium-extractor-pictures",
  }),
  from_vanilla("chemical-plant", "rf-brine-concentrator", { "rf-concentration" }, {
    crafting_speed = 1, energy_usage = "200kW", icon = "brine-concentrator",
  }),
  from_vanilla("chemical-plant", "rf-lithium-extractor", { "rf-lithium-processing" }, {
    crafting_speed = 1, energy_usage = "300kW", icon = "lithium-extractor",
  }),
})
