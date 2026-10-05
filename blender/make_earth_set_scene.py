"""
Dark Sector — write `scenes/sets/EarthSet.tscn` from `earth_layout.py`.

Plain Python, like the other `make_*_set_scene.py`: it only places the .glb files
that `build_earth_set.py` and `export_rebuild.py` wrote. Everything hangs under a
`City` node, which `SET_Y` metres below the deck is what makes this a view looking
down on a city. A re-run rewrites the scene, so the lasting place to move a
landmark is `earth_layout.py`.

    python blender/make_earth_set_scene.py
"""

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "scenes", "sets", "EarthSet.tscn")
NL = "\n"


def _layout():
    spec = importlib.util.spec_from_file_location("earth_layout", os.path.join(HERE, "earth_layout.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


L = _layout()

# Reference size each generated landmark was exported at (export_rebuild.py).
EXPORTED = {
    "earth_tower_artdeco": 205.0,
    "earth_tower_neon": 225.0,
    "earth_tower_pixel": 275.0,
    "earth_building_midrise_a": 85.0,
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

    def node(name, glb, xf=None):
        rid = resources.setdefault(glb, len(resources) + 1)
        text = '[node name="%s" parent="City" instance=ExtResource("%d")]' % (name, rid) + NL
        if xf:
            text += "transform = %s" % xf + NL
        nodes.append(text)

    node("Ground", "earth_ground")
    node("Buildings", "earth_city")
    node("River", "earth_river")
    node("Roads", "earth_roads")
    bx, bz, (ax, az) = L.bridge_axis()
    # The bridge is modelled with its deck along X; turn that onto the river's cross direction.
    node("Bridge", "earth_bridge", transform(bx, 0.0, bz, math.degrees(math.atan2(-az, ax))))
    for name, glb, x, z, yaw, size in L.LANDMARKS:
        node(name, glb, transform(x, 0.0, z, yaw, size / EXPORTED[glb]))

    head = [
        "[gd_scene load_steps=%d format=3]" % (len(resources) + 1) + NL,
        "; Written by blender/make_earth_set_scene.py from blender/earth_layout.py - move",
        "; things in the layout, or by hand here (a re-run rewrites this file).",
        "; A night city seen from above: the street grid, ~2,500 lit buildings, a river,",
        "; elevated light-trail roads, a golden cable-stayed bridge and a few landmark",
        "; towers. Hung SET_Y below the deck, so the camera looks down on it." + NL,
    ]
    for glb, rid in resources.items():
        head.append('[ext_resource type="PackedScene" path="res://assets/object/earth/%s.glb" id="%d"]' % (glb, rid))
    head.append(NL + '[node name="EarthSet" type="Node3D"]' + NL)
    head.append('[node name="City" type="Node3D" parent="."]')
    head.append("transform = %s" % transform(0.0, L.SET_Y, 0.0) + NL)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(NL.join(head) + NL + NL.join(nodes))
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    main()
