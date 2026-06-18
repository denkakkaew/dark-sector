extends Node3D

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")

@export var spawn_interval: float = 1.5
@export var spawn_x_range: float = 6.0
@export var alien_speed: float = 8.0
@export var spawn_z: float = -40.0

var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_spawn_alien()

func _spawn_alien() -> void:
	var alien: Area3D = ALIEN_SHIP_SCENE.instantiate()
	var x := randf_range(-spawn_x_range, spawn_x_range)
	alien.position = Vector3(x, 1.0, spawn_z)
	alien.speed = alien_speed
	add_child(alien)
