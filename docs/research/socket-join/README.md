# Socket join frames

Two sets of screenshots of the same subject — a rendered machine's pipe socket with an ordinary
vanilla pipe plugged into it — both taken by `scripts/probe-socket-height.ps1`, the `#357` pair on
2026-09-15 and `every-side/` on 2026-09-16. They are pictures, not measurements: nothing here
asserts that a socket is right. `tools/check-socket-height.py` is the gate that does, off the
sheets.

## `every-side/` — the reproducible set

Thirteen frames, one pair per plumbable socket plus a shared reference. This is the set to look at.

| machine | side | fluid | seam frame | run frame |
|---|---|---|---|---|
| rf-isotope-collector | west | rf-tritium | `seam-isotope-collector-west-tritium.png` | `run-…` |
| rf-isotope-collector | east | rf-tritium | `seam-isotope-collector-east-tritium.png` | `run-…` |
| rf-isotope-collector | north | rf-helium-3 | `seam-isotope-collector-north-helium-3.png` | `run-…` |
| rf-heat-exchanger | west | water | `seam-heat-exchanger-west-water.png` | `run-…` |
| rf-heat-exchanger | east | water | `seam-heat-exchanger-east-water.png` | `run-…` |
| rf-heat-exchanger | south | steam | `seam-heat-exchanger-south-steam.png` | `run-…` |

A `seam-` frame is at zoom 8 — one tile on 256 px, eight times what a player sees — centred on the
half-tile where the socket stops and the pipe starts, so the machine's own edge is the only other
thing in it. It is four tiles by three for the four side-on sockets and three by four for the two
end-on ones, because the frame turns with its subject: a socket met end-on runs up and down the
screen rather than across it. A `run-` frame is the same socket with a five-tile pipe run
leaving it at zoom 1, which is 32 px to the tile and the size a player meets it at; its size comes
off the machine's own footprint, so the exchanger's fifteen-tile body and the run past it both
fit. `pipe-alone.png` is three tiles of vanilla pipe on the same floor at zoom 8, shot once, as the
reference every seam frame is read against.

The three sockets that are missing from the table are rf-heat-exchanger's reactor-energy
connections. They are contained (ADR 0018), they meet a machine face and never a pipe, and the
probe finds that out by building a pipe on every connection and asking the engine whether it
joined — so they drop out by themselves rather than by being listed here.
`scripts/probe-heat-exchanger-art.ps1` is where they are shown refusing one.

**These frames are reproducible.** Re-run the probe and the bytes match: verified on 2026-09-16 by
two runs into separate directories, all thirteen files identical by sha256. That is what #374
bought, and it is what makes the cheap regression check — diff the pair — possible at all. The
ground is a `lab-dark-2` floor rather than grass for exactly that reason; grass-1 declares its
variants with weighted probabilities, so the engine draws for every tile and no map seed reaches
the draw.

### Three things to look at in them

- **The east socket and the west socket do not read alike**, and the heat exchanger's pair is the
  clearest. On the west frame the stub shows between the machine and the pipe — its blue accent
  band and its dark rim both. On the east frame the pipe's own end cap is drawn over most of it.
  Same geometry, two different pictures.
- **An end-on seam shows no tube at all.** On the collector's north socket the pipe's body covers
  the stub and only the mouth ring shows past it; on the exchanger's south socket the machine's
  body covers the seam and the stub is behind it. Neither frame puts a length of tube beside a
  length of pipe, so neither height nor width can be judged in one. They are kept because what
  they show is what a player actually meets on those sides.
- **The run frames are the ones that decide whether any of it matters.** Zoom 8 is for arguing
  about a quarter of a pixel; zoom 1 is the size the game draws at.

## The `#357` pair — kept, and not reproducible

The files in this directory's own root are a before-and-after pair shot for
[#357](https://github.com/trulsjo/realistic-fusion-refreshed/issues/357), which asked Truls to
accept the re-rendered socket join by eye. The before half comes from a worktree at `e8cdd1c` with
that day's probe copied in, so both halves were shot by the same instrument; `post.py` made the
five montages. #357 is closed, and this is the evidence behind it.

**Re-running the probe does not reproduce them, and cannot.** Two reasons, both structural:

- They were shot on grass, before #374. Two runs of that probe differed on 84.75 per cent of
  `pipe-alone`'s 786,432 pixels on art that had not changed — the grass moved, not the art.
- The frame set itself is gone. #378 replaced `joint-collector.png`, `joint-exchanger.png` and
  `run.png` with one pair per plumbable socket, so today's probe writes different files.

The before half would also need a worktree at `e8cdd1c` again, which is a re-render of superseded
art for a checkpoint that is already closed. So they are left as they are, labelled, rather than
re-shot into something they were never a copy of.
