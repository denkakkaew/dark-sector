# gdUnit4 test suite for FlightFloor and the ships' ground clearance.
#
# What these guard is that an alien never flies *through* rock. On screen a ship
# sliding through a sandstone ledge reads instantly as broken; in a test it is a
# number — the hull's underside below the rock's top — so that is what is checked.
extends GdUnitTestSuite

const ALIEN_SCENE := preload("res://scenes/AlienShip.tscn")

## A 4 x 3 x 4 m block of "rock" standing on the ground at (10, -22): far enough
## out that a ship has room to settle back onto its course before the line.
const ROCK_AT := Vector3(10.0, 1.5, -22.0)
const ROCK_SIZE := Vector3(4.0, 3.0, 4.0)


func after() -> void:
	# Game.tscn's _ready starts a scene on the real autoload; leave it as found.
	GameState.reset_campaign()


func _rock_set(tagged: bool = true) -> Node3D:
	var root: Node3D = auto_free(Node3D.new())
	var rock := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = ROCK_SIZE
	rock.mesh = box
	root.add_child(rock)
	if tagged:
		rock.add_to_group(FlightFloor.GROUP)
	add_child(root)
	rock.global_position = ROCK_AT
	return root


func test_the_floor_is_the_top_of_the_rock_and_nothing_elsewhere() -> void:
	var floor := FlightFloor.measure(_rock_set())
	assert_object(floor).is_not_null()
	assert_float(floor.height_at(ROCK_AT.x, ROCK_AT.z)).is_equal_approx(ROCK_AT.y + ROCK_SIZE.y * 0.5, 0.01)
	assert_float(floor.height_at(-20.0, -30.0)).is_equal(FlightFloor.NOTHING)
	# Outside the flight zone altogether: nothing is ever under a ship there.
	assert_float(floor.height_at(500.0, 0.0)).is_equal(FlightFloor.NOTHING)


func test_only_what_is_tagged_is_an_obstacle() -> void:
	# A set opts its rock in. Untagged geometry — a building out beyond the
	# flight zone, a drifting module — is never measured.
	assert_object(FlightFloor.measure(_rock_set(false))).is_null()


func test_a_ship_flown_at_a_rock_climbs_over_it_and_back_onto_its_course() -> void:
	seed(3)
	var floor := FlightFloor.measure(_rock_set())
	var alien: Area3D = auto_free(ALIEN_SCENE.instantiate())
	alien.flight_floor = floor
	add_child(alien)
	alien.global_position = Vector3(ROCK_AT.x, 1.0, -44.0)
	alien.velocity = Vector3(0.0, 0.0, 8.0)
	var half_height: float = (alien.get_node("CollisionShape3D").shape as BoxShape3D).size.y * 0.5
	var rock_top := ROCK_AT.y + ROCK_SIZE.y * 0.5
	var rock_near_edge := ROCK_AT.z - ROCK_SIZE.z * 0.5
	var rock_far_edge := ROCK_AT.z + ROCK_SIZE.z * 0.5
	var climbed_early := false
	var lowest_over_rock := INF
	while alien.global_position.z < 8.5:
		alien._physics_process(1.0 / 60.0)
		var p: Vector3 = alien.global_position
		if p.z < rock_near_edge - 2.0 and alien._lift > 0.5:
			climbed_early = true
		if p.z > rock_near_edge and p.z < rock_far_edge:
			lowest_over_rock = minf(lowest_over_rock, p.y - half_height)
	# Rising well before the rock, not popping up on contact...
	assert_bool(climbed_early).is_true()
	# ...over it with the hull's underside clear of the top the whole way...
	assert_float(lowest_over_rock).is_greater_equal(rock_top)
	# ...and back down on the course it was flying once past.
	assert_float(alien._lift).is_less(0.05)


func test_a_ship_spawned_inside_rock_is_on_top_of_it_from_the_first_frame() -> void:
	var floor := FlightFloor.measure(_rock_set())
	var alien: Area3D = auto_free(ALIEN_SCENE.instantiate())
	alien.flight_floor = floor
	add_child(alien)
	alien.global_position = Vector3(ROCK_AT.x, 1.0, ROCK_AT.z)
	alien.velocity = Vector3(0.0, 0.0, 8.0)
	alien._physics_process(1.0 / 60.0)
	var half_height: float = (alien.get_node("CollisionShape3D").shape as BoxShape3D).size.y * 0.5
	assert_float(alien.global_position.y - half_height).is_greater_equal(ROCK_AT.y + ROCK_SIZE.y * 0.5)


func test_mars_measures_its_ledges_and_the_open_scenes_have_no_floor() -> void:
	var game: Node = auto_free(load("res://scenes/Game.tscn").instantiate())
	add_child(game)
	var look := game.get_node("SceneLook")
	for index in range(1, CampaignData.count() + 1):
		look.apply(index)
		await get_tree().process_frame
		if index == 3:
			assert_object(look.flight_floor).is_not_null()
			# The big ledge framing the left corner (mars_layout.hand_placed_ledges).
			assert_float(look.flight_floor.height_at(-15.5, -1.5)).is_greater(1.5)
		else:
			assert_object(look.flight_floor).is_null()


func test_no_ship_of_a_real_mars_wave_flies_through_rock() -> void:
	# The real spawner, every flight mode, flown to the end. What is checked is
	# the hull's underside against the measured rock under its centre, every frame.
	seed(7)
	GameState.scene_index = 3
	var game: Node = auto_free(load("res://scenes/Game.tscn").instantiate())
	add_child(game)
	var floor: FlightFloor = game.get_node("SceneLook").flight_floor
	game.set("_to_spawn", 0)
	var climbed := 0
	for mode in AlienShip.FlightMode.values():
		game.set("_mode_weights", [0.0, 0.0, 0.0, 0.0])
		game.get("_mode_weights")[mode] = 1.0
		for i in 25:
			game._spawn_alien()
			var alien: AlienShip = game.get_children().back()
			var half_height: float = (alien.get_node("CollisionShape3D").shape as BoxShape3D).size.y * 0.5
			var highest_lift := 0.0
			for frame in 600:
				# Stopped just short of the line: one that crossed it would cost the
				# real campaign energy, and enough of them would end the run.
				if alien.global_position.z > AlienShip.EARTH_Z - 0.5:
					break
				alien._physics_process(1.0 / 60.0)
				var p := alien.global_position
				assert_float(p.y - half_height).is_greater_equal(floor.height_at(p.x, p.z))
				highest_lift = maxf(highest_lift, alien._lift)
			if highest_lift > 0.5:
				climbed += 1
			if is_instance_valid(alien):
				alien.free()
	# And the rock really is in the way of some of them — otherwise this proves
	# nothing about climbing at all.
	assert_int(climbed).is_greater(0)
	print("ships that climbed over rock: ", climbed, " of 100")
