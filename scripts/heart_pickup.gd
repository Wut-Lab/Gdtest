class_name HeartPickup
extends Area2D
## An extra heart floating in the level (H in a text map). Touch it to gain a heart.
## At full health it isn't picked up, so it stays for later.

signal collected

const BLOCK := 3.0

var _t := 0.0
## Asked before picking up; the level sets it to check the player isn't at full health.
var can_collect := func() -> bool: return true


func _ready() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 22)
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and visible and can_collect.call():
		hide()
		set_deferred("monitoring", false)
		collected.emit()


## Put it back for a new run.
func reset() -> void:
	show()
	set_deferred("monitoring", true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := HeartArt.size(BLOCK)
	var c := Vector2(0, sin(_t * 2.5) * 2.0)
	var glow := 1.0 + sin(_t * 4.0) * 0.08
	draw_rect(Rect2(c - Vector2(15, 15) * glow, Vector2(30, 30) * glow), Color(HeartArt.BODY, 0.2))
	HeartArt.draw(self, c - s / 2.0, BLOCK)
