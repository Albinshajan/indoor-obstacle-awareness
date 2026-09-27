#!/usr/bin/env python3
"""Shared EXIF-orientation handling for the capture set.

The capture app writes RGB, depth and confidence in ARKit's native *unrotated
sensor frame* and records the display orientation as a cosmetic EXIF tag (see
FrameWriter.swift). For a portrait-held phone that tag is 6, meaning the stored
pixels must be rotated 90 degrees clockwise to appear upright.

That matters more than "cosmetic" suggests. Measured on the real capture set
(2026-09-15): of four frames deliberately aimed at an object, the fine-tuned
detector found **zero** in the stored orientation and **four** once rotated
upright -- a chair going from no detection at all to 0.96 confidence. The
training corpus is upright indoor photography; a scene lying on its side is out
of distribution, and the detector simply does not see it.

So detection must run on the upright image. The depth and confidence maps must
then be rotated the same way, or the boxes no longer index the right pixels.
This module is the single definition of "the same way", imported by both
predict_boxes.py and distance_eval.py so the two cannot drift apart.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

# EXIF orientation -> number of counter-clockwise 90-degree turns needed to
# bring the stored pixels upright, as np.rot90's k argument. Only the four
# rotation-without-mirroring cases occur here; mirrored values (2, 4, 5, 7) are
# not produced by the capture app and fall back to no rotation.
_ROT90_K = {1: 0, 3: 2, 6: 3, 8: 1}

EXIF_ORIENTATION_TAG = 274


def exif_orientation(jpeg_path: Path) -> int:
    """Orientation tag of a capture JPEG; 1 (no rotation) when absent."""
    from PIL import Image

    with Image.open(jpeg_path) as img:
        return (img.getexif() or {}).get(EXIF_ORIENTATION_TAG, 1)


def rot90_k(orientation: int) -> int:
    """np.rot90 `k` that brings an array from stored to upright orientation."""
    return _ROT90_K.get(orientation, 0)


def upright_rgb(jpeg_path: Path) -> tuple[np.ndarray, int]:
    """(upright RGB array, orientation tag).

    Loaded via PIL and rotated explicitly rather than by cv2, whose imread
    applies EXIF orientation silently -- doing it here keeps the rotation in one
    visible place that the depth maps can be matched against.
    """
    from PIL import Image

    with Image.open(jpeg_path) as img:
        orientation = (img.getexif() or {}).get(EXIF_ORIENTATION_TAG, 1)
        rgb = np.asarray(img.convert("RGB"))
    return np.rot90(rgb, k=rot90_k(orientation)).copy(), orientation


def upright_map(arr: np.ndarray, orientation: int) -> np.ndarray:
    """Rotate a depth or confidence map to match `upright_rgb`."""
    return np.rot90(arr, k=rot90_k(orientation)).copy()
