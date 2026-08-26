extends Node

signal data_loaded(category: String)
signal all_data_loaded()

var _cache: Dictionary = {}
var _base_pack_path: String = "res://packs/base/records"

func _ready() -> void:
	call_deferred("load_all_data")

func load_all_data() -> void:
	DebugLog.info("DataRegistry: Starting data load from %s" % _base_pack_path)
	var categories := ["items", "enemies", "classes", "dungeons", "spells"]
	for category in categories:
		_load_category(category)
	DebugLog.info("DataRegistry: Loaded %d records total" % _cache.size())
	all_data_loaded.emit()

func _load_category(category: String) -> void:
	var dir_path := "%s/%s" % [_base_pack_path, category]
	var dir := DirAccess.open(dir_path)
	if not dir:
		DebugLog.warn("DataRegistry: Could not open directory: %s" % dir_path)
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
		DebugLog.warn("DataRegistry: Could not open file: %s" % file_path)
		return
	var json_text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		DebugLog.error("DataRegistry: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return
	var data = json.data
	var count := 0
	if data is Array:
		for item in data:
			if item is Dictionary and item.has("id"):
				_validate_record(item)
				_cache[item["id"]] = item
				count += 1
			elif item is Dictionary:
				DebugLog.data_issue("(unknown)", "id", "string", "missing")
	elif data is Dictionary:
		if data.has("id"):
			_validate_record(data)
			_cache[data["id"]] = data
			count += 1
		else:
			DebugLog.data_issue(file_path.get_file(), "id", "string", "missing")
	DebugLog.info("DataRegistry: Loaded %d records from %s" % [count, file_path.get_file()])

func _validate_record(record: Dictionary) -> void:
	var id: String = record.get("id", "(unknown)")
	var type: String = record.get("type", "")
	match type:
		"class":
			_validate_class_record(record, id)
		"weapon", "armor":
			_validate_equipment_record(record, id)
		"consumable":
			_validate_consumable_record(record, id)
		"spell":
			_validate_spell_record(record, id)
		"enemy":
			_validate_enemy_record(record, id)
		"dungeon":
			_validate_dungeon_record(record, id)

func _validate_class_record(record: Dictionary, id: String) -> void:
	var required := ["hp", "mp", "strength", "defense", "vitality", "energy", "agility", "luck"]
	if not record.has("base_stats"):
		DebugLog.data_issue(id, "base_stats", "Dictionary", "missing")
		return
	var stats: Dictionary = record["base_stats"]
	for key in required:
		if not stats.has(key):
			DebugLog.data_issue(id, "base_stats.%s" % key, "int", "missing")
		elif not stats[key] is int and not stats[key] is float:
			DebugLog.data_issue(id, "base_stats.%s" % key, "int", typeof(stats[key]))

func _validate_equipment_record(record: Dictionary, id: String) -> void:
	if not record.has("slot"):
		DebugLog.data_issue(id, "slot", "String", "missing")

func _validate_consumable_record(record: Dictionary, id: String) -> void:
	if not record.has("effect"):
		DebugLog.data_issue(id, "effect", "String", "missing")

func _validate_spell_record(record: Dictionary, id: String) -> void:
	if not record.has("mp_cost"):
		DebugLog.data_issue(id, "mp_cost", "int", "missing")

func _validate_enemy_record(record: Dictionary, id: String) -> void:
	for key in ["hp", "strength", "defense", "agility"]:
		if not record.has(key):
			DebugLog.data_issue(id, key, "int", "missing")

func _validate_dungeon_record(record: Dictionary, id: String) -> void:
	if not record.has("floor_data"):
		DebugLog.data_issue(id, "floor_data", "Array", "missing")
		return
	var floors: Array = record["floor_data"]
	for i in range(floors.size()):
		var fd: Variant = floors[i]
		if not fd is Dictionary:
			DebugLog.data_issue(id, "floor_data[%d]" % i, "Dictionary", typeof(fd))
			continue
		for key in ["width", "height", "encounter_rate"]:
			if not fd.has(key):
				DebugLog.data_issue(id, "floor_data[%d].%s" % [i, key], "varies", "missing")

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
