class_name VinePlatform
extends StaticBody2D
## Vine Platform (v, Mossy Cave): a dark green platform with moss on top and vines hanging under
## it, each 2-4 blocks long. You can land on it (and jump up through it), but jumping through
## its vines drags on your sideways speed in the air, so a jump may fall short.

const T := 32.0
const WIDTH := 96.0
const THICK := 12.0
const BODY := Color("2f5a2a")
const SHADE := Color("1d3a1b")
const MOSS := Color("4f9a3c")
const LEAF := Color("6cc04f")
const VINE := Color("3f7f31")

## One entry per tile column under the platform: how far its vines hang, in pixels.
var _lengths: Array[float] = []
## Each strand: x offset, length, sway phase.
var _strands: Array = []
var _player: Player
var _t := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, THICK)
	col.shape = shape
	col.one_way_collision = true
	add_child(col)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 13 + int(position.y) * 7
	for i in 3:
		var blocks := rng.randi_range(2, 4)
		_lengths.append(blocks * T)
		for k in 2:
			_strands.append({"x": -WIDTH / 2.0 + i * T + 8.0 + k * 16.0 + rng.randf_range(-3.0, 3.0),
				"len": blocks * T - rng.randf_range(0.0, 14.0) * k, "phase": rng.randf() * TAU})


## Nothing to put back for a new run (levels reset every obstacle).
func reset() -> void:
	pass


## Vine length (pixels) hanging at this x, or 0 outside the platform.
func vines_at(x: float) -> float:
	var i := int(floor((x - (global_position.x - WIDTH / 2.0)) / T))
	return _lengths[i] if i >= 0 and i < _lengths.size() else 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		var p := _player.global_position
		var top := global_position.y + THICK / 2.0
		var len := vines_at(p.x)
		if len > 0.0 and p.y > top and p.y - Player.SIZE / 2.0 < top + len:
			_player.in_vines = 0.1
	queue_redraw()


func _draw() -> void:
	var w := WIDTH / 2.0
	for s in _strands:
		var x: float = s.x
		var n: float = s.len
		var prev := Vector2(x, THICK / 2.0)
		var y := 8.0
		while y <= n:
			var sway := sin(_t * 1.6 + s.phase + y * 0.04) * 3.0 * (y / n)
			var pt := Vector2(x + sway, THICK / 2.0 + y)
			draw_line(prev, pt, VINE, 2.0)
			if int(y) % 16 == 0:
				draw_rect(Rect2(pt.x - 4.0, pt.y - 2.0, 4, 3), LEAF)
				draw_rect(Rect2(pt.x + 1.0, pt.y + 3.0, 4, 3), MOSS)
			prev = pt
			y += 8.0
	draw_rect(Rect2(-w, -THICK / 2.0, WIDTH, THICK), BODY)
	draw_rect(Rect2(-w, THICK / 2.0 - 3.0, WIDTH, 3), SHADE)
	draw_rect(Rect2(-w - 1.0, -THICK / 2.0 - 3.0, WIDTH + 2.0, 6), MOSS)
	var x := -w + 4.0
	while x < w - 4.0:
		draw_rect(Rect2(x, -THICK / 2.0 - 6.0, 3, 4), LEAF)
		x += 11.0
