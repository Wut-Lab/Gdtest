class_name ColorWheel
extends Control
## A touch-friendly color wheel. The angle around the wheel picks the hue; the distance from
## the center picks how vivid the color is (center = white). Tap or drag anywhere on it.
## Brightness is set separately (see `value`), which darkens the whole wheel to match.

signal changed

const TEXTURE_SIZE := 192

var hue := 0.0
var saturation := 0.0
var value := 1.0:
	set(v):
		value = v
		queue_redraw()

var _wheel: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wheel = _make_wheel()


func set_hsv(h: float, s: float, v: float) -> void:
	hue = h
	saturation = s
	value = v
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) / 2.0 - 2.0


func _center() -> Vector2:
	return size / 2.0


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT
	var dragged: bool = event is InputEventMouseMotion \
		and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if pressed or dragged:
		_pick(event.position)
		accept_event()


func _pick(pos: Vector2) -> void:
	var v := pos - _center()
	hue = fposmod(v.angle() / TAU, 1.0)
	saturation = clampf(v.length() / _radius(), 0.0, 1.0)
	queue_redraw()
	changed.emit()


func _draw() -> void:
	var r := _radius()
	var c := _center()
	# The wheel, darkened by the brightness setting.
	draw_texture_rect(_wheel, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
		Color(value, value, value))
	# Marker: a ring showing the picked spot, filled with the picked color.
	var at := c + Vector2.from_angle(hue * TAU) * saturation * r
	draw_circle(at, 9.0, Color.from_hsv(hue, saturation, value))
	draw_arc(at, 9.0, 0.0, TAU, 24, Color.WHITE, 2.5, true)
	draw_arc(at, 11.5, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.5, true)


## Builds the wheel image once: hue by angle, saturation by distance, soft edge.
func _make_wheel() -> ImageTexture:
	var n := TEXTURE_SIZE
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var half := n / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half)
			var dist := d.length() / half
			if dist > 1.0:
				continue
			var col := Color.from_hsv(fposmod(d.angle() / TAU, 1.0), dist, 1.0)
			col.a = clampf((1.0 - dist) * half, 0.0, 1.0)   # anti-aliased rim
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
