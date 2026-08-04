extends Control
## The title screen's attract mode: the four destinations, slowly cross-fading.
##
## Storyboard screen 1 asks the idle kiosk to advertise the campaign — "the four
## scene backdrops (ISS, Moon, Mars, Earth) slowly cross-fade behind the logo,
## previewing the campaign". A child walking past should be able to see what
## they would be flying to before deciding to touch anything.
##
## The images are photographs of the *real* battle scenes, taken through
## `Game.tscn` with the HUD hidden, so the attract screen cannot drift out of
## step with what the game actually looks like. Re-shoot them if the scene looks
## change: the harness that made them is described in `planning/IMPLEMENTATION_PLAN.md`.
##
## Everything is driven off `CampaignData`, image path included, so a fifth
## destination is a table entry plus a `destination_5.png` and no code.

const IMAGE_PATH := "res://assets/backdrop/destination_%d.png"
## Seconds a destination is held before it starts giving way to the next.
const HOLD: float = 6.0
const FADE: float = 2.2
## How strongly the photograph is allowed to show. It is behind an 88-pixel logo
## and the one button that matters; at full strength the START button loses its
## edge against Earth's day side.
const IMAGE_ALPHA: float = 0.5

@onready var _caption: Label = $Caption
@onready var _destination: Label = $Caption/Destination

var _layers: Array[TextureRect] = []
var _textures: Array[Texture2D] = []
var _indices: Array[int] = []
var _front: int = 0
var _showing: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_destinations()
	if _textures.is_empty():
		# No photographs yet — the plain dark backdrop underneath is a perfectly
		# good title screen, so this quietly does nothing rather than failing.
		_caption.hide()
		return

	for i in 2:
		var layer := TextureRect.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# The stills are 16:9, as is the screen this is built for, so "covered"
		# and "not distorted" are the same thing here. KEEP_ASPECT_COVERED holds
		# that true if the window is ever letterboxed differently.
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.modulate.a = 0.0
		add_child(layer)
		# Below the caption, which was authored first.
		move_child(layer, i)
		_layers.append(layer)

	_layers[0].texture = _textures[0]
	_layers[0].modulate.a = IMAGE_ALPHA
	_set_caption(0)
	_cycle()


func _load_destinations() -> void:
	for index in range(1, CampaignData.count() + 1):
		var path := IMAGE_PATH % index
		if not ResourceLoader.exists(path):
			continue
		_textures.append(load(path))
		# Kept alongside, because a missing image must not shift the captions:
		# the third *picture* is not necessarily the third *scene*.
		_indices.append(index)


func _cycle() -> void:
	# One destination is not a slideshow. It is also not a bug — a build with a
	# single backdrop should show it, not blink it at itself forever.
	if _textures.size() < 2:
		return
	while is_inside_tree():
		await get_tree().create_timer(HOLD).timeout
		if not is_inside_tree():
			return
		_advance()
		await get_tree().create_timer(FADE).timeout


func _advance() -> void:
	var next := (_showing + 1) % _textures.size()
	var incoming := _layers[1 - _front]
	incoming.texture = _textures[next]
	incoming.modulate.a = 0.0
	# Draw order is child order, so the one fading in has to be moved on top —
	# otherwise it appears from behind the outgoing image and the cross-fade
	# reads as a flicker rather than a dissolve.
	move_child(incoming, _layers.size() - 1)

	var fade := create_tween().set_parallel(true)
	fade.tween_property(incoming, "modulate:a", IMAGE_ALPHA, FADE)
	fade.tween_property(_layers[_front], "modulate:a", 0.0, FADE)

	# The words change at the darkest point of the dissolve, where neither
	# picture is really on screen, so a destination is never captioned wrong.
	var words := create_tween()
	words.tween_property(_caption, "modulate:a", 0.0, FADE * 0.45)
	words.tween_callback(_set_caption.bind(next))
	words.tween_property(_caption, "modulate:a", 1.0, FADE * 0.45)

	_front = 1 - _front
	_showing = next


func _set_caption(slot: int) -> void:
	var index := _indices[slot]
	_caption.text = "MISSION %d OF %d" % [index, CampaignData.count()]
	_destination.text = CampaignData.scene_name(index)
	_destination.add_theme_color_override("font_color", CampaignData.accent(index))
