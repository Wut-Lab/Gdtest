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
## Shockwave also fires on any landing falling faster than this (about a 5-tile drop; a jump onto
## flat ground lands slower).
@export var shockwave_fall_speed := 860.0
## Stunning Landing: landing on or within 1 tile of a spike square freezes it this long.
@export var stun_time := 3.0
## High Jump: jumps go this many times as high (speed scales by the square root).
@export var high_jump := 1.2
## Phase Jump: you're phased out while your rise or fall speed is under this share of a jump's
## launch speed: the apex plus 5% of the jump's air time on each side.
@export var phase_window := 0.1
## Grip and Go: landing after moving at least this far sideways (px) in the air dashes on
## for this share of that distance (capped).
@export var grip_min_distance := 64.0
@export var grip_share := 0.75
@export var grip_max_distance := 192.0
## Lucky Charm: chance to shrug off a hit from an obstacle.
@export var lucky_chance := 0.2
## Slow Burst: when hurt, obstacles overlapping this square (half-size in px) slow down.
@export var slow_burst_reach := 96.0
@export var slow_burst_time := 3.0
## Wall Cling: seconds you can hang on walls per jump, and how hard you kick off.
@export var cling_time := 1.0
@export var cling_kick := 1.3
## Brick Drop: seconds between bricks.
@export var brick_cooldown := 3.0
## Angry Block Dash (rare): seconds of rage, the speed boost, and the recharge after it ends.
@export var angry_time := 3.0
@export var angry_speed := 1.5
@export var angry_cooldown := 5.0
## Personal Space (rare): reach in px, how many tiles it shoves, the stun, and its recharge.
@export var push_reach := 128.0
@export var push_tiles := 3
@export var push_stun := 1.0
@export var push_cooldown := 3.0
## Bounce House: rubber bounces go this many times as high (speed scales by the square root),
## and landing on normal ground faster than house_fall_speed bounces back at house_hop of it.
@export var house_height := 1.25
@export var house_fall_speed := 650.0
@export var house_hop := 0.3

@export_group("Look")
@export var color := Color("ff6b5e")
@export var eye_color := Color("1b2440")
## How fast the squash and stretch settles back (higher is snappier).
@export var squash_recovery := 12.0

var active := false
## Abilities from collected cards: "dash", "pound", "double_jump".
var abilities: Array[String] = []
var fall_limit_y := INF
## The level's pond (town): the player floats in it.
var water: Water
## Seconds of blinking after being hurt, when nothing can hurt you again.
var invincible := 0.0
## Phase Jump card: phased out (nothing can hurt you) right now.
var phased := false
var _phase_look := 1.0   # how solid you're drawn: dips when phasing, then fades back in

var _coyote := 0.0
var _jump_buffer := 0.0
var _face := 1.0
var _squash := Vector2.ONE
var _was_on_floor := true
var _bouncing := false
var _stun := 0.0
var _shock_cd := 0.0
var _cling_left := 1.0   # Wall Cling: hang time left this jump
var _cling_dir := 0.0    # which way the wall you're clinging to faces (0 = not clinging)
var _brick_cd := 0.0
var _angry := 0.0
var _angry_cd := 0.0
var _push_cd := 0.0
## Angry Block Dash costs a heart: Main sets this; it returns false if you can't pay.
var pay_heart: Callable = func() -> bool: return true
## Safety Bubble: the last plain ground you stood on, and the bubble's float-back time.
var last_ground := Vector2.ZERO
## Guard Block: the shield is up (Main sets it at the start and the checkpoint).
var guard_up := false
var _bubble := 0.0
var _brick: Node = null
var _takeoff_x := 0.0   # Grip and Go: where you left the ground
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
	add_to_group("player")
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


func in_water() -> float:
	return _submerged()


## How much of the player is under water, 0 (none) to 1 (all).
func _submerged() -> float:
	if water == null or water.is_empty():
		return 0.0
	var top := water.surface_at(position.x)
	if top == INF:
		return 0.0
	return clampf((position.y + SIZE / 2.0 - top) / SIZE, 0.0, 1.0)


func reset_to(pos: Vector2) -> void:
	position = pos
	_cling_dir = 0.0
	_cling_left = cling_time
	_brick_cd = 0.0
	_angry = 0.0
	_angry_cd = 0.0
	_push_cd = 0.0
	_bubble = 0.0
	last_ground = pos
	if is_instance_valid(_brick):
		_brick.queue_free()
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
	phased = false
	_phase_look = 1.0
	_shake_left = 0.0
	camera.position = Vector2.ZERO
	camera.reset_smoothing()


var _shake := 0.0
var _shake_left := 0.0
var _shake_time := 0.0


## Shake the screen: up to [param strength] px, easing off over [param seconds].
func shake(strength: float, seconds: float) -> void:
	if strength >= _shake * (_shake_left / maxf(_shake_time, 0.001)):
		_shake = strength
		_shake_left = seconds
		_shake_time = seconds


func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var s := _shake * _shake_left / _shake_time
	camera.position = Vector2(randf_range(-s, s), randf_range(-s, s)) if _shake_left > 0.0 else Vector2.ZERO


## Dashed into something too big to break (Big Bad Square): bounce back off it, unhurt.
## Chain Dash gives the dash straight back.
func dash_bounce(side: float) -> void:
	_dash = 0.0
	velocity = Vector2(side * 320.0, -360.0)
	_bouncing = true
	_squash = Vector2(0.7, 1.3)
	_puff()
	if "chain_dash" in abilities:
		_dash_cd = 0.0
		_air_dash_used = false


## Chain Dash card: a dash that knocks out an enemy or breaks an obstacle gives the dash
## straight back and a small hop, so you can chain through groups of them.
func chain_dash() -> void:
	if not "chain_dash" in abilities:
		return
	_dash = 0.0
	_dash_cd = 0.0
	_air_dash_used = false
	velocity = Vector2(_face * run_speed, -jump_velocity * 0.45)
	_squash = Vector2(0.75, 1.3)
	CardFx.spawn(get_parent(), global_position, "plus", 0.0, "Chain!")
	_play(_jump_sfx, 1.7)


## Knocked back by a hazard (push.x: -1 left, 1 right; push.y: -1 up, 1 down), then a
## moment of safety.
func knock_back(push: Vector2) -> void:
	var soft := 0.5 if "long_blink" in abilities else 1.0   # Long Blink: half the knockback
	velocity = Vector2(push.x * 320.0 * soft, (420.0 if push.y > 0.0 else -420.0) * (0.6 if soft < 1.0 else 1.0))
	_stun = 0.3 * soft
	_bouncing = true
	invincible = 1.2 * (2.0 if "long_blink" in abilities else 1.0)
	_squash = Vector2(0.65, 1.3)
	_puff()
	_play(_hurt_sfx)


## Guard Block card: the shield takes the hit and breaks. Returns true if it did.
func try_guard(push: Vector2) -> bool:
	if "guard_block" not in abilities or not guard_up:
		return false
	guard_up = false
	velocity = Vector2(push.x * 180.0, -220.0)
	_stun = 0.1
	invincible = 0.8
	CardFx.spawn(get_parent(), global_position, "pop")
	_play(_land_sfx, 1.5)
	return true


## Lucky Charm card: maybe shrug off an obstacle's hit. Returns true if it was shrugged off:
## no heart lost, just a little push away and a moment of safety.
func try_shrug_off(push: Vector2) -> bool:
	if "lucky_charm" not in abilities or randf() >= lucky_chance:
		return false
	velocity = Vector2(push.x * 200.0, -260.0 if push.y <= 0.0 else 260.0)
	_stun = 0.15
	invincible = 0.6
	CardFx.spawn(get_parent(), global_position, "lucky")
	_play(_jump_sfx, 1.8)
	return true


## Portion Booster card: the percentages on attack, jump and movement cards go up 5 points.
func _pct(base: float) -> float:
	return base + (0.05 if "portion_booster" in abilities else 0.0)


## Slow Burst card: after getting hurt, every obstacle overlapping a square 3 tiles out from you
## moves at half speed for 3 seconds.
func slow_burst() -> void:
	if "slow_burst" not in abilities:
		return
	var area := Rect2(global_position - Vector2.ONE * slow_burst_reach, Vector2.ONE * slow_burst_reach * 2.0)
	for t in get_tree().get_nodes_in_group("card_targets"):
		var half: Vector2 = t.half_size()
		if t.visible and area.intersects(Rect2(t.global_position - half, half * 2.0)):
			t.slow(slow_burst_time)
	CardFx.spawn(get_parent(), global_position, "slow", slow_burst_reach)


## Grip and Go card: after covering at least 2 tiles sideways in the air, landing dashes on
## for 75% of that distance.
func _grip_and_go() -> void:
	var moved := position.x - _takeoff_x
	if absf(moved) < grip_min_distance or _dash > 0.0:
		return
	_face = signf(moved)
	_dash = minf(absf(moved) * _pct(grip_share), grip_max_distance) / dash_speed
	velocity = Vector2(_face * dash_speed, 0.0)
	_squash = Vector2(1.4, 0.7)
	_puff()
	_play(_jump_sfx, 1.4)


## Move to a teleport pad, keeping the current velocity.
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	_takeoff_x = pos.x
	_coyote = 0.0          # you arrive in the air: no ledge-grace jump carried over
	_was_on_floor = false
	camera.reset_smoothing()
	_squash = Vector2(0.6, 1.4)
	_puff()
	if "tele_hop" in abilities:
		# Tele-hop card: pop straight up, half as high as a full jump (sqrt(0.5) of the speed).
		velocity = Vector2(0.0, -jump_velocity * sqrt(_pct(0.5)))   # half a jump's height
		_bouncing = true   # keeps its full height even if jump isn't held
		_play(_jump_sfx, 1.15)
	teleported.emit()


## Running speed, 15% faster with the Quick card. Momentum builds up to 25% more over 2 seconds.
func _run_speed() -> float:
	var s := run_speed * (1.0 + _pct(0.15) if "quick" in abilities else 1.0)
	if _angry > 0.0:
		s *= angry_speed
	if "momentum" in abilities:
		s *= 1.0 + _pct(0.25) * clampf(_momentum / 2.0, 0.0, 1.0)
	return s


## Launch speed of a jump: High Jump makes it 20% higher.
func _jump_speed() -> float:
	return jump_velocity * (sqrt(1.0 + _pct(high_jump - 1.0)) if "high_jump" in abilities else 1.0)


## Nothing can hurt you: blinking after a hit, or phased out by Phase Jump.
func is_safe() -> bool:
	return invincible > 0.0 or phased or _angry > 0.0


func is_angry() -> bool:
	return _angry > 0.0


## Angry Block Dash can be started now (not raging or recharging).
func angry_ready() -> bool:
	return _angry == 0.0 and _angry_cd == 0.0


func push_ready() -> bool:
	return _push_cd == 0.0


## Safety Bubble card: float back to pos inside a bubble instead of falling.
func bubble_to(pos: Vector2) -> void:
	global_position = pos + Vector2(0.0, -4.0)
	velocity = Vector2.ZERO
	_dash = 0.0
	_pounding = false
	_bubble = 1.0
	invincible = 1.0
	camera.reset_smoothing()
	_play(_jump_sfx, 1.6)


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
	phased = "phase_jump" in abilities and not is_on_floor() and not _pounding \
			and absf(velocity.y) <= (phase_window + (0.1 if "portion_booster" in abilities else 0.0)) * jump_velocity
	_phase_look = move_toward(_phase_look, 0.25 if phased else 1.0, delta * (12.0 if phased else 3.0))
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
	var sub := _submerged()
	if sub > 0.3:
		_coyote = coyote_time   # you can always hop out of the water
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -_jump_speed()
		_jump_buffer = 0.0
		_coyote = 0.0
		_bouncing = false
		_squash = Vector2(0.7, 1.35)
		_puff()
		_play(_jump_sfx)
	elif _jump_buffer > 0.0 and _cling_dir != 0.0 and Input.is_action_just_pressed("jump"):
		# Wall Cling: kick off the wall, away from it, and get your hang time back.
		velocity = Vector2(_cling_dir * run_speed * cling_kick, -jump_velocity * 0.9)
		_face = _cling_dir
		_cling_dir = 0.0
		_cling_left = cling_time
		_stun = 0.15   # a moment before steering, so the kick is felt
		_jump_buffer = 0.0
		_bouncing = false
		_squash = Vector2(0.7, 1.35)
		_puff()
		_play(_jump_sfx)
	elif _jump_buffer > 0.0 and not on_floor and _air_jump and "double_jump" in abilities \
			and not _pounding and _stun == 0.0 and Input.is_action_just_pressed("jump"):
		# Double jump card: one extra jump in the air, 75% as high as a full jump.
		velocity.y = -_jump_speed() * sqrt(_pct(0.75))   # 75% of a full jump's height
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
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump") and not _bouncing and sub == 0.0:
		g *= short_hop_gravity
	velocity.y = minf(velocity.y + g * delta, pound_speed if _pounding else max_fall_speed)
	if "glide" in abilities and velocity.y > glide_fall_speed and Input.is_action_pressed("jump") \
			and not _pounding and _dash == 0.0 and not on_floor:
		velocity.y = glide_fall_speed   # Glide card: float down while jump is held
		_squash = _squash.lerp(Vector2(1.25, 0.85), 0.3)
	if sub > 0.0:
		# Floating: the more of you is under water, the harder it pushes you up (you settle about
		# half in), and the water slows you down.
		velocity.y -= gravity * 2.0 * sub * delta
		velocity.y *= exp(-5.0 * sub * delta)
		velocity.x *= exp(-1.5 * sub * delta)
	if velocity.y >= 0.0:
		_bouncing = false

	var before := velocity
	move_and_slide()
	var bounced_now := _apply_rubber(before, on_floor)
	_hit_obstacles()
	if _angry > 0.0:
		_angry_smash()
	if is_on_floor() and get_slide_collision_count() > 0 and _floor_is_ground():
		last_ground = global_position
	if _bubble > 0.0:
		_bubble = maxf(_bubble - delta, 0.0)
	if _pounding and (bounced_now or is_on_floor()):
		_pounding = false
		if not bounced_now:
			_squash = Vector2(1.6, 0.5)
			if "shockwave" in abilities and _shock_cd == 0.0:
				_shockwave()
			if Input.is_action_pressed("jump"):
				velocity.y = -jump_velocity * _pct(pound_rebound)   # pound rebound: hold jump to spring back up
				_puff()
				_play(_jump_sfx, 0.9)

	if not bounced_now and is_on_floor() and not _was_on_floor and before.y > 250.0:
		var amount := clampf((before.y - 200.0) / 700.0, 0.0, 1.0)
		_squash = Vector2(1.0 + 0.4 * amount, 1.0 - 0.35 * amount)
		_puff()
		_land_sfx.volume_db = lerpf(-14.0, -4.0, amount)   # harder landings are louder
		_play(_land_sfx)
		Haptics.land()
	if "shockwave" in abilities and _shock_cd == 0.0 and not bounced_now and is_on_floor() \
			and not _was_on_floor and before.y > shockwave_fall_speed:
		_shockwave()   # Shockwave: any hard landing, not just a Ground Pound
	if "stun_landing" in abilities and is_on_floor() and not _was_on_floor:
		_stun_landing()
	if "bounce_house" in abilities and is_on_floor() and not _was_on_floor and not bounced_now \
			and before.y > house_fall_speed and not _pounding:
		velocity.y = -before.y * house_hop   # Bounce House: a little spring off a big fall
		_bouncing = true
		_squash = Vector2(1.35, 0.7)
	if "grip_and_go" in abilities and is_on_floor() and not _was_on_floor and not bounced_now:
		_grip_and_go()
	if _was_on_floor and not is_on_floor():
		_takeoff_x = position.x
	_update_cling(delta, bounced_now)
	_was_on_floor = is_on_floor() and not bounced_now

	if position.y > fall_limit_y:
		fell.emit()


## Wall Cling card: pressed against a normal wall in mid-air, hang there (up to 1 second per
## jump); jump to kick off it.
func _update_cling(delta: float, bounced_now: bool) -> void:
	if is_on_floor():
		_cling_left = cling_time
	_cling_dir = 0.0
	if "wall_cling" not in abilities or is_on_floor() or bounced_now or _cling_left <= 0.0 \
			or _pounding or velocity.y < 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) > 0.7 and _rubber_data(col) == null \
				and not col.get_collider().is_in_group("card_targets"):
			_cling_dir = signf(n.x)
			_cling_left = maxf(_cling_left - delta, 0.0)
			velocity.y = 0.0   # hang on
			_squash = _squash.lerp(Vector2(0.85, 1.1), 0.3)
			return


## Brick Drop card: drop a brick straight down from under you (one at a time).
func _drop_brick() -> void:
	_brick_cd = brick_cooldown
	if is_instance_valid(_brick):
		_brick.queue_free()
	_brick = Brick.new()
	get_parent().add_child(_brick)
	_brick.global_position = global_position + Vector2(0.0, SIZE / 2.0 + Brick.T / 2.0 + 2.0)
	_play(_land_sfx, 0.8)


func _update_dash_and_pound(delta: float, on_floor: bool) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_brick_cd = maxf(_brick_cd - delta, 0.0)
	if Input.is_action_just_pressed("brick") and "brick_drop" in abilities and not on_floor \
			and _brick_cd == 0.0:
		_drop_brick()
	_push_cd = maxf(_push_cd - delta, 0.0)
	_angry_cd = maxf(_angry_cd - delta, 0.0)
	if _angry > 0.0:
		_angry = maxf(_angry - delta, 0.0)
		if _angry == 0.0:
			_angry_cd = angry_cooldown   # recharge starts when the rage ends
	elif Input.is_action_just_pressed("angry") and "angry_dash" in abilities and _angry_cd == 0.0 \
			and pay_heart.call():
		_angry = angry_time
		_squash = Vector2(1.3, 0.75)
		_puff()
		_play(_land_sfx, 0.5)
	if Input.is_action_just_pressed("push") and "personal_space" in abilities and _push_cd == 0.0:
		_personal_space()
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


## Standing on the level's tiles (not a brick, spike square or moving platform).
func _floor_is_ground() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.7 and col.get_collider() is TileMapLayer:
			return true
	return false


## Angry Block Dash: smash every Bad Block, spike square and spiked platform you touch.
## You can still stand on a spiked platform's top without breaking it.
func _angry_smash() -> void:
	var me := Rect2(global_position - Vector2.ONE * (SIZE / 2.0 + 6.0), Vector2.ONE * (SIZE + 12.0))
	var feet := global_position.y + SIZE / 2.0
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not t.visible or not t.has_method("smash"):
			continue
		var half: Vector2 = t.half_size()
		if not me.intersects(Rect2(t.global_position - half, half * 2.0)):
			continue
		if t is SpikePlatform and feet <= t.global_position.y - half.y + 3.0:
			continue
		t.smash()
		Haptics.land()


## Personal Space card: shove everything within reach 3 tiles away from you and stun it.
func _personal_space() -> void:
	_push_cd = push_cooldown
	CardFx.spawn(get_parent(), global_position, "slow", push_reach)
	_play(_land_sfx, 0.8)
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not t.visible:
			continue
		var half: Vector2 = t.half_size()
		var d: Vector2 = t.global_position - global_position
		if absf(d.x) - half.x <= push_reach and absf(d.y) - half.y <= push_reach:
			t.shove(signf(d.x) if absf(d.x) > 1.0 else _face, push_tiles)
			t.stun(push_stun)


## Shockwave card: shove spike squares, spiked platforms and Bad Blocks near the floor 2 tiles away from you.
func _shockwave() -> void:
	_shock_cd = shockwave_cooldown
	var feet := global_position.y + SIZE / 2.0
	CardFx.spawn(get_parent(), Vector2(global_position.x, feet), "shock", shockwave_reach)
	_play(_land_sfx, 0.6)
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not t.visible:
			continue
		var half: Vector2 = t.half_size()
		var d: Vector2 = t.global_position - global_position
		var bottom: float = t.global_position.y + half.y
		if absf(d.x) - half.x <= shockwave_reach and bottom > feet - 2.0 * 32.0 and bottom < feet + 6.0:
			t.shove(signf(d.x) if d.x != 0.0 else _face)


## Stunning Landing card: landing on a spike square, spiked platform or Bad Block, or within 1 tile of
## one, stuns it.
func _stun_landing() -> void:
	var feet := global_position.y + SIZE / 2.0
	var hit := false
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not t.visible:
			continue
		var half: Vector2 = t.half_size()
		var d: Vector2 = t.global_position - global_position
		var top: float = t.global_position.y - half.y
		var bottom: float = t.global_position.y + half.y
		# Within a 1-tile gap sideways (plus a little slack), and near your feet's height.
		if absf(d.x) <= half.x + SIZE / 2.0 + 36.0 and top < feet + 32.0 and bottom > feet - 64.0:
			t.stun(stun_time)
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
			if other.take_hit("dash"):
				chain_dash()
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
			var lift := sqrt(house_height) if "bounce_house" in abilities else 1.0
			velocity.y = -minf(speed * lift, max_bounce_speed * lift)   # Bounce House: 25% higher
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
	if _phase_look < 0.99:
		# Phase Jump: see-through, with a shimmering outline drifting off you.
		var k := 1.0 - _phase_look
		var wob := sin(Time.get_ticks_msec() * 0.03) * 3.0 * k
		draw_rect(rect.grow(2.0 + wob), Color(0.62, 0.95, 1.0, 0.6 * k), false, 2.0)
		draw_rect(rect.grow(5.0 - wob), Color(0.62, 0.95, 1.0, 0.25 * k), false, 2.0)
	if _angry > 0.0:
		# Angry Block Dash: a pulsing red glow.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		draw_rect(rect.grow(4.0 + 2.0 * pulse), Color(1.0, 0.2, 0.15, 0.35))
		draw_rect(rect.grow(2.0), Color(1.0, 0.25, 0.2, 0.6), false, 2.0)
	if guard_up and "guard_block" in abilities:
		# Guard Block: a thin blue shield outline while it's up.
		draw_rect(rect.grow(3.0), Color(0.55, 0.8, 1.0, 0.7), false, 2.0)
	if _bubble > 0.0:
		# Safety Bubble: a shimmering bubble that pops as it fades.
		var r := SIZE * (0.95 + 0.15 * (1.0 - _bubble))
		draw_circle(Vector2.ZERO, r, Color(0.6, 0.9, 1.0, 0.18 * _bubble))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.75, 0.95, 1.0, 0.8 * _bubble), 2.0)
		draw_rect(Rect2(-r * 0.5, -r * 0.6, 4, 4), Color(1, 1, 1, 0.7 * _bubble))
	draw_rect(rect, Color(color, _phase_look) if _angry == 0.0 else Color(color, _phase_look).lerp(Color("e5484d"), 0.45))
	var ex := _face * 4.0
	var ey := rect.position.y + s.y * 0.3
	# Dark eyes on light colors, light eyes on dark colors, so they always show.
	var eyes := eye_color if color.get_luminance() > 0.3 else Color("eef1fa")
	eyes.a = _phase_look
	draw_rect(Rect2(ex - 5.0, ey, 3.0, 5.0), eyes)
	draw_rect(Rect2(ex + 2.0, ey, 3.0, 5.0), eyes)
	if _angry > 0.0:
		# Angry brows slanting down toward the middle.
		for side in [-1.0, 1.0]:
			var bx: float = ex + side * 4.0
			draw_line(Vector2(bx + side * 3.0, ey - 4.0), Vector2(bx - side * 2.0, ey - 1.0), eyes, 2.0)
