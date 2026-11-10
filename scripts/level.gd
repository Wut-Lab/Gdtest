class_name Level
extends Node2D
## A level. Either set Map File to a text map (the usual way), or clear it and paint the
## Ground tile map in the editor. The camera and the fall line follow the level's size.
##
## Text map characters, one per 32 px tile:
##   .  empty        #  ground        =  floating platform (jump up through it)
##   R  rubber       P  player start  G  goal

signal goal_reached

const T := 32
const ATLAS_GROUND_TOP := Vector2i(0, 0)
const ATLAS_GROUND_FILL := Vector2i(1, 0)
const ATLAS_PLATFORM := Vector2i(2, 0)
const ATLAS_RUBBER := Vector2i(3, 0)

@export_file("*.txt") var map_file := ""
@export var grid_color := Color(0.93, 0.95, 0.98, 0.05)

var _walls: Array[CollisionShape2D] = []

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
	var lines := text.replace("\r", "").split("\n")
	for y in lines.size():
		var line: String = lines[y]
		for x in line.length():
			var ch := line[x]
			match ch:
				"#", "=", "R":
					cells[Vector2i(x, y)] = ch
				"P":
					start_cell = Vector2i(x, y)
				"G":
					goal_cell = Vector2i(x, y)
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
	_update_walls()
	queue_redraw()


func _atlas_for(cells: Dictionary, cell: Vector2i) -> Vector2i:
	match cells[cell]:
		"=":
			return ATLAS_PLATFORM
		"R":
			return ATLAS_RUBBER
	var above: String = cells.get(cell + Vector2i.UP, "")
	return ATLAS_GROUND_FILL if above == "#" or above == "R" else ATLAS_GROUND_TOP


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


func _draw() -> void:
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
