extends MeshInstance3D
class_name ShockArc
## An electric arc: a jagged, flickering ribbon of light from `source` to
## `target` — or, with no target, a crackle of short arcs around `source`.
##
## Drawn as camera-facing triangle strips rather than lines, because GL
## Compatibility draws a line one pixel wide whatever width is asked for, and a
## bolt a child is meant to see coming has to be thicker than a hair. Vertices
## are in world space (`top_level`), so an arc hanging off a ship never inherits
## the ship's banking.
##
## The jag is re-rolled every `flicker_interval`, but the mesh is rebuilt every
## frame from the same seed, so between flickers the bolt keeps its shape and
## stretches to follow both ends as they move instead of lagging behind them.

const CORE_COLOR := Color(0.92, 0.97, 1.0, 1.0)
const GLOW_COLOR := Color(0.3, 0.62, 1.0, 0.5)
## How much wider the soft glow is than the white-hot core.
const GLOW_WIDTH: float = 2.5

@export var source: Node3D
@export var target: Node3D
## Seconds until the arc frees itself, fading out as it goes. 0 lives until freed.
@export var lifetime: float = 0.0
## Crackle mode: how far the short arcs reach from `source`, and how many.
@export var crackle_radius: float = 1.5
@export var crackle_count: int = 3
## Half-width of the core, in metres.
@export var width: float = 0.05
@export var flicker_interval: float = 0.05
## Midpoint subdivisions: an arc has 2^detail segments.
@export var detail: int = 4
## Sideways kick of the first subdivision, as a fraction of the arc's length.
@export var roughness: float = 0.2

var _mesh := ImmediateMesh.new()
var _rng := RandomNumberGenerator.new()
var _flicker_seed: int = 0
var _until_flicker: float = 0.0
var _age: float = 0.0
## Brightness of the current flicker, so the arc stutters rather than glowing.
var _flash: float = 1.0
# Last positions seen, kept so an arc outlives a ship shot mid-bolt.
var _from: Vector3
var _to: Vector3
## A bolt to a target rather than a crackle. Decided once, so a bolt whose
## target is freed mid-flash finishes as a bolt instead of turning into sparks.
var _is_bolt: bool = false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material_override = material
	_is_bolt = target != null
	_follow_ends()
	_reroll()
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	_follow_ends()
	_until_flicker -= delta
	if _until_flicker <= 0.0:
		_reroll()
	_rebuild()


func _follow_ends() -> void:
	if is_instance_valid(source):
		_from = source.global_position
	if is_instance_valid(target):
		_to = target.global_position


func _reroll() -> void:
	_until_flicker = flicker_interval
	_flicker_seed = randi()
	_flash = randf_range(0.55, 1.0)


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_rng.seed = _flicker_seed
	# Full strength for the first half of its life, then gone over the second:
	# the flash has to land before it starts to fade, or it never reads.
	var fade := 1.0 if lifetime <= 0.0 else clampf(2.0 * (1.0 - _age / lifetime), 0.0, 1.0)
	var strength := _flash * fade
	var depth := maxi(1, detail)
	var arcs: Array[PackedVector3Array] = []
	var widths: Array[float] = []
	if _is_bolt:
		var main := jagged(_from, _to, depth, roughness, _rng)
		arcs.append(main)
		widths.append(width)
		# Two forks off the main bolt: a single clean line reads as a laser.
		var reach := _from.distance_to(_to) * 0.22
		for _fork in 2:
			var start := main[_rng.randi_range(1, main.size() - 2)]
			arcs.append(jagged(start, start + _random_direction() * reach, depth - 1, roughness, _rng))
			widths.append(width * 0.55)
	else:
		for _arc in crackle_count:
			var end := _from + _random_direction() * crackle_radius * _rng.randf_range(0.6, 1.0)
			arcs.append(jagged(_from, end, depth - 1, roughness * 1.5, _rng))
			widths.append(width * 0.7)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in arcs.size():
		_ribbon(arcs[i], widths[i] * GLOW_WIDTH, GLOW_COLOR, strength, camera.global_position)
		_ribbon(arcs[i], widths[i], CORE_COLOR, strength, camera.global_position)
	_mesh.surface_end()


func _ribbon(points: PackedVector3Array, half_width: float, color: Color, strength: float, eye: Vector3) -> void:
	"""One strip along `points`, turned to face the camera.

	Each point's sideways edge is taken across the direction *through* it (from
	the point before to the point after), so neighbouring quads share their
	edges and the bolt bends at each kink instead of breaking into dashes.
	"""
	var tint := Color(color.r, color.g, color.b, color.a * strength)
	var last := points.size() - 1
	var sides := PackedVector3Array()
	for i in points.size():
		var through := points[mini(i + 1, last)] - points[maxi(i - 1, 0)]
		sides.append(through.cross(eye - points[i]).normalized() * half_width)
	for i in last:
		var a := points[i]
		var b := points[i + 1]
		for corner in [a - sides[i], a + sides[i], b + sides[i + 1], a - sides[i], b + sides[i + 1], b - sides[i + 1]]:
			_mesh.surface_set_color(tint)
			_mesh.surface_add_vertex(corner)


func _random_direction() -> Vector3:
	return Vector3(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	).normalized()


## A lightning path from `from` to `to` by midpoint displacement: each pass
## splits every segment and kicks the new midpoint sideways, by half as much as
## the pass before, so the bolt is jagged at every scale and never doubles back.
## Ends exactly on both endpoints; `2^detail + 1` points.
static func jagged(from: Vector3, to: Vector3, detail: int, roughness: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var points := PackedVector3Array([from, to])
	var spread := from.distance_to(to) * roughness
	for _pass in detail:
		var refined := PackedVector3Array()
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var axis := (b - a).normalized()
			var kick := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			# Sideways only, so a kick never folds a segment back on itself.
			kick -= axis * kick.dot(axis)
			refined.append(a)
			refined.append((a + b) * 0.5 + kick * spread)
		refined.append(points[points.size() - 1])
		points = refined
		spread *= 0.5
	return points
