extends SceneTree
# Pass 1: write the PNGs (tiles and touch buttons). They must be imported before scenes can use them.

const STONE := Color("e2a86f")
const STONE_TOP := Color("f7d5a6")
const STONE_SIDE := Color("ad7546")
const INK := Color("eef1fa")
const PAD := Color(0.067, 0.09, 0.169, 0.55)


func _initialize() -> void:
	var art := ProjectSettings.globalize_path("res://art")
	DirAccess.make_dir_recursive_absolute(art)
	_tiles().save_png(art + "/tiles.png")
	_circle(76, PAD, Color(INK, 0.35)).save_png(art + "/button.png")
	_circle(76, Color(INK, 0.25), Color(INK, 0.6)).save_png(art + "/button_pressed.png")
	_circle(92, PAD, Color(0.475, 0.886, 0.761, 0.6)).save_png(art + "/button_big.png")
	_circle(92, Color(INK, 0.25), Color(0.475, 0.886, 0.761, 0.9)).save_png(art + "/button_big_pressed.png")
	print("ART OK")
	quit()


func _tiles() -> Image:
	# Three 32×32 tiles: 0 = ground surface, 1 = ground fill, 2 = floating platform.
	var img := Image.create_empty(96, 32, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 32, 32), STONE)
	img.fill_rect(Rect2i(0, 0, 32, 6), STONE_TOP)
	img.fill_rect(Rect2i(0, 6, 1, 26), STONE_SIDE)
	img.fill_rect(Rect2i(32, 0, 32, 32), STONE)
	img.fill_rect(Rect2i(32, 0, 1, 32), STONE_SIDE)
	for p in [Vector2i(41, 9), Vector2i(53, 21), Vector2i(46, 27), Vector2i(58, 6)]:
		img.fill_rect(Rect2i(p, Vector2i(2, 2)), STONE_SIDE)
	img.fill_rect(Rect2i(64, 0, 32, 32), STONE)
	img.fill_rect(Rect2i(64, 0, 32, 6), STONE_TOP)
	img.fill_rect(Rect2i(64, 26, 32, 6), STONE_SIDE)
	img.fill_rect(Rect2i(64, 6, 1, 20), STONE_SIDE)
	return img


func _circle(diameter: int, fill: Color, ring: Color) -> Image:
	var img := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if d <= r - 2.5:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, ring)
	return img
