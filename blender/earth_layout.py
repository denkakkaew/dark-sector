"""
Dark Sector — where everything in the Earth scene goes: a night city seen from
above. Godot metres, x right, z toward the player (so the city is at negative z),
y up. The whole set is built with its ground at y=0 and hung `SET_Y` below the
deck (see below), so every height here is height above the street.

Plain data, no Blender: `build_earth_set.py` reads it (the river, the roads, where
buildings may not go) and `make_earth_set_scene.py` reads it to write
`scenes/sets/EarthSet.tscn`.

Reference: `assets/backdrop/earth_city.png` — an aerial night view: a dense city of
lit windows running to a hazy horizon, a river curving in from the lower right, a
golden cable-stayed bridge across it, golden light trails on the roads along the
banks, and a few landmark towers with lit crowns standing above the skyline.

Why the city is a long way below
--------------------------------
The painting looks *down* on the city from altitude; the camera here is on a deck
4 m up. So the street is `SET_Y` metres below the deck and the skyline rises toward
the camera's horizon, exactly as the painting's does, with the tall towers
reaching above it. Nothing in the set is in the alien flight zone: ships fly
between y=0.3 and y=6, and the tallest landmark's crown is still 400 m out.

The city runs a long way — to about 1.5 km — because the horizon is where the
painting's skyline sits; beyond a few hundred metres it is only lights, which the
ground's own street-light texture and the haze take over from.
"""

import math

SET_Y = -120.0

# The river's centre line, (x, z), from the near right bank out to the horizon.
RIVER = [
    (320.0, -95.0),
    (200.0, -150.0),
    (85.0, -230.0),
    (-20.0, -320.0),
    (-110.0, -440.0),
    (-135.0, -600.0),
    (-65.0, -800.0),
    (80.0, -1050.0),
    (210.0, -1400.0),
]
RIVER_WIDTH = 62.0
RIVER_WIDTH_FAR = 110.0  # wider with distance, so it still reads at the horizon

# Elevated roads run along both banks, this far from the centre line, at this height.
BANK_ROAD_OFFSET = 62.0
ROAD_HEIGHT = 25.0
ROAD_WIDTH = 7.0

# The bridge: where it crosses (a point on the river), its length across, deck
# height, and the pylon.
BRIDGE_AT = (85.0, -230.0)
BRIDGE_LENGTH = 190.0
BRIDGE_DECK_HEIGHT = 27.0

# name, glb, x, z, yaw (deg), size (metres: the longest side of the generated model,
# which is its height for a tower).
LANDMARKS = [
    ("ArtDeco", "earth_tower_artdeco", -250.0, -470.0, 20.0, 205.0),
    ("Neon", "earth_tower_neon", 150.0, -520.0, -10.0, 225.0),
    ("Pixel", "earth_tower_pixel", 470.0, -400.0, 0.0, 275.0),
    ("MidriseA1", "earth_building_midrise_a", -120.0, -250.0, 5.0, 85.0),
    ("MidriseA3", "earth_building_midrise_a", 20.0, -300.0, -8.0, 105.0),
    ("MidriseA2", "earth_building_midrise_a", 260.0, -300.0, 12.0, 80.0),
    ("MidriseA4", "earth_building_midrise_a", -330.0, -330.0, -20.0, 95.0),
]

# Where the generated filler buildings cluster tallest (a downtown), and how far the
# city extends. (x, z, radius) and the far limit.
DOWNTOWN = (-60.0, -420.0, 380.0)
CITY_FAR = -1500.0


def river_points(n=160):
    """Points along the river's centre line, smoothed (Catmull-Rom through RIVER),
    each as (x, z, half_width)."""
    pts = RIVER
    out = []
    segs = len(pts) - 1
    for s in range(segs):
        p0 = pts[max(s - 1, 0)]
        p1, p2 = pts[s], pts[s + 1]
        p3 = pts[min(s + 2, segs)]
        for k in range(n // segs):
            t = k / (n // segs)
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            z = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append([x, z])
    out.append(list(pts[-1]))
    res = []
    for x, z in out:
        far = min(1.0, max(0.0, (-z - 95.0) / 1100.0))
        res.append((x, z, 0.5 * (RIVER_WIDTH + (RIVER_WIDTH_FAR - RIVER_WIDTH) * far)))
    return res


def _seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def river_distance(x, z, points=None):
    """Distance from (x, z) to the river's centre line, and the half-width there."""
    pts = points or river_points()
    best, hw = 1e9, 0.0
    for (ax, az, aw), (bx, bz, bw) in zip(pts, pts[1:]):
        d = _seg_dist(x, z, ax, az, bx, bz)
        if d < best:
            best, hw = d, 0.5 * (aw + bw)
    return best, hw


def bridge_axis():
    """(centre x, centre z, unit direction across the river) for the bridge."""
    pts = river_points()
    cx, cz = BRIDGE_AT
    best = min(range(len(pts) - 1), key=lambda i: _seg_dist(cx, cz, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]))
    fx, fz = pts[best + 1][0] - pts[best][0], pts[best + 1][1] - pts[best][1]
    n = math.hypot(fx, fz)
    # across = perpendicular to the flow
    return cx, cz, (fz / n, -fx / n)


def blocked(x, z, margin=0.0, points=None):
    """True where a filler building must not stand: on the river or its bank roads,
    near the bridge, or on a landmark."""
    d, hw = river_distance(x, z, points)
    if d < hw + 14.0 + margin:  # the water and its embankment
        return True
    if abs(d - (hw + BANK_ROAD_OFFSET - 14.0)) < 22.0 + margin and d > hw:
        # the elevated bank roads run here
        return True
    bx, bz, (ax, az) = bridge_axis()
    # along the bridge's approach roads (the deck line, extended)
    rel_x, rel_z = x - bx, z - bz
    along = rel_x * ax + rel_z * az
    off = abs(rel_x * (-az) + rel_z * ax)
    if abs(along) < BRIDGE_LENGTH * 0.5 + 220.0 and off < 24.0 + margin:
        return True
    for _, _, lx, lz, _, size in LANDMARKS:
        if math.hypot(x - lx, z - lz) < 38.0 + margin + size * 0.06:
            return True
    return False
