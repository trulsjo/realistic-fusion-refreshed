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

**This map is the held reactor.** One heater's plant is the fed one, and twelve more of its
cells are `ok`: see [The fed map, all ninety-six states](#the-fed-map-all-ninety-six-states).

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
  what it burns. **Seven of its figures are pinned** (#509), in `tests/test-reactor-logic.lua`'s
  block *THE FED D-D REACTOR ON ONE HEATER*: nothing researched's 55.3 MW and 2.381×10⁸ °C,
  heating rung 4's 88.9 MW and rung 5's 97.6, confinement rung 3's 86.9, and the top corner's
  625.0 units burning 2.500 u/s. Those are the figures the coverage reading below turns on. The
  rest of the column is cited from this note.
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
and the held model is not the plant. Five cells either side of the fed model's line are measured
under [Five combination states, nearest the line](#five-combination-states-nearest-the-line), and
two more under [Two more combination states](#two-more-combination-states). All seven land where
it puts them.

### Repeated runs read the same

[#518](https://github.com/trulsjo/realistic-fusion-refreshed/issues/518). **The bench has no
run-to-run spread.** Two states were each run three times at the same arguments, on 2026-10-03,
Factorio 2.0.77 (build 84539), one heater, nothing researched, every run passing the gate:

| state | arguments | plasma held | °C | MW | read at |
|---|---|---|---|---|---|
| D-T | `-Plasma rf-d-t-plasma -Exchangers 8 -Heaters 1 -Unresearched -Ticks 600000 -Window 30000` | 275.6, three times | 2.193e9, three times | 282.1 – 338.5, three times | 570 000 ticks |
| D-D | `-Heaters 1 -Unresearched -Ticks 900000 -Window 10000` | 1000.0, three times | 2.382e8, three times | 48.3 – 58.0, three times | 890 000 ticks |

The spread of all three quantities is zero, in each state. The three D-T reports are the same
file, character for character: every window of the trace and every pipe of the fuel line, not
only the last. So are the three D-D reports, except for one line. One of them was created on a
different map and says so: 27 enemy entities removed where the other two say 14. Its 89 windows,
the last at 890 000 ticks, are the other two's.

**So a difference between two readings of one state is a difference between the runs**: their
length, their window, their arguments or the tree they ran on. An agreement quoted here at 0.02%
is not inside the noise, because there is none.

**The #486 and #510 D-T figures are not inside the spread, and #486's does not reproduce.** #486
read 277.3 units at 2.180×10⁹ °C after 252 000 ticks; #510 read 275.6 at 2.193×10⁹ after
600 000. #486's command is `-Plasma rf-d-t-plasma -Exchangers 8 -Heaters 1 -Unresearched -Ticks
252000`. Run again on 2026-10-03, Factorio 2.0.77, it reads **275.6 units at 2.193×10⁹ °C**,
282.1 – 338.5 MW, flat from 78 000 ticks. It reads the same on an export of `1df5855`, the
commit that recorded #486. What produced 277.3 and 2.180×10⁹ is not on record. The game's figure
is #510's, and the fed model's 276.9 units at 2.183×10⁹ °C is 0.5% over it in plasma and 0.5%
under it in temperature, not between two readings.

### What the earlier readings were

#440 (nothing researched and the top corner, 2026-10-01) and
[#485](https://github.com/trulsjo/realistic-fusion-refreshed/issues/485) (the eleven single-ladder
rows, 2026-10-02) measured the same rig on Factorio 2.0.77. Nothing researched was read after
126 000 ticks, and the top corner after a tick count not on record. Of #485's eleven, ten were
read after 126 000 ticks and passed the bench's equilibrium gate there: heating rungs 1 to 5,
confinement rungs 1 and 2, and plant efficiency rungs 1 to 3. Confinement rung 3 had not settled
at 126 000 ticks and was quoted from a 360 000-tick run that had. **The eleven read at 126 000
ticks were mid-transient**: nothing researched and #485's ten. The top corner read 1.8% hotter
than its long run too, but with no tick count on record it cannot be placed. Their plasma
temperatures, against the long runs above:

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
its box drains the tick it fills. Since #508 the bench's gate reads the pipes' last two windows
of it; the rest gates nothing. Quoted here: the 870 000-tick runs
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
rung 2. The hot inventory comes from the fill, and the next section measures how it scales with
the length of the pipe run.

#### A longer line cools slower and settles in the same place

[#511](https://github.com/trulsjo/realistic-fusion-refreshed/issues/511). Four pipe counts, each
`-Heaters 1 -Unresearched -Pipes <n> -Window 10000`: D-D, one heater, nothing researched,
Factorio 2.0.77 (build 84539), 2026-10-03. Three pipes ran `-Ticks 900000`, the others
`-Ticks 2000000`, and all four passed the gate. Ticks are to the 10 000-tick window. "Falls by e"
is the time the pipes' excess over the heater's 1×10⁶ °C takes to fall by a factor of e, fitted
between the tenth and fortieth windows after the box fills.

| pipes | segment capacity | box first full | pipes within 2× the heater's °C | falls by e in | reactor, last window | pipes, last window |
|---|---|---|---|---|---|---|
| 3 (default) | 1300 | 80 000 | 880 000 | 145 900 ticks | 2.38154e8 at 890 000 | 1.914e6 |
| 6 | 1600 | 90 000 | 1 080 000 | 179 200 | 2.38139e8 at 1 990 000 | 1.006e6 |
| 9 | 1900 | 90 000 | 1 270 000 | 212 300 | 2.38139e8 at 1 990 000 | 1.035e6 |
| 12 | 2200 | 100 000 | 1 470 000 | 245 500 | 2.38139e8 at 1 990 000 | 1.120e6 |

**The settled point does not move.** Six, nine and twelve pipes end on the same 2.38139×10⁸ °C,
0.002% over `M.settle_fed`'s 2.38135×10⁸, each at 1000.0 units and 48.3 – 58.0 MW. Three pipes
read 2.38154×10⁸ at 890 000 ticks with the line still at 1.9× the heater's temperature; the
six-pipe run read 2.38181×10⁸ at that tick and fell to the common figure later.

**The transient stretches by about 65 000 ticks a pipe**, measured to the 2× mark: 880 000 ticks
at three pipes, 1 470 000 at twelve. Four times the pipe takes 1.7 times as long, not four
times, because most of the hot inventory is not in the pipes. The reactor's box adds its own
1000 units to the capacity of the segment it joins, so the line's inventory is 1000 + 100 per
pipe. That is the "segment capacity" column, read from the bench's fuel-line trace on a short
run at each count.
[Why the box fills slower than the fed model](#why-the-box-fills-slower-than-the-fed-model)
measures it. The fall-by-e times are that capacity over the 0.5311 u/s the settled reactor
burns: 146 900, 180 800, 214 600 and 248 500 ticks, each within 1.3% of the fit.

**Three is the shortest line the rig builds.** `-Pipes 1` and `-Pipes 2` put the heater on top of
the reactor and the rig refuses them.

**A D-T reactor on one heater never fills, and its pipes stay at its own temperature**
([#510](https://github.com/trulsjo/realistic-fusion-refreshed/issues/510)). Measured with
`-Plasma rf-d-t-plasma -Exchangers 8 -Heaters 1 -Unresearched -Ticks 600000 -Window 30000`:
nothing researched, one heater, Factorio 2.0.77, 2026-10-03, passing the bench's gate including
its fuel-line check (#508). At 540 000 and 570 000 ticks alike the heater makes plasma at
1×10⁶ °C, the three pipes hold **2.1901×10⁹ °C** and the reactor **2.193×10⁹ °C at 275.6 units**,
all in one fluid segment, selling 282.1 – 338.5 MW across the bench's two bounds. The pipes sit
0.13% under the reactor. The D-D top corner's pipes, also in its pool, sit 0.07% under it
(1.461×10⁹ against 1.462×10⁹). The box held
275.6 units from 90 000 ticks on and never filled. The fed model reads 276.9 units at
2.183×10⁹ °C (`d-t-ignition.md`), 0.5% under this temperature. #486 quoted 277.3 units at
2.180×10⁹ °C for the same rig; its command reads this run's figures when repeated, see
[Repeated runs read the same](#repeated-runs-read-the-same).

### Confinement rung 3 on two heaters

[#497](https://github.com/trulsjo/realistic-fusion-refreshed/issues/497). #485 read this state
full but 17.5% colder than the held model, 5.349×10⁸ °C against `M.settle`'s 6.483×10⁸, the widest
gap of any single-ladder state. The fed model closes it: 5.341×10⁸ °C against the game's 5.342×10⁸
in the table above. The held model never pays to heat the arriving fuel up from the heater's
1×10⁶ °C; a fuel line always does. Left open was whether more plasma could reach the held point.
**It cannot.** `-Heaters 2 -Rungs confinement_ladder=3 -Ticks 600000 -Window 30000`, D-D,
confinement rung 3 and nothing else researched, two heaters, Factorio 2.0.77, 2026-10-03, passing
the bench's gate including its fuel-line check:

| ticks | 30 000 | 60 000 | 90 000 | 150 000 | 270 000 | 360 000 | 570 000 |
|---|---|---|---|---|---|---|---|
| plasma held | 775.2 | 999.8 | 999.8 | 999.8 | 999.8 | 999.8 | 999.8 |
| reactor, °C | 7.943e8 | 6.028e8 | 5.667e8 | 5.428e8 | 5.349e8 | 5.343e8 | 5.342e8 |

At 570 000 ticks the six pipes hold 1.011×10⁶ °C and the reactor sells **76.0 – 91.1 MW**. That is
the one-heater reading to every digit quoted: same temperature, same bracket. The box never drained
after it filled. #501's one-heater run filled it by 168 000 ticks; two heaters fill it by 60 000.
The fed model agrees, at 1000 units, 5.341×10⁸ °C and 86.9 MW on 5 u/s as on 2.5. A full box
takes only what it burns, 1.932 u/s, however much the line could bring. So the held model's
settled point is not where any fuel line settles at this rung.

### The default four-heater run, settled

[#527](https://github.com/trulsjo/realistic-fusion-refreshed/issues/527). The bench's default
invocation is D-D, four heaters, every ladder at its top, 126 000 ticks. #517 found it passes the
gate narrowly, with its twelve pipes at 4.2×10⁷ °C. Run long here: `-Ticks 2000000 -Window 20000`
and nothing else, so four heaters, twelve pipes, a 2200-unit segment, all eleven rungs asserted
held, Factorio 2.0.77 (build 84539), 2026-10-04, passing the gate. The last report is at
1 980 000 ticks.

| ticks | pipes, °C | reactor, °C |
|---|---|---|
| 120 000 | 4.183e7 | 9.173e8 |
| 240 000 | 2.262e6 | 9.086e8 |
| 260 000, first within 2× the heater's 1×10⁶ | 1.708e6 | 9.083e8 |
| 500 000 to 1 980 000, all 75 windows | 1.00069e6 | 9.080e8 to 9.083e8 |

| reading | plasma held | °C | MW |
|---|---|---|---|
| default length, 126 000 ticks (#517, 2026-10-03) | 999.6 | 9.173e8 | 142.6 – 171.1 |
| settled, 1 980 000 ticks | 999.6 | 9.083e8 | 141.0 – 169.3 |
| fed model, four heaters' 10 u/s, 7200 s, capture 0.9375 | 1000 | 9.080e8 | 161.4, burning 3.812 u/s |

**The default reading is 1.0% hot and 1.1% high.** 9.173×10⁸ against 9.083×10⁸ °C, and 142.6
against 141.0 MW on the sustained bound, 171.1 against 169.3 on the flowing one. The plasma held
does not differ. From 500 000 ticks the reactor repeats three readings, one a window:
9.083×10⁸ °C at 999.6 units, 9.082×10⁸ at 999.8 and 9.080×10⁸ at 1000.0. That is where a 20 000-tick window
lands in the heaters' cycle, not a drift. The fed model's temperature is the lowest of the three,
and its 161.4 MW is inside the bracket.

**The line is settled 134 000 ticks after the default length ends**, at 260 000, by the 2×
mark #511 used.
A full box takes only what it burns, so four heaters settle where two do: the two-heater run
under [The supply-limited cells on two heaters](#the-supply-limited-cells-on-two-heaters) reads
the same point.

**Notes that quote a default-length four-heater figure as settled.** None is the state above, and
none is rewritten here. Each was taken at 126 000 ticks before the gate read the fuel line (#508).

- `bolted-joint-throughput.md`: the D-D control's 94.0 MW flowing and 78.3 sustained, its 86.4 MW
  with the plant-efficiency ladder, and the D-T reactor's 996 to 1 195 MW at 597.4 units.
- `fluid-link-throughput.md`: the same 78.3235 and 86.3862 MW pair, and the 1 195.4 MW.
- ADR 0018's Consequences: the 78.3 MW, and the 996 to 1 195 MW.
- `bench-mod-links.ps1`'s help under `-Exchangers` and `-Plasma`: "the 94 MW this rig's D-D
  reactor settles at", and 996 to 1 195 MW.
- `entities.lua` and `recipes/hc.lua`, `check-hc.ps1` and `probe-exchanger-chaining.ps1`: the
  996 to 1 195 MW for a D-T reactor on four heaters.

The 94.0, 78.3 and 86.4 MW were read with fewer ladders than exist now, so they are not this
state at an earlier tick. How far each is from settled was not measured.

### Five combination states, nearest the line

[#498](https://github.com/trulsjo/realistic-fusion-refreshed/issues/498). The held model's demand
split said one heater keeps a box full when the settled reactor asks under 2.5 u/s, and #498 named
the three cases nearest that line. The fed model draws the line elsewhere: it keeps all three full.
Its own line runs between heating rung 3 with confinement rung 2, full at 2.466 u/s, and heating
rung 4 with confinement rung 2, part-full at 2.5. Those two are measured as well. All five: D-D,
one heater, nothing else researched, Factorio 2.0.77, 2026-10-03, passing the bench's gate
including its fuel-line check. Four were run `-Ticks 600000 -Window 30000` and are quoted at
570 000 ticks. Heating 3 + confinement 2 is quoted at 1 560 000 ticks, from `-Ticks 1600000
-Window 40000`: at 600 000 its box was still filling and the gate refused it on the fuel line
alone. Columns as in the table above. "Held asks" is `M.settle`'s burn at a full box, in u/s
at its settled °C, 1200 s at one tick.

| research state | game: MW | held | °C | fed model: held | °C | MW | u/s | held asks | held split said | fed model said |
|---|---|---|---|---|---|---|---|---|---|---|
| heating 4 + confinement 1 | 92.4 – 110.9 | 999.8 | 5.515e8 | 1000 | 5.514e8 | 105.8 | 2.019 | 2.343 at 6.153e8 | full | full |
| heating 2 + confinement 2 | 86.9 – 104.3 | 999.8 | 5.715e8 | 1000 | 5.714e8 | 99.4 | 2.120 | 2.612 at 6.685e8 | part-full | full |
| heating 5 + confinement 1 | 101.3 – 121.5 | 999.8 | 6.056e8 | 1000 | 6.055e8 | 115.9 | 2.293 | 2.692 at 6.844e8 | part-full | full |
| heating 3 + confinement 2 | 97.0 – 116.4 | 999.8 | 6.399e8 | 1000 | 6.397e8 | 111.0 | 2.466 | 3.087 at 7.626e8 | part-full | full |
| heating 4 + confinement 2 | 99.0 – 118.8 | 788.6 | 9.489e8 | 789.8 | 9.476e8 | 113.3 | 2.500 | 3.534 at 8.520e8 | part-full | part-full |

**The fed model's split survives at all five, and the held one fails at three.** Every box landed
where the fed model put it: four full, one part-full at 788.6 against 789.8 units. Every
temperature sits within 0.14% of the fed model's, and every fed MW figure is inside the game's
bracket. The held split said heating 2 + confinement 2, heating 5 + confinement 1 and heating 3 +
confinement 2 could not be kept full; all three were. Heating 4 + confinement 1 it called full,
and it was, but not at the held model's settled point: 5.515×10⁸ °C, 10% under its 6.153×10⁸.

**This is #497's explanation tested where it was not measured.** The held model, which never heats
the arriving fuel, runs 12% to 17% over the game at the three full states #498 named. The fed
model, which does, is within 0.02% at each. The part-full state's pipes stay in the reactor's pool,
at 9.478×10⁸ °C against its 9.489×10⁸, as the top corner's and the D-T reactor's do.

**One thing the fed model does not reproduce is how long filling takes.** At heating 3 +
confinement 2 it fills the box by 300 000 ticks, and the game first held 1000 units at 880 000
in that run, hotter than the model all the way up. The model fills a 1000-unit box. The game
fills 2300 units: the box, and the segment its pipes are in.
[Why the box fills slower than the fed model](#why-the-box-fills-slower-than-the-fed-model) has
the measurement. The settled point is what this note quotes, and there the two agree.

### Two more combination states

[#512](https://github.com/trulsjo/realistic-fusion-refreshed/issues/512) named four states where
the fed model is least certain. Two are in the table above: confinement 2 with heating 4, and
confinement 2 with heating 3. These are the other two: D-D, one heater, nothing else researched,
Factorio 2.0.77 (build 84539), 2026-10-03, both passing the bench's gate including its fuel-line
check. Columns as in the first table of this section.

| research state | run | game: MW | held | °C | fed model: held | °C | MW | u/s |
|---|---|---|---|---|---|---|---|---|
| confinement 3 + heating 2 | `-Ticks 600000 -Window 30000`, read at 570 000 | 91.5 – 109.8 | 781.5 | 9.638e8 | 782.7 | 9.625e8 | 104.7 | 2.500 |
| plant efficiency 1 + confinement 2 | `-Ticks 900000 -Window 30000`, read at 870 000 | 69.4 – 83.3 | 999.9 | 4.258e8 | 1000 | 4.258e8 | 79.5 | 1.393 |

**Both sit on the fed model.** Confinement 3 + heating 2 is part-full where the model puts it,
1.2 units under its 782.7 and 0.14% over its temperature, with its three pipes in the reactor's
pool at 9.627×10⁸ °C. The other two measured part-full cells show the same small offset.
Plant efficiency 1 + confinement 2 holds a full box at the model's temperature to the four
figures quoted. That is also confinement rung 2's own temperature in the first table: plant
efficiency moved what is sold, 65.6 – 78.7 MW to 69.4 – 83.3, and not the plasma. Both fed MW
figures are inside the game's bracket.

**The 24-of-96 split survives.** Three of the six part-full heating × confinement cells are now
measured part-full: the top corner, confinement 2 + heating 4, and confinement 3 + heating 2.
The full cell nearest the line, confinement 2 + heating 3, is measured full. One state with
plant efficiency beside another ladder is measured, and its plasma is that other ladder's.

### Why the box fills slower than the fed model

[#516](https://github.com/trulsjo/realistic-fusion-refreshed/issues/516). **There is more to
fill than the box.** The reactor's plasma box is `input-output`, so it joins the fluid segment
its pipes are in, and the engine counts the box's volume in that segment's capacity. Three
`rf-pipe` are 300 units of pipe, and `LuaFluidBox.get_capacity` on any of them answers 1300.
The segment holds that plasma itself, beside the 1000 the box reads. `M.settle_fed` fills the
box alone.

Since #516 the bench's fuel-line trace ends each row with what the segment holds of its capacity
and what the heater's output box holds. Read there: D-D, one heater, three pipes, nothing
researched, Factorio 2.0.77 (build 84539), 2026-10-03, `-Ticks 120000 -Window 10000`. That run is
too short for the gate, which refuses it on the fuel line. It is quoted for the fill, not for a
settled point.

| ticks | fed so far, at 2.5 u/s | box | segment, of 1300 | heater's output box, of 200 |
|---|---|---|---|---|
| 10 000 | 416.7 | 180.7 | 216.8 | 0 |
| 40 000 | 1666.7 | 617.3 | 747.4 | 0 |
| 70 000 | 2916.7 | 983.3 | 1275.9 | 0 |
| 80 000 | | 1000.0 | 1300.0 | 195.4 |
| 110 000 | | 1000.0 | 1300.0 | 197.2 |

At 10 000 ticks the box holds 180.7 of the 416.7 units fed and the segment 216.8. That is 397.5
between them, and the rest burned. A full line is 2300 units, and then the heater's own 200-unit
output box backs up behind it. Six pipes report a capacity of 1600, nine 1900 and twelve 2200.

**The box is not inside the segment's figure.** The segment's capacity counts the box's volume,
so its contents could be read as already including the box. A full line would then be 1300
units and the sums above a double count. Three readings from the same rig say they are two
stores.

- **The box does not read a share.** As 1000 of the segment's 1300 it would read 166.8 units at
  10 000 ticks. It reads 180.7.
- **The burn only fits the sum.** Between 10 000 and 40 000 ticks the heater fed 1250 units. Box
  plus segment grew by 967.2, which leaves 282.8 burned, 0.57 u/s. The segment alone grew by
  530.6, which would leave 719.4 burned, 1.44 u/s. The fed model's reactor never burns more
  than 0.76 u/s in this fill.
- **Tick by tick, the two add up to what was fed.**
  [#520](https://github.com/trulsjo/realistic-fusion-refreshed/issues/520):
  `scripts/probe-plasma-segment.ps1` logs the line every tick and balances it over each heater
  cycle. Run with no arguments on 2026-10-04, Factorio 2.0.77 (build 84539): D-D, one heater,
  nothing researched (asserted), 100 000 ticks, a three-pipe cell and a six-pipe one. Burned is
  read, not derived: the box is read before the mod's step and after it on the same tick, and
  the two differ on every sixth tick and on no other. In plasma units, over the 120-tick cycle
  ending on the tick named:

  | pipes, segment capacity | cycle ends | fed | burned | box grew | segment grew | box + segment | fed − burned − both | fed − burned − segment |
  |---|---|---|---|---|---|---|---|---|
  | 3, 1300 | 12 002 | 5.0000 | 0.6211 | 1.9902 | 2.3887 | 4.3789 | 0.0000 | 1.9902 |
  | 3, 1300 | 66 002 | 5.0000 | 1.2981 | 1.5145 | 2.1874 | 3.7019 | 0.0000 | 1.5145 |
  | 6, 1600 | 12 002 | 5.0000 | 0.5375 | 1.7848 | 2.6777 | 4.4625 | 0.0000 | 1.7848 |
  | 6, 1600 | 66 002 | 5.0000 | 1.4230 | 1.2878 | 2.2893 | 3.5770 | 0.0000 | 1.2878 |

  With two stores the balance closes to four decimals in all twelve cycles the default spans
  print, three at each of the four rows. With the segment's figure read as counting the box it
  is short by the box's growth every time. Over the whole run each heater fed 2300 and 2600
  units more than its reactor burned (3230.03 against 930.03, and 3530.03 against 930.03),
  which is the box's 1000 and the segment's 1300 and 1600. Within a cycle the segment's
  contents jump when the heater delivers and fall while the box fills. Each pipe's own amount
  is its 100 units' share of the segment's figure, a thirteenth at three pipes: 19.64 units in
  each while the segment reads 255.34 of 1300.

**The split between the two moves through the fill**, from the same run. "Segment per 1000" is
what the segment holds for every 1000 units in the box.

| ticks | 3 pipes: box | segment | segment per 1000 | 6 pipes: box | segment | segment per 1000 |
|---|---|---|---|---|---|---|
| 3 002 | 54.22 | 68.82 | 1269 | 47.78 | 75.42 | 1579 |
| 12 002 | 212.74 | 259.08 | 1218 | 188.90 | 287.15 | 1520 |
| 30 002 | 483.48 | 584.01 | 1208 | 433.09 | 653.49 | 1509 |
| 48 002 | 711.56 | 887.23 | 1247 | 647.53 | 977.29 | 1509 |
| 66 002 | 930.81 | 1203.91 | 1293 | 837.63 | 1315.24 | 1570 |
| full | 1000.00 | 1300.00 | 1300 | 1000.00 | 1600.00 | 1600 |

The box first read 999 units in the cycle ending on tick 71 402 at three pipes and 80 642 at
six. [What the pooled reading leaves over](#what-the-pooled-reading-leaves-over) turns the
split into a rule, and says why these cycle-end figures sit a few units off it.

**The game's fill beside the model's**, at the same ticks. "Pooled" is the fed model's loop with
that inventory added: the box steps its share of one pool, the result is mixed back, and the
feed tops up the pool, not the box. It is arithmetic done for this note. `M.settle_fed` is
unchanged, and no test pins the pooled figures. The pool is the box plus 1200 units or plus
1300, because the game's split is not fixed: the box holds 1000 for every 1200 in the segment
at 10 000 ticks, and 1000 for every 1298 at 70 000.

Heating 3 + confinement 2, the full-box cell nearest the line, `-Ticks 1000000 -Window 20000`,
same rig, same day. The gate refuses this run too, on the fuel line; the settled point is the
1 600 000-tick run's, above.

| ticks | game: held | °C | `M.settle_fed`: held | °C | pooled, +1300: held | °C |
|---|---|---|---|---|---|---|
| 120 000 | 774.5 | 8.991e8 | 904.6 | 7.424e8 | 776.9 | 8.973e8 |
| 240 000 | 883.3 | 7.656e8 | 977.8 | 6.632e8 | 887.8 | 7.614e8 |
| 360 000 | 928.7 | 7.147e8 | 1000 | 6.397e8 | 933.4 | 7.105e8 |
| 480 000 | 957.5 | 6.837e8 | 1000 | 6.397e8 | 962.7 | 6.791e8 |
| 600 000 | 980.8 | 6.596e8 | 1000 | 6.397e8 | 987.7 | 6.530e8 |
| first holds 1000 | 820 000 | | 300 000 | | 660 000 | |

After 820 000 ticks the game's box reads between 998.6 and 1000 from window to window, which is
why the 40 000-tick windows of the longer run first saw 1000 at 880 000.

Nothing researched, far from the line, `-Ticks 900000 -Window 10000`:

| ticks | game: held | °C | `M.settle_fed`: held | °C | pooled, +1200: held | °C | pooled, +1300: held | °C |
|---|---|---|---|---|---|---|---|---|
| 10 000 | 180.7 | 1.784e9 | 371.1 | 9.405e8 | 181.3 | 1.782e9 | 173.9 | 1.840e9 |
| 30 000 | 483.5 | 7.153e8 | 970.7 | 2.690e8 | 485.5 | 7.123e8 | 467.3 | 7.422e8 |
| 50 000 | 736.1 | 4.227e8 | 1000 | 2.381e8 | 752.8 | 4.131e8 | 724.1 | 4.369e8 |
| 70 000 | 983.3 | 2.608e8 | 1000 | 2.381e8 | 1000 | 2.478e8 | 984.3 | 2.617e8 |
| first holds 1000 | 80 000 | | 40 000 | | 70 000 | | 80 000 | |

Each "first holds 1000" is the first window that reads it, on the game's grid: 20 000 ticks in
the first table, 10 000 in the second. Stepped finer, the model's box is full at 288 000 ticks
at the line and at 31 000 with nothing researched.

**The gap is not special to the line.** Nothing researched fills in 2.3 to 2.6 times the model's
time, 31 000 ticks against somewhere between 70 000 and 80 000. Heating 3 + confinement 2 fills
in 2.7 times, 300 000 against 820 000 by the window. And 2300 units is 2.3 times 1000. Near the line it
shows more because the margin is thin: the heater makes 2.5 u/s and the full box burns 2.466.

**The game ran hotter because it held less.** At 120 000 ticks the box held 774.5 units where
the model held 904.6, and the same heating on less plasma is a hotter plasma. The pooled
reading holds what the game holds, and is within 0.2% of its temperature there. A hotter
reactor does burn more, which #516 asked about. That follows from the short box, not the other
way round.

#### What the pooled reading leaves over

[#521](https://github.com/trulsjo/realistic-fusion-refreshed/issues/521). The pooled reading
above filled the line cell 160 000 ticks before the game, and left two things unseparated: the
moving split, and the heat the engine's mixing destroys (ADR 0011). **The split is now
measured, and it is a rule. It closes the gap with nothing researched and not at the line.**

**The split, measured through two whole fills** by `scripts/probe-plasma-segment.ps1`. D-D, one
heater, three pipes, Factorio 2.0.77 (build 84539), 2026-10-04: nothing researched over 100 000
ticks (the #520 run, which also has six pipes), and heating rung 3 + confinement rung 2 with
`-Pipes 3 -Rungs heating_ladder=3,confinement_ladder=2 -Ticks 1000000 -From 120000,780000
-Span 240 -Every 100`. The step is read from a third run, `-Pipes 3 -Ticks 36000 -From 31560
-Span 132 -Every 1`, nothing researched. "Capacity" is the segment's: 1300 at three pipes,
1600 at six.

- **Low branch, to about 520 units in the box:** segment = box × (capacity − 100) / 1000. At
  three pipes that is 1.2 × box.
- **High branch, from about 530 units:** box = 100 + 900 × segment / capacity.
- **Both are the reading one tick before the heater delivers.** A cycle's end is the tick a
  craft lands, and on it the segment already holds the 3.75 units just delivered and the box
  does not. So the cycle-end figures in the tables above sit 3.8 over the low branch, and
  under the high one by 3.75 × 900 / capacity: 2.6 at three pipes, 2.1 at six. One tick
  earlier the low branch is 0.05 off at 12 001 ticks, and the high branch's constant reads
  99.9 at 66 001 at both pipe counts and 99.7 at the line state at 120 001 and at 780 001.
- **The switch is a step.** With nothing researched the box read 519.85 at 32 642 ticks and
  530.51 at 33 002, while the segment stood at 627.75 for two cycles. At six pipes it fell
  between 506.92 and 552.35 units, and at the line state between 473.67 and 559.39.

Why the engine splits this way was not found. `quality.md` records a lone 1000-unit box
relaxing to 526.3158 units, which is where the switch falls; the two were not connected.

**The pooled reading, re-run with that split and fed as the heater feeds.** The same
arithmetic as above with two changes: the pool's split is read off the two branches, switching
at 526 units, in place of a fixed +1200 or +1300; and the feed arrives as 5 units every 120
ticks, read on the step before each delivery, because that is where the probe reads the game.
Computed 2026-10-04, 6-tick step, 1×10⁶ °C feed, three pipes. It is still arithmetic for this
note: `M.settle_fed` is unchanged and no test pins it. The game column is the probe's reading
at the cycle ending 2 ticks after the tick named. The +1300 column is the earlier reading,
fed steadily, and its last row is the first step at or over the figure.

Heating 3 + confinement 2:

| ticks | game: held | °C | pooled, +1300: held | °C | pooled, measured split, in bursts: held | °C |
|---|---|---|---|---|---|---|
| 120 000 | 774.5 | 8.991e8 | 776.9 | 8.973e8 | 774.7 | 8.991e8 |
| 240 000 | 883.3 | 7.656e8 | 887.8 | 7.614e8 | 883.5 | 7.658e8 |
| 360 000 | 928.8 | 7.147e8 | 933.4 | 7.105e8 | 929.0 | 7.149e8 |
| 480 000 | 957.6 | 6.837e8 | 962.7 | 6.791e8 | 958.1 | 6.836e8 |
| 600 000 | 980.8 | 6.595e8 | 987.7 | 6.530e8 | 982.2 | 6.583e8 |
| 720 000 | 996.4 | 6.478e8 | 1000 | 6.397e8 | 998.1 | 6.414e8 |
| a cycle first ends on 998 units | 768 002 to 780 002 | | 648 150 | | 678 354 | |

Nothing researched:

| ticks | game: held | °C | pooled, +1300: held | °C | pooled, measured split, in bursts: held | °C |
|---|---|---|---|---|---|---|
| 12 000 | 212.7 | 1.566e9 | 206.2 | 1.607e9 | 212.8 | 1.566e9 |
| 30 000 | 483.5 | 7.153e8 | 467.3 | 7.422e8 | 483.5 | 7.152e8 |
| 48 000 | 711.6 | 4.433e8 | 698.9 | 4.590e8 | 711.6 | 4.433e8 |
| 66 000 | 930.8 | 2.886e8 | 930.2 | 2.917e8 | 930.9 | 2.887e8 |
| a cycle first ends on 999 units | 71 402 | | 71 070 | | 71 394 | |

At the line the probe printed one cycle in a hundred, so the game's figure is a bracket: the
cycle ending on 768 002 read 997.79 units and the one on 780 002 read 998.01. The bench's
coarser windows gave 80 000 and 820 000 above for the same two fills.

**With nothing researched the split is the whole gap.** The re-run is within 0.05% of the
game's plasma and 0.03% of its temperature at all four ticks, where +1300 was 3.4% and 3.8%
out, and its cycle first ends on 999 units 8 ticks before the game's.

**At the line it holds to 600 000 ticks and not after.** Through 600 000 it is within 0.14%
of plasma and 0.18% of temperature, against 0.70% and 0.99% for +1300. It then ends a cycle
on 998 units at 678 354 ticks, 90 000 to 102 000 before the game.

**The reactor model is not what is off.** In the cycle ending on tick 780 002 the probe read
4.9945 units burned of the 4.9995 fed. `M.step`, run at each of the twenty states the box was
in before the mod stepped it in the next cycle, ticks 780 006 to 780 120, burns 4.99476
against 4.99452 read: 0.005% apart. A cycle's end is its low point. The box read 998.01 units
there and up to 999.58 before a step, so `M.step` at the end state alone gives 2.4935 u/s
where the cycle burned 2.4973, and that 0.15% is the swing and not a residual.

**What is left is where the heat sits, and it is not explained.** At 720 000 ticks the game
holds 996.4 units at 6.478×10⁸ °C and the re-run 998.1 at 6.414×10⁸: the game's box is 1.0%
hotter with less in it, so it burns nearer the 2.5 u/s fed and the last units come slowly. At
780 000 its pipes read 4.80×10⁸ °C beside a box at 6.47×10⁸, where the pooled arithmetic
holds both at one temperature. Variants tried, each with the first tick it reads 998 units:

| variant | first reads 998 |
|---|---|
| measured split, one temperature in box and segment, fed steadily | 673 644 |
| measured split, one temperature, fed in 5-unit bursts, read at a cycle's end | 678 354 |
| measured split, fed steadily, the segment keeping its own temperature and giving no heat back | 660 342 |
| the game, read at a cycle's end | 768 002 to 780 002 |

None reaches the game. The game's pipes are colder than its box and warmer than the feed, so
it lies between the first row and the third, and both fill sooner. **Mixing loss is not the
cause, by its sign.** Heat destroyed is a colder box, a colder box burns less here, and a
reactor that burns less fills sooner; the game's box is hotter than the arithmetic's, not
colder. What keeps it hotter over the last ten units was not found. The settled point is
unaffected: the 1 600 000-tick bench run of this state reads 999.8 units and 6.399×10⁸ °C,
which is the fed model's.

**Tried against it: more pipe.** Heating 3 + confinement 2 at `-Pipes 12`, a 2200-unit segment,
`-Ticks 2000000 -Window 20000`, passing the gate. The box first held 1000 units at 1 180 000
ticks, against 820 000 at three pipes. It settled at 999.8 units, 6.400×10⁸ °C and
97.0 – 116.4 MW, which is the three-pipe run's settled point and the fed model's. A shorter line
could not be tried, because three pipes is the shortest the rig builds.

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

#### The fed map, all ninety-six states

[#513](https://github.com/trulsjo/realistic-fusion-refreshed/issues/513). The held map's layout
and symbols, on the fed model: one 90 MW exchanger against a reactor one heater feeds.

**The method, once.** `M.settle_fed`, 7200 s at the 6-tick step, D-D, one heater's 2.5 u/s
arriving at 1×10⁶ °C. MW is what the last step sells. The tuned reading is the most the reactor
sells at any feed from 5% to 100% of the heater's 2.5 u/s, in 5% steps. That is the fed
counterpart of the held map's density optimum: a player under-feeding the reactor on purpose.
Plant efficiency scales what is sold and nothing else, so each heating × confinement cell was
settled once at the shipped capture and scaled. Three cells settled with the capture passed
instead agree with the scaled figure to six decimals.

```
                               50   55   60   65   70   75   MW of heating
  capture 0.85   tau 30 s      ok   ok   ok   ok   ok   X
                     40 s      ok   ok   ok   X    X    X
                     50 s      ok   ok   X    X    X*   X*
                     60 s      ok   X    X*   X*   X*   X*
  capture 0.9    tau 30 s      ok   ok   ok   ok   X    X
                     40 s      ok   ok   X    X    X    X
                     50 s      ok   X    X    X    X*   X*
                     60 s      X    X    X*   X*   X*   X*
  capture 0.925  tau 30 s      ok   ok   ok   ok   X    X
                     40 s      ok   ok   X    X    X    X
                     50 s      ok   X    X    X    X*   X*
                     60 s      X    X    X*   X*   X*   X*
  capture 0.9375 tau 30 s      ok   ok   ok   ok   X    X
                     40 s      ok   ok   X    X    X    X
                     50 s      ok   X    X    X    X*   X*
                     60 s      X    X    X*   X*   X*   X*
```

`ok` — covered at the heater's full feed *and* at every lower feed swept. `~` — covered at full
feed and not at some lower one. `X` — not covered at full feed. `*` — **supply-limited**: the
box is part-full and the reactor burns all 2.5 u/s.

| | `ok` | `~` | `X` | of which supply-limited |
|---|---|---|---|---|
| held map | 20 | 4 | 72 | not a held reading |
| fed map, one heater | **32** | **0** | **64** | 24, all `X` |

**Twelve cells differ, and all twelve become `ok`.** Eight are `X` on the held map and four are
`~`. Fed MW at full feed, then tuned:

| capture | cell | held map | fed: full / tuned, MW |
|---|---|---|---|
| 0.85 | τ 30 s, 70 MW — heating rung 4 | `X` | 88.9 / 88.9 |
| 0.85 | τ 40 s, 60 MW | `X` | 85.0 / 85.0 |
| 0.85 | τ 50 s, 55 MW | `X` | 87.4 / 88.9 |
| 0.85 | τ 60 s, 50 MW — confinement rung 3 | `X` | 86.9 / 86.9 |
| 0.9 | τ 30 s, 65 MW | `~` | 84.9 / 85.4 |
| 0.9 | τ 50 s, 50 MW — #395's cell | `~` | 79.5 / 80.1 |
| 0.925 | τ 30 s, 65 MW | `X` | 87.3 / 87.8 |
| 0.925 | τ 40 s, 55 MW | `~` | 81.1 / 82.9 |
| 0.925 | τ 50 s, 50 MW | `X` | 81.7 / 82.3 |
| 0.9375 | τ 30 s, 65 MW | `X` | 88.5 / 89.0 |
| 0.9375 | τ 40 s, 55 MW | `~` | 82.2 / 84.0 |
| 0.9375 | τ 50 s, 50 MW | `X` | 82.8 / 83.4 |

**No cell is `~` on the fed map.** Under-feeding raises what a fed reactor sells in twenty-nine
of the thirty-two `ok` cells, and in none of them past 90. The largest gain is 4.6 MW, at the
plant-efficiency rung 3 corner: 60.95 MW at full feed and 65.56 at 30% of it.

**One cell is `X` by a hair.** Capture 0.9, τ 40 s, 60 MW sells 90.02 MW at full feed. Every
other cell is at least 1.0 MW from the line, at full feed and tuned.

**The six supply-limited heating × confinement cells are `X` at every capture**, 104.7 MW or
more. [The supply-limited cells on two heaters](#the-supply-limited-cells-on-two-heaters) reads
them on a second heater.

Three of the twelve cells are measured in the game. Heating rung 4 alone and confinement rung 3
alone are in the first table of this section: 77.7 – 93.2 MW and 76.0 – 91.1, both brackets
straddling 90 with the fed figure inside them under it. Capture 0.9 with τ 50 s is under
[Two more combination states](#two-more-combination-states): 69.4 – 83.3 MW, under 90 at both
bounds.

The fed grid, **full feed / tuned**, in MW. **Bold is over 90.** \* is supply-limited.

##### capture 0.85 — shipped, nothing researched

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 55.3 / 59.4 | 63.3 / 66.6 | 71.7 / 73.7 | 80.2 / 80.7 | 88.9 / 88.9 | **97.6** / **97.9** |
| **40 s** | 64.2 / 67.9 | 74.5 / 76.1 | 85.0 / 85.0 | **95.5** / **95.5** | **105.8** / **105.8** | **115.9** / **115.9** |
| **50 s** | 75.0 / 75.6 | 87.4 / 88.9 | **99.4** / **99.4** | **111.0** / **111.0** | **113.3** / **113.3** \* | **116.1** / **116.1** \* |
| **60 s** | 86.9 / 86.9 | **100.4** / **100.4** | **104.7** / **104.7** \* | **107.2** / **107.2** \* | **110.1** / **110.1** \* | **113.0** / **113.0** \* |

##### capture 0.9 — `rf-plant-efficiency-1`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 58.5 / 62.9 | 67.0 / 70.6 | 75.9 / 78.1 | 84.9 / 85.4 | **94.1** / **94.1** | **103.4** / **103.6** |
| **40 s** | 68.0 / 71.9 | 78.9 / 80.6 | **90.0** / **90.0** | **101.1** / **101.1** | **112.0** / **112.0** | **122.7** / **122.7** |
| **50 s** | 79.5 / 80.1 | **92.5** / **94.1** | **105.3** / **105.3** | **117.5** / **117.5** | **120.0** / **120.0** \* | **122.9** / **122.9** \* |
| **60 s** | **92.0** / **92.0** | **106.4** / **106.4** | **110.8** / **110.8** \* | **113.6** / **113.6** \* | **116.6** / **116.6** \* | **119.7** / **119.7** \* |

##### capture 0.925 — `rf-plant-efficiency-2`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 60.1 / 64.7 | 68.9 / 72.5 | 78.0 / 80.2 | 87.3 / 87.8 | **96.7** / **96.7** | **106.2** / **106.5** |
| **40 s** | 69.9 / 73.9 | 81.1 / 82.9 | **92.5** / **92.5** | **103.9** / **103.9** | **115.1** / **115.1** | **126.1** / **126.1** |
| **50 s** | 81.7 / 82.3 | **95.1** / **96.7** | **108.2** / **108.2** | **120.8** / **120.8** | **123.3** / **123.3** \* | **126.3** / **126.3** \* |
| **60 s** | **94.6** / **94.6** | **109.3** / **109.3** | **113.9** / **113.9** \* | **116.7** / **116.7** \* | **119.8** / **119.8** \* | **123.0** / **123.0** \* |

##### capture 0.9375 — `rf-plant-efficiency-3`

| τ | 50 MW | 55 MW | 60 MW | 65 MW | 70 MW | 75 MW |
|---|---|---|---|---|---|---|
| **30 s** (ship) | 60.9 / 65.6 | 69.8 / 73.5 | 79.0 / 81.3 | 88.5 / 89.0 | **98.1** / **98.1** | **107.7** / **108.0** |
| **40 s** | 70.8 / 74.9 | 82.2 / 84.0 | **93.8** / **93.8** | **105.3** / **105.3** | **116.7** / **116.7** | **127.8** / **127.8** |
| **50 s** | 82.8 / 83.4 | **96.4** / **98.0** | **109.7** / **109.7** | **122.4** / **122.4** | **125.0** / **125.0** \* | **128.0** / **128.0** \* |
| **60 s** | **95.8** / **95.8** | **110.8** / **110.8** | **115.4** / **115.4** \* | **118.3** / **118.3** \* | **121.4** / **121.4** \* | **124.7** / **124.7** \* |

This records readings. Whether 90 MW should move is #315 and Truls's.

#### The supply-limited cells on two heaters

[#526](https://github.com/trulsjo/realistic-fusion-refreshed/issues/526). The method of the
one-heater map, at two heaters' feed: `M.settle_fed`, 7200 s at the 6-tick step, D-D, 5 u/s
arriving at 1×10⁶ °C, computed 2026-10-04. 14 400 s reads the same to the digits quoted. Each
cell was settled once at the shipped capture and its MW scaled; the top corner settled with
capture 0.9375 passed instead agrees to six decimals. Held, °C and burn do not depend on
capture. The tuned reading was not swept at this feed.

| cell | one heater: held | °C | two heaters: held | °C | burn, u/s | MW at capture 0.85 / 0.9 / 0.925 / 0.9375 |
|---|---|---|---|---|---|---|
| τ 50 s, 70 MW — heating 4 + confinement 2 | 789.8 | 9.476e8 | 1000 | 7.047e8 | 2.795 | 122.0 / 129.2 / 132.8 / 134.6 |
| τ 50 s, 75 MW — heating 5 + confinement 2 | 720.4 | 1.115e9 | 1000 | 7.663e8 | 3.105 | 132.6 / 140.4 / 144.3 / 146.2 |
| τ 60 s, 60 MW — heating 2 + confinement 3 | 782.7 | 9.625e8 | 1000 | 7.005e8 | 2.773 | 113.1 / 119.8 / 123.1 / 124.7 |
| τ 60 s, 65 MW — heating 3 + confinement 3 | 707.4 | 1.153e9 | 1000 | 7.746e8 | 3.147 | 124.9 / 132.2 / 135.9 / 137.7 |
| τ 60 s, 70 MW — heating 4 + confinement 3 | 659.9 | 1.313e9 | 1000 | 8.435e8 | 3.492 | 135.9 / 143.9 / 147.9 / 149.9 |
| τ 60 s, 75 MW — heating 5 + confinement 3 | 625.0 | 1.460e9 | 1000 | 9.080e8 | 3.812 | 146.3 / 154.9 / 159.2 / 161.4 |

**A second heater fills all six.** The most any of them burns at a full box is 3.812 u/s, under
two heaters' 5, so none is supply-limited on two and a third heater changes no figure: the
model reads the same at 7.5 u/s. Filling the box cools it, by 26% to 38%, and raises what it
sells by 7.7% at heating 4 + confinement 2 (113.3 to 122.0 MW at capture 0.85) and by 29.5% at
the top of both ladders (113.0 to 146.3).

**Each then needs two exchangers, at every capture.** All twenty-four figures are over one
exchanger's 90 MW and under two's 180; the largest is 161.4. They needed two on one heater as
well: the one-heater figures run from 104.7 to 128.0 MW.

**Two of the six are measured in the game on two heaters.** `bench-mod-links.ps1 -Heaters 2
-Ticks 1000000 -Window 20000`, with `-Rungs heating_ladder=4,confinement_ladder=2` or with
nothing, which is every ladder at its top. D-D, six pipes, Factorio 2.0.77 (build 84539),
2026-10-04, both passing the bench's gate, both read at 980 000 ticks.

| research state | game: MW | held | °C | fed model: held | °C | MW | u/s |
|---|---|---|---|---|---|---|---|
| heating 4 + confinement 2, capture 0.85 | 106.7 – 128.0 | 999.9 | 7.047e8 | 1000 | 7.047e8 | 122.0 | 2.795 |
| every ladder at its top, capture 0.9375 | 141.1 – 169.3 | 999.8 | 9.082e8 | 1000 | 9.080e8 | 161.4 | 3.812 |

Both boxes are full where the model fills them, both temperatures are within 0.02% of it, and
both fed MW figures are inside the game's bracket. On one heater the same two states held 788.6
and 623.8 units. The four-heater run under
[The default four-heater run, settled](#the-default-four-heater-run-settled) is the second
state again, and reads the same point.

**The seventy-six states still unmeasured on a fuel line** are every state with two or more
ladders researched, less the top corner and the seven combination states measured above:
ninety-six, less the unresearched corner, the eleven single-ladder states, the far corner and those
seven. The fed model reads all of them, and it has matched the game at all twenty measured.

## What this does not cover

- **THE FED REACTOR, measured at twenty of ninety-six states** on one heater, at three on
  two and at one on four — see [The fed reactor, one heater](#the-fed-reactor-one-heater) above. Every figure outside that
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
  and is cited from this note. *THE FED D-D REACTOR ON ONE HEATER* pins the fed model's one-heater
  boundary the same way.
- `realistic-fusion-refreshed/prototypes/entities.lua` — `exchanger.energy_consumption` and the
  sizing argument above it.
- #227 (the 90 MW), #395 (the plant-efficiency lever), #425 and ADR 0038 (the heating ladder), #432
  (this measurement), #315 (whether the capacity moves).
