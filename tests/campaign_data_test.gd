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


func test_every_scene_has_a_story_and_a_pool_of_facts_to_teach() -> void:
	for i in range(1, CampaignData.count() + 1):
		var entry := CampaignData.scene(i)
		assert_str(entry["title"]).is_not_empty()
		assert_str(entry["story"]).is_not_empty()

		# Several, so a kiosk replayed back to back doesn't teach the same fact
		# every time. One would still work; it would just stop being a campaign
		# worth playing twice.
		assert_int(CampaignData.quiz_count(i)).is_greater(1)

		for variant in CampaignData.quiz_count(i):
			var quiz := CampaignData.quiz(i, variant)
			assert_str(quiz["fact"]).is_not_empty()
			assert_str(quiz["question"]).is_not_empty()

			# Three big touch buttons, per the storyboard — and the correct index
			# has to point at one of them, which is the failure a typo would cause.
			var answers: Array = quiz["answers"]
			assert_int(answers.size()).is_equal(3)
			assert_int(quiz["correct"]).is_between(0, answers.size() - 1)
			for answer in answers:
				assert_str(answer).is_not_empty()


func test_no_scene_hides_its_answer_in_the_same_slot_every_time() -> void:
	# Kids find "it's always the first button" long before they find any
	# astronomy, and then the quiz stops teaching anything at all.
	for i in range(1, CampaignData.count() + 1):
		var slots: Array = []
		for variant in CampaignData.quiz_count(i):
			var correct: int = CampaignData.quiz(i, variant)["correct"]
			if not slots.has(correct):
				slots.append(correct)
		assert_int(slots.size()).is_greater(1)


func test_no_scene_asks_the_same_question_twice() -> void:
	# A duplicate in a pool is invisible in play — it just quietly makes one fact
	# twice as likely as the rest — so it has to be caught here.
	for i in range(1, CampaignData.count() + 1):
		var questions: Array = []
		for variant in CampaignData.quiz_count(i):
			var question: String = CampaignData.quiz(i, variant)["question"]
			assert_bool(questions.has(question)).is_false()
			questions.append(question)


func test_a_drawn_variant_is_always_one_of_the_scenes_own() -> void:
	for i in range(1, CampaignData.count() + 1):
		for roll in 30:
			assert_int(CampaignData.random_quiz_variant(i)).is_between(
				0, CampaignData.quiz_count(i) - 1
			)


func test_a_draw_never_repeats_the_variant_it_is_asked_to_avoid() -> void:
	# The point of the pool: a second run in a row teaches a different fact.
	for i in range(1, CampaignData.count() + 1):
		for previous in CampaignData.quiz_count(i):
			for roll in 30:
				assert_int(CampaignData.random_quiz_variant(i, previous)).is_not_equal(previous)


func test_every_variant_in_a_pool_can_actually_come_up() -> void:
	# Avoiding the previous pick must not shrink the pool to a shuttle between two
	# variants — over a run of draws every fact in the scene should appear.
	var scene_index := 1
	var pool_size := CampaignData.quiz_count(scene_index)
	var seen: Array = []
	var previous := -1
	for roll in pool_size * 50:
		previous = CampaignData.random_quiz_variant(scene_index, previous)
		if not seen.has(previous):
			seen.append(previous)
	assert_int(seen.size()).is_equal(pool_size)


func test_quiz_lookups_clamp_instead_of_crashing() -> void:
	# `quiz_variant` is carried across a scene change in GameState, so a stale one
	# from a longer pool must not be an out-of-bounds read on the briefing.
	for i in range(1, CampaignData.count() + 1):
		var first := CampaignData.quiz(i, 0)
		var last := CampaignData.quiz(i, CampaignData.quiz_count(i) - 1)
		assert_str(CampaignData.quiz(i, -5)["question"]).is_equal(first["question"])
		assert_str(CampaignData.quiz(i, 999)["question"]).is_equal(last["question"])


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


func test_every_scene_has_a_look_the_battlefield_can_be_dressed_from() -> void:
	# SceneLook.gd indexes every one of these without guarding, so a missing key
	# is a crash on entering the scene rather than a scene that looks plain.
	for i in range(1, CampaignData.count() + 1):
		var look := CampaignData.look(i)
		assert_float(look["sun"]["energy"]).is_greater(0.0)
		assert_float(look["fill"]["energy"]).is_greater_equal(0.0)
		assert_float(look["stars"]).is_between(0.0, 1.0)
		assert_bool(look["photo"]["visible"] is bool).is_true()

		# A backdrop path that doesn't resolve is a push_warning and a scene with
		# no backdrop — deliberately, so a kiosk never stops for it, which also
		# means a typo here is invisible in play. This is what catches it.
		if look["photo"]["visible"]:
			assert_bool(ResourceLoader.exists(look["photo"]["texture"])).override_failure_message(
				"Scene %d's backdrop image is missing: %s" % [i, look["photo"]["texture"]]
			).is_true()

		for body in look["bodies"]:
			assert_float(body["radius"]).is_greater(0.0)
			assert_float(body["mottle"]).is_between(0.0, 1.0)
			assert_float(body["emission"]).is_greater_equal(0.0)
			# Bodies are scenery: in front of the guns is the play area, and a
			# planet parked in it would be something to shoot at.
			assert_float(body["position"].z).is_less(0.0)


func test_every_scene_is_lit_differently_from_the_last() -> void:
	# The point of the phase: four destinations that read as four places. Two
	# scenes sharing a sky and an ambient would be two scenes that look the same.
	var seen: Array = []
	for i in range(1, CampaignData.count() + 1):
		var look := CampaignData.look(i)
		var signature := [look["space"], look["ambient"]]
		assert_bool(seen.has(signature)).is_false()
		seen.append(signature)


func test_the_ore_carrier_is_slower_tougher_and_worth_more() -> void:
	# The storyboard's whole trade in one assertion: it gives the player time and
	# pays out, in exchange for having to be hit several times.
	var carrier := CampaignData.ORE_CARRIER
	assert_int(carrier["hit_points"]).is_greater(1)
	assert_float(carrier["speed_scale"]).is_less(1.0)
	assert_float(carrier["size"]).is_greater(1.0)
	assert_int(carrier["score"]).is_greater(100)


func test_a_spawn_plan_sends_exactly_the_carriers_its_wave_asks_for() -> void:
	for i in range(1, CampaignData.count() + 1):
		var wave := CampaignData.wave(i)
		var plan := CampaignData.spawn_plan(i)
		assert_int(plan.size()).is_equal(wave["count"])
		assert_int(plan.count(true)).is_equal(wave["ore_carriers"])

		# The opening spawns are always ordinary scouts, so a scene never starts
		# on the enemy that needs three hits.
		for slot in CampaignData.ORE_CARRIER_LEAD_IN:
			assert_bool(plan[slot]).is_false()


func test_carriers_arrive_spread_across_the_wave_not_as_a_convoy() -> void:
	# Mars is the only scene with any, and the wave should feel like carriers
	# turning up through it rather than one clump the player either catches or
	# misses. Rolled several times: this is randomised per run.
	var scene_index := 3
	var wave := CampaignData.wave(scene_index)
	var carriers: int = wave["ore_carriers"]
	assert_int(carriers).is_greater(0)

	var first: int = CampaignData.ORE_CARRIER_LEAD_IN
	var band := float(wave["count"] - first) / float(carriers)
	for roll in 20:
		var slots: Array = []
		var plan := CampaignData.spawn_plan(scene_index)
		for slot in plan.size():
			if plan[slot]:
				slots.append(slot)
		assert_int(slots.size()).is_equal(carriers)
		for i in slots.size():
			assert_int(slots[i]).is_between(first + int(i * band), first + int((i + 1) * band))


func test_scene_lookups_clamp_instead_of_crashing() -> void:
	# Callers pass GameState.scene_index around; an off-by-one must not throw.
	assert_str(CampaignData.scene_name(0)).is_equal("ISS")
	assert_str(CampaignData.scene_name(-3)).is_equal("ISS")
	assert_str(CampaignData.scene_name(99)).is_equal("EARTH")
