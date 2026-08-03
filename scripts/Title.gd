extends Control
## Storyboard screen 1: the attract screen the kiosk idles on between players.
##
## Deliberately almost empty of logic. It is the one screen a passer-by sees
## before deciding whether to touch anything, so it has exactly two ways out —
## into a run, or into the board — and both are one press away.

@onready var _start_button: Button = $Layout/Column/StartButton
@onready var _ranking_button: Button = $Corner/RankingButton
@onready var _logo: Label = $Layout/Column/Logo

## Guards the handoff: the router's scene change is deferred, so a button can be
## pressed again in the frames before this screen actually goes away.
var _leaving: bool = false


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_ranking_button.pressed.connect(_on_ranking_pressed)
	# Focused so Enter and Space work too, which keeps the dev loop quick without
	# a second code path.
	_start_button.grab_focus()
	_breathe_logo()


## A slow pulse on the logo, so an idle kiosk doesn't look like a frozen one.
## The backdrop's drifting ships say the same thing, but they are faint by design
## and from across a room this is what carries.
func _breathe_logo() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_logo, "modulate", Color(1.0, 1.0, 1.0, 0.72), 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_logo, "modulate", Color.WHITE, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.show_sign_in()


func _on_ranking_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SceneRouter.show_ranking()
