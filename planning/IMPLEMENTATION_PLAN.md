# Dark Sector — Phased Implementation Plan

## Context

**Dark Sector** is a 16:9 landscape touchscreen arcade game (Godot 4.6, GL Compatibility
renderer, Jolt 3D physics) targeting a single Windows kiosk, aimed at kids ~8–12. The player
mans a turret and fights a **4-scene story campaign** — **ISS → Moon → Mars → Earth orbit** —
with an **educational layer**: each scene's mission briefing teaches one real space fact, and
a post-scene quiz on that fact refills energy / grants bonus score. The full screen-by-screen
design lives in `planning/STORYBOARD.md` — that document is the spec this plan builds toward.

**Current build state** (repo is no longer a bare scaffold):

- **Done (Phases 1–3):** `Game.tscn` with camera/light/environment; `AlienShip.tscn` with four
  flight modes (DIRECT / STRAFE / WEAVE / SWOOP); `Turret.tscn` with an aim pivot; `Laser.tscn`;
  `HitEffect.tscn` (CPUParticles); `Reticle.gd`; FIRE button + spacebar fire; aim-assist.
- **Also in place:** a web export in `docs/` (GitHub Pages), gdUnit4 test addon,
  `run/main_scene` set to `Game.tscn`.
- **Not yet built:** autoloads (GameState / SceneRouter / Leaderboard), HUD (energy/score/timer),
  scene campaign, briefing/quiz, sign-in, results/ranking.

Decisions locked in with the user:

- **View:** fixed forward 3D camera behind/above the turret; aliens spawn far away and fly in.
- **Controls:** reticle-aimed turret (drag/mouse moves the reticle, the barrel pivots to it,
  with aim-assist); fire on tap/FIRE button/spacebar. Touch-first, mouse as dev stand-in.
- **Campaign:** 4 scenes = 4 levels, difficulty rising each scene; energy/score/timer carry
  across the whole campaign.
- **Educational mechanics:** one "DID YOU KNOW?" fact per briefing + one multiple-choice quiz
  question per scene (3 answers, correct → +energy and bonus score, wrong → no penalty).
- **Leaderboard:** stored locally in a `user://` file (no backend); records score, scene
  reached, quiz tally, time.

Conventions (from CLAUDE.md): GDScript + `.tscn` scenes, cross-scene state in `[autoload]`
singletons, UTF-8 files, stick to GL-Compatibility-safe rendering features.

## Target architecture

**Autoload singletons** (registered under `[autoload]` in `project.godot`) — these outlive
individual scenes:

- `res://autoload/GameState.gd` — current scene index (1–4), energy, score, quiz tally,
  elapsed time, signed-in player name; central game flow signals (`scene_started`,
  `scene_cleared`, `quiz_answered`, `game_over`, `game_won`).
- `res://autoload/SceneRouter.gd` — switches between title / sign-in / briefing / game / quiz /
  results screens via `get_tree().change_scene_to_file()`. Keeps transitions in one place.
- `res://autoload/Leaderboard.gd` — load/save `user://leaderboard.json`, insert+sort scores,
  return top-N.

**Campaign data** — one small data table drives everything per-scene (storyboard's
"extensible" principle). A `CampaignData.gd` (const array or `Resource`) with one entry per
scene: name, backdrop settings, story line, fact card text, quiz question + 3 answers +
correct index, and the spawn table (alien count, speed, cadence, flight-mode weights,
ore-carrier weight). Briefing, quiz, HUD, and spawner all read from this — adding facts or a
5th scene is a data change, not a code change.

**Scenes** under `res://scenes/`:

- `Title.tscn` (boot scene, set as `run/main_scene`) → SignIn.
- `SignIn.tscn`, `Briefing.tscn`, `Game.tscn` (exists), `Quiz.tscn`, `Results.tscn`
  (win/lose + leaderboard).
- Gameplay sub-scenes (exist): `Turret.tscn`, `AlienShip.tscn`, `Laser.tscn`, `HitEffect.tscn`;
  plus a HUD layer (exists as a bare CanvasLayer in `Game.tscn` — grows in Phase 4).

**Scripts** under `res://scripts/` (current layout — keep it).

---

## Phase 1 — Alien ships flying on screen ✅ DONE

Aliens spawn far out and fly toward the camera with wobble; despawn past the Earth plane
(`reached_earth` signal exists). Extended beyond plan: four flight modes.

## Phase 2 — Turret at the bottom, movable/aimable ✅ DONE

Turret with aim pivot; reticle-driven aiming (drag/mouse/touch), aim-assist cone.

## Phase 3 — Shooting: laser, reticle, hit effect ✅ DONE

Lasers from the muzzle with cooldown; FIRE button + spacebar; CPUParticles hit effect.

---

## Phase 4 — Score & energy system + HUD

**Goal:** destroying aliens awards points; energy drops when aliens get through.

- Add `GameState.gd` autoload: `score`, `energy` (starts at max), `quiz_correct_count`,
  signals `score_changed`, `energy_changed`, `game_over`.
- Alien destroyed → `GameState.add_score(points)`. Alien reaching the line
  (`reached_earth` — rename or alias to `got_through`, since in scenes 1–3 it means reaching
  the station / base / escaping with ore) → `GameState.take_damage()`. Energy 0 → `game_over`.
- Build out the HUD (`CanvasLayer` in `Game.tscn`): energy bar (`TextureProgressBar`),
  scene indicator (`SCENE 1·ISS`), timer label, score label — the top bar from the storyboard.
  Energy bar flashes red + screen-edge pulse on a leak (storyboard beat 4b).
- Floating `+points` popup at the kill position (storyboard beat 4a).
- **Verify:** kills raise score; leaked aliens drain the energy bar with red feedback; bar at 0
  ends the game.

## Phase 5 — Wave & timer system

**Goal:** a scene = one timed wave driven by data, not the ad-hoc spawn loop.

- `GameState.gd`: per-scene timer; scene ends when the wave is cleared (all spawned aliens
  resolved) or the timer elapses.
- Spawner in `Game.gd` becomes table-driven: reads count / cadence / speed / flight-mode
  weights from the current `CampaignData` entry instead of hard-coded values.
- HUD shows remaining time.
- **Verify:** a scene runs to completion (cleared or timed out) and signals `scene_cleared`.

## Phase 6 — 4-scene campaign (ISS → Moon → Mars → Earth)

**Goal:** the storyboard's story campaign, rising difficulty, distinct look per scene.

- Create `CampaignData.gd` with the four scene entries (names, story lines, facts, quiz
  questions, spawn tables from the storyboard's arc table).
- **Per-scene visuals:** swap `WorldEnvironment` sky/fog colors + a simple backdrop per scene
  (ISS: blue Earth glow below; Moon: grey horizon; Mars: red/ochre; Earth finale: dark +
  red alert tint). Keep it GL-Compatibility-safe (colors, gradients, simple meshes — no
  fancy sky shaders needed).
- **Ore carrier** (Mars): an `AlienShip` variant — slower, takes 2–3 hits (add `hit_points`),
  worth more score. Weighted into the Mars spawn table only.
- Flow: scene 1 → 2 → 3 → 4 with the spawn tables escalating; clearing scene 4 → win
  (**"Yay!! We protected Earth!"**). Energy 0 at any point → lose.
- `Results.tscn` (first pass): win/lose message, scene reached, final score.
- **Verify:** play all 4 scenes to the win message; each scene visibly changes backdrop and
  difficulty; Mars spawns ore carriers; lose path shows game-over with the scene name.

## Phase 7 — Educational layer: mission briefing + quiz

**Goal:** the storyboard's screens 3 and 6 — fact in, quiz out, energy as the reward.

- `Briefing.tscn`: mission number, scene title over a backdrop color, story line with the
  player's name, "DID YOU KNOW?" fact card, 3·2·1 countdown → auto-starts the scene. All text
  from `CampaignData`.
- `Quiz.tscn`: one question, three large touch buttons (from `CampaignData`). Correct →
  `GameState.restore_energy(amount)` + bonus score + celebratory banner; wrong → friendly
  "the answer is…" banner, no penalty. ~2 s feedback, then route to the next briefing (or
  Victory after scene 4).
- Wire the flow in `SceneRouter`: briefing → game → (cleared) → quiz → next briefing / victory.
- **Verify:** each scene shows its fact before and its question after; a correct answer
  visibly refills the energy bar; a wrong answer costs nothing and shows the correct answer.

## Phase 8 — Title, sign-in + ranking/leaderboard

**Goal:** the kiosk frame — attract screen, name entry, persistent local leaderboard.

- `Title.tscn`: logo, tagline, START + Ranking buttons; set as `run/main_scene`. (Attract-mode
  backdrop cross-fade is a polish item.)
- `SignIn.tscn`: `LineEdit` for player name + PLAY button (disabled until non-empty,
  touch-friendly sizes). Store name in `GameState`. Godot's on-screen keyboard appears on
  touch; a custom kiosk keyboard is a polish item if needed.
- `Leaderboard.gd`: read/write `user://leaderboard.json` — array of
  `{name, score, scene_reached, quiz_correct, quiz_total, time}` — insert on game end, keep
  sorted top-N.
- `Results.tscn` (full version): ranked board with SCORE / SCENE / QUIZ / TIME columns,
  current run highlighted; Play Again / Sign Out / Title buttons.
- **Verify:** sign in → play → run is saved with scene + quiz tally and appears ranked;
  persists across restarts; Ranking from the title shows the board view-only.

## Phase 9 — Polish (etc.)

Sound effects (fire/explosion/quiz-correct chime), background music, screen-shake,
title-screen attract mode, touch target tuning for the kiosk, refresh the `docs/` web export,
and an export preset for **Windows Desktop**
(`godot --headless --export-release "Windows Desktop" <out.exe>`). Scope confirmed with user
after Phase 8.

---

## Files to create (representative)

```
project.godot                        # add [autoload] entries; run/main_scene → Title.tscn
res://autoload/GameState.gd
res://autoload/SceneRouter.gd
res://autoload/Leaderboard.gd
res://scripts/CampaignData.gd        # 4 scene entries: story, fact, quiz, spawn table
res://scenes/Title.tscn    (+ .gd)
res://scenes/SignIn.tscn   (+ .gd)
res://scenes/Briefing.tscn (+ .gd)
res://scenes/Quiz.tscn     (+ .gd)
res://scenes/Results.tscn  (+ .gd)
res://scenes/HUD.tscn      (+ .gd)   # or grow the existing HUD layer in Game.tscn

# Already exist (extend, don't recreate):
res://scenes/Game.tscn       + scripts/Game.gd        # spawner → CampaignData-driven
res://scenes/Turret.tscn     + scripts/Turret.gd
res://scenes/AlienShip.tscn  + scripts/AlienShip.gd   # add hit_points (ore carrier)
res://scenes/Laser.tscn      + scripts/Laser.gd
res://scenes/HitEffect.tscn  + scripts/HitEffect.gd
```

## Verification (overall)

The Godot 4.6 editor is the primary tool — scene/node wiring happens through the UI. Per phase:

- Open the editor: `godot --editor --path .` (note: `godot` is **not currently on PATH** on this
  machine — locate/confirm the Godot 4.6 binary first, or launch from the installed editor).
- Run a specific scene from the editor (F6) during early phases; run the full game
  (`godot --path .`) end-to-end from Title once the router exists.
- Each phase has its own "Verify" line above — confirm that behavior before moving on.
- gdUnit4 is installed — add unit tests for pure-logic pieces (`GameState` energy/score math,
  `Leaderboard` insert/sort/persist, `CampaignData` table integrity: 4 scenes, each with a
  fact, 3 answers, and a valid correct index).
- Test with touch/mouse at 16:9 landscape, the kiosk target.
- Cross-check against `planning/STORYBOARD.md`: every storyboard screen (1–9) exists and the
  win text **"Yay!! We protected Earth!"** appears verbatim.
- Final: refresh the `docs/` web export and produce a Windows export; smoke-test the `.exe`.

## Open notes

- `godot` binary is not on PATH; confirm how to invoke the Godot 4.6 editor on this machine.
- Stay within GL-Compatibility renderer features (prefer `CPUParticles3D` over `GPUParticles3D`,
  avoid Forward+/Mobile-only effects).
- `AlienShip.reached_earth` predates the campaign — in scenes 1–3 "getting through" means
  reaching the station / base / escaping with ore. Rename (or document) when wiring Phase 4.
- Quiz refilling energy means knowledge affects survival (intentional, per storyboard). If the
  employer wants pure skill-based ranking, switch the quiz reward to score-only — one line in
  `Quiz.gd`.
