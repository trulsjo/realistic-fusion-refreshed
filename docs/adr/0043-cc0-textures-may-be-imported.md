# 43. CC0 image textures may be imported; meshes stay ours

Date: 2026-10-26

## Status

Accepted. **Decided by Truls, 2026-10-26**, in the grilling that opened the second attempt at
denser rendered art.

**Amends [ADR 0030](0030-art-is-rendered-from-stored-models.md)** in one clause: its *"Nothing is
imported"* paragraph. The rest of ADR 0030 stands, and ADR 0030 carries a dated note pointing here.

## Context

ADR 0030 banned Poly Haven, Sketchfab and image textures so that every model and every render would
be original and carry the repository's LGPLv3. It called that *"the one rule in this ADR that cannot
be relaxed for convenience"*. The ban was never about legality: Poly Haven's assets are CC0, and CC0
material may sit inside an LGPLv3 work. It was about provenance. If everything is ours, there is one
story to tell and nothing goes in the NOTICE.

The second attempt at detail starts from a measured gap. `scripts/probe-isotope-collector-art.ps1`
put `rf-isotope-collector` beside Krastorio 2's reactor on 2026-10-26, and ours still read pale and
flat. Texture is one of the places we are flattest. Procedural noise makes poor grain at 64 px per
tile: it either washes out or turns into render noise.

## Decision

**A CC0 image texture may be imported into a model**: rust, grime, painted metal, rubber and the
like. It must be CC0, which in practice means Poly Haven. It is recorded beside the model that uses
it, with its source URL and its licence, and the rendered sheets carry the repository's LGPLv3 as
before.

**Meshes are not imported**, CC0 or otherwise. Every shape is built by a model's script or by a
**kit part** (`GLOSSARY.md`). The kit is what this attempt is building, and imported meshes would
replace it rather than feed it.

Sketchfab stays out: its licences vary per asset, and some of them are NonCommercial.

## Considered options

- **Keep the ban.** That was defensible, because the baseline gap is mostly value range and part
  vocabulary, not surface texture. It was rejected because texture is still a gap, and CC0 costs
  only a provenance file.
- **Allow CC0 meshes too.** Rejected: it trades the set's own shape language for whoever modelled
  the asset, and it undercuts the kit.
