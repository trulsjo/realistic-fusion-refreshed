# What `--dump-data` yields for a machine's footprint and connections

Researched 2026-09-04 ([#244](https://github.com/trulsjo/realistic-fusion-refreshed/issues/244), part of
[#238](https://github.com/trulsjo/realistic-fusion-refreshed/issues/238)). **Every API claim is pinned to
Factorio 2.0.77**, read at `https://lua-api.factorio.com/2.0.77/` rather than at `/stable/` or
`/latest/`. This records what a real dump holds for the five mockup machines, so a per-machine geometry
extractor reads the game's answer rather than `entities.lua`. It states facts and makes no design
decisions; it also modifies nothing in `scripts/`.

Two kinds of evidence, kept apart throughout:

- **Observed** — read out of one real dump, produced 2026-09-04 with Factorio 2.0.77 (build 84539,
  win64, steam), the way `scripts/probe-connection-categories.ps1` produces its `declared` dump:
  `New-ModJunctions` linking this worktree's three mods in, `Write-ModList` enabling `base` plus
  `realistic-fusion-refreshed-assets`, `realistic-fusion-refreshed-core` and `realistic-fusion-refreshed`
  (all 0.1.0, commit dbbce55) and writing the bundled `elevated-rails`, `quality` and `space-age`
  explicitly disabled, then `Invoke-Factorio ... -Arguments @('--dump-data')`. The run exited 0 and
  wrote a 13.9 MB `data-raw-dump.json`. Numbers below are numbers for that mod list.
- **Documented** — quoted from the 2.0.77 prototype docs, with URLs.

Anything that is neither is marked **inferred**.

## 1. Where the five live in the dump

The dump is one object with **one top-level key per prototype type**, each an object keyed by prototype
name (`docs/research/tech-tree-dump-fields.md` records the same shape). Names are unique only within a
type, and every one of the five appears under **three** types — `item`, `recipe` and its entity type —
so a geometry extractor must select by *entity* type, not by name alone. Observed:

| Machine | Entity type | `collision_box` | `selection_box` |
|---|---|---|---|
| `rf-heat-exchanger` | `boiler` | `[[-2.25,-7.25],[2.25,7.25]]` | `[[-2.5,-7.5],[2.5,7.5]]` |
| `rf-direct-energy-converter` | `generator` | `[[-2.25,-7.25],[2.25,7.25]]` | `[[-2.5,-7.5],[2.5,7.5]]` |
| `rf-aneutronic-reactor` | `boiler` | `[[-7.25,-7.25],[7.25,7.25]]` | `[[-7.5,-7.5],[7.5,7.5]]` |
| `rf-isotope-collector` | `boiler` | `[[-2.25,-2.25],[2.25,2.25]]` | `[[-2.5,-2.5],[2.5,2.5]]` |
| `rf-lithium-blanket` | `container` | `[[-2.25,-2.25],[2.25,2.25]]` | `[[-2.5,-2.5],[2.5,2.5]]` |

Two things worth knowing before writing the selector:

- **`rf-reactor` is a `boiler` too**, not a `reactor` — the dump has no `reactor/rf-reactor`, and a
  lookup that assumed the type from the name would find nothing. Observed.
- The five entities carry **no `tile_width`, `tile_height`, `drawing_box_vertical_extension` or
  `not-rotatable` flag**; `flags` is `["placeable-neutral","player-creation"]` on all five. Observed.
  `tile_width`/`tile_height` default to the collision box's width/height "rounded up"
  (<https://lua-api.factorio.com/2.0.77/prototypes/EntityPrototype.html#tile_width>), so the footprint
  in tiles is **inferred** as 5×15, 5×15, 15×15, 5×5, 5×5 — which is also what the selection boxes
  say directly, since a selection box for a building "should match the tile size" (same page,
  `selection_box`).

### Encoding

- Both boxes are dumped in **BoundingBox shorthand**: a 2-element array of 2-element arrays, no
  `left_top`/`right_bottom` keys and no third orientation item. Observed on all five and on every
  vanilla entity checked (`heat-exchanger`, `boiler`, `steam-turbine`, `nuclear-reactor`).
  Documented: "The first tuple item is left_top, the second tuple item is right_bottom", "Positive x
  goes towards east, positive y goes towards south"
  (<https://lua-api.factorio.com/2.0.77/types/BoundingBox.html>). The struct form is legal in Lua and a
  robust reader should accept it, but nothing in this dump uses it.
- Numbers are plain JSON numbers; PowerShell's `ConvertFrom-Json` reads `-7.25` as `Double` and `7`
  as `Int64`. Observed.
- The dump is **pretty-printed** with a newline and indentation between key and value (`"direction": \n
  0`), so a regex written for compact JSON matches nothing — the first pass of this research fell
  into that. Walk the parsed object, as `Find-MissingAssets` and `Add-Connections` already do.

## 2. Fluid boxes, connection by connection

Field semantics, documented (<https://lua-api.factorio.com/2.0.77/types/FluidBox.html>,
<https://lua-api.factorio.com/2.0.77/types/PipeConnectionDefinition.html>):

- `FluidBox.pipe_connections` :: array[PipeConnectionDefinition], required — "Connection points to
  connect to other fluidboxes. This is also marked as blue arrows in alt mode."
- `FluidBox.filter` :: FluidID, optional — "Can be used to specify which fluid is allowed to enter this
  fluid box."
- `FluidBox.production_type` :: ProductionType, optional, default `"none"` — one of `"none"`, `"input"`,
  `"input-output"`, `"output"`; "`input-output` should only be used for boilers in fluid heating mode."
- `position` :: MapPosition, optional — "Position relative to entity's center where pipes can connect to
  this fluidbox regardless the directions of entity."
- `positions` :: array of 4 MapPosition, optional — "The 4 separate positions corresponding to the 4
  main directions of entity. Only loaded, and mandatory if `position` is not defined and if
  `connection_type` is `"normal"` or `"underground"`."
- `direction` :: defines.direction, optional — "Primary direction this connection points to when entity
  direction is north and the entity is not mirrored. When entity is rotated or mirrored, effective
  direction will be computed based on this value. Only loaded, and mandatory if `connection_type` is
  `"normal"` or `"underground"`."
- `flow_direction` :: FluidFlowDirection, optional, default `"input-output"`; values `"input"`,
  `"output"`, `"input-output"` (<https://lua-api.factorio.com/2.0.77/types/FluidFlowDirection.html>).
- `connection_type` :: PipeConnectionType, optional, default `"normal"`; values `"normal"`,
  `"underground"`, `"linked"`.
- `connection_category` :: string or array[string], optional, default `"default"` — the field
  `load-check.ps1`'s containment gate already reads.

What the five actually hold. Observed, positions as `[x, y]` relative to the entity centre, entity
facing north:

**`boiler/rf-heat-exchanger`** — `mode: "output-to-separate-pipe"`

| Box | `filter` | `production_type` | `volume` | Connections (`flow_direction`, `direction`, `position`) |
|---|---|---|---|---|
| `fluid_box` | `water` | `input` | 200 | `input-output`, 0, `[0,-7]`; `input-output`, 8, `[0,7]` |
| `output_fluid_box` | `steam` | `output` | 200 | `output`, 4, `[2,0]` |
| `energy_source.fluid_box` | `rf-reactor-energy` | `input` | 200 | `input`, 12, `[-2,0]` |

`energy_source` is `{type: "fluid", effectivity, burns_fluid: true, scale_fluid_usage: true, fluid_box}`;
no `fluid_usage_per_tick` is dumped (documented default `0`, "the system automatically calculates this
value under certain conditions involving the fluid box filter" —
<https://lua-api.factorio.com/2.0.77/types/FluidEnergySource.html>).

**`generator/rf-direct-energy-converter`** — `burns_fluid: true`, `energy_source: {type: "electric", ...}`

| Box | `filter` | `production_type` | `volume` | Connections |
|---|---|---|---|---|
| `fluid_box` | `rf-aneutronic-reactor-energy` | `input` | 1000 | `input-output`, 12, `[-2,0]`; `input-output`, 4, `[2,0]` |

No `output_fluid_box` — GeneratorPrototype has none
(<https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html>). Its electric energy source
has no fluid box either.

**`boiler/rf-aneutronic-reactor`** — `mode: "output-to-separate-pipe"`, `energy_source: {type: "electric", ...}`

| Box | `filter` | `production_type` | `volume` | Connections |
|---|---|---|---|---|
| `fluid_box` | *(absent)* | `input-output` | 3000 | `input-output`, 12, `[-7,0]`, `connection_category: "rf-plasma"`; `input-output`, 4, `[7,0]`, `connection_category: "rf-plasma"` |
| `output_fluid_box` | `rf-aneutronic-reactor-energy` | `output` | 1000 | `output`, 0, `[0,-7]` |

This is the only one of the five whose `fluid_box` has **no `filter`** and the only one carrying a
`connection_category`; both are plain strings, not one-element arrays (the whole dump has 14 string
categories and 0 array ones — observed). An extractor reading `filter` must tolerate its absence.

**`boiler/rf-isotope-collector`** — `mode: "output-to-separate-pipe"`, `energy_source: {type: "void"}`

| Box | `filter` | `production_type` | `volume` | Connections |
|---|---|---|---|---|
| `fluid_box` | `rf-tritium` | `output` | 500 | `output`, 12, `[-2,0]`; `output`, 4, `[2,0]` |
| `output_fluid_box` | `rf-helium-3` | `output` | 500 | `output`, 0, `[0,-2]` |

Note that the *input* box is dumped with `production_type: "output"` — the collector is a boiler used
backwards, and the dump records that as set. A geometry file must not assume a boiler's `fluid_box` is
an input.

**`container/rf-lithium-blanket`** — no fluid box of any kind, no `energy_source`. Its geometry is
the two boxes alone. Observed.

### Encoding, connection by connection

- **`pipe_connections` is always a JSON array**, even with one element: the raw text is `[ { ... } ]`
  and `ConvertFrom-Json` yields `Object[]` of count 1. Observed on `rf-heat-exchanger`'s
  `output_fluid_box`. (PowerShell's own pipeline will still unwrap a one-element array when a function
  returns it — the trap `Add-Connections` in `factorio-lib.ps1` documents; wrap in `@()`.)
- **`position`, never `positions`, on every rf- connection.** The entire dump contains exactly one
  `positions` field, on vanilla `mining-drill/pumpjack`. Observed. So a first extractor can read
  `position` and treat `positions` as an error to report, not a case to handle.
- **`direction` is dumped as an integer**, never as a string, and the only values in the whole dump are
  0, 4, 8 and 12 (46, 22, 41 and 22 occurrences; the one `"direction": 0.4` in the file is an
  artillery-shell particle, not a pipe). Observed. The docs give the 16 names of `defines.direction`
  from `north` through `northnorthwest` without printing their numbers
  (<https://lua-api.factorio.com/2.0.77/defines.html#defines.direction>). The mapping **north = 0,
  east = 4, south = 8, west = 12** is **observed**, not read: every connection whose `position` lies
  on the north edge (`y < 0`, `x = 0`) carries 0, east edge 4, south edge 8, west edge 12 — on all four
  rf- boilers/generators above and on vanilla `heat-exchanger` (`[-1,0.5]`→12, `[1,0.5]`→4,
  `[0,-0.5]`→0) and `steam-turbine` (`[0,2]`→8, `[0,-2]`→0). That it is a 16-point compass with four
  steps per quarter turn is **inferred** from the sixteen names; nothing here needs the other twelve.
- **`connection_type` is absent on all of the five's connections**, so each is `"normal"` by the
  documented default. The dump's only two `connection_type` fields are `"underground"`, on vanilla
  `pipe-to-ground` and our `rf-pipe-to-ground`. Observed.
- **`flow_direction` is present on every one** of the five's connections. Observed. Do not rely on
  that — it is optional with a default, and `tech-tree-dump-fields.md` already records that the dump
  omits properties left at default.
- Every fluid box on the five also carries `pipe_covers` (a Sprite4Way of vanilla pipe-cover sheets)
  and `volume`. Observed. Neither is geometry.

### Where a connection sits relative to the box

Every `position` above is **exactly on the edge tile of the selection box**: `rf-heat-exchanger`'s
box spans y ∈ [-7.5, 7.5] and its water connections are at y = ∓7; its box spans x ∈ [-2.5, 2.5] and
the steam/energy connections are at x = ±2. Observed on all four. The pipe that connects therefore
sits one tile beyond, at `position + unit(direction)` — that is **inferred** from the
`connection_type` docs describing a `"normal"` connection as one made to the neighbouring tile
(paraphrased, not quoted), not from anything the dump says; the dump stores the inside position only.

## 3. What the scripts already expose

**Fetching the dump — the one call.** There is no library function that *runs* a dump; there is one
that runs the game, and every dump in the repo goes through it:

```powershell
. "$PSScriptRoot/factorio-lib.ps1"
$exe = Resolve-FactorioExe                      # -Path, $env:FACTORIO_EXE, or the Steam install
$bundled = Get-BundledMods -FactorioExe $exe    # space-age, quality, elevated-rails — discovered
New-ModJunctions -ModDirectory $modDir -RepoRoot $repoRoot -Mods (Get-RepoMods)
Write-ModList    -ModDirectory $modDir -Bundled $bundled -EnabledBundled @() -Mods (Get-RepoMods)
$r = Invoke-Factorio -FactorioExe $exe -ModDirectory $modDir -Arguments @('--dump-data') `
                     -OutputDirectory $temp -Tag 'geometry'
# $r.Code is the exit code; the dump is at
$dump = Join-Path $temp 'write-data/script-output/data-raw-dump.json'
```

That path follows from `Invoke-Factorio` itself: it writes a `factorio-config.ini` moving `write-data`
under `$OutputDirectory`, so the game's `script-output/` lands there rather than in the player's
appdata (`scripts/factorio-lib.ps1`, `Invoke-Factorio`). Three callers already do exactly this —
`Invoke-DataDump` in `scripts/load-check.ps1`, `Get-OurConnections` in
`scripts/probe-connection-categories.ps1`, and the zip self-test — and each is script-local, not
exported; each also deletes the dump path before the run so a silent non-write cannot hand back the
previous dump, and copies the result aside under its tag. An extractor should copy both habits.
`Write-ModList` must be told about the bundled mods; omitting one **enables** it, which is the fault
the function's own header records. Observed: this run took about 30 s, most of it `base`'s data
stage; the dump is 13.9 MB.

`Remove-ModJunctions` before `Remove-TempDirectory` on the way out, in that order — the lib's comment
on the former says why (a recursive delete would follow the junction into the repo).

**Reading the dump — what exists and what does not.** Two readers walk the JSON today, and neither
returns geometry:

- `Find-MissingAssets` walks the whole dump as an object graph and returns *strings* matching
  `__mod__/….png|ogg`. Its walk (a stack over `PSCustomObject` properties and `Object[]` elements,
  skipping `filename` beside `stripes`) is the model for any structural walk, but it is not
  parameterised.
- `Get-ConnectionsFromDump -DumpPath -Prefix 'rf-'` returns `"type/name" → (path → row)` for every
  `pipe_connections` entry under every rf- prototype, where `path` is the property path
  (`.fluid_box.pipe_connections[1]`, `.energy_source.fluid_box.pipe_connections[1]`, …) and `row` is
  `{Category, Set, Type}` — the connection category and connection type **only**. It deliberately
  discards `position`, `direction` and `flow_direction`, because the containment gate compares
  categories and nothing else. It is the right *selector* (it finds every box, including the energy
  source's, by recursion rather than by a list of field names, and it keys by `type/name` so the
  `item`/`recipe` homonyms cannot collide) and the wrong *projection*.

So the honest answer to "the one call that fetches it" is: **`Invoke-Factorio` with `--dump-data`
fetches the dump; nothing yet extracts geometry from it.** The extractor would either (a) widen
`Add-Connections`' row with `Position`, `Direction` and `FlowDirection` — three fields, all already in
`$connection` at that point, and `Get-ConnectionsFromDump` would then hand back everything section 2
lists except the boxes — or (b) do its own selection over the parsed object. Which is a decision for
[#248](https://github.com/trulsjo/realistic-fusion-refreshed/issues/248), not this note; (a) touches
`factorio-lib.ps1`, which the containment gate and the probe both dot-source, so `load-check.ps1` and
`probe-connection-categories.ps1` would need re-running after it.

## 4. The field list a per-machine geometry file needs

Everything a mockup-art or layout tool would read, per entity, as the dump names it:

| Field | Path in the dump | Shape observed | Notes |
|---|---|---|---|
| entity type | top-level key | `boiler` / `generator` / `container` | select by this, not by name |
| `collision_box` | `<type>/<name>.collision_box` | `[[x1,y1],[x2,y2]]` | `{0,0}` is the entity position; must lie inside |
| `selection_box` | `<type>/<name>.selection_box` | `[[x1,y1],[x2,y2]]` | equals the tile footprint on all five |
| footprint in tiles | *(derived)* | — | `tile_width`/`tile_height` absent; inferred as ceil of collision box, equal to the selection box extent |
| fluid boxes | `.fluid_box`, `.output_fluid_box`, `.energy_source.fluid_box` | object or absent | recurse for `pipe_connections` rather than naming these three, as `Add-Connections` does |
| `filter` per box | `<box>.filter` | string or **absent** | absent on `rf-aneutronic-reactor.fluid_box` |
| `production_type` per box | `<box>.production_type` | string | `input` / `output` / `input-output`; not implied by the box's name |
| `pipe_connections` | `<box>.pipe_connections[]` | always an array | wrap in `@()` in PowerShell |
| `position` | `…[i].position` | `[x, y]`, integers on the five | on the edge tile; `positions` never used by rf- |
| `direction` | `…[i].direction` | integer 0/4/8/12 | N/E/S/W, observed; "when entity direction is north" |
| `flow_direction` | `…[i].flow_direction` | string | present on all; default `input-output` if ever absent |
| `connection_type` | `…[i].connection_type` | **absent** on the five | default `normal` |
| `connection_category` | `…[i].connection_category` | string or absent | already read by `Get-ConnectionsFromDump` |

Not geometry and safe to drop: `volume`, `pipe_covers`, `mode`, `energy_source.type`, `burns_fluid`,
`flags`, and the fluid box's drawing fields (`render_layer`, `secondary_draw_orders`,
`hide_connection_info`, `pipe_picture`, …), none of which the five set except `pipe_covers`.

## 5. Open points

- **The N/E/S/W numbers are observed, not documented.** The 2.0.77 defines page lists names only. If an
  extractor wants a documented source for `0/4/8/12`, the machine-readable `runtime-api.json` for
  2.0.77 should carry the values; this research did not manage to read it (the page is too large for
  the fetcher used). Positions make the mapping unambiguous in practice, and a sanity check that the
  direction agrees with which edge the position sits on would catch a wrong assumption.
- **Rotation is not in the dump.** `direction` is defined for the north-facing entity; how a rotated
  or mirrored placement moves each connection is engine behaviour, not data. If a geometry file has
  to cover rotated placements, that is a runtime question (`LuaEntity.fluidbox.get_pipe_connections`
  would give the effective positions on a real map) and a probe, not a dump.
- **Whether to widen `Add-Connections` or walk separately** is left to #248, as above.
- The `boiler`-with-`production_type: "output"` input box on `rf-isotope-collector` is what the dump
  says; whether it is what the design *means* is a question for whoever owns that prototype, not for
  the extractor.
