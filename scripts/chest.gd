class_name Chest
extends Area2D
## A treasure chest (C in a text map). Touch it to open it: it holds a card (20%) or 2–10 pixels.
## Main decides what's inside and remembers opened chests in the save file, so each chest
## pays out once. It sits on the floor of its cell.

signal opened(chest: Chest)

const OUTLINE := Color("3b2716")
const WOOD := Color("9c6b3f")
const WOOD_DARK := Color("6e4626")
const WOOD_LIGHT := Color("c48a52")
const METAL := Color("d9deef")
const METAL_SHADE := Color("8a93b8")
const GOLD := Color("f2c230")
const GOLD_SHADE := Color("b8860b")
const INSIDE := Color("24160b")

var is_open := false
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 22)
	col.shape = shape
	col.position = Vector2(0, -11)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_open:
		set_open(true)
		_flash = 1.0
		opened.emit(self)


## Shows it open (already looted) or closed.
func set_open(v: bool) -> void:
	is_open = v
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0 or not is_open:
		_flash = maxf(_flash - delta * 1.2, 0.0)
		queue_redraw()


func _draw() -> void:
	draw_chest(self, Vector2.ZERO, is_open, _t)
	if _flash > 0.0:
		# A burst of light blocks rising out of the chest.
		for i in 6:
			var x := -10.0 + i * 4.0
			var y := -14.0 - (1.0 - _flash) * (18.0 + (i % 3) * 8.0)
			draw_rect(Rect2(x, y, 3, 3), Color(GOLD, _flash))


## Draws a chest whose bottom center is at o (26×22 closed). Shared with menus.
static func draw_chest(ci: CanvasItem, o: Vector2, open: bool, t := 0.0) -> void:
	# Body: outline, wood, a plank line and a dark base.
	ci.draw_rect(Rect2(o + Vector2(-13, -12), Vector2(26, 12)), OUTLINE)
	ci.draw_rect(Rect2(o + Vector2(-12, -11), Vector2(24, 10)), WOOD)
	ci.draw_rect(Rect2(o + Vector2(-12, -6), Vector2(24, 1)), WOOD_DARK)
	ci.draw_rect(Rect2(o + Vector2(-12, -3), Vector2(24, 2)), WOOD_DARK)
	if open:
		# Lid flipped up behind, dark inside showing.
		ci.draw_rect(Rect2(o + Vector2(-13, -27), Vector2(26, 8)), OUTLINE)
		ci.draw_rect(Rect2(o + Vector2(-12, -26), Vector2(24, 6)), WOOD_DARK)
		ci.draw_rect(Rect2(o + Vector2(-12, -26), Vector2(24, 2)), WOOD)
		ci.draw_rect(Rect2(o + Vector2(-13, -20), Vector2(26, 9)), OUTLINE)
		ci.draw_rect(Rect2(o + Vector2(-12, -19), Vector2(24, 8)), INSIDE)
	else:
		# Lid: lighter wood with a highlight along the top, a dark seam under it.
		ci.draw_rect(Rect2(o + Vector2(-13, -22), Vector2(26, 11)), OUTLINE)
		ci.draw_rect(Rect2(o + Vector2(-12, -21), Vector2(24, 9)), WOOD)
		ci.draw_rect(Rect2(o + Vector2(-12, -21), Vector2(24, 2)), WOOD_LIGHT)
		ci.draw_rect(Rect2(o + Vector2(-12, -12), Vector2(24, 1)), OUTLINE)
	# Metal bands on both sides, top to bottom.
	var top := -26.0 if open else -21.0
	for bx in [-10.0, 7.0]:
		ci.draw_rect(Rect2(o + Vector2(bx, top), Vector2(3, -1.0 - top)), METAL)
		ci.draw_rect(Rect2(o + Vector2(bx + 2.0, top), Vector2(1, -1.0 - top)), METAL_SHADE)
	if open:
		ci.draw_rect(Rect2(o + Vector2(-12, -19), Vector2(24, 8)), INSIDE)
	# Gold lock on the front, with a keyhole. A soft twinkle while closed.
	ci.draw_rect(Rect2(o + Vector2(-3, -14), Vector2(6, 6)), GOLD)
	ci.draw_rect(Rect2(o + Vector2(-3, -9), Vector2(6, 1)), GOLD_SHADE)
	ci.draw_rect(Rect2(o + Vector2(-1, -12), Vector2(2, 3)), OUTLINE)
	if not open and fmod(t, 2.4) < 0.25:
		ci.draw_rect(Rect2(o + Vector2(2, -15), Vector2(2, 2)), Color.WHITE)
