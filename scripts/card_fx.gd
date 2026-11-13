class_name CardFx
extends Node2D
## Short card effects drawn in blocks, freed when done.
##   "shock": a Shockwave rolling out both ways along the floor.
##   "zap":   a Stunning Landing burst of electric sparks at the feet.
##   "slow":  a Slow Burst ring spreading out to the edge of its square.
##   "pop":   a squashed Bad Block bursting into little red blocks.
##   "plus":  floating "+N" text for pixels from a broken obstacle (set `text`).
##   "lucky": a Lucky Charm gold ring and sparkles when a hit is shrugged off.

const SHOCK := Color("ffd9a0")
const SPARK := Color("ffe27a")
const SPARK_2 := Color("9ff3ff")
const LUCKY := Color("f2c230")
const SLOW := Color("8fb8ff")

var kind := "zap"
## Shockwave reach in pixels.
var reach := 160.0
var text := ""
var _age := 0.0
var _life := 0.35
var _bolts: Array = []
var _next_bolts := 0.0


static func spawn(parent: Node, at: Vector2, fx_kind: String, fx_reach := 160.0, fx_text := "") -> void:
	var fx := CardFx.new()
	fx.kind = fx_kind
	fx.reach = fx_reach
	fx.text = fx_text
	fx._life = {"shock": 0.4, "lucky": 0.5, "slow": 0.45, "pop": 0.4, "plus": 0.8}.get(fx_kind, 0.35)
	fx.z_index = 5
	parent.add_child(fx)
	fx.global_position = at


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_next_bolts -= delta
	if kind == "zap" and _next_bolts <= 0.0:
		_next_bolts = 0.05   # re-roll the bolts so they flicker
		_bolts = []
		for i in 5:
			var a := -PI + (i + randf_range(0.2, 0.8)) * PI / 5.0   # fan upward from the feet
			_bolts.append(bolt(Vector2.ZERO, Vector2(cos(a), sin(a)) * randf_range(16.0, 26.0)))
	queue_redraw()


## Shockwave: how many px (sign included) a body of half-size `half` at `at` can slide sideways,
## trying `tiles` tiles first and fewer if a wall is in the way. 0 if blocked.
static func clear_shift(body: PhysicsBody2D, at: Vector2, half: Vector2, dir: float, tiles := 2) -> float:
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0 - Vector2(6.0, 6.0)   # a bit smaller, so the floor it sits on doesn't count
	q.shape = shape
	q.exclude = [body.get_rid()]
	q.collision_mask = body.collision_mask
	var space := body.get_world_2d().direct_space_state
	for n in range(tiles, 0, -1):
		var clear := true
		for i in range(1, n + 1):   # every tile it slides through must be open
			q.transform = Transform2D(0.0, at + Vector2(dir * i * 32.0, 0.0))
			for hit in space.intersect_shape(q, 4):
				if not hit.collider is Player:
					clear = false
		if clear:
			return dir * n * 32.0
	return 0.0


## Electric sparks crackling over a box of half-size `half`, re-rolled by the caller.
static func stun_bolts(half: Vector2) -> Array:
	return [bolt(Vector2(-half.x, randf_range(-half.y, half.y)), Vector2(half.x, randf_range(-half.y, half.y)), 5),
		bolt(Vector2(randf_range(-half.x, half.x), -half.y), Vector2(randf_range(-half.x, half.x), half.y), 5)]


## Draws stun sparks, blinking in the last second.
static func draw_stun(ci: CanvasItem, bolts: Array, stun_left: float) -> void:
	if stun_left > 1.0 or fmod(stun_left, 0.2) < 0.12:
		for i in bolts.size():
			ci.draw_polyline(bolts[i], SPARK if i == 0 else SPARK_2, 2.0)


## Slowed look: a pale blue tint with a little clock hand ticking slowly round.
static func draw_slow(ci: CanvasItem, half: Vector2, slow_left: float) -> void:
	ci.draw_rect(Rect2(-half, half * 2.0), Color(SLOW, 0.25))
	var a := slow_left * 2.0
	ci.draw_line(Vector2.ZERO, Vector2(sin(a), -cos(a)) * minf(half.x, half.y) * 0.8, Color(SLOW, 0.9), 2.0)


## A jagged line from a to b as a list of points.
static func bolt(a: Vector2, b: Vector2, steps := 4) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var n := (b - a).orthogonal().normalized()
	for i in range(1, steps):
		pts.append(a.lerp(b, float(i) / steps) + n * randf_range(-4.0, 4.0))
	pts.append(b)
	return pts


func _draw() -> void:
	var k := _age / _life
	if kind == "shock":
		# Two blocky crests sliding outward, shrinking as they go.
		var x := reach * k
		var h := 14.0 * (1.0 - k) + 2.0
		var c := Color(SHOCK, 1.0 - k)
		for side in [-1.0, 1.0]:
			for i in 3:
				var bx: float = side * (x - i * 6.0)
				var bh := h * (1.0 - i * 0.3)
				draw_rect(Rect2(bx - 3.0, -bh, 6.0, bh), c)
		draw_rect(Rect2(-x, -2.0, x * 2.0, 2.0), Color(SHOCK, 0.5 * (1.0 - k)))
	elif kind == "pop":
		for i in 8:
			var a := i * TAU / 8.0
			var p := Vector2(cos(a), sin(a)) * (6.0 + 26.0 * k) + Vector2(0, 30.0 * k * k)
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("e5484d", 1.0 - k))
	elif kind == "plus":
		var font := ThemeDB.fallback_font
		var p := Vector2(-12.0, -20.0 - 24.0 * k)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color("1b2440", 1.0 - k))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(LUCKY, 1.0 - k))
	elif kind == "slow":
		# A pale blue square outline growing out to the edge of the slowed area.
		var r := reach * (0.3 + 0.7 * k)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(SLOW, 0.8 * (1.0 - k)), false, 3.0)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(SLOW, 0.12 * (1.0 - k)))
	elif kind == "lucky":
		# A gold square ring growing out from you, with four sparkles flying off its corners.
		var r := 14.0 + 22.0 * k
		var c := Color(LUCKY, 1.0 - k)
		draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), c, false, 3.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var p: Vector2 = d * (r + 6.0)
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, 1.0 - k))
	else:
		var c1 := Color(SPARK, 1.0 - k * 0.6)
		var c2 := Color(SPARK_2, 1.0 - k * 0.6)
		for i in _bolts.size():
			draw_polyline(_bolts[i], c1 if i % 2 == 0 else c2, 2.0)


## How far (px) a pacing obstacle may go in direction dir (-1/1), up to max_tiles, so it stops
## with at least one free floor tile between it and the platform's edge (somewhere to land).
## half_tiles: tiles from its centre to its outer edge cell (0 for 1-wide, 1 for 3-wide).
## Obstacles not standing on floor (floating bridges) keep their full reach.
static func pace_reach(body: PhysicsBody2D, at: Vector2, dir: float, max_tiles: int, half_tiles := 0) -> float:
	var space := body.get_world_2d().direct_space_state
	var floor_at := func(x: float) -> bool:
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, at.y), Vector2(x, at.y + 32.0), 1)
		q.exclude = [body.get_rid()]
		return not space.intersect_ray(q).is_empty()
	if not floor_at.call(at.x):
		return max_tiles * 32.0
	var k := 0
	while k < max_tiles:
		var ok := true
		for c in range(half_tiles + 1, half_tiles + 3):   # its new outer cell + one spare tile
			if not floor_at.call(at.x + dir * (k + c) * 32.0):
				ok = false
		if not ok:
			break
		k += 1
	return k * 32.0
