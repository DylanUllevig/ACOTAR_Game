extends Node
## Player options, kept in user://settings.cfg (separate from saves, so they
## survive a new game). Volumes are 0..1 linear; everything applies at once.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"master_volume": 0.85,
	"music_volume": 0.7,
	"sfx_volume": 0.85,
	"ambience_volume": 0.7,
	"ui_volume": 0.7,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": 1.0,      # 0 = off, 1 = full
	"text_speed": 1.0,        # multiplier on the typewriter
	"damage_numbers": true,
	"show_hints": true,
}
const BUSES := {"master_volume": "Master", "music_volume": "Music", "sfx_volume": "SFX", "ambience_volume": "Ambience", "ui_volume": "UI"}

var values := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	values = DEFAULTS.duplicate()
	var cf = ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			var v = cf.get_value("options", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v
	apply_all.call_deferred()


func get_v(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_v(key: String, v: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Unknown setting " + key)
		return
	values[key] = v
	_apply(key)
	save()
	changed.emit(key)


func save() -> void:
	var cf = ConfigFile.new()
	for k in values:
		cf.set_value("options", k, values[k])
	cf.save(PATH)


func apply_all() -> void:
	for k in values:
		_apply(k)


func _apply(key: String) -> void:
	if BUSES.has(key):
		var idx = AudioServer.get_bus_index(BUSES[key])
		if idx >= 0:
			var lin = clampf(float(values[key]), 0.0, 1.0)
			AudioServer.set_bus_volume_db(idx, linear_to_db(max(lin, 0.0001)))
			AudioServer.set_bus_mute(idx, lin <= 0.001)
		return
	match key:
		"fullscreen":
			if DisplayServer.get_name() == "headless":
				return
			var want = bool(values[key])
			var mode = DisplayServer.window_get_mode()
			var is_full = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if want and not is_full:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif not want and is_full:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			if DisplayServer.get_name() == "headless":
				return
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values[key]) else DisplayServer.VSYNC_DISABLED)
