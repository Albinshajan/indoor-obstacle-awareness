# Indoor obstacle awareness on a smartphone

Code, results and dissertation for *A Smartphone-Based Prototype for Indoor
Obstacle Awareness: Real-Time Object Detection, Distance Estimation, and
Audio-Haptic Feedback for Blind and Visually Impaired Users* — MSc Data Science
and Artificial Intelligence, Middlesex University Dubai, 2026 (module CST4275).
Author: Albin Shajan. Supervisor: Dr Ikram Ur Rehman.

> **Public version.** This repository is a cleaned copy of the project. The
> signed ethics form and the University's guidelines deck are not included,
> personal contact details in the participant documents are replaced by
> "[removed]", and device and developer-account identifiers are replaced by
> placeholders. The history starts from this snapshot.

## What this is

An iPhone prototype that detects indoor obstacles, estimates how far away they
are, and signals them through graded vibration and panned audio, together with
the measurements behind every design decision. The scope is **obstacle
awareness, not navigation**, and the prototype is intended only as a supplement
to a white cane.

**It is not ready for use by blind or visually impaired people.** It has not
been evaluated with any user, its detector misses most obstacles in the setting
it was built for, and it cannot detect poles or glass. It demonstrates technical
feasibility on one handset and nothing more (dissertation §5.6).

## Main results

Measured on an iPhone 13 Pro Max (A15 Bionic):

- **Detection (RQ1).** Of YOLOv8n, YOLO11n and YOLO26n fine-tuned on the same
  indoor corpus, YOLO26n is the most accurate (pooled mAP50-95 0.170 against
  about 0.125), the smallest, and tied fastest; all three run end to end at over
  75 fps. Buffer conversion and resizing take about 43 % of pipeline latency.
- **Distance (RQ2).** Against 102 tape-measured frames at 0.5–4.5 m, the
  phone's built-in LiDAR has a mean absolute error of 0.188 m (95 % interval
  0.12–0.26 m), against 1.221 m for a monocular depth network; 0.077 m on doors.
- **What limits it.** Detection, not depth: the detector put a correctly named
  box on the photographed object in 11 of 102 frames. The model that won every
  photograph benchmark drew door boxes over empty corridor floor.
- **Prototype.** Detection, LiDAR depth, a derived-feature layer and switchable
  haptic/audio feedback run at 29.8 fps with 13.3 ms of processing per frame.

The research question about haptic feedback (RQ3) is unanswered: the approved
participant study was not run (§1.5).

## Repository layout

| Path | Contents |
|---|---|
| `docs/thesis/` | The dissertation as Markdown, one file per chapter, with its figures |
| `tools/` | Data preparation, training notebook, Core ML export, evaluation, analysis and thesis build scripts |
| `ios/ObstacleAwareness/` | The iOS app: prototype (`Assist/`), detection view, capture app and benchmark harness |
| `results/` | Every table and figure the thesis reports, as CSV, Markdown and images |
| `docs/submission/` | Poster and talk notes |
| `docs/checklist_audit.md` | The dissertation checked item by item against the supervisor's checklist |

## Reproducing

```bash
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
python3 tools/check_citations.py        # citations and cross-references
bash tools/build_thesis.sh pdf          # dissertation PDF (needs pandoc and a TeX distribution)
bash tools/build_thesis.sh docx         # Word version
bash tools/verify_decision_layer.sh     # 45 checks of the prototype's decision layer (macOS)
source .venv/bin/activate               # the analysis scripts need the packages above
python tools/distance_uncertainty.py    # distance-study intervals and figure
```

The detection experiments need the datasets below, downloaded separately; each
script's header documents its arguments, and dissertation Appendix I lists the
order they run in. The iOS app is generated with XcodeGen
(`cd ios/ObstacleAwareness && xcodegen generate`); set your own development team
in `project.yml` before building.

## What is not included

- **Datasets and trained weights** (`data/`, `*.pt`, `*.mlpackage`). Obtain the
  datasets from their publishers: the Roboflow indoor-objects set
  (`lochan-r-ugnn4/indoor-objects-detection-h2mgz`, CC BY 4.0), COCO val2017
  (annotations CC BY 4.0), and the AI Builders indoor-objects set
  (`thepbordin/indoor-object-detection` on Kaggle, GPL-3.0). The weights are
  reproducible with `tools/train_colab.ipynb` and `tools/export_coreml.py`.
- **The tape-measured capture set** (researcher-owned).
- **Participant data**: none exists; the study was not run.

## Licence

- **Code** (`tools/`, `ios/`, and all other source files): **GNU AGPL-3.0**
  (`LICENSE`), as required by the Ultralytics YOLO framework the code builds on.
- **Dissertation text, figures and results** (`docs/`, `results/`):
  **CC BY 4.0** (`LICENSE-CC-BY-4.0`). Reuse them freely with credit to the
  author.
- **Third-party material keeps its own licence.** Contact sheets under
  `results/objective1_audit/` show images from the Roboflow indoor-objects set
  (Lochan R, 2023, CC BY 4.0) and the AI Builders set (Jaiinsom, 2022,
  GPL-3.0).

## Citation

Shajan, A. (2026) *A Smartphone-Based Prototype for Indoor Obstacle Awareness:
Real-Time Object Detection, Distance Estimation, and Audio-Haptic Feedback for
Blind and Visually Impaired Users*. MSc dissertation. Middlesex University
Dubai.
