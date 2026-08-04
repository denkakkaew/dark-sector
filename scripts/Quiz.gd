extends Control
## Storyboard screen 4: one question about the fact the briefing just showed,
## and the answer charges the energy bar the battle is fought on.
##
## Correct → full bar + bonus score. Wrong → the right answer is shown warmly
## and the bar charges to ~70%. There is no other penalty: the storyboard is
## firm that kids can't lose here, only learn. The rule itself lives in
## `GameState.record_quiz_answer()`; this screen only presents it.

const FEEDBACK_SECONDS: float = 1.8
const COUNTDOWN_STEP: float = 0.6
const CORRECT_COLOR := Color(0.25, 0.92, 0.62)
const WRONG_COLOR := Color(0.95, 0.42, 0.38)
const LETTERS: PackedStringArray = ["A", "B", "C"]

@onready var _accent_wash: ColorRect = $AccentWash
@onready var _question: Label = $Layout/Column/Question
@onready var _answers: VBoxContainer = $Layout/Column/Answers
@onready var _feedback: Label = $Layout/Column/Feedback
@onready var _energy_bar: ProgressBar = $Layout/Column/EnergyRow/EnergyBar
@onready var _countdown: Label = $Layout/Column/Countdown

var _correct_index: int = 0
var _answered: bool = false
## Set once the feedback has been read and the countdown is running — from then
## on a tap skips straight into the battle.
var _skippable: bool = false


func _ready() -> void:
	var index := GameState.scene_index
	var entry := CampaignData.scene(index)
	_correct_index = entry["correct"]
	_question.text = entry["question"]
	_accent_wash.color = Color(CampaignData.accent(index), 0.12)

	var answers: Array = entry["answers"]
	for i in _answers.get_child_count():
		var button: Button = _answers.get_child(i)
		if i >= answers.size():
			button.hide()
			continue
		button.text = "%s · %s" % [LETTERS[i], answers[i]]
		button.pressed.connect(_on_answer_pressed.bind(i))

	# The bar starts empty and fills to what the answer earns, so the reward
	# reads as the thing being carried into the fight rather than a number.
	_energy_bar.max_value = GameState.MAX_ENERGY
	_energy_bar.value = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable:
		return
	var tapped: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("fire")
	)
	if tapped:
		_launch()


func _on_answer_pressed(chosen: int) -> void:
	if _answered:
		return
	_answered = true
	var correct := chosen == _correct_index
	GameState.record_quiz_answer(correct)
	# A rising arpeggio, or a soft two-note shrug. The wrong-answer cue is
	# deliberately not a buzzer: the storyboard is firm that a kid cannot lose
	# here, and a buzzer is the sound of being told off.
	Audio.play("quiz_correct" if correct else "quiz_wrong", 1.0)

	_mark_answers(chosen, correct)
	_feedback.add_theme_color_override("font_color", CORRECT_COLOR if correct else WRONG_COLOR)
	if correct:
		_feedback.text = "CORRECT!   Energy fully charged   +%d bonus" % GameState.QUIZ_BONUS
	else:
		var answers: Array = CampaignData.scene(GameState.scene_index)["answers"]
		_feedback.text = "Good try! The answer is %s — %s" % [
			LETTERS[_correct_index], answers[_correct_index]
		]

	var fill := create_tween()
	fill.tween_property(_energy_bar, "value", GameState.energy, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_run_countdown()


func _mark_answers(chosen: int, correct: bool) -> void:
	for i in _answers.get_child_count():
		var button: Button = _answers.get_child(i)
		# Left interactive-looking but inert: `disabled` greys a button out, and
		# the greying would swallow the colour that says which answer was right.
		button.focus_mode = Control.FOCUS_NONE
		if i == _correct_index:
			button.add_theme_color_override("font_color", CORRECT_COLOR)
		elif i == chosen and not correct:
			button.add_theme_color_override("font_color", WRONG_COLOR)
		else:
			button.modulate.a = 0.45


func _run_countdown() -> void:
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	if not is_inside_tree():
		return
	# Only now, so a stray tap can't skip the feedback before it has been read.
	_skippable = true
	for n in [3, 2, 1]:
		_countdown.text = "%d" % n
		Audio.play("countdown")
		await get_tree().create_timer(COUNTDOWN_STEP).timeout
		# A tap during the countdown launches early and frees this screen; the
		# awaits above would otherwise carry on touching freed nodes.
		if not is_inside_tree():
			return
	_countdown.text = "LAUNCH!"
	_launch()


func _launch() -> void:
	if not _skippable:
		return
	_skippable = false
	Audio.play("launch")
	SceneRouter.start_battle()
