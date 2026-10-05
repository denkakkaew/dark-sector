# gdUnit4 test suite for Worker, the scenery worker (Mars' drones around the rig).
#
# It is judged by eye, but a few properties are cheap to pin down and are exactly
# what would go wrong quietly: a worker that wandered off its post and across the
# colony, one that never moved at all (an unattached or mis-seeded script looks
# identical to a statue), or one that walked sideways. And the Mars set has to have
# actually attached it.
extends GdUnitTestSuite

const WorkerScript := preload("res://scripts/Worker.gd")


func _worker(seed_value: int = 7, radius: float = 3.0) -> Node3D:
	var node: Node3D = auto_free(Node3D.new())
	node.set_script(WorkerScript)
	node.roam_radius = radius
	node.seed_value = seed_value
	node.position = Vector3(40.0, 0.0, -60.0)
	add_child(node)
	return node


func _run(node: Node3D, seconds: float, step: float = 0.05) -> Array[Vector3]:
	var trail: Array[Vector3] = []
	for i in int(seconds / step):
		node._process(step)
		trail.append(node.position)
	return trail


func test_it_stays_within_its_roam_radius_of_where_it_was_placed() -> void:
	var node := _worker()
	var home := node.position
	for position in _run(node, 120.0):
		assert_float(Vector2(position.x - home.x, position.z - home.z).length()).is_less(3.0 + 0.05)


func test_it_actually_moves_and_also_stops_to_work() -> void:
	var node := _worker()
	var trail := _run(node, 60.0)
	var moved := 0
	var still := 0
	for i in range(1, trail.size()):
		if trail[i].distance_to(trail[i - 1]) > 0.001:
			moved += 1
		else:
			still += 1
	# Both, plenty: a statue and a sleepwalker are the two ways this goes wrong.
	assert_int(moved).is_greater(100)
	assert_int(still).is_greater(100)


func test_it_faces_the_way_it_walks() -> void:
	# The model faces +Z, so facing a heading means its +Z points along the step.
	var node := _worker()
	var checked := 0
	var previous := node.position
	for i in 1200:
		node._process(0.05)
		var step := node.position - previous
		previous = node.position
		step.y = 0.0
		if step.length() < 0.02:
			continue
		# Skip the turn onto a new heading; check once it has settled.
		var facing := Vector3(node.global_basis.z.x, 0.0, node.global_basis.z.z).normalized()
		if facing.dot(step.normalized()) > 0.9:
			checked += 1
	assert_int(checked).is_greater(200)


func test_two_workers_with_different_seeds_do_not_move_in_step() -> void:
	var a := _worker(1)
	var b := _worker(2)
	var trail_a := _run(a, 30.0)
	var trail_b := _run(b, 30.0)
	var same := 0
	for i in trail_a.size():
		if trail_a[i].is_equal_approx(trail_b[i]):
			same += 1
	assert_int(same).is_less(trail_a.size() / 2)


func test_the_mars_drones_are_really_workers() -> void:
	var set_scene: Node3D = auto_free(load(CampaignData.look(3)["set"]).instantiate())
	add_child(set_scene)
	var drones := 0
	for child in set_scene.get_children():
		if child.name.begins_with("Drone"):
			drones += 1
			assert_object(child.get_script()).is_same(WorkerScript)
	assert_int(drones).is_greater(0)
