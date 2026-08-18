-- Tests for the reactor power balance.
--
-- Run from the repository root:   lua tests/test-reactor-logic.lua
--
-- Like tests/test-reactivity.lua this runs outside Factorio, which is only possible because the
-- module under test touches no Factorio API (ADR 0005). Written to Lua 5.2 semantics and verified
-- on 5.4.

package.path = "RealisticFusion/?.lua;" .. package.path
local L = require("scripts.reactor-logic")
-- Required directly by the D-T block at the bottom, which recomputes one rate from the dataset to
-- pin down the reactant densities step() feeds it. Nothing else here reaches past reactor-logic.
local reactivity = require("scripts.reactivity")

local failures, checks = 0, 0

local function check(ok, name, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  -- " .. detail) or ""))
  end
end

local function near(actual, expected, tolerance, name)
  local ok
  if expected == 0 then
    ok = math.abs(actual) <= tolerance
  else
    ok = math.abs(actual - expected) / math.abs(expected) <= tolerance
  end
  check(ok, name, string.format("got %.6g, expected %.6g", actual, expected))
end

-- The values the shipped rf-reactor runs with, taken from the module rather than copied, so the
-- balance checks at the bottom cannot quietly start testing different numbers from the game's.
local SPEC = L.reactor

local TICK = 1 / 60
local FULL = 1000        -- the reactor's input fluidbox volume
local HOT = 6.0e8        -- a fusing temperature, in celsius: two minutes into a cold start

-- How long to run before calling the answer settled. Twenty minutes of game time, which is far
-- longer than it looks like it needs to be: the plasma's confinement time is thirty seconds, but
-- fusion self-heating is positive feedback, so the effective time constant is minutes rather than
-- seconds and the model is still climbing at six confinement times. Verified converged -- the same
-- to five figures at forty minutes.
local SETTLE_S = 1200

--- Run with the reactor kept full, which is what a heater that keeps up does.
--
-- Whether the answer is steady depends on running for SETTLE_S; a shorter horizon returns a point
-- on the way up, which reads like an equilibrium and is not one.
--
-- The step size is a parameter because the cadence check at the bottom varies it. Everything else
-- leaves it at one tick.
-- `amount` defaults to the neutronic reactor's box. The aneutronic one holds three times as much
-- in the same volume, which is its whole difference, so it has to be passed -- a settle() that
-- silently used 1000 units for both would run the second reactor at a third of its density and
-- report the answer as its equilibrium. It did, before this parameter existed.
local function settle(spec, seconds, available_j, dt, fluid, amount)
  dt = dt or TICK
  fluid = fluid or "rf-d-d-plasma"
  amount = amount or FULL
  local t_c, last = spec.min_temperature_c, nil
  for _ = 1, math.floor(seconds / dt) do
    last = L.step(spec, fluid, amount, t_c, available_j, dt)
    if not last then break end
    t_c = last.temperature_c
  end
  return t_c, last
end

-- ---------------------------------------------------------------- nothing to do

check(L.step(SPEC, nil, FULL, HOT, math.huge, TICK) == nil, "no fluid, no step")
check(L.step(SPEC, "water", FULL, HOT, math.huge, TICK) == nil, "a fluid with no fuel entry is not burnt")
check(L.step(SPEC, "rf-d-d-plasma", 0, HOT, math.huge, TICK) == nil, "empty reactor, no step")
check(L.step(SPEC, "rf-d-d-plasma", FULL, HOT, math.huge, 0) == nil, "zero elapsed time, no step")

-- Every plasma the mod defines needs an entry, or its reactor silently does nothing. The other
-- direction -- a plasma prototype with no row here -- is control.lua's check_every_plasma_burns,
-- which needs the game to see the prototypes.
check(L.fuels["rf-d-d-plasma"] ~= nil, "D-D plasma has a fuel entry")

-- And every entry needs the whole set of fields, because step() indexes them without asking. A row
-- missing `fractions` throws inside a running game rather than failing to load, which is the worst
-- available moment to find out; a row missing anything else is silently wrong instead. Checked here
-- because this is the earliest place that can see them.
for name, fuel in pairs(L.fuels) do
  for _, field in ipairs({ "reaction", "energy_per_reaction_j", "charged_fraction",
                           "fuel_per_reaction", "neutrons_per_reaction" }) do
    check(fuel[field] ~= nil, string.format("%s declares %s", name, field))
  end
  check(type(fuel.fractions) == "table" and #fuel.fractions == 2
    and fuel.fractions[1] > 0 and fuel.fractions[2] > 0,
    string.format("%s declares a reactant fraction for each side", name))

  -- The even-mix invariant, and the reason it is asserted rather than described: step() caps the
  -- burn at particles / fuel_per_reaction and draws the plasma down as one fluid, so a row whose
  -- two sides are NOT present in equal share would go on reacting after the scarce one had run out
  -- -- silently, paying for it out of the abundant one. The cap has to be no larger than the
  -- scarcest side can supply, which for one nucleus per reaction per side is exactly this.
  --
  -- D-D passes with room to spare (1/2 against a share of 1) because both its reactants come out of
  -- the same pool; D-T passes with equality. An uneven mix fails here, at the bench, rather than in
  -- a save. Supporting one is a different model -- see the note in M.fuels.
  local scarcest = math.min(fuel.fractions[1], fuel.fractions[2])
  check(1 / fuel.fuel_per_reaction <= scarcest + 1e-12,
    string.format("%s cannot burn past its scarcest reactant", name),
    string.format("cap is 1/%g of the plasma against a scarcest share of %g",
      fuel.fuel_per_reaction, scarcest))
end

-- ---------------------------------------------------------------- heating and cooling

-- Heating raises the temperature of a cold plasma; that is the only way the reactor ever gets to
-- a temperature where the cross-section data is interesting.
local warm = L.step(SPEC, "rf-d-d-plasma", FULL, SPEC.min_temperature_c, math.huge, TICK)
check(warm.temperature_c > SPEC.min_temperature_c, "heating warms a cold plasma", tostring(warm.temperature_c))
near(warm.heating_used_j, SPEC.heating_power_w * TICK, 1e-12, "a powered reactor spends its full heating")

-- Without power the plasma only loses energy. This is what makes a brownout visible in game
-- rather than silently free.
local cooling = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e7, 0, TICK)
check(cooling.temperature_c < 1.0e7, "an unpowered reactor cools", tostring(cooling.temperature_c))
near(cooling.heating_used_j, 0, 0, "an unpowered reactor spends nothing")

-- A partly powered reactor spends what it has, not what it wants.
local starved = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e7, 1000, TICK)
near(starved.heating_used_j, 1000, 1e-12, "a starved reactor spends only what is available")

-- Cooling is asymptotic, never inverted: one confinement time of loss cannot take the plasma
-- below ambient however long the step is.
local overshoot = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e8, 0, 10 * SPEC.confinement_time_s)
check(overshoot.temperature_c >= SPEC.min_temperature_c, "a very long unpowered step does not go below ambient",
  tostring(overshoot.temperature_c))

-- ---------------------------------------------------------------- rate responds to temperature

-- The criterion the whole ticket turns on: the same reactor, same fuel, different temperature,
-- must fuse at a different rate. A constant would pass every other test in this file.
local cold_burn = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e7, math.huge, TICK)
local warm_burn = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e8, math.huge, TICK)
local hot_burn  = L.step(SPEC, "rf-d-d-plasma", FULL, HOT, math.huge, TICK)
check(cold_burn.fusion_power_w < warm_burn.fusion_power_w, "hotter plasma fuses faster (1e7 -> 1e8 C)",
  string.format("%.3g vs %.3g", cold_burn.fusion_power_w, warm_burn.fusion_power_w))
check(warm_burn.fusion_power_w < hot_burn.fusion_power_w, "hotter plasma fuses faster (1e8 -> 6e8 C)",
  string.format("%.3g vs %.3g", warm_burn.fusion_power_w, hot_burn.fusion_power_w))
-- Not merely different: superlinear. Six times the temperature gives far more than six times the
-- power -- about twenty-seven times at the shipped data. A response that merely tracked
-- temperature would mean the cross-section curve had been flattened somewhere between the table
-- and here.
check(hot_burn.fusion_power_w > 6 * 4 * warm_burn.fusion_power_w, "the response is superlinear in temperature",
  string.format("%.3g vs %.3g, ratio %.1f for a 6x temperature rise",
    hot_burn.fusion_power_w, warm_burn.fusion_power_w, hot_burn.fusion_power_w / warm_burn.fusion_power_w))

-- Density matters too, and in the other direction from temperature: half the plasma at the same
-- temperature is less than half the power, because the rate goes as the square of density.
local half = L.step(SPEC, "rf-d-d-plasma", FULL / 2, HOT, math.huge, TICK)
check(half.fusion_power_w < hot_burn.fusion_power_w / 2, "halving the plasma more than halves the power",
  string.format("%.3g vs %.3g", half.fusion_power_w, hot_burn.fusion_power_w))

-- ---------------------------------------------------------------- fuel

check(hot_burn.plasma_consumed > 0, "a fusing reactor burns fuel", tostring(hot_burn.plasma_consumed))
check(cold_burn.plasma_consumed < hot_burn.plasma_consumed, "a cold reactor burns less fuel")

-- The cap that stops the particle count going negative. A step long enough to burn everything
-- must stop at everything.
local gulp = L.step(SPEC, "rf-d-d-plasma", FULL, 1.5e9, math.huge, 3600)
-- Asserted as equality, not as an upper bound: "<= FULL" would pass just as happily on a rate
-- lookup that had broken to zero, so it would stop testing the cap and start testing nothing.
near(gulp.plasma_consumed, FULL, 1e-12, "a very long step burns exactly the plasma present")
check(gulp.temperature_c >= SPEC.min_temperature_c and gulp.temperature_c <= SPEC.max_temperature_c,
  "temperature stays inside the fluid's range even when the reactor burns dry", tostring(gulp.temperature_c))

-- ---------------------------------------------------------------- output

check(hot_burn.energy_units > 0, "a running reactor produces reactor energy", tostring(hot_burn.energy_units))
near(hot_burn.q_factor, hot_burn.fusion_power_w * TICK / hot_burn.heating_used_j, 1e-12,
  "Q is fusion energy over heating energy")

-- Capture efficiency exists to stop a reactor that never fuses being a free electricity loop:
-- Factorio's steam turbines lose nothing, so at 100% capture a cold reactor would pay for its own
-- heating forever. At equilibrium with negligible fusion, output must come out below heating.
local COLD_SPEC = {}
for k, v in pairs(SPEC) do COLD_SPEC[k] = v end
COLD_SPEC.confinement_time_s = 4     -- too leaky to reach a fusing temperature
local cold_t, cold_state = settle(COLD_SPEC, SETTLE_S, math.huge)
local cold_out_w = cold_state.energy_units * COLD_SPEC.energy_fluid_j_per_unit * 60
check(cold_state.fusion_power_w < 0.05 * COLD_SPEC.heating_power_w, "the leaky reactor barely fuses",
  string.format("%.3g W at %.3g C", cold_state.fusion_power_w, cold_t))
check(cold_out_w < COLD_SPEC.heating_power_w, "a reactor that does not fuse is a net loss",
  string.format("out %.3g W vs heating %.3g W", cold_out_w, COLD_SPEC.heating_power_w))

-- A reactor parked at the bottom of the range must sell nothing at all. This is the case the
-- capture_efficiency check above does not reach: there the plasma is above ambient and genuinely
-- losing heat, here the temperature clamp puts the energy straight back and the reactor is not
-- losing anything to sell. Charging the loss term to the output regardless paid a full, cold,
-- unpowered reactor about 34 W for ever -- small, but energy from nothing, which is the one thing
-- this model must not do.
-- Not asserted as exactly zero: the energy that left is the difference between what the plasma
-- had and what a temperature it was just clamped to says it has, so the round trip through
-- celsius loses a few bits. The residue is 5e-15 units a step, which is 3e-7 W -- a hundred
-- million times below the leak this closed, and eleven orders below the reactor's output.
local parked = L.step(SPEC, "rf-d-d-plasma", FULL, SPEC.min_temperature_c, 0, TICK)
near(parked.temperature_c, SPEC.min_temperature_c, 1e-12, "an unpowered reactor parks at the minimum")
near(parked.energy_units, 0, 1e-12, "a reactor parked at the minimum sells nothing")

-- ---------------------------------------------------------------- D-D by-products (#27)

-- The reactors are the breeder (CONTEXT.md, ADR 0010): running D-D leaves tritium and helium-3
-- behind. The two branches are already in M.fuels' comment and drive energy_per_reaction_j, so
-- what is asserted here is that the same reaction count also produces matter, and that the two
-- accounts agree with each other rather than being two independent numbers that happen to look
-- right.
check(L.fuels["rf-d-d-plasma"].products ~= nil, "D-D declares what it breeds")

check(hot_burn.products["rf-tritium"] > 0, "a fusing reactor breeds tritium",
  tostring(hot_burn.products["rf-tritium"]))
check(hot_burn.products["rf-helium-3"] > 0, "a fusing reactor breeds helium-3",
  tostring(hot_burn.products["rf-helium-3"]))

-- The 50/50 branch. Equal amounts is the whole physical claim, so it is asserted as equality
-- rather than as "both are positive".
near(hot_burn.products["rf-tritium"], hot_burn.products["rf-helium-3"], 1e-12,
  "the two D-D branches breed in equal measure")

-- Stoichiometry, which is what ties breeding to the energy account. Two deuterons go into every
-- reaction and half of them leave a triton, so a quarter of the deuterium burnt comes back as
-- tritium and another quarter as helium-3 -- at the same nuclei-per-unit the plasma is counted at.
-- Without this the breeding rate could drift to any constant and every other check here would
-- still pass.
near(hot_burn.products["rf-tritium"], hot_burn.plasma_consumed / 4, 1e-12,
  "tritium bred is a quarter of the deuterium burnt")
near(hot_burn.products["rf-helium-3"], hot_burn.plasma_consumed / 4, 1e-12,
  "helium-3 bred is a quarter of the deuterium burnt")

-- Breeding follows the simulation rather than a fixed rate, which is the reason this is computed
-- here at all instead of being a recipe on a machine (#27). A cold reactor breeds less for the
-- same reason it produces less power.
check(cold_burn.products["rf-tritium"] < hot_burn.products["rf-tritium"],
  "a cold reactor breeds less than a hot one",
  string.format("%.3g vs %.3g", cold_burn.products["rf-tritium"], hot_burn.products["rf-tritium"]))

-- A reactor that is not fusing breeds nothing at all. `parked` is at the bottom of the range with
-- no power, which is the state a reactor sits in before its heater catches up.
near(parked.products["rf-tritium"], 0, 1e-12, "a reactor parked at the minimum breeds nothing")

-- The burn cap applies to breeding too: a step long enough to consume the whole reactor cannot
-- breed as though it had burnt more than was there.
near(gulp.products["rf-tritium"], FULL / 4, 1e-12,
  "a step that burns the reactor dry breeds against the fuel that was actually present")

-- ---------------------------------------------------------------- D-T (#28)
--
-- The second tier, and the first test of the claim M.fuels' comment makes: that adding a reaction
-- is a row in that table and nothing else. Everything below drives the same step() the D-D checks
-- above do, with one fluid name changed.

check(L.fuels["rf-d-t-plasma"] ~= nil, "D-T plasma has a fuel entry")

-- D-T leaves an alpha and a neutron. Neither is a fluid this mod defines -- the neutron is already
-- what reactor energy stands for, and there is no helium-4 in ADR 0010's set -- so this tier
-- breeds nothing, and the reactor it runs in needs no collector.
check(L.fuels["rf-d-t-plasma"].products == nil, "D-T breeds nothing")

local dt_hot  = L.step(SPEC, "rf-d-t-plasma", FULL, HOT, math.huge, TICK)
local dt_warm = L.step(SPEC, "rf-d-t-plasma", FULL, 1.0e8, math.huge, TICK)

-- The reactant densities, which are the one thing a second reaction changes about the rate lookup
-- and the one thing that would fail silently. D-D is deuterium against deuterium, so every nucleus
-- in the box is both reactants at once and the rate goes as the full density squared -- halved
-- again by reactivity.rate, because each pair would otherwise be counted twice. A D-T plasma is a
-- 50/50 mix, so each side is at HALF the density of the fluid, and the rate is a quarter of what
-- feeding the whole density twice would give.
--
-- Recomputed here from the dataset rather than asserted as a ratio: getting this wrong quadruples
-- the tier's output and every other check in this block still passes.
local n = FULL * SPEC.particles_per_unit / SPEC.volume_m3
near(dt_hot.fusion_power_w,
  reactivity.rate("D-T", HOT + 273.15, n / 2, n / 2)
    * SPEC.volume_m3 * L.fuels["rf-d-t-plasma"].energy_per_reaction_j,
  1e-12, "D-T burns a mix, so each reactant sits at half the plasma's density")

-- The acceptance criterion: a materially different rate and output from D-D at the same
-- temperature. Bounds are loose because they exist to catch a row that was copied and not edited,
-- which would make the two identical, not to pin the physics -- the dataset does that.
check(dt_hot.fusion_power_w > 5 * hot_burn.fusion_power_w, "D-T fuses far harder than D-D at the same temperature",
  string.format("%.3g vs %.3g W, ratio %.1f", dt_hot.fusion_power_w, hot_burn.fusion_power_w,
    dt_hot.fusion_power_w / hot_burn.fusion_power_w))
check(dt_hot.energy_units > 5 * hot_burn.energy_units, "and sells far more for it",
  string.format("%.3g vs %.3g units", dt_hot.energy_units, hot_burn.energy_units))

-- The difference that decides the progression, and it is the interesting one: D-T's advantage is
-- not a constant multiple, it grows enormously as the plasma cools. That is why D-T is the easier
-- reaction rather than merely the bigger one -- it is what a reactor can still run on when D-D has
-- fallen off the bottom of its curve.
check(dt_warm.fusion_power_w / warm_burn.fusion_power_w > dt_hot.fusion_power_w / hot_burn.fusion_power_w,
  "D-T's advantage over D-D widens as the plasma cools",
  string.format("%.0fx at 1e8 C against %.0fx at 6e8 C",
    dt_warm.fusion_power_w / warm_burn.fusion_power_w, dt_hot.fusion_power_w / hot_burn.fusion_power_w))

-- The burn cap is the fuel table's to get right per reaction, not step()'s: D-T consumes one
-- nucleus from each side of a 50/50 mix, which is two out of the box, the same as D-D consuming
-- two deuterons. A row that left fuel_per_reaction at 1 would let the reactor burn twice what it
-- holds.
local dt_gulp = L.step(SPEC, "rf-d-t-plasma", FULL, 1.5e9, math.huge, 3600)
near(dt_gulp.plasma_consumed, FULL, 1e-12, "a very long D-T step burns exactly the plasma present")

-- ---- the shipped balance: D-T ignites, and that is a different regime rather than a bigger number
--
-- D-D settles. Heating and self-heating balance the confinement loss partway up the cross-section
-- curve and the plasma sits there at Q around 2. D-T does not: at this reactor's density and
-- confinement time the plasma passes Lawson by a wide margin, self-heating outruns the loss term
-- at every temperature the data covers below the peak, and the temperature climbs until something
-- stops it. What stops it here is the clamp at the top of the fluid's declared range.
--
-- That is asserted rather than avoided, because it is the behaviour and hiding it in a bound that
-- happened to pass would be worse. See the note in M.fuels and docs/research/d-t-ignition.md for
-- what the clamp stands in for and what the alternative costs.
local dt_t, dt_state = settle(SPEC, 60, math.huge, nil, "rf-d-t-plasma")
near(dt_t, SPEC.max_temperature_c, 1e-12, "a D-T plasma ignites and runs up to the top of its range")
check(dt_state.q_factor > 10, "an ignited D-T reactor runs far past breakeven",
  string.format("Q = %.3g", dt_state.q_factor))

-- What a player actually builds against, and the property that makes an ignited reactor playable
-- rather than a runaway: at the top of the range the reactor burns exactly what it is fed and its
-- output follows the feed. Ignition removes the temperature as a control input, so the throttle is
-- the fuel line -- which is a throttle, and is the one worth testing.
--
-- Modelled the way the game does it: the heater tops the box up each step with plasma at injection
-- temperature, and the step burns out of what is there.
local function supplied(fluid, feed_per_s, seconds)
  local t, held, last = SPEC.min_temperature_c, 0, nil
  for _ = 1, math.floor(seconds / TICK) do
    local added = math.min(feed_per_s * TICK, FULL - held)
    if added > 0 then
      t = (t * held + 1e6 * added) / (held + added)   -- injected far below fusion temperature
      held = held + added
    end
    last = L.step(SPEC, fluid, held, t, math.huge, TICK)
    if last then
      held = held - last.plasma_consumed
      t = last.temperature_c
    end
  end
  return last, held
end

local fed_1x = supplied("rf-d-t-plasma", 2.5, 600)
local fed_2x = supplied("rf-d-t-plasma", 5.0, 600)
near(fed_1x.plasma_consumed * 60, 2.5, 1e-3, "an ignited reactor burns exactly what it is fed")
-- Just under two, and the shortfall is not slack in the tolerance: the confinement heating is
-- recovered too and does not double with the fuel, so the output is affine in the feed rather than
-- proportional to it. At 50 MW in against a few hundred out that offset is worth about 7%.
near(fed_2x.energy_units / fed_1x.energy_units, 2, 0.1,
  "so doubling the fuel line very nearly doubles the power out")

-- The tier is worth reaching, measured against D-D on the terms a player compares them on: the
-- same one heater feeding each.
local dd_fed = supplied("rf-d-d-plasma", 2.5, 600)
check(fed_1x.energy_units > 3 * dd_fed.energy_units,
  "D-T pays far better than D-D off the same fuel line",
  string.format("%.4g vs %.4g MW", fed_1x.energy_units * 60, dd_fed.energy_units * 60))

-- ---------------------------------------------------------------- cadence is a free parameter
--
-- ADR 0005 calls the update cadence a tuning parameter and pre-authorises coarsening it. That is
-- a claim about this file, and it only holds while the answer does not depend on how large the
-- steps are: this is explicit Euler integration, and explicit Euler is only stable while the step
-- stays well inside the system's time constant. #24 measured the cost, found sixty steps a second
-- of a plasma with a thirty-second confinement time to be almost entirely waste, and throttled
-- control.lua on the strength of this property -- so it is checked rather than assumed.
--
-- Deliberately not tied to whatever cadence control.lua currently uses. The property worth
-- keeping is that the whole range is available, so a later change of interval is covered by a
-- test that already exists rather than needing a new one.
--
-- Compared at equilibrium rather than partway up. A shorter horizon flatters the coarse steps --
-- they have had less time to accumulate error -- and reports a smaller divergence than the one
-- the game will actually run at.
local fine_t, fine_state = settle(SPEC, SETTLE_S, math.huge)
for _, ticks in ipairs({ 2, 6, 15, 30 }) do
  local coarse_t, coarse_state = settle(SPEC, SETTLE_S, math.huge, ticks * TICK)
  near(coarse_t, fine_t, 0.01,
    string.format("one step per %d ticks settles where one step per tick does", ticks))
  -- Per tick rather than per step, or the comparison would just be measuring the step size.
  near(coarse_state.energy_units / ticks, fine_state.energy_units, 0.01,
    string.format("one step per %d ticks produces the same energy per tick", ticks))
end

-- ---------------------------------------------------------------- blanket breeding (#30)
--
-- The second breeding route (CONTEXT.md), and the one real D-T machines are designed around: a
-- shell of lithium around the reactor catches the neutrons the plasma cannot confine and turns
-- them into tritium. Everything below drives M.breed, which is deliberately not part of step() --
-- the plasma does not know what is bolted to the outside of the reactor.

local BLANKET = L.blanket
local CHARGED = math.huge   -- a blanket with lithium to spare

-- Both tiers must report their neutrons, because a blanket fits either reactor. The numbers are
-- not interchangeable and that is the point of the tier.
near(L.fuels["rf-d-t-plasma"].neutrons_per_reaction, 1, 1e-12, "every D-T reaction releases a neutron")
near(L.fuels["rf-d-d-plasma"].neutrons_per_reaction, 0.5, 1e-12, "half of D-D's reactions release one")

-- The invariant that keeps the two accounts from drifting: D-D's neutron and its helium-3 come out
-- of the SAME branch, so a later edit that moves the branch split has to move both. Asserted
-- against the products table rather than against 0.5 twice, which would pass on two independent
-- constants that happened to agree today.
near(L.fuels["rf-d-d-plasma"].neutrons_per_reaction, L.fuels["rf-d-d-plasma"].products["rf-helium-3"],
  1e-12, "D-D's neutrons and its helium-3 are the same branch")

check(hot_burn.neutrons > 0, "a fusing D-D reactor releases neutrons", tostring(hot_burn.neutrons))
check(dt_hot.neutrons > 0, "a fusing D-T reactor releases neutrons", tostring(dt_hot.neutrons))
-- Not asserted as zero, and the difference is worth stating because it is the same trap the fluid
-- writes in control.lua guard against. A plasma at ambient has a reactivity that is negligible
-- rather than absent, so `neutrons` is a raw count of a few thousand where a fusing reactor's is
-- 1e21. In fluid units that is 1e-17 of a unit -- eleven orders below the threshold the engine will
-- accept as a fluid amount at all -- so it rounds to nothing everywhere it matters, but it is not
-- nothing, and a test claiming it were would be testing a rate lookup that had broken to zero.
check(parked.neutrons * 1e12 < hot_burn.neutrons, "a reactor parked at the minimum releases next to none",
  string.format("%.3g against a fusing reactor's %.3g", parked.neutrons, hot_burn.neutrons))

-- Neutrons come off the same capped reaction count everything else does. Stated against the fuel
-- burnt rather than against a reaction count the test would have to recompute: two nuclei go into
-- every D-D reaction and half of those reactions make a neutron, so one neutron per four nuclei.
near(hot_burn.neutrons, hot_burn.plasma_consumed * SPEC.particles_per_unit / 4, 1e-12,
  "D-D releases one neutron per four deuterons burnt")
near(dt_hot.neutrons, dt_hot.plasma_consumed * SPEC.particles_per_unit / 2, 1e-12,
  "D-T releases one neutron per two nuclei burnt")

-- ---- what the blanket makes of them

check(L.breed(SPEC, BLANKET, 0, CHARGED) == nil, "no neutrons, nothing bred")
check(L.breed(SPEC, BLANKET, nil, CHARGED) == nil, "a reactor with no step breeds nothing")
check(L.breed(SPEC, BLANKET, 1e20, 0) == nil, "an empty blanket breeds nothing")
check(L.breed(SPEC, BLANKET, 1e20, nil) == nil, "a blanket that was never loaded breeds nothing")

local bred = L.breed(SPEC, BLANKET, dt_hot.neutrons, CHARGED)
check(bred ~= nil, "a blanket on a fusing D-T reactor breeds")
near(bred.tritium_units, dt_hot.neutrons * BLANKET.tritium_per_neutron / SPEC.particles_per_unit,
  1e-12, "tritium bred is the neutron count times the breeding ratio")

-- One lithium nucleus per triton. Asserted as an identity between the two returned numbers rather
-- than recomputed, because they are the same quantity counted in two different things and the way
-- this goes wrong is that one of them silently stops tracking the other.
near(bred.nuclei_used, bred.tritium_units * SPEC.particles_per_unit, 1e-12,
  "one lithium nucleus is spent per triton bred")

-- The identity the item size exists for, and the one a player can check by watching a belt: with
-- lithium_nuclei_per_item equal to particles_per_unit, one lithium item in is one unit of tritium
-- out. If either constant moves without the other this is what says so.
near(bred.nuclei_used / BLANKET.lithium_nuclei_per_item, bred.tritium_units, 1e-12,
  "one lithium item breeds one unit of tritium")

-- What a step can consume, which is what control.lua sizes its withdrawal from the blanket's
-- inventory by. It has to agree with what breed() then spends when the charge is not the limit --
-- if it under-reports, the blanket is capped at whatever it happens to withdraw and breeds less
-- than the physics says while looking perfectly healthy. That is not hypothetical: it is what the
-- first version of control.lua did, and it took an in-game measurement to see.
near(L.lithium_for(BLANKET, dt_hot.neutrons), bred.nuclei_used, 1e-12,
  "the lithium a step wants is the lithium an unconstrained step spends")

-- The cap, which is what stops a blanket breeding on credit. Half the lithium it wants must give
-- exactly half the tritium and consume exactly the lithium there was -- not merely less of each.
local wanted = L.breed(SPEC, BLANKET, dt_hot.neutrons, CHARGED)
local short  = L.breed(SPEC, BLANKET, dt_hot.neutrons, wanted.nuclei_used / 2)
near(short.nuclei_used, wanted.nuclei_used / 2, 1e-12, "a blanket running out spends exactly what it had")
near(short.tritium_units, wanted.tritium_units / 2, 1e-12, "and breeds exactly what that bought")

-- Breeding follows the simulation, which is the same claim the D-D by-products make and the reason
-- neither is a recipe: a cool reactor releases fewer neutrons, so its blanket breeds less.
local dt_cool = L.step(SPEC, "rf-d-t-plasma", FULL, 1.0e7, math.huge, TICK)
local cool_bred = L.breed(SPEC, BLANKET, dt_cool.neutrons, CHARGED)
check(cool_bred.tritium_units * 10 < bred.tritium_units,
  "a blanket on a cool reactor breeds far less",
  string.format("%.3g vs %.3g", cool_bred.tritium_units, bred.tritium_units))

-- ---- the claim the tier turns on
--
-- A D-T reactor burns one triton per reaction and its blanket breeds tritium_per_neutron of one
-- back. Above one is self-sufficiency -- the tier feeding itself rather than draining the D-D
-- reactors upstream of it -- and it is the whole reason real machines are built this way.
--
-- Half the plasma is tritium (fractions), so tritons burnt is half the nuclei burnt.
local tritons_burnt = dt_hot.plasma_consumed * SPEC.particles_per_unit
  * L.fuels["rf-d-t-plasma"].fractions[2]
check(bred.nuclei_used > tritons_burnt,
  "a blanketed D-T reactor breeds back more tritium than it burns",
  string.format("%.4g bred against %.4g burnt, ratio %.3f",
    bred.nuclei_used, tritons_burnt, bred.nuclei_used / tritons_burnt))

-- And the same blanket on a D-D reactor is worth having but is not the same machine: D-D makes a
-- neutron on half its reactions where D-T makes one on every reaction, so at equal reaction rates
-- the blanket breeds half as much. Compared at the same temperature so the difference is the
-- branch structure rather than the cross-section.
local dd_bred = L.breed(SPEC, BLANKET, hot_burn.neutrons, CHARGED)
check(dd_bred.tritium_units > 0, "a blanket on a D-D reactor breeds too",
  tostring(dd_bred.tritium_units))
near(dd_bred.tritium_units / hot_burn.plasma_consumed,
  bred.tritium_units / dt_hot.plasma_consumed / 2, 1e-12,
  "per unit of plasma burnt, a D-D blanket breeds half what a D-T blanket does")

-- ---------------------------------------------------------------- aneutronic tier (#31)
--
-- The third and fourth reactions, and the second reactor. Everything here drives the same step()
-- the D-D and D-T blocks do, with a different spec passed in -- which is the claim ADR 0005 made
-- and the reason a reactor is a table of constants rather than a class.

local ANEUTRONIC = L.aneutronic_reactor
-- The aneutronic reactor holds three times the plasma in the same volume, so a full one is three
-- times the density. Read off the prototype's fluid box the way FULL is, rather than derived, so a
-- change to one has to be a change to both.
local ANEUTRONIC_FULL = 3000

check(L.fuels["rf-d-he3-plasma"] ~= nil, "D-He3 plasma has a fuel entry")
check(L.fuels["rf-he3-he3-plasma"] ~= nil, "He3-He3 plasma has a fuel entry")

-- WHAT MAKES THE TIER ANEUTRONIC, and the one property the whole thing is named for. Asserted
-- rather than described because a blanket bolted to one of these breeds from `neutrons`, and a row
-- that inherited D-T's 1 by being copied would quietly turn an aneutronic reactor into a tritium
-- factory -- which is the exact opposite of what it is.
for _, name in ipairs({ "rf-d-he3-plasma", "rf-he3-he3-plasma" }) do
  check(L.fuels[name].neutrons_per_reaction == 0, name .. " releases no neutrons")
  check(L.fuels[name].products == nil, name .. " breeds nothing")
  -- Everything charged is the other half of the same statement: no neutron means no energy leaving
  -- the plasma uncharged, which is what direct energy conversion collects.
  near(L.fuels[name].charged_fraction, 1, 0, name .. " keeps its whole release in the plasma")
end

local aneutronic_hot = L.step(ANEUTRONIC, "rf-d-he3-plasma", ANEUTRONIC_FULL, HOT, math.huge, TICK)
check(aneutronic_hot.neutrons == 0, "so a D-He3 reactor reports no neutrons at all",
  tostring(aneutronic_hot.neutrons))
-- And therefore a blanket on one does nothing. The blanket does not know what fuel is burning; it
-- is handed a neutron count, and this is what that count being zero means downstream.
check(L.breed(ANEUTRONIC, BLANKET, aneutronic_hot.neutrons, CHARGED) == nil,
  "a lithium blanket on an aneutronic reactor breeds nothing")

-- The reactant densities, recomputed from the dataset for the reason the D-T block does it: a mix
-- against a single fuel is the one thing a new row gets wrong silently. D-He3 is a 50/50 blend, so
-- each side sits at half the plasma's density; He3-He3 is like species, so every nucleus is both
-- sides and reactivity.rate halves the pair count.
local an_n = ANEUTRONIC_FULL * ANEUTRONIC.particles_per_unit / ANEUTRONIC.volume_m3
near(aneutronic_hot.fusion_power_w,
  reactivity.rate("D-He3", HOT + 273.15, an_n / 2, an_n / 2)
    * ANEUTRONIC.volume_m3 * L.fuels["rf-d-he3-plasma"].energy_per_reaction_j,
  1e-12, "D-He3 burns a mix, so each reactant sits at half the plasma's density")

local he3_hot = L.step(ANEUTRONIC, "rf-he3-he3-plasma", ANEUTRONIC_FULL, HOT, math.huge, TICK)
near(he3_hot.fusion_power_w,
  reactivity.rate("He3-He3", HOT + 273.15, an_n, an_n)
    * ANEUTRONIC.volume_m3 * L.fuels["rf-he3-he3-plasma"].energy_per_reaction_j,
  1e-12, "He3-He3 is like species, so both sides are the whole plasma")

-- The denser machine is the point of the second spec. Same fuel, same temperature, three times the
-- density: the rate goes as n^2, so nine times the power. If a later edit made the two reactors
-- the same box this is what would notice.
local aneutronic_thin = L.step(ANEUTRONIC, "rf-d-he3-plasma", FULL, HOT, math.huge, TICK)
near(aneutronic_hot.fusion_power_w / aneutronic_thin.fusion_power_w, 9, 1e-9,
  "three times the plasma is nine times the power")

-- ---- the shipped balance of the tier
--
-- SETTLE_S, not a shorter horizon, and that is the correction this block needed rather than a
-- detail. Both aneutronic plasmas climb for a long time before they stop: at two minutes He3-He3
-- is at 8.9e8 C and Q 0.12, which is a point on the way up and reads exactly like an equilibrium
-- if it is asserted against. Every number below is the settled one.
local an_t, an_state = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-d-he3-plasma", ANEUTRONIC_FULL)
near(an_t, ANEUTRONIC.max_temperature_c, 1e-12, "a D-He3 plasma ignites and runs up to the clamp")
check(an_state.q_factor > 50, "and runs far past breakeven there",
  string.format("Q = %.3g", an_state.q_factor))

-- THE FINDING THAT MATTERS ABOUT HE3-HE3, and it is a real constraint rather than a balance number.
--
-- Its cross-section peaks past 600 keV -- above the top of the ENDF-derived dataset -- and
-- max_temperature_c stops the plasma at 172. So it too climbs to the clamp, but it gets there
-- burning at about a hundredth of its peak reactivity, where D-He3 at the same ceiling is near
-- enough to its own peak to be sixty times stronger. The last tier in the mod cannot reach its own
-- optimum, and arrives barely above break-even because of it.
--
-- ADR 0014 is what makes that shippable rather than broken: a tier may arrive marginal.
local he3_t, he3_state = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-he3-he3-plasma", ANEUTRONIC_FULL)
near(he3_t, ANEUTRONIC.max_temperature_c, 1e-12,
  "He3-He3 reaches the clamp too -- it is where it lands, not whether it gets there")
check(he3_state.q_factor > 1, "and is just above break-even there",
  string.format("Q = %.3g", he3_state.q_factor))
check(he3_state.q_factor < an_state.q_factor / 20,
  "but far weaker than D-He3 in the same reactor, because the clamp is far below its peak",
  string.format("Q %.3g against %.3g", he3_state.q_factor, an_state.q_factor))

-- AND THIS IS THE ONE THAT NOTICES A RAISED CLAMP, which the previous version of this block
-- claimed and did not do. Asserting "He3-He3 is weak" is not a statement about the clamp at all:
-- at a 120-second horizon the plasma had not reached the clamp, so raising max_temperature_c to
-- 7e9 left every figure here bit-identical and the check passed exactly as before.
--
-- Q at the ceiling is the quantity that actually depends on where the ceiling is. Let the plasma
-- run to 7e9 -- which is where He3-He3's reactivity peaks -- and it stops being marginal, so this
-- bound breaks and says why.
local raised = {}
for key, value in pairs(ANEUTRONIC) do raised[key] = value end
raised.max_temperature_c = 7e9
local _, raised_state = settle(raised, SETTLE_S, math.huge, nil, "rf-he3-he3-plasma", ANEUTRONIC_FULL)
check(raised_state.q_factor > 5 * he3_state.q_factor,
  "raising the clamp to He3-He3's own peak transforms it, which is what makes the clamp the cause",
  string.format("Q %.3g at a 7e9 ceiling against %.3g at the shipped 2e9",
    raised_state.q_factor, he3_state.q_factor))

-- Every spec the mod ships needs the fields step() and control.lua index without asking. The fuel
-- rows are covered at the top of this file; this is the other half of the same guard, and it exists
-- because a second reactor is exactly the moment a spec field gets added to one and not the other.
for label, spec in pairs({ ["rf-reactor"] = SPEC, ["rf-aneutronic-reactor"] = ANEUTRONIC }) do
  for _, field in ipairs({ "volume_m3", "particles_per_unit", "heating_power_w",
                           "confinement_time_s", "capture_efficiency", "energy_fluid_j_per_unit",
                           "energy_fluid", "min_temperature_c", "max_temperature_c" }) do
    check(spec[field] ~= nil, string.format("%s's spec declares %s", label, field))
  end
end
check(SPEC.energy_fluid ~= ANEUTRONIC.energy_fluid,
  "the two reactors sell different fluids, so one converter cannot drink the other's output")
-- One nuclei-per-unit constant across the mod. The blanket's one-item-one-unit identity rests on
-- it, and a second value would make a fluid unit mean different things in different pipes.
near(ANEUTRONIC.particles_per_unit, SPEC.particles_per_unit, 0,
  "both reactors count the same nuclei per fluid unit")

-- ---------------------------------------------------------------- the shipped balance
--
-- Not a physics check -- a check that the numbers the mod ships with produce a reactor worth
-- building. These bounds are wide on purpose: they catch a constant edited by accident, not a
-- deliberate rebalance, which should move them.
-- Reusing the equilibrium the cadence block already ran, which is also the point at which these
-- numbers mean what they say: the shipped reactor ends up around 8.8e8 C, Q 2.1, 133 MW. It passes
-- these bounds two minutes into a cold start as well, at 6.2e8 C and Q 1.4 -- which is why the
-- horizon is stated rather than left implicit.
local hot_t, hot_state = fine_t, fine_state
local out_w = hot_state.energy_units * SPEC.energy_fluid_j_per_unit * 60
check(hot_t > 1e8 and hot_t < 2e9, "the shipped reactor settles at a fusion temperature",
  string.format("%.3g C", hot_t))
check(hot_state.q_factor > 1, "the shipped reactor reaches Q > 1", string.format("Q = %.3g", hot_state.q_factor))
check(out_w > SPEC.heating_power_w, "the shipped reactor is net positive",
  string.format("out %.3g W vs heating %.3g W", out_w, SPEC.heating_power_w))

-- ----------------------------------------------------------------

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
print("OK")
