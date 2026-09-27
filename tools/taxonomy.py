"""Canonical 12-class indoor-obstacle taxonomy shared by prepare_data.py and distance_eval.py.

COCO has no door/stairs/pole/glass class, which is exactly why Objective 1
fine-tunes rather than runs zero-shot (see CLAUDE.md section 5).
"""

CANONICAL_CLASSES = [
    "person",
    "chair",
    "table",
    "door",
    "door_glass",
    "window",
    "stairs",
    "pole",
    "handrail",
    "wall",
    "low_obstacle",
    "other",
]

CLASS_TO_ID = {name: i for i, name in enumerate(CANONICAL_CLASSES)}
ID_TO_CLASS = {i: name for name, i in CLASS_TO_ID.items()}

# The five classes covered by the researcher's own tape-measured capture set
# (CLAUDE.md section 5, "Own capture protocol") -- must match the capture
# app's ObstacleClass enum (ios/ObstacleAwareness/Sources/Capture/CaptureMetadata.swift)
# exactly, since these strings are parsed straight out of filenames.
# distance_eval.py only ever sees these.
CAPTURE_CLASSES = ["door", "chair", "table_edge", "pole", "low_obstacle"]

# Fixed hazard weights for the urgency score (CLAUDE.md section 7). Kept here
# so the derived-feature layer and any evaluation code share one source
# instead of drifting apart.
HAZARD_WEIGHT = {
    "stairs": 1.0,
    "door_glass": 0.9,
    "pole": 0.8,
    "door": 0.7,
    "low_obstacle": 0.6,
    "handrail": 0.4,
    "wall": 0.4,
    "table": 0.3,
    "chair": 0.3,
    "window": 0.3,
    "person": 0.2,
    "other": 0.1,
}

# Raw class-name -> canonical class-name mapping, one dict per source.
#
# SEEDED FROM THE PROPOSAL'S SOURCE DESCRIPTIONS, NOT FROM THE ACTUAL
# data.yaml FILES -- Roboflow/AI Builders exports need account credentials
# this environment doesn't have, so these were never inspected directly.
# Verify every raw key against the real downloaded data.yaml before running
# `prepare_data.py merge`, and correct any name that doesn't match
# (prepare_data.py logs and drops any raw class it can't map, it does not
# fail silently).
#
# roboflow_lochan VERIFIED against the real export (2026-09-07,
# lochan-r-ugnn4/indoor-objects-detection-h2mgz v1): the actual 10 classes
# are Bed, Chair, Couch, Door, Person, Stairs, Table, Toy, Wardrobe, Window
# -- not the guessed Wall/Pole/Handrail/Other above. Four don't have an
# obvious canonical match and are a judgment call, not a verified fact --
# reconsider before citing this mapping in Chapter 3:
#   Bed, Couch, Toy   -> low_obstacle (floor-level obstacles/trip hazards)
#   Wardrobe          -> wall (tall furniture that blocks passage like a wall segment)
SOURCE_CLASS_MAPS = {
    "roboflow_lochan": {
        "Door": "door",
        "Stairs": "stairs",
        "Person": "person",
        "Chair": "chair",
        "Table": "table",
        "Window": "window",
        "Bed": "low_obstacle",
        "Couch": "low_obstacle",
        "Toy": "low_obstacle",
        "Wardrobe": "wall",
    },
    # VERIFIED 2026-09-21 against the real data.yaml (Kaggle
    # thepbordin/indoor-object-detection, GPL-3.0): the 10 classes are door,
    # cabinetDoor, refrigeratorDoor, window, chair, table, cabinet, couch,
    # openedDoor, pole -- not the door-glass / door-wood / door-metal / person
    # guessed from the proposal. There is no glass-door or handrail class, so
    # this source adds `pole` (44 boxes) but not `door_glass` or `handrail`.
    # Judgment calls, following roboflow_lochan's precedents:
    #   openedDoor              -> door (an open door is still a doorway)
    #   couch                   -> low_obstacle (as Roboflow's Couch)
    #   cabinet                 -> wall (as Roboflow's Wardrobe: tall, built-in,
    #                              blocks passage like a wall segment)
    #   cabinetDoor, refrigeratorDoor -> DROPPED, deliberately unmapped: mapping
    #                              them to `door` would teach a cabinet front as a
    #                              doorway, the wrong hazard. prepare_data.py logs
    #                              and drops unmapped classes.
    "ai_builders_jaiinsom": {
        "door": "door",
        "openedDoor": "door",
        "window": "window",
        "chair": "chair",
        "table": "table",
        "couch": "low_obstacle",
        "cabinet": "wall",
        "pole": "pole",
    },
    "coco": {
        "person": "person",
        "chair": "chair",
        "dining table": "table",
    },
}

# Capture-class -> acceptable detector class names, most-preferred first.
#
# The own-capture class names are not all detector class names. Two mismatches
# are deliberate:
#   table_edge -> table   the capture protocol photographs the *edge* of a
#                         table, which the detector only knows as `table`
#   pole       -> wall    the merged corpus has ZERO `pole` instances (the AI
#                         Builders source was never obtainable), so the
#                         detector can never emit one -- see
#                         results/dataset_report.md. Pole frames are shot
#                         against wall segments/pillars so the trained `wall`
#                         class fires instead. `pole` is kept as the first
#                         preference so this map stays correct if that source
#                         is ever added.
#
# predict_boxes.py uses this to decide which detection is the intended object.
CAPTURE_CLASS_TO_DETECTOR = {
    "door": ["door", "door_glass"],
    "chair": ["chair"],
    "table_edge": ["table"],
    "pole": ["pole", "wall"],
    "low_obstacle": ["low_obstacle"],
}
