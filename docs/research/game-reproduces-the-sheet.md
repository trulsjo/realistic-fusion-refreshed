# Does the game reproduce the sheet? Measured, through one window

Measured 2026-09-17 with `tools/measure-frame-accents.py`, for
[#387](https://github.com/trulsjo/realistic-fusion-refreshed/issues/387). **This note is a bench's
findings.** It decides nothing and adds no threshold; whether an accent reads is ADR 0034's, and it
is Truls's.

**Its two siblings measure the other two halves.** `accent-separation.md` reads the committed sheet
and needs no game. `accent-legibility-at-zoom-1.md` photographs the machine in a real map and asks
an eye. This one puts the *first* note's window on the *second* note's picture, which is the only
shape in which the difference between a sheet and a frame is a measurement rather than a
disagreement between two methods.

## The answer

**The game reproduces the sheet.** Every accent band a zoom-1 frame draws is within **0.7 dE00** of
the same band on the sheet it was drawn from, read through the same window:

| socket | sheet | frame | moved | wobble |
|---|---|---|---:|---:|
| collector west, tritium | `#a2b8a8` | `#a0b8a8` | 0.5 | 0.8 |
| collector east, tritium | `#506f60` | `#506e5e` | 0.5 | 0.5 |
| exchanger west, reactor energy | `#caa27b` | `#c9a179` | 0.7 | 1.4 |
| exchanger east, reactor energy | `#c29768` | `#c19768` | 0.2 | 1.0 |
| exchanger west, water | `#8ea9c1` | `#8ca8c1` | 0.4 | 3.6 |
| exchanger east, water | `#345777` | `#345776` | 0.7 | 0.6 |

**Every one of those moves is smaller than the sheet bench's own wobble on the same band**, which is
how far the colour travels under the worst of four one-step narrowings of its window. So the right
reading of this table is not "the game darkens things by half a unit" — it is that the difference
between the sheet and the frame is *below what either instrument resolves*. The west water row makes
it plain: it moved 0.4 and wobbles 3.6, which is a band two screen pixels wide saying it cannot be
measured that finely by anybody.

**Reproduce it in two commands.** Both are exact since #387 turned the weather off (below):

```
pwsh -File scripts/probe-heat-exchanger-art.ps1 -MapSeed 1 -OutputDirectory out
python tools/measure-frame-accents.py out/game-alone.png
```

## What the 8.4 turned out to be

`accent-legibility-at-zoom-1.md` recorded the exchanger's west water band at `#92acc3` on the sheet
and `#7592ae` in the game, **8.4 dE00 apart**, and said in the same breath that it did not know how
much of that was real — the two figures came through different windows, and a difference between two
windows is not a measurement of a difference between two images. It was right not to know. Measured
through one window, the number is **0.4**.

The 8.4 was three things, and none of them is the game:

| | dE00 | what it was |
|---|---:|---|
| the window | ~7 | a hand-placed hue cut against `socket_strip`'s filter-guarded, body-classified one |
| a re-render | ~0.7 | the frames were shot at 21:17 on 2026-09-16 and both sheets were re-rendered at 23:48 (`9ab4c57`) |
| the game | 0.4 | measured above |

The first is the bulk of it and the reason this bench exists. The second is small but not nothing,
and it is why the figures above were taken on a frame shot **after** the re-render rather than on
the committed ones — see the caveat at the foot of this note.

**`accent-separation.md`'s `#92acc3` is stale for the same reason** and so is its `#a5bbaa` for the
collector's west tritium: both predate `9ab4c57`. Today's sheet reads `#8ea9c1` and `#a2b8a8`. That
is a separate correction and this note does not make it; it is recorded here because a reader
comparing the two tables would otherwise find a fourth discrepancy and think it was ours. Its
tightest pair moved with them: the exchanger's steam and water accents read **11.7** dE00 apart
today where that note says 11.2.

## The thing nobody had noticed: a frame carries weather

**Factorio draws a moving cloud shadow over the map, and a screenshot catches whatever the clouds
were doing on that tick.** It is soft-edged, tens of tiles across, and it does not sit still. Found
while trying to explain why the *same* band read 6.4 dE00 differently in two frames of the same
machine taken in the same run.

It is worth more than the whole quantity this note measures:

| | dE00 on the exchanger's west energy band |
|---|---:|
| sheet against frame, clouds off | **0.7** |
| one frame against another, clouds on | **6.4** |

And it cannot be subtracted. On the frame that caught one, the top two thirds of the socket were
darkened by up to 22 % and the bottom third was **identical to the pixel** — a shadow with an edge
across it, not an offset.

`scripts/art-probe-lib.ps1`'s `ready()` now sets `surface.show_clouds = false` on every art probe's
rig. `always_day` does not do it: the sun and the clouds are separate, and `LuaSurface.show_clouds`
is the one that means *never*, whatever the player's graphics settings say (2.0.77).

**Two things follow, and the second is the useful one.**

- **Every accent figure in `accent-legibility-at-zoom-1.md` was taken on a frame with the weather
  left on**, including the 8.4 this note settles. That is not why the 8.4 was wrong — the window was
  — but it is a second reason none of those figures should be quoted to a decimal.
- **An art probe's frames are now reproducible.** With `-MapSeed` fixed and the clouds off, every
  frame either probe takes is byte-identical across runs, with one exception: `working-night.png`
  still differs by **at most 2 of 255** over 115,233 pixels. Only that frame, and only on the
  machine that has a glow — `rf-isotope-collector`'s `night.png` matches exactly, which is what its
  `glow: false` means. That residue is unexplained and is not weather; with the clouds on the same
  pair differed by up to 17 over 311,621 pixels.

## A pipe still does not cover a band, and now that is measured properly

`accent-legibility-at-zoom-1.md` claims a plugged-in pipe moves a band by 0.0 dE00, off a
hand-placed box. Through `socket_strip`'s window, with the clouds off, the piped frame and the
unpiped frame give **the same hex on all six sockets** — `#a0b8a8`, `#506e5e`, `#c9a179`, `#c19768`,
`#8ca8c1`, `#345776`, in both. The claim survives a better instrument, which is the outcome worth
recording: vanilla's pipe butts up outboard of the accent, against the flange pair ADR 0033 put
there, and the band sits inboard of it.

With the clouds **on**, the same comparison read 6.4 and 3.1 dE00 on two of those sockets, purely
from the weather. That is what a frame measured without this fix would have said, and it would have
read as a pipe doing something.

## What this bench cannot reach, and how to let it

**Three of the nine sockets are refused, by name rather than dropped.** `socket_strip` measures a
north or south connection on the `-e` sheet — the same machine with the camera a quarter turn on —
because only there does the socket run left-to-right on screen. A frame of a north-facing machine
draws the `` sheet, so the `-e` window names pixels that frame does not hold. Refused: the
collector's north helium-3, and the exchanger's north reactor energy and south steam.

**The way in is a zoom-1 frame of a machine facing east**, which would draw exactly the `-e` sheet.
No probe shoots one: `rotations.png` has all four directions but at zoom 1.5, and this bench refuses
any zoom but 1 because the halved sheet and a zoom-1 frame are the same scale exactly and nothing
else is. Not done here, and not a defect — a bench that guessed would be worse than one that says
what it cannot see.

Also out of reach: any machine with no committed `models/<machine>/geometry.json`, and any sheet
with a non-zero `frame.shift`, which none of ours has because the render margin is symmetric on
purpose.

## The caveat on the committed frames

**`docs/research/accent-legibility-at-zoom-1/`'s four probe frames predate the sheets they would be
windowed against.** They were committed at 21:17 on 2026-09-16 and both machines were re-rendered at
23:48 the same evening (`9ab4c57`, fixing the socket underside). Running this bench on them reports
0.2 to 1.2 dE00 rather than 0.2 to 0.7 — the extra is the re-render, not the game.

They are **left alone** rather than re-shot. They are the evidence ADR 0034 was decided on, and a
decision whose evidence has been quietly replaced is worth less than one whose evidence is old and
says so. `tools/test_measure_frame_accents.py` runs against them for that reason and asserts no
colour by value.

That note's own sentence — *"Re-running the probes reproduces these frames only until a machine is
re-rendered"* — came true the same evening it was written.
