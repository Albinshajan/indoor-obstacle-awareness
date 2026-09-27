#!/usr/bin/env bash
# Assemble docs/thesis/*.md into one document for submission.
#
#   tools/build_thesis.sh            -> build/thesis.md
#   tools/build_thesis.sh docx       -> build/thesis.docx  (needs pandoc)
#   tools/build_thesis.sh pdf        -> build/thesis.pdf   (needs pandoc + a LaTeX engine)
#
# Chapter order is fixed here rather than derived from filenames, so renaming a
# file cannot silently reorder the thesis.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=docs/thesis
OUT=build
mkdir -p "$OUT"

CHAPTERS=(
  "$SRC/front_matter.md"
  "$SRC/ch1_introduction.md"
  "$SRC/ch2_literature_review.md"
  "$SRC/ch3_methodology.md"
  "$SRC/ch4_results.md"
  "$SRC/ch5_discussion.md"
  "$SRC/ch6_conclusions.md"
  "$SRC/bibliography.md"
  "$SRC/appendices/README.md"
)

for f in "${CHAPTERS[@]}"; do
  [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
done

# Each file starts on a new page. In the PDF that is a raw LaTeX block; in the
# docx it is the reference template's page break before every level-1 heading
# (tools/make_reference_docx.py), so no explicit break is added there.
{
  for f in "${CHAPTERS[@]}"; do
    cat "$f"
    printf '\n\n```{=latex}\n\\clearpage\n```\n\n'
  done
} > "$OUT/thesis.md"

# Column widths follow content rather than being equal (see the script header).
python3 tools/format_tables.py "$OUT/thesis.md"

# Count the editorial notes that must not reach a submitted document.
#
# This deliberately flags EVERY blockquote rather than matching a list of
# known note prefixes. The earlier version matched
# ^> \*\*(VERIFY|To be completed|Provisional|Status:|Stub|Regenerated) and
# therefore reported a clean thesis while three real notes sat in Chapter 2
# opening "To add", "Consider" and "Note on" -- an allow-list of prefixes can
# only ever catch the note styles someone already thought of. The thesis uses
# blockquotes for nothing else, so anything quoted is a note until it isn't.
NOTES=$(grep -cE '^> ' "$OUT/thesis.md" || true)

echo "built $OUT/thesis.md ($(wc -l < "$OUT/thesis.md") lines)"
if [ "$NOTES" -gt 0 ]; then
  echo "WARNING: $NOTES editorial note(s) still in the text -- these are notes to yourself, not thesis content:"
  grep -nE '^> ' "$OUT/thesis.md" | sed 's/^/  /'
fi

case "${1:-md}" in
  md) ;;
  docx|pdf)
    command -v pandoc >/dev/null || { echo "pandoc not installed: brew install pandoc" >&2; exit 1; }
    # NO --number-sections. Every heading in the manuscript already carries
    # its own number ("## 4.2", "### 3.8.1"), and those are the numbers the
    # whole thesis cross-references. Letting pandoc number as well produced
    # headings like "2.1 1.1 Problem statement" -- doubled, and with an
    # auto-number that disagreed with the manuscript's own, since pandoc
    # counts the front matter as section 1 and makes Chapter 1 section 2.
    # That would break every "see section 4.2" in the text.
    #
    # REFERENCE_DOC lets the university's own template supply the styles:
    #   REFERENCE_DOC=~/path/to/template.docx tools/build_thesis.sh docx
    # No --toc: the front matter places the contents, list of figures and list
    # of tables itself, after the abstract and declarations where the
    # guidelines put them, rather than before the title page.
    #
    # The ethics form (Appendix A) is embedded at the marker in the appendices:
    # as PDF pages in the PDF, and as page images in the docx.
    ETHICS_PDF="$PWD/docs/source_documents/Albin-Ethics_updated_Signed-IR.pdf"
    if [ ! -f "$ETHICS_PDF" ]; then
      # The public copy of the repository leaves the signed form out.
      python3 - "$OUT/thesis.md" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace(
    "<!-- ETHICS_FORM_PAGES -->",
    "*Not included in this copy: the signed form carries the signatures of the "
    "researcher and the supervisor, and is reproduced in the submitted report.*"))
PY
    elif [ "$1" = "pdf" ]; then
      python3 - "$OUT/thesis.md" "$ETHICS_PDF" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); pdf = sys.argv[2]
block = ("```{=latex}\n\\includepdf[pages=-,scale=0.9,pagecommand={\\thispagestyle{plain}}]{" + pdf + "}\n```")
p.write_text(p.read_text().replace("<!-- ETHICS_FORM_PAGES -->", block))
PY
    else
      command -v pdftoppm >/dev/null || { echo "pdftoppm missing (brew install poppler): ethics form pages not embedded" >&2; }
      if command -v pdftoppm >/dev/null; then
        rm -rf "$OUT/ethics_pages" && mkdir -p "$OUT/ethics_pages"
        pdftoppm -r 110 -png "$ETHICS_PDF" "$OUT/ethics_pages/page"
        python3 - "$OUT/thesis.md" "$PWD/$OUT/ethics_pages" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); d = pathlib.Path(sys.argv[2])
imgs = "\n\n".join(f"![]({f})" for f in sorted(d.glob("page-*.png")))
p.write_text(p.read_text().replace("<!-- ETHICS_FORM_PAGES -->", imgs))
PY
      fi
    fi
    PANDOC_ARGS=(--resource-path="$SRC")
    # The Word version is styled by tools/reference.docx (Times New Roman, 1.5
    # spacing, A4, page numbers, chapter page breaks) unless REFERENCE_DOC names
    # another template.
    if [ "$1" = "docx" ] && [ -z "${REFERENCE_DOC:-}" ]; then
      [ -f tools/reference.docx ] || python3 tools/make_reference_docx.py
      REFERENCE_DOC=tools/reference.docx
    fi
    if [ -n "${REFERENCE_DOC:-}" ]; then
      [ -f "$REFERENCE_DOC" ] || { echo "REFERENCE_DOC not found: $REFERENCE_DOC" >&2; exit 1; }
      PANDOC_ARGS+=(--reference-doc="$REFERENCE_DOC")
    fi
    if [ "$1" = "docx" ] && ! command -v rsvg-convert >/dev/null; then
      echo "note: rsvg-convert missing, Figure 2.1 will be dropped -- brew install librsvg" >&2
    fi
    if [ "$1" = "pdf" ]; then
      # xelatex, not the default pdflatex: the manuscript uses en/em dashes and
      # arrows, and pdflatex drops non-ASCII characters with only a warning --
      # so a PDF built with it loses glyphs silently rather than failing.
      PANDOC_ARGS+=(--pdf-engine=xelatex -V geometry:margin=1in -V documentclass=report
                    -V fontsize=11pt --top-level-division=chapter -H tools/thesis_header.tex
                    -V mainfont="Times New Roman" -V mathfont="STIX Two Math" -V monofont=Menlo)
    fi
    pandoc "$OUT/thesis.md" "${PANDOC_ARGS[@]}" -o "$OUT/thesis.$1"
    echo "built $OUT/thesis.$1"
    ;;
  *) echo "usage: $0 [md|docx|pdf]" >&2; exit 1 ;;
esac
