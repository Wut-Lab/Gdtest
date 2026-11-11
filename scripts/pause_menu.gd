class_name PauseMenu
extends Control
## The pause menu: one panel with three pages.
##   Paused:  Continue, Options, Back (to the start screen)
##   Options: Sound, Back
##   Sound:   Music Volume, Sound Volume, Sound: On/Off, Back
## Esc goes back one page (or continues from the first page).

signal continue_pressed
signal quit_pressed

const BUTTON_SIZE := Vector2(240, 44)

var _pages := {}
var _page := ""
var _music_slider: HSlider
var _sounds_slider: HSlider
var _music_value: Label
var _sounds_value: Label
var _sound_toggle: Button
var _preview: AudioStreamPlayer
var _last_preview := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Dim the game behind the menu.
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

	var paused := _page_box("Paused")
	_button(paused, "Continue", func() -> void: continue_pressed.emit())
	_button(paused, "Options", func() -> void: _show("Options"))
	_button(paused, "Back", func() -> void: quit_pressed.emit())

	var options := _page_box("Options")
	_button(options, "Sound", func() -> void: _show("Sound"))
	_button(options, "Back", func() -> void: _show("Paused"))

	var sound := _page_box("Sound")
	var m := _slider_row(sound, "Music Volume")
	_music_slider = m[0]
	_music_value = m[1]
	var s := _slider_row(sound, "Sound Volume")
	_sounds_slider = s[0]
	_sounds_value = s[1]
	_sound_toggle = _button(sound, "Sound: On", _toggle_sound)
	_button(sound, "Back", func() -> void: _show("Options"))

	for page in [paused, options, sound]:
		panel.add_child(page)   # only the open page is visible, and the panel fits it

	_music_slider.value_changed.connect(func(v: float) -> void:
		AudioSettings.music = v / 100.0
		_changed())
	_sounds_slider.value_changed.connect(func(v: float) -> void:
		AudioSettings.sounds = v / 100.0
		_changed()
		_play_preview())

	_preview = AudioStreamPlayer.new()
	_preview.stream = load("res://audio/jump.wav")
	_preview.bus = AudioSettings.SOUNDS_BUS
	_preview.volume_db = -8.0
	add_child(_preview)
	hide()


func open() -> void:
	_sync()
	show()
	_show("Paused")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match _page:
			"Sound": _show("Options")
			"Options": _show("Paused")
			_: continue_pressed.emit()


func _show(page_name: String) -> void:
	_page = page_name
	for n in _pages:
		_pages[n].visible = n == page_name
	# Focus the first button so keys and gamepads work straight away.
	for c in _pages[page_name].get_children():
		if c is Button or c is HSlider:
			c.grab_focus()
			break
		for cc in c.get_children():
			if cc is HSlider:
				cc.grab_focus()
				return


func _sync() -> void:
	_music_slider.set_value_no_signal(roundf(AudioSettings.music * 100.0))
	_sounds_slider.set_value_no_signal(roundf(AudioSettings.sounds * 100.0))
	_update_labels()


func _changed() -> void:
	AudioSettings.apply()
	AudioSettings.save()
	_update_labels()


func _toggle_sound() -> void:
	AudioSettings.sound_on = not AudioSettings.sound_on
	_changed()


func _update_labels() -> void:
	_music_value.text = "%d%%" % int(_music_slider.value)
	_sounds_value.text = "%d%%" % int(_sounds_slider.value)
	_sound_toggle.text = "Sound: On" if AudioSettings.sound_on else "Sound: Off"
	_music_slider.editable = AudioSettings.sound_on
	_sounds_slider.editable = AudioSettings.sound_on


## A short jump sound while dragging Sound Volume, so you hear the new level.
func _play_preview() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_preview > 180:
		_last_preview = now
		_preview.play()


# ---------- Building blocks, so every page looks the same ----------

func _page_box(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title
	box.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = "TitleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_pages[title] = box
	return box


func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	box.add_child(b)
	return b


## A label with its value on the right, and a 0-100 slider under it.
func _slider_row(box: VBoxContainer, text: String) -> Array:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	value.add_theme_color_override("font_color", Color("a9b3d1"))
	value.custom_minimum_size = Vector2(44, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	group.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(BUTTON_SIZE.x, 30)
	group.add_child(slider)
	group.custom_minimum_size = Vector2(BUTTON_SIZE.x, 0)
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(group)
	return [slider, value]
