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
##   - Wide pits get a floating platform or a spike square to ride across.
##   - Spike squares and up-down spikes only start after the first stretch, and grow more
##     common toward the goal. At most 2 extra hearts per level.

const ROWS := 17
const LENGTH := 100       # roughly how many columns of level before the goal
const TOP_MIN := 9        # highest ground row
const TOP_MAX := 15       # lowest ground row (row 16 is always fill)
const MAX_HEARTS := 2


static func random_seed() -> int:
	return randi_range(1, 99999)


static func generate(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols: Array = []   # each column is an Array of ROWS one-character strings
	var h := TOP_MAX
	var hearts := 0

	# Start: flat ground with the player.
	_flat(cols, h, 6)
	cols[2][h - 1] = "P"

	while cols.size() < LENGTH:
		var progress := float(cols.size()) / LENGTH
		var kinds := {"gap": 2.5, "step": 2.5, "platform": 1.2, "run": 1.5}
		if progress > 0.2:
			kinds["spike"] = 1.0 + progress * 2.0
			kinds["updown"] = 0.8 + progress * 1.5
		if h >= TOP_MIN + 5:
			kinds["rubber"] = 1.2
		match _pick(rng, kinds):
			"gap":
				var dh := rng.randi_range(-2, 2)
				var new_h := clampi(h + dh, TOP_MIN, TOP_MAX)
				var w := rng.randi_range(2, 3)
				if new_h <= h - 2:
					w = 2
				_pit(cols, w)
				h = new_h
			"run":
				_flat(cols, h, rng.randi_range(4, 8))
			"step":
				var dh := rng.randi_range(-2, 3)
				if dh == 0:
					dh = 1
				h = clampi(h + dh, TOP_MIN, TOP_MAX)
			"platform":
				# A 7-wide pit with a 3-tile platform 2 rows up in the middle.
				var x := cols.size()
				_pit(cols, 7)
				for i in range(2, 5):
					cols[x + i][h - 2] = "="
				if hearts < MAX_HEARTS and rng.randf() < 0.35:
					cols[x + 3][h - 5] = "H"
					hearts += 1
			"spike":
				# A 5-wide pit bridged by a spike square pacing in the middle.
				var x := cols.size()
				_pit(cols, 5)
				cols[x + 2][h - 1] = "S"
			"updown":
				# Flat ground with an up-down spike square to pass under while it's up.
				var x := cols.size()
				_flat(cols, h, 7)
				cols[x + 3][h - 1] = "V"
			"rubber":
				# Rubber patch, then a 5-tile wall only a bounce can clear.
				var x := cols.size()
				_flat(cols, h, 3)
				for i in 3:
					cols[x + i][h] = "R"
				h -= 5
		var x := cols.size()
		_flat(cols, h, rng.randi_range(3, 6))
		if hearts < MAX_HEARTS and cols.size() - x >= 4 and rng.randf() < 0.08:
			cols[x + 1][h - 3] = "H"
			hearts += 1

	# Goal at the end, on a flat run with a little ground past it.
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
