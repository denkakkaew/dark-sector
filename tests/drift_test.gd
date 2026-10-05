# gdUnit4 test suite for Drift, the scenery mover (the ISS module passing below the
# turret). It has no collision and nothing reads where it is, so what is worth
# guarding is just that it moves the way the layout says, comes back round, and is
# really on the ISS set — a Drift that wasn't attached would leave a module parked
# in the sky with every other check green.
extends GdUnitTestSuite

const DriftScript := preload("res://scripts/Drift.gd")


func _drifter(velocity: Vector3, wrap_from: float, wrap_to: float) -> Node3D:
	var node: Node3D = auto_free(Node3D.new())
	node.set_script(DriftScript)
	node.velocity = velocity
	node.wrap_from = wrap_from
	node.wrap_to = wrap_to
	add_child(node)
	return node


func test_it_moves_at_its_velocity() -> void:
	var node := _drifter(Vector3(2.0, 0.0, 0.0), -80.0, 80.0)
	node.position = Vector3(-10.0, -5.0, -30.0)
	node._process(1.5)
	assert_float(node.position.x).is_equal_approx(-7.0, 0.001)
	# Only along its velocity: the height and depth it was placed at are kept.
	assert_float(node.position.y).is_equal_approx(-5.0, 0.001)
	assert_float(node.position.z).is_equal_approx(-30.0, 0.001)


func test_it_comes_back_round_once_it_has_crossed() -> void:
	var node := _drifter(Vector3(2.0, 0.0, 0.0), -80.0, 80.0)
	node.position = Vector3(79.5, 0.0, 0.0)
	node._process(1.0)
	assert_float(node.position.x).is_equal_approx(-80.0, 0.001)


func test_the_iss_module_is_set_drifting_left_to_right_below_the_flight_lanes() -> void:
	var set_scene: Node3D = auto_free(load(CampaignData.look(1)["set"]).instantiate())
	add_child(set_scene)
	var module: Node3D = set_scene.get_node("Module")
	assert_object(module.get_script()).is_same(DriftScript)
	# Left to right, slowly: a battle is a minute long and the module should
	# cross it, not shoot past.
	assert_float(module.velocity.x).is_between(0.5, 4.0)
	# And under the lanes aliens fly in, which stay above y=0.3 (a swooping ship
	# is clamped there), so no ship passes through it. Measured off the module's
	# real mesh, not its origin: it is 8 m tall.
	var meshes := module.find_children("*", "MeshInstance3D", true, false)
	assert_int(meshes.size()).is_greater(0)
	var box: AABB = (meshes[0] as MeshInstance3D).global_transform * (meshes[0] as MeshInstance3D).get_aabb()
	assert_float(box.end.y).is_less(0.3)
