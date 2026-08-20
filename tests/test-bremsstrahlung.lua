-- The bremsstrahlung equilibrium, reproduced and pinned (#51).
--
-- Run from the repository root:   lua tests/test-bremsstrahlung.lua
--
-- WHY THIS EXISTS. docs/research/bremsstrahlung.md and docs/adr/0014 both quote a D-D equilibrium
-- with the radiation term counted, and they disagreed: 2.42e8 K at Q 0.32 against 2.69e8 K at
-- Q 0.386. Neither harness was checked in, so there was no way to ask which was right without
-- rebuilding one. This is that harness, kept, so the next question about these numbers is a command
-- rather than an archaeology.
--
-- THE ANSWER, which the tables below print rather than assert away: the two numbers are not two
-- attempts at one calculation. They are the SAME calculation under two different published fits.
-- 2.69e8 K is the non-relativistic formula; 2.42e8 K is the same formula with the relativistic
-- correction the note's own section on it says must be used at these temperatures. The later sweep
-- dropped the correction, so its whole confinement ladder is 10-20% optimistic.
--
-- NOTHING SHIPPED USES THIS. reactor-logic.lua carries no radiation term and this file does not add
-- one to it; the models below are local, and whether any of them ever goes into the simulation is
-- #37 and #52. What this file checks is that the figures the docs quote still follow from the
-- repository's own reactivity dataset.
--
-- AND NOTHING RUNS IT FOR YOU. There is no CI here and no scripts/*.ps1 invokes the Lua tests, so
-- regenerating cross-section-data/reactivities.lua invalidates bremsstrahlung.md and ADR 0014
-- silently unless somebody types the command above. Stated rather than glossed, because "the test
-- would catch it" is only true of a test something runs.
--
-- Like the other tests here it runs outside Factorio (ADR 0005), written to Lua 5.2 semantics and
-- verified on 5.4.

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
local H = require("harness")
local L = require("scripts.reactor-logic")
local reactivity = require("scripts.reactivity")

local check = H.check

-- Every figure below is quoted to three significant figures in the docs, so 1% is the tolerance
-- that distinguishes "the dataset moved" from "the last digit rounded differently". It is also far
-- tighter than the ~20% disagreement this file exists to resolve, which is the point: at 1% the two
-- implementations cannot both pass.
local TOL = 0.01

-- Nil is a failure rather than an error, and that is not defensive padding: a balance with no root
-- returns nil, so breaking the physics badly enough makes several of these nil at once. Crashing
-- on the first one would hide every check after it, which is exactly what happened the first time
-- this file was negative-tested by stripping the relativistic correction.
--
-- H.near is not what this file wants, which is why it keeps its own: that one takes a tolerance per
-- call and prints the raw miss, and here the tolerance is one constant and the useful number is how
-- far off in percent. Built on H.check so the counters are still the harness's (#42).
--
-- Named near_pct rather than near, and the difference in name is load-bearing: the two take
-- different arguments, so a same-named pair one directory apart is a trap. Following the harness's
-- own documented `local near = H.near` here would rebind every call below to a function whose third
-- argument is a tolerance, and each would then pass its name string where the tolerance goes.
local function near_pct(actual, expected, name)
  if not actual then
    return check(false, name, string.format("got no equilibrium, expected %.6g", expected))
  end
  local off = math.abs(actual - expected) / math.abs(expected)
  check(off <= TOL, name,
    string.format("got %.6g, expected %.6g (%.2f%% off)", actual, expected, 100 * off))
end

local K_B = 1.380649e-23
local KELVIN_PER_KEV = 1.1604518e7   -- 1 eV = 11604.518 K, so 1 keV is this many kelvin

-- NRL Plasma Formulary (2019) eq. (30) in SI, as Wurzel and Hsu (Phys. Plasmas 29, 062103 (2022))
-- eq. (7) states it directly: P_B = C_B * n_i * n_e * Z_eff * sqrt(T_keV), W/m^3.
--
-- Converting the formulary's cgs constant gives 5.344e-37; Wurzel and Hsu round to 5.34e-37 and
-- that is the value docs/research/bremsstrahlung.md computed with, so it is the value here. The
-- 0.1% between them is an order of magnitude below the tolerance above and two below the
-- disagreement being resolved.
local C_B = 5.34e-37

-- The relativistic correction factor xi. Bremsstrahlung is derived non-relativistically, and these
-- plasmas are not: the electron rest mass is 511 keV and the D-D point sits at 21 keV with the term
-- counted and 76 keV without it, so the correction runs from a few percent to a factor of five.
--
-- Two published fits, because they disagree with each other by up to 30% at the top of this range
-- and picking one silently is exactly the mistake this file documents.
local M_E_C2_KEV = 511

local MODELS = {
  {
    key = "none",
    label = "none (shipped)",
    xi = nil,   -- no term at all, which is what the simulation actually does
  },
  {
    key = "nonrel",
    label = "non-relativistic",
    -- The bare formulary equation. Correct below ~10 keV and increasingly optimistic above it.
    xi = function(_) return 1 end,
  },
  {
    key = "rider",
    label = "Rider 1997",
    -- Rider, Phys. Plasmas 4, 1039 (1997), eq. (21), at Z_eff = 1. The trailing (3/2)t is
    -- electron-electron bremsstrahlung, which has no dipole moment non-relativistically and so
    -- switches on only as the plasma warms.
    xi = function(t)
      return (1 + 0.7936 * t + 1.874 * t * t) + 1.5 * t
    end,
  },
  {
    key = "wurzel",
    label = "Wurzel/Putvinski",
    -- Wurzel and Hsu, appendix D eqs. (D1)-(D2), attributing the fit to Putvinski, Ryutov and
    -- Yushmanov, Nucl. Fusion 59, 076018 (2019). The headline model in bremsstrahlung.md, on the
    -- grounds that it is the larger of the two and the conservative choice.
    --
    -- Cut off at t = 1, i.e. 5.93e9 K, which is the fit's PUBLISHED DOMAIN and not the point where
    -- it misbehaves. Xie (arXiv:2404.11540) records t < 1 as the validity bound; the expression
    -- itself is still positive and rising there (xi = 6.70 at t = 1) and does not go negative until
    -- somewhere between t = 2 and t = 3, well above this scan's 1e10 K ceiling. So the guard costs
    -- the band from 5.93e9 to 1e10 K, where the fit would still return plausible-looking numbers
    -- with no published claim behind them -- which is the thing worth refusing.
    --
    -- bremsstrahlung.md's implementation note says the fit "returns negative numbers" above the
    -- bound and that this was hit in practice. That is true of the range it was driven over there
    -- and not of the bound itself, and repeating it here would tell a reader that raising the
    -- ceiling is safe right up to the negativity. It is not: it is unsupported from t = 1.
    xi = function(t)
      if t >= 1 then return nil end
      return (1 + 1.78 * t ^ 1.34) + 2.12 * t * (1 + 1.1 * t + t * t - 1.25 * t ^ 2.5)
    end,
  },
}

--- Bremsstrahlung power for the whole plasma, in watts. Z_eff = 1: every ion in a D-D or D-T
--- plasma is singly charged, which is also the assumption the shipped model's n_e = n_i makes.
local function brems_w(model, spec, density, t_k)
  if not model.xi then return 0 end
  local t_kev = t_k / KELVIN_PER_KEV
  local xi = model.xi(t_kev / M_E_C2_KEV)
  if not xi then return nil end   -- outside the fit's validity, and never silently zero
  return C_B * density * density * math.sqrt(t_kev) * xi * spec.volume_m3
end

--- Fusion power for the whole plasma, in watts, off the repository's own reactivity dataset.
local function fusion_w(fuel, spec, density, t_k)
  local rate = reactivity.rate(fuel.reaction, t_k,
    density * fuel.fractions[1], density * fuel.fractions[2])
  return rate * spec.volume_m3 * fuel.energy_per_reaction_j
end

--- The power balance the plasma settles on, in watts.
--
-- Charged fusion products plus external heating against the transport loss and the radiation. It
-- is step()'s balance with one term added and the fuel burn-down left out, which is what makes
-- reproducing the shipped equilibrium below a real check rather than a tautology: if this stated
-- the balance differently it would not land on 8.769e8.
local function balance_w(model, fuel, spec, density, t_k)
  local n = density * spec.volume_m3           -- nuclei present
  local charged = fusion_w(fuel, spec, density, t_k) * fuel.charged_fraction
  local loss = 3 * n * K_B * t_k / spec.confinement_time_s
  local brems = brems_w(model, spec, density, t_k)
  if not brems then return nil end
  return charged + spec.heating_power_w - loss - brems
end

--- Every stable equilibrium temperature, in kelvin, ascending.
--
-- Found by scanning rather than by iterating from a seed, because these balances have more than one
-- root -- D-T's reactivity rolls over past its peak while bremsstrahlung keeps climbing, so the two
-- curves cross back -- and an iteration would land on whichever one it started nearest and report
-- it as "the" answer. A stable root is one the balance crosses downwards: warmer plasma loses more
-- than it makes, so it falls back.
local function equilibria(model, fuel, spec, density)
  local LO, HI, STEPS = 1e6, 1e10, 6000
  local roots = {}
  local prev_t, prev_f
  for i = 0, STEPS do
    local t = LO * (HI / LO) ^ (i / STEPS)
    local f = balance_w(model, fuel, spec, density, t)
    if f and prev_f and prev_f > 0 and f <= 0 then
      -- Bisect. 200 halvings takes a decade-wide bracket well below float precision; the loop is
      -- cheap and stopping on a relative width is one more thing to get wrong.
      local lo, hi = prev_t, t
      for _ = 1, 200 do
        local mid = math.sqrt(lo * hi)
        local fm = balance_w(model, fuel, spec, density, mid)
        if fm and fm > 0 then lo = mid else hi = mid end
      end
      roots[#roots + 1] = math.sqrt(lo * hi)
    end
    -- Reset rather than carry the last valid point across a gap. A band where the model is
    -- undefined sits at the top of the range today, so this changes nothing now -- but a model with
    -- an interior validity window would otherwise bracket the first point above the band against a
    -- point from below it, and the bisection would search a range the balance is not defined over
    -- and return something that is not a root. A fabricated equilibrium is the worst thing this
    -- file could produce, since its whole purpose is to be quoted.
    prev_t, prev_f = t, f
  end
  return roots
end

--- The equilibrium a reactor started cold actually reaches: the coolest stable one.
--
-- A nil answer means ONE thing and it is worth naming, because the obvious reading is the wrong
-- one: it means the plasma RAN AWAY, never that it quenched. The balance is positive at the scan
-- floor for every model here -- 50 MW of heating against about 1.6 MW radiated and 0.14 MW of
-- transport at 1e6 K -- so a cold plasma always warms. No downward crossing below 1e10 K therefore
-- means it was still climbing at the top of the scan, and the callers below say so.
local function settles_at(model, fuel, spec, density)
  local roots = equilibria(model, fuel, spec, density)
  return roots[1]
end

-- The top row of every dataset in cross-section-data/reactivities.lua. Above it
-- reactivity.interpolate CLAMPS rather than extrapolating -- deliberately, and for good reasons
-- stated in that file -- so an equilibrium found up there is balanced against a flat reactivity
-- that is not physics. D-D's cross-section is still climbing at the table's end, so the clamp
-- understates it and the true root is higher or absent altogether.
--
-- Not an error: those rows are real answers to "what does THIS model do", and one of them is the
-- struck ADR figure this file exists to explain. They are marked instead, so a number that leaves
-- the dataset behind cannot be quoted as though it had not.
local DATASET_TOP_K = 6.96271e9

local function beyond_dataset(t_k)
  return t_k and t_k > DATASET_TOP_K
end

local SPEC = L.reactor
local DENSITY = SPEC.particles_per_unit   -- 1000 units in a 1000 m^3 box is 1e20 m^-3
local FUELS = {
  { key = "D-D", fuel = L.fuels["rf-d-d-plasma"] },
  { key = "D-T", fuel = L.fuels["rf-d-t-plasma"] },
}

-- ---------------------------------------------------------------------------------------------
-- The table the documents quote.

print("Equilibrium at the shipped constants -- 1e20 m^-3, tau_E 30 s, 50 MW heating, 1000 m^3")
print("")
print(string.format("  %-5s %-18s %12s %8s %10s %10s",
  "fuel", "bremsstrahlung", "settles at", "Q", "P_fus", "P_brem"))

local found = {}
for _, f in ipairs(FUELS) do
  for _, model in ipairs(MODELS) do
    local t = settles_at(model, f.fuel, SPEC, DENSITY)
    found[f.key .. "/" .. model.key] = t
    if t then
      local p_fus = fusion_w(f.fuel, SPEC, DENSITY, t)
      local p_br = brems_w(model, SPEC, DENSITY, t) or 0
      print(string.format("  %-5s %-18s %10.3g K %8.3g %7.0f MW %7.0f MW%s",
        f.key, model.label, t, p_fus / SPEC.heating_power_w, p_fus / 1e6, p_br / 1e6,
        beyond_dataset(t) and "  (past the dataset)" or ""))
    else
      print(string.format("  %-5s %-18s %12s", f.key, model.label, "runs away"))
    end
  end
end

-- ---------------------------------------------------------------------------------------------
-- The confinement ladder, which is what ADR 0014 records and #53 would build.
--
-- Printed under both fits because the difference between them is the whole finding: the ladder in
-- that ADR is the non-relativistic column, and the relativistic one needs about eight seconds more
-- confinement to reach the same place.

print("")
print("D-D against confinement time -- where a research ladder would run")
print("")
print(string.format("  %6s %14s %8s %14s %8s", "tau_E", "non-rel", "Q", "Wurzel/Put.", "Q"))

local D_D = L.fuels["rf-d-d-plasma"]
local BY_KEY = {}
for _, m in ipairs(MODELS) do BY_KEY[m.key] = m end

local LADDER = {}
local legend = false
for _, tau in ipairs({ 30, 40, 42, 50, 52, 55, 60, 70, 100, 200 }) do
  local spec = {}
  for k, v in pairs(SPEC) do spec[k] = v end
  spec.confinement_time_s = tau

  local cells = {}
  for _, key in ipairs({ "nonrel", "wurzel" }) do
    local t = settles_at(BY_KEY[key], D_D, spec, DENSITY)
    cells[key] = { t_k = t, q = t and fusion_w(D_D, spec, DENSITY, t) / spec.heating_power_w }
  end
  LADDER[tau] = cells

  -- A cell can be empty, and it means something: past about 100 s the non-relativistic D-D balance
  -- has no root below 1e10 K at all. It is not radiating enough to ever catch up, so it runs off
  -- the top of the scan and out of the reactivity dataset. "runs away" rather than a number.
  local function cell(c)
    if not c.t_k then return string.format("%12s %8s", "runs away", "--") end
    -- A trailing "*" is not decoration: it marks a root balanced against a clamped reactivity
    -- rather than against the dataset. See beyond_dataset above.
    return string.format("%10.3g K%s %7.3g", c.t_k, beyond_dataset(c.t_k) and "*" or " ", c.q)
  end
  print(string.format("  %5ds %s %s", tau, cell(cells.nonrel), cell(cells.wurzel)))
  legend = legend or beyond_dataset(cells.nonrel.t_k) or beyond_dataset(cells.wurzel.t_k)
end

if legend then
  print("")
  print(string.format("  * balanced against a reactivity CLAMPED at the dataset's top row (%.4g K),",
    DATASET_TOP_K))
  print("    not interpolated within it -- see beyond_dataset. Not a physical equilibrium.")
end

-- ---------------------------------------------------------------------------------------------
-- Assertions.

print("")

-- The reproduction check, and the reason anything below it can be believed. If this harness did
-- not land on the shipped model's own equilibrium it would be a different model, and its
-- bremsstrahlung numbers would be about a different reactor.
near_pct(found["D-D/none"], 8.769e8, "radiation-free D-D reproduces the shipped equilibrium")
-- Through num(), like every other arithmetic on a root here: a missing equilibrium would otherwise
-- reach reactivity.rate as nil and take down the two assertions below that carry the finding.
near_pct(found["D-D/none"] and fusion_w(D_D, SPEC, DENSITY, found["D-D/none"]) / SPEC.heating_power_w,
  2.139, "radiation-free D-D reproduces the shipped Q")
near_pct(found["D-T/none"], 4.63e9, "radiation-free D-T reproduces d-t-ignition.md's equilibrium")

-- THE FINDING. The two disputed figures are two models, not two answers, and each is reproduced
-- here by the model it came from. Nothing else in this file matters as much as these two lines.
near_pct(found["D-D/nonrel"], 2.69e8, "ADR 0014's 2.69e8 is the NON-RELATIVISTIC equilibrium")
near_pct(found["D-D/wurzel"], 2.42e8, "bremsstrahlung.md's 2.42e8 is the RELATIVISTIC one")

local function q_at(key)
  local t = found[key]
  if not t then return nil end
  local fuel = key:match("^D%-D") and D_D or L.fuels["rf-d-t-plasma"]
  return fusion_w(fuel, SPEC, DENSITY, t) / SPEC.heating_power_w
end

near_pct(q_at("D-D/nonrel"), 0.386, "and its Q 0.386 likewise")
near_pct(q_at("D-D/wurzel"), 0.32, "against Q 0.32 with the correction counted")

-- The third fit, so the spread between published fits is on the record rather than implied.
near_pct(found["D-D/rider"], 2.46e8, "Rider 1997 sits between the two")

-- D-T, which the term does not rescue from the clamp -- the load-bearing claim in
-- reactor-logic.lua's comment block and in d-t-ignition.md.
near_pct(found["D-T/wurzel"], 3.26e9, "D-T with the correction stays above the int32 ceiling")
check(found["D-T/wurzel"] and found["D-T/wurzel"] > 2.147e9, "D-T equilibrium is above int32",
  string.format("%.3g K", found["D-T/wurzel"] or 0))
check(found["D-T/nonrel"] and found["D-T/wurzel"] and found["D-T/nonrel"] > found["D-T/wurzel"],
  "the correction lowers D-T's equilibrium rather than raising it")

-- "No equilibrium" is zero for the comparisons below, for the same reason near_pct() treats it as a
-- failure: a check that errors takes every check after it down with it, and these are the ones
-- that carry the finding.
local function num(v) return v or 0 end

-- The correction is not a rounding error at this operating point, which is why dropping it moved
-- the answer at all. num() and the `or 0` are the same guard every check above uses: xi() answers
-- nil outside its domain, and an unguarded comparison against nil would abort the run before the
-- ladder assertions below -- which are the ones carrying the finding.
local t_kev = num(found["D-D/wurzel"]) / KELVIN_PER_KEV
local xi_here = BY_KEY.wurzel.xi(t_kev / M_E_C2_KEV)
check(num(xi_here) > 1.05, "the correction is worth more than 5% here",
  string.format("xi = %.3f at %.1f keV", num(xi_here), t_kev))

-- The ladder, which is what #52 and #53 would be built on. Both columns, because ADR 0014 quotes
-- the left one and a reader has to be able to check that claim as well as the corrected one.
near_pct(LADDER[42].nonrel.q, 1.02, "ADR 0014's break-even at 42 s is the non-relativistic ladder")
near_pct(LADDER[50].nonrel.q, 2.58, "and its 50 s rung likewise")
check(LADDER[50].wurzel.q and LADDER[50].wurzel.q < 1,
  "with the correction, 50 s is still below break-even",
  string.format("Q %.3g", num(LADDER[50].wurzel.q)))

-- Where the corrected ladder crosses break-even. A bracket rather than a single number, because
-- the rung a design would actually use is a balance decision and not this file's to make -- and
-- because a bracket is what fails informatively if the dataset moves under it.
check(LADDER[50].wurzel.q and LADDER[55].wurzel.q
  and LADDER[50].wurzel.q < 1 and LADDER[55].wurzel.q > 1,
  "the corrected ladder crosses break-even between 50 s and 55 s",
  string.format("Q %.3g at 50 s, %.3g at 55 s",
    LADDER[50].wurzel.q or 0, LADDER[55].wurzel.q or 0))

-- bremsstrahlung.md's own confinement sweep, at the two rungs it publishes that this ladder also
-- covers. They land in the relativistic column, which is what makes that document internally
-- consistent and leaves ADR 0014 as the one carrying the other model's numbers.
near_pct(LADDER[60].wurzel.t_k, 6.48e8, "bremsstrahlung.md's 60 s rung is the relativistic one")
near_pct(LADDER[100].wurzel.q, 3.58, "and its 100 s rung likewise")

near_pct(LADDER[200].wurzel.t_k, 2.13e9, "and its 200 s rung, the last one it publishes")

-- THE ERROR IS NOT A PERCENTAGE, and this is the assertion that stops the struck ladder being
-- "corrected" by scaling. Bremsstrahlung grows as sqrt(T) while D-D's reactivity climbs steeply
-- over this range, so every second of confinement buys the uncorrected ladder more than it buys
-- the real one and the two diverge as the ladder goes up: 11% apart at 30 s, 118% at 50 s.
-- num() for the same reason every other comparison here uses it: a rung whose plasma ran away has
-- no temperature, and an unguarded division would abort the run before the two cliff assertions
-- below -- which are the ones that would explain what moved.
local function gap(tau)
  local top, bottom = num(LADDER[tau].nonrel.t_k), num(LADDER[tau].wurzel.t_k)
  if bottom == 0 then return 0 end
  return top / bottom - 1
end
check(gap(30) < 0.2 and gap(50) > 1,
  "the two ladders diverge superlinearly rather than by a fixed fraction",
  string.format("%.0f%% apart at 30 s, %.0f%% at 50 s", 100 * gap(30), 100 * gap(50)))

-- The cliff. ADR 0014 records D-D igniting and running to the clamp "past about 55 s", which is a
-- constraint on how many rungs a ladder can have -- and it is the non-relativistic ladder's cliff.
-- Both columns are asserted, because the correction does not move the cliff so much as replace it:
--
--   * Without the correction D-D genuinely runs away. Between 55 s and 60 s its equilibrium jumps
--     1.82e9 -> 2.66e9 K, straight through the clamp, and it keeps climbing from there.
--   * With it, D-D never runs away at all. Radiation grows with temperature faster than D-D's
--     reactivity does past 168 keV, so the balance always closes; the ladder just walks up slowly
--     and does not reach the clamp until somewhere past 100 s.
--
-- The symptom a player sees at the top is the same either way -- a pinned temperature reading --
-- but a runaway and a slow climb bound a research ladder very differently, and #53 is the ticket
-- that has to know which it is guarding against.
check(num(LADDER[55].nonrel.t_k) < 2e9 and num(LADDER[60].nonrel.t_k) > 2e9,
  "ADR 0014's cliff at ~55 s is the non-relativistic ladder's",
  string.format("%.3g K at 55 s, %.3g K at 60 s",
    num(LADDER[55].nonrel.t_k), num(LADDER[60].nonrel.t_k)))
check(num(LADDER[100].wurzel.t_k) < 2e9 and num(LADDER[200].wurzel.t_k) > 2e9,
  "with the correction the clamp is not reached until past 100 s",
  string.format("%.3g K at 100 s, %.3g K at 200 s",
    num(LADDER[100].wurzel.t_k), num(LADDER[200].wurzel.t_k)))

-- ---------------------------------------------------------------- density, and the optimum in it

-- WHY THIS BLOCK EXISTS, since nothing above needed it: the shipped density is not the density that
-- makes the most power. Fusion and bremsstrahlung both go as n^2 while the transport loss goes as
-- nT, so thinning the plasma at fixed heating raises its equilibrium temperature -- and over the
-- range D-D's reactivity is still climbing steeply, that buys more than the lost density costs.
--
-- A player therefore gets MORE out of a half-empty reactor than a full one, which is the opposite
-- of what #37's item 3 recorded from the radiation-free model, where the curve falls monotonically.
-- ADR 0016 accepts it as a deliberate mechanic rather than tuning it away, so the numbers it quotes
-- are asserted here for the reason #51 exists: a balance figure with no kept harness behind it is
-- a figure that drifts.
--
-- Densities are given as a fraction of a full fluidbox. `amount` is the box's share of its fluid
-- segment (#40), so the fraction below is the fill of the whole run and not of one machine, which
-- is what makes heater throughput the lever rather than anything per-reactor.

local FILLS = { 1.0, 0.85, 0.70, 0.65, 0.60, 0.50, 0.35, 0.25 }

--- Q and fusion power at one fill, for one confinement time. nil when the plasma ran away.
local function at_fill(tau, fill)
  local spec = {}
  for k, v in pairs(SPEC) do spec[k] = v end
  spec.confinement_time_s = tau
  local density = DENSITY * fill
  local t = settles_at(BY_KEY.wurzel, D_D, spec, density)
  if not t then return nil end
  local p = fusion_w(D_D, spec, density, t)
  return { t_k = t, p_w = p, q = p / spec.heating_power_w }
end

local TAUS = { 30, 50, 70 }
local FILL_ROWS = {}
for _, tau in ipairs(TAUS) do
  FILL_ROWS[tau] = {}
  for _, fill in ipairs(FILLS) do FILL_ROWS[tau][fill] = at_fill(tau, fill) end
end

print("")
print("D-D against plasma fill -- the density optimum, and how research closes it")
print("")
print(string.format("  %5s %14s %8s %14s %8s %14s %8s",
  "fill", "tau 30 s", "Q", "tau 50 s", "Q", "tau 70 s", "Q"))
for _, fill in ipairs(FILLS) do
  local cells = ""
  for _, tau in ipairs(TAUS) do
    local c = FILL_ROWS[tau][fill]
    if c then
      cells = cells .. string.format(" %10.3g K%s %7.3g", c.t_k,
        beyond_dataset(c.t_k) and "*" or " ", c.q)
    else
      cells = cells .. string.format(" %12s %8s", "runs away", "--")
    end
  end
  print(string.format("  %4.0f%%%s", fill * 100, cells))
end

--- Q at a fill, or 0, so a runaway cannot abort the run before the assertions that explain it.
local function q(tau, fill)
  local c = FILL_ROWS[tau][fill]
  return c and c.q or 0
end

-- THE FINDING. An under-supplied reactor out-performs a full one at the shipped confinement time,
-- and by a wide enough margin that a player will find it: 40% more fusion power for 35% less fuel.
check(q(30, 0.65) > q(30, 1.0) * 1.3,
  "at tau 30 s a 65% full reactor beats a full one by more than 30%",
  string.format("Q %.3f at 65%% against Q %.3f full", q(30, 0.65), q(30, 1.0)))

-- An interior maximum, not a monotonic rise as density falls -- which is what makes it an operating
-- point a player tunes to rather than an instruction to run the reactor as empty as possible. Below
-- it the n^2 term wins again, and by 25% fill the reactor is worse than full.
check(q(30, 0.65) > q(30, 0.85) and q(30, 0.65) > q(30, 0.50),
  "the optimum at tau 30 s is interior, near 65% fill",
  string.format("Q %.3f / %.3f / %.3f at 85%% / 65%% / 50%%",
    q(30, 0.85), q(30, 0.65), q(30, 0.50)))
check(q(30, 0.25) < q(30, 1.0),
  "and far enough below it a reactor is worse off than full",
  string.format("Q %.3f at 25%% against Q %.3f full", q(30, 0.25), q(30, 1.0)))

-- RESEARCH CLOSES IT, which is the half of ADR 0016 that makes the mechanic self-limiting rather
-- than a permanent tax on building properly. Raising confinement time raises the equilibrium
-- temperature at every density, so the optimum walks up the fill axis until it leaves the range
-- altogether and full supply is simply best.
check(q(50, 0.85) > q(50, 1.0) and q(50, 0.85) > q(50, 0.65),
  "by tau 50 s the optimum has moved up to about 85% fill",
  string.format("Q %.3f / %.3f / %.3f at full / 85%% / 65%%",
    q(50, 1.0), q(50, 0.85), q(50, 0.65)))
check(q(70, 1.0) > q(70, 0.85),
  "and by tau 70 s full supply is the best supply, so the mechanic has closed",
  string.format("Q %.3f full against Q %.3f at 85%%", q(70, 1.0), q(70, 0.85)))

-- The rung break-even falls on depends on supply, which ADR 0014's ladder does not say because it
-- is a full-supply table. A player who tunes density crosses at tau 50 s where a player who does
-- not is still below it. Asserted so that correction cannot quietly come undone.
check(q(50, 1.0) < 1 and q(50, 0.85) > 1,
  "at tau 50 s a tuned reactor is above break-even and a full one is not",
  string.format("Q %.3f full against Q %.3f at 85%%", q(50, 1.0), q(50, 0.85)))

-- D-T is untouched by any of this and it is worth pinning why, because the obvious worry is that
-- moving density for D-D's sake would disturb the tier that works. D-T sits far PAST its optimum
-- rather than below it, so its temperature barely moves as the plasma thins and it de-rates almost
-- exactly as n^2 -- and its equilibrium is above max_temperature_c at every fill here anyway, so
-- what a player actually sees is the clamp.
local D_T = L.fuels["rf-d-t-plasma"]
local function dt_at(fill)
  local density = DENSITY * fill
  local t = settles_at(BY_KEY.wurzel, D_T, SPEC, density)
  return t and fusion_w(D_T, SPEC, density, t) or 0
end
local dt_full, dt_65 = dt_at(1.0), dt_at(0.65)
check(dt_full > 0 and dt_65 / dt_full > 0.40 and dt_65 / dt_full < 0.50,
  "D-T de-rates as n^2 rather than up-rating, so the D-D mechanic is D-D's alone",
  string.format("%.1f%% of full at 65%% fill, where n^2 predicts %.1f%%",
    100 * dt_65 / dt_full, 100 * 0.65 * 0.65))

H.finish()
