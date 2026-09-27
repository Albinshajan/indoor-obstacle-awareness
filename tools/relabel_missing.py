"""Fill in person / chair / table annotations the source corpus left out --
training split only.

Why. The spurious-box audit (`tools/audit_spurious.py`,
results/objective1_audit/) found that most of the detector's confident
`person` and `chair` boxes over "nothing annotated" were over real, unlabelled
people and chairs. Missing labels do double damage. They count against
precision at evaluation, and in TRAINING they teach the model that a visible
person or chair is background -- a direct pressure towards exactly the low
recall those two classes show.

How. A large COCO-pretrained detector (YOLO26x by default -- COCO is one of the
two sources the ethics approval names) proposes boxes for its `person`,
`chair` and `dining table` classes, the three COCO classes the taxonomy maps
(`taxonomy.SOURCE_CLASS_MAPS["coco"]`). A proposal is added only if

  - its confidence is >= 0.5, and
  - it overlaps NO existing annotation of ANY class at IoU >= 0.3.

The second rule is deliberately conservative: a COCO `chair` sitting on a
Roboflow `couch` (mapped to `low_obstacle`) is left alone rather than
double-labelled. It will miss some genuine gaps; it should add very few wrong
boxes.

Scope. The validation split is NOT touched, so every variant in
`train_ablation.py` is still scored against identical ground truth -- which
means any gain measured there is a gain in finding the originally-annotated
objects, not an artefact of changed labels.

Output: data/processed/relabel/{images,labels}/ holding the training split
(images symlinked, labels copied plus additions) and added_boxes.csv listing
every addition, so each one can be inspected.

A second use, for evaluation only. `--split val --output data/processed/
relabel_val` builds a teacher-completed copy of the VALIDATION labels. The
original validation labels carry the same gaps, so a model trained to find the
people nobody labelled is charged a false positive every time it succeeds.
Scoring against the completed copy is the check on that. It is secondary, and
reported as such: the teacher that completed these labels also completed the
relabel variant's training labels, so it favours that variant by construction.

A third use: `--images-list` relabels any list of images, with labels found
next to each (Ultralytics' /images/ -> /labels/ convention). Used for the AI
Builders train+valid images, which carry no `person` class at all, so every
person in them would otherwise be taught as background.

Usage:
    .venv/bin/python tools/relabel_missing.py
    .venv/bin/python tools/relabel_missing.py --split val --output data/processed/relabel_val
    .venv/bin/python tools/relabel_missing.py --images-list data/processed/ablation/lists/aib_trainval.txt \
        --output data/processed/aib_relabel
"""

from __future__ import annotations

import argparse
import csv
import logging
import shutil
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from taxonomy import CANONICAL_CLASSES, SOURCE_CLASS_MAPS  # noqa: E402

log = logging.getLogger("relabel_missing")


def iou(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """IoU of one xyxy box against many."""
    if b.size == 0:
        return np.zeros(0)
    x1 = np.maximum(a[0], b[:, 0]); y1 = np.maximum(a[1], b[:, 1])
    x2 = np.minimum(a[2], b[:, 2]); y2 = np.minimum(a[3], b[:, 3])
    inter = np.clip(x2 - x1, 0, None) * np.clip(y2 - y1, 0, None)
    area_a = (a[2] - a[0]) * (a[3] - a[1])
    area_b = (b[:, 2] - b[:, 0]) * (b[:, 3] - b[:, 1])
    return inter / (area_a + area_b - inter + 1e-9)


def main():
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--teacher", default="yolo26x.pt")
    p.add_argument("--conf", type=float, default=0.5)
    p.add_argument("--max-overlap", type=float, default=0.3)
    p.add_argument("--merged", type=Path, default=root / "data/processed/merged")
    p.add_argument("--output", type=Path, default=root / "data/processed/relabel")
    p.add_argument("--device", default="cpu")
    p.add_argument("--split", default="train", choices=["train", "val"])
    p.add_argument("--images-list", type=Path, default=None,
                   help="relabel these images instead of a merged split (labels via /images/ -> /labels/)")
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M")

    import torch
    from PIL import Image
    from ultralytics import YOLO
    torch.set_num_threads(4)   # leave CPU for the training runs' data loaders

    teacher = YOLO(args.teacher)
    coco_to_taxonomy = {}
    for idx, name in teacher.names.items():
        if name in SOURCE_CLASS_MAPS["coco"]:
            coco_to_taxonomy[idx] = CANONICAL_CLASSES.index(SOURCE_CLASS_MAPS["coco"][name])
    log.info("teacher %s, mapped classes %s", args.teacher,
             {teacher.names[k]: CANONICAL_CLASSES[v] for k, v in coco_to_taxonomy.items()})

    if args.images_list is not None:
        sources = [Path(line) for line in args.images_list.read_text().splitlines() if line.strip()]
        split_name = args.images_list.stem
    else:
        rows = [r for r in csv.DictReader((args.merged / "provenance.csv").open()) if r["split"] == args.split]
        sources = [args.merged / "images" / r["new_filename"] for r in rows]
        split_name = args.split
    images_out, labels_out = args.output / "images", args.output / "labels"
    images_out.mkdir(parents=True, exist_ok=True)
    labels_out.mkdir(parents=True, exist_ok=True)

    added = []
    for k, src in enumerate(sources, 1):
        link = images_out / src.name
        if not link.exists():
            link.symlink_to(src.resolve())
        label_src = Path(str(src).replace("/images/", "/labels/")).with_suffix(".txt")
        lines = label_src.read_text().splitlines() if label_src.exists() else []

        w, h = Image.open(src).size
        existing = []
        for line in lines:
            _, cx, cy, bw, bh = map(float, line.split())
            existing.append([(cx - bw / 2) * w, (cy - bh / 2) * h, (cx + bw / 2) * w, (cy + bh / 2) * h])
        existing = np.array(existing).reshape(-1, 4)

        result = teacher.predict(str(src), conf=args.conf, classes=list(coco_to_taxonomy),
                                 imgsz=640, device=args.device, verbose=False)[0]
        new_lines = []
        for box, cls, conf in zip(result.boxes.xyxy.cpu().numpy(), result.boxes.cls.cpu().numpy().astype(int),
                                  result.boxes.conf.cpu().numpy()):
            overlap = iou(box, existing)
            if overlap.size and overlap.max() >= args.max_overlap:
                continue
            x1, y1, x2, y2 = box
            taxonomy_cls = coco_to_taxonomy[cls]
            new_lines.append(f"{taxonomy_cls} {(x1 + x2) / 2 / w:.6f} {(y1 + y2) / 2 / h:.6f} "
                             f"{(x2 - x1) / w:.6f} {(y2 - y1) / h:.6f}")
            existing = np.vstack([existing, box[None]])   # two teacher boxes cannot both fill one gap
            added.append({"image": src.name, "class": CANONICAL_CLASSES[taxonomy_cls],
                          "conf": f"{conf:.3f}", "x1": round(float(x1), 1), "y1": round(float(y1), 1),
                          "x2": round(float(x2), 1), "y2": round(float(y2), 1)})
        (labels_out / (src.stem + ".txt")).write_text("\n".join(lines + new_lines) + ("\n" if lines or new_lines else ""))
        if k % 250 == 0:
            log.info("%d/%d images, %d boxes added so far", k, len(sources), len(added))

    with (args.output / "added_boxes.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["image", "class", "conf", "x1", "y1", "x2", "y2"])
        writer.writeheader()
        writer.writerows(added)
    by_class = {}
    for a in added:
        by_class[a["class"]] = by_class.get(a["class"], 0) + 1
    log.info("added %d boxes over %d %s images: %s", len(added), len(sources), split_name, by_class)


if __name__ == "__main__":
    main()
