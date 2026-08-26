# 26. Third-party mods are pinned to their 2.0 line, and the claim is scoped to it

Date: 2026-08-26

## Status

Accepted. Decided by Truls, 2026-08-26, settling
[#59](https://github.com/trulsjo/realistic-fusion-refreshed/issues/59).

**Stands alongside [ADR 0008](0008-factorio-version-floor-and-doc-pin.md) rather than superseding
it.** Nothing ADR 0008 decided changes here: this repository still declares `factorio_version` 2.0,
still floors at `base >= 2.0.77`, and still pins documentation links to an explicit version rather
than `/stable/` or `/latest/`. Its trigger for revisiting — *"when 2.1 is stable"* — is still the
right trigger and is still unfired. What this ADR answers is a question ADR 0008 did not face: what
to do when **the ecosystem moves before the trigger does**. ADR 0008 gains a dated note pointing
here.

**Discharges nothing of [ADR 0007](0007-coexistence-without-integration.md), which was already
met.** That ADR's minimum — *"at minimum, loading alongside Krastorio 2 should be verified before v1
ships"* — is satisfied, for the 2.0 line and for name collision both. This ADR is about the coverage
*beyond* that minimum, and about what any of it licenses the project to say.

## Context

**ADR 0008's trigger has not fired, and the mods did not wait for it.** Checked against
<https://lua-api.factorio.com/> on 2026-08-26: latest stable is **2.0.77**, latest experimental is
**2.1.16**. ADR 0008 recorded 2.0.77 and 2.1.14 on 2026-08-14 and #59 re-checked on 2026-08-18. So
across twelve days stable did not move at all while experimental advanced twice — 2.1 is no closer
to being the stable branch than when ADR 0008 chose 2.0.

Meanwhile every overhaul family shipped a `factorio_version` 2.1 release: Krastorio 2 at 2.1.2,
Angel's at 2.1.x, Bob's at 3.0.x, Space Exploration at 0.7.61, MadClown's at 2.1.01, SeaBlock NG at
1.1.4 — all within two months. Factorio treats 2.0 and 2.1 as different major versions, and
`auxiliary/mod-structure.html` is explicit that a mod declaring one *"indicates support for all
releases under that major version, **and no other major releases**"*. None of those releases loads
on 2.0.77.

**This could not be solved in the test harness.** Because the major version is declared on both
sides, checking against a 2.1-era Krastorio 2 would require this repository's own mods to declare
`factorio_version` 2.1 — at which point they stop loading on stable for every player. There is no
arrangement where the mod ships for 2.0 and is checked against 2.1 with one install and one
`info.json`.

**The cost of pinning fell while the ticket was open.** #59's second acceptance criterion asks that
pinned versions live *"somewhere the download step can read rather than left in prose"*.
[#60](https://github.com/trulsjo/realistic-fusion-refreshed/issues/60) landed
`scripts/fetch-mods.ps1` the same day this was decided, whose `$MOD_SETS` manifest is exactly that
place. What the ticket priced as new machinery is now data entry.

## Decision

**Third-party mods are pinned to the last `factorio_version` 2.0 release of each family**, and those
pins live in `scripts/fetch-mods.ps1`'s `$MOD_SETS`. Moving this repository to
`factorio_version` 2.1 is **not** done, and is deferred to ADR 0008's existing trigger.

**A passing coexistence lane proves coexistence with that family's 2.0 line, and nothing about the
release players run.** No unqualified claim — "compatible with Angel's", "works with Space
Exploration" — may reach a portal listing, `README.md`, a mod description or a changelog on the
strength of these lanes. Where the claim is made at all it names the version it was proved against.
Krastorio 2 is under the same rule; ADR 0007's discharge is already worded that way.

**Set membership is computed, not transcribed.** Each family's closure was derived from the portal
API at the last fv 2.0 release of every member, following no-prefix and `~` dependencies and
ignoring `?`, `(?)`, `!` and `+`. Re-deriving it is how the pins get refreshed, and the script that
did it is the reason the numbers below are trustworthy rather than copied.

### The sets, as pinned

| Set | Mods | Notes |
|---|---|---|
| `krastorio2` | 5 | pinned by #60; the only family also fetched by git |
| `angels` | 8 | four content mods plus their four `~` graphics mods |
| `bobs` | 12 | **Bob's 2.1.x is a `factorio_version` 2.0 mod**; 3.0.x is the 2.1 one |
| `madclowns` | 7 | `Clowns-Processing` plus six Angel's mods it requires |
| `spaceex` | 17 | five deliberately large graphics mods among them |
| `seablock` | 46 | the as-intended pack, below |
| `riteg` | 1 | 2.0 only — never got a 2.1 release |
| `fluid` | 1 | Advanced Fluid Handling; slug is `underground-pipe-pack` |

**SeaBlock NG is pinned as-intended rather than minimal, and it is the expensive choice.**

> **Corrected 2026-08-26 (#127 review), same day.** This paragraph first justified the pack by
> saying `SeaBlockWanne` declares `SeaBlockPack` with `+`, a prefix the game does not enforce. **That
> is not true of the version pinned here.** `SeaBlockWanne` **1.0.5** names no `SeaBlockPack` at
> all; its hard requirements are the four Angel's content mods and their `~` graphics, a closure of
> **nine**. The `+ SeaBlockPack` line first appears in **1.1.4**, which is `factorio_version` 2.1 —
> a release this very ADR declines to target. At 2.0 the dependency runs the other way round:
> `SeaBlockPack` requires `SeaBlockWanne`. The claim was read out of
> `docs/research/mod-set-coexistence-targets.md` and never checked against the pinned release, which
> is exactly the discipline CLAUDE.md asks for and this ADR is about. **The decision stands and the
> reason is replaced**, below.

The real choice is between **nine** mods and **46**, and the pack is taken deliberately rather than
because any dependency asks for it: the lane is worth more answering *"does this mod load beside
what a SeaBlock player installs"* than *"beside the nine that strictly must load"*. Taking the pack
means the lane exercises the real configuration. Two consequences follow and neither is
optional: it needs **`-With quality`**, because `quality` is bundled with the game rather than on the
portal, and quality does not drag in `space-age`, which matters because `SeaBlockWanne` declares
`! space-age`. And it **overlaps the `angels` and `bobs` lanes**, because `SeaBlockPack` hard-depends
on twenty of their mods directly — the three sets are not independent samples.

**Lane separation is forced, not chosen.** `SeaBlockWanne` declares `! space-age` and
`! Krastorio2`; `space-exploration` declares `!` against fourteen Angel's and Bob's mods and against
`space-age`; `Krastorio2` declares `! Clowns-Nuclear`, `! bobequipment` and `! bobvehicleequipment`.
No single mod list can hold these families together, so each is its own set and its own run.

## Consequences

- **[#61](https://github.com/trulsjo/realistic-fusion-refreshed/issues/61) is unblocked** and
  inherits the pins. This ADR does not run the lanes, and a set that resolves on the portal is not
  yet a set that loads. Six of the eight have never been loaded at all.
- **The two that were smoke-tested both failed, and the failure is upstream's.** `riteg` and `fluid`
  were fetched and loaded to prove the pins are real rather than plausible. Both trip the asset
  check: RITEG 1.3.11 and `underground-pipe-pack` 2.0.6 each name
  `__base__/sound/car-metal-impact.ogg`, a path Factorio 2.0 removed. Neither is our bug and
  neither is a pinning artefact — a 1.1-era reference that survived into a 2.0 release. It is the
  predicted cost arriving on the first run: **triage on these lanes will often end at "upstream's",
  and #61 should budget for that rather than read a red lane as a defect here.** It also corrected a
  claim in `load-check.ps1`, which said the asset check does not cover the extra mods; it does cover
  the `__base__` paths they name.
- **[#33](https://github.com/trulsjo/realistic-fusion-refreshed/issues/33) keeps its answer.** Its
  Krastorio 2 half was checked against 2.0.19, which is what this ADR pins, so nothing it recorded
  needs redoing.
- **The coverage is against a snapshot upstream has left behind**, in two families visibly
  mid-development on their 2.0 line. Accepted deliberately: most of what a coexistence lane catches
  is *our* fault — a prototype name collision, a recipe clash — and those exist against a family's
  2.0 line and its 2.1 line alike, because our mod is the same in both. What a stale snapshot cannot
  catch is what upstream changed after it, which is precisely why the claim is scoped above.
- **MadClown's is incomplete at any version.** `Clowns-Science` is `factorio_version` 1.1 only, so
  that lane is four Clowns mods and never the full family. Not a pinning artefact; recorded so it is
  not rediscovered as a failure.
- **No family below Krastorio 2 has a verified git source yet**, so all of them take
  [#60](https://github.com/trulsjo/realistic-fusion-refreshed/issues/60)'s portal fallback and
  therefore need Factorio credentials. Angel's, Bob's, MadClown's and SE are on public git and
  SeaBlock NG is on codeberg, but no tag mapping has been verified, and a guessed tag fails at fetch
  time. Adding `Git` entries later is per-mod and changes nothing else.
- **These lanes cannot run on a machine that has never signed in to Factorio.** That precondition
  arrived with #60 and this ADR extends it from one optional family to seven.
- **Refreshing the pins is re-deriving them**, not editing prose. When ADR 0008's trigger fires the
  same derivation runs against the 2.1 releases and the manifest is replaced wholesale.
- **The cache is per set**, `.mod-cache/<set>/`. One shared directory accumulated every set ever
  fetched and `load-check` junctions all of it, so krastorio2 followed by seablock produced a 51-mod
  directory that no lane asked for and that `SeaBlockWanne` forbids (`! Krastorio2`). It also could
  not hold `flib` at both 0.16.2 and 0.16.5, which the two lanes pin separately. Corrected in the
  same review as the rationale above.

## Alternatives considered

**Move the project to 2.1.** Rejected because ADR 0008 set the condition itself and the condition is
unmet: 2.1 is the experimental branch, and shipping against experimental is the thing ADR 0008
declined to do. It would also stop the mod loading on stable for every player, re-run
`load-check.ps1`'s twelve invariants and every `check-*.ps1` rig against a game version nothing here
has been tested on, reopen [ADR 0003](0003-space-age-tolerated-not-targeted.md)'s targeting of base
2.0, and drop RITEG, which has no 2.1 release at all. The argument for it is real and is recorded
rather than dismissed — a coexistence claim about releases nobody runs is worth less than one about
releases they do — but it buys that at the price of the mod not running either.

**Defer, and check only what 2.0 already reaches.** Krastorio 2, RITEG and Advanced Fluid Handling
have usable 2.0 releases, so #33 completes either way and this costs nothing today. Rejected because
it buys nothing: the wider families would wait on a trigger that has not moved in twelve days, and
the machinery to check them now exists and is cheap to point at them.

**Pin only the maintained families** — Angel's, Bob's and Space Exploration — and defer SeaBlock NG
and MadClown's, whose 2.0 lines are mid-development. Rejected as a rule that needs a judgement per
family and revisiting each time one is added, for a saving that is mostly rig time.

**SeaBlock NG at its enforced minimum** rather than the full pack — **nine** mods: `SeaBlockWanne`
1.0.5, the four Angel's content mods, and their four `~` graphics mods. That is genuinely all the
pinned release requires. Rejected because what strictly loads is not what a SeaBlock player installs,
and the lane is worth more answering the second question. The cost is 46 mods against nine, and an
overlap with two other lanes, both stated above. **This alternative was first written up as a `+`
prefix argument, which was wrong** — see the correction above; nine-versus-46 is the real trade, and
it is a wider gap than the one originally weighed.
