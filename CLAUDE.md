# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Dark Sector** — an alien-shooting arcade game built in **Godot 4.6** (GL Compatibility renderer, Jolt physics for 3D). Currently a near-empty project scaffold: only `project.godot` and the icon exist. No scenes, scripts, or `README` have been authored yet, so most architecture decisions are still open.

Target deployment: a single **16:9 landscape touchscreen on Windows**. Design and test for touch input and that fixed aspect ratio first; mouse is only a development stand-in.

## Game design (the spec to build toward)

The player controls a **turret on a space station** and shoots invading alien ships heading for Earth.

- Aliens attack in **3 rounds / levels**, with difficulty rising each level.
- An **energy bar** decreases whenever an alien ship reaches Earth; if it hits zero, the game ends.
- Clearing all 3 levels wins, showing the message **"Yay!! We protected Earth!"**.
- Supporting systems the build needs: a **sign-in screen** before play, a **timer**, and a **ranking/leaderboard** system.

When adding features, keep these three subsystems (sign-in, timer, ranking) as distinct concerns — they outlive any single level and likely belong in autoload singletons rather than per-scene logic.

## Engine configuration (already set in `project.godot`)

- Renderer: `gl_compatibility` (desktop and mobile both) — stick to features supported by this renderer; avoid Forward+/Mobile-only rendering features.
- 3D physics engine: **Jolt Physics**.
- Windows rendering device driver: `d3d12`.

## Working in this project

- Open in the editor: `godot --editor --path .` (or `godot -e`). The Godot 4.6 editor is the primary tool — most scene, node, and resource wiring happens through the UI, not by hand-editing `.tscn`/`.tres` files.
- Run the game headless/from CLI: `godot --path .` (add a main scene first — none is set yet).
- Export a Windows build: configure an export preset in the editor, then `godot --headless --export-release "Windows Desktop" <output.exe>`.
- `.godot/` is generated cache (gitignored) — never edit it; delete it to force a reimport if assets get stuck.

## Conventions

- GDScript files use `.gd`; scenes `.tscn`; resources `.tres`. Prefer scenes + GDScript unless there's a reason to add C# (no C# / .NET is configured here).
- Cross-scene state (current level, energy, score, signed-in user) should live in **autoload singletons** registered under `[autoload]` in `project.godot`, not passed manually between scenes.
- Files are UTF-8 (`.editorconfig`).
