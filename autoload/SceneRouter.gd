extends Node
## Every screen transition in the game.
##
## Registered as an autoload so any screen can hand off to the next one without
## knowing what that is. Keeping the whole flow in one file is the point: the
## shape of a session — title → sign-in → (briefing → quiz → battle → cleared) ×4
## → results — is readable here rather than scattered across buttons and cards.
##
## `GameState` holds *what* the run is; this holds *where* the player is.

const TITLE := "res://scenes/Title.tscn"
const SIGN_IN := "res://scenes/SignIn.tscn"
const BRIEFING := "res://scenes/Briefing.tscn"
const QUIZ := "res://scenes/Quiz.tscn"
const GAME := "res://scenes/Game.tscn"
const RESULTS := "res://scenes/Results.tscn"

## True when Results was opened from the title rather than at the end of a run.
## The same screen serves both — a board is a board — but there is no run to
## highlight and nothing to play again, so it reads this and drops those parts.
var ranking_only: bool = false

## Guards `finish_run()`. Scene changes are deferred, so a card's button is still
## live for a frame or two after it is pressed, and a second press would post the
## same run to the board twice.
var _run_finished: bool = false


func show_title() -> void:
	Leaderboard.forget_last_run()
	_go_to(TITLE)


func show_sign_in() -> void:
	_go_to(SIGN_IN)


## Start a fresh run at scene 1's briefing. The entry point for Play and for
## Play Again; the player's name is already in `GameState` by this point and
## `reset_campaign()` deliberately leaves it there.
func start_campaign() -> void:
	GameState.reset_campaign()
	Leaderboard.forget_last_run()
	_run_finished = false
	show_briefing()


func show_briefing() -> void:
	_go_to(BRIEFING)


func show_quiz() -> void:
	_go_to(QUIZ)


## Into the battle. The quiz has already charged the energy bar by this point;
## `Game.tscn` starts the scene itself once it is loaded.
func start_battle() -> void:
	_go_to(GAME)


## A scene's wave is done: on to the next briefing, or — when that was the last
## scene — the campaign is won and the run goes on the board.
func finish_scene() -> void:
	if GameState.advance_scene():
		show_briefing()
	else:
		finish_run(true)


## The run is over, either way. Records it and shows the board.
##
## `won` distinguishes clearing scene 4 from dying on it; both leave
## `scene_index` at 4, so nothing downstream could work it out for itself.
func finish_run(won: bool) -> void:
	if _run_finished:
		return
	_run_finished = true
	ranking_only = false
	Leaderboard.record_run(won)
	_go_to(RESULTS)


## The board on its own, from the title. Nothing is recorded and nothing is
## highlighted — it is the attract screen's "who's winning" shortcut.
func show_ranking() -> void:
	ranking_only = true
	_go_to(RESULTS)


func _go_to(scene_path: String) -> void:
	# Two things every transition has to do, which is most of why they all come
	# through here.
	#
	# The outcome cards pause the tree to freeze the battle behind them. A new
	# screen loading into a still-paused tree is a dead screen: nothing
	# processes, no button responds, and it looks like a hang rather than a bug.
	get_tree().paused = false
	# Deferred because callers are typically button handlers or signal callbacks,
	# and changing scene from inside one frees the node that is mid-emit.
	get_tree().call_deferred("change_scene_to_file", scene_path)
