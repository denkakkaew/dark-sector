# gdUnit4 test suite for the CampaignData table (Phase 5).
#
# The table is content, not logic, so these tests guard its *shape*: every field
# the briefing, quiz, HUD and spawner will index into exists and is sane. Adding
# a fifth scene should keep all of this green without touching the tests.
extends GdUnitTestSuite


func test_campaign_has_the_four_storyboard_scenes_in_order() -> void:
	assert_int(CampaignData.count()).is_equal(4)

	var names: Array = []
	for i in range(1, CampaignData.count() + 1):
		names.append(CampaignData.scene_name(i))
	assert_array(names).is_equal(["ISS", "MOON", "MARS", "EARTH"])


func test_every_scene_has_a_story_a_fact_and_a_three_answer_quiz() -> void:
	for i in range(1, CampaignData.count() + 1):
		var entry := CampaignData.scene(i)
		assert_str(entry["title"]).is_not_empty()
		assert_str(entry["story"]).is_not_empty()
		assert_str(entry["fact"]).is_not_empty()
		assert_str(entry["question"]).is_not_empty()

		# Three big touch buttons, per the storyboard — and the correct index has
		# to point at one of them, which is the failure a typo would cause.
		var answers: Array = entry["answers"]
		assert_int(answers.size()).is_equal(3)
		assert_int(entry["correct"]).is_between(0, answers.size() - 1)


func test_backdrop_traffic_is_a_sane_count() -> void:
	# Scenery, not difficulty: a negative count would make the spawn loop in
	# BackdropTraffic silently do nothing, which is a typo you'd never notice.
	for i in range(1, CampaignData.count() + 1):
		assert_int(CampaignData.scene(i)["backdrop_traffic"]).is_greater_equal(0)


func test_every_scene_has_its_own_accent_colour() -> void:
	# The briefing and quiz tint themselves with it, and Phase 6's backdrops will
	# too — two scenes sharing one would make them read as the same place.
	var seen: Array = []
	for i in range(1, CampaignData.count() + 1):
		var accent := CampaignData.accent(i)
		assert_bool(seen.has(accent)).is_false()
		seen.append(accent)


func test_every_wave_is_playable_and_can_pick_a_flight_mode() -> void:
	for i in range(1, CampaignData.count() + 1):
		var wave := CampaignData.wave(i)
		assert_int(wave["count"]).is_greater(0)
		assert_float(wave["interval"]).is_greater(0.0)
		assert_float(wave["speed"]).is_greater(0.0)

		# One weight per flight mode, and at least one of them non-zero — an
		# all-zero row would make the spawner fall back to DIRECT forever.
		var weights: Array = wave["mode_weights"]
		assert_int(weights.size()).is_equal(4)
		var total := 0.0
		for weight in weights:
			assert_float(weight).is_greater_equal(0.0)
			total += weight
		assert_float(total).is_greater(0.0)


func test_difficulty_rises_scene_by_scene() -> void:
	# The storyboard's arc: more ships, arriving faster, flying faster.
	for i in range(1, CampaignData.count()):
		var earlier := CampaignData.wave(i)
		var later := CampaignData.wave(i + 1)
		assert_int(later["count"]).is_greater(earlier["count"])
		assert_float(later["interval"]).is_less(earlier["interval"])
		assert_float(later["speed"]).is_greater(earlier["speed"])


func test_each_scene_has_time_to_fly_its_wave_out() -> void:
	# The time limit is a safety valve, not the challenge: it has to outlast the
	# wave comfortably, or scenes would end on the clock as a matter of course.
	for i in range(1, CampaignData.count() + 1):
		var wave := CampaignData.wave(i)
		var spawn_duration: float = wave["count"] * wave["interval"]
		assert_float(wave["time_limit"]).is_greater(spawn_duration * 1.5)


func test_scene_lookups_clamp_instead_of_crashing() -> void:
	# Callers pass GameState.scene_index around; an off-by-one must not throw.
	assert_str(CampaignData.scene_name(0)).is_equal("ISS")
	assert_str(CampaignData.scene_name(-3)).is_equal("ISS")
	assert_str(CampaignData.scene_name(99)).is_equal("EARTH")
