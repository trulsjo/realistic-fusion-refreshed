# Upstream material

The rules for taking a file, code or art, from a predecessor or from upstream. The root `CLAUDE.md`
keeps the two that rule material out outright, and this page holds the rest. It was a section of
`CLAUDE.md` until 2026-10-15 (#709).

**Everything is governed per directory — Lua included.** There is no blanket permission to lift
code: check for a licence file in the directory a file comes from before taking it. The redesign's
`RealisticFusionCore/electric-boiler/` holds 167 lines of Lua under **CC BY-NC-ND 4.0**, so "the
repo licence is WTFPL" does not settle what a given file is. See
`docs/adr/0001-liftable-predecessor-material.md`.

- **Permissive material is free** — a directory with neither a `license.txt` nor a `legal-note.txt`,
  subject to the unmarked-graphics exception below, which is a large one.
- **Copyleft (GPL/LGPL) is allowed only in its own directory**, with its licence file alongside and
  modifications stated.
- **Lift only from Realistic Fusion Power 1.8.18 or later.** Earlier releases are CC BY-SA 4.0;
  1.8.18 changed the primary licence to WTFPL.
- **A declared licence is evidence, not proof — read the mod's own credits against it.** A fourth
  predecessor, **UFP: Ultimate Fusion Power Fixed**, declares LGPLv3 across all five zips with no
  per-directory marking at all, while its listings credit Games Workshop, Dreamhaven, Blizzard,
  Hello Games and Arch666Angel. That is why `CLAUDE.md` rules out every asset in it.

**Both predecessors already mark their assets this way.** Realistic Fusion Power and Durikkan's 2.0
port keep graphics derived from **Krastorio 2** in their own directories with the licence text
alongside, while everything else stays permissive. Upstream K2 assets
(<https://codeberg.org/raiguard/Krastorio2Assets>) are **LGPLv3**; the copy inside the four-module
redesign is marked **GPLv3** — read the file next to the sprites rather than assuming either. **The
upstream LGPLv3 is the root, not the whole tree**:
`Krastorio2Assets/compatibility/IndustrialRevolution/` carries a `SUB-LICENSE.txt` putting its five
PNGs under **CC BY-NC-ND 4.0**, which the NonCommercial or NoDerivatives rule in `CLAUDE.md` rules
out outright. Nothing from it is in any of the three mods and nothing from it is committed, checked
2026-09-12 — the directory is present three times under the git-ignored `.mod-cache*/`, which is
where the gates unpack upstream. This repo uses the same scheme — see `legal-note.txt`.

**Every item in `C:\src\factorio\_reference\` — what it is, where it came from, when it was obtained
and what terms it states — is inventoried in `docs/research/reference-provenance.md`** (#234). This
page states the rules; that note says which file on disk is which.

Two things to know about how the predecessors mark material:

- **Marking is by `legal-note.txt` as much as by `license.txt`.** The provenance lives in the legal
  note; the licence file is only the licence text. Searching for licence files alone finds the
  directory and misses what it is — which is exactly the mistake that produced a wrong version of
  this section when it was in `CLAUDE.md`.
- **A directory is named for what it depicts, not for where the art came from.** The Krastorio 2
  material in both predecessors is in `particle-accelerator/`. Of the three older predecessors only
  the redesign has a directory actually called `krastorio-2/`, so not finding that name means
  nothing. (This repo has two of its own, which are its own doing and come from upstream — not from
  the redesign.)

Two rules follow:

- **Lift whole directories, with their license file *and* their legal note.** Never copy loose files
  out of a licensed directory into one governed by `LICENSE`. Free means neither file is present —
  see the unmarked-graphics exception below before concluding that settles it.
- **Modifying a file from a licensed directory yields a derivative under that license.** A
  recoloured or re-composited LGPL sprite is still LGPL, and the change must be stated. Modified
  sprites belong in the licensed directory, not beside your own work.

**The exception to "no licence file means free": the predecessors' unmarked `graphics/`.** It is not
one donor's art — the original's changelog credits at least three outside sources for material that
is left unmarked, and says which files came from where for none of them. ADR 0001 names the three
and the releases that credit them.

So: **do not take unmarked graphics from the predecessors on the assumption they are free.** Ask
before using them, or use art with known provenance — which in practice means upstream Krastorio 2,
and is why every sprite in this repo comes from there. Do not relabel them GPL either; that would be
guessing in the other direction.

- **Attribute Romner_set, Durikkan and PreLeyZero** for anything derived from their work, in the
  commit and in the file. Not a licence obligation — a community norm and simple honesty.
- **Do not try to contact Romner_set.** He deprecated the mod, archived the successor read-only and
  anonymised his GitHub account. That is someone stepping away deliberately; respect it.
- **This repo is a fresh history on purpose.** Bring code across as ordinary commits; do not add the
  archive as a remote, fork it, or graft its history in.
