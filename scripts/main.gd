extends Node
## Runs the game: loads the level, spawns the player, and tracks time, hearts, falls and winning.
## You start with 2 hearts (3 with the Heart Box card); each fall or spike hit costs one, and losing the last ends the run.
## In a web build it also lets the page send a level in (used by the level editor).

## TOWN: walking around Square Hub Town. MENU: inside a town building (shop, cards, dungeon gate).
enum State { READY, PLAY, WON, OUT, TOWN, MENU }

const TOWN_MAP := "res://levels/town.txt"

const SETTINGS_PATH := "user://settings.cfg"
const START_HEARTS := 2

@export var level_scene: PackedScene
@export var player_scene: PackedScene

var state := State.READY
var run_time := 0.0
const WIN_REWARD := 3
## Terry, the lazy yellow block in town, says one of these when you talk to him.
const _WALKER_LINES := ["Hi!", "It's a good day to dungeon dive!", "Have a great dive!"]
const TOWNSFOLK_LINES := {"paula": _WALKER_LINES, "tim": _WALKER_LINES,
	"romeo": ["I like the view from up here!"],
	"larry": ["Oh, hey! I'm Larry. Heard there was a nice pond out here.",
		"I'm still unpacking my fishing gear... come back once I've found my good hooks!"]}
## How many times you've talked to each townsfolk (their lines go in order).
var _talks := {}
var dialog: DialogBox
## Larry was in town when it was last built (so his arrival can be announced).
var _larry_shown := false
const TERRY_LINES := ["Mmh... five more minutes.", "Paul's up there? Good for him. I'm good down here.",
	"Jumping? Sounds exhausting.", "Zzz...", "Wake me when it's lunch."]
## First Hard or Scramble clear of a liked level.
const REPLAY_REWARD := 3
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
## Replay Room mode of the level being played: "", "true", "hard" or "scramble".
var _replay_mode := ""
## Safety Bubble card: already caught you this level (until the checkpoint).
var _bubble_used := false
## Which town door the last run started from, so Back to Town returns there.
var _came_from := "dungeon"
## Dungeon areas, in order. Each is a run of 5 fixed levels (hearts carry over), then its boss.
## An area shows at the gate once the boss of the area before it is beaten.
const AREAS := [
	{"id": "basic", "name": "Basic", "first": 1, "levels": 5, "extra": 12,
		"boss": "res://levels/boss_basic.txt", "boss_name": "Big Bad Square"},
	{"id": "moss", "name": "Mossy Cave", "first": 6, "levels": 5,
		"boss": "res://levels/boss_moss.txt", "boss_name": "Old Mossback"},
]
const FLOOR_CLEAR_REWARD := 10
## Beating a boss the first time: these pixels plus its card (Dash first, if you lack it).
const BOSS_REWARD := 25
## Each boss gives its area's own card if you don't have it yet, otherwise the boss's card.
const BOSS_CARDS := {"basic": "chain_dash", "moss": "bark_hide"}
const AREA_CARDS := {"basic": "dash", "moss": "overgrowth"}
## Longest level a run may roll, in tiles.
const MAX_LEVEL_TILES := 240
## Extra Bad Blocks added to an area's 1st..5th level: a little harder nearer the boss.
const EXTRA_BAD_BLOCKS := [0, 1, 1, 2, 2]
var _floor := ""   # the area being played ("" = none)
var _floor_step := 0
var _floor_seeds: Array[int] = []
## Hearts carried into the next level of a floor (-1 = start fresh).
var _carry_hearts := -1
var _rematch := false   # a Rematch: straight to the boss, no rewards
var _level_hearts := 0  # hearts at the start of this level (Save and Quit goes back to it)
var player: Player
## The town building the player is standing at ("" = none).
var _near_door := ""
## Where falls send you: the start, or the last checkpoint touched this run.
var _respawn := Vector2.ZERO
var _music_track := ""
var _ding: AudioStreamPlayer

var _js_load_level: JavaScriptObject

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	level = level_scene.instantiate() as Level
	world.add_child(level)
	player = player_scene.instantiate() as Player
	player.water = level.water
	player.slip_check = level.is_slippery
	level.add_child(player)
	_fit_to_level()

	player.reset_to(level.start.position)
	player.fell.connect(_on_player_fell)
	player.grew_moss.connect(func(pos: Vector2) -> void:
		if state == State.PLAY:
			level.add_overgrowth(level.to_local(pos)))
	player.pay_heart = _pay_angry_heart
	get_tree().node_added.connect(_hook_button_haptics)
	for n in find_children("*", "BaseButton", true, false):
		_hook_button_haptics(n)
	level.goal_reached.connect(_on_goal_reached)
	level.heart_collected.connect(_on_heart_collected)
	level.heart_check = func() -> bool: return hearts < _start_hearts()   # no pickups at full health
	level.card_collected.connect(_on_card_collected)
	level.chest_opened.connect(_on_chest_opened)
	level.obstacle_broken.connect(_on_obstacle_broken)
	level.pixel_collected.connect(_on_pixel_collected)
	level.player_hurt.connect(_on_player_hurt)
	level.door_near.connect(_on_door_near)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.boss_defeated.connect(_on_boss_defeated)
	_ding = AudioStreamPlayer.new()
	_ding.stream = load("res://audio/ding.wav")
	_ding.bus = AudioSettings.SOUNDS_BUS
	add_child(_ding)
	hud.enter_pressed.connect(_enter_door)
	dialog = DialogBox.new()
	hud.get_node("Root").add_child(dialog)
	dialog.closed.connect(_end_talk)
	hud.town_requested.connect(func() -> void: enter_town(_came_from))
	hud.like_pressed.connect(_on_like_pressed)
	hud.main_menu.replay_requested.connect(_play_replay)
	hud.main_menu.closed.connect(_leave_building)
	hud.play_requested.connect(_play_again)
	hud.main_level_requested.connect(play_main_level)
	hud.random_level_requested.connect(play_random_level)
	hud.floor_requested.connect(start_floor)
	hud.rematch_requested.connect(start_rematch)
	hud.pause_menu.save_quit_pressed.connect(_save_and_quit)
	hud.main_menu.resume_run_pressed.connect(_resume_run)
	hud.main_menu.end_run_pressed.connect(enter_town)
	hud.areas_needed.connect(_update_gate)
	hud.pause_requested.connect(pause)
	hud.card_pressed.connect(func(i: int) -> void:
		pause()
		if get_tree().paused:
			hud.pause_menu.open_card(i))
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
	hud.main_menu.play_pressed.connect(enter_town)
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
	music.volume_db = -12.0
	music.name = "Music"
	add_child(music)
	set_music("music")


## Switch tracks: "music" (town), "music_level" (practice and dungeon levels) or
## "music_saved" (saved levels in the Replay Room). Starts the new one from the top.
func set_music(track: String) -> void:
	var music: AudioStreamPlayer = get_node_or_null("Music")
	if music == null or _music_track == track:
		return
	_music_track = track
	var stream: AudioStreamOggVorbis = load("res://audio/%s.ogg" % track)
	stream.loop = true
	music.stream = stream
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
	if _level_key.begins_with("boss_"):
		z = minf(z, visible.x / level.get_bounds().size.x)   # boss rooms: always see the whole arena
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
	_leave_floor()
	_came_from = "dungeon"
	seed_value = 0
	_level_key = "main"
	_replay_mode = ""
	set_music("music_level")
	hud.set_seed(0)
	load_level_text(FileAccess.get_file_as_string(level.map_file))


## A random level from a seed; a seed below 1 picks a new one.
## mode: "" (a dungeon level), or a Replay Room mode: "true", "hard" or "scramble".
func play_random_level(s: int, mode := "") -> void:
	if s <= 0 and _floor != "" and state == State.WON:
		_next_floor_level()   # the win menu's "Next level" button
		return
	_leave_floor()
	_came_from = "replay" if mode != "" else "dungeon"
	seed_value = s if s > 0 else LevelGen.random_seed()
	_level_key = "seed%d" % seed_value
	_replay_mode = mode
	set_music("music_saved" if mode != "" else "music_level")
	hud.set_seed(seed_value)
	var text := LevelGen.generate(seed_value)
	if mode == "hard":
		text = LevelRemix.hard(text, seed_value)
	elif mode == "scramble":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		text = LevelRemix.scramble(text, rng)
	load_level_text(text)
	if mode == "hard":
		hud.banner("Hard Replay!")
	elif mode == "scramble":
		hud.banner("Scramble Replay: find the goal!")
	elif LevelGen.is_vertical(seed_value):
		hud.banner("Climb to the top!")
	elif LevelGen.is_diagonal(seed_value):
		hud.banner("Climb up and across!")


## Square Hub Town: walk around and go into its buildings. Coming back from the dungeon puts
## you at its gate.
func enter_town(at_door := "") -> void:
	_leave_floor()
	state = State.TOWN
	seed_value = 0
	_level_key = "town"
	set_music("music")
	_replay_mode = ""
	_near_door = ""
	hud.set_seed(0)
	var town := FileAccess.get_file_as_string(TOWN_MAP)
	if not CardCollection.replay_unlocked():
		town = town.replace("%", ".").replace("^", ".")   # the Replay Room and its ledge
	# Milestones: Paul (5 levels), then rubber up to him and Terry (10 levels).
	if not CardCollection.milestone(5):
		town = town.replace("(", ".")
	town = town.replace("r", "R" if CardCollection.milestone(10) else "#")
	if not CardCollection.milestone(10):
		town = town.replace(")", ".")
	# Area milestones: the first time you play an area, a little of it shows up in town.
	if "moss" not in CardCollection.areas_played:
		town = town.replace("o", ".")   # mossy blocks by the pond
	if not CardCollection.larry_here():
		town = town.replace("f", ".").replace("l", ".")   # Larry's hut: your 3rd Shop card
	# Romeo sits on the right hill, then the left, switching every 2 levels you complete.
	town = town.replace("[" if CardCollection.clears / 2 % 2 == 0 else "]", ".")
	_larry_shown = CardCollection.larry_here()
	level.load_map_text(town)
	for d in level.get_doors():
		if d.kind == "paul":
			d.closed = not CardCollection.milestone(10)   # his shutter stays down until 10 levels
	_sync_chests()
	_fit_to_level()
	get_tree().paused = false
	hud.tuning_panel.hide()
	var spot := level.start.position
	for d in level.get_doors():
		if d.kind == at_door:
			spot = d.position + Vector2(0, -12)
	player.reset_to(spot)
	_unstick.call_deferred()
	player.active = true
	player.abilities.assign(CardCollection.equipped)
	hearts = _start_hearts()
	_show_abilities()
	hud.set_pixels(CardCollection.pixels)
	hud.hide_menus()
	hud.set_town_mode(true)
	hud.pause_menu.set_quit_text("Main Menu")
	$TouchControls.show()
	hud.pause_button.show()
	if at_door == "":
		hud.banner("Square Hub Town")
	for a in CardCollection.claim_milestones():
		hud.toast("Rare card: %s! Added to your collection." % AbilityCard.NAMES[a])


func _on_door_near(kind: String, near: bool) -> void:
	if near:
		_near_door = kind
	elif _near_door == kind:
		_near_door = ""
	hud.show_enter(TownDoor.NAMES[_near_door] if _near_door != "" and state == State.TOWN else "",
		"Talk to" if _near_door in TownDoor.PEOPLE else "Enter")


## Go into the building you're standing at.
func _enter_door() -> void:
	if state != State.TOWN or _near_door == "" or get_tree().paused:
		return
	if _near_door in TOWNSFOLK_LINES:
		var n: int = _talks.get(_near_door, 0)
		_talks[_near_door] = n + 1
		_talk(_near_door, TOWNSFOLK_LINES[_near_door] if _near_door == "larry" \
			else [TOWNSFOLK_LINES[_near_door][n % TOWNSFOLK_LINES[_near_door].size()]])
		return
	if _near_door == "terry":
		_talk("terry", [TERRY_LINES[randi() % TERRY_LINES.size()]])
		return
	if _near_door == "paul" and not CardCollection.milestone(10):
		_talk("paul", ["Still unpacking. Please come back later!"])
		return
	state = State.MENU
	player.active = false
	player.velocity = Vector2.ZERO
	$TouchControls.hide()
	hud.pause_button.hide()
	hud.show_enter("")
	match _near_door:
		"dungeon": hud.show_start()
		"shop": hud.main_menu.open_page("Shop")
		"cards": hud.main_menu.open_page("Cards")
		"replay": hud.main_menu.open_page("Replay")
		"paul": hud.main_menu.open_page("Paul")


## Back out of a shop or card hall visit.
func _leave_building() -> void:
	if state != State.MENU:
		return
	if CardCollection.larry_here() and not _larry_shown:
		# Your 3rd Shop card: Larry has set up his fishing hut by the pond.
		enter_town(_near_door)
		hud.toast("Someone's set up a fishing hut by the pond!")
		return
	state = State.TOWN
	player.active = true
	player.abilities.assign(CardCollection.equipped)   # equips may have changed
	_show_abilities()
	hud.set_pixels(CardCollection.pixels)
	$TouchControls.show()
	hud.pause_button.show()
	hud.show_enter(TownDoor.NAMES[_near_door] if _near_door != "" else "",
		"Talk to" if _near_door in TownDoor.PEOPLE else "Enter")


func new_run() -> void:
	hud.set_town_mode(false)
	hud.pause_menu.set_quit_text("Back to Town")
	player.reset_to(level.start.position)
	_respawn = level.start.position
	_bubble_used = false
	player.guard_up = true
	player.bark_up = true   # Bark Hide grows back for every level
	player.active = true
	run_time = 0.0
	falls = 0
	hits = 0
	player.abilities.assign(CardCollection.equipped)   # equipped from the collection
	hearts = _carry_hearts if _carry_hearts > 0 else _start_hearts()
	_show_abilities()
	hud.set_hearts(hearts, maxi(hearts, _start_hearts()))
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


## Pause the game and open the dialogue box: [param who] says each of [param pages] in turn.
func _talk(who: String, pages: Array) -> void:
	get_tree().paused = true
	hud.pause_button.hide()
	hud.tune_button.hide()
	hud.show_enter("")
	$TouchControls.hide()
	dialog.say(who, pages)


func _end_talk() -> void:
	get_tree().paused = false
	hud.pause_button.show()
	hud.tune_button.show()
	$TouchControls.show()
	hud.show_enter(TownDoor.NAMES[_near_door] if _near_door != "" else "",
		"Talk to" if _near_door in TownDoor.PEOPLE else "Enter")
	get_viewport().gui_release_focus()


## Safety net: if the player ever lands inside the ground (back from a level), lift them out.
func _unstick() -> void:
	await get_tree().physics_frame
	for i in 16:
		if not player.test_move(player.global_transform, Vector2.ZERO):
			return
		player.position.y -= 8.0
	player.reset_to(level.start.position)


## Pause the game and open the pause menu (Pause button, Esc or P).
func pause() -> void:
	if state not in [State.PLAY, State.TOWN] or get_tree().paused:
		return
	get_tree().paused = true
	hud.pause_button.hide()
	hud.tune_button.hide()
	$TouchControls.hide()
	for b in get_tree().get_nodes_in_group("hud_banner"):
		b.queue_free()   # banners would draw over the menu
	hud.pause_menu.set_town(state == State.TOWN)
	hud.pause_menu.set_cards(player.abilities, player.color)
	hud.pause_menu.open()
	hud.pause_menu.set_save_quit(state == State.PLAY and _floor != "")


func resume() -> void:
	hud.pause_menu.hide()
	get_tree().paused = false
	if state == State.TOWN:
		player.abilities.assign(CardCollection.equipped)   # in town, equips can change from Pause > Cards
		_show_abilities()
	hud.pause_button.show()
	hud.tune_button.show()
	$TouchControls.show()
	get_viewport().gui_release_focus()


## Pause menu's quit: from the dungeon back to town, from town to the main menu.
func go_to_start() -> void:
	resume()
	if state != State.TOWN:
		enter_town(_came_from)
		return
	state = State.READY
	player.active = false
	player.reset_to(level.start.position)
	hud.pause_button.hide()
	hud.show_enter("")
	hud.show_main_menu(player.color)
	$TouchControls.hide()   # touch controls only while playing, so menus get the whole screen


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in [State.PLAY, State.TOWN] and not get_tree().paused:
		pause()
	elif event.is_action_pressed("restart") and state in [State.PLAY, State.WON, State.OUT] \
			and not get_tree().paused:
		new_run()
	elif state == State.TOWN and (event.is_action_pressed("ui_up")
			or (event is InputEventKey and event.pressed and event.keycode == KEY_E)):
		_enter_door()


func _process(delta: float) -> void:
	if state == State.PLAY:
		run_time += delta
	hud.set_stats(run_time, falls)
	$TouchControls.set_ready("angry", player.angry_ready() and (hearts > 1 or state != State.PLAY))
	$TouchControls.set_ready("push", player.push_ready())


## Angry Block Dash costs a heart, but never your last one (and only in a level).
func _pay_angry_heart() -> bool:
	if state != State.PLAY:
		return state == State.TOWN   # free to try out in town
	if hearts <= 1:
		hud.toast("Too angry to risk your last heart!")
		return false
	hearts -= 1
	hud.set_hearts(hearts, _start_hearts())
	hud.hearts_display.flash()
	Haptics.hurt()
	return true


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
	if state == State.PLAY and "safety_bubble" in player.abilities and not _bubble_used:
		_bubble_used = true   # Safety Bubble: caught once per level (refills at the checkpoint)
		player.bubble_to(player.last_ground)
		hud.toast("Safety Bubble!")
		return
	falls += 1
	# Spiked platforms smashed by Angry Block Dash come back, so no bridge is lost for good.
	for t in get_tree().get_nodes_in_group("card_targets"):
		if t is SpikePlatform and t.get_meta("smashed", false):
			t.reset()
	if state != State.PLAY:
		player.reset_to(level.start.position)
		return
	player.reset_to(_respawn)
	_lose_heart(true)


## A checkpoint: falls send you back here for the rest of this run.
func _on_checkpoint(spot: Vector2) -> void:
	if state != State.PLAY:
		return
	_respawn = spot
	_bubble_used = false
	player.guard_up = true
	_ding.play()
	hud.toast("Checkpoint!")


## Touched a spike: lose a heart and get knocked away, unless still blinking from the last hit.
func _on_player_hurt(push: Vector2) -> void:
	if state != State.PLAY or player.is_safe():
		return
	if player.try_guard(push):
		hud.toast("Guard Block!")
		return   # Guard Block: the shield took it
	if player.try_bark(push):
		hud.toast("Bark Hide broke!")
		return   # Bark Hide: the bark took it
	if player.try_shrug_off(push):
		return   # Lucky Charm: shrugged it off
	hits += 1
	player.knock_back(push)
	player.slow_burst()
	_lose_heart()


## Hearts at the start of a run: 2, plus 1 for the Heart Box card.
func _start_hearts() -> int:
	return START_HEARTS + (1 if "heart_box" in player.abilities else 0)


func _lose_heart(from_fall := false) -> void:
	hearts -= 1
	if hearts <= 0:
		Haptics.lose()
	elif from_fall:
		Haptics.fall()
	else:
		Haptics.hurt()
	hud.set_hearts(hearts, _start_hearts())
	hud.hearts_display.flash()
	if hearts <= 0:
		state = State.OUT
		hud.pause_button.hide()
		player.active = false
		player.velocity = Vector2.ZERO
		hud.show_out(run_time, falls)
		if _floor != "":
			var ar := _area(_floor)
			var where := "the boss" if _floor_step > int(ar.levels) else "Level %d" % (ar.first + _floor_step - 1)
			hud.out_label.text = "Out of hearts on %s. Start again from Level %d?" % [where, ar.first]
			if _rematch:
				hud.out_label.text = "Out of hearts. Try the rematch again?"
		$TouchControls.hide()


func _on_heart_collected() -> void:
	hearts = mini(hearts + 1, _start_hearts())
	hud.set_hearts(hearts, _start_hearts())


## Chests this save file already opened stay open (and empty).
func _sync_chests() -> void:
	var chests := level.get_chests()
	for i in chests.size():
		chests[i].set_open(_level_key != "custom" and CardCollection.chest_opened("%s:%d" % [_pickup_key(), i]))
	var pixels := level.get_pixels()
	for i in pixels.size():
		pixels[i].set_taken(_level_key != "custom" and CardCollection.chest_opened("%s:px%d" % [_pickup_key(), i]))


## A floating pixel: +1, remembered like chests so replaying a level doesn't pay out again.
func _on_pixel_collected(index: int) -> void:
	if _level_key != "custom":
		CardCollection.mark_chest("%s:px%d" % [_pickup_key(), index])
	CardCollection.add_pixels(1)
	hud.set_pixels(CardCollection.pixels)


## A chest holds a card 20% of the time (from the Chest Only cards; none yet), otherwise
## 2–10 pixels. A card this file already
## owns turns into DUPLICATE_PIXELS instead.
func _on_chest_opened(index: int) -> void:
	if _level_key != "custom":
		CardCollection.mark_chest("%s:%d" % [_pickup_key(), index])
	var chest_cards := CardCollection.pool("chest")
	var card: String = chest_cards.pick_random() if randf() < 0.2 and not chest_cards.is_empty() else ""
	if card != "":
		_on_card_collected(card)
	else:
		var n := randi_range(2, 10)
		CardCollection.add_pixels(n)
		hud.set_pixels(CardCollection.pixels)
		hud.toast("Chest: +%d pixels!" % n)


## Broken spike squares drop a card 8% of the time, otherwise 1–2 pixels. Squashed Bad Blocks
## drop a card 10% of the time, otherwise 1 pixel. Cards come from the Drop pool, ones this
## file doesn't own yet.
func _on_obstacle_broken(pos: Vector2, kind: String) -> void:
	var chance := 0.1 if kind in ["bad_block", "moss_square"] else 0.08
	# A Moss Covered Square drops this area's cards (drop group "moss"); the rest use the Drop pool.
	var left := CardCollection.pool("moss" if kind == "moss_square" else "drop").filter(func(a: String) -> bool: return not CardCollection.owned.has(a))
	if randf() < chance and not left.is_empty():
		_on_card_collected(left.pick_random())
		return
	var n := 1 if kind in ["bad_block", "moss_square"] else randi_range(1, 2)
	CardCollection.add_pixels(n)
	hud.set_pixels(CardCollection.pixels)
	CardFx.spawn(level, pos, "plus", 0.0, "+%d" % n)


## A card you already own turns into this many pixels.
const DUPLICATE_PIXELS := 2


func _on_card_collected(ability: String) -> void:
	# Found cards join the collection for good. A new one is equipped now if a slot is free.
	if CardCollection.add(ability):
		var card_name: String = AbilityCard.NAMES[ability]
		if CardCollection.is_equipped(ability):
			player.abilities.assign(CardCollection.equipped)
			hud.toast("New card: %s! Equipped." % card_name)
		else:
			hud.toast("New card: %s! Added to your collection." % card_name)
	elif _level_key != "custom" and not CardCollection.is_beaten(_level_key):
		CardCollection.add_pixels(DUPLICATE_PIXELS)
		hud.set_pixels(CardCollection.pixels)
		hud.toast("Duplicate %s: +%d pixels" % [AbilityCard.NAMES[ability], DUPLICATE_PIXELS])
	_show_abilities()


## Win screen's Like button: save this level to the Replay Room (or take it out).
func _on_like_pressed() -> void:
	if not CardCollection.toggle_like(seed_value):
		hud.toast("Replay Room is full (%d levels)" % CardCollection.room_size())
	hud.set_like(true, seed_value in CardCollection.liked)


## Replay Room: play a liked level again (Hard and Scramble pay once each; see win_reward).
func _play_replay(s: int, mode: String) -> void:
	hud.main_menu.hide()
	play_random_level(s, mode)


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
	var clear_key := _replay_clear_key()
	if clear_key != "" and not CardCollection.is_beaten(clear_key):
		var before := CardCollection.room_size()
		CardCollection.mark_beaten(clear_key)
		if CardCollection.room_size() > before:
			hud.toast("The Replay Room grew: room for %d levels!" % CardCollection.room_size())
	var levels_before := CardCollection.levels_beaten()
	if _level_key != "custom":
		CardCollection.mark_beaten(_level_key)
	_announce_milestones(levels_before, CardCollection.levels_beaten())
	if reward > 0:
		CardCollection.record_win()
		CardCollection.add_pixels(reward)
		hud.set_pixels(CardCollection.pixels)
	hud.show_win(run_time, falls, hearts, seed_value, reward)
	hud.set_like(seed_value > 0 and CardCollection.replay_unlocked(), seed_value in CardCollection.liked)
	if _floor != "":
		_floor_level_won()
	$TouchControls.hide()


## --- Floor runs ---------------------------------------------------------------------------

static func _area(id: String) -> Dictionary:
	for ar in AREAS:
		if ar.id == id:
			return ar
	return {}


static func area_unlocked(i: int) -> bool:
	return i == 0 or CardCollection.is_beaten("boss:" + AREAS[i - 1].id)


## Fill the dungeon gate with the areas you can play, and how far you've got in each.
func _update_gate() -> void:
	var rows := []
	for i in AREAS.size():
		if not area_unlocked(i):
			break
		var ar: Dictionary = AREAS[i]
		var marks := []
		for k in ar.levels:
			var n: int = ar.first + k
			marks.append(("✓" if CardCollection.is_beaten(_area_key(ar.id, k + 1)) else "") + str(n))
		marks.append(("✓" if CardCollection.is_beaten("boss:" + ar.id) else "") + "Boss")
		rows.append({"id": ar.id, "title": "Levels %d–%d: %s" % [ar.first, ar.first + 4, ar.name],
			"progress": "  ".join(marks), "rematch": ar.has("boss") and boss_wins(ar.id) >= 2})
	hud.set_areas(rows)


## The save key for an area's level slot (its 1st to 5th level). The layouts are random every
## run, so wins and first-win rewards are counted per slot, not per layout.
static func _area_key(id: String, step: int) -> String:
	return "%s:L%d" % [id, step]


## Pixels and chests picked up in a dungeon run are remembered under "run:" keys, which are
## wiped when a new run starts: every run's fresh levels have all their pickups.
func _pickup_key() -> String:
	return "run:" + _level_key if _floor != "" and not _level_key.begins_with("boss_") else _level_key


## Five fresh random levels for a run through an area.
func _roll_floor_seeds(id: String) -> void:
	_floor_seeds.clear()
	var extra: int = _area(id).get("extra", 0)
	var lengths := {}
	while _floor_seeds.size() < int(_area(id).levels):
		var s := LevelGen.random_seed()
		var w := LevelGen.generate(s, extra).find("\n")
		if s not in _floor_seeds and w <= MAX_LEVEL_TILES:
			_floor_seeds.append(s)
			lengths[s] = w
	# Shorter levels first, so the run builds up toward the boss.
	_floor_seeds.sort_custom(func(a: int, b: int) -> bool: return lengths[a] < lengths[b])
	CardCollection.opened_chests = CardCollection.opened_chests.filter(
		func(k: String) -> bool: return not k.begins_with("run:"))


## Times this area's boss was beaten the normal way. Files that beat him before wins were
## counted have at least 1.
static func boss_wins(id: String) -> int:
	var n: int = CardCollection.boss_wins.get(id, 0)
	return maxi(n, 1 if CardCollection.is_beaten("boss:" + id) else 0)


## Rematch (after 2 normal wins): straight into the boss room with fresh hearts. No rewards.
func start_rematch(id: String) -> void:
	start_floor(id, int(_area(id).levels) + 1)
	_rematch = true
	hud.banner("Rematch: %s!" % _area(id).boss_name, 5.0, 1.0)


func start_floor(id: String, step := 1) -> void:
	_rematch = false
	_floor = id
	_floor_step = step
	_carry_hearts = -1
	_roll_floor_seeds(id)
	_play_floor_level()


func _leave_floor() -> void:
	if _level_key.begins_with("boss_"):
		_level_key = ""
		_on_screen_changed()   # back to the normal zoom
	_floor = ""
	_rematch = false
	_carry_hearts = -1
	level.set_theme("")
	$Background/Sky.modulate = Color.WHITE


func _play_floor_level() -> void:
	var id := _floor
	var step := _floor_step
	var carry := _carry_hearts
	_came_from = "dungeon"
	seed_value = _floor_seeds[step - 1] if step <= _floor_seeds.size() else 0
	_level_key = _area_key(id, step)
	_replay_mode = ""
	set_music("music_level")
	var ar := _area(id)
	if id not in CardCollection.areas_played:
		CardCollection.areas_played.append(id)   # town milestone: see enter_town
		CardCollection.save()
	if step > int(ar.levels):
		_play_boss(ar, carry)
		return
	hud.set_seed(seed_value)
	var text := LevelGen.generate(seed_value, ar.get("extra", 0))   # Basic levels run 10-15 tiles longer
	text = _harden(text, step, seed_value)
	if id == "moss":
		text = _mossify(_add_moss_obstacles(text, seed_value), seed_value).replace("`", "=")
		level.set_theme("moss")
		$Background/Sky.modulate = Color(0.55, 0.85, 0.7)
	_floor = id
	_floor_step = step
	_carry_hearts = carry
	load_level_text(text)
	_level_hearts = hearts
	hud.banner("Level %d  ·  %s" % [ar.first + step - 1, ar.name])


## The area's boss room, after its 5 levels. Hearts carry in.
func _play_boss(ar: Dictionary, carry: int) -> void:
	seed_value = 0
	_level_key = "boss_" + ar.id
	hud.set_seed(0)
	_floor = ar.id
	_floor_step = int(ar.levels) + 1
	_carry_hearts = carry
	set_music("music_boss")
	var rematch := _rematch
	level.set_theme("moss" if ar.id == "moss" else "")
	$Background/Sky.modulate = Color(0.55, 0.85, 0.7) if ar.id == "moss" else Color.WHITE
	load_level_text(FileAccess.get_file_as_string(ar.boss))
	_rematch = rematch
	_level_hearts = hearts
	_on_screen_changed()
	hud.banner("Boss: %s!" % ar.boss_name, 5.0, 1.0)


## The boss is down: the exit cube appears by the door on his side. Touching it wins (and
## pays the boss rewards).
func _on_boss_defeated() -> void:
	if state != State.PLAY:
		return
	Haptics.hurt()
	level.open_boss_exit()
	hud.banner("The exit is open!", 5.0, 1.0)


## Mossy Cave: most floating platforms become crumbling blocks.
## Levels get a little harder nearer the boss: later levels gain 1-2 more Bad Blocks on flat
## ground, and the last one's first Bad Block is a Hard one (faster, horned).
func _harden(text: String, step: int, s: int) -> String:
	var n: int = EXTRA_BAD_BLOCKS[clampi(step - 1, 0, EXTRA_BAD_BLOCKS.size() - 1)]
	if n == 0:
		return text
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 17 + step
	var g: Array = []
	for line in text.split("\n"):
		g.append(line.split(""))
	var spots: Array[Vector2i] = []
	var busy: Array[Vector2i] = []
	for y in g.size():
		for x in g[y].size():
			if g[y][x] not in [".", "#", "=", "*"]:
				busy.append(Vector2i(x, y))
	for y in range(2, g.size() - 1):
		for x in range(3, mini(g[y].size(), g[y + 1].size()) - 3):
			var ok := true
			for dx in range(-2, 3):
				if g[y][x + dx] != "." or g[y + 1][x + dx] not in ["#", "="]:
					ok = false
			if not ok:
				continue
			for b in busy:   # clear of the start, goal, pads, checkpoint and other obstacles
				if absi(b.x - x) < (10 if g[b.y][b.x] == "P" else 5) and absi(b.y - y) < 5:
					ok = false
					break
			if ok:
				spots.append(Vector2i(x, y))
	for i in n:
		if spots.is_empty():
			break
		var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		g[c.y][c.x] = "e"
		spots = spots.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 6 or absi(o.y - c.y) >= 5)
	var out := PackedStringArray()
	for row in g:
		out.append("".join(row))
	var res := "\n".join(out)
	if step >= EXTRA_BAD_BLOCKS.size():
		var k := res.find("e")
		if k != -1:
			res = res.substr(0, k) + "k" + res.substr(k + 1)
	return res


## Mossy Cave: every map also gets 1-2 Moss Covered Squares (q, on flat ground) and 1-2 Vine
## Platforms (v, floating over flat ground with room for their vines), away from start and goal.
func _add_moss_obstacles(text: String, s: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 53 + 11
	var g: Array = []
	for line in text.split("\n"):
		g.append(line.split(""))
	var at := func(x: int, y: int) -> String:
		return g[y][x] if y >= 0 and y < g.size() and x >= 0 and x < g[y].size() else "?"
	var keep_away: Array[Vector2i] = []
	for y in g.size():
		for x in g[y].size():
			if g[y][x] in ["P", "G", "@", "1", "2", "3"]:
				keep_away.append(Vector2i(x, y))
	var far := func(x: int, y: int) -> bool:
		for k in keep_away:
			if absi(k.x - x) < (10 if g[k.y][k.x] == "P" else 6) and absi(k.y - y) < 6:
				return false
		return true
	var squares: Array[Vector2i] = []
	var vines: Array[Vector2i] = []
	# Strict rules first (5 flat tiles for a square; 7 free rows for vines); tight maps such as
	# the climbs fall back to looser ones (3 flat tiles; 3 free rows) so every map gets some.
	for loose in [false, true]:
		for y in range(2, g.size() - 1):
			for x in range(3, g[y].size() - 3):
				if not far.call(x, y):
					continue
				if squares.is_empty() or not loose:
					var flat := true
					for dx in (range(-1, 2) if loose else range(-2, 3)):
						if at.call(x + dx, y) != "." or at.call(x + dx, y + 1) not in ["#", "="]:
							flat = false
					if flat and not (loose and Vector2i(x, y) in squares):
						squares.append(Vector2i(x, y))
				if vines.is_empty() or not loose:
					var room := true
					for dx in range(-1, 2):
						for dy in (range(-1, 2) if loose else range(-2, 5)):
							if at.call(x + dx, y + dy) != ".":
								room = false
						if not loose and at.call(x + dx, y + 5) not in ["#", "="] \
								and at.call(x + dx, y + 6) not in ["#", "="]:
							room = false
					if room:
						vines.append(Vector2i(x, y))
		if not squares.is_empty() and not vines.is_empty():
			break
	for pair in [[squares, "q"], [vines, "v"]]:
		var spots: Array = pair[0]
		for i in rng.randi_range(1, 2):
			if spots.is_empty():
				break
			var c: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
			g[c.y][c.x] = pair[1]
			if pair[1] == "q":
				for dx in range(-3, 4):   # its floor never crumbles (see _mossify)
					if at.call(c.x + dx, c.y + 1) == "=":
						g[c.y + 1][c.x + dx] = "`"
			keep_away.append(c)
			spots = spots.filter(func(o: Vector2i) -> bool: return absi(o.x - c.x) >= 6 or absi(o.y - c.y) >= 6)
	var out := PackedStringArray()
	for row in g:
		out.append("".join(row))
	return "\n".join(out)


func _mossify(text: String, s: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + 7
	var out := ""
	for ch in text:
		out += "c" if ch == "=" and rng.randf() < 0.6 else ch
	return out


func _floor_level_won() -> void:
	var ar := _area(_floor)
	var total: int = int(ar.levels)
	if _floor_step < total:
		hud.set_floor_win("Next: Level %d" % (ar.first + _floor_step))
		return
	if _floor_step == total and ar.has("boss"):
		hud.set_floor_win("Next: Boss!")
		return
	# The boss is beaten (areas without a boss yet: clearing level 5 stands in for it).
	var key: String = "boss:" + _floor
	if _rematch:
		hud.banner("Rematch won!", 5.0, 1.0)
		hud.set_floor_win("")
		return
	if ar.has("boss"):
		var wins := boss_wins(_floor) + 1
		CardCollection.boss_wins[_floor] = wins
		CardCollection.save()
		if wins >= 2 and CardCollection.is_beaten(key):
			# The second win: every card he gives is yours now.
			var got := []
			for c in [AREA_CARDS.get(ar.id, ""), BOSS_CARDS.get(ar.id, "")]:
				if c != "" and not CardCollection.owns(c):
					_on_card_collected(c)
					got.append(AbilityCard.NAMES[c])
			var news := "%s beaten again!" % ar.boss_name
			if not got.is_empty():
				news += " You got " + " and ".join(got) + "."
			if wins == 2:
				news += " Rematch unlocked at the gate."
			hud.result_label.text += "\n" + news
			hud.banner(news, 5.0, 1.0)
	if not CardCollection.is_beaten(key):
		CardCollection.mark_beaten(key)
		var px := FLOOR_CLEAR_REWARD
		var news := "%s cleared!" % ar.name
		if ar.has("boss"):
			px += BOSS_REWARD
			news = "%s beaten!" % ar.boss_name
			var card: String = AREA_CARDS.get(ar.id, "")
			if card == "" or CardCollection.owns(card):
				card = BOSS_CARDS.get(ar.id, "")
			if card != "" and not CardCollection.owns(card):
				_on_card_collected(card)
		CardCollection.add_pixels(px)
		hud.set_pixels(CardCollection.pixels)
		news += " +%d pixels" % px
		var i := AREAS.find(ar)
		if i + 1 < AREAS.size():
			news += ". %s is open!" % AREAS[i + 1].name
		hud.result_label.text += "\n" + news
		hud.banner(news)
	elif not ar.has("boss"):
		hud.banner("The boss's lair is still being dug...")
	hud.set_floor_win("")


## Pause menu's Save and Quit: remember this run from the start of the current level, then go
## back to the title. Picking the save file again offers to resume it.
func _save_and_quit() -> void:
	var ar := _area(_floor)
	var where := "the %s boss" % ar.name if _floor_step > int(ar.levels) \
		else "Level %d (%s)" % [ar.first + _floor_step - 1, ar.name]
	if _rematch:
		where = "a rematch with %s" % ar.boss_name
	CardCollection.run = {"area": _floor, "step": _floor_step, "hearts": _level_hearts,
		"rematch": _rematch, "where": where, "seeds": _floor_seeds.duplicate()}
	CardCollection.save()
	enter_town("dungeon")
	go_to_start()


## Resume the saved run at the start of the level it stopped on.
func _resume_run() -> void:
	var r := CardCollection.run
	CardCollection.run = {}
	CardCollection.save()
	if _area(r.get("area", "")).is_empty():
		enter_town()
		return
	if r.get("rematch", false):
		start_rematch(r.area)
		return
	_floor = r.area
	_floor_step = int(r.step)
	_floor_seeds.assign(r.get("seeds", []))
	if _floor_seeds.size() != int(_area(r.area).levels):
		_roll_floor_seeds(r.area)   # an older save without its levels
	_rematch = false
	_carry_hearts = int(r.hearts) if _floor_step > 1 and int(r.hearts) > 0 else -1
	_play_floor_level()


func _next_floor_level() -> void:
	_carry_hearts = hearts
	_floor_step += 1
	_play_floor_level()


## Play again / Try again. Out of hearts in a floor starts the floor over from level 1.
func _play_again() -> void:
	if _floor != "" and state == State.OUT:
		if _rematch:
			start_rematch(_floor)
		else:
			start_floor(_floor)
		return
	new_run()


## Winning pays 3 pixels, or 4 for a fast run, the first time only: replays and editor
## test levels pay nothing, so a level can't be farmed. Hard and Scramble replays pay 3 pixels
## and add a Replay Room space, the first time each is cleared on a level (once only).
func win_reward() -> int:
	var clear_key := _replay_clear_key()
	if clear_key != "":
		return 0 if CardCollection.is_beaten(clear_key) else REPLAY_REWARD
	if _level_key == "custom" or _level_key.begins_with("boss_") or CardCollection.is_beaten(_level_key):
		return 0   # bosses pay through _floor_level_won
	return FAST_REWARD if run_time <= par_time() else WIN_REWARD


const MILESTONE_NEWS := {
	5: "5 levels beaten! Someone pink moved onto the floating platform in town...",
	10: "10 levels beaten! Rubber blocks popped up in town, and a sleepy neighbor moved in.",
	15: "15 levels beaten! A rare attack card is waiting for you in town.",
	20: "20 levels beaten! A rare card showed up in the Shop.",
}


func _announce_milestones(before: int, after: int) -> void:
	for m in CardCollection.MILESTONES:
		if before < m and after >= m:
			hud.toast(MILESTONE_NEWS[m])


## The save key for a Hard or Scramble replay's first clear ("hard:seed7"), or "" for other levels.
func _replay_clear_key() -> String:
	return "%s:%s" % [_replay_mode, _level_key] if _replay_mode in ["hard", "scramble"] else ""


## A fast run: start to goal in under 1.5× the time it takes to just run that distance
## (across plus up, so climbing levels count their height).
func par_time() -> float:
	var d := (level.goal.position - level.start.position).abs()
	return (d.x + d.y) / player.run_speed * PAR_SLACK


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
		_leave_floor()
		_level_key = "custom"
		set_music("music_level")
		_replay_mode = ""
		load_level_text(str(args[0]))


## Every menu button gives a small tap buzz (on-screen move/jump keys are left out).
func _hook_button_haptics(n: Node) -> void:
	if not n is BaseButton or (has_node("TouchControls") and $TouchControls.is_ancestor_of(n)):
		return
	if not n.pressed.is_connected(Haptics.tap):
		n.pressed.connect(Haptics.tap)
