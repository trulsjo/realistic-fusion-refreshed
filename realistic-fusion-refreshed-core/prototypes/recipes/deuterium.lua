-- The water-to-deuterium chain. Balance is provisional: ratios, times and energy values are
-- out of scope on the map and get established by playtesting against a build.
data:extend({
  -- The machines themselves.
  {
    type = "recipe",
    name = "rf-electrolyser",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "item", name = "steel-plate",       amount = 10 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "pipe",              amount = 10 },
    },
    results = { { type = "item", name = "rf-electrolyser", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-deuterium-extractor",
    enabled = false,
    energy_required = 8,
    -- No concrete: it is unlocked by the "concrete" technology, which requires
    -- advanced-material-processing -- outside the closure of this recipe's own unlocking
    -- technology. (automation-2 is inside it, via fluid-handling.) A player rushing chemical
    -- science could otherwise unlock a machine they cannot build.
    ingredients = {
      { type = "item", name = "steel-plate",        amount = 20 },
      { type = "item", name = "advanced-circuit",   amount = 10 },
      { type = "item", name = "pipe",               amount = 30 },
    },
    results = { { type = "item", name = "rf-deuterium-extractor", amount = 1 } },
  },

  -- Water to hydrogen. Oxygen is not modelled: ADR 0010 fixes Core's fluid set and there is no
  -- oxygen in it, so it is vented rather than invented.
  {
    type = "recipe",
    name = "rf-hydrogen-from-water",
    category = "rf-electrolysis",
    enabled = false,
    energy_required = 1,
    ingredients = { { type = "fluid", name = "water", amount = 100 } },
    results = { { type = "fluid", name = "rf-hydrogen", amount = 100 } },
    main_product = "rf-hydrogen",
  },

  -- The catalyst is made once and then recirculates; this recipe exists to charge the loop and
  -- to top it up. Vanilla chemistry, so no Core machine is needed to bootstrap the chain.
  {
    type = "recipe",
    name = "rf-hydrogen-sulfide",
    category = "chemistry",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "fluid", name = "rf-hydrogen", amount = 100 },
      { type = "item",  name = "sulfur",      amount = 1 },
    },
    results = { { type = "fluid", name = "rf-hydrogen-sulfide", amount = 100 } },
  },

  -- The Girdler sulfide process. Hydrogen sulfide comes out in exactly the amount that went in,
  -- which is what makes it a catalyst rather than a reagent: the loop needs charging once and
  -- then sustains itself. Most of the water leaves as the depleted stream.
  {
    type = "recipe",
    name = "rf-heavy-water",
    category = "rf-enrichment",
    enabled = false,
    energy_required = 4,
    ingredients = {
      { type = "fluid", name = "water",               amount = 100 },
      -- ignored_by_stats on both sides: the catalyst is not net-produced or net-consumed, so
      -- counting it would inflate both columns of the production graph by the whole recirculating
      -- volume and hide a genuine leak. Vanilla marks kovarex exactly this way.
      { type = "fluid", name = "rf-hydrogen-sulfide", amount = 50, ignored_by_stats = 50 },
    },
    results = {
      { type = "fluid", name = "rf-heavy-water",       amount = 10 },
      { type = "fluid", name = "rf-depleted-water",    amount = 90 },
      -- ignored_by_productivity as well: allow_productivity is false today, but if balancing
      -- ever flips it, productivity modules would otherwise create catalyst out of nothing.
      { type = "fluid", name = "rf-hydrogen-sulfide",  amount = 50,
        ignored_by_stats = 50, ignored_by_productivity = 50 },
    },
    main_product = "rf-heavy-water",
  },

  -- The depleted stream has to go somewhere. Base 2.0 has no fluid void and no vanilla recipe can
  -- consume a modded fluid, so without this the enrichment machine fills its output box after a
  -- single craft and stalls. The stall lifts if the box is drained, but there is nowhere to drain
  -- it to except more tanks, so in practice the chain backs up before producing meaningful
  -- deuterium -- and each stall strands the hydrogen sulfide charge, which is taken at craft start
  -- and only returned on completion.
  --
  -- Depleted water is still water, just stripped of deuterium, so returning it costs time and
  -- energy rather than material. This is not an infinite water source: the enrichment step takes
  -- 100 water and returns 90, so the loop is lossy by exactly the heavy water drawn off.
  {
    type = "recipe",
    name = "rf-depleted-water-recycling",
    category = "chemistry",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-depleted-water", amount = 100 } },
    results = { { type = "fluid", name = "water", amount = 100 } },
  },

  -- Heavy water to deuterium, the input the whole power side consumes.
  {
    type = "recipe",
    name = "rf-deuterium",
    category = "rf-electrolysis",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-heavy-water", amount = 100 } },
    results = { { type = "fluid", name = "rf-deuterium", amount = 100 } },
    main_product = "rf-deuterium",
  },
})
