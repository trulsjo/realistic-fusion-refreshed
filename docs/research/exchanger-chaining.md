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
| `rf-heat-exchanger` | 40 MW | **8** |
| `rf-hc-exchanger` | 400 MW | **1**, with 20% spare |

So the ordinary machine needs eight per reactor, which is what `rf-hc-exchanger` exists to remove
(#32) — and the ×10 factor is the predecessor's own. Eight machines is a plumbing problem, and the
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
all. Reactor energy is an ordinary fluid in an ordinary pipe, which is the point of
[ADR 0018](../adr/0018-energy-is-contained-and-no-pipe-carries-it.md). The control uses vanilla
`pipe`.

## What this does and does not settle

**Settled:** reactor energy cannot be chained through exchangers. Any layout with more than one
exchanger on a reactor needs a pipe carrying energy to each.

**Not measured here:** whether **water** chains end to end. It is an ordinary `input-output` box on a
boiler rather than an energy source, and vanilla boilers chain water in a row, so it is expected to —
but expected is not measured, and this probe did not ask.

**Not decided here:** the layout. That the ordinary exchanger needs a manifold is a fact; whether the
machine should therefore stay 5×15, or whether eight-per-reactor is itself the thing to change, is
Truls's. Worth noting that `rf-hc-exchanger` at one-per-reactor sidesteps the whole question, and it
already exists.
