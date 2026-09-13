# How small a feature can be and still read

Measured 2026-09-13 for [#335](https://github.com/trulsjo/realistic-fusion-refreshed/issues/335),
which had to choose a detail floor and needed to know what one actually is. The rule the numbers
produced lives in `models/house-style.md`; this note is only how they were got. Rerun it with

```
python docs/research/detail-floor/measure-detail.py --rivets
```

## The question

`models/house-style.md` said *"Detail floor: nothing smaller than 0.125 tiles (8 px). Panels, seams
and bolts below that vanish or shimmer."* — bolts by name; rivets it never mentioned.

Every seam, every groove, every rib band and **every bolt and rivet** on both rendered machines was
under it: 261 of the 369 features the gate now checks, or 70.7 per cent, measured by rebuilding
both machines with the checker set to the old figure. Whole classes of feature at a hundred per
cent, and the classes the rule named. Nobody had measured which way that cut.

## Two units, and the old rule used the wrong one

A sheet is rendered at 64 px per tile and `pictures.lua` draws it at `scale = 0.5`, so **one tile is
32 pixels on the player's screen**. "0.125 tiles (8 px)" is eight pixels of the *sheet* — a
resolution nothing is ever displayed at. Read as screen pixels it is four, and every number below is
given both ways.

Vanilla's sheets use the same convention — 64 px per tile at `scale = 0.5` — so one pixel there is
one pixel here and the two halves of the table are directly comparable.

## The automatic sweep

Each sheet is high-passed against a 9 px box blur, so a run is a feature against its **local**
surround — a rivet against the panel it sits on, a groove against the plate it is cut into — rather
than a whole part against the background. Both signs count, because a raised feature is lighter than
its surround and a cut one darker. Opaque pixels only.

| sheet | runs | p10 | median | p90 | median in tiles | median on screen |
|---|---:|---:|---:|---:|---:|---:|
| vanilla boiler | 3 740 | 1 | 2.0 px | 5 | 0.031 | 1.0 px |
| vanilla heat exchanger | 3 747 | 1 | 2.0 px | 5 | 0.031 | 1.0 px |
| vanilla storage tank | 6 613 | 1 | 2.0 px | 5 | 0.031 | 1.0 px |
| vanilla electric furnace | 5 625 | 1 | 2.0 px | 6 | 0.031 | 1.0 px |
| vanilla chemical plant | 439 722 | 1 | 2.0 px | 6 | 0.031 | 1.0 px |
| **ours — heat exchanger** | 21 861 | 1 | 3.0 px | 6 | 0.047 | 1.5 px |
| **ours — isotope collector** | 7 765 | 1 | 2.0 px | 6 | 0.031 | 1.0 px |

**Our two rows are of the sheets as of #340.** Only the run count moves when a machine is
re-rendered — it did twice while #335's own tickets were landing, which is why the count is pinned
to a commit and the three percentiles are not. Vanilla's five rows move only when Wube reships.

**THE MEDIAN COUNTS SURFACE GRAIN, not only deliberate features**, so read it as "typical
high-frequency feature" and never as a design target. Procedural grime and a rendered surface both
put one- and two-pixel variation everywhere; so does vanilla's painted texture. What makes the
table worth anything is that the same procedure ran on both sides.

The chemical plant's run count is large because its sheet is an animation with many frames. It
changes nothing: the distribution is the same as the others'.

## The hand measurement, which is the clean figure

Vanilla's boiler carries rivet rows around its front hatch. Those are certainly deliberate, so
measuring only them removes the grain the sweep cannot separate out. Sixty-three light runs over
eleven rows:

| | sheet px | tiles | screen px |
|---|---:|---:|---:|
| vanilla boiler hatch rivets, median | 2.0 | 0.031 | 1.0 |
| the same, 10th to 90th percentile | 1–7 | 0.016–0.109 | 0.5–3.5 |

## What it settles

**The old floor was four times vanilla's median and above vanilla's 90th percentile.** As written it
forbids nearly all of Factorio's own art. The isotope collector sits exactly on vanilla's density at
2.0 sheet pixels; the heat exchanger is half again coarser at 3.0. Neither was ever too fine — the
rule was too coarse.

There is headroom below what we ship. Vanilla's deliberate rivets are two sheet pixels; our smallest
feature is 3.2. The floors #335 chose are therefore set *at* what we already do rather than above
it, and the argument for not going finer is taste rather than legibility.

## What this does not measure

- **Contrast.** A feature reads by size *and* by how far it differs from its surround. The sweep
  fixes contrast at 14 of 255 and varies only width, so it cannot say whether a wider feature at
  lower contrast would do as well. Nothing in the house style governs contrast either.
- **Which features are deliberate.** Only the hand measurement does, and only on one hatch.
- **Zoom.** Everything is quoted at `scale = 0.5`, one tile to 32 screen pixels. A player who zooms
  in sees more of the sheet's 64 px, so the floors are conservative rather than tight.
- **Anything Wube has published.** These are measurements of the shipped art, not a reading of a
  style guide. If one exists it would be a second source and has not been consulted.
