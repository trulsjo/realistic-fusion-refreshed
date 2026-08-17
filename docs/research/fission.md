# Fission: vanilla is already about right, and the one thing it gets wrong is the interesting one

Researched 2026-08-17, exploratory. **Nothing here is decided.** A `RealisticFission` module is not in
[ADR 0002](../adr/0002-v1-scope-and-module-split.md)'s scope, not in
[ADR 0010](../adr/0010-v1-module-layout-and-prototype-set.md)'s prototype set, and anything acted on
from this note would need a superseding ADR. This is material for that decision, not the decision.

Checked against: **Factorio 2.0.77's own prototype data** (`data/base/prototypes/{recipe,item,entity/entities,fluid}.lua`
in the installed game, `base` version 2.0.77 — not the wiki); **ENDF/B-VIII.1** thermal constants via
Pritychenko's tabulation; **IAEA-TECDOC-1450** (thorium), **IAEA-TECDOC-1531** (fast reactor database),
**IAEA-TECDOC-1587** and **OECD-NEA NSC/WPFC/DOC(2012)15** (reprocessing); **DOE-HDBK-1019/1-93**
(moderator constants); **Madland 2006** (fission energy release); **UKAEA CCFE-PR(17)67** (tritium
supply); and the **source** of Krastorio 2 2.1.3 and Bob's Metals, Chemicals and Intermediates 2.1.1 as
they sit in `C:\src\factorio\_reference\` and the local mods directory. Full list at the bottom, with a
section naming what I could only get secondarily.

## The verdict, in one paragraph

**Vanilla's fission abstraction is more physically defensible than this project's premise would
predict, and the honest delta a "realistic" fission mod adds is not more chemistry — it is
criticality.** Vanilla gets the two numbers that can be checked essentially right: its 0.7 % U-235
split is natural uranium's 0.7204 % to within 3 %, and its 8 GJ fuel cell is worth 0.101 g of fissioned
U-235 at 193 MeV per fission — so a vanilla `uranium-235` item is one gram, to 1 %. What vanilla has no
representation of at all is the thing that makes a fission reactor a reactor: **k_eff**. A vanilla
nuclear reactor is a burner entity; it cannot be poisoned, cannot be moderated well or badly, has no
delayed-neutron margin, and cannot be shut down into a xenon pit. Every one of those is a real,
data-driven mechanic, and none of them is "another recipe". Meanwhile the two chains that fiction
loves — thorium breeding and fast breeders — turn out to be the ones the primary data is least kind
to: the IAEA's own fast reactor database records BN-600 at a breeding gain of **−0.15** and Phénix at
**+0.16**. Finally, and this is the finding that bears hardest on *this* pack: **the real world's
tritium for fusion comes from fission**, specifically from neutron capture in CANDU heavy-water
moderator, and ITER's supply is Ontario's. A fission module in this pack has an obvious, cited,
physically correct reason to exist that has nothing to do with power at all.

## 1. What vanilla actually ships, from the game's own data

All numbers below are read out of `D:\SteamLibrary\steamapps\common\Factorio\data\base\prototypes\`
at `base` 2.0.77. Space Age 2.0.77 adds **no** fission content: its only uranium references are
`uranium-235` as an ingredient in `biolab` (3) and `captive-biter-spawner` (15), plus two technology
prerequisites. It is a *consumer* of vanilla's chain. The reactor, centrifuge, Kovarex, fuel-cell and
reprocessing prototypes are untouched, so [ADR 0003](../adr/0003-space-age-tolerated-not-targeted.md)'s
"tolerated, not targeted" position costs nothing here — unlike fusion, where Space Age lands on the
mod's exact subject.

### The chain

| Step | Prototype fact | Where |
|---|---|---|
| Ore | `uranium-ore` needs `required_fluid = "sulfuric-acid"`, `fluid_amount = 10`, `mining_time = 2`; `has_starting_area_placement = false` | `entity/resources.lua:148` |
| Split | `uranium-processing`: 10 ore → U-235 at `probability = 0.007`, U-238 at `probability = 0.993`, `energy_required = 12`, category `centrifuging` | `recipe.lua:2509` |
| Enrich | `kovarex-enrichment-process`: 40 U-235 + 5 U-238 → 41 U-235 + 2 U-238, `energy_required = 60`; the 40 and the 2 are `ignored_by_stats` | `recipe.lua:2536` |
| Fuel | `uranium-fuel-cell`: 10 iron + 1 U-235 + 19 U-238 → 10 cells | `recipe.lua:2586` |
| Burn | `uranium-fuel-cell`: `fuel_value = "8GJ"`, `fuel_category = "nuclear"`, `burnt_result = "depleted-uranium-fuel-cell"` | `item.lua:2313` |
| Reprocess | `nuclear-fuel-reprocessing`: 5 depleted cells → 3 U-238, `energy_required = 60` | `recipe.lua:2572` |

### The power path

| Entity | Prototype fact |
|---|---|
| `nuclear-reactor` | `type = "reactor"`, `consumption = "40MW"`, `neighbour_bonus = 1`, `heat_buffer` `max_temperature = 1000`, `specific_heat = "10MJ"`, `max_transfer = "10GW"` |
| `heat-pipe` | heat energy source, `specific_heat = "1MJ"`, `max_transfer = "1GW"`, `max_temperature = 1000` |
| `heat-exchanger` | `type = "boiler"`, `energy_consumption = "10MW"`, `target_temperature = 500`, `min_working_temperature = 500`, input filtered to `water`, output to `steam` |
| `steam-turbine` | `type = "generator"`, `fluid_usage_per_tick = 1`, `maximum_temperature = 500`, `effectivity = 1` |
| `steam` (fluid) | `heat_capacity = "0.2kJ"`, `default_temperature = 15`, `max_temperature = 5000` |

Arithmetic that follows from those and nothing else:

```
steam at 500 °C          = 0.2 kJ × (500 − 15)        = 97 kJ per unit
steam turbine            = 1 unit/tick × 60 × 97 kJ   = 5.82 MW
heat exchanger           = 10 MW ÷ 97 kJ              = 103.1 steam units/s
turbines per exchanger   = 103.1 ÷ 60                 = 1.718
lone reactor             = 40 MW ÷ 10 MW              = 4 exchangers, 6.87 turbines
one fuel cell            = 8 GJ ÷ 40 MW               = 200 s
```

`neighbour_bonus = 1` means each adjacent reactor adds 100 %, so a reactor with four neighbours runs at
**200 MW** off the same 8 GJ cell in the same 200 s. That is the whole of vanilla's fission gameplay:
build a bigger rectangle.

### Is vanilla's abstraction physically scaled? Mostly, yes — and this is the uncomfortable part

Two checks are available because vanilla commits to real numbers.

**The isotopic split is right.** Natural uranium is 0.7204 at.% U-235. Vanilla's `probability = 0.007`
is 97.2 % of that. Whether Wube intended it or not, `uranium-processing` reproduces natural abundance.

**The fuel cell's energy is right if a uranium item is one gram.** Recoverable energy per U-235 fission
is conventionally ~200 MeV; Madland's evaluation gives the *prompt* release as ⟨E_r⟩ = 185.6 MeV for
n + ²³⁵U at thermal energy, with prompt *deposition* ⟨E_d⟩ = 180.57 MeV, and delayed β/γ from fission
products adds roughly another 12–14 MeV of recoverable energy on top (antineutrinos, ~9 MeV, leave). At
193 MeV recoverable:

```
8 GJ ÷ (193 MeV × 1.602176634e-19 J/eV)  =  2.587 × 10²⁰ fissions
2.587 × 10²⁰ × 235.0439 / 6.02214076e23  =  0.1010 g of U-235
```

A vanilla fuel cell contains exactly **0.1** `uranium-235` items. **One vanilla uranium item = 1.010 g,
to 1 %.** At the conventional 200 MeV it is 0.974 g; at Madland's bare prompt release, 1.05 g. The
scaling survives the choice.

For orientation: a 3 GW-thermal PWR fissions 0.0366 g of U-235 per second, 3.16 kg/day, and the
textbook figure of **1.05 g fissioned per megawatt-day** falls straight out of the same arithmetic.

**So what does vanilla get wrong?** Not the energy, and not the abundance. It gets wrong:

1. **Kovarex is fiction.** Real enrichment is gas centrifugation of UF₆ measured in separative work
   units; it does not consume U-238 to make U-235 and there is no catalytic 40 → 41 loop. Vanilla's
   `uranium-processing` is not enrichment either — it is a 100 %-recovery isotopic *sort*.
2. **The reactor is a burner.** `type = "reactor"` with `fuel_categories = {"nuclear"}` has no
   composition, no moderator, no absorber, no neutron balance, and no state beyond a heat buffer. It
   burns a cell in a fixed time whatever is around it.
3. **Reprocessing is a token.** 5 depleted cells → 3 U-238 has no plutonium in it at all, which is
   backwards: the entire economic argument for reprocessing is the plutonium.
4. **There is no criticality**, and therefore no control. Everything a reactor operator actually does
   is absent.

Point 4 is the delta. Points 1–3 are chemistry, and chemistry is what an overhaul mod adds when it has
nothing else to add.

### Kovarex is worth 8.9× — computed

Without Kovarex, U-235 is the binding constraint: a cell needs 0.1 U-235, one centrifuge craft yields
0.007, so 14.3 crafts and **142.9 ore per cell — 56 MJ per ore**. With Kovarex (3 U-238 per extra
U-235) and reprocessing (0.6 U-238 back per depleted cell), net centrifuged items per cell is
1.9 + 0.3 − 0.6 = 1.6, so **16 ore per cell — 500 MJ per ore**. Vanilla's one interesting fission
decision is a factor of 8.93, and it is entirely fictional physics.

## 2. What the overhaul mods do, from source

### Krastorio 2 (2.1.3, LGPLv3)

Read from `C:\src\factorio\_reference\Krastorio2`, whose root `LICENSE` is the **GNU LGPLv3** — the
same licence as this repository, and `Krastorio2Assets` likewise. Under `CLAUDE.md`'s rules that makes
K2 material liftable into its own directory with the licence text and modifications stated. It is a
single root licence; there is no per-directory marking to check.

K2 **adds no fission chemistry**. It rebalances vanilla's (`prototypes/updates/base/{entities,recipes}.lua`):

| Change | From | To |
|---|---|---|
| `nuclear-reactor.consumption` | 40 MW | **250 MW** |
| `nuclear-reactor.neighbour_bonus` | 1 | **0.25** |
| `heat_buffer.specific_heat` / `max_transfer` | 10 MJ / 10 GW | 50 MJ / 50 GW |
| `uranium-fuel-cell` ingredients | 1 U-235 + 19 U-238 | 2 U-235 + 10 U-238 |
| `nuclear-fuel-reprocessing` | 5 depleted → 3 U-238 | 1 depleted → 6 U-238 + 4 stone + 15 % `kr-tritium` |
| `kovarex-enrichment-process` | 40 U-235 + 5 U-238 → 41 U-235 + 2 U-238 | 30 U-235 + 3 U-238 → 31 U-235 + **2 stone** |

Two things are worth noticing. K2 cuts the neighbour bonus by 4× and raises base output by 6.25× —
i.e. it deliberately kills "build a bigger rectangle" as the mechanic, which is an implicit judgement
that vanilla's only fission decision is not a good one. And **K2 already ties fission to fusion fuel**:
reprocessing yields tritium at 15 % probability, and `prototypes/recipes/centrifuging.lua` makes
`kr-tritium` from 30 `kr-lithium` + 5 rare metals + 1 U-235 in a centrifuge. That is lithium-6 breeding
dressed as a centrifuge recipe, and it is the same idea this note reaches on physical grounds in §5.

K2's heavy water is one recipe, `kr-heavy-water`: 500 water → 20 heavy water in 120 s in an
electrolyser (`prototypes/recipes/electrolysis.lua:4`). No exchange process, no catalyst, no depleted
stream. This repository's Girdler sulfide chain (`RealisticFusionCore/prototypes/recipes/deuterium.lua`)
is already the more physical of the two.

K2 also ships `kr-fusion-reactor` and `kr-advanced-steam-turbine` (`effectivity = 2.1`,
`fluid_usage_per_tick = 5/3`, `maximum_temperature = 975`, `max_power_output = "100MW"`), which is a
live coexistence concern under [ADR 0007](../adr/0007-coexistence-without-integration.md) and is
already on the map.

### Bob's Metals, Chemicals and Intermediates (2.1.1) — **not liftable**

Read from the installed `bobplates_2.1.1.zip`. It has the fullest fission chain of anything surveyed:
`bob-thorium-232` from `bob-thorium-ore` (centrifuging), `bob-thorium-fuel-cell` (12 GJ),
`bob-thorium-plutonium-fuel-cell` (60 GJ), `bob-plutonium-239`, `bob-plutonium-fuel-cell` (40 GJ), a
Kovarex analogue on plutonium (40 Pu-239 + 5 U-238 → 41 Pu-239 + 2 U-238), and
`bob-deuterium-fuel-cell` / `-2` at 80 and 120 GJ.

Its treatment is instructive precisely because it is thorough and still not physical: **every isotope
transformation is a centrifuge recipe.** `bob-plutonium-nucleosynthesis` makes Pu-239 from 5 U-235 +
15 U-238 in a `centrifuging` machine. In reality Pu-239 is made by neutron capture on U-238 *inside an
operating reactor*, followed by two beta decays; a centrifuge separates isotopes and creates none. The
same applies to thorium: `bob-thorium-fuel-reprocessing` yields U-235 rather than U-233. This is not a
criticism of Bob's — it is evidence that when the engine offers only crafting machines, even the most
committed chain becomes chemistry.

**Licensing: `bobplates_2.1.1.zip` contains no licence file of any kind**, and `info.json` and
`changelog.txt` name none. `CLAUDE.md`'s "no licence file means permissive" rule is a rule about
*directories inside the predecessors*, whose repository roots declared WTFPL or the Unlicence. It does
not transfer to a third-party mod with no declaration anywhere: the default is all rights reserved.
**Nothing from Bob's mods is liftable without asking.** Recorded here so the question is not
rediscovered.

## 3. Which fission chains are interesting

All cross-sections below are **thermal (0.0253 eV) values from ENDF/B-VIII.1**, read from Pritychenko's
Tables 2 and 3. The `Atlas` column is the *Atlas of Neutron Resonances* evaluated experimental value
that Pritychenko prints alongside, so each row carries its own cross-check.

| Nuclide | σ_fission (b) | Atlas (b) | σ_capture (b) | Atlas (b) | α = σ_c/σ_f |
|---|---:|---:|---:|---:|---:|
| U-233 | 533.5 | 530.3 ± 1.2 | 44.08 | 45.7 ± 0.7 | **0.083** |
| U-235 | 586.1 | 582.6 ± 1.1 | 99.42 | 98.8 ± 0.8 | **0.170** |
| Pu-239 | 751.1 | 748.1 ± 2.0 | 270.4 | 269.3 ± 2.9 | **0.360** |
| Pu-241 | 1024 | 1011.1 ± 6.2 | 363.9 | 362.1 ± 5.1 | **0.355** |
| Th-232 (fertile) | 5.37 × 10⁻⁵ | 5.2 × 10⁻⁵ | 7.337 | 7.35 ± 0.03 | — |
| U-238 (fertile) | 1.85 × 10⁻⁵ | 1.1 × 10⁻⁵ | 2.683 | 2.682 ± 0.019 | — |

**α is the number that decides which spectrum a chain works in.** It is the fraction of absorptions
that make a heavier nuclide instead of energy. 36 % of the neutrons a thermal Pu-239 nucleus absorbs
are thrown away making Pu-240; 8 % of U-233's are. IAEA-TECDOC-1450 puts the consequence directly:

> "For the 'fissile' ²³³U nuclei, the number of neutrons liberated per neutron absorbed (represented as
> η) is greater than 2.0 over a wide range of thermal neutron spectrum, unlike ²³⁵U and ²³⁹Pu. Thus,
> contrary to ²³⁸U–²³⁹Pu cycle in which breeding can be obtained only with fast neutron spectra, the
> ²³²Th–²³³U fuel cycle can operate with fast, epithermal or thermal spectra."
>
> — IAEA-TECDOC-1450, *Thorium fuel cycle — Potential benefits and challenges*, 2005, §2

and on the fertile side:

> "The absorption cross-section for thermal neutrons of ²³²Th (7.4 barns) is nearly three times that of
> ²³⁸U (2.7 barns). Hence, a higher conversion (to ²³³U) is possible with ²³²Th than with ²³⁸U (to
> ²³⁹Pu). Thus, thorium is a better 'fertile' material than ²³⁸U in thermal reactors but thorium is
> inferior to depleted uranium as a 'fertile' material in fast reactor."

Chain by chain, with what each *requires that the previous one did not*:

### U-235 thermal — the only chain that needs nothing new

0.72 % of natural uranium, fissile at thermal energy, α = 0.17. Requires: a moderator and enough
enrichment or enough neutron economy. Everything else in this list is downstream of it.

### U-238 → Pu-239, fast — requires reprocessing, and does not pay what fiction says

U-238's capture is 2.683 b thermal, but the chain only *closes* in a fast spectrum where α for Pu-239
falls far enough for η to exceed 2 with margin. The IAEA's own database is brutal about how well this
worked. **Total breeding gain** (BG; breeding ratio = 1 + BG), from IAEA-TECDOC-1531 §3.11:

| Plant | Total breeding gain |
|---|---:|
| Phénix (France) | 0.16 |
| Super-Phénix 1 (France) | 0.18 |
| CRBRP (USA) | 0.24 (0.29 initial core) |
| MONJU (Japan) | 0.2 |
| SNR-300 (Germany) | 0.10 |
| PFBR (India) | 0.05, **negative** in core regions |
| BN-350 (Kazakhstan) | 0 |
| PFR (UK) | **−0.05** |
| BN-600 (Russian Federation) | **−0.15** |
| EBR-II, FFTF, BOR-60, Rapsodie, DFR, KNK-II, FBTR | "configuration not for breeding" |

The database's own footnote on Phénix: *"A total breeding gain 1.16 was experimentally defined at the
time of reprocessing"* — i.e. a **breeding ratio** of 1.16, matching BG = 0.16.

**Read that table before designing a breeder tier.** The best number in it is +0.24, on a reactor that
was never built. Half the "breeder" reactors ever operated had a configuration not for breeding, and
two of the ones that tried came out negative. Doubling times implied by BG ≈ 0.15 are decades. A mod
that makes a fast breeder a fuel *multiplier* is making it up; a mod that makes it a fuel *extender* —
you get slightly more out than you put in, and only if you reprocess — is telling the truth and is
arguably a better mechanic, because the reprocessing loop is where the gameplay is.

### Th-232 → U-233 — the only thermal breeder, and it fights back

Requires: an epithermal or thermal spectrum with excellent neutron economy (so: heavy water, graphite,
or molten salt), plus a **fissile starter** (Th-232's own fission cross-section is 5.4 × 10⁻⁵ b — it is
not fuel), plus remote handling. Four primary facts from IAEA-TECDOC-1450:

- **Thorium is "3 to 4 times more abundant than uranium"** and natural thorium "does not contain any
  'fissile' material and is made up of the 'fertile' ²³²Th isotope only."
- **The protactinium delay.** "²³³Pa is formed as an intermediate, which has a relatively longer
  half-life (~27 days) as compared to ²³⁹Np (2.35 days) in the uranium fuel cycle thereby requiring
  longer cooling time of at least one year for completing the decay of ²³³Pa to ²³³U." Pa-233 also
  absorbs neutrons while it sits there, which is why molten-salt designs pull it out of the core.
- **The U-232 problem, which is also the selling point.** U-232 forms via (n,2n) on Th-232, Pa-233 and
  U-233; its "half-life of ²³²U is only 73.6 years and the daughter products have very short half-life
  and some like ²¹²Bi and ²⁰⁸Tl emit strong gamma radiations: 0.7–1.8 MeV and 2.6 MeV respectively",
  which "necessitat[es] remote and automated reprocessing and refabrication in heavily shielded hot
  cells". This is the mechanically interesting bit: **thorium fuel gets more dangerous to handle the
  longer you store it**, and that is a genuinely unusual constraint to build a factory around.
- **ThO₂ is harder in every processing sense.** Melting point 3 350 °C against UO₂'s 2 800 °C, so
  sintering above 2 000 °C; and dissolution needs "Boiling THOREX solution [13 M HNO₃ + 0.05 M HF +
  0.1 M Al(NO₃)₃] at ~393 K and long dissolution period", with the HF corroding the plant and aluminium
  nitrate added to mitigate it.

TECDOC-1450 also records that breeding ratio in Th–U systems "show[s] the possibility of breeding ratio
to approach 1.0 but not to exceed it" for HTGRs and heavy water reactors, and ≥ 1.0 in a BN-800-type
sodium-cooled fast reactor. So thorium's thermal breeding is real and marginal, exactly as U-238's fast
breeding is real and marginal.

### Pu-239/241 recycle (MOX) — requires reprocessing and buys degradation

α = 0.36 and 0.355 thermal, so each pass through a thermal reactor degrades the vector toward Pu-240
and Pu-242. This is why MOX is a once-or-twice thing in LWRs and why the plutonium argument really
belongs to fast reactors.

### Minor-actinide burning — requires a fast spectrum and gives no energy story

Np-237 (σ_f 0.0204 b), Am, Cm. The point is waste transmutation, not power. In a game about scaling
power up, a machine whose product is *less waste* is a hard sell unless waste is a mechanic first.

### The one nobody puts in a mod: Xe-135

Not a chain — a poison, and the largest number in the whole dataset. **Xe-135 thermal capture is
2.664 × 10⁶ barns** (ENDF/B-VIII.1; Atlas 2.65 × 10⁶). Sm-149 is 4.051 × 10⁴ b. Xe-135 is bred from
I-135 after fission and burnt out by the flux while the reactor runs; shut down, and the iodine keeps
decaying into xenon with nothing to burn it, so the reactor **cannot be restarted for the best part of
a day**. That is a mechanic no Factorio mod has, it is derivable from data in the same library the repo
already uses, and it is the single most distinctive thing about operating a fission reactor.

Whether "your reactor is locked out for twenty minutes of game time after you turn it off" is *fun* is
a design question and not mine. It is the kind of thing that is either the best idea in the note or the
worst.

## 4. What is necessary outside the fissionable material

This is the part the brief flagged as under-explored, and it is where a fission mod's actual recipe
graph lives.

### Moderators

A fast neutron born at ~2 MeV must reach ~0.025 eV to see U-235's 586 barns instead of a few. The
figure of merit is the **moderating ratio** — slowing-down power divided by absorption — because a
material that slows neutrons well and eats them is not a moderator. DOE-HDBK-1019/1-93 Table 2, p. 27,
verbatim:

| Material | ξ (log energy decrement) | Collisions to thermalise | Macroscopic slowing-down power | **Moderating ratio** |
|---|---:|---:|---:|---:|
| H₂O | 0.927 | 19 | 1.425 | **62** |
| D₂O | 0.510 | 35 | 0.177 | **4 830** |
| Helium | 0.427 | 42 | 9 × 10⁻⁶ | **51** |
| Beryllium | 0.207 | 86 | 0.154 | **126** |
| Boron | 0.171 | 105 | 0.092 | **0.00086** |
| Carbon | 0.158 | 114 | 0.083 | **216** |

Boron is the control in that table: excellent slowing-down power, ratio of 0.00086, useless as a
moderator and superb as an absorber. That one row is the whole concept.

The underlying cause is visible in ENDF/B-VIII.1 directly: **H-1 capture is 0.3326 b, H-2 capture is
5.057 × 10⁻⁴ b** — light hydrogen eats 658 times more neutrons than heavy hydrogen. Everything about
heavy water follows from that ratio.

**What fails without a moderator:** natural or low-enriched uranium will not go critical at all in a
thermal design. **What each costs to produce:**

- **Light water** — free, and pays for itself in enrichment: an LWR needs 3–5 % U-235.
- **Heavy water** — see §5. Expensive, and buys natural-uranium operation.
- **Graphite** — needs *nuclear-grade* purity, principally boron-free, because boron's ratio is 0.00086.
  A carbon chain that is indistinguishable from making coke is the wrong chain; the interesting step is
  purification.
- **Beryllium** — ratio 126, and it is also an (n,2n) *multiplier*, which is why it appears in fusion
  blankets. Toxic and rare.

### Coolants

The coolant's job is to remove heat without eating neutrons and without needing enormous pressure. Real
numbers, from IAEA-TECDOC-1531 §7.3 (secondary sodium temperatures at the intermediate heat exchanger):

| Plant | Secondary inlet (°C) | Secondary outlet (°C) |
|---|---:|---:|
| Phénix | 350 | 540 |
| PFR (UK) | 370 | 540 |
| BN-600 | 315 | 510 |
| Super-Phénix 1 | 345 | 525 |
| EBR-II | 307 | 465 |
| MONJU | 325 | 505 |

The point for a mod: **sodium runs at 500–550 °C at roughly atmospheric pressure**, where a PWR needs
15.5 MPa to reach 325 °C. That is the entire reason anyone puts a metal that burns in air and explodes
in water inside a power station. Vanilla's heat system already carries temperature to 1 000 °C and its
turbine caps at 500 °C, so the engine can express the distinction without new machinery — a
sodium loop that reaches the turbine's ceiling and a water loop that does not is a legible tier.

Survey of the rest, with what each requires:

| Coolant | Why | What it costs |
|---|---|---|
| Light water | cheap, is also the moderator | pressure vessel; boils; positive-void concerns in some designs |
| Heavy water | moderator + coolant, natural-U operation | the D₂O inventory itself, and tritium (§5) |
| Liquid sodium | 500–550 °C at low pressure, no moderation (fast spectrum) | burns in air, reacts with water, so an intermediate loop; opaque to inspection |
| Lead / lead-bismuth | high boiling point, no moderation, chemically inert with water | corrosion of steel; freezes at 125 °C (LBE) and must never freeze; Po-210 from Bi-209 |
| Molten fluoride salt | fuel and coolant in one, atmospheric pressure, on-line reprocessing | fluorine chemistry, and the fuel is now a liquid you must clean continuously |
| Helium | chemically inert, no moderation, very high outlet temperature | ratio 51 as a moderator is irrelevant; the problem is heat capacity and pumping power |
| CO₂ | Magnox/AGR heritage, cheap | reacts with graphite at temperature |

### Reflectors

A reflector is a moderator placed outside the core to bounce leaking neutrons back. Physically it is
not a new material — beryllium, graphite and D₂O all serve — so a mod that wants reflectors is asking
for a *placement* mechanic, not a new recipe chain. Since the mod's parent project already declined
network-shaped simulation ([ADR 0011](../adr/0011-per-reactor-simulation-fluid-coupled.md)), a
neighbour-sensitive reflector would reopen exactly the question ADR 0011 closed. Flagging that, not
resolving it.

### Control absorbers

ENDF/B-VIII.1 thermal capture, read directly:

| Absorber | σ_capture (b) | Note |
|---|---:|---|
| Gd-157 | **252 900** | Atlas 254 000 ± 815. The largest practical absorber. |
| Gd-155 | 60 730 | |
| Cd (natural) | **2 519** | Atlas 2 520 ± 50; the element as found, no separation needed |
| Cd-113 | 19 960 | 12 % of natural Cd |
| Hf (natural) | **104.2** | derived below |
| B-10 | 0.396 **(capture only)** | its useful reaction is (n,α), not (n,γ) — see below |

**Boron is the important special case and the tables above do not show it.** B-10's reactor value comes
from **¹⁰B(n,α)⁷Li**, a charged-particle channel that is not in a capture table at all. That reaction is
one of the IAEA's designated *neutron cross-section standards* (Carlson et al., *Evaluation of the
Neutron Data Standards*, Nuclear Data Sheets **148**, 143, 2018), as is ⁶Li(n,t). Its thermal value is
of order 3 800 b; **I could not open a primary tabulation of the number and am flagging it below rather
than quoting it as sourced.** The design consequence stands either way: boron absorbs by *transmuting*,
producing helium, so a boron absorber is consumed and gasses — which is why boron carbide control rods
swell, and why boric acid in the coolant is a chemical shim rather than a rod.

What each costs to produce:

- **Boron** — B₄C from boron ore; the enriched-B-10 route is an isotope separation plant, which is a
  different tier of machine from a smelter.
- **Cadmium** — usable as the natural element, which makes it the cheap one, and it melts at 321 °C,
  which makes it the one that fails in an accident.
- **Hafnium** — usable as the natural element, corrosion-resistant, and *it is the waste stream of
  making zirconium*, which is the neatest by-product relationship in the whole subject (below).
- **Gadolinium** — burnable poison mixed into the fuel itself, not a rod: it burns out as the fuel does,
  which is a self-regulating mechanic rather than a control.

### Structural material, and why zirconium specifically

Cladding sits in the neutron flux for years, so its absorption is subtracted from the reactor's neutron
economy the entire time. Zirconium is chosen for exactly one reason, and hafnium is why it is difficult.

Derived from ENDF/B-VIII.1 per-isotope thermal captures weighted by standard isotopic abundance:

```
Zr natural  =  0.5145×0.01025 + 0.1122×1.205 + 0.1715×0.2264
             + 0.1738×0.04995 + 0.0280×0.02031            =  0.1886 b
Hf natural  =  0.0016×562.2  + 0.0526×22.14 + 0.1860×371.9
             + 0.2728×83.93  + 0.1362×40.50 + 0.3508×12.92 =  104.2 b
ratio                                                       =  553×
```

Those land on the standard published figures (Zr ≈ 0.18 b, Hf ≈ 104 b) without my having to take them
from anyone. **Zirconium and hafnium are chemically almost identical and always occur together, and one
of them absorbs 553 times more neutrons than the other.** Nuclear-grade zirconium therefore requires
hafnium reduced to below ~100 ppm, which means a liquid-liquid extraction or ion-exchange separation
before the Kroll reduction of ZrCl₄ to metal.

**This is the best recipe chain in the entire subject and no mod has it.** A separation step whose
*by-product* is the control-rod material, feeding a cladding whose absorption you would otherwise pay
for forever. Zirconium in, Zircaloy and hafnium out, both of them needed, from one plant.

(Zircaloy's other property is the one that matters in accidents: above ~1 200 °C zirconium reduces
steam and liberates hydrogen. That is Three Mile Island and Fukushima. Whether a mod wants a failure
mode is a scope question.)

### Fuel forms

| Form | Why | Cost |
|---|---|---|
| Metal | highest density of fissile atoms per volume — best for breeding; conducts heat well | swells and phase-changes under irradiation; low melting point; is what EBR-II and the IFR used, and what pyroprocessing exists for |
| Oxide (UO₂) | dimensionally stable, high melting point, the industry default | poor thermal conductivity, so the pellet centre runs ~1 000 °C hotter than its rim |
| Carbide / nitride | better conductivity than oxide, denser than oxide | pyrophoric; nitride needs enriched N-15 or you breed C-14 |
| Molten salt | fuel *is* the coolant, no fuel fabrication at all, continuous reprocessing, no fuel-melt accident | the entire plant is now a radiochemistry facility, and fluoride chemistry attacks everything |

For a factory game the ranking is upside-down from the industry's: molten salt is the one with the
fewest discrete items and the most *fluid* handling, which is this engine's strength and this
project's existing idiom. Oxide fuel is pellets in tubes in bundles — three assembly steps of
increasing tedium.

### Reprocessing — the back end, and the only place the chains close

Nothing past the first pass through the reactor works without this. Three families, each a genuinely
different machine.

**PUREX (aqueous).** From IAEA-TECDOC-1587: "The combination known generically as PUREX (which utilizes
the extractant tributyl phosphate (TBP) mixed in a largely inert hydrocarbon solvent) soon replaced all
earlier solvent extraction media because of its high performance in industrial scale plants", separating
"3 main streams of nuclides (uranium, plutonium, and waste, i.e. fission products and minor actinides)".
The NEA flowsheets put the feed at **HNO₃ 4–4.5 M** with scrub at **HNO₃ 2 M**. This is the mature,
industrial one, and it is a chemical plant: dissolve in nitric acid, extract into an organic phase,
strip back. In Factorio terms: fluids, several columns, recirculating solvent — very close in shape to
the Girdler sulfide loop Core already has.

**Pyroprocessing (electrorefining).** From IAEA-TECDOC-1587, on the IFR/EBR-II line: metallic fuel pins
chopped into "a stainless steel mesh basket that became the anode of an electro-refining cell using a
**LiCl-KCl electrolyte**"; "Application of a potential of less than one volt" anodically dissolves the
fuel except the noble metals; uranium plates on a steel cathode and transuranics are collected in a
liquid cadmium cathode, "about 3-5 kg of TRUs per batch", typically "**a mixture of 70% transuranics,
30% uranium and 5% lanthanide fission products**". The oxide variant first reduces oxide to metal "by
electrolysis in a LiCl bath containing 1 wt.% Li₂O and operated at **650 °C**". Waste salt is turned
into sodalite by mixing with zeolite and "heating to temperatures near **900 °C**".

Pyroprocessing is deliberately *bad* at separating pure plutonium — the product is always a TRU mixture
— which is its proliferation argument and, incidentally, a nice game constraint: you cannot get clean
plutonium out of it.

**Fluoride volatility.** From the NEA report, Chapter 3: "The saturated vapour pressures of uranium and
plutonium hexafluorides are equal to that of the atmosphere at **56.4 and 62.3 °C** respectively, while
fluorides of fission products belonging to groups 1-4 of the periodic system are non-volatile at these
temperatures". Fluorination runs at **500 °C**, and "In the fluorination of a uranium-plutonium mixture,
uranium hexafluoride is formed much more readily than plutonium hexafluoride" — the equilibrium constant
for PuF₄ + F₂ = PuF₆ at 500 °C "is only 0.01", so U and Pu separate at the fluorination step itself.
Yields from bench-scale spent-fuel work: "**above 99% and 89-91%** respectively" for uranium and
plutonium. The FREGAT demonstration concentrated "about 85% of the total radioactivity" into residues
"which did not exceed 15% of the fuel mass". Its distinguishing property is radiation-insensitivity:
"gives an opportunity to reprocess SNF with any short cooling period", which matters enormously for a
fast reactor's short doubling time and for molten-salt on-line processing.

Note what fluoride volatility does to a mod's fluid set: it *is* a gas-handling chain. UF₆ boils at
56.4 °C; the same chemistry is what enrichment uses. One reagent family, two purposes.

## 5. Heavy water specifically, and the connection this pack already has

### What D₂O buys

IAEA-TECDOC-1450, §3.2.2, primary:

> "The advantages of using heavy water as a moderator are well understood. Its moderating ratio (the
> ratio of moderating ability to neutron absorption) is about eighty times that of light water,
> providing substantially better neutron economy than light water. For a breeding cycle, which is
> predicated on the availability of neutrons to breed fissile nuclides, the neutron economy of the
> reactor system is particularly important."

DOE-HDBK-1019's table gives the ratio as 4 830 against 62, i.e. 78× — the two sources agree. The
consequence is the one Truls named: **a heavy-water reactor runs on natural uranium.** No enrichment
plant, no centrifuge cascade, no separative work. UKAEA's tritium report states the corollary that
matters: "CANDU reactors do not have burnable absorbers, because they are fuelled with natural uranium
which **has very little reactivity margin**." Heavy water buys you the fuel and spends your margin.

That trade is a *good tier*: an early reactor that needs no enrichment but is fragile, against a later
one that needs an enrichment plant but is forgiving.

### How D₂O is made

Deuterium is ~150 ppm of natural hydrogen, so heavy water is an isotope separation problem with a
separation factor barely above 1. The dominant route was the **Girdler sulfide (GS) dual-temperature
H₂O/H₂S exchange**: a cold tower near 30 °C and a hot tower near 130 °C, exploiting the fact that
deuterium concentrates into the water at low temperature and into the H₂S at high temperature, so
circulating H₂S between two towers pumps deuterium up without consuming the H₂S. The alternative
industrial route is **monothermal ammonia–hydrogen catalytic exchange**. Both are enormous plants; GS is
energy-hungry and circulates lethal quantities of hydrogen sulfide.

**This repository already models GS, and models it well.** `RealisticFusionCore/prototypes/recipes/deuterium.lua`
has `rf-heavy-water` taking 100 water + 50 `rf-hydrogen-sulfide` and returning 10 heavy water, 90
depleted water and **the same 50 hydrogen sulfide**, marked `ignored_by_stats` on both sides with the
comment *"the catalyst is not net-produced or net-consumed"*. That is the physics of a
dual-temperature exchange loop expressed correctly in the engine's own idiom, and it is already better
than what K2 ships (500 water → 20 heavy water, one recipe, no catalyst). **A fission module in this
pack would not build a heavy-water chain. It would consume one that exists.**

### The tritium, which is the whole point

Deuterium's capture cross-section is small — **5.057 × 10⁻⁴ b** (ENDF/B-VIII.1) — but a CANDU's
moderator is hundreds of tonnes of it sitting in a high flux for decades, so ²H(n,γ)³H accumulates.
Every heavy-water reactor makes tritium whether it wants to or not, and the operators are *required* to
remove it.

From UKAEA CCFE-PR(17)67 (Kovari, Coleman, Cristescu & Smith, *Tritium resources available for fusion
reactors in the long term*), primary:

> "The tritium required for ITER will be supplied from the CANDU production in Ontario, but while
> Ontario may be able to supply 8 kg for a DEMO fusion reactor in the mid-2050s, it will not be able to
> provide 10 kg at any realistic starting time."

> "Reactors using heavy water as moderator, coolant, or both, inevitably generate tritium due to neutron
> capture by deuterium. […] Ontario Power Generation (OPG) operates a Tritium Removal Facility (TRF) at
> its Darlington nuclear station. This facility extracts tritium from the moderator water of all of
> OPG's CANDU reactors (not just the four at Darlington). Ni et al estimate that one CANDU 6 reactor can
> produce **130 g of tritium per year**, but this is based on physics, not actual production data."

> "Various estimates for tritium production in HWRs are to be found in the literature, ranging from
> **0.21 to 0.26 kg/GWe/full-power year**, which agrees well with the data from Cernavoda reactors in
> Romania (0.22 kg/GWe/fpy)."

And the routes to make *more* of it, deliberately:

> "(a) adjuster rods containing lithium could be used, giving **0.13 kg per year per reactor**; […]
> (c) tritium production could be increased by **0.05 kg per year per reactor** by doping the moderator
> with lithium-6."

**That is the design finding.** The mod's D-T tier currently runs on tritium the D-D reactors breed as a
by-product (`M.fuels["rf-d-d-plasma"].products`, ADR 0010, `rf-isotope-collector`), with lithium blanket
breeding recorded as a later upgrade. The real world does neither: it takes tritium out of fission
reactor moderator, and ITER's supply is a fission by-product. A `RealisticFission` module that produced
`rf-tritium` from a heavy-water reactor would be **the most physically accurate tritium source in the
entire project**, and it would consume `rf-heavy-water` and `rf-lithium` — two fluids and one item Core
already defines.

It would also be a **third** breeding route, and CONTEXT.md currently fixes the vocabulary at exactly
two (*D-D by-products* and *blanket breeding*). Adding one is a vocabulary change as well as a scope
change.

### The fluid-sharing question, answered from the prototype data

Core's fluid set (ADR 0010, `RealisticFusionCore/prototypes/fluids.lua`) already contains
`rf-heavy-water`, `rf-deuterium`, `rf-tritium`, `rf-hydrogen`, `rf-depleted-water`,
`rf-hydrogen-sulfide`, `rf-brine`, `rf-lithium-solution` and the item `rf-lithium`. A fission module
wanting heavy water, tritium and lithium would want **exactly those prototypes** — not similar ones.

And the module seam ADR 0010 defines is already the right shape for it:

> "**`RealisticFusionCore` owns every fluid and item prototype**, and the extraction chain that produces
> feedstock. […] **Dependencies run one way only.** Power depends on Core; Core never references Power."

A Fission module depending on Core and never referenced by it is the same arrangement as Power, and
`#27`'s correction to ADR 0010 already proved the seam works in practice: *"a Core machine consuming,
through an ordinary pipe, a fluid a Power reactor made (`scripts/check-breeding.ps1`)"*. A Core machine
consuming a fluid a *Fission* reactor made is the same test with a different producer.

**Duplicating the fluids would be strictly worse** and is worth saying plainly, because it is the
default outcome of building the module separately: two `heavy-water` fluids that do not connect, two
tritium items, and a player with a pipe that will not join. Nothing here decides that a Fission module
should exist — but if one does, sharing Core's fluids is the arrangement the existing decisions already
point at, and the alternative would need arguing for rather than drifting into.

## 6. Can fission be simulated the way fusion is? — the ADR 0005 problem

This is the section that decides whether a fission module is *judgeable* against
[ADR 0005](../adr/0005-real-time-fusion-simulation.md), and the answer is more interesting than yes or
no.

### The good news: the data pipeline already exists and already handles fission

`tools/derive-reactivities.py` reads ENDF/B-VIII.0 cross-section tables as `{E in eV, σ in barns}` JSON
and integrates them. `tools/endf/README.md` names the source: ENDF/B-VIII.0 published by the IAEA at
<https://www-nds.iaea.org/exfor/endf.htm>. **That is the same library and the same file format that
holds every fission cross-section in §3.** Neutron-induced fission is MT = 18 and radiative capture is
MT = 102 in the same evaluations. Adding U-235 to `CHANNELS` is not a new kind of work.

Better: ENDF is not only cross-sections. The same library publishes a **decay data sublibrary** and a
**fission product yield sublibrary**, which together are what a burnup calculation needs — the
Bateman-equation inputs for U-238 → Pu-239 and for I-135 → Xe-135. So the fission analogue of
`cross-section-data/reactivities.lua` is not one generated table but three, all derivable from the same
upstream with the same kind of script.

### The bad news: the rate law is a different shape

`reactor-logic.lua` computes

```lua
reactions = reactivity.rate(fuel.reaction, t_k, density * f1, density * f2) * spec.volume_m3 * dt
```

— a rate proportional to **n₁ n₂ ⟨σv⟩(T)**, where temperature is the state variable and the tabulated
data is a function of temperature alone. **A fission rate is not that in any limit.** It is

```
fissions/s  =  Σ_f · φ · V
```

where φ is the neutron flux, and φ is not a property of the fuel — it is a property of whether the
*assembly* is critical. The state variable is the neutron population, and the driver is composition and
geometry, not temperature. Temperature enters only as feedback: Doppler broadening of U-238's capture
resonances (negative, prompt, and the reason reactors are stable) and moderator density.

The zero-dimensional standard model is **point kinetics**, and it is structurally the same *kind* of
object as `M.step` — an ODE integrated forward with a small state vector:

```
dn/dt   =  ((ρ − β)/Λ) n  +  Σ λᵢ Cᵢ
dCᵢ/dt  =  (βᵢ/Λ) n  −  λᵢ Cᵢ
```

with ρ the reactivity, β the delayed neutron fraction, Λ the prompt generation time, and six delayed
precursor groups. It is roughly as much code as the plasma power balance, it is as standard a first
model, and it has the same property the fusion model has: the interesting behaviour is *emergent* from
the constants rather than chosen.

**And it contains the best physics-as-gameplay fact in fission.** β ≈ 0.0065 for U-235: 0.65 % of
fission neutrons are delayed by seconds to minutes, and that 0.65 % is the entire reason a reactor can
be controlled by a human or a motor rather than only by physics. Push reactivity above β and the chain
sustains on prompt neutrons alone, with Λ ~ 10⁻⁴ s thermal and ~10⁻⁷ s fast. **The difference between a
power reactor and a bomb is 0.65 % of reactivity**, and that number is a constant, not a balance
choice. DOE-HDBK-1019/2-93 also gives the decay-heat consequence: "About 7 percent of the 200 MeV
produced by an average fission is released at some time after the instant of fission", so a shut-down
reactor is still at "about 5 to 6% of the thermal rating" and "diminishes to less than 1%
approximately one hour after shutdown" — a reactor you cannot simply switch off.

### Where ρ comes from, and this is the hard part

Point kinetics needs ρ = (k−1)/k, and k is not tabulated anywhere because it depends on what the player
built. The classical decomposition is the four-factor formula k_∞ = η f p ε with leakage corrections,
and every factor is computable from macroscopic cross-sections — which is to say, from ENDF microscopic
data plus the composition. So the derivation chain is:

```
ENDF σ(E)  →  spectrum-averaged σ  →  Σ = N σ  →  η, f, p, ε  →  k_∞  →  ρ  →  point kinetics
```

Two honest observations about that chain:

- **It is genuinely data-driven, and it is longer than the fusion one.** The fusion model needs one
  interpolation per tick. This needs a composition-to-k step, which is where all the judgement is.
  A defensible v1 shortcut is to compute k at *load time* for each declared fuel/moderator combination
  — a table of k_∞ against enrichment and moderator ratio, generated by a Python tool from ENDF exactly
  as `reactivities.lua` is — leaving only the point-kinetics ODE and the poison inventory at runtime.
  That fits ADR 0005's letter (rate interpolated from tabulated data derived from cross-sections) and
  its spirit.
- **The spectrum-averaging is where a shortcut becomes a fudge.** A real k calculation solves a
  transport or diffusion equation. Anything cheaper is a parametrisation, and a note that pretended
  otherwise would be doing what `derive-reactivities.py`'s header criticises the redesign for doing.
  **Any ADR proposing this must state that the spectrum treatment is an approximation, not claim it is
  the data speaking.**

### What is *not* honestly simulable per-reactor

ADR 0011 fixed the unit of simulation at one entity, with plasma sharing delegated to the fluid system.
Fission has no equivalent free ride: **criticality is a property of an assembly, not of a building.**
Vanilla's `neighbour_bonus` is a crude stand-in for exactly this. A physically honest multi-reactor
fission model would need neighbour awareness, which is the network-shaped problem ADR 0011 declined for
v1 — and the reasons it declined it (no entity for a network's status text, merge and split losing
state, 440 lines of entity management) apply unchanged.

The available honest answer is that **one fission reactor entity is one core**, self-contained, with
its moderator and absorber state in its own fluidboxes and inventory, and that adjacency does nothing.
That is a real design constraint and it should be stated in any proposal rather than discovered.

## 7. The question underneath: what does "realistic fission" add?

Laid out plainly, because the brief asked me not to flatter the premise.

| Candidate addition | Real? | Does vanilla have it? | Is it interesting, or more clicking? |
|---|---|---|---|
| More isotopes (Th, Pu, U-233) | yes | no | **Clicking**, if they are centrifuge recipes — which is what every mod that has tried has produced |
| Real enrichment (UF₆, SWU cascades) | yes | no (Kovarex is invented) | Marginal. Replaces one fictional loop with a longer real one |
| Reprocessing that yields plutonium | yes | no (5 → 3 U-238) | **Interesting** — it is the loop that closes the fuel cycle and it is where the fast-reactor story lives |
| Moderator choice (H₂O / D₂O / C) driving enrichment requirement | yes | no | **Interesting** — a real branch with a real trade, and D₂O's chain already exists here |
| Zr/Hf separation, hafnium as by-product | yes | no | **Interesting** — the best by-product relationship in the subject |
| Criticality, control rods, delayed neutrons | yes | **no** | **The delta.** No mod has it; it is simulable; it is what a reactor *is* |
| Xe-135 poisoning / restart lockout | yes | no | **Interesting or infuriating**, and that is a design call |
| Decay heat after shutdown | yes | no | Interesting; makes a reactor a commitment rather than a switch |
| Breeding as a fuel multiplier | **no** — BG ≈ 0.16 at best, negative for BN-600 | no | Would be a lie. Breeding as a fuel *extender* is true and less exciting |
| Tritium from heavy-water moderator | yes | no | **The connection to this pack**, and the only one that makes fission serve the mod's existing subject |

Reading that table honestly: **the case for a fission module is criticality and the tritium link, and
almost nothing else.** A mod that adds thorium, plutonium and four fuel-cell tiers as centrifuge recipes
has added clicking; Bob's already did it, thoroughly, ten years ago. A mod that makes a reactor a thing
you can poison, stall, and lose control of has added something nobody has.

## 8. Options, with trade-offs

**These are options, not a recommendation. Every one of them past A is out of scope under
[ADR 0002](../adr/0002-v1-scope-and-module-split.md), which fixes v1 at fusion power only, and would
need a superseding ADR. Whether `RealisticFission` exists at all is Truls's decision, as is where it
would sit and what it would share.**

### A. No fission module. Vanilla's stays as it is.

- **For:** vanilla's abstraction is defensibly scaled (§1); the pack's subject is fusion; ADR 0002 is
  unamended; nothing in v1 waits on this.
- **Against:** loses the tritium link, which is the one place fission genuinely serves this pack, and
  leaves the mod's tritium coming from a D-D by-product route that the real world does not use.
- **Note:** the only option requiring no ADR.

### B. A minimal heavy-water reactor whose product is tritium, not power.

One entity consuming `rf-heavy-water` and natural uranium, producing modest power and `rf-tritium` at
a rate derived from ²H(n,γ)³H. Optionally lithium-6 doping of the moderator as an upgrade, exactly as
Kovari et al. describe (+0.05 kg/reactor-year).

- **For:** the physically correct tritium source; consumes Core fluids that already exist; smallest
  possible fission surface; makes the fission module *serve* the fusion module rather than compete with
  it. Directly cited end to end.
- **Against:** it is a fission module that is barely about fission, and a player who wanted a fission
  overhaul would be disappointed. It also adds a third breeding route to a CONTEXT.md that names two.
- **Cost:** low to medium. One entity, one recipe path, one technology, no new fluids.

### C. Criticality as the mod's identity — point kinetics, control rods, poisons.

The full §6 model: k from ENDF-derived tables, point kinetics with six delayed groups, Doppler
feedback, control-rod reactivity, Xe-135 and Sm-149 inventories, decay heat.

- **For:** the only option that adds something no mod has; the only one that is to fission what ADR 0005
  is to fusion; and the physics is genuinely emergent rather than chosen. It reuses this project's
  established pattern — a Python tool generating a Lua table from ENDF — without inventing a new one.
- **Against:** the spectrum-averaging step is an approximation and must be declared as one (§6); it is a
  materially larger simulation than `reactor-logic.lua`; and ADR 0005's outstanding UPS obligation would
  arrive again, unmeasured, on a heavier model. It also cannot express multi-reactor criticality under
  ADR 0011's per-entity rule.
- **Cost:** high. A second simulation, a second generator tool, three ENDF sublibraries.

### D. Fuel-cycle breadth without criticality — the conventional overhaul.

Thorium, plutonium, U-233, PUREX/pyro/fluoride reprocessing, Zr/Hf separation, moderator choice, as
recipe chains.

- **For:** large visible content for known effort; the chemistry is all real and all citable; the Zr/Hf
  and reprocessing chains are genuinely good factory design.
- **Against:** it is what Bob's already ships, and by this project's own standard (ADR 0005: physics
  computed, not implied through recipe ratios) it is the thing this project exists to not be. A
  centrifuge that makes plutonium is `bob-plutonium-nucleosynthesis` with better icons.
- **Cost:** medium, and mostly art and locale rather than code.

### E. Fission as a fusion *neutron multiplier* — the hybrid.

Not a separate module: a fission blanket on a D-T reactor, multiplying its 14 MeV neutrons. This is the
one published route to net-positive muon-catalysed fusion too (Petrov 1980, recorded in
[`cold-fusion.md`](cold-fusion.md) Option C), so it arrives from two directions independently.

- **For:** puts fission inside the fusion mod's own subject rather than beside it; a real design in the
  literature; and it makes the D-T tier's neutron output — currently just "sold as reactor energy" —
  mean something.
- **Against:** it needs uranium, which is a vanilla map resource, and ADR 0010 deliberately avoided map
  resources for lithium on worldgen grounds. Vanilla uranium already exists so the worldgen objection is
  weaker, but the dependency is new. It also blurs the mod's identity in the direction Romner's
  deprecation notice warned about.
- **Cost:** medium. One entity on the Power side, one new dependency on vanilla ore.

### The question underneath all of them

**Does this pack want fission at all, or does it want the one thing fission gives fusion — tritium?**
Option B says the second and nothing more. Option C says fission deserves the same treatment fusion got
and should be its own project-scale effort. Option E says fission belongs inside the fusion mod as a
component, not beside it as a peer. Option D says the market wants breadth. **That is a scope-and-
identity question and it is Truls's.**

## Sources

Primary, read directly:

- **Factorio 2.0.77 base game data**, installed at `D:\SteamLibrary\steamapps\common\Factorio\data\`.
  `base/info.json` version 2.0.77. Files: `base/prototypes/recipe.lua`, `base/prototypes/item.lua`,
  `base/prototypes/entity/entities.lua`, `base/prototypes/entity/resources.lua`,
  `base/prototypes/fluid.lua`; `space-age/prototypes/{recipe,technology}.lua`.
- B. Pritychenko, *Tables of Neutron Thermal Cross Sections, Westcott Factors, Resonance Integrals,
  Maxwellian Averaged Cross Sections, Astrophysical Reaction Rates, and r-process Abundances Calculated
  from Evaluated Nuclear Data Libraries*, **Atomic Data and Nuclear Data Tables 163, 101708 (March
  2025)**; arXiv:2503.18990. Tables 1–3 (thermal elastic, fission, capture) for ENDF/B-VIII.1,
  JEFF-3.3, JENDL-5.0, CENDL-3.2, BROND-3.1 and the *Atlas of Neutron Resonances*.
  <https://arxiv.org/abs/2503.18990>
- IAEA, **IAEA-TECDOC-1450**, *Thorium fuel cycle — Potential benefits and challenges*, Vienna, May
  2005. <https://www-pub.iaea.org/MTCD/Publications/PDF/TE_1450_web.pdf>
- IAEA, **IAEA-TECDOC-1531**, *Fast Reactor Database — 2006 Update*, Vienna, December 2006. §3.11–3.12
  (breeding gain), §7.3 (intermediate heat exchanger coolant temperatures).
  <https://www-pub.iaea.org/MTCD/publications/PDF/te_1531_web.pdf>
- IAEA, **IAEA-TECDOC-1587**, *Spent Fuel Reprocessing Options*, Vienna, August 2008.
  <https://www-pub.iaea.org/MTCD/Publications/PDF/TE_1587_web.pdf>
- OECD Nuclear Energy Agency, **NEA/NSC/WPFC/DOC(2012)15**, *Spent Nuclear Fuel Reprocessing Flowsheet
  — A Report by the WPFC Expert Group on Chemical Partitioning of the NEA Nuclear Science Committee*,
  © OECD 2012. Chapter 3 (fluoride volatility).
  <https://www.oecd-nea.org/upload/docs/application/pdf/2020-01/nsc-wpfc-doc2012-15.pdf>
- US Department of Energy, **DOE-HDBK-1019/1-93**, *DOE Fundamentals Handbook: Nuclear Physics and
  Reactor Theory*, Volume 1, January 1993 — module NP-02 *Reactor Theory (Neutron Characteristics)*,
  Table 2 "Moderating Properties of Materials", p. 27.
- US Department of Energy, **DOE-HDBK-1019/2-93**, Volume 2, January 1993 — module NP-04, *Reactor
  Operation*, decay heat.
- D. G. Madland, *Total prompt energy release in the neutron-induced fission of ²³⁵U, ²³⁸U, and ²³⁹Pu*,
  **Nuclear Physics A 772, 113–137 (2006)**; arXiv:nucl-th/0603071. Eqs. (31)–(33) and (46)–(48).
  <https://arxiv.org/abs/nucl-th/0603071>
- M. Kovari, M. Coleman, I. Cristescu & R. Smith, *Tritium resources available for fusion reactors in
  the long term*, **UKAEA CCFE-PR(17)67**, Culham Centre for Fusion Energy.
  <https://scientific-publications.ukaea.uk/wp-content/uploads/CCFE-PR1767-1.pdf>
- A. D. Carlson et al., *Evaluation of the Neutron Data Standards*, **Nuclear Data Sheets 148, 143
  (2018)** — cited for the standards status of ⁶Li(n,t) and ¹⁰B(n,α); see the caveat below.
- D. A. Brown et al., *ENDF/B-VIII.0: The 8th Major Release of the Nuclear Reaction Data Library with
  CIELO-project Cross Sections, New Standards and Thermal Scattering Data*, **Nuclear Data Sheets 148,
  1–142 (2018)**; library released by CSEWG on 2 February 2018. <https://www.nndc.bnl.gov/endf-b8.0/>
- J. R. Stehn, M. Divadeenam & N. E. Holden, *Evaluation of the thermal-neutron constants for ²³³U,
  ²³⁵U, ²³⁹Pu and ²⁴¹Pu*, **BNL-NCS-31878**, National Nuclear Data Center, 1982 — cited as the
  canonical evaluation of the 2200 m/s constants and fission neutron yields; abstract only, see below.

Mod source, read directly:

- **Krastorio 2 2.1.3**, `C:\src\factorio\_reference\Krastorio2` — root `LICENSE` is **GNU LGPLv3**.
  `prototypes/updates/base/{entities,recipes}.lua`, `prototypes/recipes/{centrifuging,electrolysis,nuclear-fusion}.lua`,
  `prototypes/buildings/{advanced-steam-turbine,fusion-reactor}.lua`. `Krastorio2Assets` root `LICENSE`
  is likewise LGPLv3.
- **Bob's Metals, Chemicals and Intermediates 2.1.1**, `bobplates_2.1.1.zip` from the local mods
  directory — `prototypes/item/nuclear.lua`, `prototypes/recipe/nuclear-recipe.lua`. **No licence file
  of any kind in the archive.**

In this repository:

- `RealisticFusion/scripts/reactor-logic.lua`, `RealisticFusion/scripts/reactivity.lua`,
  `tools/derive-reactivities.py`, `tools/endf/README.md`.
- `RealisticFusionCore/prototypes/fluids.lua`, `RealisticFusionCore/prototypes/recipes/deuterium.lua`.
- `CONTEXT.md`; ADRs [0002](../adr/0002-v1-scope-and-module-split.md),
  [0003](../adr/0003-space-age-tolerated-not-targeted.md),
  [0005](../adr/0005-real-time-fusion-simulation.md),
  [0007](../adr/0007-coexistence-without-integration.md),
  [0010](../adr/0010-v1-module-layout-and-prototype-set.md),
  [0011](../adr/0011-per-reactor-simulation-fluid-coupled.md); and
  [`cold-fusion.md`](cold-fusion.md) for the hybrid-blanket route arrived at independently.

### What could not be sourced primarily

Stated plainly rather than laundered.

- **ν̄, the average number of neutrons per fission.** I could not open a primary tabulation. The Stehn,
  Divadeenam & Holden evaluation (BNL-NCS-31878) is the right reference and its OSTI record carries only
  an abstract with no numbers; the ENDF/B-VIII.0 and JEFF-3.3 papers are paywalled or behind an identity
  redirect. **No ν̄ value is quoted anywhere in this note.** The argument in §3 is built on
  α = σ_c/σ_f, which I did compute from primary data, plus IAEA-TECDOC-1450's own statement about η — so
  nothing here depends on a number I could not open. Any ADR that needs η numerically must source ν̄
  first.
- **¹⁰B(n,α)⁷Li thermal cross-section (~3 800 b) and ⁶Li(n,t)⁴He (~940 b).** Both are IAEA neutron
  cross-section *standards*, and Carlson et al. (2018) is the right citation, but the paper is on
  ScienceDirect behind a 403 and <https://nds.iaea.org/standards/> returned 402 to the fetcher. The
  Pritychenko tables cover elastic, fission and capture only, so the (n,α) and (n,t) channels are not in
  the data I read. **The numbers are named as "of order" in §4 and are not quoted as sourced.**
- **Xe-135 and I-135 half-lives (~9.1 h and ~6.6 h).** The 2.664 × 10⁶ b capture cross-section **is**
  primary (ENDF/B-VIII.1, Pritychenko Table 3). The half-lives are standard ENSDF/NuDat values that I
  did not open, so §3's "best part of a day" is a qualitative statement rather than an arithmetic one.
- **Girdler sulfide separation factors (2.32 at ~32 °C, ~1.8 at ~130 °C) and the deuterium abundance in
  natural water (~140–156 ppm).** I could not obtain a primary source. IAEA-TECDOC-1080 is a different
  document entirely (research-reactor fuels); the ANSTO survey PDF is a scan with no text layer; the ACS
  chapter (H. K. Rae, *Selecting Heavy Water Processes*, ACS Symposium Series 68, 1978) returned 403.
  **§5 therefore describes the GS process qualitatively — two towers, hot and cold, H₂S recirculating —
  and quotes no separation factor.** The physics that §5's argument actually rests on (the D₂O/H₂O
  moderating-ratio contrast, and H-1 vs H-2 capture) is primary.
- **Isotopic abundances used to weight the Zr and Hf capture cross-sections.** The per-isotope σ values
  are primary (ENDF/B-VIII.1); the abundances are standard values I did not take from IUPAC's technical
  report. The derived 0.1886 b and 104.2 b land on the published figures, which is corroboration rather
  than a second source.
- **β ≈ 0.0065 and Λ ~ 10⁻⁴ s.** Standard point-kinetics constants, not sourced here. DOE-HDBK-1019
  covers delayed neutrons qualitatively in the module I read; the numeric fractions are in a volume I
  could not obtain. §6's argument is structural and does not turn on the exact values, but an ADR would
  need them.
- **Nuclear-grade zirconium's hafnium limit (~100 ppm) and the Kroll reduction route.** Reported
  consistently but from review literature and secondary summaries, not from a primary specification.
- **Delayed β/γ energy release (~12–14 MeV) added to Madland's prompt figure in §1.** Madland is primary
  for the prompt release and deposition; the delayed component and the ~193 MeV recoverable total are
  the conventional decomposition and I did not source them primarily. The §1 conclusion is stated across
  three values (185.6, 193 and 200 MeV) precisely so it does not depend on that choice.
- **Whether ENDF's decay and fission-yield sublibraries are as directly usable as the cross-section
  files.** §6 asserts they exist in the same format from the same publisher, which is true of the ENDF-6
  format generally; **I did not download or parse either sublibrary**, so "as easy as the cross-sections"
  is an expectation and not a verified claim.
