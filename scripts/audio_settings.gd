class_name AudioSettings
extends RefCounted
## Music and sound volumes, and the master sound switch. Music plays on the "Music" bus and
## sound effects on the "Sounds" bus; both feed Master. Settings are saved on this device.

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SOUNDS_BUS := "Sounds"

static var music := 0.8     # 0..1
static var sounds := 0.8    # 0..1
static var sound_on := true


## Create the buses (once) and apply the saved settings.
static func setup() -> void:
	for bus_name in [MUSIC_BUS, SOUNDS_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music = cfg.get_value("audio", "music", music)
		sounds = cfg.get_value("audio", "sounds", sounds)
		sound_on = cfg.get_value("audio", "sound_on", sound_on)
	apply()


static func apply() -> void:
	_set_volume(MUSIC_BUS, music)
	_set_volume(SOUNDS_BUS, sounds)
	AudioServer.set_bus_mute(0, not sound_on)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep other saved settings, like the player's color
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sounds", sounds)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.save(PATH)


static func _set_volume(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.0)
