class_name CrumbleBlock
extends AnimatableBody2D
## Mossy Cave: a cracked, mossy stone you can stand on (and jump up through, like a floating
## platform). Step on it and it shakes for a moment, then crumbles away; it grows back a few
## seconds later.

const SIZE := 32.0
## How long it holds after you land on it, and how long until it's back.
const HOLD := 0.6
const REGROW := 3.0
const EDGE := Color("1b2440")

var _shake := -1.0      # counting up while it shakes; -1 when still
var _gone := 0.0        # seconds left until it grows back
var _col: CollisionShape2D
var _t := 0.0


func _ready() -> void:
	sync_to_physics = false
	_col = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	_col.shape = shape
	_col.one_way_collision = true
	add_child(_col)
	# Feet on top start the crumble.
	var feet := Area2D.new()
	var fs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(SIZE - 4.0, 6.0)
	fs.shape = r
	fs.position = Vector2(0, -SIZE / 2.0 - 3.0)
	feet.add_child(fs)
	feet.body_entered.connect(func(b: Node2D) -> void:
		if b is Player and _shake < 0.0 and _gone == 0.0 and b.velocity.y >= 0.0:
			_shake = 0.0)
	add_child(feet)


func reset() -> void:
	_shake = -1.0
	_gone = 0.0
	_col.set_deferred("disabled", false)
	show()


func _physics_process(delta: float) -> void:
	_t += delta
	if _gone > 0.0:
		_gone = maxf(_gone - delta, 0.0)
		if _gone == 0.0:
			reset()
	elif _shake >= 0.0:
		_shake += delta
		if _shake >= HOLD:
			_shake = -1.0
			_gone = REGROW
			_col.set_deferred("disabled", true)
			hide()
	queue_redraw()


func _draw() -> void:
	var o := Vector2(randf_range(-1.5, 1.5), 0) if _shake >= 0.0 else Vector2.ZERO
	var h := SIZE / 2.0
	draw_rect(Rect2(o + Vector2(-h, -h), Vector2(SIZE, SIZE)), EDGE)
	draw_rect(Rect2(o + Vector2(-h + 2, -h + 2), Vector2(SIZE - 4, SIZE - 4)), Color("6f7a6a"))
	draw_rect(Rect2(o + Vector2(-h + 2, -h + 2), Vector2(SIZE - 4, 4)), Color("5fa84a"))   # moss on top
	draw_rect(Rect2(o + Vector2(-h + 4, -h + 6), Vector2(5, 3)), Color("5fa84a"))
	draw_rect(Rect2(o + Vector2(h - 10, -h + 6), Vector2(4, 4)), Color("4b8a3a"))
	# Cracks, which widen as it shakes.
	var k := 1.0 + (2.0 * _shake / HOLD if _shake >= 0.0 else 0.0)
	draw_polyline(PackedVector2Array([o + Vector2(-4, -6), o + Vector2(0, 2), o + Vector2(-3, 8), o + Vector2(2, 14)]), EDGE, k)
	draw_polyline(PackedVector2Array([o + Vector2(0, 2), o + Vector2(8, 4), o + Vector2(10, 12)]), EDGE, k)
