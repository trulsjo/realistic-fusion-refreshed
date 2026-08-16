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

package.path = "RealisticFusion/?.lua;" .. package.path
local C = require("scripts.circuit-output")
local L = require("scripts.reactor-logic")

local failures, checks = 0, 0

local function check(ok, name, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  -- " .. detail) or ""))
  end
end

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

local INT32_MAX = 2147483647
local INT32_MIN = -2147483648

equal(C.signals({ temperature_c = 1e12, q_factor = 0 }).temperature, INT32_MAX,
  "a temperature past int32 is clamped, not wrapped")
equal(C.signals({ temperature_c = 15, q_factor = 1e9 }).q, INT32_MAX,
  "a Q past int32 is clamped, not wrapped")
equal(C.signals({ temperature_c = -1e12, q_factor = 0 }).temperature, INT32_MIN,
  "a negative past int32 is clamped too")

-- The reason the clamp is not merely defensive: the shipped fluid's ceiling is 2e9 C, which fits
-- with about 7% to spare. Any later tier raising max_temperature past int32 starts losing the top
-- of the range silently, so the headroom is asserted here rather than assumed.
check(SPEC.max_temperature_c <= INT32_MAX,
  "the shipped plasma's maximum temperature fits in a circuit signal",
  string.format("%.6g C against int32 max %d", SPEC.max_temperature_c, INT32_MAX))

-- ---------------------------------------------------------------- status

-- Three states, which is what a player needs to tell apart: it is working, it is sitting there, or
-- it has nothing to work with. The diode is a name here rather than a defines value so that this
-- file runs outside Factorio; publish() maps it.
local function status_of(result, plasma_amount)
  return C.status(result, plasma_amount)
end

local running = { temperature_c = 6e8, q_factor = 1.4, fusion_power_w = 7e7 }
local cold    = { temperature_c = 15,  q_factor = 0,   fusion_power_w = 0 }

equal(status_of(running, 1000).key, "running", "a fusing reactor reports running")
equal(status_of(running, 1000).diode, "green", "running shows a green diode")

equal(status_of(cold, 1000).key, "idle", "a reactor holding plasma but not fusing reports idle")
equal(status_of(cold, 1000).diode, "yellow", "idle shows a yellow diode")

equal(status_of(nil, 0).key, "starved", "a reactor with no plasma reports starved")
equal(status_of(nil, 0).diode, "red", "starved shows a red diode")
equal(status_of(nil, nil).key, "starved", "no plasma at all is starved, not an error")

-- The boundary between idle and running is fusion actually happening, not temperature. A reactor
-- can be hot and not fusing on the way down, and calling that "running" would be a lie the player
-- would act on.
equal(status_of({ temperature_c = 6e8, q_factor = 0, fusion_power_w = 0 }, 1000).key, "idle",
  "hot but not fusing is idle, not running")

-- Where the boundary actually sits, and why it is not "any fusion at all". These three cases are
-- the ones this suite originally got wrong: it fed status() a clean q_factor of 0, which never
-- happens. In a running game the reactivity at 15 C is about 1e-70 and there are 1e23 particles,
-- so fusion power is a tiny positive number and a "> 0" test called a stone-cold reactor "Fusing".
-- Caught by tests/../probe in a live game, fixed here.
equal(status_of({ temperature_c = 15, q_factor = 1e-60, fusion_power_w = 1e-55 }, 1000).key, "idle",
  "a stone-cold reactor with denormal fusion is idle, not running")
equal(status_of({ temperature_c = 6.3e6, q_factor = 0.004, fusion_power_w = 2e5 }, 1000).key, "idle",
  "fusion below half a percent of heating is still idle")
equal(status_of({ temperature_c = 3e7, q_factor = 0.005, fusion_power_w = 2.5e5 }, 1000).key, "running",
  "half a percent is where running starts")

-- The property the threshold exists to give: status and signal never contradict each other.
for _, q in ipairs({ 0, 1e-60, 0.004, 0.005, 0.5, 1, 2.1, 40 }) do
  local result = { temperature_c = 1e8, q_factor = q, fusion_power_w = q * 5e7 }
  local says_running = status_of(result, 1000).key == "running"
  local shows_q = C.signals(result).q > 0
  check(says_running == shows_q,
    "status and Q signal agree",
    string.format("q_factor %.3g: running=%s, signal=%d", q, tostring(says_running), C.signals(result).q))
end

-- A reactor that is fusing while its plasma runs out is still running: it is doing the thing.
-- Starved is about having nothing, not about having little.
equal(status_of(running, 0.5).key, "running", "a nearly-empty but fusing reactor is running")

-- ---------------------------------------------------------------- locale keys
--
-- Every status has to name a key that exists, or the player sees "Unknown key" in the one place
-- this ticket exists to make readable. The keys are asserted against the module rather than
-- retyped, and scripts/locale-check.ps1 does not cover these -- it checks prototype names, and
-- these are runtime strings.
for _, case in ipairs({ { running, 1000 }, { cold, 1000 }, { nil, 0 } }) do
  local status = status_of(case[1], case[2])
  check(type(status.key) == "string" and status.key ~= "", "every status has a key")
  check(C.LOCALE_PREFIX and C.LOCALE_PREFIX:match("^[%w-]+%.$") ~= nil,
    "the locale prefix is a section followed by a dot",
    tostring(C.LOCALE_PREFIX))
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

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
print("OK")
