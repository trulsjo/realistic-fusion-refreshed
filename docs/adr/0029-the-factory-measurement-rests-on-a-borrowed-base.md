# 29. The factory measurement rests on a borrowed base

Date: 2026-09-03

## Status

Accepted. Decided by Truls on 2026-09-03, while grilling
[#65](https://github.com/trulsjo/realistic-fusion-refreshed/issues/65). Supersedes nothing. Discharges
#65 and unblocks [#67](https://github.com/trulsjo/realistic-fusion-refreshed/issues/67); it narrows
[ADR 0005](0005-real-time-fusion-simulation.md)'s open residue rather than reopening its decision.

## Context

[ADR 0005](0005-real-time-fusion-simulation.md) obliges this project to measure UPS, and its own
consequences record that half the obligation is unmet: *"the measurement is a rig, not a factory. #34
asked for a real base at scale and there is no such save in this project."* Every figure on record —
#24's, #34's, #39's, #62's — is flat ground, power, reactors, and nothing else. A rig cannot show how
the simulation behaves beside an engine that is already busy, which is the whole question.

**Every other number in this repository comes from a script anyone can run.** `check-*.ps1`,
`load-check.ps1` and `bench-reactors.ps1`'s rig sweep all build their own maps from the working tree.
That property is not decorative: it is why a figure quoted here can be re-taken by a reader who
doubts it.

A factory measurement cannot have it, and the reason is not laziness. **A representative base is
somebody's work.** Building one by playing costs hundreds of hours. Generating one produces a bigger
rig, not a factory — the designs a real player made are exactly what a generator cannot supply.
Downloading one means taking a file under whatever terms its author set, and this repository has strict
rules about that ([ADR 0001](0001-liftable-predecessor-material.md), `legal-note.txt`).

The base actually available is TimEv's *Modular 10k SPM Vanilla 2.0 Megabase*, already on the
development machine. Measured with none of this project's mods loaded, it spends about **14 ms a tick, roughly 84% of the
16.67 ms budget** — a genuinely loaded engine, which is the premise the whole exercise rests on.
**Its video, description and forum thread state no licence, permission or terms of any kind.** Full
provenance is in [`docs/research/borrowed-base.md`](../research/borrowed-base.md).

Two facts constrain what can be done with it. Local use of a published save is ordinary use and needs
no grant; **redistribution has no grant, and neither would a derivative** — a megabase with our
reactors in it is derived from TimEv's work. And it is 167 MB against GitHub's 100 MB per-file limit,
so the repository is not an option regardless of terms.

## Decision

**This project accepts one measured figure whose input is a third-party file it cannot ship.**

- **The borrowed base is used locally and never redistributed**, and no derivative of it is either.
  It stays outside the repository, in `_reference/`, with the rest of the material this project reads
  but does not own.
- **The recipe is the durable artefact, not the save.** `scripts/bench-reactors.ps1 -PlantInto` is
  committed; no planted save exists. Someone who obtains TimEv's save independently can rebuild an
  *equivalent* measurement.
- **Git LFS is refused.** It changes how everyone clones this repository, for one binary.
- **TimEv is attributed wherever a figure taken on the base is quoted**, as a community norm rather
  than a licence obligation — the same courtesy this repository extends to Romner_set, Durikkan and
  PreLeyZero.
- **The v1 target stays vanilla** ([ADR 0003](0003-space-age-tolerated-not-targeted.md)). The borrowed
  base is vanilla; a Space Age measurement is a separate later question and is deliberately **not** a
  prerequisite of #67.

## Consequences

- **One figure in this project is not reproducible by a stranger, and it is the headline one.** Anyone
  can re-take it who has the file; nobody can obtain the file from us. That is the cost, it is
  accepted, and it is stated here so that a reader who notices does not have to wonder whether anyone
  else did.
- **If the download link rots, the figure becomes reproducible only by whoever still has the save.**
  Recorded as the failure mode rather than as the plan. The file already disagrees with the thread's
  advertised version — the header says `base 2.0.7` where the post says 2.0.43 — so the link cannot be
  relied on to serve the same bytes twice, and that is why the provenance note is as detailed as it is.
- **The per-reactor slope survives the move, which nothing expected.** `-Save` refuses a per-reactor
  figure because a factory cannot be un-built. Planting at load sidesteps that: the reactors were never
  in the save, so the same save swept at count zero is a real `n = 0` baseline — the same factory,
  the same tick, the same mods, the same planted surface generated and powered. #67 therefore gets a
  subtraction on a loaded tick rather than an absolute number, which is a better discharge of ADR 0005
  than the ticket asked for.
- **The absolute figures from a planted run are not this mod's.** `wholeUpdate` and `scriptUpdate` on a
  borrowed base are mostly the borrowed base. Only the difference is attributable, and the script says
  so in its own output rather than leaving it to be inferred. This is the exact reverse of `-Save`,
  where the absolute cost is the answer and no per-reactor figure exists.
- **The engine columns will not resolve a small fleet.** The whole tick is about 13 ms and varies by a
  few percent between runs, so `wholeUpdate` and `entityUpdate` can come out *lower* with reactors than
  without. `scriptUpdate` is the column that isolates. The 1.4× resolution floor
  [`docs/research/reactor-runtime-cost.md`](../research/reactor-runtime-cost.md) records applies here as
  much as to the rig, and matters more.
- **`_reference/` still documents the provenance of nothing else in it** — the predecessor mods, the
  three `ultimateCore` packs, the Krastorio 2 checkouts and a screen recording. Out of scope for #65
  and filed as [#234](https://github.com/trulsjo/realistic-fusion-refreshed/issues/234); this ADR
  governs the borrowed base alone.

## Alternatives considered

**Build a base by playing.** The only option with no third-party terms at all, and the only one whose
factory is genuinely ours. Rejected on cost: hundreds of hours for one benchmark input, and the result
would still be one person's design.

**Generate a synthetic loaded base** — belts, trains, biters, thousands of entities, from a committed
script. Reproducible by anyone, governed by nobody's terms, and the option that would have kept this
project's every-figure-is-rerunnable property intact. Rejected because it produces a **bigger rig**, not
a factory: the thing a rig cannot supply is a real player's decisions, and #65 exists precisely because
a rig cannot answer the question. Explicitly **not** foreclosed — if the borrowed base becomes
unavailable, this is what to build.

**Write a planted save and keep it beside the borrowed base.** The shape #65 was scoped as, and how this
was going to be done until the mechanism was checked. Rejected twice over: Factorio 2.0.77 offers no
save-writing mode but `--create` and `--start-server`, so it needed a multiplayer server run plus
`game.server_save`; and the resulting save would be a non-redistributable derivative taking about half a
gigabyte of disk to hold a state a script can rebuild. Planting at load needs neither and yields the
baseline besides.

**Commit the save with Git LFS.** Refused. One binary is not worth changing how the repository is
cloned, and it would be redistribution, which there is no grant for.

**Leave the obligation open and record why.** #65's own last acceptance criterion offers this as the
honest outcome if no legitimate save can be obtained. Not taken, because one could be: the constraint
turned out to be redistribution rather than use, and nothing about this measurement requires
redistributing anything.
