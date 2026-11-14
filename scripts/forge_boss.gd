class_name ForgeBoss
extends CharacterBody2D
## Anvil Annie (z, Ember Forge boss): a huge living anvil, sooty iron with a glowing face.
##
## Stage 1 (6 to 4 hearts): she hops after you, spits arcs of sparks, and every few seconds
## crouches (the tell) and leaps high to slam down where you are. The slam sends a wave of fire
## rolling along the floor both ways: jump over it.
## Stage 2 (3 hearts left): the iron floor plates start heating up in cycles, she slams and spits
## more often, and her own top heats red hot now and then (it glows first). Stomping her while
## she's red hot burns you.
##
## Jump on her top (or Ground Pound it) to take a heart. Touching her sides costs a heart.

signal hurt_player(push: Vector2)
signal defeated(pos: Vector2)

const W := 68.0
const H := 56.0
const MAX_HP := 6
const GRAVITY := 2000.0
const EDGE := Color("1b2440")
const IRON := Color("3b3f4a")
const IRON_DARK := Color("2c2f38")
const IRON_LIGHT := Color("8a92a3")
const COOL := 2.5
const WARN := 0.7
const HOT := 1.5

var hp := MAX_HP
## The arena, for heating its floor plates.
var room: Node
var min_x := 0.0
var max_x := 2000.0

var _origin := Vector2.ZERO
var _player: Node2D
var _dir := -1.0
var _hit_area: Area2D
var _mode := "idle"   # idle, hop, crouch, slam, hurt, dead
var _timer := 0.0
var _hop_cd := 1.2
var _slam_cd := 4.0
var _spark_cd := 2.5
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _t := 0.0
var _heat_t := 0.0
var _flash := 0.0
var _squash := 0.0

var _clang_sfx := BigBadSquare._sfx("anvil_clang", -2.0)
var _hit_sfx := BigBadSquare._sfx("forge_boss_hit", 0.0)
var _spark_sfx := BigBadSquare._sfx("sparks", -4.0)
var _sizzle_sfx := BigBadSquare._sfx("sizzle", -4.0)
var _hop_sfx := BigBadSquare._sfx("land", -2.0)


func _ready() -> void:
	add_to_group("card_targets")
	_origin = position
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(W, H)
	col.shape = shape
	add_child(col)
	_hit_area = Area2D.new()
	var ac := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(W + 4.0, H + 4.0)
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)
	for p in [_clang_sfx, _hit_sfx, _spark_sfx, _sizzle_sfx, _hop_sfx]:
		add_child(p)


func reset() -> void:
	position = _origin
	velocity = Vector2.ZERO
	hp = MAX_HP
	_mode = "idle"
	_hop_cd = 1.2
	_slam_cd = 4.0
	_spark_cd = 2.5
	_stun = 0.0
	_slow = 0.0
	_heat_t = 0.0
	if room and room.has_method("set_plates_active"):
		room.set_plates_active(false)
	for n in get_tree().get_nodes_in_group("forge_shots"):
		n.queue_free()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


func half_size() -> Vector2:
	return Vector2(W, H) / 2.0


func take_hit(_kind: String) -> bool:
	return false


func stun(seconds: float) -> void:
	if _mode in ["idle", "hop", "crouch"]:
		_stun = maxf(_stun, seconds)
		if _mode == "crouch":
			_mode = "idle"


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 1) -> void:
	if is_on_floor():
		position.x = clampf(position.x + dir * mini(tiles, 1) * 32.0, min_x + W / 2.0, max_x - W / 2.0)


func smash() -> void:
	stun(0.8)


## Her top: 0 cool, 0..1 glowing (warning), 2 red hot. Only in stage 2.
func heat() -> float:
	if hp > 3 or _mode == "dead":
		return 0.0
	var k := fposmod(_heat_t, COOL + WARN + HOT)
	if k < COOL:
		return 0.0
	if k < COOL + WARN:
		return (k - COOL) / WARN
	return 2.0


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _mode == "dead":
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_squash = maxf(_squash - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	if hp <= 3:
		var before := heat()
		_heat_t += delta
		if before < 2.0 and heat() >= 2.0:
			_sizzle_sfx.play()
	var pace := 0.5 if _slow > 0.0 else 1.0
	var was_air := not is_on_floor()
	velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)
	if is_on_floor() and _mode in ["idle", "hurt", "crouch"]:
		velocity.x = 0.0
	match _mode:
		"idle":
			if _player and _stun == 0.0:
				_dir = signf(_player.global_position.x - global_position.x) if absf(_player.global_position.x - global_position.x) > 4.0 else _dir
				_hop_cd -= delta * pace
				_slam_cd -= delta * pace
				_spark_cd -= delta * pace
				if _slam_cd <= 0.0:
					_mode = "crouch"
					_timer = 0.6
				elif _spark_cd <= 0.0:
					_spit_sparks()
				elif _hop_cd <= 0.0 and is_on_floor():
					_hop_cd = 1.3 if hp > 3 else 1.0
					_mode = "hop"
					velocity = Vector2(_dir * 150.0 * pace, -520.0)
		"crouch":
			_timer -= delta
			if _timer <= 0.0 and _player:
				_mode = "slam"
				_slam_cd = 5.0 if hp > 3 else 3.4
				velocity.y = -900.0
				var air := 2.0 * 900.0 / GRAVITY
				velocity.x = clampf((_player.global_position.x - global_position.x) / air, -420.0, 420.0)
		"hurt":
			_timer -= delta
			if _timer <= 0.0:
				_mode = "idle"
	move_and_slide()
	position.x = clampf(position.x, min_x + W / 2.0, max_x - W / 2.0)
	if was_air and is_on_floor():
		_squash = 0.2
		if _mode == "slam":
			_land_slam()
		elif _mode == "hop":
			_hop_sfx.pitch_scale = 0.6
			_hop_sfx.play()
		if _mode in ["hop", "slam"]:
			_mode = "idle"
	_check_player()
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


## The slam lands: a clang, a shake, and fire rolling along the floor both ways.
func _land_slam() -> void:
	_clang_sfx.pitch_scale = randf_range(0.9, 1.0)
	_clang_sfx.play()
	if _player and _player.has_method("shake"):
		_player.shake(9.0, 0.4)
	var floor_y := global_position.y + H / 2.0
	for side in [-1.0, 1.0]:
		var w := FireWave.new()
		w.dir = side
		w.min_x = min_x
		w.max_x = max_x
		w.position = get_parent().to_local(Vector2(global_position.x + side * (W / 2.0), floor_y))
		w.hit.connect(func(push: Vector2) -> void: hurt_player.emit(push))
		get_parent().add_child(w)


## Three sparks in arcs: one at you, one short, one long.
func _spit_sparks() -> void:
	_spark_cd = 3.6 if hp > 3 else 2.6
	_spark_sfx.play()
	var from := global_position + Vector2(_dir * W / 2.0, -H / 2.0 + 8.0)
	var to: Vector2 = _player.global_position
	for k in [0.75, 1.0, 1.3]:
		var target := Vector2(from.x + (to.x - from.x) * k, to.y)
		var t := clampf(absf(target.x - from.x) / 260.0, 0.6, 1.2)
		var s := Spark.new()
		s.velocity = Vector2((target.x - from.x) / t, (target.y - from.y - 0.5 * Spark.GRAVITY * t * t) / t)
		s.position = get_parent().to_local(from)
		s.hit.connect(func(push: Vector2) -> void: hurt_player.emit(push))
		get_parent().add_child(s)


func _check_player() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		var on_top := (p.velocity.y > 0.0 or p.is_pounding()) and feet < global_position.y - H / 2.0 + 8.0
		if on_top and heat() >= 2.0:
			# Red hot: it burns. Bounce off, singed.
			_sizzle_sfx.play()
			hurt_player.emit(Vector2(signf(p.global_position.x - global_position.x), -1.0))
			p.velocity.y = -p.jump_velocity * 0.7
			return
		if on_top:
			if _mode == "hurt":
				p.velocity.y = -p.jump_velocity * 0.6
				return
			p.velocity.y = -p.jump_velocity * 0.85
			p.stomped()   # Hot Feet card
			_take_hit(p)
			return
		if p.is_safe():
			return
		var dx: float = p.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else -_dir, -1.0))


func _take_hit(p: Player) -> void:
	hp -= 1
	_flash = 0.3
	_hit_sfx.pitch_scale = 1.0 + (MAX_HP - hp) * 0.05
	_hit_sfx.play()
	p.shake(6.0, 0.3)
	if hp <= 0:
		_mode = "dead"
		for n in get_tree().get_nodes_in_group("forge_shots"):
			n.queue_free()
		if room and room.has_method("set_plates_active"):
			room.set_plates_active(false)
		defeated.emit(global_position)
		CardFx.spawn(get_parent(), global_position, "boom")
		var boom := BigBadSquare._sfx("forge_boss_defeat", 0.0)
		get_parent().add_child(boom)
		boom.finished.connect(boom.queue_free)
		boom.play()
		p.shake(12.0, 0.7)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_mode = "hurt"
	_timer = 0.8
	_stun = 0.0
	if hp == 3:
		# Stage 2: the forge heats up.
		_heat_t = 0.0
		_slam_cd = 1.5
		p.shake(10.0, 0.5)
		if room and room.has_method("set_plates_active"):
			room.set_plates_active(true)


func _draw() -> void:
	var w := W / 2.0
	var h := H / 2.0
	var sq := _squash / 0.2 if _squash > 0.0 else 0.0
	if _mode == "crouch":
		sq = 0.8
	var top := -h + 8.0 * sq
	var ht := heat()
	var iron := IRON.lerp(Color.WHITE, 0.5) if _flash > 0.0 else IRON
	var face := iron.lerp(Color("b5381a"), 1.0 if ht >= 2.0 else ht * 0.4)
	# Anvil: a wide top with a horn, a narrow waist and a heavy base.
	draw_rect(Rect2(-w - 1, top - 1, W + 2, 18), EDGE)
	draw_rect(Rect2(-w, top, W, 16), face)
	draw_rect(Rect2(-w, top, W, 3), IRON_LIGHT if ht < 2.0 else Color("ffd08a"))
	var horn := _dir * w
	draw_colored_polygon(PackedVector2Array([Vector2(horn, top), Vector2(horn + _dir * 18.0, top + 4.0),
		Vector2(horn, top + 12.0)]), face)
	draw_rect(Rect2(-w * 0.55, top + 16, W * 0.55, (h - 14.0) - (top + 16.0)), IRON_DARK)
	draw_rect(Rect2(-w * 0.85, h - 14, W * 0.85, 14), IRON)
	draw_rect(Rect2(-w * 0.85, h - 3, W * 0.85, 3), IRON_DARK)
	# A glowing, furious face on the waist.
	var ex := _dir * 6.0
	var fy := top + 26.0
	var glow := Color("ff9a1f")
	if _stun > 0.0:
		draw_rect(Rect2(ex - 14, fy, 10, 3), glow)
		draw_rect(Rect2(ex + 4, fy, 10, 3), glow)
	else:
		draw_rect(Rect2(ex - 14, fy - 4, 10, 7), glow)
		draw_rect(Rect2(ex + 4, fy - 4, 10, 7), glow)
		draw_colored_polygon(PackedVector2Array([Vector2(ex - 16, fy - 9), Vector2(ex - 2, fy - 4),
			Vector2(ex - 2, fy - 1), Vector2(ex - 16, fy - 6)]), EDGE)
		draw_colored_polygon(PackedVector2Array([Vector2(ex + 16, fy - 9), Vector2(ex + 2, fy - 4),
			Vector2(ex + 2, fy - 1), Vector2(ex + 16, fy - 6)]), EDGE)
		draw_rect(Rect2(ex - 8, fy + 8, 16, 4), Color("ffd23f") if _mode == "crouch" else Color(glow, 0.8))
	if ht > 0.0:
		for i in 5:
			var fx := -w + 8.0 + i * (W - 16.0) / 4.0
			var fh := (3.0 + 4.0 * ht if ht < 2.0 else 10.0) * (0.6 + 0.4 * sin(_t * 15.0 + i))
			draw_rect(Rect2(fx - 2, top - fh, 4, fh), Color("ff9a1f") if ht >= 2.0 else Color(1.0, 0.7, 0.3, 0.5 * ht))
	# Hearts above.
	var hs := HeartArt.size(3.0)
	var gap := 4.0
	var total := MAX_HP * hs.x + (MAX_HP - 1) * gap
	for i in MAX_HP:
		HeartArt.draw(self, Vector2(-total / 2.0 + i * (hs.x + gap), top - hs.y - 14.0), 3.0, i < hp)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)


## Fire rolling along the floor away from a slam. Jump over it.
class FireWave:
	extends Node2D
	signal hit(push: Vector2)
	const SPEED := 290.0
	const TALL := 22.0
	var dir := 1.0
	var min_x := 0.0
	var max_x := 2000.0
	var _life := 2.4
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		add_to_group("forge_shots")
		z_index = 3

	func _physics_process(delta: float) -> void:
		_t += delta
		_life -= delta
		position.x += dir * SPEED * delta
		if _life <= 0.0 or global_position.x < min_x + 8.0 or global_position.x > max_x - 8.0:
			queue_free()
			return
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p and not _done:
			var feet: float = p.global_position.y + Player.SIZE / 2.0
			if absf(p.global_position.x - global_position.x) < 16.0 and feet > global_position.y - TALL:
				_done = true
				hit.emit(Vector2(dir, -1.0))
		queue_redraw()

	func _draw() -> void:
		var f := 0.8 + 0.2 * sin(_t * 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(6, -TALL * f),
			Vector2(0, -TALL * f - 6), Vector2(-6, -TALL * f)]), Color("e8501c"))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(0, -TALL * 0.65 * f)]), Color("ffd23f"))


## A spark spat in an arc. Costs a heart on touch; fizzles on the ground.
class Spark:
	extends Node2D
	signal hit(push: Vector2)
	const GRAVITY := 700.0
	var velocity := Vector2.ZERO
	var _life := 3.0
	var _t := 0.0

	func _ready() -> void:
		add_to_group("forge_shots")
		z_index = 3

	func _physics_process(delta: float) -> void:
		_t += delta
		_life -= delta
		velocity.y += GRAVITY * delta
		position += velocity * delta
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p and global_position.distance_to(p.global_position) < 16.0:
			hit.emit(Vector2(signf(velocity.x), -1.0))
			queue_free()
			return
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position
		q.collision_mask = 1
		for r in get_world_2d().direct_space_state.intersect_point(q, 4):
			if not r.collider is CharacterBody2D:
				queue_free()
				return
		if _life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := 5.0 + sin(_t * 40.0)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color("ff9a1f"))
		draw_rect(Rect2(-r * 0.5, -r * 0.5, r, r), Color("ffe08a"))
		draw_rect(Rect2(-velocity.normalized() * 10.0 - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.6, 0.2, 0.6))
