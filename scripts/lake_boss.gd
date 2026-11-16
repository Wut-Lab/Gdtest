class_name LakeBoss
extends CharacterBody2D
## Crazy Harry (x, Cavern Lake boss): a giant Piranha Block with a saddle,
## ridden by a Harpoonist. He lives in the arena's lake.
##
## Stage 1 (5 to 3 hearts): he swims at you like a Piranha Block, bites on touch and leaps out of
## the water when you're just above him. His rider aims (the gun glints) and fires arcing harpoons
## that cost a heart and a half.
## Stage 2 (2 hearts left): he also dives deep under you (bubbles rise where he'll come up: the
## tell), then bursts out in a high jump to land on you.
##
## Jump on him (his head or the rider) to take a heart. After each hit he sinks for a moment and
## can't be hurt. Cards: stuns, slows and shoves work; nothing but a stomp hurts him.

signal hurt_player(push: Vector2)
signal harpooned(push: Vector2)
signal defeated(pos: Vector2)

const W := 76.0
const H := 46.0
const MAX_HP := 5
const SWIM := 125.0
const GRAVITY := 1500.0
const RELOAD := 3.0
const RELOAD_2 := 2.3
const AIM := 0.7
const DIVE_EVERY := 4.0
const DIVE_TELL := 1.0
const HURT_TIME := 0.9
const BODY := Color("4a5776")
const BELLY := Color("c9a227")
const FIN := Color("2f3a55")
const EDGE := Color("1b2440")
const TOOTH := Color("f4f1e6")

## The lake: left and right edges (pixels) and the water's surface.
var x0 := 0.0
var x1 := 0.0
var surface_y := 0.0
var hp := MAX_HP

var _home_y := 0.0
var _origin := Vector2.ZERO
var _player: Node2D
var _dir := -1.0
var _hit_area: Area2D
var _mode := "swim"   # swim, leap, dive, jump, hurt, dead
var _vx := 0.0
var _vy := 0.0
var _timer := 0.0
var _leap_cd := 1.5
var _dive_cd := DIVE_EVERY
var _target_x := 0.0
var _reload := 2.0
var _aim := 0.0
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _t := 0.0
var _flash := 0.0
var _bubbles: Array = []

var _hit_sfx := BigBadSquare._sfx("lake_boss_hit", 0.0)
var _chomp_sfx := BigBadSquare._sfx("chomp", -2.0)
var _splash_sfx := BigBadSquare._sfx("splash", -9.0)   # about half as loud as before
var _bubble_sfx := BigBadSquare._sfx("bubbles", -3.0)
var _fire_sfx := BigBadSquare._sfx("harpoon_fire", -3.0)


func _ready() -> void:
	add_to_group("card_targets")
	z_index = 6
	_origin = position
	_home_y = surface_y + 6.0
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
	ash.size = Vector2(W + 4.0, H + 30.0)   # the rider on top counts too
	ac.shape = ash
	ac.position = Vector2(0.0, -12.0)
	_hit_area.add_child(ac)
	add_child(_hit_area)
	for p in [_hit_sfx, _chomp_sfx, _splash_sfx, _bubble_sfx, _fire_sfx]:
		add_child(p)


func reset() -> void:
	position = _origin
	hp = MAX_HP
	_mode = "swim"
	_stun = 0.0
	_slow = 0.0
	_reload = 2.0
	_aim = 0.0
	_leap_cd = 1.5
	_dive_cd = DIVE_EVERY
	_bubbles.clear()
	for h in get_tree().get_nodes_in_group("harpoons"):
		h.queue_free()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


func half_size() -> Vector2:
	return Vector2(W, H) / 2.0


func take_hit(_kind: String) -> bool:
	return false


func stun(seconds: float) -> void:
	if _mode in ["swim", "leap"]:
		_stun = maxf(_stun, seconds)
		_aim = 0.0


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 1) -> void:
	if _mode == "swim":
		position.x = clampf(position.x + dir * tiles * 32.0, x0 + W / 2.0, x1 - W / 2.0)


func smash() -> void:
	stun(0.8)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _mode == "dead":
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	_leap_cd = maxf(_leap_cd - delta, 0.0)
	var pace := 0.5 if _slow > 0.0 else 1.0
	match _mode:
		"swim":
			_swim(delta, pace)
		"leap", "jump":
			_vy += GRAVITY * delta
			position += Vector2(_vx * pace, _vy) * delta
			position.x = clampf(position.x, x0 + W / 2.0, x1 - W / 2.0)
			if _vy > 0.0 and position.y >= _home_y:
				position.y = _home_y
				_splash()
				_mode = "swim"
				_leap_cd = 1.6
		"dive":
			# Deep under where you are, with bubbles rising above him: the tell.
			_timer -= delta
			position.x = move_toward(position.x, _target_x, 260.0 * delta)
			position.y = move_toward(position.y, surface_y + 90.0, 220.0 * delta)
			if randf() < delta * 14.0:
				_bubbles.append({"x": _target_x - position.x + randf_range(-24, 24), "y": 0.0, "r": randf_range(3, 7)})
			if _timer <= 0.0:
				_jump_at_player()
		"hurt":
			_timer -= delta
			position.y = move_toward(position.y, surface_y + 60.0 if _timer > 0.35 else _home_y, 260.0 * delta)
			if _timer <= 0.0:
				position.y = _home_y
				_mode = "swim"
	for b in _bubbles:
		b.y -= 90.0 * delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return position.y + b.y > surface_y - 6.0)
	_rider(delta, pace)
	_check_player()
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


func _swim(delta: float, pace: float) -> void:
	position.y = _home_y + 3.0 * sin(_t * 2.5)
	if _player == null or _stun > 0.0:
		return
	var d := _player.global_position - global_position
	if absf(d.x) > 4.0:
		_dir = signf(d.x)
	position.x = clampf(move_toward(position.x, _player.global_position.x, SWIM * pace * delta),
		x0 + W / 2.0, x1 - W / 2.0)
	# Stage 2: every few seconds, dive and come up under you.
	if hp <= 2:
		_dive_cd -= delta * pace
		if _dive_cd <= 0.0:
			_dive_cd = DIVE_EVERY
			_mode = "dive"
			_timer = DIVE_TELL
			_aim = 0.0
			_target_x = clampf(_player.global_position.x, x0 + W / 2.0, x1 - W / 2.0)
			_bubbles.clear()
			_bubble_sfx.play()
			_splash()
			return
	# Like a Piranha Block: leap at you when you're just above the water near him.
	var above: bool = _player.global_position.y < surface_y - 4.0
	if above and absf(d.x) < 3.5 * 32.0 and -d.y < 6 * 32.0 and _leap_cd == 0.0:
		_mode = "leap"
		var rise := clampf(_home_y - _player.global_position.y + 10.0, 60.0, 170.0)
		_vy = -sqrt(2.0 * GRAVITY * rise)
		_vx = clampf(d.x * 1.2, -170.0, 170.0)
		_splash()


## Stage 2's big jump: straight up out of the deep, high enough to come down on you.
func _jump_at_player() -> void:
	_mode = "jump"
	_bubbles.clear()
	position.y = surface_y + 30.0
	var top: float = _player.global_position.y - 70.0 if _player else surface_y - 200.0
	var rise := clampf(position.y - top, 160.0, 330.0)
	_vy = -sqrt(2.0 * GRAVITY * rise)
	var air := 2.0 * absf(_vy) / GRAVITY
	var aim_x: float = clampf(_player.global_position.x if _player else _target_x, x0 + W / 2.0, x1 - W / 2.0)
	_vx = (aim_x - position.x) / air
	_splash()


## The rider: turns to you, aims (the gun glints), fires a harpoon in an arc.
func _rider(delta: float, pace: float) -> void:
	if _player == null or _stun > 0.0 or _mode in ["dive", "hurt", "dead"]:
		_aim = 0.0
		return
	if _aim > 0.0:
		_aim -= delta * pace
		if _aim <= 0.0:
			_fire()
		return
	_reload -= delta * pace
	if _reload <= 0.0:
		_aim = AIM


func _gun_pos() -> Vector2:
	return global_position + Vector2(_dir * 24.0, -H / 2.0 - 18.0)


func _fire() -> void:
	_reload = RELOAD_2 if hp <= 2 else RELOAD
	var from := _gun_pos()
	var to: Vector2 = _player.global_position + Vector2(0.0, 6.0)
	var t := clampf(absf(to.x - from.x) / 300.0, 0.6, 1.3)
	var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * Harpoonist.GRAVITY * t * t) / t)
	var h := Harpoonist.Harpoon.new()
	h.position = get_parent().to_local(from)
	h.velocity = v
	h.hit.connect(func(push: Vector2) -> void: harpooned.emit(push))
	get_parent().add_child(h)
	_fire_sfx.pitch_scale = randf_range(0.85, 0.95)
	_fire_sfx.play()


func _splash() -> void:
	CardFx.spawn(get_parent(), Vector2(position.x, surface_y), "pop")
	_splash_sfx.pitch_scale = randf_range(0.7, 0.85)
	_splash_sfx.play()


func _check_player() -> void:
	if _mode in ["dive", "hurt"]:
		return
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		if (p.velocity.y > 0.0 or p.is_pounding()) and feet < global_position.y - H / 2.0 + 6.0:
			_take_stomp(p)
			return
		if _stun > 0.0 or p.is_safe():
			return
		var dx: float = p.global_position.x - global_position.x
		_chomp_sfx.pitch_scale = randf_range(0.7, 0.8)
		_chomp_sfx.play()
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else _dir, -1.0))


func _take_stomp(p: Player) -> void:
	p.velocity.y = -p.jump_velocity * 0.85
	p.stomped()   # Hot Feet card
	hp -= 1
	_flash = 0.3
	_hit_sfx.pitch_scale = 1.0 + (MAX_HP - hp) * 0.06
	_hit_sfx.play()
	if p.has_method("shake"):
		p.shake(6.0, 0.3)
	if hp <= 0:
		_mode = "dead"
		for h in get_tree().get_nodes_in_group("harpoons"):
			h.queue_free()
		defeated.emit(global_position)
		CardFx.spawn(get_parent(), global_position, "boom")
		var boom := BigBadSquare._sfx("lake_boss_defeat", 0.0)
		get_parent().add_child(boom)
		boom.finished.connect(boom.queue_free)
		boom.play()
		p.shake(12.0, 0.7)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_mode = "hurt"
	_timer = HURT_TIME
	_aim = 0.0
	_stun = 0.0
	if hp == 2:
		_dive_cd = 1.5   # stage 2 starts soon after
		p.shake(10.0, 0.5)


func _draw() -> void:
	var w := W / 2.0
	var h := H / 2.0
	var body := BODY.lerp(Color.WHITE, 0.6) if _flash > 0.0 else BODY
	# Bubbles rising where he'll burst out (stage 2's tell).
	for b in _bubbles:
		draw_arc(Vector2(b.x, b.y), b.r, 0.0, TAU, 10, Color(0.85, 0.95, 1.0, 0.9), 1.5)
	var tail := -_dir * (w + 2.0)
	var wag := 4.0 * sin(_t * 9.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tail, -2), Vector2(tail - _dir * 20, -18 + wag),
		Vector2(tail - _dir * 20, 16 + wag)]), FIN)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * _dir, h - 4), Vector2(4 * _dir, h - 4),
		Vector2(-12 * _dir, h + 10)]), FIN)   # belly fin
	draw_rect(Rect2(-w - 2, -h - 2, W + 4, H + 4), EDGE)
	draw_rect(Rect2(-w, -h, W, H), body)
	draw_rect(Rect2(-w, h - 13, W, 13), BELLY)   # the huge underbite jaw
	draw_rect(Rect2(-w, -h, W, 5), body.lightened(0.15))
	# A scar across the face.
	var sx := _dir * 16.0
	draw_line(Vector2(sx - 6, -h + 6), Vector2(sx + 8, -h + 18), Color("2a3148"), 2.0)
	# Mean eye under a heavy brow.
	var ex := _dir * 24.0
	if _stun > 0.0:
		draw_rect(Rect2(ex - 6, -6, 12, 3), Color.WHITE)
	else:
		draw_rect(Rect2(ex - 6, -10, 12, 9), Color("ffde59"))
		draw_rect(Rect2(ex - 2 + _dir * 2, -9, 4, 7), EDGE)
		draw_colored_polygon(PackedVector2Array([Vector2(ex - 9 * _dir, -16), Vector2(ex + 8 * _dir, -11),
			Vector2(ex + 8 * _dir, -8), Vector2(ex - 9 * _dir, -12)]), EDGE)
	# Teeth sticking up from the jaw.
	for i in 6:
		var tx := _dir * (6.0 + i * 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, h - 13), Vector2(tx + 3, h - 13),
			Vector2(tx, h - 21)]), TOOTH)
	# Saddle with straps, and the Harpoonist rider sitting on it.
	draw_rect(Rect2(-18, -h - 6, 36, 8), Color("6b4428"))
	draw_rect(Rect2(-18, -h - 8, 8, 4), Color("8a5a32"))
	draw_rect(Rect2(10, -h - 8, 8, 4), Color("8a5a32"))
	draw_rect(Rect2(-16, -h + 2, 4, H - 16), Color("5a3a22"))
	draw_rect(Rect2(12, -h + 2, 4, H - 16), Color("5a3a22"))
	var r := Vector2(-4 * _dir, -h - 19)
	draw_rect(Rect2(r + Vector2(-12, -12), Vector2(24, 24)), Color("8a5a32"))
	draw_rect(Rect2(r + Vector2(-12, -12), Vector2(24, 4)), Color("b07a48"))
	draw_rect(Rect2(r + Vector2(-12, -5), Vector2(24, 3)), Color("2b2b2b"))
	for gx in [-9.0, 1.0]:
		var lx: float = r.x + gx + _dir * 2.0
		draw_rect(Rect2(lx - 1, r.y - 8, 10, 8), Color("2b2b2b"))
		draw_rect(Rect2(lx, r.y - 7, 8, 6), Color("8fd3ff"))
	var gun := _gun_pos() - global_position
	draw_rect(Rect2(minf(r.x, gun.x), gun.y - 2, absf(gun.x - r.x) + 4, 5), Color("6d7685"))
	if _aim > 0.0 and fmod(_aim, 0.2) < 0.1:
		draw_rect(Rect2(gun.x - 3, gun.y - 6, 6, 2), Color("ffde59"))
		draw_rect(Rect2(gun.x - 1, gun.y - 8, 2, 6), Color("ffde59"))
	# Hearts above his head.
	var hs := HeartArt.size(3.0)
	var gap := 4.0
	var total := MAX_HP * hs.x + (MAX_HP - 1) * gap
	for i in MAX_HP:
		HeartArt.draw(self, Vector2(-total / 2.0 + i * (hs.x + gap), -h - 60.0), 3.0, i < hp)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
