"""Objective 1, accuracy at the operating point: confusion matrices and
per-class precision, recall and F1 for the three fine-tuned detectors on the
scene-split validation set.

Why this exists alongside mAP. mAP integrates precision over every confidence
threshold, which is the right way to compare detectors and the wrong way to
describe what the prototype does: the app runs at ONE threshold
(`AssistController.confidenceThreshold`, 0.30). A confusion matrix at that
threshold says which errors the user would actually meet -- a door missed, a
table called a chair, a box on empty floor -- which a pooled mAP cannot.

Four steps, in the order they have to be trusted:

1. CROSS-CHECK. Ultralytics' own `val()` at its defaults must reproduce the
   Colab figures in `results/objective1_train_metrics.csv`. The local weights
   are that run's (run 2, 2026-09-11), so a mismatch would mean this is not the
   evaluation the thesis already reports, and nothing below should be read.
2. PREDICT once per model at conf 0.001 with the app's NMS IoU (0.45),
   single-label -- one class per box, as the Core ML export's argmax gives --
   and cache the result, so every threshold below reuses one set of boxes.
3. MATCH with `ultralytics.utils.metrics.ConfusionMatrix.process_batch`, the
   library's own greedy IoU matching, rather than a reimplementation. A box
   counts as matched at IoU > 0.5, the mAP50 criterion.
4. DERIVE every metric from the matrix, so the tables and the heatmaps cannot
   disagree.

Then two analyses the headline numbers raise:

- A SCENE-LEVEL BOOTSTRAP of micro and macro F1, paired across models, to say
  whether the ranking is larger than resampling noise. Scenes, not images, are
  resampled, because the three augmented copies of one photograph are not
  three independent observations.
- RECALL BY OBJECT SIZE, in COCO's own pixel-area bands (small < 32^2,
  medium < 96^2, large otherwise), to test whether what the detector misses
  is mostly what is small.

Two evaluation sets. `all`: the full 678-image validation split, identical to
the Colab evaluation. `unaugmented`: only scenes that appear once, which are
Roboflow's own valid/test images and therefore carry none of its 3x
augmentation (vertical flip, 30-degree rotation). 196 of the 283 validation
scenes are three augmented copies of one photograph, so `all` is both
inflated by near-duplicates and partly upside down; `unaugmented` is the check
on whether that changes the answer.

What this does NOT measure: the Core ML exports. It evaluates the PyTorch
weights. The export was checked against them on a sample image (confidence
0.77 vs 0.76, same box; CLAUDE.md section 8) but not across this set.

Usage:
    .venv/bin/python tools/detection_metrics.py
    .venv/bin/python tools/detection_metrics.py --skip-crosscheck   # reuse cached predictions only
    # any other set of weights, e.g. tools/train_ablation.py's variants -- no
    # cross-check (there is no Colab reference) and no thesis figures copied:
    .venv/bin/python tools/detection_metrics.py --output results/objective1_ablation \
        --weights baseline=data/processed/ablation/weights/baseline.pt \
        --weights mosaic=data/processed/ablation/weights/mosaic.pt
    # a different evaluation set: a list of image paths, labels alongside
    # (every image its own scene, no unaugmented subset):
    ... --eval-list data/processed/ablation/lists/aib_test.txt --labels data/processed/aib/labels
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import shutil
import sys
from collections import Counter
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from taxonomy import CANONICAL_CLASSES  # noqa: E402

log = logging.getLogger("detection_metrics")

DEFAULT_MODELS = ["yolov8n", "yolo11n", "yolo26n"]
OPERATING_THRESHOLD = 0.30   # AssistController.confidenceThreshold
NMS_IOU = 0.45               # AssistController.iouThreshold
MATCH_IOU = 0.50             # the mAP50 criterion
SWEEP = [round(t, 2) for t in np.arange(0.05, 0.951, 0.05)]

# Reference palette, light mode (dataviz skill), in its fixed slot order: a
# model's colour is its position in the run, never cycled. Slots 1-3 validate
# all-pairs for CVD; the full order validates adjacent pairs, which is what
# lines and grouped bars need. Several slots sit below 3:1 on white, so every
# line is direct-labelled and every figure has a table.
CATEGORICAL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
SEQUENTIAL_BLUE = ["#fcfcfb", "#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5",
                   "#256abf", "#184f95", "#0d366b"]
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
GRID = "#e4e3df"


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------

def load_split(provenance: Path, images_dir: Path, split: str) -> list[dict]:
    rows = [r for r in csv.DictReader(provenance.open()) if r["split"] == split]
    scene_sizes = Counter(r["scene_id"] for r in rows)
    return [{"path": images_dir / r["new_filename"],
             "scene": r["scene_id"],
             "unaugmented": scene_sizes[r["scene_id"]] == 1} for r in rows]


def load_list(list_path: Path) -> list[dict]:
    """An arbitrary evaluation set: one image path per line, each its own scene."""
    paths = [Path(line) for line in list_path.read_text().splitlines() if line.strip()]
    return [{"path": p, "scene": p.stem, "unaugmented": True} for p in paths]


EVAL_NAME = "validation"   # set from --eval-list in main(); used in figure titles


def load_ground_truth(image: Path, labels_dir: Path) -> tuple[np.ndarray, np.ndarray]:
    """YOLO-format labels -> (classes, xyxy pixel boxes)."""
    from PIL import Image
    w, h = Image.open(image).size
    label = labels_dir / (image.stem + ".txt")
    if not label.exists():
        return np.zeros(0), np.zeros((0, 4))
    rows = np.loadtxt(label, ndmin=2)
    if rows.size == 0:
        return np.zeros(0), np.zeros((0, 4))
    cls, cx, cy, bw, bh = rows.T
    boxes = np.stack([(cx - bw / 2) * w, (cy - bh / 2) * h,
                      (cx + bw / 2) * w, (cy + bh / 2) * h], axis=1)
    return cls.astype(int), boxes


# --------------------------------------------------------------------------
# Step 1: cross-check against the Colab run
# --------------------------------------------------------------------------

def crosscheck(weights: Path, model_name: str, val_list: Path, reference: dict, device: str) -> list[dict]:
    from ultralytics import YOLO

    data_yaml = val_list.with_name("crosscheck_data.yaml")
    data_yaml.write_text(f"train: {val_list}\nval: {val_list}\n"
                         f"nc: {len(CANONICAL_CLASSES)}\nnames: {CANONICAL_CLASSES}\n")
    metrics = YOLO(str(weights)).val(data=str(data_yaml), imgsz=640, split="val", batch=16,
                                     device=device, plots=False, verbose=False)
    box = metrics.box
    rows = [{"model": model_name, "class": "__pooled_mAP__",
             "ap50_95_local": float(box.map), "ap50_local": float(box.map50)}]
    for idx, ap, ap50 in zip(box.ap_class_index, box.ap, box.ap50):
        rows.append({"model": model_name, "class": CANONICAL_CLASSES[int(idx)],
                     "ap50_95_local": float(ap), "ap50_local": float(ap50)})
    for r in rows:
        ref = reference.get((model_name, r["class"]))
        r["ap50_95_colab"] = ref[0] if ref else float("nan")
        r["ap50_colab"] = ref[1] if ref else float("nan")
        r["ap50_95_diff"] = r["ap50_95_local"] - r["ap50_95_colab"]
    return rows


def read_colab_reference(path: Path) -> dict:
    ref = {}
    for r in csv.DictReader(path.open()):
        ref[(r["model"], r["class"])] = (float(r["ap50_95"]), float(r["ap50"]))
    return ref


# --------------------------------------------------------------------------
# Step 2: predict once, cache
# --------------------------------------------------------------------------

def _digest(weights: Path) -> str:
    """Cheap content key, so retrained weights under an old name cannot be
    served stale cached predictions."""
    import hashlib
    h = hashlib.sha1(str(weights.stat().st_size).encode())
    with weights.open("rb") as f:
        h.update(f.read(1 << 20))
    return h.hexdigest()[:12]


def predict(weights: Path, images: list[dict], device: str, cache_dir: Path, name: str,
            eval_tag: str = "") -> dict:
    cache = cache_dir / f"predictions_{name}_{_digest(weights)}{eval_tag}.json"
    if cache.exists():
        log.info("reusing cached predictions %s", cache)
        return json.loads(cache.read_text())

    from ultralytics import YOLO
    model = YOLO(str(weights))
    names = [model.names[i] for i in sorted(model.names)]
    if names != CANONICAL_CLASSES:
        raise SystemExit(f"{weights}: class names {names} do not match taxonomy.CANONICAL_CLASSES")

    out = {}
    for i, item in enumerate(images):
        result = model.predict(str(item["path"]), conf=0.001, iou=NMS_IOU, imgsz=640,
                               max_det=300, device=device, verbose=False)[0]
        b = result.boxes
        out[item["path"].name] = {
            "cls": b.cls.cpu().numpy().astype(int).tolist(),
            "conf": b.conf.cpu().numpy().round(5).tolist(),
            "xyxy": b.xyxy.cpu().numpy().round(2).tolist(),
        }
        if (i + 1) % 100 == 0:
            log.info("  %s: %d/%d", weights.stem, i + 1, len(images))
    cache.write_text(json.dumps(out))
    return out


# --------------------------------------------------------------------------
# Step 3: match, via Ultralytics' own ConfusionMatrix
# --------------------------------------------------------------------------

def _tensors(prediction: dict, ground_truth: tuple) -> tuple[dict, dict]:
    import torch
    gt_cls, gt_xyxy = ground_truth
    detections = {"cls": torch.tensor(prediction["cls"], dtype=torch.float32),
                  "conf": torch.tensor(prediction["conf"], dtype=torch.float32),
                  "bboxes": torch.tensor(prediction["xyxy"], dtype=torch.float32).reshape(-1, 4)}
    batch = {"cls": torch.tensor(gt_cls, dtype=torch.float32),
             "bboxes": torch.tensor(gt_xyxy, dtype=torch.float32).reshape(-1, 4)}
    return detections, batch


def confusion(predictions: dict, truth: dict, images: list[dict], threshold: float,
              per_image: bool = False):
    """(nc+1) x (nc+1) counts, Ultralytics orientation: rows predicted, columns
    true, last index background. Transposed to rows-true only for display.
    With `per_image`, also each image's own contribution, for the bootstrap."""
    from ultralytics.utils.metrics import ConfusionMatrix

    cm = ConfusionMatrix(names=dict(enumerate(CANONICAL_CLASSES)))
    contributions = {}
    for item in images:
        name = item["path"].name
        before = cm.matrix.copy() if per_image else None
        cm.process_batch(*_tensors(predictions[name], truth[name]), conf=threshold, iou_thres=MATCH_IOU)
        if per_image:
            contributions[name] = (cm.matrix - before).astype(int)
    total = cm.matrix.astype(int)
    return (total, contributions) if per_image else total


COCO_SMALL, COCO_MEDIUM = 32 ** 2, 96 ** 2   # pixel areas, COCO's own size bands


def recall_by_size(predictions: dict, truth: dict, images: list[dict], threshold: float) -> list[dict]:
    """Share of ground-truth objects found with the right class, per COCO size
    band. Per-object outcomes come from the same Ultralytics matcher, via its
    `save_matches` record: every ground-truth box that is not listed as a
    false negative was matched with the correct class."""
    from ultralytics.utils.metrics import ConfusionMatrix

    cm = ConfusionMatrix(names=dict(enumerate(CANONICAL_CLASSES)), save_matches=True)
    found, total = Counter(), Counter()
    for item in images:
        name = item["path"].name
        detections, batch = _tensors(predictions[name], truth[name])
        cm.process_batch(detections, batch, conf=threshold, iou_thres=MATCH_IOU)
        not_correct = Counter(tuple(b.tolist()) for b in cm.matches["FN"].get("bboxes", []))
        for box, cls in zip(batch["bboxes"], batch["cls"]):
            key = tuple(box.tolist())
            area = float((box[2] - box[0]) * (box[3] - box[1]))
            band = "small" if area < COCO_SMALL else "medium" if area < COCO_MEDIUM else "large"
            for group in ("all", CANONICAL_CLASSES[int(cls)]):
                total[(group, band)] += 1
            if not_correct[key]:
                not_correct[key] -= 1
            else:
                for group in ("all", CANONICAL_CLASSES[int(cls)]):
                    found[(group, band)] += 1
    rows = []
    for (group, band), n in sorted(total.items()):
        rows.append({"class": group, "size": band, "objects": n,
                     "found": found[(group, band)], "recall": _ratio(found[(group, band)], n)})
    return rows


def bootstrap(per_image: dict[str, dict], images: list[dict], draws: int = 2000,
              seed: int = 20260921) -> tuple[list[dict], list[dict]]:
    """Resample scenes with replacement, the same scenes for every model on
    every draw, so model differences are paired. Returns 95% percentile
    intervals per model and per model pair."""
    scenes = sorted({i["scene"] for i in images})
    index = {scene: k for k, scene in enumerate(scenes)}
    size = len(CANONICAL_CLASSES) + 1
    stacks = {}
    for model_name, matrices in per_image.items():
        arr = np.zeros((len(scenes), size, size), dtype=np.int64)
        for item in images:
            arr[index[item["scene"]]] += matrices[item["path"].name]
        stacks[model_name] = arr

    rng = np.random.default_rng(seed)
    samples = {m: {"micro_f1": [], "macro_f1": []} for m in stacks}
    for _ in range(draws):
        pick = rng.integers(0, len(scenes), len(scenes))
        for model_name, arr in stacks.items():
            _, s = metrics_from_matrix(arr[pick].sum(axis=0))
            samples[model_name]["micro_f1"].append(s["micro_f1"])
            samples[model_name]["macro_f1"].append(s["macro_f1"])

    per_model, pairs = [], []
    for metric in ("micro_f1", "macro_f1"):
        for model_name, arr in stacks.items():
            _, point = metrics_from_matrix(arr.sum(axis=0))
            lo, hi = np.percentile(samples[model_name][metric], [2.5, 97.5])
            per_model.append({"model": model_name, "metric": metric, "point": point[metric],
                              "ci_low": float(lo), "ci_high": float(hi), "scenes": len(scenes)})
        names = list(stacks)
        for a, b in [(later, earlier) for i, earlier in enumerate(names) for later in names[i + 1:]]:
            diff = np.array(samples[a][metric]) - np.array(samples[b][metric])
            lo, hi = np.percentile(diff, [2.5, 97.5])
            pairs.append({"comparison": f"{a} - {b}", "metric": metric, "mean_diff": float(diff.mean()),
                          "ci_low": float(lo), "ci_high": float(hi),
                          "share_of_draws_not_ahead": float((diff <= 0).mean())})
    return per_model, pairs


# --------------------------------------------------------------------------
# Step 4: metrics, all from the matrix
# --------------------------------------------------------------------------

def _ratio(a, b):
    return a / b if b else float("nan")


def metrics_from_matrix(m: np.ndarray) -> tuple[list[dict], dict]:
    nc = m.shape[0] - 1
    tp = np.diag(m)[:nc]
    predicted = m[:nc, :].sum(axis=1)          # every box the model output, per class
    support = m[:, :nc].sum(axis=0)            # every ground-truth object, per class
    fp = predicted - tp                         # wrong class or no object there
    fn = support - tp                           # missed or called something else

    per_class = []
    for c in range(nc):
        p, r = _ratio(tp[c], predicted[c]), _ratio(tp[c], support[c])
        # 2TP / (2TP + FP + FN): equal to the harmonic mean wherever that is
        # defined, and 0 rather than undefined for a class found zero times.
        f1 = _ratio(2 * tp[c], 2 * tp[c] + fp[c] + fn[c])
        per_class.append({
            "class": CANONICAL_CLASSES[c], "support": int(support[c]), "predicted": int(predicted[c]),
            "tp": int(tp[c]), "fp": int(fp[c]), "fn": int(fn[c]),
            "missed": int(m[nc, c]), "misclassified": int(support[c] - tp[c] - m[nc, c]),
            "spurious": int(m[c, nc]),
            "precision": p, "recall": r, "f1": f1,
        })

    evaluated = [r for r in per_class if r["support"] > 0]
    TP, FP, FN = tp.sum(), fp.sum(), fn.sum()
    micro_p, micro_r = _ratio(TP, TP + FP), _ratio(TP, TP + FN)
    weights = np.array([r["support"] for r in evaluated], dtype=float)

    def macro(key):
        vals = np.array([r[key] for r in evaluated], dtype=float)
        vals = np.nan_to_num(vals, nan=0.0)   # a class never predicted has precision 0, not "absent"
        return float(vals.mean()), float((vals * weights).sum() / weights.sum())

    class_block = m[:nc, :nc]
    summary = {
        "objects": int(support.sum()),
        "boxes_output": int(predicted.sum()),
        "correct": int(TP),
        "misclassified": int(class_block.sum() - TP),
        "missed": int(m[nc, :nc].sum()),
        "spurious": int(m[:nc, nc].sum()),
        "micro_precision": micro_p, "micro_recall": micro_r,
        "micro_f1": _ratio(2 * TP, 2 * TP + FP + FN),
        "macro_precision": macro("precision")[0], "macro_recall": macro("recall")[0],
        "macro_f1": macro("f1")[0],
        "weighted_f1": macro("f1")[1],
        # Detection has no true negatives, so "accuracy" needs defining. Two
        # readings, both straight off the matrix:
        #   matrix accuracy -- trace over every non-empty cell, i.e. correct /
        #     (correct + misclassified + missed + spurious);
        #   classification accuracy -- of the objects that WERE found, the
        #     share given the right class. It separates "cannot find it" from
        #     "finds it and names it wrongly".
        "matrix_accuracy": _ratio(TP, m.sum()),
        "classification_accuracy": _ratio(TP, class_block.sum()),
        "untrained_class_boxes": int(sum(r["predicted"] for r in per_class if r["support"] == 0)),
    }
    return per_class, summary


# --------------------------------------------------------------------------
# Figures
# --------------------------------------------------------------------------

def _style(ax):
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.tick_params(colors=INK_SECONDARY, labelsize=9)
    ax.yaxis.label.set_color(INK_SECONDARY)
    ax.xaxis.label.set_color(INK_SECONDARY)


def plot_confusion(m: np.ndarray, model_name: str, threshold: float, subset: str, path: Path):
    """Rows true, columns predicted -- the convention a data-science reader
    expects. Each true-class row is coloured by its share of that row, so the
    diagonal reads as recall. Classes with no ground truth and no predictions
    (the four never trained) are dropped rather than drawn as empty bands."""
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap

    nc = m.shape[0] - 1
    shown = [c for c in range(nc) if m[:, c].sum() or m[c, :].sum()] + [nc]
    labels = [CANONICAL_CLASSES[c].replace("_", " ") for c in shown[:-1]] + ["background"]
    counts = m[np.ix_(shown, shown)].T      # rows true, columns predicted
    shares = counts / np.maximum(counts.sum(axis=1, keepdims=True), 1)

    cmap = LinearSegmentedColormap.from_list("seq_blue", SEQUENTIAL_BLUE)
    fig, ax = plt.subplots(figsize=(7.4, 6.4), dpi=200)
    ax.imshow(shares, cmap=cmap, vmin=0, vmax=1)
    for i in range(len(shown)):
        for j in range(len(shown)):
            if counts[i, j] == 0 or (i == len(shown) - 1 and j == len(shown) - 1):
                continue
            ax.text(j, i, f"{counts[i, j]}", ha="center", va="center", fontsize=8,
                    color="#ffffff" if shares[i, j] > 0.55 else INK)
    ax.set_xticks(range(len(shown)), labels, rotation=40, ha="right")
    ax.set_yticks(range(len(shown)), labels)
    ax.set_xlabel("Predicted class")
    ax.set_ylabel("True class")
    # Separate the background row/column: it is a different kind of cell.
    edge = len(shown) - 1.5
    ax.axhline(edge, color=INK_SECONDARY, linewidth=0.8)
    ax.axvline(edge, color=INK_SECONDARY, linewidth=0.8)
    ax.set_title(f"{model_name} — {EVAL_NAME} ({subset}), confidence > {threshold:.2f}, IoU > {MATCH_IOU:.1f}",
                 fontsize=10, color=INK, loc="left")
    ax.tick_params(colors=INK_SECONDARY, labelsize=9, length=0)
    for spine in ax.spines.values():
        spine.set_visible(False)
    fig.tight_layout()
    fig.savefig(path, facecolor="white")
    plt.close(fig)


def plot_sweep(sweep_rows: list[dict], models: list[str], subset: str, path: Path):
    """Two small multiples, one per averaging, rather than two measures on
    one axis."""
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.8), dpi=200, sharey=True)
    panel_lines = []
    rows_in = [r for r in sweep_rows if r["subset"] == subset]
    ymax = max(max(r["micro_f1"], r["macro_f1"]) for r in rows_in)
    for ax, key, title in [(axes[0], "micro_f1", "Micro F1 (every object counts once)"),
                           (axes[1], "macro_f1", "Macro F1 (every class counts once)")]:
        peaks = []
        for k, model_name in enumerate(models):
            rows = [r for r in rows_in if r["model"] == model_name]
            xs = [r["threshold"] for r in rows]
            ys = [r[key] for r in rows]
            colour = CATEGORICAL[k]
            ax.plot(xs, ys, color=colour, linewidth=2)
            best = int(np.nanargmax(ys))
            ax.plot(xs[best], ys[best], "o", color=colour, markersize=6,
                    markeredgecolor="white", markeredgewidth=1.5, zorder=3)
            peaks.append((ys[best], xs[best], model_name))
        panel_lines.append((ax, peaks))
        ax.axvline(OPERATING_THRESHOLD, color=INK_SECONDARY, linestyle="--", linewidth=1)
        ax.annotate("app threshold 0.30", (OPERATING_THRESHOLD, 0.02), xytext=(4, 0),
                    textcoords="offset points", fontsize=8, color=INK_SECONDARY)
        ax.set_title(title, fontsize=10, color=INK, loc="left")
        ax.set_xlabel("Confidence threshold")
        ax.set_xlim(0, 1.0)
        ax.set_ylim(0, ymax * 1.15)
        ax.grid(axis="y", color=GRID, linewidth=0.6)
        _style(ax)
    axes[0].set_ylabel("F1")
    handles = [plt.Line2D([], [], color=CATEGORICAL[k], linewidth=2) for k in range(len(models))]
    fig.legend(handles, models, loc="upper right", ncol=len(models), frameon=False, fontsize=8,
               bbox_to_anchor=(0.99, 1.0))
    fig.tight_layout(rect=(0, 0, 1, 0.94))
    for ax, peaks in panel_lines:
        _label_peaks(fig, ax, peaks)
    fig.savefig(path, facecolor="white")
    plt.close(fig)


def _label_peaks(fig, ax, peaks):
    """Direct-label each model at its F1 peak. Two peaks sit within 0.01 of
    each other in both panels, so fixed offsets collide: try positions around
    the marker and keep the first whose box touches no earlier label and no
    plotted line."""
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    line_points = np.vstack([line.get_transform().transform(np.column_stack(line.get_data()))
                             for line in ax.get_lines() if len(line.get_xdata()) > 2])
    # Densify so a line crossing a box between two sweep points still counts.
    dense = []
    for line in ax.get_lines():
        xs, ys = line.get_data()
        if len(xs) > 2:
            t = np.linspace(0, len(xs) - 1, len(xs) * 12)
            dense.append(line.get_transform().transform(
                np.column_stack([np.interp(t, range(len(xs)), xs), np.interp(t, range(len(ys)), ys)])))
    line_points = np.vstack(dense) if dense else line_points
    candidates = [(6, 6, "left"), (6, -14, "left"), (-6, 6, "right"), (-6, -14, "right"),
                  (6, 16, "left"), (6, -24, "left"), (-6, 16, "right"), (-6, -24, "right")]
    placed = []
    for y, x, model_name in sorted(peaks, reverse=True):
        best, best_hits = None, None
        for dx, dy, ha in candidates:
            text = ax.annotate(f"{model_name} {y:.3f}", (x, y), xytext=(dx, dy), ha=ha,
                               textcoords="offset points", fontsize=8, color=INK_SECONDARY)
            box = text.get_window_extent(renderer).expanded(1.05, 1.15)
            inside = ((line_points[:, 0] > box.x0) & (line_points[:, 0] < box.x1) &
                      (line_points[:, 1] > box.y0) & (line_points[:, 1] < box.y1)).sum()
            hits = inside + 1000 * sum(box.overlaps(other) for other in placed)
            axes_box = ax.get_window_extent(renderer)
            if box.x0 < axes_box.x0 or box.x1 > axes_box.x1:
                hits += 10000
            if best_hits is None or hits < best_hits:
                if best is not None:
                    best.remove()
                best, best_hits, best_box = text, hits, box
            else:
                text.remove()
            if hits == 0:
                break
        placed.append(best_box)


def plot_per_class_f1(per_class_rows: list[dict], models: list[str], subset: str, path: Path):
    import matplotlib.pyplot as plt

    classes = [c for c in CANONICAL_CLASSES
               if any(r["class"] == c and r["support"] > 0 for r in per_class_rows)]
    width = 0.8 / len(models) - 0.02
    fig, ax = plt.subplots(figsize=(9.2, 3.8), dpi=200)
    for k, model_name in enumerate(models):
        vals = []
        for c in classes:
            row = next(r for r in per_class_rows
                       if r["model"] == model_name and r["subset"] == subset and r["class"] == c)
            vals.append(0.0 if np.isnan(row["f1"]) else row["f1"])
        xs = np.arange(len(classes)) + (k - (len(models) - 1) / 2) * (width + 0.02)
        ax.bar(xs, vals, width=width, color=CATEGORICAL[k], label=model_name,
               edgecolor="white", linewidth=1)
    ax.set_xticks(range(len(classes)), [c.replace("_", " ") for c in classes])
    ax.set_ylabel("F1 at confidence > 0.30")
    ax.set_ylim(0, 1)
    ax.grid(axis="y", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    ax.legend(frameon=False, fontsize=9, ncol=len(models), loc="upper left")
    ax.set_title(f"Per-class F1 — {EVAL_NAME} ({subset})", fontsize=10, color=INK, loc="left")
    _style(ax)
    fig.tight_layout()
    fig.savefig(path, facecolor="white")
    plt.close(fig)


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

def write_csv(path: Path, rows: list[dict]):
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        for r in rows:
            w.writerow({k: (f"{v:.4f}" if isinstance(v, float) else v) for k, v in r.items()})


def write_matrix_csv(path: Path, m: np.ndarray):
    names = CANONICAL_CLASSES + ["background"]
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["true \\ predicted"] + names)
        for i, name in enumerate(names):
            w.writerow([name] + m.T[i].tolist())


def main():
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--provenance", type=Path, default=root / "data/processed/merged/provenance.csv")
    p.add_argument("--images", type=Path, default=root / "data/processed/merged/images")
    p.add_argument("--labels", type=Path, default=root / "data/processed/merged/labels")
    p.add_argument("--weights-dir", type=Path, default=root / "data/raw/finetuned_weights")
    p.add_argument("--colab-metrics", type=Path, default=root / "results/objective1_train_metrics.csv")
    p.add_argument("--output", type=Path, default=root / "results/objective1_confusion")
    p.add_argument("--cache", type=Path, default=root / "data/processed/detection_metrics_cache")
    p.add_argument("--thesis-figures", type=Path, default=root / "docs/thesis/figures",
                   help="where Chapter 4's two figures are copied, so a rerun cannot leave a stale copy")
    p.add_argument("--device", default="cpu", help="cpu by default: deterministic, and fast enough for nano models")
    p.add_argument("--skip-crosscheck", action="store_true")
    p.add_argument("--eval-list", type=Path, default=None,
                   help="evaluate on this list of images instead of the merged validation split "
                        "(labels from --labels; no cross-check, no thesis figures)")
    p.add_argument("--weights", action="append", metavar="NAME=PATH",
                   help="evaluate these weights instead of the three Colab detectors (repeatable, in plot order)")
    args = p.parse_args()
    if args.weights:
        models = dict(w.split("=", 1) for w in args.weights)
        models = {name: Path(path) for name, path in models.items()}
    else:
        models = {name: args.weights_dir / f"{name}.pt" for name in DEFAULT_MODELS}
    is_default = not args.weights and args.eval_list is None
    global EVAL_NAME
    if args.eval_list is not None:
        EVAL_NAME = args.eval_list.stem
    names = list(models)
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    args.output.mkdir(parents=True, exist_ok=True)
    args.cache.mkdir(parents=True, exist_ok=True)

    if args.eval_list is not None:
        images = load_list(args.eval_list)
        # Images that are the merged corpus's own files keep their real scene,
        # so the bootstrap still resamples augmented copies together.
        scene_of = {r["new_filename"]: r["scene_id"] for r in csv.DictReader(args.provenance.open())}
        for item in images:
            item["scene"] = scene_of.get(item["path"].name, item["scene"])
        subsets = {"all": images}
        eval_tag = f"_{args.eval_list.stem}"
    else:
        images = load_split(args.provenance, args.images, "val")
        subsets = {"all": images, "unaugmented": [i for i in images if i["unaugmented"]]}
        eval_tag = ""
    log.info("%s: %d images (%d scenes); unaugmented: %d", EVAL_NAME,
             len(images), len({i['scene'] for i in images}), len(subsets.get("unaugmented", images)))
    truth = {i["path"].name: load_ground_truth(i["path"], args.labels) for i in images}

    # Step 1
    if is_default and not args.skip_crosscheck:
        val_list = args.cache / "val.txt"
        val_list.write_text("\n".join(str(i["path"]) for i in images) + "\n")
        reference = read_colab_reference(args.colab_metrics)
        rows = []
        for model_name, weights in models.items():
            log.info("cross-check: Ultralytics val() for %s", model_name)
            rows += crosscheck(weights, model_name, val_list, reference, args.device)
        write_csv(args.output / "crosscheck_vs_colab.csv", rows)
        pooled = [r for r in rows if r["class"] == "__pooled_mAP__"]
        for r in pooled:
            log.info("  %s pooled mAP50-95 local %.4f vs Colab %.4f (diff %+.4f)",
                     r["model"], r["ap50_95_local"], r["ap50_95_colab"], r["ap50_95_diff"])

    # Steps 2-4
    per_class_rows, summary_rows, sweep_rows, size_rows = [], [], [], []
    per_image = {subset: {} for subset in subsets}
    for model_name, weights in models.items():
        preds = predict(weights, images, args.device, args.cache, model_name, eval_tag)
        for subset, subset_images in subsets.items():
            m, per_image[subset][model_name] = confusion(preds, truth, subset_images,
                                                         OPERATING_THRESHOLD, per_image=True)
            write_matrix_csv(args.output / f"confusion_{model_name}_{subset}.csv", m)
            per_class, summary = metrics_from_matrix(m)
            per_class_rows += [{"model": model_name, "subset": subset, **r} for r in per_class]
            # The recall ceiling: every box the model emits at all (conf > 0.001).
            # No threshold setting can find an object that is absent here.
            _, floor = metrics_from_matrix(confusion(preds, truth, subset_images, 0.001))
            summary_rows.append({"model": model_name, "subset": subset,
                                 "threshold": OPERATING_THRESHOLD, **summary,
                                 "recall_ceiling": floor["micro_recall"]})
            size_rows += [{"model": model_name, "subset": subset, **r}
                          for r in recall_by_size(preds, truth, subset_images, OPERATING_THRESHOLD)]
            plot_confusion(m, model_name, OPERATING_THRESHOLD, subset,
                           args.output / f"confusion_{model_name}_{subset}.png")
            for t in SWEEP:
                _, s = metrics_from_matrix(confusion(preds, truth, subset_images, t))
                sweep_rows.append({"model": model_name, "subset": subset, "threshold": t,
                                   **{k: s[k] for k in ("micro_precision", "micro_recall", "micro_f1",
                                                        "macro_f1", "matrix_accuracy")}})
            log.info("%s/%s: micro F1 %.3f, macro F1 %.3f, matrix acc %.3f, cls acc %.3f",
                     model_name, subset, summary["micro_f1"], summary["macro_f1"],
                     summary["matrix_accuracy"], summary["classification_accuracy"])

    write_csv(args.output / "per_class_metrics.csv", per_class_rows)
    write_csv(args.output / "summary.csv", summary_rows)
    write_csv(args.output / "threshold_sweep.csv", sweep_rows)
    write_csv(args.output / "recall_by_size.csv", size_rows)
    boot_models, boot_pairs = [], []
    for subset, subset_images in subsets.items():
        models_ci, pairs_ci = bootstrap(per_image[subset], subset_images)
        boot_models += [{"subset": subset, **r} for r in models_ci]
        boot_pairs += [{"subset": subset, **r} for r in pairs_ci]
    write_csv(args.output / "bootstrap_f1.csv", boot_models)
    write_csv(args.output / "bootstrap_pairs.csv", boot_pairs)
    for subset in subsets:
        plot_sweep(sweep_rows, names, subset, args.output / f"f1_vs_threshold_{subset}.png")
        plot_per_class_f1(per_class_rows, names, subset, args.output / f"per_class_f1_{subset}.png")
    if not is_default:
        log.info("wrote %s", args.output)
        return
    shutil.copyfile(args.output / "confusion_yolo26n_all.png",
                    args.thesis_figures / "figure_4_1_confusion_yolo26n.png")
    shutil.copyfile(args.output / "f1_vs_threshold_all.png",
                    args.thesis_figures / "figure_4_2_f1_vs_threshold.png")
    log.info("wrote %s (and Figures 4.1-4.2 into %s)", args.output, args.thesis_figures)


if __name__ == "__main__":
    main()
