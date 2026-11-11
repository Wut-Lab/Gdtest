class_name Hud
extends CanvasLayer
## Timer, fall counter, hearts, the start and win menus, and the Tune button.

signal play_requested
signal pause_requested
signal player_color_changed(color: Color)

@onready var time_label: Label = %TimeLabel
@onready var falls_label: Label = %FallsLabel
@onready var start_menu: Control = %StartMenu
@onready var win_menu: Control = %WinMenu
@onready var result_label: Label = %ResultLabel
@onready var play_button: Button = %PlayButton
@onready var again_button: Button = %AgainButton
@onready var out_menu: Control = %OutMenu
@onready var out_label: Label = %OutLabel
@onready var retry_button: Button = %RetryButton
@onready var hearts_display: HeartsDisplay = %HeartsDisplay
@onready var pause_button: Button = %PauseButton
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var tune_button: Button = %TuneButton
@onready var tuning_panel: TuningPanel = %TuningPanel
@onready var color_wheel: ColorWheel = %ColorWheel
@onready var brightness: HSlider = %Brightness
@onready var color_preview: ColorRect = %ColorPreview
@onready var color_reset: Button = %ColorReset

## The game's built-in player color, for the Reset button. Main sets it.
var default_color := Color("ff6b5e")


func _ready() -> void:
	play_button.pressed.connect(play_requested.emit)
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


func show_start() -> void:
	start_menu.show()
	win_menu.hide()
	out_menu.hide()
	play_button.grab_focus()


func show_win(time: float, falls: int, hearts: int) -> void:
	result_label.text = "Time %.2fs  ·  Falls %d  ·  Hearts %d" % [time, falls, hearts]
	start_menu.hide()
	win_menu.show()
	again_button.grab_focus()


func show_out(time: float, falls: int) -> void:
	out_label.text = "Out of hearts after %.2fs. Try again?" % time
	start_menu.hide()
	out_menu.show()
	retry_button.grab_focus()


func set_hearts(hearts: int, slots: int) -> void:
	hearts_display.slots = slots
	hearts_display.hearts = hearts


func hide_menus() -> void:
	start_menu.hide()
	win_menu.hide()
	out_menu.hide()
	get_viewport().gui_release_focus()


func set_stats(time: float, falls: int) -> void:
	time_label.text = "%.2fs" % time
	falls_label.text = "Falls %d" % falls
