# 15-minute project summary — speaking brief

For presenting to Dr Ikram Ur Rehman. Timed to 15 minutes with a minute of
slack. Every number here traces to a committed artefact, so you can say "that's
in `results/`" to anything.

**The one framing decision.** Do not say the model is better. You fine-tuned
three existing detectors; YOLO26n winning is a *selection* result on your
corpus, not a contribution to detection. What *is* new is the **measurement** —
distance error in metres against a tape measure, which the reviewed literature
does not do. Lead with that and the talk is defensible throughout.

---

## 0:00–1:30 · The problem (90 s)

Around 2.2 billion people live with some form of visual impairment. The long
cane is highly effective at the ground plane, and it has three specific blind
spots: it detects **only on contact**, it says nothing about **what** an
obstacle is, and it covers **nothing above sweep height**.

So the question: can a consumer smartphone answer *what is near me, and how
close*, accurately and fast enough to matter to someone walking?

**Say the boundaries now, not when asked.** This is obstacle *awareness*, not
navigation — no routing, no wayfinding. It supplements a cane, never replaces
one. And no participant data of any kind was collected, so nothing in the
project is usability evidence. Volunteering that in the first ninety seconds
sets the tone for everything after it.

## 1:30–3:00 · What was built, and the four objectives (90 s)

Four objectives, three delivered:

1. **Benchmark three detectors** — YOLOv8n, YOLO11n, YOLO26n — fine-tuned
   identically on a merged indoor corpus, exported to Core ML, timed per stage
   on the phone. *Done.*
2. **Validate distance against physical ground truth** — the phone's LiDAR
   against a monocular metric-depth network, both measured against obstacles at
   tape-measured distances. *Done.*
3. **Build the prototype** — derived features driving graded haptics and panned
   audio. *Done.*
4. **Evaluate with blindfolded sighted participants.** Ethics approved,
   protocol designed, **not run.** *Descoped.*

Pre-empt objective 4 here rather than waiting: five participants across two
conditions yields a demonstration, not a result — and Chapter 2 criticises that
exact overreach in this literature, so running it and reporting it as evidence
would have been inconsistent.

## 3:00–5:30 · Result 1 — the detector benchmark (2.5 min)

**The expected trade-off did not appear.** YOLO26n won every axis measured:
highest pooled mAP50-95 (0.170 against roughly 0.125), fewest parameters,
smallest deployment footprint, and sustained latency tied for fastest. All
three models exceeded **75 fps** end-to-end on the A15.

> Latency is not the constraint on this class of system. Accuracy is.

**The finding that travels furthest**, and the one to spend time on: **43% of
pipeline latency is not inference.** Pixel-buffer conversion and letterbox
resizing cost nearly as much as the neural network. Measured three times now
across two unrelated code paths — `AVCaptureSession` and ARKit — landing at
43.0%, 43.6% and 39.9%. So any latency figure in this literature taken at the
model rather than the pipeline understates real cost by close to half.

**If asked what 0.170 mAP means in practice** — and this is the better answer,
so offer it: at the single threshold the prototype runs, the detector **names
89% of the objects it finds correctly but finds only 21% of those present**. The
errors are misses, not confusions, and no threshold setting lifts recall above
41%.

**If asked why mAP is low:** dataset availability, not model capacity — and
that is now tested rather than asserted. COCO has no door, stair, pole or glass
class. Four of twelve taxonomy classes carry **zero** training instances. And
when the source corpus's missing annotations were filled in — most of the
people in its own photographs were never labelled — recall on the two weakest
classes **doubled**, with the validation labels left unchanged.

## 5:30–9:00 · Result 2 — distance, the actual contribution (3.5 min)

This is the centre of the talk. Give it the time.

**Why it is worth measuring at all:** the closest comparable system in the
reviewed corpus reports distance accuracy as a **boolean** — `True` against all
nine of its objects. No error magnitude, no units, no stated ground truth. Its
nine "obstacles" are COCO categories, none of them a door, step, stair or pole.

**What was measured:** 102 tape-measured indoor captures, 0.5 to 4.5 m.

| method | MAE | MAPE |
|---|---|---|
| **LiDAR** | **0.188 m** | 16.1% |
| — doors only | **0.077 m** | **4.3%** |
| Monocular (Depth-Anything-V2 metric) | 1.221 m | 69.7% |

**The comparison was designed as a trade-off and did not resolve as one.** The
expectation was LiDAR more accurate, monocular deployable on any handset.
Monocular error came out **6.5× larger** — not a deficit that trades against
convenience at the distances a walking user must react within.

**So the "smartphone-only" claim is withdrawn.** This configuration needs a
depth sensor. Say it plainly: it was not defensible anyway, because two systems
in the reviewed corpus are already smartphone-only and both predate this work.
Naming the hardware the approach actually works on is a more useful result than
asserting it needs none.

**Then volunteer the weakness before being asked.** The detector produced a
usable box in only **37% of 102 frames**. `pole` and `low_obstacle` essentially
never fired their own class.

> The sensing is good enough. The detection is not yet.

Both headline figures therefore describe accuracy *conditional on detection
succeeding* — the 38 frames with a box are not a random sample of the 102
attempted. Of those 38, 30 lie on the photographed object: 11 correctly named, all
doors, and 19 under another name (a chair's slatted backrest read as `window`,
a door as `wall`). The other 8 miss it, including every table box, which
covers the whole table rather than the edge that was measured to. The LiDAR-versus-monocular comparison still holds, because it is
computed identically for both arms over the same frames.

## 9:00–11:30 · Result 3 — the prototype (2.5 min)

Show it. Open the app, point at a door, let him see the distance readout move
and the urgency band change.

The pipeline: ARKit frame → rotate upright → detect → sample LiDAR depth inside
each box → derive → feel it.

Distance is the **median depth over each box's lower third** — the top of a box
frames the wall behind a floor-standing object. Bearing, closing rate and
time-to-contact feed a hazard-weighted urgency score. The haptic encoding maps
that score to **vibration intensity, sharpness and pulse rate simultaneously**;
three switchable feedback conditions are built in for the study that was not
run.

**Two design points worth mentioning**, because they show judgement rather than
just assembly:

- **The announcement gate is not an optimisation.** A per-frame detector drops
  objects routinely; without three-of-five temporal confirmation the feedback
  stutters several times a second and is unusable no matter how accurate the
  detector is. The fix is temporal, not visual.
- **The urgency function's first form was wrong**, and arithmetic caught it,
  not the demo. Giving proximity and time-to-contact co-weights summing to one
  made the top warning band unreachable for a stationary user — a staircase
  half a metre ahead scored "close" rather than "stop" purely because the user
  had stopped walking. Anyone demonstrating the prototype is walking, so the
  broken case never occurs in a demo.

The whole derived layer costs **0.066 ms per frame** — about a hundredth of the
detector — which is why speech stays on a button and out of the measured path.

## 11:30–13:00 · What is honestly unresolved (1.5 min)

Volunteer all of this. It is the part that reads as competence.

- **No participant data of any kind.** RQ3 unanswered. Nothing here is
  usability evidence.
- **Four taxonomy classes have no training instances**, including `pole`, the
  second-highest hazard weight in the project's own taxonomy.
- **The urgency weighting is unvalidated.** No user has confirmed that what it
  scores as urgent feels urgent.
- **Thermal cost is not established.** The full pipeline reaches `serious`
  thermal state within minutes, against a detector alone that never left
  `nominal` in fifteen. But two runs put the latency penalty at **+3.3% and
  +17.9%** — and time-to-`serious` also varied 2.5-fold, which points at an
  ambient temperature never recorded. The frame rate held at 30 fps in both.
  **Report the range, not one number.**
- **Dim lighting untested.** Darkening the bright captures to simulate it was
  considered and rejected.

## 13:00–14:00 · The contribution, in one breath (1 min)

Four things, in priority order:

1. **Distance error against independently measured physical ground truth**,
   which the reviewed literature does not report.
2. A **joint** accuracy, latency and deployment-cost benchmark for indoor
   mobile-only deployment.
3. The **haptic encoding** — urgency mapped to three tactile dimensions at once
   — built and running, though unvalidated.
4. An explicit **feasibility-versus-usability separation**, held throughout.

And the methodological point that outlives the project: **benchmarking a model
rather than a pipeline flatters the system twice** — 43% of latency hidden in
preprocessing, and an order of magnitude hidden in time-to-thermal-throttle.
Ask of any reported figure in this field what else was running when it was
taken.

## 14:00–15:00 · Slack and questions

---

## If there is time, or if asked "what would you do next" (60–90 s)

Seven retraining runs, one change at a time, after the main results were in.
Three things moved the numbers, all of them about data rather than the model:
completing the missing annotations, mosaic augmentation (excluded by an earlier
design decision, now retracted), and adding a second indoor corpus, which took
the number of capture frames where the photographed object is found from 12 to
**37 of 102**.

**Then the part worth telling.** The model that won *every* photograph
benchmark draws confident `door` boxes over **empty corridor floor**. Only the
evaluation carried out where the prototype is actually used caught it, so the
prototype still ships the model this talk reports. If a benchmark and the
deployment setting disagree, the deployment setting wins — and this field has
almost no deployment-setting validation data, which is the strongest piece of
further work the thesis names.

## Questions to expect, and the honest answer

**"Why didn't you run the study?"** — Methodological, not scheduling. n=5 over
two conditions is a demonstration, not a result, and Chapter 2 criticises
exactly that overreach. Approval exists and is unused; the three feedback
conditions are already switchable, so it is the best-prepared piece of further
work in the thesis.

**"Isn't 37% detection a failure?"** — It is the binding constraint, and it is
reported as the headline finding rather than buried. It traces to two causes:
`pole` has zero training instances, and there is a domain gap between the
training corpus's photography and what a chest-held phone produces in an
ordinary room.

**"Why LiDAR if it limits you to Pro iPhones?"** — Because the measurement
chose it, not the assumption. The choice was deliberately deferred until
Objective 2 had data. The hardware restriction is the finding, and the
overclaim it invalidates was withdrawn rather than defended.

**"What's the latency, then?"** — 13.3 ms per frame for the full pipeline at 30
fps sustained, all five stages measured separately on the phone. But there is
**no pass/fail criterion**, because this literature has never established what
"fast enough" means for a walking user. So it is reported as a distribution and
graded against nothing — which is itself a reportable gap.

**"How do I know these numbers are real?"** — Every figure traces to a
committed artefact: the scene-level split manifest, per-class AP with instance
counts, raw per-stage device logs, the distance-evaluation output with a full
capture audit trail of every excluded and relabelled frame, and 45 off-device
checks pinning the decision layer's geometry to planted values.

---

## Three things not to say

1. **"My model is better."** You fine-tuned existing detectors. YOLO26n winning
   is a selection result on your corpus.
2. **"It's smartphone-only."** Withdrawn, deliberately, and for a reason worth
   stating.
3. **Any single thermal percentage.** Two runs disagree 5-fold. Say the range
   and the reason.
