class_name Harpoonist
extends CharacterBody2D
## Harpoonist Block (u, Cavern Lake): a brown block in swimming goggles with a harpoon gun. It
## stays put, turns to face you, and when you're in range it aims (its gun glints) and fires a
## harpoon in an arc that comes down where you're standing. A harpoon hit costs a heart and a
## half. Touching its sides costs a heart; jump on it (or dash or pound into it) to squash it.

signal hurt_player(push: Vector2)
## A harpoon hit you: a heart and a half.
signal harpooned(push: Vector2)
signal broken(pos: Vector2)

const SIZE := 26.0
const RANGE := 11 * 32.0
const RELOAD := 2.6
const AIM := 0.6
const GRAVITY := 900.0
const BODY := Color("8a5a32")
const TOP := Color("b07a48")
const SHADE := Color("5a3a22")

var _origin := Vector2.ZERO
var _player: Node2D
var _dir := -1.0
var _hit_area: Area2D
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _reload := 1.5
var _aim := 0.0
var _recoil := 0.0


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
	ash.size = Vector2(SIZE + 4.0, SIZE + 4.0)
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)


func reset() -> void:
	position = _origin
	velocity = Vector2.ZERO
	_stun = 0.0
	_slow = 0.0
	_reload = 1.5
	_aim = 0.0
	for h in get_tree().get_nodes_in_group("harpoons"):
		h.queue_free()
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


func take_hit(_kind: String) -> bool:
	_die()
	return true


func half_size() -> Vector2:
	return Vector2(SIZE, SIZE) / 2.0


func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)
	_aim = 0.0


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 2) -> void:
	var shift := CardFx.clear_shift(self, global_position, half_size(), dir, tiles)
	while shift != 0.0 and not _floor_under(global_position.x + shift):
		shift -= signf(shift) * 32.0
	position.x += shift


func _floor_under(x: float) -> bool:
	var from := Vector2(x, global_position.y)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, SIZE / 2.0 + 8.0), 1)
	q.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func smash() -> void:
	_die()


func _die() -> void:
	if not visible:
		return
	CardFx.spawn(get_parent(), global_position, "pop")
	broken.emit(global_position)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_stun = maxf(_stun - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	_recoil = maxf(_recoil - delta, 0.0)
	velocity.x = 0.0
	velocity.y = minf(velocity.y + 2200.0 * delta, 900.0)
	move_and_slide()
	var pace := 0.5 if _slow > 0.0 else 1.0
	if _player and _stun == 0.0:
		var d := _player.global_position - global_position
		if absf(d.x) > 4.0:
			_dir = signf(d.x)
		if absf(d.x) < RANGE and absf(d.y) < 7 * 32.0:
			if _aim > 0.0:
				_aim -= delta * pace
				if _aim <= 0.0:
					_fire()
			else:
				_reload -= delta * pace
				if _reload <= 0.0:
					_aim = AIM
		else:
			_aim = 0.0
	_check_player()
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


## Fire a harpoon in an arc that lands where the player is now.
func _fire() -> void:
	_reload = RELOAD
	_recoil = 0.2
	var from := global_position + Vector2(_dir * 18.0, -4.0)
	var to: Vector2 = _player.global_position + Vector2(0.0, 6.0)
	var t := clampf(absf(to.x - from.x) / 300.0, 0.55, 1.3)
	var v := Vector2((to.x - from.x) / t, (to.y - from.y - 0.5 * GRAVITY * t * t) / t)
	var h := Harpoon.new()
	h.position = get_parent().to_local(from)
	h.velocity = v
	h.hit.connect(func(push: Vector2) -> void: harpooned.emit(push))
	get_parent().add_child(h)


func _check_player() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		if p.is_dashing() or p.is_pounding() or (p.velocity.y > 0.0 and feet < global_position.y):
			if p.is_dashing():
				_die()
				p.chain_dash()
				return
			if not p.is_pounding():
				p.velocity.y = -p.jump_velocity * 0.6
			_die()
			return
		var dx: float = p.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else _dir, -1.0))


func _draw() -> void:
	var h := SIZE / 2.0
	draw_rect(Rect2(-h, -h, SIZE, SIZE), BODY)
	draw_rect(Rect2(-h, -h, SIZE, 5), TOP)
	draw_rect(Rect2(-h, h - 4, SIZE, 4), SHADE)
	# Goggles: a strap round the head and two round-ish lenses.
	draw_rect(Rect2(-h, -6, SIZE, 3), Color("2b2b2b"))
	var ex := _dir * 3.0
	for x in [ex - 9.0, ex + 1.0]:
		draw_rect(Rect2(x - 1, -9, 10, 9), Color("2b2b2b"))
		draw_rect(Rect2(x, -8, 8, 7), Color("8fd3ff") if _stun == 0.0 else Color("c8d0de"))
		draw_rect(Rect2(x + 1, -7, 3, 2), Color.WHITE)
		draw_rect(Rect2(x + 3 + _dir * 2, -5, 2, 2), Color("1b2440"))
	draw_rect(Rect2(ex - 3, 5, 6, 2), Color("3f2817"))   # a firm, flat mouth
	# The harpoon gun, held out front: a stock, a long barrel and a loaded barbed tip.
	var gx := _dir * (h - 2.0) - _dir * _recoil * 20.0
	var y := 4.0
	draw_rect(Rect2(minf(gx, gx + _dir * 8.0), y - 1, 8, 7), Color("5a3a22"))
	draw_rect(Rect2(minf(gx + _dir * 6.0, gx + _dir * 22.0), y, 16, 4), Color("6d7685"))
	if _reload > 0.4 or _aim > 0.0:
		var tip := gx + _dir * 24.0
		draw_colored_polygon(PackedVector2Array([Vector2(tip, y - 1), Vector2(tip, y + 5),
			Vector2(tip + _dir * 6.0, y + 2)]), Color("c8d0de"))
	if _aim > 0.0 and fmod(_aim, 0.2) < 0.1:
		draw_rect(Rect2(gx + _dir * 24.0 - 3.0, y - 4, 6, 2), Color("ffde59"))   # glint: about to fire
		draw_rect(Rect2(gx + _dir * 24.0 - 1.0, y - 6, 2, 6), Color("ffde59"))
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)


## A harpoon in flight: falls in an arc, hurts the player on touch, and sticks where it lands.
class Harpoon:
	extends Node2D
	signal hit(push: Vector2)
	var velocity := Vector2.ZERO
	var _stuck := 0.0
	var _life := 3.0

	func _ready() -> void:
		add_to_group("harpoons")
		z_index = 3

	func _physics_process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		if _stuck > 0.0:
			_stuck -= delta
			modulate.a = clampf(_stuck / 0.4, 0.0, 1.0)
			if _stuck <= 0.0:
				queue_free()
			return
		velocity.y += GRAVITY * delta
		position += velocity * delta
		rotation = velocity.angle()
		var p: Node2D = get_tree().get_first_node_in_group("player")
		var tip := global_position + Vector2.RIGHT.rotated(rotation) * 10.0
		if p and p.visible and tip.distance_to(p.global_position) < 15.0:
			hit.emit(Vector2(signf(velocity.x), -1.0))
			queue_free()
			return
		var q := PhysicsPointQueryParameters2D.new()
		q.position = tip
		q.collision_mask = 1
		for r in get_world_2d().direct_space_state.intersect_point(q, 4):
			if not r.collider is CharacterBody2D:
				_stuck = 1.0
				return

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2(-16, 0), Vector2(6, 0), Color("6b4428"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(4, -4), Vector2(4, 4), Vector2(13, 0)]), Color("c8d0de"))
		draw_line(Vector2(5, -4), Vector2(1, -7), Color("c8d0de"), 2.0)   # barbs
		draw_line(Vector2(5, 4), Vector2(1, 7), Color("c8d0de"), 2.0)
		draw_line(Vector2(-16, 0), Vector2(-24, -3), Color("e6dcc0"), 1.0)   # a bit of rope
