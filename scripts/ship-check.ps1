<#
.SYNOPSIS
    Fails if the claims the shipped mods make about themselves have stopped being true, if the
    scripts in this directory have stopped answering Get-Help, if any prose cites one of our own
    files by line number, if an accent named for a fluid has stopped being that fluid's colour,
    or if a docs/ note this repo cites
    is not there to be read.

.DESCRIPTION
    ADR 0003 and ADR 0006 each create an obligation that is a sentence rather than code: the clean
    break from predecessor saves must be "stated plainly wherever players will look", and the quality
    interaction must be "a named known-gap, not a silent one". Issue #35 discharged both. Nothing else
    in this repository would notice if they were edited away, because neither is a prototype, a name
    or a number -- load-check, locale-check and name-check all pass on a mod that says nothing at all.

    So this check is deliberately about prose and files, and it needs no Factorio. Since ADR 0023
    it also covers one claim that is a number rather than a sentence -- the assets dependency floor --
    because that one has the same shape: nothing else here would notice it going stale, and the cost
    of it going stale is a player's game refusing to load. It asserts:

      - LICENSE, LICENSE.GPL and legal-note.txt ship inside each mod, not only at the repo root, and
        each mod's legal-note.txt still ends with the root one verbatim, behind a preamble saying
        where it came from. Three copies of a file is three chances to drift; this is what makes
        the copies safe.
      - Each mod's info.json description and its English [mod-description] agree. They are duplicated
        because Factorio reads one before the locale loads and the other after, and a player sees
        whichever the moment supplies -- so the two saying different things is the failure that would
        never be noticed.
      - The two CODE mods' descriptions, and README.md, carry the clean break and the quality gap.
        The assets mod is exempt from those two and from nothing else: it ships no prototype, so
        "saves are not supported" and "not balanced for quality" would be claims about nothing. It is
        NOT exempt from the licence files, the description match or the credits -- it is the mod that
        actually carries the Krastorio 2 art, so it is the one that most needs them (ADR 0023).
      - Romner_set, Durikkan and PreLeyZero are credited, in all three.  No licence asks for it (see
        CLAUDE.md); it is a community norm, which is exactly the kind of thing that quietly
        disappears in an edit.
      - Each code mod's declared floor on realistic-fusion-refreshed-assets equals the version that
        mod actually declares, and no .png is left behind in a code mod. Both guard the split ADR 0023
        made, and neither can fail on this machine: art paths resolve against whatever assets version
        the PLAYER has, while the dev loop junctions the current one.

        WHAT THE FLOOR ASSERT DOES NOT COVER, stated because the first version of this comment
        claimed more than it delivered. It catches a version bumped without the floor following. It
        does NOT catch the likelier mistake: adding a sprite and the code that names it while
        leaving the assets version alone. Floor and version still agree, so this passes; the freshly
        built zip has the file, so load-check passes; and a player already holding that same assets
        version satisfies the floor, never re-downloads, and gets the missing-file error anyway.
        Nothing here can see that, because nothing here knows what a player already has -- it needs
        a rule about bumping the assets version whenever its content changes, which is deliberately
        not built while the mod is unpublished. Tracked separately; do not read a pass here as
        cover for it.

    Since #303 the citation check in section 7 covers two of the three shapes ADR 0032 names -- a
    path with a line number on it, and a bare `:155` continuation inheriting the path named earlier
    on the same line. It reads every tracked .md, .lua, .ps1, .py and .js, which is wider than the
    rest of this script, because ADR 0032 binds our own comments as well as docs/.

    Since #334 it also asserts that the two accents taken from a fluid's own colour still carry it.
    Three files type the same RGB triple -- the Core mod's prototypes/fluids.lua, the palette table
    in models/house-style.md and the PALETTE of each build script -- and nothing else in this
    repository types a FLUID's colour at all, so a recolour of rf-tritium or rf-helium-3 would leave
    every rendered socket disagreeing with the pipe it feeds while every gate still passed. Other
    colours are typed in several places (rf_blender.py's icon backdrop, make-mockup-art.ps1's
    per-connection palette) and are nobody's copy of anything, so they are out of scope. Which
    accents are in scope is derived rather than listed; section 8 says how, and why the four role
    accents are not among them.

    Since #183 it also asserts that every docs/ path cited anywhere in scripts/ or docs/ resolves
    to a file that exists. Two notes were researched, written and committed for #158 and #159, and
    never merged; three files on main cited them, both tickets read as completed, and the findings
    could not be opened. The citing line is a comment or a markdown link, so no parser reads it,
    and an unmerged branch looks merged from everywhere except `git merge-base`.

    Since #151 it also asserts one thing that is not about the mods at all: that every script in
    scripts/ which declares a .SYNOPSIS actually answers Get-Help. It lives here because it is the
    same shape as everything above -- a claim made in prose, invisible to every other gate, and
    checkable without starting a game. Twenty-seven scripts had a #Requires line above their help
    block, which detaches it: PowerShell synthesised syntax-only help and the reasoning in the block
    was unreachable, while the file read exactly the same. Nothing but an assert can see that --
    including the second half of the same trap, which the first fix for it walked into: sitting
    directly against the block's closing delimiter, the requires statement is absorbed into the
    last section and rendered back to the reader as help prose. It needs a blank line between
    the two. (Spelling that delimiter out here would end this block early, which is its own
    small demonstration of how literally the parser reads these.)

    WHAT IT CANNOT CHECK

    That the sentences are true, or that a player reads them. It matches on the load-bearing words --
    the predecessors by name, "not supported", "quality" -- so a rewrite that keeps the meaning passes
    and a deletion does not. A rewrite that keeps the words and loses the meaning also passes, and
    there is no version of this check that would not.

    Nor does it look at the mod portal, where the long description lives outside the zip. That copy is
    uploaded by hand and this repository cannot see it.

    Section 7 cannot see ADR 0032's third shape -- "lines 196-197, 204, 208, 227, and 576-578"
    written out in running prose. There is no handle in that a regex can trust, and a pattern loose
    enough for it fires on every ADR quoting a predecessor by line. #302 found five of those by
    reading, and reading is what will find the next. It also cannot see a continuation whose path
    sits on an earlier line than the `:155` itself, nor an unbackticked one, both for the same
    reason: the alternative attributes citations to files nobody named. The section comment carries
    the measurements.

    It also cannot judge whether a symbol is the RIGHT symbol, and that is ADR 0032's bet rather
    than a shortfall: a wrong name greps to nothing and a reader notices, where a number landing two
    lines off reads as correct. Two citations merged in #306 that neither half of this could see --
    one naming the wrong field, one quoting a fragment that greps to nothing -- so read that bet as
    a bet.

    -SelfTest here does NOT re-prove sections 1 to 8, unlike the checks that read a Factorio dump.
    Those need one because they can pass by finding nothing; sections 1 to 4 name every file and
    string they require, so a mistake in them fails rather than goes quiet. What it proves is the
    shared self-test runner in factorio-lib.ps1, which every other gate's -SelfTest now calls: a
    runner that skipped a half, or counted one it never ran, would report a clean pass over a gate
    that did not execute, in all of them at once. It lives here because this gate starts no game.

    SECTIONS 5 TO 9 ARE THE EXCEPTION, and are stated here rather than left to be discovered.
    Each selects by scanning and matching a predicate, so each is exactly the shape that can pass by
    finding nothing. What stands in for a self-test is a floor: section 5 fails when a script opens
    with a comment block but is not in scope, sections 6 and 7 fail when they find too few
    citations to believe -- section 7 twice over, once per shape it matches -- and section 8 carries
    four: one on each of the three things it scans, and one on the pairing between two of them. That is narrower than a -SelfTest would be, because a floor
    cannot see a mistake in the scan itself -- break that and there is nothing left to check and so
    nothing left to fail.

    SECTION 9 HAS NO FLOOR AND A -SelfTest INSTEAD (#416), because there is no count to hold it to:
    prose that cites a self-test half by ordinal should be absent, and after #411 through #415 it is,
    so a floor would have to be zero and would prove nothing. Two halves stand in for it, one per
    direction: a planted document citing halves by ordinal five ways must be caught with its file
    and line, and one naming its halves -- beside a measurement that follows the same word -- must
    not be flagged. The second matters as much: a gate that fires on the sentences the rule asks
    people to write is a gate that gets switched off. What section 9 cannot see is written out above
    the section, not here: a citation in a trailing comment after code, the ways English points at a
    half without the word, and any file outside the tracked list.

    SECTION 10 HAS BOTH (#616). It reads the `## Current figures` table at the top of a research
    note and fails a row whose Section link names no heading of that file, or whose figure is
    written nowhere below the table. A floor holds the number of tables it found, because it finds
    the notes by scanning; and the figure-anchor-resolves and figure-value-in-note halves each plant
    a loose row beside a good one. It cannot tell whether a row is the figure the note currently
    stands behind; the section comment has the rest of what it cannot see.

    SECTION 11 HAS BOTH AS WELL (#649). It reads every table in the tracked markdown and fails a
    delimiter row or a body row whose cell count is not its header's, which is the part of how a
    table renders on GitHub that can be checked without a browser. Since #652 it reads a table
    inside a blockquote as well, and fails a row there that has lost its `>`. A floor holds the
    number of tables it found, and the table-row-cells-caught, quoted-table-caught and
    table-shape-not-flagged halves plant the shapes it must and must not report. It cannot see a
    table that has no delimiter row; the section comment has the rest.

    SECTION 8 CARRIES ITS OWN, which is the one thing a floor cannot do: it exercises
    Test-SameColour on a known-equal and a known-unequal pair on every run, so a comparison that
    stopped saying no fails rather than turning every check below it green. It was also demonstrated
    by hand on 2026-09-13 (#334), five ways: recolouring rf-tritium in the Core mod failed the
    palette row AND the build script; recolouring either of those alone failed that one by name;
    renaming a build script's PALETTE key failed it for having no entry; and breaking
    Test-SameColour itself failed the pair above.

.PARAMETER SelfTest
    Run the checks as usual, then prove four things a green run cannot: the shared -SelfTest runner
    in factorio-lib.ps1 -- that it numbers halves from the list it was given and refuses a half it
    cannot show ran -- section 9, in both directions, section 10's two assertions, each in both
    directions, and section 11, in both directions and inside a blockquote, all on documents planted in a temporary directory. Nothing here plants anything in the repository; the runner's cases are built in
    memory and the planted documents live in the scratch directory the run removes on its way out.

.EXAMPLE
    pwsh -File scripts/ship-check.ps1

.EXAMPLE
    pwsh -File scripts/ship-check.ps1 -SelfTest
#>

#Requires -Version 7

param(
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/factorio-lib.ps1"   # starts no game, but the library sources the harness submodule.

$mods      = Get-RepoMods
$assetsMod = 'realistic-fusion-refreshed-assets'
# Every mod that ships a prototype, which is every mod that can make a claim about a save.
$codeMods  = @($mods | Where-Object { $_ -ne $assetsMod })

$failures = [System.Collections.Generic.List[string]]::new()
$checks   = 0

function Test-Claim {
    param([string] $Where, [string] $Text, [hashtable] $Needles)

    foreach ($what in $Needles.Keys | Sort-Object) {
        $script:checks++
        # Any one of the alternatives satisfies the claim, so a rewrite that says the same thing a
        # different way is not a failure.
        $hit = @($Needles[$what]) | Where-Object { $Text -match [regex]::Escape($_) }
        if (-not $hit) {
            $wanted = (@($Needles[$what]) | ForEach-Object { "'$_'" }) -join ', '
            $script:failures.Add("$Where does not state ${what}: none of $wanted")
        }
    }
}

# What every player-facing surface has to carry. The alternatives exist so that the wording can be
# improved without this check having to be edited in the same commit -- which is how a check like
# this ends up being edited to match whatever the code now says.
$CLAIMS = @{
    'the clean break'  = @('are NOT supported', 'are not supported')
    'which predecessors' = @('Realistic Fusion Power')
    'the quality gap'  = @('NOT balanced for quality', 'not balanced for quality')
}

# Kept apart from $CLAIMS because the two sets have different scope. The claims above are about what
# a mod does to a save, which the assets mod does not do; these are about whose work this is built
# on, which is truest of the mod that holds the art.
$CREDITS = @{
    'credit to Romner_set'  = @('Romner_set')
    'credit to Durikkan'    = @('Durikkan')
    'credit to PreLeyZero'  = @('PreLeyZero')
}

$rootNote = Join-Path $repoRoot 'legal-note.txt'
if (-not (Test-Path $rootNote)) { throw "no legal-note.txt at the repo root: $rootNote" }
$rootText = [IO.File]::ReadAllText($rootNote)

foreach ($mod in $mods) {
    $modDir = Join-Path $repoRoot $mod
    if (-not (Test-Path $modDir)) { throw "no such mod directory: $modDir" }

    # 1. The licence and the scope rule ship with the mod, not only with the repository.
    foreach ($file in 'LICENSE', 'LICENSE.GPL', 'legal-note.txt') {
        $checks++
        $path = Join-Path $modDir $file
        if (-not (Test-Path $path)) { $failures.Add("$mod does not ship $file") }
    }

    # The shipped copy is the root note verbatim behind a preamble, rather than a byte-identical
    # copy, because the root note says "this repository" and cites an ADR path -- neither of which
    # is in the zip a player unpacks, and the mod description now sends them to this file. The
    # preamble resolves both. What is asserted is that the note itself is unaltered underneath it:
    # three copies of a file is three chances to drift, and this is what makes the copies safe.
    $checks++
    $modNote = Join-Path $modDir 'legal-note.txt'
    if (Test-Path $modNote) {
        $modText = [IO.File]::ReadAllText($modNote)
        if (-not $modText.EndsWith($rootText)) {
            $failures.Add("$mod/legal-note.txt no longer ends with the root legal-note.txt verbatim")
        }
        $checks++
        if ($modText.Length -eq $rootText.Length) {
            $failures.Add("$mod/legal-note.txt has no preamble saying which repository it came from")
        }
    }

    # 2. The two descriptions a player can be shown agree with each other.
    $info = Get-Content (Join-Path $modDir 'info.json') -Raw | ConvertFrom-Json
    $cfg  = Get-Content (Join-Path $modDir 'locale/en/mod.cfg') -Raw

    # The entry is read out of its own section, and the section name is checked, because neither is
    # implied by anything else here. Under a misspelled header the file still parses, every needle
    # below still matches, and the player is shown "Unknown key: mod-description.<mod>". And the
    # same key appears under [mod-name] one line earlier, so a search across the whole file would
    # have to tell the two apart by their values -- both of which begin "Realistic Fusion
    # Refreshed". Verified against Factorio 2.0.77 that [mod-description] is the header the game
    # reads and that a backslash-n in the value arrives as a paragraph break.
    $lines  = $cfg -split "`r?`n"
    $header = [array]::IndexOf($lines, '[mod-description]')
    $checks++
    if ($header -lt 0) {
        $failures.Add("$mod/locale/en/mod.cfg has no [mod-description] section header")
    }

    $line = $null
    for ($i = $header + 1; $header -ge 0 -and $i -lt $lines.Count -and $lines[$i] -notmatch '^\['; $i++) {
        if ($lines[$i] -like "$mod=*") { $line = $lines[$i]; break }
    }
    $checks++
    if (-not $line) {
        $failures.Add("$mod/locale/en/mod.cfg has no [mod-description] entry")
        $localised = ''
    } else {
        # A .cfg value is one line, so the paragraph breaks are escaped there and literal in JSON.
        $localised = ($line -replace "^$([regex]::Escape($mod))=", '') -replace '\\n', "`n"
        $checks++
        if ($localised -ne $info.description) {
            $failures.Add("${mod}: info.json description and [mod-description] differ. " +
                'A player sees whichever loads first, so these have to be the same text.')
        }
    }

    Test-Claim -Where "$mod/info.json" -Text $info.description -Needles $CREDITS
    if ($mod -ne $assetsMod) {
        Test-Claim -Where "$mod/info.json" -Text $info.description -Needles $CLAIMS
    }
}

# 3. The assets split (ADR 0023). Both halves fail only for a player, never here: the junctioned
# assets mod is always the current one, so load-check resolves every sprite path whatever the floor
# says. These two are the whole of what stands between that and "File __...-assets__/....png not
# found" on someone else's machine.
$assetsInfo    = Get-Content (Join-Path $repoRoot "$assetsMod/info.json") -Raw | ConvertFrom-Json
$assetsVersion = $assetsInfo.version
$floorPattern  = "^\s*" + [regex]::Escape($assetsMod) + "\s*>=\s*(?<floor>\S+)\s*$"

foreach ($mod in $codeMods) {
    $checks++
    $deps  = @((Get-Content (Join-Path $repoRoot "$mod/info.json") -Raw | ConvertFrom-Json).dependencies)
    $floor = $deps | ForEach-Object { [regex]::Match($_, $floorPattern) } |
             Where-Object { $_.Success } | Select-Object -First 1

    if (-not $floor) {
        $failures.Add("$mod/info.json does not require '$assetsMod >= <version>'")
    }
    elseif ($floor.Groups['floor'].Value -ne $assetsVersion) {
        $declared = $floor.Groups['floor'].Value
        $failures.Add("$mod/info.json requires $assetsMod >= $declared, but that mod is at " +
            "$assetsVersion. Raise the floor in the same commit that bumps the assets version -- " +
            'otherwise a player keeps the older assets mod and the sprite the newer code names is ' +
            'not in it.')
    }

    $checks++
    $strays = @(Get-ChildItem (Join-Path $repoRoot $mod) -Recurse -File -Filter *.png -ErrorAction SilentlyContinue)
    if ($strays) {
        $named = ($strays | Select-Object -First 3 | ForEach-Object { $_.Name }) -join ', '
        $failures.Add("$mod ships $($strays.Count) .png. Art belongs in $assetsMod (ADR 0023); " +
            "left here it is re-downloaded on every code release: $named")
    }
}

# 4. The repository's own front page, which is where anyone arriving from the mod portal lands.
$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
Test-Claim -Where 'README.md' -Text $readme -Needles $CLAIMS
Test-Claim -Where 'README.md' -Text $readme -Needles $CREDITS

# 5. The scripts in this directory answer Get-Help. Comment-based help at the top of a script is
# recognised only when nothing but comments and blank lines precedes it, so a #Requires statement
# above the block silently detaches it: PowerShell then synthesises syntax-only help from the param
# block, and the reasoning in the block -- 6100 characters in probe-quality.ps1 alone -- becomes
# unreachable by the documented means of reaching it. Twenty-seven scripts were broken this way,
# and a twenty-eighth by the adjacency below (#151). It is asserted rather than eyeballed because
# the failure is invisible in the file: the block reads exactly the same whether PowerShell can
# see it or not.
$allScripts = @(Get-ChildItem $PSScriptRoot -File -Filter *.ps1 | Sort-Object Name)
$documented = @($allScripts | Where-Object { (Get-Content $_.FullName -Raw) -match '(?m)^\s*\.SYNOPSIS\s*$' })

# The floor, because everything below it passes by finding nothing. Break the predicate above --
# rename the keyword, reformat the line -- and every script leaves scope while this still prints
# green. A script that OPENS with a comment block is documented and has to be reachable; one that
# does not (factorio-lib.ps1, dot-sourced rather than invoked) is not being asked to grow help it
# never had, which #151 put out of scope.
$checks++
$undeclared = @($allScripts | Where-Object {
    (Get-Content $_.FullName -TotalCount 1) -eq '<#' -and $_.Name -notin $documented.Name })
if ($undeclared) {
    $failures.Add('these open with a comment block but declare no .SYNOPSIS, so nothing below ' +
        "checks their help: $(($undeclared.Name) -join ', ')")
}

foreach ($ps1 in $documented) {
    # A parse error arrives here as "could not find ... in a help file", which names neither the
    # cause nor the fix -- and under $ErrorActionPreference = 'Stop' it would end the run before the
    # failures gathered in sections 1-4 are ever printed.
    try { $help = Get-Help $ps1.FullName }
    catch {
        $checks++
        $failures.Add("$($ps1.Name): Get-Help failed, which usually means a parse error: " +
            $_.Exception.Message)
        continue
    }

    $checks++
    $rendered = (@($help.description) | ForEach-Object { $_.Text }) -join ''
    if (-not $rendered.Trim()) {
        $failures.Add("$($ps1.Name): Get-Help renders no .DESCRIPTION -- either its #Requires line " +
            'sits above the closing #>, where it detaches the block, or the block declares none.')
    }

    $checks++
    # The synthesised stand-in is the syntax line, which opens with the file name. A real .SYNOPSIS
    # does not, by the convention every script here follows, so this tells the two apart without
    # knowing what any of them is supposed to say.
    if ($help.Synopsis -like ([WildcardPattern]::Escape($ps1.Name) + '*')) {
        $failures.Add("$($ps1.Name): Get-Help returns the generated syntax line, not its .SYNOPSIS")
    }

    $checks++
    # The other half of the same trap, and the one the first fix for #151 walked into: moved to the
    # line IMMEDIATELY below #>, the requires statement is absorbed into the block's last section --
    # the final .EXAMPLE's remarks, in most of these -- and rendered to the reader as prose. Help
    # that is reachable and wrong is not obviously better than help that is unreachable.
    $remarks = (@($help.examples.example) |
                ForEach-Object { @($_.remarks) | ForEach-Object { $_.Text } }) -join ' '
    if ("$rendered $remarks" -match 'Requires -Version') {
        $failures.Add("$($ps1.Name): its #Requires line is rendered as help text. It needs a blank " +
            'line between it and the closing #>, or the help parser absorbs it into the last section.')
    }
}

# 6. Every docs/ path this repo cites in prose actually exists. Two research notes were written for
# #158 and #159, committed to their own branches, cited from three files on main -- and never
# merged. Both tickets read as completed while the findings they produced could not be opened, and
# scripts/tree-viewer.ps1 sent a reader to a field-semantics note that was not there. Nothing could
# see it: the citing line is a comment or a link, so no parser reads it, and the branch it lived on
# looked merged from anywhere except `git merge-base`. Same shape as section 5 -- a claim made in
# prose, invisible to every other gate, checkable without starting a game (#183).
# Every file in scripts/, not only the .ps1 ones: the help above promises "anywhere in scripts/",
# and scripts/tree-layout-probe.js cites a research note from a JavaScript comment, which a .ps1
# filter would have walked straight past (#182).
$citing = @(Get-ChildItem $PSScriptRoot -File) +
          @(Get-ChildItem (Join-Path $repoRoot 'docs') -File -Filter *.md -Recurse)
$cited = [System.Collections.Generic.List[object]]::new()
foreach ($file in $citing) {
    $n = 0
    foreach ($line in (Get-Content $file.FullName)) {
        $n++
        # A path pointing into docs/ and ending .md. Globs are patterns, not citations, and a
        # fenced or inline code span naming a directory is not a promise that a file is in it.
        foreach ($m in [regex]::Matches($line, '(?<![\w./-])docs/[\w./-]+\.md')) {
            if ($m.Value -match '\*') { continue }
            $cited.Add([pscustomobject]@{ Path = $m.Value; From = $file.Name; Line = $n })
        }
    }
}

# The floor, as in section 5: everything below passes by finding nothing, so a regex that stops
# matching would take this check out of scope while still printing green. The repo cites its own
# notes constantly -- if this ever finds none, the predicate broke, not the habit.
$checks++
if ($cited.Count -lt 10) {
    $failures.Add(("only $($cited.Count) docs/ citations found across $($citing.Count) files, which " +
        'means the pattern above stopped matching rather than that the repo stopped citing'))
}

$checks++
$dangling = @($cited | Where-Object { -not (Test-Path (Join-Path $repoRoot $_.Path)) } |
              Sort-Object Path, From)
if ($dangling) {
    $shown = ($dangling | ForEach-Object { "$($_.Path) (cited by $($_.From):$($_.Line))" }) -join '; '
    $failures.Add("these docs/ paths are cited but do not exist: $shown")
}

# ----------------------------------------------------------------------------- our own files, by line
#
# 7. NOTHING IN PROSE MAY CITE ONE OF THIS REPOSITORY'S OWN FILES BY LINE NUMBER (#69, ADR 0032).
#
# Not a style rule. A line number is a claim about a file that no gate reads, and it goes wrong
# silently the moment anyone adds a comment above the thing it points at -- which is the ordinary
# way this repository changes. Two pull requests running, #256 and #259, each moved control.lua's
# three get_capacity call sites and each left the research note pointing at the old lines; an audit
# then found the same rot in twelve other documents, ten of them stale by more than a hundred lines,
# some pointing at prose that had never been there. The repair was to name the function instead, and
# a function name is checkable by grep in a way `:488` is not.
#
# WHAT IS LEFT ALONE, and why each is outside the rule:
#   - the predecessor archives and vanilla -- ORIG/, PORT/, _reference/, RealisticFusion*, base/ --
#     whose files this repo neither owns nor moves, where a line number is the only pointer there is;
#   - verbatim game output, which prints `__mod-name__/control.lua:12:` and is a quotation;
#   - a bare file name that several of our own files share -- `entities.lua`, `d-d.lua` -- because
#     which one is meant cannot be decided here, and a gate that guesses would cry wolf on the
#     predecessor citations that fill port-and-original-inspection.md. A citation is ours only when
#     the path given resolves to exactly ONE tracked file.
#
# TWO OF ADR 0032'S THREE SHAPES ARE CHECKED, AND THE THIRD IS NOT (#303):
#
#   1. `prototypes/fluids.lua:119` -- a path and a colon. Matched, then subject to the ambiguity
#      exemption above. ADR 0032 decision item 2 NARROWS that hole from the other side rather than
#      closing it, and the difference matters: a path anchored at the REPO root resolves to one
#      tracked file and fires here, while a MOD-relative one still names two and is still exempt.
#      Five paths are ambiguous that way -- data.lua, prototypes/entities.lua, prototypes/fluids.lua,
#      prototypes/categories.lua, prototypes/items.lua -- and the specimen on this very line is one
#      of them, which is why writing it here is safe.
#
#      So: zero own-tree citations resolve to one tracked file today, and a pass is therefore the
#      absence of violations rather than the exemption swallowing thirty of them -- demonstrable only
#      by planting one, never by reading a green run, which is why #303's pull request plants one
#      instead of asserting it. But prose still writes the bare mod-relative form more than twice as
#      often as the repo-relative one, so THAT is the shape the next regression will most likely take
#      and this check will not see it. Only a citation written the way item 2 asks is gated.
#
#   2. `:155` written bare in backticks -- a continuation inheriting the path named earlier on the
#      SAME LINE. New in #303. THE BACKTICKS ARE THE DISCRIMINATOR AND ARE REQUIRED: unbackticked,
#      a colon and a number cannot be told from a page range, a ratio or a timestamp --
#      dag-layout-algorithms.md carries `11(2):109-125` and three more citations shaped exactly like
#      it -- and measured on 2026-09-10 over the files this check actually reads, with the same skip
#      filter, the loose `:\d+` matches around 250 places against this one's two dozen. (A tenfold
#      larger figure is available by counting tools/endf/*.json too, and would be dishonest here:
#      those are the datasets the list below excludes by name for exactly this reason.) A gate that
#      cried wolf on bibliography entries gets switched off, which is the same failure the ambiguity
#      exemption above already refuses to risk.
#
#   3. "lines 196-197, 204, 208, 227, and 576-578" -- running prose, no path and no colon. NOT
#      ATTEMPTED, and that is a decision rather than an omission. There is no handle here a regex
#      can trust: a pattern loose enough to catch it fires on every ADR that quotes a predecessor
#      by line, which is most of port-and-original-inspection.md and predecessor-survey.md. #302
#      found five such citations of ours by READING, and reading is what will have to find the next
#      one. Stated in the help block as a gap so a green run does not imply otherwise.
#
# WHAT SHAPE 2 STILL MISSES, stated for the same reason:
#   - a continuation whose path sits on an EARLIER line. Per-line is the whole design -- carrying
#     state further means guessing where a sentence ended, and a wrong guess attributes a citation
#     to a file nobody named. connection-category-reassignment.md has four that inherit a
#     third-party data-final-fixes.lua from the line above, and they are correctly silent, but by
#     being unattributable rather than by being classified. Reading is the backstop there too.
#
#     AND PER-LINE CAN MISATTRIBUTE IN ITS OWN DIRECTION, which is the honest other half: reword one
#     of those four so any path of ours appears earlier on the same line, and this check fails on a
#     continuation that was always the third party's. The wrong guess is cheaper in this direction --
#     a false failure is argued with, a false pass is not noticed -- but it is not no guess.
#   - the specimens, and this is the one worth knowing before editing any of the three. ADR 0032,
#     CLAUDE.md's conventions bullet and this comment each write the banned form out on purpose,
#     because a rule against a shape cannot be stated without showing the shape. All of them are
#     silent today either because no path precedes them on their line or because the path they
#     inherit is one of the ambiguous ones -- which is luck, not a decision. Writing a specimen with
#     a repo-relative path WILL fail this check. The fix then is to reword the specimen, NOT to
#     exempt the file: exempting it would hide a genuinely broken citation inside the very document
#     that bans them, and these three are where a reader is most likely to trust one.
$tracked = @(& git -C $repoRoot ls-files | Where-Object { $_ })

# This check reads more than $citing does, and has its own list on purpose (#303). ADR 0032 decision
# item 5 binds our Lua and PowerShell comments as well as docs/, and nothing violated it when that
# was written, so covering them now costs nothing and gets more expensive later. Every tracked .md,
# .lua, .ps1, .py and .js -- 201 files on 2026-09-10 against the 123 $citing walks, and built from
# git ls-files so an untracked generated tree is excluded by never appearing. .json is deliberately
# out: tools/endf/*.json are cross-section datasets whose every row reads `,{"E":1.001E+06 ...}` and
# matches a colon-and-digits pattern thousands of times.
#
# $citing is NOT widened to match. Section 6 is a different check answering a different question,
# and coupling the two harder so they can share one list would make widening either one a change to
# both -- which is exactly the trap this comment would then have to warn about instead.
#
# IT NARROWS AS WELL AS WIDENS, and only the widening is obvious. $citing reads EVERY file directly
# in scripts/; this reads only tracked ones with the five extensions, so scripts/mockup-machines.psd1
# and scripts/tree-viewer.template.html leave scope, and so does any file not yet `git add`ed. A new
# doc is therefore ungated until it is staged. Nothing violates the rule in either place today; the
# trade is deliberate, because a list built from the index is what keeps the generated trees out.
$citingCode = @($tracked | Where-Object { $_ -match '\.(?:md|lua|ps1|py|js)$' })

# A path token, with the line number optional so shape 2 can inherit one that carries none.
$OWN_PATH = '(?<![\w./-])([\w./-]+\.(?:lua|ps1|py|js|json|md))(:\d+(?:-\d+)?)?'
$OWN_CONT = '`:(\d+(?:-\d+)?)`'

$numbered = [System.Collections.Generic.List[object]]::new()
$anyCite  = 0
$anyCont  = 0
foreach ($rel in $citingCode) {
    # The list comes from the index and the content from the worktree, so the two can disagree: a
    # file deleted or renamed but not yet staged is still tracked and no longer there. Get-Content
    # then throws under the $ErrorActionPreference above, which killed the whole run -- no failure
    # summary and every later section unrun, on nothing worse than an unstaged `rm`. Skipped rather
    # than reported: this section checks prose, and worktree integrity is not its question.
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $n = 0
    foreach ($line in (Get-Content -LiteralPath $full)) {
        $n++
        # Verbatim log output, the predecessor archives and vanilla, per the note above. Whole-line,
        # which is what keeps a shape-2 continuation inheriting one of those paths silent too.
        if ($line -match '__|Script @|ORIG/|PORT/|_reference/|RealisticFusion|(?<![\w-])base/') { continue }

        # Shape 1.
        foreach ($m in [regex]::Matches($line, $OWN_PATH)) {
            if (-not $m.Groups[2].Success) { continue }
            $anyCite++
            $path = $m.Groups[1].Value
            $hits = @($tracked | Where-Object { $_ -eq $path -or $_.EndsWith('/' + $path) })
            if ($hits.Count -eq 1) {
                $numbered.Add([pscustomobject]@{
                    Shown = "$($m.Value) (in ${rel}:$n)"; From = $rel; Line = $n })
            }
        }

        # Shape 2. The last path token before the continuation, on this line, is the one it means.
        foreach ($m in [regex]::Matches($line, $OWN_CONT)) {
            $anyCont++
            $before = [regex]::Matches($line.Substring(0, $m.Index), $OWN_PATH)
            if (-not $before.Count) { continue }
            $path = $before[$before.Count - 1].Groups[1].Value
            $hits = @($tracked | Where-Object { $_ -eq $path -or $_.EndsWith('/' + $path) })
            if ($hits.Count -eq 1) {
                $numbered.Add([pscustomobject]@{
                    Shown = "$($m.Value) inheriting $path (in ${rel}:$n)"; From = $rel; Line = $n })
            }
        }
    }
}

# A floor per shape, for the same reason section 5 and section 6 carry one: both pass by finding
# nothing, so a regex that stopped matching would print green while checking nothing at all.
#
# Shape 1's floor is unchanged at ten, and #303 confirmed it still bites rather than lowering it:
# #302 removed forty-six own-tree citations and over ninety path:line matches remain, because the
# predecessor and vanilla ones this check deliberately walks past are counted here too. That is
# the point -- the floor measures whether the PATTERN still works, not whether the repo still
# offends, so it survives the corpus being cleaned.
#
# EVERY COUNT IN THIS SECTION INCLUDES THE SPECIMENS IN ITS OWN COMMENTS, which is why none of them
# is written exactly. Two drafts quoted precise figures -- 89 and 21, then 91 and 24 -- and each was
# falsified by the prose that quoted it, because adding a sentence about a specimen adds a specimen.
# Round numbers are not vagueness here, they are the only stable way to state this. Re-measure before
# changing a floor; do not trust a figure in a comment the figure counts.
$checks++
if ($anyCite -lt 10) {
    $failures.Add("only $anyCite path:line citation(s) found across $($citingCode.Count) files, " +
        'which means the pattern above stopped matching rather than that the repo stopped citing')
}

# Shape 2's floor, at eight against the two dozen found on 2026-09-10. It cannot be a floor on
# continuations judged OURS, because that number is zero and is meant to be -- every one in the tree
# is either unattributable or inherits an ambiguous path. So it counts the shape being FOUND, which
# is what proves the pattern still matches.
$checks++
if ($anyCont -lt 8) {
    $failures.Add("only $anyCont bare-continuation citation(s) found across " +
        "$($citingCode.Count) files, which means the shape-2 pattern above stopped matching " +
        'rather than that the repo stopped writing them')
}

$checks++
if ($numbered.Count) {
    $shown = (($numbered | Sort-Object From, Line | ForEach-Object { $_.Shown }) -join '; ')
    $failures.Add('these cite one of our own files by line number, which goes stale silently -- ' +
        "name the function, field, constant or prototype instead (ADR 0032): $shown")
}

# ------------------------------------------------------------------- the accents that are a fluid's
#
# 8. AN ACCENT NAMED FOR A FLUID MUST BE THAT FLUID'S OWN COLOUR (#334).
#
# Two of the house style's accents are not picks. models/house-style.md says so in its own words:
# tritium's green and helium-3's violet are taken straight from the Core mod's prototypes/fluids.lua
# "rather than picked", on the argument that a player who has learnt a fluid from its icon should
# meet the same colour on the machine's socket. The other accents -- energy, steam, water, plasma --
# are roles first and were chosen for the role, and plasma cannot follow the rule at all, since one
# accent covers four fluids of four different colours.
#
# So the same RGB triple is typed three times over: in fluids.lua, in house-style.md's palette
# table, and in the PALETTE of every build script that renders a machine carrying the fluid. Nothing
# else in this repository types a FLUID's colour -- other colours are typed in plenty of places and
# are copies of nothing. models/rf_blender.py's ACCENT_OF_FLUID maps the fluid to the accent's
# NAME and models/test_rf_blender.py checks that mapping, but a name is not a value: recolour
# rf-tritium and every rendered socket goes on being the old green, silently disagreeing with the
# pipe it feeds, and every gate in this repository still passes. The drift surface grows with each
# render, because each new build.py carries its own copy.
#
# WHICH ACCENTS ARE IN SCOPE IS DERIVED, NOT LISTED, so a third by-product accent is covered the day
# it is written. A palette row "<X> accent" is in scope exactly when the Core mod declares a fluid
# called rf-<X>. That picks up Tritium and Helium-3 and leaves the four role accents alone: there is
# no rf-energy, no rf-plasma, and steam and water are the game's own fluids rather than ours, so
# none of the four names a fluid this repository declares. It is also the right rule rather than a
# convenient one -- an accent named after one of our fluids should agree with it, whoever adds it.
#
# THE FLOORS, for the reason sections 5, 6 and 7 carry one: a scan passes by finding nothing, so a
# regex that stopped matching would print green while checking nothing at all. There are FOUR --
# one on each of the three things scanned (the fluid declarations, the palette rows, the machines
# whose geometry says which accents their build script must hold) and one on the pairing of an
# accent to a fluid, which is derived from the first two rather than scanned for. The two files
# themselves are named rather than searched for, so a missing one throws instead of going quiet.
#
# A FLOOR CANNOT SEE A BROKEN COMPARISON, which is the hole sections 5 to 7 live with and this one
# does not have to: Test-SameColour is exercised on a known-equal and a known-unequal pair below,
# every run. That is the self-test half #334 asked for, at the size the thing being proved deserves.
$fluidsLua  = Join-Path $repoRoot 'realistic-fusion-refreshed-core/prototypes/fluids.lua'
$houseStyle = Join-Path $repoRoot 'models/house-style.md'

$fluidColour = @{}
foreach ($m in [regex]::Matches((Get-Content $fluidsLua -Raw),
        'fluid\(\s*"(rf-[\w-]+)"\s*,\s*\{\s*r\s*=\s*([\d.]+)\s*,\s*g\s*=\s*([\d.]+)\s*,\s*b\s*=\s*([\d.]+)\s*\}')) {
    $fluidColour[$m.Groups[1].Value] = @($m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value)
}
$checks++
if ($fluidColour.Count -lt 8) {
    $failures.Add(("only $($fluidColour.Count) fluid colour(s) read out of the Core mod's " +
        'prototypes/fluids.lua, where eleven are declared -- so the pattern above stopped matching ' +
        'rather than that the mod stopped declaring fluids'))
}

# A palette row: the role, the linear RGB, and what wears it. Only the accent rows carry a fluid's
# name; Body steel, Frame, Bare metal and Glow are not accents and do not match.
$accents = [System.Collections.Generic.List[object]]::new()
foreach ($line in (Get-Content $houseStyle)) {
    $m = [regex]::Match($line, '^\|\s*(.+?)\s+accent\s*\|\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\|')
    if (-not $m.Success) { continue }
    $accents.Add([pscustomobject]@{
        Name   = $m.Groups[1].Value.ToLowerInvariant()
        Colour = @($m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value) })
}
# Four, against the six rows the table holds today, so retiring one accent does not fail this while
# a broken pattern still does. Deliberately not six: a floor at the exact count is a second, unsaid
# rule about how many accents the house style is allowed to have.
$checks++
if ($accents.Count -lt 4) {
    $failures.Add(("only $($accents.Count) accent row(s) read out of models/house-style.md's " +
        'palette table, where six are written -- so the pattern above stopped matching rather ' +
        'than that the house style stopped having accents'))
}

# Equal to the tolerance the table is written to. Both sides are decimal text, so this is exact in
# practice; the epsilon is so that 0.5 and 0.50 are the same colour, which is the likelier edit.
function Test-SameColour {
    param([string[]] $A, [string[]] $B)
    for ($i = 0; $i -lt 3; $i++) {
        $x = [double]::Parse($A[$i], [cultureinfo]::InvariantCulture)
        $y = [double]::Parse($B[$i], [cultureinfo]::InvariantCulture)
        if ([math]::Abs($x - $y) -gt 1e-9) { return $false }
    }
    return $true
}

# The comparison has to be able to say no, and has to survive a colour written with fewer decimals.
# Every check below is green if Test-SameColour always returns true, so this is proved rather than
# assumed.
$checks++
if (-not (Test-SameColour @('0.50', '1.00', '0.60') @('0.5', '1', '0.6'))) {
    $failures.Add('Test-SameColour calls two spellings of one colour different, so every ' +
        'comparison below is unreliable')
}
$checks++
if (Test-SameColour @('0.50', '1.00', '0.60') @('0.50', '0.90', '0.60')) {
    $failures.Add('Test-SameColour calls two different colours the same, so every comparison ' +
        'below passes for free')
}

$fromFluid = @($accents | Where-Object { $fluidColour.ContainsKey("rf-$($_.Name)") })
# Two, which is every one there is, so this one has no headroom and is meant not to. Dropping a
# fluid accent is exactly the edit that must not happen quietly: the house style's argument for
# these two is that a player meets a fluid's own colour on the socket, so losing one is a change to
# that argument and should be made by editing this number on purpose.
$checks++
if ($fromFluid.Count -lt 2) {
    $failures.Add(("only $($fromFluid.Count) palette accent(s) name a fluid this repo declares, " +
        'where tritium and helium-3 both do -- either the pairing above stopped matching, or an ' +
        'accent taken from a fluid was retired without this number being moved with it'))
}

foreach ($accent in $fromFluid) {
    $fluid = "rf-$($accent.Name)"
    $checks++
    if (-not (Test-SameColour $accent.Colour $fluidColour[$fluid])) {
        $failures.Add(("$fluid is drawn $($fluidColour[$fluid] -join ' ') in the Core mod's " +
            'prototypes/fluids.lua but its palette row in models/house-style.md says ' +
            "$($accent.Colour -join ' ') -- a socket rendered in that accent would disagree with " +
            'the pipe it feeds'))
    }
}

# WHICH BUILD SCRIPT MUST CARRY WHICH ACCENT IS READ OFF THE MACHINE, not counted. Every
# models/<machine>/geometry.json records the fluid on each connection the machine declares, so it
# says exactly which accents that machine's build.py has to hold. Counting matches instead would
# let a renamed PALETTE key leave scope in silence -- indistinguishable from a machine that
# legitimately carries neither fluid -- and #334 raised this check precisely because the drift
# surface grows with every machine rendered.
$inScope = 0
foreach ($geometry in (Get-ChildItem (Join-Path $repoRoot 'models') -File -Filter geometry.json -Recurse)) {
    $build = Join-Path $geometry.DirectoryName 'build.py'
    if (-not (Test-Path $build)) { continue }   # geometry extracted, model not built yet
    $rel     = $build.Substring($repoRoot.Length + 1).Replace('\', '/')
    $carries = @((Get-Content $geometry.FullName -Raw | ConvertFrom-Json).connections |
                 ForEach-Object { $_.fluid } | Sort-Object -Unique)
    $text    = Get-Content $build -Raw
    foreach ($accent in $fromFluid) {
        $fluid = "rf-$($accent.Name)"
        if ($carries -notcontains $fluid) { continue }
        $inScope++
        $want = $fluidColour[$fluid]
        $m = [regex]::Match($text, '"' + [regex]::Escape($accent.Name) +
                                   '"\s*:\s*\(\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)')
        $checks++
        if (-not $m.Success) {
            $failures.Add(("$rel renders a machine that carries $fluid but its PALETTE has no " +
                "entry keyed $($accent.Name), so the socket is drawn in something other than the " +
                'colour the fluid is drawn in'))
            continue
        }
        $got = @($m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value)
        if (-not (Test-SameColour $got $want)) {
            $failures.Add(("$fluid is drawn $($want -join ' ') in the Core mod's " +
                "prototypes/fluids.lua but $rel renders its accent $($got -join ' ') -- the " +
                'socket and the pipe would not be the same colour'))
        }
    }
}

# The third floor, on the pairing of a machine to its accents. Today the isotope collector is the
# only built model carrying either fluid, and it carries both.
$checks++
if ($inScope -lt 2) {
    $failures.Add(("only $inScope built model(s) carry a fluid whose accent is that fluid's " +
        'colour, where the isotope collector carries two -- so the geometry pattern above ' +
        'stopped matching rather than that no machine carries them'))
}


# ----------------------------------------------------------------- our own halves, by name
# 9. NOTHING IN PROSE MAY CITE A -SelfTest HALF BY ORDINAL (#411, #416).
#
# The same shape as section 7 and the same failure: a claim about code that no other gate reads,
# which goes wrong silently the moment the code changes in its ordinary way. A half inserted above
# another renumbers every half after it, and a sentence naming one by position then points at a
# different half and still reads as true. It is not hypothetical -- CLAUDE.md named two of
# load-check.ps1's by number as the canaries, and bench-reactors.ps1's own .PARAMETER prose
# numbered three of its own, so renumbering either gate edited prose nothing would have flagged.
#
# The halves carry names now (#411 through #415, Invoke-SelfTestHalves), so a citation has something
# to point at that a later insertion cannot invalidate.
#
# WHAT COUNTS AS PROSE, and this is the whole of the discrimination: every line of a tracked .md,
# and in code only the lines that are COMMENTS -- a line-comment, or a line inside a block comment.
# A label a script PRINTS is not a citation; factorio-lib.ps1's runner canary holds numbered lines
# as the output it expects. That is code
# doing its job, and a gate that failed them would be asking prose rules of a string literal.
#
# WHAT IT CANNOT SEE, stated here rather than left to be discovered, exactly as section 7 states its
# own gaps:
#   - a citation in a TRAILING comment, after code on the same line. Only a line whose first
#     non-blank text opens a comment is read, because deciding whether a `#` sits inside a string
#     needs a parser and a wrong guess reports a citation nobody wrote.
#   - every way English can point at a half without the word: an ordinal on its own, "the one
#     before the stall detector", "the last of them". There is no handle in those a regex can
#     trust, which is the same decision section 7 records for its third shape.
#   - a half named in a file this check does not read -- anything outside the tracked .md, .lua,
#     .ps1, .py and .js list, and anything not yet `git add`ed.
#   - a citation inside a FENCED block in markdown, which is where a pasted run lives. Quoted output
#     is not a citation, and telling a quoted one from a written one inside a fence would need a
#     reader rather than a regex. An INDENTED markdown block is read, because telling one from a
#     wrapped list item needs a markdown parser.
# It catches the three forms that actually occur, and the patterns below are the statement of them:
# the word half or halves followed by a word ordinal, the same followed by a small integer, and a
# self-test named with the ordinal-over-total an unconverted gate's comments used to carry.
#
# THE SPECIMENS ARE WRITTEN AS DESCRIPTIONS RATHER THAN AS EXAMPLES, which is the opposite of what
# section 7 does and for the same reason section 7 explains: a rule against a shape wants to show
# the shape, but this one would then fail on its own comment. Exempting this file would hide a
# genuine citation inside the document that bans them, so the prose here spells none of them out and
# the regexes are the specimens.
# ONE PATTERN RATHER THAN THREE APPLIED IN TURN, and the alternation is ordered longest-first. The
# labelled form CONTAINS the integer form, so three separate scans reported such a citation twice --
# two failures for one sentence, and any count taken over the result inflated by the overlap. One
# scan takes the longest match at each position and carries on past it.
$HALF_ORDINAL =
    # The labelled form first -- what a gate's own comments carried before the runner numbered them.
    '(?i)(?:self-test|-selftest)\s+(?:half\s+)?\d{1,2}(?:/\d{1,2})?\b' +
    # The word form, which is what prose writes. BOTH SPELLINGS, because they share no prefix -- a
    # pattern keyed on the singular misses the plural entirely, which this gate's own self-test
    # caught on its first run.
    '|(?i)\bhal(?:f|ves)\s+(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen)\b' +
    # The integer form, and the one that can fire on something nobody wrote as a citation:
    # check-brownout's rig has a supply level CALLED half, and its note tabulates a reading after
    # that word. So a decimal is excluded, and so is a unit -- the ones this repository's notes
    # actually tabulate, listed rather than guessed, because a whole-numbered row reads exactly like
    # a citation otherwise. A unit outside the list is a false FAILURE, which is the cheap
    # direction: a false failure is argued with, a false pass is not noticed.
    '|(?i)\bhal(?:f|ves)\s+\d{1,2}(?![\d.])(?!\s*(?:[kMG]?W\b|[kM]?J\b|C\b|K\b|px\b|%|[mun]?s\b|tiles?\b|ticks?\b|files?\b))'

function Get-ProseLines {
    <#  The lines of a file that are PROSE: in markdown all of them but a fenced block, and in code
        the comments.

        Block comments are tracked because that is where the citations this gate exists for live: a
        PowerShell comment-based help block carries no per-line marker, and bench-reactors.ps1's
        .PARAMETER SelfTest numbered its halves from inside one.

        A FENCED BLOCK IS NOT PROSE, for the same reason a printed label is not a citation: this
        repository's notes record measurements by pasting the run that produced them, and a pasted
        -SelfTest transcript is quoted output. An INDENTED code block is not excluded -- telling one
        from a wrapped list item needs a markdown parser, and the fenced form is what the notes
        here use.  #>
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $Extension)

    $open, $close, $line = switch ($Extension) {
        '.md'  { $null,   $null, $null }
        '.ps1' { '<#',    '#>',  '#'   }
        '.py'  { '"""',   '"""', '#'   }
        '.lua' { '--[[',  ']]',  '--'  }
        '.js'  { '/*',    '*/',  '//'  }
        default { $null,  $null, $null }
    }

    $out    = [System.Collections.Generic.List[object]]::new()
    $inside = $false
    $fenced = $false
    $n      = 0
    foreach ($text in (Get-Content -LiteralPath $Path)) {
        $n++
        if ($Extension -eq '.md') {
            if ($text.TrimStart() -match '^(?:```|~~~)') { $fenced = -not $fenced; continue }
            if (-not $fenced) { $out.Add([pscustomobject]@{ Line = $n; Text = $text }) }
            continue
        }
        $trimmed = $text.TrimStart()
        if ($inside) {
            $out.Add([pscustomobject]@{ Line = $n; Text = $text })
            if ($text.Contains($close)) { $inside = $false }
            continue
        }
        if ($open -and $trimmed.StartsWith($open)) {
            $out.Add([pscustomobject]@{ Line = $n; Text = $text })
            # A block opened and closed on one line is not a block.
            if (-not $trimmed.Substring($open.Length).Contains($close)) { $inside = $true }
            continue
        }
        if ($line -and $trimmed.StartsWith($line)) { $out.Add([pscustomobject]@{ Line = $n; Text = $text }) }
    }
    return $out
}

function Find-NumberedHalves {
    <#  Every place the prose of these files cites a self-test half by ordinal.

        Returns the file, the line and the citation as written, because a finding that does not
        quote what it matched sends a reader hunting through a comment block for it.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Files, [string] $Root)

    $found = [System.Collections.Generic.List[object]]::new()
    foreach ($rel in $Files) {
        $full = if ($Root) { Join-Path $Root $rel } else { $rel }
        if (-not (Test-Path -LiteralPath $full)) { continue }   # tracked, deleted, not yet staged
        foreach ($prose in (Get-ProseLines -Path $full -Extension ([IO.Path]::GetExtension($full)))) {
            foreach ($m in [regex]::Matches($prose.Text, $HALF_ORDINAL)) {
                $found.Add([pscustomobject]@{ File = $rel; Line = $prose.Line; Cited = $m.Value })
            }
        }
    }
    return $found
}

$checks++
foreach ($cite in (Find-NumberedHalves -Files $citingCode -Root $repoRoot)) {
    $failures.Add(("$($cite.File), line $($cite.Line), cites a self-test half by ordinal " +
        "(`"$($cite.Cited)`"). Name the half instead -- the halves are declared by name where " +
        'they run, and an ordinal points at a different half the moment one is inserted above it.'))
}

# 10. A ROW OF A `## Current figures` TABLE MUST STILL BELONG TO ITS NOTE (#602, #616).
#
# Seven notes under docs/research/ open with a table of the figures the note stands behind, and
# docs/agents/code-review.md says a figure and its row change in the same commit. That rule is prose,
# and this is the half of it a script can hold: a row whose Section link names a heading the file
# does not have, and a row whose value is written nowhere in the note below the table. Both are what
# an edit to a section leaves behind when the row is forgotten -- a heading renamed, a figure
# re-measured -- and neither changes anything another gate reads.
#
# THE NOTES ARE FOUND BY THE HEADING, never by a list of names, so a note that gains a table is
# gated from the commit that adds it. The table is the one under that heading whose header row names
# the six columns; a row is every `|` line after the separator until the first line that is not one.
#
# AN ANCHOR IS COMPUTED THE WAY GITHUB COMPUTES IT, because that is where the link is followed:
# lowercased, everything but letters, marks, decimal digits, underscores, hyphens and spaces dropped,
# spaces to hyphens, and a repeated heading suffixed -1, -2 in order. A superscript is not a decimal
# digit and a multiplication sign is not a letter, so both drop, which is what GitHub does to them.
#
# A VALUE IS HELD TO ITS NUMBERS, not to its words. Every number in the Value cell must be written
# somewhere below the table, whole: 0.32 is not found inside 0.3205, and 5.4 is not found inside
# 5.44. A cell holding several figures passes when each of them is found.
#
# WHAT IT CANNOT SEE:
#   - whether the row is the figure the note CURRENTLY stands behind. A superseded figure is still
#     written in the note -- the house style keeps it, marked -- so it passes here. That half of the
#     rule stays with the review.
#   - whether the value sits in the section the row points at. It is searched for in the whole note
#     below the table, because a section's extent needs a markdown parser to bound.
#   - a small number. 3, 10 and 50 are written somewhere in any note, so a row whose value is one of
#     those is held to nothing. The exponent's base in a power of ten passes the same way.
#   - an order of magnitude written as a superscript. Only the mantissa and the 10 are numbers
#     here, so a row a thousandfold out in its exponent passes. An exponent written with an e is
#     read.
#   - a number written straight after another one, when it opens with exactly three digits. The
#     pair reads as one grouped figure, so "rung 3 100 MW" hides both the 3 and the 100, and prose
#     wrapped as "rung 5" then "102.4 MW" hides the 102.4, since a line end is a space here. That
#     is a false FAILURE, the cheap direction, and only when the note writes the figure nowhere
#     else.
#   - a heading written with underscore emphasis. GitHub drops those underscores from the anchor
#     and this keeps them, so such a heading's row fails until the heading is written with
#     asterisks. No heading in the seven notes is.
#   - a unit, a sign, or which of two figures in one cell is which.
#   - the Measured, Game version and Research state cells, which are not read at all.
$FIGURE_HEADING = '^##\s+Current figures\s*$'
$FIGURE_HEADER  = '^\|\s*Figure\s*\|\s*Value\s*\|\s*Measured\s*\|\s*Game version\s*\|\s*Research state\s*\|\s*Section\s*\|\s*$'
# Thousands grouped by a space or a comma first, so a figure written in groups of three is one number
# and not three.
$FIGURE_NUMBER  = '\d+(?:[ ,]\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?(?:e[+-]?\d+)?'
# How many notes carried a table when this section was written (#616). A scan that found none would
# pass every row it never read.
$FIGURE_TABLE_FLOOR = 7

function Get-HeadingAnchors {
    <#  The anchor GitHub gives each heading of a markdown file, fenced blocks left out.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]] $Lines)

    $anchors = [System.Collections.Generic.HashSet[string]]::new()
    $seen    = @{}
    $fenced  = $false
    foreach ($text in $Lines) {
        if ($text.TrimStart() -match '^(?:```|~~~)') { $fenced = -not $fenced; continue }
        if ($fenced -or $text -notmatch '^#{1,6}\s+(.*?)\s*$') { continue }
        # A link in a heading renders as its text, and the anchor is made from what renders.
        $shown  = [regex]::Replace($Matches[1], '\[([^\]]*)\]\([^)]*\)', '$1')
        $anchor = [regex]::Replace($shown.ToLowerInvariant(), '[^\p{L}\p{M}\p{Nd}\p{Pc}\- ]', '').Replace(' ', '-')
        # A repeat takes the first suffix not already taken, so a heading that is itself
        # called "results-1" does not share an anchor with the second "results".
        $base = $anchor
        if (-not $seen.ContainsKey($base)) { $seen[$base] = 0 }
        while ($anchors.Contains($anchor)) { $seen[$base]++; $anchor = "$base-$($seen[$base])" }
        [void] $anchors.Add($anchor)
    }
    return , $anchors
}

function Find-LooseFigureRows {
    <#  Every row of a `## Current figures` table that has come loose from its note, and how many
        such tables were read.

        Returns one object: Tables, the count, and Found, a list of the file, the line, which of the
        things is wrong and the words that show it. The count is returned beside the findings
        because zero findings over zero tables is the pass this section must not give.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Files, [string] $Root)

    $found  = [System.Collections.Generic.List[object]]::new()
    $tables = 0
    foreach ($rel in $Files) {
        $full = if ($Root) { Join-Path $Root $rel } else { $rel }
        if (-not (Test-Path -LiteralPath $full)) { continue }   # tracked, deleted, not yet staged
        $lines = @(Get-Content -LiteralPath $full -Encoding utf8)
        $at = 0
        while ($at -lt $lines.Count -and $lines[$at] -notmatch $FIGURE_HEADING) { $at++ }
        if ($at -ge $lines.Count) { continue }
        # The header row, which must come before the next heading of the same rank.
        $head = $at + 1
        while ($head -lt $lines.Count -and $lines[$head] -notmatch $FIGURE_HEADER -and $lines[$head] -notmatch '^##\s') { $head++ }
        if ($head -ge $lines.Count -or $lines[$head] -notmatch $FIGURE_HEADER) {
            $found.Add([pscustomobject]@{ File = $rel; Line = $at + 1; Kind = 'table'
                Detail = 'the heading is there and no table with the six columns follows it' })
            continue
        }
        $tables++
        $end = $head + 2                                        # past the header and its separator
        while ($end -lt $lines.Count -and $lines[$end].StartsWith('|')) { $end++ }

        $anchors = Get-HeadingAnchors -Lines $lines
        # One line, one kind of space: a number wrapped across a line end, or grouped with a
        # no-break or thin space, is still that number.
        $below = if ($end -lt $lines.Count) { $lines[$end..($lines.Count - 1)] -join ' ' } else { '' }
        $below = [regex]::Replace($below, '[\s   ]+', ' ')

        for ($i = $head + 2; $i -lt $end; $i++) {
            $cells = @([regex]::Split($lines[$i].Trim().Trim('|'), '(?<!\\)\|') | ForEach-Object { $_.Trim() })
            if ($cells.Count -ne 6) {
                $found.Add([pscustomobject]@{ File = $rel; Line = $i + 1; Kind = 'cells'
                    Detail = "$($cells.Count) cells where the header has 6" })
                continue
            }
            $links = @([regex]::Matches($cells[5], '\]\(#([^)\s]+)\)') | ForEach-Object { $_.Groups[1].Value })
            if (-not $links) {
                $found.Add([pscustomobject]@{ File = $rel; Line = $i + 1; Kind = 'anchor'
                    Detail = "the Section cell links to no heading: $($cells[5])" })
            }
            foreach ($link in $links) {
                if (-not $anchors.Contains($link)) {
                    $found.Add([pscustomobject]@{ File = $rel; Line = $i + 1; Kind = 'anchor'
                        Detail = "#$link is no heading of this file" })
                }
            }
            $value = [regex]::Replace($cells[1], '[\s   ]+', ' ')
            foreach ($number in ([regex]::Matches($value, $FIGURE_NUMBER) | ForEach-Object { $_.Value } | Select-Object -Unique)) {
                # Whole means not inside a longer figure on either side, a grouped one included:
                # a group of three is not found as the tail of a longer grouped figure, and no
                # figure is found as the head of one.
                $before = if ($number -match '^\d{3}(?!\d)') { '(?<![\d.,]|\d[ ,])' } else { '(?<![\d.,])' }
                if ($below -notmatch ($before + [regex]::Escape($number) + '(?!\d|[.,]\d|[ ,]\d{3}(?!\d))')) {
                    $found.Add([pscustomobject]@{ File = $rel; Line = $i + 1; Kind = 'value'
                        Detail = "$number, from the Value `"$($cells[1])`", is written nowhere below the table" })
                }
            }
        }
    }
    return [pscustomobject]@{ Tables = $tables; Found = $found }
}

$figureNotes = @($tracked | Where-Object { $_ -match '^docs/research/[^/]+\.md$' } | Where-Object {
    $full = Join-Path $repoRoot $_
    (Test-Path -LiteralPath $full) -and (Select-String -LiteralPath $full -Pattern $FIGURE_HEADING -Quiet)
})
$figureRows = Find-LooseFigureRows -Files $figureNotes -Root $repoRoot

$checks++
if ($figureRows.Tables -lt $FIGURE_TABLE_FLOOR) {
    $failures.Add(("only $($figureRows.Tables) note(s) under docs/research/ carry a Current figures table, " +
        "against the $FIGURE_TABLE_FLOOR there were when section 10 was written. Either a table was " +
        'removed, which is a decision to record by lowering the floor, or the scan stopped finding them.'))
}
$checks++
foreach ($row in $figureRows.Found) {
    $what = switch ($row.Kind) {
        'anchor' { 'points at a section the note does not have' }
        'value'  { 'carries a figure the note does not' }
        'cells'  { 'is not a six-cell row' }
        default  { 'has no table to read' }
    }
    $failures.Add(("$($row.File), line $($row.Line): a Current figures row $what -- $($row.Detail). " +
        'A figure that changes in a section changes its row in the same commit ' +
        '(docs/agents/code-review.md, "Review the prose, not only the code").'))
}

# 11. A ROW OF A MARKDOWN TABLE MUST HAVE AS MANY CELLS AS ITS HEADER (#649).
#
# Four pull requests running, #625 to #641, the pre-PR reviewer said it had not checked how a table
# renders on GitHub, and nobody looked. This is the part of rendering a script can hold. GitHub
# reads a header and the delimiter row under it as a table only when the two have the same number
# of cells; a body row with too many loses the extra ones, and one with too few gets empty cells.
# None of the three changes anything another gate reads.
#
# A TABLE IS a run of lines that each start with a pipe, outside a code fence, whose second line is
# a delimiter row: pipes, hyphens, colons and spaces and nothing else. Every tracked `.md` is read.
#
# A BLOCKQUOTED TABLE IS READ TOO (#652). A line's `>` marks are taken off before any of the above
# is asked of it, and counted. A row with a different count from its header is reported: it is the
# row that lost its `>`, which GitHub renders below the quote and outside the table. Two things
# follow from reading through the marks, and both are handled where the run is walked. A table
# that follows another with no blank line between, at a different depth, is a table of its own
# when its second line is a delimiter row at its own depth. And a fence opened inside a quote is
# closed by the quote's end as well as by a fence line, or one unclosed quoted fence would hide
# every table after it.
#
# A CELL IS COUNTED THE WAY GITHUB COUNTS IT: a pipe ends a cell unless a backslash is before it,
# and a pipe inside inline code ends one like any other.
#
# WHAT IT CANNOT SEE:
#   - a table with no delimiter row at all. Such a run is not a table to GitHub, and neither is a
#     wrapped line of prose that happens to start with a pipe, and nothing here tells them apart.
#     One such run is in the tracked notes, a wrapped line of prose in
#     docs/research/icon-conventions-2-0.md.
#   - a table written without leading pipes, or whose first line follows a list marker on the
#     same line. Its lines do not start with a pipe. One that is only indented under a list item
#     is read, since a line is trimmed first.
#   - a delimiter row that is malformed some other way, a cell of colons and no hyphen for one.
#   - anything about how a table looks: its width, its alignment, what a cell's markdown becomes.
$TABLE_DELIMITER = '^\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)*\|?$'
# How many tables the tracked markdown held on 2026-10-08 was 456, of which 16 are in a blockquote.
# A scan that found none would pass every row it never read; the floor is set under the count so
# that removing a note does not trip it.
$TABLE_FLOOR = 420

function Split-TableRow {
    <#  The cells of one table line. The outer pipes are the row's edges and not separators.  #>
    param([Parameter(Mandatory)] [string] $Line)

    $inner = $Line.Trim() -replace '^\|', '' -replace '(?<!\\)\|$', ''
    return , @([regex]::Split($inner, '(?<!\\)\|'))
}

function Find-MisshapenTableRows {
    <#  Every delimiter row and body row whose cell count is not its header's, or that sits at a
        different blockquote depth from its header, and how many tables were read.

        Returns one object: Tables, the count, and Found, a list of the file, the line, which kind
        of fault it is and the two counts. The count of tables is returned beside the findings for
        the reason Find-LooseFigureRows returns its own.  #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Files, [string] $Root)

    $found  = [System.Collections.Generic.List[object]]::new()
    $tables = 0
    foreach ($rel in $Files) {
        $full = if ($Root) { Join-Path $Root $rel } else { $rel }
        if (-not (Test-Path -LiteralPath $full)) { continue }   # tracked, deleted, not yet staged
        $lines  = @(Get-Content -LiteralPath $full -Encoding utf8)
        # Each line with its blockquote marks taken off, and how many it had. A quoted table is a
        # table like any other once the marks are gone, and the count is what catches a row that
        # lost one.
        $texts  = [string[]]::new($lines.Count)
        $depths = [int[]]::new($lines.Count)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $text = $lines[$i].Trim()
            if ($text.StartsWith('>')) {
                $marks      = [regex]::Match($text, '^(?:>\s*)+')
                $depths[$i] = ($marks.Value -replace '[^>]', '').Length
                $text       = $text.Substring($marks.Length)
            }
            $texts[$i] = $text
        }
        $fenced     = $false
        $fenceDepth = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($fenced -and $depths[$i] -lt $fenceDepth) { $fenced = $false }
            if ($texts[$i] -match '^(?:```|~~~)') { $fenced = -not $fenced; $fenceDepth = $depths[$i]; continue }
            if ($fenced -or -not $texts[$i].StartsWith('|')) { continue }
            $end = $i + 1
            while ($end -lt $lines.Count -and $texts[$end].StartsWith('|')) {
                $newTable = $depths[$end] -ne $depths[$i] -and $end + 1 -lt $lines.Count -and
                            $depths[$end + 1] -eq $depths[$end] -and $texts[$end + 1] -match $TABLE_DELIMITER
                if ($newTable) { break }
                $end++
            }
            if ($end - $i -ge 2 -and $texts[$i + 1] -match $TABLE_DELIMITER) {
                $tables++
                $want = (Split-TableRow -Line $texts[$i]).Count
                for ($row = $i + 1; $row -lt $end; $row++) {
                    $have = (Split-TableRow -Line $texts[$row]).Count
                    if ($have -ne $want) {
                        $found.Add([pscustomobject]@{ File = $rel; Line = $row + 1
                            Kind   = if ($row -eq $i + 1) { 'delimiter' } else { 'row' }
                            Detail = "$have cells where the header has $want" })
                    }
                    if ($depths[$row] -ne $depths[$i]) {
                        $found.Add([pscustomobject]@{ File = $rel; Line = $row + 1; Kind = 'quote'
                            Detail = "$($depths[$row]) blockquote mark(s) where the header has $($depths[$i])" })
                    }
                }
            }
            $i = $end - 1
        }
    }
    return [pscustomobject]@{ Tables = $tables; Found = $found }
}

$tableRows = Find-MisshapenTableRows -Files @($tracked | Where-Object { $_ -match '\.md$' }) -Root $repoRoot

$checks++
if ($tableRows.Tables -lt $TABLE_FLOOR) {
    $failures.Add(("only $($tableRows.Tables) table(s) were found in the tracked markdown, against a " +
        "floor of $TABLE_FLOOR set under the count section 11 last recorded. Either a great many were removed, " +
        'which is a decision to record by lowering the floor, or the scan stopped finding them.'))
}
$checks++
foreach ($row in $tableRows.Found) {
    $what = switch ($row.Kind) {
        'delimiter' { 'has a delimiter row that does not match its header, so GitHub renders no table' }
        'quote'     { 'has a row that is not in the blockquote its header is in, so GitHub ends the table above it' }
        default     { 'has a row GitHub will pad or cut' }
    }
    $hint = if ($row.Kind -ceq 'quote') {
        'Every line of a quoted table carries the mark.'
    } else {
        'A pipe inside a cell is written with a backslash before it, inline code included.'
    }
    $failures.Add("$($row.File), line $($row.Line): a table $what -- $($row.Detail). $hint")
}

if ($failures.Count) {
    Write-Host ''
    foreach ($f in $failures) { Write-Host "FAIL  $f" -ForegroundColor Red }
    Write-Host ''
    Write-Host ("{0} of {1} checks failed." -f $failures.Count, $checks) -ForegroundColor Red
    Write-Host 'See docs/adr/0003-space-age-tolerated-not-targeted.md,'
    Write-Host '    docs/adr/0006-clean-break-from-predecessor-saves.md and'
    Write-Host '    docs/adr/0023-art-ships-in-its-own-mod.md for why these are obligations.'
    exit 1
}

if ($SelfTest) {
    # After the sections, not instead of them: a gate proved against a repository that is already
    # failing tells nobody which of the two broke.
    Write-Host ''
    $planted = Join-Path ([IO.Path]::GetTempPath()) ('rf-shipcheck-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $planted -Force | Out-Null
    try {
        Invoke-SelfTestHalves -Halves @(
            @{ Name = 'self-test-runner'; Body = { Test-SelfTestRunner } }

            @{ Name = 'ordinal-citation-caught'; Body = {
                # Section 9 passes by finding nothing, so nothing in a green run says the patterns
                # still match. This plants one citation per form, in prose, and requires each to be
                # reported with the file and the words it matched.
                $doc = Join-Path $planted 'numbered.md'
                # One line per form, and the last is the OVERLAP: the labelled form contains the
                # integer form, so a scan that applied the patterns in turn reported that one line
                # twice. One citation is one finding.
                @(
                    'The canary is half six, one for each direction.'
                    'Halves six and seven are the pair.'
                    'The stall detector is half 5 of this gate.'
                    'It was proved by -SelfTest 3/7 before the runner.'
                    'See self-test half 5 of the bench.'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $caught = @(Find-NumberedHalves -Files @($doc))
                if ($caught.Count -ne 5) {
                    throw ("a document citing halves by ordinal five ways was reported " +
                           "$($caught.Count) time(s): $(($caught | ForEach-Object { $_.Cited }) -join ', '). " +
                           'Section 9 is not matching what it claims to, or it is matching one line twice.')
                }
                foreach ($row in $caught) {
                    if ($row.File -cne $doc -or $row.Line -lt 1) {
                        throw "a finding does not name the file and line it was found on: $($row | Out-String)"
                    }
                }
                $perLine = @($caught | Group-Object Line | Where-Object { $_.Count -ne 1 })
                if ($perLine) {
                    throw ("line(s) $(($perLine | ForEach-Object { $_.Name }) -join ', ') produced more than " +
                           'one finding, so one citation is being reported twice and any count over ' +
                           'the result is inflated.')
                }
                "a document citing a half by ordinal is caught, five ways, each named with its file and line, each once."
            } }

            @{ Name = 'named-citation-not-flagged'; Body = {
                # The other direction, and it is not decoration: a gate that fired on everything
                # would be switched off, and it would fire on the very sentences this rule asks
                # people to write. The measurement words are here too -- a supply level called half
                # with a wattage after it is what check-brownout's note tabulates.
                $doc = Join-Path $planted 'named.md'
                @(
                    'The added-category and replaced-category halves are the canaries.'
                    'The stall-detector half holds all three directions.'
                    'It cut the sheet in half a tile above the socket.'
                    'full drew 55.17 MW, half 27.57 MW, blackout 0 MW'
                    # The same row with whole numbers, which reads exactly like a citation once the
                    # decimal is gone. The unit is what tells them apart.
                    'full drew 55 MW, half 27 MW, blackout 0 MW'
                    'The repo-loads half must pass or the halves after it prove nothing.'
                    # A pasted transcript, which is how this repository records a measurement. It is
                    # quoted output rather than a citation, and the fence is what says so.
                    '```'
                    'self-test 3/13: a prototype naming a file that is not there is caught.'
                    '  5/7 ok: the stall is flagged at tick 876.'
                    '```'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $flagged = @(Find-NumberedHalves -Files @($doc))
                if ($flagged.Count) {
                    throw ('prose naming its halves, a measurement after the word half, or a run ' +
                           'pasted inside a fence, were ' +
                           "reported as ordinal citations: $(($flagged | ForEach-Object { $_.Cited }) -join ', '). " +
                           'A gate that fires on the sentences the rule asks for gets switched off.')
                }
                ('prose that names its halves, a measurement after the same word whole or decimal, ' +
                 'and a pasted transcript inside a fence, are all left alone.')
            } }

            @{ Name = 'figure-anchor-resolves'; Body = {
                # Section 10 passes by finding nothing loose. Two rows whose Section links differ
                # only in whether a heading answers them: the second "Results" is reachable as
                # results-1 and as nothing else, which is the suffix a renamed or added heading
                # moves.
                $doc = Join-Path $planted 'anchors.md'
                @(
                    '# A note'
                    ''
                    '## Current figures'
                    ''
                    '| Figure | Value | Measured | Game version | Research state | Section |'
                    '|---|---|---|---|---|---|'
                    '| Cost, second sitting | 5.257 µs | 2026-09-20 | 2.0.77 | not stated | [Results](#results-1) |'
                    '| Cost, a sitting nobody wrote | 5.257 µs | 2026-09-20 | 2.0.77 | not stated | [Results](#results-2) |'
                    ''
                    '## Results'
                    ''
                    '## Results'
                    ''
                    'The median was 5.257 µs.'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $read = Find-LooseFigureRows -Files @($doc)
                $rows = @($read.Found)
                if ($read.Tables -ne 1) { throw "the planted note's table was counted $($read.Tables) time(s), not once." }
                if ($rows.Count -ne 1 -or $rows[0].Kind -cne 'anchor' -or $rows[0].Line -ne 8) {
                    throw ('a row linking to a heading the note has and a row linking to one it does not ' +
                           "produced: $(($rows | ForEach-Object { "line $($_.Line) $($_.Kind) ($($_.Detail))" }) -join '; '). " +
                           'Wanted exactly one finding, kind anchor, on line 8.')
                }
                'a row whose Section link names no heading is caught on its line, and the row beside it, linking to a repeated heading by its suffix, is left alone.'
            } }

            @{ Name = 'figure-value-in-note'; Body = {
                # The other assertion, both directions again. The good rows are the shapes a real
                # table holds: a figure grouped in thousands and wrapped across a line end in the
                # prose, and two figures in one cell. The bad row is a figure re-measured in its
                # section and not in its row -- and the stale one must not be found inside the
                # longer figure that replaced it. The second bad row is the same mistake in a
                # grouped figure: its three-digit groups are the tail of the tick the note writes.
                $doc = Join-Path $planted 'values.md'
                @(
                    '# A note'
                    ''
                    '## Current figures'
                    ''
                    '| Figure | Value | Measured | Game version | Research state | Section |'
                    '|---|---|---|---|---|---|'
                    '| Settle tick | 1 980 000 | 2026-10-05 | 2.0.77 | unresearched | [Readings](#readings) |'
                    '| Output range | 48.3 – 58.0 MW | 2026-10-03 | 2.0.77 | unresearched | [Readings](#readings) |'
                    '| D-D Q | 0.32 | 2026-08-17 | none (pure simulation) | unresearched | [Readings](#readings) |'
                    '| Window | 980 000 | 2026-10-05 | 2.0.77 | unresearched | [Readings](#readings) |'
                    '| Ceiling | 2e+09 C | 2026-08-17 | 2.0.77 | unresearched | [Readings](#readings) |'
                    ''
                    '## Readings'
                    ''
                    'The box settles by tick 1 980'
                    '000 and sells 48.3 – 58.0 MW. Q is 0.3205. The clamp read 2e+09 C.'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $rows = @((Find-LooseFigureRows -Files @($doc)).Found)
                $lines = @($rows | ForEach-Object { $_.Line } | Sort-Object)
                if ($rows.Count -ne 2 -or ($rows | Where-Object { $_.Kind -cne 'value' }) -or
                    $lines[0] -ne 9 -or $lines[1] -ne 10) {
                    throw ('three rows whose figures the note writes and two whose figures it does not ' +
                           "produced: $(($rows | ForEach-Object { "line $($_.Line) $($_.Kind) ($($_.Detail))" }) -join '; '). " +
                           'Wanted exactly two findings, kind value, on lines 9 and 10.')
                }
                'a row whose figure is written nowhere below the table is caught on its line, as is one whose figure is only the tail of a longer grouped one; a wrapped thousands figure, a two-figure cell and an exponent with a plus sign are left alone.'
            } }

            @{ Name = 'table-row-cells-caught'; Body = {
                # Section 11 passes by finding nothing misshapen. One table with a row too long and
                # a row too short, and a second whose delimiter row is a cell short. The long row
                # is the shape that is easy to write: a pipe inside inline code, which GitHub
                # counts.
                $doc = Join-Path $planted 'misshapen.md'
                @(
                    '| Gate | Reads | Runs a game |'
                    '|---|---|---|'
                    '| ship-check | prose | no |'
                    '| load-check | `a | b` | yes |'
                    '| name-check | a dump |'
                    ''
                    '| Gate | Reads | Runs a game |'
                    '|---|---|'
                    '| ship-check | prose | no |'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $read = Find-MisshapenTableRows -Files @($doc)
                $rows = @($read.Found | ForEach-Object { "$($_.Line) $($_.Kind)" })
                if ($read.Tables -ne 2 -or ($rows -join '; ') -cne '4 row; 5 row; 8 delimiter') {
                    throw ("two planted tables, one with a row of four cells and a row of two under a " +
                           "header of three, one with a delimiter row of two, were read as $($read.Tables) " +
                           "table(s) with: $($rows -join '; '). Wanted two tables and exactly " +
                           "'4 row; 5 row; 8 delimiter'.")
                }
                'a row with a cell too many, a row with a cell too few and a delimiter row a cell short are each caught on their line; the long row is a pipe inside inline code.'
            } }

            @{ Name = 'quoted-table-caught'; Body = {
                # A blockquoted table is held to the same counts, and to one more thing: every row
                # carries the mark its header carries. The second planted table is the defect
                # #650's review found by reading, a last row that had lost its `>`.
                $doc = Join-Path $planted 'quoted.md'
                @(
                    '> | Release | Attribution |'
                    '> |---|---|'
                    '> | 0.2.0 | one | two |'
                    ''
                    '> | Release | Attribution |'
                    '> |---|---|'
                    '> | 1.2.0 | kept its mark |'
                    '| 1.8.0 | lost its mark |'
                    ''
                    '> | Release | Attribution | Source |'
                    '> |---|---|'
                    '> | 1.3.13 | a credit | a changelog |'
                    ''
                    '> ```'
                    '> a fence the end of the quote closes'
                    ''
                    '| Release | Attribution |'
                    '|---|---|'
                    '| 1.8.18 | one | two |'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $read = Find-MisshapenTableRows -Files @($doc)
                $rows = @($read.Found | ForEach-Object { "$($_.Line) $($_.Kind)" })
                if ($read.Tables -ne 4 -or ($rows -join '; ') -cne '3 row; 8 quote; 11 delimiter; 19 row') {
                    throw ("four planted tables -- three blockquoted, with a row of three cells under a " +
                           "header of two, a last row with no blockquote mark and a delimiter row a " +
                           "cell short, then one after a quoted fence that only the quote's end closes -- " +
                           "were read as $($read.Tables) table(s) with: $($rows -join '; '). Wanted four " +
                           "tables and exactly '3 row; 8 quote; 11 delimiter; 19 row'.")
                }
                'inside a blockquote, a row with a cell too many, a row that has lost its mark and a delimiter row a cell short are each caught on their line, and a table after a quoted fence that only the end of the quote closes is still read.'
            } }

            @{ Name = 'table-shape-not-flagged'; Body = {
                # The other direction. An escaped pipe is one cell, a row may leave off its closing
                # pipe, a cell may be empty, a misshapen table inside a fence is quoted text, a
                # wrapped line of prose that starts with a pipe is no table, and a well-formed
                # table inside a blockquote, nested or not, is a table.
                $doc = Join-Path $planted 'shapely.md'
                @(
                    '| Gate | Reads | Runs a game |'
                    '|:---|---:|:---:|'
                    '| ship-check | `a \| b` | no |'
                    '| load-check | a dump | yes'
                    '| name-check | | no |'
                    ''
                    '```'
                    '| Gate | Reads |'
                    '|---|---|'
                    '| ship-check | prose | no |'
                    '```'
                    ''
                    'The layer is one of `"entity-info-icon"`'
                    '| `"air-entity-info-icon"`, and vanilla uses the first.'
                    ''
                    '> | Release | Attribution |'
                    '> |---|---|'
                    '> | 0.2.0 | a credit |'
                    ''
                    '> > | Release | Attribution |'
                    '>> |---|---|'
                    '> >| 1.2.0 | another |'
                    ''
                    # Two tables with no blank line between them, the second in a quote. They are
                    # two tables, and the second is not the first one's rows gone astray.
                    '| Gate | Reads |'
                    '|---|---|'
                    '| ship-check | prose |'
                    '> | Release | Attribution | Source |'
                    '> |---|---|---|'
                    '> | 0.2.0 | a credit | a changelog |'
                ) | Set-Content -LiteralPath $doc -Encoding utf8

                $read = Find-MisshapenTableRows -Files @($doc)
                if ($read.Tables -ne 5 -or $read.Found.Count) {
                    throw ("a well-formed table, a table inside a fence, a line of prose starting " +
                           "with a pipe, two well-formed blockquoted tables and a plain table with a " +
                           "quoted one directly under it were read as $($read.Tables) table(s) with: " +
                           "$(($read.Found | ForEach-Object { "line $($_.Line) $($_.Kind) ($($_.Detail))" }) -join '; '). " +
                           'Wanted five tables and no finding.')
                }
                'an escaped pipe, a row with no closing pipe, an empty cell, a table inside a fence, prose that starts with a pipe, a well-formed table inside a blockquote, nested or not, and a quoted table directly under a plain one are all left alone.'
            } }
        )
    } finally { Remove-Item -LiteralPath $planted -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    Write-Host '-SelfTest: PASS' -ForegroundColor Green
    exit 0
}

Write-Host ("ship-check: {0} checks, 0 failures." -f $checks) -ForegroundColor Green
Write-Host 'The clean break and the quality gap are stated in both code mods and in README.md; the'
Write-Host 'licence and the scope rule ship inside all three; the assets floor matches, no code mod'
Write-Host 'ships art, every accent named for a fluid still carries that fluid''s own colour, and'
Write-Host 'no prose cites a self-test half by position, every Current figures row still names a'
Write-Host 'heading and a figure its note has, and every table row has as many cells as its header.'
exit 0
