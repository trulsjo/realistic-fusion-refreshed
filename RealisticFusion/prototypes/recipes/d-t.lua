-- The D-T tier (#28). One recipe, because the tier adds no machine.
--
-- That is the point of it rather than an omission. D-T runs in the reactor the D-D tier already
-- built, through the pipes it already laid, into the heat exchanger it already fed -- ADR 0010 names
-- a single rf-reactor for both, and prototypes/entities.lua leaves its input box unfiltered so it
-- burns whichever plasma reaches it. What a player builds to reach this tier is not another
-- building; it is a tritium supply, which is what the last tier's reactors have been accumulating.
data:extend({
  -- The mix into plasma, in the same heater and at the same rate as D-D, so one heater still feeds
  -- one reactor. Everything about the step is the same -- ionised and injected far below fusion
  -- temperature -- and the difference between the tiers is entirely in what the reactor then does
  -- with it.
  --
  -- 5 units in 2 seconds is D-D's rate, deliberately unchanged: a heater is a heater, and making
  -- this one faster would hide the tier's actual step up inside a machine stat. Fed at that rate a
  -- D-T reactor settles around 320 MW against a D-D reactor's 86 -- see docs/research/d-t-ignition.md.
  {
    type = "recipe",
    name = "rf-d-t-plasma",
    category = "rf-plasma-heating",
    enabled = false,
    energy_required = 2,
    ingredients = { { type = "fluid", name = "rf-d-t-mix", amount = 5 } },
    results = { { type = "fluid", name = "rf-d-t-plasma", amount = 5, temperature = 1e6 } },
    main_product = "rf-d-t-plasma",
    -- No productivity, for the reason rf-d-d-plasma gives: plasma is energy, and a bonus here would
    -- conjure it. Worse on this tier than the last, since it would conjure tritium with it.
    allow_productivity = false,
  },
})
