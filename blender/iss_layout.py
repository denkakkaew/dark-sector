"""
Dark Sector — the one station part in the ISS scene: a module drifting past.

Godot metres, x right, z toward the player (so the station is at negative z), y up.
Plain data, read by `make_iss_set_scene.py`. The ISS scene keeps its painted Earth
limb as the backdrop — a 3D globe cannot match that painting's sharpness across a
limb that fills half the screen — and `look.photo.distance` pushes it far back so a
real module can pass in front of it.

The module slides slowly left to right, below the turret and over the planet: low
enough (its top is below y=0) to stay under the lanes aliens fly in (y 0.3-6), far
enough out (z=-30) to be seen across the whole width of the screen, and beyond the
deck's far rim so the ring never hides it. It wraps back to the left once it has
crossed; a battle lasts a minute, so that is rarely seen.
"""

# name, glb, x, y, z, yaw, pitch, roll (degrees), size (metres, the longest side).
PARTS = [
    ("Module", "iss_module", -75.0, -5.0, -30.0, 0.0, 0.0, 0.0, 18.0),
]

# name -> (speed in m/s along +x, x it re-enters at, x it has to pass to wrap).
# 2 m/s crosses the visible width in about a minute.
DRIFT = {
    "Module": (2.0, -80.0, 80.0),
}

# Reference size each model is exported at (export_rebuild.py), so the scene can
# scale each instance to the size above.
EXPORTED = {
    "iss_module": 22.0,
}
