class_name AbilityCard
extends Area2D
## An ability card floating in the level. Touch it to gain its ability for this run.
##   D = Dash, Q = Ground Pound, J = Double Jump (in a text map)

signal collected(ability: String)

const LETTERS := {"D": "dash", "Q": "pound", "J": "double_jump"}
const NAMES := {"dash": "Dash", "pound": "Ground Pound", "double_jump": "Double Jump"}
const COLORS := {"dash": Color("4da3ff"), "pound": Color("ff9f43"), "double_jump": Color("b388ff")}
const PAPER := Color("eef1fa")
const EDGE := Color("1b2440")

@export_enum("dash", "pound", "double_jump") var ability := "dash"

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
	var c: Color = COLORS[ability]
	var o := Vector2(0, sin(_t * 2.5) * 2.0)
	var glow := 1.0 + sin(_t * 4.0) * 0.08
	draw_rect(Rect2(o - Vector2(16, 19) * glow, Vector2(32, 38) * glow), Color(c, 0.22))
	# A small blocky card: dark edge, light paper, colored band, and the ability's symbol.
	draw_rect(Rect2(o + Vector2(-11, -14), Vector2(22, 28)), EDGE)
	draw_rect(Rect2(o + Vector2(-9, -12), Vector2(18, 24)), PAPER)
	draw_rect(Rect2(o + Vector2(-9, -12), Vector2(18, 5)), c)
	var b := 2.0   # symbol block size
	match ability:
		"dash":
			# Two right-pointing chevrons.
			for cx in [-5.0, 1.0]:
				for i in 5:
					var dx: float = (2.0 - absf(i - 2.0)) * b
					draw_rect(Rect2(o + Vector2(cx + dx, -3.0 + i * b), Vector2(b, b)), c)
		"pound":
			# A down arrow onto a ground line.
			draw_rect(Rect2(o + Vector2(-1, -5), Vector2(b, 8)), c)
			for i in 3:
				var w := (5 - i * 2) * b
				draw_rect(Rect2(o + Vector2(-w / 2.0, 1 + i * b), Vector2(w, b)), c)
			draw_rect(Rect2(o + Vector2(-7, 9), Vector2(14, b)), c)
		"double_jump":
			# Two up-pointing chevrons.
			for cy in [-4.0, 3.0]:
				for i in 5:
					var dy: float = absf(i - 2.0) * b
					draw_rect(Rect2(o + Vector2(-5.0 + i * b, cy + dy), Vector2(b, b)), c)
