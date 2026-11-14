class_name ShallowSpikes
extends Area2D
## Shallow spikes (, Cavern Lake): a low row of steel spikes on the floor of their cell. They never
## move and can't be broken; touching them costs a heart. Running water can push you into them.

signal hurt_player(push: Vector2)

const W := 30.0
const TALL := 10.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(W - 6.0, TALL - 3.0)
	col.shape = shape
	col.position = Vector2(0.0, -(TALL - 3.0) / 2.0)
	add_child(col)
	body_entered.connect(_touch)


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		_touch(b)


func _touch(b: Node) -> void:
	if b is Player:
		var dx: float = b.global_position.x - global_position.x
		hurt_player.emit(Vector2(signf(dx) if absf(dx) > 1.0 else -1.0, -1.0))


func reset() -> void:
	pass


func _draw() -> void:
	# Origin is the floor at the middle of the cell.
	draw_rect(Rect2(-W / 2.0, -3, W, 3), Color("4a5468"))
	for i in 5:
		var x := -W / 2.0 + 3.0 + i * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -3), Vector2(x + 3, -3), Vector2(x, -TALL)]),
			Color("c8d0de"))
		draw_line(Vector2(x, -TALL), Vector2(x + 3, -3), Color("7c8699"), 1.0)
