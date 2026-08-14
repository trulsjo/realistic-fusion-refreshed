# 9. Mod names and prototype prefix

Date: 2026-08-14

## Status

Accepted. Resolves
[Choose the published mod name](https://github.com/trulsjo/realistic-fusion-refreshed/issues/8).

## Context

[ADR 0002](0002-v1-scope-and-module-split.md) ships v1 as two mods, so this is five values rather than
one: two internal names, two display titles, and the prototype prefix.

Per the mod-structure documentation at `/2.0.77/`:

- **`name`** is the internal identifier. The mod portal restricts it to alphanumerics, dashes and
  underscores, longer than 3 and shorter than 50 characters, and the zip must be
  `{mod-name}_{version-number}`.
- **`title`** is the human-readable display name, localisable, and the portal ignores its length limit.

Internal names bind permanently in practice: dependencies and saves reference them, so changing one
after publication breaks both.

Portal availability, checked 2026-08-14:

| Name | Status |
|---|---|
| `RealisticFusion` | free |
| `RealisticFusionRefreshed` | free |
| `RealisticFusionCore` | free — the archived redesign used it but never published |
| `RealisticFusionPower` | taken (Romner_set) |
| `RealisticFusionPowerPort` | taken (Durikkan) |
| `RealisticFusionWeaponry` | taken |

A straight lineage pair was therefore unavailable: `RealisticFusionPower` is Romner's. But
`RealisticFusion` — the most natural name for the thing — is unclaimed.

## Decision

| | Internal `name` | `title` |
|---|---|---|
| Main mod | **`RealisticFusion`** | **Realistic Fusion** |
| Library | **`RealisticFusionCore`** | **Realistic Fusion Core** |

**The prototype prefix is `rf-`.**

`rf-` satisfies the constraint from [ADR 0006](0006-clean-break-from-predecessor-saves.md) that names
must not collide with the `rfp-` prefix used by the original and Durikkan's port, so this mod and the
port remain installable side by side. The archived redesign also used `rf-`, but it was never published
to the portal; the only mod that might otherwise clash is 1.1-only and so cannot be loaded alongside a
2.0 mod at all.

## Consequences

- **These names are effectively permanent.** Saves and dependencies bind to the internal name, so a
  later rename breaks both — the same failure mode [ADR 0006](0006-clean-break-from-predecessor-saves.md)
  accepted once deliberately and should not repeat by accident.
- **`RealisticFusionCore` is reused from the archived redesign.** It is unpublished, so there is no
  portal conflict, and the continuity is honest rather than misleading — the concept is the same one.
- **The naming does not impersonate a predecessor.** `RealisticFusionPower` and
  `RealisticFusionPowerPort` remain theirs, and are actively maintained in Durikkan's case. Taking
  `RealisticFusion` reads as a successor without claiming to *be* either.
- **Attribution still applies.** `CLAUDE.md` requires crediting Romner_set, Durikkan and PreLeyZero for
  anything derived from their work — a name similar to theirs makes that more important, not less.
- **Titles are localisable**, so the display names can be translated later without touching the internal
  names.

## Alternatives considered

**`RealisticFusionRefreshed` plus `RealisticFusionRefreshedCore`.** Matches this repository's name and
signals a new take rather than a continuation. Rejected: "Refreshed" reads as a repository codename
rather than a product name, and the pair is wordy in a portal listing.

**Keep `RealisticFusionCore` and rename the power half** — something like `RealisticFusionReactors`,
since `RealisticFusionPower` is taken. Rejected: it produces an asymmetric pair whose second name is
chosen by what happened to be left over rather than by what the mod is.
