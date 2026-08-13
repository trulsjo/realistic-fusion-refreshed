# 2. v1 scope and the module split

Date: 2026-08-13

## Status

Accepted. Resolves
[Does the four-module split survive?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/3).

## Context

The archived redesign splits the mod four ways — Core, Power, Weaponry, Antimatter. The 1.1 original
did not: it shipped as a single mod with the antimatter chain inside it, gated behind an
`rf-antimatter` "[WIP]" setting. So the split is the redesign's proposal, not the proven arrangement.

What the survey (`docs/research/predecessor-survey.md`) established about the four:

| Module | Lua | State |
|---|---:|---|
| Core | 3,288 | substantive — the fuel chain |
| Power | 5,388 | substantive — reactors and a real-time fusion simulation |
| Antimatter | 1,242 | substantive but will not load: 7 referenced icons do not exist |
| Weaponry | 0 | `info.json` and nothing else |

Dependencies are real rather than decorative: Power, Weaponry and Antimatter all hard-depend on Core;
Antimatter optionally depends on Power. Core is a genuine library in that arrangement.

Two facts shaped the scope half of this decision:

1. **Weaponry has nothing to inherit.** The redesign's module is an empty stub. A separately published
   [Realistic Fusion Weaponry](https://mods.factorio.com/mod/RealisticFusionWeaponry) 1.x mod exists,
   but it falls outside the three predecessors and **was not surveyed**. Including Weaponry would mean
   porting an unsurveyed mod or writing new content.
2. **Antimatter carries an art-provenance problem on top of a code problem.** Beyond the 7 missing
   icons, its models are exactly the PreLeyZero donated art that `CLAUDE.md` says must not be assumed
   free — Romner credits them for "all the antimatter-related and 2.0 models". Shipping it needs that
   question answered first.

## Decision

**v1 is fusion power only** — the fuel chain and the power-generation content. Antimatter and Weaponry
are deferred to a later effort; they are not cancelled, but they are not specified here and nothing in
v1 waits on them.

**The four-module split survives in reduced form: two published mods, Core and Power.** Core remains a
separate published dependency rather than being folded into Power, so that Antimatter, Weaponry or
anything else can attach later without restructuring or a save migration.

**Core is not committed as a stable public API.** It is published because this project's own future
modules will depend on it, not as an interface third parties are invited to build against. That option
was considered and declined: the commitment would constrain the interface before there is any consumer
to shape it.

## Consequences

- Splitting later is avoided rather than deferred. Moving prototypes between mods once players hold
  saves breaks quietly, and `__ModName__` asset paths are baked into every sprite reference — paying
  the two-mod cost now avoids paying that later.
- The cost is real and accepted: two portal entries, two `info.json`, and version lockstep between them
  for what is currently a single consumer.
- [Choose the published mod name](https://github.com/trulsjo/realistic-fusion-refreshed/issues/8) now
  covers **two** names plus the internal names both mods bind to, not one.
- [Specify the v1 module layout and prototype set](https://github.com/trulsjo/realistic-fusion-refreshed/issues/9)
  narrows to two mods' worth of layout.
- Whether the redesign's real-time fusion simulation survives into Power is untouched here and remains
  open on the map — it hangs on the upstream base decision.

## Alternatives considered

**One mod, Core as an internal directory.** With Antimatter and Weaponry deferred, Core has exactly one
consumer, so a separate published library is an abstraction with a single caller. Rejected on migration
cost: the later split is the expensive direction, and the internal-boundary discipline that would keep
it cheap is easy to erode in practice.

**All four modules in v1.** Rejected — Weaponry has no inheritable content and Antimatter cannot load
and cannot ship until the PreLeyZero art question is answered.

**Core as a public API for third-party mods.** Rejected as premature; see above.
