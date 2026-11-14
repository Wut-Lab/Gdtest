class_name MossBoss
extends CharacterBody2D
## Old Mossback (y in a text map): the Mossy Cave's boss, a giant Moss Covered Square with
## 4 hearts. Only jumps on his head hurt him.
##   Phase 1 (hearts 4 and 3): he hops after you, and every landing leaves slippery moss.
##   Phase 2 (hearts 2 and 1): he leaps up and hangs by vines under the floating platform,
##   lobbing Moss Covered Squares. Each one that lands turns into a mossy block, so the room
##   changes as the fight goes on. Neighbouring stacks never differ by more than 2 blocks (no
##   pit is too deep to jump out of), and the stacks beside him grow into stairs up to his head.
##   After the 3rd hit the blocks crumble and he throws faster.

signal hurt_player(push: Vector2)
signal defeated(pos: Vector2)
## Phase 1: landed from a hop here (feet); the level grows slippery moss there.
signal landed(pos: Vector2)

const T := 32.0
const SIZE := 52.0
const MAX_HP := 4
const GRAVITY := 2200.0
const HOP_SPEED := 600.0
const HOP_SIDE := 150.0
const FLASH := 1.0
const LEAP_TIME := 0.9
## Vine length between the platform and his head while he hangs.
const VINE := 72.0
const THROW_TIME := 0.95
const BODY := Color("2f5a2a")
const SHADE := Color("1d3a1b")
const MOSS := Color("4f9a3c")
const LEAF := Color("6cc04f")
const EYES := Color("eef1fa")
const PUPIL := Color("1b2440")

## Set by the level: the cell in the middle of the floating platform he hangs from, the row of
## the floor's top tiles, and the first and last columns inside the walls.
var perch_cell := Vector2i(9, 2)
var floor_row := 12
var min_col := 1
var max_col := 18
## The level, for adding and clearing his blocks.
var room: Node

var hp := MAX_HP
var _origin := Vector2.ZERO
var _player: Player
var _dir := -1.0
var _hit_area: Area2D
var _shape: CollisionShape2D
var _wait := 1.0
var _mode := "hop"      # hop, leap, hang
var _mode_t := 0.0
var _leap_from := Vector2.ZERO
var _flash := 0.0
var _stun := 0.0
var _slow := 0.0
var _bolts: Array = []
var _next_bolts := 0.0
var _t := 0.0
var _was_on_floor := true
var _throw_in := 1.5
## Blocks stacked in each column so far: {column: count}.
var _heights := {}
## Squares in the air: {from, to (global), cell, t}.
var _shots: Array = []
var _hit_sfx := BigBadSquare._sfx("boss_hit", 0.0)
var _crash_sfx := BigBadSquare._sfx("boss_crash", -4.0)
var _land_sfx := BigBadSquare._sfx("land", -2.0)
var _throw_sfx := BigBadSquare._sfx("jump", -6.0)


func _ready() -> void:
	add_to_group("card_targets")
	_origin = position
	collision_layer = 4
	collision_mask = 1
	_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	_shape.shape = shape
	add_child(_shape)
	_hit_area = Area2D.new()
	var ac := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(SIZE + 6.0, SIZE + 6.0)
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)
	for p in [_hit_sfx, _crash_sfx, _land_sfx, _throw_sfx]:
		add_child(p)


func reset() -> void:
	position = _origin
	velocity = Vector2.ZERO
	hp = MAX_HP
	_stun = 0.0
	_slow = 0.0
	_flash = 0.0
	_mode = "hop"
	_mode_t = 0.0
	_wait = 1.0
	_shots.clear()
	_clear_blocks(false)
	collision_mask = 1
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## Card effects: stuns and slows work on him (and pushes while he's on the ground), but only
## jumps on his head hurt him.
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func is_stunned() -> bool:
	return _stun > 0.0


func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func shove(dir: float, tiles := 2) -> void:
	if _mode == "hop":
		position.x += CardFx.clear_shift(self, global_position, half_size(), dir, tiles)


func smash() -> void:
	if _stun > 0.0:
		return
	if _mode == "hop" and _player:
		var away := signf(global_position.x - _player.global_position.x)
		shove(away if away != 0.0 else -_dir, 1)
	stun(0.8)
	_crash_sfx.play()


func take_hit(_kind: String) -> bool:
	return false


func half_size() -> Vector2:
	return Vector2(SIZE, SIZE) / 2.0


## Where he hangs: under the middle of the platform, on his vines.
func _hang_pos() -> Vector2:
	return Vector2(perch_cell.x * T + T / 2.0, (perch_cell.y + 1) * T + VINE + SIZE / 2.0)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	_update_shots(delta)
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07
			_bolts = CardFx.stun_bolts(half_size())
		if _mode == "hop":
			velocity.x = 0.0
			velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
			_move()
		else:
			_check_player()
			queue_redraw()
		return
	var pace := 0.5 if _slow > 0.0 else 1.0
	delta *= pace
	_mode_t += delta
	match _mode:
		"hop":
			velocity.y = minf(velocity.y + GRAVITY * delta / pace, 900.0)
			if is_on_floor():
				velocity.x = 0.0
				if _player:
					var to_player := signf(_player.global_position.x - global_position.x)
					if to_player != 0.0:
						_dir = to_player
				if hp <= 2 and _flash < 0.4:
					_start_leap()
				else:
					_wait -= delta
					if _wait <= 0.0:
						velocity = Vector2(_dir * HOP_SIDE * pace, -HOP_SPEED)
						_wait = randf_range(0.8, 1.4)
			_move()
		"leap":
			# One big arc up to his perch; nothing can touch him on the way.
			var k := clampf(_mode_t / LEAP_TIME, 0.0, 1.0)
			var to := _hang_pos()
			position = _leap_from.lerp(to, k) + Vector2(0.0, -110.0 * sin(k * PI))
			if k >= 1.0:
				position = to
				_mode = "hang"
				_mode_t = 0.0
				_throw_in = 1.0
				_land_sfx.pitch_scale = 0.8
				_land_sfx.play()
				if _player:
					_player.shake(4.0, 0.2)
			queue_redraw()
		"hang":
			_throw_in -= delta
			if _throw_in <= 0.0:
				_throw_in = 1.2 if hp >= 2 else 0.9
				_throw()
			_check_player()
			queue_redraw()


func _move() -> void:
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land_sfx.pitch_scale = randf_range(0.55, 0.65)
		_land_sfx.play()
		landed.emit(global_position + Vector2(0.0, SIZE / 2.0))
		if _player:
			_player.shake(3.0, 0.18)
	_was_on_floor = is_on_floor()
	_check_player()
	queue_redraw()


func _start_leap() -> void:
	_mode = "leap"
	_mode_t = 0.0
	_leap_from = position
	velocity = Vector2.ZERO
	collision_mask = 0
	_throw_sfx.pitch_scale = 0.6
	_throw_sfx.play()


# ---------- Phase 2: lobbing squares that turn into blocks ----------

## The most blocks a column may hold: stairs of 4, 3, 2, 1 on each side of him, one block under
## him and around the room, none by the doors.
func _cap(col: int) -> int:
	if col < min_col + 3 or col > max_col - 2:
		return 0
	var d := absi(col - perch_cell.x)
	if d <= 1:
		return 1
	return maxi(6 - d, 1)


func _height(col: int) -> int:
	if col < min_col or col > max_col:
		return 99   # the walls
	return _heights.get(col, 0)


## Columns where one more block is allowed: under its cap, and never more than 2 blocks taller
## than a neighbour (so every pit can be jumped out of).
func _open_columns() -> Array:
	var open := []
	for col in range(min_col, max_col + 1):
		var h := _height(col) + 1
		if h > _cap(col):
			continue
		var ok := true
		for n in [col - 1, col + 1]:
			if n >= min_col and n <= max_col and h - _height(n) > 2:
				ok = false
		for s in _shots:
			if s.cell.x == col:
				ok = false   # one square per column at a time
		if ok:
			open.append(col)
	return open


func _throw() -> void:
	var open := _open_columns()
	var col := -1
	if not open.is_empty():
		# Half the time at the open column nearest you; otherwise the one that builds his
		# stairs fastest (the tallest allowed), with a little luck mixed in.
		if _player and randf() < 0.5:
			var px := int(floor(_player.global_position.x / T))
			open.sort_custom(func(a: int, b: int) -> bool: return absi(a - px) < absi(b - px))
			col = open[0]
		else:
			open.sort_custom(func(a: int, b: int) -> bool: return _cap(a) - _height(a) > _cap(b) - _height(b))
			col = open[randi_range(0, mini(2, open.size() - 1))]
	var block := col != -1
	if not block:
		# Nowhere left to build: he just throws at you (it pops when it lands).
		col = clampi(int(floor(_player.global_position.x / T)) if _player else perch_cell.x, min_col, max_col)
	var cell := Vector2i(col, floor_row - 1 - _height(col))
	var parent: Node2D = get_parent()
	_shots.append({"from": global_position + Vector2(0.0, SIZE / 2.0),
		"to": parent.to_global(Vector2(col * T + T / 2.0, cell.y * T + T / 2.0)),
		"cell": cell, "t": 0.0, "block": block})
	_throw_sfx.pitch_scale = randf_range(0.75, 0.9)
	_throw_sfx.play()


func _shot_pos(s: Dictionary) -> Vector2:
	var k: float = clampf(s.t / THROW_TIME, 0.0, 1.0)
	var from: Vector2 = s.from
	var to: Vector2 = s.to
	return from.lerp(to, k) + Vector2(0.0, -90.0 * sin(k * PI))


func _update_shots(delta: float) -> void:
	for s in _shots.duplicate():
		s.t += delta * (0.5 if _slow > 0.0 else 1.0)
		var pos := _shot_pos(s)
		var hit := false
		if _player and _player.active:
			var d := _player.global_position - pos
			hit = absf(d.x) < 24.0 and absf(d.y) < 24.0
			if hit and s.t < THROW_TIME:
				hurt_player.emit(Vector2(signf(d.x) if d.x != 0.0 else 1.0, -1.0))
		if s.t >= THROW_TIME:
			_shots.erase(s)
			var to: Vector2 = s.to
			var blocked := false
			if _player:
				var d2 := _player.global_position - to
				blocked = absf(d2.x) < T / 2.0 + Player.SIZE / 2.0 - 2.0 and absf(d2.y) < T / 2.0 + Player.SIZE / 2.0 - 2.0
			if s.block and not blocked and room:
				room.add_boss_block(s.cell)
				_heights[s.cell.x] = _height(s.cell.x) + 1
				_land_sfx.pitch_scale = 1.2
				_land_sfx.play()
			else:
				CardFx.spawn(get_parent(), to, "pop")
				if blocked and not hit:
					hurt_player.emit(Vector2(1.0 if _player.global_position.x >= to.x else -1.0, -1.0))
	if not _shots.is_empty():
		queue_redraw()


func _clear_blocks(with_fx := true) -> void:
	if room:
		room.clear_boss_blocks(with_fx)
	_heights.clear()


# ---------- Getting hit ----------

func _check_player() -> void:
	if _mode == "leap":
		return
	for b in _hit_area.get_overlapping_bodies():
		if not b is Player:
			continue
		var p: Player = b
		var feet := p.global_position.y + Player.SIZE / 2.0
		var side := signf(p.global_position.x - global_position.x)
		if side == 0.0:
			side = -_dir
		if p.velocity.y >= 0.0 and feet < global_position.y - SIZE * 0.2:
			p.velocity.y = -p.jump_velocity * 0.85
			if _flash == 0.0:
				_take_stomp()
			return
		if p.is_dashing():
			p.dash_bounce(side)
			return
		if _flash > 0.0:
			return
		hurt_player.emit(Vector2(side, -1.0))


func _take_stomp() -> void:
	hp -= 1
	_flash = FLASH if hp != 1 else 1.5
	CardFx.spawn(get_parent(), global_position - Vector2(0.0, SIZE / 2.0), "pop")
	_hit_sfx.pitch_scale = 1.0 + (MAX_HP - hp) * 0.08
	_hit_sfx.play()
	if _player:
		_player.shake(6.0, 0.25)
	if hp <= 0:
		_shots.clear()
		defeated.emit(global_position)
		CardFx.spawn(get_parent(), global_position, "boom")
		var boom := BigBadSquare._sfx("boss_defeat", 0.0)
		get_parent().add_child(boom)
		boom.finished.connect(boom.queue_free)
		boom.play()
		if _player:
			_player.shake(12.0, 0.7)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	if hp == 1:
		# His blocks crumble; he starts again, throwing faster.
		_shots.clear()
		_clear_blocks()
		_crash_sfx.play()
		_throw_in = 1.6
		if _player:
			_player.shake(8.0, 0.4)


# ---------- Drawing ----------

func _draw() -> void:
	var h := SIZE / 2.0
	# Squares in the air (and where each will land).
	for s in _shots:
		var to: Vector2 = to_local(s.to)
		draw_rect(Rect2(to - Vector2(T, T) / 2.0, Vector2(T, T)), Color(0.42, 0.75, 0.31, 0.25 + 0.15 * sin(_t * 14.0)))
		_draw_small(to_local(_shot_pos(s)), s.t * 7.0)
	if _mode == "hang":
		# The vines he hangs by, up to the platform.
		for vx in [-16.0, 0.0, 16.0]:
			var sway := sin(_t * 1.4 + vx) * 1.5
			draw_line(Vector2(vx, -h), Vector2(vx + sway, -h - VINE), Color("3f7f31"), 3.0)
			draw_rect(Rect2(vx + sway - 4.0, -h - VINE * 0.5, 4, 3), LEAF)
	var blink := _flash > 0.0 and int(_flash * 12.0) % 2 == 0
	var body := BODY.lerp(Color.WHITE, 0.6) if blink else BODY
	draw_rect(Rect2(-h, -h, SIZE, SIZE), body)
	draw_rect(Rect2(-h, h - 7, SIZE, 7), SHADE if not blink else body)
	draw_rect(Rect2(-h - 2.0, -h - 3.0, SIZE + 4.0, 10), MOSS)
	for x in [-22.0, -12.0, -1.0, 10.0, 19.0]:
		draw_rect(Rect2(x, -h - 8.0, 4, 6), LEAF)
	draw_rect(Rect2(-h - 2.0, -h + 7.0, 5, 14), MOSS)
	draw_rect(Rect2(h - 3.0, -h + 7.0, 5, 20), MOSS)
	# The same tired face as the small ones, only bigger. About to throw: cheeks puffed.
	var ex := _dir * 5.0 if _mode == "hop" else 0.0
	if _mode == "hang" and _player:
		ex = clampf((_player.global_position.x - global_position.x) / 40.0, -1.0, 1.0) * 5.0
	var ey := -h + 18.0
	if _stun > 0.0:
		draw_rect(Rect2(ex - 16.0, ey + 5.0, 11.0, 3.0), EYES)
		draw_rect(Rect2(ex + 5.0, ey + 5.0, 11.0, 3.0), EYES)
	else:
		for x in [ex - 18.0, ex + 4.0]:
			draw_rect(Rect2(x, ey, 14.0, 12.0), EYES)
			draw_rect(Rect2(x, ey, 14.0, 6.0), SHADE)                    # heavy eyelid
			draw_rect(Rect2(x + 5.0 + signf(ex) * 2.0, ey + 6.0, 5.0, 6.0), PUPIL)
			draw_rect(Rect2(x + 2.0, ey + 14.0, 10.0, 2.0), SHADE)       # bag under the eye
	var puff := _mode == "hang" and _throw_in < 0.4
	if puff:
		draw_rect(Rect2(ex - 7.0, ey + 20.0, 14.0, 10.0), SHADE)
	else:
		draw_rect(Rect2(ex - 7.0, ey + 22.0, 14.0, 3.0), SHADE)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
	# His hearts: above his head on the ground, under him while he hangs.
	var hs := HeartArt.size(3.0)
	var gap := 4.0
	var total := hs.x * MAX_HP + gap * (MAX_HP - 1)
	var hy := -h - hs.y - 12.0 if _mode != "hang" else h + 8.0
	for i in MAX_HP:
		HeartArt.draw(self, Vector2(-total / 2.0 + i * (hs.x + gap), hy), 3.0, i < hp)


## A thrown Moss Covered Square, tumbling.
func _draw_small(at: Vector2, spin: float) -> void:
	draw_set_transform(at, spin)
	draw_rect(Rect2(-13, -13, 26, 26), BODY)
	draw_rect(Rect2(-14, -15, 28, 6), MOSS)
	for x in [-9.0, 2.0]:
		draw_rect(Rect2(x, -4, 7, 6), EYES)
		draw_rect(Rect2(x, -4, 7, 3), SHADE)
		draw_rect(Rect2(x + 2, -1, 3, 3), PUPIL)
	draw_set_transform(Vector2.ZERO)
