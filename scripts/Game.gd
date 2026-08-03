extends Node3D

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")
const AlienShip = preload("res://scripts/AlienShip.gd")
const AIM_DISTANCE: float = 20.0

## How far out the aliens are staged. Framing, not difficulty — the per-scene
## difficulty knobs (count, cadence, speed, flight modes) come from CampaignData.
@export var spawn_radius: float = 35.0

@onready var _camera: Camera3D = $Camera3D
@onready var _turret = $Turret
@onready var _reticle = $UI/Reticle
@onready var _hud = $UI/HUD

var _reticle_screen_pos: Vector2
var _spawn_timer: float = 0.0

# The wave, read from CampaignData for whichever scene GameState is on.
var _spawn_interval: float = 1.5
var _alien_speed: float = 8.0
var _mode_weights: Array = []
## Aliens still to spawn. The scene is cleared when this and `_alive` are both 0.
var _to_spawn: int = 0
## Aliens in the air: spawned, not yet shot down and not yet through.
var _alive: int = 0

func _ready() -> void:
	_reticle_screen_pos = get_viewport().get_visible_rect().size / 2.0
	# The scene index is carried by GameState, so a reload after "continue" comes
	# up as the next scene. Phase 7 has SceneRouter load this scene; until then
	# starting it here is what sets the HUD, the wave and the timer going.
	_load_wave(GameState.scene_index)
	GameState.start_scene(GameState.scene_index)

func _load_wave(scene_index: int) -> void:
	var wave := CampaignData.wave(scene_index)
	_spawn_interval = wave["interval"]
	_alien_speed = wave["speed"]
	_mode_weights = wave["mode_weights"]
	_to_spawn = wave["count"]
	_alive = 0
	# First alien flies in on the beat, not the instant the scene opens.
	_spawn_timer = _spawn_interval

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_reticle_screen_pos = event.position
	elif event is InputEventScreenDrag:
		_reticle_screen_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		_reticle_screen_pos = event.position
	elif event.is_action_pressed("fire"):
		_turret.try_fire()

func _process(delta: float) -> void:
	_update_aim()
	_reticle.reticle_pos = _reticle_screen_pos
	# Once the scene is over the field stops filling up; the aliens already in
	# flight are frozen with the rest of the tree by the outcome card.
	if not GameState.scene_running or _to_spawn <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval
		_to_spawn -= 1
		_spawn_alien()

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

func _spawn_alien() -> void:
	var alien: Area3D = ALIEN_SHIP_SCENE.instantiate()
	var mode := _pick_flight_mode()
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
	alien.velocity = (target - spawn).normalized() * _alien_speed
	alien.destroyed.connect(_on_alien_destroyed)
	alien.got_through.connect(_on_alien_got_through)
	_alive += 1

# The score itself is GameState's business; the popup needs the kill position,
# which only this node ever sees — so the two are split here.
func _on_alien_destroyed(world_position: Vector3, points: int) -> void:
	GameState.add_score(points)
	_hud.pop_score(world_position, points)
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
