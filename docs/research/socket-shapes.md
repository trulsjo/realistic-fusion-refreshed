# What a plumbable socket's mouth should look like

Taken 2026-09-14 with `scripts/probe-socket-shapes.ps1`, for
[#351](https://github.com/trulsjo/realistic-fusion-refreshed/issues/351). The rig is
[#350](https://github.com/trulsjo/realistic-fusion-refreshed/issues/350)'s; the decision it fed is
ADR 0033 and the rule it produced is in `models/house-style.md`. **This note is a probe's findings.
It asserts nothing and decides nothing.**

## Why the frames are committed and not just the rig

#350 committed the rig on the grounds that the next engine version could be asked the same question.
That is true of the *method* and not of these frames: the variant sheets were rendered with
`SOCKET_Z` at 0.044, and
[#356](https://github.com/trulsjo/realistic-fusion-refreshed/issues/356) changes it to 0.033. After
#356 lands, re-running the rig reproduces a different set. So the ten PNGs in `socket-shapes/` are
here because a decision recorded as "we looked and chose" with nothing left to look at is exactly
what #351's acceptance criteria were written to prevent.

**One rename.** The fourth treatment was called `collared` when these were shot and the files are
committed as `rimmed-inboard`, because #351 gave "collar" to the accent band. Nothing else about
them was touched.

## What was shot

Four treatments and one reference, each photographed twice: at zoom 8 (`seam-*.png`, one tile
across the frame, where a seam can be argued about) and at zoom 1 (`game-*.png`, 32 px to the tile,
where a player meets it). `pipe-alone` is the same six-tile pipe run with the machine taken away,
standing where a socket would have been, so the reference can be subtracted.

| File | What it shows |
|---|---|
| `seam-pipe-alone.png` | vanilla's pipe run ending in open air — one of the two references |
| `seam-bare.png` | what ships today, the control — the other reference |
| `seam-flanged.png` | vanilla's flange pair at the mouth — **the one chosen** |
| `seam-dark-cored.png` | a shadowed channel down the tube |
| `seam-rimmed-inboard.png` | the dark rim moved off the mouth onto the body face |
| `game-*.png` | the same five at 32 px to the tile |

The control is a control in fact and not by assertion: the `bare` variant reproduces the Assets
mod's `isotope-collector.png` and `-shadow.png` byte for byte, which the probe's own
`.DESCRIPTION` records the hashes for.

## What the frames showed

**There is almost no bare tube at a socket's mouth.** This is the finding that decided it, and
nobody had written it down before. With a pipe joined, what shows outside the slab is vanilla's
`pipe_cover` — a dark disc standing proud — then the accent band, then the slab edge. The
bare-metal stub `models/house-style.md` describes is not visible from outside at all. Three of the
four treatments were therefore decorating a surface a player never sees.

**`dark-cored` is indistinguishable from the control at zoom 8.** Put `seam-dark-cored.png` beside
`seam-bare.png` and the channel cannot be found. Same cause: no exposed tube to draw it on.

**`flanged` adds a second ring beside a ring that is already there.** Vanilla's `pipe_cover` is
already a flange at that join. The pair reads as a taller, thicker dark ring with a lighter outer
edge — a fitting finished rather than a fitting added.

**`rimmed-inboard` was the only visibly different one, and it costs the accent.** Moving the rim
inboard pushes the accent band onto the body face, where the slab edge clips it: `seam-bare.png`
shows a clear mint block, `seam-rimmed-inboard.png` a thin sliver half behind the stone.

**At zoom 1 none of the four can be told apart, the flange included.** Compare `game-bare.png`,
`game-flanged.png`, `game-dark-cored.png` and `game-rimmed-inboard.png`. #350's own criterion —
*"a difference nobody can see at 32 px to the tile is not a candidate"* — eliminates the whole set
read literally. ADR 0033 overrides it on stated grounds; that override is the single most
undo-able thing in this decision and is written down in two places for that reason.

## What this note does not answer

At zoom 1 an accent is roughly six pixels of pale colour, and tritium and helium-3 are both pale.
Whether a player can tell them apart at that size is unmeasured. It is a question about every
accent on every machine rather than about sockets, so it is
[#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359) and was deliberately kept
out of #351.

## Rerunning

```
pwsh -File scripts/probe-socket-shapes.ps1
```

Pass `-SheetDirectory` a directory that already holds the variant sheets to skip Blender, which is
the slow half. The rig is written for `rf-isotope-collector` and names it in three places; its
`.DESCRIPTION` says which. Exit 0 means the pictures were taken, never that any shape is right.
