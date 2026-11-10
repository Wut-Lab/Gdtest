extends CanvasLayer
## On-screen buttons. They show on touchscreens, or as soon as a touch is seen.
## Each button presses an Input Map action, so the player code doesn't know about touch.

@onready var pad: Node2D = $Pad


func _ready() -> void:
	pad.visible = DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not pad.visible:
		pad.visible = true
