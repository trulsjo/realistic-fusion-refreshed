-- Power's own fluids. Core owns everything the extraction chain produces; the plasmas and the
-- energy the reactors emit belong here (ADR 0010), and Power never defines a Core fluid.
--
-- Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/ with the licence
-- and a NOTICE naming every source file and every modification. Do not move one of these out of
-- that directory: the licence travels with the directory, not with this file (legal-note.txt).
local function icon(name)
  return { { icon = "__realistic-fusion-refreshed-assets__/graphics/krastorio-2/fluids/" .. name .. ".png", icon_size = 64 } }
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
    max_temperature = 5e9,
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
    max_temperature = 5e9,
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 0.35, g = 1.00, b = 0.70 },
    flow_color = { r = 0.60, g = 1.00, b = 0.85 },
  },

  -- D-He3 plasma (#31), the first aneutronic tier. Same range and same reasons as the two above --
  -- one pair of bounds for every plasma, tied to reactor-logic's clamps by control.lua's
  -- check_plasma_bounds.
  --
  -- Deuterium's cyan carried toward helium-3's violet, which is what the fuel is: Core gives
  -- rf-helium-3 an r0.80 g0.45 b1.00 and rf-deuterium a cyan, so a blend of the two lands here.
  -- Against D-D's orange and D-T's green it is a different family entirely, which is the point --
  -- four plasmas now share a pipe network's worth of colours and a player has to be able to tell
  -- at a glance which one is going into which reactor.
  {
    type = "fluid",
    name = "rf-d-he3-plasma",
    icons = icon("d-he3-plasma"),
    subgroup = "fluid",
    order = "rf-p-c[d-he3-plasma]",
    default_temperature = 15,
    max_temperature = 5e9,
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 0.55, g = 0.60, b = 1.00 },
    flow_color = { r = 0.75, g = 0.80, b = 1.00 },
  },

  -- He3-He3 plasma (#31), the end of ADR 0010's chain.
  --
  -- Helium-3's own violet pushed to magenta rather than left at Core's rf-helium-3 colour. The two
  -- aneutronic plasmas are the pair most likely to be confused -- same tier, same reactor, adjacent
  -- in every menu -- so they are separated on hue rather than on shade. Blue against magenta reads
  -- apart in a pipe at any zoom; two violets would not.
  {
    type = "fluid",
    name = "rf-he3-he3-plasma",
    icons = icon("he3-he3-plasma"),
    subgroup = "fluid",
    order = "rf-p-d[he3-he3-plasma]",
    default_temperature = 15,
    max_temperature = 5e9,
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 0.90, g = 0.40, b = 1.00 },
    flow_color = { r = 0.95, g = 0.65, b = 1.00 },
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
    -- rf-reactor names this fluid as a boiler output with a target of 550. Nothing READS the
    -- temperature -- the heat exchanger burns this by fuel_value -- but the target is stamped onto
    -- every unit control.lua writes, and check_energy_outlets() refuses to load if this is below it.
    -- So the pair moves together or not at all: see the target in prototypes/entities.lua for why
    -- it is 550 and not 165.
    max_temperature = 550,
    fuel_value = "1MJ",
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 1.00, g = 0.90, b = 0.45 },
    flow_color = { r = 1.00, g = 0.95, b = 0.70 },
  },

  -- What an ANEUTRONIC reactor sells (#31). A second energy fluid rather than the one above, and
  -- the separation is the tier's whole mechanic rather than bookkeeping.
  --
  -- The neutronic reactors sell energy that arrived as neutrons and wall heat, and the only thing
  -- that can be done with heat is a steam loop: rf-heat-exchanger, water, turbines. An aneutronic
  -- reaction puts everything into charged particles, and a charged particle can be decelerated
  -- against a collector plate and taken straight off as current -- which is what
  -- rf-direct-energy-converter does, and what a heat exchanger cannot be asked to do because there
  -- is no heat.
  --
  -- Two fluids is what stops the two routes being interchangeable. The converter filters this and
  -- the exchanger filters the other, so a player cannot pipe reactor energy into a direct converter
  -- and skip the steam stage, and cannot run an aneutronic reactor through an exchanger either. The
  -- simulation is the same step() for both; what differs is what comes out of the pipe and what
  -- will drink it.
  --
  -- The same 1 MJ per unit, deliberately, so "one unit is one megajoule" stays true of the whole
  -- mod and the two tiers' outputs can be compared without a conversion.
  {
    type = "fluid",
    name = "rf-aneutronic-reactor-energy",
    icons = icon("aneutronic-reactor-energy"),
    subgroup = "fluid",
    order = "rf-p-z[aneutronic-reactor-energy]",
    default_temperature = 15,
    -- Declared for the reason rf-reactor-energy's is: rf-aneutronic-reactor names this fluid as a
    -- boiler output with a target temperature, and a prototype asking for a temperature the fluid
    -- cannot hold is a trap for whoever reads it next.
    max_temperature = 165,
    fuel_value = "1MJ",
    gas_temperature = 0,
    auto_barrel = false,
    base_color = { r = 0.55, g = 0.90, b = 1.00 },
    flow_color = { r = 0.75, g = 0.95, b = 1.00 },
  },
})
