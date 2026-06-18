extends Area3D

signal reached_earth

const HIT_EFFECT_SCENE := preload("res://scenes/HitEffect.tscn")
const EARTH_Z: float = 9.0

@export var speed: float = 8.0

var _destroyed: bool = false

func _ready() -> void:
	add_to_group("aliens")
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _destroyed:
		return
	position.z += speed * delta
	if position.z >= EARTH_Z:
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
