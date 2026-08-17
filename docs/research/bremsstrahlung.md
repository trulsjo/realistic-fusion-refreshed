# Bremsstrahlung, and whether it would bite

Researched 2026-08-17 against primary sources, and computed against the shipped model — `scripts/
reactor-logic.lua` and `cross-section-data/reactivities.lua` at `M.reactor`'s constants, driven from
a standalone Lua 5.4.6 harness that requires the repo's own modules rather than reimplementing them.
Nothing in the mod was changed to produce these numbers.

It exists because `reactor-logic.lua` and `docs/research/d-t-ignition.md` both justify the 2×10⁹ °C
temperature clamp with a claim about bremsstrahlung, and [#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37)
may act on it.

**The short version: the claim is wrong in its load-bearing part, and right about something else.**
Bremsstrahlung does not "bite long before 4.6×10⁹" for D-T — adding it moves that equilibrium to
about 3.3×10⁹ K, still well above the int32 ceiling the clamp is really there to protect. What it
does bite is **D-D**, the tier that currently works: adding bremsstrahlung drops the shipped D-D
reactor from Q 2.1 to Q 0.32. The tier is playable *because* the term is missing. Details and
arithmetic below.

## What bremsstrahlung is, for a reader who does not do plasma physics

German for "braking radiation". A plasma is a gas hot enough that the electrons have come off the
nuclei, so it is a soup of free negative electrons and free positive ions. An electron flying past an
ion is deflected by the ion's electric charge; being deflected means being accelerated; and an
accelerated charge radiates. The electron loses a little energy, and that energy leaves as a photon —
an X-ray, at these temperatures.

Neither particle is captured, so it is called **free–free emission**. The plasma is emitting light,
and the light leaves. That is a loss: energy the reactor spent heating the plasma, gone.

Three things matter about it for a reactor model:

- **It goes as density squared.** Both an electron and an ion are needed, so the rate is proportional
  to `n_e × n_i`. Double the density and you quadruple the radiation.
- **It goes as the square root of temperature.** Weakly. This is the crux of everything below: fusion
  power rises very steeply with temperature and then rolls over, while bremsstrahlung just keeps
  creeping up. Where the two curves cross is where a plasma can or cannot sustain itself.
- **The plasma is transparent to it.** At the densities in question the emitted X-rays fly straight
  out through the plasma and hit the wall. Nothing is reabsorbed. (Arithmetic for this claim below —
  it matters, because the *other* radiation channel behaves in exactly the opposite way.)

A fusion plasma actually radiates through three channels, and only one of them is this one:

| | mechanism | what it needs | is it what we mean? |
|---|---|---|---|
| **Bremsstrahlung** | free electron deflected by an ion's Coulomb field | ions and electrons | **yes, this note** |
| **Cyclotron / synchrotron** | electron spiralling around a magnetic field line | a magnetic field | no — and see below, because it is bigger here |
| **Line radiation** | bound electron in a partly-ionised atom dropping between energy levels | atoms that still have electrons, i.e. impurities | no — a pure hydrogen plasma has none |

The distinction is not pedantic. In a *fully ionised hydrogenic* plasma — deuterium, tritium, their
electrons, nothing else — line radiation is zero by construction, because there are no bound
electrons left to make a line. That is the plasma this mod models. Cyclotron radiation is not zero;
it is enormous. More on that in the section on what really limits a reactor.

## The formula

**NRL Plasma Formulary**, 2019 revision, A. S. Richardson, Pulsed Power Physics Branch, US Naval
Research Laboratory, "Radiation" section, page 58, equation (30):

> Bremsstrahlung from hydrogen-like plasma:
> `P_Br = 1.69 × 10⁻³² n_e T_e^(1/2) Σ [Z² n(Z)]  watt/cm³`,
> where the sum is over all ionization states Z.

with the section's stated units convention, page 57:

> Note: Energies and temperatures are in eV; all other quantities are in cgs units except where
> noted. Z is the charge state (Z = 0 refers to a neutral atom); the subscript e labels electrons.
> n is number density.

So: `n_e` and `n(Z)` in cm⁻³, `T_e` in **eV**, result in W/cm³. The formulary attributes it to
Glasstone and Lovberg, *Controlled Thermonuclear Reactions* (Van Nostrand, New York, 1960) — its
reference 26. It carries **no relativistic correction and no stated validity range**; that is a real
limitation of the formulary entry and is dealt with in the next section.

Converted to SI, which is what this repository works in — `n[cm⁻³] = 10⁻⁶ n[m⁻³]`,
`T[eV] = 10³ T[keV]`, `W/cm³ = 10⁻⁶ W/m³`:

    1.69e-32 × 10⁶ × (10⁻⁶)² × √(10³)  =  5.344e-37

Which is the constant the fusion literature uses directly. **Wurzel and Hsu**, "Progress toward
fusion energy breakeven and gain as measured against the Lawson criterion", *Physics of Plasmas* **29**,
062103 (2022), equation (7) and the text beneath it:

> `P_B = C_B n_i n_e Z² T_e^(1/2) V`
> […] in m³, and setting `C_B = 5.34 × 10⁻³⁷ W m³ keV^(-1/2)` gives `P_B` […]

So the working SI form, and the one used for every number in this note:

    P_brem = 5.34e-37 × Z_eff × n_e × n_i × sqrt(T_keV)   W/m³

with `n` in m⁻³ and `T` in **keV**. Two independent primary sources, one derived from the other by
unit conversion only, agreeing to three figures. `Z_eff` is defined in the same paper, equation (41):

> `Z_eff = Σᵢ nᵢ Zᵢ² / n_e`, where i is summed over all ion species in the plasma.

For a pure D-T or D-D plasma `Z_eff = 1`, because every ion is singly charged. Every impurity raises
it, quadratically in the impurity's charge — which is why a trace of iron off the wall matters far
more than its particle count suggests.

### The relativistic correction, which is not academic here

`T_e = 511 keV` is the electron rest mass. A plasma whose electrons carry an appreciable fraction of
that is relativistic, and the non-relativistic formula understates the radiation. **This model runs
at 76 keV (the shipped D-D equilibrium) to 399 keV (the unbounded D-T equilibrium)**, so the
correction is not a footnote — it is a factor of 1.5 to 5.3.

Wurzel and Hsu, appendix D, equations (D1) and (D2):

> `P_B = C_B n_e² T_e^(1/2) ξ(Z_eff)`
> where
> `ξ(Z_eff) = Z_eff (1 + 1.78 t^1.34) + 2.12 t (1 + 1.1 t + t² − 1.25 t^2.5)`
> and `t = T_e / m_e c²`.

The first bracket is the electron–ion emission with its relativistic enhancement; the second is
**electron–electron** bremsstrahlung, which vanishes in the non-relativistic limit (two identical
charges have no dipole moment) and switches on as the plasma warms. It carries no `Z_eff` because it
does not involve the ions at all. Wurzel and Hsu attribute the fit to their reference 137, Putvinski,
Ryutov and Yushmanov, *Nuclear Fusion* **59**, 076018 (2019); **that paper was not read directly for
this note** — the equation is taken as quoted by Wurzel and Hsu.

An independent primary source gives a different fit. **Rider**, "Fundamental limitations on plasma
fusion systems not in thermodynamic equilibrium", *Physics of Plasmas* **4**, 1039 (1997), equation
(21):

> The bremsstrahlung power loss density, including relativistic corrections, is given in [ref 1]
> `P_brem = 1.69 × 10⁻³² n_e² √T_e [ (Σᵢ Zᵢ² nᵢ / n_e)(1 + 0.7936 T_e/m_ec² + 1.874 (T_e/m_ec²)²)
>  + (3/2) T_e/m_ec² ] W/cm³`,
> in which the electron temperature `T_e` and rest energy `m_e c²` are in eV.

The two disagree, and by more as the plasma gets hotter:

| T_e | t = T_e/511 keV | Wurzel/Putvinski ξ | Rider 1997 eq. (21) |
|---|---|---|---|
| 8.6 keV | 0.017 | 1.04 | 1.04 |
| 43 keV | 0.084 | 1.26 | 1.21 |
| **76 keV** (shipped D-D point) | 0.148 | **1.51** | 1.38 |
| 172 keV (the clamp) | 0.337 | 2.42 | 1.99 |
| **399 keV** (unbounded D-T point) | 0.781 | **5.25** | 3.93 |

That spread is known and documented. **Xie**, "Bremsstrahlung radiation power in fusion plasmas
revisited: towards accurate analytical fitting", *Plasma Physics and Controlled Fusion* (2024),
arXiv:2404.11540, exists precisely because the community's standard fits disagree at the several-
to-tens-of-percent level above ~50 keV; its figure 1 tabulates seven of them side by side, including
both of the above, and its stated purpose is "to enhance the fitting to achieve an error of less than
1%". Its table also records the validity bound on the Rider/McNally form as `t < 1`, i.e. below
511 keV — which every number in this note respects, but only just, at the 399 keV end.

**This note uses the Wurzel/Putvinski form as the headline** because it is the larger of the two, it
is the one a peer-reviewed 2022 paper reaches for when treating exactly this high-temperature regime,
and using the larger number is the conservative choice for the question being asked. Where the answer
would change if the smaller fit were used, that is stated.

## Why bremsstrahlung sets an ignition floor — and, out here, a ceiling

The classical argument, and the one the code comment is reaching for. Wurzel and Hsu, section III A,
on Lawson's first insight, equation (8):

> Dividing both sides by V and plotting the resulting fusion power density `S_c = P_c/V`
> (left-hand side) and bremsstrahlung power density `S_B = P_B/V` (right-hand side) versus T in Fig. 6
> shows that **T ≳ 4.3 keV is required for `S_c ≥ S_B`. This temperature is known as the ideal
> ignition temperature** because, under the idealized scenario of perfect confinement, ignition occurs
> at this temperature. Note that because `n²` cancels on both sides of Eq. (8), the ideal ignition
> temperature is independent of density.

Both sides go as `n²`, so density drops out and the crossing is a pure temperature. Below it, no
amount of confinement helps: the plasma radiates away more than its own charged fusion products
deposit, and it cools. That is the floor.

**Running that calculation against this repository's own reactivity dataset reproduces 4.3 keV
exactly.** Charged fusion power against bremsstrahlung, no transport loss, `Z_eff = 1`, over the
ENDF/B-VIII.0-derived ⟨σv⟩ in `cross-section-data/reactivities.lua`:

| fuel | brems model | crossings of `P_charged = P_brem` |
|---|---|---|
| D-T | non-relativistic | **4.3 keV** and 7 441 keV |
| D-T | Rider 1997 | **4.3 keV** and 467 keV |
| D-T | Wurzel/Putvinski | **4.3 keV** and **409 keV** |
| D-D | non-relativistic | 44.3 keV and 6 154 keV |
| D-D | Rider 1997 | 60.5 keV and 279 keV |
| D-D | Wurzel/Putvinski | **71.9 keV** and **167.5 keV** |

Two things fall out of that table, and only the first is in the literature.

**The floor.** D-T's is 4.3 keV, matching the published value to two figures and independently
confirming both the dataset and the bremsstrahlung implementation used throughout this note. D-D's
is an order of magnitude higher — 44 keV without relativistic corrections, 72 keV with them. **This
D-D figure is computed here and was not sourced from the literature**; it is consistent with the
standard statement that D-D needs far hotter conditions than D-T, but no primary source was found in
this pass that states a D-D ideal ignition temperature to compare against.

**The ceiling, which is the part the code comment half-guessed.** Because fusion reactivity rolls
over past its peak while bremsstrahlung keeps climbing, the two curves cross *back* at high
temperature. For D-T that upper crossing is at **409 keV**, and the model's unbounded D-T equilibrium
sits at 399 keV — right at the edge of it. So there genuinely is a bremsstrahlung wall out there. It
is just in a different place from where the comment puts it. And for D-D the ignition band is
narrow — 72 to 168 keV — with the shipped D-D reactor sitting at 76 keV, barely inside its lower
edge. That is the real fragility in this model, and it is not the one anybody wrote down.

## The arithmetic at this model's operating point

`M.reactor` in `reactor-logic.lua`: `volume_m3 = 1000`, `particles_per_unit = 1e20` over a 1000-unit
box, so `n_e = n_i = 10²⁰ m⁻³` in a full reactor; `confinement_time_s = 30`; `heating_power_w = 50e6`.
The model carries `(3/2)NkT` for ions and as much again for electrons, so `n_e = n_i` is exactly the
assumption already in the code and `Z_eff = 1` is exactly right for both shipped plasmas.

Bremsstrahlung over the whole plasma is therefore

    P_brem = 5.34e-37 × 1 × 1e20 × 1e20 × sqrt(T_keV) × 1000 m³
           = 5.34e6 × sqrt(T_keV)  W
           = 5.34 × sqrt(T_keV)  MW

and the transport loss the model already carries is `E/τ_E = 3NkT/30`, with `N = 10²³`:

    E/tau = 3 × 1e23 × 1.380649e-23 × T / 30 = 0.1381 × T[K]  W

| T (K) | T (keV) | P_brem non-rel | P_brem relativistic | factor | `E/τ_E` | P_α D-T | P_α D-D |
|---|---|---|---|---|---|---|---|
| 1×10⁸ | 9 | 16 MW | 16 MW | 1.04 | 14 MW | 108 MW | 2 MW |
| 3×10⁸ | 26 | 27 MW | 31 MW | 1.15 | 41 MW | 828 MW | 16 MW |
| 5×10⁸ | 43 | 35 MW | 44 MW | 1.26 | 69 MW | 1 167 MW | 34 MW |
| **8.77×10⁸** | 76 | 46 MW | **70 MW** | 1.51 | **121 MW** | 1 253 MW | **71 MW** |
| 1.5×10⁹ | 129 | 61 MW | 120 MW | 1.98 | 207 MW | 1 093 MW | 128 MW |
| **2×10⁹** (the clamp) | 172 | 70 MW | **169 MW** | 2.42 | **276 MW** | **962 MW** | 168 MW |
| 3×10⁹ | 259 | 86 MW | 293 MW | 3.41 | 414 MW | 770 MW | 236 MW |
| **4.63×10⁹** | 399 | 107 MW | **560 MW** | 5.25 | **639 MW** | **590 MW** | 325 MW |

`P_α` is the charged share only — 20% of D-T's release, 66% of D-D's — because that is what stays in
the plasma and self-heats it. It is the same `charged_fraction` the code uses.

Read the D-T row at 4.63×10⁹ K first, because it is the one the code comment is about. Without
bremsstrahlung the balance closes exactly: `P_α 590 + heating 50 = 639 = E/τ_E`, which is why the
model settles there and why `d-t-ignition.md` reports 4.63×10⁹. Adding relativistic bremsstrahlung
puts 560 MW on the loss side against a 639 MW supply — a large term, comparable to the transport
loss, and enough to move the equilibrium. Not enough to move it *far*.

Now read the D-D row at 8.77×10⁸ K. Supply is `P_α 71 + heating 50 = 121 MW`, exactly matching the
121 MW transport loss — again the model's own equilibrium, reproduced. Adding 70 MW of
bremsstrahlung to a 121 MW budget is not a correction. It is more than half the loss again.

### What it does to the equilibria

Same harness, bremsstrahlung subtracted from the power balance, solved for the temperature where
`P_α + P_heating = E/τ_E + P_brem`:

| fuel | bremsstrahlung | settles at | Q | P_fus | P_brem | brems share of loss |
|---|---|---|---|---|---|---|
| **D-D** | none (shipped) | 8.77×10⁸ K | **2.14** | 107 MW | — | — |
| D-D | non-relativistic | 2.69×10⁸ K | 0.39 | 19 MW | 26 MW | 41% |
| D-D | Rider 1997 | 2.46×10⁸ K | 0.33 | 16 MW | 27 MW | 44% |
| **D-D** | Wurzel/Putvinski | **2.42×10⁸ K** | **0.32** | 16 MW | 27 MW | 44% |
| **D-T** | none (shipped) | 4.63×10⁹ K | **58.9** | 2 947 MW | — | — |
| D-T | non-relativistic | 4.18×10⁹ K | 62.8 | 3 141 MW | 101 MW | 15% |
| D-T | Rider 1997 | 3.47×10⁹ K | 70.5 | 3 524 MW | 276 MW | 37% |
| **D-T** | Wurzel/Putvinski | **3.26×10⁹ K** | **73.2** | 3 658 MW | 331 MW | 37% |

**D-T: the claim fails.** The equilibrium moves from 4.63×10⁹ to 3.26×10⁹ K — a 30% reduction, real
but nowhere near the 2×10⁹ clamp and comfortably above the 2.147×10⁹ int32 ceiling. Bremsstrahlung
does not "bite long before 4.6×10⁹" in any sense that changes what the clamp is doing. The plasma
still ignites, still runs away past the clamp, and the clamp is still doing the work. Note also that
Q goes **up**, not down: bremsstrahlung parks the plasma nearer the ⟨σv⟩ peak at 65 keV, so it
actually fuses harder.

**D-D: the tier collapses.** 8.77×10⁸ → 2.42×10⁸ K, Q 2.14 → 0.32, 107 MW of fusion power → 16 MW.
Sub-breakeven, and the reactor is no longer a fusion machine — it is a 50 MW heater with a 16 MW
bonus, radiating 27 MW straight out of the wall. Everything in `d-t-ignition.md`'s fuel-chain
section, which depends on a D-D reactor breeding 0.92 u/s of tritium at its settling point, goes with
it.

Both of these are the physics being right, not a bug. A D-D plasma at 10²⁰ m⁻³ with 30 s of
confinement and 50 MW of heating is genuinely nowhere near D-D ignition, and the shipped tier only
looks like a working reactor because the dominant radiative loss is absent from the model.

### Does any parameter put D-T under the int32 ceiling?

Sweeps, with relativistic bremsstrahlung included, looking for a D-T equilibrium below 2.147×10⁹ K —
the point of the question, since that is what would let the temperature circuit signal stop being
pinned:

| `τ_E` | D-T settles at | Q |
|---|---|---|
| 30 s (shipped) | 3.26×10⁹ K | 73 |
| 15 s | 2.48×10⁹ K | 86 |
| **10 s** | **2.02×10⁹ K** | 96 |
| 5 s | 1.32×10⁹ K | 115 |
| 3 s | 3.1×10⁷ K — **quenches** | 0.2 |

| `Z_eff` at `τ_E` = 30 s | D-T settles at |
|---|---|
| 1 (pure) | 3.26×10⁹ K |
| 2 | 2.93×10⁹ K |
| 3 | 2.66×10⁹ K |
| 5 | 2.26×10⁹ K |
| 7 | 1.9×10⁷ K — **quenches** |

Neither is a comfortable answer. Dirtying the plasma to `Z_eff ≈ 6` would be needed to land under the
ceiling, and `Z_eff = 7` extinguishes it entirely — a knife edge between "still pinned" and "does not
work", which is not a design anyone should build a tier on, and a plasma far filthier than any real
machine tolerates. Cutting `τ_E` to 10 s does it cleanly, but `τ_E` is described in the code as "the
reactor's defining statistic" and changing it re-tunes D-D as well. **Both are Truls's calls, not
recommendations**; they are recorded here as the two options the arithmetic actually offers.

## Is bremsstrahlung what limits a real ignited D-T plasma?

**No, and this is the part the existing note gets most wrong by omission.** In a real D-T reactor
bremsstrahlung is a small, well-understood, roughly 5%-of-fusion-power tax, and it is not the binding
constraint on anything. The table above shows why, in this model's own numbers: at the clamp,
relativistic bremsstrahlung is 169 MW against 4 805 MW of fusion power — 3.5%.

What actually limits a burning plasma, in rough order of how hard each one bites:

**Transport, not radiation.** Real reactors are limited by how fast heat leaks out across the
magnetic field, which is the `E/τ_E` term the model already has and is the entire content of the
Lawson criterion. Every large tokamak's performance is quoted as a confinement time against an
empirical scaling law for exactly this reason. The model already carries the dominant loss.

**Cyclotron radiation, at these temperatures.** This is the one that should worry anyone modelling a
399 keV plasma. NRL Plasma Formulary (2019) equation (34), same section, same units convention:

> Cyclotron radiation in magnetic field B:
> `P_c = 6.21 × 10⁻²⁸ B² n_e T_e  watt/cm³`

Linear in `T_e`, not square-root — and quadratic in field strength. Evaluated for this reactor:

| B | T | P_cyclotron (unreabsorbed) | P_brem for comparison |
|---|---|---|---|
| 5 T | 8.77×10⁸ K | 11 700 MW | 70 MW |
| 5 T | 4.63×10⁹ K | 61 900 MW | 560 MW |
| 12 T | 4.63×10⁹ K | 357 000 MW | 560 MW |

Two to three orders of magnitude larger than bremsstrahlung, and larger than the fusion power. That
number is not the net loss — plasmas are optically **thick** to the low cyclotron harmonics and
reabsorb nearly all of it, and metal walls reflect much of what escapes, so the net figure in a real
reactor is a hard radiative-transfer calculation rather than a formula. Albajar, Bornatici and
Engelmann, "Improved calculation of synchrotron radiation losses in realistic tokamak plasmas",
*Nuclear Fusion* **41**, 665 (2001), and the code benchmarking that followed it, exist because there
is no closed form: the answer depends on the profile, the geometry and the wall reflectivity.

The contrast with bremsstrahlung is total, and it is worth stating because it is the reason
bremsstrahlung is the tractable one. NRL equation (31) gives the bremsstrahlung optical depth as
`τ ≈ 5.0 × 10⁻³⁸ ḡ Z n_e² L T_e^(−7/2)` with `ḡ ≈ 1.2`; at this reactor's density and a 10 m path
that is about **5×10⁻²⁴ at the D-D point and 1.5×10⁻²⁶ at 4.63×10⁹ K**. Optically thin by
twenty-odd orders of magnitude. Every bremsstrahlung photon leaves, always, which is why a one-line
formula is honest for it and would be a fabrication for cyclotron radiation.

**So: if the argument for adding a radiation term at 399 keV is fidelity, bremsstrahlung is not the
term that fidelity demands first.** It is the term that can be added in one line. Those are different
justifications and the repo should not conflate them.

**Impurity radiation and `Z_eff`.** In a real machine, material sputtered off the wall is the
dominant radiative loss, not hydrogenic bremsstrahlung. It enters two ways: it raises `Z_eff`, which
multiplies bremsstrahlung directly (equation 41 above), and partly-ionised heavy ions radiate through
*line* emission, which is a different and far more powerful channel. This is why tokamaks care
intensely about wall materials. Specific `Z_eff` targets for ITER were **not sourced primarily for
this note** — the ITER Physics Basis chapters are paywalled and were not obtained — so no number is
quoted here.

**Helium ash dilution.** Every D-T reaction leaves a helium-4 nucleus. It is doubly charged, so it
raises `Z_eff`; and at fixed electron density it displaces two units of fuel, so fusion power falls
as `(n_DT/n_e)²`. Ash removal rate versus energy confinement time is a genuine reactor design
constraint. Applied to this model at the clamp, though, it does not save the situation either:

| `n_He/n_e` | P_fus | P_α | vs. loss (transport 276 + brems 169) |
|---|---|---|---|
| 0 | 4 805 MW | 962 MW | 446 MW |
| 0.05 | 3 892 MW | 779 MW | 446 MW |
| 0.10 | 3 075 MW | 615 MW | 446 MW |
| 0.15 | 2 355 MW | 471 MW | 446 MW |

Even at a 15% ash fraction — far beyond what a real reactor would tolerate — alpha heating still
exceeds the losses and the plasma still climbs to the clamp. The specific `τ*_He/τ_E` figures the
literature uses were also **not sourced primarily** here.

**Density and beta limits.** Real machines cannot simply raise `n` to raise fusion power. The
empirical density limit is Greenwald *et al.*, "A new look at density limits in tokamaks", *Nuclear
Fusion* **28**, 2199 (1988); the paper was located but the hosted copy is an image scan and its text
could not be extracted, so the familiar `n_G = I_p / πa²` form (line-averaged density in 10²⁰ m⁻³,
plasma current in MA, minor radius in m) is reproduced here **from secondary reproduction, not from
the paper itself**. Pressure is separately capped by MHD stability — the Troyon beta limit — which
was **not sourced in this pass at all** and is mentioned only so the list is not misleadingly short.
Neither applies to this model, which has no plasma current, no field and no geometry.

## What adding it to this model would take

Mechanically, almost nothing — which is exactly the trap. In `M.step`, alongside the existing
`loss_j`:

```lua
-- Bremsstrahlung. NRL Plasma Formulary (2019) eq. (30), in SI: 5.34e-37 * Z_eff * n_e * n_i *
-- sqrt(T_keV) W/m^3, with Z_eff = 1 for a fully-ionised hydrogenic plasma. Taken against the
-- plasma still present, like loss_j, and for the same reason.
local n_after = remaining / spec.volume_m3
local brems_j = 5.34e-37 * n_after * n_after * math.sqrt(t_k / 1.1604518e7) * spec.volume_m3 * dt
```

subtracted in `new_thermal_j` and clamped jointly with `loss_j` so the two together cannot exceed
`kept_j`. It needs no new state, no new prototype field and no dependency: `left_j` is already
computed as what went in minus what was retained, so the radiated energy routes itself into
`captured_j` and gets sold at `capture_efficiency` — which is physically right, since the X-rays hit
the first wall and heat it. Two lines and a guard.

The relativistic factor is a third line if wanted, and at these temperatures it should be wanted —
it is worth 1.5× at the D-D point and 5.3× at the D-T one:

```lua
local t = (t_k / 1.1604518e7) / 511  -- T_e / m_e c^2
local xi = (1 + 1.78 * t^1.34) + 2.12 * t * (1 + 1.1 * t + t * t - 1.25 * t^2.5)
```

valid only for `t < 1`, i.e. below 5.93×10⁹ K. Above that the fit returns negative numbers — it was
hit during this investigation and it fails silently, exactly the class of bug `reactivity.lua`'s
`dx == 0` guard exists to prevent. Any implementation needs the same kind of guard.

**What it costs is the whole D-D tier**, and that is the finding, not the two lines. Restoring
something like the shipped D-D behaviour would need one of:

| change | D-D result with bremsstrahlung |
|---|---|
| shipped: 50 MW, `τ_E` 30 s | 2.42×10⁸ K, Q 0.32, 16 MW |
| heating → 150 MW | 1.13×10⁹ K, Q 0.95, 143 MW |
| heating → 200 MW | 1.50×10⁹ K, Q 0.96, 193 MW |
| `τ_E` → 60 s | 6.48×10⁸ K, Q 1.47, 73 MW |
| `τ_E` → 100 s | 1.40×10⁹ K, Q 3.58, 179 MW |
| `τ_E` → 200 s | 2.13×10⁹ K, Q 5.33, 267 MW |

Raising the heating power cannot restore Q above about 0.97 no matter how far it is pushed — it peaks
there at roughly 175 MW and falls away on both sides, because
bremsstrahlung grows with the temperature the extra heating buys, and Q is fusion over *heating*, so
the denominator grows too. **Only a longer confinement time restores an ignited-looking D-D tier**,
and `τ_E` ≈ 100 s gets to Q 3.6 at 1.4×10⁹ K. Which of these, if any, is a balance decision and
belongs to Truls.

And for D-T: **no, adding bremsstrahlung does not produce an equilibrium below 2.147×10⁹.** It
produces one at 3.26×10⁹, which is still above the int32 ceiling, so the clamp and the pinned
temperature signal survive the change unchanged. The stated motivation in `d-t-ignition.md` —
"fixing it properly means a bremsstrahlung term" — does not hold: a bremsstrahlung term does not fix
the pinned signal.

## Verdict on the existing claim

The claim, in `reactor-logic.lua` lines 115–117 and `docs/research/d-t-ignition.md` point 1:

> A real D-T plasma at 1e20 m^-3 has exactly such a channel in bremsstrahlung, which this
> zero-dimensional model does not carry and which would bite long before 4.6e9.

**Overstated on its central point, and misleading in what it implies.** Taken clause by clause:

- *"A real D-T plasma at 1e20 m⁻³ has exactly such a channel in bremsstrahlung"* — **supported**. It
  does, the formula is standard, and at `Z_eff = 1` and 10²⁰ m⁻³ it is 169 MW at the clamp and 560 MW
  at 4.63×10⁹ K.
- *"which this zero-dimensional model does not carry"* — **supported**, trivially. It does not.
- *"and which would bite long before 4.6e9"* — **overstated**. It bites *at* 4.6×10⁹, moving the
  equilibrium to 3.26×10⁹ K. "Long before" implies it would bring the plasma down near the clamp, and
  it does not: 3.26×10⁹ is still 52% above the clamp and 52% above the int32 ceiling.
- The implication that the clamp is therefore "the less wrong physics" — **not supported as
  argued**. The clamp discards 640 MW at 2×10⁹ K; bremsstrahlung there is 169 MW. The clamp is not
  standing in for bremsstrahlung; it is nearly four times too large to be. It is standing in for the
  model's missing transport at high temperature, or for nothing in particular.
- The implication that bremsstrahlung is the dominant thing missing — **wrong**. At 399 keV,
  unreabsorbed cyclotron radiation is two to three orders of magnitude larger, and the reason it is
  not in the model is that it cannot be written in one line, not that it is small.

The claim is also **silent on the finding that matters more**: adding bremsstrahlung breaks D-D, the
tier that currently works, dropping it from Q 2.14 to Q 0.32. That is the actual consequence of the
change the note proposes, and neither document mentions it.

### What would have to change in the repo

Not done here — this note modifies nothing but itself, as instructed — and the wording is Truls's
call. What is factually wrong and should not survive as written:

1. **`RealisticFusion/scripts/reactor-logic.lua`, lines 115–119.** "would bite long before 4.6e9" is
   not true; it moves the equilibrium to 3.26×10⁹. The sentence can be repaired without giving up the
   conclusion — the clamp *should* stay, because the int32 ceiling is a hard constraint and reason 2
   in `d-t-ignition.md` was always the load-bearing one. What has to go is the claim that
   bremsstrahlung justifies it.
2. **`docs/research/d-t-ignition.md`, the "equilibrium that isn't" section, point 1.** Same sentence,
   same problem. Its closing line — "Fixing it properly means a bremsstrahlung term, which would move
   D-D's balance too" — is half right in a useful way: bremsstrahlung *would* move D-D's balance, far
   more than the author seems to have expected, but it would **not** fix the pinned D-T temperature,
   which is what that paragraph claims it would fix.
3. **Ticket #37**, whatever it currently says about adding bremsstrahlung to lower the D-T
   equilibrium below the int32 ceiling. It will not. If the pinned temperature signal is the goal,
   the levers that reach it are `τ_E`, `heating_power_w`, `particles_per_unit`, or a different signal
   encoding — not a radiation term.

The honest one-line summary for whoever picks this up: **bremsstrahlung is real, it is a genuine gap
in the model, adding it is two lines — and it would cost the D-D tier and buy nothing on D-T.**

## Sources

Primary, read directly:

- **NRL Plasma Formulary**, 2019 revision, A. S. Richardson, Pulsed Power Physics Branch, Naval
  Research Laboratory. "Radiation" section, pp. 57–58; eq. (30) bremsstrahlung, eq. (31) optical
  depth, eq. (34) cyclotron radiation. The canonical page at `nrl.navy.mil` returned HTTP 403 from
  this network; the copy read was the mirror at
  <https://tanimislam.github.io/research/NRL_Formulary_2019.pdf>, and the MIT PSFC library copy at
  <https://library.psfc.mit.edu/catalog/online_pubs/NRL_FORMULARY_19.pdf> is the same document.
- **S. E. Wurzel and S. C. Hsu**, "Progress toward fusion energy breakeven and gain as measured
  against the Lawson criterion", *Physics of Plasmas* **29**, 062103 (2022). arXiv:2105.10954.
  Eq. (7) and `C_B`; eq. (8) and the 4.3 keV ideal ignition temperature; eq. (41) `Z_eff`; eq. (43);
  appendix D eqs. (D1)–(D2) relativistic correction.
- **T. H. Rider**, "Fundamental limitations on plasma fusion systems not in thermodynamic
  equilibrium", *Physics of Plasmas* **4**, 1039 (1997), eq. (21). Read at
  <https://riderinstitute.org/wp-content/uploads/2019/11/INFERNO5.pdf>.
- **H. Xie**, "Bremsstrahlung radiation power in fusion plasmas revisited: towards accurate
  analytical fitting", *Plasma Physics and Controlled Fusion* (2024). arXiv:2404.11540. Figure 1
  comparing seven published fits and their validity bounds.
- **The repository's own data**: `RealisticFusion/cross-section-data/reactivities.lua`, derived by
  `tools/derive-reactivities.py` from ENDF/B-VIII.0 (<https://www-nds.iaea.org/exfor/endf.htm>).
  161 points per reaction, 2.32×10⁶ K to 6.96×10⁹ K, so every equilibrium in this note is interpolated
  inside the table rather than clamped at its ends. D-T peaks at 8.94×10⁻²² m³/s at 7.60×10⁸ K
  (65 keV).

Cited but read only as quoted by a source above:

- **S. Putvinski, D. Ryutov and P. Yushmanov**, *Nuclear Fusion* **59**, 076018 (2019) — the origin of
  the relativistic fit, via Wurzel and Hsu's reference 137. Not read directly.
- **F. Albajar, M. Bornatici and F. Engelmann**, "Improved calculation of synchrotron radiation
  losses in realistic tokamak plasmas", *Nuclear Fusion* **41**, 665 (2001) — abstract and citing
  literature only; the paper is paywalled.
- **M. Greenwald et al.**, "A new look at density limits in tokamaks", *Nuclear Fusion* **28**, 2199
  (1988) — located, but the accessible copy is an image scan and its text could not be extracted. The
  `n_G = I_p/πa²` form given above is from secondary reproduction.

Not sourced primarily, and flagged as such in the text where used:

- The D-D ideal ignition temperature. Computed here from the repo's dataset (44 keV non-relativistic,
  72 keV relativistic); no primary source found in this pass stating a comparable published figure.
- ITER's `Z_eff` and helium ash (`τ*_He/τ_E`) design targets. The ITER Physics Basis chapters are
  paywalled and were not obtained; no numbers are quoted.
- The Troyon beta limit. Named only; not sourced in this pass.
- Freidberg's *Plasma Physics and Fusion Energy* and Wesson's *Tokamaks* were both sought and neither
  was obtainable. Everything they would have supplied is instead cited to Wurzel and Hsu, which is
  peer-reviewed and was read in full.
