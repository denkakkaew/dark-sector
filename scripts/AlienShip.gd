extends Area3D

signal reached_earth

@export var speed: float = 8.0

const EARTH_Z: float = 9.0

func _physics_process(delta: float) -> void:
	position.z += speed * delta
	if position.z >= EARTH_Z:
		reached_earth.emit()
		queue_free()
