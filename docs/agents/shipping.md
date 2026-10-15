# Shipping: the packer and the locale check

The commands for building the zips and for the locale check, which no gate runner starts. Both
tools are `vendor/grado-factorio-tools`'s. This was two paragraphs of the root `CLAUDE.md`'s State
section until 2026-10-15 (#709).

**The packer is not this repository's.** Since #466 it is
`vendor/grado-factorio-tools/scripts/pack-mods.ps1`, and this repository's own copy is gone. It has
no default mod list and no default output directory, so building the zips by hand names all three:

```
pwsh -File vendor/grado-factorio-tools/scripts/pack-mods.ps1 -OutputDirectory dist `
    realistic-fusion-refreshed-assets realistic-fusion-refreshed-core realistic-fusion-refreshed
```

It deletes any other version's zip of the same mod in the output directory, which the old script
did not.

**Nor is the locale check.** Since #677 it is
`vendor/grado-factorio-tools/scripts/locale-check.ps1`, and this repository's own copy is gone. It
is handed the mods and the prefix that marks a prototype as this repository's, and this command is
the one place the repository says either to it. No gate runner starts it: run it by hand before
anything ships, once as below and once with `-With space-age`.

```
pwsh -File vendor/grado-factorio-tools/scripts/locale-check.ps1 -Prefix rf- `
    realistic-fusion-refreshed-assets realistic-fusion-refreshed-core realistic-fusion-refreshed
```
