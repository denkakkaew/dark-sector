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
## Each scene carries a **pool** of quiz variants rather than a single question,
## and one is drawn per scene per run (see `random_quiz_variant()`). A kiosk gets
## played over and over by the same kids, and a fact they have already been shown
## teaches nothing the second time.
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
##   not the main pressure: a wave flies itself out in well under this, so a
##   scene normally ends by being cleared. It exists so an idle kiosk can never
##   sit in a scene forever. One flat minute for every scene — the later waves
##   are longer, but they are also faster, so they do not need more clock.
##
## `quiz` is the scene's pool of teaching moments — one is drawn per run and the
## fact card and the quiz screen both read that same one, so the question is
## always about the fact the player was just shown. Each entry is self-contained:
##
## - `fact` — the fact card screen's "DID YOU KNOW?". True, and short enough to read
##   at a glance; the card is sized for roughly the length of the ones here.
## - `question` / `answers` / `correct` — three big touch buttons and the index of
##   the right one. The correct index is varied deliberately across the pool: kids
##   spot "it's always the first one" long before they learn any astronomy.
##
## `accent` is the scene's signature colour, from the storyboard's per-scene
## palette. The briefing, fact card and quiz tint themselves with it so the four missions
## read as different places before any real art exists; the `look` block below
## keeps the battle in step with them.
##
## `look` is the battlefield's dressing, read by `SceneLook.gd`:
##
## - `space` — what the camera sees where nothing else is: the sky colour.
## - `ambient` / `sun` / `fill` — the scene's lighting. Ambient is what lifts the
##   turret and the aliens out of black, so it carries most of a scene's mood.
## - `photo` — the painted backdrop authored in `Game.tscn`. `texture` is the
##   image to hang on it, `tint` knocks it back so it stays scenery, and a scene
##   with nothing to hang sets `visible` false. Its placement was tuned by hand
##   and stays where it is; only its *height* moves, so an image of a different
##   shape keeps its proportions instead of being stretched to Earth's.
## - `bodies` — flat-shaded spheres the scene builds for itself. A huge one
##   parked low is a planet surface curving away below the guns; a small one high
##   up is a distant world. `mottle` dusts the surface with noise (craters, dust);
##   `emission` keeps a distant body from going black on its night side. A scene
##   whose `photo` already paints its ground and horizon has no need of them.
## - `stars` — density of the procedural star field, 0 for a sky that has none
##   (Mars' is full of dust, and the photographic backdrops bring their own).
const SCENES: Array = [
	{
		"name": "ISS",
		"title": "ISS — First Contact",
		"accent": Color(0.24, 0.55, 0.9),
		"story": "Alien scouts are attacking the International Space Station — man the turret!",
		"quiz": [
			{
				"fact": "The ISS orbits ~400 km above Earth at ~28,000 km/h. Astronauts on board see 16 sunrises every day!",
				"question": "How many sunrises do ISS astronauts see each day?",
				"answers": ["1", "16", "100"],
				"correct": 1,
			},
			{
				"fact": "The ISS races all the way around the planet once every 90 minutes — 16 laps of Earth every single day.",
				"question": "How long does the ISS take to circle Earth once?",
				"answers": ["About 24 hours", "About a month", "About 90 minutes"],
				"correct": 2,
			},
			{
				"fact": "The ISS runs entirely on sunlight: eight huge solar wings turn it into all the electricity the station needs.",
				"question": "Where does the ISS get its electricity?",
				"answers": ["From giant solar panels", "From a very long cable to Earth", "From petrol engines"],
				"correct": 0,
			},
			{
				"fact": "The ISS is the biggest thing humans have ever built in space — end to end it is about as long as a football pitch.",
				"question": "How big is the ISS?",
				"answers": ["About the size of a bus", "About as long as a football pitch", "As big as the Moon"],
				"correct": 1,
			},
			{
				"fact": "Everything on the ISS floats, so astronauts sleep in sleeping bags clipped to the wall and their tools are tethered down.",
				"question": "Why do ISS astronauts clip their sleeping bags to the wall?",
				"answers": ["To keep warm", "To stop the bag getting dirty", "So they don't float away while they sleep"],
				"correct": 2,
			},
		],
		# Low orbit: the Earth photograph fills the lower view and lights the
		# station. This is the look the gameplay scene was built against.
		"look": {
			"space": Color(0.02, 0.02, 0.06),
			"ambient": Color(0.12, 0.12, 0.18),
			"sun": {"color": Color(1, 1, 1), "energy": 0.35},
			"fill": {"color": Color(0.88, 0.92, 1), "energy": 0.55},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/space_earth.png",
				"tint": Color(0.7, 0.7, 0.7),
			},
			"bodies": [],
			"stars": 0.0,
		},
		"wave": {
			"count": 12,
			"interval": 1.6,
			"speed": 7.0,
			"mode_weights": [0.85, 0.15, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
	{
		"name": "MOON",
		"title": "The Moon — Forward Base",
		"accent": Color(0.62, 0.66, 0.72),
		"story": "The aliens are building a secret base on the far side of the Moon. Stop the landers!",
		"quiz": [
			{
				"fact": "The Moon is 384,400 km from Earth, and its gravity is only 1/6 of ours. We always see the same side!",
				"question": "How strong is the Moon's gravity compared to Earth's?",
				"answers": ["The same", "One sixth", "Double"],
				"correct": 1,
			},
			{
				"fact": "The Moon has no air, so there is no wind and no rain. The footprints Apollo astronauts left in 1969 are still there today.",
				"question": "Why are the Apollo footprints still on the Moon?",
				"answers": ["There is no wind or rain to wipe them away", "They were carved into solid rock", "Astronauts repaint them every year"],
				"correct": 0,
			},
			{
				"fact": "The Moon turns once for every lap around Earth, so the same face always points at us. Nobody saw its far side until 1959!",
				"question": "Why do we always see the same side of the Moon?",
				"answers": ["It is held still and never turns", "It turns once for every lap around Earth", "Its other side is invisible"],
				"correct": 1,
			},
			{
				"fact": "The Moon is 384,400 km away — the Apollo astronauts needed about three days to fly there.",
				"question": "How long did the Apollo astronauts take to reach the Moon?",
				"answers": ["About three hours", "About three years", "About three days"],
				"correct": 2,
			},
			{
				"fact": "Sound needs air to travel through, and the Moon has none. Standing side by side, the Moonwalkers still had to talk by radio.",
				"question": "Why did the Moonwalkers talk to each other by radio?",
				"answers": ["There is no air to carry their voices", "The Moon is far too noisy", "They were miles apart from each other"],
				"correct": 0,
			},
		],
		# No air to soften anything: a hard white sun and a black sky. The other
		# surface scene's rule applies here too — the backdrop paints its own
		# regolith, horizon, star field and the storyboard's small blue Earth, so
		# the procedural sphere, the second marble and the generated stars are all
		# gone. Each would have doubled something the image already has, and the
		# ground sphere would have cut the alien base in half.
		"look": {
			"space": Color(0.01, 0.01, 0.02),
			"ambient": Color(0.1, 0.1, 0.13),
			"sun": {"color": Color(1, 1, 0.97), "energy": 0.95},
			"fill": {"color": Color(0.6, 0.65, 0.78), "energy": 0.18},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/moon_surface.png",
				# Straight grey, no colour shift: unlike Mars there is no cast to
				# correct, only a bright lit foreground to knock back so the
				# turret stays in front of the regolith instead of in it.
				"tint": Color(0.62, 0.62, 0.64),
			},
			"bodies": [],
			"stars": 0.0,
		},
		"wave": {
			"count": 16,
			"interval": 1.3,
			"speed": 8.5,
			"mode_weights": [0.5, 0.5, 0.0, 0.0],
			"ore_carriers": 0,
			"time_limit": 60.0,
		},
	},
	{
		"name": "MARS",
		"title": "Mars — The Mining Raid",
		"accent": Color(0.82, 0.38, 0.2),
		"story": "Alien drones are stealing minerals from Mars to fuel their fleet. Stop the ore carriers!",
		"quiz": [
			{
				"fact": "Mars is red because of iron rust, and it has the tallest volcano in the solar system: Olympus Mons.",
				"question": "Why does Mars look red?",
				"answers": ["Its soil is full of iron rust", "It is very hot", "Aliens painted it"],
				"correct": 0,
			},
			{
				"fact": "A day on Mars is almost the same as ours: the planet turns once every 24 hours and 37 minutes.",
				"question": "How long is one day on Mars?",
				"answers": ["Ten times longer than Earth's", "Almost the same as Earth's", "Only ten minutes"],
				"correct": 1,
			},
			{
				"fact": "Olympus Mons on Mars is the tallest volcano in the solar system — about three times the height of Mount Everest.",
				"question": "How does Olympus Mons compare with Mount Everest?",
				"answers": ["About three times taller", "About half as tall", "Exactly the same height"],
				"correct": 0,
			},
			{
				"fact": "Mars has two small, lumpy moons called Phobos and Deimos. They look more like potatoes than like our Moon.",
				"question": "How many moons does Mars have?",
				"answers": ["None at all", "Twelve", "Two"],
				"correct": 2,
			},
			{
				"fact": "Mars pulls with only about a third of Earth's gravity, so the same jump would carry you nearly three times as high.",
				"question": "What would your jump be like on Mars?",
				"answers": ["Exactly the same as on Earth", "Nearly three times higher", "You could not leave the ground"],
				"correct": 1,
			},
		],
		# The only scene with an atmosphere: dust turns the sky rust-pink, mutes
		# the sun and bounces light back up, so nothing here goes fully black.
		# No stars — you cannot see them through the dust.
		#
		# The one scene fought over a painted surface rather than open space. The
		# backdrop carries the mining outpost the aliens are raiding, so the
		# procedural ground sphere the other surface scene uses is gone: the photo
		# paints its own ground, horizon and dust haze, and a sphere in front of it
		# would only cut the outpost in half.
		"look": {
			# The sky is the only one in the campaign that isn't black. Barely any
			# of it survives behind the photo, but it has to agree with the image's
			# own haze at the edges rather than framing it in a darker band.
			"space": Color(0.4, 0.21, 0.16),
			"ambient": Color(0.34, 0.2, 0.16),
			"sun": {"color": Color(1, 0.85, 0.68), "energy": 0.7},
			"fill": {"color": Color(1, 0.66, 0.5), "energy": 0.4},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/mars_surface.png",
				# Knocked further back than Earth's, and towards grey: the image is
				# a saturated orange edge to edge, and the aliens have to stay the
				# most colourful thing on the screen.
				"tint": Color(0.55, 0.51, 0.52),
			},
			"bodies": [],
			"stars": 0.0,
		},
		"wave": {
			"count": 20,
			"interval": 1.1,
			"speed": 9.5,
			"mode_weights": [0.3, 0.25, 0.45, 0.0],
			"ore_carriers": 3,
			"time_limit": 60.0,
		},
	},
	{
		"name": "EARTH",
		"title": "Earth Orbit — The Last Stand",
		"accent": Color(0.86, 0.24, 0.28),
		"story": "This is it — the alien armada has reached Earth. Hold the line, defender!",
		"quiz": [
			{
				"fact": "Earth's atmosphere and magnetic field protect us from space radiation every single day.",
				"question": "What shields Earth from space radiation?",
				"answers": ["Its atmosphere and magnetic field", "Clouds", "Satellites"],
				"correct": 0,
			},
			{
				"fact": "The air we breathe is mostly nitrogen — about 78% of it. Only about a fifth is the oxygen our bodies use.",
				"question": "What is most of Earth's air made of?",
				"answers": ["Oxygen", "Nitrogen", "Carbon dioxide"],
				"correct": 1,
			},
			{
				"fact": "Oceans cover about 71% of Earth's surface. That water is why our planet looks blue from space.",
				"question": "How much of Earth's surface is covered by ocean?",
				"answers": ["About one tenth", "About one third", "About seven tenths"],
				"correct": 2,
			},
			{
				"fact": "Space officially begins just 100 km straight up — a shorter trip than many car journeys, if only you could drive upwards!",
				"question": "How far up does space begin?",
				"answers": ["About 100 km", "About 100 metres", "About a million km"],
				"correct": 0,
			},
			{
				"fact": "Earth is racing around the Sun at about 107,000 km/h, carrying everyone standing on it along for the ride.",
				"question": "How fast is Earth travelling around the Sun?",
				"answers": ["It is standing still", "About 100 km/h, like a car", "About 100,000 km/h"],
				"correct": 2,
			},
		],
		# The darkest scene, and the only one lit in red: everything in front of the
		# backdrop is washed in alert light, and the sun is turned down so the red
		# reads as an alarm rather than as a sunset. The backdrop is the city
		# itself, at night — the thing the whole campaign has been defending, and
		# the only scene where losing has an address.
		"look": {
			"space": Color(0.01, 0.01, 0.03),
			"ambient": Color(0.2, 0.07, 0.09),
			"sun": {"color": Color(1, 0.94, 0.92), "energy": 0.3},
			"fill": {"color": Color(1, 0.34, 0.32), "energy": 0.5},
			"photo": {
				"visible": true,
				"texture": "res://assets/backdrop/earth_city.png",
				# The lightest knock-back in the campaign, and barely shifted: a
				# night city is already dark and mostly black, so the usual push
				# would put the lights out. The small warm bias is the alert light
				# reaching the skyline.
				"tint": Color(0.86, 0.74, 0.76),
			},
			"bodies": [],
			# None: the photograph covers the whole frustum and brings its own.
			"stars": 0.0,
		},
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


## Mars' armoured ore carrier, relative to the ordinary scout of the same scene.
## One dictionary rather than four exports on the variant scene, so the whole
## trade — slow and tough, but worth four kills — is retuned in one place.
##
## Note there is no leak penalty here: a carrier that escapes costs the same
## energy as any other alien. It is worth stopping for the score, not because
## missing it hurts more, and Mars is already the scene that adds weaving.
const ORE_CARRIER := {
	"hit_points": 3,
	"score": 400,
	"speed_scale": 0.55,
	"size": 1.7,
}

## Spawns at the head of a wave that are never carriers, so a scene opens on the
## enemy the player already knows how to shoot.
const ORE_CARRIER_LEAD_IN: int = 3


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


## The battlefield's dressing for a 1-based scene index — see `look` above.
static func look(index: int) -> Dictionary:
	return scene(index)["look"]


## How many quiz variants a scene has to draw from.
static func quiz_count(index: int) -> int:
	return scene(index)["quiz"].size()


## One variant from a scene's pool: the fact card and the question about it.
##
## `variant` is clamped rather than trusted, for the same reason `scene()` clamps
## its index — it is carried in `GameState` across a scene change, and a pool of
## a different length would otherwise be an out-of-bounds crash on the briefing.
static func quiz(index: int, variant: int) -> Dictionary:
	var pool: Array = scene(index)["quiz"]
	return pool[clampi(variant, 0, pool.size() - 1)]


## A fresh variant for a scene, avoiding `previous` where the pool allows it.
##
## The avoidance is the point on a kiosk: the same child plays three runs in a
## row, and drawing them the fact they were shown five minutes ago wastes the
## one screen in the scene that is actually teaching something.
static func random_quiz_variant(index: int, previous: int = -1) -> int:
	var pool_size := quiz_count(index)
	if pool_size <= 1:
		return 0
	var picked := randi() % pool_size
	if picked == previous:
		# One step along rather than re-rolling: a re-roll can land on `previous`
		# again, and this keeps every other variant equally likely.
		picked = (picked + 1 + randi() % (pool_size - 1)) % pool_size
	return picked


## The order a scene's wave arrives in: one entry per spawn, true where an ore
## carrier flies instead of a scout.
##
## Built up front rather than rolled per spawn, because a scene has to end up
## with exactly the number of carriers its table asks for — a per-spawn chance
## would sometimes send none at all, and Mars' whole story is the carriers. They
## are spread one to a band so they arrive spaced out across the wave instead of
## bunching into a convoy, and never in the opening spawns.
static func spawn_plan(index: int) -> Array:
	var table := wave(index)
	var count: int = table["count"]
	var plan: Array = []
	plan.resize(count)
	plan.fill(false)

	var first := mini(ORE_CARRIER_LEAD_IN, count)
	var carriers: int = clampi(table["ore_carriers"], 0, count - first)
	if carriers <= 0:
		return plan

	var band := float(count - first) / float(carriers)
	for i in carriers:
		var start := first + int(i * band)
		var slot := start + randi() % maxi(1, int(band))
		plan[clampi(slot, first, count - 1)] = true
	return plan
