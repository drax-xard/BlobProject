extends Node

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 5

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

# --- Public API ---

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		DebugLog.warn("SaveManager: Invalid slot %d" % slot)
		return false
	var data := _build_save_data()
	data["slot"] = slot
	data["timestamp"] = Time.get_datetime_string_from_system()
	data["version"] = GameManager.get_version()
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		DebugLog.error("SaveManager: Could not write to %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_log_save_data("Save", data)
	DebugLog.info("SaveManager: Game saved to slot %d" % slot)
	return true

func load_game(slot: int) -> bool:
	if not has_save(slot):
		DebugLog.warn("SaveManager: No save in slot %d" % slot)
		return false
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		DebugLog.error("SaveManager: Could not read %s" % path)
		return false
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		DebugLog.error("SaveManager: Parse error in %s: %s" % [path, json.get_error_message()])
		return false
	var data: Dictionary = json.data
	_log_save_data("Load", data)
	_apply_save_data(data)
	DebugLog.info("SaveManager: Game loaded from slot %d" % slot)
	return true

func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	var path := _slot_path(slot)
	DirAccess.remove_absolute(path)
	DebugLog.info("SaveManager: Deleted save slot %d" % slot)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"slot": slot,
		"version": data.get("version", "unknown"),
		"timestamp": data.get("timestamp", "unknown"),
		"dungeon_id": data.get("dungeon_id", ""),
		"floor": data.get("floor", 1),
		"turn_count": data.get("turn_count", 0),
		"gold": data.get("gold", 0),
		"party_size": data.get("party", []).size(),
		"party_names": _extract_party_names(data.get("party", [])),
		"party_level": _extract_party_level(data.get("party", [])),
	}

func get_all_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		slots.append(get_save_info(i))
	return slots

# --- Build / Apply ---

func _build_save_data() -> Dictionary:
	var data: Dictionary = {}
	data["party"] = GameManager.party.duplicate(true)
	data["inventory"] = GameManager.inventory.duplicate(true)
	data["gold"] = GameManager.gold
	data["dungeon_id"] = GameManager.current_dungeon_id
	data["floor"] = GameManager.current_floor
	data["turn_count"] = GameManager.turn_count
	data["player_grid_pos"] = {"x": GameManager.saved_player_pos.x, "y": GameManager.saved_player_pos.y}
	data["player_facing"] = GameManager.saved_player_facing
	return data

func _apply_save_data(data: Dictionary) -> void:
	GameManager.party = data.get("party", [])
	GameManager.inventory = data.get("inventory", [])
	GameManager.gold = data.get("gold", 0)
	GameManager.current_dungeon_id = data.get("dungeon_id", "")
	GameManager.current_floor = data.get("floor", 1)
	GameManager.turn_count = data.get("turn_count", 0)
	var pos_data: Dictionary = data.get("player_grid_pos", {"x": 0, "y": 0})
	GameManager.saved_player_pos = Vector2i(pos_data.get("x", 0), pos_data.get("y", 0))
	GameManager.saved_player_facing = data.get("player_facing", 0)
	GameManager.current_state = GameManager.GameState.EXPLORING
	GameManager.party_changed.emit()
	GameManager.inventory_changed.emit()
	GameManager.game_loaded.emit()

# --- Helpers ---

func _slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("save_%d.json" % slot)

func _log_save_data(label: String, data: Dictionary) -> void:
	DebugLog.info("SaveManager [%s] dungeon=%s floor=%d gold=%d turn=%d" % [
		label, data.get("dungeon_id", "?"), data.get("floor", 0),
		data.get("gold", 0), data.get("turn_count", 0)])
	var pos: Dictionary = data.get("player_grid_pos", {})
	DebugLog.info("SaveManager [%s] pos=(%d,%d) facing=%d" % [
		label, pos.get("x", 0), pos.get("y", 0), data.get("player_facing", 0)])
	var party: Array = data.get("party", [])
	for i in range(party.size()):
		if party[i] is Dictionary:
			var m: Dictionary = party[i]
			DebugLog.info("SaveManager [%s] party[%d]: %s Lv.%d HP=%d/%d MP=%d/%d STR=%d DEF=%d" % [
				label, i, m.get("name", "?"), m.get("level", 0),
				m.get("hp", 0), m.get("max_hp", 0),
				m.get("mp", 0), m.get("max_mp", 0),
				m.get("strength", 0), m.get("defense", 0)])
			var eq: Dictionary = m.get("equipment", {})
			DebugLog.info("SaveManager [%s] party[%d] equipment: %s" % [label, i, eq])
	var inv: Array = data.get("inventory", [])
	DebugLog.info("SaveManager [%s] inventory: %d stacks" % [label, inv.size()])
	for i in range(inv.size()):
		if inv[i] is Dictionary:
			DebugLog.info("SaveManager [%s]   [%d] %s x%d" % [label, i, inv[i].get("id", "?"), inv[i].get("quantity", 0)])

func _extract_party_names(party: Array) -> Array[String]:
	var names: Array[String] = []
	for member in party:
		if member is Dictionary:
			names.append(member.get("name", "?"))
	return names

func _extract_party_level(party: Array) -> int:
	for member in party:
		if member is Dictionary:
			return int(member.get("level", 1))
	return 1
