extends Control

var reticle_pos: Vector2 = Vector2.ZERO
## The gun is jammed by an alien's shock: the reticle turns electric blue and
## stutters, so a child pressing fire and getting nothing can see why.
var jammed: bool = false

const RADIUS: float = 20.0
const GAP: float = 6.0
const LINE_LEN: float = 14.0
const THICKNESS: float = 2.0
const JAMMED_COLOR := Color(0.45, 0.75, 1.0)
## Pixels the jammed reticle jumps about by.
const JAMMED_JITTER: float = 3.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var colour := Color.WHITE
	var centre := reticle_pos
	if jammed:
		colour = JAMMED_COLOR
		colour.a = randf_range(0.35, 1.0)
		centre += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * JAMMED_JITTER
	draw_arc(centre, RADIUS, 0.0, TAU, 32, colour, THICKNESS)
	var r := RADIUS + GAP
	draw_line(centre + Vector2(0.0, -r - LINE_LEN), centre + Vector2(0.0, -r), colour, THICKNESS)
	draw_line(centre + Vector2(0.0,  r),            centre + Vector2(0.0, r + LINE_LEN), colour, THICKNESS)
	draw_line(centre + Vector2(-r - LINE_LEN, 0.0), centre + Vector2(-r, 0.0), colour, THICKNESS)
	draw_line(centre + Vector2(r, 0.0),             centre + Vector2(r + LINE_LEN, 0.0), colour, THICKNESS)
