class_name HeartsDisplay
extends Control
## A row of blocky hearts in the HUD: full hearts for what you have, empty slots up to the
## starting amount.

const BLOCK := 4.0
const GAP := 6.0

var hearts := 3:
	set(v):
		hearts = v
		_resize()
var slots := 3:
	set(v):
		slots = v
		_resize()

var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


## A short shake when a heart is lost.
func flash() -> void:
	_flash = 0.4


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func _resize() -> void:
	var n := maxi(hearts, slots)
	var s := HeartArt.size(BLOCK)
	custom_minimum_size = Vector2(n * s.x + (n - 1) * GAP, s.y)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var w := HeartArt.size(BLOCK).x + GAP
	for i in maxi(hearts, slots):
		var pos := Vector2(i * w, 0)
		if i == hearts and _flash > 0.0:   # the heart just lost shakes
			pos.x += sin(_flash * 60.0) * 3.0
		HeartArt.draw(self, pos, BLOCK, i < hearts)
