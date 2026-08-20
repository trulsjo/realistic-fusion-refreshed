-- Blanket breeding (#30). One recipe, because the tier adds one machine and no chemistry.
--
-- The blanket itself is the only thing built here. What it consumes -- rf-lithium -- comes out of
-- Core's brine chain, which rf-lithium-extraction already unlocks, and what it produces leaves
-- through the isotope collector rf-tritium-breeding already unlocked. So this tier is a fitting
-- bolted to machines a player has, fed by a chain a player has, and that is deliberate: the step
-- up is in what the reactors then do rather than in another building to lay out.
data:extend({
  -- Steel and pipe for the shell, advanced circuits for the instrumentation a neutron-facing
  -- structure needs. Dearer than the isotope collector because it is the later tier and sits in a
  -- harder place -- inside the neutron flux rather than beside it.
  --
  -- ADVANCED CIRCUITS RATHER THAN PROCESSING UNITS, and that is a correctness fix rather than a
  -- taste one. Every ingredient has to sit inside the closure of the unlocking technology's
  -- prerequisites (technology/d-d.lua says why), and processing-unit is not in this one's: nothing
  -- on the chain from rf-d-t-fusion, rf-tritium-breeding or rf-lithium-extraction reaches vanilla's
  -- processing-unit technology. A player would have researched blanket breeding and then been
  -- unable to build a blanket. Naming processing-unit as a fourth prerequisite would have fixed it
  -- too and was not taken: it is a progression claim this repository has not otherwise made, and
  -- advanced-circuit is what every other recipe here is built from.
  --
  -- No lithium in the recipe, which is worth saying because it looks like an omission. The lithium
  -- a blanket holds is what it consumes while running, and putting some in the build cost as well
  -- would charge for the same thing twice and make an empty blanket look like a loaded one.
  -- Balance is provisional, like everything else here.
  {
    type = "recipe",
    name = "rf-lithium-blanket",
    enabled = false,
    energy_required = 8,
    ingredients = {
      { type = "item", name = "steel-plate",      amount = 40 },
      { type = "item", name = "advanced-circuit", amount = 30 },
      { type = "item", name = "pipe",             amount = 20 },
    },
    results = { { type = "item", name = "rf-lithium-blanket", amount = 1 } },
  },
})
