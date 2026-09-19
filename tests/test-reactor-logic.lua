-- Tests for the reactor power balance.
--
-- Run from the repository root:   lua tests/test-reactor-logic.lua
--
-- Like tests/test-reactivity.lua this runs outside Factorio, which is only possible because the
-- module under test touches no Factorio API (ADR 0005). Written to Lua 5.2 semantics and verified
-- on 5.4.

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
local H = require("harness")
local L = require("scripts.reactor-logic")
-- Required directly by the D-T block at the bottom, which recomputes one rate from the dataset to
-- pin down the reactant densities step() feeds it. Nothing else here reaches past reactor-logic.
local reactivity = require("scripts.reactivity")

local check, near = H.check, H.near

-- The values the shipped rf-reactor runs with, taken from the module rather than copied, so the
-- balance checks at the bottom cannot quietly start testing different numbers from the game's.
local SPEC = L.reactor

local TICK = 1 / 60
-- The reactor's input fluidbox volume, taken from the module for the same reason SPEC is: the
-- prototype writes its box from this field too, so the game and this file cannot run different
-- reactors (#153).
local FULL = SPEC.box_volume
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
--
-- THE LOOP ITSELF LIVES IN reactor-logic SINCE #53, and this is a wrapper over it rather than a
-- second copy. control.lua's confinement guard has to settle a reactor at load, and #51 is the
-- record of what it costs to have one piece of arithmetic implemented twice. What stayed here is
-- the argument order and the defaults, which every call below is written against.
local function settle(spec, seconds, paid_j, dt, fluid, amount)
  return L.settle(spec, fluid or "rf-d-d-plasma", amount or FULL, seconds, paid_j, dt or TICK)
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

  -- The ion composition every row must declare (#98). `fractions` cannot serve here and this is
  -- the trap: it is a RATE multiplier, not a population -- D-D's two entries are both 1 because
  -- both its reactants come out of one pool, so they do not sum to anything meaningful. `ions`
  -- is the population, and its shares do sum to one.
  -- Guarded rather than indexed straight through, following this file's own rule that a nil is a
  -- failure and not an error: a row missing the field should fail one check and let the rest run,
  -- not crash the suite and hide everything after it.
  local has_ions = type(fuel.ions) == "table" and #fuel.ions >= 1
  check(has_ions, string.format("%s declares its ion composition", name))
  if has_ions then
    local sum = 0
    for _, ion in ipairs(fuel.ions) do
      check(type(ion.z) == "number" and ion.z >= 1 and ion.z % 1 == 0,
        string.format("%s declares an integer nuclear charge for each species", name))
      sum = sum + (ion.frac or 0)
    end
    check(math.abs(sum - 1) < 1e-12,
      string.format("%s's ion shares sum to one", name),
      string.format("summed to %.12g", sum))
  end

  -- And the composition must agree with `fractions` about whether this is one species or two, so
  -- the two fields cannot drift apart: a like-species row has both rate fractions at 1 and exactly
  -- one population entry, an even mix has both at 0.5 and two entries.
  local like = fuel.fractions[1] == 1 and fuel.fractions[2] == 1
  check(has_ions and #fuel.ions == (like and 1 or 2),
    string.format("%s's composition agrees with its fractions about being %s", name,
      like and "one species" or "a mix"),
    string.format("%s ion entries against fractions {%g, %g}",
      has_ions and tostring(#fuel.ions) or "no", fuel.fractions[1], fuel.fractions[2]))

  -- And for a mix, agrees about the SHARES and their order, not merely the count. Comparing counts
  -- alone was the first version of this check and it did less than its name claimed: a row with
  -- `fractions = {0.85, 0.15}` and `ions = {{z=1,frac=0.5},{z=5,frac=0.5}}` satisfied every check
  -- above -- two entries, integral charges, shares summing to one -- while contradicting
  -- `fractions` outright, and #52 would then have read the wrong n_e and Z_eff for it. Order
  -- matters for the same reason and is free to pin while the shipped rows are still symmetric:
  -- today's 50/50 rows cannot tell the two orders apart, and the first uneven row would.
  if has_ions and not like then
    for i = 1, 2 do
      if fuel.ions[i] then
        near(fuel.ions[i].frac, fuel.fractions[i], 1e-12,
          string.format("%s's species %d holds the share its fractions claim", name, i))
      end
    end
  end
end

-- ---------------------------------------------------------------- electrons per ion (#98)

-- Why this exists. docs/research/bremsstrahlung.md states that Z_eff = 1 and n_e = n_i are "exactly
-- right for both shipped plasmas", and it was right about the two it had analysed -- D-D and D-T are
-- hydrogenic. Helium-3 is Z = 2, so they are wrong for the other two, and radiation goes as
-- Z_eff * n_e^2. #52 must not bake hydrogen's constants in; these are the numbers it has to read.
--
-- Consumed by step() since #52 -- both by the radiation term and by the heat capacity, which carried
-- the same hydrogenic assumption. Asserted here so that the row a later editor writes, or flattens,
-- fails at the bench rather than silently under-radiating a tier.
for _, case in ipairs({
  { "rf-d-d-plasma",     1.0, 1.0     },
  { "rf-d-t-plasma",     1.0, 1.0     },
  { "rf-d-he3-plasma",   1.5, 5 / 3   },
  { "rf-he3-he3-plasma", 2.0, 2.0     },
}) do
  local n_e, z_eff = L.electrons(L.fuels[case[1]])
  near(n_e, case[2], 1e-12, string.format("%s carries %.2f electrons per ion", case[1], case[2]))
  near(z_eff, case[3], 1e-12, string.format("%s has Z_eff %.4g", case[1], case[3]))
end

-- The pair the whole ticket is about, stated as the comparison rather than as two numbers: a
-- hydrogenic assumption understates their radiation, and by how much depends on both terms, so
-- asserting only Z_eff would let n_e be flattened silently and the other way round.
local dhe3_ne, dhe3_z = L.electrons(L.fuels["rf-d-he3-plasma"])
local he3_ne, he3_z = L.electrons(L.fuels["rf-he3-he3-plasma"])
check(dhe3_ne > 1 and dhe3_z > 1, "a D-He3 plasma is not hydrogenic in either term",
  string.format("n_e/n_i %.4g, Z_eff %.4g", dhe3_ne, dhe3_z))
check(he3_ne > dhe3_ne and he3_z > dhe3_z, "and a He3-He3 plasma is further from it in both",
  string.format("n_e/n_i %.4g, Z_eff %.4g", he3_ne, he3_z))

-- The electron-ion part of the radiation, which is what these two numbers multiply. The full
-- factor is not this -- the relativistic correction adds an electron-electron term that does not
-- scale with charge -- so tests/test-further-reactions.lua carries the 3.13x and 6.34x figures
-- against the real form. This is the part that lives in the data rather than in the formula.
near(dhe3_ne * dhe3_ne * dhe3_z, 3.75, 1e-9,
  "D-He3's electron-ion radiation factor is 3.75 against hydrogen's 1")
near(he3_ne * he3_ne * he3_z, 8.0, 1e-9,
  "He3-He3's electron-ion radiation factor is 8 against hydrogen's 1")

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

-- AND THAT IS TRUE OF D-D AND FALSE OF D-T, which is the whole of #70's answer and is why the two
-- tiers are checked side by side here rather than one of them being taken as the reactor's behaviour.
--
-- At the same temperature and the same density, with no power going in at all, a D-T plasma climbs
-- and a D-D plasma falls: D-T passes Lawson at this reactor's density and confinement time, so its
-- own alpha heating outruns the loss and the confinement heating is what gets it TO a fusing
-- temperature rather than what keeps it at one. So a brownout does not cost a lit D-T reactor its
-- plasma, and cutting its power raises its net contribution rather than lowering it -- the opposite
-- of the runaway #70 was opened on.
--
-- Measured in a running game by scripts/check-brownout.ps1, which is the evidence; this is the
-- second-long guard that fails first if a balance change ever takes D-T back below ignition.
local unpowered_dt = L.step(SPEC, "rf-d-t-plasma", FULL, HOT, 0, TICK)
local unpowered_dd = L.step(SPEC, "rf-d-d-plasma", FULL, HOT, 0, TICK)
check(unpowered_dt.temperature_c > HOT, "an unpowered D-T plasma at a fusing temperature climbs anyway",
  string.format("%.6g C from %.6g", unpowered_dt.temperature_c, HOT))
check(unpowered_dd.temperature_c < HOT, "where a D-D plasma at the same temperature and density falls",
  string.format("%.6g C from %.6g", unpowered_dd.temperature_c, HOT))
near(unpowered_dt.heating_used_j, 0, 0, "and it is climbing on nothing: no heating was spent")

-- Left alone with no power for five minutes the two end up three and a half orders apart, which is
-- the figure the ADR 0015 correction quotes. Asserted as a separation rather than as two values,
-- because both move with the balance and the separation is the claim.
local held_dt, held_dd = HOT, HOT
for _ = 1, math.floor(300 / TICK) do
  held_dt = L.step(SPEC, "rf-d-t-plasma", FULL, held_dt, 0, TICK).temperature_c
  held_dd = L.step(SPEC, "rf-d-d-plasma", FULL, held_dd, 0, TICK).temperature_c
end
-- ~~All the way to the top of its range.~~ **To its own equilibrium since #58** -- it used to reach
-- the clamp because the clamp was under the equilibrium, not because five minutes is enough to
-- arrive anywhere in particular. Unpowered, an ignited D-T plasma still climbs on alpha heating
-- alone; where it stops is now physics rather than a declared bound.
check(held_dt > 3e9 and held_dt < SPEC.max_temperature_c,
  "five unpowered minutes take the D-T plasma to its own equilibrium, short of the clamp",
  string.format("%.6g C, clamp %.6g C", held_dt, SPEC.max_temperature_c))
check(held_dd < held_dt / 1000, "and take the D-D plasma out of the fusing range entirely",
  string.format("%.6g C against %.6g C", held_dd, held_dt))

-- A partly powered reactor is heated by what it was paid, not by what it wants.
--
-- THE FIFTH ARGUMENT IS A PAYMENT SINCE #72, not a buffer reading. control.lua pays for the
-- heating every tick and accumulates what it actually got, so a brownout reaches step() as a
-- smaller number of joules rather than as a shortfall for step() to discover. The arithmetic is
-- unchanged by that -- it always clamped to this argument -- but what a caller is saying by
-- passing 1000 is different, and this file is where it is written down.
local starved = L.step(SPEC, "rf-d-d-plasma", FULL, 1.0e7, 1000, TICK)
near(starved.heating_used_j, 1000, 1e-12, "a starved reactor is heated only by what it was paid")

-- And the other direction, which is the one per-tick spending made reachable: a caller may hand
-- over MORE than the interval's heating, and the plasma is still heated at heating_power_w.
--
-- It is not a hypothetical. math.huge is exactly that overpayment, it is what every settle() in
-- this file and in reactor-logic's own confinement guard passes for "never starved", and without
-- the clamp it would heat the plasma by an infinity of joules. This is the line that keeps that
-- meaning.
local overpaid = L.step(SPEC, "rf-d-d-plasma", FULL, SPEC.min_temperature_c,
  SPEC.heating_power_w * TICK * 100, TICK)
near(overpaid.heating_used_j, SPEC.heating_power_w * TICK, 1e-12,
  "a reactor paid a hundred times over is still heated at heating_power_w")
near(overpaid.temperature_c, warm.temperature_c, 1e-12,
  "so it reaches the same temperature as one paid exactly")

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
-- ~~What stops it here is the clamp at the top of the fluid's declared range.~~ **NOT SINCE #58.**
-- The clamp moved to 5e9, which is above where this reaction settles, so what stops it now is its
-- own cross-section rolling over past its peak. That is the whole of what #58 bought: the number a
-- player reads is a measurement again rather than a constant.
--
-- 3.25e9 at the shipped 30 s, measured through step() at this file's tick. It moves with
-- confinement -- 3.92e9 at the top rung -- which is the property the ladder test below pins, and
-- the reason this one is a band rather than a point.
local dt_t, dt_state = settle(SPEC, 60, math.huge, nil, "rf-d-t-plasma")
near(dt_t, 3.248e9, 0.01, "a D-T plasma ignites and settles at its own equilibrium")
check(dt_t < SPEC.max_temperature_c,
  "which is BELOW the clamp, so the reading is its temperature and not the ceiling (#58)",
  string.format("%.6g C against a clamp at %.6g C", dt_t, SPEC.max_temperature_c))
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

-- Nil rather than a table of zeroes, which is what lets control.lua leave the entity alone -- and
-- since #93 it is also what makes every one of these arms sell NO capture heat. There is no
-- separate gate on the joules: a return of nil has no `joules` field to add, so heat follows
-- breeding through exactly the same door (ADR 0019, decision 2).
check(L.breed(SPEC, BLANKET, 0, CHARGED) == nil, "no neutrons, nothing bred, and no heat")
check(L.breed(SPEC, BLANKET, nil, CHARGED) == nil, "a reactor with no step breeds nothing")
check(L.breed(SPEC, BLANKET, 1e20, 0) == nil, "an empty blanket breeds nothing, and heats nothing")
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
-- And sells exactly the heat that bought, for the same reason and by the same arithmetic: the
-- joules come off `bred` rather than off the neutron count, so every cap in this function carries
-- into the heat without a rule of its own (#93). A blanket held back by a full collector is the
-- same statement with the cap coming from control.lua instead.
near(short.joules, wanted.joules / 2, 1e-12, "and sells exactly the capture heat that bought")

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

-- ---- what the blanket SELLS (#93, ADR 0019)
--
-- The blanket stopped being a fuel fitting only. docs/research/blanket-capture-energy.md pins the
-- figure and tests/test-blanket-energy.lua asserts the derivation against published masses; what
-- is asserted here is that the shipped function returns it and that it is disjoint from what
-- step() already sold.

local EV = 1.602176634e-19

-- Per TRITON, which is the form breed() multiplies, and per NEUTRON, which is the form the
-- literature quotes. Both read off the shipped function rather than written down twice.
near(L.capture_energy_j(BLANKET) / EV / 1e6, 4.12428, 1e-5,
  "a blanket releases 4.124 MeV per triton bred")
near(L.capture_energy_j(BLANKET) * BLANKET.tritium_per_neutron / EV / 1e6, 4.53671, 1e-5,
  "which is 4.537 MeV per neutron entering it, at the shipped breeding ratio")
-- Derived from the ratio, not stored beside it. Both branches make one triton, so the blend is
-- fixed by the neutron balance: one Li-6 capture per neutron whatever the ratio, and TBR - 1 Li-7
-- reactions to account for the rest. At a ratio of exactly 1 the endothermic branch disappears and
-- the figure is the bare Li-6 ceiling -- which is the property that says the two cannot contradict.
near(L.capture_energy_j({ tritium_per_neutron = 1.0,
    li6_capture_ev = BLANKET.li6_capture_ev, li7_breeding_ev = BLANKET.li7_breeding_ev })
  / EV / 1e6, 4.78347, 1e-5,
  "and moving the ratio to 1 gives the bare Li-6 ceiling, because the blend is derived from it")
check(L.capture_energy_j(BLANKET) * BLANKET.tritium_per_neutron < BLANKET.li6_capture_ev * EV,
  "so the shipped blend sits BELOW that ceiling -- the endothermic branch costs something")

near(bred.joules, bred.tritium_units * SPEC.particles_per_unit * L.capture_energy_j(BLANKET), 1e-9,
  "and what a step sells is that figure times the tritons it actually bred")

-- THE NEUTRON IS NOT SOLD TWICE, which is the whole hazard ADR 0019 named and #91 was opened to
-- close. Two disjoint statements, one for each half of the accounting.
--
-- FIRST: step() sells the neutron's kinetic energy exactly once. What it sells, before
-- capture_efficiency, is (fusion_j - charged_j) + left_j -- the neutron plus first-wall leakage --
-- so dividing by the neutron's own share of the release has to land just above 1. A reactor
-- selling it twice would land near 2, and there is no tolerance wide enough to confuse the two.
--
-- 1.5 rather than something tighter, because the leakage term MOVES WITH TEMPERATURE and this
-- assertion is about a double count rather than about a value: it is 1.027 at the 6e8 C here and
-- 1.173 at the 2.548e9 C a D-T reactor settles at in game, where the plasma sits on the clamp and
-- radiates hard. Both are unmistakably one neutron and not two.
local fusion_j  = dt_hot.fusion_power_w * TICK
local neutron_j = fusion_j * (1 - L.fuels["rf-d-t-plasma"].charged_fraction)
local sold_j    = dt_hot.energy_units * SPEC.energy_fluid_j_per_unit / SPEC.capture_efficiency
check(sold_j > neutron_j and sold_j < 1.5 * neutron_j,
  "step() sells the neutron's kinetic energy exactly once, plus the wall leakage and no more",
  string.format("%.4f x the neutron's own %.4g J", sold_j / neutron_j, neutron_j))

-- SECOND: the blanket adds the capture reactions' nuclear Q and nothing else. A published energy
-- multiplication factor ALREADY CONTAINS the neutron's kinetic energy, so importing one would put
-- 16.87 MeV per neutron into the same box the neutron's own 14.06 MeV already landed in -- 3.7x the
-- right figure, and more than double a D-T reactor's whole output. Both wrong imports are computed
-- here so the numbers are on record rather than in a paragraph.
local per_neutron  = bred.joules / dt_hot.neutrons
local naive_import = 1.2 * 14.06e6 * EV
near(naive_import / per_neutron, 3.719, 1e-3,
  "M x E_n at M = 1.2 is 3.7x what the blanket sells, which is what a naive import would cost")
near((1.2 - 1) * 14.06e6 * EV / per_neutron, 0.6198, 1e-3,
  "and (M - 1) x E_n strips the kinetic energy out correctly but still misses, at 0.62x")
check(per_neutron < 0.4 * neutron_j / dt_hot.neutrons,
  "so the blanket's own term is a THIRD of the neutron it rides on, not a multiple of it",
  string.format("%.4g J against the neutron's %.4g J",
    per_neutron, neutron_j / dt_hot.neutrons))

-- What it is worth, as the uplift a player will actually see on the fluid box. Both terms cross the
-- same capture_efficiency (ADR 0019, decision 4), so the ratio is the same whatever that constant
-- becomes under ADR 0020 -- which is why the two features do not interact.
--
-- MEASURED AT ONE TEMPERATURE, NOT AT EQUILIBRIUM, and therefore NOT the number
-- rf-signal-blanket-share will read: sold energy carries the leakage term, which is an equilibrium
-- quantity. The share a player sees has to be measured in game once the signal exists.
check(bred.joules / sold_j > 0.25 and bred.joules / sold_j < 0.35,
  "a blanket is worth about 31% more sold energy on a D-T reactor at 6e8 C",
  string.format("+%.2f%%", 100 * bred.joules / sold_j))
-- Any fuel, with no per-tier gate (ADR 0019, decision 3). D-D makes a neutron on half its
-- reactions, so the blanket earns its keep there too and by arithmetic rather than by a rule.
check(dd_bred.joules > 0, "a blanket on a D-D reactor sells capture heat too, with no per-tier gate",
  string.format("%.4g J a step", dd_bred.joules))
near(dd_bred.joules / dd_bred.tritium_units, bred.joules / bred.tritium_units, 1e-9,
  "and per triton bred it sells exactly the same, because the blanket does not know the fuel")

-- ---------------------------------------------------------------- aneutronic tier (#31)
--
-- The third and fourth reactions, and the second reactor. Everything here drives the same step()
-- the D-D and D-T blocks do, with a different spec passed in -- which is the claim ADR 0005 made
-- and the reason a reactor is a table of constants rather than a class.

local ANEUTRONIC = L.aneutronic_reactor
-- The aneutronic reactor holds three times the plasma in the same volume, so a full one is three
-- times the density. Taken from the module the way FULL is, and the prototype's box is written from
-- the same field, so the two cannot disagree (#153).
local ANEUTRONIC_FULL = ANEUTRONIC.box_volume

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
  "a lithium blanket on an aneutronic reactor breeds nothing, and sells no heat")

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
-- REWRITTEN BY #52, AND WHAT CHANGED IS THE PHYSICS RATHER THAN THE ASSERTION. Before the radiation
-- term both aneutronic plasmas ignited and ran to the clamp. Neither does now, and helium-3's charge
-- is why: at Z = 2 it brings two electrons per nucleus, radiation goes as Z_eff n_e^2, and the two
-- terms together put a D-He3 plasma at 3.13x and a He3-He3 plasma at 6.34x the radiation a
-- hydrogenic plasma of the same ion density would suffer (#98).
--
-- NO BALANCE CONSTANT WAS TOUCHED TO PRODUCE THESE NUMBERS, and none may be touched to move them
-- back: #52's last criterion reserves the aneutronic tiers' response for Truls, precisely so nobody
-- picks a heating power that makes this block pass. What is asserted here is what the shipped
-- constants now do.
--
-- D-He3 IS DENSITY-SENSITIVE, WHICH IS THE WHOLE OF IT, and the first version of this block got it
-- wrong by testing one fill and generalising. Radiation goes as n^2 and so does the fusion rate, but
-- the HEATING IS FIXED at 200 MW -- so there is a density above which radiation swamps the heater
-- before the plasma can climb, and below which it cannot. A full box traps the plasma cold; half a
-- box ignites it and is close to the best the tier does:
--
--     3000 u  1.37e7 C   Q 6e-8      full, trapped
--     2000 u  6.27e7 C   Q 0.0017    still trapped
--     1500 u  clamp      Q 20.7      ignited, and the optimum
--      500 u  clamp      Q 2.3        thinner: lights easily, fuses less
--
-- This is ADR 0016's operating-density lever, arriving on a tier that had no use for it before: "a
-- reaction has a density at which it makes the most power, and it is not necessarily a full one".
-- Here it is not a full one by a factor of two.
--
-- IT IS ALSO WHY THE MAP RIGS STILL PASS. scripts/check-aneutronic.ps1 sees this reactor ignite to
-- the clamp, because a heater feeding a reactor does not hold its box at 3000 units. Nothing about
-- the rigs was changed for #52; the in-game reactor was already on the lit side of the fold.
local an_t, an_state = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-d-he3-plasma", ANEUTRONIC_FULL)
check(an_t < 1e8, "a FULL D-He3 plasma no longer ignites: radiation traps it at the cold root",
  string.format("%.3g C at %d units, against a clamp at %.3g C",
    an_t, ANEUTRONIC_FULL, ANEUTRONIC.max_temperature_c))
check(an_state.q_factor < 1e-3, "and fuses essentially nothing there",
  string.format("Q = %.3g", an_state.q_factor))
-- Half the fill, nothing else changed -- not the heating, not a constant.
local half_t, half_state = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-d-he3-plasma",
  ANEUTRONIC_FULL / 2)
-- ~~Runs to the clamp.~~ **To 4.41e9 since #58**, which is where D-He3 actually settles at this
-- density -- and this tier is the one the old 2e9 was really pinning. Its Q falls slightly with the
-- unpinning, 20.7 to 18.8, because the plasma now runs past its own cross-section peak instead of
-- being held below it. That is correct rather than a regression: see the fuel row.
near(half_t, 4.406e9, 0.01,
  "at half fill the same reactor ignites and settles at its own equilibrium")
check(half_t < ANEUTRONIC.max_temperature_c,
  "below the clamp, so this tier stopped being pinned too (#58)",
  string.format("%.6g C against a clamp at %.6g C", half_t, ANEUTRONIC.max_temperature_c))
check(half_state.q_factor > 10, "and runs far past break-even there, which is the tier's optimum",
  string.format("Q = %.3g at %d units", half_state.q_factor, ANEUTRONIC_FULL / 2))
-- Raising the heating clears the full box too, so the fold is a ratio rather than a wall.
local lit = {}
for key, value in pairs(ANEUTRONIC) do lit[key] = value end
lit.heating_power_w = ANEUTRONIC.heating_power_w * 4
local lit_t = settle(lit, SETTLE_S, math.huge, nil, "rf-d-he3-plasma", ANEUTRONIC_FULL)
near(lit_t, 4.584e9, 0.01,
  "and four times the heating clears a full box, so what matters is heating against n^2")

-- THE FINDING THAT MATTERS ABOUT HE3-HE3, AND #52 REPLACED IT WITH A HARDER ONE.
--
-- What this block used to say: the tier climbs to the clamp but gets there burning at about a
-- hundredth of its peak reactivity, because its cross-section peaks past 600 keV and the clamp stops
-- the plasma at 172 -- so it arrives barely above break-even, at Q 1.31, and ADR 0014 is what makes
-- a marginal tier shippable rather than broken. All of that was true of a model with no radiation.
--
-- WITH THE TERM COUNTED THERE IS NO IGNITED STATE TO ARRIVE AT. Its charged fusion power is between
-- 1.7% and 6% of its own bremsstrahlung everywhere in the dataset, so there is nothing above the
-- cold root to climb to at any heating power -- docs/research/further-reactions.md sweeps it and
-- finds the clamp reachable only on about 10.2 GW, radiating 9 672 MW to make 261 MW. The Q of 1.31
-- this tier used to report was an artefact of the missing channel, in exactly the way D-D's 2.14 was.
--
-- The raised-clamp check that used to live here is gone with it: it asked whether Q at the ceiling
-- depends on where the ceiling is, and the plasma no longer reaches any ceiling, so the question has
-- no subject. Nothing replaces it, because a clamp is not what stops this tier now.
--
-- WHETHER THAT IS ACCEPTABLE IS TRULS'S CALL AND IS NOT SETTLED HERE (#52's last criterion). What is
-- asserted is only what the shipped constants do.
-- AND THE DENSITY LEVER DOES NOT RESCUE IT, which is the difference between this tier and its
-- neighbour. Thinning gets it hot -- 300 units settles at 2.51e9 -- but being hot is not IGNITING.
-- CONTEXT.md fixes that word: an ignited plasma is one "whose own fusion self-heating carries it
-- without external confinement heating". At 300 units the 200 MW heater is carrying the whole
-- thing. The plasma is hot because it is thin and being heated, not because it is fusing.
--
--     3000 u  3.11e6 C   Q 9e-48
--      500 u  1.08e9 C   Q 0.0062
--      300 u  2.51e9 C   Q 0.0224
--      200 u  4.33e9 C   Q 0.0306
--      179 u  5.00e9 C   Q 0.0318   <- the best it does, at any fill, and already at the clamp
--      150 u  5.00e9 C   Q 0.0226      thinner still is worse, and pinned
--
-- The peak is at 179 units and was found on a ONE-UNIT sweep. A 25-unit sweep misses it and reports
-- whichever sampled fill happened to be highest -- which is how 0.0307 reached three files at once.
--
-- AND #58 DID NOT RESCUE IT EITHER, which is worth stating because #58's own ticket expected it to.
-- That ticket predicted this tier would arrive "materially stronger" at a raised ceiling, Q 1.31 to
-- 15.9. Those were pre-#52 figures, from a model carrying no radiation. Measured with the term in,
-- raising the ceiling from 2e9 to 5e9 takes its best Q from 0.0177 to 0.0318 -- a factor of 1.8 on
-- a number two orders below break-even, which is not a rescue in any sense a player would notice.
-- Radiation sets this equilibrium, not the clamp, and no ceiling changes that.
--
-- So D-He3 has a fold it can be moved across and this has a wall it cannot: every fill trades
-- temperature against rate and none of them buys fusion. That is what "no ignited state" means here,
-- and it is why the old Q of 1.31 was the missing term rather than the machine.
local he3_t, he3_state = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-he3-he3-plasma", ANEUTRONIC_FULL)
check(he3_t < 1e7, "a full He3-He3 plasma stays cold",
  string.format("%.3g C, against a clamp at %.3g C", he3_t, ANEUTRONIC.max_temperature_c))
check(he3_state.q_factor < 1,
  "so the Q of 1.31 this tier used to report was the missing radiation term, not the machine",
  string.format("Q = %.3g", he3_state.q_factor))
-- The fill that treats it best, so the claim is about the fuel rather than about one operating point.
local he3_best_q = 0
for _, amount in ipairs({ 1500, 1000, 500, 300, 200, 100 }) do
  local _, st = settle(ANEUTRONIC, SETTLE_S, math.huge, nil, "rf-he3-he3-plasma", amount)
  if st.q_factor > he3_best_q then he3_best_q = st.q_factor end
end
check(he3_best_q < 0.05,
  "and no fill ignites it, at the raised ceiling either -- heater power, not fusion (#58)",
  string.format("best Q %.4g across six fills, against D-He3's %.3g at half fill",
    he3_best_q, half_state.q_factor))

-- Every spec the mod ships needs the fields the mod indexes off it without asking. The fuel rows are
-- covered at the top of this file; this is the other half of the same guard, and it exists because a
-- second reactor is exactly the moment a spec field gets added to one and not the other.
--
-- NINE OF THE TEN ARE INDEXED AT RUNTIME, by step() or by control.lua. box_volume is the tenth and
-- is indexed at the PROTOTYPE stage instead -- prototypes/entities.lua writes each reactor's plasma
-- box from it, and control.lua deliberately reads the LOADED box rather than this field, because a
-- mod sorting after us can change it. Missing it would fail the data stage and the two locals at the
-- head of this file rather than a runtime call, which is the same class of breakage and the reason
-- it belongs in this list (#153).
for label, spec in pairs({ ["rf-reactor"] = SPEC, ["rf-aneutronic-reactor"] = ANEUTRONIC }) do
  for _, field in ipairs({ "volume_m3", "box_volume", "particles_per_unit", "heating_power_w",
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
-- Not a physics check -- a check that the numbers the mod ships with produce the reactor that was
-- INTENDED. Read the next paragraph before filing any of this as a regression.
--
-- THE D-D TIER IS BELOW BREAK-EVEN, AND THAT IS THE DECISION RATHER THAN A SHORTFALL. It settles
-- around 2.4e8 C at Q 0.32 and sells less than the 50 MW it draws. Until #52 the model carried no
-- radiation loss at all, and without one the same reactor read 8.8e8 C at Q 2.14 -- a number that
-- was an artefact of the missing channel, not a property of the machine. Bremsstrahlung is real, it
-- goes as Z_eff n_e^2 sqrt(T), and a D-D plasma at 1e20 m^-3 with 30 s of confinement is genuinely
-- nowhere near ignition. ADR 0015 accepted that and named the consequence: the D-D tier is a
-- BREEDER TIER, whose product is fuel rather than electricity and which is meant to be run at a
-- loss until a player researches out of it. ADR 0014 makes a tier arriving net negative legitimate.
--
-- So the assertions below are inverted ON PURPOSE from what they said before #52. What would be a
-- regression is D-D climbing back above break-even without a deliberate rebalance -- the reverse of
-- what this block used to guard.
--
-- The figures are #51's, pinned to 1% in tests/test-bremsstrahlung.lua and reproduced here through
-- the SHIPPED step() rather than a local model, which is the point: before #52 that file's header
-- said "nothing shipped uses this", and now the shipped balance and the research note have to agree.
local hot_t, hot_state = fine_t, fine_state
local out_w = hot_state.energy_units * SPEC.energy_fluid_j_per_unit * 60
check(hot_t > 1e8 and hot_t < 2e9, "the shipped reactor settles at a fusion temperature",
  string.format("%.3g C", hot_t))
near(hot_t, 2.422e8, 0.01, "the shipped D-D reactor settles where #51 pinned it, 2.422e8 C")
near(hot_state.q_factor, 0.3205, 0.01, "at #51's Q of 0.3205")

-- ------------------------------------------------------------------ what #58 moved, and what not
--
-- The ceiling went 2e9 -> 5e9. These four assertions are the whole of what that did, each measured
-- through the shipped step() at both ceilings rather than argued from one.
--
-- THE FIRST TIER IS UNTOUCHED, and this is the assertion that proves it rather than asserting it.
-- Same spec, same fuel, the two ceilings differing: D-D settles at the same temperature to the last
-- figure the model carries, because it was never anywhere near either clamp. A balance change that
-- moved the tier a player starts on would be a different ticket.
local function at_ceiling(ceiling, fuel, amount)
  local s = {}
  for k, v in pairs(SPEC) do s[k] = v end
  s.max_temperature_c = ceiling
  local temperature, state = settle(s, SETTLE_S, math.huge, nil, fuel, amount)
  return temperature, state
end
local dd_low = at_ceiling(2e9, "rf-d-d-plasma", FULL)
local dd_high = at_ceiling(5e9, "rf-d-d-plasma", FULL)
near(dd_high, dd_low, 1e-12,
  "#58 moved the ceiling and a normally supplied D-D reactor did not move at all")

-- AND THE QUALIFICATION, WHICH THE FULL-FILL CHECK ABOVE CANNOT SEE AND WHICH IT WOULD BE DISHONEST
-- TO OMIT. "D-D is unchanged" is true of a supplied reactor and FALSE of a thin one, because a thin
-- D-D plasma was already against the old 2e9 clamp -- ADR 0024 records exactly that: "a reactor held
-- at a tenth of a box is against the clamp already, at the shipped 30 s". Anything that was pinned
-- necessarily moves when the pin moves. That is unpinning rather than re-tuning, and it is the same
-- effect #58 was opened to produce on D-T; it reaches this tier too at fills nobody has to run.
--
--     tau 30, 1000 u   2.422e8 -> unchanged        tau 60, 1000 u   6.483e8 -> unchanged
--     tau 30,  250 u   1.463e9 -> unchanged        tau 60,  250 u   2e9 -> 2.755e9   moved
--     tau 30,  100 u   2e9 -> 3.545e9   moved      tau 60,  100 u   2e9 -> 5e9       still pinned
--
-- So the honest claim is the one asserted here: unchanged wherever it was not already against the
-- old clamp, and moved exactly where it was. Asserted both ways so neither half can rot.
local dd_thin_low = at_ceiling(2e9, "rf-d-d-plasma", FULL / 10)
local dd_thin_high = at_ceiling(5e9, "rf-d-d-plasma", FULL / 10)
near(dd_thin_low, 2e9, 1e-12,
  "a tenth-full D-D plasma was against the old clamp, which is why it is the case that moves")
check(dd_thin_high > dd_thin_low * 1.5,
  "so it unpins with the ceiling -- D-D is unchanged when SUPPLIED, not unconditionally (#58)",
  string.format("%.6g C, up from a pinned %.6g C", dd_thin_high, dd_thin_low))

-- D-T IS THE TIER THE TICKET IS FOR: pinned at the old ceiling, free at the new one. Both measured
-- here so the change is a comparison rather than a claim.
local dt_low = at_ceiling(2e9, "rf-d-t-plasma", FULL)
local dt_high = at_ceiling(5e9, "rf-d-t-plasma", FULL)
near(dt_low, 2e9, 1e-12, "D-T was pinned against the old 2e9 ceiling")
check(dt_high > dt_low * 1.5 and dt_high < 5e9,
  "and is free of the new one, settling on its own cross-section instead (#58)",
  string.format("%.6g C, up from a pinned %.6g C", dt_high, dt_low))

-- AND THE PART OF #58 THAT IS A LOSS, asserted so it cannot later be filed as a regression. D-He3
-- gives Q back when it unpins, because the extra temperature carries it past its own cross-section
-- peak. The ticket says so too; this is the measurement behind it.
local _, dhe3_low = (function()
  local s = {}
  for k, v in pairs(ANEUTRONIC) do s[k] = v end
  s.max_temperature_c = 2e9
  return settle(s, SETTLE_S, math.huge, nil, "rf-d-he3-plasma", ANEUTRONIC_FULL / 2)
end)()
check(half_state.q_factor < dhe3_low.q_factor,
  "D-He3 gives Q back at the raised ceiling -- past its cross-section peak, not a regression (#58)",
  string.format("Q %.4g at 5e9 against %.4g at 2e9", half_state.q_factor, dhe3_low.q_factor))
check(hot_state.q_factor < 1, "which is below SCIENTIFIC break-even, by decision -- see ADR 0015",
  string.format("Q = %.3g", hot_state.q_factor))

-- AND HERE IS WHERE #52's OWN PREMISE DOES NOT SURVIVE ITS IMPLEMENTATION, recorded rather than
-- smoothed over. That ticket says a D-D reactor "settles below break-even -- a machine a player runs
-- at a loss". It settles below Q = 1, which is scientific break-even. It does NOT run at a loss.
--
-- Engineering break-even in this model is Q >= (1 - eta) / eta, which at eta = 0.85 is 0.1765 -- and
-- D-D lands at 0.3205, comfortably above it. The reason is that the X-rays are not thrown away: they
-- hit the first wall and heat it, so step() sells them through left_j at capture_efficiency, which
-- docs/research/bremsstrahlung.md calls physically right and is why the term needed no new plumbing.
-- The reactor therefore radiates hard, recovers most of it as wall heat, and clears its own heating
-- bill: 56.1 MW sold against 50 MW drawn, net +6.1 MW.
--
-- THIS FORCED A VOCABULARY DECISION, AND IT WAS TAKEN. CONTEXT.md used to define a breeder tier as
-- one "which consumes more power than it makes", which the measurement above makes false. Truls chose
-- to fix the wording rather than stop selling the radiation (2026-08-21): a breeder tier is now one
-- that "makes no meaningful power", and CONTEXT.md carries a **break-even** entry distinguishing the
-- scientific sense (Q = 1) from the engineering one (0.1765 here). D-D sits between them.
--
-- The alternative was to exclude the radiation from what is sold, which would have made the tier a
-- genuine drain -- and would also have cut D-T's output, since a D-T reactor at the clamp radiates
-- hard and currently sells all of it. Rejected as unphysical: the X-rays really do heat the wall.
near(out_w / 1e6, 56.12, 0.01, "it sells 56.1 MW for the 50 MW it draws")
check(out_w > SPEC.heating_power_w,
  "so it is marginally NET POSITIVE, which is what CONTEXT.md's break-even entry now describes",
  string.format("out %.4g W vs heating %.4g W, net %+.3g W",
    out_w, SPEC.heating_power_w, out_w - SPEC.heating_power_w))
near((1 - SPEC.capture_efficiency) / SPEC.capture_efficiency, 0.1765, 0.01,
  "engineering break-even is Q 0.1765 here, which is the number that decides the sentence above")

-- ------------------------------------------------- capture efficiency is an argument (#94)
--
-- ADR 0020 makes plant efficiency researchable, and research is per force. control.lua's SPECS is
-- one table every reactor of a name shares, so the value cannot live there: it becomes an argument
-- to step(). ~~NO TECHNOLOGY EXISTS YET~~ -- three do since #96, and the ladder they move is
-- asserted in its own block below. What is asserted HERE is still the seam: that the argument
-- reaches step() and does exactly one thing.
--
-- 0.9375 is ADR 0020's third rung. ~~and is NOT shipped~~ -- it is shipped since #96, which is why
-- the block below reads it off the ladder rather than retyping it; here it is still a literal, so
-- that this block goes on testing the argument even if the ladder is later shortened.
local researched = L.step(SPEC, "rf-d-t-plasma", FULL, HOT, math.huge, TICK, 0.9375)
near(researched.energy_units / dt_hot.energy_units, 0.9375 / SPEC.capture_efficiency, 1e-12,
  "capture efficiency reaches step() as an argument, and scales the sold energy by exactly itself")

-- AND NOTHING ELSE. capture_efficiency governs what is recovered from energy that has already left
-- the plasma, so it cannot touch the plasma or any plasma statistic -- which is ADR 0020's
-- consequence that a player sees output rise with no movement in Q.
near(researched.temperature_c, dt_hot.temperature_c, 0, "and moves the plasma not at all")
near(researched.q_factor, dt_hot.q_factor, 0, "so Q does not move either, which is ADR 0020's point")
near(researched.fusion_power_w, dt_hot.fusion_power_w, 0, "nor the fusion power Q is measured from")

-- The default, which is what keeps the spec the single place the unresearched value is written
-- down -- and what lets every other call in this file, and every pure-logic caller in the mod,
-- drive the shipped constant by saying nothing. dt_hot above passed no argument at all.
near(L.step(SPEC, "rf-d-t-plasma", FULL, HOT, math.huge, TICK, SPEC.capture_efficiency).energy_units,
  dt_hot.energy_units, 0,
  "and omitting it is the same as passing the spec's own constant")

-- ------------------------------------------------------------- the floor conjures nothing (#103)

-- THAT THE CLAMP CREATES NOTHING, which is a property rather than a measurement now. #103 measured
-- it first: a plasma driven under min_temperature_c was put back up to it, so the joules it had
-- radiated away were handed back, and a full cold D-D reactor was worth 26.6 kW of that while a full
-- He3-He3 one was worth 322 kW. ADR 0021 settled the floor as the edge of the model's domain and
-- capped the drain to land a plasma exactly on it, so there is nothing to hand back.
--
-- conjured_power_w survives that fix on purpose: what it watches is a one-line property of the joint
-- clamp, and the comment on left_j in reactor-logic.lua records this file losing a very similar
-- property once already. Everything below asserts zero.

local function at_floor(spec, fluid, units)
  return L.step(spec, fluid, units, spec.min_temperature_c, 0, TICK)
end

-- A cold, unpowered reactor -- the state an idle one holding plasma sits in, indefinitely, and the
-- one the whole of #103 was about. Across fills because the conjuring went as n^2 when it existed.
local floor_dd    = at_floor(SPEC, "rf-d-d-plasma", FULL)
local floor_half  = at_floor(SPEC, "rf-d-d-plasma", FULL / 2)
local floor_tenth = at_floor(SPEC, "rf-d-d-plasma", FULL / 10)
near(floor_dd.conjured_power_w, 0, 0,
  "a full reactor parked at the floor conjures nothing to stay there")
near(floor_half.conjured_power_w, 0, 0, "nor a half-full one, where it used to be 6.7 kW")
near(floor_tenth.conjured_power_w, 0, 0, "nor a tenth-full one")

-- BOTH ANEUTRONIC FUELS, at full fill and thin. This is where it mattered: the joint clamp saturated
-- here, so the figure was the plasma's whole heat content every step rather than a radiated power,
-- and 322 kW made it the worst case in the mod by twelve times.
local floor_he3   = at_floor(ANEUTRONIC, "rf-he3-he3-plasma", ANEUTRONIC_FULL)
local floor_dhe3  = at_floor(ANEUTRONIC, "rf-d-he3-plasma", ANEUTRONIC_FULL)
local he3_thin    = at_floor(ANEUTRONIC, "rf-he3-he3-plasma", 300)
local dhe3_thin   = at_floor(ANEUTRONIC, "rf-d-he3-plasma", 300)
near(floor_he3.conjured_power_w, 0, 0, "a full He3-He3 reactor conjures nothing, where it was 322 kW")
near(floor_dhe3.conjured_power_w, 0, 0, "nor a full D-He3 one, where it was 269 kW")
near(he3_thin.conjured_power_w, 0, 0, "nor a thin He3-He3 one, below where the clamp used to saturate")
near(dhe3_thin.conjured_power_w, 0, 0, "nor a thin D-He3 one")

-- THE PLASMA STILL GETS THERE, which is the half of this that a fix could break by overshooting the
-- other way. The cap bounds the drain; it does not stop the plasma cooling.
near(floor_dd.temperature_c, SPEC.min_temperature_c, 0,
  "and it is AT the floor rather than merely near it, which is what the cap lands it on")
near(floor_he3.temperature_c, ANEUTRONIC.min_temperature_c, 0, "on the aneutronic tier too")

-- COLD-PARKED IS A FIXED POINT. Stepping a plasma that is already there changes nothing about it,
-- which is what "inert" means and is the state a reactor sits in for as long as it is unpowered.
local parked_again = at_floor(SPEC, "rf-d-d-plasma", FULL)
near(parked_again.temperature_c, floor_dd.temperature_c, 0, "and stepping it again leaves it there")

-- THE CROSSING STEP IS THE ONE A NARROWER FIX WOULD HAVE MISSED. A plasma just above the floor with
-- no heating cools past it in one step. Capping the drain lands it exactly on the floor and SELLS
-- what left; gating the radiation term at the floor would have let it overshoot and conjured the
-- difference back. So this case is both zero-conjured and non-zero-sold, and the second half is what
-- says the energy went somewhere rather than being quietly dropped.
local crossing = L.step(SPEC, "rf-d-d-plasma", FULL, 20, 0, TICK)
near(crossing.conjured_power_w, 0, 0, "a plasma cooling THROUGH the floor conjures nothing either")
near(crossing.temperature_c, SPEC.min_temperature_c, 0, "and stops exactly on it rather than under")
check(crossing.energy_units > 1e-6,
  "and what it lost on the way down is sold, because it really did leave the plasma",
  string.format("%.6g units", crossing.energy_units))

-- AND NOTHING ABOVE THE FLOOR CHANGED, which is the claim that the cap is confined to the bottom of
-- the range. A fusing reactor, one climbing under full heating, and one cooling from high with no
-- heating at all -- the last is the case that passes closest to the cap without reaching it.
local hot     = L.step(SPEC, "rf-d-d-plasma", FULL, 2.42e8, math.huge, TICK)
local warming = L.step(SPEC, "rf-d-d-plasma", FULL, 1e6, math.huge, TICK)
local cooling = L.step(SPEC, "rf-d-d-plasma", FULL, 1e6, 0, TICK)
near(hot.conjured_power_w, 0, 0, "a fusing reactor conjures nothing")
near(warming.conjured_power_w, 0, 0, "and neither does one climbing under full heating")
near(cooling.conjured_power_w, 0, 0, "nor one falling from a million degrees with the power cut")
check(cooling.temperature_c > SPEC.min_temperature_c,
  "which is still falling freely rather than being held up by the cap",
  string.format("%.7g C", cooling.temperature_c))

-- NONE OF IT IS SOLD AT THE FLOOR. This was the property that made the conjuring invisible, and it
-- still holds for the reason it always did -- left_j is floored at zero -- rather than because the
-- conjuring is gone. Not exactly zero on D-D: 4.6e-15 units a step is the charged fraction of the
-- residual fusion below, correctly sold, and eleven orders below anything a player could see.
near(floor_dd.energy_units, 0, 1e-12, "a floored reactor sells nothing")
near(floor_he3.energy_units, 0, 1e-12, "nor on the aneutronic tier")

-- AND IT IS NOT LAUNDERED INTO BY-PRODUCTS. A D-D plasma at the floor does breed a trickle -- 4659
-- neutrons a step -- but that comes from residual fusion, not from the clamp: 3.3e-7 W of it, which
-- would be there whether or not the floor existed. Asserted as negligible rather than as zero,
-- because zero is what this used to claim and it is not true.
check(floor_dd.fusion_power_w < 1e-6,
  "what fuses at the floor is negligible rather than absent",
  string.format("%.4g W", floor_dd.fusion_power_w))
check(floor_dd.neutrons > 0 and floor_dd.neutrons < 1e4,
  "so its neutron trickle comes from fusion, not from the clamp",
  string.format("%.6g per step", floor_dd.neutrons))
near(floor_he3.neutrons, 0, 0, "and the aneutronic tier breeds none at all, floor or not")

-- ------------------------------------------------- and BELOW the floor it does not hold (#107)
--
-- THE INVARIANT ABOVE IS CONDITIONAL AND THIS IS THE CONDITION. Everything from here up feeds
-- step() a temperature at or above spec.min_temperature_c, which is every temperature the engine
-- can currently produce -- so "conjures nothing" was true of the shipped game and was written down
-- as though it were true in general. It is not: the drain cap's algebra closes only from the floor
-- upward, because kept_j - floor_thermal_j is remaining * heat_per_particle * (t_k - floor_k) and
-- that is non-negative only there. Below it, drainable_j clamps to zero, the plasma still lands
-- under floor_thermal_j, the LOW clamp fires, and retained_j exceeds new_thermal_j.
--
-- ASSERTED AS PRESENT RATHER THAN FIXED, deliberately. #107 closes this by refusing to load the
-- configuration that reaches it -- see M.plasma_bounds_fault below and control.lua's
-- check_plasma_bounds -- rather than by teaching step() a physics it has none for: below the floor
-- the model is outside its own domain by ADR 0021's own statement, and there is no right answer
-- to give. So these numbers are what the load guard is worth, and a fix that made them zero would
-- delete the reason the guard exists.
local below_floor = L.step(SPEC, "rf-d-d-plasma", FULL, SPEC.min_temperature_c - 1, 0, TICK)
near(below_floor.conjured_power_w, 248.517, 0.001,
  "one degree below the floor a full D-D reactor conjures 248 W, which is why #107 refuses to load it")
local absolute_zero = L.step(SPEC, "rf-d-d-plasma", FULL, -273, 0, TICK)
near(absolute_zero.conjured_power_w, 71572.8, 0.001,
  "and 71.6 kW at -273 C, so it goes as how far under the floor the input is")
check(below_floor.conjured_power_w > 0 and absolute_zero.conjured_power_w > below_floor.conjured_power_w,
  "which is a positive, monotone quantity rather than the zero the step above reports")
near(below_floor.temperature_c, SPEC.min_temperature_c, 0,
  "and the plasma is put back up to the floor, which is where the joules come from")

-- THE GUARD THAT MAKES THE ZERO ABOVE UNCONDITIONAL. A Factorio fluid cannot hold a temperature
-- below its default_temperature, so a spec floor ABOVE it is the configuration in which the engine
-- hands step() the input just measured, on every cold reactor, permanently. It loads perfectly and
-- nothing else here would catch it -- the fluid accepts every write, the reactor runs, and the
-- plant is quietly a little more efficient than the physics allows.
--
-- Driven here rather than in a game because a load guard that fires refuses to load, so a rig that
-- loads cannot exercise it -- the same reason the confinement ladder's guard is negative-tested
-- here. control.lua supplies the prototypes and the wording; this is the decision.
local SHIPPED_MIN, SHIPPED_MAX = SPEC.min_temperature_c, SPEC.max_temperature_c
check(L.plasma_bounds_fault(SPEC, SHIPPED_MIN, SHIPPED_MAX) == nil,
  "the shipped pair passes, so load-check.ps1 is not being asked to load a mod this refuses")
check(L.plasma_bounds_fault(ANEUTRONIC, ANEUTRONIC.min_temperature_c, ANEUTRONIC.max_temperature_c) == nil,
  "and so does the aneutronic pair")
-- The direction #107 opened over: raise the simulation's floor and leave the fluid where it is.
check(L.plasma_bounds_fault({ min_temperature_c = SHIPPED_MIN + 1, max_temperature_c = SHIPPED_MAX },
    SHIPPED_MIN, SHIPPED_MAX) == "min-above-fluid",
  "a floor one degree above the fluid's is refused, which is the case that used to load and conjure")
check(L.plasma_bounds_fault({ min_temperature_c = 34540, max_temperature_c = SHIPPED_MAX },
    SHIPPED_MIN, SHIPPED_MAX) == "min-above-fluid",
  "and so is the 3 eV floor #46 wanted, which is the edit that would actually be made")
-- The direction that already errored, kept so a fix in one direction cannot lose the other.
check(L.plasma_bounds_fault({ min_temperature_c = SHIPPED_MIN - 1, max_temperature_c = SHIPPED_MAX },
    SHIPPED_MIN, SHIPPED_MAX) == "min-below-fluid",
  "a floor below the fluid's still fails, in the direction that was already checked")
check(L.plasma_bounds_fault({ min_temperature_c = SHIPPED_MIN, max_temperature_c = SHIPPED_MAX * 2 },
    SHIPPED_MIN, SHIPPED_MAX) == "max-above-fluid",
  "and so does a ceiling above the fluid's")

-- ---------------------------------------------------------------- the confinement ladder (#53)
--
-- What research does, what each rung's tooltip claims, and the guard that stops the ladder growing
-- into the temperature clamp.
--
-- THE LADDER IS THE PROGRESSION #53 IS ABOUT: a player who has researched nothing runs a D-D
-- reactor below break-even (the block above, and ADR 0015 on why that is intended), and a player
-- who has researched all of it runs one net positive. Everything here is at FULL SUPPLY unless it
-- says otherwise, which ADR 0016 makes a load-bearing qualifier rather than a pedantic one: a
-- player picks their own density, and at these temperatures full is not always the best pick.

-- That this ladder exists on one reactor and not on the other is asserted with every other
-- ladder's, in the resolution block below -- L.spec_ladders is what says which ladders there are.
local LADDER = SPEC.confinement_ladder
-- The plasma the load guard is asked about. It lives on the spec so that a second reactor given a
-- ladder names its own, and control.lua refuses to load a ladder that has none -- but it can only
-- refuse over a spec it can see, and this is the earlier place.
--
-- OVER EVERY SPEC THAT HAS A LADDER rather than over the neutronic one, which is the shape this
-- check should have had from the start: it read SPEC alone, so the day a second reactor was given a
-- ladder its guard fuel would have gone unchecked here -- and an unchecked one used to switch the
-- load guard off in silence rather than fail it. reactor-logic raises over that now, but this is
-- the bench that says so before a map is ever made.
for label, spec in pairs({ ["rf-reactor"] = SPEC, ["rf-aneutronic-reactor"] = ANEUTRONIC }) do
  if spec.confinement_ladder then
    check(L.fuels[spec.confinement_guard_fuel or ""] ~= nil,
      string.format("%s's ladder names a plasma the simulation can actually burn to guard it", label),
      tostring(spec.confinement_guard_fuel))
  end
end

-- Resolution. THE HIGHEST RESEARCHED RUNG WINS, not the count of them: the prerequisite chain is a
-- player-facing ordering and the console does not respect it, so a force holding level 3 alone must
-- get level 3's number rather than the base one.
local function researched(...)
  local held = {}
  for _, name in ipairs({ ... }) do held[name] = true end
  return function(name) return held[name] end
end

local TOP = LADDER[#LADDER]

-- OVER EVERY SPEC LADDER, NOT OVER THE CONFINEMENT ONE (#424). The rung walk is one function now
-- -- L.resolve_ladder, reached through the L.spec_ladders row that names each field -- so the same
-- four questions are asked of every ladder the list carries, and a ladder added there is covered
-- here without an edit. The capture ladder has its own block further down: it shares this walk and
-- deliberately not the delivery, which is the asymmetry ADR 0020 decision 5 asks for.
for _, ladder in ipairs(L.spec_ladders) do
  local rungs = SPEC[ladder.rungs]
  local field = ladder.field
  check(type(rungs) == "table" and #rungs > 0,
    string.format("the neutronic reactor has a %s", ladder.rungs))
  check(ANEUTRONIC[ladder.rungs] == nil,
    string.format("and the aneutronic reactor deliberately has no %s", ladder.rungs))
  check(type(ladder.prototypes) == "string" and ladder.prototypes ~= "",
    string.format("%s names the prototypes file a load refusal points at", ladder.rungs),
    tostring(ladder.prototypes))

  -- Strictly upward from the shipped value. A rung at or below the one before it is a technology
  -- that does nothing, or undoes something, and neither would fail anything else here. Both spec
  -- ladders climb -- confinement time and heating power alike -- so the claim is one loop.
  local previous = SPEC[field]
  for level, rung in ipairs(rungs) do
    check(rung[field] > previous,
      string.format("%s rung %d raises %s", ladder.rungs, level, field),
      string.format("%g after %g", rung[field], previous))
    check(type(rung.technology) == "string" and rung.technology ~= "",
      string.format("%s rung %d names a technology", ladder.rungs, level))
    previous = rung[field]
  end

  local top = rungs[#rungs]
  near(L.resolve_ladder(SPEC, ladder.rungs, field, researched()), SPEC[field], 0,
    string.format("a force with nothing researched runs the shipped %s", field))
  near(L.resolve_ladder(SPEC, ladder.rungs, field, researched(top.technology)), top[field], 0,
    string.format("a force holding only the top %s rung gets the top rung, not the base", ladder.rungs))
  near(L.resolve_ladder(ANEUTRONIC, ladder.rungs, field, researched(top.technology)),
    ANEUTRONIC[field], 0,
    string.format("and %s does not reach the aneutronic reactor however much is researched",
      ladder.rungs))
  near(L.resolve_ladder(SPEC, ladder.rungs, field, researched(rungs[1].technology)), rungs[1][field], 0,
    string.format("a force part way up %s gets the rung it has reached and no more", ladder.rungs))
end

-- AND THE SHORT-CIRCUIT control.lua's spec_for() MAKES, which is the whole reason a reactor with no
-- ladder allocates nothing per force -- rf-aneutronic-reactor never reaches force_specs at all.
-- Asked of the predicate rather than of one ladder's field, which is what #424 changed: spec_for
-- used to read `base.confinement_ladder` and so meant "some ladder" while saying "this one".
check(L.has_spec_ladder(SPEC), "the neutronic reactor has some ladder on its spec")
check(not L.has_spec_ladder(ANEUTRONIC),
  "the aneutronic reactor has none, so control.lua's per-force cache is never touched for it")

-- The second ladder on this reactor (#425, ADR 0038). Read from the spec rather than written out,
-- for the reason LADDER is: every figure below has to move when a rung is retuned, and a literal
-- here would leave the suite pinning a ladder the game does not ship.
local HEAT_LADDER = SPEC.heating_ladder

--- The spec at one rung of each ladder, as control.lua's derive() builds it.
--
-- LEVEL 0 IS THE SHIPPED VALUE on either axis, so at_rungs(0, 0) is a copy of SPEC itself and the
-- grid below carries the unresearched state as a cell rather than beside one. The two ladders are
-- independent (ADR 0038 decision 2), so every pair of levels is a state some force can be in.
local function at_rungs(heat_level, tau_level)
  local spec = {}
  for k, v in pairs(SPEC) do spec[k] = v end
  if tau_level > 0 then spec.confinement_time_s = LADDER[tau_level].confinement_time_s end
  if heat_level > 0 then spec.heating_power_w = HEAT_LADDER[heat_level].heating_power_w end
  return spec
end

--- The spec one confinement rung up, at the shipped heating power.
local function at_rung(level) return at_rungs(0, level) end

--- Q at one confinement rung and one fill of the input box, at the shipped heating power.
local function q_at(level, fill)
  local _, state = settle(at_rung(level), SETTLE_S, math.huge, nil, nil, FULL * (fill or 1))
  return state.q_factor
end

--- Q at one rung of each ladder and one fill, for the claims a confinement tooltip makes about
--- what a heating rung does to it.
local function q_at_heated(tau_level, heat_level, fill)
  local _, state = settle(at_rungs(heat_level, tau_level), SETTLE_S, math.huge, nil, nil,
    FULL * (fill or 1))
  return state.q_factor
end

-- THE RUNGS THEMSELVES, pinned to 1% the way #51 requires every balance figure to be. These are the
-- numbers reactor-logic's ladder note quotes and the numbers the technology descriptions describe
-- in words; a rebalance moves them here first and everything downstream is a deliberate edit.
near(q_at(1), 0.5777, 0.01, "rung 1 reaches Q 0.578 at full supply")
near(q_at(2), 0.9503, 0.01, "rung 2 reaches Q 0.950 at full supply")
near(q_at(3), 1.4675, 0.01, "rung 3 reaches Q 1.468 at full supply")

-- WHAT THE REACTOR SELLS AT EACH RUNG, IN MEGAWATTS, and why a Q is not enough on its own (#227).
--
-- The rungs above are pinned as Q, which is fusion power over heating power and says nothing about
-- what leaves the machine. What a heat exchanger has to drain is the ENERGY FLUID, and #227 sized
-- rf-heat-exchanger against these numbers: at 90 MW one machine covers the ladder to rung 2 and not
-- to rung 3, fed or full, tuned or not. They were quoted in a comment in
-- realistic-fusion-refreshed/prototypes/entities.lua and pinned nowhere, which meant a rebalance
-- could have moved the reactor out from under a machine capacity chosen to match it and no gate
-- would have said a word.
--
-- THE EXCHANGER'S OWN RATING IS DELIBERATELY NOT REPEATED HERE. It is a prototype field and this
-- file loads no prototypes, so asserting against a literal 90 would put one balance number in two
-- places with nothing keeping them in step -- the defect ADR 0031's Consequences names about the
-- mockup script's hand-copied connection table. What is pinned is the REACTOR, which is the half
-- that can drift silently; the comparison against the machine lives beside the machine.
--
-- Capture is the spec's own unresearched 0.85 here. ADR 0020's ladder multiplies all of these by
-- 0.9375/0.85 at its top rung, which is a separate lever and is not pinned twice.
local function mw_at(level, fill)
  local spec = level > 0 and at_rung(level) or SPEC
  local _, state = settle(spec, SETTLE_S, math.huge, nil, nil, FULL * (fill or 1))
  return state.energy_units * SPEC.energy_fluid_j_per_unit / TICK / 1e6
end

near(mw_at(0), 56.1, 0.01, "unresearched, a full D-D reactor sells 56.1 MW", "MW")
near(mw_at(1), 67.1, 0.01, "rung 1 sells 67.1 MW at full supply", "MW")
near(mw_at(2), 82.9, 0.01, "rung 2 sells 82.9 MW at full supply", "MW")
near(mw_at(3), 104.9, 0.01, "rung 3 sells 104.9 MW at full supply", "MW")

-- AND AT THE DENSITY OPTIMUM, which is the higher of the two and therefore the one a capacity has to
-- clear. ADR 0016 makes tuning density a player lever and ADR 0024 tabulates where the optimum sits
-- -- about 65% full unresearched, 75% at rung 1, 85% at rung 2 -- and a reactor run there sells more
-- than the same reactor run full. Rung 2's is the tight one against #227's 90 MW, clearing it by
-- barely a megawatt, so it is the figure most worth pinning: a 2% drift up falsifies the claim in
-- realistic-fusion-refreshed/prototypes/entities.lua that one exchanger drains a rung-2 reactor.
near(mw_at(0, 0.65), 61.6, 0.02, "unresearched, its density optimum sells 61.6 MW", "MW")
near(mw_at(1, 0.75), 73.7, 0.02, "rung 1's density optimum sells 73.7 MW", "MW")
near(mw_at(2, 0.85), 88.8, 0.02, "rung 2's density optimum sells 88.8 MW -- the tight one", "MW")
check(mw_at(2, 0.85) > mw_at(2) and mw_at(3) > mw_at(2, 0.85),
  "the optimum is above full supply at a rung, and below the NEXT rung run full",
  string.format("rung 2: %.1f full, %.1f tuned; rung 3 full %.1f",
    mw_at(2), mw_at(2, 0.85), mw_at(3)))

-- THE PROGRESSION THE TICKET ASKS FOR, stated as the claim rather than as three numbers: below
-- break-even unresearched, above it with the ladder done, and no rung wasted in between.
check(hot_state.q_factor < 1 and q_at(1) < 1,
  "an unresearched D-D reactor is below break-even, and one rung does not fix it",
  string.format("Q %.3f unresearched, %.3f at rung 1", hot_state.q_factor, q_at(1)))
check(q_at(#LADDER) > 1,
  "researching the whole ladder takes it net positive",
  string.format("Q %.3f", q_at(#LADDER)))

-- WHAT EACH TECHNOLOGY'S DESCRIPTION CLAIMS, asserted here because the strings are prose and prose
-- cannot be derived from the constants the way the seconds are -- prototypes/technology/
-- confinement.lua records why no Q is quoted in game. If a rebalance falsifies one of these, this
-- is what says so before a player does.
--
-- Rung 2 is the interesting one and its whole tooltip turns on it: full supply misses break-even
-- and about 85% full clears it. That fill is ADR 0016's own figure for the optimum at this
-- confinement time, quoted so the tooltip, the ADR and the model all say one thing.
check(q_at(2) < 1 and q_at(2, 0.85) > 1,
  "rung 2's tooltip is true: full falls short, 85% full crosses break-even",
  string.format("Q %.3f full, %.3f at 85%%", q_at(2), q_at(2, 0.85)))

-- Rung 3 says a full reactor is finally net positive and that tuning is worth little now. Both
-- halves, because "worth little" is the half that would quietly stop being true.
local unresearched_gain = select(2,
  settle(SPEC, SETTLE_S, math.huge, nil, nil, FULL * 0.65)).q_factor / hot_state.q_factor - 1
local top_gain = q_at(3, 0.9) / q_at(3) - 1
check(q_at(3) > 1, "rung 3's tooltip is true: a FULL reactor is net positive",
  string.format("Q %.3f", q_at(3)))
check(top_gain < 0.10 and unresearched_gain > 0.30,
  "and tuning the supply is worth under 10% there, against over 30% unresearched",
  string.format("%.1f%% at rung 3, %.1f%% unresearched", top_gain * 100, unresearched_gain * 100))

-- AND THE QUALIFIER BOTH OF THOSE STRINGS GAINED (#425, found in review). Every claim in the two
-- blocks above is measured at BASE HEATING, and each string used to state it unqualified -- which
-- was complete while there was one ladder and became a tooltip sending a player to solve a problem
-- they no longer have. Each now says "on base heating" and says what one heating rung does to it;
-- these are those two sentences.
--
-- Rung 2: full supply misses break-even on base heating and clears it with one heating rung, so
-- the density choice the string is about is settled for the player rather than posed to them.
near(q_at_heated(2, 1, 1), 1.1263, 0.01,
  "rung 2 with one heating rung clears break-even held FULL, which its tooltip now says")
check(q_at(2) < 1 and q_at_heated(2, 1, 1) > 1,
  "so the string's 'on base heating' is load-bearing rather than tidy",
  string.format("Q %.4f at base heating, %.4f with one rung", q_at(2), q_at_heated(2, 1, 1)))

-- Rung 3: "the four per cent left here" is base heating too, and one heating rung leaves nothing
-- at all -- the curve block below measures the optimum going to full supply there. Asserted here
-- as the GAIN rather than as the optimum, because the gain is what the string quotes.
near(top_gain, 0.043, 0.02, "the four per cent the string quotes is 4.3% on base heating")
check(q_at_heated(3, 1, 0.9) < q_at_heated(3, 1, 1),
  "and one heating rung leaves full supply simply best, which is the clause it gained",
  string.format("Q %.4f at 90%% against %.4f full -- tuning down COSTS %.1f%%",
    q_at_heated(3, 1, 0.9), q_at_heated(3, 1, 1),
    (1 - q_at_heated(3, 1, 0.9) / q_at_heated(3, 1, 1)) * 100))

-- -------------------------------------------- the heating ladder's own claims (#425, ADR 0038)
--
-- The same job the block above does for the confinement rungs: prototypes/technology/heating.lua
-- quotes the megawatts from the ladder and cannot drift, and its PROSE cannot be derived from
-- anything, so what the prose claims is pinned here.

--- What a D-D reactor sells and what it costs, at one heating rung and entry confinement.
local function heating_rung(level, fill)
  local spec = at_rungs(level, 0)
  local _, state = settle(spec, SETTLE_S, math.huge, nil, nil, FULL * (fill or 1))
  return {
    mw = state.energy_units * SPEC.energy_fluid_j_per_unit / TICK / 1e6,
    q  = state.q_factor,
    heating_mw = spec.heating_power_w / 1e6,
  }
end

-- THE TOP RUNG'S TOOLTIP, which is the one that makes a claim about money: "About 81 MW for the
-- line against 56 unresearched, and a reactor selling 102.9 MW into it -- where unresearched it
-- barely covered its own line at all."
--
-- THE COMPARISON IS AGAINST THE LINE AND NOT AGAINST THE REACTOR'S OWN HEATING, and getting that
-- wrong is a defect this block caught in review. The first draft of that string said the reactor
-- "turns a real profit at last, selling 102.9 MW against the 75 MW it burns" -- and a D-D reactor
-- sells more than it burns at EVERY rung, unresearched included (1.122x at 50 MW, rising to
-- 1.371x at 75), which is ADR 0015's engineering break-even and has nothing to do with this
-- ladder. Against the whole LINE the sentence is true and is worth saying: 1.002x unresearched,
-- which is barely covering it, against 1.270x at the top rung.
local TOP_HEAT = heating_rung(#HEAT_LADDER)
near(TOP_HEAT.mw, 102.9, 0.01, "at the top heating rung a full D-D reactor sells 102.9 MW", "MW")
near(TOP_HEAT.heating_mw, 75, 0, "against the 75 MW it burns", "MW")

-- AND THE HALF THE SAME SENTENCE REFUSES TO OVERSTATE: profitable is not break-even. ADR 0015's
-- letter holds at every rung -- Q(D-D) never reaches 1 at any heating power, peaking at 0.968 near
-- 180 MW, which is far past anything this ladder reaches. Asserted over the ladder here; the peak
-- itself is ADR 0038's measurement and is not re-swept at every suite run.
for h = 0, #HEAT_LADDER do
  local rung = heating_rung(h)
  check(rung.q < 1,
    string.format("heating rung %d leaves D-D below scientific break-even at entry confinement", h),
    string.format("Q %.4f", rung.q))
end
near(heating_rung(#HEAT_LADDER).q, 0.6135, 0.01,
  "and the top rung reaches Q 0.613, which is ADR 0038's figure")

-- THE MIDDLE RUNG'S TOOLTIP is a claim about the supply ratio and not about one reactor, so it is
-- asserted where the ratio grid is built rather than here. See "the middle heating rung's tooltip"
-- in the fuel-chain section below.

-- WHAT THE LINE DRAWS, which is the figure every heating tooltip states and the one ADR 0038 makes
-- mandatory. ADR 0015's line table is 50 MW of confinement heating plus about 6 MW of heater,
-- electrolysers, extractor and chemical plant; none of that second part moves, so each rung's line
-- figure is its own heating plus the same ~6 MW. The literals in locale/en/heating.cfg are checked
-- against the ladder rather than against the model, because this suite loads no recipes and cannot
-- see the ~6 MW at all -- what it CAN say is that the six published figures are one arithmetic
-- series over the shipped rungs, which is the way they would drift.
local LINE_MW = { 56, 61, 66, 71, 76, 81 }
local LINE_AUXILIARY_MW = LINE_MW[1] - SPEC.heating_power_w / 1e6
check(#LINE_MW == #HEAT_LADDER + 1,
  "locale/en/heating.cfg publishes a line figure for the shipped state and one per rung",
  string.format("%d figures against %d rungs", #LINE_MW, #HEAT_LADDER))
for i, want in ipairs(LINE_MW) do
  local heating = (i == 1) and SPEC.heating_power_w or HEAT_LADDER[i - 1].heating_power_w
  near(want, heating / 1e6 + LINE_AUXILIARY_MW, 0.01,
    string.format("the published %d MW line figure is this rung's heating plus the same auxiliaries",
      want))
end
near(LINE_MW[#LINE_MW] / LINE_MW[1], 1.446, 0.01,
  "and the ladder raises a D-D line's whole draw by 45%, which every rung's tooltip warns about")

-- AND WHAT THE REACTOR SELLS AGAINST THAT LINE, which is the comparison the top rung's tooltip
-- makes and the one the reactor-against-its-own-heating reading is so easily confused with. The
-- ratio a player cares about is what one reactor returns against what its whole line costs: 1.002
-- unresearched, which is barely covering it, and 1.270 at the top rung.
near(heating_rung(0).mw / LINE_MW[1], 1.002, 0.01,
  "unresearched, a D-D reactor barely covers its own line")
near(TOP_HEAT.mw / LINE_MW[#LINE_MW], 1.270, 0.01,
  "and at the top heating rung it covers it by 27%")
-- Monotone across the ladder, which is what makes the line worth climbing at all: every rung adds
-- 5 MW of draw and more than 5 MW of sale.
for i = 2, #LINE_MW do
  check(heating_rung(i - 1).mw / LINE_MW[i] > heating_rung(i - 2).mw / LINE_MW[i - 1],
    string.format("heating rung %d pays for more of its own line than the rung below", i - 1),
    string.format("%.4f against %.4f",
      heating_rung(i - 1).mw / LINE_MW[i], heating_rung(i - 2).mw / LINE_MW[i - 1]))
end

-- ------------------------------------------------- the fuel chain, at the settled point (#117)
--
-- HOW MANY D-D REACTORS FEED ONE D-T REACTOR. Here rather than in a paragraph because
-- docs/research/d-t-ignition.md quoted this ratio from an arithmetic comment for a month after the
-- numerator moved under it, and #117 asked for a figure a rig produces instead.
--
-- BOTH TIERS AT ONE OPERATING POINT, which was #117's first requirement and is Truls's decision:
-- SETTLED -- box full, all the power the reactor asks for. CONTEXT.md names it the reference point
-- and pins the D-D end of it; the note used to compare a heater-fed D-T reactor against a settled
-- D-D one, which are not the same kind of number.
--
-- The chain is two lines of stoichiometry and nothing else. Half a D-T plasma unit is tritium
-- (`fractions`), and a quarter of the deuterium a D-D reactor burns comes back as tritium -- the
-- by-products block above pins that quarter against `plasma_consumed`. So the ratio is what one
-- reactor needs over what the other leaves behind.
--
-- IT MOVES WITH THE LADDER, AND BOTH TIERS MOVE. The ladder sits on the reactor rather than on a
-- tier (reactor-logic's confinement_ladder note), so research speeds the breeder up and slows the
-- burner down at once -- D-T settles hotter, past the peak of its own cross-section, and burns
-- less. That is why one number cannot answer the question and why the two ends are pinned
-- separately rather than a rate of change being asserted.
local T_FRACTION = L.fuels["rf-d-t-plasma"].fractions[2]

-- THE OTHER READING'S DENOMINATOR (#290). Read from M.heater rather than written as 2.5: all four
-- rf-plasma-heating recipes take their energy_required and amounts from it and rf-heater takes its
-- crafting_speed, so a retune moves the pinned figures below instead of silently falsifying them.
local HEATER_RATE = L.heater_plasma_rate()
near(HEATER_RATE, 2.5, 1e-9, "one rf-heater makes 2.5 units of plasma a second")

-- Tritium one heater on rf-d-t-mix supplies, which is the consumer the per-heater reading is about.
--
-- ONE ASSUMPTION HERE IS NOT PINNED AND SAYS SO: that the MIX a heater eats has the same composition
-- as the PLASMA it makes. `fractions` describes the plasma; what a heater draws from the tritium line
-- is set by Core's rf-d-t-mixing (50 + 50 into 100) and by the plasma recipe being one-for-one. Those
-- agree today, and they have to agree for the model to be coherent at all -- a 25/75 mix burnt as a
-- 50/50 plasma would be step() disagreeing with the pipe about what is in the box, which is the
-- same fault `fractions` was added to fix (#28). Nothing in the tree ENFORCES it: Core's recipes are
-- prototypes and this suite runs outside Factorio, so it cannot read them. Retune a mixing recipe
-- without retuning `fractions` and the figures below stay at 9.12 while a player's chain moves.
-- Found in review of the commit that added this block.
local HEATER_TRITIUM = HEATER_RATE * T_FRACTION

--- Both ends of the chain at one confinement time.
--
-- BOTH ENDS AT SETTLE_S, and the D-T end especially. The D-T block above settles that tier for one
-- minute, which is what the note's own table quotes and is NOT converged: 3.248e9 C at a minute
-- against 3.265e9 C settled, and 26.03 u/s of plasma against 25.95. The gap is small and it is a
-- different operating point, so the chain is measured at the same horizon the D-D end has always
-- been measured at rather than at whichever one each tier happened to be quoted at.
local function chain(spec)
  local _, dt = settle(spec, SETTLE_S, math.huge, nil, "rf-d-t-plasma")
  local _, dd = settle(spec, SETTLE_S, math.huge, nil, "rf-d-d-plasma")
  local needed = dt.plasma_consumed / TICK * T_FRACTION
  local bred   = dd.products["rf-tritium"] / TICK
  local ratio  = needed / bred
  local sold_w = (dt.energy_units + dd.energy_units * ratio) / TICK * spec.energy_fluid_j_per_unit
  return {
    needed = needed, bred = bred, ratio = ratio,
    -- The same quantity per heater instead of per saturated reactor, and the count that relates
    -- them. Only the breeder end moves with the ladder here: a heater makes the same plasma
    -- whatever a force has researched.
    per_heater = HEATER_TRITIUM / bred,
    heaters    = needed / HEATER_TRITIUM,
    -- What the whole chain sells, per reactor in it -- the figure the note quotes as the tier's
    -- step, and the one that says the step is per-reactor rather than per-plant.
    per_reactor_w = sold_w / (1 + ratio),
  }
end

-- ONE MEASUREMENT PER CELL OF THE GRID, the unresearched state first on both axes. Each cell is
-- settled once and every assertion below reads this table, which is what keeps the suite's cost
-- down: a settled D-D reactor is 72 000 steps and there is no reason to pay for one twice.
--
-- A GRID RATHER THAN A ROW SINCE #425. There are two independent ladders on this reactor now
-- (ADR 0038 decision 2), so a force can be at any pair of rungs and the supply ratio has 24
-- readings rather than 4. The row this used to be is GRID[0] -- base heating, the whole confinement
-- ladder -- and every figure it pinned is unchanged, which is the ADR's decision 3 arriving as an
-- assertion rather than as a promise.
--
-- [heating level][confinement level], 0 meaning the shipped value on that axis.
local GRID = {}
for h = 0, #HEAT_LADDER do
  GRID[h] = {}
  for t = 0, #LADDER do GRID[h][t] = chain(at_rungs(h, t)) end
end

local RUNGS  = GRID[0]
local BARE   = GRID[0][0]
local TOPPED = GRID[#HEAT_LADDER][#LADDER]
-- The top of the confinement ladder alone, which is what "researched" meant before #425 and is
-- still a legitimate build a player stops at.
local TOP_TAU_ONLY = GRID[0][#LADDER]

-- EVERY CELL OF THE NOTE'S TABLE, not only the two ends. The first version of this block pinned
-- rung 0 and rung 3 and asserted the rungs between only to fall, which left six published cells
-- computed nowhere -- a rebalance could move the 40 s or 50 s row and the suite would still say
-- "0 failures". That is the same drift #117 was opened about, one table down, so the table is
-- pinned row by row. Found in review of the commit that added this block.
--
-- The rows are d-t-ignition.md's, in its order: tritium bred, tritium needed, D-D reactors per
-- D-T reactor, and megawatts per reactor across the whole chain.
--
-- SINCE #290 IT ALSO PINS THE OTHER READING OF THE SAME QUANTITY, per rung. `ratio` is the SUPPLY
-- RATIO per saturated reactor -- what a settled D-T reactor burns -- and `per_heater` is what one
-- rf-heater's worth costs, which is the reading a player meets because a heater is what they build.
-- `heaters` is what relates them. CONTEXT.md defines all three under **supply ratio**; the note
-- publishes all three; this table is where they are measured.
--
-- AND SINCE #425 IT IS ONE ROW OF A GRID RATHER THAN THE WHOLE STATEMENT. Every figure in it is
-- measured at BASE HEATING -- the row ADR 0038's own grid heads with "(shipped)" -- and every one
-- is unchanged by that ADR, because the heating ladder starts where the reactor already was. The
-- other five rows are pinned as ratios by RATIO_GRID below; the four extra columns here are not
-- republished per heating rung, because d-t-ignition.md publishes the grid as ratios alone.
local PUBLISHED = {
  { tau = 30, bred = 0.137012, needed = 12.9747, ratio = 94.6969, mw = 88.457,  per_heater = 9.1233, heaters = 10.3798 },
  { tau = 40, bred = 0.246974, needed = 12.3144, ratio = 49.8611, mw = 124.569, per_heater = 5.0613, heaters = 9.8515 },
  { tau = 50, bred = 0.406267, needed = 11.8952, ratio = 29.2794, mw = 175.662, per_heater = 3.0768, heaters = 9.5162 },
  { tau = 60, bred = 0.627339, needed = 11.6077, ratio = 18.5032, mw = 244.242, per_heater = 1.9926, heaters = 9.2862 },
}
check(#PUBLISHED == #LADDER + 1,
  "the published table has a row for the shipped value and one for every rung of the ladder",
  string.format("%d rows against %d rungs", #PUBLISHED, #LADDER))
for i, want in ipairs(PUBLISHED) do
  -- i - 1 because RUNGS is indexed by LEVEL, and level 0 is the unresearched state.
  local got = RUNGS[i - 1]
  near(got.bred, want.bred, 0.01,
    string.format("at %d s a D-D reactor breeds %.4g u/s of tritium", want.tau, want.bred))
  near(got.needed, want.needed, 0.01,
    string.format("at %d s a D-T reactor burns %.4g u/s of tritium", want.tau, want.needed))
  near(got.ratio, want.ratio, 0.01,
    string.format("at %d s it takes %.4g D-D reactors to feed one", want.tau, want.ratio))
  near(got.per_reactor_w / 1e6, want.mw, 0.01,
    string.format("at %d s the chain sells %.4g MW per reactor in it", want.tau, want.mw))
  near(got.per_heater, want.per_heater, 0.01,
    string.format("at %d s one heater on the D-T mix costs %.4g D-D reactors", want.tau, want.per_heater))
  near(got.heaters, want.heaters, 0.01,
    string.format("at %d s a settled D-T reactor eats %.4g heaters", want.tau, want.heaters))
  -- THE THREE PUBLISHED FIGURES MULTIPLYING OUT, against each other rather than against the model.
  -- Asserting it on `got` would be an identity and not a check -- per_heater is
  -- HEATER_TRITIUM/bred and heaters is needed/HEATER_TRITIUM, so their product is needed/bred,
  -- which is how ratio is computed in chain() and no retune could break it. This version has
  -- something to say: the three literals on this row are transcribed into the note as three
  -- separate figures, and a row whose columns no longer multiply out is exactly the drift a reader
  -- would otherwise have to catch by hand. Found in review of the commit that added this block.
  near(want.per_heater * want.heaters, want.ratio, 0.01,
    string.format("at %d s the published per-heater figure times the published heater count is the published ratio", want.tau))
end

-- ------------------------------------ the whole grid, at every research state (#425, ADR 0038)
--
-- EVERY CELL A FORCE CAN BE IN, and there are twenty-four of them because the two ladders are
-- independent. ADR 0038 decision 2 is what makes the grid rectangular rather than a path: neither
-- line is a prerequisite of the other, so a player may hold five heating rungs at entry
-- confinement, and that corner has to be a measured figure like every other.
--
-- WHY IT IS PINNED CELL BY CELL, which is the same argument the row above makes and one rung
-- stronger. docs/research/d-t-ignition.md publishes all twenty-four and ADR 0038 argues from them;
-- a version of this that pinned the two corners and asserted only that the interior fell would
-- leave twenty-two published figures computed nowhere.
--
-- ROWS ARE HEATING, COLUMNS ARE CONFINEMENT, in ADR 0038's own order. The first row is PUBLISHED's
-- ratio column, repeated here rather than derived from it: the two tables are read side by side by
-- anyone checking the note, and a row that has silently stopped agreeing with the table above it is
-- exactly what a reader cannot see.
local RATIO_GRID = {
  { heat = 50, 94.6969, 49.8611, 29.2794, 18.5032 },
  { heat = 55, 71.7289, 37.7457, 22.4073, 14.6994 },
  { heat = 60, 56.4655, 29.9051, 18.1325, 12.3848 },
  { heat = 65, 45.8742, 24.5885, 15.3078, 10.8469 },
  { heat = 70, 38.2695, 20.8354, 13.3389,  9.7503 },
  { heat = 75, 32.6281, 18.0905, 11.8979,  8.9269 },
}
check(#RATIO_GRID == #HEAT_LADDER + 1,
  "the published grid has a row for the shipped heating power and one for every heating rung",
  string.format("%d rows against %d rungs", #RATIO_GRID, #HEAT_LADDER))
for h, row in ipairs(RATIO_GRID) do
  check(#row == #LADDER + 1,
    string.format("the %d MW row has a cell for the shipped confinement time and one per rung", row.heat),
    string.format("%d cells against %d rungs", #row, #LADDER))
  -- The row's own label against the ladder it claims to be a row of, so a rung retuned in
  -- reactor-logic cannot leave this table pinning the right ratio under the wrong megawatts.
  local heat_w = (h == 1) and SPEC.heating_power_w or HEAT_LADDER[h - 1].heating_power_w
  near(row.heat, heat_w / 1e6, 0,
    string.format("the %d MW row is labelled with the heating power it was measured at", row.heat))
  for t, want in ipairs(row) do
    near(GRID[h - 1][t - 1].ratio, want, 0.01,
      string.format("at %d MW and %d s it takes %.4g D-D reactors to feed one",
        row.heat, PUBLISHED[t].tau, want))
  end
end

-- MONOTONE ON BOTH AXES, which is a claim the cells above cannot make on their own: every rung of
-- either ladder makes the chain shorter, whatever the other ladder is at, so there is no rung a
-- player reaches and finds the plumbing got worse. Asserted rather than argued because nothing
-- else here would notice if a rung inverted it, and because it has to keep holding when the rungs
-- are retuned.
--
-- ON THE CONFINEMENT AXIS BOTH ENDS PULL THE SAME WAY, which is why it holds: the breeder breeds
-- more (0.137 to 0.627 u/s at base heating) and the burner needs less (12.97 to 11.61), because
-- D-T settles past the peak of its own cross-section and fuses slower there.
--
-- ON THE HEATING AXIS THEY DO NOT, and that is worth knowing before reading the figures as the same
-- effect twice. More heating makes the burner need LESS too (12.97 to 12.84 at 30 s), but barely;
-- essentially all of the fall is the breeder, which goes 0.137 to 0.393 u/s. ADR 0038 measured
-- that the ratio falls with heating power monotonically and turns over nowhere, and this is where
-- the claim is kept honest.
for h = 0, #HEAT_LADDER do
  for t = 1, #LADDER do
    check(GRID[h][t].ratio < GRID[h][t - 1].ratio,
      string.format("at heating level %d, confinement rung %d shortens the fuel chain", h, t),
      string.format("%.4g D-D per D-T after %.4g", GRID[h][t].ratio, GRID[h][t - 1].ratio))
  end
end
for t = 0, #LADDER do
  for h = 1, #HEAT_LADDER do
    check(GRID[h][t].ratio < GRID[h - 1][t].ratio,
      string.format("at confinement level %d, heating rung %d shortens the fuel chain", t, h),
      string.format("%.4g D-D per D-T after %.4g", GRID[h][t].ratio, GRID[h - 1][t].ratio))
  end
end

-- THE MIDDLE HEATING RUNG'S TOOLTIP, and the qualifier in it is load-bearing. It claims that "at
-- the confinement time you start with, three rungs have more than halved the number of breeder
-- reactors one fusion plant needs", and that the rungs are worth less further up the other ladder.
-- The first draft of that string said "under half the D-D reactors it needed unresearched" with no
-- qualifier at all, and this loop is what caught it: the halving holds at entry confinement and at
-- the first rung, and FAILS at the two above -- 15.31 against half of 29.28, and 10.85 against half
-- of 18.50. The claim was narrowed to what the grid supports rather than the assertion widened.
check(GRID[3][0].ratio < 0.5 * GRID[0][0].ratio,
  "at entry confinement, heating rung 3 more than halves the fuel chain",
  string.format("%.4g against %.4g", GRID[3][0].ratio, GRID[0][0].ratio))
-- The second half of the same sentence: the rungs are worth less the further up the confinement
-- ladder they are taken. Asserted as the fraction remaining, which rises across the row.
for t = 1, #LADDER do
  check(GRID[3][t].ratio / GRID[0][t].ratio > GRID[3][t - 1].ratio / GRID[0][t - 1].ratio,
    string.format("and heating rung 3 is worth less at confinement level %d than at %d", t, t - 1),
    string.format("%.3f of the chain left against %.3f",
      GRID[3][t].ratio / GRID[0][t].ratio, GRID[3][t - 1].ratio / GRID[0][t - 1].ratio))
end

-- THE TARGET ADR 0038 SET, AND THE CEILING #294 WILL GATE. The stated target is about 9 settled
-- D-D reactors per saturated D-T reactor at the fully-researched state; the ceiling is 15. Pinned
-- here so #294 gates a figure this suite already measures rather than one it re-derives.
near(TOPPED.ratio, 8.9269, 0.01,
  "at the top of both ladders it takes 8.93 D-D reactors to feed one")
check(TOPPED.ratio < 15,
  "which is inside the ceiling ADR 0038 names for the fully-researched state",
  string.format("%.4g against 15", TOPPED.ratio))

-- AND THE OTHER READING OF IT, which is the one CONTEXT.md publishes because a heater is what a
-- player builds. 9.1233 unresearched is pinned in the table above; this is its far corner.
near(TOPPED.per_heater, 0.9726, 0.01,
  "and one heater on the D-T mix costs 0.973 of a D-D reactor there -- under one")
near(TOPPED.heaters, 9.1780, 0.01,
  "while a settled D-T reactor eats 9.18 heaters there, against 10.4 unresearched")

-- WHAT A REACTOR BREEDS AT THE FAR CORNER, which is a rate rather than a ratio and is pinned for a
-- reader rather than for the grid: realistic-fusion-refreshed/prototypes/entities.lua sizes
-- rf-isotope-collector's boxes against it, and the sentence there quotes all three of these.
near(BARE.bred, 0.137012, 0.01, "unresearched, a D-D reactor breeds 0.137 u/s of tritium")
near(TOP_TAU_ONLY.bred, 0.627339, 0.01, "at the top of the confinement ladder alone, 0.627 u/s")
near(TOPPED.bred, 1.285164, 0.01, "and at the top of both ladders, 1.285 u/s")

-- INTERMEDIATE STATES ARE DELIBERATELY UNGATED, and this is the cell that says why: a player who
-- finishes the confinement ladder and researches no heating sits at 18.5, which is a legitimate
-- build and is over the ceiling. #294 gates the fully-researched state alone.
check(TOP_TAU_ONLY.ratio > 15,
  "top-confinement-only is over the ceiling, which is why #294 gates the fully-researched state",
  string.format("%.4g against 15", TOP_TAU_ONLY.ratio))

-- AND THE BLANKET IS THE OTHER ROUTE ENTIRELY, not a discount on this one (#30, ADR 0019). The
-- breeding block above proves a blanketed D-T reactor breeds back more tritium than it burns, so
-- the ratio this section measures is the cost of the UNBLANKETED chain -- the one a player is on
-- before rf-blanket-breeding. Stated here as well because the two numbers are read together and
-- the note quotes them in one breath.
check(BARE.ratio > 1 and TOPPED.ratio > 1,
  "the unblanketed chain always costs more than one D-D reactor per D-T reactor",
  string.format("%.4g unresearched, %.4g researched", BARE.ratio, TOPPED.ratio))

-- ------------------------------------- the supply ratio, on the aneutronic tier too (#290)
--
-- THE SAME MEASUREMENT AS THE `per_heater` COLUMN ABOVE, FOR HELIUM-3 INSTEAD OF TRITIUM, and it is
-- here because realistic-fusion-refreshed/prototypes/entities.lua arrived at the same 9:1 while
-- sizing the composite tank, in
-- a different vocabulary, with nothing joining the two statements up. They are one quantity.
--
-- A D-D reactor breeds helium-3 and tritium at the same rate -- half a nucleus of each per reaction,
-- which the by-products block above pins -- so the denominator is BARE.bred here too, and the
-- numerator differs only in what share of a plasma unit is the bred isotope. That share is read off
-- `fractions` rather than written down: 0.5 for the two 50/50 mixes, 1 for He3-He3, which burns a
-- bare Core fluid and has no second species to blend in. The unpinned mix assumption noted at
-- HEATER_TRITIUM applies to rf-d-he3-mixing in the same way.
--
-- NO BALANCE CHANGE IS DECIDED HERE, and #290 says so in as many words. Whether 9.1 is acceptable
-- is #292's question; this block exists so that #292 argues about one figure.
local function per_heater(plasma)
  return HEATER_RATE * L.fuels[plasma].fractions[2] / BARE.bred
end

near(per_heater("rf-d-he3-plasma"), BARE.per_heater, 1e-9,
  "per heater, the D-He3 mix costs exactly what the D-T mix costs -- one measurement, two tiers")
near(per_heater("rf-he3-he3-plasma"), 2 * per_heater("rf-d-he3-plasma"), 1e-9,
  "and a heater on bare helium-3 costs twice that, having no second species to blend in")
near(per_heater("rf-d-he3-plasma"), 9.1233, 0.01,
  "so nine settled D-D reactors feed one heater on the mix")
near(per_heater("rf-he3-he3-plasma"), 18.2466, 0.01,
  "and eighteen feed one on bare helium-3")

-- THE PER-SATURATED-REACTOR READING EXISTS ON THIS TIER TOO and is deliberately NOT pinned: what a
-- settled rf-aneutronic-reactor burns is a measurement this file does not take, and inventing one
-- to fill the symmetry would put a figure on the record that nothing measured. Every aneutronic
-- figure above is per heater and says so.

-- ------------------------------------------------------------------------------- the guard (#53)
--
-- control.lua's check_confinement_ladder refuses to load a ladder whose top rung settles D-D
-- against max_temperature_c, where the reactor inherits the pinned temperature reading the D-T tier
-- already has and further research stops doing anything a player can see. The DECISION is
-- reactor-logic's so that it can be broken here; control.lua supplies only the operating point and
-- the message.
--
-- Stepped at the game's own cadence rather than at a tick, which is what GUARD_DT reproduces: it is
-- control.lua's UPDATE_INTERVAL of six ticks. A coarser step settles hotter, which is the safe
-- direction for a guard and the wrong one for a published figure.
local GUARD_DT = 6 / 60

check(L.ladders_overrun(SPEC, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT) == nil,
  "the shipped ladder does not reach the clamp",
  string.format("top rung %g s settles at %.4g C, clamp %.4g C", TOP.confinement_time_s,
    settle(at_rung(#LADDER), SETTLE_S, math.huge, GUARD_DT), SPEC.max_temperature_c))

-- BREAKING IT, which is the half that makes the line above mean anything.
--
-- IT IS BROKEN BY LOWERING THE CEILING SINCE #58, NOT BY RAISING THE RUNG, and the reason is the
-- point rather than the technique. ~~A fourth rung at 200 s is past the crossing -- D-D reaches the
-- clamp somewhere near 175 s in this model.~~ That was true against a 2e9 ceiling. Against 5e9 no
-- rung reaches it at all: a full D-D box climbs with confinement but converges far under the clamp
-- -- 2.13e9 at 200 s, 2.64e9 at 600 s, and still only 2.90e9 at 20 000 s, which is a rung nobody
-- would write. The guard cannot be tripped by any ladder a person would write. (Converges: it is
-- not flat by 600 s, so do not read that figure as a limit.)
--
-- So the overrunning case is built the other way round -- the same 200 s rung against the ceiling
-- this reactor used to have -- which still exercises exactly what the guard decides: whether the
-- top rung pins the plasma against ITS OWN spec's clamp. What changed is the clamp, not the shape
-- of the question, and a guard that can no longer fire on shipped values still has to be known to
-- work.
local OVERRUN = {}
for k, v in pairs(SPEC) do OVERRUN[k] = v end
OVERRUN.max_temperature_c = 2e9
OVERRUN.confinement_ladder = {}
for _, rung in ipairs(LADDER) do
  OVERRUN.confinement_ladder[#OVERRUN.confinement_ladder + 1] = rung
end
OVERRUN.confinement_ladder[#OVERRUN.confinement_ladder + 1] =
  { technology = "rf-plasma-confinement-4", confinement_time_s = 200 }

local overrun_at = L.ladders_overrun(OVERRUN, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT)
check(overrun_at ~= nil, "a ladder that pins its own spec's clamp is caught",
  overrun_at and string.format("%.6g C", overrun_at) or "NOT CAUGHT")
-- `or 0` follows this file's rule that a nil is a failure and not an error: H.near would throw on
-- one, and a broken guard should fail the two checks it breaks rather than take the suite down and
-- hide everything after it.
near(overrun_at or 0, OVERRUN.max_temperature_c, 0,
  "and what it reports is the clamp itself, which is the reading a player would be stuck with")

-- A spec with no ladder at all is not an overrun, it is nothing to check. The aneutronic reactor is
-- exactly that case and passes through control.lua's loop untouched.
check(L.ladders_overrun(ANEUTRONIC, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT) == nil,
  "a reactor with no ladder has nothing to overrun")

-- AND IT READS EVERY SPEC LADDER, NOT THE CONFINEMENT ONE (#425, found in review). This guard took
-- the top confinement rung and left every other field shipped, which was sufficient while there
-- was one ladder and silently insufficient the moment there were two: the ladders are independent,
-- so a force can hold the top of both, and heating power raises the settled temperature as well.
--
-- THE CONFINEMENT LADDER IS LEFT SHIPPED IN THIS SPEC, which is what makes the check about the
-- heating axis alone. Against the old one-axis guard this spec is safe -- 6.483e8 C at the top
-- confinement rung and base heating, nowhere near a 2e9 clamp -- so the only thing that can catch
-- it is the guard reading the heating ladder's top rung.
local HEAT_OVERRUN = {}
for k, v in pairs(SPEC) do HEAT_OVERRUN[k] = v end
HEAT_OVERRUN.max_temperature_c = 2e9
HEAT_OVERRUN.heating_ladder = {}
for _, rung in ipairs(HEAT_LADDER) do
  HEAT_OVERRUN.heating_ladder[#HEAT_OVERRUN.heating_ladder + 1] = rung
end
HEAT_OVERRUN.heating_ladder[#HEAT_OVERRUN.heating_ladder + 1] =
  { technology = "rf-plasma-heating-6", heating_power_w = 2000e6 }

-- The control, and it is what makes the line after it mean anything: with the heating ladder left
-- exactly as it ships, this same spec and clamp are safe. So the catch below is the added rung and
-- not the lowered ceiling.
local HEAT_SAFE = {}
for k, v in pairs(SPEC) do HEAT_SAFE[k] = v end
HEAT_SAFE.max_temperature_c = 2e9
check(L.ladders_overrun(HEAT_SAFE, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT) == nil,
  "the shipped heating ladder does not pin a 2e9 clamp, so the next line is about the added rung",
  string.format("%.6g C at the top of both shipped ladders",
    settle(at_rungs(#HEAT_LADDER, #LADDER), SETTLE_S, math.huge, GUARD_DT)))

local heat_overrun_at =
  L.ladders_overrun(HEAT_OVERRUN, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT)
check(heat_overrun_at ~= nil,
  "a HEATING rung that pins the clamp is caught, on a spec whose confinement ladder is untouched",
  heat_overrun_at and string.format("%.6g C", heat_overrun_at) or "NOT CAUGHT")
near(heat_overrun_at or 0, HEAT_OVERRUN.max_temperature_c, 0,
  "and it reports the clamp, the same reading the confinement half does")

-- AND THE WAY THE GUARD USED TO LIE, which is worth a test of its own because it made every line
-- above meaningless without failing any of them. Asked about a plasma with no fuel row, step()
-- returns nil, settle() breaks on the first one, and the settled temperature comes back at the seed
-- -- so the old code compared min_temperature_c against the clamp and answered "safe" having
-- simulated nothing. One character wrong in confinement_guard_fuel switched the invariant off.
--
-- The SAME overrunning ladder is used for both halves deliberately: it is caught above with the
-- fuel named correctly, so if this half stopped raising, the pair would disagree about a ladder
-- that is definitely unsafe rather than about one that is definitely fine.
local raised, message = pcall(L.ladders_overrun,
  OVERRUN, "rf-not-a-plasma", FULL, SETTLE_S, GUARD_DT)
check(raised == false, "an unsimulatable guard fuel raises rather than reporting the ladder safe",
  raised and "RETURNED, so the guard can still be switched off silently" or "raised")
check(type(message) == "string" and message:find("rf%-not%-a%-plasma", 1, false) ~= nil,
  "and it names the plasma it could not simulate, so the typo is visible",
  tostring(message))

-- The other two ways to ask and get no answer. Neither can happen from control.lua -- it passes a
-- prototype's own volume and a fixed horizon -- but they reach the same nil and must reach the same
-- refusal, or the fix above is about one input rather than about the property.
check(select(1, pcall(L.ladders_overrun,
    OVERRUN, SPEC.confinement_guard_fuel, 0, SETTLE_S, GUARD_DT)) == false,
  "an empty reactor raises too, rather than passing a ladder it never ran")
check(select(1, pcall(L.ladders_overrun,
    OVERRUN, SPEC.confinement_guard_fuel, FULL, 0, GUARD_DT)) == false,
  "and so does a horizon too short for a single step")

-- ----------------------------------------------------------------

-- ---------------------------------------------------------- the plant-efficiency ladder (#96)
--
-- ADR 0020. Three technologies take capture_efficiency 0.85 -> 0.90 -> 0.925 -> 0.9375, each
-- closing HALF the remaining distance to a ceiling of 0.95. The halving is the whole mechanism:
-- halving a gap never closes it, so the free-loop guard holds structurally and there is no clamp
-- to maintain. Everything here is arithmetic on the ladder plus the two functions control.lua
-- reaches it through -- the resolver and the load guard's decision.

local CAPTURE_LADDER = SPEC.capture_ladder
check(type(CAPTURE_LADDER) == "table" and #CAPTURE_LADDER == 3,
  "the neutronic reactor has a plant-efficiency ladder of exactly three rungs",
  tostring(CAPTURE_LADDER and #CAPTURE_LADDER))
check(ANEUTRONIC.capture_ladder == nil and ANEUTRONIC.capture_ceiling == nil,
  "and the aneutronic reactor deliberately has neither ladder nor ceiling (ADR 0020, decision 4)")

-- THE VALUES AS VALUES, which is the ticket's own wording. Pinned rather than derived, because
-- these are the numbers a tooltip quotes and a player reads, and a test that recomputed them from
-- the halving rule would agree with any ladder built by that rule rather than with this one.
near(SPEC.capture_efficiency, 0.85, 0, "an unresearched force recovers 0.85")
near(CAPTURE_LADDER[1].capture_efficiency, 0.90,   0, "level 1 takes it to 0.90")
near(CAPTURE_LADDER[2].capture_efficiency, 0.925,  0, "level 2 to 0.925")
near(CAPTURE_LADDER[3].capture_efficiency, 0.9375, 0, "and level 3 to 0.9375")
near(SPEC.capture_ceiling, 0.95, 0, "against a ceiling of 0.95")

-- AND AS A HALVING, which is the property the values are an instance of. Asserted separately from
-- the values above so that changing one without the other fails rather than passes: a rung moved
-- by hand would still be "a value", and this is what says it is still the right kind of value.
local previous = SPEC.capture_efficiency
for level, rung in ipairs(CAPTURE_LADDER) do
  near(rung.capture_efficiency, previous + (SPEC.capture_ceiling - previous) / 2, 1e-12,
    string.format("level %d closes exactly half the gap that was left", level))
  previous = rung.capture_efficiency
end

-- NO LEVEL REACHES THE CEILING, which is the free-loop guard stated as arithmetic. It cannot be
-- reached by halving, so this is a property rather than a coincidence -- but it is what
-- control.lua's check_plant_efficiency refuses to load over, so it is asserted here as well.
for level, rung in ipairs(CAPTURE_LADDER) do
  check(rung.capture_efficiency < SPEC.capture_ceiling,
    string.format("level %d stays under the ceiling", level),
    string.format("%.6g against %.6g", rung.capture_efficiency, SPEC.capture_ceiling))
  check(rung.capture_efficiency < 1,
    string.format("and level %d is well under 1.0, where a reactor would pay for its own heating", level),
    string.format("%.6g", rung.capture_efficiency))
end

-- THE TOTAL PRIZE, which is what ADR 0020 decision 2 turns on. TWO FIGURES, NOT ONE, and they are
-- easy to conflate: +11.8% is what the CEILING allows any line into this constant to be worth
-- (0.95/0.85), and +10.3% is what the three shipped rungs actually deliver (0.9375/0.85). The ADR
-- quotes the first when it argues that an infinite research is calibrated for an unbounded reward;
-- the second is what a player gets. Both are asserted so neither can be quoted as the other.
near(SPEC.capture_ceiling / SPEC.capture_efficiency - 1, 0.1176, 0.001,
  "the ceiling caps any line into this constant at +11.8% of what a reactor sells")
near(CAPTURE_LADDER[3].capture_efficiency / SPEC.capture_efficiency - 1, 0.1029, 0.001,
  "and the three shipped rungs take +10.3% of that, which is what a player gets")

-- WHAT A FORCE ACTUALLY RUNS. The resolver control.lua calls on a cache miss, driven here with a
-- plain predicate so that the decision is testable without a game.
local function has(...)
  local held = {}
  for _, name in ipairs({ ... }) do held[name] = true end
  return function(name) return held[name] end
end
near(L.capture_efficiency(SPEC, has()), 0.85, 0,
  "a force with nothing researched runs the spec's own constant")
near(L.capture_efficiency(SPEC, has("rf-plant-efficiency-1")), 0.90, 0, "level 1 moves it")
near(L.capture_efficiency(SPEC, has("rf-plant-efficiency-1", "rf-plant-efficiency-2")), 0.925, 0,
  "and level 2 on top of it")
near(L.capture_efficiency(SPEC, has("rf-plant-efficiency-1", "rf-plant-efficiency-2",
  "rf-plant-efficiency-3")), 0.9375, 0, "and the whole line reaches the top rung")
-- THE HIGHEST RUNG WINS, NOT THE COUNT, which matters for a force granted level 3 from the console
-- without the two below it. The prerequisite chain is a player-facing ordering and the simulation
-- may not assume it held -- the same reasoning M.resolve_ladder is written under, which is the one
-- rung walk every ladder has shared since #424.
near(L.capture_efficiency(SPEC, has("rf-plant-efficiency-3")), 0.9375, 0,
  "a force granted only the top rung gets the top rung, not one level of anything")
near(L.capture_efficiency(SPEC, has("rf-plant-efficiency-2")), 0.925, 0, "and only the middle one, the middle one")
-- The aneutronic reactor has no ladder, so no amount of research moves it. This is ADR 0020's
-- decision 4 as an assertion rather than as a comment.
for _, name in ipairs({ "rf-plant-efficiency-1", "rf-plant-efficiency-2", "rf-plant-efficiency-3" }) do
  near(L.capture_efficiency(ANEUTRONIC, has(name)), ANEUTRONIC.capture_efficiency, 0,
    "the aneutronic reactor does not move for " .. name)
end

-- THE FREE LOOP AT LEVEL 3, which is the assertion the whole ceiling exists for, taken at the
-- operating point that is WORST for the guard rather than at a convenient one.
--
-- "A cold reactor returns less than the heating it draws" is ADR 0020's phrasing and its arithmetic
-- is the steady state: over a step where the plasma keeps nothing, everything the heating put in
-- leaves again through left_j and is sold across capture_efficiency. A literally cold reactor
-- returns far less than that, because most of the heating goes into warming the plasma -- so the
-- bound is not tested there. It is tested at a plasma too THIN to fuse and already pinned at the
-- temperature clamp, where nothing can be retained and the whole of the heating is sold. That is
-- the maximum a non-fusing reactor can ever return, and it is 46.9 MW against 50 MW drawn.
--
-- One unit of plasma is 1e17 m^-3, a millionth of a full box's density squared, so the 515 W that
-- does fuse is five orders below the heating and is noise rather than a term.
local RATED_W = SPEC.heating_power_w
local function never_fusing(capture)
  local result = L.step(SPEC, "rf-d-d-plasma", 1, SPEC.max_temperature_c, math.huge, TICK, capture)
  return result.energy_units * SPEC.energy_fluid_j_per_unit / TICK, result
end
local top_w, top = never_fusing(CAPTURE_LADDER[3].capture_efficiency)
local base_w = never_fusing(SPEC.capture_efficiency)
near(top_w, 46.875e6, 0.001,
  "at level 3 a reactor that is not fusing returns 46.9 MW, which is ADR 0020's own figure")
check(top_w < RATED_W,
  "which is less than the 50 MW it draws, so the plant is not a free loop at the top of the line",
  string.format("%.6g W against %.6g W", top_w, RATED_W))
near(top_w / RATED_W, CAPTURE_LADDER[3].capture_efficiency, 1e-4,
  "and the shortfall IS the capture efficiency, which is why the ceiling is the guard")
check(top.fusion_power_w < 1e-3 * RATED_W,
  "with fusion five orders below the heating, so this really is the non-fusing case",
  string.format("%.6g W", top.fusion_power_w))
near(base_w, 42.5e6, 0.001, "an unresearched force returns 42.5 MW at the same point")
check(top_w > base_w,
  "so research does move it -- toward the heating, and never to it",
  string.format("%.6g W against %.6g W", top_w, base_w))
-- The bound the asymptote sets, which is the sentence a fourth-rung proposal has to answer: the
-- drain never falls below 5% of heating whatever is researched.
check(SPEC.capture_ceiling * RATED_W < RATED_W,
  "even a force at the ceiling itself would return less than it drew",
  string.format("%.6g W against %.6g W", SPEC.capture_ceiling * RATED_W, RATED_W))

-- THE DECISION control.lua's check_plant_efficiency MAKES, and the negative half of it. That guard
-- refuses to load a rung at or above the ceiling; the comparison lives in reactor-logic so it can
-- be broken here, because a guard nobody has watched fail is a guard nobody knows the shape of.
check(L.capture_ceiling_fault(SPEC) == nil,
  "the shipped ladder passes the guard, so load-check.ps1 is not being asked to load a refusal")
check(L.capture_ceiling_fault(ANEUTRONIC) == nil,
  "and a reactor with no ceiling at all is not a fault -- it simply has no line")

-- A SPEC WITH NO CEILING IS STILL BOUNDED, AT 1.0, and this is the half review found missing. The
-- guard used to return nil for any spec that declared no capture_ceiling, which is exactly
-- M.aneutronic_reactor -- the spec with the HIGHEST shipped capture and the tightest margin in the
-- mod. A balance pass raising it to 1.0 would have loaded, and a non-fusing aneutronic reactor
-- would have sold back exactly its heating for ever.
--
-- The line above is what says 0.95 with no ceiling PASSES, so the two together are the whole
-- statement: no line, bounded by physics, and 1.0 is where physics stops.
local _, an_value, an_ceiling = L.capture_ceiling_fault(
  { capture_efficiency = 1.0 })
check(an_ceiling == 1 and an_value == 1.0,
  "a ceiling-less reactor at 1.0 is refused, and the bound reported is the free loop itself",
  string.format("%s at a bound of %s", tostring(an_value), tostring(an_ceiling)))
check(L.capture_ceiling_fault({ capture_efficiency = 1.2 }) == "its unresearched capture_efficiency",
  "and so is one past it, which would sell back more than it was given")
check(L.capture_ceiling_fault({ capture_efficiency = 0.99 }) == nil,
  "while 0.99 with no ceiling passes -- lossy, so not a loop, whatever else it is")
check(L.capture_ceiling_fault({
    capture_efficiency = 0.9,
    capture_ladder = { { technology = "rf-x", capture_efficiency = 1.0 } },
  }) == "rf-x",
  "a ladder on a ceiling-less spec is bounded by 1.0 too, rung by rung")
local reaching = {
  capture_efficiency = SPEC.capture_efficiency,
  capture_ceiling = SPEC.capture_ceiling,
  capture_ladder = {
    { technology = "rf-plant-efficiency-1", capture_efficiency = 0.90 },
    { technology = "rf-plant-efficiency-2", capture_efficiency = 0.95 },
  },
}
local broke, value = L.capture_ceiling_fault(reaching)
check(broke == "rf-plant-efficiency-2" and value == 0.95,
  "a rung that ARRIVES at the ceiling is refused, and the refusal names it",
  string.format("%s at %s", tostring(broke), tostring(value)))
check(L.capture_ceiling_fault({
    capture_efficiency = SPEC.capture_efficiency, capture_ceiling = SPEC.capture_ceiling,
    capture_ladder = { { technology = "rf-plant-efficiency-1", capture_efficiency = 1.0 } },
  }) == "rf-plant-efficiency-1",
  "and so is one past it, which is the free loop itself")
check(L.capture_ceiling_fault({ capture_efficiency = 0.99, capture_ceiling = SPEC.capture_ceiling })
    == "its unresearched capture_efficiency",
  "a spec whose UNRESEARCHED value already breaks the ceiling is refused too, ladder or no ladder")

-- ---------------------------------------------------------------- the density curve (#74)
--
-- ADR 0016 accepts that a reactor makes more power under-supplied than full, and #74 is what tells
-- a reactor where its own best density is so the status line can stop calling that state a fault.
-- density_curve is the sweep behind it: settle the reactor at twenty fills, rank them by the fusion
-- power they reach, and report where the peak is and where under-supplying stops paying.
--
-- WHAT MAKES THIS A TEST AND NOT A TAUTOLOGY. The whole table below is published in ADR 0016 and
-- reproduced in tests/test-bremsstrahlung.lua by a bisection solver that shares no code with
-- step(). This suite drives the SHIPPED step() instead, so agreeing with those figures is two
-- independent routes to one answer -- which is the shape #51 was opened about and the reason the
-- other suite exists.

local function curve_at(tau, fuel, heating_w)
  local spec = {}
  for k, v in pairs(SPEC) do spec[k] = v end
  spec.confinement_time_s = tau
  if heating_w then spec.heating_power_w = heating_w end
  return L.density_curve(spec, fuel or "rf-d-d-plasma", FULL)
end

local SHIPPED_CURVE = L.density_curve(SPEC, "rf-d-d-plasma", FULL)
check(SHIPPED_CURVE ~= nil, "the shipped reactor has a density curve")

-- ADR 0016's headline: 65% fill at the shipped confinement time, where Q reaches 0.450 against a
-- full reactor's 0.320.
near(SHIPPED_CURVE.optimum, 0.65, 1e-9,
  "the shipped tier's best density is ADR 0016's 65% fill")

-- And its floor: "below about 35% fill the n-squared term wins again and a starved reactor is worse
-- off than a full one". That sentence is the whole of what "starved" now means, so the number it
-- names is worth pinning rather than trusting.
near(SHIPPED_CURVE.floor, 0.35, 1e-9,
  "and under-supplying stops paying at ADR 0016's 35%")

-- THE OPTIMUM WALKS UP THE FILL AXIS AS CONFINEMENT RESEARCH RAISES TAU, and leaves the range
-- entirely. This is the property #74's acceptance criterion turns on -- whatever a reactor shows a
-- player has to stay correct as research moves the optimum -- so it is asserted as a monotone walk
-- rather than as one number, which a single rung would not distinguish from a hardcoded fraction.
local walked = {}
for _, tau in ipairs({ 30, 40, 50, 60, 70 }) do
  walked[#walked + 1] = { tau = tau, curve = curve_at(tau) }
end
for i = 2, #walked do
  check(walked[i].curve.optimum >= walked[i - 1].curve.optimum,
    string.format("the best density at tau %g s is no thinner than at tau %g s",
      walked[i].tau, walked[i - 1].tau),
    string.format("%.2f against %.2f", walked[i].curve.optimum, walked[i - 1].curve.optimum))
end
check(walked[#walked].curve.optimum > walked[1].curve.optimum,
  "and it has actually moved over the ladder, rather than being a constant that never walks",
  string.format("%.2f at tau 70 s against %.2f at tau 30 s",
    walked[#walked].curve.optimum, walked[1].curve.optimum))

-- ADR 0016's third row: by tau 70 s full supply is simply best, and the lever is closed.
local TOP = walked[#walked].curve
near(TOP.optimum, 1.0, 1e-9, "by tau 70 s the best density is full supply")

-- AND THE FLOOR GOES WITH IT, which is not a rounding case but the regime the ladder ends in. With
-- the peak at full supply every thinner fill is worth less than a full one, so a floor read as
-- "worse than full" would condemn a reactor at 95% as starved. There is no trap to warn about --
-- adding plasma helps all the way up -- so the floor is zero and nothing is called starved for its
-- density at all.
near(TOP.floor, 0, 1e-9, "with no interior peak there is no starved band")
check(SHIPPED_CURVE.floor > 0, "where the peak IS interior there is one",
  tostring(SHIPPED_CURVE.floor))

-- The floor is below the optimum by construction: it is the thinnest fill still worth as much as a
-- full reactor, and a peak sits above every point that merely matches full supply.
for _, row in ipairs(walked) do
  check(row.curve.floor < row.curve.optimum,
    string.format("at tau %g s the starved floor is below the best density", row.tau),
    string.format("%.2f against %.2f", row.curve.floor, row.curve.optimum))
end

-- The band a caller treats as "at the optimum" comes off the curve rather than being invented by
-- the caller, so the resolution of the answer and the width of the band cannot drift apart.
check(SHIPPED_CURVE.step > 0 and SHIPPED_CURVE.step <= 0.1,
  "the curve reports the grid step its fills are resolved to", tostring(SHIPPED_CURVE.step))
local on_grid = SHIPPED_CURVE.optimum / SHIPPED_CURVE.step
near(on_grid, math.floor(on_grid + 0.5), 1e-9,
  "and the optimum is one of the grid's own fills")

-- D-T IS NOT D-D, and ADR 0016 is explicit about why: D-T sits far PAST its optimum rather than
-- below it, so it de-rates almost exactly as n-squared and full supply is its best density. A curve
-- that gave both fuels the same answer would be reporting the sweep's shape rather than the fuel's.
near(curve_at(30, "rf-d-t-plasma").optimum, 1.0, 1e-9,
  "D-T's best density is full supply at the shipped confinement time")

-- ------------------------------ the curve moves with HEATING too (#425, ADR 0038)
--
-- THIS IS THE ASSERTION control.lua's DENSITY-CURVE CACHE KEY RESTS ON. That table was keyed
-- [prototype][confinement_time_s][fluid] and its note said confinement time was the only field
-- derive() moved -- true until ADR 0038 gave the reactor a second spec ladder. A curve is swept by
-- settling the reactor at twenty fills and step() heats it at spec.heating_power_w, so two forces
-- at ONE confinement time and different heating rungs have genuinely different optima. Without
-- heating power in the key the second reads the first's answer and circuit-output.status reports
-- the wrong one of lean / running / rich.
--
-- The pair below is the proof, and it is the sharpest pair there is: at the top of the confinement
-- ladder one heating rung takes the optimum from an interior 90% straight to full supply.
local TAU_TOP = LADDER[#LADDER].confinement_time_s
local AT_TOP_BASE  = curve_at(TAU_TOP, nil, SPEC.heating_power_w)
local AT_TOP_RUNG1 = curve_at(TAU_TOP, nil, HEAT_LADDER[1].heating_power_w)
near(AT_TOP_BASE.optimum, 0.90, 1e-9,
  "at the top confinement rung and base heating the best density is 90% fill")
near(AT_TOP_BASE.floor, 0.85, 1e-9, "with the starved floor just under it at 85%")
near(AT_TOP_RUNG1.optimum, 1.0, 1e-9,
  "and one heating rung later, at the SAME confinement time, it is full supply")
near(AT_TOP_RUNG1.floor, 0, 1e-9, "with no interior peak and so no starved band at all")
check(AT_TOP_BASE.optimum ~= AT_TOP_RUNG1.optimum,
  "so confinement time alone does not identify a curve, which is why the cache key carries heating power")

-- ADR 0016'S MECHANIC CLOSES AT THAT RUNG, AND ADR 0038 ACCEPTS IT. ADR 0024 chose 60 s over 70 s
-- specifically to leave the +4% that a 90%-over-85% choice is worth alive; the first heating rung
-- spends it. Accepted on ADR 0016's own grounds -- the mechanic was always expected to be
-- researched away -- and recorded here so the closure is a measured fact rather than a prediction.
for h = 1, #HEAT_LADDER do
  local curve = curve_at(TAU_TOP, nil, HEAT_LADDER[h].heating_power_w)
  near(curve.optimum, 1.0, 1e-9,
    string.format("at the top confinement rung, heating rung %d leaves nothing to tune", h))
end

-- AT ENTRY CONFINEMENT THE MECHANIC SURVIVES ALL FIVE RUNGS, which is the other half of ADR 0038's
-- claim and the half that stops "the mechanic closes" being read as "the mechanic is gone". The
-- optimum walks 65% to 90% and the floor 35% to 80%: still interior, still a choice, and still
-- worth something at every rung a player can reach at the confinement time they start with.
local entry_optima = {}
for h = 0, #HEAT_LADDER do
  local heating = (h == 0) and SPEC.heating_power_w or HEAT_LADDER[h].heating_power_w
  entry_optima[h] = curve_at(SPEC.confinement_time_s, nil, heating)
  check(entry_optima[h].optimum < 1.0,
    string.format("at entry confinement, heating rung %d still has an interior optimum", h),
    string.format("%.2f", entry_optima[h].optimum))
  check(entry_optima[h].floor > 0,
    string.format("and a starved floor under it at heating rung %d", h),
    string.format("%.2f", entry_optima[h].floor))
end
near(entry_optima[0].optimum, 0.65, 1e-9, "the walk starts at ADR 0016's 65% fill")
near(entry_optima[#HEAT_LADDER].optimum, 0.90, 1e-9, "and reaches 90% at the top heating rung")
near(entry_optima[0].floor, 0.35, 1e-9, "the floor starts at 35%")
near(entry_optima[#HEAT_LADDER].floor, 0.80, 1e-9, "and reaches 80%")

-- The aneutronic tier has its own reactor, its own volume and no confinement ladder, and it gets
-- its own curve for the same reason it gets its own spec.
local ANEUTRONIC_CURVE = L.density_curve(L.aneutronic_reactor, "rf-d-he3-plasma", ANEUTRONIC_FULL)
check(ANEUTRONIC_CURVE ~= nil, "the aneutronic reactor has a curve of its own")
check(ANEUTRONIC_CURVE.optimum > 0 and ANEUTRONIC_CURVE.optimum <= 1.0,
  "and its best density is a fill", tostring(ANEUTRONIC_CURVE.optimum))

-- Nothing to sweep is nil rather than a fabricated curve, which is what control.lua caches as
-- "this plasma has none" and what circuit-output falls back to "running" on. A guessed curve would
-- put a reactor in a density state nobody measured.
check(L.density_curve(SPEC, "water", FULL) == nil, "a fluid with no fuel row has no curve")
check(L.density_curve(SPEC, nil, FULL) == nil, "and neither does no fluid at all")
check(L.density_curve(SPEC, "rf-d-d-plasma", 0) == nil, "nor a box with no volume")


-- ---------------------------------------------------------------- float32 representability (#119)
--
-- A prototype hands its numbers back at SINGLE precision. So a ceiling declared as a Lua double in
-- this file and as the same literal in prototypes/fluids.lua comes back from the engine slightly
-- SMALLER whenever the value is not exactly representable, control.lua's check_plasma_bounds sees
-- the two disagree, and the mod refuses to load over a pair of numbers that were typed identically
-- and print identically. Measured on 2.0.77 while building #55.
--
-- DECIDED (Truls, 2026-08-26, #119): a ceiling has to BE representable. Not "compare at float32
-- precision", which would accept 6.9e9 and let the simulation clamp 256 C above what the fluid can
-- hold; not a tolerance, which would put a fudge factor inside an invariant whose whole value is
-- being exact. The check refuses an unrepresentable ceiling and names the nearest one that works.
--
-- It costs a person almost nothing, which is what makes the strict reading affordable: representable
-- values are 512 C apart at 5e9 -- one part in ten million -- and 2, 3, 4, 5, 6, 6.8, 6.912, 6.96
-- and 7 x10^9 are all exact. Of the numbers this project has actually reached for, only 6.9e9 and
-- the dataset edge itself are not.
--
-- NO math.frexp AND NO string.pack. The first is gone in 5.4 (this file is verified there) and the
-- second does not exist in 5.2 (which is what Factorio runs), so neither is portable across both.
-- The implementation normalises by exact powers of two instead, which every version has.

check(L.float32_exact ~= nil and L.float32_floor ~= nil,
  "reactor-logic exposes the representability predicate and the nearest representable value")

-- The shipped ceilings, which are the reason this is asserted at all rather than merely tested.
check(L.float32_exact(SPEC.max_temperature_c),
  "the neutronic ceiling is representable, so check_plasma_bounds can compare it as declared",
  string.format("%.10g", SPEC.max_temperature_c))
check(L.float32_exact(ANEUTRONIC.max_temperature_c),
  "and so is the aneutronic one",
  string.format("%.10g", ANEUTRONIC.max_temperature_c))

-- Ground truth computed offline with string.pack("<f") on standalone Lua 5.4 and pasted in as
-- literals. The oracle cannot ship -- 5.2 has no string.pack, which is the whole reason
-- float32_exact exists -- so what is asserted here is agreement with a round trip run elsewhere.
for _, value in ipairs({ 15, 1, 0.5, 2e9, 3e9, 4e9, 5e9, 6e9, 6.8e9, 6.912e9, 6.96e9, 7e9 }) do
  check(L.float32_exact(value), string.format("%.10g survives a float32 round trip", value))
end
for _, value in ipairs({ 6.5e9, 6.9e9, 6.96271e9 }) do
  check(not L.float32_exact(value),
    string.format("%.10g does not, which is the case #119 was opened about", value))
end

-- The two the project actually reached for, to the digit, so a wrong exponent cannot pass.
near(L.float32_floor(6.9e9), 6899999744, 0,
  "6.9e9 stores as 6899999744 -- the 256 C that made two identical numbers disagree")
near(L.float32_floor(6.96271e9), 6962709504, 0,
  "and the reactivity dataset's own edge is not representable either")

-- float32_floor never rounds UP, which matters because it suggests a replacement for a CEILING:
-- a suggestion above the value asked for could push a later tier past a bound it was chosen under.
for _, value in ipairs({ 6.5e9, 6.9e9, 6.96271e9, 1.234e9, 3.7e8 }) do
  local floored = L.float32_floor(value)
  check(floored <= value and L.float32_exact(floored),
    string.format("float32_floor(%.10g) lands on a representable value at or below it", value),
    string.format("%.10g", floored))
end

-- An already-representable value is its own floor, or the message would suggest changing a number
-- that is already fine.
for _, value in ipairs({ 2e9, 5e9, 6.912e9 }) do
  near(L.float32_floor(value), value, 0,
    string.format("%.10g is its own nearest representable value", value))
end

-- Degenerate inputs reach this from a spec someone is editing, so they answer rather than throw.
check(L.float32_exact(0), "zero is representable")
check(L.float32_exact(-2e9), "and so is a negative, which the sign must not confuse")
check(not L.float32_exact(0 / 0), "a NaN is not representable rather than an error")
check(not L.float32_exact(math.huge), "nor is an infinity")

-- THE LARGE END, WHERE THE FIRST VERSION OF THIS WAS WRONG. `local scale = 1` made scale an INTEGER
-- on Lua 5.4, so doubling it wrapped at 2^63 and every representable value from 2^86 up came back
-- unrepresentable. Factorio's 5.2 has no integer subtype and never showed it, so only this file
-- could catch it. These are float32-exact by construction: powers of two, and FLOAT32_MAX itself.
for _, value in ipairs({ 2 ^ 86, 2 ^ 100, 2 ^ 127, (2 - 2 ^ -23) * 2 ^ 127 }) do
  check(L.float32_exact(value),
    string.format("%.10g is representable, above where integer scale used to wrap", value))
end

-- Past the largest finite float32 nothing is representable: the engine rounds it to infinity, which
-- is not the value that was declared.
for _, value in ipairs({ 2 ^ 128, 1e300, 3.5e38 }) do
  check(not L.float32_exact(value),
    string.format("%.10g overflows a float32 rather than surviving it", value))
end

-- THE SMALL END, WHERE IT WAS ALSO WRONG. Below 2^-126 a float32's spacing stops halving and stays
-- at 2^-149, so normalising past that reported every subnormal -- and everything under one -- as
-- representable when the engine flushes it to zero.
check(L.float32_exact(2 ^ -140), "a subnormal that is a whole number of 2^-149 steps is representable")
check(L.float32_exact(2 ^ -149), "and so is the smallest subnormal itself")
for _, value in ipairs({ 2 ^ -150, 2 ^ -1074, 1e-320 }) do
  check(not L.float32_exact(value),
    string.format("%.10g is below every float32 step and flushes to zero", value))
end

-- float32_ceil is float32_floor's mirror, and the guard uses it for the MINIMUM bound: a floor
-- suggested downwards would sit under the value someone chose, which is the direction
-- check_plasma_bounds refuses on.
for _, value in ipairs({ 6.5e9, 6.9e9, 6.96271e9, 1.234e9 }) do
  local ceiled = L.float32_ceil(value)
  check(ceiled >= value and L.float32_exact(ceiled),
    string.format("float32_ceil(%.10g) lands on a representable value at or above it", value),
    string.format("%.10g", ceiled))
end
near(L.float32_ceil(6.9e9), 6900000256, 0,
  "6.9e9's representable neighbours are 6899999744 below and 6900000256 above")
for _, value in ipairs({ 15, 2e9, 5e9 }) do
  near(L.float32_ceil(value), value, 0,
    string.format("%.10g is its own ceiling as well as its own floor", value))
end

H.finish()
