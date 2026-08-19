# 14. "Realistic" means theoretically possible, and a tier may start below break-even

Date: 2026-08-18

## Status

Accepted. Fixes the meaning of the word the mod is named for, and settles the framing half of
[#37](https://github.com/trulsjo/realistic-fusion-refreshed/issues/37) — *is the shipped reactor's
behaviour the intended one?* It does not settle the numbers; see Consequences.

Extends [ADR 0005](0005-real-time-fusion-simulation.md), which decided that reactors compute their
rate from cross-section data rather than implying it through recipe ratios. That ADR settled *how*
the physics is arrived at. This one settles *which* physics is being aimed at, which turns out to be
a separate question and one that had been left implicit.

Decided by Truls. Recorded here because it is a decision, not a consequence of one.

## Context

The D-D tier ships at Q 2.14 — 133 MW of thermal output against 50 MW of confinement heating — so a
player's first reactor pays for itself. That reading was never chosen. It is what falls out of the
cross-section data at the shipped density and confinement time when the model carries no radiation
loss at all.

[`bremsstrahlung.md`](../research/bremsstrahlung.md) checked the dominant omission against the NRL
Plasma Formulary and found that counting it takes D-D from Q 2.14 to well under break-even. The
physics is not in dispute: a D-D plasma at 10²⁰ m⁻³ with 30 s of confinement is genuinely nowhere
near ignition, and every real machine ever built has been net negative. The shipped tier looks
positive because a real loss term is missing.

That was recorded as a two-sided choice on #37 — keep the model radiation-free and knowingly
incomplete, or add the term and move density, heating or confinement to keep D-D working. **Both
sides shared an assumption nobody had examined: that a D-D reactor must be net positive the moment a
player builds one.** The predecessor does not assume it.

### What the 1.1 original actually ships

Verified 2026-08-18 against Realistic Fusion Power 1.8.18 in `C:\src\factorio\_reference\`.
`rfp-heater` declares `energy_usage = "400MW"`, and every efficiency technology states the value it
is moving *to*, so each tier's base figure is recoverable from its first upgrade:

| Tier | Fusion out | Heating in | Q at base | Q fully upgraded |
|---|---|---|---|---|
| D-D, T+He3 suppressed (`rfp-d-d-fusion-0`) | 100 MW | 400 MW | **0.25** | 1.0 |
| D-D, tritium suppressed (`rfp-d-d-fusion-1`) | 200 MW | 400 MW | **0.50** | 1.5 |
| D-D (`rfp-d-d-fusion-2`) | 400 MW | 400 MW | **1.00** | 3.0 |
| D-T | 1400 MW | 200 MW | 7.0 | 20 |
| D-He3 | 10 GW | 5 GW | 2.0 | — |
| He3-He3 | 7 GW | 7 GW | **1.00** | — |

Three things follow, and the third is the one that matters:

- **D-D and He3-He3 start at exactly 1.00.** Break-even is not a number anyone lands on by accident.
  It was chosen as the *starting* point of a tier, with `fusion-efficiency` and `heating-efficiency`
  as the road out of it: heating falls 400 → 200 MW over four steps, output rises 400 → 600 MW over
  nine.
- **The suppressed D-D variants are net negative on purpose, and are gated behind breeding
  research.** `rfp-d-d-fusion` unlocks the plain variant at Q 1.00; `rfp-tritium-breeding` unlocks
  the Q 0.50 one and `rfp-helium-3-breeding` the Q 0.25 one. So a player deliberately *downgrades*
  their reactor's power balance to get tritium and helium-3 out of it. Burning electricity to breed
  fuel is a designed mechanic there, not a balance failure.
- **So "not self-sustaining without research" is the predecessor's position**, in its numbers and in
  its author's words alike.

### And Romner says so in his own words

From his mod spotlight in **Alt-F4 #4, 2020-09-11**
(<https://alt-f4.blog/ALTF4-4/#mod-spotlight-realistic-fusion-power-romner>), read from a local copy
Truls fetched — the site returns 403 to automated fetching:

> "Fusion isn't easy to achieve of course, because otherwise us humans would be using it as our
> primary power source. […] **At first, fusion will be very impractical and use more energy than it
> produces**, but at the end you'll feel like you have unlimited energy."

> "The first fusion reaction you can unlock is D-D (Deuterium-Deuterium) with production science,
> **which can not even sustain itself. After a few efficiency upgrades it becomes possible to use as
> a power source**, but still pretty impractical compared to fission (150 MW/power plant at most)."

> "**He3-He3 cannot sustain itself at first**, but can produce up to 3.5 GW with efficiency
> upgrades."

Two things to hold on to when reading that against the table above.

**The article is an older balance.** It is dated six days after the 1.2.0 release and quotes
"150 MW/power plant at most" for fully-upgraded D-D, where 1.8.18 gives 600 MW per reactor. The
absolute numbers moved; the design principle is stated identically in both.

**"Cannot sustain itself" and "Q 1.00" agree, and the gap between them is the point.** The reactor's
own balance is exactly break-even, and a D-D *power plant* is net negative because the fuel chain
around it — Girdler sulfide, electrolysis, pumps — is not free. That is the same accounting #37's
item 4 already makes for this repository, where about 56 MW of chain draw stands against 50 MW of
reactor heating. A tier can be at break-even at the reactor and still cost a player power overall,
and that is a legitimate place for a tier to start.

## Decision

**"Realistic" means the fusion chains are real and the numbers are anchored in what is theoretically
possible — not in what can be built today.** Reactions, branching ratios, energy releases and
cross-sections are physics and are not negotiable. Confinement time, density, purity and capture
efficiency are engineering, and this mod is free to place them anywhere the physics permits,
including well beyond the present state of the art.

**A tier may start below break-even.** Q < 1 on a newly unlocked reactor is a legitimate design
state and not a bug to be tuned away. It is what every real machine has done, and the predecessor
shipped three reactors that way on purpose.

**The route from below break-even to above it is research that moves a physical parameter** —
confinement time, density, plasma purity — never a flat addition to output. ADR 0005 makes the rate
computed rather than chosen, so `+30 MW` has nowhere to live in this model and would be exactly the
implied physics that ADR exists to prevent. Raising nτT is also what fusion research actually is,
which makes the honest implementation and the flavourful one the same implementation.

**Running a reactor at a loss to breed fuel is legitimate**, and is a mechanic available to this
project rather than a state to be avoided.

## Consequences

- **This does not add the bremsstrahlung term and does not retune anything.** It removes the
  objection that adding it would "break the tier that works", because a D-D tier below break-even is
  no longer broken. What to actually ship stays open on #37.
- **It gives `rf-d-d-fusion` somewhere to go.** The technology tree currently has eight technologies
  and no upgrades at all; a confinement-time ladder would be the first, and it is now the sanctioned
  shape for one.
- **The numbers, if that route is taken.** Driving the shipped model with the formulary's
  bremsstrahlung term against a confinement sweep, at the shipped 50 MW heating:

  | τ_E | Settles at | Q | Fusion power |
  |---|---|---|---|
  | **30 s** (shipped) | 2.42×10⁸ K | **0.32** | 16 MW |
  | 42 s | 3.65×10⁸ K | 0.64 | 32 MW |
  | 50 s | 4.73×10⁸ K | 0.95 | 48 MW |
  | 52 s | 5.04×10⁸ K | **1.04** | 52 MW |
  | 55 s | 5.55×10⁸ K | 1.19 | 60 MW |
  | 70 s | 8.56×10⁸ K | 2.08 | 104 MW |

  A ladder from 30 s to about 70 s crosses break-even between 50 s and 55 s and is smooth and
  monotonic. The harness reproduces the shipped radiation-free equilibrium exactly (8.769×10⁸ K,
  Q 2.139), so it is the same model with one term added.

  > **This is a *full-supply* table, and that qualification was missing (2026-08-19,
  > [ADR 0016](0016-plasma-density-is-a-player-lever.md)).** Every row assumes the reactor's fluid
  > segment is held full. It is not the density that makes the most power at the lower rungs, so
  > **which rung crosses break-even depends on how the player runs the reactor**: at τ 50 s a segment
  > held near 85% reaches Q 1.085 where a full one reaches 0.950. A player who tunes density crosses
  > a rung earlier than this table reads. The numbers are not wrong — they are the answer to "at full
  > supply", which is not the only way the reactor gets run.

  > **Corrected 2026-08-18 (#51).** This table originally read ~~30 s → 2.69×10⁸ K, Q 0.39; 42 s →
  > 4.95×10⁸ K, Q 1.02; 50 s → 1.03×10⁹ K, Q 2.58; 55 s → 1.82×10⁹ K, Q 4.63~~ — the
  > **non-relativistic** bremsstrahlung formula, without the relativistic correction that
  > [`bremsstrahlung.md`](../research/bremsstrahlung.md) establishes is worth 1.1× to 5× over this
  > model's temperature range. **The error is not a fixed percentage and the struck numbers must
  > not be scaled by one.** It is 11% at 30 s and 118% at 50 s, where the struck ladder reads
  > 1.03×10⁹ K against 4.73×10⁸ — because the missing radiation grows only as √T while D-D's
  > reactivity climbs steeply across this range, so each extra second of confinement buys the
  > uncorrected ladder more than it buys the real one. Both ladders are now asserted in
  > `tests/test-bremsstrahlung.lua`, which is what this ADR should have been able to cite in the
  > first place.

- **It is a slope, not a cliff — and that is the correction that changes what a ladder may do.**
  This ADR originally recorded that ~~past about 55 s the D-D plasma ignites and runs to
  `max_temperature_c`~~, bounding how many rungs there could be. That runaway is an artefact of the
  missing correction: it is real in the struck ladder above, which jumps 1.82×10⁹ → 2.66×10⁹ K
  between 55 s and 60 s, and absent from the corrected one. With the correction counted, radiation
  outgrows D-D's reactivity past its upper ignition crossing, so the balance always closes and the
  plasma does not reach the clamp until somewhere past 100 s.

  What survives is the *consequence* rather than the mechanism: a D-D reactor taken far enough up
  the ladder still ends against `max_temperature_c` and still inherits the pinned temperature
  reading the D-T tier has ([`d-t-ignition.md`](../research/d-t-ignition.md)). It arrives there by
  walking rather than by jumping, which is a far more forgiving thing to design a ladder against.

- ~~**Two implementations of the same term disagree by about 20% and must be reconciled first.**~~
  **Resolved 2026-08-18 (#51).** They were not two implementations of one term but one
  implementation of two published formulas — the later sweep dropped the relativistic correction.
  The relativistic figures are the ones to use, they are the ones `bremsstrahlung.md` carries
  throughout, and `tests/test-bremsstrahlung.lua` now pins both to 1% so the question cannot be
  reopened by memory. Balance numbers may be derived from the corrected table above.

- **Nothing about D-T changes.** It passes Lawson by more than an order of magnitude at this
  density and confinement time and stays ignited with the radiation term counted; the term moves its
  equilibrium to 3.26×10⁹ K, still above the int32 ceiling that the clamp actually rests on.

- **This is a lens for future tiers, not only a verdict on D-D.** D-He3 and He3-He3 (#31) are far
  harder reactions than D-T, and this ADR says in advance that they are allowed to arrive
  net negative and be researched into viability, rather than being quietly given whatever
  confinement time makes them pay on the first build.

## Alternatives considered

**Leave "realistic" undefined.** It had been, and the cost was concrete: the D-D tier's headline
figure was an artefact of an omission that nobody had decided to make, and #37's framing inherited
an assumption from nowhere. A word in the mod's own name earns a definition.

**Realistic means buildable with today's technology.** Rejected, and it would end the project: no
reactor on Earth has reached Q 1 in a sustained burn, so the mod would have no net-positive tier at
all and no progression. It also contradicts ADR 0010's chain, which ends at He3-He3 — a reaction
nobody has run for power and nobody expects to this century.

**Keep D-D net positive and add the radiation term anyway**, by shortening nothing and simply giving
the reactor better confinement from the start. Available and not chosen: it spends the whole of the
research ladder's range before a player has researched anything, and it makes the first reactor the
best one physics allows, which is the opposite of a progression.
