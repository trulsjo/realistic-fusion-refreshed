# How far apart two fluid accents land at zoom 1

Measured 2026-09-16 for [#379](https://github.com/trulsjo/realistic-fusion-refreshed/issues/379),
which is the measuring half of
[#359](https://github.com/trulsjo/realistic-fusion-refreshed/issues/359). #359 asks whether two
accents on one machine are far enough apart and then asks for a decision; **this note decides
nothing.** It is the figures the decision is waiting on, and the decision stays Truls's. Rerun it
with

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

| pair | palette dE00 | drawn dE00, closest two sockets | palette dE76 | drawn dE76 |
|---|---:|---:|---:|---:|
| helium-3 × tritium | 41.8 | **30.4** | 80.8 | 37.9 |
| energy × water | 45.5 | **10.1** | 93.6 | 10.1 |
| steam × water | 21.4 | **14.9** | 38.0 | 16.3 |
| energy × steam | 29.4 | 18.5 (unstable, below) | 62.9 | 20.9 |

**The drawn figure is never the palette figure and the gap is not a constant**: helium-3 × tritium
keeps 73 per cent of its palette distance, energy × water keeps 22 per cent. Quoting the table would
have over-stated one pair by a factor of four and a half.

**And the two formulas disagree by more on the palette than on the pixels.** For helium-3 × tritium
dE76 calls the palette rows 80.8 apart and dE00 calls them 41.8 — nearly double — while on the
drawn pixels the two agree to within a quarter. dE76 is Euclidean in Lab and over-reports at the
high chroma the palette rows sit at, which is why `tools/colour_distance.py` carries CIEDE2000 and
the extra seventy lines that go with it.

## Method, and the window every figure was read through

Everything below is **at zoom 1 — 32 px to the tile, the size a player meets a machine at**
(`CONTEXT.md`, Zoom). The sheets are drawn at 64 and ship at `scale 0.5`, so each sheet is halved
before anything is measured off it. The halving averages in **linear light with the colour
premultiplied by alpha**, which is what a graphics card filtering an sRGB texture does; averaging
the gamma-encoded bytes darkens every edge instead. [#371](https://github.com/trulsjo/realistic-fusion-refreshed/issues/371)
is what a picture quoted without its zoom costs.

- **Where a band is.** `tools/socket_strip.py` isolates one connection's socket, and the accent
  band's span along the tube comes from `models/rf_blender.py`'s `BAND_BACK` and `BAND_DEPTH` —
  never from columns typed into the tool. Both ends are pulled in by `socket_strip.FILTER_HALF_PX`,
  the width the renderer's reconstruction filter smears an edge, so no column of the window draws
  the flange rib or the port beside it.
- **The colour** is the **median** of the window. A band is a lit cylinder, so its pixels are a
  spread and the mean of a spread moves as soon as one contaminated column joins it.
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
`tools/measure-accent-separation.py`, run on 2026-09-16 against the sheets as they
stand at `0a3dc7b`.

### rf-isotope-collector — the pair #359 is about

| accent | socket | sheet | colour | L\* | a\* | b\* | wobble |
|---|---|---|---|---:|---:|---:|---:|
| helium-3 | north rf-helium-3 | `isotope-collector-e.png` | `#564868` | 33.2 | +13.2 | −16.5 | 1.2 |
| tritium | west rf-tritium | `isotope-collector.png` | `#a5bbaa` | 74.0 | −10.9 | +6.1 | 0.5 |
| tritium | east rf-tritium | `isotope-collector.png` | `#517160` | 44.6 | −15.4 | +5.6 | 0.3 |

**helium-3 × tritium: dE00 30.4 to 47.6** over the two socket pairs. Closest is the north helium-3
against the east tritium; furthest is the same helium-3 against the west tritium.

### rf-heat-exchanger

| accent | socket | sheet | colour | L\* | a\* | b\* | wobble |
|---|---|---|---|---:|---:|---:|---:|
| energy | west rf-reactor-energy | `heat-exchanger.png` | `#afa596` | 68.3 | +0.8 | +9.4 | 6.7 |
| energy | north rf-reactor-energy | `heat-exchanger-e.png` | `#43413f` | 27.8 | +0.3 | +1.7 | 6.5 |
| energy | east rf-reactor-energy | `heat-exchanger.png` | `#c29768` | 65.5 | +10.0 | +30.9 | 0.7 |
| steam | south steam | `heat-exchanger-e.png` | `#757a7c` | 50.7 | −1.3 | −1.8 | 12.4 |
| water | west water | `heat-exchanger.png` | `#9aa49f` | 66.4 | −4.6 | +1.1 | 2.4 |
| water | east water | `heat-exchanger.png` | `#345778` | 35.8 | −2.4 | −22.3 | 0.3 |

| pair | dE00, closest | dE00, furthest |
|---|---:|---:|
| energy × water | 10.1 | 45.1 |
| steam × water | 14.9 | 19.1 |
| energy × steam | 18.5 — **unstable** | 25.5 |

**energy × steam is refused, not reported.** The west energy band wobbles 6.7 dE00 and the south
steam band 12.4; between them that is 19.1, which is not smaller than the 18.5 the two medians are
apart. The number would be the window moving, not the accents parting.

## Three things the numbers say

**1. The face a socket is on moves its colour as far as the accent does, and on one machine
further.** The sun is fixed and
the camera turns, so one accent is lit two ways on one machine:

| accent | how far its own sockets land apart, dE00 |
|---|---|
| tritium, 2 sockets | 26.3 |
| water, 2 sockets | 34.7 |
| energy, 3 sockets | 13.1 to 40.7 |

On `rf-heat-exchanger` the **closest energy-to-water** pair is 10.1 dE00 and the **closest
energy-to-energy** pair across two faces is 13.1. Two different accents on the same face are closer
together than one accent is to itself on two faces. On `rf-isotope-collector`, tritium spans 26.3
across its own two sockets against the 30.4 that separates it from helium-3 at their closest.

**2. A band is half-lit, and the shadow half is near-neutral.** Reading the steam band column by
column along its own span — the six zoom-1 columns 102..107 of `heat-exchanger-e.png` — its
median L\* runs 71.0, 76.0, 75.9, 49.4, 32.3, 29.9, and the inboard end
falls into shadow and loses nearly all its chroma. That is what the large wobbles above are: a real
gradient, not an instrument fault. Every median in this note is a summary of such a gradient.

**3. Every band gets the same amount of screen, and it is small.**

| socket kind | band, at zoom 1 | area |
|---|---|---:|
| plumbable, tube radius 0.249 | 7.04 × 22.0 px | 154.9 px² |
| contained, tube radius 0.3 | 7.04 × 27.0 px | 190.1 px² |

The width is `BAND_DEPTH` — 0.22 tiles — and so is the same on every machine; the height is the
band's drawn silhouette, taller on a contained socket because it is drawn thicker. **Seven screen
pixels of width** is the whole of what an accent gets along the tube.

The area is a product rather than a pixel count, and that is deliberate. The band starts 0.17 tiles
back from the socket's mouth while the outboard strip is only 0.25 tiles deep, so **more than half
of every band lies inboard of the collision edge**, where the machine's own body is behind it and
alpha can no longer say where the band stops. Colour still can: on the collector's west socket the
green runs to sheet column 216 and column 217 reads grey, which is where `BAND_BACK` and
`BAND_DEPTH` put the back of the band — 216.96.

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
band, moving a palette colour, or turning any of this into a gate. Those are #359's, and
`CLAUDE.md` reserves them for Truls.

## Self-check

`tools/colour_distance.py` is graded against a published test set rather than against this
repository: `tools/test_colour_distance.py` runs all thirty-four pairs of Sharma, Wu and Dalal's
supplementary test data (*Color Research and Application* 30(1), 2005, Table 1) to four decimals,
plus the sRGB-to-Lab anchors and the transfer function's round trip.

```
python tools/test_colour_distance.py
```

The bench's own arithmetic is pinned separately, by `tools/test_measure_accent_separation.py`: the
halved window's off-by-one, and the halving being done in light rather than in gamma-encoded bytes.
Both are cases where a wrong answer is still a plausible colour, which is why each is asserted
against a case where the right answer and the likely wrong one differ visibly.

```
python tools/test_measure_accent_separation.py
```
