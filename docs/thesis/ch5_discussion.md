# Chapter 5 — Discussion

## 5.1 What this chapter does

Chapter 4 reported what was measured. This chapter asks why the results came
out as they did, what they mean against the literature reviewed in Chapter 2,
where they agree and disagree with it, which alternative explanations remain
open, and what follows for anyone building in this area. RQ1 is discussed in
§5.2, RQ2 in §5.3, and RQ3, RQ4 and the prototype in §5.4. §5.5 sets out the
limitations and how each bears on interpretation, §5.6 addresses ethics,
privacy, security and responsible deployment, and §5.7 draws out the
implications.

## 5.2 RQ1 — what the detector benchmark adds

### 5.2.1 A dominance result, not a trade-off

The expected shape of a detector comparison is a trade-off curve: a faster
model that gives up accuracy, a more accurate one that costs latency or
footprint. That is the shape He and Saha (2023) found across seven YOLO
architectures, and it is the shape the model-selection literature generally
assumes.

It is not what appeared here. YOLO26n returned the best pooled mAP50-95
(0.170 against roughly 0.125 for both alternatives), the fewest parameters, the
smallest `.mlpackage`, and sustained latency tied for fastest. On this
benchmark there is no axis on which choosing it costs anything.

**Why.** The most likely reason is architectural. YOLO26 removes non-maximum
suppression and the distribution-focal-loss head, and its developers designed
it for edge deployment (Sapkota et al., 2025; Jocher et al., 2026). A model
built to be both smaller and end-to-end can be better on every axis at once
when it is compared with predecessors that were not.

**Alternative explanations.** Three remain open. First, the training settings
were Ultralytics' defaults, which the developers presumably tuned most
recently for their newest architecture, so the comparison may favour YOLO26n
for reasons unrelated to the architecture's merit on this task. Second, the two
training runs share a seed (§3.5.1), so the ranking has not been tested
against different initialisations. Third, the comparison covers one small
corpus. The operating-point bootstrap (§4.1.7) shows that the ranking survives
resampling of the validation scenes, which rules out the simplest alternative,
chance, but not these three.

**Agreement and disagreement with previous work.** The result does not refute
He and Saha: their comparison was outdoor and predates YOLO26 entirely. The
more useful reading is that an NMS-free architecture has changed the shape of a
trade-off that was real when it was last measured, which is an argument for
re-running such comparisons on current architectures rather than inheriting
their conclusions. Their best model reached a precision of 80 % and a recall of
68.2 % on their outdoor dataset; this project's best reached 0.438 and 0.206 at
its operating threshold. The two are measured on different corpora and cannot
be compared directly, but the gap is consistent with the indoor classes here
being harder and the corpus smaller, which §5.2.5 confirms.

The practical consequence for a builder is simpler than the literature would
suggest. On this evidence the newest nano variant is a sound default for indoor
mobile deployment, and the trade-off need not be weighed at this scale — with
the caveat that the evidence covers three models, one corpus and one device.

### 5.2.2 Absolute accuracy is low, and the reason is only partly established

Pooled mAP50-95 across all three models sits between 0.118 and 0.170. That is
low. When the benchmark was first run, four explanations were consistent with
the data and were not distinguished by it: roughly 900 distinct source
photographs sit behind 2,714 augmented training images; training ran for 50
epochs; the annotation quality of the source corpus had not been audited; and
the merged taxonomy might simply be harder than a general-object benchmark,
with classes like `wall` and `window` poorly served by box annotation.

What must not happen is a comparison against the accuracy figures reported
elsewhere in this literature. Okolo et al. (2025) report 91.70 %; that number
is a mean of per-object detection accuracies over nine COCO categories, not a
mean average precision, and placing 0.170 beside 91.70 % would compare
different quantities computed over different class sets. Khilnani and Devesh
(2025) report 53.4 % mAP alongside 71.7 % AP50, and only the former is the same
kind of measurement as the figure reported here — across a different corpus,
which still bars a like-for-like reading.

The per-class picture is more informative than the pooled one, and supports a
narrower claim: `stairs`, the highest-weighted hazard in the taxonomy, reaches
AP50-95 between 0.17 and 0.26 across runs, while `person` and `chair` sit
consistently lowest. That `person` should be weak is surprising, as it is
usually among the easiest classes, and it pointed at the source corpus's
annotation quality as the first thing to check before attributing the result to
model capacity.

The operating-point evaluation (§4.1.7) narrows the question. At the
prototype's threshold, YOLO26n names 89 % of the objects it finds correctly but
finds only 21 % of those present, and no threshold lifts recall above 41 %.
That weakens one part of the fourth explanation: classes that look alike, such
as window and door or chair and table, are rarely confused, so the taxonomy is
not hard in the sense of being confusable. The other part, that box annotation
serves classes like `window` poorly, survives. The deficit lies in finding
objects, and the first three explanations are all consistent with that. So is
the size gradient in recall, which runs from 0.07 for small objects to 0.36 for
large ones. One observation leans towards annotation quality. Large people are
found less often than medium-sized ones, the reverse of every other class with
instances of both sizes. That is the pattern inconsistent labelling of large,
partly visible people would produce. §5.2.5 reports the experiment that tested
it.

### 5.2.3 Preprocessing is not a rounding error — a methodological finding

The finding with the widest applicability beyond this project concerns where
the time actually goes. Averaged across all three detectors, pixel-buffer
conversion and letterbox resizing together cost 5.4–5.6 ms per frame against
7.2–7.4 ms for Core ML inference. Non-inference buffer handling is **roughly
43 % of end-to-end pipeline latency**, and a second, independent
implementation through ARKit and Core Image reproduced the proportion at 43.6 %
and 39.9 % on two runs (§4.3.3).

This matters because of how latency is customarily reported in this
literature. A figure such as Zhao and Zhang's (2023) 8 fps, or any claim of
real-time operation, is reported at the level of the system; what is usually
measured is the detector. The gap between the two is not small, and it is
invisible unless the pipeline is instrumented in stages. If the proportion
measured here held elsewhere, a system reporting 7 ms of inference and implying
140 fps would deliver closer to 80 fps end to end.

**An alternative explanation** is that these two implementations are simply
inefficient, and that a buffer path written with Apple's accelerated image
libraries, or one that let the neural engine consume the camera format
directly, would shrink the share. That is possible and was not tested. The
finding is therefore stated as what these two independent implementations
measured, not as a law. The recommendation that follows holds either way:
report per-stage timings, or report end-to-end timings, but do not report
inference latency as though it were pipeline latency. The one reviewed system
that reports end-to-end latency, about 150 ms per frame for a transformer
detector on a smart cane (Khilnani and Devesh, 2025), shows how far apart
systems in this field can be once the whole pipeline is counted.

### 5.2.4 Thermal behaviour: an absence, carefully bounded

Sustained camera and Neural Engine load was expected to induce thermal
throttling within 10–15 minutes. Across three runs each exceeding fifteen
minutes — the longest 1,423 seconds and 42,675 frames — `thermal_state` never
left `nominal`, and latency drifted by no more than 0.4 ms between the cold and
sustained phases.

Two independent observations agreeing (no state change, no drift) is stronger
than either alone, and the instrumentation is confirmed working rather than
silently failing: the phase transitions occur exactly at the designed 60 s and
300 s marks. The claim that follows is nonetheless narrow. Ambient temperature
was neither controlled nor recorded, and the phone sat in open air rather than
in a pocket or a case. The finding is that **nano-scale detectors do not
thermally throttle an A15 under these conditions**, not that thermal limits are
irrelevant to this class of system. A larger model, a warmer room, or a phone
held against the body could each change it.

The detector-only benchmark also left out everything else the prototype runs,
and that omission proved decisive (§4.3.4). Running the
complete pipeline, with ARKit world tracking, the LiDAR sensor, a continuously
playing haptic engine and an active audio engine alongside the detector, the
device reached `fair` within one to two and a half minutes and `serious` within
two to five. The detector-only absence was real; it was also a property of the
component rather than of the deliverable.

**The generalisable point is about benchmarking practice, not about this
handset.** A reassuring thermal result obtained from a detector in isolation
materially understates the thermal load of the system that detector ships
inside — by an order of magnitude in time-to-`serious` here. That parallels
§5.2.3's finding about preprocessing almost exactly: in both cases, measuring
the model rather than the pipeline produced a number that flattered the system,
and in both cases the error was one of scope rather than of technique. Any
reader of this literature should ask of a reported thermal or latency figure
what else was running when it was taken.

The design consequence for Objective 4 is sharper than §3.2.4 assumed.
Counterbalancing feedback-condition order was justified against throttling
within ten to fifteen minutes; at two to five minutes to `serious`, a
participant running two conditions back to back would have had the second in a
measurably hotter regime. The precaution was correct and the margin was far
thinner than the benchmark suggested.

The cost of that state is where a single measurement would have misled. A
3.4-minute run put it at **+3.3 % of frame time**, which on its own would have
supported calling it negligible. A 6.1-minute run conducted specifically to
test that figure put it at **+17.9 %** (§4.3.4). The two differ by a factor of
5.4 on the same build, device, model and feedback condition, so no claim of
negligibility can be made.

What survives both is narrower and still worth having: **the frame rate is
unaffected** — exactly 30.0 processed frames per second throughout `serious` in
both runs, across 137 seconds of combined operation in that state, no dropped
frames — and the latency effect is consistently upward. What does not survive
is any figure for how large it is.

The disagreement is itself informative. Time to reach `serious` also varied
2.5-fold between the two runs, 121 s against 308 s. The dominant variable is
therefore almost certainly starting and ambient temperature, which this study
neither controlled nor recorded. A quantity that moves 2.5-fold between runs
under an unrecorded variable cannot carry a precise claim about its
consequences, and reporting the smaller of two numbers because it was measured
first would be a choice about presentation rather than about evidence.

Getting to that answer required controlling a confound that points the wrong
way, which is worth recording because it would be easy to publish the
uncontrolled version. Across all frames, the `nominal` window shows a *higher*
mean latency than the `serious` window — heat apparently making the device
faster. The `nominal` window is almost exactly the cold phase, and the
pixel-buffer stage costs 5.28 ms cold against 3.34 ms warm as Metal and Core
Image caches fill, which is a larger effect than the thermal penalty and
opposite in sign. A thermal claim drawn from an uncontrolled comparison of this
data would have been not merely imprecise but inverted.

What remains open is the magnitude: what the penalty is once ambient
temperature is held constant. Answering it means recording ambient temperature
and running several sessions per condition, which is a thermal-characterisation
study in its own right. `critical` was never reached in any run, so nothing here
describes the top of the scale.

### 5.2.5 What the retraining experiments settle, and what they do not

§4.1.8 turns three of this chapter's open questions into answered ones and
raises a fourth that matters more than any of them.

**The annotation explanation is no longer a suspicion.** §5.2.2 listed
annotation quality among several untested explanations for `person` and `chair`
being the weakest classes. Completing the missing labels in the training split
doubled recall on both, measured against the unchanged validation labels, and
removed the size anomaly in which large people were harder to find than
medium-sized ones. This does not exonerate the other explanations — corpus
size and training length remain plausible contributors to the low absolute
level — but for these two classes the mechanism is now demonstrated rather
than hypothesised: a detector taught that visible people are background learns
not to find them.

**The low figures partly reflect the reference annotations.** The precision reported
in §4.1.7 is measured against a ground truth that omits most of the people in
its own photographs: 605 unlabelled people across 678 validation images,
against 367 labelled. A benchmark that reports precision against such a
reference reports a number about the annotations as much as about the model.
This agrees with Northcutt, Athalye and Mueller (2021), who found label errors
in the test sets of ten widely used benchmarks and advised caution in choosing
models on test accuracy alone. Their errors were mislabelled examples; the
errors here are missing boxes, which a detection benchmark counts as the
model's false positives. The finding carries theirs over to object detection in
a form that is cheap to check, and it is a reason to audit any detection
benchmark's completeness before drawing conclusions from its precision column.

**One design decision was wrong.** §3.4 excluded mosaic augmentation on the
reasoning that it composes viewpoints a chest-held phone never occupies. The
reasoning is sound about viewpoints and the outcome contradicts it: mosaic is
the single largest benchmark gain measured here, and it lifted small-object
recall. That agrees with the argument made when mosaic was introduced, that
mixing four images lets a detector learn objects outside their usual context
and at smaller scales (Bochkovskiy, Wang and Liao, 2020). Where an
augmentation's plausibility and its measured effect disagree, the measurement
should win, and the decision should have been tested rather than argued.

**The fourth finding is the one that generalises.** The best model on every
photograph benchmark — the combined recipe, ahead by 0.194 micro F1 against
completed labels — draws confident `door` boxes over empty floor when pointed
down the corridor where this project's own captures were taken. Any selection
procedure resting on those benchmarks would have chosen it. Only the
evaluation carried out in the deployment setting rejected it, and that
evaluation exists here only because Objective 2 required tape-measured
captures for a different purpose.

This is an instance of a well-documented problem. Koh et al. (2021) assembled a
benchmark of distribution shifts that arise in real deployments and showed that
models performing well on data like their training data can degrade
substantially when deployed elsewhere. What this project adds is a case in an
assistive setting, where the failure is not merely lower accuracy but a
specific, hazard-relevant false alarm, and where the shift is between public
photographs and a chest-held phone in an ordinary corridor. An alternative
explanation, that the floor-as-door failure is peculiar to this corridor's
polished tiles, cannot be ruled out with one environment; but one environment
is enough to overturn a benchmark ranking, which is the point.

The implication for this field is direct. §2.5 records that the reviewed
systems are evaluated on public benchmarks or on small demonstrations, and this
work adds a case in which benchmark rank and behaviour in a real corridor point
in opposite directions. A detector intended for a mobility aid should be
validated on annotated frames from the environment it will run in, and the
absence of such a validation set — here and in the literature — is a gap in
method, not an inconvenience.

### 5.2.6 The threshold that does not exist

Objective 1 has no pass/fail criterion, because the reviewed literature supplies
none. Latency is treated throughout this field as safety-critical — Chapter 2's
Domain A reviews several systems whose contribution is framed in those terms —
yet no reviewed source states what "fast enough" means for a walking user in
metres per second, reaction distance, or milliseconds.

The benchmark therefore reports a distribution and grades nothing. Inventing a
threshold retrospectively would manufacture a pass. The absence is itself a
reportable gap in the field, and closing it is the kind of contribution a
human-factors study rather than a computer-vision one would make.

## 5.3 RQ2 — distance estimation

The gap this objective addresses is narrower and sharper than Chapter 2 first
suggested. It is not merely that distance estimates are validated against
datasets rather than physical measurement — it is that in the closest
comparable system they are not quantified at all. Okolo et al. (2025) report
distance accuracy as a boolean, recording `True` against all nine objects, with
no error magnitude, no units and no stated ground truth. Das et al. (2025)
report reduced mean absolute error relative to comparable approaches, which is
quantified but relative. Against that, reporting error in metres against
tape-measured ground truth, with intervals, is a modest requirement that no
system in the reviewed corpus meets.

**The comparison is not close.** On the same detector-boxed frames, LiDAR's mean
absolute error (0.188 m, 16.1 % MAPE) is roughly a sixth of the monocular
network's (1.221 m, 69.7 % MAPE), the intervals do not overlap, and LiDAR is
closer to the tape measure in every one of the 35 paired frames. The comparison
was framed in advance as accuracy against device coverage, LiDAR being present
only on Pro-line iPhones and a monocular network running anywhere. As
delivered, the monocular network does not offer "works everywhere, a little
less precisely"; a 70 % error is not tolerable at any of the distances this
study covers.

**Why LiDAR is accurate, and where it is not.** Where the detector's box lies on
a solid surface, LiDAR's estimate is unbiased and within a few centimetres of
the tape measure: 0.077 m on doors across 0.5–4.5 m. That agrees in direction
with Luetzenburg, Kroon and Bjørk (2021), who report about ±1 cm for the same
class of sensor when scanning. The larger error here is expected, since this
project reads one frame's depth from a hand-held phone inside a detector's box
and compares it with a floor-level tape measure whose own offset from the
camera is a few centimetres (§3.7.1). LiDAR's errors concentrate where
the sampled region lies behind the surface the tape measured to: every chair
estimate and every table estimate was too far. The explanation is where the
region fell rather than the sensor. The chair boxes covered the backrest, which
stands behind the chair's front edge, and their lower third sees the wall
through the slats; the table boxes covered the whole table rather than its
near edge (§4.2.1), and their lower third fell on the legs and shelf. The
lower-third rule was chosen because it avoids the background above a
floor-standing object (§3.7.2); the data shows that it is sound for a solid
surface facing the camera and biased for open or see-through objects. Because an over-estimate warns late,
the bias errs in the unsafe direction. Sampling a near percentile of the region,
the closest surface in it, rather than its median, is the natural remedy, and
it is untested.

**The range effect was a class-mix effect.** Pooled over classes, LiDAR's error
appears to fall with distance. It does not do so for doors, the one class
present at every distance, and the pooled pattern is explained by the table
boxes, which missed the edge that was measured to, sitting at 0.5–1.0 m
(§4.2.4). This is a caution about binned error
tables in general, including this one: when the classes in each bin differ, a
trend across bins can be a trend across classes. The same caution applies to
the ~5 m range ceiling documented in §3.7.1. The protocol stopped at 4.5 m, so
this data neither shows the ceiling nor contradicts it.

**Why the monocular network fails, and what that implies.** The monocular error
is not noise. The network over-estimated every one of the 38 distances, yet its
estimates track the tape measure almost perfectly in rank (correlation 0.98),
following estimate ≈ 1.19 × truth + 0.77 m. Three explanations fit that
pattern, and this data cannot separate them. The metric scale of a
single-image depth network is tied to the camera geometry of its training data,
and a network given no information about the phone's focal length cannot know
whether it is looking at a near object through a wide lens or a far one
through a narrow lens (Yin et al., 2023). The metric fine-tuning used synthetic
renderings (Roberts et al., 2021), and a real corridor of glossy tiles and
painted walls is outside that distribution. And the evaluation's input handling
may differ from what the checkpoint was tuned for in resolution and aspect
(§3.7.2). All three predict a systematic rather than a random error, which is
what was observed.

An exploratory recalibration, fitted to the other frames and applied to each
held-out frame, reduces the monocular MAE to 0.224 m, close to LiDAR's
uncalibrated figure. That result is post hoc, uses the ground truth it is
evaluated against, and comes from one camera in one building, so it is a
suggestion rather than a finding. But it changes what the comparison says about
device coverage. The claim this data supports is not that monocular depth
cannot work on phones without LiDAR; it is that this network, used as
delivered, does not. Whether a one-off calibration per phone model would make
it work is a testable question, and it is listed as further work (§6.5).

**The binding constraint was detection, not depth.** The detector put a box on
the photographed object in 30 of the 102 captured frames and a correctly named
one in 11 (§4.2.1); `pole` and `low_obstacle` returned nothing usable.
Both depth methods' headline figures are therefore computed over a smaller, and
almost certainly easier, subset of frames than the full capture set — the 38
frames with a box are not a random sample of the 102 attempted. This does not
invalidate the comparison between LiDAR and monocular, which is computed
identically for both methods over the same subset, but it does mean the
headline figures describe accuracy conditional on detection succeeding, not
accuracy across the obstacle-awareness task as a whole. That gap — between
what the detector was trained on and what a chest-held phone in an ordinary
indoor space produces — is the same domain gap §5.2.5 found in another form,
and §5.5 treats it as a limitation in its own right.

## 5.4 RQ3, RQ4, and the prototype

**RQ3 is unanswered.** The evaluation isolating the haptic channel from audio
was designed, approved and prepared (§3.2.4) but not carried out. This is the
single largest gap in the thesis, and it is the gap Chapter 2 identified as
open in the literature: Okolo et al. (2025) combine audio and tactile output
without isolating either's contribution, and no reviewed system does isolate
it. The gap therefore remains open at the close of this work, exactly as found.

The reasoning behind not proceeding bears on how the omission should be read.
The approved design provided for five participants across two counterbalanced
conditions. Such a design can demonstrate that a system is operable; it cannot
support an inferential claim that the haptic channel improves response, and
RQ3 is an inferential question. Chapter 2 criticises this literature for
exactly that overreach — Dede and Gumus (2025) draw usability conclusions from
four participants, and §2.5.4 notes how sharply sample size limits what
follows. Sears and Hanson (2012) make the related point that preliminary
studies with non-representative users cannot carry claims about the intended
users. Having made that criticism, running a five-person study and reporting it
as evidence about feedback modality would have been inconsistent.

The position is therefore that RQ3 requires a study this project could not
mount, not that it requires a study this project neglected. What the project
can show is that the system the study would have evaluated exists and works
(§4.3), which is the necessary precondition for running it at all.

The haptic encoding described in §3.8 — urgency mapped to intensity, sharpness
and pulse rate — is an argued design, not a validated one. Its rationale draws
on Khilnani and Devesh's (2025) case for prioritising obstacles by urgency
rather than presence, on the tacton principle of structuring a tactile message
through its intensity and rhythm (Brewster and Brown, 2004), and on the
evidence from Dede and Gumus (2025) and Tokmurziyev et al. (2025) that the
haptic channel can carry categorical rather than merely binary information.
That is a reasonable basis for a design. It is not evidence that this
particular encoding works.

### 5.4.1 What building the decision layer revealed

Four things emerged from implementing the layer rather than specifying it, and
all four are reportable.

**An urgency score that co-weights proximity and time-to-contact under-warns a
stationary user.** The first implemented form gave the two drivers fixed
weights summing to one. The arithmetic consequence was not anticipated: with no
closing rate, the maximum attainable score fell below the threshold for the
highest warning band, so a staircase half a metre directly ahead was classified
"close" rather than "stop" purely because the user had stopped walking towards
it (§4.3.2). The correction is to let proximity saturate the score on its own
and have closing speed escalate it earlier. The general point transfers beyond
this prototype: in any system that fuses a static and a dynamic hazard term by
apportioning a fixed budget between them, the static term alone cannot reach
the top of the scale, and the situation in which that matters most — a user who
has stopped because something is immediately in front of them — is precisely
the one the system must not under-report. This is a design defect that unit
arithmetic catches and a demonstration does not, because a demonstration is
performed by someone walking.

**The decision layer's ceiling is the detector's recall, not its own
accuracy.** §4.2.1's coverage finding propagates directly into the prototype:
no derived feature can be computed for an obstacle the detector never reports,
and no urgency score exists for a hazard that was never boxed. Two classes make
this concrete. `pole` carries the second-highest hazard weight in the taxonomy
and has zero training instances, and `low_obstacle` — trip hazards, the class
whose consequences are most physical — returned no usable detection on the
captures. The hazard prioritisation in §3.8.2 is therefore implemented but
only partly exercisable: the ranking works, and two of the classes it is
designed to rank near the top cannot reach it.

**Class confusions in the deployment setting reach the hazard weights.** On the
captures, doors were boxed as `wall` in six frames and chair backrests as
`window` in thirteen (§4.2.1). A chair read as a window loses nothing, since
both carry weight 0.3. A door read as a wall drops from 0.7 to 0.4, which lowers
its hazard gain from 0.88 to 0.76 and its urgency by about a seventh at any
given distance. The detector's confusions on its own validation set were rare
(§4.1.7); in the deployment setting they were common, and they lower the
warning for exactly the class the taxonomy ranks above walls. A reader
assessing this prototype should weight detector coverage and confusion above
every parameter of the decision layer, because improving the urgency function
cannot compensate for an obstacle that was never detected, or was detected as
something less dangerous.

**Choosing LiDAR on the evidence sharpens the positioning claim rather than
weakening it.** §3.8.1 settled the depth source on Objective 2's measurement,
and the measurement chose the sensor available only on Pro-line devices. That
constrains the deliverable: this configuration is not a smartphone-only system
in the sense the proposal originally claimed, and the claim is withdrawn rather
than defended. Smartphone-only was never the defensible contribution in any
case — DeepNAVI (Kuriakose, Shrestha and Sandnes, 2023) and PathFinder (Das et
al., 2025) are both smartphone-only and both predate this work, a point §2.6
makes and the proposal's own novelty ordering had wrong. What replaces it is
narrower and supportable: on hardware with a built-in depth sensor, obstacle
distance can be estimated accurately enough to drive graded feedback, and the
monocular alternative that would remove the hardware requirement does not
reach that accuracy as delivered.

**RQ4 was not attempted.** The indicative comparison against Seeing AI was a
stretch objective and is not reported.

## 5.5 Limitations

The limitations are listed individually below and then grouped in Table 5.1 by
the aspect of the work they affect, with the consequence of each for how the
results should be read.

1. **No participant data of any kind.** RQ3 is unanswered, and nothing in this
   thesis constitutes usability evidence. This is stated as a limitation rather
   than managed as one.
2. **Four taxonomy classes have zero training instances** — `pole`,
   `door_glass`, `handrail`, `other` — because the one source carrying them
   could not be obtained in time. `pole` carries the second-highest hazard
   weight in the taxonomy. A system cannot detect a class it was never shown,
   and the delivered detector covers eight of twelve intended classes.
3. **Absolute detection accuracy is low**, and the experiments distinguish only
   some of the candidate explanations (§5.2.2, §5.2.5).
4. **The detector transfers poorly to the deployment setting.** On the
   researcher's own captures it put a box on the photographed object in 29 % of
   frames and a correctly named one in 11 % (§4.2.1), well below its performance on
   the source corpus's held-out images. Every distance figure in §4.2 is
   conditional on detection succeeding, over a subset that is not a random
   sample of the full set.
5. **Lighting coverage is bright-condition only.** A dim-lighting capture
   session was not completed in the time available. This was reported as
   untested rather than approximated by darkening the bright-condition images,
   which would have misrepresented an untested condition as a measured one.
6. **No corroborating depth dataset.** NYU Depth V2 and DIODE were not
   obtained, so the monocular arm rests entirely on the researcher's own
   captures. Those are the stronger kind of evidence, being physically
   measured, but they are a single source.
7. **The LiDAR range ceiling of approximately 5 m** bounds the operating
   envelope, and captures were designed to 4.5 m accordingly, so behaviour near
   and beyond the ceiling is unmeasured.
8. **Thermal behaviour was observed, not controlled** (§5.2.4).
9. **Evaluation on blindfolded sighted participants would have demonstrated
   technical feasibility only.** Had Objective 4 run, its results would not
   have been usability evidence for blind or visually impaired users, whose
   spatial strategies, hazard assessment and cane technique differ
   substantially. The distinction is maintained here in its strongest form, by
   there being no participant claims to qualify.
10. **VoiceOver contention is partly mitigated and not resolved.** Blind and
    visually impaired users run VoiceOver constantly. Two things were done and
    checked. The audio session is configured to **mix with** rather than
    interrupt other audio, so the system cannot silence a user's screen
    reader; a category that interrupted would have turned an assistive aid into
    an accessibility regression. And the interface itself was made
    screen-reader navigable and **verified on the device with VoiceOver
    running** (18 September): the status card is a single element that speaks
    one written-out sentence — class, bearing, distance and closing rate —
    rather than nine separately-focusable fragments, and the camera preview,
    its bounding-box overlays and the frame-rate and thermal telemetry are all
    hidden from the reader, since they are glanceable information for a sighted
    operator that the card already carries in words.

    What remains unresolved is the contention itself. Mixing prevents
    silencing; it does not stop two audio streams competing for one channel and
    one listener's attention, and nothing here establishes what a user
    experiences when an earcon fires mid-utterance. No blind or visually
    impaired user has used this system at all, so its screen-reader behaviour
    is verified as *implemented*, not as *usable* — which is the same
    feasibility-versus-usability distinction this thesis holds everywhere else.
11. **Single device, single operator, single building.** Every latency figure
    comes from one iPhone 13 Pro Max, and every capture from one person holding
    it in one building. Inter-device, inter-operator and inter-site variation
    are unmeasured.
12. **The literature review is purposive, not systematic** (§2.2.1). No
    screening tally or per-database search dates are reported, so the corpus of
    fourteen papers is a reasoned selection rather than an exhaustive one. Every
    claim of absence in Chapter 2 — that distance accuracy is rarely validated
    against physical measurement, that the haptic channel is rarely isolated —
    is therefore a claim about this corpus and the survey it draws on, not a
    census of the field.
13. **Small samples in the distance study.** The LiDAR figures rest on 35
    frames, the door figure on 17, table edge on 4, and each distance bin on 3
    to 5. The bootstrap intervals (Table 4.7) quantify the uncertainty in the
    pooled figures; the per-bin and per-class figures carry more uncertainty
    than their precision suggests, which is why §4.2.4 declines to claim a
    range effect.
14. **Training runs share a seed, and no hyperparameters were searched.** The
    two Colab runs bound run-to-run variation but not the effect of a different
    initialisation (§3.5.1), and every setting was a default or a reasoned
    departure from one. A tuned model of any of the three architectures might
    rank differently.
15. **Limited computational resources shaped the design.** Training ran on a
    free Colab GPU and later on a laptop at about six hours a run, which is why
    each retraining variant was trained once, why larger variants were not
    tried, and why the experiments vary one factor at a time rather than
    crossing them.
16. **Assumptions built into the measurements.** The lower-third sampling rule
    assumes a solid, floor-standing object and is biased for open-framed ones
    (§5.3). The tape measure reads floor distance, not optical-axis depth, and
    the offset between them was not measured (§3.7.1). The hazard weights'
    ordering is grounded in accident evidence but their spacing is not, and
    most decision-layer constants are design choices (Table 3.13).
17. **Representativeness of the data.** The training corpus is photographs of
    rooms and corridors drawn from public images, and the capture set is one
    polished-tile corridor with a small number of objects. Neither represents
    homes, workplaces, clutter, crowds, other flooring, other lighting or
    moving obstacles. The class confusions of §4.2.1 show that the gap between
    the two is already large within one building.
18. **Deployment limitations.** The configuration requires a Pro-tier iPhone
    with LiDAR, which excludes most users on cost alone. The phone reaches a
    `serious` thermal state within minutes. Battery life under continuous use
    was not measured. The detector misses most objects in the deployment
    setting. Nothing here has been validated with the people it is meant for,
    and **the prototype is not ready for use by blind or visually impaired
    people**, as a supplement to a cane or otherwise.

Table: Table 5.1: Limitations grouped by what they affect, and what each means for interpretation

| Aspect | Items | Effect on interpretation |
|---|---|---|
| Dataset | 2, 6, 17 | detection results describe eight classes of a small public corpus; the monocular result has no second source |
| Sample size | 1, 13 | pooled distance figures are reliable to their stated intervals; per-class and per-bin figures are indicative only; no user-level inference is possible |
| Representativeness | 11, 17 | results describe one device, one operator, one building and bright light; they should not be read as typical of indoor environments |
| Model | 3, 14 | the ranking holds for these defaults and this seed; absolute accuracy is low, and a tuned model could perform differently |
| Evaluation | 4, 5, 7, 8, 9 | distance accuracy is conditional on detection; dim light, the range ceiling and the thermal penalty are unmeasured; any participant result would have shown feasibility only |
| Computational resources | 15 | the retraining findings rest on one run per variant; small differences are not evidence (§3.5.4) |
| Assumptions | 16 | over-estimates on open-framed objects, and errors of a few centimetres, reflect the sampling rule and the ground truth as much as the sensor; the urgency behaviour reflects design choices, not measurement |
| Generalisability | 4, 11, 12, 17 | the benchmark-versus-deployment finding is one case; the review's claims of absence are claims about its corpus |
| User testing | 1, 9, 10 | no claim about usability, preference or safety for BVI users can be drawn |
| Deployment | 7, 8, 18 | the system demonstrates technical feasibility on one handset; it is not a deployable aid |

## 5.6 Ethics, privacy, security and responsible AI

A system intended for people who cannot see what the camera sees raises ethical
questions beyond those the ethics application addressed, because its user
cannot check its output against their own perception. This section considers
them under the headings a responsible deployment would need to answer.

**Ethical conduct of this project.** The project operated under a supervisor's
signed recommendation of low risk (§3.2). No human participant took part, no
personal data was collected from anyone other than the researcher, and every
dataset and model was used under its published licence: CC BY 4.0 for the COCO
annotations and the Roboflow set, GPL-3.0 for the AI Builders set, Apache-2.0
for the depth network, and AGPL-3.0 for the detectors, whose copyleft extends
to the application source (§3.5). Where the delivered work diverged from the
approved form, the divergence is recorded rather than smoothed over
(§3.2.1–§3.2.3).

**Privacy.** A camera that runs continuously in a user's home or workplace sees
other people, documents and screens. The design limits what that exposure
amounts to: detection, depth sampling and feedback all run on the device, no
frame is transmitted anywhere, and the prototype stores only a log of timings
and detected class names, never an image. That is a property of this
prototype's design rather than a guarantee. A future version that added cloud
scene description, as LLM-Glasses does with GPT-4o (Tokmurziyev et al., 2025),
would send images of bystanders to a third party, and would need a lawful basis
and a consent model for doing so. In the capture set, the only person visible
is the researcher (§3.2.2).

**Data protection and governance.** The capture data contains no personal data
of anyone but the researcher and was stored locally. A participant study would
have processed personal data about identifiable people in the UAE, and so would
fall under the UAE's Personal Data Protection Law, Federal Decree-Law No. 45 of
2021 (United Arab Emirates, 2021), as well as the University's research ethics
procedures. The protocol's choices of written notes rather than video, a
seven-day withdrawal window with deletion, and no recording of participants
(§3.2.3–§3.2.4) are the data minimisation such a study would need. Dataset
provenance is recorded for every image (§3.9), which is the governance a later
audit of the training data would require.

**Security.** The application makes no network connections and holds no
credentials, which removes the usual attack surfaces. Two risks remain. A
modified build could carry a detector that suppresses a class, and in an
assistive device, suppressing warnings is the harm that matters; only the
platform's code signing protects against that. And a camera-based detector can
in principle be fooled by patterns placed deliberately in the environment.
Neither risk was tested, and both would need attention before any distribution
beyond a research prototype.

**Bias and fairness.** Three forms of unfairness bear on this system. The first
is access: the accurate depth path needs a Pro-tier iPhone, which prices out
many of the people who might benefit, and the monocular alternative that would
widen access does not work as delivered (§5.3). The second is uneven detection.
Pedestrian detectors have been shown to perform worse on people with darker
skin tones (Wilson, Hoffman and Morgenstern, 2019); this project's `person`
class was trained on a small corpus whose demographic composition is unknown
and was not audited, so whether its detection is equitable is not known. The
third is environmental: the detector saw one building, and the class confusions
of §4.2.1 show that its behaviour depends on flooring, furniture and lighting,
so users in unfamiliar or less typical environments may be served worse. None
of these was measured, and each is stated so that it is not assumed away.

**Potential harms and misuse.** The most serious harm is over-reliance. A user
who trusts the system may attend less to the cane, yet the system misses most
obstacles in the deployment setting (§4.2.1), cannot detect poles or glass at
all, and over-estimates distance to open-framed objects, which warns late. A
system that is silent because it has missed something is indistinguishable, to
its user, from one that has found nothing. False alarms carry the opposite
risk: a model that announced doors over empty floor, as the best benchmark
model did (§4.1.8), teaches a user to ignore warnings, including the ones that
matter. The positioning of this work as a supplement to a cane, never a
replacement, is a response to the first harm; keeping the measured model rather
than the benchmark winner is a response to the second. Misuse for surveillance
is unlikely given that the prototype stores no images, but the same pipeline
with image logging added would be a person detector running continuously in
private spaces.

**Responsible deployment.** Nothing in this thesis supports deploying the
prototype, and it is not offered for use by blind or visually impaired people
in any environment. Before any such use it would need, at minimum: detection
evaluated on annotated frames from the environments of use, with recall
reported per hazard class (§6.5, item 7); distance accuracy measured in dim
light and near the range ceiling; the thermal penalty characterised; the
feedback encoding evaluated with blind and visually impaired participants,
including their cane and screen-reader use; and a way for the system to tell
its user when it cannot see, such as when the depth sensor returns no confident
reading or the device is throttling. Use in safety-critical settings such as
stairs or roads would need validation beyond all of these.

## 5.7 Implications

**For practice.** The buffer-handling finding (§5.2.3) has immediate
consequences for anyone building a mobile vision pipeline: instrument in
stages, and treat a framework that hides preprocessing as potentially hiding a
large share of the latency budget. The dominance result (§5.2.1) suggests that,
at nano scale, the newest detector can be chosen without weighing a trade-off,
though the evidence covers three models on one corpus. And a detector for a
mobility aid should be chosen on data from its deployment environment, since
benchmark rank alone chose wrongly here (§5.2.5).

**For research.** Three methodological habits in this field deserve revisiting.
Reporting inference latency as pipeline latency understates real-world cost by
a margin that was large in both implementations measured here. Reporting
distance accuracy without units, error magnitude, or independent ground truth —
in the limiting case, as a boolean — leaves the central claim of an
obstacle-awareness system unevidenced. And reporting detection precision
without auditing the completeness of the annotations measures the annotations
as much as the model.

**For the field's framing.** Chapter 2 found that accuracy figures are commonly
reported from evaluations on general-object corpora. Okolo et al.'s nine
obstacle categories are COCO classes, of which three are outdoor vehicles and
none is a door, step, stair or pole. High reported accuracy on such a class set
does not establish competence on the indoor obstacles that carry the highest
consequence on contact, and the distinction is worth stating explicitly
wherever such figures are cited.
