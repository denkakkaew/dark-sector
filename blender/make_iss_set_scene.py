"""
Dark Sector — write `scenes/sets/ISSSet.tscn` from `iss_layout.py`.

Plain Python, like `make_moon_set_scene.py`: it only places the .glb that
`export_rebuild.py` wrote, and attaches `scripts/Drift.gd` to anything the layout
says moves. A re-run rewrites the scene, so the lasting place to move or retime
the module is `iss_layout.py`.

    python blender/make_iss_set_scene.py
"""

import importlib.util
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "scenes", "sets", "ISSSet.tscn")

NL = "\n"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


L = _load("iss_layout")


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def transform(x, y, z, yaw, pitch, roll, scale):
    """Roll about Z, then pitch about X, then yaw about Y; Godot's text form lists
    the basis axes (columns) and then the origin."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    m = _mul(ry, _mul(rx, rz))
    axes = [(m[0][c] * scale, m[1][c] * scale, m[2][c] * scale) for c in range(3)]
    nums = [v for axis in axes for v in axis] + [x, y, z]
    return "Transform3D(%s)" % ", ".join(("%.4f" % v).rstrip("0").rstrip(".") or "0" for v in nums)


def main():
    resources = {}
    nodes = []
    uses_drift = False
    for name, glb, x, y, z, yaw, pitch, roll, size in L.PARTS:
        rid = resources.setdefault(glb, len(resources) + 1)
        xf = transform(x, y, z, yaw, pitch, roll, size / L.EXPORTED[glb])
        node = '[node name="%s" parent="." instance=ExtResource("%d")]' % (name, rid) + NL
        node += "transform = %s" % xf + NL
        if name in L.DRIFT:
            speed, wrap_from, wrap_to = L.DRIFT[name]
            uses_drift = True
            node += 'script = ExtResource("DRIFT")' + NL
            node += "velocity = Vector3(%g, 0, 0)" % speed + NL
            node += "wrap_from = %g" % wrap_from + NL
            node += "wrap_to = %g" % wrap_to + NL
        nodes.append(node)

    drift_id = len(resources) + 1
    head = [
        "[gd_scene load_steps=%d format=3]" % (len(resources) + 1 + int(uses_drift)) + NL,
        "; Written by blender/make_iss_set_scene.py from blender/iss_layout.py - move",
        "; parts in the layout, or by hand here (a re-run rewrites this file).",
        "; A station module drifting slowly across, below the turret and over the",
        "; painted Earth limb. It stays under the alien flight lanes." + NL,
    ]
    for glb, rid in resources.items():
        head.append('[ext_resource type="PackedScene" path="res://assets/object/iss/%s.glb" id="%d"]' % (glb, rid))
    if uses_drift:
        head.append('[ext_resource type="Script" path="res://scripts/Drift.gd" id="%d"]' % drift_id)
    head.append(NL + '[node name="ISSSet" type="Node3D"]' + NL)

    text = NL.join(head) + NL + NL.join(nodes)
    text = text.replace('ExtResource("DRIFT")', 'ExtResource("%d")' % drift_id)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", OUT, len(nodes), "nodes")


if __name__ == "__main__":
    main()
