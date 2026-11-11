class_name CardIcon
extends Control
## A card drawn in a menu: the card when something is equipped, or an empty outline.
## Big cards (card_scale above 1) also show the ability's name in their bottom bar.
## Locked cards are a dark silhouette with a question mark; equipped ones get a green check.

var ability := "":
	set(v):
		ability = v
		queue_redraw()
var locked := false:
	set(v):
		locked = v
		queue_redraw()
var equipped := false:
	set(v):
		equipped = v
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
	if locked:
		draw_set_transform(c, 0.0, Vector2(card_scale, card_scale))
		draw_rect(Rect2(-12, -16, 24, 32), Color("2a3354"))
		draw_rect(Rect2(-10, -14, 20, 21), Color("1f2742"))
		# A blocky question mark.
		var q := Color("4a5680")
		for r in [Rect2(-4, -12, 8, 2), Rect2(2, -10, 2, 4), Rect2(-1, -6, 4, 2), Rect2(-1, -4, 2, 3), Rect2(-1, 1, 2, 2)]:
			draw_rect(r, q)
		draw_set_transform(Vector2.ZERO)
		return
	if ability != "":
		AbilityCard.draw_card(self, ability, c, card_scale, card_scale >= 2.5)
		if equipped:
			# Green check badge in the top-right corner.
			var p := c + Vector2(12, -16) * card_scale
			draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color("1b2440"))
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color("79e2c2"))
			for r in [Rect2(-4, 0, 2, 2), Rect2(-2, 2, 2, 2), Rect2(0, 0, 2, 2), Rect2(2, -2, 2, 2)]:
				draw_rect(Rect2(p + r.position, r.size), Color("1b2440"))
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
