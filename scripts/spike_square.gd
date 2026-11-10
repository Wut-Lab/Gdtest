class_name SpikeSquare
extends AnimatableBody2D
## A spike square (S in a text map): an "intelligent obstacle" that paces a few tiles left and
## right. Its left and right sides have spikes that cost a heart; its top is safe to ride.

signal hurt_player(direction: float)

const T := 32.0
const SPIKE := 10.0         # how far the spikes stick out
const BODY := Color("5b4b8a")
const TOP := Color("7d6bb3")
const SHADE := Color("3e3363")
const METAL := Color("d9deef")
const METAL_SHADE := Color("8a93b8")
const EYES := Color("eef1fa")

## Tiles to travel each way from the start.
@export var travel := 2.0
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
	# One hit zone per side, below the top edge so riding on top is safe.
	for side in [-1.0, 1.0]:
		var area := Area2D.new()
		var ac := CollisionShape2D.new()
		var ash := RectangleShape2D.new()
		ash.size = Vector2(SPIKE + 2.0, T - 8.0)
		ac.shape = ash
		ac.position = Vector2(side * (T / 2.0 + SPIKE / 2.0 - 1.0), 4.0)
		area.add_child(ac)
		add_child(area)
		_hit_areas.append(area)


## Back to the start of its path, for a new run.
func reset() -> void:
	_t = 0.0
	position = _origin


func _physics_process(delta: float) -> void:
	_t += delta
	var span := travel * T
	# Ping-pong at a steady speed, starting from the middle heading right.
	var d := fposmod(_t * speed + span, span * 4.0)
	var offset := (d if d < span * 2.0 else span * 4.0 - d) - span
	_dir = 1.0 if d < span * 2.0 else -1.0
	position.x = _origin.x + offset
	queue_redraw()
	for area in _hit_areas:
		for b in area.get_overlapping_bodies():
			if b is Player:
				hurt_player.emit(signf(b.global_position.x - global_position.x))


func _draw() -> void:
	var h := T / 2.0
	# Body: flat purple block with a light top lip and a darker base, like the tiles.
	draw_rect(Rect2(-h, -h, T, T), BODY)
	draw_rect(Rect2(-h, -h, T, 5), TOP)
	draw_rect(Rect2(-h, h - 4, T, 4), SHADE)
	# Eyes look the way it's moving.
	var ex := _dir * 4.0
	draw_rect(Rect2(ex - 6.0, -6.0, 4.0, 6.0), EYES)
	draw_rect(Rect2(ex + 2.0, -6.0, 4.0, 6.0), EYES)
	# Blocky spikes: three per side, each a stair of blocks narrowing to a point.
	for side in [-1.0, 1.0]:
		for i in 3:
			var cy := -h + 8.0 + i * 9.0
			for step in [[0.0, 4.0, 4.0], [4.0, 3.0, 2.5], [7.0, 3.0, 1.0]]:
				var w: float = step[1]
				var half: float = step[2]
				var x: float = h + step[0] if side > 0 else -h - step[0] - w
				draw_rect(Rect2(x, cy - half, w, half * 2.0), METAL)
				draw_rect(Rect2(x, cy, w, half), METAL_SHADE)
