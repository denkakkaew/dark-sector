"""
Dark Sector — read the hand-tuned fleet back out of `temp/alien_fleet_adjust.blend`.

`make_fleet_adjust.py` builds that file; the person tuning it selects each ship's
Empty and rotates/scales it. This reads every Empty's world rotation and scale and
prints them, plus the ship's resulting bounds against the shared hit box, as JSON.

    "<blender>/blender.exe" --background temp/alien_fleet_adjust.blend \
        --python blender/read_fleet_adjust.py
"""

import json
import math

import bpy
from mathutils import Vector

NAMES = ("alien_ship", "alien_ship_2", "alien_ship_3")
HITBOX = Vector((1.93, 1.87, 1.15))  # Blender x, y (depth), z (height)


def _bounds(handle):
    pts = []
    for o in handle.children_recursive:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def read():
    out = {}
    for name in NAMES:
        h = bpy.data.objects.get(name)
        if h is None:
            out[name] = None
            continue
        h.rotation_mode = "XYZ"
        mw = h.matrix_world
        loc, rot, scl = mw.decompose()
        e = rot.to_euler("XYZ")
        lo, hi = _bounds(h)
        out[name] = {
            "scale": [round(v, 4) for v in scl],
            "rotation_deg": [round(math.degrees(a), 2) for a in e],
            "size_xyz": [round(v, 3) for v in (hi - lo)],
            "bounds_min": [round(v, 3) for v in lo],
            "bounds_max": [round(v, 3) for v in hi],
            "centre_offset": [round(v, 3) for v in ((lo + hi) / 2 - loc)],
            "fits_hitbox": all((hi - lo)[i] <= HITBOX[i] + 1e-3 for i in range(3)),
            "location": [round(v, 3) for v in loc],
            "parent_children": [c.name for c in h.children],
        }
    # What else moved: anything with a changed transform among the ship children.
    for name in NAMES:
        h = bpy.data.objects.get(name)
        if h:
            for c in h.children_recursive:
                loc, rot, scl = c.matrix_local.decompose()
                out.setdefault("child_local", {})[c.name] = {
                    "loc": [round(v, 3) for v in loc],
                    "rot_deg": [round(math.degrees(a), 2) for a in rot.to_euler()],
                    "scale": [round(v, 4) for v in scl],
                }
    print("FLEET " + json.dumps(out))


if __name__ == "__main__":
    read()
