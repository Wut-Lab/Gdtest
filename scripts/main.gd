extends Node
## Runs the game: loads the level, spawns the player, and tracks time, falls and winning.

enum State { READY, PLAY, WON }

@export var level_scene: PackedScene
@export var player_scene: PackedScene

var state := State.READY
var run_time := 0.0
var falls := 0
var level: Level
var player: Player

@onready var world: Node2D = $World
@onready var hud: Hud = $HUD


func _ready() -> void:
	level = level_scene.instantiate() as Level
	world.add_child(level)
	player = player_scene.instantiate() as Player
	level.add_child(player)

	# Keep the camera inside the level, and treat falling below it as a fall.
	var b := level.get_bounds()
	player.camera.limit_left = int(b.position.x)
	player.camera.limit_right = int(b.end.x)
	player.camera.limit_top = int(b.position.y)
	player.camera.limit_bottom = int(b.end.y)
	player.fall_limit_y = b.end.y + 80.0

	player.reset_to(level.start.position)
	player.fell.connect(_on_player_fell)
	level.goal_reached.connect(_on_goal_reached)
	hud.play_requested.connect(new_run)
	hud.set_stats(0.0, 0)
	hud.show_start()


func new_run() -> void:
	player.reset_to(level.start.position)
	player.active = true
	run_time = 0.0
	falls = 0
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


func _on_player_fell() -> void:
	falls += 1
	player.reset_to(level.start.position)


func _on_goal_reached() -> void:
	if state != State.PLAY:
		return
	state = State.WON
	player.active = false
	player.velocity = Vector2.ZERO
	hud.show_win(run_time, falls)
