# What an upgrade-planner swap does to a chained row of exchangers

Measured 2026-09-17 with `scripts/probe-next-upgrade.ps1`, against Factorio 2.0.77, for
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

**The swap empties the contained energy box and keeps the other two.**

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

## A planner ORDERS the swap; it does not perform it

`surface.upgrade_area` with an upgrade-planner stack returns ok and leaves `to_be_upgraded()` true,
and the entity is **still tier 1**. A construction robot carries the order out, and a benchmark map
has no roboport. So the probe performs the swap directly with `create_entity{ fast_replace = true }`,
which is the same operation a robot performs, and every "after" figure above comes from that.

**This matters for reading any result about upgrade planners in a headless rig.** A probe that
stopped at `upgrade_area` would report a row of orders and conclude nothing had changed.

## The blueprint

A blueprint over the row captures and re-places (`re-place ok=true`). One reading is worth recording
because it surprised the run that produced it: **a blueprint taken while an upgrade order is pending
captures the upgrade TARGET, not the entity standing there.** An early run whose capture area
covered the ordered machine returned `upgprobe-grouped-t1, rf-reactor, upgprobe-grouped-t2,
upgprobe-grouped-t1` — a `t2` that exists nowhere on the map. Later runs with a narrower area
captured `rf-reactor, upgprobe-grouped-t1`.

**That reading is from one run and the capture areas differed, so it is a lead rather than a
finding.** Anyone acting on it should re-take it deliberately.

## What this does NOT answer

- **The reactor face.** `reactor joins=-/-` in every run: the row was never bolted to `rf-reactor`,
  only to itself. The reactor sells energy north and south (ADR 0031) and the probe lays the row
  east of it, so the two never met. **#396's "does the face bolted to `rf-reactor` survive" is
  unanswered**, and the layout is what needs fixing rather than the conclusion.
- **Whether the fluid loss matters.** One buffer of `rf-reactor-energy` per swap is a number without
  a threshold beside it.
- **Anything about a real second tier.** The scratch pair differs in `energy_consumption` and in
  nothing else, on purpose. #315 owns the shipped tier.
- **Robots doing it.** Every swap here is a direct `fast_replace`. A robot-performed upgrade in a
  real game was not observed.

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
