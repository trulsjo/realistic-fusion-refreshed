<#
.SYNOPSIS
    Runs every gate in the repository, one after another, and prints one line per gate. Exits
    non-zero naming each gate that failed (#567).

.DESCRIPTION
    FOR AN INTEGRATED BRANCH, BEFORE A REVIEW. Each ticket's author runs the gates its own change
    touches. #557 combined seven such changes, and one of them broke a gate its author had no
    reason to run: #555 changed how control.lua writes UPDATE_INTERVAL, which the Lua suites, the
    ship check and the load check all passed, and check-pooling.ps1 reads that line by its shape.
    It was caught because the gates were run by hand on the combined tree. This is that step.

    NOT FOR A MARKDOWN-ONLY BRANCH (#618, decided 2026-10-07). When every path
    `git diff --name-only --no-renames main...HEAD` prints ends in .md, the branch runs
    ship-check.ps1 alone, because no other gate here reads a .md file. --no-renames makes a file
    renamed to .md print the path it had. One path that does not end in .md, a comment-only
    edit to a script included, and it runs everything: check-pooling.ps1 reads control.lua by
    its shape, which is the failure above. This script does not look at the diff. The session
    decides, and the pre-PR reviewer checks the paths.

    WHAT IT RUNS, in this order:

      the Lua suites           every tests/test-*.lua, with `lua` from PATH
      ship-check.ps1           no game
      load-check.ps1           the default load, from the junctioned repository
      check-*.ps1              every scripts/check-*.ps1, found by name, so a new one is picked up

    Each is its own process with its default arguments. A gate that fails does not stop the run:
    the rest still run, so one invocation says everything that is broken.

    WHAT IT DOES NOT RUN. No probe: a probe asserts nothing, and exit 0 from one means it reported.
    No -SelfTest of any gate, and not load-check.ps1 -FromZips, locale-check.ps1 or name-check.ps1:
    the first two prove a gate or a packaging and the last two read a prototype dump, and none of
    them is what an integration breaks first. Run them as CLAUDE.md says, before anything ships.

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
    Prove the runner with stand-in gates and no game: a gate that fails, or whose executable is
    missing, is returned by name as failed, and one that passes beside it is still reported as
    passing. The exit code this script turns that list into is not exercised.

.EXAMPLE
    pwsh -File scripts/run-gates.ps1
    pwsh -File scripts/run-gates.ps1 -Only 'test-*'
    pwsh -File scripts/run-gates.ps1 -SelfTest
#>

#Requires -Version 7
[CmdletBinding()]
param(
    [string] $Only = '*',
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent

function Invoke-Gates {
    <#  Run each gate, print its line, and return the names that failed. A gate is a Name, an
        executable and its arguments; it passes on exit 0 and on nothing else.  #>
    param([Parameter(Mandatory)] [object[]] $Gates, [Parameter(Mandatory)] [string] $LogDirectory)

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
    }
    return , $failed
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('rf-gates-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$pwsh = (Get-Process -Id $PID).Path

if ($SelfTest) {
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
    ) } finally { Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue }
    Write-Host '-SelfTest: PASS' -ForegroundColor Green
    exit 0
}

$gates = @()
foreach ($suite in Get-ChildItem (Join-Path $repoRoot 'tests') -Filter 'test-*.lua' | Sort-Object Name) {
    $gates += @{ Name = $suite.BaseName; Exe = 'lua'; Arguments = @($suite.FullName) }
}
$scripts = @('ship-check.ps1', 'load-check.ps1') +
    @(Get-ChildItem $PSScriptRoot -Filter 'check-*.ps1' | Sort-Object Name | ForEach-Object Name)
foreach ($script in $scripts) {
    $gates += @{ Name = [IO.Path]::GetFileNameWithoutExtension($script); Exe = $pwsh
                 Arguments = @('-NoProfile', '-File', (Join-Path $PSScriptRoot $script)) }
}
$gates = @($gates | Where-Object { $_.Name -like $Only })
if ($gates.Count -eq 0) { throw "-Only '$Only' matches no gate." }

Write-Host "Running $($gates.Count) gate(s), one at a time. Logs: $temp"
$watch = [Diagnostics.Stopwatch]::StartNew()
Push-Location $repoRoot
try { $failed = Invoke-Gates -Gates $gates -LogDirectory $temp } finally { Pop-Location }
$took = '{0:hh\:mm\:ss}' -f $watch.Elapsed

Write-Host ''
if (@($failed).Count -gt 0) {
    Write-Host "FAIL - $(@($failed).Count) of $($gates.Count) gate(s) failed in ${took}: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Remove-Item -Recurse -Force $temp
Write-Host "OK - all $($gates.Count) gate(s) passed in $took."
