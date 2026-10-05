# 39. Over-supply is a density limit, behind an option that is off by default

Date: 2026-10-05

## Status

Accepted. Settles [#421](https://github.com/trulsjo/realistic-fusion-refreshed/issues/421), whether
over-supplying a reactor should do anything. **Decided by Truls, 2026-10-05**, in a grilling
session during triage that put each branch to him one round at a time. Nothing below has been built
or measured yet. Every number in it is provisional.

**Extends [ADR 0016](0016-plasma-density-is-a-player-lever.md)**, which made the *under*-supplied
side of the density axis a player lever. This decides the over-supplied side. **Constrained by
[ADR 0005](0005-real-time-fusion-simulation.md)**: whatever over-supply does has to live in the
model, not be added on as a flat bonus.

## Context

A reactor's density is how full its box is, and the box is also the most fuel the reactor can take.
So "full" is both the densest the model knows and the point where a reactor stops accepting fuel.
A second heater past that point is wasted throughput. Truls, 2026-09-19: *"There might still be
case for connecting more than one heater if oversupplying the reactor does something interesting."*

## Decision

1. **By default, over-supply does nothing.** A full reactor stops taking fuel, as it always has.
   With the option off, nothing this ADR describes exists.
2. **A startup mod option adds a density limit, after the Greenwald limit.** It is the mod's first
   setting. It is a startup setting because of point 3, which changes a prototype.
3. **The limit sits where "full" sits with the option off, and the box grows past it**, to 1.25 ×
   that fill, kept as a named constant beside the box volume in `M.reactor` and its aneutronic
   counterpart. So every figure quoted at or below full reads the same with the option on or off,
   and `CONTEXT.md`'s operating points, the supply ratio and every pinned figure stay true.
4. **Above the limit, fusion keeps following the model, and so does a hazard.** The n² term goes on
   raising fusion power past the limit, and on every step the reactor risks a **disruption**. The
   chance per second rises **quadratically** with the excess over the limit, as a fraction of the
   limit, scaled so that a disruption comes after **about 60 s on average at the top of the box**
   (25% over) and after about 25 minutes at 5% over. Both are named constants. The randomness is
   Factorio's deterministic generator, and the pure-Lua tests seed it.
5. **A disruption costs the plasma and nothing else.** The box empties and the reactor has to be
   filled and heated again from cold. Damage to the reactor is
   [#581](https://github.com/trulsjo/realistic-fusion-refreshed/issues/581), labelled
   `later-version`.
6. **The player can see it coming.** `circuit-output.status` gains `unstable`, past `rich`, shown
   whenever the hazard is above zero. A disruption raises an alert. Both exist only with the option
   on.
7. **It applies to both reactors**, `rf-reactor` and `rf-aneutronic-reactor`, each with its limit
   at its own full fill.

## Considered options

- **Cold-fuel quench**: take all the fuel offered and pay `M.settle_fed`'s cost of heating it.
  Rejected because it only punishes a mistake and gives no reason to build the second heater.
- **Fuelling as a control**: a faster refill after a dip. Rejected because it pays only in
  transients, which a player rarely sees.
- **A limit below today's full box**: rejected because it would make the settled reference figures
  unreachable with the option on, so half of `CONTEXT.md` would read differently depending on a
  setting.
- **A hard limit**, or a hard limit with a grace period: rejected because over-supply would then be
  a mistake to avoid rather than a choice. The hazard rate is what makes running past the limit a
  gamble.

## Consequences

- **Turning the option off on a save trims plasma above the old full mark**, because the box
  shrinks back. That is accepted, and the setting's description says so; there is no migration.
- **On a reactor whose optimum lies below full, crossing the limit is always a loss.** A full D-D
  reactor already reads `rich` (ADR 0016), so overfilling it lowers output as well as risking a
  disruption. The gamble pays only where more density still means more power.
- With [#420](https://github.com/trulsjo/realistic-fusion-refreshed/issues/420)'s high-capacity
  heater, one machine can over-supply a reactor on its own, and with speed modules it can do so by a
  wide margin. #420 leaves that alone; with the option on, the hazard is what limits it.
