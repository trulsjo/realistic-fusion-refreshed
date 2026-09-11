# What a mod set hides of ours, per lane

Which of this repository's prototypes come out of a loaded game `hidden` — out of the crafting UI and
out of the tooltips a player reads
([#219](https://github.com/trulsjo/realistic-fusion-refreshed/issues/219)).

Measured by `scripts/probe-hidden-prototypes.ps1` against **Factorio 2.0.77 (build 84539)** on
**2026-09-12**, `-With quality`, every lane cached under `.mod-cache/` at the
[ADR 0026](../adr/0026-third-party-mods-are-pinned-to-their-2-0-line.md) pins. The script is committed
rather than the numbers alone: this is a fact about eleven third-party sets at particular versions,
and the next pin refresh is entitled to a different one.

## The answer

**One lane of eleven hides anything of ours, and it hides twenty-six prototypes.**

| lane | mods | hidden by the set |
|---|---:|---:|
| `angels` | 8 | 0 |
| `angels-bobs` | 20 | 0 |
| `angels-bobs-madclowns` | 21 | 0 |
| `bobs` | 12 | 0 |
| `fluid` | 1 | 0 |
| `k2-spaceex` | 22 | 0 |
| `krastorio2` | 5 | 0 |
| `madclowns` | 7 | 0 |
| `riteg` | 1 | 0 |
| **`seablock`** | **46** | **26** |
| `spaceex` | 17 | 0 |

No lane *un*-hides anything of ours, and no lane's dump is missing a prototype of ours — so removal,
which would be a different accident, does not happen either.

## What `seablock` hides

**Nine fluids**, which is the tier boundary rather than a scatter:

| fluid | what it is |
|---|---|
| `rf-tritium` | D-T fuel |
| `rf-helium-3` | aneutronic fuel |
| `rf-d-t-mix` | the D-T reactor's working fluid |
| `rf-d-he3-mix` | the D-He3 reactor's working fluid |
| `rf-d-t-plasma` | D-T plasma |
| `rf-d-he3-plasma` | D-He3 plasma |
| `rf-he3-he3-plasma` | He3-He3 plasma |
| `rf-reactor-energy` | what the neutronic reactor sells |
| `rf-aneutronic-reactor-energy` | what the aneutronic reactor sells |

**Four items and thirteen recipes** with them. The items are the `-barrel` items for the four
barrelled fluids above. The recipes are **both halves** of each of those four barrels — the
`rf-<fluid>-barrel` fill and the `empty-rf-<fluid>-barrel` empty, eight in all — plus the five that
make the plasmas and the mixes: `rf-d-t-plasma`, `rf-d-he3-plasma`, `rf-he3-he3-plasma`,
`rf-d-t-mixing`, `rf-d-he3-mixing`.

> **A first version of this note said four items and NINE recipes, and 22 rather than 26.** The probe
> filtered on the `rf-` prefix alone, and base Factorio names the empty half `empty-rf-<fluid>-barrel`
> — ours by consequence rather than by choice, which `name-check.ps1` already handles under
> `$DERIVED` and this probe did not. So the four empty halves were invisible to it: neither counted
> as hidden nor as absent. **The contradiction is what found it** — the same note said the Angel's
> sweep hides *both* barrel recipes while its own count held only the fills, and both could not be
> true. Fixed in the probe, re-run over all eleven lanes, and the numbers here are the second run's.

**The visible eight are the Core fuel chain plus `rf-d-d-plasma`** — `rf-brine`,
`rf-depleted-water`, `rf-deuterium`, `rf-heavy-water`, `rf-hydrogen`, `rf-hydrogen-sulfide`,
`rf-lithium-solution`, `rf-d-d-plasma`. So on that lane a player can see the whole route up to the
D-D reactor and nothing above it, and cannot see what either reactor sells.

## It is not us

This repository sets `hidden` in exactly one place: `combinator.hidden` in
`realistic-fusion-refreshed/prototypes/signals.lua`, which is
[ADR 0012](../adr/0012-reactor-signals-need-a-companion-entity.md)'s companion entity. No fluid,
item or recipe of ours sets the field.

**Thirty prototypes of ours are already hidden before any set loads**, and none of them is this. They
are all `rf-*-recycling` recipes that the **quality** mod generates from our machines and hides
itself; they appear only because this measurement passes `-With quality`. The probe subtracts them,
so a prototype hidden on both sides is never reported as a set's doing.

## Which mod does it is still unknown

**The dump cannot answer it.** It records what a prototype ended up as, never who wrote it. Two leads
from reading the cached set by hand, neither of which closes the question:

- **The barrel recipes have a named mechanism.** `angelsmods.functions.modify_barreling_recipes()` in
  `angelsrefining`, called from that mod's `data-final-fixes.lua`, loops over **every** fluid in
  `data.raw.fluid` and, when `angelsmods.trigger.enable_auto_barreling` is set, hides both barrel
  recipes and re-categorises them to `angels-barreling-pump`. That is a blanket pass over the whole
  game rather than anything aimed at us. It explains the hidden **barrel recipes**. It does not
  explain the hidden **fluids**.
- **No `hidden = true` assignment onto a fluid appears anywhere in the set's Lua** on a plain grep,
  so whatever sets it is indirect — a helper, a table-driven override, or a loop whose target is not
  written literally. `angelsmods.functions.hide(...)` is the obvious thing to chase next.

### Two mechanisms ruled out by measurement

Recorded so nobody re-tests them.

- **Not `auto_barrel`.** `rf-d-d-plasma` declares `auto_barrel = false` and stays **visible**;
  `rf-tritium` declares none and is **hidden**.
- **Not "has no enabled producer".** **Every one of our seventeen fluids has zero enabled producing
  recipes on that lane**, and only nine are hidden. Reachability alone cannot be the rule.

One correlation survives and nothing has broken it: every hidden fluid has **at most one** recipe
producing it and every visible one has **at least two**, with `rf-d-d-plasma` the single exception at
one producer and visible. A lead, not a mechanism.

## Why neither gate sees it

This is [ADR 0007](../adr/0007-coexistence-without-integration.md)'s **finding 4** exactly.
`name-check` compares content only for prototypes present in *both* dumps, and a prototype of ours is
by construction in one. `load-check` asserts validity, assets, the simulation's invariants and — since
[#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209) — that containment survived
the load; a hidden fluid breaks none of them.

So the finding had no repeatable instrument until this probe, the same gap
[`connection-categories-by-lane.md`](connection-categories-by-lane.md) and its probe were written to
fill for connection categories. **This probe is not a gate either**, and deliberately: turning it into
one would decide that a set hiding our fluids is a failure, which is the open question rather than the
answer.

## What is not decided

**Whether this repository should do anything about it.** That is a coexistence decision and Truls's,
not this note's. [ADR 0007](../adr/0007-coexistence-without-integration.md) finding 4 is the frame and
[#153](https://github.com/trulsjo/realistic-fusion-refreshed/issues/153) is the nearest precedent — it
settled two comparable cases **by letting them go**, on the grounds that a machine inheriting an
overhaul's pollution rate is "coexistence working rather than coexistence failing".

Both readings have something to stand on, and this note takes neither.

- **For treating it as a defect:** #153's cases were *inherited* stats on prototypes cloned from
  vanilla, where `hidden` here is a set editing a prototype that is wholly ours; and the effect is
  player-visible rather than a cost number.
- **For letting it go:** whatever sets the field is a blanket pass over `data.raw` rather than
  anything aimed at us — the one mechanism that *has* been identified, Angel's barrelling sweep,
  touches every fluid in the game — which is the same shape ADR 0007 already accepts, and it is one
  lane of eleven. A player who installs a 46-mod overhaul has accepted that it rearranges what the
  crafting UI shows.

**Nothing in this note is a recommendation.** It says what eleven lanes do.

## Sources

`scripts/probe-hidden-prototypes.ps1`, run 2026-09-12 with `-With quality -KeepTemp` against Factorio
2.0.77 (build 84539) on Windows, over the eleven lanes cached by `scripts/fetch-mods.ps1` at the
ADR 0026 pins. **Every figure here is the SECOND run of that day**, after the derived-barrel blindness
above was fixed; the first run's 22 is superseded and no number from it survives in this note. The
`seablock` fluid reading reproduces the one taken by hand on 2026-09-11 from a
`name-check.ps1 -AlsoModDirectory .mod-cache/seablock -With quality -KeepTemp` dump, fluid for fluid —
that hand reading looked at fluids only, so it could not have caught the missing recipes either.

The Angel's barrelling mechanism is read from `angelsrefining`'s own Lua in `.mod-cache/seablock`,
which is that mod's source at its pinned version and is not this repository's to ship — see
[ADR 0001](../adr/0001-liftable-predecessor-material.md).
