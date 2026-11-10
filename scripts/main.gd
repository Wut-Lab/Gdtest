extends Node
## Runs the game: loads the level, spawns the player, and tracks time, hearts, falls and winning.
## You start with 3 hearts; each fall or spike hit costs one, and losing the last ends the run.
## In a web build it also lets the page send a level in (used by the level editor).

enum State { READY, PLAY, WON, OUT }

const SETTINGS_PATH := "user://settings.cfg"
const START_HEARTS := 3
## Heart pickups can take you above the starting amount, up to this.
const MAX_HEARTS := 5

@export var level_scene: PackedScene
@export var player_scene: PackedScene

var state := State.READY
var run_time := 0.0
var falls := 0
var hearts := START_HEARTS
var hits := 0
var level: Level
var player: Player

var _js_load_level: JavaScriptObject

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	level = level_scene.instantiate() as Level
	world.add_child(level)
	player = player_scene.instantiate() as Player
	level.add_child(player)
	_fit_to_level()

	player.reset_to(level.start.position)
	player.fell.connect(_on_player_fell)
	level.goal_reached.connect(_on_goal_reached)
	level.heart_collected.connect(_on_heart_collected)
	level.player_hurt.connect(_on_player_hurt)
	hud.play_requested.connect(new_run)
	hud.tuning_panel.player = player
	hud.default_color = player.color
	player.color = _load_player_color(player.color)
	hud.set_player_color(player.color)
	hud.player_color_changed.connect(_on_player_color_changed)
	hud.set_stats(0.0, 0)
	hud.set_hearts(hearts, START_HEARTS)
	hud.show_start()
	get_viewport().size_changed.connect(_on_screen_changed)
	_on_screen_changed()
	_setup_web_bridge()


## Fill any screen. Landscape uses a 960×544 base; an upright phone switches to 544×960 so the
## menus and buttons stay a readable size, and the camera zooms in so you see about 24 rows
## (the level plus some sky) instead of a thin strip.
func _on_screen_changed() -> void:
	var win := get_window()
	var portrait := win.size.y > win.size.x
	var base := Vector2i(544, 960) if portrait else Vector2i(960, 544)
	if win.content_scale_size != base:
		win.content_scale_size = base   # fires size_changed again, which lands below
		return
	var visible := get_viewport().get_visible_rect().size
	var z := maxf(1.0, visible.y / 760.0)
	player.camera.zoom = Vector2(z, z)


## Keep the camera inside the level, and treat falling below it as a fall.
## The game fills any screen shape, so there's no top limit: on a tall screen the ground stays
## at the bottom and you see more sky.
func _fit_to_level() -> void:
	var b := level.get_bounds()
	player.camera.limit_left = int(b.position.x)
	player.camera.limit_right = int(b.end.x)
	player.camera.limit_top = -100000
	player.camera.limit_bottom = int(b.end.y)
	player.fall_limit_y = b.end.y + 80.0


## Replace the current level with a text map and start playing it.
func load_level_text(text: String) -> void:
	level.load_map_text(text)
	_fit_to_level()
	get_tree().paused = false
	hud.tuning_panel.hide()
	new_run()


func new_run() -> void:
	player.reset_to(level.start.position)
	player.active = true
	run_time = 0.0
	falls = 0
	hits = 0
	hearts = START_HEARTS
	hud.set_hearts(hearts, START_HEARTS)
	level.reset_pickups()
	state = State.PLAY
	hud.hide_menus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		new_run()
	elif state == State.READY and (event.is_action_pressed("move_left")
			or event.is_action_pressed("move_right") or event.is_action_pressed("jump")):
		new_run()


func _process(delta: float) -> void:
	if state == State.PLAY:
		run_time += delta
	hud.set_stats(run_time, falls)


## The player color picked on the start screen is saved on this device.
func _on_player_color_changed(c: Color) -> void:
	player.color = c
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "color", c)
	cfg.save(SETTINGS_PATH)


func _load_player_color(fallback: Color) -> Color:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return fallback
	return cfg.get_value("player", "color", fallback)


func _on_player_fell() -> void:
	falls += 1
	if state != State.PLAY:
		player.reset_to(level.start.position)
		return
	player.reset_to(level.start.position)
	_lose_heart()


## Touched a spike: lose a heart and get knocked away, unless still blinking from the last hit.
func _on_player_hurt(direction: float) -> void:
	if state != State.PLAY or player.invincible > 0.0:
		return
	hits += 1
	player.knock_back(direction if direction != 0.0 else -1.0)
	_lose_heart()


func _lose_heart() -> void:
	hearts -= 1
	hud.set_hearts(hearts, START_HEARTS)
	hud.hearts_display.flash()
	if hearts <= 0:
		state = State.OUT
		player.active = false
		player.velocity = Vector2.ZERO
		hud.show_out(run_time, falls)


func _on_heart_collected() -> void:
	hearts = mini(hearts + 1, MAX_HEARTS)
	hud.set_hearts(hearts, START_HEARTS)


func _on_goal_reached() -> void:
	if state != State.PLAY:
		return
	state = State.WON
	player.active = false
	player.velocity = Vector2.ZERO
	hud.show_win(run_time, falls, hearts)


# ---------- Web page bridge ----------

func _setup_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_js_load_level = JavaScriptBridge.create_callback(_on_js_load_level)
	var window := JavaScriptBridge.get_interface("window")
	window.squareHopLoadLevel = _js_load_level
	var pending: Variant = window.squareHopPendingLevel
	if pending is String and pending != "":
		load_level_text(pending)
	JavaScriptBridge.eval("window.dispatchEvent(new Event('squarehop-ready'))")


func _on_js_load_level(args: Array) -> void:
	if args.size() > 0:
		load_level_text(str(args[0]))
