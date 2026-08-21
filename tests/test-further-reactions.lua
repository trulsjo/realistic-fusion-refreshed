-- The candidate-reaction arithmetic behind docs/research/further-reactions.md (#98).
--
-- Run from the repository root:   lua tests/test-further-reactions.lua
--
-- WHY THIS EXISTS. That note says the shipped He3-He3 tier has no ignited state once
-- bremsstrahlung is counted, that D-He3 needs four times its heating to light, and that the
-- radiation term as sketched in docs/research/bremsstrahlung.md understates the aneutronic pair by
-- 3.1x and 6.3x. #98 asks #52 to act on that. The harness that computed it was a scratchpad, so
-- none of it was reproducible -- which is the same hole docs/research/quality.md left and #97
-- exists to close. This is that harness, kept.
--
-- WHAT IT IS. tests/test-bremsstrahlung.lua's power balance, generalised in three ways the shipped
-- model cannot express:
--
--   * a fuel may be an UNEVEN mix -- p-11B is about 15% boron, not half;
--   * the two species may have DIFFERENT CHARGE, so the electron density follows from
--     quasineutrality instead of being assumed equal to the ion density, and it enters both the
--     heat capacity and the radiation;
--   * the electrons may be COLDER than the ions, T_e = r * T_i, which is what every published
--     p-11B viability window rests on and what this mod's one-temperature model cannot have.
--
-- Set r = 1 with one singly-charged ion species and it is the shipped balance exactly. The
-- validation block below is that claim as four checks against figures bremsstrahlung.md publishes,
-- and it is the reason to believe the rest: those four are not fitted here, they fall out.
--
-- WHAT IS SHIPPED AND WHAT IS NOT, since #52 and #98 moved the line. scripts/reactor-logic.lua now
-- carries the radiation term and the per-fuel electron density, so two of the three generalisations
-- below are no longer local to this file. The third still is: the shipped model has ONE temperature,
-- and every p-11B figure here depends on electrons being colder than ions. That is the one that has
-- no route into the simulation without a different step().
--
-- AND NOTHING RUNS IT FOR YOU. There is no CI here and no scripts/*.ps1 invokes the Lua tests, so
-- regenerating cross-section-data/reactivities.lua invalidates further-reactions.md silently unless
-- somebody types the command above. Stated rather than glossed, exactly as the bremsstrahlung suite
-- states it, because "the test would catch it" is only true of a test something runs.
--
-- WHAT IT DOES NOT CHECK, so the gap is not mistaken for coverage: the note's full equilibrium
-- sweeps for p-11B and the lithium family, and its ideal-ignition bands. Those need reactivity data
-- this repository does not carry -- p-11B's fit coefficients and T-T's and T-He3's NRL tabulations
-- are inlined below with their sources, but the lithium fuels' are in ORNL/TM-6914 and were read
-- from the paper rather than digitised. Two significant figures is all NRL gives for T-T and T-He3,
-- so every figure derived from those two carries that and the tolerances below say so.
--
-- Like the other suites here it runs outside Factorio (ADR 0005), written to Lua 5.2 semantics and
-- verified on 5.4.6.

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
local H = require("harness")
local L = require("scripts.reactor-logic")
local reactivity = require("scripts.reactivity")

local check, near = H.check, H.near

-- 1% against figures that come from this repository's own dataset -- the same tolerance
-- test-bremsstrahlung.lua uses, and for the same reason: it distinguishes "the dataset moved" from
-- "the last digit rounded differently".
local TOL = 0.01
-- 3% against anything derived from the NRL tabulations, which are two significant figures
-- log-log interpolated. Tightening this would be pretending the input is better than it is.
local TOL_NRL = 0.03

local K_B = 1.380649e-23
local EV = 1.602176634e-19
local KEV = 1.1604518e7      -- kelvin per keV
local MEC2 = 511             -- electron rest energy, keV
local C_B = 5.34e-37         -- bremsstrahlung coefficient, SI, NRL Plasma Formulary (2019) p. 58

-- The relativistic correction factor. NRL's plain n_e^2 sqrt(T) form is non-relativistic, and
-- bremsstrahlung.md's own section on it says the correction must be used at these temperatures --
-- the two differ by 10-20% at the D-D settling point and by more at the clamp. The z_eff term is
-- electron-ion; the additive term is electron-electron and does not scale with charge, which is why
-- the aneutronic factors below are not simply Z_eff * (n_e/n_i)^2.
local function xi(te_kev, z_eff)
  local t = te_kev / MEC2
  if t >= 1 then return nil end
  return z_eff * (1 + 1.78 * t ^ 1.34) + 2.12 * t * (1 + 1.1 * t + t * t - 1.25 * t ^ 2.5)
end

---------------------------------------------------------------------------- reactivity datasets

-- p-11B. Bosch and Hale (1992) eqs (12)-(14) functional form, coefficients from Tentori and
-- Belloni, Nucl. Fusion 63, 086001 (2023) table 2, which also reprints Nevins and Swain (2000).
-- Both fits are kept because the note's central claim is that p-11B fails under EITHER, and a
-- single fit would leave that untestable. Published domain 70 to 500 keV; nil outside it rather
-- than extrapolated, which matters -- the reaction's interesting region is at its upper edge.
local PB11_EG, PB11_MRC2 = 22589.0, 0.92283 * 931.49410242e3
local PB11 = {
  ns = { 4.4467e-14, -5.9357e-2, 2.0165e-1, 1.0404e-3, 2.7621e-3, -9.1653e-6, 9.8305e-7 },
  tb = { 9.7827e-14, -5.1610e-2, 1.3240e-1, 3.8446e-4, 1.2499e-3, -5.6715e-6, 1.1615e-6 },
}
local function pb11(which)
  local p = PB11[which]
  return function(t_k)
    local T = t_k / KEV
    if T < 70 or T > 500 then return nil end
    local theta = T / (1 - (T * (p[2] + T * (p[4] + T * p[6]))) / (1 + T * (p[3] + T * (p[5] + T * p[7]))))
    local x = (PB11_EG / (4 * theta)) ^ (1 / 3)
    return p[1] * theta * math.sqrt(x / (PB11_MRC2 * T ^ 3)) * math.exp(-3 * x)
  end
end

-- T-T and T-He3, NRL Plasma Formulary (2019) p. 45, reactions (4) and (5a-c). Ten points each, in
-- cm^3/s at the tabulated keV, log-log interpolated and converted to m^3/s. Two significant
-- figures is what the table gives.
local function tabulated(points)
  return function(t_k)
    local T = t_k / KEV
    if T < points[1][1] or T > points[#points][1] then return nil end
    for i = 2, #points do
      if T <= points[i][1] then
        local a, b = points[i - 1], points[i]
        local f = math.log(T / a[1]) / math.log(b[1] / a[1])
        return math.exp(math.log(a[2]) + f * math.log(b[2] / a[2])) * 1e-6
      end
    end
  end
end

local TT = tabulated({ {1,3.3e-22},{2,7.1e-21},{5,1.4e-19},{10,7.2e-19},{20,2.5e-18},{50,8.7e-18},
                       {100,1.9e-17},{200,4.2e-17},{500,8.4e-17},{1000,8.0e-17} })
local THE3 = tabulated({ {1,1e-28},{2,1e-25},{5,2.1e-22},{10,1.2e-20},{20,2.6e-19},{50,5.3e-18},
                         {100,2.7e-17},{200,9.2e-17},{500,2.9e-16},{1000,5.2e-16} })

-- The repository's own dataset, for the four shipped reactions. Zero outside the table's range
-- becomes nil so a balance has no root there rather than a spurious one at zero rate.
local function shipped(reaction)
  return function(t_k)
    local v = reactivity.reactivity(reaction, t_k)
    return v > 0 and v or nil
  end
end

------------------------------------------------------------------------------------------- fuels

-- `ions` is the ion composition -- charge and share of the TOTAL ion density -- named to match the
-- field the shipped `M.fuels` rows now carry, so `L.electrons` can be called on either. A
-- like-species fuel has one entry and carries the factor of one half in its rate, exactly as
-- reactivity.rate does. `j` and `ch` are the energy per reaction in joules and the charged fraction.
local function mix(p, z1, f1, z2, f2)
  local f = { j = p.mev * 1e6 * EV, ch = p.ch, sv = p.sv, like = (z2 == nil) }
  if z2 then f.ions = { { z = z1, frac = f1 }, { z = z2, frac = f2 } }
  else f.ions = { { z = z1, frac = 1 } } end
  return f
end

--- A fuel this mod actually ships, taken FROM THE SHIPPED ROW rather than restated here (#98).
--
-- The composition, the energy per reaction and the charged fraction all come out of
-- `M.fuels`, so the radiated powers this suite pins are pinned against the data #52 will read. That
-- is the point of doing it this way round: restating the numbers locally would have made every
-- figure below agree with itself forever while the shipped rows drifted underneath. Change a
-- plasma's `ions` and the 3.13x, the 6.34x and the 4771 MW all move, here, at the bench.
local function ship(key, sv)
  local row = L.fuels[key]
  -- The shipped table by reference, not copied element by element: nothing here mutates it, and a
  -- copy is one more thing that can be edited into disagreeing with its original.
  return { j = row.energy_per_reaction_j, ch = row.charged_fraction, sv = sv, ions = row.ions,
           like = (#row.ions == 1) }
end

local F = {}
F["D-D"]     = ship("rf-d-d-plasma", shipped("D-D"))
F["D-T"]     = ship("rf-d-t-plasma", shipped("D-T"))
F["D-He3"]   = ship("rf-d-he3-plasma", shipped("D-He3"))
F["He3-He3"] = ship("rf-he3-he3-plasma", shipped("He3-He3"))
-- The three this mod does not ship stay stated here, because there is no row to take them from.
F["T-T"]     = mix({ mev = 11.327, ch = 1.259 / 11.327,   sv = TT }, 1)
-- T-He3's branch energies are ORNL/TM-6914 Table II; 3.020 of the 13.006 MeV leaves as a neutron
-- on the 4% branch and as nothing else, so the charged fraction is high but not one.
F["T-He3"]   = mix({ mev = 13.006, ch = 1 - 3.020 / 13.006, sv = THE3 }, 1, .5, 2, .5)
local function pb11_fuel(boron, which)
  return mix({ mev = 8.68, ch = 1, sv = pb11(which) }, 1, 1 - boron, 5, boron)
end

------------------------------------------------------------------------------------ the balance

--- Every power in watts at ion temperature `t_k`, with electrons at `r * t_k`.
local function powers(f, spec, n_i, t_k, r)
  r = r or 1
  -- THE SHIPPED FUNCTION, not a second copy of it. This block used to recompute electrons per ion
  -- and Z_eff inline with the identical formula, which is the exact failure mode this change cites
  -- as its reason for deriving the two numbers rather than storing them -- two implementations, one
  -- of which gets the fix. Calling L.electrons instead means every radiated power below is testing
  -- the function #52 will call, and the non-shipped fuels above name their field `ions` so they can
  -- go through it too.
  local per_ion, z_eff = L.electrons(f)
  local n_e = n_i * per_ion
  local sv = f.sv(t_k)
  if not sv then return nil end
  local rate
  if f.like then rate = 0.5 * n_i * n_i * sv
  else rate = (n_i * f.ions[1].frac) * (n_i * f.ions[2].frac) * sv end
  local p_fus = rate * spec.volume_m3 * f.j
  -- (3/2)nkT for the ions plus the same for the electrons at their own temperature. The shipped
  -- model's 3nkT is this with n_e = n_i and r = 1.
  local loss = 1.5 * (n_i * t_k + n_e * r * t_k) * spec.volume_m3 * K_B / spec.confinement_time_s
  local x = xi(r * t_k / KEV, z_eff)
  if not x then return nil end
  return {
    p_fus = p_fus, p_ch = p_fus * f.ch, loss = loss, n_e = n_e, z_eff = z_eff,
    brem = C_B * n_e * n_e * math.sqrt(r * t_k / KEV) * x * spec.volume_m3,
  }
end

--- Net power into the plasma. Zero is an equilibrium.
local function balance(f, spec, n_i, t_k, with_brem, r, heating)
  local p = powers(f, spec, n_i, t_k, r)
  if not p then return nil end
  local h = heating or spec.heating_power_w
  return p.p_ch + h - p.loss - (with_brem and p.brem or 0), p
end

--- The temperature the balance settles at: the highest root where net power crosses from positive
--- to negative, found by bisection on a log grid. nil when there is no such crossing, which is a
--- real answer and not a failure -- a fuel that never climbs has no equilibrium to report.
local function settles(f, spec, n_i, with_brem, r, heating, lo, hi)
  lo, hi = lo or 1e6, hi or 1e10
  local prev_t, prev_v
  for i = 0, 4000 do
    local t = lo * (hi / lo) ^ (i / 4000)
    local v = balance(f, spec, n_i, t, with_brem, r, heating)
    if v and prev_v and prev_v > 0 and v <= 0 then
      local a, b = prev_t, t
      for _ = 1, 120 do
        local mid = math.sqrt(a * b)
        local fm = balance(f, spec, n_i, mid, with_brem, r, heating)
        if fm and fm > 0 then a = mid else b = mid end
      end
      return math.sqrt(a * b)
    end
    if v then prev_t, prev_v = t, v end
  end
  return nil
end

--- The best charged-fusion-to-bremsstrahlung ratio a fuel reaches at one temperature. This is the
--- number that orders the whole survey, and it is DENSITY-INDEPENDENT: both sides go as n^2, so
--- the density cancels and no confinement time, heating power or operating density can move it.
--- Above 1 a plasma can hold itself up against its own radiation; below 1 nothing reaches it.
local function best_ratio(f, spec, lo, hi)
  local best = 0
  for i = 0, 2000 do
    local t = (lo or 1e6) * ((hi or 1e10) / (lo or 1e6)) ^ (i / 2000)
    local p = powers(f, spec, 1e20, t, 1)
    if p and p.brem > 0 then
      local q = p.p_ch / p.brem
      if q > best then best = q end
    end
  end
  return best
end

------------------------------------------------------------------- validation: reduce to shipped

-- The four figures that make the rest believable. None is fitted here: set r = 1 and one singly
-- charged species and this balance IS the shipped one, so these fall out of bremsstrahlung.md's
-- own dataset. If any fails, the generalisation has stopped being a generalisation.
print("validating against docs/research/bremsstrahlung.md")

local t_dd_free = settles(F["D-D"], L.reactor, 1e20, false)
near(t_dd_free, 8.769e8, TOL, "D-D settles radiation-free at 8.769e8 K")
local _, p_dd_free = balance(F["D-D"], L.reactor, 1e20, t_dd_free, false)
near(p_dd_free.p_fus / L.reactor.heating_power_w, 2.139, TOL, "D-D radiation-free reaches Q 2.139")

local t_dd_brem = settles(F["D-D"], L.reactor, 1e20, true)
near(t_dd_brem, 2.422e8, TOL, "D-D with bremsstrahlung settles at 2.422e8 K")
local _, p_dd_brem = balance(F["D-D"], L.reactor, 1e20, t_dd_brem, true)
near(p_dd_brem.p_fus / L.reactor.heating_power_w, 0.3205, TOL, "D-D with bremsstrahlung falls to Q 0.3205")

near(settles(F["D-T"], L.reactor, 1e20, false), 4.633e9, TOL, "D-T settles radiation-free at 4.633e9 K")
near(settles(F["D-T"], L.reactor, 1e20, true), 3.264e9, TOL, "D-T with bremsstrahlung settles at 3.264e9 K")

--------------------------------------------------------------------------------- Gamow energies

-- E_G = 2 * mu c^2 * (pi * alpha * Z1 * Z2)^2, the barrier term under every reactivity
-- parameterisation. Checked against the only three published values available, which is what makes
-- the p-11B coefficient block above trustworthy: Bosch and Hale (1992) table IV give B_G^2 = 1182
-- keV for D-T and 986 keV for D(d,p)T, and Tentori and Belloni (2023) give 22 589 keV for p-11B.
local U_KEV = 931.49410242e3
local ALPHA = 1 / 137.035999084
local GAMOW_K = 2 * (math.pi * ALPHA) ^ 2
local MASS = { p = 1.00727647, D = 2.01410178, T = 3.01604928, He3 = 3.01602932,
               Li6 = 6.01512289, B11 = 11.00930536 }
local CHARGE = { p = 1, D = 1, T = 1, He3 = 2, Li6 = 3, B11 = 5 }

local function gamow(a, b)
  local mu = MASS[a] * MASS[b] / (MASS[a] + MASS[b])
  return GAMOW_K * mu * U_KEV * (CHARGE[a] * CHARGE[b]) ^ 2
end

near(gamow("D", "T"), 1182, 0.001, "Gamow energy for D-T is Bosch and Hale's 1182 keV")
near(gamow("D", "D"), 986, 0.001, "Gamow energy for D-D is Bosch and Hale's 986 keV")
near(gamow("p", "B11"), 22589, 0.001, "Gamow energy for p-11B is Tentori and Belloni's 22 589 keV")
-- And the ordering claim the note makes about the fuels it never computes a sweep for: charge
-- geometry alone disqualifies them before any cross-section is consulted.
check(gamow("He3", "Li6") > 8 * gamow("D", "T"), "He3-Li6's barrier is many times D-T's",
  string.format("%.0f against %.0f keV", gamow("He3", "Li6"), gamow("D", "T")))

--------------------------------------------------------- the finding #98 exists for: electrons

-- bremsstrahlung.md says Z_eff = 1 and n_e = n_i are "exactly right for both shipped plasmas", and
-- it was right about the two it had analysed. Helium-3 is Z = 2, so they are wrong for the other
-- two, and radiation goes as Z_eff * n_e^2 through xi.
print("checking the electron density of each shipped plasma")

local function geometry(f)
  local p = powers(f, L.reactor, 1e20, 5e8, 1)
  return p.n_e / 1e20, p.z_eff
end

local ne, zeff = geometry(F["D-D"])
near(ne, 1.00, 0, "a D-D plasma has one electron per ion")
near(zeff, 1.00, 0, "a D-D plasma has Z_eff 1")
ne, zeff = geometry(F["D-T"])
near(ne, 1.00, 0, "a D-T plasma has one electron per ion")
near(zeff, 1.00, 0, "a D-T plasma has Z_eff 1")
ne, zeff = geometry(F["D-He3"])
near(ne, 1.50, 0, "a D-He3 plasma has one and a half electrons per ion")
near(zeff, 5 / 3, 1e-9, "a D-He3 plasma has Z_eff 1.67")
ne, zeff = geometry(F["He3-He3"])
near(ne, 2.00, 0, "a He3-He3 plasma has two electrons per ion")
near(zeff, 2.00, 0, "a He3-He3 plasma has Z_eff 2")

-- What that costs, at the clamp in the reactor these two fuels actually burn in. The factor is not
-- simply Z_eff * (n_e/n_i)^2 because xi's electron-electron term does not scale with charge.
local A = L.aneutronic_reactor
local t_clamp = A.max_temperature_c + 273.15
local function understatement(f)
  local p = powers(f, A, 3e20, t_clamp, 1)
  local naive = C_B * 3e20 * 3e20 * math.sqrt(t_clamp / KEV) * xi(t_clamp / KEV, 1) * A.volume_m3
  return p.brem / naive, p.brem
end

local factor_dhe3, brem_dhe3 = understatement(F["D-He3"])
near(factor_dhe3, 3.13, 0.01, "hydrogen's constants understate D-He3's radiation by 3.13x")
local factor_he3, brem_he3 = understatement(F["He3-He3"])
near(factor_he3, 6.34, 0.01, "hydrogen's constants understate He3-He3's radiation by 6.34x")
near(brem_dhe3 / 1e6, 4771, 0.01, "D-He3 radiates 4771 MW at the clamp")
near(brem_he3 / 1e6, 9672, 0.01, "He3-He3 radiates 9672 MW at the clamp")

-------------------------------------------------------------------------- the ordering, and why

-- The single number that orders the survey. Three fuels are above 1 and all three already ship;
-- everything the note surveys is below it, and so is one of the three tiers that ships.
print("ranking every fuel by charged fusion power against its own bremsstrahlung")

-- D-T IS THE ONE CELL THIS HARNESS DISAGREES WITH THE NOTE ABOUT, and it is pinned at what the
-- code computes rather than at what the note prints. further-reactions.md's ordering table says
-- 13.0; sweeping temperature at T_e = T_i gives a maximum of 27.7 at about 26 keV, and the same
-- sweep reproduces every other cell of that table -- D-He3 4.3, D-D 1.07, T-He3 0.58, p-11B 0.52,
-- T-T 0.21, He3-He3 0.06 -- as well as all four of bremsstrahlung.md's published equilibria and
-- all three published Gamow energies. So the disagreement is one number, not a method.
--
-- It was not resolved by making the assertion pass. What it is NOT is a threat to the note's
-- argument: the table exists to sort fuels either side of 1, and 27.7 and 13.0 are the same answer
-- to that question, with D-T first either way. The note should be corrected or the 13.0 explained;
-- until then this is the reproducible figure and that is why it is the asserted one.
near(best_ratio(F["D-T"], L.reactor), 27.7, 0.05, "D-T reaches 27.7x its bremsstrahlung, not the note's 13.0")
near(best_ratio(F["D-He3"], L.reactor), 4.3, 0.05, "D-He3 reaches 4.3x")
near(best_ratio(F["D-D"], L.reactor), 1.07, 0.05, "D-D reaches 1.07x, barely above the line")
near(best_ratio(F["T-He3"], L.reactor), 0.58, TOL_NRL, "T-He3 reaches 0.58x and cannot hold itself up")
near(best_ratio(F["T-T"], L.reactor), 0.21, TOL_NRL, "T-T reaches 0.21x")
near(best_ratio(F["He3-He3"], L.reactor), 0.06, 0.05, "He3-He3 reaches 0.06x")

-- p-11B, the reaction the whole question is usually asked about. It fails at one temperature under
-- both published fits and at every boron fraction, and the note's claim is the maximum over all of
-- them. Sweeping the fraction is the check, not asserting one mix.
local best_pb11 = 0
for _, which in ipairs({ "ns", "tb" }) do
  for i = 1, 24 do
    local r = best_ratio(pb11_fuel(i * 0.02, which), L.reactor, 70 * KEV, 500 * KEV)
    if r > best_pb11 then best_pb11 = r end
  end
end
near(best_pb11, 0.52, 0.05, "p-11B reaches 0.52x at best over both fits and every boron fraction")
check(best_pb11 < 1, "p-11B cannot hold itself up at one temperature, whatever the mix",
  string.format("best ratio %.3f", best_pb11))

-- And the structural point: p-11B's published window exists only because its electrons are colder
-- than its ions. Give it that and it clears the line, which is what makes this a model limit rather
-- than a property of the fuel.
local cold = 0
for i = 1, 24 do
  local f = pb11_fuel(i * 0.02, "tb")
  for j = 0, 200 do
    local t = 70 * KEV * (500 / 70) ^ (j / 200)
    local p = powers(f, L.reactor, 1e20, t, 0.5)
    if p and p.brem > 0 and p.p_ch / p.brem > cold then cold = p.p_ch / p.brem end
  end
end
check(cold > 1, "p-11B does clear the line once its electrons are held at half the ion temperature",
  string.format("best ratio %.3f at T_e = T_i/2", cold))

------------------------------------------------------------- what that does to the shipped tiers

print("checking what the radiation term does to the aneutronic tiers as shipped")

-- He3-He3 has no ignited state at all: there is nothing above the cold root to climb to, at any
-- heating power, because its fusion power never approaches its radiation anywhere in the dataset.
local t_he3_shipped = settles(F["He3-He3"], A, 3e20, true)
check(t_he3_shipped ~= nil and t_he3_shipped < 1e7,
  "He3-He3 as shipped settles at the cold root once radiation is counted",
  t_he3_shipped and string.format("%.3g K", t_he3_shipped) or "no equilibrium at all")

-- The Q the tier ships, taken from the SHIPPED step() rather than from the balance above, because
-- that is the number the tier actually reports and the one the note calls an artefact. The clamp is
-- where it lands: reactor-logic's own comment says this tier "cannot reach its optimum", and the
-- clamp is how far up it gets.
local shipped_step = L.step(A, "rf-he3-he3-plasma", 3000, A.max_temperature_c, A.heating_power_w, 1)
check(shipped_step ~= nil, "the shipped model has a He3-He3 step at the clamp")
near(shipped_step.q_factor, 1.31, 0.01, "the shipped He3-He3 tier reports Q 1.31 at the clamp")
-- And the point: the same fuel, once its own radiation is charged against it, cannot get near the
-- temperature that Q was read at.
check(t_he3_shipped ~= nil and t_he3_shipped < 0.01 * (A.max_temperature_c + 273.15),
  "with radiation counted it settles below a hundredth of that temperature",
  t_he3_shipped and string.format("%.3g K against a clamp at %.3g K",
    t_he3_shipped, A.max_temperature_c + 273.15) or "no equilibrium")

-- D-He3 is trapped rather than dead, and the distinction is the whole of its entry in the note:
-- 200 MW cannot climb out of the cold root, four times it can, and past that the fuel is good.
local t_dhe3_shipped = settles(F["D-He3"], A, 3e20, true)
check(t_dhe3_shipped ~= nil and t_dhe3_shipped < 1e8,
  "D-He3 at its shipped 200 MW sits at the cold root",
  t_dhe3_shipped and string.format("%.3g K", t_dhe3_shipped) or "no equilibrium")
local t_dhe3_800 = settles(F["D-He3"], A, 3e20, true, 1, 800e6)
check(t_dhe3_800 ~= nil and t_dhe3_800 > 1e9,
  "four times the heating clears it and it ignites",
  t_dhe3_800 and string.format("%.3g K", t_dhe3_800) or "still trapped")

-- The reason it is worth clearing: above the wall it is a genuinely good fuel.
local p_dhe3_clamp = powers(F["D-He3"], A, 3e20, t_clamp, 1)
near(p_dhe3_clamp.p_ch / p_dhe3_clamp.brem, 3.48, 0.02,
  "D-He3 runs at 3.48x its bremsstrahlung at the clamp")

------------------------------------------------------------------------- T-He3, the cheapest add

-- The candidate the note puts first on cost: an even mix of two isotopes the mod already breeds,
-- so no uneven-mix support is needed and no new chain step. On the model AS IT SHIPS -- no
-- radiation term -- it beats the tier it would sit beside by an order of magnitude.
-- Read AT THE CLAMP rather than at an equilibrium, and the difference is not bookkeeping: T-He3
-- radiation-free is ignited, so there is no root to find -- it climbs until the clamp stops it,
-- exactly as reactor-logic.lua records D-T doing. `settles` correctly returns nil for it, which is
-- what caught this: asking a runaway fuel where it settles is the wrong question.
local p_the3 = powers(F["T-He3"], A, 3e20, t_clamp, 1)
check(p_the3 ~= nil, "T-He3 has reactivity data at the clamp")
near(p_the3.p_fus / A.heating_power_w, 16.6, TOL_NRL, "T-He3 reaches Q 16.6 radiation-free at the clamp")
check(p_the3.p_fus / A.heating_power_w > 10 * shipped_step.q_factor,
  "which is more than ten times what the He3-He3 tier beside it reports",
  string.format("%.3g against %.3g", p_the3.p_fus / A.heating_power_w, shipped_step.q_factor))
-- Its charged fraction is the reason ADR 0018's geometry cannot express it: 77% wants the direct
-- converter and the remaining 23% wants a steam stage, and one category per box allows only one.
near(F["T-He3"].ch, 0.768, 0.005, "T-He3 is 77% charged, so it wants both conversion routes at once")

------------------------------------------------------------------------- catalysed D-D, for size

-- Not modellable here -- three reactant pairs in one plasma is a different step() -- but its size
-- is arithmetic off the NRL formulary's own four reactions, and it is the largest number in the
-- note, so it is worth pinning against the plain D-D it would replace.
local CATALYSED = 4.03 + 3.27 + 17.59 + 18.35      -- 6 D -> 2 He4 + 2 p + 2 n
near(CATALYSED / 6, 7.21, 0.005, "catalysed D-D yields 7.21 MeV per deuteron")
near((CATALYSED / 6) / (3.65 / 2), 3.95, 0.01, "which is 3.9x plain D-D's 1.82 MeV per deuteron")

H.finish()
