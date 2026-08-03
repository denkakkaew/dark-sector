extends Control
## Red warning frame that pulses inward from the screen edge when an alien gets
## through (storyboard beat 5b).
##
## Drawn as a stack of nested rectangle outlines with alpha falling off toward
## the centre — a vignette without needing a shader or a texture, which keeps it
## safe under the GL-Compatibility renderer.

const BANDS: int = 16
const BAND_WIDTH: float = 7.0
const PEAK_ALPHA: float = 0.55
const FADE_TIME: float = 0.7

var _intensity: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


func pulse() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_intensity = 1.0
	set_process(true)
	_tween = create_tween()
	_tween.tween_property(self, "_intensity", 0.0, FADE_TIME).set_trans(Tween.TRANS_QUAD)
	_tween.finished.connect(func() -> void:
		set_process(false)
		queue_redraw())


func _draw() -> void:
	if _intensity <= 0.001:
		return
	for i in BANDS:
		# Squared falloff: bright right at the edge, gone a sixth of the way in.
		var t := 1.0 - float(i) / float(BANDS)
		var alpha := _intensity * t * t * PEAK_ALPHA
		var inset := (float(i) + 0.5) * BAND_WIDTH
		var band := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return
		draw_rect(band, Color(1.0, 0.18, 0.12, alpha), false, BAND_WIDTH)
