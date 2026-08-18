-- Tests for the reaction rate computation.
--
-- Run from the repository root:   lua tests/test-reactivity.lua
--
-- The module under test touches no Factorio API, which is what makes this possible and is
-- required by ADR 0005 so that tick cadence can change without touching the rate computation.
--
-- Written to Lua 5.2 semantics (what Factorio 2.0.77 runs) and verified on 5.4: no "//", no
-- math.type, no assumptions about integer subtypes.

package.path = "tests/?.lua;RealisticFusion/?.lua;" .. package.path
local H = require("harness")
local R = require("scripts.reactivity")

local check, near = H.check, H.near

-- ---------------------------------------------------------------- interpolation

-- {x, y} ascending in x. Deliberately uneven spacing: a bug that assumes a uniform grid should
-- not pass.
local D = { { 10, 2 }, { 20, 6 }, { 40, 10 }, { 100, 12 } }

near(R.interpolate(D, 10), 2, 0, "exact point, first")
near(R.interpolate(D, 20), 6, 0, "exact point, middle")
near(R.interpolate(D, 100), 12, 0, "exact point, last")

near(R.interpolate(D, 15), 4, 1e-12, "interpolates midway between points")
near(R.interpolate(D, 30), 8, 1e-12, "interpolates in a wider span")
near(R.interpolate(D, 25), 7, 1e-12, "interpolates off-centre")

-- Out of range clamps rather than extrapolating. Extrapolating a reactivity curve produces
-- nonsense fast: below threshold it would go negative, above the table it would grow without
-- bound.
near(R.interpolate(D, 0), 2, 0, "below range clamps to first")
near(R.interpolate(D, -1e6), 2, 0, "far below range clamps to first")
near(R.interpolate(D, 1e9), 12, 0, "above range clamps to last")

-- Degenerate tables must not fall off either end of the search.
local ONE = { { 5, 42 } }
near(R.interpolate(ONE, 5), 42, 0, "single entry, exact")
near(R.interpolate(ONE, 0), 42, 0, "single entry, below")
near(R.interpolate(ONE, 1e6), 42, 0, "single entry, above")

local TWO = { { 0, 0 }, { 1, 100 } }
near(R.interpolate(TWO, 0), 0, 0, "two entries, at lower bound")
near(R.interpolate(TWO, 1), 100, 0, "two entries, at upper bound")
near(R.interpolate(TWO, 0.25), 25, 1e-12, "two entries, between")

-- A duplicated x is exactly what the upstream dataset contained, so the table must survive one
-- wherever it sits. Note which path each case actually takes: neither reaches the dx == 0 guard
-- in the module, because the search's invariant already makes x0 < x1 strictly. The guard is
-- defence against a future rewrite losing that invariant, and these cases cannot stand in for it
-- -- claiming otherwise would be a test that passes for the wrong reason.
local DUP_FIRST = { { 10, 1 }, { 10, 5 }, { 20, 9 } }   -- resolved by the lower clamp
local dup_first = R.interpolate(DUP_FIRST, 10)
check(dup_first == dup_first, "duplicate at the lower bound is not NaN", tostring(dup_first))
near(dup_first, 1, 0, "duplicate at the lower bound takes the first value")

local DUP_MID = { { 5, 1 }, { 10, 2 }, { 10, 7 }, { 20, 9 } }  -- resolved by the search
local dup_mid = R.interpolate(DUP_MID, 10)
check(dup_mid == dup_mid, "interior duplicate is not NaN", tostring(dup_mid))
check(dup_mid >= 1 and dup_mid <= 9, "interior duplicate stays within the table", tostring(dup_mid))
local dup_after = R.interpolate(DUP_MID, 15)
check(dup_after == dup_after, "interpolating past an interior duplicate is not NaN", tostring(dup_after))
check(dup_after >= 1 and dup_after <= 9, "past an interior duplicate stays in range", tostring(dup_after))

-- ---------------------------------------------------------------- reactivity

check(#R.reactions == 4, "four reactions", table.concat(R.reactions, ","))
for _, name in ipairs(R.reactions) do
  local v = R.reactivity(name, 1.0e8)
  check(type(v) == "number" and v > 0, "reactivity is a positive number for " .. name, tostring(v))
end

-- The four reactions must not share a curve. If a dataset were mis-wired to the wrong key this
-- is what would catch it.
local seen = {}
for _, name in ipairs(R.reactions) do
  local v = R.reactivity(name, 1.0e8)
  for other, ov in pairs(seen) do
    check(v ~= ov, string.format("%s and %s differ at the same temperature", name, other))
  end
  seen[name] = v
end

-- Physics the data must reproduce, or the numbers are decorative. D-T is the best measured
-- fusion reactivity there is: it peaks near 64 keV at about 8.7e-22 m^3/s, and passes about
-- 1.1e-22 m^3/s at 10 keV. The upstream data this project rejected was ~3x high and peaked at
-- about a fifth of the right temperature; these bounds fail that data loudly.
local KEV = 1.16045e7 -- kelvin per keV
near(R.reactivity("D-T", 10 * KEV), 1.1e-22, 0.30, "D-T reactivity at 10 keV")

local peak_t, peak_v = 0, 0
for kev = 1, 400 do
  local v = R.reactivity("D-T", kev * KEV)
  if v > peak_v then peak_v, peak_t = v, kev end
end
check(peak_t >= 40 and peak_t <= 100, "D-T peak is between 40 and 100 keV", peak_t .. " keV")
near(peak_v, 8.7e-22, 0.30, "D-T peak reactivity")

-- Ordering that holds across the whole useful range: D-T is far and away the easiest reaction.
for _, kev in ipairs({ 5, 10, 20, 50 }) do
  local dt = R.reactivity("D-T", kev * KEV)
  check(dt > R.reactivity("D-D", kev * KEV), "D-T beats D-D at " .. kev .. " keV")
  check(dt > R.reactivity("D-He3", kev * KEV), "D-T beats D-He3 at " .. kev .. " keV")
  check(dt > R.reactivity("He3-He3", kev * KEV), "D-T beats He3-He3 at " .. kev .. " keV")
end

-- Cold plasma does not fuse.
near(R.reactivity("D-T", 0), 0, 0, "no reactivity at absolute zero")

-- ---------------------------------------------------------------- rate

-- Unlike species: rate = n1 * n2 * <sv>.
local sv = R.reactivity("D-T", 20 * KEV)
near(R.rate("D-T", 20 * KEV, 1e20, 2e20), 1e20 * 2e20 * sv, 1e-12, "unlike-species rate")

-- Like species must not be double counted: each pair is one reaction, so the rate carries a
-- factor of one half. Getting this wrong doubles D-D output for free.
local sv_dd = R.reactivity("D-D", 20 * KEV)
near(R.rate("D-D", 20 * KEV, 1e20, 1e20), 0.5 * 1e20 * 1e20 * sv_dd, 1e-12, "like-species rate halved")

near(R.rate("D-T", 20 * KEV, 0, 1e20), 0, 0, "no fuel, no rate")

-- ---------------------------------------------------------------- Q factor

near(R.q_factor(100, 50), 2, 1e-12, "Q is fusion over heating")
near(R.q_factor(0, 50), 0, 0, "no fusion, Q is zero")

-- The case that would crash a reactor mid-tick.
local ok_q = pcall(function() return R.q_factor(100, 0) end)
check(ok_q, "zero heating power does not error")
local q0 = R.q_factor(100, 0)
check(q0 == q0, "zero heating power does not produce NaN", tostring(q0))
check(q0 ~= math.huge and q0 ~= -math.huge, "zero heating power does not produce infinity", tostring(q0))
near(R.q_factor(0, 0), 0, 0, "nothing happening at all, Q is zero")

-- ----------------------------------------------------------------

H.finish()
