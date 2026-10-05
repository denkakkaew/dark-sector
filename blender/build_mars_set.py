"""
Dark Sector — build Mars' terrain: ground and mesas, sandstone ledges, rocks, solar
panels.

The colony and the drilling rig come from generated models via `export_rebuild.py`;
the ground they stand on, the rock around them and the thin solar panels (which a
generator would melt) are built here, procedurally, and written to
`assets/object/mars/`:

    mars_ground.glb       rust-red sand, gentle dunes, flat-topped mesas, low far hills
    mars_ledges.glb       layered sandstone slabs, framing the corners
    mars_rocks.glb        small rust boulders scattered over the ground
    mars_solar_panel.glb  one panel on a stand (the scene places several)

It reuses the Moon's terrain tools (`build_moon_set.py`: noise, the tiled surface
texture, the height-field-to-mesh builder); what differs is the shape — dunes and
mesas instead of craters and a ridge — and the colour. `mars_layout.py` holds where
everything goes.

    "<blender>/blender.exe" --background --factory-startup \
        --python blender/build_mars_set.py [-- ground ledges rocks solar]
"""

import importlib.util
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "object", "mars")


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


M = _load("build_moon_set")  # the shared terrain tools
L = _load("mars_layout")

g2b = M.g2b

X_HALF = 345.0
Z_NEAR = 22.0
Z_FAR = -300.0
COLS = 230
ROWS = 210
TILE = 12.0
TRI_BUDGET = 60000

# Surface colour: rust, before the vertex shading multiplies it.
SAND_BASE = 0.5
SAND_TINT = (1.0, 0.58, 0.36)
SAND_CONTRAST = 1.9


# --- ground -----------------------------------------------------------------


def _mesa(x, z, cx, cz, radius, height, seed):
    """A flat-topped butte: a plateau with steep, ragged sides and stepped strata."""
    ang = np.arctan2(z - cz, x - cx)
    n = M.ValueNoise(seed, 64)
    ragged = 1.0 + 0.28 * (n(np.cos(ang) * 2.5 + 5, np.sin(ang) * 2.5 + 5) - 0.5) * 2
    d = np.hypot(x - cx, z - cz) / (radius * ragged)
    # Steep skirt from d=0.72 (rim of the top) to d=1.08 (foot).
    t = np.clip((1.08 - d) / 0.36, 0.0, 1.0)
    profile = M._smooth(t) ** 0.85
    h = height * profile
    # Strata: pull heights toward 3 m steps, so the sides read as layered rock.
    step = 3.0
    stepped = np.floor(h / step) * step + M._smooth((h / step) % 1.0) * step
    return np.where(profile > 0.0, 0.55 * h + 0.45 * stepped, 0.0), profile


def height(x, z, noises):
    """Ground height at arrays of (x, z), and a mesa mask (0-1) for the colouring."""
    # Gentle dunes: broad swells plus fine ripples.
    h = (M.fbm(noises, x + 300, z + 300, 1 / 85.0) - 0.5) * 5.0
    h = h + (M.fbm(noises, x + 50, z + 700, 1 / 11.0) - 0.5) * 0.7
    # A few small, shallow craters: Mars has them, the painting hardly.
    rng = np.random.default_rng(4)
    for _ in range(40):
        cx, cz = rng.uniform(-X_HALF, X_HALF), Z_NEAR - (Z_NEAR - Z_FAR) * rng.random() ** 1.4
        r = rng.uniform(5, 26)
        if math.hypot(cx, cz - L.TURRET_Z) < 40 + r:
            continue
        d = np.hypot(x - cx, z - cz) / r
        h = h + np.where(d < 1.0, -0.12 * r * (1 - d * d) ** 1.4, 0.0) + 0.04 * r * np.exp(-(((d - 1.08) / 0.22) ** 2))

    # Low far hills, so the horizon isn't a ruled line between mesas.
    band = np.exp(-(((z - L.HILLS_Z) / L.HILLS_WIDTH) ** 2))
    hills = 1.0 - np.abs(M.fbm(noises, x + 90, z + 500, 1 / 60.0) * 2 - 1)
    h = h + band * L.HILLS_HEIGHT * hills ** 1.4

    mask = np.zeros_like(h)
    for i, (cx, cz, r, ht) in enumerate(L.MESAS):
        mh, prof = _mesa(x, z, cx, cz, r, ht, 40 + i)
        h = h + mh
        mask = np.maximum(mask, prof)

    # Flat round the player and gentle across the whole spawn zone.
    flat = np.clip((np.hypot(x, z - L.TURRET_Z) - 18.0) / 52.0, 0.0, 1.0)
    return h * M._smooth(flat), mask


def build_ground():
    noises = [M.ValueNoise(s) for s in (11, 12, 13, 14, 15)]
    t = np.linspace(0.0, 1.0, ROWS)
    zs = Z_NEAR + (Z_FAR - Z_NEAR) * t ** 1.45
    xs = np.linspace(-X_HALF, X_HALF, COLS)
    X, Z = np.meshgrid(xs, zs)
    H, mask = height(X, Z, noises)

    # Colour: dune hollows darker, crests lighter, mesa sides in warm bands.
    gz, gx = np.gradient(H, zs, xs)
    slope = np.hypot(gx, gz)
    cavity = np.zeros_like(H)
    local_mean = (H[:-2:, :] + H[2::, :]) / 2
    cavity[1:-1] = np.clip((H[1:-1] - local_mean) * 0.5, -0.25, 0.25)
    base = 1.0 + cavity - np.clip(slope * 0.35, 0, 0.3)
    band = 0.5 + 0.5 * np.sin(H * 1.7)
    tone_a = np.array([1.12, 0.88, 0.72])  # pale sandstone
    tone_b = np.array([0.82, 0.58, 0.46])  # dark iron-stained layer
    strata = tone_b[None, None, :] * (1 - band[..., None]) + tone_a[None, None, :] * band[..., None]
    plain = np.ones(H.shape + (3,))
    # Broad patches of paler dust and darker iron-rich ground, so a flat plain is
    # not one orange.
    patch = M.fbm(noises, X + 800, Z + 200, 1 / 38.0) - 0.5
    tint = np.stack([1.0 + 0.3 * patch, 1.0 + 0.1 * patch, 1.0 - 0.45 * patch], axis=-1)
    colour = (plain * (1 - mask[..., None]) + strata * mask[..., None]) * base[..., None] * tint
    colour = np.clip(colour, 0.3, 1.3)

    image = M._make_image("sand", M._regolith_texture(1024, 6, SAND_BASE, SAND_TINT, SAND_CONTRAST))
    obj = M.terrain_from_heights(X, Z, H, colour, image, "MarsGround", TILE, TRI_BUDGET)
    return obj, (noises,)


# --- ledges and rocks -------------------------------------------------------


# Layer colours, bottom to top and round again: pale sandstone, rust, iron brown.
LEDGE_TONES = [(1.05, 0.8, 0.62), (0.9, 0.52, 0.36), (0.6, 0.4, 0.32), (1.0, 0.72, 0.52)]


def _ledge_template(rng, name):
    """A layered sandstone outcrop: three to five flat slabs stacked and each a
    little smaller and off-centre from the one below, so the side reads as strata
    with a ledge at every layer. Heights are in units of 1; the placement scales
    the whole thing to its radius and height."""
    layers = int(rng.integers(3, 6))
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    nz = M.ValueNoise(int(rng.integers(0, 10 ** 6)), 64)
    color_layer = bm.verts.layers.float_color.new("Col")
    thickness = 1.0 / layers
    ox = oy = 0.0
    for i in range(layers):
        slab = bmesh.new()
        bmesh.ops.create_icosphere(slab, subdivisions=2, radius=1.0)
        radius = 1.0 - 0.17 * i + rng.uniform(-0.05, 0.05)
        sx, sy = rng.uniform(0.9, 1.2), rng.uniform(0.85, 1.15)
        tone = LEDGE_TONES[(i + int(rng.integers(0, 4))) % len(LEDGE_TONES)]
        for v in slab.verts:
            p = v.co
            n = 0.6 * nz(np.array(p.x * 2.0 + i * 7), np.array(p.y * 2.0 + 3)) + 0.4 * nz(np.array(p.x * 5.0 + i), np.array(p.y * 5.0 + 9))
            k = (0.82 + 0.4 * float(n)) * radius
            # A slab: a flat-topped, steep-sided disc, not a ball.
            side = 1.0 if abs(p.z) < 0.55 else 0.86
            z = max(min(p.z, 0.75), -0.75)
            v.co = Vector((ox + p.x * k * sx * side, oy + p.y * k * sy * side, i * thickness + (z * 0.5 + 0.5) * thickness * 0.98))
        new_verts = {}
        for v in slab.verts:
            new_verts[v] = bm.verts.new(v.co)
        for f in slab.faces:
            bm.faces.new([new_verts[v] for v in f.verts])
        shade = rng.uniform(0.88, 1.08)
        for v in new_verts.values():
            v[color_layer] = (tone[0] * shade, tone[1] * shade, tone[2] * shade, 1.0)
        slab.free()
        ox += rng.uniform(-0.12, 0.12)
        oy += rng.uniform(-0.12, 0.12)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return mesh


def build_ledges(noises):
    rng = np.random.default_rng(31)
    templates = [_ledge_template(rng, "ledge%d" % i) for i in range(5)]
    image = M._make_image("sand_ledge", M._regolith_texture(512, 8, SAND_BASE, SAND_TINT, SAND_CONTRAST))
    mat = M._ground_material(image)

    placements = list(L.hand_placed_ledges())
    # A scatter of mid-distance slabs, bigger the further out.
    attempts = 0
    while len(placements) < 46 and attempts < 4000:
        attempts += 1
        x = rng.uniform(-170, 170)
        z = -30 - 160 * rng.random() ** 1.1
        if L.blocked(x, z, margin=4.0):
            continue
        r = rng.uniform(2.0, 4.5) + abs(z) * 0.03
        placements.append((float(x), float(z), r, r * rng.uniform(0.45, 0.65)))

    objs = []
    for i, (x, z, r, hgt) in enumerate(placements):
        h = float(height(np.array([x]), np.array([z]), noises)[0][0])
        mesh = templates[i % len(templates)].copy()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new("ledge%d" % i, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = g2b(x, h - 0.15, z)
        obj.rotation_euler = (0, 0, rng.uniform(0, math.tau))
        # Radius sets the footprint; height is its own number, so a slab stays a slab.
        # 1.6: a slab's layers read better chunky than pancake-flat.
        obj.scale = (r, r * rng.uniform(0.85, 1.15), hgt * 1.6)
        objs.append(obj)

    return _join_with_uv(objs, "MarsLedges")


def build_rocks(noises):
    rng = np.random.default_rng(37)
    big = [M._rock_template(rng, "big%d" % i, 3) for i in range(4)]
    small = [M._rock_template(rng, "small%d" % i, 1) for i in range(4)]
    image = M._make_image("sand_rock", M._regolith_texture(512, 10, 0.4, (1.0, 0.52, 0.32), SAND_CONTRAST))
    mat = M._ground_material(image)

    placements = []
    attempts = 0
    while len(placements) < 260 and attempts < 7000:
        attempts += 1
        x = rng.uniform(-190, 190)
        z = Z_NEAR - (Z_NEAR + 170) * rng.random() ** 1.25
        if L.blocked(x, z, margin=2.0):
            continue
        placements.append((float(x), float(z), 0.15 + 1.5 * rng.random() ** 4.0))

    objs = []
    for i, (x, z, r) in enumerate(placements):
        h = float(height(np.array([x]), np.array([z]), noises)[0][0])
        pool = big if r > 0.6 else small
        mesh = pool[i % len(pool)].copy()
        tone = rng.uniform(0.6, 1.05)
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in range(len(mesh.vertices)):
            attr.data[v].color = (tone, tone * 0.82, tone * 0.7, 1.0)
        for poly in mesh.polygons:
            poly.use_smooth = r > 0.6
        mesh.materials.append(mat)
        obj = bpy.data.objects.new("rock%d" % i, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = g2b(x, h - 0.1 * r, z)
        obj.rotation_euler = (0, 0, rng.uniform(0, math.tau))
        obj.scale = (r, r * rng.uniform(0.8, 1.2), r * rng.uniform(0.7, 1.0))
        objs.append(obj)
    return _join_with_uv(objs, "MarsRocks")


def _join_with_uv(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    me = joined.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            p = me.vertices[vi].co
            uv.data[li].uv = ((p.x + p.z * 0.5) / TILE, (p.y + p.z * 0.5) / TILE)
    return joined


# --- solar panel ------------------------------------------------------------


def _cells(n=128):
    """Dark blue photovoltaic cells in a white grid."""
    img = np.zeros((n, n, 4), dtype=np.float32)
    img[..., 3] = 1.0
    img[..., :3] = (0.05, 0.1, 0.28)
    cell = n // 4
    rng = np.random.default_rng(2)
    for cy in range(4):
        for cx in range(4):
            img[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell, :3] *= rng.uniform(0.85, 1.2)
    for i in range(0, n, cell):
        img[i:i + 2, :, :3] = (0.75, 0.78, 0.85)
        img[:, i:i + 2, :3] = (0.75, 0.78, 0.85)
    return img


def build_solar_panel():
    """One 6 m panel on a stand, tilted toward the sun, standing on its bottom."""
    white = M._dark("PanelFrame", (0.7, 0.72, 0.76, 1.0), 0.5)
    cells = bpy.data.materials.new("PanelCells")
    cells.use_nodes = True
    nt = cells.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.3
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = M._make_image("pv", _cells())
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])

    parts = []
    # post and tilted panel
    parts.append(M._add("primitive_cylinder_add", white, vertices=8, radius=0.12, depth=1.6, location=(0, 0, 0.8)))
    panel = M._add("primitive_cube_add", cells, size=1.0, location=(0, 0, 1.9))
    panel.scale = (6.0, 0.08, 3.6)
    panel.rotation_euler = (math.radians(-38), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    me = panel.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            p = me.vertices[vi].co
            uv.data[li].uv = (p.x / 1.5, p.z / 1.5)
    parts.append(panel)
    frame = M._add("primitive_cube_add", white, size=1.0, location=(0, 0.02, 1.9))
    frame.scale = (6.1, 0.05, 3.7)
    frame.rotation_euler = (math.radians(-38), 0, 0)
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    parts.append(frame)
    return M._join(parts, "MarsSolarPanel")


# --- export -----------------------------------------------------------------


def _export(obj, filename):
    M.OUT = OUT
    M._export(obj, filename)


def main(names):
    names = names or ["ground", "ledges", "rocks", "solar"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    noises = None
    if set(names) & {"ground", "ledges", "rocks"}:
        ground, (noises,) = build_ground()
        if "ground" in names:
            _export(ground, "mars_ground.glb")
    if "ledges" in names:
        _export(build_ledges(noises), "mars_ledges.glb")
    if "rocks" in names:
        _export(build_rocks(noises), "mars_rocks.glb")
    if "solar" in names:
        _export(build_solar_panel(), "mars_solar_panel.glb")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
