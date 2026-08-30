# Which dagre levers actually shorten the tree viewer's edges

Measured 2026-08-30 ([#171](https://github.com/trulsjo/realistic-fusion-refreshed/issues/171)) in
Chrome against `tree-viewer-out/angels-lane.html`, built from `.mod-cache/angels` on **Factorio
2.0.77** — the default view, 406 live technologies and 946 edges after #168 hid the 72 that no
player can research. **Facts only.** The change these fed is `CARDW 230 → 170` with a wrapping
title; what each rejected lever costs is recorded here so nobody sweeps them again.

Extended 2026-08-30 ([#182](https://github.com/trulsjo/realistic-fusion-refreshed/issues/182))
with two more levers. The rank split changed nothing in the viewer and is the record of a lever
that does not hold; `edgesep` is the one that did, and ships at 6.

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
after. Recorded as its own ticket rather than forced into this one —
[#182](https://github.com/trulsjo/realistic-fusion-refreshed/issues/182), whose answer is the
next section.

## The rank split, measured on two lanes (#182)

Measured 2026-08-30 in Chrome with `scripts/tree-layout-probe.js`, against
`tree-viewer-out/angels-lane.html` and a `tree-viewer-out/krastorio2-lane.html` regenerated the same
day so both lanes carry the shipped 170px card. **The answer is that no rank-split rule holds: the
split wins on Angels and loses on Krastorio 2, in every variant tried. Nothing was shipped to the
viewer.**

### How it was measured

The probe is committed rather than pasted and lost, because this is the third ad-hoc dagre harness
this one question has needed. It takes each node's size **off the rendered card** —
`offsetWidth`/`offsetHeight` on the `.card` the viewer drew — instead of re-deriving the viewer's
height formula, so it cannot drift from the render — which is what all three traps below were.

The scaffolding is stated exactly here because #171's version of it was not written down precisely
enough to reproduce, and the numbers differ as a result. Within a rank of `n` cards, ordered by
`order`, the first `k` are the upper half and the rest the lower, joined pairwise `A[i] → B[i]`;
`half` says where `k` falls on an odd `n`.

| knob | value | meaning |
|---|---|---|
| `order` | `graph` | the order the viewer added the nodes |
| | `x` | by cross-rank coordinate in the first layout, ascending |
| | `xrev` | the same, descending |
| `half` | `floor` | k = floor(n/2) |
| | `ceil` | k = ceil(n/2) |
| | `alt` | no block split at all: even indices up, odd indices down |

Scaffolding edges are marked, never drawn, and excluded from every number below. They cannot close a
cycle: they join two cards of the same rank, and same rank means there is no path between them in
either direction.

The baseline row reproduces #171's shipped layout exactly — 33682 x 8424, total 6016714, longest
38501, which is the evidence that it is measuring the same thing the earlier sweep did.

### Angels lane — the split wins

406 live technologies, 946 edges, 40 ranks, widest rank 41 cards. `rankdir TB`:

| candidate | W | H | total | median | longest | ranks |
|---|---|---|---|---|---|---|
| *baseline* | *33682* | *8424* | *6016714* | *4156* | *38501* | *40* |
| **graph / `ceil`** | **29879** | 10203 | **5531519** | 4658 | **28761** | 49 |
| graph / `floor` | 32524 | 10562 | 5912902 | 5212 | 39450 | 51 |
| graph / `alt` | 36833 | 11739 | 6683283 | 4255 | 62467 | 56 |
| x / `floor` | 38248 | 10996 | 7103609 | 4723 | 37461 | 53 |
| x / `ceil` | 36380 | 10807 | 7015125 | 4819 | 56565 | 52 |
| x / `alt` | 35544 | 11580 | 6734475 | 4741 | 43048 | 55 |
| xrev / `floor` | 37024 | 10257 | 7356331 | 4899 | 59587 | 49 |
| xrev / `ceil` | 31644 | 10386 | 6004111 | 4630 | 28498 | 50 |
| xrev / `alt` | 37448 | 11851 | 7464588 | 4773 | 52743 | 57 |

Three of the nine beat the baseline on total length; two of those three also beat it on the longest
edge. Selecting by shortest total picks `graph/ceil`, which is **8.1% off the total and 25.3% off
the longest edge, for 21% more height and 11% less width** — and is within 1% of the best longest
edge in the table, so the two criteria do not fight here.

The same three candidates in `rankdir LR`:

| candidate | W | H | total | median | longest | ranks |
|---|---|---|---|---|---|---|
| *baseline* | *10390* | *22308* | *4216707* | *3139* | *29113* | *40* |
| **graph / `ceil`** | 12730 | 18979 | **3912752** | 3385 | **18475** | 49 |
| graph / `floor` | 13250 | 20713 | 4188731 | 3776 | 26456 | 51 |

`graph/ceil` wins there too — 7.2% off the total, 36.5% off the longest edge — so the Angels result
is not an artefact of one orientation.

**And #171's coin is still there, with its sign reversed.** `graph/floor` and `graph/ceil` differ
only in `floor` versus `ceil` on odd-length ranks, and that alone moves the longest edge from 39450,
which is *worse* than the baseline, to 28761. In #171's sweep `floor` was the good side and `ceil`
the bad one; under the scaffolding spelled out above it is the other way round. So the tie-break is
not merely arbitrary — **which side of it is good does not survive a re-implementation of the same
description.**

### Krastorio 2 lane — nothing wins

329 live technologies (330 dumped, 1 unresearchable), 617 edges, 26 ranks — and the widest rank holds
**41 cards, exactly as Angels does**, so this is not a lane that lacks the pathology. `rankdir TB`:

| candidate | W | H | total | median | longest | ranks |
|---|---|---|---|---|---|---|
| *baseline* | *19907* | *5203* | *1968230* | *1816* | *14669* | *26* |
| graph / `floor` | 22612 | 6978 | 2203290 | 2575 | 18296 | 35 |
| graph / `ceil` | 24127 | 6344 | 2421383 | 2686 | 24591 | 32 |
| graph / `alt` | 20028 | 7023 | 2082356 | 2423 | 15927 | 35 |
| x / `floor` | 21711 | 7163 | 2453436 | 2360 | 23434 | 36 |
| x / `ceil` | 21959 | 7277 | 2720910 | 3064 | 23102 | 37 |
| x / `alt` | 21231 | 7307 | 2166297 | 2363 | 16005 | 37 |
| xrev / `floor` | 23631 | 5828 | 2165218 | 2448 | 33526 | 29 |
| xrev / `ceil` | 22761 | 5611 | 2170492 | 2530 | 20877 | 28 |
| xrev / `alt` | 21544 | 6943 | 2162255 | 2461 | 18485 | 34 |

Every one of them loses to the baseline on all four of width, height, total and longest. The nearest
miss is `xrev/alt`, at 9.9% *more* total length.

Splitting only the ranks that are actually wide does not rescue it — the same `graph` ordering,
applied to ranks above a size threshold and left alone below it. The probe's third argument is
that threshold, so these rows are `RIG.start('TB', ['graph/floor', 'graph/ceil'], 20)`:

| candidate | W | H | total | median | longest | ranks |
|---|---|---|---|---|---|---|
| *baseline* | *19907* | *5203* | *1968230* | *1816* | *14669* | *26* |
| only ranks > 12 / `floor` | 21339 | 5667 | 2065640 | 2214 | 16615 | 28 |
| only ranks > 12 / `ceil` | 21432 | 5594 | 2216218 | 2507 | 18213 | 28 |
| only ranks > 20 / `floor` | 22364 | 5562 | 2181961 | 2550 | 19550 | 28 |
| only ranks > 20 / `ceil` | 20671 | 5362 | 2000256 | 2166 | 19326 | 27 |

That last row is the closest anything came anywhere on this lane — 1.6% more total length — and it
still pays 31.7% on the longest edge, which is the column the split exists to improve.

Nor does the orientation, in `rankdir LR`:

| candidate | W | H | total | median | longest | ranks |
|---|---|---|---|---|---|---|
| *baseline* | *6750* | *11443* | *1241574* | *1313* | *8578* | *26* |
| graph / `floor` | 9090 | 12927 | 1431997 | 1689 | 11085 | 35 |
| graph / `ceil` | 8310 | 13878 | 1534147 | 1827 | 14274 | 32 |
| graph / `alt` | 9090 | 11595 | 1398772 | 1795 | 10654 | 35 |

**Sixteen variants, three families, two orientations, and not one of them beats doing nothing.**

### What that settles

- **There is no stable rank-split rule.** #182 asked for one that reliably shortens edges. The
  mechanism takes 8% off one lane and adds 10% to the other, and the sign of its tie-break is not
  stable between two implementations of the same description. No rule can be stated, which is the
  outcome the ticket allowed for.
- **Selecting by measurement would be safe, and is still not worth it.** Score every candidate and
  keep the best, with the first layout's own result standing as a candidate, and the outcome can
  never be worse than the baseline: Angels would pick `graph/ceil`, Krastorio 2 would pick the
  baseline. But it costs **three layouts per `rankdir|deadShown` cache key instead of one**, on a
  wait #175 had to work to make visible rather than broken-looking, and on the second lane it buys
  exactly nothing. Not shipped.
- **A candidate cannot be scored more cheaply than by laying it out**, which #182 asked to check.
  dagre 0.8.5's whole public surface is `{ graphlib, layout, debug, util: { time, notime },
  version }` — checked against the cdnjs bundle the viewer loads. `rank`, `order` and `position`
  are internal, so there is no way to obtain a ranking, and therefore no rank-space score,
  without paying for the coordinate phase that is the expensive part.
- **The viewer is unchanged.** `scripts/tree-viewer.template.html` still runs one layout per cache
  key, and `scripts/tree-viewer.ps1` still asserts nothing and stays out of every check sweep.

The lever that was left unspent when this section was written is the one recorded in
`docs/research/dag-layout-algorithms.md`: `edgesep`, which the viewer never set. It is spent now —
the next section is what it bought and what it cost.

### A caveat on every timing here

A layout took between 2.9 and 12.8 seconds in this session, where #175 recorded 4459 ms for the same
Angels graph, and repeats of identical work on the same page varied by a factor of three. Read the
*ratio* between a candidate and its baseline; never the absolute.

## `edgesep`: the lever that took nothing back — shipped 2026-08-30 (#182)

Measured with `scripts/tree-layout-probe.js` on both lanes and both orientations, and **shipped at
`edgesep: 6`** — Truls's call, made by looking at the busiest rank gap rather than at the table.

dagre separates two **dummy** nodes by `edgesep` and two cards by `nodesep`, and its dummies carry
`width: 0`, so a dummy occupies gutter and nothing else. The viewer set `nodesep: 16` and never set
`edgesep`, leaving all 2346 of the Angels lane's dummies at dagre's default of **20** — wider apart
than the cards they thread between. It was missing from #171's sweep entirely.

| Angels, `rankdir TB` | W | H | total | median | longest |
|---|---|---|---|---|---|
| *`edgesep` 20 — the default, and what #171 shipped* | *33682* | *8424* | *6016714* | *4156* | *38501* |
| 10 | 31104 | 8424 | 5631778 | 3918 | 35981 |
| **6 — shipped** | **30127** | **8424** | **5486094** | **3819** | **35018** |
| 4 | 29639 | 8424 | 5413412 | 3749 | 34529 |
| 2 | 29150 | 8424 | 5340861 | 3693 | 34039 |

| Lane and orientation, 20 → 6 | W | H | total | longest |
|---|---|---|---|---|
| Angels, TB | 33682 → **30127** | 8424 → 8424 | −8.8% | −9.0% |
| Angels, LR | 10390 → 10390 | 22308 → **18431** | −13.6% | −13.1% |
| Krastorio 2, TB | 19907 → **18901** | 5203 → 5203 | −5.0% | −6.0% |
| Krastorio 2, LR | 6750 → 6750 | 11443 → **10390** | −8.1% | −10.2% |

Three things that table says:

- **It compresses one axis and leaves the other to the pixel.** Top-down the height is 8424 in every
  row; left-right the width is 10390 in every row. `edgesep` is purely a cross-rank quantity, so
  unlike the card width (#171) and unlike the rank split above, no trade is being made at all.
- **It holds on both lanes.** Krastorio 2 gains half what Angels does — 5% of width against 11% —
  but it gains in every column, in both orientations. That is exactly what the rank split could not
  do.
- **The returns flatten.** 6 → 4 is another 1.6% of width; 4 → 2 another 1.6% again.

### What it spends, and why 6 rather than 4

The gap between adjacent edge lanes, and only at the crowded end. Measured across all 39 rank gaps
of the Angels lane — 3253 adjacent pairs, against a 1.5px stroke:

| `edgesep` | tightest pair | 10th percentile | median | pairs under 3px |
|---|---|---|---|---|
| 20 | 0.7 | 20.0 | 103.0 | 8 |
| **6** | 0.2 | **6.0** | 96.0 | 28 |
| 4 | 0.1 | 4.0 | 95.0 | 30 |

The median barely moves, because the typical pair of lanes was never near the floor. **The 10th
percentile IS `edgesep`, exactly, at every value** — that is where the whole cost lands. At 6 two
neighbouring lines keep four stroke widths of paper between them; at 4 they keep under three, for
1.6% more width.

The pairs closer than a stroke width are a different thing and should not be read as lane spacing:
they are edges converging on a shared endpoint, and 8 of them exist at the default already. Those
touch somewhere along their length whatever this number is.

### The version it was measured against, and the move that followed

All of it is dagre **0.8.5**, which is what `scripts/tree-viewer.template.html` loaded from cdnjs and
[the only version cdnjs has](https://api.cdnjs.com/libraries?search=dagre) — its dagre list is
`0.8.5`, `dagre-d3 0.6.4`, `graphlib 4.0.5`, and the maintained `@dagrejs/dagre` is not on it at
all. Checked again 2026-08-30. Two neighbours were run against the same graph while the question was
open, because "would a newer dagre draw this better" is cheap to answer and otherwise gets guessed:

| dagre | how it loads | Angels TB at `edgesep 6` |
|---|---|---|
| **0.8.5** (cdnjs) | `<script src>`, sets `window.dagre` | 30127 x 8424, total 5486094, longest 35018 |
| `@dagrejs/dagre` **2.0.4** (jsdelivr) | **not** by `<script src>` — see below | 30127 x 8424, total 5486094, longest 35018 |
| `@dagrejs/dagre` **3.1.1** (jsdelivr) | `<script src>`, sets `window.dagre` | 30127 x 8424, total 5486094, longest 35018 |

**Identical, to the pixel and to the last unit of edge length.** Eight years and three major versions
change nothing about how this graph is drawn, so there is no layout argument for moving.

**And 2.0.x cannot be loaded the way the viewer loads a library.** Its `dist/dagre.min.js` is
30 KB against 0.8.5's 284 KB because it externalises `@dagrejs/graphlib` rather than bundling it;
loaded from a `<script>` tag it throws `Error: Dynamic require of "@dagrejs/graphlib" is not
supported` before defining anything, and what a reader sees is the viewer's own "a library did not
load" fallback with no clue why — which is what that message was rewritten to name. Reaching 2.0.4
at all meant
`import('https://cdn.jsdelivr.net/npm/@dagrejs/dagre@2.0.4/+esm')`, which is jsdelivr bundling the
dependency in on the fly — a module import, where the viewer's startup is a synchronous global.

### Shipped: `@dagrejs/dagre` 3.1.1 from jsdelivr — Truls's call, 2026-08-30

3.1.1's bundle is self-contained again, so the move is one URL: the call shape
(`dagre.graphlib.Graph`, `setNode`, `setEdge`, `dagre.layout`, `g.node().x,y`, `g.edge().points`)
is unchanged across all three versions and no viewer code changed with it. What it costs is leaving
cdnjs for dagre — #161's convention, reopened deliberately rather than drifted out of. d3 stays on
cdnjs, so the viewer now loads from two hosts and its failure message names which one is missing.

Verified on both lanes and both orientations, by splicing the updated template over each lane's real
dataset:

| on 3.1.1 | W | H | total | median | longest |
|---|---|---|---|---|---|
| Angels TB | 30127 | 8424 | 5486094 | 3819 | 35018 |
| Angels LR | 10390 | 18431 | 3643990 | 2750 | 25286 |
| Krastorio 2 TB | 18901 | 5203 | 1870281 | 1763 | 13782 |
| Krastorio 2 LR | 6750 | 10390 | 1140995 | 1287 | 7706 |

Every figure equals 0.8.5's. **The drawing did not change at all.**

One thing did: it is **faster**. Both libraries were loaded into the same page — 0.8.5 evaluated
into a private module object so it could not clobber the global — and the Angels TB layout run
alternately: 0.8.5 at 3822, 3479, 3289 ms against 3.1.1 at 2283, 2218, 3093, 2839 ms. Roughly a
quarter off, and the two sets do not quite separate, so read it as "faster" and not as a factor.
Absolute numbers on this machine ran 3x higher earlier in the same session under load, which is why
the comparison is alternated on one page rather than taken across runs.

**What it does not buy:** 3.1's own new features are per-cluster `rankdir`/`ranksep`/`nodesep` and
dynamic-layout options, and this viewer uses no clusters. The reason to move is that the package
can still receive a fix and cdnjs's copy never will.

**A caveat on the changelog**, since it is the obvious thing to reach for: it lists no breaking
change touching any of this, but it reads as partly generated — it cites "semandtic-versioning.org"
— and it is not a migration guide. The identical-output result above is measurement, not changelog.

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
