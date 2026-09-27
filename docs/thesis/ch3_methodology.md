# Chapter 3 — Methodology

## 3.1 Overview

The work is organised as three linked studies sharing one codebase and one
target device. Objective 1 is a comparative benchmark of three detectors, in
which accuracy is measured offline and latency is measured on the phone.
Objective 2 is a measurement study comparing two depth-estimation methods
against tape-measured physical ground truth. Objective 3 is the construction of
the prototype itself, including the derived-feature layer that turns detections
and depth into feedback. Figure 3.1 shows how the offline work feeds the
on-device pipeline.

All three depend on one preparatory stage: assembling an indoor obstacle
dataset, because no existing public dataset covers the required classes.

The target device is an **iPhone 13 Pro Max** (A15 Bionic, 6 GB RAM, iOS 26.5)
with a built-in LiDAR scanner. All models are deployed as Core ML
`.mlpackage` bundles. Every latency figure reported in this thesis was measured
on that device; no workstation timing is quoted anywhere, because Core ML
prediction on macOS uses the Mac's Neural Engine and describes nothing about the
A15.

![Figure 3.1: System architecture. The offline stages produce the detector bundled in the application and the measurement that selected its depth source; the on-device pipeline processes one ARKit frame per cycle. Stage timings are the means from the prototype's second live run (§4.3.3).](figures/figure_3_1_system_architecture.svg)

### 3.1.1 Research design

The research is quantitative and comparative. Objectives 1 and 2 are
measurement studies: each holds everything fixed except the factor under
comparison, measures the outcome against a stated reference, and reports the
uncertainty of the result. Objective 3 is a design-and-build objective whose
evidence is functional verification and on-device measurement rather than a
comparison. Table 3.1 connects each research question to the design, data and
metrics that address it, and to the section where it is answered.

Table: Table 3.1: Research design — each research question mapped to its method, data, variables and results

| RQ | Objective | Design | Data | Independent variables | Outcome measures | Results |
|---|---|---|---|---|---|---|
| RQ1 | 1 | comparative benchmark; two training runs; on-device latency runs of 13–24 min; retraining experiments changing one factor at a time | merged indoor corpus, 2,714 training and 678 validation images, split by scene; live camera stream | detector architecture; for the retraining experiments, training data and augmentation | mAP50-95 and per-class AP; precision, recall and F1 at the operating threshold; per-stage latency (mean, median and 95th percentile, p95) and throughput; parameters and package size | §4.1 |
| RQ2 | 2 | measurement study against physical ground truth | 102 tape-measured captures, 0.5–4.5 m | depth method (LiDAR or monocular), distance, object class | mean absolute error (MAE), mean absolute percentage error (MAPE), root mean square error (RMSE) and signed bias, by method, distance and class, with bootstrap intervals | §4.2 |
| — | 3 | design and build, verified against planted values and measured on the device | planted test inputs; two live runs of the prototype | — | 45 verification checks; per-stage latency; thermal state; what the pipeline reported | §4.3 |
| RQ3 | 4 | within-participant comparison, order counterbalanced — designed and approved, not run | — | feedback condition (audio only, audio and haptic) | task completion time and success rate; post-task interview (planned) | §3.2.4 |
| RQ4 | stretch | not attempted | — | — | — | — |

### 3.1.2 Baselines and comparison points

Every comparison in this thesis has a stated reference point.

- **Detectors.** YOLOv8n is the baseline. It is the architecture the proposal
  named, and the one most used in the reviewed systems (He and Saha, 2023;
  Okolo et al., 2025). YOLO11n and YOLO26n are compared against it under
  identical training settings.
- **Depth.** The monocular network is the comparison for LiDAR, since RQ2 asks
  whether distance should be estimated with or without an additional sensor. Both
  are compared against the tape measure, which is the ground truth rather than
  a baseline.
- **Retraining experiments.** A local retrain of the original recipe is the
  baseline for every variant, so that each change is measured on identical
  hardware (§3.5.4).
- **Latency.** The Objective 1 harness, which runs the detector alone, is the
  comparison point for the full prototype's latency and thermal behaviour
  (§4.3.3–§4.3.4).
- **Previous research.** Where the reviewed literature reports a comparable
  quantity, Chapter 5 compares with it. Where it reports a different quantity,
  such as a mean per-object accuracy rather than a mean average precision, the
  difference is stated rather than the two numbers placed side by side.

The prototype itself has no baseline. No reviewed system was available to run
on the same device, and the comparison that would have served as its
evaluation, audio-only against audio-plus-haptic feedback, is the one that was
not run.

## 3.2 Ethics

Ethical approval was sought under the title "A Smartphone-Based Navigation
Assistant for Blind and Visually Impaired Users", with a proposed period of
1 June to 5 October 2026. The application was signed by the researcher on
8 July 2026 and by the supervisor on 11 August 2026, with the supervisor's
recommendation to the Research Ethics Committee recorded as "This is a low risk
project and all ethical, legal and safety issues have been sufficiently
addressed". The signed application form, and the participant information,
informed consent and debriefing sheets submitted with it, are reproduced in
Appendix A.

The supervisor's signed recommendation constitutes the approval record for this
project. No data collection involving human participants was undertaken at any
point (§3.2.5).

Section numbers of the ethics form are written below as "form §2.6" and so on,
to distinguish them from sections of this thesis.

### 3.2.1 Reconciling the approved title with the delivered scope

The approved form is titled "A Smartphone-Based Navigation **Assistant**",
form §2.4 describes a "navigational aid system", and form §2.6 describes
participants undertaking "navigation and obstacle avoidance tasks". This thesis
delivers a narrower system: obstacle awareness only, with no route guidance or
wayfinding of any kind. The delivered scope is a strict subset of the approved
scope. Delivering less than was approved raises no ethical difficulty; the
divergence is recorded so that the two titles are not read as describing
different studies.

### 3.2.2 Secondary data sources

Form §3.2 names two secondary sources: **COCO**, publicly available under
CC BY 4.0; and **a self-collected image set of ground-level indoor hazards**,
captured by the researcher in controlled, non-public indoor spaces, annotated
using Roboflow, with no identifiable bystanders. Form §2.6 describes Stage I as
evaluating models "through publicly available data sets like COCO".

The datasets actually used are recorded in full in §3.3. Two points of detail
are noted here. All three detectors were fine-tuned on a publicly licensed
Roboflow dataset, `lochan-r-ugnn4/indoor-objects-detection-h2mgz`
(CC BY 4.0; Lochan R, 2023) — a public dataset falling within form §2.6's
"publicly available data sets like COCO", carrying no personal data beyond the
`person` class discussed below. The self-collected capture set spans doors,
chairs, table edges, wall and pole segments and floor-level obstacles, which is
broader in class coverage than form §3.2's "ground-level hazards" wording but
identical in kind and in collection conditions: researcher-collected, in
controlled unoccupied indoor spaces, with no identifiable bystanders.

One further public dataset was used after the measurements reported in
Chapter 4 were complete: the AI Builders indoor-objects set (GPL-3.0;
Jaiinsom, 2022), located on Kaggle too late to enter the merged corpus and used
only in the retraining experiments of §4.1.8. It is described in §3.3.7. Like
the Roboflow set, it is a publicly licensed dataset of indoor photographs
falling within form §2.6's "publicly available data sets like COCO", and it
carries no personal data beyond the `person` class discussed below. It is
recorded here so that the sources actually used are stated in full.

NYU Depth V2 and DIODE were considered during planning and were **not**
obtained or used (§3.3.3).

`person` is retained in the detection taxonomy because a person is a genuine
indoor obstacle, but **no bystander appears in any frame** the researcher
collected. The only person visible anywhere in the capture set is the
researcher, whose feet appear at the lower edge of some close-range frames;
no face or other identifying feature is captured.

### 3.2.3 Inconsistencies in the application documents, and how each is resolved

**Recording.** Form §2.6 states that evaluation "sessions will be video
recorded", while form §4.11 — "Will you audio or video record interviews and/or
observations?" — is marked **No**, and form §4.10, on consent from people
appearing in visual data, is marked **Yes**. These answers cannot all be
correct, and the reviewer's comment on form §4.10 asked explicitly for
confirmation of whether participant images or video would be captured. The
participant documents divide the same way: the debriefing sheet, the earliest
of the three, refers to a video recording, while the information and consent
sheets state that none is made.

The protocol adopted resolves this in favour of form §4.11 and the information
and consent sheets: **no audio, video or photographic record of participants is
made at any point.** The debriefing sheet would have been corrected before any
session. The study's
measures — task timings, outcomes, and post-task comments — are captured as
written notes, so footage would add an obligation under data protection without
adding evidence. Collecting less personal data than was approved raises no
ethical difficulty, on the same reasoning as §3.2.1.

**Participant count.** Form §2.6 specifies **five** blindfolded participants
while form §3.1 specifies **10–15**, and the reviewer's comments requested
clarification. The governing figure is **five**, consistent with form §2.6 and
with the information sheet.

**Post-task instrument.** Form §2.6 describes post-task interviews to be
analysed thematically, while the information and consent sheets tell
participants they will complete a short post-task questionnaire. Neither an
interview guide nor a questionnaire is among the application documents, and
none was drafted, because the study was not run. A single instrument would have
had to be settled, and the participant documents aligned with it, before
recruitment.

**Title.** The form and the debriefing sheet carry the earlier title, "A
Smartphone-Based Navigation Assistant"; the information and consent sheets
carry the thesis title. §3.2.1 reconciles the two.

### 3.2.4 The evaluation protocol as specified

Recorded here because a reader should be able to see what was approved and
prepared, whether or not it was carried out (§3.2.5).

**Participants.** Five sighted participants, aged 18 or over, recruited by
convenience sampling from fellow students and the researcher's contacts,
wearing blindfolds. The information sheet excludes anyone with a medical
condition, such as a balance or inner-ear condition, that would make the task
unsafe. The approved form is explicit that no blind or visually
impaired individuals take part in this phase, and that blindfolded sighted
participants are a limited simulation for feasibility testing rather than a
substitute for testing with BVI users.

**Procedure.** Each participant completes a short indoor obstacle course twice —
once under **audio-only** feedback and once under **audio-plus-haptic** — with
condition order counterbalanced between participants. Counterbalancing is not
presentational: sustained camera and Neural Engine use warms the device, so a
fixed order risks the second condition measuring thermal state rather than
feedback modality.

**Measures and instrument.** Form §2.6 specifies the measures: task completion
time and success rate, recorded by the researcher as written notes, alongside
the system's own logged detection output and latency; and a post-task
interview, to be analysed thematically. The information and consent sheets
describe a short post-task questionnaire instead (§3.2.3). A session was
expected to take 20–30 minutes.

**Safety and consent.** Sessions take place on the Middlesex University Dubai
campus, in a controlled indoor environment with clear walkways and low, soft
obstacles deliberately positioned. Participants receive a full safety briefing
beforehand; **a sighted volunteer remains beside each participant
throughout**, monitoring for safety and able to intervene immediately;
participants set their own pace and may stop or withdraw at any time without
giving a reason, including for seven days after the session, in which case
their data is destroyed. Written informed consent is obtained in advance. No
payment or reimbursement is offered.

### 3.2.5 The evaluation was not conducted

**This evaluation was not carried out.** No participant was recruited, no
consent was taken, no session took place, and no participant data of any kind
exists. The approval for it remains unused rather than exceeded, and RQ3 is
therefore unanswered (§1.5).

## 3.3 Data

### 3.3.1 Why an existing dataset was not sufficient

COCO (Lin et al., 2014) contains no `door`, `stairs`, `pole` or `glass` class.
These are precisely the indoor obstacles that carry the highest consequence on
contact, and their absence makes a zero-shot benchmark impossible for exactly
the classes that matter. All three detectors were therefore fine-tuned on a
merged indoor corpus, with COCO retained only as a held-out zero-shot partition
for the classes it does cover.

### 3.3.2 Sources used

Table 3.2 lists every data source used, with its licence and its role in the
project.

Table: Table 3.2: Data sources used

| Source | Content | Licence | Role |
|---|---|---|---|
| Roboflow indoor-objects (Lochan R, 2023) | 1,417 images, 10 classes | CC BY 4.0 | fine-tuning and validation |
| COCO val2017 (Lin et al., 2014) | 5,000 images, 36,781 annotations, 80 categories | CC BY 4.0 (annotations) | zero-shot partition; one retraining variant |
| AI Builders indoor-objects (Jaiinsom, 2022) | 1,349 images, 7,331 objects, 10 classes | GPL-3.0 | retraining experiments only (§3.3.7) |
| Researcher captures | 102 tape-measured frames: RGB, depth and confidence | researcher-owned | Objective 2 ground truth |

The Roboflow source was confirmed through Roboflow's application programming
interface as
`lochan-r-ugnn4/indoor-objects-detection-h2mgz` version 1. Its ten classes are
Bed, Chair, Couch, Door, Person, Stairs, Table, Toy, Wardrobe and Window.

**Why these sources are appropriate.** RQ1 asks which detector suits indoor
obstacle detection on a phone, which needs annotated photographs of indoor
obstacles in the classes that matter. The Roboflow set was the only openly
licensed source obtained that carries `door` and `stairs` annotations, and it is
photographed at human scale in rooms and corridors rather than from a vehicle
or a robot. Its limits are reported rather than assumed away: it is small, it
is frame-extracted from video, and it lacks four intended classes (§3.3.3).
RQ2 asks how accurate distance estimates are, which needs a physical ground
truth that no public dataset supplies in this form. The researcher's captures
provide it, taken with the target phone, in the setting the prototype is meant
for, at the distances that matter to a walking user.

COCO val2017 could not be downloaded from `images.cocodataset.org` in the
development environment, which blocks unlisted hosts at the proxy. It was
obtained from Kaggle mirrors and then **cross-checked against the official
host**: `instances_val2017.json` and three sampled images are byte-for-byte
identical (MD5) to copies downloaded directly from `images.cocodataset.org` on
an unrestricted connection. The mirror is therefore confirmed as carrying the
primary-source bytes, not merely assumed to.

### 3.3.3 Sources planned but not obtained

Three planned sources were not used, and each omission has a downstream
consequence that is reported rather than concealed.

- **AI Builders indoor-objects (Jaiinsom)** — GNU GPL 3.0, 1,349 images, the
  only planned source carrying `pole` and door subtypes. Not obtained before
  the corpus was frozen. As a direct result the merged corpus contains **zero
  instances of `pole`, `door_glass`, `handrail` and `other`**, and the
  fine-tuned detectors cannot emit those classes at all. `pole` carries the
  second-highest hazard weight in the taxonomy after `stairs`. This is the
  single most consequential gap in the dataset and is discussed in Chapter 5.
  The source was located after the corpus had been frozen, too late to change
  it; §3.3.7 records what it contains and §4.1.8 what adding it does.
- **NYU Depth V2 (labeled)** (Silberman et al., 2012) — the direct download
  (2.97 GB, confirmed by HTTP HEAD) was interrupted and not resumed; free disk
  space on the development machine was under 6 GB. The official train/test
  split file's URL could not be verified.
- **DIODE indoor val** (Vasiljevic et al., 2019) — not obtained.

The two depth datasets would have provided a second, independent check on
monocular depth accuracy. Their absence means Objective 2 rests entirely on the
researcher-collected captures — which is the stronger of the two
kinds of evidence, since it is physically measured rather than
sensor-derived. It does mean there is no second dataset to corroborate it.

### 3.3.4 The merged taxonomy

Sources were remapped into a single 12-class taxonomy: `person`, `chair`,
`table`, `door`, `door_glass`, `window`, `stairs`, `pole`, `handrail`, `wall`,
`low_obstacle`, `other`. Four mappings from the Roboflow source are judgement
calls rather than exact correspondences and are recorded as such: Bed, Couch and
Toy map to `low_obstacle` as floor-level obstacles; Wardrobe maps to `wall` as
tall furniture blocking passage.

Each class carries a fixed hazard weight used later by the urgency function
(§3.8.2), ordered on consequence of contact: `stairs` (1.0) > `door_glass`
(0.9) > `pole` (0.8) > `door` (0.7) > `low_obstacle` (0.6) > `handrail`/`wall`
(0.4) > `table`/`chair`/`window` (0.3) > `person` (0.2) > `other` (0.1).

The ordering has a stated basis; the numerical values do not. Stairs rank
first because a fall is the most serious outcome in the accident survey of
Manduchi and Kurniawan (2011), where 36 % of respondents reported falls with
medical consequences. Glass doors rank second because they defeat both the camera
and the depth sensor (§3.4), so they are the obstacle least likely to be
announced. Poles and doors follow because they strike above the height a cane
sweeps, and the indoor head-level collisions in the same survey were typically
with doors, shelves, tables, staircase sides and walls. A person ranks low
because a person moves out of the way and can be spoken to. The spacing
between the numbers is a design choice with no empirical basis, which is why
hazard is only allowed to modulate urgency, not to decide it (§3.8.2).

### 3.3.5 Splitting by scene, not by image

The Roboflow source is frame-extracted from video. A random image-level split
would place near-duplicate frames on both sides of the train/validation
boundary and inflate mAP without measuring generalisation. The split is
therefore taken at **scene level**, keyed on the stable per-image identifier
that precedes the `_jpg.rf.<hash>` suffix in the exported filenames.

That identifier required verification rather than assumption. The Roboflow
export applies 3× augmentation (vertical flip and 30° rotation) to its own train
split only — 992 raw training images become 2,967 exported ones, while
validation and test are unchanged at 283 and 142. Listing all three exported
copies of a single original confirmed that they share one identifier and differ
only in the hash suffix, so augmented copies of the same photograph land in the
same scene and therefore the same split. The merge produced 1,417 unique
scenes, exactly matching the raw image count.

The resulting partition is 2,714 training images, 678 validation, and 3,068
COCO images held out as a zero-shot partition — 6,460 in total. There is no
separate test split. The 678 validation images select each model's best epoch,
which is Ultralytics' default, and are used to compare the retraining variants;
no hyperparameter was tuned on them. The capture set (§3.7) is the fully
held-out test, and the only one taken in the deployment setting.

### 3.3.6 Class imbalance

Per-class instance counts are reported in full rather than pooled (Table 3.3),
because the merged taxonomy is severely imbalanced and a single pooled mAP
conceals it.

Table: Table 3.3: Instances per class in the merged corpus

| class | train | val | zero-shot | total |
|---|---|---|---|---|
| window | 3,756 | 747 | 0 | 4,503 |
| low_obstacle | 1,903 | 344 | 0 | 2,247 |
| person | 1,248 | 367 | 11,004 | 12,619 |
| chair | 1,069 | 368 | 1,791 | 3,228 |
| table | 777 | 329 | 697 | 1,803 |
| door | 410 | 113 | 0 | 523 |
| stairs | 398 | 83 | 0 | 481 |
| wall | 355 | 84 | 0 | 439 |
| door_glass, pole, handrail, other | 0 | 0 | 0 | 0 |

`stairs` — the highest-weighted hazard in the taxonomy — is supported by 398
training instances, and four classes by none at all. Both facts constrain what
Chapter 4's accuracy figures can be taken to mean. No resampling or class
weighting was applied to correct the imbalance: the three detectors are
compared under the same imbalance, and correcting it would have added a
setting whose effect interacts with architecture.

### 3.3.7 A source recorded as unobtainable, subsequently obtained

The AI Builders set above was located on Kaggle after the corpus was frozen
(`thepbordin/indoor-object-detection`, GPL-3.0, 1,349 images, 7,331 objects).
It is **not** part of the merged corpus and does not affect any figure in §4.1
to §4.3: re-merging it would have redrawn the scene split and invalidated every
measurement already taken. It is used only in the retraining experiments
(§3.5.4, §4.1.8), where it is kept as a separate tree with its own published
splits, its train and valid portions added to training and its test portion
held back as an evaluation set.

Its real class list differs from the one this project had assumed from the
source's prose description: `door`, `cabinetDoor`, `refrigeratorDoor`,
`window`, `chair`, `table`, `cabinet`, `couch`, `openedDoor`, `pole`. There is
no glass-door and no handrail class, so the source adds `pole` — 36 boxes —
but does not close the other three gaps. Three mappings follow the precedents
in §3.3.4: `openedDoor` to `door`, `couch` to `low_obstacle`, `cabinet` to
`wall`. `cabinetDoor` and `refrigeratorDoor` are deliberately dropped, because
mapping a cabinet front to `door` would teach the model that a cabinet is a
doorway. These mappings and exclusions were confirmed by the researcher.

Both this source and the Roboflow one draw on Open Images, so the two were
checked for shared photographs: four, all on the Roboflow training side, so no
evaluation set is contaminated.

### 3.3.8 Variables and features

Table 3.4 lists what each data set records and how it is used. There is no
classical feature engineering on the input side: the detection and depth
networks learn their own representations from pixels. The engineered features
in this project are derived from the models' outputs, between the models and
the feedback, and are defined in §3.8.2.

Table: Table 3.4: Variables recorded in each data set

| Data set | Unit | Variables | Used as |
|---|---|---|---|
| Detection corpus (Roboflow, COCO, AI Builders) | image | RGB image; for each object, a class in the 12-class taxonomy and a bounding box as normalised centre, width and height; source and scene identifier | detector input and training target |
| Capture set | frame | RGB 1920 × 1440; LiDAR depth 256 × 192 in metres; per-pixel confidence (low, medium, high); camera intrinsics; device attitude (pitch, roll, yaw); ambient light intensity and colour temperature; from the filename, the photographed class, tape-measured distance in millimetres, lighting condition and repetition | Objective 2 ground truth and inputs |
| Benchmark latency log | frame | per-stage time in milliseconds for `capture`, `preprocess` and `detect`; total; thermal state; session phase and elapsed time | Objective 1 latency |
| Prototype latency log | frame | the benchmark log's fields plus `depthSample` and `feedback` times, number of tracks, confirmed tracks, and the top obstacle's class, confidence, distance, urgency and warning level | Objective 3 measurement |

### 3.3.9 Data quality: duplicates, missing values, label errors and outliers

Table 3.5 lists every data-quality issue found and how it was treated. The
guiding rule was to correct errors where the correct value was known, to
exclude where it was not, and never to impute a value into ground truth.

Table: Table 3.5: Data-quality issues and their treatment

| Issue | Where | Treatment |
|---|---|---|
| Near-duplicate frames extracted from video, and augmented copies of one photograph | Roboflow source | split by scene so that all copies fall on one side (§3.3.5); bootstrap resamples scenes, not images (§3.5.3) |
| Photographs shared between sources | Roboflow and AI Builders, both drawn from Open Images | checked; four shared, all on the Roboflow training side (§3.3.7) |
| Missing annotations: visible people and chairs left unlabelled | Roboflow source | audited (§4.1.7); in one retraining variant, completed in the training split only by a teacher model, with the validation labels left unchanged (§3.5.4) |
| Classes with no instances | `pole`, `door_glass`, `handrail`, `other` | reported, not synthesised; the detector is described as covering eight of twelve classes |
| Vertical-flip copies inconsistent with the augmentation policy | Roboflow export | kept, since removing them would redraw the split; acknowledged in §3.4 |
| Stray and practice captures | capture set, 121 frames pulled from the device | 19 excluded as smoke-test or practice frames, preserved rather than deleted |
| Distance field not advanced before the next shot | capture set | 12 frames relabelled to their true distance, each listed in a correction log |
| Implausible ground truth (a distance entered in metres) | capture set | values below 250 mm rejected on load (§3.7.2) |
| Missing or unreliable depth pixels | LiDAR depth maps | low-confidence pixels discarded; the median taken over what remains; a frame with no valid pixel is reported as missing, never filled |
| Frames with no detector box | capture set | excluded from the headline figures, not given a substitute box; reported as a coverage finding (§4.2.1) |
| Outlying depth values within a box | both depth sources | handled by using the median rather than the mean; no frame removed as an outlier |

The capture set's audit trail is reproduced with the data (Appendix E). No
frame was removed for giving an inconvenient result.

### 3.3.10 Synthetic, proxy and simulated data

Several parts of this work rely on data that is not a direct measurement of the
thing it stands for. Each is disclosed in Table 3.6 with the limitation it
brings.

Table: Table 3.6: Synthetic, proxy and simulated data, and their limitations

| Data | Stands in for | Where used | Limitation |
|---|---|---|---|
| Hypersim renderings (Roberts et al., 2021) | real indoor scenes with metric depth | the training data of the monocular depth network's metric fine-tuning | synthetic images and one camera geometry; a candidate explanation for the network's systematic error (§5.3) |
| Teacher-model labels (YOLO26x, COCO-pretrained) | human annotation of missing people, chairs and tables | the `relabel` retraining variant; a secondary evaluation set | 79 % of a checked sample correct (§4.1.8); the secondary set is reported as secondary because one model wrote both it and the training labels |
| Planted depth values and synthetic detections | real frames with known geometry | off-device verification of the decision layer (§3.8.4) | verifies arithmetic and geometry, not device behaviour |
| A merged-set photograph upscaled to 1920 × 1440 with a planted depth map | a real capture | an end-to-end check of the distance pipeline before any real capture existed | used for verification only; no figure in this thesis comes from it |
| Blindfolded sighted participants | blind and visually impaired users | the approved evaluation protocol (§3.2.4), which was not run | would have supported feasibility claims only (§2.5.4) |
| A wall segment photographed for `pole` | a pole | the capture protocol (§3.7.1), because the detector has no `pole` class | tests whether depth can be sampled at a pole-like surface, not whether a pole is detected |

## 3.4 Preprocessing

Two distinct pipelines exist, and conflating them is a common source of
misreported latency.

**Offline (training and evaluation).** Images are letterboxed to 640 px,
preserving aspect ratio, and pixel values are scaled to the range 0 to 1, which
is the detectors' own convention; the depth network instead uses ImageNet mean
and standard-deviation normalisation, baked into its exported graph (§3.5.2).
Augmentation is restricted to transformations a chest-held phone actually
produces: horizontal flip, modest colour and brightness variation, mild
rotation, translation and scale (Table 3.9). **No vertical flip and no
mosaic** — both teach viewpoints the camera never occupies. The Roboflow export
applies its own vertical flip to its training split; those copies are present
in the corpus, and this is acknowledged as an inconsistency with the stated
policy rather than silently inherited. The mosaic decision was later tested and
reversed (§4.1.8).

**On-device (inference — this is what the latency figures measure).**
`AVCaptureSession` yields a `CVPixelBuffer` in 420f bi-planar YpCbCr, which is
converted manually to BGRA, then resized and letterboxed. The conversion is
written explicitly and timed as its own stage rather than delegated to the
Vision framework, specifically so that its cost remains visible; §4.1 shows
that cost to be substantial. Two known traps were guarded against: performing
pixel-buffer conversion on the CPU per frame, and device-versus-image
orientation mismatch, which silently rotates the input and degrades accuracy
while appearing correct in a debugger. The prototype takes its frames from
ARKit rather than `AVCaptureSession`, and rotates each one upright before
detection, for the reason given in §3.7.1.

**Depth.** ARKit `sceneDepth` is delivered at 256 × 192 and must be mapped into
the RGB frame before sampling. The RGB frame is 1920 × 1440, the same 4:3
aspect ratio, so the mapping between the two is a uniform scale once both are
in the same orientation. Depth pixels are filtered by `ARConfidenceLevel` and
low-confidence pixels are **discarded**, because glass and dark matte surfaces
return confident-looking but wrong values.

## 3.5 Models

Table 3.7 lists the models used, with their size and licence.

Table: Table 3.7: Models used

| Model | Role | Parameters | Licence |
|---|---|---|---|
| YOLOv8n (Jocher, Chaurasia and Qiu, 2023) | detection baseline | 3.0 M | AGPL-3.0 |
| YOLO11n (Jocher and Qiu, 2024) | detection candidate | 2.6 M | AGPL-3.0 |
| YOLO26n (Jocher et al., 2026) | detection candidate | 2.5 M | AGPL-3.0 |
| Depth-Anything-V2 Metric Indoor Small (Yang et al., 2024) | monocular metric depth | 24.8 M | Apache-2.0 |
| ARKit `sceneDepth` (Apple Inc., n.d.a) | LiDAR depth | — | platform |

**Why these detectors.** The review in §2.5.5 supports a single-stage detector
for a phone, and the three chosen span three generations of one family:
YOLOv8n, the most widely used in the reviewed systems; YOLO11n, its successor;
and YOLO26n, which removes non-maximum suppression by predicting a
non-redundant set of boxes (Sapkota et al., 2025; Jocher et al., 2026). All
three share one training and export toolchain, so the comparison isolates
architecture rather than tooling, and this is a stronger comparison than the
YOLOv8-versus-YOLO-NAS pairing originally proposed. The nano variants were
chosen because they are the size class intended for mobile deployment; a
larger variant would have been compared at a latency cost the application does
not need to pay if a nano model suffices.

**Why this depth network.** RQ2 compares depth with and without an additional
sensor, which needs a depth estimate in metres from a single image. A relative
network such as MiDaS (Ranftl et al., 2022) would have needed a scale fitted
per image against the ground truth, which would make the comparison circular.
Depth-Anything-V2's (DAv2) metric indoor variant outputs metres directly, so mean
absolute error is computable without scale fitting. Only the **Small** variant
is Apache-2.0; Base, Large and Giant are CC-BY-NC-4.0 and were not
substituted. The checkpoint used is `Depth-Anything-V2-Metric-Hypersim-Small`:
"Hypersim" names the synthetic indoor dataset it was fine-tuned on (Roberts et
al., 2021), and it is the same Apache-2.0 indoor metric checkpoint under a
different repository name. It was run with `max_depth = 20`.

Ultralytics' AGPL-3.0 licence means publishing the application source inherits
copyleft. This is acceptable for a dissertation and is declared here.

Table 3.8 lists the alternatives considered for each component and why each
was not chosen.

Table: Table 3.8: Alternatives considered

| Component | Alternative | Why it was not chosen |
|---|---|---|
| Detector | two-stage detector such as Faster R-CNN (Ren et al., 2017) | a region-proposal stage adds latency that a per-frame mobile pipeline cannot afford, and no reviewed assistive system uses one on a phone |
| Detector | transformer detector such as RT-DETR (Zhao et al., 2024) | its speed claims are made on server GPUs; the one reviewed system using the family reports about 150 ms per frame (Khilnani and Devesh, 2025) |
| Detector | YOLO-NAS, as proposed | a separate training toolchain and licence would have confounded architecture with tooling |
| Detector | larger YOLO variants (small, medium) | not tested; the nano variants run far inside the frame budget, and the retraining experiments found the binding constraint to be data rather than capacity (§4.1.8) |
| Depth | MiDaS (Ranftl et al., 2022) | relative depth; comparing it with a tape measure needs a per-image scale fitted to the ground truth |
| Depth | Depth-Anything-V2 Base or Large | non-commercial licence |
| Depth | geometry from known object sizes | needs a size prior per class, and fails for partly visible objects such as a door cut off by the frame |
| Depth | an external ultrasonic or depth sensor, as in Okolo et al. (2025) and Khilnani and Devesh (2025) | additional hardware; the phone's built-in LiDAR tests the same idea without it |
| Depth | NYU Depth V2 or DIODE as a second benchmark | not obtained (§3.3.3) |
| Feedback | continuous speech | first-utterance latency of hundreds of milliseconds; speech is kept for object identity, on demand (§3.8.3) |
| Feedback | spatial audio over headphones | headphones block the environmental sound a BVI user depends on; bone-conduction headsets would add hardware |
| Evaluation | study with BVI participants | not approved for this phase; a blindfolded feasibility study was approved instead, and not run (§1.5) |

### 3.5.1 Training

All three detectors were fine-tuned on a free Colab T4 GPU from their
COCO-pretrained checkpoints, with **identical hyperparameters** so that the
comparison isolates architecture (Table 3.9). Training was run **twice**
(2026-09-08 and 2026-09-11) to separate a genuine ranking from single-run
noise, and both runs are reported in Chapter 4.

The two runs are repeats of one configuration rather than independently seeded
runs. The notebook set no seed, so Ultralytics' default applied to both: seed 0
with deterministic mode requested. The two runs nonetheless differed by up to
0.007 in pooled mAP50-95, which is the run-to-run variation that GPU
computation and an unpinned library version leave even under a fixed seed.
What the two runs bound is that variation. They do not sample the effect of a
different random initialisation of the new classification layers, and the
ranking in §4.1 should be read with that in mind.

Table: Table 3.9: Training configuration, identical for all three detectors

| Setting | Value | Reason |
|---|---|---|
| Initial weights | COCO-pretrained checkpoint of each architecture | transfer learning from a large general corpus to a small indoor one |
| Epochs | 50 | validation mAP flattens near epoch 40 and validation loss rises from epoch 1 (§3.5.4), so longer training was not pursued |
| Image size | 640 × 640, letterboxed | Ultralytics default; matches the on-device input |
| Batch size | 16, with gradients accumulated to a nominal batch of 64 | fits a T4's memory; accumulation is Ultralytics' default |
| Optimiser | AdamW, learning rate 0.000625, momentum 0.9, weight decay 0.0005 | selected by Ultralytics' `auto` rule for runs under 10,000 iterations; this run has 2,150 |
| Learning-rate schedule | 3 warm-up epochs, then linear decay to 1 % of the initial rate | Ultralytics default |
| Mixed precision | on | Ultralytics default on GPU |
| Horizontal flip | probability 0.5 | the scene can appear on either side |
| Vertical flip | 0 | a chest-held phone is never upside down |
| Rotation | up to 10° | hand tilt, not tumbling |
| Translation, scale | 0.1, 0.2 | modest framing variation |
| Colour jitter (hue, saturation, value) | 0.015, 0.4, 0.3 | modest lighting variation |
| Mosaic, mixup | 0, 0 | excluded as unrealistic viewpoints; the mosaic decision is revisited in §4.1.8 |
| Seed | 0 (Ultralytics default), deterministic mode | see text |
| Software | Ultralytics 8.4.147 | recorded in the checkpoint |

No hyperparameter search was run. With three architectures to compare, a search
per architecture would have tuned each to the validation set and confounded
the comparison with the search; defaults were kept wherever there was no
specific reason to depart from them, and every departure is justified in the
table.

### 3.5.2 Core ML export

Detectors and the depth network were exported to `.mlpackage` with coremltools
9.0, with a manifest recording parameter count, package size and licence.
Normalisation is baked into the traced depth graph rather than approximated by
Core ML's scalar `scale` parameter.

Two issues in the depth export path required resolution and are recorded because
they affect reproducibility:

1. The metric variant of Depth-Anything-V2 is a genuinely different
   `DepthAnythingV2` class — with a sigmoid and `max_depth` scaling head —
   living under `metric_depth/`, not the repository root's relative-depth class
   of the same name.
2. Tracing failed on `upsample_bicubic2d`, for which coremltools 9.0's PyTorch
   frontend has no converter, independent of deployment target. The only
   bicubic call in the model is the positional-embedding resize in its DINOv2
   backbone (Oquab et al., 2024) — a smooth low-frequency resize of learned
   embeddings, not of image content — so bilinear is substituted for bicubic
   **during tracing only**. A real prediction after the fix returned depth
   min/max/mean of 1.9 / 10.5 / 5.2 m with zero NaNs.

The exported detectors carry one non-obvious quirk: the raw `confidence` output
has shape (num_detections, 80) regardless of the model's actual class count,
because Ultralytics' Core ML NMS export path allocates 80 columns from its COCO
template. The true class confidence always falls within the first 12 columns,
matching the model's own `names` metadata and the raw PyTorch predictions
exactly; columns 12–79 are near-zero padding. On-device inference reads the
metadata's `names` dictionary and slices accordingly.

Export correctness was verified by running a real validation image through the
`.mlpackage` and through the raw `.pt` weights via Ultralytics, and comparing:
same class, same box, confidences of 0.77 and 0.76 — a small numerical
difference between runtimes, not a discrepancy. The exports are float
precision; no quantisation was applied.

### 3.5.3 Evaluation at the operating threshold

Mean average precision summarises a detector across every confidence
threshold. That is the right basis for comparing architectures, and it is why
§4.1.1 uses it. It does not describe what the prototype does, because the
prototype runs at a single threshold: a confidence of 0.30, with non-maximum suppression at an intersection over union (IoU, Equation 3.1)
of 0.45. A second evaluation therefore fixes the
threshold where the prototype fixes it and asks which errors remain. The script
is `tools/detection_metrics.py`.

Before any new metric was computed, the local evaluation was checked against
the one already reported. Ultralytics' own validation routine, run on the same
weights and the same 678-image validation split, reproduced the pooled and
per-class AP of the second Colab run to four decimal places for all three
models. The analysis below is therefore computed on the evaluation Chapter 4
reports, not on a close relative of it.

Each model's predictions were generated once, with one class per box, as the
Core ML export's argmax produces. Predicted boxes were matched to annotated
objects using Ultralytics' own confusion-matrix routine, greedy by IoU and
one-to-one, rather than a reimplementation of it. The overlap between a
predicted box $B_p$ and an annotated box $B_g$ is their intersection over union,

$$\mathrm{IoU}(B_p, B_g) = \frac{|B_p \cap B_g|}{|B_p \cup B_g|} \qquad (3.1)$$

and a box counts as matched at IoU above 0.5, the criterion behind AP50
(Everingham et al., 2010). Every annotated object then falls into exactly one
outcome: found with the right class, found with the wrong class, or missed.
Every box the model outputs is either one of the first two or **spurious**, with
no object under it. With TP the objects found with the right class, FP the
boxes output that are not, and FN the objects not found with the right class,

$$P = \frac{TP}{TP + FP}, \qquad R = \frac{TP}{TP + FN} \qquad (3.2)$$

$$F_1 = \frac{2PR}{P + R} \qquad (3.3)$$

Precision, recall and F1 are computed per class. Micro averages count every
object once; macro averages count each of the eight classes present in
validation once. Object detection has no true negatives, so accuracy is
reported in two defined forms, both read directly off the matrix. *Matrix
accuracy* is correct detections over every non-empty cell. *Classification
accuracy* is correct detections over objects matched at all: of the objects
the detector found, the share it named correctly. The two separate a detector
that cannot find objects from one that finds them and names them wrongly.

Two further analyses test the result rather than decorate it. The first is a
**bootstrap over scenes** (Efron and Tibshirani, 1993): 2,000 resamples of the
283 validation scenes, with the same scenes drawn for every model on each
draw, so that model differences are paired. Scenes are resampled rather than
images because 196 of the 283 validation scenes are three augmented copies of
one photograph (§3.3.5), and three copies are not three independent
observations. The second is **recall by object size**, in the pixel-area bands
COCO defines (small below 32², medium below 96², large above). It tests whether
the objects the detector misses are simply the small ones. Every figure is also
recomputed on the 84 scenes that appear once, which are the only unaugmented
photographs in the split.

The evaluation uses the PyTorch weights, not the Core ML exports. The two were
shown to agree on a sample image above but were not compared across this set.

### 3.5.4 Retraining experiments

The operating-point evaluation (§4.1.7) raised a question the benchmark could
not answer: what would make the detector better. Five candidate answers were
tested by retraining, one change at a time, with YOLO26n held fixed as the
architecture. The script is `tools/train_ablation.py`.

**The comparison point is a local retrain, not the Colab weights.** The
experiments ran on the researcher's own machine (Apple M4, Metal backend)
rather than a Colab T4, so a `baseline` run repeated the original recipe
exactly — same Ultralytics version, same seed, same 50 epochs — to give every
variant something to be measured against on identical hardware. §4.1.8 reports
how closely that baseline reproduces the Colab model.

One question was dismissed before testing. The saved checkpoints carry their
own epoch-by-epoch history, and in all three of them validation box loss rises
from the first epoch while training box loss falls; validation mAP flattens
around epoch 40. The model is overfitting a small corpus, so training for
longer was not among the variants.

The five changes were: **mosaic augmentation** (Bochkovskiy, Wang and Liao,
2020) at Ultralytics' defaults, reversing the decision in §3.4 on the evidence
of that overfitting and of the 0.07 recall on small objects; **relabelling**,
described below; **COCO**, adding the 3,068 converted COCO images that §3.3.2
held out as a zero-shot test set; **AI Builders**, the source §3.3.3 records as
unobtainable, which was subsequently located on Kaggle and is described in
§3.3.7; and combinations of whichever of these proved to help.

**Relabelling.** The audit in §4.1.7's follow-up found real, unlabelled objects
under five of the six sampled `chair` boxes and three of the six `person` boxes
that fell over apparently empty regions. Missing labels do double damage:
they count against precision at evaluation, and in training they teach the
model that a visible person is background. `tools/relabel_missing.py` therefore
completes the **training** split's annotations with a large COCO-pretrained
detector (YOLO26x), adding a box only where its confidence is at least 0.5 and
no existing annotation of any class overlaps it at IoU 0.3 or more. The
validation split is left untouched, so any gain is measured against the
original ground truth.

**Four evaluation sets**, so that no single benchmark decides the answer:

1. the 678-image validation split with its **original** labels, the same set
   every figure in §4.1 uses;
2. its 84 unaugmented photographs;
3. the **AI Builders test split** (107 photographs, a source no variant except
   `aib` and `full` trained on) — an out-of-source check;
4. the **102 tape-measured captures** (§3.7.1), never used for training, scored
   by whether the photographed class is detected at all. This is the only set
   taken in the setting the prototype is used in.

A fifth, secondary set scores against validation labels completed by the same
teacher rule. It answers a specific objection — that a relabelled model is
penalised for finding the people the validation annotators also skipped — and
it is reported as secondary throughout, because one teacher wrote both those
labels and the relabelled training set.

Differences are read against a **paired bootstrap over scenes**, 2,000
resamples, the same scenes drawn for every model on each draw (§3.5.3). One
run is one sample: the two Colab runs of the original recipe differed by 0.006
pooled mAP50-95, so differences below roughly 0.01 are not evidence.

### 3.5.5 Controls against data leakage

Leakage would make every accuracy figure in Chapter 4 optimistic, so the
controls are collected here. The split is by scene, so augmented and
video-adjacent copies of a photograph never straddle the training and
validation sets (§3.3.5). Photographs shared between sources were searched for
and found only on the training side (§3.3.7). Missing labels were completed in
the training split only; the validation labels every headline figure is scored
against were never altered (§3.5.4). The AI Builders source was kept in its own
tree rather than merged, so its arrival could not redraw the split. And the
tape-measured captures were never used for training, tuning or model
selection: they are stored in a separate directory tree and used only for
evaluation (§3.7.1).

### 3.5.6 Evaluation metrics and why they were chosen

Table 3.10 lists every metric reported in Chapter 4, what it measures, and why
it was chosen over the alternatives.

Table: Table 3.10: Evaluation metrics and the reason for each

| Metric | Objective | What it measures | Why chosen |
|---|---|---|---|
| mAP50-95 and per-class AP | 1 | ranking quality across all confidence thresholds, averaged over IoU 0.50–0.95 | the standard measure for comparing detectors (Lin et al., 2014); per class because the pooled figure hides the imbalance in Table 3.3 |
| Precision, recall, F1 at confidence 0.30 | 1 | the errors the prototype actually makes at its own threshold | mAP averages over thresholds the prototype never uses; recall matters most for a warning system, because a missed obstacle is silent |
| Confusion matrix; classification accuracy | 1 | whether errors are misses or wrong names | separates a detector that cannot find objects from one that misnames them |
| Recall by object size | 1 | whether misses are explained by small objects | tests one specific explanation of low recall |
| Latency per stage: mean, median, p95; throughput in fps | 1, 3 | where the time goes, typical cost, tail cost | the mean shows the budget, the median resists occasional stalls, and p95 shows the delays a user would notice |
| Parameters and package size | 1 | deployment cost on the device | the third axis of RQ1 |
| MAE | 2 | typical error in metres | directly interpretable against a walking user's distances; less sensitive to single bad frames than RMSE |
| MAPE | 2 | error relative to distance | an error of 0.3 m matters more at 1 m than at 4 m |
| RMSE | 2 | error weighted towards large misses | shows whether occasional large errors dominate |
| Signed bias | 2 | systematic over- or under-estimation | MAE cannot tell a noisy method from a consistently offset one; the difference decides whether calibration could help |
| 95 % bootstrap intervals | 1, 2 | uncertainty from the particular sample of scenes or frames | the samples are small, and a point estimate without an interval overstates what they show |

The distance metrics are defined in §3.7.3.

## 3.6 Objective 1 — latency measurement protocol

Latency is measured on the device, per frame, split into five pipeline stages:
`capture` (YpCbCr → BGRA conversion), `preprocess` (letterbox resize), `detect`
(Core ML inference), and two stages belonging to the decision layer that are
recorded as zero in this study because that layer is outside Objective 1's
scope. Each run is summarised by the mean, median and 95th percentile of each
stage, and by the processed frame rate (Table 3.10).

Each run logs `thermalState` alongside every frame and separates **cold** from
**sustained** operation, with phase transitions at 60 s and 300 s. Runs exceed
15 minutes so that any thermal throttling within the 10–15 minute window
anticipated for sustained camera and Neural Engine use would appear in the
data.

All three models were run in one session on one device under the same ambient
conditions. Ambient temperature was not controlled or logged, which bounds what
the thermal result can claim (§4.1.4).

## 3.7 Objective 2 — distance estimation protocol

### 3.7.1 Capture protocol

Captures span five object classes (`door`, `chair`, `table_edge`, `pole`,
`low_obstacle`) at nine distances from 500 mm to 4500 mm in 500 mm steps, with
repeated measurements at each station. Two lighting conditions were planned;
only the bright condition was captured (§4.2). Distance is measured with a
tape measure laid along the floor from the face of the object to the operator's
standing position, and is **encoded in the filename**, which is the sole record
of ground truth:

```
obj-<class>_d-<mm>_light-<bright|dim>_rep-<n>.{jpg,depth.npy,conf.npy,json}
obj-door_d-2500_light-bright_rep-2.jpg
```

Each capture records four files: the RGB frame, ARKit depth as float32, the
per-pixel `ARConfidenceLevel` map as uint8, and a JSON sidecar carrying camera
intrinsics, resolutions, device attitude and ambient light estimates. RGB,
depth and confidence are all stored in ARKit's native unrotated sensor frame,
matching `camera.intrinsics` exactly.

**Frames are rotated upright before detection.** A phone held in portrait
stores a scene lying on its side, which is outside the distribution of the
upright photographs the detector was trained on. Measured on real captures, the
detector found no box in four object-aimed frames as stored and a box in all
four once they were rotated upright, one chair going from no detection to a
confidence of 0.96. The evaluation therefore detects on the upright frame and
rotates the depth and confidence maps to match (`tools/orientation.py`).

The phone is held at chest height, level, at consistent pitch. Inconsistent
pitch is the largest avoidable source of monocular depth error and is invisible
in the resulting photograph, so the capture application displays a live tilt
indicator.

**Poles were photographed as wall segments.** The detector has no `pole` class
(§3.3.3), so a pole capture could never receive a box of its own class. Pole
frames were therefore taken against a pillar or wall segment, so that the
trained `wall` class could fire in its place; the evaluation accepts that
substitution and flags every frame whose detected class differs from the one
photographed.

The upper bound of 4500 mm is set by the hardware: ARKit `sceneDepth` has a
range ceiling of approximately 5 m. Glass doors were planned as a deliberate
failure case, because they defeat both depth methods.

**Uncertainty in the ground truth.** A tape measure reads to a millimetre, but
the reading is not the dominant uncertainty. The tape runs along the floor to
the operator's standing position, while the camera is held above and slightly
ahead of that point, and `sceneDepth` measures depth along the optical axis
rather than horizontal floor distance. The resulting offset was not measured.
It is plausibly a few centimetres, which means that the smallest errors in
§4.2, such as 0.077 m for doors, are close to the resolution of the ground
truth itself and should not be read more finely than that.

**The capture set is never training data.** It is held-out physical ground
truth and is stored in a separate directory tree.

### 3.7.2 Distance derivation

For each frame, the object's bounding box is obtained from the fine-tuned
YOLO26n detector's own prediction — not from a heuristic region of interest —
and the distance estimate is the **median depth over the lower third of that
box**. Where the detector returns several boxes, a box of the photographed
class (or of its permitted substitute, `wall` for `pole`) is preferred;
otherwise the most confident box of any class is taken. Boxes for the
capture set were taken at a confidence of 0.25, Ultralytics' default, which is
slightly below the prototype's 0.30; five of the 38 boxes fall between the two.

Two choices here are deliberate. The **lower third** is used because indoor
obstacles stand on the floor, and the top of a bounding box frequently captures
background well behind the object. The **median** rather than the mean is used
because a single background pixel bleeding into the region destroys a mean.

Bounding boxes are produced in the RGB frame's pixel space, while the LiDAR
depth map is 256 × 192 and the monocular depth map is at full RGB resolution.
Every region of interest is therefore converted to fractions of the frame and
back to pixels separately for each depth array. Ground-truth values below 250 mm
are rejected as implausible, guarding against a distance mistakenly entered in
metres.

Monocular predictions use the checkpoint's own preprocessing — an
aspect-preserving resize to the next multiple of 14 at or above the target
input size, then bilinear interpolation of the predicted depth back to source
resolution. A square resize would compress a 4:3 capture by 25 % horizontally
before a metric depth model saw it. The evaluation script's default input size
of 518 px applies; the command line of the run was not recorded, which is
noted as a reproducibility gap.

After the evaluation, each detector box was inspected on its frame to record
whether it lies on the photographed object, since a box of another class may
still lie on the right object and a box of the right class could lie elsewhere.
The verdicts, confirmed by the researcher, are in
`results/objective2/box_placement_audit.csv`, and §4.2.1 reports the figures
both with and without the boxes that do not lie on the object.

### 3.7.3 Error metrics

For $n$ frames with tape-measured distance $d_i$ and estimate $\hat d_i$, the
four error metrics are

$$\mathrm{MAE} = \frac{1}{n}\sum_{i=1}^{n} |\hat d_i - d_i|, \qquad \mathrm{MAPE} = \frac{100\%}{n}\sum_{i=1}^{n} \frac{|\hat d_i - d_i|}{d_i} \qquad (3.4)$$

$$\mathrm{RMSE} = \sqrt{\frac{1}{n}\sum_{i=1}^{n} (\hat d_i - d_i)^2}, \qquad \mathrm{bias} = \frac{1}{n}\sum_{i=1}^{n} (\hat d_i - d_i) \qquad (3.5)$$

A positive bias means the method over-estimates distance, which for a warning
system errs in the unsafe direction: an obstacle reported farther away than it
is warns later than it should.

They are reported by method, by 0.5 m distance bin and by object class.
Reporting by bin matters more than the pooled figure: a method whose error
grows with distance and one whose error is uniform can share an MAE while
behaving entirely differently near the user. Intervals are 95 % percentile
bootstrap intervals over frames, 10,000 resamples, and the two methods are also
compared frame by frame on the frames where both produced an estimate
(`tools/distance_uncertainty.py`).

## 3.8 The prototype

The prototype is the instrument through which the results of Objectives 1 and
2 reach a user, and its components were each chosen for a stated reason
(Table 3.11). Figure 3.1 shows how they connect. One learned model runs in the
prototype: the detector, which says what is present and where it is in the
image. Distance comes from a sensor, ARKit's LiDAR depth. Everything downstream
of those two is deterministic code whose behaviour is fixed by the constants in
Table 3.13.

Table: Table 3.11: Prototype components and why each was chosen

| Component | Choice | Why |
|---|---|---|
| Frame source | ARKit session (Apple Inc., n.d.a) | delivers the RGB frame and the LiDAR depth map already registered to each other in one frame |
| Detector | YOLO26n, Core ML, confidence 0.30 | the Objective 1 result (§4.1); the threshold is checked in §4.1.7 |
| Depth source | ARKit `sceneDepth` | the Objective 2 result (§3.8.1) |
| Decision layer | plain value types with no platform dependency | the same code can be verified off the device against planted values (§3.8.4) |
| Haptics | one looping Core Haptics player with dynamic parameters (Apple Inc., n.d.b) | changes intensity, sharpness and pulse rate continuously without rebuilding patterns mid-playback |
| Audio | pre-rendered earcons through `AVAudioEngine` | earcons are short and fast to play (Blattner, Sumikawa and Greenberg, 1989); speech is too slow for the per-frame path |
| Audio session | mixes with other audio | a screen reader must never be silenced by an assistive app |
| Instrumentation | per-frame latency and detection log | makes every claim about the running system checkable from data |

### 3.8.1 Why the depth source was decided here rather than in advance

The decision layer samples one depth source, and which one was deliberately
left open until Objective 2 had produced real measurements. Fixing it in
advance would have meant choosing on the basis of the expected trade-off — the
LiDAR arm faster, the monocular arm more widely deployable — rather than on
what the two arms actually did against a tape measure.

Objective 2 (§4.2) removed the trade-off. On detector-driven boxes, ARKit
`sceneDepth` reached 0.188 m MAE against physical ground truth where
Depth-Anything-V2-Metric-Hypersim-Small reached 1.221 m, and `sceneDepth` also
costs no Neural Engine time, arriving already registered to the RGB frame
inside the same `ARFrame`. Accuracy and latency therefore point the same way,
and the prototype samples `sceneDepth`.

The price is device coverage: this configuration requires a Pro-tier iPhone.
That is RQ2's substantive answer rather than an incidental limitation, and it
is taken up in §5.3.

### 3.8.2 Derived-feature layer

The engineering in this system sits **between the models and the feedback**
(Table 3.12).

Table: Table 3.12: Derived features, as implemented

| Feature | Derivation as implemented |
|---|---|
| Object distance | median `sceneDepth` over the box's lower third, low-confidence pixels discarded |
| Bearing zone | box centroid x → left / centre / right at the frame thirds |
| Hazard weight | class → fixed weight (§3.3.4) |
| Closing rate | least-squares slope of distance against time over a 0.6 s window |
| Time-to-contact | distance ÷ closing rate |
| Urgency score | proximity, boosted by closing speed, scaled by a hazard gain (Equation 3.6) |
| Haptic encoding | urgency → (intensity, sharpness, pulse rate) |
| Announcement gate | 3-of-5 frame confirmation with hysteresis |

**Median rather than mean**, because a single background pixel entering through
a loose box edge moves a mean by metres and a median barely at all. **Lower
third rather than the whole box**, because for a floor-standing object the top
of the box frames the wall behind it; §4.2 measures a residual positive
distance bias for open-framed objects even with this restriction, so the effect
is real and only partly mitigated.

The urgency score for an obstacle at distance $d$, closing at rate $v$, with
hazard weight $h$, takes the form

$$u = \min\!\big(1,\; p(d) + 0.35\, t(d, v)\big) \times \big(0.6 + 0.4\, h\big) \qquad (3.6)$$

where the proximity term falls linearly from 1 at 0.5 m to 0 at 4.0 m,

$$p(d) = \mathrm{clip}\!\left(\frac{4.0 - d}{4.0 - 0.5},\, 0,\, 1\right) \qquad (3.7)$$

and the time-to-contact term falls linearly from 1 at contact to 0 at a
four-second horizon, and is zero for a stationary or receding obstacle,

$$t(d, v) = \begin{cases} \mathrm{clip}\!\left(\dfrac{4 - d/v}{4},\, 0,\, 1\right) & v > 0.05\ \mathrm{m/s} \\ 0 & \text{otherwise} \end{cases} \qquad (3.8)$$

Two properties of that form are deliberate and were arrived at by correcting a
first attempt.

First, **proximity alone can saturate the score.** An earlier form gave
proximity and time-to-contact fixed co-weights summing to one, which capped a
stationary user's urgency below the threshold for the highest warning band: a
staircase half a metre directly ahead was classified "close" rather than "stop"
purely because the user had stopped walking towards it. Being about to walk
into something is urgent whether or not one is moving at that instant, so
closing speed now escalates an already-saturating proximity term instead of
competing with it for a share of the score.

Second, **hazard class acts as a gain, not a multiplier.** Scaling urgency by
the raw class weight would score a chair 0.3 m from the user's shin at 0.3. A
low-hazard *class* is not a low-hazard *situation*. Restricting hazard to a
0.6–1.0 gain lets it rank obstacles competing for a single announcement slot,
following Khilnani and Devesh's (2025) prioritisation argument, without letting
it decide whether an imminent collision matters.

**The basis of each constant.** Every threshold and weight in the decision
layer is listed in Table 3.13 with the kind of basis it has. Three kinds occur:
a constant set by a measurement or by the hardware; a constant set by an
internal-consistency argument; and a constant that is a design choice with a
stated rationale but no empirical basis. The third kind is marked as such
rather than presented as tuned.

Table: Table 3.13: Decision-layer constants and their basis

| Constant | Value | Basis | Kind |
|---|---|---|---|
| Detector confidence threshold | 0.30 | macro F1 on validation peaks there and micro F1 is flat from 0.10 to 0.30 (§4.1.7); checked after the fact, not tuned | measured |
| NMS IoU threshold | 0.45 | Ultralytics' export default | convention |
| Maximum range of the proximity term | 4.0 m | inside the ~5 m LiDAR ceiling, leaving the least reliable metre out; the tape-measured validation stops at 4.5 m | hardware and measurement |
| Saturation range | 0.5 m | the nearest distance validated (§4.2); nearer than this every obstacle is immediate | measurement |
| Time-to-contact horizon | 4 s | at comfortable adult walking speeds of 1.27–1.46 m/s (Bohannon, 1997) an obstacle enters the horizon 5–6 m away, before proximity begins to rise, so closing speed escalates a warning earlier rather than duplicating proximity | internal consistency |
| Minimum closing rate | 0.05 m/s | slower changes are treated as stationary, so that small fluctuations in depth are not read as an approach | design choice |
| Time-to-contact boost | 0.35 | caps what closing speed alone can add: an obstacle beyond 4 m, where proximity is zero, can reach at most 0.35, the lowest warning band, however fast it is approached | design choice |
| Hazard gain floor | 0.6 | a chair (weight 0.3) keeps 72 % of its proximity-driven urgency and a staircase all of it, so class ranks obstacles without silencing one | design choice |
| Hazard weights | Table in §3.3.4 | ordering grounded in accident evidence; spacing arbitrary | ordering evidenced, values design choice |
| Warning bands (rising edges) | 0.12, 0.45, 0.70 | spread the score into "ahead", "close" and "stop"; not validated against users | design choice |
| Falling-edge margin | 0.08 | prevents a score on a boundary from switching band every frame | design choice |
| Confirmation gate | 3 detections in 5 frames | removes single-frame false detections at the cost of about 0.1 s at 30 Hz | design choice |
| Track retirement | 8 consecutive misses | slower to forget than to trust, so a briefly occluded obstacle keeps warning | design choice |
| Track association | IoU ≥ 0.25 | survives a walking pan without merging adjacent objects | design choice |
| Closing-rate window | 0.6 s, at least 3 samples | up to 18 samples at 30 Hz, enough to average frame-to-frame depth variation while still responding within a second | design choice |
| Frame-rate cap | 30 ms between processed frames | just under 33.3 ms, so that ARKit's 60 Hz delivery does not alias the cap (§4.3.3) | measured |

The design-choice constants are the ones a participant study would calibrate.
They are defensible as starting points, reasoned from the geometry of the
problem, but they are not a result, and nothing in this thesis should be read
as evidence that they are right.

Both the form of Equation 3.6 and its constants are reasoned design choices,
and **neither is validated against users**. Establishing whether what this
function scores as urgent is what a user experiences as urgent is precisely
what RQ3 would have begun to address; the function must therefore be read as a
designed artefact, not as a tuned result. This is stated again in §5.4 because
it is the single most important qualification on Objective 3.

The announcement gate is not an optimisation. A per-frame detector drops
objects it found in the previous frame as a matter of routine, and driving
haptics or speech straight from raw per-frame detections produces feedback that
stutters several times a second — unusable regardless of detector accuracy, and
not fixable by improving the detector, because the remedy is temporal rather
than visual. The gate requires three detections within a five-frame window
before a track may drive feedback, tolerates eight consecutive misses before
retiring it, and applies asymmetric hysteresis to the urgency band: escalation
is immediate, de-escalation waits until the score has fallen clear of the
threshold it rose through. The asymmetry is intentional for a safety-adjacent
signal — a warning that lags its input is worse than one that occasionally
over-warns.

### 3.8.3 Feedback implementation

Haptics use Core Haptics via a single looping `CHHapticAdvancedPatternPlayer`,
constructed once as a short continuous pulse inside a loop. All three tactile
dimensions are then steered on the live player: intensity and sharpness as
dynamic parameters, pulse rate by moving the loop's end point. Constructing and
scheduling fresh patterns at frame rate was rejected because tearing players
down mid-playback glitches perceptibly.

The three dimensions rise together rather than encoding independent variables.
They are one perceptual dimension — how alarming — expressed redundantly, in
the manner of a single tacton whose parameters co-vary (Brewster and Brown,
2004). That is the choice most likely to survive the poor tactile
discrimination available through a hand-held phone in a case.
Tokmurziyev et al.'s 81.3 % recognition across thirteen distinguishable
patterns (§2.5.3) is an upper bound obtained with a dedicated wearable actuator
and does not transfer to this hardware.

Audio uses earcons synthesised into PCM buffers at engine start and panned by
bearing zone, with cadence rising across the urgency bands so that the audio
and haptic channels agree rather than beat against each other when both are
active. `AVSpeechSynthesizer` is deliberately **kept out of the latency
path**: first-utterance latency runs to hundreds of milliseconds, which against
a detection pipeline of roughly 13 ms (§4.1) would swamp the measurement by an
order of magnitude and make the reported figure a property of the speech
synthesiser rather than of the pipeline. Speech is reserved for object identity
on demand, behind a button.

The audio session is configured to mix with other audio rather than interrupt
it. This matters beyond politeness: a real blind or visually impaired user runs
VoiceOver continuously, and a session category that interrupted other audio
would silence their screen reader — turning an assistive aid into an
accessibility regression. Mixing is a partial mitigation only, since the two
channels still compete for attention; §5.5 returns to this.

Three modes sit behind a runtime toggle — audio-only, haptic-only, both — so
that the approved RQ3 conditions remain switchable and counterbalanced should
the evaluation be run in future work.

### 3.8.4 Verifying the decision layer without a device

The derived-feature layer, the tracker and the depth sampler are implemented as
plain value types with no ARKit, Core ML, Core Haptics or AVFoundation
dependency, so their arithmetic can be checked away from the phone.
`tools/verify_decision_layer.sh` compiles those three sources for macOS and
exercises them against planted values: the letterbox round trip, the
portrait-to-landscape rotation corner by corner, the lower-third derivation, a
planted 2.5 m depth region placed behind a low-confidence majority, the urgency
function's monotonicity and bounds, and the gate's confirmation, retirement and
hysteresis behaviour. All 45 checks pass
(`results/objective3/decision_layer_verification.md`).

The motivation is specific rather than general good practice. The offline
distance pipeline contained a coordinate-space defect that did not raise an
error: one pixel-space box was applied both to a 256×192 depth array and to a
full-resolution monocular map, every region of interest clipped to nothing, and
the resulting absence of readings was logged as a plausible finding about the
sensor's range ceiling (§3.7.2). The live pipeline carries the same class of
hazard twice — letterbox padding, and a rotation between the frame the detector
sees and the frame the depth map uses — and a wrong rotation there does not
fail loudly either; it samples a mirrored region and returns a believable
number. Pinning both transforms to planted values is the response. The harness
also surfaced a second defect during development: a region of interest falling
entirely outside the frame was clamped to a single corner pixel and that
pixel's depth returned as though it were a reading of the object.

What this establishes is bounded, and worth stating plainly: it verifies
geometry and arithmetic, not device behaviour. Latency, the haptic engine and
the audio path are only meaningful when measured on the phone (§3.6).

## 3.9 Reproducibility

All preparation, export and evaluation steps are command-line tools under
`tools/`, and every figure in Chapter 4 traces to a committed artefact:
`results/split_manifest.csv` for the scene-level split, `results/dataset_report.md`
for class counts, `results/objective1_train_metrics.csv` and
`results/objective1_accuracy_table.md` for accuracy,
`results/objective1_latency/` for raw per-stage device logs, and
`results/objective2/` for the distance study. Dataset binaries and device logs
are excluded from version control; the manifests that describe them are not.
Table 3.14 records the software used.

Table: Table 3.14: Software and hardware used

| Component | Version |
|---|---|
| Training | Ultralytics 8.4.147 on a Google Colab T4 GPU; retraining experiments on an Apple M4 with the Metal backend, same Ultralytics version |
| Evaluation and export | Python 3.13.7, PyTorch 2.14.0, coremltools 9.0, NumPy 2.3.5, pandas 3.0.5, matplotlib 3.11.1 (versions in the development environment when the analyses were last run) |
| Application | Xcode 16.4, iOS deployment target 17.0, run on iOS 26.5 |
| Device | iPhone 13 Pro Max, A15 Bionic, 6 GB RAM |
| Random seeds | 0 for training (Ultralytics default); 0 for every bootstrap |

Two gaps are recorded rather than hidden. The Colab runtime's PyTorch and
driver versions were not recorded, which is one reason the two training runs
could differ under the same seed. And the monocular run's exact command line
was not saved, although the script's defaults determine it (§3.7.2).

## 3.10 Validity, and how it was assessed where ground truth was unavailable

Four kinds of validity bear on the conclusions, and each was assessed
differently.

**Internal validity — does each measurement measure what it claims?** Each
pipeline was checked against a known answer before its output was used. The
local evaluation reproduced the Colab AP figures to four decimal places
(§3.5.3). The Core ML exports reproduced the PyTorch predictions on a sample
image (§3.5.2). The distance pipeline recovered a planted 2.5 m region exactly
(§3.8.4). The decision layer passes 45 checks against planted values. And the
local retraining baseline reproduced the Colab model within resampling noise
(§4.1.8).

**Construct validity — are the measured quantities the right ones?** Where a
physical ground truth exists it is used: the tape measure for distance. Where
it does not, the claim is narrowed to what can be verified. There is no ground
truth for urgency, because what counts as urgent is a property of a user's
experience, which this project did not measure. The urgency function is
therefore verified for its properties (bounded, monotonic in distance,
responsive to closing speed, able to reach its top band) and not validated for
its meaning. For detection, the annotations are themselves a fallible ground
truth, and their completeness was audited rather than assumed (§4.1.7), with
every audit verdict confirmed by the researcher.

**Statistical conclusion validity — are differences larger than chance?**
Differences between detectors are read against a paired bootstrap over scenes,
and distance errors carry bootstrap intervals over frames. The small samples
are stated with every figure that depends on them.

**External validity — how far do the results generalise?** Not far, and this
is stated wherever it matters. There was one device, one operator, one building
and one lighting condition, and the detection corpus is small. §5.5 sets out
what each of these limits.
