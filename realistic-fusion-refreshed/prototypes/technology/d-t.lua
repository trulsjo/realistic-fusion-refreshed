-- The two technologies that gate the D-T tier (#28), in the order ADR 0010 lists them:
-- rf-tritium-breeding, then rf-d-t-fusion.
--
-- They gate different things and that is why there are two. Breeding is about getting the tritium
-- out of the reactors that have been making it since the first D-D reactor was built; fusion is
-- about burning it. A player can reach the first and stockpile for a long time before the second.
--
-- rf-blanket-breeding, the lithium route, is the later upgrade and is not either of these.
data:extend({
  -- Capturing what D-D leaves behind.
  --
  -- rf-isotope-collector moved here from rf-d-d-fusion, where #27 put it. It was placed there
  -- because without a collector the by-products go nowhere, and that reasoning was sound while this
  -- technology did not exist -- but with it, the collector is the only thing this technology could
  -- gate, and a technology named "tritium breeding" that unlocks nothing is worse than a tier or so
  -- of reactors venting what they breed. Nothing is lost by waiting: the by-products are computed
  -- either way, so a collector bolted on later starts collecting immediately with no backlog to
  -- catch up on (see control.lua's apply()).
  {
    type = "technology",
    name = "rf-tritium-breeding",
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/tritium-breeding.png",
    icon_size = 256,
    prerequisites = { "rf-d-d-fusion" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-isotope-collector" },
    },
    unit = {
      count = 300,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 45,
    },
  },

  -- Burning it.
  --
  -- Two prerequisites, one per half of the fuel. rf-tritium-breeding supplies the tritium;
  -- rf-gas-mixing is Core's and supplies the machine that blends it with deuterium into
  -- rf-d-t-mix, which is this tier's only ingredient. A Power technology may depend on a Core one
  -- and never the reverse (ADR 0010), so this direction is the allowed one -- and it is the same
  -- closure rule rf-d-d-fusion follows: everything the unlocked recipe consumes has to be reachable
  -- inside this technology's own prerequisites, or a player researches a tier they cannot run.
  --
  -- No machine is unlocked, deliberately: the reactor, the heater, the plasma pipe and the heat
  -- exchanger are all the D-D tier's and are all this tier needs. The science packs are D-D's three
  -- as well rather than a new one, because a pack this repository has not otherwise established is
  -- a progression claim on top of a fuel-chain one. Costs are provisional, like every other balance
  -- number here.
  {
    type = "technology",
    name = "rf-d-t-fusion",
    icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/technologies/d-t.png",
    icon_size = 256,
    prerequisites = { "rf-tritium-breeding", "rf-gas-mixing" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-d-t-plasma" },
      -- The high-capacity steam pair (#32), here rather than behind a technology of its own.
      --
      -- ADR 0010 names seven Power technologies and none of them is a high-capacity one, so an
      -- eighth would extend that list -- a decision about the shape of the tree, and Truls's rather
      -- than a side effect of building the machines. This is also the tier that creates the need:
      -- a D-D reactor sells about 86 MW, which two ordinary exchangers absorb, while an ignited D-T
      -- reactor sells around 320 MW and would otherwise want eight exchangers and fifty-five
      -- turbines. Handing over the answer in the same technology as the problem is the shape a
      -- player can act on.
      --
      -- If they should have their own technology later, moving these two lines is the whole change.
      { type = "unlock-recipe", recipe = "rf-hc-exchanger" },
      { type = "unlock-recipe", recipe = "rf-hc-turbine" },
    },
    unit = {
      count = 600,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 60,
    },
  },
})
