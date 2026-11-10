extends SceneTree
# Pass 2: write the Input Map, tile set, UI theme and every scene as editor-native files.

const T := 32
const W := 960.0
const H := 544.0
const SKY_TOP := Color("1b2440")
const SKY_BOT := Color("3d4f7c")
const INK := Color("eef1fa")
const INK_DIM := Color("a9b3d1")
const GOAL := Color("79e2c2")
const PANEL := Color(0.067, 0.09, 0.169, 0.92)

var failed := false


func _initialize() -> void:
	_setup_project()
	_check(ResourceSaver.save(_make_tileset(), "res://art/tileset.tres"), "tileset")
	_check(ResourceSaver.save(_make_theme(), "res://art/ui_theme.tres"), "theme")
	_save_scene(_player_scene(), "res://scenes/player.tscn")
	_save_scene(_goal_scene(), "res://scenes/goal.tscn")
	_save_scene(_teleporter_scene(), "res://scenes/teleporter.tscn")
	_save_scene(_hud_scene(), "res://scenes/hud.tscn")
	_save_scene(_touch_scene(), "res://scenes/touch_controls.tscn")
	_save_scene(_level_scene(), "res://levels/level_01.tscn")
	_save_scene(_main_scene(), "res://scenes/main.tscn")
	print("BUILD FAILED" if failed else "BUILD OK")
	quit(1 if failed else 0)


func _check(err: int, what: String) -> void:
	if err != OK:
		failed = true
		push_error("Could not save %s (error %d)" % [what, err])


func _save_scene(root: Node, path: String) -> void:
	_set_owner(root, root)
	var packed := PackedScene.new()
	_check(packed.pack(root), "pack " + path)
	_check(ResourceSaver.save(packed, path), path)
	root.free()


func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		if child.scene_file_path == "":   # don't reach inside instanced scenes
			_set_owner(child, owner)


func _full_rect(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0


# ---------- Project settings ----------

func _setup_project() -> void:
	var keys := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"jump": [KEY_SPACE, KEY_UP, KEY_W, KEY_Z],
		"restart": [KEY_R],
	}
	var joy_buttons := {
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"jump": JOY_BUTTON_A,
	}
	var joy_axis := {"move_left": -1.0, "move_right": 1.0}
	for action in keys:
		var events := []
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			ev.device = -1
			events.append(ev)
		if joy_buttons.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = joy_buttons[action]
			jb.device = -1
			events.append(jb)
		if joy_axis.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = JOY_AXIS_LEFT_X
			jm.axis_value = joy_axis[action]
			jm.device = -1
			events.append(jm)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.3, "events": events})
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main.tscn")
	# Fill any screen shape: the shorter side shows 544 px of level, the longer side shows more.
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("application/config/description", "A small platformer: run and jump to the goal.")
	_check(ProjectSettings.save(), "project.godot")


# ---------- Resources ----------

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "rubber")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://art/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	for i in 4:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	var square := PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	for i in 4:
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
		if i == 2:
			td.set_collision_polygon_one_way(0, 0, true)   # jump up through floating platforms
		if i == 3:
			td.set_custom_data("rubber", true)             # the player bounces off it
	return ts


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 16
	th.set_color("font_color", "Label", INK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(22)
	panel.border_color = Color(INK, 0.15)
	panel.set_border_width_all(1)
	th.set_stylebox("panel", "PanelContainer", panel)

	for state_name in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = GOAL.darkened(0.15) if state_name == "pressed" else GOAL
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(10)
		if state_name == "focus":
			sb.draw_center = false
			sb.border_color = INK
			sb.set_border_width_all(2)
			sb.set_expand_margin_all(3)
		th.set_stylebox(state_name, "Button", sb)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(color_name, "Button", SKY_TOP)
	th.set_font_size("font_size", "Button", 18)

	th.set_type_variation("TitleLabel", "Label")
	th.set_font_size("font_size", "TitleLabel", 28)
	th.set_type_variation("BodyLabel", "Label")
	th.set_font_size("font_size", "BodyLabel", 15)
	th.set_color("font_color", "BodyLabel", INK_DIM)
	th.set_type_variation("StatLabel", "Label")
	th.set_font_size("font_size", "StatLabel", 20)
	th.set_type_variation("SmallLabel", "Label")
	th.set_font_size("font_size", "SmallLabel", 14)
	th.set_color("font_color", "SmallLabel", INK_DIM)
	return th


# ---------- Scenes ----------

func _player_scene() -> Node:
	var p := CharacterBody2D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.floor_snap_length = 4.0
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	p.add_child(col)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	p.add_child(cam)
	# Dust puff at the feet on jumps, landings and bounces (world-space, one shot).
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.position = Vector2(0, 12)
	dust.emitting = false
	dust.one_shot = true
	dust.amount = 8
	dust.lifetime = 0.4
	dust.explosiveness = 1.0
	dust.local_coords = false
	dust.direction = Vector2(0, -1)
	dust.spread = 75.0
	dust.gravity = Vector2(0, 400)
	dust.initial_velocity_min = 50.0
	dust.initial_velocity_max = 140.0
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, Color(INK, 0.9))
	fade.set_color(1, Color(INK, 0.0))
	dust.color_ramp = fade
	p.add_child(dust)
	return p


func _goal_scene() -> Node:
	var g := Area2D.new()
	g.name = "Goal"
	g.set_script(load("res://scripts/goal.gd"))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	g.add_child(col)
	return g


func _teleporter_scene() -> Node:
	var t := Area2D.new()
	t.name = "Teleporter"
	t.set_script(load("res://scripts/teleporter.gd"))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	t.add_child(col)
	return t


func _hud_scene() -> Node:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	var root := Control.new()
	root.name = "Root"
	root.theme = load("res://art/ui_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_rect(root)
	hud.add_child(root)

	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.unique_name_in_owner = true
	time_label.theme_type_variation = "StatLabel"
	time_label.position = Vector2(14, 8)
	time_label.text = "0.00s"
	root.add_child(time_label)

	var falls_label := Label.new()
	falls_label.name = "FallsLabel"
	falls_label.unique_name_in_owner = true
	falls_label.theme_type_variation = "SmallLabel"
	falls_label.position = Vector2(14, 36)
	falls_label.text = "Falls 0"
	root.add_child(falls_label)

	_menu(root, "StartMenu", "Reach the goal",
		"Run and jump through the level to the green goal. Hold jump to go higher. "
		+ "You can steer a little in mid-air.\n\n"
		+ "Keys: arrows or A/D to move, Space to jump, R to restart.",
		"StartBody", "PlayButton", "Play")
	var win := _menu(root, "WinMenu", "Goal reached", "Time 0.00s  ·  Falls 0",
		"ResultLabel", "AgainButton", "Play again")
	win.visible = false

	var tune := Button.new()
	tune.name = "TuneButton"
	tune.unique_name_in_owner = true
	tune.text = "Tune"
	tune.anchor_left = 1.0
	tune.anchor_right = 1.0
	tune.offset_left = -102.0
	tune.offset_right = -14.0
	tune.offset_top = 10.0
	tune.offset_bottom = 54.0
	tune.focus_mode = Control.FOCUS_NONE
	root.add_child(tune)

	var panel := Control.new()
	panel.name = "TuningPanel"
	panel.unique_name_in_owner = true
	panel.set_script(load("res://scripts/tuning_panel.gd"))
	_full_rect(panel)
	root.add_child(panel)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS   # menus keep working while the game is paused
	return hud


func _menu(parent: Control, menu_name: String, title: String, body: String,
		body_name: String, button_name: String, button_text: String) -> Control:
	var center := CenterContainer.new()
	center.name = menu_name
	center.unique_name_in_owner = true
	_full_rect(center)
	parent.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.theme_type_variation = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var body_label := Label.new()
	body_label.name = body_name
	body_label.unique_name_in_owner = true
	body_label.text = body
	body_label.theme_type_variation = "BodyLabel"
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(body_label)

	var button := Button.new()
	button.name = button_name
	button.unique_name_in_owner = true
	button.text = button_text
	button.custom_minimum_size = Vector2(160, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(button)
	return center


func _touch_scene() -> Node:
	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	layer.layer = 2
	layer.set_script(load("res://scripts/touch_controls.gd"))
	var pad := Node2D.new()
	pad.name = "Pad"
	layer.add_child(pad)

	var margin := 18.0
	var left := _touch_button(pad, "Left", "move_left", 76, false, Vector2(margin, H - margin - 76))
	_arrow(left, 76, -1.0)
	var right := _touch_button(pad, "Right", "move_right", 76, false, Vector2(margin + 88, H - margin - 76))
	_arrow(right, 76, 1.0)
	var jump := _touch_button(pad, "Jump", "jump", 92, true, Vector2(W - margin - 92, H - margin - 92))
	var label := Label.new()
	label.name = "Label"
	label.text = "JUMP"
	label.size = Vector2(92, 92)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK)
	jump.add_child(label)
	return layer


func _touch_button(parent: Node, node_name: String, action: String, diameter: int, big: bool,
		pos: Vector2) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.name = node_name
	b.action = action
	b.passby_press = true
	b.texture_normal = load("res://art/button_big.png" if big else "res://art/button.png")
	b.texture_pressed = load("res://art/button_big_pressed.png" if big else "res://art/button_pressed.png")
	var shape := CircleShape2D.new()
	shape.radius = diameter / 2.0
	b.shape = shape
	b.position = pos
	parent.add_child(b)
	return b


func _arrow(button: Node2D, diameter: int, direction: float) -> void:
	var c := diameter / 2.0
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.color = INK
	arrow.polygon = PackedVector2Array([
		Vector2(c + 9.0 * direction, c),
		Vector2(c - 7.0 * direction, c - 14.0),
		Vector2(c - 7.0 * direction, c + 14.0),
	])
	button.add_child(arrow)


func _level_scene() -> Node:
	var level := Node2D.new()
	level.name = "Level01"
	level.set_script(load("res://scripts/level.gd"))
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load("res://art/tileset.tres")
	level.add_child(ground)
	# The layout lives in a text map; the level paints Ground from it when it loads.
	level.set("map_file", "res://levels/level_01.txt")
	level.set("teleporter_scene", load("res://scenes/teleporter.tscn"))

	var start := Marker2D.new()
	start.name = "Start"
	start.position = Vector2(2 * T + 16, 15 * T - 12)
	level.add_child(start)

	var goal: Node2D = load("res://scenes/goal.tscn").instantiate()
	goal.name = "Goal"
	goal.position = Vector2(88 * T + 16, 11 * T - 18)
	level.add_child(goal)
	return level



func _main_scene() -> Node:
	var main := Node.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	main.set("level_scene", load("res://levels/level_01.tscn"))
	main.set("player_scene", load("res://scenes/player.tscn"))

	var bg := CanvasLayer.new()
	bg.name = "Background"
	bg.layer = -1
	main.add_child(bg)
	var sky := TextureRect.new()
	sky.name = "Sky"
	_full_rect(sky)
	var grad := Gradient.new()
	grad.set_color(0, SKY_TOP)
	grad.set_color(1, SKY_BOT)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	sky.texture = tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	bg.add_child(sky)

	var world := Node2D.new()
	world.name = "World"
	main.add_child(world)

	var hud: Node = load("res://scenes/hud.tscn").instantiate()
	hud.name = "HUD"
	main.add_child(hud)
	var touch: Node = load("res://scenes/touch_controls.tscn").instantiate()
	touch.name = "TouchControls"
	main.add_child(touch)
	return main
