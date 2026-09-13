"""
Dark Sector — export the Tripo alien saucer from Blender into the game.

Companion to `export_turret.py`, same pipeline and conventions, different
subject: `AlienShip.blend` holds one model — a flying saucer with an alien in a
glass dome — as 61 meshes parented to a `ROOT` empty. This script writes it out
as a game-ready glTF binary:

    assets/object/alien/alien_ship.glb

The raw model is ~2.0M tris across 61 parts with 61 textures (some 2048), which
is nowhere near shippable: unlike the turret there are several aliens alive at
once, so this one is decimated harder and its textures are capped smaller.

The export re-origins the saucer on its own centre (it wobbles and banks about
that point in flight), yaws it so the alien faces down Godot's +Z — the
direction the ships fly, toward the camera and Earth — scales to game units and
joins every part into a single mesh, so one alien is one node in the scene tree
instead of 61.

Unlike the turret and station hull, the saucer is deliberately **not** white
balanced onto the turret's hue. That grade exists to make the player's own
hardware read as one material family; the aliens are supposed to sit apart from
it, and pulling their purple hull and green pilot toward the turret's grey would
throw away the one strong colour contrast the gameplay screen has. They do get
the same surface finish, because Tripo hands everything back flat matte and the
dome needs a highlight to read as glass.

Nothing in the source scene is modified: every step runs on duplicated objects,
materials and images, all of which are deleted again afterwards.

How to run
----------
Blender Scripting tab -> open this file -> Run Script, or from the Python
console / an MCP session:

    exec(open("blender/export_alien.py").read())
    export_alien()

`export_alien` prints the bounds the Godot scene depends on — `AlienShip.tscn`
hard-codes a collision shape sized to them, so update it if they move.
"""

import bpy
import json
import math
import os

from mathutils import Matrix, Vector

# --- tuning -----------------------------------------------------------------

# Blender units -> game units. The saucer is ~1.04 units across in Blender; at
# 1.9 it lands at ~1.98 game units, a shade wider than the 1.5 placeholder cube
# it replaces, which is what a disc needs to carry the same visual mass.
GAME_SCALE = 1.9

# Decimation budget for the whole ship. Well under the turret's 25k: a wave puts
# several of these on screen at once, they are never closer than a few units to
# the camera, and the saucer's silhouette is mostly smooth curves that survive a
# collapse cleanly.
#
# It buys less than its name suggests — it is divided by the source's *face*
# count, and Tripo's meshes are quads, so the saucer leaves here at ~13k
# triangles rather than 9k. Treat it as a dial, not as a promise, and read the
# `exported_tris` the export prints for what actually shipped.
#
# A ship built out of flat plating rather than curves needs a bigger one: see
# `budget` in export_alien_variants.py.
TRI_BUDGET = 9000

# Never decimate a single part below this, so the rim lights and the pilot's
# face keep their shape instead of collapsing into slivers at the global ratio.
MIN_POLYS_PER_PART = 150

# Longest edge allowed on any texture. Half the turret's cap: the saucer is a
# fraction of the screen even at its closest, and it carries 61 basecolor maps.
MAX_TEXTURE_SIZE = 256

JPEG_QUALITY = 85

# Surface finish forced onto the saucer's materials. Tripo delivers roughness
# 0.9 with no metallic, which reads as chalk on the hull and kills the dome.
# Metallic stays low on purpose: GL-Compatibility has no reflection probe or sky
# here, so metal has nothing to reflect and goes black.
SURFACE_FINISH = {"roughness": 0.5, "metallic": 0.05}

# The only textured inputs a ship keeps; see _base_colour_only for why the rest
# have to go.
KEEP_LINKED = ("Base Color", "Alpha")

# The empty every mesh in the .blend hangs off.
SOURCE_PARENT = "ROOT"

OUT_DIR = os.path.join("assets", "object", "alien")
OUT_FILE = "alien_ship.glb"

# --- geometry measurement ---------------------------------------------------


def _meshes():
    root = bpy.data.objects.get(SOURCE_PARENT)
    if root is None:
        raise RuntimeError("object %r not found in the .blend" % SOURCE_PARENT)
    objs = [o for o in root.children_recursive if o.type == "MESH"]
    if not objs:
        raise RuntimeError("%r has no mesh descendants" % SOURCE_PARENT)
    return objs


def _world_verts(objs):
    for o in objs:
        mw = o.matrix_world
        for v in o.data.vertices:
            yield mw @ v.co


def _vert_bounds(objs):
    """Tight bounds over actual vertices.

    Unioning per-object bounding boxes overshoots once the export transform has
    rotated them, and the collision shape in Godot is sized off these numbers.
    """
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for p in _world_verts(objs):
        for i in range(3):
            lo[i] = min(lo[i], p[i])
            hi[i] = max(hi[i], p[i])
    return lo, hi


def _transform(yaw=None):
    """World -> export-space matrix.

    Moves the saucer's centre to the origin, yaws it so the pilot ends up
    facing Godot's +Z after the glTF Y-up conversion, and scales into game
    units.

    **This model faces +X in Blender** — check it in the Numpad-3 (Right) view,
    where you should be looking the pilot in the face. Don't try to infer the
    facing from the bounds: the saucer is very nearly as wide as it is long, so
    which axis is "longer" flips with small edits to the model and says nothing
    about which end is the nose.

    The yaw direction was settled in the engine, not on paper: park a ship
    close in front of the gameplay camera and look at its face. Blender's Y-up
    conversion sends Blender -Y to Godot +Z, which is the way the ships fly, so
    the nose has to end up on -Y — hence the -90 default, swinging it round
    from +X. (The mirror of this, +90, presents the dome to the player and
    reads as the saucer flying home tail-first.)

    `export_alien_variants.py` passes a different `yaw` for each ship in the
    pool, because the other two models came out of Tripo pointing elsewhere.
    """
    lo, hi = _vert_bounds(_meshes())
    centre = (lo + hi) * 0.5
    scale = Matrix.Scale(GAME_SCALE, 4)
    face_forward = Matrix.Rotation(-math.pi / 2 if yaw is None else yaw, 4, "Z")
    return scale @ face_forward @ Matrix.Translation(-centre)


# --- throwaway copies -------------------------------------------------------


def _base_colour_only(mat, bsdf):
    """Strip every map but base colour off a Principled BSDF.

    Tripo returns some models with a basecolor map only and others carrying a
    packed metallic/roughness map and a normal map as well, and that difference
    is not cosmetic. SURFACE_FINISH below is only written into sockets that
    aren't already linked, so a ship that arrives with those maps silently keeps
    Tripo's own values — metallic 1.0 included — and on GL-Compatibility, with
    no reflection probe or sky to reflect, a fully metallic hull renders as a
    black blob. The first export of `alien_ship_3.glb` did exactly that.

    Dropping the maps is also what keeps the fleet one material family: every
    ship then takes its finish from the same two numbers, and the ones that
    carry three maps per part stop costing three times the texture memory of the
    ones that carry one. At the size an alien is on screen, none of it is
    missed.
    """
    for socket in bsdf.inputs:
        if socket.name in KEEP_LINKED:
            continue
        for link in list(socket.links):
            mat.node_tree.links.remove(link)


def _retexture(obj, cache, trash):
    """Give obj its own materials, with downscaled copies of each image.

    The cache is shared across the whole ship so each source material is copied
    and each image resized exactly once, however many objects reference them.
    """
    for slot in obj.material_slots:
        src = slot.material
        if src is None:
            continue
        if src.name in cache:
            slot.material = cache[src.name]
            continue

        mat = src.copy()
        trash["materials"].append(mat)
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    _base_colour_only(mat, node)
                    for key, value in SURFACE_FINISH.items():
                        socket = node.inputs.get(key.capitalize())
                        if socket is not None and not socket.is_linked:
                            socket.default_value = value
                if node.type != "TEX_IMAGE" or node.image is None:
                    continue
                w, h = node.image.size
                if w == 0 or h == 0 or max(w, h) <= MAX_TEXTURE_SIZE:
                    continue
                copy = node.image.copy()
                trash["images"].append(copy)
                f = MAX_TEXTURE_SIZE / max(w, h)
                copy.scale(max(1, int(w * f)), max(1, int(h * f)))
                node.image = copy
        cache[src.name] = mat
        slot.material = mat


def _build_copies(matrix, trash, budget=None):
    """Duplicate every part, transform it, decimate it and join the lot."""
    objs = _meshes()
    total = sum(len(o.data.polygons) for o in objs)
    ratio = min(1.0, (budget or TRI_BUDGET) / float(total))

    holder = bpy.data.collections.new("__export_tmp")
    trash["collections"].append(holder)
    bpy.context.scene.collection.children.link(holder)

    cache = {}
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

        _retexture(dup, cache, trash)

    return total, ratio


def _join(trash):
    """Collapse the parts into one mesh, so an alien is one node in Godot.

    The decimate modifiers are applied first: a join keeps only the *active*
    object's modifier stack, so leaving them for the exporter's `export_apply`
    would silently ship every other part at full density.
    """
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in trash["objects"]:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)

    bpy.context.view_layer.objects.active = trash["objects"][0]
    bpy.ops.object.join()

    joined = bpy.context.view_layer.objects.active
    joined.name = "AlienShip"
    # join() consumed the others; keep the survivor off the discard list.
    trash["objects"] = [joined]
    trash["meshes"] = [joined.data]
    return joined


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
    if here and os.path.isdir(os.path.join(os.path.dirname(here), "assets")):
        return os.path.dirname(here)
    return os.path.abspath(os.getcwd())


def export_alien(out_dir=None, out_file=None, yaw=None, budget=None):
    """Export the saucer currently in the scene. Returns what it measured.

    `out_file`, `yaw` and `budget` exist for `export_alien_variants.py`, which
    drives this same pipeline over the other ships in the pool; called bare it
    exports `AlienShip.blend` exactly as it always did.
    """
    matrix = _transform(yaw)
    trash = {k: [] for k in ("objects", "meshes", "materials", "images", "collections")}

    root = out_dir or os.path.join(_project_root(), OUT_DIR)
    os.makedirs(root, exist_ok=True)
    path = os.path.join(root, out_file or OUT_FILE)

    try:
        src_tris, ratio = _build_copies(matrix, trash, budget)
        joined = _join(trash)

        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,            # Blender Z-up -> glTF/Godot Y-up
            export_image_format="JPEG",
            export_jpeg_quality=JPEG_QUALITY,
            export_animations=False,
            export_extras=False,
        )

        out_tris = len(joined.data.polygons)
        surfaces = len(joined.material_slots)
        lo, hi = _vert_bounds(trash["objects"])
    finally:
        _discard(trash)

    return {
        "file": path,
        "size_mb": round(os.path.getsize(path) / 1e6, 2),
        "source_tris": src_tris,
        "exported_tris": out_tris,
        "decimate_ratio": round(ratio, 4),
        "surfaces": surfaces,
        # Blender (x, y, z) -> Godot (x, z, -y).
        "godot_bounds_min": [round(v, 3) for v in (lo.x, lo.z, -hi.y)],
        "godot_bounds_max": [round(v, 3) for v in (hi.x, hi.z, -lo.y)],
        "godot_size": [
            round(hi.x - lo.x, 3),
            round(hi.z - lo.z, 3),
            round(hi.y - lo.y, 3),
        ],
    }


if __name__ == "__main__":
    print(json.dumps(export_alien(), indent=2))
