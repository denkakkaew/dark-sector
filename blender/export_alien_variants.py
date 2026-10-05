"""
Dark Sector — export the rest of the alien fleet from raw Tripo .glb downloads.

`export_alien.py` exports one ship, the flying saucer, out of `AlienShip.blend`.
This script drives that same pipeline over the other models the fleet is drawn
from, importing each raw download straight from `planning/` instead:

    planning/alien spaceship 3d model.glb      -> assets/object/alien/alien_ship_2.glb
    planning/alien spaceship 3d model (1).glb  -> assets/object/alien/alien_ship_3.glb

Together with `alien_ship.glb` those are the pool `AlienShip.gd` draws a hull
from on every spawn, so a wave arrives as a mixed fleet rather than a row of
clones. Everything else — the triangle budget, the 256px texture cap, the
surface finish, the join into one mesh — is `export_alien.py`'s and is not
repeated here, so a change to the ships' look is still made in one place.

`alien_ship.glb` is deliberately **not** re-exported here. It already ships from
`AlienShip.blend`, which is the download plus the cleanup that was done to it by
hand; re-importing the raw .glb over the top would throw that away.

Why a table of facings
----------------------
The one thing that genuinely differs per model is which way it points. Tripo
hands each model back on its own arbitrary heading, and the pipeline has to swing
the nose onto Blender -Y — which the glTF Y-up conversion turns into Godot +Z,
the direction the ships fly. `FACING` records the direction each nose points in
*before* that yaw, measured by looking at the model rather than at its bounds:
all three are round-ish, so which axis is "longer" says nothing about which end
is the nose. Get it wrong and the ship flies home tail-first, which is invisible
at spawn distance and obvious up close.

To re-measure one, render the model from the four sides and find the view you
are looking the pilot in the face from — `--python-expr` with a Workbench render
is enough, and that is how the three below were settled.

How to run
----------
Headless, from the repo root (the Godot editor is not involved):

    "<blender>/blender.exe" --background --factory-startup \
        --python blender/export_alien_variants.py

It prints, per ship, what `AlienShip.tscn` depends on: the exported triangle
count and the Godot-space bounds. The collision box in that scene is one shape
shared by every hull in the pool, so if a new ship's bounds fall outside it,
widen the box (erring generous — a near miss counting as a hit is the friendly
side for this audience) rather than giving the ship its own.
"""

import importlib.util
import json
import os
import sys

import bpy


def _load_export_alien():
    """Import the sibling script as a module, however Blender was started."""
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "export_alien.py")
    spec = importlib.util.spec_from_file_location("export_alien", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Direction each model's nose points in Blender, straight after the glTF import.
# See the module docstring for how these were measured and why the bounds can't
# tell you. The yaw that puts a nose on -Y follows from the direction alone.
FACING = {
    "+X": -1.5707963267948966,  # -90°, the saucer's case; see export_alien.py
    "-X": 1.5707963267948966,   # +90°
    "-Y": 0.0,                  # already pointing the right way
    "+Y": 3.141592653589793,    # 180°
}

VARIANTS = [
    {
        # A winged gunship: cockpit canopy, a glowing nose emitter and a cannon
        # on each wingtip. Flat enough that it reads as a silhouette head-on.
        "source": "alien spaceship 3d model.glb",
        "out": "alien_ship_2.glb",
        "facing": "-Y",
    },
    {
        # A heavy plated disc with the pilot sunk into a canopy on top — the
        # closest of the three to the original saucer, and the biggest.
        #
        # It is also the one that needs its own decimation budget. The saucer's
        # 9000 works because the saucer is smooth curves, which collapse
        # gracefully; this hull is flat plating over 74 parts, and at that
        # budget nearly every part bottoms out on MIN_POLYS_PER_PART at once.
        # What comes out is not a softer ship, it is a shattered one — plates
        # torn into shards with gaps between them, reading as wreckage rather
        # than as a ship, and dark with it once the UVs go.
        #
        # The knee is sharp and it is worth knowing where it sits, because the
        # budget buys less here than the arithmetic suggests (see TRI_BUDGET).
        # Rendered from above, 22k triangles is wreckage, 27k still cracks
        # around the canopy ring, and 36k — what this number buys — is
        # indistinguishable from the raw download. Past that the render stops
        # changing.
        "source": "alien spaceship 3d model (1).glb",
        "out": "alien_ship_3.glb",
        "facing": "-X",
        "budget": 34000,
    },
]


def _project_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(here)


def export_variants(out_dir=None):
    """Export every ship in VARIANTS. Returns one report dict per ship."""
    export_alien = _load_export_alien()
    root = _project_root()
    reports = []

    for variant in VARIANTS:
        source = os.path.join(root, "planning", variant["source"])
        if not os.path.isfile(source):
            raise RuntimeError(
                "source model not found: %s — planning/ is gitignored, so the raw "
                "downloads have to be present locally to re-export" % source
            )
        # A fresh empty scene per ship: the pipeline finds its meshes by the
        # `ROOT` empty Tripo names, and every one of these files brings its own.
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=source)

        report = export_alien.export_alien(
            out_dir=out_dir,
            out_file=variant["out"],
            yaw=FACING[variant["facing"]],
            budget=variant.get("budget"),
        )
        report["source"] = variant["source"]
        report["facing"] = variant["facing"]
        reports.append(report)

    return reports


if __name__ == "__main__":
    print("VARIANT_REPORT " + json.dumps(export_variants(), indent=2))
