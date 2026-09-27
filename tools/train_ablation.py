"""What moves the numbers: controlled retraining experiments on the detector.

Chapter 4's comparison holds the recipe fixed and varies the architecture. This
holds the architecture fixed (YOLO26n, Objective 1's winner) and varies one
thing at a time, to test the three changes the operating-point evaluation
pointed to (results/objective1_confusion_findings.md):

  baseline     the original recipe exactly, retrained here. The comparison
               point every other variant is measured against -- NOT the Colab
               weights, because this runs on different hardware (Apple MPS vs
               a CUDA T4) and a fair ablation changes one thing at a time.
  mosaic       + mosaic=1.0 (off for the last 10 epochs) and scale=0.5, the
               Ultralytics defaults. The original recipe disabled mosaic
               because it composes viewpoints a chest-held phone never sees;
               this tests that decision against the two things the evaluation
               found -- validation loss rising from epoch 1 (overfitting) and
               recall of 0.07 on small objects. Mosaic is the standard remedy
               for both.
  coco         + the 3,068 COCO val2017 indoor images (person / chair / table
               only) already converted into data/processed/merged, until now
               held out as `test_zeroshot`. Targets the two weakest classes.
               Risk: COCO has no door, window or stairs labels, so any in
               those photos are taught as background.
  mosaic_coco  both.
  relabel      the original training images with missing person / chair /
               table annotations filled in by tools/relabel_missing.py, after
               the spurious-box audit found most confident person and chair
               "false alarms" sat on real, unlabelled objects. Validation is
               untouched, so a gain here is a gain against the original labels.
  mosaic_relabel  mosaic plus relabel.
  aib          + the AI Builders set's train and valid splits (1,242 images,
               tools/import_ai_builders.py): 667 more doors, and the corpus's
               first 36 poles. Its own test split is kept back as a second
               evaluation set, the only one containing `pole`.
  full         mosaic + relabel + aib, with the AI Builders images relabelled
               too (they carry no `person` class, so every person in them would
               otherwise be background). The candidate recipe after the single-
               change results: mosaic and relabel helped on the photograph sets,
               aib took the researcher's captures from 11 to 37 of 102.
  s_<variant>  the same recipe on YOLO26s instead of YOLO26n.

Everything else is the original recipe from train_colab.ipynb, which the Colab
checkpoints' own `train_args` confirm: 50 epochs, 640, batch 16, no vertical
flip, hsv_s 0.4, hsv_v 0.3, degrees 10, seed 0, deterministic. Validation is
always the same 678-image scene-split `val` set, so every variant is scored on
identical ground truth.

One run is one sample. The two Colab runs of the original recipe differed by
0.006 pooled mAP50-95, so a difference smaller than about 0.01 between two
variants here is not evidence of anything.

Usage:
    .venv/bin/python tools/train_ablation.py baseline mosaic
    .venv/bin/python tools/detection_metrics.py --weights baseline=data/processed/ablation/weights/baseline.pt ...
"""

from __future__ import annotations

import argparse
import csv
import logging
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from taxonomy import CANONICAL_CLASSES  # noqa: E402

log = logging.getLogger("train_ablation")

# train_colab.ipynb's COMMON_TRAIN_KWARGS, verbatim.
ORIGINAL_RECIPE = dict(
    epochs=50, imgsz=640, batch=16,
    fliplr=0.5, flipud=0.0, degrees=10.0, translate=0.1, scale=0.2,
    shear=0.0, perspective=0.0, mosaic=0.0, mixup=0.0,
    hsv_h=0.015, hsv_s=0.4, hsv_v=0.3,
    seed=0, deterministic=True,
)

MOSAIC = dict(mosaic=1.0, close_mosaic=10, scale=0.5)

VARIANTS = {
    "baseline":       {"model": "yolo26n.pt", "train": "train",         "overrides": {}},
    "mosaic":         {"model": "yolo26n.pt", "train": "train",         "overrides": MOSAIC},
    "coco":           {"model": "yolo26n.pt", "train": "train_coco",    "overrides": {}},
    "mosaic_coco":    {"model": "yolo26n.pt", "train": "train_coco",    "overrides": MOSAIC},
    "relabel":        {"model": "yolo26n.pt", "train": "train_relabel", "overrides": {}},
    "mosaic_relabel": {"model": "yolo26n.pt", "train": "train_relabel", "overrides": MOSAIC},
    "aib":            {"model": "yolo26n.pt", "train": "train_aib",     "overrides": {}},
    "full":           {"model": "yolo26n.pt", "train": "train_full",    "overrides": MOSAIC},
}
for name in list(VARIANTS):
    VARIANTS[f"s_{name}"] = {**VARIANTS[name], "model": "yolo26s.pt"}


def write_lists(provenance: Path, images: Path, out: Path, relabel_images: Path,
                aib: Path, aib_relabel_images: Path) -> dict[str, Path]:
    rows = list(csv.DictReader(provenance.open()))
    def paths(split):
        return [str(images / r["new_filename"]) for r in rows if r["split"] == split]
    lists = {"train": paths("train"), "val": paths("val"), "coco": paths("test_zeroshot")}
    out.mkdir(parents=True, exist_ok=True)
    files = {}
    for key, items in lists.items():
        files[key] = out / f"{key}.txt"
        files[key].write_text("\n".join(items) + "\n")
    files["train_coco"] = out / "train_coco.txt"
    files["train_coco"].write_text("\n".join(lists["train"] + lists["coco"]) + "\n")
    # Same training images, reached through the relabelled tree so Ultralytics
    # pairs each with its relabelled .txt (it swaps /images/ for /labels/).
    if relabel_images.exists():
        files["train_relabel"] = out / "train_relabel.txt"
        files["train_relabel"].write_text(
            "\n".join(str(relabel_images / Path(x).name) for x in lists["train"]) + "\n")
    if (aib / "manifest.csv").exists():
        manifest = list(csv.DictReader((aib / "manifest.csv").open()))
        extra = [str(aib / "images" / r["new_filename"]) for r in manifest if r["source_split"] != "test"]
        test = [str(aib / "images" / r["new_filename"]) for r in manifest if r["source_split"] == "test"]
        files["train_aib"] = out / "train_aib.txt"
        files["train_aib"].write_text("\n".join(lists["train"] + extra) + "\n")
        files["aib_test"] = out / "aib_test.txt"
        files["aib_test"].write_text("\n".join(test) + "\n")
    if "train_relabel" in files and (aib_relabel_images.parent / "added_boxes.csv").exists():
        files["train_full"] = out / "train_full.txt"
        files["train_full"].write_text(
            files["train_relabel"].read_text()
            + "\n".join(str(p) for p in sorted(aib_relabel_images.iterdir())) + "\n")
    log.info("train %d, val %d, coco %d", len(lists["train"]), len(lists["val"]), len(lists["coco"]))
    return files


def data_yaml(out: Path, train_list: Path, val_list: Path, name: str) -> Path:
    path = out / f"data_{name}.yaml"
    path.write_text(f"train: {train_list}\nval: {val_list}\n"
                    f"nc: {len(CANONICAL_CLASSES)}\nnames: {CANONICAL_CLASSES}\n")
    return path


def main():
    root = Path(__file__).resolve().parent.parent
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("variants", nargs="+", choices=sorted(VARIANTS))
    p.add_argument("--provenance", type=Path, default=root / "data/processed/merged/provenance.csv")
    p.add_argument("--images", type=Path, default=root / "data/processed/merged/images")
    p.add_argument("--output", type=Path, default=root / "data/processed/ablation")
    p.add_argument("--relabel-images", type=Path, default=root / "data/processed/relabel/images")
    p.add_argument("--aib", type=Path, default=root / "data/processed/aib")
    p.add_argument("--aib-relabel-images", type=Path, default=root / "data/processed/aib_relabel/images")
    p.add_argument("--device", default="mps")
    p.add_argument("--workers", type=int, default=4)
    args = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M")

    from ultralytics import YOLO

    lists = write_lists(args.provenance, args.images, args.output / "lists", args.relabel_images,
                        args.aib, args.aib_relabel_images)
    weights_dir = args.output / "weights"
    weights_dir.mkdir(parents=True, exist_ok=True)

    for name in args.variants:
        spec = VARIANTS[name]
        target = weights_dir / f"{name}.pt"
        if target.exists():
            log.info("%s: %s exists, skipping (delete it to retrain)", name, target)
            continue
        if spec["train"] not in lists:
            raise SystemExit(f"{name}: no {spec['train']} list -- run tools/relabel_missing.py first")
        yaml = data_yaml(args.output / "lists", lists[spec["train"]], lists["val"], name)
        recipe = {**ORIGINAL_RECIPE, **spec["overrides"]}
        log.info("%s: %s, train=%s, overrides=%s", name, spec["model"], spec["train"], spec["overrides"])
        started = time.time()
        model = YOLO(spec["model"])
        model.train(data=str(yaml), device=args.device, workers=args.workers,
                    project=str(args.output / "runs"), name=name, exist_ok=True,
                    plots=False, verbose=False, **recipe)
        best = Path(model.trainer.save_dir) / "weights" / "best.pt"
        shutil.copyfile(best, target)
        log.info("%s: done in %.0f min -> %s", name, (time.time() - started) / 60, target)


if __name__ == "__main__":
    main()
