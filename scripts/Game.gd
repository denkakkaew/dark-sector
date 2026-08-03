extends Node3D

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")
const AlienShip = preload("res://scripts/AlienShip.gd")
const AIM_DISTANCE: float = 20.0

@export var spawn_interval: float = 1.5
@export var spawn_radius: float = 35.0
@export var alien_speed: float = 8.0

@onready var _camera: Camera3D = $Camera3D
@onready var _turret = $Turret
@onready var _reticle = $UI/Reticle
@onready var _fire_button: Button = $UI/FireButton
@onready var _hud = $UI/HUD

var _reticle_screen_pos: Vector2
var _spawn_timer: float = 0.0

func _ready() -> void:
	_reticle_screen_pos = get_viewport().get_visible_rect().size / 2.0
	_fire_button.pressed.connect(_turret.try_fire)
	# Phase 5 hands the scene index to the router; until then this scene is
	# always scene 1, and starting it here is what sets the HUD and timer going.
	GameState.start_scene(1)

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
	# Once the run is over the field stops filling up; the aliens already in
	# flight are frozen with the rest of the tree by the game-over card.
	if not GameState.scene_running:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_alien()

func _update_aim() -> void:
	var ray_origin := _camera.project_ray_origin(_reticle_screen_pos)
	var ray_dir := _camera.project_ray_normal(_reticle_screen_pos)
	var aim_point := ray_origin + ray_dir * AIM_DISTANCE
	_turret.aim_at(aim_point)

func _pick_flight_mode() -> AlienShip.FlightMode:
	var r := randf()
	if r < 0.40:
		return AlienShip.FlightMode.DIRECT
	elif r < 0.65:
		return AlienShip.FlightMode.STRAFE
	elif r < 0.85:
		return AlienShip.FlightMode.WEAVE
	else:
		return AlienShip.FlightMode.SWOOP

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
	alien.velocity = (target - spawn).normalized() * alien_speed
	alien.destroyed.connect(_on_alien_destroyed)
	alien.got_through.connect(_on_alien_got_through)

# The score itself is GameState's business; the popup needs the kill position,
# which only this node ever sees — so the two are split here.
func _on_alien_destroyed(world_position: Vector3, points: int) -> void:
	GameState.add_score(points)
	_hud.pop_score(world_position, points)

func _on_alien_got_through() -> void:
	GameState.take_damage()
