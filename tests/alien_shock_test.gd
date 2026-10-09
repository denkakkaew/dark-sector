# gdUnit4 test suite for the scouts' electric shock at the turret.
#
# The shock is a small state machine spread over three nodes — the ship charges
# and discharges, the spawner applies the cost, the turret jams — and every part
# of it fails quietly: a ship that never reaches range, a jam that never lifts,
# or a charge that survives the ship being shot all look like "the feature is
# rare" from the kiosk. These pin the rules down without a window.
extends GdUnitTestSuite

const ALIEN_SHIP_SCENE := preload("res://scenes/AlienShip.tscn")
const TURRET_SCENE := preload("res://scenes/Turret.tscn")

const STEP: float = 0.05


func _field() -> Node3D:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	return root


func _shocker(field: Node3D, at: Vector3) -> AlienShip:
	"""A scout parked at `at` that can shock a target at the origin. Speed 0, so
	it hovers where it is put and only the shock logic moves anything."""
	var target := Node3D.new()
	field.add_child(target)
	var ship: AlienShip = ALIEN_SHIP_SCENE.instantiate()
	ship.speed = 0.0
	field.add_child(ship)
	ship.global_position = at
	ship.shock_target = target
	ship.can_shock = true
	return ship


func _fly(ship: AlienShip, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		ship._physics_process(STEP)
		elapsed += STEP


func test_every_scene_has_a_shock_chance_that_never_falls() -> void:
	var previous := 0.0
	for i in range(1, CampaignData.count() + 1):
		var chance: float = CampaignData.wave(i)["shock_chance"]
		assert_float(chance).is_between(0.0, 1.0)
		assert_float(chance).is_greater_equal(previous)
		previous = chance


func test_a_shock_costs_less_than_a_leak() -> void:
	# The jam is the cost. A shock as expensive as a leak would make the ships
	# that stay away the safe ones — see CampaignData.SHOCK.
	var shock: Dictionary = CampaignData.SHOCK
	assert_float(shock["damage"]).is_greater(0.0)
	assert_float(shock["damage"]).is_less(GameState.LEAK_DAMAGE)
	assert_float(shock["charge_pace"]).is_between(0.01, 0.99)
	assert_float(shock["charge_time"]).is_greater(0.0)
	assert_float(shock["stun_time"]).is_greater(0.0)


func test_a_jagged_arc_runs_end_to_end_without_wandering_off() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var from := Vector3(-3.0, 1.0, 2.0)
	var to := Vector3(4.0, 2.0, -5.0)
	var points := ShockArc.jagged(from, to, 4, 0.2, rng)
	assert_int(points.size()).is_equal(17)
	assert_vector(points[0]).is_equal(from)
	assert_vector(points[points.size() - 1]).is_equal(to)
	# Kicks halve each pass, so no point strays further than twice the first one.
	var limit := from.distance_to(to) * 0.2 * 2.0
	for i in points.size():
		var on_line := from.lerp(to, float(i) / float(points.size() - 1))
		assert_float(points[i].distance_to(on_line)).is_less(limit)


func test_a_shocker_in_range_charges_and_then_shocks_exactly_once() -> void:
	var field := _field()
	var ship := _shocker(field, Vector3(0.0, 0.0, -5.0))
	var shocks := [0]
	ship.shocked_turret.connect(func() -> void: shocks[0] += 1)
	_fly(ship, STEP)
	assert_int(ship.shock_state).is_equal(AlienShip.ShockState.CHARGING)
	_fly(ship, CampaignData.SHOCK["charge_time"] * 0.5)
	assert_int(shocks[0]).is_equal(0)
	_fly(ship, CampaignData.SHOCK["charge_time"] * 2.0)
	assert_int(shocks[0]).is_equal(1)
	assert_int(ship.shock_state).is_equal(AlienShip.ShockState.SPENT)
	# The bolt is left on the field, not on the ship.
	assert_int(field.find_children("*", "ShockArc", false, false).size()).is_equal(1)


func test_a_charging_ship_slows_to_the_charge_pace() -> void:
	var field := _field()
	var ship := _shocker(field, Vector3(0.0, 2.0, -5.0))
	ship.speed = 8.0
	ship._physics_process(STEP)
	var before := ship.global_position.z
	ship._physics_process(STEP)
	var moved := ship.global_position.z - before
	assert_float(moved).is_equal_approx(8.0 * STEP * CampaignData.SHOCK["charge_pace"], 0.001)


func test_a_ship_out_of_range_or_unarmed_never_charges() -> void:
	var field := _field()
	var far := _shocker(field, Vector3(0.0, 0.0, -30.0))
	_fly(far, 1.0)
	assert_int(far.shock_state).is_equal(AlienShip.ShockState.READY)
	var unarmed := _shocker(field, Vector3(0.0, 0.0, -3.0))
	unarmed.can_shock = false
	_fly(unarmed, 1.0)
	assert_int(unarmed.shock_state).is_equal(AlienShip.ShockState.READY)


func test_a_shocker_shot_down_mid_charge_never_shocks() -> void:
	# The whole counterplay: the charge is the easiest shot the ship offers.
	var field := _field()
	var ship := _shocker(field, Vector3(0.0, 0.0, -5.0))
	var shocks := [0]
	ship.shocked_turret.connect(func() -> void: shocks[0] += 1)
	_fly(ship, STEP)
	ship.take_hit()
	_fly(ship, CampaignData.SHOCK["charge_time"] * 2.0)
	assert_int(shocks[0]).is_equal(0)


func test_a_jammed_turret_holds_fire_until_the_jam_lifts() -> void:
	var field := _field()
	var turret: Node3D = TURRET_SCENE.instantiate()
	field.add_child(turret)
	var lasers_before := field.get_child_count()
	turret.stun(1.0)
	assert_bool(turret.is_stunned()).is_true()
	turret.try_fire()
	assert_int(field.get_child_count()).is_equal(lasers_before)
	turret._process(1.1)
	assert_bool(turret.is_stunned()).is_false()
	turret.try_fire()
	assert_int(field.get_child_count()).is_equal(lasers_before + 1)


func test_a_second_shock_extends_the_jam_rather_than_stacking_it() -> void:
	var field := _field()
	var turret: Node3D = TURRET_SCENE.instantiate()
	field.add_child(turret)
	turret.stun(1.2)
	turret._process(1.0)
	turret.stun(1.2)
	turret._process(1.1)
	assert_bool(turret.is_stunned()).is_true()
	turret._process(0.2)
	assert_bool(turret.is_stunned()).is_false()
