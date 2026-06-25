extends Area3D
class_name AlienShip

signal reached_earth

const HIT_EFFECT_SCENE := preload("res://scenes/HitEffect.tscn")
const EARTH_Z: float = 9.0

enum FlightMode { DIRECT, STRAFE, WEAVE, SWOOP }

@export var speed: float = 8.0

var velocity: Vector3 = Vector3.ZERO
var flight_mode: FlightMode = FlightMode.DIRECT
var _destroyed: bool = false
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

func _physics_process(delta: float) -> void:
	if _destroyed:
		return
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
	if global_position.z >= EARTH_Z:
		reached_earth.emit()
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _destroyed:
		return
	if area.is_in_group("lasers"):
		_explode()

func _explode() -> void:
	_destroyed = true
	$MeshInstance3D.visible = false
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position
	queue_free()
