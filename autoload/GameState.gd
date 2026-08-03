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
## The scene's wave is over. `timed_out` is true when the scene's time limit
## ran out rather than the wave being flown out — see CampaignData's `time_limit`.
signal scene_cleared(index: int, timed_out: bool)

const MAX_ENERGY: float = 100.0
## Energy lost per alien that gets through — five leaks end a full bar.
const LEAK_DAMAGE: float = 20.0
## Fraction of the bar a wrong quiz answer starts a scene with (storyboard: a
## handicap, not a knockout). Used from Phase 7; defined here with the rest of
## the energy rules.
const PARTIAL_ENERGY: float = 0.7

var score: int = 0
var energy: float = MAX_ENERGY
var quiz_correct_count: int = 0
var quiz_total_count: int = 0
## Total time across the campaign, in seconds. Only advances while a scene is
## actually being played.
var elapsed_time: float = 0.0
## Seconds left in the current scene, counted down from the scene's `time_limit`.
## This is the timer the HUD shows; `elapsed_time` is the campaign total behind it.
var scene_time_left: float = 0.0
var scene_index: int = 1
var player_name: String = ""
## True between `start_scene()` and the scene or the run ending. Gates both timers.
var scene_running: bool = false


func _ready() -> void:
	# The timer must not tick while the game-over overlay has the tree paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	tick(delta)


## Advance both clocks. Split out of `_process` so the timing rules can be
## driven from a test without putting this node in a tree.
func tick(delta: float) -> void:
	if not scene_running:
		return
	elapsed_time += delta
	scene_time_left = maxf(0.0, scene_time_left - delta)
	if scene_time_left <= 0.0:
		complete_scene(true)


## Wipe everything for a fresh run (new player, or Retry after a game over).
func reset_campaign() -> void:
	score = 0
	energy = MAX_ENERGY
	quiz_correct_count = 0
	quiz_total_count = 0
	elapsed_time = 0.0
	scene_time_left = 0.0
	scene_index = 1
	scene_running = false
	score_changed.emit(score)
	energy_changed.emit(energy, MAX_ENERGY)


func start_scene(index: int) -> void:
	scene_index = clampi(index, 1, CampaignData.count())
	scene_time_left = CampaignData.wave(scene_index)["time_limit"]
	scene_running = true
	scene_started.emit(scene_index)
	# Re-announce so a HUD that was built after the state changed shows the
	# current values rather than its placeholder ones.
	score_changed.emit(score)
	energy_changed.emit(energy, MAX_ENERGY)


## The scene's wave is over. Called by the spawner once every alien in the wave
## has been resolved, and by the timer when the scene's limit runs out.
func complete_scene(timed_out: bool = false) -> void:
	if not scene_running:
		return
	scene_running = false
	scene_cleared.emit(scene_index, timed_out)


## Step to the next scene, returning false when the campaign is already on its
## last one — i.e. false means "that was the win". The next scene isn't started
## here: `start_scene()` is called by the gameplay scene once it is loaded.
func advance_scene() -> bool:
	if campaign_complete():
		return false
	scene_index += 1
	return true


func campaign_complete() -> bool:
	return scene_index >= CampaignData.count()


func scene_name() -> String:
	return CampaignData.scene_name(scene_index)


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


## Formats the campaign timer as M:SS — the total shown on end-of-run cards.
func time_text() -> String:
	return _mmss(int(elapsed_time))


## Formats the scene countdown as M:SS for the HUD's clock. Rounded *up*, so the
## clock only shows 0:00 when the time really is gone.
func scene_time_text() -> String:
	return _mmss(int(ceil(scene_time_left)))


func _mmss(total_seconds: int) -> String:
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]
