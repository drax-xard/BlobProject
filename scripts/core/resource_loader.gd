class_name ResLoader
extends RefCounted

const PACKS_PATH := "res://packs"

static var _cache: Dictionary = {}
static var _pack_manifests: Dictionary = {}

# --- Texture ---

static func load_texture(pack_id: String, path: String) -> Texture2D:
	var key := "texture:%s:%s" % [pack_id, path]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var tex: Texture2D = _try_load_texture(pack_id, path)
	if not tex:
		tex = _create_placeholder_texture(path)
		DebugLog.warn("ResLoader: Missing texture '%s/%s', using placeholder" % [pack_id, path])
	else:
		DebugLog.info("ResLoader: Loaded texture '%s/%s'" % [pack_id, path])
	_cache[key] = tex
	return tex

static func _try_load_texture(pack_id: String, path: String) -> Texture2D:
	var res_path := "%s/%s/assets/textures/%s" % [PACKS_PATH, pack_id, path]
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null

static func _create_placeholder_texture(label: String) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	if label.begins_with("portrait"):
		img.fill(Color(1.0, 0.0, 1.0))
	else:
		img.fill(Color(0.5, 0.0, 0.5))
	return ImageTexture.create_from_image(img)

# --- Audio ---

static func load_audio(pack_id: String, path: String) -> AudioStream:
	var key := "audio:%s:%s" % [pack_id, path]
	if _cache.has(key):
		return _cache[key] as AudioStream
	var stream: AudioStream = _try_load_audio(pack_id, path)
	if not stream:
		stream = _create_placeholder_audio()
		DebugLog.warn("ResLoader: Missing audio '%s/%s', using placeholder" % [pack_id, path])
	else:
		DebugLog.info("ResLoader: Loaded audio '%s/%s'" % [pack_id, path])
	_cache[key] = stream
	return stream

static func _try_load_audio(pack_id: String, path: String) -> AudioStream:
	var res_path := "%s/%s/assets/audio/%s" % [PACKS_PATH, pack_id, path]
	if ResourceLoader.exists(res_path):
		return load(res_path) as AudioStream
	return null

static func _create_placeholder_audio() -> AudioStream:
	return AudioStream.new()

# --- Scene ---

static func load_scene(pack_id: String, path: String) -> PackedScene:
	var key := "scene:%s:%s" % [pack_id, path]
	if _cache.has(key):
		return _cache[key] as PackedScene
	var res_path := "%s/%s/assets/scenes/%s" % [PACKS_PATH, pack_id, path]
	if ResourceLoader.exists(res_path):
		var scene: PackedScene = load(res_path)
		_cache[key] = scene
		DebugLog.info("ResLoader: Loaded scene '%s/%s'" % [pack_id, path])
		return scene
	DebugLog.warn("ResLoader: Missing scene '%s/%s'" % [pack_id, path])
	return null

# --- Generic cached access ---

static func get_or_load(type: String, pack_id: String, path: String) -> Resource:
	match type:
		"texture":
			return load_texture(pack_id, path)
		"audio":
			return load_audio(pack_id, path)
		"scene":
			return load_scene(pack_id, path)
		_:
			DebugLog.warn("ResLoader: Unknown resource type '%s'" % type)
			return null

# --- Pack manifest ---

static func load_pack_manifest(pack_id: String) -> Dictionary:
	if _pack_manifests.has(pack_id):
		return _pack_manifests[pack_id]
	var manifest_path := "%s/%s/pack.json" % [PACKS_PATH, pack_id]
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		DebugLog.warn("ResLoader: Could not open pack.json for '%s'" % pack_id)
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		DebugLog.error("ResLoader: JSON parse error in %s/pack.json: %s" % [pack_id, json.get_error_message()])
		return {}
	var data: Dictionary = json.data
	_pack_manifests[pack_id] = data
	return data

static func get_asset_list(pack_id: String) -> Dictionary:
	var manifest := load_pack_manifest(pack_id)
	return manifest.get("assets", {})

static func has_asset(pack_id: String, type: String, path: String) -> bool:
	var assets := get_asset_list(pack_id)
	var list: Array = assets.get(type, [])
	return path in list

# --- Cache management ---

static func clear_cache() -> void:
	_cache.clear()

static func clear_pack(pack_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for key in _cache:
		if key.ends_with(":%s:" % pack_id) or (":" in key and key.split(":")[1] == pack_id):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_cache.erase(key)

static func get_cache_size() -> int:
	return _cache.size()
