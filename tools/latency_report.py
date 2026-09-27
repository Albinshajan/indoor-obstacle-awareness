#!/usr/bin/env python3
"""Objective 1: latency table + throttling plot from LatencyLogger.swift CSVs.

    python latency_report.py --csv-dir device_logs/ --output out/
    python latency_report.py --csv-dir device_logs/ --output out/ --threshold-ms 150

--threshold-ms is optional and deliberately not defaulted: CLAUDE.md section
9 notes the proposal treats latency as safety-critical without ever citing a
"fast enough for a walking user" figure, so Objective 1 currently has no
pass/fail criterion. Pass one in once that number is sourced from the
literature; until then this script only reports the distribution, it does
not invent a threshold to grade it against.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

STAGE_COLUMNS = ["capture_ms", "preprocess_ms", "detect_ms", "depthSample_ms", "feedback_ms", "total_ms"]
PHASE_ORDER = ["cold", "warm", "sustained"]


def load_all(csv_dir: Path) -> pd.DataFrame:
    paths = sorted(csv_dir.glob("latency_*.csv"))
    if not paths:
        raise SystemExit(f"no latency_*.csv files found in {csv_dir}")
    frames = []
    for path in paths:
        df = pd.read_csv(path)
        df["source_file"] = path.name
        frames.append(df)
    combined = pd.concat(frames, ignore_index=True)
    combined["session_phase"] = pd.Categorical(combined["session_phase"], categories=PHASE_ORDER, ordered=True)
    return combined


def p95(series: pd.Series) -> float:
    return float(np.percentile(series, 95))


def build_table(df: pd.DataFrame, threshold_ms: float | None) -> pd.DataFrame:
    agg = {col: ["mean", "median", p95, "count"] for col in STAGE_COLUMNS}
    table = df.groupby(["model", "feedback_mode", "session_phase"], observed=True).agg(agg)
    table.columns = ["_".join(c) if isinstance(c, tuple) else c for c in table.columns]
    table = table.rename(columns=lambda c: c.replace("p95", "p95")).reset_index()

    if threshold_ms is not None:
        pass_rate = (
            df.assign(meets=df["total_ms"] <= threshold_ms)
            .groupby(["model", "feedback_mode", "session_phase"], observed=True)["meets"]
            .mean()
            .rename("pass_rate_at_threshold")
            .reset_index()
        )
        table = table.merge(pass_rate, on=["model", "feedback_mode", "session_phase"])

    return table


def plot_throttling(df: pd.DataFrame, output_path: Path, threshold_ms: float | None, rolling_window: int = 30):
    models = sorted(df["model"].unique())
    fig, axes = plt.subplots(len(models), 1, figsize=(9, 3 * len(models)), sharex=True, squeeze=False)

    for ax, model in zip(axes[:, 0], models):
        sub = df[df["model"] == model].sort_values("session_elapsed_s")
        ax.scatter(sub["session_elapsed_s"], sub["total_ms"], s=4, alpha=0.25, label="per-frame total_ms")
        rolling = sub["total_ms"].rolling(rolling_window, min_periods=1).mean()
        ax.plot(sub["session_elapsed_s"], rolling, color="black", linewidth=1.5, label=f"rolling mean ({rolling_window} frames)")
        if threshold_ms is not None:
            ax.axhline(threshold_ms, color="red", linestyle="--", linewidth=1, label=f"threshold ({threshold_ms:.0f} ms)")
        for phase_start, label in [(60, "cold→warm"), (300, "warm→sustained")]:
            ax.axvline(phase_start, color="grey", linestyle=":", linewidth=1)
        ax.set_title(model)
        ax.set_ylabel("total latency (ms)")
        ax.legend(fontsize=7, loc="upper left")

    axes[-1, 0].set_xlabel("session elapsed (s)")
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--csv-dir", required=True, help="directory of latency_*.csv files pulled off the phone")
    p.add_argument("--output", required=True)
    p.add_argument("--threshold-ms", type=float, default=None)
    args = p.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    df = load_all(Path(args.csv_dir))
    table = build_table(df, args.threshold_ms)

    table_path = output_dir / "latency_table.csv"
    table.to_csv(table_path, index=False)

    plot_path = output_dir / "throttling.png"
    plot_throttling(df, plot_path, args.threshold_ms)

    print(f"{len(df)} frames across {df['model'].nunique()} model(s) -> {table_path}, {plot_path}")
    if args.threshold_ms is None:
        print("no --threshold-ms given: table reports raw latency distribution only, no pass/fail column")


if __name__ == "__main__":
    main()
