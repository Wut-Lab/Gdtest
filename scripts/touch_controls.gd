extends CanvasLayer
## On-screen buttons. They show on touchscreens, or as soon as a touch is seen.
## Each button presses an Input Map action, so the player code doesn't know about touch.
## The buttons sit in a black bar along the bottom of the screen, so your thumbs never cover
## the level: Left and Right on the left, Pound, Dash and Jump on the right. Main moves the
## camera so the level shows above the bar.

signal bar_changed

const BAR_HEIGHT := 104.0
const BORDER := ScreenBorder.BLOCK
const MARGIN := 14.0
const GAP := 12.0
const SMALL := Vector2(76, 72)
const BIG := Vector2(96, 72)

@onready var pad: Node2D = $Pad
@onready var left: TouchScreenButton = $Pad/Left
@onready var right: TouchScreenButton = $Pad/Right
@onready var jump: TouchScreenButton = $Pad/Jump
@onready var dash: TouchScreenButton = $Pad/Dash
@onready var pound: TouchScreenButton = $Pad/Pound

var _bar: ColorRect
var _keys := {}   # button -> TouchKey


func _ready() -> void:
	_bar = ColorRect.new()
	_bar.color = Color("05070d")
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	move_child(_bar, 0)
	_setup_key(left, SMALL, "", -1.0, Color("2a3354"))
	_setup_key(right, SMALL, "", 1.0, Color("2a3354"))
	_setup_key(jump, BIG, "JUMP", 0.0, Color("79e2c2"), Color("1b2440"))
	_setup_key(dash, SMALL, "DASH", 0.0, Color("e5484d"))
	_setup_key(pound, SMALL, "POUND", 0.0, Color("e5484d"))
	pad.visible = DisplayServer.is_touchscreen_available()
	set_abilities([])
	get_viewport().size_changed.connect(_layout)
	_layout()


## Swaps the button's round picture for a 3D block key that animates when pressed.
func _setup_key(b: TouchScreenButton, key_size: Vector2, text: String, arrow: float,
		face: Color, text_color := Color("eef1fa")) -> void:
	for c in b.get_children():
		c.queue_free()
	# Same touch setup as the old round buttons: a picture (now invisible) sets the button's
	# size and the touch shape is centered on it. The key is drawn by a TouchKey child.
	var img := Image.create_empty(int(key_size.x), int(key_size.y), false, Image.FORMAT_RGBA8)
	b.texture_normal = ImageTexture.create_from_image(img)
	b.texture_pressed = null
	var shape := RectangleShape2D.new()
	shape.size = key_size + Vector2(GAP, GAP)   # a little extra so near-misses still count
	b.shape = shape
	b.shape_centered = true
	var key := TouchKey.new()
	key.position = key_size / 2.0
	key.key_size = key_size
	key.label = text
	key.arrow = arrow
	key.face = face
	key.text_color = text_color
	b.add_child(key)
	b.pressed.connect(key.press.bind(true))
	b.released.connect(key.press.bind(false))
	_keys[b] = key


## Height the black bar covers at the bottom of the screen (with the border under it), or 0
## when the controls are hidden.
func bar_height() -> float:
	return BAR_HEIGHT + BORDER if pad.visible else 0.0


## Dash and Pound buttons show only once their cards are collected.
func set_abilities(abilities: Array[String]) -> void:
	dash.visible = "dash" in abilities
	pound.visible = "pound" in abilities


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var bar_top := size.y - BORDER - BAR_HEIGHT
	_bar.position = Vector2(0, bar_top)
	_bar.size = Vector2(size.x, BAR_HEIGHT + BORDER)
	_bar.visible = pad.visible
	var cy := bar_top + BAR_HEIGHT / 2.0 + 2.0
	var x := BORDER + MARGIN + SMALL.x / 2.0
	left.position = Vector2(x, cy)
	right.position = Vector2(x + SMALL.x + GAP, cy)
	x = size.x - BORDER - MARGIN - BIG.x / 2.0
	jump.position = Vector2(x, cy)
	x -= BIG.x / 2.0 + GAP + SMALL.x / 2.0
	dash.position = Vector2(x, cy)
	pound.position = Vector2(x - SMALL.x - GAP, cy)
	# Those were centers; buttons are placed by their top-left corner.
	for b in _keys:
		b.position -= _keys[b].key_size / 2.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not pad.visible:
		pad.visible = true
		_layout()
		bar_changed.emit()
