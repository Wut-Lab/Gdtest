class_name Player
extends CharacterBody2D
## The player: a square that runs, jumps, and steers slightly in the air.
## Select the Player scene and tune the feel in the Inspector.

signal fell

const SIZE := 24.0

@export_group("Running")
@export var run_speed := 250.0
@export var ground_accel := 2600.0
@export var ground_decel := 3000.0
## Low air acceleration means you can only steer a little mid-jump.
@export var air_accel := 900.0
@export var air_decel := 250.0

@export_group("Jumping")
## About 4 tiles high when jump is held.
@export var jump_velocity := 760.0
@export var gravity := 2200.0
@export var max_fall_speed := 900.0
## Extra gravity while rising after jump is released, for short hops.
@export var short_hop_gravity := 2.6
## You can still jump this long after running off a ledge.
@export var coyote_time := 0.1
## A jump pressed this long before landing still counts.
@export var jump_buffer_time := 0.12

@export_group("Look")
@export var color := Color("ff6b5e")
@export var eye_color := Color("1b2440")

var active := false
var fall_limit_y := INF

var _coyote := 0.0
var _jump_buffer := 0.0
var _face := 1.0
var _squash := Vector2.ONE
var _was_on_floor := true

@onready var camera: Camera2D = $Camera2D


func reset_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_squash = Vector2.ONE
	_was_on_floor = true
	camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_squash = _squash.move_toward(Vector2.ONE, 4.0 * delta)
	queue_redraw()
	if not active:
		return

	var on_floor := is_on_floor()

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_face = signf(dir)
		var acc := ground_accel if on_floor else air_accel
		velocity.x = move_toward(velocity.x, dir * run_speed, acc * delta)
	else:
		var dec := ground_decel if on_floor else air_decel
		velocity.x = move_toward(velocity.x, 0.0, dec * delta)

	if on_floor:
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.75, 1.3)

	var g := gravity
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		g *= short_hop_gravity
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not _was_on_floor and fall_speed > 300.0:
		_squash = Vector2(1.25, 0.75)
	_was_on_floor = is_on_floor()

	if position.y > fall_limit_y:
		fell.emit()


func _draw() -> void:
	# Squash and stretch, anchored at the feet.
	var s := Vector2(SIZE * _squash.x, SIZE * _squash.y)
	var rect := Rect2(Vector2(-s.x / 2.0, SIZE / 2.0 - s.y), s)
	draw_rect(rect, color)
	var ex := _face * 4.0
	var ey := rect.position.y + s.y * 0.3
	draw_rect(Rect2(ex - 5.0, ey, 3.0, 5.0), eye_color)
	draw_rect(Rect2(ex + 2.0, ey, 3.0, 5.0), eye_color)
