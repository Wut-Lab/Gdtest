class_name LakeGen
extends RefCounted
## Turns a random level (from LevelGen) into a Cavern Lake level. Same seed, same result.
##
##   - Floating platforms grow 1–2 tiles wider where there's room (never closer than a tile to
##     anything else).
##   - 1–2 small lakes (~, 3–5 wide and 2 deep) are dug into long flat stretches of ground,
##     with at least 3 flat tiles on each side. You float in them and can always hop out.
##   - 1–2 rivers run along wide platforms (< >) and pour off one end as a waterfall (|) that
##     drops up to 6 tiles. A river on a long stretch of ground runs into shallow spikes (,).
##   - 1–2 more shallow spikes on flat ground, with room to land on each side.
##   - 1–2 Piranha Blocks (a) in the lakes (or the rivers, if there's no lake) and 1–2
##     Harpoonist Blocks (u) on flat ground, all well away from the start, goal and checkpoint.
##   - About 30% of the other floating platforms become crumbling blocks (c).

const CRUMBLE := 0.3


static func lakeify(text: String, s: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 71 + 5
	var g: Array = []
	for line in text.split("\n"):
		g.append(Array(line.split("")))
	var rows := g.size()
	var at := func(x: int, y: int) -> String:
		return g[y][x] if y >= 0 and y < rows and x >= 0 and x < g[y].size() else "?"
	var busy: Array[Vector2i] = []
	for y in rows:
		for x in g[y].size():
			if g[y][x] not in [".", "#", "=", "R", "W", "^"]:
				busy.append(Vector2i(x, y))
	var key_spots := busy.duplicate()   # start, goal, checkpoint, pads, pickups...
	var far := func(x: int, y: int, r: int, only_key := false) -> bool:
		for b in (key_spots if only_key else busy):
			var rr := maxi(r, 10) if g[b.y][b.x] == "P" else r
			if absi(b.x - x) < rr and absi(b.y - y) < 6:
				return false
		return true
	var open_above := func(x0: int, x1: int, y: int, h: int) -> bool:
		for x in range(x0, x1 + 1):
			for dy in range(1, h + 1):
				if at.call(x, y - dy) != ".":
					return false
		return true

	# 1. Wider platforms.
	for run in _runs(g, "="):
		if run.z - run.x + 1 < 3:
			continue
		for side in [-1, 1]:
			var grow := rng.randi_range(0, 2)
			for i in grow:
				var cx: int = (run.x - 1 - i) if side < 0 else (run.z + 1 + i)
				var ok: bool = at.call(cx, run.y) == "." and at.call(cx + side, run.y) == "."
				for dy in [-3, -2, -1, 1, 2]:
					if at.call(cx, run.y + dy) != "." or at.call(cx + side, run.y + dy) not in [".", "?"]:
						ok = false
				if not ok:
					break
				g[run.y][cx] = "="

	# 2. Lakes in long flat ground.
	var lakes: Array[Vector2i] = []   # bottom-row cells, for piranhas
	var lake_runs := []
	var ground_runs := _surface_runs(g, "#")
	_shuffle(ground_runs, rng)
	var want_lakes := rng.randi_range(1, 2)
	# Strict first (3 flat tiles each side, 3 rows of air), then looser (2 and 2) if none fit.
	var gn := ground_runs.size()
	for i in gn * 2:
		var run: Vector3i = ground_runs[i % gn]
		var loose := i >= gn
		if lake_runs.size() >= want_lakes or (loose and not lake_runs.is_empty()):
			break
		var n: int = run.z - run.x + 1
		var w := rng.randi_range(3, 5)
		var m := 2 if loose else 3
		if n < w + 2 * m + 1:
			continue
		var x0: int = run.x + m + rng.randi_range(0, n - 2 * m - w)
		var y: int = run.y
		var ok: bool = open_above.call(x0 - 1, x0 + w, y, 2 if loose else 3) \
			and far.call(x0 + w / 2, y, 4 if loose else 6) and at.call(x0, y) == "#"
		for x in range(x0, x0 + w):
			if at.call(x, y + 1) != "#" or at.call(x, y + 2) != "#":
				ok = false
		if not ok:
			continue
		for x in range(x0, x0 + w):
			g[y][x] = "~"
			g[y + 1][x] = "~"
			lakes.append(Vector2i(x, y + 1))
		lake_runs.append(Vector3i(x0, y, x0 + w - 1))
		busy.append(Vector2i(x0 + w / 2, y - 1))

	# 3. Rivers on wide platforms, pouring off one end.
	var river_cells: Array[Vector2i] = []
	var plat := _runs(g, "=")
	_shuffle(plat, rng)
	var made := 0
	var want := rng.randi_range(1, 2)
	var tries := plat.size()
	for i in tries * 2:
		var run: Vector3i = plat[i % tries]
		var loose := i >= tries   # second pass: 3-tile platforms, nearer other things
		if made >= want or (loose and made > 0):
			break
		if run.z - run.x + 1 < (3 if loose else 4) or not open_above.call(run.x, run.z, run.y, 2) \
				or not far.call((run.x + run.z) / 2, run.y - 1, 3 if loose else 5) \
				or at.call(run.x, run.y) != "=":
			continue
		var dirs := [1, -1] if rng.randf() < 0.6 else [-1, 1]
		for d in dirs:
			var ex: int = run.z + 1 if d > 0 else run.x - 1
			if at.call(ex, run.y - 1) != "." or at.call(ex, run.y) != ".":
				continue
			for x in range(run.x, run.z + 1):
				g[run.y - 1][x] = ">" if d > 0 else "<"
				river_cells.append(Vector2i(x, run.y - 1))
				g[run.y][x] = "`"   # never crumbles under a river
			# A stone lip holds the water in at the upstream end; it only flows out the other.
			var lip: int = run.x if d > 0 else run.z
			g[run.y - 1][lip] = "#"
			river_cells.erase(Vector2i(lip, run.y - 1))
			var fy: int = run.y - 1
			while fy < run.y + 6 and at.call(ex, fy) == ".":
				g[fy][ex] = "|"
				fy += 1
			busy.append(Vector2i((run.x + run.z) / 2, run.y - 1))
			made += 1
			break

	# A river on a long stretch of ground runs into shallow spikes.
	ground_runs = _surface_runs(g, "#")
	_shuffle(ground_runs, rng)
	for run in ground_runs:
		var n: int = run.z - run.x + 1
		var len := rng.randi_range(4, 6)
		if n < len + 7:
			continue
		var x0: int = run.x + 2 + rng.randi_range(0, n - len - 6)
		if not open_above.call(x0, x0 + len + 1, run.y, 3) or not far.call(x0 + len / 2, run.y - 1, 6):
			continue
		for x in range(x0, x0 + len):
			g[run.y - 1][x] = ">"
		g[run.y - 1][x0 - 1] = "#"   # a stone lip holds it in at the upstream end
		g[run.y - 1][x0 + len] = ","
		busy.append(Vector2i(x0 + len, run.y - 1))
		break

	# 4. Shallow spikes on flat ground (or wide platforms), with room to land each side.
	var spikes := rng.randi_range(1, 2)
	var spots := []
	for run in _surface_runs(g, "#") + _runs(g, "="):
		var n: int = run.z - run.x + 1
		if n < 7:
			continue
		for x in range(run.x + 3, run.z - 2):
			if open_above.call(x - 1, x + 1, run.y, 3) and far.call(x, run.y - 1, 6):
				spots.append(Vector2i(x, run.y - 1))
	for i in spikes:
		if spots.is_empty():
			break
		var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		g[c.y][c.x] = ","
		busy.append(c)
		spots = spots.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 8 or absi(o.y - c.y) >= 4)

	# 5. Piranhas: in the lakes, or in the rivers.
	var homes: Array = lakes if not lakes.is_empty() else river_cells
	var near_ok := homes.filter(func(c: Vector2i) -> bool: return far.call(c.x, c.y, 8, true))
	homes = near_ok if not near_ok.is_empty() else homes.filter(func(c: Vector2i) -> bool: return far.call(c.x, c.y, 5, true))
	for i in rng.randi_range(1, 2):
		if homes.is_empty():
			break
		var c: Vector2i = homes[rng.randi_range(0, homes.size() - 1)]
		g[c.y][c.x] = "a"
		homes = homes.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 4 or o.y != c.y)

	# 6. Harpoonists on flat ground or platforms.
	spots = []
	for run in _surface_runs(g, "#") + _runs(g, "="):
		if run.z - run.x + 1 < 3:
			continue
		for x in range(run.x + 1, run.z):
			if open_above.call(x - 1, x + 1, run.y, 2) and far.call(x, run.y - 1, 7):
				spots.append(Vector2i(x, run.y - 1))
	for i in rng.randi_range(1, 2):
		if spots.is_empty():
			break
		var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		g[c.y][c.x] = "u"
		g[c.y + 1][c.x] = "`" if g[c.y + 1][c.x] == "=" else g[c.y + 1][c.x]
		busy.append(c)
		spots = spots.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 10 or absi(o.y - c.y) >= 5)

	# 7. Some of the other platforms crumble.
	for y in rows:
		for x in g[y].size():
			if g[y][x] == "=" and rng.randf() < CRUMBLE:
				g[y][x] = "c"
			elif g[y][x] == "`":
				g[y][x] = "="
	var out := PackedStringArray()
	for row in g:
		out.append("".join(row))
	return "\n".join(out)


## Horizontal runs of a tile: Vector3i(first x, row, last x).
static func _runs(g: Array, ch: String) -> Array:
	var out := []
	for y in g.size():
		var x := 0
		while x < g[y].size():
			if g[y][x] == ch:
				var x1 := x
				while x1 + 1 < g[y].size() and g[y][x1 + 1] == ch:
					x1 += 1
				out.append(Vector3i(x, y, x1))
				x = x1 + 1
			else:
				x += 1
	return out


## Runs of ground with open air right above it (walkable floor): Vector3i(first x, row, last x).
static func _surface_runs(g: Array, ch: String) -> Array:
	var out := []
	for y in range(1, g.size()):
		var x := 0
		while x < g[y].size():
			if g[y][x] == ch and x < g[y - 1].size() and g[y - 1][x] == ".":
				var x1 := x
				while x1 + 1 < g[y].size() and g[y][x1 + 1] == ch and g[y - 1][x1 + 1] == ".":
					x1 += 1
				out.append(Vector3i(x, y, x1))
				x = x1 + 1
			else:
				x += 1
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
