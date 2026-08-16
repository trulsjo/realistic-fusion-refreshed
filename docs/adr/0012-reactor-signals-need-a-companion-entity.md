# 12. A reactor's circuit signals need a companion entity

Date: 2026-08-16

## Status

Accepted. Records a constraint discovered while implementing
[Reactor observability: status text and circuit signals](https://github.com/trulsjo/realistic-fusion-refreshed/issues/25).

Extends [ADR 0010](0010-v1-module-layout-and-prototype-set.md) rather than reversing it: 0010's
interface decision — status text and circuit signals, no GUI — stands unchanged. What changes is the
prototype set, which 0010 calls "a starting specification, not a contract" and asks to be amended by
a superseding ADR rather than drifted from silently. This is that amendment.

## Context

ADR 0010 specifies that the simulation surfaces through "entity status text and tooltips, plus plasma
temperature and Q-factor emitted as **circuit signals**", and ADR 0011 requires those signals to be
per reactor, because "a network has no position, no tooltip and no circuit connection point".

**A reactor cannot carry a wire.** `rf-reactor` is a `boiler`, and it is a boiler for a reason that
is not cosmetic: `mode = "output-to-separate-pipe"` is what gives it plasma in through one pipe and
reactor energy out through another, which is the shape ADR 0011's fluid coupling depends on.
`BoilerPrototype` has **no `circuit_connector` and no `circuit_wire_max_distance`** — checked against
the [2.0.77 prototype documentation](https://lua-api.factorio.com/2.0.77/prototypes/BoilerPrototype.html),
and its inheritance chain (`EntityWithOwnerPrototype` → `EntityWithHealthPrototype` →
`EntityPrototype`) introduces neither. Circuit connectivity in Factorio 2.0 is declared per prototype
type; it is not something runtime code can add.

So the specified prototype set cannot express the specified interface. One of the two has to give.

Three further facts were established by probing rather than from documentation, because the
documentation does not state them:

1. A `LogisticFilter` written to a constant combinator section **requires an explicit `quality`**.
   Without it `set_slot` rejects the filter with *"Can't specify non zero request with non trivial
   item filter condition"* — a `SignalFilter` that leaves quality open is a condition, not a signal.
2. A signal value beyond int32 **throws rather than wrapping**: *"Given min value (3e+09) is too big,
   allowed values are from -2147483648 to 2147483647"*. `rf-d-d-plasma`'s 2e9 °C ceiling clears
   int32 by about 7%, so the range fits — but only just.
3. `LuaEntity.custom_status` **is accepted on a boiler**, so the status half needs no companion.

## Decision

**Signals are carried by a hidden companion entity at the reactor's own position.** `rf-reactor-signals`
is a `constant-combinator`, created on demand when a reactor is first stepped and destroyed with it.
It is unminable, unbuildable, has no recipe and no item, and is out of Factoriopedia.

**It borrows the reactor's selection box**, so the whole reactor is the wire target rather than a
one-tile spot at its centre, and takes `selection_priority = 1` so an ordinary click resolves to the
reactor. One, not zero: the documentation states that "the value `0` will be treated the same as
`nil`", which would leave it at the default 50 and tied with the reactor.

**A wire drag is redirected at runtime, because the engine does not do it.** Dragging a wire is not a
special case to Factorio's selection: it offers whatever is selected, which is the reactor, and the
reactor has no connector — so no wire would attach to a reactor at all. `circuit-output.install()`
watches `on_selected_entity_changed` and `on_player_cursor_stack_changed` and moves `player.selected`
onto the combinator for exactly as long as a vanilla wire is in hand. The alternative, giving the
combinator the higher priority outright, costs more than it buys: the reactor would stop being what a
click, a mine or a deconstruction planner lands on, and its status line would be replaced by a bare
combinator's.

**It does not set `hide-alt-info`.** Alt mode over a constant combinator draws the signals it emits,
so the temperature and Q float over every reactor for free — the readout a player is most likely to
find without being told.

**Two virtual signals join the prototype set**: `rf-signal-plasma-temperature` in whole degrees, and
`rf-signal-q-factor` as a percentage. A percentage rather than a truncated integer because it makes
`Q > 100` the decider condition for "is this reactor net positive", which is the question worth
wiring.

**The addition is three prototypes, not a new player-facing building.** ADR 0011 rejected per-network
simulation partly because it would need "a network controller entity the specified prototype set does
not contain". That objection does not transfer: this entity has no position of its own, no
independent existence, and describes exactly one reactor.

## Consequences

- **Reporting has its own cadence.** Publishing on every simulation step took the per-reactor cost
  from 1.39 µs to 3.51 µs; at one report every five steps it is 1.80 µs. A gauge no one can read at
  10 Hz is work that buys nothing, which is ADR 0005's argument for the simulation cadence applied
  once more. `REPORT_EVERY` in `control.lua` is the single place it lives, and
  `docs/research/reactor-runtime-cost.md` records what it costs.
- **#24's headline figure is superseded**, from 1.39 µs to 1.80 µs per reactor. The method and every
  other conclusion in that note stand.
- **Orphan cleanup is required and is not free.** A reactor removed while this mod is disabled never
  returns through the tick loop, so its combinator would be left on the map — invisible, unminable
  and still on the wire. `circuit-output.rescan()` pairs combinators to reactors by position on
  configuration change and destroys the unmatched. It deliberately does not destroy and rebuild them
  all, which is simpler and would silently disconnect every wire a player had run whenever any mod
  in their save updated.
- **Wires do not survive blueprinting.** The combinator is `not-blueprintable`, so a blueprinted
  reactor arrives with a fresh one and no connections. The alternative — a phantom entity inside
  every blueprint — is worse. Worth revisiting if players hit it.
- **A later tier inherits this.** `rf-aneutronic-reactor` will need the same companion, and if a
  reactor ever stops being a boiler — which [#43](https://github.com/trulsjo/realistic-fusion-refreshed/issues/43)
  and [#44](https://github.com/trulsjo/realistic-fusion-refreshed/issues/44) put in question — this
  ADR should be re-read before the companion is carried across. A `reactor`-type prototype has its
  own circuit behaviour and might not need one.
- **The one claim here that was reasoned rather than measured turned out to be false, and this
  records it rather than quietly editing it away.** The first version of this ADR argued that a wire
  drag only offers entities with a circuit connector, so the companion would win the cursor by
  default and `selection_priority = 1` would settle everything else. Playing it settled it instead:
  no wire would attach to a reactor at all. The measurement exists now — `LuaPlayer.update_selected_entity`
  runs the engine's own selection resolution at a position, so the question the mouse asks can be
  asked from a script after all, in the client, where there is a `LuaPlayer` to ask it of. With a
  wire in hand and no redirect the answer is `rf-reactor`; with the redirect it is
  `rf-reactor-signals`. Headless still cannot do it: the client is what has a player.
- **One handler remains unmeasured**, and only one: picking a wire up while the reactor is already
  under the cursor. A scripted `set_stack` raises no `on_player_cursor_stack_changed`, and Factorio
  refuses to let a script raise that event at all. Everything downstream of the event is the code the
  measured case exercises.

## Alternatives considered

**Give the reactor a circuit connector.** Not possible: `BoilerPrototype` does not accept one, and an
unknown property is a load error rather than something silently ignored.

**Stop the reactor being a boiler.** It would gain circuit connectivity and lose
`output-to-separate-pipe`, which is what carries plasma in and energy out — the mechanism ADR 0011 is
built on. That is a much larger decision than observability, and it is open on its own terms in #43
and #44. Not settled here as a side effect.

**Emit per network from one entity a player places.** Rejected by ADR 0011 already, and rejected
again for the same reason: the values describe a reactor, and an aggregate would misdescribe the
building the player is looking at.

**Status text only, no signals.** Cheapest, and it is what a boiler can do unaided. Rejected because
"build control logic around it" is half of what #25 asks for, and a status line cannot be wired.
