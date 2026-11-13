class_name MainMenu
extends Control
## The title screen, shown when the game starts and after leaving a run.
##   Main:    the player, the game's name, the save file in use, Play, Options, Credits
## Shop and Cards are opened from their buildings in town (open_page).
##   Files:   3 save files to pick from (each has its own cards); Delete starts one over,
##            after an "Are you sure?" check
##   Cards:   the card collection: every card by type, locked ones as silhouettes
##   Card:    one card up close, with what it does and Equip / Unequip
##   Shop:    3 cards on display for pixels, restocked every few wins
##   Buy:     one shop card up close, with what it does and Buy
##   Replay:  the Replay Room: 10–20 liked levels to play again (Hard / Scramble pay once each)
##   Mode:    how to replay one: True, Hard or Scramble
##   Credits: who and what made the game, and the engine's license
## Options opens the same Options page as the pause menu.

signal play_pressed
## The save file has a saved dungeon run: pick it back up, or end it and go to town.
signal resume_run_pressed
signal end_run_pressed
signal options_pressed
## A Shop or Cards visit from town is over.
signal closed
## Replay Room: play this liked level.
## mode: "true", "hard" or "scramble".
signal replay_requested(seed_value: int, mode: String)

const BUTTON_SIZE := Vector2(240, 44)
const DIM := Color("a9b3d1")

var _pages := {}
var _resume_text: Label
var _square: PlayerPreview
var _count: Label
var _icons := {}          # ability -> CardIcon in the collection grid
var _big: CardIcon
var _big_type: Label
var _big_text: Label
var _equip: Button
var _shown := ""
## Opened from a town building: Back leaves the menu instead of going to the Main page.
var _town := false
var _file_label: Label
var _file_buttons: Array[Button] = []
var _erase_buttons: Array[Button] = []
var _shop_info: Label
var _shop_slots: Array[Button] = []
var _shop_icons: Array[CardIcon] = []
var _shop_prices: Array[Label] = []
var _shop_pick := ""
var _buy_big: CardIcon
var _buy_type: Label
var _buy_text: Label
var _buy: Button
var _buy_sfx: AudioStreamPlayer
var _replay_list: VBoxContainer
var _replay_info: Label
var _mode_title: Label
var _mode_seed := 0
var _paul_info: Label
var _paul_row: HBoxContainer
## Where the Buy page goes back to: "Shop" or "Paul".
var _buy_from := "Shop"
var _mode_notes := {}   # "hard"/"scramble" -> Label under its button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.067, 0.09, 0.169, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var main := _page("Main")
	_square = PlayerPreview.new()
	_square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main.add_child(_square)
	var title := Label.new()
	title.text = "Square Hop"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)
	var tagline := Label.new()
	tagline.text = "Run, jump and bounce to the goal."
	tagline.add_theme_color_override("font_color", DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(tagline)
	_file_label = Label.new()
	_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_file_label.theme_type_variation = "SmallLabel"
	_file_label.add_theme_color_override("font_color", DIM)
	main.add_child(_file_label)
	_button(main, "Play", func() -> void: _open_files())
	_button(main, "Options", func() -> void: options_pressed.emit())
	_button(main, "Credits", func() -> void: _show("Credits"))

	var credits := _page("Credits")
	var title2 := Label.new()
	title2.text = "Credits"
	title2.theme_type_variation = "TitleLabel"
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_child(title2)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	credits.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	_credit(list, "Game design and direction", "The Square Hop team")
	_credit(list, "Programming, art, music and sound",
		"Made with Claude (Anthropic) in Claude Code. All art is drawn by code and all music "
		+ "and sounds are synthesized, so there are no outside assets.")
	_credit(list, "Engine", "Made with Godot Engine %s (godotengine.org)" % _godot_version())
	_credit(list, "Font", "Open Sans, Godot's default font (SIL Open Font License 1.1)")
	_credit(list, "Thanks", "Thanks for playing!")
	_credit(list, "Godot Engine license", Engine.get_license_text()
		+ "\nPortions of this software are copyright © The FreeType Project "
		+ "(www.freetype.org). All rights reserved. Godot also includes other open-source "
		+ "libraries; see godotengine.org/license.")
	_button(credits, "Back", func() -> void: _show("Main"))

	var cards := _page("Cards")
	cards.add_child(_title("Cards"))
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", DIM)
	cards.add_child(_count)
	for type_name in ["attack", "jump", "movement", "misc"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var label := Label.new()
		label.text = String(type_name).capitalize()
		label.custom_minimum_size = Vector2(96, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_color_override("font_color", AbilityCard.TYPE_COLORS[type_name].lightened(0.25))
		row.add_child(label)
		for a in CardCollection.ALL:
			if AbilityCard.TYPES[a] != type_name:
				continue
			var b := Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(60, 58)
			b.pressed.connect(_open_card.bind(a))
			var icon := CardIcon.new()
			icon.card_scale = 1.5
			icon.ability = a
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			b.add_child(icon)
			row.add_child(b)
			_icons[a] = icon
		cards.add_child(row)
	_button(cards, "Back", _back_out)

	var card := _page("Card")
	_big = CardIcon.new()
	_big.card_scale = 4.0
	_big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(_big)
	_big_type = Label.new()
	_big_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_big_type)
	_big_text = Label.new()
	_big_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_big_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_text.custom_minimum_size = Vector2(280, 0)
	_big_text.add_theme_color_override("font_color", DIM)
	card.add_child(_big_text)
	_equip = _button(card, "Equip", _toggle_equip)
	_button(card, "Back", func() -> void: _open_collection())

	var shop := _page("Shop")
	shop.add_child(_title("Shop"))
	_shop_info = Label.new()
	_shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_info.add_theme_color_override("font_color", DIM)
	shop.add_child(_shop_info)
	# The counter: cards on little stands over a blocky wooden counter.
	var counter := Control.new()
	counter.custom_minimum_size = Vector2(330, 150)
	counter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	counter.draw.connect(func() -> void: _draw_counter(counter))
	shop.add_child(counter)
	for i in CardCollection.SHOP_SIZE:
		var b := Button.new()
		b.flat = true
		b.position = Vector2(15 + i * 104, 4)
		b.size = Vector2(92, 96)
		b.pressed.connect(func() -> void: _open_buy(CardCollection.shop_stock[i] if i < CardCollection.shop_stock.size() else ""))
		var icon := CardIcon.new()
		icon.card_scale = 2.2
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		counter.add_child(b)
		var price := Label.new()
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.position = Vector2(15 + i * 104, 118)
		price.size = Vector2(92, 24)
		price.add_theme_color_override("font_color", Color("f2c230"))
		counter.add_child(price)
		_shop_slots.append(b)
		_shop_icons.append(icon)
		_shop_prices.append(price)
	_button(shop, "Back", _back_out)

	var paul := _page("Paul")
	paul.add_child(_title("Paul's Cards"))
	_paul_row = HBoxContainer.new()
	_paul_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_paul_row.add_theme_constant_override("separation", 12)
	paul.add_child(_paul_row)
	# A thin line between Paul's cards and what he says.
	var line := ColorRect.new()
	line.color = Color(DIM, 0.5)
	line.custom_minimum_size = Vector2(300, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	paul.add_child(line)
	_paul_info = Label.new()
	_paul_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paul_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paul_info.custom_minimum_size = Vector2(300, 0)
	_paul_info.add_theme_color_override("font_color", DIM)
	paul.add_child(_paul_info)
	_button(paul, "Back", _back_out)

	var replay := _page("Replay")
	replay.add_child(_title("Replay Room"))
	_replay_info = Label.new()
	_replay_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_replay_info.custom_minimum_size = Vector2(320, 0)
	_replay_info.add_theme_color_override("font_color", DIM)
	replay.add_child(_replay_info)
	var replay_scroll := ScrollContainer.new()
	replay_scroll.custom_minimum_size = Vector2(340, 300)
	replay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	replay.add_child(replay_scroll)
	_replay_list = VBoxContainer.new()
	_replay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_list.add_theme_constant_override("separation", 8)
	replay_scroll.add_child(_replay_list)
	_button(replay, "Back", _back_out)

	var mode := _page("Mode")
	_mode_title = _title("")
	mode.add_child(_mode_title)
	for m in [["True Replay", "true", "The level exactly as it was."],
			["Hard Replay", "hard", "More Bad Blocks, and they're faster, horned and sharper-eyed."],
			["Scramble Replay", "scramble", "Start and goal land in new random spots, at least half the level apart."]]:
		var key: String = m[1]
		_button(mode, m[0], func() -> void: replay_requested.emit(_mode_seed, key))
		var d := Label.new()
		d.text = m[2]
		d.theme_type_variation = "SmallLabel"
		d.add_theme_color_override("font_color", DIM)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(300, 0)
		mode.add_child(d)
		if key != "true":
			var note := Label.new()
			note.theme_type_variation = "SmallLabel"
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(300, 0)
			mode.add_child(note)
			_mode_notes[key] = note
	_button(mode, "Back", _open_replay)

	var buy := _page("Buy")
	_buy_big = CardIcon.new()
	_buy_big.card_scale = 4.0
	_buy_big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy.add_child(_buy_big)
	_buy_type = Label.new()
	_buy_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy.add_child(_buy_type)
	_buy_text = Label.new()
	_buy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_text.custom_minimum_size = Vector2(280, 0)
	_buy_text.add_theme_color_override("font_color", DIM)
	buy.add_child(_buy_text)
	_buy = _button(buy, "Buy", _buy_card)
	_button(buy, "Back", _buy_back)
	_buy_sfx = AudioStreamPlayer.new()
	_buy_sfx.stream = load("res://audio/buy.wav")
	_buy_sfx.bus = AudioSettings.SOUNDS_BUS
	add_child(_buy_sfx)

	var files := _page("Files")
	files.add_child(_title("Save Files"))
	for n in range(1, CardCollection.FILES + 1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(250, 56)
		pick.pressed.connect(func() -> void:
			if _erase_buttons[n - 1].get_meta("armed", false):
				_update_file_row(n)   # tapping the file while asking cancels the delete
			else:
				_pick_file(n))
		row.add_child(pick)
		var erase := Button.new()
		erase.custom_minimum_size = Vector2(92, 56)
		erase.pressed.connect(_erase_file.bind(n))
		row.add_child(erase)
		files.add_child(row)
		_file_buttons.append(pick)
		_erase_buttons.append(erase)
	_button(files, "Back", func() -> void: _show("Main"))

	var resume := _page("Resume")
	resume.add_child(_title("Saved Run"))
	_resume_text = Label.new()
	_resume_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resume_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resume_text.custom_minimum_size = Vector2(280, 0)
	_resume_text.add_theme_color_override("font_color", DIM)
	resume.add_child(_resume_text)
	_button(resume, "Resume", func() -> void: resume_run_pressed.emit())
	_button(resume, "End Run (go to town)", func() -> void:
		CardCollection.run = {}
		CardCollection.save()
		end_run_pressed.emit())

	panel.add_child(main)
	panel.add_child(resume)
	panel.add_child(files)
	panel.add_child(cards)
	panel.add_child(card)
	panel.add_child(shop)
	panel.add_child(buy)
	panel.add_child(paul)
	panel.add_child(replay)
	panel.add_child(mode)
	panel.add_child(credits)
	open()


func open(player_color := Color("ff6b5e")) -> void:
	_town = false
	_square.color = player_color
	CardCollection.setup()
	_update_main_label()
	show()
	_show("Main")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _pages["Mode"].visible:
		get_viewport().set_input_as_handled()
		_open_replay()
	elif _pages["Card"].visible:
		get_viewport().set_input_as_handled()
		_open_collection()
	elif _pages["Buy"].visible:
		get_viewport().set_input_as_handled()
		_buy_back()
	elif _pages["Shop"].visible or _pages["Cards"].visible or _pages["Replay"].visible or _pages["Paul"].visible:
		get_viewport().set_input_as_handled()
		_back_out()
	elif _pages["Credits"].visible or _pages["Cards"].visible or _pages["Files"].visible:
		get_viewport().set_input_as_handled()
		_show("Main")


## Opens the Shop or Cards page from its town building.
func open_page(page_name: String) -> void:
	CardCollection.setup()
	_town = true
	show()
	if page_name == "Shop":
		_open_shop()
	elif page_name == "Replay":
		_open_replay()
	elif page_name == "Paul":
		_open_paul()
	else:
		_open_collection()


func _back_out() -> void:
	if _town:
		hide()
		closed.emit()
	else:
		_show("Main")


func _open_files() -> void:
	CardCollection.setup()
	for i in CardCollection.FILES:
		_update_file_row(i + 1)
	_show("Files")
	_file_buttons[CardCollection.file - 1].grab_focus()


func _update_file_row(n: int) -> void:
	var pick := _file_buttons[n - 1]
	var erase := _erase_buttons[n - 1]
	var used := CardCollection.file_exists(n)
	var mark := "  ·  Current" if n == CardCollection.file else ""
	if used:
		pick.text = "File %d%s\n%d of %d cards  ·  %d pixels" % [n, mark, CardCollection.file_card_count(n),
			CardCollection.ALL.size(), CardCollection.file_pixels(n)]
	else:
		pick.text = "File %d%s\nNew game" % [n, mark]
	erase.text = "Delete"
	erase.visible = used
	erase.set_meta("armed", false)


## Pick a save file and go on to the level screen.
func _pick_file(n: int) -> void:
	CardCollection.use_file(n)
	_update_main_label()
	if not CardCollection.run.is_empty():
		_resume_text.text = "You stopped in the middle of a run: %s. Resume from the start of that level?" \
			% CardCollection.run.get("where", "the dungeon")
		_show("Resume")
		return
	play_pressed.emit()


## Delete asks "Are you sure?" first: tap Yes to delete the file, or tap the file to cancel.
func _erase_file(n: int) -> void:
	var erase := _erase_buttons[n - 1]
	if not erase.get_meta("armed", false):
		_file_buttons[n - 1].text = "Are you sure?\nDelete File %d for good? Tap here to keep it." % n
		erase.text = "Yes"
		erase.set_meta("armed", true)
		return
	CardCollection.erase_file(n)
	_update_file_row(n)
	_update_main_label()
	_file_buttons[n - 1].grab_focus()


func _update_main_label() -> void:
	_file_label.text = "Save file %d" % CardCollection.file


func _open_collection() -> void:
	CardCollection.setup()
	_count.text = "Found %d of %d  ·  Equipped %d of %d" % [CardCollection.owned.size(),
		CardCollection.ALL.size(), CardCollection.equipped.size(), CardCollection.MAX_EQUIPPED]
	for a in _icons:
		_icons[a].locked = not CardCollection.owns(a)
		_icons[a].equipped = CardCollection.is_equipped(a)
	_show("Cards")
	# Focus the card you were just looking at, or the first one.
	_icons[_shown if _icons.has(_shown) else CardCollection.ALL[0]].get_parent().grab_focus()


func _open_card(a: String) -> void:
	_shown = a
	var found := CardCollection.owns(a)
	_big.ability = a
	_big.locked = not found
	var type_name: String = AbilityCard.TYPES[a]
	_big_type.text = AbilityCard.TYPE_NAMES[type_name] if found else "Locked card"
	_big_type.add_theme_color_override("font_color",
		AbilityCard.TYPE_COLORS[type_name].lightened(0.25) if found else DIM)
	_big_text.text = AbilityCard.DESCRIPTIONS[a] if found else "Not found yet. Keep playing to find it."
	_equip.visible = found
	_update_equip()
	_show("Card")
	if found:
		_equip.grab_focus()


func _update_equip() -> void:
	var on := CardCollection.is_equipped(_shown)
	var full := CardCollection.equipped.size() >= CardCollection.MAX_EQUIPPED
	_big.equipped = on
	_equip.text = "Unequip" if on else ("All 3 slots are full" if full else "Equip")
	_equip.disabled = not on and full


func _toggle_equip() -> void:
	CardCollection.toggle_equip(_shown)
	_update_equip()


func _open_shop() -> void:
	_buy_from = "Shop"
	CardCollection.setup()
	var stock := CardCollection.get_shop()
	var left := CardCollection.RESTOCK_WINS - CardCollection.shop_wins
	_shop_info.text = "You have %d pixels  ·  New cards in %d win%s" % [CardCollection.pixels, left,
		"" if left == 1 else "s"]
	for i in _shop_slots.size():
		var a: String = stock[i] if i < stock.size() else ""
		_shop_icons[i].visible = a != ""
		_shop_slots[i].disabled = a == ""
		if a != "":
			_shop_icons[i].ability = a
		_shop_prices[i].text = ("%d px" % CardCollection.price_of(a)) if a != "" else ("Sold" if i < stock.size() else "")
	_show("Shop")
	for i in _shop_slots.size():
		if not _shop_slots[i].disabled:
			_shop_slots[i].grab_focus()
			return
	_pages["Shop"].get_child(-1).grab_focus()


## Lists the liked levels, each with Play and Remove.
func _open_replay() -> void:
	for c in _replay_list.get_children():
		_replay_list.remove_child(c)
		c.queue_free()
	var liked := CardCollection.liked
	_replay_info.text = ("Levels you liked: %d / %d. Hard and Scramble pay once each." % [liked.size(), CardCollection.room_size()]) \
		if liked.size() > 0 else "No saved levels yet. Win a random level and tap Save to Replay Room."
	for sv in liked:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var shape := "Vertical" if LevelGen.is_vertical(sv) else ("Diagonal" if LevelGen.is_diagonal(sv) else "Horizontal")
		var play := Button.new()
		play.text = "▶ Seed %d · %s" % [sv, shape]
		play.custom_minimum_size = Vector2(250, 44)
		play.pressed.connect(func() -> void:
			_mode_seed = sv
			_mode_title.text = "Seed %d" % sv
			for k in _mode_notes:
				var done := CardCollection.is_beaten("%s:seed%d" % [k, sv])
				_mode_notes[k].text = "Cleared" if done \
					else "First clear: +3 pixels and +1 Replay Room space"
				_mode_notes[k].add_theme_color_override("font_color", Color("ffd166") if done else Color("79e2c2"))
			_show("Mode"))
		row.add_child(play)
		var remove := Button.new()
		remove.text = "✕"
		remove.custom_minimum_size = Vector2(44, 44)
		remove.pressed.connect(func() -> void:
			CardCollection.toggle_like(sv)
			_open_replay())
		row.add_child(remove)
		_replay_list.add_child(row)
	_show("Replay")
	if liked.size() > 0:
		_replay_list.get_child(0).get_child(0).grab_focus()
	else:
		_pages["Replay"].get_child(-1).grab_focus()


func _open_buy(a: String) -> void:
	if a == "":
		return
	_shop_pick = a
	_buy_big.ability = a
	var type_name: String = AbilityCard.TYPES[a]
	_buy_type.text = AbilityCard.TYPE_NAMES[type_name]
	_buy_type.add_theme_color_override("font_color", AbilityCard.TYPE_COLORS[type_name].lightened(0.25))
	_buy_text.text = AbilityCard.DESCRIPTIONS[a]
	var cost := CardCollection.price_of(a)
	var short := cost - CardCollection.pixels
	_buy.text = ("Buy (%d pixels)" % cost) if short <= 0 else ("Need %d more pixels" % short)
	_buy.disabled = short > 0
	_show("Buy")
	if _buy.disabled:
		_pages["Buy"].get_child(-1).grab_focus()


func _buy_card() -> void:
	var ok := CardCollection.buy_from_paul(_shop_pick) if _buy_from == "Paul" else CardCollection.buy(_shop_pick)
	if ok:
		_buy_sfx.play()
		_buy_back()


func _buy_back() -> void:
	if _buy_from == "Paul":
		_open_paul()
	else:
		_open_shop()


## Paul's mini shop: the Paul-only cards you don't have yet.
func _open_paul() -> void:
	_buy_from = "Paul"
	for c in _paul_row.get_children():
		_paul_row.remove_child(c)
		c.queue_free()
	var stock := CardCollection.paul_stock()
	if CardCollection.pool("paul").is_empty():
		_paul_info.text = "Paul: \"Oh, hi! I'm still unpacking my cards. Come back soon!\""
	elif stock.is_empty():
		_paul_info.text = "Paul: \"You've got every card I have. Nice!\""
	else:
		_paul_info.text = "Paul: \"Cards you won't find anywhere else!\"  ·  You have %d pixels" % CardCollection.pixels
	for a in stock:
		var col := VBoxContainer.new()
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(92, 96)
		var icon := CardIcon.new()
		icon.card_scale = 2.2
		icon.ability = a
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(icon)
		b.pressed.connect(_open_buy.bind(a))
		col.add_child(b)
		var price := Label.new()
		price.text = "%d px" % CardCollection.PAUL_PRICE
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_color", Color("f2c230"))
		col.add_child(price)
		_paul_row.add_child(col)
	_show("Paul")
	if not stock.is_empty():
		_paul_row.get_child(0).get_child(0).grab_focus()
	else:
		_pages["Paul"].get_child(-1).grab_focus()


## Wooden stands under each slot and a blocky counter along the bottom.
func _draw_counter(c: Control) -> void:
	var wood := Color("9c6b3f")
	var dark := Color("6e4626")
	var light := Color("c48a52")
	var edge := Color("3b2716")
	for i in CardCollection.SHOP_SIZE:
		var x := 15.0 + i * 104
		c.draw_rect(Rect2(x + 30, 92, 32, 18), edge)
		c.draw_rect(Rect2(x + 32, 92, 28, 16), dark)
		c.draw_rect(Rect2(x + 32, 92, 28, 3), light)
	c.draw_rect(Rect2(0, 108, c.size.x, 42), edge)
	c.draw_rect(Rect2(2, 110, c.size.x - 4, 38), wood)
	c.draw_rect(Rect2(2, 110, c.size.x - 4, 4), light)
	for bx in range(2, int(c.size.x) - 4, 22):
		c.draw_rect(Rect2(bx, 114, 1, 34), dark)


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "TitleLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _show(page_name: String) -> void:
	for n in _pages:
		_pages[n].visible = n == page_name
	for c in _pages[page_name].get_children():
		if c is Button:
			c.grab_focus()
			break


func _page(page_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = page_name
	box.add_theme_constant_override("separation", 14)
	_pages[page_name] = box
	return box


func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	box.add_child(b)
	return b


## A small dim heading with its text under it.
func _credit(list: VBoxContainer, heading: String, text: String) -> void:
	var h := Label.new()
	h.text = heading
	h.theme_type_variation = "SmallLabel"
	h.add_theme_color_override("font_color", DIM)
	list.add_child(h)
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	list.add_child(t)


func _godot_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]
