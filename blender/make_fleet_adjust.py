"""
Dark Sector — build `temp/alien_fleet_adjust.blend`, a bench for hand-tuning the
alien ships' size and heading.

The game's ships are exported by `export_rebuild.py` from fixed rules (a longest
side and a yaw per model). When those rules get a ship wrong, the quickest fix is
to look at it and turn it by hand — so this puts the three *exported* ships in one
Blender scene next to things that say what "right" is, and
`read_fleet_adjust.py` reads the result back into the export rules.

    "<blender>/blender.exe" --background --factory-startup \
        --python blender/make_fleet_adjust.py

What is in the scene
--------------------
* Each ship hangs under an Empty named `alien_ship`, `alien_ship_2`, `alien_ship_3`
  (scout saucer, gunship, heavy cruiser). **The Empty is the handle**: select it,
  then rotate (R) and scale (S) it. Do not apply the transform (Ctrl+A) and do not
  edit the mesh — the reader works from the Empty's rotation and scale.
* Blender units are Godot metres. Blender -Y is Godot +Z, which is the direction
  every ship flies (toward the camera and the station). So **a ship's nose should
  point down the green FLIGHT arrow, along -Y**.
* The orange wire box on each ship is the hit box (1.93 x 1.87 x 1.15). It is one
  shape shared by every hull, so a ship that pokes out of it is hit before it
  looks hit, and one far inside it gets hit by shots that look like misses.
* The grey turret is at its real size and height, for scale: that is what the
  player is shooting from. The 1 m cube is a ruler.
"""

import math
import os

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALIEN_DIR = os.path.join(ROOT, "assets", "object", "alien")
TURRET_DIR = os.path.join(ROOT, "assets", "object", "turret")
OUT = os.path.join(ROOT, "temp", "alien_fleet_adjust.blend")

SHIPS = [
    ("alien_ship", "alien_ship.glb", "scout saucer"),
    ("alien_ship_2", "alien_ship_2.glb", "gunship"),
    ("alien_ship_3", "alien_ship_3.glb", "heavy cruiser"),
]

# Godot (x, y, z) = (1.93, 1.15, 1.87) from AlienShip.tscn; Blender is z-up, and
# depth is Blender y.
HITBOX = (1.93, 1.87, 1.15)
SPACING = 5.0

EMPTY_NAMES = {}


def _new_material(name, colour, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour
    if emission:
        bsdf.inputs["Emission Color"].default_value = colour
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = colour
    return mat


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def _wire_box(name, size, location, colour):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    box = bpy.context.view_layer.objects.active
    box.name = name
    box.scale = size
    box.display_type = "WIRE"
    box.color = colour
    box.hide_select = True  # a reference, not something to nudge by accident
    box.hide_render = True  # wire in the viewport; renders would draw it solid
    return box


def _arrow(name, start, length, colour):
    """A flat arrow along -Y: the way a ship must face."""
    bpy.ops.mesh.primitive_cylinder_add(
        radius=0.04, depth=length, location=(start.x, start.y - length / 2, start.z)
    )
    shaft = bpy.context.view_layer.objects.active
    shaft.rotation_euler = (math.radians(90), 0, 0)
    shaft.name = name + "_shaft"
    bpy.ops.mesh.primitive_cone_add(
        radius1=0.14, depth=0.35, location=(start.x, start.y - length - 0.17, start.z)
    )
    head = bpy.context.view_layer.objects.active
    head.rotation_euler = (math.radians(90), 0, 0)
    head.name = name + "_head"
    mat = _new_material(name, colour, 2.0)
    for o in (shaft, head):
        o.data.materials.append(mat)
        o.color = colour
        o.hide_select = True


def _label(text, location, size=0.28, colour=(1, 1, 1, 1)):
    bpy.ops.object.text_add(location=location, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.view_layer.objects.active
    obj.data.body = text
    obj.data.size = size
    obj.name = "LABEL " + text
    obj.color = colour
    obj.data.materials.append(_new_material("label", colour, 1.0))
    obj.hide_select = True
    return obj


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"

    for i, (name, fname, title) in enumerate(SHIPS):
        x = (i - 1) * SPACING
        objs = _import(os.path.join(ALIEN_DIR, fname))
        handle = bpy.data.objects.new(name, None)
        handle.empty_display_type = "ARROWS"
        handle.empty_display_size = 1.2
        handle.location = (x, 0, 1.4)
        scene.collection.objects.link(handle)
        for o in objs:
            if o.parent is None:
                o.parent = handle
                o.matrix_parent_inverse = Matrix.Identity(4)
        # Ships are exported centred on their own bounds, so the handle sits at
        # the ship's centre and the hit box centres on it.
        _wire_box("REF hit box %s" % name, HITBOX, (x, 0, 1.4), (1.0, 0.55, 0.1, 1.0))
        _arrow("FLIGHT %s" % name, Vector((x, -1.4, 1.4)), 1.4, (0.1, 1.0, 0.3, 1.0))
        _label("%s  (%s)" % (name, title), (x - 1.6, 0.0, 3.3))

    # The turret at real size, to the side. Gun sits on the base at the height
    # Turret.tscn puts its pivot (the gun's origin is its pivot), barrel on +Y
    # because the player shoots away from the camera.
    tx = 2 * SPACING
    base = _import(os.path.join(TURRET_DIR, "turret_base.glb"))
    gun = _import(os.path.join(TURRET_DIR, "turret_gun.glb"))
    for o in base:
        if o.parent is None:
            o.location.x += tx
    for o in gun:
        if o.parent is None:
            o.location = (tx, 0, 1.395)
    _label("turret (real size)", (tx - 1.4, 0.0, 3.3))

    _wire_box("REF 1 m cube", (1, 1, 1), (-2 * SPACING, 0, 0.5), (0.8, 0.8, 0.8, 1.0))
    _label("1 m cube", (-2 * SPACING - 0.8, 0.0, 1.8))

    # A ground line so "up" and the floor are obvious.
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0))
    floor = bpy.context.view_layer.objects.active
    floor.name = "REF floor"
    floor.scale = (30, 8, 1)
    floor.display_type = "WIRE"
    floor.hide_select = True
    floor.hide_render = True

    # A camera looking at the lineup from the front (the side ships fly toward).
    cam_data = bpy.data.cameras.new("front")
    cam = bpy.data.objects.new("front view", cam_data)
    cam.location = (0, -22, 3.5)
    cam.rotation_euler = (math.radians(86), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("saved", OUT)


if __name__ == "__main__":
    build()
