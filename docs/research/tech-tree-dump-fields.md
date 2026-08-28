# What the 2.0.77 dumps give a tech-tree viewer

Researched 2026-08-28 ([#159](https://github.com/trulsjo/realistic-fusion-refreshed/issues/159)).
**Every API claim is pinned to Factorio 2.0.77**, read at `https://lua-api.factorio.com/2.0.77/`
rather than at `/stable/` or `/latest/`, both of which move. This records what `--dump-data` and
`--dump-prototype-locale` actually provide for a tool that renders a tech tree — science-pack costs,
prerequisites, unlocks, localized names. It states facts and makes no design decisions.

Two kinds of evidence, kept separate throughout:

- **The prototype docs at 2.0.77**, quoted, with URLs.
- **A real dump**, produced 2026-08-28 with Factorio 2.0.77 (build 84539, win64, steam) via
  `Invoke-Factorio` from `scripts/factorio-lib.ps1`, the same way `name-check.ps1` and
  `locale-check.ps1` produce theirs. **Mod list for every observation below:** `base` 2.0.77 plus
  this repo's three mods junctioned from the working tree —
  `realistic-fusion-refreshed-assets` 0.1.0, `realistic-fusion-refreshed-core` 0.1.0,
  `realistic-fusion-refreshed` 0.1.0 (commit b27791c) — with the bundled `elevated-rails`,
  `quality` and `space-age` written explicitly disabled. Numbers like "210 technologies" are
  numbers for that mod list, not constants.

Both dumps are engine flags, one run each; the run exits after writing. `--dump-data` writes
`script-output/data-raw-dump.json` in the write-data directory: **one top-level key per prototype
type** (`technology`, `recipe`, `item`, `tool`, `fluid`, …), each an object keyed by prototype
name. `--dump-prototype-locale` writes one `script-output/<category>-locale.json` per locale
category. Prototype names are unique only **within** a type
(`https://lua-api.factorio.com/2.0.77/prototypes/PrototypeBase.html#name`).

**The dump serialises what the data stage set, not the schema.** A property left at its default is
simply absent — all 210 technologies in this dump lack the `enabled` key, and `iron-gear-wheel`
lacks `category` — so a consumer must apply the documented defaults itself, and cannot distinguish
"explicitly set to the default" from "never set".

## 1. Science packs: `unit`, `count`, `count_formula`, and `research_trigger`

`TechnologyPrototype.unit` "determines the cost in items and time of the technology", and is
optional — "mandatory if `research_trigger` is not defined"
(<https://lua-api.factorio.com/2.0.77/prototypes/TechnologyPrototype.html>). Its shape
(<https://lua-api.factorio.com/2.0.77/types/TechnologyUnit.html>):

- `count` :: uint64, optional — "How many units are needed. Must be `> 0`."
- `count_formula` :: MathExpression, optional — "Formula that specifies how many units are needed
  per level of the technology." Variables `l`/`L` are the current level. Either `count` or
  `count_formula` must be defined, never both.
- `time` :: double, required — seconds per unit in a speed-1 lab.
- `ingredients` :: array of ResearchIngredient, required — "List of ingredients needed for one unit
  of research. The items must all be ToolPrototypes."

In the dump an ingredient is a **two-element JSON array** `[name, count]`, not an object.
`technology.automation.unit` as dumped:

```json
"unit": { "count": 10, "ingredients": [["automation-science-pack", 1]], "time": 10 }
```

Science packs are ToolPrototypes, so they live under the top-level **`tool`** key of the dump, not
`item` — `data-raw-dump.json` has `automation-science-pack` in `tool` and not in `item`.

`count_formula` arrives as a plain string. Nine technologies in this dump use it, all with
`"max_level": "infinite"`: `physical-projectile-damage-7`, `stronger-explosives-7`,
`refined-flammables-7`, `laser-weapons-damage-7`, `artillery-shell-range-1`,
`artillery-shell-speed-1`, `follower-robot-count-5`, `worker-robots-speed-6`,
`mining-productivity-4`. Example: `"count_formula": "2^(L-7)*1000"` with `time: 60`. `max_level`
is otherwise absent in this dump (it can also be a number per the TechnologyPrototype page).

**Trigger technologies have no `unit` key at all.** `research_trigger` :: TechnologyTrigger is
"mandatory if `unit` is not defined" (TechnologyPrototype page). TechnologyTrigger is a union of
eight variants (<https://lua-api.factorio.com/2.0.77/types/TechnologyTrigger.html>):
`mine-entity`, `craft-item`, `craft-fluid`, `send-item-to-orbit`, `capture-spawner`,
`build-entity`, `create-space-platform`, `scripted`. Seven base-game technologies use it in this
dump, and they are exactly the seven without `unit`:

```json
"steam-power":              { "type": "craft-item", "item": "iron-plate", "count": 50 }
"electronics":              { "type": "craft-item", "item": "copper-plate", "count": 10 }
"automation-science-pack":  { "type": "craft-item", "item": "lab" }
"steel-axe":                { "type": "craft-item", "item": "steel-plate", "count": 50 }
"oil-processing":           { "type": "mine-entity", "entity": "crude-oil" }
"uranium-processing":       { "type": "mine-entity", "entity": "uranium-ore" }
"space-science-pack":       { "type": "send-item-to-orbit", "item": "satellite" }
```

`count` is omitted when it is 1. So a viewer's per-technology cost source is a three-way branch:
`unit.count`, `unit.count_formula`, or `research_trigger`.

## 2. Prerequisites and visibility flags

`prerequisites` :: array of TechnologyID, optional — "List of technologies needed to be researched
before this one can be researched" (TechnologyPrototype page). In the dump it is a **flat array of
technology-name strings** — `"logistics-2"` has `["logistics", "logistic-science-pack"]` — and the
key is **absent** when there are none (two techs here: `steam-power`, `electronics`).

The flags, from the same page, all booleans:

- `enabled`, default `true` — "This can be `false` to disable the technology at the start of the
  game".
- `hidden`, default `false` — "Hides the technology from the tech screen".
- `visible_when_disabled`, default `false` — "Controls whether the technology is shown in the tech
  GUI when it is not `enabled`".
- `essential`, default `false` — shown in the GUI's "essential" filtered view. 8 techs set it here.
- `upgrade`, default `false` — multi-level display behaviour. 88 techs set it here.

**Under this mod list, none of the 210 technologies sets `enabled`, `hidden` or
`visible_when_disabled`**, so every tech in the dump is a renderable tech and the keys simply do
not appear. The flags appear in the dump only when a mod sets them, so a consumer that wants the
game's visibility rule must treat a missing key as the documented default: not researchable when
`enabled` is `false`, invisible when `hidden`, and visible-but-disabled only with
`visible_when_disabled`.

What *does* exist in data.raw and is not a real subject for display, in this dump, lives in other
types: the engine's placeholder and parameter prototypes. `recipe` contains `recipe-unknown`
(`"hidden": true`, empty `ingredients`/`results`) and `parameter-0` … `parameter-9`
(`"parameter": true`, no results); `fluid` contains `fluid-unknown` and its own `parameter-0` …
`parameter-9`; `item` has ten parameter items. Four vanilla recipes besides `recipe-unknown` are
`hidden: true` (`pistol`, `loader`, `fast-loader`, `express-loader`). None of these is referenced
by any technology effect, but a tool that walks whole prototype tables will meet them.

## 3. Unlocks: effects, recipes, products, placed entities

`effects` :: array of Modifier, optional — "List of effects of the technology (applied when the
technology is researched)" (TechnologyPrototype page). The key is absent when a tech has none
(three here: `flammables`, `laser`, `modules`). The Modifier union at 2.0.77 has **48 variants**
(<https://lua-api.factorio.com/2.0.77/types/Modifier.html>): `unlock-recipe`, `give-item`,
`nothing`, `gun-speed`, `ammo-damage`, `turret-attack`, `artillery-range`, `laboratory-speed`,
`laboratory-productivity`, `mining-drill-productivity-bonus`, `train-braking-force-bonus`,
`worker-robot-speed`, `worker-robot-storage`, `worker-robot-battery`, `follower-robot-lifetime`,
`maximum-following-robots-count`, `inserter-stack-size-bonus`, `bulk-inserter-capacity-bonus`,
`belt-stack-size-bonus`, `beacon-distribution`, `deconstruction-time-to-live`,
`create-ghost-on-entity-death`, `cliff-deconstruction-enabled`, `mining-with-fluid`,
the 2.0-era unlock family `unlock-space-location`, `unlock-quality`,
`unlock-space-platforms`, `unlock-circuit-network`, `cargo-landing-pad-count`,
`change-recipe-productivity`, `rail-support-on-deep-oil-ocean`,
`rail-planner-allow-elevated-rails`, `vehicle-logistics`, `character-logistic-requests`,
`character-logistic-trash-slots`, the eleven `character-*` bonuses (crafting/mining/running speed,
build/reach/item-drop/resource-reach/item-pickup/loot-pickup distance, inventory slots, health),
and the two construction-queue attempt caps.

Observed in this dump: 22 distinct types across 210 technologies — 251 `unlock-recipe`, then
`ammo-damage` (54), `gun-speed` (26), `turret-attack` (14), `bulk-inserter-capacity-bonus` (8),
`train-braking-force-bonus` (7), `laboratory-speed` (6), `maximum-following-robots-count` (6),
`worker-robot-speed` (6), `mining-drill-productivity-bonus` (4), `worker-robot-storage` (3),
`inserter-stack-size-bonus` (2), and one each of `artillery-range`, `character-mining-speed`,
`character-inventory-slots-bonus`, `cliff-deconstruction-enabled`,
`create-ghost-on-entity-death`, `character-logistic-requests`, `character-logistic-trash-slots`,
`vehicle-logistics`, `mining-with-fluid`, `unlock-circuit-network`. `give-item` and `nothing`
appear nowhere in this mod list.

The dumped shapes are flat and small. `unlock-recipe` carries `recipe`; everything else observed
carries `modifier` (a number for bonuses, `true` for the boolean unlocks), plus a discriminating
field where the target needs naming:

```json
{ "type": "unlock-recipe", "recipe": "pipe" }
{ "type": "ammo-damage", "ammo_category": "bullet", "modifier": 0.1 }
{ "type": "turret-attack", "turret_id": "gun-turret", "modifier": 0.1 }
{ "type": "mining-with-fluid", "modifier": true }
```

So the non-recipe effects fall into three observable groups: numeric bonuses (`modifier` is a
number, sometimes scoped by `ammo_category` or `turret_id`), boolean capability unlocks
(`modifier: true` — `mining-with-fluid`, `unlock-circuit-network`,
`cliff-deconstruction-enabled`, `vehicle-logistics`, the logistic-request pair,
`create-ghost-on-entity-death`), and — in the union but not in this dump — item grants
(`give-item`) plus `unlock-space-location`, `unlock-quality`, `unlock-space-platforms` and
`cargo-landing-pad-count`. That is what exists; which of them a viewer shows is a design choice
this document does not make.

### The recipe → products chain

`unlock-recipe.recipe` names a RecipePrototype
(<https://lua-api.factorio.com/2.0.77/prototypes/RecipePrototype.html>). `results` ::
array of ProductPrototype, optional — "A table containing result names and amounts. Products also
contain information such as fluid temperature, probability of results and whether some of the
amount is ignored by productivity." At 2.0 every entry is an **object with an explicit `type`
discriminator** — there is no 1.1-style bare `result` shorthand in the dump:

```json
"iron-gear-wheel":  { "ingredients": [{"type": "item", "name": "iron-plate", "amount": 2}],
                      "results":     [{"type": "item", "name": "iron-gear-wheel", "amount": 1}] }
"advanced-oil-processing": { "results": [{"type": "fluid", "name": "heavy-oil", "amount": 25},
                                         {"type": "fluid", "name": "light-oil", "amount": 45},
                                         {"type": "fluid", "name": "petroleum-gas", "amount": 55}] }
```

Census of every key appearing in any `results` entry across the 271 recipes of this dump:
`type` / `name` / `amount` (all 286 entries; 242 item, 44 fluid), `ignored_by_stats` (58),
`temperature` (4 — this repo's plasma recipes, e.g.
`{"type": "fluid", "name": "rf-d-d-plasma", "amount": 5, "temperature": 1000000}`),
`ignored_by_productivity` (4 — `kovarex-enrichment-process`), `probability` (2 —
`uranium-processing`'s 0.007/0.993 pair), `fluidbox_index` (1 — `basic-oil-processing`).
Eleven recipes have no usable `results`: `recipe-unknown` and the ten parameter recipes.
`main_product` appears as `""` on kovarex (docs: empty string forces the recipe's own
name/icon). `enabled` on recipes shows all three states here: absent on 20, explicit `true` on 3,
`false` on 248 — the technology-unlocked ones.

An item result's `name` is a prototype name in one of the **item subclasses**, each of which is
its own top-level dump key. Present in this dump: `item`, `item-with-entity-data`, `tool`,
`module`, `ammo`, `gun`, `armor`, `capsule`, `repair-tool`, `rail-planner`, `blueprint`,
`deconstruction-item`, `upgrade-item` (plus non-takeable `item-entity`, `item-request-proxy`).
A name→item lookup has to search all of them; `type: "fluid"` results resolve against `fluid`
alone.

The item→entity hop is `place_result` :: EntityID, optional — "Name of the EntityPrototype that
can be built using this item"
(<https://lua-api.factorio.com/2.0.77/prototypes/ItemPrototype.html>). Dumped as a plain string:
`item.rf-reactor` has `"place_result": "rf-reactor"`, `item.iron-plate` has none.

## 4. Localized names: `--dump-prototype-locale`

The flag writes one `<category>-locale.json` per locale category — 23 files under this mod list,
among them `technology-locale.json`, `recipe-locale.json`, `item-locale.json`,
`fluid-locale.json`, `entity-locale.json`. Each file is one object with two keys, **`names` and
`descriptions`, each mapping prototype name → resolved display string**:

```json
{ "names": { "automation": "Automation", "rf-d-d-fusion": "D-D fusion", ... },
  "descriptions": { "advanced-circuit": "More advanced integrated circuits.", ... } }
```

Strings are in the game's configured locale — English here, the default for the fresh write-data
directory each `Invoke-Factorio` run gets. So yes: it gives localized technology, recipe, item and
fluid names keyed by prototype name, one language per run.

**The fallback chain arrives fully resolved.** The dump lists prototypes whose name resolves to a
valid value (`locale-check.ps1` records the game's own wording: "if they have a valid value" — a
prototype with no entry is simply absent, which is what that check exploits). Observed coverage
under this mod list: all 210 technologies, all 271 recipes (the hidden and parameter ones
included), all 36 fluids, and **every prototype of all 13 item subclasses — zero missing from
`item-locale.json`**. That includes every name that is not written in any locale file but derived:

- Items named via their placed entity — the ItemPrototype docs note that with `place_result` set,
  the entity's localised name is used as the item name unless overridden. Vanilla
  `assembling-machine-1` (an item with no `item-name` locale entry of its own) appears in
  `item-locale.json` as `"Assembling machine 1"`; this repo's `rf-reactor` item likewise arrives
  as `"Fusion reactor"`, identical to its `entity-locale.json` entry.
- Engine-generated recipes: `empty-rf-brine-barrel` → `"Empty Brine barrel"`.
- `localised_name` overrides in data.raw are already applied: `technology.logistic-science-pack`
  dumps `"localised_name": ["technology-name.logistic-science-pack"]` and the locale file has the
  finished `"Logistic science pack"`.

**Levelled technologies are keyed by their full prototype name, with the level stripped from the
value.** `physical-projectile-damage-7` → `"Physical projectile damage"` — the TechnologyPrototype
`name` docs say a trailing `-<number>` is ignored for localisation and shown as a level indicator,
and the dump reflects exactly that: no key `physical-projectile-damage`, no "7" in the string.

`descriptions` is sparser than `names` (207 vs 210 technologies here); descriptions are optional.

## The field map, in one place

What an extraction script reads per technology `T` in `data-raw-dump.json.technology`, all facts
above condensed; defaults per the 2.0.77 docs, applied by the consumer because the dump omits them:

| Viewer field | Source | Shape / notes |
|---|---|---|
| science-pack kinds | `T.unit.ingredients` | array of `[tool-name, count]` pairs |
| unit count | `T.unit.count` | uint64; **or** `T.unit.count_formula` (string, `L` = level; `max_level` may be `"infinite"`) |
| research time | `T.unit.time` | double, seconds per unit |
| trigger techs | `T.research_trigger` | present iff `unit` absent; `{type, item\|entity, count?}`, `count` omitted when 1 |
| prerequisites | `T.prerequisites` | array of technology names; key absent when none |
| researchable/visible | `T.enabled` / `T.hidden` / `T.visible_when_disabled` | absent = `true` / `false` / `false` |
| unlocked recipes | `T.effects[]` where `type == "unlock-recipe"` | `.recipe` → `data-raw-dump.json.recipe` |
| other effects | remaining `T.effects[]` | `{type, modifier, ammo_category?/turret_id?}`; key absent when no effects |
| recipe products | `recipe.results[]` | `{type: "item"\|"fluid", name, amount}` + optional `probability`, `temperature`, `ignored_by_stats`, `ignored_by_productivity`, `fluidbox_index` |
| placed entity | `<item-subclass>.<name>.place_result` | string entity name; item lookup must search every item subclass table |
| display names | `<category>-locale.json` → `names[prototype-name]` | resolved string, one language per run; fallback chains and `-<level>` stripping already applied; absent = would show "Unknown key" |

Reproduction: junction the three repo mods, disable the bundled expansions, and run Factorio once
with `--dump-data` and once with `--dump-prototype-locale` — `scripts/locale-check.ps1`'s
`Invoke-Dumps` does precisely this; the outputs land in the run's
`write-data/script-output/`.
