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
## Chance a level has a treasure chest, up on a floating platform off the main path.
const CHEST_CHANCE := 0.2


static func random_seed() -> int:
	return randi_range(1, 99999)


static func generate(seed_value: int) -> String:
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
