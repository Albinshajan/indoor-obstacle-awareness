# Remaining work — checklist (as of 26 September 2026)

Written after the retraining experiments. Everything below is either verified
open or verified done; where something is "done", the evidence is named so it
can be re-checked rather than trusted.

**Dates that bind.** Title page carries **1 October 2026**; the signed ethics
form's proposed end date is **5 October 2026**; the draft-thesis milestone
(20 September) has passed. There is **no word limit** (confirmed 21 September).
Whether a *page* limit exists is still unknown — the guidelines deck mentions
one on Slide 24 without giving a figure.

**Submission is three parts** (guidelines deck, Slide 4): Report including the
ethics forms; Code **and** Data (code compulsory, data optional); and a Poster
presented in person **or** a recorded presentation, plus a viva.

Key: **[A]** = only you can do it · **[C]** = Claude can do it, on request ·
**[A+C]** = you supply something, Claude does the rest.

---

## 0a. From the supervisor's checklist pass (26 September) — yours

The thesis was audited item by item against the supervisor's "MSc Dissertation –
Checklist" and revised; the full record is `docs/checklist_audit.md`. Its last
section lists what only you can do. In short:

- [x] **Box-placement verdicts confirmed, 26 September.** Sheets 2 and 3 as
      proposed; #12 and #32–34 overturned (the table boxes cover the whole
      table, not the edge measured to). 30 of 38 boxes lie on the photographed
      object, 11 of them correctly named; the thesis carries these figures.
- [x] **Generative-AI declaration kept as drafted** (researcher's decision, 26 September).
- [ ] **[A] Check the 33 references added this pass** yourself (the checklist asks
      for it); each has a DOI or URL.
- [x] **§6.1.6: the wrong-deadline sentence removed**; the rest of the reflection kept.
- [x] **Information, consent and debriefing sheets added** (from Downloads, the
      versions submitted: 9 July information and consent sheets, 7 July debriefing
      sheet) to `docs/source_documents/ethics_attachments/` and reproduced as
      Appendix A.2–A.4. Two new inconsistencies recorded in §3.2.3: the debriefing
      sheet mentions video recording, and the sheets promise a questionnaire where
      the form says interview.
- [ ] **[A] Read the rebuilt PDF end to end.**

## 0. Blocking, and quick

- [ ] **[A] Unlock the iPhone and plug it in, then install the current build.**
      The app with the two retrained detectors compiles but was never installed
      — both attempts hit a locked device ("developer disk image could not be
      mounted"). Command: CLAUDE.md §10, item 1. Afterwards the free
      provisioning profile lasts **7 days**; re-run the same command when it
      expires.
      *Done when:* the app launches on the phone and the mode strip shows four
      tabs (Assist / Detect / Capture / Benchmark).

- [x] **Audit verdicts confirmed, 26 September.** All three sets reviewed sheet
      by sheet with the researcher; `rater` columns now name them. Detector
      boxes: 21 real / 16 false alarms / 10 unclear (two of the assistant's
      verdicts overturned, and they cancel). Added training labels: 38 of 48
      correct (79 %), against the 92 % the assistant's first pass gave — four
      `person` labels it had passed were rejected. §4.1.7, §4.1.8 and §3.5.4
      now carry the confirmed figures.

- [x] **Confirmed 26 September. [A] Confirm three class-mapping judgement calls** for the AI Builders
      source (§3.3.7): `openedDoor` → `door`, `couch` → `low_obstacle`,
      `cabinet` → `wall`, and the deliberate dropping of `cabinetDoor` and
      `refrigeratorDoor`. These follow the precedents already set for the
      Roboflow source. They affect §4.1.8 only, not any Chapter 4 measurement.

---

## 1. Must be done before submission

### 1.1 Report

- [ ] **[A] Read the new thesis sections end to end.** They were written this
      week and have not been read by you: §3.3.7, §3.5.4, §4.1.7, §4.1.8,
      §5.2.5, the rewritten §4.1.7 caveat, Chapter 6 items 2, 6 and 7, and the
      two new abstract paragraphs.

- [x] **AI Builders added to §3.2.2 (26 September)** — one paragraph, on the
      same reasoning that put the Roboflow set there: a publicly licensed
      dataset of indoor photographs, no personal data beyond the `person` class,
      used only in the §4.1.8 experiments. This is methodology reporting, not an
      ethics action.
      - [ ] **[A] Still yours:** confirm you stand by the standing decision not
            to file a Change in Ethics Approval for training sources beyond the
            two named on the form. Nothing in the thesis asserts that a form was
            filed.

- [ ] **[A] Obtain the ethics approval record for Appendix A.** The signed form
      evidences the *supervisor's recommendation*; the peer-reviewer block and
      the REC decision block are blank. Ask for the approval email or a
      countersigned copy and add it to `docs/source_documents/`. This is the
      oldest open item in the project (CLAUDE.md §4).

- [x] **Length settled, 26 September: no page limit and no word limit.** Nothing
      needs cutting; the cutting guidance in `docs/thesis/README.md` is retained
      only in case a limit is ever imposed. The manuscript is ~41,800 words after the
      26 September checklist pass (counting table cells).

- [x] **Final build checked, 26 September.** PDF (128 pages) and docx build with
      no warnings; contents, list of figures and list of tables generated; roman
      then arabic page numbers; Figures 2.1 and 3.1 redrawn for legibility; ethics
      form embedded in Appendix A; title page reads 1 October 2026. Rendered
      pages were inspected.

### 1.2 Code and data

- [ ] **[A] Decide what "Code and Data" contains.** Code is compulsory and is
      the repository as it stands. Data is optional and large:
      `data/raw/ai_builders_jaiinsom` 375 MB, ablation weights 36 MB,
      `data/processed/relabel` 12 MB, plus the corpora already gitignored.
      Recommendation: submit the repository (code, tools, results, thesis
      sources) and *not* the datasets, with `results/dataset_report.md`,
      §3.3.2, §3.3.3 and §3.3.7 documenting how each source is obtained.

- [ ] **[A] Back the repository up somewhere other than this Mac.** There is
      **no git remote**. Every thesis source file, every result and the only
      copies of the signed ethics PDF and the guidelines deck live in one
      directory on one machine. Decide deliberately: a private remote is the
      obvious answer, but the repository contains two real signatures
      (CLAUDE.md §8 flags this), so a private repository or an encrypted
      archive, not a public one.

### 1.3 Poster or recorded presentation, and the viva

- [x] **Poster and talk updated (26 September).** The printed poster gains one
      line under Result 3 (a second corpus found the object in 37 of 102 frames
      against 12, and boxed empty floor as `door`), paid for by tightening two
      existing sentences — **it was two A5 pages until that was done**, so
      re-check the page count with `--print-to-pdf` after any further edit.
      `build/poster_A5.pdf` rebuilt. The speaking notes and the talk carry the
      operating-point figures, the relabelling result and the floor-as-door
      finding in full, and a "73 frames" error in Panel 5 was corrected to 38.

- [ ] **[A] Choose: poster in person, or recorded presentation plus viva.**

- [ ] **[A+C] Prepare viva answers for the three things most likely to be
      pressed.** Why the evaluation was not run (§3.2.5, and the n=5 reasoning);
      why the app ships the *weaker*-on-benchmarks model (§4.1.8); and what the
      thesis claims about BVI users, which is nothing — feasibility only.

---

## 2. Should be done, in the time available

- [ ] **[A] Run the floor-as-door demonstration on the phone and record it.**
      Open **Detect**, choose `26n+full — experimental`, sweep the corridor
      where the captures were taken. Expect confident `door` boxes over empty
      floor. Then switch to `yolo26n` for comparison. This is the live form of
      §4.1.8's central claim, it takes five minutes, and a screenshot would
      make a strong figure. **[C]** can add it to Chapter 4 once you have it.

- [ ] **[A] Check VoiceOver on the new detector menu.** The picker changed from
      a segmented control to a menu, and the experimental warning line is new.
      The existing UI tests check structure, not speech; §5.5 item 10 already
      limits what can be claimed about VoiceOver.

- [x] **Session handoff written (26 September):** `docs/session_2026-09-26.md`,
      covering 21–26 September, including the five mistakes made this week and
      how each was caught.

- [ ] **[A] Re-read §4.1.8's recommendation and decide whether you agree.**
      The thesis now states that the prototype keeps the measured model. If you
      would rather ship `26n+aib` (37 of 102 frames on the captures, against
      11), that is defensible — but then Objective 2's distance figures and
      Objective 3's latency figures describe a model the app no longer runs,
      and both would need re-measuring. **[C]** can do the re-measurement
      scripting; the device runs are yours.

---

## 3. Optional — further work, not required for submission

- [ ] **[A+C] Box-annotate frames from the deployment corridor.** Chapter 6
      item 7, and the only thing that would make the floor false-alarm rate
      measurable. A few hundred frames. You capture (the Capture tab already
      writes frames); annotation needs a tool such as Roboflow or CVAT.
      **Never** use the 102 tape-measured frames for training.
- [ ] **[A] Thermal characterisation** with ambient temperature recorded
      (Chapter 6 item 0) — a study, not a log.
- [ ] **[A] The participant evaluation** (Chapter 6 item 1). Approval exists and
      is unused. `docs/study/recruitment_message.md` is drafted and still has
      `[DURATION]` and `[DATES]` open; a dry run fixes the first.
- [ ] **[C] YOLO26s.** Not run: ~15 hours locally, and the ablation's answer is
      that data, not capacity, binds.
- [ ] **[C] Retrain with `cabinet` mapped somewhere other than `wall`** to test
      whether that mapping is what makes the AI-Builders models call floors and
      table edges `wall`.

---

## 4. Verified done — do not redo

- Objectives 1, 2 and 3: measured, written up, committed.
- Confusion matrix, precision/recall/F1 at the operating threshold, bootstrap
  intervals, recall by object size (§4.1.7).
- Annotation audit; training-label completion; five retraining variants plus
  two combinations; four evaluation sets (§4.1.8).
- AI Builders source located, licensed, mapped, checked for overlap with the
  Roboflow corpus (4 shared photographs, all on the training side).
- Both retrained detectors exported to Core ML and bundled in the app, with
  `yolo26n` still the default and the experimental ones labelled as such.
- `build_thesis.sh` md / docx / pdf all build, with no editorial notes flagged.
- 6 of 6 accessibility-tree UI tests pass; the device build compiles.
