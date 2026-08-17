# Cold fusion is four different things, and none of them is net positive

Researched 2026-08-17, exploratory. **Nothing here is decided.** [ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md)
fixes v1's reaction set at D-D, D-T, D-He3 and He3-He3; cold fusion is outside it, and anything acted
on from this note would need a superseding ADR. This is material for that decision, not the decision.

The short version, for someone who wants only one paragraph: **"cold fusion" names four unrelated
things.** One of them — muon-catalysed fusion — is real, reproducible, and runs the *same nuclear
reactions this mod already tabulates*, at cryogenic temperature, with the difference living entirely
in the catalysis rather than in the nuclear physics. It is also net-negative by a factor of about two
for a hard reason that no engineering removes. The other three are respectively unproven, real but
negligible, and real but negligible. The original mod's author reached the "not worth it" conclusion
by a different route in 2020, and said so in his changelog.

## What "cold fusion" means, for a reader without a physics background

Two nuclei fuse only if they touch, and both are positively charged, so they repel. The standard way
to beat that repulsion is to throw them at each other hard — which is what "hot" means: a hundred
million kelvin is just a way of saying "moving fast enough". That is the whole of what
`scripts/reactor-logic.lua` models, and why plasma temperature is its central state variable.

"Cold fusion" is the family of proposals to beat the repulsion **without** the speed. There are only
a few physical ways to do that, and they are genuinely different from one another:

1. **Shrink the atom.** Replace the electron in a hydrogen molecule with a muon — a particle
   identical to an electron but 207 times heavier. The molecule shrinks by the same factor, the two
   nuclei end up ~200× closer together, and they tunnel through the barrier at ordinary temperatures.
   This is **muon-catalysed fusion (μCF)**. It is real, it was discovered by accident in 1957, and it
   is the only member of the family that has ever produced fusion in industrially interesting numbers.
2. **Hide the charge.** Pack deuterium into a metal so densely that the metal's own conduction
   electrons screen the nuclear charge. This is **electron screening**, it is measured and real, and
   the effect is small.
3. **Claim it happens anyway.** Assert that some condition inside a loaded metal lattice produces
   fusion-scale energy with no accepted mechanism. This is the **Fleischmann–Pons** claim of 1989 and
   its descendant field, **LENR**. It is unproven and remains under investigation.
4. **Cheat by not being cold.** Build a small device that accelerates a few deuterons to fusion
   energies using something other than a reactor — a pyroelectric crystal, an electrostatic grid.
   These are **pyroelectric fusion** and **inertial-electrostatic confinement (IEC / "fusors")**. Both
   work, both make neutrons on a desk, and neither is cold in any meaningful sense; they are hot
   fusion in very small quantities. They get called cold fusion because the apparatus is at room
   temperature.

Only (1) and (4) demonstrably produce fusion. Only (1) produces enough of it to be worth arithmetic.

## The prior decision this project already has

The original mod's author considered a cold fusion tier and dropped it. From
`RealisticFusionPower_1.8.18/changelog.txt`, under **Version 1.2.0, Date 2020.9.5**, in a
`Major Features` block that is otherwise about antimatter:

> ```
> Version: 1.2.0
> Date: 2020.9.5
>   Major Features:
>     - Antimatter power. Currently beta, can be disabled in mod settings.
>     - Some of the textures are modified from Krastorio 2 and licensed under GNU GPL v3. Others are
>       modified from angel's discarded/unused thread.
>     - I know I said I'll add cold fusion (not antimatter power), but the difference in power output
>       wasn't big enough between normal and cold fusion to make it worth it. I'll might still add it
>       in the future though.
> ```

Two things about that entry are worth noticing.

**The stated reason is a game-design reason, not a physics one.** "The difference in power output
wasn't big enough between normal and cold fusion" is a complaint about tier separation: a new tier
that produces roughly what the previous tier produced is not a tier. It is not a claim that cold
fusion is impossible, and it is not a claim about input energy at all. His mod was recipe-driven, so
"power output" for him was a number he chose; he is reporting that he could not find a number that
made the tier feel like a step. **This mod cannot make that choice**, because output is computed
(ADR 0005), so the same question arrives here in a different and harder form.

**Two more traces survive elsewhere in the changelog, and they say the tier got further than "an
idea".** Under **Version 1.0.2, Date 2020.8.19**:

> ```
>   Bugfixes:
>     - Cold fusion science requirement was too big and caused an integer overflow (only on some
>       systems, apparently)
> ```

A technology cannot overflow its science cost unless it exists as a prototype. So a cold fusion
technology **shipped in 1.0.x**, three weeks before the 1.2.0 entry that says it was dropped.

And the name is still in the mod. `locale/en/base.cfg` line 162, in the `[technology-name]` section:

```
rfp-d-he3-fusion=D-He3 fusion
rfp-cold-fusion-theory=Cold fusion theory
rfp-tritium-decay=Tritium decay to helium-3
```

`rfp-cold-fusion-theory` is present in all four shipped locales — `en`, `de`, `es-ES`, `zh-CN` — of
**both** Realistic Fusion Power 1.8.18 **and** Durikkan's 2.0 port 1.9.0 and 1.9.2, and there is **no
prototype of that name anywhere in any of them**. Grepping the whole of `_reference/` for `cold`
returns changelogs and locale files and nothing else. It is a dead string that three shipped mods
have been carrying for six years, translated into three languages, for a technology that was removed.

Its position in the list is informative too: it sits immediately after `rfp-d-he3-fusion` and before
`rfp-tritium-decay`, i.e. **after the aneutronic block**. Wherever cold fusion was meant to go, it was
meant to go at or past the end of the progression — which is exactly where a tier has the least room
to be "a big enough difference in power output", and is consistent with why it was cut.

This is the closest thing to a prior decision that exists. It is evidence that the design problem is
real and that someone hit it, not evidence about the physics.

## 1. Muon-catalysed fusion — real physics, and the interesting one

### The mechanism

A muon is a lepton with the same charge as an electron and 206.768 times its mass, so a muonic
hydrogen atom's Bohr radius is smaller than an ordinary one by that same factor. Bind two hydrogen
nuclei with one muon and you get the muonic analogue of the H₂⁺ molecular ion, with the two nuclei
about 200× closer than in ordinary H₂ — close enough that their vibrational motion carries them
through the Coulomb barrier at a useful rate without any thermal energy at all. Jackson's 1957
abstract puts it exactly this way:

> "The μ⁻ meson binds two hydrogen nuclei together in the μ-mesonic analog of the ordinary H₂⁺
> molecular ion. In their vibrational motion the nuclei have a finite, although small, probability of
> penetrating the Coulomb barrier to zero separation where they may undergo a nuclear reaction."
>
> — J. D. Jackson, *Catalysis of Nuclear Reactions between Hydrogen Isotopes by μ-Mesons*,
> Phys. Rev. **106**, 330 (1957)

The muon is not consumed. After the nuclei fuse it is released and can bind another pair, hence
*catalysis*. This is not an exotic proposal: it was **observed before it was predicted**. Alvarez and
co-workers found it by accident in late 1956 while scanning film from the Berkeley 10-inch
liquid-hydrogen bubble chamber, when they noticed muons all leaving with the same anomalous kinetic
energy of 5.4 MeV. The reaction was p + d fusion, catalysed by a single muon, on the trace deuterium
naturally present in the liquid hydrogen — published as L. W. Alvarez et al., *Catalysis of Nuclear
Reactions by μ Mesons*, Phys. Rev. **105**, 1127 (1957). Jackson's abstract gives the channel and its
Q-value: **p + d + μ⁻ → ³He + μ⁻ + 5.5 MeV**.

Cryogenic is not a figure of speech here. μCF experiments run on liquid or high-pressure gaseous
D/T at tens of kelvin — the Bystritsky et al. d–μ–³He measurement below ran its target at **34 K**.

### Which reactions it catalyses — and this is the finding that matters for this repo

**Muons catalyse the reactions this mod already tabulates.** Not analogous ones; the same ones, with
the same branches and the same Q-values that `M.fuels` in `scripts/reactor-logic.lua` already carries:

| Muonic molecule | Reaction | MeV | Repo's row | Repo's dataset |
|---|---|---|---|---|
| `ddμ` | D + D → t + p | 4.03 | `rf-d-d-plasma`, branch 1 | `D-D_T` |
| `ddμ` | D + D → ³He + n | 3.27 | `rf-d-d-plasma`, branch 2 | `D-D_He3` |
| `dtμ` | D + T → α + n | 17.6 | `rf-d-t-plasma` | `D-T` |
| `dμ³He` | D + ³He → α + p | 18.35 (p carries 14.6) | *(ADR 0010's D-He3 tier, not yet a `M.fuels` row)* | `D-He3` |
| `pdμ` | p + D → ³He + γ | 5.5 | **none** | **none** |
| **none found** | ³He + ³He | — | `rf-he3-he3-plasma` (ADR 0010) | `He3-He3` |

Sources for each: the `ddμ` branches and their Q-values, and `dtμ` → α + n + μ + 17.6 MeV, are stated
in Kamimura, Kino & Yamashita and in the `ddμ` T-matrix study (arXiv:2508.12783, Phys. Rev. C, 2025);
the `dμ³He` channel is measured — 14.6 MeV protons detected from a d + ³He gas target at 34 K, with
the J=0 fusion rate in d–μ–³He derived for the first time, in Bystritsky et al., *Nuclear fusion in
muonic deuterium-helium complex*, arXiv:nucl-ex/0506025 (2005); `pdμ` is Alvarez 1957 / Jackson 1957
above.

Note the two ends of that table:

- **`ddμ`'s branches are `M.fuels["rf-d-d-plasma"]`'s branches, digit for digit.** The comment in
  `reactor-logic.lua` lists "D + D -> T (1.01 MeV) + p (3.02 MeV) — 4.03 MeV, entirely charged" and
  "D + D -> He3 (0.82 MeV) + n (2.45 MeV)" — 3.27 MeV. Those are the same two numbers the μCF
  literature quotes for the `ddμ` molecule. **A μCF tier would therefore need no new nuclear data at
  all**, and `charged_fraction`, `energy_per_reaction_j` and `products` would carry over unchanged.
  What changes is only *how often* it happens.
- **`pdμ` is the one μCF reaction the repo does not have**, and it is nearly reachable: Core already
  defines `rf-hydrogen` and `rf-deuterium` (ADR 0010), so the reactants exist as fluids. There is no
  `p-D` cross-section in `tools/endf/` and `derive-reactivities.py` has no `p-D` channel, so adding
  it would mean sourcing one more ENDF table.
- **He3-He3 muon catalysis: I found nothing.** No paper in the searches describes a `³Heμ³He`
  catalytic cycle, which is unsurprising — a muon bound to a doubly-charged ³He makes a
  pseudo-hydrogen ion, not a neutral atom, and the machinery that makes `dtμ` work does not obviously
  transfer. **I am recording this as "not found", not as "does not exist".** If a cold tier were
  scoped, this is the one row of ADR 0010's four that would need checking rather than assuming.

### The two constants that decide everything

μCF's problem is not whether it works. It is that the cycle stops, for two independent reasons, and
both are numbers rather than engineering difficulties.

**Alpha sticking (ω_s).** When `dtμ` fuses, the muon is usually released — but sometimes it is
captured into orbit around the α particle that was just produced. A muon stuck to a doubly-charged
helium nucleus is out of the game. That probability is the hard ceiling on the whole scheme, because
it is a *per-cycle* loss: a muon that survives 1/ω_s cycles on average simply cannot do more.

| quantity | value | source |
|---|---|---|
| initial sticking ω_s⁰ | 8.57 × 10⁻³ | Kamimura, Kino & Yamashita, *Comprehensive study of muon-catalyzed nuclear reaction processes in the dtμ molecule*, arXiv:2112.08399, Phys. Rev. C (2023) — noted there as ~7% below the literature values of ≃0.91–0.93% |
| reactivation fraction R | ≈ 0.35 | a stuck muon can be stripped again as the α slows through the medium; arXiv:2606.07077 (preprint) citing Rafelski et al. (1989) and Kamimura et al. (2023) |
| effective sticking ω_s^eff (theory) | 0.557% | ω_s^eff = ω_s⁰(1 − R), same preprint |
| effective sticking ω_s^eff (**measured**, liquid DT) | **(0.45 ± 0.05)%** | high-density DT measurement, independent of tritium concentration, consistent with X-ray observations — **see caveat below** |

**Muon lifetime (τ_μ).** A muon decays. The best measurement is τ_μ = 2 196 980.3 (2.2) ps, i.e.
**2.196 980 3 μs**, to 1.0 ppm — MuLan Collaboration, *Detailed report of the MuLan measurement of the
positive muon lifetime and determination of the Fermi constant*, Phys. Rev. D **87**, 052003 (2013).
The corresponding decay rate is λ_μ = 4.55 × 10⁵ s⁻¹.

That sets a race. The cycle rate at liquid-hydrogen density is λ_c ≈ 2.0 × 10⁸ s⁻¹, rising to
≈ 5.5 × 10⁸ s⁻¹ in optimised scenarios (arXiv:2605.26432, preprint). So in one muon lifetime you get
roughly λ_c/λ_μ ≈ 440 cycles before decay — but sticking bites first.

**The two combine into the number that matters.** Cycles per muon:

```
X_c  =  1 / ( ω_s^eff  +  λ_μ / λ_c )
     =  1 / ( 0.0045   +  4.55e5 / 2.0e8 )
     =  1 / 0.006775
     ≈  148
```

That is my own arithmetic from the four cited constants, and it lands on the measured value:
**150 ± 4 (stat.) ± 20 (syst.) fusions per muon**, the LAMPF result reported in S. E. Jones et al.,
*Muon-catalysed fusion revisited*, Nature **321**, 127 (1986). Sticking contributes about two thirds
of the loss and decay about one third.

### The energy input, which is the crux

**The input is muon production, and it dominates everything else by three orders of magnitude.**
Muons are made by firing a proton beam into a target, producing pions that decay to muons. Nobody
makes them cheaply. The figure used throughout the field:

> "⟨E_μ⟩ ≃ 5 GeV" per muon
>
> — arXiv:2605.26432 Eq. (7) (preprint), describing this as the *eventual cheapest* cost, ~1 μ⁻ per
> 5 GeV

Set that against the yield and the entire question resolves in four lines of arithmetic:

| quantity | value |
|---|---|
| energy in, per muon | 5 000 MeV |
| energy out, per D-T fusion | 17.59 MeV |
| fusions per muon achieved | ≈ 150 |
| **energy out per muon** | 150 × 17.59 = **2 639 MeV** |
| **Q (thermal)** | 2 639 / 5 000 = **0.53** |

**It is net-negative by roughly a factor of two, and it has been for forty years.** Breaking even
thermally needs X_c = 5000/17.59 = **284** fusions per muon.

Now the part that makes this a *physics* result rather than an engineering to-do list. Suppose the
muon never decayed at all — infinite lifetime, free. Sticking alone still caps the cycle:

```
X_c  ≤  1 / ω_s^eff  =  1 / 0.0045  =  222 cycles
Q    ≤  222 × 17.59 / 5000          =  0.78
```

**Sticking alone forbids thermal break-even at 5 GeV per muon**, with the muon lifetime removed from
the problem entirely. The published route around it is nuclear polarisation of the fuel, which is
projected to bring ω_s to ≈ 0.34% (arXiv:2605.26432, preprint) — giving a ceiling of X_c ≤ 294 and
Q ≤ 1.03. That is *marginal thermal break-even in the ideal limit*, and it is before the muon decays,
before any capture losses, and before the heat is converted to the electricity that runs the
accelerator. Fold in a realistic 40% thermal-to-electric conversion and a self-supplying plant needs
**X_c ≈ 711** against a hard ceiling near 222–294. The gap is a factor of three, and it is not on the
engineering side of the ledger.

Consequently the field's own serious proposals for net power are **hybrids**: Yu. V. Petrov, *Muon
catalysis for energy production by nuclear fusion*, Nature **285**, 466 (1980), showed that μCF d-t
fusion **combined with a fissile blanket** can give positive energy gain. The amplification comes from
fission of the blanket, driven by μCF's 14 MeV neutrons — the fusion itself is still net-negative and
is being used as a neutron source. That is a materially different machine from anything in ADR 0010,
and it would import fission into a fusion mod.

Attribution note, since the mod's `CLAUDE.md` cares about it: the idea of muons as fusion catalysts is
credited in Petrov's paper to **A. D. Sakharov and Ya. B. Zel'dovich**; the observation is Alvarez's
group's; the first full theory is Jackson's.

## 2. Fleischmann–Pons cold fusion, and LENR

This is the one the phrase "cold fusion" usually means in ordinary conversation, and it is the one
where care is owed in both directions.

**The claim.** M. Fleischmann and S. Pons, *Electrochemically induced nuclear fusion of deuterium*,
J. Electroanal. Chem. **261**, 301–308 (1989), with errata in vol. **263**, 187 (1989), reported
anomalous heat during electrolysis of heavy water at a palladium cathode, in excess of any chemical
explanation, and attributed it to fusion inside the loaded lattice.

**What went wrong with the evidence.** The nuclear signature was the weakest part. A 2.45 MeV neutron
capturing on hydrogen produces a 2.22 MeV γ, and the γ peak in the paper was at the wrong energy; the
errata corrected it, and an MIT group (Petrasso and co-workers) published a critique of the γ-ray
spectrum in Nature **339**, 183 (1989), titled *Problems with the γ-ray spectrum in the Fleischmann et
al. experiments*. **The paper has never been formally retracted** — what happened is that the nuclear
evidence did not survive scrutiny and replication attempts largely failed. I am stating that carefully
because "retracted" is often asserted and is not, as far as I can establish, true.

**Where official review landed, twice.** The 1989 DOE ERAB panel found no convincing evidence for cold
fusion and declined to recommend a dedicated programme, while supporting peer-reviewed investigation.
The 2004 DOE review revisited it explicitly; from the report itself (*Report of the Review of Low
Energy Nuclear Reactions*, DOE Office of Science, 1 December 2004):

> On excess heat: **"The reviewers were split approximately evenly on this topic."**
>
> On nuclear origin: **"The preponderance of the reviewers' evaluations indicated that Charge Element
> 2 ... is not conclusively demonstrated."** Two-thirds of reviewers commenting on Charge Element 1
> "did not feel the evidence was conclusive"; one found it convincing.
>
> On funding: **"No reviewer recommended a focused federally funded program for low energy nuclear
> reactions"** — but reviewers supported "individual, well-designed proposals" through ordinary peer
> review.

**Where it stands now, factually.** Three data points, all after 2004, all primary:

- **A well-resourced modern attempt found nothing.** C. P. Berlinguette, Y.-M. Chiang, et al.,
  *Revisiting the cold case of cold fusion*, Nature **570**, 45–51 (2019) — a multi-institution
  programme (UBC, MIT, Lawrence Berkeley National Laboratory) funded by Google, which re-examined the
  claims to modern standards and "yielded no evidence of such an effect", while arguing that the
  underlying materials science of highly hydrided metals remains an under-explored and interesting
  parameter space.
- **The US government funded a programme in 2023.** ARPA-E, *U.S. Department of Energy Announces $10
  Million in Funding to Projects Studying Low-Energy Nuclear Reactions*, announced 17 February 2023 —
  $10 M across eight projects (Amphionic; Energetics Technology Center; Lawrence Berkeley National
  Laboratory; MIT; Stanford; Texas Tech; University of Michigan), framed explicitly as answering
  "does this area show promise, and if so, how? Or can we conclusively show that it does not?" under
  an ARPA-E Exploratory Topic. That framing is the whole point: it is funding to *settle* the
  question, not funding premised on the effect being real.
- **A real, small, measured effect exists — and it is not the claimed one.** K.-Y. Chen, J. Maiwald,
  P. A. Schauer et al., *Electrochemical loading enhances deuterium fusion rates in a metal target*,
  Nature **644**, 640–645 (2025), acknowledging ARPA-E support for work at LBNL. They bombarded a
  palladium target with 30 keV deuterium ions and measured that *in situ* electrochemical loading of
  deuterium into the palladium gave a **15(2)% increase in D-D fusion rates**. The authors are
  explicit about what it is not: the reactor "produces a neutron yield equivalent to only 10⁻⁹ W with
  15 W of input power". That is **Q ≈ 7 × 10⁻¹¹.**

**Statement of consensus, plainly:** cold fusion as a fusion-scale energy source in a loaded metal
lattice is **not established**, has failed to replicate under two federal reviews and one modern
well-funded attempt, and is not accepted by the scientific community. Anomalous effects in
hydrided metals remain an open, funded research question, and the effects that have been convincingly
measured are percent-level modifications to a beam-driven reaction rate, not energy sources.

### Electron screening: the measured, respectable, tiny version

The one part of this area that is solid, quantified and directly relevant to this repo's machinery.
Deuterons inside a metal lattice are screened by the conduction electrons, which lowers the effective
Coulomb barrier by a screening potential U_e and enhances the cross-section at low energy. It is
measured: **U_e = 309 ± 12 eV** for deuterated tantalum (Raiola et al., *Enhanced electron screening
in d(d,p)t for deuterated metals*, Eur. Phys. J. A, 2004; the same programme surveyed 58 samples and
found large effects in metals and small gas-like effects in insulators, semiconductors and
lanthanides). The enhancement decreases with rising sample temperature, consistent with Debye
screening by quasi-free metallic electrons (Raiola et al., J. Phys. G **31**, 1141, 2005).

**Why this matters here and nowhere else:** screening shifts the *effective* collision energy by
~300 eV. That is more than an order of magnitude enhancement at the few-keV beam energies where it is
measured, and it is a rounding error at the 8.6 keV–800 keV thermal energies this mod's reactors run
at. It is the only cold-fusion-adjacent effect that could be expressed *through the repo's existing
data pipeline* — see below — and it would be invisible in play.

## 3. Pyroelectric fusion and IEC fusors — real, and not cold

**Pyroelectric fusion.** B. Naranjo, J. K. Gimzewski & S. Putterman, *Observation of nuclear fusion
driven by a pyroelectric crystal*, Nature **434**, 1115–1117 (2005). Gently heating a pyroelectric
crystal in a deuterated atmosphere generates an electrostatic field that produces and accelerates a
deuteron beam — **>100 keV and >4 nA** — which on striking a deuterated target gives a neutron flux
**over 400× background**. Real D-D fusion, on a desktop, at room temperature. It is D-D fusion driven
by a >100 keV beam: the crystal is cold, the deuterons are not.

**IEC / Farnsworth–Hirsch fusors.** R. Hirsch, *Inertial-Electrostatic Confinement of Ionized Fusion
Gases*, J. Appl. Phys. **38**, 4522–4535 (1967). Concentric electrostatic grids accelerate ions
inward to a dense core where they fuse. Fusors are the standard amateur-buildable neutron source. As
with the pyroelectric device, the fusion is entirely conventional: fast deuterons, standard D-D
cross-section, nothing cold about the nuclei.

**Neither can be net positive, and this is proved rather than observed.** T. H. Rider, *Fundamental
limitations on plasma fusion systems not in thermodynamic equilibrium*, Phys. Plasmas **4**, 1039–1046
(1997) (from his 1995 MIT thesis of the same title) used analytical Fokker–Planck calculations to show
that for virtually all fusion schemes where the major particle species are significantly non-Maxwellian
or at radically different mean energies, the recirculating power required to *maintain* the
non-equilibrium distribution against collisions substantially exceeds the fusion power — so, "barring
the discovery of methods for recycling the power at exceedingly high efficiencies, grossly
nonequilibrium reactors will not be able to produce net power". Both fusors and pyroelectric devices
are exactly such grossly non-equilibrium systems. Their loss is not a matter of scale.

Two observations for this repo specifically:

- Their nuclear physics is **already in the repo**. A fusor burning D-D uses `D-D`; burning D-T uses
  `D-T`. There is nothing to add to `cross-section-data/`.
- Their distinguishing feature is a **non-thermal ion distribution**, and the mod's entire model —
  `derive-reactivities.py` integrates σ(E) over a **Maxwellian** — assumes a thermal one. A beam-driven
  device is precisely the case ⟨σv⟩ does not describe. Modelling it properly means beam-target rates,
  not a reactivity table.

## 4. Anything else called cold fusion

- **Sonofusion / bubble fusion.** Claimed acoustic-cavitation D-D fusion in deuterated acetone
  (Taleyarkhan et al., Science **295**, 1868, 2002). Independent replication failed and Purdue
  University found Taleyarkhan guilty of research misconduct in 2008. **I did not source the
  misconduct finding to a primary document** — flagged below.
- **Piezonuclear / fracto-fusion.** Fracture-induced charge separation in deuterated solids producing
  a few neutrons. Same category as pyroelectric: a small accelerator dressed as a solid-state effect.
- **Muon catalysis in other hosts** — e.g. muonic lithium hydride (arXiv:2207.09753). Same μCF physics
  in a different medium; the sticking ceiling is unaffected.
- **"Cold fusion" as pure genre furniture.** In games it usually means "the fusion tier you unlock
  that doesn't need the big hot machine". That is the sense in which the predecessor's
  `rfp-cold-fusion-theory` almost certainly meant it, and it corresponds to no physics at all. Worth
  naming explicitly because it is the meaning a player will bring to the tooltip.

## Is any of it net positive? No.

| candidate | best measured/derived Q | fixed by engineering? |
|---|---|---|
| μCF, D-T | **0.53** (150 fusions × 17.59 MeV / 5 GeV per muon) | **No.** Sticking alone caps Q ≤ 0.78; polarised fuel projects Q ≤ 1.03 thermal, still below electrical self-supply at ~711 cycles needed |
| μCF + fissile blanket | > 1 (Petrov 1980) | Yes — but the gain is **fission** |
| LENR / Fleischmann–Pons | not established | n/a — the effect itself is unproven |
| Electrochemically enhanced beam-target D-D | **≈ 7 × 10⁻¹¹** (10⁻⁹ W out, 15 W in) | No — it is a beam experiment measuring a 15% rate change |
| Pyroelectric | ≪ 1, not quoted as Q | **No** — Rider 1997 |
| IEC / fusor | ≪ 1, not quoted as Q | **No** — Rider 1997 |

**That is the headline finding, and it is the design problem in one line: cold fusion is a catalysis
technique, not an energy source.** μCF genuinely lets D and T fuse at 34 K. It genuinely runs the
reactions this mod already models. It genuinely fails to pay for itself, by a factor whose dominant
term is a nuclear constant.

**This is a decision for Truls, not for this note.** A mod whose selling point is that the physics is
computed rather than chosen has to decide whether a net-negative tier is a feature or a contradiction.
Options are at the bottom; I am not choosing between them.

## What a data-driven implementation would need that the repo does not have

This is the section that decides whether a μCF tier is even *judgeable* against
[ADR 0005](../adr/0005-real-time-fusion-simulation.md).

### The reaction data is already there. The rate data is not, and it is a different kind of thing.

`M.fuels` rows would need no new nuclear numbers — `energy_per_reaction_j`, `charged_fraction`,
`fuel_per_reaction`, `fractions` and `products` all carry over from `rf-d-d-plasma` and
`rf-d-t-plasma` unchanged, because μCF fuses the same nuclei into the same products.

But `M.step()` computes reactions as

```lua
reactions = reactivity.rate(fuel.reaction, t_k, density * f1, density * f2) * spec.volume_m3 * dt
```

— a rate proportional to **n₁ n₂ ⟨σv⟩(T)**. **μCF's rate is not that expression in any limit.** It is

```
reactions/s  =  (muons delivered per second)  ×  X_c
```

with X_c governed by ω_s, λ_μ and λ_c — sticking, decay and cycling. It is proportional to the
**muon supply**, essentially independent of plasma temperature over the relevant range, and only
weakly dependent on density (through λ_c). Temperature, the state variable this whole simulation is
built around, drops out. A μCF tier is not a new row in `M.fuels`; it is a second rate law.

### The tabulated data question, answered directly

`tools/derive-reactivities.py` consumes ENDF/B-VIII.0 cross-section tables — σ(E) in barns against
energy in eV — and Maxwellian-averages them. **There is no ENDF-equivalent archive for the quantities
μCF needs.** Molecular formation rates λ_dtμ(T), sticking probabilities and reactivation fractions are
published as numbers and curves in individual papers (Kamimura et al. 2023; the reactivation and
cycle-rate values above), not as a machine-readable dataset of the kind that pipeline ingests. **I
searched for one and did not find it**; I am recording that as "not found" rather than "does not
exist", since it is a negative result from a literature search.

**So the honest answer is: a μCF tier would hard-code constants.** ω_s = 0.0045, λ_μ = 4.55×10⁵ s⁻¹,
λ_c ≈ 2×10⁸ s⁻¹, E_μ ≈ 5 GeV, X_c ≈ 150. Five magic numbers with citations, driving a rate that no
interpolation touches. **That is a direct tension with ADR 0005**, whose whole point is that reaction
rate is interpolated from tabulated cross-section data rather than implied through chosen constants.
Five cited constants are more defensible than a tuned recipe ratio — but they are constants, and a
tier built on them is not the same kind of object as the D-D and D-T tiers. **This should be stated as
a tension in any ADR that proposes one, not glossed.**

### One exception: electron screening does fit the existing pipeline exactly

Screening modifies the *cross-section*, which is the one thing `derive-reactivities.py` already
handles. The standard screening treatment shifts the effective energy by U_e, so a screened channel
could be generated from the **same ENDF inputs already committed under `tools/endf/`** — a new
`CHANNELS`-style entry, or a `--screening` flag, producing a `D-D-screened` dataset alongside `D-D`.
No new upstream data, no new rate law, no hard-coded constants beyond the single measured U_e = 309 ±
12 eV. It would be the only genuinely data-driven cold-fusion-adjacent thing available.

It would also be **invisible**. U_e ≈ 300 eV against a reactor at kT ≈ 8.6 keV (10⁸ K) is a sub-percent
correction; the tier would compute honestly and produce no observable difference — which is, note,
precisely the failure mode the original author described in 2020, arrived at from the other direction.

### One observation about the existing table at cold temperatures

Not a bug in current use, but relevant if anything is built near the bottom of the range.
`reactivities.lua` is tabulated from 2.3209 × 10⁶ K to 6.96 × 10⁹ K, with an explicit `{0,0}` point
at the bottom, and `reactivity.interpolate` linearly interpolates between adjacent points. A reactor
sitting at `min_temperature_c = 15` (288.15 K) therefore evaluates the segment between `{0,0}` and
`{2.3209e6, 9.00663e-34}` and gets ⟨σv⟩ = 1.12 × 10⁻³⁷ m³/s for D-D. **That number is a linear
artefact, not physics** — the true reactivity there is smaller by hundreds of orders of magnitude,
because the real curve is exp(−1/√T)-like and a straight line from the origin cannot represent it.

In practice it is harmless: at the shipped density and volume it works out to 5.6 × 10⁵ reactions/s
and **0.33 microwatts** of fusion power, against 50 MW of heating. It does not need fixing and I have
not touched it. It matters only in that **anyone building a cold tier on this table would be reading
a fictitious number** — the existing data cannot be stretched downward to cold-fusion temperatures,
and a μCF tier must not be implemented by pointing the current rate law at a low temperature.

## Options, with trade-offs

**These are options, not a recommendation. ADR 0010 fixed v1's reaction set at D-D, D-T, D-He3 and
He3-He3; every option below except the first would need a superseding ADR.**

### A. Do nothing. Cold fusion stays out.

- **For:** matches the prior decision that already exists in this lineage; costs nothing; ADR 0010
  stands unamended; nothing in the note argues the physics is interesting *as a power source*.
- **Against:** loses the one genuinely surprising true fact in the area — that D and T fuse at 34 K on
  reactions the mod already tabulates — and leaves `rfp-cold-fusion-theory`'s six-year-old ghost as
  the only trace of the idea.
- **Note:** this is the only option that requires no ADR.

### B. A μCF tier that is honestly net-negative — a catalyst tier, not a power tier.

Muon production consumes a large, explicit electrical input; the reactor produces less than it
consumes; the player builds it for something *other* than power — most naturally as the mod's tritium
and helium-3 breeder, since μCF produces exactly those from `ddμ` at cryogenic temperature, or as a
neutron source.

- **For:** the only design in which the physics can be stated truthfully and still be a reason to
  build the thing. It converts the fatal flaw into the mechanic. It reuses ADR 0010's existing
  `rf-isotope-collector` concept and needs no new nuclear data.
- **Against:** a machine that eats power is a hard sell as a *fusion* tier in a game about scaling
  power up, and it is arguably a Core machine rather than a Power one — which would put it across the
  module seam ADR 0010 defines. Needs a second rate law in `reactor-logic.lua` (see tension below).
- **Cost:** medium. One entity, one rate path, five cited constants, one technology.

### C. A μCF tier that is net-positive because a fissile blanket makes it so.

The only published route to positive gain (Petrov 1980). μCF supplies 14 MeV neutrons; a fissile
blanket multiplies the energy.

- **For:** genuinely net positive, genuinely cited, genuinely how the field proposes to do it. It
  gives a real tier with real numbers.
- **Against:** it imports **fission** into a fusion mod. The energy the player sees would come mostly
  from the blanket, which is a different mod's subject matter, and it needs uranium — a map resource,
  which ADR 0010 deliberately avoided for lithium on worldgen grounds (vanilla uranium exists, so this
  is less severe, but it is a dependency on vanilla ore the mod currently does not have).
- **Cost:** high. New fuel chain, new prototypes, arguably out of scope per ADR 0002.

### D. Screening as a data-driven modifier rather than a tier.

Regenerate a screened `D-D` dataset from the committed ENDF inputs with U_e = 309 eV, and expose it as
a research bonus or a machine modifier rather than a reactor.

- **For:** the **only** option that satisfies ADR 0005 completely — real tabulated data, real
  published constant, produced by the existing pipeline from inputs already in the repo. Smallest diff
  by a wide margin: one channel in `derive-reactivities.py`.
- **Against:** the effect is **sub-percent at reactor temperatures**. It is honest and it is
  imperceptible. Shipping a technology whose measured effect is invisible is arguably worse than
  shipping nothing.
- **Cost:** low.

### E. A cold fusion tier in the game-genre sense, disconnected from the physics.

What `rfp-cold-fusion-theory` was presumably going to be.

- **For:** the only option with free rein on balance, so it is the only one that can be made to *feel*
  like a tier.
- **Against:** it is "physics implied through numbers someone chose", which is the thing this project
  exists to not be (ADR 0005, and the `rf-isotope-collector` reasoning in ADR 0010's 2026-08-17
  correction). It would be the first prototype in the mod whose behaviour has no derivation.
- **Cost:** low to build, high to the mod's stated identity.

### The question underneath all of them

**Is a net-negative tier a feature or a contradiction for a mod whose selling point is realism?**
Option B says feature — an honest dead end that teaches the player something true. Option E says the
contradiction is unacceptable and the honest answer is to fabricate openly. Option A says the
contradiction is unacceptable and the honest answer is silence. **That is a scope-and-identity
question, and it is Truls's.**

## Sources

Primary, read directly:

- L. W. Alvarez et al., *Catalysis of Nuclear Reactions by μ Mesons*, Phys. Rev. **105**, 1127 (1957).
  doi:10.1103/PhysRev.105.1127
- J. D. Jackson, *Catalysis of Nuclear Reactions between Hydrogen Isotopes by μ-Mesons*, Phys. Rev.
  **106**, 330 (1957). doi:10.1103/PhysRev.106.330
- Yu. V. Petrov, *Muon catalysis for energy production by nuclear fusion*, Nature **285**, 466 (1980).
- S. E. Jones et al., *Muon-catalysed fusion revisited*, Nature **321**, 127 (1986).
- M. Kamimura, Y. Kino & T. Yamashita, *Comprehensive study of muon-catalyzed nuclear reaction
  processes in the dtμ molecule*, arXiv:2112.08399; Phys. Rev. C (2023).
- V. M. Bystritsky et al., *Nuclear fusion in muonic deuterium-helium complex*, arXiv:nucl-ex/0506025
  (2005).
- *Reaction processes of muon-catalyzed fusion in the muonic molecule ddμ studied with the tractable
  T-matrix model*, arXiv:2508.12783; Phys. Rev. C (2025).
- MuLan Collaboration, *Detailed report of the MuLan measurement of the positive muon lifetime and
  determination of the Fermi constant*, Phys. Rev. D **87**, 052003 (2013).
- M. Fleischmann & S. Pons, *Electrochemically induced nuclear fusion of deuterium*,
  J. Electroanal. Chem. **261**, 301–308 (1989); errata **263**, 187 (1989).
- R. D. Petrasso et al., *Problems with the γ-ray spectrum in the Fleischmann et al. experiments*,
  Nature **339**, 183 (1989).
- DOE Office of Science, *Report of the Review of Low Energy Nuclear Reactions*, 1 December 2004.
  <https://en.wikisource.org/wiki/Report_of_the_Review_of_Low_Energy_Nuclear_Reactions>
- C. P. Berlinguette, Y.-M. Chiang et al., *Revisiting the cold case of cold fusion*, Nature **570**,
  45–51 (2019).
- ARPA-E, *U.S. Department of Energy Announces $10 Million in Funding to Projects Studying Low-Energy
  Nuclear Reactions*, 17 February 2023.
  <https://arpa-e.energy.gov/news-and-events/news-and-insights/us-department-energy-announces-10-million-funding-projects-studying-low-energy-nuclear-reactions>
- K.-Y. Chen, J. Maiwald, P. A. Schauer et al., *Electrochemical loading enhances deuterium fusion
  rates in a metal target*, Nature **644**, 640–645 (2025). doi:10.1038/s41586-025-09042-7
- B. Naranjo, J. K. Gimzewski & S. Putterman, *Observation of nuclear fusion driven by a pyroelectric
  crystal*, Nature **434**, 1115–1117 (2005). doi:10.1038/nature03575
- R. Hirsch, *Inertial-Electrostatic Confinement of Ionized Fusion Gases*, J. Appl. Phys. **38**,
  4522–4535 (1967).
- T. H. Rider, *Fundamental limitations on plasma fusion systems not in thermodynamic equilibrium*,
  Phys. Plasmas **4**, 1039–1046 (1997); MIT PhD thesis, 1995.
- F. Raiola et al., *Enhanced electron screening in d(d,p)t for deuterated metals*, Eur. Phys. J. A
  (2004); and *Electron screening in d(d,p)t for deuterated metals: temperature effects*,
  J. Phys. G **31**, 1141 (2005).

In this repository:

- `_reference/RealisticFusionPower_1.8.18/.../changelog.txt` — versions 1.2.0 and 1.0.2.
- `_reference/RealisticFusionPower_1.8.18/.../locale/{en,de,es-ES,zh-CN}/base.cfg` line 162, and
  `_reference/RealisticFusionPowerPort_1.9.{0,2}/.../locale/*/base.cfg` line 182 —
  `rfp-cold-fusion-theory`, orphaned.
- `RealisticFusion/scripts/reactor-logic.lua`, `RealisticFusion/scripts/reactivity.lua`,
  `RealisticFusion/cross-section-data/reactivities.lua`, `tools/derive-reactivities.py`.

### What could not be sourced primarily

Stated plainly rather than laundered:

- **ω_s^eff = (0.45 ± 0.05)% measured in liquid DT.** This is the number the break-even arithmetic
  turns on. It is attributed in the literature to the SIN/PSI programme (Petitjean and co-workers).
  The primary PDF (`oecd-nea.org/trw/docs/villigen/vil-3-04.pdf`) would not parse, so **I have this
  via review and search summaries, not from the measuring paper.** The theory value 0.557% from
  arXiv:2606.07077 is consistent with it and is independently sourced, and the arithmetic is not
  sensitive at the level that changes the conclusion — Q ≤ 0.78 becomes Q ≤ 0.63 at 0.557%, i.e.
  worse.
- **X_c = 150 ± 4 (stat.) ± 20 (syst.)**, attributed to Jones et al., Nature **321**, 127 (1986). The
  paper is paywalled and I could not open it; the figure and its error bars come from search
  summaries of it. My own arithmetic from independently sourced constants gives 148, which is
  corroboration, not a second source.
- **E_μ ≈ 5 GeV per muon, X_c ≈ 284 for Q = 1, ω_s → 0.34% under polarisation.** These come from
  arXiv:2605.26432, **a preprint, not peer-reviewed**. The 5 GeV figure is long-standing in the field
  and is consistent with Petrov (1980); the polarisation projection is that preprint's own.
- **Jackson's 1957 conclusion on power production.** A remark — "The speculations on power production
  are, of course, very wild and probably wrong" — is widely quoted, but I could not open either
  Jackson 1957 (APS returned 403) or his retrospective *A Personal Adventure in Muon-Catalyzed
  Fusion*, Phys. Perspect. (2010), and **I could not establish which of the two it comes from.** The
  1957 abstract, which I did read, is quoted above and is reliable; the "wild and probably wrong"
  line is not, and is recorded here rather than in the body for that reason.
- **The 1989 DOE ERAB report.** I did not open it. Its conclusion — no convincing evidence, no
  dedicated programme, support for peer-reviewed work — is reported consistently but secondarily. The
  2004 review quotations *are* from the report text.
- **Taleyarkhan misconduct finding (Purdue, 2008).** Reported secondarily; I did not obtain the
  university's finding.
- **ARPA-E's exact Exploratory Topic name and number.** The press release, date, amount and recipient
  list are sourced; the formal topic designation is not.
- **He3-He3 muon catalysis.** A negative result from searching, not an established impossibility.
- **A machine-readable dataset of μCF molecular formation and sticking rates.** Searched for, not
  found. Recorded as absent rather than nonexistent.
