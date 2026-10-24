# 41. The mods move to Factorio 2.1, floored at the build they are tested on

Date: 2026-10-24

## Status

Accepted. **Decided by Truls, 2026-10-24**, in the grilling of
[#763](https://github.com/trulsjo/realistic-fusion-refreshed/issues/763), whose
[measurement comment](https://github.com/trulsjo/realistic-fusion-refreshed/issues/763#issuecomment-6384102280)
records each answer. Recorded by [#766](https://github.com/trulsjo/realistic-fusion-refreshed/issues/766).

**Supersedes [ADR 0008](0008-factorio-version-floor-and-doc-pin.md)**, all three of its values. ADR
0008 is not rewritten. It gains a dated note pointing here, as it gained one for ADR 0026.
**Re-points [ADR 0026](0026-third-party-mods-are-pinned-to-their-2-0-line.md)'s pins** at the 2.1
line and keeps its scoping rule. **Moves [ADR 0003](0003-space-age-tolerated-not-targeted.md)'s base
game** from 2.0 to 2.1 and leaves its Space Age decision alone. ADR 0026 and ADR 0003 also carry
dated notes.

## Context

**ADR 0008's trigger has fired.** It deferred 2.1 to "when 2.1 is stable". On 2026-10-24
<https://lua-api.factorio.com/> gave "Latest stable version (2.1.23)", and Steam updated the
development machine's Factorio to 2.1.23. That copy is the one the harness falls back to when
`FACTORIO_EXE` is unset, and `FACTORIO_EXE` was unset. So every gate that starts the game failed
on any branch: `Incompatible Factorio version (current: 2.1, required: 2.0)`. That failure is #763.

**#763 put two ways forward to Truls**: install 2.0.77 beside it and point `FACTORIO_EXE` at that,
or move to 2.1. He chose to measure the move first, and the measurement was run on 2.1.23 that
day in a throwaway worktree, with nothing committed. In short:

- **Every `info.json` involved declares 2.0, and each has to move.** That is the three mods' own,
  and 47 sites in scripts that write one for the game to load: every rig, probe, bench and
  harness, 5 of them in the shared tools repository's scripts.
- **With the versions moved, the mods' own port is small.** Four fixes made `load-check.ps1` pass:
  - two in the data stage: `rf-hc-turbine`'s fluid box can no longer carry
    `minimum_temperature`, and a recipe's `category` merged into `categories`;
  - two at runtime: `LuaFluidBoxPrototype.volume` became the method `get_volume()`, and
    `LuaRecipePrototype.category` became `categories`.

  A fifth change remains. 2.1 removes `LuaEntity.fluidbox` in favour of index methods on the
  entity, and the mod's runtime code reads it in five places. `load-check.ps1` passed with all
  five unported, so its pass did not show that the mod runs.
- **The harness's port is large.** The rigs use `fluidbox` 392 times across 38 scripts.

The figures, and each command that gave them, are in the measurement comment.

## Decision

**`factorio_version` is `"2.1"`.** A mod declares one major version and loads under no other
(ADR 0026 quotes the rule), so the mods stop loading on 2.0. Truls declined to keep a 2.0.77
install for the gates.

**The dependency floor is `base >= 2.1.23`.** This is ADR 0008's reasoning, carried over: the floor
is the only build anything here can be tested on.

**New documentation and API claims pin to `/2.1.23/`.** An existing claim pinned to `/2.0.77/` is
rechecked only where the code it backs breaks on 2.1, and otherwise keeps its pin. A stale explicit
version is visibly stale, which is why ADR 0008 pinned in the first place. `/stable/` and
`/latest/` stay forbidden.

**Each third-party pin moves to its family's 2.1 release**, re-derived the way ADR 0026 derived
it, `riteg` included. Truls first dropped the `riteg` lane on the premise that RITEG never got a
2.1 release. That premise came from ADR 0026's 2026-08-26 reading and was out of date. On
2026-10-24 the mod portal (`mods.factorio.com/api/mods/RITEG/full`) listed two
`factorio_version` 2.1 releases, 1.3.12 and 2.1.2, both from 2026-09-11, after that reading. Told this, Truls kept the lane the same day.

**The v1 target is the Factorio 2.1 base game, with Space Age tolerated but not integrated.**
ADR 0003's Space Age decision is unchanged, and so is the open question of whether Space Age ever
becomes a first-class target.

## Consequences

- **Nothing changes in the mods until
  [#767](https://github.com/trulsjo/realistic-fusion-refreshed/issues/767).** This ADR records the
  decision. The mods still declare 2.0, and `CLAUDE.md`'s State section still says what they load
  against. #767 ports the mods and moves both.
- **The `check-*.ps1` gates stay red for longer than the mods do.** Their rigs are ported in
  [#768](https://github.com/trulsjo/realistic-fusion-refreshed/issues/768) to
  [#771](https://github.com/trulsjo/realistic-fusion-refreshed/issues/771). Until those land,
  `load-check.ps1` is the only gate that creates a map and can pass, and the measurement showed what it misses.
- **The shared tools move first.** trulsjo/grado-factorio-tools#199 has the mods its scripts write
  declare 2.1, and [#765](https://github.com/trulsjo/realistic-fusion-refreshed/issues/765) moves
  this repository's pin past it. #767 waits on both.
- **The probes and benches only get their version moved, in
  [#773](https://github.com/trulsjo/realistic-fusion-refreshed/issues/773).** Each gets its API port
  when it is next run for a question.
- **No player's save can break, because there are no players.** The mod is not published
  (`README.md`). Whether a 2.0 save of it loads on 2.1 was not measured. #767 states save
  compatibility, as `CLAUDE.md`'s breaking-change rule asks.
- **A figure measured on 2.0.77 keeps its version.** Research notes, probe reports and ADRs that
  say 2.0.77 recorded what was true there. A figure is re-measured on 2.1.23 when a ticket needs
  it, and is not re-read as a 2.1 figure meanwhile.
- **The third-party sets are re-derived in
  [#772](https://github.com/trulsjo/realistic-fusion-refreshed/issues/772)**, which also decides
  how the derivation reads 2.1's `+` prefix.

## Alternatives considered

**Install 2.0.77 and keep the gates on it.** This needs no code change, and it keeps everything
measured so far valid. Truls declined it (#763, Q2).

ADR 0026 rejected moving on five grounds. Three no longer hold:

- 2.1 was the experimental branch. It is now stable.
- The mod would stop loading on stable. It now stops loading on 2.0 instead.
- RITEG would drop out. It has 2.1 releases.

The other two are costs this move accepts:

- Every rig runs on a version nothing here was tested on. That is paid in #767 to #771.
- ADR 0003's base game reopens. Its dated note moves it to 2.1.

**Floor at `base >= 2.1`.** Rejected for ADR 0008's reason: it claims patch versions nobody here
has run the mod against.
