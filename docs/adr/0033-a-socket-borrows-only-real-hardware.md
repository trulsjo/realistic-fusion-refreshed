# 33. A socket borrows a vanilla drawing cue only when the cue is real hardware

Date: 2026-09-14

## Status

Accepted. Decided by Truls, 2026-09-14, settling
[#351](https://github.com/trulsjo/realistic-fusion-refreshed/issues/351) from the frames
[#350](https://github.com/trulsjo/realistic-fusion-refreshed/issues/350) shot. Supersedes nothing.

`models/house-style.md` holds the rule and every number. This ADR holds the principle behind it,
the three treatments it rejected and the criterion it deliberately overrode, because a rulebook
records what is done and none of those three are.

## Context

[#349](https://github.com/trulsjo/realistic-fusion-refreshed/issues/349) settled how a plumbable
socket is *measured* against the pipe that plugs into it. Height and thickness are now solved from
vanilla's own sheet and gated by `tools/check-socket-height.py`. Truls accepted the resulting art on
2026-09-14. Shape was left alone, because no measurement reaches it.

The two objects are genuinely different things. Vanilla's pipe is a stylised flat ribbon with heavy
flanges and a dark core; work its drawn extents back and no cylinder fits them. Ours is an honest
cylinder. So "make them match" is not a number to correct. It is a question of how far this mod
imitates vanilla's drawing conventions against its own, and `CLAUDE.md` puts that class of call with
Truls rather than with an agent.

#350 built a rig that draws one socket's end four ways onto throwaway copies of a shipped model and
photographs each with an ordinary pipe plugged into it, at zoom 8 where a seam can be argued about
and at zoom 1 where a player meets it. Nothing it makes can ship. The four were `bare` (the
control, byte-identical to what ships), `flanged`, `dark-cored` and `rimmed-inboard`.

**The frames found something none of the four treatments had been proposed knowing.** With a pipe
joined, there is almost no bare tube at a socket's mouth: what shows outside the slab is vanilla's
`pipe_cover`, then the accent band, then the slab edge. Three of the four were decorating a surface
a player never sees.

## Decision

**A socket borrows a vanilla drawing cue when, and only when, the cue is also hardware a real pipe
has.** A flange is. A painted window is not.

Applied to #350's four, that puts a **flange pair at the mouth of every socket a player can plumb**
— two ribs standing proud of the tube, in the tube's own material, just inboard of the dark rim.
[#353](https://github.com/trulsjo/realistic-fusion-refreshed/issues/353) is where it reaches the
art, through the helper
[#352](https://github.com/trulsjo/realistic-fusion-refreshed/issues/352) extracts.

**The accent band does not move, thin, lengthen or change colour.** It was the thing every candidate
had to survive rather than a thing to trade against the seam: the accents are what tell a player
which socket carries what, and #334 gates their colours across three copies for that reason.

**A contained connection is untouched**, the same exemption
[ADR 0018](0018-energy-is-contained-and-no-pipe-carries-it.md) has forced since #343. A shape chosen
to sit well against a pipe has nothing to sit against on a face that meets a reactor. This ADR is
vacuous for those sockets rather than exempting them: they borrow no cue because there is no pipe to
borrow one from.

## Consequences

**#350's zoom-1 criterion is overridden, and the override is the part that has to survive.** #350
said *"a difference nobody can see at 32 px to the tile is not a candidate, and magnification alone
would hide that."* **No treatment, the flange included, is distinguishable at zoom 1.** Read
literally the criterion eliminates all four and `bare` stands.

It is set aside on the grounds that it was written to stop a treatment being chosen off
magnification alone, and a flange is not an artefact of zoom — it is hardware, it is what vanilla
itself draws there, and players do zoom in. The cost of the override is that the next person will
find #350's sentence, find a flange nobody can see at play distance, and undo it. That is why the
paragraph exists in `models/house-style.md` as well as here.

**It costs a re-render of two machines' sockets, and that re-render is already being paid for.**
[#356](https://github.com/trulsjo/realistic-fusion-refreshed/issues/356) corrects `SOCKET_Z` and
re-renders the same sockets; it is held until #353 so Truls sees one set of frames rather than two.

**It binds every machine still to be built.** ADR 0010 names five more with plumbable sockets. The
principle is cheap to apply to a machine not yet modelled and expensive to reverse across machines
already rendered, which is the same arithmetic #356 makes about the height.

**The ribs must be fitted by measurement, not typed.** On the isotope collector the clear span
between the rim and the accent band is 0.09 tiles, and the first attempt at typed offsets buried one
rib and clipped the band. `models/house-style.md` carries the rule and the numbers.

## Alternatives considered

**Borrow nothing — a socket matches a pipe's measurements and no more.** The honest-cylinder
position, and the one recommended before the frames were looked at. It has a real argument: the
complaint that opened #349 was a visible step at the join, that step was a height and a thickness,
and both are now measured and gated. It was rejected on the frames: vanilla's `pipe_cover` already
puts a ring at that join, and adding the pair vanilla itself draws beside it is not imitation of a
convention so much as finishing a fitting that is half drawn.

**Match vanilla's read as far as possible, dark core included** (`dark-cored`). Rejected twice over.
It came out indistinguishable from the control even at zoom 8, because there is no exposed tube to
put a channel on; and had there been, it would have drawn the shadow inside a ribbon onto a
cylinder, which is a feature our geometry does not have. This is the boundary the decision above is
drawn at.

**Move the dark rim inboard onto the body face** (`rimmed-inboard`, called `collared` until this
ADR). The only one of the four that was visibly different, and it failed on the accents: the rim
moving inboard pushes the band onto the body face where the slab edge clips it to a sliver. Better
seam, worse machine.

**Answer the accent-legibility question here too.** The frames raised it — at zoom 1 an accent is
about six pixels of pale colour, and tritium and helium-3 are both pale. Refused: that is a finding
about every accent on every machine, and folding it into a rule about one kind of socket would hide
it. It is [#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359).
