"""
Dark Sector — build the Earth scene's night city: street ground, filler buildings,
river, elevated roads and the bridge.

The landmark towers and mid-rise buildings come from generated models via
`export_rebuild.py`. What a generator can't make — a city's worth of buildings, a
river, light-trail roads, a bridge's cable fans — is built here, procedurally, and
written to `assets/object/earth/`:

    earth_ground.glb   the street plane: dark blocks with glowing street lines
    earth_city.glb     ~1300 filler buildings, one mesh, lit windows
    earth_river.glb    the river, a dark ribbon with scattered reflected light
    earth_roads.glb    elevated roads along both banks and the bridge approaches,
                       with headlight and tail-light trails
    earth_bridge.glb   a golden cable-stayed bridge, deck centred on the origin

    "<blender>/blender.exe" --background --factory-startup \\
        --python blender/build_earth_set.py [-- ground city river roads bridge]

How the lights are made
-----------------------
Nothing here is lit by a lamp: the glow is the material's own *emission*, from a
texture (a window atlas, a street grid, a lane of headlights). The walls themselves
are near-black, so what the player sees is a field of lit windows, not lit walls.
Each building's UVs are scaled by its own size, so a window is the same size on a
small block and a tower, and offset at random, so no two share a pattern.

The set is built with its ground at y=0; `earth_layout.SET_Y` hangs it below the
deck.
"""

import importlib.util
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "object", "earth")


def _layout():
    spec = importlib.util.spec_from_file_location("earth_layout", os.path.join(HERE, "earth_layout.py"))
    module = importlib.util.module_from_spec(spec)
    sys.modules["earth_layout"] = module
    spec.loader.exec_module(module)
    return module


L = _layout()


def g2b(x, y, z):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


# --- textures ---------------------------------------------------------------

# A window is this many metres; the atlas holds 8 x 8 of them.
WIN_W, WIN_H = 2.7, 3.1
ATLAS_CELLS = 8
ATLAS_METRES = (ATLAS_CELLS * WIN_W, ATLAS_CELLS * WIN_H)
STREET_TILE = 104.0


def _image(name, rgba):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.pixels = rgba.ravel().tolist()
    img.pack()
    return img


def window_atlas(n=256, seed=17):
    """8 x 8 windows, about half lit: warm, white or cool. The wall between them is
    near-black, so used as emission it is a field of lit windows."""
    rng = np.random.default_rng(seed)
    img = np.zeros((n, n, 4), dtype=np.float32)
    img[..., 3] = 1.0
    img[..., :3] = (0.012, 0.016, 0.034)
    cell = n // ATLAS_CELLS
    palette = [(1.0, 0.8, 0.42), (1.0, 0.9, 0.7), (0.9, 0.93, 1.0), (0.55, 0.78, 1.0)]
    weights = [0.5, 0.2, 0.18, 0.12]
    for cy in range(ATLAS_CELLS):
        for cx in range(ATLAS_CELLS):
            if rng.random() < 0.56:
                col = np.array(palette[rng.choice(len(palette), p=weights)]) * rng.uniform(0.7, 1.0)
                y0, x0 = cy * cell + cell // 5, cx * cell + cell // 6
                img[y0:y0 + cell * 3 // 5, x0:x0 + cell * 2 // 3, :3] = col
    # the corner pixel (0, 0) stays wall: roofs sample it
    img[0:4, 0:4, :3] = (0.012, 0.016, 0.034)
    return img


def street_texture(n=512, seed=5):
    """Dark blocks with glowing streets: a grid of amber lines, brighter at the
    junctions, and scattered lit dots for the windows seen from far above."""
    rng = np.random.default_rng(seed)
    img = np.zeros((n, n, 4), dtype=np.float32)
    img[..., 3] = 1.0
    img[..., :3] = (0.008, 0.01, 0.022)
    blocks = 4
    step = n // blocks
    for i in range(blocks):
        a = i * step
        img[a:a + 5, :, :3] = (0.55, 0.33, 0.12)
        img[:, a:a + 5, :3] = (0.5, 0.3, 0.11)
        for j in range(blocks):
            b = j * step
            img[a:a + 14, b:b + 14, :3] = (1.0, 0.8, 0.4)
    for _ in range(900):
        y, x = rng.integers(0, n, 2)
        img[y:y + 2, x:x + 2, :3] = np.array(window_color(rng)) * rng.uniform(0.5, 1.0)
    return img


def window_color(rng):
    palette = [(1.0, 0.8, 0.42), (1.0, 0.9, 0.7), (0.9, 0.93, 1.0), (0.55, 0.78, 1.0)]
    return palette[rng.choice(len(palette), p=[0.5, 0.2, 0.18, 0.12])]


def river_texture(n=256, seed=9):
    """Near-black water with scattered gold and white reflections and faint ripples."""
    rng = np.random.default_rng(seed)
    img = np.zeros((n, n, 4), dtype=np.float32)
    img[..., 3] = 1.0
    img[..., :3] = (0.004, 0.012, 0.035)
    ripple = 0.5 + 0.5 * np.sin(np.linspace(0, 40, n))[None, :]
    img[..., 2] += 0.01 * ripple
    for _ in range(260):
        y, x = rng.integers(0, n, 2)
        length = rng.integers(3, 14)
        col = np.array((1.0, 0.7, 0.3) if rng.random() < 0.7 else (0.7, 0.85, 1.0)) * rng.uniform(0.25, 0.8)
        img[y:y + length, x:x + 2, :3] = col  # vertical streaks: a reflected light
    return img


def road_texture(w=256, h=64):
    """A road seen from above: two lanes of light trails, warm one way, red the
    other, between amber edge lines on near-black."""
    img = np.zeros((h, w, 4), dtype=np.float32)
    img[..., 3] = 1.0
    img[..., :3] = (0.01, 0.012, 0.02)
    rng = np.random.default_rng(3)
    img[0:3, :, :3] = (0.9, 0.55, 0.2)
    img[h - 3:, :, :3] = (0.9, 0.55, 0.2)
    for lane, (y0, y1, col) in enumerate(((10, 26, (1.0, 0.85, 0.5)), (38, 54, (1.0, 0.18, 0.12)))):
        x = int(rng.integers(0, 20))
        while x < w:
            length = int(rng.integers(10, 34))
            gap = int(rng.integers(12, 40))
            img[y0 + 5:y1 - 5, x:x + length, :3] = np.array(col) * rng.uniform(0.7, 1.0)
            x += length + gap
    return img


# --- materials --------------------------------------------------------------


def emissive_material(name, image, strength, base=(0.012, 0.016, 0.034, 1.0), rough=0.9, metallic=0.0):
    """Near-black surface that glows with `image`."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = base
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metallic
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.extension = "REPEAT"
    nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    return mat


def glow_material(name, colour, strength, base=None):
    """Glows `colour`. `base` is the surface under the glow (default: the same
    colour); a dark base keeps the scene's lights from washing a dim glow out."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = base or colour
    b.inputs["Emission Color"].default_value = colour
    b.inputs["Emission Strength"].default_value = strength
    return mat


def plain_material(name, colour, rough=0.6):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = colour
    b.inputs["Roughness"].default_value = rough
    return mat


# --- mesh helper ------------------------------------------------------------


def mesh_from(name, quads, uvs, material):
    """quads: list of 4 (x, y, z) Godot-space points per face; uvs: matching 4 (u, v).
    Every face gets its own four vertices so each can carry its own UVs."""
    verts, faces, uv_list = [], [], []
    for quad, uv in zip(quads, uvs):
        base = len(verts)
        verts.extend(g2b(*p) for p in quad)
        faces.append((base, base + 1, base + 2, base + 3))
        uv_list.extend(uv)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for li, uv in enumerate(uv_list):
        layer.data[li].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


# --- ground -----------------------------------------------------------------


def build_ground():
    img = _image("streets", street_texture())
    mat = emissive_material("Streets", img, 0.42, base=(0.006, 0.008, 0.018, 1.0))
    x0, x1, z0, z1 = -3500.0, 3500.0, 220.0, -3800.0
    quad = [(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1)]
    # Counter-clockwise seen from above: Godot (x0,z0) -> (x1,z0) -> (x1,z1) is
    # clockwise looking down -Y in Blender terms, so reverse the order.
    quad = [quad[0], quad[3], quad[2], quad[1]]
    s = STREET_TILE
    uv = [((x - x0) / s, (z0 - z) / s) for x, _, z in quad]
    return mesh_from("EarthGround", [quad], [uv], mat)


# --- filler buildings -------------------------------------------------------


def _box_faces(cx, cz, w, d, h, y0, yaw, rng):
    """Five faces (four sides and the roof) of a box, in Godot space, with UVs that
    keep a window one size however big the building is."""
    c, s = math.cos(yaw), math.sin(yaw)

    def p(dx, dz, y):
        return (cx + dx * c - dz * s, y, cz + dx * s + dz * c)

    hw, hd = w / 2, d / 2
    corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]
    quads, uvs = [], []
    au, av = ATLAS_METRES
    off_u, off_v = rng.random(), rng.random()
    for i in range(4):
        (ax, az), (bx, bz) = corners[i], corners[(i + 1) % 4]
        length = math.hypot(bx - ax, bz - az)
        u0 = off_u + (i * 13.7) / au
        u1 = u0 + length / au
        v0, v1 = off_v, off_v + h / av
        # wound so the face looks outward (counter-clockwise from outside)
        quads.append([p(ax, az, y0), p(bx, bz, y0), p(bx, bz, y0 + h), p(ax, az, y0 + h)])
        uvs.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    roof = [p(-hw, -hd, y0 + h), p(-hw, hd, y0 + h), p(hw, hd, y0 + h), p(hw, -hd, y0 + h)]
    quads.append(roof)
    uvs.append([(0.004, 0.004)] * 4)
    return quads, uvs


def build_city():
    rng = np.random.default_rng(42)
    pts = L.river_points()
    mat = emissive_material("Windows", _image("windows", window_atlas()), 1.35)

    spacing = 26.0
    yaw = math.radians(14.0)
    cy, sy = math.cos(yaw), math.sin(yaw)
    quads, uvs = [], []
    dx0, dz0, drad = L.DOWNTOWN
    count = 0
    # Grid cells in a rotated frame, so the blocks are not aligned to the camera.
    for gz in range(int(20 / spacing) + 1, int(-L.CITY_FAR / spacing) + 20):
        for gx in range(-110, 111):
            gxm, gzm = gx * spacing, -gz * spacing
            x = gxm * cy - gzm * sy + rng.uniform(-6, 6)
            z = gxm * sy + gzm * cy + rng.uniform(-6, 6)
            if z > 30.0 or z < L.CITY_FAR:
                continue
            dist = -z
            # Thinner and lower toward the horizon, where it is only lights.
            keep = 1.0 if dist < 700 else max(0.3, 1.0 - (dist - 700) / 900)
            if rng.random() > keep:
                continue
            if L.blocked(x, z, 3.0, pts):
                continue
            w, d = rng.uniform(11, 21), rng.uniform(11, 21)
            down = math.exp(-(math.hypot(x - dx0, z - dz0) / drad) ** 2)
            h = 12 + rng.random() ** 1.8 * 30 + down * rng.random() ** 1.4 * 80
            if dist > 900:
                h = min(h, 45)
            q, u = _box_faces(x, z, w, d, h, 0.0, yaw + rng.uniform(-0.05, 0.05), rng)
            quads += q
            uvs += u
            if h > 55 and rng.random() < 0.7:
                # a stepped top, so the skyline is not all flat roofs
                w2, d2, h2 = w * 0.6, d * 0.6, rng.uniform(8, 24)
                q, u = _box_faces(x, z, w2, d2, h2, h, yaw, rng)
                quads += q
                uvs += u
            count += 1
    print("filler buildings:", count)
    return mesh_from("EarthCity", quads, uvs, mat)


# --- river and roads --------------------------------------------------------


def _ribbon(name, centre, half_widths, y, material, uv_scale, v_wrap=1.0):
    """A flat strip along a polyline of (x, z), half-width given per point."""
    left, right = [], []
    for i, (x, z) in enumerate(centre):
        a = centre[max(i - 1, 0)]
        b = centre[min(i + 1, len(centre) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / n, tx / n
        hw = half_widths[i]
        left.append((x + nx * hw, z + nz * hw))
        right.append((x - nx * hw, z - nz * hw))
    quads, uvs = [], []
    run = 0.0
    for i in range(len(centre) - 1):
        seg = math.hypot(centre[i + 1][0] - centre[i][0], centre[i + 1][1] - centre[i][1])
        u0, u1 = run / uv_scale, (run + seg) / uv_scale
        run += seg
        # winding: counter-clockwise from above
        quads.append([(left[i][0], y, left[i][1]), (right[i][0], y, right[i][1]),
                      (right[i + 1][0], y, right[i + 1][1]), (left[i + 1][0], y, left[i + 1][1])])
        uvs.append([(u0, 0.0), (u0, v_wrap), (u1, v_wrap), (u1, 0.0)])
    return mesh_from(name, quads, uvs, material)


def build_river():
    pts = L.river_points()
    mat = emissive_material("Water", _image("water", river_texture()), 1.2, base=(0.004, 0.01, 0.03, 1.0), rough=0.25)
    centre = [(x, z) for x, z, _ in pts]
    half = [hw for _, _, hw in pts]
    # Texture repeats along the river every ~150 m and once across it.
    return _ribbon("EarthRiver", centre, half, 0.5, mat, 150.0)


def _offset_line(pts, distance):
    """The river's centre line shifted sideways by `distance` + the local half width."""
    out = []
    for i, (x, z, hw) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / n, tx / n
        d = distance * (hw + L.BANK_ROAD_OFFSET)  # distance is +-1: which bank
        out.append((x + nx * d / (hw + L.BANK_ROAD_OFFSET) * (hw + L.BANK_ROAD_OFFSET), z + nz * (hw + L.BANK_ROAD_OFFSET) * distance))
    return out


def build_roads():
    pts = L.river_points()
    mat = emissive_material("RoadLights", _image("trails", road_texture()), 1.5, base=(0.01, 0.012, 0.02, 1.0))
    objs = []
    width = L.ROAD_WIDTH / 2
    for side in (1, -1):
        line = _offset_line(pts, side)
        objs.append(_ribbon("BankRoad%d" % side, line, [width] * len(line), L.ROAD_HEIGHT, mat, 24.0))
    # The bridge's approach roads: the deck line, extended out on both banks.
    bx, bz, (ax, az) = L.bridge_axis()
    reach = L.BRIDGE_LENGTH * 0.5 + 220.0
    line = [(bx + ax * t, bz + az * t) for t in np.linspace(-reach, reach, 40)]
    objs.append(_ribbon("ApproachRoad", line, [width * 1.2] * len(line), L.BRIDGE_DECK_HEIGHT + 0.6, mat, 24.0))
    return _join(objs, "EarthRoads")


# --- bridge -----------------------------------------------------------------


def _bar(a, b, radius, material, parts, verts=8):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=d.length, location=(a + b) / 2)
    o = bpy.context.view_layer.objects.active
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.data.materials.append(material)
    parts.append(o)


def _slab(centre, size, material, parts):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
    o = bpy.context.view_layer.objects.active
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    parts.append(o)


def build_bridge():
    """A single-pylon cable-stayed bridge. Local axes (Blender): X along the deck,
    Y across it, Z up; the deck's centre is the origin at ground level.

    Built to read the way the painting's bridge does from 300 m up: a *dark* steel
    structure picked out by points and lines of light — lamp posts, a dotted string
    along each fascia, thin amber cables — with only the pylon floodlit. The glows
    are deliberately low (well under 1): the set has no tonemapper, so anything
    brighter clips to a flat pale yellow and a whole cable fan merges into one
    sheet."""
    steel = plain_material("BridgeSteel", (0.03, 0.03, 0.035, 1.0), 0.45)
    dark_base = (0.03, 0.025, 0.02, 1.0)
    pylon = glow_material("BridgePylon", (0.85, 0.42, 0.08, 1.0), 0.55, base=dark_base)
    cable = glow_material("BridgeCable", (0.95, 0.6, 0.22, 1.0), 0.45, base=dark_base)
    arch = glow_material("BridgeArch", (0.7, 0.34, 0.08, 1.0), 0.22, base=dark_base)
    rail = glow_material("BridgeRail", (1.0, 0.55, 0.16, 1.0), 0.5, base=dark_base)
    lamp = glow_material("BridgeLamp", (1.0, 0.84, 0.55, 1.0), 2.2)
    uplight = glow_material("BridgeUplight", (1.0, 0.6, 0.25, 1.0), 0.6, base=dark_base)
    beacon = glow_material("BridgeBeacon", (1.0, 0.08, 0.05, 1.0), 3.0)
    parts = []
    Lb = L.BRIDGE_LENGTH
    H = L.BRIDGE_DECK_HEIGHT
    deck_w = 22.0
    # The road surface sits at H + 0.4, just under `build_roads`' approach ribbon
    # (H + 0.6), so the bridge carries the same light-trail traffic as its banks.
    top_of_deck = H + 0.4

    # -- deck: a slab over a narrower box girder, a parapet down each edge with a
    # thin lit rail on top, and a string of fascia lights along the outside.
    _slab((0, 0, top_of_deck - 1.0), (Lb, deck_w, 2.0), steel, parts)
    _slab((0, 0, top_of_deck - 2.8), (Lb, deck_w * 0.6, 1.8), steel, parts)
    for side in (-1, 1):
        y_edge = side * (deck_w / 2 - 0.2)
        _slab((0, y_edge, top_of_deck + 0.55), (Lb, 0.4, 1.1), steel, parts)
        _slab((0, y_edge, top_of_deck + 1.2), (Lb, 0.3, 0.2), rail, parts)
        for x in np.arange(-Lb / 2 + 2.0, Lb / 2 - 1.0, 4.0):
            _slab((x, side * (deck_w / 2 + 0.05), top_of_deck - 1.4), (0.5, 0.3, 0.5), lamp, parts)
        # lamp posts, staggered between the two sides, arms over the road
        for x in np.arange(-Lb / 2 + 5.0 + (side + 1) * 2.5, Lb / 2 - 2.0, 10.0):
            y_post = side * (deck_w / 2 - 1.2)
            _bar((x, y_post, top_of_deck), (x, y_post, top_of_deck + 7.5), 0.16, steel, parts, 6)
            _bar((x, y_post, top_of_deck + 7.5), (x, y_post - side * 1.8, top_of_deck + 7.8), 0.12, steel, parts, 6)
            _slab((x, y_post - side * 1.9, top_of_deck + 7.6), (1.0, 0.55, 0.3), lamp, parts)

    # -- the pylon: an inverted Y, legs straddling the deck from the riverbed and
    # meeting in a single mast that carries the cables, with a portal beam under
    # the deck and a red aviation light on top. Toward one bank, as in the painting.
    px = -Lb * 0.12
    meet, top = H + 46.0, 112.0
    leg_foot = deck_w / 2 + 2.0
    for side in (-1, 1):
        _slab((px, side * leg_foot, 2.0), (6.0, 5.0, 4.0), steel, parts)
        _bar((px, side * leg_foot, 0.0), (px, side * 0.9, meet), 1.5, pylon, parts, 10)
    _slab((px, 0, top_of_deck - 3.4), (3.0, leg_foot * 2 + 1.0, 2.0), pylon, parts)
    _slab((px, 0, H + 30.0), (2.2, 9.0, 1.4), pylon, parts)
    _bar((px, 0, meet - 3.0), (px, 0, top), 1.7, pylon, parts, 10)
    _bar((px, 0, top), (px, 0, top + 9.0), 0.55, pylon, parts, 8)
    _slab((px, 0, top + 9.6), (1.1, 1.1, 1.1), beacon, parts)

    # -- piers, each two round columns on a cap beam with a ring of light at the
    # waterline, and shallow arches springing between the piers and the pylon.
    # The pylon gets columns too (its portal beam is their cap), so the arches
    # beside it spring from something.
    piers = [-Lb * 0.45, -Lb * 0.28, Lb * 0.05, Lb * 0.23, Lb * 0.41]
    supports = sorted(piers + [px])
    for x in supports:
        for side in (-1, 1):
            _bar((x, side * 6.0, 0.0), (x, side * 6.0, top_of_deck - 3.7), 1.4, steel, parts, 10)
            _bar((x, side * 6.0, 1.3), (x, side * 6.0, 1.9), 1.55, uplight, parts, 10)
        if x != px:
            _slab((x, 0, top_of_deck - 4.2), (3.2, 16.0, 1.6), steel, parts)
    for a, b in zip(supports, supports[1:]):
        for side in (-1, 1):
            spring, crown = H * 0.35, top_of_deck - 3.9
            pts = [(a + (b - a) * t, side * 6.0, spring + (crown - spring) * math.sin(math.pi * t))
                   for t in np.linspace(0.04, 0.96, 11)]
            for p, q in zip(pts, pts[1:]):
                _bar(p, q, 0.55, arch, parts, 6)

    # -- the cable fans: from the mast down to the deck edges, one fan toward each
    # end. Few and thin, so from the deck they read as separate lines of light.
    n = 9
    for side in (-1, 1):
        for k in range(n):
            t = (k + 1) / n
            z_top = top - 3.0 - k * 2.8
            for sign, reach in ((-1, Lb * 0.36 - 12.0), (1, Lb * 0.42)):
                x_deck = px + sign * (12.0 + t * reach)
                _bar((px, side * 0.8, z_top), (x_deck, side * (deck_w / 2 - 0.4), top_of_deck + 1.0), 0.32, cable, parts, 6)
    obj = _join(parts, "EarthBridge")
    return obj


# --- export -----------------------------------------------------------------


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    return out


def _export(obj, filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_image_format="JPEG", export_jpeg_quality=90,
        export_animations=False, export_extras=False,
    )
    obj.data.calc_loop_triangles()
    print("EXPORTED", filename, "tris", len(obj.data.loop_triangles),
          "MB", round(os.path.getsize(path) / 1e6, 2))


def main(names):
    names = names or ["ground", "city", "river", "roads", "bridge"]
    builders = {
        "ground": (build_ground, "earth_ground.glb"),
        "city": (build_city, "earth_city.glb"),
        "river": (build_river, "earth_river.glb"),
        "roads": (build_roads, "earth_roads.glb"),
        "bridge": (build_bridge, "earth_bridge.glb"),
    }
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        build, filename = builders[name]
        _export(build(), filename)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
