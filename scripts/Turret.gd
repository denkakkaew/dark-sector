extends Node3D

const LASER_SCENE := preload("res://scenes/Laser.tscn")

@export var fire_cooldown: float = 0.2
@export var laser_speed: float = 60.0
@export var aim_assist_angle: float = 35.0

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
	_apply_aim_assist()
	var laser: Area3D = LASER_SCENE.instantiate()
	get_parent().add_child(laser)
	laser.global_transform = $AimPivot/Muzzle.global_transform
	laser.speed = laser_speed

func _apply_aim_assist() -> void:
	var muzzle: Node3D = $AimPivot/Muzzle
	var forward := -muzzle.global_basis.z
	var cos_threshold := cos(deg_to_rad(aim_assist_angle))
	var best: Node3D = null
	var best_cos: float = cos_threshold
	for node in get_tree().get_nodes_in_group("aliens"):
		var alien := node as Node3D
		if alien == null or alien.get("_destroyed"):
			continue
		var to_alien := (alien.global_position - muzzle.global_position).normalized()
		var dot := forward.dot(to_alien)
		if dot > best_cos:
			best_cos = dot
			best = alien
	if best:
		_aim_pivot.look_at(best.global_position, Vector3.UP)
