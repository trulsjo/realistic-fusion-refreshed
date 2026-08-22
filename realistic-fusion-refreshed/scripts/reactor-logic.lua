-- The reactor simulation: one step of the plasma power balance.
--
-- Pure Lua, like scripts/reactivity.lua and for the same reason (ADR 0005): the physics is
-- isolated from the tick cadence, so throttling to a coarser cadence is a change in control.lua
-- alone and never a rewrite of this file. Nothing here touches data, game, storage, settings, or
-- any of table_size / serpent / log / localised_print, which is what lets tests/test-reactor-logic.lua
-- run it outside Factorio.
--
-- Written to Lua 5.2.1 (what Factorio 2.0.77 runs) and verified on standalone 5.4.6.
--
-- THE MODEL
--
-- A zero-dimensional power balance, which is the standard first model of a confined plasma:
--
--     dE/dt = P_heating + P_charged - E / tau
--
-- Thermal energy accumulates from external heating and from the charged fusion products that stay
-- behind, and leaks away over a confinement time. Temperature is that energy divided by the heat
-- capacity of the particles present, and the reaction rate is read from cross-section data at that
-- temperature -- so temperature is a state variable the reactor drives, not a constant it is given.
--
-- Everything that leaves the plasma is what the reactor sells: neutrons, which are not confined at
-- all, plus the transport loss into the first wall. Charged products are not counted twice -- they
-- self-heat first and leave through the loss channel afterwards.
--
-- Balance numbers live in the prototype spec passed in, not here, and are provisional.

local reactivity = require("scripts.reactivity")

local M = {}

local K_B = 1.380649e-23  -- J/K
local CELSIUS_TO_KELVIN = 273.15

-- Bremsstrahlung (#52). The plasma radiates X-rays and they leave, which is the loss channel this
-- model carried none of until now. docs/research/bremsstrahlung.md has the derivation, the primary
-- sources and the arithmetic; what matters here is the shape:
--
--     P_brem = C_B * n_e^2 * sqrt(T_e[keV]) * xi(T_e, Z_eff)   W/m^3
--
-- Z_eff lives INSIDE xi rather than multiplying it, because the relativistic correction splits into
-- an electron-ion part that scales with charge and an electron-electron part that does not. Setting
-- xi = Z_eff recovers the non-relativistic form, which is the limit as T goes to zero.
--
-- n_e IS NOT n_i AND Z_eff IS NOT 1 (#98). Both come off the fuel row through M.electrons, so a
-- D-He3 plasma radiates against 1.5 electrons per ion at Z_eff 5/3 and a He3-He3 plasma against 2.0
-- at Z_eff 2. Assuming hydrogen would understate those two by 3.13x and 6.34x.
--
-- KNOWN LIMITATION, RECORDED RATHER THAN GUARDED: this is free-free emission from a FULLY IONISED
-- plasma, and it is applied at every temperature including ones where that is not true. Below a few
-- eV -- tens of thousands of degrees -- hydrogen is only partly ionised, line radiation is the
-- channel that would actually dominate, and this formula is out of its domain. The effect is that a
-- sub-fusion plasma radiates harder than it should: around 350 kW against 200 kJ of thermal content
-- at 5e4 C, so it falls to min_temperature_c in under a second.
--
-- Left as it is deliberately. Nothing downstream turns on it -- a reactor that cold is not fusing
-- either way, and confinement heating is two orders larger than the radiated power, so start-up and
-- re-ignition are unaffected (scripts/check-brownout.ps1 measures both). Gating the term on an
-- ionisation threshold would mean inventing a constant to fix a state nothing reads, which is the
-- wrong trade. What it DID change is one rig's tolerance -- see check-observability.ps1's idle case.
local C_B = 5.34e-37       -- W m^3 keV^-1/2, NRL Plasma Formulary (2019) p. 58 in SI
local KELVIN_PER_KEV = 1.1604518e7
local MEC2_KEV = 511       -- electron rest energy; the correction's fit stops here

--- The relativistic correction to bremsstrahlung, which is not optional at these temperatures.
--
-- The plain sqrt(T) form is non-relativistic and understates the radiation by 10-20% at the D-D
-- settling point and more above it. #51 exists because two implementations of this term disagreed by
-- about that much, and the resolution was that one of them had dropped this factor -- so leaving it
-- out would reintroduce the exact discrepancy that ticket closed.
--
-- ABOVE 511 keV THE FIT IS OUT OF DOMAIN and this holds it at its edge value rather than
-- extrapolating. That UNDERSTATES radiation above 5.93e9 K, stated because it is a real limit and
-- because #58 may raise max_temperature_c: no shipped reactor reaches it (both clamp at 2e9 K, or
-- 172 keV) but a future one could, and it should find this note rather than a silent extrapolation.
local function radiation_factor(t_kev, z_eff)
  local t = t_kev / MEC2_KEV
  if t >= 1 then t = 1 - 1e-9 end
  return z_eff * (1 + 1.78 * t ^ 1.34) + 2.12 * t * (1 + 1.1 * t + t * t - 1.25 * t ^ 2.5)
end

-- What each plasma is made of and what it releases, keyed by the fluid the reactor is holding.
-- Adding a tier (#31) is a row here plus prototypes; the code below does not change.
--
-- Every row carries `fractions`: what share of the plasma's nuclei each side of the reaction is.
-- It exists because a rate goes as the product of the two reactant densities, and a fluid unit is
-- a count of nuclei rather than of either species. A single-fuel plasma is entirely its own
-- reactant, so both shares are 1; a mixed plasma splits, and feeding the whole density twice would
-- overstate its rate by the reciprocal of the product. It is stated per row rather than derived
-- from the reaction name because it is a property of the FUEL -- what a heater put in the pipe --
-- rather than of the reaction.
--
-- EVEN MIXES AND LIKE SPECIES ONLY, and this is a limit of the model rather than of the field.
-- Below, the burn is capped at particles / fuel_per_reaction and the fuel is drawn down as a single
-- fluid, so both sides are assumed to run out together. An uneven mix would break both: the reactor
-- would go on reacting after the scarce side was gone, and would drain the abundant side to pay for
-- it. Supporting one means tracking the two species separately, which is a fluid apiece and a
-- different model, not another field here. tests/test-reactor-logic.lua asserts the invariant so a
-- row that assumed otherwise fails at the bench rather than in a save.
--
-- D-D runs two branches at roughly equal rates:
--     D + D -> T (1.01 MeV) + p (3.02 MeV)   -- 4.03 MeV, entirely charged
--     D + D -> He3 (0.82 MeV) + n (2.45 MeV) -- 3.27 MeV, of which 0.82 is charged
-- so the mean release is 3.65 MeV and the charged share is 4.85/7.30.
--
-- The two branches are also where tritium and helium-3 come from, which is what makes the reactors
-- the breeder (CONTEXT.md, ADR 0010) rather than a separate machine: half the reactions leave a
-- triton behind and half leave a helium-3, so breeding is the same reaction count the energy is
-- computed from and cannot drift away from it.
M.fuels = {
  ["rf-d-d-plasma"] = {
    reaction = "D-D",
    energy_per_reaction_j = 3.65e6 * 1.602176634e-19,
    charged_fraction = 4.85 / 7.30,
    -- Deuterium against deuterium: every nucleus present is both reactants at once. The
    -- double-counting that follows from that is reactivity.rate's to undo, not this table's --
    -- D-D is in its LIKE_SPECIES set and carries a factor of one half there.
    fractions = { 1, 1 },
    -- The ion POPULATION, as nuclear charge and share of the total ion density (#98). One species,
    -- bare deuterons: one electron each and Z_eff 1. This is the hydrogenic case
    -- docs/research/bremsstrahlung.md was written against, and it is correct for this row.
    ions = { { z = 1, frac = 1 } },
    -- Nuclei consumed per reaction. Two, because both sides of D-D are deuterium.
    fuel_per_reaction = 2,
    -- Nuclei of each product per reaction, counted at the same particles_per_unit as the plasma so
    -- the whole model needs one density constant rather than one per fluid. The proton the first
    -- branch also releases is not modelled: there is no hydrogen sink for it in ADR 0010's fluid
    -- set. The neutron the second one releases IS modelled, one field down.
    products = { ["rf-tritium"] = 0.5, ["rf-helium-3"] = 0.5 },
    -- Neutrons escaping per reaction, which is what a lithium blanket has to work with (#30).
    --
    -- Half, and it is the SAME half as the helium-3 above rather than a second estimate of it: only
    -- the He3 + n branch makes a neutron, so every helium-3 this plasma breeds left a neutron with
    -- it. tests/test-reactor-logic.lua asserts the two are equal for exactly that reason -- if a
    -- later edit moves the branch split it has to move both, and this is what refuses to let one
    -- drift away from the other.
    --
    -- They are 2.45 MeV neutrons where D-T's are 14.06, which the blanket model does not
    -- distinguish; see M.blanket for what that costs.
    neutrons_per_reaction = 0.5,
  },

  -- D + T -> He4 (3.52 MeV) + n (14.06 MeV), a single branch releasing 17.59 MeV.
  --
  -- The reaction the whole D-D tier exists to reach (#28). It is the easiest fusion there is: five
  -- times the energy of a mean D-D reaction, and a cross-section that is orders of magnitude larger
  -- at every temperature a reactor can actually hold. What it costs is tritium, which does not
  -- occur in nature in any useful quantity and has to be bred -- so this tier runs on what the last
  -- one left behind, and that is the progression rather than a bigger number.
  ["rf-d-t-plasma"] = {
    reaction = "D-T",
    energy_per_reaction_j = 17.59e6 * 1.602176634e-19,
    -- Only the alpha is confined. The neutron carries four fifths of the release straight through
    -- the wall, which is why D-T self-heats proportionally far less than D-D despite releasing
    -- nearly five times as much -- and why almost all of it is available to sell.
    charged_fraction = 3.52 / 17.59,
    -- An even blend, because rf-d-t-mixing makes one: one deuteron and one triton per reaction.
    fractions = { 0.5, 0.5 },
    -- Two species and both singly charged, so this plasma is hydrogenic too: one electron per ion
    -- and Z_eff 1, the same as D-D by a different route. Written as two entries rather than
    -- collapsed into one because the population IS two species -- collapsing it would make the row
    -- disagree with `fractions` about what is in the box.
    ions = { { z = 1, frac = 0.5 }, { z = 1, frac = 0.5 } },
    -- One nucleus from each side, so two out of the box -- the same as D-D, arrived at differently.
    fuel_per_reaction = 2,
    -- No products. The alpha is helium-4, which ADR 0010's fluid set does not contain, and the
    -- neutron is what this mod already sells as reactor energy. A D-T reactor therefore needs no
    -- collector -- nothing comes out of it but power, unless a blanket is fitted.
    --
    -- One neutron per reaction, and this is the tier the blanket exists for (#30). Where D-D
    -- vents a neutron on half its reactions, every D-T reaction makes one, and at four fifths of
    -- the release rather than three quarters -- so the same reactor offers a blanket twice the
    -- neutrons per reaction while burning the tritium the blanket breeds. That is what closes the
    -- loop: a D-T reactor consumes one triton per reaction and a blanket over it breeds
    -- tritium_per_neutron of one back, which is the whole reason real designs are built this way.
    neutrons_per_reaction = 1,
    --
    -- IT IGNITES, and that is the tier's defining behaviour rather than a balance number.
    --
    -- D-D settles: heating plus self-heating balance the confinement loss and the radiation partway
    -- up the curve, and the plasma sits at about 2.42e8 C and Q 0.32. D-T at this density and
    -- passes Lawson by more than an order of magnitude, so the alpha heating alone outruns the loss
    -- term and the temperature climbs until the cross-section falls off past its peak. Left
    -- unbounded the model finds a real equilibrium out at 4.6e9 C; what it actually meets first is
    -- the clamp at max_temperature_c, and the plasma parks there.
    --
    -- The clamp is therefore load-bearing on this tier where it was decoration on the last one, and
    -- it stays for one reason that holds: int32 stops at 2.147e9, so a plasma allowed past 2e9 would
    -- start truncating its own temperature circuit signal (scripts/circuit-output.lua). Energy is
    -- not lost at the clamp -- step() sells everything the plasma cannot hold -- so nothing is
    -- created or destroyed by it; it is a ceiling on the state variable, not on the accounting.
    --
    -- It was ALSO justified as standing in for bremsstrahlung, back when this model carried no
    -- radiation at all. #52 put the term in, so the clamp no longer stands in for anything -- but
    -- the reasoning is kept because it was wrong for reasons worth not repeating, and because the
    -- clamp survived on the int32 argument alone (docs/research/bremsstrahlung.md, against the NRL
    -- Plasma Formulary):
    --
    --   * Bremsstrahlung does not bite "long before" 4.6e9. It moves the equilibrium to 3.26e9 --
    --     real, but still half again above both this clamp and the int32 ceiling. Adding the term
    --     would NOT unpin the temperature reading, which is the thing anyone would add it for.
    --   * The clamp is not standing in for it. The clamp sheds about 640 MW at 2e9 where
    --     bremsstrahlung is 169 MW -- four times too small to be what the clamp is doing.
    --   * It is not the dominant omission either. Unreabsorbed cyclotron radiation at these
    --     temperatures is two to three orders larger; it is absent because it cannot be written in
    --     one line, not because it is small.
    --
    -- And the part that mattered most: adding bremsstrahlung would cost the tier that works. It did.
    -- D-D fell from Q 2.14 to Q 0.32 -- exactly as predicted -- because a D-D plasma at 1e20 m^-3
    -- with 30 s of confinement is genuinely nowhere near ignition. ADR 0015 accepted that before the
    -- term was written, which is why this is a decision that was taken rather than a fix that was
    -- applied. **D-T is unaffected in behaviour**: it passes Lawson by orders of magnitude either
    -- way, and the term moves its unbounded equilibrium to 3.26e9, still above this clamp.
    --
    -- What this costs in game is that the temperature reading is pinned for every D-T reactor, so
    -- the fuel line rather than the temperature is the throttle: an ignited reactor burns exactly
    -- what it is fed and its output follows. tests/test-reactor-logic.lua asserts that, and
    -- docs/research/d-t-ignition.md has the measurements. The levers that would actually reach the
    -- int32 ceiling are confinement_time_s and the plasma's purity, not a radiation term -- both
    -- re-tune D-D as well, so both are balance decisions. Balance is provisional, as everywhere.
  },

  -- D + He3 -> He4 (3.6 MeV) + p (14.7 MeV), a single branch releasing 18.353 MeV (#31).
  --
  -- THE FIRST ANEUTRONIC TIER, and that word is the whole of what it buys. Both products are
  -- charged, so nothing leaves the plasma as a neutron: no first-wall activation, no blanket, no
  -- neutron budget to spend. In this mod it is what makes direct energy conversion possible at all
  -- -- rf-direct-energy-converter collects charged particles and there is nothing to collect from a
  -- reaction that vents four fifths of its release as neutrons (ADR 0010's chain, step 5).
  --
  -- What it costs is temperature. D-He3's cross-section peaks at 230 keV against D-T's 65, and it
  -- is three and a half times smaller at its peak -- so this reaction wants a hotter, denser
  -- machine, which is what M.aneutronic_reactor below is.
  ["rf-d-he3-plasma"] = {
    reaction = "D-He3",
    energy_per_reaction_j = 18.353e6 * 1.602176634e-19,
    -- Every joule. He4 and the proton are both charged, so the whole release stays in the plasma
    -- and self-heats it, and every joule the reactor sells left through the transport channel
    -- rather than as radiation past the wall. That is not a modelling convenience: it is the
    -- physical claim direct energy conversion rests on.
    charged_fraction = 1,
    -- An even blend, because rf-d-he3-mixing makes one: one deuteron and one helium-3 per reaction.
    fractions = { 0.5, 0.5 },
    -- AND HERE THE HYDROGENIC ASSUMPTION BREAKS (#98). Helium-3 is Z = 2, so an even mix carries
    -- 1.5 electrons per ion and Z_eff = 5/3, not 1 and 1. bremsstrahlung.md says those constants
    -- are "exactly right for both shipped plasmas" and it was right about the two it had analysed;
    -- this is not one of them. Radiation goes as Z_eff * n_e^2, so a term that assumed hydrogen
    -- would understate this plasma's by more than a factor of three.
    ions = { { z = 1, frac = 0.5 }, { z = 2, frac = 0.5 } },
    fuel_per_reaction = 2,
    -- No products in ADR 0010's fluid set -- helium-4 and hydrogen are not modelled, the same
    -- omission D-D's proton already carries.
    --
    -- AND NO NEUTRONS, which is the tier. Stated as a number rather than left absent so
    -- control.lua's check_fuel_rows sees a real answer: a blanket bolted to a reactor burning this
    -- breeds nothing, and does so by arithmetic rather than by a missing field.
    --
    -- The honest caveat, because "aneutronic" is a claim and this one is only nearly true: a real
    -- D-He3 plasma still contains deuterium, so it runs D-D on the side and those reactions do make
    -- neutrons -- a few percent of the fusion power in most designs. This model burns one reaction
    -- per plasma, so the side branch is not simulated, and the mod is therefore slightly kinder to
    -- this tier than physics is. Modelling it means two reactions from one fluid, which is a
    -- different step() rather than another field here.
    neutrons_per_reaction = 0,
  },

  -- He3 + He3 -> He4 + 2p, releasing 12.859 MeV. The end of ADR 0010's chain (step 6).
  --
  -- The only reaction here with no deuterium in it at all, and that is its point rather than its
  -- power: it burns one fuel, which the D-D reactors have been breeding since the first tier, and
  -- it is aneutronic on both branches rather than nearly so -- there is no D-D side reaction to
  -- caveat, because there is no deuterium to run one.
  --
  -- IT IS ALSO THE HARDEST REACTION IN THE MOD BY A LONG WAY, and the reactor cannot reach its
  -- optimum. Its cross-section peaks past 600 keV -- above the top of the ENDF-derived dataset --
  -- where max_temperature_c stops the plasma at 172 keV, so it burns at about a hundredth of its
  -- peak reactivity. That is not a balance choice: the clamp is there because a plasma past 2e9
  -- truncates its own temperature circuit signal (see rf-d-t-plasma above), and this reaction
  -- wants to run three times hotter than that ceiling.
  --
  -- RE-ANCHORED BY #52, AND THE CLAMP IS NO LONGER THE BINDING CONSTRAINT. This said the tier
  -- "arrives at Q 1.31, barely above break-even, where D-He3 in the same machine reaches Q 82.8",
  -- both settling at the clamp with only their distance from their own peak separating them. Those
  -- were figures from a model that carried no radiation, and helium-3 is the worst case for that
  -- omission: at Z = 2 it brings two electrons per nucleus, so it radiates against 6.34x what a
  -- hydrogenic plasma of the same ion density would (#98).
  --
  -- With the term counted, no fill ignites this reaction. Thinning the plasma does reach the clamp,
  -- but on heater power rather than on fusion -- Q peaks at 0.0131 around 300 units, which is not
  -- ignition in CONTEXT.md's sense at all. D-He3 in the same machine is fine at half fill (Q 20.7)
  -- and trapped at full, so the two tiers now differ in kind rather than in degree: one has an
  -- operating density and the other has no operating point.
  --
  -- AND THE CLAMP IS NO LONGER THE LEVER, which matters because #58 exists to raise it. Measured
  -- with the term carried, lifting max_temperature_c does nothing for this reaction: Q saturates at
  -- 0.0224 and stops improving past 3e9, because radiation now sets the equilibrium before the
  -- ceiling does. The same test gave Q 16 at a 7e9 ceiling before #52. Whatever rescues this tier is
  -- not the clamp.
  --
  -- DECIDED: LEFT AS IT IS, for now (Truls, 2026-08-21, #52's last criterion). ADR 0014 makes a
  -- marginal tier legitimate, and keeping this one costs almost nothing in code -- the row, the fluid
  -- and the technology all already exist, where removing it would mean deleting prototypes and
  -- superseding ADR 0010's prototype set. The cost is a player's, not the codebase's: someone
  -- researches the last tier and finds it will not fuse. Nothing here may be tuned to hide that.
  -- tests/test-reactor-logic.lua carries the fill sweeps.
  ["rf-he3-he3-plasma"] = {
    reaction = "He3-He3",
    energy_per_reaction_j = 12.859e6 * 1.602176634e-19,
    charged_fraction = 1,
    -- Helium-3 against helium-3: every nucleus is both reactants, so both shares are one and the
    -- double-counting is reactivity.rate's to undo -- He3-He3 is in its LIKE_SPECIES set, the same
    -- as D-D.
    fractions = { 1, 1 },
    -- The furthest of the four from hydrogen (#98): one species, but doubly charged, so a full
    -- reactor holds TWO electrons per ion and Z_eff = 2. Between the two terms that is eight times
    -- hydrogen's electron-ion radiation for the same ion density, and it is the reason this tier's
    -- shipped Q is an artefact of the missing term rather than a balance figure -- see
    -- docs/research/further-reactions.md.
    ions = { { z = 2, frac = 1 } },
    fuel_per_reaction = 2,
    neutrons_per_reaction = 0,
  },
}

--- The electron density and effective charge of a plasma, from its ion population (#98).
--
-- Returns electrons per ion and Z_eff, both per unit of TOTAL ion density -- so a caller with an ion
-- density multiplies the first by it and gets n_e. Quasineutrality gives the first (every bound
-- electron came off some nucleus, so n_e = sum of frac*z) and the standard definition gives the
-- second (sum of frac*z^2 over sum of frac*z).
--
-- DERIVED RATHER THAN STORED, and that is the whole reason this is a function. #98 asks that each
-- row "carry its electrons per ion and its Z_eff"; storing those two numbers beside `ions` would let
-- them contradict it, and a plasma whose declared electron count disagrees with its declared
-- composition is a bug nothing would catch. The charges are the physical fact; these two follow.
--
-- CALLED BY step() SINCE #52, which is what it was written for: the radiation term above reads both
-- numbers from here rather than assuming hydrogen, and so does the heat capacity.
-- tests/test-reactor-logic.lua asserts the four values, and
-- tests/test-further-reactions.lua carries what they cost against the real radiation formula.
--
-- AND `ions` IS DELIBERATELY NOT IN control.lua's FUEL_FIELDS, which is the list that makes a row
-- missing a field refuse to load. It belongs there the moment the radiation term reads it -- a
-- plasma with no composition would then compute no radiation, silently, which is exactly the class
-- of fault that list exists to catch. Until then the bench test covers every row including a new
-- one, and refusing to start a game over a field nothing reads would be out of proportion.
function M.electrons(fuel)
  local n_e, z2n = 0, 0
  for _, ion in ipairs(fuel.ions or {}) do
    n_e = n_e + ion.frac * ion.z
    z2n = z2n + ion.frac * ion.z * ion.z
  end
  -- A row with no composition, or one whose shares are all zero, would otherwise return 0/0 -- and
  -- a nan electron density does not raise anything, it propagates into the radiation term and out
  -- the far side as a plasma that radiates nothing. Loud beats silent: this is the one case where
  -- the caller cannot recover and must not continue.
  if n_e <= 0 then
    error("reactor-logic: a plasma must declare at least one ion species with a positive share; "
      .. "M.fuels row for " .. tostring(fuel.reaction) .. " declares no usable `ions`.")
  end
  return n_e, z2n / n_e
end

-- What the shipped rf-reactor is made of. Kept here rather than in control.lua so the tests run
-- against the same numbers the game does, and passed into step() rather than read from it so a
-- later tier can be a different reactor without a second copy of the physics.
--
-- Left running with the plasma kept full, these reach about 2.42e8 C at Q 0.32, selling 56.1 MW
-- against the 50 MW of heating they draw. It takes minutes rather than seconds to get there: fusion
-- self-heating is positive feedback, so the plasma is still climbing long after the thirty-second
-- confinement time would suggest it had settled.
--
-- RE-ANCHORED BY #52. These read 8.8e8 C, Q 2.1 and 133 MW before the radiation term went in, and
-- that equilibrium was an artefact of a loss channel the model did not carry. The tier is now below
-- SCIENTIFIC break-even (Q < 1) by decision -- ADR 0015 calls it a breeder tier, whose product is
-- fuel rather than electricity.
--
-- It is NOT below engineering break-even, and that is worth knowing before quoting either number:
-- a plant pays for itself when Q >= (1 - capture_efficiency) / capture_efficiency, which here is
-- 0.1765, and 0.32 clears it. The radiated X-rays are not thrown away -- they heat the first wall
-- and step() sells them -- so the reactor makes marginally more than it consumes. See the shipped
-- balance block in tests/test-reactor-logic.lua for why that leaves ADR 0015's wording in tension
-- with its own arithmetic.
--
-- Provisional, like every other balance number in this repository.
M.reactor = {
  -- Plasma volume. ITER is about 800 m^3.
  volume_m3 = 1000,
  -- Nuclei per unit of plasma fluid. With a 1000-unit fluid box that is 1e20 m^-3 in a full
  -- reactor, which is the density a real machine runs at.
  particles_per_unit = 1e20,
  -- Confinement heating. Spent out of the reactor's electric buffer by control.lua rather than
  -- declared on the prototype: the prototype's own energy_consumption is the boiler conversion
  -- this mod does not use, and is deliberately nearly zero.
  heating_power_w = 50e6,
  -- Energy confinement time: how long the plasma holds its heat. This is the reactor's defining
  -- statistic -- it decides the temperature the heating settles at, and therefore, through the
  -- cross-section data, everything else.
  confinement_time_s = 30,
  -- What is recovered of everything leaving the plasma. Below 1 because Factorio's steam turbines
  -- lose nothing, so at 1 a reactor that never fuses would pay for its own heating forever; it
  -- also stands in for the divertor, cryoplant and magnet power that v1 does not model.
  capture_efficiency = 0.85,
  -- rf-reactor-energy's fuel_value. One unit, one megajoule.
  energy_fluid_j_per_unit = 1e6,
  -- What this reactor sells its output as. Stated on the spec rather than in control.lua because
  -- the aneutronic reactor below sells a different fluid into a different converter (#31), and
  -- apply() should be writing whatever the reactor it is applying says rather than one name the
  -- whole mod shares.
  energy_fluid = "rf-reactor-energy",
  -- rf-d-d-plasma's default_temperature and max_temperature.
  --
  -- LEFT AT 15 DELIBERATELY, and it was nearly raised. #46 wanted the boiler's own conversion shut
  -- off entirely, and #101 showed how: that conversion is exactly zero whenever plasma is at or
  -- above the target, so a floor above the target closes it forever. A floor at a few eV -- the
  -- boundary the bremsstrahlung note above names as where this model becomes valid -- would have
  -- done it.
  --
  -- Rejected on the cost of holding it. The clamp below puts a cooling plasma back up to this
  -- number, so the floor is held against radiation by energy that comes from nowhere, and
  -- bremsstrahlung goes as sqrt(T): a full cold reactor already conjures about 27 kW to hold 15 C,
  -- and 3 eV would have made it 292 kW. Trading 6.7 W of unaccounted output for another 266 kW of
  -- conjured heat is the wrong direction, however invisible the conjured half is -- left_j is
  -- floored at zero below, so none of it is ever sold.
  --
  -- What was taken instead: rf-reactor's target went to 550, which shrinks the leak to 1.9 W for
  -- nothing, because the rate goes as 1/(target - floor). See prototypes/entities.lua.
  --
  -- THE CONJURED HEAT IS NOT A NEW PROBLEM AND IS NOT SOLVED HERE -- it is #103. Same class as the
  -- 34 W loop the comment on left_j records closing, and unsold and therefore invisible, which is
  -- exactly why it has survived this long.
  --
  -- MEASURED under #103 rather than derived: step() reports conjured_j, and
  -- tests/test-reactor-logic.lua pins 26.6 kW for a full D-D reactor here -- and 322 kW for a full
  -- He3-He3 one, which is the worst case in the mod.
  --
  -- THE TWO ARE NOT THE SAME EFFECT, which is what measuring showed and deriving could not. Here the
  -- clamp restores bremsstrahlung PLUS the confinement loss, so the scaling is nearly n^2 and
  -- measurably not exactly so. On the aneutronic tier the joint clamp below is SATURATED at any fill
  -- worth having -- unscaled bremsstrahlung is six times what the plasma has to give, so loss_j and
  -- brems_j scale down to sum to exactly kept_j, new_thermal_j lands on zero, and the whole thermal
  -- content is conjured back every step. That caps the figure at kept_j/dt and makes it scale as n
  -- rather than n^2: 322 kW is a heat capacity, not a radiated power.
  --
  -- Do not change this line for #103 without reading that ticket: the obvious repairs each ask what
  -- a plasma below the floor IS, and this simulation has no answer to that today.
  min_temperature_c = 15,
  max_temperature_c = 2e9,
}

-- What the shipped rf-aneutronic-reactor is made of (#31).
--
-- The second machine, and ADR 0010 names it separately for a reason this table is the whole of:
-- D-He3 and He3-He3 want conditions the first reactor does not reach. It is the same physics, the
-- same step() and the same file -- a reactor is its constants, which is exactly what ADR 0005 set
-- out to make true.
--
-- WHAT IS DIFFERENT, and why each one:
M.aneutronic_reactor = {
  -- Same plasma volume. The machine is bigger on the ground but the confinement region is not the
  -- part that grew; what grew is what is inside it.
  volume_m3 = 1000,
  -- THE SAME nuclei per unit as the neutronic reactor, deliberately. One nuclei-per-unit constant
  -- for the whole mod is what keeps a fluid unit meaning the same thing everywhere -- the lithium
  -- blanket's one-item-one-unit identity rests on it (M.blanket), and a second value here would
  -- silently make a unit of plasma mean different things in different pipes.
  --
  -- The density comes from the fluid box instead: rf-aneutronic-reactor holds 3000 units in the
  -- same 1000 m^3, so a full one runs at 3e20 m^-3 where a full rf-reactor runs at 1e20. That is
  -- the lever, and it is the right one -- fusion rate goes as n^2 while the transport loss goes as
  -- n, so density is what buys ignition, and a denser machine is what the aneutronic tier is.
  particles_per_unit = 1e20,
  -- Four times the confinement heating. D-He3 needs about 230 keV against D-T's 65 to reach its
  -- peak, and a plasma is not taken there by hoping.
  heating_power_w = 200e6,
  -- Twice the confinement time. Engineering rather than physics, and ADR 0014 is explicit that
  -- this mod may put it anywhere the physics permits -- so a later, harder machine holding its
  -- heat twice as long is exactly the kind of progression that ADR sanctions. It is also what
  -- makes He3-He3 reach its equilibrium at all.
  confinement_time_s = 60,
  -- Higher than the neutronic reactor's 0.85, and this is the tier's actual physical payoff.
  -- Both aneutronic reactions release everything as charged particles, which arrive on collector
  -- plates and are converted electrostatically, rather than as heat crossing a first wall into a
  -- steam loop. Less is lost to the structure because less of it ever becomes heat.
  --
  -- It is NOT a large gain and should not be read as one: 0.95 against 0.85 is a tenth. What the
  -- tier really buys is that there is no steam stage to build -- one converter where the neutronic
  -- side needs a heat exchanger, water and a row of turbines.
  --
  -- AND IT IS THE NUMBER THAT KEEPS THE LOOP CLOSED, which matters more here than on the last tier
  -- and is why it must not drift up. capture_efficiency exists because Factorio's turbines lose
  -- nothing, so at 1 a reactor that never fuses would sell back exactly the heating it was given
  -- and pay for itself for ever. This tier runs that margin tighter than any other: a cold
  -- aneutronic reactor returns 190 MW of sellable fluid for the 200 MW spent heating it. Still
  -- negative, so still not a free loop -- but at 1.0 it would be, and there is no other term
  -- standing between this constant and perpetual motion.
  capture_efficiency = 0.95,
  energy_fluid_j_per_unit = 1e6,
  energy_fluid = "rf-aneutronic-reactor-energy",
  -- The same bounds, and the same reason: 2e9 is where a temperature stops fitting in the int32 a
  -- circuit signal is. It costs this tier more than it costs the last one -- He3-He3 wants to run
  -- past 7e9 -- and that cost is stated on its fuel row rather than hidden here.
  min_temperature_c = 15,
  max_temperature_c = 2e9,
}

-- What the shipped rf-lithium-blanket is made of (#30).
--
-- A blanket is a shell of lithium around the reactor that catches escaping neutrons and turns them
-- into tritium. It is the route real D-T machines are designed around, and the upgrade that
-- decouples D-T throughput from what the D-D tier happens to leave behind (CONTEXT.md names the
-- two routes; ADR 0010 makes this one the later of them).
--
-- Its own table rather than fields on M.reactor, for the reason M.reactor is passed in rather than
-- read: the blanket is a separate entity a player may or may not have built, and a later tier may
-- ship a different one. breed() takes both.
M.blanket = {
  -- Tritons bred per escaping neutron -- the tritium breeding ratio, the number every blanket
  -- design is judged by. Above one because a blanket multiplies neutrons before it captures them:
  --
  --     n + Li-6  -> T + He4        + 4.78 MeV   exothermic, and the reaction that does the work
  --     n + Li-7  -> T + He4 + n'   - 2.47 MeV   endothermic, and hands the neutron back on
  --
  -- so one neutron entering can leave more than one triton behind. Real designs add beryllium or
  -- lead as a further multiplier and aim at 1.05 to 1.15, because a D-T plant has to breed back
  -- every triton it burns plus its losses and its start-up inventory. 1.1 is the middle of that
  -- band and is provisional like every other balance number in this repository.
  --
  -- What this deliberately does NOT model is that the ratio depends on the neutron's energy: D-T's
  -- 14.06 MeV neutrons are above the Li-7 threshold and multiply, where D-D's 2.45 MeV ones are
  -- not and do not. A D-D blanket should therefore breed nearer 0.9 than 1.1. Modelling it means a
  -- per-fuel ratio rather than a per-blanket one -- which is a row in M.fuels, not a rewrite -- and
  -- it is left out here because the tier the blanket exists for is D-T, and because inventing two
  -- numbers where the field's own figures are quoted for one is a worse lie than quoting the one.
  tritium_per_neutron = 1.1,
  -- Lithium nuclei in one rf-lithium item, which is what makes an item count and a fluid unit
  -- commensurable. The same 1e20 as M.reactor.particles_per_unit, and equal to it on purpose:
  -- one lithium nucleus is spent per triton bred, so one item in is one unit of tritium out and
  -- the accounting a player can do in their head is the accounting the model does.
  --
  -- What it costs, stated rather than glossed: 1e20 atoms of lithium-6 is 1.0 mg, three orders
  -- below the gram vanilla's uranium item works out at (docs/research/fission.md). So an
  -- rf-lithium item is not a gram-scale thing, and the reason it is this size is the identity
  -- above rather than a mass anyone measured. Raising it to 1e23 would put the item at a gram and
  -- take blanket consumption to one item every thirteen minutes per reactor, which is a balance
  -- decision about how visible the lithium line should be and not a physics one.
  lithium_nuclei_per_item = 1e20,
}

--- One simulation step for one reactor.
--
-- @param spec           reactor constants -- M.reactor holds the shipped ones
-- @param fluid_name     the plasma the reactor holds, or nil when it holds nothing
-- @param amount         plasma, in fluid units
-- @param temperature_c  plasma temperature in degrees celsius, as the fluidbox reports it
-- @param available_j    electrical energy the reactor may spend this step
-- @param dt             seconds since the last step
-- @return nil when there is nothing to simulate, otherwise a table of what happened
-- Returning nil leaves the reactor untouched, which for a fluid with no entry above means the
-- reactor holds it and does nothing with it forever, reporting itself starved the whole time.
--
-- That used to be unreachable because the prototype filtered its input box to rf-d-d-plasma. It is
-- reachable now: #28 removed the filter so one reactor could burn either plasma. What covers it
-- instead is control.lua's check_every_plasma_burns, which refuses to load when a plasma-heating
-- recipe makes a fluid with no row above -- at load, in front of whoever added it, rather than in
-- front of a player wondering why their reactor is idle.
function M.step(spec, fluid_name, amount, temperature_c, available_j, dt)
  local fuel = fluid_name and M.fuels[fluid_name]
  if not fuel or not amount or amount <= 0 or not dt or dt <= 0 then return nil end

  local particles = amount * spec.particles_per_unit
  local density = particles / spec.volume_m3
  local t_k = (temperature_c or 0) + CELSIUS_TO_KELVIN
  if t_k < 0 then t_k = 0 end

  -- Electrons per ion and effective charge, from the fuel's own composition (#98). Both terms below
  -- need them: the heat capacity because the electrons have to be heated too, and the radiation
  -- because it goes as Z_eff n_e^2.
  local per_ion, z_eff = M.electrons(fuel)

  -- (3/2)NkT for the ions and as much again PER ELECTRON, not once.
  --
  -- This was a flat 3 before #52 -- (3/2) for the ions plus (3/2) for one electron each -- which is
  -- exactly right for D-D and D-T and wrong for the other two. A helium-3 nucleus brings two
  -- electrons, so a full He3-He3 plasma has three particles to heat per ion rather than two, and its
  -- heat capacity is 4.5 NkT rather than 3. D-He3 is 3.75. The hydrogenic pair is untouched:
  -- 1.5 * (1 + 1) is 3, the constant this replaces.
  local heat_per_particle = 1.5 * (1 + per_ion) * K_B
  local thermal_j = particles * heat_per_particle * t_k

  -- Reactions this step, from the interpolated reactivity. Capped at the fuel actually present:
  -- without the cap a long step at a high rate burns more deuterium than the reactor holds and
  -- the particle count goes negative.
  --
  -- The cap counts nuclei, not sides, which is what makes one expression right for both shipped
  -- rows: D-D takes two deuterons from one pool, D-T takes one nucleus from each half of an even
  -- one, and either way it is two out of the box. It is also where the even-mix assumption above
  -- lives -- an uneven mix would run past its scarce side here.
  local reactions = reactivity.rate(fuel.reaction, t_k,
    density * fuel.fractions[1], density * fuel.fractions[2]) * spec.volume_m3 * dt
  local burnable = particles / fuel.fuel_per_reaction
  if reactions > burnable then reactions = burnable end

  local fusion_j = reactions * fuel.energy_per_reaction_j
  local charged_j = fusion_j * fuel.charged_fraction

  local heating_j = spec.heating_power_w * dt
  if available_j and available_j < heating_j then heating_j = available_j end
  if heating_j < 0 then heating_j = 0 end

  local burnt = reactions * fuel.fuel_per_reaction
  local remaining = particles - burnt
  -- Burnt fuel leaves with its share of the thermal energy. Without this, consuming fuel would
  -- heat the remainder for free. That share is not sold either -- it leaves with the ash rather
  -- than through the wall -- which is a real gap in the accounting and a rounding error in
  -- practice: about a fifth of a percent per second at the shipped settling point.
  local kept_j = (remaining > 0) and (thermal_j * remaining / particles) or 0

  -- The term the heating has to beat. It is why temperature settles at a value instead of
  -- climbing without limit, and why a reactor that loses power cools down rather than freezing
  -- in place.
  --
  -- Taken against the plasma that is still there rather than against the plasma the step started
  -- with. The difference is nothing at the shipped burn rate and stops being nothing if a later
  -- tier burns a large fraction in one step: charging loss on burnt fuel would over-cool, and
  -- would let captured_j below sell energy the plasma never had.
  local loss_j = kept_j * dt / spec.confinement_time_s
  if loss_j > kept_j then loss_j = kept_j end

  -- Bremsstrahlung (#52). Against the plasma still present and at the temperature it started the
  -- step at, both for the same reason loss_j is: charging radiation on fuel that has already been
  -- burnt would over-cool, and would let captured_j below sell energy the plasma never had.
  local brems_j = 0
  if remaining > 0 and t_k > 0 then
    local t_kev = t_k / KELVIN_PER_KEV
    local n_e = per_ion * remaining / spec.volume_m3
    brems_j = C_B * n_e * n_e * math.sqrt(t_kev)
      * radiation_factor(t_kev, z_eff) * spec.volume_m3 * dt
  end

  -- CLAMPED JOINTLY, not one after the other. Each is bounded by kept_j on its own, but a hot thin
  -- plasma can have either one alone smaller than what it holds and the two together larger -- and
  -- then new_thermal_j goes negative, the temperature pins to the minimum, and left_j sells the
  -- difference. That is energy from nothing, and it is the same free loop capture_efficiency exists
  -- to prevent. Scaled rather than truncated so the two keep their ratio, which is what makes the
  -- radiated share of a cooling plasma stay meaningful instead of being whatever was subtracted
  -- first.
  local drained_j = loss_j + brems_j
  if drained_j > kept_j then
    local scale = kept_j / drained_j
    loss_j = loss_j * scale
    brems_j = brems_j * scale
  end

  local new_thermal_j = kept_j + heating_j + charged_j - loss_j - brems_j

  local new_temperature_c = spec.min_temperature_c
  if remaining > 0 then
    new_temperature_c = new_thermal_j / (remaining * heat_per_particle) - CELSIUS_TO_KELVIN
    if new_temperature_c > spec.max_temperature_c then new_temperature_c = spec.max_temperature_c end
    if new_temperature_c < spec.min_temperature_c then new_temperature_c = spec.min_temperature_c end
  end

  -- What the plasma actually ends the step holding, after the clamps above -- which is not
  -- new_thermal_j whenever a clamp bit. Selling loss_j instead was a slow leak of energy from
  -- nothing: at the bottom of the range the temperature is put back up to the minimum, so the
  -- plasma keeps the energy, and charging the same joules to the output as well paid a full cold
  -- reactor about 34 W for ever. Small, and exactly the free loop capture_efficiency exists to
  -- prevent, so it is closed by asking what left rather than by asking what was lost.
  --
  -- It works at the top of the range too, in the other direction: energy above max_temperature
  -- used to be discarded silently, and is now sold, because it did leave the plasma.
  local retained_j = 0
  if remaining > 0 then
    retained_j = remaining * heat_per_particle * (new_temperature_c + CELSIUS_TO_KELVIN)
  end
  local left_j = kept_j + heating_j + charged_j - retained_j
  if left_j < 0 then left_j = 0 end

  -- ENERGY THIS STEP CREATED FROM NOTHING, reported rather than derived (#103).
  --
  -- When the LOW clamp bites, retained_j is larger than the plasma physically has: the temperature
  -- was put back up to min_temperature_c, so the joules radiated away below the floor are handed
  -- back. Nobody pays for them. The high clamp is the opposite case and is not this -- there
  -- retained_j is smaller, and the difference leaves through left_j above, correctly, because it
  -- really did leave the plasma.
  --
  -- Reported as conjured_power_w below because #103 asks for it MEASURED rather than argued, and
  -- because deriving it outside this function would mean a second implementation of the clamp --
  -- the mistake #51 was opened about. Nothing reads it in the mod; tests/test-reactor-logic.lua
  -- does, and pins 26.6 kW here against 322 kW on a full He3-He3 reactor.
  --
  -- It does NOT reach the player: left_j is floored at zero just above, so a plasma held at the
  -- floor sells nothing. That is the property the tests pin, and the whole reason this has gone
  -- unnoticed. See docs/research/target-temperature.md.
  local conjured_j = retained_j - new_thermal_j
  if conjured_j < 0 then conjured_j = 0 end

  -- capture_efficiency is what stops a reactor that never fuses from being a free 100% electric
  -- to thermal to electric loop: Factorio's steam turbines lose nothing, so without a loss here a
  -- cold reactor would exactly pay for its own heating forever. It also stands in for everything
  -- v1 does not model -- divertor, cryoplant, magnet power.
  local captured_j = ((fusion_j - charged_j) + left_j) * spec.capture_efficiency

  -- What the reaction leaves behind, in fluid units. Computed from the same (capped) reaction
  -- count as the energy above, so a reactor that burns dry mid-step breeds against the fuel that
  -- was actually there. Always a table when the fuel declares products, so callers never have to
  -- distinguish "bred nothing" from "breeds nothing".
  local products
  if fuel.products then
    products = {}
    for name, per_reaction in pairs(fuel.products) do
      products[name] = reactions * per_reaction / spec.particles_per_unit
    end
  end

  return {
    temperature_c   = new_temperature_c,
    plasma_consumed = burnt / spec.particles_per_unit,
    products        = products,
    -- Escaping neutrons, as a count, from the same capped reaction count everything else here is
    -- computed from. Reported whether or not a blanket exists to catch them, for the reason
    -- products are: what the plasma does cannot depend on what a player bolted to the outside of
    -- it, so fitting a blanket later starts breeding at once rather than having a backlog to
    -- account for. breed() below is what turns this into tritium.
    neutrons         = reactions * fuel.neutrons_per_reaction,
    energy_units     = captured_j / spec.energy_fluid_j_per_unit,
    heating_used_j   = heating_j,
    -- What the clamp created from nothing this step, as a power. Zero in every state except a
    -- plasma pinned at min_temperature_c. As a power rather than joules for the reason
    -- fusion_power_w is: it does not move with dt. See where it is computed (#103).
    conjured_power_w = conjured_j / dt,
    fusion_power_w   = fusion_j / dt,
    q_factor         = reactivity.q_factor(fusion_j, heating_j),
  }
end

--- The lithium one step's neutrons can consume, in nuclei.
--
-- Exists so the caller can size a withdrawal before breeding rather than after, and so that the
-- breeding ratio has exactly one definition. control.lua tops a blanket's charge up to this before
-- calling breed(); getting the two out of step means a blanket that can only ever breed as fast as
-- it takes items out of its inventory, which was a silent throughput ceiling before it was a
-- measurement (see the note in control.lua's blanket_breed).
function M.lithium_for(blanket, neutrons)
  return neutrons * blanket.tritium_per_neutron
end

--- What a lithium blanket makes of one step's neutrons (#30).
--
-- Separate from step() rather than folded into it, and the seam is deliberate: step() is the
-- plasma, and the plasma does not know whether anything is bolted to the reactor. This is the
-- shell around it, and it is a pure function of a neutron count and the lithium on hand for the
-- same reason step() is -- so tests/test-reactor-logic.lua can drive it outside Factorio.
--
-- @param spec     reactor constants, for particles_per_unit -- the blanket breeds into the same
--                 fluid units the plasma is counted in
-- @param blanket  M.blanket, or another one
-- @param neutrons escaping neutrons this step, as step() returns them
-- @param charge   lithium nuclei the blanket has left to breed from
-- @return nil when nothing happens, otherwise what was bred and what it cost
--
-- Returning nil for an empty blanket rather than a table of zeroes is what lets control.lua leave
-- the entity alone entirely, which matters because writing a fluid amount too small for the engine
-- to represent is a crash rather than a rounding error.
function M.breed(spec, blanket, neutrons, charge)
  if not neutrons or neutrons <= 0 then return nil end
  if not charge or charge <= 0 then return nil end

  -- One lithium nucleus per triton, so the tritons bred and the nuclei spent are the same number.
  -- They are separated in the return only because they are counted in different things at the far
  -- end -- fluid units against items -- and conflating those is how a blanket would silently eat
  -- its lithium at the wrong rate.
  local bred = M.lithium_for(blanket, neutrons)
  -- The cap that makes an empty blanket stop rather than breed on credit. It is the same shape as
  -- step()'s burn cap and exists for the same reason: without it the charge goes negative and the
  -- blanket keeps producing tritium out of lithium it does not have.
  if bred > charge then bred = charge end

  return {
    tritium_units = bred / spec.particles_per_unit,
    nuclei_used   = bred,
  }
end

return M
