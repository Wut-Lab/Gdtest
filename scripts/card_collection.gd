class_name CardCollection
extends RefCounted
## The player's ability card collection, kept for good in one of 3 save files on this device.
## owned: every card found so far in the current file. equipped: up to 3 of them, used on every run.
## A new file starts with one free card (Heart Box) so the collection isn't empty.
## Each file also keeps its pixels (the currency) and which treasure chests it has opened.
## Sound and the player's color are shared settings, not part of a save file.

const SETTINGS := "user://settings.cfg"
const FILES := 3
const MAX_EQUIPPED := 3
const STARTER := "heart_box"
## Every card, grouped by type, in the order the collection screen shows them.
const ALL := ["dash", "pound", "double_jump", "glide", "quick", "tele_hop", "high_jump", "phase_jump", "shockwave", "stun_landing", "grip_and_go", "lucky_charm", "bounce_house", "wall_cling", "brick_drop", "slow_burst", "portion_booster", "air_brake", "momentum", "heart_box"]

## Where each card can come from (its drop group, as on the blueprint):
##   shop = Shop Only, find = Find Only (chests), drop = Drop Only, level = Find and Drop
##   (anything earned in levels, never sold), all = Shop, Find and Drop, starter = only the
##   card every new save file starts with. Cards not listed are "all".
const DROP_GROUPS := {
	"dash": "level", "pound": "shop", "shockwave": "level", "stun_landing": "shop",
	"brick_drop": "all",
	"double_jump": "shop", "glide": "level", "high_jump": "shop", "phase_jump": "level",
	"wall_cling": "all",
	"quick": "shop", "tele_hop": "level", "air_brake": "level", "grip_and_go": "shop",
	"momentum": "all",
	"heart_box": "starter", "lucky_charm": "shop", "bounce_house": "shop", "slow_burst": "level",
	"portion_booster": "level",
}
## The shop: every card costs the same for now, 3 on display, new stock every 3 wins.
const PRICE := 30
const SHOP_SIZE := 3
const RESTOCK_WINS := 3

## The save file in use, 1 to 3.
static var file := 1
static var owned: Array[String] = []
static var equipped: Array[String] = []
static var pixels := 0
## Chests already opened, as "level key:chest number", so each pays out once.
static var opened_chests: Array[String] = []
## The cards on display in the shop ("" = sold), and wins since it last restocked.
static var shop_stock: Array[String] = []
static var shop_wins := 0
static var _loaded := false


static func path(n: int) -> String:
	return "user://save_%d.cfg" % n


## Opens the save file used last (file 1 the first time).
static func setup() -> void:
	if _loaded:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	use_file(clampi(int(cfg.get_value("game", "last_file", 1)), 1, FILES))


## Switches to save file n, starting it fresh if it's empty, and remembers it as the last used.
static func use_file(n: int) -> void:
	_loaded = true
	file = n
	var cfg := ConfigFile.new()
	if cfg.load(path(n)) == OK and cfg.has_section_key("cards", "owned"):
		owned.assign(cfg.get_value("cards", "owned", []))
		equipped.assign(cfg.get_value("cards", "equipped", []))
		owned = owned.filter(func(a: String) -> bool: return a in ALL)
		equipped = equipped.filter(func(a: String) -> bool: return a in owned)
		pixels = int(cfg.get_value("progress", "pixels", 0))
		opened_chests.assign(cfg.get_value("progress", "opened_chests", []))
		shop_stock.assign(cfg.get_value("shop", "stock", []))
		shop_wins = int(cfg.get_value("shop", "wins", 0))
	else:
		# A fresh file: written to disk the first time something changes.
		owned.assign([STARTER])
		equipped.assign([STARTER])
		pixels = 0
		opened_chests.clear()
		shop_stock.clear()
		shop_wins = 0
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("game", "last_file", n)
	settings.save(SETTINGS)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path(file))
	cfg.set_value("cards", "owned", owned)
	cfg.set_value("cards", "equipped", equipped)
	cfg.set_value("progress", "pixels", pixels)
	cfg.set_value("progress", "opened_chests", opened_chests)
	cfg.set_value("shop", "stock", shop_stock)
	cfg.set_value("shop", "wins", shop_wins)
	cfg.save(path(file))


static func add_pixels(n: int) -> void:
	pixels += n
	save()


static func chest_opened(key: String) -> bool:
	return key in opened_chests


static func mark_chest(key: String) -> void:
	if key not in opened_chests:
		opened_chests.append(key)
		save()


static func drop_group(ability: String) -> String:
	return DROP_GROUPS.get(ability, "all")


## Cards that can come from a source ("shop", "find" or "drop").
static func pool(source: String) -> Array:
	return ALL.filter(func(a: String) -> bool:
		var g := drop_group(a)
		return g == source or g == "all" or (g == "level" and source in ["find", "drop"]))


## The shop's cards, stocking it first if it's empty. Cards already owned aren't stocked.
static func get_shop() -> Array[String]:
	if shop_stock.is_empty():
		var left := pool("shop").filter(func(a: String) -> bool: return a not in owned)
		left.shuffle()
		shop_stock.assign(left.slice(0, SHOP_SIZE))
		save()
	return shop_stock


## A win counts toward restocking the shop.
static func record_win() -> void:
	shop_wins += 1
	if shop_wins >= RESTOCK_WINS:
		shop_wins = 0
		shop_stock.clear()
	save()


## Buys a card on display. Returns false if it isn't there or there aren't enough pixels.
static func buy(ability: String) -> bool:
	var i := shop_stock.find(ability)
	if i < 0 or pixels < PRICE or ability in owned:
		return false
	pixels -= PRICE
	shop_stock[i] = ""
	add(ability)   # saves
	return true


## A random card this file hasn't found yet, or "" if it has them all.
static func random_unowned() -> String:
	var left := ALL.filter(func(a: String) -> bool: return a not in owned)
	return "" if left.is_empty() else left[randi() % left.size()]


## How many pixels save file n has.
static func file_pixels(n: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path(n)) != OK:
		return 0
	return int(cfg.get_value("progress", "pixels", 0))


## Whether save file n has been started.
static func file_exists(n: int) -> bool:
	return FileAccess.file_exists(path(n))


## How many cards save file n has found (0 if it hasn't been started).
static func file_card_count(n: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path(n)) != OK:
		return 0
	return (cfg.get_value("cards", "owned", []) as Array).size()


## Deletes save file n. If it's the one in use, it starts over fresh.
static func erase_file(n: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path(n)))
	if n == file:
		use_file(n)


static func owns(ability: String) -> bool:
	return ability in owned


static func is_equipped(ability: String) -> bool:
	return ability in equipped


## Adds a found card. Returns true if it's new. New cards are equipped if a slot is free.
static func add(ability: String) -> bool:
	if ability in owned:
		return false
	owned.append(ability)
	if equipped.size() < MAX_EQUIPPED:
		equipped.append(ability)
	save()
	return true


## Equips or unequips an owned card. Returns false if all 3 slots are full.
static func toggle_equip(ability: String) -> bool:
	if ability in equipped:
		equipped.erase(ability)
	elif ability in owned and equipped.size() < MAX_EQUIPPED:
		equipped.append(ability)
	else:
		return false
	save()
	return true
