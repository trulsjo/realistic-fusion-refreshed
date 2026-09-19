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

**One cell reads 0.1 to 0.2 MW below a figure quoted elsewhere, and it is the sweep's grid rather
than a disagreement.** `entities.lua` and `tests/test-reactor-logic.lua` both give confinement
rung 2's tuned figure as **88.8 MW**, pinned at the 85% fill ADR 0024 tabulates as that rung's
optimum. This sweep reads **88.6** at 85% and **88.7** at its own argmax of 80%, and the pin's
tolerance is 2%, so nothing here falsifies it. The 88.7 in the table above is the argmax, because
that is what every other cell in the table is.

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

## What this does not cover

- **THE FED REACTOR.** Every figure here is a settled reactor on the pure model. What a reactor
  actually reaches on a fuel line is `docs/research/d-t-ignition.md`'s feed table and
  `bench-mod-links.ps1`'s measurement, and the `entities.lua` comment keeps both — a fed reactor
  never reaches the settled figure. The three ladders move the fed reading too, and by how much is
  not measured here or anywhere.
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
