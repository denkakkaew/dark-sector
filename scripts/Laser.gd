extends Area3D

@export var speed: float = 40.0
@export var max_travel: float = 60.0

var _start_z: float

func _ready() -> void:
	add_to_group("lasers")
	_start_z = position.z
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position.z -= speed * delta
	if absf(position.z - _start_z) >= max_travel:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("aliens"):
		queue_free()
