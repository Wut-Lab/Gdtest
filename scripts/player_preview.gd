class_name PlayerPreview
extends Control
## The player's square, drawn large in their color, for menus.

var color := Color("ff6b5e"):
	set(v):
		color = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(56, 56)


func _draw() -> void:
	var s := 44.0
	var o := (size - Vector2(s, s)) / 2.0
	draw_rect(Rect2(o, Vector2(s, s)), color)
	var eyes := Color("1b2440") if color.get_luminance() > 0.3 else Color("eef1fa")
	draw_rect(Rect2(o + Vector2(s / 2.0 + 2, s * 0.3), Vector2(5, 9)), eyes)
	draw_rect(Rect2(o + Vector2(s / 2.0 + 12, s * 0.3), Vector2(5, 9)), eyes)
