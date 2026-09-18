# What a contained socket's pipe cover misses by, and what the engine draws without one

Measured 2026-09-17 with `scripts/probe-pipe-cover-miss.ps1` and `tools/measure-pipe-cover-miss.py`,
for [#390](https://github.com/trulsjo/realistic-fusion-refreshed/issues/390). **This note is a
probe's findings.** It draws no threshold and proposes no remedy;
[#391](https://github.com/trulsjo/realistic-fusion-refreshed/issues/391) weighs those and the choice
is Truls's.

> **Answered, 2026-09-17.** [ADR 0036](../adr/0036-every-socket-is-drawn-at-pipe-height.md) levels
> every contained socket to vanilla's pipe height and thickness, which makes the cover concentric
> and the miss below zero, and keeps the `pipe_covers` declaration **provisionally**. Nothing in
> this note changes: it is the measurement the decision acts on, and the figures below are what a
> re-measurement after #392 has to be compared against.

## What was seen, and what it turned out to be

Truls saw it on the frames committed with #389: on `rf-heat-exchanger`'s short ends the
`rf-reactor-energy` sockets have a pipe cover sitting **below and outboard** of the socket, attached
to nothing. The outline was understood — a CONTAINED connection (ADR 0018) is drawn at world height
0.55 and the engine draws `pipe_covers` flat on the ground at the connection tile, and nothing
reconciles the two — but no number was established.

## The miss, measured

**0.376 to 0.378 tiles, which is 12.0 screen pixels at zoom 1.** Measured twice at scales eight
times apart, the two answers differ by 0.002 tiles:

| frame | socket | cover's drop below the socket's drawn axis |
|---|---|---:|
| `exchanger-west-x8`, zoom 8 | west `rf-reactor-energy`, **contained** | +102.68 px = **+0.4011 tiles** |
| | west water, **plumbable** (the control) | +5.85 px = **+0.0229 tiles** |
| | **the miss** | 96.83 px = **0.3782 tiles** |
| `exchanger-west-z1`, zoom 1 | west `rf-reactor-energy`, **contained** | +11.60 px = **+0.3626 tiles** |
| | west water, **plumbable** (the control) | −0.44 px = **−0.0138 tiles** |
| | **the miss** | 12.04 px = **0.3764 tiles** |

The tool prints these to one decimal in pixels; the tile figures above are that division done once
rather than twice, because rounding a drop to three places and then subtracting two of them moves
the answer by more than the two zooms differ by.

**It is a difference between two readings, not a reading against a prediction**, which is what #390
asked for. Both sockets are on the same short end of the same machine, two tiles apart, in one
frame, in one light. The contained one is drawn at world height 0.55 and the plumbable one at
`rf_blender.SOCKET_Z`, 0.033, and the cover is on the ground under each.

**The projection predicts 0.3661 tiles** — (0.55 − 0.033) × 0.70804, where the second factor is how
far one tile of world height climbs the screen through the render camera. Measured is 0.3764 at zoom
1 and 0.3782 at zoom 8, so the real miss is **0.010 to 0.012 tiles larger** than the arithmetic, and
larger at both scales. That residue is about seven tenths of a sheet pixel and this note does not
explain it; the likeliest reading is that the contained socket's own stub hides the top of its cover
and pushes the centroid down, which the plumbable socket — barely off the ground — cannot do.

**That the two zooms agree at all is the check on the method.** The window, the axis and the
subtraction are worked out independently at 32 and at 256 pixels to the tile, and a mistake in any
of them would not survive the change of scale intact.

**Quote the `exchanger-west-*` frames and not `exchanger-whole-z1`.** On the whole-machine frame the
east end reads +0.545 tiles against the west's +0.363, because the machine's own body and the
westerly sun occlude the far cover differently. The dedicated six-tile frames are where both sockets
are clear.

### How it was measured, and why nothing had to recognise a cover

The probe runs three times and the frames are subtracted. The runs differ in one thing — which fluid
boxes still declare `pipe_covers` — so **the pixels that differ between two runs are the cover**, and
nothing has to know what one looks like, what colour it is or how big it ought to be. That matters
because a cover on a rendered sheet, on a Krastorio 2 sprite and on a mockup plate are three
different pictures, and this finds all three the same way.

The socket's **drawn axis** comes off the committed sheet through `tools/socket_strip.py`'s
`Strip.axis_row` and is put on the frame by `tools/measure-frame-accents.py`'s `sheet_to_frame` —
the #385 sidecar is what makes that possible at all, and the #387 mapping is borrowed rather than
rewritten.

## What Factorio does when a contained box declares no covers

**It loads, it draws nothing in their place, and it says nothing about it.** Measured on 2.0.77:

- `-Strip contained` removes `pipe_covers` from **12 fluid boxes** — every box in the tree whose
  connections all carry a `connection_category`. The game started, built the rig and took every
  frame.
- **Zero Error and zero Warning lines** in the whole 113-line log.
- Nothing is drawn where the cover was. The subtraction is the cover and the frame behind it is the
  ground.

**No box in the tree is mixed**, which had to be checked because `pipe_covers` is declared per box
rather than per connection: a box holding both kinds could not lose its covers for one and keep them
for the other. Twelve boxes are entirely contained and none is mixed, so the question is
hypothetical today — and the probe reports it every run, so it will say when it stops being.

For scale, asked of the loaded prototypes rather than listed: **24 contained connections across 9
prototypes** — `rf-aneutronic-reactor` (4), `rf-direct-energy-converter` (2), `rf-hc-exchanger` (1),
`rf-heat-exchanger` (3), `rf-heater` (2), `rf-pipe` (4), `rf-pipe-to-ground` (2), `rf-pump` (2),
`rf-reactor` (4).

> **Twenty-six since #276**, 2026-09-18: `rf-hc-exchanger` went from one energy connection to three
> when it took `rf-heat-exchanger`'s footprint, and `contain()` walks the box, so both new ones carry
> the category. `load-check.ps1` counts the live figure on every run; the numbers above are this
> probe's own dump and are left as taken.

## The north connection does not show it, because it has no cover to show

`rf-heat-exchanger`'s north `rf-reactor-energy` connection is the reactor contact, and a player
never sees that face bare. **Nothing at it changes between the runs** — standing alone or with a
reactor actually bolted on, at zoom 8 and at zoom 1, in all four frames. So either no cover is drawn
there or it is entirely hidden behind the machine's own sprite; for a player the two are the same
thing, and this probe does not distinguish them.

**That is not true of every north face.** `rf-direct-energy-converter`'s north connection, on a
machine of the same 15 × 5 footprint, draws a cover 36 × 11 px at zoom 1 — sitting on the grass
clear of the plate. The difference is the art, not the connection: a rendered sheet draws its body
out past the footprint and a mockup plate stops at it.

## A Krastorio 2 machine does not look wrong without its cover — it looks better

`rf-reactor` still wears Krastorio 2's art, and six contained boxes belong to machines nobody has
rendered, so this had to be asked of one of them rather than assumed.

Its west plasma face draws a cover **52 × 224 px at zoom 8, 7 × 28 px at zoom 1** — the same vanilla
sprite, standing on the grass beside the yellow K2 body and touching nothing, exactly as it does on
our own sheet. **With the declaration gone the K2 sprite's own edge is clean**: it draws its own
pipework, and the cover was adding a stub to a machine that did not need one. Its north energy face
shows nothing, like the exchanger's.

So on the evidence of one machine, the answer to "would a K2-art machine look wrong with its cover
removed" is **no**. One machine is not six, and this note does not claim otherwise.

## The mockups show the same miss, more starkly

`rf-aneutronic-reactor` and `rf-direct-energy-converter` wear mockups — flat plates with labelled
connection marks — and neither has a committed `models/<machine>/geometry.json`, so neither has a
drawn axis to measure a drop against. What can be said is where the cover is, and on the converter
it is unmistakable: **a grey pipe-cover blob on the grass above the plate's north edge, clear of the
machine altogether**, beside a yellow `energy` mark it does not touch.

| machine | face | cover at zoom 8 | at zoom 1 |
|---|---|---|---|
| `rf-aneutronic-reactor` | west plasma | 55 × 228 px | 7 × 28 px |
| | north energy | 289 × 90 px | 36 × 11 px |
| `rf-direct-energy-converter` | north energy | 290 × 90 px | 36 × 11 px |
| | south energy | — | 37 × 25 px |

A mockup is a placeholder and its look is not a decision anybody has made, so nothing here is a
finding about the mockups themselves. It is a finding about the cover: it misses on art of all three
kinds.

## What this does not settle

- **It proposes nothing.** The 0.55 is INHERITED rather than chosen — it is the height every socket
  had before #349, and `models/house-style.md` records that "a look chosen for them would be a
  decision nobody has been asked for". So levelling the sockets is as live a remedy as changing the
  cover, and this note weighs neither. #391 does.
- **`-Strip all` is an instrument, not a proposal.** It takes the covers off plumbable sockets too,
  which would be wrong in the game and is suggested nowhere. It exists because a plumbable socket's
  cover survives the `contained` run, so the control #390 asks for would otherwise be unmeasurable.
- **The 0.011-tile residue is unexplained**, and is recorded rather than rounded away.
- **One machine per art source.** `rf-reactor` stands for Krastorio 2's art and two mockups stand for
  the mockups; the other five contained boxes were not photographed.

## Reproducing it

```
pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7                  -OutputDirectory covers
pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip contained -OutputDirectory bare
pwsh -File scripts/probe-pipe-cover-miss.ps1 -MapSeed 7 -Strip all       -OutputDirectory bare-all
python tools/measure-pipe-cover-miss.py covers bare --all bare-all
```

**The same `-MapSeed` on all three runs is not optional.** The grass variant under a machine comes
off the map seed, so three runs on random maps differ on most of a frame's pixels and the
subtraction measures the ground instead of the cover.

No frame is committed. All of them are reproducible to the byte by the four commands above, which is
what `-MapSeed` and #387's cloud fix bought.
