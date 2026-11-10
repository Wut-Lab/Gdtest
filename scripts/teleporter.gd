class_name Teleporter
extends Area2D
## A teleport pad. Touching it sends the player to its partner pad of the same color,
## keeping their speed and direction. The pad you arrive on stays inactive until you step off,
## so you don't bounce straight back.

signal used

const COLORS := {
	"red": Color("ff4d6d"),
	"yellow": Color("ffd23f"),
	"blue": Color("4da3ff"),
}
const PIXEL := 4.0          # size of one glow "pixel"
const CORE := 12.0          # half-size of the solid square (same as the goal)

@export_enum("red", "yellow", "blue") var color_name := "red"

var partner: Teleporter
var armed := true

var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player) or not armed or partner == null:
		return
	partner.armed = false
	(body as Player).call_deferred("teleport_to", partner.global_position)
	flash()
	partner.flash()
	used.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		armed = true


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 2.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var c: Color = COLORS.get(color_name, Color.WHITE)
	var strength := 1.0 if partner != null else 0.35   # a pad with no partner looks dormant
	var bob := Vector2(0, sin(_t * 2.5) * 2.0)

	# Pixelated glow: a square halo of 4 px blocks whose brightness falls off with distance
	# and shimmers block by block. Alpha is stepped so it reads as pixel art.
	var reach := 30.0 + _flash * 16.0
	var n := int(ceil(reach / PIXEL))
	for gy in range(-n, n):
		for gx in range(-n, n):
			var center := Vector2((gx + 0.5) * PIXEL, (gy + 0.5) * PIXEL)
			var d := maxf(absf(center.x), absf(center.y))
			if d < CORE + 1.0 or d > reach:
				continue
			var falloff := 1.0 - (d - CORE) / (reach - CORE)
			var shimmer := 0.5 + 0.5 * sin(_t * 5.0 + gx * 1.7 + gy * 2.3 + sin(gx * gy * 0.9) * 3.0)
			var a := snappedf(falloff * (0.25 + 0.55 * shimmer) * strength + _flash * 0.3, 0.15)
			if a < 0.1:
				continue
			draw_rect(Rect2(bob + center - Vector2(PIXEL, PIXEL) / 2.0, Vector2(PIXEL, PIXEL)), Color(c, minf(a, 0.9)))

	# Core: the same pulsing square as the goal, with a darker center like an opening.
	var pulse := 1.0 + sin(_t * 4.0) * 0.08 + _flash * 0.25
	draw_rect(Rect2(bob - Vector2(CORE, CORE) * pulse, Vector2(CORE, CORE) * 2.0 * pulse), Color(c, strength))
	draw_rect(Rect2(bob - Vector2(5, 5) * pulse, Vector2(10, 10) * pulse), Color(c.darkened(0.45), strength))
