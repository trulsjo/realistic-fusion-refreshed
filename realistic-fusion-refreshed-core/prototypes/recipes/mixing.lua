-- Blending deuterium with a bred fuel into the mix a later reactor tier burns.
--
-- These are Core recipes making Core fluids in a Core machine, and they consume two fluids Core
-- defines but does not produce: tritium and helium-3 come out of a running D-D reactor, which is
-- Power's (#27, ADR 0010). That is the module seam working in the direction it is meant to --
-- nothing here references a reactor, a plasma or a Power technology, and Core loads and is
-- playable on its own with these two recipes simply having no input yet.
--
-- Balance is provisional, as everywhere else. The one number with a reason behind it is the ratio:
-- both mixes are one-to-one, because both reactions burn one nucleus of each side.
data:extend({
  {
    type = "recipe",
    name = "rf-gas-mixer",
    enabled = false,
    energy_required = 4,
    -- Kept inside the closure of the unlocking technology's own prerequisites, the way every other
    -- machine recipe in this module is: see the note in technology/lithium.lua for what that
    -- avoids.
    ingredients = {
      { type = "item", name = "steel-plate",        amount = 15 },
      { type = "item", name = "electronic-circuit", amount = 10 },
      { type = "item", name = "pipe",               amount = 15 },
    },
    results = { { type = "item", name = "rf-gas-mixer", amount = 1 } },
  },

  -- D-T fuel. One deuteron and one triton per reaction, so one of each here.
  {
    type = "recipe",
    name = "rf-d-t-mixing",
    category = "rf-gas-mixing",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "fluid", name = "rf-deuterium", amount = 50 },
      { type = "fluid", name = "rf-tritium",   amount = 50 },
    },
    results = { { type = "fluid", name = "rf-d-t-mix", amount = 100 } },
    main_product = "rf-d-t-mix",
    -- No productivity: a mix is a blend, and a bonus here would conjure tritium, which is the
    -- scarce half of the fuel chain and the thing the whole breeding tier exists to supply.
    allow_productivity = false,
  },

  -- D-He3 fuel, the aneutronic tier's.
  {
    type = "recipe",
    name = "rf-d-he3-mixing",
    category = "rf-gas-mixing",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "fluid", name = "rf-deuterium", amount = 50 },
      { type = "fluid", name = "rf-helium-3",  amount = 50 },
    },
    results = { { type = "fluid", name = "rf-d-he3-mix", amount = 100 } },
    main_product = "rf-d-he3-mix",
    allow_productivity = false,
  },
})
