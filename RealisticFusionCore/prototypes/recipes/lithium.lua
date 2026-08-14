-- Water to lithium. Balance is provisional, like the deuterium chain.
--
-- The whole point of this branch is what it does NOT contain: no resource prototype, no autoplace,
-- no map entity of any kind. Brine is produced from ordinary water, so a player who adds this mod
-- to a running game reaches lithium without exploring a single new chunk. ADR 0010 chose this over
-- the redesign's intent, which was brine as "a completely new resource similar to oil" -- that
-- would only generate in unexplored chunks and strand exactly those players.
data:extend({
  {
    type = "recipe",
    name = "rf-brine-concentrator",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "item", name = "steel-plate",        amount = 10 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "pipe",               amount = 10 },
    },
    results = { { type = "item", name = "rf-brine-concentrator", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-lithium-extractor",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "item", name = "steel-plate",      amount = 15 },
      { type = "item", name = "advanced-circuit", amount = 5 },
      { type = "item", name = "pipe",             amount = 10 },
    },
    results = { { type = "item", name = "rf-lithium-extractor", amount = 1 } },
  },

  -- Water concentrated into brine. Most of the water leaves as vapour rather than as a second
  -- fluid: there is no depleted stream here to dispose of, so no sink is needed.
  {
    type = "recipe",
    name = "rf-brine",
    category = "rf-concentration",
    enabled = false,
    energy_required = 3,
    ingredients = { { type = "fluid", name = "water", amount = 100 } },
    results = { { type = "fluid", name = "rf-brine", amount = 20 } },
  },

  -- Brine concentrated further into a lithium-bearing solution.
  {
    type = "recipe",
    name = "rf-lithium-solution",
    category = "rf-concentration",
    enabled = false,
    energy_required = 4,
    ingredients = { { type = "fluid", name = "rf-brine", amount = 100 } },
    results = { { type = "fluid", name = "rf-lithium-solution", amount = 25 } },
  },

  -- Solid lithium, the input blanket breeding will consume.
  {
    type = "recipe",
    name = "rf-lithium",
    category = "rf-lithium-processing",
    enabled = false,
    energy_required = 6,
    ingredients = { { type = "fluid", name = "rf-lithium-solution", amount = 50 } },
    results = { { type = "item", name = "rf-lithium", amount = 1 } },
  },
})
