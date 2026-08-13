# 6. Clean break from predecessor saves

Date: 2026-08-14

## Status

Accepted. Resolves
[Save migration or clean break?](https://github.com/trulsjo/realistic-fusion-refreshed/issues/7).

## Context

The predecessors kept a continuous naming lineage. The 1.1 original and Durikkan's port use identical
internal prototype names — `rfp-reactor`, `rfp-hc-turbine`, `rfp-heater` and so on — which is why the
port needed no migration files at all, while the original shipped seven across its life
(`rfp-1.0.0.json` through `rfp-1.8.0.lua`). The archived redesign broke that lineage itself, renaming
everything to `rf-*` (`rf-m-reactor`, `rf-ion-cyclotron`).

Three constraints limit what carrying a save over could actually mean here:

1. **The mod name cannot transfer.** Factorio saves bind to a mod's internal name, not merely to
   prototype names. `RealisticFusionPowerPort` belongs to an actively maintained mod (1.9.2, December
   2025); adopting that name is neither available nor right. When a save's mod is absent, its entities
   are removed regardless of what a different mod happens to call its own prototypes.
2. **The 1.1 original's saves cannot come forward at all.** A 1.1 save must pass through the game's own
   1.1 → 2.0 migration first, and the original does not support 2.0. Only port users were ever realistic
   candidates.
3. **Behaviour now differs fundamentally.** Under [ADR 0005](0005-real-time-fusion-simulation.md)
   reactors carry simulation state in `storage`. A migrated `rfp-reactor` would arrive with no plasma
   temperature and no confinement state — values that would have to be invented on arrival rather than
   carried.

## Decision

**v1 makes a clean break. Predecessor saves are not supported**, and this is stated plainly wherever
players will look rather than left to be discovered.

**Prototype names must not collide with the `rfp-` prefix.** This is the one hard technical requirement
the break creates: if a player has both this mod and Durikkan's port installed, two prototypes of the
same name is a load error, not a graceful degradation. A distinct prefix keeps the two installable side
by side, which is the courteous outcome for a player evaluating both.

**Naming is otherwise unconstrained**, which is new freedom for
[Choose the published mod name](https://github.com/trulsjo/realistic-fusion-refreshed/issues/8) — no
scheme is inherited.

## Consequences

- **Port users rebuild their fusion setup.** That cost is real and falls on a small, identifiable group.
  It is accepted because the alternatives could not deliver what their name promises: the mod-name
  binding defeats a true carry-over, and the simulation state would be fabricated even where entities
  survived.
- **The break must be advertised, not buried.** Save incompatibility is the failure mode that breaks
  silently and is discovered by players rather than by a build. A mod page and description that say so
  are part of shipping v1.
- **From v1 onward, save compatibility becomes ours to protect.** This ADR discards continuity with
  *predecessors*; it says nothing about breaking our own players later. `CLAUDE.md`'s rule stands —
  anything breaking an existing save takes `!` before the colon and a `BREAKING CHANGE:` footer
  explaining the migration.
- **Migration tooling is not ruled out forever.** Should demand appear, a later effort could ship
  migration scripts converting `rfp-*` entities where both mods are installed. Deciding against it for
  v1 does not foreclose it, and the distinct-prefix requirement above happens to keep that door open.

## Alternatives considered

**Ship a migration path.** Migration scripts converting the port's entities when both mods are
installed, synthesising initial simulation state. Rejected for v1: it constrains naming, adds a testing
burden against a moving third-party mod, and depends on that mod remaining available — for a continuity
that would still be partial, since the fabricated simulation state means the reactors would not behave
as they did before.

**Adopt the `rfp-*` prototype names outright.** Maximises the chance entities survive a swap. Rejected:
it inherits someone else's naming scheme permanently, still cannot deliver a true carry-over because the
mod name will not transfer, and it guarantees a collision for anyone with the port installed — turning a
"compatibility" measure into a load error.
