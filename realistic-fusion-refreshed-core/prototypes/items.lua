-- Placement items for Core's machines. Icons are derived from Krastorio 2 (LGPLv3) and live in
-- graphics/krastorio-2/ with the licence and a NOTICE naming every source file -- see the same
-- note at the top of prototypes/fluids.lua.
local ENTITY = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/entities/"

local function item(name, icon, subgroup, order, stack_size)
  return {
    type = "item",
    name = name,
    -- The item icon is the entity's, so the icon in hand is the icon on the map.
    icons = { { icon = icon, icon_size = 64 } },
    subgroup = subgroup,
    order = order,
    place_result = name,
    stack_size = stack_size,
  }
end

data:extend({
  item("rf-electrolyser",       ENTITY .. "electrolyser.png",       "production-machine", "rf-a[electrolyser]",       20),
  item("rf-deuterium-extractor", ENTITY .. "deuterium-extractor.png", "production-machine", "rf-b[deuterium-extractor]", 10),
  item("rf-brine-concentrator", ENTITY .. "brine-concentrator.png", "production-machine", "rf-c[brine-concentrator]", 20),
  item("rf-lithium-extractor",  ENTITY .. "lithium-extractor.png",  "production-machine", "rf-d[lithium-extractor]",  20),
  item("rf-gas-mixer",          ENTITY .. "gas-mixer.png",          "production-machine", "rf-e[gas-mixer]",          20),

  -- The only solid Core produces. Blanket breeding (a later ticket) is what consumes it.
  -- No place_result, so it does not go through item() above.
  {
    type = "item",
    name = "rf-lithium",
    icons = { { icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/items/lithium.png", icon_size = 64 } },
    subgroup = "intermediate-product",
    order = "rf-a[lithium]",
    stack_size = 100,
  },
})
