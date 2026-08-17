-- The three technologies that gate the aneutronic tier (#31), in the order ADR 0010 lists them:
-- rf-helium-3-breeding, then rf-direct-energy-conversion, then rf-aneutronic-fusion.
--
-- WHAT EACH ONE IS FOR, because the split is not obvious and one of the three needed a role
-- inventing rather than inherited.
--
-- rf-helium-3-breeding is the odd one. In the 1.1 original it unlocked a suppressed D-D reactor
-- variant that traded power for helium-3 -- a mechanic that does not exist here, because this mod's
-- reactors breed both by-products from the same reaction count that produces their energy and there
-- is nothing to suppress (ADR 0005, #27). So helium-3 is already coming out of every D-D reactor
-- with a collector on it long before this technology, and a technology named for breeding it cannot
-- gate the breeding.
--
-- What it gates instead is the point at which helium-3 stops being a by-product and starts being a
-- fuel stock: the vessel you keep enough of it in to run something on. That is a real step in a
-- player's factory and it is where the tank belongs. Recorded here rather than left as a puzzle,
-- because the alternative -- dropping the technology and folding the tank into the next one -- is a
-- change to ADR 0010's named set and is Truls's to make rather than a side effect of this ticket.
--
-- rf-direct-energy-conversion comes BEFORE the reactor that needs it, which reads backwards and is
-- deliberate. It leaves a player with a converter and nothing to feed it, exactly the way Core's
-- rf-gas-mixing leaves them a mixer with nothing to mix -- "the thing you have ready for when the
-- reactors start paying out". The alternative is a reactor whose output fluid nothing in the game
-- can drink, which is the worse of the two: an unusable machine is a bug report, an early machine
-- is a plan.
--
-- rf-aneutronic-fusion is the tier proper, and unlocks both reactions at once. ADR 0010 names three
-- technologies for four reactions, so D-He3 and He3-He3 share one; they share a reactor, a
-- converter and a fuel, so there is little left for a fourth to gate.
data:extend({
  -- Stockpiling what the D-D reactors have been breeding all along.
  {
    type = "technology",
    name = "rf-helium-3-breeding",
    icon = "__RealisticFusion__/graphics/krastorio-2/technologies/helium-3-breeding.png",
    icon_size = 256,
    -- rf-tritium-breeding, because that is what unlocks the collector -- there is no helium-3 in a
    -- pipe anywhere until a player has one, so gating storage behind it is the honest order.
    prerequisites = { "rf-tritium-breeding" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-aneutronic-composite-tank" },
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

  -- Electricity without a steam loop.
  --
  -- processing-unit is a prerequisite for its ingredients rather than its flavour, which is the
  -- same rule rf-d-d-fusion follows with advanced-circuit and concrete: everything the unlocked
  -- recipe consumes has to be reachable inside this technology's own prerequisites, or a player
  -- researches a tier and cannot build it. #30 broke that rule and scripts/check-blanket.ps1
  -- enforces it now.
  {
    type = "technology",
    name = "rf-direct-energy-conversion",
    icon = "__RealisticFusion__/graphics/krastorio-2/technologies/direct-energy-conversion.png",
    icon_size = 256,
    prerequisites = { "rf-helium-3-breeding", "processing-unit" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-direct-energy-converter" },
    },
    unit = {
      count = 800,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
        { "production-science-pack", 1 },
      },
      time = 60,
    },
  },

  -- The tier itself: the reactor and both aneutronic plasmas.
  --
  -- Three prerequisites, one per thing the tier needs to exist. rf-direct-energy-conversion is
  -- where the output goes and carries processing-unit for the reactor's own recipe;
  -- rf-gas-mixing is Core's and supplies rf-d-he3-mix, which is half the fuel; rf-d-t-fusion is the
  -- tier this one follows, and is what makes the progression a line rather than two branches a
  -- player picks between. A Power technology may depend on a Core one and never the reverse
  -- (ADR 0010), so the rf-gas-mixing edge is the allowed direction.
  --
  -- The production science pack appears here and on the technology above, and it is the first time
  -- this repository asks for a fourth pack. That is a progression claim and it is made deliberately
  -- at the last tier rather than smuggled in earlier: everything up to and including D-T runs on
  -- the same three packs the D-D tier established.
  {
    type = "technology",
    name = "rf-aneutronic-fusion",
    icon = "__RealisticFusion__/graphics/krastorio-2/technologies/aneutronic-fusion.png",
    icon_size = 256,
    prerequisites = { "rf-direct-energy-conversion", "rf-d-t-fusion", "rf-gas-mixing" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-aneutronic-reactor" },
      { type = "unlock-recipe", recipe = "rf-d-he3-plasma" },
      { type = "unlock-recipe", recipe = "rf-he3-he3-plasma" },
    },
    unit = {
      count = 1500,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
        { "production-science-pack", 1 },
      },
      time = 60,
    },
  },
})
