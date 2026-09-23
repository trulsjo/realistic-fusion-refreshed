# What moves the fuel-chain supply ratio, and what each lever costs

**Measured 2026-09-20 at revision `d47055d`, on the pure simulation** —
`realistic-fusion-refreshed/scripts/reactor-logic.lua` through `M.settle`, both ends settled for
1200 s at one tick, box full and never starved unless a row says otherwise. No game is started.

**Reproduce it with `lua scripts/probe-supply-ratio.lua`.** About seventeen seconds, and every
table and chart below is pasted from that run, except the fully-researched table under *Decided
against*, which says where it came from.

**It is a probe, so it asserts nothing and exits 0 whatever it finds**
([`CLAUDE.md`](../../CLAUDE.md)'s paragraph on probes is the contract). A lever that makes the ratio
worse is a result here, not a failure — and three of them do. The probe stays committed so the next
rebalance can be asked the same question instead of this note being trusted after the model has
moved under it.

**It decides nothing, and it must not.**
[ADR 0038](../adr/0038-heating-power-is-the-second-researchable-lever.md) already chose the lever
and Truls took that decision; this note is the pricing the choice was checked against, committed so
it can be re-taken. Where a row disagrees with what is shipped, the shipped value is the decision.

## The quantity

`CONTEXT.md` defines **supply ratio** and both its readings. Every figure here is **per saturated
reactor** — settled D-D reactors per settled D-T reactor — unless the column says *per heater*.

**The control comes out right**, which is what says the rig measures the same quantity the
repository publishes rather than something subtly else:

```
  CONTROL REPRODUCES the published baseline.
  94.7 / 9.123 / Q 0.3205 measured against 94.7 / 9.123 / Q 0.3204 published
```

The published side of that comparison is pinned to 1% in `tests/test-reactor-logic.lua`, which is a
gate. The probe's control line is not — a probe cannot fail — so it prints loudly instead. **A rig
priced against the wrong baseline reads exactly like a working one**, which is why the row is there
at all.

## Every lever on one axis

One representative point per lever — the top of a shipped ladder where there is one, a round move
a reader can hold in their head otherwise. It is the only figure here where the three that make the
ratio **worse** stand next to the ones that help.

| lever | ratio | per heater | D-D Q |
|---|---|---|---|
| shipped, unresearched | **94.70** | 9.12 | 0.320 |
| **both ladders, topped** — the state #294 gates | **8.93** | 0.97 | 2.004 |
| heating ladder alone, at entry confinement | 32.63 | 3.18 | 0.613 |
| confinement ladder alone, at entry heating | 18.50 | 1.99 | 1.467 |
| box halved — the density lever | 20.34 | 7.06 | 0.414 |
| D-T fed at half — a player's throttle | 26.28 | 9.12 | 0.320 |
| D-D fed at 75% — the same throttle, on the breeder | 69.02 | 6.65 | 0.440 |
| `max_temperature_c` ×0.4 | *124.44 — worse* | 9.12 | 0.320 |
| `particles_per_unit` ×2 | *9 895 — worse* | 523.70 | 0.011 |
| `volume_m3` halved | *300.17 — worse* | 15.98 | 0.183 |

```
every lever, against the shipped 94.70
  shipped, unresearched  |##############                           94.70
  both ladders, topped   |#                                        8.93
  heating ladder alone   |########                                 32.63
  confinement alone      |#####                                    18.50
  box halved             |######                                   20.34
  D-T fed at half        |#######                                  26.28
  D-D fed at 75%         |############                             69.02
  clamp x0.4             |###############                          124.44
  density x2             |#######################################  9895.45
  volume_m3 halved       |####################                     300.17
                         |   ^ #294's ceiling of 15
                          log scale, 8.93 to 9895.45
```

**Six of those ten points are states a player can already be in** — the entry state, either ladder
alone, both topped, and the two throttles. The other four are retunes nobody has taken, and
**three of the four make the chain longer**. That is the shape of the problem ADR 0038 was
deciding against, and it is why the decision came down to the two ladders.

**The fully-researched D-D tier is above scientific break-even** at Q 2.004. ADR 0015's *"the D-D
tier is a breeder"* describes the **unresearched** machine, and that is the reading it keeps.

## The three the ticket asked for by name

These are the intuitive moves, and all three make the chain **longer**. They are measured here
rather than described so nobody re-derives them.

| lever | ratio | per heater | D-D Q | what actually happened |
|---|---|---|---|---|
| baseline — shipped | **94.70** | 9.12 | 0.320 | — |
| `max_temperature_c` ×0.4 (5×10⁹ → 2×10⁹ °C) | **124.44** | 9.12 | 0.320 | D-T burns 17.1 u/s, was 13.0 |
| `particles_per_unit` ×2 | **9 895** | 523.70 | 0.011 | D-D Q 0.011, was 0.320 |
| `volume_m3` ×0.5 | **300.17** | 15.98 | 0.183 | D-D Q 0.183, was 0.320 |

**Why lowering the clamp backfires, which is the one worth reading twice.** `max_temperature_c` is
a ceiling on the simulation, not a setpoint. A D-T plasma held below its own equilibrium sits
**nearer the peak of its cross-section** — D-T's ⟨σv⟩ peaks around 70 keV and the shipped plasma
settles far past it — so a clamped D-T reactor fuses *faster* and eats more tritium. The breeder is
untouched, because the clamp never binds on it. Both ends move the wrong way at once.

**Why density backfires.** Fusion goes as n² and so does bremsstrahlung, but the radiation leaves
the plasma while only the charged fraction of the fusion stays in it. At the D-D tier's temperature
the radiation wins, so a denser D-D plasma is a **colder** one.

**`volume_m3` ×0.5 doubles the density too, and is not as bad — which is worth knowing rather than
glossing.** Doubling `particles_per_unit` doubles the density *and* the particle count, so the
radiated power goes up four-fold against twice the thermal store. Halving `volume_m3` doubles the
density at the *same* particle count, so the radiated power only doubles against an unchanged
store. Both are worse than shipped; one is 9 895 at Q 0.011 and the other 300 at Q 0.183, and the
gap is that difference and not noise.

## The two shipped ladders

Both are read off the spec rather than restated, so a retune re-prices them.

| point | heating | ratio | per heater | D-D Q |
|---|---|---|---|---|
| shipped | 50 MW | **94.70** | 9.12 | 0.320 |
| `rf-plasma-heating-1` | 55 MW | 71.73 | 6.93 | 0.384 |
| `rf-plasma-heating-2` | 60 MW | 56.47 | 5.46 | 0.446 |
| `rf-plasma-heating-3` | 65 MW | 45.87 | 4.45 | 0.506 |
| `rf-plasma-heating-4` | 70 MW | 38.27 | 3.72 | 0.562 |
| `rf-plasma-heating-5` | 75 MW | **32.63** | 3.18 | 0.613 |
| past the ladder ×2 | 100 MW | 18.43 | 1.81 | 0.806 |
| past the ladder ×4 | 200 MW | 7.39 | 0.76 | **0.964** |
| past the ladder ×8 | 400 MW | 4.08 | 0.45 | 0.807 |

```
supply ratio against confinement heating
  shipped                |######################################   94.70
  rung 1  heating-1      |##################################       71.73
  rung 2  heating-2      |################################         56.47
  rung 3  heating-3      |#############################            45.87
  rung 4  heating-4      |###########################              38.27
  rung 5  heating-5      |##########################               32.63
  shipped x2             |###################                      18.43
  shipped x4             |#########                                7.39
  shipped x8             |##                                       4.08
                         |                ^ #294's ceiling of 15
                          log scale, 4.08 to 94.70
```

**Two things the rows past the ladder are for.** The ratio falls monotonically and **turns over
nowhere**, which is the property ADR 0038 chose this lever for. And D-D's Q peaks at **0.964** near
200 MW and comes back down — it never crosses 1, so ADR 0015's breeder stays below scientific
break-even at every heating power measured. That is a narrow margin rather than a structural one,
and it is worth knowing before anyone proposes a sixth rung.

| point | confinement | ratio | per heater | D-D Q |
|---|---|---|---|---|
| shipped | 30 s | **94.70** | 9.12 | 0.320 |
| `rf-plasma-confinement-1` | 40 s | 49.86 | 5.06 | 0.578 |
| `rf-plasma-confinement-2` | 50 s | 29.28 | 3.08 | **0.950** |
| `rf-plasma-confinement-3` | 60 s | **18.50** | 1.99 | **1.467** |
| past the ladder ×3 | 90 s | 8.19 | 0.92 | **3.172** |

```
supply ratio against confinement time
  shipped                |#####################################    94.70
  rung 1  confinement-1  |############################             49.86
  rung 2  confinement-2  |#####################                    29.28
  rung 3  confinement-3  |##############                           18.50
  shipped x3             |###                                      8.19
                         |          ^ #294's ceiling of 15
                          log scale, 8.19 to 94.70
```

**Confinement reaches lower ratios than the heating ladder does, and takes the breeder over
break-even doing it.** Its top rung is 18.50 where heating's top rung is 32.63. Q(D-D) is
1.467 at the top shipped rung and 3.172 at three times the baseline. ADR 0038 refused to move the
*baseline* for exactly this reason: the ladder's own top rung is already above break-even and
raising the floor to meet it empties the ladder of its meaning. The two lines are not
interchangeable even where the ratios coincide.

## The fill, which is already a player's lever

ADR 0016 makes operating density a throttle rather than a supply problem. So a D-T reactor fed what
a plant can actually breed **is** an under-filled reactor, and the saturated figure describes a
plant the fuel chain has to be built up to.

| point | ratio | what else moved |
|---|---|---|
| D-T at 100% supply | **94.70** | D-T sells 3 151 MW |
| D-T at 75% | 55.73 | 1 871 MW |
| D-T at 50% | 26.28 | 905 MW |
| D-T at 25% | 6.83 | 267 MW |
| D-D at 75% | 69.02 | D-D sells 61.2 MW, breeds 0.188 u/s |
| D-D at 50% | 73.27 | D-D sells 60.1 MW, breeds 0.177 u/s |

**Throttling the burner is not a model change at all** — nothing in the spec moves, the chain per
unit of tritium is identical, and the megawatts fall with the ratio. It shrinks the plant without
shortening the chain.

**Throttling the breeder is the surprise, and it shortens the chain.** A leaner D-D plasma is a less
dense one, bremsstrahlung goes as n², so it settles hotter and breeds **more** per reactor: 0.188
u/s at 75% fill against 0.137 u/s full. That is ADR 0016's density optimum showing up on the fuel
chain instead of on the power curve. It is not free — a D-D reactor at half supply buffers half as
much, which is the brownout story ADR 0015 records — but it is a real, already-shipped lever that
costs a player nothing to try.

## The plasma fluid box, which is the density lever by design

`realistic-fusion-refreshed/prototypes/entities.lua` says so in as many words: one
`particles_per_unit` mod-wide *"precisely so that this box is the lever"*. So a row here is not a
capacity tweak with a density side effect — density is the whole of what it does.

| box | n at full | ratio | per heater | D-D Q | D-D settles at |
|---|---|---|---|---|---|
| 250 units | 2.5×10¹⁹ | **9.34** | 12.47 | 0.234 | 1.46×10⁹ °C |
| 500 units | 5×10¹⁹ | **20.34** | **7.06** | **0.414** | 7.12×10⁸ °C |
| **1000 — shipped** | 1×10²⁰ | 94.70 | 9.12 | 0.320 | 2.42×10⁸ °C |
| 2000 units | 2×10²⁰ | 9 895 | 261.85 | 0.011 | 3.88×10⁷ °C |
| 3000 units | 3×10²⁰ | *33.08 — noise* | *5.2×10⁴* | 0.000 | 1.04×10⁷ °C |
| 4000 units | 4×10²⁰ | *18.63 — noise* | *5.2×10⁷* | 0.000 | 3.65×10⁶ °C |

```
supply ratio against the plasma fluid box
  250 units              |#                                        9.34
  500 units              |#####                                    20.34
  1000 units             |##############                           94.70
  2000 units             |#######################################  9895.45
  3000 units             |########                                 33.08   <- both tiers out; this bar is noise
  4000 units             |#####                                    18.63   <- both tiers out; this bar is noise
                         |   ^ #294's ceiling of 15
                          log scale, 9.34 to 9895.45
```

**The last two rows are not improvements and the probe marks them.** At 3×10²⁰ m⁻³ both tiers have
extinguished; the ratio is a quotient of two collapsing numbers and means nothing. The probe marks a
row only when **both** ends are out, because a breeder collapsing alone makes the ratio *larger* —
which is the 2000-unit row, and the honest reading of it.

**Halving the box improves both readings**, 94.70 → 20.34 per reactor and 9.12 → 7.06 per heater,
and D-D's Q peaks near 500 units — ADR 0016's density optimum reappearing as a box size. **The
collateral is the largest of any lever priced here**: D-D on a 500-unit box settles at
7.12×10⁸ °C, hotter than the **6.48×10⁸ °C** the confinement ladder's top rung reaches on the
shipped box, so every rung of ADR 0024 moves. It is *not* hotter than the top of both ladders
together, which reaches 1.18×10⁹ °C. A halved box also halves what one reactor buffers, which is
the `check_input_flow` and exchanger-drain story.

### Capacity and heating are one lever, and the heating goes as capacity squared

The collapse above is a fixed 50 MW spread over more particles against a loss that grew as n².
Holding a temperature costs n², so scaling heating **in proportion** to the box does not stand
still — it is worse than doing nothing:

| box | linear heating | ratio | quadratic heating | ratio | D-D Q |
|---|---|---|---|---|---|
| 2000 units | 100 MW | 300.17 | 200 MW | **18.49** | 1.468 |
| 3000 units | 150 MW | 1 180 | 450 MW | **8.18** | 3.175 |
| 4000 units | 200 MW | 4 506 | 800 MW | **6.06** | 4.189 |

**The quadratic path works and takes the breeder well above break-even** — Q(D-D) 1.468 at the
gentlest of the three. That is the same collision the confinement baseline has with ADR 0015, at a
much larger power bill.

## Levers with no home

**Both neutronic tiers are one spec.** `M.reactor` is what `rf-reactor` runs on whichever plasma it
is fed (#28), so every row above moves **both** ends of the chain at once. *(This said "(ADR 0005)"
until #446. ADR 0005 decides that reaction rate comes from cross-section data. It says nothing about
how many specs there are.)* A lever meant for the
D-T tier alone has no field to be written in. Measured on the D-T end alone, to price the field
that does not exist:

| point | ratio | D-T burns |
|---|---|---|
| `volume_m3` ×0.5, D-T only | 171.39 | 23.5 u/s, was 13.0 |
| `volume_m3` ×2, D-T only | **54.54** | 7.5 u/s, was 13.0 |
| `max_temperature_c` ×0.4, D-T only | 124.44 | 17.1 u/s, was 13.0 |

**A bigger plasma volume on the D-T tier alone is worth 94.70 → 54.54** and nothing in the shipped
model can express it. Pulling it means a second spec, or a per-fuel override on the first. ~~That is a
decision rather than a retune, and this note does not take it.~~ **#446 took that decision: the
field stays unbuilt.** See *Decided against* below.

### Decided against (#446, 2026-09-23)

**`M.reactor` stays one spec for both neutronic tiers.** There is no second spec, no per-fuel
override and no second prototype. Truls decided this on #446.

**The rows above are measured at the unresearched state, which nothing gates.** ADR 0038 gates the
fully-researched state. The same three rows, measured there with both ladders at their top rung and
the D-D end left at the researched spec:

| point | ratio | D-T burns | D-T output |
|---|---|---|---|
| shipped, fully researched | **8.93** | 11.47 u/s | 2812 MW |
| `volume_m3` ×0.5, D-T only | 16.99 | 21.83 u/s | 5294 MW |
| `volume_m3` ×2, D-T only | **4.84** | 6.22 u/s | 1553 MW |
| `max_temperature_c` ×0.4, D-T only | 13.27 | 17.05 u/s | 4148 MW |

*Measured 2026-09-23 at revision `e5019a6`, with the probe's `chain()` arithmetic (`M.settle`,
1200 s at one tick, box full). The same script reproduces 94.70, 8.93 and 54.54, so it measures
the same quantity as the probe. `scripts/probe-supply-ratio.lua` does not print this table.*

**Why the field stays unbuilt:**

- **The ratio has nothing left to buy.** ADR 0038 decision 1 sets the target at about 10 and the
  ceiling at 15. The shipped fully-researched figure is 8.93.
- **The one row that helps does so by making the D-T reactor burn less.** Volume ×2 lowers the
  ratio because the D-T reactor burns less fuel and sells less power: −45% output fully researched,
  −42% at entry. D-D breeding does not change. The lever is a cut to the D-T tier, not a cheaper
  breeder.
- **It moves the entry state.** At unresearched, volume ×2 takes the D-T reactor from 3151 MW to
  1833 MW and its Q from 73.1 to 42.1. ADR 0038 decision 3 keeps entry untouched, and ADR 0015 is
  the design it keeps.
- **A second prototype is outside ADR 0010's prototype set.** It would be a new machine to model,
  art, localise and place in the tech tree. One `rf-reactor` that a player switches from breeder to
  D-T by changing its feed is the intended game.
- **The other two rows make the ratio worse at both states.** Volume ×0.5 gives 171.39 and 16.99.
  The temperature clamp at ×0.4 gives 124.44 and 13.27. Its D-T burn is 17.05 u/s at both states,
  because the plasma sits against the clamp, where confinement time and heating power no longer
  move the burn.

**What reopens it:**

1. A target below 8.93 fully researched, which means superseding ADR 0038 decision 1.
2. A reason to separate the D-T tier that is not the ratio: its own art, its own tech step or its
   own research ladder.
3. A D-T-only lever that lowers the ratio **without** lowering D-T output. None of the three
   measured here does that.

**The aneutronic tier is the other side of the same statement, and it already has its own spec.**
`M.aneutronic_reactor` declares 200 MW, 60 s and a 3000-unit box and carries **no ladder of any
kind**, so no lever above reaches it. Its ratio is **9.12 D-D reactors per heater** on the D-He3
mix — identical to the neutronic tier's per-heater figure, because a D-D reactor breeds tritium and
helium-3 in equal measure and both mixes are half isotope (#290). ADR 0038 decision 5 leaves it
where #52 put it; whether it moves is
[#422](https://github.com/trulsjo/realistic-fusion-refreshed/issues/422).

## Non-levers, measured so nobody reaches for them

| point | ratio | per heater | why |
|---|---|---|---|
| box ×2, `particles_per_unit` ÷2 | **94.70 — unchanged** | 4.56 | density unchanged at 1×10²⁰ m⁻³ |
| box ×4, `particles_per_unit` ÷4 | **94.70 — unchanged** | 2.28 | same |
| `capture_efficiency` at its top rung | **unchanged** | unchanged | breeds 0.137012 u/s either way |

**Rescaling `particles_per_unit` against the box is invariant on one reading and cosmetic on the
other.** Both sides of the per-saturated-reactor ratio are counted in fluid units, so scaling what a
unit *means* cancels exactly. The per-heater reading does move — a heater's rate is a recipe in
units while breeding is computed in nuclei — but the plant produces identically and only the numbers
on the pipes change. It also contradicts the one-nuclei-per-unit decision `reactor-logic.lua` states
twice. **Recorded as a non-lever**, not as a cheap win.

**Plant efficiency moves megawatts and not the chain.** `capture_efficiency` reaches `step()` as an
argument rather than as a spec field (ADR 0020 decision 5) and scales what a reactor *sells*: 61.9
MW against 56.1 at the top rung. Neither end of the ratio is an energy figure, so the ratio cannot
move. Measured rather than argued, because *"it obviously does not"* is how a lever gets left out of
a sweep.

## What this note cannot see

It reads one Lua module. **Nothing here says whether a plant plays.** That question is answered in
running games and not in this note: `scripts/check-heating.ps1` measures the draw, the temperature
and the breeding order at four research states, and `scripts/check-breeding.ps1` runs a
**fully-researched** reactor with a collector plumbed into ordinary storage tanks and watches both
by-products arrive. What neither shows is an **rf-heater** keeping up with a researched reactor, or
an exchanger draining one — those are
[#440](https://github.com/trulsjo/realistic-fusion-refreshed/issues/440) and
[#315](https://github.com/trulsjo/realistic-fusion-refreshed/issues/315), and they are open.

It also cannot see the recipes. The per-heater column rests on the mix a heater draws having the
same composition as the plasma it makes; Core's `rf-d-t-mixing` is a prototype and this runs outside
Factorio. `tests/test-reactor-logic.lua` records the same gap beside `HEATER_TRITIUM`.
