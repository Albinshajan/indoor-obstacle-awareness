#!/usr/bin/env python3
"""Export the three detectors and Depth-Anything-V2-Metric-Indoor-Small to Core ML.

    python export_coreml.py --targets depth --depth-checkpoint <path> --output out/
    python export_coreml.py --targets yolov8n yolo11n yolo26n --output out/
    python export_coreml.py --output out/          # everything

Run `--targets depth` on its own first: the depth conversion is traced
through torch.jit rather than using Ultralytics' maintained export path, so
it is the one most likely to need a coremltools/torch version nudge
(CLAUDE.md section 8).

Every export appends one row to out/manifest.csv (and out/manifest.json)
recording parameter count, on-disk size and licence, so Chapter 3/4 can cite
one file for the deployment-cost side of Objective 1.
"""
from __future__ import annotations

import argparse
import csv
import json
import logging
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("export_coreml")

DETECTOR_LICENCE = "AGPL-3.0"
DEPTH_LICENCE = "Apache-2.0 (Depth-Anything-V2-Metric-Indoor-Small only -- Base/Large/Giant are CC-BY-NC-4.0, do not substitute)"

# Ultralytics weight filenames. yolo26n may not exist in older ultralytics
# releases -- if `.export()` raises for it, upgrade the ultralytics package
# rather than substituting a different model.
DETECTOR_WEIGHTS = {
    "yolov8n": "yolov8n.pt",
    "yolo11n": "yolo11n.pt",
    "yolo26n": "yolo26n.pt",
}

IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


def dir_size_bytes(path: Path) -> int:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


class ManifestWriter:
    def __init__(self, output_dir: Path):
        self.path_json = output_dir / "manifest.json"
        self.path_csv = output_dir / "manifest.csv"
        self.entries = json.loads(self.path_json.read_text()) if self.path_json.exists() else []

    def add(self, entry: dict):
        self.entries = [e for e in self.entries if e["model"] != entry["model"]] + [entry]

    def flush(self):
        self.path_json.write_text(json.dumps(self.entries, indent=2))
        if self.entries:
            with open(self.path_csv, "w", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=list(self.entries[0].keys()))
                writer.writeheader()
                writer.writerows(self.entries)


def export_detector(name: str, weights_dir: Path | None, imgsz: int, output_dir: Path, manifest: ManifestWriter):
    from ultralytics import YOLO

    weights = (weights_dir / DETECTOR_WEIGHTS[name]) if weights_dir else DETECTOR_WEIGHTS[name]
    log.info("loading %s (%s)", name, weights)
    model = YOLO(str(weights))
    num_params = sum(p.numel() for p in model.model.parameters())

    exported_path = model.export(format="coreml", imgsz=imgsz, nms=True, half=False)
    exported_path = Path(exported_path)

    final_path = output_dir / f"{name}.mlpackage"
    if exported_path.resolve() != final_path.resolve():
        if final_path.exists():
            import shutil
            shutil.rmtree(final_path)
        exported_path.rename(final_path)

    manifest.add({
        "model": name,
        "task": "detection",
        "format": "coreml_mlpackage",
        "input_size": imgsz,
        "num_params": num_params,
        "file_size_bytes": dir_size_bytes(final_path),
        "licence": DETECTOR_LICENCE,
        "weights_source": str(weights),
    })
    log.info("%s -> %s (%d params, %.1f MB)", name, final_path, num_params, dir_size_bytes(final_path) / 1e6)


def build_normalized_depth_module(depth_net, max_depth: float):
    import torch
    import torch.nn as nn

    class NormalizedDepthModel(nn.Module):
        """Bakes ImageNet mean/std normalisation into the traced graph.

        Core ML's ImageType input only accepts one scalar `scale` shared
        across channels (plus a per-channel `bias`), which cannot express
        three different per-channel std-devs. Normalising inside the traced
        module avoids approximating that with an averaged scale.
        """

        def __init__(self, net, max_depth):
            super().__init__()
            self.net = net
            self.register_buffer("mean", torch.tensor(IMAGENET_MEAN).view(1, 3, 1, 1))
            self.register_buffer("std", torch.tensor(IMAGENET_STD).view(1, 3, 1, 1))
            self.max_depth = max_depth

        def forward(self, x):
            # x arrives 0..1 (Core ML ImageType configured with scale=1/255, bias=0)
            x = (x - self.mean) / self.std
            depth = self.net(x)
            return depth.clamp(0.0, self.max_depth)

    return NormalizedDepthModel(depth_net, max_depth)


def load_depth_anything_v2(checkpoint: Path, repo_dir: Path | None, max_depth: float):
    """Load DAv2-Metric-Hypersim-Small (the "Indoor" metric model -- Hypersim is the
    synthetic indoor dataset it's trained on; CLAUDE.md's "Indoor" naming refers to
    this same checkpoint, HuggingFace calls it "Hypersim"). Verified 2026-09-08
    against the real DepthAnything/Depth-Anything-V2 repo and a real export run.

    Import from `<repo_dir>/metric_depth`, NOT the repo root: the metric variant is
    a genuinely different `DepthAnythingV2` class (Sigmoid + max_depth scaling in its
    output head) living in `metric_depth/depth_anything_v2/dpt.py`, distinct from the
    repo root's `depth_anything_v2/dpt.py` (unbounded relative depth, no max_depth).
    Importing from the repo root silently loads the wrong class -- it has the same
    name and a compatible-looking constructor, so this fails at load_state_dict()
    with a confusing shape/key mismatch rather than an import error.
    """
    import torch

    if repo_dir:
        sys.path.insert(0, str(Path(repo_dir) / "metric_depth"))
    try:
        from depth_anything_v2.dpt import DepthAnythingV2
    except ImportError as e:
        sys.exit(
            "could not import depth_anything_v2 -- clone DepthAnything/Depth-Anything-V2 "
            f"and pass --depth-repo <path to repo root> (not metric_depth itself): {e}"
        )

    model_config = {"encoder": "vits", "features": 64, "out_channels": [48, 96, 192, 384], "max_depth": max_depth}
    net = DepthAnythingV2(**model_config)
    state_dict = torch.load(checkpoint, map_location="cpu")
    net.load_state_dict(state_dict)
    net.eval()
    return net


def export_depth(checkpoint: Path, repo_dir: Path | None, input_size: int, max_depth: float, output_dir: Path, manifest: ManifestWriter):
    import coremltools as ct
    import torch

    if input_size % 14 != 0:
        sys.exit(f"--input-size must be a multiple of 14 (DINOv2 patch size), got {input_size}")

    depth_net = load_depth_anything_v2(checkpoint, repo_dir, max_depth)
    num_params = sum(p.numel() for p in depth_net.parameters())
    wrapped = build_normalized_depth_module(depth_net, max_depth)
    wrapped.eval()

    example_input = torch.rand(1, 3, input_size, input_size)
    # coremltools 9.0's PyTorch frontend has no 'upsample_bicubic2d' converter (confirmed
    # 2026-09-08 -- NotImplementedError at trace time, independent of minimum_deployment_target).
    # DINOv2's positional-embedding resize (metric_depth/depth_anything_v2/dinov2.py,
    # interpolate_pos_encoding) is the only bicubic call in this model. Since it's resizing a
    # smooth, low-frequency signal (not image content), swapping it for bilinear during tracing
    # only is a low-risk substitute -- not something to do silently, hence this comment.
    import torch.nn.functional as F
    original_interpolate = F.interpolate

    def _bilinear_instead_of_bicubic(*args, **kwargs):
        if kwargs.get("mode") == "bicubic":
            kwargs["mode"] = "bilinear"
        return original_interpolate(*args, **kwargs)

    F.interpolate = _bilinear_instead_of_bicubic
    try:
        traced = torch.jit.trace(wrapped, example_input)
    finally:
        F.interpolate = original_interpolate

    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=example_input.shape, scale=1 / 255.0, bias=[0, 0, 0])],
        outputs=[ct.TensorType(name="depth_metres")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
    )

    final_path = output_dir / f"depth_anything_v2_metric_indoor_small_{input_size}.mlpackage"
    mlmodel.save(str(final_path))

    manifest.add({
        "model": f"dav2_metric_indoor_small_{input_size}",
        "task": "monocular_depth",
        "format": "coreml_mlprogram",
        "input_size": input_size,
        "num_params": num_params,
        "file_size_bytes": dir_size_bytes(final_path),
        "licence": DEPTH_LICENCE,
        "weights_source": str(checkpoint),
    })
    log.info("depth (%dpx) -> %s (%d params, %.1f MB)", input_size, final_path, num_params, dir_size_bytes(final_path) / 1e6)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--targets", nargs="+", default=["yolov8n", "yolo11n", "yolo26n", "depth"],
                    choices=["yolov8n", "yolo11n", "yolo26n", "depth"])
    p.add_argument("--weights-dir", default=None, help="directory containing yolo*.pt; omit to let ultralytics auto-download")
    p.add_argument("--imgsz", type=int, default=640, help="detector input size")
    p.add_argument("--depth-checkpoint", default=None, help="path to the DAv2-Metric-Indoor-Small .pth")
    p.add_argument("--depth-repo", default=None, help="path to a cloned Depth-Anything-V2 repo, added to sys.path")
    p.add_argument("--input-size", type=int, default=518, help="depth model input side, must be a multiple of 14 (392/322 are faster -- benchmark)")
    p.add_argument("--max-depth", type=float, default=20.0)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = ManifestWriter(output_dir)

    for target in args.targets:
        if target == "depth":
            if not args.depth_checkpoint:
                sys.exit("--depth-checkpoint is required to export the depth model")
            export_depth(Path(args.depth_checkpoint), Path(args.depth_repo) if args.depth_repo else None,
                         args.input_size, args.max_depth, output_dir, manifest)
        else:
            export_detector(target, Path(args.weights_dir) if args.weights_dir else None, args.imgsz, output_dir, manifest)

    manifest.flush()
    log.info("manifest written to %s", manifest.path_json)


if __name__ == "__main__":
    main()
