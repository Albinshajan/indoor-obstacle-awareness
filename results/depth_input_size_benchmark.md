# Depth model input-size benchmark (Core ML export, 2026-09-08)

Depth-Anything-V2-Metric-Indoor-Small (Hypersim checkpoint) exported at all
three candidate input sizes CLAUDE.md section 6 asked to benchmark. All
three: real export (not simulated), real prediction on a COCO image,
zero NaNs.

| input size | params | `.mlpackage` size | depth min/max/mean (m) | Mac `predict()` median (ms) |
|---|---|---|---|---|
| 322 | 24,785,089 | 49.0 MB | 1.97 / 11.31 / 5.55 | 10.6 |
| 392 | 24,785,089 | 49.2 MB | 1.91 / 10.46 / 5.16 | 18.2 |
| 518 (reference) | 24,785,089 | 49.6 MB | 1.40 / 10.25 / 4.69 | 46.6 |

Param count and `.mlpackage` size are essentially flat across input sizes
(as expected — the network's weights don't change, only the input
resolution does). The size/speed trade-off is entirely in compute per
frame, not deployment footprint.

**The Mac `predict()` timings are informational only, not a device latency
claim** — CLAUDE.md's rule stands: Core ML prediction on macOS runs on the
Mac's Neural Engine and says nothing about the A15. They're included here
only to show the *relative* scaling trend before real on-device numbers
exist: 322→392 is +72% latency for a resolution CLAUDE.md already expected
to be faster, 322→518 is +340%, roughly tracking the quadratic-ish cost a
ViT backbone's attention mechanism would predict as token count grows with
resolution. Real per-size latency has to come from `LatencyLogger.swift` on
the phone once the on-device inference pipeline exists (not yet built).

Depth values shift slightly across sizes (mean 5.55→5.16→4.69 m) on the
same input image and reticle-independent full-frame stats — expected given
a different effective receptive field per resolution, not yet analysed
against the tape-measured ground truth (`distance_eval.py`'s job, once real
capture data exists).
