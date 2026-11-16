# Issue tracker — what its rules were measured on

The history behind the rules of [`issue-tracker.md`](issue-tracker.md) that are this repository's
own, moved here from that page's *Create an issue* line when it became a stub page (#864,
Truls's ruling in its triage, 2026-11-16). For #861 the tense of its hang-guard sentences was
changed, a sentence on #861 was added and the clause "there this line is the whole instruction"
was dropped; the incident of its decision-comment bullet stands beside it.
"This line" in it is that line as it stood. **Read
this page** when one of those rules is revisited or doubted. Filing, reading or closing an issue
does not need it. **The rule is the one `issue-tracker.md` or the shared
[`tracker-conventions.md`](../../vendor/grado-factorio-tools/docs/tracker-conventions.md) words.**

## Multi-line bodies, heredocs and the hang guard

Heredoc bodies passed through the Bash tool have failed here with
`unexpected EOF while looking for matching '`. Every command that failed ran past 60 lines; the
trigger is not pinned down. Write the file with the Write tool: a heredoc that writes the file is
no safer. A command that edits a body file and the `gh` command that sends it are joined with
`&&`, so a failed edit sends nothing: on #713 an `assert` in the edit script failed and the
`gh pr edit --body-file` on the next line sent the old body anyway, as that session's transcript
shows; #718 counts two such commands. On 2026-10-06 one command of six such heredocs ended in
`here-document at line 214 delimited by end-of-file`; of the six body files, two were never
written and one was cut short.

A heredoc is not what makes a command hang, though (#645, reproduced 2026-10-09). The Bash tool's
stdin is a pipe that is never closed, so a `cat` or a `python -` with nothing fed to it waits on
that pipe, and `python -` with stdin from `/dev/null` starts the interactive prompt and never
ends. `tools/refuse-hanging-bash.py` is written as a PreToolUse hook that refuses those two shapes
before they run, with a message that says to use the Write tool. It applied on a machine whose
`.claude/settings.local.json` registered it for the Bash tool, where #859 moved it from
`.claude/settings.json` when that file came to be tracked, so a fresh clone had no hook. Since #861
the tracked `.claude/settings.json` wires its PowerShell port, the shared `refuse-hanging-bash.ps1`
under `vendor/grado-factorio-tools/scripts/`, for every clone with the submodule initialised, and
a `settings.local.json` that still registers the Python script runs both. The Python script was
registered on Truls's machine on 2026-10-09, and refused its first live call the same day:
`if false; then cat; fi; echo ran-through`, before it ran.

Since #660 each refusal is appended to `.claude/refused-bash.log`, which is git-ignored, as one
line of JSON with the time, the reason and the command. A refusal that looks false is read from
that file, and the script's docstring lists the false refusals already known. Since #666 the hook
also refuses a heredoc whose body is over 60 lines, with the same message; a shorter one is let
through, and this line still says to write the file.

Since #682 it also refuses, on Windows, a command that holds two backslashes in a row. A Bash tool
command there loses one backslash of every two before bash runs it, inside single quotes and
inside a quoted heredoc as well: `echo 'Z\\Z'` printed `Z\Z` (reproduced 2026-10-11 and
2026-10-12, GNU bash 5.1.16 (msys)). So a heredoc of 11 lines that held `r"\\s+"` reached Python
as `r"\s+"`, and an edit script stopped with two of six files edited. A file written with the
Write tool keeps both backslashes, and so does a command sent through the PowerShell tool. The
script's docstring says where the halving happens, which upstream report has the cause, and what
is refused though it would have run.

## A comment that records Truls's decisions

On #713 [the comment on
#593](https://github.com/trulsjo/realistic-fusion-refreshed/issues/593#issuecomment-6191194343)
restated the rule's wording, and its edit history shows that wording changed twice after it was
posted, as the rule's moved on the branch (#716).
