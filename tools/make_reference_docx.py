#!/usr/bin/env python3
"""Build tools/reference.docx, the style template for the Word version of the thesis.

    python tools/make_reference_docx.py

Starts from pandoc's own default reference document and changes only what the
submitted Word file needs:

- Times New Roman throughout (theme fonts), 12 pt, 1.5 line spacing;
- A4 pages, 1-inch margins, and a centred page number in the footer;
- a page break before every level-1 heading and before the contents and list
  headings, so each chapter starts on a new page;
- a centred "Title Page" paragraph style for the title page;
- rules above and below each table and under its header row.

build_thesis.sh uses the result automatically for `docx` unless REFERENCE_DOC
points at another template (for example the University's own).
"""
from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tools" / "reference.docx"

FOOTER = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:p>
    <w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:fldChar w:fldCharType="begin"/></w:r>
    <w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>
    <w:r><w:fldChar w:fldCharType="separate"/></w:r>
    <w:r><w:t>1</w:t></w:r>
    <w:r><w:fldChar w:fldCharType="end"/></w:r>
  </w:p>
</w:ftr>
"""

SECTPR = ('<w:sectPr><w:footerReference w:type="default" r:id="rIdThesisFooter"/>'
          '<w:pgSz w:w="11906" w:h="16838"/>'
          '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
          'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>')

TITLE_PAGE_STYLE = ('<w:style w:type="paragraph" w:customStyle="1" w:styleId="TitlePage">'
                    '<w:name w:val="Title Page"/><w:basedOn w:val="Normal"/><w:qFormat/>'
                    '<w:pPr><w:spacing w:before="240" w:after="240"/><w:jc w:val="center"/></w:pPr>'
                    '</w:style>')

TABLE_BORDERS = ('<w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>'
                 '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/></w:tblBorders>')


def style_block(styles: str, style_id: str) -> tuple[int, int]:
    m = re.search(r'<w:style [^>]*w:styleId="' + style_id + r'"[^>]*>.*?</w:style>', styles, re.S)
    if not m:
        raise SystemExit(f"style {style_id} not found in the default reference document")
    return m.start(), m.end()


def add_page_break_before(styles: str, style_id: str) -> str:
    """Insert <w:pageBreakBefore/> where the schema puts it: after keepNext and
    keepLines, before everything else. Word rejects out-of-order elements."""
    a, b = style_block(styles, style_id)
    block = styles[a:b]
    m = re.search(r"<w:pPr>(.*?)</w:pPr>", block, re.S)
    if not m:
        block = re.sub(r"(<w:name [^>]*/>)", r"\1<w:pPr><w:pageBreakBefore/></w:pPr>", block, count=1)
    else:
        inner = m.group(1)
        anchor = None
        for tag in ("keepLines", "keepNext", "pStyle"):
            t = re.search(r"<w:" + tag + r"\b[^>]*/>", inner)
            if t:
                anchor = t
                break
        inner = (inner[:anchor.end()] + "<w:pageBreakBefore/>" + inner[anchor.end():]) if anchor \
            else "<w:pageBreakBefore/>" + inner
        block = block[:m.start(1)] + inner + block[m.end(1):]
    return styles[:a] + block + styles[b:]


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        default = tmp / "default.docx"
        subprocess.run(["pandoc", "-o", str(default), "--print-default-data-file", "reference.docx"], check=True)
        work = tmp / "x"
        with zipfile.ZipFile(default) as z:
            z.extractall(work)

        theme = work / "word/theme/theme1.xml"
        t = theme.read_text()
        t = re.sub(r'(<a:(?:major|minor)Font>\s*<a:latin typeface=")[^"]*"', r'\1Times New Roman"', t)
        theme.write_text(t)

        styles_path = work / "word/styles.xml"
        s = styles_path.read_text()
        # 12 pt body text, 1.5 line spacing, from the document defaults.
        s = re.sub(r"<w:sz w:val=\"\d+\"\s*/>", '<w:sz w:val="24"/>', s, count=1)
        s = re.sub(r"<w:szCs w:val=\"\d+\"\s*/>", '<w:szCs w:val="24"/>', s, count=1)
        # One spacing element in the default paragraph properties: keep its
        # space-after and add 1.5 line spacing to it.
        pdef = re.search(r"<w:pPrDefault>.*?</w:pPrDefault>", s, re.S)
        if pdef and "<w:spacing" in pdef.group(0):
            blk = re.sub(r"<w:spacing ([^/]*?)\s*/>", r'<w:spacing \1 w:line="360" w:lineRule="auto"/>', pdef.group(0), count=1)
            s = s[:pdef.start()] + blk + s[pdef.end():]
        else:
            raise SystemExit("unexpected docDefaults layout in pandoc's reference document")
        s = add_page_break_before(s, "Heading1")
        s = add_page_break_before(s, "TOCHeading")
        # Black headings rather than the theme's blue.
        for sid in ("Heading1", "Heading2", "Heading3", "Heading4", "Title", "TOCHeading"):
            a, b = style_block(s, sid)
            blk = re.sub(r"<w:color [^>]*/>", '<w:color w:val="000000"/>', s[a:b])
            s = s[:a] + blk + s[b:]
        # Rules above and below each table; tblBorders goes after tblInd per the
        # schema. The header-row rule is already in pandoc's style.
        a, b = style_block(s, "Table")
        blk = re.sub(r"(<w:tblInd [^>]*/>)", r"\1" + TABLE_BORDERS, s[a:b], count=1)
        s = s[:a] + blk + s[b:]
        s = s.replace("</w:styles>", TITLE_PAGE_STYLE + "</w:styles>")
        styles_path.write_text(s)

        (work / "word/footer1.xml").write_text(FOOTER)
        rels = work / "word/_rels/document.xml.rels"
        r = rels.read_text().replace(
            "</Relationships>",
            '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" '
            'Id="rIdThesisFooter" Target="footer1.xml" /></Relationships>')
        rels.write_text(r)
        ct = work / "[Content_Types].xml"
        c = ct.read_text().replace(
            "</Types>",
            '<Override PartName="/word/footer1.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/></Types>')
        ct.write_text(c)
        doc = work / "word/document.xml"
        d = doc.read_text()
        d = re.sub(r"<w:sectPr.*?</w:sectPr>", "", d, flags=re.S)
        d = d.replace("</w:body>", SECTPR + "</w:body>")
        doc.write_text(d)

        tmp_out = tmp / "reference.docx"
        with zipfile.ZipFile(tmp_out, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(work.rglob("*")):
                if f.is_file():
                    z.write(f, f.relative_to(work).as_posix())
        shutil.copy(tmp_out, OUT)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
