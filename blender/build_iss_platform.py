"""
Dark Sector — build the ISS platform the turret is bolted to (campaign scene 1).

Scene 1 of the campaign is first contact at the ISS, so the player should read
as standing on the station's hull with aliens closing in on it. This builds that
surface procedurally and writes it to:

    assets/object/iss/iss_platform.glb

Unlike the turret, this is authored rather than sculpted, so it is built
straight in game units with the deck's walking surface on Z=0 and the turret's
mount at the origin — drop the .glb in at the same spot as the Turret node and
the two line up with no offset.

What's in it, roughly from the player outwards: a panelled central walkway with
handrails, a pressurised module either side wrapped in gold MLI foil, a lattice
truss across the far end carrying four solar array wings, radiator panels, and
scattered greebles (hatches, crates, an antenna). The far end of the walkway
just stops, so there is a hard silhouette against space.

Everything is emitted into a single bmesh with per-face material indices, so the
whole platform is one object with ~9 surfaces — no joins, no operator context to
fight, and a handful of draw calls. There are no textures: flat materials only,
which keeps it comfortably inside GL-Compatibility's budget.

How to run
----------
Blender Scripting tab -> open this file -> Run Script, or from an MCP session:

    exec(open("blender/build_iss_platform.py").read())
    build()                 # (re)builds the ISSPlatform collection
    export()                # writes the .glb

`build()` clears and rebuilds its own collection each time, so it is safe to run
repeatedly and never touches the Turret / TurretBase collections.
"""

import bpy
import bmesh
import math
import os

from mathutils import Euler, Matrix, Vector

COLLECTION = "ISSPlatform"
OUT_DIR = os.path.join("assets", "object", "iss")
OUT_FILE = "iss_platform.glb"

# Deck runs from the player's feet (-Y, toward camera) out to +Y (toward the
# aliens). glTF's Y-up conversion turns +Y into Godot's -Z, which is the
# direction the turret fires, so the platform recedes away from the camera.
DECK_HALF_WIDTH = 5.0
DECK_NEAR = -7.0
DECK_FAR = 20.0
DECK_THICK = 0.5

MODULE_X = 7.2
MODULE_R = 2.4
MODULE_Z = -2.0

# Aliens cross this end of the platform at roughly Z 1.2-2.5 on their way in, so
# the truss is kept low enough to pass under them and the tall pieces (arrays,
# radiators, masts) are pushed outboard of the centre lane they converge into.
TRUSS_Y = 16.5
TRUSS_Z = 0.15
TRUSS_HEIGHT = 0.95
TRUSS_HALF = 16.0

# The deck plates alternate between `hull` and `plate`, which are deliberately
# close together: any real contrast between them turns the walkway into a
# chessboard that pulls the eye off the turret and the incoming aliens.
PALETTE = [
    ("hull", (0.64, 0.65, 0.66), 0.0),
    ("plate", (0.55, 0.57, 0.60), 0.0),
    ("hull_dark", (0.16, 0.18, 0.22), 0.0),
    ("trim", (0.42, 0.44, 0.48), 0.0),
    ("foil", (0.72, 0.55, 0.16), 0.0),      # gold MLI insulation blanket
    ("solar", (0.07, 0.09, 0.18), 0.0),     # array cells, near-black blue
    ("rail", (0.80, 0.62, 0.12), 0.0),
    ("radiator", (0.88, 0.89, 0.90), 0.0),
    ("glow_cyan", (0.15, 0.70, 0.90), 2.2),
    ("glow_amber", (1.00, 0.60, 0.10), 2.0),
]
MAT = {name: i for i, (name, _, _) in enumerate(PALETTE)}


# --- primitive emitters -----------------------------------------------------


class Builder:
    def __init__(self):
        self.bm = bmesh.new()

    def _tag(self, before, mat):
        self.bm.faces.ensure_lookup_table()
        for f in self.bm.faces[before:]:
            f.material_index = mat

    def box(self, size, loc, mat, rot=(0.0, 0.0, 0.0)):
        m = Matrix.LocRotScale(Vector(loc), Euler(rot), Vector(size))
        before = len(self.bm.faces)
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._tag(before, mat)

    def tube(self, radius, length, loc, mat, rot=(0.0, 0.0, 0.0), segments=16, caps=True):
        m = Matrix.LocRotScale(Vector(loc), Euler(rot), Vector((1.0, 1.0, 1.0)))
        before = len(self.bm.faces)
        bmesh.ops.create_cone(
            self.bm, cap_ends=caps, cap_tris=False, segments=segments,
            radius1=radius, radius2=radius, depth=length, matrix=m,
        )
        self._tag(before, mat)

    def rail(self, x, y0, y1, z, mat):
        """A handrail: one long bar on short posts, the ISS's most-photographed detail."""
        self.tube(0.055, y1 - y0, (x, (y0 + y1) * 0.5, z + 0.42), mat,
                  rot=(math.pi / 2, 0, 0), segments=8)
        n = max(2, int((y1 - y0) / 3.0))
        for i in range(n + 1):
            y = y0 + (y1 - y0) * i / float(n)
            self.tube(0.05, 0.42, (x, y, z + 0.21), mat, segments=6)


# --- the platform -----------------------------------------------------------


def _deck(b):
    mid_y = (DECK_NEAR + DECK_FAR) * 0.5
    length = DECK_FAR - DECK_NEAR

    # Structural slab, then raised hull plates so the surface isn't a bare sheet.
    b.box((DECK_HALF_WIDTH * 2, length, DECK_THICK),
          (0, mid_y, -DECK_THICK * 0.5), MAT["trim"])

    cols, rows = 4, 9
    pw = (DECK_HALF_WIDTH * 2 - 0.5) / cols
    ph = (length - 0.5) / rows
    for c in range(cols):
        for r in range(rows):
            x = -DECK_HALF_WIDTH + 0.25 + pw * (c + 0.5)
            y = DECK_NEAR + 0.25 + ph * (r + 0.5)
            shade = "hull" if (c + r) % 2 == 0 else "plate"
            b.box((pw - 0.18, ph - 0.18, 0.08), (x, y, 0.0), MAT[shade])

    # Edge lips, and a strip light down each side of the walkway.
    for s in (-1, 1):
        b.box((0.35, length, 0.34), (s * DECK_HALF_WIDTH, mid_y, 0.02), MAT["trim"])
        b.box((0.10, length - 2.0, 0.06), (s * (DECK_HALF_WIDTH - 0.32), mid_y, 0.14),
              MAT["glow_cyan"])

    # Blunt end cap, so the far edge reads as a real edge against space.
    b.box((DECK_HALF_WIDTH * 2 + 0.7, 0.5, 0.7), (0, DECK_FAR, -0.1), MAT["trim"])


def _modules(b):
    length = 25.0
    mid_y = 5.5
    for s in (-1, 1):
        x = s * MODULE_X
        b.tube(MODULE_R, length, (x, mid_y, MODULE_Z), MAT["foil"], rot=(math.pi / 2, 0, 0))
        # Structural ribs along the hull.
        n = 7
        for i in range(n):
            y = mid_y - length * 0.5 + length * (i + 0.5) / n
            b.tube(MODULE_R + 0.12, 0.3, (x, y, MODULE_Z), MAT["trim"],
                   rot=(math.pi / 2, 0, 0))
        # A porthole strip and a docking node on the outboard side.
        for i in range(4):
            y = mid_y - 6.0 + i * 3.6
            b.tube(0.34, 0.2, (x + s * MODULE_R * 0.92, y, MODULE_Z + 0.9),
                   MAT["glow_cyan"], rot=(0, math.pi / 2, 0), segments=10)
        b.tube(1.15, 1.0, (x, mid_y - length * 0.5 - 0.4, MODULE_Z), MAT["hull"],
               rot=(math.pi / 2, 0, 0), segments=12)


def _truss(b):
    span = TRUSS_HALF * 2
    for dy in (-0.35, 0.35):
        for dz in (0.0, TRUSS_HEIGHT):
            b.box((span, 0.2, 0.2), (0, TRUSS_Y + dy, TRUSS_Z + dz), MAT["trim"])
    # Lattice diagonals across the face nearest the player.
    step = 1.7
    n = int(span / step)
    for i in range(n):
        x = -TRUSS_HALF + step * (i + 0.5)
        lean = math.atan2(TRUSS_HEIGHT, step) * (1 if i % 2 == 0 else -1)
        b.box((0.12, 0.12, math.hypot(TRUSS_HEIGHT, step)),
              (x, TRUSS_Y - 0.35, TRUSS_Z + TRUSS_HEIGHT * 0.5), MAT["trim"],
              rot=(0, lean, 0))
    # Vertical posts where the arrays hang off.
    for x in (-TRUSS_HALF + 1.0, -6.0, 6.0, TRUSS_HALF - 1.0):
        b.box((0.25, 0.5, TRUSS_HEIGHT), (x, TRUSS_Y, TRUSS_Z + TRUSS_HEIGHT * 0.5),
              MAT["trim"])


def _solar_arrays(b):
    """Four wings on the truss ends, tilted to catch the light and read as panels."""
    tilt = math.radians(-32.0)
    for s in (-1, 1):
        for i, cx in enumerate((11.0, 17.5)):
            x = s * cx
            y = TRUSS_Y + 0.4
            z = TRUSS_Z + 1.45
            b.box((5.8, 5.4, 0.08), (x, y, z), MAT["solar"], rot=(tilt, 0, 0))
            # Frame and the spine the blanket rolls out from.
            b.box((6.0, 0.18, 0.22), (x, y - 2.62 * math.cos(tilt), z - 2.62 * math.sin(tilt)),
                  MAT["trim"], rot=(tilt, 0, 0))
            b.box((6.0, 0.18, 0.22), (x, y + 2.62 * math.cos(tilt), z + 2.62 * math.sin(tilt)),
                  MAT["trim"], rot=(tilt, 0, 0))
            b.box((0.22, 5.4, 0.22), (x, y, z), MAT["trim"], rot=(tilt, 0, 0))
            if i == 0:
                b.box((0.3, 0.3, 1.5), (x, TRUSS_Y, TRUSS_Z + 0.7), MAT["trim"])


def _radiators(b):
    for s in (-1, 1):
        b.box((4.2, 3.4, 0.1), (s * 7.4, DECK_FAR - 1.5, 1.5), MAT["radiator"],
              rot=(math.radians(28.0), 0, 0))
        b.box((0.24, 0.24, 1.4), (s * 7.4, DECK_FAR - 1.5, 0.75), MAT["trim"])


def _greebles(b):
    # Hatches set into the walkway.
    for y in (-3.5, 4.0, 12.5):
        b.tube(0.85, 0.16, (0, y, 0.06), MAT["hull_dark"], segments=12)
        b.tube(0.62, 0.2, (0, y, 0.09), MAT["trim"], segments=12)

    # Equipment crates and stowage, kept off the firing line.
    crates = [
        (-3.4, -4.5, (1.5, 1.2, 0.9)), (3.5, -2.0, (1.2, 1.6, 0.7)),
        (-3.6, 7.5, (1.3, 1.3, 1.1)), (3.4, 10.5, (1.6, 1.2, 0.8)),
        (-3.3, 14.5, (1.1, 1.5, 0.6)),
    ]
    for x, y, size in crates:
        b.box(size, (x, y, size[2] * 0.5), MAT["hull"])
        b.box((size[0] * 0.7, size[1] * 0.7, 0.06), (x, y, size[2] + 0.02), MAT["glow_amber"])

    # Antenna dish and a couple of masts, outboard so they stay off the firing line.
    b.tube(0.12, 2.6, (-6.6, 17.5, 1.3), MAT["trim"], segments=8)
    b.tube(1.25, 0.25, (-6.6, 17.5, 2.7), MAT["hull"], rot=(math.radians(-40), 0, 0), segments=14)
    b.tube(0.12, 3.2, (6.6, 18.5, 1.6), MAT["trim"], segments=8)
    b.box((0.5, 0.5, 0.5), (6.6, 18.5, 3.3), MAT["glow_amber"])

    for s in (-1, 1):
        b.rail(s * (DECK_HALF_WIDTH - 0.55), DECK_NEAR + 1.5, DECK_FAR - 1.0, 0.05,
               MAT["rail"])


# --- assembly ---------------------------------------------------------------


def _materials():
    mats = []
    for name, rgb, emit in PALETTE:
        key = "iss_" + name
        mat = bpy.data.materials.get(key) or bpy.data.materials.new(key)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.65
            if "Metallic" in bsdf.inputs:
                bsdf.inputs["Metallic"].default_value = 0.35 if name in ("foil", "trim") else 0.0
            if emit and "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
                bsdf.inputs["Emission Strength"].default_value = emit
        mats.append(mat)
    return mats


def build():
    """(Re)build the ISSPlatform collection. Safe to call repeatedly."""
    old = bpy.data.collections.get(COLLECTION)
    if old:
        for ob in list(old.objects):
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)
        bpy.data.collections.remove(old)

    b = Builder()
    _deck(b)
    _modules(b)
    _truss(b)
    _solar_arrays(b)
    _radiators(b)
    _greebles(b)

    me = bpy.data.meshes.new("ISSPlatform")
    b.bm.to_mesh(me)
    b.bm.free()
    for mat in _materials():
        me.materials.append(mat)
    me.shade_flat()

    coll = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(coll)
    ob = bpy.data.objects.new("ISSPlatform", me)
    coll.objects.link(ob)
    return {"object": ob.name, "tris": len(me.loop_triangles) or sum(
        max(0, len(p.vertices) - 2) for p in me.polygons), "materials": len(me.materials)}


def _project_root():
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
    if here and os.path.isdir(os.path.join(os.path.dirname(here), "assets")):
        return os.path.dirname(here)
    return os.path.abspath(os.getcwd())


def export(out_dir=None):
    ob = bpy.data.objects.get("ISSPlatform")
    if ob is None:
        raise RuntimeError("nothing to export — run build() first")

    root = out_dir or os.path.join(_project_root(), OUT_DIR)
    os.makedirs(root, exist_ok=True)
    path = os.path.join(root, OUT_FILE)

    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="NONE",
        export_animations=False,
        export_extras=False,
    )
    lo = [min(v.co[i] for v in ob.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in ob.data.vertices) for i in range(3)]
    return {
        "file": path,
        "size_mb": round(os.path.getsize(path) / 1e6, 3),
        "tris": sum(max(0, len(p.vertices) - 2) for p in ob.data.polygons),
        "materials": len(ob.data.materials),
        # Blender (x, y, z) -> Godot (x, z, -y)
        "godot_bounds_min": [round(lo[0], 2), round(lo[2], 2), round(-hi[1], 2)],
        "godot_bounds_max": [round(hi[0], 2), round(hi[2], 2), round(-lo[1], 2)],
    }


if __name__ == "__main__":
    print(build())
    print(export())
