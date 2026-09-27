#!/usr/bin/env python3
"""Merge the indoor-obstacle sources into the 12-class taxonomy (CLAUDE.md section 5).

Three independent subcommands, each appending to one shared provenance.csv so
the data-provenance appendix and the ethics amendment can be built from a
single file:

    prepare_data.py merge --source roboflow_lochan=<dir> --source ai_builders_jaiinsom=<dir> --output <out_dir>
    prepare_data.py coco --annotations instances_val2017.json --images <val2017_dir> --output <out_dir>
    prepare_data.py nyu --mat nyu_depth_v2_labeled.mat --output <out_dir> [--splits splits.mat]

`merge` splits by scene (not by image) before it does anything else, because
the Roboflow sets are frame-extracted from video and a random image-level
split would put near-duplicate frames on both sides of train/val.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import logging
import re
import sys
from pathlib import Path

import yaml

from taxonomy import CANONICAL_CLASSES, CLASS_TO_ID, SOURCE_CLASS_MAPS

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("prepare_data")

SOURCE_LICENCES = {
    "roboflow_lochan": "CC BY 4.0",
    "ai_builders_jaiinsom": "GNU GPL 3.0",
    "coco": "CC BY 4.0 (annotations)",
    "nyu_depth_v2": "unverified mirror -- confirm licence before publishing derived files",
}

PROVENANCE_FIELDS = [
    "new_filename",
    "original_filename",
    "source",
    "licence",
    "scene_id",
    "split",
    "classes_present",
    "contains_person",
]

DEFAULT_SCENE_REGEX = re.compile(
    r"^(?P<scene>.+?)(?:_jpg\.rf\.[0-9a-f]+)?(?:[_-]frame[_-]?\d+)?$", re.IGNORECASE
)


class ProvenanceWriter:
    """Appends to output_dir/provenance.csv, writing the header only once."""

    def __init__(self, output_dir: Path):
        self.path = output_dir / "provenance.csv"
        is_new = not self.path.exists()
        self._fh = open(self.path, "a", newline="")
        self._writer = csv.DictWriter(self._fh, fieldnames=PROVENANCE_FIELDS)
        if is_new:
            self._writer.writeheader()

    def write(self, row: dict):
        self._writer.writerow(row)

    def close(self):
        self._fh.close()


def read_names(yaml_path: Path) -> dict[int, str] | None:
    """Return {index: raw_name} from a Roboflow data.yaml, or None if unrecognised.

    Roboflow exports use either a list (`names: [door, stairs, ...]`) or a
    dict (`names: {0: door, 1: stairs, ...}`). Anything else is reported as
    "no names found" rather than silently producing empty labels.
    """
    with open(yaml_path) as f:
        data = yaml.safe_load(f)
    names = data.get("names") if isinstance(data, dict) else None
    if names is None:
        log.warning("%s: no names found", yaml_path)
        return None
    if isinstance(names, list):
        return {i: n for i, n in enumerate(names)}
    if isinstance(names, dict):
        return {int(k): v for k, v in names.items()}
    log.warning("%s: no names found (unrecognised names layout %s)", yaml_path, type(names).__name__)
    return None


def discover_images(source_dir: Path) -> list[tuple[Path, Path]]:
    """Return [(image_path, label_dir), ...] across a source directory.

    Real Roboflow YOLOv8 exports split into train/valid/test subdirectories,
    each with their own images/ and labels/ (confirmed against the actual
    lochan-r-ugnn4/indoor-objects-detection-h2mgz export, 2026-09-07) --
    not the flat images/+labels/ layout originally assumed here. We pool
    all splits together and re-split by scene ourselves regardless, so
    Roboflow's own train/valid/test assignment doesn't matter to us.
    Falls back to a flat images/+labels/ layout for sources that use it.
    """
    split_dirs = [source_dir / split for split in ("train", "valid", "test") if (source_dir / split / "images").is_dir()]
    if not split_dirs:
        split_dirs = [source_dir] if (source_dir / "images").is_dir() else []

    pairs = []
    for split_dir in split_dirs:
        image_dir = split_dir / "images"
        label_dir = split_dir / "labels"
        for image_path in sorted(p for p in image_dir.iterdir() if p.suffix.lower() in (".jpg", ".jpeg", ".png")):
            pairs.append((image_path, label_dir))
    return pairs


def scene_id_for(stem: str, scene_regex: re.Pattern) -> str:
    m = scene_regex.match(stem)
    scene = m.group("scene") if m and m.group("scene") else stem
    if scene == stem:
        log.debug("%s: no scene pattern matched, treating each image as its own scene", stem)
    return scene


def scene_split(scene_ids: list[str], val_fraction: float, seed: int) -> dict[str, str]:
    """Deterministically assign each unique scene to train or val."""
    unique_scenes = sorted(set(scene_ids))
    rng_input = [f"{seed}:{s}".encode() for s in unique_scenes]
    hashed = sorted(zip(rng_input, unique_scenes), key=lambda t: hashlib.sha256(t[0]).hexdigest())
    n_val = round(len(unique_scenes) * val_fraction)
    val_scenes = {s for _, s in hashed[:n_val]}
    return {s: ("val" if s in val_scenes else "train") for s in unique_scenes}


def write_split_manifest(records: list, split_map: dict[str, str], manifest_path: Path):
    """One row per scene: which side of the train/val split it landed on and how many images it contributed.

    This is the scene-level record Chapter 3 cites for "split by scene, not
    by image" -- provenance.csv has the same split column per-image, but
    this is the compact group-level view.
    """
    counts: dict[str, int] = {}
    for _source_key, _image_path, _label_path, scene_id, _boxes in records:
        counts[scene_id] = counts.get(scene_id, 0) + 1

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(manifest_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["scene_id", "split", "n_images"])
        for scene_id in sorted(counts):
            writer.writerow([scene_id, split_map[scene_id], counts[scene_id]])
    log.info("wrote scene-level split manifest (%d scenes) to %s", len(counts), manifest_path)


def remap_boxes(label_path: Path, raw_names: dict[int, str], class_map: dict[str, str], warned: set[str]) -> list[tuple[int, float, float, float, float]]:
    boxes = []
    if not label_path.exists():
        return boxes
    for line in label_path.read_text().splitlines():
        parts = line.split()
        if len(parts) != 5:
            continue
        raw_id, cx, cy, w, h = parts
        raw_name = raw_names.get(int(raw_id))
        canonical = class_map.get(raw_name) if raw_name is not None else None
        if canonical is None:
            key = raw_name or f"id:{raw_id}"
            if key not in warned:
                log.warning("unmapped raw class %r, dropping its boxes (add it to SOURCE_CLASS_MAPS if it should map)", key)
                warned.add(key)
            continue
        boxes.append((CLASS_TO_ID[canonical], float(cx), float(cy), float(w), float(h)))
    return boxes


def cmd_merge(args):
    output_dir = Path(args.output)
    (output_dir / "images").mkdir(parents=True, exist_ok=True)
    (output_dir / "labels").mkdir(parents=True, exist_ok=True)
    scene_regex = re.compile(args.scene_regex, re.IGNORECASE) if args.scene_regex else DEFAULT_SCENE_REGEX

    sources = {}
    for spec in args.source:
        key, _, path = spec.partition("=")
        if key not in SOURCE_CLASS_MAPS:
            sys.exit(f"unknown source key {key!r}, expected one of {list(SOURCE_CLASS_MAPS)}")
        sources[key] = Path(path)

    records = []  # (source_key, image_path, label_path, scene_id, boxes)
    for source_key, source_dir in sources.items():
        yaml_path = source_dir / "data.yaml"
        raw_names = read_names(yaml_path)
        if raw_names is None:
            log.error("skipping source %s: could not read class names from %s", source_key, yaml_path)
            continue
        class_map = SOURCE_CLASS_MAPS[source_key]
        warned: set[str] = set()
        image_label_pairs = discover_images(source_dir)
        if not image_label_pairs:
            log.error("skipping source %s: no images/ found under %s (checked train/valid/test and flat layout)", source_key, source_dir)
            continue
        for image_path, label_dir in image_label_pairs:
            label_path = label_dir / f"{image_path.stem}.txt"
            boxes = remap_boxes(label_path, raw_names, class_map, warned)
            if not boxes:
                continue
            scene = scene_id_for(image_path.stem, scene_regex)
            records.append((source_key, image_path, label_path, f"{source_key}:{scene}", boxes))

    if not records:
        log.error("no images survived class remapping, nothing written")
        return

    split_map = scene_split([r[3] for r in records], args.val_fraction, args.seed)
    write_split_manifest(records, split_map, Path(args.split_manifest))

    provenance = ProvenanceWriter(output_dir)
    for source_key, image_path, _label_path, scene_id, boxes in records:
        new_stem = f"{source_key}__{image_path.stem}"
        new_image = output_dir / "images" / f"{new_stem}{image_path.suffix.lower()}"
        new_label = output_dir / "labels" / f"{new_stem}.txt"
        new_image.write_bytes(image_path.read_bytes())
        new_label.write_text("\n".join(f"{c} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}" for c, cx, cy, w, h in boxes) + "\n")

        classes_present = sorted({CANONICAL_CLASSES[c] for c, *_ in boxes})
        provenance.write({
            "new_filename": new_image.name,
            "original_filename": image_path.name,
            "source": source_key,
            "licence": SOURCE_LICENCES.get(source_key, "unknown"),
            "scene_id": scene_id,
            "split": split_map[scene_id],
            "classes_present": ";".join(classes_present),
            "contains_person": "person" in classes_present,
        })
    provenance.close()
    log.info("merged %d images from %d source(s) into %s", len(records), len(sources), output_dir)


def coco_bbox_to_yolo(bbox, img_w, img_h):
    x, y, w, h = bbox
    cx = (x + w / 2) / img_w
    cy = (y + h / 2) / img_h
    return cx, cy, w / img_w, h / img_h


def cmd_coco(args):
    output_dir = Path(args.output)
    (output_dir / "images").mkdir(parents=True, exist_ok=True)
    (output_dir / "labels").mkdir(parents=True, exist_ok=True)

    with open(args.annotations) as f:
        coco = json.load(f)

    class_map = SOURCE_CLASS_MAPS["coco"]
    cat_id_to_name = {c["id"]: c["name"] for c in coco["categories"]}
    images_by_id = {im["id"]: im for im in coco["images"]}

    boxes_by_image: dict[int, list] = {}
    for ann in coco["annotations"]:
        raw_name = cat_id_to_name.get(ann["category_id"])
        canonical = class_map.get(raw_name)
        if canonical is None:
            continue
        img = images_by_id[ann["image_id"]]
        cx, cy, w, h = coco_bbox_to_yolo(ann["bbox"], img["width"], img["height"])
        boxes_by_image.setdefault(ann["image_id"], []).append((CLASS_TO_ID[canonical], cx, cy, w, h))

    if not boxes_by_image:
        log.error("no COCO annotations matched the indoor class map in taxonomy.SOURCE_CLASS_MAPS['coco']")
        return

    images_dir = Path(args.images)
    provenance = ProvenanceWriter(output_dir)
    for image_id, boxes in boxes_by_image.items():
        img = images_by_id[image_id]
        src_path = images_dir / img["file_name"]
        if not src_path.exists():
            log.warning("missing image file %s, skipping", src_path)
            continue
        new_stem = f"coco__{src_path.stem}"
        new_image = output_dir / "images" / f"{new_stem}{src_path.suffix.lower()}"
        new_label = output_dir / "labels" / f"{new_stem}.txt"
        new_image.write_bytes(src_path.read_bytes())
        new_label.write_text("\n".join(f"{c} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}" for c, cx, cy, w, h in boxes) + "\n")

        classes_present = sorted({CANONICAL_CLASSES[c] for c, *_ in boxes})
        provenance.write({
            "new_filename": new_image.name,
            "original_filename": img["file_name"],
            "source": "coco",
            "licence": SOURCE_LICENCES["coco"],
            "scene_id": f"coco:{img['file_name']}",
            "split": "test_zeroshot",
            "classes_present": ";".join(classes_present),
            "contains_person": "person" in classes_present,
        })
    provenance.close()
    log.info("wrote %d COCO indoor-subset images to %s (zero-shot baseline, not for training)", len(boxes_by_image), output_dir)


def cmd_nyu(args):
    import h5py
    import numpy as np
    from PIL import Image

    output_dir = Path(args.output)
    (output_dir / "rgb").mkdir(parents=True, exist_ok=True)
    (output_dir / "depth").mkdir(parents=True, exist_ok=True)

    split_of_index = {}
    if args.splits:
        try:
            from scipy.io import loadmat
            splits = loadmat(args.splits)
            for idx in splits["trainNdxs"].flatten():
                split_of_index[int(idx) - 1] = "train"
            for idx in splits["testNdxs"].flatten():
                split_of_index[int(idx) - 1] = "test"
        except Exception:
            log.exception("could not read --splits %s, leaving split column as 'unsplit'", args.splits)

    try:
        mat = h5py.File(args.mat, "r")
    except OSError:
        sys.exit(
            f"{args.mat} is not an HDF5 (.mat v7.3) file. NYU Depth V2 labeled releases before some "
            "distributions ship pre-v7.3 .mat files, which need scipy.io.loadmat instead of h5py -- "
            "this script only implements the h5py path."
        )

    images = mat["images"]     # (N, 3, H, W)
    depths = mat["depths"]     # (N, H, W), metres
    n = images.shape[0]

    provenance = ProvenanceWriter(output_dir)
    manifest_path = output_dir / "nyu_manifest.csv"
    with open(manifest_path, "w", newline="") as mf:
        manifest = csv.writer(mf)
        manifest.writerow(["index", "rgb_path", "depth_path", "split"])
        for i in range(n):
            rgb = np.transpose(images[i], (2, 1, 0)).astype("uint8")
            depth = np.transpose(depths[i], (1, 0)).astype("float32")

            rgb_name = f"nyu_{i:05d}.jpg"
            depth_name = f"nyu_{i:05d}.npy"
            Image.fromarray(rgb).save(output_dir / "rgb" / rgb_name)
            np.save(output_dir / "depth" / depth_name, depth)

            split = split_of_index.get(i, "unsplit")
            manifest.writerow([i, f"rgb/{rgb_name}", f"depth/{depth_name}", split])
            provenance.write({
                "new_filename": rgb_name,
                "original_filename": f"nyu_depth_v2_labeled.mat[{i}]",
                "source": "nyu_depth_v2",
                "licence": SOURCE_LICENCES["nyu_depth_v2"],
                "scene_id": f"nyu:{i}",
                "split": split,
                "classes_present": "",
                "contains_person": "",
            })
    provenance.close()
    log.info("wrote %d NYU Depth V2 pairs to %s (manifest: %s)", n, output_dir, manifest_path)


def build_parser():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)

    merge = sub.add_parser("merge", help="merge Roboflow/AI Builders sources into the 12-class taxonomy, split by scene")
    merge.add_argument("--source", action="append", required=True, metavar="KEY=DIR",
                        help="e.g. roboflow_lochan=/data/roboflow_indoor_objects (repeatable)")
    merge.add_argument("--output", required=True)
    merge.add_argument("--val-fraction", type=float, default=0.2)
    merge.add_argument("--seed", type=int, default=0)
    merge.add_argument("--scene-regex", default=None,
                        help="regex with a named group 'scene'; default strips Roboflow's _jpg.rf.<hash> and _frame\\d+ suffixes")
    merge.add_argument("--split-manifest", default="results/split_manifest.csv",
                        help="scene-level train/val split record (Chapter 3's 'split by scene' evidence)")
    merge.set_defaults(func=cmd_merge)

    coco = sub.add_parser("coco", help="convert COCO val2017 indoor subset to a zero-shot baseline set")
    coco.add_argument("--annotations", required=True, help="path to instances_val2017.json")
    coco.add_argument("--images", required=True, help="path to val2017 image directory")
    coco.add_argument("--output", required=True)
    coco.set_defaults(func=cmd_coco)

    nyu = sub.add_parser("nyu", help="extract NYU Depth V2 (labeled) into rgb/depth pairs + manifest")
    nyu.add_argument("--mat", required=True, help="path to nyu_depth_v2_labeled.mat (v7.3/HDF5)")
    nyu.add_argument("--splits", default=None, help="optional splits.mat with the official Eigen train/test indices")
    nyu.add_argument("--output", required=True)
    nyu.set_defaults(func=cmd_nyu)

    return p


def main():
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
