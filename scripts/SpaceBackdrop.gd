extends Control
## The living space backdrop behind the briefing and the quiz: Earth held well
## back, with alien ships patrolling across it.
##
## Both screens are text screens first — the fact card is the whole point of the
## briefing, and a misread question is a wasted energy bar — so everything here
## is deliberately faint and slow. The opacities below are the knobs to reach for
## if it ever competes with the words in front of it.
##
## The ships are a sprite rendered from the same saucer model the battle uses
## (`assets/backdrop/alien_ship_side.png`), so these screens and the gameplay
## show the same enemy, without a 3D subviewport inside a menu.

const ALIEN := preload("res://assets/backdrop/alien_ship_side.png")

## Earth's opacity. Low enough that white text stays legible over the bright
## limb and the city lights, which are the worst case on this image.
@export_range(0.0, 1.0) var image_opacity: float = 0.32
## Faint on purpose. Both screens have centred text, so a crossing ship passes
## behind words no matter which lane it takes; at this weight that reads as
## depth rather than as clutter.
@export_range(0.0, 1.0) var ship_opacity: float = 0.35
@export var ship_count: int = 3
## On-screen width of a ship, in pixels at the 1152×648 design resolution.
@export var ship_width_range := Vector2(80.0, 130.0)
## Pixels per second. A crossing takes roughly half a minute: this is scenery
## behind something you are meant to be reading, not a thing to watch.
@export var speed_range := Vector2(26.0, 44.0)
## Vertical band the ships patrol, as a fraction of screen height. High in the
## star field: below this they start crossing the quiz's question, which is the
## one line on either screen that has to be read exactly.
@export var lane_range := Vector2(0.06, 0.18)
@export var bob_amplitude: float = 9.0
@export var bob_rate: float = 0.5

@onready var _image: TextureRect = $Image
@onready var _traffic: Control = $Traffic

var _ships: Array[Dictionary] = []


func _ready() -> void:
	_image.modulate.a = image_opacity
	for i in ship_count:
		_add_ship(i, ship_count)


func _add_ship(index: int, total: int) -> void:
	var screen := get_viewport_rect().size
	var sprite := Sprite2D.new()
	sprite.texture = ALIEN
	sprite.modulate.a = ship_opacity

	var width := randf_range(ship_width_range.x, ship_width_range.y)
	sprite.scale = Vector2.ONE * (width / float(ALIEN.get_width()))
	_traffic.add_child(sprite)

	# Spread them along the crossing and alternate headings, so they read as
	# traffic passing rather than a formation flying by.
	var along := (float(index) + 0.5) / float(total)
	var lane := lerpf(lane_range.x, lane_range.y, randf())
	var ship := {
		"node": sprite,
		"x": lerpf(-_margin(sprite), screen.x + _margin(sprite), along),
		"y": screen.y * lane,
		"heading": 1.0 if index % 2 == 0 else -1.0,
		"speed": randf_range(speed_range.x, speed_range.y),
		"bob": randf() * TAU,
	}
	_ships.append(ship)
	_place(ship)


func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	for ship in _ships:
		var margin := _margin(ship["node"])
		ship["x"] += ship["heading"] * ship["speed"] * delta
		# Turning happens past the edge, so what's on screen is a crossing and
		# never the turn itself.
		if ship["x"] > screen.x + margin:
			ship["x"] = screen.x + margin
			ship["heading"] = -1.0
		elif ship["x"] < -margin:
			ship["x"] = -margin
			ship["heading"] = 1.0
		ship["bob"] += delta
		_place(ship)


func _place(ship: Dictionary) -> void:
	var sprite: Sprite2D = ship["node"]
	sprite.position = Vector2(
		ship["x"], ship["y"] + sin(ship["bob"] * bob_rate) * bob_amplitude
	)
	# The sprite was rendered nose-right, so it only needs flipping to fly left.
	sprite.flip_h = ship["heading"] < 0.0


func _margin(sprite: Sprite2D) -> float:
	return ALIEN.get_width() * sprite.scale.x * 0.5 + 20.0
