# CLAUDE.md — Indoor Obstacle Awareness Prototype

Context handoff. Drop this at the repo root; Claude Code reads `CLAUDE.md`
automatically at session start.

---

## 1. Project identity

**Albin Shajan** (M01097740), MSc Data Science and AI, Middlesex University
Dubai. Module CST4275. Supervisor: Dr. Ikram Ur Rehman.

**Title (proposal):** A Smartphone-Based Prototype for Indoor Obstacle
Awareness: Real-Time Object Detection, Distance Estimation, and
Audio-Haptic Feedback for Blind and Visually Impaired Users.

**Draft thesis due 20 September 2026** — confirmed by the user 2026-09-15
against the module guidelines deck ("Next Milestone: 20th September – Draft
Thesis"). The title-page template in the same deck is dated 1 October 2026 and
the signed ethics form gives a proposed end date of 5 October 2026.
`front_matter.md` now carries **1st October 2026**, matching the template.

**The deck is in the repo** (`docs/source_documents/dissertation_project_guidelines_extracted.md`)
and settles three things, read 2026-09-18: the Investigation/Research structure
on Slide 4 matches this thesis chapter for chapter, including "Appendices –
Ethics Forms" as a named section; submission is Report (with ethics forms) +
Code and Data (code compulsory, data optional) + Poster in person **or**
Recorded Presentation and viva; and the title-page date above.

**There is no word limit and no page limit — word limit confirmed by the user
2026-09-21, page limit 2026-09-26.** The deck never stated either (Slide 24's
"Appendices do not count towards the page limit" is its only reference to any
limit, with no figure attached, and no limit applies in practice). Length is not
a constraint in any form: do not cut material to save words or pages. The
manuscript is **~41,800 words excluding appendices** (counting table cells) after the 26 September pass against the supervisor's checklist — `docs/checklist_audit.md`; it was ~27,300 after the September 21-26
additions; per-chapter breakdown in `docs/thesis/README.md`.

**Superseded:** this file previously asserted a hard deadline of 15 September
2026 with the note "the Gantt chart in the proposal shows mid-October and is
obsolete — ignore it." That date had no documentary support and was wrong. It
is the reason Objective 4 was descoped on 11 September (see below).

### Scope, stated precisely

This is **obstacle awareness**, not navigation. It helps a user know *what*
is nearby and *how close*. It does not do path-following, route guidance or
wayfinding. It is positioned as a supplement to a white cane, never a
replacement. Evaluation with blindfolded sighted participants demonstrates
**technical feasibility only** — it is not usability evidence for blind or
visually impaired users, and must never be written up as such.

Hold this line in all generated text. The proposal and literature review
spend several pages defending it.

**Objective 4 is descoped — decision confirmed 2026-09-15, and this time on
sound reasoning.** The 11 September descoping was made on a wrong deadline
(15 vs 20 September). Revisited with the correct date, the answer is the same:
no participant evaluation. The governing reason is not the calendar but that
**n=5 across two conditions cannot answer RQ3** — it yields a demonstration,
not a result, and presenting it as evidence about a feedback modality would put
the thesis in the position Chapter 2 criticises the field for (small-sample
usability claims). The prototype is built and demonstrated instead.

**Consequence that must not be missed: Objective 3 now carries its own weight
alone.** With no participant data, the working prototype IS the evidence that
Objective 3 was delivered. **Built 2026-09-16** — the decision layer and Core
Haptics path are delivered, verified and running on the device
(`results/objective3_prototype.md`). Three objectives delivered, not two.

RQ3 and RQ4 are unanswered. Written up honestly in ch1 section 1.5, ch5
section 5.4 and ch6 section 6.5 item 1: approval obtained, protocol designed
and documented (ch3 section 3.2.4), study not run.

**Evaluation protocol decisions (user, 2026-09-15).** Participants **5**,
resolving the form's §2.6 (five) vs §3.1 (10–15) contradiction in favour of
five. Age **18+**. Location **on the MDX Dubai campus**. A sighted volunteer
beside each participant throughout, monitoring safety. **No audio, video or
photographic recording of participants at any point** — this resolves the
form's other contradiction (§2.6 says sessions will be video recorded, §4.11
is marked No) in favour of §4.11; measures are written notes, and collecting
less personal data than approved needs no amendment. Duration and dates not
yet fixed; duration needs a dry run before the recruitment message goes out.

**Status: the evaluation is NOT committed.** The recruitment message
(`docs/study/`) may go out to gauge interest without obliging anyone to run
the study. Chapters 1, 2, 4 and 5 state it was not conducted, which is true as
of now — do not rewrite them speculatively.

**Ethics record — closed items (user decision, 2026-09-15).** The blank
peer-reviewer and REC decision blocks are **not** to be treated as
outstanding; the supervisor's signed recommendation stands as the approval
record. No Change in Ethics Approval form is being filed for the Roboflow
training corpus. Chapter 3 still describes accurately which datasets were
actually used — that is methodology reporting, not an ethics action — but
drops the "amendment required" framing.

---

## 2. Objectives → research questions

| # | Objective | RQ |
|---|---|---|
| 1 | ~~Benchmark YOLO variants on accuracy, latency and computational cost~~ **done 2026-09-11** — `results/objective1_full_table.md`; confusion matrices / P / R / F1 at the app's 0.30 threshold added 2026-09-21 — `results/objective1_confusion_findings.md`, ch4 §4.1.7 | RQ1 |
| 2 | ~~Validate distance estimation against physical ground truth~~ **done 2026-09-16** — `results/objective2_findings.md` | RQ2 |
| 3 | ~~Build the smartphone prototype with dual audio + haptic feedback~~ **done 2026-09-16** — `results/objective3_prototype.md` | — |
| 4 | ~~Ethics-approved evaluation with blindfolded sighted participants~~ **descoped 2026-09-11 — not attempted, out of time** | RQ3 |
| stretch | Indicative comparison against Microsoft Seeing AI | RQ4 |

**Defensible contribution, in priority order.** Objectives 1 and 2 carry it;
protect them if something must be cut.

1. Distance error against **independently measured physical** ground truth
   (tape measure), which the reviewed literature does not do
2. **Joint** accuracy + latency + deployment-cost benchmark for indoor,
   mobile-only deployment
3. Isolating the **haptic channel's** contribution from audio in a
   controlled comparison
4. Explicit **feasibility vs usability** separation

**"Smartphone-only" is NOT the contribution.** DeepNAVI (Kuriakose et al.,
2023) and PathFinder (Das et al., 2025) are already smartphone-only and are
both in the review corpus. The proposal currently leads with this claim and
must be reordered.

---

## 3. Hardware and platform

- **iPhone 13 Pro Max**, iOS 26.5, A15 Bionic, 6 GB RAM, **LiDAR present**
- Mac with Xcode available
- Target: Core ML (`.mlpackage`), **not** TFLite

### Device constraints that shape results

- **LiDAR range ceiling ≈ 5 m.** Ground-truth captures run 0.5–4.5 m in
  0.5 m steps. Testing past 5 m produces an error cliff that looks like a
  bug but is a hardware limit. The ceiling is itself a reportable finding.
- **Cannot run detection + monocular depth at frame rate.** Run detection
  every frame; sample depth only inside detected boxes. ARKit `sceneDepth`
  is nearly free (60 Hz, sensor-driven); the monocular net costs real ANE
  time every frame. This gives RQ2 a real trade-off: **LiDAR wins latency,
  monocular wins device coverage.**
- **Thermal state, MEASURED 2026-09-16 — the ~10-15 min expectation this file
  used to assert was wrong by an order of magnitude.** The detector alone never
  left `nominal` across three runs of 13-24 min (Objective 1). The *full* assist
  pipeline — ARKit world tracking + LiDAR + Core Haptics + AVAudioEngine
  alongside the detector — reached `fair` in 56 s and `serious` in **121 s**.
  **The cost of `serious` is NOT established.** Run 2 (3.4 min) measured
  +3.3% frame time; run 3 (6.1 min, same build/device/model/condition) measured
  **+17.9%** — a 5.4x disagreement, with time-to-`serious` also varying 2.5x
  (121 s vs 308 s), which points at an ambient temperature neither run
  recorded. What holds across both: **30.0 fps throughout `serious`, zero
  dropped frames**, and latency rising. Do not quote a single percentage
  (`results/objective3/latency_findings.md`).
  Three consequences: report cold *and* sustained latency separately;
  **counterbalance feedback-condition order** or RQ3 measures heat rather than
  haptics, and the margin is far thinner than 10-15 min implied; and when
  comparing thermal states use **warm-phase frames only** — the naive
  all-frames comparison inverts the result, because the coldest window is also
  the least cache-warmed and that effect is larger and opposite in sign.
- **Free provisioning profiles expire after 7 days.** Participant sessions
  land on days 6–7. Re-run from Xcode the morning of each session day.

### LiDAR resolves an argument, at a cost

On an iPhone Pro, LiDAR is *built in*, not "additional hardware" — this
dissolves the contradiction between the accessibility rationale and using a
depth sensor. But §2.5.3 of the literature review criticises NaviSense for
requiring LiDAR/AR hardware. **That critique must be softened**, because it
is the same class of sensor.

---

## 4. Ethics — approved, with defects to manage

**Corrected 2026-09-15 against the real signed PDF
(`Albin-Ethics_updated_Signed-IR.pdf`).** The earlier note here — "no checkbox
carries a recorded answer (visible ticks are template defaults), and the
supervisor, peer-reviewer and REC decision blocks are blank" — was **wrong on
two counts**. The form is substantively complete: checkboxes throughout
sections 3–8 carry real answers, and the **supervisor block is signed**
(Dr Ikram Rehman, 11/08/2026, recommendation to REC "This is a low risk
project and all ethical, legal and safety issues have been sufficiently
addressed" = Yes). Researcher signed 08/07/2026. Proposed period 1 June –
5 October 2026.

What **is** genuinely blank: the **peer-reviewer assessment and decision**
(no name, signature, date or risk rating) and the **REC decision block**. The
form therefore evidences a supervisor recommendation, not a recorded approval
outcome. Still obtain the approval email or countersigned copy for the
appendix — but the reason is narrower than previously recorded.

### Three mismatches with the thesis

1. **Title/scope.** The approved form is titled "A Smartphone-Based
   Navigation **Assistant**"; §2.4 says "navigational aid system"; §2.6 has
   participants doing "navigation and obstacle avoidance tasks". Delivering
   narrower than approved is ethically fine, but Chapter 3 needs one
   sentence reconciling the two titles.
2. **Participant count contradicts itself.** §2.6 says five; §3.1 says
   10–15. Resolve with supervisor in writing before recruiting. 6–8 is
   realistic in the time available.
3. **Approved secondary sources are only two:** COCO, and researcher-
   collected indoor captures. NYU Depth V2, DIODE and the Roboflow indoor
   sets are **not** listed. The signed declaration requires a Change in
   Ethics Approval form for methodology alterations — send the supervisor a
   timestamped amendment note.

The tape-measure distance capture needs **no** amendment: §3.2 already
covers researcher-collected images in unoccupied indoor spaces with no
identifiable bystanders.

### Already covered by ethics

**RQ3 approves the audio-only vs audio+haptic comparison.** The condition
comparison is authorised — it just has to be built into the evaluation.
**The form contradicts itself on video recording** (confirmed 2026-09-15,
not merely a consent-sheet question): §2.6 states sessions "will be video
recorded", but §4.11 ("Will you audio or video record interviews and/or
observations?") is marked **No**, while §4.10 (consent from people appearing
in visual data) is marked **Yes**. Those three answers cannot all be correct.
Moot in practice since no session took place, but it needs explaining in
Chapter 3 rather than left for a reader to find — written up in
`docs/thesis/ch3_methodology.md` §3.2.3.

**The participant documents, found 26 September** in ~/Downloads and now in
`docs/source_documents/ethics_attachments/` (the submitted versions per the
researcher: 9 July information and consent sheets, 7 July debriefing sheet;
reproduced unedited as Appendix A.2–A.4). They add two inconsistencies, both in
§3.2.3: the **debriefing sheet still says "your video recording"** and carries
the old "Navigation Assistant" title, and the **information/consent sheets
promise a post-task questionnaire where form §2.6 says interview**; no
questionnaire or interview guide exists. `~/Downloads/Informed Consent Form.docx`
is another student's form (an AI-fatigue survey), not this project's.

---

## 5. Data

### The fork, and the decision taken

COCO has **no `door`, `stairs`, `pole` or `glass` class** — the highest-risk
indoor obstacles. Zero-shot Objective 1 is therefore impossible for exactly
the classes that matter. **Decision: fine-tune all three detectors** on the
merged indoor set (~2,700 images, nano models, ~50 epochs). Train on a free
Colab T4 (~30 min each); use the Mac only for Core ML export.

### Sources

| Source | Content | Licence |
|---|---|---|
| Roboflow indoor-objects (Lochan R) | 1,417 imgs, 10 classes incl. Door, Stairs, Person | CC BY 4.0 |
| AI Builders indoor-objects (Jaiinsom) | 1,349 imgs / 7,331 objects, door subtypes, pole | GNU GPL 3.0 |
| COCO val2017 | zero-shot baseline, indoor classes only | Annotations CC BY 4.0 |
| NYU Depth V2 (labeled/Eigen) | 1,449 imgs, 795/654, uint16 mm depth, **~2.8 GB (2,972,037,809 bytes, confirmed via HTTP HEAD on the file itself, 2026-09-07)** — not ~1.5 GB as originally estimated; internal array dtype/units still unverified, `prepare_data.py`'s `nyu` command assumes metres and has never been run against the real file | verify mirror |
| DIODE indoor val | 325 samples, FARO laser GT, ~99% density | MIT (Kaggle mirror) |
| **Own capture** | ~270 frames, tape-measured | researcher-owned |

### Own capture protocol

5 classes (door, chair, table edge, wall/pole, low obstacle) × 9 distances
(0.5–4.5 m) × 2 lighting × 3 reps ≈ 270 frames. Record RGB + ARKit depth +
confidence map. Chest height, level, consistent pitch — inconsistent pitch
is the biggest avoidable source of monocular error. Capture some glass
doors deliberately: they fail for both LiDAR and monocular, and that is
limitations material.

**The detector cannot see `pole`.** The merged corpus has zero `pole`,
`door_glass`, `handrail` and `other` instances (`results/dataset_report.md`)
because the AI Builders source — the only one carrying `pole` and door
subtypes — was never downloaded. So a `pole` capture can never get a
detector-predicted box of its own class. Shoot pole frames against a wall
segment or pillar so the trained `wall` class fires instead;
`taxonomy.CAPTURE_CLASS_TO_DETECTOR` encodes that substitution and
`predict_boxes.py` flags every frame where the detected class isn't the
photographed one. The gap is honest limitations material for Chapter 5 —
one licensed source being unobtainable cost the taxonomy its second-highest
hazard-weighted class.

**Distances are entered in millimetres** in the capture app's "Distance
(mm)" field — `2500`, not `2.5`. The four 7 Sept smoke-test frames on the
device use `d-1` and `d-2`, which parse as 1 mm and 2 mm of ground truth;
they must not reach `distance_eval.py`.

Filename convention (ground truth is parsed from it — no separate log):

```
obj-<class>_d-<mm>_light-<bright|dim>_rep-<n>.{jpg,depth.npy}
obj-door_d-2500_light-bright_rep-2.jpg
```

### Data preparation rules

- **Split by scene, not by image.** The Roboflow sets are frame-extracted
  from video; a random 80/20 split puts near-duplicates in both sides and
  inflates mAP meaninglessly. Split on source scene or filename prefix and
  state this in Chapter 3.
- **The captured distance set is never training data.** Held-out physical
  ground truth for Objective 2. Keep it in a separate directory tree.
- **Report per-class AP with instance counts.** The merged taxonomy is badly
  imbalanced; any class under ~50 instances yields noise. A single pooled
  mAP hides that `stairs` — highest consequence — is undertrained.
- Keep `person` in the taxonomy (it is a real indoor obstacle) but never
  persist frames containing people.

### Preprocessing — two distinct pipelines

**Offline (train/eval):** letterbox to 640 preserving aspect, ImageNet
normalisation. Augmentation limited to what a chest-held phone sees:
horizontal flip, modest brightness/blur, mild rotation. **No vertical
flip.** Mosaic and heavy scale jitter teach viewpoints the camera never
occupies.

**On-device (inference — this is measured latency):** `AVCaptureSession`
yields `CVPixelBuffer` in `420f` bi-planar YpCbCr → BGRA → resize →
letterbox. Two traps: pixel-buffer conversion done accidentally on the CPU
per frame, and device- vs image-orientation mismatch, which silently
rotates input and tanks accuracy while looking fine in the debugger. The
logger's `capture` stage exists to keep this cost visible.

**Depth:** ARKit `sceneDepth` is 256×192 and must be mapped into the RGB
frame before sampling inside a box. Filter by `ARConfidenceLevel` and
**discard** low-confidence pixels — glass and dark matte surfaces return
confident-looking garbage.

---

## 6. Models and licences

| Model | Role | Licence |
|---|---|---|
| YOLOv8n / YOLO11n / YOLO26n | detection candidates (Obj 1) | AGPL-3.0 |
| Depth-Anything-V2-**Metric-Indoor-Small** | monocular metric depth | **Apache-2.0** |
| MiDaS | second depth candidate | MIT |
| ARKit `sceneDepth` | LiDAR depth arm of RQ2 | platform |

- YOLO26 (Jan 2026) is NMS-free and materially faster on CPU. The proposal
  names only YOLOv8 and YOLO-NAS; comparing v8n/11n/26n is stronger and
  costs nothing since they share one API.
- **Only DAv2 Small is Apache-2.0.** Base/Large/Giant are CC-BY-NC-4.0 —
  do not substitute them.
- Ultralytics AGPL-3.0 means publishing the app source inherits copyleft.
  Fine for a dissertation; must be declared.
- DAv2 metric-indoor outputs **metres directly**, so MAE is computable
  without scale fitting. Run with `max_depth = 20`. Input side must be a
  multiple of 14 (518 = 14×37 reference; 392 and 322 are faster — benchmark
  them).

---

## 7. Derived-feature layer (Objective 3's real design artifact)

**BUILT AND VERIFIED, 2026-09-16.** `ios/ObstacleAwareness/Sources/Assist/`;
full record in `results/objective3_prototype.md`. Everything in the table below
is implemented. Four things about it that are load-bearing and easy to undo by
accident:

1. **The depth source is ARKit `sceneDepth`, chosen on Objective 2's numbers**
   (LiDAR 0.188 m MAE vs monocular 1.221 m), not assumed. Don't switch it to
   the monocular net for "device coverage" without re-reading §4.2.
2. **`FrameGeometry.landscapeROI(forPortrait:)` is a rotation, not an axis
   swap.** The detector works in the upright portrait frame; `sceneDepth` is in
   ARKit's landscape sensor frame. Dropping the flip mirrors every region and
   returns a plausible wrong number. Pinned corner-by-corner by
   `tools/verify_decision_layer.sh`.
3. **Urgency is `min(1, proximity + 0.35*ttc) * (0.6 + 0.4*hazard)`.** Do not
   "tidy" this into co-weights summing to 1 — that was the first version and it
   made the top warning band unreachable for a stationary user (stairs at 0.5 m
   scored "close", not "stop"). Do not make hazard a plain multiplier either: a
   chair 0.3 m from a shin is not a 0.3-urgency situation.
4. **`AVSpeechSynthesizer` stays out of the per-frame path** (button only).
   First-utterance latency is hundreds of ms against a ~13 ms pipeline.

Run `bash tools/verify_decision_layer.sh` after touching
`ObstacleDecision.swift`, `ObstacleTracker.swift` or `DepthSampler.swift`. It
caught two real defects while the layer was being written.

**~~Still unmeasured~~ — MEASURED 2026-09-16/17**,
`results/objective3/latency_findings.md`. Two live runs; run 2 (6,035 frames,
202.4 s, 29.8 fps) is the one to cite. Total **13.32 ms/frame**, of which the
whole decision layer is **0.066 ms** (0.5%, ~a hundredth of the detector);
`depthSample` 1.05 ms; buffer handling 43.6%, replicating Objective 1's 43% on
a separate code path. All five `LatencyLogger` stages populated, and the log now
also carries `tracks`, `confirmed`, `top_class`, `top_confidence`,
`top_distance_m`, `top_urgency`, `top_level` per row.

Two defects those runs exposed, both fixed: the 30 Hz cap was written as
`1.0/30.0` = 33.3 ms, *exactly* twice ARKit's 16.7 ms delivery period, so it sat
on a delivery boundary and jitter deferred every other frame — intervals came
out bimodal at 33/50 ms and the session averaged 22.8 fps. Threshold is now
0.030 s → 29.8 fps. And the log recorded timings but nothing about what was
detected, so a live "why is it saying person?" could not be answered from data.

**Still open:** the *magnitude* of the `serious` penalty, which two runs put
5.4x apart. Settling it needs ambient temperature recorded, a fixed route and
several runs per condition — a thermal-characterisation study, not another log.
`critical` was never reached. Chapter 6 §6.5 item 0.

There is no classical feature engineering on the input side — the backbones
learn their representations, and claiming otherwise is padding a Data
Science examiner will see through. The engineering sits **between the models
and the feedback**, and deserves its own Chapter 3 section.

| Feature | Derivation | Rationale |
|---|---|---|
| Object distance | median depth over box's **lower third** | floor-standing objects; box top catches background |
| Bearing zone | box centroid x → left/centre/right | audio panning, which side vibrates |
| Hazard weight | class → fixed weight (stairs > door > chair) | Khilnani & Devesh's prioritisation argument |
| Time-to-contact | distance ÷ closing rate (frame-to-frame tracking) | a 2 m object approached matters more than a static one |
| Urgency score | weighted combination of the above | the scalar the feedback encodes |
| Haptic encoding | urgency → (intensity, sharpness, pulse rate) | Core Haptics params — **this is the Obj 3 contribution** |
| Announcement gate | N-of-M temporal confirmation + hysteresis | without it feedback flickers on every dropped detection and is unusable |

Use **median**, not mean, when sampling depth: one background pixel bleeding
into the region wrecks a mean.

### Feedback implementation notes

- **Haptics:** Core Haptics, `CHHapticAdvancedPatternPlayer`, continuous
  playback with dynamic intensity/sharpness. iPhone 8+ only.
- **Audio:** do **not** put `AVSpeechSynthesizer` in the latency path —
  first-utterance latency runs into hundreds of ms and would swamp the
  pipeline latency being measured. Pre-render earcons via `AVAudioEngine`;
  reserve speech for object identity on demand.
- Three modes behind a toggle (audio-only / haptic-only / both) so RQ3's
  conditions are switchable, counterbalanced per participant.
- **VoiceOver — interface navigability VERIFIED on device 2026-09-18;
  channel contention still open.** Two things are done and checked: the audio
  session uses `.mixWithOthers` so the system cannot silence a user's screen
  reader, and the Assist interface is screen-reader navigable — the status card
  is one element speaking one sentence (class, bearing, distance, closing rate)
  and the preview, box overlays and fps/thermal telemetry are hidden from the
  reader. Confirmed by ear on the phone, not just in a test log.
  **Still a limitation:** mixing prevents silencing but not two audio streams
  competing for one listener, and no BVI user has used the system — so this is
  verified as *implemented*, never as *usable*. Written up in ch5 §5.5 item 10.
  **`ios/ObstacleAwareness/UITests/` holds 6 accessibility-tree tests; run them
  after touching AssistView, DetectView, RootView or Theme.**
- **XCUITest cannot verify that something is hidden from VoiceOver.**
  `.accessibilityHidden(true)`, the same on the parent, and
  `.accessibilityElement(children: .ignore)` + hidden all leave labels directly
  queryable and do not even merge them — yet the device announces none of them.
  A conclusion that this was a real defect was drawn from XCUITest output and
  was wrong. Check screen-reader hiding on hardware.

---

## 8. Existing harness

**All of this has now been run against real data on a real Mac and a real
device** — the "syntax-checked but never run" caveat this section used to carry
is long superseded. Objective 1 (three 13-24 min device runs), Objective 2 (102
tape-measured captures) and Objective 3 (two live pipeline runs, 45 off-device
checks) are all complete. `pandas` had to be installed into `.venv` for
`latency_report.py`; `pandoc` 3.11 and `librsvg` are installed for
`build_thesis.sh docx`/`pdf`.

```
tools/
  taxonomy.py         12-class taxonomy, hazard weights, per-source class-name maps — shared by prepare_data.py and distance_eval.py
  prepare_data.py
  export_coreml.py
  predict_boxes.py    detector boxes over the capture set -> the CSV distance_eval.py's --boxes-csv wants
  train_ablation.py   "what moves the numbers": YOLO26n retrained locally (MPS, ~6 h/run, same Ultralytics 8.4.147 + seed as Colab) one change at a time -- baseline / mosaic / coco / relabel / aib (+ s_ variants for YOLO26s). Weights -> data/processed/ablation/weights/. STARTED 2026-09-21; the checkpoints showed val box loss rising from epoch 1 = overfitting, so "train longer" is NOT one of the variants
  audit_spurious.py   splits the matcher's uncredited boxes into duplicate / other_class / partial / unannotated and samples the unannotated ones onto contact sheets. All verdicts in results/objective1_audit/ were CONFIRMED by the researcher 2026-09-26, sheet by sheet (rater column names them); the assistant's first pass was overturned on 2 of 47 detector boxes and 4 of 48 added labels, so cite the CSVs, not the earlier prose
  relabel_missing.py  fills missing person/chair/table labels in the TRAIN split only (YOLO26x COCO teacher, conf >= 0.5, no overlap >= 0.3 with any existing box) -> data/processed/relabel/. Val untouched
  import_ai_builders.py  Kaggle thepbordin/indoor-object-detection (GPL-3.0, downloaded 2026-09-21) -> data/processed/aib/, keeping its own splits; never re-merged into data/processed/merged, which would redraw the val split
  detection_metrics.py   Obj 1 at the operating threshold: confusion matrices, P/R/F1, threshold sweep, scene bootstrap, recall by COCO size band. Cross-checks Ultralytics val() against the Colab CSV first (reproduced to 4 d.p. 2026-09-21). Copies Figures 4.1-4.2 into docs/thesis/figures itself
  distance_eval.py
  distance_uncertainty.py   Obj 2 second pass (2026-09-26): bootstrap CIs, paired LiDAR-vs-mono, error by box placement (reads results/objective2/box_placement_audit.csv), monocular LOO recalibration, class mix per bin -> results/objective2/uncertainty.md + Figure 4.3
  check_citations.py   citations <-> bibliography both ways, and every numbered table/figure referred to in the text. Run after editing the thesis
  format_tables.py     build-time only: sets pipe-table column widths from content in build/thesis.md
  thesis_header.tex    LaTeX header for the PDF build (suppresses LaTeX's own caption numbers; the manuscript numbers its tables/figures itself)
  latency_report.py
  LatencyLogger.swift wired into ios/ObstacleAwareness (Benchmark/ and Assist/ both use it)
  verify_decision_layer.sh   compiles Objective 3's three pure decision-layer sources for macOS and checks geometry/scoring against planted values -- 45 checks, run it after touching any of them
  decision_layer_checks/main.swift   the checks themselves (must be named main.swift; Swift only allows top-level code there)
  requirements.txt
ios/ObstacleAwareness/
  project.yml            XcodeGen spec: target ObstacleAwareness, bundle com.albinshajan.obstacleawareness
  Sources/
    ObstacleAwarenessApp.swift   entry point, root view is CaptureView
    Assist/                Objective 3's prototype -- ARKit frame -> upright rotate -> detect -> sceneDepth -> derived features -> audio/haptic. The app's DEFAULT mode.
      ObstacleDecision.swift   bearing zones, hazard weights (mirror of taxonomy.py's HAZARD_WEIGHT), urgency function, and FrameGeometry -- the ONE place a coordinate space changes hands
      ObstacleTracker.swift    IoU association, least-squares closing rate over a 0.6s window, 3-of-5 announcement gate, asymmetric level hysteresis
      DepthSampler.swift       median sceneDepth over a box's lower third, ARConfidenceLevel.low discarded, stride-capped at 1500 samples
      HapticFeedbackEngine.swift   ONE looping CHHapticAdvancedPatternPlayer; intensity/sharpness are dynamic parameters (multiplier vs offset -- different semantics, easy to swap), pulse rate is loopEnd
      AudioFeedbackEngine.swift    PCM earcons rendered at start and panned by bearing; .mixWithOthers so VoiceOver survives; speech on a button only
      AssistController.swift   owns the ARSession, 30 Hz cap, per-frame pipeline, LatencyLogger with all five stages populated
      AssistView.swift         box overlay + a decision trace panel that breaks the urgency score into its terms -- this is what ch4 4.3's screenshots show
    Models/                yolov8n / yolo11n / yolo26n are the MEASURED detectors (every thesis figure). yolo26n_full and yolo26n_aib were added 2026-09-23 from the retraining experiments and are selectable in Assist/Detect for live comparison ONLY -- both draw boxes on empty corridor floor (`full` calls them `door`), see results/objective1_ablation_findings.md. Default stays yolo26n; DetectorVariant.isMeasured marks the difference in the UI
    Detect/                detection only, added 2026-09-21 -- every box the detector returns (class + confidence, adjustable threshold), no depth/gating/feedback. AROrientationTrackingConfiguration: same 1920x1440 frame and rotation as Assist, but no LiDAR and no world tracking. Logs nothing -- not a measurement instrument. Installed and checked on the phone 2026-09-21 by eye (boxes on objects, edge detections, threshold, speech, stop); no figure comes from it. Described in ch4 §4.3.1
      DetectController.swift   ARSession -> upright rotate -> letterbox -> Core ML -> parse; mirrors AssistController's prep/parse deliberately rather than refactoring the measured instrument
      DetectView.swift         preview sized to the frame's own aspect (nothing cropped), box overlays, one-sentence status card, per-frame list, threshold slider, class list with training counts from results/dataset_report.md (duplicated like HazardWeight -- change both)
    Capture/               the ground-truth capture app (PROMPT.md Stage 2) -- field-tested 2026-09-16, produced the 102 frames behind Objective 2
      CaptureView.swift        main screen: AR preview, reticle, class/lighting/distance controls, coverage grid, export sheet
      ARCaptureController.swift   owns the ARSession, publishes latest frame + pitch-deviation-from-session-start + thermal state
      CaptureStore.swift       owns Documents/Captures; rep numbers and coverage counts are derived by scanning filenames, not separately tracked state
      FrameWriter.swift        writes the four sidecar files per frame; see its header comment for the RGB/depth orientation decision
      NPYWriter.swift          hand-rolled NPY v1.0 writer (float32 depth, uint8 confidence) -- no numpy dependency needed on-device
      CaptureMetadata.swift    ObstacleClass/LightingCondition enums -- must stay in sync with tools/taxonomy.py's CAPTURE_CLASSES
      CoverageGrid.swift, ARPreviewView.swift, DirectoryExporterView.swift, CaptureError.swift
  ObstacleAwareness.xcodeproj   generated by `xcodegen generate`, do not hand-edit -- edit project.yml instead
data/           gitignored -- captures and downloaded datasets
docs/source_documents/   the signed ethics PDF, the guidelines deck, the submitted proposal and lit review, the proposal Gantt -- COMMITTED 2026-09-18 (Appendix A had promised the ethics form since the first draft while the file sat only in ~/Downloads). No git remote exists, so the two real signatures stay on this machine; decide deliberately before adding one
results/        generated tables/figures, plus participant-study CSVs (gitignored)
```

| File | Purpose |
|---|---|
| `export_coreml.py` | 3 detectors + DAv2-S → `.mlpackage`; manifest of params/size/licence. Normalisation baked into the traced depth graph, not approximated via Core ML's scalar `scale`. **Both export paths verified for real** (2026-09-08 depth, 2026-09-11 detectors with the actual fine-tuned weights) — see section 8's detail notes for the bugs found and fixed, and the 80-vs-12-column output quirk |
| `prepare_data.py` | merge sources → 12-class taxonomy; COCO converter; NYU pair manifest; emits `provenance.csv` and a scene-level `results/split_manifest.csv` |
| `dataset_report.py` | Stage 3.3: per-class instance counts (train/val/test_zeroshot), image-size and box-area distributions, flags any class under 50 instances → `results/dataset_report.md` |
| `train_colab.ipynb` | Stage 3.4: fine-tunes yolov8n/yolo11n/yolo26n with identical hyperparameters (no vertical flip, no mosaic), saves per-class AP. **Run for real twice now** (2026-09-08 and 2026-09-11; the notebook set no seed, so **both used Ultralytics' default seed 0** with deterministic mode — confirmed from the checkpoints' `train_args` on 2026-09-26. They are repeat runs of one configuration, NOT independently seeded; do not write that two runs rule out a favourable initialisation) — results in `results/objective1_train_metrics.csv` (holds run 2) / `results/objective1_accuracy_table.md` (both runs): yolo26n wins pooled mAP50-95 in both runs (0.164 and 0.170 vs ~0.12-0.13 for the other two) and most classes both times — two independent runs now support this, not one. Absolute mAP is low in both. **Correction 2026-09-11:** an earlier note here claimed `person` is "unexpectedly the weakest class for every model" — checked against both runs' actual numbers and that's wrong; `chair` is weakest in 4 of 6 (model,run) combos, `person` in 2 of 6. Corrected finding: `person` and `chair` are consistently the two weakest classes, not `person` alone — see the accuracy table for the full corrected write-up. **`finetuned_weights.zip` recovered, 2026-09-11 — real cause was an outdated notebook, not a browser block.** The Colab tab was running an old copy of `train_colab.ipynb` from before the weights-saving cell was added, so it only ever downloaded the metrics CSV — no retrain needed once caught, since Ultralytics saves `best.pt` under `runs/detect/<model>/weights/` regardless: a small ad-hoc cell (glob + zip + download, not part of the committed notebook) pulled the still-live Colab session's existing checkpoints without spending any more GPU time. Real fine-tuned weights now at `data/raw/finetuned_weights/{yolov8n,yolo11n,yolo26n}.pt` and exported to Core ML — see section 8's export detail note |
| `detection_metrics.py` | Obj 1, operating point. yolo26n at conf > 0.30: P 0.438, R 0.206, micro F1 0.280, classification accuracy 0.89 -- **errors are misses, not confusions**; recall ceiling 0.41 at any threshold. Lead over both others survives a paired scene bootstrap; the 84-image unaugmented subset is too small to separate any pair. Matching reuses Ultralytics' own `ConfusionMatrix` -- do not swap in a reimplementation. `--skip-crosscheck` reuses cached predictions (`data/processed/detection_metrics_cache/`) |
| `predict_boxes.py` | Obj 2. Runs a fine-tuned detector (default yolo26n, the Objective 1 winner) over the capture set → `filename,x1,y1,x2,y2,img_w,img_h,expected_class,detected_class,confidence,match` plus a coverage report. Loads frames via PIL, not cv2, so EXIF orientation is never applied and boxes stay in the same unrotated sensor frame as the `.depth.npy` |
| `distance_eval.py` | Obj 2. MAE/MAPE/RMSE/bias by method, 0.5 m bin, class, lighting. `--run-monocular` generates DAv2 predictions |
| `LatencyLogger.swift` | on-device per-stage timings + `thermalState` + cold/sustained split → CSV |
| `latency_report.py` | Obj 1 latency table + throttling plot from those CSVs |

**Latency must be measured on the phone.** Core ML prediction on macOS uses
the Mac's Neural Engine and describes nothing about the A15. Never quote
Mac-side timings.

**This Mac's network egress is allowlisted, not open** (checked
2026-09-07): `github.com`, `pypi.org`, `files.pythonhosted.org` all resolve
and connect normally, but `images.cocodataset.org` fails TLS verification
in a way that matches a proxy blocking an unlisted host ("no alternative
certificate subject name matches"), not a transient network issue —
retrying won't fix it. Don't assume a source is downloadable from this
Mac just because generic connectivity checks (e.g. to github.com) succeed;
verify the specific host. COCO val2017 needs to be downloaded by hand, same
as Roboflow and Kaggle.

**Core ML export — both paths verified for real, 2026-09-08.** Ran
`export_coreml.py --targets yolov8n` (pretrained COCO weights, since the
Colab-fine-tuned weights weren't downloaded from that run — `train_colab.ipynb`
now saves them too, see below) — real `.mlpackage`, correct params/size in
the manifest. Then `--targets depth` at input-size 392, using the real
checkpoint (`depth-anything/Depth-Anything-V2-Metric-Hypersim-Small` on
HuggingFace — this is CLAUDE.md's "Indoor" model; "Hypersim" is the
synthetic indoor dataset it's trained on, same Apache-2.0 checkpoint, just
a different repo name than assumed) and the real `DepthAnything/Depth-Anything-V2`
repo. Two real bugs found and fixed in `export_coreml.py`:
1. `load_depth_anything_v2()` imported from `<repo_dir>` — wrong. The metric
   variant is a genuinely different `DepthAnythingV2` class (sigmoid +
   max_depth scaling head) living in `<repo_dir>/metric_depth/depth_anything_v2/dpt.py`,
   not the repo root's relative-depth-only class of the same name. Now
   imports from `<repo_dir>/metric_depth`.
2. Tracing failed with `NotImplementedError: ... 'upsample_bicubic2d' ...`
   — coremltools 9.0's PyTorch frontend has no converter for that op,
   independent of `minimum_deployment_target` (tried iOS16 and iOS17, same
   error either way). The only bicubic call in the model is DINOv2's
   positional-embedding resize (`interpolate_pos_encoding` in
   `metric_depth/depth_anything_v2/dinov2.py`) — a smooth low-frequency
   resize, not image content, so `export_depth()` now monkey-patches
   `F.interpolate` to substitute bilinear for bicubic *during tracing only*.
   Numerically sane after the fix: real prediction on a COCO image gave
   depth min/max/mean 1.9 m / 10.5 m / 5.2 m, zero NaNs.

**Real fine-tuned detector weights exported, 2026-09-11.** Two independent
Colab runs' `finetuned_weights.zip` finally recovered (see `train_colab.ipynb`
status below for why this took a while) and exported to
`data/processed/coreml_export/{yolov8n,yolo11n,yolo26n}.mlpackage` via:
```
python3 tools/export_coreml.py --targets yolov8n yolo11n yolo26n \
  --weights-dir data/raw/finetuned_weights --output data/processed/coreml_export
```
Verified against a real Roboflow validation image, cross-checked against
the same image run through the raw `.pt` via Ultralytics directly — same
class, same box, matching confidence (0.77 vs 0.76, small NMS/quantization
difference, not a discrepancy).

**Non-obvious quirk worth knowing before writing the on-device inference
code (Stage 6):** the exported `.mlpackage`'s raw `confidence` output is
shape `(num_detections, 80)`, not `(num_detections, 12)` — Ultralytics'
CoreML NMS-export path always allocates 80 confidence columns regardless
of the model's actual class count (looks like a fixed template inherited
from the COCO export path, not something `export_coreml.py` controls).
This is NOT a correctness bug: verified the real class confidence always
sits within the first `nc` (12) columns, matching the model's own `names`
metadata and the raw `.pt` predictions exactly; columns 12-79 are
near-zero padding that never wins an argmax in testing. Whoever writes the
Swift inference code needs to read the metadata's `names` dict (12 entries)
and slice `confidence[:, :12]` — reading the full 80-wide array or
assuming its width equals `nc` will silently break.

Reproduce with: `data/external/Depth-Anything-V2` (cloned repo) and
`data/raw/pretrained_weights/depth_anything_v2_metric_hypersim_vits.pth`
(99 MB checkpoint) are both in place locally (gitignored). Real export
output lives in `data/processed/coreml_export/` (also gitignored — the
manifest there is the reproducible record, not the binary files):
```
python3 tools/export_coreml.py --targets depth \
  --depth-checkpoint data/raw/pretrained_weights/depth_anything_v2_metric_hypersim_vits.pth \
  --depth-repo data/external/Depth-Anything-V2 \
  --input-size 392 --output data/processed/coreml_export
```
**All three input sizes (322/392/518) now exported and verified** — see
`results/depth_input_size_benchmark.md`: params and `.mlpackage` size are
essentially flat (~49 MB regardless of resolution, as expected — same
weights), Mac-side `predict()` timing (informational only, not a device
latency claim) scales roughly with resolution² as a ViT backbone would
predict. Still open: this used pretrained COCO detector weights for the
yolov8n export, not the real fine-tuned indoor ones (see
`train_colab.ipynb` status above) — the depth model itself has no
"fine-tuned" version to swap in, it's used as-is.

**Objective 2 chain built and verified end-to-end, 2026-09-14** — against a
synthetic frame (a merged-set image upscaled to the capture app's real
1920×1440, with a depth map whose values were planted at a known distance),
because no real tape-measured captures existed yet. Mechanically correct end
to end: `predict_boxes.py` → `boxes.csv` → `distance_eval.py` → `results_long.csv`
+ `results_summary.csv` with all four groupings populated. **Do not read the
monocular number from that test as a result** — the ground truth was
invented and the image was an upscaled 416×416 photo.

Two real bugs found and fixed in `distance_eval.py` doing it:

1. **ROI coordinate space.** Detector boxes are in RGB pixels (1920×1440) but
   ARKit `sceneDepth` is 256×192, and the monocular map is at full RGB
   resolution — the same pixel box was applied to both. Every ROI is now
   converted to fractions of the frame on load (`to_fractions`) and back to
   pixels per depth array (`to_pixels`). **This mattered more than it
   sounds:** pre-fix, every detector-boxed frame clipped to an empty region
   and returned `None`, logged as *"no valid LiDAR pixels (possibly beyond
   the ~5 m LiDAR range ceiling)"*. Objective 2 would have produced a
   plausible-looking hardware finding out of a coordinate bug. Verified by
   planting a known 2.5 m region and recovering MAE exactly 0.0, including
   the `ARConfidenceLevel` filter correctly discarding a planted
   low-confidence 0.05 m patch.
2. **Monocular preprocessing squashed the aspect ratio.** The old path
   resized the frame to `input_size × input_size`, compressing a 4:3 capture
   25% horizontally before a *metric* depth model saw it. Now delegates to
   the checkpoint's own `infer_image`, which is aspect-preserving
   (`keep_aspect_ratio=True`, `ensure_multiple_of=14`, `lower_bound`,
   bicubic) and interpolates the depth back to source resolution. **Open
   consistency question for Chapter 3:** the Core ML exports were traced at
   square input sizes (322/392/518), so the on-device model still takes a
   square input while the offline evaluation no longer does. Either re-export
   at a non-square size or state the difference explicitly — don't leave it
   unmentioned.

Note `image2tensor` selects cuda/mps/cpu itself, so `distance_eval.py` moves
the weights to match (mps on this Mac) or the forward pass dies on a device
mismatch.

**Objective 2 run for real, 2026-09-16 — done.** 121 raw captures pulled off
the device; cleaned to 102 (7 stray smoke-test frames at bogus distances
like `d-1`/`d-50`, and 12 practice shots at `door@1000` before the real
ones, excluded but preserved in
`data/raw/own_capture/_excluded_smoketest_or_practice/`; 12 frames where
the distance field wasn't updated before the next distance was shot are
relabeled to their true distance — full audit trail in
`data/raw/own_capture/_correction_log.txt`). Bright lighting only — a dim
session wasn't completed in the time available, and rather than fake it by
darkening the bright frames (asked for directly, declined — see this
session's transcript), it's reported honestly as untested. Full result:
**`results/objective2_findings.md`.**

Headline: **on detector-driven boxes only** (the fallback ROI numbers are
explicitly not citable, per the rule below) — LiDAR MAE 0.188 m (16.1%
MAPE), door alone 0.077 m (4.3% MAPE, a genuinely strong number); monocular
MAE 1.221 m (69.7% MAPE), ~6.5x worse. **The real bottleneck wasn't depth
accuracy, it was detector coverage**: `predict_boxes.py` (yolo26n) found a
box in only 38/102 frames (37%) — `pole` and `low_obstacle` essentially
never fired their own class (0/22 each), consistent with the corpus gap
already on record below (`pole` has zero training instances). This is a
real domain-gap finding worth its own Chapter 5 paragraph, not something to
smooth over: the detector trained on Roboflow's photography doesn't
transfer cleanly to the researcher's own capture conditions.

`read_names()` handles two Roboflow `data.yaml` layouts; a
third will report "no names found" rather than silently emitting empty
labels. `taxonomy.py`'s `SOURCE_CLASS_MAPS` raw class names are seeded from
the proposal's prose, not from the actual downloaded `data.yaml` files
(Roboflow/AI Builders need account credentials this environment doesn't
have) — verify them against the real files before the first
`prepare_data.py merge` run. `distance_eval.py` falls back
to a centred-ROI heuristic when no `--boxes-csv` is given; don't cite
numbers from that fallback — generate the boxes with `predict_boxes.py`
first.

**Frames MUST be rotated upright before detection** (`tools/orientation.py`,
2026-09-15). The capture app stores pixels in ARKit's unrotated sensor frame
with EXIF orientation 6, so a portrait-held phone yields a scene lying on its
side — out of distribution for the upright training corpus. Measured on real
capture output: the detector found **0 boxes in 4 object-aimed frames as
stored, 4 of 4 once rotated**, a chair going from nothing to 0.96 confidence.
`predict_boxes.py` detects on the upright frame and writes boxes in upright
pixel space; `distance_eval.py` rotates the depth and confidence maps to
match. Do not "simplify" this by removing the rotation — it is the difference
between having detector-driven distance numbers and having only the
uncitable fallback.

---

## 9. Write-up defects — all closed but one (audited 2026-09-18)

This section used to list fourteen open defects carried from the proposal and
the original literature review. **Every one has been closed except a single
item that cannot be closed without the researcher's own records.** Audited
against the actual text on 18 September, not assumed.

### THE ONE OPEN ITEM

**§2.2 has no search dates and no screening counts.** The chapter states the
databases and the inclusion criteria but not (a) when the searches were run and
(b) how many records were screened against how many retained. These are facts
about how the review was conducted and can only come from the researcher's
search log. **Do not estimate them** — an invented screening count in a
methodology section is a fabrication, not a rounding. A `VERIFY` note sits at
that point in `ch2_literature_review.md` and `build_thesis.sh` flags it.

### Closed, with where each was resolved

| Defect | Resolution |
|---|---|
| Figure 2.1 said 18 sources / 9-6-3 against the text's 14 / 6-6-2, and mislabelled Table 2.2 | Figure regenerated 15 Sept; record in `source_verification.md` |
| Domain C gap assigned to Objective 3 in §2.5.3 vs Objective 4 in Table 2.2 | Objective 4 throughout; the note recording the discrepancy removed 18 Sept |
| Novelty ordering led with "smartphone-only" | Claim **withdrawn** — §5.4.1, §6.1, abstract. DeepNAVI and PathFinder predate it |
| Register collapsed from §2.5.3 onward | Chapter 2 redrafted end to end 15 Sept |
| Evaluation described in past tense | All chapters state it was not conducted |
| §2.5.4's unintelligible 44% sentence; "Crivello et al. Looked at" | Figure removed as unverifiable; Domain D rebuilt on the survey's own findings |
| §2.3 paragraph 1 had zero citations for the 1990s-2000s era | Now carried by Crivello et al. (2026) |
| Lokhande (2024) int8 claim on a Scopus-delisted venue | Magnitude no longer relied on; the general claim is attributed and the venue's status stated in the text |
| Chaudary et al. cited as vol. 27 (2021) | **2023** throughout, bibliography included |
| Chaudary Domain C → D? | **Resolved 18 Sept: keep in C.** Discussed substantively in both §2.5.3 and §2.5.4, so moving only the table row would have created a new inconsistency. Table 2.1 records *primary* contribution; the caption now says so |
| No latency threshold for a walking user | Not inventable — written up as a **gap in the field**: §4.1.6, §5.2.6, §6.5 item 3. Objective 1 reports a distribution and grades nothing |
| No discussion of indoor obstacle datasets in Domain A | COCO's class coverage is now discussed in §2.5.1 via Okolo, and the full argument is §3.3.1 |
| Seven unverified figures (91.70%, 71.7% mAP, 96.3% @ 8 fps, 81.3%, PathFinder 73/80%, Vis-Assist) | Six confirmed with three descriptions corrected, one removed — full record in `docs/thesis/source_verification.md` |

### A tooling defect found during this audit, worth remembering

`build_thesis.sh` reported a clean thesis while three editorial notes sat in
Chapter 2. Its detector matched an allow-list of note prefixes
(`VERIFY|To be completed|Provisional|Status:|Stub|Regenerated`) and the three
real notes opened "To add", "Consider" and "Note on". **An allow-list of
prefixes can only catch the note styles someone already thought of.** It now
flags every blockquote, since the thesis uses blockquotes for nothing else.
The general lesson: a check that can only fail in ways you predicted will
report success you have not earned.

## 9b. Remaining work

`docs/remaining_work_checklist.md` (23 September) is the live list: what blocks,
what must happen before submission, what is optional, and what is verified done.
Read it before starting anything; update it rather than duplicating it here.

## 9a. Session handoffs

**Objective 2 facts corrected 2026-09-26 — do not reintroduce the old ones.**
Of the 38 frames with a detector box, 12 are named with the photographed
class, but the placement verdicts **confirmed by the researcher on 26 September**
(`results/objective2/box_placement_audit.csv`) put only **30 on the photographed
object** — 11 correctly named (all doors) and 19 under another name (13 chair
backrests as `window`, 6 doors as `wall`) — and **8 not on it**: all four
table-edge boxes (#12, #32–34, overturned by the researcher: they cover the
whole table, not the edge measured to) plus one chair frame and three
low-obstacle frames. "The detector located the object in 37 % of frames" is
wrong; say "returned a box in 37 %, a box on the object in 29 %, a correctly
named one in 11 %". LiDAR MAE on boxes on the object 0.113 m (CI 0.083–0.145);
on correctly named door boxes 0.063 m. LiDAR MAE 0.188 m over all 35 boxed
frames has 95 % CI 0.122–0.264; LiDAR beats
monocular in 35/35 paired frames. **The "LiDAR improves with range" pattern is
a class-mix artefact** (table edges only at 0.5–1.0 m; door error does not fall
with range) — never write it as a range effect. Monocular over-estimates in 38/38
with r = 0.98 (estimate ≈ 1.19 × truth + 0.77 m); a leave-one-out linear
recalibration gives 0.224 m — exploratory, post hoc, not deployable. LiDAR
over-estimates chairs in every frame (the box is on the backrest, behind the
front edge, and the lower third sees the wall through the slats); the table
boxes missed the edge entirely; doors are unbiased.

- `docs/checklist_audit.md` — **26 September, latest.** The thesis audited item
  by item against the supervisor's checklist and revised; the nine corrections
  of fact it made; and the six things only the researcher can do.

Dated session records live in `docs/`. Read the most recent before acting —
they carry what changed, what was decided and why, and which older notes in
this file were found to be wrong.

- `docs/session_2026-09-26.md` — **most recent session record.** The detector measured at its
  operating point (§4.1.7), the annotation audit, seven retraining runs, and the
  finding that the best benchmark model calls corridor floor a `door` — so the
  app keeps the measured model. Also lists five mistakes made and how each was
  caught.
- `docs/session_2026-09-18.md` — Build script was
  under-reporting editorial notes (three were hiding in Chapter 2, all now
  closed); guidelines deck found and committed, which settles the title-page
  date and confirms no page limit is stated; source documents added so
  Appendix A points at a real file; Dynamic Type defect in the new UI fixed.
  What genuinely remains is listed there.
- `docs/session_2026-09-16.md` — Objective 2 run for real on
  102 tape-measured frames, Objective 3 built/verified/installed, Chapters 3-6
  and the abstract updated. What still needs the user is listed there.
- `docs/session_2026-09-15.md` — thesis drafted end to end, Objective 4 settled
  as descoped on methodological grounds, Chapter 2's figures verified against
  sources (one removed), ethics record corrected, capture-app tilt measure
  verified on-device.

---

## 10. Immediate next actions

1. **~~Hello-world onto the phone~~ — done.** `ios/ObstacleAwareness/` is an
   XcodeGen project (`project.yml` + `Sources/`) building and running
   `ObstacleAwareness.app` on the paired iPhone 13 Pro Max, free-ID signed.
   Signing/build notes: Xcode's "Personal Team" account cache is stale —
   the live free team is `YOUR_TEAM_ID` ("Apple Development: YOUR_APPLE_ID"),
   not the `YOUR_TEAM_ID` team `defaults read com.apple.dt.Xcode` reports.
   `-allowProvisioningUpdates` resolves this automatically; `project.yml`'s
   `DEVELOPMENT_TEAM` doesn't need to match exactly. Physical device
   destination for `xcodebuild`: `platform=iOS,id=YOUR_DEVICE_UDID`.
   First install on a device needs a one-time manual trust: Settings →
   General → VPN & Device Management → Developer App → Trust. Rebuild
   command:
   ```
   cd ios/ObstacleAwareness && xcodegen generate && \
   xcodebuild -project ObstacleAwareness.xcodeproj -scheme ObstacleAwareness \
     -destination 'platform=iOS,id=YOUR_DEVICE_UDID' -allowProvisioningUpdates build && \
   xcrun devicectl device install app --device YOUR_DEVICE_UDID \
     "$(xcodebuild -project ObstacleAwareness.xcodeproj -scheme ObstacleAwareness \
        -destination 'platform=iOS,id=YOUR_DEVICE_UDID' -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d"/"n}')" && \
   xcrun devicectl device process launch --device YOUR_DEVICE_UDID com.albinshajan.obstacleawareness
   ```
   The free provisioning profile expires after 7 days — just re-run this.
2. **Two emails:** supervisor (ethics amendment + participant count), and
   recruiting 6–8 people for days 6–7. Recruitment is the one task that
   cannot be compressed.
3. **Start downloads — in progress, 2026-09-07.** User provided Kaggle
   (`[removed]`) and Roboflow API credentials, stored at `~/.kaggle/kaggle.json`
   and `~/.roboflow_api_key` (outside the repo, gitignored either way).
   Status:
   - **COCO val2017 — done, verified, and cross-checked against the
     official host.** `images.cocodataset.org` is blocked by this Mac's
     sandbox proxy regardless of credentials, so initially fetched via
     Kaggle mirrors instead: images from `xthink/coco-2017-val-images`
     (5,000 files, confirmed against the official count) into
     `data/raw/coco/val2017/`; annotations cherry-picked as a single file
     (`-f coco2017/annotations/instances_val2017.json`) from
     `awsaf49/coco-2017-dataset` into `data/raw/coco/annotations/`. The
     user separately downloaded the official `images.cocodataset.org`
     zips directly (their Mac isn't behind this sandbox's proxy) to
     `~/Downloads/{val2017,annotations}` — MD5-checked against the Kaggle
     copy: `instances_val2017.json` and three sampled images are byte-for-byte
     identical. The mirror wasn't just "probably fine", it's now confirmed
     the primary-source bytes. Original verification —
     verified 5,000 images / 36,781 annotations / 80 categories.
   - **Roboflow indoor-objects (Lochan R) — downloaded and merged.**
     Confirmed via the Roboflow API that
     `lochan-r-ugnn4/indoor-objects-detection-h2mgz` is the exact source
     (1,417 images, CC BY 4.0, 10 classes matching CLAUDE.md's table exactly
     — though the actual class names are Bed/Chair/Couch/Door/Person/
     Stairs/Table/Toy/Wardrobe/Window, not the earlier guessed Wall/Pole/
     Handrail/Other; `taxonomy.py`'s `SOURCE_CLASS_MAPS` is now corrected
     against the real `data.yaml`, with Bed/Couch/Toy → `low_obstacle` and
     Wardrobe → `wall` as judgment calls worth reconsidering for Chapter 3).
     Downloaded version 1 in YOLOv8 format to `data/raw/roboflow_lochan/` via
     the `roboflow` pip package.
     1. **Directory layout mismatch — fixed.** The real export splits into
        `train/{images,labels}`, `valid/{images,labels}`, `test/{images,labels}`
        (plus `data.yaml`), not the flat `images/`+`labels/` layout
        `prepare_data.py`'s `remap_source()` originally assumed.
        `discover_images()` now pools all three (falling back to a flat
        layout for sources that use one) since we redo the split by scene
        ourselves regardless. `prepare_data.py merge --source
        roboflow_lochan=data/raw/roboflow_lochan --output data/processed/merged`
        and `prepare_data.py coco --annotations
        data/raw/coco/annotations/instances_val2017.json --images
        data/raw/coco/val2017 --output data/processed/merged` both ran
        clean against the real data (zero unmapped classes) — kept/dropped
        class tables are in `results/stage3_class_report.md`.
     2. **This export's augmentation isn't ours — turned out to be a
        non-problem, verified rather than assumed.** The Roboflow version
        applies 3x augmentation (vertical flip + 30° rotation) to its own
        train split only (raw project 1,417 images / 992 train → exported
        train 2,967 = 992×3, valid/test unchanged at 283/142). I'd
        originally assumed the exported filenames (`<id>_jpg.rf.<hash>.jpg`)
        gave no way to trace an augmented copy back to its original, making
        near-duplicate leakage across our scene split a real risk — that
        assumption was wrong. Checked directly: the `<id>` before `_jpg.rf.`
        **is** Roboflow's stable per-original-image identifier, shared by
        all augmented copies of the same source photo (confirmed by listing
        all three copies of one original — same `<id>`, three different
        `.rf.<hash>` suffixes, all three in `train/`). `scene_id_for()`'s
        default regex already strips exactly the `_jpg\.rf\.[0-9a-f]+`
        suffix, so augmented copies already land in the same scene and
        therefore the same split — confirmed against the real merge (1,417
        unique scenes, exactly matching the raw image count). The "no
        vertical flip" policy conflict is still real for
        `train_colab.ipynb` to handle (don't re-use Roboflow's own flipped
        copies as if they were natural viewpoints when writing that
        notebook), but the leakage risk itself is resolved, not open.
   - **NYU Depth V2 labeled — failed, not retried.** Direct link
     (`horatio.cs.nyu.edu/mit/silberman/nyu_depth_v2/nyu_depth_v2_labeled.mat`,
     ~2.8 GB) is reachable and needs no credentials, but the transfer died
     partway (curl exit 56, connection interrupted) — likely just needs a
     resumable retry (`curl -C -`). **Disk space is tight on this Mac: only
     ~6 GB free** (`/System/Volumes/Data` at 99% capacity) — confirm there's
     room, or download to external/cloud storage, before retrying a 2.8 GB
     file. The official train/test split file's URL is unverified (a
     guessed path 404'd) — `prepare_data.py`'s `--splits` is optional and
     falls back to `unsplit` if you don't track it down.
4. **~~Build the capture app~~ — built and verified against a real
   on-device capture (2026-09-07).** Class picker matches
   `tools/taxonomy.py`'s `CAPTURE_CLASSES` (door, chair, table_edge, pole,
   low_obstacle); refuses to capture without a distance value. Files land
   in the app's Documents/Captures folder, exportable via the in-app
   "Export captures" button (Files/AirDrop/iCloud Drive), directly through
   the Files app, or pulled straight off the device from the Mac:
   ```
   xcrun devicectl device copy from --device YOUR_DEVICE_UDID \
     --domain-type appDataContainer --domain-identifier com.albinshajan.obstacleawareness \
     --source "Documents/Captures" --destination <local dir>
   ```
   Confirmed on a real capture (`obj-door_d-1_light-bright_rep-1` etc.):
   rep-counter auto-increments correctly across repeat captures of the same
   class/distance/lighting; `.depth.npy` loads in `numpy.load()` as
   float32 (192, 256) with plausible reticle (centre-pixel) readings and
   zero NaNs; `.conf.npy` loads as uint8 restricted to `{0,1,2}` matching
   `ARConfidenceLevel`; `.json` intrinsics/resolutions are internally
   consistent (1920×1440 RGB vs 256×192 depth, same aspect ratio, so the
   depth↔RGB pixel mapping is a clean ratio with no rotation math needed).
   Camera permission prompt and grant also confirmed working.

   Still unverified / worth a second look:
   - **Pitch/roll semantics.** The test capture's roll was ~‑91° to ‑93°,
     close to ±90° — could just be how the phone was held for a quick
     smoke test, or could mean the assumed eulerAngles axis ordering
     (pitch=x, yaw=y, roll=z) or the pitch-deviation-from-session-start
     design (see `ARCaptureController.swift`'s header comment) doesn't mean
     what it's assumed to mean. Check this on a real, carefully-held
     capture before trusting the pitch-deviation HUD warning during actual
     data collection.
   - **`frame.exposureDuration`/`.exposureOffset`** aren't on `ARFrame` in
     the installed iOS 18.5 SDK (PROMPT.md's Stage 2 spec asked for them);
     dropped in favour of `ARLightEstimate`'s ambient intensity/colour
     temperature — flagged in `FrameWriter.swift`, not silently omitted.
   - RGB/depth/confidence are saved in ARKit's native unrotated sensor
     frame, matching `camera.intrinsics` exactly, with orientation set as a
     cosmetic EXIF tag only — see `FrameWriter.swift`'s header comment
     before assuming the JPEGs are portrait-oriented on disk.

   Signing note: `project.yml`'s `DEVELOPMENT_TEAM: YOUR_TEAM_ID` looks wrong
   (it's not the team that ends up signing the build) but is correct to
   leave as-is — see `-allowProvisioningUpdates` note above and the
   `ios-signing-setup` memory. Don't "fix" it to match a build log.

5. **Objective 1's on-device latency benchmark — built and mechanically
   verified, 2026-09-11.** `ios/ObstacleAwareness/Sources/Benchmark/`:
   `DetectionController.swift` (`AVCaptureSession` → manual YpCbCr→BGRA
   conversion + letterbox resize, each its own timed stage, → real
   fine-tuned `.mlpackage` inference, no Vision framework — matches
   CLAUDE.md section 5's explicit intent that the buffer-conversion cost
   stay visible rather than being hidden inside Vision's abstraction),
   `BenchmarkView.swift` (model picker, start/stop, live thermal/frame-count
   HUD), `DetectorVariant.swift`. `LatencyLogger.swift` copied in from
   `tools/` (now actually wired in, closing that long-standing TODO). All
   three fine-tuned `.mlpackage` models bundled directly into the app under
   `Sources/Models/` (compiled to `.mlmodelc` automatically by Xcode — confirmed
   in the built app bundle). `RootView.swift` adds a Capture/Benchmark mode
   switch so both tools live in one build.

   Deliberately does not measure `depthSample`/`feedback` (reads 0 in the
   CSV) — those belong to Objective 3's decision layer, not built, and
   Objective 1 is specifically about the detector comparison.

   **Real smoke-test run (30-second, yolov8n, not the full benchmark):**
   2,206 frames in 73.8 s (~30 fps), `total_ms` mean 12.96 / median 12.92 /
   p95 14.23 (excluding the cold-start frame), correct `cold`→`warm` phase
   transition at the 60 s mark, `thermal_state` tracked correctly (stayed
   `fair` throughout this short a run). Log saved at
   `data/raw/device_logs/latency_yolov8n_none_1789131891.csv` for reference
   — **this is not the real benchmark data**, just proof the pipeline is
   mechanically correct end-to-end (real per-stage numbers, no NaNs, no
   crashes, correct CSV shape).

   **Objective 1 — fully done, 2026-09-11.** Real 15+ minute runs completed
   for all three models (yolov8n 1,423.5 s/42,675 frames, yolo11n 771.7 s/
   23,143 frames, yolo26n 794.9 s/23,842 frames — logs in
   `data/raw/device_logs/full_benchmark/`), processed by `latency_report.py`
   into `results/objective1_latency/`, combined with accuracy and manifest
   data into the final table: **`results/objective1_full_table.md`.**
   Headline: **yolo26n wins outright on every axis** — best accuracy (0.170
   vs ~0.125 pooled mAP50-95), fewest params, smallest `.mlpackage`, and
   tied-fastest sustained latency (79.0 fps vs yolov8n's 79.1, both ahead of
   yolo11n's 77.7). Notable finding, not a bug: `thermal_state` stayed
   `nominal` throughout all three runs — no throttling observed under these
   conditions, consistent with latency barely drifting between cold and
   sustained (≤0.4 ms) — and `capture`+`preprocess` combined cost nearly as
   much as `detect` itself (~5.5 ms vs ~7.3 ms), the buffer-handling cost
   CLAUDE.md's device-constraints section warned not to let go invisible.
   See the full table for details and caveats. Objective 1 needs nothing
   further.

**~~Not yet written: the decision layer~~ — built 2026-09-16.**
`ios/ObstacleAwareness/Sources/Assist/` — see section 7's status note.

**Revised shape of the remaining 4 days (2026-09-11 → 2026-09-15), after
descoping Objective 4:**
- **Today/tomorrow (11–12):** real tape-measured captures (~270 frames —
  the one physical, non-parallelizable task left) run in parallel with
  fixing the `finetuned_weights.zip` download and exporting the real
  fine-tuned detector to Core ML.
- **13:** `distance_eval.py` against the real captures (Objective 2's
  actual result); minimal on-device detection+depth pipeline with
  `LatencyLogger.swift` wired in for real A15 latency numbers (Objective
  1's missing half).
- **14:** whatever of the decision layer / haptic feedback is realistic to
  demonstrate as a working prototype (Objective 3) — this does not need to
  be participant-tested, just working.
- **15:** write-up. Given the compressed schedule, do not leave this for a
  single day by default — if the technical work above slips, cut it short
  rather than the write-up, since a working prototype with an unfinished
  writeup is a worse outcome than a slightly less polished prototype with a
  complete, honest writeup.
