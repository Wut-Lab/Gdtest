class_name Water
extends Node2D
## A pond: "~" cells in a level map. Drawn a little see-through in front of everything, darker the
## deeper it goes, with a wavy bright surface. Two blocky fish swim back and forth inside it
## (a placeholder for fishing later). The player floats in it (see Player._swim).

const T := 32
const SHALLOW := Color(0.36, 0.66, 0.95, 0.62)
const DEEP := Color(0.13, 0.33, 0.70, 0.78)
const FISH_COLORS := [[Color("ff8a3d"), Color("ffd23f")], [Color("e84393"), Color("4ad6c4")]]

## Cell -> depth below the surface (0 = the top row of water).
var _depth := {}
## Column -> y of the water surface (pixels).
var _surface := {}
var _t := 0.0
var _fish: Array[Dictionary] = []


func _init() -> void:
	z_index = 5


func setup(cells: Array[Vector2i]) -> void:
	_depth.clear()
	_surface.clear()
	_fish.clear()
	for c in cells:
		if not _surface.has(c.x) or c.y * T < _surface[c.x]:
			_surface[c.x] = c.y * T
	for c in cells:
		_depth[c] = c.y - int(_surface[c.x] / T)
	if cells.is_empty():
		queue_redraw()   # clear the last map's pond (levels have no water)
		return
	var xs := _surface.keys()
	xs.sort()
	var left: float = xs[0] * T + 14.0
	var right: float = (xs[-1] + 1) * T - 14.0
	var top: float = _surface.values().min()
	# Two fish in the deeper middle, swimming at different speeds and depths.
	_fish.append({"y": top + 1.6 * T, "left": left + T, "right": right - 2 * T, "speed": 0.45, "phase": 0.0, "i": 0})
	_fish.append({"y": top + 2.7 * T, "left": left + 2 * T, "right": right - 4 * T, "speed": 0.3, "phase": 2.0, "i": 1})
	queue_redraw()


func is_empty() -> bool:
	return _depth.is_empty()


## The water surface over [param x], or INF where there's no water.
func surface_at(x: float) -> float:
	return _surface.get(int(floor(x / T)), INF)


func _process(delta: float) -> void:
	if _depth.is_empty():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var max_d := 1
	for c in _depth:
		max_d = maxi(max_d, _depth[c])
	for c in _depth:
		var k := clampf(float(_depth[c]) / maxf(max_d - 1, 1), 0.0, 1.0)
		draw_rect(Rect2(c.x * T, c.y * T, T, T), SHALLOW.lerp(DEEP, k))
	for f in _fish:
		_draw_fish(f)
	# A wavy surface line along the top.
	for x in _surface:
		var y: float = _surface[x]
		for i in 4:
			var px: float = x * T + i * 8
			var wy := y + 2.0 * sin(_t * 2.5 + px * 0.08)
			draw_rect(Rect2(px, wy - 1, 8, 3), Color(0.8, 0.93, 1.0, 0.85))


func _draw_fish(f: Dictionary) -> void:
	var span: float = f.right - f.left
	var s: float = sin(_t * f.speed + f.phase)
	var x: float = f.left + span * (0.5 + 0.5 * s)
	var dir := 1.0 if cos(_t * f.speed + f.phase) >= 0.0 else -1.0
	var y: float = f.y + 3.0 * sin(_t * 1.7 + f.phase)
	var cols: Array = FISH_COLORS[f.i]
	var edge := Color("1b2440")
	# Body, a stripe, a square tail and a dot eye, all blocky.
	draw_rect(Rect2(x - 11, y - 7, 22, 14), edge)
	draw_rect(Rect2(x - 10, y - 6, 20, 12), cols[0])
	draw_rect(Rect2(x - 2, y - 6, 4, 12), cols[1])
	var tail_x := x - dir * 11 - (6 if dir > 0 else 0)
	var wag := 2.0 * sin(_t * 8.0 + f.phase)
	draw_rect(Rect2(tail_x, y - 5 + wag, 6, 10), edge)
	draw_rect(Rect2(tail_x + 1, y - 4 + wag, 4, 8), cols[1])
	draw_rect(Rect2(x + dir * 6 - 1.5, y - 3, 3, 3), edge)
