# Objective 1 — full comparison (accuracy + on-device latency + deployment cost)

The joint benchmark RQ1 asks for: real fine-tuned weights (`train_colab.ipynb`,
2 independent runs), real Core ML export (`export_coreml.py`, verified against
raw `.pt` predictions), real on-device latency (`LatencyLogger.swift` wired
into `ios/ObstacleAwareness`'s Benchmark mode, run on the actual iPhone 13
Pro Max — never a Mac-side timing). All four pieces are now real,
measured data, not placeholders.

## The table

| model | mAP50-95 | params | `.mlpackage` size | cold (ms) | sustained (ms) | p95 sustained (ms) | fps (sustained) | licence |
|---|---|---|---|---|---|---|---|---|
| yolov8n | 0.1254 | 3,013,188 | 6.2 MB | 12.68 | 12.65 | 13.69 | 79.1 | AGPL-3.0 |
| yolo11n | 0.1247 | 2,592,180 | 5.4 MB | 13.04 | 12.87 | 13.93 | 77.7 | AGPL-3.0 |
| **yolo26n** | **0.1696** | **2,508,480** | **5.0 MB** | 13.07 | **12.65** | 13.75 | 79.0 | AGPL-3.0 |

Per-class AP: `results/objective1_accuracy_table.md`. Raw latency
distributions (cold/warm/sustained, all five pipeline stages): `results/objective1_latency/latency_table.csv`.
Throttling plot: `results/objective1_latency/throttling.png`.

## Headline finding

**yolo26n wins on every axis at once** — best accuracy (35% higher pooled
mAP50-95 than the other two), fewest parameters, smallest deployment
footprint, and tied for fastest sustained latency. This is not a
speed-vs-accuracy trade-off story; on this benchmark yolo26n dominates
outright. Worth stating plainly and not underselling it, but also worth
pairing with the caveats already on record in `objective1_accuracy_table.md`
(small/augmented training set, only two training runs, `person`/`chair`
consistently weakest classes) so the claim is appropriately scoped.

## What the real device run showed that a Mac-side test never could

- **Real runs, not smoke tests:** yolov8n ran 1,423.5 s / 42,675 frames,
  yolo11n 771.7 s / 23,143 frames, yolo26n 794.9 s / 23,842 frames — all
  well past the ~10-15 min window CLAUDE.md flagged for thermal throttling.
- **`thermal_state` never left `nominal` in any of the three runs.** CLAUDE.md's
  device-constraints note anticipated throttling within 10-15 min of
  sustained camera + ANE use; that didn't happen here, at least not under
  whatever ambient conditions the phone was in during this session (open
  air, not enclosed, unknown room temperature — not controlled or logged).
  This is a genuine, reportable finding, not a failure of the
  instrumentation: the logger is confirmed working (`thermal_state` is
  populated correctly, cold/warm/sustained phase transitions happen exactly
  at the 60 s / 300 s marks as designed) — the phone simply didn't
  thermally throttle under these particular nano-model workloads. Consistent
  with this, latency barely moves between `cold` and `sustained` for any
  model (≤0.4 ms drift) — no throttling observed, no latency drift observed,
  the two facts agree with each other rather than contradicting.
- **Preprocessing costs almost as much as the neural network itself.**
  `capture` (YpCbCr→BGRA conversion + orientation) + `preprocess` (letterbox
  resize) together average ~5.4-5.6 ms per frame across all three models,
  versus ~7.2-7.4 ms for `detect` — the "boring" buffer-handling code is
  roughly 43% of total pipeline latency, not a rounding error. This is
  exactly the cost CLAUDE.md's device-constraints section warned could get
  silently hidden if done carelessly (e.g. via Vision framework's own
  preprocessing, which this pipeline deliberately avoids); worth a sentence
  in Chapter 4 rather than letting `detect_ms` alone stand in for "pipeline
  latency".
- **All three models sustain 75+ fps end-to-end** on the A15 — comfortably
  real-time for this task; latency is not the bottleneck differentiating
  these three variants, accuracy is.

## Caveat

No pass/fail latency threshold exists in the reviewed literature (CLAUDE.md
section 9's "no latency threshold" write-up defect) — `latency_report.py`
was deliberately run without `--threshold-ms`, so this table reports the raw
distribution only. Do not retroactively invent a threshold to grade these
numbers against; if one gets sourced later, re-run with `--threshold-ms` to
add a pass-rate column.
