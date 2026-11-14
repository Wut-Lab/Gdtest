class_name Level
extends Node2D
## A level. Either set Map File to a text map (the usual way), or clear it and paint the
## Ground tile map in the editor. The camera and the fall line follow the level's size.
##
## Text map characters, one per 32 px tile:
##   .  empty        #  ground        =  floating platform (jump up through it)
##   R  rubber       W  rubber wall   P  player start  G  goal
##   1  red teleport     2  yellow teleport     3  blue teleport   (each color links its pair)
##   H  extra heart      S  spike square (paces left and right; spiky sides, safe top)
##   V  vertical spike square (rises 3 tiles and back; spikes on top and bottom)
##   ^  one-way block (jump up through it from below, then stand on it)
##   D  Dash card    Q  Ground Pound card    J  Double Jump card    L  Glide card
##   K  Quick card       E  Tele-hop card       X  Heart Box card
##   *  pixel (1 pixel of currency, once per save file)
##   C  treasure chest (a card or some pixels, once per save file)
##   T  wide moving platform with spikes on top (3 tiles wide, centered on its cell)
##   B  wide moving platform with spikes underneath (ride on top)
##   @  checkpoint (falls send you back here once you've touched it)
##   c  crumbling block (Mossy Cave): holds a moment after you land, then falls; grows back
##   !  town: dungeon gate     $  town: shop     &  town: card hall

signal goal_reached
signal heart_collected
signal card_collected(ability: String)
signal chest_opened(index: int)
signal pixel_collected(index: int)
signal player_hurt(push: Vector2)
## A breakable obstacle or enemy was destroyed: kind is "spike" or "bad_block".
signal obstacle_broken(pos: Vector2, kind: String)
## The player walked up to (or away from) a town building's door.
signal door_near(kind: String, near: bool)
## The player touched a checkpoint. spot is where to respawn.
signal checkpoint_reached(spot: Vector2)
## A boss (Big Bad Square) was beaten.
signal boss_defeated

const T := 32
## Bad Blocks marked k in the map (Hard Replay).
var _hard_cells := {}
const ATLAS_GROUND_TOP := Vector2i(0, 0)
const ATLAS_GROUND_FILL := Vector2i(1, 0)
const ATLAS_PLATFORM := Vector2i(2, 0)
const ATLAS_RUBBER := Vector2i(3, 0)
const ATLAS_RUBBER_WALL := Vector2i(4, 0)
const ATLAS_ONE_WAY := Vector2i(5, 0)
const TELEPORT_COLORS := {"1": "red", "2": "yellow", "3": "blue"}

@export_file("*.txt") var map_file := ""
@export var teleporter_scene: PackedScene
@export var grid_color := Color(0.93, 0.95, 0.98, 0.05)

var _walls: Array[CollisionShape2D] = []
var _teleporters: Node2D
var _pickups: Node2D
var _obstacles: Node2D
var _chests: Node2D
var _pixels: Node2D
var _doors: Node2D
## The pond (empty in most levels).
var water: Water
## The look of the level: "" (sandstone) or "moss" (Mossy Cave: green-tinted stone, moss on top
## of the ground and vines hanging from platforms).
var theme := ""
var _checkpoints: Node2D
## Main sets this: whether a heart can be picked up right now (false at full health).
var heart_check := Callable()

@onready var ground: TileMapLayer = $Ground
@onready var start: Marker2D = $Start
@onready var goal: Goal = $Goal
## Boss rooms: background doors (d, bottom cell of a 2-tall door) and whether a boss is here.
var _back_doors: Array[Vector2i] = []
## Mossy blocks (o): ground blocks with moss on them, e.g. by the town pond after the Mossy Cave.
var _moss_cells: Array[Vector2i] = []
var _moss_layer: Node2D
var _mossy_cells := {}
## Ground cells a Moss Covered Square has landed on: a thick patch of moss grows on top.
var _moss_patches := {}


## Overgrowth card: the player's own moss patch {x0, x1, y, left (seconds), caught (enemies
## already tangled by it)}, or empty. Enemies that step on it are tangled for a moment.
var _overgrowth := {}
const OVERGROWTH_TIME := 5.0
const OVERGROWTH_TANGLE := 0.75
const OVERGROWTH_BOSS_TANGLE := 0.5
## Seconds after a patch grows before a landing can grow the next one.
const OVERGROWTH_COOLDOWN := 1.0
var _overgrowth_cd := 0.0


## The player landed at pos (feet) with Overgrowth: moss covers the ground 1.5 tiles each way,
## as far as that floor goes. A new patch replaces the old one.
func add_overgrowth(pos: Vector2) -> void:
	var cell := ground.local_to_map(ground.to_local(to_global(pos + Vector2(0.0, 6.0))))
	if ground.get_cell_source_id(cell) == -1 or _overgrowth_cd > 0.0:
		return
	_overgrowth_cd = OVERGROWTH_COOLDOWN
	var x0 := pos.x
	var x1 := pos.x
	for side in [-1, 1]:
		var reach := 0.0
		while reach < T * 1.5:
			var c := ground.local_to_map(ground.to_local(to_global(pos + Vector2(side * (reach + 8.0), 6.0))))
			if ground.get_cell_source_id(c) == -1 or ground.get_cell_source_id(c + Vector2i.UP) != -1:
				break
			reach += 8.0
		if side < 0:
			x0 = pos.x - reach
		else:
			x1 = pos.x + reach
	_overgrowth = {"x0": x0, "x1": x1, "y": cell.y * float(T), "left": OVERGROWTH_TIME, "caught": []}
	_moss_layer.queue_redraw()


func _physics_process(delta: float) -> void:
	_overgrowth_cd = maxf(_overgrowth_cd - delta, 0.0)
	if _overgrowth.is_empty():
		return
	_overgrowth.left -= delta
	if _overgrowth.left <= 0.0:
		_overgrowth = {}
		_moss_layer.queue_redraw()
		return
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not (t is BadBlock or t is BigBadSquare or t is MossBoss) or not t.visible or t in _overgrowth.caught:
			continue
		var half: Vector2 = t.half_size()
		var feet: float = t.position.y + half.y
		if absf(feet - _overgrowth.y) < 6.0 and t.position.x + half.x > _overgrowth.x0 \
				and t.position.x - half.x < _overgrowth.x1:
			_overgrowth.caught.append(t)
			t.stun(OVERGROWTH_TANGLE if t is BadBlock else OVERGROWTH_BOSS_TANGLE)   # bosses shake it off sooner
	_moss_layer.queue_redraw()


## True if the ground at this spot (local to the level) has a slippery moss patch on it.
func is_slippery(pos: Vector2) -> bool:
	return not _moss_patches.is_empty() \
		and _moss_patches.has(ground.local_to_map(ground.to_local(pos)))


## A Moss Covered Square landed with its feet at pos: about half the time, slippery moss grows
## on the block(s) under it.
func add_moss_patch(pos: Vector2, half_width := BadBlock.SIZE / 2.0 - 2.0, always := false) -> void:
	if not always and randf() >= 0.5:
		return
	for dx in [-half_width, half_width]:
		var cell := ground.local_to_map(ground.to_local(to_global(pos + Vector2(dx, 4.0))))
		if ground.get_cell_source_id(cell) != -1:
			_moss_patches[cell] = true
	_moss_layer.queue_redraw()
var _has_boss := false
## Blocks the Mossy Cave boss has thrown into the room (mossy ground tiles).
var _boss_blocks: Array[Vector2i] = []


## A thrown Moss Covered Square landed and turned into a mossy block here.
func add_boss_block(cell: Vector2i) -> void:
	ground.set_cell(cell, 0, ATLAS_GROUND_TOP)
	_boss_blocks.append(cell)
	_moss_cells.append(cell)
	_moss_patches.erase(cell + Vector2i.DOWN)   # covered up
	_moss_layer.queue_redraw()


## All the boss's blocks crumble away.
func clear_boss_blocks(with_fx := true) -> void:
	for cell in _boss_blocks:
		ground.erase_cell(cell)
		_moss_cells.erase(cell)
		if with_fx:
			CardFx.spawn(self, Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0), "bark")
	_boss_blocks.clear()
	_moss_layer.queue_redraw()


func _ready() -> void:
	goal.reached.connect(func() -> void: goal_reached.emit())
	for i in 2:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		col.shape = RectangleShape2D.new()
		body.add_child(col)
		add_child(body)
		_walls.append(col)
	_teleporters = Node2D.new()
	_teleporters.name = "Teleporters"
	add_child(_teleporters)
	_pickups = Node2D.new()
	_pickups.name = "Pickups"
	add_child(_pickups)
	_obstacles = Node2D.new()
	_obstacles.name = "Obstacles"
	add_child(_obstacles)
	_chests = Node2D.new()
	_chests.name = "Chests"
	add_child(_chests)
	_pixels = Node2D.new()
	_pixels.name = "Pixels"
	add_child(_pixels)
	_moss_layer = Node2D.new()   # over the tiles, so the moss covers the blocks
	_moss_layer.name = "MossBlocks"
	add_child(_moss_layer)
	_moss_layer.draw.connect(_draw_moss_blocks)
	water = Water.new()
	water.name = "Water"
	add_child(water)
	_doors = Node2D.new()
	_doors.name = "Doors"
	add_child(_doors)
	move_child(_doors, 0)   # buildings behind everything else
	_checkpoints = Node2D.new()
	_checkpoints.name = "Checkpoints"
	add_child(_checkpoints)
	if map_file != "":
		load_map_text(FileAccess.get_file_as_string(map_file))
	else:
		_update_walls()


## Builds the level from a text map (see the character list at the top of this file).
func load_map_text(text: String) -> void:
	ground.clear()
	var cells := {}
	var start_cell := Vector2i(-1, -1)
	var goal_cell := Vector2i(-1, -1)
	var pads := {}   # color name -> Array of cells, in reading order
	var hearts: Array[Vector2i] = []
	var chests: Array[Vector2i] = []
	var pixel_cells: Array[Vector2i] = []
	var cards := {}   # cell -> ability
	var spikes: Array[Vector2i] = []
	var vspikes: Array[Vector2i] = []
	var platforms := {}   # cell -> spikes on top?
	var bad_blocks: Array[Vector2i] = []
	_hard_cells.clear()
	_mossy_cells.clear()
	_moss_patches.clear()
	_overgrowth = {}
	_overgrowth_cd = 0.0
	var vine_cells: Array[Vector2i] = []
	var moss_bosses: Array[Vector2i] = []
	var simple_blocks: Array[Vector2i] = []
	_boss_blocks.clear()
	var doors := {}   # cell -> door character
	var checkpoints: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var crumbles: Array[Vector2i] = []
	var bosses: Array[Vector2i] = []
	_back_doors.clear()
	_moss_cells.clear()
	var lines := text.replace("\r", "").split("\n")
	for y in lines.size():
		var line: String = lines[y]
		for x in line.length():
			var ch := line[x]
			match ch:
				"#", "=", "R", "W", "^":
					cells[Vector2i(x, y)] = ch
				"P":
					start_cell = Vector2i(x, y)
				"G":
					goal_cell = Vector2i(x, y)
				"H":
					hearts.append(Vector2i(x, y))
				"D", "Q", "J", "L", "K", "E", "I", "F", "Z", "U", "O", "Y", "N", "h", "w", "b", "s", "p", "A", "M", "X":
					cards[Vector2i(x, y)] = AbilityCard.LETTERS[ch]
				"S":
					spikes.append(Vector2i(x, y))
				"C":
					chests.append(Vector2i(x, y))
				"*":
					pixel_cells.append(Vector2i(x, y))
				"V":
					vspikes.append(Vector2i(x, y))
				"e", "k":
					bad_blocks.append(Vector2i(x, y))
					if ch == "k":
						_hard_cells[Vector2i(x, y)] = true
				"@":
					checkpoints.append(Vector2i(x, y))
				"c":
					crumbles.append(Vector2i(x, y))
				"n":
					simple_blocks.append(Vector2i(x, y))
				"o":
					cells[Vector2i(x, y)] = "#"
					_moss_cells.append(Vector2i(x, y))
				"m":
					bosses.append(Vector2i(x, y))
				"y":
					moss_bosses.append(Vector2i(x, y))
				"q":
					bad_blocks.append(Vector2i(x, y))
					_mossy_cells[Vector2i(x, y)] = true
				"v":
					vine_cells.append(Vector2i(x, y))
				"d":
					_back_doors.append(Vector2i(x, y))
				"~":
					water_cells.append(Vector2i(x, y))
				"!", "$", "&", "%", "(", ")", "{", "}", "[", "]", "f", "l":
					doors[Vector2i(x, y)] = ch
				"T", "B":
					platforms[Vector2i(x, y)] = ch == "T"
				"1", "2", "3":
					var color_name: String = TELEPORT_COLORS[ch]
					if not pads.has(color_name):
						pads[color_name] = []
					pads[color_name].append(Vector2i(x, y))
	for cell in cells:
		ground.set_cell(cell, 0, _atlas_for(cells, cell))

	if start_cell.x >= 0:
		start.position = Vector2(start_cell.x * T + T / 2.0, (start_cell.y + 1) * T - 12.0)
	if goal_cell.x >= 0:
		goal.position = Vector2(goal_cell.x * T + T / 2.0, (goal_cell.y + 1) * T - 18.0)
		goal.show()
		goal.set_deferred("monitoring", true)
	else:
		goal.hide()
		goal.set_deferred("monitoring", false)
	_place_teleporters(pads)
	_place_doors(doors)
	_place_checkpoints(checkpoints)
	_place_chests(chests)
	_place_pixels(pixel_cells)
	_place_hearts(hearts, cards)
	_place_spikes(spikes, vspikes, platforms, bad_blocks)
	for cell in crumbles:
		var cb := CrumbleBlock.new()
		cb.position = Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0)
		_obstacles.add_child(cb)
	for cell in simple_blocks:
		var sb := SimpleBlock.new()
		sb.position = Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0)
		_obstacles.add_child(sb)
	for cell in vine_cells:
		var vp := VinePlatform.new()
		vp.position = Vector2(cell.x * T + T / 2.0, cell.y * T + VinePlatform.THICK / 2.0)
		_obstacles.add_child(vp)
	_has_boss = not bosses.is_empty()
	for cell in bosses:
		var boss := BigBadSquare.new()
		boss.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - BigBadSquare.SIZE / 2.0)
		boss.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		boss.defeated.connect(func(_pos: Vector2) -> void: boss_defeated.emit())
		_obstacles.add_child(boss)
	for cell in moss_bosses:
		_has_boss = true
		var mb := MossBoss.new()
		mb.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - MossBoss.SIZE / 2.0)
		mb.room = self
		mb.floor_row = cell.y + 1
		mb.min_col = 1
		mb.max_col = lines[cell.y].length() - 2
		for c in cells:   # he hangs under the middle of the highest floating platform
			if cells[c] == "=" and (mb.perch_cell.y > c.y or cells.get(mb.perch_cell, "") != "="):
				mb.perch_cell = c + Vector2i(1, 0)
		mb.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		mb.defeated.connect(func(_pos: Vector2) -> void: boss_defeated.emit())
		mb.landed.connect(func(pos: Vector2) -> void: add_moss_patch(pos, MossBoss.SIZE / 2.0 - 4.0, true))
		_obstacles.add_child(mb)
	water.setup(water_cells)
	_moss_layer.queue_redraw()
	_update_walls()
	queue_redraw()


## Pads float in their cell like the goal. Each pad links to the next one of its color
## (with two pads, that's each other); a pad with no partner stays dormant.
func _place_teleporters(pads: Dictionary) -> void:
	for child in _teleporters.get_children():
		_teleporters.remove_child(child)
		child.queue_free()
	if teleporter_scene == null:
		return
	for color_name in pads:
		var group: Array[Teleporter] = []
		for cell in pads[color_name]:
			var t := teleporter_scene.instantiate() as Teleporter
			t.color_name = color_name
			t.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - 18.0)
			_teleporters.add_child(t)
			group.append(t)
		if group.size() >= 2:
			for i in group.size():
				group[i].partner = group[(i + 1) % group.size()]


func _place_hearts(cells: Array[Vector2i], cards: Dictionary) -> void:
	for child in _pickups.get_children():
		_pickups.remove_child(child)
		child.queue_free()
	for cell in cells:
		var h := HeartPickup.new()
		h.position = Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0)
		h.collected.connect(func() -> void: heart_collected.emit())
		h.can_collect = func() -> bool: return not heart_check.is_valid() or heart_check.call()
		_pickups.add_child(h)
	for cell in cards:
		var c := AbilityCard.new()
		c.ability = cards[cell]
		c.position = Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0)
		c.collected.connect(func(a: String) -> void: card_collected.emit(a))
		_pickups.add_child(c)


func _place_spikes(cells: Array[Vector2i], vertical_cells: Array[Vector2i], platforms: Dictionary,
		bad_blocks: Array[Vector2i] = []) -> void:
	for child in _obstacles.get_children():
		_obstacles.remove_child(child)
		child.queue_free()
	for cell in cells + vertical_cells:
		var s := SpikeSquare.new()
		s.vertical = cell in vertical_cells
		s.position = Vector2(cell.x * T + T / 2.0, cell.y * T + T / 2.0)
		s.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		s.broken.connect(func(pos: Vector2) -> void: obstacle_broken.emit(pos, "spike"))
		_obstacles.add_child(s)
	for cell in bad_blocks:
		var e := BadBlock.new()
		e.hard = _hard_cells.has(cell)
		e.mossy = _mossy_cells.has(cell)
		e.landed.connect(func(pos: Vector2) -> void: add_moss_patch(pos))
		e.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - BadBlock.SIZE / 2.0)
		e.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		e.broken.connect(func(pos: Vector2) -> void:
			obstacle_broken.emit(pos, "moss_square" if e.mossy else "bad_block"))
		_obstacles.add_child(e)
	for cell in platforms:
		var p := SpikePlatform.new()
		p.spikes_top = platforms[cell]
		# Hurdles sit on the floor of their cell; bridges sit near the top of theirs.
		var y: float = (cell.y + 1) * T - SpikePlatform.THICK / 2.0 if p.spikes_top else cell.y * T + SpikePlatform.THICK / 2.0
		p.position = Vector2(cell.x * T + T / 2.0, y)
		p.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		_obstacles.add_child(p)


## Bring back every heart pickup and send obstacles to their starting spots, for a new run.
func reset_pickups() -> void:
	for c in _checkpoints.get_children():
		c.set_active(false)
	for h in _pickups.get_children():
		h.reset()
	for s in _obstacles.get_children():
		s.reset()
	if _has_boss:
		_hide_goal()   # the exit only opens once the boss is beaten


func _hide_goal() -> void:
	goal.hide()
	goal.set_deferred("monitoring", false)


## The boss is beaten: the exit cube appears in front of the door on his side (the rightmost).
func open_boss_exit() -> void:
	if _back_doors.is_empty():
		# No door (a map made in the editor): the exit appears where its G was placed.
		goal.show()
		goal.set_deferred("monitoring", true)
		CardFx.spawn(self, goal.position, "pop")
		return
	var cell: Vector2i = _back_doors[0]
	for c in _back_doors:
		if c.x > cell.x:
			cell = c
	goal.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - 18.0)
	goal.show()
	goal.set_deferred("monitoring", true)
	CardFx.spawn(self, goal.position, "pop")


## Chests sit on the floor of their cell. Numbered in reading order, for the save file.
func _place_chests(cells: Array[Vector2i]) -> void:
	for child in _chests.get_children():
		_chests.remove_child(child)
		child.queue_free()
	for i in cells.size():
		var c := Chest.new()
		c.position = Vector2(cells[i].x * T + T / 2.0, (cells[i].y + 1) * T)
		c.opened.connect(func(_c: Chest) -> void: chest_opened.emit(i))
		_chests.add_child(c)


## Checkpoints stand on the floor of their cell. The respawn spot is like the start's.
func _place_checkpoints(cells: Array[Vector2i]) -> void:
	for child in _checkpoints.get_children():
		_checkpoints.remove_child(child)
		child.queue_free()
	for cell in cells:
		var c := Checkpoint.new()
		c.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T)
		var spot := Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - 12.0)
		c.reached.connect(func(_c: Checkpoint) -> void: checkpoint_reached.emit(spot))
		_checkpoints.add_child(c)


## Town buildings stand on the floor of their cell.
func _place_doors(doors: Dictionary) -> void:
	for child in _doors.get_children():
		_doors.remove_child(child)
		child.queue_free()
	for cell in doors:
		var d := TownDoor.new()
		d.kind = TownDoor.KINDS[doors[cell]]
		d.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T)
		d.near_changed.connect(func(door: TownDoor, near: bool) -> void: door_near.emit(door.kind, near))
		_doors.add_child(d)


func _place_pixels(cells: Array[Vector2i]) -> void:
	for child in _pixels.get_children():
		_pixels.remove_child(child)
		child.queue_free()
	for i in cells.size():
		var p := PixelPickup.new()
		p.position = Vector2(cells[i].x * T + T / 2.0, cells[i].y * T + T / 2.0)
		p.collected.connect(func(_p: PixelPickup) -> void: pixel_collected.emit(i))
		_pixels.add_child(p)


func get_pixels() -> Array[Node]:
	return _pixels.get_children()


func get_doors() -> Array[Node]:
	return _doors.get_children()


func get_chests() -> Array[Node]:
	return _chests.get_children()


func get_teleporters() -> Array[Node]:
	return _teleporters.get_children()


func _atlas_for(cells: Dictionary, cell: Vector2i) -> Vector2i:
	match cells[cell]:
		"=":
			return ATLAS_PLATFORM
		"R":
			return ATLAS_RUBBER
		"W":
			return ATLAS_RUBBER_WALL
		"^":
			return ATLAS_ONE_WAY
	var above: String = cells.get(cell + Vector2i.UP, "")
	return ATLAS_GROUND_FILL if above in ["#", "R", "W"] else ATLAS_GROUND_TOP


## The playable area: from the top of the screen down to the lowest tile.
func get_bounds() -> Rect2:
	var used := ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2(0, 0, 960, 544)
	var ts := Vector2(ground.tile_set.tile_size)
	return Rect2(used.position.x * ts.x, 0.0, used.size.x * ts.x, used.end.y * ts.y)


## Invisible walls at both ends so the player can't leave the level sideways.
func _update_walls() -> void:
	var b := get_bounds()
	var rects := [
		Rect2(b.position.x - 32.0, -1000.0, 32.0, b.size.y + 2000.0),
		Rect2(b.end.x, -1000.0, 32.0, b.size.y + 2000.0),
	]
	for i in 2:
		var r: Rect2 = rects[i]
		(_walls[i].shape as RectangleShape2D).size = r.size
		_walls[i].position = r.get_center()


func set_theme(t: String) -> void:
	theme = t
	ground.modulate = Color(0.62, 0.86, 0.6) if t == "moss" else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if theme == "moss":
		_draw_moss()
	for cell in _back_doors:
		_draw_back_door(cell)
	# A faint tile grid behind the level.
	var b := get_bounds()
	var step := float(T)
	var x := b.position.x + step
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), grid_color)
		x += step
	var y := b.position.y + step
	while y < b.end.y:
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), grid_color)
		y += step


## A wooden door set into the back wall, 2 tiles tall, standing on the floor of its cell.
func _draw_back_door(cell: Vector2i) -> void:
	var w := 40.0
	var h := 60.0
	var x := cell.x * T + T / 2.0 - w / 2.0
	var y := (cell.y + 1) * T - h
	draw_rect(Rect2(x - 4, y - 4, w + 8, h + 4), Color("8a5a32"))      # frame
	draw_rect(Rect2(x, y, w, h), Color("5a3a22"))                      # door
	for i in 3:
		draw_rect(Rect2(x + 4 + i * 12, y + 4, 8, h - 8), Color("6b4428"))   # planks
	draw_rect(Rect2(x, y + 14, w, 3), Color("3f2817"))
	draw_rect(Rect2(x, y + h - 18, w, 3), Color("3f2817"))
	draw_rect(Rect2(x + w - 10, y + h / 2.0, 4, 4), Color("e0a35a"))   # knob


## A block wrapped in moss: green over the top and down the sides, with tufts and a vine.
func _draw_moss_blocks() -> void:
	for cell in _moss_cells:
		_draw_moss_block(_moss_layer, cell)
	if not _overgrowth.is_empty():
		# Overgrowth: bright leafy moss that withers away over its last second.
		var fade := clampf(_overgrowth.left, 0.0, 1.0)
		var grow := clampf((OVERGROWTH_TIME - _overgrowth.left) / 0.2, 0.0, 1.0)
		var mid: float = (_overgrowth.x0 + _overgrowth.x1) / 2.0
		var hw: float = (_overgrowth.x1 - _overgrowth.x0) / 2.0 * grow
		var oy: float = _overgrowth.y
		_moss_layer.draw_rect(Rect2(mid - hw, oy - 4, hw * 2.0, 8), Color("58c244", fade))
		var lx := mid - hw + 3.0
		var n := 0
		while lx < mid + hw - 3.0:
			_moss_layer.draw_rect(Rect2(lx, oy - 8 - (n * 5) % 4, 3, 6), Color("9be87a", fade))
			if n % 4 == 1:
				_moss_layer.draw_rect(Rect2(lx - 1, oy - 12, 4, 4), Color("f2e27a", fade))   # little flowers
			lx += 7.0
			n += 1
	for cell in _moss_patches:
		var x: float = cell.x * T
		var y: float = cell.y * T
		_moss_layer.draw_rect(Rect2(x - 1, y - 5, T + 2, 11), Color("3f8f2f"))
		_moss_layer.draw_rect(Rect2(x + 2, y + 6, 6, 5), Color("3f8f2f"))
		_moss_layer.draw_rect(Rect2(x + 20, y + 6, 8, 7), Color("3f8f2f"))
		for i in 5:
			_moss_layer.draw_rect(Rect2(x + 2 + i * 6, y - 9 + (i * 7) % 3, 3, 5), Color("7fd45f"))


func _draw_moss_block(c: CanvasItem, cell: Vector2i) -> void:
	var x := cell.x * T
	var y := cell.y * T
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 31 + cell.y
	c.draw_rect(Rect2(x, y, T, T), Color(0.31, 0.6, 0.24, 0.45))
	c.draw_rect(Rect2(x, y - 3, T, 7), Color("4f9a3c"))
	for side in [x, x + T - 4]:
		c.draw_rect(Rect2(side, y + 4, 4, rng.randi_range(8, 20)), Color("4f9a3c"))
	for i in 4:
		c.draw_rect(Rect2(x + rng.randi_range(2, T - 6), y - 3 - rng.randi_range(2, 6), 3, 5), Color("6cc04f"))
	for i in 3:
		c.draw_rect(Rect2(x + rng.randi_range(4, T - 8), y + rng.randi_range(8, T - 8), 4, 3), Color("6cc04f"))


## Mossy Cave: tufts of moss along every top surface and a few vines hanging under ledges.
func _draw_moss() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for cell in ground.get_used_cells():
		var above := ground.get_cell_source_id(cell + Vector2i.UP) == -1
		var below := ground.get_cell_source_id(cell + Vector2i.DOWN) == -1
		var x := cell.x * T
		var y := cell.y * T
		if above:
			draw_rect(Rect2(x, y - 3, T, 5), Color("4f9a3c"))
			for i in 3:
				var tx := x + rng.randi_range(2, T - 6)
				draw_rect(Rect2(tx, y - 3 - rng.randi_range(2, 5), 3, 4), Color("6cc04f"))
		if below and rng.randf() < 0.35:
			var len := rng.randi_range(14, 44)
			var vx := x + rng.randi_range(6, T - 6)
			draw_line(Vector2(vx, y + T), Vector2(vx, y + T + len), Color("3f7f31"), 2.0)
			for k in range(8, len, 10):
				draw_rect(Rect2(vx - 3, y + T + k, 3, 3), Color("5fb047"))
