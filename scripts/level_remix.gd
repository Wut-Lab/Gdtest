class_name LevelRemix
extends RefCounted
## Replay Room remixes of a random level's text map:
##   hard:     every Bad Block becomes a Hard Bad Block (k: faster, sees farther, horned) and
##             more Hard Bad Blocks are added on flat ground away from the start, goal and checkpoint.
##   scramble: the start and goal move to random spots you can stand on, at least half the
##             level apart (across for wide levels, up for tall ones, both added up for diagonal).
##             The goal is always one a tile map of jumps says the start can reach (see reach()).

const FLOOR := "#="
## Tiles you can't move through (^ one-way blocks only stop you from above).
const SOLID := "#=RWTBSV"
## Tiles you can stand on top of.
const TOP := "#=RWB^S"   # S: a horizontal spike square has a safe top to ride
## A plain jump: about 4 tiles up and 5 across. Rubber bounces reach about 7 up.
const JUMP_UP := 4
const BOUNCE_UP := 7
const JUMP_ACROSS := 5


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
	for _try in 40:
		var a: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		var reached := reach(g, a)
		var ends := spots.filter(func(b: Vector2i) -> bool: return far.call(a, b) and reached.has(b))
		if ends.is_empty():
			continue
		var b: Vector2i = ends[rng.randi_range(0, ends.size() - 1)]
		g[a.y][a.x] = "P"
		g[b.y][b.x] = "G"
		return _text(g)
	return text


## A cell the player can stand in: open, and something to stand on below.
static func _node(g: Array, x: int, y: int) -> bool:
	var c := _at(g, x, y)
	return not c in SOLID and c != "^" and _at(g, x, y + 1) in TOP and y + 1 < g.size()


static func _open(g: Array, x: int, y: int, up: bool) -> bool:
	var c := _at(g, x, y)
	return not c in SOLID and (up or c != "^")


## Can you jump from a to b? Tries arcs from low to high: straight up from a to a top row,
## across, then down onto b. Rising passes through one-way blocks; falling doesn't.
static func _can_jump(g: Array, a: Vector2i, b: Vector2i, up_max: int) -> bool:
	var dx := absi(b.x - a.x)
	var drop := b.y - a.y   # positive: b is lower
	if a.y - b.y > up_max or dx > JUMP_ACROSS + clampi(drop / 2, 0, 3):
		return false
	var step := signi(b.x - a.x)
	for top in range(mini(a.y, b.y), a.y - up_max - 1, -1):
		var ok := true
		for y in range(top, a.y + 1):
			if not _open(g, a.x, y, true):
				ok = false
				break
		if ok and dx > 0:
			var x := a.x
			while x != b.x:
				x += step
				if not _open(g, x, top, true):
					ok = false
					break
		if ok:
			for y in range(top, b.y + 1):
				if not _open(g, b.x, y, false):
					ok = false
					break
		if ok:
			return true
	return false


## Every standing spot reachable from start by walking, jumping, falling, bouncing on
## rubber and teleporting (each digit pair links both ways). A cautious map: moving
## platforms and abilities aren't counted, so it can miss real routes, never invent them.
static func reach(g: Array, start: Vector2i) -> Dictionary:
	var h := g.size()
	var w: int = (g[0] as Array).size()
	var pads := {}
	for p in _find(g, "123"):
		if not pads.has(g[p.y][p.x]):
			pads[g[p.y][p.x]] = []
		pads[g[p.y][p.x]].append(p)
	var stand := {}
	for y in h:
		for x in w:
			if _node(g, x, y):
				stand[Vector2i(x, y)] = true
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var a: Vector2i = todo.pop_back()
		var up_max := BOUNCE_UP if _at(g, a.x, a.y + 1) == "R" else JUMP_UP
		var next: Array[Vector2i] = []
		for x in range(maxi(a.x - JUMP_ACROSS - 3, 0), mini(a.x + JUMP_ACROSS + 4, w)):
			for y in range(maxi(a.y - up_max, 0), h):
				var b := Vector2i(x, y)
				if stand.has(b) and not seen.has(b) and _can_jump(g, a, b, up_max):
					next.append(b)
		# Teleporters: touching a pad drops you below its partner.
		for d in [-1, 0, 1]:
			var c := _at(g, a.x + d, a.y)
			if pads.has(c):
				for p in pads[c]:
					var y: int = p.y
					while y < h and not _node(g, p.x, y) and _open(g, p.x, y, false):
						y += 1
					next.append(Vector2i(p.x, y))
		for b in next:
			if stand.has(b) and not seen.has(b):
				seen[b] = true
				todo.append(b)
	return seen
