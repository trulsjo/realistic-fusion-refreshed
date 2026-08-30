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

### The far zoom is where it costs

Below `k < 0.5` the viewer swaps to `.far`: the body is hidden and the head renders at 18px on a
25.2px line box. The card keeps the height it was given, which was measured at 12px, so a name that
needed one line up close can need three down here. Counted in the rendered viewer at 170px:

| far-zoom head, 406 cards | count |
|---|---|
| needing three lines or more | 35 |
| overflowing their card's height | 15 |
| worst overflow | 25px (`physical-projectile-damage-7`) |
| **clipped** | **0** |

Nothing clips, and the distinction matters: `.card .head` sets `overflow: hidden` but never a
height, and `.card` is deliberately `overflow: visible` so the counter-scaled corner badges can
escape it. There is no box for the text to be clipped against. Those 15 titles hang a little past
the bottom border into the 90px rank gap. Left alone: sizing every card for its 18px head would
make the whole canvas taller for a zoom level at which the reader is scanning colour and shape.

### Wrapping

Wrapping the title to a second line is what makes the narrowing affordable. It costs 56 of the 406
cards an extra 17px and buys back the 8 names that were being cut at 230px, so the narrower card is
**more** legible than the wide one, not less.

## Splitting a rank: the one lever that could still win

Raised by Truls: use more ranks, so each holds fewer cards. `minlen` is the obvious knob and is not
the right one — forcing every edge to span two ranks leaves **40 ranks and 41 cards on the
widest**, identical width, 42% more height. It scales the same structure apart, which is
`ranksep` again.

The idea needs the ranks genuinely split, which means adding scaffolding edges between cards that
currently share a rank. Layout runs twice: once to learn the ranks, once with the scaffolding in.
The scaffolding is never drawn; only the real edges are measured below.

| how each rank was halved | W | H | total | median | longest |
|---|---|---|---|---|---|
| *baseline, 40 ranks* | *33682* | *8424* | *6016714* | *4156* | *38501* |
| graph order, `floor` pairing | **29445** | 10547 | **4649671** | 3993 | **21477** |
| by x, reversed | 29663 | 10259 | 5261621 | 4520 | 22111 |
| by x, forward, `ceil` blocks | 34026 | 10809 | 6123492 | 4319 | **53907** |
| random, seed 999 | 34374 | 11989 | 6377902 | 4486 | 45081 |
| random, seed 42 | 34584 | 12412 | 6326137 | 4625 | 55309 |
| thirds, by x | 31631 | 12491 | 5513497 | 4327 | 23095 |

**The best of these is the best result anywhere in this document** — the longest edge nearly
halved, total length down 23%, width down 13%, for 25% more height, which is exactly the trade
the ticket authorised.

**And it is not shippable as measured.** Rows two and four differ only in `floor` versus `ceil` on
odd-length ranks, and that single tie-break moves the longest edge from 21477 to 53907 — from 44%
better than the baseline to 40% worse. Random pairings lose consistently, so the ordering plainly
matters; but the two structured orderings that win and the structured ordering that loses are not
told apart by anything measured here. The mechanism is not understood, and a layout that depends on
an invisible coin is worse than one that is merely wide.

What would make it safe is not a better guess but a measurement: generate several candidate splits,
lay each out, keep whichever has the shortest total. A layout is ~4500 ms and the viewer already
caches one per `rankdir|deadShown` (#175), so the search costs seconds once per state and nothing
after. Recorded as its own ticket rather than forced into this one.

## Three measurement traps, all hit here

- **`canvas.measureText` does not agree with the browser's line breaking.** A greedy word-wrap over
  canvas metrics called "Advanced nickel smelting 2" a one-line title; the browser rendered two, and
  that card's text hung 20px below its border. The viewer now measures with a real off-screen
  `div.card > div.head` — the thing that will render it.
- **A row assumed to be one line was two.** `.card .packs` carries the count formula, and
  `artillery-shell-speed-1`'s `1000+3^(L-1)*1000` wrapped at 170px where it had fitted at 230px:
  that row rendered 31px tall against the 15px the height formula allows, leaving the card 18px
  short. 84 technologies carry that shape. The row is
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
