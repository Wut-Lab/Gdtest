class_name TouchKey
extends Node2D
## How an on-screen button looks: a chunky 3D block key, centered on its button.
## Pressing it sinks the key face into its base and sends out a ring; letting go pops it back.

const DEPTH := 6.0
const OUTLINE := Color("05070d")
const INK := Color("eef1fa")

var key_size := Vector2(76, 70)
var label := ""
var arrow := 0.0            # -1 left, 1 right, 0 none
var face := Color("2a3354")
var text_color := INK
var pressed := false

var _press := 0.0           # 0 up, 1 fully sunk (eased toward pressed each frame)
var _ring := 0.0            # 1 right after a press, fades to 0


func press(on: bool) -> void:
	if on and not pressed:
		_ring = 1.0
	pressed = on


func _process(delta: float) -> void:
	var target := 1.0 if pressed else 0.0
	_press = move_toward(_press, target, delta * (14.0 if pressed else 8.0))
	_ring = maxf(_ring - delta * 2.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var half := key_size / 2.0
	var top := -half.y + DEPTH * _press
	# Ring that grows out of the key when it's pressed.
	if _ring > 0.0:
		var grow := (1.0 - _ring) * 14.0
		var r := Rect2(-half - Vector2(grow, grow), key_size + Vector2(grow, grow) * 2.0)
		draw_rect(r, Color(face.lightened(0.4), _ring * 0.6), false, 3.0)
	# Base (the key's side), then the face on top of it.
	draw_rect(Rect2(-half - Vector2(2, 2), key_size + Vector2(4, 4)), OUTLINE)
	draw_rect(Rect2(-half.x, -half.y + DEPTH, key_size.x, key_size.y - DEPTH), face.darkened(0.45))
	var f := face.darkened(0.12 * _press)
	draw_rect(Rect2(-half.x, top, key_size.x, key_size.y - DEPTH), f)
	draw_rect(Rect2(-half.x, top, key_size.x, 4.0), f.lightened(0.25))
	draw_rect(Rect2(-half.x, top, 4.0, key_size.y - DEPTH), f.lightened(0.12))
	var mid := Vector2(0.0, top + (key_size.y - DEPTH) / 2.0)
	if arrow != 0.0:
		# A blocky arrow: rows of 5 px blocks narrowing to a point.
		for i in 4:
			var h := (4 - i) * 5.0
			var x := mid.x + arrow * (i * 5.0 - 8.0)
			draw_rect(Rect2(x - 2.5, mid.y - h, 5.0, h * 2.0), text_color)
	elif label != "":
		var font := ThemeDB.fallback_font
		var fs := 17
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, mid + Vector2(-w / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
