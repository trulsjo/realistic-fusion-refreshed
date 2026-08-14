data:extend({
  -- Electrolysis: water to hydrogen, heavy water to deuterium.
  { type = "recipe-category", name = "rf-electrolysis" },
  -- The Girdler sulfide process. Its own category so the enrichment step cannot be run in a
  -- vanilla chemical plant, and so Power can never gain access to it by accident.
  { type = "recipe-category", name = "rf-enrichment" },
})
