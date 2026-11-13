class_name SpikeSquare
extends AnimatableBody2D
## A spike square: an "intelligent obstacle" that paces back and forth.
##   S (horizontal): moves 2 tiles left and right of its cell; spikes on its left and right,
##     and a safe top you can ride.
##   V (vertical): rises 3 tiles above its cell and back down; spikes on its top and bottom.
## Touching a spiky side costs a heart. Each has 1 health: dash into a V, or ground pound an S.

## push.x: which way to knock the player (-1 left, 1 right); push.y: -1 up, 1 down.
signal hurt_player(push: Vector2)
signal broken(pos: Vector2)

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
@export var max_health := 1

var health := 1

var _origin := Vector2.ZERO
var _t := 0.0
var _dir := 1.0
var _reach := Vector2(-1.0, -1.0)   # px it may go left (x) and right (y); set on first use
var _hit_areas: Array[Area2D] = []
## Stunning Landing: seconds left frozen in place.
var _stun := 0.0
## Shockwave: how far it has been pushed off its path, and where it is sliding to.
var _shift := Vector2.ZERO
var _shift_to := Vector2.ZERO
var _bolts: Array = []
var _next_bolts := 0.0
## Slow Burst: seconds left moving at half speed.
var _slow := 0.0


func _ready() -> void:
	sync_to_physics = true
	add_to_group("card_targets")
	_origin = position
	health = max_health
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
	_stun = 0.0
	_slow = 0.0
	_shift = Vector2.ZERO
	_shift_to = Vector2.ZERO
	position = _origin
	health = max_health
	show()
	process_mode = Node.PROCESS_MODE_INHERIT


## A dash or ground pound landed on it. V only takes dashes, S only ground pounds.
## Returns true if it took damage.
func take_hit(kind: String) -> bool:
	if kind != ("dash" if vertical else "pound"):
		return false
	health -= 1
	if health <= 0:
		broken.emit(global_position)
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
	return true


## Angry Block Dash ran into it: broken whatever kind it is.
func smash() -> void:
	health = 0
	broken.emit(global_position)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED


## Stunning Landing card: freeze in place for this many seconds.
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


## Half its width and height, for the cards that reach for it.
func half_size() -> Vector2:
	return Vector2(T, T) / 2.0


## Slow Burst card: move at half speed for this many seconds.
func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func is_stunned() -> bool:
	return _stun > 0.0


## Shockwave card: slide up to tiles × 32 px sideways (dir -1 or 1), less if a wall is in the way.
func shove(dir: float, tiles := 2) -> void:
	_shift_to.x += CardFx.clear_shift(self, global_position + _shift_to - _shift, half_size(), dir, tiles)


func _physics_process(delta: float) -> void:
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)   # stunned: hold still
	else:
		_t += delta * (0.5 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_shift = _shift.move_toward(_shift_to, 480.0 * delta)
	var path := Vector2.ZERO
	if vertical:
		# From its cell up 3 tiles and back down, at a steady speed.
		var span := 3.0 * T
		var d := fposmod(_t * speed, span * 2.0)
		_dir = -1.0 if d < span else 1.0
		path.y = -(d if d < span else span * 2.0 - d)
	else:
		# 2 tiles each way, starting from the middle heading right.
		path.x = _pace_x()
	position = _origin + _shift + path
	if _stun > 0.0:
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07   # re-roll the sparks so they crackle
			_bolts = CardFx.stun_bolts(half_size())
	queue_redraw()
	for area in _hit_areas:
		for b in area.get_overlapping_bodies():
			if b is Player:
				if vertical and b.is_dashing():
					take_hit("dash")   # dashing through a V breaks it instead of hurting
					return
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
	if _stun > 0.0:
		# Dazed: flat eyes and electric sparks crackling over it (blinking in the last second).
		draw_rect(Rect2(-7.0, -2.0, 5.0, 2.0), EYES)
		draw_rect(Rect2(2.0, -2.0, 5.0, 2.0), EYES)
	else:
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
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)


## Up to 2 tiles each way, starting from the middle heading right, but stopping a tile short
## of its platform's edges.
func _pace_x() -> float:
	if _reach.x < 0.0:
		var at: Vector2 = global_position - position + _origin
		_reach = Vector2(CardFx.pace_reach(self, at, -1.0, 2, 0), CardFx.pace_reach(self, at, 1.0, 2, 0))
	var total := _reach.x + _reach.y
	if total <= 0.0:
		return 0.0
	var d := fposmod(_t * speed + _reach.x, total * 2.0)
	_dir = 1.0 if d < total else -1.0
	return (d if d < total else total * 2.0 - d) - _reach.x
