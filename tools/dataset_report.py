#!/usr/bin/env python3
"""Stage 3.3: per-class instance counts, train/val balance, image-size and box-area distributions.

    python dataset_report.py --merged-dir data/processed/merged --output results/dataset_report.md

Reads the merged pool `prepare_data.py` produces (images/, labels/,
provenance.csv) and reports the numbers Chapter 3/4 need to defend the
taxonomy's class balance -- flagging any class under 50 instances as noise
rather than letting a single pooled mAP hide it (CLAUDE.md section 5).
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

from taxonomy import CANONICAL_CLASSES

MIN_INSTANCES_REPORTABLE = 50


def load_split_map(provenance_path: Path) -> dict[str, str]:
    import csv
    split_by_stem = {}
    with open(provenance_path) as f:
        for row in csv.DictReader(f):
            split_by_stem[Path(row["new_filename"]).stem] = row["split"]
    return split_by_stem


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--merged-dir", required=True)
    p.add_argument("--output", default="results/dataset_report.md")
    args = p.parse_args()

    merged_dir = Path(args.merged_dir)
    images_dir = merged_dir / "images"
    labels_dir = merged_dir / "labels"
    split_by_stem = load_split_map(merged_dir / "provenance.csv")

    instance_counts: Counter = Counter()
    instance_counts_by_split: dict[str, Counter] = defaultdict(Counter)
    box_areas: list[float] = []
    box_areas_by_class: dict[str, list[float]] = defaultdict(list)
    image_sizes: list[tuple[int, int]] = []
    n_images_by_split: Counter = Counter()

    label_files = sorted(labels_dir.glob("*.txt"))
    for label_path in label_files:
        stem = label_path.stem
        split = split_by_stem.get(stem, "unknown")
        n_images_by_split[split] += 1

        for ext in (".jpg", ".jpeg", ".png"):
            candidate = images_dir / f"{stem}{ext}"
            if candidate.exists():
                with Image.open(candidate) as img:
                    image_sizes.append(img.size)
                break

        for line in label_path.read_text().splitlines():
            if not line.strip():
                continue
            parts = line.split()
            class_id = int(parts[0])
            w, h = float(parts[3]), float(parts[4])
            cname = CANONICAL_CLASSES[class_id]
            instance_counts[cname] += 1
            instance_counts_by_split[split][cname] += 1
            area = w * h
            box_areas.append(area)
            box_areas_by_class[cname].append(area)

    lines = ["# Dataset report", "", f"Generated from `{merged_dir}` ({len(label_files)} images).", ""]

    lines.append("## Images per split")
    lines.append("")
    for split, n in sorted(n_images_by_split.items()):
        lines.append(f"- {split}: {n}")
    lines.append("")

    lines.append("## Per-class instance counts")
    lines.append("")
    lines.append("| class | train | val | test_zeroshot | other | total | flag |")
    lines.append("|---|---|---|---|---|---|---|")
    for c in CANONICAL_CLASSES:
        total = instance_counts.get(c, 0)
        if total == 0:
            continue
        train_n = instance_counts_by_split.get("train", Counter()).get(c, 0)
        val_n = instance_counts_by_split.get("val", Counter()).get(c, 0)
        test_n = instance_counts_by_split.get("test_zeroshot", Counter()).get(c, 0)
        other_n = total - train_n - val_n - test_n
        flag = "UNDER 50 -- noisy" if total < MIN_INSTANCES_REPORTABLE else ""
        lines.append(f"| {c} | {train_n} | {val_n} | {test_n} | {other_n} | {total} | {flag} |")
    missing = [c for c in CANONICAL_CLASSES if instance_counts.get(c, 0) == 0]
    lines.append("")
    lines.append(f"Zero instances so far: {', '.join(missing) if missing else 'none'}")
    lines.append("")

    if image_sizes:
        widths = np.array([w for w, _h in image_sizes])
        heights = np.array([h for _w, h in image_sizes])
        lines.append("## Image size distribution")
        lines.append("")
        lines.append(f"- width: min={widths.min()} max={widths.max()} mean={widths.mean():.0f} median={np.median(widths):.0f}")
        lines.append(f"- height: min={heights.min()} max={heights.max()} mean={heights.mean():.0f} median={np.median(heights):.0f}")
        top_sizes = Counter(image_sizes).most_common(5)
        lines.append(f"- most common (w,h): {top_sizes}")
        lines.append("")

    if box_areas:
        areas = np.array(box_areas)
        lines.append("## Box-area distribution (fraction of image area)")
        lines.append("")
        lines.append(f"- min={areas.min():.4f} max={areas.max():.4f} mean={areas.mean():.4f} median={np.median(areas):.4f}")
        lines.append(f"- p10={np.percentile(areas, 10):.4f} p90={np.percentile(areas, 90):.4f}")
        lines.append("")
        lines.append("### Median box-area by class")
        lines.append("")
        lines.append("| class | n_boxes | median_area_frac |")
        lines.append("|---|---|---|")
        for c in CANONICAL_CLASSES:
            vals = box_areas_by_class.get(c)
            if not vals:
                continue
            lines.append(f"| {c} | {len(vals)} | {np.median(vals):.4f} |")
        lines.append("")

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n")
    print(f"wrote {output_path}")


if __name__ == "__main__":
    main()
