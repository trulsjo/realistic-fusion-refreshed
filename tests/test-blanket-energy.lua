-- What a lithium blanket releases per neutron, pinned (#91).
--
-- Run from the repository root:   lua tests/test-blanket-energy.lua
--
-- WHY THIS EXISTS. ADR 0019 sells the blanket's capture heat and defers the figure to
-- docs/research/blanket-capture-energy.md, which derives 4.537 MeV per neutron entering the
-- blanket from published masses and the shipped breeding ratio. A note is prose, and the one thing
-- prose cannot do is notice that somebody moved `tritium_per_neutron`. This file notices: every net
-- figure below is computed against M.blanket as the shipped module holds it, so a balance pass on
-- the ratio fails the suite rather than silently invalidating the note.
--
-- AND NOTHING RUNS IT FOR YOU. There is no CI here and no scripts/*.ps1 invokes the Lua tests, so
-- that sentence is only true of somebody who types the command above. Stated rather than glossed,
-- the same way tests/test-bremsstrahlung.lua states it.
--
-- WHAT IT DOES NOT COVER: breed(). It returns no joules yet -- that is #93 -- so there is nothing
-- shipped here to check against. This suite is the arithmetic #93's implementation gets checked
-- against, which is the order #51 and #52 used.
--
-- Like the other tests here it runs outside Factorio (ADR 0005), written to Lua 5.2 semantics and
-- verified on 5.4.

package.path = "tests/?.lua;realistic-fusion-refreshed/?.lua;" .. package.path
local H = require("harness")
local L = require("scripts.reactor-logic")
local check, near = H.check, H.near

-- AME2020 mass excesses in keV, unrounded, from the evaluation's own mass_1.mas20.txt.
-- M. Wang et al., Chinese Physics C 45 (2021) 030003. See the note's Sources section for the URL.
--
-- ATOMIC mass excesses, used without an electron correction on purpose: lithium's three electrons
-- are exactly tritium's one plus helium's two, so they cancel in both reactions below. That step is
-- what silently poisons this kind of arithmetic when it does not hold, so it is asserted rather
-- than assumed -- see ELECTRON BALANCE below.
local D = {
  n   =  8071.31806,
  H3  = 14949.81090,
  He4 =  2424.91587,
  Li6 = 14086.88044,
  Li7 = 14907.10463,
  Be9 = 11348.451,
}

-- Atomic masses in u, same source, for the one place a mass ratio rather than a mass difference is
-- wanted: the lab-frame threshold of the endothermic branch.
local U = { n = 1.00866491590, Li7 = 7.016003434 }

-- Electrons in the neutral atom, for the balance assertion below.
local Z = { n = 0, H3 = 1, He4 = 2, Li6 = 3, Li7 = 3 }

print("the two capture reactions, from AME2020 mass excesses")

check(Z.Li6 + Z.n == Z.H3 + Z.He4,
  "ELECTRON BALANCE: Li-6 + n has the same electron count as T + He-4")
check(Z.Li7 + Z.n == Z.H3 + Z.He4 + Z.n,
  "ELECTRON BALANCE: Li-7 + n has the same electron count as T + He-4 + n")

-- Q = sum of reactant mass excesses minus sum of product ones. In MeV.
local Q6 = (D.Li6 + D.n - D.H3 - D.He4) / 1000
local Q7 = (D.Li7 + D.n - (D.H3 + D.He4 + D.n)) / 1000

near(Q6,  4.78347, 1e-5, "Q of n + Li-6 -> T + He-4, MeV")
near(Q7, -2.46762, 1e-5, "Q of n + Li-7 -> T + He-4 + n', MeV")
check(Q6 > 0, "the Li-6 branch is exothermic")
check(Q7 < 0, "the Li-7 branch is endothermic")

-- The Li-7 branch also costs the recoil, so its lab threshold is above |Q|. Getting this wrong by
-- using |Q| directly would put the threshold at 2.468 MeV, which is still above D-D's 2.45 MeV
-- neutrons -- so the conclusion below would survive the error and the error would survive with it.
local threshold = -Q7 * (U.Li7 + U.n) / U.Li7
near(threshold, 2.8224, 1e-4, "lab-frame threshold of the Li-7 branch, MeV")
check(threshold > -Q7, "the threshold is above |Q|, because the recoil has to be paid for too")

-- The two tiers' neutrons, from reactor-logic.lua's own comments on M.fuels.
local DD_NEUTRON_MEV, DT_NEUTRON_MEV = 2.45, 14.06
check(DD_NEUTRON_MEV < threshold, "D-D's neutrons are BELOW the Li-7 threshold and do not multiply")
check(DT_NEUTRON_MEV > threshold, "D-T's neutrons are ABOVE it and do")

print("the blend, fixed by the neutron balance rather than assumed")

--- Net capture energy per neutron entering the blanket, in MeV, for a breeding ratio.
--
-- The whole derivation, in one line, and the reason the mod must not store this beside the ratio.
-- A Li-6 capture DESTROYS the neutron and a Li-7 reaction HANDS IT BACK, so in a blanket that
-- leaks nothing and holds nothing but lithium, every neutron ends its life in exactly one Li-6
-- capture. That fixes the Li-6 term at 1 whatever the ratio is, and leaves the Li-7 reactions to
-- account for the rest of the tritons: tbr - 1 of them, each costing |Q7|.
local function net_mev_per_neutron(tbr)
  return 1 * Q6 + (tbr - 1) * Q7
end

-- The neutron balance stated as its own assertion rather than left implicit in the function, since
-- it is the step a reader is most likely to want to argue with.
local function split(tbr) return 1, tbr - 1 end

local li6, li7 = split(1.1)
near(li6, 1.0, 1e-12, "Li-6 captures per incident neutron, at TBR 1.1")
near(li7, 0.1, 1e-12, "Li-7 reactions per incident neutron, at TBR 1.1")
near(li6 + li7, 1.1, 1e-12, "and the two make one triton each, so they sum to the ratio")

-- Read from the shipped module, not written down here. This is the assertion that makes the whole
-- file a guard rather than a calculator: move tritium_per_neutron and this suite fails, which is
-- the only thing standing between docs/research/blanket-capture-energy.md and quiet rot.
local TBR = L.blanket.tritium_per_neutron
near(TBR, 1.1, 1e-12,
  "M.blanket.tritium_per_neutron is still 1.1 -- if it moved, re-derive the note's figures")

local net_per_neutron = net_mev_per_neutron(TBR)
local net_per_triton  = net_per_neutron / TBR
near(net_per_neutron, 4.53671, 1e-5, "net MeV per neutron entering the blanket, at the shipped TBR")
near(net_per_triton,  4.12428, 1e-5, "net MeV per triton bred, which is the form breed() wants")
check(net_per_neutron < Q6,
  "the endothermic branch costs something, so the net is BELOW the 4.783 MeV ceiling")
near((Q6 - net_per_neutron) / Q6, 0.0516, 1e-2, "and what it costs is 5.2% of the ceiling")

print("the formula, against the note's table")

near(net_mev_per_neutron(1.00), 4.7835, 1e-4, "TBR 1.00 gives the pure Li-6 ceiling")
near(net_mev_per_neutron(1.10), 4.5367, 1e-4, "TBR 1.10, the shipped ratio")
near(net_mev_per_neutron(1.15), 4.4133, 1e-4, "TBR 1.15, the top of the design band")
near(net_mev_per_neutron(1.30), 4.0432, 1e-4, "TBR 1.30, a multiplier-assisted design")
near(net_mev_per_neutron(1.15) / 1.15, 3.8377, 1e-4, "per triton at TBR 1.15")
near(net_mev_per_neutron(1.30) / 1.30, 3.1102, 1e-4, "per triton at TBR 1.30")

print("the double-count trap, as arithmetic")

-- The reason #91 exists. A published energy multiplication factor already contains the neutron's
-- kinetic energy, which step() sells separately at fusion_j - charged_j. Adding M x E_n as the
-- blanket's contribution sells the neutron twice; these two checks are what that costs, so the
-- number is on record rather than in a paragraph.
local M_PUBLISHED = 1.2
local double_counted = M_PUBLISHED * DT_NEUTRON_MEV
local stripped       = (M_PUBLISHED - 1) * DT_NEUTRON_MEV
near(double_counted, 16.872, 1e-3, "M x E_n at M = 1.2, which is what a naive import would add")
near(double_counted / net_per_neutron, 3.719, 1e-3, "and it is 3.7x the derived figure")
near(stripped, 2.812, 1e-3, "(M - 1) x E_n strips the kinetic energy out correctly")
check(stripped < net_per_neutron,
  "and still undershoots, because a published M is measured on a blanket with structure to absorb "
  .. "into and multipliers to pay for")

-- The cross-check run the honest way round: turn the derived figure into an M and compare with the
-- literature band, rather than importing one. Just above 1.3 is the expected place for an idealised
-- lithium-only blanket, and the note says why.
local m_implied = (DT_NEUTRON_MEV + net_per_neutron) / DT_NEUTRON_MEV
near(m_implied, 1.3227, 1e-4, "the implied energy multiplication factor for a D-T neutron")
check(m_implied > 1.3,
  "which sits just ABOVE the published 1.1-1.3 band, as an idealised lithium blanket should")

-- Beryllium is how real designs buy the ratio back, and it is endothermic: quoted here so the note's
-- claim that a bought ratio is bought out of the heat is checkable rather than asserted.
local Q_be = (D.Be9 + D.n - 2 * D.He4 - 2 * D.n) / 1000
near(Q_be, -1.5727, 1e-3, "Q of Be-9(n,2n)2He-4, MeV -- the multiplier costs energy")
check(Q_be < 0, "so a TBR bought with beryllium is bought out of the heat")

print("what it adds per reaction, and what that is NOT")

-- Basis-free: the per-neutron figure times the reaction's neutron yield. reactor-logic.lua holds
-- both yields, so these are read rather than written down.
local dd = L.fuels["rf-d-d-plasma"]
local dt = L.fuels["rf-d-t-plasma"]
near(dd.neutrons_per_reaction, 0.5, 1e-12, "D-D releases half a neutron per reaction")
near(dt.neutrons_per_reaction, 1.0, 1e-12, "D-T releases one")
near(dt.neutrons_per_reaction * net_per_neutron, 4.5367, 1e-4, "so a D-T reaction gains 4.537 MeV")
near(dd.neutrons_per_reaction * net_per_neutron, 2.2684, 1e-4, "and a D-D reaction gains 2.268 MeV")

-- The ratios against each tier's own TOTAL release, which is the basis ADR 0019's table used and
-- not the basis a player reads. Corrected here from that table's 4.78 ceiling to the 4.537 net;
-- the share signal's own denominator is sold energy, which is an equilibrium quantity and has to be
-- measured once #93 lands rather than derived here.
local EV = 1.602176634e-19
local dd_release_mev = dd.energy_per_reaction_j / EV / 1e6
local dt_release_mev = dt.energy_per_reaction_j / EV / 1e6
near(dd_release_mev,  3.65, 1e-6, "D-D's total release, from the shipped row")
near(dt_release_mev, 17.59, 1e-6, "D-T's total release, from the shipped row")
near(dt.neutrons_per_reaction * net_per_neutron / dt_release_mev, 0.2579, 1e-3,
  "D-T gains 25.8% of its own release, against ADR 0019's provisional +27%")
near(dd.neutrons_per_reaction * net_per_neutron / dd_release_mev, 0.6215, 1e-3,
  "D-D gains 62.1%, against ADR 0019's provisional +65%")

print("the neutron-energy omission, sized rather than modelled")

-- What the single blended ratio costs D-D, both ways round, which is the finding question 2 turns
-- on: the energy error is the SMALLER of the two and they partly cancel in the sold total.
local dd_physical_tbr = 1.0
local dd_physical_per_neutron = net_mev_per_neutron(dd_physical_tbr)
near(dd_physical_per_neutron, 4.7835, 1e-4,
  "below the threshold there is no Li-7 branch, so D-D's physical figure is the ceiling")
near(net_per_neutron / dd_physical_per_neutron - 1, -0.0516, 1e-2,
  "the shipped blend charges D-D 5.2% too little ENERGY per neutron")
near(TBR / dd_physical_tbr - 1, 0.10, 1e-6,
  "and credits it 10% too much TRITIUM -- the larger error, and the one already documented")
check(math.abs(net_per_neutron / dd_physical_per_neutron - 1) < math.abs(TBR / dd_physical_tbr - 1),
  "so fixing the energy alone would be picking the smaller of two errors")

H.finish()
