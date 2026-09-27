# Chapter 6 — Conclusions and Further Work

## 6.1 Conclusions

### 6.1.1 The aim, revisited

This project set out to build and empirically evaluate a smartphone-based
prototype for indoor obstacle awareness (§1.2): to establish which detection
model is deployable on current consumer hardware when accuracy, on-device
latency and deployment cost are measured together; how accurately distance can
be estimated against independently measured physical ground truth; and how the
resulting hazard information can be encoded in audio and haptic feedback. The
underlying question was whether a consumer phone can reliably answer *what is
near me, and how close is it* — not whether it can navigate, and not as a
replacement for a cane.

The aim was met for the first two parts and for the build of the third. The
phone answers "how close" well, provided it has a depth sensor and has found
the object. It answers "what" far less reliably than its benchmark scores
suggest. The feedback encoding exists and runs, but whether it helps anyone is
unknown.

### 6.1.2 The research questions and objectives

**RQ1 — which detector.** Of the three nano-scale detectors compared, YOLO26n
is the most accurate (pooled mAP50-95 0.170 against about 0.125), the smallest,
and tied fastest; all three run end to end at over 75 frames per second on the
A15. At the prototype's operating threshold the ranking survives a paired
bootstrap over validation scenes. **Objective 1 is complete.** The answer is
scoped to three models, one corpus and one device.

**RQ2 — with or without an additional sensor.** With. The phone's built-in
LiDAR estimated distance with a mean absolute error of 0.188 m (95 % interval
0.12–0.26 m) against 1.221 m for the monocular network, was closer to the tape
measure in all 35 paired frames, and costs about 1 ms per frame against a full
network forward pass. **Objective 2 is complete.** The monocular network's
error proved to be a systematic offset rather than noise, so the "without"
option is not closed, only unproven.

**Objective 3 — the prototype.** Complete as a build. Detection, LiDAR depth
sampling, a derived-feature layer and switchable audio and haptic feedback run
together on the target device at 29.8 frames per second, and the decision
layer's logic passes 45 checks against planted values. It has not been
evaluated with users.

**RQ3 — does haptic feedback add to audio.** Not answered. **Objective 4 was
not conducted**, for the methodological reason given in §1.5: five
participants cannot answer an inferential question about a feedback modality.

**RQ4 — comparison with Seeing AI.** Not attempted.

### 6.1.3 Principal findings

**The accuracy–latency trade-off did not appear.** YOLO26n won every axis
measured. Model selection for this deployment context is therefore simpler than
the comparison was designed to resolve. That conclusion is better read as
evidence that architectural change has outrun a trade-off that was real when
it was last measured than as a general claim about detector families.

**Accuracy is limited by data, and the detector's errors are misses.** At the
prototype's threshold the best detector names 89 % of the objects it finds
correctly but finds only 21 % of those present. Retraining experiments showed
that completing annotations the source corpus had omitted doubled recall on the
two weakest classes, and that mosaic augmentation, excluded by a design
decision this thesis retracts, added 0.045 micro F1. Neither longer training nor
a larger model was the lever.

**Benchmark rank did not predict behaviour in the deployment setting.** The
model that won every photograph benchmark drew confident door boxes over empty
corridor floor where the prototype is used, and on the tape-measured captures
the prototype's own detector put a box on the photographed object in fewer than
a third of frames and a correctly named one in about one in nine. A detector for a mobility aid needs
validation data from the environment it will run in.

**Benchmarking a model rather than a pipeline flatters the system twice over.**
Pixel-buffer conversion and resizing cost roughly 43 % of pipeline latency,
measured through `AVCaptureSession` and again, independently, through ARKit,
where the two runs gave 43.6 % and 39.9 %. And a detector that never left
`nominal` thermal state across three runs exceeding fifteen minutes reached
`serious` within two to five minutes once the depth sensor, world tracking,
haptic engine and audio engine it ships alongside were running too. In both
cases the component's figure was correct and the deliverable's was worse.

**Built-in LiDAR is accurate on solid surfaces, and its errors come from where
the box lies.** Door distance was estimated to 0.077 m across 0.5–4.5 m, close
to the resolution of the ground truth itself, and 0.113 m over every box that
lay on the photographed object. Chairs were over-estimated in every frame,
because their boxes covered a backrest behind the front edge, seen through its
slats; the table boxes missed the edge that was measured to altogether.
The apparent improvement of accuracy with range was an artefact of which
classes sat in which distance bins.

**The monocular network's failure is calibration, not noise.** It
over-estimated every distance yet ranked them almost perfectly, and an
exploratory recalibration brought its error close to LiDAR's. As delivered it
cannot be recommended; whether a per-device calibration would rescue it is
open.

**Thermal cost is directional but unmeasured in size.** Sustained operation at
`serious` costs frame time in a consistent direction and costs no frames, by an
amount two runs put at 3 % and 18 %. The naive comparison of this data points
the wrong way, because cache warm-up is a larger effect of opposite sign.

**The feasibility–usability line held.** No participant data was collected, so
no feasibility result is presented as a usability one. That is a consequence of
an objective not being carried out rather than a design achievement, and it is
reported as such, but the distinction it preserves is the one Chapter 2 found
the literature blurring.

### 6.1.4 The strength of each claim

Table 6.1 classifies the thesis's main claims by the strength of the evidence
behind them. *Demonstrated* means measured here, with the sample and its
uncertainty stated. *Suggested* means consistent with the evidence but resting
on a small sample, a single condition or a post-hoc analysis. *Potential*
means a possibility the results open but do not test. *Future possibility*
means something that would require work not done here.

Table: Table 6.1: Main claims and the strength of the evidence for each

| Claim | Strength | Basis |
|---|---|---|
| YOLO26n is the best of the three nano detectors on accuracy, size and latency, on this corpus and device | demonstrated | Tables 4.1–4.3; paired scene bootstrap |
| The detector's errors are overwhelmingly misses, not confusions, on its validation set | demonstrated | Table 4.3, Figure 4.1 |
| Buffer handling costs about 40–44 % of pipeline latency in two independent implementations | demonstrated | §4.1.5, §4.3.3 |
| Built-in LiDAR is far more accurate than the monocular network as delivered | demonstrated on 35 frames, one lighting condition, one building | Tables 4.7–4.8, Figure 4.3 |
| LiDAR door distance is accurate to within a few centimetres across 0.5–4.5 m | demonstrated on 17 frames | Tables 4.9–4.10 |
| Completing missing annotations doubles recall on `person` and `chair` | demonstrated for this corpus, one run per variant | Table 4.5 |
| Benchmark rank and behaviour in the deployment setting can diverge | demonstrated as one case | §4.1.8 |
| The full pipeline reaches `serious` thermal state within minutes | demonstrated in two runs | Table 4.13 |
| The lower-third rule over-estimates open or see-through objects | suggested; 13 chair frames | Tables 4.8–4.9 |
| A per-device calibration could make monocular depth usable | suggested; exploratory and post hoc | §4.2.2 |
| Measuring inference rather than the pipeline understates latency across this field | suggested; generalised from two implementations | §5.2.3 |
| The haptic encoding could help a user judge urgency | potential; argued design, no user data | §3.8.2–§3.8.3 |
| A blind or visually impaired person could use the prototype safely as a supplement to a cane | future possibility; requires the evaluations in §6.5 | — |

**The prototype is not ready for deployment.** Nothing in this thesis shows that
it is safe or useful for blind or visually impaired people, and it should not
be used by them outside a supervised, ethically approved study (§5.6).

### 6.1.5 The contribution restated

The contribution of this thesis is the evaluation rather than the application,
and it has four parts, in priority order. First, a measurement of distance
error against independently obtained physical ground truth, which the reviewed
literature does not report: 0.188 m for built-in LiDAR over all boxed frames and
0.077 m for doors. Second, a joint accuracy, latency and deployment-cost
benchmark measured on the target phone and broken down by pipeline stage,
which exposes the share of latency that inference-only reporting hides. Third,
evidence that benchmark rank and behaviour in the deployment setting can point
in opposite directions for an assistive detector, and that annotation
completeness distorts both the measurement and the training of such a detector.
Fourth, a derived-feature layer and haptic encoding, verified for correctness
though not for usefulness, together with an explicit separation of feasibility
from usability in every claim. Smartphone-only operation is not claimed as a
contribution: it was already demonstrated by systems in the reviewed corpus.

### 6.1.6 Reflection on the process

Three things went well and are worth carrying into future work. Deciding the
depth source only after measuring it (§3.8.1) turned what would have been an
assumption into a result. Checking every pipeline against a planted or known
answer before trusting its output caught a coordinate defect that had already
produced a plausible false finding, and an urgency function that could not
reach its own top band. And reporting the thermal result only after a second
run turned a reassuring figure into an honest one.

Two things would be done differently. Several recording gaps, including ambient temperature during thermal runs, the
monocular run's command line and the Colab library versions, cost precision
later that a line of logging would have kept. And the capture protocol planned
dim lighting, glass doors and distances past the range ceiling but captured
none of them; a short pilot session would have shown how long each condition
took and allowed them to be scheduled rather than dropped.

## 6.2 Implications for practice

For a practitioner building a mobile assistive vision pipeline, four things
follow. Instrument latency in stages rather than at the model, because a
framework that hides preprocessing may be hiding a large share of the budget.
Choose among current nano-scale detectors on the evidence rather than assuming a
trade-off, which at this scale may no longer exist. Validate the chosen detector
on annotated frames from the environment of use, because benchmark rank chose
wrongly here. And budget dataset acquisition and annotation as the dominant
risk to the schedule: in this project the most consequential technical
shortfalls came from a licensed dataset that could not be obtained in time and
from labels the source corpus had omitted, not from anything about the models.

## 6.3 Implications for theory and research

Three reporting conventions in this literature warrant revision. Inference
latency is routinely presented as pipeline latency, understating real-world
cost. Distance accuracy is reported without units or error magnitude — in the
limiting case as a boolean — which leaves unevidenced the central claim of a
system whose purpose is to tell a user how far away something is. And detection
precision is reported against annotations whose completeness is not checked,
which measures the annotations as much as the model.

A further gap is one this work could not close: no source in the reviewed
corpus states what latency threshold constitutes "fast enough" for a walking
user, despite the field treating latency as safety-critical. Until such a
figure exists, latency benchmarks in this area can report distributions but
cannot grade them.

## 6.4 Limitations

Set out in full in §5.5, with their consequences for interpretation in
Table 5.1, and not repeated here. The two that most constrain what this thesis
may claim are the absence of any participant data, which leaves RQ3 unanswered,
and the detector's poor transfer to the deployment setting, compounded by four
taxonomy classes with no training instances, which means the delivered
detector misses most obstacles in the setting it was built for and cannot see
one of the hazards its own weighting scheme ranks most highly.

## 6.5 Further work

Each item is tied to the limitation in §5.5 that it would address.

**0. Characterise the thermal penalty with ambient temperature recorded**
(limitation 8). §4.3.4 reports the penalty at sustained `serious` as +3.3 % on
one run and +17.9 % on another, with time-to-`serious` varying 2.5-fold between
them, so the governing variable is almost certainly a starting and ambient
temperature neither run recorded. Settling it needs a thermometer, several
sessions per condition and a fixed walking route. `critical` was never reached
and remains undescribed.

**1. Run the participant evaluation** (limitations 1, 9). Ethics approval exists
and is unused, the audio-only versus audio-plus-haptic comparison is explicitly
authorised, the three feedback modes are switchable, and the protocol is
documented in §3.2.4. It would establish feasibility with blindfolded sighted
participants. A study large enough to answer RQ3, and a later one with blind
and visually impaired participants and co-design of the encoding, would be
needed before any usability claim. Condition order must be counterbalanced.

**2. Close the remaining coverage gap** (limitation 2). Partly done after this
thesis's measurements were complete: the AI Builders source was located and
added in the retraining experiments (§3.3.7, §4.1.8). It supplies `pole` — 36
boxes, enough to name the class but not to train it well — and nothing for
`door_glass` or `handrail`. Those two classes, and a usable quantity of `pole`,
still require purpose-collected data.

**3. Establish a latency threshold for a walking user** (limitation 12, and
§5.2.6). A human-factors study relating walking speed, reaction distance and
feedback latency would give this field the pass/fail criterion it currently
lacks, and would let existing benchmarks, including Chapter 4's, be graded
rather than merely reported.

**4. Corroborate and calibrate the monocular depth arm** (limitation 6). Test it
against an independent depth dataset such as NYU Depth V2 or DIODE, and test the
suggestion in §5.3 that a per-device linear calibration, fitted on one set of
tape-measured frames and evaluated on another, makes it usable on phones without
LiDAR.

**5. Resolve VoiceOver contention** (limitation 10). Any deployment to real
users runs into a screen reader already occupying the audio channel. This is a
prerequisite for work with blind and visually impaired participants, not an
optimisation.

**6. Complete the annotation audit for the remaining classes** (limitation 3).
The audit and relabelling of `person` and `chair` doubled their recall
(§4.1.8). The same treatment is needed for `door`, `stairs`, `wall` and
`window`, which a COCO-pretrained teacher cannot propose and which need human
annotation.

**7. Build an annotated validation set in the deployment environment**
(limitations 4, 17). This is the clearest methodological gap the work exposes
(§5.2.5): the model that won every photograph benchmark draws confident `door`
boxes over empty corridor floor, and only the tape-measured captures caught it.
Those captures carry a photographed class per frame, not annotated boxes, so
they can show such a failure but cannot measure its rate. A few hundred
box-annotated frames from the corridors the system is meant to work in would
make deployment-setting precision and recall measurable, give a selection
criterion that benchmark rank does not supply, and serve as training data
against exactly the false alarms observed.

**8. Fix the sampling rule for open-framed objects** (limitation 16). Replace or
supplement the median of the lower third with a near percentile, the closest
surface in the region, and measure whether it removes the over-estimation on
chairs and tables without introducing floor readings on solid objects.

**9. Complete the capture protocol** (limitations 5, 7, 13). Capture the dim
lighting condition, glass doors, and distances past the 5 m ceiling that the
protocol planned, with more frames per class and distance, so that per-bin and
per-class figures can carry claims.

**10. Repeat the measurements across devices, operators and buildings**
(limitations 11, 17). A second phone model, a second person holding it and a
second building would show which results belong to this configuration and
which generalise.

**11. Compare with Seeing AI** (RQ4). The indicative comparison proposed as a
stretch objective remains possible on a defined task set, and would place the
prototype's behaviour beside a widely used assistive application (Microsoft,
n.d.).
