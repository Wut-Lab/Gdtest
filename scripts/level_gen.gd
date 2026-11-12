class_name LevelGen
extends RefCounted
## Builds a random level from a seed, in the same text format as levels/*.txt. The same seed
## always gives the same level.
##
## Guidelines that keep every level beatable (a full jump is about 4 tiles up and 5 across):
##   - Gaps are 2–3 tiles. Climbing 2 tiles across a gap allows only 2 tiles of gap.
##   - Steps go up 1–2 tiles or down 1–3. Ground stays between rows 9 and 15.
##   - Every feature is followed by at least 3 tiles of flat ground to land and take off.
##   - Climbs taller than a jump (5 tiles) always start with a rubber patch to bounce on.
##   - Wide pits get a floating platform, a moving platform or a spike square to ride across,
##     or a teleporter pair to warp over them.
##   - At most 2 extra hearts per level.
##   - Bad Blocks (e): 1–3 a level, at the far end of landing runs of 4+ tiles (or, if none
##     landed there, one on the flat run before the goal),
##     so there's room to see them coming and jump on them.
##   - 1–3 pixels float over gaps, 2 rows above the higher edge, in the jump's arc.
##     Not over the teleporter pits, which are too wide to jump.
##
## Required groups (every level has them, in a random order between the plain features):
##   Obstacles: 1–4 of spike square (S), up-down spikes (V), spiked-top platform (T) and
##     spiked-bottom platform (B).
##   Special Blocks-Advanced: 1–2 teleporter pairs (each pair counts as one).
##   Special Blocks-Basic: 3–15 tiles of rubber (R), rubber wall (W) and one-way block (^).
##     The first 6 can be single tiles; past 6 they come in groups of 3 or more.

const ROWS := 17
const TOP_MIN := 9        # highest ground row
const TOP_MAX := 15       # lowest ground row (row 16 is always fill)
const MAX_HEARTS := 2
const MAX_BAD_BLOCKS := 3
## Chance a level has a treasure chest, up on a floating platform off the main path.
const CHEST_CHANCE := 0.2
## Share of seeds that make a vertical level: a tall shaft you climb to the goal at the top.
const VERTICAL_CHANCE := 0.4
## Share of seeds that make a diagonal level: the same climb, but every step also heads right.
const DIAGONAL_CHANCE := 0.2
const D_MAX_WIDTH := 320
const V_WIDTH := 30          # columns, including the stone wall on each side
const V_MAX_ROWS := 220


static func random_seed() -> int:
	return randi_range(1, 99999)


## Whether a seed makes a vertical (climbing) level. Decided apart from the layout's own
## random numbers, so horizontal seeds keep the layouts they always had.
static func is_vertical(seed_value: int) -> bool:
	var t := RandomNumberGenerator.new()
	t.seed = seed_value * 31 + 7
	return t.randf() < VERTICAL_CHANCE


## Whether a seed makes a diagonal level: climbing up and to the right at the same time.
static func is_diagonal(seed_value: int) -> bool:
	var t := RandomNumberGenerator.new()
	t.seed = seed_value * 31 + 7
	return t.randf() >= 1.0 - DIAGONAL_CHANCE


static func generate(seed_value: int) -> String:
	if is_vertical(seed_value):
		return generate_vertical(seed_value)
	if is_diagonal(seed_value):
		return generate_vertical(seed_value, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols: Array = []   # each column is an Array of ROWS one-character strings
	var st := {"h": TOP_MAX, "hearts": 0}

	_flat(cols, TOP_MAX, 6)
	cols[2][TOP_MAX - 1] = "P"
	var pieces := _required_pieces(rng)
	if rng.randf() < CHEST_CHANCE:
		pieces.insert(rng.randi_range(0, pieces.size()), "chest")

	for piece in pieces:
		for i in rng.randi_range(0, 1):
			_plain_feature(cols, st, rng)
		_piece(cols, st, rng, piece)
		_landing(cols, st, rng)
	for i in rng.randi_range(1, 2):
		_plain_feature(cols, st, rng)

	# Goal at the end, on a flat run with a little ground past it.
	var h: int = st.h
	var gx := cols.size() + 3
	_flat(cols, h, 7)
	cols[gx][h - 1] = "G"
	if st.get("bad", 0) == 0:
		cols[gx - 2][h - 1] = "e"   # every level gets at least one Bad Block

	_add_pixels(cols, rng)

	var lines := PackedStringArray()
	for y in ROWS:
		var line := ""
		for col in cols:
			line += col[y]
		lines.append(line)
	return "\n".join(lines) + "\n"


## The features every level must include, shuffled.
static func _required_pieces(rng: RandomNumberGenerator) -> Array:
	var pieces := []
	for i in rng.randi_range(1, 4):
		pieces.append(["S", "V", "T", "B"][rng.randi_range(0, 3)])
	for i in rng.randi_range(1, 2):
		pieces.append("warp%d" % (i + 1))
	# Basic special blocks: [name, tiles used].
	var singles := [["rubber_pad", 1], ["one_way_step", 1], ["wall_bump", 1], ["wall_bump2", 2]]
	var groups := [["rubber_strip", 3], ["rubber_climb", 3], ["rubber_wall", 3], ["one_way_shelf", 3],
		["one_way_stairs", 4]]
	var target := rng.randi_range(3, 15)
	var used := 0
	while used < target:
		var options := []
		if used < 6:
			options += singles
		for g in groups:
			if used + g[1] <= 15:
				options.append(g)
		if options.is_empty():
			break
		var pick: Array = options[rng.randi_range(0, options.size() - 1)]
		pieces.append(pick[0])
		used += pick[1]
	for i in range(pieces.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = tmp
	return pieces


## Gaps, steps, floating platforms and flat runs between the required pieces.
static func _plain_feature(cols: Array, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var h: int = st.h
	match _pick(rng, {"gap": 2.5, "step": 2.5, "platform": 1.2, "run": 1.5}):
		"gap":
			var new_h := clampi(h + rng.randi_range(-2, 2), TOP_MIN, TOP_MAX)
			_pit(cols, 2 if new_h <= h - 2 else rng.randi_range(2, 3))
			st.h = new_h
		"run":
			_flat(cols, h, rng.randi_range(4, 8))
		"step":
			var dh := rng.randi_range(-2, 3)
			st.h = clampi(h + (dh if dh != 0 else 1), TOP_MIN, TOP_MAX)
		"platform":
			# A 7-wide pit with a 3-tile platform 2 rows up in the middle.
			var x := cols.size()
			_pit(cols, 7)
			for i in range(2, 5):
				cols[x + i][h - 2] = "="
			if st.hearts < MAX_HEARTS and rng.randf() < 0.35:
				cols[x + 3][h - 5] = "H"
				st.hearts += 1
	_landing(cols, st, rng)


## Flat ground after a feature, sometimes with a heart above it.
static func _landing(cols: Array, st: Dictionary, rng: RandomNumberGenerator) -> void:
	var h: int = st.h
	var x := cols.size()
	var w := rng.randi_range(3, 6)
	_flat(cols, h, w)
	if st.hearts < MAX_HEARTS and w >= 4 and rng.randf() < 0.08:
		cols[x + 1][h - 3] = "H"
		st.hearts += 1
	if st.get("bad", 0) < MAX_BAD_BLOCKS and w >= 4 and rng.randf() < 0.3:
		cols[x + w - 1][h - 1] = "e"
		st.bad = st.get("bad", 0) + 1


static func _piece(cols: Array, st: Dictionary, rng: RandomNumberGenerator, piece: String) -> void:
	var h: int = st.h
	var x := cols.size()
	match piece:
		"S":
			# A 5-wide pit bridged by a spike square pacing in the middle.
			_pit(cols, 5)
			cols[x + 2][h - 1] = "S"
		"V":
			# Up-down spikes on flat ground: pass under while it's up, or dash through it.
			_flat(cols, h, 7)
			cols[x + 3][h - 1] = "V"
		"T":
			# A spiked-top platform pacing along flat ground: jump over it.
			_flat(cols, h, 9)
			cols[x + 4][h - 1] = "T"
		"B":
			# A 9-wide pit crossed by riding a spiked-bottom platform.
			_pit(cols, 9)
			cols[x + 4][h - 1] = "B"
		"warp1", "warp2":
			# A pit too wide to jump, with a teleport pad on each edge.
			var pad := "1" if piece == "warp1" else "2"
			_flat(cols, h, 3)
			cols[x + 2][h - 1] = pad
			_pit(cols, 9)
			_flat(cols, h, 2)
			cols[x + 12][h - 1] = pad
		"chest":
			# A floating platform 3 rows up with a chest on it: jump up through it to reach.
			_flat(cols, h, 7)
			for i in range(2, 5):
				cols[x + i][h - 3] = "="
			cols[x + 3][h - 4] = "C"
		"rubber_pad":
			_flat(cols, h, 3)
			cols[x + 1][h] = "R"
		"rubber_strip":
			_flat(cols, h, 5)
			for i in range(1, 4):
				cols[x + i][h] = "R"
		"rubber_climb":
			# Rubber patch, then a 5-tile wall only a bounce can clear. Drop down first if
			# there isn't room above.
			if h < TOP_MIN + 5:
				h = TOP_MAX
				_flat(cols, h, 3)
				x = cols.size()
			_flat(cols, h, 3)
			for i in 3:
				cols[x + i][h] = "R"
			st.h = h - 5
		"wall_bump", "wall_bump2", "rubber_wall":
			# A rubber wall standing on flat ground (1, 2 or 3 tall): hop over it, or it
			# throws you back.
			var tall := {"wall_bump": 1, "wall_bump2": 2, "rubber_wall": 3}[piece] as int
			_flat(cols, h, 5)
			for i in tall:
				cols[x + 2][h - 1 - i] = "W"
		"one_way_step":
			# A 5-wide pit with a one-way block stepping stone in the middle.
			_pit(cols, 5)
			cols[x + 2][h - 1] = "^"
		"one_way_shelf":
			# A 7-wide pit with a 3-block one-way shelf 2 rows up.
			_pit(cols, 7)
			for i in range(2, 5):
				cols[x + i][h - 2] = "^"
		"one_way_stairs":
			# One-way blocks stepping up to a ledge 4 tiles higher (or down from one).
			if h < TOP_MIN + 4:
				h = TOP_MAX
				_flat(cols, h, 3)
				x = cols.size()
			_flat(cols, h, 6)
			cols[x + 1][h - 2] = "^"
			cols[x + 2][h - 2] = "^"
			cols[x + 4][h - 4] = "^"
			cols[x + 5][h - 4] = "^"
			st.h = h - 4
			_flat(cols, st.h, 1)


## Puts 1–3 pixels over gaps: in the middle of a pit, 2 rows above its higher edge.
static func _add_pixels(cols: Array, rng: RandomNumberGenerator) -> void:
	var pits := []   # [first column, width]
	var x := 0
	while x < cols.size():
		if cols[x][ROWS - 1] == ".":
			var start := x
			while x < cols.size() and cols[x][ROWS - 1] == ".":
				x += 1
			var w := x - start
			var has_bridge := false
			for c in range(start, x):
				if "B" in cols[c] or "=" in cols[c] or "^" in cols[c] or "S" in cols[c]:
					has_bridge = true
			if start > 0 and x < cols.size() and (w <= 5 or has_bridge):
				pits.append([start, w])
		else:
			x += 1
	for i in range(pits.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pits[i]
		pits[i] = pits[j]
		pits[j] = tmp
	for k in mini(rng.randi_range(1, 3), pits.size()):
		var start: int = pits[k][0]
		var w: int = pits[k][1]
		var top := mini(_top(cols[start - 1]), _top(cols[start + w]))
		var col: Array = cols[start + w / 2]
		var row := top - 2
		while row > 0 and col[row] != ".":
			row -= 1
		col[row] = "*"


## The row of a column's highest solid tile.
static func _top(col: Array) -> int:
	for y in ROWS:
		if col[y] in ["#", "R", "W", "^", "="]:
			return y
	return ROWS


static func _flat(cols: Array, h: int, w: int) -> void:
	for i in w:
		var col := []
		for y in ROWS:
			col.append("#" if y >= h else ".")
		cols.append(col)


static func _pit(cols: Array, w: int) -> void:
	for i in w:
		var col := []
		for y in ROWS:
			col.append(".")
		cols.append(col)


static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys()[0]


# ---------- Vertical levels ----------
## A tall shaft between two stone walls. You climb jump-through platforms to the goal at the top.
## Guidelines that keep it climbable:
##   - The next platform is 3 rows up (2 when it's a long sideways hop), with at most 3 tiles of
##     sideways gap, so every step is an easy jump. Platforms are jump-through (= or ^).
##   - Rubber pads launch you 5 rows up to the next platform.
##   - Teleporter pairs warp you 9 rows up, past a gap too tall to jump.
##   - Obstacles (S, V, T) and Bad Blocks sit on wide platforms you cross from one end to the other.
##   - Falling just drops you to a lower platform or the floor; you never fall out.
##   - Same required groups as horizontal levels: 1–4 obstacles, 1–2 teleporter pairs and 3–15
##     basic special blocks (rubber pads, rubber wall bumps, one-way block platforms).
## Diagonal levels use the same rules in a wide space, with every step heading right.
static func generate_vertical(seed_value: int, diagonal := false) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var gw := D_MAX_WIDTH if diagonal else V_WIDTH
	var g: Array = []   # rows (top to bottom), each an Array of one-character strings
	for y in V_MAX_ROWS:
		var row := []
		for x in gw:
			row.append("#" if x == 0 or x == gw - 1 or y >= V_MAX_ROWS - 2 else ".")
		g.append(row)
	var floor_y := V_MAX_ROWS - 2
	g[floor_y - 1][3] = "P"
	# cur: the platform you're standing on. exit: which end you leave from (-1 left, 1 right, 0 any).
	var st := {"cur": {"x": 1, "w": V_WIDTH - 2, "y": floor_y, "exit": 0}, "hearts": 0, "bad": 0,
		"pixel_spots": [], "wide": []}
	if diagonal:
		st.dir = 1
		st.cur = {"x": 1, "w": 6, "y": floor_y, "exit": 1}

	var pieces := []
	for i in rng.randi_range(1, 4):
		pieces.append(["S", "V", "T"][rng.randi_range(0, 2)])
	for i in rng.randi_range(1, 2):
		pieces.append("warp%d" % (i + 1))
	var basics := 0
	var target := rng.randi_range(3, 15)
	while basics < target:
		var pick: String = ["rubber", "one_way", "wall"][rng.randi_range(0, 2)]
		pieces.append(pick)
		basics += {"rubber": 3, "one_way": 3, "wall": 1}[pick]
	if rng.randf() < CHEST_CHANCE:
		pieces.append("chest")
	for i in range(pieces.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = tmp

	# Diagonal levels rise 1–3 rows a step, so they head across as much as up.
	for piece in pieces:
		for i in rng.randi_range(1, 2):
			_v_step(g, st, rng, rng.randi_range(1, 3) if diagonal else 3, rng.randi_range(3, 5), "=")
		_v_piece(g, st, rng, piece)
	for i in rng.randi_range(2, 3):
		_v_step(g, st, rng, rng.randi_range(1, 3) if diagonal else 3, rng.randi_range(3, 5), "=")
	# The goal on a last, wider platform.
	var top: Dictionary = _v_step(g, st, rng, 3, 6, "=")
	g[top.y - 1][top.x + 3] = "G"
	if st.bad == 0 and not st.wide.is_empty():
		var w: Dictionary = st.wide[rng.randi_range(0, st.wide.size() - 1)]
		_v_put(g, w.x + w.w - 1, w.y - 1, "e")
	# 1–3 pixels hanging in the jump arcs between platforms.
	var spots: Array = st.pixel_spots
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var placed := 0
	for p in spots:
		if placed >= rng.randi_range(1, 3):
			break
		if g[p.y][p.x] == ".":
			g[p.y][p.x] = "*"
			placed += 1

	# Crop the empty sky above the goal, keeping 6 rows of headroom, and (diagonal) the empty
	# space past it, closed off with a wall.
	var first: int = maxi(top.y - 8, 0)
	var last_x := gw
	if diagonal:
		last_x = mini(top.x + top.w + 6, gw)
		for y in V_MAX_ROWS:
			g[y][last_x - 1] = "#"
	var lines := PackedStringArray()
	for y in range(first, V_MAX_ROWS):
		lines.append("".join(g[y].slice(0, last_x)))
	return "\n".join(lines) + "\n"


## Puts a tile if the spot is inside the shaft.
static func _v_put(g: Array, x: int, y: int, ch: String) -> void:
	if x > 0 and x < g[0].size() - 1 and y >= 0:
		g[y][x] = ch


## Whether a platform of width w at (x, y) has room: empty around it and 2 rows of air above.
static func _v_free(g: Array, x: int, y: int, w: int) -> bool:
	var gw: int = g[0].size()
	if x < 1 or x + w > gw - 1 or y < 4:
		return false
	for yy in range(y - 3, y + 2):
		for xx in range(maxi(x - 1, 1), mini(x + w + 1, gw - 1)):
			if g[yy][xx] != ".":
				return false
	return true


## Adds the next platform `rise` rows above the current one, within an easy jump, and makes it
## current. Returns it.
static func _v_step(g: Array, st: Dictionary, rng: RandomNumberGenerator, rise: int, w: int,
		ch: String, max_gap := 3, min_gap := -2) -> Dictionary:
	var cur: Dictionary = st.cur
	var y: int = cur.y - rise
	var best := -1
	for attempt in 40:
		var gap := rng.randi_range(min_gap, max_gap)   # tiles of air between the edges (negative = overlap)
		var side: int = cur.exit if cur.exit != 0 else st.get("dir", 1 if rng.randf() < 0.5 else -1)
		if attempt > 20 and not st.has("dir"):
			side = -side
		var x: int = cur.x + cur.w + gap if side > 0 else cur.x - gap - w
		if cur.w > 12:   # the floor: anywhere
			x = rng.randi_range(2, g[0].size() - 2 - w)
		if _v_free(g, x, y, w):
			best = x
			break
	if best < 0:   # no room sideways: go straight up through it (platforms are jump-through)
		best = clampi(cur.x + cur.w / 2 - w / 2, 1, g[0].size() - 1 - w)
	for i in w:
		g[y][best + i] = ch
	# A pixel in the arc of this jump, between the two platforms.
	var mid_x: int = (cur.x + cur.w / 2 + best + w / 2) / 2 if cur.w <= 12 else best + w / 2
	st.pixel_spots.append({"x": mid_x, "y": y - 2})
	if st.hearts < MAX_HEARTS and rng.randf() < 0.06:
		_v_put(g, best + w / 2, y - 3, "H")
		st.hearts += 1
	var plat := {"x": best, "w": w, "y": y, "exit": 0}
	st.cur = plat
	return plat


## A wide platform you cross end to end: arrive at one end, leave from the other.
static func _v_wide(g: Array, st: Dictionary, rng: RandomNumberGenerator, w: int) -> Dictionary:
	var came_from: int = st.cur.x + st.cur.w / 2
	var plat := _v_step(g, st, rng, 3, w, "=", 2)
	var center: int = plat.x + w / 2
	plat.exit = 1 if came_from < center else -1
	st.wide.append(plat)
	return plat


static func _v_piece(g: Array, st: Dictionary, rng: RandomNumberGenerator, piece: String) -> void:
	match piece:
		"S", "V", "T":
			var p := _v_wide(g, st, rng, 9)
			_v_put(g, p.x + 4, p.y - 1, piece)
			if st.bad < MAX_BAD_BLOCKS and rng.randf() < 0.3:
				_v_put(g, p.x + (p.w - 1 if p.exit > 0 else 0), p.y - 1, "e")
				st.bad += 1
		"wall":
			# A rubber wall bump (1–2 tall) standing on a wide platform: hop over it.
			var p := _v_wide(g, st, rng, 7)
			for i in rng.randi_range(1, 2):
				_v_put(g, p.x + 3, p.y - 1 - i, "W")
		"one_way":
			# A few one-way block steps in a row.
			for i in rng.randi_range(1, 2):
				_v_step(g, st, rng, 3, rng.randi_range(3, 4), "^")
		"rubber":
			# A rubber pad off to the side of where you stand (never overhead), then a platform
			# 5 rows up that only a bounce reaches.
			var p := _v_step(g, st, rng, 2, 5, "=", 3, 1)
			for i in range(1, 4):
				g[p.y][p.x + i] = "R"
			st.cur = {"x": p.x + 1, "w": 3, "y": p.y, "exit": 0}
			var up := _v_step(g, st, rng, 5, 4, "=", 0)
			up.exit = 0
		"warp1", "warp2":
			# A pad at the end of a platform, and its partner 9 rows up at the far end of a
			# platform too high to jump to. You leave that one from its other end.
			var pad := "1" if piece == "warp1" else "2"
			var a := _v_step(g, st, rng, 3, 5, "=")
			_v_put(g, a.x + 4, a.y - 1, pad)
			var b := _v_step(g, st, rng, 9, 7, "=", 4)
			var pad_left: bool = rng.randf() < 0.5 if not st.has("dir") else st.dir > 0
			_v_put(g, b.x if pad_left else b.x + 6, b.y - 1, pad)
			b.exit = 1 if pad_left else -1
		"chest":
			# A small side ledge with a chest, off the main climb (the climb carries on from here).
			var cur: Dictionary = st.cur.duplicate()
			var ledge := _v_step(g, st, rng, 3, 3, "=")
			_v_put(g, ledge.x + 1, ledge.y - 1, "C")
			st.pixel_spots.pop_back()
			st.cur = cur
