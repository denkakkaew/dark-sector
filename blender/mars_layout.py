"""
Dark Sector — where everything on Mars goes. Godot metres, x right, z toward the
player (so the colony is at negative z), y up with the deck's bottom at 0.

Plain data, no Blender: `build_mars_set.py` reads it to keep rocks off the
buildings, and `make_mars_set_scene.py` reads it to write
`scenes/sets/MarsSet.tscn`. Move a building here and both follow.

Reference: `assets/backdrop/mars_surface.png` — the friendly colony left of centre
(a blue-glass dome, a ring-decked tower, pods, a radar dish, solar panels, rovers),
the alien-run drilling rig right of centre with a crane and spindly drones working
it, flat-topped mesas on the horizon, and big layered sandstone ledges in the two
bottom corners, all under an orange haze.

Layout rules (as for the Moon)
------------------------------
* Everything with height stays **beyond the alien spawn ring** (ships appear up to
  ~36 m out), so a ship never flies through a building: the colony and the rig
  are 50-90 m out. The only nearer things are low sandstone ledges in the screen
  corners and scattered boulders, outside the ship corridor (|x| < 8). Ships do
  cross those, so they *climb over* them: MarsSet.tscn tags the ground, ledges
  and rocks `flight_obstacle`, and scripts/FlightFloor.gd measures them.
* The ground is flat for 18 m round the turret and gentle across the whole spawn
  zone, so no ship spawns inside a dune.
"""

import math

TURRET_Z = 7.5

# Far hills: a low band, since the painting's horizon is mesas and haze, not mountains.
HILLS_Z = -245.0
HILLS_WIDTH = 45.0
HILLS_HEIGHT = 9.0

# Flat-topped mesas: (x, z, radius, height).
MESAS = [
    (-105.0, -205.0, 48.0, 26.0),
    (-195.0, -238.0, 72.0, 36.0),
    (98.0, -200.0, 56.0, 32.0),
    (178.0, -236.0, 62.0, 26.0),
    (8.0, -262.0, 42.0, 17.0),
]

# name, glb, x, z, yaw (deg, 0 = faces the player), size (metres: the longest side
# of the generated model — the width of a dome, the height of a tower).
BUILDINGS = [
    # The colony.
    ("Dome", "mars_colony_dome", -22.0, -66.0, 0.0, 22.0),
    ("Tower", "mars_colony_tower2", -36.0, -73.0, 0.0, 26.0),
    ("PodA", "mars_hab_pod", -8.0, -60.0, 15.0, 8.5),
    ("PodB", "mars_hab_pod2", -46.0, -63.0, -20.0, 7.5),
    ("PodC", "mars_hab_pod", -3.0, -76.0, 35.0, 8.0),
    ("PodD", "mars_hab_pod2", -31.0, -58.0, 5.0, 6.5),
    ("Radar", "mars_radar_dish", -68.0, -65.0, 25.0, 11.0),
    ("Crawler", "mars_cargo_crawler", -26.0, -53.0, 80.0, 13.0),
    ("RoverA", "mars_rover", -13.0, -52.0, 35.0, 5.5),
    ("RoverB", "mars_rover", -56.0, -54.0, -40.0, 5.0),
    # The alien-run rig.
    ("Rig", "mars_drill_rig", 40.0, -76.0, 0.0, 32.0),
    ("Crane", "mars_mining_crane", 58.0, -70.0, -25.0, 22.0),
    ("OreA", "mars_ore_pile", 26.0, -64.0, 20.0, 6.5),
    ("OreB", "mars_ore_pile", 51.0, -60.0, -30.0, 5.5),
]

# The workers around the rig: (x, z, yaw, size). Standing, facing about the rig.
DRONES = [
    (33.0, -63.0, 160.0, 3.6),
    (38.0, -60.0, 200.0, 3.4),
    (45.0, -62.0, 150.0, 3.6),
    (50.0, -66.0, 230.0, 3.3),
    (30.0, -69.0, 120.0, 3.5),
    (55.0, -61.0, 180.0, 3.4),
]

# How the drones move (scripts/Worker.gd): they wander this far from their post,
# at this speed, and stop to work in between.
DRONE_ROAM_RADIUS = 3.2
DRONE_WALK_SPEED = 0.9

# Solar panels on stands: (x, z, yaw).
SOLAR = [
    (-48.0, -72.0, 15.0),
    (-42.0, -78.0, 20.0),
    (-12.0, -68.0, -10.0),
    (-6.0, -66.0, -5.0),
    (-58.0, -76.0, 30.0),
]
SOLAR_SIZE = 6.0


def hand_placed_ledges():
    """(x, z, radius, height) — the layered sandstone slabs that frame the bottom
    corners, like the painting's, and a few in the middle distance."""
    return [
        (-15.5, -1.5, 3.4, 1.7),
        (-21.0, -7.5, 3.0, 1.6),
        (-12.5, 4.5, 2.2, 0.6),
        (17.5, -2.0, 3.2, 1.6),
        (23.0, -8.5, 2.8, 1.5),
        (14.5, 5.0, 2.0, 0.55),
        (-34.0, -22.0, 5.0, 3.0),
        (36.0, -26.0, 5.5, 3.2),
        (-62.0, -40.0, 7.0, 4.2),
        (66.0, -44.0, 7.5, 4.5),
    ]


def blocked(x, z, margin=0.0):
    """True where a random rock must not go: the deck, the ship corridor and the
    buildings."""
    if math.hypot(x, z - TURRET_Z) < 9.0 + margin:
        return True
    if abs(x) < 8.0 + margin and z > -40.0:
        return True
    for _, _, bx, bz, _, size in BUILDINGS:
        if math.hypot(x - bx, z - bz) < size * 0.6 + margin:
            return True
    for sx, sz, _ in SOLAR:
        if math.hypot(x - sx, z - sz) < 5.0 + margin:
            return True
    return False
