# Objective 1 — what moves the numbers (ablation, in progress)

`tools/train_ablation.py` retrains YOLO26n locally (Apple M4, MPS) under the
original recipe, changing one thing at a time. Every variant is scored by
`tools/detection_metrics.py` at the app's operating point (confidence > 0.30,
IoU > 0.5). Results: `results/objective1_ablation/`.

Status, 2026-09-22 16:00: **complete.** Five single changes, mosaic + relabel,
and `full` (mosaic + relabel + aib, AI Builders relabelled too; 3,956 training
images). YOLO26s was not run. See "Not run" at the end.

## 1. The local baseline reproduces the Colab model

Same recipe, same Ultralytics version (8.4.147), same seed; only the hardware
differs.

| | Colab run 2 | local baseline |
|---|---|---|
| best mAP50-95 (training log) | 0.170 | 0.160 |
| micro F1 at 0.30 | 0.280 | 0.281 |
| macro F1 at 0.30 | 0.328 | 0.334 |

Paired bootstrap, baseline − Colab: micro F1 +0.001 (−0.024 to +0.026). At the
operating point the two cannot be told apart, so the variants below are
measured against the local baseline with confidence that it stands in for the
thesis's model.

## 2. Mosaic: a real gain on both photograph sets

`mosaic=1.0, close_mosaic=10, scale=0.5` (Ultralytics defaults), everything
else unchanged.

**Validation split (678 images, 2,435 objects):**

| | baseline | mosaic | mosaic − baseline (95 % CI) |
|---|---|---|---|
| micro F1 | 0.281 | **0.326** | **+0.045 (0.019 – 0.071)** |
| macro F1 | 0.334 | **0.377** | **+0.044 (0.014 – 0.072)** |
| precision | 0.448 | 0.510 | |
| recall | 0.205 | 0.240 | |
| recall at any threshold | 0.416 | 0.498 | |
| recall, small / medium / large | 0.077 / 0.141 / 0.347 | 0.107 / 0.157 / 0.406 | |

F1 rises for every class: chair 0.156 → 0.213, stairs 0.397 → 0.480,
window 0.197 → 0.251, wall 0.682 → 0.739, low_obstacle 0.421 → 0.476,
person 0.224 → 0.244, door 0.286 → 0.296, table 0.308 → 0.318.

**But not on the 84 unaugmented validation photographs:** micro F1 0.289 →
0.282, −0.007 (−0.053 to +0.036). Those are the only upright, natural photos in
the split, so this raised the possibility that mosaic mainly helps on
Roboflow's flipped and rotated copies.

**AI Builders test split (107 natural upright photos, a source neither model
trained on, 369 objects):**

| | baseline | mosaic | mosaic − baseline (95 % CI) |
|---|---|---|---|
| micro F1 | 0.134 | **0.196** | **+0.063 (0.023 – 0.101)** |
| macro F1 | 0.111 | **0.155** | **+0.045 (0.012 – 0.078)** |

On independent natural photographs the gain holds, and is larger. The flat
unaugmented-subset result is most plausibly small-sample noise. Caveat: some AIB
images are consecutive shots (two door-photo sequences), so treating each image
as independent likely makes these intervals somewhat too narrow.

## 3. …which does not reach the researcher's own captures

The 102 tape-measured frames (Objective 2's held-out set, never used for
training), rotated upright, confidence > 0.30. The measure is **frames where
the photographed class is detected** (`predict_boxes.py --conf 0.30`, `expected` match; CSVs in `results/objective1_ablation/captures/`,
with the `pole` → `wall` substitution allowed):

| | Colab run 2 | baseline | mosaic |
|---|---|---|---|
| photographed class found | **12 / 102** | 11 / 102 | 7 / 102 |
| — door (19 frames) | **11** | 8 | **0** |
| — chair (19 frames) | 0 | 0 | **4** |
| frames with any box | 33 | 46 | 55 |

Mosaic stops finding the door, calling it `wall` in 2 frames and nothing in 17.
It starts finding the chair. It also adds wrong boxes on the low-obstacle
frames (wall 10, stairs 7, door 3).

**How much this can carry.** The 19 door frames are one door, shot at nine
distances twice over, and the same goes for each class. Checked by eye: one
wooden apartment door and one dark wooden chair, both in the same tiled
corridor, at every distance. This set is about five
physical objects, not 102 observations. It cannot rank the models. What it
does show is that **a gain measured on two photograph benchmarks did not
appear on the objects this prototype was actually pointed at.** That is
§4.2.1's domain gap again, and it is the strongest argument yet that the next
real improvement is training data from the deployment setting, not another
recipe change.

## 4. Relabel: recall on people and chairs doubles

The training split with 2,204 missing person / chair / table boxes filled in
by a YOLO26x COCO teacher (`tools/relabel_missing.py`). Validation labels
unchanged.

**Validation split, original labels:**

| | baseline | relabel | relabel − baseline (95 % CI) |
|---|---|---|---|
| objects found (of 2,435) | 499 | **623** | |
| recall | 0.205 | **0.256** | |
| precision | 0.448 | 0.348 | |
| micro F1 | 0.281 | 0.295 | +0.013 (−0.020 – 0.042) |
| macro F1 | 0.334 | **0.363** | **+0.030 (0.005 – 0.056)** |

| recall | baseline | relabel |
|---|---|---|
| person | 0.155 | **0.341** |
| chair | 0.098 | **0.198** |
| person, large | 0.122 | **0.468** |
| chair, large | 0.172 | 0.280 |

**This is the strongest result so far, and it is about the data, not the
model.** Recall is measured only against objects the annotators *did* label.
So the doubling is not an artefact of the new labels. The model now finds
twice as many of the originally labelled people and chairs, because it has
stopped being taught that the unlabelled ones are background. It also removes
the anomaly §5.2.2 and the audit pointed at: large people go from the hardest
size band (0.12) to the easiest (0.47). That turns the annotation-quality
explanation from a suspicion into a tested one, for `person` and `chair`.

**The precision drop is expected, and has not yet been measured properly.**
Spurious boxes rise from 544 to 1,091, and person precision falls from 0.40 to
0.16. A model trained to find every person now finds the people the
*validation* annotators also skipped, and each of those is charged as a false
positive. The audit found exactly those unlabelled people in validation. The
check is scoring against a teacher-completed copy of the validation labels
(running). That check is secondary, because the same teacher built the
relabel training labels.

**The secondary check: scored against teacher-completed validation labels.**
The same YOLO26x rule (confidence ≥ 0.5, no overlap ≥ 0.3 with any existing box)
added **793 boxes to the 678 validation images: 605 person, 176 chair,
12 table**. Validation had 367 labelled people, so its annotators missed most
of the people in these photographs.

| completed labels (3,228 objects) | baseline | mosaic | relabel |
|---|---|---|---|
| precision | 0.492 | 0.555 | **0.593** |
| recall | 0.170 | 0.197 | **0.329** |
| micro F1 | 0.252 | 0.291 | **0.423** |
| person precision / recall | 0.67 / 0.10 | 0.65 / 0.10 | 0.67 / **0.54** |

relabel − baseline micro F1 +0.171 (0.134 – 0.212), scene-level bootstrap.
mosaic − baseline +0.039 (0.017 – 0.061), consistent with the original labels.

Read with care. This set favours relabel by construction, because one teacher
wrote both relabel's extra training labels and these extra validation labels.
Two things in it do not depend on that:

- relabel's precision is higher than baseline's here, not lower. So the drop
  on the original labels is the model finding people the validation
  annotators skipped, which is the direction the audit predicted.
- Even the **baseline's** person precision is 0.67 against completed labels,
  against 0.40 on the original ones. The thesis's operating-point figures
  (§4.1.7) understate person precision substantially. That strengthens the
  caveat already written there: the spurious count is an upper bound on false
  alarms.

**AI Builders test split:** micro F1 0.134 → **0.191** (+0.057, 0.018 –
0.096), macro 0.111 → 0.141 (+0.031, 0.003 – 0.059).

**Captures:** photographed class found in 8 / 102 frames (door 4, chair 4),
against baseline's 11 (door 8), with far fewer stray boxes (21 frames with any
box, against 46).

## 5. COCO: a small gain, not clearly real

The 3,068 converted COCO images (person / chair / table only) added to training.

| | baseline | coco | coco − baseline (95 % CI) |
|---|---|---|---|
| validation micro F1 | 0.281 | 0.300 | +0.020 (−0.005 – 0.047) |
| validation macro F1 | 0.334 | 0.353 | +0.021 (−0.007 – 0.053) |
| unaugmented micro F1 | 0.288 | **0.318** | (84 images; highest of any variant) |
| AI Builders test micro F1 | 0.134 | 0.180 | +0.047 (0.012 – 0.080) |
| captures, class found | 11 / 102 | 8 / 102 | (chair 7, door 0) |

The feared side effect did not show. COCO's unlabelled doors and windows did
not cost door or window F1 on validation (0.286 → 0.282, 0.197 → 0.213). But the
validation gain does not clear its interval, and it doubles training time.
**Not carried into the combined recipe.**

## 6. AI Builders: the only change that reaches the captures

The AI Builders train + valid splits added to training: 1,242 indoor photographs
of mixed origin (mostly Open Images IDs, plus two door-photo sequences and web
images). Only 4 are shared with the Roboflow source, all on its training side,
so the validation set is not contaminated.

| | baseline | aib |
|---|---|---|
| validation micro F1 | 0.281 | 0.294 (+0.013, −0.012 – 0.037) |
| validation door F1 | 0.286 | **0.371** |
| **captures, class found** | **11 / 102** | **37 / 102** |
| — door (19 frames) | 8 | **19**, every distance 0.5 – 4.5 m, median confidence 0.84 |
| — chair (19 frames) | 0 | **14**, out to 3.5 m, median confidence 0.89 |

On the Roboflow validation set aib is neutral overall. It helps doors and costs
nothing measurable. On the researcher's own captures it is the only change that
moves anything: the door is found at every distance, and the chair, which no
earlier model found once, in 14 of 19 frames. The AI Builders test figure for
this variant (micro F1 0.293) is not comparable to the others, because aib
trained on the other two splits of that source.

Limits. The capture set is about five physical objects, so "37 / 102" is five
objects' worth of evidence, not 102 frames' worth. `pole` is still found only
through the `wall` stand-in (4 frames); no real `pole` box appeared. And aib
over-predicts `wall` on the table-edge and low-obstacle frames (15 and 9),
most likely because its `cabinet` class is mapped to `wall`.

Plausible reason, untested: AI Builders adds 667 doors, including two sequences
of close door photographs, and many plain, evenly lit interiors. That is nearer
to the corridor these captures were taken in than Roboflow's photographs are.
It is the domain gap again, closed a little from the data side.

Licence: AI Builders is GPL-3.0. Training on it has to be declared alongside
Ultralytics' AGPL-3.0; the two are compatible.

## Summary of single changes

| variant | val micro F1 | val macro F1 | AIB-test micro F1 | completed-val micro F1 | captures |
|---|---|---|---|---|---|
| Colab run 2 | 0.280 | 0.328 | 0.124 | 0.263 | 12 |
| baseline | 0.281 | 0.334 | 0.134 | 0.252 | 11 |
| **mosaic** | **0.326** | **0.377** | **0.196** | 0.291 | 7 |
| **relabel** | 0.295 | 0.363 | 0.191 | **0.423** | 8 |
| coco | 0.300 | 0.353 | 0.180 | 0.278 | 8 |
| **aib** | 0.294 | 0.346 | *(in-source)* | 0.263 | **37** |

Each of mosaic, relabel and aib wins somewhere the others do not. mosaic wins
on the benchmarks, relabel on people and chairs, aib on the deployment captures.
That is why the next run combines all three.

## 7. mosaic + relabel: the effects partly stack

| | baseline | mosaic | relabel | mosaic + relabel |
|---|---|---|---|---|
| val recall | 0.205 | 0.240 | 0.256 | **0.277** |
| val macro F1 | 0.334 | 0.377 | 0.363 | **0.385** |
| val micro F1 | 0.281 | **0.326** | 0.295 | 0.305 |
| completed-val micro F1 | 0.252 | 0.291 | 0.423 | **0.434** |
| AIB-test micro F1 | 0.134 | 0.196 | 0.191 | **0.234** |
| recall at any threshold | 0.416 | 0.498 | 0.462 | **0.529** |
| person / chair recall | 0.155 / 0.098 | 0.169 / 0.144 | 0.341 / 0.198 | **0.387 / 0.247** |
| captures: door / chair (of 19) | 8 / 0 | 0 / 4 | 4 / 4 | 1 / **11** |

On the independent AI Builders test the combination beats both parts:
+0.038 over mosaic (0.001 – 0.076), +0.043 over relabel (0.004 – 0.085). On
the original validation labels its micro F1 sits below mosaic's (−0.021,
−0.055 to +0.011). As with relabel alone, that is the relabelled model being
charged for the people the validation annotators skipped. Against the
completed labels it is the best variant. On the captures it keeps relabel's
chair gain (11 of 19) but, like mosaic, nearly loses the door (1 of 19). That
is the gap aib closed, which is why `full` adds it.

## 8. full: best on the photograph benchmarks, and a new failure on the captures

| | baseline | mosaic + relabel | aib | **full** |
|---|---|---|---|---|
| val micro F1 (original labels) | 0.281 | 0.305 | 0.294 | 0.313 (+0.032, −0.002 – 0.066) |
| val macro F1 | 0.334 | 0.385 | 0.346 | 0.376 (+0.044, 0.008 – 0.078) |
| val recall | 0.205 | 0.277 | 0.208 | **0.278** |
| unaugmented macro F1 | 0.338 | 0.368 | 0.329 | **0.388** |
| completed-val micro F1 | 0.252 | 0.434 | 0.263 | **0.446** (+0.194, 0.154 – 0.234) |
| completed-val precision | 0.492 | 0.571 | 0.551 | **0.602** |
| recall, small / medium / large | 0.077 / 0.141 / 0.347 | 0.096 / 0.207 / 0.457 | 0.075 / 0.143 / 0.354 | 0.099 / 0.204 / **0.462** |
| captures: class found | 11 | 12 | **37** | 26 |
| — door / chair (of 19) | 8 / 0 | 1 / 11 | **19 / 14** | **19** / 7 |

(`full` and `aib` trained on AI Builders train + valid, so their AIB-test
figures, 0.355 and 0.293, are in-source and left out of this table.)

On the photograph benchmarks `full` is the best or tied-best model.
Against the teacher-completed labels its precision (0.602) and micro F1
(0.446) are the highest of any variant. It keeps aib's door on the captures,
19 of 19 at every distance.

**But it adds a failure the benchmarks cannot see.** In 20 of the 44 pole and
low-obstacle capture frames, its top box is `door`, and a visual check shows
those boxes cover the **empty tiled floor**. aib has the same fault in a milder
form: its extra boxes on low-obstacle frames are floor-sized `wall` boxes.
(Its `wall` boxes on table-edge frames are on the real object, a small wooden
side table, just misnamed, most likely through the cabinet → wall mapping.)
Both models trained on the AI Builders data, so the floor fault most likely
comes with that source. `full` makes it worse in a hazard-relevant way: `door`
carries hazard weight 0.7 against `wall`'s 0.4. In Assist, a `door` box over
the floor would take its distance from the floor just ahead of the user and
raise a close-range warning with no door present. The same shows on
validation: `full`'s door F1 (0.259) is the lowest of any variant, with door
precision about 0.31 against baseline's 0.40.

The capture set has no box annotations, so this false-alarm rate cannot be
measured, only shown. That is itself a finding. **A benchmark cannot certify a
detector for a setting it has never seen.** The one measurement that caught
this regression is the one taken in the deployment setting.

## Recommendation for the app

**Keep the current model (Colab run 2) in the app.** Three reasons, in order:

1. `full` and `aib` put false boxes on the floor of the corridor the prototype
   was tested in, and `full` names them `door`. For a warning system that is a
   regression in exactly the behaviour a user would feel. No benchmark here
   measures it.
2. Every Objective 2 distance figure and every Objective 3 latency and thermal
   figure in the thesis was produced with the current model. Swapping means
   re-running Objective 2 and re-measuring latency, or describing a deployed
   model the thesis never measured.
3. The strongest gains (relabel's doubled person and chair recall, full's
   0.446 on completed labels) are real, but they are gains on photograph
   benchmarks. §4.2.1 and this ablation both show that benchmark gains do not
   transfer to the deployment setting reliably.

The ablation belongs in the thesis as a finding in its own right, as a new
section after §4.1.7. It shows what moves the numbers (data and augmentation,
not training length), what the annotation audit caused and cured, and why a
detector for this purpose has to be validated where it will be used.

**What would change the recommendation:** box-annotated frames from the
deployment setting. They would make the floor false-alarm rate measurable, and
would be the right training data to remove it. That is option 4 of the
improvement plan, and it remains the researcher's to collect.

## Not run

**YOLO26s** (improvement option 3). It would take about 15 hours on this
machine. The ablation's answer is that data, not capacity, is the binding
constraint: every clear gain came from changing what the model trained on,
and the one architecture-level lever tested (mosaic, an augmentation) helped on
benchmarks and hurt on the captures. A larger model is unlikely to fix a
floor-as-door confusion that comes from the training data.

## What this means for the app — earlier notes

**Update 07:45:** the case for swapping now rests on `full`. If it keeps
aib's capture coverage and mosaic's and relabel's benchmark gains, it is the
model to deploy, subject to re-measuring latency, and to re-running Objective 2
if the distance figures are to describe the deployed model.

**Earlier (19:30), before aib: do not swap the app to the mosaic model on this evidence.** It is better on
both photograph sets. But it loses the one door that Objective 2's strongest
distance result (0.077 m) was measured on, and every distance figure in the
thesis was produced with the current model. Mosaic belongs in the thesis as an
ablation finding. It should go into the app only if a combined recipe also
holds the door, or once deployment-setting data exists to decide on.

## Live comparison on the device, 26 September

All five bundled detectors were run through the Assist pipeline in one session,
in the corridor the captures were taken in. Logs:
`results/objective3/latency_*_1790416*.csv` and `*_1790417*.csv`.

| detector | duration | frames with a confirmed track | frames under 0.8 m | of those, "stop" |
|---|---|---|---|---|
| **yolo26n** (default) | 98 s | 56 % | 446 | **441** |
| 26n+full | 56 s | 59 % | 60 | 51 |
| 26n+aib | 27 s | 68 % | 2 | 2 |
| yolo11n | 31 s | 70 % | 46 | 46 |
| yolov8n | 8 s | 57 % | 0 | 0 |

**The decision layer does what §4.3 says it does.** With the measured detector,
an obstacle inside 0.8 m produced the top warning band in 441 of 446 frames.

**And the session produced a usability finding about the interface, not the
model.** Run in order, the session ended on `yolov8n`, and the prototype then
appeared to have stopped warning at all — it had not; that detector simply
never brought anything within 0.8 m in eight seconds. Assist displayed the
frame rate and thermal state but **never which detector was selected**, so a
picker left on a weak or experimental model is indistinguishable from a broken
prototype. The HUD now names the running detector, in ember with "exp" when it
is one of the two experimental sets, and the status card says so in words for a
screen reader. Cost: one line of chrome. The alternative was a user — or an
examiner at the poster session — concluding that the system does not work.

`26n+aib` is also visible here as the weaker choice for this purpose: 27
seconds in the same corridor produced two frames with an obstacle inside
0.8 m, against 446 in 98 seconds for the default.
