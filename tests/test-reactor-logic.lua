-- Tests for the reactor power balance.
--
-- Run from the repository root:   lua tests/test-reactor-logic.lua
--
-- Like tests/test-reactivity.lua this runs outside Factorio, which is only possible because the
-- module under test touches no Factorio API (ADR 0005). Written to Lua 5.2 semantics and verified
-- on 5.4.

package.path = "RealisticFusion/?.lua;" .. package.path
local L = require("scripts.reactor-logic")

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
local HOT = 6.0e8        -- roughly where the shipped spec settles, in celsius

--- Run to steady state with the reactor kept full, which is what a heater that keeps up does.
local function settle(spec, seconds, available_j)
  local t_c, last = spec.min_temperature_c, nil
  for _ = 1, math.floor(seconds * 60) do
    last = L.step(spec, "rf-d-d-plasma", FULL, t_c, available_j, TICK)
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

-- Every plasma the mod defines needs an entry, or its reactor silently does nothing.
check(L.fuels["rf-d-d-plasma"] ~= nil, "D-D plasma has a fuel entry")

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
local cold_t, cold_state = settle(COLD_SPEC, 120, math.huge)
local cold_out_w = cold_state.energy_units * COLD_SPEC.energy_fluid_j_per_unit * 60
check(cold_state.fusion_power_w < 0.05 * COLD_SPEC.heating_power_w, "the leaky reactor barely fuses",
  string.format("%.3g W at %.3g C", cold_state.fusion_power_w, cold_t))
check(cold_out_w < COLD_SPEC.heating_power_w, "a reactor that does not fuse is a net loss",
  string.format("out %.3g W vs heating %.3g W", cold_out_w, COLD_SPEC.heating_power_w))

-- ---------------------------------------------------------------- the shipped balance
--
-- Not a physics check -- a check that the numbers the mod ships with produce a reactor worth
-- building. These bounds are wide on purpose: they catch a constant edited by accident, not a
-- deliberate rebalance, which should move them.
local hot_t, hot_state = settle(SPEC, 120, math.huge)
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
