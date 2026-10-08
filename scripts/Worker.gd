extends Node3D
## A scenery worker that looks busy: it walks to a spot near its post, stops to
## work — leaning in and swinging, as if with a pick — then wanders to another.
## The alien drones use it: Mars' around the drilling rig, the Moon's around the
## landers and tanks (where the ground rolls, so they set `ground`, and hop higher).
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
## The ground it walks on, if that isn't flat: the worker keeps its feet on it
## instead of on the height it was placed at. The Moon's base area rolls by a
## few tenths of a metre across one drone's beat — enough to see one float or
## wade. Unset (Mars' rig yard), it stays at its placed height. The ground's mesh
## is ray-cast in the engine, measured once and shared by every worker on it.
@export var ground: Node3D
## How high its walk bounces, as a multiple of the normal gait. The Moon's crew
## hop: a sixth of Earth's gravity is worth showing a kid.
@export var bounce: float = 1.0

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
## Height of the ground where it stands right now (its placed height, without a
## `ground`).
var _floor_y: float = 0.0
var _ground_mesh: TriangleMesh
var _state: State = State.WORK
var _timer: float = 0.0
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_home = position
	_ground_mesh = _measure_ground()
	_floor_y = _ground_height(position)
	position.y = _floor_y
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
	# Eased down rather than set: it can stop mid-hop, and the Moon's hop is high
	# enough that dropping straight onto its feet would be a visible pop.
	position.y = lerpf(position.y, _floor_y, minf(1.0, delta * 10.0))
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
	_floor_y = _ground_height(position)
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * TURN_RESPONSE))
	# The gait: a bounce at every step and a sway between feet.
	position.y = _floor_y + absf(sin(_clock * STEP_RATE)) * BOB_HEIGHT * bounce * scale.y * 4.0
	rotation.z = sin(_clock * STEP_RATE * 0.5) * SWAY
	rotation.x = lerpf(rotation.x, 0.0, minf(1.0, delta * 8.0))


func _pick_next_spot() -> void:
	# Uniform over the disc, not the radius, so it doesn't crowd its post.
	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf()) * roam_radius
	_target = _home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_state = State.WALK


func _measure_ground() -> TriangleMesh:
	"""The ground's surface, in the space the worker moves in (its parent's).

	Kept on the ground node itself, so a crew of six builds it once and it goes
	when the set does — a static cache would hold every visit's terrain for as
	long as the kiosk runs."""
	if ground == null:
		return null
	if ground.has_meta(&"worker_ground"):
		return ground.get_meta(&"worker_ground")
	var parent := get_parent_node_3d()
	var to_local := parent.global_transform.affine_inverse() if parent != null else Transform3D.IDENTITY
	var faces := PackedVector3Array()
	var meshes: Array = ground.find_children("*", "MeshInstance3D", true, false)
	if ground is MeshInstance3D:
		meshes.push_front(ground)
	for instance: MeshInstance3D in meshes:
		if instance.mesh != null:
			faces.append_array((to_local * instance.global_transform) * instance.mesh.get_faces())
	var surface := TriangleMesh.new()
	if faces.is_empty() or not surface.create_from_faces(faces):
		surface = null
	ground.set_meta(&"worker_ground", surface)
	return surface


func _ground_height(at: Vector3) -> float:
	if _ground_mesh == null:
		return _home.y
	var hit := _ground_mesh.intersect_ray(Vector3(at.x, _home.y + 50.0, at.z), Vector3.DOWN)
	return hit["position"].y if not hit.is_empty() else _home.y
