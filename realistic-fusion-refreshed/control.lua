-- Runtime: the tick loop, reading and writing fluid boxes, and the invariants that tie the
-- simulation to the prototypes. Which reactors exist is scripts/entity-management.lua's business;
-- the physics is scripts/reactor-logic.lua's and does not know this file exists; what a reactor
-- reports to the player is scripts/circuit-output.lua's.

local logic    = require("scripts.reactor-logic")
local entities = require("scripts.entity-management")
local circuit  = require("scripts.circuit-output")

-- Which constants each reactor prototype is simulated with (#31). ADR 0010 names two reactors and
-- scripts/reactor-logic.lua holds a spec for each; this is the only place the two lists meet.
--
-- Keyed by prototype name and looked up per reactor per step, which is a table index against the
-- alternative of storing the spec beside the entity in the register -- state that would have to be
-- migrated, kept in step with a rename, and could go stale against a spec edit. The lookup cannot.
--
-- check_reactor_specs() below refuses to load if entity-management registers a reactor this table
-- has no entry for, because the failure is otherwise a nil index inside on_nth_tick on a live save.
local SPECS = {
  ["rf-reactor"]            = logic.reactor,
  ["rf-aneutronic-reactor"] = logic.aneutronic_reactor,
}

-- The same constants AS ONE FORCE RUNS THEM (#53).
--
-- Confinement time is researchable now, and research is per force, so SPECS above stopped being
-- the whole answer: two forces on one map run the same reactor prototype with different physics.
-- What resolves the difference is scripts/reactor-logic.lua's confinement ladder; what this holds
-- is the result, so no reactor ever reads force.technologies inside the tick loop.
--
-- [force_index][prototype name] -> the spec to hand step(). A force with nothing researched maps
-- STRAIGHT BACK to the module table rather than to a copy of it -- derive() returns `base`
-- unchanged -- so a fresh save allocates nothing at all and every reactor on it is running the
-- exact table the tests drive.
--
-- NOT IN `storage`, AND THAT IS THE WHOLE OF THE MIGRATION THIS FEATURE NEEDS. Factorio rebuilds
-- the Lua state on every load, so this table starts empty every time and is refilled from
-- force.technologies, which the save already carries. An existing save part way through the ladder
-- therefore gets exactly what its research says on the first tick after loading, and a rung added,
-- removed or renamed in a later version cannot leave a stale number behind because there is no
-- stored number to go stale. A migration script would have had to migrate precisely this, and
-- could only have got it wrong.
--
-- And it is why neither on_init nor on_configuration_changed clears it: a fresh Lua state has
-- nothing to clear, so a call there would read as diligence and do nothing at all.
--
-- ADR 0020 reaches the same place for capture_efficiency by a different route -- an argument to
-- step() rather than a spec per force -- and its four requirements are what this is built to meet:
-- reactor-logic stays free of anything Factorio, nothing is allocated per step, the answer is
-- cached per force, and it is invalidated on research rather than re-read in the loop. When that
-- ticket lands, its constant belongs in derive() beside this one.
local force_specs = {}

--- This force's version of one reactor's constants.
local function derive(base, force)
  local tau = logic.confinement_time(base, function(name)
    local technology = force.technologies[name]
    -- Guarded rather than indexed: a ladder rung whose technology prototype is missing is a
    -- developer error, and the useful behaviour is that the force simply has not researched it.
    -- check_confinement_ladder() below is what refuses to load over it, once, with a message.
    return technology ~= nil and technology.researched
  end)
  if tau == base.confinement_time_s then return base end

  local spec = {}
  for k, v in pairs(base) do spec[k] = v end
  spec.confinement_time_s = tau
  return spec
end

--- The constants to simulate this reactor with, for the force that owns it.
--
-- entity.force_index rather than entity.force.index: the same answer for one property read instead
-- of two, on a path that runs once per reactor per step. entity.force is fetched only on a cache
-- miss, which for a settled game is never.
local function spec_for(entity)
  local base = SPECS[entity.name]
  -- A reactor no technology moves -- rf-aneutronic-reactor, deliberately (see the ladder's note in
  -- scripts/reactor-logic.lua) -- never touches the cache at all.
  if not base.confinement_ladder then return base end

  local index = entity.force_index
  local by_force = force_specs[index]
  if not by_force then
    by_force = {}
    force_specs[index] = by_force
  end

  local spec = by_force[entity.name]
  if not spec then
    spec = derive(base, entity.force)
    by_force[entity.name] = spec
  end
  return spec
end

--- Drop everything, so the next reactor to be stepped rebuilds it.
--
-- The whole cache rather than the one force the event names, because the events below do not all
-- name one -- and because a force's entry is two table lookups to rebuild. There is no cost here
-- worth being clever about.
local function forget_force_specs()
  force_specs = {}
end

-- The temperature apply() stamps on the reactor energy it writes, memoised per reactor by
-- energy_temperature() below and taken from the prototype rather than hardcoded here. Nothing
-- reads it -- the exchanger and the converter both burn their fluid by fuel_value -- so this is
-- about what a player sees in the pipe and nothing else. See CONTEXT.md on HOST ARTEFACT (#46).
local ENERGY_TEMPERATURE = {}

-- Memoised at the point of use rather than filled by check_prototypes(), and that is not a
-- preference. check_prototypes() runs from on_init and on_configuration_changed only -- NOT from
-- on_load -- so a table filled there would be empty for every ordinary save load, apply() would
-- write a nil temperature, and the engine would quietly reset the fluid to its default. Which is
-- 15: exactly the literal this replaced, so the bug would have looked like nothing happening.
local function energy_temperature(name)
  local cached = ENERGY_TEMPERATURE[name]
  if cached then return cached end
  local resolved = prototypes.entity[name].target_temperature
  ENERGY_TEMPERATURE[name] = resolved
  return resolved
end

-- ADR 0005 pre-authorises throttling the simulation to a coarser cadence and requires that doing
-- so be a change in one place. This is that place: nothing else in the mod knows how often the
-- simulation steps, and the step itself is written in terms of elapsed seconds.
--
-- Ten steps a second, not sixty, on the strength of #24's measurement. Not because the per-tick
-- cost was unaffordable -- #24 put it at nine to eleven microseconds per reactor before throttling,
-- linear out to 200 of them, a ninth of a tick's budget at that size -- but because five of every
-- six of those steps bought nothing.
--
-- At the shipped cadence the step now costs about 2.5 microseconds per reactor with any of the four
-- reactions running, around 3% of a tick at 200 of them (#39, on a machine checked to be quiet;
-- earlier figures on that page were taken beside a compile and read nearly three times high).
--
-- The plasma's confinement time is thirty seconds, and stepping a thirty-second process every
-- sixteen milliseconds resolves nothing that a tenth of a second misses: equilibrium
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

-- Which of those boxes the blanket breeds into (#30). Resolved from the list above rather than
-- written down a second time, so the two cannot disagree, and required to exist by
-- check_blanket_feed() below -- apply() reads the box's headroom before letting a blanket spend
-- lithium, and a nil index there would be a crash ten times a second.
local TRITIUM = "rf-tritium"
local TRITIUM_BOX
for index, name in ipairs(COLLECTOR_BOXES) do
  if name == TRITIUM then TRITIUM_BOX = index end
end

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
      -- The box's own declared volume, not the segment the player has piped it into -- measured
      -- on a collector with its outlet on a run under #68, which is the arrangement this call
      -- meets in ordinary play. See docs/research/reactor-runtime-cost.md, finding 2.
      --
      -- REVIEWED UNDER #69 AND LEFT ALONE. This clamp is benign whichever way get_capacity reads,
      -- because the engine clamps a Lua write to the box regardless: over-reporting here would
      -- discard the excess rather than spend anything for it. That is not true one caller up, where
      -- the same figure decides how much LITHIUM to buy -- which is why that one is the subject of
      -- #69 and this one is a note.
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
-- @param headroom  how much tritium the collector can still take, in fluid units. Breeding is
--                  capped to it, which is what stops a blanket paying for tritium that deposit()
--                  would throw away -- see apply() for why that is not treated the way every
--                  other overflow in this mod is.
-- @param spec      the reactor's constants, for particles_per_unit -- the blanket breeds into the
--                  fluid units that reactor counts its plasma in, and #31 made that a question
--                  worth asking rather than one constant. Both shipped reactors declare the same
--                  1e20 on purpose (see M.aneutronic_reactor), so this changes nothing today and
--                  stops being right the moment a third one disagrees.
local function blanket_breed(entity, spec, neutrons, headroom)
  if not neutrons or neutrons <= 0 then return nil end
  if not headroom or headroom <= 0 then return nil end
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
  -- Capped to what the collector can actually take, BEFORE any lithium is drawn. Doing it after
  -- would be the bug this closes: the items would already be gone.
  local room = headroom * spec.particles_per_unit
  if wanted > room then wanted = room end
  if wanted <= 0 then return nil end

  if charge < wanted then
    charge = charge + take_lithium(blanket, math.ceil((wanted - charge) / per_item)) * per_item
  end
  if charge <= 0 then return nil end

  -- The cap reaches breed() as the charge, because breed() spends exactly what it breeds -- one
  -- nucleus per triton -- so bounding one bounds the other. Anything the headroom held back stays
  -- as charge and is bred on a later step rather than lost.
  local bred = logic.breed(spec, logic.blanket, neutrons, math.min(charge, wanted))
  if not bred then return nil end

  storage.blanket_charge[entity.unit_number] = charge - bred.nuclei_used
  return bred.tritium_units
end

--- Apply one reactor's step to the world.
local function apply(entity, spec, plasma, result)
  -- Spending straight out of the buffer rather than declaring a fixed prototype consumption: the
  -- network refills what was spent, so a brownout shows up as a plasma that cannot hold its
  -- temperature. Measured on a reactor given 10 kW instead of the 50 MW it wants: the buffer sits
  -- empty and the plasma never leaves six figures.
  --
  -- This used to claim the mechanism makes the draw "follow the simulation". It does not, and #37
  -- recorded as much when it closed: heating_power_w is a CONSTANT, so a supplied reactor draws
  -- the same 50 MW whether it is barely fusing or sitting at the clamp. Only the SHORTFALL follows
  -- anything. #46 rested part of its case on the retired claim.
  entity.energy = entity.energy - result.heating_used_j

  local box = entity.fluidbox

  -- Writing the plasma back is also how it is shared. Box 1 is the reactor's input-output box, so
  -- it belongs to the fluid segment it is plumbed into: a temperature written here is one every
  -- reactor on that run of rf-pipe works from next tick, mixed by the engine and by no code of
  -- ours (ADR 0011).
  --
  -- Each reactor reads and writes only its own share: a share of n out of a segment of N is given a
  -- rise computed against n, and the engine's mixing then dilutes it by n/N. As arithmetic that
  -- cancels, and this comment used to conclude from it that the pool gains the energy the reactor
  -- spent whatever else is on the run, "measured at 20 pipes against none".
  --
  -- IT DOES NOT, and #40 measured how much does arrive. One reactor with nothing plumbed to it keeps
  -- 95% of what it spent; the same one reactor on a twenty-pipe run keeps 75%; three reactors
  -- bridged together keep 58%. Two separate things are going on and the harness separates them:
  --
  --   * The engine's mixing is LOSSY. Flattening a temperature difference across a segment destroys
  --     about a fifth of the difference -- measured on reactors the simulation never touched at all,
  --     and confirmed by the one-reactor pair above, where nothing else can be to blame.
  --   * AND THE REST IS NOT MIXING. Three writers lose more than mixing alone accounts for. This
  --     comment used to name the shape of update() as the candidate -- two passes, each write
  --     replacing a box from the start-of-step pool, with the engine re-splitting between the Lua
  --     writes so that a reactor writing second overwrites the share of its neighbour's rise it had
  --     just been handed.
  --
  -- THAT MECHANISM DOES NOT EXIST, measured under #73 by scripts/check-pooling.ps1's `probe` row.
  -- A Lua write to one box on a run changes NO other box on that run in the same tick -- 0 of 12,
  -- against 12 of 12 moved six ticks later through the same instrument, which is the control that
  -- makes the nil a finding rather than a broken probe. The engine re-splits between TICKS, in its
  -- own fluid update after every handler has run. So the share a second writer would overwrite has
  -- not arrived yet, and it cannot be overwritten.
  --
  -- Confirmed from the other side by driving the candidates against each other: on identical rows
  -- from one identical state, with the writes 73% apart end to end at the instant they landed, the
  -- shipped two-pass shape, a single-pass shape and a two-pass shape with a relative write all keep
  -- 72.18% -- the same number to four figures. There is nothing to choose between them because the
  -- engine cannot tell them apart.
  --
  -- So NOTHING IN THIS FILE IS CHANGED, and now for a reason rather than for a deferral: the
  -- read-then-write shape is not what costs the excess. What does is not known. It is not the
  -- engine's mixing alone either, and the two cells that would separate the remaining candidates
  -- differ in fill and temperature as well as in writer count, so #40's comparison cannot settle it.
  -- docs/research/reactor-runtime-cost.md carries the numbers and scripts/check-pooling.ps1 the rig.
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
    --
    -- It is READ FROM THE PROTOTYPE rather than written as a literal, and that is the whole of
    -- #46's second item. This used to be a hardcoded 15, which is a number a player hovering the
    -- line reads as room temperature and therefore as a bug -- and 15 is exactly what the engine
    -- itself defaults an unset target_temperature to, so the literal was the absence of an answer
    -- rather than an answer. Deriving it means the pipe and the reactor's own tooltip cannot
    -- disagree, whatever the target is. That question -- #46's third item -- is now SETTLED: 550
    -- for rf-reactor and 165 for rf-aneutronic-reactor, for reasons that live beside each of them
    -- in prototypes/entities.lua.
    local produced = box[2]
    local amount = result.energy_units + (produced and produced.amount or 0)
    -- This box's own capacity. It used to say "the segment's, because get_capacity reports the
    -- segment" -- measured under #40 and that is true of a pipe and false of a machine: asked of a
    -- reactor's box, get_capacity answers the box's declared volume however long the run beyond it
    -- is. #40 measured that with NOTHING plumbed to this box, which is the case where the box and
    -- the segment are the same object; #68 re-took it with the box on a 27000-unit run and the
    -- answer is unchanged at the declared 1000. Nothing changes here, because the box is what a
    -- write is clamped to anyway; the reasoning was wrong rather than the code, and it would have
    -- justified writing more than a box can hold.
    --
    -- Overflow is discarded, which is the right behaviour and not an oversight: a reactor whose
    -- heat is not being carried away does not get to bank it. It shows up as output backing up.
    local capacity = box.get_capacity(2)
    if amount > capacity then amount = capacity end
    -- The reactor's OWN energy fluid, not one name the whole mod shares (#31). An aneutronic
    -- reactor sells rf-aneutronic-reactor-energy into a direct energy converter where a neutronic
    -- one sells rf-reactor-energy into a heat exchanger, and the two are deliberately not
    -- interchangeable -- see prototypes/fluids.lua. Writing the wrong one here would be rejected by
    -- the box's filter and lose the reactor's entire output silently, which is why
    -- check_energy_outlets() below ties this field to the prototype rather than trusting it.
    box[2] = {
      name = spec.energy_fluid,
      amount = amount,
      temperature = energy_temperature(entity.name),
    }
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
  -- A FULL collector is the same trap as a missing one, and is handled the same way. It was
  -- argued the other way first -- that overflow is discarded everywhere in this mod, so a backed-up
  -- collector losing blanket tritium is just another throughput limit showing up as output backing
  -- up -- and that analogy does not hold. What backs up elsewhere is energy and D-D by-products,
  -- which cost nothing to compute and nothing to throw away. This costs an item a player mined,
  -- concentrated and belted here, at about 19 a second on an ignited D-T reactor -- so a stopped
  -- consumer or a full tank would quietly eat a full blanket in nine minutes and show nothing for
  -- it. So the blanket breeds only into the room the collector actually has.
  --
  -- The by-products get first claim on that room because they are free, and what is left is what
  -- the blanket may pay for. Nothing is lost by being held back: unbred lithium stays as lithium.
  --
  -- ALL THREE TERMS ARE THE BOX'S, WHICH IS THE WHOLE OF #69 AND IS MEASURED RATHER THAN ASSUMED.
  -- get_capacity answers a box's own declared volume even when that box is piped into a segment
  -- fifty times its size (#68: 500 against a 27 000-unit run of twenty pipes and a tank; the cell
  -- named below is a different rig with a shorter run, so its figure is 25 300 rather than 27 000
  -- and neither is stale), and fluidbox[i].amount is that same
  -- box's contents -- so a capacity and a held amount subtract cleanly instead of mixing a segment
  -- with a share. Had it been the segment's, this expression would over-report the room by the
  -- whole downstream volume in the arrangement a player actually builds -- collector piped to a
  -- tank -- and the blanket would buy tritium the collector cannot take, which is exactly the trap
  -- the paragraph above is written about.
  --
  -- check-blanket.ps1's `flooded` cell holds that: a collector at 95% whose outlet is piped into a
  -- run that has been filled, so the room is 25 units in the box and 300 downstream against a
  -- segment that reads 25 300. The blanket buys 326 items. With this line reading the segment it
  -- buys 1 887 and throws 1 562 of them away, which is what the cell was checked against.
  local collector = entities.collector(entity)
  if collector then
    local products = result.products
    local held = collector.fluidbox[TRITIUM_BOX]
    local headroom = collector.fluidbox.get_capacity(TRITIUM_BOX)
      - (held and held.amount or 0)
      - ((products and products[TRITIUM]) or 0)
    local bred = blanket_breed(entity, spec, result.neutrons, headroom)
    if bred and bred > 0 then
      -- A fresh table every step, so adding to it is safe; and a copy when the fuel breeds nothing
      -- of its own, which is the D-T case the blanket exists for.
      products = products or {}
      products[TRITIUM] = (products[TRITIUM] or 0) + bred
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
      -- The reactor's own constants (#31), as this reactor's OWNER has researched them (#53).
      -- check_reactor_specs() guarantees SPECS is never nil for anything the register can hold, so
      -- spec_for has no fallback on purpose: a fallback would silently simulate an aneutronic
      -- reactor as a neutronic one, which looks like a balance problem rather than a missing entry.
      local spec = spec_for(entity)
      local plasma = entity.fluidbox[1]
      local result = logic.step(spec, plasma and plasma.name, plasma and plasma.amount,
        plasma and plasma.temperature, entity.energy, dt)

      -- Reported from the read pass, on the state the step was computed against, so a reactor
      -- describes the tick it just simulated rather than one it is part way through. It happens
      -- here and not in the write pass because a reactor with nothing to simulate has no entry
      -- there at all, and "starved of plasma" is exactly the state that reactor is in and the one
      -- worth showing.
      if reporting then circuit.publish(entity, result, plasma and plasma.amount, spec) end

      if result then
        pending[#pending + 1] = { entity = entity, spec = spec, plasma = plasma, result = result }
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
    apply(step.entity, step.spec, step.plasma, step.result)
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
-- Over every reactor rather than rf-reactor alone (#31). The aneutronic one draws four times the
-- heating against four times the buffer, so it passes at the same interval -- but the two numbers
-- are on different prototypes now and nothing else would notice one moving without the other.
--
-- IT CHECKS AGAINST A BUFFER 6.7% SMALLER THAN THE ONE THE ENTITY HAS, and deliberately so. The
-- engine holds 16/15 of the declared buffer_capacity -- exactly, measured at four capacities and
-- four inflow limits by scripts/check-buffer.ps1 (#71) -- while buffer_capacity here reports the
-- declared figure. So the real ceiling at 50 MW is 12.8 ticks where this allows 12. Left
-- conservative rather than corrected by a ratio: an interval is a whole number of ticks, so the
-- 0.8 buys nothing, and a hardcoded 16/15 would be this file believing an engine constant no
-- prototype states. See docs/research/reactor-runtime-cost.md.
local function check_cadence()
  for name, spec in pairs(SPECS) do
    local source = prototypes.entity[name].electric_energy_source_prototype
    local needed = spec.heating_power_w * UPDATE_INTERVAL / 60
    if needed > source.buffer_capacity then
      error(string.format(
        "%s: UPDATE_INTERVAL of %d ticks needs %.3g J of buffer per step but the prototype " ..
        "has %.3g J, so the reactor would be starved every step. Lower the interval in control.lua " ..
        "or raise buffer_capacity in prototypes/entities.lua.",
        name, UPDATE_INTERVAL, needed, source.buffer_capacity))
    end
  end
end

--- Refuse to run if a reactor on the map has no constants to be simulated with (#31).
--
-- entity-management decides what a reactor IS and this file decides what one DOES, and those two
-- lists are written down separately -- deliberately, because requiring one from the other would
-- install runtime event handlers into the data stage and into the test suite. This is the seam
-- that makes the separation safe.
--
-- Without it, adding a third reactor prototype to entity-management and forgetting the spec here
-- gives a mod that loads, builds and runs, and throws on a nil index inside on_nth_tick the first
-- moment a player puts plasma in one. With it, the mod refuses to load and says which name is
-- missing.
local function check_reactor_specs()
  for _, name in ipairs(entities.REACTORS) do
    if not SPECS[name] then
      error(string.format(
        "scripts/entity-management.lua registers '%s' as a reactor but control.lua's SPECS has no " ..
        "constants for it, so it would be simulated with nil. Add a spec to " ..
        "scripts/reactor-logic.lua and a row to SPECS.", name))
    end
    if not prototypes.entity[name] then
      error(string.format(
        "scripts/entity-management.lua registers '%s' as a reactor but no such entity prototype " ..
        "exists. Add it to prototypes/entities.lua or take the name out of REACTORS.", name))
    end
  end

  -- And the other direction, which is the one that bites on a RENAME rather than on an addition.
  -- check_cadence and check_energy_outlets both walk SPECS and index the entity prototype straight
  -- through, so a key left behind after a prototype was renamed or dropped is "attempt to index a
  -- nil value" pointing into one of those functions -- not the named diagnostic the comments around
  -- them promise. The loop above cannot see it, because it starts from the other list.
  local registered = {}
  for _, name in ipairs(entities.REACTORS) do registered[name] = true end

  for name in pairs(SPECS) do
    if not prototypes.entity[name] then
      error(string.format(
        "control.lua's SPECS holds constants for '%s', which is not an entity prototype -- so the " ..
        "checks below would index nil. Drop the row, or reconcile the name with " ..
        "prototypes/entities.lua.", name))
    end
    -- And the case that is not a crash at all, which is why it needs saying. A reactor with a
    -- prototype and a spec but no entry in entity-management's REACTORS passes every other guard
    -- here: this loop finds it, check_cadence and check_energy_outlets and check_plasma_bounds all
    -- walk SPECS and are satisfied, and the two loops that walk REACTORS simply never see it. What
    -- a player gets is a reactor that builds, accepts plasma, and is never registered or stepped --
    -- the "looks like a balance problem" failure this whole function exists to prevent, arriving
    -- through the one door the other checks leave open. The comment on SPECS tells the next editor
    -- that this is where the two lists meet; this is what makes that true in both directions.
    if not registered[name] then
      error(string.format(
        "control.lua's SPECS holds constants for '%s' but scripts/entity-management.lua does not " ..
        "register it as a reactor, so nothing would ever simulate one. Add it to REACTORS there, " ..
        "or drop the row here.", name))
    end
  end
end

--- Refuse to run if a reactor's output would be written into a box that will not take it (#31).
--
-- apply() writes spec.energy_fluid into box 2, and box 2 is filtered on the prototype. Those are
-- two files apart and there are two of each now, so the mistake is available: give the aneutronic
-- reactor rf-reactor-energy in its spec, or swap the filters, and the mod loads perfectly while
-- every reactor of that kind silently produces nothing at all. Not a crash -- a rejected write --
-- which is the kind of failure a player reports as "my reactors do not work" a week later.
--
-- The consumer is checked too, and it is the other half of the same question. A fluid nothing burns
-- is a reactor that fills its box and stops; #28's rf-d-d-fusion had exactly this problem with
-- steam turbines and it was found on review rather than by the game.
local function check_energy_outlets()
  for name, spec in pairs(SPECS) do
    local boxes = prototypes.entity[name].fluidbox_prototypes
    local outlet = boxes[2]
    local filter = outlet and outlet.filter and outlet.filter.name
    if filter ~= spec.energy_fluid then
      error(string.format(
        "%s: the simulation sells %s but the prototype's output box is filtered to %s, so every " ..
        "unit the reactor produced would be rejected. Reconcile energy_fluid in " ..
        "scripts/reactor-logic.lua with prototypes/entities.lua.",
        name, spec.energy_fluid, tostring(filter)))
    end

    local fluid = prototypes.fluid[spec.energy_fluid]
    if not fluid then
      error(string.format("%s: sells the fluid '%s', which no loaded mod defines.",
        name, spec.energy_fluid))
    end
    -- fuel_value is what makes a unit of this worth a joule to whatever burns it. Zero would load,
    -- pipe and fill exactly as it does now, and generate no power anywhere.
    if (fluid.fuel_value or 0) <= 0 then
      error(string.format(
        "%s: sells '%s', which has no fuel_value -- so a heat exchanger or converter burning it " ..
        "would produce nothing. Set one in prototypes/fluids.lua.", name, spec.energy_fluid))
    end

    -- The temperature apply() stamps on that fluid has to be one the fluid can hold. Cheap to
    -- check and newly load-bearing: since #46 the stamp is the reactor's own target_temperature
    -- rather than a literal 15. prototypes/fluids.lua declares max_temperature on both energy
    -- fluids for exactly this reason; this is what stops the pair drifting.
    --
    -- THE STATED REASON IS NARROWER THAN IT WAS. This said an over-range target "would make every
    -- write fail". #101 measured that the ENGINE's own boiler conversion does no such thing: it
    -- stamped output at 500 C and at 5000 C against a declared maximum of 165 and neither clamped
    -- nor refused. What that probe did NOT test is this file's path -- apply() reaches box 2
    -- through a Lua write, which is not the boiler's internal transfer, and whether a Lua write
    -- above max_temperature clamps, throws or is dropped is unmeasured. So this guard is
    -- deliberately conservative: it fails the mod at load rather than shipping a write nobody has
    -- characterised. Do not relax it on the strength of the engine being permissive elsewhere --
    -- measure this path first. See docs/research/target-temperature.md.
    -- Never nil to guard against: the 2.0.77 LuaEntityPrototype docs say target_temperature
    -- "Defaults to 15 if not set", so the read below always answers a number even for a boiler
    -- that declares none. Which is why energy_temperature()'s memo is safe to key on truthiness.
    local target = prototypes.entity[name].target_temperature
    if target > fluid.max_temperature then
      error(string.format(
        "%s: stamps its output at the prototype's target_temperature of %s C, but '%s' holds at " ..
        "most %s C -- so every unit the reactor produced would be rejected. Raise " ..
        "max_temperature in prototypes/fluids.lua or lower the target in prototypes/entities.lua.",
        name, tostring(target), spec.energy_fluid, tostring(fluid.max_temperature)))
    end

    -- Somewhere for it to go. Any entity that is not this reactor and has a fluid box filtered to
    -- the fluid will do -- rf-heat-exchanger for one tier, rf-direct-energy-converter for the
    -- other -- and asking the question that loosely is deliberate: what matters is that the fluid
    -- is not a dead end, not which prototype type ends it.
    local consumed = false
    for other, prototype in pairs(prototypes.entity) do
      if other ~= name then
        for _, box in pairs(prototype.fluidbox_prototypes or {}) do
          if box.filter and box.filter.name == spec.energy_fluid then
            consumed = true
            break
          end
        end
      end
      if consumed then break end
    end
    if not consumed then
      error(string.format(
        "%s: sells '%s' and nothing in the game has a fluid box that accepts it, so the reactor " ..
        "would fill its output box and stop. Give the tier a converter, or point it at one that " ..
        "exists.", name, spec.energy_fluid))
    end
  end
end

--- Refuse to run if a reactor has no combinator to put its signals on (#31).
--
-- The name is derived from the reactor's rather than listed -- circuit-output builds
-- "<reactor>-signals" -- which is what lets a third reactor need no change in that file. What
-- derivation costs is that a missing prototype is discovered at the moment of use: create_entity
-- on an unknown name throws inside the reporting pass, on a live save, the first time a reactor of
-- that kind is built.
--
-- THE MOVING CORE IS NOT CHECKED HERE, and not for want of trying. reactor-animation.lua derives
-- "<reactor>-core" exactly the same way and has exactly the same failure, but animation prototypes
-- are a data-stage type the runtime does not expose -- `prototypes.animation` is not a key, which
-- this check found out by being written and throwing. So that one is covered by the rigs instead:
-- scripts/check-aneutronic.ps1 runs a reactor of each kind until it is fusing, which is the call
-- that would throw, and a missing animation fails there rather than never.
local function check_reactor_companions()
  for _, name in ipairs(entities.REACTORS) do
    if not prototypes.entity[name .. "-signals"] then
      error(string.format(
        "%s: scripts/circuit-output.lua puts its signals on '%s-signals', which no mod defines -- " ..
        "so the reactor would throw the first time it reported. Add it to prototypes/signals.lua.",
        name, name))
    end
  end
end

--- Refuse to run if a tier makes steam nothing in its own closure can drink (#36).
--
-- THE OTHER HALF OF THE PREREQUISITE CLOSURE, and the half no check enforced. check-aneutronic.ps1
-- and check-blanket.ps1 assert that everything a technology's recipes CONSUME is reachable inside
-- its own prerequisites -- buildable at the near end. This asserts the far end: that what the tier
-- produces has somewhere to go. rf-heat-exchanger inherits vanilla heat-exchanger's 500 C steam,
-- and vanilla unlocks the only thing that drinks it -- steam-turbine -- from nuclear-power, behind
-- uranium processing and nowhere in rf-d-d-fusion's closure. Without a sink a player researches
-- fusion, builds the whole chain, and has nowhere to put the steam. That is not a crash and not a
-- load failure; it is a dead end that only shows up in a game.
--
-- #36 settled how that gap is closed: rf-d-d-fusion unlocks vanilla's steam-turbine itself, which
-- accepts that the turbine becomes available before nuclear power. This check is deliberately
-- indifferent to WHICH answer holds -- it looks for any reachable sink, so the decision could be
-- revisited in favour of an rf-turbine or a nuclear-power prerequisite without touching it. What it
-- refuses is having no answer at all, which is the state #23 shipped and review caught by reading.
--
-- OVER THIS MOD'S TECHNOLOGIES ONLY, by name prefix. The rule is general but the standing is not:
-- base's own heat-exchanger passes trivially because nuclear-power unlocks its turbine in the same
-- technology, and a third-party tier that fails this is not ours to fail a load over. Recipes
-- enabled from the start are not considered as SOURCES -- they belong to no technology, so there is
-- no closure to be outside of -- but they are considered as sinks, for the reason the candidates()
-- helper below gives.
--
-- IT REFUSES ONLY THE DEAD END. No sink at all is a load failure; a sink that exists but is rated
-- below our steam is logged and allowed, because that rating usually belongs to a prototype another
-- mod owns. See the comment on the two outcomes below.
--
-- WHICH MEANS #36'S OWN GAP IS THE WARNING, NOT THE ERROR -- and the reason is that #36 slightly
-- overstates it. "Nowhere to put the steam" is not quite true: vanilla steam-engine is a generator
-- that drinks steam, its recipe is enabled from tick 0, and it is rated to 165 C. So a player with
-- rf-d-d-fusion and no turbine could always route 500 C steam into steam engines and get power --
-- while throwing away two thirds of the heat. That is a bad tier, not a broken one. Removing the
-- steam-turbine unlock therefore produces this check's log line naming steam-engine, not its error.
--
-- The two severities map onto #36's acceptance criterion exactly as written: "can still convert the
-- exchanger's steam to electricity" is the error, and it holds. Converting it *well* is the warning.
-- A hard gate on the decision would have to assert the turbine specifically, which is the one thing
-- this check must not do if the answer is to stay revisitable.
--
-- Reachability is judged by the tree rather than by researching it: a recipe unlocked by any
-- technology in the closure counts as available. That trusts the tree to mean what it says, which
-- is weaker than a rig that researches the closure on a live force and reads force.recipes -- the
-- shape check-aneutronic.ps1 uses. It is what fits an on_init check, where nothing is researched
-- yet; if a tier ever needs the stronger claim, that rig is the place for it.
local function check_steam_sinks()
  -- EVERY RECIPE A PLAYER COULD HAVE, which is not the same set on the sink side as on the source
  -- side. A source has to be unlocked by a technology to be the tier's problem; a SINK only has to
  -- be available, and a recipe enabled from tick 0 belongs to no technology at all. Vanilla
  -- steam-engine is the case that matters: a generator rated to 165 C whose recipe every player has
  -- in the first minute. Judging sinks by unlocks alone would refuse to load over a low-temperature
  -- tier whose steam the starting equipment could already drink.
  local from_start = {}
  for name, recipe in pairs(prototypes.recipe) do
    if recipe.enabled then from_start[name] = true end
  end
  local function candidates(unlocked)
    local all = {}
    for name in pairs(from_start) do all[name] = true end
    for name in pairs(unlocked) do all[name] = true end
    return all
  end

  -- What a recipe puts on the map, if anything.
  local function placed_by(recipe_name)
    local recipe = prototypes.recipe[recipe_name]
    for _, product in pairs(recipe and recipe.products or {}) do
      if product.type == "item" then
        local item = prototypes.item[product.name]
        if item and item.place_result then return item.place_result end
      end
    end
  end

  -- Every recipe unlocked by a technology or anything it transitively requires, itself included.
  local function reachable_recipes(tech_name, found, seen)
    if seen[tech_name] then return found end
    seen[tech_name] = true
    local tech = prototypes.technology[tech_name]
    if not tech then return found end
    for _, effect in pairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" then found[effect.recipe] = true end
    end
    for prerequisite in pairs(tech.prerequisites) do
      reachable_recipes(prerequisite, found, seen)
    end
    return found
  end

  for tech_name, tech in pairs(prototypes.technology) do
    if tech_name:sub(1, 3) == "rf-" then
      -- The closure is what a SINK may be found in; only this technology's OWN unlocks are checked as
      -- sources. Both halves matter and they are not symmetric.
      --
      -- A closure contains its prerequisites' unlocks, so iterating it for sources asks the same
      -- question about rf-heat-exchanger once for every technology downstream of rf-d-d-fusion --
      -- and the answer cannot differ, because a descendant's closure is a superset of the unlocking
      -- technology's. If the technology that unlocks a source has a sink, every technology that
      -- requires it has the same sink. So the extra passes could only ever agree, and what they
      -- actually produced was the same warning logged three times over.
      --
      -- Checking the unlocking technology alone is therefore equivalent, not a weakening: a source
      -- is unlocked exactly once from our side, and that is the tier whose closure has to answer for
      -- it.
      local recipes = reachable_recipes(tech_name, {}, {})
      local unlocks = {}
      for _, effect in pairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
      end
      for recipe_name in pairs(unlocks) do
        local source = placed_by(recipe_name)
        -- A boiler with a target_temperature and an output box is a steam source whatever it is
        -- called. Asked of the prototype rather than of a list, so a tier that adds one is covered
        -- by having been added.
        --
        -- THE TYPE GUARD IS NOT DEFENSIVE, it is required. target_temperature is documented as
        -- optional, which reads like "nil when absent" and is not what it means: reading it on
        -- anything that is not a boiler or fusion-reactor THROWS "Entity is not boiler or
        -- fusion-reactor", and this loop sees every entity every reachable recipe places. Found by
        -- running load-check.ps1, which is the only way it could have been.
        --
        -- Boilers only, not fusion-reactors: Space Age's fusion reactor also carries the field, but
        -- what it makes is plasma rather than steam and no tier of ours unlocks one.
        local hot = source and source.type == "boiler" and source.target_temperature
        -- BY ROLE, NOT BY INDEX. fluidbox_prototypes[2] is the output box on rf-reactor -- which is
        -- what check_energy_outlets above indexes, correctly for the prototype it looks at -- but
        -- not on rf-heat-exchanger, where the energy_source's own box shifts the order and [2] is
        -- the water input. An earlier version of this check indexed [2] and reported the exchanger
        -- as making "water at 500 C", which is how the ordering came to light.
        local steam
        if hot then
          for _, box in pairs(source.fluidbox_prototypes) do
            if box.production_type == "output" and box.filter then
              steam = box.filter.name
              break
            end
          end
        end
        -- HEATING IS WHAT MAKES A BOILER A STEAM SOURCE, not being of type boiler. The first
        -- version of this check asked only the type and failed on rf-isotope-collector, which is a
        -- boiler prototype because that shape gives it the boxes it needs -- control.lua writes
        -- by-products into it -- and whose output is helium-3 at 15 C, the fluid's own default. It
        -- adds no heat, so there is nothing for a turbine to take and nothing to be a dead end.
        -- A source that raises its output above the fluid's default temperature is doing the thing
        -- this check is about; one that does not is moving fluid.
        local fluid = steam and prototypes.fluid[steam]
        -- THE TWO HOPS ARE SPLIT BY HOW THE FLUID CARRIES ITS JOULES, and getting that wrong is what
        -- the second version of this check did. rf-reactor is a boiler too (ADR 0012: it is one so
        -- that mode = "output-to-separate-pipe" gives it plasma in and energy out), and it raises
        -- rf-reactor-energy to 550 C -- so it looked like a steam source whose sink had to be a
        -- generator, and rf-heat-exchanger is not one. But reactor energy carries its joules in its
        -- fuel_value, not in its temperature, and the thing that cashes it is a boiler.
        --
        -- So: a fluid with a fuel_value is somebody's fuel and check_energy_outlets above owns that
        -- hop -- it already asserts the fuel_value exists and that something has a box for it. A
        -- fluid without one carries its energy as heat, and the only way to cash heat is a generator
        -- rated for the temperature. This check owns that hop, and only that hop.
        if fluid and (fluid.fuel_value or 0) == 0 and hot > fluid.default_temperature then
          -- TWO OUTCOMES, NOT ONE, and the difference is what another mod is allowed to do to us.
          -- No sink at all is the dead end #36 is about: the steam has nowhere to go and the tier
          -- does not work. A sink that exists but is rated below our steam is a different and much
          -- milder thing -- the generator runs, throws the excess heat away, and the player loses
          -- efficiency rather than the ability to play.
          --
          -- Only the first is worth refusing to load over, and the reason is not taste. hot is our
          -- number but maximum_temperature belongs to whatever drinks it, and that is frequently a
          -- prototype we do not own: bobpower sets vanilla steam-turbine to 465 C
          -- (bobpower/prototypes/entity/steam-turbines.lua), so a rating comparison that called
          -- error() would let a third-party mod make this one unloadable. Worse than unloadable --
          -- check_prototypes() runs from on_configuration_changed as well as on_init, so it would
          -- break saves already in progress, and the message would tell the player to go and edit
          -- our technology tree about a mod interaction they did not cause.
          local sink, cool_sink, cool_rating
          for candidate in pairs(candidates(recipes)) do
            local entity = placed_by(candidate)
            -- maximum_temperature is a generator's ceiling, so a turbine rated below the steam it
            -- is offered is not a sink: the engine would run it, throw the excess heat away, and
            -- the tier would look like it worked while paying for steam it could not use.
            --
            -- get_max_energy_production() rather than the max_energy_production attribute, which
            -- LuaEntityPrototype does not have in 2.0.77 -- the quality system made these getters
            -- and reading the field throws "doesn't contain key". Found by running this, not by
            -- reading: the documentation page lists both forms.
            --
            -- Type-guarded for the same reason the source is: maximum_temperature is a generator's
            -- field and reading it on anything else throws. No identity test against the source is
            -- needed -- a prototype cannot be both a boiler and a generator, so the type guards
            -- already exclude it.
            if entity and entity.type == "generator"
              and (entity.get_max_energy_production() or 0) > 0 then
              for _, box in pairs(entity.fluidbox_prototypes) do
                if box.filter and box.filter.name == steam then
                  local rating = entity.maximum_temperature or 0
                  if rating >= hot then
                    sink = entity.name
                  elseif rating > (cool_rating or -1) then
                    cool_sink, cool_rating = entity.name, rating
                  end
                  break
                end
              end
            end
            if sink then break end
          end
          if not sink and not cool_sink then
            error(string.format(
              "%s: unlocks %s, which makes %s at %d C, and nothing a player could have by then " ..
              "drinks it to make electricity -- so they could research the tier, build the chain " ..
              "and have nowhere to put the steam. Unlock a turbine here (see #36), or name a " ..
              "technology that does as a prerequisite.",
              tech_name, source.name, steam, hot))
          elseif not sink then
            log(string.format(
              "realistic-fusion-refreshed: %s makes %s at %d C and the best-rated sink reachable from %s is " ..
              "%s, " ..
              "rated %d C -- the steam will be drunk but the heat above that thrown away. Not " ..
              "refused, because the rating usually belongs to a prototype another mod owns.",
              source.name, steam, hot, tech_name, cool_sink, cool_rating))
          end
        end
      end
    end
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
-- Over every reactor as well as every fuel (#31), which is a square rather than a list and is
-- correct for the reason the loop over fuels was: the input box is unfiltered, so ANY plasma can
-- reach ANY reactor, and the pair that would crash is whichever spec's clamps are widest against
-- whichever fluid's range is narrowest. Both shipped reactors declare the same bounds, so this
-- checks four pairs to prove one thing -- and the day a tier wants a hotter clamp, it is the pair
-- it forgot that this names.
-- ~~MEASURED AND NOT FIXED, 2026-08-24 (#119, found by #55) ... Left alone here because choosing
-- between comparing at float32 precision, allowing a tolerance, and requiring the ceiling to be
-- representable is a decision rather than a correction; #119 carries it.~~ FIXED 2026-08-26 (#119,
-- PR #124), and the fix is the first thing the function does -- see below. The reading chosen was
-- the third: a bound must BE representable, and one that is not is refused by name rather than
-- tolerated. 6.9e9 -- the ceiling #54 proposed -- stores as 6899999744; 2e9, 4e9 and 5e9 are all
-- exact, and 5e9 being exact is why the shipped ceiling clears this check at all, which ADR 0025
-- chose it partly on account of.
local function check_plasma_bounds()
  -- FIRST, THAT THE COMPARISON BELOW CAN MEAN ANYTHING (#119). A fluid hands max_temperature back at
  -- SINGLE precision while the spec's number is a double, so a bound that is not exactly
  -- representable comes back as whichever float32 is NEAREST -- lower for 6.9e9, higher for
  -- 6.96271e9 -- and the comparison below fires over two numbers that were typed identically and
  -- print identically. That is not a contradiction to report; it is a question that cannot be
  -- asked yet.
  --
  -- So the ceiling has to BE representable, which is #119's decision rather than this code's: see
  -- M.float32_exact in scripts/reactor-logic.lua for the two readings that were rejected and why the
  -- strict one is affordable. Refusing here rather than tolerating it means the message can name the
  -- value that works, which is the whole difference between an hour lost and a one-line fix.
  for reactor, spec in pairs(SPECS) do
    -- EACH BOUND IS SUGGESTED IN THE DIRECTION THAT KEEPS IT. Rounding a ceiling down and a floor
    -- up both narrow the range rather than widen it, so taking the advice can never carry a value
    -- past the bound it was chosen under. The other direction would hand back a minimum below the
    -- one asked for, which is the exact failure the comparison further down exists to catch.
    for _, bound in ipairs({
      { label = "max_temperature_c", value = spec.max_temperature_c,
        nearest = logic.float32_floor, side = "at or below" },
      { label = "min_temperature_c", value = spec.min_temperature_c,
        nearest = logic.float32_ceil, side = "at or above" },
    }) do
      if not logic.float32_exact(bound.value) then
        local usable = bound.nearest(bound.value)
        local gap = bound.value - usable
        error(string.format(
          "%s: %s is %.10g, which a 32-bit float cannot hold exactly. The engine stores every fluid " ..
          "temperature at single precision, so this value and the one it is compared against in " ..
          "prototypes/fluids.lua come back different and the check below would report two numbers " ..
          "that print the same. Use %.10g -- the nearest value %s it that a float32 does hold " ..
          "exactly, %.10g C away (#119).",
          reactor, bound.label, bound.value, usable, bound.side, gap < 0 and -gap or gap))
      end
    end
  end

  for name in pairs(logic.fuels) do
    local fluid = prototypes.fluid[name]
    if not fluid then
      error(string.format(
        "scripts/reactor-logic.lua burns %s but no such fluid exists. Add it to " ..
        "prototypes/fluids.lua or drop the row.", name))
    end
    for reactor, spec in pairs(SPECS) do
      if spec.min_temperature_c < fluid.default_temperature
        or spec.max_temperature_c > fluid.max_temperature then
        error(string.format(
          "%s: the simulation clamps temperature to [%.6g, %.6g] C but %s accepts " ..
          "[%.6g, %.6g], so a reactor would write a temperature the fluid cannot hold. Reconcile " ..
          "scripts/reactor-logic.lua with prototypes/fluids.lua.",
          reactor, spec.min_temperature_c, spec.max_temperature_c, name,
          fluid.default_temperature, fluid.max_temperature))
      end
    end
  end
end

--- Refuse to load a temperature ceiling a circuit signal cannot carry (#55).
--
-- THE SIBLING OF check_plasma_bounds ABOVE, and it belongs beside it because it closes the other
-- half of the same question. That one ties the simulation's ceiling to what the FLUID can hold;
-- this one ties it to what the WIRE can report. A ceiling can satisfy the first and fail the
-- second, and the failure is worse for being quiet: the fluid accepts the temperature, the reactor
-- runs correctly, and the number a player reads stops moving.
--
-- THE CEILING IS NO LONGER SET BY THE INTEGER (#57, ADR 0025), and this comment used to say it was.
-- Why, what a wire carries now, and why this check is kept although it can no longer fire:
-- scripts/circuit-output.lua, at TEMPERATURE_SCALE. That is the one place it is written down.
--
-- The decision is that file's rather than this function's: it owns both INT32_MAX and the scale, and
-- knows what a wire carries. Keeping the comparison there is what lets
-- tests/test-circuit-output.lua break it. This supplies the loop and the message.
--
-- Over every reactor, because the ceiling lives on the spec and a second reactor may declare its
-- own. Both shipped reactors currently name 5e9 (#58), so this checks two specs to prove one thing --
-- and the day a tier wants a hotter clamp, it is the one someone forgot that this names.
--
-- IT RUNS AFTER check_plasma_bounds AND IS NOW ALWAYS MASKED BY IT IN PRACTICE. That check throws
-- first, and it ties the ceiling to what the FLUID accepts -- a bound far under 2.1e12 C. So any
-- ceiling big enough to reach this one fails that one first, which is another way of saying this
-- guard is slack rather than live.
--
-- ~~Verified end to end at 4e9, which is float32-exact and therefore reaches here.~~ It did before
-- #57; 4e9 is carried comfortably now and proves nothing. Breaking this guard means breaking the
-- scale, which tests/test-circuit-output.lua does directly rather than through a game.
local function check_signal_ceiling()
  for name, spec in pairs(SPECS) do
    local shown = circuit.unrepresentable(spec.max_temperature_c)
    if shown then
      error(string.format(
        "%s: the simulation clamps temperature to %.6g C, but a wire carries thousands of degrees " ..
        "in a 32-bit integer and so stops at %.6g C, meaning every reactor of this kind would " ..
        "report %d for ever instead of its own plasma temperature. Lower max_temperature_c in " ..
        "scripts/reactor-logic.lua, or raise TEMPERATURE_SCALE in scripts/circuit-output.lua -- " ..
        "and if you raise the scale, read what it costs the bottom of the range first (ADR 0025).",
        name, spec.max_temperature_c, circuit.INT32_MAX * circuit.TEMPERATURE_SCALE, shown))
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
-- is a realistic-fusion-refreshed-core prototype (ADR 0010) -- so a rename on Core's side leaves this file
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
      "a realistic-fusion-refreshed-core prototype (ADR 0010) -- check that Core still declares it, or change " ..
      "LITHIUM in control.lua to whatever it was renamed to.", LITHIUM))
  end
  -- The blanket needs somewhere to put items at all. A container prototype with no inventory would
  -- load perfectly and never accept a single lithium.
  local blanket = prototypes.entity["rf-lithium-blanket"]
  if not blanket or (blanket.get_inventory_size(defines.inventory.chest) or 0) < 1 then
    error("rf-lithium-blanket: the prototype has no chest inventory, so no inserter can feed it " ..
      "lithium. Check inventory_size in prototypes/entities.lua.")
  end
  if not TRITIUM_BOX then
    error("rf-lithium-blanket: what the blanket breeds leaves through rf-isotope-collector, but " ..
      "COLLECTOR_BOXES in control.lua no longer lists rf-tritium -- so a blanket would consume " ..
      "lithium and deposit nothing. Give the blanket a fluid box of its own, or put the tritium " ..
      "box back.")
  end
end

-- The fields step() indexes without asking, checked before a reactor ever runs.
--
-- M.fuels is documented as the place a tier is added -- "a row here plus prototypes; the code
-- below does not change" -- so a row is written by someone reading the neighbouring rows rather
-- than the function that consumes them. Miss a field and the arithmetic throws inside on_nth_tick:
-- a crash on a live save, at whatever moment the first reactor of that tier gets plasma, rather
-- than a refusal to load.
--
-- tests/test-reactor-logic.lua asserts the same thing and is the better place to find it, because
-- it needs no game at all. This is here because the bench only catches it if the bench is run, and
-- the one thing that is always run before a save exists is loading.
--
-- Deliberately fields rather than values: whether 0.5 is the right neutron count is physics and
-- belongs in the tests, where it can be checked against the branch it comes from.
local FUEL_FIELDS = { "reaction", "energy_per_reaction_j", "charged_fraction", "fuel_per_reaction",
                      "neutrons_per_reaction" }

local function check_fuel_rows()
  for name, fuel in pairs(logic.fuels) do
    for _, field in ipairs(FUEL_FIELDS) do
      if fuel[field] == nil then
        error(string.format(
          "scripts/reactor-logic.lua: the fuel row for %s has no %s, which step() reads on every " ..
          "reactor holding it -- so the mod would load and then throw the moment one did. Add the " ..
          "field to M.fuels.", name, field))
      end
    end
    if type(fuel.fractions) ~= "table" or #fuel.fractions ~= 2 then
      error(string.format(
        "scripts/reactor-logic.lua: the fuel row for %s needs a reactant fraction for each side " ..
        "of its reaction, as a two-element table.", name))
    end
  end
end

--- Refuse to load a confinement ladder whose top rung parks D-D against the temperature clamp (#53).
--
-- The same shape as every other invariant here and for the same reason: it can only fire on a
-- developer edit -- a rung added or raised in scripts/reactor-logic.lua -- and without it the mod
-- loads perfectly and the defect surfaces in a player's save, as a reactor whose thermometer has
-- stopped moving and whose research has therefore stopped doing anything a player can see. The D-T
-- tier already reads that way at the clamp on purpose (docs/research/d-t-ignition.md); D-D arriving
-- there by accident is what this refuses.
--
-- ONE FUEL, AND THE SPEC SAYS WHICH -- confinement_guard_fuel, beside the ladder itself. The
-- exemption is the point rather than a narrowing: D-T settles at the clamp at every rung of the
-- ladder and at none of them, because it passes Lawson by more than an order of magnitude and is
-- pinned there whatever the confinement time is. A guard over every fuel would fail on the day it
-- was written, which is a guard nobody can keep. Reading the fuel off the spec rather than naming
-- it here is what stops a second reactor with a ladder being settled on a plasma it cannot burn.
--
-- THE DECISION IS reactor-logic's, not this function's. logic.confinement_ladder_overruns settles
-- the top rung and answers; this supplies the operating point, the horizon and the message. That
-- split is what lets tests/test-reactor-logic.lua negative-test the guard by breaking a ladder,
-- which is not something a check that only exists inside on_init could be asked to prove.
--
-- WHAT IT COSTS: about 40 ms, once, in on_init and on_configuration_changed. Not in the tick loop
-- and not at data stage.
-- Twenty minutes of simulated time, which is converged rather than merely long: the same answer to
-- five figures at two hours, over the whole ladder and well past it. Stepped at the cadence
-- update() actually runs, so the guard is asked about the simulation the game performs; a coarser
-- step settles hotter, which is the safe direction for a guard and the wrong one for a figure.
local LADDER_GUARD_SECONDS = 1200

local function check_confinement_ladder()
  for name, spec in pairs(SPECS) do
    if spec.confinement_ladder then
      -- Box 1 is the plasma box -- the same index update() reads the plasma out of, so the two
      -- cannot come to disagree about which box this is. Full, which is the reference operating
      -- point rather than the hottest one: see the note on confinement_ladder_overruns, which is
      -- where the argument for checking that one point lives.
      local volume = prototypes.entity[name].fluidbox_prototypes[1].volume
      local top = spec.confinement_ladder[#spec.confinement_ladder]
      -- Two questions, not one, and they are asked in two places on purpose. This one is whether
      -- the spec NAMED a fuel; reactor-logic's is whether the name WORKS, and it raises rather
      -- than answering when it cannot simulate -- which is what stops a mistyped name switching
      -- this whole invariant off in silence. A nil field gets the clearer message of the two, and
      -- it gets it here, beside every other refusal this file makes.
      local fuel = spec.confinement_guard_fuel
      if not fuel then
        error(string.format(
          "%s: has a confinement ladder but no confinement_guard_fuel, so there is no plasma to " ..
          "settle it against and the ladder would go unguarded. Name one in " ..
          "scripts/reactor-logic.lua, beside the ladder.", name))
      end
      local reached = logic.confinement_ladder_overruns(spec, fuel, volume,
        LADDER_GUARD_SECONDS, UPDATE_INTERVAL / 60)
      if reached then
        error(string.format(
          "%s: the confinement ladder's top rung (%s, %g s) settles %s at %.6g C, which is the " ..
          "simulation's own clamp of %.6g C -- so the reactor's temperature would be pinned there " ..
          "and further research would do nothing a player can see. Lower the top rung or shorten " ..
          "the ladder in scripts/reactor-logic.lua.",
          name, top.technology, top.confinement_time_s, fuel, reached, spec.max_temperature_c))
      end
      -- The prototypes the ladder names have to exist, or the force cache above silently reads a
      -- rung nobody can research and the line quietly stops one short. Cheap, and it catches a
      -- rename in prototypes/technology/confinement.lua that nothing else would.
      for _, rung in ipairs(spec.confinement_ladder) do
        if not prototypes.technology[rung.technology] then
          error(string.format(
            "%s: the confinement ladder names the technology '%s', which no loaded mod defines -- " ..
            "so no force could ever reach %g s of confinement. Reconcile " ..
            "scripts/reactor-logic.lua with prototypes/technology/confinement.lua.",
            name, rung.technology, rung.confinement_time_s))
        end
      end
    end
  end
end

local function check_prototypes()
  check_fuel_rows()
  check_reactor_specs()
  check_cadence()
  check_confinement_ladder()
  check_plasma_bounds()
  check_signal_ceiling()
  check_every_plasma_burns()
  check_collector_boxes()
  check_blanket_feed()
  check_energy_outlets()
  check_reactor_companions()
  check_steam_sinks()
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

-- What makes a force's confinement time change (#53). Each of these drops the derived spec cache;
-- the next reactor to be stepped rebuilds it from force.technologies, which is the only place the
-- answer is ever stored.
--
-- Wired through a table constructor and pairs() for the reason entity-management wires its build
-- events that way: a name this engine version does not define is simply a value the constructor
-- does not store, and pairs iterates what is there. ipairs would stop at the hole and silently drop
-- every event after it.
--
-- on_research_finished is the one that fires in normal play. The rest are the ways a force can end
-- up with different research WITHOUT finishing any -- reversed by a mod or the console, reset by a
-- scenario, merged into another force -- and every one of them would otherwise leave a reactor
-- running the confinement time of research its owner no longer has, for the rest of the save.
for _, event in pairs({
  defines.events.on_research_finished,
  defines.events.on_research_reversed,
  defines.events.on_technology_effects_reset,
  defines.events.on_force_reset,
  defines.events.on_forces_merged,
}) do
  script.on_event(event, forget_force_specs)
end

-- The reactor's signals sit on a companion entity a player cannot see, and the engine will not
-- offer it to a wire drag on its own -- the reactor outranks it for selection, and dragging a wire
-- is not a special case (ADR 0012). circuit-output moves the selection for as long as a wire is in
-- hand; installing it needs the reactor's name, which entity-management owns.
circuit.install(entities.REACTORS)
