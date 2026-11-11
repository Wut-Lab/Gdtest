class_name CardIcon
extends Control
## A card drawn in a menu: the card when something is equipped, or an empty outline.
## Big cards (card_scale above 1) also show the ability's name in their bottom bar.

var ability := "":
	set(v):
		ability = v
		queue_redraw()
var card_scale := 1.0:
	set(v):
		card_scale = v
		custom_minimum_size = Vector2(24.0, 32.0) * v + Vector2(6, 6)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_scale = 1.0


func _draw() -> void:
	var c := size / 2.0
	if ability != "":
		AbilityCard.draw_card(self, ability, c, card_scale, card_scale >= 2.5)
		return
	# Empty slot: a dashed card outline.
	var r := Rect2(c - Vector2(12, 16), Vector2(24, 32))
	var dim := Color(AbilityCard.PAPER, 0.3)
	for i in range(0, 24, 6):
		draw_rect(Rect2(r.position + Vector2(i, 0), Vector2(3, 2)), dim)
		draw_rect(Rect2(r.position + Vector2(i, 30), Vector2(3, 2)), dim)
	for i in range(0, 32, 6):
		draw_rect(Rect2(r.position + Vector2(0, i), Vector2(2, 3)), dim)
		draw_rect(Rect2(r.position + Vector2(22, i), Vector2(2, 3)), dim)
