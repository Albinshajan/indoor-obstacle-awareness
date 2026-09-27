#!/bin/bash
# Score ablation variants on every evaluation set the ablation uses, in one go:
#
#   results/objective1_ablation/                 validation split (original labels)
#   results/objective1_ablation/aib_test/        AI Builders test split (unseen source,
#                                                except for variants trained on AIB)
#   results/objective1_ablation/val_completed/   validation with teacher-completed
#                                                person/chair/table labels (secondary)
#   results/objective1_ablation/captures/        the 102 tape-measured captures, via
#                                                predict_boxes.py at the app's 0.30
#
# Bash, not zsh, on purpose: the --weights list is an array, and an unquoted
# string of flags is passed as ONE argument by zsh -- which is how three
# scoring runs failed silently on 2026-09-22.
#
# Usage:  bash tools/score_ablation.sh baseline mosaic relabel coco aib mosaic_relabel full
set -euo pipefail
cd "$(dirname "$0")/.."

W=data/processed/ablation/weights
LOGS=data/processed/ablation/score_logs
mkdir -p "$LOGS" results/objective1_ablation/captures

WEIGHTS=(--weights colab_run2=data/raw/finetuned_weights/yolo26n.pt)
for v in "$@"; do
  [ -f "$W/$v.pt" ] || { echo "missing $W/$v.pt" >&2; exit 1; }
  WEIGHTS+=(--weights "$v=$W/$v.pt")
done

run() {  # name, then detection_metrics.py arguments
  local name=$1; shift
  if .venv/bin/python tools/detection_metrics.py "$@" "${WEIGHTS[@]}" > "$LOGS/$name.log" 2>&1; then
    echo "$name: ok"
  else
    echo "$name: FAILED -- see $LOGS/$name.log" >&2; tail -5 "$LOGS/$name.log" >&2; exit 1
  fi
}

run val            --output results/objective1_ablation
run aib_test       --output results/objective1_ablation/aib_test \
                   --eval-list data/processed/ablation/lists/aib_test.txt --labels data/processed/aib/labels
run val_completed  --output results/objective1_ablation/val_completed \
                   --eval-list data/processed/ablation/lists/val_completed.txt --labels data/processed/relabel_val/labels

for v in colab_run2 "$@"; do
  weights=$W/$v.pt; [ "$v" = colab_run2 ] && weights=data/raw/finetuned_weights/yolo26n.pt
  out=results/objective1_ablation/captures/boxes_$v.csv
  [ -f "$out" ] && [ "$out" -nt "$weights" ] && continue
  .venv/bin/python tools/predict_boxes.py --capture-dir data/raw/own_capture --output "$out" \
    --weights "$weights" --conf 0.30 > "$LOGS/captures_$v.log" 2>&1 \
    || { echo "captures $v: FAILED -- see $LOGS/captures_$v.log" >&2; exit 1; }
done
echo "captures: ok"
