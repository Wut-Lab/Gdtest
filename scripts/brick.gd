class_name Brick
extends CharacterBody2D
## Brick Drop card: a one-tile stone brick that falls straight down and stays where it lands,
## riding along on moving obstacles. You can stand on it. Fades out after a while.

const T := 32.0
const FILL := Color("c9874f")
const LIGHT := Color("f0c08a")
const DARK := Color("6e3f1f")
const LIFE := 10.0

var _age := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(T, T)
	col.shape = shape
	add_child(col)
	velocity = Vector2(0.0, 300.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + 2200.0 * delta, 1100.0)
	velocity.x = 0.0
	move_and_slide()
	modulate.a = clampf((LIFE - _age) / 0.6, 0.0, 1.0)   # fade out at the end
	queue_redraw()


func _draw() -> void:
	var h := T / 2.0
	draw_rect(Rect2(-h, -h, T, T), DARK)
	draw_rect(Rect2(-h + 2, -h + 2, T - 4, T - 4), FILL)
	draw_rect(Rect2(-h + 2, -h + 2, T - 4, 4), LIGHT)
	# Mortar lines: two rows of bricks, offset.
	draw_rect(Rect2(-h + 2, -1, T - 4, 2), DARK)
	draw_rect(Rect2(-1, -h + 2, 2, h - 3), DARK)
	draw_rect(Rect2(-h + 9, 1, 2, h - 3), DARK)
	draw_rect(Rect2(h - 11, 1, 2, h - 3), DARK)
