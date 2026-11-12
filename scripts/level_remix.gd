class_name LevelRemix
extends RefCounted
## Replay Room remixes of a random level's text map:
##   hard:     every Bad Block becomes a Hard Bad Block (k: faster, sees farther, horned) and
##             more Hard Bad Blocks are added on flat ground away from the start, goal and checkpoint.
##   scramble: the start and goal move to random spots you can stand on, at least half the
##             level apart (across for wide levels, up for tall ones, both added up for diagonal).

const FLOOR := "#="


static func _grid(text: String) -> Array:
	var g: Array = []
	for line in text.strip_edges(false, true).split("\n"):
		var row: Array = []
		for ch in line:
			row.append(ch)
		g.append(row)
	return g


static func _text(g: Array) -> String:
	var lines: PackedStringArray = []
	for row in g:
		lines.append("".join(row))
	return "\n".join(lines) + "\n"


static func _at(g: Array, x: int, y: int) -> String:
	if y < 0 or y >= g.size() or x < 0 or x >= (g[y] as Array).size():
		return "#"
	return g[y][x]


## A cell you can stand in: empty, empty above, plain ground below.
static func _standable(g: Array, x: int, y: int) -> bool:
	return _at(g, x, y) == "." and _at(g, x, y - 1) == "." and _at(g, x, y + 1) in FLOOR \
		and y + 1 < g.size() - 1


static func _find(g: Array, chars: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in g.size():
		for x in (g[y] as Array).size():
			if g[y][x] in chars:
				out.append(Vector2i(x, y))
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func hard(text: String, seed_value: int) -> String:
	var g := _grid(text)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 97 + 3
	for c in _find(g, "e"):
		g[c.y][c.x] = "k"
	var keep := _find(g, "PG@")
	var spots: Array = []
	for y in g.size():
		for x in (g[y] as Array).size():
			if _standable(g, x, y) and _standable(g, x - 1, y) and _standable(g, x + 1, y):
				spots.append(Vector2i(x, y))
	_shuffle(spots, rng)
	var w: int = (g[0] as Array).size()
	var add := clampi(maxi(w, g.size()) / 20, 3, 10)
	var placed := _find(g, "k")
	for s in spots:
		if add == 0:
			break
		var ok := true
		for k in keep:
			if maxi(absi(k.x - s.x), absi(k.y - s.y)) < 6:
				ok = false
		for p in placed:
			if maxi(absi(p.x - s.x), absi(p.y - s.y)) < 5:
				ok = false
		if ok:
			g[s.y][s.x] = "k"
			placed.append(s)
			add -= 1
	return _text(g)


static func scramble(text: String, rng: RandomNumberGenerator) -> String:
	var g := _grid(text)
	for c in _find(g, "PG"):
		g[c.y][c.x] = "."
	var w: int = (g[0] as Array).size()
	var h: int = g.size()
	var spots: Array = []
	for y in h:
		for x in w:
			if _standable(g, x, y):
				spots.append(Vector2i(x, y))
	var far := func(a: Vector2i, b: Vector2i) -> bool:
		var dx := absi(a.x - b.x) / float(w)
		var dy := absi(a.y - b.y) / float(h)
		if h <= 20:
			return dx >= 0.5      # wide level: half of it across
		if w <= 34:
			return dy >= 0.5      # tall level: half of it up
		return dx + dy >= 1.0     # diagonal: half across plus half up
	for _try in 200:
		var a: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		var ends := spots.filter(func(b: Vector2i) -> bool: return far.call(a, b))
		if ends.is_empty():
			continue
		var b: Vector2i = ends[rng.randi_range(0, ends.size() - 1)]
		g[a.y][a.x] = "P"
		g[b.y][b.x] = "G"
		return _text(g)
	return text
