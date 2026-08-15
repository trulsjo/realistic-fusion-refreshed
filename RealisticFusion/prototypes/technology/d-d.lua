-- Power's technologies may depend on Core's; the reverse never happens (ADR 0010). This one takes
-- rf-deuterium-extraction because a reactor with no deuterium is scenery.
--
-- The vanilla prerequisites are named for their ingredients rather than their flavour: every item
-- the recipes above use has to be unlockable inside this technology's own prerequisite closure,
-- or a player can research fusion and be unable to build it.
data:extend({
  {
    type = "technology",
    name = "rf-d-d-fusion",
    icon = "__base__/graphics/technology/nuclear-power.png",
    icon_size = 256,
    prerequisites = { "rf-deuterium-extraction", "advanced-circuit", "concrete" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-pipe" },
      { type = "unlock-recipe", recipe = "rf-pipe-to-ground" },
      { type = "unlock-recipe", recipe = "rf-heater" },
      { type = "unlock-recipe", recipe = "rf-reactor" },
      { type = "unlock-recipe", recipe = "rf-heat-exchanger" },
      { type = "unlock-recipe", recipe = "rf-d-d-plasma" },
    },
    unit = {
      count = 500,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 45,
    },
  },
})
