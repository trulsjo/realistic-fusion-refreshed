# Whether the shared `get-dump.ps1` can take this repository's base-game dump

Measured 2026-11-16 ([#863](https://github.com/trulsjo/realistic-fusion-refreshed/issues/863)), on
Factorio 2.1.24, tools pin `664cbbb`, at this repository's `main` 745ce31 plus the branch's
commits for #861 and #862, which touch no mod. **It can, and on that tree the dump it took was
byte for byte the one this repository's own `dump-data.ps1` took** (*Measured*), so
`tools/extract-geometry.py` now takes its dump from it and `dump-data.ps1` is deleted. ADR 0007,
*Verification*, says so where it names the old script.

## The question

#863 asked whether `vendor/grado-factorio-tools/scripts/get-dump.ps1`, lifted from the modpack,
can load the three mods here while keeping the base-game-only load ADR 0003 makes the v1 target.
`dump-data.ps1` wrote a mod list with every bundled mod named and disabled, so its dump described
`base` and the three mods alone (*Read from source*: its header, at 745ce31). `get-dump.ps1` takes
a directory of mods and, with no `-With`, enables no bundled mod (*Read from source*: its header's
`-With`, at the pin).

## The runs

Both on the same tree, one after the other, each into a directory of its own under the session's
scratch directory. `dump-data.ps1` was then under `scripts/`, which this change deletes, so its
line names it by `<scripts>`; it is in the tree at 745ce31.

```
pwsh -NoProfile -File <scripts>/dump-data.ps1 -Out <scratch>/dumps/rf-dump.json
pwsh -NoProfile -File vendor/grado-factorio-tools/scripts/get-dump.ps1 . -CacheDirectory <scratch>/dumps/cache
```

*Measured*: both exited 0. The first took 12.5 s and the second 4.1 s, wall clock, as `time`
printed them. `get-dump.ps1` printed `get-dump: made, no dump of this set was in the cache` and
the dump's path. The `.key` it wrote beside the dump:

```
factorio 2.1.24
bundled 
realistic-fusion-refreshed 0.1.0 directory, 61 file(s), 651861 bytes
realistic-fusion-refreshed-assets 0.1.0 directory, 180 file(s), 17648778 bytes
realistic-fusion-refreshed-core 0.1.0 directory, 20 file(s), 85955 bytes
```

So it found exactly the three mods at the root of the repository, and enabled no bundled mod: the
base-game load. *Measured*: both dumps were 14528339 bytes, `cmp` found no difference, and both
had the SHA-256 starting `9f8b4f4e6faec0e87532`.

## What `extract-geometry.py` does with it

Without `--dump` it runs `get-dump.ps1` on the repository root and reads the one `.json` the run
leaves in its cache directory (since #887's review panel).

*Measured*: run twice on 2026-11-16, before that change, for the five machines with a committed
`geometry.json`, it took 5.4 s the first time, whose output was not kept, and 19.3 s the second,
whose was. Each left every one of the five files unchanged, and no temp directory named
`rf-geometry-dump-*` after it. After the change, a run for the five left them unchanged and no
such directory either; its time was not taken. A run for one machine with `--stdout`, which writes
no file, took 39.95 s, by the pre-PR reviewer's account of #887 and not re-run here, with the
review panel's three worktrees open on the machine.

It gives `get-dump.ps1` a fresh temp directory as its cache on every run and removes it after,
rather than the default `.dump-cache` (*Read from source*: `take_dump` in
`tools/extract-geometry.py`). The cache serves a set again when each mod's version, file count and
total bytes match (*Read from source*: the script's header, under WHAT MAKES A SET). An edit to
`entities.lua` that moves a connection from `-1.5` to `-2.5` changes no byte count, so a kept cache
would hand the tool the dump from before it. That is *Inferred* from the header, not measured.

## What this does not say

That the two scripts' dumps agree on any other tree, build or mod set: one tree was dumped once
with each. Nothing about `-With`: no run here enabled a bundled mod.
