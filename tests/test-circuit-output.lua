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

-- Temperature is emitted in whole degrees, which is the only scale that both fits int32 and reads
-- naturally on a combinator.
equal(C.signals({ temperature_c = 6.0e8, q_factor = 1.4 }).temperature, 600000000,
  "temperature is emitted in whole degrees")
equal(C.signals({ temperature_c = 15, q_factor = 0 }).temperature, 15,
  "a cold reactor reports its floor temperature")
equal(C.signals({ temperature_c = 877079999.6, q_factor = 0 }).temperature, 877080000,
  "temperature rounds rather than truncates")

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

equal(C.signals({ temperature_c = 1e12, q_factor = 0 }).temperature, INT32_MAX,
  "a temperature past int32 is clamped, not wrapped")
equal(C.signals({ temperature_c = 15, q_factor = 1e9 }).q, INT32_MAX,
  "a Q past int32 is clamped, not wrapped")
equal(C.signals({ temperature_c = -1e12, q_factor = 0 }).temperature, INT32_MIN,
  "a negative past int32 is clamped too")

-- The reason the clamp is not merely defensive: the shipped fluid's ceiling is 2e9 C, which fits
-- with about 7% to spare. Any later tier raising max_temperature past int32 starts losing the top
-- of the range silently, so the headroom is asserted here rather than assumed.
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

for label, spec in pairs(CEILINGS) do
  check(spec.max_temperature_c <= INT32_MAX,
    label .. "'s maximum plasma temperature fits in a circuit signal",
    string.format("%.6g C against int32 max %d", spec.max_temperature_c, INT32_MAX))
end

-- THE DECISION control.lua's check_signal_ceiling MAKES, and the negative half of it. That guard
-- refuses to load a ceiling a wire cannot carry; the comparison lives in circuit-output so it can
-- be broken here, because a guard nobody has watched fail is a guard nobody knows the shape of.
--
-- Note what the failing case RETURNS: not `true`, but the number a player would actually be shown
-- instead. That is what the refusal message quotes, and it is the difference between "this is too
-- big" and "every reactor would read 2147483647 C for ever".
check(C.unrepresentable(SPEC.max_temperature_c) == nil,
  "the shipped ceiling is representable, so the load guard passes",
  string.format("%.6g C", SPEC.max_temperature_c))
equal(C.unrepresentable(INT32_MAX), nil,
  "a ceiling exactly at the int32 maximum still fits -- the clamp keeps that value")
equal(C.unrepresentable(INT32_MAX + 1), INT32_MAX,
  "one degree past it does not, and the guard is told what a wire would show instead")
equal(C.unrepresentable(6.9e9), INT32_MAX,
  "nor does #54's proposed 6.9e9 ceiling, which is the case this guard exists for")

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
