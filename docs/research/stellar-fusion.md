# Stellar fusion, and why "the Sun does it" is not an argument for a reactor

Researched 2026-08-21 against primary sources, on a bounded question rather than as a survey. The
question, from Truls: *"I have the understanding that the sun fuses helium and heavier elements with
positive energy. Is this false or is there some other effect in place here (i.e. the extreme scale)."*
With the qualification *"no need to go very deep in this topic. The mod is not going to make a 'sun'
entity."*

**Nothing here decides anything.** [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md)'s
reaction set is scope and scope is Truls's; this note
records what the physics says and, at the end, one thing it puts in front of a decision.

Computed against a standard solar model read directly — **Bahcall's BS2005-AGS,OP** export table, 1284
zones — and against **AME2020**'s mass table, both downloaded and parsed rather than quoted from
memory. Every derived number below says so where it is derived. The reactor-side figures are
[`bremsstrahlung.md`](bremsstrahlung.md)'s and the shipped model's, not re-derived here.

**Cross-references rather than repeats.** [`further-reactions.md`](further-reactions.md) already
surveys p-p and rules it out on its S-factor, already surveys the lithium and boron families, and
already establishes that counting bremsstrahlung correctly kills the He3-He3 tier. This note does not
redo any of that. What it adds is the *stellar* side: what the Sun actually runs, what it does with
scale, and what that does and does not license.

## The short version

**The premise is true, and it is also nearly irrelevant to the Sun.** Fusion of helium and of
everything up to the iron peak is exothermic — the triple-α process releases 7.275 MeV and the Sun
will run it, in about 7.6 billion years, for 130 million years. Right now it runs none of it. Today
the Sun is a hydrogen burner and nothing else, at **99.36% pp chain and 0.64% CNO**.

**"The extreme scale" is the right instinct, and it decomposes into four different things, only two of
which a reactor could ever buy.** Density and confinement time are the two the Sun wins on
outrageously — 3.3×10¹¹ times this mod's plasma density and 3.3×10¹³ times its confinement time. The
two it cannot sell are the weak interaction, which is what makes p-p permanently unavailable to any
machine, and three-body kinematics at reactor density, which is what makes triple-α unavailable. And
the Sun *loses* on temperature and on power density, which is the part nobody expects.

**The single number that makes the point: the centre of the Sun produces 239 W/m³, which is
1.6 milliwatts per kilogram — and a resting human body produces 1.16 W/kg, seven hundred and thirty
times more.** Averaged over the whole Sun it is 0.27 W/m³ and 0.19 mW/kg, and the human margin becomes
six thousandfold. The Sun is not a good reactor. It is a mediocre reactor of enormous size, held
together for free, and left running for ten billion years.

**And the finding that turns the question around.** One of ADR 0010's four reactions *is* a solar
reaction, and it is the top one:

> `³He + ³He → ⁴He + 2p`, the mod's `rf-he3-he3-plasma` at 12.859 MeV, is the pp-I termination — the
> most common fusion reaction in the Sun's core, running **84.2%** of its terminations and supplying
> about **40%** of its total nuclear energy release.

So "the Sun does this reaction constantly" is *already true* of the reaction this mod puts at the end
of its tech tree, and it does not help: with bremsstrahlung counted at helium-3's real electron
density, He3-He3 has no ignited state at all ([`further-reactions.md`](further-reactions.md)). That is
the answer to whether stellar precedent is ever an argument here. It is not, and the counter-example
is already in the mod.

## What the Sun is actually running

From **Vinyoles et al. 2017**'s B16-GS98 neutrino fluxes (Table 6) — the standard solar model, read
directly. Terminations are counted as ⁴He nuclei produced: every pp or pep reaction makes one ³He, the
pp-II and pp-III branches consume one each and are counted by the ⁷Be and ⁸B fluxes, and pp-I consumes
two. Computed here from those fluxes:

| branch | reaction that ends it | share of terminations |
|---|---|---:|
| **pp-I** | `³He + ³He → ⁴He + 2p` | **84.24%** |
| **pp-II** | `⁷Be(e⁻,ν)⁷Li(p,α)⁴He` | **15.10%** |
| pp-III | `⁷Be(p,γ)⁸B(β⁺)⁸Be → 2α` | 0.0167% |
| hep | `³He + p → ⁴He + e⁺ + ν` | 2×10⁻⁷ % |
| **CNO** | `¹⁵N(p,α)¹²C` | **0.644%** |

**The arithmetic checks against something the model was not fitted to.** Multiply the total —
3.265×10¹⁰ ⁴He nuclei cm⁻²s⁻¹ at 1 AU — by 26.73 MeV and it gives **1371 W/m²** against the IAU 2015
nominal total solar irradiance of **1361 W/m²** (Prša et al. 2016). Seven parts in a thousand, from
neutrino fluxes and a Q value alone. That is the check that the branch fractions above are being read
correctly, and it is why they are quoted rather than the textbook 85/15.

Two things to take from the table.

**The CNO cycle is real, measured, and small.** B16-GS98 predicts 0.64% of terminations; **Borexino**
detected its neutrinos in 2020, which is the first direct confirmation that the Sun runs it at all.
The commonly repeated "about 1%" is the right order and slightly high for the high-metallicity model.

**Nothing in the table is a reaction this mod's fuel chain touches, except the first row.** The Sun
holds essentially no deuterium: **Adelberger et al. 2011** §IV states that `d(p,γ)³He` is so much
faster than the pp weak rate that *"the lifetime of a deuterium nucleus in the solar core is ~1 s, and
the equilibrium abundance of deuterium relative to H is maintained at ~3×10⁻¹⁸"*. So D-D, D-T and
D-He3 do not happen in the Sun in any quantity worth a digit, and there is no tritium there at all.
The mod burns four reactions; the Sun runs one of them, and runs it more than any other.

## Helium burning: exothermic, and the Sun's problem is timing

`3 ⁴He → ¹²C` releases **7274.75 keV**, computed from AME2020 mass excesses (3 × 2424.91587 keV, ¹²C
being zero by definition of the scale). Exothermic, and not marginally.

What makes it hard is not the energy but the route, and the route is the whole content of the
"density-and-time" argument later in this note. From **José & Iliadis 2011** §5.2:

> "Helium burning in massive stars and AGB stars takes place in the temperature range of
> T = 0.1 – 0.4 GK and starts with the fusion of two α-particles. The composite nucleus ⁸Be lives for
> only ~10⁻¹⁶ s and quickly decays back into two α-particles. After a given time a tiny equilibrium
> abundance of ⁸Be builds up, sufficient to allow for capture of a third α-particle to form ¹²C. […]
> The triple-α reaction is a (sequential) three-body interaction and thus has not been measured in the
> laboratory."

The two constants that decide it, both primary:

- **⁸Be is unbound by 91.840 keV** — computed from AME2020's ⁸Be and ⁴He mass excesses (4941.672 and
  2424.91587 keV).
- **Its total width is Γ = 5.57 ± 0.25 eV**, from the TUNL A=8 evaluation (**Tilley et al. 2004**), a
  26 eV-resolution ⁴He(α,α) measurement. That is a mean life of `ħ/Γ` = **1.18×10⁻¹⁶ s**, or a
  half-life of 8.2×10⁻¹⁷ s.

**Will the Sun ever do it? Yes, and there is a date.** From **Schröder & Smith 2008**'s solar
evolution model (Table 1 and §2): the Sun leaves the main sequence around an age of 10 Gy, reaches the
tip of the red giant branch at **12.167 Gy** — the paper's abstract puts that at *"7.59 Gy from
now"* — and then enters a *"brief (130 million year) He-burning phase"*. Their zero-age helium model
sits at 53.7 L☉ against 2730 L☉ at the RGB tip.

Worth noticing, because it cuts against the intuition that heavier fuel means more power: as a
core-helium-burning star the Sun radiates **a fiftieth** of what it radiates at the tip of the red
giant branch, where the energy is coming from a hydrogen shell. Helium burning is what a star does when
it has run out of the good fuel.

## Where exothermic fusion actually stops

Three different questions with three different answers, and conflating them is where the popular
answer comes from.

**Highest binding energy per nucleon of any nuclide.** Ranked from AME2020's full table, measured
values only:

| nuclide | BE/A (keV) |
|---|---:|
| **⁶²Ni** | **8794.5555 ± 0.0069** |
| ⁵⁸Fe | 8792.2534 ± 0.0055 |
| ⁵⁶Fe | 8790.3563 ± 0.0048 |
| ⁶⁰Ni | 8780.7769 ± 0.0059 |
| ⁵⁴Cr | 8777.9672 ± 0.0025 |

**⁶²Ni wins, ⁵⁶Fe is third, and the margin is 4.2 keV per nucleon — 0.05%.** The uncertainties are
seven electron-volts, so the ordering is not in doubt; the popular answer is simply wrong, and it is
wrong by a hair.

**Endpoint of stellar fusion as it actually runs: ⁵⁶Ni.** Silicon burning reaches nuclear statistical
equilibrium, and at the small neutron excess of a massive star's core NSE favours ⁵⁶Ni over the iron
isotopes (José & Iliadis §6.2). ⁵⁶Ni then β-decays to ⁵⁶Co and on to ⁵⁶Fe, which is why the iron peak
is iron and not nickel, and why supernova light curves are powered by that decay chain.

**Where fusion stops being *useful*, which is much earlier than either.** Two effects, both from José &
Iliadis §6.1: hydrogen burning releases far more energy per unit mass than anything after it, and
**past helium burning most of the energy leaves as neutrino–antineutrino pairs** from pair annihilation
and the photo-neutrino process, which escape freely. Core silicon burning lasts about **one day**.
Exothermic and useful are different properties, and the gap between them opens long before ⁶²Ni.

For this mod the practical point is that the ceiling nobody will ever reach is not the interesting
one: ADR 0010's chain ends at helium-3, five decades of binding energy below any of this.

## The scale question, quantified

### Power density, which is the number that settles it

Computed from the BS2005-AGS,OP luminosity profile: the enclosed luminosity divided by the enclosed
volume, which is a power density by construction and needs no rate formula.

| | power density | per unit mass |
|---|---:|---:|
| solar centre (r < 0.01 R☉) | **239 W/m³** | 1.6 mW/kg |
| within 0.1 R☉ (44% of L☉) | 120 W/m³ | 1.1 mW/kg |
| within 0.24 R☉ (98% of L☉) | 19 W/m³ | 0.42 mW/kg |
| **whole Sun** | **0.271 W/m³** | **0.192 mW/kg** |
| a resting 70 kg human | ~1200 W/m³ | **1160 mW/kg** |
| **this mod's D-D reactor** (16 MW / 1000 m³) | **16 000 W/m³** | — |
| **this mod's D-T reactor at the clamp** (4805 MW / 1000 m³) | **4 805 000 W/m³** | — |

The human figure uses the FAO/WHO/UNU basal metabolic rate equation for males aged 30–60 —
`BMR = 0.048 × kg + 3.653 MJ/day`, Table 5.2 — which gives 81 W for 70 kg. Per kilogram that is
**730× the centre of the Sun** and **6000× the Sun's average**. The per-volume row for a human is
softer, because it needs a body density this note did not source; the per-mass comparison needs only a
mass and is the one to quote.

**The mod's weakest reactor is 67 times more power-dense than the centre of the Sun.** That is
`rf-reactor` on D-D — the breeder tier, below scientific break-even, the machine `CONTEXT.md` says
must not be described as a power source. The D-T tier at the clamp is twenty thousand times the solar
centre. A Factorio reactor is a fifteen-tile square; the Sun's energy-producing core is 10²⁵ m³. That
ratio, and not any per-volume superiority, is where the Sun's 3.8×10²⁶ W comes from.

### The pp bottleneck, which no engineering removes

The first step of the pp chain is not a strong-interaction reaction. It requires one of the two protons
to β-decay during the collision, and that is a weak process. **Adelberger et al. 2011** §III, the
canonical evaluation, opens with the consequence:

> "The rate for the initial reaction in the pp chain, p+p → d + e⁺ + ν_e, is too small to be measured
> in the laboratory. Instead, this cross section must be calculated from standard weak interaction
> theory."

Its recommended value, eq. (25):

> `S₁₁(0) = 4.01(1 ± 0.009) × 10⁻²⁵ MeV b`

Against the same paper's eq. (32) for the *next* strong reaction in the chain — `³He(³He,2p)⁴He` at
`S₃₃(0) = 5.21 ± 0.27 MeV b` — that is a factor of **1.3×10²⁵**, which is the same twenty-five orders
of magnitude [`further-reactions.md`](further-reactions.md) already refuses p-p on, now measured
against a reaction the Sun itself runs rather than against a range.

**What that costs in time, computed here.** At the solar centre the model gives ρ = 1.505×10⁵ kg/m³ and
X = 0.3646, so `n_p` = 3.28×10³¹ m⁻³. At 239 W/m³ and 26.2 MeV of thermal energy per ⁴He, the centre
completes 5.69×10¹³ chains m⁻³s⁻¹, consuming four protons each. So:

> **A proton at the centre of the Sun waits about 4.6 billion years to fuse.**

That is not a rhetorical number and it has an internal check: the Sun is 4.6 Gyr old, and BS2005 has
its central hydrogen down from 0.71 to 0.365. A per-proton lifetime of order the Sun's age is exactly
what a half-burnt core requires.

**And the reason this is permanent rather than hard.** The solar core is **3.3×10¹¹ times denser** than
this mod's plasma at 10²⁰ m⁻³. Three hundred billion times the density, unlimited time, and a proton
still waits four and a half billion years. There is no confinement time, density or purity that recovers
twenty-five orders of magnitude in an S-factor, because the shortfall is not in the barrier — p-p's
Gamow energy is *half* D-D's — it is in the strength of the interaction. [ADR 0014](../adr/0014-realistic-means-theoretically-possible.md)
licenses putting confinement, density and purity anywhere the physics permits. It does not license changing the weak
coupling constant, and a p-p reactor is that, not a harder machine.

### Triple-α, where the effect really is density and time

Triple-α is the case where "the extreme scale" is the whole answer, and it is quantifiable. The
mechanism is sequential through an equilibrium population of ⁸Be, so what a reactor would need is a
third α arriving inside 1.18×10⁻¹⁶ s.

Computed here from nuclear statistical equilibrium — `n(⁸Be)/n(α)²` from the two masses and the
91.840 keV separation energy, both 0⁺ so the degeneracies are 1:

| | n(α) | n(⁸Be) | ⁸Be per α |
|---|---:|---:|---:|
| helium-burning core, ρ = 10⁴ g/cm³, 10⁸ K | 1.5×10³³ m⁻³ | 1.0×10²³ m⁻³ | 6.7×10⁻¹¹ |
| helium-burning core, ρ = 10⁵ g/cm³, 10⁸ K | 1.5×10³⁴ m⁻³ | 1.0×10²⁵ m⁻³ | 6.7×10⁻¹⁰ |
| **this mod's reactor**, 10²⁰ m⁻³, 2.42×10⁸ K | 1.0×10²⁰ m⁻³ | **0.061 m⁻³** | 6.1×10⁻²² |

The middle row reproduces the ~10⁻⁹ equilibrium fraction the helium-burning literature quotes, which is
the check on the implementation. The bottom row is the finding:

> **A 1000 m³ magnetic bottle at this mod's density contains about 61 ⁸Be nuclei at any instant.** A
> cubic metre of it contains one sixteenth of one.

Because the triple-α rate goes as `n(α)³`, the shortfall against a helium-burning core at 10⁴ g/cm³ is
**3.4×10³⁹**, and against 10⁵ g/cm³ it is 3.4×10⁴². Time does not buy that back: a star has 130
million years, which is 1.4×10¹⁴ times this reactor's 30 s confinement — twenty-five orders short of
the deficit.

**So triple-α is exactly the thing Truls's "extreme scale" was reaching for**, and it is the one place
in this note where the answer is genuinely and only scale. Gravitational confinement supplies the
density; nothing else does. A magnetic bottle is held to something like 10²⁰–10²¹ m⁻³ by pressure, and
inertial confinement reaches comparable densities for a fraction of a nanosecond, which is the wrong
half of the product. (Both of those are stated as orders of magnitude and neither was sourced in this
pass; nothing above turns on either.)

### Gravitational confinement against magnetic, in one table

| | this mod's reactor | the Sun's core |
|---|---:|---:|
| fuel-nucleus density | 10²⁰ m⁻³ | 3.3×10³¹ m⁻³ (protons) |
| temperature | 21 keV (D-D, shipped) | **1.33 keV** |
| energy confinement time | 30 s | 3.1×10⁷ yr = 9.9×10¹⁴ s |
| triple product `n_e Tτ` | 6.3×10²² keV·s·m⁻³ | 8.2×10⁴⁶ keV·s·m⁻³ |
| confined mass | 3×10⁻⁴ kg of plasma | 9.0×10²⁹ kg within 0.24 R☉ |

The Sun's confinement time here is the Kelvin–Helmholtz time, `GM²/RL`, computed from the IAU 2015
nominal values — the time the Sun would take to radiate its gravitational binding energy, which is the
star's analogue of `τ_E`. It is 3.3×10¹³ times this reactor's.

**The Lawson criterion is satisfied by the Sun so trivially that it stops being informative, and that
is the lesson.** The Sun's triple product is twenty-five orders of magnitude above the D-T ignition
threshold of order 3×10²¹ keV·s·m⁻³, and it still manages 0.27 W/m³. The reason is that the criterion
is *per fuel*: applying D-T's threshold to a p-p plasma is a category error, and p-p's own threshold is
worse by something like the twenty-five orders its S-factor is down — nothing in the barrier offsets
that, because p-p's Coulomb barrier is the *lower* of the two. A tokamak fails Lawson by a factor of a few and
would produce megawatts per cubic metre; the Sun beats it by 10²⁵ and produces less per kilogram than a
sleeping person. **Confinement is not what the Sun is good at making power with. Volume is.**

Note also that the Sun's core is *colder* than any of this mod's plasmas — 1.33 keV against a shipped
D-D equilibrium of 21 keV. So per pair of nuclei it fuses very much *less* often than this reactor
does. What it has instead is 3.3×10¹¹ times the number density, which is **10²³ times the pair density**
because a rate goes as `n²`, and ten billion years in which to be inefficient. That is the whole
trade, and it is not one a machine can make.

## What this means for this mod

### Whether "the Sun does it" is ever an argument here — no, and the counter-example already ships

[ADR 0014](../adr/0014-realistic-means-theoretically-possible.md) fixes what "realistic" means: *"Reactions, branching ratios, energy releases and
cross-sections are physics and are not negotiable. Confinement time, density, purity and capture
efficiency are engineering, and this mod is free to place them anywhere the physics permits."*

Read against this note, that formulation holds up well and draws the line in the right place:

- **It correctly excludes p-p**, because the obstacle is an interaction strength and not a parameter.
  [`further-reactions.md`](further-reactions.md) already reached that conclusion and used p-p as ADR
  0014's boundary case; this note adds the stellar side of the same fact, which is that even at
  3×10¹¹ times the density it takes five billion years.
- **It correctly excludes triple-α**, and by a route worth having written down: the deficit is
  10³⁹–10⁴² in density-cubed, and ADR 0014's licence to put density "anywhere the physics permits" runs
  into the fact that pressure is physics. A plasma at 10³³ m⁻³ is not a confinement setting; it is a
  different state of matter held up by 2×10³⁰ kg of overburden.
- **It gives no weight at all to stellar precedent, and it should not**, because He3-He3 is a solar
  reaction — 84% of the Sun's terminations and 40% of its power — and it is also the tier that
  [`further-reactions.md`](further-reactions.md) finds has no ignited state once its two electrons per
  ion are counted. The Sun runs the mod's hardest reaction constantly. That proves nothing about a
  bottle, and it is the cleanest available demonstration that "it happens in nature" and "it works in a
  machine" are unrelated claims.

**ADR 0010's reaction set is vindicated rather than challenged**, and for a slightly odd reason: three
of its four reactions are ones the Sun essentially never runs, because the Sun contains no deuterium
(3×10⁻¹⁸ relative to hydrogen) and no tritium. That is the correct choice under ADR 0014's standard,
which asks for theoretically possible and not for observed-in-nature — and it is the same choice every
real fusion programme has made, for the same reason.

**One decision this note puts in front of Truls, with the trade-offs, and does not take.** ADR 0010's
chain ends at He3-He3, and this note has established that the reaction is the Sun's most common one
while `further-reactions.md` has established that the tier cannot ignite in this model. Truls already
decided on 2026-08-21, under #52's last criterion, to **leave the tier as it is** — the code says so
at `reactor-logic.lua`'s He3-He3 row, with the reasoning that ADR 0014 makes a marginal tier
legitimate. Nothing here reopens that. What is new is only that the tier now has an unusually good
piece of flavour text available to it if the decision is ever revisited: the reaction the player
researches last is the reaction the Sun has been running for four and a half billion years, and it
still will not light in a box. Whether that is worth surfacing to a player — a tooltip, a technology
description, nothing — is a decision, not a finding.

### Whether `reactor-logic.lua`'s radiation term is contradicted — no, and the reason is already in the repo

The premise is right: in a star, free–free emission is the *transport* mechanism that carries energy
out over ~10⁵ years, not a loss channel. **Mitalas & Sills 1992** computed the photon diffusion time
for the present Sun as **170 000 years**, from a random walk with a 0.090 cm mean step. Nothing leaves;
it is re-absorbed and re-emitted the whole way out, and what finally escapes at the photosphere is the
same energy thermalised down to 5772 K.

**This does not affect the shipped model, and `bremsstrahlung.md` already established why.** The
distinction is optical depth, and it is not close. Using the same NRL Plasma Formulary form that note
used — eq. (31), `τ ≈ 5.0 × 10⁻³⁸ ḡ Z n_e² L T_e^(−7/2)` with `ḡ ≈ 1.2`:

| | `n_e` | T | path | free–free optical depth |
|---|---:|---:|---:|---:|
| solar core | 6.2×10³¹ m⁻³ | 1.33 keV | 1 R☉ | **1.9×10¹⁴** |
| this mod's D-D plasma | 10²⁰ m⁻³ | 21 keV | 10 m | **4.6×10⁻²²** |

Thirty-five orders of magnitude between them, and the reactor row reproduces `bremsstrahlung.md`'s own
figure (5×10⁻²⁴ at its 76 keV point; this implementation gives 5.0×10⁻²⁴ there), which is the check
that the two are being computed the same way. **The Sun is optically thick by fourteen orders of
magnitude and this reactor is optically thin by twenty-one.** Same emission mechanism, opposite regime, and the
regime is what decides whether the photon is transport or loss.

So the term as shipped is correct as written, and correct for the reason its own comment gives: every
bremsstrahlung photon leaves. Three specific things follow, none of which asks for a change:

- **`brems_j` being subtracted as a drain is right**, and it stays right at any density Factorio can
  represent. The crossover to optical thickness is thirty-odd orders of magnitude away.
- **Routing the radiated energy into `captured_j` is also right**, and the stellar case is the reason
  the distinction matters: the X-rays are not lost from the *machine*, only from the *plasma*, and they
  land on the first wall. That is what makes the shipped D-D tier sell 56.1 MW against 50 MW drawn while
  sitting at Q 0.32 — `CONTEXT.md`'s two break-evens. A star has no first wall and no `captured_j`; it
  has 0.7 R☉ of its own body doing the same job, and calls the result its luminosity.
- **The one place the stellar analogy would matter is a channel the model does not carry.** In a real
  reactor at these temperatures the dominant radiative term is cyclotron radiation, and plasmas are
  optically *thick* to its low harmonics — so that channel is genuinely part-transport and part-loss,
  which is precisely why `bremsstrahlung.md` says it cannot be written in one line and refuses to.
  Nothing about the Sun changes that assessment; if anything it illustrates it.

## What is not verified

- **Every solar number here is computed by this note from published data, and none of it is in a
  checked-in harness.** The scripts that produced the branch fractions, the power-density profile, the
  proton lifetime, the ⁸Be equilibrium and the optical depths were written to a scratchpad and are not
  committed — unlike [`bremsstrahlung.md`](bremsstrahlung.md)'s and
  [`further-reactions.md`](further-reactions.md)'s, which are `tests/test-bremsstrahlung.lua` and
  `tests/test-further-reactions.lua`. Nothing in the mod depends on any figure in this note, which is
  why no harness was added for it; if any of it ever becomes load-bearing on a balance decision, it
  should be.
- **The solar power-density profile is a numerical derivative of a tabulated luminosity fraction**, and
  the innermost few zones of BS2005 carry too little enclosed luminosity to differentiate cleanly. The
  central figure quoted (239 W/m³) is `L(<r)/V` over spheres of 0.01 to 0.02 R☉, which is stable to 2%
  across that range; a zone-by-zone derivative is noisier and peaks around 226–240 W/m³ in the same
  region. Read it as "about 240", not as three digits.
- **BS2005-AGS,OP is not the model the branch fractions come from.** The fluxes are Vinyoles et al.
  2017's B16-GS98; the structural profile is Bahcall's BS2005 with AGS abundances, which is a *low*-Z
  model. Mixing the two is fine for the order-of-magnitude statements this note makes and would not be
  fine for anything precise. The central temperature and density differ by a few per cent between the
  two composition families, which is the same size as the difference this note ignores.
- **Bahcall's exported model table is the author's own published data rather than a paper**, read at
  `http://www.sns.ias.edu/~jnb/SNdata/Export/BS2005/bs05_agsop.dat`. Its companion paper
  (astro-ph/0412440) was **not read**; the column definitions come from the file's own header.
- **The ⁸Be equilibrium calculation assumes nuclear statistical equilibrium between α and ⁸Be, and
  treats the reactor case with the same expression.** That is the standard treatment for the stellar
  regime and it is being extrapolated, not derived, for the reactor regime — where the population would
  in reality be set by a kinetic balance nothing establishes at 61 nuclei in 1000 m³. The point the
  number makes survives any such correction by dozens of orders of magnitude, but the number itself
  should not be quoted as a rate.
- **The triple-α rate itself was not obtained.** NACRE II covers only two-body exoergic reactions and
  excludes it; **Fynbo et al. 2005** (*Nature* **433**, 136) and Caughlan & Fowler 1988 were not read.
  Everything this note says about triple-α rests on the two nuclear constants (both primary) and on
  José & Iliadis's description of the mechanism, not on a tabulated rate.
- **The Hoyle state is not sourced here.** The 7.654 MeV 0⁺ resonance in ¹²C is what makes the third-α
  capture fast enough to matter at all, and the TUNL A=11,12 evaluation was not fetched. The note does
  not use its energy or width for anything.
- **Adelberger et al. 2011's ~1 s deuteron lifetime and 3×10⁻¹⁸ deuterium abundance are quoted as the
  paper states them**, not recomputed. `S₃₃(0)` is taken from their eq. (32) rather than their Table I:
  the text-extracted Table I has its value column shifted against its reaction labels, which would put
  5.21 MeV·b on the wrong reaction. It was caught by checking each value against the section that
  derives it, and no other S-factor is quoted from that table.
- **The D-T triple-product ignition threshold of order 3×10²¹ keV·s·m⁻³ is from common usage and was
  not sourced in this pass.** Nothing here depends on its precise value: the Sun exceeds it by
  twenty-five orders of magnitude and the argument is about the exponent, not the coefficient. The same
  goes for the magnetic and inertial density limits quoted in the triple-α section, and for the
  inference that p-p's own threshold is worse by roughly the twenty-five orders its S-factor is down —
  that is reasoning from `S₁₁` and the two Gamow energies, not a computed criterion.
- **The human basal metabolic rate uses the FAO/WHO/UNU predictive equation, not a measurement**, and
  its standard error of estimate is 0.700 MJ/day — 10% on the figure quoted. The per-volume row in the
  power-density table additionally assumes a body density this note did not source, and is marked soft
  for that reason.
- **Mitalas & Sills 1992 was not read.** Only its abstract, via ADS and search results; the paper is
  not open access and the ADS full-text scan carries no extractable text. The 170 000 years and the
  0.090 cm step length are as quoted in its abstract.
- **Schröder & Smith 2008 is one model.** Its RGB-tip age of 12.167 Gy is 0.3% from Sackmann,
  Boothroyd & Kraemer 1993's, which is the other standard reference and was **not read** — its ADS copy
  is an image scan with no text layer and no OCR was available on this machine. Where the two are
  compared in Schröder & Smith's own text they differ materially only on RGB mass loss (0.332 against
  0.275 M☉), which nothing here depends on.
- **Nothing here has been run in Factorio, and nothing here changed a line of the mod.** No prototype,
  no test, no gate and no ADR was touched.

## Sources

Primary, read directly:

- **N. Vinyoles, A. M. Serenelli, F. L. Villante, S. Basu, J. Bergström, M. C. Gonzalez-Garcia,
  M. Maltoni, C. Peña-Garay and N. Song**, "A new generation of standard solar models",
  *Astrophysical Journal* **835**, 202 (2017), arXiv:1611.09867. Read. **Table 6** for the B16-GS98 and
  B16-AGSS09met neutrino fluxes and their units, from which every branch fraction here is computed;
  §2.1 for what B16 is.
- **E. G. Adelberger et al.**, "Solar fusion cross sections. II. The pp chain and CNO cycles",
  *Reviews of Modern Physics* **83**, 195 (2011), arXiv:1004.2318v3. Read. §III opening paragraph and
  eq. (25) for `S₁₁(0)` and for the statement that p-p is too small to measure; §IV for the ~1 s
  deuteron lifetime and the 3×10⁻¹⁸ equilibrium deuterium abundance; eq. (32) for `S₃₃(0)`; Table I's
  caption for the 1.55×10⁷ K Gamow-peak reference temperature. The same paper's eq. (25) is already cited in
  [`further-reactions.md`](further-reactions.md); this note read it independently for §III and §IV.
- **M. Wang, W. J. Huang, F. G. Kondev, G. Audi and S. Naimi**, "The AME 2020 atomic mass evaluation
  (II)", *Chinese Physics C* **45**, 030003 (2021). The `mass_1.mas20` table downloaded from the AMDC
  mirror at <https://amdc.impcas.ac.cn/masstables/Ame2020/mass_1.mas20> and parsed here: binding
  energies per nucleon for the iron-peak ranking, and mass excesses for ¹H, ²H, ³He, ⁴He, ⁸Be and ¹²C
  from which every Q value in this note is computed. Extrapolated and estimated entries excluded.
- **D. R. Tilley, J. H. Kelley, J. L. Godwin, D. J. Millener, J. E. Purcell, C. G. Sheu and
  H. R. Weller**, "Energy levels of light nuclei A = 8, 9, 10", *Nuclear Physics A* **745**, 155 (2004).
  Read at the TUNL Nuclear Data Project copy
  <https://nucldata.tunl.duke.edu/nucldata/ourpubs/08_2004.pdf>. The ⁸Be ground-state table and
  reaction 12 text for `Γ = 5.57 ± 0.25 eV` and `E_b = −92.04 ± 0.05 keV`, from the 26 eV-resolution
  measurement (1992WA09).
- **J. José and C. Iliadis**, "Nuclear astrophysics: the unfinished quest for the origin of the
  elements", *Reports on Progress in Physics* **74**, 096901 (2011), arXiv:1107.2234. Read. §5.2 for
  helium burning at T = 0.1–0.4 GK and the sequential triple-α mechanism; §6.1 for neutrino cooling
  past helium burning and the one-day silicon-burning stage; §6.2 for NSE favouring ⁵⁶Ni. **A review
  rather than a primary measurement**, and cited as one — every number this note takes from it is
  descriptive rather than load-bearing.
- **K.-P. Schröder and R. C. Smith**, "Distant future of the Sun and Earth revisited", *Monthly Notices
  of the Royal Astronomical Society* **386**, 155 (2008), arXiv:0801.4031. Read. Table 1 and §2 for the
  12.167 Gy RGB tip, the 53.7 L☉ zero-age helium model and the 130 Myr helium-burning phase; the
  abstract for "7.59 Gy from now".
- **A. Prša et al.**, "Nominal values for selected solar and planetary quantities: IAU 2015 Resolution
  B3", *Astronomical Journal* **152**, 41 (2016), arXiv:1510.07674. Read. `R☉ = 6.957×10⁸ m`,
  `L☉ = 3.828×10²⁶ W`, `S☉ = 1361 W/m²`, `(GM)☉ = 1.3271244×10²⁰ m³/s²` — the constants behind every
  solar figure here. `M☉ = 1.98841×10³⁰ kg` from that with CODATA 2018's G.
- **FAO/WHO/UNU**, *Human energy requirements: report of a Joint FAO/WHO/UNU Expert Consultation, Rome,
  17–24 October 2001*, FAO Food and Nutrition Technical Report Series 1 (2004). Read at
  <https://openknowledge.fao.org/server/api/core/bitstreams/65875dc7-f8c5-4a70-b0e1-f429793860ae/content>.
  Table 5.2, males 30–60 years: `BMR = 0.048 × kg + 3.653 MJ/day`, s.e.e. 0.700, upholding Schofield
  (1985).
- **NRL Plasma Formulary**, 2019 revision, A. S. Richardson, Naval Research Laboratory. "Radiation",
  eq. (31), the free–free optical depth, used here at solar-core conditions. Read at the same mirror
  [`bremsstrahlung.md`](bremsstrahlung.md) used, <https://tanimislam.github.io/research/NRL_Formulary_2019.pdf>.
- **J. N. Bahcall and A. M. Serenelli**, the BS2005-AGS,OP standard solar model export table, read at
  <http://www.sns.ias.edu/~jnb/SNdata/Export/BS2005/bs05_agsop.dat> — 1284 zones of radius,
  temperature, density, pressure, luminosity fraction and composition. The author's own published data;
  the companion paper astro-ph/0412440 was not read.
- **The repository's own data and code**: `realistic-fusion-refreshed/scripts/reactor-logic.lua` at
  `M.reactor`, `M.aneutronic_reactor` and the `rf-he3-he3-plasma` fuel row; and
  [`bremsstrahlung.md`](bremsstrahlung.md) for the shipped equilibria (D-D 16 MW at 2.42×10⁸ K, D-T
  4805 MW at the clamp) and the reactor-side optical depth this note reproduces.

Read for a specific claim only:

- **Borexino Collaboration**, "Experimental evidence of neutrinos produced in the CNO fusion cycle in
  the Sun", *Nature* **587**, 577 (2020). **Abstract and summaries only** — nature.com redirects to an
  authentication endpoint from this network. Cited for the existence of the direct CNO detection and
  for nothing quantitative; the 0.64% CNO share above is Vinyoles et al.'s prediction, computed here,
  not Borexino's measurement.
- **R. Mitalas and K. R. Sills**, "On the photon diffusion time scale for the Sun", *Astrophysical
  Journal* **401**, 759 (1992). **Abstract only.** The 170 000 years and the 0.090 cm mean step length.

Not obtained:

- **I.-J. Sackmann, A. I. Boothroyd and K. E. Kraemer**, "Our Sun. III. Present and future",
  *Astrophysical Journal* **418**, 457 (1993). ADS holds an image scan with no text layer; no OCR was
  available. Its RGB-tip figures are known here only through Schröder & Smith's comparison.
- **H. O. U. Fynbo et al.**, "Revised rates for the stellar triple-α process from measurement of ¹²C
  nuclear resonances", *Nature* **433**, 136 (2005), and **G. R. Caughlan and W. A. Fowler**, *Atomic
  Data and Nuclear Data Tables* **40**, 283 (1988). Neither was obtained; no triple-α rate is quoted.
- **NACRE II** (Y. Xu et al., *Nuclear Physics A* **918**, 61 (2013), arXiv:1310.7099) was located and
  is **not applicable** — it compiles two-body exoergic reactions only and excludes triple-α. Recorded
  because it is the compilation a reader would reach for first.
