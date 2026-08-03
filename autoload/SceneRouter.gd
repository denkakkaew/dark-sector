extends Node
## Every screen transition in the game.
##
## Registered as an autoload so any screen can hand off to the next one without
## knowing what that is. Keeping the whole flow in one file is the point: the
## campaign's shape — briefing → quiz → battle → cleared → briefing … → victory —
## is readable here rather than scattered across buttons and outcome cards.
##
## `GameState` holds *what* the run is; this holds *where* the player is.

const BRIEFING := "res://scenes/Briefing.tscn"
const QUIZ := "res://scenes/Quiz.tscn"
const GAME := "res://scenes/Game.tscn"

## Start a fresh run at scene 1's briefing. The entry point for Play and Retry.
func start_campaign() -> void:
	GameState.reset_campaign()
	show_briefing()


func show_briefing() -> void:
	_go_to(BRIEFING)


func show_quiz() -> void:
	_go_to(QUIZ)


## Into the battle. The quiz has already charged the energy bar by this point;
## `Game.tscn` starts the scene itself once it is loaded.
func start_battle() -> void:
	_go_to(GAME)


## A scene's wave is done: on to the next briefing.
##
## When that was the last scene the campaign is won, and a fresh one begins —
## the victory message is shown by the card that calls this, and Phase 8 routes
## to the real Results screen from here instead.
func finish_scene() -> void:
	if GameState.advance_scene():
		show_briefing()
	else:
		start_campaign()


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
