# Does plasma actually cross the tunnel?

Evidence for [#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208), which decided
to take `no-pipe-touching`'s own opt-out and required this measurement before the answer shipped.
**Nothing here decides anything** — the decision is recorded on #208 and in
[ADR 0007](../adr/0007-coexistence-without-integration.md)'s finding 4.

Measured on **2026-09-01** against **Factorio 2.0.77** (file version 2.0.77.84539) by
`scripts/probe-plasma-tunnel.ps1`, on the `seablock` lane — 46 mods, `-With quality`,
`no-pipe-touching` **1.1.28**.

## Why this exists and the category probe was not enough

`scripts/probe-connection-categories.ps1` reads **prototypes**. It established that the mod rewrites
`rf-pipe-to-ground`'s connections. That is a measurement about a *declaration*.

"The declaration is gone" and "the plasma moves" are two claims, and #208 was decided on the first
while the argument that it *matters* rested on a reading of somebody else's Lua that nobody had run:
that the mod gives **vanilla's** pipe-to-ground the category `pipe-to-ground` as well
(`data-final-fixes.lua:160`, where it writes the underground prototype's own name), so after the
rewrite ours and vanilla's match exactly and a player's tunnel pairs with our plasma line.

**That reading is now measured and it was right.**

## The result

Five rows on one map, one loaded copy of the set. Each row is the same chain — a plasma feed, a
pipe-to-ground taking it on its surface connection, a tunnel across five tiles of open ground, and a
partner hanging off the far end:

```
row           subject                partner            near       far   partner
hole-under    rf-probe-tunnel-bare   pipe-to-ground   100.000         -   100.000
fix-under     rf-pipe-to-ground      pipe-to-ground   100.000         -     0.000
hole-surface  rf-probe-tunnel-bare   bob-copper-pipe  100.000   100.000   100.000
fix-surface   rf-pipe-to-ground      bob-copper-pipe  100.000   100.000     0.000
control       rf-pipe-to-ground      rf-pipe          100.000   100.000   100.000
```

`rf-probe-tunnel-bare` is the shipped prototype with `npt_compat` removed and **nothing else
changed** — the state `rf-pipe-to-ground` was in before #208. Both are on the same map so the hole
and the fix are compared against one loaded copy of the set rather than across two runs.

**The tunnel is real.** A vanilla pipe-to-ground five tiles away receives our plasma, underground and
out of sight — exactly the case `prototypes/entities.lua` says cannot happen.

**The widening is real.** A `bob-copper-pipe` laid against the surface connection carries plasma
away. This is the half that keeps `rf-plasma` in its list, and it leaks just as thoroughly: a
whitelist with eleven more names on it is not a weaker fence, it is a gate.

**Both close.** With the opt-out, the partner holds nothing in either case.

**`fix-surface` is the row that proves the fix is a refusal rather than a failure.** Its far end holds
100 while its partner holds 0 — so plasma crossed our own tunnel, arrived in the far box, and was
refused at the bob pipe. Had the whole chain simply broken, `far` would read 0 too.

## The control, and why the first run of this probe is not in the table

**`control` must cross, and does.** It is the same five-tile chain with `rf-pipe` as the partner, so
it exercises every part the refusals depend on — feed, filter, surface connection, tunnel pairing,
far surface connection.

It earned its place immediately. **The first version of this rig reported 0.000 on all five rows,
including the control**, and those numbers would have read as a total vindication of containment.
They were a broken rig. Three mistakes, all of them fixed by copying the geometry from
`scripts/check-containment.ps1`'s tunnel row, which is a gate that passes today:

- entities were centred on integers instead of half-tile centres, so nothing landed where intended;
- the infinity filter carried no `temperature` and no `mode`, and plasma at 6e8 K does not fill
  without them;
- the feed sat **two** tiles from the subject, and no connection category can bridge a gap.

Any of the three produces five confident zeroes. The control is the only reason they were caught
rather than published, and it is the reason the refusals above can be believed.

## What this does not establish

- **Nothing about the other thirteen lanes.** They are covered at the declaration level by
  [`connection-categories-by-lane.md`](connection-categories-by-lane.md), and none of them changes a
  category of ours.
- **Nothing about a later release of `no-pipe-touching`.** 1.1.28 is what ran. The opt-out is that
  mod's own published hook, so a version that changes it changes this result.
- **Nothing about any other mod.** The fix is a permission from one author, not a defence.
  [#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209) is the gate that would
  notice a second one, and it is the trigger for reopening #208.
- **Nothing about pipes we did not try.** `bob-copper-pipe` stands for the eleven names the widening
  appends; the other ten were not placed.
