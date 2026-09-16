# The socket join, before and after the flange pair

The frames [#357](https://github.com/trulsjo/realistic-fusion-refreshed/issues/357)'s acceptance is
given against. **The answer is not here — it is on #357, in Truls's own words.** This note says what
was shot, how, and what the pairs are comparing, so that the next acceptance is a diff rather than
a re-render.

Taken 2026-09-15 with `scripts/probe-socket-height.ps1`.

**THIS NOTE DESCRIBES THE #357 PAIR AND NOTHING SINCE.** #374 and #378 changed the probe under it:
it paves with `lab-dark-2` rather than grass and it writes one pair of frames per plumbable socket,
`seam-<machine>-<side>-<fluid>.png` and `run-<machine>-<side>-<fluid>.png`, so none of the
filenames below is one it produces today. `docs/research/socket-join/README.md` says what the two
sets in that directory are and which of them a re-run reproduces. Nothing measured here has moved;
the frames it names are still the frames on disk.

## What is being compared, and why it is not what #357 first said

#357 was written as an acceptance of a quarter of a pixel: #356 dropped every plumbable socket by
0.0109 tiles and the acceptance Truls gave on 2026-09-14 was against a reference half a pixel high.

**That quarter pixel was never rendered on its own.** #356's height correction and #351's flange
pair reached the sheets in one commit, `e9020d1`, because #356 asked for one set of frames rather
than two. So the pair below is not a quarter pixel; it is everything that happened to a socket
between the art Truls last accepted and the art that ships:

| | sha | socket |
|---|---|---|
| before | `e8cdd1c` | z 0.044, radius 0.249, no flange pair |
| after | `e9020d1` | z 0.033, radius 0.249, flange pair at the mouth |

`0b5a918` re-rendered byte-identical afterwards and #364's band re-measure (`0369188`) changed prose
only, so `e9020d1` is still what ships. The before side was produced by a `git worktree` at
`e8cdd1c` with today's probe copied in, so both halves are shot by the same instrument.

## The frames

Eight from the probe, two sets of four:

| file | zoom | what it is |
|---|---|---|
| `joint-collector-{before,after}.png` | 8 | rf-isotope-collector's west socket with ordinary pipe run into it |
| `joint-exchanger-{before,after}.png` | 8 | rf-heat-exchanger's water socket, the same way |
| `pipe-alone-{before,after}.png` | 8 | three tiles of vanilla pipe on bare ground, the reference |
| `run-{before,after}.png` | 1 | a pipe run leaving the collector, at 32 px to the tile |

And five montages, which are what a person actually looks at — `models/post.py compare` for the
first three, `models/post.py vanilla` inside the last two:

| file | shows |
|---|---|
| `montage-collector-seam.png` | the collector's seam, before against after, with vanilla's pipe beside it |
| `montage-exchanger-seam.png` | the same for the exchanger |
| `montage-run-zoom1.png` | the run at the size a player meets it |
| `montage-heat-exchanger-composite.png` | the sheet on a tile grid beside vanilla's own sprites, before against after |
| `montage-isotope-collector-composite.png` | the same for the collector |

**`run.png` is at zoom 1 here and was at zoom 2 until [#371](https://github.com/trulsjo/realistic-fusion-refreshed/issues/371).**
Both halves of this pair were shot after that fix, so the frame that decides whether a difference is
visible is at the size it is met at rather than twice it.

## What the frames cannot tell you, which is the ground

**The grass differs between the two runs and it is not the art.** Each probe run creates a fresh
map, and `pave` retiles the working area with `grass-1` but the tile VARIANT chosen is the map's,
not ours — so 85 per cent of `pipe-alone`'s pixels differ between before and after, on a frame whose
only subject is vanilla pipe that did not change. Measured by row band: bands of bare ground differ
on 99 per cent of pixels at a mean delta of about 32, while the bands the pipe runs through differ
on 38 to 44 per cent at about 10 — the pipe holds still and the grass under it does not. Decoratives
outside the paved rectangle survive, which is the plant in the corner of one `run` frame and not the
other.

**SAY THE METRIC OR THE NUMBER IS NOT REPRODUCIBLE**, which is the same rule as `CONTEXT.md`'s
**Proud** entry one layer down. The deltas above are the per-pixel SUM of absolute difference over
all four RGBA channels, averaged over a band, with the 768-row frame cut into eight bands of 96.
Read instead as a mean over the three colour channels, the same frames give 9.7 to 11.4 for bare
ground and 3.0 to 3.8 where the pipe runs: the contrast survives, every figure changes, and a reader
checking this note against the frames gets numbers that do not match it. One reviewer did exactly
that and reported the statistics as not reproducing.

So these pairs are for reading the SEAM. They do not support a pixel diff, and a whole-frame
impression will be dominated by grass.

**"A fixed map seed would fix it" was written here and is FALSE**, which #374 found out by trying
it: a pinned seed on a surface of the rig's own still left 84.53 per cent of the reference frame's
pixels differing between two runs, at a mean channel delta of 11.5 over the ones that did. The
cause is not the seed but the TILE. base's `grass-1` declares its variants with weighted
probabilities over sizes 1, 2 and 4, so the engine draws for every tile `set_tiles` writes and no
seed a rig can set reaches that draw. Paving with a lab tile, whose main variant is `count = 1`,
does fix it: two runs are byte-identical now, which is what `docs/research/socket-join/every-side/`
is shot on. These pairs are still grass and still not diffable.

## What settled it

Nothing here. #357 is a human checkpoint: an agent's job was to make the comparison easy and then
stop. The answer, and what it means for #362, is on the issue.
