#!/usr/bin/env bash
# Compiles Objective 3's pure decision-layer sources for macOS, together with
# tools/decision_layer_checks/main.swift, and runs the checks. The UI, Core Haptics,
# AVAudioEngine and ARKit files are deliberately excluded -- they need a device,
# and everything they depend on for correctness is in the three files below.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=ios/ObstacleAwareness/Sources/Assist
OUT="${TMPDIR:-/tmp}/verify_decision_layer"
swiftc -O -o "$OUT" \
  "$SRC/ObstacleDecision.swift" \
  "$SRC/ObstacleTracker.swift" \
  "$SRC/DepthSampler.swift" \
  tools/decision_layer_checks/main.swift
exec "$OUT"
