# 23. Art ships in its own mod

Date: 2026-08-24

## Status

Accepted. Decided by Truls on 2026-08-24.

**Amends [ADR 0002](0002-v1-scope-and-module-split.md)** in one place — its count of published mods,
which goes from two to three — and leaves the rest of it standing: v1 is still fusion power only,
Core is still a separate library, Core is still not a committed public API, and Antimatter and
Weaponry are still deferred. The reason for the third mod has nothing to do with the reasons ADR
0002 gave for the first two, which is why this amends rather than supersedes.

## Context

The two mods weigh about 11.1 MB together. **10.5 MB of that is PNG** — 6.4 MB in Power, 4.1 MB in
Core — against roughly 590 KB of Lua, locale and cross-section data combined. So a release that
changes one number in a recipe re-ships, to every player who has the mod, about nineteen times its
own weight in art that did not change.

Nothing is published yet, and that is the whole of why this is being done now rather than later.
Once a mod is on the portal, moving files between mods means every installed copy re-downloads
everything once, and every player has to accept a new dependency. ADR 0002 already made this
argument for Core and Power and paid it up front:

> Splitting later is avoided rather than deferred. Moving prototypes between mods once players hold
> saves breaks quietly, and `__ModName__` asset paths are baked into every sprite reference — paying
> the two-mod cost now avoids paying that later.

Two facts were measured before deciding, because both bore on where the seam goes:

- **The `graphics/` trees are not pure assets.** Twelve `*-pictures.lua` files live inside them, and
  `NOTICE.txt` says why: every width, frame count, shift and scale in them is read off Krastorio 2's
  own prototypes, so each is a derivative of its *code* as well as its art and has to sit beside the
  LICENSE that governs it. They are not incidental — the shifts they carry are the one thing that
  cannot be recovered from a sprite sheet.
- **Those files travel with the art anyway.** Eleven of 152 commits have touched a `*-pictures.lua`,
  and nine of those eleven shipped PNGs in the same commit. The two that did not were a comment pass
  and one animation fix.

The reservation, stated so it is on the record rather than discovered later: 10.5 MB is not a large
payload. Krastorio 2, which is where this art comes from, does not split. Space Exploration does, at
roughly a hundred times this size. The saving per release is real but modest; what makes it worth a
third portal entry is that **every balance number in this mod is provisional and has been playtested
once**, so code-only releases are what the foreseeable future consists of.

## Decision

**A third published mod, `realistic-fusion-refreshed-assets`, holds every sprite both other mods
draw.** It ships no prototype, no recipe, no technology and no `data.lua`; installing it alone
changes nothing in the game.

**The whole `graphics/krastorio-2/` directory moved** — PNGs, the twelve `*-pictures.lua`, the
LICENSE and the NOTICE — rather than the PNGs alone. This is [ADR 0001](0001-liftable-predecessor-material.md)'s
own rule applied to material leaving rather than arriving: lift whole directories, with their licence
file and their legal note. The alternative left the derived Lua orphaned from its LICENSE and would
have needed three marked directories to say what one says now.

**One assets mod, not one per consumer.** Core and Power each declare it directly rather than Power
inheriting it through Core, because Power's art references are its own. The cost is accepted and
named: a player installing Core alone also gets Power's 6.4 MB. ADR 0002's one-way rule is not
broken by this — assets depends on nothing, so nothing about Power reaches Core through it.

**`graphics/mockup/` moved too**, against the recommendation put to Truls. Those are generated
placeholder rectangles, the repository's own work, and they change whenever a footprint is retried —
so they are the one part of the payload that is coupled to code, and putting them in the mod whose
purpose is not changing with code has a cost. Truls chose one home for art over that cost.
`scripts/make-mockup-art.ps1` now writes there.

**The dependency is a floor, and the floor is the mechanism.** Both code mods declare
`realistic-fusion-refreshed-assets >= X.Y.Z`. The assets version moves only when art moves, and the
same commit raises the floor in both `info.json`. Exact lockstep was considered and rejected outright:
it would make every balance tweak re-ship 10.9 MB, which is the thing this ADR exists to stop.

**Paths keep their `graphics/` segment** — `__realistic-fusion-refreshed-assets__/graphics/krastorio-2/…`.
Redundant in a mod that is nothing but assets, and kept anyway: it made every one of the 34 references
a pure mod-name swap, and it leaves `sounds/` an obvious home.

**`ship-check.ps1` widens.** Its remit goes from the prose ADR 0003 and ADR 0006 oblige to *the claims
the shipped mods make about themselves*, which now includes one claim that is a number. It gains two
asserts — the declared floor equals the assets mod's version, and no `.png` remains under either code
mod — and one exemption: the assets mod carries the licence files, the description match and the
credits, but **not** the clean-break and quality statements, because it ships no prototype for those
to be about. The credits are not exempt and that is deliberate: this is the mod that actually holds
the borrowed art.

## Consequences

- **A release that changes only code costs a player ~590 KB instead of ~11.1 MB.** That is the point,
  and it is the only benefit claimed.
- **A stale floor is a load failure on someone else's machine and cannot fail on this one.** The dev
  loop junctions the current assets mod, so `Find-MissingAssets` resolves every path whatever the
  floor says. `ship-check.ps1` is the only thing standing between that and
  `File __…-assets__/….png not found` in a player's log. Both new asserts were tested by breaking
  them deliberately before this was committed.
- **A footprint retry now bumps the assets mod**, because the mockups live there. Accepted above.
- **Three portal entries, three `info.json`, three legal notes, three copies of LICENSE and
  LICENSE.GPL.** ADR 0002 counted this cost at two and accepted it; this is the same cost once more.
- **The two `NOTICE.txt` files merged into one**, kept as two labelled parts rather than interleaved.
  Each was written against the machines its own mod adds, and merging the entries would have lost
  which set was taken when and for what.
- **`Get-RepoMods` in `scripts/factorio-lib.ps1` is now the single mod list.** It was a literal in
  twenty-two scripts; the third mod would have been twenty-two edits, and the fourth twenty-two more.

## Alternatives considered

- **Two assets mods, one per code mod.** Keeps ADR 0002's boundary exact — Core's dependency graph
  would never mention anything Power-shaped. Rejected on cost: four portal entries, four `info.json`
  and four version bumps to avoid a few MB of impurity in an install nobody is likely to perform.
- **PNGs only, `*-pictures.lua` left behind.** Would give an assets mod that changes only when art
  changes. Rejected because it orphans LGPL-derived code from its LICENSE, and because the measured
  churn says the separation would buy almost nothing: those files move with the art nine times in
  eleven.
- **Move only `buildings/`**, which is 8.5 MB of the 10.5 MB. Rejected: it splits a licensed
  directory, which is the one thing ADR 0001 says not to do.
- **Doing nothing.** The honest alternative, given the size. It loses its force the moment the mod is
  published, and publishing is the next effort rather than a distant one.
