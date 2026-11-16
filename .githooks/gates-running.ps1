<#
.SYNOPSIS
    Exits 1 when the .gates-running marker under -Root names a live scripts/run-gates.ps1 run,
    and 0 when there is no marker or the run it names is gone (#872).

.DESCRIPTION
    pre-commit runs this before the Markdown check, so a commit made while the gates run is
    refused before it moves the tree they are reading. run-gates.ps1's #812 check would fail such
    a run anyway, but only after the gate during which the commit came, and every gate before it
    would be run again.

    THE MARKER is the file run-gates.ps1 writes at the root of the tree it watches when it starts,
    and removes in a finally on its way out: two lines, the process ID of the pwsh running it and
    that process's start time, in UTC, in the round-trip form. It is git-ignored, so it is not in
    the #812 fingerprint.

    A run stopped from outside, by Stop-Process or a killed shell, skips its finally and leaves
    the marker behind. So the marker blocks only while a process with its ID is running and
    started at its time; the time is what tells a process that reused the ID from the run. A
    stale marker is reported and ignored, and so is one this cannot read.

    It refuses commits and nothing else. An edit to a tracked file with no commit still moves the
    fingerprint, and #812's check stays the guard against that.

.PARAMETER Root
    The top of the working tree the commit is in, where run-gates.ps1 writes its marker.

.EXAMPLE
    pwsh -NoProfile -File .githooks/gates-running.ps1 -Root (git rev-parse --show-toplevel)
#>

#Requires -Version 7
param([Parameter(Mandatory)] [string] $Root)

$marker = Join-Path $Root '.gates-running'
if (-not (Test-Path -LiteralPath $marker)) { exit 0 }

$id, $started = @(Get-Content -LiteralPath $marker)[0, 1]
$live = $false
if ($id -match '^\d+$') {
    try {
        $process = Get-Process -Id ([int] $id) -ErrorAction Stop
        $live = $process.StartTime.ToUniversalTime().ToString('o') -eq $started
    } catch {
        # No such process, or one whose start time this user cannot read, which is not a run of
        # the gates this user started.
    }
}

if ($live) {
    [Console]::Error.WriteLine("pre-commit: refused. A scripts/run-gates.ps1 run, process $id, started $started, is still going ($marker).")
    [Console]::Error.WriteLine('pre-commit: a commit now moves the tree its gates are reading. Wait for it to finish, or stop it, and commit again.')
    exit 1
}
[Console]::Error.WriteLine("pre-commit: $marker names process $id, started $started, and no process with that ID and start time is running, so the marker is stale and is ignored.")
exit 0
