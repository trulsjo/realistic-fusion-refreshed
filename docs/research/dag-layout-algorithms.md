# What the layout literature and the reachable libraries offer a 4:1 technology DAG

Read 2026-08-30 for [#182](https://github.com/trulsjo/realistic-fusion-refreshed/issues/182),
against **dagre 0.8.5** as `scripts/tree-viewer.template.html` loads it from cdnjs, **d3 7.9.0**,
and the Factorio modding API pinned at **2.0.77**. **Facts only.** The decision this feeds — whether
#182's rank split is replaced, kept and stabilised, or dropped for a different mechanism, and
whether the viewer's library set changes at all — is Truls's and is recorded on the ticket, not
here.

Every number attributed to *the levers note* comes from `docs/research/tree-layout-levers.md` (#171)
or from #182's own brief. Nothing in this note was measured by running a layout; it is reading.

## The question

Truls's question on #182 is why the canvas is four times wider than tall when the widest rank holds
only 41 cards, and whether the fix is a better rank split or something else entirely. Restated for
the literature: **what does a layered drawing algorithm actually optimise, does any of it optimise
width or aspect ratio, and which of the answers can a self-contained HTML page reach?**

The measured situation, from the levers note and #182's brief and not re-derived here: 406 live
technologies, 946 edges, 40 ranks, canvas 33682 x 8424 at the 170px card #171 shipped; the widest
rank holds 41 cards; the 946 edges become **2346 dummy nodes**; one rank is crossed by 137 edges;
rank 25 holds 16 cards spread across 30712px. The levers note's conclusion was that card width is
the only knob that moves canvas width at all, and that `ranksep` does not move it by a single pixel.

## 1. The four phases, and which one is producing the width

The framework is [Sugiyama, Tagawa & Toda, "Methods for Visual Understanding of Hierarchical System
Structures", *IEEE TSMC* 11(2):109–125, 1981](https://doi.org/10.1109/TSMC.1981.4308636). The
canonical modern statement of the phases is the `dot` paper — [Gansner, Koutsofios, North & Vo, "A
Technique for Drawing Directed Graphs", *IEEE TSE* 19(3):214–230,
1993](https://doi.org/10.1109/32.221135), full text at
<https://www.graphviz.org/documentation/TSE93.pdf> — which names cycle removal, layering, crossing
reduction (its §3, "Vertex Ordering Within Ranks") and node coordinates (its §4).

`dot` §3 is where the dummy nodes appear, and the paper is explicit that they are a device of the
*ordering* phase, not of the drawing: *"After rank assignment, edges between nodes more than one
rank apart are replaced by chains of unit length edges between temporary or 'virtual' nodes."*

dagre implements the same pipeline, in one visible list. `lib/layout.js` at v0.8.5 runs, in order,
`acyclic.run`, `rank`, `normalize.run`, `order`, `position`, `normalize.undo`
([source](https://github.com/dagrejs/dagre/blob/v0.8.5/lib/layout.js)) — cycle removal, layering,
dummy insertion, ordering, coordinates. `lib/rank/index.js` says so in its own comment: *"This basic
structure is derived from Gansner, et al., 'A Technique for Drawing Directed Graphs.'"*
([source](https://github.com/dagrejs/dagre/blob/v0.8.5/lib/rank/index.js)). It offers three rankers
— `network-simplex` (the default), `tight-tree`, `longest-path` — and nothing else.

**The width is produced in phase four, out of material phase two committed to.** The primary source
that states the tension plainly is [Jünger, Mutzel & Spisla, "A Flow Formulation for Horizontal
Coordinate Assignment with Prescribed Width", GD 2018,
arXiv:1806.06617](https://arxiv.org/abs/1806.06617). Its Fig. 1 caption is the whole problem in one
sentence: *"In the left picture the horizontal edge length is k−3 and the width is 1, in the right
picture the horizontal edge length is 0 and the width is k−2, where k is the number of layers."*
Short edges and a narrow drawing are opposing objectives, and the phase that assigns x-coordinates
is aimed at the first. The same paper says why counting cards per rank does not predict the canvas:
*"the maximum number of nodes in one layer does not necessarily define the actual width of the final
drawing"*, and *"The main objective of most methods for the coordinate assignment phase is 'short
edges', which often leads to small drawings, but the width of the final layout is not directly
addressed."* That is a published statement of exactly what the levers note measured — 41 cards on
the widest rank, 33682px of canvas.

dagre's coordinate phase is [Brandes & Köpf, "Fast and Simple Horizontal Coordinate Assignment", GD
2001, LNCS 2265:31–44](https://doi.org/10.1007/3-540-45848-4_3), and dagre's `lib/position/bk.js` is
named for it. Two facts about it matter here:

- **It has no objective function.** It is four extreme alignments (up/down x left/right), each
  compacted, then averaged; `positionX` runs all four and `findSmallestWidthAlignment` /
  `balance` combine them
  ([source](https://github.com/dagrejs/dagre/blob/v0.8.5/lib/position/bk.js)). There is no total
  edge length being minimised and no width being bounded. The levers note's finding that forcing
  `align: 'UL'` nearly doubles the longest edge, and that dagre's four-way average beats every
  single alignment, is that design showing through.
- **dagre does not implement BK's compaction.** Its own source comment says so: *"This portion of
  the algorithm differs from BK due to a number of problems. Instead of their algorithm we construct
  a new block graph and do two sweeps."* The problems are real and now documented — [Brandes, Walter
  & Zink, "Erratum: Fast and Simple Horizontal Coordinate Assignment", arXiv:2008.01252
  (2020)](https://arxiv.org/abs/2008.01252) identifies two flaws in the compaction step, one
  ("double shifting") long known, one ("shift accumulation") *"a serious flaw that has not been
  documented before"*. Whether dagre's substitute is equivalent to the erratum's correction is not
  something this note establishes; what it establishes is that dagre's compaction is dagre's, not
  the paper's, and reasoning about the viewer from the 2002 paper alone is unsafe.

## 2. Is the dummy explosion inherent? No — it is a property of the layering

The `dot` paper treats virtual nodes as unavoidable once ranks are fixed, and spends its effort on
making them cheap rather than on making them fewer. But the layering that fixes them is itself a
choice, and there is a documented line of work on choosing it to produce fewer.

- **Node promotion.** ELK ships it as a post-processing pass on layer assignment, and its source
  states the goal in one line: *"The goal of the node promotion is to achieve a layering with less
  dummy nodes. For this purpose the original graph nodes are promoted recursively and the promotion
  is applied, if and only if this reduces the determined count of dummy nodes."*
  ([`NodePromotion.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/intermediate/NodePromotion.java)).
  It cites [Nikolov, Tarassov & Branke, "In search for efficient heuristics for minimum-width graph
  layering with consideration of dummy nodes", *ACM JEA* 10, Article 2.7,
  2005](https://doi.org/10.1145/1064546.1180618).
- **Width-bounded layering.** The same paper's MinWidth heuristic is ELK's `MIN_WIDTH` layering
  strategy, described in its enum as *"Implementation of the 'MinWidth' heuristic for solving the
  NP-hard minimum-width layering problem with consideration of dummy nodes"*
  ([`LayeringStrategy.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/LayeringStrategy.java)).
  ELK's implementation notes it *"differs from the one described in the paper as it considers the
  actual size of the nodes"*, including *"estimating the sizes of dummy nodes by taking the edge
  spacing of the LGraph into account"*
  ([`MinWidthLayerer.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p2layers/MinWidthLayerer.java)).
- **Coffman–Graham.** ELK's `COFFMAN_GRAHAM` strategy *"Allows to restrict the number of original
  nodes in any layer"* (same enum file), bounded by
  `org.eclipse.elk.layered.layering.coffmanGraham.layerBound`. This is #182's "use more ranks so each
  holds fewer cards" as a layering constraint rather than as scaffolding edges added between a
  second layout run — no pairing rule, so no `floor`/`ceil` coin. The underlying result is
  [Coffman & Graham, "Optimal scheduling for two-processor systems", *Acta Informatica*
  1(3):200–213, 1972](https://doi.org/10.1007/BF00288685).
- **Layering that costs dummy nodes explicitly.** [Healy & Nikolov, "A Branch-and-Cut Approach to
  the Directed Acyclic Graph Layering Problem", GD 2002, LNCS
  2528:98–109](https://doi.org/10.1007/3-540-36151-0_10) and [Jabrayilov, Mallach, Mutzel, Rüegg &
  von Hanxleden, "Compact Layered Drawings of General Directed Graphs", GD 2016, LNCS
  9801:209–221](https://doi.org/10.1007/978-3-319-50106-2_17) both treat the number of dummy nodes
  as part of the layering objective; the flow paper above cites them for exactly that (its refs 8
  and 10). These are exact methods, not heuristics — cited here as evidence that the objective is
  formulable, not as something to run in a browser.

**dagre has none of these.** Its ranker list is the three above; there is no node promotion, no
width bound, no Coffman–Graham. So the answer to "is the dummy explosion inherent" is: the *chains*
are inherent to a proper layering, their *number* is not, and dagre offers no lever on it.

## 3. What `dot` does differently from dagre

Three differences, all primary-sourced, all bearing on horizontal room.

**`dot` weights virtual-node edges eight times harder than real ones.** Its x-coordinate objective
is `min Σ Ω(e) ω(e) |x_w − x_v|`, and the paper explains Ω: *"Since edges between real nodes in
adjacent ranks can always be drawn as straight lines, it is more important to reduce the horizontal
distance between virtual nodes, so chains may be aligned vertically and thus straightened."* Edges
are typed real–real, real–virtual, virtual–virtual, with *"Ω(e) ≤ Ω(f) ≤ Ω(g). Our implementation
uses 1, 2, and 8."* (`dot` §4). dagre's Brandes–Köpf phase has no Ω and no objective at all — the
*only* place a dummy is distinguished from a card in dagre's coordinate phase is the separation
function.

**`dot` solves that objective optimally; dagre approximates.** `dot` §4.2 builds an auxiliary graph
and runs network simplex on it, *"using the X coordinates as 'ranks'"*, after §4.1's heuristic sweep
proved too fiddly (*"the heuristics begin to interfere with each other"*). dagre runs network
simplex only in the *ranking* phase.

**dagre already separates dummies more tightly than `dot` does — and the viewer never sets the
knob.** `dot`'s separation is uniform: *"ρ(a,b) = (xsize(a)+xsize(b))/2 + nodesep(G)"* (§4), one
`nodesep` for every adjacent pair. dagre splits it, in `lib/position/bk.js`:

```js
sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
sum += (wLabel.dummy ? edgeSep : nodeSep) / 2;
```

and its dummies carry `width: 0, height: 0`
([`lib/normalize.js`](https://github.com/dagrejs/dagre/blob/v0.8.5/lib/normalize.js)). So a dummy
occupies no card width, only gutter — and that gutter is **`edgesep`, whose default is 20**
(`graphDefaults = { ranksep: 50, edgesep: 20, nodesep: 50, rankdir: "tb" }` in
[`lib/layout.js`](https://github.com/dagrejs/dagre/blob/v0.8.5/lib/layout.js)). The viewer sets
`{ rankdir, nodesep: 16, ranksep: 90, marginx: 40, marginy: 40 }` and never sets `edgesep`, so
every one of the 2346 dummies is separated by dagre's default 20px while the cards are at 16.
**`edgesep` does not appear anywhere in the levers note's sweep.** It is the one dagre knob that
touches only edge routing, which is where the levers note concluded the width lives.

Honest arithmetic against that hope, so nobody is surprised: 137 crossings at 20px is 2740px, and
2346 dummies spread over 40 ranks average about 59 a rank, or ~1170px of gutter. Against a canvas of
33682px and a rank-25 span of 30712px, `edgesep` cannot be the whole story — the rest is the block
alignment propagating x-coordinates across ranks.

**Measured afterwards, since it was cheap.** This note otherwise reads rather than runs, but the
prediction above was testable in one browser session, on the same 406 live technologies and 946
edges as the levers note, at the shipped 170px card:

| `edgesep` | W | H | total | median | longest |
|---|---|---|---|---|---|
| **20** — dagre's default, and what the viewer gets today | 33682 | 8424 | 6016714 | 4156 | 38501 |
| 10 | 31104 | 8424 | 5631778 | 3918 | 35981 |
| 4 | 29639 | 8424 | 5413412 | 3749 | 34529 |
| 2 | 29150 | 8424 | 5340861 | 3693 | 34039 |

The arithmetic was right that it is not the whole story, and wrong that it is not a win. From 20 to
4 the canvas loses **12% of its width, total edge length 10%, and the longest edge 10%** — and
**the height does not move at all**, at 8424 in every row, because `edgesep` is a purely horizontal
quantity. That makes it the only lever measured anywhere in these two notes that costs nothing:
card width traded legibility, splitting ranks traded 25% more height and was unstable, and `ranksep`
bought nothing. Returns flatten below 4 — 4 to 2 is another 1.6%.

What it spends instead is the gap between adjacent edge lanes, which no number here captures.
Edges draw at 1.5px, so at `edgesep: 4` two neighbouring lanes are 4px apart and at 2 they nearly
touch. Whether a rank carrying 137 crossings still reads at that spacing is a judgement to be made
by looking at it, not from this table.

**Also note `dot`'s own trick that dagre copies.** dagre's `makeSpaceForEdgeLabels` comment reads
*"we split each rank in half by doubling minlen and halving ranksep"*, which is `dot` §6's
edge-label handling — *"doubling the ranks when virtual nodes are created ... and halving the
separation between ranks"*. That is #171's measured finding stated by both implementations: doubling
`minlen` is `ranksep` under another name, and buys no width.

## 4. What is reachable from the viewer's page

The template's own comment is the constraint: *"The dagre and d3 libraries come from cdnjs by
deliberate choice (#161): this is a dev-side instrument, and the prototype's variant A proved an
offline hand-rolled fallback is possible if that trade-off is ever revisited."* That is a
convention, not a technical limit — the viewer is a local file, not a sandboxed page — so anything
below marked "jsdelivr only" is a decision about #161's trade-off, not an impossibility.

**cdnjs, checked directly against `api.cdnjs.com` on 2026-08-30.** Searching `dagre` returns exactly
`dagre 0.8.5`, `dagre-d3 0.6.4`, `graphlib 4.0.5`. `dagre`'s version list ends at 0.8.5 — **the
maintained `@dagrejs/dagre` (3.1.x) is not on cdnjs at all**, so the viewer is pinned to a 0.8.5
that cdnjs will never move. `elkjs`: 404. `d3-dag`: 404. `@hpcc-js/wasm`: no match. `webcola`: no
match. Present: `viz.js 2.1.2`, `cytoscape 3.34.2`, `vis-network 10.1.2`, `d3-graphviz 5.6.0`.

### ELK / elkjs

ELK's `layered` is the same Sugiyama pipeline ([algorithm
reference](https://eclipse.dev/elk/reference/algorithms/org-eclipse-elk-layered.html)), but it
exposes each phase as a strategy rather than fixing it. Node placement
(`org.eclipse.elk.layered.nodePlacement.strategy`, default `BRANDES_KOEPF`) offers `SIMPLE`,
`INTERACTIVE`, `LINEAR_SEGMENTS`, `BRANDES_KOEPF`, `NETWORK_SIMPLEX`; the enum's own javadoc
describes `NETWORK_SIMPLEX` as *"Using an auxiliary graph and the NetworkSimplex algorithm to
calculate a balanced placement with straight long edges"* — i.e. `dot`'s §4.2 available as an option
([`NodePlacementStrategy.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/NodePlacementStrategy.java)).
Layering strategies are the nine listed in §2 above. Edge routing is
`POLYLINE`/`ORTHOGONAL`/`SPLINES`
([`org.eclipse.elk.edgeRouting`](https://eclipse.dev/elk/reference/options/org-eclipse-elk-edgeRouting.html)).

**Aspect ratio is a first-class option**: `org.eclipse.elk.aspectRatio`, *"The desired aspect ratio
of the drawing, that is the quotient of width by height"*
([reference](https://eclipse.dev/elk/reference/options/org-eclipse-elk-aspectRatio.html)), default
`1.6` for `layered`. What consumes it in `layered` is **graph wrapping**,
`org.eclipse.elk.layered.wrapping.strategy` (default `OFF`): *"Specifies the desired strategy to
wrap graphs in order to improve their presentation within a drawing area of a certain aspect ratio.
I.e. the graph is split into several chunks to better utilize the given area."* `SINGLE_EDGE` allows
one backward-wrapping edge per cut, `MULTI_EDGE` allows several
([`WrappingStrategy.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/WrappingStrategy.java)).
`wrapping.correctionFactor` is documented as *"simply multiplied with the 'aspect ratio' layout
option"*, which is the explicit link between the two. The primary source is [Rüegg & von Hanxleden,
"Wrapping Layered Graphs", Diagrams 2018, LNCS
10871:743–747](https://doi.org/10.1007/978-3-319-91376-6_72), and the fuller treatment is Rüegg's
thesis, *Sugiyama Layouts for Prescribed Drawing Areas*, Kiel Computer Science Series 2018/1
(<https://macau.uni-kiel.de/receive/diss_mods_00023761>). ELK's overview paper cites both ([Domrös
et al., "The Eclipse Layout Kernel", arXiv:2311.00533](https://arxiv.org/abs/2311.00533), refs 38
and 40).

**But read what wrapping is for before hoping for it.** ELK's own implementation states the target
shape: *"Calculates cut points and inserts breaking points into the calculated layering. The goal is
to improve very wide and narrow drawings, i.e. many layers but few nodes per layer."*
([`BreakingPointInserter.java`](https://github.com/eclipse-elk/elk/blob/master/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/intermediate/wrapping/BreakingPointInserter.java)).
The viewer's pathology is the opposite one: **few ranks (40), enormous span within a rank.**
Wrapping cuts the *layer sequence* into chunks; it does not narrow a layer. Applied to this graph it
would serpentine the 40 ranks into a few blocks and make the drawing wider still. The options that
address the viewer's shape are ELK's layering ones — `MIN_WIDTH`, `COFFMAN_GRAHAM`, node promotion —
not the wrapping ones.

`elkjs` (<https://github.com/kieler/elkjs>) is ELK's layout core GWT-transpiled to JavaScript. It
runs without a Worker (`new ELK()` with no `workerUrl`), and `elk.layout(graph, options)` returns a
Promise — **async, where dagre is synchronous**, which is a change to the viewer's layout path and
its #175 cache, not a swap of one call for another. Latest published is **0.12.0**; `elk.bundled.js`
is **1,609,707 bytes** (~1.6 MB), against dagre 0.8.5's minified bundle. Not on cdnjs; on jsdelivr
at `cdn.jsdelivr.net/npm/elkjs@0.12.0/lib/elk.bundled.js`. No ELK-published benchmark for a graph of
this size was found; the largest failure reported on its tracker is a stack overflow at ~181,000
elements ([elk#472](https://github.com/eclipse-elk/elk/issues/472)), two orders of magnitude above
406/946.

### Graphviz `dot` in the browser

Three distinct things, and only the oldest is on cdnjs.

| build | version | Graphviz | shape | cdnjs |
|---|---|---|---|---|
| `viz.js` (mdaines, v2 line) | 2.1.2 | **2.40.1** | `viz.js` 11 KB + `full.render.js` **1.98 MB** | **yes** |
| `@viz-js/viz` (same author, v3 line) | 3.29.0 | 15.1.1 | one self-contained file, ~1.19 MB ESM / 1.33 MB global | no |
| `@hpcc-js/wasm-graphviz` | 1.28.0 | 16.0.0 | ESM only, `dist/index.js` ~821 KB | no |

Both modern builds embed the WASM as inline base64 rather than fetching a `.wasm` alongside, so each
is a single script. The cdnjs copy is the 2018-era asm.js build carrying Graphviz **2.40.1** — eight
years and several major versions behind, and split across two files where the render script is 2 MB.
Its API is worker-oriented; a non-worker path exists but was not verified here.

Taking any of these means `dot`'s §4.2 network-simplex coordinate phase, its Ω = 1/2/8 virtual-node
weighting, and `ratio` — which is Graphviz's own aspect-ratio attribute, and which is *scaling*, not
re-layout, except for `ratio=compress`: *"dot attempts to compress the initial layout to fit in the
given size. This achieves a tighter packing of nodes but reduces the balance and symmetry"*
(<https://graphviz.org/docs/attrs/ratio/>). It also means text in, SVG out, and a rewrite of how the
viewer gets coordinates back — the current code reads `g.node(id).x/y` and `g.edge(e).points`.

### d3-dag

<https://github.com/erikbrinkman/d3-dag>, latest **1.2.2**, **not on cdnjs**. Layering operators in
v1 are `longest-path`, `simplex`, `topological` — Coffman–Graham is not among them. Coordinate
operators are `center`, `greedy`, `quad`, `simplex`. `coordSimplex`'s own doc comment says it
*"mirrors that of Gansner, Emden R., et al."*, i.e. the `dot` objective; `coordQuad` *"positions
nodes to minimize a quadratic optimization"* with per-link weights (`vertWeak`, `vertStrong`,
`linkCurve`, `nodeCurve`). Both are **edge-length / straightness objectives. There is no
aspect-ratio or width objective anywhere in d3-dag's README, changelog or operator sources.** It
ships a dagre-compatible shim (`import { dagre } from "d3-dag"`), and its README publishes timings
on a 184-node graph: 5.1 ms "fast", 49 ms "medium", "small graphs only" for the optimal-decrossing
"slow" preset. Its `decrossOpt` doc warns it *"brute forces an NP-Complete problem ... any graph
that is probably too large will throw an error instead of running."*

### The rest, briefly

- **`@dagrejs/dagre` 3.1.x** — the maintained fork. Its changelog records a TypeScript rewrite (3.0.0)
  and per-cluster `rankdir`/`ranksep`/`nodesep`/`align` (3.1.0)
  ([changelog](https://github.com/dagrejs/dagre/blob/master/changelog.md)); its wiki still cites
  Gansner et al. and Brandes–Köpf, so the algorithm is the same in kind. No aspect-ratio option.
  jsdelivr only.
- **cytoscape.js 3.34.2** is on cdnjs, but its layered layouts are wrappers — `cytoscape-dagre`,
  `cytoscape-elk` — and neither wrapper is on cdnjs. Any aspect-ratio control comes from the wrapped
  engine, not from cytoscape.
- **vis-network 10.1.2** is on cdnjs. Its hierarchical layout is not Sugiyama: its docs state the
  option *"overrules some of the other options. The physics is set to the hierarchical repulsion
  solver"*, with `sortMethod` `hubsize` or `directed`
  (<https://visjs.github.io/vis-network/docs/network/layout.html>). No aspect-ratio control, and
  swapping a deterministic layered layout for a physics solver is a different instrument.
- **WebCola 3.4.0** has a DAG-aware `flowLayout(axis, minSeparation)` — *"causes constraints to be
  generated such that directed graphs are laid out either from left-to-right or top-to-bottom"*
  (`src/layout.ts`) — and ideal-edge-length terms, but no aspect-ratio objective, and it is not on
  cdnjs. No paper citation was found in its README, wiki, homepage or source headers; that is a gap,
  not a claim that none exists.

## 5. How Factorio draws its own tree

**Nothing in the prototype data positions a technology.** Checked at 2.0.77:
[`TechnologyPrototype`](https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html)
carries `order`, the generic sort key *"Used to order prototypes in inventory, recipes and GUIs"*,
shared with every other prototype type — no row, column, x, y or tier.
[`LuaTechnologyPrototype`](https://lua-api.factorio.com/2.0.77/classes/LuaTechnologyPrototype.html)
adds nothing positional either: `prerequisites`, `successors`, `level`/`max_level` (the research
level, not a rank), and `essential`, *"Whether the technology should be shown in the technology tree
GUI when 'Show only essential technologies' is enabled"* — a filter, not a coordinate. No API
exposes the GUI's computed positions. So the layout is computed at render time from the prerequisite
graph.

**No Friday Facts describes the algorithm.** FFF-238 ("The GUI update (Part II)", 2018-04-13,
<https://factorio.com/blog/post/fff-238>) covers the tech tree GUI's restyling — the queue, the
colour states, where the featured-technology frame sits — and says nothing about placement. FFF-187
and FFF-376 show the tree without describing how it is laid out. **This is a documented absence**:
no Wube post naming ranks, layering or crossing minimisation was found.

The closest primary technical statement is a 2017 forum thread
(<https://forums.factorio.com/viewtopic.php?t=42980>) — weaker evidence than an FFF, and flagged as
such. **posila** (2017-03-20): *"Tech tree in Factorio is hard to layout. Technically we have (and
Civilization has) oriented graph, not tree, and our graph is not planar (which means it can't be
drawn on a piece of paper without some connections crossing)."* **Oxyd** (2017-03-22), on a modified
build: *"Notice how an individual technology's tree can spread really wide"*, and on cost, *"doing
the entirety of Bob's mods took a few seconds already"* — with the shipped answer being to bound the
problem: *"By limiting the size of the displayed portion of the tree, we can also limit how long it
will take for the tree to render."*

**The finding Truls's flag anticipated**: Factorio's own response to an arbitrary modded technology
graph was to stop drawing all of it, not to lay all of it out well. That is a real option — it is
§6's focus+context, arrived at by a shipping team under the same constraint — but it is not a model
for a better global layout, because Wube did not build one.

## 6. Approaches that attack it from somewhere else

- **Edge bundling on a layered drawing.** [Pupyrev, Nachmanson & Kaufmann, "Improving Layered Graph
  Layouts with Edge Bundling", GD 2010, LNCS
  6502:329–340](https://doi.org/10.1007/978-3-642-18469-7_30) modifies a Sugiyama drawing by bundling
  edges, with bundles chosen by minimising the total *ink* needed to draw the edges. It reduces
  visual clutter along routes that already exist; this note found no claim that it narrows the
  drawing, and the viewer's problem is width, so treat it as a legibility lever rather than an
  aspect-ratio one. No browser implementation was checked.
- **Orthogonal routing.** ELK's `edgeRouting: ORTHOGONAL` is `layered`'s default and is one option
  string; dagre has no routing phase at all — it returns the dummy chain's points and the viewer
  draws through them. This changes how an edge looks between ranks, not how much room its chain
  reserves.
- **Packing weakly-connected components.** Graphviz `pack` lays *"each connected component of the
  graph ... out separately, and then the graphs packed together"* (<https://graphviz.org/docs/attrs/pack/>),
  with the packing method set by `packmode`; the primary algorithm is [Freivalds, Dogrusoz & Kikusts,
  "Disconnected Graph Layout and the Polyomino Packing Approach", GD 2001, LNCS
  2265:378–391](https://doi.org/10.1007/3-540-45848-4_30). ELK has the equivalent as
  `separateConnectedComponents` and `compaction.connectedComponents`. **Whether this helps here is
  unknown and cheap to find out**: a Factorio technology tree from one mod set is probably close to
  one component (everything descends from automation), in which case packing has nothing to pack —
  but the viewer's own note records that hiding technologies *"loses its in-edge"* and strands cards,
  so the component count after #168's filter is a fact worth measuring before the idea is dismissed.
- **Focus+context, and expanding on demand.** [Furnas, "Generalized fisheye views", CHI
  1986:16–23](https://doi.org/10.1145/22627.22342) is the original degree-of-interest formulation;
  [van Ham & Perer, "'Search, Show Context, Expand on Demand': Supporting Large Graph Exploration
  with Degree-of-Interest", *IEEE TVCG* 15(6):953–960,
  2009](https://doi.org/10.1109/TVCG.2009.108) is the modern statement, and is what Wube's 2017
  answer amounts to in practice. This sidesteps global layout entirely rather than improving it,
  which makes it a different instrument from the one #161 designed — worth knowing exists, not
  obviously in scope for #182.
- **Prescribing the width outright.** The Jünger/Mutzel/Spisla flow formulation of §1 does exactly
  what #182 wants — *"we can fix the maximum width of the final drawing"* while minimising total
  horizontal edge length — and reports it *"can compete with state-of-the-art algorithms"*. There is
  no JavaScript implementation of it that this note found, on cdnjs or anywhere.

## What this note does not settle

- **It measured almost nothing.** Every dagre number here is quoted from #171's note or #182's
  brief, with one exception: the `edgesep` table in §3 was run, because the reading predicted
  something cheap enough to test. Everything else about ELK, `dot`, d3-dag and Factorio is reading.
- **Whether any of §2's layering strategies actually narrows *this* graph** is unknown. `MIN_WIDTH`
  and `COFFMAN_GRAHAM` are documented to bound layer width; nothing here says what they do to the
  Angels lane's canvas, and reaching them means reaching ELK.
- **Whether ELK's async API can live behind #175's cache** was not examined.
- **No approach here is clearly better than tuning dagre**, and the sources do not support saying one
  is. What they do support: dagre's coordinate phase optimises nothing, its layering phase has no
  width lever, and both of those are choices other implementations make differently.
