"""How many of the detector's "spurious" boxes are really false alarms?

A box counts as spurious in `detection_metrics.py` when it matches no annotated
object at IoU > 0.5. That conflates four different things, and only one of them
is the detector's fault:

  duplicate      overlaps an annotated object of its own class at IoU > 0.5,
                 but that object was already claimed by a better box
  other_class    overlaps an annotated object of another class at IoU > 0.5 --
                 the 62 misclassifications, plus wrong-class second boxes
  partial_same   overlaps an annotated object OF ITS OWN CLASS at
                 0.1 < IoU <= 0.5: the right thing, boxed too loosely or too
                 tightly to count -- a localisation error, not a false alarm
  partial_other  overlaps only annotated objects of other classes at
                 0.1 < IoU <= 0.5
  unannotated    overlaps nothing annotated (IoU <= 0.1). Either a real object
                 the annotators did not label -- the corpus's annotation
                 completeness has never been audited -- or a genuine false alarm

The first four are split automatically. The last cannot be: whether there is
an object under a box is a judgement about the image. So this renders a
stratified, seeded sample of `unannotated` boxes as contact sheets and writes a
manifest with an empty `verdict` column for a person to fill in. It does not
decide the verdicts itself.

Usage:
    .venv/bin/python tools/audit_spurious.py            # yolo26n, conf > 0.30
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
from collections import Counter
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from detection_metrics import (MATCH_IOU, OPERATING_THRESHOLD, _digest, _tensors,  # noqa: E402
                               load_ground_truth, load_split)
from taxonomy import CANONICAL_CLASSES  # noqa: E402

NEAR_IOU = 0.10


def spurious_boxes(prediction: dict, ground_truth: tuple, threshold: float) -> list[dict]:
    """Boxes Ultralytics' matcher leaves unmatched, with their best IoU against
    any annotated object. Uses the matcher's own record (`save_matches`) so the
    set is exactly the one `detection_metrics.py` counts."""
    from ultralytics.utils.metrics import ConfusionMatrix, box_iou

    cm = ConfusionMatrix(names=dict(enumerate(CANONICAL_CLASSES)), save_matches=True)
    detections, batch = _tensors(prediction, ground_truth)
    cm.process_batch(detections, batch, conf=threshold, iou_thres=MATCH_IOU)
    fp = cm.matches["FP"]   # unmatched boxes AND matched-but-misclassified ones
    out = []
    for box, cls, conf in zip(fp.get("bboxes", []), fp.get("cls", []), fp.get("conf", [])):
        best = 0.0
        if batch["bboxes"].shape[0]:
            best = float(box_iou(box[None], batch["bboxes"]).max())
        out.append({"xyxy": [round(float(v), 1) for v in box], "cls": int(cls),
                    "conf": float(conf), "best_iou": best})
    import torch
    gt_boxes, gt_cls = batch["bboxes"], batch["cls"]
    for b in out:
        if b["best_iou"] > MATCH_IOU:
            ious = box_iou(torch.tensor([b["xyxy"]]), gt_boxes)[0]
            same = gt_cls[ious > MATCH_IOU].int().tolist()
            b["kind"] = "duplicate" if b["cls"] in same else "other_class"
        elif b["best_iou"] > NEAR_IOU:
            ious = box_iou(torch.tensor([b["xyxy"]]), gt_boxes)[0]
            same = (gt_cls == b["cls"]) & (ious > NEAR_IOU)
            b["kind"] = "partial_same" if bool(same.any()) else "partial_other"
        else:
            b["kind"] = "unannotated"
    return out


def contact_sheet(items: list[dict], images_dir: Path, path: Path, cols: int = 4, tile: int = 300):
    from PIL import Image, ImageDraw, ImageFont

    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile, rows * (tile + 24)), "white")
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    for k, item in enumerate(items):
        image = Image.open(images_dir / item["image"]).convert("RGB")
        x1, y1, x2, y2 = item["xyxy"]
        w, h = x2 - x1, y2 - y1
        pad = max(w, h) * 0.6 + 20
        crop_box = (max(0, x1 - pad), max(0, y1 - pad),
                    min(image.width, x2 + pad), min(image.height, y2 + pad))
        draw = ImageDraw.Draw(image)
        draw.rectangle([x1, y1, x2, y2], outline=(235, 104, 52), width=max(2, image.width // 200))
        crop = image.crop(tuple(int(v) for v in crop_box))
        crop.thumbnail((tile, tile))
        cx, cy = (k % cols) * tile, (k // cols) * (tile + 24)
        sheet.paste(crop, (cx + (tile - crop.width) // 2, cy + 24 + (tile - crop.height) // 2))
        ImageDraw.Draw(sheet).text((cx + 6, cy + 4),
                                   f"#{item['id']}  {item['predicted']}  {item['conf']:.2f}",
                                   fill=(11, 11, 11), font=font)
    sheet.save(path)


def main():
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", default="yolo26n")
    p.add_argument("--weights", type=Path, default=None)
    p.add_argument("--per-class", type=int, default=6, help="sampled unannotated boxes per predicted class")
    p.add_argument("--seed", type=int, default=20260921)
    p.add_argument("--output", type=Path, default=root / "results/objective1_audit")
    args = p.parse_args()

    weights = args.weights or root / f"data/raw/finetuned_weights/{args.model}.pt"
    cache = root / f"data/processed/detection_metrics_cache/predictions_{args.model}_{_digest(weights)}.json"
    if not cache.exists():
        raise SystemExit(f"{cache} missing -- run tools/detection_metrics.py first")
    predictions = json.loads(cache.read_text())

    images_dir = root / "data/processed/merged/images"
    images = load_split(root / "data/processed/merged/provenance.csv", images_dir, "val")
    labels = root / "data/processed/merged/labels"

    boxes = []
    for item in images:
        name = item["path"].name
        for b in spurious_boxes(predictions[name], load_ground_truth(item["path"], labels), OPERATING_THRESHOLD):
            boxes.append({"image": name, "predicted": CANONICAL_CLASSES[b["cls"]], **b})

    args.output.mkdir(parents=True, exist_ok=True)
    kinds = Counter(b["kind"] for b in boxes)
    by_class = Counter((b["predicted"], b["kind"]) for b in boxes)
    with (args.output / "spurious_breakdown.csv").open("w", newline="") as f:
        w = csv.writer(f)
        order = ("duplicate", "other_class", "partial_same", "partial_other", "unannotated")
        w.writerow(["predicted_class", *order, "total"])
        for c in CANONICAL_CLASSES:
            counts = [by_class[(c, k)] for k in order]
            if sum(counts):
                w.writerow([c, *counts, sum(counts)])
        w.writerow(["ALL", *[kinds[k] for k in order], len(boxes)])
    print("FP boxes by kind:", dict(kinds))

    rng = random.Random(args.seed)
    sample = []
    for c in CANONICAL_CLASSES:
        pool = [b for b in boxes if b["kind"] == "unannotated" and b["predicted"] == c]
        sample += rng.sample(pool, min(args.per_class, len(pool)))
    for k, b in enumerate(sample, 1):
        b["id"] = k
    with (args.output / "unannotated_sample.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "image", "predicted", "conf", "x1", "y1", "x2", "y2", "verdict", "note"])
        for b in sample:
            w.writerow([b["id"], b["image"], b["predicted"], f"{b['conf']:.3f}", *b["xyxy"], "", ""])
    for s in range(0, len(sample), 12):
        contact_sheet(sample[s:s + 12], images_dir, args.output / f"sheet_{s // 12 + 1}.png")
    print(f"sampled {len(sample)} unannotated boxes -> {args.output}")


if __name__ == "__main__":
    main()
