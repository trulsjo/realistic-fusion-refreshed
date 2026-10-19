# What an upgrade-planner swap does to a chained row of exchangers

Measured 2026-09-17, the reactor face on 2026-09-30, the lone swap on 2026-10-01 and a robot's
swap and the blueprint on 2026-10-19, with `scripts/probe-next-upgrade.ps1`, against Factorio 2.0.77, for
[#396](https://github.com/trulsjo/realistic-fusion-refreshed/issues/396). **This note is a probe's
findings.** It draws no threshold and proposes nothing;
[#315](https://github.com/trulsjo/realistic-fusion-refreshed/issues/315) chose route 1 during triage
and the ADR that route wants is Truls's to write.

Nothing in this mod is on any upgrade path today — `claim()` in
`realistic-fusion-refreshed-core/prototypes/vanilla.lua` clears `next_upgrade` and
`fast_replaceable_group` on every machine both modules copy out of vanilla — so the probe stands up
its own scratch pair outside the `rf-` set and changes no shipped prototype.

## The headline: two answers that a reader of the 2.0.77 docs would not predict

**`next_upgrade` alone does not load.** The pair is refused at the PROTOTYPE stage, not at runtime:

```
Error while running setup for entity prototype "upgprobe-ungrouped-t1" (boiler): next_upgrade
target (upgprobe-ungrouped-t2) must have the same fast_replaceable_group
(upgprobe-ungrouped-t2 != upgprobe-ungrouped-t1).
```

The [2.0.77 EntityPrototype docs](https://lua-api.factorio.com/2.0.77/prototypes/EntityPrototype.html)
state **no** such constraint — they define `next_upgrade` and say nothing about
`fast_replaceable_group`. The engine enforces it anyway. With the field absent each prototype
defaults it to its own name, so two prototypes that both omit it are *not* equal and the pair is
rejected. **So #315's route needs both fields, and a tier-2 prototype that sets only `next_upgrade`
will not load at all** — which is a loud failure rather than a quiet one, and is the good case.

**The swap empties the contained energy box and keeps the other two** — on the swapped machine.
Where that energy goes is the two dated blocks below: with a reactor bolted on, it moves into the
reactor (2026-09-30); with nothing joined, it is lost (2026-10-01). *(All three are readings in
the tick of the swap. Read again 600 ticks later on 2026-10-19, a bolted row had all but 1.6 of its
energy back and a lone box was still empty — see the #408 block below.)*

| box | filter | before | after the swap |
|---|---|---:|---|
| 1 | `water` | 100.0 | **100.0** |
| 2 | `steam` | 100.0 | **100.0** |
| 3 | `rf-reactor-energy` | 100.0 | **empty** |

Water and steam survive; the reactor energy does not. Box 3 is the machine's fluid **energy source**
box rather than an ordinary fluid box, which is the difference `probe-exchanger-chaining.ps1` also
found to matter — fuel written into an energy source's box behaves unlike fuel in an output box.
Whether losing one buffer's worth of energy per swap matters is a balance question and is not this
note's to answer.

> **2026-09-30, [#401](https://github.com/trulsjo/realistic-fusion-refreshed/issues/401): "empties"
> is what the swapped machine reads, and it is not where the energy went.** With the row bolted to
> a reactor, the reactor's own box was filled to 500 and the swapped machine's to 100 in the same
> tick, then the swap performed and both read again in that tick:
>
> | | before | after the swap |
> |---|---:|---:|
> | row[2] box 3, `rf-reactor-energy` | 100.0 | **empty** |
> | the reactor's energy box | 500.0 | **600.0** |
> | `rf-reactor-energy` across reactor + all three in the row | 600.0 | **600.0** |
>
> The hundred moved into the peer across the bolted face; nothing was destroyed, and neither
> neighbour in the row took any of it. The 2026-09-17 run above read only the swapped machine, so
> it could not tell an emptied box from a moved one — and its row's energy boxes were joined to
> each other, so its "empty" may have been a move too. Whether a swap with NO peer on the energy
> box loses the fluid was the open half, and the 2026-10-01 block below answers it.

> **2026-10-01, [#478](https://github.com/trulsjo/realistic-fusion-refreshed/issues/478): with
> nothing to receive it, the energy is LOST.** A lone exchanger stood clear of everything else the
> rig builds, its energy box filled to capacity — 200 — and a control read before the swap listed
> each of its three energy connections, `north->- west->- east->-`: none reached anything. It was
> swapped by the same `fast_replace` as the row, and the box and the total across every entity on
> the surface that holds `rf-reactor-energy` were read before and after in that tick:
>
> | | before | after the swap |
> |---|---:|---:|
> | the lone machine's energy box | 200.0 | **0.0** |
> | `rf-reactor-energy` across every holder on the surface | 800.0 | **600.0** |
>
> The 600 that stayed is what the bolted case above left in the reactor and row, which this run
> does not touch. **So whether a swap loses the
> box depends on whether anything is joined to it**: with a peer it moved (#401), with none it was
> destroyed — a full buffer, 200 units of reactor energy, per machine. How the engine moves it is
> not measured, only that the two cases differ. Whether the loss matters is a balance question, as
> above. One run.

> **2026-10-19, [#408](https://github.com/trulsjo/realistic-fusion-refreshed/issues/408): a
> ROBOT'S swap and a direct one agree, and what a same-tick reading calls lost on a bolted row is
> back 600 ticks later.** Every figure above is a direct `create_entity{ fast_replace = true }`,
> read in the tick of the swap. The probe now builds a second site with a roboport, ten
> construction robots and a storage chest of tier-2 items, leaves the planner's order for a robot,
> and builds a TWIN row beside it — same geometry, same fill, never ordered — whose middle machine
> is fast_replaced directly in the tick the robot's swap is first seen. Steam boxes are filled to
> capacity on both, so nothing boils away while the robot travels. Both rows pass both controls
> (`2 of 2`, `REACTOR IS BOLTED`) before anything is swapped. By tick 449 the reactor's 500 had
> flowed into the row, so both swaps started from the reactor box empty and row[2]'s full. Every
> swapped holder is read again 600 ticks after the last swap:
>
> | | robot | direct, the twin |
> |---|---:|---:|
> | row[2] `rf-reactor-energy` before | 200.0 | 200.0 |
> | row[2] `rf-reactor-energy` in the tick of the swap | 33.2 | empty |
> | `rf-reactor-energy` across reactor + row: before → in the tick → **settled** | 598.4 → 432.4 → **596.8** | 598.4 → 398.4 → **596.8** |
> | water and steam in row[2] after | 100.0 and 200.0, kept | 100.0 and 200.0, kept |
> | joints: row[2], both neighbours, reactor face | re-formed, same relations | re-formed, same relations |
>
> Two runs, identical to the tenth, settled at tick 2014 and 2019. **So the two operations agree on
> every settled reading — joints, water, steam and energy — and neither loses the energy of a box
> with a peer**: both rows end 1.6 short of where they started, the same 1.6 each. The same-tick
> readings differ, 166.0 against 200.0 missing, and neither is a loss: it had not arrived yet.
> Where it is in between is not measured.
>
> **That reaches back over the sections above.** The 2026-09-17 "empty" and the 2026-09-30 "moved
> into the reactor" are same-tick readings, so each is what one tick showed rather than where the
> energy ends up. Neither is a measurement of a different operation from a robot's.
>
> **A lone machine loses its buffer either way, and stays lost.** A lone exchanger inside the
> roboport's reach, energy box full at 200 and its three energy connections reaching nothing
> (`north->- west->- east->-`), was ordered once the row's swap was done and swapped by a robot at
> tick 1413 and, in the second run, 1418: lone box 200.0 → 0.0, every holder at the site 796.8 →
> 596.8. Settled, the robot's lone box and the direct section's, swapped by `fast_replace` as on
> 2026-10-01, both read 0.0 — so #478's loss is a loss, measured both ways.

## The joints survive, and the row re-joins the replacement

The row is three exchangers chained short end to short end. **The control says the row was actually
chained before anything was swapped** — 2 of 2 neighbouring pairs joined — which is what makes every
line below a difference rather than a lone reading.

| | before | after |
|---|---|---|
| `row[2]` box 1 reaches | two neighbours | **two neighbours** |
| `row[2]` joins | `11+9` | `11+9` |
| `row[1]` joins | the old `row[2]` | **the new `row[2]`** |
| `row[3]` joins | the old `row[2]` | **the new `row[2]`** |

A swap **mid-row** does not break the chain for the neighbours either side: both re-join the
replacement, by its new unit number, in the same tick. That is #396's question 6 answered in the
affirmative.

Joining is asked through `get_pipe_connections` and each connection's `target.owner`, not through a
system id: **`get_fluid_system_id` is not a 2.0.77 method**, and indexing it raises rather than
returning nil. `probe-exchanger-chaining.ps1` established that first and this probe borrows the
idiom rather than rediscovering it.

## The reactor face survives too

**Answered 2026-09-30 for [#401](https://github.com/trulsjo/realistic-fusion-refreshed/issues/401).**
Until then `reactor joins=-/-` in every run, because the row was laid east of the reactor and a
reactor sells energy north and south (ADR 0031). The probe now bolts the row's MIDDLE machine —
the one the swap is pointed at — by its north energy face onto the reactor's south output, placed
by `check-hc.ps1`'s bolt arithmetic off the live connections rather than by typed offsets, and
chains the other two off its short ends. The reactor's south output reads at `0.5,7.5` targeting
`0.5,8.5`, and the row lands at `x = -14.5, 0.5, 15.5`, `y = 10.5`.

**The control asks from both sides before any swap** — the reactor's south connection reaches the
exchanger and the exchanger's north connection reaches the reactor — and both did: `REACTOR IS
BOLTED`, alongside the row's own `2 of 2`.

| | before the swap | after |
|---|---|---|
| reactor's south energy connection reaches | the old `row[2]` (6) | **the new `row[2]` (11)** |
| `row[2]`'s north energy connection reaches | the reactor (4) | **the reactor (4)** |
| `row[1]`, `row[3]` reach | the old `row[2]` | **the new `row[2]`** |

The unit numbers are one run's; a second run on the same commit read 4, 9 and 2 in their places,
with every relation the same.

**The joint #315's route most depends on — the one that carries energy into the row at all —
re-forms in the same tick, from both sides.** And the reactor's own box is not emptied: it GAINS
the swapped machine's energy, as the fluid section above records. *(In the tick of the swap, with
the reactor's box holding 500. On 2026-10-19 an empty reactor box gained nothing in that tick, and
the row had its energy back 600 ticks later; see the #408 block above.)*

## A planner ORDERS the swap; it does not perform it

`surface.upgrade_area` with an upgrade-planner stack returns ok and leaves `to_be_upgraded()` true,
and the entity is **still tier 1**. A construction robot carries the order out, and a benchmark map
has no roboport. So the probe performs the swap directly with `create_entity{ fast_replace = true }`,
~~which is the same operation a robot performs~~, and every "after" figure in the sections dated
before 2026-10-19 comes from that. **#408 put a roboport in the rig, and the two agree on every
settled reading** — see the 2026-10-19 block above.

**This matters for reading any result about upgrade planners in a headless rig.** A probe that
stopped at `upgrade_area` would report a row of orders and conclude nothing had changed.

## The blueprint

> **2026-10-19, [#408](https://github.com/trulsjo/realistic-fusion-refreshed/issues/408): settled.
> A blueprint taken while an upgrade order is pending captures the upgrade TARGET.** One capture
> area, the union of the reactor's and the row's bounding boxes (`-21.8,-6.8 .. 22.8,12.8`),
> computed once and used for two fresh blueprints, before anything is performed:
>
> | | the blueprint holds |
> |---|---|
> | before the order | `rf-reactor, upgprobe-grouped-t1, upgprobe-grouped-t1, upgprobe-grouped-t1` |
> | with the order pending, row[2] still tier 1 on the map (`to_be_upgraded=true`) | `rf-reactor, upgprobe-grouped-t1, upgprobe-grouped-t1, upgprobe-grouped-t2` |
>
> The area is the same and only the order differs, so the `t2` is the order's doing. Two runs, the
> same both times. The paragraph below is the lead as it was first recorded.

A blueprint over the row captures and re-places (`re-place ok=true`). One reading is worth recording
because it surprised the run that produced it: **a blueprint taken while an upgrade order is pending
captures the upgrade TARGET, not the entity standing there.** An early run whose capture area
covered the ordered machine returned `upgprobe-grouped-t1, rf-reactor, upgprobe-grouped-t2,
upgprobe-grouped-t1` — a `t2` that exists nowhere on the map. Later runs with a narrower area
captured `rf-reactor, upgprobe-grouped-t1`. Since #401 the capture area is the union of the
reactor's and the row's own bounding boxes and is taken AFTER the swap, so it holds
`rf-reactor, upgprobe-grouped-t1, upgprobe-grouped-t2, upgprobe-grouped-t1` — a `t2` that does
exist this time — and says nothing more about the lead.

**That reading is from one run and the capture areas differed, so it is a lead rather than a
finding.** Anyone acting on it should re-take it deliberately.

## What this does NOT answer

- **Anything about a real second tier.** The scratch pair differs in `energy_consumption` and in
  nothing else, on purpose. #315 owns the shipped tier.
- **Where a peered box's energy is between the swap and its return**, and why the same tick
  reads 33.2 of it after a robot's swap and none after a direct one. Two runs at one state.

## Reproducing it

```
pwsh -File scripts/probe-next-upgrade.ps1
```

It loads twice: once with an ungrouped pair, whose refusal is the first finding and is caught rather
than thrown, and once with a grouped pair for everything else. Exit 0 means it ran and reported.

**The ungrouped load has three outcomes, not two, and the third is the one to watch for.** A run that
throws has not necessarily been refused — `Invoke-FactorioStep` throws on any non-zero exit — so the
probe reports `UNANSWERED` when it fails without the `next_upgrade target` text, and says nothing
about `fast_replaceable_group` in that case. A Factorio already running is the usual cause;
`scripts/factorio-lib.ps1`'s own header records that it once *"cost two wrong conclusions in a row
before anyone noticed the game was simply running"*. If you see `UNANSWERED`, read the log the line
names rather than re-running blind.
