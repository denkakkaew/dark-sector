"""
Dark Sector — where everything on the Moon goes. Godot metres, x right, z toward
the player (so the base is at negative z), y up with the deck's bottom at 0.

Plain data, no Blender: `build_moon_set.py` reads it to keep rocks off the
buildings and to run the pipes between them, and `make_moon_set_scene.py` reads
it to write `scenes/sets/MoonSet.tscn`. Move a building here and both follow.

Reference: `assets/backdrop/moon_surface.png` — the alien base sits right of centre
on the horizon, a landing pad with its craft in front of it to the left, big
mounds on the left of the horizon, boulders at the bottom corners.

Layout rules
------------
* Everything with height stays **beyond the alien spawn ring** (aliens appear up
  to ~36 m out and fly to the turret), so a ship never flies through a building:
  the base is 55-90 m out. The only things nearer are low boulders at the screen
  corners, clear of the flight corridor.
* The turret stands on the deck at (0, 0, 7.5); the ground is flat for 16 m
  around it, because the deck sits on y=0.
"""

import math

TURRET_Z = 7.5

# The horizon ridge: where it peaks, how wide the band is, and its height (a
# floor plus a peak scaled by ridged noise). Tuned so the tallest peaks stand
# about a tenth of the screen above the horizon, like the painting.
RIDGE_Z = -235.0
RIDGE_WIDTH = 40.0
RIDGE_BASE = 6.0
RIDGE_PEAK = 20.0

PIPE_HEIGHT = 0.9
PIPE_RADIUS = 0.65
PAD_RADIUS = 5.5

# name, glb, x, z, yaw (deg, 0 = faces the player), size (metres: the longest
# side of the generated model, which is its width for a dome and its height for
# a spire).
BUILDINGS = [
    ("DomeA", "moon_alien_dome_geodesic", 17.0, -66.0, 10.0, 20.0),
    ("DomeB", "moon_alien_dome_geodesic", 38.0, -78.0, -15.0, 15.0),
    ("ShellA", "moon_alien_dome_shell", 26.0, -58.0, 20.0, 12.0),
    ("ShellB", "moon_alien_dome_shell", 43.0, -64.0, -25.0, 10.0),
    ("ShellC", "moon_alien_dome_shell", 5.0, -80.0, 30.0, 11.0),
    ("SpireA", "moon_alien_spire", 29.0, -78.0, 0.0, 36.0),
    ("SpireB", "moon_alien_spire", 48.0, -86.0, 0.0, 28.0),
    ("TanksA", "moon_alien_tanks", 9.0, -70.0, 80.0, 10.0),
    ("TanksB", "moon_alien_tanks", 37.0, -69.0, 100.0, 9.0),
]

# Landing pads, each with a lander parked on it.
PADS = [
    ("PadA", 3.0, -54.0, 15.0, "LanderA"),
    ("PadB", -16.0, -66.0, -20.0, "LanderB"),
]
LANDER_SIZE = 6.5

# Tubes between the buildings, as (x, z) end pairs.
PIPES = [
    ((17.0, -66.0), (26.0, -58.0)),
    ((26.0, -58.0), (43.0, -64.0)),
    ((17.0, -66.0), (9.0, -70.0)),
    ((29.0, -78.0), (38.0, -78.0)),
    ((38.0, -78.0), (37.0, -69.0)),
    ((26.0, -58.0), (3.0, -54.0)),
    ((9.0, -70.0), (5.0, -80.0)),
]


def hand_placed_rocks():
    """(x, z, radius, big) — the boulders that frame the shot, bottom corners and
    the middle distance, like the painting's."""
    return [
        (-9.8, 2.0, 1.45, True),
        (-12.8, -3.0, 0.95, True),
        (10.5, 2.6, 1.15, True),
        (13.0, -2.0, 0.8, False),
        (-24.0, -14.0, 2.0, True),
        (28.0, -18.0, 1.7, True),
        (-45.0, -40.0, 3.0, True),
        (52.0, -42.0, 2.4, True),
    ]


def blocked(x, z, margin=0.0):
    """True where a random rock must not go: the deck, the flight corridor and
    the buildings and pads."""
    # The deck and its apron.
    if math.hypot(x, z - TURRET_Z) < 9.0 + margin:
        return True
    # The corridor ships fly down to the turret.
    if abs(x) < 8.0 + margin and z > -40.0:
        return True
    for _, _, bx, bz, _, size in BUILDINGS:
        if math.hypot(x - bx, z - bz) < size * 0.65 + margin:
            return True
    for _, px, pz, _, _ in PADS:
        if math.hypot(x - px, z - pz) < PAD_RADIUS * 1.5 + margin:
            return True
    return False
