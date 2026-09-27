# Objective 3 — the delivered prototype (2026-09-16)

Objective 3 is the build, not a research question. With the participant
evaluation descoped on methodological grounds (§1.5), the working system is the
whole of the evidence that Objective 3 was delivered, so this document records
what was built, what decision it settled on which evidence, and what has and
has not been measured.

Source: `ios/ObstacleAwareness/Sources/Assist/`. Runs on the iPhone 13 Pro Max
(A15 Bionic, iOS 26.5) as the app's default mode; the Objective 2 capture tool
and the Objective 1 benchmark harness remain in the same build behind a mode
switch.

## The depth source was chosen on Objective 2's measurement, not assumed

`CLAUDE.md` deliberately sequenced this work after Objective 2, because which
depth source the decision layer samples should follow the data. Objective 2
(`results/objective2_findings.md`, 102 tape-measured frames) settles it:

| | LiDAR (ARKit `sceneDepth`) | Monocular (DAv2-Metric-Hypersim-S) |
|---|---|---|
| MAE, detector-driven boxes | **0.188 m** | 1.221 m |
| MAPE | **16.1%** | 69.7% |
| `door` alone | **0.077 m / 4.3%** | — |
| per-frame cost | sensor-driven, already in the `ARFrame` | a full ViT forward pass on the ANE |

Accuracy and latency point the same way, which is not the trade-off RQ2 was
expected to produce. The prototype samples `sceneDepth`. The cost is device
coverage — this path needs a Pro-tier iPhone — and that is RQ2's actual answer
rather than a limitation discovered late.

## The derived-feature layer as built

| Feature | Implementation |
|---|---|
| Object distance | median `sceneDepth` over the box's **lower third**, `ARConfidenceLevel.low` discarded, stride-sampled to at most 1,500 values |
| Bearing zone | box centroid x → left / centre / right at the frame thirds |
| Hazard weight | fixed per-class table mirroring `tools/taxonomy.py`'s `HAZARD_WEIGHT` |
| Closing rate | least-squares slope of distance against time over a 0.6 s window, minimum 3 samples |
| Time-to-contact | distance ÷ closing rate, only where the rate exceeds 0.05 m/s |
| Urgency score | `min(1, proximity + 0.35 × ttcTerm) × hazardGain` |
| Haptic encoding | urgency → (intensity 0.25–1.0, sharpness 0.20–1.0, pulse rate 1.1–7.1 Hz) |
| Announcement gate | 3-of-5 frame confirmation; retired after 8 consecutive misses; level hysteresis with a 0.08 fall margin |

`proximity` is 1 at or inside 0.5 m and 0 at or beyond 4.0 m. `hazardGain` is
`0.6 + 0.4 × weight`, so class modulates the score by up to 40% rather than
determining it.

### Two design corrections made while building

**The urgency function's first form could not reach its own top band.**
Proximity and time-to-contact initially shared a fixed budget (0.65 / 0.35).
That capped a stationary user's urgency at 0.65, below the 0.70 threshold for
the highest warning level — so a staircase 0.5 m directly ahead was reported as
"close" rather than "stop" purely because the user had stopped walking towards
it. Proximity now saturates the score on its own and closing speed boosts it.
Caught by the verification harness below, not by inspection.

**Hazard weight is a gain, not a multiplier.** Multiplying urgency by the raw
class weight scores a chair 0.3 m from the user's shin at 0.3. A low-hazard
*class* is not a low-hazard *situation*. Hazard's role here is to rank
obstacles competing for one announcement slot, not to decide whether an
imminent collision matters.

Both are design choices, reasoned but **not validated against users** — that is
what RQ3 would have begun to do. They must be read as a designed artefact, not
a tuned result.

## Feedback channels

**Haptic.** One looping `CHHapticAdvancedPatternPlayer`, built once as a 0.12 s
continuous pulse inside a loop. All three tactile dimensions are then steered on
the live player: intensity and sharpness as dynamic parameters, pulse rate by
moving the loop's end point. Nothing is rebuilt while feedback is running,
because constructing and scheduling patterns at frame rate glitches audibly as
players are torn down mid-playback. The two dynamic parameters have different
semantics — intensity control is a multiplier over 0…1, sharpness control an
offset over −1…1 — which is easy to get backwards.

**Audio.** Three earcons synthesised into PCM buffers at engine start (440 Hz
single burst, 660 Hz single, 880 Hz double), each with a raised-cosine attack
and release, panned by bearing zone through a mono→stereo mixer. Cadence rises
with the urgency band (2.0 s / 1.0 s / 0.45 s) so the two channels agree rather
than beat against each other when both are active. The audio session uses
`.mixWithOthers`: a category that interrupted other audio would silence a real
user's VoiceOver, turning an assistive aid into an accessibility regression.

**Speech** is `AVSpeechSynthesizer` on a button, never in the frame loop.
First-utterance latency runs to hundreds of milliseconds — against a detection
pipeline of roughly 13 ms (§4.1), a single spoken word would swamp the
measurement by an order of magnitude and the reported latency would become a
property of the speech synthesiser.

**Three modes** — audio-only, haptic-only, both — switchable at runtime, so the
comparison the ethics approval covers is built into the instrument even though
the study was not run.

## What has been verified, and how

**Off-device, 45 checks, all passing** —
`results/objective3/decision_layer_verification.md`, reproduced by
`tools/verify_decision_layer.sh`. It compiles the three pure sources for macOS
and checks them against planted values: the letterbox round trip, the
portrait↔landscape rotation corner by corner and under four applications, the
lower-third derivation, a planted 2.5 m depth region recovered from behind a
low-confidence majority, the urgency function's monotonicity and bounds, and
the gate's confirm / retire / hysteresis behaviour.

This exists because the offline distance pipeline shipped a coordinate bug that
did not crash: one pixel box applied to two differently-sized arrays returned
no reading for every frame, and that was logged as a plausible LiDAR range
finding. A day went into chasing a hardware limit that was arithmetic. The live
pipeline carries the same hazard twice over — letterbox padding, and a rotation
between the detector's frame and the depth map's — so both are pinned to
planted values.

The harness caught a second real defect: a fully off-frame region of interest
was clamped into a single corner pixel and returned that pixel's depth as
though it were a reading of the object.

**On-device.** The app builds, installs and launches on the iPhone 13 Pro Max,
and the pipeline is wired end to end with `LatencyLogger`'s `depthSample` and
`feedback` stages now populated (they read 0 in the Objective 1 logs by
design — they belonged to this layer, which did not exist yet).

**Not yet measured:** per-stage latency for the full assist pipeline under a
real indoor scene, and the pulse-rate/intensity response recorded from a
physical approach. Both need the phone held and walked towards an obstacle,
which is the one part of this that cannot be automated. The procedure and the
processing command are in `docs/session_2026-09-16.md`.

## Known limitations, for Chapter 5

- **The urgency weighting is unvalidated.** No user has confirmed that what
  this function scores as urgent feels urgent.
- **Detector coverage bounds the whole system.** Objective 2 measured a box in
  only 37% of frames, and `pole` and `low_obstacle` never fired their own
  class. The decision layer cannot score an obstacle the detector never
  reports, so its ceiling is the detector's recall, not its own accuracy.
- **LiDAR restricts the device.** The accuracy argument for `sceneDepth` is
  also an argument against the smartphone-only positioning: this configuration
  needs a Pro-tier iPhone.
- **VoiceOver contention is mitigated, not solved.** `.mixWithOthers` keeps the
  screen reader audible; the two still compete for the user's attention.
- **One obstacle drives feedback at a time.** Two simultaneous haptic patterns
  are indistinguishable through a single actuator.

---

## Addendum, 2026-09-16 evening — measured on device

Two live runs; full detail in `results/objective3/latency_findings.md`. Run 2
(6,035 frames, 202.4 s, 29.8 fps) is authoritative.

- **Total 13.32 ms per frame**, of which the **decision layer is 0.066 ms** —
  half of one percent, roughly a hundredth of the detector. Everything in the
  derived-feature table above is free relative to detection.
- **`depthSample` 1.05 ms**, putting a figure on "LiDAR is nearly free".
- **Buffer handling 43.6% of the frame**, replicating Objective 1's 43% on a
  separate code path.
- **Thermal `serious` within minutes**, against detector-only runs that never
  left `nominal` in over fifteen minutes. **Its cost is not established**: run 2
  measured +3.3% total latency over 81 s there, run 3 measured **+17.9%** over
  55.9 s on the same build and device, with time-to-`serious` varying 2.5x
  (121 s vs 308 s) — pointing at an unrecorded ambient temperature. What holds
  across both: **30.0 fps throughout, zero dropped frames**, latency rising.
  The naive all-frames comparison inverts even the direction (cache warm-up is
  larger and opposite in sign), so the warm-only restriction is load-bearing.

Three defects found and fixed across the two runs:

- **The frame-rate cap was aliasing against ARKit's delivery clock.** Written
  as `1.0/30.0` = 33.3 ms, exactly twice ARKit's 16.7 ms period, it sat on a
  delivery boundary; jitter pushed frames just under it and deferred each a
  further 16.7 ms. Intervals were bimodal at 33 and 50 ms, averaging 22.8 fps
  against a 30 Hz cap. Threshold now 30 ms → **29.8 fps, unimodal**, a 31%
  throughput recovery at unchanged per-frame cost.
- **The log recorded timings and nothing about what was detected**, so a live
  report that the prototype was announcing `person` could not be answered from
  data. `LatencyLogger` now writes `tracks`, `confirmed`, `top_class`,
  `top_confidence`, `top_distance_m`, `top_urgency`, `top_level` per row.
- **The interface showed gated tracks without marking them**, so rows the
  announcement gate was suppressing read as things the prototype was saying.
  Now labelled, with confidence shown.

**The `person` question, settled with data.** `person` drove feedback in 64 of
3,855 frames (**1.7%**) — the second least frequent class. The impression came
from the interface: 1.23 tracks per frame against 0.92 confirmed, with 619
frames where the gate held back every track present. The code path was cleared
separately: replicating the device's exact preprocessing offline reproduced
Ultralytics' own classes and confidences, and swapping colour channels changed
confidence without changing any class. Written up as §4.3.5.

## Addendum, 18 September — screen-reader behaviour verified

The interface was made screen-reader navigable and checked on the device with
VoiceOver running.

- **The status card is one element speaking one sentence** — class, bearing,
  distance and closing rate — rather than nine separately-focusable fragments.
  Confirmed both in the accessibility tree
  (`ios/ObstacleAwareness/UITests/AccessibilityTreeTests.swift`, 5 tests
  passing) and by ear on the phone.
- **The preview, its box overlays and the frame-rate/thermal telemetry are
  hidden from the reader.** Confirmed on device: swiping from the top reaches
  the card without announcing "stopped", "nominal" or "Camera preview".
- Controls announce the action they perform ("Start detecting", "Speak nearest
  obstacle"), and the active tab and feedback condition carry the selected
  trait.
- Decorative glyphs inside labelled controls were announcing their SF Symbol
  semantics — the "Both" button read as "Hdr", the tab icons as "Radio" and
  "Speed". Hidden.

**A harness limitation worth knowing.** XCUITest cannot verify that something
is hidden from VoiceOver. `.accessibilityHidden(true)`, the same on the parent
container, and `.accessibilityElement(children: .ignore)` followed by hidden
all left the labels directly queryable and did not even merge them — yet on the
device none of them is announced. An earlier conclusion that this was a real
defect was drawn from XCUITest output and was wrong. Verify screen-reader
hiding on hardware, not from a test log.

This establishes the interface is navigable, not that it is usable: no blind or
visually impaired user has used this system. §5.5 item 10 states the
distinction.
