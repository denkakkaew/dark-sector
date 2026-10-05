"""
Dark Sector — write `scenes/sets/MoonSet.tscn` from `moon_layout.py`.

Plain Python (no Blender): it only places the .glb files that `build_moon_set.py`
and `export_rebuild.py` wrote. The output is an ordinary scene — open it in the
editor and nudge a building by hand if you like — but a re-run rewrites it, so
the lasting place to move something is `moon_layout.py`.

    python blender/make_moon_set_scene.py
"""

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "scenes", "sets", "MoonSet.tscn")


def _layout():
    spec = importlib.util.spec_from_file_location("moon_layout", os.path.join(HERE, "moon_layout.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


L = _layout()

# Reference size each generated model was exported at (export_rebuild.py).
EXPORTED = {
    "moon_alien_dome_geodesic": 20.0,
    "moon_alien_dome_shell": 12.0,
    "moon_alien_spire": 36.0,
    "moon_alien_tanks": 10.0,
    "moon_alien_lander": 6.5,
}


def transform(x, y, z, yaw_deg=0.0, scale=1.0):
    """Godot's text form lists the basis axes, then the origin."""
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    axes = [(c * scale, 0.0, -s * scale), (0.0, scale, 0.0), (s * scale, 0.0, c * scale)]
    nums = [v for axis in axes for v in axis] + [x, y, z]
    return "Transform3D(%s)" % ", ".join(("%.4f" % v).rstrip("0").rstrip(".") or "0" for v in nums)


def main():
    resources = {}  # name -> id

    def res(name):
        if name not in resources:
            resources[name] = len(resources) + 1
        return resources[name]

    lines = []

    def node(name, glb, xf=None):
        rid = res(glb)
        extra = "\ntransform = %s" % xf if xf else ""
        lines.append('[node name="%s" parent="." instance=ExtResource("%d")]%s\n' % (name, rid, extra))

    node("Terrain", "moon_terrain")
    node("Rocks", "moon_rocks")
    node("Pipes", "moon_pipes")
    for name, glb, x, z, yaw, size in L.BUILDINGS:
        node(name, glb, transform(x, 0.0, z, yaw, size / EXPORTED[glb]))
    for name, x, z, yaw, lander in L.PADS:
        node(name, "moon_pad", transform(x, 0.0, z, yaw))
        node(lander, "moon_alien_lander", transform(x, 0.3, z, yaw + 25.0, L.LANDER_SIZE / EXPORTED["moon_alien_lander"]))

    head = ["[gd_scene load_steps=%d format=3]\n" % (len(resources) + 1),
            "; Written by blender/make_moon_set_scene.py from blender/moon_layout.py — move",
            "; things in the layout, or by hand here (a re-run rewrites this file).",
            "; The Moon's alien forward base, ground and horizon, in front of the sky plate",
            "; SceneLook hangs far behind it. Everything stays beyond the alien spawn ring",
            "; or below the flight lanes, so no ship flies through a building.\n"]
    for name, rid in resources.items():
        sub = "moon" if name.startswith("moon_") else "moon"
        head.append('[ext_resource type="PackedScene" path="res://assets/object/moon/%s.glb" id="%d"]' % (name, rid))
    head.append('\n[node name="MoonSet" type="Node3D"]\n')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head) + "\n" + "\n".join(lines))
    print("wrote", OUT, len(lines), "nodes")


if __name__ == "__main__":
    main()
