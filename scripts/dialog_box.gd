class_name DialogBox
extends Control
## Townsfolk talk: pauses the game and shows a simple panel near the bottom of the screen,
## with the speaker's picture in a small box on the left, their words on the right,
## and Next (when there's more to say) and Back buttons along the bottom.

signal closed

var _portrait: TownDoor
var _name: Label
var _text: Label
var _next: Button
var _back: Button
var _pages: Array = []
var _i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var shade := ColorRect.new()
	shade.color = Color(0.067, 0.09, 0.169, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	# The small picture box: the same border, with the character standing inside it.
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(72, 72)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(56, 56)
	holder.clip_contents = true
	frame.add_child(holder)
	_portrait = TownDoor.new()
	_portrait.portrait = true
	_portrait.position = Vector2(28, 46)
	_portrait.scale = Vector2(1.3, 1.3)
	holder.add_child(_portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_name = Label.new()
	_name.theme_type_variation = "TitleLabel"
	_name.add_theme_font_size_override("font_size", 22)
	words.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(250, 48)
	words.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_next = Button.new()
	_next.text = "Next"
	_next.custom_minimum_size = Vector2(110, 44)
	_next.pressed.connect(_on_next)
	buttons.add_child(_next)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(110, 44)
	_back.pressed.connect(close)
	buttons.add_child(_back)
	_layout.call_deferred()
	get_viewport().size_changed.connect(_layout)
	_panel = panel


var _panel: PanelContainer


## Fit the panel to the screen width (up to 520) and sit it just above the bottom.
func _layout() -> void:
	if _panel == null:
		return
	var w := minf(520.0, get_viewport_rect().size.x - 32.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0
	_panel.offset_bottom = -24
	_panel.offset_top = -24 - _panel.get_combined_minimum_size().y
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Show what [param who] (a TownDoor kind) says: one page per entry of [param pages].
func say(who: String, pages: Array) -> void:
	_portrait.kind = who
	_name.text = TownDoor.NAMES.get(who, who)
	_pages = pages
	_i = 0
	_refresh()
	show()
	_layout()
	(_next if _next.visible else _back).grab_focus()


func _refresh() -> void:
	_text.text = "\"%s\"" % _pages[_i]
	_next.visible = _i < _pages.size() - 1


func _on_next() -> void:
	_i += 1
	_refresh()
	(_next if _next.visible else _back).grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
