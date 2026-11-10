class_name Player
extends CharacterBody2D
## The player: a square that runs, jumps, bounces on rubber, and steers slightly in the air.
## Select the Player scene and tune the feel in the Inspector, or use the in-game Tune panel.

signal fell
signal bounced
signal teleported
signal wall_bounced

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

@export_group("Rubber")
## Share of the landing speed a rubber tile gives back (0.85 = bounces to about 72% of the drop).
@export var rubber_bounciness := 0.85
## Holding jump as you land on rubber launches you at least this many times a normal jump.
@export var rubber_boost := 1.2
## Holding jump on repeat bounces adds this much on top of the landing speed (pumping).
@export var rubber_pump := 1.05
## Landings slower than this don't bounce, so you can stand and walk on rubber.
@export var bounce_threshold := 150.0
@export var max_bounce_speed := 1100.0

@export_group("Rubber wall")
## Share of your running speed a rubber wall throws back at you.
@export var wall_bounciness := 0.9
## The weakest kick a rubber wall gives, so even a slow bump sends you back.
@export var wall_kick := 320.0
## Hitting a rubber wall on the ground bumps you up this fast, so you leave the ground.
@export var wall_hop := 260.0
## Hitting one in mid-air while holding jump launches you up this many times a normal jump.
@export var wall_jump := 0.95
## For this long after a wall bounce your own steering is ignored, so the kick is felt.
@export var wall_stun := 0.25

@export_group("Look")
@export var color := Color("ff6b5e")
@export var eye_color := Color("1b2440")
## How fast the squash and stretch settles back (higher is snappier).
@export var squash_recovery := 12.0

var active := false
var fall_limit_y := INF
## Seconds of blinking after being hurt, when nothing can hurt you again.
var invincible := 0.0

var _coyote := 0.0
var _jump_buffer := 0.0
var _face := 1.0
var _squash := Vector2.ONE
var _was_on_floor := true
var _bouncing := false
var _stun := 0.0

@onready var camera: Camera2D = $Camera2D
@onready var dust: CPUParticles2D = $Dust


func reset_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_squash = Vector2.ONE
	_was_on_floor = true
	_bouncing = false
	_stun = 0.0
	invincible = 0.0
	camera.reset_smoothing()


## Knocked back by a hazard (direction -1 = left, 1 = right), then a moment of safety.
func knock_back(direction: float) -> void:
	velocity = Vector2(direction * 320.0, -420.0)
	_stun = 0.3
	_bouncing = true
	invincible = 1.2
	_squash = Vector2(0.65, 1.3)
	_puff()


## Move to a teleport pad, keeping the current velocity.
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	_coyote = 0.0          # you arrive in the air: no ledge-grace jump carried over
	_was_on_floor = false
	camera.reset_smoothing()
	_squash = Vector2(0.6, 1.4)
	_puff()
	teleported.emit()


## Current squash/stretch scale, for tests.
func get_squash() -> Vector2:
	return _squash


func _physics_process(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-squash_recovery * delta))
	invincible = maxf(invincible - delta, 0.0)
	queue_redraw()
	if not active:
		return

	var on_floor := is_on_floor()

	var dir := Input.get_axis("move_left", "move_right")
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)   # just bounced off a rubber wall: no steering yet
	elif dir != 0.0:
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
		_bouncing = false
		_squash = Vector2(0.7, 1.35)
		_puff()

	var g := gravity
	if velocity.y < 0.0 and not Input.is_action_pressed("jump") and not _bouncing:
		g *= short_hop_gravity
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)
	if velocity.y >= 0.0:
		_bouncing = false

	var before := velocity
	move_and_slide()
	var bounced_now := _apply_rubber(before, on_floor)

	if not bounced_now and is_on_floor() and not _was_on_floor and before.y > 250.0:
		var amount := clampf((before.y - 200.0) / 700.0, 0.0, 1.0)
		_squash = Vector2(1.0 + 0.4 * amount, 1.0 - 0.35 * amount)
		_puff()
	_was_on_floor = is_on_floor() and not bounced_now

	if position.y > fall_limit_y:
		fell.emit()


## Bounce off any rubber tile touched this frame. The surface reflects the velocity
## that points into it, keeping the rest, so you bounce away in the direction you came from.
func _apply_rubber(before: Vector2, was_on_floor: bool) -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var data := _rubber_data(col)
		if data == null:
			continue
		var n := col.get_normal()
		var is_wall := bool(data.get_custom_data("rubber_wall"))
		var into_side := absf(n.x) > 0.7 and before.x * n.x < -30.0
		if is_wall and into_side:
			# Rubber wall: throw the player back the way they came.
			velocity.x = n.x * maxf(absf(before.x) * wall_bounciness, wall_kick)
			if not was_on_floor and Input.is_action_pressed("jump"):
				velocity.y = minf(before.y, -jump_velocity * wall_jump)   # wall jump
			elif was_on_floor:
				velocity.y = -wall_hop                                     # bumped off the ground
			else:
				velocity.y = before.y
			_bouncing = velocity.y < 0.0
			_stun = wall_stun
			_face = signf(n.x)
			_squash = Vector2(0.6, 1.25)
			_puff()
			wall_bounced.emit()
			return true
		if n.y < -0.7 and before.y > bounce_threshold:
			# Landed on top: reflect upward, keep the sideways speed.
			var speed := before.y * rubber_bounciness
			if Input.is_action_pressed("jump"):
				speed = maxf(before.y * rubber_pump, jump_velocity * rubber_boost)
			velocity.y = -minf(speed, max_bounce_speed)
			velocity.x = before.x
			_bouncing = true
			_coyote = 0.0
			_squash = Vector2(1.45, 0.6)
			_puff()
			bounced.emit()
			return true
		elif into_side and absf(before.x) > 60.0:
			# Side of a rubber floor tile: a softer push back.
			velocity.x = n.x * maxf(absf(before.x) * rubber_bounciness, 150.0)
			_squash = Vector2(0.7, 1.2)
		elif n.y > 0.7 and before.y < -bounce_threshold:
			# Hit it from below: knocked back down.
			velocity.y = absf(before.y) * rubber_bounciness
	return false


## The tile data of a rubber tile that was hit, or null for anything else.
func _rubber_data(col: KinematicCollision2D) -> TileData:
	var layer := col.get_collider() as TileMapLayer
	if layer == null:
		return null
	# Tiles are merged into larger physics bodies, so find the tile from the contact point,
	# nudged a little into the surface that was hit.
	var inside := col.get_position() - col.get_normal() * 2.0
	var data := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(inside)))
	if data == null or not bool(data.get_custom_data("rubber")):
		return null
	return data


func _puff() -> void:
	dust.restart()


func _draw() -> void:
	if invincible > 0.0 and fmod(invincible, 0.2) < 0.1:
		return   # blink while invincible
	# Squash and stretch, anchored at the feet.
	var s := Vector2(SIZE * _squash.x, SIZE * _squash.y)
	var rect := Rect2(Vector2(-s.x / 2.0, SIZE / 2.0 - s.y), s)
	draw_rect(rect, color)
	var ex := _face * 4.0
	var ey := rect.position.y + s.y * 0.3
	# Dark eyes on light colors, light eyes on dark colors, so they always show.
	var eyes := eye_color if color.get_luminance() > 0.3 else Color("eef1fa")
	draw_rect(Rect2(ex - 5.0, ey, 3.0, 5.0), eyes)
	draw_rect(Rect2(ex + 2.0, ey, 3.0, 5.0), eyes)
