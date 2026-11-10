class_name TuningPanel
extends Control
## In-game sliders for the player's movement values. Changes apply instantly, are saved on
## this device, and "Copy settings" gives a line of text to make them the new defaults.

signal closed

const SAVE_PATH := "user://tuning.cfg"
const SETTINGS := [
	# [property, label, min, max, step]
	["run_speed", "Run speed", 100.0, 500.0, 5.0],
	["ground_accel", "Ground acceleration", 500.0, 6000.0, 50.0],
	["air_accel", "Air steering", 0.0, 3000.0, 25.0],
	["jump_velocity", "Jump strength", 400.0, 1200.0, 10.0],
	["gravity", "Gravity", 800.0, 4000.0, 50.0],
	["short_hop_gravity", "Short-hop pull", 1.0, 5.0, 0.1],
	["max_fall_speed", "Max fall speed", 400.0, 1600.0, 25.0],
	["coyote_time", "Ledge grace (s)", 0.0, 0.3, 0.01],
	["jump_buffer_time", "Early jump grace (s)", 0.0, 0.3, 0.01],
	["rubber_bounciness", "Rubber bounciness", 0.3, 1.0, 0.01],
	["rubber_boost", "Rubber boost (hold jump)", 1.0, 2.0, 0.05],
	["wall_kick", "Rubber wall kick", 100.0, 700.0, 10.0],
	["wall_jump", "Rubber wall jump", 0.5, 1.5, 0.05],
	["wall_stun", "Wall bounce no-steer (s)", 0.0, 0.6, 0.01],
	["squash_recovery", "Squash settle speed", 3.0, 30.0, 0.5],
]

var player: Player:
	set = set_player

var _defaults := {}
var _sliders := {}
var _value_labels := {}
var _status: Label


func _ready() -> void:
	_build()
	hide()


func set_player(p: Player) -> void:
	player = p
	for s in SETTINGS:
		_defaults[s[0]] = player.get(s[0])
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for s in SETTINGS:
			if cfg.has_section_key("player", s[0]):
				player.set(s[0], float(cfg.get_value("player", s[0])))
	_sync_sliders()


func open() -> void:
	_sync_sliders()
	_status.text = ""
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func settings_text() -> String:
	var parts := PackedStringArray()
	for s in SETTINGS:
		parts.append("%s=%s" % [s[0], _fmt(float(player.get(s[0])), s[4])])
	return "Square Hop tuning: " + ", ".join(parts)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	# Solid background so the menus behind don't show through.
	var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb:
		sb.bg_color.a = 1.0
		panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Tuning"
	title.theme_type_variation = "TitleLabel"
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	for s in SETTINGS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := Label.new()
		name_label.text = s[1]
		name_label.custom_minimum_size = Vector2(210, 0)
		name_label.theme_type_variation = "BodyLabel"
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = s[2]
		slider.max_value = s[3]
		slider.step = s[4]
		slider.custom_minimum_size = Vector2(0, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider_changed.bind(s[0], s[4]))
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(64, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		rows.add_child(row)
		_sliders[s[0]] = slider
		_value_labels[s[0]] = value_label

	_status = Label.new()
	_status.theme_type_variation = "SmallLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 0)
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	for b in [["Reset", _on_reset], ["Copy settings", _on_copy], ["Done", close]]:
		var button := Button.new()
		button.text = b[0]
		button.custom_minimum_size = Vector2(120, 44)
		button.pressed.connect(b[1])
		buttons.add_child(button)


func _sync_sliders() -> void:
	if player == null or _sliders.is_empty():
		return
	for s in SETTINGS:
		var v := float(player.get(s[0]))
		(_sliders[s[0]] as HSlider).set_value_no_signal(v)
		(_value_labels[s[0]] as Label).text = _fmt(v, s[4])


func _on_slider_changed(value: float, prop: String, step: float) -> void:
	player.set(prop, value)
	(_value_labels[prop] as Label).text = _fmt(value, step)
	_save()


func _on_reset() -> void:
	for prop in _defaults:
		player.set(prop, _defaults[prop])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_sync_sliders()
	_status.text = "Back to the game's built-in values."


func _on_copy() -> void:
	var text := settings_text()
	DisplayServer.clipboard_set(text)
	_status.text = "Copied. Paste it to Claude to make these the defaults:\n" + text


func _save() -> void:
	var cfg := ConfigFile.new()
	for s in SETTINGS:
		cfg.set_value("player", s[0], player.get(s[0]))
	cfg.save(SAVE_PATH)


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	return ("%.2f" % v) if step < 0.1 else ("%.1f" % v)
