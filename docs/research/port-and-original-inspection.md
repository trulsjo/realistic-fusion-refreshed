# Port and original — code inspection

Research for [issue #15](https://github.com/trulsjo/realistic-fusion-refreshed/issues/15) — what is
actually inside **Durikkan's 2.0 port** and **Romner_set's 1.1 original**, read from the files rather than
from portal pages.

This replaces sections 2 and 3 of [`predecessor-survey.md`](predecessor-survey.md), which stated plainly
that neither mod could be downloaded and that nothing said about them was code inspection. Both are now
extracted and were read directly. `predecessor-survey.md` is not edited; the closing section below records
which of its gaps this closes and which remain.

**Facts only.** Where the evidence supports more than one reading, both are stated. None of the project's
open decisions are settled here.

## Method and its limits

Three extracted trees were read in place, outside this repository. Nothing was copied in, no remote was
added, no history was grafted.

| Alias used below | Path |
|---|---|
| `ORIG/` | `C:\src\factorio\_reference\RealisticFusionPower_1.8.18\RealisticFusionPower_1.8.18\` |
| `PORT/` | `C:\src\factorio\_reference\RealisticFusionPowerPort_1.9.2\RealisticFusionPowerPort_1.9.2\` |
| `PORT090/` | `C:\src\factorio\_reference\RealisticFusionPowerPort_1.9.0\RealisticFusionPowerPort_1.9.0\` |

Each archive nests the mod directory once inside a directory of the same name; the aliases point at the
inner directory, the one containing `info.json`.

Line counts are physical lines (`wc -l`). Diffs are `diff -u`; "changed lines" means lines prefixed `<`
or `>` by `diff`, so a modified line counts twice.

**Neither mod was run.** A Factorio 2.0.77 install was found at
`D:\SteamLibrary\steamapps\common\Factorio` (`data/base/info.json` reports `"version": "2.0.77"`) and was
read for base-game prototype values where the port copies them, but no load test was attempted. Every
"does it load" or "how does it behave" statement below is static analysis.

Version-specific claims are marked with the Factorio version they depend on. The 1.1↔2.0 API renames used
as evidence (`global`→`storage`, `on_built_entity.created_entity`→`.entity`, fluid box
`base_area`/`base_level`→`volume`, pipe connection `type`→`flow_direction`) should be checked against
<https://lua-api.factorio.com/1.1.110/> and <https://lua-api.factorio.com/2.0.77/> before being relied on
for migration work.

---

## 1. Realistic Fusion Power 1.8.18 — the 1.1 original

`ORIG/info.json`:

```json
"name": "RealisticFusionPower", "version": "1.8.18", "author": "Romner_set",
"factorio_version": "1.1",
"dependencies": ["base >= 1.1", "? RTG", "? Flow Control", "? Krastorio2", "? Krastorio2Assets",
  "? Krastorio2-more-locomotives", "? Booktorio", "? angelspetrochem", "? angelssmelting",
  "? angelsindustries", "? bobelectronics", "? bobplates", "? bobpower", "? space-exploration",
  "? aai-industry", "? True-Nukes"]
```

Fifteen optional dependencies, confirming the portal API figure the previous survey reported.

### 1.1 Lua line count and file layout

**61 Lua files, 9,452 lines.** 41 MB, 204 files total: 124 PNG, 61 Lua, 7 TXT, 6 OGG, 4 CFG, 2 JSON.

| Area | Files | Lines |
|---|---:|---:|
| Mod proper (stage entry points + `prototypes/` + `electric-boiler/`) | 19 | 6,820 |
| `compatibility-patches/` | 36 | 2,595 |
| `migrations/` | 6 | 37 |
| **Total** | **61** | **9,452** |

The mod proper, file by file:

| File | Lines |
|---|---:|
| `prototypes/entities.lua` | 1,718 |
| `prototypes/technology/fusion-efficiency.lua` | 1,308 |
| `prototypes/technology/technology.lua` | 709 |
| `prototypes/recipes/recipes.lua` | 523 |
| `prototypes/technology/heating-efficiency.lua` | 408 |
| `prototypes/recipes/items.lua` | 355 |
| `prototypes/fluid.lua` | 333 |
| `data-final-fixes.lua` | 281 |
| `settings.lua` | 237 |
| `prototypes/item.lua` | 235 |
| `electric-boiler/electric-boiler.lua` | 165 |
| `control.lua` | 160 |
| `prototypes/technology/antimatter-efficiency.lua` | 152 |
| `print-table.lua` | 89 |
| `prototypes/categories.lua` | 66 |
| `data.lua` | 42 |
| `settings-final-fixes.lua` | 37 |
| `data-updates.lua` | 1 |
| `settings-updates.lua` | 1 |

Two structural observations that matter more than the totals:

1. **Files are organised by prototype *type*, not by domain.** There is one `entities.lua`, one
   `fluid.lua`, one `recipes.lua`. Fuel chain, reactors and antimatter all live inside each of them. See
   §1.3.
2. **There is no runtime simulation.** `control.lua` (160 lines) does exactly three things: it kills
   non-`rfp-` pipes that hold plasma, it spawns/despawns the aneutronic-composite helper entities, and it
   wraps everything in an `xpcall` that prints an apology instead of crashing (`ORIG/control.lua:27-34`).
   Reactors are recipe-driven crafting machines. The real-time fusion model is the abandoned redesign's
   innovation, not the original's — this confirms the previous survey's reading from the locale file.

`compatibility-patches/` holds 17 directories (36 Lua files + one PNG,
`compatibility-patches/Booktorio/gs-process.png`):

`5dim_automation`, `Booktorio`, `CW-hydrogen-power`, `Flow Control`, `IndustrialRevolution`, `Krastorio2`,
`Krastorio2-more-locomotives`, `RTG`, `angelsindustries`, `angelspetrochem`, `angelssmelting`,
`bobelectronics`, `bobplates`, `bobpower`, `space-exploration`, `spidertron-extended`,
`spidertron-extended-se`.

The dependency list and the patch set do not match in either direction. Three optional dependencies have
no patch directory (`Krastorio2Assets`, `aai-industry`, `True-Nukes`) and five patch directories are not
declared as dependencies (`5dim_automation`, `CW-hydrogen-power`, `IndustrialRevolution`,
`spidertron-extended`, `spidertron-extended-se`). The loading mechanism does not need the declaration: it
iterates the `mods` table at runtime — `for k,_ in pairs(mods) do pcall(require, "compatibility-patches."..k..".pre-data") end`
(`ORIG/data.lua:27`) and six sibling lines in `data.lua:43`, `data-updates.lua:2`,
`data-final-fixes.lua:166`, `settings.lua:238`, `settings-updates.lua:2`, `settings-final-fixes.lua:38`.
Space Exploration is the largest single patch at 1,397 lines across 9 files, of which
`compatibility-patches/space-exploration/prototypes/technology/fusion-efficiency.lua` alone is 649.

`migrations/` holds 6 Lua files (37 lines) plus `rfp-1.0.0.json`, covering RFP 1.1.0 → 1.8.0.

### 1.2 Which directories carry their own licence file

**This was the largest unknown in the previous survey. It is now answered for both mods, and the answer is
the same for both.**

Root: `ORIG/license.txt` is the **WTFPL**, `Copyright (C) 2024 Romner`. `ORIG/legal-note.txt` states the
per-directory convention: *"Any file in a subdirectory of this mod that doesn't have a license.txt and/or
a legal-note.txt in its directory is licensed under the WTFPL."*

**Exactly two subdirectories carry their own licence file.** An exhaustive search of all three trees for
`*licen*`, `*legal*`, `COPYING*`, `*.md` and `readme*` returned only these and the two roots.

| Directory | Licence | `legal-note.txt` says | Contents |
|---|---|---|---|
| `ORIG/graphics/particle-accelerator/` | **GNU GPL v3** (674-line `license.txt`) | *"All textures in this directory are **modified** from Krastorio 2"* | 9 PNG, **no `.lua`** |
| `ORIG/electric-boiler/` | **CC BY-NC-ND 4.0** (403-line `license.txt`) | *"All textures **and code** in this directory are from angels petrochem"* | 9 PNG **and `electric-boiler.lua`, 165 lines** |

**Applying ADR 0001:**

- **`electric-boiler/` is NonCommercial-NoDerivatives and is therefore never lifted.** It contains Lua,
  not only art — the same trap the redesign had. This is the *third* independent copy of Angel's electric
  boiler found in the predecessor material (redesign, original, port), and all three are marked NC-ND.
- **`graphics/particle-accelerator/` is copyleft (GPLv3), usable only whole, with its licence file, with
  modifications stated.** Its own `legal-note.txt` already declares the sprites modified from Krastorio 2.
  Note this is Romner's 2022 copy; upstream Krastorio2Assets is LGPLv3, as ADR 0001 records. The
  directory is antimatter art, which ADR 0002 puts outside v1 scope anyway.
- Everything else — `graphics/entity/`, `graphics/entity/shadows/`, `graphics/icons/` (48 PNG),
  `graphics/technology/` (21 PNG), `sounds/` (6 OGG), `locale/`, all Lua outside `electric-boiler/` — has
  no licence file and is permissive under the root WTFPL, subject to the standing PreLeyZero /
  YuokiTani / forum-sprites caveat in `CLAUDE.md`, which this inspection does nothing to resolve.

**The NC-ND Lua is wired in, and is modified.** `ORIG/data.lua:28` reads
`if not mods["angelspetrochem"] then require("electric-boiler.electric-boiler") end` — a fallback boiler
for players without Angel's, exactly as in the redesign. The file's own header (`ORIG/electric-boiler/electric-boiler.lua:1-4`)
says: *"To (hopefully) comply with CC BY-NC-ND 4.0, all changes made are indicated in comments starting
with `--*`"*, and `--*replaced`, `--*added line` and `--*section commented out` markers appear throughout.
As ADR 0001 already found for the redesign's copy: NoDerivatives forbids exactly this, so on a plain
reading the archive's own copy appears to sit outside the terms it ships under. Not a legal opinion.

**No NonCommercial or NoDerivatives material other than `electric-boiler/` was found in either mod.** The
redesign's two extra licensed directories — `graphics/icons/krastorio-2/` (GPLv3) and
`graphics/icons/angels-numerals/` (CC BY-NC-ND) — **do not exist here**. `graphics/icons/` has no
subdirectories at all in either the original or the port. The redesign is the more contaminated tree of
the three, not the less.

### 1.3 How separable is the fuel chain from power generation?

The port is the same code and is analysed in §2.3. The finding is identical for both and is stated once,
there. Summary for the original: the mechanical seam is clean and the *design* seam is not.

### 1.4 What does the antimatter setting gate?

The setting is `rfp-antimatter`, `bool-setting`, `startup`, **`default_value = true`** — antimatter is on
by default (`ORIG/settings.lua:121-127`). Note the port did not change this.

It gates nine contiguous blocks, one per prototype file, plus one conditional `require` and two couplings.
Block extents were computed by matching each guard's `if` to the `end` at the same indentation.

| File | Lines | Count | What is gated |
|---|---|---:|---|
| `prototypes/fluid.lua` | 219–280 | 62 | antiprotons, positrons, their high-energy forms, antihydrogen |
| `prototypes/item.lua` | 112–191 | 80 | fuel cells, processor, reactor, science pack items |
| `prototypes/entities.lua` | 739–1229 | 491 | explosion projectile, particle accelerator, decelerator, antimatter processor, antimatter reactor |
| `prototypes/recipes/items.lua` | 161–271 | 111 | the recipes crafting those items |
| `prototypes/recipes/recipes.lua` | 240–325 | 86 | antihydrogen, hydrogen ionization, water electrolysis, (de)acceleration recipes |
| `prototypes/technology/technology.lua` | 504–634 | 131 | 5 antimatter technologies |
| `prototypes/categories.lua` | 44–65 | 22 | 1 fuel category, 4 recipe categories |
| `data-final-fixes.lua` | 2–66 | 65 | science pack into labs; `rfp-antimatter-fuel` when Krastorio 2 absent |
| `prototypes/technology/antimatter-efficiency.lua` | whole file | 152 | 6 efficiency techs, `require`d conditionally at `data.lua:40` |
| **Total** | | **1,200** | |

Line counts are inclusive of the guard's `if` and its matching `end`. That is **17.6 % of the 6,820-line
mod proper**, all reachable by deleting nine contiguous ranges and one `require`.

**The gate is self-consistent — nothing gated is referenced from outside.** The two recipes that look like
general chemistry, `rfp-hydrogen-ionization` and `rfp-water-electrolysis`, are defined *inside* the
antimatter block (`ORIG/prototypes/recipes/recipes.lua:254` and `:268`) and unlocked *inside* it
(`technology.lua:525` and `:632`). Checked: no reference to any antimatter prototype exists outside a
guarded block.

**Two couplings run the other way, and both are small:**

1. `ORIG/prototypes/entities.lua:1244` —
   `local fr = nil; if not settings.startup["rfp-antimatter"].value then fr = "rfp-electrolysis" end`.
   With antimatter **off** the electrolyser gets a `fixed_recipe`; with antimatter **on** it stays
   general-purpose so it can also run `rfp-water-electrolysis`. Dropping antimatter means taking the
   `fixed_recipe` branch — a two-line simplification, not a rework.
2. `ORIG/prototypes/technology/technology.lua:709` —
   `if settings.startup["rfp-antimatter"].value then table.insert(data.raw.technology["rfp-particle-acceleration"].prerequisites, "rfp-tritium-decay") end`,
   inside the `rfp-tritium-decay` block. Antimatter is a *consumer* of the tritium-decay tech, never a
   supplier.

**Reading:** antimatter is cleanly separated. It is a leaf of the tech tree, hanging off
`rfp-d-he3-heating-efficiency-4` and `rfp-d-he3-fusion-efficiency-9` — the far end of the fusion
progression — and nothing upstream depends on it. This is consistent with ADR 0002's deferral: the code
does not have to be untangled, only deleted or left un-required. It also means the guard pattern itself is
a working precedent, should a `v1` want an off-by-default WIP flag.

The one caveat is provenance, not code: the entity art for the accelerator and decelerator sits in the
GPLv3 `graphics/particle-accelerator/` directory, and `CLAUDE.md` flags the rest of the antimatter models
as PreLeyZero's unmarked donation. The *code* is separable; the *assets* are the part with the open
question, exactly as ADR 0002 says.

---

## 2. Realistic Fusion Power Port — Durikkan's 2.0 port

`PORT/info.json`:

```json
"name": "RealisticFusionPowerPort", "version": "1.9.2", "author": "Romner_set",
"factorio_version": "2.0", "dependencies": ["base >= 2.0"]
```

Note the `author` field still reads **`Romner_set`**, not Durikkan, in both 1.9.0 and 1.9.2. There is no
`contact` field (the original had one pointing at Romner's Discord); dropping it is consistent with
`CLAUDE.md`'s "do not try to contact Romner_set".

### 2.1 Lua line count and file layout

**19 Lua files, 7,077 lines.** 38 MB, 163 files: 126 PNG, 19 Lua, 7 TXT, 6 OGG, 4 CFG, 1 JSON.

The 19 files are **exactly the original's 19 mod-proper files, same names, same directories**. Nothing was
added, split, renamed or moved. What is gone is `compatibility-patches/` (36 files) and `migrations/`
(6 files + 1 JSON).

| File | ORIG | PORT | Changed lines |
|---|---:|---:|---:|
| `prototypes/entities.lua` | 1,718 | 1,819 | 1,391 |
| `prototypes/technology/fusion-efficiency.lua` | 1,308 | 1,308 | 108 |
| `prototypes/technology/technology.lua` | 709 | 709 | 64 |
| `prototypes/recipes/recipes.lua` | 523 | 600 | 203 |
| `prototypes/technology/heating-efficiency.lua` | 408 | 408 | 32 |
| `prototypes/recipes/items.lua` | 355 | 356 | 271 |
| `prototypes/fluid.lua` | 333 | 359 | 112 |
| `data-final-fixes.lua` | 281 | 281 | 42 |
| `settings.lua` | 237 | 237 | **0** |
| `prototypes/item.lua` | 235 | 235 | 30 |
| `electric-boiler/electric-boiler.lua` | 165 | 167 | 154 |
| `control.lua` | 160 | 157 | 57 |
| `prototypes/technology/antimatter-efficiency.lua` | 152 | 152 | 12 |
| `print-table.lua` | 89 | 89 | **0** |
| `prototypes/categories.lua` | 66 | 123 | 57 |
| `data.lua` | 42 | 38 | 7 |
| `settings-final-fixes.lua` | 37 | 37 | **0** |
| `data-updates.lua` | 1 | 1 | **0** |
| `settings-updates.lua` | 1 | 1 | **0** |

The three efficiency-technology files — 1,868 lines, over a quarter of the mod — changed **only** in
`__RealisticFusionPower__` → `__RealisticFusionPowerPort__` asset paths. Stripping those renames leaves
zero diff in all three. The same is true of `prototypes/item.lua`.

`prototypes/entities.lua` absorbs most of the real migration work. Categorising its non-path diff lines:
38 × `base_area` and 37 × `base_level` removed against 38 × `volume` added (fluid-box migration); 15 ×
`pipe_connections` rewritten from `{type = "input"/"output"}` to
`{flow_direction = …, direction = defines.direction.…}`; `hr_version` blocks flattened into `scale`-based
single sprites; `graphics_set` introduced; and 9 × `circuit_wire_max_distance` + 10 ×
`circuit_connector` added, which is the changelog's circuit-connection feature. All 2.0-era prototype
forms. `PORT/prototypes/entities.lua` retains zero `base_area`, zero `base_level` and zero
`{type = "input"}` pipe connections.

Locale grew from 313 to 336 lines (English). The additions are `[recipe-name]` entries — the changelog's
*"I needed to make actual recipe names due to engine changes"* — plus a new `[item-group-name]` section
for the Factoriopedia grouping.

### 2.2 Which directories carry their own licence file

**The same two directories, the same two licences, both marks unchanged from the original.**

| Directory | Licence | `legal-note.txt` says | Contents |
|---|---|---|---|
| `PORT/graphics/particle-accelerator/` | **GNU GPL v3** | *"modified from Krastorio 2"* | 9 PNG, **no `.lua`** |
| `PORT/electric-boiler/` | **CC BY-NC-ND 4.0** | *"All textures and code … from angels petrochem"* | 9 PNG **and `electric-boiler.lua`, 167 lines** |

The nine `graphics/particle-accelerator/` PNGs are byte-identical to the original's. So are their
`license.txt` and `legal-note.txt`. `PORT/graphics/icons/` has no subdirectory and no licence file.

**Three things differ, and all three matter.**

1. **The root licence changed from WTFPL to The Unlicense — but `legal-note.txt` was not updated.**
   `PORT/license.txt` opens *"This applies to all folders, except those that contain a license file within
   them."* followed by the Unlicense text. `PORT/legal-note.txt`, however, is byte-identical to the
   original's and still reads *"…is licensed under the **WTFPL**. Read individual legal-note.txt's for
   more about those."* The two files in the same directory name different licences. Both are permissive
   and the practical difference is small, but the mod does not state one licence consistently. The portal
   field says `unlicense`; the archive says both.

2. **The NC-ND Lua is now loaded unconditionally.** The original guarded it
   (`ORIG/data.lua:28`, `if not mods["angelspetrochem"] then …`). `PORT/data.lua:36` is a bare
   `require("electric-boiler.electric-boiler")`, sitting in the prototype list between `technology` and the
   antimatter `require`. With `? angelspetrochem` also gone from `info.json`, the port always defines
   `angels-electric-boiler` — under ADR 0001 there is no configuration in which taking the port whole
   avoids shipping NoDerivatives code.

3. **The NC-ND file has been modified again, on top of Romner's already-marked modifications.** The port's
   copy is 167 lines against the original's 165, with 154 changed lines: asset paths rewritten to
   `__RealisticFusionPowerPort__`, `circuit_wire_max_distance` and `circuit_connector` added
   (`PORT/electric-boiler/electric-boiler.lua:55-56`), and — between 1.9.0 and 1.9.2 — the 1.1-era
   `module_specification = {module_slots = 0}` replaced with the 2.0 `module_slots = 0` (`:51`). Durikkan
   kept Romner's `--*` change-marking convention and its header comment, so the derivation is documented;
   it is nonetheless a second layer of derivative work on NoDerivatives material.

Everything else in the port — all Lua outside `electric-boiler/`, `graphics/entity/`,
`graphics/entity/shadows/`, `graphics/icons/`, `graphics/technology/`, `sounds/`, `locale/` — carries no
licence file and is permissive under the root `license.txt`.

**One provenance note the licence files do not cover.** The port changed 18 icons and added 3, all in
`graphics/icons/`:

- Added: `d-d-fusion-trit-he3.png`, `d-d-fusion-trit.png`, `heavy-water-distillation.png`
- Content changed: `antihydrogen`, `d-d-fusion`, `d-d-plasma`, `d-he3-fusion`, `d-he3-mix`,
  `d-he3-plasma`, `d-t-fusion`, `d-t-mix`, `d-t-plasma`, `deuterium`, `gs-process`, `he3-he3-fusion`,
  `he3-he3-plasma`, `helium-3`, `hydrogen-sulfide`, `hydrogen`, `tritium-decay`, `tritium` (all `.png`)

The changelog names their source: *"Changed a lot of the recipe icons to the graphics Romner had in his
Realistic Fusion 2.0 build."* That build is the dev repo's `RFP-2.0/` directory, which carries no licence
file and is therefore WTFPL by the redesign's own convention. **Who drew them is not established.** One of
the 18, `antihydrogen.png`, is antimatter art — the category `CLAUDE.md` flags as PreLeyZero's unmarked
donation. Whether any of the other 20 are theirs could not be determined from any file in any of the three
trees.

### 2.3 How separable is the fuel chain from power generation?

Both mods are one Lua tree with no internal module boundary. The question is whether a Core/Power cut
(ADR 0002) has a seam to follow. **There is a clean mechanical seam and a genuinely interwoven design.**

#### Where the seam is clean

The **advanced deuterium extraction chain is one contiguous `if/else` at the end of every file it touches**,
guarded by a single startup setting `rfp-advanced-deuterium-extraction` (`PORT/settings.lua:135-141`,
default `true`):

| File | Fuel-chain block | Lines |
|---|---|---:|
| `PORT/prototypes/entities.lua` | 1237–1820 (`else` at 1735 gives the simple `rfp-deuterium-extractor`) | 584 |
| `PORT/prototypes/recipes/recipes.lua` | 397–601 | 205 |
| `PORT/prototypes/technology/technology.lua` | 2–125 | 124 |
| `PORT/prototypes/recipes/items.lua` | 296–357 | 62 |
| `PORT/prototypes/fluid.lua` | 304–358 | 55 |
| `PORT/prototypes/item.lua` | 193–236 | 44 |
| `PORT/prototypes/categories.lua` | 94–99 | 6 |
| **Total** | | **1,080** |

Plus `electric-boiler/` (167 lines), which exists solely to provide the `rfp-boiling` recipe category the
distillation steps run in (`PORT/electric-boiler/electric-boiler.lua:53`). In the original the same blocks
sit at `entities.lua:1232-1719`, `recipes/recipes.lua:345-524`, `technology.lua:2-125`,
`recipes/items.lua:295-356`, `fluid.lua:282-332`, `item.lua:193-236`, `categories.lua:37-42` — 955 lines,
same shape.

That is a single trailing block per file, cuttable with an editor. The prototypes on each side barely
touch: the fuel chain produces `rfp-deuterium` and consumes water; power consumes `rfp-deuterium` and
produces `rfp-reactor-energy-mj`. Nothing in `entities.lua:1237-1820` refers to a reactor, and nothing
above line 1237 refers to an electrolyser or an extractor.

#### Where it is interwoven

**a) The technology tree crosses the seam in both directions.** Extracted from
`PORT/prototypes/technology/technology.lua`:

| Tech (line) | Side | Prerequisites |
|---|---|---|
| `rfp-deuterium-extraction` (12, 106) | fuel | `rfp-fusion-theory` |
| `rfp-gs-process-1` (30) | fuel | `rfp-deuterium-extraction`, **`rfp-d-d-fusion`** |
| `rfp-gs-process-2` (55) | fuel | `rfp-gs-process-1`, **`rfp-tritium-breeding`** |
| `rfp-gs-process-3` (79) | fuel | `rfp-gs-process-2`, **`rfp-helium-3-breeding`** |
| `rfp-d-d-heating` (214) | power | `rfp-plasma-handling`, **`rfp-deuterium-extraction`** |

Every tier of the deuterium chain is gated on a *fusion* research milestone, and the first heating tech is
gated on the *fuel* chain. Split into two published mods and Power's technologies become prerequisites of
Core's, so Core would hard-depend on Power — the reverse of the intended direction, in which Power depends
on Core (ADR 0002).

**b) The reactors are the breeder.** This is not a code artefact; it is the mod's design. The D-D fusion
recipes return tritium and helium-3 as by-products alongside energy:

```lua
-- PORT/prototypes/recipes/recipes.lua:17-21  (rfp-d-d-fusion-0-<n>)
results = {
    {type = "fluid", name = rfp_fluids["reactor-energy-mj"], amount = dd0energy[i]},
    {type = "fluid", name = rfp_fluids["helium-3"],          amount = 5.5},
    {type = "fluid", name = rfp_fluids["tritium"],           amount = 5.5}
},
```

Three graded variants trade energy against by-product (`rfp-d-d-fusion-0-*` at 100–200 MJ with both
by-products, `-1-*` at 200–300 MJ with tritium only, `-2-*` at 400–600 MJ with neither), and the tech tree
unlocks them in that order — `rfp-tritium-breeding` unlocks `rfp-d-d-fusion-1-9`,
`rfp-helium-3-breeding` unlocks `rfp-d-d-fusion-0-9`. Deuterium is the only fuel the chain supplies; every
other fusion input comes out of a reactor. The original 1.x has no lithium and no lithium breeding — the
previous survey's reading from the locale file is confirmed against the code. So "fuel chain" and "power"
are a closed loop, not a line with a cut point in it.

**c) Three globals cross every file.** `PORT/data.lua:2-11` defines `insert_to_ingredients` and builds
`rfp_fluids` and `rfp_categories` by scanning `settings.startup` for the `rfp-fluid-*` / `rfp-category-*`
string settings declared in `settings.lua:26-101`. Every prototype file on both sides reads them. This one
is cheap to split — the settings are startup settings, so a second mod can read
`settings.startup["rfp-fluid-deuterium"].value` directly — but the settings themselves have to live in
exactly one mod, and `settings-final-fixes.lua:9-35` rewrites their `allowed_values`/`forced_value` in a
way that assumes it sees all of them.

**d) The magnetic-confinement pipes sit on the boundary.** `rfp-pipe`, `rfp-pipe-to-ground` and `rfp-pump`
(`PORT/prototypes/entities.lua:23-42`) are tinted copies of the vanilla prototypes; they exist because
plasma cannot go in an iron pipe, and `control.lua:128-157` enforces that at runtime by killing offending
pipes. Plasma is produced by `rfp-heater` and consumed by the reactors, so the pipes are Power by
function — but the *runtime enforcement* is the mod's single piece of `control.lua` logic and would have
to live in whichever mod owns it, while needing the fluid names from the settings the other mod may
declare.

#### Reading

Two readings, both supported, neither settled here:

- **Cut it.** The prototype-level seam is real and unusually clean for a mod this size: one trailing block
  per file, one setting already switching it on and off, and no prototype cross-references. What must
  change is the tech tree (roughly 5 prerequisite edges) and the ownership of `settings.lua` and
  `control.lua`. On this evidence the port would be split along a line that already exists in the code.
- **Don't cut it here.** The tech-tree edges point the wrong way for a Core-that-Power-depends-on, and the
  by-product loop means the two halves are not independently playable in any case: Core alone produces
  deuterium with nothing to burn it, and Power alone has no tritium or helium-3 because it has no
  deuterium to start the D-D chain that breeds them. That is a design property of the original, not a
  porting artefact, so ADR 0002's split would be re-drawing the *design*, not just the file layout.

The redesign chose the second reading and split `Core`/`Power` differently: it moved the *plasma heaters*
into Core along with the fuel chain and introduced lithium breeding, so that Core produces plasma and
Power only burns it. That is a design change, not a refactor. Recording the observation; not choosing.

### 2.4 The antimatter setting

Identical to the original — same setting, same default (`true`), same nine blocks in the same files. See
§1.4. Block extents shift with the port's added lines: `PORT/prototypes/fluid.lua:236-302`,
`item.lua:112-191`, `entities.lua:741-1234`, `recipes/items.lua:160-264`, `recipes/recipes.lua:277-375`,
`technology/technology.lua:504-634`, `categories.lua:101-122`, `data-final-fixes.lua:2-66` — 1,063 lines —
plus `technology/antimatter-efficiency.lua` (152 lines) `require`d at `data.lua:37`, for 1,215 total.

One small inherited defect, noted because it is in the antimatter path and easy to miss: the four
`rfp-antiproton-deceleration-<i>` recipes are given
`localised_name = {"recipe-name.rfp-antiproton-production"}` (`PORT/prototypes/recipes/recipes.lua:346`),
so they display as "Antiproton production". `locale/en/base.cfg` has no
`rfp-antiproton-deceleration` key at all. Out of v1 scope under ADR 0002.

### 2.5 1.9.0 → 1.9.2: the compatibility removal

The changelog claims *"Stripped out all of the compatibility code."* **The directory is gone; the hooks
into it are not.**

Only seven files differ between 1.9.0 and 1.9.2, and one directory is missing:

```
Only in PORT090: compatibility-patches
changelog.txt                          15 changed lines
data.lua                                7
data-final-fixes.lua                   12
electric-boiler/electric-boiler.lua     4
info.json                               4
prototypes/recipes/recipes.lua         18
```

**Shape and size of the removal:**

| | 1.9.0 | 1.9.2 |
|---|---:|---:|
| `compatibility-patches/` directories | 15 | 0 |
| `compatibility-patches/` files | 31 (all `.lua`) | 0 |
| `compatibility-patches/` Lua lines | 2,369 | 0 |
| `compatibility-patches/` on disk | 175 KB | 0 |
| Optional dependencies in `info.json` | 12 | 0 |
| Total Lua files | 50 | 19 |
| Total Lua lines | 9,454 | 7,077 |

Plus 4 lines deleted from `data.lua`, for **2,373 lines of Lua removed**.

The 15 directories removed: `5dim_automation`, `CW-hydrogen-revolution`, `Flow Control`, `Krastorio2`,
`Krastorio2-more-locomotives`, `RTG`, `angelsindustries`, `angelspetrochem`, `angelssmelting`,
`bobelectronics`, `bobplates`, `bobpower`, `space-exploration`, `spidertron-extended`,
`spidertron-extended-se`.

**Dependencies before and after:**

- **1.9.0:** `["base >= 2.0", "? Flow Control", "? Krastorio2", "? Krastorio2Assets",
  "? Krastorio2-more-locomotives", "? angelspetrochem", "? angelssmelting", "? angelsindustries",
  "? bobelectronics", "? bobplates", "? bobpower", "? space-exploration", "? aai-industry"]` — 12 optional.
- **1.9.2:** `["base >= 2.0"]` — none.

Against the original's 15, the port had already dropped three at 1.9.0: `RTG`, `Booktorio` and
`True-Nukes`. The patch *set* had already been trimmed too — 1.9.0 carried 31 of the original's 36 patch
files (2,369 of 2,595 lines), having dropped `Booktorio/` entirely (141 lines, including the in-game
manual `control.lua` and its PNG), `IndustrialRevolution/` (36), `angelsindustries/data-updates.lua` (31)
and `bobplates/data-updates.lua` (13), and renamed `CW-hydrogen-power/` → `CW-hydrogen-revolution/`.

**What survived the strip — five dead `require` loops and two live mod checks.** The `pairs(mods)` hook
lines were removed from `data.lua` only. Still present in 1.9.2:

```
PORT/settings.lua:238            for k,_ in pairs(mods) do pcall(require, "compatibility-patches."..k..".settings") end
PORT/settings-updates.lua:2      … ".settings-updates") end
PORT/settings-final-fixes.lua:38 … ".settings-final-fixes") end
PORT/data-updates.lua:2          … ".data-updates") end
PORT/data-final-fixes.lua:166    … ".data-final-fixes") end
```

All five point at a directory that no longer exists. Because they are `pcall`-wrapped they fail silently
and are inert — the code is dead, not broken. Two *live* checks remain, and these do still change
behaviour:

```
PORT/data-final-fixes.lua:13  if not mods["Krastorio2"] then add_to_lab("lab")
PORT/data-final-fixes.lua:68  if data.raw.recipe["nuclear-fuel"] and not data.raw.recipe["nuclear-fuel"].hidden and not mods["Krastorio2"] then
```

They suppress the antimatter science pack's lab insertion and the `rfp-thermonuclear-fuel` /
`rfp-fusion-fuel` items when Krastorio 2 is loaded. So *"everything just always requires vanilla
ingredients"* is accurate about recipes, and *"stripped out all of the compatibility code"* is accurate
about the directory but not about the whole mod: two Krastorio 2 branches survive with no declared
dependency on Krastorio 2.

`migrations/` was already gone at 1.9.0. Since the port publishes under a new mod name
(`RealisticFusionPowerPort`), no 1.x save can carry into it and the original's six migration scripts have
nothing to migrate — dropping them is consistent, not an oversight.

**The other 1.9.0 → 1.9.2 changes**, for completeness — all small, none compatibility-related:

- `electric-boiler.lua:51`: 1.1-era `module_specification = {module_slots = 0}` → 2.0 `module_slots = 0`.
  A 1.1 leftover that survived the 1.9.0 port and was only fixed at 1.9.2.
- `data-final-fixes.lua`: six `icon_mipmaps = 4` removed.
- `recipes.lua`: `enabled = false` added to `rfp-d-t-mixing` and `rfp-d-he3-mixing` (these were craftable
  from the start in 1.9.0 — a bug fix); three `subgroup = "fluid"` removed; one
  `hide_from_player_crafting` removed from `rfp-deuterium-extraction`; a wrong `localised_name` on the
  hydrogen-sulfide recipe corrected to `{"fluid-name.rfp-hydrogen-sulfide"}`; seven more `icon_mipmaps`
  removed.

### 2.6 Which buildings become "insanely overpowered with quality"?

**The code does not make it visible. The string `quality` appears nowhere in any Lua, `.cfg`, `.json` or
`.txt` file of any of the three trees** — the only match across all of them is the word "quality" inside
the GPLv3 licence text in `graphics/particle-accelerator/license.txt`. There is no quality scaling, no
quality guard, no `quality_indicator_*` tuning, no `hidden_in_factoriopedia`-style opt-out. No entity in
`PORT/prototypes/entities.lua` declares `module_slots` or `allowed_effects` either, so all of them take
the 2.0 defaults (which were not verified against the docs).

Durikkan's warning is therefore about the vanilla quality mechanic acting on ordinary prototypes, and
identifying the buildings means reading the prototype *types* and their declared magnitudes. That is what
follows. **Which of these the mechanic actually multiplies is a base-game rule, and it is only partly
verified below — treat this section as a candidate list, not a finding.**

What was verified: <https://wiki.factorio.com/Quality> states *"+30 % output rate on boilers, steam
engines, steam turbines, accumulators (also affects input rate), and nuclear reactors"* and *"+30 %
crafting speed"* on assembling machines, per quality level, so legendary is ×2.5.
<https://wiki.factorio.com/Steam_turbine> gives the full table and shows fluid consumption scaling in
lockstep with output — 5.82 MW / 60 steam per second at normal, 14.55 MW / 150 at legendary — so for the
`generator` prototype type quality is throughput scaling, **not** free energy.

The port's entities, by prototype type and declared magnitude:

| Entity | Prototype type | Declared magnitude | Line |
|---|---|---|---:|
| `rfp-direct-energy-converter` | `generator` | `max_power_output = "20GW"`, `fluid_usage_per_tick = 1/3`, `effectivity = 1`, `output_flow_limit = "20GW"` | `entities.lua:419-427` |
| `rfp-hc-turbine` | `generator` (copy of `steam-turbine`) | `fluid_usage_per_tick = 10` — **10× vanilla** | `entities.lua:58-65` |
| `rfp-heat-exchanger` | `reactor` | `consumption = "2GW"`, `scale_energy_usage = true`, `heat_buffer.max_transfer = "2GW"`, `neighbour_bonus = 0` | `entities.lua:312, 332-357` |
| `rfp-hc-exchanger` | `boiler` (copy of `heat-exchanger`) | `energy_consumption = "100MW"` — **10× vanilla** | `entities.lua:46-56` |
| `rfp-antimatter-reactor` | `burner-generator` | `max_power_output = "1.5TW"` (`--UNLIMITED POWAAAH`) | `entities.lua:1221` |
| `rfp-reactor` | `furnace` | `energy_usage = "400MW"`, `crafting_speed = 1` | `entities.lua:556` |
| `rfp-aneutronic-reactor` | `furnace` | `energy_usage = "1W"`, `crafting_speed = 1` | `entities.lua:682` |
| `rfp-heater` | `furnace` | `energy_usage = "200kW"`, `crafting_speed = 1` | `entities.lua:488` |
| `rfp-particle-accelerator` | `assembling-machine` | `energy_usage = "9.95GW"` | `entities.lua:923` |
| `rfp-particle-decelerator` | `assembling-machine` | `energy_usage = "7.45GW"` | `entities.lua:1011` |
| `rfp-electrolyser`, `rfp-deuterium-extractor` | `assembling-machine` | `energy_usage = "1990kW"` | `entities.lua:1311, 1811` |

**The strongest named candidates, and why:**

1. **`rfp-hc-turbine`** — this one *is* visible in the code, without any quality question. Base 2.0.77's
   `steam-turbine` declares `effectivity = 1`, `fluid_usage_per_tick = 1`, `maximum_temperature = 500`
   and **no `max_power_output` at all** (`D:\SteamLibrary\steamapps\common\Factorio\data\base\prototypes\entity\entities.lua:9245-9256`).
   The port's copy raises `fluid_usage_per_tick` to 10 and adds no cap, so it is an uncapped 10× steam
   turbine (≈58 MW at 500 °C) whose output quality then multiplies again on top. Its partner
   `rfp-hc-exchanger` is likewise a 10× heat exchanger (100 MW vs base's `energy_consumption = "10MW"`,
   same file, line 9045). Both are gated behind the `rfp-hc-stuff` startup setting, default `true`
   (`PORT/settings.lua:142-148`), which exists precisely because *"a single D-T reactor produces 1.4 GW to
   2 GW"*.
2. **`rfp-direct-energy-converter`** — a `generator` at 20 GW. If the steam-turbine scaling applies, a
   legendary DEC is a **50 GW single building**. That would be the largest single power source in the mod
   by a wide margin, and it is a plain `generator`, the same prototype family the wiki's steam-turbine
   table covers.
3. **`rfp-heat-exchanger`** — a `reactor` at 2 GW, the "nuclear reactors" entry in the wiki's list; 5 GW
   at legendary.
4. **`rfp-antimatter-reactor`** — 1.5 TW `burner-generator`. Out of v1 scope under ADR 0002, and
   `burner-generator` is not one of the types the wiki page enumerates, so whether quality touches it at
   all was not determined.

**What could not be determined, and it is the crux:** whether the *fixed caps* in these prototypes scale
with quality alongside the throughput. The DEC declares both `max_power_output = "20GW"` and an
`energy_source.output_flow_limit = "20GW"`; the heat exchanger declares both `consumption = "2GW"` and
`heat_buffer.max_transfer = "2GW"`. If the cap scales, these buildings get proportionally bigger, which
matches "insanely overpowered" as a *scale* complaint. If the cap does **not** scale, a quality DEC would
consume more fluid for the same 20 GW — quality would make it *worse*. Nothing in
<https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html> mentions quality; the scaling is
engine-side and not prototype-declared, so it cannot be read out of the files. Settling it needs the game.

The `furnace` and `assembling-machine` entities (the reactors themselves, the heater, the accelerators,
the extractors) get `+30 %` crafting speed per level, which scales inputs and outputs together and does not
break any ratio. They are unlikely to be what Durikkan meant, but they were not ruled out by observation.

**Bottom line: Durikkan names no buildings, and neither does the code.** The list above is derived from
prototype types and declared magnitudes plus two verified wiki statements, and the `rfp-hc-turbine` /
`rfp-hc-exchanger` 10× multipliers are the only part of it that the port's own source makes visible
without appeal to engine behaviour.

### 2.7 Migration state — `storage`, 2.0 event fields, 1.1 leftovers

**`control.lua` is fully migrated.** All 25 `storage.` references, zero `global.` table accesses:

| 1.1 form | 2.0 form in the port |
|---|---|
| `global.stop`, `global.entities`, `global.k` (16 sites) | `storage.stop`, `storage.entities`, `storage.k` |
| `local entity = event.created_entity or event.entity` (`ORIG/control.lua:38`) | `local entity = event.entity` (`PORT/control.lua:38`) |
| `require("compatibility-patches.Booktorio.control")` (`ORIG/control.lua:161`) | removed |

Nothing else in `control.lua` changed — the diff is 57 lines and is entirely those three items. Zero
occurrences of `created_entity` anywhere in the port. The seven remaining `global` matches are all
`settings.global[...]` (the runtime-setting accessor, which keeps that name in 2.0 —
`control.lua:78, 114, 131`) plus four in comments and one `setting_type = "runtime-global"`. No
`defines.events.on_pre_player_mined_item`, no `game.player`.

**Prototype stage is migrated, with cosmetic residue.** Zero `base_area`, zero `base_level`, zero
`{type = "input"}` pipe connections, zero `module_specification`, zero old-style `result_count` or
positional `{"name", n}` ingredient/result shorthand. What remains:

- **10 × `icon_mipmaps = 4`**, a key removed in 2.0: `prototypes/entities.lua:192, 1325`;
  `prototypes/fluid.lua:322, 333, 349`; `prototypes/item.lua:162, 174, 183, 213`;
  `prototypes/technology/technology.lua:535`. Durikkan removed 13 more of these between 1.9.0 and 1.9.2
  and missed these ten. Unknown keys are ignored by the loader, so these are cosmetic — *not verified by
  loading*.
- **2 × `hr_version`**, at `prototypes/entities.lua:7-8`, inside the `tintPictures` helper:
  `if picture.hr_version then picture.hr_version.tint = tint end`. Defensive, and reached for the tinted
  copies of base-game pipes/pumps; harmless whether or not base still has the key.
- **20 × `se_allow_in_space = true`**, a Space Exploration property, on entities across the file. Left
  in after every SE compatibility patch was deleted and `? space-exploration` removed from `info.json`.
  Inert without SE.
- **5 dead `pcall(require, "compatibility-patches.…")` loops** (§2.5).

**No leftover was found that would change behaviour under 2.0.** The one 1.1-era construct that genuinely
would have — `module_specification` in `electric-boiler.lua` — survived 1.9.0 and was fixed in 1.9.2. Whether
anything else fails at load was **not verified**: the mod was not loaded.

---

## 3. What this closes, and what remains open

### Closed

Against `predecessor-survey.md`'s **"What could not be verified"**, item 1 (*"Neither mod-portal mod could
be downloaded"*) and its six sub-points:

| Gap | Status |
|---|---|
| Lua line counts unknown for both | **Closed.** Original 9,452 in 61 files (6,820 in 19 excluding compat and migrations); port 7,077 in 19 files. §1.1, §2.1 |
| File and directory layout unknown for both | **Closed.** Both listed in full; the port's 19 files are the original's 19, unchanged in name and place. §1.1, §2.1 |
| Which directories carry their own licence file, and under which licence | **Closed for both, and identical.** Two directories: `graphics/particle-accelerator/` (GPLv3, art only) and `electric-boiler/` (**CC BY-NC-ND 4.0, containing Lua**). The redesign's `krastorio-2/` and `angels-numerals/` directories do not exist in either. §1.2, §2.2 |
| Durikkan's "minor" recipe and tech-cost tweaks are his claim, not a diff | **Closed, and the claim holds.** Exactly three technology science costs changed (`rfp-fusion-theory` 500→1000, `rfp-d-d-heating` 1500→1000, `rfp-d-d-fusion` 5000→3000, all `× rfp-science-multiplier`; `technology.lua:135, 218, 240`) and exactly two recipe times (`rfp-girdler-sulfide-process-0` `energy_required` 1→5 at `recipes.lua:435`, and the graded `rfp-girdler-sulfide-process-<i>` loop 0.1→1 at `recipes.lua:543`). All three efficiency-technology files and `item.lua` changed **only** in asset paths. Everything else in the recipe diff is `localised_name`, `subgroup`, `icon_size` and Factoriopedia ordering. §2.1 |
| Whether the compatibility code was removed cleanly, and what 1.9.2 recipes require | **Closed.** 15 directories / 31 files / 2,369 lines / 175 KB deleted, plus 4 lines from `data.lua`; 12 optional dependencies → 0. Not clean: five `pcall`-wrapped `require` loops into the deleted directory survive (inert) and two live `mods["Krastorio2"]` branches survive in `data-final-fixes.lua:13, 68`. Recipes do all use vanilla ingredients. §2.5 |
| No claim in sections 2 and 3 rested on reading either mod's code | **Superseded.** Every claim above is code inspection. |

Also closed:

- **The 1.x prototype inventory** the previous survey reconstructed from the redesign's stale ~v1.8.15
  locale copy is confirmed against the actual 1.8.18 files, including its two key negatives: no lithium
  anywhere, and no reactor simulation.
- **`rfp-antimatter` gating** (§1.4): 1,200 lines across nine contiguous blocks, self-consistent, with two
  small couplings pointing inward. ADR 0002's deferral costs nine deletions.
- **The port's licence is stated twice, inconsistently.** `license.txt` is the Unlicense; `legal-note.txt`
  in the same directory still says WTFPL. §2.2

### Open

1. **Neither mod was loaded.** A 2.0.77 install exists at `D:\SteamLibrary\steamapps\common\Factorio` and
   was read for base prototype values, but no load test was run. So "the port's leftovers are cosmetic",
   "the five dead `require`s are inert" and "the original's 1.1 code would need X" are static-analysis
   conclusions. The original cannot be loaded by that install at all (`factorio_version 1.1`).
2. **Which buildings go "insanely overpowered with quality" is still not settled** (§2.6). The code says
   nothing about quality. The candidate list is `rfp-hc-turbine` and `rfp-hc-exchanger` (verified 10×
   multipliers over base, visible in the source), `rfp-direct-energy-converter` (20 GW `generator`),
   `rfp-heat-exchanger` (2 GW `reactor`) and `rfp-antimatter-reactor` (1.5 TW `burner-generator`). The
   deciding question — whether the fixed `output_flow_limit` and `heat_buffer.max_transfer` caps scale
   with quality alongside throughput — is engine behaviour, not prototype data, and needs the game to
   answer. ADR 0003's "named known-gap" obligation stands unchanged.
3. **Who drew the 21 icons the port took from Romner's RFP-2.0 build is not established** (§2.2). They
   carry no licence file and are WTFPL by the redesign's convention, but `CLAUDE.md`'s PreLeyZero caveat
   applies and one of them (`antihydrogen.png`) is antimatter art. No file in any of the three trees
   attributes individual images.
4. **Whether Romner's blanket relicensing covered contributors' work** is untouched here — the archives
   contain no contributor records at all, only the two per-directory notes reproduced in §1.2.
5. **`electric-boiler.lua`'s standing under CC BY-NC-ND** is described, not judged. The port modifies an
   already-modified copy and loads it unconditionally; ADR 0001 already decided the material is never
   lifted, so nothing turns on the judgement for this project.
6. **Space Age behaviour is unobserved** for both, as before. Neither mod references any Space Age
   prototype, planet, `surface_conditions` or `spoil` property — zero occurrences of each — so neither
   integrates with it in any direction.
7. **Realistic Fusion Weaponry was not surveyed** and is still outside the ticket's scope.
8. **The `rfp-hc-turbine` cap question** (§2.6, candidate 1) assumes base 2.0.77's `steam-turbine` really
   has no `max_power_output`; that was read from the installed base mod's `entities.lua:9245-9256` and not
   cross-checked against <https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html> for a
   default value applied when the field is absent.

### Sources

- Extracted trees: `C:\src\factorio\_reference\{RealisticFusionPower_1.8.18, RealisticFusionPowerPort_1.9.0, RealisticFusionPowerPort_1.9.2}\`
- Base game read for comparison: `D:\SteamLibrary\steamapps\common\Factorio\data\base\` (`info.json` version 2.0.77)
- <https://wiki.factorio.com/Quality> and <https://wiki.factorio.com/Steam_turbine> — the two verified
  quality statements in §2.6
- <https://lua-api.factorio.com/2.0.77/prototypes/GeneratorPrototype.html> — checked for quality-related
  properties; there are none
- Prior survey: [`predecessor-survey.md`](predecessor-survey.md); decisions:
  [ADR 0001](../adr/0001-liftable-predecessor-material.md),
  [ADR 0002](../adr/0002-v1-scope-and-module-split.md),
  [ADR 0003](../adr/0003-space-age-tolerated-not-targeted.md)
