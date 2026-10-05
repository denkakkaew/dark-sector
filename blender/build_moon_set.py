"""
Dark Sector — build the Moon's terrain: ground, horizon ridge, rocks, pad, pipes.

The generated alien-base buildings come from `export_rebuild.py`; everything that
is ground, rock, or a thin run of tube — the parts an image-to-3D generator can't
make — is built here, procedurally, and written to `assets/object/moon/`:

    moon_terrain.glb   ground + horizon ridge, one mesh
    moon_rocks.glb     boulders scattered over the ground, one mesh
    moon_pad.glb       a landing pad with its light posts
    moon_pipes.glb     ribbed tubes joining the base's buildings

`moon_layout.py` holds where everything goes, in Godot metres, and is read by
this script (rocks avoid the buildings; pipes and pads go where it says) and by
`make_moon_set_scene.py`, which writes the .tscn that places the lot.

How to run (headless, from the repo root):

    "<blender>/blender.exe" --background --factory-startup \
        --python blender/build_moon_set.py [-- terrain rocks pad pipes]

Why the ground looks the way it does
------------------------------------
Two layers, because one can't do both jobs. The *shape* — craters, undulation, the
ridge on the horizon — is real geometry. The *surface* is a seamless regolith
texture tiled every 12 m, so it is sharp at a boot's distance and averages to flat
grey at a mountain's. Large-scale light and dark (crater floors, rims) is a vertex
colour multiplied over it. The painted backdrop it replaces had the same
properties and none of the parallax.

GL-Compatibility: nothing here needs more than a StandardMaterial3D.
"""

import importlib.util
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "object", "moon")

# --- layout -----------------------------------------------------------------


def _layout():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "moon_layout.py")
    spec = importlib.util.spec_from_file_location("moon_layout", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


L = _layout()


def g2b(x, y, z):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


# --- noise ------------------------------------------------------------------


def _smooth(t):
    return t * t * (3 - 2 * t)


class ValueNoise:
    """Periodic 2D value noise on a lattice, sampled with smooth interpolation."""

    def __init__(self, seed, size=256):
        self.size = size
        self.grid = np.random.default_rng(seed).random((size, size))

    def __call__(self, x, y):
        s = self.size
        xi = np.floor(x).astype(np.int64)
        yi = np.floor(y).astype(np.int64)
        fx = _smooth(x - xi)
        fy = _smooth(y - yi)
        x0, x1 = xi % s, (xi + 1) % s
        y0, y1 = yi % s, (yi + 1) % s
        g = self.grid
        a = g[y0, x0] * (1 - fx) + g[y0, x1] * fx
        b = g[y1, x0] * (1 - fx) + g[y1, x1] * fx
        return a * (1 - fy) + b * fy


def fbm(noise_list, x, y, freq, gain=0.5, lacunarity=2.0):
    total = 0.0
    amp = 1.0
    norm = 0.0
    for n in noise_list:
        total = total + amp * n(x * freq, y * freq)
        norm += amp
        amp *= gain
        freq *= lacunarity
    return total / norm


# --- terrain ----------------------------------------------------------------

# Ground extents in Godot metres. z runs from just behind the camera out to the
# far ridge; the sky plate hangs at 330, past the end of this.
X_HALF = 345.0
Z_NEAR = 22.0
Z_FAR = -300.0
COLS = 230
ROWS = 210
TILE_METRES = 12.0  # one repeat of the regolith texture
TRI_BUDGET = 60000


def _craters(rng):
    """(x, z, radius) for craters, many small and a few large, kept off the deck."""
    out = []
    for _ in range(520):
        r = 2.5 * (1.0 / (1.0 - rng.random() * 0.985)) ** 0.62  # power law, 2.5 .. ~90
        r = min(r, 85.0)
        x = rng.uniform(-X_HALF, X_HALF)
        # Denser near, since that is where the eye reads them.
        z = Z_NEAR - (Z_NEAR - Z_FAR) * rng.random() ** 1.5
        if math.hypot(x, z - L.TURRET_Z) < 22 + r:
            continue
        out.append((x, z, r))
    return out


def _height(x, z, craters, noises):
    """Ground height in metres at arrays of (x, z)."""
    # Gentle undulation: broad swells plus finer lumps.
    h = (fbm(noises, x + 500, z + 500, 1 / 90.0) - 0.5) * 7.0
    h = h + (fbm(noises, x + 100, z + 900, 1 / 14.0) - 0.5) * 1.1

    for cx, cz, r in craters:
        d = np.hypot(x - cx, z - cz) / r
        near = d < 1.6
        if not near.any():
            continue
        depth = min(0.2 * r, 7.0)
        rim = min(0.07 * r, 2.4)
        bowl = np.where(d < 1.0, -depth * (1.0 - d * d) ** 1.4, 0.0)
        lip = rim * np.exp(-(((d - 1.08) / 0.2) ** 2))
        h = h + bowl + lip

    # The ridge: a band of ridged noise across the far end, a bit taller on the
    # left, where the painting has its big mounds.
    ridged = 1.0 - np.abs(fbm(noises, x + 40, z + 700, 1 / 70.0) * 2 - 1)
    ridged = ridged ** 1.6
    band = np.exp(-(((z - L.RIDGE_Z) / L.RIDGE_WIDTH) ** 2))
    left = 1.0 + 0.7 * np.clip((-x - 40) / 160.0, 0, 1)
    h = h + band * left * (L.RIDGE_BASE + L.RIDGE_PEAK * ridged)

    # Flat where the player stands (the deck sits on y=0) and gentle across the
    # whole spawn zone: aliens appear ~36 m out at 1.5-6 m up, and a hill there
    # would swallow a ship as it spawns. Full relief only from ~70 m.
    flat = np.clip((np.hypot(x, z - L.TURRET_Z) - 18.0) / 52.0, 0.0, 1.0)
    return h * _smooth(flat)


def _regolith_texture(n=1024, seed=3, base=0.285, tint=(0.99, 0.99, 1.02), contrast=1.0):
    """A seamless grey regolith: layered noise, pits and pebbles. Periodic by
    construction (FFT filtered), so it tiles."""
    rng = np.random.default_rng(seed)

    def band(beta):
        f = np.fft.fftfreq(n)
        fx, fy = np.meshgrid(f, f)
        mag = np.hypot(fx, fy)
        mag[0, 0] = 1.0
        spectrum = np.fft.fft2(rng.standard_normal((n, n))) / mag ** (beta / 2)
        spectrum[0, 0] = 0
        out = np.real(np.fft.ifft2(spectrum))
        return (out - out.mean()) / out.std()

    coarse = band(2.4)
    mid = band(1.6)
    fine = band(0.6)
    v = base + contrast * (0.05 * coarse + 0.032 * mid + 0.028 * fine)

    # Pits and bright pebbles: sparse blobs.
    for _ in range(2600):
        x, y = rng.integers(0, n, 2)
        r = rng.integers(1, 4)
        yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
        mask = (xx * xx + yy * yy) <= r * r
        sign = 1.0 if rng.random() < 0.5 else -1.0
        ys = (np.arange(y - r, y + r + 1)) % n
        xs = (np.arange(x - r, x + r + 1)) % n
        v[np.ix_(ys, xs)] += sign * 0.06 * mask
    v = np.clip(v, 0.12, 0.8)
    img = np.stack([v * tint[0], v * tint[1], v * tint[2], np.ones_like(v)], axis=-1)
    return img


def _make_image(name, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.pixels = rgba.ravel().tolist()
    img.pack()
    return img


def _ground_material(image):
    mat = bpy.data.materials.new("MoonRegolith")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Smart"
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs[6])
    nt.links.new(col.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return mat


def terrain_from_heights(X, Z, H, shade, image, name="MoonTerrain", tile=TILE_METRES, budget=TRI_BUDGET):
    """Turn a height field into one mesh: world-planar UVs tiled every `tile`
    metres, `shade` as a vertex colour (rows x cols, grey, or rows x cols x 3), the
    texture multiplied by it, flat stretches decimated away.

    Shared with the other scenes' ground (`build_mars_set.py`)."""
    rows, cols = H.shape
    verts = [g2b(X[r, c], H[r, c], Z[r, c]) for r in range(rows) for c in range(cols)]
    faces = []
    for r in range(rows - 1):
        for c in range(cols - 1):
            i = r * cols + c
            # Counter-clockwise seen from above (Blender +Z).
            faces.append((i, i + cols, i + cols + 1, i + 1))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = True

    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            v = mesh.vertices[vi].co
            uv.data[li].uv = (v.x / tile, v.y / tile)

    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    flat = np.asarray(shade).reshape(rows * cols, -1)
    for i in range(len(mesh.vertices)):
        c = flat[i]
        rgb = (float(c[0]), float(c[0]), float(c[0])) if len(c) == 1 else (float(c[0]), float(c[1]), float(c[2]))
        attr.data[i].color = (rgb[0], rgb[1], rgb[2], 1.0)

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(_ground_material(image))

    # Decimate the flat stretches away, keep the relief.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    total = len(mesh.polygons)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.ratio = min(1.0, budget / (total * 2.0))  # quads are two tris each
    bpy.ops.object.modifier_apply(modifier="Decimate")
    return obj


def build_terrain():
    rng = np.random.default_rng(11)
    noises = [ValueNoise(s) for s in (1, 2, 3, 4, 5)]
    craters = _craters(rng)

    # Rows are spaced finer near the camera than far away.
    t = np.linspace(0.0, 1.0, ROWS)
    zs = Z_NEAR + (Z_FAR - Z_NEAR) * t ** 1.45
    xs = np.linspace(-X_HALF, X_HALF, COLS)
    X, Z = np.meshgrid(xs, zs)
    H = _height(X, Z, craters, noises)

    # Large-scale light and dark: crater floors darker, rims and ridges lighter,
    # steep faces a touch darker. A vertex colour, multiplied over the texture.
    gz, gx = np.gradient(H, zs, xs)
    slope = np.hypot(gx, gz)
    local_mean = (H[:-2:, :] + H[2::, :]) / 2  # coarse proxy for "the floor around"
    cavity = np.zeros_like(H)
    cavity[1:-1] = np.clip((H[1:-1] - local_mean) * 0.45, -0.35, 0.3)
    shade = 1.0 + cavity - np.clip(slope * 0.5, 0, 0.25)
    shade = shade + 0.08 * np.clip(H / 40.0, 0, 1)
    shade = np.clip(shade, 0.45, 1.15)

    obj = terrain_from_heights(X, Z, H, shade, _make_image("regolith", _regolith_texture()))
    return obj, (noises, craters)


# --- rocks ------------------------------------------------------------------


def _rock_template(rng, name, subdivisions=2):
    """A lumpy boulder: a displaced icosphere, squashed, with a flat-ish base."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    nz = ValueNoise(int(rng.integers(0, 10 ** 6)), 64)
    sx, sy, sz = rng.uniform(0.8, 1.3), rng.uniform(0.8, 1.3), rng.uniform(0.55, 0.9)
    for v in bm.verts:
        p = v.co
        # Two octaves, so a boulder has big lumps and smaller chips.
        n = 0.65 * nz(np.array(p.x * 1.7 + 9), np.array(p.y * 1.7 + p.z * 1.3 + 4))             + 0.35 * nz(np.array(p.x * 5.3 + 3), np.array(p.y * 5.3 + p.z * 4.1 + 8))
        k = 0.7 + 0.6 * float(n)
        v.co = Vector((p.x * k * sx, p.y * k * sy, p.z * k * sz))
    # Settle the underside onto the ground plane.
    low = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= low * 0.7
        if v.co.z < 0:
            v.co.z *= 0.35
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def build_rocks(noises, craters):
    rng = np.random.default_rng(23)
    big_templates = [_rock_template(rng, "big%d" % i, 3) for i in range(5)]
    small_templates = [_rock_template(rng, "small%d" % i, 1) for i in range(5)]
    mat = _ground_material(_make_image("regolith_rock", _regolith_texture(512, 9)))

    placements = []
    for x, z, r, big in L.hand_placed_rocks():
        placements.append((x, z, r))
    # A scatter: many small, a few boulders, thinning with distance.
    attempts = 0
    while len(placements) < 230 and attempts < 6000:
        attempts += 1
        x = rng.uniform(-190, 190)
        z = Z_NEAR - (Z_NEAR + 170) * rng.random() ** 1.25
        if L.blocked(x, z, margin=2.0):
            continue
        r = 0.18 + 2.0 * rng.random() ** 4.0
        placements.append((float(x), float(z), r))

    objs = []
    for i, (x, z, r) in enumerate(placements):
        h = float(_height(np.array([x]), np.array([z]), craters, noises)[0])
        pool = big_templates if r > 0.7 else small_templates
        mesh = pool[i % len(pool)].copy()
        # Each rock its own brightness, so a field of them isn't one grey.
        tone = rng.uniform(0.55, 1.0)
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for v in range(len(mesh.vertices)):
            attr.data[v].color = (tone, tone, tone * 1.02, 1.0)
        obj = bpy.data.objects.new("rock%d" % i, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = g2b(x, h - 0.1 * r, z)
        obj.rotation_euler = (0, 0, rng.uniform(0, math.tau))
        obj.scale = (r, r * rng.uniform(0.8, 1.2), r * rng.uniform(0.7, 1.05))
        if r > 0.7:
            for poly in mesh.polygons:
                poly.use_smooth = True
        mesh.materials.append(mat)
        objs.append(obj)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    rocks = bpy.context.view_layer.objects.active
    rocks.name = "MoonRocks"

    # Planar UVs over world position, same tiling as the ground.
    me = rocks.data
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            p = me.vertices[vi].co
            uv.data[li].uv = ((p.x + p.z * 0.5) / TILE_METRES, (p.y + p.z * 0.5) / TILE_METRES)
    return rocks


# --- pad and pipes ----------------------------------------------------------


def _emissive(name, colour, strength=3.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Emission Color"].default_value = colour
    bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _dark(name, colour=(0.03, 0.035, 0.04, 1.0), rough=0.6):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def _add(prim, mat, **kw):
    getattr(bpy.ops.mesh, prim)(**kw)
    obj = bpy.context.view_layer.objects.active
    obj.data.materials.append(mat)
    return obj


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    return out


def build_pad():
    """A round landing pad at the origin, ground level, with six light posts."""
    dark = _dark("PadDeck")
    trim = _dark("PadTrim", (0.07, 0.08, 0.09, 1.0))
    glow = _emissive("PadGlow", (0.25, 1.0, 0.85, 1.0), 4.0)
    R = L.PAD_RADIUS
    parts = [
        _add("primitive_cylinder_add", dark, vertices=64, radius=R, depth=0.3, location=(0, 0, 0.15)),
        _add("primitive_cylinder_add", trim, vertices=64, radius=R * 1.06, depth=0.18, location=(0, 0, 0.09)),
        _add("primitive_torus_add", glow, major_radius=R * 0.82, minor_radius=0.1,
             major_segments=64, minor_segments=8, location=(0, 0, 0.32)),
        _add("primitive_torus_add", glow, major_radius=R * 0.34, minor_radius=0.08,
             major_segments=48, minor_segments=8, location=(0, 0, 0.32)),
    ]
    for i in range(6):
        a = math.tau * i / 6
        x, y = math.cos(a) * R * 1.12, math.sin(a) * R * 1.12
        parts.append(_add("primitive_cylinder_add", trim, vertices=12, radius=0.12, depth=1.4,
                          location=(x, y, 0.7)))
        parts.append(_add("primitive_uv_sphere_add", glow, segments=12, ring_count=8, radius=0.22,
                          location=(x, y, 1.45)))
    return _join(parts, "MoonPad")


def build_pipes():
    """Ribbed tubes along the ground between the buildings in the layout."""
    dark = _dark("Pipe", (0.045, 0.05, 0.055, 1.0), 0.5)
    rib = _dark("PipeRib", (0.08, 0.09, 0.1, 1.0), 0.5)
    glow = _emissive("PipeGlow", (0.25, 1.0, 0.85, 1.0), 2.5)
    parts = []
    for (ax, az), (bx, bz) in L.PIPES:
        a = Vector(g2b(ax, L.PIPE_HEIGHT, az))
        b = Vector(g2b(bx, L.PIPE_HEIGHT, bz))
        d = b - a
        length = d.length
        mid = (a + b) / 2
        tube = _add("primitive_cylinder_add", dark, vertices=16, radius=L.PIPE_RADIUS, depth=length,
                    location=mid)
        tube.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        parts.append(tube)
        n = max(2, int(length / 3.2))
        for i in range(n + 1):
            p = a + d * (i / n)
            ring = _add("primitive_torus_add", rib, major_radius=L.PIPE_RADIUS * 1.02,
                        minor_radius=L.PIPE_RADIUS * 0.22, major_segments=16, minor_segments=6,
                        location=p)
            ring.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            parts.append(ring)
        # a thin light seam along the top
        seam = _add("primitive_cylinder_add", glow, vertices=6, radius=0.06, depth=length,
                    location=mid + Vector((0, 0, L.PIPE_RADIUS * 1.02)))
        seam.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        parts.append(seam)
    return _join(parts, "MoonPipes")


# --- export -----------------------------------------------------------------


def _export(obj, filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    kwargs = dict(
        filepath=os.path.join(OUT, filename),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_animations=False,
        export_extras=False,
    )
    # Vertex colours are what carries the ground's large-scale shading.
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    if "export_vertex_color" in props:
        kwargs["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kwargs)
    me = obj.data
    me.calc_loop_triangles()
    print("EXPORTED", filename, "tris", len(me.loop_triangles),
          "MB", round(os.path.getsize(os.path.join(OUT, filename)) / 1e6, 2))


def main(names):
    names = names or ["terrain", "rocks", "pad", "pipes"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    noises = craters = None
    if "terrain" in names or "rocks" in names:
        terrain, (noises, craters) = build_terrain()
        if "terrain" in names:
            _export(terrain, "moon_terrain.glb")
    if "rocks" in names:
        _export(build_rocks(noises, craters), "moon_rocks.glb")
    if "pad" in names:
        _export(build_pad(), "moon_pad.glb")
    if "pipes" in names:
        _export(build_pipes(), "moon_pipes.glb")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
