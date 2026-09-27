#!/usr/bin/env python3
"""Set pipe-table column widths from their content, in the assembled thesis.

    python tools/format_tables.py build/thesis.md

Pandoc wraps a wide pipe table to the page and sizes its columns by the number
of dashes in the header separator. The sources use `|---|---|`, so every column
gets the same width, and a table whose last column holds a sentence squeezes it
into a quarter of the page. This rewrites each separator so that a column's
share of the width follows the length of its longest cell, with a floor so
that a short column (a number, a class name) keeps room for its header word.

Runs on the assembled build/thesis.md only; the chapter sources are untouched.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

SEPARATOR = re.compile(r"^\|(\s*:?-+:?\s*\|)+\s*$")
TOTAL_DASHES = 80
MIN_SHARE = 0.07
# Roughly how many characters of 12 pt text fit across the text block; the
# +3 in the floor leaves room for cell padding.
CHARS_PER_LINE = 60


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def visible_length(cell: str) -> int:
    cell = re.sub(r"\*\*|`|\*", "", cell)
    return len(cell)


def rewrite(lines: list[str]) -> list[str]:
    out = list(lines)
    i = 0
    while i < len(lines):
        if i > 0 and SEPARATOR.match(lines[i]) and lines[i - 1].lstrip().startswith("|"):
            header = i - 1
            j = i + 1
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                j += 1
            rows = [cells(lines[k]) for k in [header] + list(range(i + 1, j))]
            ncol = len(rows[0])
            longest = [max((visible_length(r[c]) for r in rows if c < len(r)), default=1) for c in range(ncol)]
            # Cap very long cells so one essay-length column does not take everything.
            weights = [min(max(n, 4), 90) for n in longest]
            total = sum(weights)
            # A column must at least fit its longest single word (capped), or a
            # header such as "Objective" breaks mid-word into the next column.
            longest_word = [max((len(w) for r in rows if c < len(r)
                                 for w in re.sub(r"\*\*|`|\*", "", r[c]).split()), default=1)
                            for c in range(ncol)]
            shares = [max(w / total, MIN_SHARE, (min(lw, 16) + 4) / CHARS_PER_LINE)
                      for w, lw in zip(weights, longest_word)]
            norm = sum(shares)
            dashes = [max(3, round(TOTAL_DASHES * s / norm)) for s in shares]
            out[i] = "|" + "|".join("-" * d for d in dashes) + "|"
            i = j
        else:
            i += 1
    return out


def main() -> None:
    path = Path(sys.argv[1])
    lines = path.read_text().split("\n")
    path.write_text("\n".join(rewrite(lines)))


if __name__ == "__main__":
    main()
