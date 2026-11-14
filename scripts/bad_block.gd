class_name BadBlock
extends CharacterBody2D
## Bad Block: a basic enemy. It walks toward the player along whatever it stands on, but never
## off an edge. Jump on it (or dash or pound into it) to squash it; touching its sides costs a
## heart. Squashed ones drop a card now and then, otherwise 1 pixel.

signal hurt_player(push: Vector2)
signal broken(pos: Vector2)
## Moss Covered Square: landed from a hop here (its feet).
signal landed(pos: Vector2)

const SIZE := 26.0
const BODY := Color("b8323a")
const TOP := Color("e5484d")
const SHADE := Color("7a1f26")
const EYES := Color("eef1fa")
const PUPIL := Color("1b2440")
## Sees the player this far away sideways (and 3 tiles up or down).
const SIGHT := 320.0

@export var speed := 70.0
## Hard Bad Block (k, Hard Replay): faster, sees farther, darker with horns.
@export var hard := false
## Moss Covered Square (q, Mossy Cave): dark green and tired-looking. Walks like a Bad Block,
## and also hops the way it faces; where it lands, moss grows on the blocks.
@export var mossy := false

const HOP_SPEED := 520.0
const HOP_SIDE := 135.0   # about 2 tiles per hop
var _hop_cd := 1.5
var _hopping := false
var _hop_vx := 0.0

var _origin := Vector2.ZERO
var _player: Node2D
var _dir := 1.0
var _hit_area: Area2D
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _squash := 0.0


func _ready() -> void:
	add_to_group("card_targets")
	_origin = position
	if hard:
		speed *= 1.6
	collision_layer = 4   # its own layer: the player passes into it instead of standing on it
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


## Back to its starting spot, alive, for a new run.
func reset() -> void:
	position = _origin
	velocity = Vector2.ZERO
	_stun = 0.0
	_slow = 0.0
	_hopping = false
	_hop_cd = 1.5
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## Any attack squashes it.
func take_hit(_kind: String) -> bool:
	_die()
	return true


func half_size() -> Vector2:
	return Vector2(SIZE, SIZE) / 2.0


func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


## Shoved sideways (Shockwave, Personal Space), but never past the edge of its platform.
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


## Angry Block Dash ran into it.
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
	velocity.y = minf(velocity.y + 2200.0 * delta, 900.0)
	velocity.x = 0.0
	var pace := 0.5 if _slow > 0.0 else 1.0
	if _hopping:
		velocity.x = _hop_vx * pace
	elif _player and _stun == 0.0 and is_on_floor():
		var d := _player.global_position - global_position
		if absf(d.x) < SIGHT * (1.5 if hard else 1.0) and absf(d.y) < 96.0 and absf(d.x) > 2.0:
			_dir = signf(d.x)
			if _ground_ahead():
				velocity.x = _dir * speed * pace
			if mossy:
				_hop_cd -= delta * pace
				if _hop_cd <= 0.0:
					_hop_cd = randf_range(1.4, 2.6)
					_hopping = true
					# Hop forward only onto floor (with a tile to spare); otherwise hop on the spot.
					_hop_vx = _dir * HOP_SIDE if _floor_at(_dir * 77.0) and _floor_at(_dir * 109.0) else 0.0
					velocity = Vector2(_hop_vx * pace, -HOP_SPEED)
	move_and_slide()
	if _hopping and is_on_floor() and velocity.y >= 0.0:
		_hopping = false
		_squash = 0.2
		landed.emit(global_position + Vector2(0.0, SIZE / 2.0))
	_check_player()
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


## True if there's floor a full tile past its front edge, so it never walks off a platform and
## always leaves one tile at the edge for the player to land on.
func _ground_ahead() -> bool:
	var from := global_position + Vector2(_dir * (SIZE / 2.0 + 2.0 + 32.0), 0.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, SIZE / 2.0 + 8.0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and not hit.collider is Player


## True if there's floor at this sideways offset, at the height it stands on now.
func _floor_at(dx: float) -> bool:
	var from := global_position + Vector2(dx, 0.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, SIZE / 2.0 + 8.0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and not hit.collider is Player


func _check_player() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		if p.is_dashing() or p.is_pounding() or (p.velocity.y > 0.0 and feet < global_position.y):
			if p.is_dashing():
				_die()
				p.chain_dash()   # Chain Dash card
				return
			if not p.is_pounding():
				p.velocity.y = -p.jump_velocity * 0.6   # bounce off its squashed head
			_die()
			return
		var dx: float = p.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else -_dir, -1.0))


func _draw() -> void:
	var h := SIZE / 2.0
	if mossy:
		_draw_mossy(h)
		return
	if hard:
		for sx in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(sx * 11.0, -h), Vector2(sx * 4.0, -h),
				Vector2(sx * 12.0, -h - 8.0)]), Color("eef1fa"))
	draw_rect(Rect2(-h, -h, SIZE, SIZE), Color("6e1a4a") if hard else BODY)
	draw_rect(Rect2(-h, -h, SIZE, 5), Color("a8287a") if hard else TOP)
	draw_rect(Rect2(-h, h - 4, SIZE, 4), Color("3f0f2b") if hard else SHADE)
	var ex := _dir * 3.0
	if _stun > 0.0:
		draw_rect(Rect2(ex - 7.0, -3.0, 5.0, 2.0), EYES)
		draw_rect(Rect2(ex + 2.0, -3.0, 5.0, 2.0), EYES)
	else:
		# Angry face: eyes cut by thick brows slanting down to the middle, pupils glaring where
		# it walks, and a frown of gritted teeth.
		draw_rect(Rect2(ex - 9.0, -6.0, 7.0, 6.0), EYES)
		draw_rect(Rect2(ex + 2.0, -6.0, 7.0, 6.0), EYES)
		draw_colored_polygon(PackedVector2Array([Vector2(ex - 10.0, -10.0), Vector2(ex - 1.0, -5.0),
			Vector2(ex - 1.0, -2.0), Vector2(ex - 10.0, -6.0)]), PUPIL)
		draw_colored_polygon(PackedVector2Array([Vector2(ex + 10.0, -10.0), Vector2(ex + 1.0, -5.0),
			Vector2(ex + 1.0, -2.0), Vector2(ex + 10.0, -6.0)]), PUPIL)
		draw_rect(Rect2(ex - 5.0 + _dir, -3.0, 2.0, 3.0), PUPIL)
		draw_rect(Rect2(ex + 4.0 + _dir, -3.0, 2.0, 3.0), PUPIL)
		# Mouth: dark slot with zigzag teeth, corners turned down.
		draw_rect(Rect2(ex - 6.0, 3.0, 12.0, 5.0), PUPIL)
		for i in 3:
			draw_rect(Rect2(ex - 5.0 + i * 4.0, 3.0, 2.0, 2.0), EYES)
			draw_rect(Rect2(ex - 3.0 + i * 4.0, 6.0, 2.0, 2.0), EYES)
		draw_rect(Rect2(ex - 8.0, 7.0, 2.0, 3.0), PUPIL)
		draw_rect(Rect2(ex + 6.0, 7.0, 2.0, 3.0), PUPIL)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)


## Moss Covered Square: dark green, moss on its head, half-shut tired eyes with bags under them.
func _draw_mossy(h: float) -> void:
	var sq := _squash / 0.2 if _squash > 0.0 else 0.0   # just landed: squashed flat for a moment
	var top := -h + 6.0 * sq
	draw_rect(Rect2(-h - 2.0 * sq, top, SIZE + 4.0 * sq, h - top), Color("2f5a2a"))
	draw_rect(Rect2(-h - 2.0 * sq, h - 4, SIZE + 4.0 * sq, 4), Color("1d3a1b"))
	draw_rect(Rect2(-h - 2.0 * sq - 1.0, top - 2.0, SIZE + 4.0 * sq + 2.0, 6), Color("4f9a3c"))
	for x in [-10.0, -3.0, 5.0]:
		draw_rect(Rect2(x, top - 5.0, 3, 4), Color("6cc04f"))
	draw_rect(Rect2(-h - 1.0, top + 4.0, 3, 7), Color("4f9a3c"))
	draw_rect(Rect2(h - 2.0, top + 4.0, 3, 10), Color("4f9a3c"))
	var ex := _dir * 3.0
	var ey := 1.0 + 3.0 * sq
	if _stun > 0.0:
		draw_rect(Rect2(ex - 8.0, ey, 6.0, 2.0), EYES)
		draw_rect(Rect2(ex + 2.0, ey, 6.0, 2.0), EYES)
	else:
		for x in [ex - 9.0, ex + 2.0]:
			draw_rect(Rect2(x, ey - 3.0, 7.0, 6.0), EYES)
			draw_rect(Rect2(x, ey - 3.0, 7.0, 3.0), Color("1d3a1b"))        # heavy eyelid
			draw_rect(Rect2(x + 2.0 + _dir, ey, 3.0, 3.0), PUPIL)
			draw_rect(Rect2(x + 1.0, ey + 4.0, 5.0, 1.0), Color("1d3a1b"))  # bag under the eye
		draw_rect(Rect2(ex - 3.0, ey + 7.0, 6.0, 2.0), Color("1d3a1b"))     # small flat mouth
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
