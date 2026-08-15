-- Runtime: the tick loop, reading and writing fluid boxes, and the invariants that tie the
-- simulation to the prototypes. Which reactors exist is scripts/entity-management.lua's business;
-- the physics is scripts/reactor-logic.lua's and does not know this file exists.

local logic    = require("scripts.reactor-logic")
local entities = require("scripts.entity-management")

-- ADR 0005 pre-authorises throttling the simulation to a coarser cadence and requires that doing
-- so be a change in one place. This is that place: nothing else in the mod knows how often the
-- simulation steps, and the step itself is written in terms of elapsed seconds.
--
-- Ten steps a second, not sixty, on the strength of #24's measurement. Not because the per-tick
-- cost was unaffordable -- nine to eleven microseconds per reactor, linear out to 200 of them, a
-- ninth of a tick's budget at that size -- but because five of every six of those steps bought
-- nothing. The plasma's confinement time is thirty seconds, and stepping a thirty-second process
-- every sixteen milliseconds resolves nothing that a tenth of a second misses: equilibrium
-- temperature moves 0.10% between the two cadences. tests/test-reactor-logic.lua asserts that
-- insensitivity across the whole range from one tick to thirty, so changing this line stays safe.
--
-- The price of coarsening is that every reactor now steps on the same tick, so the work arrives
-- as a spike rather than spread out. That is not an oversight to be fixed by staggering reactors
-- across buckets: reactors sharing a fluid segment have to step together, for the reason
-- update() gives below.
--
-- There is a ceiling on this number that the physics test cannot see, because it is a fact about
-- the prototype and not about the plasma: a step draws heating_power_w * interval / 60 joules out
-- of the reactor's buffer in one go, so at 50 MW against a 10 MJ buffer anything past twelve ticks
-- is starved every step. check_cadence() below enforces it, so the test's range and this line
-- cannot drift apart in silence -- raising this past 12 means raising buffer_capacity in
-- prototypes/entities.lua with it, and the mod refuses to load until one of the two moves.
--
-- See docs/research/reactor-runtime-cost.md; scripts/bench-reactors.ps1 takes the measurement.
local UPDATE_INTERVAL = 6

--- Apply one reactor's step to the world.
local function apply(entity, plasma, result)
  -- Spending straight out of the buffer is what makes the reactor's draw follow the simulation
  -- rather than a fixed prototype figure: the network refills what was spent, so a brownout shows
  -- up as a plasma that cannot hold its temperature. Measured on a reactor given 10 kW instead of
  -- the 50 MW it wants: the buffer sits empty and the plasma never leaves six figures.
  entity.energy = entity.energy - result.heating_used_j

  local box = entity.fluidbox

  -- Writing the plasma back is also how it is shared. Box 1 is the reactor's input-output box, so
  -- it belongs to the fluid segment it is plumbed into: a temperature written here is one every
  -- reactor on that run of rf-pipe works from next tick, mixed by the engine and by no code of
  -- ours (ADR 0011).
  --
  -- Each reactor reads and writes only its own share, and the arithmetic survives that because
  -- the two errors cancel exactly: a share of n out of a segment of N is given a rise computed
  -- against n, and the engine's mixing then dilutes it by n/N, so the energy the pool gains is
  -- the energy the reactor spent whatever else is on the run. Measured at 20 pipes against none:
  -- same plasma, same heating, same stored energy to within a tenth.
  local remaining = plasma.amount - result.plasma_consumed
  if remaining > 0 then
    box[1] = { name = plasma.name, amount = remaining, temperature = result.temperature_c }
  else
    box[1] = nil
  end

  if result.energy_units > 0 then
    -- Assigned to box 2 by index rather than inserted: fluidbox.insert would find box 1 whenever
    -- the reactor had just burnt its last plasma, and quietly fill the plasma box with reactor
    -- energy. The temperature is stated rather than left out, because omitting it resets the
    -- fluid to its default every tick; nothing reads it, since the heat exchanger burns this by
    -- fuel_value.
    local produced = box[2]
    local amount = result.energy_units + (produced and produced.amount or 0)
    -- Segment capacity, not this box's -- get_capacity reports the segment the box belongs to.
    -- Overflow is discarded, which is the right behaviour and not an oversight: a reactor whose
    -- heat is not being carried away does not get to bank it. It shows up as output backing up.
    local capacity = box.get_capacity(2)
    if amount > capacity then amount = capacity end
    box[2] = { name = "rf-reactor-energy", amount = amount, temperature = 15 }
  end
end

--- Read every reactor, then write every reactor.
--
-- Split in two on purpose. Reactors on one run of rf-pipe share a fluid segment, so if the steps
-- were interleaved a reactor would compute against a pool its neighbour had already written to
-- this tick, and the result would depend on the order entities.registry() happens to iterate in.
-- Reading first makes every reactor see the same start-of-tick pool, which is both what
-- simultaneous confinement means physically and one less thing to argue about in multiplayer.
local function update()
  local dt = UPDATE_INTERVAL / 60
  local pending = {}

  for unit_number, entity in pairs(entities.registry()) do
    if entity.valid then
      local plasma = entity.fluidbox[1]
      local result = logic.step(logic.reactor, plasma and plasma.name, plasma and plasma.amount,
        plasma and plasma.temperature, entity.energy, dt)
      if result then
        pending[#pending + 1] = { entity = entity, plasma = plasma, result = result }
      end
    else
      -- Dropped here rather than on a mined or died event, which is why entity-management wires
      -- no destruction handlers. One validity check covers every way an entity can leave --
      -- mined, destroyed, scripted away, surface deleted -- where a set of destruction handlers
      -- covers only the ways someone remembered. Removing the current key during pairs is
      -- defined behaviour in Lua; adding one would not be.
      entities.forget(unit_number)
    end
  end

  for _, step in ipairs(pending) do
    apply(step.entity, step.plasma, step.result)
  end
end

--- Refuse to run a cadence the reactor cannot be powered through.
--
-- A step spends the whole interval's heating in one go, so the buffer has to hold it. Past twelve
-- ticks at the shipped 50 MW and 10 MJ it cannot, and the reactor is starved every step for ever
-- -- silently, because underpowered is a legitimate state it is meant to have. That trap is not
-- something the Lua tests can see: they know the physics but not the prototype, and the physics is
-- happily insensitive to cadence well past the point the buffer gives out.
--
-- Here is the one place both numbers are visible, so here is where it is checked rather than
-- described. It can only fire on a developer edit -- to this file's interval or to entities.lua's
-- buffer -- and it fires during scripts/load-check.ps1, which creates a map and therefore runs
-- this.
local function check_cadence()
  local source = prototypes.entity["rf-reactor"].electric_energy_source_prototype
  local needed = logic.reactor.heating_power_w * UPDATE_INTERVAL / 60
  if needed > source.buffer_capacity then
    error(string.format(
      "rf-reactor: UPDATE_INTERVAL of %d ticks needs %.3g J of buffer per step but the prototype " ..
      "has %.3g J, so the reactor would be starved every step. Lower the interval in control.lua " ..
      "or raise buffer_capacity in prototypes/entities.lua.",
      UPDATE_INTERVAL, needed, source.buffer_capacity))
  end
end

--- Refuse to run a simulation that can compute a temperature the fluid cannot hold.
--
-- The same shape of trap as check_cadence, one file further out. apply() writes the simulated
-- temperature straight into the fluidbox, and Factorio rejects a temperature outside the fluid's
-- declared range -- so reactor-logic's clamps and rf-d-d-plasma's prototype have to agree, and
-- nothing but this ties them together. Edit max_temperature alone to make room for a later tier
-- and the mod loads perfectly, then throws on a live save the first time a reactor gets hot.
local function check_plasma_bounds()
  local fluid = prototypes.fluid["rf-d-d-plasma"]
  if logic.reactor.min_temperature_c < fluid.default_temperature
    or logic.reactor.max_temperature_c > fluid.max_temperature then
    error(string.format(
      "rf-reactor: the simulation clamps temperature to [%.6g, %.6g] C but rf-d-d-plasma accepts " ..
      "[%.6g, %.6g], so a reactor would write a temperature the fluid cannot hold. Reconcile " ..
      "scripts/reactor-logic.lua with prototypes/fluids.lua.",
      logic.reactor.min_temperature_c, logic.reactor.max_temperature_c,
      fluid.default_temperature, fluid.max_temperature))
  end
end

local function check_prototypes()
  check_cadence()
  check_plasma_bounds()
end

-- The register is rebuilt in the same breath as the prototype checks because both are answers to
-- "the world may not be what this code last saw": one re-reads the map, the other re-reads the
-- prototypes. The build-event handlers that keep the register current in between are wired by
-- entity-management itself.
script.on_init(function()
  check_prototypes()
  entities.rescan()
end)
script.on_configuration_changed(function()
  check_prototypes()
  entities.rescan()
end)

script.on_nth_tick(UPDATE_INTERVAL, update)
