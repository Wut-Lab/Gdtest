class_name TownDoor
extends Area2D
## A building's door in Square Hub Town: stand in front of it and press Enter (Up key or the
## on-screen button) to go in. ! = the dungeon gate, $ = the shop, & = the card hall,
## % = the Replay Room (a small house, shown once it's unlocked).
## ( = Paul, a pink block with a mini card shop; ) = Terry, a lazy yellow block (milestones).
## { = Paula (purple) and } = Tim (green), who walk back and forth.
## f = a small fishing hut and l = Larry (after your 3rd card from the Shop).
## [ / ] = Romeo (dark red) on the left / right hill: paces a tile each way and hops now and then.
## It sits on the floor of its cell; the building is drawn around it, 3 tiles wide.

signal near_changed(door: TownDoor, near: bool)

const KINDS := {"!": "dungeon", "$": "shop", "&": "cards", "%": "replay", "(": "paul", ")": "terry", "{": "paula", "}": "tim", "[": "romeo", "]": "romeo", "f": "hut", "l": "larry"}
const NAMES := {"dungeon": "the Dungeon", "shop": "the Shop", "cards": "the Card Hall", "replay": "the Replay Room",
	"paul": "Paul", "terry": "Terry", "paula": "Paula", "tim": "Tim", "romeo": "Romeo", "hut": "the Fishing Hut", "larry": "Larry"}
const SIGNS := {"dungeon": "DUNGEON", "shop": "SHOP", "cards": "CARDS", "replay": "REPLAY"}
## Townsfolk: you talk to them instead of entering.
const PEOPLE := ["paul", "terry", "paula", "tim", "romeo", "larry"]
## Scenery only: no door to walk up to.
const DECOR := ["hut"]
## Townsfolk who stroll back and forth (body colour, highlight).
const WALKERS := {"paula": [Color("9b5de5"), Color("c19bf2")], "tim": [Color("3dbb5c"), Color("7fdc95")]}
const WALK_RANGE := 36.0
const EDGE := Color("1b2440")

var kind := "shop"
## Paul's shutter is down (his shop isn't open yet).
var closed := false
var _t := 0.0
var _home := Vector2.ZERO
## Drawn in a dialogue box: no door area, no walking, animates while paused.
var portrait := false
## Romeo: where he's pacing to, how long he waits, and his current hop.
var _goal_x := 0.0
var _wait := 1.0
var _hop_t := -1.0
var _hop_h := 0.0
const HOP_TIME := 0.55


func _ready() -> void:
	_home = position
	_t = randf() * 10.0
	if portrait:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	if kind in DECOR:
		return
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	col.shape = shape
	col.position = Vector2(0, -20)
	add_child(col)
	body_entered.connect(func(b: Node2D) -> void: if b is Player: near_changed.emit(self, true))
	body_exited.connect(func(b: Node2D) -> void: if b is Player: near_changed.emit(self, false))


func _process(delta: float) -> void:
	_t += delta
	if WALKERS.has(kind) and not portrait:
		position.x = _home.x + WALK_RANGE * sin(_t * 0.7)
	elif kind == "romeo" and not portrait:
		_romeo(delta)
	queue_redraw()


func _draw() -> void:
	match kind:
		"dungeon": _draw_dungeon()
		"shop": _draw_shop()
		"cards": _draw_cards()
		"replay": _draw_replay()
		"paul": _draw_paul()
		"terry": _draw_terry()
		"paula", "tim": _draw_walker()
		"romeo": _draw_romeo()
		"hut": _draw_hut()
		"larry": _draw_larry()
	if not SIGNS.has(kind):
		return
	var font := ThemeDB.fallback_font
	var text: String = SIGNS[kind]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(-w / 2.0, -98), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("eef1fa"))


## A stone gatehouse with a dark arch and two flickering torches.
func _draw_dungeon() -> void:
	draw_rect(Rect2(-56, -128, 112, 128), EDGE)
	draw_rect(Rect2(-54, -126, 108, 126), Color("6b7391"))
	for row in 8:
		for i in 4:
			var x := -54.0 + i * 27.0 + (13.0 if row % 2 else 0.0)
			draw_rect(Rect2(x, -126 + row * 16, 1, 16), Color("4a5070"))
		draw_rect(Rect2(-54, -126 + row * 16, 108, 1), Color("4a5070"))
	# Battlements.
	for i in 4:
		draw_rect(Rect2(-56 + i * 32, -140, 18, 14), EDGE)
		draw_rect(Rect2(-54 + i * 32, -138, 14, 12), Color("6b7391"))
	draw_rect(Rect2(-40, -112, 80, 22), Color("2a3150"))
	# Arch.
	draw_rect(Rect2(-22, -64, 44, 64), Color("0b0f1e"))
	draw_rect(Rect2(-16, -72, 32, 8), Color("0b0f1e"))
	for tx in [-38.0, 30.0]:
		draw_rect(Rect2(tx, -52, 8, 14), Color("5a3d22"))
		var f := 0.75 + sin(_t * 9.0 + tx) * 0.25
		draw_rect(Rect2(tx - 1, -62 - 4 * f, 10, 10 * f), Color("ff9a3c"))
		draw_rect(Rect2(tx + 2, -58 - 2 * f, 4, 5 * f), Color("ffe27a"))


## A wooden shop with a striped awning and a pixel in the window.
func _draw_shop() -> void:
	draw_rect(Rect2(-50, -110, 100, 110), EDGE)
	draw_rect(Rect2(-48, -108, 96, 108), Color("9c6b3f"))
	for i in 6:
		draw_rect(Rect2(-48, -100 + i * 18, 96, 1), Color("6e4626"))
	draw_rect(Rect2(-40, -114, 80, 22), Color("2a3150"))
	# Striped awning.
	for i in 6:
		draw_rect(Rect2(-54 + i * 18, -84, 18, 14), Color("e5484d") if i % 2 == 0 else Color("eef1fa"))
	draw_rect(Rect2(-54, -70, 108, 3), EDGE)
	# Window with a big pixel.
	draw_rect(Rect2(14, -56, 28, 26), EDGE)
	draw_rect(Rect2(16, -54, 24, 22), Color("2a3150"))
	PixelCounter.draw_icon(self, Vector2(21, -50 + sin(_t * 2.0) * 1.5), 7.0)
	# Door.
	draw_rect(Rect2(-30, -56, 30, 56), EDGE)
	draw_rect(Rect2(-28, -54, 26, 54), Color("6e4626"))
	draw_rect(Rect2(-8, -30, 3, 3), Color("f2c230"))


## A tall blue hall with a big card over the door.
func _draw_cards() -> void:
	draw_rect(Rect2(-50, -132, 100, 132), EDGE)
	draw_rect(Rect2(-48, -130, 96, 130), Color("3d5aa8"))
	for x in [-40.0, 32.0]:
		draw_rect(Rect2(x, -130, 8, 130), Color("324a8c"))
	draw_rect(Rect2(-40, -112, 80, 22), Color("2a3150"))
	# Four card-type colors over the door.
	var types := ["attack", "jump", "movement", "misc"]
	for i in 4:
		var c: Color = AbilityCard.TYPE_COLORS[types[i]]
		var x := -34.0 + i * 18.0
		var bob := sin(_t * 2.0 + i) * 1.5
		draw_rect(Rect2(x, -84 + bob, 14, 18), c)
		draw_rect(Rect2(x + 2, -82 + bob, 10, 10), Color("eef1fa"))
	# Door.
	draw_rect(Rect2(-18, -58, 36, 58), EDGE)
	draw_rect(Rect2(-16, -56, 32, 56), Color("1f2d5c"))
	draw_rect(Rect2(-1, -56, 2, 56), EDGE)


## A small purple house with a peaked roof, a round window with a heart, and a replay arrow.
func _draw_replay() -> void:
	var roof := PackedVector2Array([Vector2(-48, -70), Vector2(0, -104), Vector2(48, -70)])
	draw_colored_polygon(roof, EDGE)
	draw_colored_polygon(PackedVector2Array([Vector2(-42, -72), Vector2(0, -100), Vector2(42, -72)]), Color("5a3d8c"))
	draw_rect(Rect2(-40, -72, 80, 72), EDGE)
	draw_rect(Rect2(-38, -70, 76, 70), Color("8a63c9"))
	draw_rect(Rect2(-38, -70, 76, 4), Color("a585dc"))
	# Window with a beating heart.
	draw_circle(Vector2(20, -42), 12.0, EDGE)
	draw_circle(Vector2(20, -42), 10.0, Color("2a3150"))
	var b := 1.0 + 0.12 * sin(_t * 4.0)
	draw_circle(Vector2(17, -44), 3.0 * b, Color("e5484d"))
	draw_circle(Vector2(23, -44), 3.0 * b, Color("e5484d"))
	draw_colored_polygon(PackedVector2Array([Vector2(13.5, -43), Vector2(26.5, -43), Vector2(20, -36 + 1.5 * (b - 1.0) * 10.0)]), Color("e5484d"))
	# Door with a circular replay arrow.
	draw_rect(Rect2(-30, -48, 30, 48), EDGE)
	draw_rect(Rect2(-28, -46, 26, 46), Color("3a2a66"))
	draw_arc(Vector2(-15, -30), 7.0, 0.6, TAU - 0.3, 16, Color("f2c230"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -36), Vector2(-6, -29), Vector2(-11, -33)]), Color("f2c230"))


## Paul: a pink block with a bow tie, a fan of cards in hand and a little bob.
func _draw_paul() -> void:
	var y := -2.0 * absf(sin(_t * 2.0))
	draw_rect(Rect2(-14, -28 + y, 28, 28), EDGE)
	draw_rect(Rect2(-12, -26 + y, 24, 24), Color("f27bb5"))
	draw_rect(Rect2(-12, -26 + y, 24, 4), Color("f9a8d0"))
	# Eyes that blink now and then.
	var blink := fmod(_t, 3.2) < 0.12
	for ex in [-6, 4]:
		draw_rect(Rect2(ex, -19 + y, 3, 1 if blink else 4), EDGE)
	# Bow tie.
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10 + y), Vector2(0, -8 + y), Vector2(-5, -6 + y)]), Color("7a3cc0"))
	draw_colored_polygon(PackedVector2Array([Vector2(5, -10 + y), Vector2(0, -8 + y), Vector2(5, -6 + y)]), Color("7a3cc0"))
	# A fan of three cards.
	for i in 3:
		var p := Vector2(16 + i * 3, -20 + y + i)
		draw_rect(Rect2(p, Vector2(7, 10)), EDGE)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(5, 8)), [Color("e5484d"), Color("f2c230"), Color("4a8fe7")][i])
	if closed:
		# A little striped shutter pulled down in front of him, with a sign.
		draw_rect(Rect2(-22, -18, 44, 18), EDGE)
		for i in 4:
			draw_rect(Rect2(-20, -16 + i * 4, 40, 3), Color("c9cfe0") if i % 2 == 0 else Color("9aa3bd"))
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_rect(Rect2(-w / 2.0 - 3, -15, w + 6, 11), Color("f2c230"))
		draw_string(font, Vector2(-w / 2.0, -7), "SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, EDGE)


## Terry: a yellow block flopped on the ground, eyes shut, with Zzz floating up.
func _draw_terry() -> void:
	var breathe := 1.0 + 0.6 * sin(_t * 1.5)
	draw_rect(Rect2(-16, -20 - breathe, 32, 20 + breathe), EDGE)
	draw_rect(Rect2(-14, -18 - breathe, 28, 18 + breathe), Color("f2c230"))
	draw_rect(Rect2(-14, -18 - breathe, 28, 3), Color("f8dc72"))
	for ex in [-8, 3]:
		draw_rect(Rect2(ex, -10, 5, 1), EDGE)   # shut eyes
	var font := ThemeDB.fallback_font
	for i in 3:
		var k := fmod(_t * 0.5 + i / 3.0, 1.0)
		draw_string(font, Vector2(12 + k * 14, -24 - k * 26), "z", HORIZONTAL_ALIGNMENT_LEFT, -1,
			10 + int(k * 6), Color(1, 1, 1, 1.0 - k))


## Paula / Tim: a square strolling back and forth, bobbing, eyes looking the way it walks.
func _draw_walker() -> void:
	var cols: Array = WALKERS[kind]
	var dir := 1.0 if cos(_t * 0.7) >= 0.0 else -1.0
	var y := -2.0 * absf(sin(_t * 6.0))
	draw_rect(Rect2(-13, -26 + y, 26, 26), EDGE)
	draw_rect(Rect2(-11, -24 + y, 22, 22), cols[0])
	draw_rect(Rect2(-11, -24 + y, 22, 4), cols[1])
	var blink := fmod(_t + 1.3, 3.6) < 0.12
	for ex in [-6, 2]:
		draw_rect(Rect2(ex + dir * 2, -17 + y, 3, 1 if blink else 4), EDGE)
	if kind == "paula":
		# A little bow on top.
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -30 + y), Vector2(0, -27 + y), Vector2(-6, -24 + y)]), Color("f27bb5"))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -30 + y), Vector2(0, -27 + y), Vector2(6, -24 + y)]), Color("f27bb5"))
	else:
		# A small backpack, ready for a dive.
		draw_rect(Rect2(-dir * 13 - (4 if dir > 0 else 0), -20 + y, 4, 12), Color("8a5a2b"))


## Romeo paces between one tile left and one tile right of his spot, pauses, and sometimes hops
## 1-2 tiles straight up, landing where he took off.
func _romeo(delta: float) -> void:
	if _hop_t >= 0.0:
		_hop_t += delta
		var k := _hop_t / HOP_TIME
		position.y = _home.y - _hop_h * 4.0 * k * (1.0 - k)
		if k >= 1.0:
			_hop_t = -1.0
			position.y = _home.y
		return
	var x := position.x - _home.x
	if absf(_goal_x - x) > 0.5:
		position.x = _home.x + move_toward(x, _goal_x, 45.0 * delta)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(0.6, 1.8)
	if randf() < 0.35:
		_hop_t = 0.0
		_hop_h = randf_range(32.0, 64.0)
	else:
		_goal_x = [-32.0, 0.0, 32.0].pick_random()


## Romeo: a dark red block with a big excited grin and wide, sparkly eyes.
func _draw_romeo() -> void:
	var dir := signf(_goal_x - (position.x - _home.x)) if not portrait else 0.0
	var stretch := 3.0 if _hop_t >= 0.0 else 0.0
	var top := -26.0 - stretch
	draw_rect(Rect2(-13, top, 26, 26 + stretch), EDGE)
	draw_rect(Rect2(-11, top + 2, 22, 22 + stretch), Color("8e1b2a"))
	draw_rect(Rect2(-11, top + 2, 22, 4), Color("c03a4c"))
	# Wide eyes with a shine, raised brows.
	for ex in [-8, 2]:
		var e := Vector2(ex + dir * 1.5, top + 9)
		draw_rect(Rect2(e, Vector2(6, 6)), Color("f4f6ff"))
		draw_rect(Rect2(e + Vector2(2, 2), Vector2(3, 3)), EDGE)
		draw_rect(Rect2(e + Vector2(3, 2), Vector2(1, 1)), Color.WHITE)
		draw_rect(Rect2(e + Vector2(0, -3), Vector2(6, 1.5)), EDGE)
	# A big open grin.
	draw_rect(Rect2(-5 + dir * 1.5, top + 17, 10, 5), EDGE)
	draw_rect(Rect2(-3 + dir * 1.5, top + 20, 6, 2), Color("f27bb5"))


## A small, makeshift fishing hut: patchy planks, a tarp roof tied down at the corners, a crate.
func _draw_hut() -> void:
	draw_rect(Rect2(-34, -58, 60, 58), EDGE)
	var planks := [Color("9a7b55"), Color("8a6c48"), Color("a8875f"), Color("7f6342")]
	for i in 7:
		draw_rect(Rect2(-32 + i * 8, -54 + (i % 2) * 2, 7, 54 - (i % 2) * 2), planks[i % 4])
	# The tarp roof, a bit saggy, with ropes.
	draw_colored_polygon(PackedVector2Array([Vector2(-42, -52), Vector2(-4, -76), Vector2(34, -52),
		Vector2(18, -55), Vector2(-4, -58), Vector2(-26, -55)]), Color("3f8fd6"))
	draw_polyline(PackedVector2Array([Vector2(-42, -52), Vector2(-4, -76), Vector2(34, -52)]), EDGE, 2.0)
	draw_line(Vector2(-42, -52), Vector2(-38, 0), Color("d9c9a3"), 1.0)
	draw_line(Vector2(34, -52), Vector2(30, 0), Color("d9c9a3"), 1.0)
	# A dark doorway with a cloth flap, and a crate out front.
	draw_rect(Rect2(-18, -34, 16, 34), Color("2a2238"))
	draw_rect(Rect2(-18, -34, 7, 26), Color("c95c4a"))
	draw_rect(Rect2(8, -14, 16, 14), EDGE)
	draw_rect(Rect2(9, -13, 14, 12), Color("b58b52"))
	draw_line(Vector2(9, -7), Vector2(23, -7), EDGE, 1.0)
	# A hand-painted sign, slightly crooked.
	var font := ThemeDB.fallback_font
	draw_set_transform(Vector2(0, -46), -0.06)
	draw_rect(Rect2(-24, -8, 44, 13), Color("e9dcb8"))
	draw_string(font, Vector2(-21, 2), "BAIT?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, EDGE)
	draw_set_transform(Vector2.ZERO)


## Larry: a white block holding a fishing rod out over the pond, line bobbing.
func _draw_larry() -> void:
	var y := -1.0 * absf(sin(_t * 1.2))
	draw_rect(Rect2(-13, -26 + y, 26, 26), EDGE)
	draw_rect(Rect2(-11, -24 + y, 22, 22), Color("f2f4fa"))
	draw_rect(Rect2(-11, -24 + y, 22, 4), Color.WHITE)
	var blink := fmod(_t, 4.1) < 0.12
	for ex in [-7, 2]:
		draw_rect(Rect2(ex, -17 + y, 3, 1 if blink else 4), EDGE)
	draw_rect(Rect2(-3, -9 + y, 6, 1.5), EDGE)   # a calm little smile
	# A bucket hat.
	draw_rect(Rect2(-15, -29 + y, 30, 4), Color("6b8f5e"))
	draw_rect(Rect2(-10, -34 + y, 20, 6), Color("6b8f5e"))
	# The rod and its line, out toward the water on the right.
	var tip := Vector2(30, -46)
	draw_line(Vector2(8, -10 + y), tip, Color("7a5230"), 2.0)
	var bob := Vector2(tip.x + 10, 4 + 2.0 * sin(_t * 2.0))
	draw_line(tip, bob, Color(1, 1, 1, 0.7), 1.0)
	draw_rect(Rect2(bob.x - 2, bob.y - 3, 4, 4), Color("e5484d"))
