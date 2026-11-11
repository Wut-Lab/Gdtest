class_name PixelCounter
extends HBoxContainer
## The pixel count in the top-right corner: a little 2×2 pixel icon and a number.
## Pixels are the game's currency (nothing to spend them on yet).

var _icon: Control
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(18, 18)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.draw.connect(func() -> void: draw_icon(_icon, Vector2.ZERO, 7.0))
	add_child(_icon)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)


func set_pixels(n: int) -> void:
	_label.text = str(n)


## A pixel: four colored blocks with a dark edge, s px per block, top-left at o.
static func draw_icon(ci: CanvasItem, o: Vector2, s: float) -> void:
	ci.draw_rect(Rect2(o, Vector2(s * 2.0 + 4.0, s * 2.0 + 4.0)), Color("1b2440"))
	var colors := [Color("ff6b5e"), Color("79e2c2"), Color("4da3ff"), Color("f2c230")]
	for i in 4:
		ci.draw_rect(Rect2(o + Vector2(2.0 + (i % 2) * s, 2.0 + (i / 2) * s), Vector2(s, s)), colors[i])
