# 31. Energy bolts along a long face, and each tier chains on its own axis

Date: 2026-09-07

## Status

Accepted. Decided by Truls, 2026-09-07, in a design session worked against
[#84](https://github.com/trulsjo/realistic-fusion-refreshed/issues/84).

**Amends [ADR 0018](0018-energy-is-contained-and-no-pipe-carries-it.md)'s Decision item 4**, which
has been unimplementable since 2026-08-24 and says so in its own block quote. Its coordinates were
3×2 tile centres; this ADR replaces them with the shipped machine's. Nothing else in ADR 0018 moves
— items 1, 2, 3, 5 and 6 stand exactly as written, and item 2's *"No pipe entity carries either, and
none is added"* is what this ADR exists to make buildable.

**Amends [ADR 0022](0022-footprints-follow-the-original-mod.md)'s footprint table** for two machines:
`rf-hc-exchanger` goes from 7×7 to 15×5, and `rf-heat-exchanger` and
`rf-direct-energy-converter` keep their five-by-fifteen area with the long axis declared east–west
rather than north–south. ADR 0022's rule — *the footprint is chosen first, from the original mod, and
the art is redrawn to fit* — is applied here rather than changed.

Closes the gap [#111](https://github.com/trulsjo/realistic-fusion-refreshed/issues/111) surfaced and
was careful not to settle. Implemented by
[#275](https://github.com/trulsjo/realistic-fusion-refreshed/issues/275),
[#276](https://github.com/trulsjo/realistic-fusion-refreshed/issues/276) and
[#87](https://github.com/trulsjo/realistic-fusion-refreshed/issues/87).

**Items 1, 2, 4 and 5 are in the tree as of 2026-09-07.** #275 turned `rf-heat-exchanger` and gave
`rf-reactor` its south output; #87 gave `rf-aneutronic-reactor` the same output and turned
`rf-direct-energy-converter` fifteen wide by five tall with energy on both long faces. Item 3 —
`rf-hc-exchanger` at the same size — is #276's and is the only part still outstanding; the
measurement below means containment did not wait for it. Item 6 stands deferred.

## Context

### ADR 0018 decided a geometry for a machine that no longer exists

Item 4 gives `rf-heat-exchanger`'s energy box three `input-output` connections at south `{0, 0.5}`,
west `{-1, -0.5}` and east `{1, -0.5}`, and argues that three is *forced* because four of a 3×2's six
tiles are already taken. Every number there is a 3×2 tile centre.
[#45](https://github.com/trulsjo/realistic-fusion-refreshed/issues/45) and ADR 0022 made the machine
**5×15** on 2026-08-24, so the tile centres became x ∈ {−2…2} and y ∈ {−7…7} and the argument stopped
describing anything.

### The shipped machines cannot bolt at all, and the reason is geometry rather than flow

`rf-heat-exchanger` declares **one** energy connection: `flow_direction = "input"`, **west long
face** `{-2, 0}`. `rf-reactor` sells energy from **one** connection: `output`, **north** `{0, -7}`.
A west-facing connection and a north-facing one cannot meet, whatever either declares. So the
neutronic tier has shipped for two weeks in a state where ADR 0018's item 2 could not be applied:
categorise both ends and reactor energy has no route to an exchanger at all.

`probe-energy-containment.ps1` worked around it by declaring a rig-only variant with a south
connection, and `CONTEXT.md` records that its bolt row *"is a claim about a shape that would chain,
not about the one in the tree."*

### What was measured before deciding, and what each measurement cost the alternatives

**#111, 2026-09-06 — exchangers chain, under two conditions.** Fuel has to *arrive* through a
connection, and **every** connection on that energy box has to be `input-output`: one declared plain
`"input"` stops fuel leaving by the others. See
[`exchanger-chaining.md`](../research/exchanger-chaining.md). That closed
[#258](https://github.com/trulsjo/realistic-fusion-refreshed/issues/258), which asked for a contained
pipe family on the premise that bolting could not reach eight machines.

**2026-09-07 — a row of eight chains, and water serves it from two ends.** Every earlier measurement
in both probes used **two** machines. Eight is what a lit D-T reactor needs — about 322 MW against
40 MW each — and its rate was recorded as unknown in ADR 0018's Consequences and in the research
note. All eight reach `working` with full boxes, fed energy through **one** connection on the first
machine.

Water is the constraint chaining *creates*, and it existed in no earlier measurement: once machines
bolt short end to short end, every interior water connection is consumed by a joint, so a row is
reachable at its two ends and nowhere else. Off `rf-hc-turbine`'s own declared figure, eight
machines want about **3,300 units of water a second** through those two connections. They get it.
The rig counts the pipes it left — two water, one energy, eight steam — rather than arguing that its
skipping logic worked.

**2026-09-07 — a plain `"input"` connection still accepts a bolt.** `rf-hc-exchanger`, categorised
and otherwise untouched, bolts to a reactor's output and draws its full 400 MW. So **`flow_direction`
governs forwarding, not joining**: an `"input"` connection joins and accepts, and what it will not do
is pass fuel on to a third machine. That one sentence is why the high-capacity machine needs no
geometry change to be contained, which took an unwritten Blender model off
[#86](https://github.com/trulsjo/realistic-fusion-refreshed/issues/86)'s critical path.

### The reactor's faces were nearly full, and that shaped the answer

| face | carries | why it is not available |
|---|---|---|
| west `{-7, 0}` | plasma, `input-output` | ADR 0011 — one run of `rf-pipe` feeds a row of reactors from one shared pool, and it uses both faces |
| east `{7, 0}` | plasma, `input-output` | the same |
| north `{0, -7}` | reactor energy, `output` | already the energy face |
| **south** | **nothing** | **free** |

The original mod put its reactor's two energy outputs on the **east** face and its exchanger's two
inputs on the matching west face (#47), which is where the five-by-fifteen shape comes from at all.
Reproducing that exactly would mean freeing the east face, which means moving plasma, which means
spending ADR 0011's premise. The south face costs nothing.

**And the flush contact buys nothing against a single pipe.** ADR 0022 records that
[#47](https://github.com/trulsjo/realistic-fusion-refreshed/issues/47) and
[#48](https://github.com/trulsjo/realistic-fusion-refreshed/issues/48) measured the
reactor-to-exchanger link at 31–62× of headroom and *"found the flush contact buys nothing against a
single pipe"*. **The qualifier is part of the finding and is kept**: what was measured is a bolt
against **one** pipe, not against any arrangement of them, so this paragraph is not licence to say
the geometry cannot matter to throughput anywhere. It says the reason for this shape is not a fluid
argument — which is a decision about how a plant reads, and what ADR 0022 says a footprint is.

> `entities.lua`'s comment on the same pair splits the credit the other way — #48 for the
> measurement, #47 for the conclusion — where ADR 0022 credits both jointly. The ADR is the
> citation used here. The disagreement is noted so a reader who meets both does not take one for a
> typo, and neither is this ADR's to settle.

## Decision

**Reactor energy bolts along a long face. Both reactors sell it north and south. Every connection on
an energy box is `input-output`. And each tier chains on its own axis.**

1. **Both reactors gain a second energy output, south `{0, 7}`**, `flow_direction = "output"`, one
   connection per face. `rf-reactor` and `rf-aneutronic-reactor` take the same addition. Plasma keeps
   both west and east, so ADR 0011 is untouched.

2. **`rf-heat-exchanger` is declared fifteen wide by five tall**, `collision_box`
   `{{-7.25, -2.25}, {7.25, 2.25}}`, with the energy face **north** by default — so the machine
   stands *south* of a reactor, and a row on the reactor's north face is the same machine rotated
   180°.

   | carries | box | position | direction | flow |
   |---|---|---|---|---|
   | reactor energy | `energy_source.fluid_box` | `{0, -2}` | north | `input-output` |
   | reactor energy | `energy_source.fluid_box` | `{-7, -1}` | west | `input-output` |
   | reactor energy | `energy_source.fluid_box` | `{7, -1}` | east | `input-output` |
   | water | `fluid_box` | `{-7, 1}` | west | `input-output` |
   | water | `fluid_box` | `{7, 1}` | east | `input-output` |
   | steam | `output_fluid_box` | `{0, 2}` | south | `output` |

   Each short end reads `_ e _ w _`. **Water leaves the short-end centre**, which is the one part of
   this that is a free choice rather than a consequence: the centre tile is where a reactor-facing
   connection would want to be if the machine were ever rotated onto a short end, and the energy
   tile has to be at the same offset on both ends or a column will not chain.

   `production_type` stays `"input"` on the energy box. What the machine *does* with the fluid is
   unchanged; `flow_direction` is what decides whether a connection will join another machine's.

3. **`rf-hc-exchanger` becomes the same machine at the same size with the same connections.** What
   still differs, enumerated rather than waved at: `energy_consumption` (400 MW against 40 MW), all
   three box volumes, `mining_time` (1 against 0.5), and the art. `mode` and `target_temperature`
   already agree, both inherited from the same vanilla heat exchanger.

4. **`rf-direct-energy-converter` is declared fifteen wide by five tall with energy `input-output` on
   both long faces**, `{0, -2}` and `{0, 2}`. No short-end connections: it has one fluid box and
   nothing else to place there.

5. **The two tiers therefore chain along different axes, and that is deliberate.** An exchanger
   chains through its **short ends**, because both its long faces are spent — energy in on one, steam
   out on the other — so a row grows sideways along the reactor's face. A converter chains through
   its **long faces**, so a stack grows outward from the reactor. Truls, 2026-09-07: *"the exchanger
   and the converter are different beasts, exchanger needs its array of turbines, while the converter
   needs nothing more."*

6. **Intake width is not taken.** One energy connection per reactor face, and one on each of the
   exchanger's faces. More inlets down a long face is a throughput change — #47 measured throughput
   as near linear in connection count — and
   [#227](https://github.com/trulsjo/realistic-fusion-refreshed/issues/227) is still deciding how
   much one exchanger should drain. Deferred, not rejected.

## Consequences

- **ADR 0018's item 2 becomes buildable.** A reactor, an exchanger bolted flush to its face, and a
  row chaining off it, with no pipe anywhere on that leg. That is what item 2 asserts and what item 4
  could not deliver on the current footprints.
- **The high-capacity exchanger stops being distinguishable by size, and the art has to take over.**
  `entities.lua` justified 7×7 with *"The size IS the message"*; after this the two machines differ
  only in art. This is the same move ADR 0022 already made for the reactor-versus-exchanger pair, and
  it is a real loss, stated rather than absorbed. #277 is where the art pays it back, and the comment
  in the tree is amended rather than deleted.
- **`rf-hc-exchanger` needs no geometry change to be contained**, measured above. So #86 waited on the
  ordinary exchanger's geometry (#275) and on nothing else — not on #276, and not on a Blender model.
  Both landed on 2026-09-07, and `check-containment.ps1`'s crossed section now GATES that bolt:
  `rf-hc-exchanger` is one of its three matching pairs, bolted to a reactor's north face, and the
  engine has to form the joint. The 400 MW figure stays a probe measurement —
  `probe-energy-containment.ps1`'s AC 5 row — because a rate is not what a gate here is for.
- **A converter placed backwards cannot be got wrong**, and that is why item 4 keeps both long faces
  rather than following item 2's one-sided shape. A `generator` declares only `vertical_animation`
  and `horizontal_animation`, so north and south draw identically — `graphics/mockup/` ships two
  sheets for this machine where every boiler here ships four. Energy on one long face only would look
  correct reversed and move nothing.
- **A chained row is reachable for water at its two ends only.** Measured as sufficient for eight
  machines, and it is a property a player has to live with rather than a bug: a row longer than
  eight is unmeasured, and the answer if one starves is intake width, which item 6 defers.
- **Footprints break saves and blueprints, with no migration.** ADR 0022's Consequences says the
  engine will not reconcile a changed footprint. Both mods are 0.1.0 and unpublished, so ADR 0006's
  clean-break culture covers it; the commits carry `!` and a `BREAKING CHANGE:` footer.
- **Four rendered or mocked-up machines need their geometry regenerated.** `rf-heat-exchanger` is
  re-rendered — forced, because `load-check.ps1` fails when it finds no
  `graphics/rendered/*/manifest.json` at all, so the directory cannot be deleted to escape the gate.
  `rf-hc-exchanger`, `rf-direct-energy-converter` and `rf-aneutronic-reactor` regenerate mockups.

  **Three of the four are done, and the heat exchanger's re-render moved no pixel.** #275 rendered it
  for the turned footprint; #86 then added a connection category, which changes `geometry.json` and
  so its sha, so the model had to be rebuilt and the sheets re-rendered to keep the manifest honest —
  and every one of the thirteen PNGs came back byte-identical, which is this ADR's determinism claim
  paying for itself. #87 regenerated the converter's and the aneutronic reactor's mockups.
  `rf-hc-exchanger` waits on #276.
- **`rf-reactor` keeps Krastorio 2's art and skips the mockup round.** Its art already fits its
  footprint, which is not the condition `make-mockup-art.ps1` exists for, and `entities.lua` records
  that the art is what tells the two 15×15 reactors apart. Its new south socket is drawn by
  `pipe_covers`, the same as its north one. #278 renders it properly.
- **The mockup script's hand-copied connection table becomes a gate.** It duplicates every machine's
  footprint and connections with nothing enforcing agreement, and this change moves connections on
  five machines. #275 adds the check beside `load-check`'s render gate.
- **Every rig that names a face or a footprint on this leg is rebuilt**: `check-d-t`, `check-hc`,
  `check-brownout`, `check-containment`, `check-aneutronic`, `bench-mod-links`, `bench-reactors`, and
  both probes.
- ~~**The rate is still unmeasured.**~~ **MEASURED, 2026-09-08 (#89)**, and both of the questions
  this bullet separates now have answers in
  [`bolted-joint-throughput.md`](../research/bolted-joint-throughput.md). A bolted joint carries
  **100 units/tick — 6 000 MW** on one connection, 1.95x what a twenty-pipe run did. A D-T reactor
  against a real eight-machine row sustains **320 MW**, which is the row's nameplate rather than the
  joint's limit: every machine in the row worked and every energy box sat at 199.3 of 200, so the row
  is demand-limited and the reactor's own box backs up at 97.9%. **Item 6's deferral survives and
  loses one of its reasons** — intake width cannot be justified on throughput, because the first
  connection is nowhere near full.
  Every figure behind the rest of this decision is still a box reading at steady state.
- **UPS is unmeasured**, and ADR 0005's outstanding obligation is unaffected.

## Alternatives considered

**Free the reactor's east face and reproduce the original mod exactly.** Reactor energy out east,
exchanger energy in on its west long face, which is the arrangement the five-by-fifteen shape was
drawn for (#47). Rejected: the east face is plasma, and plasma is on both west and east because
ADR 0011's shared pool depends on it. That is an ADR premise spent on a look, when the south face is
free and buys the same look.

**Keep energy north only, and put the exchanger's energy face south.** No reactor change at all, and
the machine still bolts. Rejected: one row per reactor instead of two, so a lit D-T reactor's eight
exchangers make a single row 120 tiles wide rather than two of 60. Adding a connection to a free face
is cheaper than that.

**Give the converter the exchanger's declaration** — energy on one long face plus both short ends, so
one rule covers both tiers. Rejected on the generator's two sprite states, above: it would ship a
machine whose art cannot express its own geometry. The cost of rejecting it is that a player learns
the chaining rule twice, and Truls accepted that explicitly: the two machines are different beasts.

**Leave `rf-hc-exchanger` at 7×7 and give it only `input-output` on its existing south connection.**
One field, and the two machines stay tellable apart by size. Rejected by Truls: the high-capacity
machine should *be* the ordinary one at a different scale, and one machine covering a whole reactor is
still a blueprint chore avoided whatever its footprint. The measurement above then made it cheaper
than it looked — that machine bolts as declared, so nothing about containment waits for it.

**Take intake width now**, several energy inlets down each long face, which is what the original mod
did with two. Deferred rather than rejected — item 6.

**Put `rf-reactor` on a mockup in the same pass**, so both reactors follow the usual mockup-then-model
route. Rejected: it would replace fitting art with a labelled box and put both 15×15 reactors on
labelled boxes, which is the exact distinction `entities.lua` is protecting. If it is ever done
anyway, the aneutronic one's label has to change too.
