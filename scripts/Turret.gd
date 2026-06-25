extends Node3D

const LASER_SCENE := preload("res://scenes/Laser.tscn")

@export var fire_cooldown: float = 0.2
@export var laser_speed: float = 40.0

@onready var _aim_pivot: Node3D = $AimPivot

var _fire_cooldown_remaining: float = 0.0

func _process(delta: float) -> void:
	_fire_cooldown_remaining = maxf(_fire_cooldown_remaining - delta, 0.0)

func aim_at(world_pos: Vector3) -> void:
	var to_aim := world_pos - _aim_pivot.global_position
	if to_aim.length_squared() < 0.01:
		return
	if absf(to_aim.normalized().dot(Vector3.UP)) > 0.99:
		return
	_aim_pivot.look_at(world_pos, Vector3.UP)

func try_fire() -> void:
	if _fire_cooldown_remaining > 0.0:
		return
	_fire_cooldown_remaining = fire_cooldown
	var laser: Area3D = LASER_SCENE.instantiate()
	get_parent().add_child(laser)
	laser.global_transform = $AimPivot/Muzzle.global_transform
	laser.speed = laser_speed
