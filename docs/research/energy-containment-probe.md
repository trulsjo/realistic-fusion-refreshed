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
`fusion-reactor` and `fusion-generator` carries `connection_category = {"fusion-plasma"}`, and Space
Age ships no pipe with that category.

The aneutronic half of that design needed no probing. `scripts/check-aneutronic.ps1` already builds a
converter so that its own south connection lands on the tile the reactor's output points at (`:387`)
and a second converter five tiles behind it (`:396-404`) — direct-bolt and chaining, shipped and
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

`scripts/probe-energy-containment.ps1` builds nine rows on one headless map. Every subject is a
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
| `chain` | The `bolt` row with a second categorised exchanger three tiles east, joined through energy connections on their west and east faces |

Two of those rows are instrumentation rather than findings, and both are load-bearing:

- **`control` is the calibration.** It uses the shipped exchanger and an ordinary pipe, which is what
  the mod does today, so it must read `joins=YES` and carry fuel. Without it, a bug in the placement
  arithmetic or in the join test would read exactly like containment working, and **every negative
  below would be unfalsifiable**. It earned its place: see the off-by-one recorded further down.
- **`list` exists because a negative on the bare string would have decided #44.** "The field was
  spelled wrong" is the one way such a negative could be wrong, so both forms were built. #43 tried
  `fluid_box` against `fluid_boxes` for exactly this reason, and it was the difference between a
  finding and a mistake.

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
bolt: the reactor's output sits on (0.5, 53.5) and points at (0.5, 52.5), and the exchanger stands at (0.5, 52)
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
rig; two would mean two reactors to fill and two chances for the fill loop to differ. That costs
nothing here: the connection doing the bolting is south `{0, 0.5}`, the same tile, facing and flow
the shipped exchanger already declares. The variant adds two sideways connections and does not touch
the one under test.

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
```

Both exchangers are full and both are making steam, from one reactor connection, with no pipe
anywhere in the row. This is the answer that decides the layout: eight exchangers can hang off one
reactor face in a row rather than having to ring the reactor, and `rf-hc-exchanger` stays a
convenience rather than becoming close to mandatory at the D-T tier.

### The chain variant needed three energy connections, not two

This is a fact about the shape #44 ships, not about the rig. `rf-heat-exchanger` is vanilla's 3×2, so
its tile centres are x ∈ {−1, 0, 1} and y ∈ {−0.5, 0.5} — and four of those tiles are already spoken
for:

| face | tile | box |
|---|---|---|
| west | `{-1, 0.5}` | water, `input-output` |
| east | `{1, 0.5}` | water, `input-output` |
| north | `{0, -0.5}` | steam, `output` |
| south | `{0, 0.5}` | the energy intake |

Two connections on one tile will not load. So a variant that chains **sideways** has exactly one pair
of tiles available — west `{-1, -0.5}` and east `{1, -0.5}` — and it still needs the south one to
bolt onto a north-facing reactor output. **Three energy connections, all `input-output`.**
`production_type` stays `"input"`: what the machine *does* with the fluid is unchanged, and
`flow_direction` is what decides whether a connection will join another machine's — the same
distinction `rf-direct-energy-converter`'s own box already makes.

A consequence for layout, and measured rather than reasoned: two exchangers three tiles apart **also
join through their water boxes**, east `{1, 0.5}` against west `{-1, 0.5}`, so one water feed serves
the row. The rig asks that question directly — an earlier version of this note claimed it
"incidentally" when nothing in the rig had ever asked it, which is an inference dressed as a
measurement and the one thing a probe exists not to produce.

## AC 4 — the same questions on `rf-hc-exchanger`

**One answer covers both**, which is what #82 allowed for.

```
hc/refuse  rf-probe-hc-str + infinity-pipe        joins=no  carries=0       status=no_input_fluid
hc/accept  rf-probe-hc-str + rf-probe-energy-feed joins=YES carries=473.333 status=working
```

473.333 against its declared energy box volume of 500 — a full box being drawn down, the same
picture as the ordinary exchanger's 199.333 of 200. Bolt and chain were not repeated for it: the
mechanism is the same one, and the ordinary exchanger's rows establish it.

## What these numbers are not

- **Nothing here is a throughput measurement.** Every row asks whether a connection forms and
  whether fuel crosses it. What a bolted joint carries against a run of pipe is unmeasured, and
  `docs/research/fluid-link-throughput.md` measured the pipe case only. A row of eight chained
  exchangers drawing from one reactor connection is the shape #44 ships and its rate is not known.
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
- **`rf-heat-exchanger` needs three energy connections**, south plus west and east, all
  `input-output`, at the tiles named above. `rf-hc-exchanger` has a seven-tile face and more room,
  but the same reasoning applies to it.
- **Two shipped assertions invert.** `scripts/check-containment.ps1:338-342` asserts that an ordinary
  pipe still joins the reactor's energy output and carries reactor energy. Both are correct today and
  wrong afterwards.
- **One shipped gate becomes true-but-meaningless.** `scripts/check-aneutronic.ps1:678` asserts the
  composite tank buffers the tier's energy fluid, but fills it with `insert_fluid` on an unplumbed
  tank (`:463-466`), and Lua insertion ignores connection categories. It would keep passing after the
  capability was gone.
- **The rigs that plumb this leg with vanilla pipes** are `check-d-t.ps1`, `check-hc.ps1`,
  `check-brownout.ps1`, `bench-mod-links.ps1` and `bench-reactors.ps1`.
