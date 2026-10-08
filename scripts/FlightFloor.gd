class_name FlightFloor
extends RefCounted
## How high the solid ground is under every half metre of the alien flight zone:
## the top of whatever stands there — a sandstone ledge, a boulder, the ground
## itself. Ships read it to climb over rock instead of flying through it.
##
## It is *measured* off the scene's set, not written down beside it: the set's
## nodes in the `flight_obstacle` group are ray-cast from above once, as the
## scene comes up. So regenerating Mars' rocks, or moving a ledge in its layout,
## can never leave the ships dodging rock that isn't there any more — the same
## reason `AlienShip._fit_collision_to()` measures hulls instead of trusting a
## number. The casting is `TriangleMesh`'s, in the engine, so twenty thousand
## rays over a hundred thousand triangles costs a few milliseconds.

const GROUP := "flight_obstacle"
## The ground the ships fly over: everything between the spawn ring (35 m out,
## plus the weave and wobble) and the line they are lost at, x across, z toward
## the player. Anything outside it is never under a ship.
const ZONE := Rect2(-45.0, -45.0, 90.0, 57.0)
const CELL: float = 0.5
## Rays start this high: above anything a set puts in the flight zone.
const RAY_TOP: float = 80.0
## What `height_at` says where nothing was measured: nothing to clear.
const NOTHING: float = -INF

var _heights := PackedFloat32Array()
var _columns: int = 0
var _rows: int = 0


## Measure a set. Null when it has nothing in the group under the flight zone,
## so a ship only ever pays for this in a scene that has rock to fly over.
static func measure(root: Node) -> FlightFloor:
	var faces := PackedVector3Array()
	var obstacles := root.find_children("*", "", true, false)
	obstacles.push_front(root)
	for node in obstacles:
		if not node.is_in_group(GROUP):
			continue
		var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			meshes.push_front(node)
		for instance: MeshInstance3D in meshes:
			if instance.mesh != null:
				faces.append_array(instance.global_transform * instance.mesh.get_faces())
	if faces.is_empty():
		return null
	var shape := TriangleMesh.new()
	if not shape.create_from_faces(faces):
		return null
	var result := FlightFloor.new()
	result._cast(shape)
	return result


func _cast(shape: TriangleMesh) -> void:
	_columns = int(ceil(ZONE.size.x / CELL))
	_rows = int(ceil(ZONE.size.y / CELL))
	_heights.resize(_columns * _rows)
	for row in _rows:
		for column in _columns:
			var x := ZONE.position.x + (column + 0.5) * CELL
			var z := ZONE.position.y + (row + 0.5) * CELL
			var hit := shape.intersect_ray(Vector3(x, RAY_TOP, z), Vector3.DOWN)
			_heights[row * _columns + column] = hit["position"].y if not hit.is_empty() else NOTHING
	# A ray down a cell's centre can slip past the peak of a boulder narrower than
	# the cell. Spreading every height one cell out closes that gap.
	_spread()


func _spread() -> void:
	var source := _heights.duplicate()
	for row in _rows:
		for column in _columns:
			var highest := NOTHING
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					var r := row + dr
					var c := column + dc
					if r >= 0 and r < _rows and c >= 0 and c < _columns:
						highest = maxf(highest, source[r * _columns + c])
			_heights[row * _columns + column] = highest


## The top of the solid ground at (x, z), or `NOTHING` outside the zone.
func height_at(x: float, z: float) -> float:
	var column := int(floor((x - ZONE.position.x) / CELL))
	var row := int(floor((z - ZONE.position.y) / CELL))
	if column < 0 or column >= _columns or row < 0 or row >= _rows:
		return NOTHING
	return _heights[row * _columns + column]
