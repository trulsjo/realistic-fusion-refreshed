# 17. The mods take the Refreshed name, and the plain one is left alone

Date: 2026-08-20

## Status

Accepted. **Supersedes the two internal names and the two titles decided by
[ADR 0009](0009-mod-names-and-prototype-prefix.md)**, which re-decides
[#8](https://github.com/trulsjo/realistic-fusion-refreshed/issues/8). That ADR's other decision — the
prototype prefix `rf-` — is untouched and still holds; see the Consequences.

ADR 0009 is not edited. It records what was decided on 2026-08-14 and why, which is worth keeping
legible; this is the ADR the current names live in. ADR 0010 asks to be amended by a superseding ADR
rather than drifted from silently, and 0012 and 0013 already do that to it — this is the same shape.

Decided by Truls, 2026-08-20.

## Context

ADR 0009 weighed two things: whether a name was free on the portal, and how the pair would read in a
listing. On those terms `RealisticFusion` won easily — it was unclaimed, and it is the most natural
name for the thing. That ADR then rejected the Refreshed pair in as many words:

> **`RealisticFusionRefreshed` plus `RealisticFusionRefreshedCore`.** Matches this repository's name
> and signals a new take rather than a continuation. Rejected: "Refreshed" reads as a repository
> codename rather than a product name, and the pair is wordy in a portal listing.

**What it did not weigh is who else might want `RealisticFusion`.** Romner_set deprecated the original
and archived its successor read-only. He may never come back. But if he did, `RealisticFusion` is the
name he would most plausibly want for it — it is the natural shortening of his own
`RealisticFusionPower` — and a name on the portal is taken once and not again.

ADR 0009 did consider impersonation and cleared it: *"Taking `RealisticFusion` reads as a successor
without claiming to **be** either."* That is a different question from this one. Not impersonating him
is about what a player would infer. Not taking the name is about what he would have left.

**And this repository has already decided not to ask him.** `CLAUDE.md` is explicit: *"Do not try to
contact Romner_set. He deprecated the mod, archived the successor read-only and anonymised his GitHub
account. That is someone stepping away deliberately; respect it."* So holding the name on his behalf
is not available either — it would mean either sitting on it indefinitely or contacting him to offer
it back, and the second is ruled out. The only way to leave him the name is not to take it.

**The window for this is now, and ADR 0009 is what says so.** It recorded that internal names *"bind
permanently in practice: dependencies and saves reference them, so changing one after publication
breaks both"*, and warned that a later rename would repeat the save break that
[ADR 0006](0006-clean-break-from-predecessor-saves.md) accepted once deliberately. Nothing is
published, so the cost is a development save and nothing else. After publication this decision would
not be available at any acceptable price.

## Decision

| | Internal `name` | `title` |
|---|---|---|
| Main mod | **`realistic-fusion-refreshed`** | **Realistic Fusion Refreshed** |
| Library | **`realistic-fusion-refreshed-core`** | **Realistic Fusion Refreshed Core** |

**Lower case with hyphens, rather than the CamelCase of the names it replaces.** The portal's rule is
alphanumerics, dashes and underscores, so both forms are permitted; the hyphenated one reads better as
a URL and as a directory, and it is what the repository is already called.

**Both names are free.** `https://mods.factorio.com/mod/realistic-fusion-refreshed` and
`.../realistic-fusion-refreshed-core` both return HTTP 404, checked 2026-08-20. A 404 is evidence of
availability rather than proof of it, and it should be re-checked immediately before publishing.

**`RealisticFusion` is left free, and not reserved.** No placeholder is uploaded to hold it.

## Consequences

- **The repository's mod directories are renamed with the mods, and that is forced rather than
  chosen.** `New-ModJunctions` in `scripts/factorio-lib.ps1` links each mod into a temporary mod
  directory *under its directory name*, and Factorio requires a mod folder to be named for the mod. So
  `RealisticFusion/` becomes `realistic-fusion-refreshed/` and `RealisticFusionCore/` becomes
  `realistic-fusion-refreshed-core/`, and the `$ourMods` list every rig carries changes with them.
- **The prototype prefix stays `rf-`.** ADR 0009 justified it by not colliding with the `rfp-` of the
  original and Durikkan's port, so that this mod and the port remain installable side by side. That
  reasoning does not depend on the mod's name and is unaffected. Changing the prefix would rename every
  prototype in both mods and break every save that has one, for nothing.
- **Saves break, and no player is affected.** Renaming the internal name makes this a different mod as
  far as the engine is concerned: a save from before it will not load, and `migrations/` cannot bridge
  it because migrations are keyed to the mod name too. Nothing is published, so the only casualty is a
  development save.
- **Earlier ADRs keep the old names, deliberately.** ADR 0009's decision table, ADR 0010's layout and
  ADR 0013's path to `RealisticFusion/graphics/krastorio-2/buildings/` all still say what they said.
  They are records of what was decided and observed at the time, and rewriting them to match a later
  decision would falsify the record — the same reason ADR 0011 and ADR 0015 carry corrections rather
  than edits. Live path references in `docs/research/` *are* updated, because a reader follows those.
- **References to a predecessor are untouched**, and there are more of them than of ours: the
  redesign's own `RealisticFusionCore/electric-boiler/` and `graphics/icons/angels-numerals/` in
  `CLAUDE.md` and ADR 0001, `RealisticFusionPower`, `RealisticFusionPowerPort`,
  `RealisticFusionWeaponry`, the `rfp-` prefix, and "Realistic Fusion 2.0" — which is the *redesign's*
  mod version and not a title of ours (`CONTEXT.md` fixes that term).
- **`CONTEXT.md` moves with it**, since it fixes the two mods' names and titles as vocabulary.

## Alternatives considered

**Keep `RealisticFusion`.** What ADR 0009 decided, and it is still the better name in isolation:
shorter, more natural, and already justified as non-impersonating. Rejected on the one ground that ADR
did not weigh — it is the name Romner_set would want back, and taking it forecloses that permanently
for a gain measured in two words of listing width.

**Take `RealisticFusion` and give it up if he ever returns.** Rejected as a promise that cannot be
kept: it would require either sitting on the name indefinitely or contacting him to hand it over, and
`CLAUDE.md` rules the second out. A name held for someone who cannot be told it is held for them is
simply taken.

**`RealisticFusionRefreshed` plus `RealisticFusionRefreshedCore`.** ADR 0009's own rejected
alternative, and the CamelCase matches the style of the pair being replaced. Rejected in favour of the
hyphenated form: the portal permits both, and the hyphenated one matches the repository and reads
better as a URL and a directory name. The substance of 0009's objection — that "Refreshed" is wordy —
is accepted as true and paid anyway.

**Rename only the main mod and leave `RealisticFusionCore`.** Rejected: it produces exactly the
asymmetric pair ADR 0009 rejected for the same reason, and `RealisticFusionCore` is a name the archived
redesign used, so leaving it takes a second name that is not ours to take either.
