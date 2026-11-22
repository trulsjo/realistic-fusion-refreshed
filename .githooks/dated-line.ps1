<#
.SYNOPSIS
    Exits 1 when the commit being made changes a gate script's code and adds no dated line to
    docs/agents/state-detail.md, and its message carries no Dated-Line: none trailer (#913).

.DESCRIPTION
    CLAUDE.md's State section: "A change to a gate adds a dated line at the foot of that page, in
    the commit that changes the gate." The commit-msg hook runs this after the message check.

    WHY commit-msg AND NOT pre-commit. pre-commit runs before git writes the message, so it cannot
    read the trailer; commit-msg is handed the message and still sees the index the commit is
    made from. A check split between the two would have to pass what pre-commit found to
    commit-msg in a file, so the whole of it sits in commit-msg.

    THE GATE SCRIPTS are $GATE_SCRIPTS below, and nowhere else: scripts/ship-check.ps1,
    scripts/load-check.ps1, every scripts/check-*.ps1 and scripts/run-gates.ps1. A staged path is
    read against them with -like.

    A CODE CHANGE is one that moves a token outside the comments. Each version of a staged gate
    script, the one at HEAD and the one in the index, is read by PowerShell's own tokenizer, its
    comment tokens dropped, a help block among them, and each run of line ends taken as one; the
    two sequences are compared. So an edit to a comment or to help, a comment line added or
    removed, and a change of indent or of spacing inside a line pass, and a changed string, a
    printed message among them, is code. A script added or deleted is a code change, since one
    side has no code.

    A DATED LINE is an added line of docs/agents/state-detail.md, in the index against HEAD, that
    opens with "- " and a date written YYYY-MM-DD. Its words, its ticket and where it stands are
    not read.

    THE WAY OUT is a trailer in the message whose key is Dated-Line, in any case, and whose value
    opens with the word none, as `Dated-Line: none, the change is a rename`, read by git
    interpret-trailers. The run says it honoured it, and names the scripts it let through.

    WHAT IT CANNOT SEE: an amend is read against the commit it amends, so amending a code change
    into a commit that already carries its dated line is refused and wants the trailer; a merge
    is read against its first parent; a change to a gate that is not a script in the list, a
    shared check in vendor/, gates.yml or a hook, is not read; a token the tokenizer gives a
    different text for the same code, and joining two lines that a line end kept apart as two
    statements, are not told from a change of meaning in one direction or the other. A commit
    made with --no-verify runs no hook, and the workflow does not run this over a pull request.

.PARAMETER MessageFile
    The file holding the commit message, as git hands it to commit-msg.

.PARAMETER Root
    The top of the working tree the commit is in.

.PARAMETER SelfTest
    Build a scratch repository in the temp directory and require the check to refuse a code change
    to a gate with no dated line, a code change to a check-*.ps1, a gate added, a gate deleted, a
    line added without a date and a trailer whose value is not none; and to pass a code change with
    a dated line, a change to comments and help alone, a code change with the trailer, naming the
    script, and a code change to a script not in the list. Then commit through the commit-msg hook
    in a copy of .githooks, once refused and once let through, so the hook's wiring is held too.

.EXAMPLE
    pwsh -NoProfile -File .githooks/dated-line.ps1 -Root (git rev-parse --show-toplevel) .git/COMMIT_EDITMSG

.EXAMPLE
    pwsh -NoProfile -File .githooks/dated-line.ps1 -SelfTest
#>

#Requires -Version 7
param(
    [Parameter(Position = 0)] [string] $MessageFile,
    [string] $Root = (Get-Location).Path,
    [switch] $SelfTest
)

$GATE_SCRIPTS = 'scripts/ship-check.ps1', 'scripts/load-check.ps1', 'scripts/check-*.ps1',
    'scripts/run-gates.ps1'
$STATE_DETAIL = 'docs/agents/state-detail.md'
$EMPTY_TREE   = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'

[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Test-GateScript([string] $Path) {
    foreach ($pattern in $GATE_SCRIPTS) { if ($Path -like $pattern) { return $true } }
    $false
}

function Get-CodeToken([string] $Text) {
    <#  The script $Text's tokens outside its comments, one string, a run of line ends as one.  #>
    $tokens = $null
    $errors = $null
    [void] [Management.Automation.Language.Parser]::ParseInput($Text, [ref] $tokens, [ref] $errors)
    $out = [Collections.Generic.List[string]]::new()
    $atLineEnd = $true
    foreach ($token in $tokens) {
        $kind = "$($token.Kind)"
        if ($kind -in 'Comment', 'LineContinuation', 'EndOfInput') { continue }
        if ($kind -eq 'NewLine') {
            if (-not $atLineEnd) { $out.Add('<line end>') }
            $atLineEnd = $true
            continue
        }
        $out.Add("${kind}: $($token.Text)")
        $atLineEnd = $false
    }
    if ($out.Count -and $out[$out.Count - 1] -eq '<line end>') { $out.RemoveAt($out.Count - 1) }
    $out -join "`n"
}

function Get-BlobText([string] $Root, [string] $Spec) {
    <#  The text of the object $Spec names, or '' where it names none.  #>
    $lines = @(git -C $Root show $Spec 2>$null)
    if ($LASTEXITCODE -ne 0) { return '' }
    $lines -join "`n"
}

function Invoke-DatedLineCheck {
    <#  @{ Code = 0 or 1; Lines = what the run prints } for the commit staged at $Root.  #>
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $MessageFile)
    $lines = [Collections.Generic.List[string]]::new()
    $base = git -C $Root rev-parse --verify --quiet 'HEAD^{commit}' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $base) { $base = $EMPTY_TREE }
    $staged = @(git -C $Root -c core.quotePath=false diff --cached --name-only --no-renames $base)
    if ($LASTEXITCODE -ne 0) {
        $lines.Add("dated-line: git diff --cached failed, so whether a gate's code changed was NOT checked.")
        return @{ Code = 1; Lines = $lines }
    }
    $code = @()
    $commentOnly = @()
    foreach ($path in $staged | Where-Object { Test-GateScript $_ }) {
        $old = if ($base -eq $EMPTY_TREE) { '' } else { Get-BlobText $Root "${base}:$path" }
        $new = Get-BlobText $Root ":$path"
        if ((Get-CodeToken $old) -ceq (Get-CodeToken $new) -and ($old -or $new)) {
            $commentOnly += $path
        } else {
            $code += $path
        }
    }
    foreach ($path in $commentOnly) {
        $lines.Add("OK - dated-line: $path changes only comments and help, so it needs no dated line.")
    }
    if (-not $code) {
        if (-not $commentOnly) { $lines.Add('OK - dated-line: no gate script is staged.') }
        return @{ Code = 0; Lines = $lines }
    }
    $added = @(git -C $Root diff --cached -U0 --no-renames $base -- $STATE_DETAIL) |
        Where-Object { $_ -match '^\+- \d{4}-\d{2}-\d{2}\b' }
    $named = $code -join ', '
    if ($added) {
        $lines.Add("OK - dated-line: $named changes a gate's code, and $STATE_DETAIL gains a dated line.")
        return @{ Code = 0; Lines = $lines }
    }
    $trailers = @(git -C $Root interpret-trailers --parse $MessageFile 2>$null)
    if ($trailers | Where-Object { $_ -match '^(?i)dated-line:\s*none\b' }) {
        $lines.Add("OK - dated-line: $named changes a gate's code with no dated line in $STATE_DETAIL; the message's Dated-Line: none trailer was honoured.")
        return @{ Code = 0; Lines = $lines }
    }
    $lines.Add("dated-line: refused. $named changes a gate's code, outside its comments and help, and $STATE_DETAIL gains no dated line, one opening '- YYYY-MM-DD'.")
    $lines.Add("dated-line: CLAUDE.md's State section: a change to a gate adds a dated line at the foot of that page, in the commit that changes the gate. Stage the line, or give the message a 'Dated-Line: none' trailer where the change needs none.")
    $lines.Add('dated-line: the message is kept, so `git commit -e -F .git/COMMIT_EDITMSG` reopens it.')
    @{ Code = 1; Lines = $lines }
}

if (-not $SelfTest) {
    if (-not $MessageFile) {
        [Console]::Error.WriteLine('dated-line: no message file was given, so the dated line was NOT checked.')
        exit 1
    }
    $result = Invoke-DatedLineCheck -Root $Root -MessageFile $MessageFile
    foreach ($line in $result.Lines) {
        if ($result.Code) { [Console]::Error.WriteLine($line) } else { $line }
    }
    exit $result.Code
}

# ---------------------------------------------------------------------------------- self-test
$hooks = $PSScriptRoot
$scratch = Join-Path ([IO.Path]::GetTempPath()) "dated-line-selftest-$([guid]::NewGuid().ToString('N'))"
# A hook's git environment would point the scratch repository's git at this one's index. Removed,
# not set to $null, which PowerShell hands the setter as an empty string, a path git refuses.
$saved = @{}
foreach ($name in 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE') {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name)
    Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
}
$failures = 0
$cases = 0

function Write-Fixture([string] $Path, [string] $Text) {
    $full = Join-Path $repo $Path
    New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null
    [IO.File]::WriteAllText($full, $Text)
}

function Test-Case {
    param([string] $Name, [int] $Want, [string] $Message, [string] $Expect, [scriptblock] $Stage)
    $script:cases++
    & $Stage
    git -C $repo add -A 2>&1 | Out-Null
    $msg = Join-Path $scratch 'message.txt'
    [IO.File]::WriteAllText($msg, $Message)
    $result = Invoke-DatedLineCheck -Root $repo -MessageFile $msg
    $text = $result.Lines -join "`n"
    $ok = $result.Code -eq $Want -and (-not $Expect -or $text.Contains($Expect))
    if ($ok) {
        "OK - dated-line -SelfTest: $Name (exit $($result.Code))."
    } else {
        "FAILED - dated-line -SelfTest: $Name gave exit $($result.Code), wanted $Want$(if ($Expect) { ", naming '$Expect'" }):"
        $result.Lines | ForEach-Object { "    $_" }
        $script:failures++
    }
    git -C $repo reset -q --hard HEAD 2>&1 | Out-Null
    git -C $repo clean -q -fd 2>&1 | Out-Null
}

$gate = @'
<#
.SYNOPSIS
    A stand-in gate.
#>
param([switch] $SelfTest)
# Says what it checks.
$x = 1
Write-Output "checked $x"
'@
$detail = "# State detail`n`n## Added since 2026-10-12`n`n- 2026-10-12, #1: the first line.`n"
$plain = "subject`n`nA body.`n"

try {
    $repo = Join-Path $scratch 'repo'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    git -C $repo init -q -b main 2>&1 | Out-Null
    git -C $repo config user.name 'self-test'
    git -C $repo config user.email 'self-test@example.invalid'
    git -C $repo config core.autocrlf false
    Write-Fixture 'scripts/ship-check.ps1' $gate
    Write-Fixture 'scripts/check-foo.ps1' $gate
    Write-Fixture 'scripts/other.ps1' $gate
    Write-Fixture $STATE_DETAIL $detail
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit -q -m 'base' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "could not commit the scratch repository's base at $repo" }
    $codeEdit = $gate.Replace('$x = 1', '$x = 2')
    $dated = $detail + "- 2026-11-22, #913: a gate changed.`n"

    Test-Case 'a code change with no dated line is refused' 1 $plain 'scripts/ship-check.ps1 changes' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a code change with a dated line passes' 0 $plain 'gains a dated line' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
        Write-Fixture $STATE_DETAIL $dated
    }
    Test-Case 'a change to comments and help alone passes' 0 $plain 'changes only comments and help' {
        $edited = $gate.Replace('A stand-in gate.', "A stand-in gate, reworded`n    over two lines.").
            Replace('# Says what it checks.', "# Says what it checks,`n# now in two lines.").
            Replace('$x = 1', '$x   =   1    # spaced, and a trailing comment')
        Write-Fixture 'scripts/ship-check.ps1' $edited
    }
    Test-Case 'a code change with the trailer passes, and is named' 0 "subject`n`nA body.`n`nDated-Line: none, a stand-in`n" 'scripts/ship-check.ps1 changes a gate''s code with no dated line' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a trailer whose value is not none is refused' 1 "subject`n`nA body.`n`nDated-Line: yes`n" 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a code change to a check-*.ps1 is refused' 1 $plain 'scripts/check-foo.ps1 changes' {
        Write-Fixture 'scripts/check-foo.ps1' $codeEdit
    }
    Test-Case 'a gate added is refused' 1 $plain 'scripts/check-new.ps1 changes' {
        Write-Fixture 'scripts/check-new.ps1' $gate
    }
    Test-Case 'a gate deleted is refused' 1 $plain 'scripts/check-foo.ps1 changes' {
        Remove-Item -LiteralPath (Join-Path $repo 'scripts/check-foo.ps1')
    }
    Test-Case 'a line added without a date is refused' 1 $plain 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
        Write-Fixture $STATE_DETAIL ($detail + "  a continuation, with no date.`n")
    }
    Test-Case 'a code change to a script not in the list passes' 0 $plain 'no gate script is staged' {
        Write-Fixture 'scripts/other.ps1' $codeEdit
    }

    # The hook's wiring: a commit through a copy of commit-msg, which finds no shared message
    # check in this repository's vendor/ and says so, and then runs this script.
    $cases++
    New-Item -ItemType Directory -Path (Join-Path $repo '.githooks') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $hooks 'commit-msg'), (Join-Path $hooks 'dated-line.ps1') `
        -Destination (Join-Path $repo '.githooks')
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit -q -m 'hooks' 2>&1 | Out-Null
    git -C $repo config core.hooksPath .githooks
    Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    git -C $repo add -A 2>&1 | Out-Null
    $out = @(git -C $repo commit -q -m 'a code change' 2>&1) -join "`n"
    $refused = $LASTEXITCODE -ne 0 -and $out.Contains('dated-line: refused')
    Write-Fixture $STATE_DETAIL $dated
    git -C $repo add -A 2>&1 | Out-Null
    $out2 = @(git -C $repo commit -q -m 'a code change' 2>&1) -join "`n"
    $passed = $LASTEXITCODE -eq 0
    if ($refused -and $passed) {
        'OK - dated-line -SelfTest: a commit through commit-msg is refused without the line, and made with it.'
    } else {
        "FAILED - dated-line -SelfTest: through commit-msg, refused without the line: $refused; made with it: $passed."
        "    without: $out"
        "    with: $out2"
        $failures++
    }
} finally {
    foreach ($name in $saved.Keys) {
        if ($null -ne $saved[$name]) { Set-Item -LiteralPath "Env:$name" -Value $saved[$name] }
    }
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures) {
    "FAILED - dated-line -SelfTest: $failures of $cases case(s) failed."
    exit 1
}
"OK - dated-line -SelfTest: $cases of $cases case(s) passed."
exit 0
