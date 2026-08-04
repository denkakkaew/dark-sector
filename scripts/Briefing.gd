extends Control
## Storyboard screen 3: the mission briefing that opens every scene.
##
## Story, fact and title all come from `CampaignData` — nothing is written here.
##
## Nothing on this screen is on a timer. The fact card is the teaching moment of
## the whole scene, and kids read at very different speeds, so the player leaves
## when they press the button and not before.

@onready var _accent_wash: ColorRect = $AccentWash
@onready var _mission: Label = $Layout/Column/Mission
@onready var _title: Label = $Layout/Column/Title
@onready var _rule: ColorRect = $Layout/Column/Rule
@onready var _callsign: Label = $Layout/Column/Callsign
@onready var _story: Label = $Layout/Column/Story
@onready var _fact_card: PanelContainer = $Layout/Column/FactCard
@onready var _fact_text: Label = $Layout/Column/FactCard/FactBox/FactText
@onready var _continue_button: Button = $Layout/Column/ContinueButton

## Guards the handoff: the router's scene change is deferred, so the button can
## be pressed again in the frames before this screen actually goes away.
var _advancing: bool = false


func _ready() -> void:
	var index := GameState.scene_index
	var entry := CampaignData.scene(index)
	var accent := CampaignData.accent(index)

	_mission.text = "MISSION %d OF %d" % [index, CampaignData.count()]
	_title.text = entry["title"]
	_story.text = entry["story"]
	_fact_text.text = entry["fact"]

	# Until Phase 8's sign-in exists there is no name to show, and a placeholder
	# one ("DEFENDER: defender") reads worse than no line at all.
	if GameState.player_name.is_empty():
		_callsign.hide()
	else:
		_callsign.text = "DEFENDER %s" % GameState.player_name.to_upper()

	_accent_wash.color = Color(accent, 0.12)
	_rule.color = accent
	var card_style: StyleBoxFlat = _fact_card.get_theme_stylebox("panel").duplicate()
	card_style.border_color = accent
	_fact_card.add_theme_stylebox_override("panel", card_style)

	_continue_button.pressed.connect(_advance)
	# Focused so the keyboard can drive it too — Enter and Space activate a
	# focused Button, which keeps the dev loop quick without a second code path.
	_continue_button.grab_focus()

	# The hint belongs to the dev jump below and goes wherever it goes.
	$DevHint.visible = OS.is_debug_build()


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build():
		_handle_debug_jump(event)


func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	SceneRouter.show_quiz()


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
func _handle_debug_jump(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var scene_index: int = event.keycode - KEY_0
	if scene_index < 1 or scene_index > CampaignData.count():
		return
	GameState.scene_index = scene_index
	SceneRouter.show_briefing()
