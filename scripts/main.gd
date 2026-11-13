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
	{"id": "basic", "name": "Basic", "first": 1, "seeds": [18, 25, 3, 34, 1]},
	{"id": "moss", "name": "Mossy Cave", "first": 6, "seeds": [29, 56, 49, 10, 8]},
]
const FLOOR_CLEAR_REWARD := 10
var _floor := ""   # the area being played ("" = none)
var _floor_step := 0
var _floor_seeds: Array[int] = []
## Hearts carried into the next level of a floor (-1 = start fresh).
var _carry_hearts := -1
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
	level.add_child(player)
	_fit_to_level()

	player.reset_to(level.start.position)
	player.fell.connect(_on_player_fell)
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


## Pause the game and open the pause menu (Pause button, Esc or P).
func pause() -> void:
	if state not in [State.PLAY, State.TOWN] or get_tree().paused:
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
			hud.out_label.text = "Out of hearts on Level %d. Start again from Level %d?" % [
				ar.first + _floor_step - 1, ar.first]
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
## owns turns into DUPLICATE_PIXELS instead.
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


## Broken spike squares drop a card 8% of the time, otherwise 1–2 pixels. Squashed Bad Blocks
## drop a card 10% of the time, otherwise 1 pixel. Cards come from the Drop pool, ones this
## file doesn't own yet.
func _on_obstacle_broken(pos: Vector2, kind: String) -> void:
	var chance := 0.1 if kind == "bad_block" else 0.08
	var left := CardCollection.pool("drop").filter(func(a: String) -> bool: return not CardCollection.owned.has(a))
	if randf() < chance and not left.is_empty():
		_on_card_collected(left.pick_random())
		return
	var n := 1 if kind == "bad_block" else randi_range(1, 2)
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
		for k in ar.seeds.size():
			var n: int = ar.first + k
			marks.append(("✓" if CardCollection.is_beaten(_area_key(ar.id, ar.seeds[k])) else "") + str(n))
		marks.append(("✓" if CardCollection.is_beaten("boss:" + ar.id) else "") + "Boss")
		rows.append({"id": ar.id, "title": "Levels %d–%d: %s" % [ar.first, ar.first + 4, ar.name],
			"progress": "  ".join(marks)})
	hud.set_areas(rows)


static func _area_key(id: String, s: int) -> String:
	return ("seed%d" if id == "basic" else id + "%d") % s


func start_floor(id: String) -> void:
	_floor = id
	_floor_step = 1
	_carry_hearts = -1
	_floor_seeds.assign(_area(id).seeds)
	_play_floor_level()


func _leave_floor() -> void:
	_floor = ""
	_carry_hearts = -1
	level.set_theme("")
	$Background/Sky.modulate = Color.WHITE


func _play_floor_level() -> void:
	var id := _floor
	var step := _floor_step
	var carry := _carry_hearts
	_came_from = "dungeon"
	seed_value = _floor_seeds[step - 1]
	_level_key = _area_key(id, seed_value)
	_replay_mode = ""
	set_music("music_level")
	hud.set_seed(seed_value)
	var text := LevelGen.generate(seed_value)
	if id == "moss":
		text = _mossify(text, seed_value)
		level.set_theme("moss")
		$Background/Sky.modulate = Color(0.55, 0.85, 0.7)
	_floor = id
	_floor_step = step
	_carry_hearts = carry
	load_level_text(text)
	var ar := _area(id)
	hud.banner("Level %d  ·  %s" % [ar.first + step - 1, ar.name])


## Mossy Cave: most floating platforms become crumbling blocks.
func _mossify(text: String, s: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31 + 7
	var out := ""
	for ch in text:
		out += "c" if ch == "=" and rng.randf() < 0.6 else ch
	return out


func _floor_level_won() -> void:
	var ar := _area(_floor)
	var total: int = ar.seeds.size()
	if _floor_step < total:
		hud.set_floor_win("Next: Level %d" % (ar.first + _floor_step))
		return
	# All 5 levels done. The bosses aren't built yet, so for now this stands in for the boss.
	var key: String = "boss:" + _floor
	if not CardCollection.is_beaten(key):
		CardCollection.mark_beaten(key)
		CardCollection.add_pixels(FLOOR_CLEAR_REWARD)
		hud.set_pixels(CardCollection.pixels)
		var i := AREAS.find(ar)
		var news := "%s cleared! +%d pixels" % [ar.name, FLOOR_CLEAR_REWARD]
		if i + 1 < AREAS.size():
			news += ". %s is open!" % AREAS[i + 1].name
		hud.toast(news)
	hud.banner("The boss's lair is still being dug...")
	hud.set_floor_win("")


func _next_floor_level() -> void:
	_carry_hearts = hearts
	_floor_step += 1
	_play_floor_level()


## Play again / Try again. Out of hearts in a floor starts the floor over from level 1.
func _play_again() -> void:
	if _floor != "" and state == State.OUT:
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
	if _level_key == "custom" or CardCollection.is_beaten(_level_key):
		return 0
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
