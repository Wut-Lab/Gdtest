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
const MINI := Vector2(64, 33)   # Pause and Tune, stacked in one column

## The HUD's Pause and Tune buttons. While the bar shows, they hide and these bar keys stand in.
var pause_source: Button
var tune_source: Button
var _pause_key: TouchScreenButton
var _tune_key: TouchScreenButton

@onready var pad: Node2D = $Pad
@onready var left: TouchScreenButton = $Pad/Left
@onready var right: TouchScreenButton = $Pad/Right
@onready var jump: TouchScreenButton = $Pad/Jump
@onready var dash: TouchScreenButton = $Pad/Dash
@onready var pound: TouchScreenButton = $Pad/Pound
@onready var brick: TouchScreenButton = $Pad/Brick
@onready var toss: TouchScreenButton = $Pad/Toss
@onready var angry: TouchScreenButton = $Pad/Angry
@onready var push: TouchScreenButton = $Pad/Push
## Card buttons, in the order their cards were equipped (the first sits next to Jump).
var _card_buttons: Array[TouchScreenButton] = []

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
	_setup_key(brick, SMALL, "B-DROP", 0.0, Color("e5484d"))
	_setup_key(toss, SMALL, "B-TOSS", 0.0, Color("e5484d"))
	_setup_key(angry, SMALL, "ANGRY", 0.0, Color("b8323a"))
	_setup_key(push, SMALL, "PUSH", 0.0, Color("7d8597"))
	_pause_key = _mini_key("PAUSE", func() -> void: pause_source.pressed.emit())
	_tune_key = _mini_key("TUNE", func() -> void: tune_source.pressed.emit())
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


func _mini_key(text: String, action: Callable) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	pad.add_child(b)
	_setup_key(b, MINI, text, 0.0, Color("2a3354"))
	_keys[b].font_size = 12
	b.pressed.connect(func() -> void:
		if b.visible:
			action.call())
	return b


## Mirror the HUD's Pause and Tune buttons: show the bar keys only while the source would
## show, and hide the source while the bar is up.
func _process(_delta: float) -> void:
	var bar_up := visible and pad.visible
	for pair in [[pause_source, _pause_key], [tune_source, _tune_key]]:
		var src: Button = pair[0]
		if src == null:
			continue
		src.modulate.a = 0.0 if bar_up else 1.0
		src.mouse_filter = Control.MOUSE_FILTER_IGNORE if bar_up else Control.MOUSE_FILTER_STOP
		if pair[1].visible != src.visible:
			pair[1].visible = src.visible


## Dims a card's button while it can't be used (recharging, or Angry at your last heart).
func set_ready(button_name: String, ready: bool) -> void:
	var b: TouchScreenButton = get(button_name)
	b.modulate.a = 1.0 if ready else 0.4


## Height the black bar covers at the bottom of the screen (with the border under it), or 0
## when the controls are hidden.
func bar_height() -> float:
	return BAR_HEIGHT + BORDER if pad.visible else 0.0


## Dash, Pound and Brick buttons show only when their cards are equipped.
func set_abilities(abilities: Array[String]) -> void:
	var by_card := {"dash": dash, "pound": pound, "brick_drop": brick, "brick_toss": toss, "angry_dash": angry,
		"personal_space": push}
	_card_buttons.clear()
	for a in abilities:
		if by_card.has(a):
			_card_buttons.append(by_card[a])
	for b in by_card.values():
		b.visible = b in _card_buttons
	if is_node_ready():
		_layout()


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
	# Card buttons fill in leftward from Jump, only the ones showing. On narrow screens the gaps
	# between them shrink so they never reach the arrows.
	var shown := _card_buttons
	var room := x - BIG.x / 2.0 - (right.position.x + SMALL.x / 2.0 + GAP) - MINI.x - GAP
	var gap := GAP
	if shown.size() > 0:
		gap = clampf((room - shown.size() * SMALL.x) / shown.size(), 2.0, GAP)
	x -= BIG.x / 2.0 + gap + SMALL.x / 2.0
	for b in _card_buttons:
		b.position = Vector2(x, cy)
		if b.visible:
			x -= SMALL.x + gap
	# Pause over Tune, in one column just left of the card buttons.
	x += SMALL.x / 2.0 - MINI.x / 2.0
	_pause_key.position = Vector2(x, cy - MINI.y / 2.0 - 3.0)
	_tune_key.position = Vector2(x, cy + MINI.y / 2.0 + 3.0)
	# Those were centers; buttons are placed by their top-left corner.
	for b in _keys:
		b.position -= _keys[b].key_size / 2.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not pad.visible:
		pad.visible = true
		_layout()
		bar_changed.emit()
