# What every lane does to our connection categories

Evidence for [#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207), which ran
[#206](https://github.com/trulsjo/realistic-fusion-refreshed/issues/206)'s probe across all fourteen
lanes in [ADR 0007](../adr/0007-coexistence-without-integration.md)'s table. **Nothing here decides
anything.** What to do about the one lane that breaches containment is
[#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208) and Truls's call;
[#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209) is the gate.

Measured on **2026-09-01** against **Factorio 2.0.77** (file version 2.0.77.84539) by
`scripts/probe-connection-categories.ps1`, one run per lane, 28 `--dump-data` runs in 6.1 minutes.
Every lane exited 0.

**Every row is a claim about that family's pinned `factorio_version` 2.0 release and about nothing
else** — [ADR 0026](../adr/0026-third-party-mods-are-pinned-to-their-2-0-line.md) confines it to that,
and no unqualified "works with X" may be built on one. The per-lane run log is the lane's own issue
([ADR 0027](../adr/0027-the-lane-issue-is-the-run-log.md)); each row links to it.

## The answer in one line

**Reassigning a containment category is one mod's behaviour, not a pattern. Adding a category to an
ordinary box of ours is a pattern, and it is benign.**

One lane of fourteen changes a connection this repo contained, and it is
[SeaBlock NG](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139) — the lane #206 already
measured, on the strength of `no-pipe-touching` 1.1.28, which appears in no other lane. Two lanes add
a category to connections we left `default`, by a different mechanism that removes nothing. **Eleven
of the fourteen change nothing at all.**

That matters for #208 because it is the question that decides whether a mod-specific response is
adequate: on this evidence it is. A response shaped for one mod's `data-final-fixes` covers every
breach measured.

## The table

Same instrument, same subject, every lane: **17 prototypes of ours carry pipe connections, 58
connections in total, 14 of them contained with `rf-plasma`.** Those three figures were identical on
all fourteen runs, which is the instrument reporting that it read the same thing each time.

| Lane | Issue | Mods | Diffs | LOST | WIDENED | on `default` | What it does |
|---|---|---|---|---|---|---|---|
| Krastorio 2 | [#33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33) | 5 | 44 | 0 | 0 | 44 | adds `kr-steel-pipe` to every default connection |
| Space Exploration | [#129](https://github.com/trulsjo/realistic-fusion-refreshed/issues/129) | 17 | **0** | 0 | 0 | 0 | nothing |
| Krastorio 2 + Space Exploration | [#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130) | 22 | 44 | 0 | 0 | 44 | the same `kr-steel-pipe`; SE adds nothing of its own |
| Angel's | [#131](https://github.com/trulsjo/realistic-fusion-refreshed/issues/131) | 8 | **0** | 0 | 0 | 0 | nothing |
| Angel's + Space Age | [#132](https://github.com/trulsjo/realistic-fusion-refreshed/issues/132) | 8 | **0** | 0 | 0 | 0 | nothing |
| Bob's | [#133](https://github.com/trulsjo/realistic-fusion-refreshed/issues/133) | 12 | **0** | 0 | 0 | 0 | nothing |
| Bob's + Space Age | [#134](https://github.com/trulsjo/realistic-fusion-refreshed/issues/134) | 12 | **0** | 0 | 0 | 0 | nothing |
| Angel's + Bob's | [#135](https://github.com/trulsjo/realistic-fusion-refreshed/issues/135) | 20 | **0** | 0 | 0 | 0 | nothing |
| Angel's + Bob's + Space Age | [#136](https://github.com/trulsjo/realistic-fusion-refreshed/issues/136) | 20 | **0** | 0 | 0 | 0 | nothing |
| Angel's + Bob's + MadClown's | [#137](https://github.com/trulsjo/realistic-fusion-refreshed/issues/137) | 21 | **0** | 0 | 0 | 0 | nothing |
| Angel's + Bob's + MadClown's + SA | [#138](https://github.com/trulsjo/realistic-fusion-refreshed/issues/138) | 21 | **0** | 0 | 0 | 0 | nothing |
| **SeaBlock NG** | [#139](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139) | 46 | **46** | **1** | **1** | 44 | **overwrites and widens `rf-pipe-to-ground`**; adds vanilla `pipe`, `rf-pipe` and Bob's ten elsewhere |
| RITEG | [#140](https://github.com/trulsjo/realistic-fusion-refreshed/issues/140) | 1 | **0** | 0 | 0 | 0 | nothing |
| Advanced Fluid Handling | [#141](https://github.com/trulsjo/realistic-fusion-refreshed/issues/141) | 1 | **0** | 0 | 0 | 0 | nothing |

`REPLACED` and `STRUCTURAL` are zero on every lane: **no set removed the default category from an
ordinary box of ours, and no set removed a prototype or emptied a fluid box.**

## The one removal

Only `rf-pipe-to-ground` is touched, and only on SeaBlock NG:

```
LOST -- a category we wrote is gone  (1)
  pipe-to-ground/rf-pipe-to-ground  .fluid_box.pipe_connections[2]  [underground]
    declared: rf-plasma
    loaded:   pipe-to-ground

WIDENED -- added to a connection we categorised  (1)
  pipe-to-ground/rf-pipe-to-ground  .fluid_box.pipe_connections[1]  [normal]
    declared: rf-plasma
    loaded:   {rf-plasma, pipe, rf-pipe, bob-copper-pipe, ... bob-ceramic-pipe}
```

Identical to what #206 measured, on a separate invocation. The mechanism, the branch and the line
numbers are in
[`connection-category-reassignment.md`](connection-category-reassignment.md) and are not repeated
here.

**`no-pipe-touching` is in one lane's cache and no other**, so this is confined by which mod is
present rather than by anything about our prototypes. Nothing in the other thirteen lanes has a pass
of that shape.

## The pattern that does exist, and why it is not the same finding

**Two lanes add a category to connections we left `default`, and both keep `default`**, so an
ordinary pipe still connects and nothing of ours is closed off:

- **Krastorio 2** adds `kr-steel-pipe` to all 44, in both the lane where it appears alone and the one
  where it appears with Space Exploration. Its own pipe wanting to join ordinary boxes.
- **SeaBlock NG** adds vanilla `pipe`, the bare name `rf-pipe`, and Bob's ten, via `no-pipe-touching`.

Two unrelated mods, two mechanisms, the same effect. **Adding is what a pipe mod does; removing is
what one mod does.** That asymmetry is the useful result here, and it is the reason a mod-specific
response is defensible where a general one would be over-built.

## Three things worth knowing beyond the counts

**Space Age changes nothing, on any lane.** The four `-With space-age` lanes are byte-identical in
this instrument to their plain counterparts. Whatever Space Age does to our prototypes — ADR 0007's
finding 4 records nine objects edited — it does not touch a pipe connection category.

**Bob's alone does not sweep our boxes.** The `bob-*` categories reach our connections only through
`no-pipe-touching` in the SeaBlock lane. Bob's twelve mods, with and without Space Age, change
nothing here. So a category named after a mod arriving on our prototype is not evidence that the mod
put it there — which is the same caution
[ADR 0028](../adr/0028-a-suppression-rule-reports-on-doubt.md) states for a different check.

**A pipe mod that changes nothing is the control this sweep needed.** Advanced Fluid Handling
(`underground-pipe-pack` 2.0.6) adds underground pipes and leaves all 58 of our connections alone. It
rules out "any mod that adds pipes will do this", which was the obvious alternative explanation for
the SeaBlock result and is now measured rather than assumed.

## What this does not establish

- **Nothing about mods outside these fourteen lanes.** The pins are ADR 0026's; a set nobody has
  fetched is not evidence of anything.
- **Nothing about a later release of any of them.** `no-pipe-touching` 1.1.28 is what was measured.
  Its guard fires on the *absence* of a default category, so a version that changes that guard
  changes this result in either direction.
- **Nothing about the runtime consequence.** The probe reads prototypes. "The declaration is gone" is
  measured; "the plasma moves" is not.
- **Nothing about anything but connection categories.** A set editing a stat, a volume or a pollution
  rate is invisible here by design, and is
  [#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153)'s territory.
