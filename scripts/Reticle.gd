extends Control

var reticle_pos: Vector2 = Vector2.ZERO

const RADIUS: float = 20.0
const GAP: float = 6.0
const LINE_LEN: float = 14.0
const THICKNESS: float = 2.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_arc(reticle_pos, RADIUS, 0.0, TAU, 32, Color.WHITE, THICKNESS)
	var r := RADIUS + GAP
	draw_line(reticle_pos + Vector2(0.0, -r - LINE_LEN), reticle_pos + Vector2(0.0, -r), Color.WHITE, THICKNESS)
	draw_line(reticle_pos + Vector2(0.0,  r),            reticle_pos + Vector2(0.0, r + LINE_LEN), Color.WHITE, THICKNESS)
	draw_line(reticle_pos + Vector2(-r - LINE_LEN, 0.0), reticle_pos + Vector2(-r, 0.0), Color.WHITE, THICKNESS)
	draw_line(reticle_pos + Vector2(r, 0.0),             reticle_pos + Vector2(r + LINE_LEN, 0.0), Color.WHITE, THICKNESS)
