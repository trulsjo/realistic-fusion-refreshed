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
  | **30 s** (shipped) | 2.69×10⁸ K | **0.39** | 19 MW |
  | 42 s | 4.95×10⁸ K | **1.02** | 51 MW |
  | 50 s | 1.03×10⁹ K | 2.58 | 129 MW |
  | 55 s | 1.82×10⁹ K | 4.63 | 231 MW |

  A ladder from 30 s to about 50 s crosses break-even at 42 s and is smooth and monotonic. The
  harness reproduces the shipped radiation-free equilibrium exactly (8.769×10⁸ K, Q 2.139), so it is
  the same model with one term added.

- **It is a cliff, not a slope, and a ladder has to stop short of it.** Past about 55 s the D-D
  plasma ignites and runs to `max_temperature_c`, which would hand the D-D tier the pinned
  temperature reading the D-T tier already has
  ([`d-t-ignition.md`](../research/d-t-ignition.md)). That bounds how many rungs there can be, and
  it is a design constraint rather than a tuning detail.

- **Two implementations of the same term disagree by about 20% and must be reconciled first.** The
  sweep above gives Q 0.386 at the shipped 30 s where `bremsstrahlung.md` gives Q 0.32, and
  2.69×10⁸ K against 2.42×10⁸ K. Both say "well under break-even", so nothing here turns on it — but
  no balance number may be derived from either until they agree.

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
