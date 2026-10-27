# scripts/ — gate internals

Loads when working under `scripts/`. The root `CLAUDE.md` says which gates exist and when to run
them; this file says how two gates' self-tests are built, where the build tool's third one went
(#466), the two traps one of them already fell into, and what a `ship-check.ps1` result describes
(#687).

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

The packer `-FromZips` runs is `vendor/grado-factorio-tools/scripts/pack-mods.ps1` since #466 — the
copy that was here is deleted. It is a build tool rather than a gate; it uploads nothing and changes
no version, and its own `-SelfTest` proves that a **git-ignored** file planted inside a mod cannot
reach a zip — ignored specifically, since merely-untracked would be excluded for the wrong reason.
The mod it plants in is a fixture in the self-test's own scratch repository, not one of ours.

**`scripts/ship-check.ps1` reads its files as each section reaches it, so an edit made during a run
can make it pass on a tree that fails** (#687). Every section but 11 reads a file's contents from
the working tree; section 11 reads the index, so there a staged edit is what counts. The result
describes the files as each section found them, and not a commit. On 2026-10-12, at 99bc230, section
12 read the wrapped files one second before the run ended. On #685 a run started on 99bc230, whose
`docs/agents/code-review-evidence.md` had a line of 113 characters, reported 233 checks and 0
failures, because the line was rewrapped while the run was going; the same tree with no edit during
the run fails on that line.

**Since #812 both `ship-check.ps1` and `run-gates.ps1` refuse such a result.** Each takes a
fingerprint of every tracked file and of the index before it reads anything and again when it is
done, and a difference fails the run, naming each path, whatever the sections or the gates found.
`run-gates.ps1` also checks after each gate and names the gate after which the change was first
seen. A file git does not track is not in the fingerprint, so a run's own logs and reports are not
changes. A fail of this kind says only that the run read more than one tree: run it again with
nothing editing the files.
