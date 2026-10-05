"""
Dark Sector — export the regenerated turret, alien fleet and scenery props.

The 3D-generator downloads in `temp/` (see `blender/scene_rebuild_prompts.md`)
are single textured meshes, each normalised to **1.0 unit on its longest side**
with 4096px textures and no glass. This script gives each one its real game
size and pivot, decimates it, caps its texture and writes a game-ready .glb:

    temp/turret_gun.glb          -> assets/object/turret/turret_gun.glb
    temp/turret_base.glb         -> assets/object/turret/turret_base.glb
    temp/alien_scout_saucer.glb  -> assets/object/alien/alien_ship.glb
    temp/alien_gunship.glb       -> assets/object/alien/alien_ship_2.glb
    temp/alien_heavy_disc.glb    -> assets/object/alien/alien_ship_3.glb
    temp/alien_ore_carrier.glb   -> assets/object/alien/alien_ore_carrier.glb

The aliens keep the file names `AlienShip.HULLS` already preloads, so swapping
the fleet is not a code change.

It drives the same helpers as `export_alien.py` (decimate, texture cap, base
colour only, surface finish), so the whole game takes its finish from the same
two numbers. What is new here is the part that differs per model:

* **size**: the longest side in game units, because the generator's 1.0 means
  nothing in the game;
* **origin**: bottom-centre for a base, the trunnion axis for the gun — the
  point `AimPivot` rotates about — or the bounds centre for a ship, which
  wobbles and banks about that point;
* **yaw**: which way the model's front points. Everything generated here points
  Blender -Y (the glTF Y-up export turns that into Godot +Z, toward the
  camera), which is exactly how an alien must face. The gun is the opposite: its
  barrel has to end up on Godot -Z, so it is yawed 180 degrees.

How to run
----------
Headless, from the repo root (the Godot editor is not involved):

    "<blender>/blender.exe" --background --factory-startup \
        --python blender/export_rebuild.py [-- name name ...]

With no names it exports everything in SPECS. It prints, per model, what the
Godot scenes depend on: the Godot-space bounds (the alien collision box in
`AlienShip.tscn`) and, for the gun, the muzzle offset `Turret.tscn` hard-codes.
`temp/` is local only, so this cannot be re-run on a fresh checkout — the
exported files under `assets/` are what ships.
"""

import importlib.util
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector


def _project_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(here)


def _load_export_alien():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export_alien.py")
    spec = importlib.util.spec_from_file_location("export_alien", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --- origins ----------------------------------------------------------------
# Each takes the model's (lo, hi) bounds in Blender space and returns the point
# that becomes the origin.


def _bottom_centre(lo, hi):
    return Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))


def _bounds_centre(lo, hi):
    return (lo + hi) / 2


# The gun's trunnion axis, in the generator's normalised units. Measured off the
# model's own texture — the centre of the two amber side caps the barrel pivots
# on — rather than guessed: x is 0 (the caps are symmetric), y and z below. The
# caps sit slightly behind the middle of the housing and low, which is what a
# real elevation axis does.
GUN_TRUNNION = Vector((0.0, 0.088, 0.147))
# The barrel's axis at its tip, same units. It is above the trunnion axis, so
# the muzzle sits a little above `AimPivot`, as it always has.
GUN_MUZZLE = Vector((0.0, -0.5, 0.233))


def _gun_pivot(lo, hi):
    return GUN_TRUNNION


# The deck is a 140-degree arc of console blocks with a round notch cut out of
# its near edge: the turret's seat. The seat's centre is the centre of the circle
# the console rim lies on (fitted to the rim's vertices), which is *outside* the
# model's bounds — the notch is bitten out of the edge. Bottom of the deck is z=0.
DECK_SEAT = Vector((0.0, -0.294, 0.0))


def _deck_seat(lo, hi):
    return DECK_SEAT


# --- the models -------------------------------------------------------------

PI = math.pi

SPECS = {
    "turret_base": {
        "src": "turret_base.glb",
        "out": os.path.join("assets", "object", "turret", "turret_base.glb"),
        # Diameter, set so the base plate exactly fills the round seat cut in the
        # deck (radius 1.42 at the deck's size of 8.5) — no ring of gap around it.
        "size": 2.86,
        # Flattened a little so the pedestal does not tower over the deck. The
        # plate's top is then ~0.11 above the deck floor, which Game.tscn closes
        # by seating the turret that far down.
        "squash": 0.8,
        "origin": _bottom_centre,
        "yaw": 0.0,
        "budget": 9000,
        "texture": 1024,
    },
    "turret_gun": {
        "src": "turret_gun.glb",
        "out": os.path.join("assets", "object", "turret", "turret_gun.glb"),
        # Length, barrel tip to rear. The barrel is the first thing the player
        # reads, so it is long enough to point with. Grows with the base (2.86 /
        # 2.4) so the two stay in proportion.
        "size": 2.62,
        "origin": _gun_pivot,
        "yaw": PI,  # barrel from Blender -Y to +Y, i.e. Godot -Z
        "budget": 8000,
        "texture": 1024,
        "report_muzzle": True,
    },
    "iss_hull_deck": {
        "src": "iss_hull_deck.glb",
        "out": os.path.join("assets", "object", "iss", "iss_hull_deck.glb"),
        # Width of the arc. The origin is the turret's seat, so the turret node
        # and this one share a position in Game.tscn and nothing is lined up by
        # hand — the same arrangement the old hull had.
        "size": 8.5,
        "origin": _deck_seat,
        "yaw": 0.0,  # consoles on Blender +Y, which is Godot -Z, ahead of the gun
        "budget": 9000,
        "texture": 1024,
        # The generated deck is a 140-degree arc. The console blocks repeat every
        # 24 degrees with a clear gap between them, at 31, 55 ... 151 degrees
        # (measured round the seat axis from +X), so the arc is cut at two of
        # those gaps — 31 and 151, a 120-degree wedge with no block sliced
        # through — and three wedges turned 120 degrees apart close into a full
        # ring around the turret. The budget above is for one 140-degree arc, so
        # the ring as a whole carries about three times it.
        "ring": {"from_deg": 31.0, "to_deg": 151.0, "copies": 3},
        # Under the turret, a round pad level with the deck floor, so the base
        # plate sits on a platform with nothing around it. With the deck closed
        # into a ring the seat is a hole in the middle of it, and the pad is what
        # is in the hole. Game units, centred on the seat. Radius is the hole
        # (1.42) plus a rim; the
        # height is just under the floor (0.368) so the deck's own floor wins
        # wherever the two overlap instead of the surfaces fighting.
        "pad": {"radius": 1.6, "height": 0.366, "colour": (0.032, 0.036, 0.046, 1.0)},
    },
    "alien_scout_saucer": {
        "src": "alien_scout_saucer.glb",
        "out": os.path.join("assets", "object", "alien", "alien_ship.glb"),
        "size": 1.84,
        "origin": _bounds_centre,
        "yaw": 0.0,
        "budget": 12000,
        "texture": 512,
    },
    "alien_ore_carrier": {
        "src": "alien_ore_carrier.glb",
        "out": os.path.join("assets", "object", "alien", "alien_ore_carrier.glb"),
        # The same footprint as a scout. The ship itself is scaled up by
        # CampaignData.ORE_CARRIER["size"] in the spawner, so what is authored
        # here is a scout-sized hull and the table says how much bigger it is.
        "size": 1.9,
        "origin": _bounds_centre,
        "yaw": 0.0,  # pilot faces Blender -Y, like the rest of the fleet
        "budget": 12000,
        "texture": 512,
    },
    "alien_gunship": {
        "src": "alien_gunship.glb",
        "out": os.path.join("assets", "object", "alien", "alien_ship_2.glb"),
        "size": 1.84,
        "origin": _bounds_centre,
        "yaw": 0.0,
        # Hand-tuned in Blender (blender/make_fleet_adjust.py, read back by
        # read_fleet_adjust.py): the generated hull is not axis-aligned, so its
        # nose is turned onto the flight arrow by this attitude (Euler XYZ,
        # degrees, Blender axes) and scaled by `scale` on the generator's
        # 1.0-unit-longest-side model. Overrides `size` and `yaw`.
        "euler_deg": (-11.88, 0.26, -32.4),
        "scale": 3.0485,
        "budget": 14000,
        "texture": 512,
    },
    "alien_heavy_disc": {
        "src": "alien_heavy_disc.glb",
        "out": os.path.join("assets", "object", "alien", "alien_ship_3.glb"),
        # Smaller than the others: it is the tallest hull, and the shared
        # collision box in AlienShip.tscn is 1.15 high.
        "size": 1.55,
        "origin": _bounds_centre,
        "yaw": PI / 2,
        # Hand-tuned in Blender, as for the gunship. Overrides `size` and `yaw`.
        "euler_deg": (-4.18, -2.89, 55.33),
        "scale": 3.086,
        "budget": 26000,
        "texture": 1024,
        # The generator drew this hull green and white; the fleet is purple.
        # Greens (hue 0.18-0.50) turn violet (+0.44). Set to None to ship it
        # as generated.
        "recolour": ((0.18, 0.50), 0.77, 0.44),
    },
}


# The Moon's alien base (blender/moon_layout.py places them). Each is exported
# once, at the size of its largest instance, standing on its own bottom centre —
# the layout scales the smaller instances down. Metres.
def _moon_prop(name, size, budget, texture=512):
    return {
        "src": name + ".glb",
        "out": os.path.join("assets", "object", "moon", name + ".glb"),
        "size": size,
        "origin": _bottom_centre,
        "yaw": 0.0,
        "budget": budget,
        "texture": texture,
    }


SPECS.update({
    "moon_alien_dome_geodesic": _moon_prop("moon_alien_dome_geodesic", 20.0, 9000, 1024),
    "moon_alien_dome_shell": _moon_prop("moon_alien_dome_shell", 12.0, 7000, 1024),
    "moon_alien_spire": _moon_prop("moon_alien_spire", 36.0, 6000, 1024),
    "moon_alien_tanks": _moon_prop("moon_alien_tanks", 10.0, 6000),
    "moon_alien_lander": _moon_prop("moon_alien_lander", 6.5, 8000),
})


# Mars' colony and alien rig (blender/mars_layout.py places them). Each is exported
# once, at the size of its largest instance, standing on its bottom centre; the
# layout scales the smaller ones down. The tower and the second pod are the later
# generations of those two models.
def _mars_prop(name, size, budget, texture=512):
    return {
        "src": name + ".glb",
        "out": os.path.join("assets", "object", "mars", name + ".glb"),
        "size": size,
        "origin": _bottom_centre,
        "yaw": 0.0,
        "budget": budget,
        "texture": texture,
    }


SPECS.update({
    "mars_colony_dome": _mars_prop("mars_colony_dome", 22.0, 8000, 1024),
    "mars_colony_tower2": _mars_prop("mars_colony_tower2", 26.0, 9000, 1024),
    "mars_hab_pod": _mars_prop("mars_hab_pod", 8.5, 6000),
    "mars_hab_pod2": _mars_prop("mars_hab_pod2", 7.5, 6000),
    "mars_radar_dish": _mars_prop("mars_radar_dish", 11.0, 6000),
    "mars_cargo_crawler": _mars_prop("mars_cargo_crawler", 13.0, 7000),
    "mars_rover": _mars_prop("mars_rover", 5.5, 7000),
    "mars_drill_rig": _mars_prop("mars_drill_rig", 32.0, 16000, 1024),
    "mars_mining_crane": _mars_prop("mars_mining_crane", 22.0, 9000),
    "mars_ore_pile": _mars_prop("mars_ore_pile", 6.5, 4500),
    "mars_alien_drone": _mars_prop("mars_alien_drone", 3.6, 4500),
})


# Earth's landmark towers and mid-rise buildings (blender/earth_layout.py places
# them). Each was generated at night with its windows lit, so its own texture is
# also its emission: the walls are dark and the windows bright, which is what makes
# lit windows glow instead of being merely bright paint. (A second mid-rise, `earth_building_midrise_b`, was generated too, but it is 1.96M faces of separate
# window islands that no decimation here could bring under ~150k, so the layout uses the first one twice.) Standing on their bottom
# centre; exported at the size of their largest instance.
def _earth_prop(name, size, budget, texture=1024, emissive=1.1):
    spec = {
        "src": name + ".glb",
        "out": os.path.join("assets", "object", "earth", name + ".glb"),
        "size": size,
        "origin": _bottom_centre,
        "yaw": 0.0,
        "budget": budget,
        "texture": texture,
        "emissive": emissive,
    }
    return spec


SPECS.update({
    "earth_tower_artdeco": _earth_prop("earth_tower_artdeco", 205.0, 9000),
    "earth_tower_neon": _earth_prop("earth_tower_neon", 225.0, 7000),
    "earth_tower_pixel": _earth_prop("earth_tower_pixel", 275.0, 9000),
    "earth_building_midrise_a": _earth_prop("earth_building_midrise_a", 85.0, 4500),
})


# The ISS scene's one station part, a module drifting past (blender/iss_layout.py
# places it). Floating in space, so it is centred on its own bounds, at the size
# `iss_layout.EXPORTED` says. The generator drew it with its long side along X,
# which is the way it travels.
def _iss_prop(name, size, budget, texture=1024):
    return {
        "src": name + ".glb",
        "out": os.path.join("assets", "object", "iss", name + ".glb"),
        "size": size,
        "origin": _bounds_centre,
        "yaw": 0.0,
        "budget": budget,
        "texture": texture,
    }


SPECS.update({
    "iss_module": _iss_prop("iss_module", 22.0, 9000),
})


# --- pipeline ---------------------------------------------------------------

def _recolour(images, hue_from, hue_to, delta):
    """Rotate one band of hues in place, to pull a model into the fleet's palette.

    A generator hands each ship back in whatever colours its picture had, and a
    wave only reads as one fleet if the hulls share a palette. Pixels whose hue
    lies in `hue_from` (low, high; 0-1) have `delta` added to it, and the rest
    are untouched. `hue_to` is only documentation of where that lands. Done
    on the already-downscaled copies, in a gamma-ish space so a mid green
    stays a mid purple, never on the source files.
    """
    import numpy as np

    lo, hi = hue_from
    for img in images:
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = np.clip(px[:, :3], 0.0, 1.0) ** (1 / 2.2)
        mx = rgb.max(axis=1)
        mn = rgb.min(axis=1)
        d = mx - mn
        sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
        r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
        dd = np.maximum(d, 1e-6)
        hue = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) / 6.0
        sel = (hue >= lo) & (hue <= hi) & (sat > 0.25) & (d > 0.05)
        hue = np.where(sel, (hue + delta) % 1.0, hue)
        # HSV -> RGB
        i = np.floor(hue * 6).astype(np.int32) % 6
        f = hue * 6 - np.floor(hue * 6)
        p_ = mx * (1 - sat)
        q = mx * (1 - f * sat)
        t = mx * (1 - (1 - f) * sat)
        out = np.stack([
            np.choose(i, [mx, q, p_, p_, t, mx]),
            np.choose(i, [t, mx, mx, q, p_, p_]),
            np.choose(i, [p_, p_, t, mx, mx, q]),
        ], axis=1)
        px[:, :3] = np.where(sel[:, None], out, rgb) ** 2.2
        img.pixels = px.ravel().tolist()
        img.update()



def _transformed_bounds(ea, matrix):
    """Bounds of every source vertex after `matrix`, without moving anything."""
    import numpy as np

    lo = np.full(3, 1e18)
    hi = np.full(3, -1e18)
    m = np.array(matrix)
    for obj in ea._meshes():
        n = len(obj.data.vertices)
        co = np.empty(n * 3, dtype=np.float64)
        obj.data.vertices.foreach_get("co", co)
        pts = co.reshape(-1, 3)
        pts = np.c_[pts, np.ones(n)] @ np.array(obj.matrix_world).T
        pts = pts @ m.T
        lo = np.minimum(lo, pts[:, :3].min(axis=0))
        hi = np.maximum(hi, pts[:, :3].max(axis=0))
    return Vector(lo), Vector(hi)


def _import(path):
    """Import a generator .glb and hang every mesh off a `ROOT` empty.

    `export_alien`'s helpers find their meshes as the descendants of an empty
    called ROOT. Tripo's own files bring one (named differently, or not at all),
    so ROOT is made here, uniformly.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    root = bpy.data.objects.new("ROOT", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            obj.parent = root
            obj.matrix_parent_inverse = Matrix.Identity(4)
    return root


def _join_if_needed(trash):
    """`export_alien._join`, tolerating a model that is already one mesh."""
    objs = trash["objects"]
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    if len(objs) > 1:
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    for o in bpy.context.view_layer.objects:
        o.select_set(o == joined)
    trash["objects"] = [joined]
    trash["meshes"] = [joined.data]
    return joined


def _make_ring(ring, trash):
    """Cut the deck to a wedge between two angles and repeat it into a full ring.

    Runs on the finished (scaled, decimated) mesh, whose origin is the turret's
    seat, so every angle is measured about the origin and rotating a copy about Z
    turns it about the seat. The cuts are planes through the seat axis, and are
    made where the deck has a gap between console blocks, so no block is sliced.
    The cut faces are left open: the neighbouring wedge's matching cut covers
    them, and nothing but the floor plate's thin edge is ever seen there.
    """
    import bmesh

    src = trash["objects"][0]
    bpy.context.view_layer.objects.active = src
    src.select_set(True)
    for mod in list(src.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # `_build_copies` placed the copy with an object transform (scale, and the
    # shift that puts the seat at the origin) and left the vertices alone. Bake
    # it in, so the planes below are cut about the seat and a copy turned about
    # Z turns about it too, instead of replacing that transform.
    src.data.transform(src.matrix_world)
    src.matrix_world = Matrix.Identity(4)

    bm = bmesh.new()
    bm.from_mesh(src.data)
    a1 = math.radians(ring["from_deg"])
    a2 = math.radians(ring["to_deg"])
    # Keep what lies counter-clockwise of a1 and clockwise of a2.
    n1 = Vector((-math.sin(a1), math.cos(a1), 0.0))
    n2 = Vector((-math.sin(a2), math.cos(a2), 0.0))
    for normal, inner in ((n1, True), (n2, False)):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(
            bm, geom=geom, plane_co=(0.0, 0.0, 0.0), plane_no=normal,
            clear_inner=inner, clear_outer=not inner,
        )
    bm.to_mesh(src.data)
    bm.free()

    step = 2 * math.pi / ring["copies"]
    for i in range(1, ring["copies"]):
        dup = src.copy()
        dup.data = src.data.copy()
        bpy.context.scene.collection.objects.link(dup)
        # glTF imports leave objects in quaternion mode, where an Euler angle
        # is silently ignored.
        dup.rotation_mode = "XYZ"
        dup.rotation_euler = (0.0, 0.0, step * i)
        trash["objects"].append(dup)
        trash["meshes"].append(dup.data)
    # Without this the join below reads each copy's stale (identity) world
    # matrix and stacks all three wedges in one place.
    bpy.context.view_layer.update()


def _dissolve_then_collapse(trash, spec, ea):
    """Merge coplanar faces first, then collapse to the budget.

    A model built of thousands of separate flat features — window frames, ledges —
    leaves a collapse decimation with nothing to merge: every little island keeps
    its faces, and the result stays far over budget. Dissolving faces that lie in
    one plane (within `dissolve` degrees) removes them without touching the
    silhouette, and the collapse then has real work to do.
    """
    import bmesh

    for obj in trash["objects"]:
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            obj.modifiers.remove(mod)
        # Weld first. Some generator meshes arrive with every face carrying its own
        # copy of its corners, so no edge is shared and the collapse has nothing it
        # is allowed to merge. UVs are stored per face corner, so welding keeps them.
        before = len(obj.data.vertices)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.to_mesh(obj.data)
        bm.free()
        print("welded", before, "->", len(obj.data.vertices), "vertices")
        dis = obj.modifiers.new("Dissolve", "DECIMATE")
        dis.decimate_type = "DISSOLVE"
        dis.angle_limit = math.radians(spec["dissolve"])
        bpy.ops.object.modifier_apply(modifier=dis.name)
    total = sum(len(o.data.polygons) for o in trash["objects"])
    ratio = min(1.0, spec["budget"] / float(total))
    print("dissolved to", total, "faces; collapsing by", round(ratio, 4))
    for obj in trash["objects"]:
        polys = len(obj.data.polygons)
        if polys:
            floor = min(1.0, ea.MIN_POLYS_PER_PART / float(polys))
            dec = obj.modifiers.new("Decimate", "DECIMATE")
            dec.decimate_type = "COLLAPSE"
            dec.ratio = max(ratio, floor)


def _make_emissive(materials, strength):
    """Drive each material's emission from its own base-colour texture."""
    for mat in materials:
        if not mat.use_nodes:
            continue
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image is not None), None)
        if bsdf is None or tex is None:
            continue
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = strength


def _add_pad(pad, trash):
    """A plain dark cylinder under the origin, in final (game-unit) coordinates."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=pad["radius"], depth=pad["height"],
        location=(0.0, 0.0, pad["height"] / 2),
    )
    obj = bpy.context.view_layer.objects.active
    obj.name = "SeatPad"
    mat = bpy.data.materials.new("SeatPad")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = pad["colour"]
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.05
    obj.data.materials.append(mat)
    trash["objects"].append(obj)
    trash["meshes"].append(obj.data)
    trash["materials"].append(mat)


def export_prop(name, out_root=None):
    spec = dict(SPECS[name])
    if os.environ.get("REBUILD_NO_RECOLOUR"):
        spec["recolour"] = None
    ea = _load_export_alien()
    ea.MAX_TEXTURE_SIZE = spec["texture"]
    # The alien pipeline never decimates a part below 150 faces, so a model built
    # of many tiny parts can't reach its budget; `min_polys` lowers that floor.
    ea.MIN_POLYS_PER_PART = spec.get("min_polys", 150)

    root = _project_root()
    src = os.path.join(root, "temp", spec["src"])
    if not os.path.isfile(src):
        raise RuntimeError("source model not found: %s — temp/ is local only" % src)
    _import(src)

    lo, hi = ea._vert_bounds(ea._meshes())
    longest = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    if spec.get("euler_deg"):
        # A hand-set attitude and scale. The ship is centred on the middle of its
        # bounds *after* turning, since it banks and wobbles about that point.
        scale = spec["scale"]
        scale_matrix = Matrix.Scale(scale, 4)
        rot = Euler([math.radians(a) for a in spec["euler_deg"]], "XYZ").to_matrix().to_4x4()
        turned = rot @ scale_matrix
        tlo, thi = _transformed_bounds(ea, turned)
        matrix = Matrix.Translation(-(tlo + thi) / 2) @ turned
    else:
        scale = spec["size"] / longest
        origin = spec["origin"](lo, hi)
        # `squash` flattens a model along its height (z), for a part that has to
        # meet another at one level — the turret's base plate against the deck.
        scale_matrix = Matrix.Diagonal((scale, scale, scale * spec.get("squash", 1.0), 1.0))
        matrix = (
            scale_matrix
            @ Matrix.Rotation(spec["yaw"], 4, "Z")
            @ Matrix.Translation(-origin)
        )

    trash = {k: [] for k in ("objects", "meshes", "materials", "images", "collections")}
    path = os.path.join(out_root or root, spec["out"])
    os.makedirs(os.path.dirname(path), exist_ok=True)

    try:
        src_tris, ratio = ea._build_copies(matrix, trash, spec["budget"])
        if spec.get("dissolve"):
            _dissolve_then_collapse(trash, spec, ea)
        if spec.get("recolour"):
            _recolour(trash["images"], *spec["recolour"])
        if spec.get("emissive"):
            _make_emissive(trash["materials"], spec["emissive"])
        if spec.get("ring"):
            _make_ring(spec["ring"], trash)
        if spec.get("pad"):
            _add_pad(spec["pad"], trash)
        joined = _join_if_needed(trash)
        joined.name = name
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_image_format="JPEG",
            export_jpeg_quality=ea.JPEG_QUALITY,
            export_animations=False,
            export_extras=False,
        )
        joined.data.calc_loop_triangles()
        out_tris = len(joined.data.loop_triangles)
        out_lo, out_hi = ea._vert_bounds(trash["objects"])
    finally:
        ea._discard(trash)

    report = {
        "file": os.path.relpath(path, root),
        "size_mb": round(os.path.getsize(path) / 1e6, 2),
        "source_tris": src_tris,
        "exported_tris": out_tris,
        "scale": round(scale, 4),
        # Blender (x, y, z) -> Godot (x, z, -y).
        "godot_size": [
            round(out_hi.x - out_lo.x, 3),
            round(out_hi.z - out_lo.z, 3),
            round(out_hi.y - out_lo.y, 3),
        ],
        "godot_min": [round(v, 3) for v in (out_lo.x, out_lo.z, -out_hi.y)],
        "godot_max": [round(v, 3) for v in (out_hi.x, out_hi.z, -out_lo.y)],
    }
    if spec.get("report_muzzle"):
        m = scale_matrix @ Matrix.Rotation(spec["yaw"], 4, "Z") @ Matrix.Translation(-origin)
        p = m @ GUN_MUZZLE
        # Blender (x, y, z) -> Godot (x, z, -y)
        report["godot_muzzle_from_pivot"] = [round(p.x, 3), round(p.z, 3), round(-p.y, 3)]
    return report


def main(names=None):
    names = names or list(SPECS)
    reports = {}
    for n in names:
        reports[n] = export_prop(n)
        print(n, json.dumps(reports[n]))
    return reports


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
