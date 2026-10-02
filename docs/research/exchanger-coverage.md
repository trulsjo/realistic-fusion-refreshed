# What one heat exchanger covers, across all three research ladders

**Measured 2026-09-20 on the pure simulation** — `realistic-fusion-refreshed/scripts/reactor-logic.lua`
through `M.settle`, box full and never starved, settled 1200 s at one tick, fills swept at the 5%
resolution `M.density_curve` uses. No game is started: every figure here is the model's, and the
model is what `tests/test-reactor-logic.lua` pins.

**What it answers.** `rf-heat-exchanger` declares `energy_consumption = "90MW"`, chosen under
[#227](https://github.com/trulsjo/realistic-fusion-refreshed/issues/227) on 2026-09-10 against a
reactor with one research ladder. There are three now, all per force and all independent, and two of
them arrived after the capacity was chosen:

| ladder | what it moves | rungs | ADR |
|---|---|---|---|
| confinement | `confinement_time_s`, 30 → 60 s | 3 | 0024 |
| plant efficiency | `capture_efficiency`, 0.85 → 0.9375 | 3 | 0020 |
| plasma heating | `heating_power_w`, 50 → 75 MW | 5 | 0038 |

So "what one exchanger covers" is a question about a 4 × 4 × 6 grid of research states, at two
operating points each — full supply and the density optimum ADR 0016 makes a player lever. This note
is that grid. **It decides nothing**: whether the 90 MW should move is
[#315](https://github.com/trulsjo/realistic-fusion-refreshed/issues/315) and it is Truls's call.

**Why it exists as a note rather than as more comment.** Two tickets found the same sentence in
`realistic-fusion-refreshed/prototypes/entities.lua` false for two different reasons —
[#395](https://github.com/trulsjo/realistic-fusion-refreshed/issues/395) on the plant-efficiency
lever and [#432](https://github.com/trulsjo/realistic-fusion-refreshed/issues/432) on the heating
one — and the answer to both is a grid rather than a longer sentence. The comment keeps the
BOUNDARY, which is pinned; the interior lives here and is cited.

## The coverage map

One exchanger against one reactor, at 90 MW:

```
                               50   55   60   65   70   75   MW of heating
  capture 0.85   tau 30 s      ok   ok   ok   ok   X    X
                     40 s      ok   ok   X    X    X    X
                     50 s      ok   X    X    X    X    X
                     60 s      X    X    X    X    X    X
  capture 0.9    tau 30 s      ok   ok   ok   ~    X    X
                     40 s      ok   ok   X    X    X    X
                     50 s      ~    X    X    X    X    X
                     60 s      X    X    X    X    X    X
  capture 0.925  tau 30 s      ok   ok   ok   X    X    X
                     40 s      ok   ~    X    X    X    X
                     50 s      X    X    X    X    X    X
                     60 s      X    X    X    X    X    X
  capture 0.9375 tau 30 s      ok   ok   ok   X    X    X
                     40 s      ok   ~    X    X    X    X
                     50 s      X    X    X    X    X    X
                     60 s      X    X    X    X    X    X
```

`ok` — covered at full supply *and* at the density optimum. `~` — covered at full supply and not at
the optimum, so a player who tunes density outruns the machine and a player who does not, does not.
`X` — covered at neither.

**Twenty of the ninety-six cells are `ok`, four are `~`, and seventy-two are `X`.** The shipped
corner is the top-left one and it is comfortable; every direction out of it runs out of exchanger,
and the heating axis runs out fastest.

### Walking each ladder on its own, from the shipped state

This is the part the `entities.lua` comment pins, because it is the part a reader needs before
deciding anything:

| ladder walked alone | last rung one exchanger covers | first rung it does not |
|---|---|---|
| **heating** | rung 3, 65 MW — 83.2 MW full, 86.3 tuned | rung 4, 70 MW — **92.9** full, **95.1** tuned |
| **confinement** | rung 2, 50 s — 82.9 MW full, 88.7 tuned | rung 3, 60 s — **104.9** full, **107.6** tuned |
| **plant efficiency** | rung 3, the whole ladder — 61.9 MW full, 68.0 tuned | *none — this ladder never reaches 90 on its own* |

**The heating ladder is the new one and it is the sharp one.** Before ADR 0038 a reactor could only
outgrow its exchanger by researching confinement; now four rungs of heating do it with confinement
untouched, and a player meets those rungs earlier.

**Plant efficiency never breaks it alone, and that is worth stating in that direction.** #395 reports
this ladder falsifying the old sentence, and it does — but only in company. The cell that ticket
names is confinement rung 2 with plant-efficiency rung 1, tuned: **93.9 MW** at this sweep's own
80% argmax and **93.8 MW** at the 85% fill ADR 0024 tabulates as rung 2's optimum, which is #395's
figure reproduced, against 87.8 MW at full supply. It is not the only such cell. All four `~` in the
map are cells plant efficiency pushed over: (0.9, τ30, 65 MW) at 91.3 tuned against 88.1 full;
(0.9, τ50, 50 MW), which is #395's own; (0.925, τ40, 55 MW) at 91.4 against 86.1; and
(0.9375, τ40, 55 MW) at 92.7 against 87.3.

### And the far corner

Every ladder at its top is **211.2 MW at full supply**, which is **2.35 exchangers** — two of these
machines and a third one a third used. That is the size of the gap #315 would have to close, and the
reason the answer there cannot be "put the number up a bit".

## The grid

Each cell is **full supply / density optimum**, in MW. **Bold is over 90.** The optimum's own fill is
in the sweep and not reproduced here; it walks from 65% at the shipped corner to 100% wherever the
curve has no interior peak left, which is the behaviour `M.density_curve`'s note describes.

**Confinement rung 2's tuned cell reads 88.7 here and 88.6 in the suite, and both are right.**
`tests/test-reactor-logic.lua` pins **88.6 MW** at the 85% fill ADR 0024 tabulates as that rung's
optimum; this sweep's 5% grid puts its argmax at 80% and reads **88.7**; a 1% grid puts the true
peak at 82% and reads **88.8**. The 88.7 in the table above is the argmax, because that is what every
other cell in the table is. Until #441 (2026-10-01) the suite pinned 88.8 at 85% — the peak's
figure at the tabulated fill, which the model had never produced there — and this paragraph is
where the 0.2 MW gap was first written down.

#### capture 0.85 — shipped, nothing researched

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 56.1 / 61.6 | 64.7 / 69.5 | 73.7 / 77.8 | 83.2 / 86.3 | **92.9** / **95.1** | **102.9** / **104.1** |
| **40 s** | 67.1 / 73.7 | 79.1 / 84.0 | **91.8** / **94.9** | **104.7** / **106.3** | **117.7** / **118.2** | **130.7** / **130.7** |
| **50 s** | 82.9 / 88.7 | **99.4** / **102.2** | **115.9** / **116.7** | **132.0** / **132.0** | **147.3** / **147.3** | **162.0** / **162.0** |
| **60 s** | **104.9** / **107.6** | **125.1** / **125.1** | **143.7** / **143.7** | **160.9** / **160.9** | **176.8** / **176.8** | **191.5** / **191.5** |

#### capture 0.9 — `rf-plant-efficiency-1`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 59.4 / 65.2 | 68.5 / 73.6 | 78.1 / 82.3 | 88.1 / **91.3** | **98.4** / **100.7** | **108.9** / **110.3** |
| **40 s** | 71.0 / 78.0 | 83.8 / 89.0 | **97.1** / **100.5** | **110.9** / **112.5** | **124.6** / **125.1** | **138.3** / **138.3** |
| **50 s** | 87.8 / **93.9** | **105.2** / **108.2** | **122.7** / **123.5** | **139.7** / **139.7** | **156.0** / **156.0** | **171.5** / **171.5** |
| **60 s** | **111.0** / **113.9** | **132.4** / **132.5** | **152.2** / **152.2** | **170.4** / **170.4** | **187.1** / **187.1** | **202.8** / **202.8** |

#### capture 0.925 — `rf-plant-efficiency-2`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 61.1 / 67.1 | 70.4 / 75.7 | 80.3 / 84.6 | **90.5** / **93.9** | **101.1** / **103.5** | **111.9** / **113.3** |
| **40 s** | 73.0 / 80.2 | 86.1 / **91.4** | **99.8** / **103.2** | **113.9** / **115.6** | **128.1** / **128.6** | **142.2** / **142.2** |
| **50 s** | **90.2** / **96.6** | **108.2** / **111.2** | **126.1** / **127.0** | **143.6** / **143.6** | **160.3** / **160.3** | **176.3** / **176.3** |
| **60 s** | **114.1** / **117.0** | **136.1** / **136.1** | **156.4** / **156.4** | **175.1** / **175.1** | **192.3** / **192.3** | **208.4** / **208.4** |

#### capture 0.9375 — `rf-plant-efficiency-3`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 61.9 / 68.0 | 71.4 / 76.7 | 81.3 / 85.8 | **91.7** / **95.2** | **102.5** / **104.9** | **113.4** / **114.9** |
| **40 s** | 74.0 / 81.3 | 87.3 / **92.7** | **101.2** / **104.6** | **115.5** / **117.2** | **129.8** / **130.4** | **144.1** / **144.1** |
| **50 s** | **91.4** / **97.9** | **109.6** / **112.7** | **127.8** / **128.7** | **145.5** / **145.5** | **162.5** / **162.5** | **178.7** / **178.7** |
| **60 s** | **115.7** / **118.6** | **137.9** / **138.0** | **158.5** / **158.5** | **177.5** / **177.5** | **194.9** / **194.9** | **211.2** / **211.2** |

### The shape of it, on one axis at a time

From the shipped corner, what each ladder is worth alone, at full supply, against the 90 MW line:

```
                                  0              30             60             90             120  MW
                                  |--------------|--------------|--------------|--------------|
shipped, nothing researched       ############################                                  56.1
plant efficiency, whole ladder    ###############################                               61.9
confinement rung 2                #########################################                     82.9
heating rung 3                    ##########################################                    83.2
heating rung 4                    ##############################################                92.9
confinement rung 3                ####################################################          104.9
all three ladders at their tops   ############################################################>  211.2
                                                                               ^ 90 MW, one exchanger
```

The three ladders are drawn against the same line and not against each other: they multiply, they do
not add, and the grid above is where a combination is read rather than guessed at from this picture.

## The fed reactor, one heater

Every figure above is a settled reactor on the pure model: box full, never starved. A player's
reactor is fed by an `rf-heater`, and **one heater is the plant this note's 90 MW is sized on.**
#440 measured that plant at two states and
[#485](https://github.com/trulsjo/realistic-fusion-refreshed/issues/485) at eleven more — each
ladder walked alone from the unresearched state — so thirteen of the ninety-six are now read off a
fuel line. All thirteen: `bench-mod-links.ps1 -Heaters 1`, a D-D reactor, four exchangers so the
reactor and not the row is what limits, Factorio 2.0.77 (build 84539). #440's two on 2026-10-01,
the rest on 2026-10-02 with `-Rungs <ladder>=<n>`, which asserts every rung of all three ladders and
prints them with the result.

**Each figure is a bracket, not a number.** The bench's *sustained* column divides by every tick and
so undercounts the tick the reactor writes energy on; its *while flowing* column assumes that tick
carried the mean. The truth is between them. **Settled** in the last column means the fed reactor
is at the settled point — box full, plasma within 2.5% of the model's settled temperature, and the
model's full-supply figure (the grid above) inside the bracket.

| research state | sustained – while flowing | plasma held | plasma °C | model, full supply | settled? |
|---|---|---|---|---|---|
| **nothing researched** (#440) | 48.9 – 58.6 MW | 999.9 / 1000 | 2.412e8 | 56.1 MW at 2.422e8 | **yes** |
| heating rung 1, 55 MW | 56.2 – 67.4 MW | 999.9 | 2.808e8 | 64.7 at 2.829e8 | yes |
| heating rung 2, 60 MW | 63.8 – 76.6 MW | 999.9 | 3.220e8 | 73.7 at 3.257e8 | yes |
| heating rung 3, 65 MW | 71.7 – 86.1 MW | 999.9 | 3.647e8 | 83.2 at 3.701e8 | yes |
| heating rung 4, 70 MW | 80.0 – **95.9** MW | 999.9 | 4.085e8 | **92.9** at 4.158e8 | yes |
| heating rung 5, 75 MW | 88.5 – **106.3** MW | 999.8 | 4.541e8 | **102.9** at 4.623e8 | yes |
| confinement rung 1, 40 s | 57.8 – 69.4 MW | 999.9 | 3.361e8 | 67.1 at 3.413e8 | yes |
| confinement rung 2, 50 s | 71.0 – 85.2 MW | 999.8 | 4.617e8 | 82.9 at 4.727e8 | yes |
| confinement rung 3, 60 s | 76.1 – **91.3** MW | 999.8 | 5.349e8 | **104.9** at 6.483e8 | **no** |
| plant efficiency rung 1, 0.9 | 51.7 – 62.1 MW | 999.9 | 2.412e8 | 59.4 at 2.422e8 | yes |
| plant efficiency rung 2, 0.925 | 53.2 – 63.8 MW | 999.9 | 2.412e8 | 61.1 at 2.422e8 | yes |
| plant efficiency rung 3, 0.9375 | 53.9 – 64.7 MW | 999.9 | 2.412e8 | 61.9 at 2.422e8 | yes |
| **every ladder at its top** (#440) | 107.5 – 129.0 MW | 611.6 / 1000 | 1.488e9 | 211.2 at 1.183e9 | **no** |

Every row taken on 2026-10-02 passed the bench's equilibrium gate at 126 000 ticks except
confinement rung 3, which had not settled there and is quoted from a 360 000-tick run that did. Of
#440's two rows, nothing researched was read after 126 000 ticks —
`realistic-fusion-refreshed/prototypes/entities.lua` records the run in its comment headed
"MEASURED, AND IT IS NOT 86" — and the tick count of the every-ladder-at-its-top row is not on record.
The model column is `M.settle` at the same state, 1200 s at one tick.

**What each ladder does, walked alone:**

| ladder | first rung NOT at the settled point | first rung one 90 MW exchanger does not cover |
|---|---|---|
| **heating** | *none* — all five rungs hold it | **rung 4** on the model's reading; the bracket alone straddles 90 at rungs 4 and 5 |
| **confinement** | **rung 3** | *none measured* — rung 3's bracket straddles 90, 76.1 to 91.3 |
| **plant efficiency** | *none* | *none* — 64.7 MW at most |

**Heating never moves the fed reactor off the settled point**, so for that ladder the model's grid
IS the one-heater plant, and the bracket agrees with it at every rung. That is what makes rung 4 the
answer on coverage: the bracket by itself cannot decide — 80.0 to 95.9 straddles 90, and so does
rung 5's 88.5 to 106.3 — but the model's 92.9 sits inside it at a temperature the fed reactor
matches to 1.8%, so 92.9 is the reading.

**Confinement rung 3 is the first single-ladder state the fed reactor does not reach the settled
point at, and why is not established.** What the bench shows: a full box (999.8) at **5.349e8 °C, 17.5% colder than the model's
6.483e8**, selling 76.1 to 91.3 MW where the settled reactor sells 104.9. The 126 000-tick run of
the same state failed the equilibrium gate, its last report at 865.0 units and 6.98e8 °C.

**The box filled once and never drained** (#496). The bench's window trace now prints plasma held
at every window. Re-run on 2026-10-02 against Factorio 2.0.77, one heater, confinement rung 3 and
every other ladder off, 360 000 ticks at 6 000 a window, it climbs every window from 108.8 units
at the first report to 865.0 at 120 000 ticks — the reading the 126 000-tick run ended on, at the
same 6.980e8 °C — and is full, at 999.8, from 168 000 ticks on. The temperature falls the whole
way up, from 3.38e9 °C at the first report to 5.64e8 at 162 000 ticks, rises to 6.01e8 in the
window after the box fills, and sinks to 5.348e8, moving 0.02% across the last two windows.
Settled: 76.0 to 91.2 MW, the gate passed — a tenth under the table's 76.1 to 91.3, which is the
earlier 360 000-tick run. "Drained and refilled" is ruled out.

**A lead for [#497](https://github.com/trulsjo/realistic-fusion-refreshed/issues/497), not an
answer.** The model column holds the box full and never pays to heat incoming fuel. Fed instead —
one heater's 2.5 u/s arriving at 15 °C and mixed into the box by amount, the method
`d-t-ignition.md` gives for #499 — the model at rung 3 settles full at 5.339e8 °C, 86.9 MW,
burning 1.93 u/s, against this run's 5.348e8 and the bench's sustained plasma meter's 1.92. But
the same fed model runs confinement rung 2 7.8% cold (4.257e8 against the
game's 4.617e8 and the held model's 4.727e8), and the nothing-researched and heating rung 5 rows
also sit between the two models; the other nine rows were not run fed. So the rung-3 match does
not yet say the fuel sink is the cause, and nothing below is revised on it.

**The earlier candidate:** settled at 60 s the model's
reactor burns **2.509 units of plasma a second** and one heater makes **2.5** (`M.heater`, five
units every two seconds) — the first single-ladder state whose settled demand exceeds a heater;
heating rung 5 asks 1.574 and confinement rung 2 1.625. But a supply limit predicts a part-full box,
the top corner's shape, and this box is full; the bench's sustained plasma meter reads 1.92 u/s,
under the heater's 2.5. ~~though that meter excludes the ticks a craft lands on and undercounts~~
— the fed model's 1.93 u/s above reads the 1.92 as what the reactor burns rather than as an
undercount, though that rests on the same unvalidated lead. So the measurement and the demand
figure agree only on WHERE the settled point is lost, not on how.

**So whether one exchanger covers confinement rung 3 on one heater is not decided by this
measurement.** Its sustained bound is 13.9 MW under 90 and its flowing bound 1.3 MW over. The
settled reactor's 104.9 does not apply to a plant one heater feeds, and a second heater would put the
reactor back at it, which is the question #315 inherits.

**Plant efficiency changes nothing about the operating point**, as it should: it scales what is sold
and leaves the plasma alone, so all three rungs hold the unresearched 2.412e8 °C to four figures.

**The eighty-three states still unmeasured on a fuel line** are every state with two or more ladders
researched, less the top corner: ninety-six, less the unresearched corner, the eleven single-ladder
states and the far corner.

**The model's plasma demand gives a candidate split, and confinement rung 3 has not validated it.**
Settled plasma demand depends on heating and confinement only — plant efficiency never touches the
plasma — so it is a 6 × 4 table, and **eleven of its twenty-four cells ask more than 2.5 u/s**:
confinement rung 3 at every heating rung, rung 2 from heating rung 2 up, and rung 1 at heating rung
5 (2.692). Times four capture rungs, that is **forty-four of the ninety-six states predicted off the
settled point on one heater**, two of them measured (confinement rung 3 alone, and the top corner)
and forty-two not. The other forty-one unmeasured states ask 2.343 u/s or less. Both measured states
in the first group are off the settled point and all eleven measured in the second are on it, which
is consistent with the split and does not explain the mechanism above; read it as where to measure
next, not as a reading. The cases nearest the line — 2.509 here, 2.612 at heating 2 with
confinement 2 — are where it would be wrong first.

## What this does not cover

- **THE FED REACTOR, at thirteen of ninety-six states** — see
  [The fed reactor, one heater](#the-fed-reactor-one-heater) above. Every other figure in this note is
  the settled reactor on the pure model.
- **THE D-T TIER.** Only `rf-d-d-plasma`. A D-T reactor is a different sizing question and
  `rf-hc-exchanger` is the machine on the other end of it.
- **THE ANEUTRONIC TIER**, which needs nothing measured: no research ladder reaches it at all —
  `M.aneutronic_reactor` carries none of the three, which `tests/test-reactor-logic.lua` asserts
  through `L.has_spec_ladder(ANEUTRONIC)`, and the decisions behind that are ADR 0020 decision 4
  and ADR 0038 decision 5. So it has one state rather than ninety-six.
- **CHAINING.** What a second or third exchanger does when bolted onto the same reactor face is
  `docs/research/exchanger-chaining.md` and ADR 0031. This note counts machines, it does not plumb
  them.
- **WHETHER 90 SHOULD MOVE.** #315, and Truls's. This note re-anchors the claim about what the
  machine covers; it proposes no number.

## Sources

- `realistic-fusion-refreshed/scripts/reactor-logic.lua` — `M.reactor` (the three ladders live on
  the spec), `M.settle`, and `M.density_curve` for the fill resolution. The capture rung is written
  into the spec's own `capture_efficiency` rather than passed as `M.step`'s `capture` argument,
  because `M.settle` takes no such argument; `M.step` falls back to the spec field, so the two
  routes compute the identical number.
- `tests/test-reactor-logic.lua` — `sells_mw` and the block under *WHAT ONE EXCHANGER COVERS, ON ALL
  THREE LADDERS*, which pins the boundary cells quoted above. The interior of the grid is not pinned
  and is cited from this note.
- `realistic-fusion-refreshed/prototypes/entities.lua` — `exchanger.energy_consumption` and the
  sizing argument above it.
- #227 (the 90 MW), #395 (the plant-efficiency lever), #425 and ADR 0038 (the heating ladder), #432
  (this measurement), #315 (whether the capacity moves).
