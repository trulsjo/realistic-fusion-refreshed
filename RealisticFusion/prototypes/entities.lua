require("util") -- table.deepcopy

-- Power's machines, built from vanilla ones for the same reason Core's are: no graphics ship, so
-- ADR 0010's open art question stays open and the entities work rather than being invisible. The
-- base entity is chosen for its shape and fluid box count.
--
-- Every stat that affects balance is pinned rather than inherited, because a deep copy taken here
-- picks up whatever a mod sorting earlier has already done to the source prototype.

local function pin(e, name, opts)
  e.name = name
  e.minable = { mining_time = opts.mining_time or 1, result = name }
  e.icons = { { icon = opts.icon, icon_size = 64, tint = opts.tint } }
  e.icon = nil
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

local NUCLEAR_REACTOR = "__base__/graphics/icons/nuclear-reactor.png"
local CHEMICAL_PLANT = "__base__/graphics/icons/chemical-plant.png"
-- heat-boiler, not heat-exchanger: the entity was renamed and the icon file was not.
local HEAT_EXCHANGER = "__base__/graphics/icons/heat-boiler.png"
local PIPE           = "__base__/graphics/icons/pipe.png"
local PIPE_TO_GROUND = "__base__/graphics/icons/pipe-to-ground.png"

local PLASMA_TINT = { r = 1.00, g = 0.55, b = 0.30 }

-- ---------------------------------------------------------------- heater

-- Deuterium in, plasma out, on an ordinary recipe. The heater is the only ordinary machine on the
-- power side: it ionises and injects, and the confinement heating that takes the plasma from
-- there to fusion temperature is the reactor's job and the simulation's.
local heater = pin(table.deepcopy(data.raw["assembling-machine"]["chemical-plant"]), "rf-heater", {
  icon = CHEMICAL_PLANT, tint = PLASMA_TINT, mining_time = 0.5,
})
heater.crafting_categories = { "rf-plasma-heating" }
heater.crafting_speed = 1
heater.energy_usage = "5MW"
heater.module_slots = 3
-- No productivity: a productivity bonus on this recipe would conjure plasma, and plasma is
-- energy. Speed and efficiency are fine.
heater.allowed_effects = { "consumption", "speed", "pollution", "quality" }

-- ---------------------------------------------------------------- reactor

-- The simulated object (ADR 0011). Everything it does happens in control.lua; the prototype is
-- chosen for what the engine will do with fluid, not for what it nominally is.
--
-- It is a boiler, and that is not arbitrary. A crafting machine was the obvious choice and does
-- not work: with no recipe set it moves no fluid at all -- pipes connect to it and nothing ever
-- crosses, filter or no filter -- and a crafting machine's fluid boxes may only be "input" or
-- "output" types, which are one-way. A boiler fills its input box from whatever it is plumbed to
-- whether or not it is doing anything, and its input box may be "input-output": the storage-style
-- kind that joins the fluid segment it is connected to rather than being a one-way sink. That is
-- what makes every reactor on one run of rf-pipe work from a single pool at a single mixed
-- temperature, maintained by the engine, with no connectivity code anywhere in this mod.
--
-- The boiler's own conversion is neutered rather than used, and energy_consumption is what does
-- it: at 1 W the engine can move on the order of one unit per fifty hours whatever the
-- temperatures are, which is nothing beside the simulation. target_temperature is NOT what makes
-- it safe -- plasma runs six to eight orders of magnitude above 165 C, so reasoning from the
-- temperature delta proves nothing. Measured rather than argued: a reactor seeded at 100 C, below
-- the target, and one seeded at 1e6 C, above it, both lose plasma only at the rate the simulation
-- burns it, and neither produces reactor energy the engine was not asked for.
--
-- ponytail: the reactor and the heat exchanger below are therefore the same sprite in different
-- tints, which is worse than Core's placeholders and is the price of the fluid behaviour. Only
-- the icons distinguish them. It goes away with the art pass ADR 0010 left open.
local reactor = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-reactor", {
  icon = NUCLEAR_REACTOR, tint = PLASMA_TINT, mining_time = 3,
})
reactor.mode = "output-to-separate-pipe"
reactor.target_temperature = 165
reactor.energy_consumption = "1W"
reactor.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  -- Confinement heating is spent straight out of this buffer by control.lua rather than declared
  -- as a fixed consumption, which is what makes the reactor's draw follow the simulation. A few
  -- seconds of reserve so one slow tick does not read as a brownout; the network refills it at up
  -- to input_flow_limit.
  --
  -- It also sets a ceiling on control.lua's UPDATE_INTERVAL: one step spends the whole interval's
  -- heating at once, so this buffer has to cover 50 MW for that long. 10 MJ buys twelve ticks.
  buffer_capacity = "10MJ",
  input_flow_limit = "60MW",
  drain = "0W",
}

local covers = table.deepcopy(reactor.fluid_box.pipe_covers)

reactor.fluid_box = {
  production_type = "input-output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west, position = { -1, 0.5 } },
    { flow_direction = "input-output", direction = defines.direction.east, position = { 1, 0.5 } },
  },
  -- Filtered so a stray water pipe cannot fill the reactor with something it will silently refuse
  -- to burn. It also pins this prototype to the D-D tier: the D-T tier (#28) needs either
  -- LuaFluidBox.set_filter at runtime or a prototype of its own.
  filter = "rf-d-d-plasma",
}
reactor.output_fluid_box = {
  production_type = "output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "output", direction = defines.direction.north, position = { 0, -0.5 } },
  },
  filter = "rf-reactor-energy",
}

-- ---------------------------------------------------------------- heat exchanger

-- Vanilla's heat exchanger with its heat energy source replaced by a fluid one. Burning
-- rf-reactor-energy for its fuel_value is what converts the simulation's joules into steam:
-- energy_consumption sets the burn rate, and everything downstream is ordinary vanilla steam at
-- 500 C, which vanilla steam turbines already accept.
local exchanger = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-heat-exchanger", {
  icon = HEAT_EXCHANGER, tint = { r = 1.00, g = 0.90, b = 0.45 }, mining_time = 0.5,
})
exchanger.energy_consumption = "40MW"
exchanger.energy_source = {
  type = "fluid",
  effectivity = 1,
  -- Burn by fuel_value rather than by temperature: reactor energy carries its joules in its
  -- amount, not in how hot it is.
  burns_fluid = true,
  -- Take only what the current output needs. Without this the exchanger drains its whole box
  -- every tick and throws away the excess.
  scale_fluid_usage = true,
  fluid_box = {
    production_type = "input",
    volume = 200,
    pipe_covers = table.deepcopy(exchanger.fluid_box.pipe_covers),
    -- Where vanilla's heat pipe connected.
    pipe_connections = {
      { flow_direction = "input", direction = defines.direction.south, position = { 0, 0.5 } },
    },
    filter = "rf-reactor-energy",
  },
}

-- ---------------------------------------------------------------- plasma-safe fluid handling

-- Plasma must not travel through vanilla pipes (CONTEXT.md, ADR 0010). Enforcing that is #26;
-- these exist so there is something to enforce it in favour of.
--
-- ponytail: the in-world sprites are still the vanilla pipe's, so an rf-pipe and a pipe look
-- alike in a build. Only the icon is tinted. That is the same placeholder limitation Core's
-- machines carry, and it matters more here -- it goes away when real art arrives.
local pipe = pin(table.deepcopy(data.raw["pipe"]["pipe"]), "rf-pipe", {
  icon = PIPE, tint = PLASMA_TINT, mining_time = 0.1,
})
local pipe_to_ground = pin(table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"]), "rf-pipe-to-ground", {
  icon = PIPE_TO_GROUND, tint = PLASMA_TINT, mining_time = 0.1,
})

data:extend({ heater, reactor, exchanger, pipe, pipe_to_ground })
