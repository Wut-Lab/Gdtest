class_name SpikeSquare
extends AnimatableBody2D
## A spike square: an "intelligent obstacle" that paces back and forth.
##   S (horizontal): moves 2 tiles left and right of its cell; spikes on its left and right,
##     and a safe top you can ride.
##   V (vertical): rises 3 tiles above its cell and back down; spikes on its top and bottom.
## Touching a spiky side costs a heart.

## push.x: which way to knock the player (-1 left, 1 right); push.y: -1 up, 1 down.
signal hurt_player(push: Vector2)

const T := 32.0
const SPIKE := 10.0         # how far the spikes stick out
const BODY := Color("5b4b8a")
const TOP := Color("7d6bb3")
const SHADE := Color("3e3363")
const METAL := Color("d9deef")
const METAL_SHADE := Color("8a93b8")
const EYES := Color("eef1fa")

## Moves up and down (spikes top and bottom) instead of left and right.
@export var vertical := false
## Pixels per second.
@export var speed := 70.0

var _origin := Vector2.ZERO
var _t := 0.0
var _dir := 1.0
var _hit_areas: Array[Area2D] = []


func _ready() -> void:
	sync_to_physics = true
	_origin = position
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(T, T)
	col.shape = shape
	add_child(col)
	# One hit zone per spiky side, kept off the corners so the safe sides stay safe.
	for side in [-1.0, 1.0]:
		var area := Area2D.new()
		var ac := CollisionShape2D.new()
		var ash := RectangleShape2D.new()
		var out: float = side * (T / 2.0 + SPIKE / 2.0 - 1.0)
		if vertical:
			ash.size = Vector2(T - 8.0, SPIKE + 2.0)
			ac.position = Vector2(0.0, out)
		else:
			ash.size = Vector2(SPIKE + 2.0, T - 8.0)
			ac.position = Vector2(out, 4.0)
		ac.shape = ash
		area.add_child(ac)
		add_child(area)
		_hit_areas.append(area)


## Back to the start of its path, for a new run.
func reset() -> void:
	_t = 0.0
	position = _origin


func _physics_process(delta: float) -> void:
	_t += delta
	if vertical:
		# From its cell up 3 tiles and back down, at a steady speed.
		var span := 3.0 * T
		var d := fposmod(_t * speed, span * 2.0)
		_dir = -1.0 if d < span else 1.0
		position.y = _origin.y - (d if d < span else span * 2.0 - d)
	else:
		# 2 tiles each way, starting from the middle heading right.
		var span := 2.0 * T
		var d := fposmod(_t * speed + span, span * 4.0)
		_dir = 1.0 if d < span * 2.0 else -1.0
		position.x = _origin.x + (d if d < span * 2.0 else span * 4.0 - d) - span
	queue_redraw()
	for area in _hit_areas:
		for b in area.get_overlapping_bodies():
			if b is Player:
				# Knock the player away sideways, toward whichever side they're on; down if
				# they hit the bottom spikes from below.
				var dx: float = b.global_position.x - global_position.x
				var below: bool = vertical and b.global_position.y > global_position.y
				hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else -1.0, 1.0 if below else -1.0))


func _draw() -> void:
	var h := T / 2.0
	# Body: flat purple block with a light top lip and a darker base, like the tiles.
	draw_rect(Rect2(-h, -h, T, T), BODY)
	draw_rect(Rect2(-h, -h, T, 5), TOP)
	draw_rect(Rect2(-h, h - 4, T, 4), SHADE)
	# Eyes look the way it's moving.
	var e := Vector2(0.0, _dir * 3.0) if vertical else Vector2(_dir * 4.0, 0.0)
	draw_rect(Rect2(e.x - 6.0, e.y - 4.0, 4.0, 6.0), EYES)
	draw_rect(Rect2(e.x + 2.0, e.y - 4.0, 4.0, 6.0), EYES)
	# Blocky spikes: three per spiky side, each a stair of blocks narrowing to a point.
	for side in [-1.0, 1.0]:
		for i in 3:
			var c := -h + 7.0 + i * 9.0
			for step in [[0.0, 4.0, 4.0], [4.0, 3.0, 2.5], [7.0, 3.0, 1.0]]:
				var w: float = step[1]
				var half: float = step[2]
				var o: float = h + step[0] if side > 0 else -h - step[0] - w
				if vertical:
					draw_rect(Rect2(c - half, o, half * 2.0, w), METAL)
					draw_rect(Rect2(c, o, half, w), METAL_SHADE)
				else:
					draw_rect(Rect2(o, c + 1.0 - half, w, half * 2.0), METAL)
					draw_rect(Rect2(o, c + 1.0, w, half), METAL_SHADE)
