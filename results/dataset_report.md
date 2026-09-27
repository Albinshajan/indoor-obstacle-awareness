# Dataset report

Generated from `data/processed/merged` (6460 images).

## Images per split

- test_zeroshot: 3068
- train: 2714
- val: 678

## Per-class instance counts

| class | train | val | test_zeroshot | other | total | flag |
|---|---|---|---|---|---|---|
| person | 1248 | 367 | 11004 | 0 | 12619 |  |
| chair | 1069 | 368 | 1791 | 0 | 3228 |  |
| table | 777 | 329 | 697 | 0 | 1803 |  |
| door | 410 | 113 | 0 | 0 | 523 |  |
| window | 3756 | 747 | 0 | 0 | 4503 |  |
| stairs | 398 | 83 | 0 | 0 | 481 |  |
| wall | 355 | 84 | 0 | 0 | 439 |  |
| low_obstacle | 1903 | 344 | 0 | 0 | 2247 |  |

Zero instances so far: door_glass, pole, handrail, other

## Image size distribution

- width: min=200 max=640 mean=491 median=416
- height: min=145 max=640 mean=448 median=416
- most common (w,h): [((416, 416), 3392), ((640, 480), 629), ((640, 427), 375), ((480, 640), 182), ((640, 426), 145)]

## Box-area distribution (fraction of image area)

- min=0.0000 max=1.0000 mean=0.1084 median=0.0209
- p10=0.0010 p90=0.3466

### Median box-area by class

| class | n_boxes | median_area_frac |
|---|---|---|
| person | 12619 | 0.0165 |
| chair | 3228 | 0.0198 |
| table | 1803 | 0.0774 |
| door | 523 | 0.0925 |
| window | 4503 | 0.0051 |
| stairs | 481 | 0.1861 |
| wall | 439 | 0.6472 |
| low_obstacle | 2247 | 0.1261 |

