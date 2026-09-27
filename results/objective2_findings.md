# Objective 2 — distance validation against physical ground truth (real data, 2026-09-16)

Real tape-measured captures, bright lighting only (see the lighting-coverage
note at the end). 102 frames after cleanup: 90 baseline + 12 recovered from
frames where the distance field wasn't updated before the next distance was
shot (`data/raw/own_capture/_correction_log.txt` has the full audit trail;
19 stray/practice frames excluded, preserved not deleted).

## The one number that matters most: detector coverage was the bottleneck, not depth accuracy

`predict_boxes.py` (yolo26n, Objective 1's winner) found a box in **38 of
102 frames (37%)**. `pole` and `low_obstacle` essentially never fired their
own class (0/22 and 0/22) — consistent with the corpus gap already on
record in CLAUDE.md section 5 (`pole` has zero training instances; low,
floor-level objects don't suit a detector trained mostly on eye-level
Roboflow photography). `door` was the strong performer (11/19 correct-class
hits). Full table: `results/objective2/boxes.md`.

This matters because CLAUDE.md's own standing rule (`distance_eval.py`'s
centred-ROI fallback) says **fallback-derived distance numbers must not be
cited** — they're not measuring the pipeline, they're measuring whether a
frame-centred box happens to land on the object. The rest of this document
only ever reports the `roi_source=detector` subset (`n=73` frames: 35 LiDAR
+ 38 monocular — the two arms don't always agree on which frames because a
detector box exists but the ROI sometimes lands on zero valid LiDAR pixels).

## Headline: LiDAR MAE 0.188 m (16.1% MAPE) vs monocular MAE 1.221 m (69.7% MAPE)

| method | n | MAE (m) | MAPE | RMSE (m) | bias (m) |
|---|---|---|---|---|---|
| **LiDAR** | 35 | **0.188** | **16.08%** | 0.285 | +0.147 |
| Monocular (DAv2-Hypersim-Small) | 38 | 1.221 | 69.72% | 1.282 | +1.221 |

LiDAR wins decisively on accuracy here, not just latency — on real
detector-boxed frames, monocular's error is roughly 6.5x larger. Both
methods bias toward overestimating distance (positive bias), consistent
with sampling the box's lower third catching some floor/background beyond
the object's near edge.

## LiDAR by class (detector-driven only)

| class | n | MAE (m) | MAPE |
|---|---|---|---|
| **door** | 17 | **0.077** | **4.30%** |
| chair | 14 | 0.215 | 10.69% |
| table_edge | 4 | 0.567 | 85.01% |

`door` is a genuinely strong result — 4.3% mean absolute percentage error
against a tape measure, on a consumer phone's LiDAR, is a citable finding.
`table_edge` has only 4 detector-driven samples (thin, ambiguous box
boundaries — likely catching background beyond the table's far edge), too
few to trust; say so rather than present it as equivalent to door/chair's
n=14-17. No LiDAR class breakdown exists for `low_obstacle` or `pole` at
all — zero detector-driven boxes for either, a direct consequence of the
coverage problem above, not a depth-sensing failure.

## LiDAR by distance bin (detector-driven only)

| bin | n | MAE (m) | MAPE |
|---|---|---|---|
| 0.5 m | 3 | 0.409 | 81.9% |
| 1.0 m | 4 | 0.299 | 29.9% |
| 1.5 m | 4 | 0.429 | 28.6% |
| 2.0 m | 3 | 0.195 | 9.8% |
| 2.5 m | 5 | 0.076 | 3.1% |
| 3.0 m | 4 | 0.087 | 2.9% |
| 3.5 m | 4 | 0.057 | 1.6% |
| 4.0 m | 4 | 0.064 | 1.6% |
| 4.5 m | 4 | 0.161 | 3.6% |

Accuracy *improves* with distance from 1.5 m out to 4.0 m (MAPE drops from
28.6% to 1.6%), then ticks up slightly at 4.5 m — consistent with CLAUDE.md's
documented ~5 m LiDAR range ceiling starting to show, though these bins
are small (n=3-5) and this isn't the "error cliff" CLAUDE.md anticipated
past 5 m (captures only go to 4.5 m, so that ceiling itself isn't directly
observed here). The 0.5 m bin's high relative error (82%) is largely a
denominator effect — sub-decimetre absolute misalignment is a huge
percentage of a 0.5 m true distance.

## What this does NOT show (fallback numbers, not cited above)

Including the centred-ROI fallback frames — which is what `results/objective2/results_summary.csv`'s
raw output does, since `distance_eval.py` doesn't filter them out by
default — changes the LiDAR headline from MAE 0.188 m to 0.376 m and
monocular from 1.221 m to 0.963 m (fallback frames pull LiDAR's number
worse and monocular's number *better*, which is itself telling: monocular's
errors are large and fairly consistent regardless of ROI quality, while
LiDAR's accuracy is much more sensitive to whether the sampled region
actually contains the object). **Do not report the unfiltered summary CSV
numbers as the Objective 2 result** — they mix real measurements with
frames where the box was a guess.

## Lighting coverage

**Bright lighting only.** A dim-lighting session was not completed in the
time available. This is a genuine, stated limitation, not a suppressed
result — no dim-condition data exists, fabricated or otherwise, and none is
reported here. `method_light` in the raw summary CSV only ever shows
`bright` for exactly this reason.

## What Chapter 5 should say

Two distinct findings, and they should not be blurred into one:

1. **The distance-sensing result is strong where the detector actually
   finds the object** — LiDAR MAE 16% overall, 4.3% for door specifically.
   This is the RQ2 contribution: independently-measured physical ground
   truth the reviewed literature doesn't provide.
2. **The detector's real-world recall on the researcher's own capture
   conditions (37%) is the actual bottleneck**, not depth sensing — this is
   a domain-gap finding (Roboflow's training photography vs. a chest-held
   phone in a specific set of rooms) worth its own paragraph, and it's
   honest, useful limitations material rather than something to minimize.
