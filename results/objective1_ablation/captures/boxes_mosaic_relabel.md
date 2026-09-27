# Objective 2 — detector box coverage over the capture set

Weights: `data/processed/ablation/weights/mosaic_relabel.pt` (conf 0.3, imgsz 640)  
Frames: 102 — 31 with a box, 71 with no detection

| capture class | expected class hit | other class | no detection | detected as |
|---|---|---|---|---|
| chair | 11 | 3 | 5 | chair ×11, window ×1, door ×1, stairs ×1 |
| door | 1 | 9 | 9 | wall ×9, door ×1 |
| low_obstacle | 0 | 1 | 21 | person ×1 |
| pole | 0 | 1 | 21 | stairs ×1 |
| table_edge | 0 | 5 | 15 | chair ×3, low_obstacle ×2 |

`other class` rows carry a real detector box but of a class other than the one
photographed — they are kept and flagged rather than dropped, so they can be
excluded from the headline numbers if that is the honest call. `no detection`
frames are absent from the CSV entirely; distance_eval.py falls back to a
centred ROI for them and marks `roi_source=centred_roi_fallback`.

Frames with no detection:

- `obj-chair_d-1000_light-bright_rep-3.jpg` (chair)
- `obj-chair_d-3000_light-bright_rep-1.jpg` (chair)
- `obj-chair_d-4000_light-bright_rep-2.jpg` (chair)
- `obj-chair_d-4500_light-bright_rep-2.jpg` (chair)
- `obj-chair_d-500_light-bright_rep-2.jpg` (chair)
- `obj-door_d-1000_light-bright_rep-1.jpg` (door)
- `obj-door_d-1000_light-bright_rep-2.jpg` (door)
- `obj-door_d-1500_light-bright_rep-1.jpg` (door)
- `obj-door_d-1500_light-bright_rep-2.jpg` (door)
- `obj-door_d-2000_light-bright_rep-2.jpg` (door)
- `obj-door_d-4000_light-bright_rep-2.jpg` (door)
- `obj-door_d-4500_light-bright_rep-2.jpg` (door)
- `obj-door_d-500_light-bright_rep-1.jpg` (door)
- `obj-door_d-500_light-bright_rep-2.jpg` (door)
- `obj-low_obstacle_d-1000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-1500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2000_light-bright_rep-3.jpg` (low_obstacle)
- `obj-low_obstacle_d-2500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-2500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-2500_light-bright_rep-3.jpg` (low_obstacle)
- `obj-low_obstacle_d-3000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-3000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-3500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-3500_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-4000_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-4000_light-bright_rep-2.jpg` (low_obstacle)
- `obj-low_obstacle_d-4000_light-bright_rep-3.jpg` (low_obstacle)
- `obj-low_obstacle_d-4000_light-bright_rep-4.jpg` (low_obstacle)
- `obj-low_obstacle_d-4500_light-bright_rep-1.jpg` (low_obstacle)
- `obj-low_obstacle_d-4500_light-bright_rep-2.jpg` (low_obstacle)
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
- `obj-pole_d-3500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-3500_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4000_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4000_light-bright_rep-3.jpg` (pole)
- `obj-pole_d-4000_light-bright_rep-4.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-2.jpg` (pole)
- `obj-pole_d-4500_light-bright_rep-3.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-1.jpg` (pole)
- `obj-pole_d-500_light-bright_rep-2.jpg` (pole)
- `obj-table_edge_d-1500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-2000_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-2000_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-2500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-2500_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-3000_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-3000_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-3500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-3500_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-4000_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-4000_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-4000_light-bright_rep-3.jpg` (table_edge)
- `obj-table_edge_d-4500_light-bright_rep-1.jpg` (table_edge)
- `obj-table_edge_d-4500_light-bright_rep-2.jpg` (table_edge)
- `obj-table_edge_d-4500_light-bright_rep-3.jpg` (table_edge)
