# 30. Art is rendered from stored models

Date: 2026-09-06

## Status

Accepted. Decided by Truls on 2026-09-04 while charting
[#238](https://github.com/trulsjo/realistic-fusion-refreshed/issues/238), and proven on 2026-09-05
when `rf-heat-exchanger` was accepted in the game and
[#108](https://github.com/trulsjo/realistic-fusion-refreshed/issues/108) closed against every
acceptance criterion.

**Written after the proof, not before it**, on Truls's instruction — the route was chosen on paper,
and nothing was recorded until a machine actually wore it.

Rests on [ADR 0001](0001-liftable-predecessor-material.md), which is why original art was needed at
all, and on [ADR 0023](0023-art-ships-in-its-own-mod.md), which is why a model is not a shipped
thing. Vocabulary is [`CONTEXT.md`](../../CONTEXT.md)'s **Art** section: mockup, rendered art, look
note, house style, model, regenerate.

## Context

Three pressures, and a drawing tablet answers only one of them.

**Provenance leaves exactly one route open.** #108 checked Krastorio 2 exhaustively by footprint:
its building set is essentially square — 7×7 and 15×15 — and its only elongated pieces are the 5×7
advanced steam turbine, which `rf-hc-turbine` already wears, and a 22×3 logo. Nothing in it is
5×15. The predecessor *does* have that sheet, `graphics/entity/heat-exchanger.png` at 383×1088,
precisely the shape and needing no derivation at all — and it is **unmarked**, in a mod whose
changelog credits YuokiTani, angel's discarded thread and PreLeyZero for unmarked art without
saying which files are whose. ADR 0001 says ask rather than assume. It was asked, and the answer
was no. So original art was not a preference; it was what was left.

**The mockups state geometry that nothing checks.** `scripts/make-mockup-art.ps1` says so in its own
header: *"THE CONNECTION LIST HERE MUST AGREE WITH prototypes/entities.lua. Nothing enforces it:
this script never loads the game."* A mockup exists to stop a sprite lying about where the pipes go,
and its own connection list is hand-copied against a Lua file it never reads. That is the failure
mode a placeholder is supposed to prevent, reintroduced one layer up.

**Hand-drawing does not scale to a set whose footprints move.** One machine is four rotations of
structure, four of shadow, four of glow and a 120×64 icon strip — thirteen PNGs — and every one of
them is redrawn when a footprint changes. Footprints change here: #108 took this machine from 3×2
to 5×15, and ADR 0013 did the same to the reactor. Four more mockup machines are waiting behind it,
and the Krastorio 2 buildings are slated to go if this route works.

## Decision

**Every sprite this mod draws of its own is rendered headlessly from a stored Blender model.** Four
parts, in the words `CONTEXT.md` fixes:

- **House style** — `models/house-style.md`, one text for the whole set: palette (one accent per
  fluid), materials, level of detail, how a connection is shown. Written for the full machine set
  rather than for the five mockups, because it has to survive replacing the Krastorio 2 art.
- **Look note** — free prose per machine, in a `--[[ look: rf-<machine> … ]]` marker above the
  prototype in Lua. Read by the pipeline, never by the game. Writing one is Truls's call, not an
  agent's: it is what the machine should *look like*.
- **Model** — `models/<machine>/`, holding the `.blend` a person edits and the `build.py` that
  rebuilds it. Neither ships. A model is not a sprite, so ADR 0023 keeps it out of Assets, and
  `models/` sits at the top level where no mod zip can reach it.
- **Geometry from the game, never from the prose.** `tools/extract-geometry.py` reads footprint and
  connections out of `--dump-data`, so sockets sit where the prototype actually puts them, and
  `load-check.ps1` fails when a rendered `manifest.json` and the live prototype disagree
  ([#250](https://github.com/trulsjo/realistic-fusion-refreshed/issues/250)). That gate is the
  enforcement the mockup's hand-copied list never had, and it is the half of this decision that is
  about correctness rather than about pictures.

`/render-machine rf-<machine>` runs it. **Render is the default and regenerate is explicit**, so a
hand edit to a stored model survives an ordinary render; git is the only guard against a
`--regenerate` over one, and that is accepted rather than engineered around.

**Nothing is imported.** Procedural Principled materials only — no PolyHaven, no Sketchfab, no image
textures — so every model and every render is original and carries the repository's LGPLv3. This is
the whole reason the route was taken, and it is the one rule in this ADR that cannot be relaxed for
convenience. A rendered icon that replaces a Krastorio 2 one removes that entry from the NOTICE; the
heat exchanger's did, so nothing of K2 is left on that machine.

**Renders are deterministic.** PNG timestamps off, `random.seed` in the build, camera and light
numbers in `models/rf_blender.py` once and recorded in the manifest. Re-rendering an unchanged model
gives the same bytes, verified over fourteen hashes.

## Consequences

- **Binary models live in git, and they churn.** One machine, one day: five commits on 2026-09-05
  touched `models/heat-exchanger/heat-exchanger.blend`, each storing a fresh copy — 256 097,
  254 249, 254 550, 723 141, then 1 483 592 bytes as detail went in. The five sum to 2 971 629
  bytes of history for a machine whose current model is the last of them. Git cannot delta a
  `.blend` usefully, so every look revision costs its full size forever. Five machines at this rate
  is a repository that grows by art it never ships. No mitigation is built: LFS was not weighed, and
  `build.py` is not treated as the model — see the last alternative below, which is the same
  question from the other end.
- **A contributor who touches art needs Blender 5.2.0 LTS.** It is not on PATH; `render-machine.py`
  finds it through `--blender`, `$BLENDER_EXE`, a running `blender.exe`, a `Downloads` unzip, then
  Program Files. Generating a model also wants it reachable over MCP, to look at what is being
  built. Neither is needed to *play* or to build a zip.
- **Python 3 on PATH now binds everyone, not only art contributors.** The agreement gate calls
  `extract-geometry.py`, so `load-check.ps1` — the gate every change runs — fails without it.
  That is a wider dependency than the Blender one and a lighter one, and it arrived as a side
  effect of this decision rather than as part of it.
- **Acceptance is still a person looking.** The pipeline proves a render is deterministic and
  agrees with the prototype; it cannot say whether the machine reads right. `scripts/probe-heat-exchanger-art.ps1`
  places and photographs a machine in a real map — the first script here that needs the graphical
  client — and Truls accepted the heat exchanger after four rounds of that. Automating the placing
  and the photographing is as far as it goes.
- **A footprint change is now cheap; a look change is not.** Moving a connection is `--regenerate`
  and the sockets follow. Changing how a machine looks is prose, then `build.py`, then a person's
  eye, and the four rounds on the heat exchanger are the honest estimate of what that costs.
- **The Krastorio 2 art becomes replaceable, which is not the same as replaced.** The house style is
  written for the whole set on that assumption. Actually replacing it is a separate effort and was
  ruled out of scope of #238.

## Alternatives considered

- **The predecessor's heat exchanger sheet.** Exists at exactly the right shape, needs no derivation,
  and is formally covered by the port's root Unlicense. Rejected on provenance: a public-domain
  dedication disposes only of what its declarer owned, the directory is unmarked, and three outside
  donors are credited for unmarked art without attribution by file. Asked and refused (#108).
- **Krastorio 2.** The source of every other sprite here, properly licensed and marked, and the
  path of least resistance. Rejected on footprint: nothing in the set is 5×15, checked exhaustively
  against every K2 building.
- **Hand-drawn art.** The obvious route, and the one #108 was blocked on for a fortnight —
  `ready-for-human` because *"this cannot start until someone draws it"*. Rejected on the
  arithmetic above: thirteen sheets per machine, redrawn whenever a footprint moves, times the
  whole set.
- **Mockups forever.** Honest, original, free, and already shipping. Rejected because a mockup
  declares itself unfinished and because its connection list is checked against nothing — the
  defect this decision closes with the manifest gate.
- **A model built from a script only, with no stored `.blend`.** Would keep the repository text-only
  and delete the churn cost above outright, which is the strongest argument any alternative here
  has — and on the record so far it is unanswered. **No hand edit has happened yet.** All five of
  the heat exchanger's model commits changed `build.py` in the same commit, and `build.py` opens by
  wiping the scene and rebuilding it procedurally, so every look revision to date went through the
  script and a regenerate. Truls's four rounds of reactions reached the model as edits to Python.
  So the `.blend` is stored for a capability rather than for an observed practice: a shape easier to
  drag than to describe, on some machine that has not been built yet. That is a bet, it is what the
  churn above buys, and it is the part of this ADR most likely to be revisited. It is recorded as a
  bet rather than dressed up as a finding.
