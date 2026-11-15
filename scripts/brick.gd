class_name Brick
extends CharacterBody2D
## Brick Drop card: a one-tile stone brick that falls straight down and stays where it lands,
## riding along on moving obstacles. You can stand on it. Fades out after a while.

const T := 32.0
const FILL := Color("c9874f")
const LIGHT := Color("f0c08a")
const DARK := Color("6e3f1f")
const LIFE := 10.0

## Brick Toss: the lob's starting velocity (zero for a dropped brick). While it's in flight
## it breaks the first spike square or enemy it hits (bosses and platforms just stop it).
var thrown := Vector2.ZERO
var _flying := false
var _age := 0.0


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(T, T)
	col.shape = shape
	add_child(col)
	velocity = Vector2(0.0, 300.0)
	if thrown != Vector2.ZERO:
		velocity = thrown
		_flying = true
		collision_mask = 1 | 4   # hit enemies too while it flies


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + 2200.0 * delta, 1100.0)
	if not _flying:
		velocity.x = 0.0
	move_and_slide()
	if _flying:
		_hit_targets()
		if is_on_floor() or is_on_wall():
			_land()
	modulate.a = clampf((LIFE - _age) / 0.6, 0.0, 1.0)   # fade out at the end
	queue_redraw()


## Breaks a spike square or enemy the flying brick touches.
func _hit_targets() -> void:
	for t in get_tree().get_nodes_in_group("card_targets"):
		if not t.visible or not (t is SpikeSquare or t is BadBlock or t is Piranha or t is Harpoonist):
			continue
		var half: Vector2 = t.half_size()
		var d: Vector2 = (t.global_position - global_position).abs()
		if d.x < half.x + T / 2.0 + 2.0 and d.y < half.y + T / 2.0 + 2.0:
			t.smash()
			_land()
			return


func _land() -> void:
	_flying = false
	velocity.x = 0.0
	collision_mask = 1


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
