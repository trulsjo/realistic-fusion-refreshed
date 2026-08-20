# Realistic Fusion Refreshed

Work-in-progress [Factorio](https://factorio.com) mod. The goal is to finish **Realistic Fusion 2.0** —
a fusion-power mod series left unfinished. The *2.0* there is the mod's own version number, not the
game's: the redesign carrying it was built for Factorio **1.1** and abandoned around the time Factorio
2.0 arrived.

**Status: in development.** Two mods load against Factorio 2.0.77 and **all four fusion reactions are
playable** — the extraction chain, D-D reactors that breed their own tritium, D-T fusion burning it,
lithium blankets breeding more, and an aneutronic tier where D-He3 and He3-He3 run in a denser reactor
whose output goes straight to electricity through a direct energy converter, with no steam loop at all.
All balance is provisional and the mod is not published on the mod portal.

**Every prototype ADR 0010 names for the Power module now exists** — all thirteen entities and all
seven technologies, high-capacity steam equipment included. That is a statement about coverage and
not about balance: the numbers behind them are still provisional, and nothing here has been played
for longer than a test rig runs.

## Before you install

Two things this mod deliberately does not do. Both are decisions rather than oversights, and both are
the kind that otherwise get discovered by a player rather than by a build — which is why they are here
and in the mod description rather than in a changelog.

**Predecessor saves are not supported.** Nothing carries over from Realistic Fusion Power or from
Durikkan's 2.0 port, and no migration is provided. The prototype names here share no prefix with
either (`rf-` against their `rfp-`), so the game cannot match one to the other even in principle — and
the mod's own name is what a save binds to, which is not transferable at all. The practical effect on
a port user is that their fusion setup has to be rebuilt. Durikkan's port can stay installed beside
this mod, which is what the distinct prefix buys; what it does not buy is continuity. The 1.1
original cannot, and not for any reason of ours — it declares `factorio_version` 1.1, so Factorio
2.0 will not load it at all. See [ADR 0006](docs/adr/0006-clean-break-from-predecessor-saves.md).

**The buildings are not balanced for quality.** The mod loads and runs under Space Age with `quality`
enabled — that much is verified, against Factorio 2.0.77 — and that is the whole of the claim. Nothing
here is tuned against quality, and nothing is reconciled with the vanilla fusion reactor. Durikkan's
port warned that "certain buildings in this mod get insanely overpowered with quality" and named none
of them; this one names the gap instead of leaving it to be found. See
[ADR 0003](docs/adr/0003-space-age-tolerated-not-targeted.md).

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
- Which other mods (K2, Angel's/Bob's, Space Exploration, IR2) are compatibility targets.

Two that used to be on this list are settled and are stated above rather than here: the target is the
Factorio 2.0 base game with Space Age tolerated but not integrated ([ADR 0003](docs/adr/0003-space-age-tolerated-not-targeted.md)),
and the published name is Realistic Fusion Refreshed ([ADR 0017](docs/adr/0017-the-plain-name-is-left-alone.md)).

## Licence

**[LGPLv3](LICENSE)**, with [the GPLv3 text](LICENSE.GPL) it incorporates by reference.

The mod's graphics are Krastorio 2's, and so are the sprite definitions that place them — Krastorio 2
is LGPLv3, mod and assets alike. What this project takes from Realistic Fusion Power is ideas, not
code. So the licence the borrowed material already carries is the licence for the whole repository,
rather than a permissive repository with an LGPL boundary inside it that anyone reusing this would
have to find first.

It was The Unlicense until 2026-08-16, chosen then to stay in the spirit of Romner_set (WTFPL) and
Durikkan (The Unlicense). `legal-note.txt` records what changed and what still has to be checked per
directory — chiefly that NonCommercial and NoDerivatives material is never lifted, which LGPLv3 does
nothing to relax.

## Reference

Factorio's Lua API is documented per game version at <https://lua-api.factorio.com/>. Note that
`/stable/` and `/latest/` differ — `latest` is the experimental build — so pin an explicit version
when it matters.
