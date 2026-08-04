extends Node3D

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")
const ORE_CARRIER_SCENE := preload("res://scenes/OreCarrier.tscn")
const AlienShip = preload("res://scripts/AlienShip.gd")
const AIM_DISTANCE: float = 20.0

# Screen shake. Small numbers on purpose: the camera is the frame the whole
# scene is composed in — the turret's silhouette, the station plate across the
# bottom corners — and anything big enough to be *noticed* as a shake is big
# enough to break that composition. It should be felt and not seen.
const SHAKE_DECAY: float = 2.6
## Metres of camera travel at full strength.
const SHAKE_OFFSET: float = 0.16
## Degrees of roll at full strength.
const SHAKE_ROLL: float = 0.9
## Per-event strengths, 0–1. A leak shakes hardest: it is the only one of the
## three that costs the player something.
const SHAKE_KILL: float = 0.16
const SHAKE_CARRIER: float = 0.45
const SHAKE_LEAK: float = 0.6

## How far out the aliens are staged. Framing, not difficulty — the per-scene
## difficulty knobs (count, cadence, speed, flight modes) come from CampaignData.
@export var spawn_radius: float = 35.0

@onready var _camera: Camera3D = $Camera3D
@onready var _turret = $Turret
@onready var _reticle = $UI/Reticle
@onready var _hud = $UI/HUD
@onready var _scene_look = $SceneLook

var _reticle_screen_pos: Vector2
var _spawn_timer: float = 0.0
## A finger (or the left mouse button) is down: fire for as long as it is.
var _pointer_held: bool = false
## Current shake strength, 0–1, decaying to nothing.
var _shake: float = 0.0
## The camera's authored transform — where it goes back to between shakes.
var _camera_rest: Transform3D

# The wave, read from CampaignData for whichever scene GameState is on.
var _spawn_interval: float = 1.5
var _alien_speed: float = 8.0
var _mode_weights: Array = []
## Aliens still to spawn. The scene is cleared when this and `_alive` are both 0.
var _to_spawn: int = 0
## Aliens in the air: spawned, not yet shot down and not yet through.
var _alive: int = 0
## One entry per spawn, true where an ore carrier flies instead of a scout.
## Read back-to-front, because `_to_spawn` counts down.
var _spawn_plan: Array = []

func _ready() -> void:
	_reticle_screen_pos = get_viewport().get_visible_rect().size / 2.0
	_camera_rest = _camera.transform
	# A leak is felt here as well as shown on the HUD's bar and edge pulse. The
	# HUD owns the two on-screen tells; the camera is this node's to move.
	GameState.damage_taken.connect(func(_amount: float) -> void: shake(SHAKE_LEAK))
	# Both ways a scene ends pause the tree behind a card, which would strand the
	# camera wherever the last shake left it.
	GameState.game_over.connect(_settle_camera)
	GameState.scene_cleared.connect(func(_i: int, _t: bool) -> void: _settle_camera())
	# The scene index is carried by GameState, so a reload after "continue" comes
	# up as the next scene. Phase 7 has SceneRouter load this scene; until then
	# starting it here is what sets the HUD, the wave and the timer going.
	_scene_look.apply(GameState.scene_index)
	_load_wave(GameState.scene_index)
	GameState.start_scene(GameState.scene_index)

func _load_wave(scene_index: int) -> void:
	var wave := CampaignData.wave(scene_index)
	_spawn_interval = wave["interval"]
	_alien_speed = wave["speed"]
	_mode_weights = wave["mode_weights"]
	_to_spawn = wave["count"]
	_spawn_plan = CampaignData.spawn_plan(scene_index)
	_alive = 0
	# First alien flies in on the beat, not the instant the scene opens.
	_spawn_timer = _spawn_interval

func _unhandled_input(event: InputEvent) -> void:
	# Aiming and firing are the same gesture on a touchscreen: you put your
	# finger where you want to shoot. Until Phase 9 the only way to fire was the
	# spacebar — there is no FIRE button any more — so the kiosk this is built
	# for could aim but not shoot at all.
	if event is InputEventMouseMotion:
		_reticle_screen_pos = event.position
	elif event is InputEventScreenDrag:
		_reticle_screen_pos = event.position
	elif event is InputEventScreenTouch:
		_reticle_screen_pos = event.position
		_pointer_held = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_reticle_screen_pos = event.position
		_pointer_held = event.pressed

func _process(delta: float) -> void:
	_update_aim()
	_reticle.reticle_pos = _reticle_screen_pos
	# Held rather than tapped: a wave is twenty-odd ships and asking an 8-year-old
	# to tap once per shot turns the game into a tapping contest. `try_fire()`
	# enforces the cooldown, so holding down is a rate limit, not a cheat.
	if _pointer_held or Input.is_action_pressed("fire"):
		_turret.try_fire()
	_apply_shake(delta)
	# Once the scene is over the field stops filling up; the aliens already in
	# flight are frozen with the rest of the tree by the outcome card.
	if not GameState.scene_running or _to_spawn <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval
		# Which spawn of the wave this is, read off the front of the plan while
		# `_to_spawn` counts down from the back.
		var slot := _spawn_plan.size() - _to_spawn
		_to_spawn -= 1
		_spawn_alien(slot < _spawn_plan.size() and _spawn_plan[slot])

## Knock the camera, 0–1. Repeated knocks add rather than restart, so three
## kills in a second build instead of each one cutting the last one short.
func shake(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)


func _apply_shake(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	# Squared, so the knock is sharp at the front and the tail is short. A linear
	# decay reads as the camera being loose on its mount.
	var strength := _shake * _shake
	var offset := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0
	) * SHAKE_OFFSET * strength
	var transform := _camera_rest
	transform.origin += _camera_rest.basis * offset
	transform.basis = _camera_rest.basis * Basis(
		Vector3.BACK, deg_to_rad(randf_range(-1.0, 1.0) * SHAKE_ROLL * strength)
	)
	_camera.transform = transform
	if _shake <= 0.0:
		_settle_camera()


## Back to the authored framing exactly, rather than to whatever the last random
## offset happened to be — the aim ray is cast through this camera, so a camera
## left a few centimetres off would leave a permanent aiming bias behind it.
func _settle_camera() -> void:
	_shake = 0.0
	_camera.transform = _camera_rest


func _update_aim() -> void:
	var ray_origin := _camera.project_ray_origin(_reticle_screen_pos)
	var ray_dir := _camera.project_ray_normal(_reticle_screen_pos)
	var aim_point := ray_origin + ray_dir * AIM_DISTANCE
	_turret.aim_at(aim_point)

func _pick_flight_mode() -> AlienShip.FlightMode:
	"""Roll a flight mode against the scene's weights.

	The weights are relative rather than normalised, so a scene's table can be
	retuned by nudging one number without rebalancing the others.
	"""
	var total := 0.0
	for weight in _mode_weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return AlienShip.FlightMode.DIRECT
	var roll := randf() * total
	for i in _mode_weights.size():
		roll -= maxf(0.0, _mode_weights[i])
		if roll <= 0.0:
			return i as AlienShip.FlightMode
	return AlienShip.FlightMode.DIRECT

func _spawn_alien(ore_carrier: bool = false) -> void:
	var alien: Area3D = ORE_CARRIER_SCENE.instantiate() if ore_carrier else ALIEN_SHIP_SCENE.instantiate()
	# A carrier is a loaded freighter, not a fighter: it lumbers straight in
	# whatever the scene's flight-mode weights say, which is what gives the
	# player the time a three-hit target needs.
	var mode := AlienShip.FlightMode.DIRECT if ore_carrier else _pick_flight_mode()
	var speed := _alien_speed * (CampaignData.ORE_CARRIER["speed_scale"] if ore_carrier else 1.0)
	if ore_carrier:
		alien.scale = Vector3.ONE * CampaignData.ORE_CARRIER["size"]
		alien.score_value = CampaignData.ORE_CARRIER["score"]
		alien.hit_points = CampaignData.ORE_CARRIER["hit_points"]
	alien.flight_mode = mode

	var spawn := Vector3.ZERO
	var target := Vector3.ZERO

	match mode:
		AlienShip.FlightMode.DIRECT:
			var angle_h := randf_range(-PI * 0.55, PI * 0.55)
			var angle_v := randf_range(-0.3, 0.15)
			spawn = Vector3(
				sin(angle_h) * spawn_radius,
				3.0 + sin(angle_v) * 8.0,
				-cos(absf(angle_h)) * spawn_radius
			)
			target = Vector3(0.0, 1.5, 7.0)

		AlienShip.FlightMode.STRAFE:
			var side := signf(randf() - 0.5)
			spawn = Vector3(
				side * spawn_radius * 0.9,
				randf_range(1.5, 5.0),
				randf_range(-28.0, -20.0)
			)
			target = Vector3(-side * 12.0, 1.5, 7.0)

		AlienShip.FlightMode.WEAVE:
			var angle_h := randf_range(-PI * 0.45, PI * 0.45)
			var angle_v := randf_range(-0.2, 0.1)
			spawn = Vector3(
				sin(angle_h) * spawn_radius,
				3.0 + sin(angle_v) * 8.0,
				-cos(absf(angle_h)) * spawn_radius
			)
			target = Vector3(0.0, 1.5, 7.0)
			alien._weave_amp = randf_range(3.5, 6.0)
			alien._weave_freq = randf_range(1.0, 2.0)

		AlienShip.FlightMode.SWOOP:
			var angle_h := randf_range(-PI * 0.45, PI * 0.45)
			var angle_v := randf_range(-0.2, 0.1)
			spawn = Vector3(
				sin(angle_h) * spawn_radius,
				4.0 + sin(angle_v) * 6.0,
				-cos(absf(angle_h)) * spawn_radius
			)
			target = Vector3(0.0, 2.5, 7.0)
			alien._swoop_amp = randf_range(2.5, 4.5)
			alien._swoop_freq = randf_range(0.8, 1.6)

	# Into the tree first: global_position on a node that isn't in the tree has
	# no parent transform to resolve against, so the assignment is dropped and
	# every spawn logs an error. It only looked like it worked because this node
	# sits at the origin untransformed, which made the lost global equal the
	# local it fell back to — moving Game or reparenting aliens would break it.
	add_child(alien)
	alien.global_position = spawn
	alien.velocity = (target - spawn).normalized() * speed
	alien.destroyed.connect(_on_alien_destroyed)
	alien.got_through.connect(_on_alien_got_through)
	_alive += 1

# The score itself is GameState's business; the popup needs the kill position,
# which only this node ever sees — so the two are split here.
func _on_alien_destroyed(world_position: Vector3, points: int) -> void:
	GameState.add_score(points)
	_hud.pop_score(world_position, points)
	# The carrier is the biggest thing on the field and the hardest kill in the
	# campaign; it is worth more points and it should land heavier. Read off the
	# payout so the two stay tied to the same table entry.
	shake(SHAKE_CARRIER if points >= CampaignData.ORE_CARRIER["score"] else SHAKE_KILL)
	_resolve_alien()

func _on_alien_got_through() -> void:
	# Damage first: a leak that empties the bar ends the run, and a run that has
	# ended must not then be reported as a scene cleared.
	GameState.take_damage()
	_resolve_alien()

func _resolve_alien() -> void:
	_alive -= 1
	if _to_spawn <= 0 and _alive <= 0:
		GameState.complete_scene()
