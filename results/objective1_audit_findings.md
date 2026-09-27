# Objective 1 — what the "spurious" boxes actually are (2026-09-21)

`tools/audit_spurious.py` over YOLO26n (Colab run 2 weights) on the 678-image
validation split, at the app's operating point (confidence > 0.30, IoU > 0.5).
Files: `results/objective1_audit/`.

## Why

`results/objective1_confusion_findings.md` counts 581 boxes with no annotated
object under them as **spurious** and charges all of them against precision
(0.438). It flagged that this is an upper bound on false alarms, because the
source corpus's annotation completeness had never been checked. This checks it.

## Automatic split — all 643 boxes the matcher does not credit

(581 spurious + 62 matched-but-misclassified.)

| kind | boxes | what it means |
|---|---|---|
| duplicate | 11 | second box, same class, on an object already matched |
| other_class | 64 | overlaps an object of another class at IoU > 0.5: the 62 misclassifications plus 2 wrong-class duplicates |
| **partial_same** | **169** | overlaps an annotated object **of its own class** at IoU 0.1–0.5: the right thing, boxed too loosely or tightly to count |
| partial_other | 146 | overlaps only objects of other classes at IoU 0.1–0.5 |
| unannotated | 253 | overlaps no annotation at all (IoU ≤ 0.1) |

So **180 of the 581 spurious boxes (31 %) are on an object of the right class**
that is either already matched or matched too loosely. That is a localisation
error, not a false alarm. Per class: `results/objective1_audit/spurious_breakdown.csv`.

## Manual check — a sample of the 253 "unannotated" boxes

The script picked 6 at random per predicted class (5 for `wall`, which has only
5; 47 in total, seed 20260921), drew them on contact sheets (`sheet_1-4.png`),
and wrote `unannotated_sample.csv` with a verdict column.

**CONFIRMED by the researcher, 26 September 2026**, sheet by sheet; the `rater`
column records it. Two of the assistant's verdicts were overturned and they
happen to cancel: **#5** (a person inside a painting) went to *false alarm*,
since a painted figure is not a physical obstacle, and **#28** (a window frame
seen close up) went to *real*.

| predicted | real object, unlabelled | false alarm | unclear |
|---|---|---|---|
| person | **3** | 2 | 1 |
| chair | **5** | 0 | 1 |
| table | 1 | 3 | 2 |
| door | 1 | 2 | 3 |
| window | **4** | 2 | 0 |
| stairs | 1 | 3 | 2 |
| wall | 2 | 2 | 1 |
| low_obstacle | 4 | 2 | 0 |
| **all** | **21 (45 %)** | **16 (34 %)** | 10 (21 %) |

Examples: #9 and #12, a clearly visible blue chair with no annotation. #22, an
open door. #3, a seated man. The false alarms include a swimming-pool edge
called `table`, church pews called `table`, a vent grille called `stairs`, a
lit building facade called `stairs`, and single boxes drawn over a whole crowd
or balcony.

## What follows, and what does not

- **Confident `chair` and `person` boxes in the sample are mostly over real,
  unlabelled objects** (8 of 12, with one more unclear each). Six per class is
  small, but the
  direction is consistent, and it fits the two independent observations
  already on record: these are the two weakest classes, and large people are
  found *less* often than medium ones.
- **The damage goes beyond measurement.** An unlabelled person in a training
  image is a person the model is taught to call background. That pressure lands
  on exactly the two classes with the lowest recall. This is what motivated
  `tools/relabel_missing.py` and the `relabel` training variant.
- **Reported precision is too low, by an amount that can only be bounded.**
  Scaling each class's sample rate to that class's unannotated count gives
  roughly **131** real-but-unlabelled objects among the 253 (**168** if every
  "unclear" were real). Crediting them would move YOLO26n's precision from 0.438
  to about **0.55–0.59**. With six boxes per class that is an indication, not a
  measurement, so the thesis keeps 0.438 as the reported figure.
- `table`, `door` and `stairs` "unannotated" boxes are mostly genuine errors or
  unclear. For those classes the spurious count is closer to real.

## The relabelled training split (`tools/relabel_missing.py`)

A YOLO26x COCO teacher, run over the 2,714 training images (confidence ≥ 0.5,
added only where no existing box of any class overlaps at IoU ≥ 0.3), added
**2,204 boxes to 868 images: 1,620 `person`, 534 `chair`, 50 `table`**. That
more than doubles the training split's 1,248 annotated people. It is the
strongest evidence yet that the source corpus annotated people only
selectively.

A seeded sample of 36 added boxes (16 person, 12 chair, 8 table) was checked on
contact sheets, **confirmed by the researcher 26 September** (`relabel_sheet_1-3.png`,
`relabel_sample.csv`):

| class | correct | wrong | unclear |
|---|---|---|---|
| person | 12 | **4** | 0 |
| chair | 9 | 1 (a bed footboard) | 2 (dark crops) |
| table | 8 | 0 | 0 |
| **all** | **29 (81 %)** | **5** | 2 |

The assistant had judged all 16 `person` boxes correct; the researcher rejected
four on review. The errors cluster in `person`, which is also the class the
relabelling added most of (1,620 of 2,204 boxes). Tables came through cleanest,
8 of 8. The validation split was not touched.

## The relabelled AI Builders images (for the `full` variant)

The same teacher rule over AI Builders train + valid (1,242 images, which have
no `person` class at all) added **431 boxes: 295 person, 118 chair, 18 table**.
Every original AI Builders label is preserved unchanged, which was checked file
by file.

A 12-box sample (`relabel_aib_sheet.png`, `relabel_aib_sample.csv`, confirmed
by the researcher 26 September): **9 correct, 3 wrong** — #1 is one box over two
people, #8 a green cushion called a chair, #11 a vending-machine base called a
table.

**Across all three confirmed sets: 38 of 48 added labels are correct (79 %).**
That is the number to quote for the quality of the teacher's labels, not the
92 % the assistant's own first pass produced.
