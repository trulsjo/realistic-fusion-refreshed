-- Placement items. Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/
-- with the licence and a NOTICE naming every source file -- see the note at the top of
-- prototypes/fluids.lua.
local ENTITY = "__RealisticFusion__/graphics/krastorio-2/entities/"

local function item(name, subgroup, order, stack_size, icon)
  return {
    type = "item",
    name = name,
    -- The item icon is the entity's, so the icon in hand is the icon on the map. `icon` overrides
    -- that for the one machine with no Krastorio 2 art to derive a path from; see entities.lua.
    icons = { { icon = icon or (ENTITY .. name:gsub("^rf%-", "") .. ".png"), icon_size = 64 } },
    subgroup = subgroup,
    order = order,
    place_result = name,
    stack_size = stack_size,
  }
end

data:extend({
  item("rf-heater",          "energy", "rf-a[heater]",         20),
  item("rf-reactor",         "energy", "rf-b[reactor]",        10),
  item("rf-heat-exchanger",  "energy", "rf-c[heat-exchanger]", 20),
  item("rf-isotope-collector", "energy", "rf-d[isotope-collector]", 20),
  item("rf-lithium-blanket",   "energy", "rf-e[lithium-blanket]",   20),
  item("rf-pipe",            "energy-pipe-distribution", "rf-a[pipe]",           100),
  item("rf-pipe-to-ground",  "energy-pipe-distribution", "rf-b[pipe-to-ground]",  50),
  item("rf-pump",            "energy-pipe-distribution", "rf-c[pump]",            50,
       "__base__/graphics/icons/pump.png"),
})
