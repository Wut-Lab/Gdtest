class_name Goal
extends Area2D
## The goal square. Emits `reached` when the player touches it.

signal reached

@export var color := Color("79e2c2")
@export var label_color := Color("eef1fa")

var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		reached.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(_t * 4.0) * 0.08
	var c := Vector2(0, sin(_t * 2.5) * 2.0)
	draw_rect(Rect2(c - Vector2(18, 18) * pulse, Vector2(36, 36) * pulse), Color(color, 0.25))
	draw_rect(Rect2(c - Vector2(12, 12) * pulse, Vector2(24, 24) * pulse), color)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -24), "GOAL",
		HORIZONTAL_ALIGNMENT_CENTER, 60, 13, label_color)
