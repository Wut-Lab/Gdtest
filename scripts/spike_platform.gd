class_name SpikePlatform
extends AnimatableBody2D
## A wide moving platform, three tiles across, that paces 2 tiles left and right of its cell.
##   T (spikes on top): a moving hurdle; jump over it. Its sides and bottom are safe.
##   B (spikes on the bottom): ride on its safe top, like a moving bridge.
## Touching the spiky side costs a heart. Both kinds are invulnerable for now, but keep a
## health of 3 for later.

## push.x: which way to knock the player (-1 left, 1 right); push.y: -1 up, 1 down.
signal hurt_player(push: Vector2)

const T := 32.0
const WIDTH := 96.0
const THICK := 14.0
const SPIKE := 10.0
const BODY := Color("5b4b8a")
const TOP := Color("7d6bb3")
const SHADE := Color("3e3363")
const METAL := Color("d9deef")
const METAL_SHADE := Color("8a93b8")
const EYES := Color("eef1fa")

## Spikes on top (a hurdle) instead of underneath (a bridge).
@export var spikes_top := true
@export var speed := 60.0
@export var max_health := 3
## Dashes and ground pounds don't hurt it (yet).
@export var invulnerable := true

var health := 3
var _origin := Vector2.ZERO
var _t := 0.0
var _dir := 1.0
var _hit_area: Area2D
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
	shape.size = Vector2(WIDTH, THICK)
	col.shape = shape
	add_child(col)
	_hit_area = Area2D.new()
	var ac := CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(WIDTH - 6.0, SPIKE + 2.0)
	ac.position = Vector2(0.0, (-1.0 if spikes_top else 1.0) * (THICK / 2.0 + SPIKE / 2.0 - 1.0))
	ac.shape = ash
	_hit_area.add_child(ac)
	add_child(_hit_area)


## A dash or ground pound landed on it. Returns true if it took damage.
func take_hit(_kind: String) -> bool:
	if invulnerable:
		return false
	health -= 1
	if health <= 0:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
	return true


## Back to the start of its path at full health, for a new run.
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


## Half its width and height, for the cards that reach for it.
func half_size() -> Vector2:
	return Vector2(WIDTH, THICK) / 2.0


## Stunning Landing card: freeze in place for this many seconds.
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


## Slow Burst card: move at half speed for this many seconds.
func slow(seconds: float) -> void:
	_slow = maxf(_slow, seconds)


func is_stunned() -> bool:
	return _stun > 0.0


## Shockwave card: slide up to 2 tiles sideways (dir -1 or 1), less if a wall is in the way.
func shove(dir: float, tiles := 2) -> void:
	_shift_to.x += CardFx.clear_shift(self, global_position + _shift_to - _shift, half_size(), dir, tiles)


func _physics_process(delta: float) -> void:
	if _stun > 0.0:
		_stun = maxf(_stun - delta, 0.0)   # stunned: hold still
		_next_bolts -= delta
		if _next_bolts <= 0.0:
			_next_bolts = 0.07   # re-roll the sparks so they crackle
			_bolts = CardFx.stun_bolts(half_size())
	else:
		_t += delta * (0.5 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_shift = _shift.move_toward(_shift_to, 480.0 * delta)
	var span := 2.0 * T
	var d := fposmod(_t * speed + span, span * 4.0)
	_dir = 1.0 if d < span * 2.0 else -1.0
	position = _origin + _shift + Vector2((d if d < span * 2.0 else span * 4.0 - d) - span, 0.0)
	queue_redraw()
	for b in _hit_area.get_overlapping_bodies():
		if b is Player:
			var dx: float = b.global_position.x - global_position.x
			hurt_player.emit(Vector2(signf(dx) if absf(dx) > 2.0 else -1.0, -1.0 if spikes_top else 1.0))


func _draw() -> void:
	var hw := WIDTH / 2.0
	var ht := THICK / 2.0
	draw_rect(Rect2(-hw, -ht, WIDTH, THICK), BODY)
	draw_rect(Rect2(-hw, -ht, WIDTH, 4), TOP)
	draw_rect(Rect2(-hw, ht - 3, WIDTH, 3), SHADE)
	# Eyes in the middle look the way it's moving.
	var ex := _dir * 4.0
	if _stun > 0.0:
		draw_rect(Rect2(-7.0, -1.0, 5.0, 2.0), EYES)   # dazed
		draw_rect(Rect2(2.0, -1.0, 5.0, 2.0), EYES)
	else:
		draw_rect(Rect2(ex - 6.0, -3.0, 4.0, 5.0), EYES)
		draw_rect(Rect2(ex + 2.0, -3.0, 4.0, 5.0), EYES)
	# Blocky spikes along the spiky side: nine stairs of blocks narrowing to a point.
	var side := -1.0 if spikes_top else 1.0
	for i in 9:
		var c := -hw + 5.5 + i * 10.6
		for step in [[0.0, 4.0, 4.0], [4.0, 3.0, 2.5], [7.0, 3.0, 1.0]]:
			var w: float = step[1]
			var half: float = step[2]
			var o: float = ht + step[0] if side > 0 else -ht - step[0] - w
			draw_rect(Rect2(c - half, o, half * 2.0, w), METAL)
			draw_rect(Rect2(c, o, half, w), METAL_SHADE)
	if _stun > 0.0:
		CardFx.draw_stun(self, _bolts, _stun)
	if _slow > 0.0:
		CardFx.draw_slow(self, half_size(), _slow)
