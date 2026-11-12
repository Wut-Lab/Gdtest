class_name Checkpoint
extends Area2D
## A checkpoint (@ in a text map): a small stone pedestal with a glowing black cube on it.
## Touch it and the cube glows green; after that, falls send you back here instead of the start.
## It sits on the floor of its cell. Every level has one, roughly halfway through.

signal reached(checkpoint: Checkpoint)

const STONE := Color("8a93b8")
const STONE_LIGHT := Color("b4bbd6")
const STONE_DARK := Color("5a6380")
const EDGE := Color("1b2440")
const CUBE := Color("0b0d14")
const DARK_GLOW := Color("8a5cff")
const GREEN := Color("3ddc84")
const GREEN_LIGHT := Color("b6ffd4")

var active := false
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 40)
	col.shape = shape
	col.position = Vector2(0, -20)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not active:
		set_active(true)
		_flash = 1.0
		reached.emit(self)


## Lit (green) once reached; dark again for a new run.
func set_active(v: bool) -> void:
	active = v
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 1.5, 0.0)
	queue_redraw()


func _draw() -> void:
	# Pedestal: a wide base, a narrower column and a cap, in stone blocks.
	draw_rect(Rect2(-12, -6, 24, 6), EDGE)
	draw_rect(Rect2(-11, -5, 22, 5), STONE_DARK)
	draw_rect(Rect2(-8, -16, 16, 11), EDGE)
	draw_rect(Rect2(-7, -15, 14, 10), STONE)
	draw_rect(Rect2(-7, -15, 3, 10), STONE_LIGHT)
	draw_rect(Rect2(-11, -20, 22, 5), EDGE)
	draw_rect(Rect2(-10, -19, 20, 3), STONE_LIGHT)
	# The cube floats just above the cap, bobbing, with a pulsing glow around it.
	var bob := sin(_t * 2.2) * 1.5
	var c := Vector2(0, -30 + bob)
	var glow_color := GREEN if active else DARK_GLOW
	var pulse := 0.5 + 0.5 * sin(_t * (4.0 if active else 2.5))
	for i in 3:
		var r := 9.0 + i * 3.0 + pulse * 2.0
		draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0),
			Color(glow_color, (0.22 if active else 0.12) - i * 0.05))
	draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), EDGE)
	if active:
		draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), GREEN)
		draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 3)), GREEN_LIGHT)
		draw_rect(Rect2(c - Vector2(6, 6), Vector2(3, 12)), GREEN_LIGHT)
	else:
		draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), CUBE)
		draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 2)), Color(DARK_GLOW, 0.35 + pulse * 0.3))
	if _flash > 0.0:
		# A ring of green blocks bursting out when it lights up.
		for i in 8:
			var a := i * TAU / 8.0
			var p := c + Vector2(cos(a), sin(a)) * (10.0 + (1.0 - _flash) * 26.0)
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(GREEN_LIGHT, _flash))
