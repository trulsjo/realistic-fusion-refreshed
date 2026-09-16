# 35. The rig draws what is below the ground line

Date: 2026-09-16

## Status

Accepted. Decided by Truls, 2026-09-16, settling
[#373](https://github.com/trulsjo/realistic-fusion-refreshed/issues/373) on the cause
[#368](https://github.com/trulsjo/realistic-fusion-refreshed/issues/368) named. Supersedes nothing.

Rests on [ADR 0030](0030-art-is-rendered-from-stored-models.md), which is why there is a rig at all,
and on `docs/research/socket-underside-cut.md`, which is the measurement this decision acts on.
`models/render.py` holds the wiring and `models/house-style.md` the numbers.

## Context

`models/rf_blender.build_rig` puts a shadow-catching plane at world z 0. It is what the shadow sheet
is made of: `models/render.py` takes the structure from the Combined pass and the shadow from the
Shadow Catcher pass of the same render, so the plane is not decoration and cannot simply go.

**A shadow catcher is transparent in the beauty pass but not to what is behind it.**
`tools/check-socket-height.py`'s header claimed that for months and nobody had tested it. #366 and
#367 tested it twice — on a real machine and on thirty-six bare cylinders — and it is right. The
plane hides everything below world z 0, and below its axis a tube of radius `r` at height `z` draws
`sqrt(r^2 - z^2) + z/tan(pitch)` tiles instead of `r/sin(pitch)`, until `z` reaches `r cos(pitch)`
and the plane stops reaching it.

Every socket a player can plumb is drawn at `SOCKET_Z` = 0.033 with a tube of radius 0.249, which is
well under that threshold. So each one lost about a pixel underneath and kept its full extent on
top: the tube drew +20.5 px above its axis against +18.5 below, where vanilla's barrel — the thing
it is bolted to — draws +19.5 either way. Truls saw it as an accent band that read proud on top and
flush underneath, and #373 states the rule it broke: **a plumbable socket's tube draws vanilla's
barrel extent above AND below the axis the two share.**

## Decision

**The rig does not occlude what the camera would otherwise see below the ground line.** A sprite
draws the whole of the machine, the parts that stand below ground included, the way vanilla's own
pipe draws its whole barrel.

**Structure and shadow come from two view layers of one render.** The structure layer marks the
Ground plane's collection *indirect only* — the plane lights the machine and does not stand in front
of it; the shadow layer leaves the plane alone, so the Shadow Catcher pass has something to catch.

**Nothing about the socket moves.** Not the accent band, which #373 forbids in terms; not the radius
and not `SOCKET_Z`, both of which are solved against vanilla's own sheet and gated.

## Why not one of the cheaper four

Measured on the shipped rig on 2026-09-16, a minimal scene, structure and shadow wired the way
`models/render.py` wires them. Alpha pixels drawn, and the shadow sheet's alpha sum:

| Ground plane | structure rows | structure alpha px | shadow alpha sum |
|---|---|---|---|
| as it shipped | 209..407 | 9847 | 1 066 378 |
| `visible_camera = False` | 209..409 | 9982 | **0** |
| deleted | 209..409 | 9982 | **0** |
| Transparent BSDF, still a catcher | 209..**407** | 9847 | **0** |

**No single render gives both.** Anything that stops the plane occluding stops it catching, and a
transparent material is the worst of the four — it occludes *and* the shadow goes. That is what
makes a second layer necessary rather than merely tidy, and it is why this is an ADR and not a line
in a rulebook: it costs a second trace of every scene.

**Indirect-only rather than deleted**, because deleting the plane takes its bounce light with it and
re-shades every machine. **Nothing but a socket was ever behind that plane**, and the re-render
proves it: across both machines and all eight direction sheets, every pixel whose alpha moved sits
in a socket-sized cluster — 19 columns by 14 rows for a socket seen side-on, 50 by 22 for one seen
end-on. The only exception is two pixels per sheet at the frame's own corners, which gain 5 to 12 of
alpha over near-black, three tiles of margin from the machine. **Every shadow sheet is
byte-identical to the one it replaces.**

## Consequences

**Every machine re-renders**, including art already accepted. Two today.

**Renders cost a second trace per direction.** The shadow layer is switched off for a lit render —
the glow sheets and the icon take nothing from it — so the cost is four extra traces per machine and
not nine.

**The `+0.031` tile residual `tools/check-socket-height.py` carried is gone**, and that is the model
checking itself rather than a separate win. With nothing cut, a socket's drawn centre should be
`0.70804 × 0.033` = `+0.02337` tiles against the `+0.02337` that gate measures off vanilla's own
pipe — a residual of zero. Measured after the re-render: **all six plumbable sockets read `+0.000`**,
where every one read `+0.031` before. `docs/research/socket-underside-cut.md` stated that prediction
before anything was re-rendered.

**`models/socket-variants.py`'s `groundless` treatment now removes only bounce and shadow.** It is
kept — `models/house-style.md` and the research note cite it in runnable commands — and its
docstring says what it does now.

**A new gate, `tools/check-socket-parts.py`**, holds every piece of every socket symmetric about its
axis and as wide as the model recorded drawing it. It is what stops this returning, and it needed
the model to start recording what it drew: a manifest's `geometry` block is the prototype's, and a
Factorio prototype carries no radius and no height.
