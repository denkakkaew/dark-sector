extends Control
## Gameplay HUD: the storyboard's top bar (energy / scene / timer / score), the
## floating +points popups, the red edge pulse on a leak, and the game-over card.
##
## It is driven entirely by `GameState` signals — it never reads the gameplay
## nodes. The one exception is `pop_score()`, which needs the 3D kill position
## and so is called by `Game.gd`, the only node that knows where the alien died.

const POPUP_RISE: float = 80.0
const POPUP_TIME: float = 0.9
const POPUP_COLOR := Color(1.0, 0.87, 0.35)
## Bar fill colour at full energy and at empty — it reddens as the run gets
## dangerous, so the player reads trouble without having to measure the bar.
const ENERGY_FULL_COLOR := Color(0.25, 0.92, 0.62)
const ENERGY_LOW_COLOR := Color(0.95, 0.24, 0.2)
## Clock colours: normal, and the warning it turns at TIMER_WARNING_SECONDS.
const TIMER_COLOR := Color(0.8, 0.9, 1.0)
const TIMER_WARNING_COLOR := Color(1.0, 0.62, 0.28)
const TIMER_WARNING_SECONDS: float = 10.0

@onready var _energy_bar: ProgressBar = $TopBar/EnergyGroup/EnergyBar
@onready var _scene_label: Label = $TopBar/CentreGroup/SceneLabel
@onready var _timer_label: Label = $TopBar/CentreGroup/TimerLabel
@onready var _score_label: Label = $TopBar/ScoreLabel
@onready var _edge_pulse: Control = $EdgePulse
@onready var _popups: Control = $Popups
@onready var _game_over_panel: Control = $GameOverPanel
@onready var _final_score_label: Label = $GameOverPanel/Card/Layout/FinalScore
@onready var _retry_button: Button = $GameOverPanel/Card/Layout/RetryButton
@onready var _cleared_panel: Control = $SceneClearedPanel
@onready var _cleared_title: Label = $SceneClearedPanel/Card/Layout/Title
@onready var _cleared_summary: Label = $SceneClearedPanel/Card/Layout/Summary
@onready var _continue_button: Button = $SceneClearedPanel/Card/Layout/ContinueButton

var _fill_style: StyleBoxFlat
var _bar_tween: Tween


func _ready() -> void:
	# The game-over card has to stay clickable after it pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_panel.hide()
	_cleared_panel.hide()

	# Own copy of the fill box, so recolouring the bar doesn't leak into any
	# other ProgressBar that shares the theme.
	_fill_style = _energy_bar.get_theme_stylebox("fill").duplicate()
	_energy_bar.add_theme_stylebox_override("fill", _fill_style)

	GameState.score_changed.connect(_on_score_changed)
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.damage_taken.connect(_on_damage_taken)
	GameState.game_over.connect(_on_game_over)
	GameState.scene_started.connect(_on_scene_started)
	GameState.scene_cleared.connect(_on_scene_cleared)
	_retry_button.pressed.connect(_on_retry_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)

	_on_score_changed(GameState.score)
	_on_energy_changed(GameState.energy, GameState.MAX_ENERGY)
	_on_scene_started(GameState.scene_index)


func _process(_delta: float) -> void:
	# The clock counts the scene down, not the campaign up — the campaign total
	# belongs to the end-of-run cards, where there is room to read it.
	_timer_label.text = GameState.scene_time_text()
	var warning := GameState.scene_time_left <= TIMER_WARNING_SECONDS
	_timer_label.add_theme_color_override(
		"font_color", TIMER_WARNING_COLOR if warning else TIMER_COLOR
	)


## Float a "+points" label up from where an alien died (storyboard beat 5a).
func pop_score(world_position: Vector3, points: int) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(world_position):
		return

	var label := Label.new()
	label.text = "+%d" % points
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", POPUP_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_popups.add_child(label)

	# The label only knows its size once it is in the tree with its font applied.
	label.reset_size()
	var screen_pos := camera.unproject_position(world_position)
	label.position = screen_pos - Vector2(label.size.x * 0.5, label.size.y)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - POPUP_RISE, POPUP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, POPUP_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _on_score_changed(score: int) -> void:
	_score_label.text = "คะแนน %d" % score


func _on_energy_changed(energy: float, max_energy: float) -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_energy_bar.max_value = max_energy
	# Slide rather than snap, so a drain reads as a drain and not a redraw.
	_bar_tween = create_tween()
	_bar_tween.tween_property(_energy_bar, "value", energy, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fraction := 0.0 if max_energy <= 0.0 else energy / max_energy
	# Weighted toward red early: the last third of the bar is the dangerous part.
	_fill_style.bg_color = ENERGY_LOW_COLOR.lerp(ENERGY_FULL_COLOR, sqrt(fraction))


func _on_damage_taken(_amount: float) -> void:
	# Loud on purpose. This is the only thing in the game that costs the player
	# anything, and it happens off at the edge of the screen where an alien
	# crossed the line — often while they are looking somewhere else entirely.
	Audio.play("leak", 1.0)
	_edge_pulse.pulse()
	var flash := create_tween()
	flash.tween_property(_energy_bar, "modulate", Color(1.8, 0.5, 0.45), 0.06)
	flash.tween_property(_energy_bar, "modulate", Color.WHITE, 0.35)


func _on_scene_started(index: int) -> void:
	_scene_label.text = "ด่าน %d·%s" % [index, GameState.scene_name()]


func _on_game_over() -> void:
	# Storyboard screen 8 names the scene the run died on rather than numbering
	# it — "Mars" is what the player will tell the next person in the queue.
	_final_score_label.text = "ไปถึงด่าน %d · %s\nคะแนน %d   เวลา %s" % [
		GameState.scene_index, GameState.scene_name(),
		GameState.score, GameState.time_text(),
	]
	# Off the battle bed and back to the calm one: the shooting is over, and the
	# card is a screen to read rather than a moment of pressure.
	Audio.play_music("menu")
	Audio.play("game_over")
	_game_over_panel.show()
	_retry_button.grab_focus()
	# Freezes the battle behind the card; this node is PROCESS_MODE_ALWAYS.
	get_tree().paused = true


func _on_retry_pressed() -> void:
	# The lost run still goes on the board — the storyboard is explicit that it is
	# recorded and shown, and a kiosk board of nothing but wins would only ever
	# have the very best players on it.
	SceneRouter.finish_run(false)


func _on_scene_cleared(index: int, timed_out: bool) -> void:
	var last_scene := GameState.campaign_complete()
	Audio.play_music("menu")
	# Two different cues, because these are two different sizes of moment: one
	# mission down out of four, or the whole campaign held.
	Audio.play("victory" if last_scene else "scene_cleared")
	if last_scene:
		# Storyboard screen 7, and its win line verbatim. The card stays the place
		# the win is announced; CONTINUE hands off to the router, which records
		# the run and opens the board under it (screen 9).
		_cleared_title.text = "เย้!! เราปกป้องโลกไว้ได้แล้ว!"
		_continue_button.text = "ดูอันดับ  ▶"
	else:
		_cleared_title.text = "ผ่านด่าน %d แล้ว!" % index
		_continue_button.text = "ภารกิจต่อไป"
	# A scene that runs out of time still counts as held — the storyboard only
	# ever loses a run on energy — but say so, or the card looks like a bug.
	var lead := "หมดเวลา  " if timed_out else ""
	_cleared_summary.text = "%sคะแนน %d   เวลา %s   ตอบถูก %d/%d" % [
		lead, GameState.score, GameState.time_text(),
		GameState.quiz_correct_count, GameState.quiz_total_count,
	]
	_cleared_panel.show()
	_continue_button.grab_focus()
	get_tree().paused = true


func _on_continue_pressed() -> void:
	# The router decides what follows this scene, and unpauses on the way out.
	SceneRouter.finish_scene()
