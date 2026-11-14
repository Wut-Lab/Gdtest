class_name Piranha
extends CharacterBody2D
## Piranha Block (a, Cavern Lake): lives in a lake or river and never leaves it. Running water
## doesn't move it. It swims fast toward you while you're near, bites if you touch it, and leaps
## out of the water at you when you pass over it. Jump on it (or dash or pound into it) to squash it.
##
## friendly = true makes Pork, the friendly pink piranha in the town pond: he just potters
## about, hops now and then, and says his name when you're close.

signal hurt_player(push: Vector2)
signal broken(pos: Vector2)
## Pork: the player came close or left.
signal near_changed(near: bool)

const W := 26.0
const H := 20.0
const SWIM := 150.0
const SIGHT := 8 * 32.0
const LEAP_GRAVITY := 1500.0
const BODY := Color("5d6b8a")
const BELLY := Color("c9a227")
const FIN := Color("3c4660")
const EDGE := Color("1b2440")
const TOOTH := Color("f4f1e6")

@export var friendly := false
## Where it can swim: left and right edges (pixels) and its home depth (y).
var x0 := 0.0
var x1 := 0.0
var home_y := 0.0
## The water's surface above its home, for leaping.
var surface_y := 0.0

var _origin := Vector2.ZERO
var _player: Node2D
var _dir := 1.0
var _hit_area: Area2D
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _leap := false
var _vy := 0.0
var _vx := 0.0
var _leap_cd := 1.0
var _t := 0.0
var _wander := 0.0
var _near := false
var _chomp_sfx := BigBadSquare._sfx("chomp", -6.0)
var _splash_sfx := BigBadSquare._sfx("splash", -10.0)


func _ready() -> void:
	z_index = 6   # in front of the water, so you can see it coming
	if not friendly:
		add_to_group("card_targets")
	_origin = position
	_wander = position.x
	collision_layer = 4
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(W, H)
	col.shape = shape
	add_child(col)
	_hit_area = Area2D.new()
	var ac := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(W + 2.0, H + 2.0)
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)
	add_child(_chomp_sfx)
	add_child(_splash_sfx)
	_t = randf() * 10.0


func reset() -> void:
	position = _origin
	_stun = 0.0
	_slow = 0.0
	_leap = false
	_leap_cd = 1.0
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


func take_hit(_kind: String) -> bool:
	_die()
	return true


func half_size() -> Vector2:
	return Vector2(W, H) / 2.0


func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 2) -> void:
	position.x = clampf(position.x + dir * tiles * 32.0, x0 + W / 2.0, x1 - W / 2.0)


## Undertow card: dragged along its water.
func drift(dx: float) -> void:
	position.x = clampf(position.x + dx, x0 + W / 2.0, x1 - W / 2.0)


func smash() -> void:
	_die()


func _die() -> void:
	if not visible or friendly:
		return
	CardFx.spawn(get_parent(), global_position, "pop")
	broken.emit(global_position)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_t += delta
	_stun = maxf(_stun - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	_leap_cd = maxf(_leap_cd - delta, 0.0)
	var pace := 0.5 if _slow > 0.0 else 1.0
	if _leap:
		_vy += LEAP_GRAVITY * delta
		position += Vector2(_vx * pace, _vy) * delta
		position.x = clampf(position.x, x0 + W / 2.0, x1 - W / 2.0)
		if _vy > 0.0 and position.y >= home_y:
			position.y = home_y
			_leap = false
			_leap_cd = 1.0 if friendly else 1.4
			CardFx.spawn(get_parent(), Vector2(position.x, surface_y), "pop")
	elif friendly:
		_potter(delta)
	elif _stun == 0.0:
		_hunt(delta, pace)
	if not _leap:
		position.y = home_y + 2.0 * sin(_t * 3.0)
	if not friendly:
		_check_player()
	elif _player:
		var near: bool = _player.global_position.distance_to(global_position) < 4 * 32.0
		if near != _near:
			_near = near
			near_changed.emit(near)
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


## Swim at you while you're near; leap out of the water when you're just above it.
func _hunt(delta: float, pace: float) -> void:
	if _player == null:
		return
	var d := _player.global_position - global_position
	if absf(d.x) > SIGHT or absf(d.y) > 6 * 32.0:
		return
	if absf(d.x) > 3.0:
		_dir = signf(d.x)
	position.x = clampf(move_toward(position.x, _player.global_position.x, SWIM * pace * delta),
		x0 + W / 2.0, x1 - W / 2.0)
	var above: bool = _player.global_position.y < surface_y - 4.0
	if above and absf(d.x) < 3 * 32.0 and -d.y < 5 * 32.0 and _leap_cd == 0.0:
		_leap = true
		var rise := clampf(home_y - _player.global_position.y + 16.0, 40.0, 150.0)
		_vy = -sqrt(2.0 * LEAP_GRAVITY * rise)
		_vx = clampf(d.x * 1.5, -160.0, 160.0)
		_splash_sfx.pitch_scale = randf_range(1.1, 1.3)
		_splash_sfx.play()


## Pork: drifts to a new spot now and then, with a happy little hop out of the water.
## Pork, talked to: a stream of colourful bubbles floats up and pops.
var _bubbles: Array = []
var _bubble_sfx: AudioStreamPlayer


func blow_bubbles() -> void:
	var cols := [Color("ff7aa5"), Color("ffd23f"), Color("6fd3ff"), Color("8ef07a"), Color("c49bff")]
	for i in 9:
		_bubbles.append({"p": Vector2(_dir * 10.0 + randf_range(-4, 4), -4.0), "v": Vector2(randf_range(-30, 30),
			randf_range(-90, -55)), "r": randf_range(3.0, 7.0), "t": -i * 0.12, "life": randf_range(1.2, 1.9),
			"c": cols[i % cols.size()]})
	if _bubble_sfx == null:
		_bubble_sfx = AudioStreamPlayer.new()
		_bubble_sfx.stream = load("res://audio/bubbles.wav")
		_bubble_sfx.volume_db = -4.0
		_bubble_sfx.bus = AudioSettings.SOUNDS_BUS
		add_child(_bubble_sfx)
	_bubble_sfx.pitch_scale = randf_range(0.9, 1.15)
	_bubble_sfx.play()
	_leap_cd = 0.6


func _potter(delta: float) -> void:
	for b in _bubbles:
		b.t += delta
		if b.t > 0.0:
			b.p += b.v * delta
			b.p.x += sin(b.t * 6.0 + b.r) * 20.0 * delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	if not _bubbles.is_empty():
		return   # he holds still while he blows them
	if absf(position.x - _wander) < 4.0:
		if randf() < delta * 0.6:
			_wander = randf_range(x0 + W, x1 - W)
		elif randf() < delta * 0.15 and _leap_cd == 0.0:
			_leap = true
			_vy = -sqrt(2.0 * LEAP_GRAVITY * 50.0)
			_vx = 0.0
	else:
		_dir = signf(_wander - position.x)
		position.x = move_toward(position.x, _wander, 55.0 * delta)


func _check_player() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		if p.is_dashing() or p.is_pounding() or (p.velocity.y > 0.0 and feet < global_position.y - 2.0):
			if p.is_dashing():
				_die()
				p.chain_dash()
				return
			if not p.is_pounding():
				p.velocity.y = -p.jump_velocity * 0.6
				p.stomped()   # Hot Feet card
			_die()
			return
		if _stun > 0.0:
			return
		if not p.is_safe():
			_chomp_sfx.pitch_scale = randf_range(1.0, 1.2)
			_chomp_sfx.play()
		var dx: float = p.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else _dir, -1.0))


func _draw() -> void:
	var body := Color("f29bb8") if friendly else BODY
	var belly := Color("ffd6e3") if friendly else BELLY
	var fin := Color("d9668f") if friendly else FIN
	var w := W / 2.0
	var h := H / 2.0
	var tail := -_dir * (w + 2.0)
	var wag := 2.0 * sin(_t * 12.0)
	# Tail and a fin on top.
	draw_colored_polygon(PackedVector2Array([Vector2(tail, -1), Vector2(tail - _dir * 8, -8 + wag),
		Vector2(tail - _dir * 8, 8 + wag)]), fin)
	draw_rect(Rect2(-4, -h - 5, 8, 6), fin)
	draw_rect(Rect2(-w - 1, -h - 1, W + 2, H + 2), EDGE)
	draw_rect(Rect2(-w, -h, W, H), body)
	draw_rect(Rect2(-w, h - 6, W, 6), belly)   # the underbite jaw
	var ex := _dir * 5.0
	if friendly:
		# Happy eye and a smile with two little teeth.
		draw_rect(Rect2(ex - 2, -6, 5, 5), Color.WHITE)
		draw_rect(Rect2(ex - 1 + _dir, -5, 3, 3), EDGE)
		draw_rect(Rect2(_dir * 6 - 4, 1, 8, 2), EDGE)
		draw_rect(Rect2(_dir * 6 - 3, 3, 2, 2), TOOTH)
		draw_rect(Rect2(_dir * 6 + 1, 3, 2, 2), TOOTH)
		draw_rect(Rect2(-w + 3, -1, 4, 3), Color("ff7aa5"))   # blush
		for bb in _bubbles:
			if bb.t <= 0.0:
				continue
			var a: float = clampf((bb.life - bb.t) / 0.3, 0.0, 1.0)
			var c: Color = bb.c
			draw_arc(bb.p, bb.r, 0.0, TAU, 14, Color(c, a), 1.5)
			draw_circle(bb.p, bb.r - 1.0, Color(c, 0.25 * a))
			draw_rect(Rect2(bb.p + Vector2(-bb.r * 0.5, -bb.r * 0.5), Vector2(2, 2)), Color(1, 1, 1, a))
		if _near:
			var f := ThemeDB.fallback_font
			draw_string(f, Vector2(-20, -h - 10), "Pork", HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)
		return
	if _stun > 0.0:
		draw_rect(Rect2(ex - 3, -5, 6, 2), Color.WHITE)
	else:
		# Mean eye under a heavy brow.
		draw_rect(Rect2(ex - 3, -6, 6, 5), Color("ffde59"))
		draw_rect(Rect2(ex - 1 + _dir, -5, 2, 4), EDGE)
		draw_colored_polygon(PackedVector2Array([Vector2(ex - 5 * _dir, -9), Vector2(ex + 5 * _dir, -6),
			Vector2(ex + 5 * _dir, -4), Vector2(ex - 5 * _dir, -7)]), EDGE)
	# Big underbite: a row of sharp teeth sticking up from the jaw.
	var mx := _dir * 2.0
	for i in 4:
		var tx := mx + i * 4.0 * _dir
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 2, h - 6), Vector2(tx + 2, h - 6),
			Vector2(tx, h - 11)]), TOOTH)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
