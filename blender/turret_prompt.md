# Turret — text-to-3D generation prompt

Prompts for generating the player turret with an AI 3D generator (Hyper3D/Rodin,
Hunyuan3D, Meshy, Tripo, …). The design matches the storyboard art in
`planning/` and the procedural version in `blender/generate_turret.py`, so a
generated mesh can drop into `scenes/Turret.tscn` in place of the box+cylinder
placeholder.

---

## Main prompt

> A chunky stylized cartoon space defense turret for a kids' arcade game, low-poly
> game asset. A single thick cannon barrel mounted on a boxy armored housing that
> sits on a round rotating pedestal over a wide stepped circular base plate.
> Smooth rounded bevelled edges, no sharp corners, friendly toy-like proportions —
> the barrel is about as long as the housing is tall. Glossy white and light-grey
> hull panels with dark charcoal-grey mechanical parts: a dark collar where the
> barrel meets the housing, a slatted vent panel on the back, and a small sight
> block on top of the barrel. Warm amber-orange glowing accents on the two round
> side trunnion caps, the base rim ring, and a glowing ring at the muzzle. A round
> glowing cyan power core disc on the rear of the housing and a small cyan screen
> panel on top. Copper-brass band near the muzzle tip. Clean hard-surface sci-fi
> shapes, bright saturated colours, soft studio lighting, neutral background,
> full model centred, three-quarter view.

## Negative prompt

> realistic military weapon, tank, gun sight scope crosshair, camouflage, rust,
> grime, weathering, battle damage, human figure, hands, base terrain, ground
> plane, rocks, pedestal display stand, text, logos, watermark, multiple objects,
> cropped, dark moody lighting

## Short prompt (for generators with tight input limits)

> Low-poly cartoon space defense turret: one thick white cannon barrel on a boxy
> armored housing on a round rotating base. Rounded bevelled edges, glossy white
> and dark-grey panels, glowing amber trunnion caps and muzzle ring, cyan power
> core disc on the back, brass band at the muzzle. Bright, friendly, toy-like.
> Neutral background, centred, three-quarter view.

---

## Technical constraints to request (or enforce afterwards)

Most generators ignore these in the prompt text — set them in the generator's
options where possible and fix the rest in Blender before export.

- **Poly budget:** 3k–8k triangles. This is a foreground prop on a fixed camera,
  but the build targets the **GL Compatibility** renderer on a touchscreen PC.
- **Materials:** PBR, one texture set, 1024² or 2048². Emissive map (or separate
  emissive material) for the amber accents and the cyan core — the muzzle glow
  and core need to read as lit in-game.
- **Orientation:** Y-up, model facing **−Z**, origin at the **centre of the base
  plate footprint** so it sits on the deck at y = 0.
- **Scale:** roughly 2.2 m tall, 2.4 m base diameter — matches the placeholder
  in `Turret.tscn` (2.5 × 0.6 × 2.0 base, 1.6 barrel).
- **Format:** GLB (glTF 2.0). Godot imports it directly.

## Post-generation work (the generator will not do this)

AI generators return a single fused mesh. `scripts/Turret.gd` aims by rotating
`AimPivot` and spawns lasers from `Muzzle`, so the mesh has to be split:

1. Separate the mesh into **base** (static) and **barrel + housing** (aiming).
2. In `Turret.tscn`, put the base under the root and the aiming part under
   `AimPivot`, with the pivot at the trunnion axis height (~0.8–1.15 above the
   deck).
3. Add the `Muzzle` marker at the barrel tip, pointing −Z.

If splitting the generated mesh is more trouble than it's worth, run
`blender/generate_turret.py` instead — it builds the same design already
separated and parented for the aim rig.
