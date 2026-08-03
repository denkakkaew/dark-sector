# gdUnit4 test suite for SceneLook (Phase 6).
#
# The look is judged by eye, not by assertions — what these tests guard is that
# it is *applied at all*. Every one of them fails against the bug this phase
# actually shipped first: the node exports were wired in `Game.tscn` without the
# `node_paths` declaration, so they silently stayed null and the game came up
# looking like scene 1 whichever scene you were on. Nothing on screen said so.
extends GdUnitTestSuite


func _open_game() -> Node:
	var game: Node = auto_free(load("res://scenes/Game.tscn").instantiate())
	add_child(game)
	return game


func after() -> void:
	# Game.tscn's _ready starts a scene on the real autoload; leave it as found.
	GameState.reset_campaign()


func test_scene_look_reaches_the_nodes_it_dresses() -> void:
	var look := _open_game().get_node("SceneLook")
	assert_object(look.world_environment).is_not_null()
	assert_object(look.sun).is_not_null()
	assert_object(look.fill).is_not_null()
	assert_object(look.earth_image).is_not_null()


func test_the_sky_and_lights_change_with_the_scene() -> void:
	var game := _open_game()
	for index in range(1, CampaignData.count() + 1):
		game.get_node("SceneLook").apply(index)
		var expected := CampaignData.look(index)
		var environment: Environment = game.get_node("WorldEnvironment").environment
		assert_object(environment.background_color).is_equal(expected["space"])
		assert_object(environment.ambient_light_color).is_equal(expected["ambient"])
		assert_float(game.get_node("DirectionalLight3D").light_energy).is_equal_approx(
			expected["sun"]["energy"], 0.001
		)


func test_each_scene_builds_its_own_bodies_and_drops_the_last_ones() -> void:
	var game := _open_game()
	var look := game.get_node("SceneLook")
	for index in range(1, CampaignData.count() + 1):
		look.apply(index)
		# Freeing is deferred, so last scene's bodies are still counted without
		# this — which is exactly how a leak of four scenes' worth would hide.
		await get_tree().process_frame
		var expected: Dictionary = CampaignData.look(index)
		assert_int(look.get_node("Bodies").get_child_count()).is_equal(expected["bodies"].size())
		assert_bool(look.get_node("Stars").visible).is_equal(expected["stars"] > 0.0)
		assert_bool(game.get_node("Backdrop").visible).is_equal(
			expected["earth_image"]["visible"]
		)
