-- The D-D tier. Balance is provisional, as everywhere else in this repository: the chain has to
-- work, not to be tuned. The one number here that is not free is the plasma rate -- see below.
data:extend({
  -- The machines themselves.
  {
    type = "recipe",
    name = "rf-heater",
    enabled = false,
    energy_required = 6,
    ingredients = {
      { type = "item", name = "steel-plate",     amount = 20 },
      { type = "item", name = "advanced-circuit", amount = 10 },
      { type = "item", name = "pipe",            amount = 20 },
    },
    results = { { type = "item", name = "rf-heater", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-reactor",
    enabled = false,
    energy_required = 30,
    ingredients = {
      { type = "item", name = "steel-plate",     amount = 200 },
      { type = "item", name = "advanced-circuit", amount = 100 },
      { type = "item", name = "concrete",        amount = 200 },
      { type = "item", name = "rf-pipe",         amount = 50 },
    },
    results = { { type = "item", name = "rf-reactor", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-heat-exchanger",
    enabled = false,
    energy_required = 8,
    ingredients = {
      { type = "item", name = "steel-plate",     amount = 50 },
      { type = "item", name = "advanced-circuit", amount = 20 },
      { type = "item", name = "pipe",            amount = 20 },
    },
    results = { { type = "item", name = "rf-heat-exchanger", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-pipe",
    enabled = false,
    energy_required = 0.5,
    ingredients = { { type = "item", name = "steel-plate", amount = 1 } },
    results = { { type = "item", name = "rf-pipe", amount = 1 } },
  },
  {
    type = "recipe",
    name = "rf-pipe-to-ground",
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "rf-pipe",     amount = 8 },
      { type = "item", name = "steel-plate", amount = 5 },
    },
    results = { { type = "item", name = "rf-pipe-to-ground", amount = 2 } },
  },

  -- Deuterium into plasma: ionised and injected, not yet fusing. The reactor's confinement
  -- heating does the rest, which is why this step is an ordinary recipe and the reactor is not.
  --
  -- 2.5 plasma per second is the rate one heater sustains, and it is roughly what one reactor at
  -- its shipped settling point burns -- so a heater feeds a reactor, and a Girdler sulfide
  -- machine in Core feeds a heater. That alignment is deliberate; the rest of the numbers are not.
  {
    type = "recipe",
    name = "rf-d-d-plasma",
    category = "rf-plasma-heating",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-deuterium", amount = 5 } },
    -- Injected hot enough to be a plasma and nowhere near hot enough to fuse. Fuelling a running
    -- reactor therefore cools it slightly, which is what fuelling a real plasma does.
    results = { { type = "fluid", name = "rf-d-d-plasma", amount = 5, temperature = 1e6 } },
    main_product = "rf-d-d-plasma",
    allow_productivity = false,
  },
})
