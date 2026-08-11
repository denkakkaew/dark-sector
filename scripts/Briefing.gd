extends Control
## Storyboard screen 3: the mission briefing that opens every scene.
##
## Where the player is going, and who is going. Title, story and the destination
## photograph all come from `CampaignData` — nothing is written here.
##
## The scene's fact used to sit on this screen too. It has its own screen now
## (`FactCard.tscn`, screen 3b) so that the place and the lesson each get a
## moment, and this one can be staged: the mission arrives a line at a time
## rather than as a page of text a child has to find their way into.
##
## Nothing here is on a timer. The reveal is a flourish, not a clock — it can be
## skipped with a tap, and the player still leaves when they press the button and
## not before.

## The reveal schedule, in seconds from the screen opening. Kept together so the
## pacing is one block to tune at the kiosk rather than seven numbers to hunt.
const MISSION_AT: float = 0.00
const TITLE_AT: float = 0.25
const RULE_AT: float = 0.60
const CALLSIGN_AT: float = 0.85
const STORY_AT: float = 1.05
const BUTTON_AT: float = 1.55
const REVEAL_ENDS: float = 1.90
## Width the accent rule draws open to — the authored value, restored on skip.
const RULE_WIDTH: float = 260.0

@onready var _accent_wash: ColorRect = $AccentWash
@onready var _photo: DestinationBackdrop = $Photo
@onready var _mission: Label = $Layout/Column/Mission
@onready var _title: Label = $Layout/Column/Title
@onready var _rule: ColorRect = $Layout/Column/Rule
@onready var _callsign: Label = $Layout/Column/Callsign
@onready var _story: Label = $Layout/Column/Story
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
	var entry := CampaignData.scene(index)
	var accent := CampaignData.accent(index)

	_mission.text = "ภารกิจที่ %d จาก %d" % [index, CampaignData.count()]
	_title.text = entry["title"]
	_story.text = entry["story"]

	# Until Phase 8's sign-in exists there is no name to show, and a placeholder
	# one ("DEFENDER: defender") reads worse than no line at all.
	if GameState.player_name.is_empty():
		_callsign.hide()
	else:
		_callsign.text = "ผู้พิทักษ์ %s" % GameState.player_name

	_accent_wash.color = Color(accent, 0.16)
	_rule.color = accent

	_continue_button.pressed.connect(_advance)

	# The hint belongs to the dev jump below and goes wherever it goes.
	$DevHint.visible = OS.is_debug_build()

	_hide_for_reveal()
	_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build():
		_handle_debug_jump(event)
	# A number key is not a tap, so the two handlers cannot collide.
	if not _revealed and _is_tap(event):
		_settle()


## Everything the reveal brings in starts invisible. The button additionally
## stops taking input: `disabled` alone leaves a Button on MOUSE_FILTER_STOP, so
## an invisible 460×84 rectangle would swallow the tap meant to skip the reveal.
func _hide_for_reveal() -> void:
	for node in _revealed_nodes():
		node.modulate.a = 0.0
	_rule.custom_minimum_size.x = 0.0
	_title.scale = Vector2(0.94, 0.94)
	_continue_button.disabled = true
	_continue_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _reveal() -> void:
	# One frame so the containers have sorted. `size` is zero until then, and the
	# title's pivot — and so the direction it grows from — would be its top-left
	# corner instead of its middle.
	await get_tree().process_frame
	if not is_inside_tree() or _revealed:
		return
	_title.pivot_offset = _title.size * 0.5

	# One parallel tween with a delay per step, rather than a chain: a skip is
	# then a single `kill()`, and the schedule above reads as the timeline it is.
	_reveal_tween = create_tween().set_parallel(true)
	_fade_in(_mission, MISSION_AT, 0.30)
	_fade_in(_title, TITLE_AT, 0.45)
	_reveal_tween.tween_property(_title, "scale", Vector2.ONE, 0.45) \
		.set_delay(TITLE_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(_rule, "custom_minimum_size:x", RULE_WIDTH, 0.35) \
		.set_delay(RULE_AT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_in(_callsign, CALLSIGN_AT, 0.30)
	_fade_in(_story, STORY_AT, 0.50)
	_fade_in(_continue_button, BUTTON_AT, 0.35)
	# Under the music rather than on top of it: at full volume `launch` is the
	# sound of the battle starting, and the battle is three screens away.
	_reveal_tween.tween_callback(Audio.play.bind("launch", -9.0)).set_delay(TITLE_AT)
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
	_title.scale = Vector2.ONE
	_rule.custom_minimum_size.x = RULE_WIDTH
	_continue_button.disabled = false
	_continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Focused so the keyboard can drive it too — Enter and Space activate a
	# focused Button, which keeps the dev loop quick without a second code path.
	_continue_button.grab_focus()


func _revealed_nodes() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = [
		_mission, _title, _rule, _callsign, _story, _continue_button
	]
	return nodes


func _is_tap(event: InputEvent) -> bool:
	return (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("fire")
	)


func _advance() -> void:
	# A press that lands mid-reveal asks for the rest of the screen, not the next
	# one. Belt and braces with the button being inert until `_settle()`.
	if not _revealed:
		_settle()
		return
	if _advancing:
		return
	_advancing = true
	SceneRouter.show_fact_card()


## DEV ONLY — number keys jump straight to a scene's briefing.
##
## Reaching scene 4 otherwise means playing three scenes first, which makes
## tuning the later spawn tables impractical.
##
## Phase 9 was meant to delete this before the kiosk build. Gating it on
## `OS.is_debug_build()` instead does the same job and survives: a release export
## — which is what the kiosk and the web build are — has neither the keys nor the
## hint label, while the editor and `godot --path .` keep both. Deleting it would
## only have meant writing it again the next time a spawn table needs tuning.
##
## It lives on this screen and not on the fact card: it re-enters through
## `show_briefing()`, which is where the scene's fact is drawn, so from the card
## it would re-roll the fact and bounce the player a screen backwards.
func _handle_debug_jump(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var scene_index: int = event.keycode - KEY_0
	if scene_index < 1 or scene_index > CampaignData.count():
		return
	GameState.scene_index = scene_index
	SceneRouter.show_briefing()
