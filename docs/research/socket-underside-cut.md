# What cuts a socket's underside

Measured 2026-09-16 for [#366](https://github.com/trulsjo/realistic-fusion-refreshed/issues/366)
and [#367](https://github.com/trulsjo/realistic-fusion-refreshed/issues/367), two of the three
probes [#362](https://github.com/trulsjo/realistic-fusion-refreshed/issues/362) suggested. They are
one committed script with two scenes; rerun either with

```
python scripts/probe-socket-underside.py machine   --out <scratch>
python scripts/probe-socket-underside.py cylinders --out <scratch>
```

**The answer is yes: the shadow-catching ground plane is the cut, and it hides everything below
world z 0.** `tools/check-socket-height.py`'s header said so and nobody had tested it. It is now
tested, twice, on a machine and on thirty-six bare cylinders, and it is right.

## The question

A socket drawn at pipe height loses part of its underside. What was known was four measurements off
one machine at one height, and two of #362's own sentences said the simplest reading of the claim
did not fit them:

- *"A cut at a fixed screen row would put them all on the same one"* — #362 reads the four parts as
  stopping at roughly rows 370, 371, 373 and 377 of the same sheet.
- A cut at world z 0 *"predicts the stub's lowest visible point 17.3 px below its axis where 19.5 is
  measured"*.

Both objections were sound arithmetic about the wrong comparison, and the second paragraph of
[the model](#the-model) says why.

## The model, and it fits nothing

This camera is orthographic at `rf_blender.CAMERA_PITCH_DEG` = 54.7 degrees, and draws a point
`(y, z)` of the plane across a tube at `y + z / tan(pitch)` up the screen. So a cylinder of radius
`r` whose axis sits at world height `z` draws, in tiles either side of that axis:

| | above the axis | below the axis |
|---|---|---|
| nothing cut | `r / sin(pitch)` = 1.2255 r | 1.2255 r |
| everything under world z 0 hidden | 1.2255 r | `sqrt(r^2 - z^2) + z / tan(pitch)` |

The plane stops reaching the tube at `z = r cos(pitch)` — how far under its own axis a silhouette's
lowest point sits — and above that the two rows agree. **There is no fitted parameter anywhere in
that table.** Both constants come off the camera, so every number below is a prediction and not a
curve through the data.

**AND THE BOTTOM OF THE SILHOUETTE IS NOT AT A FIXED SCREEN ROW, WHICH IS #362'S FIRST OBJECTION
ANSWERED.** With the plane cutting, the lowest drawn point of a tube is the point of its
cross-section at world z 0, at `y = -sqrt(r^2 - z^2)` — so it lands `sqrt(r^2 - z^2)` tiles below
the GROUND LINE, which is a different row for every radius. A plane at one world height and a cut at
one screen row are not the same thing under a pitched camera, and the four parts stopping at four
rows is what the plane predicts rather than evidence against it.

**THE SECOND OBJECTION IS A DRAWN EDGE AGAINST A GEOMETRIC ONE.** A drawn edge spreads past the
geometry that cast it — the bevel, and Cycles' 1.5 px reconstruction filter — so every part measures
about a pixel MORE than its prediction, at the top as well as at the bottom. The stub's 17.3 against
19.5 is 2.2 px, of which about 1 px is the same spread the stub's TOP edge shows (+20.5 measured
against ±19.5 predicted) and the rest is half a pixel of row-edge quantisation at each end. The
comparison that works is the shortfall below MINUS the gain above, on the same cylinder.

## #366: the machine with the plane taken away

`rf-isotope-collector`'s west socket, rendered **four ways** into a scratch directory: as it ships,
with `models/socket-variants.py`'s `groundless` treatment, with its `unflanged` one, and with both.
Pixels above and below the socket's own axis.

**TWO VARIABLES AT TWO LEVELS, AND THE SECOND ONE IS NOT THE SUBJECT.** The ground plane is what
#366 asks about. The flange ribs are in the table because they are what stops the STUB being
measurable at all — they leave 1.15 px of tube between them, and no whole column of a sheet wearing
them falls clear of both, so `tools/measure-socket-parts.py` reports the stub as NO WINDOW and is
right to. Deleting them gives the stub a window; deleting them *and* the plane gives the row no
shipped sheet can carry.

| part | ribs on, plane on | ribs on, plane off | ribs off, plane on | **ribs off, plane off** |
|---|---|---|---|---|
| stub 0.249 | *no window* | *no window* | +20.5 / +18.5 | +20.5 / **+20.5** |
| accent band 0.289 | +23.5 / +20.5 | +23.5 / **+23.5** | +23.5 / +20.5 | +23.5 / **+23.5** |
| flange ribs 0.319 | +25.5 / +22.5 | +25.5 / **+25.5** | *deleted* | *deleted* |
| dark rim 0.379 | +30.5 / +26.5 | +30.5 / **+30.5** | +30.5 / +26.5 | +30.5 / **+30.5** |

**Every part goes symmetric when the plane goes, and the stub with them: 1.0 px lost under the
plane, nothing without it.** The top edge never moves, at the tenth of a pixel the tool prints —
only the underside was ever being touched. A `loses` of -0.8 or -1.0 is the same sub-pixel spread
the `gains` column carries, not a gain of material.

**AND THE TABLE CARRIES A CONTROL NOBODY PUT IN IT.** Deleting the ribs is supposed to change
nothing but the stub's window, and it does not: columns one and three agree on the band and the rim
to the pixel, and so do columns two and four. If deleting geometry had moved a neighbouring
reading, that is where it would show.

The stub's two readings are exactly the bare cylinder at radius 0.249 in the next section — the
same +20.5/+18.5 and +20.5/+20.5 — which is a machine's socket and a plain tube agreeing to the
pixel.

**AND IT IS TWO MACHINES, NOT ONE.** `rf-heat-exchanger`'s south steam socket is measured on the
`-e` sheet, a different machine at a different place on a different frame, and it gives the same
three rows to the pixel — 2.2 / 2.5 / 3.2 px lost as shipped, `+23.5/+23.5`, `+25.5/+25.5` and
`+30.5/+30.5` with the plane gone:

```
python scripts/probe-socket-underside.py machine --machine heat-exchanger \
       --direction south --fluid steam --radius 0.249 --out <scratch>
```

### The shadow catcher's own flags

Read off the object in the Blender doing the rendering, with each description taken from that
build's own RNA rather than from a manual page — `rf_blender.ground_report` prints it. **Abridged
below**: the tool gives every flag a line of its own, and the six `visible_*` lines are collapsed
here because they carry the same value and near-identical text. Run the probe for the full
transcript.

```
Ground, under blender 5.2.0 LTS:
    is_shadow_catcher = True   -- Only render shadows and reflections on this object, for
                                  compositing renders into real footage. Objects with this setting
                                  are considered to already exist in the footage, objects without
                                  it are synthetic objects being composited into it.
    is_holdout = False         -- Render objects as a holdout or matte, creating a hole in the
                                  image with zero alpha
    visible_camera = True      -- Object visibility to camera rays
    visible_diffuse, visible_glossy, visible_raycast, visible_shadow, visible_transmission,
    visible_volume_scatter = True
```

**So a shadow catcher being "transparent" does not make it transparent to what is BEHIND it, and the
flag's own description is why.** An object marked this way is treated as already existing in the
footage; everything else in the scene is synthetic and is being composited INTO it. Synthetic
geometry behind the catcher is therefore occluded exactly as it would be by real ground. That is not
a misconfiguration to fix — `visible_camera` is True and `is_holdout` is False, which is a shadow
catcher set up the ordinary way — and it is not something the gates should route around. It is the
plane doing its job.

**THE MANUAL DOES NOT SAY THAT, AND THIS NOTE IS NOT PRETENDING IT DOES.**
[Blender 5.2's page on the option](https://docs.blender.org/manual/en/5.2/render/cycles/object_settings/object_data.html)
reads *"Enables the object to only receive shadow rays. It is to be noted that, shadow catcher
objects will interact with other CG objects via indirect light interaction. This simplifies
compositing CGI elements into real-world footage."* — read 2026-09-16, and it settles what the
option is FOR without saying either way whether geometry behind one is occluded. The sentence that
does is the tooltip above, which is the running build's own, and the render is what actually
answers it. This is exactly the shape #366 asked for: the flags read, and the documentation checked
rather than assumed to contain an answer it does not.

## #367: the law, across radius and height

`models/socket-cylinders.py` builds thirty-six bare cylinders on the shipped rig — six radii by six
heights, one per connection on a 3 x 54 tile footprint — and the probe renders that scene twice and
measures every one. Every number goes through `tools/socket_strip.py`, the same two cuts, the same
alpha floor and the same window guard the gate and the instrument read through.

**The residual is the whole result.** It is the bottom's excess over its prediction, minus the
top's own excess over its prediction — which is `gains`, because the top's prediction is the uncut
extent. Both edges are drawn edges and both stand the same fraction of a pixel proud of the
geometry that cast them, so the two excesses cancel and the residual is **zero when the model is
right**, whatever that spread happens to be.

| render | rows | residual |
|---|---|---|
| ground plane present, the 19 rows it reaches | 19 | −0.9 to +0.6 px, mean −0.1 |
| ground plane present, the 17 rows it does not reach | 17 | −0.9 to +0.8 px, mean +0.1 |
| ground plane deleted, all 36 | 36 | −0.9 to +0.8 px, mean +0.0 |

**All three groups sit on zero, inside a pixel.** The rows the plane cuts are indistinguishable from
the rows it does not, and from the rows in a render with no plane in it at all; ±0.9 px is the
half-pixel of row-edge quantisation at each end and nothing more. There is nothing left over for a
second cause to be.

**THE FIRST VERSION OF THIS TABLE READ +0.6 TO +2.5, AND THE ARITHMETIC WAS WRONG** — found by the
review of the pull request, not by a gate. The probe ADDED the top's excess where it had to
subtract it, so instead of cancelling the spread it stood twice the spread in the column: about
+1.5 px on every row, cut or uncut. **The verdict never depended on it**, because the same formula
ran on both groups and they matched either way, and no other number in this note comes off it. What
it cost was the strength of the answer: the residual looked four times looser than it is, and a
column documented as "zero if the model is exact" printed +1.5 while three separate places said it
should print 0.

With the plane gone, **the largest asymmetry over the whole grid is 0.9 px** — at radius 0.45 and
z 0.10, on a silhouette 72 px tall. Every other one of the thirty-six is closer than that.

### The four machine measurements fall on it exactly

`models/house-style.md`'s socket table is four parts of a real socket, each wearing a rim or a band
or a rib. The test scene's bare cylinders at z 0.033 are plain tube. They agree to the pixel:

| radius | machine's socket | test cylinder | deficit predicted |
|---|---|---|---|
| 0.249 | +20.5 / +18.5 | +20.5 / +18.5 | 2.24 px |
| 0.289 | +23.5 / +20.5 | +23.5 / +20.5 | 2.79 px |
| 0.319 | +25.5 / +22.5 | +25.5 / +22.5 | 3.21 px |
| 0.379 | +30.5 / +26.5 | +30.5 / +26.5 | 4.06 px |

Two things follow. The deficit depends on the part's RADIUS and on the socket's HEIGHT and on
nothing else — not on whether the part is a tube, a band, a rib or a rim, and not on what is beside
it. And `tools/socket_strip.py`'s column window does what it was built for: a reading taken through
it is the part's own, with its neighbours kept out.

The predicted deficits above are larger than the measured `loses` by about a pixel, which is the
same edge spread again: `loses` is measured against a geometric prediction, and the drawn edge
stands proud of it at both ends.

### Where the plane stops reaching

At `z = r cos(pitch)` the tube clears the plane. The two renders agree on where that is: deleting
the plane recovers exactly 0.0 px on every cylinder above the threshold, at all six radii.

| radius | threshold z | recovered at z 0.10 | recovered at z 0.20 | recovered at z 0.55 |
|---|---|---|---|---|
| 0.150 | 0.087 | +0.0 | +0.0 | +0.0 |
| 0.249 | 0.144 | +1.0 | +0.0 | +0.0 |
| 0.289 | 0.167 | +1.0 | +0.0 | +0.0 |
| 0.319 | 0.184 | +1.0 | +0.0 | +0.0 |
| 0.379 | 0.219 | +2.0 | +0.0 | +0.0 |
| 0.450 | 0.260 | +2.0 | +0.0 | +0.0 |

Radius 0.379 and 0.450 at z 0.200 are the two rows where the model says the plane still bites and
the render says it does not: it predicts 0.05 px and 0.43 px of loss there, both under the one
pixel the measurement can read. That is the model and the instrument agreeing at the limit of the
instrument, not a disagreement.

## What this settles for the height gate

`tools/check-socket-height.py` passes both machines at about +0.031 tiles rather than on the
reference, and its header calls that residual geometric. **It is, and the model predicts it without
being shown it.** The envelope the gate measures is the widest part, the dark rim at radius 0.379:

| | predicted | measured |
|---|---|---|
| drawn centre at SOCKET_Z 0.033 | +0.05509 tiles | +0.055 (the gate) |
| residual against vanilla's pipe at +0.02337 | +0.03172 tiles, 2.030 px | +0.031 (the gate) |
| the same at the old SOCKET_Z 0.044 | +0.03618 tiles, 2.316 px | about 2.28 px (#356) |
| what correcting SOCKET_Z moved it by | 0.286 px | 0.28 px (#356) |
| what the rim's TOP edge moved by | 0.498 px | 0.52 px (#356) |
| what its BOTTOM edge moved by | 0.072 px | 0.03 px (#356) |

So **the +0.031 residual is what it should be**, and #356's puzzle is closed with it: the axis alone
moves 0.498 px when `SOCKET_Z` falls 0.011 tiles — which is the top-edge row of the table, the same
quantity, since the extent above the axis is `r / sin(pitch)` and does not depend on `z` at all —
and the drawn centre moved 0.28 because lowering the axis pushes more of the rim under the plane at
the same time. The last two rows are the same
thing said edge by edge, and they are a prediction the model was not built against: the top rides
with the axis and the bottom barely moves, because the bottom is pinned to where the tube crosses
world z 0 and that point only slides `sqrt(r^2 - z^2)` as `z` changes. The gate's tolerance of 0.08
tiles holds all of this with room to spare and its header already says so.

**It is not a defect and there is nothing here to fix.** The trade that produces it — a socket at
pipe height passing through the plinth — is Truls's and is settled (#362, Not in scope). What was
open was whether anybody could say what the number ought to be, and now it can be said: 0.0317
tiles for a rim of radius 0.379 at z 0.033, and `sqrt(r^2 - z^2) + z/tan(pitch)` for any other.

## What was NOT measured

- **Whether the same cut explains the look complaint.** `models/house-style.md` records a second
  candidate for why the accent band reads proud on top and flush underneath — the lower edge meets
  the slab and the ground shadow, where there is less contrast to read an edge against. Nothing here
  separates that from the geometry; these are alpha measurements and say nothing about contrast.
- **Any radius over 0.45 or any height over 0.55.** The grid is `models/socket-cylinders.py`'s
  `RADII` and `HEIGHTS` and is committed; extending it is an edit to that file and two more renders.
- **Any machine but the two rendered ones**, for the `machine` scene. `--machine`, `--direction`
  and `--fluid` take another; there are only two machines with rendered sheets today.
