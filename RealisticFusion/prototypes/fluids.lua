-- Power's own fluids. Core owns everything the extraction chain produces; the plasmas and the
-- energy the reactors emit belong here (ADR 0010), and Power never defines a Core fluid.
--
-- Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/ with the licence
-- and a NOTICE naming every source file and every modification. Do not move one of these out of
-- that directory: the licence travels with the directory, not with this file (legal-note.txt).
local function icon(name)
  return { { icon = "__RealisticFusion__/graphics/krastorio-2/fluids/" .. name .. ".png", icon_size = 64 } }
end

data:extend({
  -- D-D plasma. Temperature is not decoration here: it is the state variable the reactor drives
  -- and the argument the reaction rate is interpolated at, so the range has to cover real fusion
  -- conditions rather than Factorio's usual few hundred degrees. The shipped reactor settles
  -- around 6e8 C; the cross-section data runs to about 7e9.
  --
  -- Because temperature is a native fluid property, two reactors joined by rf-pipe already share
  -- one pool at one mixed temperature with no Lua tracking connectivity. That is the whole of
  -- ADR 0011's fluid coupling.
  {
    type = "fluid",
    name = "rf-d-d-plasma",
    icons = icon("d-d-plasma"),
    subgroup = "fluid",
    order = "rf-p-a[d-d-plasma]",
    default_temperature = 15,
    max_temperature = 2e9,
    -- Always drawn as a gas in pipes and tanks. Plasma is never a liquid.
    gas_temperature = 0,
    -- Barrelling plasma would put a fusion-temperature fluid in a steel drum on a belt, and would
    -- route around the containment rules entirely (#26).
    auto_barrel = false,
    base_color = { r = 1.00, g = 0.55, b = 0.30 },
    flow_color = { r = 1.00, g = 0.75, b = 0.45 },
  },

  -- D-T plasma (#28). Everything above applies unchanged -- same temperature range, same reasons --
  -- because it goes into the same reactor and is written by the same simulation. The range is not
  -- merely copied: reactor-logic clamps every plasma to one pair of bounds and control.lua's
  -- check_plasma_bounds refuses to load if any plasma disagrees with them.
  --
  -- The colour is deuterium's cyan against tritium's green, which is what the fluid is, and it is
  -- deliberately nothing like D-D's orange: a pipe carrying the wrong plasma to a reactor is a
  -- mistake worth seeing from across the factory.
  {
    type = "fluid",
    name = "rf-d-t-plasma",
    icons = icon("d-t-plasma"),
    subgroup = "fluid",
    order = "rf-p-b[d-t-plasma]",
    default_temperature = 15,
    max_temperature = 2e9,
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 0.35, g = 1.00, b = 0.70 },
    flow_color = { r = 0.60, g = 1.00, b = 0.85 },
  },

  -- What a reactor sells: the fusion energy that leaves the plasma, as a fluid the heat exchanger
  -- burns. fuel_value is the conversion rate between the simulation's joules and fluid units, so
  -- one unit is one megajoule and nothing downstream needs to know about the physics.
  {
    type = "fluid",
    name = "rf-reactor-energy",
    icons = icon("reactor-energy"),
    subgroup = "fluid",
    order = "rf-p-z[reactor-energy]",
    default_temperature = 15,
    -- Declared, not defaulted: max_temperature otherwise falls back to default_temperature, and
    -- rf-reactor names this fluid as a boiler output with a target of 165. Nothing depends on the
    -- temperature -- the heat exchanger burns this by fuel_value -- but a prototype that asks for
    -- a temperature the fluid cannot hold is a trap for whoever reads it next.
    max_temperature = 165,
    fuel_value = "1MJ",
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 1.00, g = 0.90, b = 0.45 },
    flow_color = { r = 1.00, g = 0.95, b = 0.70 },
  },
})
