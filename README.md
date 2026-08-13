# Realistic Fusion Refreshed

Work-in-progress [Factorio](https://factorio.com) mod. The goal is to finish **Realistic Fusion 2.0** —
a fusion-power mod series left unfinished. The *2.0* there is the mod's own version number, not the
game's: the redesign carrying it was built for Factorio **1.1** and abandoned around the time Factorio
2.0 arrived.

**Status: planning. No code yet.** This repository was initialised empty; nothing here is playable, and
the mod is not published on the mod portal.

## What it is meant to be

Fusion power modelled on real physics rather than a single black-box reactor: deuterium extracted from
water, plasma heating, magnetic confinement, several distinct fusion reactions (D-D, D-T, D-He3,
He3-He3), tritium and helium-3 breeding, and an equipment line of heaters, reactors, heat exchangers,
turbines and direct energy converters.

That is the shape inherited from the predecessors below. What this project ends up being is not
settled yet — see [Open questions](#open-questions).

## Lineage

Three pieces of prior work exist, all permissively licensed:

| | What | Factorio | Licence |
|---|---|---|---|
| [Realistic Fusion Power](https://mods.factorio.com/mod/RealisticFusionPower) | The original, by **Romner_set**. Unmaintained since 2024-10. | 0.17–1.1 | WTFPL |
| [Realistic Fusion Power Port](https://mods.factorio.com/mod/RealisticFusionPowerPort) | A port of the original to 2.0 by **Durikkan**, minimal balance/gameplay change. | 2.0 | The Unlicense |
| [realistic-fusion-dev](https://github.com/4881e05257b099383da78c50269d2ceb/realistic-fusion-dev) | An unfinished **redesign** (the mod's own 2.0) splitting the mod into four modules (Core, Power, Weaponry, Antimatter). Archived read-only 2026-04. | 1.1 | WTFPL |

Credit for the original design and implementation belongs to Romner_set, for the 2.0 port to Durikkan,
and for graphics work to PreLeyZero. None of these licences requires attribution; it is given because
it is deserved.

Note that a repo-level licence does not cover everything inside these mods: all three carry graphics
derived from [Krastorio 2](https://mods.factorio.com/mod/Krastorio2), which is LGPLv3. Both published
predecessors handle this by keeping such material in its own directory with its own licence file, and
this project follows the same convention — see [`legal-note.txt`](legal-note.txt).

## Open questions

Deliberately unanswered so far, and worth knowing before reading anything into this repo:

- Whether to build on the unfinished four-module redesign, on the working 2.0 port, or on neither.
- Whether the four-module split survives at all, and whether Weaponry and Antimatter are in scope.
- Target: Factorio 2.0 base game, and whether the Space Age expansion is supported.
- Which other mods (K2, Angel's/Bob's, Space Exploration, IR2) are compatibility targets.
- The published mod name.

## Licence

**[The Unlicense](LICENSE)** — released into the public domain.

Chosen to stay in the spirit of the original authors: Romner_set released Realistic Fusion Power under
the WTFPL and Durikkan released the 2.0 port under The Unlicense. Both are public-domain-equivalent, so
this carries the same intent forward — do whatever you want with it, no conditions.

## Reference

Factorio's Lua API is documented per game version at <https://lua-api.factorio.com/>. Note that
`/stable/` and `/latest/` differ — `latest` is the experimental build — so pin an explicit version
when it matters.
