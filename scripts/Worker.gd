extends Node3D
## A scenery worker that looks busy: it walks to a spot near its post, stops to
## work — leaning in and swinging, as if with a pick — then wanders to another.
## Mars' drones around the drilling rig use it.
##
## The model is one rigid mesh, so all of this is the node's own movement: a bob
## and a side-to-side sway for the gait, a forward lean for the work, and a turn
## to face the way it is going. It has no collision and nothing reads where it is,
## so it can never get in a shot's way; and it stops with the tree, so the outcome
## card freezes it like everything else.
##
## The model faces +Z (every hull and prop in the game is exported that way), so
## facing a heading is `atan2(x, z)`.

## How far from where it was placed it will stray, metres. Small: it is working a
## spot, not touring.
@export var roam_radius: float = 3.5
## Metres per second while walking.
@export var walk_speed: float = 1.0
## How long it works at each stop, seconds (min, max).
@export var work_time: Vector2 = Vector2(2.0, 4.5)
## Seeds the wandering, so each worker keeps its own rhythm and a scene replays the
## same way. Set it differently per worker.
@export var seed_value: int = 0

## Gait: radians per second of the bob, its height as a fraction of the worker's own
## height, and how far it sways (radians).
const STEP_RATE: float = 4.2
const BOB_HEIGHT: float = 0.025
const SWAY: float = 0.09
## How far it leans into its work (radians) and how fast it swings.
const LEAN: float = 0.34
const SWING_RATE: float = 5.0
## How quickly it turns onto a new heading, per second.
const TURN_RESPONSE: float = 6.0

enum State { WORK, WALK }

var _home: Vector3
var _target: Vector3
var _state: State = State.WORK
var _timer: float = 0.0
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home = position
	_rng.seed = seed_value
	_clock = _rng.randf() * TAU
	# Staggered, so a crew that was placed together does not move as one.
	_timer = _rng.randf_range(0.0, work_time.y)


func _process(delta: float) -> void:
	_clock += delta
	match _state:
		State.WORK:
			_work(delta)
		State.WALK:
			_walk(delta)


func _work(delta: float) -> void:
	_timer -= delta
	position.y = _home.y
	rotation.z = lerpf(rotation.z, 0.0, minf(1.0, delta * 8.0))
	# Squared so the swing is a sharp dip and a pause, not a smooth nod.
	var swing := maxf(0.0, sin(_clock * SWING_RATE))
	rotation.x = LEAN * swing * swing
	if _timer <= 0.0:
		_pick_next_spot()


func _walk(delta: float) -> void:
	var to_target := _target - position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.12:
		_state = State.WORK
		_timer = _rng.randf_range(work_time.x, work_time.y)
		return
	var direction := to_target / distance
	var step := minf(walk_speed * delta, distance)
	position.x += direction.x * step
	position.z += direction.z * step
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * TURN_RESPONSE))
	# The gait: a bounce at every step and a sway between feet.
	position.y = _home.y + absf(sin(_clock * STEP_RATE)) * BOB_HEIGHT * scale.y * 4.0
	rotation.z = sin(_clock * STEP_RATE * 0.5) * SWAY
	rotation.x = lerpf(rotation.x, 0.0, minf(1.0, delta * 8.0))


func _pick_next_spot() -> void:
	# Uniform over the disc, not the radius, so it doesn't crowd its post.
	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf()) * roam_radius
	_target = _home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_state = State.WALK
