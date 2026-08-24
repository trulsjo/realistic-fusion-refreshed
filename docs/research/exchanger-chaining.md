# Can heat exchangers be chained?

Measured against **Factorio 2.0.77** by [`scripts/probe-exchanger-chaining.ps1`](../../scripts/probe-exchanger-chaining.ps1),
2026-08-23, for a question about `rf-heat-exchanger`'s layout.

**Short answer: no, and it is not close.** A fluid energy source is a sink. Two exchangers laid end
to end with `input-output` connections on their short ends *do* join into one fluid connection — the
engine reports them plumbed together — and then move **exactly nothing** between them. Reactor
energy has to reach each exchanger through a pipe.

## Why the question came up

A lit D-T reactor sells about **322 MW** (measured by `scripts/check-brownout.ps1`, which settles at
321.9 MW over one minute against 322.4 over the next). One `rf-heat-exchanger` takes **40 MW**.

| | rating | per reactor |
|---|---:|---:|
| `rf-heat-exchanger` | 40 MW | **9** — eight is 320 MW and leaves 2 MW unconverted |
| `rf-hc-exchanger` | 400 MW | **1**, with 20% spare |

So the ordinary machine needs eight to cover all but 2 MW of it and nine to cover it outright, which
is what `rf-hc-exchanger` exists to remove (#32) — and the ×10 factor is the predecessor's own.
(`entities.lua`'s own comment says "eight exchangers and fifty-five turbines" against a rounded
320 MW; the figure here is the measured 322.) Eight machines is a plumbing problem, and the
question was whether they could be laid in a row that feeds itself rather than each dropped onto a
manifold.

## What was measured

Each variant is `rf-heat-exchanger` deepcopied with only its **energy** box's connections changed, so
nothing else differs. Two of each, laid end to end, fifteen tiles apart. The first is topped back up
to 200 units every tick.

| variant | boxes joined | reached the 2nd | 1st still held |
|---|---|---:|---:|
| shipped — energy in on the west long face only | no | **0** | 179.9 |
| energy on the west face **and** in/out on both short ends | **yes** | **0** | 179.9 |
| in/out on both short ends, no long face | **yes** | **0** | 179.9 |
| **categorised** — as #82 tested, `connection_category` on every energy connection | **yes** | **0** | 179.9 |
| **fed by a pipe** — fluid arrives through a connection rather than being injected | **yes** | **0** | 200 |
| **control** — shipped pair, joined by a run of vanilla pipe | n/a | **48.41** | 51.59 |

**The control is what makes the rest a finding.** Without it, "nothing arrived" could have been the
probe filling things wrongly. Through a pipe the same fluid moves freely and distributes along the
run; between two energy boxes it does not move at all.

**Joined but inert** is the precise result. The engine forms the connection — `get_pipe_connections`
on the first machine reports the second as its target — and no fluid crosses it. A fluid
`energy_source` consumes; it does not forward.

## Two traps this walked into, recorded so the next probe does not

**The data stage said yes, and that was worth nothing.** Setting `flow_direction = "input-output"` on
`energy_source.fluid_box` loads cleanly and `load-check` passes. That is the same false positive
[`probe-native-heat.ps1`](../../scripts/probe-native-heat.ps1) records for the reactor-as-crafting-machine:
it loaded perfectly and then moved no fluid at all.

**The first measurement was a self-inflicted zero.** The energy box holds 200 units and the machine
burns 40 MW of 1 MJ units — 0.667 a tick — so across a 300-tick run it consumed exactly the 200 it
had been given. "Nothing reached the second" was measuring the first running dry. The probe now tops
the source up every tick, and the numbers above are from after that fix.

**And the first control measured the containment rule instead.** It joined the two machines with
`rf-pipe`, whose connections carry the plasma category (#26), so it could not carry reactor energy at
all. Reactor energy is an ordinary fluid today and an ordinary pipe carries it, so the control uses
vanilla `pipe`. Note that this is the interim state rather than the intended one:
[ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) decides "No pipe entity carries
either, and none is added", and `CONTEXT.md` records that no prototype carries an energy category
yet. An earlier draft of this note cited that ADR as the reason a pipe carries energy, which is
backwards.

## It contradicts ADR 0018, and that is not resolved

[ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md) records the opposite, from #82,
measured against the same 2.0.77:

> a categorised exchanger bolts face to face with a reactor's output box with no pipe between them,
> **and two of them chain with fuel crossing to the second**

The last two rows of the table exist to find the difference, and did not:

- **It is not the category.** #82's chain variant carried a `connection_category`; a variant here
  carries one too, and passes nothing.
- **It is not how the fluid arrives.** The rows that inject into the first machine's box could have
  been measuring a box that will hold fluid but not push it. Feeding the first through a pipe on its
  west face instead leaves it holding a full 200 units, joined, with the second still on zero.

**#82's probe cannot be re-run to check, and that is true on `main` as well as here.**
[`probe-energy-containment.ps1`](../../scripts/probe-energy-containment.ps1) fails during map
creation with *"no free connection to attach an infinity pipe to on rf-probe-exchanger-chain box 2"*
— its `unbound()` assumes every box it plumbs has a free face, and the chained pair does not. That
failure predates this work. A second failure, which did not, was this repository moving
`rf-heat-exchanger`'s energy inlet from the south face to the west while the probe named "south";
that one is fixed here.

So the position is: five variants say no, the control says the method works, and the one recorded
"yes" rests on evidence nobody can currently reproduce. **This note does not claim #82 was wrong.**
It claims the question is open, and that a decision resting on the "yes" — ADR 0018 ships no pipe for
either energy fluid, on the premise that exchangers bolt and chain — should not rest on it until the
probe runs again. The aneutronic half is unaffected: a generator's own fluid box does chain, and
`scripts/check-aneutronic.ps1` proves it on every run.

## What this does and does not settle

**Measured, five ways:** nothing crosses between two heat-exchanger energy boxes. If that holds, any
layout with more than one exchanger on a reactor needs a pipe carrying energy to each. Read against
the section above before treating it as settled — ADR 0018 records the opposite and the disagreement
is live.

**Not measured here:** whether **water** chains end to end. It is an ordinary `input-output` box on a
boiler rather than an energy source, and vanilla boilers chain water in a row, so it is expected to —
but expected is not measured, and this probe did not ask.

**Not decided here:** the layout. That the ordinary exchanger needs a manifold is a fact; whether the
machine should therefore stay 5×15, or whether eight-per-reactor is itself the thing to change, is
Truls's. Worth noting that `rf-hc-exchanger` at one-per-reactor sidesteps the whole question, and it
already exists.
