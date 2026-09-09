-- Tests for what a reactor reports: the three circuit signals and the status it shows.
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

-- ---------------------------------------------------------------- blanket share (#95, ADR 0019)
--
-- A SHARE OF THE TOTAL, not an uplift over a bare reactor. Both describe the same machine and the
-- share is the one whose denominator a player can read off the fluid box; the uplift is recoverable
-- from it as share / (1 - share), which is why only one of them is on the wire. The examples below
-- are the same reactor read both ways, so the relationship is asserted rather than described.
--
-- A PERCENTAGE AND THEREFORE AN INTEGER, like Q. A signal is an int32 and Factorio throws rather
-- than wrapping on a bad write, so every case here is checked for being a whole number as well as
-- for its value -- including the ones that come out of a division that has no reason to be exact.
local function share(reactor_units, blanket_units)
  return C.signals({ temperature_c = 6.0e8, q_factor = 1.4, energy_units = reactor_units },
    blanket_units).blanket_share
end

equal(share(100, 0), 0, "a reactor with no blanket reports a share of zero")
equal(share(100, nil), 0, "and so does one whose blanket is simply not passed")
equal(share(75, 25), 25, "a quarter of the total reads 25")
equal(share(50, 50), 50, "half and half reads 50")
equal(share(0, 40), 100, "and a reactor selling nothing of its own reads 100, which is the ceiling")

-- THE SHIPPED MEASUREMENT, from #93's rig: a blanketed D-T reactor sells 28.0% more than the same
-- reactor without one. That is an UPLIFT, so as a share it is 0.280 / 1.280 = 21.9% -- the two
-- readings of one machine, and the reason the signal states which it carries.
equal(share(1.0, 0.280), 22,
  "the shipped +28.0% uplift reads as a share of 22, which is the same machine described twice")

-- BOUNDED BY CONSTRUCTION rather than by a clamp, which is the whole of why the share was chosen
-- over the uplift. There is no input to signals() that puts this outside 0..100 while both terms
-- are non-negative, and a blanket cannot sell negative joules.
equal(share(1e-9, 1e9), 100, "an extreme ratio still lands on the ceiling rather than past it")
equal(share(1e9, 1e-9), 0, "and the other way round lands on the floor")

-- ZERO RATHER THAN UNDEFINED at a zero denominator, inherited from reactivity.q_factor which makes
-- the same choice for the same reason. An idle reactor is not "infinitely blanket-fed".
equal(share(0, 0), 0, "a reactor selling nothing at all reports zero rather than a NaN")
equal(C.signals(nil, 40).blanket_share, 0,
  "and a reactor with nothing to simulate reports zero however much its blanket last sold")
equal(C.signals({ temperature_c = 15, q_factor = 0 }).blanket_share, 0,
  "an idle reactor reports zero, which is ADR 0019's stated reading")

-- ROUNDING, stated because the signal is an integer and a share is not. to_signal rounds to
-- nearest, so a third reads 33 and two thirds read 67 rather than both truncating downward.
equal(share(2, 1), 33, "a third rounds down to 33")
equal(share(1, 2), 67, "and two thirds round up to 67")
for _, case in ipairs({ { 3, 7 }, { 1, 3 }, { 999, 1 }, { 1, 999 } }) do
  local value = share(case[1], case[2])
  check(value == math.floor(value) and value >= 0 and value <= 100,
    string.format("a share of %g against %g is a whole number in 0..100", case[2], case[1]),
    tostring(value))
end

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

-- Five states since #74. Three of them are the same question a player always had -- it is working,
-- it is sitting there, or it has nothing to work with -- and the other two are the density lever
-- ADR 0016 accepted and nothing told a player about: lean and rich say which way to move the
-- throttle.
--
-- The threshold between idle and fusing is half a percent of the reactor's RATED heating, so the
-- spec goes in. The three density states need the curve as well; without one they collapse back to
-- "running", which is the case asserted at the bottom of this block.
local CURVE = L.density_curve(SPEC, "rf-d-d-plasma", SPEC.box_volume)
check(CURVE ~= nil, "the shipped reactor has a density curve to judge fills against")

local function status_of(result, fill)
  return C.status(result, fill, SPEC, CURVE)
end

local RATED = SPEC.heating_power_w
local running = { temperature_c = 6e8, q_factor = 1.4, fusion_power_w = 7e7 }
local cold    = { temperature_c = 15,  q_factor = 0,   fusion_power_w = 0 }

-- THE CURVE IS ADR 0016'S TABLE, checked here from the other side of the module boundary before
-- anything is judged against it. That ADR measures the shipped tier's optimum at about 65% fill and
-- says the n-squared term wins again "below about 35% fill", where a thinned reactor is worse off
-- than a full one. Those are the two numbers every case below turns on, so a curve that had drifted
-- off them would make the rest of this block assert the wrong thing while still passing.
equal(CURVE.optimum, 0.65, "the shipped reactor's best density is ADR 0016's ~65% fill")
equal(CURVE.floor, 0.35, "and it stops being worth thinning at ADR 0016's ~35%")
check(CURVE.step > 0, "the curve carries the grid step its answers are resolved to")

equal(status_of(running, CURVE.optimum).key, "running",
  "a reactor fusing at its best density reports running")
equal(status_of(running, CURVE.optimum).diode, "green", "running shows a green diode")

equal(status_of(cold, 1.0).key, "idle", "a reactor holding plasma but not fusing reports idle")
equal(status_of(cold, 1.0).diode, "yellow", "idle shows a yellow diode")

equal(status_of(nil, 0).key, "starved", "a reactor with no plasma reports starved")
equal(status_of(nil, 0).diode, "red", "starved shows a red diode")
equal(status_of(nil, nil).key, "starved", "no plasma at all is starved, not an error")

-- ---------------------------------------------------------------- the density states (#74)
--
-- THE WHOLE POINT OF THE TICKET, in three assertions: a reactor held at its best density is not a
-- fault, a full one is told it could do better by thinning, and a thin one is told to add plasma.
-- Before this, all three said "Fusing" and the mechanic was discoverable only by wiring a
-- combinator and experimenting.
equal(status_of(running, 1.0).key, "rich",
  "a FULL reactor at the shipped tier is rich -- less plasma would raise its output")
equal(status_of(running, 1.0).diode, "green", "rich is not a fault, so its diode stays green")
equal(status_of(running, CURVE.floor + CURVE.step).key, "lean",
  "a reactor thinner than its optimum but above the floor is lean")
equal(status_of(running, CURVE.floor + CURVE.step).diode, "green", "and lean is not a fault either")

-- The band that counts as "at the optimum" is one step of the sweep's own grid, so it is the
-- resolution of the answer rather than a tolerance invented here.
equal(status_of(running, CURVE.optimum - CURVE.step).key, "running",
  "one grid step under the optimum still counts as at it")
equal(status_of(running, CURVE.optimum + CURVE.step).key, "running", "and one step over")
equal(status_of(running, CURVE.optimum - CURVE.step * 1.5).key, "lean",
  "a step and a half under is lean")
equal(status_of(running, CURVE.optimum + CURVE.step * 1.5).key, "rich", "and over is rich")

-- ---------------------------------------------------------------- what "starved" means now (#74)
--
-- CONTEXT.md separates two words that used to be one: under-supplied is held below full on purpose
-- and may be the BEST state a reactor can be in; starved is held below the density at which it is
-- worth running at all. The line is the curve's floor -- the thinnest fill still worth as much as
-- a full reactor -- so it is measured per confinement rung rather than written down.
check(status_of(running, CURVE.floor).key ~= "starved",
  "a reactor exactly on the floor is not starved -- it is still worth as much as a full one",
  status_of(running, CURVE.floor).key)
equal(status_of(running, CURVE.floor / 2).key, "starved",
  "half the floor is starved: thinned past where the reactor would be better off simply filled")
equal(status_of(running, CURVE.floor / 2).diode, "red", "and that is a fault, so the diode is red")

-- Asked BEFORE the fusion threshold, which is the ordering that makes the state mean anything: a
-- reactor below the floor is in that fault whether it is hot or cold, and "idle" would report a
-- cold start it is never going to come out of.
equal(status_of(cold, CURVE.floor / 2).key, "starved",
  "a COLD reactor below the floor is starved, not idle -- the fault is the density, not the heat")

-- ---------------------------------------------------------------- the starved latch
--
-- THE FLOOR IS THE ONE LINE HERE THAT CHANGES THE DIODE AND STOPS THE MOVING CORE, and it is a line
-- a player is invited to sit near: "lean" tells them to add plasma, so a run tuned just above the
-- floor is the expected outcome and not a corner. Heaters deliver in batches, so a bare threshold
-- would have the segment cross it back and forth and every report would flip the building between a
-- green "more plasma would raise output" and a red "starved", with the core starting and stopping.
--
-- So the reactor climbs a whole grid step clear of the floor to STOP being starved, where it only
-- falls below the floor to BECOME starved. Driven here through the argument rather than through
-- storage, which is what keeps the decision testable outside Factorio at all.
local JUST_OVER = CURVE.floor + CURVE.step / 2

equal(C.status(running, JUST_OVER, SPEC, CURVE, "lean").key, "lean",
  "a reactor a half-step above the floor and not previously starved is lean")
equal(C.status(running, JUST_OVER, SPEC, CURVE, "starved").key, "starved",
  "the SAME fill reads starved if it was starved a moment ago -- the latch is what stops the flicker")
equal(C.status(running, CURVE.floor + CURVE.step, SPEC, CURVE, "starved").key, "lean",
  "and a whole grid step clear of the floor releases it")
equal(C.status(running, CURVE.floor - 1e-9, SPEC, CURVE, "lean").key, "starved",
  "falling below the floor still takes only the floor, so the fault is never slow to appear")

-- The latch reaches no state but this one. A reactor at its optimum does not become starved because
-- it once was, which is the failure mode a latch invites.
equal(C.status(running, CURVE.optimum, SPEC, CURVE, "starved").key, "running",
  "the latch does not follow a reactor back up to its optimum")
equal(C.status(running, 1.0, SPEC, CURVE, "starved").key, "rich", "nor to a full one")

-- And it needs a curve, like every other density claim: with none, nothing latches either.
equal(C.status(running, 0.01, SPEC, nil, "starved").key, "running",
  "with no curve there is no floor to latch against")

-- THE LEVER CLOSES AS RESEARCH RAISES CONFINEMENT TIME, which is the property #74 asks the status
-- line to keep. ADR 0016 measures the optimum walking up the fill axis and leaving the range by
-- tau 70 s, at which point full supply is simply best -- so the SAME full reactor that reads "rich"
-- at the shipped 30 s must read "running" once a player has researched their way up.
local RESEARCHED = {}
for k, v in pairs(SPEC) do RESEARCHED[k] = v end
RESEARCHED.confinement_time_s = 70
local TOP_CURVE = L.density_curve(RESEARCHED, "rf-d-d-plasma", RESEARCHED.box_volume)
equal(TOP_CURVE.optimum, 1.0, "by tau 70 s the best density is full supply, as ADR 0016 measured")
equal(C.status(running, 1.0, RESEARCHED, TOP_CURVE).key, "running",
  "so a full reactor there is at its optimum rather than rich")
equal(C.status(running, CURVE.optimum, RESEARCHED, TOP_CURVE).key, "lean",
  "and the 65% a player tuned to at 30 s is now merely lean")

-- AND WITH NO INTERIOR PEAK THERE IS NO FLOOR. Every fill under full is worth less than a full one
-- there, so "worse than full" would condemn a reactor at 95% as starved. It is not a trap -- adding
-- plasma helps all the way up, which is what "lean" says -- so the floor drops out and starved goes
-- back to meaning no plasma at all.
equal(TOP_CURVE.floor, 0, "with the optimum at full supply there is no starved band")
equal(C.status(running, 0.05, RESEARCHED, TOP_CURVE).key, "lean",
  "a nearly-empty reactor at the top rung is lean, not starved: filling it helps monotonically")

-- ---------------------------------------------------------------- the idle boundary

-- The boundary is fusion actually happening, not temperature. A reactor can be hot and not fusing
-- on the way down, and calling that "running" would be a lie the player would act on.
equal(status_of({ temperature_c = 6e8, q_factor = 0, fusion_power_w = 0 }, 1.0).key, "idle",
  "hot but not fusing is idle, not running")

-- Why the threshold is not "any fusion at all". Fusion power is never exactly zero: the reactivity
-- at 15 C is about 1e-70 and there are 1e23 particles, so a "> 0" test called a stone-cold reactor
-- "Fusing". This suite originally missed it by feeding status() a clean 0, which never happens.
equal(status_of({ temperature_c = 15, q_factor = 1e-60, fusion_power_w = 1e-55 }, 1.0).key, "idle",
  "a stone-cold reactor with denormal fusion is idle, not running")
equal(status_of({ temperature_c = 6.3e6, q_factor = 0.004, fusion_power_w = RATED * 0.004 }, 1.0).key,
  "idle", "fusion below half a percent of rated heating is still idle")
equal(status_of({ temperature_c = 3e7, q_factor = 0.005, fusion_power_w = RATED * 0.005 }, 1.0).key,
  "rich", "half a percent of rated heating is where fusing starts -- rich, because the box is full")

-- And why the threshold is not the Q signal either, which was the second wrong answer. q_factor is
-- 0 whenever heating power is 0 -- deliberately, since a reactor that is off is not infinitely
-- efficient -- so a hot reactor that has LOST POWER is still fusing and still filling its output
-- pipe while its Q reads zero. Reporting that as "not fusing" is wrong at exactly the moment a
-- player is trying to diagnose it.
local browned_out = { temperature_c = 8e8, q_factor = 0, fusion_power_w = 1.3e8 }
check(C.FUSING[status_of(browned_out, CURVE.optimum).key] == true,
  "a fusing reactor that has lost power is still in a fusing state",
  status_of(browned_out, CURVE.optimum).key)
equal(C.signals(browned_out).q, 0, "its Q signal is nonetheless zero, because Q has no denominator")

-- Without a spec there is no scale to judge against, so nothing is claimed to be fusing. That is
-- the safe direction: silence rather than a false positive.
equal(C.status(running, 1.0, nil, CURVE).key, "idle", "with no spec, fusing is never claimed")

-- AND WITHOUT A CURVE the three density states collapse to "running" rather than being guessed at.
-- That is the state a reactor holding a plasma nobody has swept is in.
equal(C.status(running, 1.0, SPEC, nil).key, "running", "with no curve, no density claim is made")
equal(C.status(running, 0.01, SPEC, nil).key, "running",
  "not even about a nearly-empty one -- starved needs a floor to be measured against")
equal(C.status(nil, 0, SPEC, nil).key, "starved", "but no plasma at all is still starved")

-- A reactor that is fusing while its plasma runs out is doing the thing, and this is the case #74
-- changed the answer to: it used to be "running", because starved meant an empty box. It now means
-- a density not worth running, and a hair of plasma is exactly that.
equal(status_of(running, 0.0005).key, "starved",
  "a nearly-empty reactor is starved even while it fuses -- there is no operating point down there")

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
for _, case in ipairs({
  { running, CURVE.optimum }, { running, 1.0 }, { running, CURVE.floor + CURVE.step },
  { cold, 1.0 }, { nil, 0 },
}) do
  local status = status_of(case[1], case[2])
  seen_states[status.key] = true
  check(locale[C.LOCALE_PREFIX .. status.key] == true,
    "the status key resolves to a locale entry",
    C.LOCALE_PREFIX .. status.key)
end

-- All five, not just the ones these cases happen to hit.
for _, key in ipairs({ "running", "lean", "rich", "idle", "starved" }) do
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
local state = { temperature = 15, amount = SPEC.box_volume }
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
check(C.FUSING[status_of(result, 1.0).key] == true,
  "a settled reactor is in a fusing state", status_of(result, 1.0).key)

-- ----------------------------------------------------------------

H.finish()
