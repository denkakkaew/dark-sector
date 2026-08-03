extends Node3D
## Alien ships patrolling back and forth across the far backdrop, as scenery.
##
## These are **not** targets. They carry no `Area3D`, so the player's lasers pass
## straight through them, and they never approach — they only track sideways.
## Three things keep them from being mistaken for the wave: they fly high above
## the lane the attackers use, they are much further out, and they move at a
## fraction of an attacker's speed.
##
## How many patrol is per-scene data (`backdrop_traffic` in `CampaignData`), so
## Phase 6 can give the Moon, Mars and Earth their own traffic — or none — as
## each backdrop arrives.

const ALIEN_MODEL := preload("res://assets/object/alien/alien_ship.glb")

## How far out a ship travels before turning around. Must be wider than the
## frustum at this depth (~75 units), so the turn itself happens off-camera and
## the player sees a patrol rather than a pirouette.
@export var patrol_half_width: float = 88.0
## Depth band, well behind the attackers' spawn radius of 35.
@export var depth_range := Vector2(-46.0, -40.0)
## Height band. The attackers fly at roughly y 1.5–11, so this sits clear above
## them — the single most important reason these don't read as targets. Measured
## against a screenshot, this band lands in the star field above Earth's limb.
@export var height_range := Vector2(12.0, 22.0)
@export var speed_range := Vector2(5.0, 9.0)
## Big enough to be noticed against the stars, small enough that nobody mistakes
## one for an attacker. At 1.2 they read as specks; much past 2 and they start
## looking like something you were supposed to shoot.
@export var ship_scale: float = 1.9
@export var bob_amplitude: float = 0.6
@export var bob_rate: float = 0.6

var _ships: Array[Dictionary] = []


func _ready() -> void:
	var count: int = CampaignData.scene(GameState.scene_index).get("backdrop_traffic", 0)
	for i in count:
		_add_ship(i, count)


func _add_ship(index: int, total: int) -> void:
	var model: Node3D = ALIEN_MODEL.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * ship_scale

	# Spread the starting positions evenly across the patrol and alternate the
	# headings, so they read as traffic rather than as a convoy.
	var along := (float(index) + 0.5) / float(total)
	var ship := {
		"node": model,
		"x": lerpf(-patrol_half_width, patrol_half_width, along),
		"y": randf_range(height_range.x, height_range.y),
		"z": randf_range(depth_range.x, depth_range.y),
		"heading": 1.0 if index % 2 == 0 else -1.0,
		"speed": randf_range(speed_range.x, speed_range.y),
		"bob": randf() * TAU,
	}
	_ships.append(ship)
	_place(ship)


func _process(delta: float) -> void:
	for ship in _ships:
		ship["x"] += ship["heading"] * ship["speed"] * delta
		if absf(ship["x"]) >= patrol_half_width:
			# Clamped as well as flipped, so a long frame can't strand a ship
			# outside the patrol and leave it reversing every frame.
			ship["x"] = signf(ship["x"]) * patrol_half_width
			ship["heading"] = -ship["heading"]
		ship["bob"] += delta
		_place(ship)


func _place(ship: Dictionary) -> void:
	var node: Node3D = ship["node"]
	var bob: float = sin(ship["bob"] * bob_rate) * bob_amplitude
	node.position = Vector3(ship["x"], ship["y"] + bob, ship["z"])
	# The saucer is modelled facing +Z and look_at aims a node's -Z at its
	# target, so it is given the point behind itself along the way it travels.
	node.look_at(node.global_position - Vector3(ship["heading"], 0.0, 0.0), Vector3.UP)
