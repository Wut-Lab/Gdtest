class_name ForgeGen
extends RefCounted
## Turns a random level (from LevelGen) into an Ember Forge level. Same seed, same result.
##
##   - 1–3 lava pools (_, 2–3 wide, one deep) sunk into flat ground, with at least 3 flat tiles on
##     each side, so they're always a plain jump across.
##   - About half the floating platform rows become hot plates (:), which heat up in cycles
##     with a warning glow first.
##   - 1–3 flame jets (j) in long flat stretches of floor, with room to wait beside them.
##   - About half the Bad Blocks become Cinder Blocks (t), plus 1 more on flat ground.
## Everything stays clear of the start, goal, checkpoint and teleporter pads.


static func forgify(text: String, s: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 97 + 3
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
	var far := func(x: int, y: int, r: int) -> bool:
		for b in busy:
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

	# 1. Lava pools in flat ground.
	var runs := LakeGen._surface_runs(g, "#")
	LakeGen._shuffle(runs, rng)
	var want := rng.randi_range(1, 3)
	var made := 0
	for run in runs + runs:   # second lap: anywhere left that still fits
		if made >= want:
			break
		var n: int = run.z - run.x + 1
		var w := rng.randi_range(2, 3)
		if n < w + 6:
			continue
		var x0: int = run.x + 3 + rng.randi_range(0, n - 6 - w)
		var y: int = run.y
		var ok: bool = open_above.call(x0 - 1, x0 + w, y, 3) and far.call(x0 + w / 2, y, 6)
		for x in range(x0, x0 + w):
			if at.call(x, y) != "#" or at.call(x, y + 1) != "#":
				ok = false
		if not ok:
			continue
		for x in range(x0, x0 + w):
			g[y][x] = "_"
		busy.append(Vector2i(x0 + w / 2, y - 1))
		made += 1

	# 2. Hot plates: about half the platform rows.
	for run in LakeGen._runs(g, "="):
		if run.z - run.x + 1 >= 2 and rng.randf() < 0.5:
			for x in range(run.x, run.z + 1):
				g[run.y][x] = ":"

	# 3. Flame jets in long flat floors.
	var spots := []
	for run in LakeGen._surface_runs(g, "#"):
		if run.z - run.x + 1 < 7:
			continue
		for x in range(run.x + 3, run.z - 2):
			if open_above.call(x - 1, x + 1, run.y, 4) and far.call(x, run.y - 1, 6):
				spots.append(Vector2i(x, run.y - 1))
	for i in rng.randi_range(1, 3):
		if spots.is_empty():
			break
		var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		g[c.y][c.x] = "j"
		busy.append(c)
		spots = spots.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 8 or absi(o.y - c.y) >= 4)

	# 4. Cinder Blocks: half the Bad Blocks, and one more on flat ground.
	for y in rows:
		for x in g[y].size():
			if g[y][x] == "e" and rng.randf() < 0.5:
				g[y][x] = "t"
	spots = []
	for run in LakeGen._surface_runs(g, "#") + LakeGen._runs(g, ":") + LakeGen._runs(g, "="):
		if run.z - run.x + 1 < 5:
			continue
		for x in range(run.x + 2, run.z - 1):
			if open_above.call(x - 1, x + 1, run.y, 2) and far.call(x, run.y - 1, 7):
				spots.append(Vector2i(x, run.y - 1))
	if not spots.is_empty():
		var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		g[c.y][c.x] = "t"
	var out := PackedStringArray()
	for row in g:
		out.append("".join(row))
	return "\n".join(out)
