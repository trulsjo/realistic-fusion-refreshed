-- rf-blanket-breeding (#30): the later of the two breeding routes CONTEXT.md names.
--
-- Three prerequisites, and each of them is something the technology genuinely cannot work without
-- rather than a tree shape chosen for looks. This is the same closure rule rf-d-t-fusion follows:
-- everything the unlocked machine needs has to be reachable inside this technology's own
-- prerequisites, or a player researches a tier they cannot run.
--
--   rf-d-t-fusion          the reactor worth blanketing. A blanket works on a D-D reactor too --
--                          reactor-logic gives D-D a neutron on half its reactions -- but at half
--                          the neutrons per reaction, and with the D-D reactors already breeding
--                          tritium as a by-product, the blanket is not what that tier is short of.
--                          D-T is: it burns tritium and breeds none.
--   rf-tritium-breeding    the isotope collector, which is how bred tritium actually leaves. A
--                          blanket without one spends lithium into nothing. It is already implied
--                          through rf-d-t-fusion, and is named anyway so the dependency is
--                          visible rather than inherited.
--   rf-lithium-extraction  Core's, and the only source of what the blanket eats. A Power
--                          technology may depend on a Core one and never the reverse (ADR 0010).
--
-- The ordering the ticket asks for falls out of the first two: this cannot be reached before the
-- D-D by-product route, because the by-product route is upstream of D-T fusion which is upstream
-- of here.
--
-- Costs are provisional, like every other balance number in this repository. The science packs are
-- the same three the tiers below use rather than a new one, for the reason rf-d-t-fusion gives.
data:extend({
  {
    type = "technology",
    name = "rf-blanket-breeding",
    icon = "__RealisticFusion__/graphics/krastorio-2/technologies/blanket-breeding.png",
    icon_size = 256,
    prerequisites = { "rf-d-t-fusion", "rf-tritium-breeding", "rf-lithium-extraction" },
    effects = {
      { type = "unlock-recipe", recipe = "rf-lithium-blanket" },
    },
    unit = {
      count = 900,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack",   1 },
        { "chemical-science-pack",   1 },
      },
      time = 60,
    },
  },
})
