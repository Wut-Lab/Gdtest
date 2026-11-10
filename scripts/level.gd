class_name Level
extends Node2D
## A level. Paint the Ground tile map in the editor, then move Start and Goal.
## The level's size comes from the painted tiles; the camera and the fall line follow it.

signal goal_reached

@export var grid_color := Color(0.93, 0.95, 0.98, 0.05)

@onready var ground: TileMapLayer = $Ground
@onready var start: Marker2D = $Start
@onready var goal: Goal = $Goal


func _ready() -> void:
	goal.reached.connect(func() -> void: goal_reached.emit())
	# Invisible walls at both ends so the player can't leave the level sideways.
	var b := get_bounds()
	_add_wall(Rect2(b.position.x - 32.0, -1000.0, 32.0, b.size.y + 2000.0))
	_add_wall(Rect2(b.end.x, -1000.0, 32.0, b.size.y + 2000.0))


## The playable area: from the top of the screen down to the lowest painted tile.
func get_bounds() -> Rect2:
	var used := ground.get_used_rect()
	var ts := Vector2(ground.tile_set.tile_size)
	return Rect2(used.position.x * ts.x, 0.0, used.size.x * ts.x, used.end.y * ts.y)


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.get_center()
	body.add_child(col)
	add_child(body)


func _draw() -> void:
	# A faint tile grid behind the level.
	var b := get_bounds()
	var step := float(ground.tile_set.tile_size.x)
	var x := b.position.x + step
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), grid_color)
		x += step
	var y := b.position.y + step
	while y < b.end.y:
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), grid_color)
		y += step
