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

**That table is the held reactor.** One heater's plant is the fed one, and it reads one heating rung
further and the whole confinement ladder covered — see
[What that does to coverage, on one heater](#what-that-does-to-coverage-on-one-heater).

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
The thirteen states below — each ladder walked alone, and the two corners — are read three ways,
and **the game settles at the fed model in all thirteen**: to within 0.07% in plasma temperature
at twelve, and 0.19% at the top corner.

**Three readings, one method each.**

- **Game, long.** `bench-mod-links.ps1 -Heaters 1 -Ticks 600000 -Window 30000`, with
  `-Rungs <ladder>=<n>`, `-Unresearched`, or neither for the top corner. It runs a D-D reactor with
  four exchangers, so the reactor and not the row is what limits. Factorio 2.0.77 (build 84539),
  2026-10-03. Quoted at the last report, 570 000 ticks. Nothing researched and confinement rung 2
  ran 900 000 ticks at the same window and are quoted at 870 000. Every run passed the bench's
  equilibrium gate. **Each MW figure is a bracket, not a number.** The bench's *sustained* column
  divides by every tick and so undercounts the tick the reactor writes energy on. Its *while
  flowing* column assumes that tick carried the mean. The truth is between them.
- **Fed model.** `M.settle_fed`. The box starts empty, and one heater's 2.5 u/s arrives at the
  recipe's 1×10⁶ °C and is mixed in by amount, never past 1000. It is stepped every 6 ticks, as
  `control.lua` steps the reactor, for 7200 s. **1200 s is not enough here**: it leaves
  confinement rung 3 at 5.455×10⁸ °C and the top corner at 622.1 units, where 3600 s and
  14 400 s agree with 7200 to four figures. MW is what the last step sells, after capture. u/s is
  what it burns.
- **Held model.** `M.settle` at a full box, 1200 s at one tick: the grid above.

| research state | game, long: MW | held | °C | fed model: held | °C | MW | u/s | held model |
|---|---|---|---|---|---|---|---|---|
| **nothing researched** | 48.3 – 58.0 | 999.9 | 2.382e8 | 1000 | 2.381e8 | 55.3 | 0.531 | 56.1 at 2.422e8 |
| heating rung 1, 55 MW | 55.3 – 66.4 | 999.9 | 2.764e8 | 1000 | 2.763e8 | 63.3 | 0.693 | 64.7 at 2.829e8 |
| heating rung 2, 60 MW | 62.6 – 75.2 | 999.9 | 3.159e8 | 1000 | 3.159e8 | 71.7 | 0.870 | 73.7 at 3.257e8 |
| heating rung 3, 65 MW | 70.1 – 84.1 | 999.9 | 3.563e8 | 1000 | 3.562e8 | 80.2 | 1.058 | 83.2 at 3.701e8 |
| heating rung 4, 70 MW | 77.7 – 93.2 | 999.9 | 3.971e8 | 1000 | 3.970e8 | **88.9** | 1.253 | 92.9 at 4.158e8 |
| heating rung 5, 75 MW | 85.3 – 102.4 | 999.9 | 4.380e8 | 1000 | 4.379e8 | **97.6** | 1.453 | 102.9 at 4.623e8 |
| confinement rung 1, 40 s | 56.1 – 67.4 | 999.9 | 3.259e8 | 1000 | 3.258e8 | 64.2 | 0.916 | 67.1 at 3.413e8 |
| confinement rung 2, 50 s | 65.6 – 78.7 | 999.9 | 4.258e8 | 1000 | 4.258e8 | 75.0 | 1.393 | 82.9 at 4.727e8 |
| confinement rung 3, 60 s | 76.0 – 91.1 | 999.8 | 5.342e8 | 1000 | 5.341e8 | **86.9** | 1.932 | 104.9 at 6.483e8 |
| plant efficiency rung 1, 0.9 | 51.2 – 61.4 | 999.9 | 2.383e8 | 1000 | 2.381e8 | 58.5 | 0.531 | 59.4 at 2.422e8 |
| plant efficiency rung 2, 0.925 | 52.6 – 63.1 | 999.9 | 2.383e8 | 1000 | 2.381e8 | 60.1 | 0.531 | 61.1 at 2.422e8 |
| plant efficiency rung 3, 0.9375 | 53.3 – 64.0 | 999.9 | 2.383e8 | 1000 | 2.381e8 | 60.9 | 0.531 | 61.9 at 2.422e8 |
| **every ladder at its top** | 109.0 – 130.8 | 623.8 | 1.462e9 | 625.0 | 1.460e9 | 124.7 | 2.500 | 211.2 at 1.183e9 |

**Where the game sits, row by row: at the fed model, in every row.** The fed model's MW is inside
the game's bracket in all thirteen. In plasma temperature the game runs 0.013% to 0.036% over the
fed model in the nine rows that move heating or confinement, or move nothing. The three
plant-efficiency rows run 0.062% over, at 570 000 ticks. The nothing-researched row read the same
2.383×10⁸ at 570 000 ticks and 2.382×10⁸ at 870 000, so those three look like the same slow tail.
The top corner runs 0.19% over at 0.19% less plasma. Its box never fills, so its pipes stay in the
reactor's pool and hold hot plasma the fed model does not count. The held model is never inside
0.07%: it runs 1.7% to 21% hot in the twelve full-box rows, and its MW is outside the bracket at
heating rung 5, at confinement rungs 2 and 3, and at the top corner. Plant efficiency moves only what is sold, so its
three rows hold the unresearched temperature.

**The top corner is the one measured row a heater cannot keep full**, at 623.8 units against the
fed model's 625.0, burning all 2.5 u/s. Of the twenty-four heating × confinement cells, the fed
model leaves six part-full and burning 2.5 u/s: confinement rung 2 at heating rungs 4 and 5, and
confinement rung 3 at heating rungs 2 to 5. Plant efficiency never touches the plasma, so that is
**twenty-four of the ninety-six states supply-limited on one heater**. Every other cell keeps its
box full and burns at most 2.466 u/s. This replaces the earlier candidate split, which counted
forty-four states off the settled point on one heater. That split read the held model's demand,
and the held model is not the plant.

### What the earlier readings were

#440 (nothing researched and the top corner, 2026-10-01) and
[#485](https://github.com/trulsjo/realistic-fusion-refreshed/issues/485) (the eleven single-ladder
rows, 2026-10-02) measured the same rig on Factorio 2.0.77. Nothing researched was read after
126 000 ticks, and the top corner after a tick count not on record. Of #485's eleven, ten were
read after 126 000 ticks and passed the bench's equilibrium gate there: heating rungs 1 to 5,
confinement rungs 1 and 2, and plant efficiency rungs 1 to 3. Confinement rung 3 had not settled
at 126 000 ticks and was quoted from a 360 000-tick run that had. **Every row but that one was read
mid-transient.** Their plasma temperatures, against the long runs above:

| research state | °C, earlier | °C, long | earlier over long |
|---|---|---|---|
| nothing researched (#440), 126 000 ticks | 2.412e8 | 2.382e8 | +1.3% |
| heating rungs 1 / 2 / 3 / 4 / 5, 126 000 ticks | 2.808 / 3.220 / 3.647 / 4.085 / 4.541 e8 | 2.764 / 3.159 / 3.563 / 3.971 / 4.380 e8 | +1.6 / +1.9 / +2.4 / +2.9 / +3.7% |
| confinement rungs 1 / 2, 126 000 ticks | 3.361 / 4.617 e8 | 3.259 / 4.258 e8 | +3.1 / +8.4% |
| confinement rung 3, 360 000 ticks | 5.349e8 | 5.342e8 | +0.1% |
| plant efficiency rungs 1 – 3, 126 000 ticks | 2.412e8 each | 2.383e8 each | +1.2% |
| every ladder at its top (#440), ticks not on record | 1.488e9, 611.6 units | 1.462e9, 623.8 units | +1.8% |

Those readings sat between the held and fed models, which is what #501 found at four of them and
could not explain. **The gate passed them because the reactor was cooling too slowly to fail it.**
Nothing researched moved 0.055% between its last two windows at 126 000 ticks, against a 1%
tolerance. Its fuel line was still cooling, and the next section shows it.

### The fuel line, measured

[#503](https://github.com/trulsjo/realistic-fusion-refreshed/issues/503). The bench's report now
prints a fuel-line trace: the temperature in the metered heater's plasma output, in each pipe of
the run and in the reactor's box, each with its fluid segment id. The pipes and the reactor are
read on each window's last tick. The heater is its last non-empty reading in the window, because
its box drains the tick it fills. The trace gates nothing. Quoted here: the 870 000-tick runs
above, nothing researched and confinement rung 2, one heater, three pipes, D-D, Factorio 2.0.77,
2026-10-03, 30 000 ticks a window. A 126 000-tick pair at 6 000 a window, run the same day, gave
the same readings at the ticks both report.

- **The heater makes plasma at 1×10⁶ °C**, the recipe's `temperature`, at every window of both
  runs. Its box reports no segment id. #499 and #501 mixed the fuel in at 15 °C; at 1×10⁶ °C the
  fed model moves by under 0.05%.
- **While the box fills, the pipes run at the reactor's temperature**, in its segment. Nothing
  researched at 60 000 ticks: 3.344×10⁸ °C in all three pipes, 3.344×10⁸ in the reactor.
- **Once the box is full, the pipes cool toward the heater's 1×10⁶ °C, and the reactor follows.**
  The plasma left in the pipes when the box filled is what the reactor draws next. So the fuel
  arrives far warmer than the heater made it, for hundreds of thousands of ticks.

| state, ticks | pipes, °C | reactor, °C |
|---|---|---|
| nothing researched, 90 000 (box full from 72 000) | 2.193e8 | 2.419e8 |
| nothing researched, 120 000 | 1.780e8 | 2.412e8 |
| nothing researched, 870 000 | 2.05e6 | 2.382e8 |
| confinement rung 2, 120 000 (box full from 114 000) | 3.497e8 | 4.617e8 |
| confinement rung 2, 870 000 | 1.0006e6 | 4.258e8 |

The 90 000- and 120 000-tick rows come from the 6 000-tick windows of the shorter pair, because a
30 000-tick window does not land on the moment the box fills.

**So yes: the fuel was warmer than the heater makes it, and by a lot.** At 120 000 ticks, the last
report before the 126 000-tick readings above, it reached the reactor at 1.78×10⁸ °C unresearched
and 3.50×10⁸ °C at confinement rung 2. That is 178 and 350 times the heater's 1×10⁶ °C. By
870 000 ticks it arrives at 2.05× the heater's temperature unresearched and within 0.06% of it at
rung 2. The hot inventory comes from the fill, so it should scale with the length of the pipe run.
Only this rig's three pipes were measured.

A D-T reactor on one heater never fills, at 277.3 units, so its pipes should stay in the
reactor's pool, as the top corner's do. That was not measured here, and the fed model's match there
(`d-t-ignition.md`) does not depend on it.

### What that does to coverage, on one heater

The coverage map and the grid above are the held model, and they stay so. **On one heater the plant
is the fed reactor.** Walked alone from the shipped state, its readings are:

| ladder | first rung NOT covered on the fed model | the game's bracket there |
|---|---|---|
| **heating** | **rung 5**, 97.6 MW. Rung 4 is 88.9 | rung 4 77.7 – 93.2 and rung 5 85.3 – 102.4, both straddling 90 |
| **confinement** | *none*. Rung 3 is 86.9 | rung 3 76.0 – 91.1, straddling 90 |
| **plant efficiency** | *none*. 60.9 at most | 64.0 at most |

So one heater's plant is covered one heating rung further than the held grid says, and through
the whole confinement ladder. The bracket alone decides neither heating rung 4 nor confinement
rung 3, because both straddle 90; the fed model's figure inside each bracket is the reading.
Whether 90 should move is still #315.

**The eighty-three states still unmeasured on a fuel line** are every state with two or more
ladders researched, less the top corner: ninety-six, less the unresearched corner, the eleven
single-ladder states and the far corner. The fed model reads all of them, and it has matched the
game at all thirteen measured.

## What this does not cover

- **THE FED REACTOR, measured at thirteen of ninety-six states** — see
  [The fed reactor, one heater](#the-fed-reactor-one-heater) above. Every figure outside that
  section is the held reactor on the pure model.
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
  the spec), `M.settle`, `M.settle_fed` for the fed reactor, and `M.density_curve` for the fill
  resolution. The grid was computed with the capture rung written into the spec's own
  `capture_efficiency` rather than passed as the `capture` argument `M.settle` forwards to
  `M.step`. `M.step` falls back to the spec field, so the two routes compute the identical number,
  and passing the argument is the route ADR 0020 decision 5 asks for. The fed-reactor section
  passes it.
- `tests/test-reactor-logic.lua` — `sells_mw` and the block under *WHAT ONE EXCHANGER COVERS, ON ALL
  THREE LADDERS*, which pins the boundary cells quoted above. The interior of the grid is not pinned
  and is cited from this note.
- `realistic-fusion-refreshed/prototypes/entities.lua` — `exchanger.energy_consumption` and the
  sizing argument above it.
- #227 (the 90 MW), #395 (the plant-efficiency lever), #425 and ADR 0038 (the heating ladder), #432
  (this measurement), #315 (whether the capacity moves).
