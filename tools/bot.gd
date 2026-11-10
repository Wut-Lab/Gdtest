extends SceneTree
# Auto-play test: hold right, jump at walls and real gaps, and jump onto rubber holding jump
# so it boosts. Also records the jump/land animations. Run from the project root:
#   godot --headless --path . --script res://bot.gd

var main
var frame := 0
var hold := 0
var bounces := 0
var puffs := 0
var min_squash_y := 1.0
var max_squash_y := 1.0
var _dust_was_emitting := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _cell(ground: TileMapLayer, c: int, r: int) -> int:
	return ground.get_cell_source_id(Vector2i(c, r))


func _is_rubber(ground: TileMapLayer, c: int, r: int) -> bool:
	return ground.get_cell_atlas_coords(Vector2i(c, r)) == Vector2i(3, 0)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		main.new_run()
		main.player.bounced.connect(func() -> void: bounces += 1)
		Input.action_press("move_right")
	if frame < 5:
		return false
	var p = main.player
	var ground: TileMapLayer = main.level.ground
	var x: float = p.position.x
	var feet_row: int = int(floor((p.position.y + 11.0) / 32.0))

	if p.is_on_floor() and hold == 0:
		var col: int = int(floor((x + 16.0) / 32.0))
		var land_col: int = int(floor((x + 172.0) / 32.0))
		var wall: bool = _cell(ground, col, feet_row) != -1
		var gap := true
		for dy in range(1, 4):
			if _cell(ground, col, feet_row + dy) != -1:
				gap = false
		var on_rubber: bool = _is_rubber(ground, int(floor(x / 32.0)), feet_row + 1)
		var rubber_ahead: bool = _is_rubber(ground, land_col, feet_row + 1)
		if on_rubber or rubber_ahead:
			Input.action_press("jump"); hold = 80
			print("  jump onto rubber at x=%.0f (col %d)" % [x, col])
		elif wall or gap:
			Input.action_press("jump"); hold = 32
			print("  jump %s at x=%.0f (col %d) y=%.0f" % ["wall" if wall else "edge", x, col, p.position.y])
	if hold > 0:
		hold -= 1
		if hold == 0:
			Input.action_release("jump")

	# Animation checks: squash/stretch range and dust puffs.
	var sq: Vector2 = p.get_squash()
	min_squash_y = minf(min_squash_y, sq.y)
	max_squash_y = maxf(max_squash_y, sq.y)
	var emitting: bool = p.dust.emitting
	if emitting and not _dust_was_emitting:
		puffs += 1
	_dust_was_emitting = emitting

	if main.state == main.State.WON:
		print("RESULT: WON in %.2fs, falls %d, rubber bounces %d" % [main.run_time, main.falls, bounces])
		print("ANIM: stretch up to %.2f, squash down to %.2f, dust puffs %d" % [max_squash_y, min_squash_y, puffs])
		quit(0)
		return true
	if main.falls > 0 or frame > 4000:
		print("RESULT: FAILED falls=%d x=%.0f y=%.0f bounces=%d" % [main.falls, x, p.position.y, bounces])
		quit(1)
		return true
	return false
