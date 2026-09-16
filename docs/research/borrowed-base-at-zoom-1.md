# What the accents look like on a screen with a factory on it

Shot 2026-09-17 with `scripts/probe-borrowed-base-art.ps1`, for
[#388](https://github.com/trulsjo/realistic-fusion-refreshed/issues/388). **This note is a probe's
findings.** It decides nothing. Whether any of it supersedes ADR 0034 is Truls's call and this note
does not make it.

**The factory is TimEv's** *Modular 10k SPM Vanilla 2.0 Megabase* — the borrowed base, ADR 0029 and
[`borrowed-base.md`](borrowed-base.md). Every figure below was taken standing inside it, and the
attribution is a community norm rather than a licence obligation.

## Why this exists

ADR 0034 settled #359 on frames of a machine standing still on paved grass, and said so in its own
Consequences: *"It leaves 'at speed' unanswered... Nobody has looked at these accents on a screen
with a factory on it. If that is ever done and the finding differs, this ADR is what it
supersedes."* A rig is flat ground, power, the entities under test and deliberately nothing else,
which is what makes a rig answerable and also what makes it the wrong place to ask this.

## The frames cannot be committed, and that was settled before they were taken

**ADR 0029: the borrowed base "is used locally and never redistributed, and no derivative of it is
either."** A screenshot of somebody's factory is a derivative of that factory. So:

| frame | what it is | committable |
|---|---|---|
| `base-collector-z1.png`, `base-exchanger-z1.png` | our machine inside TimEv's factory | **no** — a derivative of his work |
| `grass-*-z1.png`, `ground-*-z1.png` | our machine on ground this rig paved, on a surface it created | yes — nothing of his is in them |

**None of the six is committed here**, including the controls: they are reproducible in one command
and this note's findings are numbers rather than pictures. The rule that matters is the first row,
and it is why `-OutputDirectory` defaults to a temp directory and nothing in the probe writes into
`docs/`. A tile *name* read off his map — `red-desert-1`, `dirt-4` below — is a fact about
Factorio's terrain generator and not a piece of his factory.

**Nothing was written back.** An art probe needs the graphical client, so the save is loaded rather
than benchmarked — but it is never asked to save, `scripts/art-probe-lib.ps1` writes
`autosave-interval=0`, and the write-data directory is thrown away with the run. The probe paves
nothing and sweeps nothing on his surface, and `place` refuses an overlap rather than making one.

## Where the machines stood

`scripts/probe-borrowed-base-art.ps1` samples 20 000 entities of the player force, counts them by
chunk, and tries the busiest chunks until `can_place_entity` says the machine fits. It clears
nothing to make room.

| machine | at | ground | entities of TimEv's within 20 tiles |
|---|---|---|---:|
| `rf-isotope-collector` | −8607.5, 594.5 | `red-desert-1` | **409** |
| `rf-heat-exchanger` | −8607.5, 614.5 | `dirt-4` | **286** |

Both landed beside rail, locomotives, power poles and pipes. The frames are not of a machine in a
quiet corner.

## The accent's own colour does not change — on seven of eight sockets

Measured with `tools/measure-frame-accents.py` (#387), which puts
`tools/measure-accent-separation.py`'s own window on a frame. Base against matched-terrain control,
same run:

**Seven of the eight measurable sockets give the identical hex in both.** `#a0b8a8`, `#506e5e`,
`#c9a179`, `#8ca8c1`, `#345776` — the factory is not drawn over the band and does not shade it.

**The eighth is drawn over.** The exchanger's east `rf-reactor-energy` band reads `#c38d51` inside
the base against `#c19768` on the control, **4.3 dE00**, with a wobble of 3.7 — so the move is
barely above its own instability and should not be quoted to a decimal. What causes it is not
marginal at all: **a copper power wire runs vertically across that band.**

| | colour | dE00 to the wire |
|---|---|---:|
| the wire | `#c17a11` | — |
| east energy accent, as the control draws it | `#c19768` | **12.2** |
| east energy accent, as the base frame draws it | `#c38d51` | 8.0 |

**The wire is 12.2 dE00 from the energy accent, and the closest two accents on this machine's own
sheet are 11.7 apart.** So vanilla's copper wire is about as near the energy accent as our steam and
water accents are to each other. That is the sharpest thing in this note.

## What the accents have to compete with

Every pixel of each frame outside the machine's own footprint, as one distribution:

| frame | surround | internal spread, median | 90th pct |
|---|---|---:|---:|
| `grass-collector` | `#524610` | 3.5 | 8.2 |
| `ground-collector` (`red-desert-1`) | `#976631` | 3.1 | 7.9 |
| `base-collector` | `#79532d` | **10.3** | **26.4** |
| `grass-exchanger` | `#4f4610` | 3.7 | 12.3 |
| `ground-exchanger` (`dirt-4`) | `#7b542d` | 6.4 | 18.3 |
| `base-exchanger` | `#66492a` | **11.5** | **23.7** |

**A factory background is two to three times as varied as a paved one** — 10.3 against 3.5 and 3.1
for the collector, 11.5 against 3.7 and 6.4 for the exchanger — and its 90th percentile means it
holds colours 23.7 and 26.4 dE00 from its own middle, which is as far as an accent stands from the
background at all. That, rather than any shift in the accent itself, is what "competing with
somebody else's factory" amounts to.

### And the terrain matters more than the clutter does

This is why the probe shoots two controls. Distance from each accent to its surround's median:

| accent | on grass | on the base's own tile | inside the base |
|---|---:|---:|---:|
| collector west, tritium | 46.4 | 35.1 | 41.1 |
| collector east, tritium | 23.0 | 29.0 | 28.0 |
| exchanger west, energy | 40.8 | 28.7 | 35.4 |
| exchanger east, energy | 36.6 | 25.9 | 32.0 |
| exchanger west, water | 50.7 | 41.7 | 44.7 |
| exchanger east, water | 38.1 | 33.4 | 31.0 |

**Every row holds the accent's colour fixed at the control's reading**, so the three columns differ
in the surround and in nothing else. That matters for one cell only: the exchanger's east energy
band is the one the wire is drawn across, and taking its base-frame colour instead would read 29.7
rather than 32.0. Held fixed, the column is about the background; not held fixed, it would mix the
wire into it twice.

**Moving from grass to the base's own dirt costs between 4.7 and 12.1 dE00 on five of the six
accents**, and gains 6.0 on the sixth — the collector's east tritium, which is the darkest accent
here and the one a pale ground helps rather than hurts.

**Adding the factory on top gives roughly half of that back on three of them** — the collector's
west tritium and both of the exchanger's energy sockets, +6.0, +6.7 and +6.1 against losses of 11.3,
12.1 and 10.7 — because the factory's greys and darks pull the surround's median away from the tan
ground the machine is standing on. On the exchanger's west water it gives a third back, +3.0 of 9.0;
and on the other two it takes a little more away, −2.4 and −1.0. So "half" is the shape of it on
half the sockets and not a rule.

A grass control alone would have reported terrain and clutter together and called the sum the
factory's doing, which is the whole reason for the second control.

**Read the middle column as the more useful one.** If these accents are ever a problem, the
evidence here says terrain is the larger part of why — and this project has never looked at a
machine on anything but grass.

## What this does NOT establish

- **It is one spot, in one factory, on one terrain.** Two machines, two chunks of somebody's
  megabase. Nothing here is a survey.
- **A distance to a surround's MEDIAN is a crude proxy for legibility**, and the spread column is
  the reason: a factory background is not one colour, so the eye is not comparing an accent against
  a median. Every figure in the two tables above is a summary of a distribution, and no threshold
  is drawn on any of them.
- **It still does not measure a moving camera or a player under attack.** "At speed" now has its
  screen; it still has no motion. The camera is as still here as it was in
  [`accent-legibility-at-zoom-1.md`](accent-legibility-at-zoom-1.md).
- **It decides nothing about ADR 0034.** The accents are not drawn differently inside a factory;
  what changes is what they stand against, and whether that matters is a judgement.

## Does it differ from `accent-legibility-at-zoom-1.md`?

**On what that note measured, no.** Every accent reads the same colour inside a factory as on a rig,
to the hex, on seven of eight sockets — which is the stronger version of what that note found and
what #387 then measured properly.

**On what it did not measure, yes, in two ways neither note could have seen:** a vanilla power wire
crosses an accent band and is 12.2 dE00 from it, and a machine's ground is worth more contrast than
the factory around it. Both are new, both are numbers, and neither is a decision.
