> **Re-running `/setup-matt-pocock-skills` rewrites this stub page in place** and drops its links
> to the shared pages below: restore them from git.

# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

**The conventions shared with the siblings are on
[`tracker-conventions.md`](../../vendor/grado-factorio-tools/docs/tracker-conventions.md)**, in
the tools submodule at its pin
([on GitHub](https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/tracker-conventions.md),
whose `main` may be ahead of the pin): reading an issue with `--json`, multi-line bodies through
`--body-file`, searching before filing, blocked-by, closing, and the bar for a follow-up ticket.
Read it before filing, blocking or closing an issue. What a pull request's body holds is on
[`pr-body-convention.md`](../../vendor/grado-factorio-tools/docs/pr-body-convention.md)
([on GitHub](https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/pr-body-convention.md)),
and what a ticket's evidence holds on
[`claim-grades.md`](../../vendor/grado-factorio-tools/docs/claim-grades.md)'s *Tickets and ruling
comments* ([on GitHub](https://github.com/trulsjo/grado-factorio-tools/blob/main/docs/claim-grades.md)),
both in the same submodule. This page holds the setup template's core and this repository's own
parts. What this repository's own rules were measured on is on
[`issue-tracker-evidence.md`](issue-tracker-evidence.md), which filing an issue does not need.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <path>`, the file written with
  the Write tool, after searching the open issues as the shared page says. **The other tracker to
  search is `trulsjo/grado-factorio-tools`**, for a ticket about a shared script or page, with the
  same command and `-R trulsjo/grado-factorio-tools`.
- **A command that edits a body file and the `gh` command that sends it are joined with `&&`**,
  so a failed edit sends nothing (#713, #718), whichever sends it: `gh issue create`,
  `gh issue comment`, `gh issue edit`, `gh pr create` or `gh pr edit`, the one #713 sent.
- **A Bash command that would hang is refused before it runs** by the shared
  `refuse-hanging-bash.ps1`, which the tracked `.claude/settings.json` wires (#861): a `cat` or a
  `python -` reading the Bash tool's stdin, a heredoc over 60 lines, and on Windows two
  backslashes in a row. Each refusal is a line in the git-ignored `.claude/refused-bash.log`.
- **Blocking between issues**: when filing tickets, set each blocking edge as the shared page's
  *Blocked by* says, as the tickets are created. **Run the POST with the Bash tool**: a
  `Bash(...)` rule in the tracked `.claude/settings.json` allows it there, for a ticket of this
  repository, `grado-factorio-modpack`, `grado-factorio-tools` or `true-nukes-refreshed` (#859).
- **Pull request body**: the shared page's four rules, with no switch turned on here. The
  `mattpocock-skills:pr` skill fills the template's three headings where that plugin is installed,
  and they are written by hand where it is not. This repository adds to what it produces: above
  the template, one `Closes #<n>` line of its own for each ticket the branch resolves, where it
  resolves any; below it, the `## Pre-PR review` section the session writes in steps 5 to 7 of
  `/pre-pr-review` (`.claude/skills/pre-pr-review/SKILL.md`). A commit of the branch is named as
  the shared page's *Naming a branch commit* says. **Every `gh pr create --body-file` and `gh pr edit --body-file` is
  preceded by
  `pwsh -NoProfile -File vendor/grado-factorio-tools/scripts/pr-body-check.ps1 <file>`, joined
  with `&&`**, as the shared page's *Before a create* says. A body that quotes a
  `scripts/ship-check.ps1` result has two more checks joined between them, as step 6 of
  `/pre-pr-review` says (#884). `.github/workflows/gates.yml` runs the body check
  again on the body of each pull request, and again when the body is edited.
  `docs/agents/code-review.md` and `docs/agents/plugin-pass.md` say what else the pull request
  records once the plugin pass has run.
- **Read an issue**: `gh issue view <number> --json title,body,labels,comments --jq '{title, body, labels: [.labels[].name], comments: [.comments[].body]}'`,
  not `--comments`, for the shared page's reason.
- **Read a pull request**: `gh pr view <number> --json title,body,comments --jq '{title, body, comments: [.comments[].body]}'`,
  and `gh pr diff <number>` for the diff.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
  with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **A comment that records Truls's decisions on a ticket records what Truls decided**, and leaves
  the wording the session writes for it to the pull request (#716).
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`, after the shared page's *Before closing*.

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature
requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr`
equivalents:

- **Read a PR**: the **Read a pull request** command under Conventions.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`
  then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop
  `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`,
  `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with
`gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue, after the shared page's *Search the open issues before filing*. **A
ticket's evidence** follows `claim-grades.md`'s *Tickets and ruling comments*, and this
repository's own rules beside it are in `docs/agents/code-review.md`, under *Review the prose, not
only the code*: the paragraph on a ticket's evidence and a retrospective's (#637), and the one on
the four shared rules (#657).

## When a skill says "fetch the relevant ticket"

Run the **Read an issue** command under Conventions.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
  `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues
  endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put
  `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>`
  (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving
  dev.
- **Blocking**: GitHub's **native issue dependencies** — the canonical, UI-visible representation,
  added as the shared page's *Blocked by* says. GitHub reports
  `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies
  aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A
  ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the
  map's sub-issues / task list), drop any with an open blocker
  (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an
  assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` — the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a
  context pointer (gist + link) to the map's Decisions-so-far.
