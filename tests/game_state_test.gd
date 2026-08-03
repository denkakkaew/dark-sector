# gdUnit4 test suite for the GameState autoload (Phase 4: score & energy math).
#
# Each test builds its own instance of the script rather than touching the
# `GameState` singleton, so the tests can't leak state into each other or into
# a running game.
extends GdUnitTestSuite

const GameStateScript := preload("res://autoload/GameState.gd")


func _make_state() -> Node:
	var state: Node = auto_free(GameStateScript.new())
	state.start_scene(1)
	return state


func test_score_accumulates_and_never_goes_negative() -> void:
	var state := _make_state()
	assert_int(state.score).is_equal(0)

	state.add_score(100)
	state.add_score(250)
	assert_int(state.score).is_equal(350)

	state.add_score(-1000)
	assert_int(state.score).is_equal(0)


func test_damage_drains_energy_and_bottoms_out_at_zero() -> void:
	var state := _make_state()
	assert_float(state.energy).is_equal(state.MAX_ENERGY)

	state.take_damage()
	assert_float(state.energy).is_equal(state.MAX_ENERGY - state.LEAK_DAMAGE)

	# Far more leaks than the bar can absorb: it clamps at 0, never negative.
	for i in 20:
		state.take_damage()
	assert_float(state.energy).is_equal(0.0)


func test_energy_reaching_zero_ends_the_run_once() -> void:
	var state := _make_state()
	var monitor := monitor_signals(state)

	var leaks_to_empty := int(ceil(state.MAX_ENERGY / state.LEAK_DAMAGE))
	for i in leaks_to_empty:
		state.take_damage()

	await assert_signal(monitor).is_emitted("game_over")
	assert_bool(state.scene_running).is_false()

	# Damage after the run has ended is ignored, so game_over can't fire twice.
	state.take_damage()
	assert_float(state.energy).is_equal(0.0)


func test_quiz_sets_starting_energy_as_a_fraction() -> void:
	var state := _make_state()

	state.set_energy(state.PARTIAL_ENERGY)
	assert_float(state.energy).is_equal_approx(state.MAX_ENERGY * state.PARTIAL_ENERGY, 0.001)
	assert_float(state.energy_fraction()).is_equal_approx(state.PARTIAL_ENERGY, 0.001)

	# Out-of-range fractions clamp rather than over/under-charging the bar.
	state.set_energy(2.5)
	assert_float(state.energy).is_equal(state.MAX_ENERGY)
	state.set_energy(-1.0)
	assert_float(state.energy).is_equal(0.0)


func test_reset_campaign_clears_score_energy_and_timer() -> void:
	var state := _make_state()
	state.add_score(700)
	state.take_damage()
	state.elapsed_time = 42.0

	state.reset_campaign()

	assert_int(state.score).is_equal(0)
	assert_float(state.energy).is_equal(state.MAX_ENERGY)
	assert_float(state.elapsed_time).is_equal(0.0)
	assert_int(state.scene_index).is_equal(1)


func test_scene_name_and_time_text_match_the_hud_format() -> void:
	var state := _make_state()
	assert_str(state.scene_name()).is_equal("ISS")

	state.start_scene(3)
	assert_str(state.scene_name()).is_equal("MARS")

	state.elapsed_time = 62.4
	assert_str(state.time_text()).is_equal("1:02")
	state.elapsed_time = 9.0
	assert_str(state.time_text()).is_equal("0:09")
