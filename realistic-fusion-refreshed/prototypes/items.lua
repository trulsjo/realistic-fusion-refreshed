-- Placement items. Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/
-- with the licence and a NOTICE naming every source file -- see the note at the top of
-- prototypes/fluids.lua.
local ENTITY = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/entities/"

-- rf-heat-exchanger's icon is not derived: it is rendered from the machine's own Blender model
-- (#252), so it comes from here instead. Its Krastorio 2 icon is deleted and out of the NOTICE.
local rendered = require("__realistic-fusion-refreshed-assets__.graphics.rendered.pictures")

-- `icon` overrides the derived path. rf-heat-exchanger uses it: its icon is rendered, not derived.
local function item(name, subgroup, order, stack_size, icon)
  return {
    type = "item",
    name = name,
    -- The item icon is the entity's, so the icon in hand is the icon on the map.
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
  item("rf-heat-exchanger",  "energy", "rf-c[heat-exchanger]", 20, rendered.icon("heat-exchanger")),
  -- Next to the exchanger they scale up rather than at the end of the list, because a player
  -- comparing the two sizes is the whole point of the tier (#32).
  item("rf-hc-exchanger",    "energy", "rf-c[heat-exchanger]-b[hc]", 20),
  item("rf-hc-turbine",      "energy", "rf-c[heat-exchanger]-c[hc-turbine]", 20),
  item("rf-isotope-collector", "energy", "rf-d[isotope-collector]", 20),
  item("rf-lithium-blanket",   "energy", "rf-e[lithium-blanket]",   20),
  -- The aneutronic tier (#31). Ordered after the neutronic machines rather than interleaved with
  -- them, so the two routes read as two routes in the crafting menu.
  item("rf-aneutronic-reactor",        "energy", "rf-f[aneutronic-reactor]",        10),
  item("rf-direct-energy-converter",   "energy", "rf-g[direct-energy-converter]",   20),
  item("rf-aneutronic-composite-tank", "energy", "rf-h[aneutronic-composite-tank]", 20),
  item("rf-pipe",            "energy-pipe-distribution", "rf-a[pipe]",           100),
  item("rf-pipe-to-ground",  "energy-pipe-distribution", "rf-b[pipe-to-ground]",  50),
  item("rf-pump",            "energy-pipe-distribution", "rf-c[pump]",            50),
})
