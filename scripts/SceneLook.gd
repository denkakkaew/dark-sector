extends Node3D
## Dresses the battlefield as whichever of the four destinations is being played.
##
## Everything it needs comes from `CampaignData.look()`, so the four scenes are a
## data change: sky colour, the three lights, whether the Earth photograph is up,
## the star field, and the planet bodies. Nothing here knows what "Mars" is.
##
## The bodies and the star field are built at runtime rather than authored,
## because they are the same two primitives four times over — a flat-shaded
## sphere and a quad of dots. Building them from the table keeps a fifth
## destination a table entry instead of a fifth set of scene nodes.
##
## GL-Compatibility rules everything here: no sky shader, no reflection probe, no
## GPU particles. A planet is a sphere with a noise texture on it, lit by the
## same directional light as the turret.

## Resolution of the generated star field. Deliberately coarse: at the distance
## the quad sits, one texel lands on about two screen pixels, which is the size
## a star should be. It is filtered nearest so they stay points and don't smear.
const STAR_TEXTURE_SIZE: int = 512
## Stars at full density. Enough to read as a sky, few enough that the eye still
## picks a moving saucer out of them.
const STAR_COUNT: int = 900
const MOTTLE_TEXTURE_SIZE: int = 256

## Width of the painted backdrop quad, in metres. Hand-tuned in `Game.tscn` to
## cover the frustum at the depth it hangs at, so it is the dimension we keep
## fixed and the height that follows the image — a backdrop narrower than this
## would show the sky down its sides.
const PHOTO_WIDTH: float = 164.97

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var fill: DirectionalLight3D
## The painted backdrop authored in `Game.tscn`. Which image hangs on it, its
## tint and its visibility are ours; its placement was hand-tuned and is left
## alone.
@export var photo: MeshInstance3D

@onready var _bodies: Node3D = $Bodies
@onready var _stars: MeshInstance3D = $Stars


## Dress the field for a 1-based scene index. Called by the spawner as the
## gameplay scene comes up, before the first alien is anywhere near.
func apply(scene_index: int) -> void:
	var look := CampaignData.look(scene_index)
	_apply_environment(look)
	_apply_lights(look)
	_apply_photo(look)
	_apply_stars(look)
	_apply_bodies(look)


func _apply_environment(look: Dictionary) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	# Duplicated because the Environment is a sub-resource of Game.tscn: written
	# to in place, scene 3's rust sky would still be there the next time the
	# scene is opened from the editor.
	var environment: Environment = world_environment.environment.duplicate()
	environment.background_color = look["space"]
	environment.ambient_light_color = look["ambient"]
	world_environment.environment = environment


func _apply_lights(look: Dictionary) -> void:
	if sun != null:
		sun.light_color = look["sun"]["color"]
		sun.light_energy = look["sun"]["energy"]
	if fill != null:
		fill.light_color = look["fill"]["color"]
		fill.light_energy = look["fill"]["energy"]


func _apply_photo(look: Dictionary) -> void:
	if photo == null:
		return
	var settings: Dictionary = look["photo"]
	photo.visible = settings["visible"]
	if not settings["visible"]:
		return
	var texture := load(settings["texture"]) as Texture2D
	if texture == null:
		# A missing backdrop is scenery, not a rule: the sky behind it is still a
		# sky, so say so in the log and let the scene play.
		push_warning("SceneLook: no backdrop image at %s" % settings["texture"])
		photo.visible = false
		return

	var material := photo.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	# Same reason as the Environment: the material and the mesh are authored in
	# the scene and shared, so dress copies of them.
	material = material.duplicate()
	material.albedo_color = settings["tint"]
	material.albedo_texture = texture
	photo.set_surface_override_material(0, material)

	var quad := photo.mesh.duplicate() as QuadMesh
	if quad == null:
		return
	# Fixed width, height from the image's own aspect. Cropping the top and bottom
	# off a backdrop is invisible; stretching one destination's sky to another's
	# proportions is not.
	quad.size = Vector2(PHOTO_WIDTH, PHOTO_WIDTH * texture.get_height() / texture.get_width())
	photo.mesh = quad


func _apply_stars(look: Dictionary) -> void:
	var density: float = look["stars"]
	_stars.visible = density > 0.0
	if not _stars.visible:
		return
	var material := _stars.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return
	material = material.duplicate()
	material.albedo_texture = _star_texture(density)
	_stars.set_surface_override_material(0, material)


func _apply_bodies(look: Dictionary) -> void:
	for existing in _bodies.get_children():
		existing.queue_free()
	for body in look["bodies"]:
		_bodies.add_child(_make_body(body))


func _make_body(body: Dictionary) -> MeshInstance3D:
	"""One planet: a flat-shaded sphere, big and low for ground, small and high
	for a distant world."""
	var radius: float = body["radius"]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24

	var material := StandardMaterial3D.new()
	material.albedo_color = body["color"]
	material.roughness = 1.0
	material.metallic = 0.0
	var mottle: float = body["mottle"]
	if mottle > 0.0:
		material.albedo_texture = _mottle_texture(mottle)
		# Enough repeats that craters read at their own scale rather than as one
		# continent-sized smear, few enough that they don't turn to noise.
		material.uv1_scale = Vector3(8.0, 4.0, 1.0)
	var emission: float = body["emission"]
	if emission > 0.0:
		# Keeps a distant world from vanishing on whichever side faces away from
		# the sun — the storyboard's blue marble has to stay a blue marble.
		material.emission_enabled = true
		material.emission = body["color"]
		material.emission_energy_multiplier = emission

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	# A body this size in the shadow map would spend the whole depth range on
	# itself and leave the turret with no shadow at all.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = body["position"]
	# Turn the sphere's pole away down-range. A sphere's UVs pinch to a point
	# there, and a ground body is looked at from *above*: leave the pole up and
	# the craters smear into a starburst in the middle of the horizon.
	instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	return instance


func _mottle_texture(strength: float) -> NoiseTexture2D:
	"""Craters and dust: noise multiplied into the body's own colour.

	`strength` is how deep the darker patches go — the Moon is pitted, Mars is
	dusty and softer."""
	var noise := FastNoiseLite.new()
	noise.frequency = 0.018
	noise.fractal_octaves = 4

	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE * (1.0 - 0.45 * strength))
	ramp.set_color(1, Color.WHITE)

	var texture := NoiseTexture2D.new()
	texture.width = MOTTLE_TEXTURE_SIZE
	texture.height = MOTTLE_TEXTURE_SIZE
	# The sphere's UVs wrap all the way round, so a non-seamless noise would draw
	# a hard vertical line down the planet.
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture


func _star_texture(density: float) -> ImageTexture:
	var image := Image.create(STAR_TEXTURE_SIZE, STAR_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i in int(STAR_COUNT * density):
		var x := randi() % STAR_TEXTURE_SIZE
		var y := randi() % STAR_TEXTURE_SIZE
		# Most stars are faint. Without the spread they read as a regular dot
		# screen rather than as depth.
		var brightness := pow(randf(), 2.2)
		var warmth := randf_range(-0.12, 0.12)
		var color := Color(
			clampf(0.85 + warmth, 0.0, 1.0),
			0.9,
			clampf(0.95 - warmth, 0.0, 1.0),
			clampf(0.25 + brightness, 0.0, 1.0)
		)
		image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
