"""Rewrap, at 100 characters, the paragraph each given line sits in (#662).

    python tools/rewrap.py <file> <line> [<line> ...]

The lines are the ones scripts/ship-check.ps1 section 12 prints, counted from 1. The width is the
one docs/agents/code-review.md states and section 12 holds three files to; that section fails
when WIDTH below is not its own.

A PARAGRAPH runs from a blank line, a list marker or a change of blockquote depth to the next. Its
first line keeps its indentation, its blockquote marks and its list marker; every later line gets
what the paragraph's second line had, or the same depth in spaces when it had one line. No word is
changed, added or dropped: the words are compared before the file is written.

A FIGURE GROUPED IN THOUSANDS STAYS ON ONE LINE. A space with a digit before it and exactly three
digits after it is not a place to break, so "580 000" and "1 565 019" are each one word here.
That is wider than what section 12 fails, which wants the digits before the space to be a group
of their own: "in 2026 100 lines" is kept together here and would pass there either way.

WHAT IS LEFT AS IT IS, and said so: a table row, a line inside a code fence or a fence line, a
heading, and front matter. Asked for one of those, it prints that it left the line and goes on.

WHAT IT REFUSES: a result in which a later line would open with something markdown reads as
structure, a list marker, `>`, `#`, a pipe or a fence. The file is then not written. Break that
paragraph by hand.

WHAT IT CANNOT SEE:

  - a hard line break, two spaces or a backslash at a line's end. It is joined like any other.
  - an indented code block, which it takes for a paragraph. The three files use fences.
  - how wide a line renders. A line's length is its count of characters.

`--self-test` rewraps a document made up below and exits non-zero when a line of it is not the
line wanted. It is run by scripts/run-gates.ps1 and by .github/workflows/gates.yml.
"""
import re
import sys
import textwrap

WIDTH = 100
GLUE = " "         # stands in for the space inside a grouped figure while the words are laid out
LEAD = re.compile(r"^([ \t]*(?:>[ \t]?)*)((?:\d+[.)]|[-*+])[ \t]+)?")
STRUCTURE = re.compile(r"(?:\d+[.)]\s|[-*+]\s|>|#{1,6}\s|\||```|~~~)")


def kinds(lines):
    """What each line is: 'blank', 'fixed' for one that is never rewrapped, or 'prose'."""
    out, fenced, front = [], False, False
    for i, line in enumerate(lines):
        bare = line[LEAD.match(line).end(1):]
        if i == 0 and line.strip() == "---":
            front = True
            out.append("fixed")
        elif front:
            front = line.strip() != "---"
            out.append("fixed")
        elif bare.startswith(("```", "~~~")):
            fenced = not fenced
            out.append("fixed")
        elif fenced or bare.startswith("|") or re.match(r"#{1,6}\s", bare):
            out.append("fixed")
        else:
            out.append("prose" if bare.strip() else "blank")
    return out


def rewrap(lines, targets):
    """The lines with each target's paragraph rewrapped, and a sentence for each target."""
    lines, said = list(lines), []
    for n in sorted(set(targets), reverse=True):        # from the foot, so line numbers hold
        kind = kinds(lines)
        i = n - 1
        if not 0 <= i < len(lines) or kind[i] != "prose":
            what = "is not in the file" if not 0 <= i < len(lines) else \
                "is blank" if kind[i] == "blank" else \
                "is a table row, a heading, front matter or part of a code fence"
            said.append(f"line {n} {what}: left as it is")
            continue
        depth = lambda k: LEAD.match(lines[k]).group(1).count(">")
        starts = lambda k: bool(LEAD.match(lines[k]).group(2))
        a = i
        while not starts(a) and a > 0 and kind[a - 1] == "prose" and depth(a - 1) == depth(i):
            a -= 1
        b = i + 1
        while b < len(lines) and kind[b] == "prose" and not starts(b) and depth(b) == depth(i):
            b += 1
        quote, marker = LEAD.match(lines[a]).groups()
        first = quote + (marker or "")
        later = LEAD.match(lines[a + 1]).group(1) if b - a > 1 else \
            quote + " " * len(marker or "")
        words = lines[a][len(first):].split()
        for line in lines[a + 1:b]:
            words += line[LEAD.match(line).end(1):].split()
        body = re.sub(r"(?<=\d) (?=\d{3}(?!\d))", GLUE, " ".join(words))
        out = [line.replace(GLUE, " ") for line in textwrap.wrap(
            body, WIDTH, initial_indent=first, subsequent_indent=later,
            break_long_words=False, break_on_hyphens=False)]
        bad = [line for line in out[1:] if STRUCTURE.match(line[len(later):])]
        if bad:
            raise ValueError(f"line {n}: rewrapped, a line of its paragraph would open with "
                             f"markdown structure: {bad[0].strip()!r}. Break it by hand.")
        after = out[0][len(first):].split() + [w for line in out[1:] for w in line[len(later):].split()]
        if after != words:
            raise ValueError(f"line {n}: the rewrapped paragraph does not hold the same words.")
        said.append(f"lines {a + 1}-{b} -> {len(out)} line(s), the longest {max(map(len, out))}")
        lines[a:b] = out
    return lines, said[::-1]


def self_test():
    long = " ".join(["word"] * 21)                         # 104 characters
    doc = [
        "---",
        f"description: {long}",
        "---",
        "",
        f"## {long}",
        "",
        f"| {long} | a cell |",
        "",
        "```",
        long,
        "```",
        "",
        " ".join(["word"] * 18) + " used 580 000 tokens and then 1 565 019 more of them",
        "and a short line.",
        "",
        f"   - {long}",
        "     and its second line.",
        "",
        f"   > {long}",
        "   > and its second line.",
        "",
        f"1. {long}",
    ]
    out, said = rewrap(doc, [2, 5, 7, 10, 13, 16, 19, 22])
    want = doc[:12] + [
        " ".join(["word"] * 18) + " used",
        "580 000 tokens and then 1 565 019 more of them and a short line.",
        "",
        "   - " + " ".join(["word"] * 19),
        "     word word and its second line.",
        "",
        "   > " + " ".join(["word"] * 19),
        "   > word word and its second line.",
        "",
        "1. " + " ".join(["word"] * 19),
        "   word word",
    ]
    wrong = [f"line {k + 1}: {g!r}, wanted {w!r}"
             for k, (g, w) in enumerate(zip(out + [None] * len(want), want + [None] * len(out)))
             if g != w and (g, w) != (None, None)]
    if sum("left as it is" in s for s in said) != 4:
        wrong.append(f"four lines that are never rewrapped were answered with: {said!r}")
    try:
        rewrap(["word " * 19 + "then - a dash"], [1])
        wrong.append("a result with a line opening on a list marker was not refused")
    except ValueError:
        pass
    for w in wrong:
        print(f"WRONG: {w}", file=sys.stderr)
    print(f"rewrap: {'a line is wrong' if wrong else 'four paragraphs rewrapped as wanted, four lines left, one result refused'}.")
    return 1 if wrong else 0


def main():
    if sys.argv[1:] == ["--self-test"]:
        return self_test()
    if len(sys.argv) < 3 or not all(a.isdigit() for a in sys.argv[2:]):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    path = sys.argv[1]
    text = open(path, encoding="utf-8", newline="").read()
    eol = "\r\n" if "\r\n" in text else "\n"
    try:
        lines, said = rewrap(text.split(eol), [int(a) for a in sys.argv[2:]])
    except ValueError as e:
        print(f"{path}: {e} Nothing was written.", file=sys.stderr)
        return 1
    open(path, "w", encoding="utf-8", newline="").write(eol.join(lines))
    for s in said:
        print(f"{path}: {s}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
