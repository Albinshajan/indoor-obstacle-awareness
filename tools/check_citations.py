#!/usr/bin/env python3
"""Cross-check in-text citations against the bibliography.

    python tools/check_citations.py

Reports three things, and exits non-zero if any list is non-empty:

- citations in the chapters with no bibliography entry;
- bibliography entries never cited in the chapters;
- numbered tables and figures that are defined but never referred to in the
  text, or referred to but never defined.

A citation is keyed on its first author's surname and its year ("Okolo 2025",
"Apple Inc. n.d.a"). The check is deliberately literal: a citation written
"Kuriakose et al., 2023" and a bibliography entry "Kuriakose, B., Shrestha, R.
and Sandnes, F.E. (2023)" share the key "Kuriakose 2023" and match.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THESIS = ROOT / "docs/thesis"
CHAPTERS = ["front_matter.md", "ch1_introduction.md", "ch2_literature_review.md",
            "ch3_methodology.md", "ch4_results.md", "ch5_discussion.md",
            "ch6_conclusions.md", "appendices/README.md"]

YEAR = r"(?:\d{4}[a-z]?|n\.d\.[a-z]?)"
# Words that start a capitalised run but are not author surnames.
NOT_NAMES = {"Table", "Figure", "Chapter", "Section", "Appendix", "Equation", "The", "In", "See", "Objective",
             "Federal", "Decree", "Law", "No"}


def bibliography_keys() -> dict[str, str]:
    keys = {}
    text = (THESIS / "bibliography.md").read_text()
    for entry in re.split(r"\n\s*\n", text):
        entry = " ".join(entry.split())
        m = re.match(r"^(?P<authors>[^()]+?)\s*\((?P<year>" + YEAR + r")\)", entry)
        if not m:
            continue
        authors = m.group("authors").strip()
        surname = "Apple Inc." if authors.startswith("Apple Inc.") else re.split(r"[ ,]", authors)[0]
        keys[f"{surname} {m.group('year')}"] = entry[:90]
    return keys


# Organisations cited under a multi-word name; the bibliography keys them on
# their first word.
ORGANISATIONS = {"World Health Organization": "World", "United Arab Emirates": "United"}


def text_citations(text: str) -> set[str]:
    found = set()
    text = " ".join(text.split())  # a citation may wrap across a line break
    for name, key in ORGANISATIONS.items():
        text = text.replace(name, key)
    # Parenthetical: (Okolo et al., 2025; He and Saha, 2023) and (Apple Inc., n.d.a)
    for group in re.findall(r"\(([^()]*?" + YEAR + r"[^()]*?)\)", text):
        for part in group.split(";"):
            m = re.search(r"([A-Z][A-Za-zÀ-ſ\-]+(?: Inc\.)?)[^;]*?,\s*(" + YEAR + r")\s*$", part.strip())
            if m and m.group(1) not in NOT_NAMES:
                found.add(f"{m.group(1)} {m.group(2)}")
    # Narrative: Okolo et al. (2025), He and Saha (2023), Khilnani and Devesh's (2025),
    # Kuriakose, Shrestha and Sandnes (2023)
    narrative = re.compile(
        r"([A-Z][A-Za-zÀ-ſ\-]+)((?: et al\.)|(?:(?:, [A-Z][A-Za-zÀ-ſ\-]+)* and [A-Z][A-Za-zÀ-ſ\-]+))?(?:'s)? \((" + YEAR + r")\)")
    for m in narrative.finditer(text):
        if m.group(1) not in NOT_NAMES:
            found.add(f"{m.group(1)} {m.group(3)}")
    return found


def numbered_items(text: str, kind: str) -> tuple[set[str], set[str]]:
    defined = set(re.findall(r"(?:^Table: |!\[)" + kind + r" (\d+\.\d+):", text, flags=re.M))
    referenced = set(re.findall(kind + r"s? (\d+\.\d+)(?!:)", text))
    # "Tables 4.1–4.4" and "Figures 4.1–4.2" refer to every number in the range.
    for a, b in re.findall(kind + r"s (\d+\.\d+)[–-](\d+\.\d+)", text):
        ch, lo = a.split(".")
        _, hi = b.split(".")
        referenced.update(f"{ch}.{n}" for n in range(int(lo), int(hi) + 1))
    return defined, referenced


def main() -> int:
    text = "\n".join((THESIS / c).read_text() for c in CHAPTERS)
    keys = bibliography_keys()
    cited = text_citations(text)
    missing = sorted(c for c in cited if c not in keys)
    uncited = sorted(k for k in keys if k not in cited)
    problems = 0
    print(f"{len(keys)} bibliography entries, {len(cited)} distinct citations in the text")
    if missing:
        problems += len(missing)
        print("\nCited but not in the bibliography:")
        for c in missing:
            print(f"  {c}")
    if uncited:
        problems += len(uncited)
        print("\nIn the bibliography but never cited:")
        for k in uncited:
            print(f"  {k}")
    for kind in ("Table", "Figure"):
        defined, referenced = numbered_items(text, kind)
        # A caption's own "Table 3.1:" is a definition, not a reference in the text.
        never_referred = sorted(defined - referenced, key=lambda s: [int(x) for x in s.split(".")])
        undefined = sorted(referenced - defined, key=lambda s: [int(x) for x in s.split(".")])
        print(f"\n{kind}s: {len(defined)} defined")
        if never_referred:
            problems += len(never_referred)
            print(f"  defined but never referred to in the text: {', '.join(never_referred)}")
        if undefined:
            problems += len(undefined)
            print(f"  referred to but not defined: {', '.join(undefined)}")
    print("\nOK" if problems == 0 else f"\n{problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
