extends Area3D
class_name AlienShip

# Shot down: carries where it died so the HUD can float the points there.
signal destroyed(world_position: Vector3, points: int)
# Crossed the line the player is defending. Named for what it costs rather than
# where it happens: in scenes 1–3 "getting through" is reaching the station, the
# base site, or escaping with ore — only scene 4 is literally reaching Earth.
signal got_through

const HIT_EFFECT_SCENE := preload("res://scenes/HitEffect.tscn")
const EARTH_Z: float = 9.0

enum FlightMode { DIRECT, STRAFE, WEAVE, SWOOP }

@export var speed: float = 8.0
@export var score_value: int = 100
## Laser hits this ship survives before the last one destroys it. 1 for a scout;
## Mars' ore carrier is the armoured exception.
@export var hit_points: int = 1

# How fast the hull swings onto a new heading, as a rate per second. Low enough
# that the ship banks through a weave instead of snapping between angles, high
# enough that it never looks like it is drifting sideways.
const TURN_RESPONSE: float = 6.0

var velocity: Vector3 = Vector3.ZERO
# Smoothed heading the hull points along. Starts unset: the spawner assigns
# `velocity` after the ship is in the tree, so the first real direction only
# shows up on the first physics frame.
var _facing: Vector3 = Vector3.ZERO
var flight_mode: FlightMode = FlightMode.DIRECT
var _destroyed: bool = false
var _hits_taken: int = 0
# The armour shell's authored strength, remembered so damage can fade it towards
# nothing from whatever the scene set it to.
var _armour_alpha: float = 0.0
var _armour_glow: float = 0.0
var _wobble_time: float = 0.0
var _wobble_amp_x: float = 0.0
var _wobble_amp_y: float = 0.0
var _weave_amp: float = 0.0
var _weave_freq: float = 0.0
var _swoop_amp: float = 0.0
var _swoop_freq: float = 0.0

func _ready() -> void:
	add_to_group("aliens")
	area_entered.connect(_on_area_entered)
	_wobble_time = randf() * TAU
	_wobble_amp_x = randf_range(0.4, 1.2)
	_wobble_amp_y = randf_range(0.2, 0.7)
	var armour := get_node_or_null("Armour") as MeshInstance3D
	if armour != null:
		var material := armour.get_surface_override_material(0) as StandardMaterial3D
		if material != null:
			_armour_alpha = material.albedo_color.a
			_armour_glow = material.emission_energy_multiplier

func _physics_process(delta: float) -> void:
	if _destroyed:
		return
	var previous := global_position
	_wobble_time += delta
	var wobble := Vector3(
		sin(_wobble_time * 1.7) * _wobble_amp_x,
		sin(_wobble_time * 1.2 + 1.0) * _wobble_amp_y,
		0.0
	)
	match flight_mode:
		FlightMode.DIRECT:
			if velocity == Vector3.ZERO:
				global_position.z += speed * delta
			else:
				global_position += (velocity + wobble) * delta
		FlightMode.STRAFE:
			global_position += (velocity + wobble) * delta
		FlightMode.WEAVE:
			var lateral := Vector3(sin(_wobble_time * _weave_freq) * _weave_amp, 0.0, 0.0)
			global_position += (velocity + wobble + lateral) * delta
		FlightMode.SWOOP:
			var vertical := Vector3(0.0, sin(_wobble_time * _swoop_freq) * _swoop_amp, 0.0)
			global_position += (velocity + wobble + vertical) * delta
			global_position.y = maxf(global_position.y, 0.3)
	_steer(global_position - previous, delta)
	if global_position.z >= EARTH_Z:
		got_through.emit()
		queue_free()

func _steer(step: Vector3, delta: float) -> void:
	"""Point the hull along the way it actually moved this frame.

	Taken from the travelled step rather than `velocity`, so the wobble and the
	weave/swoop offsets steer the ship too — those are most of what a strafing
	alien's heading is made of, and without them it would slide sideways while
	staring straight ahead.
	"""
	if step.is_zero_approx():
		return
	var heading := step.normalized()
	if _facing.is_zero_approx():
		_facing = heading
	else:
		_facing = _facing.lerp(heading, minf(1.0, delta * TURN_RESPONSE)).normalized()
	# look_at aims the node's -Z at its target and the saucer is modelled facing
	# +Z, so it is given the point *behind* the ship to look at.
	var up := Vector3.UP
	if absf(_facing.dot(up)) > 0.99:
		up = Vector3.BACK
	look_at(global_position - _facing, up)

func _on_area_entered(area: Area3D) -> void:
	if _destroyed:
		return
	if area.is_in_group("lasers"):
		take_hit()


## Take one laser hit. Everything with a single hit point — every alien but the
## ore carrier — goes straight through this to `_explode()`.
func take_hit() -> void:
	if _destroyed:
		return
	_hits_taken += 1
	if _hits_taken >= hit_points:
		_explode()
		return
	_show_armour_damage()


func _show_armour_damage() -> void:
	"""A hit the ship walked away from, made obvious.

	Without this a carrier that takes three hits reads as three misses, and the
	player stops shooting at the one target on the screen that is worth 400. The
	shell fading step by step is the health bar — it says *keep going*, and it
	says how much further, without putting a gauge on a 3D object.
	"""
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.scale = Vector3.ONE * 0.5

	var armour := get_node_or_null("Armour") as MeshInstance3D
	if armour == null:
		return
	var material := armour.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	# The shell material is local to the scene (see OreCarrier.tscn), so this
	# fades this one carrier and not every carrier on the field.
	var remaining := float(hit_points - _hits_taken) / float(maxi(1, hit_points))
	material.albedo_color.a = _armour_alpha * remaining
	material.emission_energy_multiplier = _armour_glow * remaining

func _explode() -> void:
	_destroyed = true
	$Model.visible = false
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position
	# A bigger ship goes up bigger. The carrier is the hardest kill on the field
	# and the payoff should look like it.
	effect.scale = Vector3.ONE * maxf(1.0, scale.x)
	# Emitted before freeing, while global_position is still readable.
	destroyed.emit(global_position, score_value)
	queue_free()
