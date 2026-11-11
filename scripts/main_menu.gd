class_name MainMenu
extends Control
## The title screen, shown when the game starts and after leaving a run.
##   Main:    the player, the game's name, Play, Options, Credits
##   Credits: who and what made the game, and the engine's license
## Options opens the same Options page as the pause menu.

signal play_pressed
signal options_pressed

const BUTTON_SIZE := Vector2(240, 44)
const DIM := Color("a9b3d1")

var _pages := {}
var _square: PlayerPreview


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.067, 0.09, 0.169, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var main := _page("Main")
	_square = PlayerPreview.new()
	_square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main.add_child(_square)
	var title := Label.new()
	title.text = "Square Hop"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)
	var tagline := Label.new()
	tagline.text = "Run, jump and bounce to the goal."
	tagline.add_theme_color_override("font_color", DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(tagline)
	_button(main, "Play", func() -> void: play_pressed.emit())
	_button(main, "Options", func() -> void: options_pressed.emit())
	_button(main, "Credits", func() -> void: _show("Credits"))

	var credits := _page("Credits")
	var title2 := Label.new()
	title2.text = "Credits"
	title2.theme_type_variation = "TitleLabel"
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_child(title2)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	credits.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	_credit(list, "Game design and direction", "The Square Hop team")
	_credit(list, "Programming, art, music and sound",
		"Made with Claude (Anthropic) in Claude Code. All art is drawn by code and all music "
		+ "and sounds are synthesized, so there are no outside assets.")
	_credit(list, "Engine", "Made with Godot Engine %s (godotengine.org)" % _godot_version())
	_credit(list, "Font", "Open Sans, Godot's default font (SIL Open Font License 1.1)")
	_credit(list, "Thanks", "Thanks for playing!")
	_credit(list, "Godot Engine license", Engine.get_license_text()
		+ "\nPortions of this software are copyright © The FreeType Project "
		+ "(www.freetype.org). All rights reserved. Godot also includes other open-source "
		+ "libraries; see godotengine.org/license.")
	_button(credits, "Back", func() -> void: _show("Main"))

	panel.add_child(main)
	panel.add_child(credits)
	open()


func open(player_color := Color("ff6b5e")) -> void:
	_square.color = player_color
	show()
	_show("Main")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _pages["Credits"].visible:
		get_viewport().set_input_as_handled()
		_show("Main")


func _show(page_name: String) -> void:
	for n in _pages:
		_pages[n].visible = n == page_name
	for c in _pages[page_name].get_children():
		if c is Button:
			c.grab_focus()
			break


func _page(page_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = page_name
	box.add_theme_constant_override("separation", 14)
	_pages[page_name] = box
	return box


func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	box.add_child(b)
	return b


## A small dim heading with its text under it.
func _credit(list: VBoxContainer, heading: String, text: String) -> void:
	var h := Label.new()
	h.text = heading
	h.theme_type_variation = "SmallLabel"
	h.add_theme_color_override("font_color", DIM)
	list.add_child(h)
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	list.add_child(t)


func _godot_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]
