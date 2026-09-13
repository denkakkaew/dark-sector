# gdUnit4 test suite for the alien hull pool.
#
# Three hulls now share one AlienShip scene, one script and one collision shape,
# and the whole arrangement rests on a claim the export scripts make and nothing
# in the engine enforces: that every hull is centred on its own bounds, faces the
# way the ships fly, and fits inside the same box. Which hull a ship is wearing
# is invisible to the rest of the code, so a hull that broke that claim would
# break it quietly — an off-centre ship that banks around a point outside itself,
# or one the lasers pass through at the edges.
#
# What can't be tested here is the facing: a nose is not something geometry
# declares. That one is settled by looking at the model, which is what the
# FACING table in blender/export_alien_variants.py records.
extends GdUnitTestSuite

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")
const ORE_CARRIER_SCENE := preload("res://scenes/OreCarrier.tscn")

# The shape in AlienShip.tscn, which every hull has to fit inside. Repeated
# rather than read back out of the scene, so that changing the box without
# re-measuring the ships fails here instead of silently widening the test.
const COLLISION_BOX := Vector3(1.93, 1.15, 1.87)
# The box was rounded off the saucer's measured bounds, so the saucer fills it
# to within a rounding error rather than sitting comfortably inside it.
const FIT_TOLERANCE: float = 0.02


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


func _true_bounds(mesh: MeshInstance3D) -> AABB:
	"""Bounds of the hull's actual geometry, in the ship's own space.

	Walking the vertices rather than taking `mesh.global_transform *
	mesh.get_aabb()`, which is the obvious one-liner and is wrong here: a
	Transform3D applied to an AABB returns a box enclosing the *rotated box*,
	not the rotated geometry, and it over-reports by up to 40% on a hull whose
	glTF node carries a rotation. Two of the three do — the joined mesh lands in
	whichever Tripo part the export happened to join onto, so the node transform
	carries the difference — and the saucer's is a ~21 degree tilt, which is
	exactly enough to fail a fit this measurement says is fine.
	"""
	var xform := mesh.global_transform
	var bounds := AABB()
	var started := false
	for surface in mesh.mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := xform * vertex
			if started:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				started = true
	return bounds


func _spawn(scene: PackedScene) -> Node3D:
	var ship: Node3D = auto_free(scene.instantiate())
	add_child(ship)
	return ship


func test_the_fleet_is_more_than_one_ship() -> void:
	# The point of the whole change: a wave of identical clones is what this
	# replaces, and an array that got down to one entry would look like working
	# code from every other angle.
	assert_int(AlienShip.HULLS.size()).is_greater(1)
	for hull in AlienShip.HULLS:
		assert_object(hull).is_not_null()


func test_every_hull_fits_the_collision_shape_they_all_share() -> void:
	for hull in AlienShip.HULLS:
		var root: Node3D = auto_free(hull.instantiate())
		add_child(root)
		var mesh := _first_mesh(root)
		assert_object(mesh).is_not_null()

		var aabb := _true_bounds(mesh)
		for axis in 3:
			# Centred: the ship wobbles and banks about its own origin, so a hull
			# modelled off to one side would orbit a point out in empty space.
			assert_float(absf(aabb.get_center()[axis])).is_less(FIT_TOLERANCE)
			# And inside the one box, so no hull has corners the lasers miss.
			assert_float(aabb.size[axis]).is_less(COLLISION_BOX[axis] + FIT_TOLERANCE)


func test_a_spawning_ship_puts_a_hull_on() -> void:
	# AlienShip.tscn ships with an empty Model node, so a ship that failed to
	# draw a hull would fly, steer, take hits and score exactly as it should —
	# while being invisible.
	var mesh := _first_mesh(_spawn(ALIEN_SHIP_SCENE).get_node("Model"))
	assert_object(mesh).is_not_null()
	assert_object(mesh.mesh).is_not_null()


func test_the_ore_carrier_wears_one_too() -> void:
	# The carrier inherits AlienShip.tscn, and that inheritance is the reason it
	# keeps every fix the scout gets. It is also what a hand-authored model node
	# on the carrier would quietly break.
	var mesh := _first_mesh(_spawn(ORE_CARRIER_SCENE).get_node("Model"))
	assert_object(mesh).is_not_null()


func test_the_draw_reaches_every_hull_in_the_pool() -> void:
	# An off-by-one in the pick — `randi() % (size - 1)`, or an index that never
	# reaches the end — costs a ship nobody would ever notice was missing. Over
	# this many spawns the odds of a reachable hull sitting the whole run out are
	# vanishingly small, so a hull that doesn't show up here is unreachable.
	var seen: Array[Mesh] = []
	for i in 60:
		var mesh := _first_mesh(_spawn(ALIEN_SHIP_SCENE).get_node("Model"))
		if mesh != null and not seen.has(mesh.mesh):
			seen.append(mesh.mesh)
	assert_int(seen.size()).is_equal(AlienShip.HULLS.size())
