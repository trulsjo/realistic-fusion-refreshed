---
name: plugin-pass
description: Run this repository's plugin pass on an open pull request. The session checks eligibility itself, five independent reviewers read the change, one verifier checks every candidate they raise against the tree, and the result is two comments on the pull request and its two rows in docs/agents/review-figures.md. Use when a pull request has been opened.
---

# /plugin-pass

Runs **the plugin pass** that `docs/agents/code-review.md` defines under *A review before the pull
request, and the plugin pass after it*. That file is the rule; this is the procedure. The pass is
the `code-review:code-review` plugin's, with the two departures that file names (#626): the session
does the plugin's three opening steps itself, and one verifier takes the place of its scorers.
`/pre-pr-review` is the other pass and comes first; its reviewer is still running and step 7 needs
it.

Every subagent here is read-only, and is told so. Each is spawned with the Agent tool as
`general-purpose`, never a fork, with a `description` that holds the pull request's number and the
word `tools/review-usage.py` sorts it by: `plugin pass #<n>: reviewer 2, shallow bug scan`,
`plugin pass #<n>: verifier, <how many> candidates`.

**None of them works in this session's checkout where a worktree can be had** (#651; the rule is
in that file). Spawn each with `isolation: "worktree"`. Where a hook refuses that, do not go
round it, and do not run `git worktree` yourself: ask the user to make one worktree for the
pass, outside the repository, and to remove it after step 4:

```
! git worktree add --detach "<scratch>/plugin-pass-<n>" <hash>
! git worktree remove "<scratch>/plugin-pass-<n>"
```

`<where>` in the two briefs below is one of three, by which of those happened:

- **Isolation:** "Your own worktree is your working directory. Your first command there is
  `git checkout --detach <hash>`, the pull request's head, and `git rev-parse HEAD` then
  prints that hash. `<what it lacks>`"
- **The user's worktree:** "Work only in `<that directory>`, which is at `<hash>`, the pull
  request's head: start every command there. `<what it lacks>`"
- **Nobody there to make one:** "Work in the repository's checkout, which is at `<hash>`, the
  pull request's head." The pull request's body then says the pass ran there.

`<what it lacks>` is "It has no submodule contents and no git-ignored file. Read one of those
from `<this session's checkout>` by its full path, and run no command there."

## Steps

1. **Do the opening steps yourself.** No subagent. Each line runs unchanged in Git Bash and in
   PowerShell.

   ```
   gh pr view <n> --json state,isDraft,comments --jq ".state, .isDraft, (.comments[].body | .[0:15])"
   git ls-files "CLAUDE.md" "*/CLAUDE.md"
   gh pr view <n> --json body --jq .body
   gh pr view <n> --json headRefOid --jq .headRefOid
   git rev-parse HEAD
   ```

   The first prints the state, whether it is a draft, and the first 15 characters of each
   comment. Stop when the pull request is closed, is a draft, or has a comment that starts
   `### Code review`, and say which. Nothing else stops the pass. The second line is the
   `CLAUDE.md` paths the reviewers are given, and the body is the summary of the change. The last
   two print the same hash, the `<hash>` of the briefs; if they differ, push or check out first.

   Done when the five have been read.

2. **Spawn the five reviewers in one message**, on Sonnet (`model: sonnet`). Each brief is the
   block below with one task from the list under it, and nothing about what the author thinks is
   right:

   > You are one of five independent reviewers of pull request `<n>` of this repository
   > (`gh pr diff <n>`). `<your task>` The tracked `CLAUDE.md` files
   > are `<paths>`. In this repository a false sentence or a wrong figure in tracked prose is a
   > bug: `docs/agents/code-review.md`, *Review the prose, not only the code*, says what to
   > check.
   >
   > `<where>` You are read-only: edit and commit nothing. Run no `git checkout` but one named
   > above, and no `git switch`, `stash`, `reset` or `worktree`. Run no gate, leave nothing
   > running in the background, and send no message to another agent.
   >
   > Return a list of issues. For each: the file, the quoted words or code, what is wrong, the one
   > source that shows it, and why it was flagged. Leave out a pre-existing issue, a nitpick, and
   > what a linter or a gate would catch. A sentence that this change made false and did not touch
   > is not pre-existing: raise it. List separately what you noticed and decided not to raise.
   > Say so plainly if you found nothing. Keep the reply under 400 words.

   The five tasks, as the plugin words them, one misspelling corrected:

   1. Audit the changes to make sure they comply with the CLAUDE.md. Note that CLAUDE.md is
      guidance for Claude as it writes code, so not all instructions will be applicable during
      code review.
   2. Read the file changes in the pull request, then do a shallow scan for obvious bugs. Avoid
      reading extra context beyond the changes, focusing just on the changes themselves. Focus on
      large bugs, and avoid small issues and nitpicks. Ignore likely false positives.
   3. Read the git blame and history of the code modified, to identify any bugs in light of that
      historical context
   4. Read previous pull requests that touched these files, and check for any comments on those
      pull requests that may also apply to the current pull request.
   5. Read code comments in the modified files, and make sure the changes in the pull request
      comply with any guidance in the comments.

   Each report arrives as a message once this session's turn has ended, as the pre-PR reviewer's
   does. Done when all five have reported.

3. **Merge the candidates.** A candidate is an issue a reviewer raised; what a reviewer listed as
   noticed and not raised is a mention and goes to no verifier. Two reviewers raising the same
   fault is one candidate. Letter them A, B, C.

   **No candidate, no verifier**: do the last two lines of step 4, then go to step 5.

4. **Spawn one verifier for all of them**, on Sonnet. Its brief:

   > You are the verifier of the candidates five reviewers raised on pull request `<n>` of this
   > repository. For each candidate below you are given the quoted
   > words or code and the one source to check them against. Check that source, and nothing
   > else unless it sends you on.
   >
   > `<for each: its letter, the file, the quoted words, what the reviewer says is wrong, the
   > source>`
   >
   > `<where>` You are read-only: edit and commit nothing. Run no `git checkout` but one named
   > above, and no `git switch`, `stash`, `reset` or `worktree`. Run no gate, leave nothing
   > running in the background, and ask no other agent: send no message.
   >
   > Return one line for each candidate: its letter, a verdict, and the evidence in a sentence.
   > The verdict is **real** when the source shows the fault, **not real** when the source shows
   > there is none or the fault is not this pull request's, and **not verified** when you could
   > not check it from the tree. Give no score.

   Done when every candidate has a verdict. Then have the worktree removed if one was made, and read
   `git reflog -20`: the pull request's body says whether it shows a checkout since step 2.

5. **Check eligibility again** with step 1's first line, and **post two comments** with
   `gh pr comment <n> --body-file`. The first:

   ```
   ### Code review

   Found <k> issues:

   1. <the fault, in a line> (<real | not verified>: <the verifier's evidence>)

      <link to the file and lines, with the full commit hash>
   ```

   It lists every candidate found real or not verified, each said to be which. With none it says
   `No issues found. Checked for bugs and CLAUDE.md compliance.` The second comment, under
   `### What the plugin pass raised and did not post`, lists each candidate found not real with
   the verifier's reason, and each mention. It is posted when either list has an entry, and it
   says which reviewers raised nothing. A verdict is posted as the verifier gave it: where you
   read the source differently, say so beside it.

6. **Add the pull request's row to each table of `docs/agents/review-figures.md`, in one
   commit.** `python tools/review-usage.py "<subagents directory>" "#<n>" "<reviewer's name>"`
   prints the figures; step 6 of `/pre-pr-review` says where the directory is. The cells for the
   three steps say the session did them, and the scorers' cells hold the verifier's figures and
   say so. `docs/agents/code-review.md` has what a row holds and how it is graded.

7. **Fix, and have the pre-PR reviewer confirm.** `docs/agents/code-review.md` says, in the
   fourth rule, what becomes of a candidate found real or not verified, who confirms the fixes
   and from which diff, and that the class of a finding the pre-PR review missed is named in the
   pull request. A fix held under #643 and #653 is in that diff.

Then run step 7 of `/pre-pr-review`, the reading after the last fix commit.
