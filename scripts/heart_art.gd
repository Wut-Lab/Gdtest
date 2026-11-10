class_name HeartArt
extends RefCounted
## A blocky pixel heart in the same flat, square style as the tiles: a light top-left lip,
## a solid body and a darker lower-right edge. Used by the HUD and the heart pickup.

const BODY := Color("f2545b")
const LIGHT := Color("ff9aa2")
const SHADE := Color("a8323a")
const EMPTY := Color(0.067, 0.09, 0.169, 0.55)
const EMPTY_EDGE := Color(0.933, 0.945, 0.98, 0.3)

## L = light, B = body, S = shade. 7 blocks wide, 6 tall.
const PATTERN := [
	".LB.BB.",
	"LBBBBBS",
	"BBBBBBS",
	".BBBBS.",
	"..BBS..",
	"...S...",
]


static func size(block: float) -> Vector2:
	return Vector2(7, 6) * block


## Draws a heart with its top-left corner at `pos`. An empty heart is a dark slot with a
## faint rim, so lost hearts still show how many you had.
static func draw(canvas: CanvasItem, pos: Vector2, block: float, full := true) -> void:
	for y in PATTERN.size():
		var row: String = PATTERN[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var c := EMPTY
			if full:
				c = LIGHT if ch == "L" else (SHADE if ch == "S" else BODY)
			elif ch != "B":
				c = EMPTY_EDGE
			canvas.draw_rect(Rect2(pos + Vector2(x, y) * block, Vector2(block, block)), c)
