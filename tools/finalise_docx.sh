#!/usr/bin/env bash
# Build the Word version of the thesis and let Microsoft Word finish it.
#
#   bash tools/finalise_docx.sh [output-dir]
#
# pandoc writes the contents page and the lists of figures and tables as Word
# fields, which stay empty until Word updates them. This opens the built docx in
# Word, updates every contents/list field twice (the second pass picks up the
# page numbers the first pass shifted), and saves both a .docx and a Word-made
# .pdf, so the two files match page for page.
#
# Word is sandboxed and can only write inside its own container, so it saves
# there and the files are copied to the output directory (default: build/).
set -euo pipefail
cd "$(dirname "$0")/.."

OUTDIR="${1:-build}"
NAME="Albin_Shajan_M01097740_Dissertation"
WORKDIR="$HOME/Library/Containers/com.microsoft.Word/Data/thesis_export"
mkdir -p "$WORKDIR" "$OUTDIR"

bash tools/build_thesis.sh docx >/dev/null

# The field-dirty flag makes Word ask on opening whether to update fields, and
# that dialog would stall the automation; the fields are updated below instead.
python3 - "build/thesis.docx" "$WORKDIR/input.docx" <<'PY'
import sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == "word/document.xml":
            data = data.replace(b' w:dirty="true"', b"")
        zout.writestr(item, data)
PY

rm -f "$WORKDIR/$NAME.docx" "$WORKDIR/$NAME.pdf"
osascript <<EOF
set inPath to POSIX file "$WORKDIR/input.docx"
set docxPath to (POSIX file "$WORKDIR/$NAME.docx") as text
set pdfPath to (POSIX file "$WORKDIR/$NAME.pdf") as text
with timeout of 300 seconds
  tell application "Microsoft Word"
    open inPath
    set d to active document
    set n to count of tables of contents of d
    repeat 2 times
      repeat with i from 1 to n
        update (table of contents i of d)
      end repeat
    end repeat
    save as d file name docxPath file format format document
    save as active document file name pdfPath file format format PDF
    close active document saving no
  end tell
end timeout
EOF

cp "$WORKDIR/$NAME.docx" "$WORKDIR/$NAME.pdf" "$OUTDIR/"
echo "wrote $OUTDIR/$NAME.docx and $OUTDIR/$NAME.pdf ($(pdfinfo "$OUTDIR/$NAME.pdf" | awk '/^Pages/{print $2}') pages)"
