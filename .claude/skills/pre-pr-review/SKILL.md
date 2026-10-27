---
name: pre-pr-review
description: Run this repository's pre-PR review on the current branch. One fresh read-only reviewer is handed the diff against origin/main, docs/agents/code-review.md, and the gate result or the probes' raw output; the same reviewer then confirms the fixes; the result is the findings table for the pull request's body. Use when a branch is ready for its pull request, or when an implement skill says to close out with /code-review.
---

# /pre-pr-review

Runs the **pre-PR review** that `docs/agents/code-review.md` defines under *A review before the pull
request, and the plugin pass after it*. That file is the rule; this is the procedure. It needs no
pull request and it is not the plugin pass, which `/plugin-pass` runs once the pull request is open.
The same section says when the plugin pass runs and who confirms its fixes. Leave the reviewer from
step 3 running after step 6: that section has more for it to do. Step 7 is done after the plugin
pass.

## Steps

1. **Commit the work**, so the review and the fixes are two diffs. Each commit body on the branch,
   this one's and every later one's, is written as `docs/agents/code-review.md` says under *A review
   before the pull request, and the plugin pass after it* (#671). A branch that changes a rule
   commits the rule and its measurements in this step, and its line on
   `docs/agents/code-review-history.md` waits for step 7, as the head of
   `docs/agents/code-review.md` says (#760). Write both diffs to the session's scratchpad, never
   into the repository. **First fetch `origin/main`** (#755, #758), so this diff, step 7's and the
   markdown-only test in step 2 read against the `main` the branch merges into. Each reads
   `origin/main` and never the local `main`. Where the first line fails, stop and tell the user
   git's message: it fails with no network or no access to the remote.

   ```
   git fetch origin main                   # moves origin/main only
   git tag -f pre-pr-reviewed HEAD         # the reviewed commit; step 4 needs it. Never pushed
   git diff --output="<scratch>/branch.diff" origin/main...HEAD
   python tools/review-coverage.py record origin/main..HEAD   # the range handed; step 5 (#781, #787)
   ```

   **A review of part of the branch gives these lines that part's range, before they run**
   (#781): the `git diff` and the `record` line both, so the script records only what the
   reviewer is handed. Its docstring says where it keeps what it records and how a subject
   matches.

   **Have git write the diff, and quote the path** (#635). Each line runs unchanged in Git Bash
   and in PowerShell, with `<scratch>` in either form of path. A `>` redirect to an unquoted
   backslash path does not: Git Bash drops the backslashes and writes a file named for the whole
   path into the current directory. Two `.diff` files of that shape sat in the repository root
   from September until 2026-10-08.

2. **Save the evidence to a file** in the same directory. Which evidence depends on the branch:

   - a branch that records measurements: the raw output of each probe a figure came from. That
     is a copy of the probe's report in `.probe-reports/` (#589), whose arguments, date and game
     version are the ones the note gives. Where they are not, run the probe again first;
   - any other branch: the output of the gates that were run — `scripts/run-gates.ps1` when the
     branch combines more than one ticket, otherwise the gates the change touches. A
     markdown-only branch, one where every path
     `git diff --name-only --no-renames origin/main...HEAD` prints ends in `.md`, runs
     `scripts/ship-check.ps1` alone however many tickets it combines (#618).

   Done when every figure or pass the branch claims has its output in a file.

3. **Spawn one fresh reviewer** with the Agent tool: `general-purpose`, never a fork, since a fork
   has already read the author's reasoning. Give it a `name` so step 4 can reach it, and a
   `description` that starts `Pre-PR review`, which step 6's script sorts it by (#661). Its brief is
   the block below with the paths filled in and nothing about what the author thinks is right,
   and nothing that excuses a commit in the diff: step 1 recorded every commit in it as handed
   (#781).

   > You are the pre-PR reviewer of a branch of this repository. Read `docs/agents/code-review.md`
   > in full first; its second rule, *Review the prose, not only the code*, binds you. Then review
   > `<scratch>/branch.diff` (`<the diff against origin/main | the diff of <range>>`) against
   > `<evidence files>`, which hold `<the probes' raw output | the gate results>`.
   >
   > The branch claims to resolve `<#n, #n>`. Read each with the **Read an issue** command in
   > `docs/agents/issue-tracker.md` and hold the diff against its acceptance criteria. If the
   > branch resolves more than one ticket and the evidence is `ship-check.ps1` alone, confirm
   > that every path `git diff --name-only --no-renames origin/main...HEAD` prints ends in `.md`.
   >
   > Read whole each of these, which the diff changes: `<each skill file, page under
   > docs/agents/ and CLAUDE.md in the diff, or "none">`. Where the diff changes a step of a
   > skill, hold the step against the rule in `docs/agents/code-review.md`, or in
   > `docs/agents/plugin-pass.md`, that it carries out:
   > it restates none of the rule's reasons and leaves out nothing the rule requires. Say in your
   > report which files you read whole.
   >
   > List each claim the diff narrows, retracts or deletes the subject of, and search the tracked
   > files for every other statement of it by its meaning, as the second rule says. Your report
   > lists each claim, the files searched for it, and each hit, as a finding or as checked, with
   > the words each checked hit was checked on.
   >
   > A claim in the diff about a Factorio API class, method, parameter or attribute is checked
   > in the game's own reference (#793): `runtime-api.json` and `prototype-api.json` in the
   > `doc-html` directory of the install, beside the `bin` that holds the `Factorio.exe`
   > `Resolve-FactorioExe` resolves, which is `$env:FACTORIO_EXE` where that is set and
   > `D:\SteamLibrary\steamapps\common\Factorio\bin\x64\Factorio.exe` where it is not. Read the
   > member there by name: a runtime class's under its `methods` or `attributes`, a
   > prototype's under its `properties`, inheritance through `parent`, and a concept, event,
   > define or prototype type under `concepts`, `events`, `defines` or `types`. The files are the
   > installed game's, so they hold the version the gates run against; `application_version`
   > names it.
   >
   > You are read-only: edit, commit and run nothing that changes the working tree. If proving a
   > finding takes a planted change, make your own worktree first, as the third rule says. Scratch
   > files go in `<scratch>/reviewer/`.
   >
   > Return every finding as a numbered list, one you could not verify included, said to be
   > unverified. For each: the file and the quoted words or code, what is wrong, and the source
   > that shows it. Give no score.
   > Say so plainly if you found nothing, and say what you did not check. A table's cell counts
   > in a tracked `.md` are held by `scripts/ship-check.ps1`, each row to its header; a row of a
   > quoted table that has lost its `>` it does not catch, and a table in the pull request's body
   > it does not read.
   >
   > Reply with one line per finding first: its number, the file and the fault. Give
   > the detail for a finding when you are asked for it. A long reply arrives cut off.

   **Ask for a finding's detail with SendMessage when its line does not name the place and the
   fault** (#668), and for the rest of any reply that stops mid-sentence. A line that names both
   is fixed from the line. On this skill's first run a report sent whole stopped inside the sixth
   of nine findings, and the reviewer's attempt to write the rest to a file was refused. On #664
   each of the 17 findings' lines named both; no detail was asked for, 16 were fixed from the
   lines and confirmed, and one, finding 11, needed no change.

   **The report arrives as a message from the reviewer once this session's turn has ended**
   (#648). End the turn to receive it; the message starts the session's next turn. A question
   put to the user does not end the turn, and nothing from the reviewer arrives while one is
   pending. If something else starts the next turn first, or the reply came cut off and asking
   does not get the rest, read it from the reviewer's transcript, the file step 6 names.

4. **Fix, commit, and continue the same reviewer** with SendMessage to the name from step 3. Do
   not spawn a second one. Hand it the diff of the fixes and nothing else:

   ```
   git diff --output="<scratch>/fixes.diff" pre-pr-reviewed..HEAD
   python tools/review-coverage.py record pre-pr-reviewed..HEAD
   ```

   Every diff sent to the reviewer, here, in step 5, in step 7 and for the plugin pass's fixes,
   is recorded the same way, from its own range (#781).

   > `<scratch>/fixes.diff` is every change made since your review. For each of your findings,
   > say whether it is fixed, from the diff alone. Where your finding named a group, check the
   > fix against each member. Then review every other added line in that
   > diff as new work: a fix that adds a sentence adds a claim. Number any new finding on from
   > your last, with no score. Reply with one line per finding.

   **Do not send a list of what was done for each finding.** On #594 the reviewer was sent one,
   confirmed against the list, and passed a false sentence a fix had added. A finding left unfixed
   on purpose is named to the reviewer as left, with the reason, and nothing more.

   Before writing a fix, read what *Review the prose, not only the code* in
   `docs/agents/code-review.md` asks of the session that writes one (#632), and of one that
   changes what a rule allows (#788), and the paragraph under *A review before the pull request,
   and the plugin pass after it* on the fixes put to Truls first (#782).

   **When a finding corrects a figure or a claim, reword the commits that state the old one**
   (#640), except where a later message spares one (#783). The rule, and where it
   stops, is in `docs/agents/code-review.md` under *A review before the pull request, and the
   plugin pass after it*. Find them, write the corrected message to
   `<scratch>/msg.txt` with the Write tool, and reword one commit at a time. These lines are for
   Git Bash, with `<scratch>` written with forward slashes: `cp` is handed the path unquoted.

   ```
   git log -z origin/main..HEAD --format='%h %s%n%b' | tr '\n\0' ' \n' \
     | grep -F '<the old figure or words>' | cut -c1-72
   GIT_SEQUENCE_EDITOR="sed -i 's/^pick <short hash>/reword <short hash>/'" \
     GIT_EDITOR="cp <scratch>/msg.txt" git -c core.commentChar=";" rebase -i <short hash>~1
   python tools/review-coverage.py record -1 <new hash>   # where the subject changed (#781)
   git push --force-with-lease             # a pushed, unmerged branch only; never main
   ```

   **The `git log` line joins each message onto one line before it matches** (#814). A body is
   wrapped at 72, and `--grep` matches within one line, so it misses words a wrap splits. On
   #811 the claim "prints ok or raises" was wrapped after "prints" in the branch's first commit,
   and `--grep='prints ok'` did not find it. A search that finds nothing rewords nothing and says
   nothing. The line prints each hit's hash and the start of its message.

   **Run the `git log` line again before each reword.** A reword gives every later commit a new
   hash, and a rebase handed a hash that is no longer on the branch exits 0, rewords nothing and
   puts the earlier commit's old message back.

   **`-c core.commentChar=";"` keeps a body line that starts with `#`** (#681). Git takes the
   message `cp` puts in place as one an editor wrote and drops each line that starts with its
   comment character, which is `#` unless it is set. On #679 a body that began "#626 asked"
   lost that line. With the character set, a body line must not start with `;`: git drops that
   one in its place.

   The same section says why the rebase starts at the commit's parent and why the `fixes.diff` line
   above gives the same diff after a reword. Delete the tag when the branch has merged.

   The confirmation arrives as step 3's report does.

   **A new finding is fixed, committed and held, every one alike** (#643, #653): send no
   message for it, and write it `yes, not confirmed` in step 6. `docs/agents/code-review.md`, in
   the same section, says when its fix is confirmed.

   Done when the reviewer has answered for every finding of its review.

5. **Before anything is written to the pull request's body, show that a reviewer was handed every
   commit** (#781). `docs/agents/code-review.md` has the rule under *A review before the pull
   request, and the plugin pass after it*:

   ```
   python tools/review-coverage.py check
   ```

   Each commit it lists is one no reviewer was handed (#787). A held fix (#643) may be listed; stop
   on any other and send its commit to the reviewer first, as step 4 sends a fix.

   **Then invoke the `mattpocock-skills:pr` skill** with the Skill tool for `## Summary`,
   `## Evidence` and `## Merge Danger` (#738, #748); where it is not installed, write them by hand
   to the shape of its template, which `docs/agents/code-review.md` lists. Put one `Closes #N`
   line per ticket above them, and the `## Pre-PR review` section below them, as
   `docs/agents/issue-tracker.md` requires (#730). That section opens by naming each diff the
   reviewer was handed by the subjects of its commits.

   **Then answer for each thing the reviewer said it did not check** (#636). *A review before the
   pull request, and the plugin pass after it* in `docs/agents/code-review.md` says how an item is
   checked and what the pull request's body records for it. Check each item, or send it to the
   reviewer by name with SendMessage, and write the outcome of each under the `## Pre-PR review`
   heading. A defect that an item turns up is fixed, and its fix is sent to the reviewer in a
   message of its own with the diff, as step 4 sends one. It is never held.

   Done when the body has the three headings from the skill, or from its template by hand, with
   **Before:** and **After:** under Evidence and **Door:** and **Blast Radius:**
   under Merge Danger (#753), the `Closes #N` lines above them, and every item on the reviewer's
   list has an outcome written for it.

6. **Write the findings table** and put it in the pull request's body under the same heading,
   below step 5's outcomes, every finding in it:

   | # | Finding | Where | Fixed |
   |---|---|---|---|
   | 1 | one line, in the reviewer's terms | file, and the symbol or quoted words | yes, confirmed |
   | 2 | … | … | no: the reason it was left |

   **Fixed** is `yes, confirmed` only when the reviewer has said so; otherwise `yes, not confirmed`,
   `no: waits on Truls` (#782) or `no: <reason>`. The findings carry no score (#610). A review
   that found nothing says that in the body in place of the table, below step 5's outcomes for what
   the reviewer said it did not check. A cell that names a commit of the branch names it by its
   subject in quotes, not its hash (#730).

   **Check the body before it is sent** (#730), each time, the first `gh pr create` and every
   `gh pr edit` after it, this step's and step 7's included:

   ```
   pwsh -NoProfile -File vendor/grado-factorio-tools/scripts/pr-body-check.ps1 "<scratch>/body.md" && gh pr edit <n> --body-file "<scratch>/body.md"
   ```

   A body it fails is not sent; `docs/agents/issue-tracker.md` has what it checks.

   **Under the table, write what the reviewer cost** (#631). A reviewer reached by name goes idle
   and sends no completion notice, so nothing reports its usage. Read it from the session's own
   `subagents` directory, `projects/<project>/<session id>/subagents` under the Claude configuration
   directory, where the reviewer's transcript is the one file matching `agent-a<name>-*.jsonl`.
   **The session ID is the running session's**, which the environment holds as
   `CLAUDE_CODE_SESSION_ID`, and the configuration directory is `CLAUDE_CONFIG_DIR` where that is
   set and `~/.claude` where it is not (#705). The output-file path the Agent tool reports for a
   background subagent is no guide to it: on #700 it named an earlier session, whose directory held
   none of that pass's transcripts. Give the directory to the tracked script (#661):

   ```
   python tools/review-usage.py "<that directory>"
   ```

   It prints a line for each subagent, then the figures as the two tables of
   `docs/agents/review-figures.md` hold them. Write the pre-PR review's two, its last request and
   its total over all requests, and what share of the total is cache reads. The first is the one
   the first table holds, and the second the one the second table holds; that page says what each
   measures (#644). Read them again after the reviewer's last confirmation, the one of the plugin
   pass's fixes, and replace the figures in the body. Each table's row keeps the figure read when
   the row was written. If the script prints no line for the reviewer, write "not measured". The
   same run prints the plugin pass's figures once that pass has run, which is how the session that
   runs it reads them (#634). A session that reviews two pull requests gives the script two
   texts after the directory, the pull request's number as `"#<n>"` and this reviewer's name, and
   the script counts only the subagents that hold one of them.

   **Under the reviewer's cost, write the main session's own** (#670): the script's last lines.
   Where this session did other work before the branch, add `"--since=<text>"` with the
   arguments of the command that started the work; the script's docstring says how the part is
   bounded. Read it again with the reviewer's figures, when the body is last edited.

7. **Read the branch's counts again, after the last fix commit** (#663).
   `docs/agents/code-review.md` has the rule under *Review the prose, not only the code*: what is
   read again and how. This step comes after the skill's others and after the plugin pass: run it
   when the reviewer has confirmed that pass's fixes and no fix is left to commit, before the body
   is edited for the last time.

   **Where the branch changes a rule, first write its line on `docs/agents/code-review-history.md`**
   (#716), from the rule's wording at the head. Commit it, run `scripts/ship-check.ps1`, and send
   its diff to the reviewer as step 4 sends a fix, and wait for the answer: a finding in it is fixed
   and confirmed before the reading below, which is made on the head after it.

   These lines list what the rule names:

   ```
   gh pr view <n> --json body --jq .body         # its counts, and each output it quotes
   git diff -U0 origin/main...HEAD               # each count the branch added to tracked prose
   grep -n "#<n>" docs/agents/review-figures.md  # the row's pre-PR findings cell (#715)
   git log origin/main..HEAD --format="%h %s%n%b" # the branch's own commit messages
   ```

   Run each command the body quotes output from, on the head. Count what each count counts. A
   commit message that the head contradicts is reworded as step 4 says; one that a later message
   names and narrows, as the rule has it, is not contradicted (#783). Tracked prose is a
   comment or a help block as much as a `.md` file. What the reading turns up is fixed and
   committed, its diff is sent to the reviewer in a message of its own as step 4 sends one, and
   what that fix changed is read again. **A fix that only corrects a count gets no message**
   (#665): the rule says which fix that is. Commit it and read again what it changed. Then run
   step 5's `check` again (#781): a fix that only corrects a count is the only kind it may list
   now, and each it lists is named in the body as not confirmed.

   Done when the body has, under the `## Pre-PR review` heading, a line that names what was read
   again and the head it was read on, the last one if a fix moved it, by its subject (#730):
   `Read again on "<the head's subject>": <each count and each quoted output, and that the commit
   messages were read>`. The line names each fix that got no message, as not confirmed. The body
   is checked before it is sent, as step 6 says.

## What this does not do

It briefs no scorer and no verifier, and the reviewer gives its findings no score (#610). Every
finding is reported.
