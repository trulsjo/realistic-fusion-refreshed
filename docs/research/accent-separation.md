# How far apart two fluid accents land at zoom 1

Measured 2026-09-16 for [#379](https://github.com/trulsjo/realistic-fusion-refreshed/issues/379),
which is the measuring half of
[#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359). #359 asked whether two
accents on one machine are far enough apart and then asked for a decision; **this note decides
nothing**, which is the property it was written to have and still has.

**The decision has since been taken, and it moved nothing here.** Truls settled #359 on 2026-09-16:
the standard is [ADR 0034](../adr/0034-an-accent-is-read-against-its-neighbour.md) and the rule is
in `models/house-style.md`'s Palette. No colour and no geometry changed, so every figure below
stands as measured. What the decision was taken on is a second note,
`docs/research/accent-legibility-at-zoom-1.md`, which photographs both machines in a real map — so
this note says what the sheet holds and that one says what a player is shown. **Read this one for a
distance and that one for a look**; its own figures come off a hand-placed hue cut and are not a
second opinion on the table below.

Rerun this note's measurements with

```
python tools/measure-accent-separation.py --de76
```

`tools/measure-accent-separation.py` is a **bench** in this repository's sense (`CONTEXT.md`,
Measurement words): it measures a quantity, reports it, and asserts only its own validity. No gate
runs it, `scripts/load-check.ps1` and `scripts/ship-check.ps1` do not know it exists, and nothing
fails because of it. It reads the committed sheets under
`realistic-fusion-refreshed-assets/graphics/rendered/` and needs no game, no Blender and no render.

## The question

`models/house-style.md`'s Palette makes an accent load-bearing — *"the accents say what a socket
carries"* — and refuses hazard yellow as a fluid accent on those grounds. It already flags one pair
in prose: *"Helium-3's violet is near the plasma accent — 0.80 0.45 1.00 against 0.55 0.20 1.00 —
which the isotope collector does not have to resolve, since it carries no plasma. A machine that
carries both will."*

`scripts/ship-check.ps1` section 8 holds each fluid-derived accent against the fluid's own colour
across three copies, so the colours cannot drift. Nothing anywhere measured how far apart they
**land**, or how many pixels each one gets once the sheet is drawn and halved.

## The trap: the palette is not the answer

The Palette table is **linear RGB fed to Blender**. AgX and the lighting spend most of the
separation before a player sees any of it, so a figure quoted off the table answers a different
question from the one #359 asks.

Both halves of the table below are CIEDE2000 over CIE L\*a\*b\* under D65. The palette half converts
each linear row to sRGB first — `colour_distance.linear_to_srgb` then `colour_distance.srgb_to_lab`
— because the rows are linear and `srgb_to_lab` expects encoded sRGB; skipping that step is the
second way to get this wrong.

| pair | palette dE00 | drawn dE00, closest two sockets | palette dE76 | drawn dE76 | dE76/dE00, palette | dE76/dE00, drawn |
|---|---:|---:|---:|---:|---:|---:|
| helium-3 × tritium | 41.8 | **30.0** | 80.8 | 37.8 | 1.93 | 1.26 |
| energy × water | 45.5 | **29.2** | 93.6 | 42.3 | 2.06 | 1.45 |
| steam × water | 21.4 | **11.2** | 38.0 | 15.0 | 1.78 | 1.34 |
| energy × steam | 29.4 | **19.3** | 62.9 | 29.0 | 2.14 | 1.50 |

The last two columns are the first four divided, and they are there because the first version of
this note quoted them as ranges a reader had to trust — "1.8 to 2.1" and "1.3 or less", the second
of which was true of one pair in four. The review of #381 caught it. A figure that is a division of
two others in the same table belongs in the table.

**The drawn figure is never the palette figure**: each pair keeps between 52 and 72 per cent of its
palette distance, so quoting the table over-states a pair by between a third and a factor of two.
The gap is not a constant either, so no single correction recovers it — `steam × water` loses
nearly half while `helium-3 × tritium` loses barely a quarter.

**And the two formulas disagree by more on the palette than on the pixels.** dE76 calls the palette
rows 1.78 to 2.14 times as far apart as dE00 does, and the drawn pixels 1.26 to 1.50 -- every
palette figure above every drawn one, pair by pair.
dE76 is Euclidean in Lab, and it does not divide a chroma difference down as the chroma rises, so
it parts company with the eye most at the high chroma the palette rows sit at and least at the
chroma that survives to the sheet. That is why `tools/colour_distance.py` carries CIEDE2000 and the
extra seventy lines that go with it.

## Method, and the window every figure was read through

Everything below is **at zoom 1 — 32 px to the tile, the size a player meets a machine at**
(`CONTEXT.md`, Zoom). The sheets are drawn at 64 and ship at `scale 0.5`, so each sheet is halved
before anything is measured off it. The halving averages in **linear light with the colour
premultiplied by alpha**, which is what a graphics card filtering an sRGB texture does; averaging
the gamma-encoded bytes darkens every edge instead.
[#371](https://github.com/trulsjo/realistic-fusion-refreshed/issues/371) is what a picture quoted
without its zoom costs.

- **Where a band starts.** `tools/socket_strip.py` isolates one connection's socket, and the accent
  band's front edge comes from `models/rf_blender.py`'s `BAND_BACK` and `BAND_DEPTH` — never from
  columns typed into the tool. Every boundary is pulled in by `socket_strip.FILTER_HALF_PX`, the
  width the renderer's reconstruction filter smears an edge, so no column of a window draws the
  flange rib beside it.
- **Where a band ENDS is measured, not assumed, and this is the thing the first version of this
  bench got wrong.** A band is 0.22 tiles long and starts 0.17 tiles back from the socket's mouth,
  while the outboard strip is only 0.25 tiles deep — so most of every band lies inboard of the
  collision edge, and what the sheet draws there is whichever of the band and the machine's own
  body is nearer the camera. On `rf-isotope-collector`'s west socket it is the band, green to
  within a tenth of a pixel of where the geometry puts its back. On `rf-heat-exchanger`'s west
  socket it is the body, from four columns in. So each column is classified between two colours the
  sheet itself supplies — the band, read outboard of the footprint where only the socket can be
  drawn, and the machine, read past the band's back edge where the band is guaranteed absent — and
  joins the run only while it is nearer the first. Nearest-of-two between two measured references,
  so no threshold.
- **The colour** is the **median** of the run. A band is a lit cylinder, so its pixels are a spread
  and the mean of a spread moves as soon as one contaminated column joins it.
- **The wobble** is how far that median moves, in dE00, under the worst of four one-step narrowings
  — one column off each end, one row off each. It is printed beside every colour, and a pair whose
  two accents are no further apart than their two wobbles added is **reported unstable rather than
  returned**. That is a comparison between two measured quantities; there is no threshold in the
  tool, because a threshold on legibility would be a decision wearing a check's clothes.
- **The pairs are derived**, from each machine's connections through `rf_blender.ACCENT_OF_FLUID`.
  A connection with no fluid falls back to its `connection_category`, which is how
  `rf-aneutronic-reactor`'s plasma faces — recorded `fluid: null` — reach the plasma accent.

## What the sheets draw

Two machines have sheets. Everything in this section is off
`tools/measure-accent-separation.py`, run on 2026-09-16 against the sheets as they stand at
`0a3dc7b`. `w × h` is how much accent the sheet actually draws at zoom 1, in screen pixels, and it
is a **floor**: the run is trimmed at the mouth end by the filter guard, so about a pixel of band
that is certainly drawn is outside every window here.

### rf-isotope-collector — the pair #359 is about

| accent | socket | sheet | colour | L\* | a\* | b\* | wobble | w × h | area ≥ |
|---|---|---|---|---:|---:|---:|---:|---|---:|
| helium-3 | north rf-helium-3 | `isotope-collector-e.png` | `#594b6d` | 34.5 | +13.1 | −17.1 | 1.2 | 5.0 × 22.0 | 110.0 |
| tritium | west rf-tritium | `isotope-collector.png` | `#a5bbaa` | 74.0 | −10.9 | +6.1 | 0.5 | 6.0 × 22.0 | 132.0 |
| tritium | east rf-tritium | `isotope-collector.png` | `#517160` | 44.6 | −15.4 | +5.6 | 0.3 | 6.0 × 22.0 | 132.0 |

**helium-3 × tritium: dE00 30.0 to 46.3** over the two socket pairs. Closest is the north helium-3
against the east tritium; furthest is the same helium-3 against the west tritium. Both tritium
bands run their whole built span; the helium-3 one stops short, where the machine's body comes in
front of it.

### rf-heat-exchanger

| accent | socket | sheet | colour | L\* | a\* | b\* | wobble | w × h | area ≥ |
|---|---|---|---|---:|---:|---:|---:|---|---:|
| energy | west rf-reactor-energy | `heat-exchanger.png` | `#caa27b` | 69.2 | +9.7 | +25.5 | 0.9 | 3.0 × 27.0 | 81.0 |
| energy | north rf-reactor-energy | `heat-exchanger-e.png` | `#684925` | 33.7 | +8.8 | +26.6 | 1.0 | 2.0 × 27.0 | 54.0 |
| energy | east rf-reactor-energy | `heat-exchanger.png` | `#c29768` | 65.5 | +10.0 | +30.9 | 0.7 | 6.0 × 27.0 | 162.0 |
| steam | south steam | `heat-exchanger-e.png` | `#b6b8ba` | 74.7 | −0.4 | −1.1 | 1.0 | 3.5 × 22.0 | 77.0 |
| water | west water | `heat-exchanger.png` | `#92acc3` | 69.2 | −3.8 | −14.6 | 2.0 | 2.0 × 22.0 | 44.0 |
| water | east water | `heat-exchanger.png` | `#345778` | 35.8 | −2.4 | −22.3 | 0.3 | 6.0 × 22.0 | 132.0 |

| pair | dE00, closest | dE00, furthest |
|---|---:|---:|
| steam × water | 11.2 | 39.2 |
| energy × steam | 19.3 | 43.6 |
| energy × water | 29.2 | 45.9 |

No pair on either machine is refused: every wobble is at or under 2.0 dE00, and the closest pair is
11.2 apart.

## Three things the numbers say

**1. Four of the heat exchanger's six bands are cut short by the machine's own body, and two of
them get a third of the screen the widest ones do.**

| socket | accent it draws, at zoom 1 |
|---|---|
| north rf-reactor-energy | 2.0 px |
| west water | 2.0 px |
| west rf-reactor-energy | 3.0 px |
| south steam | 3.5 px |
| east rf-reactor-energy, east water | 6.0 px, the whole run |

On `rf-isotope-collector` only the north helium-3 socket loses any, at 5.0 px against the two
tritium sockets' 6.0. **Two screen pixels of accent** is what a player gets on the exchanger's north
energy and west water sockets. Nothing here says whether that is enough; it says how much there is.

**2. The same accent on two sockets of one machine lands anywhere from 4 to 35 dE00 apart.**

| accent | socket pair | dE00 |
|---|---|---:|
| energy | west vs east | 3.9 |
| tritium | west vs east | 26.3 |
| energy | north vs east | 31.8 |
| water | west vs east | 33.0 |
| energy | west vs north | 35.3 |

On `rf-heat-exchanger` water's own two sockets land **33.0** apart — further than the **29.2** that
separates energy from water at their closest. The compass face is not the whole story: the two
energy sockets on the same sheet are 3.9 apart while the two water sockets on that same sheet are
33.0. The water sockets are plumbable and sit low at `rf_blender.SOCKET_Z`, where the machine shades
the eastern one; the energy sockets are contained and stand at 0.55 in the open.

**3. The bands are narrow, and much taller than they are wide.** A band is 0.22 tiles along the
tube, which is 7.04 screen px at zoom 1 before anything occludes it, against a drawn height of 22.0
px on a plumbable socket and 27.0 on a contained one — the contained sockets are drawn at tube
radius 0.3 against 0.249, so they are taller. The height is the same in every column of every run,
which is what a cylinder's silhouette does, and which is what lets the area be a product rather than
a count: once the band and the machine's body overlap, no alpha count can tell them apart.

## The pairs that cannot be measured yet

**One pair on a machine that has a geometry file and no sheets:**

| machine | pair | why not |
|---|---|---|
| `rf-aneutronic-reactor` | energy × plasma | not rendered |

`rf-direct-energy-converter` carries one accent and `rf-lithium-blanket` carries no fluid at all, so
neither can hold a pair.

**And the entities the bench cannot reach at all.** It reads `models/<machine>/geometry.json`,
because that file is where a connection's fluid is recorded without starting the game, and five of
the thirteen entities have one. The other eight were read out of
`realistic-fusion-refreshed/prototypes/entities.lua` **by hand for this note** and are listed here
so the day one gets a sheet nobody has to rediscover it:

| entity | accents it carries | pairs |
|---|---|---|
| `rf-reactor` | plasma in, energy out | energy × plasma |
| `rf-hc-exchanger` | water, steam, energy | energy × steam, energy × water, steam × water |
| `rf-hc-turbine` | steam | none |
| `rf-aneutronic-composite-tank` | plasma | none |
| `rf-pipe`, `rf-pipe-to-ground`, `rf-pump` | plasma | none |
| `rf-heater` | plasma out; **its inputs name no fluid** | cannot be derived |

Two of those are worth a sentence each. `rf-heater`'s input boxes are a chemical plant's, unfiltered
and uncontained, so what flows in them is whatever recipe is set — no fluid name, no
`connection_category`, and nothing that says which accent a socket there would carry. It wears
Krastorio 2's sprites and has no band to measure, so the gap costs nothing today. And **plasma
appears in six of these eight and in no rendered sheet**, which is why the pair
`models/house-style.md` actually flags in prose — helium-3's violet against plasma's — appears
**nowhere in this survey**: no entity carries both, so the pair is on no machine's list above.
The clash the house style warns about is a warning about a machine nobody has built.

Run `python tools/extract-geometry.py rf-reactor` (it needs the game, or a dump) and that machine's
pairs appear in the bench's own output instead of in this table.

## What this note does not do

It does not say whether any figure above is far enough apart. It does not propose lengthening a
band, moving a palette colour, or turning any of this into a gate. Those were #359's, and
`CLAUDE.md` reserves them for Truls. He settled them on 2026-09-16 and changed nothing here — see
the head of this note, which says where the decision and its evidence live.

## Self-check

`tools/colour_distance.py` is graded against a published test set rather than against this
repository: `tools/test_colour_distance.py` runs all thirty-four pairs of Sharma, Wu and Dalal's
supplementary test data (*Color Research and Application* 30(1), 2005, Table 1) to four decimals,
plus the sRGB-to-Lab anchors and the transfer function's round trip.

```
python tools/test_colour_distance.py
```

The bench's own arithmetic is pinned separately, by `tools/test_measure_accent_separation.py`: the
halved window's off-by-one, the filter guard's own off-by-one at a boundary, and the halving being
done in light rather than in gamma-encoded bytes. All three are cases where a wrong answer is still
a plausible colour, which is why each is asserted against a case where the right answer and the
likely wrong one differ visibly. It also runs the bench over both machines and requires four of the
heat exchanger's six sockets to report stopping short of the band's back edge, which is the
defect the review of #379 found and is the one thing here that cannot be caught by reading.

```
python tools/test_measure_accent_separation.py
```
