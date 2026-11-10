extends Area2D
# This script makes one rock drift, spin and draw itself.

@export var speed := 80.0    # how fast it drifts
@export var radius := 30.0   # how big it is

var velocity := Vector2.ZERO           # speed and direction
var spin := 0.0                        # how fast it turns
var outline := PackedVector2Array()    # the corner points of its lumpy shape


func _ready() -> void:
	# Pick a random direction and spin, and a lumpy rock shape.
	velocity = Vector2.from_angle(randf() * TAU) * speed
	spin = randf_range(-1.5, 1.5)
	for i in 10:
		var angle := TAU * i / 10
		outline.append(Vector2.from_angle(angle) * radius * randf_range(0.75, 1.1))


# Every frame: move, spin, and wrap around the screen edges.
func _process(delta: float) -> void:
	position += velocity * delta
	rotation += spin * delta
	var screen := get_viewport_rect().size
	position.x = wrapf(position.x, -radius, screen.x + radius)
	position.y = wrapf(position.y, -radius, screen.y + radius)


func _draw() -> void:
	draw_colored_polygon(outline, Color("8a8fa8"))
