---
name: plugin-pass
description: Run this repository's plugin pass on an open pull request. The session checks eligibility itself, five independent reviewers read the change, one verifier checks every candidate they raise against the tree, and the result is two comments on the pull request and its two rows in docs/agents/review-figures.md. Use when a pull request has been opened.
---

# /plugin-pass

Runs **the plugin pass** that `docs/agents/code-review.md` defines under *A review before the pull
request, and the plugin pass after it*, and `docs/agents/plugin-pass.md`, which that section points
at, holds the pass's own half. Those are the rule; this is the procedure. The pass is the
`code-review:code-review` plugin's, with the two departures `code-review.md` names (#626): the
session does the plugin's three opening steps itself, and one verifier takes the place of its
scorers. `/pre-pr-review` is the other pass and comes first; its reviewer is still running and step
7 needs it.

Every subagent here is read-only, and is told so. Each is spawned with the Agent tool as
`general-purpose`, never a fork, with a `description` that holds the pull request's number and the
word `tools/review-usage.py` sorts it by: `plugin pass #<n>: reviewer 2, shallow bug scan`,
`plugin pass #<n>: verifier, <how many> candidates`.

**None of them works in this session's checkout where a worktree can be had** (#651, #699; the rule
is in `docs/agents/plugin-pass.md`). Where `HERDR_ENV` is set, make the worktree at the end of step
1, from the repository's root, and spawn without isolation:

```
herdr worktree create --cwd "<repo root>" --branch plugin-pass-<n> --base <hash> --path "<repo root>/../rf-plugin-pass-<n>" --label plugin-pass-<n> --no-focus
git -C "<repo root>/../rf-plugin-pass-<n>" rev-parse HEAD
```

From herdr's JSON reply read `.result.worktree.path`, the directory, and
`.result.workspace.workspace_id`, the workspace to remove. The `rev-parse` must print `<hash>`
before step 2. After step 4 remove both:

```
herdr worktree remove --workspace <workspace id>
git branch -D plugin-pass-<n>
```

Elsewhere spawn each with `isolation: "worktree"`. Where herdr's command fails or a hook refuses
the isolated spawn, do not go round it, and do not run `git worktree` yourself: ask the user to
make one worktree for the pass, outside the repository, and to remove it after step 4:

```
! git worktree add --detach "<scratch>/plugin-pass-<n>" <hash>
! git worktree remove "<scratch>/plugin-pass-<n>"
```

`<where>` in the two briefs below is one of three, by which of those happened:

- **Isolation:** "Your own worktree is your working directory. Your first command there is
  `git checkout --detach <hash>`, the pull request's head, and `git rev-parse HEAD` then
  prints that hash. `<what it lacks>`"
- **herdr's or the user's worktree:** "Work only in `<that directory>`, which is at `<hash>`,
  the pull request's head: start every command there. `<what it lacks>`"
- **Nobody there to make one:** "Work in the repository's checkout, which is at `<hash>`, the
  pull request's head." The pull request's body then says the pass ran there.

`<what it lacks>` is "It has no submodule contents and no git-ignored file. Read one of those
from `<this session's checkout>` by its full path, and run no command there."

## Steps

1. **Do the opening steps yourself.** No subagent. Each line runs unchanged in Git Bash and in
   PowerShell.

   ```
   git fetch origin main
   gh pr view <n> --json state,isDraft,comments --jq ".state, .isDraft, (.comments[].body | .[0:15])"
   git ls-files "CLAUDE.md" "*/CLAUDE.md"
   gh pr view <n> --json body --jq .body
   gh pr view <n> --json headRefOid --jq .headRefOid
   git rev-parse HEAD
   ```

   The first brings `origin/main` up to date, and leaves the local `main` alone (#755, #758). Where
   it fails, stop and tell the user git's message: it fails with no network or no access to the
   remote. The second prints the state, whether it is a draft, and the first 15
   characters of each comment. Stop when the pull request is closed, is a draft, or has a comment that starts
   `### Code review`, and say which. Nothing else about the pull request stops the pass. The third line is the
   `CLAUDE.md` paths the reviewers are given, and the body is the summary of the change. The last
   two print the same hash, the `<hash>` of the briefs; if they differ, push or check out first.

   Done when the six have been read.

2. **Spawn the five reviewers in one message**, on Sonnet (`model: sonnet`). Each brief is the
   block below with one task from the list under it, and nothing about what the author thinks is
   right:

   > You are one of five independent reviewers of pull request `<n>` of this repository
   > (`gh pr diff <n>`). Read the change with `gh pr diff <n>`, never with a local `git diff`
   > against `main`. `<your task>` The tracked `CLAUDE.md` files
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
   > is not pre-existing: raise it. Line width is held only in the files `docs/agents/code-review.md`
   > names as wrapped; in any other file, say nothing of it. List separately what you noticed and
   > decided not to raise. Say so plainly if you found nothing. Keep the reply under 400 words.

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
   does. **A reviewer that stops before it has reported is resumed** (#761): send it a message
   with SendMessage, to its agent id, asking it to finish within its brief and send its report.
   One that reported and then stopped is left as it is. Done when all five have reported.

3. **Merge the candidates.** A candidate is an issue a reviewer raised; what a reviewer listed as
   noticed and not raised is a mention and goes to no verifier. Two reviewers raising the same
   fault is one candidate. Letter them A, B, C.

   **No candidate, no verifier**: do the last two lines of step 4, then go to step 5.

4. **Spawn one verifier for all of them**, on Sonnet. Its brief:

   > You are the verifier of the candidates five reviewers raised on pull request `<n>` of this
   > repository. For each candidate below you are given the quoted
   > words or code and the one source to check them against. Check that source, and nothing
   > else unless it sends you on. Where you need the change, read it with `gh pr diff <n>`,
   > never with a local `git diff` against `main`.
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

   A verifier that stops before it has reported is resumed as a reviewer is in step 2. Done when
   every candidate has a verdict. Then remove the worktree, or have it removed, if one
   was made, and read
   `git reflog -20`: the pull request's body says whether it shows a checkout since step 2.

5. **Check eligibility again** with step 1's second line, and **post two comments** with
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
   say so. `docs/agents/plugin-pass.md` has what a row holds and how it is graded.

7. **Fix, and have the pre-PR reviewer confirm.** `docs/agents/code-review.md` says, in the
   fourth rule, what becomes of a candidate found real or not verified, who confirms the fixes
   and from which diff, and that the class of a finding the pre-PR review missed is named in the
   pull request. A fix held under #643 and #653 is in that diff.

   **Each edit of the body is checked before it is sent** (#730), as step 6 of `/pre-pr-review`
   runs `pr-body-check.ps1`: the edit that adds step 4's line on the reflog, and each edit for
   this step's fixes. The body names a commit of the branch by its subject in quotes, not its
   hash, and its review sections stay below `## Summary`, `## Evidence` and `## Merge Danger`.

Then run step 7 of `/pre-pr-review`, the reading after the last fix commit.
