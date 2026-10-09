"""Print the token figures a pull request's two rows in docs/agents/review-figures.md need (#661).

    python tools/review-usage.py <subagents directory> [<text> ...]

The directory is the session's own, `projects/<project>/<session id>/subagents` under the Claude
configuration directory. Each `agent-*.jsonl` there is one subagent's transcript, and the
`agent-*.meta.json` beside it has the description the session gave that subagent when it spawned
it. Run it from anywhere; it reads those files and the session's transcript and writes nothing.

HOW A SUBAGENT IS SORTED: by its description, in upper case or lower.

    Pre-PR       the pre-PR reviewer         "Pre-PR review of <branch>"
    step         the three steps             "plugin pass #<n>: eligibility step"
    reviewer     the plugin's reviewers      "plugin pass #<n>: reviewer 2, shallow bug scan"
    scorer       its scorers                 "plugin pass #<n>: scorer C, <the candidate>"

A description that starts with `Pre-PR` is the pre-PR reviewer's. Any other is sorted by whichever
of `step`, `reviewer` and `scorer` comes first in it as a whole word, so a scorer whose candidate
is about a step or a reviewer is still a scorer: "scorer B, step 7 names only md". A subagent
whose description holds none of them is printed as UNSORTED and is in no sum, and so is a
transcript with no `.meta.json` beside it. docs/agents/code-review.md tells the session that
spawns them to name them so.

WHAT THAT GETS WRONG: a step whose description names a reviewer or a scorer before the word
`step`, "reviewer eligibility step". The three steps' own names hold neither.

A SESSION THAT REVIEWED TWO PULL REQUESTS gives the texts that mark one of them: its number as
"#656", and the name of its pre-PR reviewer, whose description has no number. A subagent is then
counted only when its description or its name holds one of them, and the rest are printed as LEFT
OUT. A text is not found inside a longer number: "#65" does not mark "#656".

WHAT IT PRINTS, in the units the two tables hold:

  - reported: the count a subagent sent in the notice when it finished, read from the session's
    transcript, `<session id>.jsonl` beside the `<session id>` directory. The first table's three
    cells for the plugin pass are sums of these. A subagent with no notice there is said to have
    none, and its group's sum is then short.
  - last request: the tokens of a subagent's last request and its response. The first table's
    cell for the pre-PR reviewer, which is reached by name and sends no notice.
  - all requests, and the cache reads among them: the second table's cells.

A figure is the four token counts of a request's usage record summed: input, output, cache write
and cache read. A message streamed in several transcript lines is counted once, by its id, at the
usage of its last line.

WHAT IT CANNOT SEE: when a figure was read. The pre-PR reviewer goes on after its row is written,
so a later run prints more than the row holds; review-figures.md says which reading a row keeps.

`--self-test` builds a session of six subagents in a temporary directory and exits non-zero when
a figure printed for it is not the one worked out by hand below. It is run by
scripts/run-gates.ps1 and by .github/workflows/gates.yml.
"""
import glob
import json
import os
import re
import sys
import tempfile

GROUPS = {"step": "steps", "reviewer": "reviewers", "scorer": "scorers"}
NOTICE = re.compile(r"<tool-use-id>(\w+)</tool-use-id>.*?<subagent_tokens>(\d+)</subagent_tokens>",
                    re.S)


def total(usage):
    return sum(v for k, v in usage.items() if k.endswith("_tokens") and isinstance(v, int))


def read(path):
    """A transcript's last request, all its requests, the cache reads among them, their count."""
    order, use = [], {}
    for line in open(path, encoding="utf-8"):
        m = json.loads(line).get("message") or {}
        if m.get("role") == "assistant" and total(m.get("usage") or {}):
            if m["id"] not in use:
                order.append(m["id"])
            use[m["id"]] = m["usage"]
    if not order:
        return 0, 0, 0, 0
    return (total(use[order[-1]]), sum(map(total, use.values())),
            sum(u.get("cache_read_input_tokens", 0) for u in use.values()), len(order))


def notices(directory):
    """The count each finished subagent reported, by the id of the tool call that spawned it."""
    session = os.path.dirname(os.path.abspath(directory)) + ".jsonl"
    found = {}
    if os.path.exists(session):
        for line in open(session, encoding="utf-8"):
            entry = json.loads(line)
            # The three places a notice is kept: delivered as a turn, queued, or attached to one.
            for content in ((entry.get("message") or {}).get("content"), entry.get("content"),
                            (entry.get("attachment") or {}).get("prompt")):
                if isinstance(content, str) and content.lstrip().startswith("<task-notification>"):
                    for call, count in NOTICE.findall(content):
                        found[call] = int(count)        # a subagent that stopped twice: the last
    return found


def collect(directory, texts=()):
    """One row for each subagent: its group, its figures and its description."""
    reported, rows = notices(directory), []
    for path in sorted(glob.glob(os.path.join(directory, "agent-*.jsonl"))):
        beside = path[:-len(".jsonl")] + ".meta.json"
        meta = json.load(open(beside, encoding="utf-8")) if os.path.exists(beside) else {}
        said = meta.get("description", "")
        named = said + " " + meta.get("name", "")
        word = re.search(r"\b(step|reviewer|scorer)\b", said, re.I)
        group = "pre-PR" if said.lower().startswith("pre-pr") else \
            GROUPS[word.group(1).lower()] if word else "UNSORTED"
        if texts and not any(re.search(re.escape(t) + r"(?!\d)", named, re.I) for t in texts):
            group = "LEFT OUT"
        last, every, reads, requests = read(path)
        rows.append({"group": group, "reported": reported.get(meta.get("toolUseId")), "last": last,
                     "all": every, "reads": reads, "requests": requests, "said": said})
    return rows


def summarise(rows):
    """Each group's sums, and the plugin pass's three groups summed."""
    sums = {}
    for r in rows:
        s = sums.setdefault(r["group"], {"subagents": 0, "reported": 0, "unreported": 0, "last": 0,
                                         "all": 0, "reads": 0, "requests": 0})
        s["subagents"] += 1
        s["reported"] += r["reported"] or 0
        s["unreported"] += r["reported"] is None
        for k in ("last", "all", "reads", "requests"):
            s[k] += r[k]
    plugin = [sums[g] for g in ("steps", "reviewers", "scorers") if g in sums]
    sums["plugin pass"] = {k: sum(s[k] for s in plugin) for k in ("all", "reads")}
    return sums


def n(count):
    return f"{count:,}".replace(",", " ")       # grouped as the tables write a figure


def share(part, whole):
    return f"{100 * part / whole:.1f}%" if whole else "nothing to take a share of"


def report(rows):
    out = [f"{'group':10}{'reported':>11}{'last request':>14}{'all requests':>14}"
           f"{'cache reads':>13}{'requests':>10}  description"]
    for r in rows:
        told = "no notice" if r["reported"] is None else n(r["reported"])
        out.append(f"{r['group']:10}{told:>11}{n(r['last']):>14}{n(r['all']):>14}"
                   f"{n(r['reads']):>13}{r['requests']:>10}  {r['said']}")
    sums = summarise(rows)
    pre = sums.get("pre-PR")
    out += ["", "THE FIRST TABLE: what its subagents reported"]
    if pre:
        out.append(f"  pre-PR review's cost                {n(pre['last'])} tokens at its last "
                   f"request, {pre['subagents']} reviewer(s)")
    for g, cell in (("steps", "the three steps"), ("reviewers", "reviewers"), ("scorers", "scorers")):
        s = sums.get(g)
        if s:
            short = f"; {s['unreported']} sent no notice, so this is short" if s["unreported"] else ""
            out.append(f"  plugin pass's cost: {cell:16}{n(s['reported'])} tokens, "
                       f"{s['subagents']} subagent(s){short}")
    out += ["", "THE SECOND TABLE: over all requests"]
    if pre:
        out.append(f"  pre-PR review                    {n(pre['all'])} tokens in "
                   f"{pre['requests']} requests; of that, cache reads {share(pre['reads'], pre['all'])}")
    for g, cell in (("steps", "the three steps"), ("reviewers", "reviewers"), ("scorers", "scorers")):
        s = sums.get(g)
        if s:
            out.append(f"  plugin pass: {cell:20}{n(s['all'])} tokens, {s['subagents']} subagent(s)")
    plugin = sums["plugin pass"]
    out.append(f"  plugin pass: those three summed  {n(plugin['all'])} tokens; of that sum, "
               f"cache reads {share(plugin['reads'], plugin['all'])}")
    for g in ("UNSORTED", "LEFT OUT"):
        if g in sums:
            out.append(f"\n{g}, in no sum above: {sums[g]['subagents']} subagent(s), "
                       f"{n(sums[g]['all'])} tokens over all requests. They are the rows marked "
                       f"{g} at the top.")
    return "\n".join(out)


def self_test():
    """Six subagents with small figures, and the sums of them worked out by hand."""
    def usage(i, o, w, r):
        return {"input_tokens": i, "output_tokens": o, "cache_creation_input_tokens": w,
                "cache_read_input_tokens": r, "service_tier": "standard"}

    def said(mid, u):
        return {"message": {"role": "assistant", "id": mid, "usage": u}}

    agents = {       # name: (description, tool call, transcript lines)
        "a1": ("plugin pass #9: eligibility step", "toolu_1",
               [said("m1", usage(1, 2, 3, 4)), {"message": {"role": "user", "content": "x"}}]),
        # m2 is streamed twice and counts once, at its last line: 100, not 40 + 100.
        "a2": ("plugin pass #9: reviewer 1, pre-PR findings in the body", "toolu_2",
               [said("m2", usage(10, 10, 10, 10)), said("m2", usage(10, 20, 30, 40)),
                said("m3", usage(1, 1, 1, 7))]),
        "a3": ("plugin pass #9: scorer A, the reviewer skipped a step", "toolu_3", [said("m4", usage(5, 5, 0, 90))]),
        "a4": ("Pre-PR review of a-branch", None,
               [said("m5", usage(100, 0, 0, 0)), said("m6", usage(0, 50, 0, 150))]),
        "a5": ("PR #95 eligibility check", "toolu_5", [said("m7", usage(1000, 0, 0, 0))]),
        "a6": (None, None, [said("m8", usage(7, 0, 0, 0))]),        # no .meta.json beside it
    }
    with tempfile.TemporaryDirectory() as scratch:
        directory = os.path.join(scratch, "session", "subagents")
        os.makedirs(directory)
        for name, (description, call, lines) in agents.items():
            if description:
                with open(os.path.join(directory, f"agent-{name}.meta.json"), "w", encoding="utf-8") as f:
                    json.dump({"description": description, "toolUseId": call}, f)
            with open(os.path.join(directory, f"agent-{name}.jsonl"), "w", encoding="utf-8") as f:
                f.write("".join(json.dumps(line) + "\n" for line in lines))
        notice = ("<task-notification>\n<tool-use-id>{}</tool-use-id>\n<usage><subagent_tokens>{}"
                  "</subagent_tokens></usage>\n</task-notification>")
        with open(os.path.join(scratch, "session.jsonl"), "w", encoding="utf-8") as f:
            for call, count in (("toolu_2", 1), ("toolu_2", 105)):
                f.write(json.dumps({"message": {"role": "user",
                                                "content": notice.format(call, count)}}) + "\n")
            f.write(json.dumps({"type": "queue-operation",
                                "content": notice.format("toolu_1", 11)}) + "\n")
            f.write(json.dumps({"attachment": {"type": "queued_command",
                                               "prompt": notice.format("toolu_5", 999)}}) + "\n")
            # A notice quoted in a tool's output is not a notice.
            f.write(json.dumps({"message": {"role": "user", "content": [
                {"type": "tool_result", "content": notice.format("toolu_3", 77777)}]}}) + "\n")
        sums = summarise(collect(directory))
        only = summarise(collect(directory, ["#9"]))
    got = {
        "steps reported": sums["steps"]["reported"], "steps all": sums["steps"]["all"],
        "reviewers reported": sums["reviewers"]["reported"], "reviewers all": sums["reviewers"]["all"],
        "reviewers last": sums["reviewers"]["last"], "reviewers requests": sums["reviewers"]["requests"],
        "scorers reported": sums["scorers"]["reported"], "scorers unreported": sums["scorers"]["unreported"],
        "scorers all": sums["scorers"]["all"],
        "plugin all": sums["plugin pass"]["all"], "plugin reads": sums["plugin pass"]["reads"],
        "pre-PR last": sums["pre-PR"]["last"], "pre-PR all": sums["pre-PR"]["all"],
        "pre-PR reads": sums["pre-PR"]["reads"], "pre-PR requests": sums["pre-PR"]["requests"],
        "unsorted all": sums["UNSORTED"]["all"], "unsorted reported": sums["UNSORTED"]["reported"],
        "left out with #9 given": only["LEFT OUT"]["subagents"], "plugin all with #9 given": only["plugin pass"]["all"],
    }
    want = {
        "steps reported": 11, "steps all": 10,
        "reviewers reported": 105, "reviewers all": 110, "reviewers last": 10, "reviewers requests": 2,
        "scorers reported": 0, "scorers unreported": 1, "scorers all": 100,
        "plugin all": 220, "plugin reads": 141,        # 10 + 110 + 100, and 4 + 47 + 90
        "pre-PR last": 200, "pre-PR all": 300, "pre-PR reads": 150, "pre-PR requests": 2,
        "unsorted all": 1007, "unsorted reported": 999,     # the two with no word to sort by
        # The pre-PR reviewer, "PR #95 eligibility check" and the one with no description.
        "left out with #9 given": 3, "plugin all with #9 given": 220,
    }
    wrong = [f"{k}: {got[k]}, wanted {want[k]}" for k in want if got[k] != want[k]]
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"{len(want) - len(wrong)} of {len(want)} figures summed as wanted.")
    return 1 if wrong else 0


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if len(sys.argv) < 2 or not os.path.isdir(sys.argv[1]):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        print("Give the session's subagents directory.", file=sys.stderr)
        return 2
    rows = collect(sys.argv[1], sys.argv[2:])
    if not rows:
        print(f"No agent-*.meta.json in {sys.argv[1]}.", file=sys.stderr)
        return 2
    print(report(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
