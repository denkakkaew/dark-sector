extends Control
## Storyboard screen 3b: the "DID YOU KNOW?" card, on its own.
##
## Split out of the briefing so that the fact is the only thing on the screen
## when it is read. It is the teaching moment of the whole scene, and the quiz on
## the very next screen asks about exactly this card — which is why the variant is
## drawn once by `SceneRouter.show_briefing()` and only *read* here, through
## `GameState.quiz_entry()`. Rolling it in `_ready()` would show one fact and ask
## about another.
##
## Nothing here is on a timer, deliberately. Kids read at very different speeds,
## so the staged reveal is a flourish rather than a clock: a tap anywhere skips it
## to its finished state, and the player still leaves when they press the button.

## The reveal schedule, in seconds from the screen opening. Kept together so the
## pacing is one block to tune at the kiosk.
const MISSION_AT: float = 0.00
const CARD_AT: float = 0.20
const BADGE_AT: float = 0.55
const RULE_AT: float = 0.80
const FACT_AT: float = 1.00
const REMEMBER_AT: float = 1.50
const BUTTON_AT: float = 1.60
const REVEAL_ENDS: float = 1.95
## The fact's own fade is the longest on either screen. It is the line the whole
## scene is built around, so it arrives last and slowest.
const FACT_FADE: float = 0.55
const RULE_WIDTH: float = 260.0

@onready var _accent_wash: ColorRect = $AccentWash
@onready var _photo: DestinationBackdrop = $Photo
@onready var _mission: Label = $Layout/Column/Mission
@onready var _card: PanelContainer = $Layout/Column/Card
@onready var _badge: Label = $Layout/Column/Card/CardBox/Badge
@onready var _rule: ColorRect = $Layout/Column/Card/CardBox/Rule
@onready var _fact_text: Label = $Layout/Column/Card/CardBox/FactText
@onready var _remember: Label = $Layout/Column/Remember
@onready var _continue_button: Button = $Layout/Column/ContinueButton

## Guards the handoff: the router's scene change is deferred, so the button can
## be pressed again in the frames before this screen actually goes away.
var _advancing: bool = false
## False until the staged reveal has finished or been skipped. While it is false
## the button is inert, and the tap that would have pressed it finishes the
## reveal instead.
var _revealed: bool = false
var _reveal_tween: Tween


func _ready() -> void:
	var index := GameState.scene_index
	var accent := CampaignData.accent(index)

	_mission.text = "MISSION %d OF %d · %s" % [
		index, CampaignData.count(), CampaignData.scene_name(index)
	]
	# Read, never drawn — see the header. This is the card the briefing promised
	# and the card the quiz is about.
	_fact_text.text = GameState.quiz_entry()["fact"]

	_accent_wash.color = Color(accent, 0.16)
	_rule.color = accent
	# Duplicated so the recolour cannot leak into anything else sharing the theme.
	var card_style: StyleBoxFlat = _card.get_theme_stylebox("panel").duplicate()
	card_style.border_color = accent
	_card.add_theme_stylebox_override("panel", card_style)

	_continue_button.pressed.connect(_advance)

	_hide_for_reveal()
	_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if _revealed:
		return
	var tapped: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("fire")
	)
	if tapped:
		_settle()


## Everything the reveal brings in starts invisible. The button additionally
## stops taking input: `disabled` alone leaves a Button on MOUSE_FILTER_STOP, so
## an invisible 460×84 rectangle would swallow the tap meant to skip the reveal.
func _hide_for_reveal() -> void:
	for node in _revealed_nodes():
		node.modulate.a = 0.0
	_rule.custom_minimum_size.x = 0.0
	_card.scale = Vector2(0.93, 0.93)
	_continue_button.disabled = true
	_continue_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _reveal() -> void:
	# One frame so the containers have sorted. `size` is zero until then, and the
	# card's pivot — and so the direction it pops from — would be its top-left
	# corner instead of its middle.
	await get_tree().process_frame
	if not is_inside_tree() or _revealed:
		return
	_card.pivot_offset = _card.size * 0.5

	# One parallel tween with a delay per step, rather than a chain: a skip is
	# then a single `kill()`, and the schedule above reads as the timeline it is.
	_reveal_tween = create_tween().set_parallel(true)
	_fade_in(_mission, MISSION_AT, 0.30)
	_fade_in(_card, CARD_AT, 0.45)
	_reveal_tween.tween_property(_card, "scale", Vector2.ONE, 0.45) \
		.set_delay(CARD_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_in(_badge, BADGE_AT, 0.30)
	_reveal_tween.tween_property(_rule, "custom_minimum_size:x", RULE_WIDTH, 0.30) \
		.set_delay(RULE_AT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_in(_fact_text, FACT_AT, FACT_FADE)
	_fade_in(_remember, REMEMBER_AT, 0.30)
	_fade_in(_continue_button, BUTTON_AT, 0.35)
	# A single soft blip as the card lands — "look here", not a fanfare. Quiet
	# enough to sit under the menu bed the router is already playing.
	_reveal_tween.tween_callback(Audio.play.bind("countdown", -4.0)).set_delay(BADGE_AT)
	_reveal_tween.tween_callback(_settle).set_delay(REVEAL_ENDS)


func _fade_in(node: CanvasItem, at: float, duration: float) -> void:
	_reveal_tween.tween_property(node, "modulate:a", 1.0, duration).set_delay(at)


## The fully-revealed state, reached either by the schedule finishing or by a tap
## asking for it now. One function, so the two paths cannot drift apart.
func _settle() -> void:
	if _revealed:
		return
	_revealed = true
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_photo.settle()
	for node in _revealed_nodes():
		node.modulate.a = 1.0
	_card.scale = Vector2.ONE
	_rule.custom_minimum_size.x = RULE_WIDTH
	_continue_button.disabled = false
	_continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Focused so Enter and Space work here too, as on every other screen.
	_continue_button.grab_focus()


func _revealed_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = [
		_mission, _card, _badge, _rule, _fact_text, _remember, _continue_button
	]
	return nodes


func _advance() -> void:
	# A press that lands mid-reveal asks for the rest of the screen, not the next
	# one. Belt and braces with the button being inert until `_settle()`.
	if not _revealed:
		_settle()
		return
	if _advancing:
		return
	_advancing = true
	SceneRouter.show_quiz()
