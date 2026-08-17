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

-- The item a lithium blanket eats (#30). One name, stated here because this file is the only
-- thing that takes items out of a blanket, and checked against Core's prototype at load by
-- check_blanket_feed() below rather than trusted.
local LITHIUM = "rf-lithium"

--- Take up to `count` lithium out of a blanket, of whatever quality is in there.
--
-- Written the long way round rather than as one remove_item call, and this is not defensive
-- programming. An ItemStackDefinition with no `quality` means NORMAL quality, so
-- remove_item{name = LITHIUM, count = n} silently declines to touch uncommon lithium -- and Core's
-- rf-lithium-extractor allows quality modules, so under Space Age a player who puts one in
-- produces exactly that. The blanket would then sit on thousands of visible lithium items breeding
-- nothing at all, for ever, with no message anywhere. ADR 0003 tolerates Space Age rather than
-- targeting it, which still means not being broken by it.
--
-- Quality does not change what the blanket does with the lithium, and should not: a lithium
-- nucleus is a lithium nucleus, and the model counts nuclei. So every quality is spent alike, in
-- whatever order the inventory reports them.
local function take_lithium(blanket, count)
  local inventory = blanket.get_inventory(defines.inventory.chest)
  if not inventory then return 0 end
  local taken = 0
  for _, stack in pairs(inventory.get_contents()) do
    if stack.name == LITHIUM then
      taken = taken + inventory.remove({
        name = LITHIUM, count = count - taken, quality = stack.quality,
      })
      if taken >= count then break end
    end
  end
  return taken
end

--- Breed tritium from a reactor's neutrons in the blanket fitted to it, if there is one.
--
-- Returns what it bred, in fluid units, to be added to the reactor's products -- so blanket
-- tritium leaves through the same isotope collector the D-D by-products do, and a player plumbs
-- one pipe rather than two. See prototypes/entities.lua for why the blanket has no pipe of its
-- own and what that costs.
--
-- THE CHARGE, which is the only piece of state this adds.
--
-- Lithium is an item and tritium is a fluid, and a step breeds a fraction of an item's worth --
-- about a seventh of one at the shipped D-T rate. Rounding that up would breed for free and
-- rounding it down would breed nothing at all, so a blanket instead holds a CHARGE: it takes one
-- whole item out of the inventory, credits its nuclei, and breeds against that until it is spent.
-- That is also what a blanket physically is -- lithium loaded into a shell and consumed where it
-- sits -- so the state matches the object rather than papering over an accounting problem.
--
-- The charge is keyed by REACTOR rather than by blanket, and that is deliberate: two reactors may
-- share one blanket (entity-management), and a per-blanket charge would let the second reactor
-- breed against lithium the first one had already paid for.
local function blanket_breed(entity, neutrons)
  if not neutrons or neutrons <= 0 then return nil end
  local blanket = entities.blanket(entity)
  if not blanket then return nil end

  storage.blanket_charge = storage.blanket_charge or {}
  local charge = storage.blanket_charge[entity.unit_number] or 0

  -- Topped up to what this step can actually consume, not to one item.
  --
  -- One item per step was the first version and it was wrong twice over, found by measuring rather
  -- than by reading: it capped every blanket at one item's worth of tritium per step whatever the
  -- reactor was doing -- 10 units a second at the shipped cadence, against the 18.7 an ignited D-T
  -- reactor actually feeds it -- and it threw away the tail of every step that crossed the end of
  -- a charge, which showed up as a D-D blanket breeding 3.5% under what the physics says. Neither
  -- is visible from inside Factorio; the game just quietly breeds less.
  --
  -- Whole items still, because a player gets whole items back. What is left over stays as charge
  -- for the next step, so nothing is lost between steps.
  --
  -- The one place lithium can be lost is the part-item of charge in flight, and it goes with the
  -- REACTOR rather than with the blanket, because that is what the charge is keyed by: mining the
  -- blanket loses nothing at all -- put another one back and the leftover charge is still there --
  -- while removing the reactor discards it. At most one item either way.
  local per_item = logic.blanket.lithium_nuclei_per_item
  local wanted = logic.lithium_for(logic.blanket, neutrons)
  if charge < wanted then
    charge = charge + take_lithium(blanket, math.ceil((wanted - charge) / per_item)) * per_item
  end
  if charge <= 0 then return nil end

  local bred = logic.breed(logic.reactor, logic.blanket, neutrons, charge)
  if not bred then return nil end

  storage.blanket_charge[entity.unit_number] = charge - bred.nuclei_used
  return bred.tritium_units
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
  --
  -- The blanket is asked only once a collector has been found, and that is the one place this
  -- deliberately does NOT follow the compute-either-way rule above. Venting a by-product costs
  -- nothing, so computing it regardless is free; running a blanket into no collector would spend
  -- real lithium for nothing, which is a trap with no gameplay on the other side of it. So a
  -- blanket on a reactor with no collector is idle rather than wasteful, and keeps its lithium.
  --
  -- Overflow is not treated the same way and is left as it is: a collector already full has its
  -- tritium discarded by deposit(), lithium included, exactly as a reactor whose energy is not
  -- being carried away loses that. Every throughput limit in this mod shows up as output backing
  -- up, and a blanket is not worth making the exception.
  local collector = entities.collector(entity)
  if collector then
    local products = result.products
    local bred = blanket_breed(entity, result.neutrons)
    if bred and bred > 0 then
      -- A fresh table every step, so adding to it is safe; and a copy when the fuel breeds nothing
      -- of its own, which is the D-T case the blanket exists for.
      products = products or {}
      products["rf-tritium"] = (products["rf-tritium"] or 0) + bred
    end
    if products then deposit(collector, products) end
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

--- Refuse to run if a blanket cannot be fed, or if what it breeds has nowhere to go (#30).
--
-- The fourth trap of the same shape, across the module seam this time. Two things have to hold and
-- neither is visible from the file that depends on them:
--
-- The item. blanket_breed takes rf-lithium out of the blanket's inventory by name, and rf-lithium
-- is a RealisticFusionCore prototype (ADR 0010) -- so a rename on Core's side leaves this file
-- asking for an item that does not exist. remove_item on a missing prototype does not politely
-- return zero, and even if it did, a blanket that silently never breeds is exactly the failure
-- that takes a player an evening to find.
--
-- The outlet. Blanket tritium is deposited through the isotope collector rather than through a
-- pipe of the blanket's own, which is what lets the blanket be a plain container. That makes the
-- collector's tritium box load-bearing for this tier as well, and check_collector_boxes above
-- checks it is where deposit() writes -- but not that it exists to be written to at all if the
-- boxes were ever cut down to one. Both are cheap to state and neither can change at runtime.
local function check_blanket_feed()
  if not prototypes.item[LITHIUM] then
    error(string.format(
      "rf-lithium-blanket: control.lua feeds it the item '%s', which no loaded mod defines. It is " ..
      "a RealisticFusionCore prototype (ADR 0010) -- check that Core still declares it, or change " ..
      "LITHIUM in control.lua to whatever it was renamed to.", LITHIUM))
  end
  -- The blanket needs somewhere to put items at all. A container prototype with no inventory would
  -- load perfectly and never accept a single lithium.
  local blanket = prototypes.entity["rf-lithium-blanket"]
  if not blanket or (blanket.get_inventory_size(defines.inventory.chest) or 0) < 1 then
    error("rf-lithium-blanket: the prototype has no chest inventory, so no inserter can feed it " ..
      "lithium. Check inventory_size in prototypes/entities.lua.")
  end
  local outlet = false
  for _, expected in ipairs(COLLECTOR_BOXES) do
    if expected == "rf-tritium" then outlet = true end
  end
  if not outlet then
    error("rf-lithium-blanket: what the blanket breeds leaves through rf-isotope-collector, but " ..
      "COLLECTOR_BOXES in control.lua no longer lists rf-tritium -- so a blanket would consume " ..
      "lithium and deposit nothing. Give the blanket a fluid box of its own, or put the tritium " ..
      "box back.")
  end
end

local function check_prototypes()
  check_cadence()
  check_plasma_bounds()
  check_every_plasma_burns()
  check_collector_boxes()
  check_blanket_feed()
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
