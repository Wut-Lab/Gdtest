extends SceneTree
# Auto-runner bot: hold right; jump at walls and at ledges. Reports the route and the result.
var main
var frame := 0
var hold := 0
var last_jump_x := -999.0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.new_run(); Input.action_press("move_right")
	if frame < 5: return false
	var p = main.player
	var ground: TileMapLayer = main.level.ground
	if p.is_on_floor() and hold == 0:
		var front: float = p.position.x + 12.0 + 4.0
		var col: int = int(floor(front / 32.0))
		var feet_row: int = int(floor((p.position.y + 11.0) / 32.0))
		var wall: bool = ground.get_cell_source_id(Vector2i(col, feet_row)) != -1
		var gap := true
		for dy in range(1, 4):
			if ground.get_cell_source_id(Vector2i(col, feet_row + dy)) != -1: gap = false
		if wall or gap:
			Input.action_press("jump"); hold = 32
			print("  jump %s at x=%.0f (col %d) y=%.0f" % ["wall" if wall else "edge", p.position.x, col, p.position.y])
	if hold > 0:
		hold -= 1
		if hold == 0: Input.action_release("jump")
	if main.state == main.State.WON:
		print("RESULT: WON in %.2fs, falls %d" % [main.run_time, main.falls]); quit(0); return true
	if main.falls > 0 or frame > 3000:
		print("RESULT: FAILED falls=%d x=%.0f y=%.0f" % [main.falls, p.position.x, p.position.y]); quit(1); return true
	return false
