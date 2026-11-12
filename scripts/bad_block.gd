class_name BadBlock
extends CharacterBody2D
## Bad Block: a basic enemy. It walks toward the player along whatever it stands on, but never
## off an edge. Jump on it (or dash or pound into it) to squash it; touching its sides costs a
## heart. Squashed ones drop a card now and then, otherwise 1 pixel.

signal hurt_player(push: Vector2)
signal broken(pos: Vector2)

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


func shove(dir: float, tiles := 2) -> void:
	position.x += CardFx.clear_shift(self, global_position, half_size(), dir, tiles)


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
	if _player and _stun == 0.0 and is_on_floor():
		var d := _player.global_position - global_position
		if absf(d.x) < SIGHT * (1.5 if hard else 1.0) and absf(d.y) < 96.0 and absf(d.x) > 2.0:
			_dir = signf(d.x)
			if _ground_ahead():
				velocity.x = _dir * speed * (0.5 if _slow > 0.0 else 1.0)
	move_and_slide()
	_check_player()
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()


## True if there's floor just past its front edge, so it never walks off a platform.
func _ground_ahead() -> bool:
	var from := global_position + Vector2(_dir * (SIZE / 2.0 + 2.0), 0.0)
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
			if not p.is_pounding():
				p.velocity.y = -p.jump_velocity * 0.6   # bounce off its squashed head
			_die()
			return
		var dx: float = p.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else -_dir, -1.0))


func _draw() -> void:
	var h := SIZE / 2.0
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
