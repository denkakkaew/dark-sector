class_name DestinationBackdrop
extends Control
## The scene's own photograph, held still behind a menu screen.
##
## Same images and the same cover-fit as the title's attract cycle — this is that
## screen's still frame rather than its slideshow. The briefing and the fact card
## both use it, so a mission reads as a *place* from the moment it opens instead
## of only once the battle loads.
##
## The pictures are photographs of the real `Game.tscn` scenes with the HUD
## hidden, which is why they are worth showing here: the briefing then advertises
## the game the player is about to be dropped into, and cannot drift out of step
## with it. (`CampaignData`'s `look.photo` plates are the other candidate and the
## wrong one — those are authored for a 3D quad, in assorted aspect ratios and
## tinted for scene lighting, not composed to sit behind a paragraph of text.)

## Shared with `AttractBackdrop`, which aliases this rather than keeping its own
## copy — one source of truth, and one test guarding both screens' art.
const IMAGE_PATH := "res://assets/backdrop/destination_%d.png"

## How strongly the photograph is allowed to show. The attract screen can afford
## 0.5 behind an 88-pixel logo; these screens are read at 28 and the story line
## has to win, so they set this lower per instance.
@export_range(0.0, 1.0) var image_alpha: float = 0.40
## Faded in rather than cut to, so the screen arrives instead of appearing.
@export var fade_in: float = 0.9

var _image: TextureRect


func _ready() -> void:
	# Scenery, never a target: the screens above this one own every touch.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var path := IMAGE_PATH % GameState.scene_index
	if not ResourceLoader.exists(path):
		# No still for this destination. The dark backdrop underneath is a
		# perfectly good screen, so this quietly does nothing — same deliberate
		# silence as a missing sound, for the same reason: a kiosk with a child
		# standing at it must not stop for a missing asset.
		return

	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The stills are 16:9, as is the screen this is built for, so "covered" and
	# "not distorted" are the same thing here. COVERED keeps that true if the
	# window is ever letterboxed differently.
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.texture = load(path)
	_image.modulate.a = 0.0
	add_child(_image)

	create_tween().tween_property(_image, "modulate:a", image_alpha, fade_in)


## Jump to the fully-revealed state — what a tap during a screen's reveal asks
## for. Safe to call when there is no photograph.
func settle() -> void:
	if _image != null:
		_image.modulate.a = image_alpha
