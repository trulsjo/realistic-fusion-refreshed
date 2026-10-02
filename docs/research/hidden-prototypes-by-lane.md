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

## Which mod does it: SeaBlockWanne's reachability walk

**Answered by reading on 2026-10-02**, against the `seablock` set at its pins — `SeaBlockWanne`
**1.0.5** ("SeaBlock 2", by wanne and Yess, AGPLv3) and `angelsrefining` **2.0.4** — and checked
against the 2026-09-12 measurement above rather than by a new run. No probe was re-run.

**All twenty-six come from one pass**: `SeaBlockWanne/data-final-fixes.lua`, under its `--Gui cleanup`
comment. It is a reachability walk over the **recipe graph**, and it is written for SeaBlock's own
premise — a map with no ores — rather than for any other mod:

1. **Seeds** (lines 30-43): `steam`, `angels-water-viscous-mud`, every fluid a tile offers (`water`
   and friends), and whatever fish and trees mine to.
2. **`check_recipes()`** (lines 48-71), looped until nothing changes (lines 96-99): any recipe whose
   ingredients are **all** already reached adds its results to the reached set. It looks at
   ingredients and results only — never at `enabled`, a technology, a category or an entity.
3. **`hide_items("item", …)` and `hide_items("fluid", …)`** (lines 86-94, called at 100-101) set
   `hidden = true` on every item and every fluid not reached — `itm.hidden=true` at line 91, which is
   why a grep for a literal assignment *onto a fluid* found nothing: the fluid is a loop variable.
4. **`hide_recipes()`** (lines 73-84, called at 102) hides every recipe with any unreached ingredient
   — `rec.hidden = true` at line 81.

**It is general, not aimed at us.** The file names no prototype of ours — no `rf-`, no "fusion" —
and iterates the whole of `data.raw.item`, `data.raw.fluid` and `data.raw.recipe`. The rule it
applies is "no recipe chain from water, fish or trees makes this", and that hides any mod's fluid made
by an entity or a script rather than by a recipe. The `steam` seed is the tell: steam is made by a
boiler, not a recipe, so the walk would hide it too, and the author special-cased the one vanilla
fluid that needed it. Nothing in the file special-cases anything else's.

**Why exactly our nine.** Four of our fluids are never the result of any recipe: `rf-tritium` and
`rf-helium-3` are bred by script (`realistic-fusion-refreshed/control.lua`, into the isotope
collector's fluid boxes), and `rf-reactor-energy` and `rf-aneutronic-reactor-energy` are written by
the reactor logic (`energy_fluid` in `realistic-fusion-refreshed/scripts/reactor-logic.lua`). The
walk cannot reach any of them, so it cannot reach anything made from them either:

| hidden | why the walk never reaches it |
|---|---|
| `rf-tritium`, `rf-helium-3` | no recipe makes them — bred by script |
| `rf-reactor-energy`, `rf-aneutronic-reactor-energy` | no recipe makes them — written by the reactor |
| `rf-d-t-mix` | its only recipe, `rf-d-t-mixing`, needs `rf-tritium` |
| `rf-d-he3-mix` | its only recipe, `rf-d-he3-mixing`, needs `rf-helium-3` |
| `rf-d-t-plasma` | its only recipe needs `rf-d-t-mix` |
| `rf-d-he3-plasma` | its only recipe needs `rf-d-he3-mix` |
| `rf-he3-he3-plasma` | its only recipe needs `rf-helium-3` |

The four barrel items fall to the same `hide_items` call — a barrel's only maker is its fill recipe,
which needs the unreached fluid. The thirteen recipes fall to `hide_recipes()`: the five above each
take an unreached fluid, the four fills take an unreached fluid and the four empties take an
unreached barrel. That is twenty-six, the measured figure, with nothing left over in either
direction.

**`rf-d-d-plasma` is explained.** Its one recipe, `rf-d-d-plasma`, takes only `rf-deuterium`, which
the walk reaches from `water` through `rf-heavy-water`. So the walk reaches it, and the Core chain,
the same way. The "at most one producer" correlation below was a coincidence of our chain's shape:
the count of producers is not what the walk reads — whether any one of them has every ingredient
reached is.

### The barrel lead was wrong at the measured settings

**The note used to say Angel's barrelling sweep explains the hidden barrel recipes.** It does not
on the lane as measured. `angelsmods.functions.modify_barreling_recipes()` hides barrel recipes only
inside `if angelsmods.trigger.enable_auto_barreling` (`angelsrefining/prototypes/angels-functions.lua`
lines 1603-1611), and `angelsrefining/data.lua` line 39 sets that trigger only when the startup
setting `angels-enable-auto-barreling` is `Enabled+Hidden` or `Enabled+Shown`. Its default is
`Disabled` (`angelsrefining/settings.lua` line 14), no other mod in the set names the setting, and
the probe sets no mod settings. The giveaway was there to read: had the sweep fired, it would hide
the barrel recipes of **every** barrelled fluid, the seven visible Core fluids' included, and the measurement
hides only four pairs.

The other passes in the set that loop over `data.raw.fluid` were read for the same reason and set no
`hidden` on a fluid: `angelsrefining/data-final-fixes.lua` (barrel recipes of `auto_barrel = false`
fluids), `angelsrefining/prototypes/refining-override.lua` (barrel recipe categories) and
`bobplates/data-final-fixes.lua` (barrel recipe colours).

### Two mechanisms ruled out by measurement

Recorded so nobody re-tests them.

- **Not `auto_barrel`.** `rf-d-d-plasma` declares `auto_barrel = false` and stays **visible**;
  `rf-tritium` declares none and is **hidden**.
- **Not "has no enabled producer".** **Every one of our seventeen fluids has zero enabled producing
  recipes on that lane**, and only nine are hidden. Reachability over *enabled* recipes cannot be the
  rule — and it is not: the walk above ignores `enabled` entirely.

The correlation this section used to carry — every hidden fluid has **at most one** producing recipe
and every visible one **at least two**, with `rf-d-d-plasma` the exception — is superseded by the
walk, which explains the exception.

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
  player-visible rather than a cost number. And the walk's premise is false for these nine: they
  are made in play, by an entity or a script rather than a recipe, so what it hides is a chain a
  player can build.
- **For letting it go:** whatever sets the field is a blanket pass over `data.raw` rather than
  anything aimed at us — SeaBlockWanne's reachability walk, identified above, iterates every
  item, fluid and recipe in the game and names none of ours — which is the same shape ADR 0007
  already accepts, and it is one lane of eleven. A player who installs a 46-mod overhaul has accepted that it rearranges what the
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

The mechanism is read, on 2026-10-02, from `SeaBlockWanne`'s and `angelsrefining`'s own Lua in
`.mod-cache/seablock`, which is those mods' source at their pinned versions and is not this
repository's to ship — see [ADR 0001](../adr/0001-liftable-predecessor-material.md).
