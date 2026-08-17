-- Runtime: the tick loop, reading and writing fluid boxes, and the invariants that tie the
-- simulation to the prototypes. Which reactors exist is scripts/entity-management.lua's business;
-- the physics is scripts/reactor-logic.lua's and does not know this file exists; what a reactor
-- reports to the player is scripts/circuit-output.lua's.

local logic    = require("scripts.reactor-logic")
local entities = require("scripts.entity-management")
local circuit  = require("scripts.circuit-output")

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

-- How many simulation steps pass between reports. The reactor is simulated ten times a second and
-- reports itself twice, because those two numbers answer different questions.
--
-- The simulation's cadence is set by the physics: how finely a thirty-second confinement time has
-- to be resolved. Reporting's is set by a person reading a number, and a value that changes ten
-- times a second is not readable -- nor is any factory control loop built on it going to react
-- faster than a second. Nothing is lost by saying it five times less often, and something real is
-- gained: publishing on every step took the per-reactor cost from 1.39 us to 3.51 us, measured
-- with scripts/bench-reactors.ps1, because writing a combinator section is expensive next to the
-- arithmetic it reports.
--
-- Caching the last-written values and skipping unchanged ones was tried first and abandoned. It
-- returned 15%, because the temperature is a float that moves in its last digits every single step
-- -- at 6e8 degrees even a millionth of a percent is hundreds of degrees, so the emitted integer
-- almost never repeats and the cache almost never hits. The measurement is what settled it.
--
-- The worst staleness a player sees is half a second. That is a deliberate trade and the only one
-- here; if a later tier wants a faster gauge, this is the one number to change.
local REPORT_EVERY = 5

-- Which of the collector's boxes carries what (#27). Stated once here and asserted against the
-- prototype at load by check_collector_boxes() below, rather than looked up through
-- fluidbox.get_filter ten times a second for every reactor that has one.
--
-- An ordered list, not a map keyed by fluid: deposit() walks it by index so the two writes happen
-- in the same order on every machine in a multiplayer game. pairs() over a name-keyed table would
-- not promise that.
local COLLECTOR_BOXES = { "rf-tritium", "rf-helium-3" }

-- The smallest amount worth writing into a fluid box, and this is a crash guard rather than a
-- tidiness one. "> 0" is not the same test as "the engine will accept this": a reactor that is
-- barely fusing produces a positive double so small that it is not representable as a fluid
-- amount, and Factorio answers a write of one with "Fluid amount has to be positive" and takes the
-- whole mod down with it. Found by scripts/check-breeding.ps1's cool cell -- a reactor holding
-- plasma at injection temperature with no power to raise it, which is what every reactor is for
-- its first few seconds and what one with a dead heater is for ever.
--
-- What the threshold discards is nothing in both senses. A step is a tenth of a second, so this
-- bounds the loss at 1e-5 units a second against a working reactor's 0.7 of by-product and 82 of
-- reactor energy -- five orders down at the very least, and only reachable at all by a reactor
-- that is not meaningfully fusing.
local MIN_FLUID = 1e-6

--- Put what a reactor bred into the collector bolted to it.
--
-- Overflow is discarded rather than banked, which is the same policy the reactor's energy output
-- follows and for the same reason: a collector nobody is draining is a full collector, and it
-- should show up as by-products backing up rather than as a reactor quietly storing them for ever.
local function deposit(collector, products)
  local box = collector.fluidbox
  for index = 1, #COLLECTOR_BOXES do
    local name = COLLECTOR_BOXES[index]
    local bred = products[name]
    if bred and bred > 0 then
      local held = box[index]
      local amount = bred + (held and held.amount or 0)
      local capacity = box.get_capacity(index)
      if amount > capacity then amount = capacity end
      -- The threshold is tested against the box's new total, not against what was just bred, and
      -- that is the useful way round: a reactor breeding a millionth of a unit a step still has
      -- it accumulate into a box that already holds something, and is only discarded while the box
      -- is empty and there is nothing for it to be added to. The cost is that a barely-fusing
      -- reactor with a non-empty box rewrites it every step with almost the same number, which is
      -- two fluidbox writes a reactor at the cadence -- the same thing the energy box above does.
      if amount >= MIN_FLUID then
        -- Temperature stated rather than omitted, for the reason apply() gives about the energy
        -- box: leaving it out resets the fluid to its default every time. These two are ambient
        -- gases and the prototype gives them no range to sit anywhere else in.
        box[index] = { name = name, amount = amount, temperature = 15 }
      end
    end
  end
end

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

  -- MIN_FLUID, not zero, and for the same reason deposit() uses it: a reactor that is barely
  -- fusing computes a positive output too small for the engine to accept as a fluid amount, and
  -- writing one is a crash rather than a rounding error.
  if result.energy_units >= MIN_FLUID then
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

  -- What the reaction bred, if there is anywhere to put it. A reactor with no collector simply
  -- vents it: the by-products are computed either way, so bolting one on later starts collecting
  -- immediately and never has a backlog to catch up on.
  if result.products then
    local collector = entities.collector(entity)
    if collector then deposit(collector, result.products) end
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

  -- Counted rather than derived from game.tick, so the reporting cadence stays a multiple of the
  -- simulation's however UPDATE_INTERVAL is set.
  storage.steps_since_report = (storage.steps_since_report or REPORT_EVERY) + 1
  local reporting = storage.steps_since_report >= REPORT_EVERY
  if reporting then storage.steps_since_report = 0 end

  for unit_number, entity in pairs(entities.registry()) do
    if entity.valid then
      local plasma = entity.fluidbox[1]
      local result = logic.step(logic.reactor, plasma and plasma.name, plasma and plasma.amount,
        plasma and plasma.temperature, entity.energy, dt)

      -- Reported from the read pass, on the state the step was computed against, so a reactor
      -- describes the tick it just simulated rather than one it is part way through. It happens
      -- here and not in the write pass because a reactor with nothing to simulate has no entry
      -- there at all, and "starved of plasma" is exactly the state that reactor is in and the one
      -- worth showing.
      if reporting then circuit.publish(entity, result, plasma and plasma.amount, logic.reactor) end

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
      -- The reactor's signals combinator is invisible, unminable and still on the wire if it
      -- outlives the reactor, so it goes at the same moment and by the same test.
      circuit.forget(unit_number)
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
-- declared range -- so reactor-logic's clamps and every plasma's prototype have to agree, and
-- nothing but this ties them together. Edit max_temperature alone to make room for a later tier
-- and the mod loads perfectly, then throws on a live save the first time a reactor gets hot.
--
-- Over every fuel rather than over rf-d-d-plasma alone, because the clamps live on the reactor spec
-- and are therefore one pair of bounds for all of them: a tier whose plasma declares a narrower
-- range than the reactor can compute is the same crash, discovered later.
local function check_plasma_bounds()
  for name in pairs(logic.fuels) do
    local fluid = prototypes.fluid[name]
    if not fluid then
      error(string.format(
        "rf-reactor: scripts/reactor-logic.lua burns %s but no such fluid exists. Add it to " ..
        "prototypes/fluids.lua or drop the row.", name))
    end
    if logic.reactor.min_temperature_c < fluid.default_temperature
      or logic.reactor.max_temperature_c > fluid.max_temperature then
      error(string.format(
        "rf-reactor: the simulation clamps temperature to [%.6g, %.6g] C but %s accepts " ..
        "[%.6g, %.6g], so a reactor would write a temperature the fluid cannot hold. Reconcile " ..
        "scripts/reactor-logic.lua with prototypes/fluids.lua.",
        logic.reactor.min_temperature_c, logic.reactor.max_temperature_c, name,
        fluid.default_temperature, fluid.max_temperature))
    end
  end
end

--- Refuse to run if a plasma exists that no reactor knows how to burn.
--
-- The other half of the same seam, and it only became reachable with #28: the reactor's input box
-- used to be filtered to rf-d-d-plasma, so a plasma with no fuel row could not get into one. Two
-- tiers share one reactor now (ADR 0010 names a single rf-reactor for both), so the filter is gone
-- and any plasma a heater can make can be plumbed into any reactor.
--
-- What that opens is the failure reactor-logic's step() describes: step() returns nil for a fluid
-- it has no row for, and returning nil leaves the reactor untouched -- so the plasma sits in the
-- box for ever while the reactor reports "starved" and the player has no way to tell why. Silent,
-- and indistinguishable from an empty pipe. Adding the row is a one-line fix; finding out it was
-- missing is not, so it is found here instead.
--
-- Found through the plasma-heating recipe category rather than by scanning fluid names for
-- "-plasma", which was the first version and looked at every fluid in the game. Two things wrong
-- with that. It claimed to inspect only this repository's prototypes and did not -- "rf-" is our
-- naming convention (ADR 0009), not a reserved namespace, so any mod that happened to define a
-- fluid matching the pattern would have taken this one down at load with a message telling the
-- player to edit OUR source. And it asked the wrong question: what matters is not what a fluid is
-- called but whether a heater can make it, because that is the only way a plasma reaches a reactor.
--
-- Asking the category answers exactly that, and it is our category. A fluid another mod produces
-- through it is genuinely a plasma a reactor cannot burn, which is worth refusing to load over
-- whoever wrote it.
local HEATING_CATEGORY = "rf-plasma-heating"

local function check_every_plasma_burns()
  for _, recipe in pairs(prototypes.recipe) do
    if recipe.category == HEATING_CATEGORY then
      for _, product in pairs(recipe.products or {}) do
        if product.type == "fluid" and not logic.fuels[product.name] then
          error(string.format(
            -- Both are labelled because a plasma recipe and the fluid it makes share a name, and
            -- naming them bare reads as a typo rather than as two prototypes.
            "the %s recipe '%s' produces the fluid '%s', which scripts/reactor-logic.lua has no " ..
            "fuel entry for -- so a reactor plumbed to it would hold it for ever and report " ..
            "itself starved. Add a row to M.fuels, or take the recipe out of that category.",
            HEATING_CATEGORY, recipe.name, product.name))
        end
      end
    end
  end
end

--- Refuse to run if the collector's boxes are not what deposit() thinks they are.
--
-- The third trap of the same shape, and the one most likely to fire: deposit() writes tritium to
-- box 1 and helium-3 to box 2 by index, because asking the fluidbox its filter every step for
-- every reactor is a cost paid ten times a second to learn something that cannot change while the
-- game is running. Swap the two declarations in prototypes/entities.lua and nothing complains --
-- the mod loads, the collector fills, and a player's tritium pipe quietly carries helium-3.
--
-- It deliberately does NOT check that the two fluids exist. They are the filters on the very boxes
-- being inspected, so a Core fluid that went missing or got renamed takes the data stage down with
-- Factorio's own error long before this runs. A check here would be unreachable code claiming to
-- guard the module seam.
local function check_collector_boxes()
  local boxes = prototypes.entity["rf-isotope-collector"].fluidbox_prototypes
  for index, expected in ipairs(COLLECTOR_BOXES) do
    local box = boxes[index]
    local filter = box and box.filter and box.filter.name
    if filter ~= expected then
      error(string.format(
        "rf-isotope-collector: control.lua deposits %s into box %d but the prototype filters that " ..
        "box to %s, so a by-product would leave through the wrong pipe. Reconcile " ..
        "COLLECTOR_BOXES in control.lua with prototypes/entities.lua.",
        expected, index, tostring(filter)))
    end
  end
end

local function check_prototypes()
  check_cadence()
  check_plasma_bounds()
  check_every_plasma_burns()
  check_collector_boxes()
end

-- The register is rebuilt in the same breath as the prototype checks because both are answers to
-- "the world may not be what this code last saw": one re-reads the map, the other re-reads the
-- prototypes. The build-event handlers that keep the register current in between are wired by
-- entity-management itself.
--
-- circuit.rescan() is the third answer to the same question, and it is not redundant with the
-- pruning update() does. A reactor removed while this mod was disabled never comes back through
-- update() at all -- its unit_number is simply absent from the rebuilt register -- so nothing
-- would ever destroy the combinator it left behind. It runs after entities.rescan() because it is
-- handed the register that call rebuilds.
script.on_init(function()
  check_prototypes()
  entities.rescan()
  circuit.rescan(entities.registry())
end)
script.on_configuration_changed(function()
  check_prototypes()
  entities.rescan()
  circuit.rescan(entities.registry())
end)

script.on_nth_tick(UPDATE_INTERVAL, update)

-- The reactor's signals sit on a companion entity a player cannot see, and the engine will not
-- offer it to a wire drag on its own -- the reactor outranks it for selection, and dragging a wire
-- is not a special case (ADR 0012). circuit-output moves the selection for as long as a wire is in
-- hand; installing it needs the reactor's name, which entity-management owns.
circuit.install(entities.REACTOR)
