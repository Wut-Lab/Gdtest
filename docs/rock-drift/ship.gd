extends Area2D

# How the ship handles. Change these in the Inspector.
@export var turn_speed := 3.5   # how fast it turns
@export var thrust := 400.0     # how hard the engine pushes
@export var max_speed := 500.0  # top speed
@export var drag := 40.0        # how quickly it slows down when coasting

var velocity := Vector2.ZERO
var crashed := false


func _ready() -> void:
	position = get_viewport_rect().size / 2
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	# Turn with left and right.
	var turn := Input.get_axis("ui_left", "ui_right")
	rotation += turn * turn_speed * delta

	# Push forward with up, or slowly coast to a stop.
	if Input.is_action_pressed("ui_up"):
		velocity += Vector2.RIGHT.rotated(rotation) * thrust * delta
	else:
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	velocity = velocity.limit_length(max_speed)
	position += velocity * delta

	# Leave one edge of the screen, come back on the other.
	var screen := get_viewport_rect().size
	position.x = wrapf(position.x, 0.0, screen.x)
	position.y = wrapf(position.y, 0.0, screen.y)
	queue_redraw()


# Something touched the ship: crash, and start the round again.
func _on_area_entered(_area: Area2D) -> void:
	if crashed:
		return   # already crashed: ignore any more hits
	crashed = true
	get_tree().reload_current_scene.call_deferred()   # wait until the collision check is done


func _draw() -> void:
	var body := PackedVector2Array([Vector2(16, 0), Vector2(-12, -10), Vector2(-6, 0), Vector2(-12, 10)])
	draw_colored_polygon(body, Color("ff6b5e"))
	if Input.is_action_pressed("ui_up"):
		var flame := PackedVector2Array([Vector2(-7, -4), Vector2(-18, 0), Vector2(-7, 4)])
		draw_colored_polygon(flame, Color("ffd23f"))
