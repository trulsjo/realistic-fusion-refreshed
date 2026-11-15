<#
.SYNOPSIS
    Runs every gate in the repository, one after another, and prints one line per gate. Exits
    non-zero naming each gate that failed (#567), and each tracked path that changed while it ran
    (#812).

.DESCRIPTION
    FOR AN INTEGRATED BRANCH, BEFORE A REVIEW. Each ticket's author runs the gates its own change
    touches. #557 combined seven such changes, and one of them broke a gate its author had no
    reason to run: #555 changed how control.lua writes UPDATE_INTERVAL, which the Lua suites, the
    ship check and the load check all passed, and check-pooling.ps1 reads that line by its shape.
    It was caught because the gates were run by hand on the combined tree. This is that step.

    NOT FOR A MARKDOWN-ONLY BRANCH (#618, decided 2026-10-07). When every path
    `git diff --name-only --no-renames origin/main...HEAD` prints ends in .md, with origin/main
    fetched first (#755, #758), the branch runs ship-check.ps1 alone, because no other gate
    here reads a .md file. --no-renames makes a file renamed to .md print the path it had. One
    path that does not end in .md, a comment-only
    edit to a script included, and it runs everything: check-pooling.ps1 reads control.lua by
    its shape, which is the failure above. This script does not look at the diff. The session
    decides, and the pre-PR reviewer checks the paths.

    WHAT IT RUNS, in this order:

      the Lua suites           every tests/test-*.lua, with `lua` from PATH
      six tools' self-tests    tools/refuse-hanging-bash.py, review-usage.py, rewrap.py,
                               review-coverage.py, mesh-overlap.py and compare-sheets.py, each
                               with --self-test and `python` from PATH (#659, #787, #850, #853)
      test_rf_blender          models/test_rf_blender.py, with `python` from PATH and no
                               argument: the render's arithmetic, without Blender (#810)
      ship-check.ps1           no game
      load-check.ps1           the default load, from the junctioned repository
      check-*.ps1              every scripts/check-*.ps1, found by name, so a new one is picked up

    Each is its own process with its default arguments. A gate that fails does not stop the run:
    the rest still run, so one invocation says everything that is broken.

    A TREE THAT MOVED FAILS THE RUN (#812), whatever the gates found. It takes a fingerprint of
    every tracked file and of the index before the first gate, again after each gate until one
    differs, and once more at the end. A difference exits non-zero, naming each path that changed
    and the gate after which it was first seen, because a run whose gates read different trees
    describes none of them. A file git does not track, such as a log or a report the gates write,
    is not in the fingerprint. On 2026-10-27 one took about 2 s with the files in the disk cache,
    so about a minute over the 26 gates, and 25 s in a fresh clone.

    A COMMIT DURING A RUN IS REFUSED (#872), where .githooks/pre-commit is installed. The run
    writes a git-ignored .gates-running at the root holding its process ID and start time, and
    removes it in a finally; the hook refuses a commit while that names a live process, and
    ignores one left by a run stopped from outside. An edit with no commit is not refused, and
    the fingerprint above stays the guard against it.

    THE SIX TOOLS ARE NOT GATES, and a self-test is all that checks each. None of them runs in
    any gate: one is a hook that judges every Bash tool call on a machine that registers it, and
    five are run by hand by the session that needs them. #656's pre-PR review found a defect in what the hook
    refuses six times, and each fix was checked by running its self-test by hand. The first four
    need Python and nothing installed into it. mesh-overlap.py's needs Blender, found the way
    tools/render-machine.py finds it, and compare-sheets.py's needs Pillow; a missing one fails
    that self-test with a message rather than skipping it, and neither runs in gates.yml, whose
    runner has neither (#850, #853).

    MODELS/TEST_RF_BLENDER.PY IS A GATE OF ITS OWN (#810). It pins the arithmetic the rendered
    sheets are declared from, and since #809 it is the self-test of #800's footprint-edge check.
    It touches no bpy, so it needs Python and nothing installed, the same as the first four tools.

    WHAT IT DOES NOT RUN. No probe: a probe asserts nothing, and exit 0 from one means it reported.
    No -SelfTest of any gate, and not load-check.ps1 -FromZips, locale-check.ps1 or name-check.ps1:
    the first two prove a gate or a packaging and the last two read a prototype dump, and none of
    them is what an integration breaks first. Run them as CLAUDE.md and
    docs/agents/shipping.md say, before anything ships.

    ONE GAME AT A TIME. The gates start Factorio, and they run in sequence here on purpose.

    AND BEFORE OR AFTER A SUBAGENT FAN-OUT, NOT DURING ONE (#617). Measured on this machine:

      21 gates, nothing else running        4 min 45 s     2026-10-05
      21 gates, six subagents reading       24 min 50 s    2026-10-06
      ship-check.ps1 inside that run        10 min 59 s    2026-10-06
      ship-check.ps1 -SelfTest, quiet       1 min 20 s     2026-10-06
      the same beside four subagents        over 10 min    2026-10-06
      git status --short, quiet             0.24 s         2026-10-06
      gh issue view <n> --json, quiet       1.1 s          2026-10-06

    Nothing failed in the slow run; the session waited, and four of its shell commands, each a few
    git or gh calls, ran past timeouts of 30, 60 and 120 s. The cause was not isolated: the quiet
    git and gh figures were taken later the same day, after the subagents had finished, and neither
    was timed alone under load. The subagents started no game. They read research notes. The
    four-subagent row is a lower bound: the run was still going when a 600 s timeout moved it to the
    background, and it passed.

.PARAMETER Only
    Run only the gates whose name matches this wildcard, e.g. 'check-p*' or 'test-*'.

.PARAMETER SelfTest
    Prove the runner with stand-in gates and no game: `failing-gate-reported` requires a gate that
    fails to be returned by name as failed while one that passes beside it is still reported as
    passing, and `missing-executable-fails` requires a gate whose executable is missing to be
    reported as failed and not as passing. Since #578 two more halves run this script itself, as its own process, over stand-in
    gates in place of the real ones: `exit-code-names-failure` requires a non-zero exit and the
    failing stand-in named in what it prints, and `exit-code-clean` requires exit 0 when every
    stand-in passes. Deleting the branch that turns the failed list into an exit code fails the
    first. Since #812 the stand-ins write to a scratch git repository watched in place of this
    one: `tree-change-fails` has a passing stand-in edit a tracked file there and requires a
    non-zero exit naming the file and that stand-in, and `ignored-write-clean` has one write only
    a git-ignored file and requires exit 0. Since #872 every stand-in run also requires that it
    left no .gates-running behind, a failing one's included; `commit-refused-during-run` has a
    stand-in commit in its scratch tree through this repository's .githooks and requires
    pre-commit to refuse it naming the process the marker holds; and `stale-marker-ignored`
    plants a marker naming a process that has exited and requires the commit to go through, the
    hook saying the marker was stale.

.EXAMPLE
    pwsh -File scripts/run-gates.ps1
    pwsh -File scripts/run-gates.ps1 -Only 'test-*'
    pwsh -File scripts/run-gates.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Only = '*',
    [switch] $SelfTest,
    # The self-test's alone: comma-separated exit codes, one stand-in gate each, run in place of
    # every real gate, so the exit code below is reached by the same lines a real run takes. An
    # entry 'edit' appends to -StandInTree's tracked.txt and 'ignored' writes its ignored.txt,
    # each exiting 0.
    [Parameter(DontShow)] [string] $StandInExits,
    # The self-test's alone: the scratch git repository the stand-ins write to, watched in place
    # of the repository.
    [Parameter(DontShow)] [string] $StandInTree
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent

function Invoke-Gates {
    <#  Run each gate, print its line, and return the names that failed. A gate is a Name, an
        executable and its arguments; it passes on exit 0 and on nothing else.  #>
    param([Parameter(Mandatory)] [object[]] $Gates, [Parameter(Mandatory)] [string] $LogDirectory,
          # Handed each gate's name once it has run: the run's watch on the tree.
          [scriptblock] $AfterEach)

    $failed = @()
    foreach ($gate in $Gates) {
        $log   = Join-Path $LogDirectory "$($gate.Name).log"
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $code  = -1
        try {
            & $gate.Exe @($gate.Arguments) *> $log
            $code = $LASTEXITCODE
        } catch {
            # An executable that is not there is a failed gate with a message, not a skipped one.
            Add-Content -Path $log -Value "$_"
        }
        $took = '{0:mm\:ss}' -f $watch.Elapsed
        if ($code -eq 0) {
            Write-Host ("  PASS  {0,-24} {1}" -f $gate.Name, $took)
        } else {
            $failed += $gate.Name
            Write-Host ("  FAIL  {0,-24} {1}  exit {2}; the tail of its output:" -f $gate.Name, $took, $code) -ForegroundColor Red
            Get-Content $log -Tail 12 | ForEach-Object { Write-Host "          $_" }
        }
        if ($AfterEach) { & $AfterEach $gate.Name }
    }
    return , $failed
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('rf-gates-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$pwsh = (Get-Process -Id $PID).Path

if ($SelfTest) {
    function Invoke-StandInRun([string] $Exits) {
        <#  This script as its own process over stand-in gates and a scratch tree of its own, with
            what it printed returned and its exit code left in $LASTEXITCODE.  #>
        $tree = New-ScratchGitTree -Parent $temp
        $out  = & $pwsh -NoProfile -File $PSCommandPath -StandInExits $Exits -StandInTree $tree 2>&1
        $code = $LASTEXITCODE
        # Every way out, a failing run's included, takes the run's marker with it (#872).
        if (Test-Path -LiteralPath "$tree/.gates-running") {
            throw "a stand-in run over '$Exits' exited $code and left its .gates-running behind:`n$($out | Out-String)"
        }
        # A failing run keeps its logs, which a real one should; this one's are the self-test's.
        $logs = @($out | ForEach-Object { "$_" } | Where-Object { $_ -match 'Logs: (.+)$' } | ForEach-Object { $Matches[1].Trim() })[0]
        if ($logs -like '*rf-gates-*') { Remove-Item -Recurse -Force $logs -ErrorAction SilentlyContinue }
        $global:LASTEXITCODE = $code
        return $out
    }

    function Invoke-HookedCommit([string] $Tree) {
        <#  A commit in a scratch tree through this repository's hooks, with what git and the
            hooks printed returned and git's exit code left in $LASTEXITCODE.  #>
        $out = & git -C $Tree -c "core.hooksPath=$repoRoot/.githooks" -c user.name=stand-in `
            -c user.email=stand-in@example.invalid commit -q -m stand-in 2>&1
        $global:LASTEXITCODE = $LASTEXITCODE
        return $out
    }

    try { Invoke-SelfTestHalves -Halves @(
        @{ Name = 'failing-gate-reported'; Body = {
            $standIns = @(
                @{ Name = 'stand-in-green'; Exe = $pwsh; Arguments = @('-NoProfile', '-Command', 'exit 0') }
                @{ Name = 'stand-in-red';   Exe = $pwsh; Arguments = @('-NoProfile', '-Command', 'Write-Output planted; exit 3') }
                @{ Name = 'stand-in-after'; Exe = $pwsh; Arguments = @('-NoProfile', '-Command', 'exit 0') }
            )
            $failed = Invoke-Gates -Gates $standIns -LogDirectory $temp 6>$null
            if (@($failed).Count -ne 1 -or $failed[0] -ne 'stand-in-red') {
                throw "a stand-in gate exiting 3 between two that exit 0 was reported as: '$($failed -join ', ')'"
            }
            'a gate that fails is named, and the gates beside it still run and pass.'
        } }
        @{ Name = 'missing-executable-fails'; Body = {
            $failed = Invoke-Gates -LogDirectory $temp 6>$null -Gates @(
                @{ Name = 'stand-in-absent'; Exe = 'rf-no-such-executable'; Arguments = @() })
            if (@($failed).Count -ne 1) { throw 'a gate whose executable does not exist was reported as passing.' }
            'a gate whose executable is missing fails rather than being skipped.'
        } }
        @{ Name = 'exit-code-names-failure'; Body = {
            $out = Invoke-StandInRun '0,3,0'
            $code = $LASTEXITCODE
            if ($code -eq 0) { throw "the script exited 0 with a stand-in gate exiting 3:`n$($out | Out-String)" }
            if (-not ($out | Where-Object { "$_" -match '^FAIL - 1 of 3 gate\(s\) failed .*: stand-in-2$' })) {
                throw "the script exited $code but its last line did not name stand-in-2 alone:`n$($out | Out-String)"
            }
            "a failing stand-in gate makes the script exit $code, naming it."
        } }
        @{ Name = 'exit-code-clean'; Body = {
            $out = Invoke-StandInRun '0,0'
            if ($LASTEXITCODE -ne 0) { throw "the script exited $LASTEXITCODE with every stand-in gate passing:`n$($out | Out-String)" }
            'every stand-in gate passing makes the script exit 0.'
        } }
        @{ Name = 'tree-change-fails'; Body = {
            # Every stand-in passes, and the second edits a tracked file of the scratch tree.
            $out = Invoke-StandInRun '0,edit,0'
            $code = $LASTEXITCODE
            if ($code -eq 0) { throw "the script exited 0 with a tracked file edited during the run:`n$($out | Out-String)" }
            $lines = @($out | ForEach-Object { "$_" })
            if (-not ($lines -match '^FAIL - .*first seen after stand-in-2\b')) {
                throw "the script exited $code but did not say the change was first seen after stand-in-2:`n$($out | Out-String)"
            }
            if (-not ($lines -match '^\s+tracked\.txt \(working tree\)$')) {
                throw "the script exited $code but did not name tracked.txt:`n$($out | Out-String)"
            }
            "a tracked file edited during a run of passing gates makes the script exit $code, naming it and the gate."
        } }
        @{ Name = 'ignored-write-clean'; Body = {
            # The tracked tree stands still; a stand-in writes the file the scratch tree ignores.
            $out = Invoke-StandInRun '0,ignored'
            if ($LASTEXITCODE -ne 0) { throw "the script exited $LASTEXITCODE when only a git-ignored file was written:`n$($out | Out-String)" }
            'a run that writes only a git-ignored file exits 0, as it did before the tree was watched.'
        } }
        @{ Name = 'commit-refused-during-run'; Body = {
            # The second stand-in commits in the scratch tree through this repository's hooks, and
            # exits 0 only when pre-commit refuses it naming the process the run's marker holds.
            $out = Invoke-StandInRun '0,commit,0'
            if ($LASTEXITCODE -ne 0) { throw "a commit during a run was not refused naming the run:`n$($out | Out-String)" }
            'a commit attempted during a live run is refused by pre-commit, naming the run.'
        } }
        @{ Name = 'stale-marker-ignored'; Body = {
            # A marker naming a process that has exited, as a run stopped from outside leaves one.
            $gone = Start-Process $pwsh -ArgumentList '-NoProfile', '-Command', 'exit 0' -PassThru -WindowStyle Hidden
            $gone.WaitForExit()
            $tree = New-ScratchGitTree -Parent $temp
            "$($gone.Id)", (Get-Date).ToUniversalTime().ToString('o') | Set-Content -LiteralPath "$tree/.gates-running"
            $out  = Invoke-HookedCommit -Tree $tree
            $code = $LASTEXITCODE
            if ($code -ne 0) { throw "a commit with a stale .gates-running exited ${code}:`n$($out | Out-String)" }
            if (-not (@($out | ForEach-Object { "$_" }) -match "names process $($gone.Id),.*stale")) {
                throw "a commit with a stale .gates-running went through without saying the marker was stale:`n$($out | Out-String)"
            }
            'a commit with a stale .gates-running goes through, saying the marker was stale.'
        } }
    ) } finally { Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue }
    Write-Host '-SelfTest: PASS' -ForegroundColor Green
    exit 0
}

$gates = @()
foreach ($suite in Get-ChildItem (Join-Path $repoRoot 'tests') -Filter 'test-*.lua' | Sort-Object Name) {
    $gates += @{ Name = $suite.BaseName; Exe = 'lua'; Arguments = @($suite.FullName) }
}
# Named and not found: most of tools/*.py have no --self-test, and would read it as a file name.
foreach ($tool in 'refuse-hanging-bash', 'review-usage', 'rewrap', 'review-coverage', 'mesh-overlap', 'compare-sheets') {
    $gates += @{ Name = $tool; Exe = 'python'
                 Arguments = @((Join-Path $repoRoot "tools/$tool.py"), '--self-test') }
}
# A plain script, not a --self-test: it exits 0 or raises (#810).
$gates += @{ Name = 'test_rf_blender'; Exe = 'python'
             Arguments = @((Join-Path $repoRoot 'models/test_rf_blender.py')) }
$scripts = @('ship-check.ps1', 'load-check.ps1') +
    @(Get-ChildItem $PSScriptRoot -Filter 'check-*.ps1' | Sort-Object Name | ForEach-Object Name)
foreach ($script in $scripts) {
    $gates += @{ Name = [IO.Path]::GetFileNameWithoutExtension($script); Exe = $pwsh
                 Arguments = @('-NoProfile', '-File', (Join-Path $PSScriptRoot $script)) }
}
$treeRoot = $repoRoot
if ($StandInExits) {
    # Never the repository: a stand-in that edits writes into the tree this run watches.
    if (-not $StandInTree) { throw '-StandInExits needs -StandInTree, a scratch git repository.' }
    $treeRoot = $StandInTree
    $i = 0
    $gates = @(foreach ($exit in $StandInExits -split ',') {
        $i++
        $command = switch ($exit) {
            'edit'    { "Add-Content -LiteralPath '$StandInTree/tracked.txt' -Value edited; exit 0" }
            'ignored' { "Add-Content -LiteralPath '$StandInTree/ignored.txt' -Value written; exit 0" }
            # Exits 0 only when pre-commit refuses the commit, naming the process in the marker.
            'commit'  { "`$m = @(Get-Content -LiteralPath '$StandInTree/.gates-running'); " +
                        "`$o = git -C '$StandInTree' -c 'core.hooksPath=$repoRoot/.githooks' -c user.name=stand-in " +
                        "-c user.email=stand-in@example.invalid commit -q -m stand-in 2>&1 | Out-String; " +
                        "if (`$LASTEXITCODE -eq 0) { 'the commit went through'; exit 1 }; " +
                        "if (`$o -notmatch ('process ' + `$m[0] + ', started')) { `$o; exit 1 }; exit 0" }
            default   { "exit $([int]$exit)" }
        }
        @{ Name = "stand-in-$i"; Exe = $pwsh; Arguments = @('-NoProfile', '-Command', $command) }
    })
}
$gates = @($gates | Where-Object { $_.Name -like $Only })
if ($gates.Count -eq 0) { throw "-Only '$Only' matches no gate." }

# A live run, for .githooks/pre-commit to refuse a commit against (#872): this process's ID and
# start time, in the form .githooks/gates-running.ps1 reads. Git-ignored, so not in the #812
# fingerprint, and removed on every way out a finally sees; a run stopped from outside leaves it,
# which is why the hook ignores one whose process is gone.
$marker = Join-Path $treeRoot '.gates-running'
"$PID", (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o') | Set-Content -LiteralPath $marker
try {
    Write-Host "Running $($gates.Count) gate(s), one at a time. Logs: $temp"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    # The tree as the first gate finds it, compared after each gate until it first differs (#812).
    $treeBefore = Get-TrackedTreeFingerprint -Root $treeRoot
    $treeSeen   = $null
    $watchTree  = {
        param([string] $Gate)
        if ($script:treeSeen) { return }
        $changed = @(Get-TrackedTreeChanges -Before $treeBefore -After (Get-TrackedTreeFingerprint -Root $treeRoot))
        if ($changed) { $script:treeSeen = @{ Gate = $Gate; Paths = $changed } }
    }
    Push-Location $repoRoot
    try { $failed = Invoke-Gates -Gates $gates -LogDirectory $temp -AfterEach $watchTree } finally { Pop-Location }
    $took = '{0:hh\:mm\:ss}' -f $watch.Elapsed
    # Once more at the end, so a change undone before the end still counts and one made after the
    # first is still named.
    $moved = @(@($treeSeen.Paths) + @(Get-TrackedTreeChanges -Before $treeBefore -After (Get-TrackedTreeFingerprint -Root $treeRoot)) |
        Where-Object { $_ } | Sort-Object -Unique)

    Write-Host ''
    if (@($failed).Count -gt 0) {
        Write-Host "FAIL - $(@($failed).Count) of $($gates.Count) gate(s) failed in ${took}: $($failed -join ', ')" -ForegroundColor Red
    }
    if ($moved) {
        $when = if ($treeSeen) { "first seen after $($treeSeen.Gate)" } else { 'seen at the end of the run' }
        Write-Host "FAIL - $($moved.Count) tracked path(s) changed during the run, $when, so its result describes no one tree:" -ForegroundColor Red
        foreach ($path in $moved) { Write-Host "         $path" }
    }
    if (@($failed).Count -gt 0 -or $moved) { exit 1 }
    Remove-Item -Recurse -Force $temp
    Write-Host "OK - all $($gates.Count) gate(s) passed in $took."
} finally {
    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
}
