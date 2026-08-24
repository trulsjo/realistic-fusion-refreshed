-- An independent Core branch: lithium does not come out of the deuterium chain and does not gate
-- it. Like every Core technology it takes no Power technology as a prerequisite (ADR 0002).
--
-- Ingredients are kept inside the closure of these prerequisites deliberately. The deuterium
-- extractor originally called for concrete, whose technology needs advanced-material-processing,
-- which is outside this closure -- that would have unlocked a machine the player could not build.
data:extend({
  {
    type = "technology",
    name = "rf-lithium-extraction",
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/lithium-extraction.png",
    icon_size = 256,
    prerequisites = { "chemical-science-pack", "fluid-handling" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-brine-concentrator" },
      { type = "unlock-recipe", recipe = "rf-lithium-extractor" },
      { type = "unlock-recipe", recipe = "rf-brine" },
      { type = "unlock-recipe", recipe = "rf-lithium-solution" },
      { type = "unlock-recipe", recipe = "rf-lithium" },
    },
    unit = {
      count = 150,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 30,
    },
  },
})
