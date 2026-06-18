extends Node3D

const LASER_SCENE := preload("res://scenes/Laser.tscn")

@export var move_speed: float = 14.0
@export var keyboard_speed: float = 10.0
@export var bounds_x: float = 6.0
@export var fire_cooldown: float = 0.2
@export var laser_speed: float = 40.0

var target_x: float = 0.0
var _fire_cooldown_remaining: float = 0.0

func _ready() -> void:
	target_x = position.x

func _process(delta: float) -> void:
	_handle_keyboard(delta)
	position.x = move_toward(position.x, target_x, move_speed * delta)
	_fire_cooldown_remaining = maxf(_fire_cooldown_remaining - delta, 0.0)

func _handle_keyboard(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("ui_left"):
		dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir += 1.0
	if dir != 0.0:
		target_x = clamp(target_x + dir * keyboard_speed * delta, -bounds_x, bounds_x)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_set_target_from_screen(event.position)
			_try_fire()
	elif event is InputEventScreenDrag:
		_set_target_from_screen(event.position)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_target_from_screen(event.position)
			_try_fire()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_set_target_from_screen(event.position)
	elif event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE:
			_try_fire()

func _set_target_from_screen(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var depth := camera.global_position.distance_to(global_position)
	var world_pos := camera.project_position(screen_pos, depth)
	target_x = clamp(world_pos.x, -bounds_x, bounds_x)

func _try_fire() -> void:
	if _fire_cooldown_remaining > 0.0:
		return
	_fire_cooldown_remaining = fire_cooldown
	var laser: Area3D = LASER_SCENE.instantiate()
	get_parent().add_child(laser)
	laser.global_position = $Muzzle.global_position
	laser.speed = laser_speed
