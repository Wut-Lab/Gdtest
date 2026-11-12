extends Node
## Runs the game: loads the level, spawns the player, and tracks time, hearts, falls and winning.
## You start with 2 hearts (3 with the Heart Box card); each fall or spike hit costs one, and losing the last ends the run.
## In a web build it also lets the page send a level in (used by the level editor).

enum State { READY, PLAY, WON, OUT }

const SETTINGS_PATH := "user://settings.cfg"
const START_HEARTS := 2

@export var level_scene: PackedScene
@export var player_scene: PackedScene

var state := State.READY
var run_time := 0.0
const WIN_REWARD := 3
const FAST_REWARD := 4
const PAR_SLACK := 1.5
var falls := 0
var hearts := START_HEARTS
var hits := 0
var level: Level
## Seed of the random level being played, or 0 for the hand-made level.
var seed_value := 0
## Names the level for the save file's opened-chest list: "main", "seed123" or "custom".
var _level_key := "main"
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
	level.heart_check = func() -> bool: return hearts < _start_hearts()   # no pickups at full health
	level.card_collected.connect(_on_card_collected)
	level.chest_opened.connect(_on_chest_opened)
	level.pixel_collected.connect(_on_pixel_collected)
	level.player_hurt.connect(_on_player_hurt)
	hud.play_requested.connect(new_run)
	hud.main_level_requested.connect(play_main_level)
	hud.random_level_requested.connect(play_random_level)
	hud.pause_requested.connect(pause)
	hud.pause_menu.continue_pressed.connect(resume)
	hud.pause_menu.quit_pressed.connect(go_to_start)
	hud.tuning_panel.closed.connect(func() -> void: hud.pause_button.visible = state == State.PLAY)
	hud.tune_button.pressed.connect(func() -> void: hud.pause_button.hide())
	hud.tuning_panel.player = player
	hud.default_color = player.color
	player.color = _load_player_color(player.color)
	hud.set_player_color(player.color)
	hud.player_color_changed.connect(_on_player_color_changed)
	hud.set_stats(0.0, 0)
	hud.set_hearts(hearts, _start_hearts())
	hud.show_main_menu(player.color)
	$TouchControls.hide()   # touch controls only while playing, so menus get the whole screen
	hud.main_menu.play_pressed.connect(hud.show_start)
	hud.main_menu.options_pressed.connect(hud.pause_menu.open_options)
	get_viewport().size_changed.connect(_on_screen_changed)
	_on_screen_changed()
	_start_music()
	$TouchControls.bar_changed.connect(_fit_to_bar)
	add_child(ScreenBorder.new())
	hud.set_pixels(CardCollection.pixels)
	_setup_web_bridge()


## Soft background music, looping for the whole session. Browsers start it on the first tap
## or key press.
func _start_music() -> void:
	AudioSettings.setup()
	CardCollection.setup()
	var music := AudioStreamPlayer.new()
	music.bus = AudioSettings.MUSIC_BUS
	music.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing in the pause menu
	var stream: AudioStreamOggVorbis = load("res://audio/music.ogg")
	stream.loop = true
	music.stream = stream
	music.volume_db = -12.0
	music.name = "Music"
	add_child(music)
	music.play()


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
	_fit_to_bar()


## Keep the camera inside the level, and treat falling below it as a fall.
## The game fills any screen shape, so there's no top limit: on a tall screen the ground stays
## at the bottom and you see more sky.
func _fit_to_level() -> void:
	var b := level.get_bounds()
	player.camera.limit_left = int(b.position.x)
	player.camera.limit_right = int(b.end.x)
	player.camera.limit_top = -100000
	player.camera.limit_bottom = int(b.end.y)
	_fit_to_bar()
	player.fall_limit_y = b.end.y + 80.0


## Replace the current level with a text map and start playing it.
## On touchscreens the controls sit in a black bar along the bottom. Shift the camera so the
## player is centered in the space above it, and let it show the bar's height below the
## level's floor so the ground ends right at the bar's top edge.
func _fit_to_bar() -> void:
	var bar: float = $TouchControls.bar_height() / player.camera.zoom.y
	player.camera.offset.y = bar / 2.0
	# The offset is added after the limit, so the limit only needs the other half.
	player.camera.limit_bottom = int(level.get_bounds().end.y + bar / 2.0)


func load_level_text(text: String) -> void:
	level.load_map_text(text)
	_sync_chests()
	_fit_to_level()
	get_tree().paused = false
	hud.tuning_panel.hide()
	new_run()


## The hand-made level (levels/level_01.txt).
func play_main_level() -> void:
	seed_value = 0
	_level_key = "main"
	hud.set_seed(0)
	load_level_text(FileAccess.get_file_as_string(level.map_file))


## A random level from a seed; a seed below 1 picks a new one.
func play_random_level(s: int) -> void:
	seed_value = s if s > 0 else LevelGen.random_seed()
	_level_key = "seed%d" % seed_value
	hud.set_seed(seed_value)
	load_level_text(LevelGen.generate(seed_value))


func new_run() -> void:
	player.reset_to(level.start.position)
	player.active = true
	run_time = 0.0
	falls = 0
	hits = 0
	player.abilities.assign(CardCollection.equipped)   # equipped from the collection
	hearts = _start_hearts()
	_show_abilities()
	hud.set_hearts(hearts, _start_hearts())
	level.reset_pickups()
	if _level_key == "custom":
		_sync_chests()   # editor test levels refill their chests every run
	hud.set_pixels(CardCollection.pixels)
	if "secret_helper" in player.abilities \
			and level.get_chests().any(func(c: Node) -> bool: return not c.is_open):
		hud.banner("Secrets to be Found!")   # Secret Helper card
	state = State.PLAY
	hud.hide_menus()
	$TouchControls.show()
	hud.pause_button.show()


## Pause the game and open the pause menu (Pause button, Esc or P).
func pause() -> void:
	if state != State.PLAY or get_tree().paused:
		return
	get_tree().paused = true
	hud.pause_button.hide()
	hud.tune_button.hide()
	$TouchControls.hide()
	hud.pause_menu.set_cards(player.abilities, player.color)
	hud.pause_menu.open()


func resume() -> void:
	hud.pause_menu.hide()
	get_tree().paused = false
	hud.pause_button.show()
	hud.tune_button.show()
	$TouchControls.show()
	get_viewport().gui_release_focus()


## Leave the run and go back to the start screen.
func go_to_start() -> void:
	resume()
	state = State.READY
	player.active = false
	player.reset_to(level.start.position)
	hud.pause_button.hide()
	hud.show_main_menu(player.color)
	$TouchControls.hide()   # touch controls only while playing, so menus get the whole screen


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == State.PLAY and not get_tree().paused:
		pause()
	elif event.is_action_pressed("restart") and not get_tree().paused:
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
func _on_player_hurt(push: Vector2) -> void:
	if state != State.PLAY or player.is_safe():
		return
	if player.try_shrug_off(push):
		return   # Lucky Charm: shrugged it off
	hits += 1
	player.knock_back(push)
	player.slow_burst()
	_lose_heart()


## Hearts at the start of a run: 2, plus 1 for the Heart Box card.
func _start_hearts() -> int:
	return START_HEARTS + (1 if "heart_box" in player.abilities else 0)


func _lose_heart() -> void:
	hearts -= 1
	hud.set_hearts(hearts, _start_hearts())
	hud.hearts_display.flash()
	if hearts <= 0:
		state = State.OUT
		hud.pause_button.hide()
		player.active = false
		player.velocity = Vector2.ZERO
		hud.show_out(run_time, falls)
		$TouchControls.hide()


func _on_heart_collected() -> void:
	hearts = mini(hearts + 1, _start_hearts())
	hud.set_hearts(hearts, _start_hearts())


## Chests this save file already opened stay open (and empty).
func _sync_chests() -> void:
	var chests := level.get_chests()
	for i in chests.size():
		chests[i].set_open(_level_key != "custom" and CardCollection.chest_opened("%s:%d" % [_level_key, i]))
	var pixels := level.get_pixels()
	for i in pixels.size():
		pixels[i].set_taken(_level_key != "custom" and CardCollection.chest_opened("%s:px%d" % [_level_key, i]))


## A floating pixel: +1, remembered like chests so replaying a level doesn't pay out again.
func _on_pixel_collected(index: int) -> void:
	if _level_key != "custom":
		CardCollection.mark_chest("%s:px%d" % [_level_key, index])
	CardCollection.add_pixels(1)
	hud.set_pixels(CardCollection.pixels)


## A chest holds a card 20% of the time (from the Chest Only cards; none yet), otherwise
## 2–10 pixels. A card this file already
## owns turns into 1–2 pixels instead.
func _on_chest_opened(index: int) -> void:
	if _level_key != "custom":
		CardCollection.mark_chest("%s:%d" % [_level_key, index])
	var chest_cards := CardCollection.pool("chest")
	var card: String = chest_cards.pick_random() if randf() < 0.2 and not chest_cards.is_empty() else ""
	if card != "":
		_on_card_collected(card)
	else:
		var n := randi_range(2, 10)
		CardCollection.add_pixels(n)
		hud.set_pixels(CardCollection.pixels)
		hud.toast("Chest: +%d pixels!" % n)


func _on_card_collected(ability: String) -> void:
	# Found cards join the collection for good. A new one is equipped now if a slot is free.
	if CardCollection.add(ability):
		var card_name: String = AbilityCard.NAMES[ability]
		if CardCollection.is_equipped(ability):
			player.abilities.assign(CardCollection.equipped)
			hud.toast("New card: %s! Equipped." % card_name)
		else:
			hud.toast("New card: %s! Added to your collection." % card_name)
	elif _level_key != "custom":
		var n := randi_range(1, 2)
		CardCollection.add_pixels(n)
		hud.set_pixels(CardCollection.pixels)
		hud.toast("Duplicate %s: +%d pixels" % [AbilityCard.NAMES[ability], n])
	_show_abilities()


func _show_abilities() -> void:
	hud.set_cards(player.abilities)
	$TouchControls.set_abilities(player.abilities)


func _on_goal_reached() -> void:
	if state != State.PLAY:
		return
	state = State.WON
	hud.pause_button.hide()
	player.active = false
	player.velocity = Vector2.ZERO
	var reward := win_reward()
	if reward > 0:
		CardCollection.record_win()
		CardCollection.add_pixels(reward)
		hud.set_pixels(CardCollection.pixels)
	hud.show_win(run_time, falls, hearts, seed_value, reward)
	$TouchControls.hide()


## Winning pays 3 pixels, or 4 for a fast run (editor test levels pay nothing).
func win_reward() -> int:
	if _level_key == "custom":
		return 0
	return FAST_REWARD if run_time <= par_time() else WIN_REWARD


## A fast run: start to goal in under 1.5× the time it takes to just run that distance.
func par_time() -> float:
	return absf(level.goal.position.x - level.start.position.x) / player.run_speed * PAR_SLACK


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
		_level_key = "custom"
		load_level_text(str(args[0]))
