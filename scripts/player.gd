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

@export_group("Dash and pound")
## These need their ability cards.
## Dash: a quick straight burst the way you face (Shift, X or K). One per jump in the air.
@export var dash_speed := 620.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.45
## Ground pound: in the air, slam straight down (Down, S or J).
@export var pound_speed := 1000.0
## Glide: hold jump while falling to drift down at this speed.
@export var glide_fall_speed := 150.0
## Holding jump as a ground pound lands bounces you up this many times a normal jump.
@export var pound_rebound := 0.75
## Shockwave: a ground pound landing shoves spike squares this far away (px) 2 tiles back.
@export var shockwave_reach := 160.0
@export var shockwave_cooldown := 2.5
## Stunning Landing: landing on or within 1 tile of a spike square freezes it this long.
@export var stun_time := 3.0

@export_group("Look")
@export var color := Color("ff6b5e")
@export var eye_color := Color("1b2440")
## How fast the squash and stretch settles back (higher is snappier).
@export var squash_recovery := 12.0

var active := false
## Abilities from collected cards: "dash", "pound", "double_jump".
var abilities: Array[String] = []
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
var _shock_cd := 0.0
## Momentum card: seconds spent running one way without stopping or turning.
var _momentum := 0.0
var _dash := 0.0          # time left in the current dash
var _dash_cd := 0.0
var _air_dash_used := false
var _pounding := false
var _air_jump := true      # double jump still available this time in the air

@onready var camera: Camera2D = $Camera2D
@onready var dust: CPUParticles2D = $Dust

var _jump_sfx := _make_sfx("res://audio/jump.wav", -8.0)
var _land_sfx := _make_sfx("res://audio/land.wav", -6.0)
var _hurt_sfx := _make_sfx("res://audio/hurt.wav", -4.0)


func _ready() -> void:
	for p in [_jump_sfx, _land_sfx, _hurt_sfx]:
		add_child(p)


func _make_sfx(path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	p.bus = AudioSettings.SOUNDS_BUS
	return p


## Play a sound with a slight random pitch so repeats don't sound identical.
func _play(p: AudioStreamPlayer, pitch := 1.0) -> void:
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func reset_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote = 0.0
	_jump_buffer = 0.0
	_squash = Vector2.ONE
	_was_on_floor = true
	_bouncing = false
	_stun = 0.0
	_dash = 0.0
	_dash_cd = 0.0
	_air_dash_used = false
	_pounding = false
	_air_jump = true
	invincible = 0.0
	camera.reset_smoothing()


## Knocked back by a hazard (push.x: -1 left, 1 right; push.y: -1 up, 1 down), then a
## moment of safety.
func knock_back(push: Vector2) -> void:
	velocity = Vector2(push.x * 320.0, 420.0 if push.y > 0.0 else -420.0)
	_stun = 0.3
	_bouncing = true
	invincible = 1.2
	_squash = Vector2(0.65, 1.3)
	_puff()
	_play(_hurt_sfx)


## Move to a teleport pad, keeping the current velocity.
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	_coyote = 0.0          # you arrive in the air: no ledge-grace jump carried over
	_was_on_floor = false
	camera.reset_smoothing()
	_squash = Vector2(0.6, 1.4)
	_puff()
	if "tele_hop" in abilities:
		# Tele-hop card: pop straight up, half as high as a full jump (sqrt(0.5) of the speed).
		velocity = Vector2(0.0, -jump_velocity * 0.707)
		_bouncing = true   # keeps its full height even if jump isn't held
		_play(_jump_sfx, 1.15)
	teleported.emit()


## Running speed, 25% faster with the Quick card. Momentum builds up to 25% more over 2 seconds.
func _run_speed() -> float:
	var s := run_speed * (1.25 if "quick" in abilities else 1.0)
	if "momentum" in abilities:
		s *= 1.0 + 0.25 * clampf(_momentum / 2.0, 0.0, 1.0)
	return s


func is_dashing() -> bool:
	return _dash > 0.0


func is_pounding() -> bool:
	return _pounding


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
		if signf(dir) != _face:
			_momentum = 0.0
		_face = signf(dir)
		_momentum += delta
		var acc := ground_accel if on_floor else air_accel * (2.5 if "air_brake" in abilities else 1.0)
		velocity.x = move_toward(velocity.x, dir * _run_speed(), acc * delta)
	else:
		_momentum = 0.0
		var dec := ground_decel if on_floor else air_decel * (4.0 if "air_brake" in abilities else 1.0)
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
		_play(_jump_sfx)
	elif _jump_buffer > 0.0 and not on_floor and _air_jump and "double_jump" in abilities \
			and not _pounding and _stun == 0.0 and Input.is_action_just_pressed("jump"):
		# Double jump card: one extra jump in the air, 75% as high as a full jump.
		velocity.y = -jump_velocity * 0.866   # sqrt(0.75): 75% of a full jump's height
		_air_jump = false
		_jump_buffer = 0.0
		_bouncing = false
		_squash = Vector2(0.7, 1.35)
		_puff()
		_play(_jump_sfx, 1.25)
	if on_floor:
		_air_jump = true

	_update_dash_and_pound(delta, on_floor)

	var g := gravity
	if _dash > 0.0:
		g = 0.0                                  # dashes fly straight
	elif _pounding:
		velocity.y = pound_speed
		g = 0.0
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump") and not _bouncing:
		g *= short_hop_gravity
	velocity.y = minf(velocity.y + g * delta, pound_speed if _pounding else max_fall_speed)
	if "glide" in abilities and velocity.y > glide_fall_speed and Input.is_action_pressed("jump") \
			and not _pounding and _dash == 0.0 and not on_floor:
		velocity.y = glide_fall_speed   # Glide card: float down while jump is held
		_squash = _squash.lerp(Vector2(1.25, 0.85), 0.3)
	if velocity.y >= 0.0:
		_bouncing = false

	var before := velocity
	move_and_slide()
	var bounced_now := _apply_rubber(before, on_floor)
	_hit_obstacles()
	if _pounding and (bounced_now or is_on_floor()):
		_pounding = false
		if not bounced_now:
			_squash = Vector2(1.6, 0.5)
			if "shockwave" in abilities and _shock_cd == 0.0:
				_shockwave()
			if Input.is_action_pressed("jump"):
				velocity.y = -jump_velocity * pound_rebound   # pound rebound: hold jump to spring back up
				_puff()
				_play(_jump_sfx, 0.9)

	if not bounced_now and is_on_floor() and not _was_on_floor and before.y > 250.0:
		var amount := clampf((before.y - 200.0) / 700.0, 0.0, 1.0)
		_squash = Vector2(1.0 + 0.4 * amount, 1.0 - 0.35 * amount)
		_puff()
		_land_sfx.volume_db = lerpf(-14.0, -4.0, amount)   # harder landings are louder
		_play(_land_sfx)
	if "stun_landing" in abilities and is_on_floor() and not _was_on_floor:
		_stun_landing()
	_was_on_floor = is_on_floor() and not bounced_now

	if position.y > fall_limit_y:
		fell.emit()


func _update_dash_and_pound(delta: float, on_floor: bool) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_shock_cd = maxf(_shock_cd - delta, 0.0)
	if on_floor:
		_air_dash_used = false
	if _dash > 0.0:
		_dash = maxf(_dash - delta, 0.0)
		velocity = Vector2(_face * dash_speed, 0.0)
		if _dash == 0.0:
			velocity.x = _face * run_speed      # come out of it at running speed
		return
	if _stun > 0.0:
		return
	if Input.is_action_just_pressed("dash") and "dash" in abilities and _dash_cd == 0.0 and not _pounding \
			and (on_floor or not _air_dash_used):
		var dir := Input.get_axis("move_left", "move_right")
		if dir != 0.0:
			_face = signf(dir)
		_dash = dash_time
		_dash_cd = dash_cooldown
		_air_dash_used = not on_floor
		velocity = Vector2(_face * dash_speed, 0.0)
		_squash = Vector2(1.4, 0.7)
		_puff()
		_play(_jump_sfx, 1.4)
	elif Input.is_action_just_pressed("pound") and "pound" in abilities and not on_floor and not _pounding:
		_pounding = true
		velocity = Vector2(0.0, pound_speed)
		_squash = Vector2(0.7, 1.4)
		_play(_jump_sfx, 0.7)


## Shockwave card: shove spike squares near the floor around you 2 tiles away from you.
func _shockwave() -> void:
	_shock_cd = shockwave_cooldown
	var feet := global_position.y + SIZE / 2.0
	CardFx.spawn(get_parent(), Vector2(global_position.x, feet), "shock", shockwave_reach)
	_play(_land_sfx, 0.6)
	for s in get_tree().get_nodes_in_group("spike_squares"):
		var sq := s as SpikeSquare
		if not sq.visible:
			continue
		var d := sq.global_position - global_position
		var bottom := sq.global_position.y + SpikeSquare.T / 2.0
		if absf(d.x) <= shockwave_reach and bottom > feet - 2.0 * SpikeSquare.T and bottom < feet + 6.0:
			sq.shove(signf(d.x) if d.x != 0.0 else _face)


## Stunning Landing card: landing on a spike square, or within 1 tile of one, stuns it.
func _stun_landing() -> void:
	var feet := global_position.y + SIZE / 2.0
	var reach := SIZE / 2.0 + SpikeSquare.T * 1.5 + 4.0   # half of each, a 1-tile gap, a little slack
	var hit := false
	for s in get_tree().get_nodes_in_group("spike_squares"):
		var sq := s as SpikeSquare
		if not sq.visible:
			continue
		var d := sq.global_position - global_position
		var top := sq.global_position.y - SpikeSquare.T / 2.0
		var bottom := top + SpikeSquare.T
		if absf(d.x) <= reach and top < feet + SpikeSquare.T and bottom > feet - 2.0 * SpikeSquare.T:
			sq.stun(stun_time)
			hit = true
	if hit:
		CardFx.spawn(get_parent(), Vector2(global_position.x, feet), "zap")
		_play(_jump_sfx, 2.2)


## Dashing into an obstacle, or pounding onto one, deals it 1 damage (if it can take that kind).
func _hit_obstacles() -> void:
	if _dash <= 0.0 and not _pounding:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other == null or not other.has_method("take_hit"):
			continue
		if _dash > 0.0 and absf(col.get_normal().x) > 0.7:
			other.take_hit("dash")
		elif _pounding and col.get_normal().y < -0.7:
			if other.take_hit("pound"):
				velocity.y = -jump_velocity * 0.6   # a little hop off the smashed obstacle


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
