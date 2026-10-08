---
name: pre-pr-review
description: Run this repository's pre-PR review on the current branch. One fresh read-only reviewer is handed the diff against main, docs/agents/code-review.md, and the gate result or the probes' raw output; the same reviewer then confirms the fixes; the result is the findings table for the pull request's body. Use when a branch is ready for its pull request, or when an implement skill says to close out with /code-review.
---

# /pre-pr-review

Runs the **pre-PR review** that `docs/agents/code-review.md` defines under *A review before the pull
request, and the plugin pass after it*. That file is the rule; this is the procedure. It needs no
pull request and it is not `code-review:code-review`, which is the plugin pass, and this skill does
not run that. The same section says when the plugin pass runs and who confirms its fixes. Leave the
reviewer from step 3 running when this skill ends: that section has more for it to do.

## Steps

1. **Commit the work**, so the review and the fixes are two diffs. Write both to the session's
   scratchpad, never into the repository:

   ```
   git tag -f pre-pr-reviewed HEAD         # the reviewed commit; step 4 needs it. Never pushed
   git diff --output="<scratch>/branch.diff" main...HEAD
   ```

   **Have git write the file, and quote the path** (#635). Both lines run unchanged in Git Bash
   and in PowerShell, with `<scratch>` in either form of path. A `>` redirect to an unquoted
   backslash path does not: Git Bash drops the backslashes and writes a file named for the whole
   path into the current directory. Two `.diff` files of that shape sat in the repository root
   from September until 2026-10-08.

2. **Save the evidence to a file** in the same directory. Which evidence depends on the branch:

   - a branch that records measurements: the raw output of each probe a figure came from;
   - any other branch: the output of the gates that were run — `scripts/run-gates.ps1` when the
     branch combines more than one ticket, otherwise the gates the change touches. A
     markdown-only branch, one where every path `git diff --name-only --no-renames main...HEAD`
     prints ends in `.md`, runs `scripts/ship-check.ps1` alone however many tickets it combines
     (#618).

   Done when every figure or pass the branch claims has its output in a file.

3. **Spawn one fresh reviewer** with the Agent tool: `general-purpose`, never a fork, since a fork
   has already read the author's reasoning. Give it a `name` so step 4 can reach it. Its brief is
   the block below with the paths filled in and nothing about what the author thinks is right:

   > You are the pre-PR reviewer of a branch of this repository. Read
   > `docs/agents/code-review.md` in full first; its second rule, *Review the prose, not only the
   > code*, binds you. Then review `<scratch>/branch.diff` (the diff against `main`) against
   > `<evidence files>`, which hold `<the probes' raw output | the gate results>`.
   >
   > The branch claims to resolve `<#n, #n>`. Read each with the **Read an issue** command in
   > `docs/agents/issue-tracker.md` and hold the diff against its acceptance criteria. If the
   > branch resolves more than one ticket and the evidence is `ship-check.ps1` alone, confirm
   > that every path in the diff ends in `.md`.
   >
   > Read whole each of these, which the diff changes: `<each skill file, page under
   > docs/agents/ and CLAUDE.md in the diff, or "none">`. Where the diff changes a step of a
   > skill, hold the step against the rule in `docs/agents/code-review.md` that it carries out:
   > it restates none of the rule's reasons and leaves out nothing the rule requires. Say in your
   > report which files you read whole.
   >
   > You are read-only: edit, commit and run nothing that changes the working tree. If proving a
   > finding takes a planted change, make your own worktree first, as the third rule says. Scratch
   > files go in `<scratch>/reviewer/`.
   >
   > Return every finding as a numbered list, one you could not verify included, at 25. For
   > each: the file and the quoted words or code, what is wrong, the source that shows it, and a
   > score of 0, 25, 50, 75 or 100
   > — 0 a false positive, 25 possibly real and unverified, 50 real but minor or rare, 75
   > verified and important, 100 certain and it will be hit. Report every one whatever it scores.
   > Say so plainly if you found nothing, and say what you did not check. A table's cell counts
   > in a tracked `.md` are held by `scripts/ship-check.ps1`, each row to its header, in a
   > blockquote or out of one; a table in the pull request's body it does not read.
   >
   > Reply with one line per finding first: its number, the file, the fault and the score. Give
   > the detail for a finding when you are asked for it. A long reply arrives cut off.

   **Ask for each finding's detail with SendMessage before fixing it**, and for the rest of any
   reply that stops mid-sentence. On this skill's first run a report sent whole stopped inside
   the sixth of nine findings, and the reviewer's attempt to write the rest to a file was refused.

   **The report arrives as a message from the reviewer once this session's turn has ended**
   (#648). End the turn to receive it; the message starts the session's next turn. A question
   put to the user does not end the turn, and nothing from the reviewer arrives while one is
   pending. If something else starts the next turn first, or the reply came cut off and asking
   does not get the rest, read it from the reviewer's transcript, the file step 6 names.

4. **Fix, commit, and continue the same reviewer** with SendMessage to the name from step 3. Do
   not spawn a second one. Hand it the diff of the fixes and nothing else:

   ```
   git diff --output="<scratch>/fixes.diff" pre-pr-reviewed..HEAD
   ```

   > `<scratch>/fixes.diff` is every change made since your review. For each of your findings,
   > say whether it is fixed, from the diff alone. Where your finding named a group, check the
   > fix against each member. Then review every other added line in that
   > diff as new work: a fix that adds a sentence adds a claim. Number any new finding on from
   > your last and score it the same way. Reply with one line per finding.

   **Do not send a list of what was done for each finding.** On #594 the reviewer was sent one,
   confirmed against the list, and passed a false sentence a fix had added. A finding left unfixed
   on purpose is named to the reviewer as left, with the reason, and nothing more.

   Before writing a fix, read what *Review the prose, not only the code* in
   `docs/agents/code-review.md` asks of the session that writes one (#632).

   **When a finding corrects a figure or a claim, reword the commits that state the old one**
   (#640). The rule, and where it stops, is in `docs/agents/code-review.md` under *A review before
   the pull request, and the plugin pass after it*. Find them, write the corrected message to
   `<scratch>/msg.txt` with the Write tool, and reword one commit at a time. These lines are for
   Git Bash, with `<scratch>` written with forward slashes: `cp` is handed the path unquoted.

   ```
   git log main..HEAD --format='%h %s' --grep='<the old figure or words>'
   GIT_SEQUENCE_EDITOR="sed -i 's/^pick <short hash>/reword <short hash>/'" \
     GIT_EDITOR="cp <scratch>/msg.txt" git rebase -i <short hash>~1
   git push --force-with-lease             # a pushed, unmerged branch only; never main
   ```

   **Run the `git log` line again before each reword.** A reword gives every later commit a new
   hash, and a rebase handed a hash that is no longer on the branch exits 0, rewords nothing and
   puts the earlier commit's old message back.

   The same section says why the rebase starts at the commit's parent and why the `fixes.diff`
   line above gives the same diff after a reword. Delete the tag when the branch has merged.

   The confirmation arrives as step 3's report does.

   **A new finding at 75 or over gets this step again. One under 75 is fixed, committed and
   held** (#643): send no message for it, and write it `yes, not confirmed` in step 6.
   `docs/agents/code-review.md`, in the same section, says when its fix is confirmed.

   Done when the reviewer has answered for every finding of its review and for each new one at 75
   or over.

5. **Answer for each thing the reviewer said it did not check** (#636). The same section of
   `docs/agents/code-review.md` says how an item is checked and what the pull request's body
   records for it. Check each item, or send it to the reviewer by name with SendMessage, and write
   the outcome of each for the pull request's body, under a `## Pre-PR review` heading. A defect
   that an item turns up is fixed, and its fix is sent to the reviewer in a message of its own
   with the diff, as step 4 sends one. It is never held.

   Done when every item on the reviewer's list has an outcome written for it.

6. **Write the findings table** and put it in the pull request's body under the same heading,
   below step 5's outcomes, every finding in it:

   | # | Finding | Where | Score | Fixed |
   |---|---|---|---|---|
   | 1 | one line, in the reviewer's terms | file, and the symbol or quoted words | 75 | yes, confirmed |
   | 2 | … | … | 50 | no: the reason it was left |

   **Fixed** is `yes, confirmed` only when the reviewer has said so; otherwise
   `yes, not confirmed` or `no: <reason>`. A review that found nothing says that in the body in
   place of the table, below step 5's outcomes for what the reviewer said it did not check.

   **Under the table, write what the reviewer cost** (#631). A reviewer reached by name goes idle
   and sends no completion notice, so nothing reports its usage. Read it from the reviewer's
   transcript: the one file matching
   `projects/<project>/<session id>/subagents/agent-a<name>-*.jsonl` under the Claude configuration
   directory. Save this as `<scratch>/usage.py` and give it that file's full path, not the pattern:

   ```python
   import json, sys
   total = lambda u: sum(v for k, v in u.items() if k.endswith("_tokens") and isinstance(v, int))
   everything = 0
   for path in sys.argv[1:]:
       order, use = [], {}
       for line in open(path, encoding="utf-8"):
           m = json.loads(line).get("message") or {}
           if m.get("role") == "assistant" and total(m.get("usage") or {}):
               if m["id"] not in use:
                   order.append(m["id"])
               use[m["id"]] = m["usage"]
       reads = sum(u.get("cache_read_input_tokens", 0) for u in use.values())
       everything += sum(map(total, use.values()))
       print("last request:", total(use[order[-1]]), "all requests:", sum(map(total, use.values())),
             "of which cache reads:", reads, "requests:", len(order))
   print("all requests, every transcript given:", everything)
   ```

   Write the first two figures, and what share of the second is cache reads. The first is the one
   the first table of `docs/agents/review-figures.md` holds, and the second the one its second
   table holds; that page says what each measures (#644). Read them again after
   the reviewer's last confirmation, the one of the plugin pass's fixes, and replace the figures in
   the body. Each table's row keeps the figure read when the row was written. If the transcript
   cannot be found, write "not measured". Given several transcripts, the script prints a line for
   each and their sum, which is how the session that runs the plugin pass reads that pass's totals
   (#634).

## What this does not do

It briefs no scorers. The reviewer scores its own findings, and the score decides nothing here:
every finding is reported. If a later version briefs one scorer per finding, each gets the quoted
lines and the one source to check them against — ten scorers told only to "verify one sentence"
used about 580 000 tokens exploring the repository on #594.
