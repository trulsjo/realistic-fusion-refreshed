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
--
-- THE LOOP ITSELF LIVES IN reactor-logic SINCE #53, and this is a wrapper over it rather than a
-- second copy. control.lua's confinement guard has to settle a reactor at load, and #51 is the
-- record of what it costs to have one piece of arithmetic implemented twice. What stayed here is
-- the argument order and the defaults, which every call below is written against.
local function settle(spec, seconds, available_j, dt, fluid, amount)
  return L.settle(spec, fluid or "rf-d-d-plasma", amount or FULL, seconds, available_j, dt or TICK)
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
near(held_dt, SPEC.max_temperature_c, 1e-12,
  "five unpowered minutes take the D-T plasma all the way to the top of its range")
check(held_dd < held_dt / 1000, "and take the D-D plasma out of the fusing range entirely",
  string.format("%.6g C against %.6g C", held_dd, held_dt))

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
near(half_t, ANEUTRONIC.max_temperature_c, 1e-12,
  "at half fill the same reactor ignites and runs to the clamp")
check(half_state.q_factor > 10, "and runs far past break-even there, which is the tier's optimum",
  string.format("Q = %.3g at %d units", half_state.q_factor, ANEUTRONIC_FULL / 2))
-- Raising the heating clears the full box too, so the fold is a ratio rather than a wall.
local lit = {}
for key, value in pairs(ANEUTRONIC) do lit[key] = value end
lit.heating_power_w = ANEUTRONIC.heating_power_w * 4
local lit_t = settle(lit, SETTLE_S, math.huge, nil, "rf-d-he3-plasma", ANEUTRONIC_FULL)
near(lit_t, ANEUTRONIC.max_temperature_c, 1e-12,
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
-- neighbour. Thinning the plasma does get it to the clamp -- 300 units reaches 2e9 -- but reaching
-- the clamp is not IGNITING. CONTEXT.md fixes that word: an ignited plasma is one "whose own fusion
-- self-heating carries it without external confinement heating". At 300 units the 200 MW heater is
-- carrying the whole thing and Q peaks at 0.0131. The plasma is hot because it is thin and being
-- heated, not because it is fusing.
--
--     3000 u  3.11e6 C   Q 9e-48
--      500 u  1.08e9 C   Q 0.0062
--      300 u  clamp      Q 0.0131   <- the best it does, at any fill
--      100 u  clamp      Q 0.0015
--
-- So D-He3 has a fold it can be moved across and this has a ceiling it cannot: every fill trades
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
  "and no fill ignites it: thinning reaches the clamp on heater power alone, not on fusion",
  string.format("best Q %.4g across six fills, against D-He3's %.3g at half fill",
    he3_best_q, half_state.q_factor))

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
local floor_he3   = at_floor(ANEUTRONIC, "rf-he3-he3-plasma", 3000)
local floor_dhe3  = at_floor(ANEUTRONIC, "rf-d-he3-plasma", 3000)
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

local LADDER = SPEC.confinement_ladder
check(type(LADDER) == "table" and #LADDER > 0, "the neutronic reactor has a confinement ladder")
check(ANEUTRONIC.confinement_ladder == nil,
  "and the aneutronic reactor deliberately has none -- see the ladder's note in reactor-logic")
-- The plasma the load guard is asked about. It lives on the spec so that a second reactor given a
-- ladder names its own, and control.lua refuses to load a ladder that has none -- but it can only
-- refuse over a spec it can see, and this is the earlier place.
check(L.fuels[SPEC.confinement_guard_fuel or ""] ~= nil,
  "the ladder names a plasma the simulation can actually burn to guard it",
  tostring(SPEC.confinement_guard_fuel))

-- Strictly upward from the shipped value. A rung at or below the one before it is a technology that
-- does nothing, or undoes something, and neither would fail anything else here.
local previous_tau = SPEC.confinement_time_s
for level, rung in ipairs(LADDER) do
  check(rung.confinement_time_s > previous_tau,
    string.format("rung %d raises confinement time", level),
    string.format("%g s after %g s", rung.confinement_time_s, previous_tau))
  check(type(rung.technology) == "string" and rung.technology ~= "",
    string.format("rung %d names a technology", level))
  previous_tau = rung.confinement_time_s
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

near(L.confinement_time(SPEC, researched()), SPEC.confinement_time_s, 0,
  "a force with nothing researched runs the shipped confinement time")
near(L.confinement_time(SPEC, researched(TOP.technology)), TOP.confinement_time_s, 0,
  "a force holding only the top rung gets the top rung, not the base")
near(L.confinement_time(ANEUTRONIC, researched(TOP.technology)), ANEUTRONIC.confinement_time_s, 0,
  "and the ladder does not reach the aneutronic reactor however much is researched")
near(L.confinement_time(SPEC, researched(LADDER[1].technology)), LADDER[1].confinement_time_s, 0,
  "a force part way up gets the rung it has reached and no more")

--- The spec one rung up, as control.lua's derive() builds it.
local function at_rung(level)
  local spec = {}
  for k, v in pairs(SPEC) do spec[k] = v end
  spec.confinement_time_s = LADDER[level].confinement_time_s
  return spec
end

--- Q at one rung and one fill of the input box.
local function q_at(level, fill)
  local _, state = settle(at_rung(level), SETTLE_S, math.huge, nil, nil, FULL * (fill or 1))
  return state.q_factor
end

-- THE RUNGS THEMSELVES, pinned to 1% the way #51 requires every balance figure to be. These are the
-- numbers reactor-logic's ladder note quotes and the numbers the technology descriptions describe
-- in words; a rebalance moves them here first and everything downstream is a deliberate edit.
near(q_at(1), 0.5777, 0.01, "rung 1 reaches Q 0.578 at full supply")
near(q_at(2), 0.9503, 0.01, "rung 2 reaches Q 0.950 at full supply")
near(q_at(3), 1.4675, 0.01, "rung 3 reaches Q 1.468 at full supply")

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

check(L.confinement_ladder_overruns(SPEC, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT) == nil,
  "the shipped ladder does not reach the clamp",
  string.format("top rung %g s settles at %.4g C, clamp %.4g C", TOP.confinement_time_s,
    settle(at_rung(#LADDER), SETTLE_S, math.huge, GUARD_DT), SPEC.max_temperature_c))

-- BREAKING IT, which is the half that makes the line above mean anything. A fourth rung at 200 s is
-- past the crossing -- D-D reaches the clamp somewhere near 175 s in this model -- and the guard has
-- to say so rather than shrug.
local OVERRUN = {}
for k, v in pairs(SPEC) do OVERRUN[k] = v end
OVERRUN.confinement_ladder = {}
for _, rung in ipairs(LADDER) do
  OVERRUN.confinement_ladder[#OVERRUN.confinement_ladder + 1] = rung
end
OVERRUN.confinement_ladder[#OVERRUN.confinement_ladder + 1] =
  { technology = "rf-plasma-confinement-4", confinement_time_s = 200 }

local overrun_at = L.confinement_ladder_overruns(OVERRUN, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT)
check(overrun_at ~= nil, "a ladder with a rung at 200 s is caught",
  overrun_at and string.format("%.6g C", overrun_at) or "NOT CAUGHT")
-- `or 0` follows this file's rule that a nil is a failure and not an error: H.near would throw on
-- one, and a broken guard should fail the two checks it breaks rather than take the suite down and
-- hide everything after it.
near(overrun_at or 0, SPEC.max_temperature_c, 0,
  "and what it reports is the clamp itself, which is the reading a player would be stuck with")

-- A spec with no ladder at all is not an overrun, it is nothing to check. The aneutronic reactor is
-- exactly that case and passes through control.lua's loop untouched.
check(L.confinement_ladder_overruns(ANEUTRONIC, SPEC.confinement_guard_fuel, FULL, SETTLE_S, GUARD_DT) == nil,
  "a reactor with no ladder has nothing to overrun")

-- ----------------------------------------------------------------

H.finish()
