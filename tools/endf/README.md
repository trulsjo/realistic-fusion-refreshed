# ENDF cross-sections

Input to `tools/derive-reactivities.py`. Not shipped with the mod — only the derived
`RealisticFusion/cross-section-data/reactivities.lua` is.

These are committed rather than referenced so the derivation can actually be re-run. A generator
whose only input lives in a temporary directory on one machine is not reproducible, whatever its
header claims.

## What they are

Fusion cross-sections σ(E) from **ENDF/B-VIII.0**, published by the IAEA:
<https://www-nds.iaea.org/exfor/endf.htm>. Columns are `E,eV` (laboratory frame, stationary
target) and `Sig,b` (barns).

| File | Reaction | Points |
|---|---|---:|
| `D-D_T_cross-section.json` | D + D → T + p | 250 |
| `D-D_He3_cross-section.json` | D + D → He3 + n | 254 |
| `D-T_cross-section.json` | D + T → He4 + n | 375 |
| `D-He3_cross-section.json` | D + He3 → He4 + p | 310 |
| `He3-He3_cross-section.json` | He3 + He3 → He4 + 2p | 51 |

`He3-He3` is far more sparsely measured than the rest — 51 points against D-T's 375 — so the
aneutronic tier's numbers rest on thinner data than the neutronic one.

## Provenance

Taken from Romner_set's `realistic-fusion-dev`, directory `.cross-section-data/raw-ENDF/`. That
directory carries **no licence file**, so under
[ADR 0001](../../docs/adr/0001-liftable-predecessor-material.md) it is permissive; the
repository's default licence is WTFPL. The underlying nuclear data is published by the IAEA.

Attribution to **Romner_set** for assembling these tables, per `CLAUDE.md`.

**The reactivities from that same upstream directory were not taken.** Its generator paired
reactivities computed on a temperature grid against the cross-section energy grid, putting the
D-T peak roughly 3× too high at about a fifth of the right temperature. The cross-sections here
are sound — D-T peaks at 5.01 barns, as it should — so only the derivation was redone. See
`tools/derive-reactivities.py`.
