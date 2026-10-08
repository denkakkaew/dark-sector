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
    "mars_alien_drone": 3.6,
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

    def node(name, glb, xf=None, props="", head_extra=""):
        rid = res(glb)
        extra = "\ntransform = %s" % xf if xf else ""
        lines.append('[node name="%s" parent="."%s instance=ExtResource("%d")]%s\n%s' % (name, head_extra, rid, extra, props))

    node("Terrain", "moon_terrain")
    node("Rocks", "moon_rocks")
    node("Pipes", "moon_pipes")
    for name, glb, x, z, yaw, size in L.BUILDINGS:
        node(name, glb, transform(x, 0.0, z, yaw, size / EXPORTED[glb]))
    for name, x, z, yaw, lander in L.PADS:
        node(name, "moon_pad", transform(x, 0.0, z, yaw))
        node(lander, "moon_alien_lander", transform(x, 0.3, z, yaw + 25.0, L.LANDER_SIZE / EXPORTED["moon_alien_lander"]))
    # The ground crew. Each works its own post with its own rhythm (the seed), and
    # keeps its feet on the terrain as it walks: the ground out here rolls, so
    # `ground` points at it (the `node_paths` entry is what makes that export
    # resolve — without it the path is stored and the export silently stays null).
    for i, (x, z, yaw, size) in enumerate(L.DRONES):
        props = ('script = ExtResource("WORKER")\nroam_radius = %g\nwalk_speed = %g\nseed_value = %d\n'
                 'bounce = %g\nground = NodePath("../Terrain")\n'
                 % (L.DRONE_ROAM_RADIUS, L.DRONE_WALK_SPEED, 211 + i * 17, L.DRONE_BOUNCE))
        node("Drone%d" % (i + 1), "mars_alien_drone", transform(x, 0.0, z, yaw, size / EXPORTED["mars_alien_drone"]),
             props, ' node_paths=PackedStringArray("ground")')

    worker_id = len(resources) + 1
    head = ["[gd_scene load_steps=%d format=3]\n" % (len(resources) + 2),
            "; Written by blender/make_moon_set_scene.py from blender/moon_layout.py — move",
            "; things in the layout, or by hand here (a re-run rewrites this file).",
            "; The Moon's alien forward base, ground and horizon, in front of the sky plate",
            "; SceneLook hangs far behind it. Everything stays beyond the alien spawn ring",
            "; or below the flight lanes, so no ship flies through a building. The drones",
            "; are Mars' model and script (scripts/Worker.gd), working the landers and tanks.\n"]
    for name, rid in resources.items():
        # The drone is Mars' model — one species of worker for both alien sites —
        # so the folder comes from the name's prefix.
        folder = name.split("_")[0]
        head.append('[ext_resource type="PackedScene" path="res://assets/object/%s/%s.glb" id="%d"]' % (folder, name, rid))
    head.append('[ext_resource type="Script" path="res://scripts/Worker.gd" id="%d"]' % worker_id)
    head.append('\n[node name="MoonSet" type="Node3D"]\n')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        text = "\n".join(head) + "\n" + "\n".join(lines)
        f.write(text.replace('ExtResource("WORKER")', 'ExtResource("%d")' % worker_id))
    print("wrote", OUT, len(lines), "nodes")


if __name__ == "__main__":
    main()
