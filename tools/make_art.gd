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
	# Five 32×32 tiles: 0 = ground surface, 1 = ground fill, 2 = floating platform, 3 = rubber,
	# 4 = rubber wall.
	var img := Image.create_empty(160, 32, false, Image.FORMAT_RGBA8)
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
	_rubber(img, 96)
	_rubber_wall(img, 128)
	return img


func _rubber_wall(img: Image, ox: int) -> void:
	# The same yellow rubber turned on its side: glossy left edge, shaded right edge, and
	# vertical grip ribs. Top and bottom are flat so stacked tiles read as one column.
	var body := Color("f2c230")
	var light := Color("ffe27a")
	var shade := Color("b8860b")
	var groove := Color("9c7208")
	for y in 32:
		for x in 32:
			var c := body
			if x < 3:
				c = light
			elif x < 5:
				c = body.lerp(light, 0.5)
			elif x >= 27:
				c = shade
			img.set_pixel(ox + x, y, c)
	# Three vertical ribs, each with a highlight and a groove.
	for rx in [9, 16, 23]:
		img.fill_rect(Rect2i(ox + rx, 0, 2, 32), body.lerp(light, 0.6))
		img.fill_rect(Rect2i(ox + rx + 2, 0, 1, 32), groove)
	# Faint seam where tiles stack.
	img.fill_rect(Rect2i(ox + 5, 31, 22, 1), body.lerp(shade, 0.4))


func _rubber(img: Image, ox: int) -> void:
	# Yellow rubber: rounded, glossy top lip, darker body, and a row of grip studs.
	var body := Color("f2c230")
	var light := Color("ffe27a")
	var shade := Color("b8860b")
	var groove := Color("9c7208")
	for y in 32:
		for x in 32:
			# Rounded top corners (radius 6) so it reads as soft rubber, not stone.
			var cx := 6.0 if x < 6 else (25.0 if x > 25 else float(x))
			if y < 6 and Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx + 0.5, 6.5)) > 6.5:
				continue
			var c := body
			if y < 3:
				c = light
			elif y < 5:
				c = body.lerp(light, 0.5)
			elif y >= 27:
				c = shade
			img.set_pixel(ox + x, y, c)
	# Grip studs: two rows of small raised bumps with a highlight and a shadow.
	for row in [[11, 4], [19, 12]]:
		var y0: int = row[0]
		var x := ox + int(row[1])
		while x < ox + 30:
			img.fill_rect(Rect2i(x, y0, 4, 4), shade)
			img.fill_rect(Rect2i(x, y0, 3, 3), body.lerp(light, 0.6))
			x += 16
	# A horizontal groove near the bottom, like the edge of a rubber mat.
	img.fill_rect(Rect2i(ox + 2, 25, 28, 1), groove)


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
