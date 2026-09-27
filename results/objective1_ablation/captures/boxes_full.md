# Objective 2 — detector box coverage over the capture set

Weights: `data/processed/ablation/weights/full.pt` (conf 0.3, imgsz 640)  
Frames: 102 — 65 with a box, 37 with no detection

| capture class | expected class hit | other class | no detection | detected as |
|---|---|---|---|---|
| chair | 7 | 5 | 7 | chair ×7, wall ×3, door ×2 |
| door | 19 | 0 | 0 | door ×19 |
| low_obstacle | 0 | 10 | 12 | door ×10 |
| pole | 0 | 10 | 12 | door ×10 |
| table_edge | 0 | 14 | 6 | wall ×10, chair ×4 |

`other class` rows carry a real detector box but of a class other than the one
photographed — they are kept and flagged rather than dropped, so they can be
excluded from the headline numbers if that is the honest call. `no detection`
frames are absent from the CSV entirely; distance_eval.py falls back to a
centred ROI for them and marks `roi_source=centred_roi_fallback`.

Frames with no detection:

- `obj-chair_d-1000_light-bright_rep-1.jpg` (chair)
- `obj-chair_d-1000_light-bright_rep-2.jpg` (chair)
- `obj-chair_d-1000_light-bright_rep-3.jpg` (chair)
- `obj-chair_d-1500_light-bright_rep-1.jpg` (chair)
- `obj-chair_d-1500_light-bright_rep-2.jpg` (chair)
- `obj-chair_d-4000_light-bright_rep-2.jpg` (chair)
- `obj-chair_d-500_light-bright_rep-2.jpg` (chair)
- `obj-low_obstacle_d-1000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-3.jpg` (low_obstacle)
- `obj-low_obstacle_d-2500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2500_light-bright_rep-3.jpg` (low_obstacle)
- `obj-low_obstacle_d-4500_light-bright_rep-1.jpg` (low_obstacle)
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
- `obj-pole_d-3000_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-3000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-2.jpg` (pole)
- `obj-table_edge_d-2000_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-2000_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-2500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-2500_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-500_light-bright_rep-2.jpg` (table_edge)
