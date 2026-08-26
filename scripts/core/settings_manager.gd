extends Node

signal settings_changed(section: String)

const CONFIG_PATH_DEV := "res://settings.cfg"
const CONFIG_PATH_EXPORT := "user://settings.cfg"

var config_path: String = ""

var defaults_layout := {
	"viewport_ratio": 2.0,
	"party_panel_ratio": 1.0,
	"action_bar_ratio": 1.0,
	"viewport_min_height": 200,
	"action_bar_min_height": 40,
	"party_panel_min_width": 200,
}

var defaults_display := {
	"fullscreen": false,
	"vsync": true,
	"msaa": 0,
	"resolution_scale": 1.0,
}

var defaults_audio := {
	"master_volume": 80,
	"music_volume": 70,
	"sfx_volume": 80,
}

var layout: Dictionary = {}
var display: Dictionary = {}
var audio: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("editor") or OS.is_debug_build():
		config_path = CONFIG_PATH_DEV
	else:
		config_path = CONFIG_PATH_EXPORT
	load_settings()
	if not FileAccess.file_exists(config_path):
		save_settings()
	apply_display()
	apply_audio()

func load_settings() -> void:
	layout = defaults_layout.duplicate()
	display = defaults_display.duplicate()
	audio = defaults_audio.duplicate()

	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK:
		return

	for key in layout:
		if config.has_section_key("layout", key):
			layout[key] = config.get_value("layout", key)
	for key in display:
		if config.has_section_key("display", key):
			display[key] = config.get_value("display", key)
	for key in audio:
		if config.has_section_key("audio", key):
			audio[key] = config.get_value("audio", key)

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in layout:
		config.set_value("layout", key, layout[key])
	for key in display:
		config.set_value("display", key, display[key])
	for key in audio:
		config.set_value("audio", key, audio[key])
	config.save(config_path)

func get_layout(key: String) -> Variant:
	return layout.get(key)

func set_layout(key: String, value: Variant) -> void:
	layout[key] = value
	save_settings()
	settings_changed.emit("layout")

func get_display(key: String) -> Variant:
	return display.get(key)

func set_display(key: String, value: Variant) -> void:
	display[key] = value
	save_settings()
	apply_display()
	settings_changed.emit("display")

func get_audio(key: String) -> Variant:
	return audio.get(key)

func set_audio(key: String, value: Variant) -> void:
	audio[key] = value
	save_settings()
	apply_audio()
	settings_changed.emit("audio")

func apply_display() -> void:
	if display.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	match display.get("vsync", true):
		true:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		false:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var msaa_value: int = display.get("msaa", 0)
	var vp := get_viewport()
	if vp:
		match msaa_value:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			2: vp.msaa_3d = Viewport.MSAA_2X
			4: vp.msaa_3d = Viewport.MSAA_4X
			8: vp.msaa_3d = Viewport.MSAA_8X

func apply_audio() -> void:
	var master: float = audio.get("master_volume", 80) / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(master) if master > 0.0 else -80.0)
	AudioServer.set_bus_mute(0, master <= 0.0)
