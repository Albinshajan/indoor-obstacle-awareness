# Decision-layer verification — `tools/verify_decision_layer.sh`

Run 2026-09-16 on macOS (Darwin 25.5.0), Swift 6.1.2.

These checks exercise the three pure decision-layer sources
(`ObstacleDecision.swift`, `ObstacleTracker.swift`, `DepthSampler.swift`)
against planted values. They verify **arithmetic and geometry, not device
behaviour** — latency and the feedback channels are measured on the phone.

```

A. Letterbox padding is undone exactly
  ok    round trip (0.3, 0.4, 0.4, 0.2)
  ok    round trip (0.0, 0.0, 1.0, 1.0)
  ok    round trip (0.05, 0.7, 0.15, 0.25)
  ok    full canvas maps wider than the frame

B. Portrait/landscape rotation maps corners correctly
  ok    portrait top-left -> landscape bottom-left
  ok    portrait top-right -> landscape top-left
  ok    portrait bottom-right -> landscape top-right
  ok    portrait bottom-left -> landscape bottom-right
  ok    four rotations are the identity

C. Lower third of a box
  ok    takes the bottom third, not the top
  ok    lower third sits inside the box

D. Depth sampler recovers a planted distance
  ok    recovers the planted 2.50 m
  ok    without the confidence filter the garbage wins
  ok    skipping the rotation reads the wrong region
  ok    off-frame ROI returns nil

E. Urgency function
  ok    proximity saturates at the near bound
  ok    proximity is zero at the far bound
  ok    proximity is monotonic
  ok    stairs at 0.5 m, stationary, reaches the top band
  ok    a chair at 0.5 m is also top band (low-hazard class, high-hazard situation)
  ok    hazard class still orders two obstacles at equal distance
  ok    approaching scores above stationary
  ok    receding scores the same as stationary
  ok    beyond the range bound and stationary scores nothing
  ok    urgency stays inside 0...1 under extreme input
  ok    an unknown class falls back rather than vanishing

F. Bearing zones
  ok    left third
  ok    centre third
  ok    right third
  ok    pan follows bearing

G. Tracker: gate, closing rate and hysteresis
  ok    one frame is not confirmed
  ok    two frames are not confirmed
  ok    three frames confirm the track
  ok    the track keeps one identity across frames
  ok    closing rate recovers 1.0 m/s approaching
  ok    time to contact follows distance / rate
  ok    a single dropped frame keeps the track alive
  ok    a track is retired after sustained misses
  ok    rises to the top band
  ok    holds the top band inside the fall margin
  ok    drops once the score falls clear of the margin
  ok    two non-overlapping chairs are two tracks
  ok    they get different bearings
  ok    IoU of disjoint boxes is zero
  ok    IoU of an identical box is one

45/45 checks passed
decision layer verified
```
