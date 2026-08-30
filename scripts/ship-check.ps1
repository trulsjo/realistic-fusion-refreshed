<#
.SYNOPSIS
    Fails if the claims the shipped mods make about themselves have stopped being true, if the
    scripts in this directory have stopped answering Get-Help, or if a docs/ note this repo cites
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

    There is no -SelfTest here, unlike the checks that read a Factorio dump. Those need one because
    they can pass by finding nothing; sections 1 to 4 name every file and string they require, so a
    mistake in them fails rather than goes quiet.

    SECTION 5 IS THE EXCEPTION, and is stated here rather than left to be discovered. It selects by
    scanning this directory and matching a predicate, so it is exactly the shape that can pass by
    finding nothing. What stands in for a self-test is its floor: a script that opens with a comment
    block but is not in scope fails. That is narrower than a -SelfTest would be, because it cannot
    see a mistake in the scan itself -- break that and there is nothing left to check and so nothing
    left to fail.

.EXAMPLE
    pwsh -File scripts/ship-check.ps1
#>

#Requires -Version 7

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot/factorio-lib.ps1"   # for Get-RepoMods only; this script still starts no game.

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
$citing = @(Get-ChildItem $PSScriptRoot -File -Filter *.ps1) +
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

Write-Host ("ship-check: {0} checks, 0 failures." -f $checks) -ForegroundColor Green
Write-Host 'The clean break and the quality gap are stated in both code mods and in README.md; the'
Write-Host 'licence and the scope rule ship inside all three; the assets floor matches and no code mod'
Write-Host 'ships art.'
exit 0
