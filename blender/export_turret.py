"""
Dark Sector — export the Tripo artillery turret from Blender into the game.

The Blender scene holds the model split across two collections:

    Turret      the gun assembly — yaws and pitches when aiming
    TurretBase  the fixed pedestal it sits on

This script writes each one out as a game-ready glTF binary:

    assets/object/turret_gun.glb
    assets/object/turret_base.glb

Both are re-origined on their gameplay pivot, yawed so the barrel points down
Godot's forward axis (-Z), scaled to game units and decimated/texture-reduced
to something the GL-Compatibility renderer and the web build can carry. The raw
model is ~1.9M tris across 122 parts with 124 textures (65 megapixels), which is
far past what this game can spend on one prop.

Nothing in the source scene is modified: every step runs on duplicated objects,
materials and images, all of which are deleted again afterwards.

How to run
----------
Blender Scripting tab -> open this file -> Run Script (exports both parts), or
from the Python console / an MCP session, one part at a time:

    exec(open("blender/export_turret.py").read())
    export_part("base")
    export_part("gun")

The pivots are measured from the geometry on every run, so re-running after
editing the model picks up the new shape. `export_part` prints the numbers the
Godot scene depends on (pivot height, muzzle offset) — if they move, update
`scenes/Turret.tscn` to match.
"""

import bpy
import json
import math
import os

from mathutils import Matrix, Vector

# --- tuning -----------------------------------------------------------------

# Blender units -> game units. The pedestal is ~14.6 units across in Blender;
# at 0.2 it lands at ~2.9 game units, matching the turret footprint Game.tscn
# was laid out around (old placeholder base was 2.5 x 2.0).
GAME_SCALE = 0.2

# Triangle budget per part, after decimation.
TRI_BUDGET = {"gun": 25000, "base": 25000}

# Never decimate a single part below this, so small greebles keep their shape
# instead of collapsing into slivers at the global ratio.
MIN_POLYS_PER_PART = 120

# Longest edge allowed on any texture. Each part carries its own basecolor map
# and the turret is only ever a few hundred pixels tall on screen.
MAX_TEXTURE_SIZE = 512

JPEG_QUALITY = 85

PARTS = {
    "gun": {"collection": "Turret", "out": "turret_gun.glb"},
    "base": {"collection": "TurretBase", "out": "turret_base.glb"},
}

# Its own folder: Godot extracts every embedded texture next to the .glb on
# import, and this model carries one basecolor map per part.
OUT_DIR = os.path.join("assets", "object", "turret")

# --- geometry measurement ---------------------------------------------------


def _meshes(collection_name):
    return [o for o in bpy.data.collections[collection_name].objects if o.type == "MESH"]


def _world_verts(objs):
    for o in objs:
        mw = o.matrix_world
        for v in o.data.vertices:
            yield mw @ v.co


def _bounds(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        mw = o.matrix_world
        for corner in o.bound_box:
            w = mw @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return lo, hi


def _yaw_axis():
    """Vertical axis the gun spins around: the centre of the pedestal footprint."""
    lo, hi = _bounds(_meshes(PARTS["base"]["collection"]))
    return (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z


def _trunnion(gun_objs, yaw_x):
    """Locate the pitch axis from the boss discs capping the housing sides.

    The gun's side bosses (the concentric ring/hub parts that read as the
    trunnion) are the only gun pieces that are flat in X and pushed right out to
    the housing's side face, so that shape test finds them without relying on
    which one happens to be painted orange. Their centres agree closely, so the
    median is taken.
    """
    ys, zs = [], []
    for o in gun_objs:
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
        size = hi - lo
        ctr = (hi + lo) * 0.5
        flat_in_x = size.x < 1.2
        out_on_the_side = abs(ctr.x - yaw_x) > 1.8
        boss_sized = max(size.y, size.z) < 4.0
        if flat_in_x and out_on_the_side and boss_sized:
            ys.append(ctr.y)
            zs.append(ctr.z)
    if not ys:
        return None
    ys.sort()
    zs.sort()
    return ys[len(ys) // 2], zs[len(zs) // 2]


def _barrel_elevation(gun_objs, pivot_y, pivot_z, yaw_x):
    """Resting elevation of the barrel, in radians.

    Sampling in slabs along Y doesn't work here: the breech housing shares those
    slabs with the barrel and drags the fit steep. Instead the barrel is walked
    in spherical shells around the pivot, which is a selection that doesn't
    depend on the angle being measured. Each shell's centroid is a point on the
    barrel centreline; shells fat enough to still be housing are dropped by
    comparing against the outer shells' radius.
    """
    origin = Vector((yaw_x, pivot_y, pivot_z))
    pts = [p for p in _world_verts(gun_objs) if (p - origin).y < 0]

    shells = []
    r = 2.5
    while r < 12.0:
        sel = [p for p in pts if r <= (p - origin).length < r + 0.5]
        if len(sel) >= 150:
            c = sum(sel, Vector()) / len(sel)
            axis = (c - origin).normalized()
            spread = max(((p - c) - (p - c).dot(axis) * axis).length for p in sel)
            shells.append((c.y, c.z, spread))
        r += 0.5
    if len(shells) < 3:
        raise RuntimeError("could not find enough barrel geometry to fit a centreline")

    outer = sorted(s[2] for s in shells[len(shells) // 2:])
    barrel_radius = outer[len(outer) // 2]
    samples = [(y, z) for y, z, spread in shells if spread < barrel_radius * 2.0]
    if len(samples) < 2:
        raise RuntimeError("barrel centreline fit found no clean shells")

    n = len(samples)
    sy = sum(s[0] for s in samples)
    sz = sum(s[1] for s in samples)
    syy = sum(s[0] * s[0] for s in samples)
    syz = sum(s[0] * s[1] for s in samples)
    a = (n * syz - sy * sz) / (n * syy - sy * sy)
    # Forward is -Y, so stepping forward one unit raises the barrel by -a.
    return math.atan(-a)


def measure():
    """Work out both pivots and the barrel's resting elevation from the mesh."""
    gun_objs = _meshes(PARTS["gun"]["collection"])
    yaw_x, yaw_y, base_z = _yaw_axis()

    boss = _trunnion(gun_objs, yaw_x)
    pivot_y, pivot_z = boss if boss else (yaw_y, base_z + 5.5)
    elevation = _barrel_elevation(gun_objs, pivot_y, pivot_z, yaw_x)

    # Pitch pivot sits on the trunnion; yaw runs vertically through it. The
    # trunnion is a fraction behind the pedestal centre, which at game scale is
    # well under a tenth of a unit, so one pivot serves for both axes.
    gun_pivot = Vector((yaw_x, pivot_y, pivot_z))
    base_pivot = Vector((yaw_x, yaw_y, base_z))
    return {"gun_pivot": gun_pivot, "base_pivot": base_pivot, "elevation": elevation}


def _transform(part, m):
    """World -> export-space matrix for a part.

    Moves the part's pivot to the origin, cancels the barrel's resting elevation
    (so the mesh lines up with the direction the turret script aims), spins it
    180 degrees so the barrel ends up on Godot's -Z after the glTF Y-up
    conversion, and scales into game units.
    """
    scale = Matrix.Scale(GAME_SCALE, 4)
    flip = Matrix.Rotation(math.pi, 4, "Z")
    if part == "gun":
        level = Matrix.Rotation(m["elevation"], 4, "X")
        return scale @ flip @ level @ Matrix.Translation(-m["gun_pivot"])
    return scale @ flip @ Matrix.Translation(-m["base_pivot"])


# --- throwaway copies -------------------------------------------------------


def _shrink_textures(obj, trash):
    """Give obj its own materials with downscaled copies of every image."""
    remap = {}
    for slot in obj.material_slots:
        src = slot.material
        if src is None:
            continue
        if src.name in remap:
            slot.material = remap[src.name]
            continue

        mat = src.copy()
        trash["materials"].append(mat)
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type != "TEX_IMAGE" or node.image is None:
                    continue
                w, h = node.image.size
                if w == 0 or h == 0 or max(w, h) <= MAX_TEXTURE_SIZE:
                    continue
                small = node.image.copy()
                trash["images"].append(small)
                f = MAX_TEXTURE_SIZE / max(w, h)
                small.scale(max(1, int(w * f)), max(1, int(h * f)))
                node.image = small
        remap[src.name] = mat
        slot.material = mat


def _build_copies(part, matrix, trash):
    """Duplicate the part's meshes, transform them and queue decimation."""
    objs = _meshes(PARTS[part]["collection"])
    total = sum(len(o.data.polygons) for o in objs)
    ratio = min(1.0, TRI_BUDGET[part] / float(total))

    holder = bpy.data.collections.new("__export_tmp")
    trash["collections"].append(holder)
    bpy.context.scene.collection.children.link(holder)

    for src in objs:
        dup = src.copy()
        dup.data = src.data.copy()
        dup.parent = None
        dup.matrix_world = matrix @ src.matrix_world
        holder.objects.link(dup)
        trash["objects"].append(dup)
        trash["meshes"].append(dup.data)

        polys = len(dup.data.polygons)
        if polys:
            # Small parts keep a floor so they don't collapse at the global ratio.
            floor = min(1.0, MIN_POLYS_PER_PART / float(polys))
            dec = dup.modifiers.new(name="Decimate", type="DECIMATE")
            dec.decimate_type = "COLLAPSE"
            dec.ratio = max(ratio, floor)

        _shrink_textures(dup, trash)

    return total, ratio


def _vert_bounds(objs):
    """Tight bounds over actual vertices.

    `_bounds` unions per-object bounding boxes, which overshoot once the export
    transform rotates them; the report and the muzzle need the real extent.
    """
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for p in _world_verts(objs):
        for i in range(3):
            lo[i] = min(lo[i], p[i])
            hi[i] = max(hi[i], p[i])
    return lo, hi


def _muzzle_centre(objs, front_y):
    """Centre of the barrel's end face, in export space.

    Taken as the centroid of the last thin slice of geometry at the front of the
    gun, so lasers spawn out of the bore rather than off a bounding-box corner.
    """
    slice_pts = [p for p in _world_verts(objs) if p.y > front_y - 0.06]
    if not slice_pts:
        return None
    return sum(slice_pts, Vector()) / len(slice_pts)


def _discard(trash):
    for o in trash["objects"]:
        bpy.data.objects.remove(o, do_unlink=True)
    for m in trash["meshes"]:
        if m.users == 0:
            bpy.data.meshes.remove(m)
    for m in trash["materials"]:
        bpy.data.materials.remove(m, do_unlink=True)
    for i in trash["images"]:
        bpy.data.images.remove(i, do_unlink=True)
    for c in trash["collections"]:
        bpy.data.collections.remove(c)


# --- export -----------------------------------------------------------------


def _project_root():
    """Repo root, whether the script is run from a file or pasted into Blender."""
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
    if here and os.path.isdir(os.path.join(os.path.dirname(here), OUT_DIR)):
        return os.path.dirname(here)
    return os.path.abspath(os.getcwd())


def export_part(part, out_dir=None):
    """Export one part ('gun' or 'base'). Returns a dict of what it measured."""
    if part not in PARTS:
        raise ValueError("part must be one of %s" % sorted(PARTS))

    m = measure()
    matrix = _transform(part, m)
    trash = {k: [] for k in ("objects", "meshes", "materials", "images", "collections")}

    root = out_dir or os.path.join(_project_root(), OUT_DIR)
    os.makedirs(root, exist_ok=True)
    path = os.path.join(root, PARTS[part]["out"])

    try:
        src_tris, ratio = _build_copies(part, matrix, trash)

        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        for o in trash["objects"]:
            o.select_set(True)
        bpy.context.view_layer.objects.active = trash["objects"][0]

        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,          # bakes the decimate modifiers
            export_yup=True,            # Blender Z-up -> glTF/Godot Y-up
            export_image_format="JPEG",
            export_jpeg_quality=JPEG_QUALITY,
            export_animations=False,
            export_extras=False,
        )

        lo, hi = _vert_bounds(trash["objects"])
        muzzle = _muzzle_centre(trash["objects"], hi.y) if part == "gun" else None
    finally:
        _discard(trash)

    # After the transform the barrel runs along +Y in Blender, which the Y-up
    # conversion turns into -Z in Godot — the axis Turret.gd fires along.
    report = {
        "part": part,
        "file": path,
        "size_mb": round(os.path.getsize(path) / 1e6, 2),
        "source_tris": src_tris,
        "decimate_ratio": round(ratio, 4),
        "rest_elevation_deg": round(math.degrees(m["elevation"]), 2),
        "godot_bounds_min": [round(v, 3) for v in (lo.x, lo.z, -hi.y)],
        "godot_bounds_max": [round(v, 3) for v in (hi.x, hi.z, -lo.y)],
    }
    if part == "gun":
        # Height of the pitch pivot above the ground the pedestal stands on.
        drop = (m["gun_pivot"].z - m["base_pivot"].z) * GAME_SCALE
        report["godot_aim_pivot_y"] = round(drop, 3)
        if muzzle:
            report["godot_muzzle"] = [round(muzzle.x, 3), round(muzzle.z, 3), round(-muzzle.y, 3)]
    return report


def export_all(out_dir=None):
    return [export_part(p, out_dir) for p in ("base", "gun")]


if __name__ == "__main__":
    print(json.dumps(export_all(), indent=2))
