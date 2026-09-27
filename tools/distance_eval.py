#!/usr/bin/env python3
"""Objective 2: distance-estimation accuracy against the tape-measured capture set.

    python distance_eval.py --capture-dir captures/ --output out/
    python distance_eval.py --capture-dir captures/ --output out/ --run-monocular \
        --depth-checkpoint dav2_metric_indoor_small.pth --depth-repo ../Depth-Anything-V2

Reads CLAUDE.md's own-capture filename convention (ground truth is parsed
from the filename, there is no separate log):

    obj-<class>_d-<mm>_light-<bright|dim>_rep-<n>.jpg
    obj-<class>_d-<mm>_light-<bright|dim>_rep-<n>.depth.npy   (ARKit sceneDepth, metres)
    obj-<class>_d-<mm>_light-<bright|dim>_rep-<n>.conf.npy    (ARConfidenceLevel per pixel, optional)

Distance is sampled as the median depth over the lower third of the object's
bounding box (median, not mean, so one background pixel bleeding into the
region can't wreck the estimate). Bounding boxes come from --boxes-csv
(filename,x1,y1,x2,y2[,img_w,img_h] -- written by predict_boxes.py from the
fine-tuned detector's own predictions) when given; otherwise a centred ROI
fallback is used and every row is flagged so it isn't mistaken for a
detector-driven number.

Every frame is rotated upright before use (orientation.py) -- the detector
cannot see a scene lying on its side. Box coordinates are in the upright RGB
frame's pixel space, but the two depth sources are not: ARKit sceneDepth is 256x192 while the monocular map is at
full RGB resolution. Every ROI is therefore converted to fractions of the
frame on load and back to pixels separately per depth array.

Writes two files to --output: results_long.csv (one row per frame per
method) and results_summary.csv (MAE/MAPE/RMSE/bias grouped by method,
0.5 m distance bin, class, and lighting).
"""
from __future__ import annotations

import argparse
import csv
import logging
import re
import sys
from pathlib import Path

import numpy as np

from orientation import exif_orientation, upright_map, upright_rgb
from taxonomy import CAPTURE_CLASSES

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("distance_eval")

FILENAME_RE = re.compile(
    r"^obj-(?P<cls>[a-zA-Z_]+)_d-(?P<mm>\d+)_light-(?P<light>bright|dim)_rep-(?P<rep>\d+)$"
)

RESULT_FIELDS = [
    "filename", "method", "class", "lighting", "rep",
    "truth_m", "pred_m", "error_m", "abs_error_m", "pct_error", "distance_bin_m", "roi_source",
]


# Below this, a parsed distance is a typo rather than a measurement. The
# capture app's field is labelled "Distance (mm)" but accepts any integer, so
# a value entered in metres (`2.5` -> `d-2`) or a smoke-test placeholder
# (`d-1`) parses as 1-2 mm of ground truth. Left in, those rows don't just add
# noise: MAPE divides by the truth, so a 1 mm truth contributes a percentage
# error in the hundreds of thousands and swamps every honest frame in the
# pooled summary. The nearest real station is 500 mm.
MIN_PLAUSIBLE_MM = 250


def parse_stem(stem: str) -> dict | None:
    m = FILENAME_RE.match(stem)
    if not m:
        return None
    d = m.groupdict()
    if d["cls"] not in CAPTURE_CLASSES:
        log.warning("%s: class %r is not in taxonomy.CAPTURE_CLASSES %s", stem, d["cls"], CAPTURE_CLASSES)
    return {
        "cls": d["cls"],
        "truth_m": int(d["mm"]) / 1000.0,
        "light": d["light"],
        "rep": int(d["rep"]),
    }


def load_boxes_csv(path: Path) -> dict[str, dict]:
    """filename,x1,y1,x2,y2[,img_w,img_h] -- coordinates in the RGB frame's pixel space.

    img_w/img_h record the image size those coordinates were measured in; when
    the columns are absent the JPEG itself is read to recover it.
    """
    boxes = {}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            boxes[row["filename"]] = {
                "box": (int(row["x1"]), int(row["y1"]), int(row["x2"]), int(row["y2"])),
                "img_w": int(row["img_w"]) if row.get("img_w") else None,
                "img_h": int(row["img_h"]) if row.get("img_h") else None,
            }
    return boxes


def image_size(path: Path) -> tuple[int, int]:
    """(width, height) without applying EXIF orientation -- the capture files are
    written in ARKit's unrotated sensor frame and the orientation tag is
    cosmetic (see FrameWriter.swift)."""
    from PIL import Image

    with Image.open(path) as img:
        return img.size


def to_fractions(box: tuple[int, int, int, int], img_w: int, img_h: int) -> tuple[float, float, float, float]:
    x1, y1, x2, y2 = box
    return x1 / img_w, y1 / img_h, x2 / img_w, y2 / img_h


def to_pixels(frac_box: tuple[float, float, float, float], shape: tuple[int, int]) -> tuple[int, int, int, int]:
    """Fractional ROI -> pixel box in an array of `shape` (h, w).

    The RGB frame (1920x1440) and the ARKit depth map (256x192) share a 4:3
    aspect ratio, so this is a clean uniform scale with no cropping or
    rotation correction -- confirmed against a real capture's intrinsics JSON.
    """
    h, w = shape
    fx1, fy1, fx2, fy2 = frac_box
    return round(fx1 * w), round(fy1 * h), round(fx2 * w), round(fy2 * h)


def lower_third(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = box
    y_split = y1 + round(2 * (y2 - y1) / 3)
    return x1, y_split, x2, y2


def centred_roi_fractions(width_frac: float, height_frac: float) -> tuple[float, float, float, float]:
    x1, y1 = (1 - width_frac) / 2, (1 - height_frac) / 2
    return x1, y1, x1 + width_frac, y1 + height_frac


def sample_median_depth(depth: np.ndarray, conf: np.ndarray | None, box: tuple[int, int, int, int], confidence_threshold: int) -> float | None:
    x1, y1, x2, y2 = lower_third(box)
    x1, y1 = max(x1, 0), max(y1, 0)
    x2, y2 = min(x2, depth.shape[1]), min(y2, depth.shape[0])
    if x2 <= x1 or y2 <= y1:
        return None
    region = depth[y1:y2, x1:x2]
    valid = np.isfinite(region) & (region > 0)
    if conf is not None:
        conf_region = conf[y1:y2, x1:x2]
        valid &= conf_region >= confidence_threshold
    values = region[valid]
    if values.size == 0:
        return None
    return float(np.median(values))


def compute_metrics(rows: list[dict]) -> dict:
    errors = np.array([r["error_m"] for r in rows])
    abs_errors = np.abs(errors)
    truths = np.array([r["truth_m"] for r in rows])
    return {
        "n": len(rows),
        "mae_m": float(abs_errors.mean()),
        "mape_pct": float((abs_errors / truths * 100).mean()),
        "rmse_m": float(np.sqrt((errors ** 2).mean())),
        "bias_m": float(errors.mean()),
    }


def summarize(rows: list[dict], output_path: Path):
    groupings = [
        ("method", lambda r: r["method"]),
        ("method_bin", lambda r: (r["method"], r["distance_bin_m"])),
        ("method_class", lambda r: (r["method"], r["class"])),
        ("method_light", lambda r: (r["method"], r["lighting"])),
    ]
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["grouping", "key", "n", "mae_m", "mape_pct", "rmse_m", "bias_m"])
        for grouping_name, key_fn in groupings:
            groups: dict = {}
            for r in rows:
                groups.setdefault(key_fn(r), []).append(r)
            for key, group_rows in sorted(groups.items(), key=lambda kv: str(kv[0])):
                m = compute_metrics(group_rows)
                writer.writerow([grouping_name, key, m["n"], f"{m['mae_m']:.4f}", f"{m['mape_pct']:.2f}", f"{m['rmse_m']:.4f}", f"{m['bias_m']:.4f}"])


def run_monocular_prediction(rgb_path: Path, depth_net, input_size: int) -> np.ndarray:
    """Metric depth in metres, at the frame's own resolution.

    Delegates to the checkpoint's own `infer_image`, which applies the
    preprocessing the model was trained with: an ASPECT-PRESERVING resize to
    the next multiple of 14 at or above `input_size` (lower_bound), bicubic,
    ImageNet normalisation, then a bilinear interpolation of the predicted
    depth back to the source resolution. An earlier version of this function
    squashed the frame to input_size x input_size, which distorts a 4:3
    capture by 25% horizontally before a metric depth model ever sees it.

    The frame is rotated upright first, matching predict_boxes.py and the
    rotated depth maps below, so every array shares one coordinate space.
    """
    rgb, _orientation = upright_rgb(rgb_path)
    return depth_net.infer_image(rgb[:, :, ::-1].copy(), input_size)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--capture-dir", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--boxes-csv", default=None, help="filename,x1,y1,x2,y2 -- e.g. from the fine-tuned detector's predictions")
    p.add_argument("--roi-width-frac", type=float, default=0.5, help="fallback centred-ROI width when --boxes-csv has no entry for a frame")
    p.add_argument("--roi-height-frac", type=float, default=0.7)
    p.add_argument("--min-distance-mm", type=int, default=MIN_PLAUSIBLE_MM,
                   help=f"skip frames whose filename claims a distance below this (default {MIN_PLAUSIBLE_MM}); "
                        "guards against a distance typed in metres or a smoke-test placeholder")
    p.add_argument("--confidence-threshold", type=int, default=1, help="minimum ARConfidenceLevel to keep a depth pixel (0=none,1=low,2=medium/high)")
    p.add_argument("--run-monocular", action="store_true", help="also evaluate Depth-Anything-V2 on the RGB frames")
    p.add_argument("--depth-checkpoint", default=None)
    p.add_argument("--depth-repo", default=None)
    p.add_argument("--input-size", type=int, default=518)
    args = p.parse_args()

    capture_dir = Path(args.capture_dir)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    boxes = load_boxes_csv(Path(args.boxes_csv)) if args.boxes_csv else {}

    depth_net = None
    if args.run_monocular:
        if not args.depth_checkpoint:
            sys.exit("--run-monocular requires --depth-checkpoint")
        sys.path.insert(0, str(Path(__file__).parent))
        from export_coreml import load_depth_anything_v2
        depth_net = load_depth_anything_v2(Path(args.depth_checkpoint), Path(args.depth_repo) if args.depth_repo else None, max_depth=20.0)
        # image2tensor picks cuda/mps/cpu on its own; the weights have to follow
        # it or the forward pass dies on a device mismatch.
        import torch

        device = "cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu"
        depth_net = depth_net.to(device).eval()
        log.info("monocular depth on %s, input_size %d (aspect-preserving)", device, args.input_size)

    rows = []
    n_skipped = 0
    for jpg_path in sorted(capture_dir.glob("obj-*.jpg")):
        stem = jpg_path.stem
        meta = parse_stem(stem)
        if meta is None:
            log.warning("%s: filename doesn't match the capture convention, skipping", jpg_path.name)
            n_skipped += 1
            continue

        if meta["truth_m"] * 1000 < args.min_distance_mm:
            log.warning(
                "%s: claims %.0f mm of ground truth, below --min-distance-mm %d -- skipping. "
                "This is almost certainly a distance typed in metres or a smoke-test frame, "
                "not a real measurement", jpg_path.name, meta["truth_m"] * 1000, args.min_distance_mm)
            n_skipped += 1
            continue

        depth_path = capture_dir / f"{stem}.depth.npy"
        if not depth_path.exists():
            log.warning("%s: no matching .depth.npy, skipping", jpg_path.name)
            n_skipped += 1
            continue
        # Rotate depth and confidence upright to match the detector boxes, which
        # predict_boxes.py produces from the upright frame. See orientation.py.
        orientation = exif_orientation(jpg_path)
        lidar_depth = upright_map(np.load(depth_path), orientation)

        conf_path = capture_dir / f"{stem}.conf.npy"
        conf = upright_map(np.load(conf_path), orientation) if conf_path.exists() else None

        entry = boxes.get(jpg_path.name)
        if entry is not None:
            img_w, img_h = entry["img_w"], entry["img_h"]
            if img_w is None or img_h is None:
                img_w, img_h = image_size(jpg_path)
            frac_box, roi_source = to_fractions(entry["box"], img_w, img_h), "detector"
        else:
            frac_box, roi_source = centred_roi_fractions(args.roi_width_frac, args.roi_height_frac), "centred_roi_fallback"

        lidar_pred = sample_median_depth(lidar_depth, conf, to_pixels(frac_box, lidar_depth.shape), args.confidence_threshold)
        if lidar_pred is None:
            log.warning("%s: no valid LiDAR pixels in ROI (possibly beyond the ~5 m LiDAR range ceiling, or all low-confidence)", jpg_path.name)
        else:
            error = lidar_pred - meta["truth_m"]
            rows.append({
                "filename": jpg_path.name, "method": "lidar", "class": meta["cls"], "lighting": meta["light"], "rep": meta["rep"],
                "truth_m": meta["truth_m"], "pred_m": lidar_pred, "error_m": error, "abs_error_m": abs(error),
                "pct_error": abs(error) / meta["truth_m"] * 100, "distance_bin_m": round(meta["truth_m"] * 2) / 2, "roi_source": roi_source,
            })

        if depth_net is not None:
            mono_depth = run_monocular_prediction(jpg_path, depth_net, args.input_size)
            mono_pred = sample_median_depth(mono_depth, None, to_pixels(frac_box, mono_depth.shape), 0)
            if mono_pred is not None:
                error = mono_pred - meta["truth_m"]
                rows.append({
                    "filename": jpg_path.name, "method": "monocular", "class": meta["cls"], "lighting": meta["light"], "rep": meta["rep"],
                    "truth_m": meta["truth_m"], "pred_m": mono_pred, "error_m": error, "abs_error_m": abs(error),
                    "pct_error": abs(error) / meta["truth_m"] * 100, "distance_bin_m": round(meta["truth_m"] * 2) / 2, "roi_source": roi_source,
                })

    if not rows:
        sys.exit("no frames produced a valid distance estimate, nothing to report")

    long_path = output_dir / "results_long.csv"
    with open(long_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=RESULT_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    summary_path = output_dir / "results_summary.csv"
    summarize(rows, summary_path)

    log.info("%d frames evaluated, %d skipped -> %s, %s", len(rows), n_skipped, long_path, summary_path)
    if not boxes:
        log.warning("no --boxes-csv given: every ROI used the centred-ROI fallback, not real detector boxes -- fine for a first pass, but re-run with detector-predicted boxes before citing these numbers")


if __name__ == "__main__":
    main()
