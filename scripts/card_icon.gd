class_name CardIcon
extends Control
## One card slot in a menu: the card when something is equipped, or an empty outline.

var ability := "":
	set(v):
		ability = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(30, 34)


func _draw() -> void:
	var c := size / 2.0
	if ability != "":
		AbilityCard.draw_card(self, ability, c)
		return
	# Empty slot: a dashed card outline.
	var r := Rect2(c - Vector2(11, 14), Vector2(22, 28))
	var dim := Color(AbilityCard.PAPER, 0.3)
	for i in range(0, 22, 6):
		draw_rect(Rect2(r.position + Vector2(i, 0), Vector2(3, 2)), dim)
		draw_rect(Rect2(r.position + Vector2(i, 26), Vector2(3, 2)), dim)
	for i in range(0, 28, 6):
		draw_rect(Rect2(r.position + Vector2(0, i), Vector2(2, 3)), dim)
		draw_rect(Rect2(r.position + Vector2(20, i), Vector2(2, 3)), dim)
