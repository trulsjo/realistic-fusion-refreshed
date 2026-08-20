-- The aneutronic tier (#31): the machines, and the two plasmas they burn.
--
-- Three machines rather than the D-T tier's none, and that is the difference between the two steps.
-- D-T was a fuel a player already had, burnt in the reactor they already owned. This is a second
-- reactor, a conversion route that is not a steam loop, and somewhere to buffer what runs between
-- them (ADR 0010's chain, steps 5 and 6).
--
-- Balance is provisional, like every other number in this repository. What is not free is the
-- plasma rate: 5 units in 2 seconds is what rf-d-d-plasma and rf-d-t-plasma already run at, and it
-- is kept so that one heater still means one heater's worth of fuel however far down the chain a
-- player is. A faster recipe here would hide the tier's step up inside a machine stat.
data:extend({
  -- Every ingredient below is reachable inside rf-aneutronic-fusion's own prerequisite closure --
  -- see technology/aneutronic.lua, which names processing-unit as a prerequisite for exactly this
  -- reason. #30 shipped a recipe that broke that rule and scripts/check-blanket.ps1 now enforces it.
  {
    type = "recipe",
    name = "rf-aneutronic-reactor",
    enabled = false,
    energy_required = 60,
    ingredients = {
      { type = "item", name = "steel-plate",     amount = 400 },
      { type = "item", name = "processing-unit", amount = 200 },
      { type = "item", name = "concrete",        amount = 400 },
      { type = "item", name = "rf-pipe",         amount = 100 },
    },
    results = { { type = "item", name = "rf-aneutronic-reactor", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-direct-energy-converter",
    enabled = false,
    energy_required = 20,
    ingredients = {
      { type = "item", name = "steel-plate",     amount = 100 },
      { type = "item", name = "processing-unit", amount = 50 },
      { type = "item", name = "copper-plate",    amount = 200 },
      { type = "item", name = "pipe",            amount = 20 },
    },
    results = { { type = "item", name = "rf-direct-energy-converter", amount = 1 } },
  },
  -- Cheap, because it is a tank. Pricing storage like a machine puts a toll on running the tier
  -- smoothly, which is the one thing this exists to allow.
  {
    type = "recipe",
    name = "rf-aneutronic-composite-tank",
    enabled = false,
    energy_required = 8,
    ingredients = {
      { type = "item", name = "steel-plate", amount = 40 },
      { type = "item", name = "pipe",        amount = 20 },
    },
    results = { { type = "item", name = "rf-aneutronic-composite-tank", amount = 1 } },
  },

  -- The D-He3 mix into plasma. Core blends rf-deuterium with rf-helium-3 into rf-d-he3-mix in a
  -- gas mixer (rf-d-he3-mixing, unlocked by Core's rf-gas-mixing) and has done since that
  -- technology shipped -- this is the first thing that consumes it.
  {
    type = "recipe",
    name = "rf-d-he3-plasma",
    category = "rf-plasma-heating",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-d-he3-mix", amount = 5 } },
    results = { { type = "fluid", name = "rf-d-he3-plasma", amount = 5, temperature = 1e6 } },
    main_product = "rf-d-he3-plasma",
    -- No productivity, for the reason every plasma recipe gives: plasma is energy, and a bonus
    -- here would conjure it -- along with the helium-3 that the whole D-D tier exists to breed.
    allow_productivity = false,
  },

  -- Helium-3 into plasma, with no mixing step at all, and that is the reaction rather than a
  -- shortcut: He3-He3 burns one fuel against itself, so there is no second species to blend in.
  -- It is the only plasma in the mod made from a bare Core fluid.
  {
    type = "recipe",
    name = "rf-he3-he3-plasma",
    category = "rf-plasma-heating",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-helium-3", amount = 5 } },
    results = { { type = "fluid", name = "rf-he3-he3-plasma", amount = 5, temperature = 1e6 } },
    main_product = "rf-he3-he3-plasma",
    allow_productivity = false,
  },
})
