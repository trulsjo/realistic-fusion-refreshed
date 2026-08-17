require("util") -- table.deepcopy

-- Power's machines, built from vanilla ones: the base entity is chosen for its shape and fluid
-- box count, which is the part that decides behaviour.
--
-- Icons are derived from Krastorio 2 (LGPLv3) and live in graphics/krastorio-2/ with the licence
-- and a NOTICE naming every source file. Do not move one out of that directory -- the licence
-- travels with the directory, not with this file (legal-note.txt).
--
-- Every stat that affects balance is pinned rather than inherited, because a deep copy taken here
-- picks up whatever a mod sorting earlier has already done to the source prototype.

local ENTITY = "__RealisticFusion__/graphics/krastorio-2/entities/"

-- Plasma must not travel through vanilla pipes (CONTEXT.md, ADR 0010). This is what enforces it.
--
-- 2.0 gives a pipe connection a connection_category, and two connections join only when theirs
-- match. Naming a category of our own therefore makes a vanilla pipe beside a plasma line simply
-- not connect -- the same way it already refuses to join a heat pipe. The plasma never enters,
-- which is a stronger statement than noticing that it did.
--
-- The 1.1 original could not do this and spent 160 lines of control.lua hunting down plasma-carrying
-- vanilla pipes and destroying them. That is a tick cost, a surprise for whoever built the pipe, and
-- a race with whatever put the plasma there. None of it is needed against 2.0, so none of it is
-- here: this file is the whole of the enforcement and control.lua gains nothing.
--
-- Applied per box rather than per entity, because the reactor's other box carries reactor energy
-- through ordinary pipes on purpose, and the heater is fed deuterium through them.
local PLASMA_CATEGORY = "rf-plasma"

local function contain(box)
  for _, connection in ipairs(box.pipe_connections or {}) do
    connection.connection_category = PLASMA_CATEGORY
  end
  return box
end

local function pin(e, name, opts)
  e.name = name
  e.minable = { mining_time = opts.mining_time or 1, result = name }
  e.icons = { { icon = ENTITY .. name:gsub("^rf%-", "") .. ".png", icon_size = 64 } }
  e.icon = nil
  -- Vanilla's group would let a player fast-replace ours with the machine it was copied from.
  e.fast_replaceable_group = nil
  e.next_upgrade = nil
  return e
end

-- ---------------------------------------------------------------- heater

-- Deuterium in, plasma out, on an ordinary recipe. The heater is the only ordinary machine on the
-- power side: it ionises and injects, and the confinement heating that takes the plasma from
-- there to fusion temperature is the reactor's job and the simulation's.
local heater = pin(table.deepcopy(data.raw["assembling-machine"]["chemical-plant"]), "rf-heater", {
  mining_time = 0.5,
})
heater.crafting_categories = { "rf-plasma-heating" }
heater.crafting_speed = 1
heater.energy_usage = "5MW"
heater.module_slots = 3
-- No productivity: a productivity bonus on this recipe would conjure plasma, and plasma is
-- energy. Speed and efficiency are fine.
heater.allowed_effects = { "consumption", "speed", "pollution", "quality" }
-- Krastorio 2's fuel refinery, which is the icon this machine already carries and is modelled on
-- the same vanilla chemical plant -- same boxes, same four pipe positions. So unlike the reactor
-- this is a sprite swap and nothing else. LGPLv3; see the file for why it lives over there.
heater.graphics_set = require("graphics.krastorio-2.buildings.heater-pictures")
-- Plasma leaves through the output boxes, so those are plasma-safe only; the input boxes stay
-- ordinary because deuterium arrives through ordinary pipes. Selected by production_type rather
-- than by index: which box a chemical plant puts a result in is the recipe's business, and the two
-- output boxes are interchangeable.
for _, box in ipairs(heater.fluid_boxes) do
  if box.production_type == "output" then contain(box) end
end

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
local reactor = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-reactor", {
  mining_time = 3,
})
reactor.mode = "output-to-separate-pipe"

-- It looks like Krastorio 2's fusion reactor, and it is therefore the size of one: fifteen tiles
-- square, against the three-by-two heat exchanger it is otherwise a copy of.
--
-- The footprint follows the art rather than the art being made to fit the footprint, and that is
-- the decision, not a side effect. K2's reactor is drawn for a 15x15 building; there is no K2
-- building shaped 3x2 to repoint to, and cropping a nine-tile reactor down to three reads as
-- exactly that. Both boxes are K2's own, so the sprite lands where it was drawn to land.
--
-- The heat exchanger below keeps the vanilla 3x2 shape it always had. That is the point: the two
-- were the same sprite in two tints and could not be told apart on the ground.
reactor.collision_box = { { -7.25, -7.25 }, { 7.25, 7.25 } }
reactor.selection_box = { { -7.5, -7.5 }, { 7.5, 7.5 } }
-- Derived from K2's own prototype and LGPLv3, which is why it lives in the graphics directory and
-- not here. See the note at the top of that file for what a boiler forced to change.
local reactor_graphics = require("graphics.krastorio-2.buildings.reactor-pictures")
reactor.pictures = reactor_graphics.pictures
-- The moving core, drawn over the still one by scripts/reactor-animation.lua while the reactor is
-- fusing. It is a script rendering and not part of the entity because a boiler cannot animate at
-- all -- neither structure nor fire will play, both measured; see the file above.
data:extend({ reactor_graphics.core_animation("rf-reactor-core") })
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

-- Both boxes connect at the edge of the new footprint rather than the old one. Whole numbers
-- because fifteen is odd: the tile centres of a 15x15 entity sit on integers, where the 3x2 it
-- replaced had them on halves. West and east still both take plasma, which is what lets a run of
-- rf-pipe feed a row of reactors from one pool (ADR 0011), and the energy still leaves north.
reactor.fluid_box = {
  production_type = "input-output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "input-output", direction = defines.direction.west, position = { -7, 0 } },
    { flow_direction = "input-output", direction = defines.direction.east, position = { 7, 0 } },
  },
  -- Filtered so a stray water pipe cannot fill the reactor with something it will silently refuse
  -- to burn. It also pins this prototype to the D-D tier: the D-T tier (#28) needs either
  -- LuaFluidBox.set_filter at runtime or a prototype of its own.
  filter = "rf-d-d-plasma",
}
-- Plasma in and plasma out of the shared pool, so both faces are plasma-safe only. The energy box
-- below is deliberately not: reactor energy is an ordinary fluid and a player plumbs it with
-- ordinary pipes.
contain(reactor.fluid_box)
reactor.output_fluid_box = {
  production_type = "output",
  volume = 1000,
  pipe_covers = covers,
  pipe_connections = {
    { flow_direction = "output", direction = defines.direction.north, position = { 0, -7 } },
  },
  filter = "rf-reactor-energy",
}

-- ---------------------------------------------------------------- heat exchanger

-- Vanilla's heat exchanger with its heat energy source replaced by a fluid one. Burning
-- rf-reactor-energy for its fuel_value is what converts the simulation's joules into steam:
-- energy_consumption sets the burn rate, and everything downstream is ordinary vanilla steam at
-- 500 C, which vanilla steam turbines already accept.
local exchanger = pin(table.deepcopy(data.raw["boiler"]["heat-exchanger"]), "rf-heat-exchanger", {
  mining_time = 0.5,
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
-- These carry real art rather than a tint, so a plasma line is visibly not a water line -- which
-- is the point, since #26 is about stopping plasma reaching a vanilla pipe and a player has to be
-- able to see which is which before that rule can feel fair.
--
-- The sprites are Krastorio 2's steel pipe (LGPLv3, graphics/krastorio-2/). It is dimensionally
-- identical to the vanilla set file for file, so this repoints filenames and leaves every width,
-- height, shift, scale and frame count exactly as vanilla declares them. Nothing here guesses at
-- geometry.
local PIPE_SPRITES = {
  "pipe-corner-down-left", "pipe-corner-down-right", "pipe-corner-up-left", "pipe-corner-up-right",
  "pipe-cross", "pipe-ending-down", "pipe-ending-left", "pipe-ending-right", "pipe-ending-up",
  "pipe-horizontal-window-background", "pipe-straight-horizontal", "pipe-straight-horizontal-single",
  "pipe-straight-horizontal-window", "pipe-straight-vertical", "pipe-straight-vertical-single",
  "pipe-straight-vertical-window", "pipe-t-down", "pipe-t-left", "pipe-t-right", "pipe-t-up",
  "pipe-vertical-window-background",
}
local PIPE_TO_GROUND_SPRITES = {
  "pipe-to-ground-down", "pipe-to-ground-left", "pipe-to-ground-right", "pipe-to-ground-up",
}

-- Repoint by basename, walking the whole prototype rather than naming the fields. The pipe
-- prototype nests its sprites several layers down and the layout has changed between versions;
-- a walk keeps working when it changes again.
--
-- Only listed basenames are touched. The vanilla pipe directory also holds the fluid-flow
-- animations, the window background and both visualisation sprites, which K2 has no counterpart
-- for -- those stay pointing at __base__ deliberately, and the load-check's missing-asset
-- pre-flight is what would catch it if one were ever renamed there.
local function repoint(value, directory, names)
  local wanted = {}
  for _, n in ipairs(names) do wanted[n] = true end

  local function walk(node)
    if type(node) ~= "table" then return end
    for key, child in pairs(node) do
      if key == "filename" and type(child) == "string" then
        local base = child:match("([^/]+)%.png$")
        if base and wanted[base] then
          node[key] = directory .. base .. ".png"
        end
      else
        walk(child)
      end
    end
  end

  walk(value)
  return value
end

local GRAPHICS = "__RealisticFusion__/graphics/krastorio-2/"

local pipe = repoint(
  pin(table.deepcopy(data.raw["pipe"]["pipe"]), "rf-pipe", { mining_time = 0.1 }),
  GRAPHICS .. "pipe/", PIPE_SPRITES)
contain(pipe.fluid_box)

local pipe_to_ground = repoint(
  pin(table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"]), "rf-pipe-to-ground", { mining_time = 0.1 }),
  GRAPHICS .. "pipe-to-ground/", PIPE_TO_GROUND_SPRITES)
-- Both of its connections, which is the point: the underground one carries the category too, so a
-- vanilla pipe-to-ground cannot tunnel into a plasma line from out of sight.
contain(pipe_to_ground.fluid_box)

-- The plasma set needs a pump of its own for the same reason it needs pipes of its own: a vanilla
-- pump is a vanilla pipe connection, so with containment in place it cannot join a plasma line at
-- all, and without this there would be no way to lift plasma over a distance or to force its
-- direction.
local pump = pin(table.deepcopy(data.raw["pump"]["pump"]), "rf-pump", { mining_time = 0.2 })
-- pin() derives an icon path from the entity's name, and there is no Krastorio 2 pump in
-- graphics/krastorio-2/ to derive it from. Vanilla's is referenced rather than copied -- no file
-- moves, so no licence travels. The art is provisional: this is a plasma pump wearing an ordinary
-- pump's coat, and it reads as one until someone draws it. Nothing depends on the picture, because
-- the containment is in the connections rather than in the sprite.
pump.icons = { { icon = "__base__/graphics/icons/pump.png", icon_size = 64 } }
-- A pump is the one entity that moves fluid without a pipe connection at the far end: it also loads
-- and unloads fluid wagons, which would be a way around every rule above -- rf-pump into a vanilla
-- wagon, vanilla pump out of it, plasma anywhere. It is not. FluidWagonPrototype carries a
-- connection_category of its own, and 2.0.77 says "Pumps are only allowed to connect to this fluid
-- wagon if the pump's fluid box connection and this fluid wagon share a connection category", so
-- containing the fluid box below closes the wagon route with it. The consequence is deliberate and
-- worth stating: there is no wagon that can carry plasma, and shipping one would mean a fluid wagon
-- prototype of our own. Barrelling is shut off separately, on the fluids themselves (fluids.lua).
contain(pump.fluid_box)

data:extend({ heater, reactor, exchanger, pipe, pipe_to_ground, pump })
