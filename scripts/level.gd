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
	var doors := {}   # cell -> door character
	var checkpoints: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	var crumbles: Array[Vector2i] = []
	var bosses: Array[Vector2i] = []
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
				"m":
					bosses.append(Vector2i(x, y))
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
	for cell in bosses:
		var boss := BigBadSquare.new()
		boss.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - BigBadSquare.SIZE / 2.0)
		boss.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		boss.defeated.connect(func(_pos: Vector2) -> void: boss_defeated.emit())
		_obstacles.add_child(boss)
	water.setup(water_cells)
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
		e.position = Vector2(cell.x * T + T / 2.0, (cell.y + 1) * T - BadBlock.SIZE / 2.0)
		e.hurt_player.connect(func(push: Vector2) -> void: player_hurt.emit(push))
		e.broken.connect(func(pos: Vector2) -> void: obstacle_broken.emit(pos, "bad_block"))
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
