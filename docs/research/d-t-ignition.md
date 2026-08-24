# D-T ignites, and what that costs

Measured 2026-08-17 while implementing
[#28](https://github.com/trulsjo/realistic-fusion-refreshed/issues/28). Everything here comes from
`scripts/reactor-logic.lua` driven at the shipped `M.reactor` constants, and from
`scripts/check-d-t.ps1` running the same reactors in Factorio 2.0.77.

The short version: **D-D settles and D-T does not.** That is the difference between the two tiers,
and it is a property of the cross-section data and the reactor's confinement, not a balance number
anyone chose.

## What the data says

Maxwellian-averaged reactivity ⟨σv⟩ in m³/s, from `cross-section-data/reactivities.lua`:

| Plasma temperature | D-D | D-T | ratio |
|---|---|---|---|
| 1×10⁷ K | 8.39×10⁻²⁹ | 2.70×10⁻²⁷ | 32× |
| 5×10⁷ K | 1.15×10⁻²⁵ | 7.87×10⁻²⁴ | 69× |
| 1×10⁸ K | 8.25×10⁻²⁵ | 7.65×10⁻²³ | **93×** |
| 3×10⁸ K | 7.98×10⁻²⁴ | 5.87×10⁻²² | 74× |
| 6×10⁸ K | 2.27×10⁻²³ | 8.73×10⁻²² | 39× |
| 1×10⁹ K | 4.26×10⁻²³ | 8.72×10⁻²² | 20× |
| 2×10⁹ K | 8.64×10⁻²³ | 6.82×10⁻²² | 7.9× |
| 5×10⁹ K | 1.76×10⁻²² | 3.99×10⁻²² | 2.3× |

D-T's advantage is largest *low down* and narrows as both curves approach their peaks. That is why
D-T is the **easier** reaction rather than merely the bigger one: it is what a reactor can still run
on where D-D has fallen off the bottom of its curve. Multiply through by 17.59 MeV against D-D's
mean 3.65 and the energy advantage is another 4.8×.

Two corrections apply before those numbers become a rate, and both are per-fuel rather than per-
reaction:

- **D-D is like-species.** Every nucleus in the box is both reactants, and each pair would otherwise
  be counted twice, so `reactivity.rate` carries a factor of one half. That was already there.
- **D-T is a mixture.** A fluid unit is a count of nuclei, and in an even blend each side sits at
  *half* the plasma's density — so the rate is a quarter of what feeding the whole density twice
  would give. This is what `M.fuels[...].fractions` is, added by #28. Getting it wrong quadruples
  the tier's output and nothing else in the model notices, which is why
  `tests/test-reactor-logic.lua` recomputes one rate straight from the dataset rather than asserting
  a ratio.

## The equilibrium that isn't

Run with the box kept full and unlimited power:

| | settles at | Q | thermal out | burn |
|---|---|---|---|---|
| ~~D-D, 20 min~~ | ~~8.77×10⁸ °C~~ | ~~2.14~~ | ~~133 MW~~ | ~~3.7 u/s~~ |
| **D-D, 20 min (#52)** | **2.42×10⁸ °C** | **0.32** | **56.1 MW** | 1.0 u/s |
| D-T, 1 min | 2×10⁹ °C — **the clamp** | 96 | 4 127 MW | 34 u/s |

D-D balances: heating plus alpha self-heating against the confinement loss, partway up the curve.
D-T does not. At n = 10²⁰ m⁻³ and τ_E = 30 s this reactor passes the Lawson criterion for D-T by
more than an order of magnitude, so the alpha heating alone outruns the loss term at every
temperature below the peak and the plasma climbs until something stops it.

Raising the ceiling to find out what: the model does have a real equilibrium, out past the peak
where the cross-section is falling.

| ceiling | settles at | Q | thermal out |
|---|---|---|---|
| 2×10⁹ °C (shipped) | 2×10⁹ (pinned) | 96 | 4 127 MW |
| 5×10⁹ °C | 4.63×10⁹ | 58.9 | 2 547 MW |
| 10¹⁰ °C | 4.63×10⁹ | 58.9 | 2 547 MW |
| 10¹¹ °C | 4.63×10⁹ | 58.9 | 2 547 MW |

**The shipped ceiling stays where it is.** One reason holds, and it is the second one below.

> **Corrected 2026-08-17.** This section originally gave two reasons "in order of weight", and led
> with the wrong one. Reason 1 as written — that the clamp is the less wrong physics because
> bremsstrahlung "would bite long before 4.6×10⁹" — was reasoning rather than arithmetic, and it does
> not survive being checked against the NRL Plasma Formulary. See
> [`bremsstrahlung.md`](bremsstrahlung.md), which does the arithmetic at this model's own operating
> point. What actually holds: bremsstrahlung moves the equilibrium to **3.26×10⁹ K**, not down near
> the clamp; the clamp sheds ~640 MW at 2×10⁹ where bremsstrahlung is 169 MW, so it cannot be
> standing in for it; and unreabsorbed cyclotron radiation at these temperatures is two to three
> orders larger, so bremsstrahlung is not even the dominant omission. The struck reason is left
> visible rather than deleted, because it is why the clamp was chosen and a reader will otherwise
> wonder.

1. ~~**The clamp is the less wrong physics, not the more wrong.** A real D-T plasma at this density
   radiates hard through bremsstrahlung — a loss going as n²√T that this zero-dimensional model does
   not carry at all — and it would bite long before 4.6×10⁹ K.~~ **Not supported; see above.** What
   remains true of it: energy is not invented at the clamp, because `step()` sells everything the
   plasma cannot hold. The clamp is a ceiling on the state variable, not on the accounting.
2. **It would cost the temperature circuit signal.** A signal is an int32 and Factorio throws rather
   than wraps; the ceiling stops at 2 147 483 647, so the shipped 2×10⁹ fits with 7% to spare and
   4.6×10⁹ does not (`scripts/circuit-output.lua`). **This is the whole of the case for the clamp.**

What it costs as it stands is that the temperature reading is **pinned at 2×10⁹ for every D-T
reactor**, whatever it is doing. That is a real loss of information and it is the one thing about
this tier worth revisiting.

~~Fixing it properly means a bremsstrahlung term~~ — **it does not.** A bremsstrahlung term lands the
D-T equilibrium at 3.26×10⁹ K, still 52% above the int32 ceiling, so it would not unpin the reading.
The levers that reach it are `confinement_time_s` (10 s puts D-T at 2.02×10⁹) or plasma purity
(`Z_eff ≈ 6`, with `Z_eff = 7` extinguishing the plasma entirely — a knife edge). Both re-tune D-D as
well, so both are balance decisions rather than fixes.

And the finding this section originally missed: **adding bremsstrahlung would break the tier that
works.** D-D falls from Q 2.14 to Q 0.32, 107 MW of fusion power to 16 MW, taking the fuel-chain
arithmetic below with it. That is the physics being right — a D-D plasma at 10²⁰ m⁻³ with 30 s of
confinement is genuinely nowhere near ignition, and the shipped tier only looks net positive because
the dominant radiative loss is absent from the model.

> **It landed 2026-08-21 (#52), and the prediction was exact** — Q 0.3205, 16.02 MW of fusion. One
> word needs care, though: the tier is *not* net negative. It still sells **56.1 MW against the 50 MW
> it draws**, because the radiated X-rays heat the first wall and that heat is recovered. So D-D fuses
> at a loss and sells at a small profit: below **scientific** break-even, above **engineering**
> break-even, which `CONTEXT.md` now distinguishes. Every figure in this note below this line is the
> radiation-free one unless it says otherwise.

## Ignition is a control change, not a runaway

The pinned temperature is not a stuck reactor. At the ceiling the reactor burns **exactly what it is
fed** and the output follows the fuel line:

| feed | D-T out | D-T burn | | D-D out |
|---|---|---|---|---|
| 2.5 u/s (one heater) | 324 MW | 2.5 u/s | | 86 MW |
| 5 u/s | 606 MW | 5 u/s | | 103 MW |
| 10 u/s | 1 170 MW | 10 u/s | | |
| 20 u/s | 2 297 MW | 20 u/s | | |
| 40 u/s | 3 888 MW | 34 u/s — **fuel-saturated** | | |

So ignition removes temperature as a control input and hands the player a different throttle: the
fuel line. Below saturation the relationship is affine and very nearly proportional — doubling the
feed gives 1.87× the power, the shortfall being the 50 MW of confinement heating that is recovered
either way and does not double.

## Does the fuel chain support it?

Yes, and by a smaller margin than the raw power figures suggest — which is the point of a tier.

- A D-T reactor on one heater burns **2.5 u/s of plasma**, so 2.5 u/s of `rf-d-t-mix`, so
  **1.25 u/s of tritium**.
- A D-D reactor at its settling point burns 3.66 u/s of deuterium and breeds a quarter of that back
  as tritium: **0.92 u/s**.

**About 1.4 D-D reactors feed one D-T reactor.** Together that is 507 MW from 2.4 reactors, 214 MW
each, against 133 MW for a D-D reactor on its own — a 61% step for roughly a doubling of the
plumbing. Not a runaway, and not free.

> **Superseded for the blanketed case, 2026-08-17 (#30).** That ratio is the cost of the D-D
> by-product route, and it is now the *unblanketed* cost. A lithium blanket breeds 1.1 tritons per
> escaping neutron and a D-T reaction releases one neutron and burns one triton, so a blanketed D-T
> reactor breeds back more tritium than it burns and needs no D-D reactor upstream at all.
> Measured in game by `scripts/check-blanket.ps1`: 2 113 units of tritium over two minutes against
> a D-D reactor's 83.7 of by-product, and the ratio comes out at 1.1000 against the model's 1.1.
> The 1.4-reactor figure still describes a player who has not researched `rf-blanket-breeding`, and
> that is the progression rather than an obsolescence.

> **And the arithmetic above it is stale twice over — flagged 2026-08-24 (#53), not fixed.** It
> quotes 3.66 u/s of deuterium and 133 MW, which are **pre-#52** figures: that ticket re-anchored
> the equilibrium table further up this page and left this section alone, so the numerator moved
> and the ratio did not. #53 then made it **research-dependent** as well — D-D's by-products go
> from 0.137 to 0.627 u/s across the confinement ladder, 4.6x, so a researched player needs far
> fewer D-D reactors per D-T reactor than an unresearched one.
> 
> Left to #117 rather than re-picked here, because fixing it means **choosing an
> operating point** and the section does not currently hold one: it quotes a heater-limited D-T
> reactor (2.5 u/s) against a saturated D-D one, which are not the same kind of number. Deciding
> which the fuel chain should be quoted at is a balance question, and settling it as a side effect
> of a confinement ladder is exactly the drift this page exists to stop.

Balance is provisional here as everywhere in this repository, and this section is the first thing
that should move if it is retuned.

## In the game

`scripts/check-d-t.ps1`, 7 200 ticks, two identical reactors fed the same plasma temperature with
their output boxes drained each tick so the comparison is of throughput rather than of two
saturated buffers:

```
the reactor accepts D-T plasma through the box that used to be filtered to D-D  -- rf-d-t-plasma
and ignites: the plasma runs up to the top of its range and parks there  -- 2e+09 C against a ceiling of 2e+09
the D-D reactor beside it is unchanged  -- rf-d-d-plasma at 7.675e+08 C
both reactors sold energy over the run  -- D-T 4.709e+05 MJ, D-D 1.269e+04 MJ
D-T yields materially more than D-D at the same feed temperature  -- 37.1x  (3924 MW against 105.8 MW)
a D-T reactor breeds nothing, so its collector stays empty  -- 0 units in the collector bolted to it
the plasma heater turns Core's D-T mix into D-T plasma  -- 200 units of rf-d-t-plasma, status full_output
```

The D-D figure is 106 MW rather than the 133 MW above because two minutes is not twenty: that
reactor is at 7.7×10⁸ °C and still climbing. The D-T reactor reached its ceiling inside the first
minute and the run is measuring its steady state.

Negative-tested, each separately, by breaking the thing under test and confirming the rig said so:

- Putting `filter = "rf-d-d-plasma"` back on the reactor's input box → four failures, starting with
  the reactor holding nothing at all. This is the change most likely to be reverted by accident and
  the one that fails most quietly in a player's game.
- Giving D-T a `products` table copied from D-D → the bolted-on collector filled to 500 units.
- Deleting the D-T row from `M.fuels` → the mod refuses to load, naming the fluid
  (`check_every_plasma_burns`, added by #28 because removing the box filter is what made a plasma
  with no fuel row reachable in the first place).

## What ignition does to a brownout

The section above says ignition removes temperature as a control input. This one is the consequence
nobody had followed through, and it is the answer to
[#70](https://github.com/trulsjo/realistic-fusion-refreshed/issues/70): **ignition also removes the
reactor's dependence on its own power supply.** Confinement heating is what gets a D-T plasma *to* a
fusing temperature, not what keeps it at one, so a supply shortfall costs a lit D-T reactor output
slowly and costs its network nothing at all.

Outside Factorio, at the same density and the same temperature and with no power going in at all:

| | one step from 6×10⁸ °C | after five unpowered minutes |
|---|---|---|
| **D-T** | **rises** to 6.046×10⁸ | 2×10⁹ °C — the top of its range |
| **D-D** | falls to 5.998×10⁸ | 7.45×10⁴ °C — out of the fusing range entirely |

Three and a half orders apart, from the same starting point, on the same reactor. That is ignition,
and `tests/test-reactor-logic.lua` asserts it as a separation rather than as two values because both
move with the balance and the separation is the claim.

### In the game

`scripts/check-brownout.ps1` — eight cells, each a reactor with its own `rf-heater` on its own
electric network, run for **thirty minutes supplied**, fifteen minutes short, and five minutes after.
The full measurement, with graphs, is regenerated by `-Report` into
[`brownout-rig.md`](brownout-rig.md).

**Thirty minutes of settle, and that number was learned the hard way.** The rig first used five, on
the strength of the out-of-Factorio figure above — a reactor fed a continuous 2.5 units a second is
within a few percent of equilibrium by then. In the game it is at about a quarter of its output and
still climbing 40% a minute, so every percentage quoted against it was a ratio to a number on the way
up. The measured curve of `full`'s trailing-minute output: 86 MW at 300 s, 204 at 600, 277 at 900, 307
at 1200, 322 at 1800, 324 at 2100 and flat thereafter.

**The reason it is slow is the pipe, not the plasma.** The equilibrium the game reaches — 324 MW at
270 units — is the one the pure-Lua model predicts, to three figures. What the model has no concept of
is the feed line: a cell's plasma segment is the reactor's 1000-unit box *plus every `rf-pipe` between
it and the heater*, and the engine fills the whole segment rather than the box. The reactor's own box
therefore approaches its share of a much larger volume. The rig now asserts that `full` has stopped
climbing before the shortfall begins, so a settle too short to have converged fails the run instead of
quietly rebasing every figure in the report.

What it found, against that settled baseline:

- **A brownout is not a power cut, and the rig had to be built so.** `rf-reactor`'s energy source is
  `usage_priority = "secondary-input"` — *"used for all other machines"* in the 2.0.77 docs, the same
  bucket as `rf-heater` and the electrolysers. The engine gives every consumer on a network the same
  fraction, so the reactor is starved neither before its fuel line nor after it. Undersupplying a
  network that holds both is therefore the only faithful way to stage one.
- **Half supply is barely an event.** Cut to 27.6 MW against the 55.2 MW it was drawing, the cell
  stayed at 1.96×10⁹ °C with 191 units in the box and contributed **+178 MW net** across the
  shortfall — about half its lit output, for half its supply.
- **A total blackout is a slow decline, and the reactor fights it the whole way.** Fifteen minutes
  with no power at all left the plasma at 9.48×10⁸ °C with 93.5 units still in the box, still
  selling **15.3%** of its lit output — 49.5 MW — and **+123.6 MW net** across the shortfall, since
  it is no longer paying for heating either. Over the first minute of the blackout it was
  **+276.5 MW net**. The same blackout took the D-D cell to **0.44%** and 3.5×10⁶ °C.
- **There is no cut length that finishes it.** A reactor holding plasma sells that plasma's own loss
  whether or not any fusion is happening, so the output decays towards nothing and never arrives.
  The rig asked "when did it stop selling" first, got "still selling" from every cell, and was
  rewritten to measure the decay instead.
- **Recovery is unattended and, on this trajectory, free.** Supply restored and nothing else done,
  the reactor was back at the clamp inside five minutes — and **net positive throughout the climb**
  (+58.8 MW average). The cost that was expected here did not appear: the plasma never got thin
  enough to stop, and `capture_efficiency` sells what leaves it whether or not fusion put it there.
- **The one genuine drain had to be seeded by hand.** A reactor holding a charge too thin to carry
  itself — 2.5% of its box, injected cold, full power — runs at **−7.1 MW**. That is the only
  negative number the rig produces, it is a seventh of the heating rather than the whole of it, and
  **no cell reached that state by losing power**. Fifteen minutes of blackout left the D-T reactor
  far above it.
- **The loop closes without eating itself.** One cell is a whole plant: reactor, heater,
  `rf-hc-exchanger`, two `rf-hc-turbines` and a load bank, with the supply interface as a starter
  motor. Switched off, the plant carried its own confinement heating out of what that heating
  produced. Overloaded to 200 MW — past what it can make — it stayed at the clamp. The spiral was
  made to happen on purpose and did not.
- **A row behaves like a reactor.** Two reactors bridged by `rf-pipe` on one plasma pool took the
  same blackout with a temperature spread of 0.0% — 6.607×10⁸ °C each — and **+132.2 MW net**: they
  share the fall rather than one starving the other.
- **And the tier gap is wider than the first run suggested.** Off the same heater over the settle
  phase, D-T sold **4.45×** what D-D did; through the same blackout D-T kept 15.3% of its output
  against D-D's 0.44%, a factor of 35. The D-D cell is the one cell deliberately left unconverged —
  a plasma that never ignites climbs on temperature as well as density and would need far longer —
  which makes its own retained fraction an understatement, so the real gap is wider still.

### Two things the rig had to work out, for whoever writes the next one

Both are undocumented in the 2.0 API and both are silent when got wrong, which is the expensive kind.

- **`power_production` and `power_usage` on an `electric-energy-interface` are joules per tick.** A
  rig using watts runs on a sixtieth of the supply it meant to, and the symptom is a reactor that
  reports itself starved on a perfectly good map. Pinned in the rig against vanilla's own
  `steam-turbine`, whose `get_max_power_output()` reads 5.82 MW when multiplied by sixty.
- **A vanilla `electric-energy-interface` is also a very large battery, and zeroing its production
  does not cut anything.** It goes on discharging that buffer into the network as a tertiary source
  for minutes. The first run of the rig did exactly that and every cut cell reported numbers
  *identical* to the uncut one — which reads as the physics being insensitive to power rather than as
  a battery nobody had noticed. The interfaces now carry a fifth of a second of reserve, and the rig
  asserts that its three supply levels produce three different draws.
- **A long run gets attacked, and no other rig here is long enough to have found out.** The siblings
  run two minutes; this one runs fifty. A probe at that length died with *"LuaEntity API call when
  LuaEntity was invalid"* inside the rig's own statistics read — a cell's substation had been eaten,
  bought by the pollution of eight heaters and an exchanger. The rig now turns pollution and enemy
  expansion off, sets the surface peaceful and clears the nests before it builds, and checks every
  entity it measures through is still valid so that losing part of the rig reports itself instead of
  arriving as a stack trace.
- **Which `LuaFlowStatistics` category holds an electric network's consumption** is documented for
  neither `"input"` nor `"output"`. The rig derives it: whichever category puts a satisfied reactor's
  draw within a factor of three of its own declared `input_flow_limit` is consumption, and that
  calibration is asserted so a wrong reading cannot quietly become a net figure.
