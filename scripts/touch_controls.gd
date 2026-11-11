extends CanvasLayer
## On-screen buttons. They show on touchscreens, or as soon as a touch is seen.
## Each button presses an Input Map action, so the player code doesn't know about touch.
## The buttons stay in the screen's bottom corners whatever its shape.

const MARGIN := 18.0
const GAP := 12.0

@onready var pad: Node2D = $Pad
@onready var left: TouchScreenButton = $Pad/Left
@onready var right: TouchScreenButton = $Pad/Right
@onready var jump: TouchScreenButton = $Pad/Jump
@onready var dash: TouchScreenButton = $Pad/Dash
@onready var pound: TouchScreenButton = $Pad/Pound


func _ready() -> void:
	pad.visible = DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var small := left.texture_normal.get_size()
	var big := jump.texture_normal.get_size()
	left.position = Vector2(MARGIN, size.y - MARGIN - small.y)
	right.position = Vector2(MARGIN + small.x + GAP, size.y - MARGIN - small.y)
	jump.position = Vector2(size.x - MARGIN - big.x, size.y - MARGIN - big.y)
	# Dash to the left of Jump, Pound above it.
	dash.position = Vector2(jump.position.x - GAP - small.x, size.y - MARGIN - small.y)
	pound.position = Vector2(jump.position.x + (big.x - small.x) / 2.0, jump.position.y - GAP - small.y)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not pad.visible:
		pad.visible = true
