# Further fusion reactions, and whether any of them belongs here

Researched 2026-08-21 against primary sources, and computed against the shipped model —
`realistic-fusion-refreshed/scripts/reactor-logic.lua` and `cross-section-data/reactivities.lua` at
`M.reactor` and `M.aneutronic_reactor`, driven from a standalone Lua 5.4.6 harness that requires the
repo's own modules. Nothing in the mod was changed to produce these numbers, and nothing here decides
anything: ADR 0010's reaction set is scope, scope is Truls's, and this note records options.

Also read directly: the archived four-module **redesign** at
`C:\src\factorio\_reference\realistic-fusion-dev` (22 commits, HEAD `03748ec`), whose
`RealisticFusionPower/scripts/reactor-logic.lua` ran **seven** reaction channels in one plasma in
Factorio 1.1. It is the only prior implementation of the thing several candidates here need, and it
gets its own section — [What the redesign already
did](#what-the-redesign-already-did-and-what-it-does-not-prove) — because what it proves and what it
does not are easy to swap.

**Three of this note's boundaries were widened after the first pass**, on Truls's instruction, and
nothing in the first pass became wrong — the space got larger:

- **Fuels needing a new map resource are in scope**, recorded for later rather than ruled out. The
  worldgen objection stands and is stated per candidate; it is no longer a disqualifier. See
  [Candidates that would need a new resource](#candidates-that-would-need-a-new-resource).
- **"One reaction per plasma" is one reactant *pair* per plasma.** Multiple branches of the same pair
  are already shipped — `M.fuels["rf-d-d-plasma"]` blends D-D's two into one row. So p-B11's alpha
  cascade and He3-He3's single channel need no model change at all.
- **"Even mixes only" is architectural, not arithmetical.** `reactivity.rate()` already takes two
  independent densities. What breaks is that a plasma is one Factorio fluid with one particle count,
  and ADR 0011 hands mixing to the engine.

**The harness is committed**, as
[`tests/test-further-reactions.lua`](../../tests/test-further-reactions.lua) alongside
[`tests/test-bremsstrahlung.lua`](../../tests/test-bremsstrahlung.lua), whose balance it extends —
`lua tests/test-further-reactions.lua` from the repository root, 44 checks. It was written to a
scratchpad first and landed on 2026-08-21; landing it corrected one figure in the ordering table
below and confirmed every other number in this note. See
[What is not verified](#what-is-not-verified) for what it does and does not cover, and note that
**nothing runs it for you**. What
makes them believable in the meantime is stated rather than assumed: the harness reproduces **six**
figures `bremsstrahlung.md` publishes, without being fitted to any of them — D-D at 8.769×10⁸ K and
Q 2.139 radiation-free, 2.422×10⁸ K and Q 0.3205 with the term, D-T at 4.633×10⁹ K and 3.264×10⁹ K,
and both fuels' ideal ignition bands (D-D 72–168 keV, D-T 4–409 keV against that note's 71.9–167.5 and
4.3–409). It is the shipped balance with generalisations added, not a second model.

## The short version

**Nothing here ignites, everything here dies when the bremsstrahlung term lands — and two of them
still beat the shipped top tier on the model as it stands today, for the cost of one table row each.**
That sounds contradictory and is not: the shipped top tier does not survive the term either, so the
whole question is downstream of [#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52)
rather than downstream of any reaction's merits.

Three findings carry the note, and the third is not about new reactions at all.

- **p-B11 cannot work in this model, and the reason is structural rather than a matter of tuning.**
  Its ideal-ignition window is real, it is narrow, and it exists *only* because the electrons in a
  p-B11 plasma sit at roughly half the ion temperature. **This mod's simulation has one temperature**,
  and at `T_e = T_i` p-B11's charged fusion power never exceeds **0.52 × its own bremsstrahlung** —
  that is the best it does over every boron fraction from 4% to 50% and every temperature the
  published fits cover, under either fit. The ratio is independent of density, so no confinement time,
  heating power or operating density reaches it. See
  [p-B11, followed to the primaries](#p-b11-followed-to-the-primaries).
- **The fuel-supply objection to p-B11 is the weakest objection to it**, which is worth saying because
  it is the objection a reader expects to be decisive. Boron may not even need a map resource: borate
  is an evaporite and the mod already concentrates **brine** out of water for lithium (ADR 0010), so a
  second product off `rf-brine` is a route with no worldgen at all. If it does need one, that is now a
  cost rather than a veto. **The physics is the obstacle, not the chain.**
- **Counting bremsstrahlung kills the He3-He3 tier that already ships, and makes the D-He3 tier need
  four times its heating power to light.** `bremsstrahlung.md` checked D-D and D-T and correctly said
  `Z_eff = 1` and `n_e = n_i` are "exactly right for both shipped plasmas". They are wrong for the
  other two: a helium-3 nucleus is doubly charged, so a full `rf-aneutronic-reactor` running He3-He3
  holds **two electrons per ion**, and bremsstrahlung goes as `Z_eff n_e²`. At the clamp that is
  **6.3× the radiation** the naive form gives. He3-He3 then has no ignited state at all — its charged
  fusion power is 1.7% to 6% of its bremsstrahlung everywhere in the dataset — and reaches the clamp
  only on 10.2 GW of brute-force heating at Q 0.026. See
  [What this does to the tiers that already ship](#what-this-does-to-the-tiers-that-already-ship).

Three candidates are *interesting* without being good, all three have their fuel already in the chain,
and **two of them are one `M.fuels` row each with no model change whatever**:

- **T-He3** — the best-placed candidate in the whole note on cost, and the one the corrections
  promoted. An even 1:1 mix of two isotopes the mod already breeds, so the uneven-mix problem does not
  arise; NRL tabulates its reactivity; 13.01 MeV at a **77% charged fraction**, against D-T's 20%. Its
  radiation ratio peaks at **0.58** — higher than p-B11's 0.52 — so it still cannot ignite at one
  temperature, but on the model **as it ships today**, radiation-free, it reaches **Q 16.6** at the
  clamp in `rf-aneutronic-reactor` against the shipped He3-He3 tier's Q 1.31. It also has a prior
  implementation in this mod's own lineage, and that implementation gave it the largest fudge factor
  of seven.
- **T-T** — tritium against tritium, 11.33 MeV, tritium bred two ways already. With the radiation term
  it lands at **Q 0.35**, almost exactly where D-D lands; radiation-free it is **Q 0.95** in
  `rf-reactor` and Q 14.5 at the clamp in the aneutronic one. It is 89% neutrons, needs no new fuel
  fluid, no new isotope and no new chain step — only a plasma fluid and a row — and it is a strictly
  worse use of a triton than D-T.
- **Catalysed D-D** — do not extract the tritium and helium-3, burn them where they are made.
  **7.21 MeV per deuteron against plain D-D's 1.82**, a factor of 3.9, and no new fuel of any kind.
  It is the one candidate that needs the *hard* half of the model work: three reactant pairs in one
  plasma, not several branches of one, and that is a different `step()`.

And the honest summary of the rest: **p-Li6, p-Li7, D-Li6, He3-Li6, p-N15, p-F19 and p-p all fail
worse than p-B11 does**, most of them by large factors. For p-N15, p-F19 and He3-Li6 the reason is
visible in the charge geometry before any cross-section is consulted; for p-Li6 — whose geometry is
actually *better* than p-B11's — it is Rider's own measurement, 5.36 against 1.74; for p-Li7 it is a
branching ratio that makes the reaction a neutron source at reactor energies; and p-p fails by
twenty-five orders of magnitude and is the boundary case worth knowing.

One ranking to hold on to, because it is the single number that orders the whole list — charged fusion
power over bremsstrahlung, at one temperature, at each fuel's best. **Above 1 a plasma can hold itself
up; below 1 nothing in this model reaches it, because both sides go as `n²` and the density cancels:**

| D-T | D-He3 | D-D | **T-He3** | **p-B11** | T-T | He3-He3 |
|---:|---:|---:|---:|---:|---:|---:|
| **27.7** | **4.3** | **1.07** | 0.58 | 0.52 | 0.21 | 0.06 |

Three fuels are above the line and all three already ship. Everything this note surveys is below it,
and **so is one of the three tiers that ships.**

> **Corrected 2026-08-21, when the harness was landed as `tests/test-further-reactions.lua`.** The
> D-T cell read **13.0** in the first pass and the committed sweep computes **27.7**, peaking at about
> 26 keV — well below the temperature clamp, which is why nothing else in the note moved with it. The
> same sweep reproduces every other cell unchanged, along with all four of `bremsstrahlung.md`'s
> published equilibria and all three published Gamow energies, so the fault was one number rather
> than the method. **No conclusion in this note depends on which figure is right:** the table exists
> to sort fuels either side of 1, and D-T is first and far above it either way. Where 13.0 came from
> is not known and was not reconstructed.

## What has to be true, restated as physics

Six constraints are properties of the shipped model. Four of them turn out to be one physical
statement each, and stating them that way is what makes the candidates comparable. **Two of them are
softer than they look and are stated carefully here, because getting either wrong disqualifies a
candidate that is actually cheap.**

**A reaction rate is `n₁ n₂ ⟨σv⟩`.** A fluid unit in this mod is a count of nuclei
(`particles_per_unit`), so what a full reactor gives a reaction is the *product of the two reactant
fractions*, not the density. An even mix of two species gives 0.25 n²; a like-species fuel gives
0.5 n²; **a 15% boron mix gives 0.1275 n²**. `M.fuels[...].fractions` is exactly this.

**An uneven mix is an architecture problem, not an arithmetic one, and this is the constraint most
easily overstated.** `reactivity.rate(reaction, t_k, density_a, density_b)` already takes the two
densities independently, so the physics side handles 85:15 today without a line changing. What breaks
is downstream of it: `burnable = particles / fuel_per_reaction`, `remaining`, and the thermal share
`kept_j` are **one pool**, because the plasma is one Factorio fluid with one `amount`. Splitting that
pool is not a Lua refactor:

- A `boiler` has exactly **two** fluid boxes and ADR 0018 spends both — plasma in, reactor energy
  out — so a second fuel fluid has nowhere to go on the same entity.
- **ADR 0011 makes reactors fluid-coupled**: when two reactors share a pipe, the *engine* owns the
  mixing and the mod is told only the resulting `amount` and temperature. A composition vector kept
  mod-side in `storage` would silently desync from that mixing the first time a player bridged two
  reactors — the worst failure shape available, because nothing errors.

So an uneven mix **collides with ADR 0011** rather than being impossible, and it is already on the
record as an open ADR 0011 question in
[`reactor-control-gui.md`](reactor-control-gui.md), which calls the difference out exactly: *"His
keeps a composition vector; ours keeps a fluid prototype. That single difference is the whole of the
difficulty."*

**Several branches of one reactant pair cost nothing, and the mod already does it.** This is the other
constraint worth stating precisely, because it is the difference between p-B11 needing a new `step()`
and p-B11 needing a table row. `M.fuels["rf-d-d-plasma"]` carries D-D's *two* branches as one row —
mean `energy_per_reaction_j` of 3.65 MeV, a blended `charged_fraction` of 4.85/7.30, and
`neutrons_per_reaction = 0.5` — while `reactivities.lua` keeps `D-D`, `D-D_T` and `D-D_He3` separately
so the by-product split still works. **Blend the constants, keep the branches in the dataset.** What
is genuinely hard is two or more *different reactant pairs* in one plasma, because each pair needs its
own densities and its own depletion — the same problem as the uneven mix, arriving from the other
direction. **Only catalysed D-D needs that.** p-B11's alpha cascade, He3-He3, T-T, T-He3, p-Li6 and
D-Li6's five branches are all one pair each.

Two of those are then free outright, because they are **even** mixes of things the mod already has:
**T-T** (like species) and **T-He3** (1:1) are a row apiece with no model change at all. p-B11, p-Li6
and D-Li6 could also ship today *as even mixes* — nothing forbids a 1:1 p:¹¹B plasma — but p-B11 at
1:1 sits at **0.20** of break-even against its radiation where 10% boron reaches 0.52, so the
uneven-mix work is what the reaction is worth *at its best*, not what it needs to exist.

**Bremsstrahlung is `Z_eff n_e² √T_e`.** Not `n_i²`. In a hydrogenic plasma the two are the same and
`Z_eff` is 1, which is why the shipped model can get away with carrying one density and one
temperature. **The moment a fuel contains anything heavier than hydrogen, both factors move against
it, and they move quadratically.** Boron is Z = 5, so an ion of boron brings five electrons and
contributes 25 to the `Z²n` sum.

Those two together give a figure of merit that needs no cross-section at all — the reactivity-free
part of how a fuel fares against radiation:

| fuel and mix | n_e/n_i | Z_eff | fusion factor `n₁n₂/n²` | radiation factor `Z_eff (n_e/n_i)²` | merit |
|---|---:|---:|---:|---:|---:|
| **D-D**, **T-T** | 1.00 | 1.00 | 0.500 | 1.00 | **0.500** |
| **D-T** 1:1 | 1.00 | 1.00 | 0.250 | 1.00 | **0.250** |
| **D-He3** 1:1, **T-He3** 1:1 | 1.50 | 1.67 | 0.250 | 3.75 | **0.0667** |
| **He3-He3** | 2.00 | 2.00 | 0.500 | 8.00 | **0.0625** |
| p-Li6 3:1 | 1.50 | 2.00 | 0.188 | 4.50 | 0.0417 |
| p-Li6 1:1, p-Li7 1:1, D-Li6 1:1 | 2.00 | 2.50 | 0.250 | 10.0 | 0.0250 |
| **p-B11** 15% B | 1.60 | 2.87 | 0.128 | 7.36 | **0.0173** |
| p-B11 5:1 (Rider's mix) | 1.67 | 3.00 | 0.139 | 8.33 | 0.0167 |
| He3-Li6 1:1 | 2.50 | 2.60 | 0.250 | 16.3 | 0.0154 |
| p-N15 1:1 | 4.00 | 6.25 | 0.250 | 100 | 0.0025 |
| p-F19 1:1 | 5.00 | 8.20 | 0.250 | 205 | 0.0012 |

**Read that column before reading any reactivity.** p-B11 starts a factor of 14 behind D-T and a
factor of 29 behind D-D on geometry alone, and it has to make that up on `⟨σv⟩ × E_fus` — where D-T
also beats it. The lithium fuels are worse still, and p-F19 is behind D-T by a factor of 200 before
the nuclear physics is even consulted.

**A barrier is `E_G = 2 μc² (π α Z₁Z₂)²`.** The Gamow energy is the term inside the exponential of
every reactivity parameterisation, and it goes as the *square* of the charge product. Computed here
from masses and charges, which is arithmetic rather than a claim — and validated against the only two
published values available: Bosch and Hale's `B_G²` for D-T is 1 182 keV and this gives 1 182; Tentori
and Belloni give 22 589 keV for p-B11 and this gives 22 590.

| reaction | Z₁Z₂ | E_G (keV) | × D-T |
|---|---:|---:|---:|
| p-p | 1 | 493 | 0.4 |
| D-D | 1 | 986 | 0.8 |
| **D-T** | 1 | **1 182** | 1.0 |
| T-T | 1 | 1 477 | 1.2 |
| T-He3 | 2 | 5 906 | 5.0 |
| D-He3 | 2 | 4 730 | 4.0 |
| p-Li6 | 3 | 7 603 | 6.4 |
| p-Li7 | 3 | 7 762 | 6.6 |
| D-Li6 | 3 | 13 296 | 11.2 |
| **p-B11** | 5 | **22 590** | 19.1 |
| He3-He3 | 4 | 23 625 | 20.0 |
| p-N15 | 7 | 45 286 | 38.3 |
| p-F19 | 9 | 75 864 | 64.2 |
| He3-Li6 | 6 | 70 808 | 59.9 |

**One reaction per plasma, and one temperature.** Constraint 2 in the brief, and the second half of it
is not in the brief because nobody had needed it yet. `step()` carries a single `temperature_c` and
uses it for the reaction rate; a bremsstrahlung term added the way `bremsstrahlung.md` sketches would
use the same number for the electrons. **Every published p-B11 viability window rests on the
electrons being colder than the ions.** So does He3-He3's, and so does p-Li6's.

## The physics, for a reader who does not do plasma physics

Three things, and the third is the one this note turns on.

**Charge is what makes a fuel radiate.** [`bremsstrahlung.md`](bremsstrahlung.md) explains the
mechanism: an electron flying past an ion is deflected, a deflected charge radiates, and the X-ray
leaves. The rate needs one electron and one ion, so it goes as `n_e × n_i`, and the harder the ion's
deflection the more it radiates — which is why it goes as the *square* of the ion's charge. Now count
the electrons. A plasma is neutral, so a nucleus of charge 5 arrives with five electrons in tow. Put
boron in a proton plasma and you have raised the electron count *and* the per-ion radiation, while the
number of boron nuclei available to fuse stays small. That is the whole of why "aneutronic" fuels are
hard: they are aneutronic because they are made of heavier nuclei, and heavier nuclei is exactly what
radiates.

**Fusion power rolls over; radiation does not.** Fusion reactivity climbs very steeply with
temperature, peaks, and falls. Bremsstrahlung climbs as `√T` for ever. So for each fuel there is a
band of temperatures inside which the reaction can pay its own radiation bill and outside which it
cannot — an *ideal ignition* band, which `bremsstrahlung.md` already computes for D-D (72 to 168 keV)
and D-T (4.3 to 409 keV) off this repository's own dataset. A fuel with no such band cannot be a power
source at any density, because both sides of the comparison go as `n²` and the density cancels.

**And the electrons need not be as hot as the ions.** This is the part that decides p-B11. In a real
plasma the ions are what gets heated and what fuses; the electrons are heated only by bumping into
ions, and they cool by radiating. Those two rates balance at an electron temperature *below* the ion
temperature — and since bremsstrahlung goes as `√T_e` while fusion goes as the ion temperature,
cooler electrons are a straight gain. For D-T the gap does not matter, because D-T wins by a factor of
thirteen anyway. For p-B11 the gap is the entire margin. Rider's own p-B11 case runs ions at 300 keV
and electrons at 138 keV; that ratio, 0.46, is not a design choice but the self-consistent answer.

**This model has one temperature.** `step()` holds one `temperature_c`, uses it for the reaction rate,
and would use it for the radiation. Setting `T_e = T_i` is not a small error for an advanced fuel; it
is the difference between a fuel that marginally works and one that does not work at all.

## The candidates

Q values and branch splits from the **NRL Plasma Formulary** (2019 revision), "Thermonuclear Fusion",
pp. 44–45, reactions (1)–(10), and from **McNally, Rothe and Sharp**, ORNL/TM-6914 (1979), Table II,
which gives per-product energies in keV for 31 light-isotope reactions. Peak-reactivity temperatures
for the four shipped reactions are from this repository's own dataset; the others are stated where a
source gives them and left blank where none was found.

| reaction | Q (MeV) | products, and where the energy goes | neutrons? | fuel already in the chain? |
|---|---:|---|---|---|
| **D-D** (shipped) | 3.65 mean | T+p / He3+n, 66% charged | **yes**, half the branches | yes |
| **D-T** (shipped) | 17.59 | He4 3.52 + n 14.06, 20% charged | **yes**, every reaction | yes |
| **D-He3** (shipped) | 18.353 | He4 3.6 + p 14.7, all charged | no (but see below) | yes |
| **He3-He3** (shipped) | 12.859 | He4 + 2p, all charged | no | yes |
| **T-T** | 11.33 | He4 1.259 + 2n 5.034 each — **11% charged** | **yes**, two per reaction | **yes** — tritium |
| **T-He3** | 13.01 blended | three branches; **77% charged**, 0.59 n per reaction | **yes**, on 59% of reactions | **yes** — tritium and helium-3 |
| **catalysed D-D** | 43.24 per 6 D | 2 He4 + 2p + 2n, **61.8% charged** | **yes** | **yes** — deuterium only |
| **p-B11** | 8.68 | 3 He4, all charged | no | no — needs boron |
| **p-Li6** | 4.02 | He3 2.298 + He4 1.724, all charged | no | **yes** — H and Li, but ⁶Li |
| **p-Li7** | 17.35 (20% branch) | 2 He4 8.674 each | **yes** — the **80%** branch is `Be7 + n − 1.6 MeV` | ⁷Li is the abundant one |
| **D-Li6** | 22.37 (one branch of five) | 2 He4 11.187 each | **yes** — two of five branches | H, Li, but ⁶Li |
| **He3-Li6** | 16.88 | p 12.390 + 2 He4 2.245 each | no | yes — He3 and ⁶Li |
| **p-N15** | 4.97 (not sourced primarily) | 12C + He4 | no | **no nitrogen anywhere** |
| **p-F19** | 8.11 (not sourced primarily) | 16O + He4 | no | **no fluorine anywhere** |
| **p-p** | 0.42 (1.44 with e⁺ annihilation) | d + e⁺ + ν | no | yes — hydrogen |

Two lines in that table deserve to be read twice.

**p-Li7's branching is the trap.** The formulary states plainly that branching ratios are "correct for
energies near the cross section peaks", and near the peak p-Li7 goes **80% to `Be7 + n`, which is
endothermic by 1.6 MeV**. So the reaction that looks like the best aneutronic Q value on the list —
17.35 MeV into two alphas — is, at the energies a reactor runs at, mostly a neutron source that
*consumes* energy. It is not an aneutronic fuel.

**⁶Li is 8% of lithium.** The formulary's own natural-abundance line gives `Li6/Li7 = 0.08`. Every
lithium reaction in the table above except p-Li7 wants the rare isotope, so **every one of them needs
an isotope-separation step this mod does not have.** That is not a fatal objection — the Girdler
sulfide process already in Core is an isotope separation, and a lithium-6 enrichment stage would rhyme
with it rather than clash. It is an extra chain, and it belongs in the cost column. It also collides
with something already shipped: `rf-lithium-blanket` consumes lithium without distinguishing
isotopes, and real blankets are enriched in ⁶Li for exactly this reason.

### And this is what each one does against its own bremsstrahlung

Charged fusion power divided by bremsstrahlung, at `T_e = T_i`, computed here off this repository's
dataset for the four shipped reactions and off the published fits for the rest. **Above 1 the plasma
can hold itself up; below 1 no confinement time and no density can save it**, because both sides go
as `n²` and the density cancels.

| keV → | 100 | 150 | **172** | 200 | 250 | 300 | 400 | 500 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **D-T** | 13.02 | 7.19 | **5.69** | 4.33 | 2.81 | 1.93 | 1.05 | 0.66 |
| **D-He3** | 4.33 | 3.85 | **3.48** | 3.00 | 2.26 | 1.70 | 1.00 | 0.63 |
| **D-D** | 1.07 | 1.03 | **0.99** | 0.93 | 0.82 | 0.73 | 0.58 | 0.48 |
| p-B11 10% B (T&B) | 0.25 | 0.44 | **0.49** | 0.51 | 0.50 | 0.46 | 0.36 | 0.29 |
| p-B11 15% B (T&B) | 0.23 | 0.42 | **0.46** | 0.49 | 0.48 | 0.44 | 0.35 | 0.28 |
| p-B11 15% B (N&S) | 0.20 | 0.36 | **0.39** | 0.40 | 0.38 | 0.34 | 0.25 | 0.19 |
| **T-He3** | 0.36 | 0.49 | **0.53** | 0.58 | 0.58 | 0.57 | 0.55 | 0.52 |
| **T-T** | 0.21 | 0.21 | **0.21** | 0.21 | 0.18 | 0.16 | 0.13 | 0.11 |
| **He3-He3** | 0.010 | 0.022 | **0.027** | 0.033 | 0.041 | 0.047 | 0.054 | 0.059 |

~~172 keV is bolded because it is **2×10⁹ K, the shipped `max_temperature_c`** — the hottest a plasma
in this mod is allowed to get, for the int32 reason `d-t-ignition.md` records. Everything to the right
of that column is unreachable in the game as it stands.~~

> **Both halves of that were retired on 2026-08-25.** The int32 reason went with
> [#57](https://github.com/trulsjo/realistic-fusion-refreshed/issues/57), which rescaled the signal to
> kilodegrees; the ceiling went to **5×10⁹** with
> [#58](https://github.com/trulsjo/realistic-fusion-refreshed/issues/58) and
> [ADR 0025](../adr/0025-a-plasma-temperature-ships-in-kilodegrees.md). So 172 keV is no longer the
> bound, and the columns to its right up to about 430 keV are reachable now.
>
> The table itself is unaffected — it is reactivity against temperature, not a claim about the
> ceiling. Only the sentence reading the bound off it was wrong.

Solved for the crossings rather than read off the columns — the *ideal ignition band* of each fuel,
which is the same quantity `bremsstrahlung.md` computes for the two it looked at:

| fuel | ideal ignition band, `T_e = T_i` | `bremsstrahlung.md` says |
|---|---|---|
| **D-T** | **4 keV .. 409 keV** | 4.3 keV and 409 keV |
| **D-D** | **72 keV .. 168 keV** | 71.9 keV and 167.5 keV |
| **D-He3** | **31 keV .. 400 keV** | *not computed there* |
| **T-He3** | **never crosses 1** | — |
| **T-T** | **never crosses 1** | — |
| **He3-He3** | **never crosses 1** | *not computed there* |
| **p-B11**, any mix, either fit | **never crosses 1** | — |

**The first two rows are the validation that makes the last two believable.** They reproduce that
document's published bands to the digit, from a harness written independently of the one that produced
them, so when the same harness says He3-He3 and p-B11 have no band at all it is not a different model
talking.

Four things fall out, and only the first is already written down somewhere in this repository.

**D-D is marginal and always was.** Its band is 96 keV wide, and the shipped clamp at 172 keV sits
4 keV *past* its upper edge — so a D-D plasma driven all the way to the ceiling is outside its own
ignition band, which is what the 0.99 in its 172 keV column above is saying.
`bremsstrahlung.md` calls this "the real fragility in this model"; nothing here changes it.

**D-T and D-He3 are comfortably ignitable and everything else is not.** D-He3's 31–400 keV band is
consistent with Rider's finding that "D-³He is a fusion fuel which can break even against radiation
losses in an equilibrium plasma" — and it is the *only* aneutronic reaction in this whole note of
which that is true.

**p-B11's ceiling is 0.52 and it is a broad, flat ceiling rather than a near miss.** Sweeping the
boron fraction, at `T_e = T_i`, best value over 70–500 keV:

| boron fraction | 4% | 6% | **8%** | **10%** | 12% | 15% | 20% | 25% | 50% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| best `P_charged/P_brem` | 0.41 | 0.48 | **0.51** | **0.52** | 0.51 | 0.49 | 0.45 | 0.40 | 0.20 |

The optimum is near 10% boron — leaner than the 15% the literature optimises to, because that
optimisation is done with cold electrons and this one is not — and it is flat, so there is no mix to
find. The difference between the two published reactivity fits, twenty-five years of new
cross-section measurement, moves the ceiling from 0.40 to 0.52. It does not move it to 1.

**He3-He3 is not merely marginal; it is off the bottom of the table by a factor of twenty.** That is a
finding about a tier that ships, and it has its own section below.

## p-B11, followed to the primaries

The brief asked for this one to be done properly rather than enthusiastically, so here is the argument
in the order it actually happened.

### The case against, 1979–2000

**McNally, Rothe and Sharp**, ORNL/TM-6914 (1979), is the earliest of the sources reached here to
tabulate p-B11 alongside 30 other charged-particle reactions, and the position attributed to McNally
in the modern literature is that "for thermonuclear p-11B plasmas, bremsstrahlung radiation can exceed
fusion power under broad conditions, imposing a severe power-balance constraint" (Peng *et al.* 2026,
§1.1, citing him).

**Rider**, *Phys. Plasmas* **2**, 1853 (1995), put a number on it. His Table II gives an optimised
p-B11 case — ions at 300 keV, electrons at 138 keV, 5:1 p:¹¹B, ⟨σv⟩ = 2.39×10⁻²² m³/s, E_fus 8.7 MeV
— and **P_brem/P_fus = 1.74**. For comparison the same table gives 5.36 for p-⁶Li at 500 keV and 1.42
for He3-He3 at 1 MeV, and his Table I gives 0.008 for D-T. The text is unambiguous:

> while deuteron-based fuels can theoretically produce net power despite bremsstrahlung losses, more
> advanced fuels, such as p-¹¹B, should be unable to do so

**Rider**, *Phys. Plasmas* **4**, 1039 (1997) — already cited by `bremsstrahlung.md` for its
relativistic correction — then closed the escape route. If an equilibrium p-B11 plasma cannot pay for
its radiation, the obvious move is to leave equilibrium: keep the electrons artificially cold, or run
the two ion species at different energies. His Fokker-Planck calculation prices that. Table VI,
"active refrigeration of electrons", lowering the electron temperature until `P_brem/P_fus` is 0.50:

| fuel | E_i (keV) | E_e (keV) | P_brem/P_fus | **P_recirc/P_fus** |
|---|---:|---:|---:|---:|
| D-He3 1:1 | 150 | 39 | 0.093 | 1.9 |
| D-D | 750 | 170 | 0.18 | 6.2 |
| He3-He3 | 1500 | 160 | 0.50 | 33 |
| **p-¹¹B 5:1** | **450** | **35** | **0.50** | **320** |
| p-⁶Li 3:1 | 1200 | 22 | 0.50 | 330 |

and the conclusion:

> If they could be successfully employed, the advanced aneutronic fuels ³He-³He, p-¹¹B and p-⁶Li would
> be very attractive reactor fuels […] Unfortunately, there appears to be no way to produce net power
> with any of these fuels.

**Nevins and Swain**, *Nucl. Fusion* **40**, 865 (2000), supplied the reactivity parameterisation
everyone used afterwards. Their own verdict, as Tentori and Belloni report it: "no ignition point could
be found with their reactivity". *That paper was not read directly — it is paywalled.* Its seven
coefficients were read from Tentori and Belloni's Table 2, which reprints them, and are reproduced
below. **Nevins** 1998, *J. Fusion Energy* **17**, 25, the companion confinement review, was also
**not obtained** (Springer paywall).

### The case for, 2016–2026

The counter-argument is not "Rider was wrong". It is that Rider used the cross-sections of 1979 and
assumed thermal equilibrium.

**Sikora and Weller** 2016, *J. Fusion Energy* **35**, 538, re-evaluated the ¹¹B(p,α) rates upward.
*Not obtained directly*; its effect is visible through what follows.

**Putvinski, Ryutov and Yushmanov**, *Nucl. Fusion* **59**, 076018 (2019) — the same paper
`bremsstrahlung.md` already cites for the relativistic bremsstrahlung fit — revisited p-B11
reactivity with those measurements plus a kinetic enhancement from fusion-born alphas. Its abstract:

> The net effect leads to an approximately 30% increase of the fusion yield for the same global plasma
> parameters compared to the previous assessments.

and, on the misconception the reaction is feeble:

> although being by a factor of a few lower than that for DT, is still higher than that for DD and DHe3

**That paper was not read in full** — only its abstract and the first page of the TAE-hosted copy were
reachable. Its ignition result is quoted below through Tentori and Belloni, who did read it.

**Tentori and Belloni**, *Nucl. Fusion* **63**, 086001 (2023), CC BY 4.0, **read in full**, is the
current reference parameterisation and the most important source in this section. Its introduction
states the position precisely:

> As a fusion fuel, however, the H-¹¹B plasma has an extremely low reactivity at temperatures below
> 100 keV, allowing fusion power to overcome bremsstrahlung losses only for ion temperatures between
> approximately 240 and 380 keV (in a dilute plasma at the optimal ¹¹B/H ion concentration of 15%,
> with the electron temperature calculated self-consistently) […] The existence of these ideal ignition
> conditions has been demonstrated only lately, by using a recent fusion cross section dataset for the
> calculation of the reactivity. **Ignition, however, is achieved only marginally.**

Read the parenthesis. The window exists at a specific boron fraction, in a dilute plasma, **with the
electron temperature calculated self-consistently** — that is, with `T_e < T_i`. And it is marginal.

**And the newest work has not moved that.** *Peng et al.* 2026 (arXiv:2604.04002), from ENN — a
company commercially committed to p-B11 — opens its own paper with a section headed "Challenges facing
scientific break-even of p¹¹B plasmas", concedes that Sikora and Weller's larger cross-sections
"could bring bremsstrahlung losses closer to balance with fusion power under idealized assumptions for
uniform, unmagnetized plasmas", and reaches immediately for suprathermal ions, MeV-range suprathermal
electrons and strong rotation. On the colliding-beam route it is blunt: "sustaining suprathermal
populations can require large input power, preventing attainment of Q > 1 in colliding-beam
scenarios". Putvinski's alpha-avalanche enhancement it puts at "the ~10% level under idealized
conditions".

### What that leaves, computed against this mod's own constants

Both published parameterisations were implemented here in Bosch and Hale's functional form, with the
coefficients from Tentori and Belloni's Table 2 and `E_G = 22.589 MeV` from the same paper. **The
implementation is validated end to end**: it reproduces Nevins and Swain's reactivity range over
75–500 keV to four significant figures against an independent published quotation of it
(2.455×10⁻²³ to 3.741×10⁻²² m³/s), and Tentori and Belloni's to the same precision
(2.777×10⁻²³ to 5.619×10⁻²² m³/s).

| ⟨σv⟩, m³/s | 100 keV | 150 | **172** | 200 | 250 | 300 | 400 | 500 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **D-T** (repo dataset) | 8.44e-22 | 7.28e-22 | **6.83e-22** | 6.31e-22 | 5.57e-22 | 4.99e-22 | 4.18e-22 | 3.64e-22 |
| **D-He3** (repo dataset) | 1.78e-22 | 2.38e-22 | **2.50e-22** | 2.58e-22 | 2.58e-22 | 2.49e-22 | 2.22e-22 | 1.94e-22 |
| **D-D** (repo dataset) | 5.03e-23 | 7.60e-23 | **8.62e-23** | 9.84e-23 | 1.18e-22 | 1.36e-22 | 1.68e-22 | 1.94e-22 |
| **p-B11**, Tentori & Belloni | 7.07e-23 | 1.87e-22 | **2.37e-22** | 2.96e-22 | 3.79e-22 | 4.39e-22 | 5.15e-22 | 5.62e-22 |
| **p-B11**, Nevins & Swain | 6.15e-23 | 1.58e-22 | **1.98e-22** | 2.43e-22 | 3.02e-22 | 3.39e-22 | 3.70e-22 | 3.74e-22 |
| **He3-He3** (repo dataset) | 6.16e-25 | 1.97e-24 | **2.80e-24** | 4.04e-24 | 6.66e-24 | 9.72e-24 | 1.70e-23 | 2.54e-23 |
| **T-T** (NRL, 2 s.f.) | 1.9e-23 | 3.02e-23 | **3.53e-23** | 4.20e-23 | 4.97e-23 | 5.71e-23 | 7.10e-23 | 8.40e-23 |

**Putvinski's remark is confirmed and it is not the point.** p-B11's reactivity really does beat D-D
and D-He3 above about 130 keV, and at 500 keV it is 63% of D-T's *peak*. The reaction is not feeble.
It loses on everything else: 8.68 MeV against D-T's 17.59, a fusion factor of 0.128 against 0.25, and
a radiation factor of 7.36 against 1.

**And here is the whole finding, in one table.** The same `P_charged/P_brem` ratio for p-B11 with the
newest reactivity, as the electrons are allowed to be colder than the ions:

| T_e/T_i | 150 keV | 200 | 250 | 300 | 350 | 400 | 500 |
|---|---:|---:|---:|---:|---:|---:|---:|
| **1.00 — this mod's model** | 0.42 | 0.49 | **0.48** | 0.44 | 0.39 | 0.35 | 0.28 |
| 0.75 | 0.55 | 0.67 | 0.67 | 0.63 | 0.58 | 0.52 | 0.42 |
| 0.50 | 0.77 | 0.97 | **1.02** | 0.99 | 0.92 | 0.85 | 0.71 |
| 0.46 — **Rider's own self-consistent value** | | 1.04 | **1.10** | 1.07 | 1.01 | | |
| 0.35 | 0.99 | 1.29 | 1.39 | 1.38 | 1.32 | 1.24 | 1.08 |
| 0.25 | 1.24 | 1.63 | 1.79 | 1.81 | 1.76 | 1.69 | 1.51 |

Three independent routes land in the same place, which is why this is worth trusting. Rider got
`P_brem/P_fus = 1.74` at ions 300 keV and electrons 138 keV — `T_e/T_i` = 0.46 — with the
cross-sections of 1979. Tentori and Belloni's reactivity is 1.84× larger at that temperature, so
updating his number in place gives `P_brem/P_fus` = 0.95, i.e. `P_fus/P_brem` = 1.06. **This harness,
computing the same point from scratch at his own 5:1 mix, gives 1.04.** And Tentori and Belloni,
computing it their own way with a self-consistent electron temperature, call it ignition achieved
"only marginally". Three routes, one answer, and it is *just* above 1.

The row that matters for this mod is the top one. **At one temperature, p-B11 sits at half of
break-even at every temperature and every mix, and the deficit is a factor of two rather than a few
percent.**

### So what would it take

Honest answer, in ADR 0014's terms — "reactions, branching ratios, energy releases and cross-sections
are physics and are not negotiable; confinement time, density, purity and capture efficiency are
engineering":

- **Nothing on the engineering side reaches it.** The ratio above is density-independent and
  confinement-independent. Raising `confinement_time_s`, `particles_per_unit`, `heating_power_w` or
  `capture_efficiency` cannot move a number that has neither in it. This is a different situation
  from D-D, where `bremsstrahlung.md` found a confinement ladder that works.
- **The advance that would be needed is a two-temperature plasma**, and that is *not* magic with a
  physics-sounding name — it is the ordinary physics of a real plasma, and it is what every source
  above computes. It is unmodellable here because `step()` carries one temperature, not because it is
  unphysical. **The cost of lifting it is a second state variable per plasma plus an ion-electron
  coupling term**, which is a different `step()` and a different `storage` shape (and therefore a
  migration).
- **The advance that would be needed to make it *good* rather than marginal is one Rider priced and
  found unaffordable**: driving `T_e/T_i` below its self-consistent value costs
  `P_recirc/P_fus = 320`. That one *is* magic with a physics-sounding name, and it is the single
  best-documented negative result in this whole area.

### And the fuel supply, which is the weakest objection to it

Two routes exist and neither is a wall. Both are laid out in
[Candidates that would need a new resource](#candidates-that-would-need-a-new-resource) — the short
version is that **borate is an evaporite, and the mod already concentrates brine out of water for
lithium precisely to avoid worldgen**, so a `rf-borate-solution` off `rf-brine` may need no map
resource at all; and if it does need one, that is now a cost recorded for later rather than a veto.

One real advantage over the lithium family belongs here rather than there: **natural boron is 80%
¹¹B**, so p-B11 wants the abundant isotope and needs no enrichment step, where every lithium
reaction in this note except p-Li7 wants the 8% one.

## What this does to the tiers that already ship

This is not about a new reaction and it is reported because the brief asked for the aneutronic
candidates to be assessed *with* the bremsstrahlung term, and doing that honestly means using the
right electron density — at which point the shipped tiers fail the same test the candidates do.

**`bremsstrahlung.md` says `Z_eff = 1` is "exactly right for both shipped plasmas". It was right about
the two plasmas it had analysed** — D-D and D-T are hydrogenic, `n_e = n_i` and `Z_eff = 1` — and its
implementation sketch carries those constants. **They are wrong for the aneutronic pair.** Helium-3 is
Z = 2, so a D-He3 plasma has 1.5 electrons per ion and `Z_eff = 1.67`, and a He3-He3 plasma has 2.0
and 2.00. At the clamp, in `rf-aneutronic-reactor` at its full 3×10²⁰ m⁻³:

| plasma | n_e/n_i | Z_eff | P_brem, computed properly | P_brem under `n_e = n_i, Z_eff = 1` | factor |
|---|---:|---:|---:|---:|---:|
| **D-He3** | 1.50 | 1.67 | **4 771 MW** | 1 525 MW | **3.13×** |
| **He3-He3** | 2.00 | 2.00 | **9 672 MW** | 1 525 MW | **6.34×** |

And the consequence, sweeping heating power in the shipped aneutronic reactor with the term counted:

| fuel | heating | settles at | Q | P_fus | P_brem | E/τ |
|---|---:|---:|---:|---:|---:|---:|
| D-D | 200 MW | 2.50×10⁸ K | 0.77 | 153 MW | 250 MW | 52 MW |
| D-D | 400 MW | 1.94×10⁹ K | 5.52 | 2 210 MW | 1 467 MW | 401 MW |
| **D-He3** | **200 MW — as shipped** | **1.37×10⁷ K** | **6×10⁻⁸** | **0 MW** | **196 MW** | 4 MW |
| D-He3 | 400 MW | 5.20×10⁷ K | 0.0006 | 0 MW | 387 MW | 13 MW |
| **D-He3** | **800 MW** | **2×10⁹ K (clamped)** | **20.7** | **16 559 MW** | 4 771 MW | 518 MW |
| **He3-He3** | **200 MW — as shipped** | **3.11×10⁶ K** | **9×10⁻⁴⁸** | 0 MW | 199 MW | 1 MW |
| He3-He3 | 2 000 MW | 2.52×10⁸ K | 4×10⁻⁵ | 0 MW | 1 922 MW | 78 MW |
| He3-He3 | 5 000 MW | 9.55×10⁸ K | 0.006 | 30 MW | 4 734 MW | 297 MW |
| **He3-He3** | **10 200 MW** | 2×10⁹ K (clamped) | **0.026** | **261 MW** | **9 672 MW** | 621 MW |

Two distinct failures, and conflating them would be a mistake:

- **D-He3 is trapped, not dead.** Its ideal-ignition band is 31 to 400 keV and it is a genuinely good
  fuel — `P_charged/P_brem = 3.48` at the clamp. What 200 MW cannot do is *get it there*: radiation at
  3×10²⁰ m⁻³ eats the whole heating budget at 1 keV, so the plasma sits at the cold root and never
  climbs. **Four times the heating clears it**, and then it is ignited and lands at Q 20.7. A hot
  start would do the same job, and so would a lower operating density (ADR 0016's lever, pointing the
  other way for once).
- **He3-He3 has no ignited state at all.** It never clears, at any heating power, because there is
  nothing above to clear *to* — its charged fusion power is 1.7% to 6% of its bremsstrahlung
  everywhere in the dataset. At 10.2 GW it reaches the clamp on brute force, radiating 9 672 MW to
  make 261 MW. **The shipped Q of 1.31 for this tier is entirely an artefact of the missing radiation
  term.** Rider's He3-He3 case runs ions at **1 MeV** with electrons at 278 keV and still only reaches
  `P_brem/P_fus = 1.42`; this mod's clamp is at 172 keV, a factor of six below where the reaction is
  even discussed. `reactor-logic.lua` already says the tier "cannot reach its optimum" and quantifies
  that as a hundredth of peak reactivity; what it does not say is that the optimum is on the far side
  of a radiation wall.

**None of this is a recommendation and none of it is a bug report.** ADR 0014 explicitly sanctions a
tier arriving net negative and being researched into viability, and ADR 0015 makes a net-negative tier
legitimate outright when its product is fuel. What it is, is the arithmetic #52 will produce when it
lands, and it is better known now than discovered by a player.

## T-He3, which the corrections promoted

`T + ³He` was not on the original candidate list and it should have been: it is the cheapest thing here
to build and the best-placed of everything that is not already shipped. It is also the one candidate
with a **prior implementation in this mod's own lineage** — the redesign's `the3` channel — and that
implementation is what argues against it, not for it.

**The reaction.** Three branches on one reactant pair, so one blended `M.fuels` row. Branch energies
from ORNL/TM-6914 Table II, branching ratios from the same table:

| branch | Q (MeV) | share | neutron |
|---|---:|---:|---|
| `T + ³He → D (9.546) + α (4.773)` | 14.319 | 41% | **none** |
| `→ p (5.374) + α (1.344) + n (5.374)` | 12.092 | 55% | 5.374 MeV |
| `→ p (10.077) + α (0.403) + n (1.612)` | 12.092 | 4% | 1.612 MeV |
| **blended** | **13.006** | | **3.020 MeV, 0.59 per reaction** |

so `energy_per_reaction_j` = 13.006 MeV, `charged_fraction` = **0.768**, `neutrons_per_reaction` =
0.59 — a row in exactly the shape D-D's already is. The NRL formulary lists the same reaction as (5a)
(5b) (5c) with ratios 51/43/6 rather than 55/41/4, which moves the charged fraction to 0.78; the
spread is real and both sources warn that branching ratios are energy-dependent.

**Why it is cheap.** Everything about it fits the model as built:

- **An even 1:1 mix**, so nothing about the one-fluid pool bites. `fractions = { 0.5, 0.5 }`, `fuel_per_reaction`
  2, both sides run out together — the same shape as D-T and D-He3.
- **Both fuels are already bred.** Tritium from D-D by-products or a blanket, helium-3 from D-D
  by-products. No new item, no new isotope, no enrichment, no resource, no worldgen. A
  `rf-t-he3-mix` recipe on the existing `rf-gas-mixer` is the whole of the Core work.
- **Its reactivity is already tabulated in a source this repo cites**, the NRL formulary p. 45,
  ten points from 1 to 1000 keV.
- **Its charge geometry is D-He3's exactly** — 1.5 electrons per ion, `Z_eff` 1.67, merit 0.0667 —
  because helium-3 is the heavy partner in both.

**Why it is not good.** Its radiation ratio at one temperature peaks at **0.58 around 200–250 keV**.
That is the best of anything in this note that is not already shipped — better than p-B11's 0.52 and
2.7× better than T-T's 0.21 — and it is still below 1, so **T-He3 cannot ignite in this model
either**, and it is trapped at the cold root in both reactors exactly as D-He3 and He3-He3 are.

**But look at what it does on the model as it shipped when this was written**, with no radiation term
— #52 added one on 2026-08-21, so this comparison is now historical rather than a prediction of what
a player would see:

| | radiation-free (shipped model) | with bremsstrahlung |
|---|---|---|
| **T-He3**, `rf-aneutronic-reactor` | **runs to the clamp, Q 16.6**, 3 315 MW | quenches at 1.4×10⁷ K |
| **T-T**, `rf-aneutronic-reactor` | runs to the clamp, **Q 14.5**, 2 893 MW | 1.4×10⁸ K, Q 0.43 |
| He3-He3, `rf-aneutronic-reactor` (shipped) | Q 1.31 | 3.1×10⁶ K, Q 9×10⁻⁴⁸ |
| T-T, `rf-reactor` | 4.0×10⁸ K, **Q 0.95** | 2.0×10⁸ K, Q 0.35 |

**On the model as it stands, T-He3 and T-T would both beat the shipped top tier by an order of
magnitude**, for the cost of one table row each. With the radiation term counted, all three collapse
together. So the entire question of whether either is worth adding is downstream of #52, and that is
the cleanest statement this note can make about them.

**And the thing that would make it a real tier rather than a substitute** is that its 77% charged
fraction is high enough for the direct energy converter to be the sensible route while still venting
0.59 neutrons per reaction — so it would be the first tier where **both** conversion routes have
something to collect, which ADR 0018 gives no way to express: a reactor's energy box carries one
category, and the whole point of two categories is that a machine cannot be bolted to the wrong one.
That is a design consequence, not a physics one, and it is worth knowing before the row looks free.

## T-T, which is the cheapest thing on the list

Tritium against tritium: `T + T → He4 + 2n + 11.3 MeV` (NRL reaction 4; ORNL/TM-6914 gives the split
as He4 1.259 MeV and two neutrons at 5.034 MeV each). **Only 11% of the release is charged**, which is
why its `P_charged/P_brem` row above never exceeds 0.21 — it cannot ignite, ever.

But this mod does not require ignition. In `rf-reactor` at the shipped constants with the radiation
term counted, T-T settles at 2×10⁸ K and **Q 0.349** — against D-D's 0.32 in the same reactor. Its
fuel is tritium, which the mod breeds two ways already, and it needs no new fuel fluid, no new
isotope, no new machine and no new chain step. Its neutrons feed `rf-lithium-blanket` at two per
reaction, where D-T gives one and D-D half.

What kills it as a *tier* is not physics but economics inside the mod: a triton burned in T-T yields
11.33 MeV shared with another triton, where the same triton in D-T yields 17.59 MeV and lights an
ignited reactor at Q 96. **T-T is a strictly worse use of tritium than D-T**, by two orders of
magnitude in Q. Its only case is as somewhere to *put* tritium — a blanket that has bred more than the
D-T reactors can burn currently makes neither heat nor tritium (ADR 0019), and a T-T reactor would be
a sink that pays something back.

Its data is also the thinnest of anything here: the NRL formulary's ten-point table is the only
tabulated T-T reactivity found in this pass, and it is two significant figures.

## What the redesign already did, and what it does not prove

Read directly at `C:\src\factorio\_reference\realistic-fusion-dev`, HEAD `03748ec`.
[`reactor-control-gui.md`](reactor-control-gui.md) covers the same file for the GUI question and
reaches the same conclusions; this section is only what bears on adding a reaction.

**The architectural precedent is real and it is exactly what the hard candidates need.**
`RealisticFusionPower/scripts/reactor-logic.lua` (355 lines) holds `network.deuterium`, `.tritium`,
`.helium_3` and `.helium_4` as unit counts, computes a **mix-weighted heat capacity** summed over all
four species, and runs **seven channels every tick** — `dd_t`, `dd_he3`, `dt`, `dhe3`, `tt`, `the3`,
`he3he3` — from three independently tracked number densities. The bookkeeping is genuine, not a
sketch: `tritium_usage` subtracts `dd_t_reactions` and `helium_3_usage` subtracts `dd_he3_reactions`,
so **D-D by-products feed the other channels' fuel inside one composition** — which is catalysed D-D,
implemented, in 2022. So "several reactant pairs in one plasma" is a port of a known design rather
than a model to invent.

It is Factorio **1.1** code (the redesign's "2.0" is its own mod version, the collision `CLAUDE.md`
warns about) and it never ran on 2.0. `RealisticFusionPower/scripts/` carries no licence file of its
own, so the governing pair is the module's — a WTFPL `license.txt` and the `legal-note.txt` stating
the per-directory rule — making it liftable under ADR 0001 with attribution to **Romner_set**.
Verified against the clone. `RealisticFusionCore/electric-boiler/` and
`graphics/icons/angels-numerals/` are CC BY-NC-ND 4.0 and are not liftable for any purpose; the two
Krastorio 2 graphics directories are GPLv3.

### The rates are falsified, and that inverts what the precedent says about T-T and T-He3

`reactor-logic.lua:179–185`, with the author's own comments verbatim:

| channel | multiplier | comment |
|---|---:|---|
| `D-D_T` | **×10** | *"random bullshit GO!"* |
| `D-D_He3` | **×10** | *"look, I know that I'm supposed to make this realistic and all, but nothing except D-T works properly without these \*10s"* |
| `D-T` | **none** | *"I'll hopefully somehow change the formulas to be more realistic at some point, but this is good enough for now"* |
| `D-He3` | **×10** | |
| **`T-T`** | **×20** | |
| **`T-He3`** | **×100** | |
| `He3-He3` | **×100** | |

**So the seven-channel model ran because its rates were falsified** — which is the "physics implied
through recipe ratios" ADR 0005 exists to prevent, in a worse form, since it is physics multiplied by
arbitrary constants rather than physics left out. Anyone citing the redesign as evidence that a
multi-channel plasma *works* is citing the fudge.

**And the two channels this note promoted carry the two largest fudges of the seven.** T-T at ×20 and
T-He3 at ×100 produced roughly a twentieth and a hundredth of a playable rate at his densities, so if
the precedent were being used to argue *for* them it argues the other way. Two things sharpen that,
and both are visible in the source:

- **The multiplier is muddled as a ranking.** `tt_reactions = estimate_r(…) * t_density * t_density *
  20` carries **no factor of one half for like species**, and neither do `dd_t`, `dd_he3` or
  `he3he3`. This repository does carry it (`reactivity.rate`'s `LIKE_SPECIES` set), so his four
  same-species channels were already running at **twice** their correct rate before the multiplier —
  meaning the real deficit those channels were papering over was 2× larger than the constant says.
  Conversely T-He3's ×100 against T-T's ×20 is partly mix geometry rather than physics: T-He3 needs
  both species at half density (0.25 n²) where his unhalved like-species T-T got 1.0 n², a factor of
  four for nothing to do with the reactions.
- **His charged fractions are nucleon-counted, and for every neutronic channel that inverts the real
  split.** `constants.lua:47–56` derives them by counting nucleons in the charged product — his own
  comment, *"divide by amount of total neutrons/protons, multiply the result by amount of those that
  are part of a charged atomic core"* — giving `D-T` = 4/5. **The real D-T charged share is
  3.52/17.59 = 0.20**, because the neutron is light and takes four fifths. He had it exactly backwards,
  and the same inversion hits `D-D_He3` (3/4 against a true 0.25) and `T-T` (4/6 against a true 0.11).
  It is right only where the reaction is aneutronic and the counting is trivial, which is why his note
  on `D-D_T` — *"made this up on my own but it seems to fit the real-world values pretty much
  exactly"* — is correct for that branch alone.

**Which yields a hypothesis worth stating as a hypothesis.** D-T is the one channel with no
multiplier, and it is also the channel whose self-heating his charged fraction overstated by **4×** —
on top of a reactivity table this repository has already shown to be broken.
`cross-section-data/reactivities.lua`'s own header records that his generator "paired the temperature
grid with the cross-section energy grid, putting the D-T peak about 3x too high at about a fifth of the
right temperature", and that his reactivities were deliberately not reused. Two independent errors,
both in the optimistic direction, both largest for D-T: exactly the pattern that would make D-T the
one channel that "worked properly" and leave everything else needing to be scaled up to meet it.
**So a correctly-derived seven-channel implementation might need none of these constants.** That is a
hypothesis and not a result. It is checkable — run `tools/derive-reactivities.py`'s output against his
`estimate_r` on the same temperature grid — and **nobody has, including this pass.**

The honest reading: **take the architecture and none of the numbers.** The composition vector, the
mix-weighted heat capacity and the per-species bookkeeping are a working design worth porting. The
verdict that T-T and T-He3 are far from viable is one this note reaches independently, from the NRL
reactivities and the radiation ratio — 0.21 and 0.58 against break-even — and the redesign's
multipliers happen to agree with it while being too muddled to be evidence for it.

## Catalysed D-D, which is the most interesting and the least modellable

Not a new reaction — the four the mod already has, run in one plasma. Let the D-D by-products stay
where they are made and burn:

```
D + D  ->  T   + p      4.03 MeV
D + D  ->  He3 + n      3.27 MeV
D + T  ->  He4 + n     17.59 MeV
D + He3 -> He4 + p     18.35 MeV
-------------------------------------
6 D    ->  2 He4 + 2 p + 2 n    43.24 MeV
```

**7.21 MeV per deuteron against plain D-D's 1.82 — a factor of 3.9 — on a fuel the first tier already
makes**, with no new fuel fluid, no new isotope, no new item and no new machine. The neutrons carry
16.51 MeV of the 43.24, so the charged fraction is 0.618 against plain D-D's 0.664: barely worse, and
still neutronic. ORNL/TM-6914 names the mechanic explicitly ("DD-CAT (CAT = catalyzed, meaning the
first generation products T and ³He are burned up as fast as they are generated)") and gives the real
caveat: "about 50–80% of T and 25–50% of ³He may be consumed in fusion reactions in a high
temperature, steady-state DD burning mode", with the remainder needing isotopic separation and
feed-back. So the ideal 43.24 MeV is an upper bound and a real machine gets somewhere between plain
D-D and it.

**It is the only candidate here that needs three different reactant pairs in one plasma**, at unequal
and time-varying densities — the thing several branches of one pair explicitly is not. What it costs
is a `step()` that tracks species inventories rather than one fluid `amount`, which is the same work
an uneven mix costs and which collides with ADR 0011 for the same reason.

**And it is the one candidate with a working implementation to port rather than a model to invent.**
The redesign did exactly this: `network.deuterium`, `.tritium` and `.helium_3` as independent unit
counts, seven channels a tick, and `tritium_usage` subtracting `dd_t_reactions` so the D-D
by-products feed the other channels inside one composition. See [What the redesign already
did](#what-the-redesign-already-did-and-what-it-does-not-prove) — the architecture is liftable and
the numbers are not. So the cost is "port a known 1.1 design into a 2.0 state model that ADR 0011
deliberately shaped differently", which is real work and is not invention.

There is also a design objection worth recording next to the physics: **catalysed D-D would compete
with the mod's own progression.** ADR 0010's chain earns D-T and the aneutronic tier by making the
D-D reactor a breeder whose by-products are the next tier's fuel; a catalysed D-D reactor consumes
them itself. That is a scope question, not a physics one, and it is Truls's.

## The lithium family, where the fuel is free and the physics is not

The brief flagged this as cheap to check and possibly surprising, so it was checked. The surprise is
in the fuel column, not the physics column.

**Every one of these has a fuel route with no new worldgen.** Lithium is already produced from brine;
`rf-hydrogen` is already a Core fluid; helium-3 is already bred. What they all need instead is
**⁶Li enrichment** (natural abundance 8%, per the NRL formulary), which is a new chain step but a
thematically native one.

**And every one of them is worse than p-B11 or worse than useless:**

- **p-Li6** → `He3 (2.298) + He4 (1.724)`, 4.02 MeV, aneutronic. Rider's Table II gives
  **`P_brem/P_fus` = 5.36** at his optimum (ions 500 keV, electrons 204 keV, 3:1 p:⁶Li) — three times
  worse than his p-B11 figure — and Rider 1997 prices the electron cooling at
  `P_recirc/P_fus = 330`. The Q value is the problem: 4 MeV is less than a quarter of D-T's.
  **Its one genuinely interesting property is its product.** p-Li6 *makes helium-3*, aneutronically,
  from hydrogen and lithium — so it is a candidate **breeder tier** rather than a power tier, and
  ADR 0015 makes a net-negative breeder legitimate by decision rather than by shortfall. Recorded as
  an option with a plain trade-off: it would be a second helium-3 route that costs power, competing
  with one the D-D tier already provides for free as a by-product.
- **p-Li7** → 20% `2 He4` (17.35 MeV), **80% `Be7 + n − 1.6 MeV`** near the cross-section peak. It
  uses the *abundant* isotope and it is the only one that needs no enrichment, and the dominant branch
  is an endothermic neutron source. Not a fuel.
- **D-Li6** → five branches in ORNL/TM-6914's list, of which the headline `2 He4 + 22.37 MeV` is one.
  The others are `7Li + p` (5.03), `7Be + n` (3.38), `p + α + T` (2.56) and `3He + α + n` (1.80).
  **Two of five make neutrons**, so "D-Li6 is aneutronic at 22.4 MeV" — which is how the NRL
  formulary's single line reads — is true of one branch and false of the reaction. Same geometry as
  p-Li6 1:1 (merit 0.025), and a barrier 11× D-T's. Its five branches *are* one reactant pair, so
  blending them into one row is mechanically fine — the problem is what the blend says: average five
  branches and the row is neutronic, which is the honest answer and not the interesting one.
- **He3-Li6** → `p (12.390) + 2 He4 (2.245 each)`, 16.88 MeV, genuinely aneutronic, and the **worst
  geometry of any hydrogen-free candidate**: 2.5 electrons per ion, `Z_eff` 2.60, merit 0.0154, and a
  Gamow energy of 70 808 keV — 60× D-T's and 3× p-B11's. It burns helium-3, which the mod's own
  progression treats as its scarcest resource, to less effect than He3-He3 does.

## p-p, and the boundary of "physically reasonable"

Worth including precisely because it fails, and because ADR 0014 needs a boundary somewhere.

`p + p → d + e⁺ + ν` has the *lowest* Coulomb barrier of anything in this note — `E_G` = 493 keV,
half of D-D's. It is nevertheless impossible by a margin nothing else here approaches, because it is
not a strong-interaction reaction at all: it requires one of the two protons to beta-decay during the
collision, which is a weak process. **Adelberger et al.**, *Rev. Mod. Phys.* **83**, 195 (2011),
eq. (25), the canonical evaluation:

> S₁₁(0) = 4.01(1 ± 0.009) × 10⁻²⁵ MeV b

Astrophysical S-factors for the reactions in this note are of order 1 to 10² MeV·b. **p-p is
twenty-five orders of magnitude smaller**, and the same review notes the reaction has never been
measured in the laboratory — every value is theoretical.

So p-p is the clean statement of where the line is. ADR 0014 says the mod may put confinement,
density and purity anywhere the physics permits. It does not license changing the strength of the weak
interaction, and a p-p reactor is the same category of thing as one, not a harder engineering problem.

## Candidates that would need a new resource

**Not for now, recorded for later.** ADR 0010's no-worldgen rule is the *current aim* and not a
permanent boundary, so this section states each candidate's resource, sketches its chain, and states
the worldgen objection rather than treating it as a disqualifier.

**The objection, stated once, because it applies identically to all of them.** Factorio generates
resources only in chunks the player has not yet explored. A mod that adds an ore therefore behaves
differently for a player who adds it to a running save — patches appear only beyond the current
frontier, arbitrarily far from the base — than for one who starts fresh. That is what ADR 0010 refused
for lithium, and it is why `rf-brine` exists at all. Nothing about a new resource is technically hard;
what it costs is that the mod stops behaving the same way on every save, which is also
[ADR 0006](../adr/0006-clean-break-from-predecessor-saves.md)'s territory.

### Boron, for p-B11

**Possibly no resource at all, and that is the finding.** Borates are evaporite minerals — the same
kind of dried-lake deposit lithium brines come from — so the chain the mod already has generalises
directly:

```
water → rf-brine-concentrator → rf-brine → rf-lithium-extractor  → rf-lithium-solution → rf-lithium
                                          ↘ rf-borate-extractor  → rf-borate-solution  → rf-boron
```

One extractor, one solution fluid, one item, and a second product on a fluid that is already produced
for exactly this reason. **The claim that borates are commercially co-produced with lithium from the
same brines was not sourced primarily** — USGS returned HTTP 403 to every fetch attempted from this
network — so treat the real-world mineralogy as unverified and the game-side shape as the point.

If a resource is wanted instead, the honest version is a **borax or kernite surface patch**, which is
what the industry actually mines: an ordinary `resource` prototype with an `autoplace`, feeding a
crusher and a leach. That is the version with the worldgen objection, and it buys nothing the brine
route does not — which is why the brine route is worth trying first even with the boundary widened.

Either way, **the fuel is not what stops p-B11.** What stops it is that at one temperature its charged
fusion power is half its bremsstrahlung, and no chain fixes that.

### Nitrogen and fluorine, for p-N15 and p-F19

Both are real aneutronic reactions, both are used in ion-beam analysis (which is why cross-section
data exists for them at all), and **both are hopeless on physics before the resource question is
reached** — so the widened boundary does not help them.

**The geometry is the whole story.** Nitrogen is Z = 7 and fluorine Z = 9, so an even mix gives four
and five electrons per ion and `Z_eff` of 6.25 and 8.20 — **radiation factors of 100 and 205** against
D-T's 1, before any reactivity is considered. Their Gamow energies are 45 286 and 75 864 keV, **38× and
64× D-T's**. A reaction starting 200× behind on radiation and 64× behind on barrier is not rescued by
its Q value, and neither was pursued to a primary source for that reason. **The Q values in the
candidate table (4.97 and 8.11 MeV) are from common tabulation and were not sourced primarily.**

For completeness on the resource question rather than because it matters: nitrogen needs no patch —
it is 78% of air, and a mod that wanted it would take it from the atmosphere the way real air
separation does, which is a machine and not worldgen. Fluorine would need fluorite, which is a mined
mineral with no brine analogue, so it is the one candidate here whose fuel route genuinely requires a
resource. Neither is worth building for the physics above.

### He3-Li6 and the lithium fuels, for completeness

None of these needs a new resource — lithium is already produced from brine — but every one except
p-Li7 needs **⁶Li enrichment**, at 8% natural abundance. That is a new chain step rather than a new
resource, and it is discussed with the physics in
[The lithium family](#the-lithium-family-where-the-fuel-is-free-and-the-physics-is-not).

## Schemes rather than fuels

The brief asked for these to be judged on whether they are real physics with real literature *and*
whether this model could express them. Several are the former and none is the latter.

**Muon-catalysed fusion** is real, measured, and the most honest "hypothetical advance" on this list —
it needs no new physics, only better numbers. A negative muon binds a `dtμ` molecule tightly enough
that the nuclei tunnel, the fusion releases the muon, and it goes round again. What stops it is *alpha
sticking*: about 0.5–1% of the time the muon leaves bound to the outgoing helium and is lost. Kou and
Chen, arXiv:2606.07077 (2026), give the current cycle yield as **N_fus,μ = 112.6** in the
collision-only baseline, rising to **156.5** with the external-field reactivation scheme they propose.
Break-even needs roughly **250–300** fusions per muon against a muon production cost of about 5 GeV;
that figure is quoted in secondary literature reached during this pass and **the primary source for it
was not obtained**, so treat the 250–300 as indicative and the 112.6/156.5 as sourced.

For this mod: μCF is not a thermal plasma at all. It has no temperature, no confinement time and no
`⟨σv⟩(T)`; its output is a *rate per muon per second*, which is a recipe, not a power balance.
Modelling it means a machine that is not a reactor. It is also — pleasingly, for a Factorio mod — the
one scheme whose game shape is obvious: an accelerator that makes muons at a fixed electrical cost and
a target that returns a fixed multiple.

**Spin-polarised fuel** is real, well-founded, and the only scheme on this list that would fit this
model *without* a new `step()`. Align the deuteron and triton spins and the D-T reaction proceeds
preferentially through the spin-3/2 resonance in ⁵He: **a factor of 1.5 on the cross-section**,
predicted by **Kulsrud, Furth, Valeo and Goldhaber**, *Phys. Rev. Lett.* **49**, 1248 (1982) — *not
obtained directly; the enhancement factor and the "depolarisation time longer than the burn-up period"
claim are taken as quoted by* Baylor *et al.*, *Nucl. Fusion* **63**, 076009 (2023), which reviews the
tokamak tests. That paper's own summary of what is unsettled: hyperfine depolarisation during partial
ionisation costs about 1% in research tokamaks, and whether ion cyclotron emission resonates with the
spin precession frequency "remains uncertain".

For this mod a 1.5× multiplier on `reactivity.rate` for a polarised plasma is exactly the shape
ADR 0005 permits — physics from data, with a stated factor — and exactly the shape ADR 0014 sanctions
as a research target, since polarising the fuel is engineering rather than nuclear physics. It applies
to D-T, which is already the tier that works, so what it buys in game is a *bigger* good tier rather
than a new one. **It is the cheapest real physics on this whole list and it changes nothing
structural.**

**Beam-driven and non-Maxwellian schemes** are the direct subject of Rider 1997, and its answer is the
table reproduced above: `P_recirc/P_fus` of 7.3 to 23 000 depending on how far from Maxwellian the
distributions are driven. Its conclusion names the approaches:

> fusion approaches such as inertial-electrostatic confinement, migma, and other ideas which attempt
> to employ highly nonequilibrium plasmas will probably not even be able to produce net power with
> D-T

Rider also settles the question of whether a non-thermal distribution buys reactivity at all, citing
Snyder, Herrmann and Fisch: changing from Maxwellian to non-Maxwellian ion distributions "would alter
the fusion reactivity by at most a few percent, provided that the ions are at the same mean energy".
So the gain is not in the distribution shape; it is in the species energies, and that is what costs
the recirculating power. Peng *et al.* 2026 confirm the modern position for colliding beams
specifically. **Unmodellable here in any case** — this model's `⟨σv⟩` is Maxwellian-averaged by
construction (`tools/derive-reactivities.py` integrates over a Maxwellian), so a non-thermal scheme is
a different dataset as well as a different `step()`.

**Inertial and magneto-inertial confinement** are real and are the most active experimental route to
gain, but they are pulsed and they are not a zero-dimensional steady power balance: their figure of
merit is `ρR` and an implosion history, not `nτT`. Nothing in this model can express a pulse. Not
pursued further.

## Does the data exist? — which is the gate most candidates fail

The binding gate for most of this list. The finding is specific and it comes from a primary source.

**ENDF and its relatives do not cover these reactions.** Tentori and Belloni (2023), §4.1, having gone
looking:

> We have also considered (but finally not used) evaluated data. The TALYS-based Evaluated Nuclear Data
> Library (TENDL) is currently the only evaluated library that contains cross sections for the p-¹¹B
> reaction. The library is based on the nuclear interaction model TALYS. This model, however, is
> generally considered inaccurate for predicting reaction cross sections on light nuclei. As a matter
> of fact, the TENDL-2021 ¹¹B(p,α) cross section completely misses the resonance structure below
> 4 MeV

**So `tools/derive-reactivities.py`'s route does not extend to p-B11.** The pipeline reads ENDF-derived
cross-section JSON and integrates it; there is no ENDF evaluation to read, and the one evaluated
library that has the reaction is wrong for it in the energy range that matters. `www-nds.iaea.org`
returned **HTTP 402** to every fetch from this network, so **what ENDF/B-VIII.0's charged-particle
sublibraries actually contain could not be independently confirmed** — the repository's own claim that
its five datasets are ENDF/B-VIII.0-derived is taken as it stands.

Four routes exist and they are not equivalent:

| route | what it gives | state | licence / terms |
|---|---|---|---|
| **Analytic reactivity fits** | ⟨σv⟩(T) in closed form for **p-B11 only**, 10–500 keV | Tentori & Belloni 2023 (**CC BY 4.0**, coefficients in the paper) superseding Nevins & Swain 2000 | **clean** — CC BY 4.0, attribution required |
| **Bosch & Hale 1992** | ⟨σv⟩(T) for **exactly four reactions**: D(d,p)T, D(d,n)³He, T(d,n)⁴He, ³He(d,p)⁴He | the canonical parameterisation; paywalled | not obtained; the mod does not need it — it already has these four from cross-sections |
| **NRL Plasma Formulary** p. 45 | ⟨σv⟩ tables for D-D, D-T, D-He3, **T-T** and **T-He3**, 1–1000 keV, ten points | in hand, already cited by this repo | US Government work |
| **ORNL/TM-6914 (1979)** | ⟨σv⟩ tables for **31** light-isotope reactions, 1–1000 keV, including p-B11, p-Li6, p-Li7, D-Li6, He3-Li6, 6Li-6Li | obtained free from IAEA INIS; **a 46-page scan**, so the numbers need digitising and its own text asks for them to be "upgraded" | US Government report, publicly distributed |
| **EXFOR** experimental data | raw σ(E) for essentially anything measured, which is what Tentori & Belloni used | IAEA site unreachable (HTTP 402) this pass | not read |

Two things follow for a decision.

**T-T and T-He3 have no data problem at all**, which is most of why they are the cheapest additions
here. Both are in the NRL formulary's own reactivity table, which this repository already cites for
bremsstrahlung, and both are in ORNL/TM-6914 as well. Ten points at two significant figures is thin —
that is stated in the unverified list — but it is a table, not a digitisation project.

**p-B11 is the next-best off, and its data problem is solved differently.** Tentori and Belloni's seven coefficients
are published under CC BY 4.0 and were implemented and validated here in about forty lines. It would
enter this repo differently from every existing reaction — as a *parameterisation* rather than as a
row generated from cross-sections by `derive-reactivities.py` — which is a real inconsistency with
ADR 0005's "computed rather than chosen" and worth stating: it is still computed, but from a published
fit rather than from tabulated σ(E), so the provenance chain is one link longer and the generator does
not own it.

**Every other candidate's data is a digitisation project.** ORNL/TM-6914 has them all and is a scan
from 1979. That is not a wall, but it is real work, and it is work whose output nobody could then
check against a second source.

## Options, with trade-offs

Recorded, not chosen. ADR 0010's reaction set is scope and `CLAUDE.md` is explicit that scope is
Truls's.

**A. Add nothing.** The defensible reading of everything above. No candidate ignites where the shipped
ones do, and the model's existing top tier does not survive the radiation term that is already
decided — so the first question is what happens to He3-He3, not what to add beside it. *Cost*: none.
*What it forgoes*: the aneutronic story stops where ADR 0010 put it.

**B. Spin-polarised D-T as a research upgrade.** A 1.5× factor on `reactivity.rate` behind a
technology. *Cost*: one multiplier, one technology, no model change, no new fluid, no new chain.
*Trade-off*: it makes the tier that already works better, which is the opposite of a progression;
and 1.5× is small next to the confinement ladder ADR 0014 already sanctions. *Physically reasonable*:
yes, unambiguously — the enhancement is nuclear physics and the polarisation is engineering.

**C. T-He3 as a row.** The cheapest real addition on the list: an even 1:1 mix of two isotopes the mod
already breeds, three branches on one reactant pair blended the way D-D's two already are, NRL supplies
the reactivity, 13.01 MeV at a 77% charged fraction. **Q 16.6 at the clamp on the model as it ships**,
against the shipped He3-He3 tier's 1.31. *Cost*: one `M.fuels` row, one plasma fluid, one mixer recipe.
No model change, no new item, no resource, no enrichment. *Trade-off*: it dies with #52 like everything
else here — radiation ratio 0.58, so it never ignites; its 77% charged fraction wants both conversion
routes at once, which ADR 0018's one-category-per-box design cannot express; and the redesign gave this
channel the largest fudge of its seven.

**D. T-T as a tritium sink.** One row in `M.fuels`, one plasma fluid, no mixer at all because it is like
species. Q 0.35 in the shipped reactor with the radiation term and 0.95 without, and two neutrons per
reaction for the blanket. *Cost*: the smallest of any candidate. *Trade-off*: it is a strictly worse use
of tritium than D-T, so its only game function is absorbing surplus a blanket has bred and the D-T tier
cannot burn; and its reactivity data is two significant figures.

**E. p-Li6 as an aneutronic helium-3 breeder.** A breeder tier under ADR 0015, net negative by decision
rather than by shortfall. *Cost*: ⁶Li enrichment chain, a hydrogen-lithium plasma, uneven-mix support if
it is to run at its best mix, and reactivity data that only ORNL/TM-6914's scan has. *Trade-off*: it
duplicates a helium-3 route the D-D tier gives away free, and Rider's own numbers put it at three times
worse than p-B11.

**F. p-B11, honestly.** Data published under CC BY 4.0; the most recognisable aneutronic reaction there
is; and its alpha cascade is one reactant pair, so the branches cost nothing. Fuel plausibly from brine
with no worldgen — and if a resource is wanted, that is now a cost rather than a veto. *Cost*: **a
two-temperature `step()`**, plus quasineutral electron density in the heat capacity and the radiation
term, plus uneven-mix support to reach 0.52 rather than 0.20. Without the first of those it is at half of
break-even and no amount of confinement, density or heating reaches it. *Trade-off*: the largest piece of
model work on this list, buying "marginal ignition" in the source's own word.

**G. Catalysed D-D.** 3.9× the energy per deuteron with no new fuel of any kind, and the only candidate
with a prior implementation to port. *Cost*: a `step()` that tracks species inventories — the ADR 0011
question, shared with the uneven-mix work. *Trade-off*: it competes with ADR 0010's own progression,
since it burns the by-products the later tiers are built on.

**H. Lift the uneven-mix constraint on its own merits**, as the open ADR 0011 question rather than for
any one reaction. It is what F needs at its best, what E needs at its best, and what G needs at all;
the redesign shows the shape; and `reactor-control-gui.md`'s isotope-mix lever is the same work arriving
from the GUI side. *Cost*: a composition vector that does not desync from the engine's own fluid mixing,
which is the part nobody has designed. *Trade-off*: it is a rewrite of the thing ADR 0011 deliberately
chose, so it is an ADR and not a patch.

**I. Fix the aneutronic tiers' electron density when #52 lands.** Not a new reaction, and arguably not
optional: the term as sketched in `bremsstrahlung.md` would understate D-He3's radiation by 3.1× and
He3-He3's by 6.3×. *Cost*: `n_e` and `Z_eff` per fuel row — two fields, no model change. *Trade-off*:
counting them correctly is what makes He3-He3 unignitable and D-He3 need 4× its heating, so this is
where a balance decision becomes unavoidable rather than where one is avoided.

## What is not verified

- ~~**Every number computed here is unreproducible from the repository**, because the harness is in a
  scratchpad.~~ **Repaired 2026-08-21.** The harness is committed as
  [`tests/test-further-reactions.lua`](../../tests/test-further-reactions.lua) — run
  `lua tests/test-further-reactions.lua` from the repository root. It asserts 44 figures: the four
  `bremsstrahlung.md` equilibria that show the generalisation reduces to the shipped balance, three
  published Gamow energies, every plasma's electron density and `Z_eff`, the 3.13× and 6.34×
  understatement factors, the ordering table, p-11B under both fits across boron fractions from 2% to
  48%, and the aneutronic tiers' behaviour with the term counted. **Landing it corrected one figure**
  — see the note on the ordering table above. **Nothing runs it for you**, as with every suite here:
  there is no CI and no `scripts/*.ps1` invokes the Lua tests, so regenerating
  `cross-section-data/reactivities.lua` invalidates this document silently unless somebody types the
  command.
- **What the committed suite does *not* cover**, so its 44 checks are not mistaken for full coverage:
  the ideal-ignition bands, the lithium family's equilibria, and the full p-11B and catalysed-D-D
  sweeps. The lithium reactivities come from ORNL/TM-6914 read off the paper rather than digitised,
  so they are not in the suite at all. Only the p-11B fit coefficients and the T-T and T-He3 NRL
  tabulations are inlined, each with its source beside it, and both NRL tables are two significant
  figures — every figure derived from them carries that, which is why the suite holds them to 3%
  rather than the 1% it uses against this repository's own dataset.
- **The suite was negative-tested**, and the result is worth recording because it is this note's
  central claim seen from the other side: flattening the electron density to hydrogen's fails 18 of
  the 44 checks, and under that assumption **p-11B reads 5.0× its own bremsstrahlung and looks
  viable**, T-He3 reads 1.79 and looks ignitable, and He3-He3 settles at 1.3×10⁸ K instead of the
  cold root. That is the error [#98](https://github.com/trulsjo/realistic-fusion-refreshed/issues/98)
  exists to stop, measured.
- **`Nevins & Swain 2000` and `Nevins 1998` were not read.** Both are paywalled. The Nevins and Swain
  coefficients used here come from Tentori and Belloni's Table 2, and the claim "no ignition point
  could be found with their reactivity" is Tentori and Belloni's characterisation of them, not a quote
  from Nevins and Swain.
- **`Putvinski, Ryutov & Yushmanov 2019` was not read in full** — only its abstract and the first page
  of the TAE-hosted copy. Its 240–380 keV ignition window is quoted through Tentori and Belloni, who
  cite it as their reference 20. Note that this is the *same paper* `bremsstrahlung.md` already
  records as "not read directly" for the relativistic bremsstrahlung fit; it is now load-bearing in two
  documents and nowhere read.
- **`Bosch & Hale 1992` was not read.** Its functional form is used here (validated against two
  independently published Gamow energies and against two independently published reactivity ranges) and
  the four reactions it covers are from its abstract. **Nothing in this repository depends on it** —
  `reactivities.lua` is derived from cross-sections, not from Bosch and Hale.
- **`Sikora & Weller 2016` and `Kulsrud et al. 1982` were not obtained.** The first is invisible in
  this note except through Tentori and Belloni; the second supplies the 1.5× polarisation factor, taken
  as quoted by Baylor *et al.* 2023.
- **The muon-catalysed break-even figure of 250–300 fusions per muon is not primarily sourced.** The
  achieved yields (112.6 and 156.5) and the alpha-sticking probability are, from Kou and Chen 2026.
- **Ahmad et al. 2026's Table 1 disagrees with itself, and the value used here is the other one.** As
  read from the copy fetched in this pass it lists `P3 = 1.3240×10⁻³` for the Tentori-Belloni fit,
  where Tentori and Belloni's own Table 2 gives `1.3240×10⁻¹`. Only the latter reproduces the
  reactivity range Ahmad et al. themselves quote, so `10⁻¹` is used throughout. This is recorded
  rather than glossed because it is exactly the class of error this repository has corrected in its own
  documents twice.
- **Ahmad et al. 2026's own conclusions are not relied on.** That paper reports net-energy windows for
  p-B11 at `T_e = 0.5 T_i` and `T_e = 0.25 T_i`, which is consistent with the table computed here, and
  it is used in this note only for its reprint of the two coefficient sets and for the reactivity
  endpoints that validated the implementation.
- **`ENDF/B-VIII.0`'s charged-particle coverage was not confirmed.** `www-nds.iaea.org` returns
  HTTP 402 from this network, so neither EXFOR nor the ENDF retrieval interface was reachable, and
  their terms of use were not read.
- **Boron's real-world production route was not confirmed.** USGS returns HTTP 403 from this network.
  The claim that borates come from evaporite brines alongside lithium is stated as the plausible
  in-game route and is not sourced.
- **p-N15, p-F19 and p-p Q values are from common tabulation, not from a primary source.** Nothing in
  the argument against any of the three uses those numbers — p-p is refused on its S-factor, which
  *is* sourced, and the other two on geometry and barrier height, which are computed.
- **T-T's and T-He3's reactivities are two significant figures** from ten-point tables, log-log
  interpolated. T-T's Q 0.349 should be read as "about the same as D-D's", and T-He3's Q 16.6 as "about
  the same as T-T's 14.5 and an order above the shipped He3-He3 tier" — not as three digits. This is
  the thinnest data behind any number in this note, and it is behind the two cheapest candidates.
- **T-He3's branching ratios disagree between the two sources by about five points** — 41/55/4 in
  ORNL/TM-6914 against 51/43/6 in the NRL formulary, matched branch for branch. That moves the charged
  fraction from 0.768 to 0.783 and nothing else in the assessment. Both sources also warn that
  branching ratios are quoted for energies near the cross-section peaks, so neither is a constant.
- **The hypothesis that a correctly-derived seven-channel model would need none of the redesign's
  multipliers was not tested.** It is checkable — `tools/derive-reactivities.py`'s output against his
  `estimate_r` on one temperature grid — and this pass did not run it. What *is* verified is that both
  of his inputs were wrong in the optimistic direction and both were most wrong for D-T: the
  reactivity table's miscalibration is recorded in `reactivities.lua`'s own header, and the
  nucleon-counted charged fractions in `constants.lua:47–56` give D-T 4/5 where the kinematics give
  1/5. The inference from "both errors favour D-T" to "the multipliers are artefacts" is reasoning,
  not measurement.
- **The real-world mineralogy behind the boron chain is not sourced.** USGS returns HTTP 403 from this
  network, three attempts. Borate-from-brine is offered as the game-side shape that needs no worldgen,
  not as a verified industrial fact.
- **Nothing about the resource-backed candidates has been checked against worldgen behaviour**, because
  nothing was built. The objection stated in that section is ADR 0010's own reasoning, restated.
- **ORNL/TM-6914's numeric tables were not transcribed.** Its reaction list and per-product energies
  were read; its ⟨σv⟩ digits were not, because it is an OCR'd scan and quoting digits out of one would
  be the kind of unverified claim this repository treats as a defect.
- **Nothing here has been run in Factorio.** No candidate exists as a prototype, so there is nothing to
  run. Every statement is about the simulation and the physics, not about the game.

## Sources

Primary, read directly:

- **NRL Plasma Formulary**, 2019 revision, A. S. Richardson, Naval Research Laboratory.
  "Thermonuclear Fusion", pp. 44–45: reactions (1)–(10) with branch energies, natural isotopic
  abundances, Duane cross-section coefficients for D-D/D-T/D-He3/T-T/T-He3, and the Maxwellian ⟨σv⟩
  table 1–1000 keV. Its own references 26–28 are Glasstone and Lovberg (1960); Miley, Towner and
  Ivich, *Fusion Cross Section and Reactivities*, COO-2218-17 (1974); and Duane, *Fusion Cross Section
  Theory*, BNWL-1685 (1972). Read at the mirror
  <https://tanimislam.github.io/research/NRL_Formulary_2019.pdf>, the same copy
  [`bremsstrahlung.md`](bremsstrahlung.md) used.
- **A. Tentori and F. Belloni**, "Revisiting p-¹¹B fusion cross section and reactivity, and their
  analytic approximations", *Nuclear Fusion* **63**, 086001 (2023). **Open access, CC BY 4.0.**
  Read in full. §1 for the 240–380 keV window and "ignition […] only marginally"; eqs (7)–(8) and
  Table 2 for the high-temperature reactivity fit and both coefficient sets; text under eq. (1) for
  `E_G = 22.589 MeV`; §4.1 for the TENDL finding.
- **T. H. Rider**, "A general critique of inertial-electrostatic confinement fusion systems",
  *Physics of Plasmas* **2**, 1853 (1995). Read in full (image scan, OCR). Table I (D-T, D-He3, D-D)
  and Table II (p-¹¹B, p-⁶Li, ³He-³He) for `P_brem/P_fus`, ion and electron temperatures, mixes and
  reactivities. Read at
  <https://fsl.npre.illinois.edu/IEC/Rider,%20Phys.ofPlasmas1995.pdf>.
- **T. H. Rider**, "Fundamental limitations on plasma fusion systems not in thermodynamic
  equilibrium", *Physics of Plasmas* **4**, 1039 (1997). Read in full. Tables III, IV and VI for
  recirculating power; §IV for the verdict on advanced aneutronic fuels and on IEC and migma. Read at
  <https://riderinstitute.org/wp-content/uploads/2019/11/INFERNO5.pdf>, the same copy
  `bremsstrahlung.md` used.
- **J. R. McNally Jr., K. E. Rothe and R. D. Sharp**, *Fusion Reactivity Graphs and Tables for Charged
  Particle Reactions*, ORNL/TM-6914, Oak Ridge National Laboratory, August 1979. Read (image scan,
  OCR). Table II for the 31-reaction list with per-product energies; §text for the like-species factor
  and for the catalysed-D-D burn fractions. Obtained free from IAEA INIS,
  <https://inis.iaea.org/records/cs9sg-0eb20>.
- **E. G. Adelberger et al.**, "Solar fusion cross sections. II. The pp chain and CNO cycles",
  *Reviews of Modern Physics* **83**, 195 (2011), arXiv:1004.2318. Read. Eq. (25) for
  `S₁₁(0) = 4.01 × 10⁻²⁵ MeV b`.
- **I. M. Ahmad, A. D. Husin, D. T. Tai, N. Tamam, A. Sulieman and S. Yani**, "Evaluation of the
  Lawson criterion for aneutronic proton-boron-11 fusion: effects of ion temperature and
  bremsstrahlung losses", *Frontiers in Nuclear Engineering* **5**, 1714531 (2026). Open access. Read.
  Table 1 (reprinting both coefficient sets, with the `P3` discrepancy noted above) and §3.1 for the
  reactivity endpoints used to validate this note's implementation.
- **Y.-K. M. Peng et al.** (ENN), "Features of spherical torus p¹¹B burning plasmas",
  arXiv:2604.04002 (2026). **Preprint, not peer reviewed.** Read. §1.1–1.3 for the modern synthesis of
  the McNally, Rider, Nevins, Sikora-Weller, Putvinski and Rostoker positions.
- **W. Kou and X. Chen**, "External-Field-Assisted Muon Reactivation in Muon-Catalyzed Fusion: A
  Rate-Network Criterion for Reducing Alpha Sticking", arXiv:2606.07077 (2026). **Preprint.** Read.
  Eqs (1)–(4) and §V for `N_fus,μ` = 112.6 → 156.5 and the sticking probability.
- **The archived redesign**, `realistic-fusion-dev` by **Romner_set**, read directly from the local
  clone at `C:\src\factorio\_reference\realistic-fusion-dev`, HEAD `03748ec`.
  `RealisticFusionPower/scripts/reactor-logic.lua` lines 168–225 for the seven channels, the
  multipliers and the per-species bookkeeping; `scripts/constants.lua:37–56` for the reaction energies
  and the nucleon-counted charged fractions. WTFPL at the module root with the per-directory rule in
  its `legal-note.txt`; liftable under ADR 0001 with attribution. Factorio **1.1** code that never ran
  on 2.0. Its GUI side is covered by [`reactor-control-gui.md`](reactor-control-gui.md), which reaches
  the same conclusions about the multipliers and the licensing.
- **The repository's own data**: `realistic-fusion-refreshed/cross-section-data/reactivities.lua` and
  `scripts/reactor-logic.lua` at `M.reactor`, `M.aneutronic_reactor` and `M.fuels`; and
  [`reactor-control-gui.md`](reactor-control-gui.md) for the ADR 0011 composition-vector question.

Read for a specific claim only:

- **L. Baylor et al.**, "Polarized fusion and potential in situ tests of fuel polarization survival in
  a tokamak plasma", *Nuclear Fusion* **63**, 076009 (2023). The 1.5× D-T polarisation enhancement,
  its origin in the ⁵He spin-3/2 resonance, the attribution to Kulsrud et al. (1982), and what is
  known and unknown about depolarisation.
- **S. E. Wurzel and S. C. Hsu**, *Physics of Plasmas* **29**, 062103 (2022), and **H. Xie**,
  arXiv:2404.11540 (2024) — the bremsstrahlung constant, the `Z_eff` definition and the relativistic
  correction with its `t < 1` bound. Both were read in full for
  [`bremsstrahlung.md`](bremsstrahlung.md) and are reused here rather than re-derived, as instructed.
- **H.-Y. Wang, Y.-Q. Li, Q. Wu and Z.-F. Cui**, "Revisiting p-¹¹B Fusion: Updated Cross-sections,
  Reactivity, and Energy Balance", arXiv:2601.00241 (2026). **Preprint, not peer reviewed**, read only
  as an abstract-level check that the 2026 literature has not overturned the position above; its claim
  is that p-B11 "is not precluded by bremsstrahlung constraints when contemporary cross-section data
  and self-consistent thermal modeling are employed" — the same "self-consistent" qualifier, again.

Cited but not read:

- **H.-S. Bosch and G. M. Hale**, "Improved formulas for fusion cross-sections and thermal
  reactivities", *Nuclear Fusion* **32**, 611 (1992). Paywalled. Covers **D(d,n)³He, D(d,p)T,
  T(d,n)⁴He and ³He(d,p)⁴He** — and nothing else, which is the answer to "which reactions does the
  canonical parameterisation cover".
- **W. M. Nevins and R. Swain**, "The thermonuclear fusion rate coefficient for p-¹¹B reactions",
  *Nuclear Fusion* **40**, 865 (2000). Paywalled.
- **W. M. Nevins**, "A Review of Confinement Requirements for Advanced Fuels", *Journal of Fusion
  Energy* **17**, 25 (1998). Paywalled.
- **S. V. Putvinski, D. D. Ryutov and P. N. Yushmanov**, "Fusion reactivity of the pB¹¹ plasma
  revisited", *Nuclear Fusion* **59**, 076018 (2019). Abstract and first page only.
- **M. H. Sikora and H. R. Weller**, "A New Evaluation of the ¹¹B(p,α) Reaction Rates", *Journal of
  Fusion Energy* **35**, 538 (2016).
- **R. M. Kulsrud, H. P. Furth, E. J. Valeo and M. Goldhaber**, "Fusion Reactor Plasmas with Polarized
  Nuclei", *Physical Review Letters* **49**, 1248 (1982).
- **D. C. Moreau**, *Nuclear Fusion* **17**, 13 (1977); **J. Dawson**, "Advanced fusion reactors",
  in *Fusion* vol. 1 (1977); **N. Rostoker, M. W. Binderbauer and H. J. Monkhorst**, *Science* **278**,
  1419 (1997) — the p-B11 reactor proposals, named through Tentori and Belloni's and Peng et al.'s
  reference lists and not consulted.
- **IAEA EXFOR and the ENDF retrieval interface**, <https://www-nds.iaea.org/>. **HTTP 402 from this
  network**, both the `exfor/` and `exfor/endf.htm` endpoints.
- **USGS** Mineral Commodity Summaries (boron) and MRDS. **HTTP 403 from this network**, three
  attempts.
