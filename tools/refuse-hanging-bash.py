"""A PreToolUse hook for the Bash tool: refuse a command that would hang on its input (#645).

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
heredoc as stdin.

WHAT IS REFUSED, each simple command of the line judged by itself:

  - `cat` with no file operand, when nothing feeds it: no pipe into it, no `<`, no heredoc and no
    here-string.
  - Python given `-` for its script, or given no script and no `-c` or `-m`, when nothing feeds
    it or when the LAST thing redirected into it is /dev/null. An option that prints and exits
    (`--version`, `-V`, `-h`, any option of two hyphens and a name, the launcher's `-0`) counts
    as a script.

A pipe feeds the command after it, on the same line or on the next. A pipe into a group, `| {`
or `| (`, is taken to feed every command after it on the line, the group's end not being tracked.

WHAT IS LET THROUGH ON PURPOSE:

  - `<<` inside a quoted argument. Quoted text is blanked before anything is looked for, so
    `echo "a << b"` holds no heredoc and no command of its own.
  - A here-string, `<<<`. It feeds the command a line and ends, so nothing hangs.
  - A heredoc that feeds the command. It does not hang. The trouble a heredoc has here is another
    one, a body cut short on a quote, and docs/agents/issue-tracker.md still says to write the
    file instead.

WHAT IT CANNOT SEE:

  - any other reader. # ponytail: only `cat` and Python are known, the two that hung. A bare
    `grep pattern`, `sort` or `jq .` waits the same way; add a reader here when one hangs,
    with what counts as its file operand.
  - a command inside double quotes, `"$(cat)"`, or handed to `bash -c '...'`. Quoted text is
    blanked.
  - where a double-quoted span ends when it holds a `$(...)` with quotes of its own. The span
    is taken to end at the first inner `"`, so the rest of such a line is read as commands, and
    a heredoc body inside it that has a line opening with `cat` or `python -` is a false
    refusal. `git commit -m "$(cat <<'EOF' ...)"` with an odd count of `"` in its body is one.
  - a shift inside arithmetic, `$(( 1 << 3 ))`. It is taken for a heredoc, and what follows it
    for the body, so a reader after it is let through.
  - a reader in the body of a loop, after `do`. What feeds a loop is written at its other end,
    `while read f; do ...; done < list`, or before it, so the body is not judged at all.
  - a reader after a group that a pipe fed, `echo hi | { head -1; }; cat`, for the reason above.
  - a reader behind a wrapper other than the few skipped below, or behind a shell function.
    `timeout` is skipped with its `-s` and `-k` values; another option of its that takes a
    value is not known.
  - a command that hangs for any reason other than its stdin.

`--self-test` runs the cases at the foot and exits non-zero when one is judged wrongly.
"""
import json
import re
import sys

WRAPPERS = {"time", "nohup", "command", "exec", "env", "winpty",
            "then", "else", "if", "elif", "!"}      # not `do`: see WHAT IT CANNOT SEE
PYTHON = re.compile(r"^(?:python[\d.]*|py)(?:\.exe)?$")
WORD = r"[^\s;&|()<>]+"     # a redirect's target ends at an operator, as at a space
FEED = r"<<<\s*" + WORD + r"|<<H|\d*<\s*(?!<)" + WORD
NULLS = {"/dev/null", "nul", "NUL"}


def blank(command):
    """The command with each quoted span turned into the word Q, each heredoc into `<<H` with
    its body dropped, and comments gone. What is left can be split on shell operators."""
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
                while i < n:
                    end = command.find("\n", i)
                    end = n if end < 0 else end
                    line = command[i:end]
                    i = min(end + 1, n)
                    if (line.lstrip("\t") if tabs else line) == word:
                        break
            pending = []
            out.append("\n")
        elif c == "#" and (i == 0 or command[i - 1].isspace()):
            end = command.find("\n", i)
            i = n if end < 0 else end
        else:
            out.append(c)
            i += 1
    return "".join(out)


def judge(command):
    """Why this command would hang, as a sentence, or None when nothing in it is known to."""
    text = blank(command)
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
    ("git ls-files | while read f; do cat; done", False),
    ("while read l; do cat; done < list.txt", False),
    ("echo hi | { head -1; cat; }", False),
    ("echo hi | (read x; cat)", False),
    ("python --version && py -0 && python -V; python3 -h", False),
    ("git log |\n  cat", False),
    ("curl -s x |& python -", False),
    ("echo hi | (cat > f)", False),
    ("echo hi | { cat; }", False),
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
]


def self_test():
    wrong = [(c, want) for c, want in CASES if bool(judge(c)) != want]
    for c, want in wrong:
        print(f"WRONG: wanted {'refused' if want else 'let through'}: {c!r}", file=sys.stderr)
    print(f"{len(CASES) - len(wrong)} of {len(CASES)} cases judged as wanted.")
    return 1 if wrong else 0


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    call = json.load(sys.stdin)
    if call.get("tool_name", "Bash") != "Bash":
        return 0
    why = judge((call.get("tool_input") or {}).get("command") or "")
    if not why:
        return 0
    print(f"Refused before it ran (#645): {why}. Write the script or the text to a file with the "
          "Write tool and give the command that file's path; or feed it with a pipe or `< file`. "
          "tools/refuse-hanging-bash.py says what is refused.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
