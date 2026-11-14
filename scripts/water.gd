class_name Water
extends Node2D
## Water in a level map. Three kinds of cell:
##   ~  still water (ponds and lakes): see-through, darker the deeper it goes, with a wavy
##      bright surface. The player floats in it (see Player._swim).
##   < >  a shallow river running left / right along the top of a floor or platform. It doesn't
##      hold you up, but it carries you (and you can be pushed into things).
##   |  a waterfall where a river pours off an edge: it pushes you down while you're in it.
## In town (fish = true), every pond gets blocky fish swimming back and forth (a placeholder for
## fishing later).

const T := 32
const SHALLOW := Color(0.36, 0.66, 0.95, 0.62)
const DEEP := Color(0.13, 0.33, 0.70, 0.78)
const RIVER := Color(0.3, 0.62, 0.95, 0.6)
const FALL := Color(0.62, 0.82, 1.0, 0.5)
const FOAM := Color(0.85, 0.95, 1.0, 0.85)
const FISH_COLORS := [[Color("ff8a3d"), Color("ffd23f")], [Color("e84393"), Color("4ad6c4")],
	[Color("6fd36b"), Color("f2e27a")]]
## How deep a river is drawn, from the bottom of its cell.
const RIVER_DEPTH := 14.0
## How fast running water carries you, in pixels per second.
const FLOW_SPEED := 130.0
## Extra downward pull inside a waterfall.
const FALL_PULL := 1400.0

## Still water: cell -> depth below its pond's surface (0 = the top row).
var _depth := {}
## Column -> Array of [top_y, bottom_y] spans of still water (pixels), top to bottom.
var _spans := {}
## River cells -> flow direction (-1 or 1).
var _river := {}
## Waterfall cells.
var _falls := {}
## Each waterfall as one piece: {"x", "y0", "y1" (pixels), "side" (-1/1: which way it pours,
## or 0 if no river feeds it), "edge" (x of the block edge it pours off)}.
var _fall_runs: Array[Dictionary] = []
## The ponds: Array of {"x0", "x1" (pixels), "top", "bottom", "cells"}.
var _bodies: Array[Dictionary] = []
var _t := 0.0
var _fish: Array[Dictionary] = []


func _init() -> void:
	z_index = 5


## cells: cell -> "~", "<", ">" or "|". With fish, every pond 3+ tiles wide and 2 deep gets some.
func setup(cells: Dictionary, fish := false) -> void:
	_depth.clear()
	_spans.clear()
	_river.clear()
	_falls.clear()
	_fall_runs.clear()
	_bodies.clear()
	_fish.clear()
	var still := {}
	for c in cells:
		match cells[c]:
			"~":
				still[c] = true
			"<":
				_river[c] = -1
			">":
				_river[c] = 1
			"|":
				_falls[c] = true
	for c in _falls:
		if _falls.has(c + Vector2i.UP):
			continue
		var bottom: Vector2i = c
		while _falls.has(bottom + Vector2i.DOWN):
			bottom += Vector2i.DOWN
		var side := 0
		if _river.get(c + Vector2i.LEFT, 0) == 1:
			side = 1
		elif _river.get(c + Vector2i.RIGHT, 0) == -1:
			side = -1
		var edge: int = c.x * T if side >= 0 else (c.x + 1) * T
		var y0: float = c.y * T + (T - RIVER_DEPTH if side != 0 else 0.0)
		_fall_runs.append({"x": c.x * T, "y0": y0, "y1": (bottom.y + 1) * T, "side": side, "edge": edge})
	# Ponds: still cells joined side to side or up and down.
	var seen := {}
	for c in still:
		if seen.has(c):
			continue
		var body: Array[Vector2i] = []
		var todo: Array[Vector2i] = [c]
		seen[c] = true
		while not todo.is_empty():
			var cur: Vector2i = todo.pop_back()
			body.append(cur)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = cur + d
				if still.has(n) and not seen.has(n):
					seen[n] = true
					todo.append(n)
		var x0 := body[0].x
		var x1 := body[0].x
		var top := body[0].y
		var bottom := body[0].y
		for b in body:
			x0 = mini(x0, b.x)
			x1 = maxi(x1, b.x)
			top = mini(top, b.y)
			bottom = maxi(bottom, b.y)
		for b in body:
			_depth[b] = b.y - top
		_bodies.append({"x0": x0 * T, "x1": (x1 + 1) * T, "top": top * T, "bottom": (bottom + 1) * T,
			"cells": body})
	# Spans per column, for floating.
	for c in still:
		var col: Array = _spans.get(c.x, [])
		var merged := false
		for s in col:
			if c.y * T == s[1]:
				s[1] = (c.y + 1) * T
				merged = true
			elif (c.y + 1) * T == s[0]:
				s[0] = c.y * T
				merged = true
		if not merged:
			col.append([c.y * T, (c.y + 1) * T])
		_spans[c.x] = col
	for x in _spans:
		_spans[x].sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if fish:
		var i := 0
		for b in _bodies:
			var w: float = b.x1 - b.x0
			var deep: float = b.bottom - b.top
			if w < 3 * T or deep < 2 * T:
				continue
			var n := 2 if w >= 8 * T else 1
			for k in n:
				_fish.append({"y": b.top + (1.6 + k * 1.1) * T if deep >= 3 * T else b.top + 1.3 * T,
					"left": b.x0 + T * (1.0 + k), "right": b.x1 - T * (1.5 + k * 2.0),
					"speed": 0.45 - 0.15 * k, "phase": 2.0 * k + i, "i": (i + k) % FISH_COLORS.size()})
			i += 1
	queue_redraw()


func is_empty() -> bool:
	return _depth.is_empty() and _river.is_empty() and _falls.is_empty()


## The still-water ponds: Array of {"x0", "x1", "top", "bottom", "cells"} (pixels).
func bodies() -> Array[Dictionary]:
	return _bodies


## The top of the still water a body spanning [top_y, bottom_y] at x is touching, or INF.
func surface_near(x: float, top_y: float, bottom_y: float) -> float:
	for s in _spans.get(int(floor(x / T)), []):
		if bottom_y > s[0] and top_y < s[1]:
			return s[0]
	return INF


## The water surface over [param x] (the highest pond there), or INF where there's none.
func surface_at(x: float) -> float:
	var col: Array = _spans.get(int(floor(x / T)), [])
	return col[0][0] if not col.is_empty() else INF


## Running water at this point: -1 or 1 (its direction), 0 if none.
func flow_at(pos: Vector2) -> int:
	var c := Vector2i(int(floor(pos.x / T)), int(floor(pos.y / T)))
	if _river.has(c) and fposmod(pos.y, T) >= T - RIVER_DEPTH - 6.0:
		return _river[c]
	return 0


func in_fall(pos: Vector2) -> bool:
	return _falls.has(Vector2i(int(floor(pos.x / T)), int(floor(pos.y / T))))


## Every river and waterfall cell, for enemies that live in them.
func river_cells() -> Dictionary:
	return _river


func _process(delta: float) -> void:
	if is_empty():
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
	# A wavy surface line along the top of each pond column.
	for x in _spans:
		for s in _spans[x]:
			if _depth.get(Vector2i(x, int(s[0] / T)), 1) != 0:
				continue
			var y: float = s[0]
			for i in 4:
				var px: float = x * T + i * 8
				var wy := y + 2.0 * sin(_t * 2.5 + px * 0.08)
				draw_rect(Rect2(px, wy - 1, 8, 3), Color(0.8, 0.93, 1.0, 0.85))
	# Rivers: shallow bands with streaks sliding the way they run.
	for c in _river:
		var x: float = c.x * T
		var top: float = (c.y + 1) * T - RIVER_DEPTH
		draw_rect(Rect2(x, top, T, RIVER_DEPTH), RIVER)
		var dir: int = _river[c]
		for i in 2:
			var sx := fposmod(x + i * 16.0 + dir * _t * FLOW_SPEED * 0.6, T)
			draw_rect(Rect2(x + sx, top + 4 + i * 4, minf(9.0, T - sx), 2), FOAM)
		draw_rect(Rect2(x, top - 1 + sin(_t * 4.0 + x * 0.1), T, 2), FOAM)
	for f in _fall_runs:
		_draw_fall(f)


## A waterfall: the river rolls over the block edge in a smooth curve, then falls as one
## curtain that bows out a little as it drops, with streaks sliding down and foam at the bottom.
func _draw_fall(f: Dictionary) -> void:
	var side: int = f.side
	var y0: float = f.y0
	var y1: float = f.y1
	var w := 18.0
	var step := 3.0
	var y := y0
	var prev := Vector2.ZERO
	var first := true
	while y < y1:
		var drop := y - y0
		# Pours off the edge in an arc: out quickly at first, then nearly straight down.
		var out := (minf(sqrt(drop) * 1.6, 10.0) if side != 0 else 7.0)
		var left: float = f.edge + out if side >= 0 else f.edge - out - w
		if side == 0:
			left = f.x + (T - w) / 2.0
		var hgt := minf(step, y1 - y)
		draw_rect(Rect2(left, y, w, hgt + 0.5), FALL)
		draw_rect(Rect2(left + w * 0.3, y, w * 0.4, hgt + 0.5), Color(0.8, 0.92, 1.0, 0.35))   # bright core
		if first:
			prev = Vector2(left, y)
			first = false
		y += step
	# The lip: the river's surface curving over the edge into the curtain.
	if side != 0:
		var e: float = f.edge
		var pts := PackedVector2Array()
		for i in 7:
			var a := float(i) / 6.0
			pts.append(Vector2(e - side * 6.0 + side * a * 16.0, y0 - 2.0 + a * a * 10.0))
		draw_polyline(pts, FOAM, 2.5)
	# Streaks sliding down the whole curtain.
	var length := y1 - y0
	for i in 4:
		var sy := fposmod(i * 23.0 + _t * 240.0, maxf(length, 1.0))
		var d := sy
		var out2 := (minf(sqrt(d) * 1.6, 10.0) if side != 0 else 7.0)
		var lx: float = (f.edge + out2 if side >= 0 else f.edge - out2 - w) if side != 0 else f.x + (T - w) / 2.0
		draw_rect(Rect2(lx + 3 + i * 4, y0 + sy, 2, minf(12.0, length - sy)), FOAM)
	# Foam where it lands.
	var out_end := 10.0 if side != 0 else 7.0
	var bx: float = (f.edge + out_end if side >= 0 else f.edge - out_end - w) if side != 0 else f.x + (T - w) / 2.0
	for i in 5:
		var r := 3.0 + 2.0 * sin(_t * 9.0 + i * 1.7)
		draw_circle(Vector2(bx - 3 + i * 6, y1 - 4 - r * 0.5), r, Color(FOAM, 0.75))


func _draw_fish(f: Dictionary) -> void:
	var span: float = maxf(f.right - f.left, 1.0)
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
