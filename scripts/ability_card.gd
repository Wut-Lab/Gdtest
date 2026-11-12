class_name AbilityCard
extends Area2D
## An ability card floating in the level. Touch it to gain its ability for this run.
##   D = Dash, Q = Ground Pound, J = Double Jump, L = Glide, K = Quick, E = Tele-hop,
##   I = High Jump, F = Phase Jump, Z = Shockwave, U = Stunning Landing,
##   O = Grip and Go, Y = Lucky Charm, N = Bounce House,
##   s = Slow Burst, p = Portion Booster, A = Air Brake, M = Momentum, X = Heart Box (in a text map)

signal collected(ability: String)

const LETTERS := {"D": "dash", "Q": "pound", "J": "double_jump", "L": "glide", "K": "quick",
	"E": "tele_hop", "I": "high_jump", "F": "phase_jump", "Z": "shockwave", "U": "stun_landing", "O": "grip_and_go", "Y": "lucky_charm", "N": "bounce_house", "s": "slow_burst", "p": "portion_booster", "A": "air_brake", "M": "momentum", "X": "heart_box"}
const NAMES := {"dash": "Dash", "pound": "Ground Pound", "double_jump": "Double Jump", "glide": "Glide",
	"quick": "Quick", "tele_hop": "Tele-hop", "high_jump": "High Jump", "phase_jump": "Phase Jump", "shockwave": "Shockwave", "stun_landing": "Stunning Landing", "grip_and_go": "Grip and Go", "lucky_charm": "Lucky Charm", "bounce_house": "Bounce House", "slow_burst": "Slow Burst",
	"portion_booster": "Portion Booster", "air_brake": "Air Brake", "momentum": "Momentum", "heart_box": "Heart Box"}
## Card types, color coded: attacks are red, jumps are blue, movement is yellow, misc is gray.
const TYPES := {"dash": "attack", "pound": "attack", "double_jump": "jump", "glide": "jump",
	"quick": "movement", "tele_hop": "movement", "high_jump": "jump", "phase_jump": "jump", "shockwave": "attack", "stun_landing": "attack", "grip_and_go": "movement", "lucky_charm": "misc", "bounce_house": "misc", "slow_burst": "misc", "portion_booster": "misc", "air_brake": "movement", "momentum": "movement", "heart_box": "misc"}
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
	"high_jump": "Passive: your jumps go 20% higher.",
	"phase_jump": "Passive: at the top of every jump you phase out for a split second, and "
		+ "nothing can hurt you until you phase back in.",
	"shockwave": "Passive: when you land a Ground Pound, a shockwave rolls along the floor and "
		+ "pushes nearby spike squares and spiked platforms 2 tiles away. Needs Ground Pound; recharges in 2.5 seconds.",
	"stun_landing": "Passive: land on a spike square or spiked platform, or within 1 tile of one, "
		+ "to stun it. It stops moving for 3 seconds.",
	"grip_and_go": "Passive: land after moving at least 2 tiles sideways in the air, and you "
		+ "dash on for 75% of that distance.",
	"lucky_charm": "Passive: you have a 20% chance to shrug off a hit from a spike square or "
		+ "spiked platform and keep your heart.",
	"bounce_house": "Passive: rubber bounces you 25% higher, and landing on normal ground from "
		+ "a big fall gives you a little bounce.",
	"slow_burst": "Passive: when you get hurt, every obstacle within 3 tiles of you moves at half "
		+ "speed for 3 seconds.",
	"portion_booster": "Passive: every percentage on your equipped attack, jump and movement "
		+ "cards goes up 5 points (Quick runs 30% faster, High Jump goes 25% higher...).",
	"air_brake": "Passive: you steer much more sharply in the air, and stop almost at once when "
		+ "you let go.",
	"momentum": "Passive: keep running without stopping or turning to build up speed, up to "
		+ "25% faster after 2 seconds.",
	"heart_box": "Passive: you start every run with one extra heart (3 instead of 2).",
}
const PAPER := Color("eef1fa")
const EDGE := Color("1b2440")

@export_enum("dash", "pound", "double_jump", "glide", "quick", "tele_hop", "high_jump", "phase_jump", "shockwave", "stun_landing", "grip_and_go", "lucky_charm", "bounce_house", "slow_burst", "portion_booster", "air_brake", "momentum", "heart_box") var ability := "dash"

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
		"high_jump":
			# A tall up arrow over a short bar.
			ci.draw_rect(Rect2(o + Vector2(-1, -5), Vector2(b, 12)), c)
			for i in 3:
				var w := (1 + i * 2) * b
				ci.draw_rect(Rect2(o + Vector2(-w / 2.0, -9 + i * b), Vector2(w, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, 9), Vector2(12, b)), c)
		"phase_jump":
			# A solid block with a faded copy of it above, at the top of its arc.
			ci.draw_rect(Rect2(o + Vector2(-3, 3), Vector2(6, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(-3, -9), Vector2(6, 6)), Color(c, 0.4))
			ci.draw_rect(Rect2(o + Vector2(-7, -5), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(5, -5), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, -1), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(7, -1), Vector2(b, b)), c)
		"shockwave":
			# A block on the ground with waves rolling out both ways.
			ci.draw_rect(Rect2(o + Vector2(-3, -6), Vector2(6, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 2), Vector2(18, b)), c)
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(o + Vector2(side * 6.0 - 1.0, -2), Vector2(b, 3)), c)
				ci.draw_rect(Rect2(o + Vector2(side * 9.0 - 1.0, -4), Vector2(b, 5)), c)
			ci.draw_rect(Rect2(o + Vector2(-7, 6), Vector2(14, b)), c)
		"stun_landing":
			# A lightning bolt striking a ground line.
			for p in [Vector2(1, -9), Vector2(-1, -7), Vector2(-3, -5), Vector2(-1, -3), Vector2(1, -3),
					Vector2(3, -3), Vector2(1, -1), Vector2(-1, 1), Vector2(-3, 3)]:
				ci.draw_rect(Rect2(o + p, Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 7), Vector2(18, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, 4), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(6, 4), Vector2(b, b)), c)
		"grip_and_go":
			# A block landing on a ground line with a dash chevron in front of it.
			ci.draw_rect(Rect2(o + Vector2(-8, -2), Vector2(6, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 6), Vector2(18, b)), c)
			for i in 5:
				var dx: float = (2.0 - absf(i - 2.0)) * b
				ci.draw_rect(Rect2(o + Vector2(1.0 + dx, -6.0 + i * b), Vector2(b, b)), c)
		"lucky_charm":
			# A blocky four-leaf clover with a stem.
			for p in [Vector2(-5, -7), Vector2(1, -7), Vector2(-5, -1), Vector2(1, -1)]:
				ci.draw_rect(Rect2(o + p, Vector2(4, 4)), c)
			ci.draw_rect(Rect2(o + Vector2(-1, -3), Vector2(2, 2)), c)
			ci.draw_rect(Rect2(o + Vector2(1, 3), Vector2(b, 3)), c)
			ci.draw_rect(Rect2(o + Vector2(3, 6), Vector2(b, 3)), c)
		"bounce_house":
			# A block over a springy zigzag.
			ci.draw_rect(Rect2(o + Vector2(-3, -9), Vector2(6, 6)), c)
			for i in 5:
				var x := -8.0 + i * 4.0
				ci.draw_rect(Rect2(o + Vector2(x, 1.0 if i % 2 == 0 else 4.0), Vector2(4, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 8), Vector2(18, b)), c)
		"slow_burst":
			# A clock face: a square ring with two hands.
			ci.draw_rect(Rect2(o + Vector2(-8, -8), Vector2(16, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, 6), Vector2(16, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, -8), Vector2(b, 16)), c)
			ci.draw_rect(Rect2(o + Vector2(6, -8), Vector2(b, 16)), c)
			ci.draw_rect(Rect2(o + Vector2(-1, -5), Vector2(b, 6)), c)
			ci.draw_rect(Rect2(o + Vector2(-1, -1), Vector2(5, b)), c)
		"portion_booster":
			# A bottle with a plus on it.
			ci.draw_rect(Rect2(o + Vector2(-2, -9), Vector2(4, 4)), c)
			ci.draw_rect(Rect2(o + Vector2(-6, -5), Vector2(12, 14)), c)
			ci.draw_rect(Rect2(o + Vector2(-1, -2), Vector2(2, 8)), PAPER)
			ci.draw_rect(Rect2(o + Vector2(-4, 1), Vector2(8, 2)), PAPER)
		"air_brake":
			# A block stopped short against a wall, with brake marks behind it.
			ci.draw_rect(Rect2(o + Vector2(-3, -4), Vector2(7, 7)), c)
			ci.draw_rect(Rect2(o + Vector2(6, -8), Vector2(b, 16)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, -2), Vector2(3, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-9, 2), Vector2(4, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-7, 6), Vector2(10, b)), c)
		"momentum":
			# Three steps getting taller, with an arrow off the top one.
			ci.draw_rect(Rect2(o + Vector2(-8, 4), Vector2(4, 4)), c)
			ci.draw_rect(Rect2(o + Vector2(-3, 0), Vector2(4, 8)), c)
			ci.draw_rect(Rect2(o + Vector2(2, -4), Vector2(4, 12)), c)
			ci.draw_rect(Rect2(o + Vector2(-8, -6), Vector2(8, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-2, -8), Vector2(b, b)), c)
			ci.draw_rect(Rect2(o + Vector2(-2, -4), Vector2(b, b)), c)
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
