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

> **The SeaBlock row was closed on 2026-09-01 by
> [#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208), after this sweep ran.**
> `rf-pipe-to-ground` now carries that mod's own opt-out, and re-running the probe on that lane
> reports **44 differences, all of them the benign default-widening** — the `LOST` and `WIDENED` rows
> below are gone. Everything in this note is left as measured on the morning of that day, because it
> is the evidence the decision was taken on; the table records what the sweep found, not what the
> lane does now.

## The answer in one line

**Reassigning a containment category is one mod's behaviour, not a pattern. Adding a category to an
ordinary box of ours is a pattern, and it is benign.**

One lane of fourteen changes a connection this repo contained, and it is
[SeaBlock NG](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139) — the lane #206 already
measured, on the strength of `no-pipe-touching` 1.1.28, which appears in no other lane. **Three**
lanes add a category to connections we left `default` — SeaBlock among them, doing both things —
and none of the three removes one there. **Eleven of the fourteen change nothing at all.** One plus
three, less the lane counted in both, plus eleven, is fourteen.

**What that gives #208 is an asymmetry, not an answer.** Adding is done by two mods on three lanes by
two mechanisms; removing is done by one mod on one lane, to one prototype. Whether that makes a
mod-specific response sufficient, or merely cheap today, is #208's to weigh — and the limits below
bear on it in the other direction.

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
| **SeaBlock NG** | [#139](https://github.com/trulsjo/realistic-fusion-refreshed/issues/139) | 46 | **46** | **1** | **1** | 44 | **overwrites and widens `rf-pipe-to-ground`**; adds vanilla `pipe` and Bob's ten to the 44 (`rf-pipe` only on the contained one) |
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

**`no-pipe-touching` is in one lane's cache and no other**, and no other lane changes a category of
ours. So the breach is confined by which mod is present. Stated as an effect rather than as a claim
about their source, deliberately: a zero-diff lane shows that nothing *happened*, not that no mod in
it carries a pass of that shape whose guard simply declined to fire.

**It is not confined by anything about our prototypes, and the shape of ours is half the cause.**
That pass fires on a `pipe-to-ground` holding *no default category on any connection*, which is the
shape containment itself gives `rf-pipe-to-ground`; and `rf-pipe` keeping `rf-plasma` on all four of
its connections is what stops the earlier pass marking the underground sibling `solved_by_npt` and
taking it out of scope. `connection-category-reassignment.md` sets that out in full. **The more
thoroughly a box is contained, the more certainly this pass claims it** — so "only one mod does
this" and "our own prototypes qualify themselves for it" are both true, and the second is the half
that would carry over to a mod nobody has fetched.

## The pattern that does exist, and why it is not the same finding

**Three lanes add a category to connections we left `default`, and every one keeps `default`**, so
an ordinary pipe still connects and nothing of ours is closed off. Two mods account for the three:

- **Krastorio 2** adds `kr-steel-pipe` to all 44, on both the lane where it appears alone (#33) and
  the one where it appears with Space Exploration (#130). Its own pipe wanting to join ordinary boxes.
- **SeaBlock NG** (#139) adds vanilla `pipe` and Bob's ten — **eleven**, via `no-pipe-touching`.

**`rf-pipe` is not among those eleven, and the difference is measured rather than tidied.** The bare
name of our own pipe prototype reaches only the *contained* surface connection of
`rf-pipe-to-ground`, where twelve are appended. Not one of the 44 default rows carries it; every one
of them holds exactly `{default, pipe, bob-*...}`. Two passes of that mod append to two different
sets of boxes and they do not append the same list, which is worth knowing before anyone writes a
rule keyed on our own name appearing somewhere.

Two unrelated mods, two mechanisms, the same benign effect. **Adding is what a pipe mod does;
removing, on this evidence, is what one mod does.** That asymmetry is the result; what to build on it
is #208's.

## Three things worth knowing beyond the counts

**Adding a set on top of Space Age does the same as adding it alone.** The four `-With space-age`
lanes report the same as their plain counterparts — checked by hashing each run's report body, not
by eye, and all eight hash the same because all eight report no difference.

**That is not the same as "Space Age changes nothing", and an earlier draft of this note said the
stronger thing.** `-With` enables a bundled mod on **both** sides of the comparison: the probe builds
one `$enabledBundled` list and `Get-OurConnections` passes it to `Write-ModList` on the declared run
and the loaded run alike (`scripts/probe-connection-categories.ps1:270`). So Space Age is in the
baseline as well as in the subject and **cancels out of the diff**. If Space Age appended a category
to `rf-heater`'s output box, all four of those lanes would still report zero, and hashing the report
bodies would not catch it because it only shows that all eight are empty. Whatever Space Age does to
our prototypes — ADR 0007's finding 4 records nine objects edited — **this instrument cannot see
it**, and could not have.

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

- **Nothing about what the bundled mods do.** Anything enabled with `-With` — Space Age on four
  lanes, `quality` on SeaBlock — is loaded on both sides of every comparison and cancels out. This
  instrument measures what a **junctioned set** does on top of whatever bundled mods are enabled, and
  it is blind to the bundled mods themselves. Measuring those would need a baseline without them,
  which the probe does not currently build.
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
