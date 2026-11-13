class_name PauseMenu
extends Control
## The pause menu: one panel with five pages.
##   Paused:  Continue, Cards, Options, Back (to the main menu)
##   Cards:   the player and their 0–3 equipped ability cards (tap one to see it), Back
##   Card:    one card, large, with what it does, Back
##   Options: Sound, Back
## The main menu opens the same Options page on its own; Back then closes the menu.
##   Sound:   Music Volume, Sound Volume, Sound: On/Off, Back
## Esc goes back one page (or continues from the first page).

signal continue_pressed
signal quit_pressed
## Save the dungeon run (back to the start of this level next time) and go to the title.
signal save_quit_pressed
## Options opened from the main menu was closed.
signal closed

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
var _from_main := false
var _quit: Button
var _preview_square: PlayerPreview
var _slots: Array[CardIcon] = []
var _slot_names: Array[Label] = []
var _slot_buttons: Array[Button] = []
var _abilities: Array[String] = []
var _big_card: CardIcon
var _card_type: Label
var _card_text: Label
var _cards_count: Label
## The Card page was opened from a card in the HUD: Back goes straight back to the game.
var _direct := false


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
	_button(paused, "Cards", func() -> void: _show("Cards"))
	_button(paused, "Options", func() -> void: _show("Options"))
	_save_quit = _button(paused, "Save and Quit", func() -> void: save_quit_pressed.emit())
	_save_quit.hide()
	_quit = _button(paused, "Back to Town", func() -> void: quit_pressed.emit())

	var cards := _page_box("Cards")
	_preview_square = PlayerPreview.new()
	_preview_square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards.add_child(_preview_square)
	_cards_count = Label.new()
	_cards_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_count.add_theme_color_override("font_color", Color("a9b3d1"))
	cards.add_child(_cards_count)
	for i in 3:
		# Each slot is a flat button: tap it to see the card up close.
		var slot := Button.new()
		slot.flat = true
		slot.custom_minimum_size = Vector2(BUTTON_SIZE.x, 44)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.pressed.connect(_open_card.bind(i))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		slot.add_child(row)
		var icon := CardIcon.new()
		row.add_child(icon)
		var name_label := Label.new()
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		cards.add_child(slot)
		_slots.append(icon)
		_slot_names.append(name_label)
		_slot_buttons.append(slot)
	_button(cards, "Back", func() -> void: _show("Paused"))

	var card := _page_box("Card")
	_big_card = CardIcon.new()
	_big_card.card_scale = 4.0
	_big_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(_big_card)
	_card_type = Label.new()
	_card_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_card_type)
	_card_text = Label.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_text.custom_minimum_size = Vector2(280, 0)
	_card_text.add_theme_color_override("font_color", Color("a9b3d1"))
	card.add_child(_card_text)
	_button(card, "Back", _card_back)

	var options := _page_box("Options")
	_button(options, "Sound", func() -> void: _show("Sound"))
	_button(options, "Back", _options_back)

	var sound := _page_box("Sound")
	var m := _slider_row(sound, "Music Volume")
	_music_slider = m[0]
	_music_value = m[1]
	var s := _slider_row(sound, "Sound Volume")
	_sounds_slider = s[0]
	_sounds_value = s[1]
	_sound_toggle = _button(sound, "Sound: On", _toggle_sound)
	_button(sound, "Back", func() -> void: _show("Options"))

	for page in [paused, cards, card, options, sound]:
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


var _save_quit: Button


## Save and Quit only shows during a dungeon run.
func set_save_quit(on: bool) -> void:
	_save_quit.visible = on


## The quit button's label: "Back to Town" in the dungeon, "Main Menu" in town.
func set_quit_text(text: String) -> void:
	_quit.text = text


func open() -> void:
	_from_main = false
	_direct = false
	_sync()
	show()
	_show("Paused")


## Opened from the main menu: just Options (and Sound); Back closes it.
func open_options() -> void:
	_from_main = true
	_sync()
	show()
	_show("Options")


## Fill the Cards page with the player's color and equipped cards.
func set_cards(abilities: Array[String], player_color: Color) -> void:
	_preview_square.color = player_color
	_cards_count.text = "Equipped %d of 3" % abilities.size()
	for i in 3:
		var a := abilities[i] if i < abilities.size() else ""
		_slots[i].ability = a
		_slot_names[i].text = AbilityCard.NAMES[a] if a != "" else "Empty slot"
		_slot_names[i].modulate.a = 1.0 if a != "" else 0.5
		_slot_buttons[i].disabled = a == ""
	_abilities = abilities.duplicate()


func _open_card(i: int) -> void:
	if i >= _abilities.size():
		return
	var a := _abilities[i]
	_big_card.ability = a
	var type_name: String = AbilityCard.TYPES[a]
	_card_type.text = AbilityCard.TYPE_NAMES[type_name]
	_card_type.add_theme_color_override("font_color", AbilityCard.TYPE_COLORS[type_name].lightened(0.25))
	_card_text.text = AbilityCard.DESCRIPTIONS[a]
	_show("Card")


## Opened by tapping an equipped card in the HUD: just that card; Back resumes the game.
func open_card(i: int) -> void:
	open()
	_direct = true
	_open_card(i)


func _card_back() -> void:
	if _direct:
		continue_pressed.emit()
	else:
		_show("Cards")


func _options_back() -> void:
	if _from_main:
		hide()
		closed.emit()
	else:
		_show("Paused")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match _page:
			"Sound": _show("Options")
			"Options": _options_back()
			"Cards": _show("Paused")
			"Card": _card_back()
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
