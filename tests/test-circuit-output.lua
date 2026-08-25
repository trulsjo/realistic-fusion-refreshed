-- Tests for what a reactor reports: the two circuit signals and the status it shows.
--
-- Run from the repository root:   lua tests/test-circuit-output.lua
--
-- Like the other two suites this runs outside Factorio, which is only possible because the part
-- under test is pure. scripts/circuit-output.lua is deliberately split so that everything deciding
-- WHAT to report is arithmetic on a step result, and only publish() touches the game. The split is
-- what makes the int32 ceiling testable at all -- in Factorio it is an error thrown at a player,
-- and here it is an assertion.
--
-- Written to Lua 5.2 semantics and verified on 5.4.

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
local H = require("harness")
local C = require("scripts.circuit-output")
local L = require("scripts.reactor-logic")

local check = H.check

-- This suite's own, because it is the only suite that wants it: what a combinator emits is an
-- integer and what it reports is a key, and neither has a tolerance to be near. Built on H.check
-- so the counters stay shared (#42).
local function equal(actual, expected, name)
  check(actual == expected, name, string.format("got %s, expected %s", tostring(actual), tostring(expected)))
end

local SPEC = L.reactor

-- ---------------------------------------------------------------- signal values

-- KILODEGREES SINCE #57 (ADR 0025), not whole degrees. Whole degrees cannot carry a fusion
-- temperature: a signal is an int32 and stops at 2.147e9, below where D-T actually settles, so the
-- readout was bounding the physics. The scale is read off the module rather than retyped, for the
-- reason INT32_MAX is below.
local SCALE = C.TEMPERATURE_SCALE
equal(SCALE, 1000, "the wire carries thousands of degrees, which is what ADR 0025 decided")

equal(C.signals({ temperature_c = 6.0e8, q_factor = 1.4 }).temperature, 600000,
  "temperature is emitted in kilodegrees")
equal(C.signals({ temperature_c = 877079999.6, q_factor = 0 }).temperature, 877080,
  "temperature rounds rather than truncates")

-- THE ACCEPTED COST OF THE SCALE, asserted so it is a known property rather than a surprise found
-- in a game. Everything under half a kilodegree reads zero, which is the same number a reactor with
-- no plasma at all reports -- so below 500 C the status signal is the only thing separating a cold
-- reactor from an empty one. ADR 0025 took this deliberately; see its Consequences.
equal(C.signals({ temperature_c = 15, q_factor = 0 }).temperature, 0,
  "a reactor at the 15 C floor reads zero, indistinguishable from empty on this signal alone")
equal(C.signals({ temperature_c = 499, q_factor = 0 }).temperature, 0,
  "and so does anything under half a kilodegree")
equal(C.signals({ temperature_c = 500, q_factor = 0 }).temperature, 1,
  "half a kilodegree is where the signal starts moving")

-- Q is fractional and a circuit signal is an integer, so it goes out as a percentage. Q 2.1 is 210,
-- which also means a decider testing "Q > 100" is asking "is it net positive", the question worth
-- asking.
equal(C.signals({ temperature_c = 15, q_factor = 2.1 }).q, 210, "Q is emitted as a percentage")
equal(C.signals({ temperature_c = 15, q_factor = 0 }).q, 0, "Q of zero is zero")
equal(C.signals({ temperature_c = 15, q_factor = 0.997 }).q, 100,
  "Q just under break-even rounds to 100")

-- ---------------------------------------------------------------- the int32 ceiling
--
-- Not a theoretical bound. Probed against 2.0.77: writing 3e9 to a combinator slot throws
-- "Given min value (3e+09) is too big, allowed values are from -2147483648 to 2147483647" --
-- an error, not a wrap, so an unclamped write is a crash in front of a player.

-- READ OFF THE MODULE SINCE #55, not retyped. This file kept its own copy of both numbers, and
-- control.lua was about to want a third for its ceiling guard -- one equation in three places,
-- which is what #51 was opened about. circuit-output owns them because it is the file that knows
-- why the limit exists.
local INT32_MAX = C.INT32_MAX
local INT32_MIN = C.INT32_MIN

-- And the copies that were here are now assertions rather than definitions: the constants have to
-- BE the int32 bounds, or everything below is checking the module against itself.
equal(INT32_MAX, 2147483647, "the module's int32 ceiling is the int32 ceiling")
equal(INT32_MIN, -2147483648, "and its floor is the int32 floor")

-- THE CLAMP IS NOW A SCALE FURTHER OUT. A wire still stops at INT32_MAX, but it takes
-- INT32_MAX * SCALE degrees to reach it -- about 2.1e12 C, three orders past anything the
-- cross-section data can even be asked about.
local WIRE_CEILING_C = INT32_MAX * SCALE
equal(C.signals({ temperature_c = WIRE_CEILING_C * 2, q_factor = 0 }).temperature, INT32_MAX,
  "a temperature past what the scaled wire can carry is clamped, not wrapped")
equal(C.signals({ temperature_c = 15, q_factor = 1e9 }).q, INT32_MAX,
  "a Q past int32 is clamped, not wrapped")
equal(C.signals({ temperature_c = -WIRE_CEILING_C * 2, q_factor = 0 }).temperature, INT32_MIN,
  "a negative past it is clamped too")

-- NaN reaches here whenever a ratio's denominator is zero, and the engine THROWS on a bad signal
-- write rather than wrapping -- so an unhandled NaN is a crash in front of a player, not a wrong
-- reading. Reported as nothing instead.
local NAN = 0 / 0
check(NAN ~= NAN, "the test's own NaN is a NaN")
equal(C.signals({ temperature_c = NAN, q_factor = 0 }).temperature, 0,
  "a NaN temperature is reported as zero rather than thrown")
equal(C.signals({ temperature_c = 15, q_factor = NAN }).q, 0,
  "and so is a NaN Q")

-- ROUND TRIP AT THE SHIPPED CEILING (ADR 0025: 5e9). Written for #57, when this was the ceiling
-- #58 was going to set and the specs still declared 2e9 -- the encoding had to make 5e9 carryable
-- before the ticket that relied on it could land. **#58 has since set it**, so the specs declare
-- 5e9 too and this is no longer a forward assertion; it is the shipped value, checked from the
-- other side of the module boundary.
local NEXT_CEILING_C = 5e9
equal(C.signals({ temperature_c = NEXT_CEILING_C, q_factor = 0 }).temperature, 5000000,
  "the ceiling ADR 0025 chose survives the trip to a signal without saturating")
equal(C.signals({ temperature_c = NEXT_CEILING_C, q_factor = 0 }).temperature * SCALE, NEXT_CEILING_C,
  "and back again, which is what makes the number on the wire a temperature")
check(C.signals({ temperature_c = NEXT_CEILING_C, q_factor = 0 }).temperature < INT32_MAX,
  "with the wire nowhere near its own limit",
  string.format("%d against %d", C.signals({ temperature_c = NEXT_CEILING_C }).temperature, INT32_MAX))
equal(C.signals({ temperature_c = NEXT_CEILING_C + SCALE, q_factor = 0 }).temperature, 5000001,
  "one scale-step past it is still reported rather than wrapped")

-- ~~The reason the clamp is not merely defensive: the shipped fluid's ceiling is 2e9 C, which fits
-- with about 7% to spare.~~ **Three orders of magnitude to spare since #57**, not 7% -- the wire
-- carries WIRE_CEILING_C, computed above, and 2e9 is nowhere near it. The headroom is still
-- asserted rather than assumed, because a later tier can still raise max_temperature past what the
-- scale carries; it is simply a long way further off than it was.
--
-- OVER EVERY SHIPPED REACTOR SINCE #55, where it read the neutronic spec alone. The ceiling lives
-- on the spec, so a second reactor can declare its own -- and the one that would break the readout
-- is whichever spec someone raised without thinking about the wire.
--
-- THE LIST IS COUNTED BEFORE IT IS WALKED, because a table literal keyed on module fields can
-- shrink without anyone noticing: rename M.aneutronic_reactor and `pairs` simply yields one entry,
-- so this would report a clean pass over a reactor it never looked at. That is the same silent
-- switch-off reactor-logic's confinement guard raises over, and it is cheaper to catch here.
local CEILINGS = { ["rf-reactor"] = SPEC, ["rf-aneutronic-reactor"] = L.aneutronic_reactor }
local ceiling_count = 0
for _, spec in pairs(CEILINGS) do
  if spec then ceiling_count = ceiling_count + 1 end
end
equal(ceiling_count, 2, "both shipped reactors are present to be checked")

-- THE SCALE IS ASSERTED AGAINST THE CEILING, which is the pairing that must not drift: the wire
-- can carry INT32_MAX * SCALE degrees, and every spec's ceiling has to sit under that. Change the
-- scale without checking the ceilings, or raise a ceiling without checking the scale, and this is
-- what notices. It is the same comparison check_signal_ceiling refuses to load over.
for label, spec in pairs(CEILINGS) do
  check(spec.max_temperature_c <= WIRE_CEILING_C,
    label .. "'s maximum plasma temperature fits on a wire at this scale",
    string.format("%.6g C against %.6g C carryable (%d x %d)",
      spec.max_temperature_c, WIRE_CEILING_C, INT32_MAX, SCALE))
end

check(NEXT_CEILING_C <= WIRE_CEILING_C,
  "and so does the ceiling #58 set, which is why this had to come first",
  string.format("%.6g C against %.6g C carryable", NEXT_CEILING_C, WIRE_CEILING_C))

-- THE DECISION control.lua's check_signal_ceiling MAKES, and the negative half of it. That guard
-- refuses to load a ceiling a wire cannot carry; the comparison lives in circuit-output so it can
-- be broken here, because a guard nobody has watched fail is a guard nobody knows the shape of.
--
-- Note what the failing case RETURNS: not `true`, but the number a player would actually be shown
-- instead. That is what the refusal message quotes, and it is the difference between "this is too
-- big" and "every reactor would read 2147483647 C for ever".
-- IT ASKS THE QUESTION AT THE SCALE SINCE #57, and that is the whole substance of this ticket's
-- change to the guard. It used to compare raw celsius against INT32_MAX; had the scale changed
-- underneath it, a 5e9 ceiling would have failed 5e9 > 2147483647 and REFUSED TO LOAD -- the mod
-- broken by its own new ceiling. It divides first now.
check(C.unrepresentable(SPEC.max_temperature_c) == nil,
  "the shipped ceiling is representable, so the load guard passes",
  string.format("%.6g C", SPEC.max_temperature_c))
check(C.unrepresentable(NEXT_CEILING_C) == nil,
  "and so is the one #58 set -- the guard permits the raised ceiling",
  string.format("%.6g C", NEXT_CEILING_C))
equal(C.unrepresentable(WIRE_CEILING_C), nil,
  "a ceiling exactly at what the wire can carry still fits -- the clamp keeps that value")
equal(C.unrepresentable(WIRE_CEILING_C + SCALE), INT32_MAX,
  "one scale-step past it does not, and the guard is told what a wire would show instead")
equal(C.unrepresentable(6.9e9), nil,
  "#54's proposed 6.9e9 ceiling is carryable now, which is what #57 was for")

-- ---------------------------------------------------------------- status

-- Three states, which is what a player needs to tell apart: it is working, it is sitting there, or
-- it has nothing to work with. The diode is a name here rather than a defines value so that this
-- file runs outside Factorio; publish() maps it.
--
-- The threshold is half a percent of the reactor's RATED heating, so the spec goes in too.
local function status_of(result, plasma_amount)
  return C.status(result, plasma_amount, SPEC)
end

local RATED = SPEC.heating_power_w
local running = { temperature_c = 6e8, q_factor = 1.4, fusion_power_w = 7e7 }
local cold    = { temperature_c = 15,  q_factor = 0,   fusion_power_w = 0 }

equal(status_of(running, 1000).key, "running", "a fusing reactor reports running")
equal(status_of(running, 1000).diode, "green", "running shows a green diode")

equal(status_of(cold, 1000).key, "idle", "a reactor holding plasma but not fusing reports idle")
equal(status_of(cold, 1000).diode, "yellow", "idle shows a yellow diode")

equal(status_of(nil, 0).key, "starved", "a reactor with no plasma reports starved")
equal(status_of(nil, 0).diode, "red", "starved shows a red diode")
equal(status_of(nil, nil).key, "starved", "no plasma at all is starved, not an error")

-- The boundary is fusion actually happening, not temperature. A reactor can be hot and not fusing
-- on the way down, and calling that "running" would be a lie the player would act on.
equal(status_of({ temperature_c = 6e8, q_factor = 0, fusion_power_w = 0 }, 1000).key, "idle",
  "hot but not fusing is idle, not running")

-- Why the threshold is not "any fusion at all". Fusion power is never exactly zero: the reactivity
-- at 15 C is about 1e-70 and there are 1e23 particles, so a "> 0" test called a stone-cold reactor
-- "Fusing". This suite originally missed it by feeding status() a clean 0, which never happens.
equal(status_of({ temperature_c = 15, q_factor = 1e-60, fusion_power_w = 1e-55 }, 1000).key, "idle",
  "a stone-cold reactor with denormal fusion is idle, not running")
equal(status_of({ temperature_c = 6.3e6, q_factor = 0.004, fusion_power_w = RATED * 0.004 }, 1000).key,
  "idle", "fusion below half a percent of rated heating is still idle")
equal(status_of({ temperature_c = 3e7, q_factor = 0.005, fusion_power_w = RATED * 0.005 }, 1000).key,
  "running", "half a percent of rated heating is where running starts")

-- And why the threshold is not the Q signal either, which was the second wrong answer. q_factor is
-- 0 whenever heating power is 0 -- deliberately, since a reactor that is off is not infinitely
-- efficient -- so a hot reactor that has LOST POWER is still fusing and still filling its output
-- pipe while its Q reads zero. Reporting that as "not fusing" is wrong at exactly the moment a
-- player is trying to diagnose it.
local browned_out = { temperature_c = 8e8, q_factor = 0, fusion_power_w = 1.3e8 }
equal(status_of(browned_out, 1000).key, "running",
  "a fusing reactor that has lost power still reports running")
equal(C.signals(browned_out).q, 0, "its Q signal is nonetheless zero, because Q has no denominator")

-- Without a spec there is no scale to judge against, so nothing is claimed to be running. That is
-- the safe direction: silence rather than a false positive.
equal(C.status(running, 1000, nil).key, "idle", "with no spec, running is never claimed")

-- A reactor that is fusing while its plasma runs out is still running: it is doing the thing.
-- Starved is about having nothing, not about having little.
equal(status_of(running, 0.5).key, "running", "a nearly-empty but fusing reactor is running")

-- ---------------------------------------------------------------- locale keys
--
-- Every status has to name a key that exists, or the player sees "Unknown key" in the one place
-- this ticket exists to make readable. scripts/locale-check.ps1 does not cover these -- it checks
-- prototype names against a dump, and these are runtime strings assembled in Lua -- so the file is
-- read here and the keys are looked up in it.

local locale = {}
do
  local handle = io.open("realistic-fusion-refreshed/locale/en/observability.cfg", "r")
  check(handle ~= nil, "the observability locale file exists")
  if handle then
    local section
    for line in handle:lines() do
      local heading = line:match("^%[(.-)%]%s*$")
      if heading then
        section = heading
      else
        local key = line:match("^([%w_-]+)=")
        if key and section then locale[section .. "." .. key] = true end
      end
    end
    handle:close()
  end
end

local seen_states = {}
for _, case in ipairs({ { running, 1000 }, { cold, 1000 }, { nil, 0 } }) do
  local status = status_of(case[1], case[2])
  seen_states[status.key] = true
  check(locale[C.LOCALE_PREFIX .. status.key] == true,
    "the status key resolves to a locale entry",
    C.LOCALE_PREFIX .. status.key)
end

-- All three, not just the ones these three cases happen to hit.
for _, key in ipairs({ "running", "idle", "starved" }) do
  check(locale[C.LOCALE_PREFIX .. key] == true, "every status key is in the locale file", key)
  check(seen_states[key] == true, "every status key is actually reachable", key)
end

-- Both signal names are localised too, and they are the names circuit-output writes.
for _, name in ipairs({ "rf-signal-plasma-temperature", "rf-signal-q-factor" }) do
  check(locale["virtual-signal-name." .. name] == true, "the signal is localised", name)
end

-- ---------------------------------------------------------------- against a real step
--
-- The signals have to survive what the simulation actually produces, not just hand-written values.
-- One cold start, run to the point the reactor is fusing, straight into signals().
local state = { temperature = 15, amount = 1000 }
local result
for _ = 1, 60 * 600 do
  result = L.step(SPEC, "rf-d-d-plasma", state.amount, state.temperature, math.huge, 1 / 60)
  state.temperature = result.temperature_c
end

local signals = C.signals(result)
check(signals.temperature > 0 and signals.temperature <= INT32_MAX,
  "a real reactor's temperature is a legal signal", tostring(signals.temperature))
check(signals.q > 0 and signals.q <= INT32_MAX,
  "a real reactor's Q is a legal signal", tostring(signals.q))
check(signals.temperature == math.floor(signals.temperature),
  "a real reactor's temperature is an integer", tostring(signals.temperature))
check(signals.q == math.floor(signals.q), "a real reactor's Q is an integer", tostring(signals.q))
equal(status_of(result, 1000).key, "running", "a settled reactor reports running")

-- ----------------------------------------------------------------

H.finish()
