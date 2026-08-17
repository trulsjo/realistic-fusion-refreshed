-- Power's technologies may depend on Core's; the reverse never happens (ADR 0010). This one takes
-- rf-deuterium-extraction because a reactor with no deuterium is scenery.
--
-- The vanilla prerequisites are named for their ingredients rather than their flavour: every item
-- the recipes above use has to be unlockable inside this technology's own prerequisite closure,
-- or a player can research fusion and be unable to build it.
--
-- That invariant has a second half, which this technology failed on review: the chain has to be
-- usable at the far end as well as buildable at the near one. rf-heat-exchanger emits 500 C steam
-- and vanilla unlocks the only thing that drinks it -- steam-turbine -- from nuclear-power, behind
-- uranium processing. So a player could research fusion, build the whole chain, and have nowhere
-- to put the steam. The turbine is therefore unlocked here.
--
-- Two consequences, both deliberate. Unlocking a recipe a vanilla technology also unlocks is
-- harmless -- researching nuclear-power later simply unlocks it again. But it does put the turbine
-- in a player's hands before nuclear power, where an ordinary boiler can drive it; that is a
-- change to vanilla progression, small and stated rather than smuggled. Making nuclear-power a
-- prerequisite instead would avoid it and gate fusion behind fission, which is a far bigger claim
-- about this mod than a recipe unlock is.
data:extend({
  {
    type = "technology",
    name = "rf-d-d-fusion",
    icon = "__RealisticFusion__/graphics/krastorio-2/technologies/d-d.png",
    icon_size = 256,
    prerequisites = { "rf-deuterium-extraction", "advanced-circuit", "concrete" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-pipe" },
      { type = "unlock-recipe", recipe = "rf-pipe-to-ground" },
      { type = "unlock-recipe", recipe = "rf-pump" },
      { type = "unlock-recipe", recipe = "rf-heater" },
      { type = "unlock-recipe", recipe = "rf-reactor" },
      { type = "unlock-recipe", recipe = "rf-heat-exchanger" },
      { type = "unlock-recipe", recipe = "rf-d-d-plasma" },
      -- Vanilla's, not ours: see above. #32's rf-hc-turbine replaces it at the high-capacity tier.
      { type = "unlock-recipe", recipe = "steam-turbine" },
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
