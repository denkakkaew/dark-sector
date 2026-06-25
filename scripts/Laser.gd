extends Area3D

@export var speed: float = 40.0
@export var max_travel: float = 60.0

var _traveled: float = 0.0

func _ready() -> void:
	add_to_group("lasers")
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	translate(Vector3(0.0, 0.0, -speed * delta))
	_traveled += speed * delta
	if _traveled >= max_travel:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("aliens"):
		queue_free()
