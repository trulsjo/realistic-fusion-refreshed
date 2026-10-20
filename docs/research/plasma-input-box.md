# The reactor's plasma box as `input` instead of `input-output`

## Current figures

Each row is a figure this note currently stands behind, copied from the section named. A change to
a figure below changes its row here in the same commit (docs/agents/code-review.md).

| Figure | Value | Measured | Game version | Research state | Section |
|---|---|---|---|---|---|
| Shipped `input-output` box and canary `input` box alike, D-D: step ticks up to 96 000 on which `control.lua` changed a powered reactor's box | 15 978 of the 16 001 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Does it load, and is it stepped?](#does-it-load-and-is-it-stepped) |
| Shipped `input-output` box, D-D solo, 3 pipes: first tick the box reads 99.9% | 71 295 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Shipped `input-output` box, D-D solo, 6 pipes: first tick the box reads 99.9% | 80 539 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Canary `input` box, D-D solo, 3 pipes and 6 pipes: first tick the box reads 99.9% | 30 975 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Canary `input` box against shipped `input-output` box, D-D solo: how much faster the canary box fills | 2.30 times at three pipes, 2.60 times at six | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Shipped `input-output` box, D-D solo: units the segment held for every 1000 in the box through tick 32 000 | 1200 at three pipes, 1500 at six | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Canary `input` box, D-D solo: what the segment held until the box was full | 0 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [One reactor: solo 3 and solo 6](#one-reactor-solo-3-and-solo-6) |
| Shipped `input-output` box, D-D pair, one reactor unpowered: each box and the segment at tick 96 000 | 656.50 per box, 2164.29 of 3500 in the segment | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two reactors bridged by pipe: the pair](#two-reactors-bridged-by-pipe-the-pair) |
| Shipped `input-output` box, D-D pair, one reactor unpowered: how close the unpowered box stays to the powered one's temperature while the line fills | within 3.0% (1.9721 against 2.0330×10⁸ at 96 000) | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two reactors bridged by pipe: the pair](#two-reactors-bridged-by-pipe-the-pair) |
| Canary `input` box, D-D pair, one reactor unpowered: tick the unpowered box fills, then the powered one | 47 774, then 61 093 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two reactors bridged by pipe: the pair](#two-reactors-bridged-by-pipe-the-pair) |
| Canary `input` box, D-D pair, one reactor unpowered: step ticks on which `control.lua` changed the unpowered box, against the powered one | 205, against 15 978 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two reactors bridged by pipe: the pair](#two-reactors-bridged-by-pipe-the-pair) |
| Canary `input` box, D-D solo, 3 and 6 pipes: first row of the 10⁻⁴ settle test, rows every 4000 ticks | 44 000 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Past tick 96 000, both reactors powered, and a lone box](#past-tick-96-000-both-reactors-powered-and-a-lone-box) |
| Shipped `input-output` box and canary `input` box alike, D-D solo, 3 and 6 pipes: box temperature at tick 1 980 000 | 2.381512×10⁸ °C | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The shipped box passes the settle test near the canary's, and is still moving](#the-shipped-box-passes-the-settle-test-near-the-canarys-and-is-still-moving) |
| Shipped `input-output` box, D-D solo: tick from which every later row reads the same as the one 60 000 before it | 1 160 000 at three pipes, 1 400 000 at six | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The shipped box passes the settle test near the canary's, and is still moving](#the-shipped-box-passes-the-settle-test-near-the-canarys-and-is-still-moving) |
| Shipped `input-output` box, D-D pair, both reactors powered: tick both boxes fill | 246 755 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two powered canary boxes on one line settle at the same temperature](#two-powered-canary-boxes-on-one-line-settle-at-the-same-temperature) |
| Canary `input` box, D-D pair, both reactors powered: tick box 1 and box 2 fill | 89 651 and 88 694 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two powered canary boxes on one line settle at the same temperature](#two-powered-canary-boxes-on-one-line-settle-at-the-same-temperature) |
| Shipped `input-output` box, D-D pair, both reactors powered: the two box temperatures at tick 1 980 000 | 2.368459 and 2.394605×10⁸ °C, 1.10% apart | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two powered canary boxes on one line settle at the same temperature](#two-powered-canary-boxes-on-one-line-settle-at-the-same-temperature) |
| Canary `input` box, D-D pair, both reactors powered: the two box temperatures at tick 1 980 000 | both read 2.381512×10⁸ °C | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Two powered canary boxes on one line settle at the same temperature](#two-powered-canary-boxes-on-one-line-settle-at-the-same-temperature) |
| Shipped `input-output` box, D-D pair: the one order of the fitted rule that misses no tick, and of how many | 1H2 (the first reactor, the heater, the second reactor), none of 592 000 ticks | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The order the engine takes the two boxes in](#the-order-the-engine-takes-the-two-boxes-in) |
| Shipped `input-output` box, D-D pair built in four orders (1H2, 21H, 12H, 2H1), 1 heater, 3 and 12 pipes: the one order of the fitted rule that misses no tick in each | the build order, none of 592 000 ticks in each | 2026-10-05 (1H2) and 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Built in another order](#built-in-another-order) |
| Shipped `input-output` box, D-D pair, both powered, full, in each build: the colder box at 296 000 | the one the fitting order takes just before the heater, 2.4052 against 2.4137×10⁸ °C | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Built in another order](#built-in-another-order) |
| Shipped `input-output` box, D-D pair built 12H or 2H1, one powered: the unpowered box on the full line, rows 152 000 to 296 000 | never 15 °C; 1.083×10³ to 1.303×10⁴ °C | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Built in another order](#built-in-another-order) |
| Shipped `input-output` box, He3-He3 pair, 1 heater, 3 and 12 pipes: the one order of the fitted rule that misses no tick | 1H2, the build order, none of 992 000 ticks | 2026-10-14 and 2026-10-15 | 2.0.77 | unresearched (all 11 rungs asserted off) | [On the aneutronic reactor](#on-the-aneutronic-reactor) |
| Shipped `input-output` box, He3-He3 pair, both powered, full: what the fitting order has each box push into the line over 170 646 ticks | 22.39 and 19.38 units | 2026-10-14 and 2026-10-15 | 2.0.77 | unresearched (all 11 rungs asserted off) | [On the aneutronic reactor](#on-the-aneutronic-reactor) |
| Shipped `input-output` box, D-D pair, one reactor unpowered: ticks the two boxes fill | 148 946 and 148 939 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2) |
| Shipped `input-output` box, D-D pair, one reactor unpowered: first tick the unpowered box reads 15 °C | tick 150 012 | 2026-10-05 | 2.0.77 | unresearched | [Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2) |
| Shipped `input-output` box, D-D pair, one reactor unpowered: the powered reactor's temperature at 596 000 | 2.3859×10⁸ °C | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2) |
| Shipped `input-output` box, five shapes of line with an unpowered reactor, each built 1H2: how soon after its box fills the unpowered reactor reads 15 °C | within 2800 ticks | 2026-10-05 | 2.0.77 | unresearched in four shapes; heating rung 5 and no other in one | [Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2) |
| Shipped `input-output` box, D-D pair, the unpowered box: heat `control.lua`'s step removed over the 916 steps of the traced window | 1.9788×10¹¹ unit-°C | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Which of the step's terms takes it](#which-of-the-steps-terms-takes-it) |
| Shipped `input-output` box, D-D pair, the unpowered box: share of that heat taken by radiation and by the confinement loss | 65.8% and 35.1% | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Which of the step's terms takes it](#which-of-the-steps-terms-takes-it) |
| Shipped `input-output` box's traced temperature run on in `M.step`: time for a box held full and left unheated to reach the floor | 1818 ticks (303 steps, 30.3 s) | 2026-10-05 | not stated | unresearched (all 11 rungs asserted off) | [Which of the step's terms takes it](#which-of-the-steps-terms-takes-it) |
| Shipped `input-output` lone box, seeded with 1000 at 15 °C: box and its segment from 4000 to 596 000 | 526.3158 and 473.6842 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The lone box](#the-lone-box) |
| Canary `input` lone box, seeded with 1000 at 15 °C: box and its segment from 4000 to 596 000 | 1000.0000 and 0 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The lone box](#the-lone-box) |
| Shipped `input-output` box, D-He3 solo, 1 heater, 3 pipes: box of 3000 and segment of 3300 over the last cycle | 467.54 to 469.12 and 499.54 to 501.47 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The aneutronic reactor](#the-aneutronic-reactor) |
| Canary `input` box, D-He3 solo, 1 heater, 3 pipes: box of 3000 and segment of 3300 over the last cycle | 466.91 to 469.52 and 0 to 0.88 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The aneutronic reactor](#the-aneutronic-reactor) |
| Shipped `input-output` box, D-He3 pair, one reactor unpowered: how close the unpowered box reads to the powered one at every row of the last cycle | within 1.6% | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The aneutronic reactor](#the-aneutronic-reactor) |
| Canary `input` box, D-He3 pair, one reactor unpowered: tick from which the unpowered box is full of cold plasma, and its temperature from row 8000 | tick 143 901, at 3000 units; 15 °C | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The aneutronic reactor](#the-aneutronic-reactor) |
| Shipped `input-output` lone aneutronic box, seeded with 3000 units at 15 °C: box beside its segment | 1525.4238 beside 1474.5762 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The aneutronic reactor](#the-aneutronic-reactor) |
| Shipped `input-output` box, He3-He3 solo, 3 pipes: box first at 99.9% of 3000 | 151 531 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Canary `input` box, He3-He3 solo, 3 pipes: box first at 99.9% of 3000 | 72 162, 2.10 times sooner | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Shipped `input-output` box and canary `input` box alike, He3-He3: powered box temperature from the first row after the fill to 496 000 | 3.1057×10⁶ °C | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Shipped `input-output` box, He3-He3 pair, one powered: tick the powered and the unpowered box fill, and first tick the unpowered box reads 15 °C full | 324 192 and 324 190; tick 324 192 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Canary `input` box, He3-He3 pair, one powered: tick the powered and the unpowered box fill, and first tick the unpowered box reads 15 °C full | 144 377 and 143 901; 143 904 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Shipped `input-output` box, He3-He3 pair, both powered: ticks the two boxes fill | 325 354 and 325 353 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Canary `input` box, He3-He3 pair, both powered: ticks the two boxes fill | 144 617 and 144 616 | 2026-10-05 | 2.0.77 | unresearched (all 11 rungs asserted off) | [An aneutronic line that fills: He3-He3](#an-aneutronic-line-that-fills-he3-he3) |
| Shipped `input-output` box, He3-He3 pair, 1 heater, 3 and 12 pipes: share of the heat `control.lua`'s step took from the unpowered box over ticks 200 000 to 206 000 by radiation and by the confinement loss | 99.43% and 0.57% of 9.5206×10¹¹ unit-°C | 2026-10-14 and 2026-10-15 | 2.0.77 | unresearched (all 11 rungs asserted off) | [What cools the unpowered He3-He3 box before the fill](#what-cools-the-unpowered-he3-he3-box-before-the-fill) |
| The same window: steps on which `M.step` reproduces the unpowered box | 1000 of 1000 | 2026-10-14 and 2026-10-15 | 2.0.77 | unresearched (all 11 rungs asserted off) | [What cools the unpowered He3-He3 box before the fill](#what-cools-the-unpowered-he3-he3-box-before-the-fill) |
| Shipped `input-output` box, D-He3 solo, 40 heaters, 120 pipes: where the box settles | never fills; 2902.49 to 2923.92 of 3000 at 4.15×10⁹ °C | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Shipped `input-output` box, D-He3 solo, 48 heaters, 144 pipes: fill tick and temperature after it | 10 339; 1.369335×10⁷ °C | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Canary `input` box, D-He3 solo, 48 heaters, 144 pipes: fill tick and temperature after it | 1805; 1.369335×10⁷ °C | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Shipped `input-output` box, D-He3 pair, one powered, 48 heaters, 144 and 12 pipes: fill ticks, and first tick the unpowered box reads 15 °C | 13 957 and 13 925; 13 926 | 2026-10-14 | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Shipped `input-output` box, D-He3 solo, normal quality, 3 pipes plus three per added heater: the fewest of the counts built (1, 40, 41, 42, 44 and 48) that fill the line, its fill tick and temperature after it | 41 heaters, 123 pipes; 10 870; 1.369335×10⁷ °C | 2026-10-18 (41) and 2026-10-14 (40) | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Shipped `input-output` box, D-He3 solo, normal quality, 41, 42, 44 and 48 heaters: temperature of the full box | 1.369335×10⁷ °C at every count | 2026-10-14 (48) and 2026-10-18 | 2.0.77 | unresearched (all 11 rungs asserted off) | [A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold) |
| Shipped `input-output` box, D-He3, 48 heaters, normal quality, solo, pair and both: the one way of taking the heater bank that misses no tick of the fitted rule, and of how many | each heater in build order, pushing twice before the next, the boxes in build order; none of 594 000 ticks | 2026-10-18 | 2.0.77 | unresearched (all 11 rungs asserted off) | [The fitted rule beside the line that fills](#the-fitted-rule-beside-the-line-that-fills) |
| Shipped `input-output` box, D-He3 solo, 41 heaters, 123 pipes, the reactor at legendary and the heaters at normal: fill tick and temperature after it | 10 870; 1.369335×10⁷ °C, every row as at normal quality | 2026-10-18 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Above normal quality](#above-normal-quality) |
| Shipped `input-output` box, D-He3 solo, heaters and reactor at legendary, 3 pipes plus three per added heater: the fewest of the counts built (16, 17 and 41) that fill the line, its fill tick and temperature after it | 17 heaters, 51 pipes; 6364; 1.369335×10⁷ °C | 2026-10-18 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Above normal quality](#above-normal-quality) |
| Shipped `input-output` box, D-He3 solo, 16 heaters and the reactor at legendary, 48 pipes: where the box settles | never fills; 2908.27 to 2919.99 of 3000 at 4.15 to 4.16×10⁹ °C | 2026-10-18 | 2.0.77 | unresearched (all 11 rungs asserted off) | [Above normal quality](#above-normal-quality) |
| Shipped `input-output` box: `check-pooling.ps1` verdict | `PASS: 125 checks, 0 failures` | 2026-10-05 | 2.0.77 | not stated for this run (the 2026-10-04 run asserted all 11 rungs off) | [The pooling check: 23 of 125 checks failed, and 27 do since #565](#the-pooling-check-23-of-125-checks-failed-and-27-do-since-565) |
| Canary `input` box: `check-pooling.ps1` verdict | `FAIL: 125 checks, 27 failures` | 2026-10-05 | 2.0.77 | not stated for this run (the 2026-10-04 run asserted all 11 rungs off) | [The pooling check: 23 of 125 checks failed, and 27 do since #565](#the-pooling-check-23-of-125-checks-failed-and-27-do-since-565) |
| Shipped `input-output` box: the four "the run gains most of what its reactors spent, and not all of it" rows (solo, solopipe, bare, piped) | 94.6%, 75.4%, 57.6% and 67.0% | 2026-10-05 | 2.0.77 | not stated for this run (the 2026-10-04 run asserted all 11 rungs off) | [The pooling check: 23 of 125 checks failed, and 27 do since #565](#the-pooling-check-23-of-125-checks-failed-and-27-do-since-565) |
| Shipped `input-output` box and canary `input` box alike: load-time invariants that hold in `load-check.ps1` | sixteen | not stated | 2.0.77 | not stated | [The load check: everything holds](#the-load-check-everything-holds) |
| Neither box (the canary cannot be loaded into them): the Lua suites | 968 checks, 0 failures | 2026-10-04 | none (pure simulation) | not stated | [The Lua suites: the canary cannot reach them](#the-lua-suites-the-canary-cannot-reach-them) |
| Save made on the shipped `input-output` box at tick 80 001, loaded under the canary `input` box, D-D pair: what each box took and the segment gave up in the first tick | 43.9732 and 87.9464 | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off at build and at the canary load) | [An existing save loaded under the canary](#an-existing-save-loaded-under-the-canary) |
| The same save, canary `input` load: the unpowered pair box 2's temperature when saved, and from row 84 000 to 120 000 | 2.6695×10⁸ °C, then 15 °C | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off at build and at the canary load) | [An existing save loaded under the canary](#an-existing-save-loaded-under-the-canary) |
| The same save, control (shipped `input-output`) load: how close the unpowered box stays to the powered one's temperature | within 7.1% (1.2979 against 1.3966×10⁸ at 120 000) | 2026-10-04 | 2.0.77 | unresearched (all 11 rungs asserted off at build and at the canary load) | [An existing save loaded under the canary](#an-existing-save-loaded-under-the-canary) |
| Shipped-box saves loaded under the canary `input` box: cases in which the change would count as breaking | one case of the five loaded | 2026-10-05 | 2.0.77 | unresearched (11 rungs asserted off at build and at the canary load) | [The saves #550 did not load](#the-saves-550-did-not-load) |
| Shipped-box save at 40 001 loaded under the canary `input` box, part-full D-D solo: row on which the box is full, against the control load's | 42 000, against 72 000 | 2026-10-05 | 2.0.77 | unresearched (11 rungs asserted off at build and at the canary load) | [The saves #550 did not load](#the-saves-550-did-not-load) |

[#542](https://github.com/trulsjo/realistic-fusion-refreshed/issues/542), following #531.
**Readings for a decision that is Truls's. This note changes no shipped prototype and does not
choose an option.**

The 2.0.77 docs for [`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html) say of
`production_type`: "input-output should only be used for boilers in fluid heating mode."
`rf-reactor` and `rf-aneutronic-reactor` each have an `input-output` plasma box on a boiler in
`output-to-separate-pipe` mode. #531 found what that box does, in
[The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split): every tick the box
pushes plasma back into the segment and pulls it out again. That is why the fuel line is two
stores, and why it fills in 2.3 times the fed model's time.

## How it was measured

`scripts/probe-plasma-input-box.ps1` runs one rig twice. The first run uses `rf-reactor` as it
ships. The second enables a canary mod. In its `data-final-fixes` the canary sets
`data.raw.boiler["rf-reactor"].fluid_box.production_type` to `"input"` and changes nothing else.
Each pipe connection keeps `flow_direction = "input-output"`. The canary refuses to load if the
box is not `input-output` before the change, so a canary that matched nothing cannot read as
"nothing changed".

**The canary is `rf-reactor` itself and not a copy under another name, because `control.lua`
identifies a reactor by name.** `REACTORS` in
`realistic-fusion-refreshed/scripts/entity-management.lua` decides what is registered, and
`SPECS` in `realistic-fusion-refreshed/control.lua` holds its constants.
`check_reactor_specs()` refuses to load when the two lists disagree. A renamed copy would be
built, but nothing would register or step it. So the two variants are two runs of the same rig,
not two reactors in one map.

**The run.** 2026-10-04, Factorio 2.0.77 (build 84539), run with no arguments: 100 000 ticks
per variant, sampled every 4000, so the last row is tick 96 000. D-D, one `rf-heater` per cell
with an unbounded feed, and reactor energy drained as it arrives. Nothing researched: all 11
rungs were asserted off in both runs. The cells are:

- **solo 3** and **solo 6**: one heater, three or six `rf-pipe`, and one reactor. This is
  `probe-plasma-segment.ps1`'s layout.
- **pair**: one heater and three `rf-pipe` into a reactor, then twelve more `rf-pipe` from its
  east face into a second reactor. Only the first reactor has power, which is asserted. This is
  `check-pooling.ps1`'s discriminator: an unpowered reactor steps with zero heating, so any
  heat it holds arrived through the pipe.

The box is read every tick, before and after `control.lua`'s handler. Two rig mods do this, in
the same arrangement `probe-plasma-segment.ps1` uses.

## Readings

### Does it load, and is it stepped?

**The game loads the canary without complaint.** The map was created with exit 0. The create
and the run printed no line containing "warning" or "error", in either variant. At runtime,
`prototypes.entity["rf-reactor"].fluidbox_prototypes[1].production_type` reads `input`.
`control.lua`'s load-time checks passed, because the map was created.

**`control.lua` still steps the canary and writes its box.** Every powered reactor's box changed
across the mod's handler on 15 978 of the 16 001 step ticks up to tick 96 000. That is the same
count as for the shipped box. No box changed on any other tick; if one had, the run would have
failed. The unpowered canary reactor in the pair changed on 205 of the 16 001; see the pair
below.

### One reactor: solo 3 and solo 6

The first column is what the segment beside the box holds, read through the run's first pipe.
The segment reports a capacity of 1300 at three pipes and 1600 at six in both variants.

| tick | shipped, 3 pipes: box | segment | shipped, 6 pipes: box | segment | canary, 3 pipes: box | segment | canary, 6 pipes: box | segment |
|---|---|---|---|---|---|---|---|---|
| 4 000 | 74.27 | 89.14 | 65.49 | 98.25 | 159.37 | 0 | 159.37 | 0 |
| 12 000 | 212.74 | 255.34 | 188.90 | 283.41 | 430.62 | 0 | 430.63 | 0 |
| 24 000 | 398.31 | 478.08 | 356.13 | 534.32 | 785.82 | 0 | 785.84 | 0 |
| 32 000 | 511.85 | 614.31 | 458.68 | 688.12 | 1000.00 | 31.59 | 1000.00 | 31.60 |
| 48 000 | 711.54 | 883.50 | 647.51 | 973.56 | 999.95 | 553.82 | 999.95 | 553.84 |
| 72 000 | 999.94 | 1300.00 | 902.72 | 1427.25 | 999.95 | 1300.00 | 999.95 | 1341.38 |
| 96 000 | 999.95 | 1300.00 | 999.95 | 1600.00 | 999.95 | 1300.00 | 999.95 | 1600.00 |

| | shipped, 3 pipes | shipped, 6 pipes | canary, 3 pipes | canary, 6 pipes |
|---|---|---|---|---|
| first tick the box reads 99.9% | 71 295 | 80 539 | 30 975 | 30 975 |
| box at tick 96 000 | 999.95 | 999.95 | 999.95 | 999.95 |
| box °C at tick 96 000 | 2.4174×10⁸ | 2.4208×10⁸ | 2.3815×10⁸ | 2.3815×10⁸ |

- **With the shipped box, the segment fills alongside it.** The segment held 1200 units for every
  1000 in the box through tick 32 000 at three pipes, and 1500 at six. That ratio rose to the
  capacity as the line filled. These are the figures #520 and #531 recorded.
- **With the canary box, the segment held 0 until the box was full.** Every sampled row read 0
  before then. After that, the line beside the box filled at 128.6 to 134.6 units per 4000 ticks,
  reaching 1300 by tick 72 000 at three pipes and 1600 by 80 000 at six.
- **The canary box fills 2.30 times faster at three pipes and 2.60 times faster at six**
  (71 295 / 30 975 and 80 539 / 30 975), and **the pipe count no longer matters**: the two canary
  boxes never differ by more than 0.03 units. The fed model, `M.settle_fed`, fills its box at
  31 000 ticks and settles at 2.381×10⁸ °C with nothing researched. Both figures are recorded
  in [Why the box fills slower than the fed model](exchanger-coverage.md#why-the-box-fills-slower-than-the-fed-model).
  The canary reads 30 975 and 2.3815×10⁸.
- **The canary box had settled by tick 44 000** and read 2.3814 or 2.3815×10⁸ °C at every row
  after that. The shipped box was still cooling at tick 96 000: 2.4185×10⁸ at 92 000 and
  2.4174×10⁸ at 96 000, at three pipes. This run says nothing about where it ends.
- A full box reads just under 1000 (999.9453 to 999.9469) at every 12 000th tick and 1000 at
  the samples between, in both variants. Why was not looked into.

### Two reactors bridged by pipe: the pair

The pair has three pipes from the heater to reactor 1, then twelve pipes to reactor 2. Only
reactor 1 has power. At both build and tick 96 000, both boxes, the heater's run and the bridge
report **one segment id in both variants**: 9 = 9 = 9 = 9. The segment reports a capacity of
3500.

| tick | shipped: box 1 | °C | box 2 | °C | canary: box 1 | °C | box 2 | °C | canary segment |
|---|---|---|---|---|---|---|---|---|---|
| 4 000 | 30.45 | 3.2713×10⁹ | 30.45 | 3.2151×10⁹ | 79.86 | 3.7253×10⁹ | 82.92 | 1.8779×10⁵ | 0 |
| 24 000 | 174.89 | 1.0184×10⁹ | 174.89 | 1.0036×10⁹ | 373.54 | 9.3651×10⁸ | 500.05 | 15 | 0 |
| 48 000 | 334.10 | 5.2010×10⁸ | 334.10 | 5.1234×10⁸ | 608.54 | 5.4177×10⁸ | 1000.00 | 15 | 0 |
| 72 000 | 487.51 | 3.2454×10⁸ | 487.51 | 3.1921×10⁸ | 999.95 | 2.3819×10⁸ | 1000.00 | 15 | 354.23 |
| 96 000 | 656.50 | 2.0330×10⁸ | 656.50 | 1.9721×10⁸ | 999.95 | 2.3815×10⁸ | 1000.00 | 15 | 1141.77 |

- **Shipped: one pool.** The two boxes hold the same amount to within 0.002 units at every row except
  76 000, where they read 524.17 and 525.47.
  The unpowered reactor stays within 3.0% of the powered one's temperature (1.9721 against
  2.0330×10⁸ at 96 000), which is heat that came through the pipe. Neither box reached 99.9% in
  100 000 ticks. That holds only while the line fills: see
  [Once the shipped line is full](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2). The segment held 2164.29 of its 3500 at tick 96 000.
- **Canary: one segment, but not one pool of heat.** The plasma still reaches both boxes: until
  tick 48 000, each box takes about half the heater's feed, and the unpowered box fills first at
  47 774. The powered box fills at 61 093. **Heat does not travel.** The unpowered box read
  1.8779×10⁵ °C at 4000 and has read 15 °C at almost every row since. That is the plasma's
  `default_temperature` and the spec's `min_temperature_c` floor, which `check_plasma_bounds()`
  requires to be equal. The two exceptions are 2748 °C at 16 000 and 1.2041×10⁴ at 8000.
  `control.lua` changed that box on only 205 step ticks, against 15 978 for the powered one.
  Once the powered box filled, it settled at 2.3815×10⁸, the same as a solo canary. Between
  48 000 and 61 093 the powered box took all of the feed, and then the segment started to fill.
- At tick 52 000, the canary segment read 0.96 where every other row before 64 000 read 0. That
  single reading is not explained.

### Past tick 96 000, both reactors powered, and a lone box

([#548](https://github.com/trulsjo/realistic-fusion-refreshed/issues/548).) The same probe with
two cells added after the pair, so every cell above is built first and keeps its segment id.
2026-10-04, Factorio 2.0.77 (build 84539), nothing researched (all 11 rungs asserted off in
both runs), sampled every 4000 ticks:

- **both**: the pair again, one heater, three `rf-pipe` and twelve more between the reactors,
  with the second reactor powered too (asserted to be on an electric network).
- **lone**: no heater, no pipe, no power. An unregistered copy of `rf-reactor`, so
  `control.lua` never steps it, seeded at tick 0 to its box's capacity of 1000 at 15 °C. That
  is the instrument `quality.md`'s 526.3158 was read on: `probe-quality-leak.ps1`'s cold cell.
  The copy is made after the canary, so it carries the variant's box. The runtime prototype
  reads `input-output` in the shipped run and `input` in the canary run.

`pwsh -File scripts/probe-plasma-input-box.ps1` read them to 96 000 ticks, and
`pwsh -File scripts/probe-plasma-input-box.ps1 -Ticks 600000` to 596 000. **The two runs print
the same box, segment and temperature on all 350 rows up to 96 000**, old cells included, so no
reading above moved.

**The settle test** is now the probe's own (`-Settle`, default 10⁻⁴): a temperature has settled
from the first row after which every row reads within 10⁻⁴ of the last row's. The canary solo
boxes pass it from tick 44 000, the figure the readings above give, in both runs.

#### The shipped box passes the settle test near the canary's, and is still moving

| 600 000 ticks, 1 heater | first row of the settle test | °C at 596 000 | box at 596 000 |
|---|---|---|---|
| shipped, 3 pipes | 580 000 | 2.382469×10⁸ | 1000.0000 |
| shipped, 6 pipes | 580 000 | 2.383660×10⁸ | 1000.0000 |
| canary, 3 pipes | 44 000 | 2.381386×10⁸ | 1000.0000 |
| canary, 6 pipes | 44 000 | 2.381386×10⁸ | 1000.0000 |

The shipped box passes the test only over its last 16 000 ticks, and has not stopped. At three
pipes it read 2.3986×10⁸ at 200 000, 2.3856×10⁸ at 400 000, 2.3828×10⁸ at 560 000 and
2.3825×10⁸ at 596 000. That is 3×10⁴ °C over the last 36 000 ticks, and the six-pipe box falls
the same 3×10⁴ (2.3840 to 2.3837×10⁸ from 572 000). **So 600 000 ticks give a box that passes
the test 0.05% (three pipes) and 0.10% (six) above the canary's 2.381386×10⁸, still
falling.** Where it ends was not read by that run.

**It ends on the canary's figure**
([#560](https://github.com/trulsjo/realistic-fusion-refreshed/issues/560)).
`pwsh -File scripts/probe-plasma-input-box.ps1 -Ticks 2000000 -Every 20000`, 2026-10-05,
Factorio 2.0.77 (build 84539), nothing researched (all 11 rungs asserted off), one heater a
cell, rows every 20 000 ticks to 1 980 000. The sampled rows repeat on a 12 000-tick cycle
against the heater, so a row is compared with the row 60 000 ticks before it, which is at the
same point of that cycle. The table prints five figures, so "the same" below means within
1×10⁴ °C, 4×10⁻⁵ of the reading.

| 2 000 000 ticks, 1 heater | °C at 1 980 000 | every later row reads the same as the one 60 000 before it, from | `-Settle` 10⁻⁴ passes from |
|---|---|---|---|
| shipped, 3 pipes | 2.381512×10⁸ | 1 160 000 | 800 000 |
| shipped, 6 pipes | 2.381512×10⁸ | 1 400 000 | 980 000 |
| canary, 3 pipes | 2.381512×10⁸ | 120 000 | 60 000 |
| canary, 6 pipes | 2.381512×10⁸ | 120 000 | 60 000 |

- **The shipped box and the canary box end on the same temperature**, at both pipe counts, to
  the seven figures the probe prints for a last row. The canary's 2.381386×10⁸ above is the
  same box on another row of the 12 000-tick cycle: at 1 960 000 all four read 2.3814×10⁸, and
  at 1 980 000 all four read 2.3815×10⁸.
- The shipped box takes far longer to get there. The canary's 120 000 is the earliest this
  comparison can report on rows 20 000 apart, and the 600 000-tick run had the canary settled
  by 44 000; against that the shipped box's 1 160 000 and 1 400 000 are about 26 and 32 times
  as long.
- **The settle test as written can pass a box that is still drifting, and did.** It asks that
  every row from some row on be within 10⁻⁴ of the LAST row, so any drift slower than that over
  the run's tail passes. It passed the 600 000-tick run from 580 000 with the box 0.05% high
  and falling, and it passes this run from 800 000 at three pipes, 360 000 ticks before the
  rows stop moving. A pass means "within 10⁻⁴ of where the run ended", not "stopped".

#### Two powered canary boxes on one line settle at the same temperature

| 600 000 ticks, 1 heater, 3 + 12 pipes | box 1 full at | box 2 full at | °C at 96 000, 1 and 2 | first settle row, 1 and 2 | °C at 596 000, both |
|---|---|---|---|---|---|
| canary | 89 651 | 88 694 | 2.3840 and 2.3826×10⁸ | 104 000 and 100 000 | 2.381386×10⁸ |
| shipped | 246 755 | 246 755 | 6.8839 and 6.8839×10⁸ | 592 000 and 584 000 | 2.371960 and 2.396459×10⁸ |

- **Canary: yes.** Both boxes settle at 2.381386×10⁸ at 596 000, the same figure as a solo
  canary box. The segment read 0 at every row until the boxes filled, then 148.45 at 96 000,
  2642.04 at 200 000 and its capacity of 3500 from 236 000. Each reactor is powered and heated by
  its own step here, so this says that each settles at the solo figure. It does not say that heat
  travels between them, which the unpowered pair above says it does not.
- **Shipped, for comparison: no.** The two boxes held the same amount to within 0.0021 units at
  every row except 100 000 (520.65 and 522.40), and the same temperature to the four figures the
  probe prints at every row until they filled at 246 755. From the fill on they draw apart:
  2.4344 and 2.4346×10⁸ at 248 000, 2.4042 and 2.4132×10⁸ at 300 000. At 596 000 they read
  2.3720 and 2.3965×10⁸, 1.0% apart, and both are still falling.
- **Run to 1 980 000 (#560), the two shipped boxes stay apart.** They read 2.368459 and
  2.394605×10⁸, 1.10% apart, and have read 1.10% apart at every checked row from 1 000 000
  (0.37% at 300 000, 1.03% at 600 000). They neither converge nor go on diverging. The first
  box sits 0.55% under the solo figure of 2.381512×10⁸ and the second 0.55% over it. Under the
  canary both read 2.381512×10⁸.
- **Why, as far as 600 ticks show: one of the two full boxes exports heat into the segment,
  and the other does not.** Read on the same day with
  `-Pipes 3 -Ticks 301000 -Every 4000 -Trace 300000,300600 -TraceCell both`, every tick from
  300 000 to 300 600, both boxes full. Over those 600 ticks the mod's step burned 5.4050 units
  in the first box and 5.4426 in the second, and the engine put the same amounts back. But the
  5.4426 units reaching the second box carried 1.0164×10⁹ unit-°C, which is 1.8675×10⁸ a unit,
  the segment's own temperature (1.8698 to 1.8649×10⁸ over the window). The 5.4050 reaching
  the first carried 7.1712×10⁸, only 1.3268×10⁸ a unit. A net inflow colder than the segment
  it comes from means the box also pushed its own, hotter plasma out: at the box's 2.4040×10⁸
  that is about 5.45 units pushed and 10.85 pulled, and 5.45 is what the other box drew. So
  the reading fits one box making room in a full segment as it refills, and the other pushing
  into that room before pulling back. A full line trades nothing in bulk, so a small
  one-way trade of this kind would hold the gap open instead of closing it. That it is the only
  coupling left was not shown.
- **The order is read since #572: the first reactor, then the heater, then the second
  reactor, which is the order this rig builds them in.** Built in another order, the order that
  fits is that one (#583). That the first box is taken before the second is what the heat
  implied; the heater's place between them is new. See
  [The order the engine takes the two boxes in](#the-order-the-engine-takes-the-two-boxes-in).

#### The order the engine takes the two boxes in

([#572](https://github.com/trulsjo/realistic-fusion-refreshed/issues/572).) The fitted
fixed-point rule of [`quality.md`](quality.md#the-1887-is-the-boxs-share-and-a-fitted-rule-reproduces-it)
predicts every tick of a fed line with one reactor (#564). Since #572 this probe's `-Fixed`
runs it beside the pair and beside both, one tick at a time. From the game's reading of one
tick, each box after the mod's step, the segment and what the heater has to give, it predicts
the next tick's two boxes, segment and heater in whole 2⁻²⁴ units, with every fill floored. A
box pushes and then pulls; the heater's output box pushes twice. It is run in all six orders
of the three, and a tick is a miss when any of the four figures differs at all. An order
names what is taken first: H the heater, 1 the first reactor, which is the one next to the
heater, and 2 the second.

`pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 300000 -Every 4000 -Trace 146000,151500 -Fixed`,
2026-10-05, Factorio 2.0.77 (build 84539), normal quality, nothing researched (all 11 rungs
asserted off), one heater a cell, three pipes to the first reactor and twelve between the two,
counted to the last row at 296 000. "Filling" is every tick until both boxes have read 99.9%,
and "full" every tick from then: 148 946 and 147 054 ticks for the pair with one reactor
unpowered, 246 755 and 49 245 with both powered. Each cell is ticks missed, and the first:

| order | one unpowered, filling | one unpowered, full | both powered, filling | both powered, full |
|---|---|---|---|---|
| H12 | 5004, tick 122 | 24 510, tick 149 049 | 8294, tick 122 | 8205, tick 246 842 |
| H21 | 146 162, tick 122 | 24 510, tick 149 049 | 243 561, tick 122 | 8208, tick 246 839 |
| **1H2** | **0** | **0** | **0** | **0** |
| 2H1 | 146 162, tick 122 | 24 510, tick 149 049 | 243 561, tick 122 | 8208, tick 246 839 |
| 12H | 5004, tick 122 | 165, tick 149 049 | 8294, tick 122 | 8194, tick 246 842 |
| 21H | 146 162, tick 122 | 165, tick 149 049 | 243 561, tick 122 | 8197, tick 246 839 |

- **One order misses no tick: the first reactor, the heater, the second reactor.** It misses
  none of 592 000 ticks, 296 000 in each cell, filling and full. Each of the other five
  misses in all four columns, from tick 122 while the line fills, as the first craft reaches
  the line. Their worst misses are 0.21 units filling and 0.10 full. No reading was off
  the 2⁻²⁴ grid.
- **It predicts the first box running colder, and the first box does.** With both powered and
  the line full, the order that fits has the first box push 468.69 units of its own plasma
  into the segment over the 49 245 ticks, and the second 19.90. In that order the first box
  is taken while the segment still has the room the second box's pull left on the tick
  before, and the heater refills that room before the second box is reached. That is the
  fitted rule's account, not a reading of the engine. The first box reads
  2.405249×10⁸ °C at 296 000 and the second 2.413716×10⁸, 0.35% apart, the first colder, as
  it is at every row from 248 000, the first after the fill. The gap is still widening at
  296 000; #560 read it at 1.10% from 1 000 000. This is the trade #560 inferred from 600
  ticks of heat.
- With one reactor unpowered and the line full, the fitting order has the two boxes push
  11.29 and 10.29 units in 147 054 ticks: a box at 15 °C burns nothing, so it makes no room.
- **1H2 is also the order the rig builds them in, and the order that fits follows the build**
  ([#583](https://github.com/trulsjo/realistic-fusion-refreshed/issues/583)); see
  [Built in another order](#built-in-another-order).
- Under the canary no order fits. With one reactor unpowered, none misses fewer than 60 971
  of 61 093 ticks filling or 106 584 of 234 907 full. The rule is the `input-output` box's,
  so that is a reading of the canary and not of the rule.
- It is still a **fitted** rule. What is shown is that one order of it predicts the game on
  every tick read, not that the engine computes it so.

##### Built in another order

([#583](https://github.com/trulsjo/realistic-fusion-refreshed/issues/583).) Since #583 the
probe's `-BuildOrder` places a two-reactor cell's three parts in any order: 1 the first
reactor, H the heater and the pipes from it to the first reactor, 2 the bridge and the second
reactor. The layout on the ground is the same in every order, and the segment ids read one
segment per cell in each. `-NoCanary` runs the shipped variant alone.
`pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 300000 -Every 4000 -Fixed -NoCanary -BuildOrder <order>`,
2026-10-14, Factorio 2.0.77 (build 84539), normal quality, nothing researched (all 11 rungs
asserted off), one heater a cell, three pipes to the first reactor and twelve between the two,
counted to 296 000. The fill ticks are those of the 1H2 run to within three ticks, so
"filling" and "full" split the ticks as above: 148 946 and 147 054 with one reactor unpowered
(148 943 and 147 057 built 2H1), 246 755 and 49 245 with both powered. #572's table above
is the 1H2 build. Each cell is ticks missed, and the first:

Built 21H:

| order | one unpowered, filling | one unpowered, full | both powered, filling | both powered, full |
|---|---|---|---|---|
| H12 | 146 174, tick 122 | 24 510, tick 149 049 | 243 500, tick 122 | 16 377, tick 246 840 |
| H21 | 5004, tick 122 | 24 510, tick 149 049 | 8294, tick 122 | 16 374, tick 246 842 |
| 1H2 | 146 174, tick 122 | 165, tick 149 049 | 243 500, tick 122 | 8198, tick 246 840 |
| 2H1 | 5004, tick 122 | 24 510, tick 149 049 | 8294, tick 122 | 16 374, tick 246 842 |
| 12H | 146 130, tick 123 | 11, tick 149 050 | 243 442, tick 123 | 8196, tick 246 840 |
| **21H** | **0** | **0** | **0** | **0** |

Built 12H:

| order | one unpowered, filling | one unpowered, full | both powered, filling | both powered, full |
|---|---|---|---|---|
| H12 | 5004, tick 122 | 24 511, tick 149 049 | 8294, tick 122 | 16 374, tick 246 842 |
| H21 | 146 126, tick 122 | 24 511, tick 149 049 | 243 500, tick 122 | 16 377, tick 246 840 |
| 1H2 | 5004, tick 122 | 192, tick 149 049 | 8294, tick 122 | 16 374, tick 246 842 |
| 2H1 | 146 126, tick 122 | 24 502, tick 149 049 | 243 500, tick 122 | 8198, tick 246 840 |
| **12H** | **0** | **0** | **0** | **0** |
| 21H | 146 078, tick 123 | 12, tick 149 050 | 243 442, tick 123 | 8196, tick 246 840 |

Built 2H1:

| order | one unpowered, filling | one unpowered, full | both powered, filling | both powered, full |
|---|---|---|---|---|
| H12 | 146 163, tick 122 | 183, tick 149 053 | 243 561, tick 122 | 8208, tick 246 839 |
| H21 | 5004, tick 122 | 192, tick 149 049 | 8294, tick 122 | 8205, tick 246 842 |
| 1H2 | 146 163, tick 122 | 24 511, tick 149 049 | 243 561, tick 122 | 8208, tick 246 839 |
| **2H1** | **0** | **0** | **0** | **0** |
| 12H | 146 163, tick 122 | 24 501, tick 149 049 | 243 561, tick 122 | 8197, tick 246 839 |
| 21H | 5004, tick 122 | 24 501, tick 149 049 | 8294, tick 122 | 8194, tick 246 842 |

- **In each build exactly one order misses none of 592 000 ticks, and it is the build
  order.** Every other order misses in all four columns. So on this rig the order that fits
  follows the order the parts were placed in, and not their position: the second reactor is
  east of the first in all four builds. That is the fitted rule's account, not a reading of how
  the engine orders them.
- **The colder box on the full line is the one the fitting order takes just before the
  heater.** Built 1H2 and 2H1 that is also the box it takes first; built 21H and 12H it is not,
  so it is the place before the heater that names the box, and not the place first. That box pushes 468.69 units of its own plasma into
  the full line over the 49 245 ticks, and the other 19.90 to 20.01, in every build. With both
  powered the two boxes read 2.4052 and 2.4137×10⁸ °C at 296 000 in each:

  | built | box 1 at 296 000 | box 2 | colder | taken first by the fitting order |
  |---|---|---|---|---|
  | 1H2 | 2.405249×10⁸ | 2.413716×10⁸ | box 1, just before the heater | box 1 |
  | 21H | 2.4052×10⁸ | 2.4137×10⁸ | box 1, just before the heater | box 2 |
  | 12H | 2.4137×10⁸ | 2.4052×10⁸ | box 2, just before the heater | box 1 |
  | 2H1 | 2.4137×10⁸ | 2.4052×10⁸ | box 2, just before the heater | box 2 |

  That is the fitted rule's account of #572's trade: the box taken just before the heater
  meets a segment the heater has not yet refilled.
- **With one reactor unpowered, the build moves where the unpowered box ends.** Built 1H2 or
  21H, it is the box taken first or third, and it reads 15 °C from tick 150 012 to 296 000.
  Built 12H or 2H1 it is the box taken just before the heater, and it never reads 15 °C full:
  1.1225×10⁴ °C at 152 000 built 12H and 1.1226×10⁴ built 2H1, and 3.1011×10³ at 296 000, between 1.083×10³ and 1.303×10⁴ at every
  row from 152 000, beside a powered box at 2.39×10⁸. In those two builds the fitting order has
  it push 1313.77 and 1314.08 units into the full line over 147 054 and 147 057 ticks, against
  the 10.29 and 10.39 the unpowered box pushes at the floor, built 1H2 and 21H. Why that holds it above the floor was not read.

##### On the aneutronic reactor

([#584](https://github.com/trulsjo/realistic-fusion-refreshed/issues/584).)
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-he3-he3-plasma -Pipes 3 -Ticks 500000 -Every 4000 -Fixed -Trace 200000,206000 -NoCanary`,
2026-10-14, and again on 2026-10-15 with every reading the same, Factorio 2.0.77 (build 84539), normal quality, He3-He3 into `rf-aneutronic-reactor`,
nothing researched (all 11 rungs asserted off), one heater a cell, three pipes to the first
reactor and twelve between the two, built 1H2, counted to 496 000. The fill ticks are #571's:
324 192 ticks filling and 171 808 full for the pair with one reactor unpowered, 325 354 and
170 646 with both powered. Each cell is ticks missed, and the first:

| order | one unpowered, filling | one unpowered, full | both powered, filling | both powered, full |
|---|---|---|---|---|
| H12 | 10 899, tick 122 | 60, tick 324 369 | 10 938, tick 122 | 60, tick 325 460 |
| H21 | 272 811, tick 122 | 60, tick 324 369 | 278 477, tick 122 | 53, tick 325 460 |
| **1H2** | **0** | **0** | **0** | **0** |
| 2H1 | 272 811, tick 122 | 60, tick 324 369 | 278 477, tick 122 | 60, tick 325 460 |
| 12H | 10 899, tick 122 | 30, tick 324 369 | 10 938, tick 122 | 30, tick 325 460 |
| 21H | 272 811, tick 122 | 30, tick 324 369 | 278 477, tick 122 | 30, tick 325 460 |

- **The same order fits on a 3000-unit box: 1H2, the build order, misses none of 992 000
  ticks.** No reading was off the 2⁻²⁴ grid. Every other order misses in all four columns,
  but on the full line by 30 to 60 ticks, where on D-D they miss by thousands.
- **On the full line the fitting order has the two boxes push almost the same.** With both
  powered the first box pushes 22.39 units into the line over the 170 646 ticks and the second
  19.38; with one unpowered, 28.34 and 25.34 over 171 808. On D-D the first pushes 468.69
  against the second's 19.90 in 49 245 ticks.
- **On the fitted rule's account, that is why the two powered boxes end on one temperature.**
  A He3-He3 box burns almost nothing, so neither box makes room in the full line and neither
  trades its own plasma for the segment's. On D-D the box taken just before the heater burns,
  gives 468.69 units and runs colder. Both He3-He3 boxes read 3.105680×10⁶ °C from 328 000 to
  496 000, within the settle test's 10⁻⁴. This is the rule's account, not a reading of the
  engine.

#### Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2

Every run in this section built its cell 1H2: the first reactor, then the heater, then the
second. **Built 12H or 2H1, where the unpowered reactor is placed just before the heater, it
does not fall to the floor**, and reads 1.083×10³ to 1.303×10⁴ °C on the full line (#583); see
[Built in another order](#built-in-another-order).

The 600 000-tick run also read the shipped pair with one reactor powered past 96 000. The two
boxes fill together at 148 946 and 148 939. The unpowered reactor read 3.5294×10⁷ °C at 148 000
and **15 °C at 152 000 and at every row after that**, to 596 000. The powered reactor read
2.3859×10⁸ at 596 000. `control.lua` changed the unpowered box on 24 975 of the 99 334 step ticks.
So the heat this rig reads travelling along the shipped pipe travels only while the line is
filling.

**Why: a full box and a full segment stop trading, and the mod's own step cools a box it does
not heat** ([#558](https://github.com/trulsjo/realistic-fusion-refreshed/issues/558)). The pair
was read every tick from 146 000 to 151 500 by
`pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 152000 -Every 1000 -Trace 146000,151500`
on 2026-10-05, Factorio 2.0.77 (build 84539), nothing researched, one heater, three pipes and
twelve. Each box is read before and after `control.lua`'s handler, so what moved between one
tick's second reading and the next tick's first is the engine, and the rest is the mod's step.
Heat is counted as units × °C. The earlier rows are from the same command with
`-Ticks 156000` and no trace.

The two temperatures do not part on one tick. They draw apart as the line fills:

| tick | box, of 1000 | segment, of 3500 | powered box °C | unpowered box °C | unpowered ÷ powered |
|---|---|---|---|---|---|
| 64 000 | 437.07 | 1486.11 | 3.7500×10⁸ | 3.7108×10⁸ | 0.990 |
| 96 000 | 656.50 | 2164.29 | 2.0330×10⁸ | 1.9721×10⁸ | 0.970 |
| 120 000 | 807.72 | 2752.34 | 1.3966×10⁸ | 1.2979×10⁸ | 0.929 |
| 136 000 | 913.19 | 3162.45 | 1.1327×10⁸ | 9.4149×10⁷ | 0.831 |
| 144 000 | 966.03 | 3367.98 | 1.1353×10⁸ | 6.9550×10⁷ | 0.613 |
| 146 000 | 979.70 | 3421.12 | 1.2041×10⁸ | 5.7859×10⁷ | 0.481 |
| 148 000 | 993.24 | 3473.81 | 1.4093×10⁸ | 3.5294×10⁷ | 0.250 |

The unpowered box first reads under a tenth of the powered one's temperature on tick 148 896,
under a hundredth on 149 616, and 15 °C on tick 150 012.

- **The trade shrinks to nothing as the line fills, as #531's rule says it must.** The rule is a
  push of 100 × min(box fill, 1 − segment fill) and a pull of 100 × min(segment fill, 1 − box
  fill). For the unpowered box it gives 2.254 units a tick each way at 146 000, 0.928 at
  147 832, 0.231 at 148 748 and 0 at 149 206. The engine last moved that box on tick 149 982.
- **The rule predicts what the engine moved.** Applied to each box alone, it is within 0.001
  units of the engine's move on 5123 of the 5500 ticks for the unpowered box and 4956 for the
  powered one. The worst misses are 0.093 units on tick 146 041 and 0.087 on 149 054. By scratch
  arithmetic over the same trace rows, which the probe does not print: the 199 ticks on which
  the unpowered box misses by more than 0.01 come in pairs 120 ticks apart, which is the
  heater's cycle, and running the two boxes in either order moves neither worst miss. A craft
  landing in the segment inside the tick is what the rule, applied to one box against the
  segment as it stood, does not see.
- **The heat went into the mod's step.** Over the window the unpowered box held 5.6685×10¹⁰
  unit-°C at the start. The engine brought it 1.4119×10¹¹ more, and `control.lua`'s step took
  1.9788×10¹¹ out, leaving 1.5×10⁴: 1000 units at 15 °C. An unpowered reactor is stepped with no
  heating, so the step only loses. Radiation takes two thirds of that and the confinement loss
  one third; see [Which of the step's terms takes it](#which-of-the-steps-terms-takes-it).
- **The segment keeps its heat.** It read 8.9182×10⁷ °C at 146 000 and 8.6240×10⁷ at 151 496.
  From tick 150 012 the unpowered box sits at 15 °C beside a segment at 8.6×10⁷ and a powered
  box at 2.2×10⁸, and nothing moves between them.
- The powered box is the same trade seen from the other side. The engine took 1.3779×10¹¹
  unit-°C out of it over the window and its step put 2.4075×10¹¹ in. Once the trade stops it
  keeps everything it is given, which is why it climbs from 1.2041×10⁸ to 2.2094×10⁸ over the
  window.

This is the hot tail #530 found on a solo line, in
[The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split), with a second
reactor on the cold end of it.

##### Which of the step's terms takes it

([#570](https://github.com/trulsjo/realistic-fusion-refreshed/issues/570).) `M.step` in
`realistic-fusion-refreshed/scripts/reactor-logic.lua` moves an unheated plasma's heat in four
ways, and returns none of them: it returns a temperature and a burn. Since #570 the probe's
`-Trace` reads them off the step itself, so that nothing is worked out twice. Beside every step
tick of the window it calls `M.step` with the unpowered box's reading before the mod, the
shipped spec and no heating, and calls it again with a spec whose `confinement_time_s` is
infinite. Heat is units × °C, as above.

- **ash**: what was burnt, at the temperature it was burnt at. Burnt fuel leaves with its share
  of the heat, so this lowers the amount and not the temperature.
- **confinement**: what the second call keeps and the first does not.
- **charged fusion heating**: the charged share of the step's fusion power. It heats the
  plasma, so it is a gain. Joules are turned into unit-°C by the step's own heating: what one
  paid joule raises a unit by.
- **radiation**: whatever else the second call lost, which in `M.step` is bremsstrahlung.

`pwsh -File scripts/probe-plasma-input-box.ps1 -Pipes 3 -Ticks 300000 -Every 4000 -Trace 146000,151500 -Fixed`,
2026-10-05, Factorio 2.0.77 (build 84539), nothing researched (all 11 rungs asserted off), one
heater, three pipes and twelve. The window is the 5500 ticks #558 traced, and the mod steps on
916 of them, 146 004 to 151 494. It is the shipped pair's unpowered box:

| term | unit-°C removed over the 916 steps | of the total |
|---|---|---|
| radiation | 1.3011×10¹¹ | 65.8% |
| confinement, at the shipped 30 s | 6.9484×10¹⁰ | 35.1% |
| ash | 1.8393×10⁷ | 0.01% |
| charged fusion heating, a gain | −1.7341×10⁹ | −0.9% |
| the one step that lands on the floor | 1.3244×10⁵ | under 0.001% |
| **sum** | **1.9788×10¹¹** | |
| the trace's reading, #558 | 1.9788×10¹¹ | |

The sum agreeing with the trace checks the total and not the split: the four terms add up to
what the step removed by construction, and the charged heating is added into radiation and
taken out again, so a wrong joule conversion would move those two rows together and leave the
sum alone.

- **Radiation takes 65.8% of the heat and the confinement loss 35.1%.** The box is at full
  density and cooling, which is where bremsstrahlung, going as density squared, is at its
  largest beside a loss that goes as the heat held.
- The step that lands on the floor is counted apart. `M.step` scales its two losses to what
  the plasma has left above 15 °C, and the second call is scaled differently, so their
  difference no longer says which term took what on that step.
- **The pure simulation reproduces the box on every one of the 916 steps**, of which the last
  247, from 150 018, are a box already at 15 °C, where there is nothing to miss. Its temperature
  is within 2⁻²³ of the game's reading after the mod on all 916, and its amount within 2⁻²⁴
  units. The worst temperature miss is 5.90×10⁻⁸ of the reading, on tick 149 208, and the
  worst amount miss 5.96×10⁻⁸ units. Those are the sizes of a single-precision temperature
  and of the 2⁻²⁴-unit amounts [`quality.md`](quality.md) fitted, so the misses are the
  write and not the arithmetic.
- **A box held full and left unheated reaches the floor in 1818 ticks from the traced
  temperature, and radiation sets that time.** Run on from the box's 5.7859×10⁷ °C on tick
  146 000, with 1000 units held and nothing else moving, `M.step` reads 15 °C after 303
  steps, 30.3 s. Of the 5.7861×10¹⁰ unit-°C it removes, radiation takes 4.0813×10¹⁰ (70.5%)
  and confinement 1.7324×10¹⁰ (29.9%). With no confinement loss the same run takes 397
  steps, 2382 ticks. Confinement alone was not run, because the spec has no field that turns
  radiation off; by arithmetic it is a 30 s exponential, 30 × ln(5.7859×10⁷ K / 288 K) =
  366 s, about 22 000 ticks, some nine times the 2382 radiation alone takes.
- The traced box took 4012 ticks, 146 000 to 150 012, where the full unheated box takes 1818,
  because the engine brought it 1.4119×10¹¹ unit-°C over the window, 2.5 times what it held.

**It is not this one rig's**
([#559](https://github.com/trulsjo/realistic-fusion-refreshed/issues/559)). The same probe on
2026-10-05, Factorio 2.0.77 (build 84539), one heater and three pipes to the first reactor,
only the first reactor powered (asserted), rows every 2000 ticks. Each of the last four runs
is `-Pipes 3 -Every 2000` and the arguments its row names:

| shape | run | pipes between reactors | segment capacity | unpowered box full at | first row at 15 °C | powered box, last row |
|---|---|---|---|---|---|---|
| pair, nothing researched | 152 000 ticks, traced | 12 | 3500 | 148 939 | tick 150 012 | 2.2094×10⁸ °C at 151 496 |
| pair, nothing researched | `-Bridge 20 -Ticks 210000` | 20 | 4300 | 170 543 | 172 000 | 2.3947×10⁸ at 208 000 |
| pair, nothing researched | `-Bridge 30 -Ticks 260000` | 30 | 5300 | 197 547 | 200 000 | 2.3944×10⁸ at 258 000 |
| pair, heating rung 5 and no other | `-Rungs heating_ladder=5 -Ticks 240000` | 12 | 3500 | 179 299 | 182 000 | 4.4330×10⁸ at 238 000, still falling |
| three reactors, nothing researched | `-Trio -Ticks 280000` | 12 and 12 | 5700 | 224 297, both | 226 000, both | 2.3887×10⁸ at 278 000 |

In every shape, each built 1H2, the unpowered reactor reads 15 °C within 2800 ticks of its box
filling, and at every row after. The first row is the traced run of #558, where the tick is exact. In the
others it is the first 2000-tick row after the fill for twenty pipes and for three reactors,
and the second for thirty pipes and for heating rung 5, whose rows at 198 000 and 180 000 were
still above the floor. The three-reactor run's two unpowered boxes read 5.4122 and
5.4110×10⁷ at 200 000, 0.02% apart, and reach the floor on the same row. Under the canary the
last four runs read under 4000 °C in every unpowered box at every row from 16 000, and 15 °C at
every row from 30 000.

**What this says about `scripts/check-pooling.ps1`, by reading it and not by running it past a
fill.** No cell of the check reaches a full line as it ships. Its cells are seeded and have no
heater; it runs 1801 ticks; and its `pair`, `trio` and `five` cells assert that "the pool ran
down, so nothing was holding it up", which requires the run to be under 99.9% of capacity. They
read 47.33%, 44.64% and 42.68% of capacity left as shipped. So the check passes 125 of 125 on
pooling as it is while a line has room, and says nothing about a full one. On a full line the
probe's readings would fail these rows of `pair`, `trio` and `five`, were a cell held there:

- "the pool ran down, so nothing was holding it up": a full line is 100% of capacity.
- "and far above the seed, so the pool carried heat to them": the unpowered reactors read 15 °C.
- "the powered reactor runs a little above the run, not away from it": 2.2×10⁸ °C against 15.

"every unpowered reactor on the run is at one temperature" would still pass, at 15 °C, and
"every box holds its share of one pool, not its own contents" would pass on amounts, since a
full line has every box full. Neither would be evidence of pooling there. #559 changed no gate.

#### The lone box

| 600 000 ticks, 0 heaters, 0 pipes | box at 0 | box from 4000 to 596 000 | its segment | °C |
|---|---|---|---|---|
| shipped (`input-output`) | 1000.0000 | 526.3158 | 473.6842 | 15 |
| canary (`input`) | 1000.0000 | 1000.0000 | 0 | 15 |

The shipped copy reproduces `quality.md`'s 526.3158 to the digit, and its segment holds 0.9 of
the box, which is the control row. **The canary box keeps all 1000 it was seeded with**, and its
segment holds nothing at any row. The segment reports a capacity of 1000 in both runs. Neither
box is written by `control.lua`: 0 of 99 334 step ticks.

### The aneutronic reactor

([#562](https://github.com/trulsjo/realistic-fusion-refreshed/issues/562).) The probe takes
`-Plasma` since #562, and the canary and the lone copy follow the reactor that burns it.
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-d-he3-plasma -Pipes 3 -Ticks 500000 -Every 4000`
on 2026-10-05, Factorio 2.0.77 (build 84539): D-He3 into `rf-aneutronic-reactor` and its
3000-unit box, one heater per cell, nothing researched (all 11 rungs asserted off in both runs),
rows every 4000 ticks to 496 000. The canary refuses to load unless the box was `input-output`.

**It loads, and it is stepped.** Neither run printed a line naming a warning or an error. The
runtime prototype's box reads `input-output` in the shipped run and `input` in the canary run,
and the lone copy reads the same. `control.lua` changed every powered box across its handler on
82 644 of the 82 667 step ticks, in both variants.

**One heater does not fill this box, in either variant.** No box in a heated cell reaches 99.9%
of 3000. Each settles into a cycle its rows repeat every 12 000 ticks, which is the 4000-tick
sampling against the heater's 120-tick cycle. The ranges below are the three rows of that cycle
from 468 000 to 496 000.

| 500 000 ticks, 1 heater, 3 pipes | box, of 3000 | segment beside it, of 3300 | box °C | box at 32 000 | at 64 000 |
|---|---|---|---|---|---|
| shipped | 467.54 to 469.12 | 499.54 to 501.47 | 4.4074 to 4.4220×10⁹ | 415.47 | 465.87 |
| canary | 466.91 to 469.52 | 0 to 0.88 | 4.4034 to 4.4281×10⁹ | 465.95 | 469.52 |

- The box ends in the same place. The canary gets there in about half the time, and holds
  nothing beside it: the shipped line keeps 1068 to 1069 units in the segment for every 1000 in
  the box, 0.2% over the low branch of #531's rule at this size, (3300 − 100) / 3000 = 1.0667.
- So there is no fill tick to quote, and the fed model's figures for this reactor were not
  compared.

**The pair, one reactor unpowered, three pipes and twelve, segment capacity 7500:**

| | powered box | °C | unpowered box | °C | segment |
|---|---|---|---|---|---|
| shipped, 64 000 | 310.57 | 4.1221×10⁹ | 310.58 | 4.0641×10⁹ | 767.29 |
| shipped, 468 000 to 496 000 | 324.99 to 325.71 | 4.1014 to 4.1143×10⁹ | 324.98 to 325.71 | 4.0461 to 4.0512×10⁹ | 802.64 to 804.69 |
| canary, 64 000 | 341.72 | 4.9181×10⁹ | 1332.50 | 15 | 0 |
| canary, 468 000 to 496 000 | 467.02 to 469.32 | 4.4052 to 4.4270×10⁹ | 3000.00 | 15 | 0 to 1.20 |

- **Shipped: heat travels, and goes on travelling.** The unpowered box reads within 1.6% of
  the powered one at every row of the last cycle, and `control.lua` changes it on 82 644 step
  ticks, the same count as a powered one: it is hot enough to burn what reaches it. The line
  never fills, so the full-line loss
  [read on `rf-reactor`](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2)
  is not reached here. He3-He3 fills this reactor's line; see
  [An aneutronic line that fills](#an-aneutronic-line-that-fills-he3-he3).
- **Canary: heat does not travel.** The unpowered box read 4.1473×10⁴ °C at 4000 and 15 °C at
  every row from 8000. It takes plasma all the same, and is full, at 3000 units of cold plasma,
  from tick 143 901. `control.lua` never changed it: 0 of 82 667 step ticks. The powered box
  holds 341.72 at 64 000 while its neighbour fills, 403.02 at 148 000 once it has, and the solo
  figures by the last cycle.
- Both reactors powered: the shipped boxes read 341.36 and 341.37 at 160 000, at 4.9244 and
  4.9243×10⁹ °C; the canary's 341.89 and 341.87, at 4.9172 and 4.9175×10⁹.

**The lone box**, seeded with 3000 units at 15 °C: the shipped copy holds 1525.4238 beside
1474.5762 in its segment from the first row to 496 000, which is #531's rule again,
3000² / (2 × 3000 − 100) = 1525.4237. The canary copy keeps all 3000.

#### An aneutronic line that fills: He3-He3

([#571](https://github.com/trulsjo/realistic-fusion-refreshed/issues/571).) **What it took
was the other plasma, and no more heaters.** The probe was not changed to build it.
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-he3-he3-plasma -Pipes 3 -Ticks 500000 -Every 4000`
on 2026-10-05, Factorio 2.0.77 (build 84539): He3-He3 into `rf-aneutronic-reactor` and its
3000-unit box, one heater per cell, three pipes to the first reactor and twelve between the
two of a pair, nothing researched (all 11 rungs asserted off in both runs), rows every 4000
ticks to 496 000. A He3-He3 reactor burns almost none of its feed, so the line fills. One
heater holds a D-He3 box at 467 to 470 of 3000; 41 at normal quality fill its line, and it is cold, in
[A D-He3 line that fills is cold](#a-d-he3-line-that-fills-is-cold). The fill ticks are exact, read every tick; the first tick a full box
reads 15 °C is exact too, since #571. A fill tick here is the first tick the box reads 99.9%.
[`quality.md`](quality.md) and [`exchanger-coverage.md`](exchanger-coverage.md) give the same
three-pipe line 151 562, which is another measure:
the end of the first heater cycle to close at 99.9%.

| 500 000 ticks, 1 heater | solo, 3 pipes, segment 3300 | pair, one powered: powered box | unpowered box | both powered: box 1 | box 2 |
|---|---|---|---|---|---|
| shipped: box first at 99.9% of 3000 | 151 531 | 324 192 | 324 190 | 325 354 | 325 353 |
| shipped: °C from the first row after the fill to 496 000 | 3.1057×10⁶ | 3.1057×10⁶ | 15 | 3.1057×10⁶ | 3.1057×10⁶ |
| canary: box first at 99.9% | 72 162 | 144 377 | 143 901 | 144 617 | 144 616 |
| canary: °C from the first row after the fill to 496 000 | 3.1057×10⁶ | 3.1057×10⁶ | 15 | 3.1057×10⁶ | 3.1057×10⁶ |

Every heated cell's box reads 3000.0000 at every row after its fill, and every segment its
capacity by 496 000: 3300 for the solo cell and 7500 for a pair.

- **Solo.** The shipped box fills at 151 531 and reads 3.1057×10⁶ °C at every row from
  152 000. The canary box fills at 72 162, 2.10 times sooner, holds under one unit beside it until
  then, and ends on the same temperature.
- **The shipped pair's unpowered reactor is at the floor once the line is full, and on every
  row after.** Its box fills on tick 324 190 and first reads 15 °C full on tick 324 192. It
  reads 15 °C at all 44 rows from 324 000 to 496 000, beside a powered box at 3.1057×10⁶.
- **On this plasma it was nearly there before the fill.** The unpowered box is at 0.922 of the
  powered one's temperature at 64 000 (3.0033×10⁸ against 3.2561×10⁸), 0.653 at 128 000, 0.184
  at 192 000 and 0.018 at 256 000 (1.1019×10⁵ against 6.0877×10⁶). Its first row at 15 °C is
  252 000, with the box at 2340.99 of 3000. From there to the fill its rows repeat on the
  12 000-tick cycle against the heater: 15 °C at 264 000, 276 000 and so on to 324 000, and
  between 1.6×10³ and 1.1×10⁵ at the rows between. So the parting is the gradual one #558
  read on `rf-reactor`, on a line whose powered reactor is itself only at 3 to 6×10⁶ °C by
  then. The fill ends it; it does not cause it.
- **Both powered, the two shipped boxes end on one temperature.** They fill at 325 354 and
  325 353 and both read 3.1057×10⁶ °C from 328 000, the solo figure. The 1.10% the two
  `rf-reactor` boxes hold apart on D-D was not seen here to the five figures printed.
- **Canary.** The unpowered box reads 1.7497×10⁴ °C at 4000 and 15 °C at every row from
  8000, fills with cold plasma at 143 901, and first reads 15 °C full on 143 904. The powered
  box beside it fills at 144 377. Both powered, they fill at 144 617 and 144 616 and read
  3.1057×10⁶.
- **The lone box**, seeded with 3000 units at 15 °C, reads as it did on D-He3: 1525.4238
  beside 1474.5762 shipped, all 3000 under the canary.

##### What cools the unpowered He3-He3 box before the fill

([#585](https://github.com/trulsjo/realistic-fusion-refreshed/issues/585).) The run of
[On the aneutronic reactor](#on-the-aneutronic-reactor) traced the shipped pair every tick from
200 000 to 206 000, where the unpowered box falls against its neighbour: from 0.156 of the
powered box's temperature at 200 000 to 0.124 at 206 000, on the way from #571's 0.184 at
192 000 to 0.018 at 256 000. 2026-10-14 and 2026-10-15, Factorio 2.0.77 (build 84539), nothing researched
(all 11 rungs asserted off), one heater, three pipes and twelve, segment capacity 7500. The
mod steps on 1000 of the 6000 ticks.

| tick | box 1, powered | °C | box 2, unpowered | °C | segment | °C |
|---|---|---|---|---|---|---|
| 200 000 | 1868.92 | 1.0103×10⁷ | 1868.92 | 1.5807×10⁶ | 4574.83 | 5.8273×10⁶ |
| 203 000 | 1896.17 | 9.8132×10⁶ | 1896.17 | 1.3722×10⁶ | 4645.32 | 5.5791×10⁶ |
| 206 000 | 1923.43 | 9.5386×10⁶ | 1923.43 | 1.1860×10⁶ | 4715.81 | 5.3493×10⁶ |

Box 2's lowest reading in the window is 1.0205×10⁶ °C, on tick 205 998, and the trace's
rows 500 ticks apart read between 1.0481×10⁶ and 1.7191×10⁶; the rows above are three of
them.

| term | unit-°C removed from box 2 over the 1000 steps | of the total |
|---|---|---|
| radiation | 9.4668×10¹¹ | 99.43% |
| confinement, at the shipped spec | 5.3830×10⁹ | 0.57% |
| ash | 6.4×10⁻⁵⁴ | 0 |
| charged fusion heating, a gain | −6.2×10⁻⁵⁰ | 0 |
| **sum** | **9.5206×10¹¹** | |
| the trace's reading of the step | 9.5206×10¹¹ | |

- **Radiation takes 99.43% of what the step removes**, against 65.8% on D-D at its fill. The
  box burns nothing: ash and charged heating are under 10⁻⁴⁹ unit-°C, and the step changed its
  amount by 0.0000 units over the window.
- **The pure simulation reproduces the box on all 1000 steps**: its temperature within 2⁻²³
  of the game's reading after the mod and its amount within 2⁻²⁴ units on every one. The worst
  temperature miss is 5.76×10⁻⁸ of the reading, on tick 205 308, and the worst amount miss 0.
- **The engine brought the box 9.5139×10¹¹ unit-°C over the window, and the step removed
  9.5206×10¹¹.** The box held 2.9541×10⁹ at 200 000 and 2.2811×10⁹ at 206 000. So in 6000
  ticks 322 times what it held went through it, from the segment and out as radiation. The
  powered box is the other side: the engine took 9.4971×10¹¹ out of it and its step put
  9.4917×10¹¹ in.
- **The engine's trade is #531's rule: what arrives is not less than the rule says.** The rule
  is within 0.001 units of the engine's move on 5850 of the 6000 ticks for box 2 and all 6000
  for box 1; the worst miss is 0.048 units, on tick 200 401. It trades 39.00 units each way a
  tick at 200 000 and 37.12 at 206 000, so the box swaps its contents with a segment at about
  four times its temperature every 48 ticks. So the heat that arrives is what the rule's trade
  carries, and none of the box's fall is heat the engine withholds. Over the window the trade
  shrinks by 4.8% and the segment it is with cools by 8.2%, from 5.8273×10⁶ °C to
  5.3493×10⁶; which of the two moves the box more was not separated.
- **Held full and unheated, the box reaches the floor in 3 steps, 18 ticks.** Run on in
  `M.step` from its 1.5807×10⁶ °C at 200 000 with 3000 units held, the box's capacity, it
  reads 15 °C after 3 steps, with the confinement loss or without it. On D-D the same descent
  takes 303 steps. Radiation alone empties it, so a He3-He3 box is above the floor only while
  the trade feeds it. On this reading that is why its parting is gradual and not, as on D-D,
  at the fill.

#### A D-He3 line that fills is cold

([#586](https://github.com/trulsjo/realistic-fusion-refreshed/issues/586).) Since #586 the
probe's `-Heaters` builds a bank of heaters on one line, as `bench-mod-links.ps1` does: each
heater past the first adds three pipes west and sits on the last three, and the line gets a
substation and power source every 18 tiles along. `M.settle_fed`, the fed model, run outside
the game with 36 heaters' feed holds the box at 2770.66 of 3000 at 4.137×10⁹ °C, and with 40
or more fills it at 1.369×10⁷. So 40 and 48 were built, and since then 41, 42 and 44. **The
game does not agree at 40**: the solo box there holds 2902 to 2924, hot, and does not fill.
At 41, 42, 44 and 48 it agrees, to four places; 43 and 45 to 47 were not built.
The fed model has no segment, which may be the difference; that was not read.
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-d-he3-plasma -Heaters <n> -Pipes 3 -Ticks 200000 -Every 2000`,
2026-10-14, Factorio 2.0.77 (build 84539), normal quality, nothing researched (all 11 rungs
asserted off in both runs), the pair's second reactor twelve pipes east. A fill tick is the
first tick the box reads 99.9%. Rows every 2000 ticks to 198 000; a range is the rows of the
last heater cycles, which repeat.

| heaters, pipes to the first reactor | cell | shipped | canary |
|---|---|---|---|
| 40, 120 pipes | solo, segment 15 000 | never fills: box 2902.49 to 2923.92, segment 14 735.90 to 14 854.40, 4.15×10⁹ °C | never fills: box 2899.61 to 2922.99, segment 164.95 to 281.67, 4.14 to 4.17×10⁹ °C |
| 40 | pair, one powered, segment 19 200 | fill at 15 315 and 15 278; powered box 1.369335×10⁷ °C from 16 000; unpowered 15 °C from 15 282 | powered never fills, 2902.20 to 2921.81 at 4.14 to 4.17×10⁹ °C; unpowered full of cold plasma from 3792 |
| 40 | both powered | never fills: 2049.41 to 2064.16 each at 4.10 to 4.12×10⁹ °C | never fills: 2044.51 to 2066.61 each |
| 48, 144 pipes | solo, segment 17 400 | fills at 10 339; 1.369335×10⁷ °C from 12 000 | fills at 1805; 1.369335×10⁷ °C from 4000 |
| 48 | pair, one powered, segment 21 600 | fill at 13 957 and 13 925; powered box 1.369335×10⁷ °C from 16 000; unpowered 15 °C from 13 926 | powered never fills, 2944.44 at 4.16×10⁹ °C at 198 000; unpowered full of cold plasma from 3206 |
| 48 | both powered | never fills: 2245.86 and 2245.95 at 4.13×10⁹ °C | never fills: 2240.94 and 2245.71 at 4.14×10⁹ |

The counts between, 2026-10-18: the same command with `-NoCanary`, so shipped only, on the
same game, at normal quality, with nothing researched (all 11 rungs asserted off):

| heaters, pipes to the first reactor | cell | shipped |
|---|---|---|
| 41, 123 pipes | solo, segment 15 300 | fills at 10 870; 1.369335×10⁷ °C from 12 000 |
| 41 | pair, one powered, segment 19 500 | fill at 15 092 and 15 054; powered box 1.369335×10⁷ °C from 16 000; unpowered 15 °C from 15 054 |
| 41 | both powered | never fills: 4.10 to 4.12×10⁹ °C |
| 42, 126 pipes | solo, segment 15 600 | fills at 10 754; 1.369335×10⁷ °C from 12 000 |
| 44, 132 pipes | solo, segment 16 200 | fills at 10 617; 1.369335×10⁷ °C from 12 000 |

- **41 heaters fill a solo D-He3 line and 40 do not, and the full line is cold.** At 40 the
  solo box holds 2902 to 2924 of 3000, hot. At 41 it fills on tick 10 870, and at 48 on
  10 339. At 41, 42, 44 and 48 the full box reads 1.369335×10⁷ °C at every row from 12 000 to
  198 000, 300 times under the 4.15×10⁹ of the line that does not fill. The fed model's cold
  branch is the same figure to four places.
- **So no count of heaters read here gives a hot full D-He3 line.** Past the fill the
  temperature is the same to seven figures at the four counts built from 41 to 48: at those,
  more heaters fill the box sooner and do not move where it ends. Research cannot move it
  either: `M.aneutronic_reactor` in `realistic-fusion-refreshed/scripts/reactor-logic.lua` has
  no ladder of any kind, read from source at 1b1ff91 on 2026-10-18. Nor does legendary
  quality, and that no level between does is *inferred*:
  [Above normal quality](#above-normal-quality) (#726).
- **With one reactor unpowered, the line fills at 40 already.** That this is because the
  unpowered box burns nothing is *inferred* from its reading 15 °C, where nothing fuses, and
  was not read. The unpowered box reads 15 °C from tick 15 282 at 40 heaters and 13 926 at 48,
  four and one ticks after its fill, and at every row after; at 41 heaters it reads 15 °C on
  its fill tick, 15 054. The powered box beside it sits at
  1.369335×10⁷. So the unpowered reactor is at the floor on a full D-He3 line built 1H2, as on
  D-D and He3-He3 built that way, but the line is cold, so this is not the hot full line #558 read on `rf-reactor`.
- Both powered, none of 40, 41 and 48 fills. That two boxes burn twice what one does, and so
  need more heaters, is *inferred* from the solo and pair readings and was not read.
- **Canary.** The solo box fills 5.7 times sooner at 48 heaters and ends on the same
  temperature. In the pair the unpowered box takes cold plasma until it is full and the powered
  one never fills, at 40 or at 48. `control.lua` never changed the unpowered canary box: 0 of
  33 001 step ticks.

##### Above normal quality

([#726](https://github.com/trulsjo/realistic-fusion-refreshed/issues/726).) Since #726 the
probe's `-Quality` places the reactors, the heaters or both, as `-QualityOn` says, at a quality
above normal with the bundled `quality` mod enabled, as `probe-plasma-segment.ps1 -Quality`
does, and asserts each machine's quality as it is placed.
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-d-he3-plasma -Pipes 3 -Ticks 200000 -Every 2000 -NoCanary -Heaters <n> -Quality legendary [-QualityOn <which>]`,
2026-10-18, Factorio 2.0.77 (build 84539), nothing researched (all 11 rungs asserted off),
shipped box only, 3 pipes plus three per added heater, rows every 2000 ticks to 198 000. The
same command without `-Quality`, at 41 heaters, reads every row as the 41-heater run above.
A range in the table below is the rows of the last heater cycle, or of the last two rows where
the box has not settled.

| heaters, pipes to the first reactor | at legendary | cell | shipped |
|---|---|---|---|
| 41, 123 pipes | the reactor | solo, pair and both | every row as at normal quality: solo fills at 10 870; pair at 15 092 and 15 054; both never fill, at 4.10 to 4.12×10⁹ °C |
| 41 | the heaters, then the heaters and the reactor | solo | fills at 4369; 1.369335×10⁷ °C from 6000 |
| 41 | the same | pair, one powered | fill at 6082 and 6044; powered box 1.369335×10⁷ °C from 8000; unpowered 15 °C from 6048 |
| 41 | the same | both powered | fill at 6089 and 6051; 1.369335×10⁷ °C from 8000 |
| 17, 51 pipes | the heaters and the reactor | solo | fills at 6364; 1.369335×10⁷ °C from 8000 |
| 17 | the same | pair, one powered | fill at 10 448 and 10 411; powered box 1.369335×10⁷ °C from 12 000; unpowered 15 °C from 10 416 |
| 17 | the same | both powered | never fill: 4.11 to 4.12×10⁹ °C |
| 16, 48 pipes | the heaters and the reactor | solo | never fills: box 2908.27 to 2919.99, 4.15 to 4.16×10⁹ °C |
| 16 | the same | pair, one powered | fill at 10 928 and 10 892; powered box 1.369335×10⁷ °C from 12 000; unpowered 15 °C from 10 896 |
| 16 | the same | both powered | never fill: 4.10 to 4.11×10⁹ °C |

- **A legendary reactor changes nothing on this line.** At 41 heaters every row of the run
  with the reactor alone at legendary reads as the run at normal quality.
- **Legendary heaters fill the line sooner and leave the full box where it was.** At 41 the
  solo line fills on tick 4369 where at normal it fills on 10 870, and both powered now fill.
  Every full powered box reads 1.369335×10⁷ °C, the figure at normal. The run with the heaters
  alone at legendary reads every row as the run with the heaters and the reactor at legendary.
- **17 legendary heaters fill a solo line and 16 do not**, as 41 and 40 do at normal. Below
  the fill the box holds 2908 to 2920 of 3000, hot; at the fill it is cold.
- **So no route the shipped mod allows gives a hot full D-He3 line.** That is *inferred* from
  the readings above and from the heater counts at normal quality: every full powered box
  built, at normal and at legendary, with 16 to 48 heaters and the reactor at either quality,
  reads 1.369335×10⁷ °C, and research has no ladder on this reactor. Uncommon, rare and epic
  were not built; that they fall between normal and legendary is *inferred*. Every line was
  three pipes plus three per heater, the two-reactor cells built 1H2; another pipe count,
  another build order, a heater with a module in it and a beacon were not built.

##### The fitted rule beside the line that fills

([#587](https://github.com/trulsjo/realistic-fusion-refreshed/issues/587).) Since #587 the
probe's `-Fixed` follows every heater of a bank and runs beside each solo cell as well as the
pair and both. With one heater, `-Every 6000 -Fixed -Pipes 3 -Ticks 24000` on 2026-10-18,
Factorio 2.0.77 (build 84539), D-D, normal quality, nothing researched (all 11 rungs asserted
off), three pipes, counted to 18 000, prints the same pair and both counts in both variants as
`main`'s probe run with the same arguments that day. In the shipped variant the solo cell's
order 1H, the box and then the heater, misses none of its 18 000 ticks; under the canary it
misses 17 877, and every order misses there, the rule being the `input-output` box's. With more than one heater, which one the rule takes
first is not known, so the bank is taken four ways: heater 1, the one nearest the reactor and
the first built, first (fwd) or last (rev), each pushing twice before the next; or the whole
bank gone through twice in either of those orders (pass, revpass).
`pwsh -File scripts/probe-plasma-input-box.ps1 -Plasma rf-d-he3-plasma -Heaters 48 -Pipes 3 -Ticks 200000 -Every 2000 -Fixed -NoCanary`,
2026-10-18, Factorio 2.0.77 (build 84539), normal quality, nothing researched (all 11 rungs
asserted off), 48 heaters and 144 pipes to the first reactor, twelve more to the second, built
1H2, counted to 198 000. The fill ticks are the 2026-10-14 run's, and this run reads them
again: solo 10 339 ticks filling and 187 661 full, the pair with one unpowered 13 957 and 184 043, both powered 198 000 filling.
Each cell is ticks missed, and the first:

| order, bank | solo, filling | solo, full | one unpowered, filling | one unpowered, full | both, filling |
|---|---|---|---|---|---|
| **1H and 1H2, fwd** | **0** | **0** | **0** | **0** | **0** |
| 1H and 1H2, rev | 24, tick 10 082 | 31 301, tick 10 340 | 62, tick 13 562 | 30 698, tick 13 958 | 0 |
| 1H and 1H2, pass | 24, tick 10 082 | 0 | 61, tick 13 562 | 0 | 0 |
| 1H and 1H2, revpass | 24, tick 10 082 | 31 301, tick 10 340 | 62, tick 13 562 | 30 698, tick 13 958 | 0 |
| H1 and H12, every bank | 359, tick 122 | 31 301, tick 10 340 | 519, tick 122 | 30 698, tick 13 958 | 6596, tick 122 |

- **One way misses none of 594 000 ticks: the boxes and the bank in build order, each heater
  pushing twice before the next.** That is the order #583 found the rule follows, with the
  bank taken as its heaters were placed. No reading was off the 2⁻²⁴ grid.
- **The other ways of taking the bank part only near the fill.** While the line has room
  each of them misses nothing until tick 10 082 on the solo line and 13 562 on the pair,
  257 and 395 ticks before the fill. That the heaters back up once the line is full, so that
  which is reached first matters, is *inferred* from where the misses start, and was not read.
  Taking the bank twice in build order fits the full line as
  well. Both powered, the line never fills and all four fit.
- With the bank before the box, every order misses from tick 122, the first craft, as on one
  heater. Of the other four two-box orders, each misses 515 to 13 742 ticks while the pair's
  line fills, and 6596 to 197 879 of the 198 000 on both, whose line never fills; on the full line with one box unpowered, 12H and 21H fit with the bank fwd or pass.
- This run floors the destination's fill, the rounding #564 settled, and runs no other, so it
  says nothing new about the rounding.
- It is still a **fitted** rule. One way of it predicts every tick read, which does not show
  that the engine computes it that way.

## The repository's gates under the canary

[#549](https://github.com/trulsjo/realistic-fusion-refreshed/issues/549). 2026-10-04, Factorio
2.0.77, base game only. Each gate was run twice from the same working tree: once as it ships and
once with the canary loaded.

**How the canary was loaded.** It is the mod `probe-plasma-input-box.ps1` writes, copied out by
hand: a directory `rf-input-box-canary/` holding that script's `info.json` fields and its
`data-final-fixes.lua` text, unchanged. Its parent directory was passed to both gates:

```
pwsh -File scripts/check-pooling.ps1 -AlsoModDirectory <dir>
pwsh -File scripts/load-check.ps1    -AlsoModDirectory <dir>
```

`load-check.ps1` already took `-AlsoModDirectory`. `check-pooling.ps1` took no extra mod, so #549
gave it the same parameter, read the same way through `Get-HarnessMods`. It is off by default, and
the run without it is the shipped run. Both gates printed `also loading: rf-input-box-canary`.
The canary refuses to load unless the box is `input-output` before it changes it. Neither gate
reads the plasma box's production type back, so the change itself is the canary's own assertion plus
#542's runtime reading above.

### The pooling check: 23 of 125 checks failed, and 27 do since #565

**Since [#565](https://github.com/trulsjo/realistic-fusion-refreshed/issues/565) four more rows
fail under the canary, which is what they should have done.** The readings below are #549's, of
2026-10-04, when the four "the run gains most of what its reactors spent, and not all of it"
rows were bounded above 0.4 and below 1.02 and so passed at 100.0% arrived. #565 moved the
upper bound to 0.98. Run again on 2026-10-05, Factorio 2.0.77: shipped,
`PASS: 125 checks, 0 failures`, the four rows reading 94.6%, 75.4%, 57.6% and 67.0% as before,
so the nearest has 3.4 points of room; canary, `FAIL: 125 checks, 27 failures`, the 23 below
and those four. `scripts/check-pooling.ps1 -SelfTest` proves it: its `all-arrives-refused` half
loads this canary and requires the four rows to fail by name.

Nine other rows keep the old bound of above 0.4 and below 1.02, and still pass at 100% under the
canary: the three write shapes and the six writer rows, which read 72.2% and 71.10% to 72.19%
as shipped. Their names state a shape, not a loss, so #565 left them; the rows that compare
them with each other are among the 23.


Defaults: 1801 ticks, a simulation step every 6, a 20-pipe tail on `piped`. Nothing researched:
the rig asserted all 11 rungs off in both runs. The rig has no heater; every cell is seeded and
left to burn down.

**Shipped: `PASS: 125 checks, 0 failures`, exit 0. Canary: `FAIL: 125 checks, 23 failures`,
exit 1.** The rig printed 135 rows, 125 checks and 10 notes. 57 checks and one note read
identically in both runs, including the 11 research rows and every `get_capacity` row: a pipe
still reports the whole run, and a reactor its own box of 1000. 68 checks and 9 notes read
differently. These are the 23 that fail:

| row | shipped | canary |
|---|---|---|
| mix, pair, trio, five, solopipe, bare, piped: every box holds its share of one pool, not its own contents | worst box off its share by 1.89%, 3.23%, 1.89%, 1.02%, 2.22%, 1.88%, 0.839% | 96.7%, 95.2%, 96.8%, 98.1%, 90.9%, 97%, 97%, each worst at an `rf-pipe` |
| mix: and with nothing driving it, the run flattens to one temperature | spread 0.000119% after 180 ticks | 5×10⁷ against 1×10⁶ °C, spread 98% |
| pair, trio, five: and far above the seed, so the pool carried heat to them | 1.18592×10⁸, 7.99052×10⁷, 4.77436×10⁷ °C; 118.6, 79.9, 47.7 times the seed | 15 °C in all three, against a seed of 1×10⁶ |
| pair, trio, five: the powered reactor runs a little above the run, not away from it | 4.1%, 6.5%, 11.4% above | 1.59768×10⁸ against 15 °C in all three |
| idle: and it flattened, so the mixing had finished when the loss was read | 0.000819% apart | 4×10⁶ against 1×10⁶ °C, 75% apart |
| idle: BUT MIXING DOES NOT CONSERVE HEAT | 0.8177 survived, 18.2% destroyed | 1 survived, 0% destroyed |
| over one interval, where the heat enters DOES matter, and monotonically along the run | west 72.19%, middle 71.65%, east 71.10% | 100.00% at all three |
| and the rows had stopped moving before the longest window closed | worst flat to 9.05×10⁻⁷ | worst flat to 0.557 |
| so the gap #40 attributed to writer count is not writer count and not position either | 1.09-point ramp against a 17.8-point gap | -0.00 against -0.0 |
| probe: and the SAME instrument sees the run move once ticks have passed | 12 of 12 other boxes changed 6 ticks later | 0 of 12 |
| solopipe: the SAME single writer loses materially once there is a run to mix across | 75.4% against 94.6% | 100.0% against 100.0% |
| and the three-reactor run loses MORE than mixing alone accounts for | 57.6% against 75.4% | 100.0% against 100.0% |
| and what reaches the pool DEPENDS on what else is plumbed into the run | 57.6% against 67.0% | 100.0% against 100.0% |

These 45 checks still passed on 2026-10-04, with different figures. Since #565 the first row's
four fail, which leaves 41:

| row | shipped | canary |
|---|---|---|
| solo, solopipe, bare, piped: the run gains most of what its reactors spent, and not all of it | 94.6%, 75.4%, 57.6%, 67.0% arrived | 100.0% in all four; the bound was above 0.4 and below 1.02 then, and is below 0.98 since #565, so these four now fail |
| solo: one reactor with no run to share into keeps nearly all of what it spent | 94.6% | 100.0% |
| pair, trio, five: the pool ran down | 47.33%, 44.64%, 42.68% of capacity left | 80.78%, 75.61%, 71.82% |
| trio, five: every unpowered reactor on the run is at one temperature | 7.99052×10⁷ °C, spread 0.0329%; 4.77436×10⁷, spread 0.059% | 15 °C, spread 0%, in both |
| idle: left flat and alone, the run holds its heat | 0.000898% apart | 0% apart |
| idle: no plasma entered or left the untouched run | 1785.8695 units | 3025 units |
| twopass, onepass, rebased: started from the same state as the other shapes | 1.17974×10⁹ unit-K predicted | 1.08356×10⁹ |
| twopass, onepass, rebased: the three write shapes | 72.2% arrived in each | 100.0% in each |
| onepass, and rebased, against the shipped shape | 72.19% against 72.19% | 100.00% against 100.00% |
| writers1, writers2, writers3, middle, east, reversed: same segment, same fill, same temperature, same total heating | 1785.87 of 4000 units, 44.6% full | 3025 of 4000, 75.6% full |
| the same six: the shipped physics predicts the same gain as every other row | 1.17974×10⁹ unit-K | 1.08356×10⁹ |
| the same six: what arrived | 72.19%, 71.92%, 71.64%, 71.65%, 71.10%, 71.10% | 100.00% in each |
| write order does not matter | 71.10% against 71.10% | 100.00% against 100.00% |
| 2 writers, and 3 writers, keep the MEAN of the positions they occupy | 71.92%, 71.64% | 100.00% in both |
| the shape rows, and the one-writer row, were uneven the instant the writes landed | 3.667×10⁶ against 9.797×10⁵ °C, spread 73.28% | 2.166×10⁶ against 9.588×10⁵, spread 55.73% |
| writer count: and the three-writer row was flat | 1.875×10⁶ °C, spread 0.0000% | 1.361×10⁶, spread 0.0000% |
| seedonce: one seeding pass leaves the run as full as sixty do | 44.6% against 44.6% | 75.6% against 75.6% |

The nine notes are the positional ramp at 6, 12, 30, 60, 120, 240, 480 and 960 ticks, and its
summary. Shipped, the ramp reads +1.089, +0.944, +0.214 and +0.010 points to 60 ticks and -0.000
from 120. Canary, every window reads 100.000% at west, middle and east, a ramp of -0.000.

**What the readings say, and what they do not.** Under the canary the seeded plasma stays in the
reactors' boxes: every row's worst box is a pipe, far off its share, and the seeded runs read
fuller (75.6% where they read 44.6%). Every bookkeeping row reads 100% arrived, because no heat
leaves a box to be lost in mixing. The unpowered reactors read the 15 °C floor, which is #542's
pair reading again, on three row lengths. Whether the seed ever reached the pipes, or the boxes
emptied into them, was not separated: the rig reads totals, not the order things moved in.

### The load check: everything holds

**Shipped and canary both exit 0** and print the same verdict: "prototypes valid, every referenced
asset present, map created, the simulation's sixteen load-time invariants hold". By name, all
sixteen hold under the canary: `check_fuel_rows`, `check_reactor_specs`, `check_plasma_capacity`,
`check_input_flow`, `check_ladder_prototypes`, `check_ladder_clamp`, `check_plant_efficiency`,
`check_plasma_bounds`, `check_signal_ceiling`, `check_every_plasma_burns`,
`check_collector_boxes`, `check_blanket_feed`, `check_energy_outlets`,
`check_reactor_companions`, `check_steam_sinks` and `check_segment_constants`. The sixteenth
is #555's, from the same batch; the run was first taken with fifteen and taken again with it,
both gates reading as before. They run in `check_prototypes()` in
`realistic-fusion-refreshed/control.lua`, which refuses to create a map when one fails.

The rest of the gate also read the same in both runs. All 26 contained connections still hold
what the data stage declared, both manifests agree, 9 sockets are at vanilla pipe height,
`check-socket-parts` measured 24 parts and could not measure 6, 4 mockups agree, and no asset is
missing.

**By reading, none of the sixteen looks at the plasma box's production type.** `control.lua`
tests `production_type` twice, both times for `"output"`: to pick a boiler's steam box, and in
`check_segment_constants` to sum `rf-heater`'s output boxes.
`check_plasma_capacity` reads box 1's `volume` and nothing else. So the gate holds the prototypes
to the simulation's numbers, and the mixing the simulation relies on is outside what it checks.

### The Lua suites: the canary cannot reach them

**Run:** all six suites under Lua 5.4.6, 968 checks, 0 failures: blanket-energy 49, bremsstrahlung
31, circuit-output 116, further-reactions 44, reactivity 57, reactor-logic 671. The suites load
no prototype, so there is no way to load the canary into them. One run serves both variants.

**Reading:** no module under `realistic-fusion-refreshed/scripts/` names `production_type`.
`M.step` and `M.settle_fed` in `realistic-fusion-refreshed/scripts/reactor-logic.lua` take what a
box holds, not what kind of box it is. One function depends on the shipped box all the same:
`M.settle_segment` hard-codes the `input-output` box's push into the segment and pull back, and
`tests/test-reactor-logic.lua` pins its figures. Under the canary, #542 read a segment at 0 until
the box was full, which `M.settle_segment` does not describe. Nothing the mod runs calls it. So
the pure simulation the mod runs does not depend on the box's production type. The arithmetic the
notes use does, through `M.settle_segment`, and the suites would not notice the change.

## An existing save loaded under the canary

[#550](https://github.com/trulsjo/realistic-fusion-refreshed/issues/550).
`scripts/probe-plasma-box-save.ps1`, run with no arguments on 2026-10-04 against Factorio
2.0.77 (build 84539). It builds two cells on the shipped box: **solo** (one `rf-heater`, three
`rf-pipe`, one `rf-reactor`) and **pair** (the same, then twelve `rf-pipe` to a second,
unpowered `rf-reactor`). That is two heaters, three reactors and eighteen pipes, D-D, with
nothing researched: all 11 rungs were asserted off at build and again at the canary load. The
map is ticked to 80 000 on a headless server, saved with `game.server_save`, and the save is
loaded twice with `--benchmark` for 40 000 ticks each. In the **control** load the canary is
named disabled; in the **canary** load it is named enabled. `--benchmark` never writes a save,
and `game.auto_save` under it wrote nothing, which is why the fill runs as a server.

**The save holds tick 80 001.** `server_save` was called on tick 80 000 and lands a few ticks
later. The server read every tick after it, and its reading on tick 80 001 equals the first
reading of both loads in every figure. `on_tick` runs before the tick's entity update, so a
load's first reading is the state as saved, and its second is the first tick the engine has
moved fluid under the box that run has.

**It loads without complaint.** Both loads exited 0. Neither printed a line naming a warning,
an error, a fluid, the reactor, plasma, a migration or production, so there is no log line about
the box to quote. The canary load's `on_configuration_changed` saw `rf-input-box-canary` added,
and the runtime prototype's `production_type` read `input` there and on its first tick. The
control load read `input-output`.

**The control load reproduces the server's run exactly.** Its first two readings equal the
server's at 80 001 and 80 002 in every figure. Its pair read 656.50 per box and 2164.29 in the
segment at tick 96 000, the figures the pair above recorded at 96 000 from an unsaved run.
Anything that differs in the canary load is the box, not the save.

The segment is read through the first pipe beside each box. Its reading never includes the
box's contents, in either variant: a full solo line reads 1000 in the box and 1300 in the
segment.

| reading | tick | solo box | solo segment | pair box 1 | °C | pair box 2 | °C | pair segment |
|---|---|---|---|---|---|---|---|---|
| saved (server) | 80 001 | 1000 | 1300 | 560.2678 | 2.7088×10⁸ | 560.2678 | 2.6695×10⁸ | 1790.0104 |
| control, next tick | 80 002 | 1000 | 1300 | 560.2699 | 2.7071×10⁸ | 560.2698 | 2.6712×10⁸ | 1790.0063 |
| canary, next tick | 80 002 | 1000 | 1300 | 604.2410 | 2.7074×10⁸ | 604.2411 | 2.6709×10⁸ | 1702.0640 |
| control | 82 000 | 1000 | 1300 | 572.3986 | 2.5899×10⁸ | 572.4000 | 2.5528×10⁸ | 1837.1844 |
| canary | 82 000 | 1000 | 1300 | 1000 | 2.5276×10⁸ | 1000 | 2.5016×10⁷ | 969.1249 |
| canary | 84 000 | 999.9453 | 1300 | 999.9437 | 2.4588×10⁸ | 1000 | 15 | 1029.9657 |
| control | 120 000 | 999.9456 | 1300 | 807.7247 | 1.3966×10⁸ | 807.7276 | 1.2979×10⁸ | 2752.3364 |
| canary | 120 000 | 999.9456 | 1300 | 999.9463 | 2.3962×10⁸ | 1000 | 15 | 2204.7909 |

- **A full solo line is untouched.** All 20 sampled rows from 82 000 to 120 000 read the same in
  both loads, to every printed digit, except the segment id. The solo box at 120 000 reads
  2.4117×10⁸ °C in both, still cooling on the shipped trajectory. A full `input` box and a full
  segment trade nothing, so this says nothing about a line that is not full.
- **The engine rebuilds the segments on load.** The canary load's segment ids are 3 and 7 where
  the save's were 1 and 5. The pair's two boxes and its bridge still share one id.
- **The plasma the pair held in common goes into its boxes, and none is lost.** In the first
  tick under the canary, each box took 43.9732 and the segment gave up 87.9464. The cell's
  total, both boxes and the segment, reads 2910.5460 at 80 001 and 2910.5461 at 80 002 in both
  loads. By tick 82 000 both canary boxes are full and the segment is down to 969.12. After that
  the segment refills behind them, as it does in the fresh canary runs above.
- **The heat the unpowered box held does not survive.** Pair box 2 read 2.6695×10⁸ °C when
  saved, 2.5016×10⁷ at 82 000, and 15 °C, the floor, at every row from 84 000 to 120 000. In
  the control load the same box stays within 7.1% of the powered one's temperature (1.2979
  against 1.3966×10⁸ at 120 000). This is the pooling loss the fresh canary pair showed,
  reached from a running save.
  The pair was saved while its line was still filling. The shipped pair run further, in
  [Once the shipped line is full, the unpowered reactor falls to the floor, built 1H2](#once-the-shipped-line-is-full-the-unpowered-reactor-falls-to-the-floor-built-1h2),
  drops to the same 15 °C when its line fills near tick 149 000, so the control load's warmth
  at 120 000 is that of a line still filling.
- **Settled:** the canary's powered box 1 is still cooling at 120 000, at 2.3962×10⁸ °C, moving
  toward the 2.3815×10⁸ a fresh canary box settles at. It moved 0.0026×10⁸ in the last 8000
  ticks. Box 2 has read 15 °C since 84 000.

### The saves #550 did not load

([#561](https://github.com/trulsjo/realistic-fusion-refreshed/issues/561).) The save probe
gains `-Both`, a second pair with both reactors powered, built last. Two runs on 2026-10-05,
Factorio 2.0.77 (build 84539), D-D, nothing researched (11 rungs asserted off at build and at
the canary load), three heaters, five reactors and thirty-three pipes: three to each first
reactor and twelve across each pair. Each save is loaded for 40 000 ticks with the canary named
disabled (control) and enabled (canary), rows every 2000.

- `-Both -SaveAt 40000 -LoadTicks 40000`: the save holds tick 40 001, with every line part full.
- `-Both -SaveAt 156000 -LoadTicks 40000`: the save holds tick 156 001, after the one-powered
  pair's line filled at 148 939 and its unpowered reactor reached 15 °C.

**Both saves load without complaint.** All four loads exited 0. None printed a line naming a
warning, an error, a fluid, the reactor, plasma, a migration or production, so there is still
no log line about the box to quote. Each canary load's `on_configuration_changed` saw
`rf-input-box-canary` added and read `input` off the runtime prototype; each control load read
`input-output`. Each load's first reading equals the server's reading on the saved tick in
every figure.

| saved at 40 001, part full | reading | tick | box 1 | °C | box 2 | °C | segment |
|---|---|---|---|---|---|---|---|
| solo | saved | 40 001 | 617.3507 | 5.3570×10⁸ | | | 747.3512 |
| solo | control, next tick | 40 002 | 617.2814 | 5.3573×10⁸ | | | 747.3466 |
| solo | canary, next tick | 40 002 | 655.5322 | 5.3561×10⁸ | | | 709.0863 |
| solo | control | 42 000 | 639.8994 | 5.1114×10⁸ | | | 780.0148 |
| solo | canary | 42 000 | 999.8920 | 3.6057×10⁸ | | | 396.7163 |
| solo | control | 80 000 | 1000 | 2.4230×10⁸ | | | 1300 |
| solo | canary | 80 000 | 1000 | 2.3956×10⁸ | | | 1300 |
| pair, one powered | saved | 40 001 | 282.7996 | 6.2343×10⁸ | 282.8008 | 6.1796×10⁸ | 961.5736 |
| pair, one powered | canary, next tick | 40 002 | 310.2502 | 6.2495×10⁸ | 309.4667 | 6.1609×10⁸ | 907.4115 |
| pair, one powered | canary | 42 000 | 772.7068 | 4.6997×10⁸ | 777.0110 | 1.4057×10⁸ | 0 |
| pair, one powered | control | 80 000 | 560.2654 | 2.7106×10⁸ | 560.2655 | 2.6676×10⁸ | 1790.0152 |
| pair, one powered | canary | 80 000 | 1000 | 2.3814×10⁸ | 1000 | 15 | 750.0216 |
| pair, both powered | saved | 40 001 | 259.7079 | 1.3441×10⁹ | 259.7081 | 1.3441×10⁹ | 883.1093 |
| pair, both powered | canary | 42 000 | 680.0208 | 7.7260×10⁸ | 668.8635 | 7.7846×10⁸ | 0 |
| pair, both powered | control | 80 000 | 438.7746 | 7.9118×10⁸ | 438.7726 | 7.9118×10⁸ | 1492.0722 |
| pair, both powered | canary | 80 000 | 1000 | 2.3978×10⁸ | 1000 | 2.4199×10⁸ | 30.8334 |

| saved at 156 001 | reading | tick | box 1 | °C | box 2 | °C | segment |
|---|---|---|---|---|---|---|---|
| solo, full | saved | 156 001 | 1000 | 2.4048×10⁸ | | | 1300 |
| solo, full | control and canary, next tick | 156 002 | 1000 | 2.4048×10⁸ | | | 1300 |
| solo, full | control and canary | 196 000 | 1000 | 2.3991×10⁸ | | | 1300 |
| pair, one powered, full | saved | 156 001 | 1000 | 2.3788×10⁸ | 1000 | 15 | 3500 |
| pair, one powered, full | control and canary, next tick | 156 002 | 1000 | 2.3788×10⁸ | 1000 | 15 | 3500 |
| pair, one powered, full | control and canary | 196 000 | 1000 | 2.3941×10⁸ | 1000 | 15 | 3500 |
| pair, both powered, filling | saved | 156 001 | 700.9313 | 4.4624×10⁸ | 700.9292 | 4.4624×10⁸ | 2337.3418 |
| pair, both powered, filling | control, next tick | 156 002 | 700.9413 | 4.4624×10⁸ | 701.0356 | 4.4621×10⁸ | 2340.9755 |
| pair, both powered, filling | canary, next tick | 156 002 | 730.8382 | 4.4621×10⁸ | 730.8363 | 4.4621×10⁸ | 2281.2778 |
| pair, both powered, filling | control | 196 000 | 821.7720 | 3.4979×10⁸ | 821.7713 | 3.4979×10⁸ | 2807.1277 |
| pair, both powered, filling | canary | 196 000 | 1000 | 2.4168×10⁸ | 1000 | 2.4168×10⁸ | 2609.8915 |

- **A full line is untouched, a pair as well as a solo.** In the 156 001 save, all 22 solo rows
  and all 44 rows of the one-powered pair read the same in both loads, to every printed digit
  but the segment id. The pair's unpowered reactor was at 15 °C when saved and is at 15 °C in
  both loads. The canary takes nothing from a plant whose line was already full.
- **A part-full line empties into its boxes, and none of it is lost.** In the first tick under
  the canary the solo box took 38.18 units and its segment gave 38.26. The 0.08 between is about
  what the control load's cell lost to the burn on the same tick, 0.07. The box is full on the row at 42 000,
  where the control load's fills on the row at 72 000. It runs colder on the way, 3.6057×10⁸ °C
  against 5.1114×10⁸ at 42 000, having swallowed the segment's cooler plasma, and is within 1.2%
  of the control load at 80 000.
- **A filling pair with one reactor unpowered loses that reactor's heat**, as #550 read at
  80 000. Saved at 40 001 it read 6.1796×10⁸ °C. Under the canary it reads 1.4057×10⁸ at 42 000
  and 15 °C on every row from 46 000. In the control load it is within 1.6% of its neighbour at
  80 000.
- **A filling pair with both reactors powered keeps both hot.** Each box fills from the segment,
  by 80 000 in the first save and by 158 000 in the second, and runs colder than the control
  load while it does. Neither reactor goes to the floor. At the end of each load the canary's
  boxes read 2.40 to 2.42×10⁸ °C, within 2% of the 2.3815×10⁸ a solo box settles at.
- **Settled** is reached by the full-line cells only, which did not move. The canary's
  both-powered boxes and its part-filled solo box were still cooling at the last row.

**Under this repository's rule, the change would count as breaking in one case of the five
loaded.** Root `CLAUDE.md` defines a breaking change as "anything that breaks an existing
save", and warns that this kind "breaks silently and players find out, not the build". Every
save loads, logs nothing, and loses no plasma. Case by case:

| case | reading | breaks the save? |
|---|---|---|
| a full solo line (#550 at 80 001, #561 at 156 001) | identical in both loads | no |
| a full pair, one reactor unpowered (#561 at 156 001) | identical in both loads; the unpowered reactor is at 15 °C before and after | no |
| a part-full solo line (#561 at 40 001) | the box fills on the row at 42 000 where it filled at 72 000, and runs colder until it settles | it changes what the plant does, and nothing stops working |
| a filling pair, both powered (#561 at 40 001 and 156 001) | both boxes fill from the segment and stay hot | the same |
| a filling pair, one reactor unpowered (#550 at 80 001, #561 at 40 001) | the unpowered reactor falls from 6.18×10⁸ or 2.67×10⁸ °C to 15 °C within 6000 ticks, where the control load keeps it warm: within 1.6% of its neighbour at 80 000 in #561's, 7.1% at 120 000 in #550's | **yes** |

So the break is confined to a reactor that a saved plant heats only through the pipe, on a line
that has not yet filled. Under the shipped box that reactor loses the same heat when the line
does fill (#548, #558), on a line built 1H2; built 12H or 2H1 it keeps 10³ to 10⁴ °C (#583).
The canary takes it at load. That is a reading of the rule, not a
choice between the options below.

## What was not measured

- D-T, and any researched state but the one pair at heating rung 5. A hot full line on the
  aneutronic reactor: He3-He3 fills cold (#571), and D-He3 fills at 41 heaters at normal quality, the fewest
  of the counts built, and is cold at each of 41, 42, 44 and 48 (#586). The canary was not
  run at 41, 42 or 44, and the fitted rule was run beside a bank at 48 heaters only, and not
  under the canary (#587). Above normal quality, D-He3 was built at legendary only, not at
  uncommon, rare or epic, with no module in a heater and without the canary (#726).
- Why the unpowered box stays above the floor on a full D-D line when it is built just before
  the heater (#583).

## Options

Each option lists what it changes. **Option 2 was chosen on 2026-10-20**, by Truls, for both
reactors; see [ADR 0040](../adr/0040-the-plasma-box-is-input.md).

1. **Do nothing; keep `input-output`.** Nothing moves. The fuel line remains two stores trading
   through the box's connection, the box fills in 2.3 to 2.6 times the fed model's time, and
   ADR 0011's pooling works while the line has room: a reactor on the run shares heat with its
   neighbours, less as the line fills. The shipped pair's unpowered reactor is within 3% of the
   powered one at 96 000, 17% short at 136 000, and at 15 °C from tick 150 012, once the line
   is full (#548, #558); that pair was built 1H2, and built 12H or 2H1 it is not (#583). The prototype stays outside the docs' advice for `input-output`, and that
   advice gives no reason. The modelling work in
   [The rule behind the split](exchanger-coverage.md#the-rule-behind-the-split) remains needed,
   because `M.settle_fed` is not what the game does.
2. **Make both reactors' plasma box `input`.** On the one rig measured, the game then does what
   `M.settle_fed` describes: a fill at 30 975 against 31 000, settling at 2.3815×10⁸ against
   2.381×10⁸, with no dependence on pipe count. The segment becomes a queue in front of the box
   rather than a second store. **It ends ADR 0011's heat pooling, which the shipped box keeps
   only while the line fills (#548)**, in the cells built 1H2; built 12H or 2H1 an unpowered
   box on a full D-D line stays at 10³ to 10⁴ °C (#583). Reactors on one run share feed plasma but not heat, and a
   reactor without power sits at the 15 °C floor beside a hot one. ADR 0011 would need
   superseding. (Chosen as amending ADR 0011 instead, whose per-reactor decision stands: ADR 0040.) The pooling rows of `check-pooling.ps1`, 27 of whose 125 checks fail under the
   canary (see
   [The repository's gates under the canary](#the-repositorys-gates-under-the-canary)), and the
   comments in `control.lua` that describe box 1 as "the input-output box ADR 0011's fluid
   coupling rests on", would need rewriting. An existing save loads without complaint and loses
   no plasma, but on a line still filling a reactor heated only through the pipe falls to 15 °C,
   so the change would be breaking there, and in none of the four other cases loaded; see [An existing save loaded under the canary](#an-existing-save-loaded-under-the-canary).
   On the aneutronic reactor, read on D-He3 with one heater (#562), the box settles at the same
   467 to 470 units either way, the segment beside it empties, and an unpowered reactor on the
   run fills with 3000 units of plasma at 15 °C where the shipped one runs within 1.6% of its
   neighbour. On He3-He3, which fills that line (#571), the unpowered reactor ends at 15 °C
   whether the box is `input-output` or `input`.
3. **Make only one reactor `input`.** This splits the fuel-line behaviour by tier, and it is
   possible because the two reactors are separate prototypes. Both were measured, each alone: `rf-reactor` on D-D and `rf-aneutronic-reactor` on D-He3 and, since #571, on He3-He3.
4. **Keep `input-output` and make the model match the game.** This changes no prototype. It
   moves the fed model onto the two-store rule #531 read, which is the work already open in
   `exchanger-coverage.md`, and it keeps pooling. Like option 1, it relies on behaviour the
   docs advise against.

## Sources

- `scripts/probe-plasma-input-box.ps1`, run as described above.
- `scripts/probe-plasma-box-save.ps1`, for the save section.
- [`exchanger-coverage.md`](exchanger-coverage.md): #516, #520 and #531's readings of the
  shipped box and the fed model's figures.
- `docs/adr/0011-per-reactor-simulation-fluid-coupled.md` and `scripts/check-pooling.ps1`, for
  what pooling means here and how it is read.
- [`FluidBox`](https://lua-api.factorio.com/2.0.77/types/FluidBox.html), 2.0.77, checked
  2026-10-04.
