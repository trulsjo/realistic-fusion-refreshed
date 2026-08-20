-- The assertion helpers every suite in this directory shares (#42).
--
-- There is no test framework here on purpose (ADR 0005): the modules under test touch no Factorio
-- API, so a suite is a Lua script that runs top to bottom and exits non-zero if anything failed.
-- What was NOT on purpose is that each suite carried its own byte-identical copy of the helpers
-- below -- and the tests are the only thing standing behind the physics, so two copies of `near`
-- is two places for a tolerance to quietly differ.
--
-- Written to Lua 5.2 semantics (what Factorio 2.0.77 runs) and verified on 5.4, like the suites.
--
-- Usage, from a suite:
--
--     package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
--     local H = require("harness")
--     local check, near = H.check, H.near
--     ...
--     H.finish()
--
-- A suite wanting different semantics keeps its own helper, built on H.check so the counters stay
-- shared -- and gives it a DIFFERENT name. tests/test-bremsstrahlung.lua's near_pct is the example:
-- it takes three arguments where H.near takes four, and had it kept the name `near`, anyone who
-- deleted it as a duplicate would have rebound fourteen calls to pass a name where a tolerance goes.

local H = { checks = 0, failures = 0 }

-- The primitive. Everything else here, and the bespoke variants the suites keep for themselves,
-- goes through this one so the counters cannot disagree with what was printed.
--
-- `detail` is the observed value, printed only on a failure: a passing suite should say nothing
-- but its final count, and a failing one should say enough to place the fault without a rerun.
function H.check(ok, name, detail)
  H.checks = H.checks + 1
  if not ok then
    H.failures = H.failures + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  -- " .. detail) or ""))
  end
end

-- Relative tolerance, except against zero where relative has no meaning and the tolerance is read
-- as absolute. Both suites that compare floats want exactly this, and a tolerance of 0 is a legal
-- and used argument -- an interpolation at a tabulated point must be exact.
function H.near(actual, expected, tolerance, name)
  local ok
  if expected == 0 then
    ok = math.abs(actual) <= tolerance
  else
    ok = math.abs(actual - expected) / math.abs(expected) <= tolerance
  end
  H.check(ok, name, string.format("got %.6g, expected %.6g", actual, expected))
end

-- The epilogue. The count is printed on a pass as well as a failure because it is the only signal
-- that the suite ran the checks it was meant to: "OK" alone reads the same whether 147 checks ran
-- or a require failed silently and two did.
function H.finish()
  print(string.format("%d checks, %d failures", H.checks, H.failures))
  if H.failures > 0 then os.exit(1) end
  print("OK")
end

-- Run this file directly -- `lua tests/harness.lua` -- and it checks itself.
--
-- Worth the fifteen lines because the failure this guards against is invisible to every other
-- check there is: a harness that counted but never failed would let all four suites report exactly
-- the check counts they always reported, and pass. So the failing half matters more than the
-- passing half. Output is captured rather than printed, or the deliberate failures below would
-- read as real ones.
--
-- `...` is nil when a file is run as a script and the module name when it is required, which is
-- what keeps this out of the suites' way.
if ... == nil then
  local said, real_print = {}, print
  print = function(line) said[#said + 1] = line end
  H.check(true, "a passing check says nothing")
  H.near(1.001, 1, 0.01, "inside tolerance")
  H.near(0, 0, 0, "zero against zero, absolute")
  local quiet = H.checks == 3 and H.failures == 0 and #said == 0
  H.check(false, "a failing check is counted and printed")
  H.near(2, 1, 0.01, "outside tolerance")
  H.near(1e-9, 0, 0, "not zero, against a zero tolerance")
  local loud = H.checks == 6 and H.failures == 3 and #said == 3
  print = real_print
  if quiet and loud then
    print("harness OK")
  else
    print(string.format("harness BROKEN: %d checks, %d failures, %d lines", H.checks, H.failures, #said))
    os.exit(1)
  end
end

return H
