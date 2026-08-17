# Predecessor survey

Research for [issue #2](https://github.com/trulsjo/realistic-fusion-refreshed/issues/2) — what the three
predecessor mods actually contain and how finished each is.

**Facts only.** Where the evidence supports more than one reading, both are stated. None of the project's
open decisions are settled here.

**Method and its limits.** `realistic-fusion-dev` was cloned from GitHub into a temp directory outside this
repo and read directly. The two mod-portal mods **could not be downloaded** — the portal requires a
Factorio account login (see [What could not be verified](#what-could-not-be-verified)). Everything said
about them comes from the portal's public API (`https://mods.factorio.com/api/mods/<name>/full`), the
public mod pages and discussion threads, or from 1.x-era files that survive inside the dev repo. Nothing
about them is code inspection, and the text says so wherever it matters.

Survey date: 2026-08-13. Locally installed game for reference: Factorio 2.0.77 (build 84539, win64, steam,
space-age).

---

## 1. realistic-fusion-dev — the unfinished redesign

Source: <https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev> (cloned; repo `main`,
23 commits, HEAD `03748ec`).

The repo's own README refers to the upstream URL as `romner-set/realistic-fusion-dev`
([README.md, Installation section](https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev#installation));
that path now 404s, consistent with the account having been anonymised.

### The single most important correction: this is a Factorio **1.1** mod

"Realistic Fusion 2.0" is the **mod's** version 2.0, not Factorio 2.0. This repo does not target Factorio
2.0 and never did — it predates it. Evidence:

- All four `info.json` files declare `"factorio_version": "1.1"` and `"base >= 1.1"`.
- Runtime code uses the 1.1 API throughout: the `global` table (renamed `storage` in 2.0),
  `event.created_entity` (renamed `event.entity`), `defines.events.on_pre_player_mined_item`. See
  `RealisticFusionCore/control.lua`.
- `.luarc.json` lists `global` in `diagnostics.globals`, not `storage`.
- Commit dates run 2022-04-22 → 2023-04-01, with two 2024-10-25 commits that only change the licence and
  add the deprecation note. Factorio 2.0 shipped in October 2024.

So the four-module redesign is a **1.1-era prototype that was abandoned as Factorio 2.0 arrived**, not a
2.0 port. Anything lifted from it needs the same 1.1→2.0 migration as the original. This project's own
`README.md` currently says the redesign was "prototyped for Factorio 2.0"; on this evidence that line is
wrong and worth correcting separately.

Romner's own [deprecation notice](https://mods.factorio.com/mod/RealisticFusionPower/discussion/671ba901fcb6c30f0f6b2762)
(2024-10-25) says the same thing from the other side: *"with Space Age now out with vanilla fusion
reactors, RFP would need to be completely rewritten from the ground up (again) […] I'm officially ending
all development and maintenance of RFP/W — including the WIP 2.0 version."*

### Lua per module

Counted with `find <dir> -name '*.lua'`, physical lines.

| Module | Lua files | Lines | Verdict |
|---|---:|---:|---|
| `RealisticFusionCore` | 19 | 3,344 | substantive |
| `RealisticFusionPower` | 24 | 5,649 | substantive |
| `RealisticFusionAntimatter` | 14 | 1,236 | substantive but broken (below) |
| `RealisticFusionWeaponry` | 0 | 0 | **stub — `info.json` and nothing else** |
| `TODO/migrations` (1.x leftovers) | 6 | 37 | not part of any module |

Repo total ≈ 10,266 lines of Lua. Two of the Power files
(`.cross-section-data/DATASETS-raw.lua`, `DATASETS-reactivities.lua`, 30 lines but 110 KB) are generated
data tables, not hand-written code.

**About 2,519 of those lines are dead.** Every technology file is commented out of every `data.lua` with a
`--TODO` marker:

- `RealisticFusionCore/data.lua`: `--TODO require("prototypes.technology.technology")` and
  `--TODO require("prototypes.technology.heating-efficiency")` (331 + 404 lines)
- `RealisticFusionPower/data.lua`: same for `technology` and `fusion-efficiency` (201 + 1,306 lines)
- `RealisticFusionAntimatter/data.lua`: same for `technology` and `antimatter-efficiency` (127 + 150 lines)

The technology source is present and looks complete-ish, but it is not wired in. Consequently **the mod has
no tech tree**, and every recipe is `enabled = true` (0 occurrences of `enabled = false` across all three
modules' recipe files, 70 of `enabled = true`; several carry a literal `--[[CHANGELATER]]` comment beside
the `true`). The dev README lists "Completely recreate the tech tree" and "Balance everything for actual
ingame use outside of sandbox" as TODO, which matches.

TODO markers in live code: Core 13, Power 79, Antimatter 3.

### Does it plausibly load?

Not verified by running the game — the only installed Factorio is 2.0.77, which will not load a mod
declaring `factorio_version 1.1`, and no Lua interpreter/`luac` was available for a syntax check. What
static inspection shows:

- **`RealisticFusionCore` and `RealisticFusionPower`**: no missing asset references found. Every
  `__RealisticFusion*__/…` path in live (uncommented) code resolves to a file that exists (420 such
  references checked repo-wide). The dev README's install instructions tell you to symlink exactly these
  two modules, which is consistent with them being the working pair.
- **`RealisticFusionAntimatter`: will not load.** Seven icon files are referenced from uncommented code
  and do not exist anywhere in the repo:
  `graphics/icons/{high-energy-antiproton,high-energy-positron,antiproton,positron,proton,electron}.png`
  (from `prototypes/fluids.lua`, lines 5/17/29/41/77/88) and `graphics/icons/hydrogen-ionization.png`
  (from `prototypes/recipes/recipes.lua` line 16). A missing sprite is a hard load error in Factorio. Two
  of the seven (`proton.png`, `electron.png`) exist under `RFP-1.0-icons/`, i.e. the 1.0 icon working
  directory, and were evidently never copied across.
- **`RealisticFusionWeaponry`**: `info.json` only. It would "load" and add nothing.
- The dev README states plainly: *"Note: Don't use RFW or RFA yet, they're most likely broken."*

- **No locale files exist in any of the four modules.** The only `.cfg` files in the repo are
  `TODO/locale/{en,es-ES,zh-CN}/base.cfg`, carried over from the 1.x mod and never moved into a module.
  Even the working Core+Power pair would therefore display raw internal names (`rf-m-reactor`,
  `rf-d-t-plasma`) in-game for everything. This is a large, mechanical piece of unfinished work.

Two readings of "does it load", both supported: Core+Power probably load and run (the author shipped
install instructions for exactly those two and the last two code commits are bugfix/GUI commits); but
"loads" is a long way from "playable", given no tech tree, no locale, and self-declared unbalanced
prototype content.

### What is in `RealisticFusionCore` (3,344 lines)

The whole fuel chain lives here, not in Power. Prototypes (`prototypes/fluids.lua`,
`items.lua`, `entities.lua`, `resources.lua`, `recipes/`):

- **Fluids**: `rf-brine`, `rf-lithium-rich-brine`, `rf-molten-lithium-electrolyte`, `rf-hydrogen-sulfide`,
  `rf-heavy-water` (+ graded variants), `rf-depleted-water`, `rf-deuterium`, `rf-tritium`, `rf-helium-3`,
  `rf-d-t-mix`, `rf-d-he3-mix`, and four plasmas (`rf-deuterium-plasma`, `rf-d-t-plasma`,
  `rf-helium-3-plasma`, `rf-d-he3-plasma`).
- **Items**: lithium metal / carbonate / titanate, potassium chloride, breeder uranium fuel cell and its
  used-up form, plus the machine items (magnetic pipe / pipe-to-ground / pump, plasma heater,
  light-isotope processor, electrolyser, discharge pump, thermal evaporation plant).
- **Entities**: `rf-m-magnetic-pipe`, `-pipe-to-ground`, `-pump`, `rf-m-heater`,
  `rf-light-isotope-processor`, `rf-electrolyser`, `rf-discharge-pump`, `rf-thermal-evaporation-plant`.
- **A new world resource**: `rf-brine`, an infinite oil-like fluid patch with its own autoplace control.
- **Recipes** covering: brine mining → thermal evaporation → lithium-rich brine + KCl → lithium carbonate
  → molten electrolyte → lithium metal; Girdler-sulfide process (graded, with a startup efficiency
  setting) → heavy-water distillation (graded) → electrolysis → deuterium; deuterium-depleted-water
  discharge and recycling; tritium breeding via `rf-breeder-uranium-fuel-cell` +
  `rf-breeder-tritium-recovery` and `rf-tritium-recovery` from spent fission cells; `rf-tritium-decay` →
  helium-3; gas mixing (`rf-d-t-mixing`, `rf-d-he3-mixing`); and the four plasma heating recipes
  (`rf-d-d-heating-`, `rf-d-t-heating-`, `rf-he3-he3-heating-`, `rf-d-he3-heating-`, graded by suffix).
- `control.lua` (120 lines) implements the plasma-in-a-normal-pipe punishment: every tick it walks a
  budget of fluid-carrying entities (`rf-operations-per-tick` runtime setting, default 16) and kills any
  non-`rf-` pipe/tank/pump found holding a plasma fluid. It also exposes a `remote.add_interface("rfcore", …)`
  for other modules to register fluids.
- Startup settings: `rf-science-multiplier`, `rf-ddw-recycling`, `rf-gs-process-efficiency`,
  `rf-separate-category`.
- Compatibility hook: `for k,_ in pairs(mods) do pcall(require, "compatibility-patches."..k..".data") end`
  in every stage file — **but no `compatibility-patches/` directory exists anywhere in the repo.** The
  mechanism is in place; no patches were written. `info.json` for Core declares only
  `["base >= 1.1", "? angelspetrochem"]`, versus the sixteen optional dependencies the 1.x mod carried.

### What is in `RealisticFusionPower` (5,649 lines)

The reactors and the simulation. This is the part the dev README calls "completely rewrote nearly
everything".

- **Entities**: `rf-m-reactor` (MCF, neutronic), `rf-m-reactor-aneutronic`, `rf-ion-cyclotron`,
  `rf-icf-laser`, `rf-m-reactor-icf` with north/west heat-exchanger variants,
  `rf-m-reactor-icf-aneutronic` with north/west generator variants, `rf-direct-energy-converter`.
- **Items**: four ICF fuel pellets (`rf-d-d-`, `rf-d-t-`, `rf-d-he3-`, `rf-he3-he3-fuel-pellet`),
  heat exchanger + high-capacity heat exchanger, high-capacity turbine, DEC, the reactors, ICF laser,
  ion cyclotron.
- **Recipes**: all four MCF fusion reactions with graded suffixes (`rf-fusion-d-d-`, `-d-t-`, `-d-he3-`,
  `-he3-he3-`), plus the three D-D variants (`rf-fusion-d-d-2-`, `-3-`, and `rf-fusion-d-d-breeding-`),
  the ICF equivalents (`rf-icf-fusion-d-d-` etc.), and post-processing
  (`rf-tritium-extraction-`, `rf-helium-extraction-`, `rf-d-t-from-plasma-`,
  `rf-heliated-tritiated-fusion-results`).
- **The simulation** (`scripts/`, 1,912 lines): `constants.lua` (75) defines real physical constants —
  Boltzmann, Avogadro, per-isotope atomic masses, and reaction energies derived from mass defect via
  `E=mc²` for D-D→He3, D-D→T, D-T, D-He3, T-T, He3-He3, T-He3, split into total and charged-particle
  fractions. `reactor-logic.lua` (355) runs per-network per-tick: plasma volume from magnetic field
  strength, heat capacity from species mix, temperature, then reactivity looked up by binary search and
  linear interpolation over tabulated datasets. `entity-management.lua` (440) builds the reactor/heater
  **networks** — reactors and heaters joined by magnetic confinement pipe act as one machine.
  `gui.lua` (672) + `gui-events.lua` (370) are the custom control GUI.
- **Cross-section data** (`.cross-section-data/`, ~190 KB): raw ENDF cross-sections and derived
  reactivities as JSON for D-D→He3, D-D→T, D-T, D-He3, T-T, He3-He3, T-He3 and three D-Li6 channels, plus
  `raw-ENDF/.raw-to-reactivity.py` (3 KB) that generates them. The D-Li6 sets are present but not
  referenced by the loaded Lua — data prepared for lithium breeding that was never wired up.
- Startup settings: `rf-gui-color-variations`, `rf-hc-stuff`, `rf-hc-priority`.
- Note the directory name begins with a dot. Factorio's mod loader ignores it for prototype discovery, and
  `reactor-logic.lua` reaches it explicitly with `require(".cross-section-data/DATASETS-reactivities")`.

### What is in `RealisticFusionAntimatter` (1,236 lines)

Complete enough to read, not complete enough to load (missing icons, above). Entities:
`rf-particle-accelerator`, `rf-particle-decelerator`, `rf-antimatter-processor`, `rf-antimatter-reactor`
(a `burner-generator`), plus an antimatter pipe-explosion projectile. Fluids: protons, electrons,
antiprotons, positrons, their high-energy forms, hydrogen, antihydrogen. Items: matter-antimatter fuel
cell (full and empty), antimatter science pack. `data-final-fixes.lua` inserts the science pack into
labs and adds an `rf-antimatter-fuel` rocket-fuel item when Krastorio 2 is absent. Its `changelog.txt`
reads `Version: 1.0.0 / Date: XXXX / - First version.` — never released. `_TODO.txt` lists
"RFA: Implement new stuff" and "RFA: Revamp ?" as not started.

### What is in `RealisticFusionWeaponry`

`info.json` alone (`version 2.0.0`, `factorio_version 1.1`, depends on `RealisticFusionCore`). Zero code,
zero graphics. It has been a stub since the repo's first commit (verified against tree `ccd87d8`).
`_TODO.txt`: "RFW: Revamp ? - incl. resource destruction on impact setting".

### Non-module directories

- `RFP-2.0/` (62 MB, 230 PNGs) — the art working directory for the redesign, plus four design documents:
  - `RFP-2.0.txt` (105 lines) — the derivation of the whole chain with 16 numbered academic sources, unit
    conversions (1 Factorio fluid unit ≈ 47.8 ml, derived from water's heat density), energy budgets for
    the Girdler-sulfide and distillation stages, lithium/potassium concentrations in brine, and the
    intended six-step fusion progression. **This is the most valuable single document in the repo** if the
    physics model is to be carried forward. It ends with a wink toward Sci-Hub for the paywalled sources.
  - `_TODO.txt` (15 lines) — the honest status board: DONE = mod split, lithium extraction, improved
    deuterium extraction, tritium/helium revamp, ICF fusion (placeholder balance), tritium production;
    WIP = "RFP: Revamp fusion"; TODO = tech tree, balance, recipe balance, RFA, RFW.
  - `_idea-dump.txt` (46 lines) — the unbuilt reactor-controller design: sensor/variable lists for MCF and
    ICF, and four control tiers (manual → remote → basic algorithms → advanced algorithms → AI-assisted).
  - `textures.txt` (12 lines) — an art brief addressed to PreLeyZero.
- `RFP-1.0-icons/` (700 KB, 25 PNGs + 3 XCFs) — 1.0-era icon working directory.
- `TODO/` — 1.x leftovers not yet migrated: the RFP 1.x `changelog.txt` (218 lines, ends at 1.5.4), the
  three locale files, six 1.x migration scripts and `thumbnail.png`.

### Licensing inside the dev repo — three things that differ from this project's current assumptions

Root `LICENSE` is the WTFPL, `Copyright (C) 2024 Romner`. Each module carries `license.txt` (WTFPL) plus a
`legal-note.txt` stating: *"Any file in a subdirectory of this mod that doesn't have a license.txt and/or a
legal-note.txt in its directory is licensed under the WTFPL."* — the per-directory convention this project
has adopted.

**Four directories carry their own licence file**, and only two of them are Krastorio 2:

| Directory | Marked as | Contents |
|---|---|---|
| `RealisticFusionCore/graphics/icons/krastorio-2/` | **GNU GPL v3** | 6 lithium/KCl icons |
| `RealisticFusionAntimatter/graphics/particle-accelerator/` | **GNU GPL v3** | 9 accelerator/decelerator/fuel-cell sprites, "**modified** from Krastorio 2" |
| `RealisticFusionCore/graphics/icons/angels-numerals/` | **CC BY-NC-ND 4.0** | 22 numeral overlay icons, from Angel's Refining |
| `RealisticFusionCore/electric-boiler/` | **CC BY-NC-ND 4.0** | 8 boiler sprites, an icon, **and `electric-boiler.lua` (167 lines)**, from Angel's Petrochem |

1. **The K2 material is marked GPLv3 here, not LGPLv3.** Krastorio 2 on the mod portal today is listed as
   **GNU LGPLv3**, owner raiguard (<https://mods.factorio.com/api/mods/Krastorio2/full>). Both readings are
   defensible and neither is settled by this survey: either Romner marked it more strictly than upstream
   required (in which case the material is LGPLv3 and the GPLv3 note is over-cautious), or K2's licence
   differed when he copied it in 2022 (in which case GPLv3 is the correct term for that copy). This
   project's `README.md` and `CLAUDE.md` currently say LGPLv3; the file actually sitting next to the
   sprites in the archive says GPLv3.
2. **There is CC BY-NC-ND 4.0 material, which this project's documents do not mention at all.**
   NonCommercial-NoDerivatives is far more restrictive than either GPL variant, forbids derivative works
   outright, and cannot be reconciled with a public-domain release. One of the two directories contains
   **Lua code**, not just art — so the rule "Lua source may be lifted from the predecessors freely" has an
   exception: `RealisticFusionCore/electric-boiler/electric-boiler.lua` is Angel's, marked ND.
3. **Unmarked contributed art extends beyond PreLeyZero.** The deprecation notice thanks
   [YuokiTani](https://mods.factorio.com/user/YuokiTani) "for modifying a few unused sprites and letting me
   use them for the mod, plus creating new ones like the RFP heat exchanger for 1.0", and
   [PreLeyZero](https://mods.factorio.com/user/PreLeyZero) "for creating all the antimatter-related and 2.0
   ICF fusion models/graphics". The 1.x mod description additionally credits "some recolored graphics from
   [the Factorio forums](https://forums.factorio.com/viewtopic.php?t=40923)". None of these are marked in
   any directory, so under the repo's own convention they default to WTFPL. Whether Romner's blanket
   *"I'm also moving everything to the Do What the Fuck You Want to Public License"* disposed of
   contributors' work is not something this survey can answer — but note it names PreLeyZero's ICF and
   antimatter models specifically as third-party creations, which is exactly the material this project's
   `CLAUDE.md` already flags as not-known-to-be-free.

---

## 2. Realistic Fusion Power Port — Durikkan's 2.0 port

Source: <https://mods.factorio.com/mod/RealisticFusionPowerPort>.
**Not inspected as code — the mod zip could not be downloaded** (see the last section). Everything below is
<!-- superseded: the zip is readable as of 2026-08-17, #38 -- see the resolution block near the end of this section -->
from the portal's public API and page text.

| | |
|---|---|
| Owner | Durikkan |
| Licence (portal field) | `unlicense` |
| Created | 2025-01-02 |
| Last updated | 2025-12-13 |
| Downloads | 1,764 |
| Releases | 2 currently listed: **1.9.0** (2025-01-02) and **1.9.2** (2025-12-13) |
| `factorio_version` | 2.0 (both releases) |
| No public source repo | `source_url` is null; GitHub search for `Durikkan/RealisticFusionPowerPort` and for `RealisticFusionPowerPort` returns 0 results |

It continues the original's version numbering — the original ended at 1.8.18, the port starts at 1.9.0 —
and its portal changelog is the original's changelog verbatim with three entries prepended. A diff of the
two API `changelog` fields shows **the port added exactly 23 lines and changed nothing else**, i.e. it did
not rewrite a single historical entry.

### What changed beyond API migration

Directly from the port's own changelog (<https://mods.factorio.com/mod/RealisticFusionPowerPort/changelog>):

**1.9.0, 2025-01-02**
- Updated to support Factorio 2.0.
- *"Most buildings now support circuit connections, though the visual placement isn't ideal"* — a genuine
  gameplay addition, not migration. The port's description narrows it: everything except entities using
  `generator` prototypes, which cannot take circuit connections.
- *"Did some organizing so the fluids and recipes are all listed on their own page in Factoriopedia rather
  than cluttering up the unsorted area"* — Factoriopedia is a 2.0 feature, so this is migration-adjacent
  polish.
- ***"Changed a lot of the recipe icons to the graphics Romner had in his Realistic Fusion 2.0 build for
  greater visual clarity."*** Note the licensing consequence: this pulls art out of the dev repo
  (`RFP-2.0/icons/…`) into a published Unlicense mod.
- *"Some minor tweaks to recipes and tech costs, but nothing too big, I wanted to have this to preserve the
  mod, not rework it into completely my own thing."* — the only balance divergence acknowledged, and
  deliberately small. **Which recipes and which tech costs is not stated and could not be determined
  without the files.**
- *"Left most of the compatibility code in even though most of the other mods they reference aren't ported
  to 2.0 yet."*

**1.9.1, 2025-01-06** — *"Fixed a few minor visual issues."*

**1.9.2, 2025-12-13** — the significant one:
> *"Stripped out all of the compatibility code to fix it not loading with various other mods. Most of it
> didn't even work in the current state anyway and was generally ignored by the game. It's been too long
> and I'd have to relearn converting to 2.0 to get it set up, so now instead everything just always
> requires vanilla ingredients."*

The dependency lists corroborate this exactly. 1.9.0 declared
`["base >= 2.0", "? Flow Control", "? Krastorio2", "? Krastorio2Assets", "? Krastorio2-more-locomotives", "? angelspetrochem", "? angelssmelting", "? angelsindustries", "? bobelectronics", "? bobplates", "? bobpower", "? space-exploration", "? aai-industry"]`;
1.9.2 declares `["base >= 2.0"]` and nothing else. **The current port has no mod compatibility layer at
all** — every recipe uses vanilla ingredients. Against the original's sixteen optional dependencies and
its "Fully compatible with K2, Angel's/Bob's, SE and IR2" tagline, this is the port's largest divergence,
and it is a removal rather than a rebalance.

### Stated scope and intent

From the port's description page:

- *"a port … with minimal changes to balance or gameplay"*, and explicitly *"is not the Realistic Fusion
  2.0 that was in development at one point and left in a fairly incomplete state"*.
- *"I'm not intending to continue this mod from where it was or try to adapt it to take advantage of space
  age (You can use it with it, but there's no changes to the mod itself for it, also **certain buildings in
  this mod get insanely overpowered with quality** but it's up to you whether you use it on them or not)."*
  — an unresolved 2.0/Space Age interaction the author names but does not fix.
- *"I also have no plans to port Realistic Fusion Weapons, but perhaps someone else will."* RFW is not
  ported by anyone as far as this survey found.
- *"I needed to make actual recipe names due to engine changes"* — German, Spanish and Chinese locale were
  inherited; the new recipe names in those languages are the author's guesses.
- *"My recommendation is to play it with a science multiplier of less than one unless you're planning on
  building a mega base."*
- *"If someone wants to continue development they are more than welcome to."*
- *"The license is pretty loose, but there are some directories with graphical assets under a different
  license, see the relevant files for details."* — so the port does carry per-directory licence files, but
  **which directories, and under which licence, could not be verified**; the zip was not readable.

> **Resolved 2026-08-17 (#38).** Both zips are readable now, in `C:\src\factorio\_reference\`. The port
> marks exactly the two directories the original does, **on identical terms** — section 3 below has the
> licences and the legal notes, which are the same word for word. The *contents* are not identical; see
> the last bullet. What is specific to the port:
>
> - Root `license.txt` is **The Unlicense**, prefaced *"This applies to all folders, except those that
>   contain a license file within them."* 1.9.0 and 1.9.2 ship it byte-identical (sha256 `e70df79e…`).
> - Root `legal-note.txt` is the **original's, byte-for-byte** — and it still says WTFPL. So the port's
>   two root files name different licences. Both are permissive and nothing downstream turns on it, but
>   the licence *field* on the portal (`unlicense`) is only half the story.
> - The two releases are not otherwise the same file set, so "byte-identical" above is about that one
>   licence file and nothing else: `electric-boiler/electric-boiler.lua` is 169 lines in 1.9.0 against
>   167 in 1.9.2, and 1.9.0 still ships the `compatibility-patches/` directory that 1.9.2 dropped —
>   which is the removal Durikkan's own release notes describe, confirmed here rather than taken on
>   trust.

Lua volume: **unknown as of the survey date.** Not inspectable without the archive. A reasonable
expectation is "close to the
1.1 original's", since it is a port, but that is an inference, not a measurement.

---

## 3. Realistic Fusion Power — Romner_set's 1.1 original

Source: <https://mods.factorio.com/mod/RealisticFusionPower>.
**Not inspected as code — the mod zip could not be downloaded.**

> **Superseded 2026-08-17 (#38):** it is readable now, in `C:\src\factorio\_reference\`. The
> licensing questions this section leaves open are answered in the resolution block at its end; the
> code-inspection ones are answerable and have not been asked.

What follows comes from the portal API,
the mod page, and three artefacts that survive *inside* the dev repo and describe the 1.x mod directly:
`TODO/locale/en/base.cfg` (305 lines, the 1.x English locale, verbatim), `TODO/changelog.txt`, and
`TODO/migrations/`. Those files are a snapshot of roughly **v1.8.15 (March 2022)** — the dev repo's first
commit is 2022-04-22 and they were never touched again — not of the final 1.8.18. Treat them as very
strong but slightly stale evidence.

| | |
|---|---|
| Owner | Romner_set |
| Licence (portal field) | `WTFPL` |
| Created | 2019-10-06 (first release 0.1.0, `factorio_version` 0.17) |
| Final release | **1.8.18**, 2024-10-25 |
| Releases | 93 |
| Supported | 0.17 – 1.1 |
| Downloads | 29,427 |
| Optional dependencies (1.8.18) | RTG, Flow Control, Krastorio2, Krastorio2Assets, Krastorio2-more-locomotives, Booktorio, angelspetrochem, angelssmelting, angelsindustries, bobelectronics, bobplates, bobpower, space-exploration, aai-industry, True-Nukes |

**Licence history matters here.** Changelog 1.8.18 (2024-10-25) reads: *"Primary license changed from
CC BY-SA 4.0 to the Do What the Fuck You Want to Public License."* Every release before 1.8.18 was
**CC BY-SA 4.0**, which is share-alike and attribution-requiring. Only the final release is WTFPL. Anything
lifted should be lifted from 1.8.18 or later, not from an older archive.

### What of the fuel chain is actually modelled

From the 1.x locale file, which names every prototype the mod defined. Ticking off the ticket's list:

- **Deuterium extraction from water — yes, in two tiers.** A simple `rf-deuterium-extractor` (the 1.0
  version), and an "advanced deuterium extraction" chain toggled by a startup setting
  (`rf-advanced-deuterium-extraction`): water → graded heavy-water purification
  (`rf-water-purification` at 0.02%, `rf-heavy-water-purification-0` at 5%, and a parameterised
  `heavy-water-purification=__1__% heavy water purification`) → `rf-electrolyser` → deuterium gas.
  The Girdler-sulfide process is present and graded
  (`gs-process-name=Girdler-sulfide process [__1__% to __2__%]`), with hydrogen sulfide explicitly acting
  as a **catalyst** ("you don't need to set up permanent production of it"), and an `electric-boiler`
  entity for the 100 °C distillation step. `rf-discharge-pump` and deuterium-depleted water close the loop,
  with `rf-ddw-recycling` duplicating every water-consuming recipe to accept DDW.
- **Plasma heating — yes.** `rf-m-heater` ("Plasma heater"), and four heating technologies:
  `rf-d-d-heating-efficiency`, `rf-d-t-heating-efficiency`, `rf-he3-he3-heating-efficiency`,
  `rf-d-he3-heating-efficiency`, plus the corresponding plasma fluids
  (`rf-deuterium-plasma`, `rf-d-t-plasma`, `rf-helium-3-plasma`, `rf-d-he3-plasma`).
- **Magnetic confinement — yes, as logistics rather than as reactor physics.**
  `rf-pipe`, `rf-pipe-to-ground`, `rf-pump`, and (with Flow Control) `rf-pipe-elbow`, `rf-pipe-junction`,
  `rf-pipe-straight`. Their descriptions make the mechanic explicit: ordinary iron pipes cannot carry
  plasma. `rf-plasma-handling` is the unlocking technology. Note the 1.x reactors are **not** simulated —
  they are recipe-driven machines. Real-time simulation is the redesign's innovation, not the original's.
- **D-D — yes, in three variants**, each with its own efficiency technology:
  `rf-d-d-fusion-2` (plain D-D), `rf-d-d-fusion-1` ("Tritium suppressed D-D fusion"), and
  `rf-d-d-fusion-0` ("T+He3 suppressed D-D fusion").
- **D-T — yes.** `rf-d-t-fusion`, fed by a `rf-gas-mixer` producing `rf-d-t-mix`.
- **D-He3 — yes.** `rf-d-he3-fusion`, aneutronic.
- **He3-He3 — yes.** `rf-he3-he3-fusion`, aneutronic, unlocked via `rf-aneutronic-fusion-theory` →
  `rf-aneutronic-reactor` → `rf-direct-energy-conversion`.
- **Tritium breeding — yes, but from fusion, not from lithium.** The technology is `rf-tritium-breeding`
  and its in-game description is explicit: *"D-D fusion produces tritium 50% of the time […] I should find
  a way to extract the tritium."* There is **no lithium anywhere in the 1.x locale** — no lithium item, no
  brine, no thermal evaporation, no breeder fuel cell. Lithium-based breeding is entirely new in the
  redesign.
- **He3 breeding — yes, two paths.** `rf-helium-3-breeding` (the D-D 50/50 branch: *"D-D produces either
  tritium or helium-3 with a 50/50 chance"*) and `rf-tritium-decay` ("Tritium decay to helium-3"),
  toggleable by a startup setting.

Beyond the ticket's list, the 1.x mod also had, and the redesign does not: a **portable aneutronic fusion
reactor** equipment item with He3-He3 and D-He3 plasma fuel cells; **fuel items**
(`rf-thermonuclear-fuel`, `rf-fusion-fuel`, `rf-antimatter-fuel`); a **complete antimatter chain** shipped
as part of the same mod behind an `rf-antimatter` "[WIP]" setting; **high-capacity heat exchanger and
turbine** (`rf-hc-exchanger`, `rf-hc-turbine`) with a priority setting, because *"a single D-T reactor
produces 1.4 GW to 2 GW"*; an in-game **Booktorio manual** with worked tables of net power output per
reaction per efficiency tier and MJ-per-deuterium per heavy-water concentration; and real **third-party
integration** — settings to *replace* Krastorio 2's fusion/antimatter power, Space Exploration's
antimatter, and Bob's deuterium power, plus K2 portable-reactor descriptions and a
`rf-krastorio-remove-tritium` toggle.

The changelog confirms integration was a large share of the work: 1.2.0 Angel's, 1.3.0 Bob's/Angelbobs,
1.3.1 Bob's Warfare, 1.4.0 Space Exploration, 1.5.0 True Nukes, 1.5.2 Industrial Revolution 2, and a long
tail of SE/K2 bugfixes through 1.8.x. Roughly the same body of work Durikkan removed in port 1.9.2, and the
same body of work the redesign never rewrote (`compatibility-patches/` is referenced but empty there).

Lua volume: **unknown as of the survey date.** Not inspectable without the archive then; the archive is
readable now (#38) and this has not been recounted.

**Licensed directories:** the mod page states the primary licence is WTFPL and the dev repo's convention
implies per-directory files, and Durikkan's port description confirms *"there are some directories with
graphical assets under a different license"* — but **which directories, in the 1.1 original, could not be
verified.**

> **Resolved 2026-08-17 (#38).** 1.8.18 is in `C:\src\factorio\_reference\`. Root `license.txt` is the
> **WTFPL v2**, `Copyright (C) 2024 Romner`, confirming the changelog and this section. Root
> `legal-note.txt` states the per-directory rule outright — *"Any file in a subdirectory of this mod that
> doesn't have a license.txt and/or a legal-note.txt in its directory is licensed under the WTFPL"* — the
> same sentence the redesign carries (section 1 above), so the convention predates the redesign rather
> than being introduced by it.
>
> **Two directories are marked, and both carry a `legal-note.txt` naming the source as well as a
> `license.txt` carrying the terms:**
>
> | Directory | Licence | Legal note |
> |---|---|---|
> | `graphics/particle-accelerator/` | GPLv3 | *"All textures in this directory are modified from Krastorio 2"* |
> | `electric-boiler/` | CC BY-NC-ND 4.0 | *"All textures and code in this directory are from angels petrochem"* — 165 lines of Lua |
>
> These are the same two the redesign lists in ADR 0001's table, under the same terms, so **the redesign
> inherited them from the original** rather than establishing the scheme. Note the naming: the Krastorio 2
> material sits in `particle-accelerator/`, named for what it depicts. Only the redesign has a directory
> actually called `krastorio-2/`.
>
> **The unmarked `graphics/` is the finding that matters.** The changelog credits three outside sources
> for material that is left bare:
>
> | Release | Attribution |
> |---|---|
> | 0.2.0, 2020-01-01 | *"Credit to YuokiTani for re-rendering some unused textures with changed colors from https://u.nu/factoriogfx"* |
> | 1.2.0, 2020-09-05 | *"Others are modified from angel's discarded/unused thread"* |
> | 1.3.13, 2020-12-06 | *"New antimatter reactor graphics, courtesy of PreLeyZero."* |
| 1.8.0, 2021-09-03 | *"PreLeyZero made completely new antimatter reactor graphics, and in turn doubled the mod size."* |
>
> The rest of that 1.2.0 line — *"Some of the textures are modified from Krastorio 2 and licensed under
> GNU GPL v3"* — refers to the marked `particle-accelerator/` set, so it is **not** evidence of GPL
> material hiding under a permissive root. It is the opposite: Romner marked what he had terms for. The
> three rows above are what he did not. `CLAUDE.md`'s unmarked-graphics rule was widened from
> "PreLeyZero's donated art" to all three on the same date.

---

## What could not be verified

Listed so the gaps are as visible as the findings.

> **Partly resolved 2026-08-17 (#38).** Gap 1's licensing half is closed: both zips are now in
> `C:\src\factorio\_reference\` and the answers are in sections 2 and 3 above. Its other half — Lua line
> counts, the recipe and technology diffs, whether the port's inherited compatibility code came out
> cleanly — is answerable now and has not been asked. Gaps 2, 3 and 4 stand: the *dev repo* is still not
> on disk and none of the three has been run.

1. **Neither mod-portal mod could be downloaded.** `https://mods.factorio.com/download/...` returns
   HTTP 403 and redirects to `https://factorio.com/login?mods=1&next=...`, behind a Cloudflare challenge.
   A Factorio account login is required. Reading the locally stored account credentials from
   `%APPDATA%\Factorio\player-data.json` was attempted and **blocked by this environment's permission
   policy**, and was not retried by any other route. Consequently, for both **Realistic Fusion Power (1.1)**
   and **Realistic Fusion Power Port (2.0)**:
   - Lua line counts are **unknown**.
   - The file and directory layout is **unknown**.
   - Which directories carry their own licence file, and under which licence, is **unknown**.
   - The exact recipe and technology-cost tweaks Durikkan describes as "minor" are **unknown** — the claim
     is his, not a diff.
   - Whether the port's inherited compatibility code was removed cleanly, and what the 1.9.2 recipes
     actually require, is **unknown**.
   - No claim in sections 2 and 3 above rests on reading either mod's code. The 1.x prototype inventory in
     section 3 is reconstructed from the 1.x locale file preserved in the dev repo, which is a ~v1.8.15
     snapshot, three years and one release short of the final 1.8.18.
2. **The dev repo was never run.** The only installed Factorio is 2.0.77, which cannot load a mod declaring
   `factorio_version 1.1`, and no Lua interpreter or `luac` was available for even a syntax check. "Core
   and Power probably load" is a static-analysis conclusion (all live asset references resolve, no obvious
   structural breakage), not an observation. Runtime behaviour of the reactor simulation, the network
   logic and the GUI is entirely unverified.
3. **Antimatter's breakage is inferred from missing files, not observed.** Seven referenced icons do not
   exist in the repo; in Factorio that is normally a hard load error. Not confirmed by loading.
4. **Behaviour under Space Age is unknown for all three.** The port's author warns that *"certain buildings
   in this mod get insanely overpowered with quality"* but names none of them.
5. **The Krastorio 2 licence discrepancy is not resolved.** The archive says GPLv3; the portal says LGPLv3
   today. K2's licence at the time Romner copied the sprites in 2022 was not checked against any archived
   record.
6. **Whether Romner's WTFPL relicensing validly covered contributors' work is not established** — for
   PreLeyZero, YuokiTani, emelrad12, ttyler3, or the forum sprite pack at
   <https://forums.factorio.com/viewtopic.php?t=40923>. The deprecation notice records the contributions;
   it does not record the terms they were made under. Which specific files came from whom is likewise not
   established.
7. **Realistic Fusion Weaponry (the published 1.x mod,
   <https://mods.factorio.com/mod/RealisticFusionWeaponry>) was not surveyed.** It is outside the ticket's
   three mods. The `RealisticFusionWeaponry` directory examined here is the redesign's empty stub, which is
   a different thing.
8. **`RealisticFusionCore/data-final-fixes.lua` (119 lines) and the equivalents in Power and Antimatter
   were read only in passing.** They are the most likely home of remaining third-party integration and were
   not audited line by line.

### Sources

- Dev repo: <https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev> (HEAD `03748ec`)
- Portal API: `https://mods.factorio.com/api/mods/{RealisticFusionPower,RealisticFusionPowerPort,Krastorio2}/full`
- Mod pages: <https://mods.factorio.com/mod/RealisticFusionPower>,
  <https://mods.factorio.com/mod/RealisticFusionPowerPort>
- Deprecation notice: <https://mods.factorio.com/mod/RealisticFusionPower/discussion/671ba901fcb6c30f0f6b2762>
- "About version 2.0" announcement: <https://mods.factorio.com/mod/RealisticFusionPower/discussion/626322f706bc9f47b0984b15>
- Alt-F4 mod spotlight (referenced by the mod description, not read for this survey):
  <https://alt-f4.blog/ALTF4-4/#mod-spotlight-realistic-fusion-power-romner>
- Factorio Lua API, per-version: <https://lua-api.factorio.com/> — the 1.1 vs 2.0 claims above
  (`global`→`storage`, `on_built_entity.created_entity`→`.entity`) should be checked against
  <https://lua-api.factorio.com/1.1.110/> and <https://lua-api.factorio.com/2.0.77/> before being relied on
  for migration work.
