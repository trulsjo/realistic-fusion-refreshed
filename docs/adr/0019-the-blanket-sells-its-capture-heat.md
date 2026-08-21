# 19. The blanket sells its capture heat

Date: 2026-08-21

## Status

Accepted. Decided by Truls, 2026-08-21, in a design session that began from a plain question — in
which forms is energy released by the reactions this mod simulates, and what does the model not
capture.

**Extends [ADR 0010](0010-v1-module-layout-and-prototype-set.md)** rather than amending it:
`rf-lithium-blanket` gains a second product, and one virtual signal joins the two ADR 0010 specified.
Recorded here rather than drifted into, which is what that ADR asks for.

**Nothing in [ADR 0015](0015-the-d-d-tier-is-a-breeder.md) or
[ADR 0018](0018-energy-is-contained-and-no-pipe-carries-it.md) is disturbed** — see
[Consequences](#consequences). [ADR 0020](0020-plant-efficiency-is-researchable.md) was decided in the
same session and is independent of this one.

## Context

The simulation releases energy in exactly **two** forms at the reaction: kinetic energy of charged
products, and kinetic energy of neutrons. None of the five reactions in `reactivities.lua` has a
primary gamma branch, so there is no photon release from the fusion event itself. `charged_fraction`
is the column that separates the tiers — 4.85/7.30 for D-D, 3.52/17.59 for D-T, and 1 for both
aneutronic reactions, which is what makes direct energy conversion possible at all.

Downstream of the reaction, three things the model does not capture were examined. Two are already
settled, and are named here only so nobody reopens them under this ADR's heading:

- **Radiation** — bremsstrahlung and cyclotron. Already decided:
  [#52](https://github.com/trulsjo/realistic-fusion-refreshed/issues/52) carries it as a loss and
  [#53](https://github.com/trulsjo/realistic-fusion-refreshed/issues/53) is the path out, which buys
  **confinement** rather than capture. Bremsstrahlung is a loss of confinement rather than of energy:
  the X-rays land in the first wall, which is the channel `step()` already sells through. Whether the
  term also lands in `captured_j` is #52's decision, not this one's.
- **The ash's share of thermal energy**, leaving with the burnt fuel. `reactor-logic.lua:423-425`
  calls it a real gap in the accounting and a rounding error, and it stays one.

The third is different, and is what this ADR is about.

### The blanket releases nuclear energy and the model throws it away

`reactor-logic.lua:344` already writes the two reactions down:

    n + Li-6  -> T + He4        + 4.78 MeV   exothermic
    n + Li-7  -> T + He4 + n'   - 2.47 MeV   endothermic, and hands the neutron back

`breed()` returns `tritium_units` and `nuclei_used`. It returns no joules. So a machine that already
exists, is already fitted to reactors, and already consumes lithium a player mined, concentrated and
belted, releases real energy that the model discards.

**Approximate sizes, pending the figure the research ticket pins.** Per neutron the ceiling is
4.78 MeV, less whatever share of captures runs on Li-7, and the relative gain is lopsided because it
is measured against each tier's own release:

| Tier | Own release | Neutrons per reaction | Blanket adds | Relative |
|---|---|---|---|---|
| D-T | 17.59 MeV | 1 | ~4.78 MeV | **+27%** |
| D-D | 3.65 MeV | 0.5 | ~2.4 MeV | **+65%** |

Every number in that table is provisional and no balance figure may rest on it. Real blanket
literature quotes an *energy multiplication factor* that already includes the neutron's kinetic
energy, which this mod sells separately — so importing one would double-count. Pinning the net figure
without that error is its own ticket and gates the implementation, the same way
[#51](https://github.com/trulsjo/realistic-fusion-refreshed/issues/51) gated #52.

### Two constraints the shape had to fit

**The blanket cannot grow a face.** `rf-lithium-blanket` is a `container`, and `entities.lua:415-416`
records why: giving it a pipe of its own would need a prototype with both an item inventory and a
fluid box, and 2.0.77 has none. Its tritium already leaves through the reactor's collector for
exactly this reason.

**Breeding is gated on the collector.** `control.lua` calls `blanket_breed` only inside
`if collector then`, capped to the collector's tritium headroom, because running a blanket into
nowhere "would spend real lithium for nothing, which is a trap with no gameplay on the other side of
it" — about 19 items a second on an ignited D-T reactor. A blanket with nowhere to put tritium is
therefore **idle rather than wasteful**, and keeps its lithium.

## Decision

**The blanket's capture heat is sold, as a by-product of breeding, through the reactor's own energy
output.**

1. **`breed()` returns joules alongside tritium**, and they are added to the `rf-reactor-energy` the
   reactor writes to its own output box. The blanket gets no face, no fluid box and no pipe — the
   same answer its tritium already has, for the same prototype reason.

2. **Heat follows breeding, not neutron capture.** The collector gate is inherited exactly as it
   stands: no collector, or no tritium headroom, means no breeding and therefore no heat. This is
   physically fiction — a real blanket's neutrons arrive whether or not anyone wants the tritium, and
   the shell gets hot regardless — and it is chosen anyway, because the alternatives are worse. Heat
   following neutron capture means either spending lithium with no tritium to show for it, reopening
   the trap `control.lua` deliberately closed, or producing heat from no material at all. The odd
   consequence, that a backed-up collector costs a player power, is already how this mod behaves
   everywhere else: a reactor whose heat is not being carried away does not get to bank it.

3. **On any fuel, with no per-tier gate.** A blanket on a D-D reactor breeds today and will heat
   today. No rule is invented to protect the breeder tier, because none is needed — see
   [Consequences](#consequences).

4. **It crosses `capture_efficiency` at the reactor's own 0.85. No new constant.** One of that
   constant's two justifications transfers and one does not: blanket heat goes through the same steam
   stage Factorio's turbines lose nothing in, so the free-loop guard applies in full, while the
   divertor, cryoplant and magnet power it stands in for are plasma-side and have no blanket
   equivalent. A separate, higher blanket constant is therefore arguable on physics and refused on
   risk — `capture_efficiency` is the only term standing between this mod and a free loop, and every
   additional instance of it is another number a later balance pass can drift upward.

5. **Q excludes it.** Q-factor is a plasma statistic — fusion power over heating power — and the
   blanket's heat is released in a shell outside the plasma. Letting it in would make the signal stop
   meaning what `CONTEXT.md` says it means. The cost is accepted: a player sees a Q that understates
   how good the machine is economically, which is the right trade, because Q is not an economic
   number.

6. **A third circuit signal, `rf-signal-blanket-share`**, carrying blanket heat as a percentage of
   **total** sold energy — `blanket / (reactor + blanket)`. Bounded 0-100 by construction, with a
   denominator a player can read off the fluid box, and reading **0** when the reactor is idle, which
   inherits `reactivity.q_factor`'s deliberate choice to return 0 rather than treat a zero denominator
   as undefined. The *uplift* reading (`blanket / reactor`) was rejected: its denominator is displayed
   nowhere, it is unbounded in principle, and it reads highest on the tier where it matters least.
   Uplift stays recoverable as `share / (1 - share)`.

## Consequences

- **ADR 0015 survives, and by arithmetic rather than by a rule.** #52 lands D-D at Q 0.32; +65% on the
  sold side is about 0.53. Still below break-even, still a machine a player runs at a loss, still a
  **breeder tier** in the glossary's sense. No per-fuel gate was needed to protect it.
- **ADR 0018 is untouched.** An aneutronic reactor releases no neutrons, so a blanket on one breeds
  nothing "by arithmetic rather than by a missing field" — blanket heat can therefore only ever be
  `rf-reactor-energy`, never the aneutronic fluid, and the two-category split is unaffected.
- **The blanket becomes a power upgrade as well as a fuel one**, which is what a real blanket is, and
  changes what `rf-blanket-breeding` is worth researching for.
- **Vocabulary moves**, and `CONTEXT.md` carries it: **blanket breeding** widens to name heat as its
  second product, **Q-factor** gains that blanket heat is excluded, and **blanket share** joins as a
  new term.
- **A third signal is one more than ADR 0010 specified.** That ADR chose two signals over a GUI
  because GUI was 929 of the redesign's ~1,736 runtime lines. A third signal on the existing companion
  entity does not reopen that choice, but it is a departure from the stated set and is recorded as one.
- **A new virtual-signal icon is needed.** Only `q-factor.png` exists. Lifting one from upstream
  Krastorio 2 into `graphics/krastorio-2/virtual-signals/` is the established licensed pattern
  (LGPLv3, licence file and legal note alongside), so this is routine rather than a new question under
  [ADR 0001](0001-liftable-predecessor-material.md).
- **An existing guard would have eaten the heat silently.** `control.lua` skips the energy write
  entirely when the reactor's own output is below `MIN_FLUID`, so a barely-fusing reactor's blanket
  heat would vanish. Summing before the threshold test fixes it, which is why the prefactor comes
  first.
- **The write order has to change.** The energy box is written before `blanket_breed` runs, so the
  blanket's joules cannot reach the box a player drinks from without reordering. That is a prefactor
  with no behaviour change, landed on its own.
- **The rig already exists.** `check-blanket.ps1` builds a `fitted` and a `bare` reactor and already
  asserts one "goes on producing reactor energy" by reading `fluidbox[2].amount` directly. It needs no
  exchanger and no pipe on the energy leg, so this work is insulated from #86 and #87.
- **#52 will move the D-D figures this ADR quotes.** The comparative assertion — fitted beats bare —
  survives it. The absolute D-D numbers above do not, and are anchored to the pre-#52 equilibrium.

## Alternatives considered

**A face of the blanket's own, bolted like an exchanger.** Impossible rather than rejected: a
container has no fluid box, and 2.0.77 has no prototype that is both an inventory and a fluid box.
Changing the blanket's prototype type would break every existing save's blankets for a plumbing
nicety.

**Heat follows neutron capture, not breeding.** Physically right, and it forces a worse choice between
reopening the lithium trap and making heat from no material. Rejected in the Decision above.

**A separate, higher `capture_efficiency` for the blanket.** Defensible physics — a shell's heat is
easier to recover than plasma exhaust, which is the same argument that earned the aneutronic tier 0.95
— and refused because the tenth it would buy is smaller than the risk of a second free-loop guard to
maintain.

**Blanket heat inside Q.** Would make Q an economic number instead of a plasma one, and the glossary
already fixes it as a plasma one.

**No signal at all**, leaving the gain to arrive as more steam. Rejected: an invisible +27% is a
mechanic a player cannot discover without reading a changelog, and "the blanket is also a power
upgrade" is the whole point of doing this.

**The status line instead of a signal.** Cheaper — no prototype, no icon, no slot — and it would give
the status line its first number, on a surface
[#46](https://github.com/trulsjo/realistic-fusion-refreshed/issues/46) already has open for showing
numbers that are artefacts of being a boiler. Wrong order of work.

**Gating blanket heat to D-T only**, to protect the breeder tier by construction. Rejected: the
arithmetic protects it already, and the gate would be a rule physics does not have.
