extends Node
## The kiosk's way of putting itself away.
##
## Phase 8 left the machine with no way out of a run: a player who walks off
## mid-scene leaves it on an outcome card, or halfway through a briefing, until
## somebody touches it. The attract screen never comes back on its own, so the
## next child in the queue arrives at a stranger's dead game rather than at the
## title.
##
## This watches for the absence of input and takes the kiosk home. It is an
## autoload because the thing it measures — "nobody has touched this in a while"
## — spans every screen, and because the screens most likely to be abandoned are
## exactly the ones that have paused the tree.
##
## Deliberately *not* a countdown on the last action: it is a countdown on the
## last input of any kind, which a player who is reading is still producing at
## the tiny scale of a finger resting on the glass. Hence the warning below,
## rather than a shorter timeout.

## Seconds of no input at all before the kiosk resets itself. Long, because the
## fact card is a screen kids are *supposed* to sit still in front of and reading
## it is not idling.
##
## Splitting the briefing in two did not change what this measures. The handoff
## between the two screens is a button press, and a press is input, so the clock
## still counts one screen's worth of stillness — and each of the two is a
## shorter read than the single screen they replaced.
const IDLE_SECONDS: float = 90.0
## How long the "still there?" card is up before the reset. Counted inside
## IDLE_SECONDS, not added to it.
const WARNING_SECONDS: float = 12.0

## Emitted when the kiosk has taken itself back to the title. Nothing listens
## yet; it is here so a future attract mode can restart itself cleanly.
signal reset_to_title

var _idle_time: float = 0.0
var _layer: CanvasLayer
var _card: PanelContainer
var _message: Label


func _ready() -> void:
	# The screens this exists for — the game-over card, the scene-cleared card —
	# have paused the tree. A pausable watchdog would stop counting at precisely
	# the moment it is needed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_warning()


func _input(_event: InputEvent) -> void:
	# Purely an observer: the event is never marked handled, so gameplay,
	# buttons and the sign-in keyboard all see it exactly as before.
	_idle_time = 0.0
	if _layer.visible:
		_layer.hide()


func _process(delta: float) -> void:
	# The title *is* where being idle is the correct state. Counting there would
	# mean reloading the attract screen on top of itself every 90 seconds.
	if _on_title():
		_idle_time = 0.0
		if _layer.visible:
			_layer.hide()
		return

	_idle_time += delta
	var remaining := IDLE_SECONDS - _idle_time
	if remaining <= 0.0:
		_reset()
	elif remaining <= WARNING_SECONDS:
		_show_warning(remaining)


func _on_title() -> bool:
	var current := get_tree().current_scene
	return current != null and current.scene_file_path == SceneRouter.TITLE


## Back to the attract screen with nothing of the last player left on it.
##
## The name goes too. A kiosk that returns to the title still holding "MAYA"
## would hand her sign-in — and her place on the board — to whoever walks up
## next, which is the one thing the sign-in screen exists to prevent.
func _reset() -> void:
	_idle_time = 0.0
	_layer.hide()
	GameState.reset_campaign()
	GameState.player_name = ""
	SceneRouter.show_title()
	reset_to_title.emit()


func _show_warning(remaining: float) -> void:
	_message.text = "Still there?\nTouch anywhere to keep playing.\n\n%d" % ceili(remaining)
	if not _layer.visible:
		_layer.show()


## Built in code rather than as a scene: it belongs to the autoload, and a
## `.tscn` for it would be one more file that has to be kept in the tree of
## every screen it can appear over.
func _build_warning() -> void:
	_layer = CanvasLayer.new()
	# Above the HUD (layer 0) and above the outcome cards inside it.
	_layer.layer = 100
	_layer.hide()
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The card is a notice, not a button. Letting it eat input would mean the
	# touch that dismisses it is also a touch the game never sees.
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(dim)

	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.18, 0.96)
	style.border_color = Color(0.35, 0.68, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(46)
	_card.add_theme_stylebox_override("panel", style)
	_layer.add_child(_card)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 36)
	_message.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	_card.add_child(_message)

	# PRESET_CENTER sizes off the node's rect, which is only known once the label
	# has its font — so the card re-centres itself whenever that changes.
	_card.resized.connect(_centre_card)


func _centre_card() -> void:
	var screen := _layer.get_viewport().get_visible_rect().size
	_card.position = (screen - _card.size) * 0.5
