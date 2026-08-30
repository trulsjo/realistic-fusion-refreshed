# Which dagre levers actually shorten the tree viewer's edges

Measured 2026-08-30 ([#171](https://github.com/trulsjo/realistic-fusion-refreshed/issues/171)) in
Chrome against `tree-viewer-out/angels-lane.html`, built from `.mod-cache/angels` on **Factorio
2.0.77** — the default view, 406 live technologies and 946 edges after #168 hid the 72 that no
player can research. **Facts only.** The change these fed is `CARDW 230 → 170` with a wrapping
title; what each rejected lever costs is recorded here so nobody sweeps them again.

## The question

Truls asked whether the tree can be optimised for shorter links, and said growing taller and
narrower is acceptable. dagre's ranker is left at its default, `network-simplex`, which already
minimises total weighted edge length in *rank* space — so the question is really about the aspect
ratio, and about which of dagre's remaining knobs move it.

## Method

`dagre.layout()` was run directly, rendering nothing, over the real node set with the real card
heights. Edge length is the sum of the segment lengths of the polyline dagre returns, which is what
the eye actually follows. Every row below is one layout of the same 406-node graph.

## What sets the width

Not the node count. The widest rank holds **41** technologies, which at 230 + 16 is 10166px — yet
the canvas is **42796px**, over four times that. The excess is the chains of dummy nodes dagre
inserts for edges that span many ranks; each occupies horizontal room in every rank it crosses.

That is the finding the rest follows from: **the only lever that moves width is the card's own
width.** Everything else redistributes.

## Before and after

The two configurations that actually exist, measured in the rendered viewer rather than modelled:

| | W | H | total | median | longest | names cut |
|---|---|---|---|---|---|---|
| **before** — 230px, title cut at one line | 42796 | 8265 | 7505215 | 5072 | 47152 | 8 |
| **after** — 170px, title wraps to two | 33682 | 8424 | 6016714 | 4156 | 38501 | 0 |

21% narrower for 1.9% taller; the longest edge falls 18% rather than rising.

Everything below is a **sweep**, run to choose that width. Two models appear in it and they are not
interchangeable — read the caption on each table before comparing a number across them.

## The levers

Sweep model A: no title wrapping, so the 230px row here is the real *before*. `rankdir TB`,
`nodesep 16`, `ranksep 90` unless stated.

| Configuration | W | H | total | median | longest |
|---|---|---|---|---|---|
| **baseline** (230px) | 42796 | 8265 | 7505215 | 5072 | 47152 |
| `align: 'UL'` | 45158 | 8265 | 8773118 | 5367 | **87000** |
| `align: 'DL'` | 43407 | 8265 | 7674088 | 4929 | 49859 |
| `weight: 8` on sole-prerequisite edges | 47964 | 8250 | 8322696 | 5542 | 60521 |
| `ranksep: 130` (at 170px) | 33682 | 9982 | 6128884 | 4343 | 39679 |
| `ranksep: 60` (at 170px) | 33682 | 7252 | 5932561 | 4113 | 37614 |
| **170px, title wraps** | **33682** | **8424** | **6016714** | **4156** | **38501** |

Three levers are worse than doing nothing:

- **`align`** — forcing one corner beats the default at nothing. dagre's default runs all four
  alignments and averages them, and the average wins. `UL` nearly doubles the longest edge, to
  87000px on a canvas 45158px wide.
- **Edge `weight`** — weighting a technology's edge to its sole prerequisite, to pull the long
  Angels smelting ladders into vertical alignment, makes every column worse: 12% wider, 11% more
  total length, 28% on the longest edge. Straightening one chain bends the others around it.
- **`ranksep`** — does not change the width **at all**: 33682 at 60, 90 and 130 alike. It only
  trades canvas height against vertical edge travel. The width-for-height trade the ticket hoped
  for cannot be bought here, because rank separation and rank width are orthogonal.

## Card width, and what it costs

Sweep model B: every row wraps the title, so the 230px row is **not** the shipped before — it is
what 230px would look like with wrapping, and its height is 85px greater than model A's for that
reason. Compare rows within this table, not across to the one above.

Width scales almost everything linearly, and it is the only lever that does:

| Card width | W | H | total | median | longest | titles on one line | unlock rows ellipsised |
|---|---|---|---|---|---|---|---|
| 230 (was) | 42796 | 8350 | 7512971 | 5081 | 47171 | 98.0% | 1.0% |
| 190 | 36707 | 8384 | 6514013 | 4507 | 41386 | 95.6% | 3.5% |
| **170 (is)** | 33682 | 8422 | 6016536 | 4153 | 38499 | 87.2% | 8.0% |
| 150 | 30657 | 8541 | 5528950 | 3880 | 35687 | 72.2% | 16.5% |
| 130 (3 lines) | 27632 | 8747 | 5048171 | 3624 | 32952 | 49.0% | 30.7% |

Within this model 170px is 21% narrower than 230px for 0.9% taller; against the real before, which
did not wrap, it is 21% narrower for 1.9% taller. Either way the longest edge falls 18% rather than
rising, which is the test the ticket set. Below 170 the returns keep coming but the card stops
reading: at 150 a sixth of the visible unlock rows are cut, at 130 nearly a third.

Wrapping the title to a second line is what makes the narrowing affordable. It costs 56 of the 406
cards an extra 17px and buys back the 8 names that were being cut at 230px, so the narrower card is
**more** legible than the wide one, not less.

## Three measurement traps, all hit here

- **`canvas.measureText` does not agree with the browser's line breaking.** A greedy word-wrap over
  canvas metrics called "Advanced nickel smelting 2" a one-line title; the browser rendered two, and
  that card's text hung 20px below its border. The viewer now measures with a real off-screen
  `div.card > div.head` — the thing that will render it.
- **A row assumed to be one line was two.** `.card .packs` carries the count formula, and
  `artillery-shell-speed-1`'s `1000+3^(L-1)*1000` wrapped at 170px where it had fitted at 230px,
  making 84 technologies' worth of that shape taller than the height dagre was told. The row is
  `nowrap` with an ellipsis now, like the unlock rows beneath it; the formula is still printed in
  full in the detail panel.
- **The measurement missed what the render drew.** The probe measured the technology's name; the
  head also prefixes `⊘` or `⊝` for a technology that is unresearchable or gated behind one. A
  badged name near the wrap boundary would therefore be sized for one line and drawn on two —
  reachable by turning the hidden-technology toggle on, which badges 72 heads at once. The viewer
  now builds the head's content once, in `headHtml()`, and both the probe and the card use it.

All three were invisible at 230px. None is a dagre problem — they are the model of the card
disagreeing with the card, and a layout that is tuned but mismodelled is worse than one that is
neither.

## Cost of measuring

Sizing all 406 heads takes **119 ms**, about 292 µs each, against roughly 4500 ms for the
`dagre.layout()` it feeds — 2.6%, and only on a layout the cache has not seen before (#175). Left
unbatched on those numbers.
