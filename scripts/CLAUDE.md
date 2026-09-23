# scripts/ — gate internals

Loads when working under `scripts/`. The root `CLAUDE.md` says which gates exist and when to run
them; this file says how three self-tests are built -- two gates' and one build tool's -- and
the two traps one of them already fell into.

**Since #280 `scripts/check-hc.ps1` carries a `-SelfTest` too, and it is the second gate here that
starts the game to prove itself.** Its four halves are about the neutronic plant that section builds
— `repo-plant-passes` is the floor, `exchanger-input-only` and `reactor-sells-south` are canary mods
in the temp directory, and `pipe-in-plant-area` is **rig-side**, the first half in this repository
that breaks the world a rig builds rather than a prototype, because "a pipe is standing where none
should" is not something the data stage can say. It is **refused with `-Quality`**, the way
`load-check.ps1` refuses `-SelfTest -AlsoModDirectory` and for the same reason. Its canary mod is
duplicated from `load-check`'s rather than shared — decided 2026-09-07, because sharing means
editing the repository's most load-bearing self-test to save about fifteen lines.

`-SelfTest -FromZips` is a **different** self-test from `-SelfTest` alone, because zip mode has its
own way of passing while proving nothing: point the asset map back at the repository and every
sprite resolves against the working tree, so the run reports a clean pass over an archive it never
opened. That half deletes a referenced file from the unpacked archive and requires it to be caught.
Two traps it already fell into, both fixed and both worth knowing before editing it — the victim
must be a file the prototypes actually NAME (the `aneutronic-reactor/` sheets are shipped but
unreferenced, so deleting one is correctly silent), and it refuses to delete anything outside the
scratch directory, because the mis-wiring it exists to catch once made it delete the repository's
own sprite.

`pack-mods.ps1` is a build tool rather than a gate; it uploads nothing and changes no version, and
its own `-SelfTest` proves that a **git-ignored** file planted inside a mod cannot reach a zip —
ignored specifically, since merely-untracked would be excluded for the wrong reason.
