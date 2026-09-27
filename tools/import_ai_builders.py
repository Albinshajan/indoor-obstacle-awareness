"""Bring the AI Builders indoor-objects set (Kaggle thepbordin/indoor-object-
detection, GPL-3.0) into the 12-class taxonomy as a SEPARATE tree, without
touching data/processed/merged.

Why separate. Re-running `prepare_data.py merge` with this source added would
re-draw the scene split and change the validation set that every Objective 1
number is measured on. Here the source keeps its own published splits instead:
train + valid become extra TRAINING data for `train_ablation.py`'s `aib`
variant, and its 107-image test split becomes a second evaluation set -- the
only place `pole` can be measured at all, since the main validation set has
none.

Class mapping: taxonomy.SOURCE_CLASS_MAPS["ai_builders_jaiinsom"] (verified
against the real data.yaml, 2026-09-21); cabinetDoor and refrigeratorDoor are
dropped on purpose.

What the images are, from their file names (checked 2026-09-22; an earlier note
here called them NYU-derived frames, which the images themselves contradict):
1,117 carry 16-hex-digit names, the Open Images ID format that the Roboflow
source also uses; 138 are numbered PNGs; 54 are two door-photo sequences
(DOR_S1_*, DOR_S3_*); the rest are web-style names. Scenes include homes,
offices, shops and a railway platform. Only 4 photographs are shared with the
Roboflow source, all on its training side, so neither validation set is
contaminated. The DOR_* sequences are consecutive shots, so near-duplicates can
straddle this source's own splits, and numbers on its test split may be
somewhat optimistic.

Usage:
    .venv/bin/python tools/import_ai_builders.py
"""

from __future__ import annotations

import argparse
import csv
import logging
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_data import read_names, remap_boxes  # noqa: E402
from taxonomy import CANONICAL_CLASSES, SOURCE_CLASS_MAPS  # noqa: E402

log = logging.getLogger("import_ai_builders")


def main():
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--source", type=Path, default=root / "data/raw/ai_builders_jaiinsom")
    p.add_argument("--output", type=Path, default=root / "data/processed/aib")
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    raw_names = read_names(args.source / "data.yaml")
    class_map = SOURCE_CLASS_MAPS["ai_builders_jaiinsom"]
    (args.output / "images").mkdir(parents=True, exist_ok=True)
    (args.output / "labels").mkdir(parents=True, exist_ok=True)

    warned: set[str] = set()
    rows, counts = [], Counter()
    for split in ("train", "valid", "test"):
        for image in sorted((args.source / split / "images").iterdir()):
            name = f"aib__{image.name}"
            link = args.output / "images" / name
            if not link.exists():
                link.symlink_to(image.resolve())
            boxes = remap_boxes(args.source / split / "labels" / (image.stem + ".txt"), raw_names, class_map, warned)
            (args.output / "labels" / (Path(name).stem + ".txt")).write_text(
                "".join(f"{c} {x:.6f} {y:.6f} {w:.6f} {h:.6f}\n" for c, x, y, w, h in boxes))
            for c, *_ in boxes:
                counts[(split, CANONICAL_CLASSES[c])] += 1
            rows.append({"new_filename": name, "source_split": split, "boxes": len(boxes)})

    with (args.output / "manifest.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["new_filename", "source_split", "boxes"])
        w.writeheader()
        w.writerows(rows)
    for split in ("train", "valid", "test"):
        n = sum(1 for r in rows if r["source_split"] == split)
        log.info("%s: %d images, %s", split, n,
                 {c: counts[(split, c)] for c in CANONICAL_CLASSES if counts[(split, c)]})


if __name__ == "__main__":
    main()
