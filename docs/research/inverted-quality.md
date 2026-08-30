# Inverted Quality, and why it cannot share a game with the vanilla tiers

Researched 2026-08-30, exploratory. **Nothing here is proposed for this mod.** It answers one
question asked for future reference: the mod portal's *Inverted Quality* inverts the quality system
into tiers *below* normal, its author says the positive tiers are removed, and the question was
whether both directions could coexist — perhaps by changing the level of `normal`.

The answer is no on 2.0, for three reasons of very different hardness, and the level of `normal` is
not one of them. Factorio 2.1 adds the missing mechanism but in a different shape.

**Nothing is lifted from this mod.** Its source is GPLv3 and was read, not copied.

That distinction is not covered by anything the repository has decided.
[ADR 0001](../adr/0001-liftable-predecessor-material.md) governs the *predecessors* — Romner's
original, Durikkan's port, the four-module redesign and UFP — and Inverted Quality is none of them.
The nearest thing to a precedent is `CLAUDE.md`'s line about UFP, *"Reading its Lua for 2.0/2.1
prototype patterns is fine"*, and this note generalises that to an unrelated third-party mod on its
own authority. No rule here forbids it and none permits it either; saying so is more honest than
citing an ADR that decided a different question.

Three kinds of evidence, kept separate throughout:

- **The mod's own source**, read at
  [`danielmartin0/factorio-Inverted-Quality`](https://github.com/danielmartin0/factorio-Inverted-Quality)
  on 2026-08-30, `info.json` version **1.5.3**. The mod portal listing said **1.5.2** the same day;
  where the two could differ, this note follows the source and says so.
- **Wube's own data**, read off this machine at
  `D:\SteamLibrary\steamapps\common\Factorio\data\`, version 2.0.77.
- **Wube developer statements** on the forums, quoted with their post links.

**No game was run for this note.** Every claim below is read rather than measured, which is the
opposite of how [`quality.md`](quality.md) was produced and is worth remembering before building on
it. Where a claim could only be settled by running something, it is in
[What is not established](#what-is-not-established).

## The short version

**The blocker is `next`, not `level`.** `QualityPrototype.next` is a single link, so `normal.next` is
either `uncommon` or `shoddy` and cannot be both. Wube has said the engine assumes a linear
progression and will not gain a divergent one. Inverted Quality works by overwriting exactly the one
line that Wube's `quality` mod uses to point `normal` upward.

The level idea is sound as far as it goes — levels are free-form and the mod already shifts every one
of them — but it solves the arithmetic, not the topology, and it does not touch the second real
blocker: **no primitive that moves an item *down* a chain was found.** Degradation exists in this mod
only because the chain itself points down. That second blocker is an absence rather than a quoted
fact, and it is the softest thing this note rests on — it is qualified where it is argued.

## What the mod is

`info.json` at 1.5.3, read in full:

    "name": "Inverted-Quality",
    "author": "thesixthroc",
    "version": "1.5.3",
    "title": "Inverted Quality (Beta)",
    "factorio_version": "2.0",
    "quality_required": true,
    "dependencies": [
        "base >= 2.0.60",
        "? space-age >= 2.0.60",
        "quality >= 2.0.60",
        "PlanetsLib >= 1.4.0",
        "quality-cursor"
    ]

Note `"quality_required": true` — the same flag [`quality.md`](quality.md) found on Wube's own
`quality` mod and could not find documented anywhere. Note also that `space-age` is optional and
`quality` is not, which is the same shape ADR 0003 cares about: the mod needs the quality mechanic,
not the expansion.

The portal description, verbatim from `info.json`:

> Inverts the Quality system to negative tiers (positive tiers are removed).
>
> Crafting items has a two-thirds chance to reduce their quality by one tier. Items in the lowest tier
> are nonfunctional.
>
> The new Downgrade Port allows high-quality items to be used in low-quality recipes, and the Meltdown
> Facility allows the melting down of low-quality items back into Normal base materials.

## How it actually works

Four files do the work. None of them is what the description implies.

### It does not use negative levels at runtime

`prototypes/quality.lua` declares three new qualities with negative levels:

| name | declared `level` | `next` | `next_probability` |
|---|---|---|---|
| `shoddy` | **-1** | `defective` | 0.1 |
| `defective` | **-3** | `broken` | 0.1 |
| `broken` | **-3** | — | — |

Then `prototypes/override-final/negative-quality.lua`, at the data-final-fixes stage, runs one line
over **every** quality in the game:

    for _, quality in pairs(data.raw.quality) do
        quality.level = quality.level + 3
    end

So the negatives are transient. They exist only between two prototype-stage files and are gone before
the stage ends. Final levels:

| quality | declared | final | visible? |
|---|---|---|---|
| `broken` | -3 | **0** | yes |
| `defective` | -3 | **0** | yes |
| `shoddy` | -1 | **2** | yes |
| `normal` | 0 | **3** | yes |
| `uncommon` | 1 | 4 | `hidden` |
| `rare` | 2 | 5 | `hidden` |
| `epic` | 3 | 6 | `hidden` |
| `legendary` | 5 | 8 | `hidden` |

**This is not evidence that the engine accepts a negative level.**
[`QualityPrototype.level`](https://lua-api.factorio.com/2.0.77/prototypes/QualityPrototype.html) at
2.0.77 is declared `uint32`, and no negative value survives to be loaded. Anyone reading the mod's
tier list — "Shoddy (-1), Defective (-2), Broken (-3)" — as proof that negative levels work has read
the description rather than the source.

**`defective` and `broken` both land at level 0**, while the portal description numbers them -2 and
-3. Read from source at 1.5.3; whether that is deliberate (a nonfunctional tier's multiplier strength
does not matter) or a slip was not established.

### The chain flip is a single line, overwriting a single line

Wube's `quality` mod, `data/quality/prototypes/base-data-updates.lua`, **line 1 of the file**:

    data.raw.quality.normal.next = "uncommon"

Inverted Quality's `prototypes/override/quality.lua`:

    data.raw.quality.normal.next = "shoddy"

    for name, quality in pairs(data.raw.quality) do
        if quality.level and quality.level > 0 then
            quality.hidden = true
        end
    end

That is the whole inversion. The positive tiers are **not removed** — they are orphaned, because
nothing points `next` at them any more, and then hidden. The description's "positive tiers are
removed" describes the player's experience, not the prototype set.

`normal` itself is defined once in the game, in `base/prototypes/categories/quality.lua`, with
`level = 0`, `next_probability = 0.1`, no `next`, and `hidden = true`. The `quality` mod only mutates
it: `data-updates.lua:27` unhides it, `base-data-updates.lua:1` gives it a `next`. Searched across
`core`, `base` and `quality` on 2.0.77 — there is no second definition.

### Every base stat in the game is rewritten

This is the part that does not fit in a sentence, and the part that makes coexistence a losing
proposition regardless of the chain.

`negative-quality.lua` sets `QUALITY_LEVELS_TO_UNDO = 3` and walks the whole of `data.raw`, dividing
each quality-affected value by `1 + 0.3 × 3 = 1.9` — with per-property rules for the ones that do not
use the default bonus. Its own table names them, and it is a useful cross-check on
[`quality.md`](quality.md)'s account of what quality touches: `max_health`, `crafting_speed`,
roboport `robot_slots_count` / `robot_limit` / `charging_energy`, module `effect` sub-fields,
`attack_parameters.range`, electric-pole `supply_area_distance` / `maximum_wire_distance`,
equipment-grid `width` / `height`, container `inventory_size`, `ammo_type` damage, inserter
`rotation_speed`, solar-panel `production`, accumulator flow limits and `buffer_capacity`, boiler
`energy_consumption`, generator `fluid_usage_per_tick`, reactor `consumption`, lightning-attractor
`efficiency`, radar reveal distances, tool `durability`, sticker `duration_in_ticks`, plus
special-cased blocks for `chain-active-trigger` fork chance and `asteroid-collector`.

Two things follow that matter more than the list.

**It confirms from a second source what `quality.md` had to measure.** Boilers and generators are in
that table — `energy_consumption` for `boiler`, `fluid_usage_per_tick` for `generator` — with a plain
`relative = 0.3`. Neither prototype declares a quality field at 2.0.77. A working mod treating them as
default-scaled is independent agreement with the rig's numbers.

**It is a whole-game rewrite, so it composes with nothing.** Restoring the positive tiers on top of a
`data.raw` already divided by 1.9 double-counts every number in the game, in every other mod's
prototypes too.

### Degradation is an inherent quality effect, not a script

`prototypes/override-final/base-quality.lua` gives every `assembling-machine`, `rocket-silo` and `lab`
a built-in quality effect from a startup setting:

    e.effect_receiver.base_effect.quality =
        degradation_chance * 10 - (e.effect_receiver.base_effect.quality or 0)

So crafting rolls toward `next` with no modules installed, and `next` points down. The `* 10` matches
2.1's rescale of quality effect values.

The file also carries a commented-out line setting `base_effect.quality = -100` for the mod's own two
machines. **A negative quality effect is therefore expressible and the author chose not to ship it** —
which is a hint about what it does, not an answer.

## Why the two directions cannot coexist

Three blockers, hardest first.

### 1. `next` is one link, and the engine assumes linearity

boskid (Factorio Staff), on
[QualityPrototype extended](https://forums.factorio.com/viewtopic.php?p=675908):

> There will not be a divergent behavior [...] There are some places where game straight assumes the
> quality progression is linear.

Cycles are detected and rejected; branching and converging paths are not supported. `normal.next` is
`uncommon` or `shoddy`, never both.

A **single** eight-tier chain — `broken → defective → shoddy → normal → uncommon → rare → epic →
legendary` — is linear and so is not blocked by this. It is blocked by the next one.

### 2. Nothing moves an item down a chain

A quality effect moves an item toward `next`. **No opposite was found**, and every mechanism this
pass identified moves in that one direction: Inverted Quality gets degradation only by pointing the
chain downward from the base tier, which is what a mod would not need to do if a downward roll
existed. On a merged eight-tier chain, every machine's quality effect would push toward `legendary`
and nothing would ever reach `shoddy`.

**This is weaker than blockers 1 and 3, and deliberately so.** Those two are read off a developer
statement and off the mod's own code. This one is an absence — no 2.0.77 doc page or prototype field
found in this pass provides a downward move, and the closest candidate is untested: Inverted Quality
ships a **commented-out** `base_effect.quality = -100`, so a negative quality effect is expressible
and nobody here has run it. See [What is not established](#what-is-not-established). If that negative
value turns out to walk an item down the chain, this blocker weakens and the question is worth
reopening — blockers 1 and 3 would still stand.

Subject to that, this is the blocker the level idea does not touch, and the one that decides the
question on 2.0.

### 3. The stat rewrite is global

See above. The two schemes cannot both own the base numbers.

## On changing the level of `normal`

The idea is sound arithmetic and is already what the mod does. boskid, on
[[2.1.14] LuaQualityPrototype levels are inconsistent](https://forums.factorio.com/viewtopic.php?p=702176):

> level is not an index, it sets strength of various modifiers. It is not required to be continuous or
> 0 or 1 based.

That settles it as far as it goes: levels are free-form multiplier strengths, gaps are legal —
vanilla itself skips 4 — and a chain anchoring `normal` at 3 is expressible. Inverted Quality proves
it by shipping one.

What it does not do is create a downward mechanism, and it does not make two chains one. So it solves
the third of the problem that was never the hard part.

## The 2.1 route, and why it is a different feature

Factorio 2.1 adds the missing direction, deterministically rather than probabilistically. From
[Version history/2.1.0](https://wiki.factorio.com/Version_history/2.1.0):

- `ItemProductPrototype` gained minimum/maximum quality and quality-change fields, plus
  `affected_by_quality`.
- Recipe **ingredients** gained quality specifications.
- `RecipePrototype` gained `can_set_quality`.
- Quality effect values in prototype definitions were **divided by 10**, and `next_probability` values
  **multiplied by 10** — so a 100% quality effect now guarantees an increase.

[Quality Down-Binning](https://forums.factorio.com/viewtopic.php?p=696587) uses these to generate
recycling-like downgrade recipes for every item and every target level, and its thread reports the mod
working against 98 custom quality tiers.

So a both-directions game on 2.1 looks like: **modules climb the chain, and dedicated downgrade
machines descend it by recipe.** That is not "crafting has a 2/3 chance to degrade" — it is a
deterministic, machine-mediated downgrade. It answers a different question than the one Inverted
Quality answers.

**This repository targets 2.0.77** (`CLAUDE.md`), so none of the 2.1 route is available to it today.

## What this changes for this repository

**Nothing operational.** Quality reaches this mod only through `rf-` entity stats, and
[`quality.md`](quality.md) already measured that every quantity the simulation holds constant is flat
across all five levels. Inverted Quality is not a coexistence target under
[ADR 0007](../adr/0007-coexistence-without-integration.md) and is not proposed as one.

**One gap in `quality.md` narrows, with weaker evidence than that note's usual standard.** It says:

> Whether a mod may add a *sixth* grade was not established. [...] **Not verified. Do not build on it.**

A mod that ships three extra grades, and a mod-portal thread reporting 98 of them, are evidence that
mods may define extra quality prototypes. It is **read** evidence — a working mod and a forum report —
not a measurement on this machine, and it says nothing about what happens to *this* mod's entities at
a sixth grade. The caveat in `quality.md` is narrowed, not removed.

## What is not established

- **How the engine picks the base quality of a newly produced item** — by the name `normal`, or by the
  root of the chain. Circumstantial only: `normal` is defined in `base` rather than in the `quality`
  mod, so it exists in every game; Inverted Quality keeps the name and moves levels around it rather
  than renaming; and normal is
  [special-cased in rendering](https://forums.factorio.com/viewtopic.php?p=669853). No 2.0.77 doc page
  found in this pass states it. This is the load-bearing unknown for anyone who wants to try the
  single-chain design.
- **Whether a negative `base_effect.quality` moves an item down a chain.** Expressible, shipped
  commented-out, untested here. **Blocker 2 rests on this being no**, which is why that blocker is
  the softest of the three; settling it would need a game, and no game was run for this note.
- **Whether `defective` and `broken` sharing level 0 is deliberate.**
- **Everything about 2.1**, which was read from the wiki changelog and a forum thread, not from an
  installed build. This repository has no 2.1 to check against.

## Sources

- [Inverted Quality on the mod portal](https://mods.factorio.com/mod/Inverted-Quality) — listing 1.5.2, GPLv3
- [Source repository](https://github.com/danielmartin0/factorio-Inverted-Quality) — read at 1.5.3
- [`QualityPrototype`, 2.0.77](https://lua-api.factorio.com/2.0.77/prototypes/QualityPrototype.html)
- [QualityPrototype extended](https://forums.factorio.com/viewtopic.php?p=675908) — boskid on linearity
- [[2.1.14] LuaQualityPrototype levels are inconsistent](https://forums.factorio.com/viewtopic.php?p=702176) — boskid on what `level` is
- [Hardcoded / weird processing of 'normal' quality](https://forums.factorio.com/viewtopic.php?p=669853)
- [[MOD 2.1] Quality Down-Binning](https://forums.factorio.com/viewtopic.php?p=696587)
- [Version history/2.1.0](https://wiki.factorio.com/Version_history/2.1.0)
- Factorio 2.0.77 data: `base/prototypes/categories/quality.lua`, `quality/prototypes/quality.lua`,
  `quality/prototypes/base-data-updates.lua`, `quality/data-updates.lua`, `core/prototypes/unknown.lua`
