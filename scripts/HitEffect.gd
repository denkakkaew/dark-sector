extends Node3D

@export var light_duration: float = 0.12

func _ready() -> void:
	$CPUParticles3D.emitting = true
	$CPUParticles3D.finished.connect(queue_free)
	get_tree().create_timer(light_duration).timeout.connect(func(): $OmniLight3D.visible = false)
