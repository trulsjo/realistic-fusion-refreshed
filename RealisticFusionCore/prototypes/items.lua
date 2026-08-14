-- Placement items for Core's machines. Icons are the vanilla machines these are built from,
-- for the same reason as the fluid icons: no assets ship, so the art decision stays open.
data:extend({
  {
    type = "item",
    name = "rf-electrolyser",
    icon = "__base__/graphics/icons/chemical-plant.png",
    icon_size = 64,
    subgroup = "production-machine",
    order = "rf-a[electrolyser]",
    place_result = "rf-electrolyser",
    stack_size = 20,
  },
  {
    type = "item",
    name = "rf-deuterium-extractor",
    icon = "__base__/graphics/icons/oil-refinery.png",
    icon_size = 64,
    subgroup = "production-machine",
    order = "rf-b[deuterium-extractor]",
    place_result = "rf-deuterium-extractor",
    stack_size = 10,
  },
})
