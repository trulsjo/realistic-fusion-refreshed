<#
.SYNOPSIS
    Exits 1 when the commit being made changes a gate script's code and adds no dated line to
    docs/agents/state-detail.md, and its message carries no Dated-Line: none trailer (#913).

.DESCRIPTION
    CLAUDE.md's State section: "A change to a gate adds a dated line at the foot of that page, in
    the commit that changes the gate." The commit-msg hook runs this after the message check.

    WHY commit-msg AND NOT pre-commit. pre-commit runs before git writes the message, so it cannot
    read the trailer; commit-msg is handed the message and still sees the index the commit is made
    from. A check split between the two would have to pass what pre-commit found to commit-msg in a
    file, so the whole of it sits in commit-msg.

    THE GATE SCRIPTS are $GATE_SCRIPTS below, and nowhere else: scripts/ship-check.ps1,
    scripts/load-check.ps1, every scripts/check-*.ps1 and scripts/run-gates.ps1. A staged path is
    read against them with -like, the staged list read NUL-separated from git's output as bytes, not
    split at line ends as PowerShell splits a command's output, so a name git would quote, one
    holding a double quote, a backslash or a control character, a line break among them, is read as
    it is.

    A CODE CHANGE is one that moves a token outside the comments. Each version of a staged gate
    script, the one at HEAD and the one in the index, is read by PowerShell's own tokenizer, its
    comment tokens dropped, a help block among them, and each run of line ends taken as one; the two
    sequences are compared. A #Requires line is a comment token that PowerShell acts on, so it is
    kept as code, and so is each parse error the tokenizer reports, by its error ID, so a script
    left with an unclosed block comment, whose rest the tokenizer gives as one comment token, is a
    code change. So an edit to a comment or to help, a comment line added or removed, and a change
    of indent or of spacing inside a line pass, and a changed string, a printed message or a
    self-test's label among them, is code. A script added or deleted is a code change whatever it
    holds, since one side is not there.

    A DATED LINE is a line of docs/agents/state-detail.md that opens with "- " and a date written
    YYYY-MM-DD. The page gains one when the index, against HEAD, adds more such lines than it
    removes, so rewording a dated line already there gains none. That diff is asked for with no
    colour, no external diff program and no textconv driver, whatever the clone sets, and a diff
    that fails refuses the commit as NOT checked. Its words, its ticket and where it stands are not
    read.

    THE WAY OUT is a line of the message, anywhere in it, that opens with Dated-Line, in any case, a
    colon and the word none, ended by the line's end, a space or one of , ; . : so that
    `none-of-the-above` is not it, as `Dated-Line: none, the change is a rename`. It is written as a
    trailer, but is read on any line, since git interpret-trailers reads none in a last paragraph
    that also holds a `Closes #N` line. The run says it honoured it, and names the scripts it let
    through.

    WHAT IT CANNOT SEE: the recovery command a refusal prints double-quotes the message file's path,
    so a path holding a space stays one argument, but a character the shell it is pasted into treats
    as special inside double quotes is not kept as it is: a $ or a backtick in bash or PowerShell,
    and a ! in a bash with history expansion on; a comment inside a $( ) of a double-quoted string,
    which the tokenizer gives as part of the string's one token, so an edit to that comment alone is
    refused as code; an amend is read against the commit it amends, so amending a code change into a
    commit that already carries its dated line is refused and wants the trailer; a merge, while
    MERGE_HEAD stands, is let through unread: a commit it brings in was checked only where it was
    made with this hook, and not where it was made with --no-verify or in a clone without the hook,
    and a gate's code that a conflict's resolution changes is not read; a change to a gate that is
    not a script in the list, a shared check in vendor/, gates.yml or a hook, is not read; a token
    the tokenizer gives a different text for the same code, and joining two lines that a line end
    kept apart as two statements, are not told from a change of meaning in one direction or the
    other. A commit made with --no-verify runs no hook, and the workflow does not run this over a
    pull request.

.PARAMETER MessageFile
    The file holding the commit message, as git hands it to commit-msg.

.PARAMETER Root
    The top of the working tree the commit is in.

.PARAMETER SelfTest
    Build a scratch repository in the temp directory and require the check to refuse a code change
    to a gate with no dated line, a code change to a check-*.ps1, a gate added, a gate deleted, a
    line added without a date, a trailer whose value is not none, one whose value only starts with
    none, a changed #Requires line, a gate added that holds only comments and one deleted, a dated
    line reworded with none added, a date in an added line that does not open it, a Dated-Line: none
    that does not open its line, a string whose case alone changes, a staged list git cannot read,
    refused as NOT checked, a gate left with an unclosed block comment and one whose name git quotes
    and one whose name holds a line break, each staged in the index alone, and a gate change beside
    the page staged as a blob the repository lacks, refused as NOT checked; and to pass a code
    change with a dated line, one under color.ui, diff.external and a textconv, a change to comments
    and help alone, a code change with the trailer, naming the script, the trailer in a paragraph
    with a Closes line, a code change to a script not in the list, and a merge of a gate change. In
    a linked worktree of it, require a refusal to name the COMMIT_EDITMSG that git rev-parse
    --git-path gives, quoted, as the scratch folder's name holds a space. Then commit through the
    commit-msg hook in a copy of .githooks, once refused and once let through, so the hook's wiring
    is held too.

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
        if ($kind -eq 'Comment' -and $token.Text -notmatch '^(?i)#requires\b') { continue }
        if ($kind -in 'LineContinuation', 'EndOfInput') { continue }
        if ($kind -eq 'NewLine') {
            if (-not $atLineEnd) { $out.Add('<line end>') }
            $atLineEnd = $true
            continue
        }
        $out.Add("${kind}: $($token.Text)")
        $atLineEnd = $false
    }
    if ($out.Count -and $out[$out.Count - 1] -eq '<line end>') { $out.RemoveAt($out.Count - 1) }
    # A parse error is code: an unclosed <# comes back as a Comment token holding the rest of the
    # script, which the loop drops, so the error is what tells that script from a sound one.
    foreach ($e in $errors) { $out.Add("ParseError: $($e.ErrorId)") }
    $out -join "`n"
}

function Get-GitBytes([string] $Root, [string[]] $GitArgs) {
    <#  @{ Text = git's standard output, decoded as UTF-8 from its bytes; Code = its exit code }.
        PowerShell splits a native command's output at line ends, which loses a line break held in a
        NUL-separated name, so the output is read from the process's stream whole.  #>
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    $start.ArgumentList.Add('-C')
    $start.ArgumentList.Add($Root)
    foreach ($a in $GitArgs) { $start.ArgumentList.Add($a) }
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($start)
    $buffer = [IO.MemoryStream]::new()
    $errorRead = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($buffer)
    $process.WaitForExit()
    [void] $errorRead.Result
    @{ Text = [Text.Encoding]::UTF8.GetString($buffer.ToArray()); Code = $process.ExitCode }
}

function Get-BlobText([string] $Root, [string] $Spec) {
    <#  The text of the object $Spec names, or $null where it names none.  #>
    $lines = @(git -C $Root show $Spec 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    $lines -join "`n"
}

function Invoke-DatedLineCheck {
    <#  @{ Code = 0 or 1; Lines = what the run prints } for the commit staged at $Root.  #>
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $MessageFile)
    $lines = [Collections.Generic.List[string]]::new()
    # A merge: its diff against the first parent would read the commits it brings in again
    # without their messages, refusing one its trailer let through where it was made. A commit
    # made without this hook was never checked, which the header names.
    git -C $Root rev-parse --verify --quiet MERGE_HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $lines.Add('OK - dated-line: a merge is being made, so it is not read; a commit it brings in was checked only where it was made with this hook.')
        return @{ Code = 0; Lines = $lines }
    }
    $base = git -C $Root rev-parse --verify --quiet 'HEAD^{commit}' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $base) { $base = $EMPTY_TREE }
    # NUL-separated, as git quotes a name holding a double quote, a backslash or a control
    # character even with core.quotePath off, and a quoted name matches no pattern.
    $listed = Get-GitBytes $Root @('diff', '--cached', '--name-only', '-z', '--no-renames', $base)
    $listedAt = $listed.Code
    $staged = @($listed.Text -split "`0" | Where-Object { $_ })
    if ($listedAt -ne 0) {
        $lines.Add("dated-line: git diff --cached failed, so whether a gate's code changed was NOT checked.")
        return @{ Code = 1; Lines = $lines }
    }
    $code = @()
    $commentOnly = @()
    foreach ($path in $staged | Where-Object { Test-GateScript $_ }) {
        $old = if ($base -eq $EMPTY_TREE) { $null } else { Get-BlobText $Root "${base}:$path" }
        $new = Get-BlobText $Root ":$path"
        # Added or deleted: one side is not there, which is a code change whatever the other holds.
        if ($null -ne $old -and $null -ne $new -and (Get-CodeToken $old) -ceq (Get-CodeToken $new)) {
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
    # Added dated lines less removed ones, so a reworded line nets none.
    # The clone's colour, external-diff and textconv settings would hide the lines from the match.
    $diff = @(git -C $Root diff --cached -U0 --no-renames --no-color --no-ext-diff --no-textconv $base -- $STATE_DETAIL 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $lines.Add("dated-line: git diff --cached of $STATE_DETAIL failed, so whether it gains a dated line was NOT checked.")
        return @{ Code = 1; Lines = $lines }
    }
    $added = @($diff | Where-Object { $_ -match '^\+- \d{4}-\d{2}-\d{2}\b' }).Count
    $removed = @($diff | Where-Object { $_ -match '^-- \d{4}-\d{2}-\d{2}\b' }).Count
    $named = $code -join ', '
    if ($added -gt $removed) {
        $lines.Add("OK - dated-line: $named changes a gate's code, and $STATE_DETAIL gains a dated line.")
        return @{ Code = 0; Lines = $lines }
    }
    $message = @(Get-Content -LiteralPath $MessageFile -ErrorAction SilentlyContinue)
    # none ends at the line's end, a space or , ; . : so none-of-the-above is not it.
    if ($message | Where-Object { $_ -match '^(?i)dated-line:\s*none(?=$|[\s,;.:])' }) {
        $lines.Add("OK - dated-line: $named changes a gate's code with no dated line in $STATE_DETAIL; the message's Dated-Line: none trailer was honoured.")
        return @{ Code = 0; Lines = $lines }
    }
    $lines.Add("dated-line: refused. $named changes a gate's code, outside its comments and help, and $STATE_DETAIL gains no dated line, one opening '- YYYY-MM-DD'.")
    $lines.Add("dated-line: CLAUDE.md's State section: a change to a gate adds a dated line at the foot of that page, in the commit that changes the gate. Stage the line, or give the message a 'Dated-Line: none' trailer where the change needs none.")
    # git's own path for the file, as .git is a file in a linked worktree and the message is kept
    # under the main checkout's git directory.
    $editMsg = git -C $Root rev-parse --git-path COMMIT_EDITMSG 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $editMsg) { $editMsg = '.git/COMMIT_EDITMSG' }
    # Quoted, as a path with a space would split into two arguments.
    $lines.Add("dated-line: the message is kept, so ``git commit -e -F `"$editMsg`"`` reopens it.")
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
# A space in the name, so the linked worktree's git directory has one, which the refusal's
# recovery command must quote.
$scratch = Join-Path ([IO.Path]::GetTempPath()) "dated-line selftest-$([guid]::NewGuid().ToString('N'))"
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
#Requires -Version 7
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
    Write-Fixture 'scripts/check-notes.ps1' "# Only notes, and no code.`n"
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
    Test-Case 'a change to a #Requires line is refused' 1 $plain 'scripts/ship-check.ps1 changes' {
        Write-Fixture 'scripts/ship-check.ps1' $gate.Replace('#Requires -Version 7', '#Requires -Version 5.1')
    }
    Test-Case 'a gate added that holds only comments is refused' 1 $plain 'scripts/check-empty.ps1 changes' {
        Write-Fixture 'scripts/check-empty.ps1' "# Nothing yet.`n"
    }
    Test-Case 'a dated line reworded, and none added, is refused' 1 $plain 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
        Write-Fixture $STATE_DETAIL $detail.Replace('the first line.', 'the first line, reworded.')
    }
    Test-Case 'the trailer in a paragraph with a Closes line passes' 0 "subject`n`nA body.`n`nCloses #1`nDated-Line: none, a stand-in`n" 'trailer was honoured' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a trailer whose value only starts with none is refused' 1 "subject`n`nA body.`n`nDated-Line: none-of-the-above`n" 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a dated line that does not open the line is refused' 1 $plain 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
        Write-Fixture $STATE_DETAIL ($detail + "Moved on 2026-11-22, #913, in a sentence.`n")
    }
    Test-Case 'a Dated-Line: none that does not open its line is refused' 1 "subject`n`nSee the Dated-Line: none rule.`n" 'refused' {
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    }
    Test-Case 'a string whose case alone changes is code' 1 $plain 'scripts/ship-check.ps1 changes' {
        Write-Fixture 'scripts/ship-check.ps1' $gate.Replace('"checked $x"', '"Checked $x"')
    }
    Test-Case 'a gate deleted that holds only comments is refused' 1 $plain 'scripts/check-notes.ps1 changes' {
        Remove-Item -LiteralPath (Join-Path $repo 'scripts/check-notes.ps1')
    }
    # An index of forty zero bytes, on which git diff --cached fails: the case's own reset fails
    # on it too, so the index is rebuilt after.
    Test-Case 'a staged list git cannot read is refused as NOT checked' 1 $plain 'was NOT checked' {
        [IO.File]::WriteAllBytes((Join-Path $repo '.git/index'), [byte[]]::new(40))
    }
    Remove-Item -LiteralPath (Join-Path $repo '.git/index')
    git -C $repo reset -q --hard HEAD 2>&1 | Out-Null
    Test-Case 'a gate left with an unclosed block comment is refused' 1 $plain 'scripts/ship-check.ps1 changes' {
        Write-Fixture 'scripts/ship-check.ps1' ($gate + "`n<# never closed`n")
    }
    # A clone's own diff settings: colour codes before each line, and an external diff program,
    # would each hide the dated line from a diff that does not turn them off.
    git -C $repo config color.ui always
    git -C $repo config diff.external false
    git -C $repo config diff.bad.textconv false
    Test-Case 'a dated line is read under color.ui, diff.external and a textconv' 0 $plain 'gains a dated line' {
        Write-Fixture '.gitattributes' "docs/agents/state-detail.md diff=bad`n"
        Write-Fixture 'scripts/ship-check.ps1' $codeEdit
        Write-Fixture $STATE_DETAIL $dated
    }
    git -C $repo config --unset color.ui
    git -C $repo config --unset diff.external
    git -C $repo config --unset diff.bad.textconv

    # A gate whose name git quotes even with core.quotePath off, a double quote in it: Windows
    # refuses such a file, so it is staged in the index alone, from a blob of the gate's text, as
    # a clone off Windows could hold it.
    # Test-Case's git add -A would drop an entry with no file, so this case is written out.
    $cases++
    $blob = $gate | git -C $repo hash-object -w --stdin
    # Git for Windows refuses the name too, by core.protectNTFS, so the case turns that off.
    git -C $repo -c core.protectNTFS=false update-index --add --cacheinfo "100644,$blob,scripts/check-`"q`".ps1" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "could not stage a gate whose name git quotes at $repo" }
    [IO.File]::WriteAllText((Join-Path $scratch 'message.txt'), $plain)
    $result = Invoke-DatedLineCheck -Root $repo -MessageFile (Join-Path $scratch 'message.txt')
    if ($result.Code -eq 1 -and ($result.Lines -join "`n").Contains('scripts/check-"q".ps1 changes')) {
        "OK - dated-line -SelfTest: a gate whose name git quotes is read by its name (exit 1)."
    } else {
        "FAILED - dated-line -SelfTest: a gate whose name git quotes gave exit $($result.Code), wanted 1 naming it:"
        $result.Lines | ForEach-Object { "    $_" }
        $failures++
    }
    git -C $repo reset -q --hard HEAD 2>&1 | Out-Null

    # The page staged as a blob the repository lacks, beside a gate change: the staged list reads
    # names alone and passes, and the page's own diff fails, so only that diff can refuse it.
    $cases++
    Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo update-index --cacheinfo "100644,$('1' * 40),$STATE_DETAIL" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "could not stage $STATE_DETAIL as a missing blob at $repo" }
    [IO.File]::WriteAllText((Join-Path $scratch 'message.txt'), $plain)
    $result = Invoke-DatedLineCheck -Root $repo -MessageFile (Join-Path $scratch 'message.txt')
    if ($result.Code -eq 1 -and ($result.Lines -join "`n").Contains("of $STATE_DETAIL failed")) {
        "OK - dated-line -SelfTest: a page git cannot diff is refused as NOT checked (exit 1)."
    } else {
        "FAILED - dated-line -SelfTest: a page git cannot diff gave exit $($result.Code), wanted 1 naming its failed diff:"
        $result.Lines | ForEach-Object { "    $_" }
        $failures++
    }
    git -C $repo reset -q --hard HEAD 2>&1 | Out-Null

    # A gate whose name holds a line break, which a read split at line ends would lose: without it
    # the name is scripts/check-foo.ps1, a gate the change leaves as it is.
    $cases++
    $lfName = "scripts/check-`nfoo.ps1"
    $blob = $gate.Replace('$x = 1', '$x = 3') | git -C $repo hash-object -w --stdin
    git -C $repo -c core.protectNTFS=false update-index --add --cacheinfo "100644,$blob,$lfName" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "could not stage a gate whose name holds a line break at $repo" }
    [IO.File]::WriteAllText((Join-Path $scratch 'message.txt'), $plain)
    $result = Invoke-DatedLineCheck -Root $repo -MessageFile (Join-Path $scratch 'message.txt')
    if ($result.Code -eq 1 -and ($result.Lines -join "`n").Contains("$lfName changes")) {
        "OK - dated-line -SelfTest: a gate whose name holds a line break is read by its name (exit 1)."
    } else {
        "FAILED - dated-line -SelfTest: a gate whose name holds a line break gave exit $($result.Code), wanted 1 naming it:"
        $result.Lines | ForEach-Object { "    $_" }
        $failures++
    }
    git -C $repo reset -q --hard HEAD 2>&1 | Out-Null

    # A merge of a branch whose gate change was let through by its trailer: MERGE_HEAD stands while
    # the merge commit's message is checked, and the merge is not read again.
    git -C $repo checkout -q -b side 2>&1 | Out-Null
    Write-Fixture 'scripts/ship-check.ps1' $codeEdit
    git -C $repo commit -q -a -m "side`n`nDated-Line: none, a stand-in" 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Test-Case 'a merge of a gate change is let through' 0 $plain 'a merge' {
        git -C $repo merge -q --no-ff --no-commit side 2>&1 | Out-Null
    }
    git -C $repo merge --abort 2>&1 | Out-Null
    git -C $repo branch -q -D side 2>&1 | Out-Null

    # A linked worktree, where .git is a file: the refusal names the message file git keeps there.
    $cases++
    $linked = Join-Path $scratch 'linked'
    git -C $repo worktree add -q --detach $linked 2>&1 | Out-Null
    $editMsg = git -C $linked rev-parse --git-path COMMIT_EDITMSG
    [IO.File]::WriteAllText((Join-Path $linked 'scripts/ship-check.ps1'), $codeEdit)
    git -C $linked add -A 2>&1 | Out-Null
    [IO.File]::WriteAllText((Join-Path $scratch 'message.txt'), $plain)
    $result = Invoke-DatedLineCheck -Root $linked -MessageFile (Join-Path $scratch 'message.txt')
    $named = ($result.Lines -join "`n").Contains("git commit -e -F `"$editMsg`"``")
    if ($result.Code -eq 1 -and $editMsg -notmatch '^\.git/' -and $editMsg.Contains(' ') -and $named) {
        "OK - dated-line -SelfTest: a refusal in a linked worktree names its message file, $editMsg."
    } else {
        "FAILED - dated-line -SelfTest: a refusal in a linked worktree gave exit $($result.Code), wanted 1 naming ${editMsg}:"
        $result.Lines | ForEach-Object { "    $_" }
        $failures++
    }
    git -C $repo worktree remove --force $linked 2>&1 | Out-Null

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
