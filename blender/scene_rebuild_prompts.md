# Scene rebuild — 3D object list and image prompts

Each battle is currently a painted backdrop on a quad, with the ISS deck, the
turret and the aliens as the only 3D. This rebuild turns the painted props and
ground into real 3D objects. Each scene keeps its **palette, landmarks and semi-realistic look**
(`assets/backdrop/*_surface.png`, `space_earth.png`, `earth_city.png`), rebuilt as
clean, modern geometry. Only the sky stays painted.

## The shared style

The painted backdrops are semi-realistic: believable materials, real
proportions, rich colour. The 3D set has to read as the *same place*, so the
scenery is rebuilt to match them, only cleaner and more modern. A kid should
not see a style change when the painting becomes geometry.

- **Semi-realistic, modern sci-fi:** clean hard-surface design, believable
  proportions, real-looking materials (satin metal, painted panels, glass).
  Polished game art, not a toy and not a photograph.
- **Each scene keeps its own palette from the painting:** Moon is cold grey with
  dark alien architecture, Mars is warm cream, blue and rust-orange, the ISS is
  white with gold foil, and Earth is a navy night with warm gold and neon lights.
- **Light parts are flat colour:** windows and light strips are drawn as bright
  flat colour with no glow, and Claude makes them emissive in Godot.
- **Kid-friendly, not cute:** nothing gory, damaged or frightening, but also no
  vinyl-toy proportions.
- **The aliens are the exception.** The saucers, the ore carrier and the lander
  are the cartoon characters of the game, with a green pilot in a glass dome, and
  they are the only things that may be cute. That is also what makes them the
  brightest things on screen.

## How the work is split

| Who | What | How |
|---|---|---|
| **You** | Hero props: buildings, vehicles, alien structures (list A) | Prompt → 2D image → image-to-3D → save `.glb` to `temp/` |
| **You** | Sky plates: painted, 2D only (list B) | Prompt → 2D image → save `.png` to `temp/` |
| **Claude, in Blender MCP** | Terrain, rocks, mountains, planets, flat/thin parts, city filler (list C) | Built procedurally, with Poly Haven textures and NASA public-domain Earth maps |
| **Claude** | Decimate, cap textures, finish, export, assemble each scene in Godot | A new `blender/export_scene_props.py` on the same pipeline as `export_alien.py` |

Left to Blender rather than an image-to-3D generator:

- **Ground and mountains:** generators don't do terrain.
- **Thin flat parts** (solar panels, bridge cables, truss lattices): these shatter
  under decimation, the same failure as `alien_ship_3.glb` in `CLAUDE.md`.
- **Planets:** a textured sphere beats any generated mesh.

## Rules for every file you save

1. Save into **`temp/`** at the repo root, using the **exact filename** in the
   list, lowercase. `temp/` is gitignored, Godot-ignored (`temp/.gdignore`) and
   excluded from both export presets, so raw 60–100 MB downloads are safe there.
2. **Also save the 2D image** next to the model, with the same name and `.png`
   (`temp/mars_rover.png` next to `temp/mars_rover.glb`). Claude checks the
   generated model against it and uses it for colour matching.
3. Make the 2D images **square (1:1)**, with the object filling about 80% of the
   frame and the whole object visible.
4. When the generator offers multi-view input, give it front + side + back views
   generated from the same prompt. Without that, the hidden side comes out mushy.
5. Any texture resolution and triangle count is fine. Claude decimates to budget
   (see the **Budget** column) and caps textures afterwards.

### Why the prompts are written the way they are

Every prompt ends with the same **image-to-3D suffix**:

- A **neutral grey background**, because half these props are white or cream and
  vanish into a white background when it is cut out.
- **No glow or bloom.** A glow bakes into the texture as a white smear. Glowing
  parts are described as "bright flat cyan" instead, and Claude makes them
  emissive in Godot.
- **No ground or shadow**, so the cut-out is clean.

Keep the suffix on every prompt. Each prompt below is complete, so copy the whole
blockquote.

---

## A. Image-to-3D props (you generate)

### Checklist

| # | File (`temp/…`) | Scene | Budget (tris) | Priority |
|---|---|---|---|---|
| A1 | `alien_ore_carrier.glb` | Mars (enemy) | 9k | ★★★ |
| A2 | `moon_alien_dome_geodesic.glb` | Moon | 4k | ★★★ |
| A3 | `moon_alien_dome_shell.glb` | Moon | 4k | ★★★ |
| A4 | `moon_alien_spire.glb` | Moon | 3k | ★★★ |
| A5 | `moon_alien_tanks.glb` | Moon | 3k | ★★ |
| A6 | `moon_alien_lander.glb` | Moon | 4k | ★★ |
| A7 | `mars_colony_dome.glb` | Mars | 6k | ★★★ |
| A8 | `mars_colony_tower.glb` | Mars | 3k | ★★★ |
| A9 | `mars_hab_pod.glb` | Mars | 2k | ★★ |
| A10 | `mars_drill_rig.glb` | Mars | 8k | ★★★ |
| A11 | `mars_mining_crane.glb` | Mars | 4k | ★★ |
| A12 | `mars_radar_dish.glb` | Mars | 2k | ★★ |
| A13 | `mars_rover.glb` | Mars | 3k | ★★ |
| A14 | `mars_cargo_crawler.glb` | Mars | 3k | ★ |
| A15 | `mars_alien_drone.glb` | Mars | 2k | ★★ |
| A16 | `mars_ore_pile.glb` | Mars | 2k | ★ |
| A17 | `iss_module.glb` | ISS | 4k | ★★★ |
| A18 | `iss_soyuz.glb` | ISS | 4k | ★★ |
| A19 | `iss_robot_arm.glb` | ISS | 3k | ★★ |
| A20 | `earth_tower_artdeco.glb` | Earth | 4k | ★★★ |
| A21 | `earth_tower_neon.glb` | Earth | 4k | ★★★ |
| A22 | `earth_tower_pixel.glb` | Earth | 4k | ★★★ |
| A23 | `earth_building_midrise_a.glb` | Earth | 2k | ★★ |
| A24 | `earth_building_midrise_b.glb` | Earth | 2k | ★★ |
| A25 | `turret_gun.glb` | Every scene (player) | 6k | ★★★ |
| A26 | `turret_base.glb` | Every scene (player) | 4k | ★★★ |
| A27 | `alien_scout_saucer.glb` | Every scene (enemy) | 9k | ★★★ |
| A28 | `alien_gunship.glb` | Every scene (enemy) | 9k | ★★★ |
| A29 | `alien_heavy_disc.glb` | Every scene (enemy) | 12k | ★★★ |
| A30 | `iss_hull_deck.glb` | Every scene (player's deck) | 8k | ★★ |

A25–A30 replace models that are already in the game. Until they arrive the
current ones keep working.

Priority: ★★★ is a landmark the scene is recognised by. ★ is set dressing,
which Claude can stand in for with a Blender primitive if you run out of time.

Suggested order: the turret and the alien fleet first (A25–A29, then A1 and
A6), because they are in every scene and set the look the scenery is matched to.
Then Moon (A2–A5), Mars (A7–A16), ISS (A17–A19, A30) and Earth (A20–A24).

---

### A1 · `alien_ore_carrier.glb` — Mars' armoured ore carrier

The ordinary saucer is a cartoon (purple hull, green pilot in a glass dome). The
carrier is the same character family, but a heavier, sleeker hauler with the
stolen ore carried inside the hull, seen through windows. The orange armour
bubble stays as an effect on top.

> A modern sci-fi alien cargo spaceship for a kids' game: a wide, sleek,
> rounded saucer-shaped hauler with a glossy deep-purple hull and smooth
> lavender armour panels, clean panel lines, and a small clear glass dome on top
> holding a cartoon round green alien pilot with two antennae and big friendly
> eyes. Two large cargo bays built into the sides of the hull, each with a
> window showing glowing orange ore crystals inside, painted as bright flat
> colour. A thin mint-green light strip runs around the rim and two round
> thrusters sit at the back. Polished stylized game art, hard-surface design,
> slightly cartoon, not a toy. Single isolated object, centred, whole object in
> frame, front three-quarter view from slightly above with the pilot facing the
> viewer, plain flat neutral grey background, soft even studio lighting, no
> glow, no bloom, no cast shadow, no ground, no text.

---

### Scene 2 · Moon — the alien forward base

Reference: the cluster right of centre in `moon_surface.png`. Dark gunmetal and
charcoal-green alien architecture: lattice domes, ribbed shells, tapered spires,
tank modules, thin cyan-green light seams. It is alien, so no flags and no NASA
white. Modern means sleeker and cleaner than the painting, with the same
colours.

#### A2 · `moon_alien_dome_geodesic.glb`

> A modern sci-fi alien moon base building: a large geodesic dome made of a dark
> gunmetal hexagonal lattice frame filled with smoky dark-green translucent
> glass panels, sitting on a thick ribbed circular foundation ring with a small
> arched entrance. Thin bright cyan-green light strips along the ring, painted as
> flat colour. Sleek, clean hard-surface alien architecture, semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A3 · `moon_alien_dome_shell.glb`

> A modern sci-fi alien habitat shaped like a smooth armoured shell: a rounded
> dome of overlapping dark charcoal-green metal plates with clean ribbed seams,
> a dark oval doorway at the front, and a row of small round portholes painted
> bright flat cyan. Sleek, clean hard-surface alien architecture, semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A4 · `moon_alien_spire.glb`

> A modern sci-fi alien tower: a tall slender tapered spire of dark gunmetal
> ribbed plates rising from a wide flared base, with three thin vertical fins
> around it and a column of narrow vertical slit windows painted bright flat
> green. A small pointed antenna at the tip. Tall and thin, about six times
> taller than wide. Sleek, clean hard-surface alien architecture, semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A5 · `moon_alien_tanks.glb`

> A modern sci-fi alien fuel storage module: three fat horizontal ribbed
> cylinder tanks stacked in a pyramid on a dark metal cradle, joined by curved
> pipes, dark gunmetal with charcoal-green bands and a bright flat cyan gauge
> stripe on each tank. Sleek, clean hard-surface alien industrial design,
> semi-realistic materials, polished game asset. Single isolated object,
> centred, whole object in frame, three-quarter view from slightly above, plain
> flat neutral grey background, soft even studio lighting, no glow, no bloom, no
> cast shadow, no ground, no text.

#### A6 · `moon_alien_lander.glb`

The briefing says "destroy their landers". One sits parked on the pad (the pad
itself is Blender-built). It is an alien craft, so it shares the fleet's purple
and the green cartoon pilot, but it is a sleek lander rather than a toy. Legs are
short and sturdy because thin legs break when the image is turned into 3D.

> A modern sci-fi alien landing craft parked on the ground: a sleek, rounded,
> egg-shaped hull in glossy dark purple and charcoal-grey panels with clean
> panel lines, a glass cockpit bubble on the upper front holding a cartoon round
> green alien pilot with two antennae and big friendly eyes, three short sturdy
> landing legs with wide round foot pads, two small side thrusters, and a thin
> mint-green and cyan light strip around the middle painted as flat colour.
> Polished stylized game art, hard-surface design, slightly cartoon, not a toy.
> Single isolated object, centred, whole object in frame, front three-quarter
> view from slightly above with the pilot facing the viewer, plain flat neutral
> grey background, soft even studio lighting, no glow, no bloom, no cast
> shadow, no ground, no text.

---

### Scene 3 · Mars — the colony and the alien drilling rig

Reference: `mars_surface.png`. On the left is the colony: cream and white
rounded buildings, a big blue-glass dome, a control tower, small pods, solar
panels and a radar dish. On the right is a rusty orange oil-rig-style drilling
platform with a derrick and crane, worked by spindly alien drones. The painting's
warm illustrated look is kept; modern means cleaner and sharper.

#### A7 · `mars_colony_dome.glb`

> The main building of a modern Mars colony: a large blue glass geodesic dome on
> top of a round cream-white two-storey ring building with rounded corners, a
> wide entrance with a ramp at the front, a row of square windows and an orange
> stripe around the base. Retro-futuristic, clean, semi-realistic materials,
> polished game asset. Single isolated object, centred, whole object in frame,
> three-quarter view from slightly above, plain flat neutral grey background,
> soft even studio lighting, no glow, no bloom, no cast shadow, no ground, no
> text.

#### A8 · `mars_colony_tower.glb`

> A modern Mars colony control tower: a tall cream-white cylinder with three
> stacked ring-shaped observation decks with blue window bands, the top deck
> capped by a small blue glass dome and a thin antenna mast. Retro-futuristic,
> clean, semi-realistic materials, polished game asset. Single isolated object,
> centred, whole object in frame, three-quarter view from slightly above, plain
> flat neutral grey background, soft even studio lighting, no glow, no bloom, no
> cast shadow, no ground, no text.

#### A9 · `mars_hab_pod.glb`

> A small modern Mars colony habitat pod: a short round cream-white module with a
> shallow domed roof, a blue window band all the way round, a small door and an
> orange stripe at the base. Retro-futuristic, clean, semi-realistic materials,
> polished game asset. Single isolated object, centred, whole object in frame,
> three-quarter view from slightly above, plain flat neutral grey background,
> soft even studio lighting, no glow, no bloom, no cast shadow, no ground, no
> text.

#### A10 · `mars_drill_rig.glb`

The scene's landmark, where the aliens are stealing ore. Keep it chunky: a fine
open lattice turns to mush in image-to-3D, so the prompt asks for solid,
readable shapes.

> A modern heavy mining drill platform on Mars, shaped like an offshore oil rig:
> a thick two-deck square steel platform on four sturdy cylindrical legs, with
> boxy machinery houses and stairs on the decks, and a tall tapering drilling
> derrick rising from the centre built from chunky steel beams. Orange-yellow
> painted steel with dark grey machinery, lightly weathered by Martian dust, and
> a few bright flat purple alien panels bolted on. Chunky readable shapes, not
> fine wireframe. Semi-realistic materials, polished game asset. Single
> isolated object, centred, whole object in frame, three-quarter view from
> slightly above, plain flat neutral grey background, soft even studio lighting,
> no glow, no bloom, no cast shadow, no ground, no text.

If the derrick comes out as a blob, try generating the platform without the
derrick. Claude can build the lattice in Blender instead.

#### A11 · `mars_mining_crane.glb`

> A modern industrial crane for a mining rig: a squat rotating cab on a round
> base, a long angled boom arm built from chunky box beams, and a cable with a
> hook hanging from the boom tip. Orange-yellow painted steel, lightly weathered
> by Martian dust. Chunky readable shapes, not fine wireframe. Semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter side view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A12 · `mars_radar_dish.glb`

> A modern Mars colony radar dish: a white parabolic satellite dish with a small
> receiver on struts at its centre, tilted up on a grey tripod mount with a small
> equipment box at its feet. Clean retro-futuristic design, semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A13 · `mars_rover.glb`

> A modern six-wheeled Mars exploration rover buggy: an open white and orange
> chassis with a small cab, chunky grey wheels on rocker-bogie legs, a camera
> mast and a small antenna. Clean retro-futuristic design, semi-realistic
> materials, polished game asset. Single isolated object, centred, whole object
> in frame, three-quarter view from slightly above, plain flat neutral grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text.

#### A14 · `mars_cargo_crawler.glb`

> A long low modern Mars cargo crawler: a cream-white cylindrical tanker body
> lying on a dark grey tracked chassis, with a small rounded cab at the front
> with blue windows and orange hazard stripes. Clean retro-futuristic design,
> semi-realistic materials, polished game asset. Single isolated object,
> centred, whole object in frame, three-quarter view from slightly above, plain
> flat neutral grey background, soft even studio lighting, no glow, no bloom, no
> cast shadow, no ground, no text.

#### A15 · `mars_alien_drone.glb`

The small walking figures around the rig. They are alien workers, so they belong
to the fleet: purple, with one green eye. Friendly and a little goofy, not
scary.

> A small modern alien worker robot standing upright: a round purple glossy
> metal head-body pod with one big bright flat green eye lens, two thin jointed
> legs, two thin arms holding a small mining pick, and a short antenna. Clean
> hard-surface design, slightly cartoon, friendly and a little goofy. Polished
> stylized game asset. Single isolated object, centred, whole figure in frame,
> front three-quarter view, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no text.

#### A16 · `mars_ore_pile.glb`

> A heap of glowing alien fuel ore on the ground: a pile of chunky angular
> crystals in bright flat orange and amber, mixed with rust-red Martian rocks,
> with two dark metal crates beside it. Semi-realistic materials, polished game
> asset. Single isolated object, centred, whole object in frame, three-quarter
> view from slightly above, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground plane, no text.

---

### Scene 1 · ISS — first contact

Reference: `space_earth.png` and the storyboard ("Blue Earth filling the lower
view, ISS solar panels at the edges"). The station parts frame the screen edges
and stay out of the middle, where the aliens come in. They look like the real
ISS, in a cleaner modern form: white blanket cloth, silver and gold foil.

#### A17 · `iss_module.glb`

> A single modern space station pressurized module: a long white cylinder
> covered in quilted white thermal blanket panels with silver handrails, a round
> docking ring and hatch at one end, a cone-shaped adapter at the other, a few
> small grey equipment boxes and gold foil patches on the side. Realistic and
> clean, polished game asset. Single isolated object, centred, whole object in
> frame, three-quarter side view from slightly above, plain flat dark grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text, no flags, no logos.

#### A18 · `iss_soyuz.glb`

> A modern crew capsule spacecraft in the style of a Soyuz: a round green-grey
> orbital module, a bell-shaped descent capsule, and a cylindrical service
> module with two dark-blue solar panel wings pointing straight out to the sides.
> Realistic and clean, polished game asset. Single isolated object, centred,
> whole object in frame, side view from slightly above, plain flat dark grey
> background, soft even studio lighting, no glow, no bloom, no cast shadow, no
> ground, no text, no flags, no logos.

#### A19 · `iss_robot_arm.glb`

> A modern space station robotic arm in the style of Canadarm2: two long white
> boom segments joined by a bent elbow joint, with chunky grey joint housings at
> the shoulder, elbow and wrist, and a cylindrical grapple end-effector. Arm bent
> in a relaxed L pose. Realistic and clean, polished game asset. Single isolated
> object, centred, whole object in frame, side view from slightly above, plain
> flat dark grey background, soft even studio lighting, no glow, no bloom, no
> cast shadow, no ground, no text, no logos.

---

### Scene 4 · Earth — the night city

Reference: `earth_city.png`. A dense night city along a curving river, with a
golden cable-stayed bridge and a few landmark towers with lit crowns.

These are night buildings, so the prompts **ask for the windows lit**. Claude
uses each texture as its own emission map, so lit windows glow and dark walls
stay dark. That only works if the walls are dark and the windows bright, with no
glow around them.

#### A20 · `earth_tower_artdeco.glb`

> A tall modern art-deco skyscraper at night: a slim stepped tower with
> setbacks, dark navy-grey stone facade covered in a dense grid of warm yellow
> lit windows, and a pointed crown and spire lit in bright flat gold. Flat even
> lighting so the windows read as painted colour. Semi-realistic materials,
> polished game asset. Single isolated object, centred, whole building in frame,
> three-quarter view from slightly above, plain flat neutral grey background, no
> glow, no bloom, no light halos, no cast shadow, no ground, no text, no logos.

#### A21 · `earth_tower_neon.glb`

> A slim modern glass skyscraper at night: a tall square tower that tapers to a
> sharp point, dark blue-black glass facade with thin vertical strips of cool
> white lit windows, and a crown of bright flat magenta and violet light bands
> near the top. Flat even lighting so the lights read as painted colour.
> Semi-realistic materials, polished game asset. Single isolated object,
> centred, whole building in frame, three-quarter view from slightly above,
> plain flat neutral grey background, no glow, no bloom, no light halos, no cast
> shadow, no ground, no text, no logos.

#### A22 · `earth_tower_pixel.glb`

The tallest tower, on the right of the painting, with a pixelated, broken-up
silhouette.

> A very tall modern supertall skyscraper at night with a pixelated silhouette:
> a dark glass tower whose surface is broken by a spiral of irregular stepped
> cube cut-outs running up its height, with warm white lit windows in a fine grid
> and a small lit antenna on top. Flat even lighting so the windows read as
> painted colour. Semi-realistic materials, polished game asset. Single isolated
> object, centred, whole building in frame, three-quarter view from slightly
> above, plain flat neutral grey background, no glow, no bloom, no light halos,
> no cast shadow, no ground, no text, no logos.

#### A23 · `earth_building_midrise_a.glb`

> A modern twelve-storey city apartment block at night: a simple rectangular
> building with a flat roof carrying small rooftop water tanks and an AC unit, a
> dark grey facade with a regular grid of windows where about half are lit warm
> yellow and half are dark, and a few balconies. Flat even lighting so the
> windows read as painted colour. Semi-realistic materials, polished game asset.
> Single isolated object, centred, whole building in frame, three-quarter view
> from slightly above, plain flat neutral grey background, no glow, no bloom, no
> cast shadow, no ground, no text, no logos.

#### A24 · `earth_building_midrise_b.glb`

> A modern twenty-storey city office building at night: a rectangular tower with
> rounded corners, horizontal bands of dark glass alternating with bands of cool
> white and pale blue lit office windows, and a small blue rooftop sign panel
> painted as flat colour with no letters. Flat even lighting so the lights read
> as painted colour. Semi-realistic materials, polished game asset. Single
> isolated object, centred, whole building in frame, three-quarter view from
> slightly above, plain flat neutral grey background, no glow, no bloom, no cast
> shadow, no ground, no text, no logos.

---

### Every scene · the turret, the alien fleet and the deck

These appear in all four scenes, so they set the look of the whole game. The
scenery is built to sit behind them, and they are the brightest and most colourful
things on screen on purpose. The current models are kept as the design reference
(white turret with a cyan core and amber caps, purple saucers with a green pilot),
and each is redrawn in the same semi-realistic modern style as the sets.

**Export notes for Claude (nothing for you to do):**

- The turret is generated as **two separate models** (gun and base) instead of
  one fused mesh, because `Turret.tscn` aims by rotating the gun on the base and
  a fused mesh would have to be cut apart. `blender/export_turret.py` measures the
  pivot and muzzle from the geometry, so after the swap I re-run it and update the
  numbers `Turret.tscn` hard-codes.
- The three alien hulls are exported by `export_alien.py` and
  `export_alien_variants.py`. I add the new source files to `VARIANTS` and
  re-measure `FACING`. If a hull is larger than the shared collision box in
  `AlienShip.tscn` (1.93 x 1.15 x 1.87), I fit it to the box, not the other way
  round.
- Keep the **pilot facing the viewer** in every alien image. Which way the nose
  points is the one thing I can't infer from the shape, and a wrong guess means
  the ships fly home tail-first.

#### A25 · `turret_gun.glb`

The aiming part: the housing with the barrel. Keep the cyan core and the amber
caps. They are what the player is looking at all game. The barrel points **left
of the image** so I can read which end is the muzzle.

> A modern sci-fi defense turret gun, the rotating part only, without any base: a
> chunky rounded armoured housing in glossy-satin white and light-grey panels
> with clean panel lines, a thick cannon barrel extending forward with a dark
> charcoal collar where it meets the housing, a segmented barrel with a bright
> gold ring near the muzzle tip, and a small sight block on top with a small
> square screen painted bright flat cyan. On the back of the housing a large
> round power-core disc painted bright flat cyan, and on each side a round
> trunnion cap painted bright flat amber-orange. A slatted vent panel on the
> back. Clean hard-surface, semi-realistic materials, polished game asset, bold
> readable shapes. Single isolated object, centred, whole object in frame, side
> view with the barrel pointing to the left, tilted slightly toward the viewer so
> the cyan core is visible, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no base, no pedestal,
> no text.

#### A26 · `turret_base.glb`

> A modern sci-fi turret mounting, the static part only, without any gun: a round
> rotating pedestal made of stacked rings of glossy-satin white and light-grey
> armoured plates with dark charcoal seams, sitting on a wide stepped circular
> base plate in dark gunmetal, with small recessed rectangular lights around the
> rim painted bright flat amber-orange and small square panels painted bright
> flat blue. The top of the pedestal is a flat round mounting ring, empty. A thin
> low safety railing runs around the outer edge of the plate on one side. Clean
> hard-surface, semi-realistic materials, polished game asset, bold readable
> shapes. Single isolated object, centred, whole object in frame, three-quarter
> view from slightly above, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no gun, no barrel, no
> text.

#### A27 · `alien_scout_saucer.glb`

The ordinary enemy, and the one the game is recognised by. Same character as the
current saucer, in the modern style. Replaces `alien_ship.glb`.

> A modern sci-fi alien scout flying saucer for a kids' game: a sleek, wide,
> disc-shaped hull in glossy deep-purple panels with clean panel lines and a
> darker navy underside, a large clear glass dome on top holding a cartoon round
> green alien pilot with two antennae, big friendly eyes and a happy smile,
> gripping two small control sticks. Rectangular light panels spaced evenly
> around the rim, painted as bright flat cyan, lime-green and amber, and a round
> blue thruster ring on the underside. Polished stylized game art, hard-surface
> design, slightly cartoon, not a toy. Single isolated object, centred, whole
> object in frame, front three-quarter view from slightly above with the pilot
> facing the viewer, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no text.

#### A28 · `alien_gunship.glb`

The winged one: it reads as a different silhouette head-on, so a wave doesn't look
like a row of clones. Replaces `alien_ship_2.glb`.

> A modern sci-fi alien gunship for a kids' game: a sleek, compact, arrow-shaped
> fighter in glossy deep-purple and dark navy panels with two short, thick,
> swept-back wings, a small cannon on each wingtip, a pointed nose with a bright
> flat lime-green emitter, and a clear glass cockpit canopy holding a cartoon
> round green alien pilot with two antennae and big friendly eyes. Thin cyan and
> amber light strips along the wing edges, painted as flat colour. Wings are
> thick and solid, not thin sheets. Polished stylized game art, hard-surface
> design, slightly cartoon, not a toy. Single isolated object, centred, whole
> object in frame, front three-quarter view from slightly above with the pilot
> facing the viewer, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no text.

#### A29 · `alien_heavy_disc.glb`

The biggest hull. The old model was 74 plated parts and needed 36k triangles to
survive, so this prompt asks for **large smooth plates** instead of many small
ones, which is also what lets it be exported at about a third of that. Replaces
`alien_ship_3.glb`.

> A modern sci-fi alien heavy cruiser flying disc for a kids' game: a big, wide,
> thick disc in glossy deep-purple armour with a few large smooth overlapping
> armour plates, not many small ones, and a darker navy underside with a wide
> round thruster. A canopy sunk into the top holds a cartoon round green alien
> pilot with two antennae and big friendly eyes, under a clear glass bubble.
> Bright flat lime-green and cyan light panels around the rim. Chunky and solid
> with simple bold shapes. Polished stylized game art, hard-surface design,
> slightly cartoon, not a toy. Single isolated object, centred, whole object in
> frame, front three-quarter view from slightly above with the pilot facing the
> viewer, plain flat neutral grey background, soft even studio lighting, no glow,
> no bloom, no cast shadow, no ground, no text.

#### A30 · `iss_hull_deck.glb`

The curved station deck the turret is bolted to, in every scene. It frames the
bottom of the screen and sets the colour of the player's side of the picture.

> A curved section of a modern sci-fi space station deck seen from above and
> behind: a wide shallow arc of dark charcoal-grey armoured hull plates with
> clean panel lines, a raised rim of chunky console blocks along the outer edge
> holding small square screens painted bright flat blue, small amber indicator
> lights and recessed vents. Clean hard-surface, semi-realistic materials,
> polished game asset. Single isolated object, centred, whole object in frame,
> high three-quarter view, plain flat neutral grey background, soft even studio
> lighting, no glow, no bloom, no cast shadow, no ground, no text.

---

## B. Painted sky plates (you generate, 2D only)

Only the sky stays a painting, on the existing backdrop quad. These replace the
current backdrops, so they must be **empty of everything list A and list C now
builds in 3D**: no planets, buildings, mountains or ground. Generate them
**wide, about 2:1** (for example 2048×1024). Save them as `.png` into `temp/`.

| # | File (`temp/…`) | Used by |
|---|---|---|
| B1 | `sky_stars.png` | ISS, Moon |
| B2 | `sky_mars.png` | Mars |
| B3 | `sky_earth_night.png` | Earth |

#### B1 · `sky_stars.png`

> Deep space background, wide panorama: pure deep black space filled with
> thousands of small sharp stars of varied brightness, a few brighter stars with
> small soft cross-shaped sparkles, mostly white with some pale blue and warm
> orange ones, and a faint purple-blue Milky Way band crossing diagonally from
> upper right to lower centre. No planets, no moon, no sun, no horizon, no
> ground, no spacecraft, no text. Semi-realistic digital painting, game
> backdrop.

#### B2 · `sky_mars.png`

> Martian sky background, wide panorama: a dusty sky that is deep rust-red at
> the top and grades smoothly through burnt orange to a bright hazy peach glow
> along the bottom edge, with a few very faint stars in the top quarter. Soft,
> smooth atmospheric haze. No ground, no mountains, no buildings, no sun disc,
> no planets, no text. Warm semi-realistic digital painting, game backdrop.

#### B3 · `sky_earth_night.png`

> Night sky over a big city, wide panorama: a deep navy-blue starry night sky
> with many small stars, soft wispy clouds lit pale blue by moonlight in the
> upper left and upper right corners, and along the very bottom edge a thin
> hazy band of distant city glow made of countless tiny warm and white lights on
> a flat horizon, with no tall buildings. No moon disc, no foreground, no text.
> Semi-realistic digital painting, game backdrop.

---

## C. Built by Claude in Blender MCP (nothing for you to do)

All of these follow the painted backdrops' semi-realistic look, so they sit
naturally beside list A.

| File (`assets/object/…`) | Scene | Built from |
|---|---|---|
| `shared/earth_planet.glb` + Godot shader | ISS (large limb), Moon (small in sky) | Sphere + NASA Blue Marble / Black Marble (public domain): day side, city lights on the night side, cloud layer, blue atmosphere rim |
| `iss/iss_solar_array.glb` | ISS | Thin mast + gold-orange panel grid (flat) |
| `iss/iss_truss.glb` | ISS | Chunky white beam + radiator fins |
| `moon/moon_ground.glb` | Moon | Displaced plane: soft craters, regolith (Poly Haven texture) |
| `moon/moon_ridges.glb` | Moon | Far mountain ridge band, horizon |
| `moon/moon_rock_1…6.glb` | Moon | Rugged boulders, a few variants scattered |
| `moon/moon_landing_pad.glb` | Moon | Disc + mint-cyan emissive ring + light posts |
| `moon/moon_alien_pipes.glb` | Moon | Ribbed dark tubes joining the buildings |
| `mars/mars_ground.glb` | Mars | Displaced plane, sand + pebbles |
| `mars/mars_rock_shelf_1…4.glb` | Mars | Layered sandstone ledges (the big foreground rocks) |
| `mars/mars_mesa_1…3.glb` | Mars | Flat-topped buttes on the horizon |
| `mars/mars_solar_panel.glb` | Mars | Flat panel on a post |
| `earth/earth_city_blocks.glb` | Earth | Procedural filler buildings with an emissive window atlas |
| `earth/earth_river.glb` | Earth | Curving river plane, dark reflective with light streaks |
| `earth/earth_bridge.glb` | Earth | Golden single-pylon cable-stayed bridge (cables are too thin to generate) |
| `earth/earth_roads.glb` | Earth | Road ribbons with warm emissive light trails |

## After you hand over the files

1. Claude imports each `.glb` from `temp/` into Blender and checks it against
   its `.png`. Claude reports anything that came out broken, such as a mushy
   back side or a melted lattice, so you can regenerate just that one.
2. `blender/export_scene_props.py` (new, built on `export_alien.py`'s pipeline)
   decimates each prop to the budget above and caps textures at 512px, or 1024px
   for landmarks. It strips Tripo's metallic and roughness maps (metal goes black
   in GL-Compatibility), applies the surface finish, and writes to
   `assets/object/<scene>/`.
3. Each destination becomes a set scene, `scenes/sets/<scene>_set.tscn`, that
   `SceneLook.gd` instances from a new `look.set` entry in `CampaignData.gd`.
   A fifth destination is still a data change.
4. Layout rule: props sit **beyond the alien spawn ring** (35 units out) or
   **below the flight lanes** (aliens fly at y ≈ 0.6–5), so nothing hides an
   incoming ship. The ISS station parts frame the edges only.
5. Re-shoot `assets/backdrop/destination_1..4.png` afterwards, because the title
   and briefing advertise these scenes.
