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


# Collects every `scene_cleared` as `[index, timed_out]`. Counting matters in
# these tests — "cleared once" and "not cleared at all" are the interesting
# cases — and an array of the actual payloads says that without a wait.
func _record_scene_cleared(state: Node) -> Array:
	var clears: Array = []
	state.scene_cleared.connect(
		func(index: int, timed_out: bool) -> void: clears.append([index, timed_out])
	)
	return clears


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


func test_starting_a_scene_charges_its_countdown_from_the_campaign_table() -> void:
	var state := _make_state()
	assert_float(state.scene_time_left).is_equal(CampaignData.wave(1)["time_limit"])

	state.start_scene(4)
	assert_float(state.scene_time_left).is_equal(CampaignData.wave(4)["time_limit"])

	# The clock rounds up, so it only reads 0:00 when the time is actually gone.
	state.scene_time_left = 41.2
	assert_str(state.scene_time_text()).is_equal("0:42")
	state.scene_time_left = 0.0
	assert_str(state.scene_time_text()).is_equal("0:00")


func test_clearing_a_wave_ends_the_scene_once() -> void:
	var state := _make_state()
	var clears := _record_scene_cleared(state)

	state.complete_scene()
	assert_array(clears).is_equal([[1, false]])
	assert_bool(state.scene_running).is_false()

	# A second report — a straggler resolving after the wave — is ignored, so a
	# scene can't be cleared twice.
	state.complete_scene()
	assert_array(clears).is_equal([[1, false]])


func test_the_scene_clock_running_out_ends_the_scene_as_timed_out() -> void:
	var state := _make_state()
	var clears := _record_scene_cleared(state)

	state.scene_time_left = 0.5
	state.tick(0.6)

	assert_array(clears).is_equal([[1, true]])
	assert_float(state.scene_time_left).is_equal(0.0)
	assert_bool(state.scene_running).is_false()

	# Both clocks stop with the scene: neither ticks on once it is over.
	var elapsed: float = state.elapsed_time
	state.tick(1.0)
	assert_float(state.elapsed_time).is_equal(elapsed)


func test_a_leak_that_empties_the_bar_ends_the_run_not_the_scene() -> void:
	var state := _make_state()
	var monitor := monitor_signals(state)
	var clears := _record_scene_cleared(state)

	for i in int(ceil(state.MAX_ENERGY / state.LEAK_DAMAGE)):
		state.take_damage()

	# Game over wins the race: the spawner reports the wave resolved immediately
	# after the leak that emptied the bar, and that must not read as a clear.
	await assert_signal(monitor).is_emitted("game_over")
	state.complete_scene()
	assert_array(clears).is_empty()


func test_a_correct_quiz_answer_charges_the_bar_full_and_pays_a_bonus() -> void:
	var state := _make_state()
	state.set_energy(0.0)

	state.record_quiz_answer(true)

	assert_float(state.energy).is_equal(state.MAX_ENERGY)
	assert_int(state.score).is_equal(state.QUIZ_BONUS)
	assert_int(state.quiz_correct_count).is_equal(1)
	assert_int(state.quiz_total_count).is_equal(1)


func test_a_wrong_quiz_answer_is_a_handicap_not_a_punishment() -> void:
	var state := _make_state()
	state.add_score(1000)

	state.record_quiz_answer(false)

	# A partial bar is the whole cost: no score is taken away, and the run is
	# emphatically not over — the storyboard's "kids can't lose here" rule.
	assert_float(state.energy).is_equal_approx(state.MAX_ENERGY * state.PARTIAL_ENERGY, 0.001)
	assert_int(state.score).is_equal(1000)
	assert_bool(state.scene_running).is_true()
	assert_int(state.quiz_correct_count).is_equal(0)
	assert_int(state.quiz_total_count).is_equal(1)


func test_the_quiz_tally_counts_every_scene_across_the_campaign() -> void:
	var state := _make_state()

	state.record_quiz_answer(true)
	state.record_quiz_answer(false)
	state.record_quiz_answer(true)

	assert_int(state.quiz_correct_count).is_equal(2)
	assert_int(state.quiz_total_count).is_equal(3)
	# Only the two correct ones paid out.
	assert_int(state.score).is_equal(state.QUIZ_BONUS * 2)


func test_advancing_runs_out_at_the_end_of_the_campaign() -> void:
	var state := _make_state()

	for i in range(1, CampaignData.count()):
		assert_bool(state.advance_scene()).is_true()
		assert_int(state.scene_index).is_equal(i + 1)

	# On the last scene there is nowhere to advance to — that is the win.
	assert_bool(state.campaign_complete()).is_true()
	assert_bool(state.advance_scene()).is_false()
	assert_int(state.scene_index).is_equal(CampaignData.count())


func test_the_drawn_quiz_variant_is_what_both_screens_read() -> void:
	# The briefing shows the fact and the quiz asks about it, so they have to be
	# reading one pick — this is the pick.
	var state := _make_state()

	for scene_index in range(1, CampaignData.count() + 1):
		state.scene_index = scene_index
		var drawn: int = state.roll_quiz_variant()
		assert_int(state.quiz_variant).is_equal(drawn)
		assert_str(state.quiz_entry()["question"]).is_equal(
			CampaignData.quiz(scene_index, drawn)["question"]
		)


func test_a_scene_replayed_never_opens_on_the_fact_it_just_taught() -> void:
	# The kiosk case: the same child presses Play again straight away, and the
	# memory of the last draw deliberately outlives `reset_campaign()`.
	var state := _make_state()

	var previous: int = state.roll_quiz_variant()
	for run in 20:
		state.reset_campaign()
		var drawn: int = state.roll_quiz_variant()
		assert_int(drawn).is_not_equal(previous)
		previous = drawn


func test_each_scene_remembers_its_own_last_draw() -> void:
	# Scene 2's pool has nothing to do with scene 1's, so avoiding a repeat must
	# be tracked per scene rather than as one "last variant".
	var state := _make_state()

	state.scene_index = 1
	var first_scene_draw: int = state.roll_quiz_variant()
	state.scene_index = 2
	state.roll_quiz_variant()

	# Back to scene 1: still avoiding scene 1's own last fact, not scene 2's.
	state.scene_index = 1
	for roll in 20:
		assert_int(state.roll_quiz_variant()).is_not_equal(first_scene_draw)
		first_scene_draw = state.quiz_variant


func test_resetting_a_campaign_starts_from_a_defined_variant() -> void:
	var state := _make_state()
	state.scene_index = 3
	state.roll_quiz_variant()

	state.reset_campaign()
	assert_int(state.quiz_variant).is_equal(0)
