# 43. CC0 image textures may be imported; meshes stay ours

Date: 2026-10-26

## Status

Accepted. **Decided by Truls, 2026-10-26**, in the grilling that opened the second attempt at
denser rendered art.

**Amends [ADR 0030](0030-art-is-rendered-from-stored-models.md)** in one clause: its *"Nothing is
imported"* paragraph. The rest of ADR 0030 stands, and ADR 0030 carries a dated note pointing here.

## Context

ADR 0030 banned Poly Haven, Sketchfab and image textures, and gave its reason as provenance:
*"so every model and every render is original and carries the repository's LGPLv3"*. It called that
*"the one rule in this ADR that cannot be relaxed for convenience"*. The repository has since called
it "the licence rule", in both models' `build.py` and in `graphics/rendered/pictures.lua`.

What licence a CC0 texture puts on a render is a separate question. Poly Haven says of its assets
*"Our assets are all licensed as CC0"* and *"You do not need to give credit"* (polyhaven.com/license,
read 2026-10-27, quoted and not graded). That CC0 material may sit inside an LGPLv3 work is
*inferred* from CC0 being a waiver of every right the author holds. No lawyer has read it.

The second attempt at detail starts from a gap read by eye, not measured.
`scripts/probe-isotope-collector-art.ps1` put `rf-isotope-collector` beside Krastorio 2's reactor on
2026-10-26, on 2.1.23. To the session that photographed it, ours still read pale and flat. #798
lists the five gaps that session read, and surface texture is not among them.

Truls allowed CC0 textures anyway. The session's reasoning was that procedural noise makes poor grain
at 64 px per tile, either washing out or turning into render noise. That is not measured, and #799's
normal-pass figure is what would test it.

## Decision

**A CC0 image texture may be imported into a model**: rust, grime, painted metal, rubber and the
like. It must be CC0. It is recorded beside the model that uses it, with its source URL and its
licence, and the rendered sheets carry the repository's LGPLv3 as before.

**Meshes are not imported**, CC0 or otherwise. Every shape is built by a model's script or by a
**kit part** (`GLOSSARY.md`). The kit is what this attempt is building, and imported meshes would
replace it rather than feed it.

Sketchfab stays out, along with any source that is not CC0. Its licences are set per asset, and
that was not read here.

## Considered options

- **Keep the ban.** That was defensible: the gaps the session read in the baseline are value range
  and part vocabulary, not surface texture. It was rejected because CC0 costs only a provenance
  file, and texture may still prove to be a gap, a question #799's figures can answer.
- **Allow CC0 meshes too.** Rejected: it trades the set's own shape language for whoever modelled
  the asset, and it undercuts the kit.
