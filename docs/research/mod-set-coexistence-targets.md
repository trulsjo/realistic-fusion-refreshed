# Mod-set coexistence targets

Research for the extension of [issue #33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33)
("Coexistence verification: Space Age and Krastorio 2") to a wider set of mods — which mod families
actually exist on Factorio 2.x, what their internal names and current versions are, and what a complete
enable-list for each would be.

**Facts only.** Where the evidence supports more than one reading, both are stated. **None of the
project's open decisions are settled here** — CLAUDE.md is explicit that scope and mod-compatibility
targets are Truls's to choose. What follows is an inventory with trade-offs, not a recommendation, and
no set below is proposed for adoption.

**Method and its limits.** Every version, dependency and `factorio_version` claim comes from the mod
portal's public JSON API (`https://mods.factorio.com/api/mods/<name>/full`), fetched directly with
`curl` on the survey date and read as JSON rather than through a page scrape. That endpoint needs no
login (see [Mechanics](#mechanics-getting-these-mods-into-a-load-check)). Dependency closures were
computed mechanically from those `info_json.dependencies` arrays, following the prefix rules quoted
below. Statements of *intent* ("does not properly support Space Age") come from the `description` and
`changelog` fields of the same API responses, which are the mod pages' own text. The predecessor's
patch targets were read from the local archive at `C:\src\factorio\_reference\`.

**Nothing here was loaded in the game.** No mod below was downloaded, installed, or run. "Viable"
throughout means *the portal has a release whose declared `factorio_version` and dependencies are
satisfiable*, which is a strictly weaker claim than "loads" and much weaker than "plays".

Survey date: **2026-08-18**. Locally installed game: **Factorio 2.0.77** (the version
`scripts/factorio-lib.ps1` resolves by default). That version number turns out to matter more than
anything else here — see [The 2.0/2.1 wall](#the-2021-wall-the-single-most-decision-relevant-fact).

---

## Dependency prefix rules, quoted

Every list below is derived by these rules, so they are worth stating exactly. From the Factorio API
documentation, [`auxiliary/mod-structure.html`](https://lua-api.factorio.com/latest/auxiliary/mod-structure.html)
(page reports Factorio **2.1.14**):

> The possible prefixes are:
> - `!` for incompatibility
> - `?` for an optional dependency
> - `+` for a recommended dependency
> - `(?)` for a hidden optional dependency
> - `~` for a dependency that does not affect load order
> - no prefix for a hard requirement for the other mod

Two consequences for the lists below:

- **A closure is built from no-prefix and `~` entries only.** `~` is still a hard requirement; it only
  waives load-ordering. Angel's four graphics mods are declared `~`, so they are required despite
  looking optional at a glance.
- **`+` is *not* required.** It is a recommendation the portal surfaces but the game does not enforce.
  This matters most for SeaBlock NG, where `SeaBlockPack` — effectively the whole modpack — is declared
  `+` by `SeaBlockWanne`, so the "minimal" and "as-intended" readings of that set differ by 23 mods.
  The `+` prefix is **not** documented in the 2.0.77 version of the same page; it appears only in the
  2.1 documentation.

  > **Corrected 2026-08-26 (#59, [ADR 0026](../adr/0026-third-party-mods-are-pinned-to-their-2-0-line.md)).**
  > That `+` declaration belongs to `SeaBlockWanne` **1.1.4**, which is `factorio_version` 2.1.
  > **The 2.0 release this project pins — 1.0.5 — names no `SeaBlockPack` at all**, and at 2.0 the
  > dependency runs the other way: `SeaBlockPack` requires `SeaBlockWanne`. So on the 2.0 line the
  > minimal closure is **9 mods** and the pack closure is **46**, not the 9-versus-32 recorded below.
  > The figures further down describe the 2.1 releases surveyed on 2026-08-18 and are left as that
  > record; ADR 0026 carries the pinned numbers.

---

## The 2.0/2.1 wall — the single most decision-relevant fact

Also from `mod-structure.html`, on `factorio_version`, verbatim:

> Factorio's releases are categorized into major versions, which are indicated by the first two numbers
> in their version string (which notably does not follow SemVer). As an example, Factorio 1.1.110 is
> part of the 1.1 major version. Mods can only be compatible with one major version, not multiple.
> A `factorio_version` of `"2.0"` indicates support for all releases under that major version, **and no
> other major releases**. Even if a mod would otherwise work on a newer major release, this field needs
> to be updated to explicitly mark it as compatible.

So **2.0 and 2.1 are different major versions**, and a mod declaring one will not load on the other.

**Every overhaul family in this document has moved to `factorio_version` 2.1 in its current release.**
Krastorio 2 is 2.1.2 (`base >= 2.1.7`); Angel's is 2.1.x (`base >= 2.1.0`); Bob's is 3.0.x
(`base >= 2.1.0`); Space Exploration is 0.7.61 (`base >= 2.1.7`); MadClown's is 2.1.01; SeaBlock NG is
1.1.4. **None of them will load on the Factorio 2.0.77 this repository currently checks against.**

That leaves exactly two routes, and choosing between them is a decision, not a finding:

> **Decided 2026-08-26 (#59, [ADR 0026](../adr/0026-third-party-mods-are-pinned-to-their-2-0-line.md)):
> the second route.** Pin the last `factorio_version` 2.0 release of each family; do not move to 2.1
> while it is still the experimental branch. The pins live in `scripts/fetch-mods.ps1`'s `$MOD_SETS`
> as data, derived from the portal API rather than transcribed from this table.

| Route | What it costs | What it buys |
|---|---|---|
| **Upgrade the checking install to Factorio 2.1.x** | This repo's own mods declare `factorio_version` 2.0 and would need bumping and re-verifying; `load-check.ps1`'s ten invariants and every `check-*.ps1` rig would be re-run against a game version nothing here has been tested on; the bundled trio changes version with the game | Every set below is testable at its current, maintained release |
| **Pin the last `factorio_version` 2.0 release of each family** | Stale mods, some by a year; the released state is not what players run today; two families (SeaBlock NG, MadClown's) have 2.0 lines that are visibly mid-development | The existing 2.0.77 install and every current check keep working unchanged |

The last `factorio_version` 2.0 release of each family, with the `base >=` it declares, for the pinning
route. All of these satisfy `base >= 2.0.77`:

| Mod | Last fv=2.0 release | declares `base >=` |
|---|---|---|
| `Krastorio2` | 2.0.19 | 2.0.72 |
| `angelsrefining` | 2.0.4 | 2.0.0 |
| `angelspetrochem` | 2.0.3 | 2.0.48 |
| `angelssmelting` | 2.0.5 | unstated |
| `angelsbioprocessing` | 2.0.3 | unstated |
| `boblibrary` | 2.1.0 | 2.0.49 |
| `bobplates` | 2.1.1 | 2.0.33 |
| `space-exploration` | 0.7.57 | 2.0.76 |
| `Clowns-Processing` | 2.0.14 | unstated |
| `SeaBlockWanne` (SeaBlock NG) | 1.0.5 | 2.0.0 |
| `Flow Control` | 3.2.3 | 2.0.8 |
| `underground-pipe-pack` (Advanced Fluid Handling) | 2.0.6 | 2.0.48 |
| `RITEG` | 1.3.11 | unstated (`base`, no bound) |

Note the version-numbering trap in the Bob's rows: **Bob's 2.1.x is a `factorio_version` 2.0 mod** and
Bob's 3.0.x is the 2.1 one. The mod's version number and the game's major version move independently
and happen to collide here.

---

## Viability at a glance

"Viable" = a release exists whose `factorio_version` is 2.0 or 2.1 and whose hard dependencies all
resolve to such releases. It does **not** mean tested, and it does not mean the set plays.

| Requested set | Viable on 2.x? | At which `factorio_version` | Note |
|---|---|---|---|
| Space Age | **Yes** | ships with the game (2.0.77 here) | bundled, not from the portal |
| Krastorio 2 | **Yes** | 2.1 current; 2.0 line exists | K2 states SA support is broken — below |
| Space Exploration | **Yes** | 2.1 current; 2.0 line exists | **declares `! space-age`** |
| Krastorio 2 + Space Exploration | **Yes, and declared** | 2.1 | SE declares `(?) Krastorio2 >= 2.0.10`; no `!` either way |
| Angel's | **Partly** | 2.1 current | core four only; **Industries and Exploration are 1.1, deprecated** |
| Angel's + Space Age | **Yes, mechanically** | 2.1 | nothing declared either way; see below |
| Bob's | **Yes** | 2.1 current (mod v3.0.x) | full 18-mod set alive |
| Bob's + Space Age | **Yes, and declared** | 2.1 | ten Bob's mods declare `? space-age` / `(?) space-age` |
| Angel's + Bob's | **Yes** | 2.1 | 26 mods, no declared conflict |
| Angel's + Bob's + Space Age | **Yes, mechanically** | 2.1 | Angel's half is silent on SA |
| Angel's + Bob's + MadClown's | **Yes** | 2.1 | four Clowns mods alive; **`Clowns-Science` is 1.1 only** |
| … + Space Age | **Yes, mechanically** | 2.1 | same caveat |
| SeaBlock NG | **Yes** | 2.1 | **declares `! space-age` and `! Krastorio2`** |
| RITEG | **Yes** | **2.0 only** — never got a 2.1 release | not the `RTG` the predecessor patched |
| Advanced Fluid Handling | **Yes** | 2.1 current; 2.0 line exists | slug is `underground-pipe-pack` |

Sets that are **impossible** as requested, at any version:

- **SeaBlock NG + Space Age** — `SeaBlockWanne` declares `! space-age` outright.
- **SeaBlock NG + Krastorio 2** — `SeaBlockWanne` declares `! Krastorio2` outright.
- **Space Exploration + Space Age** — `space-exploration` declares `! space-age`.
- **Space Exploration + Angel's/Bob's** — `space-exploration` declares `!` against
  `angelsindustries`, `angelspetrochem`, `angelsrefining`, `angelssmelting`, `bobelectronics`,
  `bobores`, `bobplates`, `bobpower`, `bobrevamp`, `bobtech`, `bobvehicleequipment`, `bobwarfare`,
  `bobmodules`, and `SeaBlock`. This is not in the requested list but rules out an obvious follow-up.
- **Krastorio 2 + MadClown's Nuclear** — `Krastorio2` declares `! Clowns-Nuclear`.
- **Krastorio 2 + `bobequipment` / `bobvehicleequipment`** — declared `!` by `Krastorio2`, so
  "K2 + the full Bob's set" is not a set that can be enabled; two members must be dropped.

---

## The families

### Space Age — bundled, not from the portal

`space-age`, `elevated-rails` and `quality` ship inside the game's `data/` directory and are all
version **2.0.77** on this machine, matching the base game. `space-age` declares
`base >= 2.0.0, elevated-rails >= 2.0.0, quality >= 2.0.0`.

They are already handled: `Get-BundledMods` in `scripts/factorio-lib.ps1:305` discovers them from
`data/` rather than hardcoding them, and `Resolve-BundledSelection` closes over the hard dependencies,
so `-With space-age` alone pulls in the other two. `Write-ModList` writes every bundled mod not
requested as explicitly `enabled: false`, which is what makes a genuine base-2.0 run possible. Nothing
in this document changes how Space Age is enabled — it is `-With space-age`, and it is the one set that
needs no download at all.

### Krastorio 2 — alive, and explicit that Space Age is not supported

`Krastorio2` **2.1.2** (2026-06-29), owner **raiguard**, LGPLv3, 386,820 downloads, source at
<https://codeberg.org/raiguard/Krastorio2>. Not deprecated.

Its own description, quoted from the API's `description` field:

> Krastorio 2 has basic compatibility with the **Quality** mod. Things should work fine, but it may be
> unbalanced. Play at your own risk!
>
> Krastorio 2 does **not** properly support the **Space Age** mod. The game will load, but progression
> will be broken. Please install an add-on such as
> [Krastorio 2 Spaced Out](https://mods.factorio.com/mod/Krastorio2-spaced-out) to play Krastorio 2
> with Space Age.

And from its changelog, at 2.0.0:

> Added rudimentary compatibility with Space Age. The game loads and should not crash, but nothing
> beyond that has been tested. Play at your own risk!

So for issue #33's original scope: **K2 + Space Age loads by the author's own account and is broken by
the author's own account.** A load-check would pass and prove nothing about playability. The
author-sanctioned route is `Krastorio2-spaced-out` (owner **Polka_37**, v2.0.16, fv 2.1, requires
`base >= 2.1.0`, `space-age >= 2.1.0`, `Krastorio2`, `k2so-assets >= 1.0.7`), which is a third set
again and is **not** in the requested list.

K2 also states native Space Exploration compatibility: *"Krastorio 2 and Space Exploration have native
compatibility. Simply load both mods and it will 'just work'."*

### Space Exploration — alive, and mutually exclusive with almost everything else here

`space-exploration` **0.7.61** (2026-08-07), owner **Earendel**, 526,074 downloads, no public source
repo. The closure is 16 mods, mostly its own graphics splits plus Earendel's AAI stack.

Its `!` list is the longest of any mod surveyed and includes `space-age`, the whole Angel's core, most
of Bob's, and `SeaBlock`. SE is therefore an *alternative* to the other overhauls in this document, not
a companion to any of them — with the single exception of Krastorio 2, which both sides declare
supported.

Directly relevant to this project, and not previously recorded: **two 2.0 mods already exist to make
Durikkan's port work under Space Exploration.**

| Mod | Owner | Version | Declares |
|---|---|---|---|
| `RealisticFusionPowerPort-SE-Compat` | Starlark | 1.0.0 (2025-10-03) | `RealisticFusionPowerPort >= 1.9.0`, `space-exploration >= 0.7.0` — *"a quick fix for Space Exploration compatibility"* |
| `RealisticFusionPowerPortSE` | solar138 | 1.0.1 (2026-02-08) | `space-exploration`, **`!RealisticFusionPowerPort`** — a modified fork, *"replaces [Deep space science 4] with a more reasonable unlock tree using energy science"* |

Both are `factorio_version` 2.0, both Unlicense. They are evidence that the port's SE story is a live
community concern; whether either is relevant to this project is a scope question, not a fact.

### Angel's — the core four are alive, Industries and Exploration are not

This is the family where "which mods make up the set" genuinely has more than one answer, so both are
given.

**The core four, all alive at 2.1 (2026-07-27), all by Arch666Angel, source
<https://github.com/Arch666Angel/mods>:**

| Mod | Version | Hard deps beyond base |
|---|---|---|
| `angelsrefining` | 2.1.2 | `~ angelsrefininggraphics` |
| `angelspetrochem` | 2.1.2 | `angelsrefining`, `~ angelspetrochemgraphics` |
| `angelssmelting` | 2.1.1 | `angelsrefining`, `angelspetrochem`, `~ angelssmeltinggraphics` |
| `angelsbioprocessing` | 2.1.1 | the three above, `~ angelsbioprocessinggraphics` |

The four `*graphics` mods are separate portal entries (category `internal`, no dependencies of their
own) and are **required**, not optional. That is a 2.x change — the graphics were bundled in the 1.1
releases — and it is the most common way an Angel's enable-list comes out wrong.

**The mods the Angel's page lists that have no 2.x release at all:**

| Mod | Last release | fv | Portal `deprecated` flag |
|---|---|---|---|
| `angelsindustries` | 0.4.21 (2024-02-21) | 1.1 | **true** |
| `angelsexploration` | 0.3.16 (2024-02-21) | 1.1 | **true** |
| `angelsaddons-warehouses` | 0.5.2 (2020-07-17) | 0.18 | **true** |
| `angelsaddons-pressuretanks` | 0.5.2 (2020-07-17) | 0.18 | **true** |

`angelsindustries` is the one that matters, and it matters twice over. It is a **hard dependency of
`angelsexploration`**, so that mod is doubly dead. And it is one of the three Angel's mods the 1.8.18
predecessor wrote a compatibility patch for (`compatibility-patches/angelsindustries/`, 120 + 31 lines)
— so the largest single piece of Angel's integration the predecessor carried targets a mod that does
not exist on 2.x.

There is one ambiguous signal: `angelsindustriesgraphics` v1.0.0 exists at `factorio_version` **2.0**,
published 2025-05-27 by Arch666Angel — the same graphics-split pattern the core four use on 2.x — but
it is flagged **deprecated** on the portal and the main mod never followed. Two readings, both
supported and neither settled here: a 2.0 port of Industries was started and abandoned, or the graphics
split was published ahead of a port that has not shipped yet. No statement either way was found on the
mod page.

Two other Angel's mods do have live 2.1 releases and are not in the core four:
`angelsaddons-mobility` (Mass Transit, 2.1.1) and `angelsinfiniteores` (2.1.0), plus
`angelsaddons-storage` (Storage Options, 2.1.1), which SeaBlock NG's pack requires.

**On Space Age: Angel's says nothing at all.** No Angel's mod declares `space-age` in any form —
not required, not optional, not incompatible — and the mod page has no Space Age section. There is
indirect evidence of Space Age awareness in the changelog (`angelsrefining` 2.0.4: *"Prevented
resources being removed from planets other than Nauvis"*; `angelsbioprocessing` 2.0.3: *"Fixed crystals
not being added to Quality module recipes"*), which shows the authors have at least looked at the
expansion. Silence is not a compatibility claim in either direction, and this survey does not turn it
into one.

### Bob's — the whole set is alive, and it declares Space Age support

Eighteen mods, all owner **Bobingabout**, source <https://github.com/modded-factorio/bobsmods>, all at
mod version **3.0.0 or 3.0.1** (2026-06-29 to 2026-07-26), all `factorio_version` **2.1**,
`base >= 2.1.0`. None deprecated.

`boblibrary` is the prerequisite of every other Bob's mod except `bobinserters` (which depends on
`base` alone). Within the set the hard requirements are only `boblibrary`, plus `bobores` for
`bobplates`; **everything else Bob's declares about its siblings is `?` optional**, which is why the
set can be trimmed freely and why an incomplete list still loads. The full 18 is what "Bob's mods"
conventionally means.

**Ten of the eighteen declare Space Age explicitly**, as `? space-age >= 2.1.0` or `(?) space-age`:
`bobplates`, `bobelectronics`, `boblogistics`, `bobenemies`, `bobwarfare`, `bobtech`, `bobmodules`,
`bobassembly`, `bobgreenhouse`, `bobequipment`, `bobclasses`. The changelog confirms this is real
integration work, not a stub — `bobplates` 2.1.0: *"Combined Bob's Carbon and Space Age's Carbon"*,
*"Combined Bob's Lithium and Space Age's Lithium"*, *"Combined Bob's Tungsten and Space Age's
Tungsten"*, and earlier *"Added support for frozen entities (with Space Age)"*.

Of every family surveyed, **Bob's is the only one that positively declares Space Age support.**

One conflict to note for any set combining Bob's with K2: `Krastorio2` declares `! bobequipment` and
`! bobvehicleequipment`.

### MadClown's — four of five alive

Owner **MadClown01**, source <https://github.com/Pezzawinkle/MadClowns>, MIT. All four live mods are at
**2.1.01** (2026-07-26), `factorio_version` 2.1.

| Mod | Title | Hard deps |
|---|---|---|
| `Clowns-Processing` | MadClown01's Processing | `angelsrefining`, `angelspetrochem`, `angelssmelting` |
| `Clowns-Extended-Minerals` | MadClown01's Extended AngelBob Minerals | `Clowns-Processing` |
| `Clowns-Nuclear` | MadClown01's Nuclear Extension | none (all optional) |
| `Clowns-AngelBob-Nuclear` | MadClown01's AngelBob Nuclear Extension | `angelsrefining`, `Clowns-Nuclear`, `Clowns-Processing` |

**`Clowns-Science` has no 2.x release** — last is 1.1.7 (2023-11-12), `factorio_version` 1.1. It is not
flagged deprecated, but it has not moved in nearly three years. It is not a dependency of any of the
four above, so its absence does not block the set; it does mean "MadClown's mods" on 2.x is a smaller
thing than on 1.1. `Clowns-Locale` (0.17) and the various third-party locale packs are likewise dead
and likewise not required.

`Clowns-Extended-Minerals` declares `! angelsaddons-refiningthorium`. `Krastorio2` declares
`! Clowns-Nuclear`, so K2 and MadClown's Nuclear cannot be combined.

The Clowns mods declare nothing about `space-age` in any direction.

### SeaBlock — the classic is dead, and "NG" is a specific mod

The classic `SeaBlock` (owner **Trainwreck**, 0.5.16, 2024-02-27) is `factorio_version` **1.1** and has
no 2.x release. So has `SeaBlockMetaPack`. Three separate 2.x continuations exist under different
names:

| Slug | Title | Owner | Version | fv | Note |
|---|---|---|---|---|---|
| `SeaBlockWanne` | **SeaBlock NG** | wanne | 1.1.4 (2026-08-11) | 2.1 | **this is the requested mod** |
| `SeaBlockPack` | SeaBlock Pack | wanne | 1.1.2 (2026-08-06) | 2.1 | companion pack, `+` (recommended) from NG |
| `SeaBlockContinued` | Sea Block Continued | darkenade | 0.6.3 (2026-08-06) | **2.0** | a different continuation, by a different author |

"SeaBlock NG" is `SeaBlockWanne`, source <https://codeberg.org/wanne/SeaBlockWanne>. Note the slug
bears no resemblance to the title, which is exactly the kind of thing that produces a wrong
enable-list.

`SeaBlockWanne` declares, verbatim from its dependency array: `! space-age`, `! Krastorio2`,
`! bobenemies`, `! cargo-ships-oil-rig`. **SeaBlock NG + Space Age is not a set that can exist**, and
neither is SeaBlock NG + K2.

The minimal and as-intended readings differ sharply, because `SeaBlockPack` is `+` (recommended, not
required) — the mod loads without it and is not the intended experience without it. Both lists are
given below. `SeaBlockPack` additionally declares `! angelsaddons-bots`, `! bobgreenhouse`,
`! valves`, and recommends `+ quality`, which the mod-list mechanism would have to enable as a bundled
mod rather than a download.

`SeaBlockContinued` is worth recording as the alternative reading of "SeaBlock on 2.x": it is
`factorio_version` **2.0** (so it works on the current 2.0.77 install and *not* on 2.1), it requires
`SpaceModFeorasFork`, and it declares `! space-age`, `! quality`, `! elevated-rails` — i.e. it refuses
all three bundled mods, which is a distinct and stricter position from NG's.

### RITEG — alive on 2.0, and not the mod the predecessor patched

`RITEG` **1.3.11** (2025-05-01), owner **darkfrei**, MIT, 5,426 downloads, `factorio_version` **2.0**.
Optional deps only: `? PlutoniumEnergy >= 1.7.3`, `? Nuclear Fuel`, `? PlutoniumBreeding`. No hard
dependency beyond `base` with no version bound, so its enable-list is one line.

It has **not** been updated for 2.1. Under the major-version rule above it will load on 2.0.x and not
on 2.1.x — the one mod in this document whose viability is *inverted* by the upgrade route.

Its own description: *"RITEG (RTG) is a Radioisotope Thermoelectric Generator, it's an electrical
generator with nuclear fuel."*

**It is a different mod from the `RTG` the predecessor patched.** That one is `RTG` by **Optera**,
v1.0.1, last touched **2020-12-08**, `factorio_version` 1.1, 1,233 downloads — same device, different
author, dead for six years. Two mods, one concept, and the predecessor keyed on the dead one.

What the predecessor's patch actually does is worth knowing before any of it is carried forward. The
1.8.18 loader is `for k,_ in pairs(mods) do pcall(require, "compatibility-patches."..k..".data") end`
(`data.lua:43`), so `compatibility-patches/RTG/data.lua` runs **iff a mod named `RTG` is enabled**. Its
182 lines add RFP's *own* portable fusion equipment — `rfp-reactor-equipment` (a `generator-equipment`
with a burner energy source), the `rfp-he3-he3-fuel-cell` and `rfp-d-he3-fuel-cell` recipes, and an
`rfp-equipment` fuel category. **It references no `RTG` prototype and no `__RTG__` asset path
anywhere** — the only linkage to Optera's mod is the directory name. Whatever the intent was, porting
that file to key on `RITEG` would be a rename, not a translation; whether the portable reactor should
exist at all is a scope decision this survey does not touch.

### Advanced Fluid Handling — the slug is `underground-pipe-pack`

`underground-pipe-pack`, title **"Advanced Fluid Handling"**, owner **staplergun**, **2.0.7**
(2026-07-13), `factorio_version` 2.1, `base >= 2.0.48`, 50,915 downloads, source
<https://github.com/TheStaplergun/pipemod>. No hard dependencies beyond base; declares
`(?) Dectorio`, `(?) space-exploration`, `(?) boblogistics`, `(?) space-age`. Last fv=2.0 release is
**2.0.6**.

**This is not the mod the predecessor patched.** That is `Flow Control` by **GotLag** — note the space
in the internal name, which needs URL-encoding against the API and quoting in PowerShell. It is alive:
**3.2.4** (2026-06-26), fv 2.1, `base >= 2.0.8`, `? valves >= 1.0.0`, 219,300 downloads, source now
<https://github.com/snouz/Flow-Control>. Last fv=2.0 release is **3.2.3**.

The predecessor's `compatibility-patches/Flow Control/data-final-fixes.lua` (43 lines) deep-copies
`pipe-junction`, `pipe-straight` and `pipe-elbow` from Flow Control into orange-tinted `rfp-pipe-*`
variants, sets `se_allow_in_space = true` on each, and inserts the unlock into
`rfp-plasma-handling`. It reaches directly into `__Flow Control__/graphics/icon/pipe-*.png`. It is
firmly keyed to Flow Control's prototype names and would not transfer to `underground-pipe-pack` as-is.

Whether "Advanced fluid handling" in the ticket means *the mod titled that* or *the general capability
the predecessor got from Flow Control* is a question for Truls. Both are named here; neither is chosen.

---

## Enable-lists

Each block is the **complete hard-dependency closure** at the current release, computed from the
`info_json.dependencies` arrays as described above, in internal-name form, ready to paste. `base`,
`core` and the three bundled mods are excluded throughout — bundled mods are enabled with
`load-check.ps1`'s `-With`, never by name in this list.

Names are given as PowerShell arrays because that is what `Write-ModList -Mods` takes.

### Space Age

No downloads. Bundled.

```powershell
# no third-party mods; enable the bundled trio instead:
pwsh -File scripts/load-check.ps1 -With space-age
```

### Krastorio 2 — 4 mods

```powershell
$set = @(
    'flib'
    'Krastorio2'
    'Krastorio2Assets'
    'Krastorio2MenuSimulations'
)
```

`ChangeInserterDropLane` is declared `+` (recommended) by K2 and is deliberately omitted; add it if the
intent is to match what a player would install.

**That is true of 2.1.2 and not of the 2.0 line, so the list above does not transfer.** At **2.0.19**
— the last `factorio_version` 2.0 release, and the only K2 that loads beside this repo on 2.0.77 —
`ChangeInserterDropLane >= 1.1.0` carries no prefix at all and is a hard requirement. The 2.0 set is
therefore **five** mods, and it was loaded rather than only computed (2026-08-18, `load-check.ps1
-AlsoModDirectory`; recorded against ADR 0007):

```powershell
$set = @(
    'ChangeInserterDropLane'      # 1.2.0
    'flib'                        # 0.16.2
    'Krastorio2'                  # 2.0.19
    'Krastorio2Assets'            # 2.0.5
    'Krastorio2MenuSimulations'   # 2.0.2
)
```

All five are on **public git and need no mod-portal account** — four on codeberg under `raiguard/`,
`flib` at `github.com/factoriolib/flib`, each at a `v`-prefixed tag matching its version. That is a
cheaper route than the authenticated portal download for these particular mods, and it is worth
weighing before building the token handling; it does not generalise to every family here.

### Space Exploration — 16 mods

```powershell
$set = @(
    'aai-containers'
    'aai-industry'
    'aai-signal-transmission'
    'alien-biomes'
    'alien-biomes-graphics'
    'informatron'
    'jetpack'
    'robot_attrition'
    'shield-projector'
    'space-exploration'
    'space-exploration-graphics'
    'space-exploration-graphics-2'
    'space-exploration-graphics-3'
    'space-exploration-graphics-4'
    'space-exploration-graphics-5'
    'space-exploration-postprocess'
)
```

Cannot be combined with `-With space-age` (declared `!`).

> **Corrected 2026-08-27 (#129). This list of 16 is short by one, and the missing mod is a HARD
> dependency.** `space-exploration` 0.7.57 declares `space-exploration-menu-simulations >= 0.7.1`
> **with no prefix**, which in Factorio's dependency syntax is a requirement and not a suggestion —
> the same trap the `krastorio2` set records for `ChangeInserterDropLane`. The pin in
> `scripts/fetch-mods.ps1` is therefore **17** mods and is the correct one; this section is the
> derivation that missed it. Do not trim the set to match. All 17 fetch, and the game loads all
> twenty mods and creates a map — but **`load-check.ps1` still exits 1**, on `__base__` paths SE and
> the two AAI mods name and Factorio 2.0 removed. That red is recorded and it is upstream's; see
> ADR 0007's lane table before reading it as a regression.

### Krastorio 2 + Space Exploration — 20 mods

> **Same correction, 2026-08-27 (#129), and this list is short by two.** It omits
> `space-exploration-menu-simulations` for the reason above, and `ChangeInserterDropLane`, which
> `Krastorio2` 2.0.19 declares with no prefix — the trap the `krastorio2` set already records. The 20
> below is therefore 16 + 4 where the pins are 17 + 5. **`$MOD_SETS`' `k2-spaceex` is composed by
> `Join-ModSets` from the two family pins rather than transcribed from here, so it resolves to 22 and
> needs no edit** — verified. See
> [#130](https://github.com/trulsjo/realistic-fusion-refreshed/issues/130).
>
> **Run 2026-08-27 (#130), all 22 at their pins.** The game loads all twenty-five mods and creates a
> map, and `name-check.ps1` is green — but **`load-check.ps1` exits 1**, on the same five `__base__`
> paths SE and the two AAI mods name and Factorio 2.0 removed. Krastorio 2 adds no sixth. That red is
> recorded and it is upstream's; see ADR 0007's lane table before reading it as a regression.

Added 2026-08-18, after the first pass of this document omitted the pairing. Both dependency arrays were
re-read from `/full` on that date.

**The two mods declare each other compatible, and SE declares more than that.** `space-exploration`
0.7.61 lists **`(?) Krastorio2 >= 2.0.10`** — a hidden optional dependency, which under the prefix rules
above means SE loads after K2 when K2 is present and ships code that adapts to it. Neither mod names the
other in an `!` entry: K2's incompatibility list is `Annotorio`, `brave-new-world`, `Clowns-Nuclear`,
`HdProcessedMetal`, `KS_Power`, `Krastorio`, `Krastorio-graphics`, `KS_Combat`, `ModularLife`,
`Power Armor MK3`, `PowerAndArmor`, `SimpleSilicon`, `bobequipment`, `bobvehicleequipment`,
`custom_power_armor_fix` and `laborat`; SE's names Space Age, the Angel's and Bob's mods, `SeaBlock` and
fourteen others, and no Krastorio mod appears in it.

The union is a straight concatenation — SE's 16-mod closure pulls no `flib`, which is K2's only shared-
looking dependency, so nothing is double-counted and nothing drops out.

```powershell
$set = @(
    'aai-containers'
    'aai-industry'
    'aai-signal-transmission'
    'alien-biomes'
    'alien-biomes-graphics'
    'flib'
    'informatron'
    'jetpack'
    'Krastorio2'
    'Krastorio2Assets'
    'Krastorio2MenuSimulations'
    'robot_attrition'
    'shield-projector'
    'space-exploration'
    'space-exploration-graphics'
    'space-exploration-graphics-2'
    'space-exploration-graphics-3'
    'space-exploration-graphics-4'
    'space-exploration-graphics-5'
    'space-exploration-postprocess'
)
```

Cannot be combined with `-With space-age`, by SE's `! space-age`.

**What the `(?)` implies, stated as inference rather than fact:** an optional dependency is how a mod
declares that it changes behaviour when another is present. That SE carries one for K2 establishes that
SE-side interoperability code exists and is reachable; it does not establish that the code is current,
that it works, or that the combined set loads. Nothing here was run — see
[What could not be verified](#what-could-not-be-verified), which applies to this set exactly as to the
others.

### Angel's — 8 mods

```powershell
$set = @(
    'angelsbioprocessing'
    'angelsbioprocessinggraphics'
    'angelspetrochem'
    'angelspetrochemgraphics'
    'angelsrefining'
    'angelsrefininggraphics'
    'angelssmelting'
    'angelssmeltinggraphics'
)
```

The core four plus their four required graphics mods. `angelsindustries` and `angelsexploration`
cannot be added — no 2.x release exists.

> **Run 2026-08-27 (#131), all 8 at their pins — green on both halves, the first lane that is.**
> `load-check.ps1` exits 0 with every referenced asset present, and `name-check.ps1` exits 0 with no
> collision, nothing unprefixed and no `replaces:`. **But green does not mean untouched**: Angel's
> edits **41 of this repo's 145 prototype objects** — our barrel recipes onto its barreling pump, and
> our chemical-plant clones inheriting its rebalance (pollution 4 → 1.8/min, fluid-box volume
> 100 → 1000). Neither check can see that, for different reasons: `name-check` compares content only
> for prototypes present in **both** dumps, and a prototype of ours is by construction in only one;
> `load-check` never diffs anything, it asserts validity, assets and runtime invariants. **The barrel
> and tint edits are Angel's own uniform policy; the machine drift is ours** — Core's `from_vanilla`
> and Power's hand-set `rf-heater` both leave `energy_source` and fluid-box `volume` inherited,
> despite a comment in each file claiming every balance stat is set explicitly. See ADR 0007's lane
> section before reading the green as "no effect".

### Angel's + Space Age — same 8 mods

```powershell
# identical list; the difference is on the command line
pwsh -File scripts/load-check.ps1 -With space-age   # plus the 8 above
```

Nothing in Angel's declares `space-age` in any direction. A pass proves the prototypes coexist and
nothing about progression.

### Bob's — 18 mods

```powershell
$set = @(
    'bobassembly'
    'bobclasses'
    'bobelectronics'
    'bobenemies'
    'bobequipment'
    'bobgreenhouse'
    'bobinserters'
    'boblibrary'
    'boblogistics'
    'bobmining'
    'bobmodules'
    'bobores'
    'bobplates'
    'bobpower'
    'bobrevamp'
    'bobtech'
    'bobvehicleequipment'
    'bobwarfare'
)
```

### Bob's + Space Age — same 18 mods

```powershell
pwsh -File scripts/load-check.ps1 -With space-age   # plus the 18 above
```

The only set here where the third-party side positively declares Space Age support.

### Angel's + Bob's — 26 mods

```powershell
$set = @(
    'angelsbioprocessing'
    'angelsbioprocessinggraphics'
    'angelspetrochem'
    'angelspetrochemgraphics'
    'angelsrefining'
    'angelsrefininggraphics'
    'angelssmelting'
    'angelssmeltinggraphics'
    'bobassembly'
    'bobclasses'
    'bobelectronics'
    'bobenemies'
    'bobequipment'
    'bobgreenhouse'
    'bobinserters'
    'boblibrary'
    'boblogistics'
    'bobmining'
    'bobmodules'
    'bobores'
    'bobplates'
    'bobpower'
    'bobrevamp'
    'bobtech'
    'bobvehicleequipment'
    'bobwarfare'
)
```

The union of the two, with no extra mods pulled in: Angel's declares Bob's only as `?`/`(?)`, so
nothing new becomes required. No `!` between the two families.

### Angel's + Bob's + Space Age — same 26 mods

```powershell
pwsh -File scripts/load-check.ps1 -With space-age   # plus the 26 above
```

### Angel's + Bob's + MadClown's — 30 mods

```powershell
$set = @(
    'angelsbioprocessing'
    'angelsbioprocessinggraphics'
    'angelspetrochem'
    'angelspetrochemgraphics'
    'angelsrefining'
    'angelsrefininggraphics'
    'angelssmelting'
    'angelssmeltinggraphics'
    'bobassembly'
    'bobclasses'
    'bobelectronics'
    'bobenemies'
    'bobequipment'
    'bobgreenhouse'
    'bobinserters'
    'boblibrary'
    'boblogistics'
    'bobmining'
    'bobmodules'
    'bobores'
    'bobplates'
    'bobpower'
    'bobrevamp'
    'bobtech'
    'bobvehicleequipment'
    'bobwarfare'
    'Clowns-AngelBob-Nuclear'
    'Clowns-Extended-Minerals'
    'Clowns-Nuclear'
    'Clowns-Processing'
)
```

`Clowns-Science` is excluded: no 2.x release. It is not required by any of the four.

### Angel's + Bob's + MadClown's + Space Age — same 30 mods

```powershell
pwsh -File scripts/load-check.ps1 -With space-age   # plus the 30 above
```

### SeaBlock NG — two readings

**Minimal (what `SeaBlockWanne` hard-requires) — 9 mods:**

```powershell
$set = @(
    'angelsbioprocessing'
    'angelsbioprocessinggraphics'
    'angelspetrochem'
    'angelspetrochemgraphics'
    'angelsrefining'
    'angelsrefininggraphics'
    'angelssmelting'
    'angelssmeltinggraphics'
    'SeaBlockWanne'
)
```

**As intended (`SeaBlockWanne` + the recommended `SeaBlockPack` and its hard requirements) — 32 mods:**
*(at the 2.1 releases surveyed here. Pinned at the 2.0 line the same closure is **46** — see ADR 0026.)*

```powershell
$set = @(
    'angelsaddons-storage'
    'angelsbioprocessing'
    'angelsbioprocessinggraphics'
    'angelspetrochem'
    'angelspetrochemgraphics'
    'angelsrefining'
    'angelsrefininggraphics'
    'angelssmelting'
    'angelssmeltinggraphics'
    'bobassembly'
    'bobelectronics'
    'bobequipment'
    'bobinserters'
    'boblibrary'
    'boblogistics'
    'bobmodules'
    'bobores'
    'bobplates'
    'bobpower'
    'bobrevamp'
    'bobtech'
    'bobvehicleequipment'
    'even-distribution'
    'FactorySearch'
    'flib'
    'helmod'
    'loaders-modernized'
    'loaders-modernized-integrations'
    'QueueToFrontLimited'
    'SeaBlockPack'
    'SeaBlockWanne'
    'squeak-through-2'
)
```

Neither list may be combined with `-With space-age` or with Krastorio 2. Note the 32-mod list drops
`bobenemies` and `bobgreenhouse` relative to the full Bob's set — both are declared `!` by the SeaBlock
mods — and pulls in four quality-of-life mods (`even-distribution`, `FactorySearch`, `helmod`,
`QueueToFrontLimited`) that are hard requirements of `SeaBlockPack` rather than gameplay content.
`SeaBlockPack` also recommends `+ quality`, which would be enabled as a bundled mod.

### RITEG — 1 mod

```powershell
$set = @('RITEG')
```

`factorio_version` 2.0 only. Compatible with the current 2.0.77 install; **not** with a 2.1 upgrade.

### Advanced Fluid Handling — 1 mod

```powershell
$set = @('underground-pipe-pack')      # title: "Advanced Fluid Handling", by staplergun
```

And the mod the predecessor actually patched, for comparison:

```powershell
$set = @('Flow Control')               # note the space in the internal name
```

---

## Mechanics: getting these mods into a load-check

Everything in this section is about a gap that currently exists, not a defect. `load-check.ps1` was
built for this repository's own mods and does that job; third-party mods are simply outside what it
was asked to do.

**What the script does today.** `scripts/load-check.ps1:324` calls `New-ModJunctions` for
`$ourMods = Get-RepoMods` only — the **three** mods this repository publishes since
[ADR 0023](../adr/0023-art-ships-in-its-own-mod.md) split the art out
(`realistic-fusion-refreshed-assets`, `realistic-fusion-refreshed-core` and
`realistic-fusion-refreshed`), junctioned from the repo into a temporary mod directory.
`Write-ModList` (`scripts/factorio-lib.ps1:368`) then writes a `mod-list.json` enabling `base`, the
requested bundled mods, and every name passed in `-Mods`.

That is the default path. `-FromZips` builds the three zips instead and copies them in, which changes
nothing about the gap described here: either way the mods junctioned or copied are this repository's
own, and a third-party mod still has to arrive by some other means.

**`Write-ModList` already accepts arbitrary names.** It writes `@{ name = $m; enabled = $true }` for
each entry of `-Mods` without validating anything. So enabling a third-party mod needs no change to
that function — but Factorio will refuse to start if the mod-list names a mod whose zip is not in the
mod directory. **The missing piece is entirely the download.**

**The API needs no login; the download does.** From
[the Mod portal API wiki page](https://wiki.factorio.com/Mod_portal_API): *"Using the API does not
require any kind of authentication or account information."* That covers `/api/mods`,
`/api/mods/{name}` and `/api/mods/{name}/full` — every fact in this document was gathered without
credentials. The download endpoint is different. The release object's `download_url` is
*"Path to download for a mod. starts with `/download` and does not include a full url"*, and the wiki
states the credentials go on as query parameters:

```
https://mods.factorio.com/{download_url}?username={username}&token={token}
```

Without them the request is redirected to `mods.factorio.com/login`; the predecessor survey recorded
this concretely as HTTP 403 behind a Cloudflare challenge.

**Where the credentials come from.** The wiki: *"The token can be acquired from a json file called
'player-data.json', located in the User Data directory."* On this machine that file exists at
`%APPDATA%\Factorio\player-data.json` and contains the keys **`service-username`** and
**`service-token`** — confirmed present on 2026-08-18 by listing the key names only. The token value
was not read and is not recorded anywhere in this document or in the survey's working files.

What that implies, without deciding any of it:

- **A load-check over third-party mods depends on a logged-in Factorio account on the machine running
  it.** That is a new precondition. Every existing check runs from the repo and the game install alone.
  It also means such a check is not reproducible on a machine that has never signed in — CI, a fresh
  clone, another contributor.
- **The token is a credential.** It must not reach a log, a captured stdout file, a committed script,
  or a URL that gets echoed. `Invoke-Factorio` captures stdout and stderr to files under `$temp`; a
  download step would need to keep the URL out of anything captured. Reading the file at all is
  something this environment's permission policy has blocked before (recorded in the predecessor
  survey), so it may need explicit allowance.
- **Caching is close to mandatory.** The SeaBlock NG list is 32 mods here and 46 as pinned, and Space Exploration ships five
  separate graphics mods that are large by design. Re-downloading per run would be slow and would hit
  the portal hard for no benefit. The API gives what a cache needs: each release carries `file_name`
  (*"Always seems to follow the pattern `{name}_{version}.zip`"*) and `sha1`, so a cached zip can be
  verified rather than trusted, and a pinned version can be requested exactly.
- **Version pinning is available and, given the 2.0/2.1 wall, probably necessary.** `/full` returns
  every release with its `info_json`, so a specific `factorio_version` 2.0 release can be selected
  deterministically instead of taking whatever is current. Without pinning, a check that passes today
  breaks the next time an upstream author bumps a major version — which, on the evidence of this
  survey, is a thing that happened to all six families within the last two months.
- **`-With` stays as it is.** Bundled mods are not downloadable and are already handled correctly.
  The two mechanisms are separate and should probably stay separate.

---

## What could not be verified

Listed so the gaps are as visible as the findings.

1. **Nothing here was loaded.** No mod was downloaded, no map was created, no `load-check.ps1` run was
   made against any set. Every "viable" is a claim about declared metadata only. A set can satisfy
   every dependency and still fail at the data stage — duplicate prototype names, a recipe pointing at
   an item another mod removed, an icon path that moved. That failure mode is exactly what a load-check
   exists to find, and none has been run.
2. **Whether this repository's mods coexist with any of these sets is completely unknown.** That is
   issue #33's actual question and this document does not answer it for a single set, including K2 and
   Space Age. It supplies the enable-lists a check would need, nothing more.
3. **"Space Age compatible" is not established for Angel's, MadClown's, or the combined sets.** Angel's
   is silent; the Clowns mods are silent. Silence has been reported as silence. Bob's declaration of
   `? space-age` establishes that Bob's *intends* to support it, not that it works.
4. **The Angel's Industries situation has two readings and neither was settled.** `angelsindustriesgraphics`
   exists at `factorio_version` 2.0 and is flagged deprecated; the main mod is 1.1 and flagged
   deprecated. No statement from Arch666Angel about a 2.x port was found on the mod page. The GitHub
   repository (<https://github.com/Arch666Angel/mods>) was not read — its branches and open issues
   would probably settle it.
5. **No 2.x community continuation of Angel's Industries was searched for exhaustively.** A scan of the
   full portal index for "angelsindustries" turned up only `angelsindustries-components-enhancement`
   (fv 2.0, requires `angelsindustries`, therefore unusable) and a deprecated 1.1 fork. A mod
   continuing Industries under an unrelated name would not have been found by that scan.
6. **The `+` prefix's exact behaviour was read from documentation, not observed.** The 2.1 docs call it
   *"a recommended dependency"*; the 2.0.77 docs do not mention it at all. Whether Factorio 2.0.x
   tolerates a `+` entry it does not recognise, warns, or errors was not tested — relevant because
   `SeaBlockWanne`'s 2.0 line and `SeaBlockPack` both use it.
7. **`SeaBlockPack`'s dependency array contains `!bobgreenhouse` with no space after the `!`.** It was
   parsed as an incompatibility, which is almost certainly right, but Factorio's own tolerance for that
   spelling was not verified.
8. **Download and caching were reasoned about, not built or tried.** No mod was downloaded with a
   token. That the `?username=&token=` mechanism works as documented is taken from the wiki, and the
   only local confirmation is that `player-data.json` contains keys of the right names.
9. **The predecessor's other fourteen patch targets were not chased.** The 1.8.18
   `compatibility-patches/` tree names seventeen mods; this document covers `RTG`, `Flow Control`,
   `Krastorio2`, `angelspetrochem`, `angelssmelting`, `angelsindustries`, `bobelectronics`, `bobplates`
   and `bobpower`. Not looked up: `5dim_automation`, `Booktorio` (known dead — 1.1, deprecated,
   last touched 2020-12-31), `CW-hydrogen-power`, `IndustrialRevolution`, `Krastorio2-more-locomotives`
   (known dead — 1.1, last touched 2020-12-14), `space-exploration` patch contents,
   `spidertron-extended`, `spidertron-extended-se`. The 1.9.0 port ships **fifteen** of the seventeen:
   it drops `Booktorio` and `IndustrialRevolution` and renames `CW-hydrogen-power` to
   `CW-hydrogen-revolution`, leaving `RTG` and `Flow Control` in place. 1.9.2 ships none of it.
10. **Licence terms of the third-party mods were not assessed.** Several carry custom licence IDs
    (`custom_5a9d1cee…` for Angel's and SE, `custom_5a9d1cff…` for Bob's, `custom_6a590675…` for
    SeaBlock NG) whose text was not fetched. Nothing in this document proposes lifting code or assets
    from any of them, so ADR 0001's rules are not engaged — but they would be the moment anything is
    copied, and the per-directory rule in CLAUDE.md applies to these mods exactly as it does to the
    predecessors.
11. **Download counts, deprecation flags and versions are a snapshot of 2026-08-18.** Six of the
    families moved major version within the two months before that date. Anything here should be
    re-checked against the API before being relied on.

### Sources

All portal facts: `https://mods.factorio.com/api/mods/<name>/full` for each mod named, plus
`https://mods.factorio.com/api/mods?page_size=max` for slug discovery (22,816 entries on the survey
date). Specific pages and documents:

- Mod portal API: <https://wiki.factorio.com/Mod_portal_API>
- info.json fields, dependency prefixes, `factorio_version` semantics:
  <https://lua-api.factorio.com/latest/auxiliary/mod-structure.html> (page reports 2.1.14). The
  2.0.77 equivalent is <https://lua-api.factorio.com/2.0.77/auxiliary/mod-structure.html>, which does
  **not** list the `+` prefix.
- Krastorio 2: <https://mods.factorio.com/mod/Krastorio2>, source
  <https://codeberg.org/raiguard/Krastorio2>; the Space Age add-on
  <https://mods.factorio.com/mod/Krastorio2-spaced-out>
- Space Exploration: <https://mods.factorio.com/mod/space-exploration>
- Angel's: <https://mods.factorio.com/mod/angelsrefining>, source
  <https://github.com/Arch666Angel/mods>
- Bob's: <https://mods.factorio.com/mod/bobplates>, source
  <https://github.com/modded-factorio/bobsmods>
- MadClown's: <https://mods.factorio.com/mod/Clowns-Processing>, source
  <https://github.com/Pezzawinkle/MadClowns>
- SeaBlock NG: <https://mods.factorio.com/mod/SeaBlockWanne>, source
  <https://codeberg.org/wanne/SeaBlockWanne>
- RITEG: <https://mods.factorio.com/mod/RITEG>; the predecessor's target
  <https://mods.factorio.com/mod/RTG>
- Advanced Fluid Handling: <https://mods.factorio.com/mod/underground-pipe-pack>, source
  <https://github.com/TheStaplergun/pipemod>; Flow Control
  <https://mods.factorio.com/mod/Flow%20Control>, source <https://github.com/snouz/Flow-Control>
- Local archives: `C:\src\factorio\_reference\RealisticFusionPower_1.8.18\` (the
  `compatibility-patches/` tree, `data.lua`, `info.json`) and
  `C:\src\factorio\_reference\RealisticFusionPowerPort_1.9.0\`, `…_1.9.2\`
- This repository: `scripts/load-check.ps1`, `scripts/factorio-lib.ps1` (`Get-BundledMods` line 288,
  `Resolve-BundledSelection` line 306, `Write-ModList` line 351, `New-ModJunctions` line 371)
