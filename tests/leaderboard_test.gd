# gdUnit4 test suite for the Leaderboard autoload (Phase 8: ranking).
#
# Each test builds its own instance of the script and points `file_path` at a
# throwaway file, so nothing here can read or overwrite a real player's board.
# `.new()` doesn't run `_ready()`, so the instance starts empty until a test
# calls `load_board()` itself — which is what makes the persistence test honest.
extends GdUnitTestSuite

const LeaderboardScript := preload("res://autoload/Leaderboard.gd")
const TEST_PATH := "user://test_leaderboard.json"


func before_test() -> void:
	_delete_test_file()


func after_test() -> void:
	_delete_test_file()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _make_board() -> Node:
	var board: Node = auto_free(LeaderboardScript.new())
	board.file_path = TEST_PATH
	return board


# One run, with everything but the interesting field defaulted — so each test
# below reads as the one thing it is actually about.
func _run(
	name: String,
	score: int,
	scene_reached: int = 4,
	quiz_correct: int = 4,
	time: float = 120.0,
	won: bool = true
) -> Dictionary:
	return {
		"name": name,
		"score": score,
		"scene_reached": scene_reached,
		"quiz_correct": quiz_correct,
		"quiz_total": 4,
		"time": time,
		"won": won,
	}


func _names(board: Node) -> Array:
	var out: Array = []
	for entry in board.entries:
		out.append(entry["name"])
	return out


func test_board_ranks_by_score_and_reports_the_new_rank() -> void:
	var board := _make_board()
	assert_int(board.record(_run("REX", 8420))).is_equal(0)
	assert_int(board.record(_run("NOVA", 12300))).is_equal(0)
	# Lands between the two already there.
	assert_int(board.record(_run("ARIA", 9850))).is_equal(1)

	assert_array(_names(board)).is_equal(["NOVA", "ARIA", "REX"])
	assert_int(board.last_run_rank).is_equal(1)
	assert_str(board.last_run["name"]).is_equal("ARIA")


func test_equal_scores_break_on_scene_then_quiz_then_time() -> void:
	var board := _make_board()
	# All on 5000, and each name says what that run is worst at.
	board.record(_run("SLOW", 5000, 4, 4, 200.0))
	board.record(_run("FAST", 5000, 4, 4, 100.0))
	board.record(_run("GUESSER", 5000, 4, 2, 100.0))
	board.record(_run("SHALLOW", 5000, 3, 4, 10.0))

	# Getting further beats everything else, so SHALLOW is last however fast it
	# was. Among the three that reached scene 4, knowing more beats being quicker
	# — GUESSER's fast time doesn't lift it over SLOW. Time only separates FAST
	# and SLOW, who are level on both.
	assert_array(_names(board)).is_equal(["FAST", "SLOW", "GUESSER", "SHALLOW"])


func test_board_is_trimmed_and_a_run_that_misses_it_reports_no_rank() -> void:
	var board := _make_board()
	for i in board.MAX_ENTRIES:
		board.record(_run("P%d" % i, 1000 + i))

	assert_int(board.entries.size()).is_equal(board.MAX_ENTRIES)
	assert_int(board.record(_run("LATE", 1))).is_equal(-1)
	assert_int(board.entries.size()).is_equal(board.MAX_ENTRIES)
	assert_int(board.last_run_rank).is_equal(-1)
	# The run is still remembered even though it isn't on the board — Results
	# shows it as an extra row rather than dropping it silently.
	assert_str(board.last_run["name"]).is_equal("LATE")


func test_personal_best_is_measured_against_the_players_earlier_runs() -> void:
	var board := _make_board()
	# A player's first run is always their best, even at zero.
	board.record(_run("ARIA", 0))
	assert_bool(board.last_run_personal_best).is_true()

	board.record(_run("NOVA", 9000))
	board.record(_run("ARIA", 4000))
	assert_bool(board.last_run_personal_best).is_true()

	# Beaten by their own earlier run, not by the board leader.
	board.record(_run("ARIA", 3000))
	assert_bool(board.last_run_personal_best).is_false()

	# Names are matched case-insensitively: the kiosk upper-cases them, but a
	# board carried over from an older file may not have.
	board.record(_run("aria", 5000))
	assert_bool(board.last_run_personal_best).is_true()


func test_forget_last_run_leaves_the_board_alone() -> void:
	var board := _make_board()
	board.record(_run("ARIA", 9850))
	board.forget_last_run()

	assert_int(board.last_run_rank).is_equal(-1)
	assert_bool(board.last_run.is_empty()).is_true()
	assert_bool(board.last_run_personal_best).is_false()
	assert_int(board.entries.size()).is_equal(1)


func test_board_survives_a_reload_from_disk() -> void:
	var board := _make_board()
	board.record(_run("NOVA", 12300, 4, 4, 158.0))
	board.record(_run("ARIA", 9850, 3, 2, 174.0, false))

	var reloaded := _make_board()
	reloaded.load_board()
	assert_array(_names(reloaded)).is_equal(["NOVA", "ARIA"])

	var second: Dictionary = reloaded.entries[1]
	assert_int(second["score"]).is_equal(9850)
	assert_int(second["scene_reached"]).is_equal(3)
	assert_int(second["quiz_correct"]).is_equal(2)
	assert_float(second["time"]).is_equal_approx(174.0, 0.001)
	# JSON has no bool/int distinction worth trusting — the sanitiser has to hand
	# these back as the types the sorter and the screen expect.
	assert_bool(second["won"]).is_false()


func test_an_unreadable_board_is_an_empty_board_not_a_crash() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not a leaderboard")
	file.close()

	var board := _make_board()
	board.load_board()
	assert_int(board.entries.size()).is_equal(0)
	# And it recovers: the next run starts a fresh board over the bad file.
	assert_int(board.record(_run("ARIA", 100))).is_equal(0)


func test_rows_are_coerced_into_shape_on_the_way_in() -> void:
	var board := _make_board()
	# A hand-edited or older row: missing fields, a name past the limit, a
	# negative score, a scene index off the end of the campaign, and more correct
	# answers than questions asked.
	board.record({
		"name": "  A_VERY_LONG_CALL_SIGN  ",
		"score": -500,
		"scene_reached": 99,
		"quiz_correct": 9,
		"quiz_total": 2,
	})

	var entry: Dictionary = board.entries[0]
	assert_int(entry["name"].length()).is_less_equal(board.NAME_LIMIT)
	assert_int(entry["score"]).is_equal(0)
	assert_int(entry["scene_reached"]).is_equal(CampaignData.count())
	assert_int(entry["quiz_correct"]).is_equal(2)
	assert_float(entry["time"]).is_equal(0.0)
	assert_bool(entry["won"]).is_false()


func test_record_run_takes_the_finished_run_off_game_state() -> void:
	var board := _make_board()
	var restore := [
		GameState.player_name, GameState.score, GameState.scene_index,
		GameState.quiz_correct_count, GameState.quiz_total_count, GameState.elapsed_time,
	]
	GameState.player_name = "ARIA"
	GameState.score = 9850
	GameState.scene_index = 3
	GameState.quiz_correct_count = 2
	GameState.quiz_total_count = 3
	GameState.elapsed_time = 174.0

	board.record_run(false)
	var entry: Dictionary = board.entries[0]
	assert_str(entry["name"]).is_equal("ARIA")
	assert_int(entry["score"]).is_equal(9850)
	assert_int(entry["scene_reached"]).is_equal(3)
	assert_int(entry["quiz_correct"]).is_equal(2)
	assert_int(entry["quiz_total"]).is_equal(3)
	# `won` is passed in, not derived: dying on scene 4 and clearing it leave the
	# same scene index behind.
	assert_bool(entry["won"]).is_false()

	# An unnamed run — only reachable by launching a gameplay scene directly in
	# development — is still recorded, under the anonymous call sign.
	GameState.player_name = ""
	board.record_run(true)
	assert_str(board.last_run["name"]).is_equal(board.ANONYMOUS)

	GameState.player_name = restore[0]
	GameState.score = restore[1]
	GameState.scene_index = restore[2]
	GameState.quiz_correct_count = restore[3]
	GameState.quiz_total_count = restore[4]
	GameState.elapsed_time = restore[5]
