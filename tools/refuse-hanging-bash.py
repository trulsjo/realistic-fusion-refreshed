r"""A PreToolUse hook for the Bash tool: refuse a command that would hang on its input (#645),
that holds a long heredoc (#666), or, on Windows, that holds two backslashes in a row (#682).

Claude Code hands a hook the tool call as JSON on stdin. Exit 2 refuses the call and shows stderr
to the model; exit 0 lets it through. Register it for the Bash tool only:

    python "$CLAUDE_PROJECT_DIR/tools/refuse-hanging-bash.py"

WHAT HANGS, reproduced on 2026-10-09 under Git Bash on Windows with Python 3.13.14:

  - A command left reading the tool's stdin. That stdin is a pipe nobody closes, so a bare `cat`
    never sees its end. `timeout 8 cat` was still running after 40 s.
  - `python -` or a bare `python` with stdin from /dev/null. Python starts the interactive
    prompt, which fails on the console's size and tries again without end: two runs of 8 s wrote
    12.7 MB of traceback between them. Why it takes /dev/null for a console was not established.
    /dev/null is NUL there, a character device, which is the likely reason and no more than that.

A heredoc is NOT what hangs. `python - <<'PY'` with a body holding both kinds of quote ran and
exited 0, and so did `cat <<'X'` with an empty body. Of the three commands #645 records, the one
that completed held neither shape above. The two that ran to the timeout each held one beside
their heredoc: a bare `cat` in front of it, or a `< /dev/null` after it, which replaces the
heredoc as stdin. That `python - <<'PY'` ran says something of quotes and nothing of a backslash:
its body held none. A PAIR OF BACKSLASHES, below, is what a quoted heredoc does not protect.

WHAT IS REFUSED, each simple command of the line judged by itself:

  - `cat` with no file operand, when nothing feeds it: no pipe into it, no `<`, no heredoc and no
    here-string.
  - Python given `-` for its script, or given no script and no `-c` or `-m`, when nothing feeds
    it or when the LAST thing redirected into it is /dev/null. An option that prints and exits
    (`--version`, `-V`, `-h`, any option of two hyphens and a name, the launcher's `-0`) counts
    as a script.

A pipe feeds the command after it, on the same line or on the next. A pipe into a group, `| {`
or `| (`, is taken to feed every command after it, to the end of the whole command and not only of
its line, the group's end not being tracked.

WHAT IS LET THROUGH ON PURPOSE:

  - `<<` inside a quoted argument. Quoted text is blanked before anything is looked for, so
    `echo "a << b"` holds no heredoc and no command of its own.
  - A here-string, `<<<`. It feeds the command a line and ends, so nothing hangs.
  - A heredoc of HEREDOC_LINES lines or fewer that feeds the command. It does not hang. On
    Windows it is refused all the same when the command holds a pair of backslashes (#682).

A LONG HEREDOC IS REFUSED TOO (#666), though it does not hang: one whose body is over
HEREDOC_LINES lines, 60, counted without the line that ends it. The trouble a heredoc has here is
a body cut short on a quote, `unexpected EOF while looking for matching '`, after which nothing
runs. docs/agents/issue-tracker.md says to write the file with the Write tool, and a session that
had that in context sent nine Bash commands holding a heredoc on 2026-10-09 all the same.

LENGTH DOES NOT PREDICT THAT FAILURE. Of those nine, the one whose longest body was 129 lines,
in a command of 132, was cut short, and the one of 121, in a command of 124, ran; the other
seven, of 34 lines or fewer, ran. So the 60 is not where
heredocs start to fail. It is the tracker page's record of the earlier ones, "Every command that
failed ran past 60 lines", taken as the size past which a body is a file and is written as one.
It refuses long heredocs that would have worked. The log holds each command refused, and
not how it would have ended.

A PAIR OF BACKSLASHES IS REFUSED ON WINDOWS (#682, decided by Truls on 2026-10-12): any command
that holds two backslashes in a row, anywhere in it. Such a command does not hang. It runs as
something other than what was written, because a Bash tool command here loses one backslash of
every two before bash runs it. Reproduced on 2026-10-11 with GNU bash 5.1.16 (msys), each row
run as a Bash tool command and its left cell read from the session's transcript:

    in the command as sent                                  what the program received
    `A\\\\B` as a line of a `<<'EOF'` heredoc, 4 backslashes  2 backslashes
    `echo 'Z\\Z'`                                            `Z\Z`
    `echo 'a\\\b'`                                           `a\\b`
    `echo 'a\b'`                                             `a\b`, unchanged

So a pair becomes one and a lone backslash is kept, inside single quotes and inside a quoted
heredoc alike, neither of which bash itself touches. A file written with the Write tool is not
changed.

WHERE IT HAPPENS, read on 2026-10-12: between the Windows command line and bash's arguments. One
command held `: 'MARK\\MARK'`. The command line of its bash process, from `Get-CimInstance
Win32_Process` for the pid in /proc/$$/winpid, held both backslashes, and /proc/$$/cmdline held
one. Claude Code passes the command as one double-quoted `-c` argument, so no quoting inside the
command reaches far enough to help, and this hook, handed the command before that, sees it whole.
anthropics/claude-code#85856 gives the cause: the command line is quoted by the Microsoft C
runtime's rules and Git Bash decodes it by its own, so n backslashes arrive as ceil(n/2).

THE TEST IS MADE ON THE COMMAND AS SENT, before quoted text is blanked, and has no exemptions.
Three shapes are refused though they would have run as written:

  - a pair directly before a double quote, which is not halved: `echo 'p\\"q'` printed `p\\"q`.
  - a pair inside double quotes, which bash halves itself, so that the result is what any shell
    gives: `echo "x\\"` printed `x\`.
  - a pair in a `#` comment. Not run; nothing reads a comment.

Of 4 315 Bash tool commands in this project's transcripts on 2026-10-12, 58 held a pair, and one
of the 58 had its pairs only in the first shape. The PowerShell tool keeps a pair:
`Write-Output 'Z\\Z'` printed `Z\\Z`.

IT IS OFF ON ANY OTHER PLATFORM. verdict() asks for it only where sys.platform is "win32", which
is what Windows' Python reports beside Git Bash; under WSL or on Linux nothing is halved. judge()
applies it wherever it runs, so CASES prove it on the workflow's Linux runner too.

NOTHING RETIRES THIS RULE BUT A PERSON. If Claude Code or Git Bash stops halving, every refusal
of a pair is a false one. Read anthropics/claude-code#85856 first. Then take this script out of
`.claude/settings.json` for one command and run `echo 'Z\\Z'` as a Bash tool command: `Z\Z`
means the halving holds.

#666 SET TWO FAILURES ASIDE THAT WERE THIS. It says of them that the session "had written a `\n`
inside a Python string that held source text, and Python made it a line break". The session had
written that backslash doubled, and the halving made it single. Read on 2026-10-12 from that
session's transcript: two commands of 2026-10-09, sent at 09:18 and 09:22 UTC, each a heredoc
that `cat` wrote to an edit script. The first script wrote a line break into this file's source,
which then failed as an unterminated string. The second's search string no longer matched.

WHAT IT CANNOT SEE:

  - any other reader. # ponytail: only `cat` and Python are known, the two that hung. A bare
    `grep pattern`, `sort` or `jq .` waits the same way; add a reader here when one hangs,
    with what counts as its file operand.
  - a command inside double quotes, `"$(cat)"`, or handed to `bash -c '...'`. Quoted text is
    blanked. A heredoc there is not counted either, however long:
    `git commit -m "$(cat <<'EOF' ...)"`.
  - where a double-quoted span ends when it holds a `$(...)` with quotes of its own. The span
    is taken to end at the first inner `"`, so the rest of such a line is read as commands, and
    a heredoc body inside it that has a line opening with `cat` or `python -` is a false
    refusal. `git commit -m "$(cat <<'EOF' ...)"` with an odd count of `"` in its body is one.
  - a shift inside arithmetic, `$(( 1 << 3 ))`. It is taken for a heredoc, and what follows it
    for the body, so a reader after it is let through, and a command with more than
    HEREDOC_LINES lines after it is refused as a long heredoc.
  - a reader that is the first command of a loop's body, straight after `do`. What feeds a loop
    is written at its other end, `while read f; do ...; done < list`, or before it, so that
    command is not judged. A later command of the body is judged like any other, and a `cat`
    there is refused although the loop feeds it: `while read l; do echo; cat; done < list`.
  - a reader anywhere after a group that a pipe fed, on its line or a later one, for the reason
    above: `echo hi | { head -1; }; cat`.
  - a reader behind a wrapper other than the few skipped below, or behind a shell function.
    `timeout` is skipped with its `-s` and `-k` values; another option of its that takes a
    value is not known.
  - a command that hangs for any reason other than its stdin.
  - a pair of backslashes, when this script is run by a Python that does not report "win32" on
    Windows. One built for MSYS or Cygwin is said to report its own name; none was tried.

WHAT IS KEPT (#660). Each refusal appends one line of JSON to `.claude/refused-bash.log` at the
root of the repository this script is in: the time, the reason and the command. `.claude/*` is
git-ignored, so the log is this machine's. It is where a false refusal is counted from: read the
commands there and see which would not have hung, which heredoc would have run, or which pair of
backslashes was in one of the three shapes that run as written. A command let
through writes nothing, so a false pass is not in it; the hook does not see how a command ended.
A log that cannot be written is passed over, and the call is refused just the same.

`--self-test` runs the cases at the foot and exits non-zero when one is judged wrongly, when a
refusal is not logged as above, or when a pair of backslashes is the reason given on another
platform or out of its turn. It writes to a temporary directory and never to the log. It is run
by scripts/run-gates.ps1 and by .github/workflows/gates.yml (#659).
"""
import datetime
import json
import os
import re
import sys
import tempfile

LOG = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   ".claude", "refused-bash.log")

WRAPPERS = {"time", "nohup", "command", "exec", "env", "winpty",
            "then", "else", "if", "elif", "!"}      # not `do`: see WHAT IT CANNOT SEE
PYTHON = re.compile(r"^(?:python[\d.]*|py)(?:\.exe)?$")
WORD = r"[^\s;&|()<>]+"     # a redirect's target ends at an operator, as at a space
FEED = r"<<<\s*" + WORD + r"|<<H|\d*<\s*(?!<)" + WORD
NULLS = {"/dev/null", "nul", "NUL"}
PAIR = chr(92) * 2          # two backslashes in a row: halved before bash runs the command
HEREDOC_LINES = 60         # the longest heredoc body let through; the docstring says why 60


def blank(command, bodies=None):
    """The command with each quoted span turned into the word Q, each heredoc into `<<H` with
    its body dropped, and comments gone. What is left can be split on shell operators.

    Given a list for `bodies`, it gains each heredoc body's count of lines."""
    out, pending, i, n = [], [], 0, len(command)
    while i < n:
        c = command[i]
        if c == "\\" and i + 1 < n:
            out.append("Q")
            i += 2
        elif c == "'":
            end = command.find("'", i + 1)
            i = n if end < 0 else end + 1
            out.append("Q")
        elif c == '"':
            i += 1
            while i < n and command[i] != '"':
                i += 2 if command[i] == "\\" else 1
            i += 1
            out.append("Q")
        elif command.startswith("<<<", i):
            out.append(" <<< ")
            i += 3
        elif command.startswith("<<", i):
            m = re.match(r"<<(-?)\s*(?:\\|(['\"]))?([\w.-]+)(?(2)\2)", command[i:])
            if not m:
                out.append("<<")
                i += 2
                continue
            pending.append((m.group(3), bool(m.group(1))))
            out.append(" <<H ")
            i += m.end()
        elif c == "\n" and pending:
            # The bodies start on the next line, in the order their heredocs were opened.
            i += 1
            for word, tabs in pending:
                lines = 0
                while i < n:
                    end = command.find("\n", i)
                    end = n if end < 0 else end
                    line = command[i:end]
                    i = min(end + 1, n)
                    line = line.rstrip("\r")       # a command sent with CRLF line ends
                    if (line.lstrip("\t") if tabs else line) == word:
                        break
                    lines += 1
                if bodies is not None:
                    bodies.append(lines)
            pending = []
            out.append("\n")
        elif c == "#" and (i == 0 or command[i - 1].isspace()):
            end = command.find("\n", i)
            i = n if end < 0 else end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def judge(command, pairs=True):
    """Why this command is refused, as a sentence, or None: it would hang, it holds a pair of
    backslashes, or it holds a long heredoc. The first of those that applies is the reason.

    `pairs` false leaves the second out; verdict() decides it."""
    bodies = []
    text = blank(command, bodies)
    # Output redirects carry `&` and `|` that are not operators; they say nothing about stdin.
    text = re.sub(r"\d*>&\d+|\d*>&-|&>>?\s*" + WORD + r"|\d*>[>|]?\s*" + WORD, " ", text)
    # `|&` is a pipe, and a pipe at a line's end carries on to the next line.
    text = re.sub(r"\|&?\s*\n\s*", "| ", text.replace("|&", "|"))
    piped = False              # the last pipeline ended in a pipe: it feeds a group, `| ( cat )`
    for pipeline in re.split(r"\|\||&&|[;&\n(){}]", text):
        simples = re.split(r"\|", pipeline)
        for at, simple in enumerate(simples):
            feeds = re.findall(FEED, simple)
            words = re.sub(FEED, " ", simple).split()
            while words and (re.match(r"^\w+=", words[0]) or words[0] in WRAPPERS):
                words.pop(0)
            if words and words[0] == "timeout":
                words.pop(0)
                while words and words[0].startswith("-"):
                    words = words[2:] if words[0] in ("-s", "-k") else words[1:]
                words = words[1:]          # the duration
            if not words:
                continue
            name, args = words[0].rsplit("/", 1)[-1], words[1:]
            last = feeds[-1].lstrip("0123456789< \t") if feeds else None
            fed = bool(feeds) or at > 0 or piped
            from_null = last in NULLS

            if name == "cat" and not fed and not [a for a in args if not a.startswith("-")]:
                return ("`cat` with no file and nothing fed to it reads the Bash tool's stdin, "
                        "a pipe that is never closed")
            if PYTHON.match(name):
                script = None
                for k, a in enumerate(args):
                    if a in ("-W", "-X"):
                        continue
                    if k and args[k - 1] in ("-W", "-X"):
                        continue
                    prints = (a.startswith(("--", "-0")) and a != "--") or a in ("-V", "-VV", "-h", "-?")
                    if a in ("-c", "-m") or not a.startswith("-") or a == "-" or prints:
                        script = a
                        break
                if script in (None, "-") and (from_null or not fed):
                    return ("Python reading its program from /dev/null starts the interactive "
                            "prompt here and never ends" if from_null else
                            "Python with no script and nothing fed to it reads the Bash tool's "
                            "stdin, a pipe that is never closed")
        # Where the group ends is not tracked, so everything after its pipe counts as fed.
        piped = piped or (bool(pipeline.strip()) and not simples[-1].strip())
    if pairs and PAIR in command:
        return ("the command holds two backslashes in a row, and a pair reaches bash as one here; "
                "put the text in a file, or use the PowerShell tool, which keeps them")
    if bodies and max(bodies) > HEREDOC_LINES:
        return (f"a heredoc body of {max(bodies)} lines is over the {HEREDOC_LINES} this hook lets "
                "through; a long one has been cut short on a quote here, and nothing ran")
    return None


CASES = [
    # (the command, whether it is refused)
    ("cat > /dev/null", True),                                           # 2026-10-08 06:14, its first half
    ("cat > /dev/null; python - \"$@\" <<'PY'\nprint(1)\nPY", True),     # the same command whole
    ("python - <<'PY' < /dev/null\nPY\n", True),                         # 2026-10-08 06:48
    ("cat > /dev/null < /dev/null; python - < /dev/null; python -c \"print(1)\"", True),
    ("gh issue list; python < /dev/null", True),
    ("timeout 8 python -", True),
    ("FOO=1 python3 -X utf8 -", True),
    ("git log | head; cat", True),
    ("timeout -s KILL 5 cat > /dev/null", True),                         # run 9 of the reproduction
    ("if true; then cat; fi", True),
    ("python -- -", True),
    ("while read l; do echo; cat; done < list.txt", True),               # a known false refusal
    ("git ls-files | while read f; do cat; done", False),
    ("while read l; do cat; done < list.txt", False),
    ("echo hi | { head -1; cat; }", False),
    ("echo hi | (read x; cat)", False),
    ("echo hi | (head -1)\ngit status\npython -", False),                # a known false pass
    ("python --version && py -0 && python -V; python3 -h", False),
    ("git log |\n  cat", False),
    ("curl -s x |& python -", False),
    ("echo hi | (cat > f)", False),
    ("echo hi | { cat; }", False),
    ("cat > f.py <<'X'\n" + "line\n" * 61 + "X\n", True),                # a heredoc over HEREDOC_LINES
    ("cat > f.py <<'X'\n" + "line\n" * 60 + "X\n", False),               # one of exactly that many
    ("git log; python - <<'PY'\n" + "x = 1\n" * 61, True),               # and one that never ends
    ("cat > f <<'X'\r\na\r\nX\r\n" + "echo hi\r\n" * 61, False),         # CRLF: the body ends at X
    ("cat <<\\EOF\npython -\nEOF\n", False),
    ("cat > /dev/null <<'X'\nX\n", False),                               # 2026-10-07 22:12, completed
    ("python - <<'PY'\nimport sys\nprint(\"it's\")\ncat\nPY\necho done", False),
    ("python - <<< 'print(1)'", False),                                  # a here-string
    ("echo \"a << b\"; echo 'cat'", False),                              # `<<` and a reader, both quoted
    ("git log | cat", False),
    ("cat file.txt | python -", False),
    ("cat -n \"my file\" 2>&1", False),
    ("cat < /dev/null", False),
    ("python tools/render-machine.py rf-heat-exchanger < /dev/null", False),
    ("python -c 'print(1)' && python -m json.tool x.json", False),
    ("git commit -m \"cat\" # python -", False),
    ("echo 'Z\\\\Z'", True),                                             # #682: a pair, in quotes
    ("echo 'Z\\Z'", False),                                              # and a lone backslash
    ("python - <<'PY'\nprint(r\"\\\\s+\")\nPY", True),                   # a pair in a short heredoc
    ("python - <<'PY'\nprint(r\"\\s+\")\nPY", False),
    ("sed 's/a\\\\/b/' f.txt", True),                                    # and on a command line
    ("echo 'p\\\\\"q' # a\\\\b", True),                                  # refused though it would run
    ("echo a \\\n\\ b", False),                     # a line's last character and the next line's first
]


def verdict(call, log=LOG, platform=sys.platform):
    """Why this tool call is refused, or None. A refusal is appended to the log on the way.

    A pair of backslashes is a reason on Windows only, which is where one is halved."""
    if call.get("tool_name", "Bash") != "Bash":
        return None
    command = (call.get("tool_input") or {}).get("command") or ""
    why = judge(command, pairs=platform == "win32")
    if why:
        try:
            with open(log, "a", encoding="utf-8") as f:
                now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
                f.write(json.dumps({"time": now, "why": why, "command": command}) + "\n")
        except OSError:
            pass                # the log is a record; the refusal does not wait on it
    return why


def log_wrong():
    """What verdict() does with the log that it should not, as sentences. None is wanted."""
    refused, passed = {"tool_input": {"command": "cat"}}, {"tool_input": {"command": "cat f"}}
    wrong = []
    with tempfile.TemporaryDirectory() as scratch:
        log = os.path.join(scratch, "refused.log")
        verdict(passed, log)
        if os.path.exists(log):
            wrong.append("a command let through wrote to the log")
        why = verdict(refused, log)
        verdict(passed, log)
        lines = open(log, encoding="utf-8").read().splitlines() if os.path.exists(log) else []
        entry = json.loads(lines[0]) if len(lines) == 1 else {}
        if (entry.get("why"), entry.get("command")) != (why, "cat") or not entry.get("time"):
            wrong.append(f"one refusal and two passes left these lines in the log: {lines!r}")
        try:
            if not verdict(refused, scratch):       # a directory: it cannot be opened to append
                wrong.append("a log that cannot be written let the command through")
        except Exception as e:
            wrong.append(f"a log that cannot be written raised {e!r}")
    return wrong


def pair_wrong():
    """What is wrong with when a pair of backslashes is the reason given, as sentences."""
    pair, long_one = "echo " + PAIR, "cat > f <<'X'\n" + "line\n" * (HEREDOC_LINES + 1) + "X\n"
    with tempfile.TemporaryDirectory() as scratch:
        log = os.path.join(scratch, "refused.log")
        said = lambda command, platform: verdict({"tool_input": {"command": command}}, log, platform) or ""
        checks = [
            ("a pair was not refused on win32", "two backslashes" in said(pair, "win32")),
            ("a pair was refused on linux", not said(pair, "linux")),
            ("a long heredoc was let through on linux", "heredoc" in said(long_one + pair, "linux")),
            ("a hang did not come before a pair", "never closed" in said("cat # " + PAIR, "win32")),
            ("a pair did not come before a long heredoc",
             "two backslashes" in said(long_one + pair, "win32")),
        ]
    return [what for what, held in checks if not held], len(checks)


def self_test():
    wrong = [f"wanted {'refused' if want else 'let through'}: {c[:200]!r}"
             for c, want in CASES if bool(judge(c)) != want]
    logged = log_wrong()
    paired, pair_checks = pair_wrong()
    for w in wrong + logged + paired:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"{len(CASES) - len(wrong)} of {len(CASES)} cases judged as wanted, "
          f"{3 - len(logged)} of 3 checks of the log held, and {pair_checks - len(paired)} of "
          f"{pair_checks} checks of when a pair is the reason.")
    return 1 if wrong or logged or paired else 0


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    why = verdict(json.load(sys.stdin))
    if not why:
        return 0
    print(f"Refused before it ran: {why}. Write the script or the text to a file with the Write "
          "tool and give the command that file's path. A command left reading can be fed with a "
          "pipe or `< file` instead. tools/refuse-hanging-bash.py says what is refused.",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
