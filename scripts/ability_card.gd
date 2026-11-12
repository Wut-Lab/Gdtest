class_name AbilityCard
extends Area2D
## An ability card floating in the level. Touch it to gain its ability for this run.
##   D = Dash, Q = Ground Pound, J = Double Jump, L = Glide, K = Quick, E = Tele-hop,
##   X = Heart Box (in a text map)

signal collected(ability: String)

const LETTERS := {"D": "dash", "Q": "pound", "J": "double_jump", "L": "glide", "K": "quick",
	"E": "tele_hop", "X": "heart_box"}
const NAMES := {"dash": "Dash", "pound": "Ground Pound", "double_jump": "Double Jump", "glide": "Glide",
	"quick": "Quick", "tele_hop": "Tele-hop", "heart_box": "Heart Box"}
## Card types, color coded: attacks are red, jumps are blue, movement is yellow, misc is gray.
const TYPES := {"dash": "attack", "pound": "attack", "double_jump": "jump", "glide": "jump",
	"quick": "movement", "tele_hop": "movement", "heart_box": "misc"}
const TYPE_NAMES := {"attack": "Attack card", "jump": "Jump card", "movement": "Movement card", "misc": "Misc card"}
const TYPE_COLORS := {"attack": Color("e5484d"), "jump": Color("3d7be0"), "movement": Color("e0a400"),
	"misc": Color("7d8597")}
## How each card reads in the menus: active cards say how to use them, passives start "Passive:".
const DESCRIPTIONS := {
	"dash": "Press Dash (Shift, X or K) to burst forward the way you're facing. You get one dash "
		+ "per jump in the air. Dashing into an up-down spike square breaks it.",
	"pound": "Press Ground Pound (Down, S or J) in the air to slam straight down. Pounding onto "
		+ "a spike square breaks it, and you bounce off. Hold jump as you land to spring back up.",
	"double_jump": "Press jump again in the air for one extra jump, 75% as high as a full jump. "
		+ "It recharges when you land.",
	"glide": "Hold jump while falling to drift down slowly and steer farther across gaps. "
		+ "Let go to fall normally.",
	"quick": "Passive: you run 25% faster while this card is equipped.",
	"tele_hop": "Passive: when you come out of a teleporter, you hop straight up, half as high "
		+ "as a full jump.",
	"heart_box": "Passive: you start every run with one extra heart (3 instead of 2).",
}
const PAPER := Color("eef1fa")
const EDGE := Color("1b2440")

@export_enum("dash", "pound", "double_jump", "glide", "quick", "tele_hop", "heart_box") var ability := "dash"

var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 28)
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and visible:
		hide()
		set_deferred("monitoring", false)
		collected.emit(ability)


## Put it back for a new run.
func reset() -> void:
	show()
	set_deferred("monitoring", true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var o := Vector2(0, sin(_t * 2.5) * 2.0)
	var glow := 1.0 + sin(_t * 4.0) * 0.08
	draw_rect(Rect2(o - Vector2(17, 21) * glow, Vector2(34, 42) * glow), Color(color_of(ability), 0.22))
	draw_card(self, ability, o)


static func color_of(ability_name: String) -> Color:
	return TYPE_COLORS[TYPES[ability_name]]


## Draws a card centered on o, 24×32 times scale: a border and thick bottom bar in the card
## type's color, a white field with the ability's picture, and (big cards) the name in the bar.
## Shared by the pickups in the level and the pause menu's Cards page.
static func draw_card(ci: CanvasItem, ability_name: String, o: Vector2, scale := 1.0,
		show_name := false) -> void:
	var c := color_of(ability_name)
	ci.draw_set_transform(o, 0.0, Vector2(scale, scale))
	ci.draw_rect(Rect2(-12, -16, 24, 32), c)
	ci.draw_rect(Rect2(-10, -14, 20, 21), PAPER)
	ci.draw_rect(Rect2(-12, 8, 24, 8), c.darkened(0.15))
	ci.draw_rect(Rect2(-12, 8, 24, 1), c.darkened(0.35))
	_draw_symbol(ci, ability_name, Vector2(0, -6), c)
	ci.draw_set_transform(Vector2.ZERO)
	if show_name:
		var font := ThemeDB.fallback_font
		var text: String = NAMES[ability_name]
		var fs := int(5.0 * scale)
		while fs > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 21.0 * scale:
			fs -= 1
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := o + Vector2(-w / 2.0, 12.0 * scale + fs * 0.35)
		ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER)


## The ability's picture, built from 2×2 blocks, centered on o.
static func _draw_symbol(ci: CanvasItem, ability_name: String, o: Vector2, c: Color) -> void:
	var b := 2.0   # symbol block size
	match ability_name:
		"dash":
			# Two right-pointing chevrons.
			for cx in [-5.0, 1.0]:
				for i in 5:
					var dx: float = (2.0 - absf(i - 2.0)) * b
					ci.draw_rect(Rect2(o + Vector2(cx + dx, -3.0 + i * b), Vector2(b, b)), c)
		"pound":
			# A down arrow onto a ground line.
			ci.draw_rect(Rect2(o + Vector2(-1, -5), Vector2(b, 8)), c)
			for i in 3:
				var w := (5 - i * 2) * b
				ci.draw_rect(Rect2(o + Vector2(-w / 2.0, 1 + i * b), Vector2(w, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-7, 9), Vector2(14, b)), c)
		"double_jump":
			# Two up-pointing chevrons.
			for cy in [-4.0, 3.0]:
				for i in 5:
					var dy: float = absf(i - 2.0) * b
					ci.draw_rect(Rect2(o + Vector2(-5.0 + i * b, cy + dy), Vector2(b, b)), c)
		"glide":
			# A little parachute: a domed canopy, two lines and a block below.
			ci.draw_rect(Rect2(o + Vector2(-4, -5), Vector2(8, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, -3), Vector2(12, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-7, -1), Vector2(14, b)), c)
			for i in 3:
				ci.draw_rect(Rect2(o + Vector2(-6 + i, 1 + i * b), Vector2(1, b)), c)
				ci.draw_rect(Rect2(o + Vector2(5 - i, 1 + i * b), Vector2(1, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-2, 7), Vector2(4, 4)), c)
		"quick":
			# Speed lines trailing a running block.
			ci.draw_rect(Rect2(o + Vector2(1, -2), Vector2(6, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(-7, -2), Vector2(6, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-5, 1), Vector2(4, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, 4), Vector2(7, b)), c)
			ci.draw_rect(Rect2(o + Vector2(1, 6), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(5, 6), Vector2(b, b)), c)
		"heart_box":
			# A blocky heart inside a box.
			ci.draw_rect(Rect2(o + Vector2(-9, -8), Vector2(18, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 8), Vector2(18, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, -8), Vector2(b, 18)), c)
			ci.draw_rect(Rect2(o + Vector2(7, -8), Vector2(b, 18)), c)
			HeartArt.draw(ci, o - HeartArt.size(1.5) / 2.0 + Vector2(0, 1), 1.5)
		"tele_hop":
			# An up arrow rising out of a teleport pad.
			ci.draw_rect(Rect2(o + Vector2(-1, -2), Vector2(b, 6)), c)
			for i in 3:
				var w := (1 + i * 2) * b
				ci.draw_rect(Rect2(o + Vector2(-w / 2.0, -6 + i * b), Vector2(w, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, 5), Vector2(12, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, 9), Vector2(12, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, 5), Vector2(b, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(4, 5), Vector2(b, 6)), c)
