extends Control
## Storyboard screen 2: who is about to defend Earth.
##
## The first of the three subsystems that outlive a level. All it has to do is
## put a name in `GameState`, which the briefing greets and the board ranks.
##
## It carries its own on-screen keyboard. Godot's `virtual_keyboard` is an
## Android/iOS feature — on the Windows touchscreen this is built for, tapping a
## `LineEdit` brings up nothing at all, so without these keys the kiosk cannot be
## signed into. The hardware keyboard keeps working alongside them for dev.

const KEY_ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_SIZE := Vector2(84, 62)
const BACKSPACE := "⌫"

@onready var _name_field: LineEdit = $Layout/Column/FieldBox/NameField
@onready var _play_button: Button = $Layout/Column/PlayButton
@onready var _keyboard: VBoxContainer = $Layout/Column/Keyboard
@onready var _back_button: Button = $BackButton

var _leaving: bool = false


func _ready() -> void:
	_name_field.max_length = Leaderboard.NAME_LIMIT
	# The board shows names in a fixed-width column and players re-enter theirs
	# from memory next time; one case removes both problems.
	_name_field.text = GameState.player_name.to_upper()
	_name_field.caret_column = _name_field.text.length()
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_t: String) -> void: _play())
	_name_field.grab_focus()

	_build_keyboard()
	_play_button.pressed.connect(_play)
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_play_button()


func _build_keyboard() -> void:
	for row_index in KEY_ROWS.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		_keyboard.add_child(row)
		for letter in KEY_ROWS[row_index]:
			row.add_child(_make_key(letter))
		# Backspace shares the short bottom row, where there is space for it and
		# where a thumb already is after typing.
		if row_index == KEY_ROWS.size() - 1:
			row.add_child(_make_key(BACKSPACE, 1.6))


func _make_key(label: String, width_scale: float = 1.0) -> Button:
	var key := Button.new()
	key.text = label
	key.custom_minimum_size = Vector2(KEY_SIZE.x * width_scale, KEY_SIZE.y)
	key.add_theme_font_size_override("font_size", 26)
	# Never take focus: the field has to keep the caret so a hardware keyboard
	# and the on-screen one can be used in the same sitting.
	key.focus_mode = Control.FOCUS_NONE
	# Out of the automatic button click and onto a quieter, shorter one. A name
	# is thirty taps; at the volume of a menu button that is a drum solo.
	key.add_to_group(Audio.NO_CLICK_GROUP)
	key.pressed.connect(_on_key_pressed.bind(label))
	return key


func _on_key_pressed(label: String) -> void:
	Audio.play("ui_key", -6.0, 0.05)
	if label == BACKSPACE:
		_name_field.text = _name_field.text.substr(0, maxi(0, _name_field.text.length() - 1))
	elif _name_field.text.length() < Leaderboard.NAME_LIMIT:
		_name_field.text += label
	_name_field.caret_column = _name_field.text.length()
	_refresh_play_button()


func _on_name_changed(_text: String) -> void:
	var caret := _name_field.caret_column
	_name_field.text = _name_field.text.to_upper()
	_name_field.caret_column = caret
	_refresh_play_button()


## PLAY stays disabled on an empty name rather than substituting a default one.
## An unnamed row on a shared board belongs to nobody, and the whole point of
## this screen is that the score has an owner.
func _refresh_play_button() -> void:
	_play_button.disabled = _name_field.text.strip_edges().is_empty()


func _play() -> void:
	var name := _name_field.text.strip_edges()
	if name.is_empty() or _leaving:
		return
	_leaving = true
	GameState.player_name = name
	SceneRouter.start_campaign()


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.show_title()
