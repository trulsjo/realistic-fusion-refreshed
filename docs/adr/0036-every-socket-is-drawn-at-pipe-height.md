# 36. Every socket is drawn at pipe height, and a contained one is told apart by what it lacks

Date: 2026-09-17

## Status

Accepted. Decided by Truls, 2026-09-17, settling
[#391](https://github.com/trulsjo/realistic-fusion-refreshed/issues/391) on the measurement
[#390](https://github.com/trulsjo/realistic-fusion-refreshed/issues/390) took. Supersedes nothing.

Amends [ADR 0018](0018-energy-is-contained-and-no-pipe-carries-it.md) and
[ADR 0033](0033-a-socket-borrows-only-real-hardware.md) in one respect each, both of them about
**art**: 0018's exemption of a contained connection from being drawn like a pipe, and 0033's
statement that it is *"vacuous for those sockets"*. **Neither ADR's plumbing decision is touched.**
Containment still means what ADR 0018 says it means, and no pipe, tank, wagon or pump a player can
build joins a contained box.

Rests on [ADR 0035](0035-the-rig-draws-what-is-below-the-ground-line.md), without which the height
below the ground line could not be measured at all, and on `docs/research/pipe-cover-miss.md`, which
is the measurement this decision acts on.

**One half of this decision is provisional and says so** — see
[The cover is kept, and that half is open](#the-cover-is-kept-and-that-half-is-open).
`models/house-style.md` holds the rule and every number;
[#392](https://github.com/trulsjo/realistic-fusion-refreshed/issues/392) carries it into the art.

## Context

`rf-heat-exchanger`'s short end carries a water socket and a reactor-energy socket two tiles apart.
The water one is plumbable and is drawn at `models/rf_blender.SOCKET_Z`, 0.033, with a tube of
radius 0.249 — both solved against vanilla's own pipe sheet since #349 and #356, and both gated.
The energy one is CONTAINED and is drawn at 0.55 with radius 0.3.

Truls saw the consequence on the frames committed with #389: the contained socket's vanilla
`pipe_cover` sits below and outboard of it, attached to nothing. #390 measured it rather than
deriving it — **0.3782 tiles at zoom 8 and 0.3764 at zoom 1, which is 12.0 screen pixels at the
size a player meets it**, taken as the difference between the two sockets on one frame in one light,
with the plumbable one as the control — +0.0229 tiles at zoom 8 and −0.0138 at zoom 1, which is to
say concentric with its own cover either way. The projection alone predicts 0.3661, and
the residue of about 0.011 tiles is recorded in that note rather than rounded away.

**The 0.55 and the 0.3 were never chosen FOR this.** They are the numbers every socket on the
machine had before #349, kept when the plumbable ones moved. `models/house-style.md` said as much in
its own words: *"the contained three keep the machine's old numbers rather than taking new ones… a look
chosen for them would be a decision nobody has been asked for"*, and, a few lines earlier, that the
difference was written down *"because the obvious next thing anyone will want to do is level
them."*

**Nothing about a contained socket's look had ever been decided, and that is the whole of the
problem.** ADR 0033 is explicit that it decides nothing here — *"This ADR is vacuous for those
sockets rather than exempting them: they borrow no cue because there is no pipe to borrow one
from."* The rim's absence is older still: `rf_parts.port` has been gated on a player-facing socket
since #343, citing ADR 0018, and that gate was written before ADR 0033 was decided. So the rim, the
flange, the height and the thickness all fell out of **one** exemption — a contained face meets a
machine, not a pipe — and not one of the four was ever weighed on its own.

**What WAS decided was to keep them, and that is on the record twice.**
`models/heat-exchanger/build.py` carried `CONTAINED_Z = 0.55  # a bolted face meets a machine, so
this is a look, not a match`, and the commit that drew the plumbable sockets at pipe thickness said
in its own message: *"THE THREE CONTAINED ONES KEEP THE OLD 0.55 AND 0.3, which is a choice and is
written down as one… Each short end therefore carries two sockets drawn differently on purpose."*
**So this ADR reverses a choice rather than filling a gap**, and the distinction is worth being
plain about: the numbers were never picked for this purpose, but keeping them was picked,
deliberately, by the same author on the same day. #390 and #391 both say "inherited rather than
chosen" and are describing the numbers, not the retention.

## Decision

**Every socket on every machine is drawn at one height and one thickness — vanilla's pipe's — and a
contained socket is told apart by the hardware it does not wear.**

1. **One geometry, from one constant.** `models/rf_blender.SOCKET_Z` and 0.249 draw every socket,
   contained or plumbable. The contained pair of constants goes, and with it the branch that chose
   between them. They are not kept as separate names holding equal values: a name free to part later
   is a fork waiting to happen, and #356 is the ticket about a constant and the art built from it
   parting in silence.
2. **The cue is the absent rim and the absent flange pair — decided here, for the first time.**
   ADR 0033 declines to decide it and ADR 0018 never addressed art at all, so this is a new rule
   rather than the promotion of an existing one: a contained socket draws a stub and an accent band,
   and the two pieces of vanilla hardware it does NOT draw are what say a pipe cannot bolt to it.
3. **The accent band thins with the tube.** `BAND_PROUD` is unchanged and there is no
   contained-specific band rule.
4. **The slab gets a hole and the hole gets no rim.** At 0.033 with radius 0.249 a contained
   socket's underside reaches to −0.216, well below the slab top at 0.25, so it needs the modelled
   opening a plumbable socket has had since #349 — but not the dark rim `rf_parts.port` puts on that
   opening's mouth, because that rim is half of item 2's cue.
5. **`tools/check-socket-height.py` measures every socket, contained ones included.**
6. **It binds every machine still to be built**, on ADR 0033's arithmetic: cheap to apply to a
   machine not yet modelled, expensive to reverse across machines already rendered. Nine prototypes
   carry 24 contained connections across 12 fluid boxes, and exactly one of them —
   `rf-heat-exchanger` — has rendered art today.

### The cover is kept, and that half is open

**A contained fluid box keeps its vanilla `pipe_covers` declaration.** Once the socket is levelled
the cover is concentric with it, so the 12 px miss this ticket began with is gone without anything
being drawn.

**This half is provisional, and it is recorded as a decision that may be revisited rather than one
that is settled** (Truls, 2026-09-17). Three things hold it in place today and each of them is a
thing that could change:

- A cover under a levelled socket reads as a fitting rather than a miss. Nobody has looked at that
  on a frame yet; #392's re-render is where it will be seen.
- It is the only art on two machines' south energy face. `realistic-fusion-refreshed/prototypes/entities.lua`
  says so at `rf-reactor`'s `output_fluid_box` — *"The south socket is drawn by pipe_covers, the
  same as the north one has always been."* — and again, without the last three words, at
  `rf-aneutronic-reactor`'s. Both still wear Krastorio 2 or mockup art.
- Removing it is one line per box at `contain()` and is reversible; re-adding art to a machine that
  lost it is not.

**What would reopen it**, stated so the next person does not have to guess: a levelled socket that
still reads as plumbable because it wears a cover, or the two machines above getting rendered art of
their own so the cover stops being load-bearing. **What must happen first**: `rf-reactor`'s south
face photographed bare. #390 photographed its west plasma face and its north energy face, not that
one, so the claim that a Krastorio 2 machine looks no worse without its cover does not yet cover the
face that depends on it.

`contain()` in `realistic-fusion-refreshed/prototypes/entities.lua` marks every contained box and is
the only place that does. It stays the chokepoint where this would be applied once rather than ten
times.

## Consequences

**A sprite that lies is the rule this was weighed against, and it cuts both ways.** A contained
socket at pipe height wearing a pipe cover invites a player to plumb something that will never join.
Against that: the flange pair is the vanilla cue that says a pipe bolts here, it has been withheld
from a contained socket by accident of ADR 0018's exemption and is withheld on purpose from here on,
and a socket with no flange and no rim is not making vanilla's claim. The bet is that
the chosen cue carries more than the inherited one did — and it is a bet, because nobody has tested
whether a player reads the absence of a flange at zoom 1. #350's own finding was that **no**
treatment, the flange included, is distinguishable at zoom 1.

**The height gate's reason gets weaker, and the ADR is where that is admitted rather than hidden.**
`tools/check-socket-height.py` justified its blindness to a contained connection as *"it meets a
machine face, never a pipe, and matching it to a pipe would be wrong"*, and its failure message
tells a reader that *"a CONTAINED connection belongs at the machine's own height."* Both become
backwards. The new reason is not "a pipe meets this socket" — nothing will ever meet it — but
**"every socket is drawn to one reference, and that reference is vanilla's pipe."** That is a
convention where the old one was an argument. It is accepted because the alternative is worse:
`tools/check-socket-parts.py` pins each part against the radius the *model recorded*, which is
internal consistency, so a contained socket left out of the height gate could drift to any height
with both gates passing.

**The accent band may read thin, and that is left to the frames rather than pre-empted.**
`models/house-style.md` already records the cost — *"an accent band on a thinner stub at pipe height
is a thin ring at the machine's edge, not the raised collar it was"* — and already wrote the escape
hatch: *"the band can stay proud while the tube stays thin; they are separate numbers."* It bites
harder on a contained socket than on a water one, because with the rim and the flange gone the band
is the only thing left naming the face. #359 is open on accent legibility at zoom 1 and is the
better home for it if it turns out to be general.

**The unrimmed opening may read as a bite out of the stone**, which is the exact defect
`models/house-style.md` says the rim exists to prevent: *"the opening is modelled and rimmed, so it
reads as a fitting rather than a bite out of the stone."* If it does, the fix is a rim in the tube's
own metal rather than in `dark` — one material argument, plus an edit to `tools/check-socket-parts.py`,
which today expects a contained socket to wear *"neither rim nor ribs"*. Chosen this way round
because the cheap option costs nothing if it works and the frames will show it (Truls, 2026-09-17:
*"Reopen if it looks bad"*).

**It costs a re-render of one machine and a split of a shared helper.** `rf_parts.port` cuts the
hole and rims the mouth in one call, and item 4 needs those separable. `rf_parts.socket`'s
`plumbable` argument stops meaning "height, thickness, hole, rim and flanges" and starts meaning
"hole with a rim, and flanges" — the hole itself now being drawn for every socket.

**Whatever is chosen for the cover, all nine contained prototypes move together.** This is one
convention, not a per-machine look (Truls, 2026-09-17). Nine is the machine count; the ten
`contain()` call sites and the twelve fluid boxes item 6 gives are different units of the same
thing, and "ten machines" -- which #391 and #392 both say -- is the call-site count wearing the
wrong noun.

**#391 records; #392 builds.** This ADR, the `models/house-style.md` rewrite and the three terms
added to `CONTEXT.md` close #391. The build-script change, the `port` split, the re-render and the
gate change are #392's, and #392 requires the gate to be shown failing before it passes — which a
gate written in the same sitting as the art it gates has nothing to fail against.

## Alternatives considered

**Keep 0.55 and 0.3, and draw our own cover art at the socket's own height.** The best-looking
answer if the sockets stay where they are, and by a wide margin the most work: a cover shape decided
against the house style, sprites per accent, a render path, a manifest record, a gate and acceptance
by eye. Rejected because it spends all of that on a look whose only argument is that it is the one
we happen to have. It would be the right answer if the height difference were a designed cue; it was
kept deliberately, but it was never designed.

**Keep the height and declare no cover at all.** Arguably the honest reading of ADR 0018 — no pipe
can ever arrive, so nothing should be drawn as though one might. #390 established that the engine
permits it: 2.0.77 strips `pipe_covers` from all 12 contained boxes, loads, draws nothing in their
place and logs zero Error and zero Warning lines across 113 lines. Rejected on two counts. It leaves
the socket at an unchosen height, which is the thing this ticket exists to settle; and it removes
the only art on two machines' south energy face, on evidence that never photographed either of them.

**Leave it.** The miss is 12 px at zoom 1 and only on an unconnected machine — in a built factory a
contained connection is bolted to a reactor and the cover is hidden. Rejected because the miss was
the symptom and the unchosen height was the cause, and #390's measurement made the cause visible
rather than the symptom worse.

**Give the contained socket the hole and its dark rim, so `rf_parts.port` need not be split.** The
smallest possible change, and it destroys half the cue this ADR rests on. It would also contradict
ADR 0033 and the expectations written into `tools/check-socket-parts.py`. Rejected on the decision
above rather than on cost.

**A contained face should not be drawn as a tube at all** — a bolting face is a flange plate, not a
socket. Nobody has proposed this and it is recorded because nobody has. It would be a larger and
more honest answer than any of the four #391 listed, and it is not ruled out by anything here: this
ADR settles how a contained socket is drawn *given that it is a socket*. If it is ever taken up, it
supersedes this.

**Give contained sockets their own named constants equal to the plumbable ones.** Rejected: a
separate name free to part later buys exactly the freedom item 1 decided against, and buys it
silently. #356 is the ticket about that failure mode — *"the two can no longer part in silence,
which is the part of this that outlives the number."*
