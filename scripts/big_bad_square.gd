class_name BigBadSquare
extends CharacterBody2D
## Big Bad Square (m in a text map): the Basic area's boss, a Bad Block twice the size.
## He hops toward you. Jump on his head 3 times to beat him (he flashes for a moment after each
## hit). Touching his sides costs a heart; dashing into him just bounces you off. Down to his
## last heart, he glows for 1.5 seconds, then dashes at you. If he hits a wall he's dazed.

signal hurt_player(push: Vector2)
signal defeated(pos: Vector2)

const SIZE := 52.0
const MAX_HP := 3
const GRAVITY := 2200.0
const HOP_SPEED := 620.0
const HOP_SIDE := 170.0
const TELL := 1.5
const DASH_SPEED := 540.0
const DAZE := 1.2
const FLASH := 1.0
const BODY := Color("b8323a")
const TOP := Color("e5484d")
const SHADE := Color("7a1f26")
const EYES := Color("eef1fa")
const PUPIL := Color("1b2440")
const GLOW := Color("ffd23f")

var hp := MAX_HP
var _origin := Vector2.ZERO
var _player: Player
var _dir := -1.0
var _hit_area: Area2D
var _wait := 1.0       # time until the next hop
var _mode := "hop"     # hop, tell, dash, dazed
var _mode_t := 0.0
var _hopped := false   # last-heart phase: hopped once since the last dash
var _flash := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _t := 0.0
var _stun := 0.0
var _slow := 0.0
var _was_on_floor := true
var _hit_sfx := _sfx("boss_hit", 0.0)
var _charge_sfx := _sfx("boss_charge", -6.0)
var _crash_sfx := _sfx("boss_crash", -2.0)
var _land_sfx := _sfx("land", -2.0)


static func _sfx(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://audio/%s.wav" % name)
	p.volume_db = db
	p.bus = AudioSettings.SOUNDS_BUS
	return p


func _ready() -> void:
	add_to_group("card_targets")
	_origin = position
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	col.shape = shape
	add_child(col)
	_hit_area = Area2D.new()
	var ac := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(SIZE + 6.0, SIZE + 6.0)
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)
	for p in [_hit_sfx, _charge_sfx, _crash_sfx, _land_sfx]:
		add_child(p)


func reset() -> void:
	position = _origin
	velocity = Vector2.ZERO
	hp = MAX_HP
	_charge_sfx.stop()
	_stun = 0.0
	_slow = 0.0
	_mode = "hop"
	_mode_t = 0.0
	_wait = 1.0
	_flash = 0.0
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## Card effects: stuns, slows and pushes work on him, but only jumps on his head hurt him.
func stun(seconds: float) -> void:
	if _mode in ["tell", "dash"]:
		_charge_sfx.stop()   # a stun cancels his charge; he winds up again afterwards
		_set_mode("hop")
		_wait = 0.4
	_stun = maxf(_stun, seconds)


func is_stunned() -> bool:
	return _stun > 0.0 or _mode == "dazed"


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 2) -> void:
	position.x += CardFx.clear_shift(self, global_position, half_size(), dir, tiles)


## Angry Block Dash ran into him: knocked back a tile and stunned, but not hurt.
func smash() -> void:
	if _stun > 0.0:
		return
	var away := signf(global_position.x - _player.global_position.x) if _player else -_dir
	shove(away if away != 0.0 else -_dir, 1)
	stun(0.8)
	_crash_sfx.play()
	if _player:
		_player.shake(5.0, 0.2)


## Big Bad Square only takes jumps on his head.
func take_hit(_kind: String) -> bool:
	return false


func half_size() -> Vector2:
	return Vector2(SIZE, SIZE) / 2.0


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	_hit_by_brick()
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)
		velocity.x = 0.0
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
		_move()
		return
	var pace := 0.5 if _slow > 0.0 else 1.0   # Slow Burst: half speed
	delta *= pace
	_mode_t += delta
	var to_player := 0.0
	if _player:
		to_player = signf(_player.global_position.x - global_position.x)
	match _mode:
		"hop":
			if is_on_floor():
				velocity.x = 0.0
				if to_player != 0.0:
					_dir = to_player
				if hp == 1 and _hopped:
					_set_mode("tell")   # last heart: one hop, then glow and dash
					_charge_sfx.play()
				else:
					_wait -= delta
					if _wait <= 0.0:
						velocity = Vector2(_dir * HOP_SIDE * pace, -HOP_SPEED)
						_wait = randf_range(0.7, 1.3)
						_hopped = hp == 1
		"tell":
			velocity.x = 0.0
			if to_player != 0.0:
				_dir = to_player
			if _mode_t >= TELL:
				_set_mode("dash")
		"dash":
			velocity.x = _dir * DASH_SPEED * pace
			if (is_on_wall() and _mode_t > 0.1) or _mode_t > 2.5:
				velocity.x = 0.0
				_set_mode("dazed")
				_crash_sfx.play()
				if _player:
					_player.shake(9.0, 0.45)
				CardFx.spawn(get_parent(), global_position + Vector2(_dir * SIZE / 2.0, 0.0), "pop")
		"dazed":
			velocity.x = 0.0
			_next_bolts -= delta
			if _next_bolts <= 0.0:
				_next_bolts = 0.07
				_bolts = CardFx.stun_bolts(half_size())
			if _mode_t >= DAZE:
				_set_mode("hop")
				_wait = 0.6
	_move()


func _move() -> void:
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land_sfx.pitch_scale = randf_range(0.55, 0.65)   # a heavy landing
		_land_sfx.play()
		if _player:
			_player.shake(3.0, 0.18)
	_was_on_floor = is_on_floor()
	_check_player()
	queue_redraw()


## Brick Drop: a brick falling onto him stuns him for a moment (and breaks).
func _hit_by_brick() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if b is Brick and b.velocity.y > 0.0 and b.global_position.y < global_position.y - SIZE * 0.3:
			CardFx.spawn(get_parent(), b.global_position, "pop")
			b.queue_free()
			stun(1.5)
			_land_sfx.pitch_scale = 1.3
			_land_sfx.play()


func _set_mode(m: String) -> void:
	_mode = m
	_hopped = false
	_mode_t = 0.0


func _check_player() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		var side := signf(p.global_position.x - global_position.x)
		if side == 0.0:
			side = -_dir
		if p.velocity.y >= 0.0 and feet < global_position.y - SIZE * 0.2:
			p.velocity.y = -p.jump_velocity * 0.85   # bounce high off his head
			if _flash == 0.0:
				_take_stomp()
			return
		if p.is_dashing():
			p.dash_bounce(side)   # dashes just bounce off him
			return
		if _flash > 0.0:
			return
		hurt_player.emit(Vector2(side, -1.0))


func _take_stomp() -> void:
	hp -= 1
	_flash = FLASH
	CardFx.spawn(get_parent(), global_position - Vector2(0.0, SIZE / 2.0), "pop")
	_hit_sfx.pitch_scale = 1.0 + (MAX_HP - hp) * 0.08
	_hit_sfx.play()
	if _player:
		_player.shake(6.0, 0.25)
	if hp <= 0:
		_charge_sfx.stop()
		defeated.emit(global_position)
		CardFx.spawn(get_parent(), global_position, "boom")
		var boom := _sfx("boss_defeat", 0.0)   # on the level, so it keeps playing once he's gone
		get_parent().add_child(boom)
		boom.finished.connect(boom.queue_free)
		boom.play()
		if _player:
			_player.shake(12.0, 0.7)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	if hp == 1:
		_set_mode("hop")
		_wait = 0.4


func _draw() -> void:
	var h := SIZE / 2.0
	var squash := 1.0
	if _mode == "tell":
		squash = 0.92 + 0.04 * sin(_t * 30.0)
	var body_rect := Rect2(-h, -h + SIZE * (1.0 - squash), SIZE, SIZE * squash)
	if _mode == "tell":
		var a := 0.6 + 0.3 * sin(_t * 18.0)
		draw_rect(body_rect.grow(8.0), Color(GLOW, a))
	var blink := _flash > 0.0 and int(_flash * 12.0) % 2 == 0
	var body := BODY.lerp(Color.WHITE, 0.6) if blink else BODY
	draw_rect(body_rect, body)
	draw_rect(Rect2(body_rect.position, Vector2(SIZE, 8)), TOP if not blink else body)
	draw_rect(Rect2(-h, h - 7, SIZE, 7), SHADE)
	var top := body_rect.position.y
	var ex := _dir * 5.0
	var ey := top + 16.0
	if _mode == "dazed" or _stun > 0.0:
		draw_rect(Rect2(ex - 15.0, ey + 4.0, 10.0, 3.0), EYES)
		draw_rect(Rect2(ex + 5.0, ey + 4.0, 10.0, 3.0), EYES)
	else:
		draw_rect(Rect2(ex - 17.0, ey, 13.0, 10.0), EYES)
		draw_rect(Rect2(ex + 4.0, ey, 13.0, 10.0), EYES)
		# Heavy brows slanting down to the middle.
		draw_colored_polygon(PackedVector2Array([Vector2(ex - 19.0, ey - 7.0), Vector2(ex - 2.0, ey + 1.0),
			Vector2(ex - 2.0, ey + 5.0), Vector2(ex - 19.0, ey - 1.0)]), PUPIL)
		draw_colored_polygon(PackedVector2Array([Vector2(ex + 19.0, ey - 7.0), Vector2(ex + 2.0, ey + 1.0),
			Vector2(ex + 2.0, ey + 5.0), Vector2(ex + 19.0, ey - 1.0)]), PUPIL)
		draw_rect(Rect2(ex - 9.0 + _dir * 2.0, ey + 4.0, 4.0, 5.0), PUPIL)
		draw_rect(Rect2(ex + 8.0 + _dir * 2.0, ey + 4.0, 4.0, 5.0), PUPIL)
	# Big gritted-teeth frown.
	var my := ey + 18.0
	draw_rect(Rect2(ex - 12.0, my, 24.0, 9.0), PUPIL)
	for i in 5:
		draw_rect(Rect2(ex - 11.0 + i * 5.0, my, 3.0, 3.0), EYES)
		draw_rect(Rect2(ex - 9.0 + i * 5.0, my + 6.0, 3.0, 3.0), EYES)
	draw_rect(Rect2(ex - 15.0, my + 7.0, 3.0, 5.0), PUPIL)
	draw_rect(Rect2(ex + 12.0, my + 7.0, 3.0, 5.0), PUPIL)
	if _mode == "dazed":
		CardFx.draw_stun(self, _bolts, DAZE - _mode_t)
	elif _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	# His hearts, above his head.
	var hs := HeartArt.size(3.0)
	var gap := 4.0
	var total := hs.x * MAX_HP + gap * (MAX_HP - 1)
	for i in MAX_HP:
		HeartArt.draw(self, Vector2(-total / 2.0 + i * (hs.x + gap), top - hs.y - 8.0), 3.0, i < hp)
