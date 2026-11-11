class_name ScreenBorder
extends CanvasLayer
## A frame of rainbow 3D blocks around the whole screen, drawn above everything else.

const BLOCK := 10.0
const COLORS := [Color("ff5e5e"), Color("ffa94d"), Color("ffd43b"), Color("69db7c"),
	Color("4dabf7"), Color("b197fc")]

var _canvas: Control


func _ready() -> void:
	layer = 50
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_border)
	add_child(_canvas)
	get_viewport().size_changed.connect(_canvas.queue_redraw)


func _draw_border() -> void:
	var size := _canvas.size
	var n := 0
	# Walk around the edge clockwise so the rainbow flows all the way round.
	var cols := int(ceil(size.x / BLOCK))
	var rows := int(ceil(size.y / BLOCK))
	for i in cols:
		_block(Vector2(i * BLOCK, 0.0), n)
		n += 1
	for j in range(1, rows):
		_block(Vector2(size.x - BLOCK, j * BLOCK), n)
		n += 1
	for i in range(cols - 2, -1, -1):
		_block(Vector2(i * BLOCK, size.y - BLOCK), n)
		n += 1
	for j in range(rows - 2, 0, -1):
		_block(Vector2(0.0, j * BLOCK), n)
		n += 1


## One block: its color, a light top-left edge and a dark bottom-right edge.
func _block(p: Vector2, n: int) -> void:
	var c: Color = COLORS[(n / 2) % COLORS.size()]
	_canvas.draw_rect(Rect2(p, Vector2(BLOCK, BLOCK)), c)
	_canvas.draw_rect(Rect2(p, Vector2(BLOCK, 2)), c.lightened(0.45))
	_canvas.draw_rect(Rect2(p, Vector2(2, BLOCK)), c.lightened(0.3))
	_canvas.draw_rect(Rect2(p + Vector2(0, BLOCK - 2), Vector2(BLOCK, 2)), c.darkened(0.35))
	_canvas.draw_rect(Rect2(p + Vector2(BLOCK - 2, 0), Vector2(2, BLOCK)), c.darkened(0.25))
