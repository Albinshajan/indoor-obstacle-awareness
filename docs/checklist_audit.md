# Supervisor's MSc dissertation checklist — audit, 26 September 2026

Every item on the supervisor's checklist ("MSc Dissertation – Checklist"),
checked against the thesis as it now stands, with where it is met and what was
changed to meet it. Section numbers refer to the manuscript in `docs/thesis/`.

**Status key.** **Met** — was already met; the evidence is named. **Fixed** —
not met, or not met well, before this pass; changed now. **Partly** — met as
far as the work allows; the gap is stated in the thesis, not hidden. **Yours** —
only the author can confirm it; the list at the end says what to do.

---

## Research problem, aim and contribution

| Item | Status | Where / what changed |
|---|---|---|
| Problem clearly defined and focused | Met | §1.1: obstacle awareness, not navigation; supplement to a cane |
| Why the problem matters | **Fixed** | new §1.1.1: WHO (2019) prevalence; Manduchi and Kurniawan (2011) accident survey — 13 % monthly head-level collisions, 7 % monthly falls, indoor causes matching this taxonomy |
| A research gap, not just a problem | **Fixed** | new §1.1.2: four specific gaps drawn from Chapter 2 (distance never validated physically; accuracy/latency/cost not measured together on device; haptic not isolated; feasibility vs usability blurred) |
| Aim addresses the gap | **Fixed** | §1.2 rewritten to name the gaps it closes; "smartphone-only" removed from the aim (it contradicted the withdrawn claim) |
| Objectives specific, achievable, connected | **Fixed** | Table 1.1 was stale (Obj 2 "In progress", Obj 3 "Partial"); now shows actual status and where each is reported |
| RQs answerable by the method | **Fixed** | §1.3 states which RQs the method answers and which it cannot; Table 3.1 maps each RQ to design, data, variables, metrics and results |
| Original contribution explicit | **Fixed** | §1.4 reordered and extended (benchmark-vs-deployment finding added); restated in §6.1.5 |
| Contribution beyond implementing a model/app | **Fixed** | new §1.4.1 |
| What differentiates from existing studies | **Fixed** | new §1.4.2 and new Table 2.3 (eight closest systems compared feature by feature, every cell sourced) |

## Literature review

| Item | Status | Where / what changed |
|---|---|---|
| Critical analysis, not paper-by-paper summary | Met | Chapter 2 organised by domain, with critique of each figure (e.g. Zhao and Zhang's conflated range effect, Okolo's boolean distance) |
| Recent and relevant literature | **Fixed** | 33 references added, all verified against publisher records or the papers (Appendix G), incl. YOLO26 (2025, 2026), RT-DETR (2024), Depth Anything V2 (2024) |
| Compares approaches, methods, findings | **Fixed** | new §2.5.5 (two-stage vs single-stage vs transformer detectors; relative vs metric depth; consumer LiDAR; earcons/tactons) and Table 2.3 |
| Limitations, disagreements, gaps | **Fixed** | new §2.5.6 "Where the literature disagrees" (sensor vs camera; haptic value; detector family on-device; who should evaluate) |
| Review leads logically to own research | **Fixed** | §2.7 rewritten to lead from the four gaps to the aim; Figure 2.1 redrawn to show that flow |
| Choice of approach supported by literature | **Fixed** | §2.5.5 gives a sourced basis for each design choice; Table 3.8 cites it |
| Important claims referenced | **Fixed** | problem statement, hazard ordering, metrics, bootstrap, mosaic, label errors, distribution shift, walking speed now cited |
| Not over-reliant on websites/blogs | Met | web sources only for software, datasets, Apple documentation and the UAE law; everything else peer-reviewed or arXiv |

## Dataset and data preparation

| Item | Status | Where / what changed |
|---|---|---|
| Dataset clearly described | Met | §3.3.1–§3.3.7, Tables 3.2–3.3 |
| Source identified and referenced | **Fixed** | Roboflow (Lochan R, 2023), AI Builders (Jaiinsom, 2022), COCO (Lin et al., 2014) now in the bibliography — the Roboflow licence requires attribution, and it was missing |
| Size reported | Met | Tables 3.2, 3.3; §3.3.5 |
| Variables/features explained | **Fixed** | new §3.3.8, Table 3.4 |
| Why the dataset suits the RQs | **Fixed** | new paragraph in §3.3.2 |
| Cleaning and preprocessing explained | Met | §3.3.5, §3.4; preprocessing corrected: detectors use 0–1 pixel scaling, not ImageNet normalisation, which the text previously claimed |
| Missing values, duplicates, outliers, quality | **Fixed** | new §3.3.9, Table 3.5 (every issue and its treatment) |
| Features selected/engineered — why | Met | §3.8.2 (engineering sits between models and feedback) |
| Synthetic/proxy data disclosed | **Fixed** | new §3.3.10, Table 3.6 (Hypersim, teacher labels, planted values, the synthetic test frame, blindfolded participants, wall-as-pole) |
| Limitations of proxy data explained | **Fixed** | Table 3.6, last column |
| Claims consistent with the data | **Fixed** | see "Corrections of fact" below — three claims were not |

## Methodology

| Item | Status | Where / what changed |
|---|---|---|
| Clearly explained and reproducible | **Fixed** | new §3.1.1 research design; Table 3.14 software versions; Appendix I reproduction commands |
| Each technique justified | **Fixed** | §3.5 "Why these detectors", "Why this depth network"; Table 3.11 for prototype components |
| Alternatives considered | **Fixed** | new Table 3.8 (12 alternatives, each with the reason it was not chosen) |
| Why the chosen approach suits this problem | **Fixed** | §3.5, Table 3.8 |
| Hyperparameters reported and justified | **Fixed** | new Table 3.9, read from the checkpoints themselves (AdamW, lr 0.000625, batch 16→64, seed 0, …) |
| Train/validation/test strategy | **Fixed** | §3.3.5 now says what the validation set is used for and that the capture set is the held-out test |
| Data leakage avoided | **Fixed** | new §3.5.5 collects every control |
| Reason for each model | Met | §3.1.2 baselines, §3.5 |
| Defensible basis for thresholds/scores | **Fixed** | new Table 3.13: every decision-layer constant with its basis, marked measured / hardware / consistency / design choice; hazard-weight ordering now grounded in accident evidence (§3.3.4) |
| Method supports RQs and objectives | **Fixed** | Table 3.1 |

## AI/ML/DL technical quality

| Item | Status | Where / what changed |
|---|---|---|
| Depth beyond calling a library | Met | manual buffer conversion, export fixes (§3.5.2), decision layer (§3.8), operating-point evaluation, audit, retraining (§3.5.3–§3.5.4) |
| Model development explained | Met | §3.5.1–§3.5.4 |
| Implementation decisions justified | Met | §3.8, Tables 3.11, 3.13 |
| Compared against a baseline | **Fixed** | baselines now named explicitly (new §3.1.2) |
| Improvement demonstrated with evidence | Met | paired scene bootstrap, §4.1.7–§4.1.8 |
| More than one configuration tested | Met | 3 detectors, 2 runs, 7 retraining variants, 2 depth methods |
| Metrics appropriate | Met | — |
| Why those metrics | **Fixed** | new §3.5.6, Table 3.10; metrics now defined as Equations 3.1–3.5 |
| Reproducible from the method | **Fixed** | Table 3.14 and Appendix I; two reproducibility gaps stated (Colab versions, monocular command line) |

## Evaluation

| Item | Status | Where / what changed |
|---|---|---|
| Evaluated rather than demonstrated | Partly | Objectives 1–2 are evaluated; Objective 3 is verified and measured, not evaluated with users — now stated explicitly (§4.3 intro, new §4.3.6) |
| Answers the RQs | Partly | RQ1, RQ2 answered; RQ3, RQ4 not — stated in §1.5, §4.5, §6.1.2 |
| Quantitative results | Met | — |
| Suitable measures | Met | P, R, F1, mAP, MAE, MAPE, RMSE, bias, latency percentiles |
| What the values mean | **Fixed** | §4.1.1 now interprets mAP 0.17; §4.2 interprets the error in terms of ground-truth resolution; §3.7.3 explains why positive bias is the unsafe direction |
| Comparison with baseline / previous research | **Fixed** | §5.2.1 (He and Saha), §5.2.5 (Northcutt et al.; Bochkovskiy et al.; Koh et al.), §5.3 (Luetzenburg et al.; Yin et al.) |
| Poor results investigated | **Fixed** | new analysis `tools/distance_uncertainty.py`: why LiDAR over-estimates chairs and tables, why the monocular net fails, why the range trend was spurious |
| Robustness, errors, FP/FN, failure cases | **Fixed** | bootstrap intervals for all distance figures (Table 4.7); box-placement breakdown (Table 4.8); false alarms and misses discussed in §5.6 |
| Validity where ground truth is absent | **Fixed** | new §3.10 (internal, construct, statistical, external validity; urgency has no ground truth and is verified, not validated) |
| User/expert evaluation systematic | N/A — not conducted | protocol fully specified in §3.2.4 |
| — number of participants | Met (planned) | five, §3.2.4 |
| — selection criteria | Met (planned) | sighted, 18+, convenience sample, §3.2.4 |
| — instrument | **Fixed** | §3.2.4 now states the measures from form §2.6: completion time, success rate, post-task interview |
| — procedure | Met (planned) | §3.2.4 |
| — systematic analysis | N/A | no data |
| — ethics/consent followed | Met | §3.2, Appendix A |

## Results

| Item | Status | Where / what changed |
|---|---|---|
| Main results clearly presented | Met | — |
| Tables/figures add information | **Fixed** | new Figure 4.3 (every distance estimate against the tape measure) and new Figure 3.1 (system architecture) |
| All tables/figures numbered, captioned, discussed | **Fixed** | most Chapter 3–4 tables had no number or caption; all 37 tables and 5 figures now numbered and captioned, and `tools/check_citations.py` verifies each is referred to in the text |
| Results linked to RQs | **Fixed** | new §4.5, Table 4.17 |
| Not relying on screenshots as evidence | Met | no screenshots are used as evidence |
| Outputs interpreted, not just reported | Met | — |

## Discussion

| Item | Status | Where / what changed |
|---|---|---|
| Why the results came out as they did | **Fixed** | "Why" paragraphs in §5.2.1, §5.3 |
| What the findings mean | Met | — |
| Compared with previous studies | **Fixed** | see Evaluation row above |
| Agreement/disagreement with research | **Fixed** | explicit in §5.2.1, §5.2.5, §5.3 |
| Unexpected findings explained | **Fixed** | class-mix range effect, monocular calibration error, chair/table over-estimation, door-as-wall hazard down-weighting (§5.4.1) |
| Weaknesses of the approach | Met | §5.5 |
| Alternative explanations | **Fixed** | §5.2.1 (three for the dominance result), §5.2.3, §5.2.5, §5.3 (three for monocular failure) |
| Practical/research implications | Met | §5.7 |
| MSc-level critical thinking | Met | — |

## Prototype / artefact

| Item | Status | Where / what changed |
|---|---|---|
| Architecture explained | **Fixed** | §3.8 intro and Table 3.11 |
| Pipeline diagram | **Fixed** | new Figure 3.1 |
| Each component justified | **Fixed** | Table 3.11 |
| Relationship between AI model and app clear | **Fixed** | §3.8 intro |
| System tested | Met | §4.3.2, §4.3.3 |
| Software testing vs research evaluation | **Fixed** | new §4.3.6, Table 4.16 |
| App presented as part of the research, not the contribution | **Fixed** | §1.4.1, §4.3 intro, §6.1.5 |

## Ethics, privacy, security and responsible AI

| Item | Status | Where / what changed |
|---|---|---|
| Ethical implications | **Fixed** | new §5.6 |
| Privacy | **Fixed** | §5.6 (on-device processing, no images stored, bystanders) |
| Security | **Fixed** | §5.6 (tampered model, adversarial patterns) |
| Bias/fairness | **Fixed** | §5.6 (cost of access, skin-tone bias in person detection — Wilson et al., 2019 — environment) |
| Harms and misuse | **Fixed** | §5.6 (over-reliance, silent misses, false alarms, surveillance) |
| Data protection and governance | **Fixed** | §5.6 (UAE PDPL, withdrawal and deletion, provenance) |
| Limitations for responsible deployment | **Fixed** | §5.6 "Responsible deployment" lists what would be needed first |
| No deployment suggested without validation | **Fixed** | stated in the abstract, §5.5 item 18, §5.6, §6.1.4 |

## Claims and academic caution

| Item | Status | Where / what changed |
|---|---|---|
| Every major claim supported | **Fixed** | see "Corrections of fact" |
| No claim of deployment readiness | **Fixed** | explicit statements added (above) |
| Demonstrated / suggested / potential / future distinguished | **Fixed** | new §6.1.4, Table 6.1; Table 4.17 strength column |
| No generalising beyond limited data | **Fixed** | §5.2.1 and §5.2.3 overclaims softened ("simply the right default"; "would deliver closer to 79 fps") |

## Limitations

| Item | Status | Where / what changed |
|---|---|---|
| Clear limitations section | Met | §5.5 |
| Specific | Met | — |
| Covers dataset, sample size, representativeness, model, evaluation, compute, assumptions, generalisability, user testing, deployment | **Fixed** | items 13–18 added (sample size, seed/no tuning, compute, assumptions, representativeness, deployment) |
| How each affects interpretation | **Fixed** | new Table 5.1 |

## Conclusion

| Item | Status | Where / what changed |
|---|---|---|
| Returns to the aim | **Fixed** | new §6.1.1 |
| All objectives addressed | **Fixed** | new §6.1.2 |
| RQs answered | **Fixed** | §6.1.2 |
| Main findings clear | **Fixed** | §6.1.3; the duplicated 43 % paragraph removed; "agreeing to within a tenth of a percentage point" corrected |
| Contribution restated | **Fixed** | new §6.1.5 |
| Limitations acknowledged | Met | §6.4 |
| Future work realistic and linked | **Fixed** | each item in §6.5 now names the limitation it addresses; four items added (sampling rule, capture protocol, devices/sites, Seeing AI) |

## Academic writing and presentation

| Item | Status | Where / what changed |
|---|---|---|
| Formal, clear, academic | **Fixed** | informal phrasing replaced ("a property of the ruler", "a low bar", "chased", "in fairness", "the whole of the matter"); references to earlier drafts removed; "CLAUDE.md" was cited in §4.2.1 and is gone |
| No conversational language | **Fixed** | as above |
| Long/unclear sentences | **Fixed** | abstract rewritten to about one page as the guidelines ask, from roughly 900 words of long sentences |
| Grammar and spelling | Yours | a pass was made; read the PDF yourself before submission |
| Consistent terminology | **Fixed** | British spelling ("artefact", "judgement") |
| Abbreviations defined at first use | **Fixed** | new List of abbreviations; first uses expanded throughout |
| No unnecessary repetition | **Fixed** | Chapter 6 duplicate removed |
| Headings logical | Met | — |
| Formatting consistent | **Fixed** | all tables captioned the same way; LaTeX report class, one chapter per page |
| Table of contents correct | **Fixed** | contents, list of figures and list of tables now generated from the headings and captions, placed after the front matter (they previously came before the title page) |
| Page numbers correct | **Fixed** | roman for front matter, arabic from Chapter 1 — check in the final PDF |
| Figures readable | **Fixed** | Figures 2.1 and 3.1 redrawn so their smallest text prints at about 8 pt (it was about 5 pt) |
| Tables readable | **Fixed** | column widths now follow content (`tools/format_tables.py`); no header breaks mid-word |
| Equations presented properly | **Fixed** | urgency function and all metrics as numbered display equations (3.1–3.8) |

## Referencing

| Item | Status | Where / what changed |
|---|---|---|
| All citations in the reference list | **Fixed** | the bibliography carried an unfinished "Additions required" note; now complete — `tools/check_citations.py` reports 50 of 50 matched both ways |
| Everything listed is cited | **Fixed** | an uncited entry (Microsoft Soundscape) removed |
| One style | Met | Harvard |
| Recent sources | **Fixed** | see Literature review |
| Unsupported statements referenced | **Fixed** | — |
| Figures/data from others attributed | **Fixed** | dataset licences and attribution now in the bibliography |
| References checked, not trusted from GenAI | Partly / **Yours** | every added reference was checked against its publisher's record or the paper itself this session; the checklist asks *you* to check them manually |

## Use of generative AI

| Item | Status | Where / what changed |
|---|---|---|
| University's GenAI rules followed | **Yours** | a declaration was added to the front matter; check it against the University's current rules and edit it to match what you actually did |
| Factual information verified | Partly | every number traces to a committed script; you must confirm you are satisfied |
| Every GenAI reference checked by you | **Yours** | see Referencing |
| You can explain and defend every part | **Yours** | read §3.1.1, §3.3.8–§3.3.10, §3.5.5–§3.5.6, Table 3.13, §3.10, §4.2 (rewritten), §4.3.6, §4.5, §5.3 (rewritten), §5.6, Chapter 6 |
| Writing reflects your own understanding | **Yours** | as above |

---

## Corrections of fact made during this audit

These were errors in the thesis, found by checking claims against the data and
code, not style changes.

1. **Detector coverage on the captures was overstated.** The thesis said the
   detector located the photographed object in 37 % of frames. It returned a
   box in 38 of 102 frames. The placement verdicts, confirmed by the researcher,
   put 30 boxes on the photographed object — 11 correctly named (all doors) and
   19 under another name (13 chair backrests read as `window`, 6 doors as
   `wall`) — and 8 not on it, including all four table-edge boxes, which cover
   the whole table rather than the edge that was measured to. §4.2.1,
   abstract, §5.3, §5.5 and §6.1 corrected; Table 4.6 added.
2. **"LiDAR accuracy improves with range" was a class-mix artefact.** Every
   table-edge frame sits at 0.5–1.0 m. For doors, the one class present at every
   distance, error does not fall with range. §4.2.4 retitled and rewritten.
3. **The two training runs were not independently seeded.** Both used
   Ultralytics' default seed 0, as the checkpoints record; the thesis said "no
   seed pinned" and that two runs ruled out "a single favourable
   initialisation". §3.5.1 and §4.1.1 corrected.
4. **Detector normalisation.** The thesis said ImageNet normalisation; the
   detectors use 0–1 scaling. §3.4 corrected.
5. **Appendix A claimed to reproduce the information, consent and debriefing
   sheets.** The signed PDF is the application form only. Claim removed; the
   form's 13 pages are now embedded in the built report.
6. **"No frame containing a person was persisted."** The researcher's own feet
   appear in some close-range captures, and the detector boxed one of them as
   `person`. §3.2.2 reworded accurately.
7. **§3.7.1 said glass doors and frames beyond 5 m were captured.** Neither was.
   Now described as planned and not captured.
8. **§3.7.1 said no rotation reasoning was needed downstream.** Frames must be
   rotated upright before detection (0 of 4 boxes as stored, 4 of 4 rotated).
9. **Cross-references** to §3.1 for the LiDAR ceiling (should be §3.7.1) and to
   §1.2 for the contribution (should be §1.4) fixed; ethics-form section numbers
   now written "form §2.6" so they cannot be read as thesis sections.

## What only you can do before submission

1. ~~**Confirm the box-placement verdicts.**~~ **Done, 26 September.** Sheets
   2 and 3 confirmed as proposed; on sheet 1 you overturned #12, and by the
   same reasoning #32–34: the table boxes cover the whole table, not the edge
   measured to. §4.2, the abstract, §5.3, §5.5 and §6.1 now carry the
   confirmed figures (30 boxes on the object, 11 correctly named).
2. ~~**Edit the GenAI declaration.**~~ **Decided: kept as drafted.**
3. **Check the 33 new references** yourself (the checklist asks for it). Each
   has a DOI or URL in the bibliography.
4. ~~**Decide about §6.1.6's reflection.**~~ **Decided: the deadline sentence removed.** It says Objective 4 was first descoped
   against a deadline that turned out to be wrong. That is true and the
   guidelines ask for reflection on process, but it is your call whether to
   say it.
5. ~~**If you have the participant information, consent and debriefing sheets**~~ **Done: added as Appendix A.2–A.4.**
   submitted with the ethics application, add them to
   `docs/source_documents/` and say so in Appendix A.
6. **Read the rebuilt PDF end to end** (`bash tools/build_thesis.sh pdf`):
   spelling, page numbers, and whether you can defend every section listed
   under "Use of generative AI" above.
