-- Runtime: entity lifecycle, the tick loop, and reading and writing fluid boxes. The physics is
-- in scripts/reactor-logic.lua and does not know this file exists.

local logic = require("scripts.reactor-logic")

-- ADR 0005 pre-authorises throttling the simulation to a coarser cadence and requires that doing
-- so be a change in one place. This is that place: nothing else in the mod knows how often the
-- simulation steps, and the step itself is written in terms of elapsed seconds.
--
-- It starts at every tick deliberately. ADR 0005 chose to begin at full fidelity and measure
-- (#24) rather than pre-emptively coarsen something nobody has ever measured.
local UPDATE_INTERVAL = 1

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
-- this tick, and the result would depend on the order storage.reactors happens to iterate in.
-- Reading first makes every reactor see the same start-of-tick pool, which is both what
-- simultaneous confinement means physically and one less thing to argue about in multiplayer.
local function update()
  local dt = UPDATE_INTERVAL / 60
  local reactors = storage.reactors or {}
  local pending = {}

  for unit_number, entity in pairs(reactors) do
    if entity.valid then
      local plasma = entity.fluidbox[1]
      local result = logic.step(logic.reactor, plasma and plasma.name, plasma and plasma.amount,
        plasma and plasma.temperature, entity.energy, dt)
      if result then
        pending[#pending + 1] = { entity = entity, plasma = plasma, result = result }
      end
    else
      -- Dropped here rather than on a mined or died event. One validity check covers every way an
      -- entity can leave -- mined, destroyed, scripted away, surface deleted -- where a set of
      -- destruction handlers covers the ways someone remembered.
      reactors[unit_number] = nil
    end
  end

  for _, step in ipairs(pending) do
    apply(step.entity, step.plasma, step.result)
  end
end

local function register(entity)
  if entity and entity.valid and entity.name == "rf-reactor" then
    storage.reactors = storage.reactors or {}
    storage.reactors[entity.unit_number] = entity
  end
end

--- Rebuild the register from what is actually on the map.
--
-- Runs when the mod is added to a save and whenever the configuration changes, so a reactor is
-- never left unsimulated because an event was missed or an entity predates this code.
local function rescan()
  storage.reactors = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = "rf-reactor" })) do
      register(entity)
    end
  end
end

script.on_init(rescan)
script.on_configuration_changed(rescan)

local built_filter = { { filter = "name", name = "rf-reactor" } }
for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  -- Defined only on a game that knows about platforms. Nothing guards it because nothing needs
  -- to: a nil here is simply a value the table constructor does not store, and pairs iterates
  -- what is there. ADR 0003 tolerates Space Age without targeting it, so it must not be assumed
  -- present -- and must be handled if it is.
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}) do
  script.on_event(event, function(e) register(e.entity) end, built_filter)
end

script.on_nth_tick(UPDATE_INTERVAL, update)
