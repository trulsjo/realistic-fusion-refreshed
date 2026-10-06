---
name: pre-pr-review
description: Run this repository's pre-PR review on the current branch. One fresh read-only reviewer is handed the diff against main, docs/agents/code-review.md, and the gate result or the probes' raw output; the same reviewer then confirms the fixes; the result is the findings table for the pull request's body. Use when a branch is ready for its pull request, or when an implement skill says to close out with /code-review.
---

# /pre-pr-review

Runs the **pre-PR review** that `docs/agents/code-review.md` defines under *One review before the
pull request*. That file is the rule; this is the procedure. It needs no pull request and it is
not `code-review:code-review`, which is the plugin pass and runs only when asked for.

## Steps

1. **Commit the work**, so the review and the fixes are two diffs. Write both to the session's
   scratchpad, never into the repository:

   ```
   git rev-parse HEAD                      # the reviewed commit; step 4 needs it
   git diff main...HEAD > <scratch>/branch.diff
   ```

2. **Save the evidence to a file** in the same directory. Which evidence depends on the branch:

   - a branch that records measurements: the raw output of each probe a figure came from;
   - any other branch: the output of the gates that were run — `scripts/run-gates.ps1` when the
     branch combines more than one ticket, otherwise the gates the change touches.

   Done when every figure or pass the branch claims has its output in a file.

3. **Spawn one fresh reviewer** with the Agent tool: `general-purpose`, never a fork, since a fork
   has already read the author's reasoning. Give it a `name` so step 4 can reach it. Its brief is the
   block below with the paths filled in and nothing about what the author thinks is right:

   > You are the pre-PR reviewer of a branch of this repository. Read
   > `docs/agents/code-review.md` in full first; its second rule, *Review the prose, not only the
   > code*, binds you. Then review `<scratch>/branch.diff` (the diff against `main`) against
   > `<evidence files>`, which hold `<the probes' raw output | the gate results>`.
   >
   > The branch claims to resolve `<#n, #n>`. Read each with the **Read an issue** command in
   > `docs/agents/issue-tracker.md` and hold the diff against its acceptance criteria.
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
   > Say so plainly if you found nothing, and say what you did not check.

   **A long report arrives cut off**, and a subagent cannot write its report to a file. If the
   last finding stops mid-sentence, ask the reviewer for the rest with SendMessage before fixing
   anything. On this skill's first run the report stopped inside the sixth of nine findings.

4. **Fix, commit, and continue the same reviewer** with SendMessage to the name from step 3. Do
   not spawn a second one. Hand it the diff of the fixes and nothing else:

   ```
   git diff <reviewed commit>..HEAD > <scratch>/fixes.diff
   ```

   > `<scratch>/fixes.diff` is every change made since your review. For each of your findings,
   > say whether it is fixed, from the diff alone. Then review every other added line in that
   > diff as new work: a fix that adds a sentence adds a claim. Number any new finding on from
   > your last and score it the same way.

   **Do not send a list of what was done for each finding.** On #594 the reviewer was sent one,
   confirmed against the list, and passed a false sentence a fix had added. A finding left unfixed
   on purpose is named to the reviewer as left, with the reason, and nothing more.

   Done when the reviewer has answered for every finding. New findings get the same step again.

5. **Write the findings table** and put it in the pull request's body, every finding in it:

   | # | Finding | Where | Score | Fixed |
   |---|---|---|---|---|
   | 1 | one line, in the reviewer's terms | file, and the symbol or quoted words | 75 | yes, confirmed |
   | 2 | … | … | 50 | no: the reason it was left |

   **Fixed** is `yes, confirmed` only when the reviewer said so in step 4; otherwise
   `yes, not confirmed` or `no: <reason>`. A review that found nothing says that in the body in
   place of the table, with what the reviewer said it did not check.

## What this does not do

It briefs no scorers. The reviewer scores its own findings, and the score decides nothing here:
every finding is reported. If a later version briefs one scorer per finding, each gets the quoted
lines and the one source to check them against — ten scorers told only to "verify one sentence"
used about 580 000 tokens exploring the repository on #594.
