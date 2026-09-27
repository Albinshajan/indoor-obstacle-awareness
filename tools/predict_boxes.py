#!/usr/bin/env python3
"""Run a fine-tuned detector over the tape-measured capture set and emit the
boxes CSV that distance_eval.py's --boxes-csv expects.

    python predict_boxes.py --capture-dir data/raw/captures \
        --weights data/raw/finetuned_weights/yolo26n.pt \
        --output results/objective2/boxes.csv

Without this, distance_eval.py falls back to a centred ROI and flags every
row; CLAUDE.md section 8 is explicit that those numbers must not be cited.
yolo26n is the default because it won Objective 1 outright
(results/objective1_full_table.md).

Two details that are easy to get wrong:

1. ORIENTATION. The capture app writes RGB, depth and confidence in ARKit's
   native unrotated sensor frame and records device orientation as a
   cosmetic EXIF tag only (see FrameWriter.swift's header comment). cv2's
   imread -- which is what Ultralytics uses when handed a file path --
   APPLIES EXIF orientation; PIL, which distance_eval.py uses for the
   monocular path, does not. Handing Ultralytics a path would therefore
   silently produce boxes in a rotated frame that no longer lines up with
   the depth array. This script loads every frame itself with PIL and passes
   the array, so the detector, the monocular depth map and the ARKit depth
   map all share one coordinate space.

2. CLASS MATCHING. The capture class parsed from the filename is not always
   a detector class name -- see taxonomy.CAPTURE_CLASS_TO_DETECTOR. The
   highest-confidence detection whose class is acceptable for that capture
   class wins. If nothing acceptable is found, the highest-confidence
   detection of any class is used and the row is marked `other_class` so it
   can be audited or excluded; frames with no detection at all are written
   to the report and omitted from the CSV, which lets distance_eval.py fall
   back and flag them rather than silently inheriting a wrong box.

Writes the CSV plus a short markdown report of per-class detection coverage
next to it.
"""
from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
from pathlib import Path

import numpy as np

from orientation import upright_rgb
from taxonomy import CAPTURE_CLASS_TO_DETECTOR

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("predict_boxes")

# Same convention as distance_eval.py; kept independent so neither script
# imports the other.
FILENAME_RE = re.compile(
    r"^obj-(?P<cls>[a-zA-Z_]+)_d-(?P<mm>\d+)_light-(?P<light>bright|dim)_rep-(?P<rep>\d+)$"
)

CSV_FIELDS = [
    "filename", "x1", "y1", "x2", "y2", "img_w", "img_h",
    "expected_class", "detected_class", "confidence", "match",
]


def load_frame(path: Path) -> tuple[np.ndarray, int, int, int]:
    """Upright BGR array for Ultralytics, plus its width, height and the EXIF tag.

    The frame is rotated upright before detection -- see orientation.py for why
    this is not optional. Box coordinates are therefore in UPRIGHT pixel space,
    and distance_eval.py rotates the depth maps to match.
    """
    rgb, orientation = upright_rgb(path)
    return rgb[:, :, ::-1].copy(), rgb.shape[1], rgb.shape[0], orientation


def pick_box(result, expected_class: str, names: dict[int, str]):
    """Highest-confidence acceptable detection, else highest-confidence anything."""
    boxes = result.boxes
    if boxes is None or len(boxes) == 0:
        return None

    acceptable = CAPTURE_CLASS_TO_DETECTOR.get(expected_class, [expected_class])
    candidates = []
    for i in range(len(boxes)):
        cls_name = names.get(int(boxes.cls[i]), str(int(boxes.cls[i])))
        conf = float(boxes.conf[i])
        xyxy = [int(round(v)) for v in boxes.xyxy[i].tolist()]
        candidates.append((cls_name, conf, xyxy))

    preferred = [c for c in candidates if c[0] in acceptable]
    if preferred:
        # Rank by the map's own preference order first, then confidence, so a
        # real `pole` would beat a `wall` even at lower confidence.
        best = min(preferred, key=lambda c: (acceptable.index(c[0]), -c[1]))
        return best, "expected"
    best = max(candidates, key=lambda c: c[1])
    return best, "other_class"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--capture-dir", required=True)
    p.add_argument("--output", required=True, help="path to the boxes CSV to write")
    p.add_argument("--weights", default="data/raw/finetuned_weights/yolo26n.pt")
    p.add_argument("--conf", type=float, default=0.25, help="detector confidence threshold")
    p.add_argument("--imgsz", type=int, default=640)
    args = p.parse_args()

    capture_dir = Path(args.capture_dir)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    frames = sorted(capture_dir.glob("obj-*.jpg"))
    if not frames:
        sys.exit(f"no obj-*.jpg frames under {capture_dir}")

    from ultralytics import YOLO

    model = YOLO(args.weights)
    names = {int(k): v for k, v in model.names.items()}
    log.info("%s: %d classes %s", args.weights, len(names), sorted(names.values()))

    rows = []
    no_detection = []
    warned_orientation = False

    for jpg_path in frames:
        m = FILENAME_RE.match(jpg_path.stem)
        if m is None:
            log.warning("%s: filename doesn't match the capture convention, skipping", jpg_path.name)
            continue
        expected_class = m.group("cls")

        bgr, img_w, img_h, orientation = load_frame(jpg_path)
        if orientation != 1 and not warned_orientation:
            log.info(
                "%s carries EXIF orientation %d; frames are rotated upright before detection "
                "and boxes are written in upright pixel space", jpg_path.name, orientation)
            warned_orientation = True

        result = model.predict(bgr, conf=args.conf, imgsz=args.imgsz, verbose=False)[0]
        picked = pick_box(result, expected_class, names)
        if picked is None:
            no_detection.append((jpg_path.name, expected_class))
            continue

        (cls_name, conf, (x1, y1, x2, y2)), match = picked
        rows.append({
            "filename": jpg_path.name, "x1": x1, "y1": y1, "x2": x2, "y2": y2,
            "img_w": img_w, "img_h": img_h, "expected_class": expected_class,
            "detected_class": cls_name, "confidence": f"{conf:.4f}", "match": match,
        })

    if not rows:
        sys.exit(f"{len(frames)} frames read, zero produced a usable box -- nothing written")

    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    write_report(output_path.with_suffix(".md"), frames, rows, no_detection, args)
    log.info("%d/%d frames got a box -> %s", len(rows), len(frames), output_path)
    if no_detection:
        log.warning(
            "%d frames had no detection at all and are absent from the CSV; distance_eval.py "
            "will use its centred-ROI fallback and flag them", len(no_detection))


def write_report(path: Path, frames, rows, no_detection, args):
    by_class: dict[str, dict] = {}
    for r in rows:
        s = by_class.setdefault(r["expected_class"], {"expected": 0, "other_class": 0, "none": 0, "detected_as": {}})
        s[r["match"]] += 1
        s["detected_as"][r["detected_class"]] = s["detected_as"].get(r["detected_class"], 0) + 1
    for _name, cls in no_detection:
        by_class.setdefault(cls, {"expected": 0, "other_class": 0, "none": 0, "detected_as": {}})["none"] += 1

    lines = [
        "# Objective 2 — detector box coverage over the capture set",
        "",
        f"Weights: `{args.weights}` (conf {args.conf}, imgsz {args.imgsz})  ",
        f"Frames: {len(frames)} — {len(rows)} with a box, {len(no_detection)} with no detection",
        "",
        "| capture class | expected class hit | other class | no detection | detected as |",
        "|---|---|---|---|---|",
    ]
    for cls in sorted(by_class):
        s = by_class[cls]
        detected_as = ", ".join(f"{k} ×{v}" for k, v in sorted(s["detected_as"].items(), key=lambda kv: -kv[1]))
        lines.append(f"| {cls} | {s['expected']} | {s['other_class']} | {s['none']} | {detected_as or '—'} |")

    lines += [
        "",
        "`other class` rows carry a real detector box but of a class other than the one",
        "photographed — they are kept and flagged rather than dropped, so they can be",
        "excluded from the headline numbers if that is the honest call. `no detection`",
        "frames are absent from the CSV entirely; distance_eval.py falls back to a",
        "centred ROI for them and marks `roi_source=centred_roi_fallback`.",
    ]
    if no_detection:
        lines += ["", "Frames with no detection:", ""] + [f"- `{n}` ({c})" for n, c in no_detection]
    path.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
