extends Node
## Campaign-wide game state: score, energy, quiz tally and the run timer.
##
## Registered as an autoload so it outlives any single screen. Score, quiz tally
## and elapsed time carry across the whole 4-scene campaign; energy does not —
## from Phase 7 each scene's pre-battle quiz charges it fresh via `set_energy()`.
##
## Everything here is plain data plus signals. Nothing reaches into the scene
## tree, so the HUD, the spawner and (later) the router can all react to the same
## state without knowing about each other.

signal score_changed(score: int)
signal energy_changed(energy: float, max_energy: float)
## A leak: an alien got through. Carries the damage so feedback can scale to it.
signal damage_taken(amount: float)
signal game_over
signal scene_started(index: int)

const MAX_ENERGY: float = 100.0
## Energy lost per alien that gets through — five leaks end a full bar.
const LEAK_DAMAGE: float = 20.0
## Fraction of the bar a wrong quiz answer starts a scene with (storyboard: a
## handicap, not a knockout). Used from Phase 7; defined here with the rest of
## the energy rules.
const PARTIAL_ENERGY: float = 0.7
const SCENE_COUNT: int = 4

# Phase 6 moves the per-scene content into CampaignData.gd; the HUD only needs
# the display name, so it lives here until that table exists.
const SCENE_NAMES: PackedStringArray = ["ISS", "MOON", "MARS", "EARTH"]

var score: int = 0
var energy: float = MAX_ENERGY
var quiz_correct_count: int = 0
var quiz_total_count: int = 0
## Total time across the campaign, in seconds. Only advances while a scene is
## actually being played.
var elapsed_time: float = 0.0
var scene_index: int = 1
var player_name: String = ""
## True between `start_scene()` and the run ending. Gates the timer.
var scene_running: bool = false


func _ready() -> void:
	# The timer must not tick while the game-over overlay has the tree paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if scene_running:
		elapsed_time += delta


## Wipe everything for a fresh run (new player, or Retry after a game over).
func reset_campaign() -> void:
	score = 0
	energy = MAX_ENERGY
	quiz_correct_count = 0
	quiz_total_count = 0
	elapsed_time = 0.0
	scene_index = 1
	scene_running = false
	score_changed.emit(score)
	energy_changed.emit(energy, MAX_ENERGY)


func start_scene(index: int) -> void:
	scene_index = clampi(index, 1, SCENE_COUNT)
	scene_running = true
	scene_started.emit(scene_index)
	# Re-announce so a HUD that was built after the state changed shows the
	# current values rather than its placeholder ones.
	score_changed.emit(score)
	energy_changed.emit(energy, MAX_ENERGY)


func scene_name() -> String:
	return SCENE_NAMES[clampi(scene_index - 1, 0, SCENE_NAMES.size() - 1)]


func add_score(points: int) -> void:
	if points == 0:
		return
	score = maxi(0, score + points)
	score_changed.emit(score)


## Charge the bar to a fraction of full — how the quiz sets starting energy.
func set_energy(fraction: float) -> void:
	energy = clampf(fraction, 0.0, 1.0) * MAX_ENERGY
	energy_changed.emit(energy, MAX_ENERGY)


## An alien got through. Drains the bar and ends the run when it empties.
func take_damage(amount: float = LEAK_DAMAGE) -> void:
	if not scene_running:
		return
	energy = maxf(0.0, energy - amount)
	damage_taken.emit(amount)
	energy_changed.emit(energy, MAX_ENERGY)
	if energy <= 0.0:
		end_run()


func energy_fraction() -> float:
	return energy / MAX_ENERGY


func end_run() -> void:
	if not scene_running:
		return
	scene_running = false
	game_over.emit()


## Formats the run timer as M:SS for the HUD.
func time_text() -> String:
	var total := int(elapsed_time)
	return "%d:%02d" % [total / 60, total % 60]
