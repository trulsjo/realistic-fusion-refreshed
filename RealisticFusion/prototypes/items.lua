-- Placement items. Icons are the vanilla machines these are built from, tinted, for the same
-- reason as Core's: no assets ship, so the art decision stays open.
local PLASMA_TINT = { r = 1.00, g = 0.55, b = 0.30 }
local ENERGY_TINT = { r = 1.00, g = 0.90, b = 0.45 }

local function item(name, icon, tint, subgroup, order, stack_size)
  return {
    type = "item",
    name = name,
    icons = { { icon = icon, icon_size = 64, tint = tint } },
    subgroup = subgroup,
    order = order,
    place_result = name,
    stack_size = stack_size,
  }
end

data:extend({
  item("rf-heater", "__base__/graphics/icons/chemical-plant.png", PLASMA_TINT,
    "energy", "rf-a[heater]", 20),
  item("rf-reactor", "__base__/graphics/icons/nuclear-reactor.png", PLASMA_TINT,
    "energy", "rf-b[reactor]", 10),
  -- heat-boiler, not heat-exchanger: the entity was renamed in vanilla and the icon file was not.
  item("rf-heat-exchanger", "__base__/graphics/icons/heat-boiler.png", ENERGY_TINT,
    "energy", "rf-c[heat-exchanger]", 20),
  item("rf-pipe", "__base__/graphics/icons/pipe.png", PLASMA_TINT,
    "energy-pipe-distribution", "rf-a[pipe]", 100),
  item("rf-pipe-to-ground", "__base__/graphics/icons/pipe-to-ground.png", PLASMA_TINT,
    "energy-pipe-distribution", "rf-b[pipe-to-ground]", 50),
})
