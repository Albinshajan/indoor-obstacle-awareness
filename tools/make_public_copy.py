#!/usr/bin/env python3
"""Export a public copy of the repository with personal material removed.

    python3 tools/make_public_copy.py <output-dir>

The private repository keeps everything. The public copy is a fresh export of
the committed tree (`git archive HEAD`), so nothing removed here survives in
its history. It:

- leaves out the signed ethics form (it carries the researcher's and the
  supervisor's signatures), the University's guidelines deck, and the original
  participant-sheet .docx files (their text, redacted, is in Appendix A);
- replaces personal contact details, the iPhone's device identifier and the
  Apple developer team identifiers with placeholders;
- marks the README and Appendix A as the public version;
- then scans every text file and stops with an error if any known personal
  detail is still present.

Run it only on a clean, committed tree: uncommitted changes are not exported.

To update the public repository later, run it again on the same directory (its
.git is kept), then commit and push there. The public working copy lives at
~/Documents/indoor-obstacle-awareness, remote Albinshajan/indoor-obstacle-awareness.
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REMOVE = [
    "docs/source_documents/Albin-Ethics_updated_Signed-IR.pdf",
    "docs/source_documents/dissertation_project_guidelines_extracted.md",
    "docs/source_documents/ethics_attachments",
]

# The strings to redact are personal, so they live in a local file that is
# never committed (tools/public_redactions.local.tsv, one "find<TAB>replace"
# per line, longer strings before the substrings they contain). Keeping them
# out of this script matters: the script itself is part of the public copy.
REDACTIONS_FILE = ROOT / "tools" / "public_redactions.local.tsv"


def load_redactions() -> list[tuple[str, str]]:
    if not REDACTIONS_FILE.exists():
        sys.exit(f"missing {REDACTIONS_FILE.relative_to(ROOT)} -- it lists the personal strings to remove")
    pairs = []
    for line in REDACTIONS_FILE.read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            find, _, replace = line.partition("\t")
            pairs.append((find, replace))
    return pairs


# UAE phone numbers: mobile (05x xxx xxxx) and the UAE country code. Built from
# parts so that this file does not match its own check.
PHONE = re.compile(r"\b05\d{8}\b|" + re.escape("+" + "971"))

PUBLIC_NOTE = """> **Public version.** This repository is a cleaned copy of the project. The
> signed ethics form and the University's guidelines deck are not included,
> personal contact details in the participant documents are replaced by
> "[removed]", and device and developer-account identifiers are replaced by
> placeholders. The history starts from this snapshot."""

APPENDIX_OLD = ("Source files are in\n`docs/source_documents/` and "
                "`docs/source_documents/ethics_attachments/`.")
APPENDIX_NEW = ("In this public copy the signed form is not included, because it "
                "carries signatures, and contact details in A.2–A.4 are replaced "
                "by \"[removed]\"; both are complete in the submitted report.")


def export(out: Path) -> None:
    """Replace the directory's contents with the committed tree. An existing
    .git directory is kept, so the public repository's history continues and an
    update is just a new commit there."""
    kept_git = None
    if (out / ".git").is_dir():
        kept_git = out.parent / (out.name + ".git-kept")
        if kept_git.exists():
            shutil.rmtree(kept_git)
        shutil.move(str(out / ".git"), kept_git)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    if kept_git:
        shutil.move(str(kept_git), out / ".git")
    archive = subprocess.run(["git", "-C", str(ROOT), "archive", "HEAD"], check=True, capture_output=True).stdout
    subprocess.run(["tar", "-x", "-C", str(out)], input=archive, check=True)


def text_files(out: Path):
    for f in out.rglob("*"):
        if f.is_file():
            try:
                yield f, f.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1]).resolve()
    dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"], capture_output=True, text=True).stdout
    if dirty.strip():
        sys.exit("uncommitted changes in the repository -- commit first, the export reads HEAD")
    export(out)

    for rel in REMOVE:
        p = out / rel
        if p.is_dir():
            shutil.rmtree(p)
        elif p.exists():
            p.unlink()

    redact = load_redactions()
    forbidden = [a for a, _ in redact]
    for f, text in text_files(out):
        new = text
        for a, b in redact:
            new = new.replace(a, b)
        if f == out / "README.md":
            new = new.replace("<!-- PUBLIC_VERSION_NOTE -->", PUBLIC_NOTE)
        if f == out / "docs/thesis/appendices/README.md":
            if APPENDIX_OLD not in new:
                sys.exit("Appendix A wording changed -- update APPENDIX_OLD in make_public_copy.py")
            new = new.replace(APPENDIX_OLD, APPENDIX_NEW)
        if f == out / "docs/source_documents/README.md":
            new = "\n".join(l for l in new.split("\n")
                            if "Albin-Ethics_updated_Signed-IR.pdf" not in l
                            and "dissertation_project_guidelines_extracted.md" not in l)
            new = new.split("## A note on committing a signed document")[0].rstrip() + (
                "\n\nThe signed ethics form, the University's guidelines deck and the "
                "original participant-sheet files are not included in this public "
                "copy.\n")
        if new != text:
            f.write_text(new, encoding="utf-8")

    problems = []
    for f, text in text_files(out):
        for s in forbidden:
            if s in text:
                problems.append(f"{f.relative_to(out)}: contains a personal string ({s[:3]}...)")
        for m in PHONE.finditer(text):
            problems.append(f"{f.relative_to(out)}: phone-like {m.group(0)!r}")
    for rel in REMOVE:
        if (out / rel).exists():
            problems.append(f"{rel} still present")
    if problems:
        sys.exit("public copy NOT clean:\n  " + "\n  ".join(problems))

    emails = sorted({m.group(0) for _, t in text_files(out)
                     for m in re.finditer(r"[\w.+-]+@[\w-]+\.[\w.]+", t)})
    print(f"public copy written to {out}")
    print("email-like strings remaining (review):", ", ".join(emails) or "none")


if __name__ == "__main__":
    main()
