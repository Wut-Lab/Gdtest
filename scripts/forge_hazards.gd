class_name ForgeHazards
extends RefCounted
## Ember Forge hazards. Each is its own small node class:
##   Lava      _  glowing pools of lava sunk into the floor. Touching it costs a heart and pops you
##                up out of it (it keeps pushing you out while you're in it).
##   HotPlate  :  iron platforms (jump up through them) that heat up in a cycle: cool, then
##                glowing (the warning), then red hot. Standing on a red-hot plate costs a heart.
##   FlameJet  j  a grate in the floor that sputters, then roars a column of fire 2.5 tiles high.

const EDGE := Color("1b2440")


## Every "_" cell in a map, as one node that draws and checks them all.
class Lava:
	extends Node2D
	signal hurt_player(push: Vector2)
	const T := 32
	var cells: Array[Vector2i] = []
	var _t := 0.0
	var _player: Player

	func _ready() -> void:
		z_index = 4

	func _physics_process(delta: float) -> void:
		_t += delta
		if cells.is_empty():
			return
		if _player == null:
			_player = get_tree().get_first_node_in_group("player")
		if _player and _player.active:
			var feet := _player.position + Vector2(0.0, Player.SIZE / 2.0)
			var c := Vector2i(int(floor(feet.x / T)), int(floor((feet.y - 1.0) / T)))
			if c in cells and fposmod(feet.y, T) > 8.0:
				_player.velocity.y = minf(_player.velocity.y, -560.0)   # always pops you out
				hurt_player.emit(Vector2(0.0, -1.0))
		queue_redraw()

	func _draw() -> void:
		for c in cells:
			var x := c.x * T
			var y := c.y * T
			draw_rect(Rect2(x, y + 8, T, T - 8), Color("c2410c"))
			draw_rect(Rect2(x, y + 16, T, T - 16), Color("9a2a0a"))
			var wave := 2.0 * sin(_t * 3.0 + x * 0.2)
			draw_rect(Rect2(x, y + 7 + wave, T, 4), Color("ff9a1f"))
			draw_rect(Rect2(x + 4, y + 9 + wave, 10, 2), Color("ffd23f"))
			var k := fmod(_t * 0.7 + (c.x % 5) * 0.21, 1.0)   # a bubble rising and popping
			if k < 0.6:
				draw_circle(Vector2(x + 8 + (c.x * 7) % 16, y + 22 - k * 14.0), 2.0 + k * 3.0, Color("ffb347"))
			draw_rect(Rect2(x, y - 6, T, 6), Color(1.0, 0.5, 0.1, 0.12 + 0.05 * sin(_t * 4.0)))   # heat glow


## One tile of hot plate. Plates in a row share a phase so they heat up together.
class HotPlate:
	extends StaticBody2D
	signal hurt_player(push: Vector2)
	const W := 32.0
	const THICK := 12.0
	const COOL := 2.2
	const WARN := 0.8
	const HOT := 1.2
	var phase := 0.0
	## Off: stays cool (boss floors, until the boss heats them up).
	var active := true
	var _t := 0.0
	var _top: Area2D

	func _ready() -> void:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(W, THICK)
		col.shape = shape
		col.one_way_collision = true
		add_child(col)
		_top = Area2D.new()
		var ac := CollisionShape2D.new()
		var ash := RectangleShape2D.new()
		ash.size = Vector2(W - 6.0, 8.0)
		ac.shape = ash
		ac.position = Vector2(0.0, -THICK / 2.0 - 4.0)
		_top.add_child(ac)
		add_child(_top)

	func heat() -> float:
		## 0 cool, 0..1 warming (the warning), 2 red hot.
		if not active:
			return 0.0
		var k := fposmod(_t + phase, COOL + WARN + HOT)
		if k < COOL:
			return 0.0
		if k < COOL + WARN:
			return (k - COOL) / WARN
		return 2.0

	func reset() -> void:
		_t = 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if heat() >= 2.0:
			for b in _top.get_overlapping_bodies():
				if b is Player and b.is_on_floor():
					hurt_player.emit(Vector2(0.0, -1.0))
		queue_redraw()

	func _draw() -> void:
		var h := heat()
		var base := Color("4a4f5c")
		var col := base.lerp(Color("c2410c"), clampf(h, 0.0, 1.0) * 0.7) if h < 2.0 else Color("e8501c")
		draw_rect(Rect2(-W / 2.0, -THICK / 2.0, W, THICK), EDGE)
		draw_rect(Rect2(-W / 2.0 + 1, -THICK / 2.0 + 1, W - 2, THICK - 2), col)
		draw_rect(Rect2(-W / 2.0 + 1, -THICK / 2.0 + 1, W - 2, 2), col.lightened(0.3))
		for rx in [-10.0, 10.0]:
			draw_rect(Rect2(rx - 1.5, -1.5, 3, 3), EDGE)   # rivets
		if h > 0.0:
			# Warning flicker, then rising heat haze over a red-hot plate.
			var a := 0.5 * clampf(h, 0.0, 1.0) * (0.6 + 0.4 * sin(_t * 20.0)) if h < 2.0 else 0.6
			for i in 3:
				var sx := -10.0 + i * 10.0 + sin(_t * 6.0 + i) * 2.0
				draw_rect(Rect2(sx - 1, -THICK / 2.0 - 10.0 - fmod(_t * 30.0 + i * 5.0, 12.0), 2, 6),
					Color(1.0, 0.7, 0.3, a))


## A fire jet in the floor. Stands on the floor of its cell.
class FlameJet:
	extends Area2D
	signal hurt_player(push: Vector2)
	const IDLE := 1.6
	const SPUTTER := 0.6
	const BURST := 1.0
	const HEIGHT := 80.0
	var phase := 0.0
	var _t := 0.0
	var _col: CollisionShape2D
	var _sfx: AudioStreamPlayer2D
	var _was_burst := false

	func _ready() -> void:
		_col = CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(18.0, HEIGHT)
		_col.shape = shape
		_col.position = Vector2(0.0, -HEIGHT / 2.0)
		add_child(_col)
		_sfx = AudioStreamPlayer2D.new()
		_sfx.stream = load("res://audio/flame_jet.wav")
		_sfx.volume_db = -6.0
		_sfx.max_distance = 700.0
		_sfx.bus = AudioSettings.SOUNDS_BUS
		add_child(_sfx)

	func _stage() -> float:
		## 0 idle, 0..1 sputtering, 2 roaring.
		var k := fposmod(_t + phase, IDLE + SPUTTER + BURST)
		if k < IDLE:
			return 0.0
		if k < IDLE + SPUTTER:
			return (k - IDLE) / SPUTTER
		return 2.0

	func reset() -> void:
		_t = 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		var burst := _stage() >= 2.0
		if burst and not _was_burst:
			_sfx.pitch_scale = randf_range(0.9, 1.1)
			_sfx.play()
		_was_burst = burst
		if burst:
			for b in get_overlapping_bodies():
				if b is Player:
					var dx: float = b.global_position.x - global_position.x
					hurt_player.emit(Vector2(signf(dx) if absf(dx) > 1.0 else 1.0, -1.0))
		queue_redraw()

	func _draw() -> void:
		# The grate.
		draw_rect(Rect2(-14, -6, 28, 6), EDGE)
		draw_rect(Rect2(-13, -5, 26, 4), Color("3b3f4a"))
		for i in 4:
			draw_rect(Rect2(-11 + i * 6, -5, 2, 4), Color("1b1d24"))
		var s := _stage()
		if s == 0.0:
			draw_rect(Rect2(-6, -4, 12, 2), Color(1.0, 0.45, 0.1, 0.4 + 0.2 * sin(_t * 5.0)))   # a faint glow
			return
		var h := HEIGHT * (0.18 * s if s < 2.0 else 1.0)
		var flick := 0.85 + 0.15 * sin(_t * 30.0)
		if s >= 2.0:
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -4), Vector2(10, -4), Vector2(5, -h * flick),
				Vector2(0, -h * flick - 8), Vector2(-5, -h * flick)]), Color("e8501c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(3, -h * 0.7 * flick),
				Vector2(-3, -h * 0.7 * flick)]), Color("ff9a1f"))
			draw_rect(Rect2(-2, -h * 0.45, 4, h * 0.45 - 4), Color("ffd23f"))
		else:
			for i in 3:   # sputtering licks of flame: the warning
				var lx := -6.0 + i * 6.0
				draw_rect(Rect2(lx - 1.5, -4 - h * (0.5 + 0.5 * sin(_t * 25.0 + i * 2.0)), 3, h), Color("ff9a1f"))
