-- Core's technologies unlock extraction and nothing else. None of them takes a Power technology
-- as a prerequisite -- that direction is the explicit inversion of the port's tree, where every
-- tier of the deuterium chain was gated on a fusion milestone and Core would have had to depend
-- on Power (ADR 0002, ADR 0010).
--
-- Research costs are provisional, like the recipe balance.
data:extend({
  {
    type = "technology",
    name = "rf-heavy-water",
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/heavy-water.png",
    icon_size = 256,
    prerequisites = { "chemical-science-pack", "fluid-handling" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-electrolyser" },
      { type = "unlock-recipe", recipe = "rf-deuterium-extractor" },
      { type = "unlock-recipe", recipe = "rf-hydrogen-from-water" },
      { type = "unlock-recipe", recipe = "rf-hydrogen-sulfide" },
      { type = "unlock-recipe", recipe = "rf-heavy-water" },
      -- Unlocked with the step that produces it: without a sink for the depleted stream the
      -- enrichment machine stalls after one craft.
      { type = "unlock-recipe", recipe = "rf-depleted-water-recycling" },
    },
    unit = {
      count = 100,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 30,
    },
  },
  {
    type = "technology",
    name = "rf-deuterium-extraction",
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/deuterium-extraction.png",
    icon_size = 256,
    prerequisites = { "rf-heavy-water" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-deuterium" },
    },
    unit = {
      count = 200,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 30,
    },
  },
})
