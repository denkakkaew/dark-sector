extends Node3D

const LASER_SCENE := preload("res://scenes/Laser.tscn")

@export var fire_cooldown: float = 0.2
@export var laser_speed: float = 60.0
@export var aim_assist_angle: float = 35.0

## How far the jammed barrel shakes, in degrees either way.
const STUN_JITTER_DEG: float = 3.0

@onready var _aim_pivot: Node3D = $AimPivot
@onready var _shock_sparks: CPUParticles3D = $AimPivot/ShockSparks
@onready var _shock_light: OmniLight3D = $AimPivot/ShockLight

var _fire_cooldown_remaining: float = 0.0
## Seconds the gun stays jammed after an alien's shock; 0 is working.
var _stun_remaining: float = 0.0

func _process(delta: float) -> void:
	_fire_cooldown_remaining = maxf(_fire_cooldown_remaining - delta, 0.0)
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(_stun_remaining - delta, 0.0)
		if _stun_remaining <= 0.0:
			_recover()
		else:
			_shudder()


## Jam the gun for `seconds`: an alien's shock landed. A second shock while
## already jammed extends the jam to whichever ends later rather than stacking,
## so two shockers arriving together cost a jam, not a lockout.
func stun(seconds: float) -> void:
	_stun_remaining = maxf(_stun_remaining, seconds)
	_shock_sparks.emitting = true
	_shock_light.visible = true


func is_stunned() -> bool:
	return _stun_remaining > 0.0


## Where an alien's shock lands: the gun on its trunnion.
func shock_point() -> Node3D:
	return _aim_pivot


func _shudder() -> void:
	# Layered on top of this frame's aim, which Game re-applies every frame
	# before this runs (parent first), so the shake never accumulates.
	var jitter := deg_to_rad(STUN_JITTER_DEG)
	_aim_pivot.rotate_object_local(Vector3.RIGHT, randf_range(-jitter, jitter))
	_aim_pivot.rotate_object_local(Vector3.UP, randf_range(-jitter, jitter))
	_shock_light.light_energy = randf_range(0.5, 3.5)


func _recover() -> void:
	_shock_sparks.emitting = false
	_shock_light.visible = false

func aim_at(world_pos: Vector3) -> void:
	var target := _clamp_to_horizon(world_pos)
	var to_aim := target - _aim_pivot.global_position
	if to_aim.length_squared() < 0.01:
		return
	if absf(to_aim.normalized().dot(Vector3.UP)) > 0.99:
		return
	_aim_pivot.look_at(target, Vector3.UP)

func _clamp_to_horizon(world_pos: Vector3) -> Vector3:
	# The gun is bolted to a platform: it swings freely but never depresses below
	# the horizontal. Anything under the trunnion is aimed at flat instead of
	# down into the pedestal. The camera looks down at the turret, so without
	# this the lower half of the screen — which is below the horizon — drags the
	# barrel into the ground, including with the reticle at rest in the centre.
	var target := world_pos
	target.y = maxf(target.y, _aim_pivot.global_position.y)
	return target

func try_fire() -> void:
	if _fire_cooldown_remaining > 0.0 or is_stunned():
		return
	_fire_cooldown_remaining = fire_cooldown
	# Jittered, because at a 0.2 s cooldown this is five identical samples a
	# second and identical is what makes a repeated sound read as a glitch.
	Audio.play("laser", -4.0, 0.09)
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
		_aim_pivot.look_at(_clamp_to_horizon(best.global_position), Vector3.UP)
