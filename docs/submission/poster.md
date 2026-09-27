# Poster / recorded-presentation content

One source of content for both submission routes. The guidelines deck requires
**either** a poster presented in person **or** a recorded presentation followed
by a viva — this document holds the material either needs, ordered as the
argument should be delivered. Every number traces to a committed artefact; none
is rounded up.

**Route settled 16 Sept: poster, presented in person, at A5.** The drafted
poster is `poster.html` (print-ready PDF at `build/poster_A5.pdf`). An earlier
recommendation here favoured a recording, on the grounds that a poster cannot
convey graded vibration — that remains true and is worth saying aloud at the
session, but the route is decided and this document is now the speaking notes
behind the poster rather than a comparison of the two options.

**The one thing a poster cannot do:** transmit the haptic encoding. Say
explicitly that intensity, sharpness and pulse rate rise together with urgency,
and offer the phone if anyone wants to feel it — that turns the format's
weakness into the reason to stop at the stand.

---

## Panel 1 — The problem, stated narrowly

Around 2.2 billion people live with some form of visual impairment. The long
cane is highly effective at the ground plane, and it has three specific blind
spots: it detects only on contact, it says nothing about *what* an obstacle is,
and it covers nothing above sweep height.

**The question:** can a consumer smartphone answer *what is near me, and how
close*, accurately and fast enough to matter to someone walking?

**What this is not.** Not navigation — no routing, no wayfinding. Not a cane
replacement; a supplement. Not usability evidence: no blind or visually
impaired user has tested this, and no participant data of any kind was
collected.

*Say the boundaries out loud. Most of the reviewed literature does not, and
being the presentation that does is worth more than a larger claim.*

---

## Panel 2 — What was actually done

| Objective | Method | Status |
|---|---|---|
| 1. Detector benchmark | YOLOv8n / 11n / 26n fine-tuned identically on a merged indoor corpus, exported to Core ML, timed per stage on an A15 | Complete |
| 2. Distance validation | ARKit LiDAR vs Depth-Anything-V2 metric depth, against **tape-measured** ground truth, 0.5–4.5 m | Complete |
| 3. Prototype | Derived-feature layer → graded haptics + panned audio, three switchable conditions | Delivered |
| 4. Participant evaluation | Approved, designed, **not run** | Descoped |

**Why Objective 4 was dropped, in one sentence:** five participants across two
conditions yields a demonstration, not a result, and this thesis criticises
that exact overreach in its own literature review.

*Expect a question on this. The answer is methodological, not scheduling, and
it is stronger than an apology.*

---

## Panel 3 — Result 1: the accuracy–latency trade-off did not appear

YOLO26n won **every axis measured**: highest pooled mAP50-95 (0.170 vs ~0.125),
fewest parameters, smallest deployment footprint, and sustained latency tied
for fastest. All three models exceeded **75 fps end-to-end** on the A15, with
**no thermal throttling** across runs over fifteen minutes.

**Latency is not the constraint on this class of system. Accuracy is.**

**The finding that travels furthest:** pixel-buffer conversion and letterbox
resizing accounted for roughly **43% of pipeline latency** — nearly as much as
the neural network. Any latency figure in this literature measured at the model
rather than at the pipeline understates real cost by close to half.

**At the operating point, added 21 September.** mAP averages over every
confidence threshold; the prototype runs at one (0.30). There, YOLO26n
**names 89% of the objects it finds correctly and finds 21% of those present**
— the errors are misses, not confusions — and no threshold lifts recall above
41%. Say this if anyone asks what a 0.170 mAP means in practice.

*Artefacts: `results/objective1_full_table.md`,
`results/objective1_confusion_findings.md`.*

---

## Panel 4 — Result 2: distance, against a tape measure

| Method | MAE | MAPE |
|---|---|---|
| **LiDAR (ARKit `sceneDepth`)** | **0.188 m** | **16.1%** |
| — doors only | **0.077 m** | **4.3%** |
| Monocular (DAv2-Metric-Hypersim-S) | 1.221 m | 69.7% |

The comparison was designed as a trade-off — LiDAR more accurate, monocular
deployable anywhere. It did not resolve that way: monocular error was roughly
**six and a half times larger**, which is not a deficit that trades against
convenience at the distances a walking user must react within.

**Consequence, stated rather than buried:** this class of system can currently
be built honestly only for handsets with a depth sensor. The proposal's
"smartphone-only" framing is withdrawn — and was not defensible anyway, two
systems in the reviewed corpus already being smartphone-only.

**Why this is the contribution.** The closest comparable system in the
literature reports distance accuracy as a **boolean `True`** for all nine of
its objects: no magnitude, no units, no ground truth. Reporting error in metres
against a tape measure, broken down by distance bin, is a low bar the field has
not cleared.

*Artefact: `results/objective2_findings.md`.*

---

## Panel 5 — Result 3: the finding nobody planned for

**The detector found a usable box in only 37% of 102 captured frames.**
`pole` and `low_obstacle` essentially never fired their own class.

Two causes, both traceable:
- `pole` has **zero training instances** — the one licensed source carrying
  poles and door subtypes could not be obtained. It carries the
  second-highest hazard weight in the project's own taxonomy.
- A domain gap between the training corpus's photography and what a
  chest-held phone produces in an ordinary indoor space.

**So the honest summary of the whole project is: the sensing is good enough and
the detection is not yet.** Both headline depth figures above describe accuracy
*conditional on detection succeeding* — the 38 frames with a detector box are
not a random sample of the 102 attempted: 30 of those boxes lie on the
photographed object, and only 11 are correctly named (thesis §4.2.1).

*This is the slide to be unhurried on. Presenting a 37% coverage rate rather
than only the 4.3% door figure is the difference between a report and an
advertisement.*

**What happened when the bottleneck was attacked (23 September).** Seven
retraining runs, one change at a time. Completing annotations the corpus had
omitted **doubled recall on the two weakest classes**; mosaic augmentation —
excluded by an earlier design decision, now retracted — added a further 0.045
micro F1; adding a second indoor corpus took the number of capture frames in
which the photographed object is found from **12 to 37 of 102** (12 is the
model the prototype ships; a like-for-like local retrain gives 11), finding the
door at every distance from 0.5 m to 4.5 m. Do not confuse this with Panel 5's
"37% of 102 frames", which counts frames with *any* usable box.

**And the part worth stopping on.** The model that won *every* photograph
benchmark draws confident `door` boxes over **empty corridor floor**. Only the
evaluation carried out where the prototype is actually used caught it, and the
prototype therefore still ships the model Chapter 4 measured. **A benchmark
cannot certify a detector for a setting it has never seen** — that is the
sentence to leave with an examiner.

*Artefact: `results/objective1_ablation_findings.md`.*

---

## Panel 6 — The prototype

ARKit frame → rotate upright → detect → sample `sceneDepth` in each box → derive
→ feel it.

| Derived feature | How |
|---|---|
| Distance | median depth over the box's **lower third**, low-confidence pixels discarded |
| Bearing | centroid → left / centre / right, panned in audio |
| Closing rate | least-squares slope of distance over a 0.6 s window |
| Time-to-contact | distance ÷ closing rate |
| Urgency | `min(1, proximity + 0.35 × ttc) × (0.6 + 0.4 × hazard)` |
| **Haptic encoding** | urgency → intensity **and** sharpness **and** pulse rate |
| Announcement gate | 3-of-5 confirmation, asymmetric hysteresis |

**The gate is not an optimisation.** A per-frame detector drops objects
routinely; without temporal confirmation the feedback stutters several times a
second and is unusable no matter how good the detector is. The fix is temporal,
not visual.

**Two corrections worth admitting to.** The first urgency function gave
proximity and time-to-contact co-weights summing to one, which made the top
warning band unreachable for a stationary user — a staircase half a metre ahead
read as "close" rather than "stop" purely because the user had stopped walking.
And hazard weight had to become a *gain* rather than a multiplier, because a
chair 0.3 m from a shin is not a 0.3-urgency situation. Both were caught by
arithmetic checks, not by demonstrating it.

**What cannot be claimed:** that the encoding works for anyone. It is an argued
design with no user data behind it.

*Artefact: `results/objective3_prototype.md`.*

---

## Panel 7 — Honest limitations

1. **No participant data of any kind.** RQ3 unanswered. Nothing here is
   usability evidence.
2. **Detector coverage bounds everything.** No urgency score exists for an
   obstacle never detected.
3. **Four taxonomy classes have no training instances**, including the
   second-highest hazard weight.
4. **LiDAR restricts the device** to Pro-tier iPhones.
5. **Dim lighting untested** — the session was not completed, and darkening the
   bright frames to simulate it was considered and rejected.
6. **VoiceOver contention mitigated, not solved.** Real users run a screen
   reader continuously.

---

## Panel 8 — What comes next

**Immediately (hours, not research):** per-stage latency for the full assist
pipeline, and a recorded log of the urgency encoding responding to a physical
approach.

**Then:** run the participant evaluation — the approval exists and is unused,
and the three feedback conditions are already switchable. Obtain a source
carrying `pole` and retrain. Establish what "fast enough" means for a walking
user, which this field has never defined, and which is why Objective 1 has no
pass/fail criterion.

---

## If demonstrating live or on video

1. Open with the **decision trace panel** visible — it shows distance, closing
   rate, time-to-contact, the hazard gain and the urgency terms. Show *why* it
   warns, not just that it does.
2. Walk towards a **door**. It is the strongest class (4.3% MAPE) and the most
   legible obstacle on camera.
3. Switch conditions mid-demonstration — audio-only, haptic-only, both — to
   show the RQ3 instrument exists even though the study did not run.
4. Show an **unconfirmed track** (drawn thin and faded) becoming confirmed, to
   make the announcement gate visible.
5. **Say what the audience cannot perceive**: pulse rate and intensity rise
   together with urgency, and a video cannot transmit that. State it rather
   than hoping it reads.
6. Do **not** stage a `pole` or a low obstacle. They will not fire, that is a
   documented finding, and discovering it live looks like a failure instead of
   a result.
