"""
Dark Sector — write `scenes/sets/MarsSet.tscn` from `mars_layout.py`.

Plain Python, like `make_moon_set_scene.py`: it only places the .glb files that
`build_mars_set.py` and `export_rebuild.py` wrote. A re-run rewrites the scene, so
the lasting place to move a building is `mars_layout.py`.

    python blender/make_mars_set_scene.py
"""

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "scenes", "sets", "MarsSet.tscn")
NL = "\n"


def _layout():
    spec = importlib.util.spec_from_file_location("mars_layout", os.path.join(HERE, "mars_layout.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


L = _layout()

# Reference size each generated model was exported at (export_rebuild.py); the
# scene scales each instance to its layout size from this.
EXPORTED = {
    "mars_colony_dome": 22.0,
    "mars_colony_tower2": 26.0,
    "mars_hab_pod": 8.5,
    "mars_hab_pod2": 7.5,
    "mars_radar_dish": 11.0,
    "mars_cargo_crawler": 13.0,
    "mars_rover": 5.5,
    "mars_drill_rig": 32.0,
    "mars_mining_crane": 22.0,
    "mars_ore_pile": 6.5,
    "mars_alien_drone": 3.6,
    "mars_solar_panel": 6.0,
}


def transform(x, y, z, yaw_deg=0.0, scale=1.0):
    """Godot's text form lists the basis axes, then the origin."""
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    axes = [(c * scale, 0.0, -s * scale), (0.0, scale, 0.0), (s * scale, 0.0, c * scale)]
    nums = [v for axis in axes for v in axis] + [x, y, z]
    return "Transform3D(%s)" % ", ".join(("%.4f" % v).rstrip("0").rstrip(".") or "0" for v in nums)


def main():
    resources = {}
    nodes = []

    uses_worker = False

    def node(name, glb, xf, extra=""):
        rid = resources.setdefault(glb, len(resources) + 1)
        nodes.append('[node name="%s" parent="." instance=ExtResource("%d")]' % (name, rid) + NL + "transform = %s" % xf + NL + extra)

    # Terrain first, so it draws as the floor of everything.
    for name, glb in (("Ground", "mars_ground"), ("Ledges", "mars_ledges"), ("Rocks", "mars_rocks")):
        rid = resources.setdefault(glb, len(resources) + 1)
        nodes.append('[node name="%s" parent="." instance=ExtResource("%d")]' % (name, rid) + NL)
    for name, glb, x, z, yaw, size in L.BUILDINGS:
        node(name, glb, transform(x, 0.0, z, yaw, size / EXPORTED[glb]))
    for i, (x, z, yaw, size) in enumerate(L.DRONES):
        # Each drone works its own post, with its own rhythm (the seed).
        uses_worker = True
        extra = ('script = ExtResource("WORKER")' + NL + "roam_radius = %g" % L.DRONE_ROAM_RADIUS + NL
                 + "walk_speed = %g" % L.DRONE_WALK_SPEED + NL + "seed_value = %d" % (101 + i * 17) + NL)
        node("Drone%d" % (i + 1), "mars_alien_drone", transform(x, 0.0, z, yaw, size / EXPORTED["mars_alien_drone"]), extra)
    for i, (x, z, yaw) in enumerate(L.SOLAR):
        node("Solar%d" % (i + 1), "mars_solar_panel", transform(x, 0.0, z, yaw, L.SOLAR_SIZE / EXPORTED["mars_solar_panel"]))

    worker_id = len(resources) + 1
    head = [
        "[gd_scene load_steps=%d format=3]" % (len(resources) + 1 + int(uses_worker)) + NL,
        "; Written by blender/make_mars_set_scene.py from blender/mars_layout.py - move",
        "; things in the layout, or by hand here (a re-run rewrites this file).",
        "; Mars: the friendly colony, the alien-run drilling rig and its drones, flat-topped",
        "; mesas on the horizon and sandstone ledges in the corners, in front of the sky",
        "; plate. Everything tall is beyond the alien spawn ring." + NL,
    ]
    for glb, rid in resources.items():
        head.append('[ext_resource type="PackedScene" path="res://assets/object/mars/%s.glb" id="%d"]' % (glb, rid))
    if uses_worker:
        head.append('[ext_resource type="Script" path="res://scripts/Worker.gd" id="%d"]' % worker_id)
    head.append(NL + '[node name="MarsSet" type="Node3D"]' + NL)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        text = NL.join(head) + NL + NL.join(nodes)
        f.write(text.replace('ExtResource("WORKER")', 'ExtResource("%d")' % worker_id))
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    main()
