extends Node

signal data_loaded(category: String)
signal all_data_loaded()

var _cache: Dictionary = {}
var _base_pack_path: String = "res://packs/base/records"

func _ready() -> void:
	call_deferred("load_all_data")

func load_all_data() -> void:
	var categories := ["items", "enemies", "classes", "dungeons", "spells"]
	for category in categories:
		_load_category(category)
	all_data_loaded.emit()

func _load_category(category: String) -> void:
	var dir_path := "%s/%s" % [_base_pack_path, category]
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("DataRegistry: Could not open directory: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_json_file(dir_path.path_join(file_name), category)
		file_name = dir.get_next()
	dir.list_dir_end()
	data_loaded.emit(category)

func _load_json_file(file_path: String, _category: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("DataRegistry: Could not open file: %s" % file_path)
		return
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("DataRegistry: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return
	var data = json.data
	if data is Array:
		for item in data:
			if item is Dictionary and item.has("id"):
				_cache[item["id"]] = item
	elif data is Dictionary:
		if data.has("id"):
			_cache[data["id"]] = data

func get_record(record_id: String) -> Dictionary:
	if _cache.has(record_id):
		return _cache[record_id]
	return {}

func get_records_by_category(category: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for id in _cache:
		var record: Dictionary = _cache[id]
		if record.has("type") and record["type"] == category:
			results.append(record)
	return results

func has_record(record_id: String) -> bool:
	return _cache.has(record_id)

func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _cache:
		ids.append(id)
	return ids
