# 3. Space Age is tolerated, not targeted

Date: 2026-08-13

## Status

Accepted. Resolves
[Space Age: supported or base 2.0 only?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/4).

## Context

Space Age occupies this mod's exact subject. Per <https://wiki.factorio.com/Fusion_reactor>, the
expansion ships a fusion reactor craftable only on Aquilo, consuming fusion power cells and
fluoroketone coolant to produce plasma — 10 MW in, 100 MW out. A mod whose premise is "fusion power
modelled on real physics" therefore lands on top of a vanilla implementation of the same idea.

Three things bear on the choice:

1. **The original was abandoned for precisely this reason.** Romner's
   [deprecation notice](https://mods.factorio.com/mod/RealisticFusionPower/discussion/671ba901fcb6c30f0f6b2762)
   (2024-10-25): *"with Space Age now out with vanilla fusion reactors, RFP would need to be completely
   rewritten from the ground up (again) […] I'm officially ending all development and maintenance of
   RFP/W — including the WIP 2.0 version."* The author's own judgment was that reconciling with Space
   Age is rewrite-scale work, not a compatibility patch.
2. **Quality is a known, unfixed problem.** Durikkan's port warns that *"certain buildings in this mod
   get insanely overpowered with quality"*, naming none of them. Quality ships with Space Age; base 2.0
   has none.
3. **Behaviour under Space Age is unverified for all three predecessors.** Nothing in the survey
   observed any of them running under the expansion.

## Decision

**v1 targets the Factorio 2.0 base game.**

**Space Age is tolerated, not integrated.** The commitment is that the mod loads and runs alongside
Space Age without crashing. There is no claim of balance against it, no reconciliation with the vanilla
fusion reactor, and no Aquilo or fluoroketone integration.

**The quality interaction is a named known-gap, not a silent one.** Whatever the mod ships must say
plainly that its buildings are not balanced for quality, rather than leaving players to discover it as
Durikkan's users did.

## Consequences

- v1 stays achievable. Reconciling with vanilla fusion — replace it, complement it, or gate one behind
  the other — is a design commitment the original's author judged to be rewrite-scale, and it is not
  taken on here.
- Most 2.0 players now own Space Age, so "tolerated" is doing real work: it is the difference between a
  mod that is merely untested with the expansion and one that breaks in it. Loading safely alongside
  Space Age is a v1 obligation.
- "Loads without crashing under Space Age" is a claim that has to be verified before v1 ships, not
  assumed. No predecessor's behaviour under the expansion was ever observed.
- First-class Space Age support remains open as a later effort. This ADR declines it for v1; it does not
  rule it out for the project.
- The minimum supported 2.0.x and the version documentation pins against are no longer blocked by this
  question and graduate to their own ticket.

## Alternatives considered

**Space Age as a first-class target.** Reconcile with vanilla fusion, handle quality, handle Aquilo.
Rejected for v1 on scale: the one person who has actually written this mod concluded it needed a ground-up
rewrite, and v1 has no working code yet to rewrite from.

**Base 2.0 only, Space Age unsupported, no claim either way.** The smallest surface and honest if the
expansion is never tested. Rejected: it narrows the audience sharply for a saving that is mostly the
cost of one compatibility pass, and "no claim" in practice means players find breakage themselves.
