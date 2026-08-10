# gdUnit4 test suite for the screens the router can send a player to.
#
# Everything here guards a failure that a running game does not report. A typo in
# a path constant is a `change_scene_to_file` error into a black screen with the
# kiosk still happily running; a renamed node in a hand-edited `.tscn` is a null
# `@onready` the first time a real player reaches that screen; and a screen that
# rolls its own quiz variant shows one fact and is then quizzed on another, which
# looks like nothing at all until a child gets a question about something they
# were never told.
extends GdUnitTestSuite

## The `@onready` paths in `Briefing.gd` and `FactCard.gd`. Kept by hand, like the
## sound list in `audio_test.gd` and for the same reason: writing the line here is
## the moment to notice the node has to exist. The scene paths are spelled out
## rather than taken from `SceneRouter` because an autoload is not available in a
## constant expression — `test_the_router_and_this_suite_agree_on_the_new_screen`
## ties the two back together.
const REQUIRED_NODES: Dictionary = {
	"res://scenes/Briefing.tscn": [
		"AccentWash",
		"Photo",
		"DevHint",
		"Layout/Column/Mission",
		"Layout/Column/Title",
		"Layout/Column/Rule",
		"Layout/Column/Callsign",
		"Layout/Column/Story",
		"Layout/Column/ContinueButton",
	],
	"res://scenes/FactCard.tscn": [
		"AccentWash",
		"Photo",
		"Layout/Column/Mission",
		"Layout/Column/Card",
		"Layout/Column/Card/CardBox/Badge",
		"Layout/Column/Card/CardBox/Rule",
		"Layout/Column/Card/CardBox/FactText",
		"Layout/Column/Remember",
		"Layout/Column/ContinueButton",
	],
}

## The two screens that read the drawn fact. Neither may draw it — see
## `SceneRouter.show_briefing()`.
const READING_SCREENS: PackedStringArray = [
	"res://scripts/Briefing.gd",
	"res://scripts/FactCard.gd",
]


func test_every_screen_the_router_can_reach_exists_on_disk() -> void:
	# Every screen constant on SceneRouter, in the order a session visits them.
	var screens: PackedStringArray = [
		SceneRouter.TITLE,
		SceneRouter.SIGN_IN,
		SceneRouter.BRIEFING,
		SceneRouter.FACT_CARD,
		SceneRouter.QUIZ,
		SceneRouter.GAME,
		SceneRouter.RESULTS,
	]
	for path in screens:
		assert_bool(ResourceLoader.exists(path)) \
			.override_failure_message("SceneRouter points at a missing scene: %s" % path) \
			.is_true()


func test_the_router_and_this_suite_agree_on_the_new_screen() -> void:
	assert_str(SceneRouter.BRIEFING).is_equal("res://scenes/Briefing.tscn")
	assert_str(SceneRouter.FACT_CARD).is_equal("res://scenes/FactCard.tscn")


func test_each_reading_screen_has_the_nodes_its_script_reaches_for() -> void:
	for scene_path in REQUIRED_NODES:
		var root: Node = load(scene_path).instantiate()
		for node_path in REQUIRED_NODES[scene_path]:
			assert_object(root.get_node_or_null(node_path)) \
				.override_failure_message("%s has no node at %s" % [scene_path, node_path]) \
				.is_not_null()
		root.free()


func test_neither_reading_screen_rolls_its_own_quiz_variant() -> void:
	# Crude on purpose. The scene's fact is drawn once, in the router, so that the
	# card the player reads and the question they are asked are the same entry. A
	# second roll anywhere downstream breaks that silently.
	for script_path in READING_SCREENS:
		var source := FileAccess.get_file_as_string(script_path)
		assert_str(source) \
			.override_failure_message(
				"%s rolls the quiz variant — only SceneRouter.show_briefing() may" % script_path
			) \
			.not_contains("roll_quiz_variant")


func test_the_fact_card_is_reached_from_the_briefing_and_leads_to_the_quiz() -> void:
	# The split's whole point is the order of the three screens; this pins it to
	# the router rather than to whichever button happened to be wired last.
	assert_str(FileAccess.get_file_as_string("res://scripts/Briefing.gd")) \
		.contains("SceneRouter.show_fact_card()")
	assert_str(FileAccess.get_file_as_string("res://scripts/FactCard.gd")) \
		.contains("SceneRouter.show_quiz()")
