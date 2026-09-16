# 34. An accent is read against its neighbour, not recognised on its own

Date: 2026-09-16

## Status

Accepted. Decided by Truls, 2026-09-16, settling
[#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359) on the measurements
[#379](https://github.com/trulsjo/realistic-fusion-refreshed/issues/379) took and the frames #359's
own working shot. Supersedes nothing.

The rule is in `models/house-style.md`'s Palette. This ADR holds the standard behind it and the
standard it rejected, because the rulebook records a decision that changed nothing and the reason it
changed nothing is the whole content.

## Context

`models/house-style.md` makes an accent load-bearing — *"the accents say what a socket carries"* —
and refuses hazard yellow as a fluid accent on those grounds. `scripts/ship-check.ps1` section 8
holds each fluid-derived accent against the fluid's own colour across three copies
([#334](https://github.com/trulsjo/realistic-fusion-refreshed/issues/334)), so the colours cannot
drift.

Nothing protected the number of pixels the colour gets, or how far two of them land apart once
drawn. #359 asked whether a player can tell one accent from another at zoom 1 — 32 px to the tile —
naming tritium and helium-3, which are both pale and share `rf-isotope-collector`.

Two bodies of measurement answer it, and they are in `docs/research/accent-separation.md` (the
shipped sheets) and `docs/research/accent-legibility-at-zoom-1.md` (both machines photographed in a
real map).

**The finding that decides the question is not about either pair.** On `rf-heat-exchanger`, water's
own two sockets land **33.0 dE00** apart — further than the **29.2** that separates energy from
water at their closest. One fluid, one machine, one sheet, two sockets, and the same palette row
produces two colours further apart than two different palette rows do. The west socket stands in
the open and the east is shaded by the machine's own body.

So the question "what colour is helium-3, at zoom 1" has no answer. It is not that the answer is
imprecise; there is no single quantity there to be precise about.

## Decision

**An accent is read against its neighbour.** It distinguishes one socket from another on the machine
in front of the player, in one frame, under one light. It is not a name for a fluid that a player
recognises on sight, and no rule, gate or geometry choice may be justified on the grounds that it
should be.

**The consequence for #359 is that nothing changes.** No palette value moves, no band lengthens, no
geometry is touched, and #334's gate and its three copies stay as they are. The closest pair that
can share a machine is **11.2 dE00**, off the bench, and the pale pair reads at roughly **23.6** in
the game frame — both far above what an eye needs for two patches side by side.

**The two figures are not equally solid, and the decision does not need them to be.** 11.2 comes
from `tools/measure-accent-separation.py`, through a geometry-derived window with a stability check
beside it. 23.6 comes from a hand-placed hue cut, which `docs/research/accent-legibility-at-zoom-1.md`
itself calls *"adequate for 'are these two visibly different colours' and inadequate for 'how far
apart are they, exactly'"*. Read 23.6 as the answer to the first question only. Nothing above rests
on its second decimal: the pair was decided on being visibly two colours, which is what a crude
method can establish and what the frames show.

**The standard binds machines not yet rendered.** A pair on a new machine is checked against it
rather than reopening the question. Eleven of thirteen entities have no sheets; plasma is carried by
six of the eight the bench cannot reach at all, and by neither machine that has sheets, so the pair
`models/house-style.md` flags in prose — helium-3's violet against plasma's — is on no entity in the
survey.

**This is not a gate and must not become one.** A threshold on legibility is a decision wearing a
check's clothes, which is #379's own phrase and the reason `tools/measure-accent-separation.py` is a
bench.

## Consequences

**Two of the rulebook's own sentences are now narrower than they read**, and both are edited in
place rather than left for the new paragraph to correct at a distance. *"The accents say what a
socket carries"* stays, because on one machine it is exactly true; what it cannot be read as is *"a
colour names a fluid"*. The second is *"One accent per fluid, used the same way on every machine, so
a player reads a machine's plumbing from its colours before reading its tooltip"* — which is the
more directly absolute of the two, since it spans machines outright. It also survives, read as a
claim about telling one machine's sockets apart, and `models/house-style.md` now says which reading
is meant. A reader meeting either sentence alone would conclude the opposite.

**A future complaint of the form "this accent looks wrong on this machine" is not evidence of a
palette problem.** Under this standard it is a lighting observation until somebody shows two
accents on one machine that cannot be told apart. That is the failure mode this ADR exists to
prevent: a re-render of every sheet, paid to fix a number that was never a property of the palette.

**It fixes what a measurement has to compare.** Two accents on one machine, never an accent against
its palette row and never an accent against the same accent on another machine. `accent-separation.md`
already reports per pair per machine for this reason; the standard makes that the required shape
rather than a choice its author made.

**It leaves "at speed" unanswered, and says so.** The frames are a machine standing still on grass,
with the camera still. Nobody has looked at these accents on a screen with a factory on it. If that
is ever done and the finding differs, this ADR is what it supersedes.

## Alternatives considered

**An accent names its fluid absolutely** — a player learns that pale green is tritium and reads it
anywhere, on any machine, without a neighbour to compare against. This is what house-style's
existing sentence sounds like, and it is the standard most readers would assume.

Rejected because it is already false and cannot be repaired by moving a palette colour. Water's own
two sockets are 33.0 dE00 apart on one sheet. Recovering an absolute standard would mean flattening
the lighting across every face of every machine, which is a larger change than anything #359
contemplated and would cost the modelling its shading. The choice is not between the two standards;
it is between the relative standard and having none.

**Lengthen the bands.** `models/rf_blender.py`'s `BAND_DEPTH` grows and every machine re-renders.
Rejected on the frames: the exchanger's narrowest bands are 2.0 screen pixels wide and 22 to 27
tall, and both read plainly at zoom 1. Width was never what the eye was using, so the re-render buys
nothing.

**Move a palette colour** — helium-3 or tritium shifts far enough that no reading of the pair is
close. Rejected as the most expensive option against the least demonstrated defect: #334's gate and
all three copies move, every sheet re-renders, and the pair it would separate already reads as two
colours in the frame a player meets.

**Move the band inboard of where a vanilla pipe ends.** Proposed inside #359's own working on the
claim that a plugged-in pipe covers most of the band. **The claim was false**, and it was made from
a small overview frame rather than from pixels: sampled through one window in both frames, the
collector's west band and the exchanger's west water band are identical with and without a pipe, to
the pixel and to 0.0 dE00. Vanilla's pipe butts up outboard of the flange pair ADR 0033 put there,
and the accent sits inboard of it. Recorded here because the option was nearly filed as an issue.
