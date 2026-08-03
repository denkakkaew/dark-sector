class_name CampaignData
extends RefCounted
## The campaign's content table: one entry per scene, read by everything.
##
## The storyboard's "extensible" principle lives here — the briefing, the quiz,
## the HUD and the spawner all read this table, so adding a fact or a fifth
## scene is a data change rather than a code change.
##
## Phase 5 uses `name` and `wave`. The story/fact/quiz fields are already filled
## in from `planning/STORYBOARD.md` so Phases 6–7 are wiring rather than writing.
##
## Scene indices are **1-based** everywhere (SCENE 1·ISS … SCENE 4·EARTH) to
## match the HUD; use `scene()` / `wave()` rather than indexing `SCENES` directly.

## Flight-mode weights are positional, in `AlienShip.FlightMode` order. Kept as
## plain numbers rather than enum keys so this table has no dependency on the
## gameplay scripts — it is read by the briefing and quiz screens too.
const MODE_DIRECT: int = 0
const MODE_STRAFE: int = 1
const MODE_WEAVE: int = 2
const MODE_SWOOP: int = 3

## Per-scene content and difficulty. `wave` fields:
##
## - `count` — aliens in the wave; the scene is cleared once all of them are
##   resolved (shot down or got through).
## - `interval` — seconds between spawns.
## - `speed` — alien travel speed.
## - `mode_weights` — relative likelihood of each flight mode, MODE_* order.
##   The storyboard introduces the modes scene by scene, so early scenes leave
##   the later modes at 0.
## - `ore_carriers` — Mars' slow armoured carriers. Phase 6 implements them;
##   the number they should spawn is recorded here now.
## - `time_limit` — seconds before the scene ends on its own. A safety valve,
##   not the main pressure: each wave takes roughly half this to fly itself out,
##   so a scene normally ends by being cleared. It exists so an idle kiosk can
##   never sit in a scene forever.
##
## `accent` is the scene's signature colour, from the storyboard's per-scene
## palette. The briefing and quiz tint themselves with it so the four missions
## read as different places before any real art exists; Phase 6's backdrops and
## fog read from the same field, so the screens and the battle stay in step.
const SCENES: Array = [
	{
		"name": "ISS",
		"title": "ISS — First Contact",
		"accent": Color(0.24, 0.55, 0.9),
		"story": "Alien scouts are attacking the International Space Station — man the turret!",
		"fact": "The ISS orbits ~400 km above Earth at ~28,000 km/h. Astronauts on board see 16 sunrises every day!",
		"question": "How many sunrises do ISS astronauts see each day?",
		"answers": ["1", "16", "100"],
		"correct": 1,
		"wave": {
			"count": 12,
			"interval": 1.6,
			"speed": 7.0,
			"mode_weights": [0.85, 0.15, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 45.0,
		},
	},
	{
		"name": "MOON",
		"title": "The Moon — Forward Base",
		"accent": Color(0.62, 0.66, 0.72),
		"story": "The aliens are building a secret base on the far side of the Moon. Stop the landers!",
		"fact": "The Moon is 384,400 km from Earth, and its gravity is only 1/6 of ours. We always see the same side!",
		"question": "How strong is the Moon's gravity compared to Earth's?",
		"answers": ["The same", "One sixth", "Double"],
		"correct": 1,
		"wave": {
			"count": 16,
			"interval": 1.3,
			"speed": 8.5,
			"mode_weights": [0.5, 0.5, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 50.0,
		},
	},
	{
		"name": "MARS",
		"title": "Mars — The Mining Raid",
		"accent": Color(0.82, 0.38, 0.2),
		"story": "Alien drones are stealing minerals from Mars to fuel their fleet. Stop the ore carriers!",
		"fact": "Mars is red because of iron rust, and it has the tallest volcano in the solar system: Olympus Mons.",
		"question": "Why does Mars look red?",
		"answers": ["Its soil is full of iron rust", "It is very hot", "Aliens painted it"],
		"correct": 0,
		"wave": {
			"count": 20,
			"interval": 1.1,
			"speed": 9.5,
			"mode_weights": [0.3, 0.25, 0.45, 0.0],
			"ore_carriers": 3,
			"time_limit": 55.0,
		},
	},
	{
		"name": "EARTH",
		"title": "Earth Orbit — The Last Stand",
		"accent": Color(0.86, 0.24, 0.28),
		"story": "This is it — the alien armada has reached Earth. Hold the line, defender!",
		"fact": "Earth's atmosphere and magnetic field protect us from space radiation every single day.",
		"question": "What shields Earth from space radiation?",
		"answers": ["Its atmosphere and magnetic field", "Clouds", "Satellites"],
		"correct": 0,
		"wave": {
			"count": 26,
			"interval": 0.85,
			"speed": 11.0,
			"mode_weights": [0.25, 0.25, 0.25, 0.25],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
]


## Number of scenes in the campaign — the campaign length is the table's length.
static func count() -> int:
	return SCENES.size()


## The entry for a 1-based scene index, clamped to the table.
static func scene(index: int) -> Dictionary:
	return SCENES[clampi(index - 1, 0, SCENES.size() - 1)]


## Just the spawn table for a 1-based scene index.
static func wave(index: int) -> Dictionary:
	return scene(index)["wave"]


## Display name for the HUD's scene indicator ("ISS", "MOON", …).
static func scene_name(index: int) -> String:
	return scene(index)["name"]


## The scene's signature colour, for screens and backdrops to tint themselves.
static func accent(index: int) -> Color:
	return scene(index)["accent"]
