# Does a mod set reassign a connection category on a prototype of ours?

Evidence for [#206](https://github.com/trulsjo/realistic-fusion-refreshed/issues/206), which the
[code review of PR #205](https://github.com/trulsjo/realistic-fusion-refreshed/pull/205#issuecomment-5485579064)
opened by finding that PR's central claim false. **Nothing here decides anything.** What to do about
it is [#208](https://github.com/trulsjo/realistic-fusion-refreshed/issues/208) and Truls's call, and
the gate that would catch the class is
[#209](https://github.com/trulsjo/realistic-fusion-refreshed/issues/209).
[#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207) has since swept all fourteen
lanes and this one is the only one that changes a category of ours —
[`connection-categories-by-lane.md`](connection-categories-by-lane.md).

Measured on **2026-09-01** against **Factorio 2.0.77** (file version 2.0.77.84539) by
`scripts/probe-connection-categories.ps1`, on the `seablock` lane — 46 mods from
`scripts/fetch-mods.ps1 -Set seablock`, `-With quality`, the lane as ADR 0007 runs it. The mod under
suspicion is **`no-pipe-touching` 1.1.28**. The script is committed rather than the numbers alone,
because these are facts about a version of an engine and of somebody else's mod, and the next version
of either is entitled to different ones.

## The answer in one line

**Yes. Reproduced, not refuted.** `rf-pipe-to-ground`'s **underground** connection is declared
`rf-plasma` by our data stage and reads **`pipe-to-ground`** once the set is loaded — the category is
gone, not widened. The source reading in `prototypes/entities.lua` was right in every particular,
including which connection and which literal.

The same prototype's **surface** connection is a second finding the ticket predicted and it is not
the same one: `rf-plasma` survives there, with **twelve** further categories appended beside it —
vanilla `pipe`, the bare name `rf-pipe`, and ten of Bob's.

**Containment holds on the other twelve, but none of the fourteen was left alone.** The mod rewrites
the field in place on every contained connection it inspects — bare string `"rf-plasma"` to
one-element list `["rf-plasma"]` — which is the same category to the engine and no change at all to
what connects. Twelve come out set-identical. Saying they were "untouched" would be wrong, and the
difference is measured below rather than assumed.

## What the probe measured

Two `--dump-data` runs and a difference between them: our three mods alone (**declared** — what our
own data stage sets, read from the game rather than from the Lua), then the same three with the 46
junctioned in beside them (**loaded**). Every object holding a `pipe_connections` array is walked
wherever it sits, so a box nested in an `energy_source` or in a `fluid_boxes` list is read like any
other.

**58 connections across 17 prototypes of ours**, of which **14 carry `rf-plasma`**:

| Prototype | Connections | Contained | Where |
|---|---|---|---|
| `pipe/rf-pipe` | 4 | **4** | `fluid_box`, all four |
| `pipe-to-ground/rf-pipe-to-ground` | 2 | **2** | `fluid_box`, surface and underground |
| `pump/rf-pump` | 2 | **2** | `fluid_box`, both |
| `boiler/rf-reactor` | 3 | **2** | `fluid_box` — the plasma intake |
| `boiler/rf-aneutronic-reactor` | 3 | **2** | `fluid_box` — the same |
| `assembling-machine/rf-heater` | 4 | **2** | `fluid_boxes[3]`, `[4]` — the output boxes |
| eleven others | 40 | 0 | ordinary boxes, contained by nothing |

**46 differences**, and they are three findings rather than one.

## Finding 1 — one contained connection LOST its category

```
pipe-to-ground/rf-pipe-to-ground  .fluid_box.pipe_connections[2]  [underground]
  declared: rf-plasma
  loaded:   pipe-to-ground
```

A bare string, not a list: the value was **overwritten**, so nothing of `rf-plasma` remains on that
connection. `pipe-to-ground` is the category `no-pipe-touching` gives vanilla's own underground pipe,
which is the point — the two now match.

**What that means for the guarantee.** `prototypes/entities.lua` puts the category on *both* of this
entity's connections deliberately, *"so a vanilla pipe-to-ground cannot tunnel into a plasma line from
out of sight"*. On this lane it can. The tunnel is exactly the case the comment names, and it is the
half a player cannot see.

**How it qualified.** `no-pipe-touching`'s `data-final-fixes.lua:216` fires for a `pipe-to-ground`
prototype that is not `solved_by_npt`, carries no `npt_compat`, and holds **no default category on any
connection** — and `:225` then writes the literal over every connection whose `connection_type` is
`underground`. Containment is what removes the default category, so **the guard is satisfied by the
protection itself.** The more thoroughly a box is contained, the more certainly this pass claims it.

Two links in that chain are worth stating because they are what makes it fire rather than not:

- `rf-pipe-to-ground` is never marked `solved_by_npt`. The earlier pass at `:157-158` would have
  marked it — it strips `-to-ground` and looks for the matching `data.raw.pipe` entry, which is `rf-pipe` and
  exists — but that pass is inside a branch guarded on `rf-pipe` holding a default category, and
  `rf-pipe` holds `rf-plasma` on all four connections. **`rf-pipe`'s own containment is what lets the
  later pass reach its underground sibling.**
- Nothing of ours declares `npt_compat`, which is the mod's documented opt-out.

## Finding 2 — one contained connection was WIDENED, which is also a breach

```
pipe-to-ground/rf-pipe-to-ground  .fluid_box.pipe_connections[1]  [normal]
  declared: rf-plasma
  loaded:   {rf-plasma, pipe, rf-pipe, bob-copper-pipe, bob-steel-pipe, bob-plastic-pipe,
             bob-bronze-pipe, bob-aluminium-pipe, bob-brass-pipe, bob-titanium-pipe,
             bob-tungsten-pipe, bob-copper-tungsten-pipe, bob-ceramic-pipe}
```

`rf-plasma` is still there, and **the connection is open anyway.** A connection category is a
whitelist: adding to one we wrote lets everything added connect. Vanilla `pipe` and ten of Bob's now
join our pipe-to-ground's surface connection, and plasma crosses into whichever of them a player lays
beside it.

Calling this the milder half would be the mistake #206 exists to prevent. It is the *same* breach
reached by the opposite edit — the underground connection was captured by having its category
replaced, the surface one by having everything else added to it — and both come from the same
`:216` branch, at `:220-223`.

`rf-pipe` appearing in that list is the bare **name** of our pipe prototype, collected because the
mod takes the name of every `data.raw.pipe` entry it processes. ADR 0007's finding 2 already records
the same shape landing on vanilla `infinity-pipe`, and
[#195](https://github.com/trulsjo/realistic-fusion-refreshed/issues/195) declined to suppress it.

## Finding 3 — 44 differences on connections we never contained

Every remaining row is `no-pipe-touching` appending its collected pipe names to a connection of ours
that held `default`:

```
assembling-machine/rf-brine-concentrator  .fluid_boxes[1].pipe_connections[1]  [normal]
  declared: default (no field)
  loaded:   {default, pipe, bob-copper-pipe, ... bob-ceramic-pipe}
```

**This is not a containment finding and the probe does not print it as one.** `default` is kept in
every one of the 44, so an ordinary pipe still connects; what changed is that Bob's pipes now do too,
which is the whole purpose of the mod a player installed. These boxes carry water, deuterium, steam
and reactor energy through ordinary plumbing on purpose.

It is reported rather than filtered because the count is worth reading — a jump in it means the set
started doing something new to us — and it is sorted last because 44 rows of it would otherwise bury
the two above.

## What survived, stated exactly

**Twelve of the fourteen contained connections keep the category set our data stage declared** —
`rf-pipe` (4), `rf-pump` (2), `rf-reactor` (2), `rf-aneutronic-reactor` (2) and `rf-heater`'s two
output boxes. Containment holds on all twelve.

**All twelve were nevertheless rewritten**, and the probe reports no row for it because the rewrite
is a no-op:

| Connection | declared | loaded |
|---|---|---|
| `pipe/rf-pipe` × 4 | `"rf-plasma"` | `["rf-plasma"]` |
| `pump/rf-pump` × 2 | `"rf-plasma"` | `["rf-plasma"]` |
| `boiler/rf-reactor` × 2 | `"rf-plasma"` | `["rf-plasma"]` |
| `boiler/rf-aneutronic-reactor` × 2 | `"rf-plasma"` | `["rf-plasma"]` |
| `assembling-machine/rf-heater` `fluid_boxes[3]`, `[4]` | `"rf-plasma"` | `["rf-plasma"]` |

`contain()` writes the bare string; `no-pipe-touching`'s `has_default_category`
(`data-final-fixes.lua:14`) assigns `unify(connection_category)` back to the field on **every
connection it merely inspects**, including the ones it then decides to leave alone. A bare string and
a one-element list are the same category to the engine, so nothing about what connects changes. **The
probe compares category sets rather than the printed form for exactly this reason** — comparing text
would file all twelve under WIDENED, reporting a box as opened with nothing added to it.

Two things follow. First, **the mod reaches inside all fourteen**, so "it does not touch our
contained boxes" is not what the evidence says; what it says is that twelve rewrites are equivalent.
Second, the breach is **not** general to containment: it is one pass over one prototype type.
`no-pipe-touching` walks `data.raw.pipe` and `data.raw["pipe-to-ground"]` in separate loops with
separate guards, and only the second has a branch that fires on the *absence* of a default category.

That is the difference between "a set can take a category away" and "this set takes this category
away". The first is what #209 has to be built for; the second is all this lane shows.

## What this does not establish

- **Nothing about the other lanes.** Thirteen more exist and none was run here; that is a separate
  ticket, which uses this probe. **Since answered:**
  [#207](https://github.com/trulsjo/realistic-fusion-refreshed/issues/207) swept all fourteen on
  the same day and this lane is the only one that changes a contained connection — see
  [`connection-categories-by-lane.md`](connection-categories-by-lane.md).
- **Nothing about the runtime consequence.** The probe reads prototypes. Nobody has built a
  pipe-to-ground beside a plasma line on this lane and watched plasma cross. The category is the
  mechanism and the dump is where it lives, so this is the right place to measure it — but "the
  declaration is gone" and "the plasma moves" are two claims and only the first is measured.
- **Nothing about which fix is right.** Four shapes exist at least — declare `npt_compat`, keep a
  second category nothing buildable carries (which is how Wube's own `fusion-plasma` handles the
  editor pipe, ADR 0018), re-assert containment in a `data-final-fixes` of our own, or accept the
  lane as red. Choosing is #208's and Truls's.
- **Nothing about how the probe behaves on a set that changes nothing.** It has been run on one lane.
  Its floor asserts the instrument is reading containment at all — 14 connections on the declared
  side — which is what rules out a clean report caused by a broken walk. **Since answered:** #207 ran
  it on fourteen lanes and **eleven report no difference at all**, so the quiet case is now measured
  rather than assumed.

## One thing the instrument got wrong first, since it bears on trusting the counts

The first working version of the probe read the category with
`$category = if ($field) { $connection.connection_category }`. An `if` used as an expression sends
its block's output to the pipeline, and **a one-element array sent to the pipeline arrives as its
element** — so `["rf-plasma"]` was read as `"rf-plasma"` and the probe could not tell a list from a
string at all. It reported the same 46 differences it reports now, for the wrong reason: the twelve
in-place rewrites were invisible rather than judged equivalent.

Caught by `/code-review`, which reasoned from the mod's source that twelve rows were missing, and
settled by reading the two kept dumps directly — the reassuring half of this note's conclusion is the
half most worth distrusting, so it is the half that got checked against the JSON rather than against
the report. The count is unchanged; what changed is that the probe now sees what it is dismissing.
