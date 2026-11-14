class_name SimpleBlock
extends StaticBody2D
## Simple Block (n in a text map): a plain solid block, one tile, as a starting point for a new
## block type. It does nothing yet: you can stand on it and bump into it. The level generator
## doesn't place it; put it in a map by hand (or the editor) until it gets a job.
##
## To give it behaviour later, fill in the hooks below (they're already called by the level
## and the cards, like the other obstacles):
##   on_player_landed(): the player landed on top of it.
##   take_hit(kind): a dash ("dash") or ground pound ("pound") hit it. Return true if it reacts.
##   reset(): a new run of the level started (put it back the way it began).

const SIZE := 32.0
const BODY := Color("8a93b8")
const TOP := Color("b6bdd9")
const SHADE := Color("5b6386")
const EDGE := Color("1b2440")

var _origin := Vector2.ZERO
var _feet: Area2D


func _ready() -> void:
	add_to_group("card_targets")
	_origin = position
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	col.shape = shape
	add_child(col)
	# A thin strip on top that notices the player landing.
	_feet = Area2D.new()
	var fs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(SIZE - 4.0, 4.0)
	fs.shape = r
	fs.position = Vector2(0.0, -SIZE / 2.0 - 2.0)
	_feet.add_child(fs)
	add_child(_feet)
	_feet.body_entered.connect(func(b: Node) -> void:
		if b is Player and (b as Player).velocity.y >= 0.0:
			on_player_landed())


# ---------- Hooks for later ----------

func on_player_landed() -> void:
	pass


func take_hit(_kind: String) -> bool:
	return false


func reset() -> void:
	position = _origin
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


# Card effects (stuns, slows, pushes) don't do anything to a plain block.
func stun(_seconds: float) -> void:
	pass


func is_stunned() -> bool:
	return false


func slow(_seconds: float) -> void:
	pass


func shove(_dir: float, _tiles := 2) -> void:
	pass


func smash() -> void:
	pass


func half_size() -> Vector2:
	return Vector2(SIZE, SIZE) / 2.0


# ---------- Look ----------

func _draw() -> void:
	var h := SIZE / 2.0
	draw_rect(Rect2(-h, -h, SIZE, SIZE), BODY)
	draw_rect(Rect2(-h, -h, SIZE, 5), TOP)
	draw_rect(Rect2(-h, h - 5, SIZE, 5), SHADE)
	draw_rect(Rect2(-h, -h, SIZE, SIZE), EDGE, false, 2.0)
	# Four rivets, so it reads as a made block rather than ground.
	for p in [Vector2(-9, -6), Vector2(7, -6), Vector2(-9, 6), Vector2(7, 6)]:
		draw_rect(Rect2(p, Vector2(3, 3)), SHADE)
