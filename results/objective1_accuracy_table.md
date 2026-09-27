# Objective 1 — accuracy comparison (Colab fine-tuning, two independent runs)

Real training runs via `tools/train_colab.ipynb` on a Colab T4: yolov8n,
yolo11n, yolo26n, identical hyperparameters (50 epochs, no vertical flip, no
mosaic). Trained/validated on `roboflow_lochan` only (2,714 train / 678 val
images, scene-split) — COCO's images are tagged `test_zeroshot` and were
correctly excluded from training, so neither run covers
`person`/`chair`/`table` performance on COCO's own images, only on the
Roboflow indoor scenes. Run 1: 2026-09-08. Run 2: 2026-09-11, same notebook,
same data, no seed pinned — this is a genuine repeat, not a re-download of
the same file (confirmed distinct values throughout).

## Per-class AP50-95, both runs

| class | yolov8n r1 | yolov8n r2 | yolo11n r1 | yolo11n r2 | yolo26n r1 | yolo26n r2 |
|---|---|---|---|---|---|---|
| person | 0.039 | 0.047 | 0.036 | 0.028 | 0.039 | 0.048 |
| chair | 0.028 | 0.021 | 0.028 | 0.032 | 0.047 | 0.047 |
| table | 0.077 | 0.100 | 0.059 | 0.081 | 0.124 | 0.126 |
| door | 0.063 | 0.089 | 0.072 | 0.085 | 0.125 | 0.134 |
| window | 0.055 | 0.045 | 0.040 | 0.041 | 0.061 | 0.049 |
| stairs | 0.212 | 0.169 | 0.169 | 0.242 | 0.242 | 0.258 |
| wall | 0.366 | 0.418 | 0.452 | 0.343 | 0.455 | 0.488 |
| low_obstacle | 0.106 | 0.115 | 0.151 | 0.144 | 0.222 | 0.206 |
| **pooled mAP50-95** | 0.118 | 0.125 | 0.126 | 0.125 | **0.164** | **0.170** |

Full numbers: `results/objective1_train_metrics.csv` (currently holds run 2
— run 1's raw CSV isn't preserved separately, only the values above).

## Reading this honestly

- **yolo26n wins pooled mAP in both runs** (0.164 and 0.170), and wins most
  individual classes in both — this is now evidence across two independent
  runs, not a one-off, which is a meaningfully stronger claim to make in
  Chapter 4 than a single run would support.
- **Run-to-run variance is small on pooled mAP** (≤0.007 absolute for every
  model) but **larger on individual classes** — e.g. yolo11n's `stairs`
  AP50-95 went 0.169→0.242 and its `wall` went 0.452→0.343 between runs, a
  bigger swing than the pooled number suggests. Per-class numbers from a
  single run should be treated as noisy; if per-class claims matter for the
  writeup, average across runs or report a range, not one run's figure.
- **Correction (2026-09-11): the weakest class is not consistently
  `person`.** An earlier version of this note claimed "person is
  unexpectedly the weakest class for every model" — checking the actual
  numbers across both runs shows that's wrong: `chair` is the weakest class
  in 4 of 6 (model, run) combinations, `person` in 2 of 6. The accurate
  finding is that **`person` and `chair` are consistently the two weakest
  classes**, trading last place between runs — still notable (person is
  usually an *easy* class elsewhere, e.g. COCO), still worth a manual
  spot-check of labeling quality in `roboflow_lochan`, but "always worst"
  was an overclaim from only having looked at run 1's numbers casually.
- **Absolute mAP is low across all three models** (pooled mAP50-95
  0.12-0.17 across both runs). Plausible reasons, not yet distinguished
  from each other: only ~900 distinct source photographs behind the 2,714
  augmented train images (Roboflow's own 3x augmentation, not independent
  data), only 50 epochs, and no audit yet of the Roboflow annotation
  quality itself. Don't read this as "the pipeline is broken" or "the
  pipeline is fine" — neither is established yet.
- **`stairs`** — the highest-consequence class per the hazard weighting in
  CLAUDE.md section 7 — is mid-table in both runs (0.17-0.26), not the
  worst, but not strong either.
- This table is **accuracy only**. Objective 1's full comparison needs
  on-device latency, parameter count, `.mlpackage` size, and licence
  alongside this — those come from `export_coreml.py`'s manifest (detector
  + depth paths both verified, see CLAUDE.md section 8) and
  `LatencyLogger.swift` (not yet wired into a live on-device pipeline).
- **Fine-tuned weights (`best.pt` per model) still not recovered from
  either Colab run** — `train_colab.ipynb`'s download cell for
  `finetuned_weights.zip` hasn't come through yet (browser likely blocked
  the second automatic download). Until that lands, `export_coreml.py`'s
  detector export still only has pretrained COCO weights to work with, not
  the real fine-tuned indoor ones — the accuracy numbers above exist, but
  can't yet be exported to Core ML for the on-device latency benchmark.
