extends Control
## Storyboard screen 3: the mission briefing that opens every scene.
##
## Story, fact and title all come from `CampaignData` — nothing is written here.
## It auto-advances to the quiz after a beat, so an unattended kiosk keeps
## moving, but a tap cuts it short.

const AUTO_ADVANCE_SECONDS: float = 6.0

@onready var _accent_wash: ColorRect = $AccentWash
@onready var _mission: Label = $Layout/Column/Mission
@onready var _title: Label = $Layout/Column/Title
@onready var _rule: ColorRect = $Layout/Column/Rule
@onready var _callsign: Label = $Layout/Column/Callsign
@onready var _story: Label = $Layout/Column/Story
@onready var _fact_card: PanelContainer = $Layout/Column/FactCard
@onready var _fact_text: Label = $Layout/Column/FactCard/FactBox/FactText
@onready var _hint: Label = $Layout/Column/Hint

var _elapsed: float = 0.0
## Guards the handoff: a tap on the last frame before the timer fires would
## otherwise route twice.
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

	# Breathe, so "TAP TO CONTINUE" reads as an invitation rather than furniture.
	var pulse := create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_hint, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= AUTO_ADVANCE_SECONDS:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _is_debug_jump(event):
		return
	var tapped: bool = (
		(event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or event.is_action_pressed("ui_accept")
		or event.is_action_pressed("fire")
	)
	if tapped:
		_advance()


func _advance() -> void:
	if _advancing:
		return
	_advancing = true
	SceneRouter.show_quiz()


## DEV ONLY — number keys jump straight to a scene's briefing.
##
## Reaching scene 4 otherwise means playing three scenes first, which makes
## tuning the later spawn tables impractical. Delete this, the `DevHint` label
## and its call above before the kiosk build.
func _is_debug_jump(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var scene_index: int = event.keycode - KEY_0
	if scene_index < 1 or scene_index > CampaignData.count():
		return false
	GameState.scene_index = scene_index
	SceneRouter.show_briefing()
	return true
