# Does a fluid energy source honour a connection category?

Evidence for [#82](https://github.com/trulsjo/realistic-fusion-refreshed/issues/82), which blocks
the implementation of the decision taken on
[#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44). **Nothing here chooses a
design** — #44 chose it. Every line is a measurement, and the negatives are stated as plainly as the
positives.

Measured against **Factorio 2.0.77** by `scripts/probe-energy-containment.ps1`. The script is
committed rather than the numbers alone, because these are facts about a version of the engine and
the next version is entitled to different ones. Re-run it before quoting any figure here against a
newer build.

> **THE DECISION THIS UNBLOCKED IS NOW IN THE TREE (2026-09-07).**
> [#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) and
> [#87](https://github.com/trulsjo/realistic-fusion-refreshed/issues/87) shipped ADR 0018's item 1,
> so the field this probe asked about is set on the real machines rather than on rig copies of them:
> twenty-four connections carry a category and `scripts/check-containment.ps1` is the gate. The
> probe still runs and still measures its own variants -- that is what a probe is for, and its
> "prototype read" line now prints the shipped categories beside them -- but the load-bearing
> question it existed to answer is closed and asserted elsewhere. **AC 5 is what took the ordinary
> exchanger's geometry off #86's critical path**, and #86 shipped `rf-hc-exchanger` contained on the
> one plain-`"input"` connection it already had, exactly as that row predicted.

**Re-measured 2026-09-06 for [#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111).**
The rig had stopped running: [#45](https://github.com/trulsjo/realistic-fusion-refreshed/issues/45)
changed `rf-heat-exchanger` from 3×2 to 5×15 and the chain row still built the 3×2, so its second
machine sat inside its first and map creation failed. Every number on this page is from the rebuilt
rig on the current tree, and the answers are unchanged. What is new is a **control on the chain row**
— see AC 3 — without which the row could not be told apart from the rig filling every box it could
reach. That gap is why this page and
[`exchanger-chaining.md`](exchanger-chaining.md) disagreed for two weeks.

## The answer in one line

**Yes, to all four questions, and with no caveat about the mechanism.** A `connection_category`
declared on a fluid energy source's nested `fluid_box` reaches the engine and is enforced: an
ordinary pipe is refused, a pipe sharing the category joins and delivers, a categorised exchanger
bolts straight onto a reactor's output box with no pipe between them, and two such exchangers chain
through `input-output` connections with fuel crossing to the second. `rf-hc-exchanger`'s shape
answers the same. **#44 is not void, and it needs no new entity to build.**

## Why the question existed

#44 chose to give the two energy fluids a `connection_category` of their own and to ship **no pipe**
that carries either, so a heat exchanger bolts onto a reactor face and chains to its neighbour. That
is the shape the engine's own Space Age fusion uses: every `fusion-plasma` connection on both
`fusion-reactor` and `fusion-generator` carries `connection_category = {"fusion-plasma"}`, and **no
pipe a player can build carries it.**

The one prototype that does is worth stating, because this rig depends on the same trick:
`space-age/base-data-updates.lua:237-239` patches `infinity-pipe` to
`connection_category = {"default", "fusion-plasma"}`. Wube categorised the editor's debug pipe so it
could feed a fluid nothing buildable can carry — which is precisely what
`rf-probe-energy-feed` below is for.

The aneutronic half of that design needed no probing. `scripts/check-aneutronic.ps1` already builds a
`converter` through `bolt()` so that its own south connection lands on the tile the reactor's output
points at, and a `second_converter` five tiles behind it — direct-bolt and chaining, shipped and
gated, **for a generator's own fluid box**.

`rf-heat-exchanger` is not that. Its intake is a fluid energy source —
`energy_source = { type = "fluid", burns_fluid = true, fluid_box = { ... } }` — a fluid box nested
inside an energy source rather than declared on the entity. `contain()` in `prototypes/entities.lua`
sets `connection_category` on `pipe_connections`, and nothing established that the engine reads that
field in that position. A negative would have been decisive: the reactor's output would be
categorised and the exchanger's intake left `default`, so **nothing would connect at all** — no pipe,
no bolt, no build — and a boiler's fuel cannot arrive any other way.

**The failure mode is specific and had already happened twice.** [#23](https://github.com/trulsjo/realistic-fusion-refreshed/issues/23)
chose a crafting machine for the reactor: it loaded perfectly and moved no fluid at all.
[#43](https://github.com/trulsjo/realistic-fusion-refreshed/issues/43) put a `heat_buffer` on a
boiler: accepted by the data stage, dropped by the engine. A field the data stage takes and the
engine ignores is this project's characteristic bug, and it is the only reason this probe existed
rather than the implementation.

## What was built

`scripts/probe-energy-containment.ps1` builds ten rows on one headless map. Every subject is a
deepcopy of a **shipped** prototype with the field under test added and nothing else changed — not of
a vanilla one, because the question is whether the category reaches the engine on the boxes this mod
actually declares.

| row | what it is |
|---|---|
| `control` | The **shipped** `rf-heat-exchanger`, untouched, with an ordinary infinity pipe on the tile its energy connection points at |
| `str/refuse`, `str/accept` | The same exchanger with the category as a **bare string** — the form `contain()` already uses — offered an ordinary pipe, then a categorised one |
| `list/refuse`, `list/accept` | The same pair with the category as a **one-element list**, the form Space Age writes |
| `hc/refuse`, `hc/accept` | The same pair on `rf-hc-exchanger`'s shape, which has the same energy source on a seven-tile footprint |
| `bolt` | A categorised `rf-reactor` whose `output_fluid_box` carries the category, with a categorised exchanger placed so its own south energy connection lands face to face with it — **no pipe between them** |
| `chain` | The `bolt` row with a second categorised exchanger fifteen tiles north, joined through energy connections on their south and north short ends |
| `chain/control` | A third one of the same prototype, same plumbing, **joined to nothing**. It must hold nothing, or the `chain` row is the rig filling everything it can reach |

Three of those rows are instrumentation rather than findings, and all three are load-bearing:

- **`control` is the calibration.** It uses the shipped exchanger and an ordinary pipe, which is what
  the mod does today, so it must read `joins=YES` and carry fuel. Without it, a bug in the placement
  arithmetic or in the join test would read exactly like containment working, and **every negative
  below would be unfalsifiable**. It earned its place: see the off-by-one recorded further down.
- **`list` exists because a negative on the bare string would have decided #44.** "The field was
  spelled wrong" is the one way such a negative could be wrong, so both forms were built. #43 tried
  `fluid_box` against `fluid_boxes` for exactly this reason, and it was the difference between a
  finding and a mistake.
- **`chain/control` is the calibration `chain` went without**, and #111 added it. See AC 3.

**The categorised infinity pipe is a measuring tool, not a preview.** #44 ships no pipe for these
fluids. It exists because a row where an ordinary pipe refuses to join proves nothing on its own — a
box with a *misdeclared* category also refuses everything, and from outside the two are identical.

## AC 1 — does the category reach the engine on a nested energy-source box?

**Yes, in both forms, and the refusal is total.**

```
control      rf-heat-exchanger        + infinity-pipe        joins=YES carries=199.333 status=working
str/refuse   rf-probe-exchanger-str   + infinity-pipe        joins=no  carries=0       status=no_input_fluid
str/accept   rf-probe-exchanger-str   + rf-probe-energy-feed joins=YES carries=199.333 status=working
list/refuse  rf-probe-exchanger-list  + infinity-pipe        joins=no  carries=0       status=no_input_fluid
list/accept  rf-probe-exchanger-list  + rf-probe-energy-feed joins=YES carries=199.333 status=working
```

`carries` is the energy box's own contents against its declared volume of 200, so 199.333 is a full
box being drawn down and refilled. The accepting rows are not merely connected — they reach
`working`, which is a machine that got fuel and is making steam from it.

The runtime API also publishes the field, which is corroboration and not the finding:

```
prototype read: rf-heat-exchanger -> default | rf-probe-exchanger-str -> rf-probe-energy
                | rf-probe-exchanger-list -> rf-probe-energy
```

Worth keeping the order of evidence straight: **the behavioural rows are the ground truth.** A
category the API declines to publish could still be enforced, and one it publishes could still be
ignored — which is the entire premise of this probe. The read is quoted because it agrees, not
because it decides.

`connection_category` set as a bare string and as a one-element list behave identically here. The
repository's `contain()` uses the bare string and has no reason to change.

## AC 2 — does a categorised energy-source box bolt straight to a reactor's output?

**Yes.**

```
bolt: the reactor's output sits on (0.5, 53.5) and points at (0.5, 52.5), and the exchanger
      stands at (1.5, 45.5)
bolt: reactor output joins the exchanger directly, no pipe: YES
bolt: the exchanger holds 199.333 units and reports working
bolt: the reactor's output box held 998.667 units of a 1000 capacity going into this tick
bolt: and it is on an electric network, so it is not sitting at no_power: full_output
```

**`joins=YES` and the exchanger's own `199.333 / working` are what carry this row.** The two lines
after them rule things out rather than establishing anything: the source was never the constraint,
and the reactor was not sitting at `no_power`.

The 998.667 is worth one sentence, though, because the shortfall is exact. A full box that lost
**1.333 units in one tick** is 80 MW at 1 MJ a unit — which is precisely two 40 MW exchangers
drawing at once. Neither number was tuned to meet the other, so the arithmetic is independent
confirmation that both machines in the chain are taking real fuel through this joint and not merely
reporting a status.

**Measured on the chain variant, not on the shipped one-connection shape.** Bolt and chain are one
rig; two would mean two reactors to fill and two chances for the fill loop to differ. The connection
doing the bolting is south `{-1, 7}`.

**That is neither the tile nor the face the shipped machine declares**, and the gap has widened since
this note was written. The shipped exchanger takes its energy on the west **long** face at `{-2, 0}`
with `flow_direction = "input"` (`rf-heat-exchanger`'s `energy_source.fluid_box` in `prototypes/entities.lua`), and a west-facing connection
cannot meet `rf-reactor`'s north-facing output at all. This variant declares `"input-output"` on
three connections. So what AC 2 and AC 3 establish is that a bolt and a chain work on **the shape ADR
0018 decided** — its Decision item 4 — and not that they work on the shape in the tree today. That
is the useful direction of the two, but it is the narrower claim, and it is the one these rows
support.

**The reactor's output box is filled by Lua rather than by running the simulation.** What is under
test is whether the boxes join and fluid crosses, not what the reactor computes — so this row says
nothing about whether a running reactor's output rate satisfies a bolted exchanger. See what these
numbers are not.

### The off-by-one, recorded because the implementation will meet it

The first run of this probe reported `bolt: ... no` with the reactor's box at 1000/1000. **That was
the rig, not the engine.** The two alignments in play are not the same one:

- A **pipe run** aligns a connection's `target_position` onto the tile the pipe sits in.
- A **direct bolt** aligns one machine's connection *tile* onto the other machine's `target_position`.

Align target against target — which is what the first version did, reusing the idiom from
`scripts/bench-mod-links.ps1` — and the two machines end up one tile clear of each other, both
pointing at the same empty ground. That reads exactly like a refused connection. The probe now
prints where both machines actually stand, so the next reader can see the alignment before believing
the verdict.

## AC 3 — does `input-output` chain on a fluid energy source's box?

**Yes, and fuel crosses rather than merely connecting.**

```
chain: the second exchanger joins the first: YES
chain: it holds 199.333 units and reports working
chain: against the first one's 199.333 units and working
chain: and their WATER boxes join as well, so one feed serves the row: YES
chain/control: an unjoined third one off to the side joins the second: no, and holds 0
               units -- this row must read no and 0, or the two above mean nothing
```

Both exchangers are full and both are making steam, from one reactor connection, with no pipe
anywhere in the row. This is the answer that decides the layout: eight exchangers can hang off one
reactor connection in a column rather than each needing a pipe of its own, and `rf-hc-exchanger`
stays a convenience rather than becoming close to mandatory at the D-T tier.

**The last line is the row's calibration and it was missing until #111.** Without it, "the second one
holds fuel" cannot be told from "the rig filled every box it could reach" — and the rig does write
the reactor's box directly, every tick. A third machine of the same prototype with the same plumbing,
joined to nothing, holds nothing. The rest of this probe always had such a row; the chain row went
without one, which is how a two-week disagreement with
[`exchanger-chaining.md`](exchanger-chaining.md) survived with nothing able to break the tie.

### The chain variant needed three energy connections, not two

This is a fact about the shape ADR 0018 describes, not about the rig — and the shape it is a fact
about **changed under this probe**. `rf-heat-exchanger` was vanilla's 3×2 when #82 ran, and
[#45](https://github.com/trulsjo/realistic-fusion-refreshed/issues/45) made it 5×15 (ADR 0022). The
rig kept building the 3×2 and stopped running altogether; #111 rebuilt it and re-measured, and every
number on this page is from after that.

Today's machine has tile centres x ∈ {−2 … 2} and y ∈ {−7 … 7}, and four of its faces are already
spoken for:

| face | tile | box |
|---|---|---|
| west, long | `{-2, 0}` | the energy intake, `input` |
| east, long | `{2, 0}` | steam, `output` |
| north, short end | `{0, -7}` | water, `input-output` |
| south, short end | `{0, 7}` | water, `input-output` |

Two connections on one tile will not load. So a variant that chains has to chain along the **column**,
north to south, and the free tiles on the short ends are `{-1, -7}` and `{-1, 7}`, beside the water.
The south one also does the bolting: `rf-reactor`'s energy output faces north from `{0, -7}`, so a
machine bolting onto it stands above the reactor and meets it with a south-facing connection. The
west long face cannot do that bolt at all. **Three energy connections, all `input-output`.**
`production_type` stays `"input"`: what the machine *does* with the fluid is unchanged, and
`flow_direction` is what decides whether a connection will join another machine's — the same
distinction `rf-direct-energy-converter`'s own box already makes.

Those are the same three tiles `scripts/probe-exchanger-chaining.ps1` declares for the same question.
Two rigs asking one question have to build one shape, or a disagreement between them says nothing —
which is exactly what happened between #82 and #111.

A consequence for layout, and measured rather than reasoned: two exchangers fifteen tiles apart
**also join through their water boxes**, south `{0, 7}` against north `{0, -7}`, so one water feed
serves the column. The rig asks that question directly — an earlier version of this note claimed it
"incidentally" when nothing in the rig had ever asked it, which is an inference dressed as a
measurement and the one thing a probe exists not to produce. It also has to be true for the rig to
work: the first exchanger's own water box ends up with both faces taken, the reactor below and the
second exchanger above, and it is fed along the column instead. The rig says so on its first line:

```
plumbing: rf-probe-exchanger-chain box 1 (water) has all 2 of its faces taken by neighbours, so
          it is fed along the column rather than from a pipe of its own
```

**Only that one box is allowed to find no free face.** Every other call still stops the run, because
the failure it catches has already happened here: a machine placed one tile too close covered the
column's last free water face, both chained exchangers dropped to `no_input_fluid`, and AC 3
reported on two machines that were not running.

## AC 4 — the same questions on `rf-hc-exchanger`

**One answer covers both**, which is what #82 allowed for.

```
hc/refuse  rf-probe-hc-str + infinity-pipe        joins=no  carries=0       status=no_input_fluid
hc/accept  rf-probe-hc-str + rf-probe-energy-feed joins=YES carries=473.333 status=working
```

473.333 against its declared energy box volume of 500 — a full box being drawn down, the same
picture as the ordinary exchanger's 199.333 of 200. **Chaining** was not repeated for it: the
mechanism is the same one, and the ordinary exchanger's rows establish it. **The bolt now is**, for a
reason #82 could not have had — see AC 5.

## AC 5 — does a single plain `"input"` connection accept a bolt?

Added 2026-09-07 for
[#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275). **Yes.**

```
input-bolt: its box joins the reactor's output directly, no pipe: YES
input-bolt: it holds 473.333 units and reports working
input-bolt: the reactor's output box held 993.333 of a 1000 capacity going into this tick
input-bolt/control: an unjoined one off to the side holds 0 units
```

**Why this needed asking after AC 2 and AC 3 had passed.** Both of those bolt with an
`input-output` connection, and this page's own "What is built" section says so out loud — the chain
variant declares three `input-output` connections where the shipped machines declare one `"input"`.
[`exchanger-chaining.md`](exchanger-chaining.md) then established that a plain `"input"` connection
stops fuel **leaving** a box. Whether it also stops fuel **arriving** through a direct bolt was a
different question with no answer anywhere.

**The subject is the real declaration.** `rf-probe-hc-str` is the shipped `rf-hc-exchanger` with its
energy box categorised and nothing else changed: one connection, `flow_direction = "input"`, south
`{0, 3}`. That face matters — it is the one shipped energy connection in the tree that **can** meet
`rf-reactor`'s north-facing output `{0, -7}`. The ordinary exchanger's west long face cannot meet it
at all, which is a geometry problem and not a flow one.

**The arithmetic corroborates it independently.** The reactor's output box is refilled to 1000 every
tick and reads **993.333** going into the report tick — a shortfall of **6.667 units**, which at
1 MJ a unit is **400 MW**, which is exactly this machine's `energy_consumption`. It is not merely
joined; it is drinking at its rated rate.

**What it decides.** `rf-hc-exchanger` can be contained **as it stands**, so
[#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86) does not have to wait for
[#276](https://github.com/trulsjo/realistic-fusion-refreshed/issues/276) to change that machine's
footprint, nor for the Blender model in
[#277](https://github.com/trulsjo/realistic-fusion-refreshed/issues/277). #86 still waits on #275,
because the **ordinary** exchanger's one energy connection is on a long face that cannot meet the
reactor at all.

**So `flow_direction` governs forwarding, not joining.** A plain `"input"` connection joins another
machine's and accepts what arrives; what it will not do is pass fuel on to a third machine. That is
one sentence neither this page nor `exchanger-chaining.md` could state before.

## What these numbers are not

- **Nothing here is a throughput measurement.** Every row asks whether a connection forms and
  whether fuel crosses it. What a bolted joint carries against a run of pipe is unmeasured, and
  `docs/research/fluid-link-throughput.md` measured the pipe case only.

  **The row of eight is no longer unmeasured, and it was measured elsewhere.** This bullet used to
  end *"a row of eight chained exchangers drawing from one reactor connection is the shape #44 ships
  and its rate is not known"*. [`exchanger-chaining.md`](exchanger-chaining.md) laid that row on
  2026-09-07 for #275: all eight run, and water reaches all eight through the two connections a
  chained row leaves reachable. What is still unmeasured is the **rate** — every figure there is a
  box reading at steady state, not units per second.
- **The reactor is not running.** Its output box is written by Lua every tick. The simulation's own
  output rate against a bolted row is a separate question.
- **Nothing about UPS.** ADR 0005's budget has not been asked about a segment shaped like this.
- **Nothing about what a player sees.** Whether a build with no pipe on the energy leg reads as
  intentional, and what the pipe covers on a bolted face look like, are not in these numbers.
- **Nothing about migration.** Existing dev saves and blueprints have vanilla pipes on this leg; what
  happens to them when the category lands is the implementation's problem, not measured here.

## What is left standing for the implementation

- **Build it.** Every mechanism #44 depends on is confirmed, and none of it needs an entity beyond
  ADR 0010's set.
- **`rf-heat-exchanger` needs three energy connections**, all `input-output`. *This bullet named
  "south plus west and east" on 3x2 tile centres, and #45 made the machine 5x15.* The live tiles are
  the west long face `{-2, 0}` plus the two free short-end tiles `{-1, -7}` and `{-1, 7}`, which are
  what both probes build. **Truls settled the shipped shape on 2026-09-07** — #275, which also flips
  the machine's default orientation and moves water off the short-end centre — so read that ticket
  and the ADR it lands rather than this line.
- **`rf-hc-exchanger` needs no change to be contained**, which is AC 5 above and is new. #276 gives
  it the exchanger's footprint and connections for consistency, not because containment requires it.
- **Two shipped assertions invert.** `scripts/check-containment.ps1` asserts that an ordinary
  pipe still joins the reactor's energy output and carries reactor energy. Both are correct today and
  wrong afterwards.
- **One shipped gate becomes true-but-meaningless.** `scripts/check-aneutronic.ps1` asserts the
  composite tank buffers the tier's energy fluid, but fills it with `insert_fluid` on an unplumbed
  tank, and Lua insertion ignores connection categories. It would keep passing after the capability
  was gone. **#87 has since replaced that row**, and the comment above the file's `tanks` loop records
  it: *"THE ROW THIS REPLACES WAS TRUE AND MEANINGLESS"*.
- **The rigs that plumb this leg with vanilla pipes** are `check-d-t.ps1`, `check-hc.ps1`,
  `check-brownout.ps1`, `bench-mod-links.ps1` and `bench-reactors.ps1`.
