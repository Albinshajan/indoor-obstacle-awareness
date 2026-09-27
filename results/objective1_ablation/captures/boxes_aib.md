# Objective 2 — detector box coverage over the capture set

Weights: `data/processed/ablation/weights/aib.pt` (conf 0.3, imgsz 640)  
Frames: 102 — 69 with a box, 33 with no detection

| capture class | expected class hit | other class | no detection | detected as |
|---|---|---|---|---|
| chair | 14 | 5 | 0 | chair ×14, wall ×5 |
| door | 19 | 0 | 0 | door ×19 |
| low_obstacle | 0 | 9 | 13 | wall ×9 |
| pole | 4 | 0 | 18 | wall ×4 |
| table_edge | 0 | 18 | 2 | wall ×15, chair ×3 |

`other class` rows carry a real detector box but of a class other than the one
photographed — they are kept and flagged rather than dropped, so they can be
excluded from the headline numbers if that is the honest call. `no detection`
frames are absent from the CSV entirely; distance_eval.py falls back to a
centred ROI for them and marks `roi_source=centred_roi_fallback`.

Frames with no detection:

- `obj-low_obstacle_d-1000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-3000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-3500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-3500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-4500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-4500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-pole_d-1000_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-1000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-1000_light-bright_rep-3.jpg` (pole)
- `obj-pole_d-1500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-1500_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-2000_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-2000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-2500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-2500_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-3000_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-3000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4000_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-4000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-3.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-2.jpg` (pole)
- `obj-table_edge_d-4500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-4500_light-bright_rep-2.jpg` (table_edge)
