extends Node
## Dev-only screenshot rig: boots the real Game.tscn, optionally parks one ship of
## each hull in front of the camera, and writes a PNG.
##
##   godot --path . res://tools/Shoot.tscn -- <scene 1-4> <out.png> [lineup|strafe] [top]
##
## Windowed on purpose — headless has no renderer to read back from. Not part of
## the game; it lives in tools/ so both export presets leave it out.

const ALIEN_SCENE := preload("res://scenes/AlienShip.tscn")
const AlienShipScript := preload("res://scripts/AlienShip.gd")


func _ready() -> void:
	# The game starts fullscreen; a screenshot wants a fixed, repeatable size.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var scene_index := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "res://shot.png"
	var lineup := args.size() > 2 and (args[2] == "lineup" or args[2] == "strafe")
	var strafe := args.size() > 2 and args[2] == "strafe"

	GameState.scene_index = scene_index
	var game: Node3D = load("res://scenes/Game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	if lineup:
		# No wave: the field is ours.
		game.set("_to_spawn", 0)
		var hulls := AlienShipScript.HULLS
		for i in hulls.size():
			var alien: Area3D = ALIEN_SCENE.instantiate()
			alien.speed = 0.0
			game.add_child(alien)
			var model := alien.get_node("Model")
			for child in model.get_children():
				child.queue_free()
			model.add_child(hulls[i].instantiate())
			alien.global_position = Vector3((i - 1) * 4.4 - 2.2, 2.6, 3.0)
			if strafe:
				# Flown, not parked: heading comes from the step it travels, so this
				# is the only way to see which end of a hull leads.
				alien.flight_mode = AlienShipScript.FlightMode.STRAFE
				alien.velocity = Vector3(3.0, 0.0, 0.0)
				alien.global_position = Vector3((i - 1) * 3.6 - 1.5, 2.6 + i * 0.0, 3.0 - i * 0.5)
	if lineup and not strafe:
		# And the ore carrier, at the size the spawner gives it.
		var carrier: Area3D = load("res://scenes/OreCarrier.tscn").instantiate()
		carrier.speed = 0.0
		game.add_child(carrier)
		carrier.scale = Vector3.ONE * CampaignData.ORE_CARRIER["size"]
		carrier.global_position = Vector3(4.4, 2.6, 1.0)
	if args.size() > 3 and args[3] == "top":
		# Straight down, so a hull's long axis is plain to see against its heading.
		var camera: Camera3D = game.get_node("Camera3D")
		camera.global_position = Vector3(0.0, 16.0, 7.5)
		camera.global_rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	if args.size() > 2 and args[2] == "fast":
		# The real battle at 30x, two frames apart, to see anything that drifts.
		Engine.time_scale = 30.0
		for i in 70:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out.replace(".png", "_a.png")))
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out.replace(".png", "_b.png")))
		Engine.time_scale = 1.0
		get_tree().quit()
		return
	if args.size() > 2 and args[2] == "play":
		# The real wave, untouched: a numbered frame every half second.
		for n in 6:
			for i in 30:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out.replace(".png", "_%d.png" % n)))
		get_tree().quit()
		return
	if args.size() > 3 and args[3] == "module":
		# The ISS module part-way across, rather than waiting for it to drift in.
		var module := game.get_node_or_null("SceneLook/Set/ISSSet/Module")
		if module != null:
			module.position.x = -18.0
			module.velocity = Vector3.ZERO
	if args.size() > 3 and args[3] == "side":
		# Level with the ships and close, so a hull flown across the view is seen
		# in profile, large enough to tell nose from tail.
		var side_cam: Camera3D = game.get_node("Camera3D")
		side_cam.global_position = Vector3(0.0, 2.8, 40.0)
		side_cam.look_at(Vector3(0.0, 2.6, 2.5), Vector3.UP)
		side_cam.fov = 12.0
	if args.size() > 3 and args[3] == "close":
		# Beside and just above the turret, to judge how it meets the deck.
		var cam: Camera3D = game.get_node("Camera3D")
		cam.global_position = Vector3(2.6, 2.0, 10.4)
		cam.look_at(Vector3(0.0, 0.7, 7.5), Vector3.UP)
	for i in 20:
		await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("aliens"):
		print("alien +Z in world: ", node.global_basis.z.snapped(Vector3.ONE * 0.01), " pos ", node.global_position.snapped(Vector3.ONE * 0.1), " vel ", node.velocity)
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(out))
	print("saved ", out, " ", image.get_size())
	get_tree().quit()
