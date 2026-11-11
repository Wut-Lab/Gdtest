class_name PixelPickup
extends Area2D
## A pixel floating in the level (* in a text map). Touch it for 1 pixel, the currency.
## Main remembers collected ones in the save file, so each pays out once.

signal collected(pickup: PixelPickup)

var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and visible:
		set_taken(true)
		collected.emit(self)


## Hidden once taken (this run, or earlier in this save file).
func set_taken(v: bool) -> void:
	visible = not v
	set_deferred("monitoring", not v)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 2.0
	var glow := 0.18 + sin(_t * 4.0) * 0.06
	draw_rect(Rect2(-10, -10 + bob, 20, 20), Color(1, 1, 1, glow))
	PixelCounter.draw_icon(self, Vector2(-7, -7 + bob), 5.0)
