```{=latex}
\clearpage
\pagenumbering{arabic}
\setcounter{page}{1}
```

# Chapter 1 — Introduction

## 1.1 Problem statement

Indoor environments are the settings in which blind and visually impaired (BVI)
people encounter the obstacles that a long cane detects latest and least well.
A cane sweeps the ground plane ahead of the user and is highly effective for
kerbs, steps and floor-level objects. It is far weaker for hazards that begin
above sweep height, such as a part-open door, a table edge or a protruding
shelf, and it gives no information at all about what an object *is* or how far
away it is until contact is made. Those two pieces of information, identity and
distance, are precisely what a camera and a depth sensor can supply, and some current
phones carry such a sensor, a LiDAR (light detection and ranging) scanner,
beside the camera.

This project builds and measures a smartphone prototype that supplies them. A
phone held at chest height detects indoor obstacles in real time, estimates the
distance to each one, and encodes the result as audio and haptic feedback.

Two boundaries define the work, and both are held deliberately throughout.

**This is obstacle awareness, not navigation.** The system answers "what is near
me, and how close is it?" It does not plan routes, follow paths, or provide
wayfinding. Systems that do those things solve a different problem and are
evaluated against different criteria; conflating the two is common in this
literature and weakens the claims made on both sides.

**The prototype is a supplement to a white cane, never a replacement.** No
result in this thesis should be read as evidence that a phone can substitute for
a primary mobility aid. The cane detects the ground plane reliably and fails
safe; a phone running a neural network does neither.

### 1.1.1 Why the problem matters

The population concerned is large. The World Health Organization (2019)
estimates that at least 2.2 billion people have a near or distance vision
impairment. The harm is also documented rather than hypothetical. In a survey of
307 blind and legally blind adults, Manduchi and Kurniawan (2011) found that 13 %
experienced a head-level collision at least once a month and 7 % a fall at least
once a month, and that 23 % of head-level accidents had medical consequences.
Most of those collisions happened outdoors, but the indoor ones were typically
with doors and cabinets left ajar, with shelves and tables, with the sides of
staircases, and with walls. That list is close to the taxonomy of obstacles
this project detects (§3.3.4). The same survey found that neither
the long cane nor the guide dog protected better than the other against this
class of accident. The gap is therefore one that the primary mobility aids leave
open by design.

### 1.1.2 The research gap

Assistive systems combining a detector, a distance estimate and feedback to the
user are not new, and Chapter 2 reviews fourteen of them. The gap this project
addresses is not the absence of such systems but four specific weaknesses in
how they are evaluated, each of which Chapter 2 establishes from the reviewed
corpus (§2.6, Table 2.2).

1. **Distance estimates are not validated against physical ground truth.**
   Distance accuracy is reported against annotated datasets, against another
   sensor, or, in the closest comparable system, as a boolean (Okolo et al.,
   2025). For a system whose purpose is to tell a person how far away something
   is, the central quantity is left unmeasured.
2. **Accuracy, latency and deployment cost are reported separately**, and
   latency is usually measured at the model rather than across the pipeline on
   the target device. That leaves a builder unable to judge whether a reported
   detector would run as described on a phone.
3. **The haptic channel's contribution is not isolated from audio.** Systems
   combine the two without a controlled comparison.
4. **Feasibility and usability are blurred**, particularly where blindfolded
   sighted participants stand in for BVI users.

The first two gaps are closed by this thesis's measurements, the third is
addressed by a design that was approved but not run (§1.5), and the fourth is
held as a constraint on every claim made here.

## 1.2 Aim

To build and empirically evaluate a smartphone-based prototype for indoor
obstacle awareness that addresses the first two gaps directly. The evaluation
establishes which detection model is deployable on current consumer hardware
when accuracy, on-device latency and deployment cost are measured together;
how accurately distance can be estimated against independently measured
physical ground truth; and how the resulting hazard information can be encoded
in a dual audio-haptic feedback channel.

## 1.3 Objectives and research questions

Objective 1 concerns the YOLO ("You Only Look Once") family of single-stage,
real-time object detectors (Redmon et al., 2016). The objectives below are
those set out in the approved project proposal, with
their delivery status recorded against each (Table 1.1). The proposal separated
core objectives, on which the project's success depends, from stretch
objectives to be pursued only if time allowed.

Table: Table 1.1: Objectives as proposed, and their status at submission

| # | Objective (as proposed) | RQ | Status | Reported in |
|---|---|---|---|---|
| 1 | Assess variations of YOLO for object detection and select the most appropriate with respect to accuracy, latency and computational efficiency for real-time operation | RQ1 | **Complete** | §4.1 |
| 2 | Assess the accuracy, latency and cost of a distance-calculation technique against a given ground truth | RQ2 | **Complete** | §4.2 |
| 3 | Implement a smartphone application detecting obstacles and calculating their distances, with dual audio and haptic feedback | — | **Complete** (prototype built and measured on the device; feedback encoding not validated with users) | §4.3 |
| 4 | Perform an approved ethical evaluation with blindfolded sighted participants undertaking obstacle-awareness tasks in a controlled environment | RQ3 | **Not conducted** (§1.5) | §3.2.4–§3.2.5 |
| a | Use Seeing AI as an indicative reference point on a defined task set | RQ4 | Not attempted | — |
| b | Consider extending the pipeline to outdoor settings | — | Future work only | — |

The research questions, as recorded in the approved ethics application, are:

**RQ1.** What is the most accurate, efficient and low-latency obstacle-detection
method based on YOLO technology for application to mobile-class device use in
indoor settings?

**RQ2.** Which is more efficient from the perspective of accuracy and speed of
implementation — the estimation of distances in the system with or without the
use of additional sensors?

**RQ3.** Is the use of audio-haptic dual-channel feedback more effective than
purely audio feedback in the same kind of system? *(Not answered — see §1.5.)*

**RQ4.** In what ways does the resulting system compare with Seeing AI
(Microsoft, n.d.)? *(Not attempted.)*

RQ1 and RQ2 are answerable by the methodology used and are answered in Chapter
4: RQ1 by a benchmark in which accuracy is measured offline and latency on the
target device, and RQ2 by comparing two depth sources against a tape measure.
RQ3 can only be answered by a participant study, which was designed but not
run, and RQ4 was not attempted. Table 3.1 maps each research question to the
method, data and metrics that address it.

Two deviations from the proposal's stated method are recorded here and
justified in Chapter 3. The proposal named **YOLOv8 and YOLO-NAS** as the
detection candidates; the comparison actually run is YOLOv8n, YOLO11n and
YOLO26n, which share a single toolchain and include a materially newer architecture that needs no non-maximum
suppression (NMS) step (§3.5). The proposal named **MiDaS** as the monocular
depth candidate; Depth-Anything-V2 Metric Indoor Small was used instead,
because it outputs metric depth in metres directly and is therefore comparable
against a tape measure without scale fitting, and because it is available
under a permissive licence (§3.5).

## 1.4 Contribution

Stated in priority order, so that the weight of the thesis is unambiguous:

1. **Distance error measured against independently obtained physical ground
   truth.** Distances are measured with a tape measure and encoded in the
   filename of each capture; the estimate is never validated against another
   model's output or against a dataset's own sensor. The reviewed literature
   does not report this measurement.
2. **A joint accuracy, latency and deployment-cost benchmark** for indoor,
   mobile-only deployment, in which every latency figure is measured on the
   target device and broken down by pipeline stage. It shows that buffer
   handling, which inference-only timings omit, costs about 43 % of the frame.
3. **Evidence that benchmark rank and behaviour in the deployment setting can
   diverge.** The detector that won every photograph benchmark produced
   hazard-relevant false alarms in the corridor where the prototype is used
   (§4.1.8), and only an evaluation in that setting revealed it.
4. **A derived-feature layer** translating detections and depth into a single
   urgency score, with an explicit mapping from that score to Core Haptics
   parameters, verified against planted values.
5. **An explicit separation of feasibility from usability**, maintained in the
   claims as well as in the method.

### 1.4.1 What is contributed beyond implementing existing models

The detectors, the depth network and the phone's sensor are existing
components, and assembling them into an application would not by itself be a
research contribution. The contribution lies in the measurements made with
them and in what those measurements expose. The distance study supplies a
figure the field does not report. The latency study shows where the time goes,
not only how much of it there is. The operating-point evaluation, the
annotation audit and the retraining experiments explain *why* the detector
performs as it does, rather than reporting a single number. The evaluation on
the capture set shows that the ordinary way of choosing a model would have
chosen the wrong one. The application is the instrument that made these
measurements possible, and it is presented as such (§4.3).

### 1.4.2 What differentiates this work from existing studies

Smartphone-only operation is not itself a contribution: DeepNAVI (Kuriakose,
Shrestha and Sandnes, 2023) and PathFinder (Das et al., 2025) are
smartphone-only and predate this work, and both are in the corpus reviewed in
Chapter 2. This ordering deliberately differs from the project proposal, which
listed "using a smartphone-only system that does not require any additional
hardware" first among the claimed novelties. That claim is not supported by
the reviewed literature, and it is corrected here and in §2.6. Table 2.3
compares the closest systems with this one feature by feature. What separates
this work from them is the evaluation, not the architecture: none of the
reviewed systems reports distance error against a physical measurement, a
per-stage on-device latency breakdown, or an evaluation of its detector in the
environment it is deployed in.

## 1.5 Scope, and what was descoped

Objective 4, the ethics-approved evaluation with blindfolded sighted
participants, **was not carried out**. The preparatory work was complete:
approval was granted, the protocol was specified in full (§3.2.4), and the
three feedback conditions were designed to be switchable and counterbalanced.
The decision not to proceed was taken on methodological grounds rather than
purely practical ones.

The approved design provided for five participants across two conditions. That
is sufficient to demonstrate that a system functions; it is not sufficient to
establish that adding a haptic channel improves a user's response, which is
what RQ3 asks. Reporting a five-participant comparison as evidence about a
feedback modality would reproduce precisely the weakness Chapter 2 identifies
in this literature. Dede and Gumus (2025) are cited there for drawing usability
conclusions from four participants, and it would be inconsistent to criticise
that and then do the same. A study large enough to answer RQ3 was not
achievable within the project, and a study too small to answer it was not worth
running.

The available effort was therefore committed to Objectives 1 and 2, which carry
the contribution, and to completing the prototype under Objective 3.

The consequence is stated plainly rather than minimised: **RQ3 is unanswered,
and this thesis contains no participant data of any kind.** The haptic encoding
in Objective 3 is a design artefact with a documented rationale, not an
empirically validated one. Chapter 5 treats this as a limitation, and Chapter 6
as the first item of further work.

The evaluation that *was* approved deserves one clarification, because the
approved ethics form is titled "A Smartphone-Based Navigation Assistant" and
refers to participants performing "navigation and obstacle avoidance tasks".
The delivered scope is narrower than the approved scope. Delivering less than
was approved raises no ethical difficulty, but the two titles are reconciled
explicitly in §3.2.1 so that the record is unambiguous.

## 1.6 Deliverables

- Three fine-tuned detectors exported to Core ML, Apple's on-device inference
  runtime, with a manifest recording
  parameter count, package size and licence for each.
- An on-device benchmark harness producing per-stage latency, thermal state and
  a cold/sustained split.
- An on-device capture application recording synchronised colour (RGB) images, depth from ARKit (Apple's
  augmented-reality framework) and per-pixel confidence, with ground truth encoded in the filename, and the 102
  tape-measured frames it produced.
- The assistive prototype: detection, LiDAR depth sampling, the derived-feature
  layer and switchable audio and haptic feedback, running on the target device,
  together with an off-device verification harness for its geometry and
  scoring.
- A reproducible evaluation pipeline from raw data to every table and figure in
  Chapter 4, including the operating-point evaluation, the annotation audit and
  the retraining experiments.
- This report, with ethics documentation appended.

## 1.7 Guide to the report

**Chapter 2** reviews assistive obstacle-detection systems across four domains,
compares the closest systems with this one, and identifies the gaps this work
addresses. **Chapter 3** sets out the methodology: the research design, ethics,
data sources and their preparation, the two preprocessing pipelines, the
choice of models and the alternatives considered, the evaluation metrics, the
measurement protocols for each objective, and the architecture of the
prototype. **Chapter 4** reports the results for each objective in turn: the
detector benchmark and the experiments that followed it, the distance study,
and the prototype. **Chapter 5** discusses what the findings mean against the
reviewed literature, considers alternative explanations, sets out the
limitations, and addresses ethics, privacy and responsible deployment.
**Chapter 6** returns to the aim, answers the research questions, restates the
contribution and sets out further work, of which the participant evaluation is
the first item.
