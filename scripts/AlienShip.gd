extends Area3D
class_name AlienShip

# Shot down: carries where it died so the HUD can float the points there.
signal destroyed(world_position: Vector3, points: int)
# Crossed the line the player is defending. Named for what it costs rather than
# where it happens: in scenes 1–3 "getting through" is reaching the station, the
# base site, or escaping with ore — only scene 4 is literally reaching Earth.
signal got_through
# Charged up close to the turret and hit it with an electric shock. The ship
# draws the bolt itself; what the shock *does* — the jam, the energy — is the
# spawner's to apply, the same split as `got_through`.
signal shocked_turret

const HIT_EFFECT_SCENE := preload("res://scenes/HitEffect.tscn")
const EARTH_Z: float = 9.0

## The hulls the fleet is drawn from, one picked per ship as it spawns.
##
## They are interchangeable by construction: blender/export_rebuild.py writes
## every one of them centred on its own bounds and facing +Z, so there is no
## per-hull transform here. They are *not* the same size any more — the gunship
## and the heavy cruiser are well over the saucer — so the collision box is
## measured off whichever hull a ship is wearing (see `_fit_collision_to`)
## instead of being one shape for all. Adding a fourth is an export plus a line
## in this array.
##
## The pick is plain random, with no "don't repeat the last one" of the kind
## CampaignData's fact pool needs. Two ships in a wave sharing a hull reads as a
## fleet flying in formation; two runs in a row teaching the same fact reads as
## a broken kiosk. Only one of those is worth code.
const HULLS: Array[PackedScene] = [
	preload("res://assets/object/alien/alien_ship.glb"),
	preload("res://assets/object/alien/alien_ship_2.glb"),
	preload("res://assets/object/alien/alien_ship_3.glb"),
]

enum FlightMode { DIRECT, STRAFE, WEAVE, SWOOP }
enum ShockState { READY, CHARGING, SPENT }

## The turret's gun, which a shocker charges at once it flies within
## `CampaignData.SHOCK.range` of it — handed over by the spawner, like
## `flight_floor`. A ship with `can_shock` false, or no target, never charges.
var shock_target: Node3D
var can_shock: bool = false
## One shock per ship: ready, charging it now, or already spent.
var shock_state: ShockState = ShockState.READY
var _charge_left: float = 0.0
var _charge_light: OmniLight3D
var _charge_arc: ShockArc
var _charge_orb: MeshInstance3D
var _reach: float = 1.0
## Charge glow at its brightest, as the shock is about to land.
const CHARGE_LIGHT_ENERGY: float = 4.0
const SHOCK_COLOR := Color(0.45, 0.75, 1.0)
## The orb of charge gathering at the nose, as a fraction of the hull's reach:
## its radius when fully charged, and how far ahead of the hull's centre it sits.
const CHARGE_ORB_SIZE: float = 0.45
const CHARGE_ORB_AHEAD: float = 0.8

## A hull this ship always wears, instead of drawing one from `HULLS`. The ore
## carrier sets it: it is its own ship, not a scout in armour.
@export var hull_override: PackedScene

## Hit box per hull, measured once off the hull's own geometry and then shared.
static var _hull_boxes: Dictionary = {}

@export var speed: float = 8.0
@export var score_value: int = 100
## Laser hits this ship survives before the last one destroys it. 1 for a scout;
## Mars' ore carrier is the armoured exception.
@export var hit_points: int = 1

# How fast the hull swings onto a new heading, as a rate per second. Low enough
# that the ship banks through a weave instead of snapping between angles, high
# enough that it never looks like it is drifting sideways.
const TURN_RESPONSE: float = 6.0

## Ground clearance. A ship flies the course its flight mode gives it, and where
## rock stands in the way (Mars' sandstone ledges and boulders) it climbs over
## and then sinks back onto that course. It looks ahead along the way it is
## actually moving, so it is already rising as it reaches the rock rather than
## popping up on contact.
##
## The floor comes from the scene's set (`SceneLook.flight_floor`, handed over by
## the spawner); null is open space and the ship flies its course untouched.
var flight_floor: FlightFloor
## How far above the rock the hull's underside stays.
const CLEARANCE: float = 0.6
## Seconds ahead along the ship's own ground track that it checks for rock.
const LOOK_AHEAD: Array[float] = [0.3, 0.6, 0.9, 1.2]
## How quickly it climbs toward the height it needs (per second), and how fast
## it sinks back once past (m/s). Climbing is the urgent one.
const CLIMB_RESPONSE: float = 5.0
const SINK_SPEED: float = 2.0
## Height above its course the ship is flying at right now, to clear the ground.
var _lift: float = 0.0

var velocity: Vector3 = Vector3.ZERO
# Smoothed heading the hull points along. Starts unset: the spawner assigns
# `velocity` after the ship is in the tree, so the first real direction only
# shows up on the first physics frame.
var _facing: Vector3 = Vector3.ZERO
var flight_mode: FlightMode = FlightMode.DIRECT
var _destroyed: bool = false
var _hits_taken: int = 0
# The armour shell's authored strength, remembered so damage can fade it towards
# nothing from whatever the scene set it to.
var _armour_alpha: float = 0.0
var _armour_glow: float = 0.0
var _wobble_time: float = 0.0
var _wobble_amp_x: float = 0.0
var _wobble_amp_y: float = 0.0
var _weave_amp: float = 0.0
var _weave_freq: float = 0.0
var _swoop_amp: float = 0.0
var _swoop_freq: float = 0.0

func _ready() -> void:
	add_to_group("aliens")
	_wear_a_hull()
	area_entered.connect(_on_area_entered)
	_wobble_time = randf() * TAU
	_wobble_amp_x = randf_range(0.4, 1.2)
	_wobble_amp_y = randf_range(0.2, 0.7)
	var armour := get_node_or_null("Armour") as MeshInstance3D
	if armour != null:
		var material := armour.get_surface_override_material(0) as StandardMaterial3D
		if material != null:
			_armour_alpha = material.albedo_color.a
			_armour_glow = material.emission_energy_multiplier

func _wear_a_hull() -> void:
	"""Hang one of the fleet's hulls under `Model`.

	`Model` is an empty in the scene rather than a fixed mesh precisely so this
	can choose. Everything else — the steering, the armour damage, `_explode`
	hiding it — only ever talks to that parent node, so the rest of the script
	neither knows nor cares which ship it is wearing. The ore carrier inherits
	this along with everything else and varies too: what marks a carrier out at a
	glance is its size, its armour shell and its glow, not its silhouette.
	"""
	var hull_scene: PackedScene = hull_override if hull_override != null else HULLS[randi() % HULLS.size()]
	var hull := hull_scene.instantiate()
	$Model.add_child(hull)
	_fit_collision_to(hull_scene, hull)


func _fit_collision_to(hull_scene: PackedScene, hull: Node3D) -> void:
	"""Size the hit box to the hull the ship is wearing.

	The box is the hull's tight bounds, measured over its actual vertices — not
	`mesh.get_aabb()` pushed through the node's transform, which over-reports on
	a hull whose glTF node carries a rotation. A near miss counting as a hit is
	the friendly side to err on for this audience, so there is no margin taken
	off; the geometry is the minimum.
	"""
	if not _hull_boxes.has(hull_scene):
		var box := BoxShape3D.new()
		box.size = _hull_bounds(hull).size
		_hull_boxes[hull_scene] = box
	$CollisionShape3D.shape = _hull_boxes[hull_scene]


func _hull_bounds(hull: Node3D) -> AABB:
	var bounds := AABB()
	var started := false
	var to_model: Transform3D = $Model.global_transform.affine_inverse()
	for mesh in hull.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		var xform: Transform3D = to_model * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := xform * vertex
				if started:
					bounds = bounds.expand(point)
				else:
					bounds = AABB(point, Vector3.ZERO)
					started = true
	return bounds


func _physics_process(delta: float) -> void:
	if _destroyed:
		return
	var previous := global_position
	# A charging ship all but stops, so the flight below is run at its pace;
	# the wobble clock keeps full time, so it still hovers rather than freezing.
	var move_delta := delta * _update_shock(delta)
	# Back down onto the course, so the flight mode moves the ship along it as
	# if no rock were there; the lift goes back on top afterwards.
	global_position.y -= _lift
	var on_course := global_position
	_wobble_time += delta
	var wobble := Vector3(
		sin(_wobble_time * 1.7) * _wobble_amp_x,
		sin(_wobble_time * 1.2 + 1.0) * _wobble_amp_y,
		0.0
	)
	match flight_mode:
		FlightMode.DIRECT:
			if velocity == Vector3.ZERO:
				global_position.z += speed * move_delta
			else:
				global_position += (velocity + wobble) * move_delta
		FlightMode.STRAFE:
			global_position += (velocity + wobble) * move_delta
		FlightMode.WEAVE:
			var lateral := Vector3(sin(_wobble_time * _weave_freq) * _weave_amp, 0.0, 0.0)
			global_position += (velocity + wobble + lateral) * move_delta
		FlightMode.SWOOP:
			var vertical := Vector3(0.0, sin(_wobble_time * _swoop_freq) * _swoop_amp, 0.0)
			global_position += (velocity + wobble + vertical) * move_delta
			global_position.y = maxf(global_position.y, 0.3)
	global_position.y += _clear_the_ground(global_position - on_course, delta)
	# Steered off the step *including* the lift, so a ship climbing over rock
	# noses up, and dips its nose coming down the far side.
	var heading := global_position - previous
	# Charging, it turns to face the gun it is about to hit: a third tell beside
	# the glow and the crackle, and the one that says *which* ship is doing it.
	if shock_state == ShockState.CHARGING:
		heading = shock_target.global_position - global_position
	_steer(heading, delta)
	if global_position.z >= EARTH_Z:
		got_through.emit()
		queue_free()

func _update_shock(delta: float) -> float:
	"""Run the shock: start charging when close enough, discharge when charged.

	Returns the pace the ship flies at this frame — 1 normally, the charge pace
	while it hovers in front of the gun.
	"""
	if not can_shock or not is_instance_valid(shock_target):
		return 1.0
	match shock_state:
		ShockState.READY:
			if global_position.distance_to(shock_target.global_position) <= CampaignData.SHOCK["range"]:
				_start_charge()
				return CampaignData.SHOCK["charge_pace"]
		ShockState.CHARGING:
			_charge_left -= delta
			if _charge_left <= 0.0:
				_discharge()
				return 1.0
			var progress := 1.0 - _charge_left / CampaignData.SHOCK["charge_time"]
			# Brightening as it charges, and unsteady, so it reads as electricity
			# building up rather than a lamp being turned on.
			var flicker := randf_range(0.6, 1.0)
			_charge_light.light_energy = CHARGE_LIGHT_ENERGY * progress * flicker
			# The orb swells toward full size and sits at the nose, on the line to
			# the gun, so the bolt visibly comes out of it.
			var toward := (shock_target.global_position - global_position).normalized()
			_charge_orb.global_position = global_position + toward * _reach * CHARGE_ORB_AHEAD
			_charge_orb.scale = Vector3.ONE * maxf(0.05, progress * (0.8 + 0.2 * flicker))
			return CampaignData.SHOCK["charge_pace"]
	return 1.0


func _start_charge() -> void:
	shock_state = ShockState.CHARGING
	_charge_left = CampaignData.SHOCK["charge_time"]
	Audio.play("shock_charge", -2.0, 0.05)
	var box := ($CollisionShape3D.shape as BoxShape3D).size
	_reach = maxf(box.x, box.z) * 0.5 * scale.x
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = SHOCK_COLOR
	_charge_light.light_energy = 0.0
	_charge_light.omni_range = _reach * 3.0
	add_child(_charge_light)
	_charge_orb = _make_charge_orb()
	add_child(_charge_orb)
	# Arcs crawling over the hull and well past it: at spawn distance a ship is
	# a hand's width on screen, and sparks inside its silhouette would be lost.
	_charge_arc = ShockArc.new()
	_charge_arc.source = self
	_charge_arc.crackle_radius = _reach * 1.6
	_charge_arc.crackle_count = 5
	_charge_arc.width = 0.06
	add_child(_charge_arc)


func _make_charge_orb() -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _reach * CHARGE_ORB_SIZE
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(SHOCK_COLOR, 0.85)
	sphere.material = material
	orb.mesh = sphere
	orb.top_level = true
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.scale = Vector3.ONE * 0.05
	return orb


func _discharge() -> void:
	shock_state = ShockState.SPENT
	_charge_light.queue_free()
	_charge_orb.queue_free()
	_charge_arc.queue_free()
	# The bolt hangs off the field rather than the ship, so it finishes its
	# flash even if the ship is shot down in the middle of it.
	var bolt := ShockArc.new()
	bolt.source = self
	bolt.target = shock_target
	bolt.lifetime = CampaignData.SHOCK["bolt_time"]
	bolt.width = 0.1
	bolt.flicker_interval = 0.04
	get_parent().add_child(bolt)
	Audio.play("shock_zap", 0.0, 0.05)
	shocked_turret.emit()


func _clear_the_ground(step: Vector3, delta: float) -> float:
	"""How far above its course the ship flies this frame; it is on course now.

	Climbs smoothly toward the highest rock found along the next second or so of
	its ground track (taken from the step it really moved, so a weave's swerve is
	looked along too), and never less than what the rock directly under it needs:
	the look-ahead makes the climb smooth, the floor under it makes it certain.
	"""
	if flight_floor == null:
		return 0.0
	var track := Vector3(step.x, 0.0, step.z) / maxf(delta, 0.0001)
	var under := _climb_needed(global_position)
	var wanted := under
	for seconds in LOOK_AHEAD:
		wanted = maxf(wanted, _climb_needed(global_position + track * seconds))
	if wanted > _lift:
		_lift = lerpf(_lift, wanted, minf(1.0, delta * CLIMB_RESPONSE))
	else:
		_lift = move_toward(_lift, wanted, SINK_SPEED * delta)
	_lift = maxf(_lift, under)
	return _lift


func _climb_needed(at: Vector3) -> float:
	"""How far the ship would have to rise at `at` to clear the rock there by
	`CLEARANCE` — over its whole footprint, not just its centre. 0 when clear."""
	var box := ($CollisionShape3D.shape as BoxShape3D).size * scale
	var reach := maxf(box.x, box.z) * 0.5
	var ground := flight_floor.height_at(at.x, at.z)
	for offset in [Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
		ground = maxf(ground, flight_floor.height_at(at.x + offset.x, at.z + offset.y))
	return maxf(0.0, ground + box.y * 0.5 + CLEARANCE - at.y)


func _steer(step: Vector3, delta: float) -> void:
	"""Point the hull along the way it actually moved this frame.

	Taken from the travelled step rather than `velocity`, so the wobble and the
	weave/swoop offsets steer the ship too — those are most of what a strafing
	alien's heading is made of, and without them it would slide sideways while
	staring straight ahead.
	"""
	if step.is_zero_approx():
		return
	var heading := step.normalized()
	if _facing.is_zero_approx():
		_facing = heading
	else:
		_facing = _facing.lerp(heading, minf(1.0, delta * TURN_RESPONSE)).normalized()
	# look_at aims the node's -Z at its target and the saucer is modelled facing
	# +Z, so it is given the point *behind* the ship to look at.
	var up := Vector3.UP
	if absf(_facing.dot(up)) > 0.99:
		up = Vector3.BACK
	look_at(global_position - _facing, up)

func _on_area_entered(area: Area3D) -> void:
	if _destroyed:
		return
	if area.is_in_group("lasers"):
		take_hit()


## Take one laser hit. Everything with a single hit point — every alien but the
## ore carrier — goes straight through this to `_explode()`.
func take_hit() -> void:
	if _destroyed:
		return
	_hits_taken += 1
	if _hits_taken >= hit_points:
		_explode()
		return
	_show_armour_damage()


func _show_armour_damage() -> void:
	"""A hit the ship walked away from, made obvious.

	Without this a carrier that takes three hits reads as three misses, and the
	player stops shooting at the one target on the screen that is worth 400. The
	shell fading step by step is the health bar — it says *keep going*, and it
	says how much further, without putting a gauge on a 3D object.

	The sound says the same thing: a metallic ring rather than an explosion, so
	the ear also hears a hit that did not finish the job.
	"""
	Audio.play("armour_hit", -3.0, 0.06)
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.scale = Vector3.ONE * 0.5

	var armour := get_node_or_null("Armour") as MeshInstance3D
	if armour == null:
		return
	var material := armour.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	# The shell material is local to the scene (see OreCarrier.tscn), so this
	# fades this one carrier and not every carrier on the field.
	var remaining := float(hit_points - _hits_taken) / float(maxi(1, hit_points))
	material.albedo_color.a = _armour_alpha * remaining
	material.emission_energy_multiplier = _armour_glow * remaining

func _explode() -> void:
	_destroyed = true
	$Model.visible = false
	# An armoured ship goes up with the heavier sample, matched to the bigger
	# particle burst below. `hit_points` rather than `scale`, because armour is
	# what makes a carrier a carrier — a scout scaled up is still a scout.
	Audio.play("carrier_explode" if hit_points > 1 else "alien_explode", -1.0, 0.07)
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_parent().add_child(effect)
	effect.global_position = global_position
	# A bigger ship goes up bigger. The carrier is the hardest kill on the field
	# and the payoff should look like it.
	effect.scale = Vector3.ONE * maxf(1.0, scale.x)
	# Emitted before freeing, while global_position is still readable.
	destroyed.emit(global_position, score_value)
	queue_free()
