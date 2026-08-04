# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Dark Sector** — an alien-shooting arcade game built in **Godot 4.6** (GL Compatibility renderer, Jolt physics for 3D). **Every storyboard screen now exists**: `Title.tscn` (set as `run/main_scene`) → sign-in → `SceneRouter` runs briefing → quiz → battle → scene cleared through all four destinations to the win text → `Results.tscn`, the ranked board persisted by the `Leaderboard` autoload. `Game.tscn` is the battle — a reticle-aimed turret firing lasers at alien ships in four flight modes, over a per-scene sky, lighting and planet backdrop, with Mars' armoured ore carrier. Phase 9 added the polish layer: sound and music (`Audio` autoload over a **placeholder** set), screen shake, touch/hold to fire, an idle reset back to the title (`IdleWatch`), and the title's four-destination attract cycle. A web build is exported under `docs/` for GitHub Pages, a Windows preset builds to gitignored `build/`, and the gdUnit4 test addon is installed. **Every phase in the plan is done** — what's left is the art pass, real sound files, and the tuning judgements that need a human at the kiosk. See `planning/STORYBOARD.md` for the full spec and `planning/IMPLEMENTATION_PLAN.md` for the phased roadmap and each phase's "Still unverified".

Target deployment: a single **16:9 landscape touchscreen on Windows**. Design and test for touch input and that fixed aspect ratio first; mouse is only a development stand-in.

## Game design (the spec to build toward)

The player mans a **turret** and shoots invading alien ships heading for Earth, following the aliens' invasion plan and breaking it at every link. It is also an **educational game for kids ~8–12**: each scene teaches one real space fact. The full screen-by-screen design lives in `planning/STORYBOARD.md`, and the player's path through the screens is: title → sign-in → (per scene) briefing → quiz → gameplay → scene cleared → … → victory or game over → results/ranking.

- Aliens attack across a **4-scene story campaign** (1 scene = 1 level), with difficulty rising each scene: **ISS (first contact) → Moon (alien forward base) → Mars (aliens mining fuel) → Earth orbit (final stand)**. Score, timer, and quiz tally carry across the whole campaign; energy does not.
- An **energy bar** decreases whenever an alien ship gets through ("getting through" means reaching the station/base or escaping with ore, per scene); if it hits zero, the game ends. Its starting level each scene is set by the pre-battle quiz answer (it does not carry between scenes).
- **Educational layer:** each scene's mission briefing shows one true "DID YOU KNOW?" space fact; a multiple-choice **quiz** on that fact runs *before* the battle and sets starting energy — correct = full bar + bonus score, wrong = partial bar (~70%) with the correct answer shown, no other penalty. Facts and questions live in a per-scene data table so content is extensible.
- Aliens fly in varied patterns — **direct / strafe / weave / swoop** — introduced scene by scene; Mars adds a slow, armored, high-value **ore carrier**.
- Clearing all 4 scenes wins, showing the message **"Yay!! We protected Earth!"** (use this text verbatim).
- Supporting systems the build needs: a **sign-in screen** before play, a **timer**, and a **ranking/leaderboard** system (persisted locally in a `user://` file).

When adding features, keep these three subsystems (sign-in, timer, ranking) as distinct concerns — they outlive any single level and likely belong in autoload singletons rather than per-scene logic.

## Engine configuration (already set in `project.godot`)

- Renderer: `gl_compatibility` (desktop and mobile both) — stick to features supported by this renderer; avoid Forward+/Mobile-only rendering features.
- 3D physics engine: **Jolt Physics**.
- Windows rendering device driver: `d3d12`.

## Working in this project

- Open in the editor: `godot --editor --path .` (or `godot -e`). The Godot 4.6 editor is the primary tool — most scene, node, and resource wiring happens through the UI, not by hand-editing `.tscn`/`.tres` files. (Note: `godot` is not currently on this machine's PATH — locate/confirm the Godot 4.6 binary or launch from the installed editor.)
- Run the game from CLI: `godot --path .` runs `run/main_scene`, `res://scenes/Title.tscn`. Pass a scene path as a positional argument (`godot --path . res://scenes/Quiz.tscn`) to boot straight into one screen; the briefing also has dev keys 1–4 to jump scenes.
- Run tests: gdUnit4 is installed (`addons/gdUnit4/`); tests live under `tests/`.
- Export a Windows build: `godot --headless --path . --export-release "Windows Desktop" build/windows/DarkSector.exe` — the preset exists; `build/` is gitignored. The web build goes to `docs/` for GitHub Pages: `godot --headless --path . --export-release "Web" docs/index.html`. A **release** export is also what drops the briefing's dev scene-jump keys, which are gated on `OS.is_debug_build()`.
- `.godot/` is generated cache (gitignored) — never edit it; delete it to force a reimport if assets get stuck.

## Conventions

- GDScript files use `.gd`; scenes `.tscn`; resources `.tres`. Prefer scenes + GDScript unless there's a reason to add C# (no C# / .NET is configured here).
- Cross-scene state (current scene, energy, score, quiz tally, signed-in user) lives in **autoload singletons** registered under `[autoload]` in `project.godot`, not passed manually between scenes: `GameState` (game flow + state/signals), `Leaderboard` (`user://leaderboard.json` persistence), `SceneRouter` (every screen transition), `Audio` (all sound) and `IdleWatch` (returns an abandoned kiosk to the title), loaded in that order. Note that autoload identifiers do **not** resolve in a script run with `-s` that replaces the main loop — flow harnesses have to run as a scene.
- **Sound goes through `Audio.play("name")` and nothing else** — never a path, never an `AudioStreamPlayer` in a gameplay scene. A sound whose file is missing is a `push_warning` and silence, deliberately, so a kiosk never stops for it; that also means a typo is invisible, which is why `tests/audio_test.gd` lists every name the code calls and checks it against the disk. Add a `play()` call, add the name to that list. Every `BaseButton` gets its click automatically when it enters the tree (opt out with the `silent_button` group); the music bed is picked by `SceneRouter._go_to()` and nowhere else.
- The files under `assets/audio/` are **placeholders** written by `tools/gen_placeholder_audio.py` (Python stdlib only, seeded so re-running doesn't churn the repo). Replace one by dropping a `.wav` with the same name in the same folder — no code changes. Regenerate with `python tools/gen_placeholder_audio.py`, then let Godot reimport.
- The title's attract stills (`assets/backdrop/destination_1..4.png`) are **photographs of the real `Game.tscn` scenes** with the HUD hidden. Re-shoot them if the scene looks change, or the attract screen advertises a game that no longer exists.
- Per-scene content (story line, fact card, quiz, spawn table, backdrop) belongs in one **campaign data table** (`CampaignData.gd`) that briefing, quiz, HUD, and spawner all read from — adding a fact or a 5th scene should be a data change, not a code change.
- Current layout: gameplay scenes in `res://scenes/` (`Game`, `Turret`, `AlienShip`, `Laser`, `HitEffect`) and their scripts in `res://scripts/`. Extend these rather than recreating them; keep the `scenes/`–`scripts/` split.
- Hand-editing a `.tscn` to give a script a node reference (`@export var x: SomeNode`) needs
  `node_paths=PackedStringArray("x", …)` on the `[node …]` line as well as the `x = NodePath(…)`
  property. The editor writes both; writing only the property fails **silently** — the export
  stays null, nothing errors, and the feature just doesn't happen. `scenes/Game.tscn`'s
  `SceneLook` node is the worked example.
- Stay within GL-Compatibility renderer features — prefer `CPUParticles3D` over `GPUParticles3D`, avoid Forward+/Mobile-only effects.
- 3D art comes out of Blender via a checked-in export script, not a manual File > Export. That's `blender/export_turret.py` (run it from Blender's Scripting tab, or `exec(open(...).read())` in a Blender MCP session). It measures pivots from the geometry, re-origins each part, decimates to a triangle budget and caps texture sizes — the raw Tripo models are ~2.4M tris with 170 textures and cannot ship as-is. It prints the pivot/muzzle offsets that `scenes/Turret.tscn` hard-codes, so re-run it after editing the model and update the scene if those numbers move. Source scenes are never modified: it works on throwaway copies.
- That script also finishes Tripo's raw output, which ships flat matte (roughness 0.9, no metallic) and unbalanced. `TEXTURE_GRADE` and `SURFACE_FINISH` name the parts to treat: textures are white-balanced onto the turret's average hue, levelled and given a gentle contrast curve in linear space, and the BSDF gets a lower roughness so large curved surfaces catch a form-defining highlight. Balancing is measured per *collection*, not per part — collections from the same Tripo run can carry opposite casts. Keep metallic low: GL-Compatibility has no reflection probe or sky here, so metal has nothing to reflect and goes black.
- `PARTS` in that script maps each export to the Blender collections it's built from: `gun` and `base` (the turret, to `assets/object/turret/`) and `hull` — the curved ISS station surface the turret is bolted to, built from `ISS_TurretBase1`/`2`, written to `assets/object/iss/`. The hull is exported on the *pedestal's* pivot, so it drops into Godot already lined up with the turret rather than needing to be positioned against it by hand. Its on-screen framing is then tuned purely through the `ISSHull` node's scale in `Game.tscn`.
- `blender/export_alien.py` is the companion script for the alien saucer (`AlienShip.blend` → `assets/object/alien/alien_ship.glb`), same pipeline, different subject. Two things differ deliberately. It decimates harder and caps textures smaller (9k tris, 256px) because several aliens are alive at once, where the turret is a single instance. And it applies `SURFACE_FINISH` but **no** white balance: that grade exists to make the player's own hardware read as one material family, and pulling the aliens' purple hull and green pilot onto the turret's grey would throw away the strongest colour contrast on the gameplay screen. It also joins every part into one mesh, so an alien is one node in the scene tree instead of 61, and yaws the model so the pilot faces Godot's +Z — the direction the ships fly. It prints the bounds that the collision shape in `scenes/AlienShip.tscn` is sized to, so re-run it after editing the model and update the scene if they move.
- That yaw assumes **the saucer faces +X in the .blend** — check it in Blender's Numpad-3 (Right) view, where you should be looking the pilot in the face, and don't infer it from the bounding box: the saucer is nearly as wide as it is long, so which axis is longer flips with small edits and says nothing about which end is the nose. Get it wrong and the ships fly home tail-first, which is only obvious close to the camera — at spawn distance the face is a few pixels and either orientation looks the same. Park one in front of the camera to check.
- Files are UTF-8 (`.editorconfig`).
