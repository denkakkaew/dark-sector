# Dark Sector — Phased Implementation Plan

## Context

**Dark Sector** is a 16:9 landscape touchscreen arcade game (Godot 4.6, GL Compatibility
renderer, Jolt 3D physics) targeting a single Windows kiosk. The player controls a turret
on a space station and shoots invading alien ships before they reach Earth. The repo is
currently a bare scaffold (`project.godot` + `icon.svg` only) — no scenes, scripts, or
autoloads exist yet, so every system below is built from scratch.

This plan builds the game incrementally in the phases the user requested, each phase ending
in something runnable. Decisions locked in with the user:

- **View:** fixed forward 3D camera behind/above the turret; alien boxes spawn far away and
  fly toward the camera (toward Earth).
- **Controls:** turret slides left/right on a rail; gun fires straight forward (auto-forward
  fire). Touch-first, mouse as dev stand-in.
- **Leaderboard:** stored locally in a `user://` file (no backend).

Conventions (from CLAUDE.md): GDScript + `.tscn` scenes, cross-scene state in `[autoload]`
singletons, UTF-8 files, stick to GL-Compatibility-safe rendering features.

## Target architecture

**Autoload singletons** (registered under `[autoload]` in `project.godot`) — these outlive
individual scenes:

- `res://autoload/GameState.gd` — current level, energy, score, signed-in player name; central
  game flow signals (`level_started`, `level_cleared`, `game_over`, `game_won`).
- `res://autoload/SceneRouter.gd` — switches between sign-in / game / results scenes via
  `get_tree().change_scene_to_file()`. Keeps scene transitions in one place.
- `res://autoload/Leaderboard.gd` — load/save `user://leaderboard.json`, insert+sort scores,
  return top-N.

**Scenes** under `res://scenes/`:

- `Main` (boot scene, set as `run/main_scene`) → routes to SignIn.
- `SignIn.tscn`, `Game.tscn`, `Results.tscn` (win/lose + leaderboard).
- Gameplay sub-scenes: `Turret.tscn`, `AlienShip.tscn`, `Laser.tscn`, plus a HUD scene/layer.

**Scripts** under `res://scripts/` (or co-located with scenes).

Folder layout to create: `res://autoload/`, `res://scenes/`, `res://scripts/`,
`res://assets/` (sounds/particles later).

---

## Phase 1 — Alien ships flying on screen

**Goal:** a 3D box alien flies through a fixed-camera scene.

- Create `Game.tscn` root (`Node3D`) with a `Camera3D` (fixed, looking down +Z out toward
  space), a `DirectionalLight3D`, and a `WorldEnvironment` (simple dark/space background).
- `AlienShip.tscn`: `CharacterBody3D` (or `Area3D` + `MeshInstance3D` `BoxMesh`) — start with a
  box mesh + `BoxShape3D`. Script moves it toward Earth (toward camera / decreasing depth) at a
  configurable `speed`. Emits `reached_earth` and despawns when it crosses the Earth plane.
- Temporary spawner in `Game.gd` to spawn a few aliens at intervals at random X so motion is
  visible.
- **Verify:** run scene, boxes spawn far and fly toward the camera, then despawn.

## Phase 2 — Turret at the bottom, movable left/right

**Goal:** a large turret at the bottom of the view that slides left/right.

- `Turret.tscn`: `Node3D` with base + barrel meshes (boxes/cylinders), positioned at the
  bottom-center in front of the camera.
- `Turret.gd`: clamp horizontal movement to screen-edge X bounds. Input: touch drag / mouse X
  → target X (touch-first via `InputEventScreenDrag` / `InputEventScreenTouch`, with mouse
  fallback for dev). Also support keyboard left/right for quick dev testing.
- Add the turret to `Game.tscn`.
- **Verify:** drag/move turret left-right, confirm it stays within bounds.

## Phase 3 — Shooting: laser, pointer/reticle, hit effect

**Goal:** turret fires lasers forward; aliens react when hit.

- `Laser.tscn`: `Area3D` + thin glowing box/cylinder mesh, travels straight forward (+Z) at high
  speed; despawns off-range. On `area_entered`/`body_entered` with an alien → trigger hit.
- `Turret.gd`: fire on tap / mouse click / spacebar with a fire-rate cooldown; spawn laser from
  the barrel muzzle (`Marker3D`).
- **Pointer:** a forward-projected reticle/aim line from the barrel so the player sees where
  shots go (since fire is straight-forward, the reticle shows the barrel's forward path).
- **Hit effect:** on hit, alien plays a destruction effect (`GPUParticles3D`/`CPUParticles3D`
  burst — use `CPUParticles3D` to stay GL-Compatibility-safe) + brief flash, then `queue_free()`.
- **Verify:** firing destroys aliens with a visible effect; reticle shows aim.

## Phase 4 — Score system

**Goal:** destroying aliens awards points; energy drops when aliens reach Earth.

- In `GameState.gd`: `score`, `energy` (starts at max), signals `score_changed`,
  `energy_changed`.
- Alien destroyed → `GameState.add_score(points)`. Alien reaching Earth → `GameState.take_damage()`
  (decrement energy). Energy hits 0 → `game_over` signal.
- HUD scene (`CanvasLayer`): score label + energy bar (`ProgressBar`/`TextureProgressBar`),
  bound to the signals.
- **Verify:** kills raise score; leaked aliens drain the energy bar; bar at 0 ends the game.

## Phase 5 — Round & timer system

**Goal:** rounds with a per-round timer.

- `GameState.gd`: round/wave tracking; a round = a wave of aliens with a `Timer`. Round ends when
  the wave is cleared or the timer elapses.
- Spawner becomes wave-driven (count, spawn cadence, speed per wave) instead of the Phase-1 ad-hoc
  loop.
- HUD shows remaining time and current round.
- **Verify:** a round runs to completion (cleared or timed out) and advances.

## Phase 6 — Level system (3 levels, rising difficulty)

**Goal:** 3 levels of increasing difficulty; clearing all 3 wins.

- Define per-level config (alien count, speed, spawn rate, points) — a small data table or
  `LevelData` resource array in `GameState.gd`.
- Flow: Level 1 → 2 → 3; clearing level 3 → win screen **"Yay!! We protected Earth!"**.
  Energy 0 at any point → lose screen.
- `Results.tscn` shows win/lose message and final score.
- **Verify:** play through all 3 levels to the win message; lose path shows game-over.

## Phase 7 — Sign-in screen + ranking/leaderboard

**Goal:** name entry before play; persistent local leaderboard.

- `SignIn.tscn`: `LineEdit` for player name + Start button (touch-friendly large controls).
  Store name in `GameState`. Set `Main`/SignIn as the boot scene via `run/main_scene`.
- `Leaderboard.gd`: read/write `user://leaderboard.json` (array of `{name, score, time}`),
  insert on game end, keep sorted top-N.
- `Results.tscn`: after a game, save the run and show the ranked leaderboard with the current
  run highlighted; buttons to play again / back to sign-in.
- **Verify:** sign in → play → score is saved and appears ranked; persists across restarts.

## Phase 8 — Polish (etc.)

Sound effects (fire/explosion), background music, screen-shake, basic main-menu polish, touch
target tuning for the kiosk, and an export preset for **Windows Desktop**
(`godot --headless --export-release "Windows Desktop" <out.exe>`). Scope confirmed with user
after Phase 7.

---

## Files to create (representative)

```
project.godot                      # add [autoload] entries; set run/main_scene
res://autoload/GameState.gd
res://autoload/SceneRouter.gd
res://autoload/Leaderboard.gd
res://scenes/Main.tscn
res://scenes/SignIn.tscn  (+ .gd)
res://scenes/Game.tscn    (+ Game.gd)
res://scenes/Results.tscn (+ .gd)
res://scenes/Turret.tscn  (+ Turret.gd)
res://scenes/AlienShip.tscn (+ AlienShip.gd)
res://scenes/Laser.tscn   (+ Laser.gd)
res://scenes/HUD.tscn     (+ HUD.gd)
```

## Verification (overall)

The Godot 4.6 editor is the primary tool — scene/node wiring happens through the UI. Per phase:

- Open the editor: `godot --editor --path .` (note: `godot` is **not currently on PATH** on this
  machine — locate/confirm the Godot 4.6 binary first, or launch from the installed editor).
- Run a specific scene from the editor (F6) during early phases; run the full game (`godot --path .`)
  once `run/main_scene` is set.
- Each phase has its own "Verify" line above — confirm that behavior before moving on.
- Test with touch/mouse at 16:9 landscape, the kiosk target.
- Final: produce a Windows export and smoke-test the `.exe`.

## Open notes

- `godot` binary is not on PATH; first implementation step should confirm how to invoke the
  Godot 4.6 editor on this machine.
- Stay within GL-Compatibility renderer features (prefer `CPUParticles3D` over `GPUParticles3D`,
  avoid Forward+/Mobile-only effects).
