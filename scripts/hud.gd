class_name Hud
extends CanvasLayer
## Timer, fall counter, hearts, the start and win menus, and the Tune button.

## Replay the current level.
signal play_requested
signal main_level_requested
## seed_value below 1 means pick a new random seed.
signal random_level_requested(seed_value: int)
signal pause_requested
signal player_color_changed(color: Color)
## Town: go back to town (from the dungeon gate, a win or running out of hearts).
signal town_requested
## The dungeon gate: start a floor ("moss" = Mossy Cave).
signal floor_requested(floor_id: String)
## Town: the Enter button by a building's door.
signal enter_pressed
signal like_pressed
## One of the small equipped cards in the corner was tapped (slot 0–2).
signal card_pressed(slot: int)

@onready var time_label: Label = %TimeLabel
@onready var falls_label: Label = %FallsLabel
@onready var start_menu: Control = %StartMenu
@onready var win_menu: Control = %WinMenu
@onready var result_label: Label = %ResultLabel
@onready var play_button: Button = %PlayButton
@onready var again_button: Button = %AgainButton
@onready var random_button: Button = %RandomButton
@onready var seed_edit: LineEdit = %SeedEdit
@onready var new_level_button: Button = %NewLevelButton
@onready var seed_label: Label = %SeedLabel
@onready var cards_label: Label = %CardsLabel
var pixel_counter: PixelCounter
var enter_button: Button
var like_button: Button
## Small equipped cards under the timer (dotted outlines for empty slots).
var card_row: HBoxContainer
var _card_icons: Array[CardIcon] = []
var _card_buttons: Array[Button] = []
@onready var out_menu: Control = %OutMenu
@onready var out_label: Label = %OutLabel
@onready var retry_button: Button = %RetryButton
@onready var hearts_display: HeartsDisplay = %HeartsDisplay
@onready var pause_button: Button = %PauseButton
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var main_menu: MainMenu = %MainMenu
@onready var tune_button: Button = %TuneButton
@onready var tuning_panel: TuningPanel = %TuningPanel
@onready var color_wheel: ColorWheel = %ColorWheel
@onready var brightness: HSlider = %Brightness
@onready var color_preview: ColorRect = %ColorPreview
@onready var color_reset: Button = %ColorReset

## The game's built-in player color, for the Reset button. Main sets it.
var default_color := Color("ff6b5e")


func _ready() -> void:
	# Pixel count in the top-right corner, under the Pause and Tune buttons.
	pixel_counter = PixelCounter.new()
	pixel_counter.anchor_left = 1.0
	pixel_counter.anchor_right = 1.0
	pixel_counter.offset_left = -160.0
	pixel_counter.offset_right = -16.0
	pixel_counter.offset_top = 62.0
	pixel_counter.offset_bottom = 88.0
	pixel_counter.alignment = BoxContainer.ALIGNMENT_END
	add_child(pixel_counter)
	move_child(pixel_counter, 0)   # under the menus
	# A dark outline on the stats so they stay readable over sand-coloured walls.
	for l: Label in [time_label, falls_label, seed_label]:
		l.add_theme_color_override("font_outline_color", Color("1b2440"))
		l.add_theme_constant_override("outline_size", 5)
	# The equipped cards, small, under the timer. Tap one to see it (pauses the game).
	cards_label.hide()
	card_row = HBoxContainer.new()
	card_row.position = cards_label.position
	card_row.add_theme_constant_override("separation", 6)
	for i in 3:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		var icon := CardIcon.new()
		icon.card_scale = 1.25
		b.custom_minimum_size = icon.custom_minimum_size
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(icon)
		b.pressed.connect(func() -> void:
			if icon.ability != "":
				card_pressed.emit(i))
		card_row.add_child(b)
		_card_icons.append(icon)
		_card_buttons.append(b)
	$Root.add_child(card_row)
	$Root.move_child(card_row, cards_label.get_index())
	# Town: an Enter button that shows up while standing at a building's door.
	enter_button = Button.new()
	enter_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	enter_button.offset_left = -130.0
	enter_button.offset_right = 130.0
	enter_button.offset_top = 64.0
	enter_button.offset_bottom = 112.0
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.hide()
	enter_button.pressed.connect(enter_pressed.emit)
	$Root.add_child(enter_button)
	$Root.move_child(enter_button, pixel_counter.get_index() + 1)
	# The start screen is now the dungeon gate, reached from town.
	start_menu.get_node("Panel/Box/Title").text = "The Dungeon"
	play_button.text = "Training level"
	for menu in [start_menu, win_menu, out_menu]:
		var town := Button.new()
		town.text = "Back to Town"
		town.custom_minimum_size = Vector2(200, 44)
		town.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		town.pressed.connect(town_requested.emit)
		menu.get_node("Panel/Box").add_child(town)
	# Floors: a run of 5 levels in a row (hearts carry over), then a boss.
	var floors := HBoxContainer.new()
	floors.alignment = BoxContainer.ALIGNMENT_CENTER
	var moss := Button.new()
	moss.text = "Mossy Cave  (5 levels + boss)"
	moss.custom_minimum_size = Vector2(300, 44)
	moss.add_theme_color_override("font_color", Color("1b2440"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("6cc04f")
	sb.set_corner_radius_all(8)
	for st in ["normal", "hover", "pressed", "focus"]:
		moss.add_theme_stylebox_override(st, sb)
	moss.pressed.connect(func() -> void: floor_requested.emit("moss"))
	floors.add_child(moss)
	var sbox := start_menu.get_node("Panel/Box")
	sbox.add_child(floors)
	sbox.move_child(floors, sbox.get_node("LevelRow").get_index() + 1)
	like_button = Button.new()
	like_button.custom_minimum_size = Vector2(200, 44)
	like_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	like_button.pressed.connect(like_pressed.emit)
	var box := win_menu.get_node("Panel/Box")
	box.add_child(like_button)
	box.move_child(like_button, new_level_button.get_index() + 1)
	play_button.pressed.connect(main_level_requested.emit)
	random_button.pressed.connect(func() -> void:
		random_level_requested.emit(seed_edit.text.strip_edges().to_int()))
	seed_edit.text_submitted.connect(func(_t: String) -> void: random_button.pressed.emit())
	new_level_button.pressed.connect(func() -> void: random_level_requested.emit(0))
	again_button.pressed.connect(play_requested.emit)
	retry_button.pressed.connect(play_requested.emit)
	tune_button.pressed.connect(tuning_panel.open)
	pause_button.pressed.connect(pause_requested.emit)
	tuning_panel.closed.connect(func() -> void: get_viewport().gui_release_focus())
	color_wheel.changed.connect(_on_color_input)
	brightness.value_changed.connect(func(_v: float) -> void: _on_color_input())
	color_reset.pressed.connect(func() -> void:
		set_player_color(default_color)
		player_color_changed.emit(default_color))


## Shows a color on the wheel, slider and preview without announcing a change.
func set_player_color(c: Color) -> void:
	color_wheel.set_hsv(c.h, c.s, c.v)
	brightness.set_value_no_signal(c.v)
	color_preview.color = c


func _on_color_input() -> void:
	var c := Color.from_hsv(color_wheel.hue, color_wheel.saturation, brightness.value)
	color_wheel.value = brightness.value
	color_preview.color = c
	player_color_changed.emit(c)


## Town hides the run's timer, falls, hearts and seed.
func set_town_mode(on: bool) -> void:
	for n in [time_label, falls_label, hearts_display]:
		n.visible = not on
	if on:
		seed_label.hide()
	enter_button.hide()


## The win screen's Like button (shown once the Replay Room is open, on random levels).
func set_like(shown: bool, liked: bool) -> void:
	like_button.visible = shown
	like_button.text = "♥ Saved to Replay Room" if liked else "♡ Save to Replay Room"


## Shows the Enter button for a building ("" hides it).
func show_enter(place: String, verb := "Enter") -> void:
	enter_button.text = "%s %s" % [verb, place]
	enter_button.visible = place != ""


## The title screen, with the player's square in their color.
func show_main_menu(player_color: Color) -> void:
	start_menu.hide()
	win_menu.hide()
	out_menu.hide()
	tune_button.hide()
	main_menu.open(player_color)


func show_start() -> void:
	main_menu.hide()
	tune_button.show()
	start_menu.show()
	win_menu.hide()
	out_menu.hide()
	play_button.grab_focus()


## In a floor run: the win menu's New level button becomes "Next level", and Play again hides.
func set_floor_win(next_text: String) -> void:
	new_level_button.visible = next_text != ""
	new_level_button.text = next_text if next_text != "" else "New level"
	again_button.visible = false
	like_button.hide()
	(new_level_button if next_text != "" else win_menu.get_node("Panel/Box").get_child(-1)).grab_focus()


func show_win(time: float, falls: int, hearts: int, seed_value: int, reward := 0) -> void:
	again_button.visible = true
	new_level_button.text = "New level"
	result_label.text = "Time %.2fs  ·  Falls %d  ·  Hearts %d" % [time, falls, hearts]
	if reward > 0:
		result_label.text += "\n+%d pixels%s" % [reward, "  ·  Fast run!" if reward > 3 else ""]
	if seed_value > 0:
		result_label.text += "\nSeed %d" % seed_value
	new_level_button.visible = seed_value > 0
	start_menu.hide()
	win_menu.show()
	again_button.grab_focus()


func show_out(time: float, falls: int) -> void:
	out_label.text = "Out of hearts after %.2fs. Try again?" % time
	start_menu.hide()
	out_menu.show()
	retry_button.grab_focus()


## A short message that floats in near the top of the screen and fades away.
## A big message in the middle of the screen: fades in, stays 3 seconds, fades out.
func banner(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -260
	l.offset_right = 260
	l.offset_top = 165   # below the HUD cards, so it never covers them on a narrow screen
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color("f2c230"))
	l.add_theme_color_override("font_outline_color", Color("1b2440"))
	l.add_theme_constant_override("outline_size", 8)
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -240
	l.offset_right = 240
	l.offset_top = 70
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color("1b2440"))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func set_pixels(n: int) -> void:
	pixel_counter.set_pixels(n)


## Shows the ability cards equipped for this run as small cards (empty slots are dotted).
func set_cards(abilities: Array[String]) -> void:
	for i in 3:
		var a := abilities[i] if i < abilities.size() else ""
		_card_icons[i].ability = a
		_card_buttons[i].mouse_default_cursor_shape = \
			Control.CURSOR_POINTING_HAND if a != "" else Control.CURSOR_ARROW


## Shows the random level's seed in the corner (hidden for the hand-made level).
func set_seed(seed_value: int) -> void:
	seed_label.text = "Seed %d" % seed_value
	seed_label.visible = seed_value > 0


func set_hearts(hearts: int, slots: int) -> void:
	hearts_display.slots = slots
	hearts_display.hearts = hearts


func hide_menus() -> void:
	main_menu.hide()
	tune_button.show()
	start_menu.hide()
	win_menu.hide()
	out_menu.hide()
	get_viewport().gui_release_focus()


func set_stats(time: float, falls: int) -> void:
	time_label.text = "%.2fs" % time
	falls_label.text = "Falls %d" % falls
