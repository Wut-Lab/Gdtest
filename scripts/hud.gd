class_name Hud
extends CanvasLayer
## Timer, fall counter, the start and win menus, and the Tune button.

signal play_requested

@onready var time_label: Label = %TimeLabel
@onready var falls_label: Label = %FallsLabel
@onready var start_menu: Control = %StartMenu
@onready var win_menu: Control = %WinMenu
@onready var result_label: Label = %ResultLabel
@onready var play_button: Button = %PlayButton
@onready var again_button: Button = %AgainButton
@onready var tune_button: Button = %TuneButton
@onready var tuning_panel: TuningPanel = %TuningPanel


func _ready() -> void:
	play_button.pressed.connect(play_requested.emit)
	again_button.pressed.connect(play_requested.emit)
	tune_button.pressed.connect(tuning_panel.open)
	tuning_panel.closed.connect(func() -> void: get_viewport().gui_release_focus())


func show_start() -> void:
	start_menu.show()
	win_menu.hide()
	play_button.grab_focus()


func show_win(time: float, falls: int) -> void:
	result_label.text = "Time %.2fs  ·  Falls %d" % [time, falls]
	start_menu.hide()
	win_menu.show()
	again_button.grab_focus()


func hide_menus() -> void:
	start_menu.hide()
	win_menu.hide()
	get_viewport().gui_release_focus()


func set_stats(time: float, falls: int) -> void:
	time_label.text = "%.2fs" % time
	falls_label.text = "Falls %d" % falls
