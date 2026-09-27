# Objective 3 — on-device latency and thermal behaviour (2026-09-16)

Two live runs of the complete prototype: ARKit frame → upright rotation →
yolo26n detection → `sceneDepth` sampling inside each box → derived-feature
layer → audio **and** haptic dispatch, feedback condition `both`.

| | run 1 | **run 2 (authoritative)** |
|---|---|---|
| frames | 3,142 | **6,035** |
| duration | 137.6 s | **202.4 s** |
| processed rate | 22.8 fps | **29.8 fps** |
| time at `serious` thermal | 3.0 s | **81.2 s** |
| decision-layer columns logged | no | **yes** |

Run 1 exposed two defects (a frame-scheduling bug and the absence of any record
of *what* was detected). Both were fixed between runs. **Run 2 is the run to
cite**; run 1 is retained because the comparison is itself a result.

Raw logs: `data/raw/device_logs/assist/run{1_before_framerate_fix,2_final}/`.
Processed tables: `results/objective3/latency/` and `latency_run1/`.

## Per-stage cost (run 2, frame 1 excluded as cold-start)

| stage | mean (ms) | median | p95 | share of frame |
|---|---|---|---|---|
| `capture` — rotate and render | 4.06 | 3.70 | 6.70 | 30.5% |
| `preprocess` — letterbox | 1.74 | 1.51 | 3.32 | 13.1% |
| `detect` — Core ML forward pass | 6.41 | 6.03 | 9.41 | 48.1% |
| `depthSample` — LiDAR median | 1.05 | 0.66 | 3.18 | 7.9% |
| `feedback` — derive and dispatch | **0.066** | 0.058 | 0.146 | **0.5%** |
| **total** | **13.32** | **13.02** | **17.06** | |

**The decision layer costs 0.066 ms** — half of one percent of the frame, and
roughly a hundredth of the detector. That covers distance, bearing, the
least-squares closing rate, time-to-contact, the hazard-weighted urgency score,
IoU association across tracks, the 3-of-5 announcement gate, the hysteresis,
the haptic parameter update and the earcon dispatch. Keeping
`AVSpeechSynthesizer` out of this path is vindicated by a factor of several
thousand, not by an argument.

**`depthSample` costs 1.05 ms** (median 0.66 ms), 7.9% of the frame, for
sampling a depth map that arrives in the `ARFrame` already. The monocular
alternative is a full ViT forward pass. With Objective 2's accuracy result
(0.188 m against 1.221 m), both axes of RQ2's comparison point the same way.

**Buffer handling is 43.6% of the frame** — `capture` plus `preprocess` at
5.80 ms against `detect`'s 6.41 ms. Objective 1 measured 43% through
`AVCaptureSession` with manual YpCbCr→BGRA conversion and no ARKit; this
reproduces it through `ARFrame` and `CIImage`, a wholly separate code path.
Two independent implementations agreeing to within a percentage point makes
this a property of mobile vision pipelines rather than of one piece of code.

## Thermal: escalates in minutes, costs latency, magnitude NOT established

Three live runs now exist. The third (18 September, 6.1 minutes, 10,869 frames)
was run specifically to test whether the penalty measured on 16 September holds
over a longer session. **It does not replicate, and the honest conclusion is
weaker than the one this document previously carried.**

| | run 2 — 16 Sept, 3.4 min | run 3 — 18 Sept, 6.1 min |
|---|---|---|
| reached `fair` | 56.2 s | 142.9 s |
| reached `serious` | **121.2 s** | **307.9 s** |
| held at `serious` | 81.2 s | 55.9 s |
| `fair` mean total (warm only) | 12.878 ms | 12.837 ms |
| `serious` mean total (warm only) | 13.305 ms | 15.134 ms |
| **change** | **+3.3%** | **+17.9%** |
| `detect` change | +2.4% | +8.8% |
| p95 total | 15.95 → 17.11 ms | 15.63 → 19.04 ms |
| **processed rate at `serious`** | **30.0 fps** | **30.0 fps** |

### What is established across both runs

**Thermal state escalates within minutes**, an order of magnitude sooner than
the detector alone, which never left `nominal` across three runs of 13–24
minutes (§4.1.4). And **the frame rate is unaffected**: exactly 30.0 processed
frames per second throughout `serious` in both runs, no dropped frames, across
137 seconds of combined `serious` operation. The direction of the latency
effect is also consistent — it rises.

### What is NOT established

**The magnitude.** +3.3% and +17.9% differ by a factor of 5.4, and the earlier
characterisation of the penalty as "operationally negligible" rested on the
single smaller number. That characterisation is withdrawn. On run 3 the p95
moved from 15.6 ms to 19.0 ms, which is not negligible, and the final 60-second
window shows `detect` at 7.381 ms against a run-wide mean of 5.888 ms.

**The likely reason the two disagree is visible in the same table**: time to
reach `serious` also varied by a factor of 2.5 (121 s against 308 s). The
device took much longer to heat on run 3, which points at starting and ambient
temperature — explicitly neither controlled nor recorded (§5.2.4). A quantity
that varies 2.5× between runs under an uncontrolled variable cannot support a
precise claim about what it costs.

So the defensible statement is: **sustained operation at `serious` costs frame
time in a consistent direction and no frames, by an amount this study measured
between 3% and 18% under uncontrolled ambient conditions.** Pinning the
magnitude needs ambient temperature recorded and several runs per condition,
which is a thermal-characterisation study rather than a line in this one.

### Run 3 per-stage, for the record

Frame 1 excluded. 10,869 frames, 363.9 s, 29.9 fps.

| stage | mean (ms) | median | p95 |
|---|---|---|---|
| `capture` | 4.053 | 3.537 | 6.965 |
| `preprocess` | 1.369 | 1.301 | 1.840 |
| `detect` | 5.888 | 5.525 | 8.699 |
| `depthSample` | 2.193 | 2.028 | 4.059 |
| `feedback` | **0.094** | 0.074 | 0.191 |
| **total** | **13.597** | 13.199 | 17.936 |

By session phase: cold 13.077 ms, warm 13.376 ms, **sustained 14.905 ms**. This
is the first run to reach the `sustained` phase at all, but it crosses into
`serious` at almost the same moment (307.9 s against the 300 s phase boundary),
so phase and thermal state cannot be separated here.

The decision layer holds at **0.094 ms** — consistent with run 2's 0.066 ms and
still around a hundredth of the detector.

## What the pipeline actually reported

Run 2 is the first log carrying the decision layer's own output. Of 6,035
frames, 3,855 (63.9%) had a confirmed obstacle with a distance; of those, 3,348
were in a band that drove feedback and 507 scored `clear`.

| `top_class` | frames | share |
|---|---|---|
| `low_obstacle` | 1,058 | 27.4% |
| `wall` | 793 | 20.6% |
| `stairs` | 764 | 19.8% |
| `door` | 758 | 19.7% |
| `chair` | 265 | 6.9% |
| `table` | 143 | 3.7% |
| **`person`** | **64** | **1.7%** |
| `window` | 10 | 0.3% |

**This settles the `person` question with data.** A live session had reported
the prototype announcing `person` for scenes containing no person. `person`
turns out to be the second *least* frequent class to drive feedback, at 1.7% of
frames. The impression came from the interface, not the pipeline: tracks average
1.23 per frame against 0.92 confirmed, and in 619 frames the gate held back
every track present. Roughly a quarter of the rows a viewer sees at any moment
are gated — displayed deliberately so the gate's behaviour is visible, but not
vibrating, not beeping and not speakable. The interface now labels them.

`pole` never appears, as expected: it has zero training instances. Urgency bands
driving feedback were `stop` 1,439, `close` 1,023, `ahead` 886.

One observation to carry into Chapter 5: `top_distance_m` ranges from 0.05 m to
**5.95 m**, so `sceneDepth` returned readings past the ~5 m ceiling recorded in
§3.1. Those frames reached the feedback path through the time-to-contact term
rather than proximity, which saturates at 4.0 m by design. Objective 2's
capture protocol stopped at 4.5 m, so the accuracy of readings beyond 5 m is
untested and no claim is made about them.

## Caveats

1. **One device, one model (yolo26n), one feedback condition (`both`).** The
   condition matters for thermal load specifically, since `both` runs the haptic
   and audio engines simultaneously.
2. **3.4 minutes.** Objective 1's figures come from runs of 13–24 minutes and
   are not comparable in weight.
3. **`critical` thermal state was never reached**, so nothing here describes
   behaviour at the top of the scale.
4. **No latency threshold exists to grade any of this against** (§4.1.6, §6.5
   item 3). 13.32 ms is reported, not passed or failed.
5. **Class counts are frames, not objects.** A single obstacle held in view for
   a second contributes ~30 frames, so the table describes what drove feedback
   over time and not how many distinct obstacles were encountered.
