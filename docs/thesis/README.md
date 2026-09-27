# Thesis draft — working plan

Target structure: **Investigation/Research** route from the module guidelines
(Slide 4, left-hand column). See "Why this route" below.

Milestones from the guidelines deck:
- **20 Sept 2026** — Draft Thesis (Teams)
- Title page template dated **1 Oct 2026**
- Submission elements: Report (with ethics forms), Code + Data (code
  compulsory), Poster in person *or* recorded presentation + viva

**Governing date: 20 September 2026** (confirmed 15 Sept). An earlier working
assumption of a 15 September hard deadline was incorrect, and is the reason
Objective 4 was descoped on 11 September — see "Open question" below.

## Objective 4 — settled, 15 September

**Not running the participant evaluation.** Confirmed after the deadline
correction, so this is a scope decision rather than a scheduling accident. The
reasoning is in `CLAUDE.md`: five participants over two conditions produces a
demonstration rather than a result, and the thesis criticises small-sample
usability claims elsewhere.

Chapters 1, 2, 4, 5 and 6 already state this correctly and need no rewriting.

**The live consequence:** Objective 3 is now the sole evidence of a delivered
prototype. **Built 16 September** — the decision layer, the Core Haptics path
and the three switchable feedback conditions are implemented, verified against
planted values and running on the device (`results/objective3_prototype.md`).
Three objectives delivered.

## Chapter status

| # | Chapter | File | Status | Blocked on |
|---|---|---|---|---|
| — | Title page | `front_matter.md` | drafted | **final submission date — needs the user** |
| — | Abstract | `front_matter.md` | **complete — all three objectives** | — |
| — | Acknowledgements | `front_matter.md` | drafted | — |
| 1 | Introduction | `ch1_introduction.md` | **drafted** | — |
| 2 | Literature Review | `ch2_literature_review.md` | **drafted, figures verified** | — |
| 3 | Methodology | `ch3_methodology.md` | **complete — §3.8 rewritten around the delivered prototype** | — |
| 4 | Results / Findings | `ch4_results.md` | **complete — all three objectives measured** | — |
| 5 | Discussion | `ch5_discussion.md` | **complete — §5.4.1 added for Obj 3** | — |
| 6 | Conclusions & Further Work | `ch6_conclusions.md` | **complete — distance + prototype conclusions added** | — |
| — | Bibliography | `bibliography.md` | **drafted** | — |
| — | Appendices | `appendices/` | **A–G drafted** | — |

The thesis assembles via `tools/build_thesis.sh` with **no editorial notes left
in the text**, and all 82 numbered section cross-references resolve.

## Why this route, not Product/Software Development

The guidelines offer two structures. This thesis fits the
Investigation/Research one because the defensible contribution is empirical,
not the artifact:

- Objectives 1 and 2 are **measurement studies** with hypotheses, controls and
  error tables — they belong in Methodology → Results → Discussion, not in
  Requirements → Implementation → Testing.
- The participant evaluation (Objective 4) is **descoped**, so the
  "Evaluation" chapter the product route builds toward has no data behind it.
- A "User Guide" chapter for a research prototype that no third party will
  install is filler.

The prototype is still fully documented — it sits inside Methodology
(§3.6–3.8) and Results (§4.3), which is where a research-route thesis puts an
instrument it built to collect its own data.

**If the supervisor prefers the product route**, the material re-cuts without
rewriting: §3.5-3.6 → Requirements Specification, §3.7-3.8 → Analysis and
Design + Implementation, Ch 4 → Testing and Results, Ch 5 → Evaluation.

## Hard constraints on all generated text

Carried from `CLAUDE.md` §1. These are not stylistic preferences:

1. This is **obstacle awareness**, not navigation. No path-following, no route
   guidance, no wayfinding.
2. It is a **supplement to a white cane, never a replacement**.
3. Evaluation with blindfolded sighted participants demonstrates **technical
   feasibility only** — never written up as usability evidence for blind or
   visually impaired users. Since Objective 4 was descoped, no participant
   evidence of any kind exists, which makes this constraint easier to hold and
   more important to state.
4. **"Smartphone-only" is not the contribution.** DeepNAVI (Kuriakose et al.,
   2023) and PathFinder (Das et al., 2025) are already smartphone-only and are
   both in the review corpus.

## Remaining submission elements

Per the guidelines deck, the submission is: **Report** (with ethics forms),
**Code + Data** (code compulsory, submitted as a separate document), and
**either a poster in person or a recorded presentation + viva**.

- **Report** — drafted end to end, assembles clean.
- **Code + Data** — the repository is the code submission; `docs/thesis/appendices/`
  indexes which committed artefact backs each figure.
- **Poster, presented in person, at A5 — decided 16 Sept.**
  `docs/submission/poster.html`; print-ready at `build/poster_A5.pdf` (one page,
  exact 148×210 mm, fonts embedded so the print does not depend on the printing
  machine). Speaking notes in `docs/submission/poster.md`. Regenerate with:

  ```bash
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
    --no-pdf-header-footer --print-to-pdf=build/poster_A5.pdf \
    docs/submission/poster.html
  ```

  To print at another A size, change only the `@page` rule — but the text volume
  is tuned for A5 and would read sparse enlarged. The poster cannot convey the
  graded haptics, which is worth saying aloud at the session and offering the
  phone for.

### Producing the submittable file

`pandoc` 3.11 and `librsvg` are now installed, and **both output formats build
clean with no warnings**:

```bash
tools/build_thesis.sh docx    # contents field (update it in Word), ethics form as page images
tools/build_thesis.sh pdf     # xelatex, report class, Times New Roman, ethics form embedded
```

To style the docx with the university's own template:

```bash
REFERENCE_DOC=~/path/to/template.docx tools/build_thesis.sh docx
```

`--number-sections` is deliberately **not** used. Every heading already carries
its own number, and pandoc's auto-numbering both doubled them and disagreed
with the manuscript's own (it counts the front matter as section 1, making
Chapter 1 into section 2), which would break every cross-reference in the text.
The PDF target forces `xelatex` because the default `pdflatex` drops non-ASCII
characters — en dashes, em dashes, arrows — with only a warning.

### Length

**There is no word limit and no page limit** — the word limit confirmed on
21 September 2026 and the page limit on 26 September. The guidelines deck never
stated either: Slide 24 says appendices are exempt from "the page limit", but no
figure appears anywhere in the document, and none applies in practice.

Recounted 26 September 2026, after the pass against the supervisor's checklist
(`docs/checklist_audit.md`), with `len(re.findall(r'\S+', text))` over the
source files. The count includes table cells, which is most of the growth in
Chapter 3. The built PDF is 128 pages including the 13-page ethics form.

| Part | Words |
|---|---|
| Front matter (abstract, acknowledgements, GenAI declaration, abbreviations) | 1,155 |
| 1 Introduction | 2,390 |
| 2 Literature Review | 5,835 |
| 3 Methodology | 11,993 |
| 4 Results and Findings | 8,908 |
| 5 Discussion | 7,361 |
| 6 Conclusions and Further Work | 2,794 |
| Bibliography (50 entries) | 1,396 |
| **Total** | **41,832** |

The table is kept for orientation, not compliance — with no limit, nothing
needs cutting for length.

### Checks to run after editing the text

```bash
python3 tools/check_citations.py   # citations <-> bibliography; every table/figure referred to
bash tools/build_thesis.sh pdf      # must build with no WARNING lines
```

`check_citations.py` keys citations on first author and year, so a new
citation needs a bibliography entry whose first surname and year match. Tables
are captioned with pandoc's `Table: Table N.M: ...` line and figures with
`![Figure N.M: ...](path)`; the build suppresses LaTeX's own numbering so the
manuscript's numbers are the ones printed and listed.
