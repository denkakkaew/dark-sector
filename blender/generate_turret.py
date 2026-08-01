"""
Dark Sector — procedural low-poly defense turret generator.

Modelled from the storyboard art in `planning/`:
  - "1. Title Splash screen.png"  (3/4 side view, lower right)
  - "4a. Hit destruction moment (beat, not a separate screen)2.png" (rear view)

Art direction taken from those frames: a chunky, friendly cartoon cannon —
white/light-grey hull with dark grey mechanical parts, warm AMBER/ORANGE
accents (side trunnion caps, base rim, muzzle glow), a glowing CYAN power
core on the rear face and a small cyan screen on top, and one thick barrel
with a brass/copper band near the muzzle. Not a sphere-dome turret.

Parts are separated and parented so the pedestal rotates (yaw) and the
barrel assembly pivots on the trunnion axis (pitch) for aiming.

How to run:
  - In Blender: Scripting tab -> open this file -> Run Script.
  - Headless:   blender --background --python blender/generate_turret.py
                (add -- --export to also write turret.glb next to this file)

Orientation: forward is -Y in Blender. On glTF import into Godot (Y-up, -Z
forward) the turret faces forward as expected; verify and rotate the root if
needed.
"""

import bpy
import sys
import os
import math
from mathutils import Vector

# ---------------------------------------------------------------------------
# 0. Config
# ---------------------------------------------------------------------------
EXPORT_GLB = "--export" in sys.argv  # pass `-- --export` in headless mode
FORWARD = Vector((0.0, -1.0, 0.0))   # game "forward"

# Palette (linear RGB, sampled from the storyboard frames)
COL_HULL     = (0.88, 0.90, 0.92, 1.0)   # white / light grey main hull
COL_HULL_DK  = (0.22, 0.24, 0.28, 1.0)   # dark grey panels, collar, scope
COL_ACCENT   = (1.00, 0.48, 0.05, 1.0)   # amber/orange accent (emissive)
COL_CORE     = (0.10, 0.70, 1.00, 1.0)   # cyan power core / screen (emissive)
COL_BRASS    = (0.85, 0.60, 0.20, 1.0)   # copper/brass muzzle band


# ---------------------------------------------------------------------------
# 1. Clean up: delete existing meshes / empties
# ---------------------------------------------------------------------------
def clear_scene():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.data.objects):
        if obj.type in {"MESH", "EMPTY"}:
            obj.select_set(True)
    bpy.ops.object.delete()
    # purge orphaned meshes/materials so re-runs stay clean
    for block in (bpy.data.meshes, bpy.data.materials):
        for datum in list(block):
            if datum.users == 0:
                block.remove(datum)


# ---------------------------------------------------------------------------
# 2. Materials
# ---------------------------------------------------------------------------
def make_material(name, base_color, emission=None, emission_strength=4.0,
                  roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        # Blender 4.x uses "Emission Color"; older uses "Emission"
        emit_key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[emit_key].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def build_materials():
    return {
        "hull":    make_material("Hull",      COL_HULL,    roughness=0.42, metallic=0.05),
        "hull_dk": make_material("HullDark",  COL_HULL_DK, roughness=0.55, metallic=0.25),
        "accent":  make_material("Accent",    COL_ACCENT,  emission=COL_ACCENT,
                                 emission_strength=5.0, roughness=0.3),
        "core":    make_material("PowerCore", COL_CORE,    emission=COL_CORE,
                                 emission_strength=6.0, roughness=0.2),
        "brass":   make_material("Brass",     COL_BRASS,   roughness=0.32, metallic=0.85),
    }


# ---------------------------------------------------------------------------
# 3. Helpers
# ---------------------------------------------------------------------------
# Axis alignment for primitives (they are created along local +Z).
ROT_Y_AXIS = (math.radians(90), 0, 0)   # depth runs along world Y (barrel)
ROT_X_AXIS = (0, math.radians(90), 0)   # depth runs along world X (trunnions)


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def smooth(obj, angle=35.0):
    """Round off curved surfaces but keep hard edges crisp (chunky look)."""
    try:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except (AttributeError, RuntimeError):
        # Older Blender: fall back to the legacy auto-smooth flags
        for poly in obj.data.polygons:
            poly.use_smooth = True
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(angle)


def bevel(obj, width=0.06, segments=2):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_add(type="BEVEL")
    mod = obj.modifiers["Bevel"]
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier="Bevel")


def cylinder(name, radius, depth, location, rotation=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def box(name, size, location, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def torus(name, major, minor, location, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=24, minor_segments=8,
                                     location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def new_empty(name, location):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.4
    e.location = location
    bpy.context.collection.objects.link(e)
    return e


# ---------------------------------------------------------------------------
# 4. Build the turret
# ---------------------------------------------------------------------------
# Height of the trunnion (pitch) axis above the deck — the barrel pivots here.
PITCH_Z = 1.15
PITCH_Y = -0.10


def build_base(mats):
    """Stepped armored foot bolted to the deck + glowing amber rim."""
    parts = []

    foot = cylinder("TurretFoot", radius=1.18, depth=0.26, location=(0, 0, 0.13))
    bevel(foot, width=0.07)
    assign(foot, mats["hull_dk"])
    smooth(foot)
    parts.append(foot)

    step = cylinder("TurretBase", radius=0.98, depth=0.30, location=(0, 0, 0.40))
    bevel(step, width=0.08)
    assign(step, mats["hull"])
    smooth(step)
    parts.append(step)

    rim = torus("BaseAccentRing", major=0.99, minor=0.05, location=(0, 0, 0.52))
    assign(rim, mats["accent"])
    smooth(rim)
    parts.append(rim)

    return step, parts


def build_yaw_assembly(mats):
    """Rotating pedestal + boxy cannon housing, trunnions, core and screen."""
    parts = []

    pedestal = cylinder("YawPedestal", radius=0.80, depth=0.34, location=(0, 0, 0.72))
    bevel(pedestal, width=0.07)
    assign(pedestal, mats["hull"])
    smooth(pedestal)
    parts.append(pedestal)

    # Main boxy housing — the chunky body seen in both reference frames.
    housing = box("Housing", size=(1.02, 1.16, 0.86), location=(0, 0.02, PITCH_Z))
    bevel(housing, width=0.10, segments=3)
    assign(housing, mats["hull"])
    smooth(housing, angle=30.0)
    parts.append(housing)

    # Dark vent/slat panel on the rear face.
    vent = box("VentPanel", size=(0.62, 0.06, 0.44), location=(0, 0.60, PITCH_Z + 0.06))
    assign(vent, mats["hull_dk"])
    parts.append(vent)

    # Glowing cyan power core on the rear face (the blue disc in the HUD shot).
    core = cylinder("PowerCore", radius=0.20, depth=0.10, verts=20,
                    location=(0, 0.63, PITCH_Z - 0.12), rotation=ROT_Y_AXIS)
    assign(core, mats["core"])
    smooth(core)
    parts.append(core)

    # Small cyan status screen on the top deck of the housing.
    screen = box("TopScreen", size=(0.44, 0.32, 0.05), location=(0, -0.16, PITCH_Z + 0.45))
    assign(screen, mats["core"])
    parts.append(screen)

    # Side trunnions with amber glowing caps (the orange discs in the art).
    for side, x in (("L", -1.0), ("R", 1.0)):
        hub = cylinder("Trunnion_" + side, radius=0.34, depth=0.28, verts=20,
                       location=(x * 0.60, PITCH_Y, PITCH_Z), rotation=ROT_X_AXIS)
        assign(hub, mats["hull_dk"])
        smooth(hub)
        parts.append(hub)

        cap = cylinder("TrunnionCap_" + side, radius=0.23, depth=0.12, verts=20,
                       location=(x * 0.76, PITCH_Y, PITCH_Z), rotation=ROT_X_AXIS)
        assign(cap, mats["accent"])
        smooth(cap)
        parts.append(cap)

    return pedestal, parts


def build_barrel(mats):
    """Single thick barrel with dark collar, brass band and amber muzzle glow."""
    parts = []

    collar = cylinder("BarrelCollar", radius=0.31, depth=0.40, verts=20,
                      location=(0, PITCH_Y - 0.45, PITCH_Z), rotation=ROT_Y_AXIS)
    bevel(collar, width=0.04)
    assign(collar, mats["hull_dk"])
    smooth(collar)
    parts.append(collar)

    tube = cylinder("Barrel", radius=0.21, depth=1.40, verts=20,
                    location=(0, PITCH_Y - 1.30, PITCH_Z), rotation=ROT_Y_AXIS)
    assign(tube, mats["hull"])
    smooth(tube)
    parts.append(tube)

    band = cylinder("MuzzleBand", radius=0.25, depth=0.24, verts=20,
                    location=(0, PITCH_Y - 1.88, PITCH_Z), rotation=ROT_Y_AXIS)
    bevel(band, width=0.03)
    assign(band, mats["brass"])
    smooth(band)
    parts.append(band)

    tip = cylinder("MuzzleTip", radius=0.22, depth=0.16, verts=20,
                   location=(0, PITCH_Y - 2.06, PITCH_Z), rotation=ROT_Y_AXIS)
    assign(tip, mats["hull_dk"])
    smooth(tip)
    parts.append(tip)

    glow = torus("MuzzleGlow", major=0.20, minor=0.04,
                 location=(0, PITCH_Y - 2.14, PITCH_Z), rotation=ROT_Y_AXIS)
    assign(glow, mats["accent"])
    smooth(glow)
    parts.append(glow)

    # Small sight/scope block riding on top of the barrel.
    scope = box("Scope", size=(0.16, 0.46, 0.14), location=(0, PITCH_Y - 0.80, PITCH_Z + 0.26))
    bevel(scope, width=0.03)
    assign(scope, mats["hull_dk"])
    parts.append(scope)

    return parts


# ---------------------------------------------------------------------------
# 5. Parent for aim rig: base <- pedestal(+housing) <- pitch pivot <- barrel
# ---------------------------------------------------------------------------
def set_parent(child, parent):
    # Flush pending transforms first: a freshly created object (especially an
    # empty made via bpy.data.objects.new) still has an identity matrix_world
    # until the depsgraph updates, which would double-apply its offset here.
    bpy.context.view_layer.update()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def rig(base, base_parts, pedestal, yaw_parts, barrel_parts):
    for obj in base_parts:
        if obj is not base:
            set_parent(obj, base)

    set_parent(pedestal, base)
    for obj in yaw_parts:
        if obj is not pedestal:
            set_parent(obj, pedestal)

    pitch_pivot = new_empty("PitchPivot", (0, PITCH_Y, PITCH_Z))
    set_parent(pitch_pivot, pedestal)
    for obj in barrel_parts:
        set_parent(obj, pitch_pivot)

    return pitch_pivot


# ---------------------------------------------------------------------------
# 6. Main
# ---------------------------------------------------------------------------
def main():
    clear_scene()
    mats = build_materials()

    base, base_parts = build_base(mats)
    pedestal, yaw_parts = build_yaw_assembly(mats)
    barrel_parts = build_barrel(mats)
    rig(base, base_parts, pedestal, yaw_parts, barrel_parts)

    total = len(base_parts) + len(yaw_parts) + len(barrel_parts)
    bpy.ops.object.select_all(action="DESELECT")
    base.select_set(True)
    bpy.context.view_layer.objects.active = base
    print("[Dark Sector] Turret built: %d parts." % total)

    if EXPORT_GLB:
        here = os.path.dirname(bpy.data.filepath) or os.path.dirname(
            os.path.abspath(globals().get("__file__", "turret.py")))
        out = os.path.join(here, "turret.glb")
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB",
                                  use_selection=True)
        print("[Dark Sector] Exported: %s" % out)


if __name__ == "__main__":
    main()
