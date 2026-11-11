class_name MainMenu
extends Control
## The title screen, shown when the game starts and after leaving a run.
##   Main:    the player, the game's name, Play, Cards, Options, Credits
##   Cards:   the card collection: every card by type, locked ones as silhouettes
##   Card:    one card up close, with what it does and Equip / Unequip
##   Credits: who and what made the game, and the engine's license
## Options opens the same Options page as the pause menu.

signal play_pressed
signal options_pressed

const BUTTON_SIZE := Vector2(240, 44)
const DIM := Color("a9b3d1")

var _pages := {}
var _square: PlayerPreview
var _count: Label
var _icons := {}          # ability -> CardIcon in the collection grid
var _big: CardIcon
var _big_type: Label
var _big_text: Label
var _equip: Button
var _shown := ""


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
	_button(main, "Play", func() -> void: play_pressed.emit())
	_button(main, "Cards", func() -> void: _open_collection())
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
	for type_name in ["attack", "jump", "movement"]:
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
			b.custom_minimum_size = Vector2(60, 64)
			b.pressed.connect(_open_card.bind(a))
			var icon := CardIcon.new()
			icon.card_scale = 1.6
			icon.ability = a
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			b.add_child(icon)
			row.add_child(b)
			_icons[a] = icon
		cards.add_child(row)
	_button(cards, "Back", func() -> void: _show("Main"))

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

	panel.add_child(main)
	panel.add_child(cards)
	panel.add_child(card)
	panel.add_child(credits)
	open()


func open(player_color := Color("ff6b5e")) -> void:
	_square.color = player_color
	show()
	_show("Main")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _pages["Card"].visible:
		get_viewport().set_input_as_handled()
		_open_collection()
	elif _pages["Credits"].visible or _pages["Cards"].visible:
		get_viewport().set_input_as_handled()
		_show("Main")


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
