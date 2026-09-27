#!/usr/bin/env python3
"""Objective 2, second pass: uncertainty, box placement and error structure.

    python tools/distance_uncertainty.py

Reads what distance_eval.py already wrote -- nothing is re-sampled from the
depth maps -- and asks four questions the first pass did not:

1. How wide are the intervals? MAE, MAPE and bias per method with a
   percentile bootstrap over frames (10,000 resamples, seed 0), and the paired
   LiDAR-versus-monocular difference over the frames where both exist.
2. Was the box on the object? results/objective2/box_placement_audit.csv
   records, for each of the 38 detector boxes, whether it carries the
   photographed class, lies on the photographed object under another class
   name, or lies somewhere else. The headline figures are re-read by placement.
3. Is the monocular error noise or calibration? A straight-line fit of
   estimate on truth, and a leave-one-out linear recalibration. The
   recalibration is post hoc and exploratory: it needs tape-measured ground
   truth from the same camera to fit, so it is not a deployable method.
4. Does LiDAR error really fall with range, or does the class mix change
   across bins? Rank correlation of error with distance, for all frames and
   for doors alone.

Writes results/objective2/uncertainty.md and
docs/thesis/figures/figure_4_3_distance_estimates.png.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
LONG = ROOT / "results/objective2/results_long.csv"
PLACEMENT = ROOT / "results/objective2/box_placement_audit.csv"
OUT_MD = ROOT / "results/objective2/uncertainty.md"
OUT_FIG = ROOT / "docs/thesis/figures/figure_4_3_distance_estimates.png"

B = 10_000
SEED = 0

# Same validated palette and ink as detection_metrics.py (Figures 4.1-4.2),
# so the three Chapter 4 figures read as one set. Slot order is fixed.
CATEGORICAL = ["#2a78d6", "#eb6834"]
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
GRID = "#e4e3df"


def boot_ci(values: np.ndarray, rng: np.random.Generator, stat=np.mean) -> tuple[float, float]:
    values = np.asarray(values, dtype=float)
    idx = rng.integers(0, len(values), size=(B, len(values)))
    draws = stat(values[idx], axis=1)
    lo, hi = np.percentile(draws, [2.5, 97.5])
    return float(lo), float(hi)


def spearman(x: np.ndarray, y: np.ndarray) -> float:
    rx = pd.Series(x).rank().to_numpy()
    ry = pd.Series(y).rank().to_numpy()
    return float(np.corrcoef(rx, ry)[0, 1])


def loo_recalibrated_abs_error(truth: np.ndarray, pred: np.ndarray) -> np.ndarray:
    """|truth - (a*pred + b)| with a, b fitted on every other frame."""
    out = np.empty(len(truth))
    for i in range(len(truth)):
        keep = np.arange(len(truth)) != i
        a, b = np.polyfit(pred[keep], truth[keep], 1)
        out[i] = abs(truth[i] - (a * pred[i] + b))
    return out


def figure(detector: pd.DataFrame) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(6.4, 5.2), dpi=200)
    lim = (0, 7)
    ax.plot(lim, lim, color=INK_SECONDARY, linestyle="--", linewidth=1, zorder=1)
    ax.text(2.05, 1.55, "estimate = tape measure", fontsize=8, color=INK_SECONDARY, rotation=0)

    specs = [("lidar", "LiDAR (ARKit sceneDepth)", "o", CATEGORICAL[0]),
             ("monocular", "Monocular (DAv2 Metric-Hypersim-S)", "s", CATEGORICAL[1])]
    jitter = {"lidar": -0.05, "monocular": 0.05}
    for method, label, marker, colour in specs:
        d = detector[detector.method == method]
        on = d[d.placement != "off_object"]
        off = d[d.placement == "off_object"]
        ax.scatter(on.truth_m + jitter[method], on.pred_m, s=34, marker=marker, color=colour,
                   edgecolors="white", linewidths=1.2, zorder=3, label=label)
        ax.scatter(off.truth_m + jitter[method], off.pred_m, s=34, marker=marker, facecolors="white",
                   edgecolors=colour, linewidths=1.4, zorder=3)

    # Direct labels beside each cloud, in text ink; the marker carries identity.
    ax.text(2.2, 4.45, "monocular", fontsize=8, color=INK)
    ax.text(4.2, 3.55, "LiDAR", fontsize=8, color=INK)

    ax.set_xlim(0, 5)
    ax.set_ylim(*lim)
    ax.set_xlabel("Tape-measured distance (m)")
    ax.set_ylabel("Estimated distance (m)")
    ax.grid(color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.tick_params(colors=INK_SECONDARY, labelsize=9)
    ax.xaxis.label.set_color(INK_SECONDARY)
    ax.yaxis.label.set_color(INK_SECONDARY)
    leg = ax.legend(loc="upper left", fontsize=8, frameon=False)
    for text in leg.get_texts():
        text.set_color(INK)
    ax.text(0.02, 0.83, "Hollow markers: box not on the photographed object", transform=ax.transAxes,
            fontsize=7.5, color=INK_SECONDARY)
    fig.tight_layout()
    OUT_FIG.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_FIG, facecolor="white")
    plt.close(fig)


def main() -> None:
    rng = np.random.default_rng(SEED)
    long = pd.read_csv(LONG)
    detector = long[long.roi_source == "detector"].copy()
    placement = pd.read_csv(PLACEMENT)[["filename", "placement", "detected_class"]]
    detector = detector.merge(placement, on="filename", how="left")
    assert detector.placement.notna().all(), "a detector frame has no placement verdict"

    lines = ["# Objective 2 — uncertainty, box placement and error structure", "",
             "Generated by `tools/distance_uncertainty.py` from `results_long.csv` (detector-driven rows only) "
             "and `box_placement_audit.csv`. Percentile bootstrap over frames, "
             f"{B:,} resamples, seed {SEED}.", ""]

    # 1. Intervals.
    lines += ["## 1. Headline figures with 95 % intervals", "",
              "| method | n | MAE (m) | 95 % CI | MAPE | 95 % CI | bias (m) | 95 % CI | median abs error (m) |",
              "|---|---|---|---|---|---|---|---|---|"]
    for method in ("lidar", "monocular"):
        d = detector[detector.method == method]
        ae, pe, e = d.abs_error_m.to_numpy(), d.pct_error.to_numpy(), d.error_m.to_numpy()
        m_lo, m_hi = boot_ci(ae, rng)
        p_lo, p_hi = boot_ci(pe, rng)
        b_lo, b_hi = boot_ci(e, rng)
        lines.append(f"| {method} | {len(d)} | {ae.mean():.3f} | {m_lo:.3f}–{m_hi:.3f} | {pe.mean():.1f} % | "
                     f"{p_lo:.1f}–{p_hi:.1f} % | {e.mean():+.3f} | {b_lo:+.3f} to {b_hi:+.3f} | {np.median(ae):.3f} |")

    lidar = detector[detector.method == "lidar"].set_index("filename")
    mono = detector[detector.method == "monocular"].set_index("filename")
    both = lidar.index.intersection(mono.index)
    diff = (mono.loc[both].abs_error_m - lidar.loc[both].abs_error_m).to_numpy()
    d_lo, d_hi = boot_ci(diff, rng)
    lines += ["", f"Paired over the {len(both)} frames with both estimates: monocular absolute error exceeds "
              f"LiDAR's by {diff.mean():.3f} m on average (95 % CI {d_lo:.3f}–{d_hi:.3f}); LiDAR is closer to "
              f"the tape measure in {(diff > 0).sum()} of {len(both)} frames.", ""]

    # 2. Placement.
    lines += ["## 2. By box placement", "",
              "| method | placement | n | MAE (m) | bias (m) |", "|---|---|---|---|---|"]
    for method in ("lidar", "monocular"):
        d = detector[detector.method == method]
        for place in ("on_object_same_class", "on_object_other_class", "off_object"):
            s = d[d.placement == place]
            if len(s):
                lines.append(f"| {method} | {place} | {len(s)} | {s.abs_error_m.mean():.3f} | {s.error_m.mean():+.3f} |")
        on = d[d.placement != "off_object"]
        o_lo, o_hi = boot_ci(on.abs_error_m.to_numpy(), rng)
        lines.append(f"| {method} | **all on object** | {len(on)} | {on.abs_error_m.mean():.3f} "
                     f"(95 % CI {o_lo:.3f}–{o_hi:.3f}) | {on.error_m.mean():+.3f} |")
    lines.append("")

    # LiDAR by class, on-object frames.
    lines += ["LiDAR by class, boxes on the photographed object only:", "",
              "| class | n | MAE (m) | bias (m) | frames over-estimated |", "|---|---|---|---|---|"]
    lon = lidar[lidar.placement != "off_object"]
    for cls, s in lon.groupby("class"):
        lines.append(f"| {cls} | {len(s)} | {s.abs_error_m.mean():.3f} | {s.error_m.mean():+.3f} | "
                     f"{(s.error_m > 0).sum()} of {len(s)} |")
    lines.append("")

    # 3. Monocular structure.
    t, p = mono.truth_m.to_numpy(), mono.pred_m.to_numpy()
    slope, intercept = np.polyfit(t, p, 1)
    r = float(np.corrcoef(t, p)[0, 1])
    rec = loo_recalibrated_abs_error(t, p)
    r_lo, r_hi = boot_ci(rec, rng)
    lines += ["## 3. Monocular error structure", "",
              f"- Over-estimates in **{(mono.error_m > 0).sum()} of {len(mono)}** frames.",
              f"- Straight-line fit: estimate = {slope:.3f} × truth + {intercept:.3f} m; Pearson r = {r:.3f}.",
              f"- Ratio estimate/truth: median {np.median(p / t):.2f}, range {np.min(p / t):.2f}–{np.max(p / t):.2f}.",
              f"- Leave-one-out linear recalibration (exploratory, post hoc — needs this camera's tape-measured "
              f"truth to fit): MAE {rec.mean():.3f} m (95 % CI {r_lo:.3f}–{r_hi:.3f}), "
              f"MAPE {np.mean(rec / t) * 100:.1f} %.", ""]

    # 4. LiDAR error against range.
    door = lidar[(lidar["class"] == "door")]
    lines += ["## 4. Does LiDAR error fall with range?", "",
              f"- Spearman rank correlation of absolute error with distance, all {len(lidar)} LiDAR frames: "
              f"{spearman(lidar.truth_m.to_numpy(), lidar.abs_error_m.to_numpy()):+.2f}.",
              f"- Doors only ({len(door)} frames, one class at every distance): "
              f"{spearman(door.truth_m.to_numpy(), door.abs_error_m.to_numpy()):+.2f}.", "",
              "| bin (m) | classes in the bin (n) | MAE (m) | door MAE (m) |", "|---|---|---|---|"]
    for bin_m, s in lidar.groupby("distance_bin_m"):
        mix = ", ".join(f"{c} {n}" for c, n in s["class"].value_counts().sort_index().items())
        ds = s[s["class"] == "door"]
        door_mae = f"{ds.abs_error_m.mean():.3f}" if len(ds) else "—"
        lines.append(f"| {bin_m:.1f} | {mix} | {s.abs_error_m.mean():.3f} | {door_mae} |")
    lines.append("")

    OUT_MD.write_text("\n".join(lines) + "\n")
    figure(detector)
    print(f"wrote {OUT_MD.relative_to(ROOT)} and {OUT_FIG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
