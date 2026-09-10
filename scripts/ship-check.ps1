<#
.SYNOPSIS
    Fails if the claims the shipped mods make about themselves have stopped being true, if the
    scripts in this directory have stopped answering Get-Help, if any prose cites one of our own
    files by line number, or if a docs/ note this repo cites
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
    lines off reads as correct. Two citations merged in #306 pointing at the wrong field anyway, so
    read that bet as a bet.

    There is no -SelfTest here, unlike the checks that read a Factorio dump. Those need one because
    they can pass by finding nothing; sections 1 to 4 name every file and string they require, so a
    mistake in them fails rather than goes quiet.

    SECTIONS 5, 6 AND 7 ARE THE EXCEPTION, and are stated here rather than left to be discovered.
    Each selects by scanning and matching a predicate, so each is exactly the shape that can pass by
    finding nothing. What stands in for a self-test is a floor: section 5 fails when a script opens
    with a comment block but is not in scope, and sections 6 and 7 fail when they find too few
    citations to believe -- section 7 twice over, once per shape it matches. That is narrower than a
    -SelfTest would be, because a floor cannot see a mistake in the scan itself -- break that and
    there is nothing left to check and so nothing left to fail.

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
#      dag-layout-algorithms.md carries `11(2):109-125` and three more citations shaped exactly
#      like it -- and measured on 2026-09-10 over the files this check actually reads, with the same
#      skip filter, the loose `:\d+` matches around 250 places against this one's two dozen. (A
#      tenfold larger
#      figure is available by counting tools/endf/*.json too, and would be dishonest here: those are
#      the datasets the list below excludes by name for exactly this reason.) A gate that cried wolf
#      on bibliography entries gets switched off, which is the same failure the ambiguity exemption
#      above already refuses to risk.
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
# continuations
# judged OURS, because that number is zero and is meant to be -- every one in the tree is either
# unattributable or inherits an ambiguous path. So it counts the shape being FOUND, which is what
# proves the pattern still matches.
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
