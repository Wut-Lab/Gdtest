class_name CardCollection
extends RefCounted
## The player's ability card collection, kept for good on this device.
## owned: every card found so far. equipped: up to 3 of them, used on every run.
## A new save starts with one free card (Double Jump) so the collection isn't empty.

const PATH := "user://settings.cfg"
const MAX_EQUIPPED := 3
const STARTER := "double_jump"
## Every card, grouped by type, in the order the collection screen shows them.
const ALL := ["dash", "pound", "double_jump", "glide", "quick", "tele_hop"]

static var owned: Array[String] = []
static var equipped: Array[String] = []
static var _loaded := false


static func setup() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK and cfg.has_section_key("cards", "owned"):
		owned.assign(cfg.get_value("cards", "owned", []))
		equipped.assign(cfg.get_value("cards", "equipped", []))
		owned = owned.filter(func(a: String) -> bool: return a in ALL)
		equipped = equipped.filter(func(a: String) -> bool: return a in owned)
	else:
		owned.assign([STARTER])
		equipped.assign([STARTER])
		save()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep the other saved settings
	cfg.set_value("cards", "owned", owned)
	cfg.set_value("cards", "equipped", equipped)
	cfg.save(PATH)


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
