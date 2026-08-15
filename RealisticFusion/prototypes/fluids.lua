-- Power's own fluids. Core owns everything the extraction chain produces; the plasmas and the
-- energy the reactors emit belong here (ADR 0010), and Power never defines a Core fluid.
--
-- Placeholder icons, same as Core's and for the same reason: no assets ship, so ADR 0010's open
-- art question stays open.
local function placeholder(tint)
  return { { icon = "__base__/graphics/icons/fluid/water.png", icon_size = 64, tint = tint } }
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
    icons = placeholder({ r = 1.00, g = 0.55, b = 0.30 }),
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

  -- What a reactor sells: the fusion energy that leaves the plasma, as a fluid the heat exchanger
  -- burns. fuel_value is the conversion rate between the simulation's joules and fluid units, so
  -- one unit is one megajoule and nothing downstream needs to know about the physics.
  {
    type = "fluid",
    name = "rf-reactor-energy",
    icons = placeholder({ r = 1.00, g = 0.90, b = 0.45 }),
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
