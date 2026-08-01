# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Dark Sector** — an alien-shooting arcade game built in **Godot 4.6** (GL Compatibility renderer, Jolt physics for 3D). The core shooting loop is **playable today**: `Game.tscn` (set as `run/main_scene`) runs a turret that aims via a reticle and fires lasers at alien ships flying in four flight modes, with a particle hit effect. A web build is exported under `docs/` for GitHub Pages, and the gdUnit4 test addon is installed. The surrounding screens (title, sign-in, briefing, quiz, HUD, scene campaign, results/ranking) are designed but not yet built — see `planning/STORYBOARD.md` for the full spec and `planning/IMPLEMENTATION_PLAN.md` for the phased roadmap and what's done vs. pending.

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
- Run the game from CLI: `godot --path .` runs `run/main_scene`, currently `res://scenes/Game.tscn` (the playable gameplay scene). Once the flow screens exist this becomes `Title.tscn`.
- Run tests: gdUnit4 is installed (`addons/gdUnit4/`); tests live under `tests/`.
- Export a Windows build: configure an export preset in the editor, then `godot --headless --export-release "Windows Desktop" <output.exe>`. The web/kiosk build is exported to `docs/` for GitHub Pages.
- `.godot/` is generated cache (gitignored) — never edit it; delete it to force a reimport if assets get stuck.

## Conventions

- GDScript files use `.gd`; scenes `.tscn`; resources `.tres`. Prefer scenes + GDScript unless there's a reason to add C# (no C# / .NET is configured here).
- Cross-scene state (current scene, energy, score, quiz tally, signed-in user) should live in **autoload singletons** registered under `[autoload]` in `project.godot`, not passed manually between scenes. The planned singletons are `GameState` (game flow + state/signals), `SceneRouter` (screen transitions), and `Leaderboard` (`user://` persistence) — none exist yet.
- Per-scene content (story line, fact card, quiz, spawn table, backdrop) belongs in one **campaign data table** (`CampaignData.gd`) that briefing, quiz, HUD, and spawner all read from — adding a fact or a 5th scene should be a data change, not a code change.
- Current layout: gameplay scenes in `res://scenes/` (`Game`, `Turret`, `AlienShip`, `Laser`, `HitEffect`) and their scripts in `res://scripts/`. Extend these rather than recreating them; keep the `scenes/`–`scripts/` split.
- Stay within GL-Compatibility renderer features — prefer `CPUParticles3D` over `GPUParticles3D`, avoid Forward+/Mobile-only effects.
- Files are UTF-8 (`.editorconfig`).
