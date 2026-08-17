-- Gas mixing: the machine that turns bred fuel into reactor fuel.
--
-- Like every Core technology this takes no Power technology as a prerequisite (ADR 0002, ADR 0010).
-- It takes rf-deuterium-extraction because deuterium is half of both mixes and there is no point
-- owning a mixer before the chain can make one of its two inputs.
--
-- The other input is the half Core cannot make. Researching this leaves a player with a buildable
-- machine and two recipes that will not run until a D-D reactor is breeding tritium, and that is
-- the intended shape rather than an oversight: the mixer is the thing you have ready for when the
-- reactors start paying out. The progression gate proper is Power's rf-tritium-breeding (#28),
-- which is what makes the D-T tier reachable; this only puts the mixer on the shelf.
data:extend({
  {
    type = "technology",
    name = "rf-gas-mixing",
    icon = "__RealisticFusionCore__/graphics/krastorio-2/technologies/gas-mixing.png",
    icon_size = 256,
    prerequisites = { "rf-deuterium-extraction" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-gas-mixer" },
      { type = "unlock-recipe", recipe = "rf-d-t-mixing" },
      { type = "unlock-recipe", recipe = "rf-d-he3-mixing" },
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
