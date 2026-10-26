"""Record the commits a pre-PR reviewer is handed, and list the ones no reviewer was (#781, #787).

    python tools/review-coverage.py record <git log arguments>
    python tools/review-coverage.py check

The rule is docs/agents/code-review.md's, under *A review before the pull request, and the plugin
pass after it*; /pre-pr-review (.claude/skills/pre-pr-review/SKILL.md) says when each is run.

RECORD hands its arguments to `git log` and keeps the subject of each commit it prints, under the
current branch's name, in `pre-pr-reviewed.txt` in the git directory, one `<branch> <subject>` line
each. It is given the range of the diff the reviewer is handed, `origin/main..HEAD` only where that
is the whole branch, and `-1 <hash>` for a commit a reword gave a new subject. The file outlives
the session and is never pushed, and `--git-path` gives each worktree its own.

CHECK lists each commit of `origin/main..HEAD` whose subject is not recorded under the current
branch, as its short hash and its subject, and exits 1 when it lists one, 0 when it lists none.

A SUBJECT MATCHES ONLY WHOLE, AND ONLY UNDER ITS OWN BRANCH. A recorded subject that holds a
commit's subject as a part of it covers nothing, and neither does one recorded under another
branch. Subjects are read from git as UTF-8 and compared as text, so a gitmoji subject matches
whichever shell runs this; `grep` in Git Bash matched none without `LC_ALL=C` (#785).

WHAT IT CANNOT SEE: two commits of one branch with the same subject. One recorded covers both.

`--self-test` builds a repository in a temporary directory and exits non-zero when check does not
name the one unreviewed commit among two reviewed groups, when a reworded commit does not read as
covered once its reword is recorded, or when a subject recorded under another branch covers a
commit here. It is run by scripts/run-gates.ps1 and by .github/workflows/gates.yml.
"""
import os
import subprocess
import sys
import tempfile


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True,
                          encoding="utf-8").stdout


def store(cwd):
    return os.path.join(cwd, git(cwd, "rev-parse", "--git-path", "pre-pr-reviewed.txt").strip())


def branch(cwd):
    return git(cwd, "branch", "--show-current").strip()


def record(cwd, log_args):
    lines = [f"{branch(cwd)} {s}" for s in git(cwd, "log", "--format=%s", *log_args).splitlines()]
    with open(store(cwd), "a", encoding="utf-8", newline="\n") as f:
        f.writelines(line + "\n" for line in lines)
    return lines


def unreviewed(cwd):
    try:
        with open(store(cwd), encoding="utf-8") as f:
            seen = set(f.read().splitlines())
    except FileNotFoundError:
        seen = set()
    name = branch(cwd)
    commits = git(cwd, "log", "--format=%h %s", "origin/main..HEAD").splitlines()
    return [c for c in commits if f"{name} {c.split(' ', 1)[1]}" not in seen]


def self_test():
    wrong = []
    with tempfile.TemporaryDirectory() as d:
        hooks = os.path.join(d, "no-hooks")
        os.mkdir(hooks)
        repo = os.path.join(d, "repo")
        os.mkdir(repo)
        git(repo, "init", "-q")
        for key, value in (("user.name", "t"), ("user.email", "t@t"), ("core.hooksPath", hooks)):
            git(repo, "config", key, value)

        def commit(subject):
            git(repo, "commit", "-q", "--allow-empty", "-m", subject)

        commit("🎉 chore(repo): start")
        git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        git(repo, "checkout", "-q", "-b", "feature")
        commit("📝 docs(repo): one")
        commit("📝 docs(repo): two")
        record(repo, ["origin/main..HEAD"])
        git(repo, "tag", "reviewed")
        commit("🐛 fix(repo): three")
        record(repo, ["reviewed..HEAD"])
        commit("📝 docs(repo): four")
        # A subject that holds the unreviewed one as a part covers nothing.
        with open(store(repo), "a", encoding="utf-8") as f:
            f.write("feature 📝 docs(repo): four, and more\n")
        got = unreviewed(repo)
        if [c.split(" ", 1)[1] for c in got] != ["📝 docs(repo): four"]:
            wrong.append(f"two reviewed groups and one unreviewed commit listed {got!r}")
        run = subprocess.run([sys.executable, os.path.abspath(__file__), "check"], cwd=repo,
                             capture_output=True, encoding="utf-8")
        if run.returncode != 1 or "📝 docs(repo): four" not in run.stdout:
            wrong.append(f"check exited {run.returncode} and printed {run.stdout!r}")

        record(repo, ["-1", "HEAD"])
        git(repo, "commit", "-q", "--amend", "--allow-empty", "-m", "📝 docs(repo): four, reworded")
        if len(unreviewed(repo)) != 1:
            wrong.append("a reworded commit read as covered before its reword was recorded")
        record(repo, ["-1", "HEAD"])
        if unreviewed(repo):
            wrong.append(f"a recorded reword still listed {unreviewed(repo)!r}")

        git(repo, "checkout", "-q", "-b", "other")
        commit("✨ feat(repo): five")
        record(repo, ["-1", "HEAD"])
        git(repo, "checkout", "-q", "feature")
        commit("✨ feat(repo): five")
        if [c.split(" ", 1)[1] for c in unreviewed(repo)] != ["✨ feat(repo): five"]:
            wrong.append("a subject recorded under another branch covered a commit on this one")
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"review-coverage: {'a case is wrong' if wrong else 'the unreviewed commit listed, a recorded reword covered, another branch covering nothing'}.")
    return 1 if wrong else 0


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if args == ["--self-test"]:
        return self_test()
    cwd = os.getcwd()
    if args[:1] == ["record"] and len(args) > 1:
        for line in record(cwd, args[1:]):
            print(f"recorded: {line}")
        return 0
    if args == ["check"]:
        missing = unreviewed(cwd)
        for c in missing:
            print(f"no review was handed: {c}")
        print(f"{len(missing)} commit(s) of origin/main..HEAD no review was handed.")
        return 1 if missing else 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
