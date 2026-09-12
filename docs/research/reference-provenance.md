# What is in `_reference/`, where each item came from, and on what terms

`C:\src\factorio\_reference\` is the reading shelf: predecessor mods, the upstream assets this
project's sprites come from, a borrowed megabase and a screen recording. None of it is this
repository's work and none of it is committed here.

[ADR 0001][adr1] and `CLAUDE.md` own the **rules** — what may be lifted, from where, under what
conditions. This note owns the **inventory**: which file on disk is which, where it was obtained,
when, and what terms it states about itself. That is the part that decays, because a directory name
outlives the memory of downloading it. [#65][65] wrote the same record for the borrowed base in
[`borrowed-base.md`](borrowed-base.md); this is [#234][234] doing it for everything else.

**Written 2026-09-12.** Every date, size and licence name below was read off the files that day.

## How to read the "Stated terms" column

**"None stated" is a finding, not a gap.** Where an item says nothing about its own terms, the entry
says so in those words rather than leaving the cell blank. Silence is never
recorded as a permissive donation — that is the mistake ADR 0001 records about the predecessors'
unmarked `graphics/`, and the column is written to make it hard to repeat.

**Per-directory licence and legal files are named, not summarised.** Where a directory carries its
own terms, the entry gives the file's path so a reader can open it, because the summary is what goes
stale.

## The inventory

| On disk in `_reference/` | What it is | Obtained | Stated terms |
|---|---|---|---|
| `RealisticFusionPower_1.8.18/` | Romner_set's 1.1 original, extracted | 2026-08-13 | WTFPL v2 root, two directories marked otherwise |
| `RealisticFusionPowerPort_1.9.0/` | Durikkan's 2.0 port, extracted | 2026-08-13 | The Unlicense root, WTFPL legal note, same two directories |
| `RealisticFusionPowerPort_1.9.2/` | Same port, later release | 2026-08-13 | As 1.9.0 |
| `realistic-fusion-dev/` | The archived four-module redesign, git clone | 2026-08-21 | WTFPL v2 root, four directories marked otherwise |
| `Krastorio2/` | Krastorio 2 2.1.3 code, git clone | 2026-08-17 | LGPLv3, no sub-licences |
| `Krastorio2Assets/` | Krastorio 2 assets 2.1.1, git clone | 2026-08-16 | LGPLv3 root, **three** directories marked otherwise |
| `ufpFixed_1.0.55.zip` | UFP: Ultimate Fusion Power Fixed | 2026-08-19 | LGPLv3 declared, no per-directory marking, credits unhonoured |
| `ultimateCoreLib_0.0.13.zip` | Its script library | 2026-08-19 | As above |
| `ultimateCore_1.0.26.zip` | Its asset pack 1 | 2026-08-19 | As above, plus two root attribution files |
| `ultimateCore-2_1.0.14.zip` | Its asset pack 2 | 2026-08-19 | As above |
| `ultimateCore-3_0.0.4.zip` | Its asset pack 3 | 2026-08-19 | As above |
| `Megabase in 2.0.zip` | TimEv's 10k SPM megabase save | 2026-08-20 | **None, anywhere** — see [`borrowed-base.md`](borrowed-base.md) |
| `gui_prototype_showcase.mp4` | A recording of the redesign's reactor GUI | 2026-08-19 | **None stated** — posted by Romner_set to a mod portal discussion thread |

**How the dates were established.** For the three git clones, the first reflog entry — `clone: from
…` — which is the only unambiguous record of the day. For the zips and the extracted trees, the
file's creation timestamp on this machine, which says **the file was here by that date** and nothing
about where it was before. A move within a volume carries the old stamp across, so an item could have
been obtained earlier and elsewhere; where another document states a date outright, prefer it.
**One date is better than either**: the screen recording's 2026-08-19 was confirmed by Truls, and the
timestamp agrees with him.

**The three predecessor trees are the case where that matters.** Their stamps read 2026-08-13 20:39,
and the documents say 2026-08-17 — ADR 0001, dated 2026-08-13, says of both mods *"Neither could be
downloaded during the survey (HTTP 403 behind a login gate)"*, and
[`predecessor-survey.md`](predecessor-survey.md) marks them resolved on 2026-08-17. The two
reconcile as downloaded that evening and read four days later, so the table gives the stamp; **if you
need the date they were verified, it is 2026-08-17.**

---

## The two predecessor mods

Both are extracted trees, each one directory deep — `RealisticFusionPower_1.8.18/RealisticFusionPower_1.8.18/`
is where the `info.json` is, and the same doubling applies to both ports. **The zips themselves are
not on disk.** [`predecessor-survey.md`](predecessor-survey.md) records them arriving —
*"Resolved 2026-08-17 (#38). Both zips are readable now, in `C:\src\factorio\_reference\`"* — and
`CLAUDE.md` still says that survey was verified "against the zips". Only the extracted trees remain,
so a re-check works from those.

| | Original | Port 1.9.0 | Port 1.9.2 |
|---|---|---|---|
| `info.json` author | `Romner_set` | `Romner_set` | `Romner_set` |
| `info.json` `factorio_version` | `1.1` | `2.0` | `2.0` |
| Mod portal | [RealisticFusionPower](https://mods.factorio.com/mod/RealisticFusionPower) | [RealisticFusionPowerPort](https://mods.factorio.com/mod/RealisticFusionPowerPort) | same |

**The port's `info.json` names Romner_set, not Durikkan.** Durikkan published it; the author field
was carried over from the original unchanged. So the `info.json` is not evidence of who did the
porting work, and the portal page is.

**Root terms, by file:**

- `RealisticFusionPower_1.8.18/…/license.txt` — WTFPL v2, *"Copyright (C) 2024 Romner"*.
- `RealisticFusionPower_1.8.18/…/legal-note.txt` — states the per-directory convention:
  *"Any file in a subdirectory of this mod that doesn't have a license.txt and/or a legal-note.txt in
  its directory is licensed under the WTFPL."*
- `RealisticFusionPowerPort_1.9.{0,2}/…/license.txt` — The Unlicense, prefaced *"This applies to all
  folders, except those that contain a license file within them."*
- `RealisticFusionPowerPort_1.9.{0,2}/…/legal-note.txt` — the original's file byte for byte, which
  still says WTFPL. **The port's two root files therefore name different licences.** Both are
  permissive and nothing downstream turns on it, but neither file alone is the answer.

**Marked directories — the same two in all three trees, on the same terms:**

| Directory (in each tree) | Licence file | Legal note says |
|---|---|---|
| `graphics/particle-accelerator/` | `license.txt` — GPLv3 | *"All textures in this directory are modified from Krastorio 2"* |
| `electric-boiler/` | `license.txt` — CC BY-NC-ND 4.0 | *"All textures and code in this directory are from angels petrochem"* |

**"angels petrochem", no apostrophe, in all three trees** — the redesign's copy of the same note
writes *"angel's petrochem"*, and is the only one of the four that does.

**Everything else in their `graphics/` trees is unmarked and its origin is unrecorded.** The
original's own changelog credits YuokiTani, angel's discarded thread and PreLeyZero for material it
leaves bare. Nothing on disk says which files those are. ADR 0001 and `CLAUDE.md` carry what follows
from that.

## The redesign — `realistic-fusion-dev/`

A git clone of <https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev>, cloned
2026-08-21 12:38. **22 commits**, HEAD `03748ec` *"Indicate deprecation in README.md"*, dated
2024-10-25. The account name is Romner_set's anonymised GitHub account; the repository is archived
read-only. It is a sibling directory of reading material, not a git relationship — `CLAUDE.md`
forbids a remote, a fork or a graft.

Its own `README.md` calls it **Realistic Fusion 2.0**, which is the mod series' own version number
and not Factorio 2.0. It is Factorio 1.1 code throughout.

Root `LICENSE` is **WTFPL v2**, *"Copyright (C) 2024 Romner"*. Each of the three populated modules
repeats the root pair — `license.txt` (WTFPL v2) and `legal-note.txt` (the per-directory sentence).

**Four marked directories, more than either predecessor:**

| Directory | Licence file | Legal note says |
|---|---|---|
| `RealisticFusionAntimatter/graphics/particle-accelerator/` | `license.txt` — GPLv3 | *"All textures in this directory are modified from Krastorio 2"* |
| `RealisticFusionCore/electric-boiler/` | `license.txt` — CC BY-NC-ND 4.0 | *"All textures and code in this directory are from angel's petrochem"* |
| `RealisticFusionCore/graphics/icons/angels-numerals/` | `license.txt` — CC BY-NC-ND 4.0 | *"All texturesin this directory are from angel's refining"* (sic) |
| `RealisticFusionCore/graphics/icons/krastorio-2/` | `license.txt` — GPLv3 | *"All textures in this directory are taken/modified from Krastorio 2"* |

The last row is the one worth remembering: **the redesign marks its Krastorio 2 icons GPLv3, while
upstream Krastorio 2 is LGPLv3.** Read the file next to the sprites rather than assuming either.

**Four content directories carry no terms of their own** and fall to the root WTFPL. (`.vscode/` is a
fifth without one; it is editor config and holds nothing licensable.)

| Directory | What is in it |
|---|---|
| `RFP-1.0-icons/` | 1.x gas and particle icons — 25 PNGs and 3 GIMP `.xcf` sources |
| `RFP-2.0/` | **230 PNGs**, 3 `.blend` and 4 `.txt`. The PNGs: `gui-raw/` plasma-torus renders **174**, `icons/{gas,recipes,fluid,items}` **35**, `Roughness/` technology icons for the ICF reactor, particle accelerator, particle decelerator, big lab and antimatter processor **20**, and a loose `ICF.png` |
| `RealisticFusionWeaponry/` | **`info.json` only** — a stub module, no content at all |
| `TODO/` | The 1.x mod's leftovers: `changelog.txt`, `thumbnail.png`, three locale files and seven migrations |

`RealisticFusionWeaponry/` having no `license.txt` is not an unmarked-material problem; there is
nothing in it to license. **`RFP-2.0/` is the one that matters.** Its 230 unmarked PNGs are the
largest bare art set in the clone — the three modules hold 140, 73 and 19 once their four marked
directories come out — and its `Roughness/ICF_reactor/` icons belong to the machine whose
graphics the README credits to **PreLeyZero** by name — so the caution ADR 0001 records about the
predecessors' bare `graphics/` lands on this directory, not somewhere vaguer.

## Krastorio 2 — the two upstream checkouts

Both are git clones from Codeberg. **`Krastorio2Assets/` is where this repository's sprites come
from** — `realistic-fusion-refreshed-assets/graphics/krastorio-2/NOTICE.txt` names that one upstream
and no other. `Krastorio2/` is the mod's code, read for prototype patterns; it holds 14 PNGs in all
against the asset repo's 1,338.

| | `Krastorio2/` | `Krastorio2Assets/` |
|---|---|---|
| Remote | <https://codeberg.org/raiguard/Krastorio2.git> | <https://codeberg.org/raiguard/Krastorio2Assets.git> |
| Cloned | 2026-08-17 08:58 | 2026-08-16 00:06 |
| HEAD | `85dde34` *"Changelog micro"*, 2026-07-02 | `bbb0ac6` *"Move to version 2.1.1"*, 2026-06-25 |
| `info.json` version | 2.1.3 | 2.1.1 |
| Root `LICENSE` | LGPLv3 | LGPLv3 |

**`Krastorio2/` has no sub-licence file anywhere.** The LGPLv3 root is the whole of its terms.

**`Krastorio2Assets/` has three marked places, and one of them is not LGPL at all:**

| Path | File | What it says |
|---|---|---|
| `compatibility/IndustrialRevolution/` | `SUB-LICENSE.txt` | **CC BY-NC-ND 4.0** — *"ALL IMAGES IN THIS FOLDER IS UNDER IndustrialRevolution LICENCE / THESE IMAGES ARE PROVIDED BY THE MOD AUTHOR FOR COMPATIBILITY PURPOSE / THE LICENCE IS THE FOLLOWING: / (the author refer to Deadlock/IndustrialRevolution mod creator)"*, the file's first four lines |
| `sounds/` | `SUB-LICENSE.txt` | MIT — *"this only applies on sounds ogg files"* |
| `sounds/ambient/` | `readme-licence.txt` | CC BY 3.0 for one track, *"nyoko - Flowing Into The Darkness"* |

**The first row matters and is easy to miss.** `CLAUDE.md` says upstream Krastorio 2 assets are
LGPLv3, which is true of the root and true of everything this project has taken. It is not true of
`compatibility/IndustrialRevolution/`, whose five PNGs are NonCommercial **and** NoDerivatives —
exactly the terms ADR 0001 rules out outright. The directory holds
`charged-lithium-sulfur-battery.png`, `crushed-rare-metals.png`, `crushed-rare-metals-1.png`,
`imersite-cartridge.png` and `imersite-magazine.png`.

**Checked 2026-09-12: none of the five is in any shipped mod, and none is committed.** Grepping
`realistic-fusion-refreshed{,-core,-assets}/` for `imersite`, `crushed-rare-metals` and
`lithium-sulfur-battery` matches nothing, and the 114 PNGs under
`realistic-fusion-refreshed-assets/graphics/krastorio-2/` sit under eight top-level directories —
`buildings`, `entities`, `fluids`, `items`, `pipe`, `pipe-to-ground`, `technologies` and
`virtual-signals` — nested further inside them.

**The directory is on disk three times all the same**, six files each, at
`.mod-cache/krastorio2/`, `.mod-cache/k2-spaceex/` and `.mod-cache-portal/` — unpacked upstream mods
the gates download. `.gitignore` excludes `.mod-cache*/`, so none of it is tracked and the position is
unchanged. Say "not in any shipped mod", not "not in this repo".

**Grep for the directory, not for the filenames.** `imersite` is an ordinary Krastorio 2 resource
name, so searching the working tree for these filenames returns hundreds of hits — almost all of them
legitimate K2 material with nothing to do with these five PNGs, and the count depends on which mods
the caches last fetched. `find . -type d -name IndustrialRevolution` finds the three copies and
nothing else.

The finding is a hazard for the next person who copies a sprite out of `Krastorio2Assets/`, not a
defect in what is already here.

## UFP: Ultimate Fusion Power Fixed — five zips, no usable asset

By `VVVVVVEmersonFisioVVVVVV`, from <https://mods.factorio.com/mod/ufpFixed> and the author's other
mod pages. All five downloaded **2026-08-19**, about 630 MB in total.

| Zip | Bytes | `info.json` title | `factorio_version` |
|---|---|---|---|
| `ufpFixed_1.0.55.zip` | 752,432 | UFP: Ultimate Fusion Power Fixed | 2.1 |
| `ultimateCoreLib_0.0.13.zip` | 736,485 | Ultimate Fixed Mods Core Libs | 2.1 |
| `ultimateCore_1.0.26.zip` | 217,574,322 | Ultimate Fixed Mods Core | 2.1 |
| `ultimateCore-2_1.0.14.zip` | 204,100,957 | Ultimate Fixed Mods Core part 2 | 2.1 |
| `ultimateCore-3_0.0.4.zip` | 205,108,783 | Ultimate Fixed Mods Core part 3 | 2.1 |

`ufpFixed`'s own description calls it a *"Bootleg of Romner_set's Realistic Fusion Power"*.

**All five root `LICENSE` files are the same file.** 7,423 bytes each, MD5
`e15bfd92b69441638626d22aa3bb865e`, the LGPLv3 text verbatim, all stamped 2022-03-06 19:44 inside the
archives. **Not one `license.txt` or `legal-note.txt` exists in any subdirectory of any of the five.**

Two files in `ultimateCore_1.0.26.zip` qualify the root claim, and they are the only per-file terms
in 630 MB:

- `ultimateCore_1.0.26/freesound_org_attribution.txt` — four sounds, one of them **CC BY-NC 4.0**.
- `ultimateCore_1.0.26/vecteezy_attribution.txt` — four PNGs (`sun.png`, `blue flare.png`,
  `black hole.png`, `void.png`) whose stated terms are **attribution snippets only**: the file is the
  word *"vecteezy"*, a *"How to give attribution"* heading, *"Copy and paste the below code for
  attribution:"* and four `<a href>` lines. It states no prohibition; the
  Vecteezy licence it points at is off-file, and ADR 0001 reads that licence as forbidding
  redistribution.

**What is on the mod portal contradicts what is in the zips.** The listings credit Games Workshop,
Dreamhaven, Blizzard, Hello Games and Arch666Angel for material the archives declare LGPLv3 without
qualification. ADR 0001 records the two credits that were checked, how both failed, and what follows.

## The borrowed base

`Megabase in 2.0.zip`, 167,320,199 bytes, obtained 2026-08-20. TimEv's *Modular 10k SPM Vanilla 2.0
Megabase*; **no licence, permission or terms of any kind, anywhere**. Its full record — where the link
was, what the file's own header says, and why using it locally is available where redistributing it
is not — is [`borrowed-base.md`](borrowed-base.md), and is not repeated here.

## The screen recording

`gui_prototype_showcase.mp4`, 6,412,646 bytes, SHA-256
`191218ddc1a31f86c0a9b2dced1bd36b712d0dc1c9e79eba9d17496ab43c4f02`. **Downloaded 2026-08-19** —
Truls confirmed the day, and the file's creation timestamp on this machine agrees to the hour
(09:39). It is the only date in this inventory a person confirmed rather than a filesystem supplied.

A 2:12 screen recording of the reactor control GUI from the four-module redesign, downloaded by Truls
and read for [#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) —
[`reactor-control-gui.md`](reactor-control-gui.md) is the analysis. That note dates the footage to a
specific commit of the redesign — `46f83971`, 2022-10-09 — nearly six months before its last GUI work.

**Origin, established 2026-09-12** — Truls named the source and it was checked the same day:

| | |
|---|---|
| Posted to | Realistic Fusion Power's mod portal discussion, thread *"About version 2.0"* |
| URL | <https://mods.factorio.com/mod/RealisticFusionPower/discussion/626322f706bc9f47b0984b15> |
| Posted by | **Romner_set**, who started the thread and describes the footage in it as his own work |
| Thread started | 2022-04-22, decoding the thread id as a MongoDB ObjectId; the portal shows *"4 years ago"*, which agrees. **This is the thread, not the post** — the footage is `46f83971`, 2022-10-09, so the video went up at least six months into a thread that ran for years |
| What he says about it | *"how the current prototype which doesn't represent the final version at all looks like"*, and that compression hurt the quality |

**Stated terms: none.** Checked 2026-09-12 — the thread carries no licence, no permission and no
reuse statement of any kind. The mod's root WTFPL governs files inside the mod; it says nothing about
a video posted to a discussion thread, so this is the borrowed base's situation rather than the
predecessors': a publicly posted file with no terms attached. Reading it is ordinary use. Publishing a
frame of it, or anything cut from it, needs an answer that does not exist yet, and asking Romner_set
is not an option for the reason `CLAUDE.md` gives.

It was the one item in this inventory whose origin nothing on disk could recover, and it took a person
to answer. That is the argument for writing the rest down while the answers are still cheap.

[adr1]: ../adr/0001-liftable-predecessor-material.md
[65]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/65
[234]: https://github.com/trulsjo/realistic-fusion-refreshed/issues/234
