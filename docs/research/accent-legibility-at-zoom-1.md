# What two fluid accents look like at zoom 1, in the running game

Shot 2026-09-16 with `scripts/probe-isotope-collector-art.ps1` and
`scripts/probe-heat-exchanger-art.ps1`, for
[#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359). **This note is a probe's
findings.** The decision it fed is ADR 0034 and the rule it produced is in `models/house-style.md`.

**Its sibling is `docs/research/accent-separation.md`**, and the two measure different things. That
note reads the committed sheet under
`realistic-fusion-refreshed-assets/graphics/rendered/<machine>/` and needs no game. This one
photographs the machine standing in a real map, under the game's own light, with vanilla pipes
plugged into it. A sheet is what we ship; a frame is what a player sees.

## Why the frames are committed

The same reason #350's are. The decision recorded here is "we looked and left it alone", and a
decision of that shape with nothing left to look at is worthless to the next reader. Re-running the
probes reproduces these frames only until a machine is re-rendered.

| File | What it shows |
|---|---|
| `collector-alone.png` | `rf-isotope-collector` on grass, 11 tiles across, zoom 1 |
| `collector-pipes.png` | the same machine with vanilla pipes plugged into all three sockets, 13 tiles |
| `exchanger-alone.png` | `rf-heat-exchanger` on grass, 21 x 11 tiles, zoom 1 |
| `exchanger-pipes.png` | the same, with pipes on the three connections that accept one |
| `pale-pair-x8.png` | the collector's deck, alone on the left and piped on the right, magnified 8x |
| `collector-west-socket-x8.png` | its west tritium socket, the same two frames, magnified 8x |
| `exchanger-west-sockets-x7.png` | the exchanger's west energy and water sockets, magnified 7x |

**The three magnified files are zoom-1 pixels enlarged by nearest-neighbour, not renders at another
zoom.** Every pixel in them is a pixel a player gets; the enlargement only makes them arguable.
[#371](https://github.com/trulsjo/realistic-fusion-refreshed/issues/371) is what confusing the two
costs, and it is why neither probe now calls a magnified frame the game's own camera. Until this
issue each one said exactly that, while its lowest shot was zoom 1.5 and the frames a person was
meant to judge the machine from were zoom 3. **What changed is the sentence at the top of each file
and the two frames that answer at zoom 1** -- not every shot. The other twelve carry their zoom as
the argument to `tiles_shot`, which is where it has always been. Only the exchanger's zoom-3 frames
have their zoom appear in prose at all, and there only inside a comment about a sizing error those
frames once had.

## The pale pair, which is what #359 asked about

**They are adjacent, and they are different colours.** Two drums on the collector's deck carry the
accent rings, and `pale-pair-x8.png` is the pair side by side in one frame:

| accent | colour as the game draws it | L\* | a\* | b\* | ring pixels |
|---|---|---:|---:|---:|---:|
| tritium | `#a6b9ac` | 73.4 | −9.1 | +4.4 | 91 |
| helium-3 | `#ac9fba` | 67.4 | +9.9 | −12.2 | 140 |

**dE00 23.6, with the ring centres 24.5 screen pixels apart.** One reads green and the other lilac;
they differ in lightness by six L\*, and they sit on opposite sides of neutral in both `a*` and
`b*`. That is the comparison #359 is about, in the frame a player meets, and nothing in it is
marginal.

This corrects a thing said during triage and repeated while this issue was being worked: that
helium-3 is on the collector's north face and tritium on west and east, so the two are never
adjacent. As **socket bands** that is true. The deck's accent rings are not socket bands, and they
put the pair side by side anyway.

## A pipe does not cover a band

Stated here because it was claimed, in this issue's own working, and it is false. Both bands were
sampled through one window in both frames:

| band | with no pipe | with a pipe plugged in | moves |
|---|---|---|---:|
| collector west, tritium | 126 px, `#a3baaa` | 126 px, `#a3baaa` | **0.0 dE00** |
| exchanger west, water | 237 px, `#7592ae` | 237 px, `#7592ae` | **0.0 dE00** |

Identical, to the pixel. Vanilla's pipe butts up **outboard** of the accent, against the socket's
flange pair, and the band sits inboard of it — which is what ADR 0033's end treatment put there.
`collector-west-socket-x8.png` and `exchanger-west-sockets-x7.png` are the two frames side by side.

The exchanger takes three pipes and **refuses three**, which is what contained means
(`CONTEXT.md`, Contained). Its energy sockets are among the refusals, so no pipe can reach them at
all.

## Two screen pixels was not the problem it looked like

`accent-separation.md` measures the exchanger's north energy band and west water band at **2.0
screen pixels** wide, against 6.0 for the widest. That figure is a width, and the eye is not using
width: the same bands are 22 to 27 pixels tall, and `exchanger-west-sockets-x7.png` shows the tan
energy band and the blue water band both reading plainly at zoom 1. A band is a stripe, and a
stripe two pixels wide and twenty-two tall is not a two-pixel mark.

## What this note does NOT establish

**It does not show the game reproducing the sheet.** Read against `accent-separation.md`'s figures
for the same two sockets, the game frame agrees to 0.6 dE00 on one and differs by 8.4 on the other:

| socket | sheet, per `accent-separation.md` | this frame | dE00 |
|---|---|---|---:|
| collector west, tritium | `#a5bbaa` | `#a3baaa` | 0.6 |
| exchanger west, water | `#92acc3` | `#7592ae` | 8.4 |

**Do not read the 8.4 as the game darkening anything.** The two figures came through different
windows: the bench picks its columns from `models/rf_blender.py`'s `BAND_BACK` and `BAND_DEPTH` and
classifies each column nearest-of-two against the machine's own body, while everything in this note
was picked by hue out of a hand-placed box. Different windows on the same band are not a
measurement of the difference between a sheet and a frame. Settling that would take the bench's own
window applied to a game frame, and nothing here does it.

Everything in this note is a hue-and-saturation cut followed by a median, which is the crude method
#379's brief warned against for the sheets. It is adequate for "are these two visibly different
colours" and inadequate for "how far apart are they, exactly" — `accent-separation.md` is the
second question's answer and this note is not a second opinion on it.

And it does not measure a moving camera, a player under attack, or a screen with a factory on it.
"On grass, at speed" is half-answered: on grass, standing still.
