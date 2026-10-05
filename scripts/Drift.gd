extends Node3D
## Carries a node along a straight line at a constant speed, and brings it back to
## the start once it has crossed. Scenery that moves — the ISS module passing
## below the turret — and nothing that takes part in play: it has no collision and
## nothing reads where it is.
##
## It stops with the tree, so the outcome card freezing the battle freezes this too.

## Metres per second, in the parent's space.
@export var velocity: Vector3 = Vector3(2.0, 0.0, 0.0)
## The x it re-enters at, and the x it has to pass to do so. Far enough out that
## the wrap happens off-screen at either end.
@export var wrap_from: float = -80.0
@export var wrap_to: float = 80.0


func _process(delta: float) -> void:
	position += velocity * delta
	if position.x > wrap_to:
		position.x = wrap_from
